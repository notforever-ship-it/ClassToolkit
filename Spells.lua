-- Class Toolkit: what the player knows and where it sits on the action bars.
--
-- Spellbook: each spell's highest rank, its icon, and its cost (only in the tooltip, "25 Mana").
-- Action bars: which slot holds a spell, found by reading each button's tooltip. Range checks need this,
-- because in 1.12 only action slots can say whether the target is in range (IsActionInRange).

local CTK = ClassToolkit

local BOOK = "spell"
local POWER_WORDS = { Mana = true, Rage = true, Energy = true }

local spells = {}          -- [lowercase name] = { name, index, texture }
local costs = {}           -- [lowercase name] = number, read from the tooltip on first use
local ranges = {}          -- [lowercase name] = yards (0 for melee), read from the tooltip on first use
local dotTimes = {}        -- [lowercase name] = seconds a DoT ticks (false: not a DoT), from the tooltip
local actionSlots = {}     -- [lowercase name] = slot
local slotNames = {}       -- [slot] = what the button's tooltip calls it
local slotsDirty = true
local lastSlotScan = 0

local function ScanSpellbook()
  spells = {}
  costs = {}
  ranges = {}
  dotTimes = {}
  local i, noIcon = 1, 0
  while i < 500 do
    local name = GetSpellName(i, BOOK)
    if not name then break end
    local texture = GetSpellTexture(i, BOOK)
    if not texture then noIcon = noIcon + 1 end
    -- Ranks are listed lowest first, so the last one seen is the highest.
    spells[string.lower(name)] = { name = name, index = i, texture = texture }
    i = i + 1
  end
  CTK.Debug("spellbook: " .. (i - 1) .. " entries" .. ((noIcon > 0) and (", " .. noIcon .. " without an icon") or ""))
end

local function ScanActionSlots()
  slotsDirty = false
  lastSlotScan = GetTime()
  actionSlots = {}
  slotNames = {}
  local tip = CTK.ScanTooltip()
  for slot = 1, 120 do
    if HasAction(slot) then
      tip:SetOwner(WorldFrame, "ANCHOR_NONE")
      tip:SetAction(slot)
      local text = CTK.ScanLine("Left", 1)
      if text then
        slotNames[slot] = text
        if not actionSlots[string.lower(text)] then actionSlots[string.lower(text)] = slot end
      end
      tip:Hide()
    end
  end
end

-- What sits in an action slot, as its tooltip names it (a spell's name, or a macro's).
function CTK.ActionName(slot)
  if slotsDirty and GetTime() - lastSlotScan > 1 then ScanActionSlots() end
  return slot and slotNames[slot]
end

-- Seconds a damage-over-time spell keeps ticking, read from its tooltip ("...40 Shadow damage over
-- 12 sec"), or nil when the tooltip says nothing of the kind: then it is not a DoT.
function CTK.SpellDotDuration(name)
  local key = name and string.lower(name)
  if not key or not spells[key] then return nil end
  if dotTimes[key] == nil then
    dotTimes[key] = false
    local tip = CTK.ScanTooltip()
    tip:SetSpell(spells[key].index, BOOK)
    for line = 2, 8 do
      local text = CTK.ScanLine("Left", line)
      if text then
        local _, _, secs = string.find(text, "over (%d+) sec")
        if secs then
          dotTimes[key] = tonumber(secs)
          break
        end
      end
    end
    tip:Hide()
  end
  if dotTimes[key] == false then return nil end
  return dotTimes[key]
end

-- The spell as the spellbook spells it, or nil if the player doesn't know it.
function CTK.KnownSpellName(name)
  local s = name and spells[string.lower(name)]
  return s and s.name
end

function CTK.KnowsSpell(name)
  return name and spells[string.lower(name)] ~= nil
end

function CTK.SpellIndex(name)
  local s = name and spells[string.lower(name)]
  return s and s.index
end

-- The spell's icon. The client sometimes hands back no icon when the book is read (the hunter's Auto
-- Shot, for one), so the book is asked again, and failing that the action button holding the spell.
function CTK.SpellTexture(name)
  local s = name and spells[string.lower(name)]
  if not s then return nil end
  if not s.texture then s.texture = GetSpellTexture(s.index, BOOK) end
  if s.texture then return s.texture end
  local slot = CTK.ActionSlotFor(name)
  if slot then return GetActionTexture(slot) end
  return nil
end

-- Seconds left on the spell's cooldown (0 when ready), and the cooldown's full length.
function CTK.SpellCooldown(name)
  local index = CTK.SpellIndex(name)
  if not index then return 0, 0 end
  local start, duration = GetSpellCooldown(index, BOOK)
  if not start or start == 0 or not duration then return 0, 0 end
  local left = start + duration - GetTime()
  if left < 0 then left = 0 end
  return left, duration
end

-- Mana, rage or energy the spell costs, or nil if it has none (or the tooltip doesn't say).
function CTK.SpellCost(name)
  local key = name and string.lower(name)
  if not key or not spells[key] then return nil end
  if costs[key] == nil then
    costs[key] = false
    local tip = CTK.ScanTooltip()
    tip:SetSpell(spells[key].index, BOOK)
    local text = CTK.ScanLine("Left", 2)
    if text then
      local _, _, amount, word = string.find(text, "^(%d+) (%a+)")
      if amount and POWER_WORDS[word] then costs[key] = tonumber(amount) end
    end
    tip:Hide()
  end
  return costs[key] or nil
end

-- How far the spell reaches: yards as the tooltip says ("30 yd range", talents included), 0 for
-- "Melee Range", or nil when the tooltip doesn't say (a spell cast on yourself).
function CTK.SpellRange(name)
  local key = name and string.lower(name)
  if not key or not spells[key] then return nil end
  if ranges[key] == nil then
    ranges[key] = false
    local tip = CTK.ScanTooltip()
    tip:SetSpell(spells[key].index, BOOK)
    for line = 1, 4 do
      local text = CTK.ScanLine("Right", line)
      if text then
        -- "35 yd range", or "8 - 35 yd range" for a shot with a minimum: the far end is what matters.
        local _, _, low, high = string.find(text, "^(%d+)%s*%-%s*(%d+) yd")
        local _, _, yards = string.find(text, "^(%d+) yd")
        if high then
          ranges[key] = tonumber(high)
          break
        elseif yards then
          ranges[key] = tonumber(yards)
          break
        elseif string.find(string.lower(text), "melee", 1, true) then
          ranges[key] = 0
          break
        end
      end
    end
    tip:Hide()
  end
  if ranges[key] == false then return nil end
  return ranges[key]
end

-- The action slot holding this spell, or nil. The bars are re-read a second after they change.
function CTK.ActionSlotFor(name)
  if slotsDirty and GetTime() - lastSlotScan > 1 then ScanActionSlots() end
  return name and actionSlots[string.lower(name)]
end

-- Is the target in range of this spell? true / false, or nil when it can't be told (not on a bar,
-- no target, or a spell with no range).
function CTK.SpellInRange(name)
  local slot = CTK.ActionSlotFor(name)
  if not slot then return nil end
  local r = IsActionInRange(slot)
  if r == 1 then return true end
  if r == 0 then return false end
  return nil
end

function CTK.InitSpells()
  local f = CreateFrame("Frame")
  local events = { "SPELLS_CHANGED", "LEARNED_SPELL_IN_TAB", "PLAYER_ENTERING_WORLD", "ACTIONBAR_SLOT_CHANGED" }
  for i = 1, table.getn(events) do
    pcall(f.RegisterEvent, f, events[i])
  end
  f:SetScript("OnEvent", function()
    if event == "ACTIONBAR_SLOT_CHANGED" then
      slotsDirty = true
    else
      ScanSpellbook()
      slotsDirty = true
      if event ~= "PLAYER_ENTERING_WORLD" then CTK.UpdateAll() end
    end
  end)
  ScanSpellbook()
end
