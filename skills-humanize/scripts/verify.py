#!/usr/bin/env python3
"""Run the canonical deterministic verification suite and emit a JSON report."""

from __future__ import annotations

import argparse
import importlib.util
import json
import platform
import sys
import time
import unittest
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / "src"
if str(SRC) not in sys.path:
    sys.path.insert(0, str(SRC))
REPORT_SCHEMA = "humanizer-ch-verification-report@1"


class JsonTestResult(unittest.TestResult):
    def __init__(self) -> None:
        super().__init__()
        self.records: list[dict[str, Any]] = []
        self._started: dict[str, float] = {}

    def startTest(self, test: unittest.case.TestCase) -> None:
        super().startTest(test)
        self._started[test.id()] = time.perf_counter()

    def addSuccess(self, test: unittest.case.TestCase) -> None:
        super().addSuccess(test)
        self._record(test, "passed")

    def addSkip(self, test: unittest.case.TestCase, reason: str) -> None:
        super().addSkip(test, reason)
        self._record(test, "skipped", reason)

    def addFailure(self, test: unittest.case.TestCase, err: tuple[type[BaseException], BaseException, object]) -> None:
        super().addFailure(test, err)
        self._record(test, "failed", self._exc_info_to_string(err, test))

    def addError(self, test: unittest.case.TestCase, err: tuple[type[BaseException], BaseException, object]) -> None:
        super().addError(test, err)
        self._record(test, "failed", self._exc_info_to_string(err, test))

    def _record(self, test: unittest.case.TestCase, status: str, detail: str | None = None) -> None:
        record: dict[str, Any] = {
            "id": test.id(),
            "status": status,
            "duration_ms": round((time.perf_counter() - self._started.pop(test.id(), time.perf_counter())) * 1000, 3),
        }
        if detail:
            record["detail"] = detail
        self.records.append(record)


def contract_versions() -> dict[str, str]:
    versions: dict[str, str] = {}
    for path in sorted((ROOT / "contracts").glob("*.md")):
        version = "unknown"
        for line in path.read_text(encoding="utf-8").splitlines()[:10]:
            if line.startswith("Status:"):
                version = line.rsplit(" ", 1)[-1]
                break
        versions[path.name] = version
    return versions


def diagnostics() -> list[dict[str, str]]:
    checks = []
    yaml_available = importlib.util.find_spec("yaml") is not None
    checks.append({
        "id": "dependency.pyyaml",
        "status": "passed" if yaml_available else "skipped",
        "detail": "PyYAML available" if yaml_available else "PyYAML not installed; YAML-backed skill validation is unavailable",
        "required_for_release": True,
    })
    setuptools_available = importlib.util.find_spec("setuptools") is not None
    checks.append({
        "id": "dependency.setuptools",
        "status": "passed" if setuptools_available else "skipped",
        "detail": "setuptools available" if setuptools_available else "setuptools not installed; wheel and isolated installation smoke tests are unavailable",
        "required_for_release": True,
    })
    checks.append({
        "id": "evaluation.models",
        "status": "skipped",
        "detail": "Deterministic profile does not invoke network services or models",
        "required_for_release": False,
    })
    return checks


def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--report", type=Path, help="write the JSON report to this path")
    parser.add_argument("--compact", action="store_true", help="emit compact JSON")
    return parser.parse_args(argv)


def build_report(result: JsonTestResult, elapsed_ms: float) -> dict[str, Any]:
    diagnostic_records = diagnostics()
    all_records = [*result.records, *diagnostic_records]
    counts = {
        "passed": sum(item["status"] == "passed" for item in all_records),
        "failed": sum(item["status"] == "failed" for item in all_records),
        "skipped": sum(item["status"] == "skipped" for item in all_records),
    }
    return {
        "schema": REPORT_SCHEMA,
        "status": "failed" if counts["failed"] else "passed",
        "gate_status": "failed" if counts["failed"] else "incomplete" if any(item.get("required_for_release") and item["status"] != "passed" for item in diagnostic_records) else "passed",
        "profile": "deterministic",
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "duration_ms": round(elapsed_ms, 3),
        "environment": {"python": platform.python_version(), "platform": platform.system().lower()},
        "contract_versions": contract_versions(),
        "corpus_revision": None,
        "routing_profile": None,
        "model_revisions": {},
        "metrics": {"model_latency_ms": 0, "normalized_cost": 0, "model_calls": 0},
        "counts": counts,
        "tests": result.records,
        "diagnostics": diagnostic_records,
    }


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv)
    started = time.perf_counter()
    suite = unittest.defaultTestLoader.discover(str(ROOT / "tests"), pattern="test_*.py", top_level_dir=str(ROOT))
    result = JsonTestResult()
    suite.run(result)
    report = build_report(result, (time.perf_counter() - started) * 1000)
    rendered = json.dumps(report, ensure_ascii=False, indent=None if args.compact else 2, sort_keys=True) + "\n"
    if args.report:
        target = args.report if args.report.is_absolute() else ROOT / args.report
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(rendered, encoding="utf-8")
    sys.stdout.write(rendered)
    return 1 if report["status"] == "failed" else 0


if __name__ == "__main__":
    raise SystemExit(main())
