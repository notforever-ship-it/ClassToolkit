-- Class Toolkit: spell ready icons. Each watched spell gets an icon that greys out with a countdown while
-- it cools down, turns blue without the mana (rage, energy), red when the target is out of range, and
-- says READY when it can be cast. Shown in combat or while targeting an enemy.
--
-- Watch as many spells as you like; the icons wrap onto another line past six. "Just the next one" keeps
-- a single icon instead, showing whichever watched spell can be cast, or the one coming back soonest.
--
-- Range can only be read from an action slot in 1.12, so a spell has to be on a bar (any bar, even a
-- hidden page) for the out-of-range colour. Everything else works from the spellbook alone.

local CTK = ClassToolkit

local SIZE, PER_LINE, GAP = 32, 6, 36
local QUESTION = "Interface\\Icons\\INV_Misc_QuestionMark"
local row

-- Spells that only work after you crit your target (Turtle WoW's Kill Command). The game says they are
-- usable any time, so the addon keeps track itself: a crit by you on your target opens it, using the
-- spell (its cooldown starting) or changing target closes it again.
local critAt = 0        -- when you last crit your current target
local usedAt = {}       -- [spell] = when its cooldown last started

local function CritReady(name)
  return critAt > (usedAt[name] or 0)
end

-- Show one icon as that spell stands right now.
local function Paint(icon, name, power)
  icon.icon:SetTexture(CTK.SpellTexture(name) or QUESTION)
  local left, duration = CTK.SpellCooldown(name)
  local cost = CTK.SpellCost(name)
  -- On an action bar the game can say if the spell can be used at all right now; READY only when it can.
  local usable, noMana = nil, nil
  local slot = CTK.ActionSlotFor(name)
  if slot then
    local ok, lowMana = IsUsableAction(slot)
    if lowMana then
      noMana = true
    elseif not ok then
      usable = false
    end
  end
  if usable ~= false and CTK.SpellNeedsCrit and CTK.SpellNeedsCrit(name) and not CritReady(name) then
    usable = false
  end
  -- No target means range can't be judged, not that it's out of range.
  local inRange = nil
  if CTK.HasAttackableTarget() then inRange = CTK.SpellInRange(name) end

  -- A DoT still ticking on the target you have: count it down, purple, and say when it is ending.
  local isDot = CTK.DotDuration and CTK.DotDuration(name)
  if isDot then
    local dotLeft, onTarget = CTK.DotOnTarget(name)
    if dotLeft then
      icon.icon:SetVertexColor(0.85, 0.65, 1)
      icon.count:SetText(tostring(math.ceil(dotLeft)))
      if dotLeft <= 3 then
        CTK.SetIconState(icon, 1, 0.6, 0.1, "ending")
      else
        CTK.SetIconState(icon, 0.7, 0.4, 1, "on target")
      end
      return
    elseif onTarget then
      icon.icon:SetVertexColor(0.85, 0.65, 1)
      icon.count:SetText("")
      CTK.SetIconState(icon, 0.7, 0.4, 1, "on target")
      return
    end
  end

  if left > 0 then
    icon.icon:SetVertexColor(0.4, 0.4, 0.4)
    -- The global cooldown shows too, but a countdown for it would only flicker.
    if duration > 1.6 then icon.count:SetText(tostring(math.ceil(left))) else icon.count:SetText("") end
    CTK.SetIconState(icon, 0.6, 0.6, 0.6, name)
  elseif usable == false then
    -- The game says it cannot be used yet (a spell that needs something to happen first, or the wrong stance).
    icon.icon:SetVertexColor(0.4, 0.4, 0.4)
    icon.count:SetText("")
    CTK.SetIconState(icon, 0.6, 0.6, 0.6, "not yet")
  elseif (cost and power < cost) or noMana then
    icon.icon:SetVertexColor(0.35, 0.35, 1)
    icon.count:SetText("")
    CTK.SetIconState(icon, 0.4, 0.5, 1, "not enough")
  elseif inRange == false then
    icon.icon:SetVertexColor(0.5, 0.5, 0.5)
    icon.count:SetText("")
    CTK.SetIconState(icon, 1, 0.25, 0.25, "out of range")
  else
    icon.icon:SetVertexColor(1, 1, 1)
    icon.count:SetText("")
    CTK.SetIconState(icon, 0.3, 1, 0.3, isDot and "APPLY" or "READY")
  end
end

-- With one icon only: the spell you can cast now (the first in your list wins), or else whichever is
-- coming back soonest. A DoT still ticking on the target counts as "coming back" when it ends.
local function NextReady(watched)
  local best, bestLeft = nil, nil
  for i = 1, table.getn(watched) do
    local name = watched[i]
    if CTK.KnowsSpell(name) then
      local left = CTK.SpellCooldown(name)
      if CTK.DotDuration and CTK.DotDuration(name) then
        local dotLeft = CTK.DotOnTarget(name)
        if dotLeft and dotLeft > left then left = dotLeft end
      end
      if not best or left < bestLeft then
        best = name
        bestLeft = left
      end
    end
  end
  return best
end

-- While the icons are unlocked, every icon shows so you can see how much room the row takes.
local function Update()
  if not row then return end
  local c = CTK.char
  row:EnableMouse(CTK.movingIcons and c.ready and true or false)
  if not CTK.movingIcons then return end

  if not c.ready then
    CTK.ShowIcons(row, 0)
    return
  end

  local used = 0
  if not c.readyOne then
    for i = 1, table.getn(c.watched) do
      if CTK.KnowsSpell(c.watched[i]) then
        used = used + 1
        local icon = CTK.RowIcon(row, used)
        icon.icon:SetTexture(CTK.SpellTexture(c.watched[i]) or QUESTION)
        icon.icon:SetVertexColor(1, 1, 1)
        icon.count:SetText("")
        CTK.SetIconState(icon, 0.3, 1, 0.3, "drag")
      end
    end
  end
  if used == 0 then
    -- One icon only, or nothing watched yet: still show something to grab.
    local icon = CTK.RowIcon(row, 1)
    icon.icon:SetTexture(CTK.SpellTexture(c.watched[1]) or QUESTION)
    icon.icon:SetVertexColor(1, 1, 1)
    icon.count:SetText("")
    CTK.SetIconState(icon, 0.3, 1, 0.3, "Spell ready (drag)")
    used = 1
  end
  CTK.ShowIcons(row, used)
end

local elapsed = 0
local function OnUpdate()
  if not CTK.char or CTK.movingIcons then return end
  elapsed = elapsed + arg1
  if elapsed < 0.1 then return end
  elapsed = 0

  local c = CTK.char
  if not c.ready or UnitIsDeadOrGhost("player") or
    not (UnitAffectingCombat("player") or CTK.HasAttackableTarget()) then
    CTK.ShowIcons(row, 0)
    return
  end

  local power = UnitMana("player") or 0

  if c.readyOne then
    local name = NextReady(c.watched)
    if name then
      Paint(CTK.RowIcon(row, 1), name, power)
      CTK.ShowIcons(row, 1)
    else
      CTK.ShowIcons(row, 0)
    end
    return
  end

  local used = 0
  for i = 1, table.getn(c.watched) do
    local name = c.watched[i]
    if CTK.KnowsSpell(name) then
      used = used + 1
      Paint(CTK.RowIcon(row, used), name, power)
    end
  end
  CTK.ShowIcons(row, used)
end

function CTK.InitReady()
  -- Just right of where the hunter range icon starts out.
  row = CTK.CreateRow("ClassToolkitReady", "ready", 150, -140, SIZE, PER_LINE, GAP)
  local driver = CreateFrame("Frame")
  driver:SetScript("OnUpdate", OnUpdate)
  CTK.RegisterModule({ update = Update })

  -- Crits for the spells that need one ("You crit Boar for 120." / "Your Arcane Shot crits Boar for 300.").
  local crits = CreateFrame("Frame")
  crits:RegisterEvent("CHAT_MSG_COMBAT_SELF_HITS")
  crits:RegisterEvent("CHAT_MSG_SPELL_SELF_DAMAGE")
  crits:RegisterEvent("PLAYER_TARGET_CHANGED")
  crits:RegisterEvent("SPELL_UPDATE_COOLDOWN")
  crits:SetScript("OnEvent", function()
    if event == "PLAYER_TARGET_CHANGED" then
      critAt = 0
    elseif event == "SPELL_UPDATE_COOLDOWN" then
      -- A watched crit spell just used: it needs a new crit before it works again.
      local watched = CTK.char and CTK.char.watched or {}
      for i = 1, table.getn(watched) do
        local name = watched[i]
        if CTK.SpellNeedsCrit and CTK.SpellNeedsCrit(name) then
          local index = CTK.SpellIndex(name)
          local start, duration = GetSpellCooldown(index, "spell")
          if start and start > 0 and duration and duration > 1.6 then usedAt[name] = start end
        end
      end
    else
      local msg = arg1 or ""
      local target = UnitName("target")
      if target and (string.find(msg, "^You crit ") or string.find(msg, " crits ", 1, true))
        and string.find(msg, target, 1, true) then
        critAt = GetTime()
        CTK.Debug("crit on " .. target .. ": crit spells open")
      end
    end
  end)
end
