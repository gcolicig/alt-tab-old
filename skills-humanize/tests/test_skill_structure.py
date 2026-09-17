from __future__ import annotations

import re
import unittest

from tests.support import ROOT, load_json


class SkillStructureTests(unittest.TestCase):
    def test_plugin_manifests_name_existing_skill_directory(self) -> None:
        manifests = list(ROOT.glob("*/.codex-plugin/plugin.json"))
        if not manifests:
            self.skipTest("No plugin has been scaffolded yet")
        for path in manifests:
            manifest = load_json(str(path.relative_to(ROOT)))
            with self.subTest(path=str(path.relative_to(ROOT))):
                self.assertRegex(manifest["name"], r"^[a-z0-9-]+$")
                self.assertRegex(manifest["version"], r"^\d+\.\d+\.\d+$")
                self.assertTrue((path.parent.parent / manifest["skills"]).is_dir())

    def test_present_skills_have_frontmatter_and_required_fields(self) -> None:
        skills = [path for path in ROOT.rglob("SKILL.md") if ".git" not in path.parts]
        if not skills:
            self.skipTest("No product skill has been scaffolded yet")
        for path in skills:
            text = path.read_text(encoding="utf-8")
            with self.subTest(path=str(path.relative_to(ROOT))):
                self.assertTrue(text.startswith("---\n"))
                parts = text.split("---", 2)
                self.assertEqual(len(parts), 3)
                frontmatter = parts[1]
                self.assertRegex(frontmatter, r"(?m)^name:\s*\S+")
                self.assertRegex(frontmatter, r"(?m)^description:\s*.+")
                self.assertRegex(parts[2], r"(?m)^# .+")

    def test_skill_names_are_unique(self) -> None:
        names: dict[str, str] = {}
        for path in ROOT.rglob("SKILL.md"):
            if ".git" in path.parts:
                continue
            match = re.search(r"(?m)^name:\s*([^\s#]+)", path.read_text(encoding="utf-8"))
            if not match:
                continue
            name = match.group(1)
            self.assertNotIn(name, names, f"duplicate skill name {name}: {names.get(name)} and {path}")
            names[name] = str(path)

    def test_skill_relative_links_resolve(self) -> None:
        pattern = re.compile(r"\[[^]]*]\(([^)]+)\)")
        for path in ROOT.rglob("SKILL.md"):
            if ".git" in path.parts:
                continue
            for target in pattern.findall(path.read_text(encoding="utf-8")):
                if "://" in target or target.startswith("#"):
                    continue
                with self.subTest(path=str(path.relative_to(ROOT)), target=target):
                    self.assertTrue((path.parent / target.split("#", 1)[0]).is_file())

    def test_product_skill_descriptions_are_trigger_separated(self) -> None:
        humanizer = (ROOT / "humanizer-ch/skills/humanizer-ch/SKILL.md").read_text(encoding="utf-8").split("---", 2)[1]
        proofread = (ROOT / "humanizer-ch/skills/proofread-ch/SKILL.md").read_text(encoding="utf-8").split("---", 2)[1]
        self.assertIn("KI-Muster-Audit", humanizer)
        self.assertIn("nicht für reines Korrektorat", humanizer)
        self.assertIn("ausdrücklich Rechtschreibung", proofread)
        self.assertIn("nicht für KI-Tell-Audit", proofread)


if __name__ == "__main__":
    unittest.main()
