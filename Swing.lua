-- Class Toolkit: swing timer bars for melee (every class), Auto Shot (hunters) and wands (casters).
--
-- Knowing when an attack happened:
--   * With SuperWoW, UNIT_CASTEVENT reports every melee swing ("MAINHAND" / "OFFHAND") and each Auto Shot
--     or wand Shoot, so there is an off-hand bar too.
--   * Without it, a melee swing is a "You hit / You crit / You miss / You attack" combat line, or an
--     on-next-swing ability (Heroic Strike, Cleave, Raptor Strike, Maul) landing. An Auto Shot is an arrow
--     leaving the quiver while Auto Shot is on and no special shot (which uses ammo too) has just started
--     the global cooldown. A wand shot is "Your Shoot ..." in the combat log.
-- In 1.12 the last half second before an Auto Shot is the aim: moving then delays the shot, so the bar
-- marks that part in red.

local CTK = ClassToolkit

local AUTO_SHOT_ID, SHOOT_ID = 75, 5019
local AIM_TIME = 0.5
local BAR_WIDTH, BAR_HEIGHT, GAP = 180, 14, 4
local NEXT_SWING = { "Heroic Strike", "Cleave", "Raptor Strike", "Maul" }
-- Hunter spells with no cooldown of their own: if one is cooling down, that's the global cooldown.
local GCD_PROBES = { "Serpent Sting", "Hunter's Mark" }

local frame, rangedBar, mainBar, offBar
local ranged = { start = 0, duration = 0 }
local main = { start = 0, duration = 0 }
local off = { start = 0, duration = 0 }
local autoRepeat = false
local ammoSlot, lastAmmo = nil, nil
local lastShot, lastMain, lastOff = 0, 0, 0

local function GlobalCooldownJustStarted()
  for i = 1, table.getn(GCD_PROBES) do
    if CTK.KnowsSpell(GCD_PROBES[i]) then
      local left, duration = CTK.SpellCooldown(GCD_PROBES[i])
      return left > 0 and duration <= 1.6 and duration - left < 0.5
    end
  end
  return false
end

local function ShotFired()
  local now = GetTime()
  if now - lastShot < 0.4 then return end   -- the same shot seen twice
  lastShot = now
  ranged.start = now
  ranged.duration = UnitRangedDamage("player") or 0
  if ranged.duration > 0 then
    rangedBar.aim:SetWidth(BAR_WIDTH * math.min(AIM_TIME / ranged.duration, 1))
  end
end

local function SwingMain()
  local now = GetTime()
  if now - lastMain < 0.2 then return end
  lastMain = now
  main.start = now
  main.duration = UnitAttackSpeed("player") or 0
end

local function SwingOff()
  local now = GetTime()
  if now - lastOff < 0.2 then return end
  lastOff = now
  local _, offSpeed = UnitAttackSpeed("player")
  off.start = now
  off.duration = offSpeed or 0
end

------------------------------------------------------------------------------------------------
-- Drawing
------------------------------------------------------------------------------------------------

local function Countdown(bar, state, now, colour, readyWhile)
  if state.duration <= 0 then
    bar:Hide()
    return
  end
  local left = state.start + state.duration - now
  if left < -readyWhile then
    bar:Hide()
    return
  end
  bar:SetValue(1 - math.max(left, 0) / state.duration)
  if left > 0 then
    bar:SetStatusBarColor(colour[1], colour[2], colour[3])
    bar.time:SetText(string.format("%.1f", left))
  else
    bar:SetStatusBarColor(0.3, 1, 0.3)
    bar.time:SetText("ready")
  end
  bar:Show()
end

local function UpdateRanged(now)
  if ranged.duration <= 0 then
    rangedBar:Hide()
    return
  end
  local left = ranged.start + ranged.duration - now
  if left <= 0 and not autoRepeat then
    rangedBar:Hide()
    return
  end
  rangedBar:SetValue(1 - math.max(left, 0) / ranged.duration)
  local hunter = CTK.IsClass("HUNTER")
  if left > AIM_TIME or (left > 0 and not hunter) then
    rangedBar:SetStatusBarColor(1, 0.82, 0)
    rangedBar.time:SetText(string.format("%.1f", left))
  elseif left > 0 then
    rangedBar:SetStatusBarColor(1, 0.25, 0.25)
    rangedBar.time:SetText("hold still")
  else
    -- Overdue: out of range, moving, or the shot was only just turned back on.
    rangedBar:SetStatusBarColor(0.3, 1, 0.3)
    rangedBar.time:SetText("ready")
  end
  if hunter then rangedBar.aim:Show() else rangedBar.aim:Hide() end
  rangedBar:Show()
end

local elapsed = 0
local function OnUpdate()
  if not CTK.char or CTK.movingIcons then return end
  local c = CTK.char

  -- The quiver is checked every frame, so two quick shots can't slip through between looks.
  if c.swingRanged and autoRepeat and ammoSlot and not SUPERWOW_VERSION and CTK.IsClass("HUNTER") then
    local count = GetInventoryItemCount("player", ammoSlot)
    if lastAmmo and count and count < lastAmmo and not GlobalCooldownJustStarted() then
      ShotFired()
    end
    lastAmmo = count
  end

  elapsed = elapsed + arg1
  if elapsed < 0.05 then return end
  elapsed = 0

  local now = GetTime()
  if c.swingRanged then UpdateRanged(now) else rangedBar:Hide() end
  if c.swingMelee then
    Countdown(mainBar, main, now, { 0.85, 0.85, 0.85 }, 1.5)
    Countdown(offBar, off, now, { 0.6, 0.6, 0.85 }, 1.5)
  else
    mainBar:Hide()
    offBar:Hide()
  end
end

local function Update()
  if not frame then return end
  local c = CTK.char
  local moving = CTK.movingIcons and (c.swingMelee or c.swingRanged)
  frame:EnableMouse(moving and true or false)
  if moving then
    rangedBar:SetValue(0.7)
    rangedBar:SetStatusBarColor(1, 0.82, 0)
    rangedBar.time:SetText("drag me")
    rangedBar.aim:SetWidth(BAR_WIDTH * 0.2)
    if c.swingRanged then rangedBar:Show() else rangedBar:Hide() end
    mainBar:SetValue(0.4)
    mainBar:SetStatusBarColor(0.85, 0.85, 0.85)
    mainBar.time:SetText("")
    if c.swingMelee then mainBar:Show() else mainBar:Hide() end
    offBar:Hide()
  elseif CTK.movingIcons then
    rangedBar:Hide()
    mainBar:Hide()
    offBar:Hide()
  end
  -- When locked, OnUpdate takes over on the next frame.
end

------------------------------------------------------------------------------------------------
-- Events
------------------------------------------------------------------------------------------------

local function StartsWith(text, prefix)
  return string.sub(text, 1, string.len(prefix)) == prefix
end

local function MeleeLine(text)
  if StartsWith(text, "You hit ") or StartsWith(text, "You crit ") or StartsWith(text, "You miss ") or
    StartsWith(text, "You attack") then
    SwingMain()
  end
end

local function SpellLine(text)
  for i = 1, table.getn(NEXT_SWING) do
    if StartsWith(text, "Your " .. NEXT_SWING[i] .. " ") then
      SwingMain()
      return
    end
  end
  -- Wands: every shot shows up as "Your Shoot hits / crits / missed / was resisted ...".
  if not SUPERWOW_VERSION and StartsWith(text, "Your Shoot ") then ShotFired() end
end

function CTK.InitSwing()
  frame = CreateFrame("Frame", "ClassToolkitSwingTimer", UIParent)
  frame:SetWidth(BAR_WIDTH)
  frame:SetHeight(BAR_HEIGHT * 3 + GAP * 2)
  frame:SetFrameStrata("MEDIUM")
  CTK.MakeDraggable(frame, "swing", 0, -200)
  frame:EnableMouse(false)   -- don't block clicks in the middle of the screen

  rangedBar = CTK.CreateBar("ClassToolkitRangedBar", frame, BAR_WIDTH, BAR_HEIGHT)
  rangedBar:SetPoint("TOP", frame, "TOP", 0, 0)
  rangedBar.label:SetText(CTK.IsClass("HUNTER") and "Auto Shot" or "Wand")
  -- The aim: the last half second before an Auto Shot, when moving delays it.
  rangedBar.aim = rangedBar:CreateTexture(nil, "OVERLAY")
  rangedBar.aim:SetTexture(1, 0.1, 0.1, 0.35)
  rangedBar.aim:SetPoint("TOPRIGHT", rangedBar, "TOPRIGHT", 0, 0)
  rangedBar.aim:SetPoint("BOTTOMRIGHT", rangedBar, "BOTTOMRIGHT", 0, 0)
  rangedBar.aim:SetWidth(BAR_WIDTH * 0.2)

  mainBar = CTK.CreateBar("ClassToolkitMainHandBar", frame, BAR_WIDTH, BAR_HEIGHT)
  mainBar:SetPoint("TOP", rangedBar, "BOTTOM", 0, -GAP)
  mainBar.label:SetText("Melee")

  offBar = CTK.CreateBar("ClassToolkitOffHandBar", frame, BAR_WIDTH, BAR_HEIGHT)
  offBar:SetPoint("TOP", mainBar, "BOTTOM", 0, -GAP)
  offBar.label:SetText("Off hand")

  local driver = CreateFrame("Frame")
  driver:SetScript("OnUpdate", OnUpdate)

  local f = CreateFrame("Frame")
  local events = { "START_AUTOREPEAT_SPELL", "STOP_AUTOREPEAT_SPELL", "CHAT_MSG_SPELL_SELF_DAMAGE",
    "PLAYER_ENTERING_WORLD" }
  if SUPERWOW_VERSION then
    table.insert(events, "UNIT_CASTEVENT")
  else
    table.insert(events, "CHAT_MSG_COMBAT_SELF_HITS")
    table.insert(events, "CHAT_MSG_COMBAT_SELF_MISSES")
  end
  for i = 1, table.getn(events) do
    pcall(f.RegisterEvent, f, events[i])
  end

  f:SetScript("OnEvent", function()
    if event == "UNIT_CASTEVENT" then
      -- arg1 caster guid, arg3 "START"/"CAST"/"FAIL"/"CHANNEL"/"MAINHAND"/"OFFHAND", arg4 spell id
      if arg1 == CTK.UnitGuid("player") then
        if arg3 == "MAINHAND" then
          SwingMain()
        elseif arg3 == "OFFHAND" then
          SwingOff()
        elseif arg3 == "CAST" and (arg4 == AUTO_SHOT_ID or arg4 == SHOOT_ID) then
          ShotFired()
        end
      end
    elseif event == "CHAT_MSG_COMBAT_SELF_HITS" or event == "CHAT_MSG_COMBAT_SELF_MISSES" then
      if arg1 then MeleeLine(arg1) end
    elseif event == "CHAT_MSG_SPELL_SELF_DAMAGE" then
      if arg1 then SpellLine(arg1) end
    elseif event == "START_AUTOREPEAT_SPELL" then
      autoRepeat = true
      if not ammoSlot then
        local ok, slot = pcall(GetInventorySlotInfo, "AmmoSlot")
        ammoSlot = ok and slot or 0
      end
      lastAmmo = GetInventoryItemCount("player", ammoSlot)
    elseif event == "STOP_AUTOREPEAT_SPELL" then
      autoRepeat = false
    elseif event == "PLAYER_ENTERING_WORLD" then
      rangedBar.label:SetText(CTK.IsClass("HUNTER") and "Auto Shot" or "Wand")
    end
  end)

  CTK.RegisterModule({ update = Update })
end
