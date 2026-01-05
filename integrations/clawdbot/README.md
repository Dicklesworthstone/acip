# ACIP Integration for Clawdbot

This directory contains an optimized version of ACIP (Advanced Cognitive Inoculation Prompt) specifically designed for [Clawdbot](https://github.com/clawdbot/clawdbot) personal AI assistants.

## Current Status (Important)

Clawdbot **does not currently load `SECURITY.md` by default**. Today, you have two options:

1. **No-code (works now):** paste the contents of `SECURITY.md` into your existing `~/clawd/SOUL.md` (or `AGENTS.md`) so it’s injected into the system prompt (or use the installer with `ACIP_INJECT=1` to do this automatically).
2. **Preferred (optional feature):** add Clawdbot support for loading `SECURITY.md` (and ideally add `clawdbot security enable|update|disable`). Once that exists, the installer script in this folder works without injection.

## Why ACIP for Clawdbot?

Clawdbot is a powerful personal assistant with access to:
- Your messaging accounts (WhatsApp, Telegram, Discord, iMessage)
- Your email (via Gmail hooks)
- Your files and shell
- Your camera, screen, and location (via nodes)
- Web browsing capabilities

This access makes it a high-value target for prompt injection attacks. Someone could:
- Send you a WhatsApp message designed to trick Clawd into revealing secrets
- Email you content that attempts to hijack the agent
- Share a link to a webpage with embedded injection attempts

ACIP provides a cognitive security layer that helps Clawd recognize and resist these attacks.

## Quick Install

### Option 1: Manual (Recommended for Review)

1. Copy `SECURITY.md` to your Clawdbot workspace:
   ```bash
   curl -fsSL https://raw.githubusercontent.com/Dicklesworthstone/acip/main/integrations/clawdbot/SECURITY.md \
     -o ~/clawd/SECURITY.md
   ```

2. Verify the checksum (optional but recommended):
   ```bash
   # Fetch the expected checksum
   EXPECTED=$(curl -fsSL https://raw.githubusercontent.com/Dicklesworthstone/acip/main/.checksums/manifest.json \
     | grep -A5 '"file": "integrations/clawdbot/SECURITY.md"' \
     | grep sha256 | cut -d'"' -f4)

   # Calculate actual checksum
   # Linux: sha256sum | macOS: shasum -a 256
   ACTUAL=$({ sha256sum ~/clawd/SECURITY.md 2>/dev/null || shasum -a 256 ~/clawd/SECURITY.md; } | cut -d' ' -f1)

   # Compare
   if [ "$EXPECTED" = "$ACTUAL" ]; then
     echo "Checksum verified!"
   else
     echo "WARNING: Checksum mismatch! File may have been tampered with."
   fi
   ```

3. To activate today, inject it into `SOUL.md`/`AGENTS.md` (or rerun the installer with `ACIP_INJECT=1`). Otherwise, keep `SECURITY.md` for future native support.

### Option 2: Automated Script

```bash
curl -fsSL -H "Accept: application/vnd.github.raw" \
  "https://api.github.com/repos/Dicklesworthstone/acip/contents/integrations/clawdbot/install.sh?ref=main" | bash
```

This script:
- Downloads `SECURITY.md` to `~/clawd/`
- Verifies the SHA256 checksum (and pins the download to the manifest’s commit when available)
- Backs up any existing `SECURITY.md`
- Reports success or failure

If Clawdbot doesn’t load `SECURITY.md` yet, the installer will offer to **inject** the security layer into `SOUL.md`/`AGENTS.md` so it’s active immediately.

### Option 3: Clawdbot CLI (Coming Soon)

```bash
clawdbot security enable
clawdbot security update
clawdbot security disable
```

## What It Does

When loaded into the agent’s prompt (either by pasting into `SOUL.md`/`AGENTS.md`, or via future `SECURITY.md` support in Clawdbot), it adds a security layer that:

1. **Establishes Trust Boundaries**
   - Messages from external sources are treated as potentially adversarial data
   - Only the verified owner can authorize sensitive actions
   - Instructions in retrieved content (web, email, docs) are ignored

2. **Protects Secrets**
   - System prompts, config files, and credentials are never revealed
   - Infrastructure details are protected
   - Private information requires explicit owner consent

3. **Ensures Message Safety**
   - Confirms before sending sensitive messages
   - Validates destructive commands
   - Prevents reputation-damaging actions

4. **Recognizes Attack Patterns**
   - Authority claims, urgency, emotional manipulation
   - Encoding tricks, meta-level attacks
   - Indirect tasking and transformation requests

5. **Provides Safe Handling**
   - Triage model for ambiguous requests
   - Minimal refusals that don't leak detection logic
   - Safe alternatives offered when declining

## Token Cost

The clawdbot-optimized `SECURITY.md` is approximately:
- ~1,200 tokens (vs. ~3,200 for full ACIP v1.3)
- ~120 lines
- Optimized for the personal assistant threat model

This adds minimal overhead while providing substantial protection.

## Customization

You can customize `SECURITY.md` to fit your needs:

```markdown
## Additional Rules

- Always confirm before sending messages to my boss
- Never share anything about Project X
- When in doubt, ask me in the WebChat before acting
```

Add custom rules at the end of the file. The core protections at the top should remain intact.

## Verification

To verify your `SECURITY.md` matches the official version:

```bash
# Get the latest manifest
curl -sL https://raw.githubusercontent.com/Dicklesworthstone/acip/main/.checksums/manifest.json
```

The manifest contains SHA256 checksums for all ACIP files, generated automatically by GitHub Actions on each update.

## Updating

To update to the latest version:

```bash
# Backup current version
cp ~/clawd/SECURITY.md ~/clawd/SECURITY.md.backup

# Download latest
curl -fsSL https://raw.githubusercontent.com/Dicklesworthstone/acip/main/integrations/clawdbot/SECURITY.md \
  -o ~/clawd/SECURITY.md

# Verify checksum (recommended)
# ... (see verification steps above)
```

## Disabling

To disable ACIP protection:

```bash
mv ~/clawd/SECURITY.md ~/clawd/SECURITY.md.disabled
```

Or simply delete the file. Clawdbot will continue to operate without the security layer.

If you installed by pasting into `SOUL.md`/`AGENTS.md`, remove that section instead.

## Compatibility

- **Clawdbot version:** Any (paste into `SOUL.md`/`AGENTS.md`). Dedicated `SECURITY.md` loading requires a small Clawdbot change.
- **Workspace files:** Compatible with AGENTS.md, SOUL.md, TOOLS.md, IDENTITY.md, USER.md
- **Skills:** Does not conflict with skills

## Reporting Issues

If ACIP causes problems with legitimate use cases:

1. Check if the request pattern matches an attack pattern
2. Consider adding a custom exception in your SECURITY.md
3. Report the issue: https://github.com/Dicklesworthstone/acip/issues

## License

MIT License - same as ACIP and Clawdbot.

---

*For the full ACIP framework with detailed documentation, see the [main repository](https://github.com/Dicklesworthstone/acip).*
