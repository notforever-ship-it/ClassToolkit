-- Class Toolkit: sell all. At a vendor, Ctrl+Right-click an item in your bags to sell every stack of it.
-- The bag tooltip gets a small grey line saying so while the vendor window is open (/ctk sell: on or off).
-- Stacks are sold one at a time, a moment apart, so the server keeps up; items the vendor won't buy stay.

local CTK = ClassToolkit

local STEP = 0.15       -- seconds between two sales
local GIVE_UP = 10      -- seconds before a stuck sale stops

local job               -- { id, name, before, tried = { ["bag:slot"] = true }, wait, time }

local function IdOf(link)
  if not link then return nil end
  local _, _, id = string.find(link, "item:(%d+)")
  return id
end

local function NameOf(link)
  local _, _, name = string.find(link or "", "%[(.-)%]")
  return name or "item"
end

local function AtVendor()
  return MerchantFrame and MerchantFrame:IsVisible() and MerchantFrame.selectedTab ~= 2
end

-- How many of this item are in the bags.
local function CountOf(id)
  local n = 0
  for bag = 0, 4 do
    for slot = 1, GetContainerNumSlots(bag) do
      if IdOf(GetContainerItemLink(bag, slot)) == id then
        local _, count = GetContainerItemInfo(bag, slot)
        n = n + (count or 1)
      end
    end
  end
  return n
end

local function Finish()
  local sold = job.before - CountOf(job.id)
  if sold > 0 then
    CTK.Print("sold " .. sold .. " x " .. job.name .. ".")
  else
    CTK.Print("the vendor won't buy " .. job.name .. ".")
  end
  job = nil
end

local function OnUpdate()
  if not job then return end
  job.wait = job.wait - arg1
  job.time = job.time + arg1
  if job.wait > 0 then return end
  job.wait = STEP
  if not AtVendor() or job.time > GIVE_UP then Finish() return end
  local waiting = false
  for bag = 0, 4 do
    for slot = 1, GetContainerNumSlots(bag) do
      if IdOf(GetContainerItemLink(bag, slot)) == job.id then
        local _, _, locked = GetContainerItemInfo(bag, slot)
        local key = bag .. ":" .. slot
        if locked then
          waiting = true                -- a sale on its way: wait for it
        elseif not job.tried[key] then
          job.tried[key] = true         -- tried once; if the vendor says no, it stays in the bag
          UseContainerItem(bag, slot)
          return
        end
      end
    end
  end
  if not waiting then Finish() end
end

local function SellAll(bag, slot)
  if job then return end
  local link = GetContainerItemLink(bag, slot)
  local id = IdOf(link)
  if not id then return end
  job = { id = id, name = NameOf(link), before = CountOf(id), tried = {}, wait = 0, time = 0 }
end

function CTK.InitSell()
  -- Ctrl+Right-click on a bag item does nothing in the game itself, so it is free to use.
  local oldClick = ContainerFrameItemButton_OnClick
  ContainerFrameItemButton_OnClick = function(button, ignoreModifiers)
    if button == "RightButton" and IsControlKeyDown() and not ignoreModifiers
      and CTK.char and CTK.char.sellAll and AtVendor() then
      SellAll(this:GetParent():GetID(), this:GetID())
      return
    end
    return oldClick(button, ignoreModifiers)
  end

  -- The tiny tooltip line.
  local oldTip = GameTooltip.SetBagItem
  GameTooltip.SetBagItem = function(self, bag, slot)
    local a, b = oldTip(self, bag, slot)
    if self == GameTooltip and CTK.char and CTK.char.sellAll and AtVendor() and GetContainerItemLink(bag, slot) then
      self:AddLine("Ctrl+Right-click: sell all of this item", 0.6, 0.6, 0.6)
      self:Show()
    end
    return a, b
  end

  local driver = CreateFrame("Frame")
  driver:SetScript("OnUpdate", OnUpdate)
end
