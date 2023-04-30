-- vim:set sw=2:
-- autodire version v1.1
local component = require("component")
local event = require("event")
local sides = require("sides")

local requestSide = sides.up
local ackSide = sides.down
local outSide = sides.front

if not component.isAvailable("robot") then
  print("autodire can only run in robots!")
  return
end

if not component.isAvailable("database") then
  print("missing required component 'database'")
  return
end

if not component.isAvailable("upgrade_me") then
  print("missing required component 'upgrade_me'")
  return
end

if not component.isAvailable("inventory_controller") then
  print("missing required component 'inventory_controller'")
  return
end

-- load recipe from the primary database component
local function loadRecipe()
  local recipe = {}
  for i = 1, 81 do
    local result, item = pcall(component.database.get, i)
    if not result then break end

    if item then
      table.insert(recipe, {
        dbIndex = i,
        name = item.name,
        damage = item.damage
      })
    end
  end

  return recipe
end

-- given a recipe, determines what steps need to be taken to obtain all required items
--
-- if an item is found to be unobtainable, returns nil along with the name of the item
local function determineCraftingSteps(recipe)
  local me = component.upgrade_me

  -- cache for used items. this prevents one item satisfying infinite requests for that item
  -- since the current "step" is unaware of any other steps
  local cache = {}

  local result = {}
  for _, item in ipairs(recipe) do
    local filter = {
      name = item.name,
      damage = item.damage
    }
    local netItems = me.getItemsInNetwork(filter)
    local _, netItem = next(netItems)

    if netItem and netItem.size > 0 then -- stupid me system lists autocraftable items with size 0, this took forever to debug :|
      local cacheKey = item.name .. ":" .. item.damage
      if cache[cacheKey] == nil then cache[cacheKey] = 0 end

      if cache[cacheKey] + 1 <= netItem.size then
        table.insert(result, { autocraft = false, item = item })
        cache[cacheKey] = cache[cacheKey] + 1
        goto continue
      end
    end

    -- item isnt in network maybe try autocrafting it?
    local craftable = me.getCraftables(filter)

    if not next(craftable) then -- :(
      return nil, filter.name .. ":" .. filter.damage
    end

    table.insert(result, { autocraft = true, item = item })
    ::continue::
  end

  return result
end

-- move the currently selected item into a free slot on the specified side
local function transferItem(side)
  local invController = component.inventory_controller
  for i = 1, invController.getInventorySize(side) do
    local stack = invController.getStackInSlot(side, i)

    if not stack then
      return invController.dropIntoSlot(side, i, 1)
    end
  end

  return false
end

-- watches the given request. if it is completed returns true, false on cancelation and
-- yields if not yet completed
local function watchRequest(request)
  while true do
    if request.isCanceled() then
      return false
    end

    if request.isDone() then
      return true
    end

    coroutine.yield()
  end
end

-- request all required items from the ME-System or try autocrafting it.
-- returns a table of autocrafting jobs that still need to be completed.
--
-- if an item cannot be found, returns nil along with the items name.
-- this propably means that the item was removed while the crafting was still ongoing
-- and indicates that something has gone terribly wrong
local function requestItems(steps)
  local me = component.upgrade_me
  local database = component.database

  local jobs = {}

  for _, step in ipairs(steps) do
    if step.autocraft then
      --craft it
      local craftables = me.getCraftables({
        name = step.item.name,
        damage = step.item.damage
      })

      print("autocrafting item '" .. step.item.name .. ":" .. step.item.damage .. "'... ")
      local request = craftables[1].request(1)

      --wait for completion or cancelation
      local job = {
        watcher = coroutine.create(function() return watchRequest(request) end),
        item = step.item
      }
      table.insert(jobs, job)
    else
      if me.requestItems(database.address, step.item.dbIndex, 1) == 1 then
        print("obtained item '" .. step.item.name .. ":" .. step.item.damage .. "'")
        transferItem(outSide)
      else
        return nil, step.item.name .. ":" .. step.item.damage
      end
    end
  end

  return jobs
end

-- scans the inventory on the specified side for items
-- yields with the slot index and the stack size if an item is found, nil otherwise
local function scanInventory(side)
  local invController = component.inventory_controller
  local invSize = invController.getInventorySize(side)
  local slot = 1
  while true do
    local stack = invController.getStackInSlot(side, slot)

    if stack then
      coroutine.yield(slot, stack.size)
      slot = 1
    end

    if slot == invSize then
      slot = 1
      coroutine.yield(nil)
    else
      slot = slot + 1
    end
  end
end

io.write("loading recipe from database... ")
local recipe = loadRecipe()
if #recipe == 0 then
  print("is empty")
end

print("done!")

local me = component.upgrade_me
local db = component.database
local checkInventory = coroutine.wrap(function() scanInventory(requestSide) end)
local unobtainableWarning = false

while not event.pull(5, "interrupted") do
  local slot, amount = checkInventory()
  if not slot then goto nextCycle end

  for _ = 1, amount do
    local steps, reason = determineCraftingSteps(recipe)
    if not steps then
      if not unobtainableWarning then
        print("unable to make recipe, due to unobtainable item '" .. reason .. "'")
        event.push("carp_request", "status_update", "missing item")
        unobtainableWarning = true
      end

      goto nextCycle
    end
    unobtainableWarning = false

    local jobs, reason = requestItems(steps)
    if not jobs then
      print("critical error! item '" .. reason .. "' was removed while busy")
      event.push("carp_request", "status_update", "failure")
      return
    end

    -- dispatch all crafting jobs
    if #jobs > 0 then
      print("waiting for autocrafting jobs...")
    end

    while #jobs > 0 do
      for i, job in ipairs(jobs) do
        local _, status = coroutine.resume(job.watcher)

        if status == true then
          if me.requestItems(db.address, job.item.dbIndex, 1) == 1 then
            print("obtained item '" .. job.item.name .. ":" .. job.item.damage .. "'")
            table.remove(jobs, i)
            transferItem(outSide)
          else
            print("critical error! item '" .. job.item.name .. ":" .. job.item.damage .. "' was removed while busy")
            event.push("carp_request", "status_update", "failure")
            return
          end
        elseif status == false then --it might be nil
          print("critical error! job for item '" ..
            job.item.name .. ":" .. job.item.damage .. "' was canceled(or missing ingredients)")

          event.push("carp_request", "status_update", "failure")
          return
        end
      end
    end

    -- acknowledge
    component.inventory_controller.suckFromSlot(requestSide, slot, 1)
    transferItem(ackSide)

    print("recipe completed!")
  end

  ::nextCycle::
end
