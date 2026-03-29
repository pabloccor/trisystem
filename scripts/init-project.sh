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
echo -e "${CYAN}${BOLD}Runtimes:${RESET}"
echo "  opencode    — Open-source AI coding CLI (opencode.ai). Uses AGENTS.md"
echo "                and opencode.json for configuration."
echo "  claude-code — Anthropic's Claude Code CLI. Uses CLAUDE.md and"
echo "                .claude/settings.json for configuration."
echo "  both        — Sets up both runtimes with a shared agent, skills, and"
echo "                rules layer. Good if your team uses different tools."
echo ""
RUNTIME="$(ask_choice "Which runtime will you use?" \
  "opencode    (open-source CLI — AGENTS.md + opencode.json)" \
  "claude-code (Anthropic's CLI — CLAUDE.md + settings.json)" \
  "both        (shared agents/skills/rules for both runtimes)")"
# Extract just the runtime keyword (first word)
RUNTIME="$(echo "$RUNTIME" | awk '{print $1}')"

# ── Step 4: Template size ─────────────────────────────────────────────────────
step 4 "Source doc templates"
echo -e "${CYAN}${BOLD}Template sizes:${RESET}"
echo "  slim  — Copies starter templates (~200 lines each) into docs/source-of-truth/."
echo "          Edit them directly to describe your project."
echo "  empty — Creates blank stub files only. Use the ChatGPT workflow in"
echo "          templates/README.md to generate the content from scratch."
echo ""
TEMPLATE_SIZE="$(ask_choice "Which template size?" \
  "slim   (recommended — starter structure, ~200 lines each)" \
  "empty  (blank stubs — generate content with ChatGPT)")"
# Extract just the size keyword (first word)
TEMPLATE_SIZE="$(echo "$TEMPLATE_SIZE" | awk '{print $1}')"

# ── Step 5: Permission mode ───────────────────────────────────────────────────
step 5 "Permission mode"
echo -e "${CYAN}${BOLD}Permission modes:${RESET}"
echo "  autonomous  — Full autonomy including git push. Zero prompts. Best for"
echo "                trusted pipelines where you want the agent to ship on its own."
echo "  supervised  — (Recommended) Most ops run freely; git push and deployment"
echo "                commands require approval. Truly destructive cmds blocked."
echo "  guarded     — Reads run freely; all writes, bash, and git require approval."
echo "  locked      — Read-only. No writes, no bash, no git. Analysis mode only."
echo ""
PERMISSION_MODE="$(ask_choice "Permission mode?" \
  "supervised  (recommended — autonomous except git push + deploys)" \
  "autonomous  (fully autonomous including git push)" \
  "guarded     (approve every write and bash command)" \
  "locked      (read-only, no changes)")"
# Extract just the mode keyword (first word)
PERMISSION_MODE="$(echo "$PERMISSION_MODE" | awk '{print $1}')"

# ── Step 6: Model tier ────────────────────────────────────────────────────────
step 6 "Model cost tier"
echo -e "${CYAN}${BOLD}Model cost tiers:${RESET}"
echo "  premium   — Opus for all complex work, sonnet for medium, haiku for simple."
echo "              Best results, highest API cost."
echo "  standard  — (Recommended) Opus for orchestration + architecture, sonnet for"
echo "              most tasks, haiku for low-demand agents. Best value."
echo "  economy   — Haiku by default; sonnet for code-intensive agents; opus only"
echo "              for the orchestrator. Low cost with acceptable quality."
echo "  minimal   — Haiku everywhere except orchestrator (opus) and developer (sonnet)."
echo "              Lowest cost."
echo ""
MODEL_TIER="$(ask_choice "Model cost tier?" \
  "standard  (recommended — opus orchestration, sonnet for most, haiku for simple)" \
  "premium   (opus for all complex work)" \
  "economy   (haiku default, sonnet for code-intensive)" \
  "minimal   (haiku everywhere except orchestrator + developer)")"
# Extract just the tier keyword (first word)
MODEL_TIER="$(echo "$MODEL_TIER" | awk '{print $1}')"

# ── Step 7: Cheatsheet ────────────────────────────────────────────────────────
step 7 "Cheat sheet"
echo -e "${CYAN}${BOLD}Cheat sheet:${RESET}"
echo "  A quick-reference card covering common commands, slash commands, agent"
echo "  names, and workflow tips — tailored to your chosen runtime."
echo ""
INCLUDE_CHEATSHEET="$(ask_choice "Copy cheat sheet into project root?" \
  "yes  (copy quick-reference card — handy while getting started)" \
  "no   (skip it)")"
# Extract just the keyword (first word)
INCLUDE_CHEATSHEET="$(echo "$INCLUDE_CHEATSHEET" | awk '{print $1}')"

# ── Confirm ───────────────────────────────────────────────────────────────────
echo ""
echo -e "${DIM}────────────────────────────────────────────${RESET}"
echo -e "${BOLD}  Review your choices${RESET}"
echo -e "${DIM}────────────────────────────────────────────${RESET}"
echo ""
echo -e "  Target:          ${CYAN}$TARGET_DIR${RESET}"
echo -e "  Project name:    ${CYAN}$PROJECT_NAME${RESET}  ${DIM}(prefix: ${PROJECT_PREFIX}_)${RESET}"
echo -e "  Runtime:         ${CYAN}$RUNTIME${RESET}"
echo -e "  Template size:   ${CYAN}$TEMPLATE_SIZE${RESET}"
echo -e "  Permission mode: ${CYAN}$PERMISSION_MODE${RESET}"
echo -e "  Model tier:      ${CYAN}$MODEL_TIER${RESET}"
echo -e "  Cheat sheet:     ${CYAN}$INCLUDE_CHEATSHEET${RESET}"
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
