-- vim:set sw=2:
-- carpd version v1.0
local event = require("event")

function start()
    dofile("/bin/carpd.lua")
end

function stop()
    event.push("carp_request", "stop")
end
