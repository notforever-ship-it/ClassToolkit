-- Class Toolkit: eat / drink reminder. After a fight, a Drink icon shows if your mana is under 40% (mana
-- users only) and an Eat icon if your health is under 40% (/ctk drink <percent>). Click one to use the best
-- drink or food in your bags: the one that restores the most and that your level allows.
-- Each icon goes while you eat or drink, for good once you are back above 90%, and when a fight starts.
--
-- Food and drink are found by their tooltip ("Restores 243.6 health over 18 sec. Must remain seated..."),
-- English clients only. Potions and bandages are left alone: their tooltips don't say "seated".

local CTK = ClassToolkit

local FULL = 0.9
local EAT_ICON = "Interface\\Icons\\INV_Misc_Fork&Knife"
local DRINK_ICON = "Interface\\Icons\\INV_Drink_07"
local BUFF_NAMES = { Food = "eat", Drink = "drink", Refreshment = "both" }

local eatFrame, drinkFrame
local armed = { eat = false, drink = false }
local items = {}          -- [item id] = { health, mana, level }, read from the tooltip once
local best = {}           -- eat / drink = { bag, slot, name, texture, count } from the last bag check
local bagsDirty = true

local function Number(text, pattern)
  local _, _, n = string.find(text, pattern)
  return n and tonumber(n)
end

local function ReadItem(bag, slot)
  local tip = CTK.ScanTooltip()
  tip:SetBagItem(bag, slot)
  local info = { health = 0, mana = 0, level = 0 }
  for line = 1, 15 do
    local text = CTK.ScanLine("Left", line)
    if text then
      local level = Number(text, "^Requires Level (%d+)")
      if level then info.level = level end
      if string.find(text, "seated", 1, true) then
        info.health = Number(text, "Restores ([%d%.]+) health") or info.health
        info.mana = Number(text, "([%d%.]+) mana") or info.mana
      end
    end
  end
  tip:Hide()
  return info
end

-- Look through the bags for the best food and the best drink you can use.
local function CheckBags()
  bagsDirty = false
  best = {}
  local myLevel = UnitLevel("player") or 1
  for bag = 0, 4 do
    for slot = 1, (GetContainerNumSlots(bag) or 0) do
      local link = GetContainerItemLink(bag, slot)
      local _, _, id, name = string.find(link or "", "item:(%d+).-%[(.-)%]")
      if id then
        if not items[id] then items[id] = ReadItem(bag, slot) end
        local info = items[id]
        if info.level <= myLevel then
          local texture, count = GetContainerItemInfo(bag, slot)
          local kinds = { eat = info.health, drink = info.mana }
          for kind, amount in pairs(kinds) do
            if amount > 0 then
              local b = best[kind]
              if b and b.id == id then
                b.count = b.count + (count or 1)
              elseif not b or amount > b.amount then
                best[kind] = { bag = bag, slot = slot, id = id, name = name, texture = texture,
                  count = count or 1, amount = amount }
              end
            end
          end
        end
      end
    end
  end
end

-- Is a Food or Drink buff on you right now? Gives back eat, drink (true / false).
local function Consuming()
  local eating, drinking = false, false
  local tip = CTK.ScanTooltip()
  for i = 0, 31 do
    local index = GetPlayerBuff(i, "HELPFUL")
    if not index or index < 0 then break end
    tip:SetOwner(WorldFrame, "ANCHOR_NONE")
    tip:SetPlayerBuff(index)
    local kind = BUFF_NAMES[CTK.ScanLine("Left", 1) or ""]
    if kind == "eat" or kind == "both" then eating = true end
    if kind == "drink" or kind == "both" then drinking = true end
    tip:Hide()
  end
  return eating, drinking
end

local function UsesMana()
  return UnitPowerType("player") == 0 and (UnitManaMax("player") or 0) > 0
end

local function HealthPart()
  local max = UnitHealthMax("player") or 0
  if max <= 0 then return 1 end
  return UnitHealth("player") / max
end

local function ManaPart()
  local max = UnitManaMax("player") or 0
  if max <= 0 then return 1 end
  return UnitMana("player") / max
end

local function ShowIcon(f, kind, fallback, word)
  local b = best[kind]
  if b then
    f.icon:SetTexture(b.texture or fallback)
    f.icon:SetVertexColor(1, 1, 1)
    CTK.SetIconState(f, 0.3, 1, 0.3, word)
    f.count:SetText(b.count > 1 and b.count or "")
  else
    f.icon:SetTexture(fallback)
    f.icon:SetVertexColor(0.5, 0.5, 0.5)
    CTK.SetIconState(f, 1, 0.5, 0.2, word .. ": none in bags")
    f.count:SetText("")
  end
  f:Show()
end

-- Called after a fight ends: arm whichever icon is needed.
local function Arm()
  local c = CTK.char
  if not c or not c.drink or UnitIsDeadOrGhost("player") then return end
  local limit = (c.drinkPct or 40) / 100
  armed.eat = HealthPart() < limit
  armed.drink = UsesMana() and ManaPart() < limit
  if armed.eat or armed.drink then bagsDirty = true end
end

local elapsed = 0
local function OnUpdate()
  if not eatFrame or CTK.movingIcons then return end
  elapsed = elapsed + arg1
  if elapsed < 0.3 then return end
  elapsed = 0
  local c = CTK.char
  if not c or not c.drink or UnitIsDeadOrGhost("player") then
    armed.eat, armed.drink = false, false
  end
  if HealthPart() >= FULL then armed.eat = false end
  if not UsesMana() or ManaPart() >= FULL then armed.drink = false end
  if not armed.eat and not armed.drink then
    eatFrame:Hide()
    drinkFrame:Hide()
    return
  end
  if bagsDirty then CheckBags() end
  local eating, drinking = Consuming()
  if armed.eat and not eating then ShowIcon(eatFrame, "eat", EAT_ICON, "Eat") else eatFrame:Hide() end
  if armed.drink and not drinking then ShowIcon(drinkFrame, "drink", DRINK_ICON, "Drink") else drinkFrame:Hide() end
end

local function Use(kind)
  if CTK.movingIcons or IsShiftKeyDown() then return end
  if bagsDirty then CheckBags() end
  local b = best[kind]
  if not b then
    CTK.Print("no " .. (kind == "eat" and "food" or "drink") .. " in your bags that your level can use.")
    return
  end
  -- The bags may have moved since the last check; make sure the slot still holds it.
  local link = GetContainerItemLink(b.bag, b.slot)
  if not link or not string.find(link, "item:" .. b.id .. ":", 1, true) then
    CheckBags()
    b = best[kind]
    if not b then return end
  end
  UseContainerItem(b.bag, b.slot)
end

local function MakeIcon(name, key, x, kind, fallback, title)
  local f = CTK.CreateIcon(name, UIParent, 40)
  CTK.MakeDraggable(f, key, x, -100)
  f.icon:SetTexture(fallback)
  f:EnableMouse(true)
  f:RegisterForClicks("LeftButtonUp")
  f:SetScript("OnClick", function() Use(kind) end)
  f:SetScript("OnEnter", function()
    GameTooltip:SetOwner(this, "ANCHOR_BOTTOM")
    GameTooltip:SetText(title)
    local b = best[kind]
    if b then
      GameTooltip:AddLine("Click to use " .. (b.name or "it") .. ".", 1, 1, 1, 1)
    else
      GameTooltip:AddLine("Nothing in your bags that your level can use.", 1, 1, 1, 1)
    end
    GameTooltip:AddLine("Shift-drag to move.", 0.7, 0.7, 0.7)
    GameTooltip:Show()
  end)
  f:SetScript("OnLeave", function() GameTooltip:Hide() end)
  return f
end

local function Update()
  if not eatFrame then return end
  if CTK.movingIcons and CTK.char.drink then
    eatFrame.icon:SetTexture(EAT_ICON)
    eatFrame.icon:SetVertexColor(1, 1, 1)
    eatFrame.count:SetText("")
    CTK.SetIconState(eatFrame, 0.3, 1, 0.3, "Eat (drag)")
    eatFrame:Show()
    if UsesMana() then
      drinkFrame.icon:SetTexture(DRINK_ICON)
      drinkFrame.icon:SetVertexColor(1, 1, 1)
      drinkFrame.count:SetText("")
      CTK.SetIconState(drinkFrame, 0.3, 1, 0.3, "Drink (drag)")
      drinkFrame:Show()
    else
      drinkFrame:Hide()
    end
  elseif not CTK.char.drink or (not armed.eat and not armed.drink) then
    eatFrame:Hide()
    drinkFrame:Hide()
  end
end

function CTK.InitEatDrink()
  drinkFrame = MakeIcon("ClassToolkitDrink", "drink", 120, "drink", DRINK_ICON, "Drink")
  eatFrame = MakeIcon("ClassToolkitEat", "eat", 175, "eat", EAT_ICON, "Eat")

  local driver = CreateFrame("Frame")
  local events = { "PLAYER_REGEN_ENABLED", "PLAYER_REGEN_DISABLED", "BAG_UPDATE", "PLAYER_LEVEL_UP" }
  for i = 1, table.getn(events) do pcall(driver.RegisterEvent, driver, events[i]) end
  driver:SetScript("OnEvent", function()
    if event == "PLAYER_REGEN_ENABLED" then
      Arm()
    elseif event == "PLAYER_REGEN_DISABLED" then
      armed.eat, armed.drink = false, false
    else
      bagsDirty = true
    end
  end)
  driver:SetScript("OnUpdate", OnUpdate)
  CTK.RegisterModule({ update = Update })
end
