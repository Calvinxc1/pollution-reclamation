#!/usr/bin/env python3
"""Validate a Factorio changelog.txt against the documented format:
https://lua-api.factorio.com/latest/auxiliary/changelog-format.html
"""
from __future__ import annotations

import re
import sys
from pathlib import Path

SEPARATOR = "-" * 99
VERSION_PATTERN = re.compile(r"^Version: (\d+)\.(\d+)\.(\d+)$")
VERSION_COMPONENT_MAX = 65535
CATEGORY_PATTERN = re.compile(r"^  ([A-Za-z ]+):$")
ENTRY_PATTERN = re.compile(r"^    - (.*)$")
CONTINUATION_PATTERN = re.compile(r"^      (.*)$")

RECOGNIZED_CATEGORIES = {
    "Major Features", "Features", "Minor Features", "Graphics", "Sounds",
    "Optimizations", "Balancing", "Combat Balancing", "Circuit Network",
    "Changes", "Bugfixes", "Modding", "Scripting", "Gui", "Control",
    "Translation", "Debug", "Ease of use", "Info", "Locale", "Compatibility",
}


def validate(text: str) -> list[str]:
    errors: list[str] = []
    lines = text.split("\n")
    if lines and lines[-1] == "":
        lines = lines[:-1]

    for i, line in enumerate(lines, 1):
        if "\t" in line:
            errors.append(f"line {i}: contains a tab character")
        if line != line.rstrip():
            errors.append(f"line {i}: trailing whitespace")

    if not lines or lines[0] != SEPARATOR:
        errors.append(f"line 1: file must start with a {len(SEPARATOR)}-dash separator")
        return errors

    versions_seen: dict[str, int] = {}
    i = 0
    n = len(lines)
    while i < n:
        if lines[i] != SEPARATOR:
            errors.append(f"line {i + 1}: expected a {len(SEPARATOR)}-dash separator, got {lines[i]!r}")
            i += 1
            continue
        sep_line = i + 1
        i += 1
        if i >= n:
            errors.append(f"line {sep_line}: separator not followed by a Version line")
            break

        match = VERSION_PATTERN.match(lines[i])
        if not match:
            errors.append(f"line {i + 1}: expected 'Version: X.Y.Z', got {lines[i]!r}")
        else:
            version = match.group(0)[len("Version: "):]
            components = [int(match.group(g)) for g in (1, 2, 3)]
            if version == "0.0.0":
                errors.append(f"line {i + 1}: version 0.0.0 is not valid")
            out_of_range = [c for c in components if c > VERSION_COMPONENT_MAX]
            if out_of_range:
                errors.append(
                    f"line {i + 1}: version {version!r} has a component over "
                    f"{VERSION_COMPONENT_MAX} (max per the spec)"
                )
            if version in versions_seen:
                errors.append(
                    f"line {i + 1}: duplicate version {version!r} "
                    f"(first seen at line {versions_seen[version]})"
                )
            else:
                versions_seen[version] = i + 1
        i += 1

        date_lines = 0
        while i < n and lines[i].startswith("Date:"):
            date_lines += 1
            i += 1
        if date_lines > 1:
            errors.append(f"line {i}: more than one Date line in this version section")

        current_category: str | None = None
        # Per the spec: "Individual lines in a multiline entry will be considered
        # duplicates of other individual lines from other multiline entries in the
        # same category if they are identical" -- so dedup happens per line (entry
        # line or continuation line), not per whole entry, and only against lines
        # belonging to a *different* entry.
        seen_lines: dict[str, int] = {}
        entry_id = 0
        while i < n and lines[i] != SEPARATOR:
            line = lines[i]
            if line == "":
                i += 1
                continue

            category_match = CATEGORY_PATTERN.match(line)
            if category_match:
                current_category = category_match.group(1)
                if current_category not in RECOGNIZED_CATEGORIES:
                    errors.append(
                        f"line {i + 1}: category {current_category!r} is not a recognized "
                        f"Factorio changelog category"
                    )
                seen_lines = {}
                entry_id = 0
                i += 1
                continue

            entry_match = ENTRY_PATTERN.match(line)
            if entry_match:
                if current_category is None:
                    errors.append(f"line {i + 1}: entry appears before any category line")
                entry_id += 1
                entry_lines = [(i + 1, entry_match.group(1))]
                i += 1
                while i < n and CONTINUATION_PATTERN.match(lines[i]):
                    entry_lines.append((i + 1, CONTINUATION_PATTERN.match(lines[i]).group(1)))
                    i += 1
                for line_no, text in entry_lines:
                    owner = seen_lines.get(text)
                    if owner is not None and owner != entry_id:
                        errors.append(
                            f"line {line_no}: duplicate line within category "
                            f"{current_category!r}: {text!r} (matches another entry)"
                        )
                    else:
                        seen_lines[text] = entry_id
                continue

            if line.startswith("  ") and not line.startswith("    "):
                errors.append(
                    f"line {i + 1}: looks like a category line but is missing its "
                    f"trailing colon, has the wrong indentation, or contains characters "
                    f"outside A-Z/a-z/space: {line!r}"
                )
                i += 1
                continue

            errors.append(f"line {i + 1}: does not match any valid changelog line format: {line!r}")
            i += 1

    return errors


def main() -> int:
    if len(sys.argv) != 2:
        print("usage: validate-changelog.py <path-to-changelog.txt>", file=sys.stderr)
        return 2

    path = Path(sys.argv[1])
    try:
        text = path.read_text(encoding="utf-8")
    except OSError as error:
        print(f"error: could not read {path}: {error}", file=sys.stderr)
        return 1

    errors = validate(text)
    if errors:
        print(f"{path}: {len(errors)} changelog format problem(s):", file=sys.stderr)
        for error in errors:
            print(f"  - {error}", file=sys.stderr)
        return 1

    print(f"{path}: OK, matches https://lua-api.factorio.com/latest/auxiliary/changelog-format.html")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
