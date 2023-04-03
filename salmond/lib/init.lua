local salmon = {}

local component = require("component")
local event = require("event")
local serialization = require("serialization")
local server = require("salmon.server")

function salmon:setup(port, timeout)
  -- Check necessary components
  if not component.isAvailable("modem") then
    error("missing required component modem")
  end

  local modem = component.modem

  -- Setup
  self.server = server.new(modem, port, timeout)
  self.data = {}
  
  self.event_handlers = {
    -- modem messages
    event.listen("modem_message", function(_, _, remote, _, _, msg) 
      local data = serialization.unserialize(msg)
      self:receiveMsg(remote, data)
    end),
    -- keep connections alive
    event.timer(3, function()
      self.server:checkAlive() 
    end, math.huge),
    -- handle wakup requests
    event.listen("salmon_request", function(_, ...)
      self:handleRequest(...)
    end)
  }    

  -- Ping everyone
  local ping = serialization.serialize({
    type = "ping",
    data = {}
  })

  modem.broadcast(self.server.port, ping)
end

function salmon:handleRequest(...)
  local args = table.pack(...)
  if args.n < 1 then
    return
  end

  local requestType = args[1]

  if requestType == "wakeup" then
    if args.n ~= 2 then
      return
    end

    local remote = args[2]
    if type(remote) ~= "string" then
      return
    end
    self.server:wakeup(remote)
  elseif requestType == "status_list" then
    event.push(
      "salmon_update",
      "status_list",
      self.server:getStatusList()
    )
  end
end

function salmon:receiveMsg(remote, msg)
  local msgtype = msg.type
  local msgdata = msg.data

  if msgtype == nil or msgdata == nil then
    return
  end
  
  if type(msgdata) ~= "table" then
    return
  end

  if msgtype == "get" then
    -- find requested values    
    local response = {}
    local valid = false
    for k,v in pairs(msgdata) do
      local value = self.data[v]
      if value ~= nil then
        response[v] = value
      end
    end
    
    -- construct packet
    local packet = {
      type = "set",
      data = response
    }

    self.server:send(remote, serialization.serialize(packet))
  elseif msgtype == "set" then 
    for k, v in pairs(msgdata) do
      self.data[k] = v
    end 
  elseif msgtype == "ping" then
    local newstatus = msgdata.status
    if newstatus ~= nil then
      self.server:setStatus(remote, newstatus)
    end
  end

  self.server:keepAlive(remote)
end

function salmon:shutdown()
  -- Unregister events
  for _, evid in ipairs(self.event_handlers) do
    event.cancel(evid)
  end
  
  -- Close Server
  self.server:close()
end

return salmon