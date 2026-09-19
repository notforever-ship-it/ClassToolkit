-- Class Toolkit: warnings in chat and mid-screen when you run low on reagents or ammo.
--
-- Only reagents you actually carry are watched: one is warned about only after you've had at least its
-- "low" amount once, so nobody is told they're out of something they never use (a level 60 priest and
-- Holy Candles). Hunters' ammo is read from the quiver slot and warned about at 200 and 50 shots.

local CTK = ClassToolkit

-- { item, low }: warn when you drop below 'low'.
local REAGENTS = {
  ROGUE = { { "Flash Powder", 5 } },
  MAGE = { { "Rune of Teleportation", 3 }, { "Rune of Portals", 3 }, { "Arcane Powder", 5 }, { "Light Feather", 5 } },
  PRIEST = { { "Holy Candle", 5 }, { "Sacred Candle", 5 }, { "Light Feather", 5 } },
  PALADIN = { { "Symbol of Divinity", 2 }, { "Symbol of Kings", 20 } },
  SHAMAN = { { "Ankh", 2 } },
  WARLOCK = { { "Soul Shard", 3 } },
  DRUID = { { "Maple Seed", 2 }, { "Stranglethorn Seed", 2 }, { "Ashwood Seed", 2 }, { "Hornbeam Seed", 2 },
    { "Ironwood Seed", 2 }, { "Wild Berries", 5 }, { "Wild Thornroot", 5 } },
}
local AMMO_WARN = { 200, 50 }

local warned = {}       -- [item] = true once warned, until you have enough again
local warnedAmmo = {}
local scanQueued = false

local function CountBags()
  local counts = {}
  for bag = 0, 4 do
    local slots = GetContainerNumSlots(bag) or 0
    for slot = 1, slots do
      local link = GetContainerItemLink(bag, slot)
      if link then
        local _, _, name = string.find(link, "%[(.-)%]")
        local _, count = GetContainerItemInfo(bag, slot)
        if name then counts[name] = (counts[name] or 0) + (count or 1) end
      end
    end
  end
  return counts
end

local function AmmoCount()
  local ok, slot = pcall(GetInventorySlotInfo, "AmmoSlot")
  if not ok or not slot then return 0 end
  return GetInventoryItemCount("player", slot) or 0
end

local function Warn(text)
  CTK.Print("|cffff9933" .. text .. "|r")
  UIErrorsFrame:AddMessage(text, 1, 0.6, 0.2, 1.0, 3)
end

local function Check()
  scanQueued = false
  local c = CTK.char
  if not c or not c.reagents then return end
  if not c.reagentSeen then c.reagentSeen = {} end

  local list = REAGENTS[CTK.Class() or ""]
  if list then
    local counts = CountBags()
    for i = 1, table.getn(list) do
      local item, low = list[i][1], list[i][2]
      local count = counts[item] or 0
      if count >= low then
        c.reagentSeen[item] = true
        warned[item] = nil
      elseif c.reagentSeen[item] and not warned[item] then
        warned[item] = true
        Warn("Low on " .. item .. ": " .. count .. " left.")
      end
    end
  end

  if CTK.IsClass("HUNTER") then
    local count = AmmoCount()
    if count > 0 then
      for i = 1, table.getn(AMMO_WARN) do
        local level = AMMO_WARN[i]
        if count <= level then
          if not warnedAmmo[level] then
            warnedAmmo[level] = true
            Warn(count .. " shots left.")
          end
        else
          warnedAmmo[level] = nil
        end
      end
    end
  end
end

-- Bags change many times a second while looting, so wait for them to settle.
local function Queue()
  if scanQueued then return end
  scanQueued = true
  CTK.After(0.5, Check)
end

function CTK.PrintCounts()
  local list = REAGENTS[CTK.Class() or ""]
  local counts = CountBags()
  local parts = {}
  if list then
    for i = 1, table.getn(list) do
      local item = list[i][1]
      if (counts[item] or 0) > 0 or (CTK.char.reagentSeen and CTK.char.reagentSeen[item]) then
        table.insert(parts, item .. " " .. (counts[item] or 0))
      end
    end
  end
  if CTK.IsClass("HUNTER") then table.insert(parts, "ammo " .. AmmoCount()) end
  if table.getn(parts) == 0 then
    CTK.Print("no reagents to count yet: they're watched once you carry some.")
  else
    CTK.Print(table.concat(parts, ", "))
  end
end

function CTK.InitReagents()
  local f = CreateFrame("Frame")
  local events = { "BAG_UPDATE", "UNIT_INVENTORY_CHANGED", "PLAYER_ENTERING_WORLD", "PLAYER_REGEN_ENABLED",
    "PLAYER_REGEN_DISABLED" }
  for i = 1, table.getn(events) do
    pcall(f.RegisterEvent, f, events[i])
  end
  f:SetScript("OnEvent", function()
    if event == "UNIT_INVENTORY_CHANGED" and arg1 ~= "player" then return end
    Queue()
  end)
  CTK.RegisterModule({ update = Queue })
end
