-- Class Toolkit: buff reminder. One icon per kind of self-buff your class keeps up (an aspect, an armor,
-- a blessing...): it appears when none of that kind is on you, or when yours is about to run out. Click it
-- to cast; right-click to stop reminding about that kind on this character.
--
-- Buff names are read from each buff's tooltip, since 1.12 only hands addons the buff icons. A kind only
-- counts once you know one of its spells, so nobody is nagged about a buff they can't cast yet.

local CTK = ClassToolkit

local SIZE, MAX, GAP = 30, 6, 30

-- label: what the reminder is called. spells: what you can cast, preferred first. buffs: the names that
-- satisfy it (defaults to spells; group versions count). combatOnly: only worth having in a fight.
local KINDS = {
  WARRIOR = {
    { label = "Battle Shout", spells = { "Battle Shout" }, combatOnly = true },
  },
  PALADIN = {
    { label = "Aura", spells = { "Devotion Aura", "Retribution Aura", "Concentration Aura", "Sanctity Aura",
      "Shadow Resistance Aura", "Frost Resistance Aura", "Fire Resistance Aura" } },
    { label = "Blessing",
      spells = { "Blessing of Might", "Blessing of Wisdom", "Blessing of Kings", "Blessing of Salvation",
        "Blessing of Light", "Blessing of Sanctuary" },
      buffs = { "Blessing of Might", "Blessing of Wisdom", "Blessing of Kings", "Blessing of Salvation",
        "Blessing of Light", "Blessing of Sanctuary", "Greater Blessing of Might", "Greater Blessing of Wisdom",
        "Greater Blessing of Kings", "Greater Blessing of Salvation", "Greater Blessing of Light",
        "Greater Blessing of Sanctuary" } },
  },
  HUNTER = {
    { label = "Aspect", spells = { "Aspect of the Hawk", "Aspect of the Monkey", "Aspect of the Wild",
      "Aspect of the Beast", "Aspect of the Cheetah", "Aspect of the Pack" } },
    { label = "Trueshot Aura", spells = { "Trueshot Aura" } },
  },
  PRIEST = {
    { label = "Fortitude", spells = { "Power Word: Fortitude" },
      buffs = { "Power Word: Fortitude", "Prayer of Fortitude" } },
    { label = "Inner Fire", spells = { "Inner Fire" } },
    { label = "Divine Spirit", spells = { "Divine Spirit" }, buffs = { "Divine Spirit", "Prayer of Spirit" } },
  },
  MAGE = {
    { label = "Intellect", spells = { "Arcane Intellect" }, buffs = { "Arcane Intellect", "Arcane Brilliance" } },
    { label = "Armor", spells = { "Mage Armor", "Ice Armor", "Frost Armor" } },
  },
  WARLOCK = {
    { label = "Armor", spells = { "Demon Armor", "Demon Skin" } },
  },
  DRUID = {
    { label = "Mark of the Wild", spells = { "Mark of the Wild" }, buffs = { "Mark of the Wild", "Gift of the Wild" } },
    { label = "Thorns", spells = { "Thorns" } },
    { label = "Omen of Clarity", spells = { "Omen of Clarity" } },
  },
  SHAMAN = {
    { label = "Shield", spells = { "Lightning Shield", "Water Shield" } },
  },
}

-- Hunters: a travel aspect left on in a fight gets you dazed.
local TRAVEL_ASPECTS = { "Aspect of the Cheetah", "Aspect of the Pack" }

local row
local active = {}   -- [buff name] = seconds left, or -1 for a buff that doesn't run out

local function ReadBuffs()
  active = {}
  local tip = CTK.ScanTooltip()
  for i = 0, 31 do
    local index, untilCancelled = GetPlayerBuff(i, "HELPFUL")
    if not index or index < 0 then break end
    tip:SetOwner(WorldFrame, "ANCHOR_NONE")
    tip:SetPlayerBuff(index)
    local name = CTK.ScanLine("Left", 1)
    if name then
      if untilCancelled == 1 then
        active[name] = -1
      else
        active[name] = GetPlayerBuffTimeLeft(index) or -1
      end
    end
    tip:Hide()
  end
end

-- The spell a reminder should cast: the one you last had up, else the first you know.
local function SpellFor(kind)
  local c = CTK.char
  local last = c.lastBuff and c.lastBuff[kind.label]
  if last and CTK.KnowsSpell(last) then return last end
  for i = 1, table.getn(kind.spells) do
    if CTK.KnowsSpell(kind.spells[i]) then return kind.spells[i] end
  end
  return nil
end

-- Seconds left on the best buff of this kind that's on you: -1 if it doesn't run out, nil if none.
local function TimeLeft(kind)
  local names = kind.buffs or kind.spells
  local best, bestName = nil, nil
  for i = 1, table.getn(names) do
    local left = active[names[i]]
    if left and (best == nil or left == -1 or (best ~= -1 and left > best)) then
      best, bestName = left, names[i]
    end
  end
  return best, bestName
end

local function Remember(kind, name)
  if not name then return end
  -- A travel aspect is never the one to offer back.
  for i = 1, table.getn(TRAVEL_ASPECTS) do
    if TRAVEL_ASPECTS[i] == name then return end
  end
  for i = 1, table.getn(kind.spells) do
    if kind.spells[i] == name then
      if not CTK.char.lastBuff then CTK.char.lastBuff = {} end
      CTK.char.lastBuff[kind.label] = name
    end
  end
end

local function SetReminder(icon, spell, r, g, b, label, count, tip)
  icon.icon:SetTexture(CTK.SpellTexture(spell) or "Interface\\Icons\\INV_Misc_QuestionMark")
  icon.icon:SetVertexColor(1, 1, 1)
  icon.count:SetText(count or "")
  CTK.SetIconState(icon, r, g, b, label)
  icon.spell = spell
  icon.tip = tip
  icon:EnableMouse(true)
end

local function Refresh()
  if not row or CTK.movingIcons then return end
  local c = CTK.char
  local kinds = KINDS[CTK.Class() or ""]
  if not c.buffs or not kinds or UnitIsDeadOrGhost("player") or UnitOnTaxi("player") then
    CTK.ShowIcons(row, 0)
    return
  end

  ReadBuffs()
  local fighting = UnitAffectingCombat("player")
  local warnAt = c.buffWarnSeconds or 60
  local used = 0

  for i = 1, table.getn(kinds) do
    local kind = kinds[i]
    local spell = SpellFor(kind)
    local ignored = c.ignoredBuffs and c.ignoredBuffs[kind.label]
    if spell and not ignored and (fighting or not kind.combatOnly) and used < MAX then
      local left, name = TimeLeft(kind)
      Remember(kind, name)
      spell = SpellFor(kind)
      if left == nil then
        used = used + 1
        SetReminder(row.icons[used], spell, 1, 0.25, 0.25, kind.label, nil, "No " .. string.lower(kind.label) .. " on you.")
        row.icons[used].kind = kind.label
      elseif left >= 0 and left < warnAt then
        used = used + 1
        SetReminder(row.icons[used], spell, 1, 0.82, 0, kind.label, tostring(math.ceil(left)),
          name .. " runs out in " .. math.ceil(left) .. " seconds.")
        row.icons[used].kind = kind.label
      end
    end
  end

  -- Hunters: a travel aspect still on in combat.
  if fighting and CTK.IsClass("HUNTER") and used < MAX then
    for i = 1, table.getn(TRAVEL_ASPECTS) do
      if active[TRAVEL_ASPECTS[i]] and used < MAX then
        local fightAspect = CTK.KnowsSpell("Aspect of the Hawk") and "Aspect of the Hawk" or "Aspect of the Monkey"
        used = used + 1
        SetReminder(row.icons[used], TRAVEL_ASPECTS[i], 1, 0.15, 0.15, "in combat!", nil,
          TRAVEL_ASPECTS[i] .. " is on in a fight: one hit and you're dazed. Click for " .. fightAspect .. ".")
        row.icons[used].spell = fightAspect
        row.icons[used].kind = nil
      end
    end
  end

  CTK.ShowIcons(row, used)
end

local function Update()
  if not row then return end
  local c = CTK.char
  row:EnableMouse(CTK.movingIcons and c.buffs and true or false)
  if CTK.movingIcons then
    for i = 1, table.getn(row.icons) do row.icons[i]:EnableMouse(false) end
    if c.buffs then
      local icon = row.icons[1]
      icon.icon:SetTexture("Interface\\Icons\\Spell_Holy_WordFortitude")
      icon.icon:SetVertexColor(1, 1, 1)
      icon.count:SetText("")
      CTK.SetIconState(icon, 1, 0.25, 0.25, "Buff reminder (drag)")
      CTK.ShowIcons(row, 1)
    else
      CTK.ShowIcons(row, 0)
    end
  else
    Refresh()
  end
end

function CTK.ResetIgnoredBuffs()
  CTK.char.ignoredBuffs = {}
  CTK.Print("every buff reminder is back on for this character.")
  Refresh()
end

function CTK.InitBuffs()
  row = CTK.CreateRow("ClassToolkitBuffs", "buffs", 0, 120, SIZE, MAX, GAP)
  for i = 1, MAX do
    local icon = row.icons[i]
    icon:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    icon:SetScript("OnClick", function()
      if CTK.movingIcons then return end
      if arg1 == "RightButton" then
        if this.kind then
          if not CTK.char.ignoredBuffs then CTK.char.ignoredBuffs = {} end
          CTK.char.ignoredBuffs[this.kind] = true
          CTK.Print("no more " .. this.kind .. " reminders on this character. /ctk buffs reset brings them back.")
          Refresh()
        end
      elseif this.spell then
        CastSpellByName(this.spell, 1)
      end
    end)
    icon:SetScript("OnEnter", function()
      if CTK.movingIcons or not this.spell then return end
      GameTooltip:SetOwner(this, "ANCHOR_TOP")
      GameTooltip:SetText(this.tip or this.spell)
      GameTooltip:AddLine("Click to cast " .. this.spell .. ".", 1, 1, 1)
      if this.kind then GameTooltip:AddLine("Right-click to stop this reminder.", 0.7, 0.7, 0.7) end
      GameTooltip:Show()
    end)
    icon:SetScript("OnLeave", function() GameTooltip:Hide() end)
  end

  local f = CreateFrame("Frame")
  local events = { "PLAYER_AURAS_CHANGED", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED", "PLAYER_ENTERING_WORLD",
    "PLAYER_ALIVE", "PLAYER_UNGHOST" }
  for i = 1, table.getn(events) do
    pcall(f.RegisterEvent, f, events[i])
  end
  f:SetScript("OnEvent", function() Refresh() end)

  -- Once a second, so the "runs out in" countdown moves.
  local elapsed = 0
  f:SetScript("OnUpdate", function()
    elapsed = elapsed + arg1
    if elapsed < 1 then return end
    elapsed = 0
    Refresh()
  end)

  CTK.RegisterModule({ update = Update })
end
