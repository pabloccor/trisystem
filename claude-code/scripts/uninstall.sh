#!/bin/bash

# ============================================================================
# UNINSTALL CLAUDE CODE — Complete removal
# ============================================================================
# Removes Claude Code entirely:
#   - CLI (npm global)
#   - VS Code extension
#   - Environment variables from shell profile
#   - Configuration (~/.claude, ~/.claude.json)
#   - Cache (npx, npm, ~/Library/Caches)
#   - Shell completions
#
# Usage:
#   bash .claude/scripts/uninstall.sh
#
# Compatible with bash, zsh, and sh. Does not prompt interactively.
# ============================================================================

# Ensure we run under bash
if [ -z "$BASH_VERSION" ]; then
  _SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
  _SCRIPT_NAME="$(basename "$0")"
  /bin/bash "$_SCRIPT_DIR/$_SCRIPT_NAME" "$@"
  exit $?
fi

set -euo pipefail

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

remove_path() {
  local target="$1"
  if [[ -L "$target" ]]; then
    rm -f "$target" && log_success "Removed symlink: $target" || log_warn "Could not remove: $target"
  elif [[ -d "$target" ]]; then
    rm -rf "$target" && log_success "Removed directory: $target" || log_warn "Could not remove: $target"
  elif [[ -f "$target" ]]; then
    rm -f "$target" && log_success "Removed file: $target" || log_warn "Could not remove: $target"
  fi
}

echo ""
echo "============================================================"
echo "   CLAUDE CODE — Complete uninstall"
echo "============================================================"
echo ""

# ============================================================================
# 1. Remove environment variables from shell profile
# ============================================================================
log_info "Step 1: Removing environment variables from shell profile..."

if [[ -n "${ZSH_VERSION:-}" ]] || [[ "$SHELL" == */zsh ]]; then
  SHELL_PROFILE="$HOME/.zshrc"
elif [[ -n "${BASH_VERSION:-}" ]] || [[ "$SHELL" == */bash ]]; then
  SHELL_PROFILE="$HOME/.bashrc"
elif [[ -f "$HOME/.zshrc" ]]; then
  SHELL_PROFILE="$HOME/.zshrc"
elif [[ -f "$HOME/.bashrc" ]]; then
  SHELL_PROFILE="$HOME/.bashrc"
else
  SHELL_PROFILE=""
fi

if [[ -n "$SHELL_PROFILE" && -f "$SHELL_PROFILE" ]]; then
  BACKUP_FILE="${SHELL_PROFILE}.bak.uninstall.$(date +%Y%m%d%H%M%S)"
  cp "$SHELL_PROFILE" "$BACKUP_FILE"
  log_info "Backup: $BACKUP_FILE"

  VARS_TO_REMOVE=(
    "ANTHROPIC_AUTH_TOKEN"
    "ANTHROPIC_BASE_URL"
    "CLAUDE_CODE_DISABLE_EXPERIMENTAL_BETAS"
    "GITHUB_PAT"
    "CONTEXT7_API_KEY"
  )

  for var in "${VARS_TO_REMOVE[@]}"; do
    if grep -q "^export ${var}=" "$SHELL_PROFILE" 2>/dev/null; then
      sed -i.tmp "/^export ${var}=/d" "$SHELL_PROFILE"
      rm -f "${SHELL_PROFILE}.tmp"
      log_success "Removed: export ${var}"
    else
      log_info "${var} not found in ${SHELL_PROFILE}"
    fi
    unset "$var" 2>/dev/null || true
  done
else
  log_warn "Shell profile not found — skipping variable cleanup"
fi

# ============================================================================
# 2. Remove claude binaries
# ============================================================================
log_info "Step 2: Looking for and removing claude binaries..."

which -a claude 2>/dev/null | while IFS= read -r bin_path; do
  [[ -z "$bin_path" ]] && continue
  log_info "Found: $bin_path"
  remove_path "$bin_path"
done || true

for bin_dir in /usr/local/bin /usr/bin "$HOME/.local/bin" "$HOME/.npm-global/bin"; do
  for name in claude claude-code; do
    if [[ -e "$bin_dir/$name" || -L "$bin_dir/$name" ]]; then
      remove_path "$bin_dir/$name"
    fi
  done
done

# ============================================================================
# 3. Uninstall npm/bun global package
# ============================================================================
log_info "Step 3: Uninstalling global package..."

if command -v npm &>/dev/null; then
  npm uninstall -g @anthropic-ai/claude-code 2>/dev/null &&
    log_success "npm: @anthropic-ai/claude-code uninstalled" ||
    log_info "npm: package was not installed globally"
fi

if command -v bun &>/dev/null; then
  bun uninstall -g @anthropic-ai/claude-code 2>/dev/null &&
    log_success "bun: @anthropic-ai/claude-code uninstalled" ||
    log_info "bun: package was not installed globally"
fi

# ============================================================================
# 4. Uninstall VS Code extension
# ============================================================================
log_info "Step 4: Uninstalling VS Code extension..."

CODE_CMD=""
if command -v code &>/dev/null; then
  CODE_CMD="code"
elif [[ -f "/Applications/Visual Studio Code.app/Contents/Resources/app/bin/code" ]]; then
  CODE_CMD="/Applications/Visual Studio Code.app/Contents/Resources/app/bin/code"
fi

if [[ -n "$CODE_CMD" ]]; then
  "$CODE_CMD" --uninstall-extension anthropic.claude-code 2>/dev/null &&
    log_success "Extension anthropic.claude-code uninstalled" ||
    log_info "Extension not found in VS Code"

  if [[ -d "$HOME/.vscode/extensions" ]]; then
    find "$HOME/.vscode/extensions" -maxdepth 1 -type d -iname "anthropic.claude-code-*" 2>/dev/null |
      while IFS= read -r ext_dir; do
        [[ -z "$ext_dir" ]] && continue
        remove_path "$ext_dir"
      done || true
  fi
else
  log_info "VS Code not found — skipping"
fi

# ============================================================================
# 5. Clean npx cache
# ============================================================================
log_info "Step 5: Cleaning npx cache..."

NPX_CACHE_DIR="$HOME/.npm/_npx"
if [[ -d "$NPX_CACHE_DIR" ]]; then
  find "$NPX_CACHE_DIR" -path "*/@anthropic-ai/claude-code" -type d 2>/dev/null |
    while IFS= read -r npx_dir; do
      [[ -z "$npx_dir" ]] && continue
      local_npx_root="$(echo "$npx_dir" | sed "s|/node_modules/@anthropic-ai/claude-code.*||")"
      if [[ -n "$local_npx_root" && -d "$local_npx_root" ]]; then
        remove_path "$local_npx_root"
      fi
    done || true
fi

# ============================================================================
# 6. Remove residual node_modules
# ============================================================================
log_info "Step 6: Searching for residual installations in node_modules..."

for search_root in /usr/local/lib /usr/lib "$HOME/.npm-global" "$HOME/.nvm"; do
  [[ -d "$search_root" ]] || continue
  find "$search_root" -path "*node_modules/@anthropic-ai/claude-code" -type d 2>/dev/null |
    while IFS= read -r nm_dir; do
      [[ -z "$nm_dir" ]] && continue
      remove_path "$nm_dir"
    done || true
done

# ============================================================================
# 7. Remove project MCP config
# ============================================================================
log_info "Step 7: Removing project MCP config..."

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
MCP_JSON_FILE="${PROJECT_ROOT}/.mcp.json"

if [[ -f "$MCP_JSON_FILE" ]]; then
  rm -f "$MCP_JSON_FILE"
  log_success ".mcp.json removed from ${PROJECT_ROOT}"
else
  log_info ".mcp.json not found in ${PROJECT_ROOT}"
fi

CLAUDE_LOCAL_SETTINGS="${PROJECT_ROOT}/.claude/settings.local.json"
if [[ -f "$CLAUDE_LOCAL_SETTINGS" ]]; then
  rm -f "$CLAUDE_LOCAL_SETTINGS"
  log_success "settings.local.json removed"
fi

# Remove MCP servers from claude CLI if available
if command -v claude &>/dev/null; then
  for mcp_name in context7 github postgres; do
    claude mcp remove "$mcp_name" 2>/dev/null &&
      log_success "MCP server $mcp_name removed from claude CLI" ||
      log_info "MCP server $mcp_name was not registered"
  done
fi

# ============================================================================
# 8. Remove ~/.claude and ~/.claude.json
# ============================================================================
log_info "Step 8: Removing ~/.claude configuration directory..."

remove_path "$HOME/.claude"
remove_path "$HOME/.claude.json"

# ============================================================================
# 9. Remove config and data files
# ============================================================================
log_info "Step 9: Cleaning config and data files..."

DATA_SEARCH_DIRS=("$HOME/.config" "$HOME/.local/share" "$HOME/.local/state")

for dir in "${DATA_SEARCH_DIRS[@]}"; do
  if [[ -d "$dir" ]]; then
    find "$dir" -maxdepth 2 \( -iname "*claude*" -o -iname "*@anthropic-ai*" \) 2>/dev/null |
      while IFS= read -r found_path; do
        [[ -z "$found_path" ]] && continue
        case "$found_path" in
          *claude-code* | *claude_code* | *@anthropic-ai* | */claude | */claude/*)
            remove_path "$found_path"
            ;;
        esac
      done || true
  fi
done

# ============================================================================
# 10. Remove cache directories
# ============================================================================
log_info "Step 10: Cleaning cache directories..."

CACHE_SEARCH_DIRS=("$HOME/.cache" "$HOME/Library/Caches")

for dir in "${CACHE_SEARCH_DIRS[@]}"; do
  if [[ -d "$dir" ]]; then
    find "$dir" -maxdepth 2 -iname "*claude*" 2>/dev/null |
      while IFS= read -r cache_path; do
        [[ -z "$cache_path" ]] && continue
        remove_path "$cache_path"
      done || true
  fi
done

# ============================================================================
# 11. Remove shell completions
# ============================================================================
log_info "Step 11: Removing shell completions..."

COMPLETION_SEARCH_DIRS=(
  "$HOME/.zsh"
  "$HOME/.bash_completion.d"
  "/usr/local/share/zsh/site-functions"
  "/usr/share/bash-completion/completions"
  "/usr/local/share/bash-completion/completions"
)

for dir in "${COMPLETION_SEARCH_DIRS[@]}"; do
  if [[ -d "$dir" ]]; then
    find "$dir" -maxdepth 2 -iname "*claude*" -type f 2>/dev/null |
      while IFS= read -r comp_file; do
        [[ -z "$comp_file" ]] && continue
        remove_path "$comp_file"
      done || true
  fi
done

# ============================================================================
# 12. Warn about residual references in shell configs
# ============================================================================
log_info "Step 12: Checking for residual references in shell configs..."

SHELL_CONFIGS=()
for rc in ".zshrc" ".bashrc" ".bash_profile" ".profile" ".zprofile"; do
  [[ -f "$HOME/$rc" ]] && SHELL_CONFIGS+=("$HOME/$rc")
done

for config in "${SHELL_CONFIGS[@]}"; do
  if grep -qi "claude" "$config" 2>/dev/null; then
    log_warn "References to 'claude' remain in $config — review manually:"
    grep -n -i "claude" "$config" 2>/dev/null | head -5 | while read -r line; do
      echo "         $line"
    done
  fi
done

# ============================================================================
# 13. Final verification
# ============================================================================
echo ""
log_info "Step 13: Final verification..."

ISSUES=0

if command -v claude &>/dev/null; then
  log_error "claude still exists: $(which claude)"
  ISSUES=$((ISSUES + 1))
else
  log_success "claude not found in PATH"
fi

if [[ -d "$HOME/.claude" ]]; then
  log_warn "~/.claude still exists"
  ISSUES=$((ISSUES + 1))
else
  log_success "~/.claude removed"
fi

if [[ -f "$HOME/.claude.json" ]]; then
  log_warn "~/.claude.json still exists"
  ISSUES=$((ISSUES + 1))
else
  log_success "~/.claude.json removed"
fi

if [[ -n "${CODE_CMD:-}" ]]; then
  if "$CODE_CMD" --list-extensions 2>/dev/null | grep -q "anthropic.claude-code"; then
    log_warn "VS Code extension still installed"
    ISSUES=$((ISSUES + 1))
  else
    log_success "VS Code extension removed"
  fi
fi

echo ""
echo "============================================================"
if [[ $ISSUES -eq 0 ]]; then
  log_success "Claude Code removed completely!"
else
  log_warn "Uninstall completed with $ISSUES warning(s). Review the messages above."
fi
echo "============================================================"
echo ""
log_info "Restart your terminal for changes to take effect."
echo ""
