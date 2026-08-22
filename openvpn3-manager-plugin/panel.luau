--!nonstrict
-- OpenVPN3 Manager Panel: Manage VPN connections

local isConnected = noctalia.state.get("vpn_connected") or false
local activeProfile = noctalia.state.get("vpn_profile") or ""
local vpnIp = noctalia.state.get("vpn_ip") or ""
local availableProfiles = { "MyVPN", "WorkVPN", "PublicVPN" }
local selectedProfileIndex = 0
local autoConnect = false

local function section(title, control)
  return ui.column({ gap = 8 }, {
    ui.label({ text = title, fontWeight = "medium", color = "on_surface_variant" }),
    control,
  })
end

local function render()
  local statusColor = isConnected and "primary" or "error"
  local statusText = isConnected and `✓ Connected to {activeProfile}` or "✗ Not connected"

  panel.render(ui.column({ flexGrow = 1, gap = 16 }, {
    -- Header
    ui.row({ align = "center", justify = "space_between", gap = 8 }, {
      ui.label({ text = "OpenVPN3 Manager", fontSize = 16, fontWeight = "bold", color = "on_surface", flexGrow = 1 }),
      ui.button({ glyph = "close", onClick = "onCloseClicked" }),
    }),

    -- Content
    ui.scroll({ flexGrow = 1, gap = 16 }, {
      section("Status", ui.row({ gap = 8, align = "center" }, {
        ui.label({ text = isConnected and "shield-check" or "shield-off", fontSize = 14 }),
        ui.label({ text = statusText, color = statusColor, flexGrow = 1 }),
      })),

      (isConnected and vpnIp ~= "") and section("Connection Details", ui.column({ gap = 8 }, {
        ui.row({ gap = 12, align = "center" }, {
          ui.label({ text = "IP Address:", color = "on_surface_variant", width = 80 }),
          ui.label({ text = vpnIp }),
        }),
      })) or nil,

      section("Profile", ui.select({
        options = availableProfiles,
        selectedIndex = selectedProfileIndex,
        onChange = "onProfileSelected",
      })),

      section("Connection", ui.column({ gap = 8, align = "stretch" }, {
        isConnected and ui.button({
          text = "Disconnect",
          onClick = "onDisconnectClicked",
        }) or ui.button({
          text = "Connect",
          onClick = "onConnectClicked",
        }),
      })),

      section("Options", ui.row({ gap = 12, align = "center" }, {
        ui.toggle({ checked = autoConnect, onChange = "onAutoConnectToggle" }),
        ui.label({ text = "Auto-connect on startup", flexGrow = 1 }),
      })),
    }),
  }))
end

-- Initial render
function onOpen(_context)
  render()
end

-- Watch for state changes
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

-- Callbacks
function onProfileSelected(index, _text)
  selectedProfileIndex = tonumber(index) or 0
end

function onConnectClicked()
  local profile = availableProfiles[selectedProfileIndex + 1]
  if profile then
    noctalia.state.set("vpn_profile", profile)
    noctalia.state.set("vpn_connected", true)
    noctalia.notify(noctalia.tr("title"), `Connecting to {profile}...`)
  end
end

function onDisconnectClicked()
  noctalia.state.set("vpn_connected", false)
  noctalia.state.set("vpn_profile", "")
  noctalia.notify(noctalia.tr("title"), "Disconnecting...")
end

function onAutoConnectToggle(value)
  autoConnect = value == "true"
end

function onCloseClicked()
  panel.close()
end
