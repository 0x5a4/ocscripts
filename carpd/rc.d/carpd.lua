local rc = require("rc")
local fs = require("filesystem")
local event = require("event")

function start()
  carp = require("carplib")
  local cfg = args or {}

  carp:setup(
    cfg.port or 1000,
    cfg.default_status or "starting",
    cfg.fetch_interval or 3,
    cfg.timeout or 5
  )
  
  local userstart = "/etc/carp.d/start.lua"
  if fs.exists(userstart) then  
    dofile(userstart)
  end
end

function stop()
  local userstop = "/etc/carp.d/stop.lua"
  if fs.exists(userstop) then
    dofile(userstop)
  end

  if event_handlers ~= nil and type(event_handlers) == "table" then
    for _, evid in ipairs(event_handlers) do
      if type(evid) == "number" then
        event.cancel(evid)
      end
    end
  end
  
  carp:shutdown()
  rc.unload(carp)  
end