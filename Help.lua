-- Class Toolkit: the "How to use" window. Opens with the Help button in /ctk or /ctk help.

local CTK = ClassToolkit

local GOLD, GREEN, RED, YELLOW, BLUE, GREY, WHITE, END =
  "|cffffd100", "|cff40ff40", "|cffff4040", "|cffffff40", "|cff6080ff", "|cff9d9d9d", "|cffffffff", "|r"
local ORANGE, PURPLE = "|cffff9933", "|cffb366ff"

local function B(s) return WHITE .. s .. END end

local HELP_LEFT = table.concat({
  GOLD .. "Start" .. END,
  "- " .. B("/ctk") .. " opens the options. Only your class's switches show.",
  "- Settings are kept per character.",
  "- " .. B("Unlock icons") .. ": drag any icon or bar. Press " .. B("Lock icons") .. " when done.",
  "- Shift-drag moves them any time.",
  "- Range checks need the spell on an " .. B("action bar") .. " (any slot, any page).",
  " ",
  GOLD .. "Swing timer" .. END,
  "- Bars count down to your next swing, Auto Shot or wand shot.",
  "- They say " .. GREEN .. "ready" .. END .. " when it is time.",
  "- Auto Shot: at the " .. RED .. "red" .. END .. " end, stand still or the shot is delayed.",
  "- With SuperWoW you get an off-hand bar too.",
  " ",
  GOLD .. "Buff reminder" .. END,
  "- An icon shows when a class buff is " .. RED .. "missing" .. END .. " or " .. YELLOW .. "running out" .. END .. ".",
  "- Running out shows the seconds left.",
  "- Click it to cast. Right-click to stop that reminder.",
  "- " .. B("/ctk buffs reset") .. " brings stopped reminders back.",
  "- Hunters: " .. B("in combat!") .. " shows if Cheetah or Pack is on in a fight.",
  " ",
  GOLD .. "Spell ready icons" .. END,
  "- Add spells in " .. B("/ctk") .. ". As many as you like.",
  "- Shown in combat or with an enemy targeted.",
  "- More than six wrap onto a new line.",
  "- " .. B("Ready icons: just the next one") .. ": one icon for the next spell ready.",
  "- " .. GREY .. "Grey + number" .. END .. ": cooling down.   " .. BLUE .. "Blue" .. END .. ": not enough mana, rage or energy.",
  "- " .. RED .. "Red" .. END .. ": out of range.   " .. GREEN .. "READY" .. END .. ": go.",
  "- " .. B("Cooldown ready flash") .. ": a spell's icon pops up mid-screen when it is back.",
  " ",
  GOLD .. "DoTs" .. END .. " (damage over time, like Corruption or Serpent Sting)",
  "- Counts down in " .. PURPLE .. "purple" .. END .. " while it ticks on your target.",
  "- Turns " .. ORANGE .. "orange" .. END .. " for the last 3 seconds, then says " .. GREEN .. "APPLY" .. END .. ".",
  "- Only your current target counts. The icon follows when you switch.",
  "- " .. B("/ctk dot") .. ": the lengths it read from the spell tooltips.",
  "- " .. B("/ctk dot Rend 12") .. " fixes one. Use " .. B("off") .. " or " .. B("auto") .. " in place of the number.",
}, "\n")

local HELP_RIGHT = table.concat({
  GOLD .. "Reagents and ammo" .. END,
  "- A chat warning when a reagent runs low.",
  "- " .. B("/ctk counts") .. " lists your reagents and ammo.",
  "- Hunters: warnings at 200 and 50 shots.",
  "- Hunters: a " .. RED .. "Low ammo" .. END .. " box when equipped ammo is down to 100 shots.",
  "- " .. B("/ctk ammo 50") .. " changes that. Only the equipped stack counts.",
  " ",
  GOLD .. "Range icon" .. END,
  "- Watches your class's main attack to start.",
  "- " .. B("/ctk range <spell>") .. ", or the box in " .. B("/ctk") .. ", picks another.",
  "- " .. GREEN .. "In range" .. END .. " (with yards), " .. GREEN .. "Melee" .. END .. ", " .. ORANGE .. "Under 10 yd" .. END ..
    ", " .. YELLOW .. "Under 28 yd" .. END .. ", " .. GREY .. "Out of range" .. END .. ".",
  "- Hunters: " .. RED .. "Dead zone" .. END .. " = neither shot nor Wing Clip lands.",
  " ",
  GOLD .. "Hunters" .. END,
  "- " .. B("Aggro meter") .. ": how close you are to pulling the mob off your pet.",
  "- It shows who the mob attacks, and what to do:",
  "- " .. GREEN .. "Shoot" .. END .. ".  " .. YELLOW .. "Ease off" .. END .. ": a crit could pull it.  " ..
    ORANGE .. "Hold" .. END .. ": your next shot pulls it.",
  "- " .. RED .. "ON YOU - Feign Death!" .. END,
  "- Early on it says Hold a lot. Let the pet bite a few times first.",
  "- Threat comes from the combat log. It learns your server's Growl.",
  "- The mob turns on you past 130% of pet threat (110% up close).",
  "- " .. B("/ctk aggro growl 170") .. " sets Growl.   " .. B("/ctk aggro reset") .. " forgets.",
  "- " .. B("Feed reminder") .. ": a face when your pet is not happy. Click it, then a food.",
  "- " .. B("Eating warning") .. ": " .. YELLOW .. "Pet is eating: don't attack" .. END .. ". Attacking ends the meal.",
  " ",
  GOLD .. "Commands" .. END,
  "- " .. B("/ctk help") .. ": this window.",
  "- " .. B("/ctk commands") .. ": every command in chat.",
  "- " .. B("/ctk debug on") .. ": shows what the addon notices, for bug reports.",
}, "\n")

local COLUMN = 420   -- width of each text column
local frame

-- Sizes a font string to its text and returns the height. If the client gives no height,
-- it counts the lines instead.
local function FitHeight(fs, text, width)
  fs:SetWidth(width)
  fs:SetHeight(0)   -- 0 = size to the text
  fs:SetText(text)
  local h = fs:GetHeight()
  if not h or h < 20 then
    local _, size = fs:GetFont()
    if type(size) ~= "number" or size < 1 then size = 12 end
    local lines = 0
    for line in string.gfind(text .. "\n", "(.-)\n") do
      fs:SetWidth(0)
      fs:SetText(line)
      local n = math.ceil((fs:GetStringWidth() or 0) / (width * 0.9))
      if n < 1 then n = 1 end
      lines = lines + n
    end
    fs:SetWidth(width)
    fs:SetText(text)
    h = lines * (size + 2)
  end
  fs:SetHeight(h)
  return h
end

local function Build()
  frame = CreateFrame("Frame", "ClassToolkitHelp", UIParent)
  frame:SetWidth(26 + COLUMN + 24 + COLUMN + 26)
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

  -- Two columns side by side, so the window is not taller than the screen.
  local left = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  left:SetPoint("TOPLEFT", frame, "TOPLEFT", 26, -64)
  left:SetJustifyH("LEFT")
  left:SetJustifyV("TOP")
  local right = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  right:SetPoint("TOPLEFT", frame, "TOPLEFT", 26 + COLUMN + 24, -64)
  right:SetJustifyH("LEFT")
  right:SetJustifyV("TOP")
  local th = math.max(FitHeight(left, HELP_LEFT, COLUMN), FitHeight(right, HELP_RIGHT, COLUMN))
  local height = th + 64 + 60   -- title above, Got it button and credit below
  frame:SetHeight(height)
  local screen = UIParent:GetHeight()
  if screen and screen > 100 and height > screen - 40 then
    frame:SetScale((screen - 40) / height)   -- shrink to fit a small screen
  end

  local ok = CreateFrame("Button", "ClassToolkitHelpOk", frame, "UIPanelButtonTemplate")
  ok:SetWidth(120)
  ok:SetHeight(24)
  ok:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -24, 20)
  ok:SetText("Got it")
  ok:SetScript("OnClick", function() frame:Hide() end)

  local credit = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  credit:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 26, 26)
  credit:SetText(GREY .. "Made by " .. END .. "|cffabd473stealthzi" .. END .. GREY .. "   v" .. CTK.VERSION .. END)
end

function CTK.ToggleHelp()
  if not frame then Build() end
  if frame:IsShown() then frame:Hide() else frame:Show() end
end
