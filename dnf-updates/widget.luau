local checking = false
local count = 0
local known = false
local status = "Checking for updates…"

local function publish(packages)
  noctalia.state.set("dnf_updates", {
    known = known,
    status = status,
    packages = packages or {},
  })
end

local function updateWidget()
  local glyph = noctalia.getConfig("glyph") or "package"
  local label = noctalia.getConfig("label") or "DNF"
  local showWhenCurrent = noctalia.getConfig("show_when_current") == true

  barWidget.setGlyph(glyph)
  if count > 0 or (showWhenCurrent and known) then
    barWidget.setVisible(true)
    barWidget.setText(label == "" and tostring(count) or label .. " " .. tostring(count))
  else
    barWidget.setVisible(false)
    barWidget.setText("")
  end
  barWidget.setTooltip({ { "Updates", status } })
end

local function countPackages(output)
  local packages = 0
  for line in output:gmatch("[^\r\n]+") do
    if line:match("^%S+%s+%S+%s+%S+%s*$") then
      packages = packages + 1
    end
  end
  return packages
end

local function refresh()
  if checking then return end
  checking = true

  if not noctalia.commandExists("dnf") then
    checking = false
    count = 0
    known = false
    status = "DNF is not installed"
    publish()
    updateWidget()
    return
  end

  local accepted = noctalia.runAsync({ "dnf", "check-update", "--quiet" }, function(result)
    checking = false

    if result.exitCode == 100 then
      local packages = countPackages(result.stdout)
      count = packages
      known = true
      status = tostring(count) .. " available"
      publish()
    elseif result.exitCode == 0 then
      count = 0
      known = true
      status = "System is up to date"
      publish()
    else
      count = 0
      known = false
      status = "Could not check for updates"
      publish()
    end
    updateWidget()
  end, 60000)

  if not accepted then
    checking = false
    count = 0
    known = false
    status = "Could not start DNF"
    publish()
    updateWidget()
  end
end

function update()
  local refreshMinutes = noctalia.getConfig("refresh_minutes") or 30
  noctalia.setUpdateInterval(refreshMinutes * 60 * 1000)
  refresh()
end

function onClick()
  noctalia.togglePanel("abulujayn/dnf-updates:updates")
end
