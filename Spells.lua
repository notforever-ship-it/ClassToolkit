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

-- Copy the spell's own button on your action bar. The game darkens it while the spell can't be used
-- (Turtle WoW's Kill Command until you crit) and turns it blue without the mana, so the colour of the icon
-- on screen is the best answer there is. Returns "ok", "dark", "mana", or nil when no button shows it.
local BAR_BUTTONS = {
  { "ActionButton", 12 }, { "BonusActionButton", 12 }, { "MultiBarBottomLeftButton", 12 },
  { "MultiBarBottomRightButton", 12 }, { "MultiBarRightButton", 12 }, { "MultiBarLeftButton", 12 },
  { "pfActionBarMainButton", 12 }, { "pfActionBarTopButton", 12 }, { "pfActionBarLeftButton", 12 },
  { "pfActionBarRightButton", 12 }, { "pfActionBarVerticalButton", 12 }, { "pfActionBarPagingButton", 12 },
  { "BActionButton", 120 }, { "DAB_ActionButton_", 120 },
}
local buttonIcon = {}     -- [lowercase name] = the icon of the button showing it
local buttonLook = {}     -- [lowercase name] = when the bars were last searched for it

local function IconShows(icon, texture)
  if type(icon) ~= "table" or not icon.GetTexture or not icon.IsVisible or not icon:IsVisible() then
    return false
  end
  local t = icon:GetTexture()
  return t ~= nil and string.lower(t) == texture
end

local function FindButtonIcon(texture)
  for i = 1, table.getn(BAR_BUTTONS) do
    local prefix, count = BAR_BUTTONS[i][1], BAR_BUTTONS[i][2]
    for n = 1, count do
      local icon = getglobal(prefix .. n .. "Icon")
      if IconShows(icon, texture) then return icon end
    end
  end
  -- Another bar addon: look through the frames for a button showing it (not this addon's own icons).
  if EnumerateFrames then
    local f = EnumerateFrames()
    while f do
      local fname = f.GetName and f:GetName()
      if fname and not string.find(fname, "^ClassToolkit") then
        local icon = getglobal(fname .. "Icon")
        if icon ~= f and IconShows(icon, texture) then return icon end
      end
      f = EnumerateFrames(f)
    end
  end
  return nil
end

function CTK.ButtonState(name)
  local key = name and string.lower(name)
  if not key or not spells[key] or not spells[key].texture then return nil end
  local texture = string.lower(spells[key].texture)
  local icon = buttonIcon[key]
  if not IconShows(icon, texture) then
    buttonIcon[key] = nil
    local now = GetTime()
    if not CTK.ActionSlotFor(name) or now - (buttonLook[key] or 0) < 3 then return nil end
    buttonLook[key] = now
    icon = FindButtonIcon(texture)
    if not icon then return nil end
    buttonIcon[key] = icon
    CTK.Debug(spells[key].name .. ": copying the button " .. tostring(icon.GetName and icon:GetName()))
  end
  if not icon.GetVertexColor then
    -- No way to read the colour: ask the game about the button's own slot, as the button itself does.
    local button = icon.GetParent and icon:GetParent()
    local slot = button and button.action
    if not slot and button and ActionButton_GetPagedID then
      local ok, id = pcall(ActionButton_GetPagedID, button)
      if ok then slot = id end
    end
    if not slot then return nil end
    local usable, lowMana = IsUsableAction(slot)
    if lowMana then return "mana" end
    return usable and "ok" or "dark"
  end
  local r, g, b = icon:GetVertexColor()
  if not r then return nil end
  if b > r + 0.25 and b > g + 0.25 then return "mana" end   -- blue: not enough mana
  if r > g + 0.3 and r > b + 0.3 then return nil end       -- red (some bars): out of range, said elsewhere
  if r < 0.7 and g < 0.7 and b < 0.7 then return "dark" end
  return "ok"
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

-- How a spell stands right now: "ready", "cooldown" (and the seconds left), "range" (target too far) or
-- "unusable" (wrong stance or form, or not enough mana, rage or energy). Range and "unusable" need the
-- spell on an action bar; without it only the cooldown is known. The global cooldown counts as ready.
function CTK.SpellReadiness(name)
  local left, duration = CTK.SpellCooldown(name)
  if left > 0 and duration > 1.6 then return "cooldown", left end
  local look = CTK.ButtonState(name)
  if look == "dark" or look == "mana" then return "unusable", 0 end
  local slot = CTK.ActionSlotFor(name)
  if slot then
    if look ~= "ok" and not IsUsableAction(slot) then return "unusable", 0 end
    if CTK.HasAttackableTarget() and IsActionInRange(slot) == 0 then return "range", 0 end
  end
  return "ready", 0
end

-- A pet spell's place in the pet's spellbook (a Felhunter's Spell Lock), or nil.
local function PetSpellIndex(name)
  if not UnitExists("pet") or UnitIsDead("pet") then return nil end
  local i = 1
  while i < 100 do
    local n = GetSpellName(i, "pet")
    if not n then return nil end
    if n == name then return i end
    i = i + 1
  end
  return nil
end

-- Out of a list of spells (best first), the one to use now: the first you know that is ready, else the
-- one you know that is back soonest. Entries are spell names, or { pet = "Spell Lock" } for a pet spell.
-- Gives back name, state (as SpellReadiness), seconds left and icon; nil if you know none of them.
function CTK.BestAnswer(list)
  local best, bestState, bestLeft, bestTexture
  for i = 1, table.getn(list) do
    local entry = list[i]
    local name, state, left, texture
    if type(entry) == "table" then
      local index = PetSpellIndex(entry.pet)
      if index then
        name = entry.pet
        texture = GetSpellTexture(index, "pet")
        local start, duration = GetSpellCooldown(index, "pet")
        left = (start and start > 0 and duration) and (start + duration - GetTime()) or 0
        if left > 0 and duration > 1.6 then state = "cooldown" else state, left = "ready", 0 end
      end
    elseif CTK.KnowsSpell(entry) then
      name = CTK.KnownSpellName(entry)
      texture = CTK.SpellTexture(name)
      state, left = CTK.SpellReadiness(name)
    end
    if name then
      if state == "ready" then return name, state, left, texture end
      -- Not ready: keep the one that is back soonest (out of range or unusable counts as soon).
      if not best or left < bestLeft then
        best, bestState, bestLeft, bestTexture = name, state, left, texture
      end
    end
  end
  return best, bestState, bestLeft, bestTexture
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
