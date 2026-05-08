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

get_tool_skill_path() {
    case "$1" in
        claude)   echo "$HOME/.claude/skills" ;;
        codex)    echo "$HOME/.codex/skills" ;;
        openclaw) echo "$HOME/.openclaw/workspace/skills" ;;
        gemini)   echo "$HOME/.gemini/skills" ;;
    esac
}

detect_tools() {
    local tools=()
    for tool in claude codex openclaw gemini; do
        local dir
        dir=$(get_tool_skill_path "$tool")
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
          "$SCRIPT_DIR/workflows" \
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
            local link_dir
            link_dir=$(get_tool_skill_path "$tool")
            local link_path="$link_dir/$SKILL_NAME"

            mkdir -p "$link_dir"

            if [ -e "$link_path" ]; then
                if [ -L "$link_path" ] && [ "$(readlink "$link_path")" = "$target_dir" ]; then
                    log_info "$tool: 链接已正确"
                    continue
                fi
                log_warn "$tool: 覆盖已有文件"
                rm -rf "$link_path"
            fi

            ln -s "$target_dir" "$link_path"
            log_success "$tool: 已链接"
        done
    fi

    # ============================================================
    # Step 3: Choose AI CLI tool
    # ============================================================
    echo ""
    separator
    echo -e "  ${PURPLE}Step 3/4${NC} — 选择 AI CLI 工具"
    separator
    echo ""
    echo "  justdoit 需要调用 AI CLI 来执行任务。"
    echo "  选择你常用的工具："
    echo ""
    echo "  1) Claude Code    (claude -p --permission-mode bypassPermissions)"
    echo "  2) Codex (OpenAI) (codex exec)"
    echo "  3) Gemini         (gemini -p)"
    echo "  4) 自定义命令"
    echo ""

    local agent_cli
    if $non_interactive; then
        agent_cli="claude -p --permission-mode bypassPermissions"
        log_info "使用默认: Claude Code"
    else
        clear_input
        read -p "  请选择 (1-4) [1]: " -r REPLY
        REPLY=${REPLY:-1}

        case "$REPLY" in
            1) agent_cli="claude -p --permission-mode bypassPermissions" ;;
            2) agent_cli="codex exec" ;;
            3) agent_cli="gemini -p" ;;
            4)
                clear_input
                read -p "  请输入完整的 CLI 命令 (如: opencode -p): " -r agent_cli
                ;;
            *) agent_cli="claude -p --permission-mode bypassPermissions" ;;
        esac
    fi

    # Save tool config for justdoit.sh
    echo "# ekscoding tool config" > "$target_dir/.justdoitrc"
    echo "AGENT_CLI=\"$agent_cli\"" >> "$target_dir/.justdoitrc"
    log_success "工具配置: $agent_cli"

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
        local link_dir
        link_dir=$(get_tool_skill_path "$tool")
        local link_path="$link_dir/$SKILL_NAME"

        if [ -L "$link_path" ] && [ "$(readlink "$link_path")" = "$target_dir" ]; then
            rm "$link_path"
            log_success "移除链接: $tool"
        fi
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
            local agent_cli
            agent_cli=$(grep "AGENT_CLI=" "$rc_file" 2>/dev/null | sed 's/.*AGENT_CLI="\(.*\)"/\1/' || echo "unknown")
            log_info "AI CLI 工具: $agent_cli"
        fi
    else
        log_warn "Skill 未安装"
    fi

    # Tool symlinks
    echo ""
    echo "AI 工具链接:"
    local found_tool=false
    for tool in $(detect_tools); do
        local link_dir
        link_dir=$(get_tool_skill_path "$tool")
        local link_path="$link_dir/$SKILL_NAME"

        if [ -L "$link_path" ]; then
            echo -e "  ${GREEN}✓${NC} $tool → $(readlink "$link_path")"
            found_tool=true
        else
            echo -e "  ${YELLOW}○${NC} $tool"
        fi
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
