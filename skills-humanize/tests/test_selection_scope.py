from __future__ import annotations

import copy
import unittest

from tests.support import ROOT, load_json, validate_selection


class SelectionScopeTests(unittest.TestCase):
    def setUp(self) -> None:
        self.payload = load_json("tests/fixtures/selection-request.valid.json")
        self.contract = (ROOT / "contracts/selection-scope.md").read_text(encoding="utf-8")

    def test_valid_selection_identity(self) -> None:
        self.assertEqual(validate_selection(self.payload), [])

    def test_selection_identity_is_revision_bound(self) -> None:
        for key in ("source_revision", "segment_id", "format_node_id", "source_hash"):
            candidate = copy.deepcopy(self.payload)
            del candidate["selection"][key]
            with self.subTest(key=key):
                self.assertIn(f"selection.missing:{key}", validate_selection(candidate))

    def test_selection_span_must_be_nonempty_and_ordered(self) -> None:
        candidate = copy.deepcopy(self.payload)
        candidate["selection"]["span"] = {"start": 4, "end": 4}
        self.assertIn("selection.span.order", validate_selection(candidate))

    def test_contract_requires_zero_fulltext_model_tokens(self) -> None:
        self.assertIn("Volltexttokens im Modellrequest null", self.contract)

    def test_contract_forbids_editing_context(self) -> None:
        self.assertIn("`context_before` und `context_after` sind optional und nicht editierbar", self.contract)

    def test_document_checks_remain_not_run(self) -> None:
        self.assertIn("dokumentweite Checks mit dem Zustand `not_run`", self.contract)

    def test_critical_text_defaults_to_audit_without_escalation(self) -> None:
        self.assertIn("operation=audit", self.contract)
        self.assertIn("scope_mode=selection", self.contract)
        self.assertIn("review_profile=critical_text", self.contract)
        self.assertIn("erhoeht weder Rewrite-Tiefe, Modellklasse, Effort noch Passzahl automatisch", self.contract)


if __name__ == "__main__":
    unittest.main()

