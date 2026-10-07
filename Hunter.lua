-- Class Toolkit: hunter helpers, moved over from PokeHuntLog. The range icon lives in Range.lua now,
-- for every class.
--
-- Feed reminder: GetPetHappiness() drops from Happy (3) to Content (2) to Unhappy (1). The reminder shows
-- while the pet is below the chosen level and isn't already eating. Clicking it casts Feed Pet.

local CTK = ClassToolkit

local FEED_PET = "Feed Pet"
local FEED_EFFECT_ICON = "Interface\\Icons\\Ability_Hunter_BeastTraining"
local HAPPINESS_TEXTURE = "Interface\\PetPaperDollFrame\\UI-PetHappiness"

local HAPPINESS = {
  [1] = { text = "Unhappy", r = 1, g = 0.15, b = 0.15, coords = { 0.375, 0.5625, 0, 0.359375 } },
  [2] = { text = "Content", r = 1, g = 0.82, b = 0, coords = { 0.1875, 0.375, 0, 0.359375 } },
  [3] = { text = "Happy", r = 0.25, g = 1, b = 0.25, coords = { 0, 0.1875, 0, 0.359375 } },
}

local feedFrame
local lastHappiness, happinessSince, lastFed = nil, nil, nil

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

local NEEDS_AMMO = { ["Bows"] = true, ["Guns"] = true, ["Crossbows"] = true }

-- Is a bow, gun or crossbow in the ranged slot? (Thrown weapons and wands need no ammo.)
local function HasAmmoWeapon()
  local ok, slot = pcall(GetInventorySlotInfo, "RangedSlot")
  if not ok or not slot then return false end
  local link = GetInventoryItemLink("player", slot)
  local _, _, id = string.find(link or "", "item:(%d+)")
  if not id then return false end
  local okInfo, _, _, _, _, _, subType = pcall(GetItemInfo, "item:" .. id .. ":0:0:0")
  return okInfo and subType and NEEDS_AMMO[subType] or false
end

-- Is there any ammo (arrows or bullets) anywhere in your bags?
local function BagsHaveAmmo()
  for bag = 0, 4 do
    for s = 1, (GetContainerNumSlots(bag) or 0) do
      local link = GetContainerItemLink(bag, s)
      local _, _, id = string.find(link or "", "item:(%d+)")
      if id then
        local ok, _, _, _, _, kind = pcall(GetItemInfo, "item:" .. id .. ":0:0:0")
        if ok and kind == "Projectile" then return true end
      end
    end
  end
  return false
end

-- The shots left in the ammo you have equipped (the stack in the ammo slot, not what is in your bags), and its
-- icon. The slot does not always give its item's name on every client, so the count is read straight from it.
-- nil means "nothing to say": no ammo is wanted (thrown weapon, wand, nothing), or the count cannot be read.
-- 0 (OUT OF AMMO) only when a bow, gun or crossbow is in your hand, the ammo slot is empty, and no ammo is in
-- your bags either, so a client that hides the slot never gets a false alarm.
local function EquippedAmmo()
  local ok, slot = pcall(GetInventorySlotInfo, "AmmoSlot")
  if not ok or not slot then return nil end
  local count = GetInventoryItemCount("player", slot) or 0
  local texture = GetInventoryItemTexture("player", slot)
  if count > 0 then return count, texture end
  if texture or GetInventoryItemLink("player", slot) then return nil end   -- ammo is there but its count is unreadable
  if HasAmmoWeapon() and not BagsHaveAmmo() then return 0, nil end
  return nil
end

-- /ctk ammodebug: what the game says about the ammo slot, for finding out why the box does or doesn't show.
function CTK.AmmoDebug()
  local ok, slot = pcall(GetInventorySlotInfo, "AmmoSlot")
  CTK.Print("ammo slot id: " .. tostring(slot) .. " (ok " .. tostring(ok) .. ")")
  if ok and slot then
    CTK.Print("link: " .. tostring(GetInventoryItemLink("player", slot)))
    CTK.Print("icon: " .. tostring(GetInventoryItemTexture("player", slot)))
    CTK.Print("count: " .. tostring(GetInventoryItemCount("player", slot)))
  end
  local rok, rslot = pcall(GetInventorySlotInfo, "RangedSlot")
  CTK.Print("ranged slot id: " .. tostring(rslot) .. ", link: " .. tostring(rok and rslot and GetInventoryItemLink("player", rslot)))
  CTK.Print("bow, gun or crossbow in hand: " .. tostring(HasAmmoWeapon()) .. ", ammo in bags: " .. tostring(BagsHaveAmmo()))
  local shots = EquippedAmmo()
  CTK.Print("the box reads: " .. tostring(shots) .. " shots (limit " .. tostring(CTK.char and CTK.char.ammoBoxShots or 100) .. ")")
end

local function UpdateAmmoBox()
  ammoQueued = false
  if not ammoBox or CTK.movingIcons then return end
  local c = CTK.char
  if not c.ammoBox or not CTK.IsClass("HUNTER") then
    ammoBox:Hide()
    return
  end
  local shots, texture = EquippedAmmo()
  if not shots or shots > (c.ammoBoxShots or 100) then
    ammoBox:Hide()
    return
  end
  ammoBox.icon:SetTexture(texture or "Interface\\Icons\\INV_Ammo_Arrow_02")
  if shots == 0 then
    ammoBox.title:SetText("OUT OF AMMO")
    ammoBox.detail:SetText("Equip more before you pull")
  else
    ammoBox.title:SetText("Low ammo")
    ammoBox.detail:SetText(shots .. " shots left")
  end
  ammoBox:Show()
end

-- Bags and the ammo slot change many times a second while looting and shooting, so wait for them to settle.
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
  if not feedFrame then return end
  local c = CTK.char
  local hunter = CTK.IsClass("HUNTER")

  if CTK.movingIcons then
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
      ammoBox.detail:SetText("73 shots left")
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
