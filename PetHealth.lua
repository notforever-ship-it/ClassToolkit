-- Class Toolkit: pet low health flash (hunters and warlocks). A flashing icon when your pet drops under 35%
-- health (/ctk pethealth <percent>). Click it: Mend Pet for hunters, Health Funnel for warlocks.
-- Gone again once the pet is healed, dead or dismissed.

local CTK = ClassToolkit

local HEALS = {
  HUNTER = { spell = "Mend Pet", icon = "Interface\\Icons\\Ability_Hunter_MendPet" },
  WARLOCK = { spell = "Health Funnel", icon = "Interface\\Icons\\Spell_Shadow_LifeDrain" },
}

local frame

local function Heal()
  return HEALS[CTK.Class() or ""]
end

local function PetPercent()
  if not UnitExists("pet") or UnitIsDead("pet") then return nil end
  local max = UnitHealthMax("pet")
  if not max or max <= 0 then return nil end
  return math.floor(UnitHealth("pet") / max * 100)
end

local elapsed = 0
local function OnUpdate()
  if not frame or CTK.movingIcons then return end
  elapsed = elapsed + arg1
  if elapsed < 0.05 then return end
  elapsed = 0
  local c = CTK.char
  local heal = Heal()
  local pct = PetPercent()
  if not c or not c.petHealth or not heal or not pct or pct >= (c.petHealthPct or 35)
    or UnitIsDeadOrGhost("player") then
    frame:Hide()
    return
  end
  local name = UnitName("pet") or "Pet"
  frame.icon:SetTexture(CTK.SpellTexture(heal.spell) or heal.icon)
  CTK.SetIconState(frame, 1, 0.2, 0.2, name .. " " .. pct .. "%")
  -- Flash: the glow pulses twice a second.
  local t = math.mod(GetTime(), 0.5) / 0.5
  frame.glow:SetAlpha(0.3 + 0.7 * math.abs(1 - 2 * t))
  frame:Show()
end

local function Update()
  if not frame then return end
  local heal = Heal()
  if CTK.movingIcons and CTK.char.petHealth and heal then
    frame.icon:SetTexture(heal.icon)
    frame.glow:SetAlpha(1)
    CTK.SetIconState(frame, 1, 0.2, 0.2, "Pet low health (drag)")
    frame:Show()
  elseif not CTK.char.petHealth or not heal then
    frame:Hide()
  end
end

function CTK.InitPetHealth()
  frame = CTK.CreateIcon("ClassToolkitPetHealth", UIParent, 44)
  frame:SetFrameStrata("HIGH")
  CTK.MakeDraggable(frame, "petHealth", -140, -100)
  frame:EnableMouse(true)
  frame:RegisterForClicks("LeftButtonUp")
  frame:SetScript("OnClick", function()
    if CTK.movingIcons or IsShiftKeyDown() then return end
    local heal = Heal()
    if not heal then return end
    if CTK.KnowsSpell(heal.spell) then
      CastSpellByName(heal.spell)
    else
      CTK.Print("you don't know " .. heal.spell .. " yet.")
    end
  end)
  frame:SetScript("OnEnter", function()
    local heal = Heal()
    GameTooltip:SetOwner(this, "ANCHOR_BOTTOM")
    GameTooltip:SetText("Your pet is low on health")
    if heal then GameTooltip:AddLine("Click to cast " .. heal.spell .. ".", 1, 1, 1, 1) end
    GameTooltip:AddLine("Shift-drag to move.", 0.7, 0.7, 0.7)
    GameTooltip:Show()
  end)
  frame:SetScript("OnLeave", function() GameTooltip:Hide() end)

  local driver = CreateFrame("Frame")
  driver:SetScript("OnUpdate", OnUpdate)
  CTK.RegisterModule({ update = Update })
end
