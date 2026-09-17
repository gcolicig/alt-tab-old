from __future__ import annotations

import json
import unittest

from tests.support import ROOT, load_json


class JsonSchemaTests(unittest.TestCase):
    def test_all_json_files_parse(self) -> None:
        paths = [path for path in ROOT.rglob("*.json") if ".git" not in path.parts]
        self.assertGreaterEqual(len(paths), 2)
        for path in paths:
            with self.subTest(path=str(path.relative_to(ROOT))):
                json.loads(path.read_text(encoding="utf-8"))

    def test_schemas_declare_draft_and_closed_root(self) -> None:
        for path in sorted((ROOT / "schemas").glob("*.schema.json")):
            schema = json.loads(path.read_text(encoding="utf-8"))
            with self.subTest(path=path.name):
                self.assertEqual(schema["$schema"], "https://json-schema.org/draft/2020-12/schema")
                self.assertEqual(schema["type"], "object")
                self.assertFalse(schema["additionalProperties"])
                self.assertTrue(schema["required"])

    def test_report_schema_covers_harness_fields(self) -> None:
        schema = load_json("schemas/verification-report.schema.json")
        required = set(schema["required"])
        expected = {"schema", "status", "gate_status", "profile", "generated_at", "duration_ms", "environment", "contract_versions", "counts", "tests", "diagnostics"}
        self.assertEqual(required, expected)


if __name__ == "__main__":
    unittest.main()
