--!nonstrict
-- OpenVPN3 Manager: Status bar widget showing current VPN connection status

local autoRefresh = noctalia.getConfig("auto_refresh")
local showIp = noctalia.getConfig("show_ip")

local isConnected = noctalia.state.get("vpn_connected") or false
local activeProfile = noctalia.state.get("vpn_profile") or ""
local vpnIp = noctalia.state.get("vpn_ip") or ""

local function render()
  if isConnected then
    barWidget.setGlyph("shield-check")
    local text = activeProfile ~= "" and `VPN: {activeProfile}` or "VPN: Connected"
    barWidget.setText(text)

    local tooltip = `Connected to {activeProfile}`
    if showIp and vpnIp ~= "" then
      tooltip = `{tooltip}\nIP: {vpnIp}`
    end
    barWidget.setTooltip(tooltip)
  else
    barWidget.setGlyph("shield-off")
    barWidget.setText("VPN: Offline")
    barWidget.setTooltip("VPN Manager")
  end
end

-- Initial render
render()

-- Live updates from shared state
noctalia.state.watch("vpn_connected", function(value)
  isConnected = value == true
  render()
end)

noctalia.state.watch("vpn_profile", function(value)
  activeProfile = value or ""
  render()
end)

noctalia.state.watch("vpn_ip", function(value)
  vpnIp = value or ""
  render()
end)

function update()
  if autoRefresh then
    noctalia.setUpdateInterval(5000)
  else
    noctalia.setUpdateInterval(30000)
  end
end

function onClick()
  noctalia.notify(noctalia.tr("title"), noctalia.tr("panel_opening"))
end

function onIpc(event, payload)
  if event == "connect" then
    noctalia.state.set("vpn_profile", payload)
    noctalia.state.set("vpn_connected", true)
    noctalia.notify(noctalia.tr("title"), `Connecting to {payload}...`)
  elseif event == "disconnect" then
    noctalia.state.set("vpn_connected", false)
    noctalia.state.set("vpn_profile", "")
    noctalia.notify(noctalia.tr("title"), "Disconnecting...")
  elseif event == "refresh" then
    noctalia.state.set("vpn_connected", noctalia.state.get("vpn_connected"))
  end
end
