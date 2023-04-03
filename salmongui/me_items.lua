local util = require("util")

local items = {}

function items:setGeometry(x, y, width, height)
    self.xpos = x
    self.ypos = y
    self.width = width
    self.height = height
end

function items:bindMe(me)
    self.me = me
end

function items:bindGpu(gpu)
    self.gpu = gpu

    util.drawBox(gpu, self.xpos, self.ypos, self.width, self.height, "Items")

    self:draw()
end

function items:draw()
    local netitems = self.me.getItemsInNetwork()
    local craftables = self.me.getCraftables()

    local typecount = #netitems
    local totalcount = 0
    for _, item in ipairs(netitems) do
        totalcount = totalcount + item.size
    end

    -- shorten totalcount
    local totaltext = tostring(totalcount)
    if totalcount > 1e6 then
        totaltext = string.format("%.2fM", totalcount / 1e6)
    elseif totalcount > 1e4 then
        totaltext = string.format("%.2fk", totalcount / 1e3)
    end

    self.gpu.set(self.xpos + 1, self.ypos + 1, "Items: " .. typecount)
    self.gpu.set(self.xpos + 1, self.ypos + 2, "Total Quantity: " .. totaltext)
    self.gpu.set(self.xpos + 1, self.ypos + 3, "Craftable: " .. #craftables)
end

return items