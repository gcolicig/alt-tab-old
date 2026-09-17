from __future__ import annotations

from hashlib import sha256
import tempfile
from pathlib import Path
import unittest
import zipfile

from scripts.build_plugin_bundle import build


class BundleTests(unittest.TestCase):
    def test_bundle_is_reproducible_and_excludes_maintenance(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            first = Path(directory) / "first.zip"
            second = Path(directory) / "second.zip"
            build(first)
            build(second)
            self.assertEqual(sha256(first.read_bytes()).digest(), sha256(second.read_bytes()).digest())
            with zipfile.ZipFile(first) as archive:
                names = archive.namelist()
        self.assertIn("humanizer-ch/.codex-plugin/plugin.json", names)
        self.assertIn("humanizer-ch/skills/humanizer-ch/SKILL.md", names)
        self.assertIn("humanizer-ch/skills/proofread-ch/SKILL.md", names)
        self.assertTrue(any(name.startswith("humanizer-ch/runtime/humanizer_ch_core/") for name in names))
        self.assertFalse(any("maintainer" in name for name in names))
        self.assertFalse(any("tests/" in name for name in names))


if __name__ == "__main__":
    unittest.main()
