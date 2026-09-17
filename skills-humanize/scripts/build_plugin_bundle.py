#!/usr/bin/env python3
"""Build a deterministic Humanizer CH plugin archive from an explicit allowlist."""

from __future__ import annotations

import argparse
from hashlib import sha256
import json
from pathlib import Path
import zipfile


ROOT = Path(__file__).resolve().parents[1]
PLUGIN = ROOT / "humanizer-ch"
VERSION = "0.1.0"
ZIP_TIMESTAMP = (1980, 1, 1, 0, 0, 0)


def members() -> list[tuple[Path, str]]:
    items: list[tuple[Path, str]] = []
    fixed_roots = [PLUGIN / ".codex-plugin", PLUGIN / "skills", ROOT / "src" / "humanizer_ch_core", ROOT / "schemas"]
    for base in fixed_roots:
        for source in sorted(path for path in base.rglob("*") if path.is_file() and "__pycache__" not in path.parts):
            if source.suffix in {".pyc", ".pyo"}:
                continue
            if base == ROOT / "src" / "humanizer_ch_core":
                relative = Path("runtime") / "humanizer_ch_core" / source.relative_to(base)
            elif base == ROOT / "schemas":
                relative = Path("schemas") / source.relative_to(base)
            else:
                relative = source.relative_to(PLUGIN)
            items.append((source, str(Path("humanizer-ch") / relative)))
    return sorted(items, key=lambda item: item[1])


def build(output: Path) -> dict[str, object]:
    selected = members()
    output.parent.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(output, "w", zipfile.ZIP_DEFLATED) as archive:
        for source, archive_name in selected:
            info = zipfile.ZipInfo(archive_name, ZIP_TIMESTAMP)
            info.compress_type = zipfile.ZIP_DEFLATED
            info.create_system = 3
            info.external_attr = 0o644 << 16
            archive.writestr(info, source.read_bytes())
    return {
        "output": str(output),
        "version": VERSION,
        "file_count": len(selected),
        "bytes": output.stat().st_size,
        "sha256": sha256(output.read_bytes()).hexdigest(),
    }


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, default=ROOT / "dist" / f"humanizer-ch-{VERSION}.zip")
    args = parser.parse_args(argv)
    print(json.dumps(build(args.output), ensure_ascii=False, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
