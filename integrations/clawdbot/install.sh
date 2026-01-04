#!/usr/bin/env bash
#
# ACIP Installer for Clawdbot
# Downloads and verifies SECURITY.md for your Clawdbot workspace
#
# Usage:
#   curl -sL https://raw.githubusercontent.com/Dicklesworthstone/acip/main/integrations/clawdbot/install.sh | bash
#
# Or with custom workspace:
#   CLAWD_WORKSPACE=~/my-clawd curl -sL ... | bash
#

set -euo pipefail

# Configuration
ACIP_REPO="Dicklesworthstone/acip"
ACIP_BRANCH="main"
SECURITY_FILE="integrations/clawdbot/SECURITY.md"
MANIFEST_URL="https://raw.githubusercontent.com/${ACIP_REPO}/${ACIP_BRANCH}/.checksums/manifest.json"
SECURITY_URL="https://raw.githubusercontent.com/${ACIP_REPO}/${ACIP_BRANCH}/${SECURITY_FILE}"

# Workspace directory (default: ~/clawd)
WORKSPACE="${CLAWD_WORKSPACE:-$HOME/clawd}"
TARGET_FILE="${WORKSPACE}/SECURITY.md"

# Colors (if terminal supports them)
if [[ -t 1 ]]; then
  RED='\033[0;31m'
  GREEN='\033[0;32m'
  YELLOW='\033[1;33m'
  BLUE='\033[0;34m'
  NC='\033[0m' # No Color
else
  RED=''
  GREEN=''
  YELLOW=''
  BLUE=''
  NC=''
fi

echo -e "${BLUE}ACIP Installer for Clawdbot${NC}"
echo "================================"
echo ""

# Check for required tools
check_requirements() {
  local missing=()

  command -v curl >/dev/null 2>&1 || missing+=("curl")
  command -v sha256sum >/dev/null 2>&1 || command -v shasum >/dev/null 2>&1 || missing+=("sha256sum or shasum")

  if [[ ${#missing[@]} -gt 0 ]]; then
    echo -e "${RED}Error: Missing required tools: ${missing[*]}${NC}"
    exit 1
  fi
}

# Cross-platform SHA256
sha256() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | cut -d' ' -f1
  elif command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$1" | cut -d' ' -f1
  else
    echo ""
  fi
}

# Fetch expected checksum from manifest
get_expected_checksum() {
  echo -e "${BLUE}Fetching checksum manifest...${NC}"

  local manifest
  manifest=$(curl -sL --fail "$MANIFEST_URL" 2>/dev/null) || {
    echo -e "${YELLOW}Warning: Could not fetch manifest. Skipping checksum verification.${NC}"
    echo ""
    return
  }

  # Try to extract checksum for SECURITY.md
  # The manifest structure has versions array, but we need to look for the clawdbot file
  # For now, we'll compute and display the checksum for manual verification
  echo -e "${YELLOW}Note: Checksum verification requires manifest entry for clawdbot integration.${NC}"
  echo ""
}

# Main installation
main() {
  check_requirements

  # Ensure workspace exists
  if [[ ! -d "$WORKSPACE" ]]; then
    echo -e "${YELLOW}Workspace directory does not exist: $WORKSPACE${NC}"
    echo -n "Create it? [y/N] "
    read -r response
    if [[ "$response" =~ ^[Yy]$ ]]; then
      mkdir -p "$WORKSPACE"
      echo -e "${GREEN}Created: $WORKSPACE${NC}"
    else
      echo "Aborted."
      exit 1
    fi
  fi

  # Backup existing file
  if [[ -f "$TARGET_FILE" ]]; then
    local backup="${TARGET_FILE}.backup.$(date +%Y%m%d%H%M%S)"
    echo -e "${YELLOW}Backing up existing SECURITY.md to:${NC}"
    echo "  $backup"
    cp "$TARGET_FILE" "$backup"
  fi

  # Download SECURITY.md
  echo -e "${BLUE}Downloading SECURITY.md...${NC}"
  if ! curl -sL --fail "$SECURITY_URL" -o "$TARGET_FILE"; then
    echo -e "${RED}Error: Failed to download SECURITY.md${NC}"
    exit 1
  fi

  # Calculate and display checksum
  local checksum
  checksum=$(sha256 "$TARGET_FILE")
  echo ""
  echo -e "${GREEN}Downloaded successfully!${NC}"
  echo ""
  echo "File: $TARGET_FILE"
  echo "SHA256: $checksum"
  echo ""

  # Verify file looks reasonable
  local lines
  lines=$(wc -l < "$TARGET_FILE" | tr -d ' ')
  if [[ "$lines" -lt 50 ]]; then
    echo -e "${RED}Warning: File seems too short ($lines lines). May be corrupted.${NC}"
    exit 1
  fi

  echo -e "${GREEN}Installation complete!${NC}"
  echo ""
  echo "Next steps:"
  echo "  1. Review the file: less $TARGET_FILE"
  echo "  2. Customize if needed (add rules at the end)"
  echo "  3. Restart Clawdbot to load the new security layer"
  echo ""
  echo "To verify against official checksum:"
  echo "  Visit: https://github.com/${ACIP_REPO}/tree/main/.checksums"
  echo ""
  echo -e "${BLUE}Thank you for using ACIP!${NC}"
}

main "$@"
