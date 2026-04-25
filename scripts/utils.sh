#!/usr/bin/env bash
# utils.sh - Shared functions for claude-setup installer

set -euo pipefail

# ── Colors (disabled when stdout is not a TTY or NO_COLOR is set) ─────────
if [[ -t 1 ]] && [[ -z "${NO_COLOR:-}" ]]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    CYAN='\033[0;36m'
    BOLD='\033[1m'
    DIM='\033[2m'
    RESET='\033[0m'
else
    RED='' GREEN='' YELLOW='' CYAN='' BOLD='' DIM='' RESET=''
fi

# ── Status indicators ──────────────────────────────────────────────────────
CHECK="${GREEN}✓${RESET}"
CROSS="${RED}✗${RESET}"
ARROW="${YELLOW}→${RESET}"
BULLET="${CYAN}•${RESET}"

# ── Tracking arrays ────────────────────────────────────────────────────────
INSTALLED_ITEMS=()
SKIPPED_SECTIONS=()
FAILED_ITEMS=()

# ── State file management ────────────────────────────────────────────────
STATE_FILE="${TMPDIR:-/tmp}/claude-setup-state-$$.txt"
ROLLBACK_STACK=()

init_state_tracking() {
    rm -f "$STATE_FILE"
    touch "$STATE_FILE"
    chmod 600 "$STATE_FILE"
    ROLLBACK_STACK=()
}

track_installation() {
    local type="$1"
    local name="$2"
    local data="$3"

    echo "${type}|${name}|${data}" >> "$STATE_FILE"
    ROLLBACK_STACK+=("${type}|${name}|${data}")
}

cleanup_state_file() {
    rm -f "$STATE_FILE"
}

get_state_file() {
    echo "$STATE_FILE"
}

# ── Rollback execution ──────────────────────────────────────────────────
execute_rollback() {
    local action="$1"
    local name="$2"
    local data="$3"

    case "$action" in
        PLUGIN)
            print_info "Rolling back plugin: $name"
            if claude plugin uninstall "$name" 2>/dev/null; then
                print_success "Uninstalled plugin: $name"
            else
                print_warning "Could not uninstall plugin: $name (may already be uninstalled)"
            fi
            ;;
        MCP)
            print_info "Rolling back MCP server: $name"
            if claude mcp remove "$data" 2>/dev/null; then
                print_success "Removed MCP server: $name"
            else
                print_warning "Could not remove MCP server: $name (may already be removed)"
            fi
            ;;
        SKILL|COMMAND)
            print_info "Rolling back file: $data"
            if [[ -f "$data" ]]; then
                rm -f "$data"
                print_success "Deleted: $data"
            else
                print_info "File not found (already deleted): $data"
            fi
            ;;
        FRAMEWORK)
            print_warning "Framework rollback requires manual deletion of:"
            echo "  $data"
            ;;
        CLAUDE_MD)
            print_info "Rolling back CLAUDE.md: $data"
            if [[ -f "${data}.bak" ]]; then
                mv "${data}.bak" "$data"
                print_success "Restored CLAUDE.md from backup"
            elif [[ -f "$data" ]]; then
                rm -f "$data"
                print_success "Removed CLAUDE.md"
            fi
            ;;
        RULE)
            print_info "Rolling back rule: $name"
            if [[ -f "$data" ]]; then
                rm -f "$data"
                print_success "Deleted rule: $name"
            else
                print_info "Rule not found (already deleted): $data"
            fi
            ;;
        OUTPUT_STYLE)
            print_info "Rolling back output style: $name"
            if [[ -f "$data" ]]; then
                rm -f "$data"
                print_success "Deleted output style: $name"
            else
                print_info "Output style not found (already deleted): $data"
            fi
            ;;
    esac
}

perform_rollback() {
    print_header "ROLLING BACK INSTALLATIONS"
    echo ""

    local i=${#ROLLBACK_STACK[@]}
    while [[ $i -gt 0 ]]; do
        i=$((i - 1))
        local entry="${ROLLBACK_STACK[$i]}"
        local action="${entry%%|*}"
        local rest="${entry#*|}"
        local name="${rest%%|*}"
        local data="${rest#*|}"

        execute_rollback "$action" "$name" "$data"
    done

    echo ""
    print_success "Rollback complete"
}

# ── Error recovery prompts ──────────────────────────────────────────────
prompt_error_recovery() {
    local failed_reason="$1"

    echo ""
    print_error "Installation failed or interrupted: $failed_reason"
    echo ""
    echo "  You have three options:"
    echo "    1) Rollback all completed installations and exit"
    echo "    2) Continue with remaining sections (ignore error)"
    echo "    3) Exit without rollback (leave as is)"
    echo ""

    local choice=""
    # Read from /dev/tty in case we are piped or redirected
    read -rp "  Choose option [1-3]: " choice < /dev/tty

    case "$choice" in
        1)
            perform_rollback
            echo ""
            print_info "All tracked installations have been rolled back"
            exit 1
            ;;
        2)
            print_info "Continuing with remaining sections..."
            return 0
            ;;
        3|*)
            echo ""
            print_warning "Exiting without rollback"
            print_warning "State file saved at: $(get_state_file)"
            exit 1
            ;;
    esac
}

# ── Print functions ─────────────────────────────────────────────────────────
print_header() {
    echo ""
    echo -e "${BOLD}${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo -e "${BOLD}  $1${RESET}"
    echo -e "${BOLD}${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo ""
}

print_success() {
    echo -e "  ${CHECK} $1"
}

print_error() {
    echo -e "  ${CROSS} $1"
}

print_warning() {
    echo -e "  ${ARROW} $1"
}

print_info() {
    echo -e "  ${BULLET} $1"
}

print_step() {
    echo -e "\n${BOLD}  $1${RESET}"
}

# ── Spinner ─────────────────────────────────────────────────────────────────
spinner() {
    local pid=$1
    local msg="${2:-Working...}"
    local frames=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏')
    local i=0

    tput civis 2>/dev/null || true
    while kill -0 "$pid" 2>/dev/null; do
        printf "\r  ${CYAN}${frames[$i]}${RESET} %s" "$msg"
        i=$(( (i + 1) % ${#frames[@]} ))
        sleep 0.1
    done
    printf "\r\033[K"
    tput cnorm 2>/dev/null || true
}

# ── Run with spinner ────────────────────────────────────────────────────────
run_with_spinner() {
    local msg="$1"
    shift
    "$@" >/dev/null 2>&1 &
    local pid=$!
    spinner "$pid" "$msg"
    wait "$pid"
    return $?
}

# ── Banner ──────────────────────────────────────────────────────────────────
print_banner() {
    echo ""
    echo -e "${BOLD}${CYAN}"
    cat << 'BANNER'
        __                __                     __
  _____/ /___ ___  ______/ /__        ________  / /___  ______
 / ___/ / __ `/ / / / __  / _ \______/ ___/ _ \/ __/ / / / __ \
/ /__/ / /_/ / /_/ / /_/ /  __/_____(__  )  __/ /_/ /_/ / /_/ /
\___/_/\__,_/\__,_/\__,_/\___/     /____/\___/\__/\__,_/ .___/
                                                      /_/
BANNER
    echo -e "${RESET}"
    echo -e "  ${DIM}Configure Claude Code from scratch with a single command${RESET}"
    echo ""
}

# ── Dependency check ────────────────────────────────────────────────────────
check_dependency() {
    local cmd="$1"
    local name="${2:-$1}"
    local required="${3:-true}"

    if command -v "$cmd" &>/dev/null; then
        print_success "${name}"
        return 0
    else
        if [[ "$required" == "true" ]]; then
            print_error "${name} ${RED}(required)${RESET}"
            return 1
        else
            print_warning "${name} ${DIM}(optional, some features may not work)${RESET}"
            return 0
        fi
    fi
}

# ── Bash version check ─────────────────────────────────────────────────────
check_bash_version() {
    local required_major=5
    local required_minor=0

    # Get current version from BASH_VERSINFO array
    local current_major="${BASH_VERSINFO[0]}"
    local current_minor="${BASH_VERSINFO[1]}"

    # Check if running under Bash
    if [[ -z "${BASH_VERSION:-}" ]]; then
        print_error "Not running under Bash. Please run with: bash \$0"
        exit 1
    fi

    # Check major version
    if [[ $current_major -lt $required_major ]]; then
        print_error "Bash ${required_major}.${required_minor}+ required (current: ${current_major}.${current_minor})"
        echo ""
        echo -e "  ${DIM}Upgrade instructions:${RESET}"
        echo -e "  ${DIM}  - Ubuntu/Debian: sudo apt update && sudo apt install bash${RESET}"
        echo -e "  ${DIM}  - macOS: brew install bash${RESET}"
        echo -e "  ${DIM}  - RHEL/CentOS: sudo yum install bash${RESET}"
        echo -e "  ${DIM}  - Arch: sudo pacman -S bash${RESET}"
        echo ""
        echo -e "  ${DIM}After upgrading, run: bash --version to verify${RESET}"
        exit 1
    fi

    print_success "Bash version ${current_major}.${current_minor}"
}

# ── Multi-select interactive menu ───────────────────────────────────────────
# Usage: multi_select result_var "header" "item1|desc1" "item2|desc2" ...
# Returns: space-separated indices of selected items in result_var
# Controls: up/down navigate, SPACE toggle, 'a' toggle all, ENTER confirm
# All items selected by default
multi_select() {
    local _result_var=$1
    local -n _result=$1
    local header="$2"
    shift 2
    local items=("$@")
    local count=${#items[@]}

    if [[ $count -eq 0 ]]; then
        _result=""
        return 0
    fi

    # Parse items into names and descriptions
    local names=()
    local descs=()
    for item in "${items[@]}"; do
        names+=("${item%%|*}")
        descs+=("${item#*|}")
    done

    # Default selection state: all checked unless header starts with --none:
    local default_checked=1
    if [[ "$header" == --none:* ]]; then
        default_checked=0
        header="${header#--none:}"
    fi
    local _ms_checked=()
    for ((i = 0; i < count; i++)); do
        _ms_checked+=("$default_checked")
    done

    local cursor=0
    local key=""

    # Hide cursor
    tput civis 2>/dev/null || true

    # Draw function
    _ms_draw() {
        # Move cursor up to redraw (except first draw)
        if [[ "${1:-}" == "redraw" ]]; then
            printf "\033[%dA" "$((count + 3))"
        fi

        # Count selected
        local sel_count=0
        for ((i = 0; i < count; i++)); do
            if [[ ${_ms_checked[$i]} -eq 1 ]]; then
                sel_count=$((sel_count + 1))
            fi
        done

        echo -e "  ${DIM}Use ↑/↓ to navigate, SPACE to toggle, 'a' toggle all, ENTER to confirm${RESET}"
        echo -e "  ${CYAN}${sel_count}/${count} selected${RESET}"
        echo ""

        for ((i = 0; i < count; i++)); do
            local marker="[ ]"
            local style=""
            if [[ ${_ms_checked[$i]} -eq 1 ]]; then
                marker="${GREEN}[✓]${RESET}"
            fi
            if [[ $i -eq $cursor ]]; then
                style="${BOLD}"
                printf "  ${style}> ${marker} %-24s ${DIM}%s${RESET}\n" "${names[$i]}" "${descs[$i]}"
            else
                printf "    ${marker} %-24s ${DIM}%s${RESET}\n" "${names[$i]}" "${descs[$i]}"
            fi
        done
    }

    _ms_draw

    while true; do
        # Read single keypress from terminal device (handles pipe execution)
        if [[ -t 0 ]]; then
            IFS= read -rsn1 key
        else
            IFS= read -rsn1 key < /dev/tty
        fi

        case "$key" in
            # Arrow key escape sequence
            $'\x1b')
                if [[ -t 0 ]]; then
                    read -rsn2 -t 0.1 key2 || true
                else
                    read -rsn2 -t 0.1 key2 < /dev/tty || true
                fi
                case "$key2" in
                    '[A') # Up
                        cursor=$(( (cursor - 1 + count) % count ))
                        ;;
                    '[B') # Down
                        cursor=$(( (cursor + 1) % count ))
                        ;;
                esac
                ;;
            # Space - toggle current
            ' ')
                _ms_checked[$cursor]=$(( 1 - ${_ms_checked[$cursor]} ))
                ;;
            # 'a' - toggle all
            'a'|'A')
                local all_selected=1
                for ((i = 0; i < count; i++)); do
                    if [[ ${_ms_checked[$i]} -eq 0 ]]; then
                        all_selected=0
                        break
                    fi
                done
                local new_val=$((1 - all_selected))
                for ((i = 0; i < count; i++)); do
                    _ms_checked[$i]=$new_val
                done
                ;;
            # Enter - confirm
            '')
                break
                ;;
        esac

        _ms_draw "redraw"
    done

    # Show cursor
    tput cnorm 2>/dev/null || true

    # Count checked
    local sel_count=0
    for ((i = 0; i < count; i++)); do
        if [[ ${_ms_checked[$i]} -eq 1 ]]; then
            sel_count=$((sel_count + 1))
        fi
    done

    # If none selected, confirm skip
    if [[ $sel_count -eq 0 ]]; then
        echo ""
        if [[ -t 0 ]]; then
            read -rp "  Skip this section? [Y/n] " confirm
        else
            read -rp "  Skip this section? [Y/n] " confirm < /dev/tty
        fi
        if [[ "$confirm" =~ ^[Nn] ]]; then
            # Re-run selection
            tput cnorm 2>/dev/null || true
            multi_select "$_result_var" "$header" "${items[@]}"
            return
        fi
        _result=""
        return 0
    fi

    # Build result
    local indices=""
    for ((i = 0; i < count; i++)); do
        if [[ ${_ms_checked[$i]} -eq 1 ]]; then
            indices+="$i "
        fi
    done
    _result="${indices% }"
    echo ""
}

# ── Summary ─────────────────────────────────────────────────────────────────
print_summary() {
    print_header "INSTALLATION SUMMARY"

    if [[ ${#INSTALLED_ITEMS[@]} -gt 0 ]]; then
        echo -e "  ${GREEN}${BOLD}Installed:${RESET}"
        for item in "${INSTALLED_ITEMS[@]}"; do
            echo -e "    ${CHECK} ${item}"
        done
        echo ""
    fi

    if [[ ${#SKIPPED_SECTIONS[@]} -gt 0 ]]; then
        echo -e "  ${YELLOW}${BOLD}Skipped:${RESET}"
        for item in "${SKIPPED_SECTIONS[@]}"; do
            echo -e "    ${ARROW} ${item}"
        done
        echo ""
    fi

    if [[ ${#FAILED_ITEMS[@]} -gt 0 ]]; then
        echo -e "  ${RED}${BOLD}Failed:${RESET}"
        for item in "${FAILED_ITEMS[@]}"; do
            echo -e "    ${CROSS} ${item}"
        done
        echo ""
    fi

    echo -e "${BOLD}${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo -e "  ${DIM}Check quickstart/ docs for usage guides${RESET}"
    echo -e "${BOLD}${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo ""
}
