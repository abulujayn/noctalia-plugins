-- Tailscale Panel for Noctalia.
-- All Tailscale calls use argv form so device data is never evaluated by a shell.

-- Manifest entry: abulujayn/tailscale:manager

local state = {
  loading = false,
  action = nil,
  error = nil,
  status = nil,
  connectionNotice = nil,
}

local function trim(value)
  return (value or ""):match("^%s*(.-)%s*$")
end

local function displayName(device)
  local name = device.DNSName or device.HostName or device.Name or "Unknown device"
  return name:gsub("%.$", "")
end

local function deviceIp(device)
  if device.TailscaleIPs and #device.TailscaleIPs > 0 then
    return device.TailscaleIPs[1]
  end
  return "No Tailscale IP"
end

local function isOnline(device)
  return device.Online == true
end

local function tailnetDomain(status)
  local dnsName = status and status.Self and status.Self.DNSName
  if type(dnsName) ~= "string" then return "tailnet" end
  local domain = dnsName:match("^[^.]+%.(.+)$")
  return domain and domain:gsub("%.$", "") or "tailnet"
end

local function refresh()
  if state.loading then return end

  state.loading = true
  state.error = nil
  render()

  local accepted = noctalia.runAsync({ "tailscale", "status", "--json" }, function(result)
    state.loading = false
    if result.exitCode ~= 0 then
      state.status = nil
      state.error = trim(result.stderr) ~= "" and trim(result.stderr) or "Could not read Tailscale status."
      state.connectionNotice = nil
      noctalia.state.set("tailscale_status", {})
      render()
      return
    end

    local ok, decoded = pcall(noctalia.json.decode, result.stdout)
    if not ok or type(decoded) ~= "table" then
      state.status = nil
      state.error = "Tailscale returned an unreadable status response."
    else
      state.status = decoded
    end
    noctalia.state.set("tailscale_status", state.status or {})
    local notice = state.connectionNotice
    state.connectionNotice = nil
    local isConnected = state.status ~= nil and state.status.BackendState == "Running"
    if notice == "connect" and isConnected then
      noctalia.notify("Tailscale", "Connected to " .. tailnetDomain(state.status))
    elseif notice == "disconnect" and not isConnected then
      noctalia.notify("Tailscale", "Disconnected from tailnet")
    end
    render()
  end)

  if not accepted then
    state.loading = false
    state.error = "Could not start the Tailscale status command."
    state.connectionNotice = nil
    noctalia.state.set("tailscale_status", {})
    render()
  end
end

local function runAction(label, argv, connectionNotice)
  if state.loading or state.action then return end

  state.action = label
  state.error = nil
  render()

  local accepted = noctalia.runAsync(argv, function(result)
    state.action = nil
    if result.exitCode ~= 0 then
      state.error = trim(result.stderr) ~= "" and trim(result.stderr) or (label .. " failed.")
      render()
      return
    end

    state.connectionNotice = connectionNotice
    if connectionNotice == nil then
      noctalia.notify("Tailscale", label .. " complete.")
    end
    refresh()
  end)

  if not accepted then
    state.action = nil
    state.error = "Could not start " .. label:lower() .. "."
    render()
  end
end

local function copyIp(ip)
  if ip == "No Tailscale IP" then return end
  if noctalia.copyToClipboard(ip, "text/plain") then
    noctalia.notify("Tailscale", "Copied " .. ip)
  else
    noctalia.notifyError("Tailscale", "Could not copy the IP address.")
  end
end

local function exitNodeId()
  if not state.status or not state.status.ExitNodeStatus then return "" end
  return state.status.ExitNodeStatus.ID or ""
end

local function statusLabel()
  if not state.status then return "Status unavailable" end
  local backend = state.status.BackendState or "Unknown"
  if backend == "Running" then return "Connected" end
  return backend
end

local function deviceRows()
  local rows = {}
  if not state.status then return rows end

  local devices = {}
  if state.status.Self then table.insert(devices, state.status.Self) end
  for _, peer in pairs(state.status.Peer or {}) do table.insert(devices, peer) end
  table.sort(devices, function(a, b) return displayName(a):lower() < displayName(b):lower() end)

  for _, device in ipairs(devices) do
    local ip = deviceIp(device)
    local onlineText = isOnline(device) and "Online" or "Offline"
    local isExitNode = device.ExitNodeOption == true
    local selected = device.ExitNode == true or (exitNodeId() ~= "" and device.ID == exitNodeId())
    local controls = {
      ui.button({ text = "Copy IP", controlSize = "sm", enabled = ip ~= "No Tailscale IP", onClick = function() copyIp(ip) end }),
    }
    if isExitNode then
      table.insert(controls, ui.button({
        text = selected and "Exit node active" or "Use as exit node",
        variant = selected and "secondary" or "outline",
        controlSize = "sm",
        enabled = not selected and state.action == nil,
        onClick = function() runAction("Enable exit node", { "tailscale", "set", "--exit-node=" .. (device.ID or device.StableID or device.DNSName) }) end,
      }))
    end

    table.insert(rows, ui.column({ key = device.ID or displayName(device), gap = 7, padding = 12, radius = 10, fill = "surface_variant/0.45" }, {
      ui.row({ align = "center", justify = "space_between", gap = 10 }, {
        ui.column({ gap = 2, flexGrow = 1 }, {
          ui.label({ text = displayName(device), fontWeight = "bold", maxLines = 1 }),
          ui.label({ text = ip, color = "on_surface_variant", fontSize = 12 }),
        }),
        ui.label({ text = selected and "Exit node" or onlineText, color = selected and "primary" or (isOnline(device) and "primary" or "on_surface_variant"), fontSize = 12 }),
      }),
      ui.row({ gap = 8, align = "center" }, controls),
    }))
  end
  return rows
end

function render()
  local connected = state.status and state.status.BackendState == "Running"
  local headerControls = {
    ui.button({ glyph = "refresh", variant = "ghost", tooltip = "Refresh", enabled = not state.loading and state.action == nil, onClick = refresh }),
    ui.button({ glyph = "close", variant = "ghost", tooltip = "Close", onClick = function() panel.close() end }),
  }
  local body = {
    ui.row({ align = "center", justify = "space_between", gap = 12 }, {
      ui.column({ gap = 3, flexGrow = 1 }, {
        ui.label({ text = "Tailscale", fontSize = 20, fontWeight = "bold" }),
        ui.label({ text = statusLabel(), color = connected and "primary" or "on_surface_variant" }),
      }),
      ui.row({ gap = 4, align = "center" }, headerControls),
    }),
    ui.separator({ spacing = 2 }),
  }

  if state.error then
    table.insert(body, ui.column({ gap = 6, padding = 12, radius = 10, fill = "error_container" }, {
      ui.label({ text = "Tailscale error", color = "on_error_container", fontWeight = "bold" }),
      ui.label({ text = state.error, color = "on_error_container", maxLines = 3 }),
    }))
  end

  table.insert(body, ui.row({ gap = 8 }, {
    ui.button({ text = connected and "Turn off" or "Turn on", glyph = connected and "toggle-left" or "toggle-right", variant = connected and "destructive" or "primary", flexGrow = 1, enabled = not state.loading and state.action == nil, onClick = function()
      if connected then
        runAction("Turn off Tailscale", { "tailscale", "down" }, "disconnect")
      else
        runAction("Turn on Tailscale", { "tailscale", "up" }, "connect")
      end
    end }),
    ui.button({ text = "Disable exit node", glyph = "route-off", variant = "outline", flexGrow = 1, enabled = connected and exitNodeId() ~= "" and state.action == nil, onClick = function() runAction("Disable exit node", { "tailscale", "set", "--exit-node=" }) end }),
  }))

  if state.loading then
    table.insert(body, ui.label({ text = "Loading Tailscale status…", color = "on_surface_variant" }))
  elseif state.action then
    table.insert(body, ui.label({ text = state.action .. "…", color = "on_surface_variant" }))
  end

  table.insert(body, ui.label({ text = "Tailnet devices", fontSize = 15, fontWeight = "bold" }))
  local rows = deviceRows()
  if #rows == 0 and not state.loading then
    table.insert(body, ui.label({ text = "No devices to show. Connect Tailscale, then refresh.", color = "on_surface_variant" }))
  else
    table.insert(body, ui.scroll({ gap = 8, flexGrow = 1 }, rows))
  end

  -- The panel gives its content a fixed-height surface. Let this root consume
  -- that height so the nested ui.scroll receives the remaining space instead
  -- of expanding to its children and losing its scroll viewport.
  panel.render(ui.column({ flexGrow = 1, align = "stretch", gap = 14 }, body))
end

function onOpen()
  if not noctalia.commandExists("tailscale") then
    state.error = "The tailscale command is not installed or is not on PATH."
    noctalia.state.set("tailscale_status", {})
    render()
    return
  end
  refresh()
end
