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
-- Header (mirrors the Blizzard settings category header)
--========================================================--
local title = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightHuge")
title:SetPoint("TOPLEFT", 7, -22)
title:SetText(panel.name)

local version = panel:CreateFontString(nil, "ARTWORK", "GameFontDisable")
version:SetPoint("BOTTOMLEFT", title, "BOTTOMRIGHT", 8, 1)
version:SetText("v" .. (C_AddOns.GetAddOnMetadata(addonName, "Version") or "?"))

local divider = panel:CreateTexture(nil, "ARTWORK")
divider:SetAtlas("Options_HorizontalDivider", true)
divider:SetPoint("TOP", 0, -50)

--========================================================--
-- Scroll Frame
--========================================================--
local scrollFrame = CreateFrame("ScrollFrame", nil, panel)
scrollFrame:SetPoint("TOPLEFT", 0, -56)
scrollFrame:SetPoint("BOTTOMRIGHT", -20, 4)

local scrollBar = CreateFrame("EventFrame", nil, panel, "MinimalScrollBar")
scrollBar:SetPoint("TOPLEFT", scrollFrame, "TOPRIGHT", 6, 0)
scrollBar:SetPoint("BOTTOMLEFT", scrollFrame, "BOTTOMRIGHT", 6, 0)
ScrollUtil.InitScrollFrameWithScrollBar(scrollFrame, scrollBar)

local content = CreateFrame("Frame", nil, scrollFrame)
content:SetPoint("TOPLEFT")
content:SetSize(1, 1)
scrollFrame:SetScrollChild(content)

scrollFrame:HookScript("OnSizeChanged", function(self, width)
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
-- Row Layout (same metrics as the Blizzard settings list)
--========================================================--
local ROW_HEIGHT = 38
local COMPACT_ROW_HEIGHT = 26 -- the long list of digit offsets stays tight
local SECTION_HEIGHT = 45
local LABEL_INDENT = 37
local CONTROL_OFFSET = -80 -- controls start this far left of the row's center
local SLIDER_WIDTH = 200
local RESET_WIDTH = 70

local rows = {}

local function AddSection(text)
    local row = CreateFrame("Frame", nil, content)
    row.height = SECTION_HEIGHT

    local header = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightLarge")
    header:SetPoint("TOPLEFT", 7, -16)
    header:SetText(text)

    rows[#rows + 1] = row
    return row
end

local function AddRow(labelText, height)
    local row = CreateFrame("Frame", nil, content)
    row.height = height or ROW_HEIGHT

    local label = row:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    label:SetPoint("LEFT", LABEL_INDENT, 0)
    label:SetPoint("RIGHT", row, "CENTER", CONTROL_OFFSET - 8, 0)
    label:SetJustifyH("LEFT")
    label:SetText(labelText)

    rows[#rows + 1] = row
    return row
end

local function PlaceControl(row, control)
    control:SetPoint("LEFT", row, "CENTER", CONTROL_OFFSET, 0)
end

-- Stacks the visible rows top to bottom and sizes the scroll child to fit
local function LayoutRows()
    local y = 0
    for _, row in ipairs(rows) do
        if row:IsShown() then
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -y)
            row:SetPoint("TOPRIGHT", content, "TOPRIGHT", 0, -y)
            row:SetHeight(row.height)
            y = y + row.height
        end
    end
    content:SetHeight(y + 16)
end

--========================================================--
-- Widget Factories
--========================================================--
-- Set while RefreshAllOptions syncs widgets, so programmatic SetValue calls
-- don't feed clamped slider values back into the saved settings.
local refreshing = false

local function CreateCheckbox(parent)
    local check = CreateFrame("CheckButton", nil, parent)
    check:SetSize(30, 29)
    check:SetNormalAtlas("checkbox-minimal")
    check:SetPushedAtlas("checkbox-minimal")
    check:SetHighlightAtlas("checkbox-minimal", "ADD")

    local mark = check:CreateTexture(nil, "OVERLAY")
    mark:SetAtlas("checkmark-minimal")
    mark:SetAllPoints()
    check:SetCheckedTexture(mark)

    local disabledMark = check:CreateTexture(nil, "OVERLAY")
    disabledMark:SetAtlas("checkmark-minimal-disabled")
    disabledMark:SetAllPoints()
    check:SetDisabledCheckedTexture(disabledMark)

    return check
end

local function FormatInteger(value)
    return math.floor(value + 0.5)
end

local function CreateSlider(row, minValue, maxValue, onChange)
    local slider = CreateFrame("Frame", nil, row, "MinimalSliderWithSteppersTemplate")
    slider:SetWidth(SLIDER_WIDTH)
    PlaceControl(row, slider)
    slider:Init(minValue, minValue, maxValue, maxValue - minValue, {
        [MinimalSliderWithSteppersMixin.Label.Right] = FormatInteger,
    })
    slider:RegisterCallback(MinimalSliderWithSteppersMixin.Event.OnValueChanged, function(_, value)
        if refreshing then return end
        onChange(FormatInteger(value))
    end, slider)
    return slider
end

local function CreateResetButton(row, anchor, xOffset, onClick)
    local reset = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
    reset:SetSize(RESET_WIDTH, 22)
    reset:SetPoint("LEFT", anchor, "RIGHT", xOffset, 0)
    reset:SetText("Reset")
    reset:SetScript("OnClick", onClick)
    return reset
end

-- Edits are committed when the box loses focus (Enter, Tab or clicking away) and
-- undone by Escape. Either way the refresh then shows the saved value again.
local function CreateInputBox(parent, width, allowNegative, commit)
    local box = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
    box:SetSize(width, 20)
    box:SetAutoFocus(false)
    SetIntegerInputFilter(box, allowNegative)
    RegisterTabBox(box)

    box:SetScript("OnEnterPressed", box.ClearFocus)
    box:SetScript("OnEscapePressed", function(self)
        self.cancelled = true
        self:ClearFocus()
    end)
    box:HookScript("OnEditFocusLost", function(self)
        if self.cancelled then
            self.cancelled = nil
        else
            commit(self)
        end
        CPC.NotifyOptions()
    end)
    return box
end

-- A box being typed in is left alone so a refresh doesn't wipe the edit
local function SetBoxText(box, value)
    if not box:HasFocus() then
        box:SetText(value)
    end
end

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

local function CreateColorSwatch(row, onClick)
    local button = CreateFrame("Button", nil, row)
    button:SetSize(22, 22)
    PlaceControl(row, button)

    local edge = button:CreateTexture(nil, "BACKGROUND")
    edge:SetAllPoints()
    edge:SetColorTexture(0.6, 0.6, 0.6, 1)

    local inner = button:CreateTexture(nil, "BORDER")
    inner:SetPoint("TOPLEFT", 1, -1)
    inner:SetPoint("BOTTOMRIGHT", -1, 1)
    inner:SetColorTexture(0, 0, 0, 1)

    local swatch = button:CreateTexture(nil, "ARTWORK")
    swatch:SetPoint("TOPLEFT", 3, -3)
    swatch:SetPoint("BOTTOMRIGHT", -3, 3)

    local highlight = button:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetAllPoints()
    highlight:SetColorTexture(1, 1, 1, 0.2)

    button.swatch = swatch
    button:SetScript("OnClick", onClick)
    return button
end

--========================================================--
-- General
--========================================================--
AddSection("General")

local alwaysShowRow = AddRow("Always Show")
local alwaysShow = CreateCheckbox(alwaysShowRow)
PlaceControl(alwaysShowRow, alwaysShow)
alwaysShow:SetScript("OnClick", function(self)
    CPC.SetAlwaysShow(self:GetChecked())
end)

local sizeRow = AddRow("Frame Size")
local sizeSlider = CreateSlider(sizeRow, 8, 128, CPC.SetFrameSize)
CreateResetButton(sizeRow, sizeSlider, 40, function()
    CPC.SetFrameSize(DEFAULTS.size)
end)

local posRow = AddRow("Frame Position")

local posXLabel = posRow:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
PlaceControl(posRow, posXLabel)
posXLabel:SetText("X")

local posX, posY

local function ApplyPosition()
    local x = ParseInteger(posX:GetText())
    local y = ParseInteger(posY:GetText())
    if x and y then
        CPC.SetFramePosition(x, y)
    end
end

posX = CreateInputBox(posRow, 55, true, ApplyPosition)
posX:SetPoint("LEFT", posXLabel, "RIGHT", 10, 0)

local posYLabel = posRow:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
posYLabel:SetPoint("LEFT", posX, "RIGHT", 10, 0)
posYLabel:SetText("Y")

posY = CreateInputBox(posRow, 55, true, ApplyPosition)
posY:SetPoint("LEFT", posYLabel, "RIGHT", 10, 0)

local applyPos = CreateFrame("Button", nil, posRow, "UIPanelButtonTemplate")
applyPos:SetSize(RESET_WIDTH, 22)
applyPos:SetPoint("LEFT", posY, "RIGHT", 8, 0)
applyPos:SetText("Apply")
applyPos:SetScript("OnClick", ApplyPosition)

CreateResetButton(posRow, applyPos, 4, function()
    CPC.SetFramePosition(DEFAULTS.x, DEFAULTS.y)
end)

--========================================================--
-- Appearance
--========================================================--
AddSection("Appearance")

-- Same dropdown-with-arrows control the Blizzard settings list uses
local borderRow = AddRow("Border")
local borderControl = CreateFrame("Frame", nil, borderRow, "SettingsDropdownWithButtonsTemplate")
borderControl:SetWidth(SLIDER_WIDTH)
PlaceControl(borderRow, borderControl)
local borderDropdown = borderControl.Dropdown

local function IsBorderSelected(atlas)
    return ComboPointCounterDB.borderAtlas == atlas
end

borderDropdown:SetupMenu(function(_, rootDescription)
    for _, info in ipairs(CPC.BORDERS) do
        rootDescription:CreateRadio(info.label, IsBorderSelected, CPC.SetBorderAtlas, info.atlas)
    end
end)

local function GetBorderIndex()
    return CPC.BORDER_BY_ATLAS[ComboPointCounterDB.borderAtlas].index
end

local function StepBorder(delta)
    local info = CPC.BORDERS[GetBorderIndex() + delta]
    if info then
        CPC.SetBorderAtlas(info.atlas)
    end
end

borderControl.DecrementButton:SetScript("OnClick", function() StepBorder(-1) end)
borderControl.IncrementButton:SetScript("OnClick", function() StepBorder(1) end)

-- Same gap as the slider rows so the Reset buttons line up
CreateResetButton(borderRow, borderControl, 40, function()
    CPC.SetBorderAtlas(DEFAULTS.borderAtlas)
end)

local function UpdateBorderControl()
    local index = GetBorderIndex()
    borderDropdown:GenerateMenu()
    borderControl.DecrementButton:SetEnabled(index > 1)
    borderControl.IncrementButton:SetEnabled(index < #CPC.BORDERS)
end

local thresholdRow = AddRow("Finisher Threshold")
local thresholdSlider = CreateSlider(thresholdRow, 1, 7, CPC.SetFinisherThreshold)
CreateResetButton(thresholdRow, thresholdSlider, 40, function()
    CPC.SetFinisherThreshold(DEFAULTS.finisherThreshold)
end)

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

for _, info in ipairs(COLOR_ROWS) do
    local key = info.key
    local row = AddRow(info.label)
    local button = CreateColorSwatch(row, function()
        local r, g, b, a = CPC.GetColor(key)
        ShowColorPicker(r, g, b, a, function(nr, ng, nb, na)
            CPC.SetColor(key, nr, ng, nb, na)
        end)
    end)
    CreateResetButton(row, button, 8, function()
        local c = DEFAULTS[key]
        CPC.SetColor(key, c.r, c.g, c.b, c.a)
    end)

    colorRows[key] = row
    colorButtons[key] = button
end

local borderTintRow = colorRows.borderTint
borderTintRow:Hide()

local function UpdateBorderTintVisibility()
    local shown = ComboPointCounterDB.borderAtlas == CPC.BORDER_TINT_ATLAS
    if borderTintRow:IsShown() ~= shown then
        borderTintRow:SetShown(shown)
        LayoutRows()
    end
end

--========================================================--
-- Digit Adjustment
--========================================================--
AddSection("Digit Adjustment")

local debugRow = AddRow("Force Number", COMPACT_ROW_HEIGHT)
local debugCheck = CreateCheckbox(debugRow)
PlaceControl(debugRow, debugCheck)

local debugBox = CreateInputBox(debugRow, 40, false, function(self)
    local v = ParseInteger(self:GetText())
    if v then
        CPC.SetDebugValue(math.max(0, math.min(7, v)))
    end
end)
debugBox:SetPoint("LEFT", debugCheck, "RIGHT", 10, 0)

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

local offsetBoxes = {}

for i = 0, 7 do
    local row = AddRow("Offset " .. i, COMPACT_ROW_HEIGHT)
    local box = CreateInputBox(row, 40, true, function(self)
        local v = ParseInteger(self:GetText())
        if v then
            CPC.SetTextOffset(i, v)
        end
    end)
    -- InputBoxTemplate art extends left of the frame, so nudge it to line up with the other controls
    box:SetPoint("LEFT", row, "CENTER", CONTROL_OFFSET + 6, 0)

    offsetBoxes[i] = box
end

LayoutRows()

--========================================================--
-- Unified Refresh
--========================================================--
function CPC.RefreshAllOptions()
    local db = ComboPointCounterDB
    refreshing = true

    alwaysShow:SetChecked(db.alwaysShow)

    sizeSlider:SetValue(db.size)

    SetBoxText(posX, db.x)
    SetBoxText(posY, db.y)

    for key, button in pairs(colorButtons) do
        button.swatch:SetColorTexture(CPC.GetColor(key))
    end
    UpdateBorderControl()
    UpdateBorderTintVisibility()

    thresholdSlider:SetValue(db.finisherThreshold)

    -- Force Number stays on while its first value is still being typed
    local debugEnabled = db.debugValue ~= nil or debugBox:HasFocus()
    debugCheck:SetChecked(debugEnabled)
    SetBoxText(debugBox, db.debugValue or "")
    SetDebugBoxEnabled(debugEnabled)

    for i = 0, 7 do
        SetBoxText(offsetBoxes[i], db.textOffsets[i])
    end

    refreshing = false
end

panel:SetScript("OnShow", CPC.RefreshAllOptions)
