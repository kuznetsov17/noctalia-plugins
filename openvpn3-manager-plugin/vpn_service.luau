--!nonstrict
-- OpenVPN3 Manager — headless service.
--
-- Owns every `openvpn3` shell-out. The UI entries never run a command
-- themselves; they talk to this service over the plugin's shared state:
--
--   publishes  "status"   -> a snapshot table (see publish() below)
--   consumes   "command"  -> { action, profile?, nonce }
--
-- Actions: "connect" | "disconnect" | "toggle" | "refresh".
--
-- Shell surface (OpenVPN 3 Linux v3.x):
--   openvpn3 sessions-list                          active sessions (no --json)
--   openvpn3 configs-list --verbose                 imported profiles + D-Bus paths
--   openvpn3 session-stats --config N --json        byte counters
--   openvpn3 session-start --config-path P          connect
--   openvpn3 session-manage --session-path P -D     disconnect

local DEFAULT_POLL = 5
local CONNECT_GRACE = 60 -- seconds a pending connect may stay "busy"

local available = noctalia.commandExists("openvpn3")
local session = nil -- { path, config, device, status } or nil
local profiles = {} -- { { name = string, path = string } }
local ip = ""
local bytesIn, bytesOut = 0, 0
local busy = false
local busyUntil = 0
local lastError = ""
local lastNonce = ""

local function shellQuote(s)
  return "'" .. (tostring(s):gsub("'", "'\\''")) .. "'"
end

local function publish()
  noctalia.state.set("status", {
    available = available,
    connected = session ~= nil,
    busy = busy,
    profile = if session then session.config or "" else "",
    device = if session then session.device or "" else "",
    statusText = if session then session.status or "" else "",
    ip = ip,
    bytesIn = bytesIn,
    bytesOut = bytesOut,
    error = lastError,
    profiles = profiles,
  })
end

local function fail(message)
  lastError = noctalia.string.trim(message or "")
  if lastError ~= "" then
    noctalia.notifyError(noctalia.tr("title"), lastError)
  end
end

-- ── Parsing ─────────────────────────────────────────────────────────────────
--
-- sessions-list prints one indented `Key: value` block per session, with two
-- keys sharing some lines ("Owner: vk   Device: tun0"), so match each key
-- anywhere in the line rather than anchoring the whole line.

local function parseSessions(out)
  local list, cur = {}, nil
  for line in (out or ""):gmatch("[^\r\n]+") do
    local path = line:match("^%s*Path:%s*(%S+)")
    if path then
      cur = { path = path }
      table.insert(list, cur)
    elseif cur then
      local device = line:match("Device:%s*(%S+)")
      if device then cur.device = device end
      local config = line:match("Config name:%s*(.-)%s*$")
      -- drop a trailing "(Config path: …)" annotation when present
      if config then cur.config = noctalia.string.trim((config:gsub("%s*%(.*$", ""))) end
      local status = line:match("Status:%s*(.-)%s*$")
      if status then cur.status = status end
    end
  end
  return list
end

-- configs-list --verbose emits, per profile: the D-Bus path on its own line,
-- then a timestamps line, then "<name><padding><owner>", then "Tags: …".
local function parseProfiles(out)
  local list, pending = {}, nil
  for line in (out or ""):gmatch("[^\r\n]+") do
    local path = line:match("^(/net/openvpn/v3/configuration/%S+)")
    if path then
      pending = path
    elseif pending then
      local skip = line:match("^%d%d%d%d%-%d%d%-%d%d") or line:match("^Tags:") or line:match("^%-%-%-")
      if not skip then
        local name = line:match("^(.-)%s%s+%S+%s*$") or line
        name = noctalia.string.trim(name)
        if name ~= "" then
          table.insert(list, { name = name, path = pending })
          pending = nil
        end
      end
    end
  end
  return list
end

-- ── Polling ─────────────────────────────────────────────────────────────────

local function refreshStats(done)
  if not session or not session.config then return done() end
  noctalia.runAsync(`openvpn3 session-stats --config {shellQuote(session.config)} --json`, function(res)
    local data = noctalia.json.decode(res.stdout or "")
    if type(data) == "table" then
      bytesIn = tonumber(data.BYTES_IN) or bytesIn
      bytesOut = tonumber(data.BYTES_OUT) or bytesOut
    end
    done()
  end, 5000)
end

local function refreshIp(done)
  local device = if session then session.device else nil
  if not device or device == "" then
    ip = ""
    return done()
  end
  noctalia.runAsync(`ip -4 -o addr show dev {shellQuote(device)}`, function(res)
    ip = (res.stdout or ""):match("inet%s+([%d%.]+)") or ""
    done()
  end, 3000)
end

local function poll()
  if not available then return publish() end
  noctalia.runAsync("openvpn3 sessions-list", function(res)
    session = parseSessions(res.stdout)[1]
    if session then
      busy = false
      lastError = ""
      refreshIp(function()
        refreshStats(publish)
      end)
    else
      ip, bytesIn, bytesOut = "", 0, 0
      -- A pending connect stops being pending once its grace window elapses.
      if busy and os.time() >= busyUntil then busy = false end
      publish()
    end
  end, 8000)
end

local function refreshProfiles()
  if not available then return end
  noctalia.runAsync("openvpn3 configs-list --verbose", function(res)
    profiles = parseProfiles(res.stdout)
    publish()
  end, 8000)
end

-- ── Commands ────────────────────────────────────────────────────────────────

local function profilePath(name)
  for _, p in ipairs(profiles) do
    if p.name == name then return p.path end
  end
  return nil
end

local function connect(name)
  if not available or session then return end

  name = noctalia.string.trim(name or "")
  if name == "" then name = noctalia.string.trim(noctalia.getConfig("default_profile") or "") end
  if name == "" and profiles[1] then name = profiles[1].name end
  if name == "" then
    return fail(noctalia.tr("error.no_profile"))
  end

  -- Prefer the D-Bus config path: session-start's --config expects a file,
  -- while --config-path names an already-imported profile unambiguously.
  local path = profilePath(name)
  local target = if path then `--config-path {shellQuote(path)}` else `--config {shellQuote(name)}`
  local cmd = `openvpn3 session-start {target}`

  busy = true
  busyUntil = os.time() + CONNECT_GRACE
  lastError = ""
  publish()

  -- Credential and 2FA prompts need a TTY, so those profiles go to a terminal.
  if noctalia.getConfig("connect_in_terminal") then
    noctalia.runInTerminal(cmd)
    return poll()
  end

  noctalia.runAsync(cmd, function(res)
    if res.exitCode ~= 0 then
      busy = false
      local out = res.stderr or ""
      if noctalia.string.trim(out) == "" then out = res.stdout or "" end
      if res.timedOut then out = noctalia.tr("error.timeout") end
      fail(out)
    end
    poll()
  end, CONNECT_GRACE * 1000)
end

local function disconnect()
  if not session then return end

  local selector = if session.path
    then `--session-path {shellQuote(session.path)}`
    else `--config {shellQuote(session.config or "")}`

  busy = true
  busyUntil = os.time() + 30
  publish()

  noctalia.runAsync(`openvpn3 session-manage {selector} --disconnect`, function(res)
    busy = false
    if res.exitCode ~= 0 then
      fail(res.stderr or res.stdout)
    end
    poll()
  end, 20000)
end

local function dispatch(action, profile)
  if action == "connect" then
    connect(profile)
  elseif action == "disconnect" then
    disconnect()
  elseif action == "toggle" then
    if session then disconnect() else connect(profile) end
  elseif action == "refresh" then
    refreshProfiles()
    poll()
  end
end

-- The command channel. Clients stamp a nonce so two identical requests in a row
-- are still delivered as two separate commands.
noctalia.state.watch("command", function(cmd)
  if type(cmd) ~= "table" then return end
  local nonce = tostring(cmd.nonce or "")
  if nonce ~= "" and nonce == lastNonce then return end
  lastNonce = nonce
  dispatch(cmd.action, cmd.profile)
end)

function onIpc(event, payload)
  dispatch(event, payload)
end

function onConfigChanged()
  poll()
end

function update()
  local interval = tonumber(noctalia.getConfig("poll_interval")) or DEFAULT_POLL
  noctalia.setUpdateInterval(math.clamp(interval, 1, 60) * 1000)
  poll()
end

if available then
  refreshProfiles()
  poll()
else
  publish()
end
