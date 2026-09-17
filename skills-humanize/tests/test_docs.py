from __future__ import annotations

import re
import unittest
from pathlib import Path

from tests.support import ROOT


class DocumentationTests(unittest.TestCase):
    def test_relative_markdown_links_resolve(self) -> None:
        files = list(ROOT.glob("*.md")) + list((ROOT / "contracts").glob("*.md"))
        pattern = re.compile(r"\[[^]]*]\(([^)]+)\)")
        for source in files:
            for raw_target in pattern.findall(source.read_text(encoding="utf-8")):
                target = raw_target.split("#", 1)[0]
                if not target or "://" in target or target.startswith("mailto:"):
                    continue
                with self.subTest(source=source.name, target=target):
                    self.assertTrue((source.parent / Path(target)).exists())

    def test_markdown_fences_are_balanced(self) -> None:
        for path in ROOT.rglob("*.md"):
            if any(part.startswith(".") for part in path.relative_to(ROOT).parts):
                continue
            with self.subTest(path=str(path.relative_to(ROOT))):
                fences = sum(line.startswith("```") for line in path.read_text(encoding="utf-8").splitlines())
                self.assertEqual(fences % 2, 0)


if __name__ == "__main__":
    unittest.main()

