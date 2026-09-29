# DNF Updates

A configurable Noctalia top-bar widget that displays a package glyph and the number of pending DNF updates. Click it to open an attached panel with each available package’s installed and latest versions.

## Installation and use

Install this plugin through Noctalia, then add `abulujayn/dnf-updates:count` to the desired bar. Configure it from the widget's settings.

## Settings

- **Glyph** — the icon shown with the count; defaults to `package`.
- **Label** — text before the count; defaults to `DNF`. Leave it blank for a count only.
- **Refresh interval** — minutes between checks, from 5 to 1,440; defaults to 30.
- **Show when current** — keeps the widget visible as `DNF 0` when no updates are pending.

## Requirements

- Fedora, RHEL, or another distribution with `dnf` on `PATH`.
- Permission to run `dnf check-update` as the current user. No elevated privileges are requested and the plugin never installs updates.

## Notes

The widget uses `dnf check-update --quiet`. DNF's standard exit code `100` means updates are available; `0` means none are pending. By default it stays hidden while there are no updates or a check cannot complete, so the number is never confused with an error state.
