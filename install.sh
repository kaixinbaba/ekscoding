#!/bin/bash
set -euo pipefail

# ============================================================
# install.sh — ekscoding skill 安装器
#
# 用法:
#   ./install.sh                  # 默认安装
#   ./install.sh --dir /path      # 指定安装目录
#   ./install.sh uninstall        # 卸载
#   ./install.sh status           # 查看状态
# ============================================================

SKILL_NAME="ekscoding"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DEFAULT_INSTALL_DIR="$HOME/.my-skills/skills"

# Color
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; NC='\033[0m'

log_info()    { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[OK]${NC} $1"; }
log_warn()    { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error()   { echo -e "${RED}[ERROR]${NC} $1"; }

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
# Install
# ============================================================

cmd_install() {
    local install_dir="${1:-$DEFAULT_INSTALL_DIR}"

    echo ""
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}  ekscoding skill installer                              ${CYAN}║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════╝${NC}"
    echo ""

    # Validate source
    local source_dir="$SCRIPT_DIR"
    if [ ! -f "$source_dir/SKILL.md" ]; then
        log_error "SKILL.md not found in $source_dir"
        log_error "Run this script from the ekscoding repo root"
        return 1
    fi

    # Step 1: Copy skill to install dir
    local target_dir="$install_dir/$SKILL_NAME"
    log_info "Install dir: $target_dir"

    if [ -d "$target_dir" ]; then
        log_warn "Target already exists, overwriting..."
        rm -rf "$target_dir"
    fi

    mkdir -p "$install_dir"
    cp -r "$source_dir/SKILL.md" \
          "$source_dir/README.md" \
          "$source_dir/justdoit.sh" \
          "$source_dir/workflows" \
          "$source_dir/templates" \
          "$target_dir"
    log_success "Copied skill to $target_dir"

    # Step 2: Detect tools and create symlinks
    local tools
    tools=($(detect_tools))

    if [ ${#tools[@]} -eq 0 ]; then
        log_warn "No supported AI tools detected"
        echo ""
        echo "Supported tools: claude, codex, openclaw, gemini"
        echo "  Detectable by presence of ~/.claude/, ~/.codex/, etc."
        echo "  If your tool dir exists but wasn't detected, create symlink manually:"
        echo "  ln -s $target_dir <your-tool-skills-dir>/$SKILL_NAME"
        echo ""
        log_success "Install complete (no symlinks created)"
        return 0
    fi

    echo ""
    log_info "Detected tools: ${tools[*]}"

    for tool in "${tools[@]}"; do
        local link_dir
        link_dir=$(get_tool_skill_path "$tool")
        local link_path="$link_dir/$SKILL_NAME"

        mkdir -p "$link_dir"

        if [ -e "$link_path" ]; then
            if [ -L "$link_path" ] && [ "$(readlink "$link_path")" = "$target_dir" ]; then
                log_info "Link already correct: $link_path"
                continue
            fi
            log_warn "Overwriting existing: $link_path"
            rm -rf "$link_path"
        fi

        ln -s "$target_dir" "$link_path"
        log_success "Linked: $link_path -> $target_dir"
    done

    echo ""
    log_success "Install complete!"
    log_info "Skill dir: $target_dir"
}

# ============================================================
# Uninstall
# ============================================================

cmd_uninstall() {
    local install_dir="${1:-$DEFAULT_INSTALL_DIR}"
    local target_dir="$install_dir/$SKILL_NAME"

    echo ""
    log_warn "This will remove:"
    echo "  - $target_dir"
    echo "  - All symlinks pointing to it"

    read -p "Continue? (y/N): " -r REPLY
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "Cancelled"
        return 0
    fi

    # Remove symlinks
    for tool in $(detect_tools); do
        local link_dir
        link_dir=$(get_tool_skill_path "$tool")
        local link_path="$link_dir/$SKILL_NAME"

        if [ -L "$link_path" ] && [ "$(readlink "$link_path")" = "$target_dir" ]; then
            rm "$link_path"
            log_success "Removed symlink: $link_path"
        fi
    done

    # Remove install dir
    if [ -d "$target_dir" ]; then
        rm -rf "$target_dir"
        log_success "Removed: $target_dir"
    fi

    echo ""
    log_success "Uninstall complete"
}

# ============================================================
# Status
# ============================================================

cmd_status() {
    local install_dir="${1:-$DEFAULT_INSTALL_DIR}"
    local target_dir="$install_dir/$SKILL_NAME"

    echo ""
    echo -e "${CYAN}═══ ekscoding status ═══${NC}"
    echo ""

    if [ -d "$target_dir" ] && [ -f "$target_dir/SKILL.md" ]; then
        log_success "Installed: $target_dir"
    else
        log_warn "Not installed (run './install.sh install')"
    fi

    echo ""
    echo "Symlinks:"
    local found_any=false
    for tool in $(detect_tools); do
        local link_dir
        link_dir=$(get_tool_skill_path "$tool")
        local link_path="$link_dir/$SKILL_NAME"

        if [ -L "$link_path" ]; then
            echo -e "  ${GREEN}✓${NC} $link_path -> $(readlink "$link_path")"
            found_any=true
        else
            echo -e "  ${YELLOW}○${NC} $link_path (not linked)"
        fi
    done

    if ! $found_any; then
        echo "  (none)"
    fi
    echo ""
}

# ============================================================
# Main
# ============================================================

main() {
    local cmd="${1:-install}"
    local install_dir="$DEFAULT_INSTALL_DIR"

    # Parse --dir flag
    for arg in "$@"; do
        case "$arg" in
            --dir)
                shift
                install_dir="$1"
                ;;
        esac
        shift 2>/dev/null || true
    done

    case "$cmd" in
        install|"")
            cmd_install "$install_dir"
            ;;
        uninstall)
            cmd_uninstall "$install_dir"
            ;;
        status)
            cmd_status "$install_dir"
            ;;
        --help|-h|help)
            echo "Usage: ./install.sh [install|uninstall|status] [--dir /path]"
            ;;
        *)
            log_error "Unknown command: $cmd"
            echo "Usage: ./install.sh [install|uninstall|status] [--dir /path]"
            exit 1
            ;;
    esac
}

main "$@"
