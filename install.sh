#!/bin/bash
set -euo pipefail

# ============================================================
# install.sh — ekscoding skill 安装器
#
# 用法:
#   ./install.sh              # 交互式安装
#   ./install.sh --yes        # 非交互，全部用默认值
#   ./install.sh status       # 查看状态
#   ./install.sh uninstall    # 卸载
# ============================================================

SKILL_NAME="ekscoding"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DEFAULT_INSTALL_DIR="$HOME/.my-skills/skills"

# Color
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; PURPLE='\033[0;35m'; NC='\033[0m'

log_info()    { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[OK]${NC} $1"; }
log_warn()    { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error()   { echo -e "${RED}[ERROR]${NC} $1"; }
log_step()    { echo -e "${CYAN}→${NC} $1"; }
separator()   { echo -e "${BLUE}────────────────────────────────────────────────────────────${NC}"; }

# ============================================================
# Tool detection
# ============================================================

get_tool_skill_paths() {
    case "$1" in
        claude)   echo "$HOME/.claude/skills" ;;
        codex)    echo "$HOME/.codex/skills" ;;
        openclaw) echo "$HOME/.openclaw/workspace/skills"
                  echo "$HOME/.openclaw/workspace/.agents/skills" ;;
        gemini)   echo "$HOME/.gemini/skills" ;;
    esac
}

detect_tools() {
    local tools=()
    for tool in claude codex openclaw gemini; do
        local dir
        dir=$(get_tool_skill_paths "$tool" | head -1)
        if [ -d "$(dirname "$dir")" ]; then
            tools+=("$tool")
        fi
    done
    echo "${tools[@]}"
}

# ============================================================
# PATH detection for justdoit global install
# ============================================================

get_best_path_dir() {
    if [ -d "/usr/local/bin" ] && [ -w "/usr/local/bin" ]; then
        echo "/usr/local/bin"
    elif [ -d "$HOME/.local/bin" ]; then
        echo "$HOME/.local/bin"
    else
        echo "$HOME/.local/bin"
    fi
}

is_in_path() {
    echo "$PATH" | tr ':' '\n' | grep -qF "$1"
}

detect_shell_rc() {
    case "$(basename "$SHELL")" in
        zsh)  echo "$HOME/.zshrc" ;;
        bash) echo "$HOME/.bashrc" ;;
        *)    echo "$HOME/.zshrc" ;;
    esac
}

# ============================================================
# Interactive helpers
# ============================================================

clear_input() {
    while read -t 0.1 -r; do :; done 2>/dev/null || true
}

confirm() {
    local prompt="$1"
    local default="${2:-Y}"
    clear_input
    read -p "$prompt " -r REPLY
    [[ -z "$REPLY" && "$default" = "Y" ]] && return 0
    [[ $REPLY =~ ^[Yy]$ ]]
}

# ============================================================
# Install
# ============================================================

cmd_install() {
    local non_interactive="$1"
    local install_dir="$2"

    echo ""
    echo -e "${PURPLE}╔══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${PURPLE}║${NC}     ekscoding skill installer                            ${PURPLE}║${NC}"
    echo -e "${PURPLE}╚══════════════════════════════════════════════════════════╝${NC}"
    echo ""

    # Validate source
    if [ ! -f "$SCRIPT_DIR/SKILL.md" ]; then
        log_error "SKILL.md not found in $SCRIPT_DIR"
        log_error "Run this script from the ekscoding repo root"
        return 1
    fi

    # ============================================================
    # Step 1: Choose install directory
    # ============================================================
    echo ""
    separator
    echo -e "  ${PURPLE}Step 1/4${NC} — 选择 Skill 安装目录"
    separator
    echo ""
    echo "  Skill 文件会安装到这个目录，作为所有 AI 工具的统一存储位置。"
    echo ""

    if $non_interactive; then
        log_info "使用默认目录: $install_dir"
    else
        echo "  1) 默认: $DEFAULT_INSTALL_DIR"
        echo "  2) 自定义目录"
        echo ""
        clear_input
        read -p "  请选择 (1/2) [1]: " -r REPLY
        REPLY=${REPLY:-1}

        if [ "$REPLY" = "2" ]; then
            clear_input
            read -p "  请输入目录路径: " -r install_dir
            if [ -z "$install_dir" ]; then
                log_error "目录不能为空"
                return 1
            fi
        else
            install_dir="$DEFAULT_INSTALL_DIR"
        fi
    fi

    local target_dir="$install_dir/$SKILL_NAME"
    echo ""
    log_info "安装目录: $target_dir"

    # ============================================================
    # Step 2: Copy skill & create AI tool symlinks
    # ============================================================
    echo ""
    separator
    echo -e "  ${PURPLE}Step 2/4${NC} — 安装 Skill 文件 & 工具链接"
    separator
    echo ""

    if [ -e "$target_dir" ] || [ -L "$target_dir" ]; then
        log_warn "目标路径已存在，将覆盖"
        rm -rf "$target_dir"
    fi

    mkdir -p "$target_dir"
    cp -r "$SCRIPT_DIR/SKILL.md" \
          "$SCRIPT_DIR/README.md" \
          "$SCRIPT_DIR/justdoit.sh" \
          "$SCRIPT_DIR/agents-link.sh" \
          "$SCRIPT_DIR/references" \
          "$SCRIPT_DIR/templates" \
          "$target_dir"
    log_success "已复制 skill 文件到 $target_dir"

    local tools
    tools=($(detect_tools))

    if [ ${#tools[@]} -eq 0 ]; then
        echo ""
        log_warn "未检测到已知 AI 工具目录"
        echo "  支持: claude (~/.claude/), codex (~/.codex/), openclaw (~/.openclaw/), gemini (~/.gemini/)"
        echo "  手动创建软链接: ln -s $target_dir <工具-skills-目录>/$SKILL_NAME"
    else
        echo ""
        for tool in "${tools[@]}"; do
            while IFS= read -r link_dir; do
                local link_path="$link_dir/$SKILL_NAME"

                mkdir -p "$link_dir"

                if [ -e "$link_path" ]; then
                    if [ -L "$link_path" ] && [ "$(readlink "$link_path")" = "$target_dir" ]; then
                        log_info "$tool: 链接已正确 ($link_dir)"
                        continue
                    fi
                    log_warn "$tool: 覆盖已有文件 ($link_dir)"
                    rm -rf "$link_path"
                fi

                ln -s "$target_dir" "$link_path"
                log_success "$tool: 已链接 ($link_dir)"
            done < <(get_tool_skill_paths "$tool")
        done
    fi

    # ============================================================
    # Step 3: AI CLI tool priority ordering
    # ============================================================
    echo ""
    separator
    echo -e "  ${PURPLE}Step 3/4${NC} — AI CLI 工具优先级排序"
    separator
    echo ""
    echo "  justdoit 会按优先级顺序调用 AI CLI，当前工具失败时自动切换下一个。"
    echo ""

    # Known tool CLIs — binary name and full command
    local known_labels=()
    local known_bins=()
    local known_cmds=()
    for entry in \
        "Claude Code|claude|claude -p --permission-mode bypassPermissions" \
        "Codex|codex|codex exec" \
        "OpenCode|opencode|opencode run" \
        "Gemini|gemini|gemini -p" \
    ; do
        local label bin cmd
        IFS='|' read -r label bin cmd <<< "$entry"
        known_labels+=("$label")
        known_bins+=("$bin")
        known_cmds+=("$cmd")
    done

    # Detect installed tools
    local detected_indices=()  # indices into known_* arrays
    local i
    for i in $(seq 0 $((${#known_bins[@]} - 1))); do
        if command -v "${known_bins[$i]}" &>/dev/null; then
            detected_indices+=("$i")
        fi
    done

    local priority_cmds=()

    if $non_interactive; then
        # Default: claude first, then whatever is detected
        priority_cmds=("claude -p --permission-mode bypassPermissions")
        for idx in "${detected_indices[@]}"; do
            local cmd="${known_cmds[$idx]}"
            if [[ "$cmd" != "claude -p --permission-mode bypassPermissions" ]]; then
                priority_cmds+=("$cmd")
            fi
        done
        log_info "使用默认优先级: ${priority_cmds[*]}"

    elif [ ${#detected_indices[@]} -eq 0 ]; then
        log_warn "未检测到已知 AI CLI 工具"
        echo "  输入数字序号排列优先级，失败时自动切换下一个工具。"
        echo ""
        for i in $(seq 1 ${#known_labels[@]}); do
            local idx=$((i-1))
            echo "  ${i}) ${known_labels[$idx]}    (${known_cmds[$idx]})"
        done
        echo "  5) 自定义命令"
        echo ""
        echo "  默认顺序: 1234 (Claude Code → Codex → OpenCode → Gemini)"
        echo ""
        clear_input
        read -p "  请输入数字序号排序 [1234]: " -r REPLY
        REPLY=${REPLY:-1234}

        priority_cmds=()
        local seen=()
        local j
        for (( j=0; j<${#REPLY}; j++ )); do
            local ch="${REPLY:$j:1}"
            case "$ch" in
                1|2|3|4)
                    local idx=$((ch-1))
                    priority_cmds+=("${known_cmds[$idx]}")
                    ;;
                5)
                    echo ""
                    clear_input
                    read -p "  请输入自定义 CLI 命令 (如: mycli -p --bypass): " -r custom_cmd
                    if [[ -n "$custom_cmd" ]]; then
                        priority_cmds+=("$custom_cmd")
                    fi
                    ;;
                *) ;; # skip invalid chars
            esac
        done

    elif [ ${#detected_indices[@]} -eq 1 ]; then
        local idx="${detected_indices[0]}"
        local label="${known_labels[$idx]}"
        local bin="${known_bins[$idx]}"
        local cmd="${known_cmds[$idx]}"
        echo "  检测到: ${GREEN}${label}${NC} ($bin)"
        echo ""
        echo "  没有其他工具可 fallback。可额外添加自定义命令作为备用。"
        echo ""
        echo "  1) 仅使用 ${label}"
        echo "  2) ${label} + 自定义备用命令"
        echo ""
        clear_input
        read -p "  请选择 (1/2) [1]: " -r REPLY
        REPLY=${REPLY:-1}
        if [ "$REPLY" = "2" ]; then
            clear_input
            read -p "  请输入自定义备用 CLI 命令 (如: mycli -p --bypass): " -r custom_cmd
            priority_cmds=("$cmd" "$custom_cmd")
        else
            priority_cmds=("$cmd")
        fi
        log_success "已选择: ${label}"

    else
        echo "  检测到以下已安装的工具："
        echo ""
        local menu_idx=1
        local menu_to_known=()
        local shown_bins=()
        for idx in "${detected_indices[@]}"; do
            echo "  ${menu_idx}) ${known_labels[$idx]}    (${known_cmds[$idx]})"
            menu_to_known+=("$idx")
            shown_bins+=("${known_bins[$idx]}")
            ((menu_idx++))
        done
        echo "  ${menu_idx}) 自定义命令"
        local max_menu=$menu_idx
        echo ""
        echo "  输入数字序号按优先级排序，失败时自动切换下一个。"
        printf "  e.g. \""
        for m in $(seq 1 ${#menu_to_known[@]}); do
            printf "$m"
        done
        echo "\" = ${known_labels[${menu_to_known[0]}]} → ... (默认顺序)"
        echo ""

        clear_input
        read -p "  请输入数字序号排序: " -r REPLY

        if [[ -z "$REPLY" ]]; then
            # Default: as shown
            for idx in "${menu_to_known[@]}"; do
                priority_cmds+=("${known_cmds[$idx]}")
            done
        else
            priority_cmds=()
            local j
            for (( j=0; j<${#REPLY}; j++ )); do
                local ch="${REPLY:$j:1}"
                if [[ "$ch" =~ [1-9] ]]; then
                    local choice=$ch
                    if [ "$choice" -ge 1 ] 2>/dev/null && [ "$choice" -le "$max_menu" ]; then
                        if [ "$choice" -eq "$max_menu" ]; then
                            echo ""
                            clear_input
                            read -p "  请输入自定义 CLI 命令 (如: mycli -p --bypass): " -r custom_cmd
                            if [[ -n "$custom_cmd" ]]; then
                                priority_cmds+=("$custom_cmd")
                            fi
                        else
                            local orig_idx=$((choice-1))
                            local kd_idx="${menu_to_known[$orig_idx]}"
                            priority_cmds+=("${known_cmds[$kd_idx]}")
                        fi
                    fi
                fi
            done
        fi
    fi

    if [ ${#priority_cmds[@]} -eq 0 ]; then
        log_error "未选择任何工具，取消安装"
        return 1
    fi

    # Save tool config for justdoit.sh
    echo "# ekscoding tool config — priority-ordered AI CLI tools" > "$target_dir/.justdoitrc"
    echo "# Fallback: if tool N fails, try tool N+1" >> "$target_dir/.justdoitrc"
    echo "AGENT_CLI_PRIORITY=(" >> "$target_dir/.justdoitrc"
    for cmd in "${priority_cmds[@]}"; do
        echo "  \"$cmd\"" >> "$target_dir/.justdoitrc"
    done
    echo ")" >> "$target_dir/.justdoitrc"
    # Backward compat
    echo "AGENT_CLI=\"${priority_cmds[0]}\"" >> "$target_dir/.justdoitrc"
    echo "" >> "$target_dir/.justdoitrc"
    echo "# TASK_TIMEOUT=1800  # uncomment to override (seconds, 0 = no timeout)" >> "$target_dir/.justdoitrc"

    echo ""
    log_success "优先级配置 (${#priority_cmds[@]} 个工具):"
    for i in $(seq 0 $((${#priority_cmds[@]} - 1))); do
        echo "  $((i+1)). ${priority_cmds[$i]}"
    done

    # ============================================================
    # Step 4: Install justdoit as global command
    # ============================================================
    echo ""
    separator
    echo -e "  ${PURPLE}Step 4/4${NC} — 安装 justdoit 全局命令"
    separator
    echo ""
    echo "  justdoit.sh 是一键任务执行脚本。"
    echo "  安装为全局命令后，可以在任意项目目录直接使用："
    echo ""
    echo -e "    ${GREEN}justdoit${NC}              # 当前目录"
    echo -e "    ${GREEN}justdoit${NC} ~/my-project  # 指定项目"
    echo ""

    local install_justdoit=false
    if $non_interactive; then
        install_justdoit=true
    elif confirm "  安装 justdoit 为全局命令？ (Y/n): "; then
        install_justdoit=true
    else
        log_info "跳过全局命令安装"
        echo "  之后可手动添加别名: alias justdoit='$target_dir/justdoit.sh'"
    fi

    if $install_justdoit; then
        echo ""

        local path_dir
        if $non_interactive; then
            path_dir=$(get_best_path_dir)
        else
            # Show available PATH directories
            echo "  可用的 PATH 目录:"
            echo "  1) /usr/local/bin  $([ -w /usr/local/bin ] && echo '(可写)' || echo '(需要 sudo)')"
            echo "  2) ~/.local/bin     (推荐，用户目录无需 sudo)"
            echo "  3) ~/bin"
            echo "  4) 自定义"
            echo ""
            clear_input
            read -p "  请选择安装目录 [2]: " -r REPLY
            REPLY=${REPLY:-2}

            case "$REPLY" in
                1) path_dir="/usr/local/bin" ;;
                2) path_dir="$HOME/.local/bin" ;;
                3) path_dir="$HOME/bin" ;;
                4)
                    clear_input
                    read -p "  请输入目录路径: " -r path_dir
                    ;;
                *) path_dir="$HOME/.local/bin" ;;
            esac
        fi

        # Create dir if needed
        if [ ! -d "$path_dir" ]; then
            mkdir -p "$path_dir"
            log_info "创建目录: $path_dir"
        fi

        # Handle sudo
        local use_sudo=false
        if [ ! -w "$path_dir" ]; then
            echo ""
            log_warn "$path_dir 不可写，需要 sudo 权限"
            use_sudo=true
        fi

        # Remove old wrapper
        local wrapper="$path_dir/justdoit"
        if [ -e "$wrapper" ]; then
            if $use_sudo; then
                sudo rm -f "$wrapper"
            else
                rm -f "$wrapper"
            fi
        fi

        # Create wrapper script
        local wrapper_content='#!/bin/bash
# justdoit — ekscoding 一键任务执行 + 验收脚本
# Auto-generated by ekscoding install.sh
exec '"$target_dir"'/justdoit.sh "$@"
'
        if $use_sudo; then
            echo "$wrapper_content" | sudo tee "$wrapper" > /dev/null
            sudo chmod +x "$wrapper"
        else
            echo "$wrapper_content" > "$wrapper"
            chmod +x "$wrapper"
        fi

        log_success "全局命令已安装: $wrapper"

        # Check PATH
        if ! is_in_path "$path_dir"; then
            echo ""
            log_warn "$path_dir 不在 PATH 环境变量中"

            local shell_rc
            shell_rc=$(detect_shell_rc)

            if $non_interactive; then
                echo "export PATH=\"$path_dir:\$PATH\"" >> "$shell_rc"
                log_info "已添加到 $shell_rc"
            elif confirm "  自动添加到 $shell_rc？ (Y/n): "; then
                echo "" >> "$shell_rc"
                echo "# Added by ekscoding installer ($(date +%Y-%m-%d))" >> "$shell_rc"
                echo "export PATH=\"$path_dir:\$PATH\"" >> "$shell_rc"
                log_info "已添加，运行 'source $shell_rc' 或重开终端生效"
            else
                echo "  手动添加这一行到 shell 配置文件:"
                echo "  export PATH=\"$path_dir:\$PATH\""
            fi
        fi
    fi

    # ============================================================
    # Done
    # ============================================================
    echo ""
    separator
    echo ""
    log_success "安装完成！"
    echo ""
    echo "  Skill 目录:  $target_dir"
    if [ ${#tools[@]} -gt 0 ]; then
        echo "  AI 工具:     ${tools[*]}"
    fi
    if $install_justdoit; then
        echo "  全局命令:    justdoit"
        echo ""
        echo "  试试: justdoit --help"
    fi
    echo ""
    echo "  可用命令 (通过 AI 工具调用):"
    echo "    createTasks          拆分任务"
    echo "    doNextTask           执行下一个任务"
    echo "    doTasksUntil         执行到指定 Module"
    echo "    validateResult       生成验收文档"
    echo "    helpValidate         交互式验收引导"
    echo "    archiveHistory       归档任务历史"
    echo "    generateDeploymentChecklist  生成部署清单"
    echo "    htmlForStudy         代码逻辑可视化"
    echo "    logicmap             生成项目逻辑地图"
    echo "    agentslink           统一 agent 文件为 AGENTS.md"
    echo ""
    echo "  agents-link.sh 脚本: $target_dir/agents-link.sh"
    echo "  如需全局命令: ln -s $target_dir/agents-link.sh ~/.local/bin/agents-link"
    echo ""
}

# ============================================================
# Uninstall
# ============================================================

cmd_uninstall() {
    local install_dir="$1"
    local target_dir="$install_dir/$SKILL_NAME"

    echo ""
    if [ ! -d "$target_dir" ]; then
        log_warn "Skill 目录不存在: $target_dir"
        log_info "没有需要卸载的内容"
        return 0
    fi

    log_warn "将移除:"
    echo "  - $target_dir"
    echo "  - 所有指向它的 AI 工具软链接"
    echo "  - justdoit 全局命令"

    if ! confirm "确认卸载？ (y/N): " "N"; then
        log_info "已取消"
        return 0
    fi

    echo ""

    # Remove justdoit global command
    local search_dirs=("/usr/local/bin" "$HOME/.local/bin" "$HOME/bin")
    for dir in "${search_dirs[@]}"; do
        local wrapper="$dir/justdoit"
        if [ -f "$wrapper" ] && grep -qF "ekscoding" "$wrapper" 2>/dev/null; then
            if [ -w "$dir" ]; then
                rm -f "$wrapper"
            else
                sudo rm -f "$wrapper" 2>/dev/null || true
            fi
            log_success "移除: $wrapper"
        fi
    done

    # Remove AI tool symlinks
    for tool in $(detect_tools); do
        while IFS= read -r link_dir; do
            local link_path="$link_dir/$SKILL_NAME"

            if [ -L "$link_path" ] && [ "$(readlink "$link_path")" = "$target_dir" ]; then
                rm "$link_path"
                log_success "移除链接: $tool ($link_dir)"
            fi
        done < <(get_tool_skill_paths "$tool")
    done

    # Remove install dir
    rm -rf "$target_dir"
    log_success "移除目录: $target_dir"

    echo ""
    log_info "注: shell rc 文件中的 PATH 修改需手动清理（如曾添加过）"
    log_success "卸载完成"
}

# ============================================================
# Status
# ============================================================

cmd_status() {
    local install_dir="$1"
    local target_dir="$install_dir/$SKILL_NAME"

    echo ""
    echo -e "${CYAN}═══ ekscoding status ═══${NC}"
    echo ""

    # Skill install
    if [ -d "$target_dir" ] && [ -f "$target_dir/SKILL.md" ]; then
        log_success "Skill 已安装: $target_dir"

        # Tool config
        local rc_file="$target_dir/.justdoitrc"
        if [ -f "$rc_file" ]; then
            log_info "AI CLI 优先级:"
            # Read priority array
            local in_priority=false
            while IFS= read -r line; do
                if [[ "$line" == "AGENT_CLI_PRIORITY=("* ]]; then
                    in_priority=true
                    continue
                fi
                if $in_priority; then
                    if [[ "$line" == ")" ]]; then
                        break
                    fi
                    # Extract quoted command
                    local cmd
                    cmd=$(echo "$line" | sed -E 's/^[[:space:]]*"([^"]*)"[[:space:]]*$/\1/')
                    if [[ -n "$cmd" ]]; then
                        echo "    - $cmd"
                    fi
                fi
            done < "$rc_file"
            # Fallback: old format
            if ! $in_priority; then
                local agent_cli
                agent_cli=$(grep "AGENT_CLI=" "$rc_file" 2>/dev/null | sed 's/.*AGENT_CLI="\(.*\)"/\1/' || echo "unknown")
                echo "    - ${agent_cli}"
            fi
        fi
    else
        log_warn "Skill 未安装"
    fi

    # Tool symlinks
    echo ""
    echo "AI 工具链接:"
    local found_tool=false
    for tool in $(detect_tools); do
        while IFS= read -r link_dir; do
            local link_path="$link_dir/$SKILL_NAME"

            if [ -L "$link_path" ]; then
                echo -e "  ${GREEN}✓${NC} $tool ($link_dir) → $(readlink "$link_path")"
                found_tool=true
            else
                echo -e "  ${YELLOW}○${NC} $tool ($link_dir)"
            fi
        done < <(get_tool_skill_paths "$tool")
    done
    $found_tool || echo "  (none)"

    # justdoit global command
    echo ""
    echo "justdoit 全局命令:"
    local found_justdoit=false
    IFS=':' read -ra path_arr <<< "$PATH"
    for dir in "${path_arr[@]}"; do
        if [ -f "$dir/justdoit" ] && grep -qF "ekscoding" "$dir/justdoit" 2>/dev/null; then
            log_success "已安装: $dir/justdoit"
            found_justdoit=true
        fi
    done
    $found_justdoit || log_warn "未安装"
    echo ""
}

# ============================================================
# Help
# ============================================================

show_help() {
    cat <<EOF
ekscoding skill installer

Usage: ./install.sh [command] [flags]

Commands:
  install     交互式安装（默认）
  uninstall   卸载
  status      查看状态

Flags:
  --yes       非交互模式，全部使用默认值
  --dir PATH  指定 skill 安装目录（默认: $DEFAULT_INSTALL_DIR）

Examples:
  ./install.sh                      # 交互式安装
  ./install.sh --yes                # 默认配置快速安装
  ./install.sh --dir ~/my-skills    # 指定安装目录
  ./install.sh status               # 查看状态
  ./install.sh uninstall            # 卸载
EOF
}

# ============================================================
# Main
# ============================================================

INSTALL_DIR="$DEFAULT_INSTALL_DIR"
NON_INTERACTIVE=false
COMMAND="install"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --dir)
            INSTALL_DIR="$2"
            shift 2
            ;;
        --yes|-y)
            NON_INTERACTIVE=true
            shift
            ;;
        --help|-h|help)
            show_help
            exit 0
            ;;
        install|uninstall|status)
            COMMAND="$1"
            shift
            ;;
        *)
            log_error "未知参数: $1"
            show_help
            exit 1
            ;;
    esac
done

case "$COMMAND" in
    install)
        cmd_install "$NON_INTERACTIVE" "$INSTALL_DIR"
        ;;
    uninstall)
        cmd_uninstall "$INSTALL_DIR"
        ;;
    status)
        cmd_status "$INSTALL_DIR"
        ;;
esac
