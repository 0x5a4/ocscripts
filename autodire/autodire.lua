-- vim:set sw=2:
-- autodire version v1.0
local component = require("component")
local event = require("event")
local sides = require("sides")

local requestSide = sides.up
local ackSide = sides.down
local outSide = sides.front

-- basic steps
-- 1. load required items
-- 2. check adjacent chest for cobblestone
-- 3. if found, loop required items
--  - if available in ME, order and extract to output side
--  - if not available check craftables, order if found
if not component.isAvailable("robot") then
  print("autodire can only run in robots!")
  print("this is due to the ME upgrade only being available there")
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

-- load recipe from database

local recipe = {}
io.write("loading recipe from database... ")
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

if #recipe == 0 then
  print("database is empty!")
  return
end
print("done!")

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

-- request all required items from the ME-System.
local function requestItems()
  local me = component.upgrade_me
  local database = component.database

  -- check if all items can actually be obtained and gather the ways to obtain them in this table.
  -- this solves the issue of being halfway done with a recipe when discovering it is incompletable but
  -- still has the issue that an item might be extracted before we can finally obtain it. in that case
  -- we just return false and throw our arms in the air
  local ingredients = {}
  for _, item in ipairs(recipe) do
    local filter = {
      name = item.name,
      damage = item.damage
    }
    local netItems = me.getItemsInNetwork(filter)
    local _, netItem = next(netItems)

    if netItem and netItem.size > 0 then -- stupid me system lists autocraftable items with size 0, this took forever to debug :|
      table.insert(ingredients, { autocraft = false, item = item })
      goto continue
    end

    -- item isnt in network maybe try autocrafting it?
    local craftable = me.getCraftables(filter)

    if not next(craftable) then -- :(
      print("unable to obtain item '" .. item.name .. ":" .. item.damage .. "'")
      return false
    end

    table.insert(ingredients, { autocraft = true, item = item })
    ::continue::
  end

  -- actually obtain the items
  for _, ingredient in ipairs(ingredients) do
    if ingredient.autocraft then
      --craft it
      local craftables = me.getCraftables({
        name = ingredient.item.name,
        damage = ingredient.item.damage
      })

      io.write("autocrafting item '" .. ingredient.item.name .. ":" .. ingredient.item.damage .. "'... ")
      local status = craftables[1].request(1)

      --wait for completion or cancelation
      while true do
        if status.isCanceled() then
          print("was canceled!")
          return false
        end

        if status.isDone() then
          print("done!")
          break
        end
      end
    end

    if me.requestItems(database.address, ingredient.item.dbIndex, 1) == 1 then
      print("obtained item '" .. ingredient.item.name .. ":" .. ingredient.item.damage .. "'")
      transferItem(outSide)
    else
      print("required item was removed from ME while busy: '" .. ingredient.item.name .. ":" ..
        ingredient.item.damage .. "'")
      print("ABORTING, USER INTERVENTION IS MOST LIKELY REQUIRED")
      event.push("carp_request", "status_update", "failure")
      return false
    end
  end

  return true
end

while not event.pull(10, "interrupted") do
  local invController = component.inventory_controller

  for slot = 1, invController.getInventorySize(requestSide) do
    local stack = invController.getStackInSlot(requestSide, slot)

    if stack then
      for _ = 1, stack.size do
        if not requestItems() then
          return -- abort(yes this is a less then ideal way of doing that)
        end

        -- acknowledge
        invController.suckFromSlot(requestSide, slot, 1)
        transferItem(ackSide)
      end
    end
  end
end
