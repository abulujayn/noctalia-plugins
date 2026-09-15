#!/usr/bin/env bash
set -euo pipefail

plugin_dir="$(cd "$(dirname "$0")/.." && pwd)"

python3 - "$plugin_dir/plugin.toml" <<'PY'
import sys
import tomllib

with open(sys.argv[1], "rb") as f:
    manifest = tomllib.load(f)

assert manifest["id"] == "abulujayn/tailscale-panel"
assert manifest["dependencies"] == ["tailscale"]
assert manifest["panel"][0]["id"] == "panel"
assert manifest["panel"][0]["entry"] == "panel.luau"
PY

for required in \
  'tailscale", "status", "--json' \
  'tailscale", "up' \
  'tailscale", "down' \
  'tailscale", "set", "--exit-node="' \
  'noctalia.copyToClipboard' \
  'function onOpen'; do
  grep -Fq "$required" "$plugin_dir/panel.luau"
done

echo "static plugin checks passed"
