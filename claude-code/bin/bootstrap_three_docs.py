#!/usr/bin/env python3
"""
bootstrap_three_docs.py — Generate runtime artifacts from the three source-of-truth docs.

Usage:
    python3 .claude/bin/bootstrap_three_docs.py --refresh
    python3 .claude/bin/bootstrap_three_docs.py --validate-only
    python3 .claude/bin/bootstrap_three_docs.py --refresh --json

The three source documents must exist (canonically in docs/source-of-truth/):
    - instrucciones.md
    - *_IMPLEMENTATION_CHECKLIST.md
    - *_TECHNICAL_GUIDE.md

Generated artifacts go under .claude/memory/ and .claude/tasks/.
"""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path
from typing import Any

from common import (
    PHASE_RE,
    append_jsonl,
    claude_dir,
    canonical_source_docs_dir,
    discover_source_docs,
    docs_are_in_canonical_dir,
    ensure_parent,
    extract_headings,
    extract_items,
    memory_dir,
    now_iso,
    phase_headings,
    project_root,
    read_text,
    relpath,
    save_active_phase,
    save_active_task,
    save_registry,
    save_runtime_state,
    sha256_file,
    slugify,
    tasks_dir,
    write_json,
    write_text,
)

PHASE_KEYWORD_RE = re.compile(r"(?i)\b(?:phase|fase)\b")
CONSTRAINT_RE = re.compile(
    r"(?i)\b(?:must|must not|should|required|constraint|invariant|never|"
    r"prohibited|shall|shall not)\b"
)


def validate_docs(doc_paths: dict[str, list[Path]]) -> dict[str, Any]:
    errors: list[str] = []
    warnings: list[str] = []

    for key in ("instructions", "checklist", "guide"):
        if len(doc_paths[key]) != 1:
            errors.append(
                f"Expected exactly one {key} document, found {len(doc_paths[key])}."
            )
    if errors:
        return {"errors": errors, "warnings": warnings}

    instructions = doc_paths["instructions"][0]
    checklist = doc_paths["checklist"][0]
    guide = doc_paths["guide"][0]

    if checklist.stem.replace("_IMPLEMENTATION_CHECKLIST", "") != guide.stem.replace(
        "_TECHNICAL_GUIDE", ""
    ):
        errors.append("Checklist and technical guide do not share the same prefix.")

    instructions_text = read_text(instructions)
    checklist_text = read_text(checklist)
    guide_text = read_text(guide)

    if len(extract_headings(instructions_text)) < 1:
        errors.append("instrucciones.md has no markdown headings.")
    if len(extract_headings(guide_text)) < 2:
        errors.append("Technical guide has too few markdown headings (need >= 2).")

    checklist_headings = extract_headings(checklist_text)
    if len(checklist_headings) < 2:
        errors.append(
            "Implementation checklist has too few markdown headings (need >= 2)."
        )

    phase_count = len(phase_headings(checklist_headings))
    if phase_count < 1:
        errors.append("Implementation checklist does not contain phase headings.")
    if phase_count < 2:
        warnings.append("Only one phase detected in the implementation checklist.")
    if len(instructions_text.strip()) < 200:
        warnings.append("instrucciones.md is unusually short (< 200 chars).")
    if len(guide_text.strip()) < 500:
        warnings.append("Technical guide is unusually short (< 500 chars).")
    if len(checklist_text.strip()) < 300:
        warnings.append("Implementation checklist is unusually short (< 300 chars).")
    if not docs_are_in_canonical_dir(doc_paths):
        warnings.append(
            "Legacy source-doc location detected. "
            "Recommended canonical location: docs/source-of-truth/."
        )
    return {"errors": errors, "warnings": warnings}


def extract_sections(
    text: str, headings: list[dict[str, Any]], phase_heading: dict[str, Any]
) -> tuple[list[str], list[dict[str, Any]], int | None]:
    lines = text.splitlines()
    end_line = None
    for h in headings:
        if (
            h["line"] > phase_heading["line"]
            and h["level"] <= phase_heading["level"]
            and PHASE_KEYWORD_RE.search(h["title"])
        ):
            end_line = h["line"]
            break
    section_lines = lines[
        phase_heading["line"] - 1 : end_line - 1 if end_line else len(lines)
    ]
    child_headings = [
        h
        for h in headings
        if h["line"] > phase_heading["line"]
        and (end_line is None or h["line"] < end_line)
        and h["level"] > phase_heading["level"]
    ]
    return section_lines, child_headings, end_line


def build_phases_and_tasks(
    checklist_path: Path, checklist_text: str
) -> tuple[list[dict[str, Any]], list[dict[str, Any]]]:
    headings = extract_headings(checklist_text)
    phases_raw = phase_headings(headings)
    phases: list[dict[str, Any]] = []
    tasks: list[dict[str, Any]] = []
    previous_phase_last_task_id = None

    for p_idx, phase_heading in enumerate(phases_raw, start=1):
        section_lines, child_headings, end_line = extract_sections(
            checklist_text, headings, phase_heading
        )
        m = PHASE_RE.search(phase_heading["title"])
        phase_number = m.group(1) if m and m.group(1) else str(p_idx)
        phase_title_suffix = (
            m.group(2) if m else phase_heading["title"]
        ).strip() or phase_heading["title"]
        phase_id = f"P{p_idx:02d}"
        phase = {
            "id": phase_id,
            "phase_number": phase_number,
            "title": phase_title_suffix,
            "status": "ready" if p_idx == 1 else "blocked",
            "depends_on": [] if p_idx == 1 else [phases[-1]["id"]],
            "source_ref": f"{relpath(checklist_path)}#{phase_heading['title']}",
            "task_ids": [],
        }

        step_headings = [
            h
            for h in child_headings
            if h["level"]
            == min(
                (x["level"] for x in child_headings),
                default=phase_heading["level"] + 1,
            )
        ]
        if not step_headings:
            step_headings = [
                {
                    "level": phase_heading["level"] + 1,
                    "title": phase_title_suffix,
                    "line": phase_heading["line"] + 1,
                }
            ]

        phase_line_end = end_line if end_line else len(checklist_text.splitlines()) + 1
        last_task_id = previous_phase_last_task_id

        for s_idx, step in enumerate(step_headings, start=1):
            next_step_line = None
            for other in step_headings:
                if other["line"] > step["line"]:
                    next_step_line = other["line"]
                    break
            slice_start = step["line"] - 1
            slice_end = (next_step_line - 1) if next_step_line else (phase_line_end - 1)
            step_lines = checklist_text.splitlines()[slice_start:slice_end]
            items = extract_items(step_lines)
            if not items:
                items = [step["title"]]

            # If a step expands to a very long flat list, keep it as one task
            # and store the list as acceptance criteria instead of flooding the queue.
            if len(items) > 12:
                items = [step["title"]]
                grouped_acceptance = extract_items(step_lines)
            else:
                grouped_acceptance = None

            for t_idx, item in enumerate(items, start=1):
                task_id = f"{phase_id}-S{s_idx:02d}-T{t_idx:03d}"
                task = {
                    "id": task_id,
                    "phase_id": phase_id,
                    "step_id": f"{phase_id}-S{s_idx:02d}",
                    "title": item,
                    "status": (
                        "ready"
                        if not last_task_id and p_idx == 1 and s_idx == 1 and t_idx == 1
                        else "blocked"
                    ),
                    "depends_on": [last_task_id] if last_task_id else [],
                    "source_ref": f"{relpath(checklist_path)}#{step['title']}",
                    "acceptance": grouped_acceptance if grouped_acceptance else [item],
                    "verification_commands": [],
                    "allowed_paths": [],
                    "handoff_path": f".claude/tasks/handoffs/{task_id}.md",
                    "evidence_dir": f".claude/tasks/evidence/{task_id}",
                    "notes": [],
                }
                tasks.append(task)
                phase["task_ids"].append(task_id)
                last_task_id = task_id

        previous_phase_last_task_id = last_task_id
        phases.append(phase)

    return phases, tasks


def build_project_brief(
    instructions_path: Path,
    checklist_path: Path,
    guide_path: Path,
    instructions_text: str,
    validation: dict[str, Any],
) -> str:
    headings = extract_headings(instructions_text)[:20]
    lines = [
        "# Project brief",
        "",
        f"- Generated at: {now_iso()}",
        f"- Canonical source-of-truth dir: `{relpath(canonical_source_docs_dir())}`",
        f"- Discovery mode: {'canonical' if docs_are_in_canonical_dir({'instructions': [instructions_path], 'checklist': [checklist_path], 'guide': [guide_path]}) else 'legacy'}",
        f"- Instructions: `{relpath(instructions_path)}`",
        f"- Checklist: `{relpath(checklist_path)}`",
        f"- Technical guide: `{relpath(guide_path)}`",
        "",
        "## Top-level headings from instrucciones.md",
    ]
    for h in headings:
        lines.append(f"- H{h['level']}: {h['title']}")
    lines.extend(["", "## Validation summary"])
    if validation["errors"]:
        lines.extend([f"- ERROR: {e}" for e in validation["errors"]])
    else:
        lines.append("- No blocking validation errors detected.")
    if validation["warnings"]:
        lines.extend([f"- WARNING: {w}" for w in validation["warnings"]])
    return "\n".join(lines) + "\n"


def build_architecture_contract(guide_path: Path, guide_text: str) -> str:
    headings = extract_headings(guide_text)[:40]
    constraint_lines: list[str] = []
    for line in guide_text.splitlines():
        if CONSTRAINT_RE.search(line.strip()):
            cleaned = line.strip()
            if cleaned and len(cleaned) < 240:
                constraint_lines.append(cleaned)
        if len(constraint_lines) >= 30:
            break

    lines = [
        "# Architecture contract",
        "",
        f"- Generated at: {now_iso()}",
        f"- Source: `{relpath(guide_path)}`",
        "",
        "## Structural headings",
    ]
    for h in headings:
        lines.append(f"- H{h['level']}: {h['title']}")
    lines.extend(["", "## Constraint and invariant signals"])
    if constraint_lines:
        for line in constraint_lines:
            lines.append(f"- {line}")
    else:
        lines.append(
            "- No explicit constraint signal lines were extracted automatically."
        )
    lines.extend(
        [
            "",
            "## Operating note",
            "This file is derived. Use it as an execution contract, but reconcile "
            "against the raw guide when ambiguity matters.",
        ]
    )
    return "\n".join(lines) + "\n"


def build_manifest(
    instructions_path: Path,
    checklist_path: Path,
    guide_path: Path,
    validation: dict[str, Any],
) -> dict[str, Any]:
    prefix = checklist_path.stem.replace("_IMPLEMENTATION_CHECKLIST", "")
    return {
        "generated_at": now_iso(),
        "project_root": relpath(project_root()),
        "project_prefix": prefix,
        "source_of_truth": {
            "canonical_dir": relpath(canonical_source_docs_dir()),
            "discovery_mode": (
                "canonical"
                if docs_are_in_canonical_dir(
                    {
                        "instructions": [instructions_path],
                        "checklist": [checklist_path],
                        "guide": [guide_path],
                    }
                )
                else "legacy"
            ),
        },
        "documents": {
            "instructions": {
                "path": relpath(instructions_path),
                "sha256": sha256_file(instructions_path),
            },
            "checklist": {
                "path": relpath(checklist_path),
                "sha256": sha256_file(checklist_path),
            },
            "guide": {
                "path": relpath(guide_path),
                "sha256": sha256_file(guide_path),
            },
        },
        "validation": validation,
    }


def write_phase_yaml(path: Path, phase: dict[str, Any]) -> None:
    lines = [
        f"id: {phase['id']}",
        f"title: {json.dumps(phase['title'], ensure_ascii=False)}",
        f"status: {phase['status']}",
        "depends_on:",
    ]
    for dep in phase.get("depends_on", []):
        lines.append(f"  - {dep}")
    lines.append("task_ids:")
    for tid in phase.get("task_ids", []):
        lines.append(f"  - {tid}")
    lines.append(f"source_ref: {json.dumps(phase['source_ref'], ensure_ascii=False)}")
    write_text(path, "\n".join(lines) + "\n")


def write_task_yaml(path: Path, task: dict[str, Any]) -> None:
    lines = [
        f"id: {task['id']}",
        f"phase_id: {task['phase_id']}",
        f"step_id: {task['step_id']}",
        f"title: {json.dumps(task['title'], ensure_ascii=False)}",
        f"status: {task['status']}",
        "depends_on:",
    ]
    for dep in task.get("depends_on", []):
        lines.append(f"  - {dep}")
    lines.append("acceptance:")
    for item in task.get("acceptance", []):
        lines.append(f"  - {json.dumps(item, ensure_ascii=False)}")
    lines.append("verification_commands:")
    for item in task.get("verification_commands", []):
        lines.append(f"  - {json.dumps(item, ensure_ascii=False)}")
    lines.append("allowed_paths:")
    for item in task.get("allowed_paths", []):
        lines.append(f"  - {json.dumps(item, ensure_ascii=False)}")
    lines.append(f"handoff_path: {task['handoff_path']}")
    lines.append(f"evidence_dir: {task['evidence_dir']}")
    lines.append(f"source_ref: {json.dumps(task['source_ref'], ensure_ascii=False)}")
    write_text(path, "\n".join(lines) + "\n")


def generate_artifacts() -> dict[str, Any]:
    docs = discover_source_docs(project_root())
    validation = validate_docs(docs)
    if validation["errors"]:
        return {"ok": False, "validation": validation, "docs": docs}

    instructions_path = docs["instructions"][0]
    checklist_path = docs["checklist"][0]
    guide_path = docs["guide"][0]
    instructions_text = read_text(instructions_path)
    checklist_text = read_text(checklist_path)
    guide_text = read_text(guide_path)

    manifest = build_manifest(instructions_path, checklist_path, guide_path, validation)
    phases, tasks = build_phases_and_tasks(checklist_path, checklist_text)

    mem = memory_dir()
    tasks_root = tasks_dir()
    mem.mkdir(parents=True, exist_ok=True)
    tasks_root.mkdir(parents=True, exist_ok=True)
    (tasks_root / "phases").mkdir(parents=True, exist_ok=True)
    (tasks_root / "work-items").mkdir(parents=True, exist_ok=True)
    (tasks_root / "handoffs").mkdir(parents=True, exist_ok=True)
    (tasks_root / "evidence").mkdir(parents=True, exist_ok=True)
    (tasks_root / "reports").mkdir(parents=True, exist_ok=True)

    write_json(mem / "source-manifest.json", manifest)
    write_text(
        mem / "project-brief.md",
        build_project_brief(
            instructions_path, checklist_path, guide_path, instructions_text, validation
        ),
    )
    write_text(
        mem / "architecture-contract.md",
        build_architecture_contract(guide_path, guide_text),
    )

    execution_graph = {
        "generated_at": now_iso(),
        "phase_order": [p["id"] for p in phases],
        "phases": phases,
        "tasks": tasks,
    }
    write_json(mem / "execution-graph.json", execution_graph)

    registry = {
        "generated_at": now_iso(),
        "project_prefix": manifest["project_prefix"],
        "phase_order": [p["id"] for p in phases],
        "phases": phases,
        "tasks": tasks,
    }
    save_registry(registry)

    for phase in phases:
        write_phase_yaml(tasks_root / "phases" / f"{phase['id']}.yaml", phase)
    for task in tasks:
        write_task_yaml(tasks_root / "work-items" / f"{task['id']}.yaml", task)

    first_phase = (
        phases[0]
        if phases
        else {"id": None, "title": None, "status": "empty", "task_ids": []}
    )
    first_task = (
        tasks[0]
        if tasks
        else {
            "id": None,
            "title": None,
            "status": "empty",
            "allowed_paths": [],
            "verification_commands": [],
        }
    )
    save_active_phase(first_phase)
    save_active_task(first_task)
    save_runtime_state(
        {
            "generated_at": now_iso(),
            "active_phase_id": first_phase.get("id"),
            "active_task_id": first_task.get("id"),
            "last_worker": None,
            "last_event": "bootstrap_refresh",
        }
    )

    append_jsonl(
        tasks_root / "ledger.jsonl",
        {
            "ts": now_iso(),
            "event": "bootstrap_refresh",
            "phase_count": len(phases),
            "task_count": len(tasks),
            "project_prefix": manifest["project_prefix"],
        },
    )

    return {
        "ok": True,
        "manifest": manifest,
        "phase_count": len(phases),
        "task_count": len(tasks),
        "phases": phases,
        "tasks": tasks,
        "validation": validation,
    }


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Bootstrap a three-doc project (generate runtime artifacts)."
    )
    parser.add_argument(
        "--validate-only",
        action="store_true",
        help="Only validate the three-doc contract; do not write artifacts.",
    )
    parser.add_argument(
        "--refresh",
        action="store_true",
        help="Generate or refresh all runtime artifacts.",
    )
    parser.add_argument(
        "--json",
        action="store_true",
        help="Print machine-readable JSON output.",
    )
    args = parser.parse_args()

    docs = discover_source_docs(project_root())
    validation = validate_docs(docs)

    if args.validate_only and not args.refresh:
        result = {
            "ok": not bool(validation["errors"]),
            "validation": validation,
            "docs": {k: [relpath(p) for p in v] for k, v in docs.items()},
        }
        if args.json:
            print(json.dumps(result, ensure_ascii=False, indent=2))
        else:
            if result["ok"]:
                print("Three-doc contract is valid.")
            else:
                print("Three-doc contract is INVALID.")
            for err in validation["errors"]:
                print(f"ERROR: {err}")
            for warn in validation["warnings"]:
                print(f"WARNING: {warn}")
            print(json.dumps(result["docs"], ensure_ascii=False, indent=2))
        return 0 if result["ok"] else 1

    result = generate_artifacts()
    if args.json:
        print(json.dumps(result, ensure_ascii=False, indent=2))
    else:
        if result["ok"]:
            print(
                f"Bootstrapped project prefix: {result['manifest']['project_prefix']}"
            )
            print(f"Detected phases: {result['phase_count']}")
            print(f"Generated tasks: {result['task_count']}")
            print("Artifacts written under .claude/memory and .claude/tasks")
        else:
            print("Failed to bootstrap due to validation errors.")
            for err in result["validation"]["errors"]:
                print(f"ERROR: {err}")
            for warn in result["validation"]["warnings"]:
                print(f"WARNING: {warn}")
    return 0 if result["ok"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
