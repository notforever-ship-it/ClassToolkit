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
  "- Add as many spells as you like in " .. WHITE .. "/ctk" .. END .. ". Shown in combat or while you " ..
    "target an enemy; they wrap onto another line past six.",
  "- " .. WHITE .. "Ready icons: just the next one" .. END .. " keeps a single icon instead: whichever spell " ..
    "you can cast now, or the one coming back soonest.",
  "- " .. GREY .. "Grey + number" .. END .. " cooling down   " .. BLUE .. "Blue" .. END .. " not enough mana/rage/energy   " ..
    RED .. "Red" .. END .. " out of range   " .. GREEN .. "READY" .. END .. " go",
  "- " .. WHITE .. "DoTs" .. END .. ": a watched spell that does damage over time (Corruption, Serpent Sting, Rend, " ..
    "Moonfire, Immolate...) counts down in |cffb366ffpurple|r while it ticks on the target you have, turns " ..
    "|cffff9933ending|r for the last 3 seconds, then says " .. GREEN .. "APPLY" .. END .. ". Only your current target " ..
    "counts; switch targets and the icon follows.",
  "- The addon reads the DoT's length from the spell's tooltip. " .. WHITE .. "/ctk dot" .. END .. " lists what it found; " ..
    WHITE .. "/ctk dot Rend 12" .. END .. " corrects one, " .. WHITE .. "off" .. END .. " or " .. WHITE .. "auto" .. END .. " instead of a number.",
  " ",
  GOLD .. "Reagents and ammo" .. END,
  "- A chat warning when a reagent you carry runs low. " .. WHITE .. "/ctk counts" .. END .. " lists what you have.",
  "- Hunters: warnings at 200 and 50 shots, and a " .. RED .. "Low ammo" .. END .. " box on screen when you're down " ..
    "to your last 2 stacks (" .. WHITE .. "/ctk ammo 3" .. END .. " to change).",
  " ",
  GOLD .. "Range icon" .. END,
  "- Watches one spell, your class's main attack to start (Fireball, Shadow Bolt, Heroic Strike, Auto Shot...). " ..
    WHITE .. "/ctk range <spell>" .. END .. " or the box in /ctk picks another.",
  "- " .. GREEN .. "In range" .. END .. " (with the yards)  " .. GREEN .. "Melee" .. END .. "  |cffff9933Under 10 yd|r  " ..
    YELLOW .. "Under 28 yd" .. END .. "  " .. GREY .. "Out of range" .. END .. ". Hunters: " .. RED .. "Dead zone" .. END ..
    " when neither shot nor Wing Clip lands.",
  "- The spell has to be on an action bar (any slot) for its range to be read.",
  " ",
  GOLD .. "Hunters" .. END,
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
  frame:SetHeight(740)
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
  text:SetHeight(620)
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
