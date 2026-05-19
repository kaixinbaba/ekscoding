#!/bin/bash
set -euo pipefail

# ============================================================
# justdoit.sh — 一键任务执行 + 验收脚本
#
# 用法:
#   ./justdoit.sh [project_dir]
#
# Phase 1: 逐任务执行（独立 agent CLI 每次一个任务）
# Phase 2: 生成双轨验收文档
# Phase 3: 执行 agent 验收检查
# ============================================================

SKILL_DIR="$(cd "$(dirname "$0")" && pwd)"
SKILL_TEMPLATES_DIR="${SKILL_DIR}/templates"
MAX_RETRIES=3
SLEEP_BETWEEN_TASKS=2
TASK_TIMEOUT=1800  # 30 minutes per task attempt (0 = disabled, override in .justdoitrc)
HEARTBEAT_INTERVAL=30  # seconds between progress pings

# Load tool config
TOOL_CONFIG="${SKILL_DIR}/.justdoitrc"
if [ -f "$TOOL_CONFIG" ]; then
    source "$TOOL_CONFIG"
fi

# Build priority list — prefer new array, fallback to old single value
if [[ -n "${AGENT_CLI_PRIORITY+x}" ]] && [[ ${#AGENT_CLI_PRIORITY[@]} -gt 0 ]]; then
    PRIORITY_TOOLS=("${AGENT_CLI_PRIORITY[@]}")
elif [[ -n "${AGENT_CLI:-}" ]]; then
    PRIORITY_TOOLS=("$AGENT_CLI")
else
    PRIORITY_TOOLS=("claude -p --permission-mode bypassPermissions")
fi

# Extract binary names for validation
PRIORITY_BINS=()
for cmd in "${PRIORITY_TOOLS[@]}"; do
    PRIORITY_BINS+=("${cmd%% *}")
done

# Tool name → command mapping (for --tool flag)
get_tool_cmd() {
    case "$1" in
        claude) echo "claude -p --permission-mode bypassPermissions" ;;
        codex)  echo "codex exec" ;;
        gemini) echo "gemini -p" ;;
    esac
}

is_valid_tool() {
    case "$1" in
        claude|codex|gemini) return 0 ;;
        *) return 1 ;;
    esac
}

# ============================================================
# Error classification
# ============================================================

classify_error() {
    local stderr="$1"
    local lower
    lower=$(echo "$stderr" | tr '[:upper:]' '[:lower:]')

    if echo "$lower" | grep -qE '429|rate.?limit|quota|billing|usage.?limit|hit.*(limit|quota)|limit.?reached|too many requests|usage.?exceeded'; then
        echo "QUOTA"
    elif echo "$lower" | grep -qE '401|403|unauthorized|unauthenticated|auth|invalid.*(key|api|token)|incorrect.*api.*key|api.?key|not.*authorized'; then
        echo "AUTH"
    elif echo "$lower" | grep -qE 'connection.*(refused|reset|closed)|tim(e)?out|ENOTFOUND|DNS|resolve|unreachable|network|ETIMEDOUT|ECONNREFUSED|EHOSTUNREACH'; then
        echo "NETWORK"
    elif echo "$lower" | grep -qE 'certificate|ssl|tls|unable.*verify|UNABLE_TO_VERIFY|SSL_ERROR'; then
        echo "CERT"
    else
        echo "UNKNOWN"
    fi
}

# Detect if exit code indicates timeout (124 = timeout command, 142 = SIGALRM)
is_timeout_exit() {
    local code="$1"
    [[ "$code" -eq 124 || "$code" -eq 142 ]]
}

explain_error() {
    local error_type="$1"
    local tool_info="$2"

    case "$error_type" in
        QUOTA)    log_warning "${tool_info}: 额度用尽或触发限流，切换下一个工具..." ;;
        AUTH)     log_warning "${tool_info}: API Key 无效或认证失败，跳过该工具" ;;
        NETWORK)  log_warning "${tool_info}: 网络连接失败/超时，切换下一个工具..." ;;
        CERT)     log_warning "${tool_info}: SSL 证书验证失败，切换下一个工具..." ;;
        TIMEOUT)  log_warning "${tool_info}: 任务超时 (${TASK_TIMEOUT}s)，切换下一个工具..." ;;
        *)        log_warning "${tool_info}: 异常退出，切换下一个工具..." ;;
    esac
}

# ============================================================
# Color
# ============================================================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
PURPLE='\033[0;35m'
NC='\033[0m'

# ============================================================
# Logging
# ============================================================
log_info()    { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[OK]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error()   { echo -e "${RED}[ERROR]${NC} $1"; }
log_step()    { echo -e "${CYAN}==>${NC} $1"; }
log_phase()   { echo -e "${PURPLE}==>${NC} ${PURPLE}$1${NC}"; }

# ============================================================
# Sleep prevention (macOS caffeinate, Linux fallback)
# ============================================================
CAFFEINATE_PID=""

start_sleep_prevention() {
    if command -v caffeinate &>/dev/null; then
        # macOS: caffeinate -s (prevent system sleep) with generous timeout
        caffeinate -s -t 86400 &
        CAFFEINATE_PID=$!
        log_info "已启动 caffeinate (PID: ${CAFFEINATE_PID})，防止系统休眠"
    else
        # Linux: try systemd-inhibit, else spawn a periodic pinger
        if command -v systemd-inhibit &>/dev/null; then
            systemd-inhibit --what=sleep --why="justdoit running" sleep 86400 &
            CAFFEINATE_PID=$!
            log_info "已启动 systemd-inhibit (PID: ${CAFFEINATE_PID})"
        else
            # Fallback: background process that touches a temp file every 60s
            # Keeps the shell alive; some systems detect activity via this
            local ping_file
            ping_file=$(mktemp)
            (
                while true; do
                    touch "$ping_file" 2>/dev/null || true
                    sleep 60
                done
            ) &
            CAFFEINATE_PID=$!
            log_info "已启动 sleep-ping 保活进程 (PID: ${CAFFEINATE_PID})"
        fi
    fi
}

stop_sleep_prevention() {
    if [[ -n "$CAFFEINATE_PID" ]] && kill -0 "$CAFFEINATE_PID" 2>/dev/null; then
        kill "$CAFFEINATE_PID" 2>/dev/null || true
        wait "$CAFFEINATE_PID" 2>/dev/null || true
    fi
}

# ============================================================
# Signal handling
# ============================================================
cleanup() {
    echo ""
    stop_sleep_prevention
    log_warning "Interrupted. Partial progress may exist."
    log_info "Re-run justdoit.sh to continue from next pending task."
    exit 130
}
trap cleanup SIGINT SIGTERM
trap stop_sleep_prevention EXIT

# ============================================================
# Environment validation
# ============================================================
validate_environment() {
    local project_dir="$1"

    # Check at least one tool binary is available
    local any_found=false
    local missing_bins=()
    for bin in "${PRIORITY_BINS[@]}"; do
        if command -v "$bin" &>/dev/null; then
            any_found=true
        else
            missing_bins+=("$bin")
        fi
    done

    if ! $any_found; then
        log_error "No AI CLI tool found among: ${PRIORITY_BINS[*]}"
        log_error "Run install.sh to reconfigure."
        return 1
    fi

    if [[ ${#missing_bins[@]} -gt 0 ]]; then
        log_info "以下工具不可用（运行时将跳过）: ${missing_bins[*]}"
    fi

    if [[ ! -d "$project_dir" ]]; then
        log_error "Directory not found: $project_dir"
        return 1
    fi

    if [[ ! -d "$project_dir/docs/plans" ]]; then
        log_error "docs/plans/ not found in project. Run /createTasks first."
        return 1
    fi
}

# ============================================================
# File discovery
# ============================================================

find_latest_number() {
    local dir="$1"
    local prefix="$2"
    local max=0
    local f num
    for f in "$dir"/${prefix}*.md; do
        [[ -f "$f" ]] || continue
        num=$(basename "$f" | sed -E "s/^${prefix}([0-9]+)\.md$/\\1/")
        if [[ "$num" =~ ^[0-9]+$ ]] && [[ "$num" -gt "$max" ]]; then
            max="$num"
        fi
    done
    echo "$max"
}

find_latest_progress() {
    local plans_dir="$1/docs/plans"
    local n
    n=$(find_latest_number "$plans_dir" "progress")
    [[ "$n" -eq 0 ]] && echo "" || echo "$plans_dir/progress${n}.md"
}

find_latest_task() {
    local plans_dir="$1/docs/plans"
    local n
    n=$(find_latest_number "$plans_dir" "task")
    [[ "$n" -eq 0 ]] && echo "" || echo "$plans_dir/task${n}.md"
}

# ============================================================
# Task counting
# ============================================================

count_tasks() {
    local progress_file="$1"
    local total pending done blocked
    total=$(command grep -cE '^- \[[ x~]\] \*\*Task ' "$progress_file" 2>/dev/null | head -1); total=${total:-0}
    pending=$(command grep -cE '^- \[ \] \*\*Task ' "$progress_file" 2>/dev/null | head -1); pending=${pending:-0}
    done=$(command grep -cE '^- \[x\] \*\*Task ' "$progress_file" 2>/dev/null | head -1); done=${done:-0}
    blocked=$(command grep -cE '^- \[~\] \*\*Task ' "$progress_file" 2>/dev/null | head -1); blocked=${blocked:-0}
    echo "${total}|${done}|${blocked}|${pending}"
}

find_first_pending() {
    local progress_file="$1"
    # Find first [ ] task, skipping any [~] blocked tasks before it
    local line
    line=$(command grep -E '^- \[ \] \*\*Task ' "$progress_file" | head -1)

    if [[ -z "$line" ]]; then
        echo ""
        return
    fi

    # Extract Task ID and title using sed (more robust than bash regex for Unicode)
    local task_id title
    task_id=$(echo "$line" | sed -E 's/.*\*\*Task ([0-9]+\.[0-9]+)\*\*.*/\1/')
    title=$(echo "$line" | sed -E 's/^-\ \[ \] \*\*Task [0-9]+\.[0-9]+\*\*[[:space:]]+[-–—]{1,3}[[:space:]]+//')

    local module task_num
    module=$(echo "$task_id" | cut -d. -f1)
    task_num=$(echo "$task_id" | cut -d. -f2)

    echo "${module}|${task_num}|${title}"
}

# Check for blocked tasks that appear before the first pending task
find_blocked_before_pending() {
    local progress_file="$1"
    # Get all non-[x] tasks before the first [ ] task
    # Simple approach: if any [~] exists, warn about them
    command grep -E '^- \[~\] \*\*Task ' "$progress_file" | head -5 || true
}

verify_task_completed() {
    local progress_file="$1"
    local module="$2"
    local task_num="$3"
    command grep -qE "^- \[x\] \*\*Task ${module}\.${task_num}\*\*" "$progress_file"
}

# ============================================================
# Prompt builders
# ============================================================

build_task_prompt() {
    local progress_n="$1"
    local task_n="$2"
    local task_file="docs/plans/task${task_n}.md"
    local progress_file="docs/plans/progress${progress_n}.md"

    cat <<PROMPT_EOF
Execute exactly ONE task using the ekscoding workflow. Follow these steps precisely.

## Files
- Task details: ${task_file}
- Progress tracking: ${progress_file}

## Steps

### Step 1: Find the next task
- Read \`${progress_file}\`
- Find the FIRST line with \`[ ]\` (pending task). This is your target.
- If you encounter \`[~]\` (blocked) tasks before it, skip them — only take a \`[ ]\` task.
- Note: Module.Task identifier (e.g. "1.2") and task title.

### Step 2: Read task details
- Read \`${task_file}\`
- Find the task block matching your target
- Note: file paths, ALL implementation points, ALL acceptance criteria

### Step 3: Implement
- Make changes to the specified files following ALL implementation points
- Run lints / typecheck after changes if the project has them configured

### Step 4: Verify acceptance criteria
- Go through EVERY acceptance criterion one by one
- For each: perform the verification, collect concrete evidence (command output, file content, test results)
- If ANY criterion fails: fix the issue, then RE-VERIFY ALL criteria from the beginning

### Step 5: Update progress
- In \`${progress_file}\`, change ONLY the task's \`[ ]\` to \`[x]\`
- Append completion note immediately after the task line:
  \`\`\`
  > 完成时间：YYYY-MM-DD | 完成人：agent | 备注：<brief summary>
  \`\`\`
- Update the completion stats table at the bottom (increment completed count)

### Step 6: STOP (git commit handled by script)
- The justdoit.sh script will automatically commit all changes after you finish
- Do NOT run git add/commit yourself — the script enforces it
- Report which task was completed
- Show verification evidence for each acceptance criterion
- Do NOT proceed to the next task

## State Markers
| Marker | Meaning  |
|--------|----------|
| [ ]    | Pending  |
| [x]    | Done     |
| [~]    | Blocked  |

## Hard Constraints
- ONE TASK ONLY — stop immediately after completing one task
- VERIFY FIRST — all acceptance criteria must pass before marking done
- DO NOT COMMIT — the script handles git commit automatically
- Skip blocked tasks ([~]) — only work on [ ] tasks
PROMPT_EOF
}

build_retry_prompt() {
    local progress_n="$1"
    local task_n="$2"
    local module="$3"
    local task_num="$4"
    local attempt="$5"

    echo ""
    echo "=== RETRY ATTEMPT ${attempt}/${MAX_RETRIES} ==="
    echo "Previous attempt to complete Task ${module}.${task_num} may not have succeeded."
    echo "Check the current state of progress docs/plans/progress${progress_n}.md to see if the task was already marked [x]."
    echo "If already [x], just report it and stop. Otherwise, try again with the steps below."

    build_task_prompt "$progress_n" "$task_n"
}

build_phase2_prompt() {
    local task_n="$1"

    cat <<PROMPT_EOF
Generate dual-track acceptance documentation for a completed project. Generate docs ONLY — do NOT execute any checks yet.

## Context
- Task doc: docs/plans/task${task_n}.md (read for feature name, modules, and acceptance criteria)
- Human template reference: ${SKILL_TEMPLATES_DIR}/acceptance-human-template.md
- Agent template reference: ${SKILL_TEMPLATES_DIR}/acceptance-agent-template.md

## Steps

### Step 1: Read the task doc
- Open \`docs/plans/task${task_n}.md\`
- Identify the PROJECT/FEATURE name (from title; convert to kebab-case for filenames)
- Review ALL acceptance criteria across ALL tasks

### Step 2: Generate HUMAN acceptance doc
- Save to: \`docs/plans/acceptance-{FEATURE}.md\`
- Format:
  \`\`\`
  # {PROJECT} — 人工验收手册

  | 状态 | 步骤 | 操作 | 通过标准 |
  |------|------|------|----------|
  | [ ] | 1.1 | <action description> | <pass condition> |
  \`\`\`
- Cover ALL acceptance criteria from the task doc
- Each step must be clear enough for a non-developer to follow
- Add summary section at bottom

### Step 3: Generate AGENT acceptance doc
- Save to: \`docs/plans/acceptance-{FEATURE}-agent.md\`
- Format:
  \`\`\`
  # {PROJECT} — Agent 验收手册

  ## 执行规则
  1. 严格按步骤顺序执行
  2. 每个检查项必须写证据
  3. 失败项必须写根因和修复建议

  | 状态 | 步骤 | 检查动作 | 预期结果 | 证据 |
  |------|------|----------|----------|------|
  | [ ] | 1.1 | <CLI command or check action> | <expected output/behavior> | |

  ## Acceptance Result
  - 通过：0
  - 失败：0
  - 结论：[ ] 通过 / [ ] 部分通过 / [ ] 不通过
  \`\`\`
- Each "检查动作" MUST be a fully automated CLI command (e.g. \`curl\`, \`grep\`, \`npm test\`, \`git log\`)
- Expected result must be specific and verifiable
- Evidence column stays EMPTY — to be filled in Phase 3

### Step 4: Report
- Confirm both file paths
- Show: N human checks, M agent checks defined
- Remind: agent checks NOT executed yet
PROMPT_EOF
}

build_phase3_prompt() {
    local feature="$1"

    cat <<PROMPT_EOF
Execute agent-driven acceptance checks for a completed project. Inspection only — do NOT modify code.

## Context
- Agent acceptance doc: docs/plans/acceptance-${feature}-agent.md

## Steps

### Step 1: Read the agent acceptance doc
- Open \`docs/plans/acceptance-${feature}-agent.md\`
- Review all check items in the table

### Step 2: Execute every check
- Go through each check item in order
- For each check:
  1. Execute the command/action exactly as specified
  2. Record the ACTUAL result (copy-paste command output into evidence column)
  3. Compare actual vs expected
  4. Mark \`[x]\` for pass, \`[ ]\` for fail
  5. If a check cannot run (missing dep, wrong env), mark \`[~]\` with reason

### Step 3: Update Acceptance Result summary
- Count: passed, failed, blocked
- Set conclusion: \`[x] 通过\` if all passed, \`[ ] 部分通过\` if some failed, \`[ ] 不通过\` if all failed

### Step 4: Report
- Summary of pass/fail/blocked counts
- For each failure: which check failed, actual vs expected, root cause if determinable, suggested fix
- For each block: what was missing

## Hard Constraints
- Do NOT modify any feature code — inspect only
- Evidence must be CONCRETE — copy-paste actual terminal output
- Mark failures clearly with root cause analysis
- If a check can't run, mark as blocked ([~]) with reason
PROMPT_EOF
}

# ============================================================
# Agent execution
# ============================================================

execute_agent() {
    local project_dir="$1"
    local prompt="$2"
    local tool_cmd="$3"
    local stderr_file="$4"
    local timeout_sec="${5:-}"   # optional: 0 or empty = no timeout
    local progress_file="${6:-}" # optional: for progress-based early termination
    local module="${7:-}"        # optional
    local task_num="${8:-}"      # optional

    (
        cd "$project_dir"

        # For codex: suppress noisy thinking output via -o, capture final message
        local codex_out=""
        local stdout_redir=""
        if [[ "$tool_cmd" == codex* ]]; then
            codex_out=$(mktemp)
            tool_cmd="$tool_cmd -o $codex_out"
            stdout_redir=">/dev/null"
        fi

        # Helper: launch agent in background
        _launch_agent() {
            if [[ "$tool_cmd" =~ (^|.*[[:space:]])-p$ ]]; then
                # gemini-style: prompt as argument
                if [[ -n "$stderr_file" ]]; then
                    $tool_cmd "$prompt" 2> >(tee "$stderr_file" >&2) &
                else
                    $tool_cmd "$prompt" &
                fi
            else
                # stdin-style: prompt via pipe
                if [[ -n "${stdout_redir:-}" ]]; then
                    if [[ -n "$stderr_file" ]]; then
                        echo "$prompt" | $tool_cmd >/dev/null 2> >(tee "$stderr_file" >&2) &
                    else
                        echo "$prompt" | $tool_cmd >/dev/null &
                    fi
                else
                    if [[ -n "$stderr_file" ]]; then
                        echo "$prompt" | $tool_cmd 2> >(tee "$stderr_file" >&2) &
                    else
                        echo "$prompt" | $tool_cmd &
                    fi
                fi
            fi
        }

        if [[ -z "${timeout_sec:-}" ]] || [[ "${timeout_sec:-0}" -le 0 ]]; then
            # No timeout — run directly
            if [[ "$tool_cmd" =~ (^|.*[[:space:]])-p$ ]]; then
                if [[ -n "$stderr_file" ]]; then
                    $tool_cmd "$prompt" 2> >(tee "$stderr_file" >&2)
                else
                    $tool_cmd "$prompt"
                fi
            else
                if [[ -n "${stdout_redir:-}" ]]; then
                    if [[ -n "$stderr_file" ]]; then
                        echo "$prompt" | $tool_cmd >/dev/null 2> >(tee "$stderr_file" >&2)
                    else
                        echo "$prompt" | $tool_cmd >/dev/null
                    fi
                else
                    if [[ -n "$stderr_file" ]]; then
                        echo "$prompt" | $tool_cmd 2> >(tee "$stderr_file" >&2)
                    else
                        echo "$prompt" | $tool_cmd
                    fi
                fi
            fi
            # For codex: cat the -o output file to stdout
            if [[ -n "$codex_out" && -f "$codex_out" ]]; then
                cat "$codex_out"
                rm -f "$codex_out"
            fi
        else
            # Run with timeout + heartbeat
            local start_ts
            start_ts=$(date +%s)

            _launch_agent
            local agent_pid=$!

            # Heartbeat in background
            (
                while kill -0 "$agent_pid" 2>/dev/null; do
                    sleep "$HEARTBEAT_INTERVAL"
                    local now elapsed
                    now=$(date +%s)
                    elapsed=$((now - start_ts))
                    if kill -0 "$agent_pid" 2>/dev/null; then
                        echo -e "  ${YELLOW}[~]${NC} 等待 AI 响应... 已运行 ${elapsed}s / ${timeout_sec}s" >&2
                    fi
                done
            ) &
            local hb_pid=$!

            # Wait with timeout
            local waited=0
            while [[ $waited -lt $timeout_sec ]]; do
                if ! kill -0 "$agent_pid" 2>/dev/null; then
                    break
                fi
                sleep 1
                ((waited++))

                # Progress-based early termination (check every ~30s)
                if [[ -n "${progress_file:-}" && -n "${module:-}" && -n "${task_num:-}" ]]; then
                    if (( waited % 30 == 0 )); then
                        if command grep -qE "^- \[x\] \*\*Task ${module}\.${task_num}\*\*" "$progress_file" 2>/dev/null; then
                            echo -e "  ${GREEN}[OK]${NC} Task ${module}.${task_num} already completed (detected at ${waited}s), graceful exit..." >&2
                            kill -TERM "$agent_pid" 2>/dev/null
                            local grace=0
                            while kill -0 "$agent_pid" 2>/dev/null && (( grace < 15 )); do
                                sleep 1
                                ((grace++))
                            done
                            if kill -0 "$agent_pid" 2>/dev/null; then
                                kill -KILL "$agent_pid" 2>/dev/null
                            fi
                            wait "$agent_pid" 2>/dev/null || true
                            kill "$hb_pid" 2>/dev/null || true
                            wait "$hb_pid" 2>/dev/null || true
                            [[ -n "$codex_out" && -f "$codex_out" ]] && cat "$codex_out"
                            [[ -n "$codex_out" ]] && rm -f "$codex_out"
                            return 0
                        fi
                    fi
                fi
            done

            # Kill heartbeat
            kill "$hb_pid" 2>/dev/null || true
            wait "$hb_pid" 2>/dev/null || true

            # If still alive, timeout occurred
            if kill -0 "$agent_pid" 2>/dev/null; then
                echo -e "  ${RED}[TIMEOUT]${NC} 超过 ${timeout_sec}s，强制终止..." >&2
                kill -TERM "$agent_pid" 2>/dev/null
                sleep 2
                if kill -0 "$agent_pid" 2>/dev/null; then
                    kill -KILL "$agent_pid" 2>/dev/null
                fi
                wait "$agent_pid" 2>/dev/null || true
                [[ -n "$codex_out" && -f "$codex_out" ]] && cat "$codex_out"
                [[ -n "$codex_out" ]] && rm -f "$codex_out"
                return 124
            fi

            # Get actual exit code
            wait "$agent_pid" 2>/dev/null
            local exit_code=$?
            local elapsed
            elapsed=$(($(date +%s) - start_ts))
            echo -e "  ${GREEN}[OK]${NC} 任务耗时 ${elapsed}s" >&2
            [[ -n "$codex_out" && -f "$codex_out" ]] && cat "$codex_out"
            [[ -n "$codex_out" ]] && rm -f "$codex_out"
            return $exit_code
        fi
    )
}

# Run a prompt with tool fallback (no retries per tool, used by Phase 2 & 3)
run_with_fallback() {
    local project_dir="$1"
    local prompt="$2"
    local phase_label="$3"

    local tool_idx
    for tool_idx in $(seq 0 $((${#PRIORITY_TOOLS[@]} - 1))); do
        local tool_cmd="${PRIORITY_TOOLS[$tool_idx]}"
        local tool_bin="${PRIORITY_BINS[$tool_idx]}"

        if ! command -v "$tool_bin" &>/dev/null; then
            continue
        fi

        local stderr_file
        stderr_file=$(mktemp)
        local exit_code=0

        set +e
        execute_agent "$project_dir" "$prompt" "$tool_cmd" "$stderr_file" "$TASK_TIMEOUT"
        exit_code=$?
        set -e

        if [[ $exit_code -eq 0 ]]; then
            rm -f "$stderr_file"
            return 0
        fi

        local stderr error_type
        stderr=$(cat "$stderr_file" 2>/dev/null || echo "")
        rm -f "$stderr_file"
        if is_timeout_exit "$exit_code"; then
            error_type="TIMEOUT"
        else
            error_type=$(classify_error "$stderr")
        fi
        log_warning "${phase_label}: ${tool_bin} 退出码 ${exit_code} — ${error_type}"
        [[ -n "$stderr" ]] && echo -e "  ${YELLOW}$(echo "$stderr" | tail -3)${NC}"
        explain_error "$error_type" "$tool_bin"
    done

    log_error "${phase_label}: 所有工具均已尝试，依然失败"
    return 1
}

# ============================================================
# Progress display
# ============================================================

show_phase_banner() {
    local phase="$1"
    local desc="$2"
    echo ""
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════╗${NC}"
    printf "${CYAN}║${NC} ${PURPLE}Phase %s${NC}: %-*s${CYAN}║${NC}\n" "$phase" 48 "$desc"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

show_task_header() {
    local progress_file="$1"
    local module="$2"
    local task_num="$3"
    local title="$4"

    local stats total done_count blocked pending
    stats=$(count_tasks "$progress_file")
    IFS='|' read -r total done_count blocked pending <<< "$stats"

    echo ""
    echo -e "${BLUE}┌──────────────────────────────────────────────────────────┐${NC}"
    printf "${BLUE}│${NC}  ${CYAN}Task %s.%-3s${NC} %-*s${BLUE}│${NC}\n" "$module" "$task_num" 40 "$title"
    printf "${BLUE}│${NC}  Progress: ${GREEN}%s done${NC} / %s total (${YELLOW}%s remaining${NC})  ${BLUE}│${NC}\n" "$done_count" "$total" "$pending"
    if [[ "$blocked" -gt 0 ]]; then
        printf "${BLUE}│${NC}  ${YELLOW}Blocked tasks: %s${NC}                                             ${BLUE}│${NC}\n" "$blocked"
    fi
    echo -e "${BLUE}└──────────────────────────────────────────────────────────┘${NC}"
}

show_summary() {
    local progress_file="$1"
    local stats total done_count blocked pending
    stats=$(count_tasks "$progress_file")
    IFS='|' read -r total done_count blocked pending <<< "$stats"

    echo ""
    echo -e "${GREEN}╔══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║${NC}              ALL PHASES COMPLETE                         ${GREEN}║${NC}"
    printf "${GREEN}║${NC}  Total: %-4s | Done: %-4s | Blocked: %-4s | Pending: %-4s  ${GREEN}║${NC}\n" \
        "$total" "$done_count" "$blocked" "$pending"
    echo -e "${GREEN}╚══════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

# ============================================================
# Git commit enforcement — script is authoritative, not the agent
# ============================================================

commit_task_changes() {
    local project_dir="$1"
    local module="$2"
    local task_num="$3"
    local title="$4"

    (
        cd "$project_dir"

        # Check if there are any changes to commit
        if git diff --quiet && git diff --cached --quiet && git diff --quiet HEAD 2>/dev/null || true; then
            # Double check: any untracked files worth adding?
            if [[ -z "$(git ls-files --others --exclude-standard)" ]]; then
                log_info "No changes to commit — working tree already clean"
                return 0
            fi
        fi

        git add -A

        # If still nothing to commit, skip
        if git diff --cached --quiet; then
            log_info "No staged changes — nothing to commit"
            return 0
        fi

        local commit_msg="feat: complete Task ${module}.${task_num} - ${title}"
        if git commit -m "$commit_msg"; then
            log_success "Committed: ${commit_msg}"
        else
            log_warning "git commit failed — continuing anyway"
        fi
    )
}

# ============================================================
# Phase 1: Execute all tasks
# ============================================================

run_phase1() {
    local project_dir="$1"

    local progress_file task_file
    progress_file=$(find_latest_progress "$project_dir")
    task_file=$(find_latest_task "$project_dir")

    if [[ -z "$progress_file" ]] || [[ -z "$task_file" ]]; then
        log_error "No task/progress files in $project_dir/docs/plans/"
        log_error "Run /createTasks first."
        return 1
    fi

    local progress_n task_n
    progress_n=$(basename "$progress_file" | sed -E 's/progress([0-9]+)\.md/\1/')
    task_n=$(basename "$task_file" | sed -E 's/task([0-9]+)\.md/\1/')

    local stats total done_count blocked pending
    stats=$(count_tasks "$progress_file")
    IFS='|' read -r total done_count blocked pending <<< "$stats"

    log_info "Progress: progress${progress_n}.md | Task: task${task_n}.md"
    log_info "Status: ${total} total | ${done_count} done | ${blocked} blocked | ${pending} pending"

    if [[ "$pending" -eq 0 ]]; then
        if [[ "$blocked" -gt 0 ]]; then
            log_warning "No pending tasks, but ${blocked} blocked:"
            command grep -E '^- \[~\]' "$progress_file" | while read -r line; do
                echo "  ${YELLOW}[~]${NC} $line"
            done
        else
            log_success "All ${total} tasks done. Skipping Phase 1."
        fi
        return 0
    fi

    # Warn about blocked tasks (will be skipped)
    local blocked_list
    blocked_list=$(find_blocked_before_pending "$progress_file")
    if [[ -n "$blocked_list" ]]; then
        echo ""
        log_warning "Blocked tasks detected (will be skipped):"
        echo "$blocked_list" | while read -r line; do
            echo -e "  ${YELLOW}[~]${NC} $(echo "$line" | sed 's/^- \[~\] //')"
        done
        echo ""
    fi

    local total_completed=0
    local total_failed=0

    while true; do
        # Re-read progress file (may have been updated by last agent run)
        stats=$(count_tasks "$progress_file")
        IFS='|' read -r total done_count blocked pending <<< "$stats"

        if [[ "$pending" -eq 0 ]]; then
            echo ""
            log_success "All pending tasks completed. Phase 1 done."
            break
        fi

        local task_info
        task_info=$(find_first_pending "$progress_file")

        if [[ -z "$task_info" ]]; then
            # Check if blocked tasks remain
            if command grep -qE '^- \[~\] \*\*Task ' "$progress_file"; then
                log_warning "Only blocked tasks remain. Resolve them manually."
                command grep -E '^- \[~\]' "$progress_file" | head -5
            fi
            log_success "No more pending tasks."
            break
        fi

        local module task_num title
        IFS='|' read -r module task_num title <<< "$task_info"

        show_task_header "$progress_file" "$module" "$task_num" "$title"

        log_info "启动: $(date '+%H:%M:%S') | 超时: ${TASK_TIMEOUT}s | 工具: ${PRIORITY_BINS[*]}"

        local task_success=false
        local last_error_type="UNKNOWN"
        local last_stderr=""
        local tried_tools=()

        # Try each tool in priority order
        local tool_idx
        for tool_idx in $(seq 0 $((${#PRIORITY_TOOLS[@]} - 1))); do
            local tool_cmd="${PRIORITY_TOOLS[$tool_idx]}"
            local tool_bin="${PRIORITY_BINS[$tool_idx]}"

            # Skip unavailable tools
            if ! command -v "$tool_bin" &>/dev/null; then
                continue
            fi

            tried_tools+=("$tool_bin")

            local retry=0
            local prompt

            while [[ $retry -lt $MAX_RETRIES ]]; do
                if [[ $retry -eq 0 ]]; then
                    prompt=$(build_task_prompt "$progress_n" "$task_n")
                else
                    log_warning "Retry ${retry}/${MAX_RETRIES} for Task ${module}.${task_num} (${tool_bin})..."
                    prompt=$(build_retry_prompt "$progress_n" "$task_n" "$module" "$task_num" "$((retry+1))")
                fi

                local stderr_file
                stderr_file=$(mktemp)
                local exit_code=0

                # Full timeout for first attempt, reduced for retries
                # (retries first check if task already done — should be fast)
                local effective_timeout
                if [[ $retry -eq 0 ]]; then
                    effective_timeout="$TASK_TIMEOUT"
                else
                    effective_timeout=120
                    log_info "Retry uses reduced timeout: ${effective_timeout}s"
                fi

                set +e
                execute_agent "$project_dir" "$prompt" "$tool_cmd" "$stderr_file" "$effective_timeout" \
                    "$progress_file" "$module" "$task_num"
                exit_code=$?
                set -e

                # Check task completion regardless of exit code
                # (timeout may kill process after work is done but before cleanup)
                if verify_task_completed "$progress_file" "$module" "$task_num"; then
                    rm -f "$stderr_file"
                    if [[ $exit_code -ne 0 ]]; then
                        if is_timeout_exit "$exit_code"; then
                            log_info "Task completed despite timeout — progress file confirms [x]"
                        else
                            log_info "Task completed despite exit code ${exit_code} — progress file confirms [x]"
                        fi
                    fi
                    log_success "Task ${module}.${task_num} verified complete (via ${tool_bin})."
                    task_success=true

                    # Enforce git commit — script is authoritative
                    commit_task_changes "$project_dir" "$module" "$task_num" "$title"

                    break 2  # break out of both retry loop AND tool loop
                fi

                # Capture stderr for error classification
                last_stderr=$(cat "$stderr_file" 2>/dev/null || echo "")
                rm -f "$stderr_file"

                if is_timeout_exit "$exit_code"; then
                    last_error_type="TIMEOUT"
                    log_warning "${tool_bin} 退出码 ${exit_code} — TIMEOUT (${TASK_TIMEOUT}s)"
                elif [[ $exit_code -ne 0 ]]; then
                    last_error_type=$(classify_error "$last_stderr")
                    log_warning "${tool_bin} 退出码 ${exit_code} — ${last_error_type}"
                    # Show snippet of stderr for debugging
                    if [[ -n "$last_stderr" ]]; then
                        echo -e "  ${YELLOW}$(echo "$last_stderr" | tail -3)${NC}"
                    fi
                else
                    log_warning "Progress file not updated — task may not have completed"
                    last_error_type="UNKNOWN"
                fi

                ((retry++))
            done

            # Tool exhausted its retries — explain and fallback
            explain_error "$last_error_type" "$tool_bin"
        done

        if [[ "$task_success" != "true" ]]; then
            log_error "Task ${module}.${task_num} FAILED — 已尝试: ${tried_tools[*]}"
            log_error "Check progress file and git log for partial work."
            log_error "Fix issues manually, then re-run justdoit.sh to continue."
            ((total_failed++))
            return 1
        fi

        ((total_completed++))
        sleep "$SLEEP_BETWEEN_TASKS"
    done
}

# ============================================================
# Phase 2: Generate acceptance docs
# ============================================================

run_phase2() {
    local project_dir="$1"

    local task_file
    task_file=$(find_latest_task "$project_dir")

    if [[ -z "$task_file" ]]; then
        log_error "No task file found."
        return 1
    fi

    local task_n
    task_n=$(basename "$task_file" | sed -E 's/task([0-9]+)\.md/\1/')

    local prompt
    prompt=$(build_phase2_prompt "$task_n")

    log_step "Generating dual-track acceptance docs..."
    log_info "This may take a moment..."

    if ! run_with_fallback "$project_dir" "$prompt" "Phase 2"; then
        return 1
    fi

    # Find the generated docs
    local human_doc agent_doc
    human_doc=$(ls -t "$project_dir/docs/plans/acceptance-"*".md" 2>/dev/null | command grep -v '\-agent\.md$' | head -1 || echo "")
    agent_doc=$(ls -t "$project_dir/docs/plans/acceptance-"*"-agent.md" 2>/dev/null | head -1 || echo "")

    if [[ -z "$human_doc" ]]; then
        log_warning "Human acceptance doc not found. Check docs/plans/."
    else
        log_success "Human doc: $(basename "$human_doc")"
    fi

    if [[ -z "$agent_doc" ]]; then
        log_warning "Agent acceptance doc not found. Check docs/plans/."
        return 1
    fi

    log_success "Agent doc: $(basename "$agent_doc")"

    # Return feature name for Phase 3
    basename "$agent_doc" | sed -E 's/^acceptance-(.*)-agent\.md$/\1/'
}

# ============================================================
# Phase 3: Execute agent acceptance checks
# ============================================================

run_phase3() {
    local project_dir="$1"
    local feature="$2"

    # Auto-discover if not passed
    if [[ -z "$feature" ]]; then
        local agent_doc
        agent_doc=$(ls -t "$project_dir/docs/plans/acceptance-"*"-agent.md" 2>/dev/null | head -1 || echo "")
        if [[ -z "$agent_doc" ]]; then
            log_error "No agent acceptance doc found."
            return 1
        fi
        feature=$(basename "$agent_doc" | sed -E 's/^acceptance-(.*)-agent\.md$/\1/')
    fi

    log_info "Feature: ${feature}"

    local prompt
    prompt=$(build_phase3_prompt "$feature")

    log_step "Executing agent acceptance checks..."
    log_info "Running CLI commands — may take a moment..."

    if run_with_fallback "$project_dir" "$prompt" "Phase 3"; then
        log_success "Agent checks executed."
    else
        log_warning "Agent checks completed with issues"
    fi

    log_info "Results: docs/plans/acceptance-${feature}-agent.md"
}

# ============================================================
# Main
# ============================================================

show_help() {
    cat <<EOF
Usage: ./justdoit.sh [project_dir]

ekscoding 一键任务执行 + 验收脚本

每任务超时: ${TASK_TIMEOUT}s（可在 .justdoitrc 覆盖 TASK_TIMEOUT，0 = 禁用）
Phase 1: 逐任务执行（优先级: ${PRIORITY_BINS[*]}）
Phase 2: 生成双轨验收文档
Phase 3: 执行 agent 验收检查

Options:
  --help, -h           Show this help
  --tool <name>        Use specific AI CLI: claude, codex, gemini
                       (overrides priority list from .justdoitrc)

Examples:
  ./justdoit.sh                                  # Current directory, use priority list
  ./justdoit.sh ~/my-project                     # Specific project
  ./justdoit.sh --tool codex                     # Force codex only
  ./justdoit.sh --tool claude ~/my-project       # Force claude, specific project
EOF
}

main() {
    local specified_tool=""

    # Parse flags
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --help|-h)
                show_help
                exit 0
                ;;
            --tool)
                specified_tool="$2"
                if ! is_valid_tool "$specified_tool"; then
                    log_error "Unknown tool: $specified_tool (valid: claude, codex, gemini)"
                    exit 1
                fi
                shift 2
                ;;
            --tool=*)
                specified_tool="${1#*=}"
                if ! is_valid_tool "$specified_tool"; then
                    log_error "Unknown tool: $specified_tool (valid: claude, codex, gemini)"
                    exit 1
                fi
                shift
                ;;
            *)
                break
                ;;
        esac
    done

    local project_dir="${1:-$(pwd)}"

    # Resolve to absolute path
    project_dir="$(cd "$project_dir" 2>/dev/null && pwd)" || {
        log_error "Cannot access: $project_dir"
        exit 1
    }

    # Override priority list if --tool specified
    if [[ -n "$specified_tool" ]]; then
        PRIORITY_TOOLS=("$(get_tool_cmd "$specified_tool")")
        PRIORITY_BINS=("$specified_tool")
        if ! command -v "$specified_tool" &>/dev/null; then
            log_error "Tool not found in PATH: $specified_tool"
            exit 1
        fi
        log_info "Using specified tool: $specified_tool"
    fi

    echo ""
    echo -e "${PURPLE}╔══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${PURPLE}║${NC}  ekscoding — justdoit.sh                                ${PURPLE}║${NC}"
    printf "${PURPLE}║${NC}  Project: %-48s ${PURPLE}║${NC}\n" "$(basename "$project_dir")"
    echo -e "${PURPLE}╚══════════════════════════════════════════════════════════╝${NC}"

    validate_environment "$project_dir" || exit 1

    # Prevent system sleep while running
    start_sleep_prevention

    # ---- Phase 1: Execute all tasks ----
    show_phase_banner "1" "Execute All Pending Tasks"
    if ! run_phase1 "$project_dir"; then
        echo ""
        log_error "Phase 1 did not complete."
        log_info "Re-run justdoit.sh to continue from next pending task."
        exit 1
    fi

    # ---- Phase 2: Generate acceptance docs ----
    show_phase_banner "2" "Generate Acceptance Documentation"
    local feature
    feature=$(run_phase2 "$project_dir") || {
        echo ""
        log_error "Phase 2 failed."
        exit 1
    }

    # ---- Phase 3: Execute agent checks ----
    show_phase_banner "3" "Execute Agent Acceptance Checks"
    run_phase3 "$project_dir" "$feature" || {
        echo ""
        log_error "Phase 3 failed."
        exit 1
    }

    # ---- Summary ----
    local progress_file
    progress_file=$(find_latest_progress "$project_dir")
    show_summary "$progress_file"

    echo "Acceptance docs:"
    ls -la "$project_dir/docs/plans/acceptance-"*.md 2>/dev/null | while read -r line; do
        echo "  $line"
    done || true
    echo ""
    log_success "Done."
}

main "$@"
