-- vim:set sw=2:
local event = require("event")
local component = require("component")
local serialization = require("serialization")
local computer = require("computer")

local carplib = {}

carplib.remote = "79bcb2cb-2fd7-4101-9fdd-1ef0271edc90"

-- Initializes required event handlers and opens the port
function carplib:setup(port, default_status, fetch_interval, timeout)
  if not component.isAvailable("modem") then
    error("missing required component modem")
  end

  -- settings
  self.port = port
  self.status = default_status
  self.fetch_interval = fetch_interval
  self.timeout = timeout
  self.last_packet = 0

  local modem = component.modem
  if not modem.open(self.port) then
    error("port already opened")
  end
  modem.setWakeMessage("!wakeup!")

  -- setup event handlers
  self.event_handlers = {
    event.timer(0.5, function()
      local time_delta = computer.uptime() - self.last_packet
      if time_delta > self.timeout - 1 then
        self:syncStatus()
      end
    end, math.huge),
    event.listen("modem_message", function(_, _, remote, _, _, msg)
      self:handleMessage(remote, msg)
    end),
    event.listen("carp_request", function(_, ...)
      self:handleRequest(...)
    end)
  }

  -- initial sync
  self:syncStatus()
end

-- send a packet to the host and update last_packet timestamp
function carplib:send(data)
  component.modem.send(self.remote, self.port, data)
  self.last_packet = computer.uptime()
end

function carplib:setRequest(values)
  if type(values) ~= "table" then
    return
  end

  -- setup event handler if not already done
  if self.request == nil then
    table.insert(
      self.event_handlers,
      event.timer(self.fetch_interval, function()
        self:fetch()
      end, math.huge)
    )
  end

  self.request = values
end

function carplib:fetch()
  local packet = {
    type = "get",
    data = self.request
  }

  self:send(serialization.serialize(packet))
end

function carplib:handleRequest(...)
  local args = table.pack(...)
  if args.n < 2 then
    return
  end

  local type = args[1]
  if type == "fetch_values" then
    self:setRequest(args[2])
  elseif type == "status_update" then
    local newstatus = tostring(args[2])
    if self.status ~= newstatus then
      self.status = newstatus
      self:syncStatus()
    end
  elseif type == "data_update" then
    self:syncData(args[2])
  end
end

function carplib:handleMessage(remote, msg)
  local de = serialization.unserialize(msg)

  if type(de) ~= "table" then
    return
  end

  local msgtype = de.type
  local msgdata = de.data

  if msgtype == "ping" then
    self:syncStatus()
  elseif msgtype == "set" then
    event.push("carp_update", "data", msgdata)
  end
end

function carplib:syncStatus()
  local packet = {
    type = "ping",
    data = {
      status = self.status
    }
  }

  self:send(serialization.serialize(packet))
end

function carplib:syncData(data)
  local packet = {
    type = "set",
    data = data
  }

  self:send(serialization.serialize(packet))
end

function carplib:shutdown()
  component.modem.close(self.port)

  -- cancel event handlers
  for _, evid in ipairs(self.event_handlers) do
    event.cancel(evid)
  end
end

return carplib
