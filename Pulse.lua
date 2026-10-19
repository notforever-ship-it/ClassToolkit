-- Class Toolkit: cooldown countdown. 5 seconds before a spell with a long cooldown (over 7 seconds, so not
-- Arcane Shot) comes back, its icon shows in the middle of the screen with a big 5, 4, 3, 2, 1, then fades
-- away as it is ready. Several at once: the one back soonest shows first. Unlock the icons to move it.

local CTK = ClassToolkit

local SIZE = 48
local MIN_COOLDOWN = 7               -- seconds; short ones like Arcane Shot (6) would show all the time
local LEAD = 5                       -- seconds before it is back that the countdown starts
local FADE_IN, FADE_OUT = 0.15, 0.5
local QUESTION = "Interface\\Icons\\INV_Misc_QuestionMark"
local BOOK = "spell"

local frame
local cooling = {}     -- [spell name] = { texture, ends }
local showing          -- the spell name counting down right now
local shownAt, readyAt

-- Note every spell that is on a long cooldown right now, and when it comes back.
local function Scan()
  local now = GetTime()
  local i = 1
  while true do
    local name = GetSpellName(i, BOOK)
    if not name then break end
    local start, duration = GetSpellCooldown(i, BOOK)
    if start and start > 0 and duration and duration > MIN_COOLDOWN then
      local ends = start + duration
      if ends > now then
        local entry = cooling[name] or {}
        entry.texture = GetSpellTexture(i, BOOK)
        entry.ends = ends
        cooling[name] = entry
      end
    elseif start == 0 and cooling[name] then
      cooling[name] = nil      -- reset early (e.g. Readiness): it is back already
    end
    i = i + 1
  end
end

-- The spell back soonest that is inside the last 5 seconds, if any.
local function Soonest(now)
  local best, bestEnds
  for name, entry in pairs(cooling) do
    if entry.ends - now <= LEAD and (not bestEnds or entry.ends < bestEnds) then
      best, bestEnds = name, entry.ends
    end
  end
  return best
end

local function Show(name, now)
  showing = name
  shownAt = now
  readyAt = nil
  frame.icon:SetTexture(cooling[name].texture or QUESTION)
  frame.label:SetText(name)                 -- the spell name under the icon
  frame:SetAlpha(0)
  frame:Show()
end

local function OnUpdate()
  if not CTK.char or CTK.movingIcons then return end
  local now = GetTime()

  if not CTK.char.pulse or UnitIsDeadOrGhost("player") then
    if showing then
      showing = nil
      frame:Hide()
    end
    return
  end

  -- Ready: the icon fades away, then the next one in line can show.
  if readyAt then
    local t = now - readyAt
    if t < FADE_OUT then
      frame:SetAlpha(1 - t / FADE_OUT)
      return
    end
    readyAt, showing = nil, nil
    frame:Hide()
  end

  if not showing then
    local name = Soonest(now)
    if not name then return end
    Show(name, now)
  end

  local entry = cooling[showing]
  if not entry then
    showing = nil
    frame:Hide()
    return
  end
  local left = entry.ends - now
  if left <= 0 then
    -- Make sure it really is back, not pushed back or started again.
    local real = CTK.SpellCooldown(showing)
    if real > 0.2 then
      entry.ends = now + real
      if real > LEAD then
        showing = nil
        frame:Hide()
      end
      return
    end
    cooling[showing] = nil
    readyAt = now
    frame.count:SetText("")
    return
  end

  local t = now - shownAt
  frame:SetAlpha((t < FADE_IN) and (t / FADE_IN) or 1)
  frame.count:SetText(tostring(math.ceil(left)))
end

-- While the icons are unlocked it stays on screen with a sample icon, so it can be dragged.
local function Update()
  if not frame then return end
  if CTK.movingIcons and CTK.char.pulse then
    showing, readyAt = nil, nil
    frame.icon:SetTexture(CTK.SpellTexture(CTK.char.watched[1] or "") or QUESTION)
    frame.count:SetText("5")
    frame:SetAlpha(1)
    CTK.SetIconState(frame, 0.3, 1, 0.3, "Cooldown countdown (drag)")
    frame:EnableMouse(true)
    frame:Show()
  else
    frame:EnableMouse(false)
    CTK.SetIconState(frame, 0.3, 1, 0.3, "")
    if not showing then frame:Hide() end
  end
end

function CTK.InitPulse()
  frame = CTK.CreateIcon("ClassToolkitPulse", UIParent, SIZE)
  frame:SetFrameStrata("HIGH")
  frame:EnableMouse(false)
  frame.count:SetFont(STANDARD_TEXT_FONT, 30, "OUTLINE")
  CTK.SetIconState(frame, 0.3, 1, 0.3, "")
  CTK.MakeDraggable(frame, "pulse", 0, 120)

  local driver = CreateFrame("Frame")
  driver:RegisterEvent("SPELL_UPDATE_COOLDOWN")
  driver:RegisterEvent("PLAYER_ENTERING_WORLD")
  driver:SetScript("OnEvent", Scan)
  driver:SetScript("OnUpdate", OnUpdate)
  CTK.RegisterModule({ update = Update })
end
