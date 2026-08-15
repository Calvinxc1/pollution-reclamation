#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

python3 - <<'PY'
import json
import re
from pathlib import Path

info = json.load(open("src/info.json", encoding="utf-8"))
version = info["version"]

for path in sorted(Path("tests/fixtures").rglob("info.json")):
    json.loads(path.read_text(encoding="utf-8"))

if not re.fullmatch(r"\d+\.\d+\.\d+", version):
    raise SystemExit(f"src/info.json version must be MAJOR.MINOR.PATCH: {version}")

changelog = Path("src/changelog.txt").read_text(encoding="utf-8")
match = re.search(r"(?m)^Version:\s*(\d+\.\d+\.\d+)\s*$", changelog)
if not match:
    raise SystemExit("src/changelog.txt must contain a Factorio changelog Version entry")
if match.group(1) != version:
    raise SystemExit(
        f"src/changelog.txt top version {match.group(1)} does not match src/info.json {version}"
    )

try:
    import yaml
except ImportError:
    pass
else:
    for path in sorted(Path(".governance").rglob("*.yaml")):
        yaml.safe_load(path.read_text(encoding="utf-8"))
PY

python3 -m unittest tests/test_download_factorio_mods.py

while IFS= read -r file; do
  luac -p "$file"
done < <(rg --files -g '*.lua' src tests/fixtures)

# Files under src/control/ are meant to be pure and dependency-injected (no
# direct game/storage/script access) so the same file can load both inside
# Factorio and under a plain Lua interpreter for testing. This is a
# mechanical backstop for that convention: a stray reference wouldn't fail
# at load time, since Lua doesn't resolve globals until they're read, only
# the first time that exact code path executes -- which local tests might
# never hit.
while IFS= read -r file; do
  if grep -n 'game\.\|storage\.\|script\.' "$file"; then
    echo "error: $file references a Factorio-only global (game./storage./script.) -- files under src/control/ are meant to stay pure, see the header comment in that file" >&2
    exit 1
  fi
done < <(rg --files -g '*.lua' src/control)

for test_file in tests/lua/*_test.lua; do
  lua "$test_file"
done

./scripts/factorio-validate.sh
