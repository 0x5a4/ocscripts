
local component = require("component")
local event = require("event")
local sides = require("sides")
local serialization = require("serialization")
local os = require("os")

ignition = component.proxy(component.get("02d6bc4d"))
laserpower = component.proxy(component.get("7e869a6d"))
reactor = component.reactor_logic_adapter
laser = component.laser_amplifier

ignition_tried = false

transposer = component.transposer
gas_tank = sides.north
hohlraum_input = sides.east
hohlraum_output = sides.west

function craftHohlraum()
  local outItems = transposer.getAllStacks(hohlraum_output)

  -- check for available slot(very inefficiently)
  local available = false
  for item in outItems do
    -- an empty slot is an empty table
    if next(item) == nil then
      available = true
    end
  end

  if not available then
    return
  end

  -- find source slot
  local sourceSize = transposer.getInventorySize(hohlraum_output)
  local sourceSlot = 1
  
  for i = 1,sourceSize do
    local stack = transposer.getStackInSlot(hohlraum_input, i)
    if stack ~= nil then
      sourceSlot = i    
    end
  end

  -- transfer
  transposer.transferItem(hohlraum_input, gas_tank, 1, sourceSlot, 1)

  -- give it time to fill
  event.timer(2, function()
    transposer.transferItem(gas_tank, hohlraum_output, 1, 1)
    
    -- try again
    craftHohlraum()
  end)
end

function isLaserCharged()
  local charge = laser.getEnergy() / 2.5  
  return charge >= 800000000
end

event_handlers = {
  event.timer(600, craftHohlraum, math.huge),
  event.timer(30, function()
    -- indicates if everything is fine, and status should be set to ok
    local okFlag = true
    
    -- Check if the Laser should be charged
    local isCharged = isLaserCharged()
    local charging = laserpower.getOutput(sides.west) == 15

    if not isCharged and not charging then
      laserpower.setOutput(sides.west, 15)
    elseif isCharged and charging then
      laserpower.setOutput(sides.west, 0)
    end

    -- set status to charging if laserpower is on. this sucks
    if laserpower.getOutput(sides.west) == 15 then
      event.push("carp_request", "status_update", "charging")
      okFlag = false
    end

    -- Check if Reactor is off, reignite if possible
    if not reactor.isIgnited() then
      okFlag = false
      event.push("carp_request", "status_update", "failure")

      -- ensure injection rate is 98(might reset on server restarts)
      reactor.setInjectionRate(98)

      -- Reactor might be able to ignite on its own, propably missing hohlraum       
      if not reactor.canIgnite() and isCharged and not ignition_tried then
        -- FIRE IGNITION
        ignition.setOutput(sides.top, 15)

        event.timer(0.5, function()
          ignition.setOutput(sides.top, 0)
          laserpower.setOutput(sides.west, 15)
          ignition_tried = true
        end)
      end
    else 
      ignition_tried = false
    end
    
    -- sync data  
    event.push("carp_request", "data_update", {
      reactor_production = reactor.getProducing() / 2.5,
      reactor_plasma = reactor.getPlasmaHeat(),
      reactor_ignited = reactor.isIgnited(),
      reactor_rate = reactor.getInjectionRate(),
      laser_charging = charging,
      laser_charge = laser.getEnergy() / 2.5
    })

    if okFlag then
      event.push("carp_request", "status_update", "ok")
    end    
  end, math.huge)
}