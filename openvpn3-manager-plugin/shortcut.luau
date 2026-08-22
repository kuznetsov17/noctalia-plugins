--!nonstrict
-- OpenVPN3 Manager: Quick toggle shortcut for Control Center

local isConnected = noctalia.state.get("vpn_connected") == true
local activeProfile = noctalia.state.get("vpn_profile") or ""

local function render()
  if isConnected then
    shortcut.setLabel(if activeProfile ~= "" then `VPN: {activeProfile}` else "VPN: On")
    shortcut.setIcon("shield-check")
    shortcut.setActive(true)
  else
    shortcut.setLabel("VPN: Off")
    shortcut.setIcon("shield-off")
    shortcut.setActive(false)
  end
  shortcut.setEnabled(true)
end

render()

function onClick()
  isConnected = not isConnected
  noctalia.state.set("vpn_connected", isConnected)

  if isConnected and activeProfile == "" then
    noctalia.state.set("vpn_profile", "Default")
  elseif not isConnected then
    noctalia.state.set("vpn_profile", "")
  end
end

-- Watch for external connection changes
noctalia.state.watch("vpn_connected", function(value)
  isConnected = value == true
  render()
end)

noctalia.state.watch("vpn_profile", function(value)
  activeProfile = value or ""
  render()
end)
