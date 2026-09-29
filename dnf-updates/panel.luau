local updates = {}
local loading = false
local known = false
local status = "Checking for updates…"
local refresh

local function parseUpdates(output)
  local packages = {}
  for line in output:gmatch("[^\r\n]+") do
    local name, version, repository = line:match("^(%S+)%s+(%S+)%s+(%S+)%s*$")
    if name then
      table.insert(packages, { name = name, latest = version, repository = repository, current = "Not installed" })
    end
  end
  return packages
end

local function loadInstalledVersions(packages, onDone)
  if #packages == 0 or not noctalia.commandExists("rpm") then
    onDone()
    return
  end

  local argv = { "rpm", "-q", "--qf", "%{NAME}.%{ARCH} %{VERSION}-%{RELEASE}\\n" }
  for _, package in ipairs(packages) do
    table.insert(argv, package.name)
  end

  local accepted = noctalia.runAsync(argv, function(result)
    local versions = {}
    for line in result.stdout:gmatch("[^\r\n]+") do
      local name, version = line:match("^(%S+)%s+(.+)$")
      if name and version then
        versions[name] = version
      end
    end
    for _, package in ipairs(packages) do
      package.current = versions[package.name] or "Not installed"
    end
    onDone()
  end, 60000)

  if not accepted then
    onDone()
  end
end

local function publish()
  noctalia.state.set("dnf_updates", {
    known = known,
    status = status,
    packages = updates,
  })
end

local function updateRows()
  local rows = {}
  for _, package in ipairs(updates) do
    table.insert(rows, ui.column({ key = package.name, gap = 3, padding = 11, radius = 9, fill = "surface_variant/0.45" }, {
      ui.row({ align = "center", justify = "space_between", gap = 12 }, {
        ui.label({ text = package.name, fontWeight = "semibold", flexGrow = 1, maxLines = 1 }),
        ui.label({ text = package.repository, color = "on_surface_variant", fontSize = 12, maxLines = 1 }),
      }),
      ui.label({ text = "Current: " .. package.current, color = "on_surface_variant", fontSize = 12, maxLines = 1 }),
      ui.label({ text = "Latest: " .. package.latest, color = "primary", fontSize = 12, maxLines = 1 }),
    }))
  end
  return rows
end

function render()
  local body = {
    ui.row({ align = "center", justify = "space_between", gap = 12 }, {
      ui.column({ gap = 3, flexGrow = 1 }, {
        ui.label({ text = "DNF Updates", fontSize = 20, fontWeight = "bold" }),
        ui.label({ text = status, color = "on_surface_variant" }),
      }),
      ui.row({ gap = 4 }, {
        ui.button({ glyph = "refresh", variant = "ghost", tooltip = "Refresh", enabled = not loading, onClick = refresh }),
        ui.button({ glyph = "close", variant = "ghost", tooltip = "Close", onClick = function() panel.close() end }),
      }),
    }),
    ui.separator({ spacing = 2 }),
  }

  if loading then
    table.insert(body, ui.label({ text = "Checking for updates…", color = "on_surface_variant" }))
  elseif known and #updates == 0 then
    table.insert(body, ui.label({ text = "Your system is up to date.", color = "on_surface_variant" }))
  elseif known then
    table.insert(body, ui.label({ text = tostring(#updates) .. (#updates == 1 and " update available" or " updates available"), fontWeight = "semibold" }))
    table.insert(body, ui.scroll({ gap = 8, flexGrow = 1 }, updateRows()))
  else
    table.insert(body, ui.label({ text = status, color = "error" }))
  end

  panel.render(ui.column({ flexGrow = 1, align = "stretch", gap = 14 }, body))
end

refresh = function()
  if loading then return end
  loading = true
  status = "Checking for updates…"
  render()

  if not noctalia.commandExists("dnf") then
    loading = false
    known = false
    updates = {}
    status = "DNF is not installed"
    publish()
    render()
    return
  end

  local accepted = noctalia.runAsync({ "dnf", "check-update", "--quiet" }, function(result)
    if result.exitCode == 100 then
      updates = parseUpdates(result.stdout)
      known = true
      status = tostring(#updates) .. (#updates == 1 and " update available" or " updates available")
      loadInstalledVersions(updates, function()
        loading = false
        publish()
        render()
      end)
      return
    elseif result.exitCode == 0 then
      updates = {}
      known = true
      status = "System is up to date"
    else
      updates = {}
      known = false
      status = "Could not check for updates"
    end
    loading = false
    publish()
    render()
  end, 60000)

  if not accepted then
    loading = false
    known = false
    updates = {}
    status = "Could not start DNF"
    publish()
    render()
  end
end

function onOpen()
  refresh()
end
