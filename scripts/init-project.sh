#!/usr/bin/env bash
# init-project.sh — Initialize a new project with the three-doc template
# Usage: ./scripts/init-project.sh [target-dir]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATE_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# ── Colors ────────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

info()    { echo -e "${CYAN}${BOLD}==>${RESET} $*"; }
success() { echo -e "${GREEN}✓${RESET} $*"; }
warn()    { echo -e "${YELLOW}!${RESET} $*"; }
error()   { echo -e "${RED}ERROR:${RESET} $*" >&2; exit 1; }
prompt()  { echo -e "${BOLD}$*${RESET}"; }

# ── Helpers ───────────────────────────────────────────────────────────────────
ask() {
  local question="$1" default="${2:-}" answer
  if [[ -n "$default" ]]; then
    read -rp "$(echo -e "${BOLD}${question}${RESET} [${default}]: ")" answer
    echo "${answer:-$default}"
  else
    read -rp "$(echo -e "${BOLD}${question}${RESET}: ")" answer
    echo "$answer"
  fi
}

ask_choice() {
  # ask_choice "label" option1 option2 ...
  # Returns the chosen value
  local label="$1"; shift
  local options=("$@")
  local i answer
  echo -e "${BOLD}${label}${RESET}"
  for i in "${!options[@]}"; do
    echo "  $((i+1))) ${options[$i]}"
  done
  while true; do
    read -rp "$(echo -e "${BOLD}Choice [1-${#options[@]}]:${RESET} ")" answer
    if [[ "$answer" =~ ^[0-9]+$ ]] && (( answer >= 1 && answer <= ${#options[@]} )); then
      echo "${options[$((answer-1))]}"
      return
    fi
    warn "Please enter a number between 1 and ${#options[@]}."
  done
}

copy_dir() {
  local src="$1" dst="$2"
  if [[ -d "$src" ]]; then
    mkdir -p "$dst"
    cp -r "$src/." "$dst/"
    success "Copied $(basename "$src")/ → $dst"
  fi
}

copy_file() {
  local src="$1" dst="$2"
  if [[ -f "$src" ]]; then
    mkdir -p "$(dirname "$dst")"
    cp "$src" "$dst"
    success "Copied $(basename "$src") → $dst"
  fi
}

# ── Banner ────────────────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}Three-Doc Project Template — Init Wizard${RESET}"
echo "────────────────────────────────────────────"
echo ""

# ── Step 1: Target directory ──────────────────────────────────────────────────
if [[ -n "${1:-}" ]]; then
  TARGET_DIR="$(realpath "$1")"
else
  TARGET_DIR="$(ask "Target project directory" "$(pwd)")"
  TARGET_DIR="$(realpath "$TARGET_DIR")"
fi

if [[ ! -d "$TARGET_DIR" ]]; then
  read -rp "$(echo -e "${BOLD}Directory '$TARGET_DIR' does not exist. Create it? [Y/n]:${RESET} ")" confirm
  if [[ "${confirm:-Y}" =~ ^[Yy]$ ]]; then
    mkdir -p "$TARGET_DIR"
    success "Created $TARGET_DIR"
  else
    error "Aborted."
  fi
fi

info "Target: $TARGET_DIR"
echo ""

# ── Step 2: Project name ──────────────────────────────────────────────────────
PROJECT_NAME="$(ask "Project name (used as the template prefix)" "$(basename "$TARGET_DIR")")"
# Sanitize: uppercase letters, digits, underscores, hyphens only
PROJECT_PREFIX="$(echo "$PROJECT_NAME" | tr '[:lower:]' '[:upper:]' | tr -s ' ' '_' | tr -cd 'A-Z0-9_-')"
info "Document prefix: ${PROJECT_PREFIX}_"
echo ""

# ── Step 3: Runtime ───────────────────────────────────────────────────────────
RUNTIME="$(ask_choice "Which AI coding runtime will you use?" \
  "opencode" \
  "claude-code" \
  "both")"
echo ""

# ── Step 4: Template size ─────────────────────────────────────────────────────
TEMPLATE_SIZE="$(ask_choice "Template size for source docs?" \
  "slim  (starter structure, ~200 lines each — fill in your own content)" \
  "empty (no template files — you will generate them with ChatGPT)")"
echo ""

# ── Step 5: Cheatsheet ────────────────────────────────────────────────────────
INCLUDE_CHEATSHEET="$(ask_choice "Copy cheat sheet?" \
  "yes" \
  "no")"
echo ""

# ── Confirm ───────────────────────────────────────────────────────────────────
echo -e "${BOLD}Summary${RESET}"
echo "  Target:        $TARGET_DIR"
echo "  Project name:  $PROJECT_NAME  (prefix: ${PROJECT_PREFIX}_)"
echo "  Runtime:       $RUNTIME"
echo "  Template size: $TEMPLATE_SIZE"
echo "  Cheat sheet:   $INCLUDE_CHEATSHEET"
echo ""
read -rp "$(echo -e "${BOLD}Proceed? [Y/n]:${RESET} ")" go
if [[ ! "${go:-Y}" =~ ^[Yy]$ ]]; then
  warn "Aborted."
  exit 0
fi
echo ""

# ── Copy shared content ───────────────────────────────────────────────────────
info "Copying shared agents, skills, and rules..."

if [[ "$RUNTIME" == "claude-code" || "$RUNTIME" == "both" ]]; then
  copy_dir "$TEMPLATE_ROOT/shared/agents" "$TARGET_DIR/.claude/agents"
  copy_dir "$TEMPLATE_ROOT/shared/skills" "$TARGET_DIR/.claude/skills"
  copy_dir "$TEMPLATE_ROOT/shared/rules"  "$TARGET_DIR/.claude/rules"
fi

if [[ "$RUNTIME" == "opencode" || "$RUNTIME" == "both" ]]; then
  copy_dir "$TEMPLATE_ROOT/shared/agents" "$TARGET_DIR/.opencode/agents"
  copy_dir "$TEMPLATE_ROOT/shared/skills" "$TARGET_DIR/.opencode/skills"
  copy_dir "$TEMPLATE_ROOT/shared/rules"  "$TARGET_DIR/.opencode/rules"
fi

# ── Copy runtime-specific files ───────────────────────────────────────────────
if [[ "$RUNTIME" == "claude-code" || "$RUNTIME" == "both" ]]; then
  info "Copying Claude Code runtime files..."
  copy_dir  "$TEMPLATE_ROOT/claude-code/bin"     "$TARGET_DIR/.claude/bin"
  copy_dir  "$TEMPLATE_ROOT/claude-code/hooks"   "$TARGET_DIR/.claude/hooks"
  copy_dir  "$TEMPLATE_ROOT/claude-code/scripts" "$TARGET_DIR/.claude/scripts"
  copy_dir  "$TEMPLATE_ROOT/claude-code/memory"  "$TARGET_DIR/.claude/memory"
  copy_dir  "$TEMPLATE_ROOT/claude-code/tasks"   "$TARGET_DIR/.claude/tasks"
  copy_file "$TEMPLATE_ROOT/claude-code/CLAUDE.md" "$TARGET_DIR/CLAUDE.md"
  if [[ ! -f "$TARGET_DIR/.claude/settings.json" ]]; then
    copy_file "$TEMPLATE_ROOT/claude-code/settings.json.example" "$TARGET_DIR/.claude/settings.json"
  fi
fi

if [[ "$RUNTIME" == "opencode" || "$RUNTIME" == "both" ]]; then
  info "Copying OpenCode runtime files..."
  copy_dir  "$TEMPLATE_ROOT/opencode/plugins" "$TARGET_DIR/.opencode/plugins"

  # AGENTS.md — substitute PROJECT_NAME placeholder
  if [[ -f "$TEMPLATE_ROOT/opencode/AGENTS.md.template" ]]; then
    mkdir -p "$TARGET_DIR"
    sed "s/{{PROJECT_NAME}}/${PROJECT_NAME}/g" \
      "$TEMPLATE_ROOT/opencode/AGENTS.md.template" \
      > "$TARGET_DIR/AGENTS.md"
    success "Generated AGENTS.md"
  fi

  # opencode.json
  if [[ ! -f "$TARGET_DIR/opencode.json" ]]; then
    copy_file "$TEMPLATE_ROOT/opencode/opencode.json" "$TARGET_DIR/opencode.json"
  fi

  # package.json for plugins
  copy_file "$TEMPLATE_ROOT/opencode/package.json" "$TARGET_DIR/.opencode/package.json"

  # Also copy .claude/ runtime dirs for the compatibility layer
  copy_dir "$TEMPLATE_ROOT/claude-code/bin"    "$TARGET_DIR/.claude/bin"
  copy_dir "$TEMPLATE_ROOT/claude-code/memory" "$TARGET_DIR/.claude/memory"
  copy_dir "$TEMPLATE_ROOT/claude-code/tasks"  "$TARGET_DIR/.claude/tasks"
fi

# ── Copy source-of-truth templates ────────────────────────────────────────────
info "Copying source-of-truth document templates..."

SOT_DIR="$TARGET_DIR/docs/source-of-truth"
mkdir -p "$SOT_DIR"

if [[ "$TEMPLATE_SIZE" == slim* ]]; then
  SRC="$TEMPLATE_ROOT/templates/slim"
  copy_file "$SRC/instrucciones.md" "$SOT_DIR/instrucciones.md"

  # Rename with project prefix
  if [[ -f "$SRC/PREFIX_IMPLEMENTATION_CHECKLIST.md" ]]; then
    cp "$SRC/PREFIX_IMPLEMENTATION_CHECKLIST.md" \
       "$SOT_DIR/${PROJECT_PREFIX}_IMPLEMENTATION_CHECKLIST.md"
    success "Copied → ${PROJECT_PREFIX}_IMPLEMENTATION_CHECKLIST.md"
  fi
  if [[ -f "$SRC/PREFIX_TECHNICAL_GUIDE.md" ]]; then
    cp "$SRC/PREFIX_TECHNICAL_GUIDE.md" \
       "$SOT_DIR/${PROJECT_PREFIX}_TECHNICAL_GUIDE.md"
    success "Copied → ${PROJECT_PREFIX}_TECHNICAL_GUIDE.md"
  fi
else
  # Empty — create placeholder stubs so bootstrap doesn't fail
  touch "$SOT_DIR/instrucciones.md"
  touch "$SOT_DIR/${PROJECT_PREFIX}_IMPLEMENTATION_CHECKLIST.md"
  touch "$SOT_DIR/${PROJECT_PREFIX}_TECHNICAL_GUIDE.md"
  warn "Created empty source-of-truth stubs in $SOT_DIR"
  warn "Fill them in before running the bootstrap script."
fi

# ── Cheat sheet ───────────────────────────────────────────────────────────────
if [[ "$INCLUDE_CHEATSHEET" == "yes" ]]; then
  if [[ "$RUNTIME" == "claude-code" ]]; then
    copy_file "$TEMPLATE_ROOT/cheatsheets/CHEAT_SHEET_CLAUDE.md" "$TARGET_DIR/CHEAT_SHEET.md"
  elif [[ "$RUNTIME" == "opencode" ]]; then
    copy_file "$TEMPLATE_ROOT/cheatsheets/CHEAT_SHEET_OPENCODE.md" "$TARGET_DIR/CHEAT_SHEET.md"
  else
    copy_file "$TEMPLATE_ROOT/cheatsheets/CHEAT_SHEET_CLAUDE.md" "$TARGET_DIR/CHEAT_SHEET_CLAUDE.md"
    copy_file "$TEMPLATE_ROOT/cheatsheets/CHEAT_SHEET_OPENCODE.md" "$TARGET_DIR/CHEAT_SHEET_OPENCODE.md"
  fi
fi

# ── Make scripts executable ───────────────────────────────────────────────────
if [[ -d "$TARGET_DIR/.claude/hooks" ]]; then
  chmod +x "$TARGET_DIR/.claude/hooks/"*.sh 2>/dev/null || true
fi
if [[ -d "$TARGET_DIR/.claude/scripts" ]]; then
  chmod +x "$TARGET_DIR/.claude/scripts/"*.sh 2>/dev/null || true
fi

# ── .gitignore stub ───────────────────────────────────────────────────────────
GITIGNORE="$TARGET_DIR/.gitignore"
if [[ ! -f "$GITIGNORE" ]]; then
  cat > "$GITIGNORE" <<'GITEOF'
.venv/
__pycache__/
*.pyc
node_modules/
.claude/tasks/ledger.jsonl
.env
GITEOF
  success "Created .gitignore"
fi

# ── Done ──────────────────────────────────────────────────────────────────────
echo ""
echo -e "${GREEN}${BOLD}Done!${RESET} Project initialized at: $TARGET_DIR"
echo ""
echo "Next steps:"
echo "  1. Edit your source docs in $SOT_DIR"
echo "     (or use the ChatGPT workflow described in templates/README.md)"
echo "  2. Run the bootstrap script:"
echo "       python3 .claude/bin/bootstrap_three_docs.py --refresh"
echo "  3. Launch your AI runtime:"
if [[ "$RUNTIME" == "claude-code" || "$RUNTIME" == "both" ]]; then
  echo "       claude --agent main-orchestrator"
fi
if [[ "$RUNTIME" == "opencode" || "$RUNTIME" == "both" ]]; then
  echo "       opencode"
fi
echo ""
