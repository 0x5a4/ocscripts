local util = require("util")
local cores = {}

function cores:setGeometry(x, y, width, height)
    self.xpos = x
    self.ypos = y
    self.width = width
    self.height = height
end

function cores:bindMe(me)
    self.me = me
end

function cores:bindGpu(gpu)
    self.gpu = gpu

    util.drawBox(gpu, self.xpos, self.ypos, self.width, self.height, "Crafting")

    self:draw()
end

function cores:draw()
    local cpus = self.me.getCpus()

    --sort after processing power
    table.sort(cpus, function(a, b)
        return a.storage > b.storage
    end)

    self.gpu.fill(self.xpos + 1, self.ypos + 1, self.width - 2, self.height - 2, " ")

    local unnamedcount = 0
    local unnamedbusy = 0

    local leftlen = 0
    local left = true

    local innerheight = self.height - 3
    local yoffset = 1
    local xoffset = 1

    for _, cpu in ipairs(cpus) do
        -- increase busy count
        if cpu.name == "" then
            unnamedcount = unnamedcount + 1
            if cpu.busy then
                unnamedbusy = unnamedbusy + 1
            end
            goto continue
        end

        -- check for overflow
        if yoffset > innerheight then
            if left then
                left = false
                yoffset = 1
                xoffset = leftlen + 2
            else
                goto continue
            end
        end

        if cpu.busy then
            self.gpu.setForeground(0xFF0000)
        else
            self.gpu.setForeground(0x00FF00)
        end

        self.gpu.set(self.xpos + xoffset, self.ypos + yoffset, cpu.name)

        if left and #cpu.name > leftlen then
            leftlen = #cpu.name
        end

        yoffset = yoffset + 1

        ::continue::
    end

    self.gpu.setForeground(0xFFFFFF)

    local unnamedtext = string.format(
        "Unnamed: [%d/%d]",
        unnamedcount - unnamedbusy,
        unnamedcount
    )

    self.gpu.set(
        self.xpos + self.width - #unnamedtext,
        self.ypos + self.height - 2,
        unnamedtext
    )
end

return cores