-- Class Toolkit: shared namespace, settings and slash commands.
-- Target client is WoW 1.12.1 (Lua 5.0): no '#', no '%', no string.match, varargs via 'arg'.
--
-- Settings are per character (ClassToolkitCharDB), because what a Paladin wants on screen is not what a
-- Hunter wants. Icon positions are shared by the whole account (ClassToolkitDB).

ClassToolkit = {}
local CTK = ClassToolkit

CTK.VERSION = "1.2.0"
CTK.movingIcons = false
CTK.modules = {}   -- each module registers { update = function() } so settings changes reach it

------------------------------------------------------------------------------------------------
-- Chat
------------------------------------------------------------------------------------------------

function CTK.Print(msg)
  DEFAULT_CHAT_FRAME:AddMessage("|cffabd473Class Toolkit|r: " .. tostring(msg))
end

function CTK.Debug(msg)
  if CTK.char and CTK.char.debug then
    DEFAULT_CHAT_FRAME:AddMessage("|cff888888[Class Toolkit debug]|r " .. tostring(msg))
  end
end

------------------------------------------------------------------------------------------------
-- Helpers
------------------------------------------------------------------------------------------------

-- "HUNTER", "PALADIN" and so on, or nil if the game hasn't said yet.
function CTK.Class()
  local _, class = UnitClass("player")
  return class
end

function CTK.IsClass(class)
  return CTK.Class() == class
end

function CTK.UnitGuid(unit)
  if not SUPERWOW_VERSION then return nil end
  local exists, guid = UnitExists(unit)
  if exists and type(guid) == "string" then return guid end
  return nil
end

function CTK.HasAttackableTarget()
  return UnitExists("target") and not UnitIsDead("target") and UnitCanAttack("player", "target")
end

-- Run func once after 'seconds'. Uses one shared frame whose OnUpdate is removed when idle.
local timers = {}
local timerFrame = CreateFrame("Frame")
local function TimerUpdate()
  local now = GetTime()
  local i = 1
  while i <= table.getn(timers) do
    local t = timers[i]
    if now >= t.at then
      table.remove(timers, i)
      local ok, err = pcall(t.func)
      if not ok then CTK.Print("error: " .. tostring(err)) end
    else
      i = i + 1
    end
  end
  if table.getn(timers) == 0 then
    timerFrame:SetScript("OnUpdate", nil)
  end
end

function CTK.After(seconds, func)
  table.insert(timers, { at = GetTime() + seconds, func = func })
  timerFrame:SetScript("OnUpdate", TimerUpdate)
end

------------------------------------------------------------------------------------------------
-- Settings
------------------------------------------------------------------------------------------------

local CASTERS = { PRIEST = true, MAGE = true, WARLOCK = true }

-- What starts switched on for a class. Nothing here is forced: every module can be turned off.
local function ClassDefaults(class)
  local hunter = class == "HUNTER"
  return {
    swingMelee = not CASTERS[class],
    swingRanged = hunter or CASTERS[class] or false,  -- Auto Shot, or a wand's Shoot
    ready = true,
    readyOne = false,   -- one icon showing the next spell ready, instead of one icon each
    watched = hunter and { "Arcane Shot" } or {},
    buffs = true,
    buffWarnSeconds = 60,
    reagents = true,
    range = hunter,
    feed = hunter,
    ammoBox = hunter,
    ammoBoxStacks = 2,
    feedWhen = "content",
    feedSound = true,
    debug = false,
  }
end

-- Fill in anything missing. Class info isn't always ready when the addon loads, so this runs again at
-- PLAYER_ENTERING_WORLD; a setting already chosen is never overwritten.
function CTK.ApplyDefaults()
  local class = CTK.Class()
  if not class then return false end
  local defaults = ClassDefaults(class)
  for k, v in pairs(defaults) do
    if CTK.char[k] == nil then CTK.char[k] = v end
  end
  CTK.char.class = class
  return true
end

function CTK.Position(key)
  return CTK.db.positions[key]
end

function CTK.SavePosition(key, point, relPoint, x, y)
  CTK.db.positions[key] = { point = point, relPoint = relPoint, x = x, y = y }
end

-- Tell every module something changed: a setting, the icon lock, or the character logging in.
function CTK.UpdateAll()
  for i = 1, table.getn(CTK.modules) do
    local ok, err = pcall(CTK.modules[i].update)
    if not ok then CTK.Debug("update failed: " .. tostring(err)) end
  end
  if CTK.RefreshOptions then CTK.RefreshOptions() end
end

function CTK.RegisterModule(module)
  table.insert(CTK.modules, module)
end

-- On/off switches, with the words used for them in chat and the options window.
CTK.TOGGLES = {
  { key = "swingMelee", command = "swing", label = "Melee swing timer" },
  { key = "swingRanged", command = "ranged", label = "Auto Shot / wand timer" },
  { key = "ready", command = "ready", label = "Spell ready icons" },
  { key = "readyOne", command = "one", label = "Ready icons: just the next one" },
  { key = "buffs", command = "buffs", label = "Buff reminder" },
  { key = "reagents", command = "reagents", label = "Reagent and ammo warnings" },
  { key = "range", command = "range", label = "Range icon", class = "HUNTER" },
  { key = "feed", command = "feed", label = "Pet feed reminder", class = "HUNTER" },
  { key = "ammoBox", command = "ammo", label = "Low ammo box", class = "HUNTER" },
}

function CTK.Toggle(key)
  CTK.char[key] = not CTK.char[key]
  for i = 1, table.getn(CTK.TOGGLES) do
    local t = CTK.TOGGLES[i]
    if t.key == key then
      CTK.Print(t.label .. " " .. (CTK.char[key] and "on" or "off") .. ".")
    end
  end
  CTK.UpdateAll()
end

function CTK.ToggleMoveIcons()
  CTK.movingIcons = not CTK.movingIcons
  if CTK.movingIcons then
    CTK.Print("icons unlocked: drag them where you want, then type /ctk move or press Lock icons.")
  else
    CTK.Print("icons locked.")
  end
  CTK.UpdateAll()
end

------------------------------------------------------------------------------------------------
-- Watched spells (spell ready icons)
------------------------------------------------------------------------------------------------

function CTK.Watch(name)
  if not name or name == "" then
    CTK.Print("type the spell's name, for example /ctk watch Arcane Shot")
    return
  end
  local watched = CTK.char.watched
  for i = 1, table.getn(watched) do
    if string.lower(watched[i]) == string.lower(name) then
      CTK.Print(watched[i] .. " is already watched.")
      return
    end
  end
  local proper = CTK.SpellIndex and CTK.KnownSpellName(name)
  if not proper then
    CTK.Print("you don't know a spell called '" .. name .. "'. Check the spelling in your spellbook.")
    return
  end
  table.insert(watched, proper)
  CTK.Print("watching " .. proper .. ".")
  CTK.UpdateAll()
end

function CTK.Unwatch(name)
  local watched = CTK.char.watched
  for i = 1, table.getn(watched) do
    if string.lower(watched[i]) == string.lower(name or "") then
      CTK.Print("stopped watching " .. watched[i] .. ".")
      table.remove(watched, i)
      CTK.UpdateAll()
      return
    end
  end
  CTK.Print("'" .. tostring(name) .. "' isn't being watched.")
end

------------------------------------------------------------------------------------------------
-- Slash commands
------------------------------------------------------------------------------------------------

local function ChatHelp()
  CTK.Print("v" .. CTK.VERSION .. " commands:")
  CTK.Print("/ctk - open the options window")
  CTK.Print("/ctk help - how to use Class Toolkit")
  CTK.Print("/ctk move - unlock or lock the icons and bars so you can drag them")
  for i = 1, table.getn(CTK.TOGGLES) do
    local t = CTK.TOGGLES[i]
    CTK.Print("/ctk " .. t.command .. " - " .. string.lower(t.label) .. " on or off" ..
      (t.class and " (hunters)" or ""))
  end
  CTK.Print("/ctk watch <spell> - add a spell ready icon, /ctk unwatch <spell> - remove it")
  CTK.Print("/ctk ready all | one - an icon for every watched spell, or one for the next one ready")
  CTK.Print("/ctk feed content | unhappy | sound - when the feed reminder shows, and its sound")
  CTK.Print("/ctk ammo <stacks> - hunters: show the low ammo box at this many stacks left (2 to start)")
  CTK.Print("/ctk buffs reset - bring back buff reminders you right-clicked away")
  CTK.Print("/ctk counts - list your reagents and ammo")
  CTK.Print("/ctk version - show which version you have")
  CTK.Print("/ctk reset - put this character's settings and all icon positions back to default")
end

local function SlashHandler(msg)
  if not CTK.char then return end
  local _, _, cmd, rest = string.find(msg or "", "^%s*(%S*)%s*(.-)%s*$")
  cmd = string.lower(cmd or "")

  if cmd == "" or cmd == "options" then
    CTK.ToggleOptions()
    return
  elseif cmd == "help" then
    CTK.ToggleHelp()
    return
  elseif cmd == "commands" then
    ChatHelp()
    return
  elseif cmd == "ammo" and tonumber(rest) then
    local stacks = math.max(1, math.floor(tonumber(rest)))
    CTK.char.ammoBoxStacks = stacks
    CTK.char.ammoBox = true
    CTK.Print("the low ammo box shows when you're down to " .. stacks .. (stacks == 1 and " stack" or " stacks") ..
      " of ammo.")
    CTK.UpdateAll()
    return
  elseif cmd == "ready" and (rest == "one" or rest == "all") then
    CTK.char.readyOne = (rest == "one")
    CTK.char.ready = true
    if CTK.char.readyOne then
      CTK.Print("one ready icon, showing whichever watched spell is ready first.")
    else
      CTK.Print("a ready icon for every watched spell.")
    end
    CTK.UpdateAll()
    return
  elseif cmd == "move" or cmd == "unlock" or cmd == "lock" then
    CTK.ToggleMoveIcons()
    return
  elseif cmd == "watch" then
    CTK.Watch(rest)
    return
  elseif cmd == "unwatch" then
    CTK.Unwatch(rest)
    return
  elseif cmd == "feed" and (rest == "content" or rest == "unhappy") then
    CTK.char.feedWhen = rest
    CTK.char.feed = true
    CTK.Print("feed reminder on, when your pet is " .. rest .. " or worse.")
    CTK.UpdateAll()
    return
  elseif cmd == "feed" and rest == "sound" then
    CTK.char.feedSound = not CTK.char.feedSound
    CTK.Print("feed reminder sound " .. (CTK.char.feedSound and "on" or "off") .. ".")
    return
  elseif cmd == "buffs" and rest == "reset" then
    if CTK.ResetIgnoredBuffs then CTK.ResetIgnoredBuffs() end
    return
  elseif cmd == "counts" then
    if CTK.PrintCounts then CTK.PrintCounts() end
    return
  elseif cmd == "version" then
    CTK.Print("version " .. CTK.VERSION .. ".")
    return
  elseif cmd == "debug" then
    CTK.char.debug = (rest == "on") or (rest ~= "off" and not CTK.char.debug)
    CTK.Print("debug messages " .. (CTK.char.debug and "on" or "off") .. ", SuperWoW: " ..
      tostring(SUPERWOW_VERSION or "no") .. ".")
    return
  elseif cmd == "reset" then
    ClassToolkitCharDB = {}
    CTK.char = ClassToolkitCharDB
    CTK.db.positions = {}
    CTK.ApplyDefaults()
    CTK.Print("settings for this character and all icon positions are back to default. /reload to move the icons back.")
    CTK.UpdateAll()
    return
  end

  for i = 1, table.getn(CTK.TOGGLES) do
    if CTK.TOGGLES[i].command == cmd then
      CTK.Toggle(CTK.TOGGLES[i].key)
      return
    end
  end
  ChatHelp()
end

------------------------------------------------------------------------------------------------
-- Loading
------------------------------------------------------------------------------------------------

local loader = CreateFrame("Frame")
loader:RegisterEvent("ADDON_LOADED")
loader:RegisterEvent("PLAYER_ENTERING_WORLD")
loader:SetScript("OnEvent", function()
  if event == "ADDON_LOADED" and arg1 == "ClassToolkit" then
    if type(ClassToolkitDB) ~= "table" then ClassToolkitDB = {} end
    if type(ClassToolkitDB.positions) ~= "table" then ClassToolkitDB.positions = {} end
    if type(ClassToolkitCharDB) ~= "table" then ClassToolkitCharDB = {} end
    CTK.db = ClassToolkitDB
    CTK.char = ClassToolkitCharDB
    if type(CTK.char.watched) ~= "table" then CTK.char.watched = nil end
    CTK.ApplyDefaults()

    SLASH_CLASSTOOLKIT1 = "/ctk"
    SLASH_CLASSTOOLKIT2 = "/classtoolkit"
    SlashCmdList["CLASSTOOLKIT"] = SlashHandler

    -- Modules build their frames now; they stay hidden until the character is in the world.
    if CTK.InitWidgets then CTK.InitWidgets() end
    local inits = { "InitSpells", "InitSwing", "InitReady", "InitBuffs", "InitReagents", "InitHunter" }
    for i = 1, table.getn(inits) do
      local init = CTK[inits[i]]
      if init then
        local ok, err = pcall(init)
        if not ok then CTK.Print("couldn't start " .. inits[i] .. ": " .. tostring(err)) end
      end
    end
  elseif event == "PLAYER_ENTERING_WORLD" and CTK.char then
    CTK.ApplyDefaults()
    if not CTK.char.welcomed and CTK.char.class then
      CTK.char.welcomed = true
      CTK.Print("v" .. CTK.VERSION .. " loaded. Type /ctk to choose what shows for your " ..
        string.lower(CTK.char.class) .. ", or /ctk help for how it all works.")
    end
    CTK.After(1, CTK.UpdateAll)
  end
end)
