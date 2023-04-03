local event = require("event")
local computer = require("computer")

local factory = {}

-- create a new server on the given port and the given modem
function factory.new(modem, port, timeout)
  if type(modem) ~= "table" then
    error("expected modem to be of type table got "..type(modem))
  end

  if type(port) ~= "number" then
    error("expected port to be of type number got "..type(port))
  end

  local server = {
    connections = {},
    port = port,
    modem = modem,
    timeout = timeout
  }

  function server:close()
    self.modem.close(self.port)
    self.connections = {}
  end

  function server:send(remote, msg) 
    self.modem.send(remote, self.port, msg)
  end

  function server:wakeup(remote)
    self:send(remote, "!wakeup!")
  end

  -- update a connection's last active timestamp
  function server:keepAlive(remote)
    if type(remote) ~= "string" then
      error("expected remote to be of type string got "..type(remote))
    end
  
    local con = self.connections[remote]

    if con == nil then
      return
    end

    con.timestamp = computer.uptime()
  end

  -- check all connections for timed out ones(no life sign in more than 5 seconds)
  -- and remove them
  function server:checkAlive()
    local now = computer.uptime()
    
    for remote, v in pairs(self.connections) do
      local timestamp = v.timestamp
      if timestamp == nil then
        goto continue
      end
  
      local delta = now - timestamp
    
      if delta > self.timeout then
        self.connections[remote] = nil
        event.push("salmon_update", "disconnect", remote)
      end

      ::continue::          
    end
  end

  -- set a connection's status. creates a new connection with that status if none exists
  function server:setStatus(remote, status)
    if type(remote) ~= "string" then
      error("expected remote to be of type string got "..type(remote))
    end

    if type(status) ~= "string" then
      error("expected status to be of type string got "..type(status))
    end

    local con = self.connections[remote]

    if con == nil then
      con = {}
      self.connections[remote] = con
      event.push("salmon_update", "connect", remote)
    end

    if con.status ~= status then
      local update = {}
      update[remote] = status
      event.push("salmon_update", "status_list", update)
    end
    
    con.status = status
  end

  function server:getStatusList()
    local result = {}
    for k, v in pairs(self.connections) do
      result[k] = v.status
    end
    return result
  end
  
  -- open the port on the modem
  if not server.modem.open(server.port) then
    error("port already opened: "..server.port)
  end

  return server
end

return factory