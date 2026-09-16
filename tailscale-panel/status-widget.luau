-- A compact Tailnet status indicator. Click it to open the manager panel.

local checking = false
local connected = false
local detail = "Checking Tailscale status…"

local function render()
  barWidget.setGlyph("brand-tailscale")
  barWidget.setText("")
  -- Default icon colour while connected; a deliberately muted role otherwise.
  if connected then
    barWidget.setGlyphColor("on_surface")
  else
    barWidget.setGlyphColor("on_surface_variant", "script")
  end
  barWidget.setTooltip({ { "Tailscale", detail } })
end

local function refresh()
  if checking then return end
  checking = true

  if not noctalia.commandExists("tailscale") then
    checking = false
    connected = false
    detail = "Tailscale is not installed"
    render()
    return
  end

  local accepted = noctalia.runAsync({ "tailscale", "status", "--json" }, function(result)
    checking = false
    if result.exitCode ~= 0 then
      connected = false
      detail = "Tailscale is unavailable"
      render()
      return
    end

    local ok, status = pcall(noctalia.json.decode, result.stdout)
    connected = ok and type(status) == "table" and status.BackendState == "Running"
    detail = connected and "Connected" or "Not connected"
    render()
  end)

  if not accepted then
    checking = false
    connected = false
    detail = "Could not check Tailscale"
    render()
  end
end

function update()
  noctalia.setUpdateInterval(10 * 1000)
  refresh()
end

function onClick()
  noctalia.togglePanel("abulujayn/tailscale-panel:manager")
end
