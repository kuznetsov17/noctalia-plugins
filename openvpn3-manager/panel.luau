--!nonstrict
-- OpenVPN3 Manager — management panel.
--
-- Thin client over the service's "status" / "command" channels: pick a profile,
-- connect or disconnect, and read the live session details.
--
-- Open it with: noctalia msg panel-toggle kuznetsov17/openvpn3-manager:manager

local status = {}
local selected = 0 -- 0-based, matches ui.select
local seq = 0

local function send(action, profile)
  seq += 1
  noctalia.state.set("command", { action = action, profile = profile, nonce = `panel:{seq}` })
end

local function human(n)
  n = tonumber(n) or 0
  local units = { "B", "KiB", "MiB", "GiB", "TiB" }
  local i = 1
  while n >= 1024 and i < #units do
    n /= 1024
    i += 1
  end
  return if i == 1 then `{math.floor(n)} {units[i]}` else string.format("%.1f %s", n, units[i])
end

local function profileNames()
  local names = {}
  for _, p in ipairs(status.profiles or {}) do
    table.insert(names, p.name)
  end
  return names
end

local function section(title, control)
  return ui.column({ gap = 8, align = "stretch" }, {
    ui.label({ text = title, fontWeight = "medium", color = "on_surface_variant" }),
    control,
  })
end

local function detailRow(key, value)
  return ui.row({ gap = 12, align = "center" }, {
    ui.label({ text = key, color = "on_surface_variant", width = 96 }),
    ui.label({ text = value, flexGrow = 1 }),
  })
end

local function render()
  local names = profileNames()
  local body = {}

  -- Status line.
  local statusText, statusColor
  if not status.available then
    statusText, statusColor = noctalia.tr("error.not_installed"), "error"
  elseif status.connected then
    statusText = noctalia.tr("tooltip.connected", { profile = status.profile or "" })
    statusColor = "primary"
  elseif status.busy then
    statusText, statusColor = noctalia.tr("state.connecting"), "secondary"
  else
    statusText, statusColor = noctalia.tr("state.disconnected"), "on_surface_variant"
  end

  table.insert(body, section(noctalia.tr("section.status"), ui.row({ gap = 8, align = "center" }, {
    ui.glyph({ name = if status.connected then "shield-check" else "shield-off" }),
    ui.label({ text = statusText, color = statusColor, flexGrow = 1 }),
  })))

  -- Live session details.
  if status.connected then
    local details = {}
    if (status.statusText or "") ~= "" then
      table.insert(details, detailRow(noctalia.tr("field.state"), status.statusText))
    end
    if (status.ip or "") ~= "" then
      table.insert(details, detailRow(noctalia.tr("field.ip"), status.ip))
    end
    if (status.device or "") ~= "" then
      table.insert(details, detailRow(noctalia.tr("field.device"), status.device))
    end
    table.insert(details, detailRow(noctalia.tr("field.received"), human(status.bytesIn)))
    table.insert(details, detailRow(noctalia.tr("field.sent"), human(status.bytesOut)))
    table.insert(body, section(noctalia.tr("section.details"), ui.column({ gap = 8, align = "stretch" }, details)))
  end

  -- Profile picker. Hidden while connected: the session dictates the profile.
  if not status.connected then
    if #names > 0 then
      table.insert(body, section(noctalia.tr("section.profile"), ui.select({
        options = names,
        selectedIndex = math.min(selected, #names - 1),
        onChange = "onProfileSelected",
      })))
    else
      table.insert(body, section(noctalia.tr("section.profile"), ui.label({
        text = noctalia.tr("error.no_profile"),
        color = "on_surface_variant",
      })))
    end
  end

  -- Actions.
  local action
  if status.connected then
    action = ui.button({ text = noctalia.tr("action.disconnect"), onClick = "onDisconnect" })
  else
    action = ui.button({
      text = noctalia.tr("action.connect"),
      onClick = "onConnect",
      enabled = status.available == true and not status.busy and #names > 0,
    })
  end

  table.insert(body, ui.column({ gap = 8, align = "stretch" }, {
    action,
    ui.button({ text = noctalia.tr("action.refresh"), onClick = "onRefresh" }),
  }))

  if (status.error or "") ~= "" then
    table.insert(body, ui.label({ text = status.error, color = "error" }))
  end

  panel.render(ui.column({ flexGrow = 1, gap = 16, align = "stretch" }, {
    ui.row({ align = "center", justify = "space_between", gap = 8 }, {
      ui.label({
        text = noctalia.tr("title"),
        fontSize = 16,
        fontWeight = "bold",
        color = "on_surface",
        flexGrow = 1,
      }),
      ui.button({ glyph = "close", onClick = "onCloseClicked" }),
    }),
    ui.scroll({ flexGrow = 1, gap = 16, align = "stretch" }, body),
  }))
end

function onOpen(_context)
  status = noctalia.state.get("status") or {}
  send("refresh")
  render()
end

function onProfileSelected(index, _text)
  selected = tonumber(index) or 0
  render()
end

function onConnect()
  local names = profileNames()
  send("connect", names[selected + 1])
end

function onDisconnect()
  send("disconnect")
end

function onRefresh()
  send("refresh")
end

function onCloseClicked()
  panel.close()
end

noctalia.state.watch("status", function(next)
  status = if type(next) == "table" then next else {}
  render()
end)
