#!/usr/bin/env python3
"""
Compare locale JSON files to en.json (source of truth).

Usage (from repo root or Flutter_Munawwara):
  python tools/check_translations.py
  python tools/check_translations.py --dir assets/translations
  python tools/check_translations.py --strict   # exit 1 if any locale misses keys

Reports, per non-English file:
  - keys present in en.json but missing in that file
  - (optional) keys in that file but not in en.json (orphans)
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path


def load_flat_keys(path: Path) -> dict[str, str]:
    text = path.read_text(encoding="utf-8-sig")
    data = json.loads(text)
    if not isinstance(data, dict):
        raise ValueError(f"{path} root must be a JSON object")
    out: dict[str, str] = {}
    for k, v in data.items():
        if not isinstance(k, str):
            continue
        out[k] = v if isinstance(v, str) else json.dumps(v, ensure_ascii=False)
    return out


def main() -> int:
    parser = argparse.ArgumentParser(description="Check translation keys vs en.json")
    parser.add_argument(
        "--dir",
        type=Path,
        default=None,
        help="Directory containing *.json (default: .../assets/translations next to tools/)",
    )
    parser.add_argument(
        "--strict",
        action="store_true",
        help="Exit with code 1 if any locale is missing keys from en.json",
    )
    parser.add_argument(
        "--show-orphans",
        action="store_true",
        help="Also list keys in a locale file that are not in en.json",
    )
    args = parser.parse_args()

    if args.dir is None:
        script_dir = Path(__file__).resolve().parent
        candidate = script_dir.parent / "assets" / "translations"
        if candidate.is_dir():
            translations_dir = candidate
        else:
            translations_dir = (Path.cwd() / "assets" / "translations").resolve()
    else:
        translations_dir = args.dir.resolve()

    en_path = translations_dir / "en.json"
    if not en_path.is_file():
        print(f"error: missing baseline {en_path}", file=sys.stderr)
        return 2

    try:
        en_keys = set(load_flat_keys(en_path).keys())
    except (json.JSONDecodeError, ValueError) as e:
        print(f"error: cannot read {en_path}: {e}", file=sys.stderr)
        return 2

    other_files = sorted(
        p for p in translations_dir.glob("*.json") if p.name != "en.json"
    )
    if not other_files:
        print(f"no locale files besides en.json in {translations_dir}")
        return 0

    any_missing = False
    print(f"Baseline: en.json ({len(en_keys)} keys)\n")
    print(f"Directory: {translations_dir}\n")

    for path in other_files:
        lang = path.stem
        try:
            loc_keys = set(load_flat_keys(path).keys())
        except (json.JSONDecodeError, ValueError) as e:
            print(f"## {lang}.json - ERROR: {e}\n")
            any_missing = True
            continue

        missing = sorted(en_keys - loc_keys)
        extra = sorted(loc_keys - en_keys)

        print(f"## {lang}.json - {len(loc_keys)} keys")

        if missing:
            any_missing = True
            print(f"   Missing {len(missing)} key(s) vs en.json:")
            for k in missing:
                print(f"      - {k}")
        else:
            print("   Missing vs en.json: none")

        if args.show_orphans and extra:
            print(f"   Orphans (not in en.json): {len(extra)}")
            for k in extra:
                print(f"      + {k}")

        print()

    if args.strict and any_missing:
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
