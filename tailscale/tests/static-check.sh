#!/usr/bin/env bash
set -euo pipefail

plugin_dir="$(cd "$(dirname "$0")/.." && pwd)"

python3 - "$plugin_dir/plugin.toml" <<'PY'
import sys
import tomllib

with open(sys.argv[1], "rb") as f:
    manifest = tomllib.load(f)

assert manifest["id"] == "abulujayn/tailscale"
assert manifest["dependencies"] == ["tailscale"]
assert manifest["panel"][0]["id"] == "manager"
assert manifest["panel"][0]["entry"] == "panel.luau"
assert manifest["widget"][0]["id"] == "status"
assert manifest["widget"][0]["entry"] == "status-widget.luau"
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

for required in \
  'assets/tailscale-connected.svg' \
  'assets/tailscale-disconnected.svg' \
  'noctalia.state.watch("tailscale_status"' \
  '"This device"' \
  '"Exit node"' \
  'noctalia.togglePanel("abulujayn/tailscale:manager")'; do
  grep -Fq "$required" "$plugin_dir/status-widget.luau"
done

grep -Fq 'noctalia.state.set("tailscale_status"' "$plugin_dir/panel.luau"
grep -Fq '"Connected to " .. tailnetDomain(state.status)' "$plugin_dir/panel.luau"
grep -Fq '"Disconnected from tailnet"' "$plugin_dir/panel.luau"

test -f "$plugin_dir/assets/tailscale-connected.svg"
test -f "$plugin_dir/assets/tailscale-disconnected.svg"

echo "static plugin checks passed"
