local component = require("component")
local event = require("event")
local sides = require("sides")

local guppylib = {}

function guppylib:setup(requiredAmount, requestSide, acknowledgeSide)
  checkArg(1, requiredAmount, "number")
  checkArg(2, requestSide, "number")
  checkArg(3, acknowledgeSide, "number")

  guppylib.requiredAmount = requiredAmount
  guppylib.requestSide = requestSide
  guppylib.acknowledgeSide = acknowledgeSide

  guppylib.event_handlers = {
    event.timer(30, function()
      if self.busy then
        return
      end

      local request = self:checkRequestedAmount()

      if request > 0 then
        self.busy = true
        
        for i=1,request do
          self:craft()
        end
        
        self.busy = false
      end
    end, math.huge)
  }
end

function guppylib:checkRequestedAmount()
  local transposer = component.transposer

  local inv = transposer.getAllStacks(self.requestSide)
  local request = 0

  for stack in inv do
    if next(stack) then -- check for an empty table
      request = request + stack.size
    end
  end

  return request
end

function guppylib:craft()
  local goal = self.requiredAmount
  local transposer = component.transposer  

  while true do
    if goal == 0 then
      self:acknowledge()
      break
    elseif goal >= 64 then
      goal = goal - transposer.transferItem(sides.up, sides.down, 64)      
    else 
      goal = goal - transposer.transferItem(sides.up, sides.down, goal)
    end
  end
end

function guppylib:acknowledge()
  local transposer = component.transposer
  transposer.transferItem(self.requestSide, self.acknowledgeSide, 1)
end

function guppylib:stop()
  for _, i in pairs(self.event_handlers) do
    event.cancel(i)
  end
end

return guppylib