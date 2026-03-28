#!/usr/bin/env python3
"""
common.py — Shared utilities for the three-doc bootstrap and hook scripts.

This module provides:
- Path resolution (project root, .claude/ subdirectories)
- File I/O helpers (read/write JSON, text, JSONL)
- Source document discovery
- Markdown parsing (headings, checkbox items, phase headings)
- Registry and runtime state management
- Task lifecycle helpers
"""

from __future__ import annotations

import datetime as _dt
import fnmatch
import hashlib
import json
import os
import re
import subprocess
from pathlib import Path
from typing import Any, Iterable

EXCLUDED_SCAN_DIRS = {
    ".git",
    ".claude",
    ".venv",
    "venv",
    "node_modules",
    "__pycache__",
    "dist",
    "build",
    "target",
    ".next",
    ".nuxt",
    ".idea",
    ".vscode",
}

PHASE_RE = re.compile(
    r"(?i)\b(?:phase|fase)\b(?:\s+([0-9]+(?:\.[0-9]+)*))?\s*[-—:]*\s*(.*)"
)
CHECKBOX_RE = re.compile(r"^\s*(?:[-*+]|\d+\.)\s*\[(?: |x|X)\]\s+(.*\S)\s*$")
BULLET_RE = re.compile(r"^\s*(?:[-*+]|\d+\.)\s+(.*\S)\s*$")
CANONICAL_SOURCE_DOCS_DIR = Path("docs/source-of-truth")


def project_root() -> Path:
    env = os.environ.get("CLAUDE_PROJECT_DIR")
    if env:
        return Path(env).resolve()
    return Path(__file__).resolve().parents[2]


def claude_dir() -> Path:
    return project_root() / ".claude"


def memory_dir() -> Path:
    return claude_dir() / "memory"


def tasks_dir() -> Path:
    return claude_dir() / "tasks"


def canonical_source_docs_dir(root: Path | None = None) -> Path:
    root = root or project_root()
    return root / CANONICAL_SOURCE_DOCS_DIR


def registry_path() -> Path:
    return tasks_dir() / "registry.json"


def runtime_state_path() -> Path:
    return tasks_dir() / "runtime-state.json"


def ledger_path() -> Path:
    return tasks_dir() / "ledger.jsonl"


def active_phase_json_path() -> Path:
    return memory_dir() / "active-phase.json"


def active_task_json_path() -> Path:
    return memory_dir() / "active-task.json"


def ensure_parent(path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)


def read_text(path: Path, default: str = "") -> str:
    try:
        return path.read_text(encoding="utf-8")
    except FileNotFoundError:
        return default


def write_text(path: Path, content: str) -> None:
    ensure_parent(path)
    path.write_text(content, encoding="utf-8")


def read_json(path: Path, default: Any) -> Any:
    try:
        with path.open("r", encoding="utf-8") as f:
            return json.load(f)
    except Exception:
        return default


def write_json(path: Path, data: Any) -> None:
    ensure_parent(path)
    with path.open("w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=2)
        f.write("\n")


def append_jsonl(path: Path, record: dict[str, Any]) -> None:
    ensure_parent(path)
    with path.open("a", encoding="utf-8") as f:
        f.write(json.dumps(record, ensure_ascii=False) + "\n")


def now_iso() -> str:
    return _dt.datetime.now(_dt.timezone.utc).replace(microsecond=0).isoformat()


def slugify(value: str) -> str:
    value = value.strip().lower()
    value = re.sub(r"[^a-z0-9]+", "-", value)
    return value.strip("-") or "item"


def relpath(path: Path) -> str:
    try:
        return path.resolve().relative_to(project_root()).as_posix()
    except Exception:
        return path.as_posix()


def sha256_file(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(65536), b""):
            h.update(chunk)
    return h.hexdigest()


def discover_markdown_files(root: Path | None = None) -> list[Path]:
    root = root or project_root()
    found: list[Path] = []
    for dirpath, dirnames, filenames in os.walk(root):
        dirnames[:] = [
            d
            for d in dirnames
            if d not in EXCLUDED_SCAN_DIRS and not d.startswith(".cache")
        ]
        for name in filenames:
            if name.lower().endswith(".md"):
                found.append(Path(dirpath) / name)
    return sorted(found)


def scan_source_doc_candidates(root: Path) -> dict[str, list[Path]]:
    files = discover_markdown_files(root)
    instructions = [p for p in files if p.name == "instrucciones.md"]
    checklist = [p for p in files if p.name.endswith("_IMPLEMENTATION_CHECKLIST.md")]
    guide = [p for p in files if p.name.endswith("_TECHNICAL_GUIDE.md")]
    return {"instructions": instructions, "checklist": checklist, "guide": guide}


def docs_are_in_canonical_dir(
    doc_paths: dict[str, list[Path]], root: Path | None = None
) -> bool:
    root = root or project_root()
    canonical = canonical_source_docs_dir(root).resolve()
    chosen = [
        paths[0]
        for key, paths in doc_paths.items()
        if key in {"instructions", "checklist", "guide"} and len(paths) == 1
    ]
    if not chosen:
        return False
    return all(
        canonical == p.resolve().parent or canonical in p.resolve().parents
        for p in chosen
    )


def discover_source_docs(root: Path | None = None) -> dict[str, Any]:
    root = root or project_root()
    canonical_dir = canonical_source_docs_dir(root)
    if canonical_dir.exists():
        canonical = scan_source_doc_candidates(canonical_dir)
        if sum(len(paths) for paths in canonical.values()) > 0:
            return canonical
    return scan_source_doc_candidates(root)


def extract_headings(text: str) -> list[dict[str, Any]]:
    headings: list[dict[str, Any]] = []
    for idx, line in enumerate(text.splitlines(), start=1):
        if line.startswith("#"):
            m = re.match(r"^(#{1,6})\s+(.*\S)\s*$", line)
            if m:
                headings.append(
                    {"level": len(m.group(1)), "title": m.group(2), "line": idx}
                )
    return headings


def extract_items(lines: list[str]) -> list[str]:
    items: list[str] = []
    for line in lines:
        m = CHECKBOX_RE.match(line)
        if m:
            items.append(m.group(1).strip())
    if items:
        return items
    for line in lines:
        m = BULLET_RE.match(line)
        if m:
            items.append(m.group(1).strip())
    return items


def phase_headings(headings: list[dict[str, Any]]) -> list[dict[str, Any]]:
    return [h for h in headings if PHASE_RE.search(h["title"])]


def path_matches_patterns(path: Path | str, patterns: Iterable[str]) -> bool:
    path_str = relpath(Path(path)) if not isinstance(path, str) else path
    path_str = path_str.lstrip("./")
    pattern_list = list(patterns)
    if not pattern_list:
        return True
    for raw in pattern_list:
        pattern = raw.lstrip("./")
        if fnmatch.fnmatch(path_str, pattern):
            return True
    return False


def load_registry() -> dict[str, Any]:
    return read_json(
        registry_path(),
        {
            "generated_at": None,
            "project_prefix": None,
            "phase_order": [],
            "phases": [],
            "tasks": [],
        },
    )


def save_registry(data: dict[str, Any]) -> None:
    write_json(registry_path(), data)


def load_runtime_state() -> dict[str, Any]:
    return read_json(
        runtime_state_path(),
        {
            "generated_at": None,
            "active_phase_id": None,
            "active_task_id": None,
            "last_worker": None,
            "last_event": None,
        },
    )


def save_runtime_state(data: dict[str, Any]) -> None:
    write_json(runtime_state_path(), data)


def load_active_task() -> dict[str, Any]:
    return read_json(
        active_task_json_path(),
        {
            "id": None,
            "title": None,
            "status": "not_initialized",
            "allowed_paths": [],
            "verification_commands": [],
        },
    )


def save_active_task(data: dict[str, Any]) -> None:
    write_json(active_task_json_path(), data)
    md = [
        "# Active task",
        "",
        f"- ID: {data.get('id')}",
        f"- Title: {data.get('title')}",
        f"- Status: {data.get('status')}",
        f"- Phase: {data.get('phase_id')}",
        "",
        "## Acceptance",
    ]
    for item in data.get("acceptance", []):
        md.append(f"- {item}")
    md.extend(["", "## Allowed paths"])
    for item in data.get("allowed_paths", []):
        md.append(f"- {item}")
    md.extend(["", "## Verification commands"])
    for item in data.get("verification_commands", []):
        md.append(f"- `{item}`")
    write_text(memory_dir() / "active-task.md", "\n".join(md) + "\n")


def save_active_phase(data: dict[str, Any]) -> None:
    write_json(active_phase_json_path(), data)
    md = [
        "# Active phase",
        "",
        f"- ID: {data.get('id')}",
        f"- Title: {data.get('title')}",
        f"- Status: {data.get('status')}",
        "",
        "## Tasks",
    ]
    for item in data.get("task_ids", []):
        md.append(f"- {item}")
    write_text(memory_dir() / "active-phase.md", "\n".join(md) + "\n")


def find_task(registry: dict[str, Any], task_id: str | None) -> dict[str, Any] | None:
    if not task_id:
        return None
    for task in registry.get("tasks", []):
        if task.get("id") == task_id:
            return task
    return None


def find_phase(registry: dict[str, Any], phase_id: str | None) -> dict[str, Any] | None:
    if not phase_id:
        return None
    for phase in registry.get("phases", []):
        if phase.get("id") == phase_id:
            return phase
    return None


def tasks_by_phase(registry: dict[str, Any], phase_id: str) -> list[dict[str, Any]]:
    return [t for t in registry.get("tasks", []) if t.get("phase_id") == phase_id]


def task_is_ready(registry: dict[str, Any], task: dict[str, Any]) -> bool:
    deps = task.get("depends_on", [])
    done_ids = {t["id"] for t in registry.get("tasks", []) if t.get("status") == "done"}
    return all(dep in done_ids for dep in deps)


def refresh_phase_statuses(registry: dict[str, Any]) -> dict[str, Any]:
    for phase in registry.get("phases", []):
        phase_tasks = tasks_by_phase(registry, phase["id"])
        statuses = {t.get("status") for t in phase_tasks}
        if phase_tasks and all(t.get("status") == "done" for t in phase_tasks):
            phase["status"] = "complete"
        elif (
            "in_progress" in statuses
            or "review_pending" in statuses
            or "test_pending" in statuses
            or "qa_pending" in statuses
            or "needs_debug" in statuses
        ):
            phase["status"] = "active"
        elif any(
            task_is_ready(registry, t)
            and t.get("status") in {"planned", "blocked", "ready"}
            for t in phase_tasks
        ):
            phase["status"] = "ready"
        elif phase_tasks:
            phase["status"] = "blocked"
        else:
            phase["status"] = "empty"
    return registry


def promote_ready_tasks(registry: dict[str, Any]) -> dict[str, Any]:
    done_ids = {t["id"] for t in registry.get("tasks", []) if t.get("status") == "done"}
    for task in registry.get("tasks", []):
        if task.get("status") in {"planned", "blocked", "ready"}:
            if all(dep in done_ids for dep in task.get("depends_on", [])):
                task["status"] = "ready"
    return refresh_phase_statuses(registry)


def choose_next_active_task(
    registry: dict[str, Any],
) -> tuple[dict[str, Any] | None, dict[str, Any] | None]:
    registry = promote_ready_tasks(registry)
    phase_order = registry.get("phase_order", [])
    phases = {p["id"]: p for p in registry.get("phases", [])}
    for phase_id in phase_order:
        phase = phases.get(phase_id)
        if not phase:
            continue
        phase_tasks = tasks_by_phase(registry, phase_id)
        if all(t.get("status") == "done" for t in phase_tasks) and phase_tasks:
            continue
        for task in phase_tasks:
            if task.get("status") == "ready":
                return phase, task
        for task in phase_tasks:
            if task.get("status") in {
                "claimed",
                "in_progress",
                "review_pending",
                "test_pending",
                "qa_pending",
                "needs_debug",
                "blocked",
            }:
                return phase, task
    return None, None


def sync_active_state_from_registry(registry: dict[str, Any]) -> None:
    phase, task = choose_next_active_task(registry)
    if phase:
        save_active_phase(phase)
    else:
        save_active_phase(
            {"id": None, "title": None, "status": "complete", "task_ids": []}
        )
    if task:
        save_active_task(task)
    else:
        save_active_task(
            {
                "id": None,
                "title": None,
                "status": "complete",
                "allowed_paths": [],
                "verification_commands": [],
            }
        )
    state = load_runtime_state()
    state["generated_at"] = now_iso()
    state["active_phase_id"] = phase.get("id") if phase else None
    state["active_task_id"] = task.get("id") if task else None
    save_runtime_state(state)


def update_task_status(
    task_id: str, status: str, agent: str | None = None, note: str | None = None
) -> None:
    registry = load_registry()
    task = find_task(registry, task_id)
    if not task:
        return
    task["status"] = status
    if agent:
        task["last_updated_by"] = agent
    if note:
        task["last_note"] = note
    save_registry(promote_ready_tasks(registry))
    sync_active_state_from_registry(load_registry())


def run_commands(
    commands: list[str], cwd: Path | None = None, timeout: int = 900
) -> list[dict[str, Any]]:
    cwd = cwd or project_root()
    results: list[dict[str, Any]] = []
    for cmd in commands:
        proc = subprocess.run(
            cmd,
            cwd=str(cwd),
            shell=True,
            text=True,
            capture_output=True,
            timeout=timeout,
        )
        results.append(
            {
                "command": cmd,
                "returncode": proc.returncode,
                "stdout": proc.stdout,
                "stderr": proc.stderr,
            }
        )
    return results
