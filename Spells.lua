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
local actionSlots = {}     -- [lowercase name] = slot
local slotsDirty = true
local lastSlotScan = 0

local function ScanSpellbook()
  spells = {}
  costs = {}
  ranges = {}
  local i = 1
  while i < 500 do
    local name = GetSpellName(i, BOOK)
    if not name then break end
    -- Ranks are listed lowest first, so the last one seen is the highest.
    spells[string.lower(name)] = { name = name, index = i, texture = GetSpellTexture(i, BOOK) }
    i = i + 1
  end
  CTK.Debug("spellbook: " .. (i - 1) .. " entries")
end

local function ScanActionSlots()
  slotsDirty = false
  lastSlotScan = GetTime()
  actionSlots = {}
  local tip = CTK.ScanTooltip()
  for slot = 1, 120 do
    if HasAction(slot) then
      tip:SetOwner(WorldFrame, "ANCHOR_NONE")
      tip:SetAction(slot)
      local text = CTK.ScanLine("Left", 1)
      if text and not actionSlots[string.lower(text)] then
        actionSlots[string.lower(text)] = slot
      end
      tip:Hide()
    end
  end
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

function CTK.SpellTexture(name)
  local s = name and spells[string.lower(name)]
  return s and s.texture
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
