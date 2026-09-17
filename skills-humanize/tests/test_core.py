from __future__ import annotations

import io
import json
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch

from humanizer_ch_core.audit import deterministic_findings
from humanizer_ch_core.capabilities import foundation_capabilities
from humanizer_ch_core.cli import main, proofread_main, translate_main
from humanizer_ch_core.config import resolve_config
from humanizer_ch_core.errors import ErrorCode, HumanizerError
from humanizer_ch_core.scope import create_document, select_span, verify_selection


class ConfigurationTests(unittest.TestCase):
    def test_precedence_and_provenance(self) -> None:
        config = resolve_config(
            {"locale": "de-CH"},
            {"locale": "de-DE", "register": "formal"},
            {"register": "locker", "language": "de"},
        )
        self.assertEqual(config.locale, "de-CH")
        self.assertEqual(config.register, "formal")
        self.assertEqual(config.language, "de")
        self.assertEqual(config.provenance["locale"], "invocation")
        self.assertEqual(config.provenance["register"], "project")

    def test_invalid_locale_uses_stable_error(self) -> None:
        with self.assertRaises(HumanizerError) as caught:
            resolve_config({"locale": "de-LI"})
        self.assertEqual(caught.exception.code, ErrorCode.CONFIG_PROFILE_INVALID)
        self.assertEqual(caught.exception.exit_code, 3)

    def test_locale_infers_language_and_rejects_conflict(self) -> None:
        self.assertEqual(resolve_config({"locale": "fr-CH"}).language, "fr")
        with self.assertRaises(HumanizerError) as caught:
            resolve_config({"language": "de", "locale": "en-GB"})
        self.assertEqual(caught.exception.code, ErrorCode.CONFIG_LOCALE_CONFLICT)

    def test_unknown_configuration_key_fails(self) -> None:
        with self.assertRaises(HumanizerError) as caught:
            resolve_config({"unknown": True})
        self.assertEqual(caught.exception.code, ErrorCode.CONFIG_PROFILE_INVALID)


class ScopeTests(unittest.TestCase):
    def test_selection_is_revision_bound(self) -> None:
        original = create_document("Ein kurzer Text.")
        selection = select_span(original, 4, 10)
        verify_selection(original, selection)
        changed = create_document("Ein anderer Text.")
        with self.assertRaises(HumanizerError) as caught:
            verify_selection(changed, selection)
        self.assertEqual(caught.exception.code, ErrorCode.INPUT_REVISION_MISMATCH)

    def test_invalid_span_fails(self) -> None:
        with self.assertRaises(HumanizerError) as caught:
            select_span(create_document("abc"), 0, 4)
        self.assertEqual(caught.exception.code, ErrorCode.INPUT_SCOPE_INVALID)


class AuditTests(unittest.TestCase):
    def test_de_ch_and_hidden_unicode_findings(self) -> None:
        findings = deterministic_findings("gro\u00df\u200b", "de-CH")
        self.assertEqual([item.rule_id for item in findings], ["de_ch_eszett", "hidden_unicode"])

    def test_capability_probe_is_metadata_only(self) -> None:
        capabilities = foundation_capabilities()
        self.assertTrue(capabilities)
        self.assertTrue(all(item.probe_method in {"metadata", "artifact_manifest", "not_run"} for item in capabilities))


class CliTests(unittest.TestCase):
    def test_critical_selection_report_is_honest(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            source = Path(directory) / "sample.txt"
            source.write_text("Ein gro\u00dfer Test.", encoding="utf-8")
            output = io.StringIO()
            with patch("sys.stdout", output):
                exit_code = main(["audit", str(source), "--select", "span:0:16", "--locale", "de-CH", "--review-profile", "critical_text", "--report-format", "json"])
        report = json.loads(output.getvalue())
        self.assertEqual(exit_code, 12)
        self.assertEqual(report["quality_disposition"], "not_evaluated")
        self.assertEqual(report["result"], "incomplete")
        self.assertEqual(report["errors"][0]["code"], "HC_CHECK_REQUIRED_NOT_RUN")
        self.assertIn("semantic_humanization", [item["check_id"] for item in report["checks"] if item["status"] == "not_run"])
        self.assertEqual(report["data"]["findings"][0]["rule_id"], "de_ch_eszett")

    def test_proofread_correct_runs_deterministic_checks(self) -> None:
        with patch("sys.stdin", io.StringIO("gro\u00df")), patch("sys.stdout", new_callable=io.StringIO) as output:
            exit_code = proofread_main(["correct", "--stdin", "--locale", "de-CH", "--report-format", "json"])
        self.assertEqual(exit_code, 12)
        self.assertEqual(json.loads(output.getvalue())["data"]["findings"][0]["rule_id"], "de_ch_eszett")

    def test_translate_without_adapter_fails_distinctly(self) -> None:
        with patch("sys.stderr", new_callable=io.StringIO) as error_output:
            self.assertEqual(translate_main(["--report-format", "json"]), 6)
        report = json.loads(error_output.getvalue())
        self.assertEqual(report["errors"][0]["code"], "HC_ADAPTER_UNAVAILABLE")

    def test_finding_span_is_document_relative(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            source = Path(directory) / "sample.txt"
            source.write_text("xxgro\u00dfyy", encoding="utf-8")
            output = io.StringIO()
            with patch("sys.stdout", output):
                main(["audit", str(source), "--select", "span:2:6", "--locale", "de-CH", "--report-format", "json"])
        finding = json.loads(output.getvalue())["data"]["findings"][0]
        self.assertEqual((finding["start"], finding["end"]), (5, 6))

    def test_expected_revision_prevents_stale_file_selection(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            source = Path(directory) / "sample.txt"
            source.write_text("Text", encoding="utf-8")
            with patch("sys.stderr", new_callable=io.StringIO) as error_output:
                exit_code = main(["audit", str(source), "--expect-revision", "sha256:stale", "--report-format", "json"])
        self.assertEqual(exit_code, 2)
        self.assertEqual(json.loads(error_output.getvalue())["errors"][0]["code"], "HC_INPUT_REVISION_MISMATCH")


if __name__ == "__main__":
    unittest.main()
