#!/usr/bin/env bash
# Validates that the mod loads with Space Age absent.
#
# scripts/factorio-validate.sh writes no mod-list.json, so Factorio auto-enables
# every mod it can see, including the Space Age, quality, and elevated-rails
# mods shipped in the game's data directory. That means the normal validation
# path only ever exercises the Space Age branch. This script builds an isolated
# mods directory containing nothing but this mod and pins a mod-list.json that
# disables the expansion, so the base-game branch is covered too.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
mod_name="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1],encoding="utf-8"))["name"])' "$repo_root/src/info.json")"

factorio_bin="${FACTORIO_BIN:-}"
require_factorio="${PR_REQUIRE_FACTORIO:-0}"

skip_or_fail() {
  local status="$1"
  shift
  if [[ "$require_factorio" == "1" ]]; then
    printf '%s\n' "$@" >&2
    exit "$status"
  fi
  printf 'Skipping base-game validation: %s\n' "$*" >&2
  printf 'Set PR_REQUIRE_FACTORIO=1 to make this a hard failure.\n' >&2
  exit 0
}

if [[ -z "$factorio_bin" ]]; then
  if command -v factorio >/dev/null 2>&1; then
    factorio_bin="$(command -v factorio)"
  elif [[ -x "$HOME/Games/steam/steamapps/common/Factorio/bin/x64/factorio" ]]; then
    factorio_bin="$HOME/Games/steam/steamapps/common/Factorio/bin/x64/factorio"
  else
    skip_or_fail 127 "Factorio executable not found." "" \
      "Set FACTORIO_BIN to your Factorio executable, for example:" \
      '  FACTORIO_BIN="/path/to/factorio/bin/x64/factorio" ./scripts/factorio-validate-base-game.sh'
  fi
fi

if [[ ! -x "$factorio_bin" ]]; then
  echo "FACTORIO_BIN is not executable: $factorio_bin" >&2
  exit 127
fi

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

mods_dir="$tmp_dir/mods"
config_dir="$tmp_dir/config"
write_dir="$tmp_dir/write"
mkdir -p "$mods_dir" "$config_dir" "$write_dir"

ln -s "$repo_root/src" "$mods_dir/$mod_name"

python3 - "$mods_dir/mod-list.json" "$mod_name" <<'PY'
import json
import sys

path, mod_name = sys.argv[1], sys.argv[2]
mods = [
    {"name": "base", "enabled": True},
    {"name": "elevated-rails", "enabled": False},
    {"name": "quality", "enabled": False},
    {"name": "space-age", "enabled": False},
    {"name": mod_name, "enabled": True},
]
with open(path, "w", encoding="utf-8") as handle:
    json.dump({"mods": mods}, handle, indent=2)
PY

cat > "$config_dir/config.ini" <<EOF
[path]
read-data=__PATH__executable__/../../data
write-data=$write_dir

[general]
locale=en
EOF

save_path="$tmp_dir/${mod_name}-base-game-validation.zip"
log_path="$tmp_dir/factorio-base-game-validation.log"

echo "Factorio: $factorio_bin"
echo "Mods:     $mods_dir (Space Age disabled)"
echo "Save:     $save_path"
echo

set +e
"$factorio_bin" \
  --config "$config_dir/config.ini" \
  --mod-directory "$mods_dir" \
  --create "$save_path" \
  >"$log_path" 2>&1
status=$?
set -e

cat "$log_path"

if [[ $status -ne 0 ]]; then
  echo "Base-game validation failed with exit code $status" >&2
  exit "$status"
fi

if [[ ! -f "$save_path" ]]; then
  echo "Base-game validation did not produce expected save: $save_path" >&2
  exit 1
fi

# Guard against the expansion sneaking back in and making this a second Space
# Age run, which would silently retire the coverage this script exists for.
if grep -q "Checksum of space-age" "$log_path"; then
  echo "Space Age loaded during base-game validation; mod-list.json was not honored." >&2
  exit 1
fi

echo "Base-game validation passed (Space Age absent)."
