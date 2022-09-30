--- Super simple and WIP inventory abstraction library

-- To use, require and call the function, passing in a table of inventory peripheral names
-- Then a table will be returned. This caches the inventory contents, and allows for quick and easy transfers of item by name out of those inventories.

-- Copyright 2022 Mason Gulu
-- Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
-- The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.


return function(inventories)
  -- Table for storing current item structure
  -- itemname = {
  --   {
  --     inventoryname=,
  --     slots={1,4,5},
  --     count=,
  --   },
  -- }
  local storageCache = {}
  local api = {}
  function api.refreshStorage()
    for _, inventory in pairs(inventories) do
      local invContents = peripheral.call(inventory, "list")
      for slot, item in pairs(invContents) do
        storageCache[item.name] = storageCache[item.name] or {}
        storageCache[item.name][inventory] = storageCache[item.name][inventory] or {
          slots = {},
          count = 0,
        }
        local cached = storageCache[item.name][inventory]
        cached.slots[#cached.slots+1] = slot
        cached.count = cached.count + item.count
      end
    end
  end

  function api.pushItems(targetInventory, name, amount, toSlot, itemMovedCallback)
    if amount <= 0 then
      return 0
    end
    if not storageCache[name] then
      return 0 -- don't have any of this item
    end
    local inventory, item = next(storageCache[name])
    if not item then
      storageCache[name] = nil
      return 0 -- this item doesn't exist
    end
    if (not item.slots) or #item.slots < 1 then
      storageCache[name][inventory] = nil
      return api.pushItems(targetInventory, name, amount, toSlot, itemMovedCallback) -- this inventory doesn't actually have any items in it
    end
    local amountDispensed = peripheral.call(inventory, "pushItems", targetInventory, item.slots[1], amount, toSlot)
    -- TODO add sound
    if itemMovedCallback then
      itemMovedCallback()
    end
    item.count = item.count - amountDispensed
    if amountDispensed < amount then
      -- we pulled all the items from this slot
      table.remove(item.slots, 1)
      return amount + api.pushItems(targetInventory, name, amount - amountDispensed, toSlot, itemMovedCallback) -- so attempt to get the rest of the items required
    end
    if not peripheral.call(inventory, "getItemDetail", item.slots[1]) then
      -- we pulled the exact number of items from this slot
      table.remove(item.slots, 1)
    end
    return amount
  end

  function api.getCount(item)
    if not storageCache[item] then
      return 0
    end
    local totalCount = 0
    for k,v in pairs(storageCache[item]) do
      totalCount = totalCount + v.count
    end
    return totalCount
  end

  return api
end