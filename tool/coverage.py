#!/usr/bin/env python3
"""Filter generated files out of coverage/lcov.info and print a Markdown summary.

Generated Dart (`*.g.dart`, l10n delegates, freezed) is excluded from coverage:
it is machine-written, not hand-tested, and counting it (notably the large Drift
`database.g.dart`) deflates the number. This script is the *single* home for that
exclusion list — both `just coverage` (local) and CI run it, so the percentage is
identical everywhere. It rewrites `coverage/lcov.info` in place (filtered) and
writes a Markdown summary to stdout (CI appends it to the job summary).
"""

import re
import sys
from collections import defaultdict

LCOV = "coverage/lcov.info"

# Generated / non-hand-written sources excluded from coverage.
GENERATED = re.compile(r"\.g\.dart$|\.freezed\.dart$|app_localizations.*\.dart$")


def main() -> int:
    try:
        blocks = open(LCOV).read().split("end_of_record\n")
    except FileNotFoundError:
        print(f"::error::{LCOV} not found — run `flutter test --coverage` first")
        return 1

    kept, lf_total, lh_total = [], 0, 0
    per_dir: dict[str, list[int]] = defaultdict(lambda: [0, 0])

    for block in blocks:
        if "SF:" not in block:
            continue
        sf = next(l[3:] for l in block.splitlines() if l.startswith("SF:"))
        if GENERATED.search(sf):
            continue
        lf = sum(int(l[3:]) for l in block.splitlines() if l.startswith("LF:"))
        lh = sum(int(l[3:]) for l in block.splitlines() if l.startswith("LH:"))
        lf_total += lf
        lh_total += lh
        key = "/".join(sf.split("/")[:3])
        per_dir[key][0] += lf
        per_dir[key][1] += lh
        kept.append(block.rstrip("\n"))

    # Rewrite the lcov file with only the kept records.
    with open(LCOV, "w") as f:
        for block in kept:
            f.write(block + "\nend_of_record\n")

    pct = 100 * lh_total / lf_total if lf_total else 0.0
    print("## Coverage\n")
    print(f"**{pct:.1f}%** ({lh_total}/{lf_total} lines, generated files excluded)\n")
    print("| Area | Coverage |")
    print("| --- | --- |")
    for key in sorted(per_dir):
        lf, lh = per_dir[key]
        print(f"| `{key}` | {100 * lh / lf if lf else 0:.0f}% ({lh}/{lf}) |")
    return 0


if __name__ == "__main__":
    sys.exit(main())
