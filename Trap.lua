-- Class Toolkit: Freezing Trap timer (hunters). When a mob is frozen, a bar counts down how long it stays
-- frozen. The length goes by your trap's rank (10, 15 or 20 seconds, plus Clever Traps), and the bar learns
-- your server's real length from how long full traps last. Read from the combat log, English clients only.

local CTK = ClassToolkit

local TRAP = "Freezing Trap"
local EFFECT = "Freezing Trap Effect"
local BY_RANK = { 10, 15, 20 }
local MAX_BARS = 2
local ICON = "Interface\\Icons\\Spell_Frost_ChainsOfIce"

local holder
local bars = {}
local frozen = {}     -- list of { who, started, length, rank }

local function TrapRank()
  local index = CTK.SpellIndex(TRAP)
  if not index then return 1 end
  local _, rankText = GetSpellName(index, "spell")
  local _, _, n = string.find(rankText or "", "(%d+)")
  n = tonumber(n) or 1
  if n < 1 then n = 1 end
  if n > 3 then n = 3 end
  return n
end

-- Clever Traps: 15% longer per point.
local function TalentBonus()
  for tab = 1, (GetNumTalentTabs() or 0) do
    for i = 1, (GetNumTalents(tab) or 0) do
      local name, _, _, _, points = GetTalentInfo(tab, i)
      if name == "Clever Traps" then return 1 + 0.15 * (points or 0) end
    end
  end
  return 1
end

local function Learned()
  if type(CTK.char.trapTimes) ~= "table" then CTK.char.trapTimes = {} end
  return CTK.char.trapTimes
end

local function TrapLength(rank)
  return Learned()[rank] or BY_RANK[rank] * TalentBonus()
end

local function Remove(who, learn)
  local now = GetTime()
  for i = table.getn(frozen), 1, -1 do
    local f = frozen[i]
    if f.who == who then
      if learn then
        -- A trap that ran its course says how long traps last here. Broken ones end sooner, so keep the longest.
        local took = now - f.started
        local times = Learned()
        if took >= 3 and took <= 40 and (not times[f.rank] or took > times[f.rank]) then
          times[f.rank] = took
          CTK.Debug("freezing trap rank " .. f.rank .. " lasts " .. string.format("%.1f", took) .. " s")
        end
      end
      table.remove(frozen, i)
      return
    end
  end
end

local function OnEvent()
  local msg = arg1
  if not msg or not CTK.char or not CTK.char.trap or not CTK.IsClass("HUNTER") then return end
  local _, _, who = string.find(msg, "^(.-) is afflicted by " .. EFFECT .. "%.$")
  if who then
    Remove(who, false)
    local rank = TrapRank()
    table.insert(frozen, { who = who, started = GetTime(), length = TrapLength(rank), rank = rank })
    while table.getn(frozen) > MAX_BARS do table.remove(frozen, 1) end
    return
  end
  _, _, who = string.find(msg, "^" .. EFFECT .. " fades from (.-)%.$")
  if who then
    Remove(who, true)
    return
  end
  _, _, who = string.find(msg, "^(.-) dies%.$")
  if who then Remove(who, false) end
end

local elapsed = 0
local function OnUpdate()
  if not holder or CTK.movingIcons then return end
  elapsed = elapsed + arg1
  if elapsed < 0.05 then return end
  elapsed = 0
  if UnitIsDeadOrGhost("player") or not CTK.char or not CTK.char.trap then frozen = {} end
  local now = GetTime()
  for i = 1, MAX_BARS do
    local f = frozen[i]
    local b = bars[i]
    if f then
      local left = f.length - (now - f.started)
      if left < -1 then
        table.remove(frozen, i)
        b:Hide()
      else
        if left < 0 then left = 0 end
        b:SetValue(left / f.length)
        b.label:SetText(f.who)
        b.time:SetText(math.ceil(left) .. "s")
        if left < 3 then b:SetStatusBarColor(1, 0.5, 0.1) else b:SetStatusBarColor(0.4, 0.8, 1) end
        b:Show()
      end
    else
      b:Hide()
    end
  end
end

local function Update()
  if not holder then return end
  if CTK.movingIcons and CTK.char.trap and CTK.IsClass("HUNTER") then
    bars[1]:SetValue(0.6)
    bars[1].label:SetText("Freezing Trap (drag)")
    bars[1].time:SetText("12s")
    bars[1]:SetStatusBarColor(0.4, 0.8, 1)
    bars[1]:Show()
    bars[2]:Hide()
    holder:EnableMouse(true)
    holder:Show()
  else
    holder:EnableMouse(false)
    holder:Show()
    if not CTK.char.trap or not CTK.IsClass("HUNTER") then frozen = {} end
    for i = 1, MAX_BARS do
      if not frozen[i] then bars[i]:Hide() end
    end
  end
end

function CTK.InitTrap()
  holder = CreateFrame("Frame", "ClassToolkitTrapBars", UIParent)
  holder:SetWidth(170)
  holder:SetHeight(MAX_BARS * 18)
  holder:SetFrameStrata("MEDIUM")
  holder:EnableMouse(false)
  CTK.MakeDraggable(holder, "trap", 200, -200)

  for i = 1, MAX_BARS do
    local b = CTK.CreateBar("ClassToolkitTrapBar" .. i, holder, 150, 14)
    b:SetPoint("TOPRIGHT", holder, "TOPRIGHT", 0, -(i - 1) * 18)
    b.icon = b:CreateTexture(nil, "OVERLAY")
    b.icon:SetTexture(ICON)
    b.icon:SetWidth(14)
    b.icon:SetHeight(14)
    b.icon:SetPoint("RIGHT", b, "LEFT", -2, 0)
    b.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    bars[i] = b
  end

  local driver = CreateFrame("Frame")
  local events = { "CHAT_MSG_SPELL_PERIODIC_CREATURE_DAMAGE", "CHAT_MSG_SPELL_PERIODIC_HOSTILEPLAYER_DAMAGE",
    "CHAT_MSG_SPELL_AURA_GONE_OTHER", "CHAT_MSG_COMBAT_HOSTILE_DEATH" }
  for i = 1, table.getn(events) do pcall(driver.RegisterEvent, driver, events[i]) end
  driver:SetScript("OnEvent", OnEvent)
  driver:SetScript("OnUpdate", OnUpdate)
  CTK.RegisterModule({ update = Update })
end
