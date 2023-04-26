-- vim:set sw=2:
-- witherbegone version v1.0
local component = require("component")
local event = require("event")
local os = require("os")
local robot = require("robot")
local sides = require("sides")

if not component.isAvailable("robot") then
  print("witherbegone can only run in robots!")
  print("this is due to the ME upgrade only being available there")
  return
end

if not component.isAvailable("database") then
  print("missing required component 'database'")
  return
end

if not component.isAvailable("redstone") then
  print("missing required component 'redstone'")
  return
end

if not component.isAvailable("inventory_controller") then
  print("missing required component 'inventory_controller'")
  return
end

local trans = component.inventory_controller
local redstone = component.redstone
local db = component.database

local function moveLeft()
  robot.turnLeft()
  robot.forward()
  robot.turnRight()
end

local function pulseFront()
  redstone.setOutput(sides.front, 7)
  os.sleep(0.1)
  redstone.setOutput(sides.front, 0)
end

--[[
  Spawns a wither. Assumes that at least
  4 Soul Sand are in the first slot and
  at least 3 Wither Skulls are in the second slot
--]]
local function spawnWither()
  -- lowest block
  trans.dropIntoSlot(sides.front, 1, 1)
  pulseFront()

  -- middle block
  robot.up()
  trans.dropIntoSlot(sides.front, 1, 1)
  pulseFront()

  -- left block
  moveLeft()
  trans.dropIntoSlot(sides.front, 1, 1)
  pulseFront()

  -- right block
  robot.turnRight()
  robot.forward()
  robot.forward()
  robot.turnLeft()
  trans.dropIntoSlot(sides.front, 1, 1)
  pulseFront()

  robot.select(2)

  -- left skull
  robot.up()
  trans.dropIntoSlot(sides.front, 1, 1)
  pulseFront()

  -- middle skull
  moveLeft()
  trans.dropIntoSlot(sides.front, 1, 1)
  pulseFront()

  -- right skull
  moveLeft()
  trans.dropIntoSlot(sides.front, 1, 1)
  pulseFront()

  robot.select(1)
  robot.down()
  robot.turnRight()
  robot.forward()
  robot.turnLeft()
  robot.down()
end

-- searches for 4 soul sand and 3 skulls
-- in the chest below and grabs them
local function grabItems()
  local soulSand
  local skulls

  local i = 0

  repeat
    i = i + 1
    local stack = trans.getStackInSlot(sides.down, i)

    if stack == nil then
      goto continue
    end

    if stack.name == db.get(1).name then
      --skulls
      if stack.size >= 3 then
        skulls = i
      end
    elseif stack.name == db.get(2).name then
      --sand
      if stack.size >= 4 then
        soulSand = i
      end
    end

    ::continue::
  until i == 27 or (skulls ~= nil and soulSand ~= nil)

  if skulls == nil or soulSand == nil then
    return false
  end

  trans.suckFromSlot(sides.down, soulSand, 4)
  robot.select(2)
  trans.suckFromSlot(sides.down, skulls, 3)
  robot.select(1)

  return true
end

print("witherbegone v1.0 started")

while not event.pull(5, "interrupted") do
  if grabItems() then
    spawnWither()
    os.sleep(5)
  end
end

