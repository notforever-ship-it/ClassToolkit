-- Class Toolkit: the /ctk window. Switches for what shows on this character (hunter-only ones are hidden
-- for other classes), the spells with a ready icon, and the lock for moving everything.

local CTK = ClassToolkit

local GOLD, GREY, WHITE, END = "|cffffd100", "|cff9d9d9d", "|cffffffff", "|r"
local WIDTH, HEIGHT = 340, 510
local ROW = 26

local frame, classText, watchHeader, addBox, addButton, lockButton
local checks = {}
local watchLines = {}

local function Explain(widget, title, text)
  widget:SetScript("OnEnter", function()
    GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
    GameTooltip:SetText(title)
    GameTooltip:AddLine(text, 1, 1, 1, 1)
    GameTooltip:Show()
  end)
  widget:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

local TIPS = {
  swingMelee = "Bars counting down to your next melee swing. With SuperWoW there's an off-hand bar too.",
  swingRanged = "Counts down to your next Auto Shot or wand shot. On Auto Shot the red end is the aim: " ..
    "stand still then or the shot is delayed.",
  ready = "An icon for each watched spell: greyed out with a countdown on cooldown, blue without the mana, " ..
    "red out of range, READY when you can cast it. Shown in combat or while targeting an enemy.",
  buffs = "An icon appears when a buff your class keeps up is missing or about to run out. Click it to " ..
    "cast, right-click to stop that reminder.",
  reagents = "A warning when you run low on a reagent you carry, and hunters' ammo at 200 and 50 shots.",
  range = "Shows whether your target is in Auto Shot range, the dead zone, or melee range. Needs Auto Shot " ..
    "and Wing Clip on an action bar (any slot).",
  feed = "A happiness face when your pet stops being happy. Click it to feed.",
  ammoBox = "A red box on screen when you're down to your last stacks of ammo (2 to start; /ctk ammo 3 to change).",
}

local function AddWatched()
  local text = addBox:GetText()
  if text and text ~= "" then
    CTK.Watch(text)
    addBox:SetText("")
  end
  addBox:ClearFocus()
end

local function Build()
  frame = CreateFrame("Frame", "ClassToolkitOptions", UIParent)
  frame:SetWidth(WIDTH)
  frame:SetHeight(HEIGHT)
  frame:SetPoint("CENTER", UIParent, "CENTER", 0, 40)
  frame:SetFrameStrata("DIALOG")
  frame:SetClampedToScreen(true)
  frame:EnableMouse(true)
  frame:SetMovable(true)
  frame:RegisterForDrag("LeftButton")
  frame:SetScript("OnDragStart", function() this:StartMoving() end)
  frame:SetScript("OnDragStop", function() this:StopMovingOrSizing() end)
  CTK.Opaque(frame, 11)
  frame:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true, tileSize = 32, edgeSize = 32,
    insets = { left = 11, right = 12, top = 12, bottom = 11 },
  })
  frame:SetScript("OnShow", function() CTK.RefreshOptions() end)
  frame:Hide()
  table.insert(UISpecialFrames, "ClassToolkitOptions")

  local title = frame:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
  title:SetPoint("TOP", frame, "TOP", 0, -18)
  title:SetText("Class Toolkit")

  local close = CreateFrame("Button", "ClassToolkitOptionsClose", frame, "UIPanelCloseButton")
  close:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -6, -6)

  classText = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  classText:SetPoint("TOP", title, "BOTTOM", 0, -6)

  for i = 1, table.getn(CTK.TOGGLES) do
    local t = CTK.TOGGLES[i]
    local check = CreateFrame("CheckButton", "ClassToolkitCheck" .. t.key, frame, "UICheckButtonTemplate")
    check:SetWidth(24)
    check:SetHeight(24)
    local text = getglobal("ClassToolkitCheck" .. t.key .. "Text")
    if text then text:SetText(t.label) end
    check.toggle = t
    Explain(check, t.label, TIPS[t.key] or "")
    check:SetScript("OnClick", function()
      CTK.char[this.toggle.key] = this:GetChecked() and true or false
      CTK.UpdateAll()
    end)
    checks[i] = check
  end

  watchHeader = frame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
  watchHeader:SetText("Spell ready icons")

  for i = 1, CTK.MAX_WATCHED do
    local line = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    local remove = CreateFrame("Button", "ClassToolkitUnwatch" .. i, frame, "UIPanelButtonTemplate")
    remove:SetWidth(70)
    remove:SetHeight(18)
    remove:SetText("Remove")
    remove.index = i
    remove:SetScript("OnClick", function()
      local name = CTK.char.watched[this.index]
      if name then CTK.Unwatch(name) end
    end)
    watchLines[i] = { text = line, remove = remove }
  end

  addBox = CreateFrame("EditBox", "ClassToolkitWatchBox", frame, "InputBoxTemplate")
  addBox:SetWidth(190)
  addBox:SetHeight(18)
  addBox:SetAutoFocus(false)
  addBox:SetScript("OnEnterPressed", AddWatched)
  addBox:SetScript("OnEscapePressed", function() this:SetText("") this:ClearFocus() end)
  Explain(addBox, "Add a spell", "Type a spell's name exactly as your spellbook shows it, for example " ..
    "Arcane Shot or Overpower, then press Enter or Add.")

  addButton = CreateFrame("Button", "ClassToolkitWatchAdd", frame, "UIPanelButtonTemplate")
  addButton:SetWidth(70)
  addButton:SetHeight(20)
  addButton:SetText("Add")
  addButton:SetScript("OnClick", AddWatched)

  lockButton = CreateFrame("Button", "ClassToolkitLockButton", frame, "UIPanelButtonTemplate")
  lockButton:SetWidth(110)
  lockButton:SetHeight(22)
  lockButton:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 20, 40)
  lockButton:SetScript("OnClick", function() CTK.ToggleMoveIcons() end)
  Explain(lockButton, "Move the icons", "Unlock, drag the icons and bars where you want them, then lock again. " ..
    "Positions are shared by all your characters.")

  local help = CreateFrame("Button", "ClassToolkitOptionsHelp", frame, "UIPanelButtonTemplate")
  help:SetWidth(80)
  help:SetHeight(22)
  help:SetPoint("LEFT", lockButton, "RIGHT", 8, 0)
  help:SetText("Help")
  help:SetScript("OnClick", function() CTK.ToggleHelp() end)
  Explain(help, "How to use", "What each part does, what the colours mean, and every command.")

  local done = CreateFrame("Button", "ClassToolkitDone", frame, "UIPanelButtonTemplate")
  done:SetWidth(80)
  done:SetHeight(22)
  done:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -20, 40)
  done:SetText("Done")
  done:SetScript("OnClick", function() frame:Hide() end)

  local credit = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  credit:SetPoint("BOTTOM", frame, "BOTTOM", 0, 20)
  credit:SetText(GREY .. "Made by " .. END .. "|cffabd473stealthzi" .. END .. GREY .. "   v" .. CTK.VERSION .. END)
end

function CTK.RefreshOptions()
  if not frame or not frame:IsShown() or not CTK.char then return end
  local class = CTK.Class()
  classText:SetText(GREY .. "What shows on this " .. (class and string.lower(class) or "character") .. END)

  -- Switches that don't apply to this class are left out, and the rest close up.
  local y = -64
  for i = 1, table.getn(checks) do
    local check = checks[i]
    local t = check.toggle
    if not t.class or t.class == class then
      check:ClearAllPoints()
      check:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, y)
      check:SetChecked(CTK.char[t.key])
      check:Show()
      y = y - ROW
    else
      check:Hide()
    end
  end

  y = y - 12
  watchHeader:ClearAllPoints()
  watchHeader:SetPoint("TOPLEFT", frame, "TOPLEFT", 24, y)
  y = y - 22
  local watched = CTK.char.watched
  for i = 1, CTK.MAX_WATCHED do
    local line = watchLines[i]
    line.text:ClearAllPoints()
    line.text:SetPoint("TOPLEFT", frame, "TOPLEFT", 30, y - 3)
    line.remove:ClearAllPoints()
    line.remove:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -24, y)
    if watched[i] then
      local known = CTK.KnowsSpell(watched[i])
      line.text:SetText((known and WHITE or GREY) .. watched[i] .. END .. (known and "" or GREY .. "  (not learned)" .. END))
      line.remove:Show()
    elseif i == 1 then
      line.text:SetText(GREY .. "None yet. Add one below." .. END)
      line.remove:Hide()
    else
      line.text:SetText("")
      line.remove:Hide()
    end
    y = y - 22
  end

  y = y - 6
  addBox:ClearAllPoints()
  addBox:SetPoint("TOPLEFT", frame, "TOPLEFT", 32, y)
  addButton:ClearAllPoints()
  addButton:SetPoint("LEFT", addBox, "RIGHT", 10, 0)
  if table.getn(watched) >= CTK.MAX_WATCHED then addButton:Disable() else addButton:Enable() end

  lockButton:SetText(CTK.movingIcons and "Lock icons" or "Unlock icons")
end

function CTK.ToggleOptions()
  if not frame then Build() end
  if frame:IsShown() then frame:Hide() else frame:Show() end
end
