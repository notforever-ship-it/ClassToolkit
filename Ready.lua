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
local QUESTION = "Interface\Icons\INV_Misc_QuestionMark"
local row

-- Show one icon as that spell stands right now.
local function Paint(icon, name, power)
  icon.icon:SetTexture(CTK.SpellTexture(name) or QUESTION)
  local left, duration = CTK.SpellCooldown(name)
  local cost = CTK.SpellCost(name)
  -- No target means range can't be judged, not that it's out of range.
  local inRange = nil
  if CTK.HasAttackableTarget() then inRange = CTK.SpellInRange(name) end

  if left > 0 then
    icon.icon:SetVertexColor(0.4, 0.4, 0.4)
    -- The global cooldown shows too, but a countdown for it would only flicker.
    if duration > 1.6 then icon.count:SetText(tostring(math.ceil(left))) else icon.count:SetText("") end
    CTK.SetIconState(icon, 0.6, 0.6, 0.6, name)
  elseif cost and power < cost then
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
    CTK.SetIconState(icon, 0.3, 1, 0.3, "READY")
  end
end

-- With one icon only: the spell you can cast now (the first in your list wins), or else whichever is
-- coming back soonest.
local function NextReady(watched)
  local best, bestLeft = nil, nil
  for i = 1, table.getn(watched) do
    local name = watched[i]
    if CTK.KnowsSpell(name) then
      local left = CTK.SpellCooldown(name)
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
end
