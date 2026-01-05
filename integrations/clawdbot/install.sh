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
#   curl -fsSL -H "Accept: application/vnd.github.raw" \
#     "https://api.github.com/repos/Dicklesworthstone/acip/contents/integrations/clawdbot/install.sh?ref=main" | bash
#
# Options (via environment variables):
#   CLAWD_WORKSPACE=~/my-clawd  - Custom workspace directory (default: auto-detect from clawdbot.json, else ~/clawd)
#   ACIP_NONINTERACTIVE=1       - Skip prompts, fail if workspace doesn't exist
#   ACIP_FORCE=1                - Overwrite without backup
#   ACIP_QUIET=1                - Minimal output
#   ACIP_UNINSTALL=1            - Remove SECURITY.md instead of installing
#   ACIP_ALLOW_UNVERIFIED=1     - Allow install if checksum manifest can't be fetched (NOT recommended)
#   ACIP_INJECT=1               - (Optional) Inject ACIP into SOUL.md/AGENTS.md so it's active even if clawdbot doesn't load SECURITY.md yet
#   ACIP_INJECT_FILE=SOUL.md    - Injection target (SOUL.md or AGENTS.md; default: SOUL.md)
#
# Examples:
#   # Standard install
#   curl -fsSL ".../install.sh?ts=$(date +%s)" | bash
#
#   # Custom workspace, non-interactive
#   CLAWD_WORKSPACE=~/assistant ACIP_NONINTERACTIVE=1 curl -fsSL ".../install.sh?ts=$(date +%s)" | bash
#
#   # Uninstall
#   ACIP_UNINSTALL=1 curl -fsSL ".../install.sh?ts=$(date +%s)" | bash
#

set -euo pipefail

# ─────────────────────────────────────────────────────────────────────────────
# Configuration
# ─────────────────────────────────────────────────────────────────────────────

readonly SCRIPT_VERSION="1.1.5"
readonly ACIP_REPO="Dicklesworthstone/acip"
readonly ACIP_BRANCH="main"
readonly SECURITY_FILE="integrations/clawdbot/SECURITY.md"
readonly BASE_URL="https://raw.githubusercontent.com/${ACIP_REPO}/${ACIP_BRANCH}"
readonly MANIFEST_URL="${BASE_URL}/.checksums/manifest.json"
readonly SECURITY_URL="${BASE_URL}/${SECURITY_FILE}"
readonly INJECT_BEGIN="<!-- ACIP:BEGIN clawdbot SECURITY.md -->"
readonly INJECT_END="<!-- ACIP:END clawdbot SECURITY.md -->"

# User-configurable via environment
WORKSPACE_OVERRIDE="${CLAWD_WORKSPACE:-}"
NONINTERACTIVE="${ACIP_NONINTERACTIVE:-0}"
FORCE="${ACIP_FORCE:-0}"
QUIET="${ACIP_QUIET:-0}"
UNINSTALL="${ACIP_UNINSTALL:-0}"
ALLOW_UNVERIFIED="${ACIP_ALLOW_UNVERIFIED:-0}"
INJECT="${ACIP_INJECT:-0}"
INJECT_FILE="${ACIP_INJECT_FILE:-SOUL.md}"

# Workspace is resolved at runtime (may be inferred from clawdbot.json)
WORKSPACE=""
TARGET_FILE=""

TEMP_FILES=()

# ─────────────────────────────────────────────────────────────────────────────
# Terminal Colors & Styling
# ─────────────────────────────────────────────────────────────────────────────

setup_colors() {
  if [[ -t 1 ]] && [[ -z "${NO_COLOR:-}" ]]; then
    readonly RED=$'\033[0;31m'
    readonly GREEN=$'\033[0;32m'
    readonly YELLOW=$'\033[1;33m'
    readonly BLUE=$'\033[0;34m'
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
    readonly RED='' GREEN='' YELLOW='' BLUE='' CYAN=''
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
# Cleanup
# ─────────────────────────────────────────────────────────────────────────────

cleanup() {
  local f
  for f in "${TEMP_FILES[@]}"; do
    rm -f "$f" 2>/dev/null || true
  done
}

# ─────────────────────────────────────────────────────────────────────────────
# Banner
# ─────────────────────────────────────────────────────────────────────────────

print_banner() {
  [[ "$QUIET" == "1" ]] && return
  local inner_width=59
  local line1="     ACIP Installer for Clawdbot  v${SCRIPT_VERSION}"
  local line2="     Advanced Cognitive Inoculation Prompt"
  echo ""
  printf "%b\n" "${CYAN}╔═══════════════════════════════════════════════════════════╗${RESET}"
  printf "%b\n" "${CYAN}║${RESET}${BOLD}${WHITE}$(printf '%-*s' "$inner_width" "$line1")${RESET}${CYAN}║${RESET}"
  printf "%b\n" "${CYAN}║${RESET}${DIM}$(printf '%-*s' "$inner_width" "$line2")${RESET}${CYAN}║${RESET}"
  printf "%b\n" "${CYAN}╚═══════════════════════════════════════════════════════════╝${RESET}"
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

resolve_clawdbot_config_path() {
  if [[ -n "${CLAWDBOT_CONFIG_PATH:-}" ]]; then
    echo "${CLAWDBOT_CONFIG_PATH}"
    return 0
  fi
  if [[ -n "${CLAWDBOT_STATE_DIR:-}" ]]; then
    echo "${CLAWDBOT_STATE_DIR%/}/clawdbot.json"
    return 0
  fi
  echo "${HOME}/.clawdbot/clawdbot.json"
}

detect_workspace_from_config() {
  local cfg_path
  cfg_path="$(resolve_clawdbot_config_path)"
  [[ -f "$cfg_path" ]] || return 1

  local ws
  if command -v perl >/dev/null 2>&1; then
    ws="$(perl -0777 -ne 'if (/"workspace"\s*:\s*["'"'"'"]([^"'"'"'\n]+)["'"'"'"]/s){print $1; exit}' "$cfg_path" 2>/dev/null || true)"
  else
    ws=""
  fi
  ws="$(printf '%s' "$ws" | tr -d '\r\n' | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')"
  [[ -n "$ws" ]] || return 1

  # Expand "~" if present
  if [[ "$ws" == "~"* ]]; then
    ws="${ws/#\~/$HOME}"
  fi

  echo "$ws"
}

resolve_workspace() {
  if [[ -n "${WORKSPACE_OVERRIDE:-}" ]]; then
    echo "${WORKSPACE_OVERRIDE/#\~/$HOME}"
    return 0
  fi

  local inferred
  inferred="$(detect_workspace_from_config || true)"
  if [[ -n "$inferred" ]]; then
    echo "$inferred"
    return 0
  fi

  echo "${HOME}/clawd"
}

has_clawdbot_security_cli() {
  command -v clawdbot >/dev/null 2>&1 || return 1
  clawdbot security --help >/dev/null 2>&1
}

mktemp_file() {
  local tmp=""

  tmp="$(mktemp 2>/dev/null || true)"
  if [[ -z "$tmp" ]]; then
    tmp="$(mktemp -t acip.XXXXXX 2>/dev/null || true)"
  fi
  if [[ -z "$tmp" ]]; then
    tmp="$(mktemp "/tmp/acip.XXXXXX" 2>/dev/null || true)"
  fi

  if [[ -z "$tmp" ]]; then
    log_error "mktemp failed"
    exit 1
  fi

  echo "$tmp"
}

tmpfile() {
  local tmp
  tmp="$(mktemp_file)"
  TEMP_FILES+=("$tmp")
  echo "$tmp"
}

prompt_available() {
  [[ "$NONINTERACTIVE" != "1" ]] || return 1
  [[ -t 0 ]] || [[ -r /dev/tty ]]
}

prompt_yn() {
  local prompt="$1"
  local default="${2:-N}" # Y or N
  local reply=""
  local yn="[y/N]"
  local input="/dev/stdin"

  if [[ "$default" == "Y" ]]; then
    yn="[Y/n]"
  fi

  if ! prompt_available; then
    return 2
  fi

  if [[ ! -t 0 ]] && [[ -r /dev/tty ]]; then
    input="/dev/tty"
  fi

  read -r -p "  ${prompt} ${yn} " reply < "$input" || true
  if [[ -z "$reply" ]]; then
    reply="$default"
  fi

  [[ "$reply" =~ ^[Yy]$ ]]
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

fetch_manifest() {
  local api_url="https://api.github.com/repos/${ACIP_REPO}/contents/.checksums/manifest.json?ref=${ACIP_BRANCH}"
  local ua="acip-clawdbot-installer/${SCRIPT_VERSION}"

  if curl -fsSL --show-error --max-time 10 \
    -H "Accept: application/vnd.github.raw" \
    -H "User-Agent: ${ua}" \
    "$api_url"; then
    return 0
  fi

  if curl -fsSL --show-error --max-time 10 "$MANIFEST_URL"; then
    return 0
  fi

  return 1
}

extract_manifest_commit() {
  local manifest="$1"
  local commit
  commit=$(echo "$manifest" | \
    grep -m 1 -E '^[[:space:]]*"commit"[[:space:]]*:' | \
    sed 's/.*"commit"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/')

  if [[ -z "$commit" || ${#commit} -lt 7 ]]; then
    return 1
  fi

  echo "$commit"
}

fetch_expected_checksum() {
  local manifest="$1"
  if [[ -z "$manifest" ]]; then
    return 1
  fi

  # Extract checksum for clawdbot SECURITY.md from integrations array
  # Using grep/sed for portability (no jq requirement)
  local checksum
  checksum=$(echo "$manifest" | \
    grep -A10 "\"file\": \"${SECURITY_FILE}\"" | \
    grep '"sha256"' | \
    head -1 | \
    sed 's/.*"sha256"[[:space:]]*:[[:space:]]*"\([a-f0-9]*\)".*/\1/')

  if [[ -z "$checksum" || ${#checksum} -ne 64 ]]; then
    return 1
  fi

  echo "$checksum"
}

security_url_for_ref() {
  local ref="$1"
  echo "https://raw.githubusercontent.com/${ACIP_REPO}/${ref}/${SECURITY_FILE}"
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

  if ! prompt_available; then
    log_error "Cannot create workspace (no TTY / non-interactive)"
    echo "  Create it manually or set CLAWD_WORKSPACE to an existing directory."
    exit 1
  fi

  if prompt_yn "Create ${WORKSPACE}?" "N"; then
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

  local backup_file
  backup_file="${TARGET_FILE}.backup.$(date +%Y%m%d_%H%M%S)"

  log_step "Backing up existing SECURITY.md..."
  cp "$TARGET_FILE" "$backup_file"
  log_success "Backup saved: ${DIM}${backup_file}${RESET}"
}

# ─────────────────────────────────────────────────────────────────────────────
# Activation (Optional Injection)
# ─────────────────────────────────────────────────────────────────────────────

resolve_inject_target() {
  local preferred="${WORKSPACE%/}/${INJECT_FILE}"

  if [[ -f "$preferred" ]]; then
    echo "$preferred"
    return 0
  fi

  if [[ "$INJECT_FILE" == "SOUL.md" && -f "${WORKSPACE%/}/AGENTS.md" ]]; then
    echo "${WORKSPACE%/}/AGENTS.md"
    return 0
  fi

  if [[ "$INJECT_FILE" == "AGENTS.md" && -f "${WORKSPACE%/}/SOUL.md" ]]; then
    echo "${WORKSPACE%/}/SOUL.md"
    return 0
  fi

  echo "$preferred"
}

file_has_injection() {
  local file="$1"
  grep -q "$INJECT_BEGIN" "$file" 2>/dev/null && grep -q "$INJECT_END" "$file" 2>/dev/null
}

ensure_inject_target_exists() {
  local file="$1"

  if [[ -f "$file" ]]; then
    return 0
  fi

  log_warn "Injection target not found: ${file}"

  if ! prompt_available; then
    log_error "Cannot create ${file} (no TTY / non-interactive)"
    echo "  Create it manually, or re-run with: ACIP_INJECT=0"
    exit 1
  fi

  if prompt_yn "Create ${file} so ACIP can be activated now?" "Y"; then
    printf '%s\n' "# ${INJECT_FILE} - Clawdbot system instructions" > "$file"
    printf '%s\n' "" >> "$file"
    chmod 600 "$file" 2>/dev/null || true
    log_success "Created: ${file}"
  else
    log_warn "Skipping activation injection"
    return 1
  fi
}

backup_file() {
  local file="$1"
  local label="${2:-backup}"

  [[ -f "$file" ]] || return 0

  if [[ "$FORCE" == "1" ]]; then
    log_info "Force mode: skipping backup of ${file}"
    return 0
  fi

  local backup_path
  backup_path="${file}.${label}.$(date +%Y%m%d_%H%M%S)"
  cp "$file" "$backup_path"
  log_info "Backup saved: ${backup_path}"
}

file_mode() {
  local file="$1"

  if stat -c %a "$file" >/dev/null 2>&1; then
    stat -c %a "$file"
  else
    stat -f %Lp "$file"
  fi
}

inject_security_into_file() {
  local target="$1"
  local original_mode=""
  if [[ -e "$target" ]]; then
    original_mode="$(file_mode "$target" 2>/dev/null || true)"
  fi

  local tmp
  tmp="$(tmpfile)"

  if file_has_injection "$target"; then
    awk -v begin="$INJECT_BEGIN" -v end="$INJECT_END" -v src="$TARGET_FILE" '
      $0 == begin {
        print $0
        while ((getline line < src) > 0) { print line }
        close(src)
        skipping=1
        next
      }
      $0 == end { skipping=0; print $0; next }
      !skipping { print $0 }
    ' "$target" > "$tmp"
  else
    cat "$target" > "$tmp"
    {
      printf '\n%s\n' "$INJECT_BEGIN"
      cat "$TARGET_FILE"
      printf '\n%s\n' "$INJECT_END"
    } >> "$tmp"
  fi

  mv "$tmp" "$target"
  if [[ "$original_mode" =~ ^[0-9][0-9][0-9]([0-9])?$ ]]; then
    chmod "$original_mode" "$target" 2>/dev/null || true
  fi
  log_success "Activated ACIP by injecting into: ${target}"
}

remove_security_injection_from_file() {
  local target="$1"
  [[ -f "$target" ]] || return 1
  file_has_injection "$target" || return 1

  local original_mode=""
  if [[ -e "$target" ]]; then
    original_mode="$(file_mode "$target" 2>/dev/null || true)"
  fi

  local tmp
  tmp="$(tmpfile)"

  awk -v begin="$INJECT_BEGIN" -v end="$INJECT_END" '
    $0 == begin { skipping=1; next }
    $0 == end { skipping=0; next }
    !skipping { print $0 }
  ' "$target" > "$tmp"

  mv "$tmp" "$target"
  if [[ "$original_mode" =~ ^[0-9][0-9][0-9]([0-9])?$ ]]; then
    chmod "$original_mode" "$target" 2>/dev/null || true
  fi
  log_success "Removed ACIP injection block from: ${target}"
}

# ─────────────────────────────────────────────────────────────────────────────
# Download
# ─────────────────────────────────────────────────────────────────────────────

download_security_file() {
  local ref="$1"

  log_step "Downloading SECURITY.md..."

  local tmp_file
  tmp_file="$(tmpfile)"

  local url="$SECURITY_URL"
  if [[ -n "${ref:-}" ]]; then
    url=$(security_url_for_ref "$ref")
  fi

  if ! curl -fsSL --show-error --max-time 30 "$url" -o "$tmp_file"; then
    log_error "Failed to download SECURITY.md"
    echo ""
    echo "  URL: ${url}"
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
  chmod 644 "$TARGET_FILE" 2>/dev/null || true

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

  # Attempt to fetch manifest + pin download to the manifest commit to avoid TOCTOU issues.
  local manifest=""
  local manifest_commit=""
  local expected_checksum=""

  log_step "Fetching checksum manifest..."
  if manifest=$(fetch_manifest); then
    if manifest_commit=$(extract_manifest_commit "$manifest"); then
      log_step "Fetching expected checksum from manifest..."
      if ! expected_checksum=$(fetch_expected_checksum "$manifest"); then
        expected_checksum=""
      fi
    fi
  fi

  if [[ -n "${manifest_commit:-}" && ${#expected_checksum} -eq 64 ]]; then
    log_info "Using pinned ACIP commit: ${manifest_commit}"
    download_security_file "$manifest_commit"
    if ! verify_checksum "$TARGET_FILE" "$expected_checksum"; then
      log_error "Checksum verification failed - removing downloaded file"
      rm -f "$TARGET_FILE"
      exit 1
    fi
  else
    if [[ "$ALLOW_UNVERIFIED" == "1" ]]; then
      log_warn "Manifest unavailable; downloading from ${ACIP_BRANCH} without verification"
      log_warn "This is NOT recommended; set ACIP_ALLOW_UNVERIFIED=0 to fail closed."
      download_security_file ""
      local actual_checksum
      actual_checksum=$(sha256 "$TARGET_FILE")
      log_info "Checksum (for manual verification): ${actual_checksum}"
    else
      log_error "Could not fetch/parse checksum manifest; refusing unverified install"
      echo ""
      echo "  This installer fails closed by default to prevent unverified downloads."
      echo "  Check your network and try again."
      echo ""
      echo "  To override (NOT recommended):"
      echo "    ACIP_ALLOW_UNVERIFIED=1 curl -fsSL \"${BASE_URL}/integrations/clawdbot/install.sh?ts=$(date +%s)\" | bash"
      exit 1
    fi
  fi

  local activated="0"
  local inject_target=""

  if has_clawdbot_security_cli; then
    log_info "Detected Clawdbot security CLI; showing status"
    CLAWD_WORKSPACE="$WORKSPACE" clawdbot security status 2>/dev/null || true
    activated="1"
  else
    # If the user already has an injected ACIP block, keep it up to date automatically.
    local existing_inject=0
    local f=""
    for f in "${WORKSPACE%/}/SOUL.md" "${WORKSPACE%/}/AGENTS.md"; do
      if [[ -f "$f" ]] && file_has_injection "$f"; then
        existing_inject=1
        backup_file "$f" "backup"
        inject_security_into_file "$f"
      fi
    done

    if [[ "$existing_inject" == "1" ]]; then
      activated="1"
    else
      inject_target="$(resolve_inject_target)"

      if [[ "$INJECT" == "1" ]]; then
        if ensure_inject_target_exists "$inject_target"; then
          backup_file "$inject_target" "backup"
          inject_security_into_file "$inject_target"
          activated="1"
        fi
      elif [[ "$NONINTERACTIVE" == "1" ]]; then
        log_warn "Clawdbot doesn't load SECURITY.md by default; ACIP may not be active yet"
        log_info "To activate now: ACIP_INJECT=1 ${ARROW} inject into ${INJECT_FILE}"
      else
        echo ""
        log_warn "Clawdbot doesn't load SECURITY.md by default"
        if prompt_yn "Activate now by injecting ACIP into ${inject_target}?" "Y"; then
          if ensure_inject_target_exists "$inject_target"; then
            backup_file "$inject_target" "backup"
            inject_security_into_file "$inject_target"
            activated="1"
          fi
        else
          log_warn "Installed SECURITY.md but did not activate it in Clawdbot prompts"
        fi
      fi
    fi
  fi

  # Summary
  echo ""
  echo -e "${GREEN}╔═══════════════════════════════════════════════════════════╗${RESET}"
  echo -e "${GREEN}║${RESET}                 ${BOLD}Installation Complete!${RESET}                    ${GREEN}║${RESET}"
  echo -e "${GREEN}╚═══════════════════════════════════════════════════════════╝${RESET}"
  echo ""
  echo "  ${BOLD}Workspace:${RESET} ${WORKSPACE}"
  echo "  ${BOLD}Installed:${RESET} ${TARGET_FILE}"
  if [[ "$activated" == "1" ]]; then
    echo "  ${BOLD}Active:${RESET} yes"
  else
    echo "  ${BOLD}Active:${RESET} ${YELLOW}unknown${RESET} (enable injection to activate now)"
  fi
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

  # Remove injected blocks if present (safe to attempt on both common files)
  local injected=0
  local f=""
  for f in "${WORKSPACE%/}/SOUL.md" "${WORKSPACE%/}/AGENTS.md"; do
    if [[ -f "$f" ]] && file_has_injection "$f"; then
      backup_file "$f" "uninstalled"
      remove_security_injection_from_file "$f" || true
      injected=1
    fi
  done

  if [[ ! -f "$TARGET_FILE" ]]; then
    log_warn "SECURITY.md not found at ${TARGET_FILE}"
    echo "  Nothing to uninstall."
    if [[ "$injected" == "1" ]]; then
      echo ""
      echo "  Restart Clawdbot to apply changes."
      echo ""
    fi
    exit 0
  fi

  if [[ "$NONINTERACTIVE" != "1" ]]; then
    echo ""
    if ! prompt_available; then
      log_error "Cannot prompt for confirmation (no TTY / non-interactive)"
      echo "  Re-run with: ACIP_NONINTERACTIVE=1"
      exit 1
    fi
    if ! prompt_yn "Remove ${TARGET_FILE}?" "N"; then
      log_error "Aborted by user"
      exit 1
    fi
  fi

  # Create backup before removing
  local backup_file
  backup_file="${TARGET_FILE}.uninstalled.$(date +%Y%m%d_%H%M%S)"
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
  curl -fsSL -H "Accept: application/vnd.github.raw" \\
    "https://api.github.com/repos/${ACIP_REPO}/contents/integrations/clawdbot/install.sh?ref=${ACIP_BRANCH}" | bash

Environment Variables:
  CLAWD_WORKSPACE         Workspace directory (default: auto-detect from clawdbot.json, else ~/clawd)
  ACIP_NONINTERACTIVE     Skip prompts; fail if workspace doesn't exist
  ACIP_FORCE              Overwrite without backup
  ACIP_QUIET              Minimal output
  ACIP_UNINSTALL          Remove SECURITY.md instead of installing
  ACIP_ALLOW_UNVERIFIED   Allow install if manifest can't be fetched (NOT recommended)
  ACIP_INJECT             Inject ACIP into SOUL.md/AGENTS.md so it's active today
  ACIP_INJECT_FILE        Injection target (SOUL.md or AGENTS.md; default: SOUL.md)

Examples:
  # Standard install
  curl -fsSL -H "Accept: application/vnd.github.raw" \\
    "https://api.github.com/repos/${ACIP_REPO}/contents/integrations/clawdbot/install.sh?ref=${ACIP_BRANCH}" | bash

  # Custom workspace, non-interactive
  CLAWD_WORKSPACE=~/assistant ACIP_NONINTERACTIVE=1 \\
    curl -fsSL -H "Accept: application/vnd.github.raw" \\
      "https://api.github.com/repos/${ACIP_REPO}/contents/integrations/clawdbot/install.sh?ref=${ACIP_BRANCH}" | bash

  # Uninstall
  ACIP_UNINSTALL=1 \\
    curl -fsSL -H "Accept: application/vnd.github.raw" \\
      "https://api.github.com/repos/${ACIP_REPO}/contents/integrations/clawdbot/install.sh?ref=${ACIP_BRANCH}" | bash

More info: https://github.com/${ACIP_REPO}
EOF
}

# ─────────────────────────────────────────────────────────────────────────────
# Main Entry Point
# ─────────────────────────────────────────────────────────────────────────────

main() {
  setup_colors
  trap cleanup EXIT

  WORKSPACE="$(resolve_workspace)"
  TARGET_FILE="${WORKSPACE%/}/SECURITY.md"

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
