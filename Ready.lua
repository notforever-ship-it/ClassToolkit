-- Class Toolkit: spell ready icons. Each watched spell gets an icon that greys out with a countdown while
-- it cools down, turns blue without the mana (rage, energy), red when the target is out of range, and
-- says READY when it can be cast. Shown in combat or while targeting an enemy.
--
-- Range can only be read from an action slot in 1.12, so a spell has to be on a bar (any bar, even a
-- hidden page) for the out-of-range colour. Everything else works from the spellbook alone.

local CTK = ClassToolkit

local SIZE = 32
local row

local function Update()
  if not row then return end
  local c = CTK.char
  row:EnableMouse(CTK.movingIcons and c.ready and true or false)

  if CTK.movingIcons then
    if c.ready then
      local icon = row.icons[1]
      icon.icon:SetTexture(CTK.SpellTexture(c.watched[1]) or "Interface\\Icons\\INV_Misc_QuestionMark")
      icon.icon:SetVertexColor(1, 1, 1)
      icon.count:SetText("")
      CTK.SetIconState(icon, 0.3, 1, 0.3, "Spell ready (drag)")
      CTK.ShowIcons(row, 1)
    else
      CTK.ShowIcons(row, 0)
    end
  end
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

  local used = 0
  local power = UnitMana("player") or 0
  for i = 1, table.getn(c.watched) do
    local name = c.watched[i]
    if used < table.getn(row.icons) and CTK.KnowsSpell(name) then
      used = used + 1
      local icon = row.icons[used]
      icon.icon:SetTexture(CTK.SpellTexture(name))
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
  end
  CTK.ShowIcons(row, used)
end

function CTK.InitReady()
  -- Just right of where the hunter range icon starts out.
  row = CTK.CreateRow("ClassToolkitReady", "ready", 150, -140, SIZE, CTK.MAX_WATCHED, 36)
  local driver = CreateFrame("Frame")
  driver:SetScript("OnUpdate", OnUpdate)
  CTK.RegisterModule({ update = Update })
end
