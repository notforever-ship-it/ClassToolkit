-- Class Toolkit: spell ready icons. Each watched spell gets an icon that greys out with a countdown while
-- it cools down, turns blue without the mana (rage, energy), red when the target is out of range, and
-- says READY when it can be cast. Shown in combat or while targeting an enemy.
--
-- Watch as many spells as you like; the icons wrap onto another line past six. "Just the next one" keeps
-- a single icon instead, showing whichever watched spell can be cast, or the one coming back soonest.
--
-- Range can only be read from an action slot in 1.12, so a spell has to be on a bar (any bar, even a
-- hidden page) for the out-of-range colour. Everything else works from the spellbook alone.
--
-- Big READY alert: spells you pick in their own list get one big icon you can move that says READY while
-- you can hit them (off cooldown, enough mana, in range, your button lit up), and goes away when you use
-- them. No countdown, no sound.

local CTK = ClassToolkit

local SIZE, PER_LINE, GAP = 32, 6, 36
local QUESTION = "Interface\\Icons\\INV_Misc_QuestionMark"
local row

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
  -- Your own button on the bar has the last word: it stays dark until the spell can really be used
  -- (Kill Command lights up after you crit), so READY comes when the button lights up.
  local look = CTK.ButtonState(name)
  if look == "dark" then
    usable = false
  elseif look == "mana" then
    usable, noMana = nil, true
  elseif look == "ok" then
    usable, noMana = nil, nil
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

------------------------------------------------------------------------------------------------
-- Big READY alert
------------------------------------------------------------------------------------------------

local BIG = 64
local big            -- the big icon
local bigShowing     -- the spell it shows right now, or nil

-- The first spell in the big list you can hit right now, or nil.
local function BigReadyName(list)
  for i = 1, table.getn(list) do
    local name = list[i]
    if CTK.KnowsSpell(name) then
      local state = CTK.SpellReadiness(name)
      local cost = CTK.SpellCost(name)
      if state == "ready" and not (cost and (UnitMana("player") or 0) < cost) then return name end
    end
  end
  return nil
end

local function HideBig()
  bigShowing = nil
  big:Hide()
end

local bigElapsed = 0
local function BigOnUpdate()
  if not CTK.char or CTK.movingIcons then return end
  bigElapsed = bigElapsed + arg1
  if bigElapsed < 0.1 then return end
  bigElapsed = 0

  local c = CTK.char
  if not c.bigReady or UnitIsDeadOrGhost("player") or
    not (UnitAffectingCombat("player") or CTK.HasAttackableTarget()) then
    if bigShowing then HideBig() end
    return
  end

  local name = BigReadyName(c.bigWatched or {})
  if not name then
    if bigShowing then HideBig() end
    return
  end
  if name ~= bigShowing then
    bigShowing = name
    big.icon:SetTexture(CTK.SpellTexture(name) or QUESTION)
    big.icon:SetVertexColor(1, 1, 1)
    big.count:SetText("READY")
    CTK.SetIconState(big, 0.3, 1, 0.3, name)
    big:Show()
  end
end

-- While the icons are unlocked it stays on screen with a sample icon, so it can be dragged.
local function BigUpdate()
  if not big then return end
  local c = CTK.char
  if CTK.movingIcons and c.bigReady then
    bigShowing = nil
    big.icon:SetTexture(CTK.SpellTexture((c.bigWatched or {})[1] or "") or QUESTION)
    big.icon:SetVertexColor(1, 1, 1)
    big.count:SetText("READY")
    CTK.SetIconState(big, 0.3, 1, 0.3, "Big READY alert (drag)")
    big:EnableMouse(true)
    big:Show()
  else
    big:EnableMouse(false)
    if CTK.movingIcons or not c.bigReady then HideBig() end
  end
end

function CTK.InitReady()
  -- Just right of where the hunter range icon starts out.
  row = CTK.CreateRow("ClassToolkitReady", "ready", 150, -140, SIZE, PER_LINE, GAP)
  local driver = CreateFrame("Frame")
  driver:SetScript("OnUpdate", OnUpdate)
  CTK.RegisterModule({ update = Update })

  -- The big READY icon: a bit above the middle of the screen, under the cooldown countdown.
  big = CTK.CreateIcon("ClassToolkitBigReady", UIParent, BIG)
  big:SetFrameStrata("HIGH")
  big:EnableMouse(false)
  big.count:SetFont(STANDARD_TEXT_FONT, 16, "OUTLINE")
  big.count:SetTextColor(0.3, 1, 0.3)
  big.label:SetFontObject(GameFontNormal)
  CTK.MakeDraggable(big, "bigReady", 0, 40)
  big:Hide()
  local bigDriver = CreateFrame("Frame")
  bigDriver:SetScript("OnUpdate", BigOnUpdate)
  CTK.RegisterModule({ update = BigUpdate })
end
