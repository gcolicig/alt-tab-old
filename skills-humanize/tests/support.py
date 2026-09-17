from __future__ import annotations

import json
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[1]


def load_json(relative: str) -> dict[str, Any]:
    return json.loads((ROOT / relative).read_text(encoding="utf-8"))


def validate_selection(payload: dict[str, Any]) -> list[str]:
    errors: list[str] = []
    required = {"contract_version", "operation", "scope_mode", "review_profile", "selection"}
    errors.extend(f"missing:{key}" for key in sorted(required - payload.keys()))
    if payload.get("scope_mode") != "selection":
        errors.append("scope_mode")
    selection = payload.get("selection")
    if not isinstance(selection, dict):
        return errors + ["selection"]
    identity = {"source_revision", "segment_id", "format_node_id", "span", "source_hash"}
    errors.extend(f"selection.missing:{key}" for key in sorted(identity - selection.keys()))
    span = selection.get("span")
    if not isinstance(span, dict) or not isinstance(span.get("start"), int) or not isinstance(span.get("end"), int):
        errors.append("selection.span")
    elif span["start"] < 0 or span["end"] <= span["start"]:
        errors.append("selection.span.order")
    source_hash = selection.get("source_hash", "")
    if not isinstance(source_hash, str) or not source_hash.startswith("sha256:") or len(source_hash) != 71:
        errors.append("selection.source_hash")
    return errors

