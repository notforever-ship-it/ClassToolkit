-- Class Toolkit: hunter helpers, moved over from PokeHuntLog.
--
-- Range icon: Auto Shot's range check says whether you can shoot. When you can't and the target is within
-- ~10 yards (CheckInteractDistance 3), Wing Clip's range check tells melee range from the dead zone. Both
-- spells have to be on an action bar (any slot, even a hidden page) for their range to be readable.
--
-- Feed reminder: GetPetHappiness() drops from Happy (3) to Content (2) to Unhappy (1). The reminder shows
-- while the pet is below the chosen level and isn't already eating. Clicking it casts Feed Pet.

local CTK = ClassToolkit

local AUTO_SHOT, WING_CLIP, FEED_PET = "Auto Shot", "Wing Clip", "Feed Pet"
local FEED_EFFECT_ICON = "Interface\\Icons\\Ability_Hunter_BeastTraining"
local AUTO_SHOT_ICON = "Interface\\Icons\\Ability_Whirlwind"
local HAPPINESS_TEXTURE = "Interface\\PetPaperDollFrame\\UI-PetHappiness"

local RANGE_STATES = {
  range = { text = "In range", r = 0.25, g = 1, b = 0.25 },
  melee = { text = "Melee", r = 1, g = 0.6, b = 0.1 },
  deadzone = { text = "Dead zone", r = 1, g = 0.15, b = 0.15 },
  close = { text = "Too close", r = 1, g = 0.15, b = 0.15 },
  far = { text = "Out of range", r = 0.6, g = 0.6, b = 0.6 },
}

local HAPPINESS = {
  [1] = { text = "Unhappy", r = 1, g = 0.15, b = 0.15, coords = { 0.375, 0.5625, 0, 0.359375 } },
  [2] = { text = "Content", r = 1, g = 0.82, b = 0, coords = { 0.1875, 0.375, 0, 0.359375 } },
  [3] = { text = "Happy", r = 0.25, g = 1, b = 0.25, coords = { 0, 0.1875, 0, 0.359375 } },
}

local rangeFrame, feedFrame
local warnedAutoShot, warnedWingClip = false, false
local lastHappiness, happinessSince, lastFed = nil, nil, nil

------------------------------------------------------------------------------------------------
-- Range icon
------------------------------------------------------------------------------------------------

local function RangeState()
  local shot = CTK.SpellInRange(AUTO_SHOT)
  if shot then return "range" end
  if CheckInteractDistance("target", 3) then
    if CTK.ActionSlotFor(WING_CLIP) then
      if CTK.SpellInRange(WING_CLIP) then return "melee" end
      return "deadzone"
    end
    return "close"
  end
  if CTK.ActionSlotFor(AUTO_SHOT) then return "far" end
  -- Auto Shot isn't on the action bars: follow distance (28 yards) is the closest guess.
  if CheckInteractDistance("target", 4) then return "range" end
  return "far"
end

local rangeElapsed = 0
local function RangeOnUpdate()
  rangeElapsed = rangeElapsed + arg1
  if rangeElapsed < 0.1 then return end
  rangeElapsed = 0
  if CTK.movingIcons then return end
  if not CTK.char.range or not CTK.IsClass("HUNTER") or not CTK.HasAttackableTarget() then
    rangeFrame:Hide()
    return
  end

  local hasShot = CTK.ActionSlotFor(AUTO_SHOT)
  if not hasShot and not warnedAutoShot then
    warnedAutoShot = true
    CTK.Print("the range icon needs |cffffffffAuto Shot|r on one of your action bars (any slot). " ..
      "Drag it from your spellbook.")
  elseif hasShot and not CTK.ActionSlotFor(WING_CLIP) and not warnedWingClip and
    CTK.KnowsSpell(WING_CLIP) then
    warnedWingClip = true
    CTK.Print("put |cffffffffWing Clip|r on an action bar too, so the range icon can tell melee range " ..
      "from the dead zone.")
  end

  local state = RANGE_STATES[RangeState()]
  rangeFrame.label:SetText(state.text)
  CTK.SetIconState(rangeFrame, state.r, state.g, state.b, state.text)
  rangeFrame.icon:SetTexture(CTK.SpellTexture(AUTO_SHOT) or AUTO_SHOT_ICON)
  if state == RANGE_STATES.range then
    rangeFrame.icon:SetVertexColor(1, 1, 1)
  else
    rangeFrame.icon:SetVertexColor(0.5, 0.5, 0.5)
  end
  rangeFrame:Show()
end

------------------------------------------------------------------------------------------------
-- Feed reminder
------------------------------------------------------------------------------------------------

local function PetIsEating()
  for i = 1, 16 do
    local texture = UnitBuff("pet", i)
    if not texture then break end
    if texture == FEED_EFFECT_ICON then return true end
  end
  return false
end

-- The game only tells addons Happy, Content or Unhappy, never the hidden 0-1050 number. It does say when
-- that level changes, so the advice is based on how long the pet has been at this level.
local function FeedAdvice()
  if not UnitExists("pet") then return nil end
  local happiness = GetPetHappiness()
  if not happiness then return nil end
  local minutes = happinessSince and math.floor((time() - happinessSince) / 60) or nil
  local since = minutes and (" for " .. minutes .. " min") or ""
  local fed = lastFed and (" Last fed " .. math.floor((time() - lastFed) / 60) .. " min ago.") or ""
  if happiness == 3 then
    return "Happy" .. since .. ". Feeding now would waste most of the food." .. fed
  elseif happiness == 2 then
    return "Content" .. since .. ". A full meal fits with nothing wasted." .. fed
  end
  return "Unhappy" .. since .. ". Feed it now: it is doing less damage." .. fed
end

local function UpdateFeed(fromEvent)
  if not feedFrame then return end
  local c = CTK.char
  if CTK.movingIcons then return end

  local _, isHunterPet = HasPetUI()
  if not c.feed or not CTK.IsClass("HUNTER") or not isHunterPet or not UnitExists("pet") or UnitIsDead("pet") then
    feedFrame:Hide()
    lastHappiness = nil
    return
  end

  local happiness = GetPetHappiness()
  local look = happiness and HAPPINESS[happiness]
  if not look then
    feedFrame:Hide()
    return
  end

  if happiness ~= lastHappiness then happinessSince = time() end
  if PetIsEating() then lastFed = time() end

  local remindAt = (c.feedWhen == "unhappy") and 1 or 2
  if happiness <= remindAt and not PetIsEating() then
    feedFrame.icon:SetTexCoord(look.coords[1], look.coords[2], look.coords[3], look.coords[4])
    CTK.SetIconState(feedFrame, look.r, look.g, look.b, "Feed " .. (UnitName("pet") or "your pet") ..
      " (" .. look.text .. ")")
    feedFrame:Show()
    if fromEvent and lastHappiness and happiness < lastHappiness then
      local who = UnitName("pet") or "Your pet"
      CTK.Print("|cffffd100" .. who .. " is " .. string.lower(look.text) .. ". Time to feed it!|r")
      UIErrorsFrame:AddMessage(who .. " is " .. string.lower(look.text) .. " - feed your pet", look.r, look.g, look.b, 1.0, 3)
      if c.feedSound then pcall(PlaySound, "TellMessage") end
    end
  else
    feedFrame:Hide()
  end
  lastHappiness = happiness
end

------------------------------------------------------------------------------------------------
-- Low ammo box
------------------------------------------------------------------------------------------------

local ammoBox
local ammoQueued = false

-- The bag slots holding the ammo you have equipped, the shots in them, and its icon. nil when no ammo
-- is equipped (a thrown weapon, or none at all).
local function AmmoStacks()
  local ok, slot = pcall(GetInventorySlotInfo, "AmmoSlot")
  if not ok or not slot then return nil end
  local link = GetInventoryItemLink("player", slot)
  local _, _, name = string.find(link or "", "%[(.-)%]")
  if not name then return nil end
  local stacks, shots = 0, 0
  for bag = 0, 4 do
    for s = 1, (GetContainerNumSlots(bag) or 0) do
      local itemLink = GetContainerItemLink(bag, s)
      if itemLink and string.find(itemLink, "[" .. name .. "]", 1, true) then
        local _, count = GetContainerItemInfo(bag, s)
        stacks = stacks + 1
        shots = shots + (count or 0)
      end
    end
  end
  return stacks, shots, GetInventoryItemTexture("player", slot)
end

local function UpdateAmmoBox()
  ammoQueued = false
  if not ammoBox or CTK.movingIcons then return end
  local c = CTK.char
  if not c.ammoBox or not CTK.IsClass("HUNTER") then
    ammoBox:Hide()
    return
  end
  local stacks, shots, texture = AmmoStacks()
  if not stacks or stacks > (c.ammoBoxStacks or 2) then
    ammoBox:Hide()
    return
  end
  ammoBox.icon:SetTexture(texture or "Interface\\Icons\\INV_Ammo_Arrow_02")
  if shots == 0 then
    ammoBox.title:SetText("OUT OF AMMO")
    ammoBox.detail:SetText("Buy more before you pull")
  else
    ammoBox.title:SetText("Low ammo")
    ammoBox.detail:SetText(stacks .. (stacks == 1 and " stack, " or " stacks, ") .. shots .. " shots left")
  end
  ammoBox:Show()
end

-- Bags change many times a second while looting and shooting, so wait for them to settle.
local function QueueAmmoBox()
  if ammoQueued then return end
  ammoQueued = true
  CTK.After(0.5, UpdateAmmoBox)
end

local function CreateAmmoBox()
  ammoBox = CreateFrame("Frame", "ClassToolkitAmmoBox", UIParent)
  ammoBox:SetWidth(180)
  ammoBox:SetHeight(44)
  ammoBox:SetFrameStrata("MEDIUM")
  CTK.MakeDraggable(ammoBox, "ammo", 0, 240)
  ammoBox:EnableMouse(false)
  ammoBox:SetBackdrop({
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 },
  })
  ammoBox:SetBackdropColor(0.35, 0, 0, 0.85)
  ammoBox:SetBackdropBorderColor(1, 0.15, 0.15, 1)

  ammoBox.icon = ammoBox:CreateTexture(nil, "ARTWORK")
  ammoBox.icon:SetWidth(32)
  ammoBox.icon:SetHeight(32)
  ammoBox.icon:SetPoint("LEFT", ammoBox, "LEFT", 6, 0)
  ammoBox.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)

  ammoBox.title = ammoBox:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  ammoBox.title:SetPoint("TOPLEFT", ammoBox.icon, "TOPRIGHT", 8, -1)
  ammoBox.title:SetTextColor(1, 0.3, 0.3)

  ammoBox.detail = ammoBox:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  ammoBox.detail:SetPoint("BOTTOMLEFT", ammoBox.icon, "BOTTOMRIGHT", 8, 2)

  ammoBox:Hide()
end

------------------------------------------------------------------------------------------------
-- Setup
------------------------------------------------------------------------------------------------

local function Update()
  if not rangeFrame then return end
  local c = CTK.char
  local hunter = CTK.IsClass("HUNTER")
  rangeFrame:EnableMouse(CTK.movingIcons and c.range and true or false)

  if CTK.movingIcons then
    if c.range and hunter then
      rangeFrame.icon:SetTexture(AUTO_SHOT_ICON)
      rangeFrame.icon:SetVertexColor(1, 1, 1)
      CTK.SetIconState(rangeFrame, 0.25, 1, 0.25, "Range icon (drag)")
      rangeFrame:Show()
    else
      rangeFrame:Hide()
    end
    if c.feed and hunter then
      local look = HAPPINESS[2]
      feedFrame.icon:SetTexCoord(look.coords[1], look.coords[2], look.coords[3], look.coords[4])
      CTK.SetIconState(feedFrame, look.r, look.g, look.b, "Feed reminder (drag)")
      feedFrame:Show()
    else
      feedFrame:Hide()
    end
    ammoBox:EnableMouse(c.ammoBox and hunter and true or false)
    if c.ammoBox and hunter then
      ammoBox.icon:SetTexture("Interface\\Icons\\INV_Ammo_Arrow_02")
      ammoBox.title:SetText("Low ammo box (drag)")
      ammoBox.detail:SetText("2 stacks, 312 shots left")
      ammoBox:Show()
    else
      ammoBox:Hide()
    end
    return
  end
  ammoBox:EnableMouse(false)
  UpdateFeed(false)
  UpdateAmmoBox()
end

function CTK.InitHunter()
  rangeFrame = CTK.CreateIcon("ClassToolkitRangeIcon", UIParent, 36)
  CTK.MakeDraggable(rangeFrame, "range", 0, -140)
  rangeFrame:EnableMouse(false)   -- don't block clicks in the middle of the screen
  rangeFrame:SetScript("OnUpdate", RangeOnUpdate)
  -- A hidden frame's OnUpdate never runs, so a small always-shown driver brings the icon back.
  local rangeDriver = CreateFrame("Frame")
  rangeDriver:SetScript("OnUpdate", function()
    if not rangeFrame:IsShown() and not CTK.movingIcons and CTK.char and CTK.char.range and
      CTK.HasAttackableTarget() and CTK.IsClass("HUNTER") then
      rangeFrame:Show()
    end
  end)

  feedFrame = CTK.CreateIcon("ClassToolkitFeedReminder", UIParent, 40)
  CTK.MakeDraggable(feedFrame, "feed", 0, 180)
  feedFrame.icon:SetTexture(HAPPINESS_TEXTURE)
  feedFrame:EnableMouse(true)
  feedFrame:RegisterForClicks("LeftButtonUp")
  feedFrame:SetScript("OnClick", function()
    if CTK.movingIcons or IsShiftKeyDown() then return end
    if UnitAffectingCombat("player") then
      CTK.Print("you can't feed your pet in combat.")
    else
      CastSpellByName(FEED_PET)
    end
  end)
  feedFrame:SetScript("OnEnter", function()
    GameTooltip:SetOwner(this, "ANCHOR_BOTTOM")
    GameTooltip:SetText("Feed your pet")
    local advice = FeedAdvice()
    if advice then GameTooltip:AddLine(advice, 1, 0.82, 0, 1) end
    GameTooltip:AddLine("Click to cast Feed Pet, then click a food in your bags.", 1, 1, 1, 1)
    GameTooltip:AddLine("Shift-drag to move.", 0.7, 0.7, 0.7)
    GameTooltip:Show()
  end)
  feedFrame:SetScript("OnLeave", function() GameTooltip:Hide() end)

  CreateAmmoBox()

  local f = CreateFrame("Frame")
  local events = { "UNIT_HAPPINESS", "UNIT_PET", "UNIT_AURA", "PLAYER_ENTERING_WORLD", "BAG_UPDATE",
    "UNIT_INVENTORY_CHANGED" }
  for i = 1, table.getn(events) do
    pcall(f.RegisterEvent, f, events[i])
  end
  f:SetScript("OnEvent", function()
    if event == "UNIT_HAPPINESS" then
      UpdateFeed(true)
    elseif event == "UNIT_AURA" then
      if arg1 == "pet" then UpdateFeed(false) end
    elseif event == "UNIT_PET" then
      if arg1 == "player" then
        lastHappiness = nil
        CTK.After(1, function() UpdateFeed(false) end)
      end
    elseif event == "PLAYER_ENTERING_WORLD" then
      CTK.After(2, function() UpdateFeed(false) end)
      QueueAmmoBox()
    elseif event == "BAG_UPDATE" or (event == "UNIT_INVENTORY_CHANGED" and arg1 == "player") then
      QueueAmmoBox()
    end
  end)

  CTK.RegisterModule({ update = Update })
end
