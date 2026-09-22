-- Class Toolkit: DoT timers for the spell ready icons. A watched spell that does damage over time
-- (Corruption, Serpent Sting, Rend, Moonfire, Immolate...) counts down on its icon while it ticks on
-- the target you have, says "ending" for the last seconds, then APPLY. Only the current target counts.
--
-- How it knows, on a 1.12 client that never says who cast a debuff or how long it lasts:
-- - Whether a spell is a DoT, and for how long, comes from its own tooltip ("...damage over 18 sec").
-- - Your casts are seen through the game's cast functions (CastSpellByName, CastSpell, UseAction).
-- - The DoT counts as landed when the combat log says "<target> is afflicted by <spell>." right after
--   one of your casts, and as gone when it says "<spell> fades from <target>." or the target dies.
-- - The target's debuff icons are checked too: if yours is not there any more, the timer stops.
-- Targets are told apart by GUID with SuperWoW, by name without it.

local CTK = ClassToolkit

local PENDING_WINDOW = 6     -- seconds a cast stays "pending" waiting for its afflicted message
local dots = {}              -- [target key][spell lowercase] = { at, duration, target, seen }
local pending = nil          -- { name, key, target, at }

local function TargetKey(unit)
  return CTK.UnitGuid(unit) or UnitName(unit)
end

-- How long this spell ticks: the number you gave with /ctk dot, else what its tooltip says. nil when it
-- isn't a DoT (or you switched its timer off).
function CTK.DotDuration(name)
  if not name then return nil end
  local c = CTK.char
  local manual = c and c.dotTimes and c.dotTimes[string.lower(name)]
  if manual == 0 then return nil end
  if manual then return manual end
  return CTK.SpellDotDuration(name)
end

-- One of your casts just went out: remember it until the combat log confirms the DoT landed.
local function Remember(name)
  if not name or not CTK.char or not CTK.HasAttackableTarget() then return end
  name = string.gsub(name, "%s*%(.-%)$", "")   -- "Corruption(Rank 2)" -> "Corruption"
  local proper = CTK.KnownSpellName(name)
  if not proper or not CTK.DotDuration(proper) then return end
  pending = { name = proper, key = TargetKey("target"), target = UnitName("target"), at = GetTime() }
end

local function Landed(target, spell)
  if not pending or GetTime() - pending.at > PENDING_WINDOW then return end
  if string.lower(pending.name) ~= string.lower(spell) then return end
  if pending.target ~= target then return end
  local duration = CTK.DotDuration(pending.name)
  if not duration then return end
  dots[pending.key] = dots[pending.key] or {}
  dots[pending.key][string.lower(pending.name)] = { at = GetTime(), duration = duration, target = target, seen = false }
  CTK.Debug(pending.name .. " landed on " .. target .. " for " .. duration .. " sec")
  pending = nil
end

local function Faded(target, spell)
  spell = string.lower(spell)
  for _, list in pairs(dots) do
    local entry = list[spell]
    if entry and entry.target == target then list[spell] = nil end
  end
end

local function Died(target)
  for key, list in pairs(dots) do
    for spell, entry in pairs(list) do
      if entry.target == target then list[spell] = nil end
    end
  end
end

-- Old entries are dropped now and then so a long session doesn't collect every mob ever fought.
local lastPrune = 0
local function Prune()
  if GetTime() - lastPrune < 30 then return end
  lastPrune = GetTime()
  for key, list in pairs(dots) do
    local any = false
    for spell, entry in pairs(list) do
      if GetTime() - entry.at > entry.duration + 5 then list[spell] = nil else any = true end
    end
    if not any then dots[key] = nil end
  end
end

-- For the target you have right now: seconds left on your DoT (nil if none running), and whether a
-- debuff with this spell's icon is on it at all (someone's, or yours past what the timer knew).
function CTK.DotOnTarget(name)
  Prune()
  if not CTK.HasAttackableTarget() then return nil, false end
  local key = TargetKey("target")
  local lower = string.lower(name)
  local entry = dots[key] and dots[key][lower]
  local texture = CTK.SpellTexture(name)
  local onTarget = false
  if texture then
    for i = 1, 16 do
      local t = UnitDebuff("target", i)
      if not t then break end
      if t == texture then
        onTarget = true
        break
      end
    end
  end
  if not entry then return nil, onTarget end
  if onTarget then entry.seen = true end
  local left = entry.at + entry.duration - GetTime()
  -- Seen on the target once, gone now: dispelled, or the mob changed. Trust what the target shows.
  if left <= 0 or (entry.seen and not onTarget and GetTime() - entry.at > 1.5) then
    dots[key][lower] = nil
    return nil, onTarget
  end
  return left, onTarget
end

-- Chat help: which watched spells count as DoTs and for how long.
function CTK.PrintDots()
  local watched = CTK.char.watched or {}
  local any = false
  for i = 1, table.getn(watched) do
    local name = watched[i]
    if CTK.KnowsSpell(name) then
      local d = CTK.DotDuration(name)
      local manual = CTK.char.dotTimes and CTK.char.dotTimes[string.lower(name)]
      if d then
        any = true
        CTK.Print("|cffffffff" .. name .. "|r: DoT, " .. d .. " sec" .. (manual and " (set by you)" or " (from its tooltip)"))
      elseif manual == 0 then
        any = true
        CTK.Print("|cffffffff" .. name .. "|r: DoT timer switched off by you (/ctk dot " .. name .. " auto to bring it back)")
      end
    end
  end
  if not any then
    CTK.Print("none of your watched spells looks like a DoT. If one is, tell me: /ctk dot <spell> <seconds>.")
  end
end

-- /ctk dot <spell> <seconds> | off | auto
function CTK.SetDot(rest)
  local _, _, name, value = string.find(rest or "", "^(.-)%s+(%S+)$")
  if not name then
    CTK.PrintDots()
    return
  end
  local proper = CTK.KnownSpellName(name)
  if not proper then
    CTK.Print("you don't know a spell called '" .. name .. "'. Check the spelling in your spellbook.")
    return
  end
  if type(CTK.char.dotTimes) ~= "table" then CTK.char.dotTimes = {} end
  local key = string.lower(proper)
  value = string.lower(value)
  if value == "off" then
    CTK.char.dotTimes[key] = 0
    CTK.Print("no DoT timer for " .. proper .. ".")
  elseif value == "auto" then
    CTK.char.dotTimes[key] = nil
    local d = CTK.SpellDotDuration(proper)
    CTK.Print(proper .. (d and (" reads as a " .. d .. " sec DoT from its tooltip.") or " does not read as a DoT from its tooltip."))
  elseif tonumber(value) and tonumber(value) > 0 then
    CTK.char.dotTimes[key] = math.floor(tonumber(value))
    CTK.Print(proper .. " is a " .. CTK.char.dotTimes[key] .. " sec DoT. Watch it with /ctk watch " .. proper .. " if you haven't.")
  else
    CTK.Print("say how long it lasts: /ctk dot " .. proper .. " 18, or off, or auto.")
  end
end

function CTK.InitDots()
  -- Every way a spell goes out passes through one of these.
  local origByName, origCast, origUse = CastSpellByName, CastSpell, UseAction
  CastSpellByName = function(name, onSelf)
    if not onSelf then Remember(name) end
    return origByName(name, onSelf)
  end
  CastSpell = function(index, book)
    if book == "spell" or book == BOOKTYPE_SPELL then Remember(GetSpellName(index, book)) end
    return origCast(index, book)
  end
  UseAction = function(slot, checkCursor, onSelf)
    if not onSelf then Remember(CTK.ActionName(slot)) end
    return origUse(slot, checkCursor, onSelf)
  end

  local f = CreateFrame("Frame")
  local events = { "CHAT_MSG_SPELL_PERIODIC_CREATURE_DAMAGE", "CHAT_MSG_SPELL_PERIODIC_HOSTILEPLAYER_DAMAGE",
    "CHAT_MSG_SPELL_AURA_GONE_OTHER", "CHAT_MSG_COMBAT_HOSTILE_DEATH", "SPELLCAST_FAILED", "SPELLCAST_INTERRUPTED" }
  for i = 1, table.getn(events) do
    pcall(f.RegisterEvent, f, events[i])
  end
  f:SetScript("OnEvent", function()
    if event == "SPELLCAST_FAILED" or event == "SPELLCAST_INTERRUPTED" then
      pending = nil
    elseif event == "CHAT_MSG_SPELL_AURA_GONE_OTHER" then
      local _, _, spell, target = string.find(arg1 or "", "^(.-) fades from (.-)%.$")
      if spell and target then Faded(target, spell) end
    elseif event == "CHAT_MSG_COMBAT_HOSTILE_DEATH" then
      local _, _, target = string.find(arg1 or "", "^(.-) dies%.$")
      if target then Died(target) end
    else
      local _, _, target, spell = string.find(arg1 or "", "^(.-) is afflicted by (.-)%.$")
      if spell and target then
        spell = string.gsub(spell, "%s*%(%d+%)$", "")   -- "Deadly Poison (2)" -> "Deadly Poison"
        Landed(target, spell)
      end
    end
  end)
end
