-- Class Toolkit: the "How to use" window. Opens with the Help button in /ctk or /ctk help.

local CTK = ClassToolkit

local GOLD, GREEN, RED, YELLOW, BLUE, GREY, WHITE, END =
  "|cffffd100", "|cff40ff40", "|cffff4040", "|cffffff40", "|cff6080ff", "|cff9d9d9d", "|cffffffff", "|r"

local HELP_TEXT = table.concat({
  GOLD .. "Getting started" .. END,
  "- " .. WHITE .. "/ctk" .. END .. " opens the options. Only the switches that fit your class are shown, and " ..
    "settings are kept per character.",
  "- " .. WHITE .. "Unlock icons" .. END .. " lets you drag every icon and bar; press " .. WHITE .. "Lock icons" .. END ..
    " when you're done. Shift-drag works any time.",
  "- Range checks need the spell on an " .. WHITE .. "action bar" .. END .. ": any slot, even a page you never show.",
  " ",
  GOLD .. "Swing timer" .. END,
  "- Bars count down to your next melee swing, Auto Shot or wand shot, then say " .. GREEN .. "ready" .. END .. ".",
  "- The " .. RED .. "red" .. END .. " end of the Auto Shot bar is the aim: stand still then, or the shot is delayed.",
  "- With SuperWoW there's an off-hand bar too.",
  " ",
  GOLD .. "Buff reminder" .. END,
  "- An icon appears when a buff your class keeps up is " .. RED .. "missing" .. END .. ", or " .. YELLOW .. "running out" .. END ..
    " (with the seconds left).",
  "- Click it to cast. Right-click to stop that reminder; " .. WHITE .. "/ctk buffs reset" .. END .. " brings them back.",
  "- Hunters: a red " .. WHITE .. "in combat!" .. END .. " icon when Cheetah or Pack is still on in a fight.",
  " ",
  GOLD .. "Spell ready icons" .. END,
  "- Add up to 4 spells in " .. WHITE .. "/ctk" .. END .. ". Shown in combat or while you target an enemy.",
  "- " .. GREY .. "Grey + number" .. END .. " cooling down   " .. BLUE .. "Blue" .. END .. " not enough mana/rage/energy   " ..
    RED .. "Red" .. END .. " out of range   " .. GREEN .. "READY" .. END .. " go",
  " ",
  GOLD .. "Reagents and ammo" .. END,
  "- A chat warning when a reagent you carry runs low. " .. WHITE .. "/ctk counts" .. END .. " lists what you have.",
  "- Hunters: warnings at 200 and 50 shots, and a " .. RED .. "Low ammo" .. END .. " box on screen when you're down " ..
    "to your last 2 stacks (" .. WHITE .. "/ctk ammo 3" .. END .. " to change).",
  " ",
  GOLD .. "Hunters" .. END,
  "- Range icon: " .. GREEN .. "In range" .. END .. "  " .. RED .. "Dead zone" .. END .. "  |cffff9933Melee|r  " ..
    GREY .. "Out of range" .. END .. ". Needs Auto Shot and Wing Clip on a bar.",
  "- Feed reminder: a happiness face when your pet isn't happy. Click it, then click a food in your bags.",
  " ",
  GOLD .. "Commands" .. END,
  WHITE .. "/ctk help" .. END .. " this window     " .. WHITE .. "/ctk commands" .. END .. " every command in chat",
  WHITE .. "/ctk debug on" .. END .. " shows what the addon notices, handy for bug reports",
}, "\n")

local frame

local function Build()
  frame = CreateFrame("Frame", "ClassToolkitHelp", UIParent)
  frame:SetWidth(500)
  frame:SetHeight(650)
  frame:SetPoint("CENTER", UIParent, "CENTER", 0, 20)
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
  frame:Hide()
  table.insert(UISpecialFrames, "ClassToolkitHelp")

  local title = frame:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
  title:SetPoint("TOP", frame, "TOP", 0, -20)
  title:SetText("Class Toolkit - How to use")
  local version = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  version:SetPoint("TOP", title, "BOTTOM", 0, -2)
  version:SetText(GREY .. "version " .. CTK.VERSION .. END)

  local close = CreateFrame("Button", "ClassToolkitHelpClose", frame, "UIPanelCloseButton")
  close:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -6, -6)

  local text = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  text:SetPoint("TOPLEFT", frame, "TOPLEFT", 26, -64)
  text:SetWidth(448)
  text:SetHeight(530)
  text:SetJustifyH("LEFT")
  text:SetJustifyV("TOP")
  text:SetText(HELP_TEXT)

  local ok = CreateFrame("Button", "ClassToolkitHelpOk", frame, "UIPanelButtonTemplate")
  ok:SetWidth(120)
  ok:SetHeight(24)
  ok:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -24, 20)
  ok:SetText("Got it")
  ok:SetScript("OnClick", function() frame:Hide() end)

  local credit = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  credit:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 26, 26)
  credit:SetText(GREY .. "Made by " .. END .. "|cffabd473stealthzi" .. END)
end

function CTK.ToggleHelp()
  if not frame then Build() end
  if frame:IsShown() then frame:Hide() else frame:Show() end
end
