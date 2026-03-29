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
DIM='\033[2m'
BOLD='\033[1m'
RESET='\033[0m'

TOTAL_STEPS=7

info()    { echo -e "${CYAN}${BOLD}==>${RESET} $*"; }
success() { echo -e "${GREEN}✓${RESET} $*"; }
warn()    { echo -e "${YELLOW}!${RESET} $*"; }
error()   { echo -e "${RED}ERROR:${RESET} $*" >&2; exit 1; }
prompt()  { echo -e "${BOLD}$*${RESET}"; }
step()    { echo ""; echo -e "${DIM}────────────────────────────────────────────${RESET}"; \
            echo -e "${CYAN}${BOLD}  Step $1 / ${TOTAL_STEPS}${RESET}  ${BOLD}$2${RESET}"; \
            echo ""; }

# ── Helpers ───────────────────────────────────────────────────────────────────
ask() {
  local question="$1" default="${2:-}" answer
  if [[ -n "$default" ]]; then
    read -rp "$(echo -e "${BOLD}${question}${RESET} [${default}]: ")" answer </dev/tty
    echo "${answer:-$default}"
  else
    read -rp "$(echo -e "${BOLD}${question}${RESET}: ")" answer </dev/tty
    echo "$answer"
  fi
}

ask_choice() {
  # ask_choice "question" "keyword|Description line" ...
  # Option format: "keyword|Description shown below the option"
  # If no pipe is present, the whole string is used as keyword with no description.
  # Returns just the keyword via stdout; all display goes to /dev/tty.
  local label="$1"; shift
  local options=("$@")
  local i answer keyword desc
  echo -e "${BOLD}${label}${RESET}" >/dev/tty
  echo "" >/dev/tty
  for i in "${!options[@]}"; do
    keyword="${options[$i]%%|*}"
    desc="${options[$i]#*|}"
    if [[ "$desc" == "$keyword" ]]; then
      echo -e "  ${CYAN}${BOLD}$((i+1)))${RESET} ${BOLD}${keyword}${RESET}" >/dev/tty
    else
      echo -e "  ${CYAN}${BOLD}$((i+1)))${RESET} ${BOLD}${keyword}${RESET}" >/dev/tty
      echo -e "     ${DIM}${desc}${RESET}" >/dev/tty
    fi
  done
  echo "" >/dev/tty
  while true; do
    read -rp "$(echo -e "${BOLD}Choice [1-${#options[@]}]:${RESET} ")" answer </dev/tty
    if [[ "$answer" =~ ^[0-9]+$ ]] && (( answer >= 1 && answer <= ${#options[@]} )); then
      keyword="${options[$((answer-1))]%%|*}"
      echo "$keyword"
      return
    fi
    warn "Please enter a number between 1 and ${#options[@]}." >/dev/tty
  done
}

ask_yn() {
  # ask_yn "question" [default: y|n]
  # Prints a Y/n or y/N prompt and returns "yes" or "no"
  local question="$1" default="${2:-y}" answer
  local hint
  if [[ "$default" == "y" ]]; then hint="Y/n"; else hint="y/N"; fi
  while true; do
    read -rp "$(echo -e "${BOLD}${question}${RESET} [${hint}]: ")" answer </dev/tty
    answer="${answer:-$default}"
    case "${answer,,}" in
      y|yes) echo "yes"; return ;;
      n|no)  echo "no";  return ;;
      *) warn "Please answer y or n." >/dev/tty ;;
    esac
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

# resolve_model <tier> <agent>
# Looks up tiers.json and echoes the correct model class (opus/sonnet/haiku)
# for the given tier + agent combination.
resolve_model() {
  local tier="$1" agent="$2"
  local tiers_json="$TEMPLATE_ROOT/shared/models/tiers.json"

  # Try override first, then default
  local override default
  override="$(python3 -c "
import json, sys
data = json.load(open('$tiers_json'))
tier = data['tiers'].get('$tier', {})
print(tier.get('overrides', {}).get('$agent', ''))
" 2>/dev/null)"

  if [[ -n "$override" ]]; then
    echo "$override"
    return
  fi

  default="$(python3 -c "
import json, sys
data = json.load(open('$tiers_json'))
print(data['tiers']['$tier']['default'])
" 2>/dev/null)"

  echo "${default:-sonnet}"
}

# resolve_model_id <runtime> <model_class>
# Echoes the full model ID for the given runtime (opencode|claude-code) and class.
resolve_model_id() {
  local runtime="$1" model_class="$2"
  local tiers_json="$TEMPLATE_ROOT/shared/models/tiers.json"
  python3 -c "
import json
data = json.load(open('$tiers_json'))
print(data['models']['$runtime']['$model_class'])
" 2>/dev/null
}

# stamp_agent_models <agents_dir> <runtime> <tier>
# Injects a 'model: <id>' line into the YAML frontmatter of each agent .md file.
# If a frontmatter block already has a model: line, it is replaced.
# If there is no frontmatter, one is created.
stamp_agent_models() {
  local agents_dir="$1" runtime="$2" tier="$3"
  local tiers_json="$TEMPLATE_ROOT/shared/models/tiers.json"

  [[ -d "$agents_dir" ]] || return 0

  local agent_file agent_name model_class model_id
  for agent_file in "$agents_dir"/*.md; do
    [[ -f "$agent_file" ]] || continue
    agent_name="$(basename "$agent_file" .md)"
    model_class="$(resolve_model "$tier" "$agent_name")"
    model_id="$(resolve_model_id "$runtime" "$model_class")"
    [[ -z "$model_id" ]] && continue

    # If file starts with ---, update or insert model: within frontmatter
    if head -1 "$agent_file" | grep -q '^---'; then
      # Has frontmatter — replace existing model: line or insert after first ---
      if grep -q '^model:' "$agent_file"; then
        sed -i "s|^model:.*|model: ${model_id}|" "$agent_file"
      else
        # Insert model: as first key after opening ---
        python3 -c "
import sys
lines = open('$agent_file').readlines()
out = []
inserted = False
for line in lines:
    out.append(line)
    if not inserted and line.strip() == '---':
        out.append('model: ${model_id}\n')
        inserted = True
open('$agent_file', 'w').writelines(out)
"
      fi
    else
      # No frontmatter — prepend one
      local tmp
      tmp="$(mktemp)"
      { printf -- '---\nmodel: %s\n---\n' "$model_id"; cat "$agent_file"; } > "$tmp"
      mv "$tmp" "$agent_file"
    fi
  done

  success "Stamped model IDs into $agents_dir (tier: ${tier})"
}

# generate_opencode_json <output_path> <mode> <tier>
# Writes opencode.json with the permission block for the specified mode
# and the trisystem_model_tier field.
generate_opencode_json() {
  local out="$1" mode="$2" tier="${3:-standard}"
  mkdir -p "$(dirname "$out")"

  case "$mode" in
    autonomous)
      cat > "$out" <<EOF
{
  "\$schema": "https://opencode.ai/config.json",
  "instructions": [
    ".opencode/rules/*.md"
  ],

  "trisystem_permission_mode": "autonomous",
  "trisystem_model_tier": "${tier}",

  "permission": {
    "*": "allow",
    "doom_loop": "ask"
  }
}
EOF
      ;;
    supervised)
      cat > "$out" <<EOF
{
  "\$schema": "https://opencode.ai/config.json",
  "instructions": [
    ".opencode/rules/*.md"
  ],

  "trisystem_permission_mode": "supervised",
  "trisystem_model_tier": "${tier}",

  "permission": {
    "*": "allow",
    "doom_loop": "ask",
    "bash": {
      "*": "allow",
      "rm -rf *": "ask",
      "git push *": "ask",
      "git push": "ask",
      "shutdown *": "deny",
      "reboot *": "deny",
      "mkfs *": "deny",
      "dd if=*": "deny"
    }
  }
}
EOF
      ;;
    guarded)
      cat > "$out" <<EOF
{
  "\$schema": "https://opencode.ai/config.json",
  "instructions": [
    ".opencode/rules/*.md"
  ],

  "trisystem_permission_mode": "guarded",
  "trisystem_model_tier": "${tier}",

  "permission": {
    "*": "ask",
    "read": "allow",
    "glob": "allow",
    "grep": "allow",
    "list": "allow",
    "webfetch": "allow",
    "doom_loop": "ask"
  }
}
EOF
      ;;
    locked)
      cat > "$out" <<EOF
{
  "\$schema": "https://opencode.ai/config.json",
  "instructions": [
    ".opencode/rules/*.md"
  ],

  "trisystem_permission_mode": "locked",
  "trisystem_model_tier": "${tier}",

  "permission": {
    "*": "deny",
    "read": "allow",
    "glob": "allow",
    "grep": "allow",
    "list": "allow",
    "webfetch": "allow",
    "task": "allow",
    "skill": "allow"
  }
}
EOF
      ;;
    *)
      warn "Unknown permission mode '$mode', defaulting to supervised."
      generate_opencode_json "$out" "supervised" "$tier"
      return
      ;;
  esac

  success "Generated opencode.json (mode: ${mode}, tier: ${tier})"
}

# ── Banner ────────────────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}Three-Doc Project Template — Init Wizard${RESET}"
echo "────────────────────────────────────────────"
echo ""

# ── Step 1: Target directory ──────────────────────────────────────────────────
step 1 "Target directory"
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

# ── Step 2: Project name ──────────────────────────────────────────────────────
step 2 "Project name"
PROJECT_NAME="$(ask "Project name (used as the template prefix)" "$(basename "$TARGET_DIR")")"
# Sanitize: uppercase letters, digits, underscores, hyphens only
PROJECT_PREFIX="$(echo "$PROJECT_NAME" | tr '[:lower:]' '[:upper:]' | tr -s ' ' '_' | tr -cd 'A-Z0-9_-')"
info "Document prefix: ${PROJECT_PREFIX}_"

# ── Step 3: Runtime ───────────────────────────────────────────────────────────
step 3 "AI coding runtime"
RUNTIME="$(ask_choice "Which runtime will you use?" \
  "opencode|Open-source AI coding CLI (opencode.ai). Configured via AGENTS.md + opencode.json." \
  "claude-code|Anthropic's Claude Code CLI. Configured via CLAUDE.md + .claude/settings.json." \
  "both|Sets up both runtimes with a shared agents, skills, and rules layer.")"

# ── Step 4: Template size ─────────────────────────────────────────────────────
step 4 "Source doc templates"
TEMPLATE_SIZE="$(ask_choice "Which template size?" \
  "slim|Recommended. Copies starter templates (~200 lines each) into docs/source-of-truth/. Edit them to describe your project." \
  "empty|Creates blank stub files only. Use the ChatGPT workflow in templates/README.md to generate content from scratch.")"

# ── Step 5: Permission mode ───────────────────────────────────────────────────
step 5 "Permission mode"
PERMISSION_MODE="$(ask_choice "Permission mode?" \
  "supervised|Recommended. Most ops run freely; git push and deploy commands require approval. Truly destructive commands are blocked." \
  "autonomous|Full autonomy including git push. Zero prompts. Best for trusted pipelines." \
  "guarded|Reads run freely; all writes, bash, and git commands require approval." \
  "locked|Read-only. No writes, no bash, no git. Analysis and planning mode only.")"

# ── Step 6: Model tier ────────────────────────────────────────────────────────
step 6 "Model cost tier"
MODEL_TIER="$(ask_choice "Model cost tier?" \
  "standard|Recommended. Opus for orchestration + architecture, sonnet for most tasks, haiku for simple agents. Best value." \
  "premium|Opus for all complex work, sonnet for medium tasks, haiku for simple. Best results, highest cost." \
  "economy|Haiku by default; sonnet for code-intensive agents; opus only for the orchestrator. Low cost, acceptable quality." \
  "minimal|Haiku everywhere except orchestrator (opus) and developer (sonnet). Lowest cost.")"

# ── Step 7: Cheatsheet ────────────────────────────────────────────────────────
step 7 "Cheat sheet"
echo -e "  ${DIM}A quick-reference card with common commands, slash commands, agent names,"
echo -e "  and workflow tips — tailored to your chosen runtime.${RESET}"
echo ""
INCLUDE_CHEATSHEET="$(ask_yn "Copy cheat sheet into project root?" "y")"

# ── Review loop ───────────────────────────────────────────────────────────────
show_summary() {
  echo ""
  echo -e "${DIM}────────────────────────────────────────────${RESET}"
  echo -e "${BOLD}  Review your choices${RESET}"
  echo -e "${DIM}────────────────────────────────────────────${RESET}"
  echo ""
  echo -e "  ${DIM}1. Target dir:     ${RESET}${CYAN}$TARGET_DIR${RESET}"
  echo -e "  ${DIM}2. Project name:   ${RESET}${CYAN}$PROJECT_NAME${RESET}  ${DIM}(prefix: ${PROJECT_PREFIX}_)${RESET}"
  echo -e "  ${DIM}3. Runtime:        ${RESET}${CYAN}$RUNTIME${RESET}"
  echo -e "  ${DIM}4. Template size:  ${RESET}${CYAN}$TEMPLATE_SIZE${RESET}"
  echo -e "  ${DIM}5. Permission mode:${RESET}${CYAN}$PERMISSION_MODE${RESET}"
  echo -e "  ${DIM}6. Model tier:     ${RESET}${CYAN}$MODEL_TIER${RESET}"
  echo -e "  ${DIM}7. Cheat sheet:    ${RESET}${CYAN}$INCLUDE_CHEATSHEET${RESET}"
  echo ""
}

while true; do
  show_summary
  read -rp "$(echo -e "${BOLD}[P]roceed  [E]dit  [Q]uit:${RESET} ")" review_choice
  case "${review_choice,,}" in
    p|proceed|"")
      break
      ;;
    q|quit|exit)
      warn "Aborted."
      exit 0
      ;;
    e|edit)
      echo ""
      echo -e "${BOLD}Which setting do you want to edit?${RESET}"
      echo ""
      echo -e "  ${CYAN}${BOLD}1)${RESET} ${BOLD}Target dir${RESET}      ${DIM}$TARGET_DIR${RESET}"
      echo -e "  ${CYAN}${BOLD}2)${RESET} ${BOLD}Project name${RESET}    ${DIM}$PROJECT_NAME${RESET}"
      echo -e "  ${CYAN}${BOLD}3)${RESET} ${BOLD}Runtime${RESET}         ${DIM}$RUNTIME${RESET}"
      echo -e "  ${CYAN}${BOLD}4)${RESET} ${BOLD}Template size${RESET}   ${DIM}$TEMPLATE_SIZE${RESET}"
      echo -e "  ${CYAN}${BOLD}5)${RESET} ${BOLD}Permission mode${RESET} ${DIM}$PERMISSION_MODE${RESET}"
      echo -e "  ${CYAN}${BOLD}6)${RESET} ${BOLD}Model tier${RESET}      ${DIM}$MODEL_TIER${RESET}"
      echo -e "  ${CYAN}${BOLD}7)${RESET} ${BOLD}Cheat sheet${RESET}     ${DIM}$INCLUDE_CHEATSHEET${RESET}"
      echo ""
      read -rp "$(echo -e "${BOLD}Edit [1-7]:${RESET} ")" edit_choice
      case "$edit_choice" in
        1)
          TARGET_DIR="$(ask "Target project directory" "$TARGET_DIR")"
          TARGET_DIR="$(realpath "$TARGET_DIR")"
          if [[ ! -d "$TARGET_DIR" ]]; then
            read -rp "$(echo -e "${BOLD}Directory '$TARGET_DIR' does not exist. Create it? [Y/n]:${RESET} ")" confirm
            if [[ "${confirm:-Y}" =~ ^[Yy]$ ]]; then
              mkdir -p "$TARGET_DIR"
              success "Created $TARGET_DIR"
            fi
          fi
          ;;
        2)
          PROJECT_NAME="$(ask "Project name" "$PROJECT_NAME")"
          PROJECT_PREFIX="$(echo "$PROJECT_NAME" | tr '[:lower:]' '[:upper:]' | tr -s ' ' '_' | tr -cd 'A-Z0-9_-')"
          info "Document prefix: ${PROJECT_PREFIX}_"
          ;;
        3)
          RUNTIME="$(ask_choice "Which runtime will you use?" \
            "opencode|Open-source AI coding CLI (opencode.ai). Configured via AGENTS.md + opencode.json." \
            "claude-code|Anthropic's Claude Code CLI. Configured via CLAUDE.md + .claude/settings.json." \
            "both|Sets up both runtimes with a shared agents, skills, and rules layer.")"
          ;;
        4)
          TEMPLATE_SIZE="$(ask_choice "Which template size?" \
            "slim|Recommended. Copies starter templates (~200 lines each) into docs/source-of-truth/. Edit them to describe your project." \
            "empty|Creates blank stub files only. Use the ChatGPT workflow in templates/README.md to generate content from scratch.")"
          ;;
        5)
          PERMISSION_MODE="$(ask_choice "Permission mode?" \
            "supervised|Recommended. Most ops run freely; git push and deploy commands require approval. Truly destructive commands are blocked." \
            "autonomous|Full autonomy including git push. Zero prompts. Best for trusted pipelines." \
            "guarded|Reads run freely; all writes, bash, and git commands require approval." \
            "locked|Read-only. No writes, no bash, no git. Analysis and planning mode only.")"
          ;;
        6)
          MODEL_TIER="$(ask_choice "Model cost tier?" \
            "standard|Recommended. Opus for orchestration + architecture, sonnet for most tasks, haiku for simple agents. Best value." \
            "premium|Opus for all complex work, sonnet for medium tasks, haiku for simple. Best results, highest cost." \
            "economy|Haiku by default; sonnet for code-intensive agents; opus only for the orchestrator. Low cost, acceptable quality." \
            "minimal|Haiku everywhere except orchestrator (opus) and developer (sonnet). Lowest cost.")"
          ;;
        7)
          echo -e "  ${DIM}A quick-reference card with common commands, slash commands, agent names,"
          echo -e "  and workflow tips — tailored to your chosen runtime.${RESET}"
          echo ""
          INCLUDE_CHEATSHEET="$(ask_yn "Copy cheat sheet into project root?" "y")"
          ;;
        *)
          warn "Please enter a number between 1 and 7."
          ;;
      esac
      ;;
    *)
      warn "Please enter P to proceed, E to edit, or Q to quit."
      ;;
  esac
done
echo ""

# ── Copy shared content ───────────────────────────────────────────────────────
info "Copying shared agents, skills, and rules..."

if [[ "$RUNTIME" == "claude-code" || "$RUNTIME" == "both" ]]; then
  copy_dir "$TEMPLATE_ROOT/shared/agents" "$TARGET_DIR/.claude/agents"
  copy_dir "$TEMPLATE_ROOT/shared/skills" "$TARGET_DIR/.claude/skills"
  copy_dir "$TEMPLATE_ROOT/shared/rules"  "$TARGET_DIR/.claude/rules"
  stamp_agent_models "$TARGET_DIR/.claude/agents" "claude-code" "$MODEL_TIER"
fi

if [[ "$RUNTIME" == "opencode" || "$RUNTIME" == "both" ]]; then
  copy_dir "$TEMPLATE_ROOT/shared/agents" "$TARGET_DIR/.opencode/agents"
  copy_dir "$TEMPLATE_ROOT/shared/skills" "$TARGET_DIR/.opencode/skills"
  copy_dir "$TEMPLATE_ROOT/shared/rules"  "$TARGET_DIR/.opencode/rules"
  stamp_agent_models "$TARGET_DIR/.opencode/agents" "opencode" "$MODEL_TIER"
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

  # AGENTS.md — substitute PROJECT_NAME and PERMISSION_MODE placeholders
  if [[ -f "$TEMPLATE_ROOT/opencode/AGENTS.md.template" ]]; then
    mkdir -p "$TARGET_DIR"
    sed \
      -e "s/{{PROJECT_NAME}}/${PROJECT_NAME}/g" \
      -e "s/{{PERMISSION_MODE}}/${PERMISSION_MODE}/g" \
      -e "s/{{MODEL_TIER}}/${MODEL_TIER}/g" \
      "$TEMPLATE_ROOT/opencode/AGENTS.md.template" \
      > "$TARGET_DIR/AGENTS.md"
    success "Generated AGENTS.md"
  fi

  # opencode.json — generate with correct permission block for the chosen mode
  if [[ ! -f "$TARGET_DIR/opencode.json" ]]; then
    generate_opencode_json "$TARGET_DIR/opencode.json" "$PERMISSION_MODE" "$MODEL_TIER"
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

if [[ "$TEMPLATE_SIZE" == "slim" ]]; then
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

# ── .gitignore ────────────────────────────────────────────────────────────────
GITIGNORE="$TARGET_DIR/.gitignore"

# Entries that must be present (pattern : comment-label)
declare -a GITIGNORE_REQUIRED=(
  ".venv/"
  "venv/"
  "env/"
  "__pycache__/"
  "*.pyc"
  "*.pyo"
  "node_modules/"
  ".claude/memory/"
  ".claude/tasks/"
  ".claude/*.json"
  ".claude/*.jsonl"
  ".mcp.json"
  ".env"
  ".DS_Store"
  "Thumbs.db"
)

if [[ ! -f "$GITIGNORE" ]]; then
  cat > "$GITIGNORE" <<'GITEOF'
# Python virtual environments
.venv/
venv/
env/

# Python cache
__pycache__/
*.pyc
*.pyo

# Node
node_modules/

# Agent runtime state (generated per-session — do not commit)
.claude/memory/
.claude/tasks/
.claude/*.json
.claude/*.jsonl
.mcp.json

# Environment secrets
.env

# OS
.DS_Store
Thumbs.db
GITEOF
  success "Created .gitignore"
else
  _appended=0
  for _entry in "${GITIGNORE_REQUIRED[@]}"; do
    # grep with fixed-string and full-line match so globs don't confuse it
    if ! grep -qF "$_entry" "$GITIGNORE" 2>/dev/null; then
      if [[ $_appended -eq 0 ]]; then
        printf '\n# Agent runtime state (generated per-session — do not commit)\n' >> "$GITIGNORE"
        _appended=1
      fi
      printf '%s\n' "$_entry" >> "$GITIGNORE"
    fi
  done
  if [[ $_appended -gt 0 ]]; then
    success "Updated .gitignore with missing agent ignore rules"
  fi
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
