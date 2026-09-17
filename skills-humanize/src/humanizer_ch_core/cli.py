from __future__ import annotations

import argparse
import json
from pathlib import Path
import sys
from uuid import uuid4

from . import __version__
from .audit import deterministic_findings
from .capabilities import foundation_capabilities
from .config import resolve_config
from .errors import ErrorCode, HumanizerError
from .scope import create_document, select_span


def _parser(program: str, default_operation: str) -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(prog=program)
    parser.add_argument("operation", nargs="?", default=default_operation)
    source = parser.add_mutually_exclusive_group()
    source.add_argument("file", nargs="?", type=Path)
    source.add_argument("--stdin", action="store_true")
    parser.add_argument("--select", action="append", default=[])
    parser.add_argument("--expect-revision")
    parser.add_argument("--expect-source-hash")
    parser.add_argument("--language")
    parser.add_argument("--locale")
    parser.add_argument("--register", choices=("locker", "sachlich", "formal"))
    parser.add_argument("--review-profile", default="standard")
    parser.add_argument("--report-format", choices=("text", "json"), default="text")
    parser.add_argument("--version", action="version", version=__version__)
    return parser


def _read(args: argparse.Namespace) -> str:
    if args.stdin:
        return sys.stdin.read()
    if args.file:
        return args.file.read_text(encoding="utf-8")
    raise HumanizerError(ErrorCode.INPUT_EMPTY, "Datei oder --stdin erforderlich.", "cli", safe_action="fix_input")


def _span(selectors: list[str], length: int) -> tuple[int, int]:
    if not selectors:
        return 0, length
    if len(selectors) != 1 or not selectors[0].startswith("span:"):
        raise HumanizerError(ErrorCode.INPUT_SCOPE_INVALID, "Foundation unterstützt genau einen Selektor span:START:END.", "cli", safe_action="review_scope")
    try:
        start_text, end_text = selectors[0][5:].split(":", 1)
        return int(start_text), int(end_text)
    except ValueError as error:
        raise HumanizerError(ErrorCode.INPUT_SCOPE_INVALID, "Ungültiger Span-Selektor.", "cli", safe_action="review_scope") from error


def _run(argv: list[str] | None, program: str, default_operation: str, allowed: set[str]) -> int:
    args = _parser(program, default_operation).parse_args(argv)
    try:
        if args.operation == "doctor":
            report = {
                "schema_version": "0.1",
                "report_id": f"report-{uuid4().hex}",
                "workflow_status": "completed",
                "adapter_status": "disabled",
                "quality_disposition": "not_evaluated",
                "result": "success",
                "exit_code": 0,
                "errors": [],
                "checks": [{"check_id": "capability_probe", "required": True, "status": "passed"}],
                "data": {
                    "version": __version__,
                    "core": "ready",
                    "capabilities": [item.as_dict() for item in foundation_capabilities()],
                    "probe_constraints": {"network": False, "model_loaded": False, "text_sent": False},
                },
            }
        else:
            if args.operation not in allowed:
                raise HumanizerError(ErrorCode.CONFIG_PROFILE_INVALID, f"Operation noch nicht verfügbar: {args.operation}", "cli", safe_action="fix_configuration")
            text = _read(args)
            config = resolve_config({"language": args.language, "locale": args.locale, "register": args.register})
            document = create_document(text)
            start, end = _span(args.select, len(text))
            selection = select_span(document, start, end)
            if args.expect_revision and args.expect_revision != selection.source_revision:
                raise HumanizerError(ErrorCode.INPUT_REVISION_MISMATCH, "Erwartete Dokumentrevision stimmt nicht überein.", "scope", safe_action="review_scope")
            if args.expect_source_hash and args.expect_source_hash != selection.source_hash:
                raise HumanizerError(ErrorCode.INPUT_REVISION_MISMATCH, "Erwarteter Auswahlhash stimmt nicht überein.", "scope", safe_action="review_scope")
            findings = []
            for finding in deterministic_findings(selection.text, config.locale):
                item = finding.as_dict()
                item["start"] = int(item["start"]) + selection.start
                item["end"] = int(item["end"]) + selection.start
                findings.append(item)
            required_semantic = "semantic_humanization" if program == "humanizer-ch" else "grammar_and_context"
            checks = [
                {"check_id": "selection_integrity", "required": True, "status": "passed"},
                {"check_id": "deterministic_candidate_scan", "required": True, "status": "passed"},
                {"check_id": required_semantic, "required": True, "status": "not_run", "reason_code": "FOUNDATION_NOT_IMPLEMENTED"},
                {"check_id": "document_completeness", "required": False, "status": "not_run", "reason_code": "SELECTION_SCOPE"},
                {"check_id": "document_terminology", "required": False, "status": "not_run", "reason_code": "SELECTION_SCOPE"},
                {"check_id": "document_register", "required": False, "status": "not_run", "reason_code": "SELECTION_SCOPE"},
            ]
            report = {
                "schema_version": "0.1",
                "report_id": f"report-{uuid4().hex}",
                "workflow_status": "completed",
                "adapter_status": "disabled",
                "quality_disposition": "not_evaluated",
                "result": "incomplete",
                "exit_code": 12,
                "errors": [HumanizerError(ErrorCode.CHECK_REQUIRED_NOT_RUN, "Erforderlicher semantischer Check wurde nicht ausgeführt.", "orchestration").as_dict()],
                "checks": checks,
                "data": {
                    "operation": args.operation,
                    "review_profile": args.review_profile,
                    "config": {"language": config.language, "locale": config.locale, "register": config.register, "provenance": config.provenance},
                    "evaluated_scope": selection.as_dict(),
                    "findings": findings,
                },
            }
        if args.report_format == "json":
            print(json.dumps(report, ensure_ascii=False, sort_keys=True))
        else:
            print(f"{program}: {report}")
        return int(report["exit_code"])
    except HumanizerError as error:
        report = {
            "schema_version": "0.1",
            "report_id": f"report-{uuid4().hex}",
            "workflow_status": "failed",
            "adapter_status": "failed" if error.code == ErrorCode.ADAPTER_UNAVAILABLE else "disabled",
            "quality_disposition": "not_evaluated",
            "result": "failed",
            "exit_code": error.exit_code,
            "errors": [error.as_dict()],
            "checks": [],
        }
        if args.report_format == "json":
            print(json.dumps(report, ensure_ascii=False, sort_keys=True), file=sys.stderr)
        else:
            print(f"{error.code.value}: {error.message}", file=sys.stderr)
        return error.exit_code
    except OSError:
        error = HumanizerError(ErrorCode.IO_READ, "Eingabe konnte nicht gelesen werden.", "cli", safe_action="fix_input")
        print(f"{error.code.value}: {error.message}", file=sys.stderr)
        return error.exit_code


def main(argv: list[str] | None = None) -> int:
    return _run(argv, "humanizer-ch", "audit", {"audit"})


def proofread_main(argv: list[str] | None = None) -> int:
    return _run(argv, "proofread-ch", "correct", {"correct"})


def translate_main(argv: list[str] | None = None) -> int:
    args = list(sys.argv[1:] if argv is None else argv)
    if "--help" in args or "-h" in args:
        print("translate-ch: optional adapter entry point; no adapter configured in the foundation build")
        return 0
    parser = argparse.ArgumentParser(add_help=False)
    parser.add_argument("--report-format", choices=("text", "json"), default="text")
    parsed, _ = parser.parse_known_args(args)
    error = HumanizerError(ErrorCode.ADAPTER_UNAVAILABLE, "Kein Übersetzungsadapter konfiguriert.", "translate", safe_action="choose_adapter")
    report = {
        "schema_version": "0.1",
        "report_id": f"report-{uuid4().hex}",
        "workflow_status": "failed",
        "adapter_status": "unavailable",
        "quality_disposition": "not_evaluated",
        "result": "failed",
        "exit_code": error.exit_code,
        "errors": [error.as_dict()],
        "checks": [],
    }
    if parsed.report_format == "json":
        print(json.dumps(report, ensure_ascii=False, sort_keys=True), file=sys.stderr)
    else:
        print(f"{error.code.value}: {error.message}", file=sys.stderr)
    return error.exit_code


if __name__ == "__main__":
    raise SystemExit(main())
