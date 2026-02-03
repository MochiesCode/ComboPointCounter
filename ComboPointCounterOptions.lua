-- Only load if player is a rogue
local _, class = UnitClass("player")
if class ~= "ROGUE" then return end

local addonName, CPC = ...

-- Options Panel Registration
local panel = CreateFrame("Frame")
panel.name = "Combo Point Counter"
CPC.OptionsPanel = panel

local category = Settings.RegisterCanvasLayoutCategory(panel, panel.name)
Settings.RegisterAddOnCategory(category)
CPC.OptionsCategory = category

-- Header Text
local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
title:SetPoint("TOPLEFT", 16, -16)
title:SetText("Combo Point Counter")

local subtitle = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
subtitle:SetText("Configuration options")

-- Visibility Options
local alwaysShow = CreateFrame("CheckButton", nil, panel, "InterfaceOptionsCheckButtonTemplate")
alwaysShow:SetPoint("TOPLEFT", subtitle, "BOTTOMLEFT", 0, -16)
alwaysShow.Text:SetText("Always show (out of combat)")
alwaysShow:SetScript("OnClick", function(self)
    CPC.SetAlwaysShow(self:GetChecked())
end)

-- Frame Size Controls
local sizeHeader = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightLarge")
sizeHeader:SetPoint("TOPLEFT", alwaysShow, "BOTTOMLEFT", 0, -16)
sizeHeader:SetText("Frame Size")

local sizeSlider = CreateFrame("Slider", nil, panel, "OptionsSliderTemplate")
sizeSlider:SetPoint("TOPLEFT", sizeHeader, "BOTTOMLEFT", 0, -12)
sizeSlider:SetMinMaxValues(8, 128)
sizeSlider:SetValueStep(1)
sizeSlider:SetObeyStepOnDrag(true)
sizeSlider:SetWidth(105)
sizeSlider.Low:SetText("8")
sizeSlider.High:SetText("128")

local sizeBox = CreateFrame("EditBox", nil, panel, "InputBoxTemplate")
sizeBox:SetSize(50, 20)
sizeBox:SetPoint("LEFT", sizeSlider, "RIGHT", 12, 0)
sizeBox:SetAutoFocus(false)
sizeBox:SetNumeric(true)

sizeSlider:SetScript("OnValueChanged", function(_, value)
    CPC.SetFrameSize(math.floor(value + 0.5))
end)

sizeBox:SetScript("OnEnterPressed", function(self)
    local v = tonumber(self:GetText())
    if v then
        CPC.SetFrameSize(math.max(8, math.min(128, v)))
    end
    self:ClearFocus()
end)

local resetSize = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
resetSize:SetSize(80, 22)
resetSize:SetPoint("TOPLEFT", sizeSlider, "BOTTOMLEFT", 0, -10)
resetSize:SetText("Reset")
resetSize:SetScript("OnClick", function()
    CPC.SetFrameSize(25)
end)

-- Frame Position Controls
local posHeader = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightLarge")
posHeader:SetPoint("TOPLEFT", resetSize, "BOTTOMLEFT", 0, -22)
posHeader:SetText("Frame Position")

local posXLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
posXLabel:SetPoint("TOPLEFT", posHeader, "BOTTOMLEFT", 0, -10)
posXLabel:SetText("X")

local posX = CreateFrame("EditBox", nil, panel, "InputBoxTemplate")
posX:SetSize(60, 20)
posX:SetPoint("LEFT", posXLabel, "RIGHT", 8, 0)
posX:SetAutoFocus(false)

local posYLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
posYLabel:SetPoint("LEFT", posX, "RIGHT", 8, 0)
posYLabel:SetText("Y")

local posY = CreateFrame("EditBox", nil, panel, "InputBoxTemplate")
posY:SetSize(60, 20)
posY:SetPoint("LEFT", posYLabel, "RIGHT", 8, 0)
posY:SetAutoFocus(false)

local function ApplyPosition()
    local x, y = tonumber(posX:GetText()), tonumber(posY:GetText())
    if x and y then
        CPC.SetFramePosition(x, y)
    end
end

posX:SetScript("OnEnterPressed", function(self) ApplyPosition(); self:ClearFocus() end)
posY:SetScript("OnEnterPressed", function(self) ApplyPosition(); self:ClearFocus() end)

local applyPos = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
applyPos:SetSize(80, 22)
applyPos:SetPoint("TOPLEFT", posXLabel, "BOTTOMLEFT", 0, -10)
applyPos:SetText("Apply")
applyPos:SetScript("OnClick", ApplyPosition)

local resetPos = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
resetPos:SetSize(80, 22)
resetPos:SetPoint("LEFT", applyPos, "RIGHT", 4, 0)
resetPos:SetText("Reset")
resetPos:SetScript("OnClick", function()
    CPC.SetFramePosition(0, 0)
end)

-- Debug / Force Number Controls
local debugHeader = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightLarge")
debugHeader:SetPoint("TOPLEFT", applyPos, "BOTTOMLEFT", 0, -22)
debugHeader:SetText("Digit Adjustment")

local debugLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
debugLabel:SetPoint("TOPLEFT", debugHeader, "BOTTOMLEFT", 0, -12)
debugLabel:SetText("Force Number")

local debugCheck = CreateFrame("CheckButton", nil, panel, "InterfaceOptionsCheckButtonTemplate")
debugCheck:SetPoint("LEFT", debugLabel, "RIGHT", 6, -1)

local debugBox = CreateFrame("EditBox", nil, panel, "InputBoxTemplate")
debugBox:SetSize(40, 20)
debugBox:SetPoint("LEFT", debugCheck, "RIGHT", 6, 1)
debugBox:SetAutoFocus(false)
debugBox:SetNumeric(true)

debugCheck:SetScript("OnClick", function(self)
    if not self:GetChecked() then
        CPC.SetDebugValue(nil)
    else
        debugBox:SetFocus()
    end
end)

debugBox:SetScript("OnEnterPressed", function(self)
    CPC.SetDebugValue(tonumber(self:GetText()))
    self:ClearFocus()
end)

-- Number Offset Controls
local offsetBoxes = {}

for i = 0, 7 do
    local row = CreateFrame("Frame", nil, panel)
    row:SetSize(200, 20)

    if i == 0 then
        row:SetPoint("TOPLEFT", debugLabel, "BOTTOMLEFT", 0, -8)
    else
        row:SetPoint("TOPLEFT", offsetBoxes[i - 1], "BOTTOMLEFT", 0, -4)
    end

    local label = row:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    label:SetPoint("LEFT")
    label:SetText("Offset " .. i)

    local box = CreateFrame("EditBox", nil, row, "InputBoxTemplate")
    box:SetSize(40, 20)
    box:SetPoint("LEFT", label, "RIGHT", 8, 0)
    box:SetAutoFocus(false)

    box:SetScript("OnEnterPressed", function(self)
        CPC.SetTextOffset(i, tonumber(self:GetText()) or 0)
        self:ClearFocus()
    end)

    row.box = box
    offsetBoxes[i] = row
end

-- Unified Refresh
function CPC.RefreshAllOptions()
    alwaysShow:SetChecked(ComboPointCounterDB.alwaysShow)

    sizeSlider:SetValue(ComboPointCounterDB.size)
    sizeBox:SetText(tostring(ComboPointCounterDB.size))

    posX:SetText(ComboPointCounterDB.x or 0)
    posY:SetText(ComboPointCounterDB.y or 0)

    debugCheck:SetChecked(ComboPointCounterDB.debugValue ~= nil)
    debugBox:SetText(ComboPointCounterDB.debugValue or "")

    for i = 0, 7 do
        offsetBoxes[i].box:SetText(ComboPointCounterDB.textOffsets[i] or 0)
    end
end

panel:SetScript("OnShow", CPC.RefreshAllOptions)
