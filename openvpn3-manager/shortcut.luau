--!nonstrict
-- OpenVPN3 Manager — control-center quick tile.
--
-- Holds no VPN logic: it mirrors the service's "status" and writes to the
-- "command" channel, so the toggle works with no widget placed on a bar.

local PANEL_ID = "kuznetsov17/openvpn3-manager:manager"

local status = {}
local seq = 0

local function send(action)
  seq += 1
  noctalia.state.set("command", { action = action, nonce = `shortcut:{seq}` })
end

local function apply(next)
  status = if type(next) == "table" then next else {}

  local label
  if not status.available then
    label = noctalia.tr("error.not_installed")
  elseif status.connected then
    local profile = status.profile or ""
    label = if profile ~= "" then profile else noctalia.tr("state.connected")
  elseif status.busy then
    label = noctalia.tr("state.connecting")
  else
    label = noctalia.tr("shortcut.label")
  end

  shortcut.setLabel(label)
  shortcut.setIcon("shield-check", "shield-off")
  shortcut.setActive(status.connected == true)
  shortcut.setEnabled(status.available == true and not status.busy)
end

function onClick()
  send("toggle")
end

function onRightClick()
  noctalia.togglePanel(PANEL_ID)
end

apply(noctalia.state.get("status"))
noctalia.state.watch("status", apply)
