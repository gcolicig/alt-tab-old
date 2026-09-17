from __future__ import annotations

import re
import unittest

from tests.support import ROOT


class ContractTests(unittest.TestCase):
    def test_contracts_have_identity_and_purpose(self) -> None:
        contracts = sorted((ROOT / "contracts").glob("*.md"))
        self.assertGreaterEqual(len(contracts), 1)
        for path in contracts:
            text = path.read_text(encoding="utf-8")
            with self.subTest(path=path.name):
                self.assertRegex(text, r"(?m)^# .+")
                self.assertRegex(text, r"(?m)^Status: .+ \d+\.\d+\.\d+$")
                self.assertRegex(text, r"(?m)^Verantwortung: `[^`]+`$")
                self.assertIn("## Zweck", text)

    def test_contract_versions_are_semver(self) -> None:
        for path in sorted((ROOT / "contracts").glob("*.md")):
            match = re.search(r"(?m)^Status: .+ (\S+)$", path.read_text(encoding="utf-8"))
            with self.subTest(path=path.name):
                self.assertIsNotNone(match)
                self.assertRegex(match.group(1), r"^\d+\.\d+\.\d+$")


if __name__ == "__main__":
    unittest.main()

