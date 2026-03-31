#!/bin/bash

# ============================================================================
# INSTALL & CONFIGURE CLAUDE CODE
# ============================================================================
# Installs Claude Code (CLI + VS Code extension) and configures all required
# environment variables.
#
# Usage:
#   bash .claude/scripts/install.sh
#
# Configurable variables (edit below or export before running):
#   ANTHROPIC_AUTH_TOKEN_VALUE  — Anthropic API key (or proxy token)
#   ANTHROPIC_BASE_URL_VALUE    — API base URL (optional, for proxies)
#   GITHUB_PAT_VALUE            — GitHub personal access token (for MCP)
#   CONTEXT7_API_KEY_VALUE      — Context7 API key (for docs MCP)
#   DATABASE_URL_VALUE          — PostgreSQL connection string (for DB MCPs)
# ============================================================================

# Ensure we run under bash (arrays, [[ ]], etc.)
if [ -z "$BASH_VERSION" ]; then
  _SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
  _SCRIPT_NAME="$(basename "$0")"
  /bin/bash "$_SCRIPT_DIR/$_SCRIPT_NAME" "$@"
  exit $?
fi

set -euo pipefail

# ========================= CONFIGURATION =========================
# Use environment variables if set, otherwise fall back to these defaults.
# NEVER commit real tokens here. Set them in your shell profile instead.
ANTHROPIC_AUTH_TOKEN_VALUE="${ANTHROPIC_AUTH_TOKEN:-your-anthropic-api-key-here}"
ANTHROPIC_BASE_URL_VALUE="${ANTHROPIC_BASE_URL:-}"
CLAUDE_CODE_DISABLE_BETAS_VALUE="${CLAUDE_CODE_DISABLE_EXPERIMENTAL_BETAS:-}"
GITHUB_PAT_VALUE="${GITHUB_PAT:-your-github-pat-here}"
CONTEXT7_API_KEY_VALUE="${CONTEXT7_API_KEY:-your-context7-api-key-here}"
DATABASE_URL_VALUE="${DATABASE_URL:-postgresql://user:password@localhost:5432/yourdb}"
# =================================================================

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info()    { printf "${BLUE}[INFO]${NC} %s\n" "$1"; }
log_success() { printf "${GREEN}[OK]${NC} %s\n" "$1"; }
log_warn()    { printf "${YELLOW}[WARN]${NC} %s\n" "$1"; }
log_error()   { printf "${RED}[ERROR]${NC} %s\n" "$1"; }

echo ""
echo "============================================================"
echo "   CLAUDE CODE — Install and configure"
echo "============================================================"
echo ""

# ============================================================================
# 1. Check prerequisites (Node.js and npm)
# ============================================================================
log_info "Step 1: Checking prerequisites..."

if ! command -v node &>/dev/null; then
  log_error "Node.js is not installed. Node.js >= 18 is required (>= 22 recommended)."
  exit 1
fi

NODE_VERSION=$(node -v | sed 's/v//' | cut -d. -f1)
if [[ "$NODE_VERSION" -lt 18 ]]; then
  log_error "Node.js $(node -v) is too old. >= 18 required (>= 22 recommended)."
  exit 1
fi
if [[ "$NODE_VERSION" -lt 22 ]]; then
  log_warn "Node.js $(node -v) detected. >= 22 is recommended for full compatibility."
fi
log_success "Node.js $(node -v) detected"

if ! command -v npm &>/dev/null; then
  log_error "npm is not installed."
  exit 1
fi
log_success "npm $(npm -v) detected"

# ============================================================================
# 2. Install Claude Code CLI
# ============================================================================
log_info "Step 2: Installing Claude Code CLI..."

if command -v claude &>/dev/null; then
  CURRENT_VERSION=$(claude --version 2>/dev/null || echo "unknown")
  log_info "Claude Code already installed (version: $CURRENT_VERSION). Updating..."
fi

npm install -g @anthropic-ai/claude-code 2>&1 | tail -3

if ! command -v claude &>/dev/null; then
  log_error "Claude Code CLI installation failed. Check the errors above."
  exit 1
fi
log_success "Claude Code CLI installed: $(claude --version 2>/dev/null || echo 'OK')"

# Switch to native installer (recommended by Anthropic)
log_info "Step 2b: Installing native Claude Code build..."
claude install --force 2>&1 || true
log_success "Native build installed: $(claude --version 2>/dev/null || echo 'OK')"

# ============================================================================
# 3. Install VS Code extension
# ============================================================================
log_info "Step 3: Installing VS Code extension..."

CODE_CMD=""
if command -v code &>/dev/null; then
  CODE_CMD="code"
elif [[ -f "/Applications/Visual Studio Code.app/Contents/Resources/app/bin/code" ]]; then
  CODE_CMD="/Applications/Visual Studio Code.app/Contents/Resources/app/bin/code"
fi

if [[ -n "$CODE_CMD" ]]; then
  EXT_INSTALLED=false
  if "$CODE_CMD" --list-extensions 2>/dev/null | grep -q "anthropic.claude-code"; then
    log_success "Extension anthropic.claude-code already installed in VS Code"
    EXT_INSTALLED=true
  else
    if "$CODE_CMD" --install-extension anthropic.claude-code --force 2>&1 | grep -q "successfully installed"; then
      EXT_INSTALLED=true
      log_success "Extension anthropic.claude-code installed in VS Code"
    else
      log_warn "Direct installation failed. Trying manual download..."
      VSIX_TMP="/tmp/claude-code-$$.vsix"
      VSIX_URL="https://marketplace.visualstudio.com/_apis/public/gallery/publishers/anthropic/vsextensions/claude-code/latest/vspackage"
      if curl -fsSL --compressed --max-time 180 -o "$VSIX_TMP" "$VSIX_URL" 2>/dev/null && [[ -s "$VSIX_TMP" ]]; then
        if file "$VSIX_TMP" | grep -q "Zip"; then
          "$CODE_CMD" --install-extension "$VSIX_TMP" --force 2>&1 && EXT_INSTALLED=true || true
        fi
      fi
      rm -f "$VSIX_TMP" 2>/dev/null
    fi
  fi

  if [[ "$EXT_INSTALLED" != true ]]; then
    log_warn "Could not install extension automatically."
    log_info "Install it manually: VS Code → Extensions → search 'Claude Code' by Anthropic"
  fi
else
  log_warn "'code' not found in PATH — VS Code extension not installed"
  log_info "Install it manually: https://marketplace.visualstudio.com/items?itemName=anthropic.claude-code"
fi

# ============================================================================
# 4. Detect shell profile
# ============================================================================
log_info "Step 4: Detecting shell profile..."

if [[ -n "${ZSH_VERSION:-}" ]] || [[ "$SHELL" == */zsh ]]; then
  SHELL_PROFILE="$HOME/.zshrc"
elif [[ -n "${BASH_VERSION:-}" ]] || [[ "$SHELL" == */bash ]]; then
  SHELL_PROFILE="$HOME/.bashrc"
elif [[ -f "$HOME/.zshrc" ]]; then
  SHELL_PROFILE="$HOME/.zshrc"
elif [[ -f "$HOME/.bashrc" ]]; then
  SHELL_PROFILE="$HOME/.bashrc"
else
  log_error "Could not detect shell profile (.zshrc / .bashrc)"
  exit 1
fi

log_success "Shell profile: $SHELL_PROFILE"

BACKUP_FILE="${SHELL_PROFILE}.bak.install.$(date +%Y%m%d%H%M%S)"
cp "$SHELL_PROFILE" "$BACKUP_FILE"
log_info "Backup created: $BACKUP_FILE"

# ============================================================================
# 5. Configure environment variables in shell profile
# ============================================================================
log_info "Step 5: Configuring environment variables..."

set_env_var() {
  local var_name="$1"
  local var_value="$2"
  local profile="$3"
  local export_line="export ${var_name}=${var_value}"

  if grep -q "^export ${var_name}=" "$profile" 2>/dev/null; then
    sed -i.tmp "s|^export ${var_name}=.*|${export_line}|" "$profile"
    rm -f "${profile}.tmp"
    log_success "Updated: ${var_name}"
  else
    local tmp_file
    tmp_file=$(mktemp)
    echo "$export_line" >"$tmp_file"
    cat "$profile" >>"$tmp_file"
    mv "$tmp_file" "$profile"
    log_success "Added: ${var_name}"
  fi
}

set_env_var "ANTHROPIC_AUTH_TOKEN" "$ANTHROPIC_AUTH_TOKEN_VALUE" "$SHELL_PROFILE"

if [[ -n "$ANTHROPIC_BASE_URL_VALUE" ]]; then
  set_env_var "ANTHROPIC_BASE_URL" "$ANTHROPIC_BASE_URL_VALUE" "$SHELL_PROFILE"
fi

if [[ -n "$CLAUDE_CODE_DISABLE_BETAS_VALUE" ]]; then
  set_env_var "CLAUDE_CODE_DISABLE_EXPERIMENTAL_BETAS" "$CLAUDE_CODE_DISABLE_BETAS_VALUE" "$SHELL_PROFILE"
fi

set_env_var "GITHUB_PAT" "$GITHUB_PAT_VALUE" "$SHELL_PROFILE"
set_env_var "CONTEXT7_API_KEY" "$CONTEXT7_API_KEY_VALUE" "$SHELL_PROFILE"

# ============================================================================
# 6. Configure ~/.claude/settings.json (global permissive permissions)
# ============================================================================
log_info "Step 6: Configuring ~/.claude/settings.json..."

CLAUDE_GLOBAL_DIR="$HOME/.claude"
CLAUDE_GLOBAL_FILE="$CLAUDE_GLOBAL_DIR/settings.json"
mkdir -p "$CLAUDE_GLOBAL_DIR"
cat >"$CLAUDE_GLOBAL_FILE" <<'GLOBAL_SETTINGS_EOF'
{
  "permissions": {
    "allow": [
      "Bash(*)",
      "Read",
      "Write",
      "Edit",
      "Glob",
      "Grep",
      "WebSearch",
      "WebFetch",
      "Agent",
      "NotebookEdit"
    ]
  }
}
GLOBAL_SETTINGS_EOF
log_success "Configured ~/.claude/settings.json (permissive global permissions)"

# Local project settings
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
CLAUDE_LOCAL_DIR="$PROJECT_DIR/.claude"
CLAUDE_SETTINGS_FILE="$CLAUDE_LOCAL_DIR/settings.json"

mkdir -p "$CLAUDE_LOCAL_DIR"

# Minimal project settings — model reflects the standard tier's orchestrator (opus).
# The init wizard (scripts/init-project.sh) stamps per-agent model: fields in
# .claude/agents/ based on the chosen cost tier (shared/models/tiers.json).
# To change tier after init: re-run the init wizard or update agent model: fields.
cat >"$CLAUDE_SETTINGS_FILE" <<'SETTINGS_EOF'
{
  "model": "claude-opus-4-5",
  "env": {
    "ANTHROPIC_DEFAULT_SONNET_MODEL": "claude-sonnet-4-5",
    "ANTHROPIC_DEFAULT_OPUS_MODEL": "claude-opus-4-5",
    "ANTHROPIC_DEFAULT_HAIKU_MODEL": "claude-haiku-4-5"
  }
}
SETTINGS_EOF
log_success "Configured $CLAUDE_SETTINGS_FILE"

# Local settings with permissive permissions
CLAUDE_LOCAL_SETTINGS_FILE="$CLAUDE_LOCAL_DIR/settings.local.json"
cat >"$CLAUDE_LOCAL_SETTINGS_FILE" <<'LOCAL_SETTINGS_EOF'
{
  "permissions": {
    "allow": [
      "Bash(*)",
      "Read",
      "Write",
      "Edit",
      "Glob",
      "Grep",
      "WebSearch",
      "WebFetch",
      "Agent",
      "NotebookEdit"
    ]
  },
  "enabledMcpjsonServers": [
    "context7",
    "github",
    "postgres"
  ]
}
LOCAL_SETTINGS_EOF
log_success "Configured $CLAUDE_LOCAL_SETTINGS_FILE"

# ============================================================================
# 7. Write .mcp.json in project root
# ============================================================================
PROJECT_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
MCP_JSON_FILE="${PROJECT_ROOT}/.mcp.json"

log_info "Step 7: Writing ${MCP_JSON_FILE}..."

cat >"$MCP_JSON_FILE" <<MCP_EOF
{
  "mcpServers": {
    "context7": {
      "type": "http",
      "url": "https://mcp.context7.com/mcp",
      "headers": {
        "X-API-Key": "\${CONTEXT7_API_KEY}"
      }
    },
    "github": {
      "type": "http",
      "url": "https://api.githubcopilot.com/mcp/",
      "headers": {
        "Authorization": "Bearer \${GITHUB_PAT}"
      }
    },
    "postgres": {
      "command": "postgres-mcp",
      "args": ["\${DATABASE_URL:-${DATABASE_URL_VALUE}}"],
      "env": {
        "DATABASE_URL": "\${DATABASE_URL:-${DATABASE_URL_VALUE}}"
      }
    }
  }
}
MCP_EOF
log_success ".mcp.json written to ${MCP_JSON_FILE}"

# Add .mcp.json to .gitignore (it may contain tokens)
GITIGNORE_FILE="${PROJECT_ROOT}/.gitignore"
if [[ -f "$GITIGNORE_FILE" ]]; then
  if ! grep -q "^\.mcp\.json$" "$GITIGNORE_FILE" 2>/dev/null; then
    {
      echo ""
      echo "# MCP config with tokens — do not commit"
      echo ".mcp.json"
    } >>"$GITIGNORE_FILE"
    log_success ".mcp.json added to .gitignore"
  else
    log_info ".mcp.json already in .gitignore"
  fi
else
  {
    echo "# MCP config with tokens — do not commit"
    echo ".mcp.json"
  } >"$GITIGNORE_FILE"
  log_success ".gitignore created with .mcp.json"
fi

# ============================================================================
# 8. Export variables in current session
# ============================================================================
log_info "Step 8: Exporting variables in current session..."

export ANTHROPIC_AUTH_TOKEN="$ANTHROPIC_AUTH_TOKEN_VALUE"
[[ -n "$ANTHROPIC_BASE_URL_VALUE" ]] && export ANTHROPIC_BASE_URL="$ANTHROPIC_BASE_URL_VALUE"
export GITHUB_PAT="$GITHUB_PAT_VALUE"
export CONTEXT7_API_KEY="$CONTEXT7_API_KEY_VALUE"

log_success "Variables exported for current session"

# ============================================================================
# 9. Final verification
# ============================================================================
echo ""
log_info "Step 9: Final verification..."

ISSUES=0

if command -v claude &>/dev/null; then
  log_success "CLI: claude available at $(which claude)"
else
  log_error "CLI: claude not found in PATH"
  ISSUES=$((ISSUES + 1))
fi

for var in ANTHROPIC_AUTH_TOKEN GITHUB_PAT CONTEXT7_API_KEY; do
  if grep -q "^export ${var}=" "$SHELL_PROFILE" 2>/dev/null; then
    log_success "Env: ${var} configured in $SHELL_PROFILE"
  else
    log_error "Env: ${var} NOT found in $SHELL_PROFILE"
    ISSUES=$((ISSUES + 1))
  fi
done

if [[ -f "$CLAUDE_SETTINGS_FILE" ]]; then
  log_success "Config: $CLAUDE_SETTINGS_FILE exists"
else
  log_error "Config: $CLAUDE_SETTINGS_FILE not found"
  ISSUES=$((ISSUES + 1))
fi

if [[ -f "$MCP_JSON_FILE" ]]; then
  log_success "MCP: .mcp.json exists"
else
  log_error "MCP: .mcp.json not found"
  ISSUES=$((ISSUES + 1))
fi

# ============================================================================
# Summary
# ============================================================================
echo ""
echo "============================================================"
if [[ $ISSUES -eq 0 ]]; then
  log_success "Installation completed successfully!"
else
  log_warn "Installation completed with $ISSUES warning(s). Review the messages above."
fi
echo "============================================================"
echo ""
log_info "To start using Claude Code:"
log_info "  1. Restart your terminal (or run: source $SHELL_PROFILE)"
log_info "  2. Run: claude"
echo ""
