-- Class Toolkit: aggro meter for hunters. How close you are to pulling the mob off your pet, who the
-- mob is really attacking, and a word of advice: shoot, ease off, hold, or feign death.
--
-- The 1.12 client has no threat API, so threat is estimated from the combat log the way the threat
-- meters of the time did it: a point of damage is a point of threat, the pet's Growl adds a flat
-- amount by rank, Distracting Shot adds to yours, Feign Death wipes yours. A mob turns on you once your
-- threat passes 130% of its current target's (110% when you stand next to it). What the mob is really
-- attacking is read from the game, and whenever that disagrees with the estimate for more than a
-- second the estimate is corrected, and the pet's numbers are scaled for next time: servers change
-- what Growl is worth, and this way the meter learns it. Mobs are told apart by name, so two Goretusks
-- on you at once count as one.

local CTK = ClassToolkit

local BAR_WIDTH, BAR_HEIGHT = 180, 14
local RANGED_PULL, MELEE_PULL = 1.3, 1.1
local GROWL = { 50, 65, 110, 170, 240, 320 }        -- threat per Growl by rank, the 1.12 numbers
local DISTRACTING = { 110, 160, 250, 350, 465 }     -- Distracting Shot threat by rank
local FEIGN_ICON = "Interface\\Icons\\Ability_Rogue_FeignDeath"
local FORGET_AFTER = 120        -- seconds without a hit before a mob is forgotten
local IDLE_RESET = 10           -- seconds out of combat after which a mob's numbers start over
local HIT_WINDOW = 60           -- your hardest hit of the last minute is what your next shot may do
local SETTLE = 1                -- seconds the mob's target may disagree with the estimate before it is corrected

local ADVICE = {
  shoot = { text = "Shoot", r = 0.3, g = 1, b = 0.3 },
  ease = { text = "Ease off: a crit could pull it", r = 1, g = 0.9, b = 0.2 },
  hold = { text = "Hold: your next shot pulls it", r = 1, g = 0.6, b = 0.1 },
  over = { text = "Hold! It's about to turn on you", r = 1, g = 0.2, b = 0.2 },
  feign = { text = "ON YOU - Feign Death!", r = 1, g = 0.2, b = 0.2 },
  onyou = { text = "ON YOU - stop shooting", r = 1, g = 0.2, b = 0.2 },
  feigning = { text = "Feigning: let the pet take it", r = 0.7, g = 0.7, b = 0.7 },
  wait = { text = "Wait: your pet has no threat on it yet", r = 1, g = 0.6, b = 0.1 },
  first = { text = "Let your pet go in first", r = 0.7, g = 0.7, b = 0.7 },
}

local mobs = {}                 -- [mob name] = { me, pet, at, idle, wrongSince }
local hits = {}                 -- { at, amount }: your recent hits
local frame, bar, caption
local feigning = false
local lastMyHit = 0
local lastGrowl                 -- { target, at, amount }: taken back if the Growl turns out resisted

------------------------------------------------------------------------------------------------
-- The estimate
------------------------------------------------------------------------------------------------

local function Scale()
  local s = CTK.char and CTK.char.aggroScale
  if type(s) ~= "number" or s <= 0 then return 1 end
  return s
end

local function SetScale(s)
  if s < 0.5 then s = 0.5 end
  if s > 4 then s = 4 end
  CTK.char.aggroScale = s
end

local function Entry(name)
  local now = GetTime()
  local e = mobs[name]
  if e and e.idle and now - e.idle > IDLE_RESET then e = nil end
  if not e then
    e = { me = 0, pet = 0, at = now }
    mobs[name] = e
  end
  e.at = now
  e.idle = nil
  return e
end

local function AddMine(name, amount)
  local e = Entry(name)
  e.me = e.me + amount
end

local function AddPet(name, amount)
  local e = Entry(name)
  e.pet = e.pet + amount * Scale()
end

-- Your hardest hit of the last minute, so the advice knows what one more shot could add.
local function BigHit()
  local now, big, i = GetTime(), 0, 1
  while i <= table.getn(hits) do
    if now - hits[i].at > HIT_WINDOW then
      table.remove(hits, i)
    else
      if hits[i].amount > big then big = hits[i].amount end
      i = i + 1
    end
  end
  return big
end

-- Which rank of Growl the pet knows, from its own spellbook; by its level when the book says nothing.
local function GrowlRank()
  local i = 1
  while i < 100 do
    local name, rank = GetSpellName(i, "pet")
    if not name then break end
    if name == "Growl" and rank then
      local _, _, n = string.find(rank, "(%d+)")
      if n then return tonumber(n) end
    end
    i = i + 1
  end
  return math.floor((UnitLevel("pet") or 1) / 10) + 1
end

-- Threat of one Growl: the number you set with /ctk aggro growl, else the 1.12 value for its rank.
function CTK.GrowlThreat()
  local c = CTK.char
  if c and type(c.aggroGrowl) == "number" and c.aggroGrowl > 0 then return c.aggroGrowl end
  local rank = GrowlRank()
  if rank > table.getn(GROWL) then rank = table.getn(GROWL) end
  if rank < 1 then rank = 1 end
  return GROWL[rank]
end

local function DistractingThreat()
  local index = CTK.SpellIndex("Distracting Shot")
  local rank
  if index then
    local _, r = GetSpellName(index, "spell")
    rank = r
  end
  local _, _, n = string.find(rank or "", "(%d+)")
  n = tonumber(n) or 1
  if n > table.getn(DISTRACTING) then n = table.getn(DISTRACTING) end
  return DISTRACTING[n]
end

------------------------------------------------------------------------------------------------
-- Reading the combat log
------------------------------------------------------------------------------------------------

local function Escape(s)
  local out = string.gsub(s, "([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1")
  return out
end

-- "You hit Goretusk for 45." (melee and Auto Shot), "Your Arcane Shot crits Goretusk for 90 Arcane damage."
-- and "You cast Distracting Shot on Goretusk." (no damage in 1.12, only threat).
local function MyLine(text)
  local _, _, target, amount = string.find(text, "^You %a+ (.-) for (%d+)")
  if not target then _, _, target, amount = string.find(text, "^Your .- hits (.-) for (%d+)") end
  if not target then _, _, target, amount = string.find(text, "^Your .- crits (.-) for (%d+)") end
  if target then
    AddMine(target, tonumber(amount))
    table.insert(hits, { at = GetTime(), amount = tonumber(amount) })
    lastMyHit = GetTime()
    return
  end
  _, _, target = string.find(text, "^You %a+ Distracting Shot on (.-)%.$")
  if target then AddMine(target, DistractingThreat()) end
end

-- "Goretusk suffers 12 Nature damage from your Serpent Sting."
local function TickLine(text)
  local _, _, target, amount = string.find(text, "^(.-) suffers (%d+) %a+ damage from your ")
  if target then AddMine(target, tonumber(amount)) end
end

-- "Boar hits Goretusk for 20.", "Boar's Bite crits Goretusk for 40.", "Boar casts Growl on Goretusk."
local function PetLine(text)
  local pet = UnitName("pet")
  if not pet then return end
  local p = Escape(pet)
  local _, _, target, amount = string.find(text, "^" .. p .. " %a+ (.-) for (%d+)")
  if not target then _, _, target, amount = string.find(text, "^" .. p .. "'s? .- hits (.-) for (%d+)") end
  if not target then _, _, target, amount = string.find(text, "^" .. p .. "'s? .- crits (.-) for (%d+)") end
  if target then
    AddPet(target, tonumber(amount))
    return
  end
  _, _, target = string.find(text, "^" .. p .. " %a+ Growl on (.-)%.$")
  if target then
    local amount = CTK.GrowlThreat()
    AddPet(target, amount)
    lastGrowl = { target = target, at = GetTime(), amount = amount * Scale() }
    CTK.Debug("Growl on " .. target .. ": +" .. math.floor(amount * Scale()) .. " pet threat")
    return
  end
  -- "Boar's Growl was resisted by Goretusk." right after the cast: that Growl did nothing.
  if lastGrowl and GetTime() - lastGrowl.at < 1 and string.find(text, "^" .. p .. "'s? Growl ") then
    local e = mobs[lastGrowl.target]
    if e then e.pet = e.pet - lastGrowl.amount end
    lastGrowl = nil
  end
end

local function DeathLine(text)
  local _, _, name = string.find(text, "^(.-) dies%.$")
  if not name then _, _, name = string.find(text, "^You have slain (.-)!$") end
  if name then mobs[name] = nil end
end

------------------------------------------------------------------------------------------------
-- Drawing
------------------------------------------------------------------------------------------------

local function Show(who, key, fill, me, pet)
  local a = ADVICE[key]
  caption:SetText(who .. " - " .. a.text)
  caption:SetTextColor(a.r, a.g, a.b)
  if fill < 0 then fill = 0 end
  if fill > 1 then fill = 1 end
  bar:SetValue(fill)
  bar:SetStatusBarColor(a.r, a.g, a.b)
  bar.label:SetText("you " .. math.floor(me + 0.5) .. "  pet " .. math.floor(pet + 0.5))
  bar.time:SetText(math.floor(fill * 100 + 0.5) .. "%")
  frame:Show()
end

local elapsed, lastPrune = 0, 0
local function OnUpdate()
  elapsed = elapsed + arg1
  if elapsed < 0.1 then return end
  elapsed = 0
  if not CTK.char or CTK.movingIcons then return end
  local c = CTK.char
  if not c.aggro or not CTK.IsClass("HUNTER") or not UnitExists("pet") or UnitIsDead("pet") or
    not CTK.HasAttackableTarget() then
    frame:Hide()
    return
  end
  local now = GetTime()
  if now - lastPrune > 30 then
    lastPrune = now
    for name, e in pairs(mobs) do
      if now - e.at > FORGET_AFTER then mobs[name] = nil end
    end
  end

  -- Feign Death wipes your threat the moment it lands.
  local feign = false
  for i = 1, 32 do
    local texture = UnitBuff("player", i)
    if not texture then break end
    if texture == FEIGN_ICON then
      feign = true
      break
    end
  end
  if feign and not feigning then
    for _, e in pairs(mobs) do e.me = 0 end
    CTK.Debug("Feign Death: your threat is reset")
  end
  feigning = feign

  local name = UnitName("target")
  local e = mobs[name]
  if e and e.idle and now - e.idle > IDLE_RESET then
    mobs[name] = nil
    e = nil
  end
  local onMe = UnitIsUnit("targettarget", "player")
  local onPet = UnitIsUnit("targettarget", "pet")
  local mult = CheckInteractDistance("target", 3) and MELEE_PULL or RANGED_PULL
  local me, pet = e and e.me or 0, e and e.pet or 0
  local line = pet * mult

  -- The mob's real target is the truth. When it has disagreed with the estimate for a second, the
  -- estimate gives way, and the pet's scale learns from it for the next fight.
  if e then
    local wrong = (onPet and me > line) or (onMe and me < line and not feign)
    if wrong then
      e.wrongSince = e.wrongSince or now
      if now - e.wrongSince > SETTLE then
        if onPet then
          local fixed = me / mult * 1.05
          if pet > 0 then SetScale(Scale() * fixed / pet) end
          e.pet = fixed
          CTK.Debug("the pet holds " .. name .. " with more threat than counted: pet scale is now " ..
            string.format("%.2f", Scale()))
        else
          if now - lastMyHit < 3 and pet > 0 then SetScale(Scale() * me / line) end
          e.me = line
          CTK.Debug(name .. " turned on you earlier than counted: pet scale is now " ..
            string.format("%.2f", Scale()))
        end
        e.wrongSince = nil
        me, pet = e.me, e.pet
        line = pet * mult
      end
    else
      e.wrongSince = nil
    end
  end

  local who
  if onMe then
    who = "ON YOU"
  elseif onPet then
    who = "Pet has it"
  elseif UnitExists("targettarget") then
    who = "On " .. (UnitName("targettarget") or "someone")
  else
    who = "Not fighting yet"
  end

  if onMe then
    local key = "onyou"
    if feign then
      key = "feigning"
    elseif CTK.KnowsSpell("Feign Death") and CTK.SpellCooldown("Feign Death") == 0 then
      key = "feign"
    end
    Show(who, key, 1, me, pet)
  elseif line <= 0 then
    if me > 0 then
      Show(who, "wait", 1, me, pet)
    else
      Show(who, "first", 0, me, pet)
    end
  else
    local head = line - me
    local big = BigHit()
    if big <= 0 then big = line * 0.25 end
    local key = "shoot"
    if head <= 0 then
      key = "over"
    elseif head <= big then
      key = "hold"
    elseif head <= big * 2 then
      key = "ease"
    end
    Show(who, key, me / line, me, pet)
  end
end

local function Update()
  if not frame then return end
  local c = CTK.char
  local on = c.aggro and CTK.IsClass("HUNTER")
  frame:EnableMouse(CTK.movingIcons and on and true or false)
  if CTK.movingIcons then
    if on then
      caption:SetText("Aggro meter (drag)")
      caption:SetTextColor(0.3, 1, 0.3)
      bar:SetValue(0.55)
      bar:SetStatusBarColor(0.3, 1, 0.3)
      bar.label:SetText("you 340  pet 620")
      bar.time:SetText("55%")
      frame:Show()
    else
      frame:Hide()
    end
  end
  -- When locked, OnUpdate takes over on the next frame.
end

------------------------------------------------------------------------------------------------
-- /ctk aggro growl <threat> | auto, /ctk aggro reset
------------------------------------------------------------------------------------------------

function CTK.SetAggro(rest)
  local _, _, what, value = string.find(rest or "", "^(%S+)%s*(%S*)$")
  what = string.lower(what or "")
  value = string.lower(value or "")
  if what == "growl" then
    if value == "" or value == "auto" then
      CTK.char.aggroGrowl = nil
      CTK.Print("Growl is counted by its rank again: " .. CTK.GrowlThreat() .. " threat" ..
        (UnitExists("pet") and "" or " once you have a pet out") .. ".")
    elseif tonumber(value) and tonumber(value) > 0 then
      CTK.char.aggroGrowl = math.floor(tonumber(value))
      CTK.Print("each Growl now counts as " .. CTK.char.aggroGrowl .. " threat.")
    else
      CTK.Print("say what one Growl is worth: /ctk aggro growl 170, or auto.")
    end
  elseif what == "reset" then
    CTK.char.aggroScale = 1
    mobs = {}
    CTK.Print("the aggro meter forgot what it learned about your pet's threat.")
  else
    CTK.Print("Growl counts as " .. CTK.GrowlThreat() .. " threat, pet scale " .. string.format("%.2f", Scale()) ..
      " (learned from fights). /ctk aggro growl <threat> | auto, /ctk aggro reset, /ctk aggro on or off.")
  end
end

------------------------------------------------------------------------------------------------
-- Setup
------------------------------------------------------------------------------------------------

function CTK.InitAggro()
  frame = CreateFrame("Frame", "ClassToolkitAggro", UIParent)
  frame:SetWidth(BAR_WIDTH)
  frame:SetHeight(BAR_HEIGHT + 16)
  frame:SetFrameStrata("MEDIUM")
  CTK.MakeDraggable(frame, "aggro", 0, -262)
  frame:EnableMouse(false)   -- don't block clicks in the middle of the screen

  caption = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  caption:SetPoint("TOP", frame, "TOP", 0, 0)
  caption:SetWidth(360)
  caption:SetJustifyH("CENTER")

  bar = CTK.CreateBar("ClassToolkitAggroBar", frame, BAR_WIDTH, BAR_HEIGHT)
  bar:SetPoint("BOTTOM", frame, "BOTTOM", 0, 0)
  bar:Show()
  frame:Hide()

  -- A hidden frame's OnUpdate never runs, so a small always-shown driver does the looking.
  local driver = CreateFrame("Frame")
  driver:SetScript("OnUpdate", OnUpdate)

  local f = CreateFrame("Frame")
  local events = { "CHAT_MSG_COMBAT_SELF_HITS", "CHAT_MSG_SPELL_SELF_DAMAGE", "CHAT_MSG_SPELL_PERIODIC_CREATURE_DAMAGE",
    "CHAT_MSG_COMBAT_PET_HITS", "CHAT_MSG_SPELL_PET_DAMAGE", "CHAT_MSG_SPELL_PET_BUFF",
    "CHAT_MSG_COMBAT_HOSTILE_DEATH", "PLAYER_REGEN_ENABLED", "UNIT_PET" }
  for i = 1, table.getn(events) do
    pcall(f.RegisterEvent, f, events[i])
  end
  f:SetScript("OnEvent", function()
    if not CTK.char or not CTK.IsClass("HUNTER") then return end
    if event == "CHAT_MSG_COMBAT_SELF_HITS" or event == "CHAT_MSG_SPELL_SELF_DAMAGE" then
      if arg1 then MyLine(arg1) end
    elseif event == "CHAT_MSG_SPELL_PERIODIC_CREATURE_DAMAGE" then
      if arg1 then TickLine(arg1) end
    elseif event == "CHAT_MSG_COMBAT_PET_HITS" or event == "CHAT_MSG_SPELL_PET_DAMAGE" or event == "CHAT_MSG_SPELL_PET_BUFF" then
      if arg1 then PetLine(arg1) end
    elseif event == "CHAT_MSG_COMBAT_HOSTILE_DEATH" then
      if arg1 then DeathLine(arg1) end
    elseif event == "PLAYER_REGEN_ENABLED" then
      -- Out of combat: your threat is gone (Feign Death, or the fight is over). The pet's is kept for
      -- a moment, because after a Feign Death it is still holding the mob.
      local now = GetTime()
      for _, e in pairs(mobs) do
        e.me = 0
        e.idle = now
      end
    elseif event == "UNIT_PET" then
      if arg1 == "player" then
        for _, e in pairs(mobs) do e.pet = 0 end
      end
    end
  end)

  CTK.RegisterModule({ update = Update })
end
