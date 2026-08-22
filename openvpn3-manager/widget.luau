--!nonstrict
-- OpenVPN3 Manager — bar widget (thin presentation client).
--
-- All openvpn3 handling lives in the [[service]] (vpn_service.luau). This entry
-- only mirrors the published "status" and drives the service through the
-- "command" channel.
--
--   Left click   — connect / disconnect
--   Right click  — open the manager panel
--
-- IPC:
--   noctalia msg plugin kuznetsov17/openvpn3-manager:status focused connect "Profile"
--   noctalia msg plugin kuznetsov17/openvpn3-manager:status focused disconnect

local PANEL_ID = "kuznetsov17/openvpn3-manager:manager"

local status = {}
local seq = 0

local function send(action, profile)
  seq += 1
  noctalia.state.set("command", { action = action, profile = profile, nonce = `widget:{seq}` })
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

local function apply(next)
  status = if type(next) == "table" then next else {}

  if not status.available then
    barWidget.setGlyph("shield-off")
    barWidget.setText("")
    barWidget.setGlyphColor("on_surface_variant")
    barWidget.setTooltip(noctalia.tr("error.not_installed"))
    barWidget.setVisible(true)
    return
  end

  local showLabel = noctalia.getConfig("show_label")

  if status.connected then
    local profile = status.profile or ""
    barWidget.setGlyph("shield-check")
    barWidget.setGlyphColor("primary")
    barWidget.setText(if showLabel and profile ~= "" then profile else "")
    barWidget.setVisible(true)

    local lines = { noctalia.tr("tooltip.connected", { profile = profile }) }
    if (status.ip or "") ~= "" then
      table.insert(lines, `{noctalia.tr("field.ip")}: {status.ip}`)
    end
    if (status.device or "") ~= "" then
      table.insert(lines, `{noctalia.tr("field.device")}: {status.device}`)
    end
    if noctalia.getConfig("show_traffic") then
      table.insert(lines, `↓ {human(status.bytesIn)}   ↑ {human(status.bytesOut)}`)
    end
    barWidget.setTooltip(table.concat(lines, "\n"))
    return
  end

  if status.busy then
    barWidget.setGlyph("shield")
    barWidget.setGlyphColor("secondary")
    barWidget.setText(if showLabel then noctalia.tr("state.connecting") else "")
    barWidget.setTooltip(noctalia.tr("state.connecting"))
    barWidget.setVisible(true)
    return
  end

  barWidget.setGlyph("shield-off")
  barWidget.setGlyphColor("on_surface")
  barWidget.setText("")
  barWidget.setTooltip(noctalia.tr("tooltip.disconnected"))
  barWidget.setVisible(not noctalia.getConfig("hide_when_disconnected"))
end

function onClick()
  if not status.available or status.busy then return end
  send("toggle")
end

function onRightClick()
  noctalia.togglePanel(PANEL_ID)
end

function onIpc(event, payload)
  send(event, payload)
end

-- Reflect whatever the service last published, then track live changes.
apply(noctalia.state.get("status"))
noctalia.state.watch("status", apply)
