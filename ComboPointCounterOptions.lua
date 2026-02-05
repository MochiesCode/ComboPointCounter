-- Only load if player is a rogue
local _, class = UnitClass("player")
if class ~= "ROGUE" then return end

local addonName, CPC = ...

--========================================================--
-- Ensure saved variables are initialized
--========================================================--
ComboPointCounterDB = ComboPointCounterDB or {}
ComboPointCounterDB.alwaysShow = ComboPointCounterDB.alwaysShow or false
ComboPointCounterDB.debugValue = ComboPointCounterDB.debugValue or nil
ComboPointCounterDB.point = ComboPointCounterDB.point or "CENTER"
ComboPointCounterDB.x = ComboPointCounterDB.x or 0
ComboPointCounterDB.y = ComboPointCounterDB.y or 0
ComboPointCounterDB.size = ComboPointCounterDB.size or 25
ComboPointCounterDB.textOffsets = ComboPointCounterDB.textOffsets or {}
for i = 0, 7 do
    ComboPointCounterDB.textOffsets[i] = ComboPointCounterDB.textOffsets[i] or 0
end
ComboPointCounterDB.backgroundColor = ComboPointCounterDB.backgroundColor or {}
ComboPointCounterDB.backgroundColor.r = ComboPointCounterDB.backgroundColor.r or 0
ComboPointCounterDB.backgroundColor.g = ComboPointCounterDB.backgroundColor.g or 0
ComboPointCounterDB.backgroundColor.b = ComboPointCounterDB.backgroundColor.b or 0
ComboPointCounterDB.backgroundColor.a = ComboPointCounterDB.backgroundColor.a or 0.6
ComboPointCounterDB.finisherColor = ComboPointCounterDB.finisherColor or {}
ComboPointCounterDB.finisherColor.r = ComboPointCounterDB.finisherColor.r or 0.75
ComboPointCounterDB.finisherColor.g = ComboPointCounterDB.finisherColor.g or 0.5
ComboPointCounterDB.finisherColor.b = ComboPointCounterDB.finisherColor.b or 0
ComboPointCounterDB.finisherColor.a = ComboPointCounterDB.finisherColor.a or 1
ComboPointCounterDB.numberColor = ComboPointCounterDB.numberColor or {}
ComboPointCounterDB.numberColor.r = ComboPointCounterDB.numberColor.r or 1
ComboPointCounterDB.numberColor.g = ComboPointCounterDB.numberColor.g or 0.82
ComboPointCounterDB.numberColor.b = ComboPointCounterDB.numberColor.b or 0
ComboPointCounterDB.numberColor.a = ComboPointCounterDB.numberColor.a or 1
ComboPointCounterDB.borderTint = ComboPointCounterDB.borderTint or {}
ComboPointCounterDB.borderTint.r = ComboPointCounterDB.borderTint.r or 1
ComboPointCounterDB.borderTint.g = ComboPointCounterDB.borderTint.g or 1
ComboPointCounterDB.borderTint.b = ComboPointCounterDB.borderTint.b or 1
ComboPointCounterDB.borderTint.a = ComboPointCounterDB.borderTint.a or 1
ComboPointCounterDB.borderAtlas = ComboPointCounterDB.borderAtlas or "ChallengeMode-KeystoneSlotFrameGlow"

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
    if text == "" then
        return nil
    end

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
title:SetText("Combo Point Counter v1.1")

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

local BORDER_ATLAS_CHOICES = CPC.BORDER_ATLAS_CHOICES or {
    "ChallengeMode-KeystoneSlotFrameGlow",
    "lemixArtifact-node-circle-glw-FX",
    "ChallengeMode-KeystoneSlotFrame",
    "dragonflight-landingbutton-circlehighlight",
    "services-cover-ring",
    "talents-node-circle-sheenmask",
}

local BORDER_ATLAS_LABELS = {
    ["ChallengeMode-KeystoneSlotFrameGlow"] = "Glow 1",
    ["ChallengeMode-KeystoneSlotFrame"] = "Ornate",
    ["lemixArtifact-node-circle-glw-FX"] = "Glow 2",
    ["dragonflight-landingbutton-circlehighlight"] = "Container",
    ["services-cover-ring"] = "Ring",
    ["talents-node-circle-sheenmask"] = "Tintable Ring",
}

local BORDER_ATLAS_LOOKUP = {}
for _, atlas in ipairs(BORDER_ATLAS_CHOICES) do
    BORDER_ATLAS_LOOKUP[atlas] = true
end

local DEFAULT_BORDER_ATLAS = BORDER_ATLAS_CHOICES[1]
if not BORDER_ATLAS_LOOKUP[ComboPointCounterDB.borderAtlas] then
    ComboPointCounterDB.borderAtlas = DEFAULT_BORDER_ATLAS
end

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
resetSize:SetPoint("TOPLEFT", sizeSlider, "BOTTOMLEFT", 0, -10)
resetSize:SetText("Reset")
resetSize:SetScript("OnClick", function()
    CPC.SetFrameSize(25)
end)

--========================================================--
-- Frame Position Controls
--========================================================--
local posHeader = content:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
posHeader:SetPoint("TOPLEFT", resetSize, "BOTTOMLEFT", 0, -22)
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
applyPos:SetSize(80, 22)
applyPos:SetPoint("TOPLEFT", posXLabel, "BOTTOMLEFT", 0, -10)
applyPos:SetText("Apply")
applyPos:SetScript("OnClick", ApplyPosition)

local resetPos = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
resetPos:SetSize(80, 22)
resetPos:SetPoint("LEFT", applyPos, "RIGHT", 4, 0)
resetPos:SetText("Reset")
resetPos:SetScript("OnClick", function()
    CPC.SetFramePosition(0, 0)
end)

--========================================================--
-- Color Controls
--========================================================--
local function ShowColorPicker(r, g, b, a, onChange)
    a = a or 1

    local function ApplyNew()
        local nr, ng, nb = ColorPickerFrame:GetColorRGB()
        local na = ColorPickerFrame:GetColorAlpha() or 1
        onChange(nr, ng, nb, na)
    end

    local function ApplyOld()
        local nr, ng, nb = ColorPickerFrame:GetColorRGB()
        local opacity = 1
        if OpacitySliderFrame and OpacitySliderFrame.GetValue then
            opacity = OpacitySliderFrame:GetValue()
        elseif ColorPickerFrame.opacity ~= nil then
            opacity = ColorPickerFrame.opacity
        end
        local na = 1 - opacity
        onChange(nr, ng, nb, na)
    end

    if ColorPickerFrame.SetupColorPickerAndShow then
        local pr, pg, pb, pa = r, g, b, a
        ColorPickerFrame:SetupColorPickerAndShow({
            r = r,
            g = g,
            b = b,
            opacity = a,
            hasOpacity = true,
            swatchFunc = ApplyNew,
            opacityFunc = ApplyNew,
            cancelFunc = function()
                onChange(pr, pg, pb, pa)
            end,
        })
    else
        ColorPickerFrame.hasOpacity = true
        ColorPickerFrame.opacity = 1 - a
        ColorPickerFrame.previousValues = { r = r, g = g, b = b, a = a }
        ColorPickerFrame.func = ApplyOld
        ColorPickerFrame.opacityFunc = ApplyOld
        ColorPickerFrame.cancelFunc = function()
            local prev = ColorPickerFrame.previousValues
            onChange(prev.r, prev.g, prev.b, prev.a)
        end
        ColorPickerFrame:SetColorRGB(r, g, b)
        ColorPickerFrame:Hide()
        ColorPickerFrame:Show()
    end
end

local colorsHeader = content:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
colorsHeader:SetPoint("TOPLEFT", applyPos, "BOTTOMLEFT", 0, -22)
colorsHeader:SetText("Style")

local borderAtlasLabel = content:CreateFontString(nil, "ARTWORK", "GameFontNormal")
borderAtlasLabel:SetPoint("TOPLEFT", colorsHeader, "BOTTOMLEFT", 0, -16)
borderAtlasLabel:SetText("Border")

local borderAtlasDropdown = CreateFrame("Frame", "ComboPointCounterBorderAtlasDropdown", content, "UIDropDownMenuTemplate")
borderAtlasDropdown:SetPoint("LEFT", borderAtlasLabel, "RIGHT", 4, -2)
UIDropDownMenu_SetWidth(borderAtlasDropdown, 170)
UIDropDownMenu_SetText(borderAtlasDropdown, "")

local DEFAULT_BG_COLOR = { r = 0, g = 0, b = 0, a = 0.6 }
local DEFAULT_FINISHER_COLOR = { r = 0.75, g = 0.5, b = 0, a = 1 }
local DEFAULT_NUMBER_COLOR = { r = 1, g = 0.82, b = 0, a = 1 }
local DEFAULT_BORDER_TINT = { r = 1, g = 1, b = 1, a = 1 }
local BORDER_TINT_ATLAS = "talents-node-circle-sheenmask"
local COLOR_ROW_SWATCH_X = 170
local COLOR_ROW_RESET_X = 200
local OFFSET_INPUT_X = 70

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

    return row, button, reset
end

local defaultColorRow, defaultColorButton
local finisherColorRow, finisherColorButton
local numberColorRow, numberColorButton
local borderTintRow, borderTintButton
local borderAtlasDropdownInitialized = false
local UpdateContentHeight

local function GetSelectedBorderAtlas()
    local selected = ComboPointCounterDB.borderAtlas
    if CPC.GetBorderAtlas then
        selected = CPC.GetBorderAtlas()
    end
    if not BORDER_ATLAS_LOOKUP[selected] then
        selected = DEFAULT_BORDER_ATLAS
    end
    return selected
end

local function UpdateBorderAtlasDropdownText()
    local selected = GetSelectedBorderAtlas()
    UIDropDownMenu_SetText(borderAtlasDropdown, BORDER_ATLAS_LABELS[selected] or selected)
end

local function IsBorderTintAtlasSelected()
    return GetSelectedBorderAtlas() == BORDER_TINT_ATLAS
end

local function UpdateBorderTintVisibility()
    if not borderTintRow then
        return
    end

    borderTintRow:SetShown(IsBorderTintAtlasSelected())
    if UpdateContentHeight then
        UpdateContentHeight()
    end
end

local function InitializeBorderAtlasDropdown()
    if borderAtlasDropdownInitialized then
        return
    end

    UIDropDownMenu_Initialize(borderAtlasDropdown, function(_, level)
        if level ~= 1 then
            return
        end

        local selected = GetSelectedBorderAtlas()
        for _, atlas in ipairs(BORDER_ATLAS_CHOICES) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = BORDER_ATLAS_LABELS[atlas] or atlas
            info.func = function()
                if CPC.SetBorderAtlas then
                    CPC.SetBorderAtlas(atlas)
                else
                    ComboPointCounterDB.borderAtlas = atlas
                end
                UpdateBorderAtlasDropdownText()
                UpdateBorderTintVisibility()
            end
            info.checked = (atlas == selected)
            UIDropDownMenu_AddButton(info, level)
        end
    end)

    borderAtlasDropdownInitialized = true
end

defaultColorRow, defaultColorButton = CreateColorRow("Default background", borderAtlasLabel, -18, function()
    local r, g, b, a = CPC.GetBackgroundColor()
    ShowColorPicker(r, g, b, a, function(nr, ng, nb, na)
        CPC.SetBackgroundColor(nr, ng, nb, na)
        defaultColorButton.swatch:SetColorTexture(nr, ng, nb, na)
    end)
end, function()
    local c = DEFAULT_BG_COLOR
    CPC.SetBackgroundColor(c.r, c.g, c.b, c.a)
    defaultColorButton.swatch:SetColorTexture(c.r, c.g, c.b, c.a)
end)

finisherColorRow, finisherColorButton = CreateColorRow("Finisher background", defaultColorRow, -6, function()
    local r, g, b, a = CPC.GetFinisherColor()
    ShowColorPicker(r, g, b, a, function(nr, ng, nb, na)
        CPC.SetFinisherColor(nr, ng, nb, na)
        finisherColorButton.swatch:SetColorTexture(nr, ng, nb, na)
    end)
end, function()
    local c = DEFAULT_FINISHER_COLOR
    CPC.SetFinisherColor(c.r, c.g, c.b, c.a)
    finisherColorButton.swatch:SetColorTexture(c.r, c.g, c.b, c.a)
end)

numberColorRow, numberColorButton = CreateColorRow("Number color", finisherColorRow, -6, function()
    local r, g, b, a = CPC.GetNumberColor()
    ShowColorPicker(r, g, b, a, function(nr, ng, nb, na)
        CPC.SetNumberColor(nr, ng, nb, na)
        numberColorButton.swatch:SetColorTexture(nr, ng, nb, na)
    end)
end, function()
    local c = DEFAULT_NUMBER_COLOR
    CPC.SetNumberColor(c.r, c.g, c.b, c.a)
    numberColorButton.swatch:SetColorTexture(c.r, c.g, c.b, c.a)
end)

borderTintRow, borderTintButton = CreateColorRow("Border tint", numberColorRow, -6, function()
    local r, g, b, a = CPC.GetBorderTint()
    ShowColorPicker(r, g, b, a, function(nr, ng, nb, na)
        CPC.SetBorderTint(nr, ng, nb, na)
        borderTintButton.swatch:SetColorTexture(nr, ng, nb, na)
    end)
end, function()
    local c = DEFAULT_BORDER_TINT
    CPC.SetBorderTint(c.r, c.g, c.b, c.a)
    borderTintButton.swatch:SetColorTexture(c.r, c.g, c.b, c.a)
end)
borderTintRow:Hide()

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
    local lastOffsetRow = offsetBoxes[7]
    if not lastOffsetRow then return end

    local top = content:GetTop()
    local offsetBottom = lastOffsetRow:GetBottom()
    local colorBottom = numberColorRow and numberColorRow:GetBottom() or nil
    local borderTintBottom = (borderTintRow and borderTintRow:IsShown()) and borderTintRow:GetBottom() or nil
    if not top or not offsetBottom then return end

    local bottom = offsetBottom
    if colorBottom and colorBottom < bottom then
        bottom = colorBottom
    end
    if borderTintBottom and borderTintBottom < bottom then
        bottom = borderTintBottom
    end

    local height = top - bottom + 20
    if height < 1 then
        height = 1
    end
    content:SetHeight(height)
end

function CPC.RefreshAllOptions()
    alwaysShow:SetChecked(ComboPointCounterDB.alwaysShow)

    sizeSlider:SetValue(ComboPointCounterDB.size)
    sizeBox:SetText(tostring(ComboPointCounterDB.size))

    posX:SetText(ComboPointCounterDB.x or 0)
    posY:SetText(ComboPointCounterDB.y or 0)

    local br, bg, bb, ba = CPC.GetBackgroundColor()
    defaultColorButton.swatch:SetColorTexture(br, bg, bb, ba)

    local fr, fg, fb, fa = CPC.GetFinisherColor()
    finisherColorButton.swatch:SetColorTexture(fr, fg, fb, fa)
    local nr, ng, nb, na = CPC.GetNumberColor()
    numberColorButton.swatch:SetColorTexture(nr, ng, nb, na)
    local tr, tg, tb, ta = CPC.GetBorderTint()
    borderTintButton.swatch:SetColorTexture(tr, tg, tb, ta)
    InitializeBorderAtlasDropdown()
    UpdateBorderAtlasDropdownText()
    UpdateBorderTintVisibility()

    local debugEnabled = ComboPointCounterDB.debugValue ~= nil
    debugCheck:SetChecked(debugEnabled)
    debugBox:SetText(ComboPointCounterDB.debugValue or "")
    SetDebugBoxEnabled(debugEnabled)

    for i = 0, 7 do
        offsetBoxes[i].box:SetText(ComboPointCounterDB.textOffsets[i] or 0)
    end
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
