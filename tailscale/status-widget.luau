-- A compact Tailnet status indicator. Click it to open the manager panel.

local checking = false
local connected = false
local detail = "Checking Tailscale status…"

local function render()
  barWidget.setImage(connected and "assets/tailscale-connected.svg" or "assets/tailscale-disconnected.svg", false, 18, 18)
  barWidget.setText("")
  barWidget.setTooltip({ { "Tailscale", detail } })
end

-- Panel-initiated refreshes and actions publish this key as soon as their
-- status command finishes, so the icon does not have to wait for this widget's
-- next scheduled poll.
noctalia.state.watch("connected", function(value)
  if type(value) == "boolean" then
    connected = value
    detail = connected and "Connected" or "Not connected"
    render()
  end
end)

local function refresh()
  if checking then return end
  checking = true

  if not noctalia.commandExists("tailscale") then
    checking = false
    connected = false
    detail = "Tailscale is not installed"
    noctalia.state.set("connected", false)
    render()
    return
  end

  local accepted = noctalia.runAsync({ "tailscale", "status", "--json" }, function(result)
    checking = false
    if result.exitCode ~= 0 then
      connected = false
      detail = "Tailscale is unavailable"
      noctalia.state.set("connected", false)
      render()
      return
    end

    local ok, status = pcall(noctalia.json.decode, result.stdout)
    connected = ok and type(status) == "table" and status.BackendState == "Running"
    detail = connected and "Connected" or "Not connected"
    noctalia.state.set("connected", connected)
    render()
  end)

  if not accepted then
    checking = false
    connected = false
    detail = "Could not check Tailscale"
    noctalia.state.set("connected", false)
    render()
  end
end

function update()
  noctalia.setUpdateInterval(10 * 1000)
  refresh()
end

function onClick()
  noctalia.togglePanel("abulujayn/tailscale:manager")
end
