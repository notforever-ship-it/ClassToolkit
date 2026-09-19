-- Class Toolkit: the pieces every module draws with. Icons, rows of icons and bars can be dragged while
-- unlocked (/ctk move) or with Shift held, and remember where they were left, for the whole account.

local CTK = ClassToolkit

-- Put a frame where the player last left it, and let it be dragged while the icons are unlocked.
function CTK.MakeDraggable(f, positionKey, defaultX, defaultY)
  f:SetMovable(true)
  f:SetClampedToScreen(true)
  f:RegisterForDrag("LeftButton")

  local pos = CTK.Position(positionKey)
  if type(pos) == "table" and pos.point then
    f:SetPoint(pos.point, UIParent, pos.relPoint or pos.point, pos.x or 0, pos.y or 0)
  else
    f:SetPoint("CENTER", UIParent, "CENTER", defaultX or 0, defaultY or 0)
  end

  f:SetScript("OnDragStart", function()
    if CTK.movingIcons or IsShiftKeyDown() then this:StartMoving() end
  end)
  f:SetScript("OnDragStop", function()
    this:StopMovingOrSizing()
    local point, _, relPoint, x, y = this:GetPoint()
    CTK.SavePosition(positionKey, point, relPoint, x, y)
  end)
end

-- A square icon with a coloured glow, a label underneath and a number in the middle.
function CTK.CreateIcon(name, parent, size)
  local f = CreateFrame("Button", name, parent or UIParent)
  f:SetWidth(size)
  f:SetHeight(size)
  f:SetFrameStrata("MEDIUM")

  f.icon = f:CreateTexture(nil, "ARTWORK")
  f.icon:SetAllPoints(f)
  f.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)

  f.glow = f:CreateTexture(nil, "OVERLAY")
  f.glow:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
  f.glow:SetBlendMode("ADD")
  f.glow:SetWidth(size * 1.9)
  f.glow:SetHeight(size * 1.9)
  f.glow:SetPoint("CENTER", f, "CENTER", 0, 0)

  f.label = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  f.label:SetPoint("TOP", f, "BOTTOM", 0, -3)

  f.count = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  f.count:SetPoint("CENTER", f, "CENTER", 0, 0)
  f.count:SetTextColor(1, 1, 1)

  f:Hide()
  return f
end

function CTK.SetIconState(f, r, g, b, text)
  f.glow:SetVertexColor(r, g, b)
  f.label:SetTextColor(r, g, b)
  f.label:SetText(text or "")
end

-- A draggable strip holding up to 'max' icons side by side. Only the icons in use are shown. 'gap' has
-- to leave room for the labels under the icons.
function CTK.CreateRow(name, positionKey, defaultX, defaultY, size, max, gap)
  gap = gap or 10
  local row = CreateFrame("Frame", name, UIParent)
  row:SetWidth(max * size + (max - 1) * gap)
  row:SetHeight(size)
  row:SetFrameStrata("MEDIUM")
  CTK.MakeDraggable(row, positionKey, defaultX, defaultY)
  row:EnableMouse(false)   -- only while unlocked, so it never blocks clicks on the world
  row.icons = {}
  for i = 1, max do
    local icon = CTK.CreateIcon(name .. "Icon" .. i, row, size)
    icon:SetPoint("LEFT", row, "LEFT", (i - 1) * (size + gap), 0)
    icon:EnableMouse(false)
    row.icons[i] = icon
  end
  return row
end

-- Show the first 'used' icons of a row and hide the rest.
function CTK.ShowIcons(row, used)
  for i = 1, table.getn(row.icons) do
    if i <= used then row.icons[i]:Show() else row.icons[i]:Hide() end
  end
end

-- A timer bar with a label on the left and time on the right.
function CTK.CreateBar(name, parent, width, height)
  local bar = CreateFrame("StatusBar", name, parent)
  bar:SetWidth(width)
  bar:SetHeight(height)
  bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
  bar:SetMinMaxValues(0, 1)
  bar:SetValue(0)

  bar.bg = bar:CreateTexture(nil, "BACKGROUND")
  bar.bg:SetAllPoints(bar)
  bar.bg:SetTexture(0, 0, 0, 0.55)

  bar.label = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  bar.label:SetPoint("LEFT", bar, "LEFT", 4, 0)

  bar.time = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  bar.time:SetPoint("RIGHT", bar, "RIGHT", -4, 0)

  bar:Hide()
  return bar
end

-- The 1.12 dialog background art is partly see-through; a solid layer underneath keeps text readable.
-- Must be called before SetBackdrop so the art draws on top of it.
function CTK.Opaque(f, pad)
  if f.ctkSolid then return end
  pad = pad or 11
  f.ctkSolid = f:CreateTexture(nil, "BACKGROUND")
  f.ctkSolid:SetTexture(0.05, 0.05, 0.07, 1)
  f.ctkSolid:SetPoint("TOPLEFT", f, "TOPLEFT", pad, -pad)
  f.ctkSolid:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -pad, pad)
end

-- One hidden tooltip, shared by every module that has to read text the game only shows in tooltips
-- (spell costs, buff names, what's on an action button).
function CTK.ScanTooltip()
  if not CTK.scanTip then
    CTK.scanTip = CreateFrame("GameTooltip", "ClassToolkitScanTooltip", nil, "GameTooltipTemplate")
  end
  CTK.scanTip:SetOwner(WorldFrame, "ANCHOR_NONE")
  return CTK.scanTip
end

function CTK.ScanLine(side, n)
  local line = getglobal("ClassToolkitScanTooltipText" .. side .. n)
  return line and line:GetText()
end
