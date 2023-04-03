local event = require("event")
local util = require("util")

local services = {}
services.clients = {}

-- read in default clients
local clientfile = io.open("clients")
if clientfile ~= nil then
    for line in clientfile:lines() do
        local sep = line:find(";")
        if sep ~= nil then
            local name = line:sub(0, sep - 1)
            local address = line:sub(sep + 1, -1)
            table.insert(services.clients, {
                name = name,
                address = address,
                status = "offline"
            })
        end
    end
end

function services:bindGpu(gpu)
    self.gpu = gpu

    -- draw initial geometry
    util.drawBox(gpu, self.xpos, self.ypos, self.width, self.height, "Services")

    --draw all default clients
    for i, client in ipairs(self.clients) do
        self:drawClient(client, i)
    end
end

function services:setGeometry(x, y, width, height)
    self.xpos = x
    self.ypos = y
    self.width = width
    self.height = height
end

-- returns the index in the client table associated with an address
function services:indexOf(address)
    for i, client in ipairs(self.clients) do
        if client.address == address then
            return i
        end
    end

    return nil
end

-- draw a client at the given yoffset
function services:drawClient(client, yoffset)
    local ycoord = self.ypos + yoffset

    self.gpu.fill(self.xpos + 1, ycoord, self.width - 2, 1, " ")

    -- draw name/address
    local text = client.name or client.address:sub(1, 8)

    self.gpu.set(self.xpos + 1, ycoord, text)

    -- draw status
    local status = client.status
    local statusColor = 0xFFA500
    if status == "offline" then
        statusColor = 0xFF00FF
    elseif status:match("fail") ~= nil or status == "no power" then
        statusColor = 0xFF0000
    elseif status == "ok" then
        statusColor = 0x00FF00
    end

    self.gpu.setForeground(statusColor)
    self.gpu.set(self.xpos + self.width - #status - 3, ycoord, "[" .. status .. "]")
    self.gpu.setForeground(0xFFFFFF)
end

function services:statusUpdate(update)
    if type(update) ~= "table" then
        return
    end

    for remote, status in pairs(update) do
        local clientId = self:indexOf(remote)
        if clientId == nil then
            local newclient = {
                address = remote
            }
            table.insert(self.clients, newclient)
            clientId = #self.clients
        end

        self.clients[clientId].status = status
        self:drawClient(self.clients[clientId], clientId)
    end
end

function services:connect(remote)
    if self:indexOf(remote) ~= nil then
        return
    end

    local newclient = {
        address = remote,
        status = "..."
    }

    table.insert(
        self.clients,
        newclient
    )

    self:drawClient(newclient, #self.clients)
end

function services:disconnect(remote)
    if type(remote) ~= "string" then
        return
    end

    local clientId = self:indexOf(remote)
    if clientId ~= nil then
        self.clients[clientId].status = "offline"
        self:drawClient(self.clients[clientId], clientId)
    end
end

function services:touch(x, y)
    if x < self.xpos + 1 or y > self.ypos + #self.clients or y < self.ypos + 1 then
        return
    end

    event.push("salmon_request", "wakeup", self.clients[y - 1].address)
end

return services