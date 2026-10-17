-- Class Toolkit: runner alert. When your target, or any mob while you are in a fight, "attempts to run away
-- in fear!", a big red RUNNER! shows for 3 seconds with the mob's name, the best spell you have to stop it,
-- and a sound. Read from the mob's emote, English clients only.

local CTK = ClassToolkit

local SHOW_TIME = 3
local QUESTION = "Interface\\Icons\\INV_Misc_QuestionMark"

-- Spells that stop or slow a runner, best first. War Stomp (Tauren) is added for everyone.
local STOPPERS = {
  HUNTER = { "Concussive Shot", "Wing Clip", "Scatter Shot" },
  WARRIOR = { "Hamstring", "Piercing Howl", "Intercept", "Concussion Blow" },
  MAGE = { "Frost Nova", "Frostbolt", "Cone of Cold" },
  SHAMAN = { "Frost Shock", "Earthbind Totem" },
  ROGUE = { "Kidney Shot", "Gouge" },
  PALADIN = { "Hammer of Justice" },
  DRUID = { "Entangling Roots", "Feral Charge", "Bash" },
  PRIEST = { "Mind Flay" },
  WARLOCK = { "Curse of Exhaustion", "Death Coil" },
}

local frame
local shownAt

local function StopperList()
  local list = {}
  local own = STOPPERS[CTK.Class() or ""] or {}
  for i = 1, table.getn(own) do table.insert(list, own[i]) end
  table.insert(list, "War Stomp")
  return list
end

-- Put the best stopping spell on the small icon, with READY, its cooldown, or why not.
local function ShowStopper()
  local s = frame.stop
  local name, state, left, texture = CTK.BestAnswer(StopperList())
  if not name then
    if CTK.IsClass("ROGUE") then
      s.icon:SetTexture("Interface\\Icons\\Ability_PoisonSting")
      CTK.SetIconState(s, 1, 0.82, 0, "Crippling Poison helps")
      s.count:SetText("")
      s:Show()
    else
      s:Hide()
    end
    return
  end
  s.icon:SetTexture(texture or QUESTION)
  s.count:SetText("")
  if state == "ready" then
    CTK.SetIconState(s, 0.3, 1, 0.3, name .. ": READY")
  elseif state == "cooldown" then
    CTK.SetIconState(s, 0.6, 0.6, 0.6, name)
    s.count:SetText(math.ceil(left))
  elseif state == "range" then
    CTK.SetIconState(s, 1, 0.25, 0.25, name .. ": too far")
  else
    CTK.SetIconState(s, 0.4, 0.6, 1, name .. ": can't now")
  end
  s:Show()
end

local function Alert(who)
  shownAt = GetTime()
  frame.name:SetText(who)
  ShowStopper()
  frame:Show()
  pcall(PlaySound, "RaidWarning")
  CTK.Debug("runner: " .. who)
end

local function OnEmote()
  if not CTK.char or not CTK.char.runner or CTK.movingIcons then return end
  if UnitIsDeadOrGhost("player") or not arg1 then return end
  if not string.find(arg1, "attempts to run away in fear", 1, true) then return end
  -- The text is usually "%s attempts to run away in fear!" with the mob's name in arg2.
  local who
  if string.find(arg1, "%s", 1, true) then
    who = arg2
  else
    local _
    _, _, who = string.find(arg1, "^(.-) attempts to run away in fear")
  end
  if not who or who == "" then return end
  local isTarget = UnitExists("target") and UnitName("target") == who
  if isTarget or UnitAffectingCombat("player") then Alert(who) end
end

local elapsed = 0
local function OnUpdate()
  if not frame or not shownAt or CTK.movingIcons then return end
  elapsed = elapsed + arg1
  if elapsed < 0.1 then return end
  elapsed = 0
  if GetTime() - shownAt > SHOW_TIME or UnitIsDeadOrGhost("player") then
    shownAt = nil
    frame:Hide()
    return
  end
  ShowStopper()
end

local function Update()
  if not frame then return end
  if CTK.movingIcons and CTK.char.runner then
    shownAt = nil
    frame.name:SetText("Runner alert (drag)")
    ShowStopper()
    frame:EnableMouse(true)
    frame:Show()
  else
    frame:EnableMouse(false)
    if not shownAt or not CTK.char.runner then
      shownAt = nil
      frame:Hide()
    end
  end
end

function CTK.InitRunner()
  frame = CreateFrame("Frame", "ClassToolkitRunner", UIParent)
  frame:SetWidth(200)
  frame:SetHeight(60)
  frame:SetFrameStrata("HIGH")
  frame:EnableMouse(false)
  CTK.MakeDraggable(frame, "runner", 200, 160)

  frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  frame.title:SetPoint("TOP", frame, "TOP", 0, 0)
  frame.title:SetFont(STANDARD_TEXT_FONT, 28, "OUTLINE")
  frame.title:SetTextColor(1, 0.1, 0.1)
  frame.title:SetText("RUNNER!")

  frame.name = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  frame.name:SetPoint("TOP", frame.title, "BOTTOM", 0, -4)

  frame.stop = CTK.CreateIcon("ClassToolkitRunnerStop", frame, 32)
  frame.stop:SetPoint("TOP", frame.name, "BOTTOM", 0, -6)
  frame.stop:EnableMouse(false)

  frame:Hide()

  local driver = CreateFrame("Frame")
  driver:RegisterEvent("CHAT_MSG_MONSTER_EMOTE")
  driver:SetScript("OnEvent", OnEmote)
  driver:SetScript("OnUpdate", OnUpdate)
  CTK.RegisterModule({ update = Update })
end
