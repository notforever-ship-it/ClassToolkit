-- Class Toolkit: the /ctk window. Switches for what shows on this character (hunter-only ones are hidden
-- for other classes), the spells with a ready icon, and the lock for moving everything.

local CTK = ClassToolkit

local GOLD, GREY, WHITE, END = "|cffffd100", "|cff9d9d9d", "|cffffffff", "|r"
local WIDTH, HEIGHT = 520, 510
local COLUMN = 250   -- the switches sit in two columns this far apart
local MAX_LINES = 12   -- more than this and the window would run off the screen
local ROW = 26

local frame, classText, watchHeader, extraText, addBox, addButton, lockButton
local rangeText, rangeBox, rangeButton
local WatchLine
local checks = {}
local watchLines = {}

-- text is one line, or a list of short lines.
local function Explain(widget, title, text)
  widget:SetScript("OnEnter", function()
    GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
    GameTooltip:SetText(title)
    if type(text) == "table" then
      for i = 1, table.getn(text) do GameTooltip:AddLine(text[i], 1, 1, 1, 1) end
    else
      GameTooltip:AddLine(text, 1, 1, 1, 1)
    end
    GameTooltip:Show()
  end)
  widget:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

local TIPS = {
  swingMelee = { "Counts down to your next melee swing.", "SuperWoW adds an off-hand bar." },
  swingRanged = { "Counts down to your next Auto Shot or wand shot.",
    "Auto Shot: at the red end, stand still or the shot is delayed." },
  ready = { "An icon for each watched spell.", "Grey + number: cooling down.", "Blue: not enough mana.",
    "Red: out of range.", "READY: cast it.", "DoTs: purple countdown, then APPLY.",
    "Shown in combat or with an enemy targeted." },
  readyOne = { "One icon instead of a row.", "Shows the spell ready now, or back soonest." },
  pulse = { "A spell's icon counts 5 to 1 mid-screen before its cooldown ends.", "Spells with a cooldown over 7 seconds. Unlock icons to move it." },
  buffs = { "An icon when a class buff is missing or running out.", "Click: cast it.",
    "Right-click: stop that reminder." },
  reagents = { "A warning when a reagent runs low.", "Hunters: ammo at 200 and 50 shots." },
  range = { "Is your target in range of one spell?", "Starts on your class's main attack.",
    "In range, Melee, Under 10 yd, Under 28 yd, Out of range.", "Hunters also get Dead zone.",
    "The spell must be on an action bar (any slot).", "Pick another spell below." },
  aggro = { "How close you are to pulling the mob off your pet.", "Shows who the mob attacks.",
    "Says what to do: Shoot, Ease off, Hold, Feign Death.", "Learns your server's numbers as you fight." },
  feed = { "A face when your pet is not happy.", "Click it to feed." },
  eatWarn = { "Shows while your pet eats.", "Don't attack: it cancels the meal.", "Goes away when the meal is done." },
  ammoBox = { "A red box when your equipped ammo is low.", "100 shots to start. /ctk ammo 50 changes it.",
    "Also shows when a bow or gun has no ammo equipped." },
  interrupt = { "Your target starts a cast: a big CASTING icon, a flash and a sound.",
    "Counts down the cast. Shows your interrupt or stun and if it is ready.", "Goes away when the cast ends." },
  runner = { "A mob you fight runs away in fear: a big red RUNNER!", "Shows the spell to stop it with." },
  tick = { "A thin bar counting down to your next mana or energy tick (every 2 seconds).",
    "Purple after you spend mana: the 5 second rule.", "Hidden when you are full and out of combat." },
  drink = { "After a fight: Drink and Eat icons when you are low.", "Click one to use your best drink or food.",
    "40% to start. /ctk drink 30 changes it." },
  trap = { "A bar counting down your Freezing Trap on a mob.", "Learns your real trap length as it goes." },
  petHealth = { "A flashing icon when your pet is low on health.", "Click: Mend Pet (hunter) or Health Funnel (warlock).",
    "35% to start. /ctk pethealth 50 changes it." },
  sellAll = { "At a vendor: Ctrl+Right-click an item in your bags.", "Sells every stack of that item.",
    "Its tooltip says so while the vendor is open." },
}

-- One line per watched spell, made as they're added, so you can watch as many as you like.
WatchLine = function(i)
  if watchLines[i] then return watchLines[i] end
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
  return watchLines[i]
end

local function AddWatched()
  local text = addBox:GetText()
  if text and text ~= "" then
    CTK.Watch(text)
    addBox:SetText("")
  end
  addBox:ClearFocus()
end

local function SetRangeSpell()
  local text = rangeBox:GetText()
  if CTK.SetRangeSpell then CTK.SetRangeSpell(text) end
  rangeBox:SetText("")
  rangeBox:ClearFocus()
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

  -- Which spell the range icon watches, and a box to change it.
  rangeText = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  rangeBox = CreateFrame("EditBox", "ClassToolkitRangeBox", frame, "InputBoxTemplate")
  rangeBox:SetWidth(190)
  rangeBox:SetHeight(18)
  rangeBox:SetAutoFocus(false)
  rangeBox:SetScript("OnEnterPressed", SetRangeSpell)
  rangeBox:SetScript("OnEscapePressed", function() this:SetText("") this:ClearFocus() end)
  Explain(rangeBox, "Range icon spell", { "Type a spell name as your spellbook shows it.", "Press Enter or Set.",
    "Empty + Set: back to your class's main attack." })
  rangeButton = CreateFrame("Button", "ClassToolkitRangeSet", frame, "UIPanelButtonTemplate")
  rangeButton:SetWidth(70)
  rangeButton:SetHeight(20)
  rangeButton:SetText("Set")
  rangeButton:SetScript("OnClick", SetRangeSpell)

  watchHeader = frame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
  watchHeader:SetText("Spell ready icons")

  extraText = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  extraText:Hide()


  addBox = CreateFrame("EditBox", "ClassToolkitWatchBox", frame, "InputBoxTemplate")
  addBox:SetWidth(190)
  addBox:SetHeight(18)
  addBox:SetAutoFocus(false)
  addBox:SetScript("OnEnterPressed", AddWatched)
  addBox:SetScript("OnEscapePressed", function() this:SetText("") this:ClearFocus() end)
  Explain(addBox, "Add a spell", { "Type a spell name as your spellbook shows it.", "For example Arcane Shot or Overpower.",
    "Press Enter or Add.", "Add as many as you like." })

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
  Explain(lockButton, "Move the icons", { "Unlock, drag the icons and bars, then lock again.",
    "All your characters share the positions." })

  local help = CreateFrame("Button", "ClassToolkitOptionsHelp", frame, "UIPanelButtonTemplate")
  help:SetWidth(80)
  help:SetHeight(22)
  help:SetPoint("LEFT", lockButton, "RIGHT", 8, 0)
  help:SetText("Help")
  help:SetScript("OnClick", function() CTK.ToggleHelp() end)
  Explain(help, "How to use", { "What each part does.", "What the colours mean.", "Every command." })

  local done = CreateFrame("Button", "ClassToolkitDone", frame, "UIPanelButtonTemplate")
  done:SetWidth(80)
  done:SetHeight(22)
  done:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -20, 40)
  done:SetText("Done")
  done:SetScript("OnClick", function()
    if CTK.movingIcons then CTK.ToggleMoveIcons() end
    frame:Hide()
  end)

  local credit = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  credit:SetPoint("BOTTOM", frame, "BOTTOM", 0, 20)
  credit:SetText(GREY .. "Made by " .. END .. "|cffabd473stealthzi" .. END .. GREY .. "   v" .. CTK.VERSION .. END)
end

function CTK.RefreshOptions()
  if not frame or not frame:IsShown() or not CTK.char then return end
  local class = CTK.Class()
  classText:SetText(GREY .. "What shows on this " .. (class and string.lower(class) or "character") .. END)

  -- Switches that don't apply to this class are left out, and the rest close up in two columns,
  -- the left one filled first.
  local fits = {}
  for i = 1, table.getn(checks) do
    if CTK.ToggleFits(checks[i].toggle, class) then
      table.insert(fits, checks[i])
    else
      checks[i]:Hide()
    end
  end
  local perCol = math.ceil(table.getn(fits) / 2)
  for i = 1, table.getn(fits) do
    local check = fits[i]
    local col = (i > perCol) and 1 or 0
    local place = i - col * perCol - 1
    check:ClearAllPoints()
    check:SetPoint("TOPLEFT", frame, "TOPLEFT", 20 + col * COLUMN, -64 - place * ROW)
    check:SetChecked(CTK.char[check.toggle.key])
    check:Show()
  end
  local y = -64 - perCol * ROW

  -- The range icon's spell sits right under the switches.
  y = y - 4
  local spell = CTK.RangeSpell and CTK.RangeSpell()
  local yards = spell and CTK.SpellRange(spell)
  local reach = (yards == 0 and " (melee)") or (yards and (" (" .. yards .. " yd)")) or ""
  rangeText:ClearAllPoints()
  rangeText:SetPoint("TOPLEFT", frame, "TOPLEFT", 30, y)
  rangeText:SetText(GREY .. "Range icon watches: " .. END .. WHITE .. (spell or "nothing yet") .. END .. GREY .. reach .. END)
  y = y - 18
  rangeBox:ClearAllPoints()
  rangeBox:SetPoint("TOPLEFT", frame, "TOPLEFT", 32, y)
  rangeButton:ClearAllPoints()
  rangeButton:SetPoint("LEFT", rangeBox, "RIGHT", 10, 0)
  y = y - 22

  y = y - 12
  watchHeader:ClearAllPoints()
  watchHeader:SetPoint("TOPLEFT", frame, "TOPLEFT", 24, y)
  y = y - 22
  local watched = CTK.char.watched
  local count = table.getn(watched)
  local shown = count
  if shown > MAX_LINES then shown = MAX_LINES end

  if count == 0 then
    local line = WatchLine(1)
    line.text:ClearAllPoints()
    line.text:SetPoint("TOPLEFT", frame, "TOPLEFT", 30, y - 3)
    line.text:SetText(GREY .. "None yet. Add one below." .. END)
    line.remove:Hide()
    y = y - 22
  end
  for i = 1, shown do
    local line = WatchLine(i)
    line.text:ClearAllPoints()
    line.text:SetPoint("TOPLEFT", frame, "TOPLEFT", 30, y - 3)
    line.remove:ClearAllPoints()
    line.remove:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -24, y)
    local known = CTK.KnowsSpell(watched[i])
    line.text:SetText((known and WHITE or GREY) .. watched[i] .. END .. (known and "" or GREY .. "  (not learned)" .. END))
    line.remove:Show()
    y = y - 22
  end
  -- Lines left over from a longer list before.
  for i = shown + 1, table.getn(watchLines) do
    if count > 0 or i > 1 then
      watchLines[i].text:SetText("")
      watchLines[i].remove:Hide()
    end
  end
  if count > shown then
    extraText:ClearAllPoints()
    extraText:SetPoint("TOPLEFT", frame, "TOPLEFT", 30, y - 3)
    extraText:SetText(GREY .. "and " .. (count - shown) .. " more - /ctk unwatch <spell> removes one" .. END)
    extraText:Show()
    y = y - 22
  else
    extraText:Hide()
  end

  y = y - 6
  addBox:ClearAllPoints()
  addBox:SetPoint("TOPLEFT", frame, "TOPLEFT", 32, y)
  addButton:ClearAllPoints()
  addButton:SetPoint("LEFT", addBox, "RIGHT", 10, 0)

  -- The window grows with the list so the buttons along the bottom stay clear of it.
  frame:SetHeight(-y + 18 + 88)

  lockButton:SetText(CTK.movingIcons and "Lock icons" or "Unlock icons")
end

function CTK.ToggleOptions()
  if not frame then Build() end
  if frame:IsShown() then frame:Hide() else frame:Show() end
end
