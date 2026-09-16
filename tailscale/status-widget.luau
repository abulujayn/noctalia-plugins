-- A compact Tailnet status indicator. Click it to open the manager panel.

local checking = false
local connected = false
local detail = "Checking Tailscale status…"
local localIp = nil
local exitNode = nil

local function primaryIp(device)
  if device and device.TailscaleIPs and #device.TailscaleIPs > 0 then
    return device.TailscaleIPs[1]
  end
  return nil
end

local function nameFor(device)
  local name = device.DNSName or device.HostName or device.Name
  return name and name:gsub("%.$", "") or nil
end

local function applyStatus(status)
  connected = type(status) == "table" and status.BackendState == "Running"
  localIp = primaryIp(status and status.Self)
  exitNode = nil

  local selectedId = status and status.ExitNodeStatus and status.ExitNodeStatus.ID
  if selectedId then
    for _, peer in pairs(status.Peer or {}) do
      if peer.ID == selectedId or peer.ExitNode == true then
        local name = nameFor(peer) or selectedId
        local ip = primaryIp(peer)
        exitNode = ip and (name .. " (" .. ip .. ")") or name
        break
      end
    end
    if not exitNode then exitNode = selectedId end
  end
end

local function render()
  barWidget.setImage(connected and "assets/tailscale-connected.svg" or "assets/tailscale-disconnected.svg", false, 18, 18)
  barWidget.setText("")
  local tooltip = { { "Tailscale", detail } }
  if connected then
    table.insert(tooltip, { "This device", localIp or "IP unavailable" })
    table.insert(tooltip, { "Exit node", exitNode or "None selected" })
  end
  barWidget.setTooltip(tooltip)
end

-- Panel-initiated refreshes and actions publish this key as soon as their
-- status command finishes, so the icon does not have to wait for this widget's
-- next scheduled poll.
noctalia.state.watch("tailscale_status", function(value)
  if type(value) == "table" then
    applyStatus(value)
    detail = connected and "Connected" or "Not connected"
    render()
  end
end)

local function refresh()
  if checking then return end
  checking = true

  if not noctalia.commandExists("tailscale") then
    checking = false
    applyStatus({})
    detail = "Tailscale is not installed"
    noctalia.state.set("tailscale_status", {})
    render()
    return
  end

  local accepted = noctalia.runAsync({ "tailscale", "status", "--json" }, function(result)
    checking = false
    if result.exitCode ~= 0 then
      applyStatus({})
      detail = "Tailscale is unavailable"
      noctalia.state.set("tailscale_status", {})
      render()
      return
    end

    local ok, status = pcall(noctalia.json.decode, result.stdout)
    if not ok or type(status) ~= "table" then status = {} end
    applyStatus(status)
    detail = connected and "Connected" or "Not connected"
    noctalia.state.set("tailscale_status", status)
    render()
  end)

  if not accepted then
    checking = false
    applyStatus({})
    detail = "Could not check Tailscale"
    noctalia.state.set("tailscale_status", {})
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
