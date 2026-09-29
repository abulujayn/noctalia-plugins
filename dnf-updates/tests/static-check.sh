#!/usr/bin/env bash
set -euo pipefail

plugin_dir="$(cd "$(dirname "$0")/.." && pwd)"

python3 - "$plugin_dir/plugin.toml" <<'PY'
import sys
import tomllib

with open(sys.argv[1], "rb") as f:
    manifest = tomllib.load(f)

assert manifest["id"] == "abulujayn/dnf-updates"
assert manifest["dependencies"] == ["dnf", "rpm"]
assert manifest["widget"][0]["id"] == "count"
assert manifest["widget"][0]["entry"] == "widget.luau"
assert manifest["panel"][0]["id"] == "updates"
assert manifest["panel"][0]["entry"] == "panel.luau"
assert manifest["panel"][0]["placement"] == "attached"
assert manifest["panel"][0]["open_near_click"] is True
settings = {setting["key"]: setting for setting in manifest["widget"][0]["setting"]}
assert settings["glyph"]["type"] == "glyph"
assert settings["glyph"]["default"] == "package"
assert settings["refresh_minutes"]["type"] == "int"
assert settings["refresh_minutes"]["min"] == 5
assert settings["refresh_minutes"]["max"] == 1440
PY

for required in \
  '"dnf", "check-update", "--quiet"' \
  'result.exitCode == 100' \
  'noctalia.getConfig("glyph")' \
  'noctalia.getConfig("refresh_minutes")' \
  'barWidget.setGlyph(glyph)' \
  'noctalia.togglePanel("abulujayn/dnf-updates:updates")' \
  'function onClick()'; do
  grep -Fq "$required" "$plugin_dir/widget.luau"
done

test -f "$plugin_dir/translations/en.json"
test -f "$plugin_dir/panel.luau"
grep -Fq '"dnf", "check-update", "--quiet"' "$plugin_dir/panel.luau"
grep -Fq '"rpm", "-q", "--qf"' "$plugin_dir/panel.luau"
grep -Fq '"Current: " .. package.current' "$plugin_dir/panel.luau"
grep -Fq '"Latest: " .. package.latest' "$plugin_dir/panel.luau"
grep -Fq 'function onOpen()' "$plugin_dir/panel.luau"
if rg -n '^[[:space:]]*--' "$plugin_dir/widget.luau"; then
  exit 1
fi
if rg -n '^[[:space:]]*--' "$plugin_dir/panel.luau"; then
  exit 1
fi

echo "static plugin checks passed"
