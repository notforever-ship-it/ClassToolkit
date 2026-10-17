-- Class Toolkit: interrupt alert. When your enemy target starts casting, a big icon says "CASTING: <spell>",
-- counts the cast down, flashes once and plays a sound. Next to it sits your interrupt or stun, and whether
-- it is ready. It goes away when the cast ends, is interrupted, or you change target.
--
-- The cast start comes from the combat log ("Kobold Geomancer begins to cast Fireball."), English clients
-- only. With SuperWoW the game's own cast events are used as well, which also give the cast time.
-- Without them the cast time is learned from earlier casts of the same spell, or guessed at 3 seconds.

local CTK = ClassToolkit

local SIZE = 52
local GUESS = 3          -- seconds, for a spell whose cast time is not known yet
local FLASH_TIME = 0.6
local QUESTION = "Interface\\Icons\\INV_Misc_QuestionMark"

-- Spells that stop a cast, best first. War Stomp (Tauren) is added for everyone.
local ANSWERS = {
  ROGUE = { "Kick", "Gouge", "Kidney Shot" },
  WARRIOR = { "Pummel", "Shield Bash", "Concussion Blow" },
  MAGE = { "Counterspell" },
  SHAMAN = { "Earth Shock" },
  DRUID = { "Bash", "Feral Charge" },
  PRIEST = { "Silence" },
  WARLOCK = { { pet = "Spell Lock" }, "Death Coil" },
  PALADIN = { "Hammer of Justice" },
  HUNTER = { "Scatter Shot", "Intimidation" },
}

local START_EVENTS = {
  "CHAT_MSG_SPELL_CREATURE_VS_CREATURE_DAMAGE", "CHAT_MSG_SPELL_CREATURE_VS_SELF_DAMAGE",
  "CHAT_MSG_SPELL_CREATURE_VS_PARTY_DAMAGE", "CHAT_MSG_SPELL_HOSTILEPLAYER_DAMAGE",
  "CHAT_MSG_SPELL_CREATURE_VS_CREATURE_BUFF", "CHAT_MSG_SPELL_CREATURE_VS_SELF_BUFF",
  "CHAT_MSG_SPELL_CREATURE_VS_PARTY_BUFF", "CHAT_MSG_SPELL_HOSTILEPLAYER_BUFF",
}
-- Where "You interrupt Kobold Geomancer's Fireball." and the like show up.
local INTERRUPT_EVENTS = {
  "CHAT_MSG_SPELL_SELF_DAMAGE", "CHAT_MSG_SPELL_PET_DAMAGE", "CHAT_MSG_SPELL_PARTY_DAMAGE",
  "CHAT_MSG_SPELL_FRIENDLYPLAYER_DAMAGE",
}

local frame
local cast          -- { who, spell, started, ends, guessed }
local flashAt
local channelAt     -- when SuperWoW last said a channel started

-- The class's list with War Stomp on the end.
local function AnswerList()
  local list = {}
  local own = ANSWERS[CTK.Class() or ""] or {}
  for i = 1, table.getn(own) do table.insert(list, own[i]) end
  table.insert(list, "War Stomp")
  return list
end

local function CastTimes()
  if type(CTK.db.castTimes) ~= "table" then CTK.db.castTimes = {} end
  return CTK.db.castTimes
end

local function Stop(why)
  if cast then CTK.Debug("cast alert off: " .. tostring(why)) end
  cast = nil
  if frame and not CTK.movingIcons then frame:Hide() end
end

local function ShowAnswer()
  local name, state, left, texture = CTK.BestAnswer(AnswerList())
  local a = frame.answer
  if not name then
    a:Hide()
    return
  end
  a.icon:SetTexture(texture or QUESTION)
  if state == "ready" then
    CTK.SetIconState(a, 0.3, 1, 0.3, "READY")
    a.icon:SetVertexColor(1, 1, 1)
    a.count:SetText("")
  elseif state == "cooldown" then
    CTK.SetIconState(a, 0.6, 0.6, 0.6, name)
    a.icon:SetVertexColor(0.45, 0.45, 0.45)
    a.count:SetText(math.ceil(left))
  elseif state == "range" then
    CTK.SetIconState(a, 1, 0.25, 0.25, "too far")
    a.icon:SetVertexColor(1, 0.4, 0.4)
    a.count:SetText("")
  else
    CTK.SetIconState(a, 0.4, 0.6, 1, "can't now")
    a.icon:SetVertexColor(0.5, 0.5, 1)
    a.count:SetText("")
  end
  a:Show()
end

-- Your own icon for the spell if you have it, else SuperWoW's, else a question mark.
local function SpellIcon(spell, texture)
  return CTK.SpellTexture(spell) or texture or QUESTION
end

local function Start(who, spell, seconds, texture)
  if not CTK.char or not CTK.char.interrupt or CTK.movingIcons then return end
  if UnitIsDeadOrGhost("player") then return end
  local now = GetTime()
  -- The same cast seen twice (SuperWoW and the combat log): keep the first, take a cast time if it brings one.
  if cast and cast.spell == spell and now - cast.started < 1 then
    if seconds and cast.guessed then
      cast.ends = cast.started + seconds
      cast.guessed = false
    end
    return
  end
  local known = seconds or CastTimes()[spell]
  cast = { who = who, spell = spell, started = now, ends = now + (known or GUESS), guessed = not known }
  frame.icon:SetTexture(SpellIcon(spell, texture))
  frame.title:SetText("CASTING: " .. spell)
  CTK.SetIconState(frame, 1, 0.2, 0.2, who)
  flashAt = now
  frame.flash:SetAlpha(1)
  frame.flash:Show()
  pcall(PlaySound, "RaidWarning")
  ShowAnswer()
  frame:Show()
  CTK.Debug("cast alert: " .. who .. " casts " .. spell .. ", " .. string.format("%.1f", cast.ends - now) ..
    (cast.guessed and " s (guessed)" or " s"))
end

-- The cast went off: remember how long it took, the shortest seen (pushback only makes casts longer).
local function Finished(spell)
  if not cast or cast.spell ~= spell then return end
  local took = GetTime() - cast.started
  if took >= 0.4 and took <= 8 then
    local times = CastTimes()
    if not times[spell] or took < times[spell] then times[spell] = took end
  end
  Stop("cast finished")
end

local function TargetIs(who)
  return who and CTK.HasAttackableTarget() and UnitName("target") == who
end

local function OnCombatLog()
  local msg = arg1
  if not msg then return end

  local _, _, who, spell = string.find(msg, "^(.-) begins to cast (.+)%.$")
  if not who then _, _, who, spell = string.find(msg, "^(.-) begins to perform (.+)%.$") end
  if who then
    if TargetIs(who) then Start(who, spell) end
    return
  end
  if not cast then return end

  local _, _, victim, cut = string.find(msg, "^You interrupt (.-)'s (.+)%.$")
  if not victim then _, _, victim, cut = string.find(msg, "^.- interrupts (.-)'s (.+)%.$") end
  if not victim then _, _, victim, cut = string.find(msg, "^(.-)'s (.+) is interrupted%.$") end
  if victim then
    if victim == cast.who then Stop("interrupted") end
    return
  end

  -- Anything else from the caster that names the spell means it went off ("...'s Fireball hits you").
  if string.find(msg, cast.spell, 1, true) and
    (string.sub(msg, 1, string.len(cast.who)) == cast.who or string.find(msg, "afflicted by", 1, true)) then
    Finished(cast.spell)
  end
end

-- SuperWoW: arg1 caster, arg3 START / CAST / FAIL / CHANNEL, arg4 spell id, arg5 cast time.
local function OnCastEvent()
  if not CTK.char or not CTK.char.interrupt then return end
  local guid = CTK.UnitGuid("target")
  if not guid or arg1 ~= guid or not CTK.HasAttackableTarget() then return end
  if arg3 == "START" or arg3 == "CHANNEL" then
    local name, texture
    if SpellInfo then
      local ok, n, _, t = pcall(SpellInfo, arg4)
      if ok then name, texture = n, t end
    end
    if not name then return end
    local seconds = tonumber(arg5)
    if seconds and seconds > 100 then seconds = seconds / 1000 end   -- milliseconds
    if seconds and seconds <= 0 then seconds = nil end
    if arg3 == "CHANNEL" then channelAt = GetTime() end
    Start(UnitName("target") or "?", name, seconds, texture)
  elseif (arg3 == "CAST" or arg3 == "FAIL") and cast then
    if channelAt and GetTime() - channelAt < 0.2 then return end   -- a channel's own start
    if arg3 == "CAST" then Finished(cast.spell) else Stop("cast failed") end
  end
end

local elapsed = 0
local function OnUpdate()
  if not frame or CTK.movingIcons then return end
  local now = GetTime()
  if flashAt then
    local t = now - flashAt
    if t < FLASH_TIME then
      frame.flash:SetAlpha(1 - t / FLASH_TIME)
    else
      flashAt = nil
      frame.flash:Hide()
    end
  end
  if not cast then return end
  elapsed = elapsed + arg1
  if elapsed < 0.05 then return end
  elapsed = 0

  if UnitIsDeadOrGhost("player") or not TargetIs(cast.who) then
    Stop("target gone")
    return
  end
  local left = cast.ends - now
  if left < -0.5 then
    Stop("timed out")
    return
  end
  if left < 0 then left = 0 end
  frame.count:SetText((cast.guessed and "~" or "") .. string.format("%.1f", left))
  ShowAnswer()
end

-- While unlocked it shows a sample so it can be dragged.
local function Update()
  if not frame then return end
  if CTK.movingIcons and CTK.char.interrupt then
    cast = nil
    frame.flash:Hide()
    frame.icon:SetTexture("Interface\\Icons\\Spell_Fire_FlameBolt")
    frame.title:SetText("CASTING: Fireball")
    frame.count:SetText("2.1")
    CTK.SetIconState(frame, 1, 0.2, 0.2, "Interrupt alert (drag)")
    ShowAnswer()
    frame:EnableMouse(true)
    frame:Show()
  else
    frame:EnableMouse(false)
    if not CTK.char.interrupt or not cast then
      cast = nil
      frame:Hide()
    end
  end
end

function CTK.InitInterrupt()
  frame = CTK.CreateIcon("ClassToolkitInterrupt", UIParent, SIZE)
  frame:SetFrameStrata("HIGH")
  frame:EnableMouse(false)
  frame.label:SetFont(STANDARD_TEXT_FONT, 12)
  frame.count:SetFont(STANDARD_TEXT_FONT, 18, "OUTLINE")
  CTK.MakeDraggable(frame, "interrupt", -200, 160)

  frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  frame.title:SetPoint("BOTTOM", frame, "TOP", 0, 8)
  frame.title:SetFont(STANDARD_TEXT_FONT, 18, "OUTLINE")
  frame.title:SetTextColor(1, 0.25, 0.25)

  frame.flash = frame:CreateTexture(nil, "OVERLAY")
  frame.flash:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
  frame.flash:SetBlendMode("ADD")
  frame.flash:SetVertexColor(1, 0.3, 0.1)
  frame.flash:SetWidth(SIZE * 4)
  frame.flash:SetHeight(SIZE * 4)
  frame.flash:SetPoint("CENTER", frame, "CENTER", 0, 0)
  frame.flash:Hide()

  frame.answer = CTK.CreateIcon("ClassToolkitInterruptAnswer", frame, 36)
  frame.answer:SetPoint("LEFT", frame, "RIGHT", 14, 0)
  frame.answer:EnableMouse(false)

  local driver = CreateFrame("Frame")
  for i = 1, table.getn(START_EVENTS) do pcall(driver.RegisterEvent, driver, START_EVENTS[i]) end
  for i = 1, table.getn(INTERRUPT_EVENTS) do pcall(driver.RegisterEvent, driver, INTERRUPT_EVENTS[i]) end
  pcall(driver.RegisterEvent, driver, "CHAT_MSG_COMBAT_HOSTILE_DEATH")
  pcall(driver.RegisterEvent, driver, "PLAYER_TARGET_CHANGED")
  if SUPERWOW_VERSION then pcall(driver.RegisterEvent, driver, "UNIT_CASTEVENT") end
  driver:SetScript("OnEvent", function()
    if event == "UNIT_CASTEVENT" then
      OnCastEvent()
    elseif event == "PLAYER_TARGET_CHANGED" then
      if cast then Stop("target changed") end
    elseif event == "CHAT_MSG_COMBAT_HOSTILE_DEATH" then
      if cast and arg1 and string.find(arg1, cast.who .. " dies", 1, true) then Stop("caster died") end
    elseif CTK.char and CTK.char.interrupt then
      OnCombatLog()
    end
  end)
  driver:SetScript("OnUpdate", OnUpdate)
  CTK.RegisterModule({ update = Update })
end
