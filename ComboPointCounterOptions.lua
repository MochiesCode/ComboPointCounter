local addonName, CPC = ...

-- Main file bails out for unsupported classes before creating the frame
if not CPC.frame then return end

local DEFAULTS = CPC.DEFAULTS

--========================================================--
-- Options Panel Registration
--========================================================--
local panel = CreateFrame("Frame")
panel.name = "Combo Point Counter"
CPC.OptionsPanel = panel

local category = Settings.RegisterCanvasLayoutCategory(panel, panel.name)
Settings.RegisterAddOnCategory(category)
CPC.OptionsCategory = category

--========================================================--
-- Scroll Frame
--========================================================--
local scrollFrame = CreateFrame("ScrollFrame", nil, panel, "UIPanelScrollFrameTemplate")
scrollFrame:SetPoint("TOPLEFT", 0, 0)
scrollFrame:SetPoint("BOTTOMRIGHT", -28, 0)

local content = CreateFrame("Frame", nil, scrollFrame)
content:SetPoint("TOPLEFT")
content:SetSize(1, 1)
scrollFrame:SetScrollChild(content)

scrollFrame:SetScript("OnSizeChanged", function(self, width)
    content:SetWidth(width)
end)

--========================================================--
-- Tab Navigation
--========================================================--
local tabBoxes = {}

local function IsTabTarget(box)
    return box and box:IsShown() and box:IsEnabled()
end

local function FocusNextTab(current, reverse)
    local count = #tabBoxes
    if count == 0 then return end

    local startIndex = 1
    for i = 1, count do
        if tabBoxes[i] == current then
            startIndex = i
            break
        end
    end

    local step = reverse and -1 or 1
    local idx = startIndex
    for _ = 1, count do
        idx = idx + step
        if idx < 1 then idx = count end
        if idx > count then idx = 1 end

        local target = tabBoxes[idx]
        if IsTabTarget(target) then
            target:SetFocus()
            target:HighlightText()
            return
        end
    end
end

local function RegisterTabBox(box)
    tabBoxes[#tabBoxes + 1] = box
    box:SetScript("OnTabPressed", function(self)
        FocusNextTab(self, IsShiftKeyDown())
    end)
end

local function ParseInteger(text)
    text = tostring(text or "")
    if not text:match("^%-?%d+$") then
        return nil
    end

    return tonumber(text)
end

local function SanitizeIntegerText(text, allowNegative)
    text = tostring(text or "")
    local sign = ""
    if allowNegative and text:sub(1, 1) == "-" then
        sign = "-"
    end

    local digits = text:gsub("%D", "")
    return sign .. digits
end

local function SetIntegerInputFilter(box, allowNegative)
    box:SetNumeric(false)
    box:SetScript("OnTextChanged", function(self, userInput)
        if not userInput then
            return
        end

        local text = self:GetText() or ""
        local sanitized = SanitizeIntegerText(text, allowNegative)
        if sanitized ~= text then
            local cursor = self:GetCursorPosition()
            self:SetText(sanitized)
            self:SetCursorPosition(math.min(cursor, #sanitized))
        end
    end)
end

--========================================================--
-- Header Text
--========================================================--
local title = content:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
title:SetPoint("TOPLEFT", 16, -16)
title:SetText("Combo Point Counter v" .. (C_AddOns.GetAddOnMetadata(addonName, "Version") or "?"))

local subtitle = content:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
subtitle:SetText("Configuration options")

local DIGIT_COLUMN_MIN_OFFSET = 240

local function GetDigitColumnOffset()
    local width = content:GetWidth() or 0
    if width <= 0 then
        return DIGIT_COLUMN_MIN_OFFSET
    end

    local halfWidth = math.floor(width * 0.5)
    return math.max(DIGIT_COLUMN_MIN_OFFSET, halfWidth)
end

local BORDER_ATLAS_LABELS = {
    ["ChallengeMode-KeystoneSlotFrameGlow"] = "Glow 1",
    ["ChallengeMode-KeystoneSlotFrame"] = "Ornate",
    ["lemixArtifact-node-circle-glw-FX"] = "Glow 2",
    ["dragonflight-landingbutton-circlehighlight"] = "Container",
    ["services-cover-ring"] = "Ring",
    ["talents-node-circle-sheenmask"] = "Solid Color",
}

-- Set while RefreshAllOptions syncs widgets, so programmatic SetValue calls
-- don't feed clamped slider values back into the saved settings.
local refreshing = false

--========================================================--
-- Visibility Options
--========================================================--
local alwaysShow = CreateFrame("CheckButton", nil, content, "InterfaceOptionsCheckButtonTemplate")
alwaysShow.Text:SetText("Always show")
alwaysShow.Text:ClearAllPoints()
alwaysShow.Text:SetPoint("RIGHT", alwaysShow, "LEFT", -4, 1)
alwaysShow:SetPoint("TOPRIGHT", content, "TOPRIGHT", -16, -16)
alwaysShow:SetScript("OnClick", function(self)
    CPC.SetAlwaysShow(self:GetChecked())
end)

--========================================================--
-- Frame Size Controls
--========================================================--
local sizeHeader = content:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
sizeHeader:SetPoint("TOPLEFT", subtitle, "BOTTOMLEFT", 0, -16)
sizeHeader:SetText("Frame Size")

local sizeSlider = CreateFrame("Slider", nil, content, "OptionsSliderTemplate")
sizeSlider:SetPoint("TOPLEFT", sizeHeader, "BOTTOMLEFT", 0, -12)
sizeSlider:SetMinMaxValues(8, 128)
sizeSlider:SetValueStep(1)
sizeSlider:SetObeyStepOnDrag(true)
sizeSlider:SetWidth(105)
sizeSlider.Low:SetText("8")
sizeSlider.High:SetText("128")

local sizeBox = CreateFrame("EditBox", nil, content, "InputBoxTemplate")
sizeBox:SetSize(50, 20)
sizeBox:SetPoint("LEFT", sizeSlider, "RIGHT", 12, 0)
sizeBox:SetAutoFocus(false)
SetIntegerInputFilter(sizeBox, false)
RegisterTabBox(sizeBox)

sizeSlider:SetScript("OnValueChanged", function(_, value)
    if refreshing then return end
    CPC.SetFrameSize(math.floor(value + 0.5))
end)

sizeBox:SetScript("OnEnterPressed", function(self)
    local v = ParseInteger(self:GetText())
    if v then
        CPC.SetFrameSize(math.max(8, math.min(128, v)))
    end
    self:ClearFocus()
end)

local resetSize = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
resetSize:SetSize(80, 22)
resetSize:SetPoint("LEFT", sizeBox, "RIGHT", 6, 0)
resetSize:SetText("Reset")
resetSize:SetScript("OnClick", function()
    CPC.SetFrameSize(DEFAULTS.size)
end)

--========================================================--
-- Frame Position Controls
--========================================================--
local posHeader = content:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
posHeader:SetPoint("TOPLEFT", sizeSlider, "BOTTOMLEFT", 0, -34)
posHeader:SetText("Frame Position")

local posXLabel = content:CreateFontString(nil, "ARTWORK", "GameFontNormal")
posXLabel:SetPoint("TOPLEFT", posHeader, "BOTTOMLEFT", 0, -10)
posXLabel:SetText("X")

local posX = CreateFrame("EditBox", nil, content, "InputBoxTemplate")
posX:SetSize(60, 20)
posX:SetPoint("LEFT", posXLabel, "RIGHT", 8, 0)
posX:SetAutoFocus(false)
SetIntegerInputFilter(posX, true)
RegisterTabBox(posX)

local posYLabel = content:CreateFontString(nil, "ARTWORK", "GameFontNormal")
posYLabel:SetPoint("LEFT", posX, "RIGHT", 8, 0)
posYLabel:SetText("Y")

local posY = CreateFrame("EditBox", nil, content, "InputBoxTemplate")
posY:SetSize(60, 20)
posY:SetPoint("LEFT", posYLabel, "RIGHT", 8, 0)
posY:SetAutoFocus(false)
SetIntegerInputFilter(posY, true)
RegisterTabBox(posY)

local function ApplyPosition()
    local x = ParseInteger(posX:GetText())
    local y = ParseInteger(posY:GetText())
    if x and y then
        CPC.SetFramePosition(x, y)
    end
end

posX:SetScript("OnEnterPressed", function(self) ApplyPosition(); self:ClearFocus() end)
posY:SetScript("OnEnterPressed", function(self) ApplyPosition(); self:ClearFocus() end)

local applyPos = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
applyPos:SetHeight(22)
applyPos:SetPoint("TOPLEFT", posX, "BOTTOMLEFT", 0, -10)
applyPos:SetPoint("TOPRIGHT", posY, "BOTTOMRIGHT", 0, -10)
applyPos:SetText("Apply")
applyPos:SetScript("OnClick", ApplyPosition)

local resetPos = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
resetPos:SetSize(80, 22)
resetPos:SetPoint("LEFT", posY, "RIGHT", 6, 0)
resetPos:SetText("Reset")
resetPos:SetScript("OnClick", function()
    CPC.SetFramePosition(DEFAULTS.x, DEFAULTS.y)
end)

--========================================================--
-- Color Controls
--========================================================--
local function ShowColorPicker(r, g, b, a, onChange)
    local function ApplyNew()
        local nr, ng, nb = ColorPickerFrame:GetColorRGB()
        local na = ColorPickerFrame:GetColorAlpha() or 1
        onChange(nr, ng, nb, na)
    end

    ColorPickerFrame:SetupColorPickerAndShow({
        r = r,
        g = g,
        b = b,
        opacity = a or 1,
        hasOpacity = true,
        swatchFunc = ApplyNew,
        opacityFunc = ApplyNew,
        cancelFunc = function()
            onChange(r, g, b, a)
        end,
    })
end

local colorsHeader = content:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
colorsHeader:SetPoint("TOPLEFT", posHeader, "BOTTOMLEFT", 0, -80)
colorsHeader:SetText("Style")

local borderAtlasLabel = content:CreateFontString(nil, "ARTWORK", "GameFontNormal")
borderAtlasLabel:SetPoint("TOPLEFT", colorsHeader, "BOTTOMLEFT", 0, -16)
borderAtlasLabel:SetText("Border")

local borderAtlasDropdown = CreateFrame("Frame", "ComboPointCounterBorderAtlasDropdown", content, "UIDropDownMenuTemplate")
borderAtlasDropdown:SetPoint("LEFT", borderAtlasLabel, "RIGHT", 4, -2)
UIDropDownMenu_SetWidth(borderAtlasDropdown, 170)
UIDropDownMenu_SetText(borderAtlasDropdown, "")

local COLOR_ROW_SWATCH_X = 170
local COLOR_ROW_RESET_X = 200
local OFFSET_INPUT_X = 70

--========================================================--
-- Finisher Threshold Controls
--========================================================--
local thresholdLabel = content:CreateFontString(nil, "ARTWORK", "GameFontNormal")
thresholdLabel:SetPoint("TOPLEFT", borderAtlasLabel, "BOTTOMLEFT", 0, -16)
thresholdLabel:SetText("Finisher Threshold")

local thresholdSlider = CreateFrame("Slider", nil, content, "OptionsSliderTemplate")
thresholdSlider:SetPoint("TOPLEFT", thresholdLabel, "BOTTOMLEFT", 0, -12)
thresholdSlider:SetMinMaxValues(1, 7)
thresholdSlider:SetValueStep(1)
thresholdSlider:SetObeyStepOnDrag(true)
thresholdSlider:SetWidth(105)
thresholdSlider.Low:SetText("1")
thresholdSlider.High:SetText("7")

local thresholdBox = CreateFrame("EditBox", nil, content, "InputBoxTemplate")
thresholdBox:SetSize(40, 20)
thresholdBox:SetPoint("LEFT", thresholdSlider, "RIGHT", 12, 0)
thresholdBox:SetAutoFocus(false)
SetIntegerInputFilter(thresholdBox, false)
RegisterTabBox(thresholdBox)

thresholdSlider:SetScript("OnValueChanged", function(_, value)
    if refreshing then return end
    CPC.SetFinisherThreshold(math.floor(value + 0.5))
end)

thresholdBox:SetScript("OnEnterPressed", function(self)
    local v = ParseInteger(self:GetText())
    if v then
        CPC.SetFinisherThreshold(math.max(1, math.min(7, v)))
    end
    self:ClearFocus()
end)

local resetThreshold = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
resetThreshold:SetSize(80, 22)
resetThreshold:SetPoint("LEFT", thresholdBox, "RIGHT", 6, 0)
resetThreshold:SetText("Reset")
resetThreshold:SetScript("OnClick", function()
    CPC.SetFinisherThreshold(DEFAULTS.finisherThreshold)
end)

local function CreateColorRow(labelText, anchor, yOffset, onPick, onReset)
    local row = CreateFrame("Frame", nil, content)
    row:SetSize(320, 22)
    row:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, yOffset)

    local label = row:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    label:SetPoint("LEFT")
    label:SetText(labelText)

    local button = CreateFrame("Button", nil, row)
    button:SetSize(22, 22)
    button:SetPoint("LEFT", row, "LEFT", COLOR_ROW_SWATCH_X, 0)
    button:SetHighlightTexture("Interface/Buttons/ButtonHilight-Square")

    local swatch = button:CreateTexture(nil, "ARTWORK")
    swatch:SetPoint("CENTER")
    swatch:SetSize(14, 14)

    local border = button:CreateTexture(nil, "BORDER")
    border:SetAllPoints()
    border:SetTexture("Interface/Buttons/UI-Quickslot2")

    button.swatch = swatch
    button:SetScript("OnClick", onPick)

    local reset = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
    reset:SetSize(50, 22)
    reset:SetPoint("LEFT", row, "LEFT", COLOR_ROW_RESET_X, 0)
    reset:SetText("Reset")
    reset:SetScript("OnClick", onReset)

    return row, button
end

-- Keys match the color tables in CPC.DEFAULTS. Swatches are refreshed by
-- RefreshAllOptions, which every setter triggers while the panel is open.
local COLOR_ROWS = {
    { key = "backgroundColor", label = "Background Tint" },
    { key = "finisherColor", label = "Finisher Background Tint" },
    { key = "numberColor", label = "Number Tint" },
    { key = "finisherNumberColor", label = "Finisher Number Tint" },
    { key = "borderTint", label = "Border Tint" },
}

local colorRows, colorButtons = {}, {}
local rowAnchor, rowOffset = thresholdSlider, -18

for _, info in ipairs(COLOR_ROWS) do
    local key = info.key
    local row, button = CreateColorRow(info.label, rowAnchor, rowOffset, function()
        local r, g, b, a = CPC.GetColor(key)
        ShowColorPicker(r, g, b, a, function(nr, ng, nb, na)
            CPC.SetColor(key, nr, ng, nb, na)
        end)
    end, function()
        local c = DEFAULTS[key]
        CPC.SetColor(key, c.r, c.g, c.b, c.a)
    end)

    colorRows[key] = row
    colorButtons[key] = button
    rowAnchor, rowOffset = row, -6
end

local borderTintRow = colorRows.borderTint
borderTintRow:Hide()

local borderAtlasDropdownInitialized = false
local UpdateContentHeight

local function UpdateBorderAtlasDropdownText()
    local selected = ComboPointCounterDB.borderAtlas
    UIDropDownMenu_SetText(borderAtlasDropdown, BORDER_ATLAS_LABELS[selected] or selected)
end

local function UpdateBorderTintVisibility()
    borderTintRow:SetShown(ComboPointCounterDB.borderAtlas == CPC.BORDER_TINT_ATLAS)
    UpdateContentHeight()
end

local function InitializeBorderAtlasDropdown()
    if borderAtlasDropdownInitialized then
        return
    end

    UIDropDownMenu_Initialize(borderAtlasDropdown, function(_, level)
        if level ~= 1 then
            return
        end

        local selected = ComboPointCounterDB.borderAtlas
        for _, atlas in ipairs(CPC.BORDER_ATLAS_CHOICES) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = BORDER_ATLAS_LABELS[atlas] or atlas
            info.func = function()
                CPC.SetBorderAtlas(atlas)
            end
            info.checked = (atlas == selected)
            UIDropDownMenu_AddButton(info, level)
        end
    end)

    borderAtlasDropdownInitialized = true
end

--========================================================--
-- Debug / Force Number Controls
--========================================================--
local debugHeader = content:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
debugHeader:SetText("Digit Adjustment")

local debugLabel = content:CreateFontString(nil, "ARTWORK", "GameFontNormal")
debugLabel:SetPoint("TOPLEFT", debugHeader, "BOTTOMLEFT", 0, -12)
debugLabel:SetText("Force Number")

local debugCheck = CreateFrame("CheckButton", nil, content, "InterfaceOptionsCheckButtonTemplate")
debugCheck:SetPoint("LEFT", debugLabel, "RIGHT", 6, -1)

local debugBox = CreateFrame("EditBox", nil, content, "InputBoxTemplate")
debugBox:SetSize(40, 20)
debugBox:SetPoint("LEFT", debugCheck, "RIGHT", 6, 1)
debugBox:SetAutoFocus(false)
SetIntegerInputFilter(debugBox, false)
debugBox:EnableMouseWheel(false)
RegisterTabBox(debugBox)

debugBox:SetScript("OnEditFocusGained", function(self)
    self:HighlightText()
end)

local function SetDebugBoxEnabled(enabled)
    debugBox:SetEnabled(enabled)
    debugBox:SetAlpha(enabled and 1 or 0.4)
    if not enabled then
        debugBox:ClearFocus()
    end
end

debugCheck:SetScript("OnClick", function(self)
    local enabled = self:GetChecked()
    SetDebugBoxEnabled(enabled)

    if not enabled then
        CPC.SetDebugValue(nil)
    else
        debugBox:SetFocus()
    end
end)

debugBox:SetScript("OnEnterPressed", function(self)
    local v = ParseInteger(self:GetText())
    if v then
        v = math.max(0, math.min(7, v))
        CPC.SetDebugValue(v)
        self:SetText(v)
    end
    self:ClearFocus()
end)

--========================================================--
-- Number Offset Controls
--========================================================--
local offsetBoxes = {}

for i = 0, 7 do
    local row = CreateFrame("Frame", nil, content)
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
    box:SetPoint("LEFT", row, "LEFT", OFFSET_INPUT_X, 0)
    box:SetAutoFocus(false)
    SetIntegerInputFilter(box, true)
    RegisterTabBox(box)

    box:SetScript("OnEnterPressed", function(self)
        local v = ParseInteger(self:GetText()) or 0
        CPC.SetTextOffset(i, v)
        self:SetText(v)
        self:ClearFocus()
    end)

    row.box = box
    offsetBoxes[i] = row
end

local function LayoutDigitAdjustment()
    local offset = GetDigitColumnOffset()

    debugHeader:ClearAllPoints()
    debugHeader:SetPoint("TOPLEFT", sizeHeader, "TOPLEFT", offset, 0)

    debugLabel:ClearAllPoints()
    debugLabel:SetPoint("TOPLEFT", debugHeader, "BOTTOMLEFT", 0, -12)
end

--========================================================--
-- Unified Refresh
--========================================================--
UpdateContentHeight = function()
    local lastColorRow = borderTintRow:IsShown() and borderTintRow or colorRows.finisherNumberColor
    local top = content:GetTop()
    local offsetBottom = offsetBoxes[7]:GetBottom()
    local colorBottom = lastColorRow:GetBottom()
    if not top or not offsetBottom or not colorBottom then return end

    local height = top - math.min(offsetBottom, colorBottom) + 20
    content:SetHeight(math.max(height, 1))
end

function CPC.RefreshAllOptions()
    local db = ComboPointCounterDB
    refreshing = true

    alwaysShow:SetChecked(db.alwaysShow)

    sizeSlider:SetValue(db.size)
    sizeBox:SetText(tostring(db.size))

    posX:SetText(db.x)
    posY:SetText(db.y)

    for key, button in pairs(colorButtons) do
        button.swatch:SetColorTexture(CPC.GetColor(key))
    end
    InitializeBorderAtlasDropdown()
    UpdateBorderAtlasDropdownText()
    UpdateBorderTintVisibility()

    thresholdSlider:SetValue(db.finisherThreshold)
    thresholdBox:SetText(tostring(db.finisherThreshold))

    local debugEnabled = db.debugValue ~= nil
    debugCheck:SetChecked(debugEnabled)
    debugBox:SetText(db.debugValue or "")
    SetDebugBoxEnabled(debugEnabled)

    for i = 0, 7 do
        offsetBoxes[i].box:SetText(db.textOffsets[i])
    end

    refreshing = false
end

panel:SetScript("OnShow", function()
    LayoutDigitAdjustment()
    CPC.RefreshAllOptions()
    UpdateContentHeight()
end)

scrollFrame:HookScript("OnSizeChanged", function()
    LayoutDigitAdjustment()
    UpdateContentHeight()
end)
