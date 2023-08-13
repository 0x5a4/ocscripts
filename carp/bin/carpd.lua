-- vim:set sw=2:
-- carpd version v1.1
local computer = require("computer")
local component = require("component")
local event = require("event")
local serialization = require("serialization")

-- load config
local config = setmetatable({}, { __index = _G })
local result, reason = loadfile("/etc/carpd.cfg", "t", config)
if not result then
  error("config file failed to load: " .. reason)
end

_, reason = pcall(result)
if reason then
  error("config file failed to load: " .. reason)
end

if not config.remote then
  error("remote not defined in config")
end

-- config defaults
config.port = config.port or 1000
config.default_status = config.default_status or "starting"
config.fetch_interval = config.fetch_interval or 5
config.timeout = config.timeout or 10
config.enable_wakeup = config.enable_wakeup or true

-- internal state

-- data keys that are currently being requested
local request
-- list of event_handlers to be canceled on exit
local event_handlers
-- the current status
local status = config.default_status
-- timestamp of the last packet that has been send
local last_packet = 0

local function stop()
  for _, id in ipairs(event_handlers) do
    event.cancel(id)
  end

  -- run stop hook
  local hook = setmetatable({}, { __index = _G })
  local hook_result, _ = loadfile("/etc/carp.d/stop.lua", "t", hook)
  if hook_result then
    local _, hook_reason = pcall(hook_result)
    if hook_reason then
      stop()
      error("stop hook failed to run: " .. reason)
    end
  end

  component.modem.close(config.port)
end

local function sendMessage(message)
  if not component.isAvailable("modem") then
    error("missing required component 'modem'")
  end

  local ser
  if type(message) == "table" then
    ser = serialization.serialize(message)
  else
    ser = message
  end

  component.modem.send(config.remote, config.port, ser)

  last_packet = computer.uptime()
end

local function syncStatus()
  sendMessage({
    type = "ping",
    data = {
      status = status
    }
  })
end

local function syncData(data)
  sendMessage({
    type = "set",
    data = data
  })
end

local function fetch()
  sendMessage({
    type = "get",
    data = request
  })
end

local function handleMessage(msg)
  local de = serialization.unserialize(msg)

  if type(de) ~= "table" then
    return
  end

  local msgtype = de.type
  local msgdata = de.data

  if msgtype == "ping" then
    syncStatus()
  elseif msgtype == "set" then
    event.push("carp_update", "data", msgdata)
  end
end


local function handleRequest(...)
  local args = table.pack(...)
  if args.n < 1 then
    return
  end

  local requestType = args[1]
  if requestType == "fetch_values" then
    if type(args[2]) ~= "table" then
      return
    end

    --setup request handler if not already done
    if request == nil then
      table.insert(
        event_handlers,
        event.timer(config.fetch_interval, fetch, math.huge)
      )
    end

    request = args[2]
  elseif requestType == "status_update" then
    local newstatus = tostring(args[2])
    if status ~= newstatus then
      status = newstatus
      syncStatus()
    end
  elseif requestType == "data_update" then
    syncData(args[2])
  elseif requestType == "stop" then
    stop()
  end
end


if not component.isAvailable("modem") then
  error("missing required component 'modem'")
end

--open the port
if component.modem.open(config.port) then
  error("port "..config.port.." already open. try changing it in the config file")
end

if config.enable_wakeup then
  component.modem.setWakeMessage("!wakeup!")
end

-- setup event handlers
event_handlers = {
  -- every 0.5 seconds resend the status if we are close to timing out
  event.timer(0.5, function()
    local time_delta = computer.uptime() - last_packet
    if time_delta > config.timeout - 1.5 then
      syncStatus()
    end
  end, math.huge),
  -- handle incoming messages
  event.listen("modem_message", function(_, _, _, port, _, msg)
    if port ~= config.port then
      return
    end
    handleMessage(msg)
  end),
  -- handle requests locally issued by signals
  event.listen("carp_request", function(_, ...)
    handleRequest(...)
  end)
}

-- run start hook
local hook = setmetatable({}, { __index = _G })
local hook_result, _ = loadfile("/etc/carp.d/start.lua", "t", hook)
if hook_result then
  local _, hook_reason = pcall(hook_result)
  if hook_reason then
    stop()
    error("start hook failed to run: " .. reason)
  end

  -- attach event ids defined by hook
  if hook.event_handlers then
    for _, id in ipairs(hook.event_handlers) do
      table.insert(event_handlers, id)
    end
  end
end
