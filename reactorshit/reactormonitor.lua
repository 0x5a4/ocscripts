local component = require("component")
local event = require("event")

if not component.isAvailable("gpu") then
  error("missing required component gpu")
end

local gpu = component.gpu
local width, height = 60, 17
gpu.setViewport(width, height)

local energyheight = 4
local energyy = height - 1 - energyheight
local energyx = 1

local function getScaledNumber(number, postfix)
  local result = tostring(number)
  local postfix = postfix or ""
  
  if number > 1e12 then
    result = string.format("%.2f T", number / 1e12)
  elseif number > 1e9 then
    result = string.format("%.2f G", number / 1e9)
  elseif number > 1e6 then
    result = string.format("%.2f M", number / 1e6)
  elseif number > 1e4 then
    result = string.format("%.2f k", number / 1e3)
  end
  
  return result..postfix
end

local function drawEnergyBox(rf_current, rf_max)
  local barwidth = width - 2
  local storedtext = "fetching..."  

  -- draw background bar
  gpu.setBackground(0xFF0000)
  gpu.fill(
    energyx + 1,
    energyy + 2,
    barwidth,
    energyheight -1,
    " "
  )
  gpu.setBackground(0)

  if rf_current ~= nil and rf_max ~= nil then
    local rfpercent = rf_current / rf_max
    local filledwidth = barwidth * rfpercent
  
    -- draw bar
    gpu.setBackground(0x00FF00)
    gpu.fill(
      energyx + 1,
      energyy + 2,
      filledwidth,
      energyheight - 1,
      " "
    )
  
    gpu.setBackground(0)

    -- power stored label
    storedtext = getScaledNumber(rf_current, "RF")
  end

  gpu.fill(2, energyy + 1, width - 2, 1, " ")
  gpu.set(width - #storedtext, energyy + 1, storedtext)
end

local function drawReactorBox(
  reactor_production,
  reactor_plasma,
  reactor_ignited,
  reactor_rate,
  laser_charging,
  laser_charge
)
  gpu.fill(2, 2, width - 2, energyy - 3, " ")

  if reactor_production == nil or reactor_plasma == nil 
    or reactor_ignited == nil or reactor_rate == nil
    or laser_charging == nil or laser_charge == nil 
  then
    return
  end

  local productiontext = getScaledNumber(reactor_production, "RF/t")
  local plasmatext = getScaledNumber(reactor_plasma, "K")
  local chargetext = getScaledNumber(laser_charge, "RF")

  local fuelprefix = "Consumption: "
  local fueltext = "offline"
  if reactor_ignited then
    fueltext = string.format("%d/t", reactor_rate / 2)
  end

  gpu.set(2, 2, "Production: "..productiontext)
  gpu.set(2, 4, "Plasma: "..plasmatext)
  
  gpu.set(2, 3, fuelprefix)
  if not reactor_ignited then
    gpu.setForeground(0xFF0000)
  end
  gpu.set(2 + #fuelprefix, 3, fueltext)
  gpu.setForeground(0xFFFFFF)

  --draw laser box
  gpu.fill(width - 20, 2, 19, 1, "─")
  gpu.fill(width - 20, 5, 19, 1, "─")
  gpu.fill(width - 21, 3, 1, 2, "│")
  gpu.fill(width - 1, 3, 1, 2, "│")
  gpu.set(width - 21, 2, "╭")
  gpu.set(width - 1, 2, "╮")
  gpu.set(width - 1, 5, "╯")
  gpu.set(width - 21, 5, "╰")
  gpu.set(width - 20, 2, "Laser")
  
  gpu.set(width - 20, 3, "State: ")
  local statetext = "ready"
  if laser_charging then
    statetext = "charging"
    gpu.setForeground(0xFFA500)
  else
    gpu.setForeground(0x00FF00)
  end
  gpu.set(width - 20 + 7, 3, statetext)
  gpu.setForeground(0xFFFFFF)

  gpu.set(width - 20, 4, "Charge: "..chargetext)
end

-- draw energy box
gpu.fill(energyx + 1, energyy, width - 2, 1, "─")
gpu.fill(energyx + 1, energyy + energyheight + 1, width - 2, 1, "─")
gpu.fill(energyx, energyy + 1, 1, energyheight, "│")
gpu.fill(width, energyy + 1, 1, energyheight, "│")
gpu.set(energyx, energyy, "╭")
gpu.set(width, energyy, "╮")
gpu.set(width, energyy + energyheight + 1, "╯")
gpu.set(energyx, energyy + energyheight + 1, "╰")
gpu.set(energyx + 1, energyy, "Power Stored")

drawEnergyBox()

-- draw reactor box
gpu.fill(2, 1, width - 2, 1, "─")
gpu.fill(2, energyy - 1, width - 2, 1, "─")
gpu.fill(1, 2, 1, energyy - 3, "│")
gpu.fill(width, 2, 1, energyy - 3, "│")
gpu.set(1, 1, "╭")
gpu.set(width, 1, "╮")
gpu.set(width, energyy - 1, "╯")
gpu.set(1, energyy - 1, "╰")
gpu.set(2, 1, "Reactor")

-- setup event handlers
local event_handlers = {
  event.listen("carp_update", function(_, type, data)
    if type ~= "data" then
      return
    end

    drawEnergyBox(data["rfstore_current"], data["rfstore_max"])
    drawReactorBox(
      data["reactor_production"],
      data["reactor_plasma"],
      data["reactor_ignited"],
      data["reactor_rate"],
      data["laser_charging"],
      data["laser_charge"]
    )
  end)
}

-- request data to fetch
event.push("carp_request", "fetch_values", {
  "rfstore_current",
  "rfstore_max",
  "reactor_production",
  "reactor_plasma",
  "reactor_ignited",
  "reactor_rate",
  "laser_charging",
  "laser_charge"
})

event.pull("interrupted")

-- unregister event handlers
for _, evid in ipairs(event_handlers) do
  event.cancel(evid)
end

-- reset screen
gpu.fill(1,1, width, height, " ")
gpu.setViewport(gpu.maxResolution())