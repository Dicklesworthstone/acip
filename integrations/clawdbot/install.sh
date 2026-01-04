#!/usr/bin/env bash
#
# ╔═══════════════════════════════════════════════════════════════════════════╗
# ║                     ACIP Installer for Clawdbot                           ║
# ║          Advanced Cognitive Inoculation Prompt Security Layer             ║
# ╚═══════════════════════════════════════════════════════════════════════════╝
#
# Downloads and verifies SECURITY.md for your Clawdbot workspace.
#
# Usage:
#   curl -sL https://raw.githubusercontent.com/Dicklesworthstone/acip/main/integrations/clawdbot/install.sh | bash
#
# Options (via environment variables):
#   CLAWD_WORKSPACE=~/my-clawd  - Custom workspace directory (default: ~/clawd)
#   ACIP_NONINTERACTIVE=1       - Skip prompts, fail if workspace doesn't exist
#   ACIP_FORCE=1                - Overwrite without backup
#   ACIP_QUIET=1                - Minimal output
#   ACIP_UNINSTALL=1            - Remove SECURITY.md instead of installing
#
# Examples:
#   # Standard install
#   curl -sL .../install.sh | bash
#
#   # Custom workspace, non-interactive
#   CLAWD_WORKSPACE=~/assistant ACIP_NONINTERACTIVE=1 curl -sL .../install.sh | bash
#
#   # Uninstall
#   ACIP_UNINSTALL=1 curl -sL .../install.sh | bash
#

set -euo pipefail

# ─────────────────────────────────────────────────────────────────────────────
# Configuration
# ─────────────────────────────────────────────────────────────────────────────

readonly SCRIPT_VERSION="1.0.0"
readonly ACIP_REPO="Dicklesworthstone/acip"
readonly ACIP_BRANCH="main"
readonly SECURITY_FILE="integrations/clawdbot/SECURITY.md"
readonly BASE_URL="https://raw.githubusercontent.com/${ACIP_REPO}/${ACIP_BRANCH}"
readonly MANIFEST_URL="${BASE_URL}/.checksums/manifest.json"
readonly SECURITY_URL="${BASE_URL}/${SECURITY_FILE}"

# User-configurable via environment
WORKSPACE="${CLAWD_WORKSPACE:-$HOME/clawd}"
NONINTERACTIVE="${ACIP_NONINTERACTIVE:-0}"
FORCE="${ACIP_FORCE:-0}"
QUIET="${ACIP_QUIET:-0}"
UNINSTALL="${ACIP_UNINSTALL:-0}"

TARGET_FILE="${WORKSPACE}/SECURITY.md"

# ─────────────────────────────────────────────────────────────────────────────
# Terminal Colors & Styling
# ─────────────────────────────────────────────────────────────────────────────

setup_colors() {
  if [[ -t 1 ]] && [[ -z "${NO_COLOR:-}" ]]; then
    readonly RED=$'\033[0;31m'
    readonly GREEN=$'\033[0;32m'
    readonly YELLOW=$'\033[1;33m'
    readonly BLUE=$'\033[0;34m'
    readonly MAGENTA=$'\033[0;35m'
    readonly CYAN=$'\033[0;36m'
    readonly WHITE=$'\033[1;37m'
    readonly BOLD=$'\033[1m'
    readonly DIM=$'\033[2m'
    readonly RESET=$'\033[0m'
    readonly CHECK="${GREEN}✓${RESET}"
    readonly CROSS="${RED}✗${RESET}"
    readonly ARROW="${CYAN}→${RESET}"
    readonly WARN="${YELLOW}⚠${RESET}"
    readonly INFO="${BLUE}ℹ${RESET}"
  else
    readonly RED='' GREEN='' YELLOW='' BLUE='' MAGENTA='' CYAN=''
    readonly WHITE='' BOLD='' DIM='' RESET=''
    readonly CHECK='[OK]' CROSS='[FAIL]' ARROW='->' WARN='[!]' INFO='[i]'
  fi
}

# ─────────────────────────────────────────────────────────────────────────────
# Logging Functions
# ─────────────────────────────────────────────────────────────────────────────

log() {
  [[ "$QUIET" == "1" ]] && return
  echo -e "$@"
}

log_step() {
  [[ "$QUIET" == "1" ]] && return
  echo -e "${ARROW} $*"
}

log_success() {
  echo -e "${CHECK} ${GREEN}$*${RESET}"
}

log_error() {
  echo -e "${CROSS} ${RED}$*${RESET}" >&2
}

log_warn() {
  echo -e "${WARN} ${YELLOW}$*${RESET}"
}

log_info() {
  [[ "$QUIET" == "1" ]] && return
  echo -e "${INFO} ${DIM}$*${RESET}"
}

# ─────────────────────────────────────────────────────────────────────────────
# Banner
# ─────────────────────────────────────────────────────────────────────────────

print_banner() {
  [[ "$QUIET" == "1" ]] && return
  echo ""
  echo -e "${CYAN}╔═══════════════════════════════════════════════════════════╗${RESET}"
  echo -e "${CYAN}║${RESET}     ${BOLD}${WHITE}ACIP Installer for Clawdbot${RESET}  ${DIM}v${SCRIPT_VERSION}${RESET}              ${CYAN}║${RESET}"
  echo -e "${CYAN}║${RESET}     ${DIM}Advanced Cognitive Inoculation Prompt${RESET}                 ${CYAN}║${RESET}"
  echo -e "${CYAN}╚═══════════════════════════════════════════════════════════╝${RESET}"
  echo ""
}

# ─────────────────────────────────────────────────────────────────────────────
# System Detection & Requirements
# ─────────────────────────────────────────────────────────────────────────────

detect_os() {
  case "$(uname -s)" in
    Darwin*) echo "macos" ;;
    Linux*)  echo "linux" ;;
    MINGW*|MSYS*|CYGWIN*) echo "windows" ;;
    *)       echo "unknown" ;;
  esac
}

check_requirements() {
  local missing=()
  local os
  os=$(detect_os)

  log_step "Checking requirements..."

  # Check curl
  if ! command -v curl >/dev/null 2>&1; then
    missing+=("curl")
  fi

  # Check sha256 capability
  if ! command -v sha256sum >/dev/null 2>&1 && ! command -v shasum >/dev/null 2>&1; then
    missing+=("sha256sum or shasum")
  fi

  if [[ ${#missing[@]} -gt 0 ]]; then
    log_error "Missing required tools: ${missing[*]}"
    echo ""
    case "$os" in
      macos)
        echo "  Install with: brew install coreutils curl"
        ;;
      linux)
        echo "  Install with: apt-get install coreutils curl"
        ;;
    esac
    exit 1
  fi

  log_success "All requirements satisfied"
}

# ─────────────────────────────────────────────────────────────────────────────
# Cross-Platform SHA256
# ─────────────────────────────────────────────────────────────────────────────

sha256() {
  local file="$1"

  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$file" | cut -d' ' -f1
  elif command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$file" | cut -d' ' -f1
  else
    log_error "No SHA256 tool available"
    return 1
  fi
}

# ─────────────────────────────────────────────────────────────────────────────
# Checksum Verification
# ─────────────────────────────────────────────────────────────────────────────

fetch_expected_checksum() {
  log_step "Fetching checksum from manifest..."

  local manifest
  if ! manifest=$(curl -sL --fail --max-time 10 "$MANIFEST_URL" 2>/dev/null); then
    log_warn "Could not fetch manifest (network error or file not found)"
    return 1
  fi

  # Extract checksum for clawdbot SECURITY.md from integrations array
  # Using grep/sed for portability (no jq requirement)
  local checksum
  checksum=$(echo "$manifest" | \
    grep -A5 "\"file\": \"${SECURITY_FILE}\"" | \
    grep '"sha256"' | \
    head -1 | \
    sed 's/.*"sha256"[[:space:]]*:[[:space:]]*"\([a-f0-9]*\)".*/\1/')

  if [[ -z "$checksum" || ${#checksum} -ne 64 ]]; then
    log_warn "Could not extract checksum from manifest"
    return 1
  fi

  echo "$checksum"
}

verify_checksum() {
  local file="$1"
  local expected="$2"

  log_step "Verifying checksum..."

  local actual
  actual=$(sha256 "$file")

  if [[ "$actual" == "$expected" ]]; then
    log_success "Checksum verified: ${DIM}${actual:0:16}...${RESET}"
    return 0
  else
    log_error "Checksum mismatch!"
    echo ""
    echo "  Expected: ${expected}"
    echo "  Actual:   ${actual}"
    echo ""
    echo "  The file may have been tampered with or corrupted."
    echo "  Please report this at: https://github.com/${ACIP_REPO}/issues"
    return 1
  fi
}

# ─────────────────────────────────────────────────────────────────────────────
# Workspace Management
# ─────────────────────────────────────────────────────────────────────────────

ensure_workspace() {
  log_step "Checking workspace: ${DIM}${WORKSPACE}${RESET}"

  if [[ -d "$WORKSPACE" ]]; then
    log_success "Workspace exists"
    return 0
  fi

  log_warn "Workspace directory does not exist"

  if [[ "$NONINTERACTIVE" == "1" ]]; then
    log_error "Cannot create workspace in non-interactive mode"
    echo "  Set CLAWD_WORKSPACE to an existing directory or create it first."
    exit 1
  fi

  echo ""
  echo -n "  Create ${WORKSPACE}? [y/N] "
  read -r response

  if [[ "$response" =~ ^[Yy]$ ]]; then
    mkdir -p "$WORKSPACE"
    log_success "Created workspace: ${WORKSPACE}"
  else
    log_error "Aborted by user"
    exit 1
  fi
}

backup_existing() {
  if [[ ! -f "$TARGET_FILE" ]]; then
    return 0
  fi

  if [[ "$FORCE" == "1" ]]; then
    log_info "Force mode: skipping backup"
    return 0
  fi

  local backup_file="${TARGET_FILE}.backup.$(date +%Y%m%d_%H%M%S)"

  log_step "Backing up existing SECURITY.md..."
  cp "$TARGET_FILE" "$backup_file"
  log_success "Backup saved: ${DIM}${backup_file}${RESET}"
}

# ─────────────────────────────────────────────────────────────────────────────
# Download
# ─────────────────────────────────────────────────────────────────────────────

download_security_file() {
  log_step "Downloading SECURITY.md..."

  local tmp_file
  tmp_file=$(mktemp)
  trap "rm -f '$tmp_file'" EXIT

  if ! curl -sL --fail --max-time 30 "$SECURITY_URL" -o "$tmp_file"; then
    log_error "Failed to download SECURITY.md"
    echo ""
    echo "  URL: ${SECURITY_URL}"
    echo "  Please check your network connection and try again."
    exit 1
  fi

  # Validate file is not empty or error page
  local lines
  lines=$(wc -l < "$tmp_file" | tr -d '[:space:]')

  if [[ "$lines" -lt 50 ]]; then
    log_error "Downloaded file seems corrupted (only ${lines} lines)"
    exit 1
  fi

  # Check for expected content
  if ! grep -q "Cognitive Integrity Framework" "$tmp_file" 2>/dev/null; then
    log_error "Downloaded file doesn't appear to be valid ACIP content"
    exit 1
  fi

  # Move to final location
  mv "$tmp_file" "$TARGET_FILE"
  trap - EXIT

  log_success "Downloaded successfully"
}

# ─────────────────────────────────────────────────────────────────────────────
# Installation
# ─────────────────────────────────────────────────────────────────────────────

install() {
  print_banner
  check_requirements
  ensure_workspace
  backup_existing
  download_security_file

  # Attempt checksum verification
  local expected_checksum
  if expected_checksum=$(fetch_expected_checksum); then
    if ! verify_checksum "$TARGET_FILE" "$expected_checksum"; then
      log_error "Checksum verification failed - removing downloaded file"
      rm -f "$TARGET_FILE"
      exit 1
    fi
  else
    # Show checksum for manual verification
    local actual_checksum
    actual_checksum=$(sha256 "$TARGET_FILE")
    log_info "Checksum (for manual verification): ${actual_checksum}"
  fi

  # Summary
  echo ""
  echo -e "${GREEN}╔═══════════════════════════════════════════════════════════╗${RESET}"
  echo -e "${GREEN}║${RESET}                 ${BOLD}Installation Complete!${RESET}                    ${GREEN}║${RESET}"
  echo -e "${GREEN}╚═══════════════════════════════════════════════════════════╝${RESET}"
  echo ""
  echo "  ${BOLD}Installed:${RESET} ${TARGET_FILE}"
  echo ""
  echo "  ${BOLD}Next steps:${RESET}"
  echo "    1. Review the file:  ${DIM}less ${TARGET_FILE}${RESET}"
  echo "    2. Customize if needed (add rules at the end)"
  echo "    3. Restart Clawdbot to load the security layer"
  echo ""
  echo "  ${BOLD}Documentation:${RESET}"
  echo "    ${DIM}https://github.com/${ACIP_REPO}/tree/main/integrations/clawdbot${RESET}"
  echo ""
}

# ─────────────────────────────────────────────────────────────────────────────
# Uninstallation
# ─────────────────────────────────────────────────────────────────────────────

uninstall() {
  print_banner

  log_step "Uninstalling ACIP security layer..."

  if [[ ! -f "$TARGET_FILE" ]]; then
    log_warn "SECURITY.md not found at ${TARGET_FILE}"
    echo "  Nothing to uninstall."
    exit 0
  fi

  if [[ "$NONINTERACTIVE" != "1" ]]; then
    echo ""
    echo -n "  Remove ${TARGET_FILE}? [y/N] "
    read -r response

    if [[ ! "$response" =~ ^[Yy]$ ]]; then
      log_error "Aborted by user"
      exit 1
    fi
  fi

  # Create backup before removing
  local backup_file="${TARGET_FILE}.uninstalled.$(date +%Y%m%d_%H%M%S)"
  mv "$TARGET_FILE" "$backup_file"

  log_success "Uninstalled ACIP security layer"
  log_info "Backup saved: ${backup_file}"
  echo ""
  echo "  Restart Clawdbot to apply changes."
  echo ""
}

# ─────────────────────────────────────────────────────────────────────────────
# Help
# ─────────────────────────────────────────────────────────────────────────────

show_help() {
  cat << EOF
ACIP Installer for Clawdbot v${SCRIPT_VERSION}

Usage:
  curl -sL .../install.sh | bash
  curl -sL .../install.sh | ACIP_UNINSTALL=1 bash

Environment Variables:
  CLAWD_WORKSPACE      Workspace directory (default: ~/clawd)
  ACIP_NONINTERACTIVE  Skip prompts, fail if workspace doesn't exist
  ACIP_FORCE           Overwrite without backup
  ACIP_QUIET           Minimal output
  ACIP_UNINSTALL       Remove SECURITY.md instead of installing

Examples:
  # Standard install
  curl -sL .../install.sh | bash

  # Custom workspace, non-interactive
  CLAWD_WORKSPACE=~/assistant ACIP_NONINTERACTIVE=1 bash -c "\$(curl -sL .../install.sh)"

  # Uninstall
  ACIP_UNINSTALL=1 bash -c "\$(curl -sL .../install.sh)"

More info: https://github.com/${ACIP_REPO}
EOF
}

# ─────────────────────────────────────────────────────────────────────────────
# Main Entry Point
# ─────────────────────────────────────────────────────────────────────────────

main() {
  setup_colors

  # Handle help flag if running directly (not piped)
  if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    show_help
    exit 0
  fi

  if [[ "$UNINSTALL" == "1" ]]; then
    uninstall
  else
    install
  fi
}

main "$@"
