# Tailscale Panel

Manage a Tailscale connection without leaving Noctalia. The panel shows the local machine and Tailnet peers, lets you copy each device's primary Tailscale IP, and controls the local connection and exit node.

| Plugin | Value |
| --- | --- |
| ID | `abulujayn/tailscale-panel` |
| Panel ID | `manager` |
| Status widget ID | `status` |

## Usage

Open or close the panel:

```sh
noctalia msg panel-toggle abulujayn/tailscale-panel:manager
```

Add the `abulujayn/tailscale-panel:status` widget to a bar for a Tailscale logo indicator. It uses the normal bar icon colour while connected and a muted grey while disconnected; click it to open the manager.

Use **Turn on** to run `tailscale up` and **Turn off** to run `tailscale down`. The device list refreshes from `tailscale status --json`; use **Copy IP** to put a device's primary Tailscale IP on the clipboard. Devices that advertise exit-node capability offer **Use as exit node**. Use **Disable exit node** to return to direct routing.

## Requirements

- `tailscale` must be installed and available on `PATH`.
- Tailscale must already be authenticated for `tailscale up` to connect without an interactive login.

## Notes

The plugin only invokes local `tailscale` commands. It does not send Tailnet data to a third party.
