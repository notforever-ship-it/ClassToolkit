-- Class Toolkit: cooldown pulse. When a spell with a long cooldown (over 7 seconds, so not Arcane Shot) comes
-- back, its icon pops up in the middle of the screen for about a second and fades away, so you know to
-- use it again. Several at once take turns. Unlock the icons to move it.

local CTK = ClassToolkit

local SIZE = 48
local MIN_COOLDOWN = 7               -- seconds; short ones like Arcane Shot (6) would flash all the time
local FADE_IN, HOLD, FADE_OUT = 0.15, 0.6, 0.45
local QUESTION = "Interface\\Icons\\INV_Misc_QuestionMark"
local BOOK = "spell"

local frame
local cooling = {}     -- [spell name] = { texture, ends }
local queue = {}       -- spells waiting their turn to pulse
local showing, shownAt

-- Note every spell that is on a real cooldown right now, and when it comes back.
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
    end
    i = i + 1
  end
end

local function StartPulse(entry)
  showing = entry
  shownAt = GetTime()
  frame.icon:SetTexture(entry.texture or QUESTION)
  frame.label:SetText("")
  frame:SetAlpha(0)
  frame:Show()
end

local elapsed = 0
local function OnUpdate()
  if not CTK.char or CTK.movingIcons then return end
  local now = GetTime()

  -- The pulse on screen: fade in, stay a moment, fade out, then the next one in line.
  if showing then
    local t = now - shownAt
    if t < FADE_IN then
      frame:SetAlpha(t / FADE_IN)
    elseif t < FADE_IN + HOLD then
      frame:SetAlpha(1)
    elseif t < FADE_IN + HOLD + FADE_OUT then
      frame:SetAlpha(1 - (t - FADE_IN - HOLD) / FADE_OUT)
    else
      showing = nil
      frame:Hide()
    end
  end
  if not showing and table.getn(queue) > 0 then
    StartPulse(table.remove(queue, 1))
  end

  elapsed = elapsed + arg1
  if elapsed < 0.1 then return end
  elapsed = 0

  for name, entry in pairs(cooling) do
    if now >= entry.ends then
      cooling[name] = nil
      -- Make sure it really is back, not pushed back or started again.
      local left = CTK.SpellCooldown(name)
      if left > 0.2 then
        cooling[name] = { texture = entry.texture, ends = now + left }
      elseif CTK.char.pulse and not UnitIsDeadOrGhost("player") and table.getn(queue) < 3 then
        table.insert(queue, entry)
      end
    end
  end
end

-- While the icons are unlocked it stays on screen with a sample icon, so it can be dragged.
local function Update()
  if not frame then return end
  if CTK.movingIcons and CTK.char.pulse then
    showing = nil
    queue = {}
    frame.icon:SetTexture(CTK.SpellTexture(CTK.char.watched[1] or "") or QUESTION)
    frame:SetAlpha(1)
    CTK.SetIconState(frame, 0.3, 1, 0.3, "Cooldown ready (drag)")
    frame:EnableMouse(true)
    frame:Show()
  else
    frame:EnableMouse(false)
    if not showing then frame:Hide() end
  end
end

function CTK.InitPulse()
  frame = CTK.CreateIcon("ClassToolkitPulse", UIParent, SIZE)
  frame:SetFrameStrata("HIGH")
  frame:EnableMouse(false)
  CTK.SetIconState(frame, 0.3, 1, 0.3, "")
  CTK.MakeDraggable(frame, "pulse", 0, 120)

  local driver = CreateFrame("Frame")
  driver:RegisterEvent("SPELL_UPDATE_COOLDOWN")
  driver:RegisterEvent("PLAYER_ENTERING_WORLD")
  driver:SetScript("OnEvent", Scan)
  driver:SetScript("OnUpdate", OnUpdate)
  CTK.RegisterModule({ update = Update })
end
