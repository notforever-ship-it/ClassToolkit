-- Class Toolkit: range icon for every class. It watches one spell, your class's main attack unless you
-- pick another with /ctk range <spell>, and says whether your target is in range of it. When it isn't,
-- the game's interact distances fill in the gap: melee, under 10 yards, under 28 yards, further.
--
-- In 1.12 a spell's range can only be read from an action slot (IsActionInRange), so the watched spell
-- has to be on a bar, any slot, even a hidden page. The spell's own range in yards comes from its
-- tooltip, so talents that extend it are counted. Hunters keep the dead zone: within 10 yards but not
-- in Wing Clip's melee range means neither shot nor swing lands.

local CTK = ClassToolkit

local QUESTION = "Interface\\Icons\\INV_Misc_QuestionMark"

-- The spell each class starts with, and others to fall back on if it isn't known yet.
local DEFAULTS = {
  HUNTER = { "Auto Shot", "Raptor Strike" },
  MAGE = { "Fireball", "Frostbolt", "Arcane Missiles", "Shoot" },
  WARLOCK = { "Shadow Bolt", "Immolate", "Shoot" },
  PRIEST = { "Smite", "Shadow Word: Pain", "Shoot" },
  DRUID = { "Wrath", "Moonfire", "Claw" },
  SHAMAN = { "Lightning Bolt", "Earth Shock", "Rockbiter Weapon" },
  PALADIN = { "Judgement", "Holy Strike", "Hammer of Justice" },
  WARRIOR = { "Heroic Strike", "Rend", "Charge" },
  ROGUE = { "Sinister Strike", "Eviscerate", "Backstab" },
}

-- Melee abilities, checked so the icon can say "Melee" while the watched spell is out of range.
local MELEE = {
  HUNTER = { "Wing Clip", "Raptor Strike", "Mongoose Bite" },
  WARRIOR = { "Heroic Strike", "Rend", "Hamstring", "Sunder Armor", "Bloodthirst", "Mortal Strike", "Overpower" },
  ROGUE = { "Sinister Strike", "Eviscerate", "Kick", "Backstab", "Hemorrhage", "Gouge" },
  PALADIN = { "Holy Strike", "Crusader Strike" },
  DRUID = { "Claw", "Maul", "Rake", "Bash", "Shred", "Swipe" },
  SHAMAN = { "Stormstrike" },
  PRIEST = {},
  MAGE = {},
  WARLOCK = {},
}

local STATES = {
  range = { text = "In range", r = 0.25, g = 1, b = 0.25 },
  meleeGood = { text = "Melee", r = 0.25, g = 1, b = 0.25 },
  melee = { text = "Melee", r = 1, g = 0.6, b = 0.1 },
  deadzone = { text = "Dead zone", r = 1, g = 0.15, b = 0.15 },
  close = { text = "Under 10 yd", r = 1, g = 0.6, b = 0.1 },
  mid = { text = "Under 28 yd", r = 1, g = 0.9, b = 0.2 },
  far = { text = "Out of range", r = 0.6, g = 0.6, b = 0.6 },
}

local frame
local warnedSpell, warnedClip = nil, false

-- The spell the icon watches: the one chosen with /ctk range <spell>, else the first class default known.
function CTK.RangeSpell()
  local c = CTK.char
  if c and c.rangeSpell and CTK.KnowsSpell(c.rangeSpell) then return CTK.KnownSpellName(c.rangeSpell) end
  local list = DEFAULTS[CTK.Class() or ""] or {}
  for i = 1, table.getn(list) do
    if CTK.KnowsSpell(list[i]) then return CTK.KnownSpellName(list[i]) end
  end
  return nil
end

-- A melee ability of this class that sits on a bar, or nil.
local function MeleeSpell()
  local list = MELEE[CTK.Class() or ""] or {}
  for i = 1, table.getn(list) do
    if CTK.ActionSlotFor(list[i]) then return list[i] end
  end
  return nil
end

function CTK.SetRangeSpell(name)
  name = name or ""
  if name == "" or string.lower(name) == "default" then
    CTK.char.rangeSpell = nil
    CTK.char.range = true
    local spell = CTK.RangeSpell()
    CTK.Print("the range icon watches " .. (spell and ("|cffffffff" .. spell .. "|r") or "your class's main attack") .. " again.")
    CTK.UpdateAll()
    return
  end
  local proper = CTK.KnownSpellName(name)
  if not proper then
    CTK.Print("you don't know a spell called '" .. name .. "'. Check the spelling in your spellbook.")
    return
  end
  CTK.char.rangeSpell = proper
  CTK.char.range = true
  warnedSpell = nil
  local yards = CTK.SpellRange(proper)
  local range = (yards == 0 and "melee range") or (yards and (yards .. " yards")) or "its range"
  CTK.Print("the range icon now watches |cffffffff" .. proper .. "|r (" .. range .. "). Keep it on an action bar.")
  CTK.UpdateAll()
end

local function State(spell, yards, melee)
  local inSpell = spell and CTK.SpellInRange(spell)      -- true / false / nil (not on a bar)
  local inMelee = melee and CTK.SpellInRange(melee)
  local near10 = CheckInteractDistance("target", 3)
  local near28 = CheckInteractDistance("target", 4)

  -- Watching a melee ability: in its range is the whole point.
  if yards == 0 then
    if inSpell or (inSpell == nil and inMelee) then return "meleeGood" end
    if near10 then return "close" end
    if near28 then return "mid" end
    return "far"
  end

  if inSpell then return "range" end
  if inSpell == nil and not melee then
    -- Nothing on the bars to ask: the interact distances are the closest guess.
    if near10 then return "close" end
    if near28 then return "mid" end
    return "far"
  end
  if near10 then
    if melee then
      if inMelee then return "melee" end
      if CTK.IsClass("HUNTER") then return "deadzone" end
    end
    return "close"
  end
  if near28 then return "mid" end
  return "far"
end

local elapsed = 0
local function OnUpdate()
  elapsed = elapsed + arg1
  if elapsed < 0.1 then return end
  elapsed = 0
  if CTK.movingIcons then return end
  if not CTK.char or not CTK.char.range or not CTK.HasAttackableTarget() then
    frame:Hide()
    return
  end

  local spell = CTK.RangeSpell()
  local yards = spell and CTK.SpellRange(spell)
  local melee = MeleeSpell()

  if spell and not CTK.ActionSlotFor(spell) and warnedSpell ~= spell then
    warnedSpell = spell
    CTK.Print("the range icon watches |cffffffff" .. spell .. "|r: put it on one of your action bars (any slot) so " ..
      "its range can be read, or pick another spell with /ctk range <spell>.")
  elseif CTK.IsClass("HUNTER") and spell and CTK.ActionSlotFor(spell) and not warnedClip and
    CTK.KnowsSpell("Wing Clip") and not CTK.ActionSlotFor("Wing Clip") then
    warnedClip = true
    CTK.Print("put |cffffffffWing Clip|r on an action bar too, so the range icon can tell melee range from the dead zone.")
  end

  local key = State(spell, yards, melee)
  local state = STATES[key]
  local text = state.text
  if key == "range" and yards and yards > 0 then text = text .. " (" .. yards .. " yd)" end
  CTK.SetIconState(frame, state.r, state.g, state.b, text)
  frame.icon:SetTexture((spell and CTK.SpellTexture(spell)) or QUESTION)
  if key == "range" or key == "meleeGood" then
    frame.icon:SetVertexColor(1, 1, 1)
  else
    frame.icon:SetVertexColor(0.5, 0.5, 0.5)
  end
  frame:Show()
end

local function Update()
  if not frame then return end
  local c = CTK.char
  frame:EnableMouse(CTK.movingIcons and c.range and true or false)
  if CTK.movingIcons then
    if c.range then
      local spell = CTK.RangeSpell()
      frame.icon:SetTexture((spell and CTK.SpellTexture(spell)) or QUESTION)
      frame.icon:SetVertexColor(1, 1, 1)
      CTK.SetIconState(frame, 0.25, 1, 0.25, "Range icon (drag)")
      frame:Show()
    else
      frame:Hide()
    end
  end
end

function CTK.InitRange()
  frame = CTK.CreateIcon("ClassToolkitRangeIcon", UIParent, 36)
  CTK.MakeDraggable(frame, "range", 0, -140)
  frame:EnableMouse(false)   -- don't block clicks in the middle of the screen
  frame:SetScript("OnUpdate", OnUpdate)
  -- A hidden frame's OnUpdate never runs, so a small always-shown driver brings the icon back.
  local driver = CreateFrame("Frame")
  driver:SetScript("OnUpdate", function()
    if not frame:IsShown() and not CTK.movingIcons and CTK.char and CTK.char.range and CTK.HasAttackableTarget() then
      frame:Show()
    end
  end)
  CTK.RegisterModule({ update = Update })
end
