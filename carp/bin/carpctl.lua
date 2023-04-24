-- vim:set sw=2:
-- carpctl version v1.0
local event         = require("event")
local serialization = require("serialization")
local shell         = require("shell")
local tty           = require("tty")

local osargs        = shell.parse(...)

local function printUsage()
  print([[
usage: carpctl [COMMAND] <OPTIONS>

COMMANDS:
set-status <new-status>... - set status to <new-status>

fetch <value>...           - start fetching the specified values

sync-data <key>=<value>... - sync key-value pairs to the server

monitor                    - monitor carp updates

stop                       - stop the carpd daemon
  ]])
end

local subcommand = osargs[1]
local args = table.move(osargs, 2, #osargs, 1)

if subcommand == "set-status" then
  if #args < 1 then
    printUsage()
    return
  end

  local newstatus = table.concat(args, " ", 2)

  event.push("carp_request", "status_update", newstatus)
elseif subcommand == "fetch" then
  if #args < 1 then
    printUsage()
    return
  end

  event.push("carp_request", "fetch_values", args)
elseif subcommand == "sync-data" then
  if #args < 1 then
    printUsage()
    return
  end

  local data = {}
  for _, arg in ipairs(args) do
    local equal_sign = string.find(arg, "=")
    if equal_sign == nil then
      print("not a valid key-value pair: '" .. arg .. "'")
      return
    end

    -- parse the key
    local key = string.sub(arg, 1, equal_sign - 1)
    if #key == 0 then
      print("not a valid key-value pair: '" .. arg .. "'")
      return
    end

    -- parse value
    local valueString = string.sub(arg, equal_sign + 1)
    if #valueString == 0 then
      print("not a valid key-value pair: '" .. arg .. "'")
      return
    end

    -- if value is a valid number convert it to one, otherwise use it as-is
    local value = tonumber(valueString) or valueString

    data[key] = value
  end

  event.push("carp_request", "data_update", data)
elseif subcommand == "monitor" then
  -- this is basically dmesg copy pasta
  local gpu = tty.gpu()
  local interactive = io.output().tty

  local color, isPal
  if interactive then
    color, isPal = gpu.getForeground()
  end
  io.write("Press 'Ctrl-C' to exit\n")

  while true do
    local eventName, type, data = event.pullMultiple("interrupted", "carp_update")

    if eventName == "interrupted" then
      return
    end

    local timestamp = os.date("%T")

    if interactive then gpu.setForeground(0xCC2200) end
    io.write("[" .. timestamp .. "] ")
    if interactive then gpu.setForeground(0x44CC00) end
    io.write(type .. " " .. serialization.serialize(data, true) .. "\n")

    if interactive then
      gpu.setForeground(color, isPal)
    end
  end
elseif subcommand == "stop" then
  event.push("carp_request", "stop")
else
  printUsage()
end
