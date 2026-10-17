-- Class Toolkit: tick bar. Mana and energy come back in steps every 2 seconds. A thin bar counts down to
-- the next step, learned from when your mana or energy last went up.
-- Mana users also see the five second rule: after you spend mana, spirit regen stops for 5 seconds. The
-- bar fills in purple over those 5 seconds, then goes back to the tick countdown.
-- Hidden when you are full and out of combat, and for rage.

local CTK = ClassToolkit

local TICK = 2
local FSR = 5
local SLACK = 0.35       -- a rise this close to the 2 second beat counts as a tick
local LOST = 4.5         -- no tick for this long: the next rise starts the beat again

local bar
local tickAt = {}        -- [power type] = when the last tick came
local lastPower, lastType
local fsrAt

local function PowerType()
  local t = UnitPowerType("player")
  if t == 0 or t == 3 then return t end
  return nil             -- rage (1) and focus (2) don't tick like this
end

-- A rise in mana or energy: is it the regular tick? Potions, Thistle Tea and the like come off the beat.
local function Rise(kind, now)
  local last = tickAt[kind]
  if not last or now - last > LOST then
    tickAt[kind] = now
    return
  end
  local since = now - last
  local beats = math.floor(since / TICK + 0.5)
  if beats >= 1 and math.abs(since - beats * TICK) <= SLACK then tickAt[kind] = now end
end

local function OnPower()
  if arg1 and arg1 ~= "player" then return end
  local kind = PowerType()
  local power = UnitMana("player")
  if kind and kind == lastType and lastPower then
    local now = GetTime()
    if power > lastPower then
      Rise(kind, now)
    elseif power < lastPower and kind == 0 then
      fsrAt = now
    end
  end
  lastPower, lastType = power, kind
end

local elapsed = 0
local function OnUpdate()
  if not bar or CTK.movingIcons then return end
  elapsed = elapsed + arg1
  if elapsed < 0.03 then return end
  elapsed = 0
  local c = CTK.char
  local kind = PowerType()
  if not c or not c.tick or not kind or UnitIsDeadOrGhost("player") then
    bar:Hide()
    return
  end
  local full = UnitMana("player") >= UnitManaMax("player")
  if full and not UnitAffectingCombat("player") then
    bar:Hide()
    return
  end

  local now = GetTime()
  if kind == 0 and fsrAt and now - fsrAt < FSR then
    local t = now - fsrAt
    bar:SetStatusBarColor(0.65, 0.3, 1)
    bar:SetValue(t / FSR)
    bar.label:SetText("5 sec rule")
    bar.time:SetText(string.format("%.1f", FSR - t))
    bar:Show()
    return
  end

  local last = tickAt[kind]
  if not last then
    bar:Hide()
    return
  end
  local left = TICK - math.mod(now - last, TICK)
  if kind == 0 then
    bar:SetStatusBarColor(0.25, 0.5, 1)
    bar.label:SetText("Mana tick")
  else
    bar:SetStatusBarColor(1, 0.85, 0.1)
    bar.label:SetText("Energy tick")
  end
  bar:SetValue(1 - left / TICK)
  bar.time:SetText(string.format("%.1f", left))
  bar:Show()
end

local function Update()
  if not bar then return end
  if CTK.movingIcons and CTK.char.tick and PowerType() then
    bar:SetStatusBarColor(0.25, 0.5, 1)
    bar:SetValue(0.6)
    bar.label:SetText("Tick bar (drag)")
    bar.time:SetText("0.8")
    bar:EnableMouse(true)
    bar:Show()
  else
    bar:EnableMouse(false)
    if not CTK.char.tick or not PowerType() then bar:Hide() end
  end
end

function CTK.InitTick()
  bar = CTK.CreateBar("ClassToolkitTickBar", UIParent, 150, 12)
  bar:SetFrameStrata("MEDIUM")
  bar:SetMinMaxValues(0, 1)
  bar:EnableMouse(false)
  CTK.MakeDraggable(bar, "tick", -200, -200)

  local driver = CreateFrame("Frame")
  local events = { "UNIT_MANA", "UNIT_ENERGY", "UNIT_DISPLAYPOWER", "PLAYER_ENTERING_WORLD" }
  for i = 1, table.getn(events) do pcall(driver.RegisterEvent, driver, events[i]) end
  driver:SetScript("OnEvent", OnPower)
  driver:SetScript("OnUpdate", OnUpdate)
  CTK.RegisterModule({ update = Update })
end
