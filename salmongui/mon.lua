local event = require("event")
local component = require("component")

if not component.isAvailable("gpu") then
    error("missing required component gpu")
end

if not component.isAvailable("me_interface") then
    error("missing required component me_interface")
end

-- components
local me = component.me_interface
local gpu = component.gpu

local width, height = 60, 17
local vsplit = width - 16 - 11 - 1
local hsplit = height - 5

-- clear screen
gpu.setViewport(width, height)
gpu.fill(1, 1, width, height, " ")

local servicebox = dofile("services.lua")
local itembox = dofile("me_items.lua")
local corebox = dofile("me_cores.lua")

servicebox:setGeometry(vsplit, 1, width - vsplit, height)
itembox:setGeometry(1, hsplit + 1, vsplit - 2, height - hsplit)
corebox:setGeometry(1, 1, vsplit - 2, hsplit)

itembox:bindMe(me)
corebox:bindMe(me)

servicebox:bindGpu(gpu)
itembox:bindGpu(gpu)
corebox:bindGpu(gpu)

-- Setup event handlers
local event_handlers = {
    event.listen("touch", function(_, _,  x, y) servicebox:touch(x, y) end),
    event.listen("salmon_update", function(_, type, arg1)
        if type == "disconnect" then
            servicebox:disconnect(arg1)
        elseif type == "connect" then
            servicebox:connect(arg1)
        elseif type == "status_list" then
            servicebox:statusUpdate(arg1)
        end
    end),
    event.timer(30, function() itembox:draw() end, math.huge),
    event.timer(2, function() corebox:draw() end, math.huge)
}

-- request status update
event.push("salmon_request", "status_list")

-- Wait for interrupt
event.pull("interrupted")

-- unregister all eventHandlers
for _, evid in pairs(event_handlers) do
    event.cancel(evid)
end

-- reset screen
gpu.fill(1, 1, width, height, " ")
gpu.setViewport(gpu.maxResolution())