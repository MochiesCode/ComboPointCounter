-- Only load if player is a supported class
local _, class = UnitClass("player")
if class ~= "ROGUE" and class ~= "DRUID" then return end

-- Namespace
local addonName, CPC = ...

local BORDER_ATLAS_CHOICES = {
    "ChallengeMode-KeystoneSlotFrameGlow",
    "lemixArtifact-node-circle-glw-FX",
    "ChallengeMode-KeystoneSlotFrame",
    "dragonflight-landingbutton-circlehighlight",
    "services-cover-ring",
    "talents-node-circle-sheenmask",
}

local BORDER_ATLAS_LOOKUP = {}
for _, atlas in ipairs(BORDER_ATLAS_CHOICES) do
    BORDER_ATLAS_LOOKUP[atlas] = true
end

local DEFAULT_BORDER_ATLAS = BORDER_ATLAS_CHOICES[1]
CPC.BORDER_ATLAS_CHOICES = BORDER_ATLAS_CHOICES
local BORDER_TINT_ATLAS = "talents-node-circle-sheenmask"
local DEFAULT_NUMBER_COLOR = { r = 1, g = 0.82, b = 0, a = 1 }
local SMALL_BORDER_SCALE = 0.6
local SLIGHTLY_LARGER_SMALL_SCALE = SMALL_BORDER_SCALE * 1.05
local TINT_BORDER_SCALE = 0.84
local BORDER_SIZE_SCALE_BY_ATLAS = {
    ["dragonflight-landingbutton-circlehighlight"] = SLIGHTLY_LARGER_SMALL_SCALE,
    ["services-cover-ring"] = SLIGHTLY_LARGER_SMALL_SCALE,
    ["talents-node-circle-sheenmask"] = TINT_BORDER_SCALE,
}
local BORDER_Y_OFFSET_BY_ATLAS = {
    ["dragonflight-landingbutton-circlehighlight"] = -0.5,
    ["services-cover-ring"] = -0.6,
}
local BORDER_X_OFFSET_BY_ATLAS = {
    ["dragonflight-landingbutton-circlehighlight"] = -0.5,
    ["services-cover-ring"] = -0.5,
}

local BASE_FONT, BASE_FONT_SIZE, BASE_FONT_FLAGS = GameFontNormalLarge:GetFont()

-- Saved variables
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
ComboPointCounterDB.numberColor.r = ComboPointCounterDB.numberColor.r or DEFAULT_NUMBER_COLOR.r
ComboPointCounterDB.numberColor.g = ComboPointCounterDB.numberColor.g or DEFAULT_NUMBER_COLOR.g
ComboPointCounterDB.numberColor.b = ComboPointCounterDB.numberColor.b or DEFAULT_NUMBER_COLOR.b
ComboPointCounterDB.numberColor.a = ComboPointCounterDB.numberColor.a or DEFAULT_NUMBER_COLOR.a
ComboPointCounterDB.borderTint = ComboPointCounterDB.borderTint or {}
ComboPointCounterDB.borderTint.r = ComboPointCounterDB.borderTint.r or 1
ComboPointCounterDB.borderTint.g = ComboPointCounterDB.borderTint.g or 1
ComboPointCounterDB.borderTint.b = ComboPointCounterDB.borderTint.b or 1
ComboPointCounterDB.borderTint.a = ComboPointCounterDB.borderTint.a or 1
if not BORDER_ATLAS_LOOKUP[ComboPointCounterDB.borderAtlas] then
    ComboPointCounterDB.borderAtlas = DEFAULT_BORDER_ATLAS
end

--========================================================--
-- Options Sync
--========================================================--
function CPC.NotifyOptions()
    if CPC.OptionsPanel and CPC.OptionsPanel:IsShown() and CPC.RefreshAllOptions then
        CPC.RefreshAllOptions()
    end
end

--========================================================--
-- Frame
--========================================================--
local frame = CreateFrame("Frame", "ComboPointCounter", UIParent)
frame:SetPoint(
    ComboPointCounterDB.point,
    UIParent,
    ComboPointCounterDB.point,
    ComboPointCounterDB.x,
    ComboPointCounterDB.y
)
frame:SetSize(ComboPointCounterDB.size, ComboPointCounterDB.size)
frame:SetMovable(true)
frame:EnableMouse(true)
frame:RegisterForDrag("LeftButton")
CPC.frame = frame

--========================================================--
-- Drag Handling
--========================================================--
frame:SetScript("OnDragStart", function(self)
    if IsShiftKeyDown() then
        self:StartMoving()
    end
end)

frame:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()

    local _, _, _, x, y = self:GetPoint()
    CPC.SetFramePosition(math.floor(x + 0.5), math.floor(y + 0.5))
end)

--========================================================--
-- Background
--========================================================--
local fill = frame:CreateTexture(nil, "BACKGROUND")
fill:SetAllPoints()
fill:SetColorTexture(0, 0, 0, 0.6)

local mask = frame:CreateMaskTexture()
mask:SetTexture("Interface/CharacterFrame/TempPortraitAlphaMask")
mask:SetAllPoints(fill)
fill:AddMaskTexture(mask)

local border = frame:CreateTexture(nil, "BORDER")
border:SetPoint("CENTER")
border:SetAtlas(ComboPointCounterDB.borderAtlas)
if border.SetSnapToPixelGrid then
    border:SetSnapToPixelGrid(false)
end
if border.SetTexelSnappingBias then
    border:SetTexelSnappingBias(0)
end

--========================================================--
-- Counter Text
--========================================================--
local text = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
local BASE_FRAME_SIZE = 25
text:SetShadowOffset(1.5, -1.5)
text:SetShadowColor(0, 0, 0, 0.8)

--========================================================--
-- Core Update Functions
--========================================================--
local function ClampChannel(value, fallback)
    if value == nil then
        return fallback
    end
    value = tonumber(value)
    if not value then
        return fallback
    end
    if value < 0 then return 0 end
    if value > 1 then return 1 end
    return value
end

local function ApplyFillColor(comboPoint)
    local color = comboPoint >= 5 and ComboPointCounterDB.finisherColor or ComboPointCounterDB.backgroundColor
    fill:SetColorTexture(color.r, color.g, color.b, color.a)
end

local function UpdateCounter()
    C_Timer.After(0, function() -- Delayed by a frame because it doesn't always update offsets correctly if I don't
        local comboPoint = ComboPointCounterDB.debugValue or UnitPower("player", Enum.PowerType.ComboPoints) or 0

        text:SetText("") -- More offset weirdness, need this for some reason
        text:SetText(comboPoint)
        local xOffset = ComboPointCounterDB.textOffsets[comboPoint] or 0
        text:SetPoint("CENTER", frame, "CENTER", xOffset, 0)

        ApplyFillColor(comboPoint)
    end)
end
CPC.UpdateCounter = UpdateCounter

local function IsDruidCatForm()
    if class ~= "DRUID" then
        return false
    end

    if not GetShapeshiftForm then
        return false
    end

    local currentForm = GetShapeshiftForm()
    if not currentForm or currentForm == 0 then
        return false
    end

    if GetShapeshiftFormID and CAT_FORM then
        return GetShapeshiftFormID() == CAT_FORM
    end

    local _, powerTypeToken = UnitPowerType("player")
    return powerTypeToken == "ENERGY"
end

local function IsDisplaySupported()
    if class == "ROGUE" then
        return true
    end

    return IsDruidCatForm()
end

local function UpdateVisibility()
    if not IsDisplaySupported() then
        frame:Hide()
        return
    end

    if ComboPointCounterDB.alwaysShow or UnitAffectingCombat("player") then
        frame:Show()
        UpdateCounter()
    else
        frame:Hide()
    end
end
CPC.UpdateVisibility = UpdateVisibility

local function UpdateFontSize()
    local scale = ComboPointCounterDB.size / BASE_FRAME_SIZE
    local fontSize = math.floor(BASE_FONT_SIZE * scale + 0.5)
    text:SetFont(BASE_FONT, fontSize, BASE_FONT_FLAGS)
end

local function ApplyNumberColor()
    local c = ComboPointCounterDB.numberColor
    text:SetTextColor(c.r, c.g, c.b, c.a)
end

local function UpdateBorderSize()
    local atlas = ComboPointCounterDB.borderAtlas
    local sizeScale = BORDER_SIZE_SCALE_BY_ATLAS[atlas] or 1
    local borderSize = ComboPointCounterDB.size * 2 * sizeScale

    borderSize = math.floor(borderSize + 0.5)
    if borderSize < 1 then
        borderSize = 1
    end
    if borderSize % 2 ~= 0 then
        borderSize = borderSize + 1
    end
    border:SetSize(borderSize, borderSize)
end

local function ApplyBorderTint()
    if ComboPointCounterDB.borderAtlas == BORDER_TINT_ATLAS then
        local c = ComboPointCounterDB.borderTint
        border:SetVertexColor(c.r, c.g, c.b, c.a)
    else
        border:SetVertexColor(1, 1, 1, 1)
    end
end

local function ApplyBorderAtlas()
    local atlas = ComboPointCounterDB.borderAtlas
    if not BORDER_ATLAS_LOOKUP[atlas] then
        atlas = DEFAULT_BORDER_ATLAS
        ComboPointCounterDB.borderAtlas = atlas
    end

    border:ClearAllPoints()
    border:SetPoint(
        "CENTER",
        frame,
        "CENTER",
        BORDER_X_OFFSET_BY_ATLAS[atlas] or 0,
        BORDER_Y_OFFSET_BY_ATLAS[atlas] or 0
    )
    border:SetAtlas(atlas)
    UpdateBorderSize()
    ApplyBorderTint()
end

--========================================================--
-- Public Setters
--========================================================--
function CPC.SetAlwaysShow(value)
    ComboPointCounterDB.alwaysShow = value and true or false
    UpdateVisibility()
    CPC.NotifyOptions()
end

function CPC.SetFrameSize(size)
    size = tonumber(size)
    if not size or size <= 0 then return end

    ComboPointCounterDB.size = size
    frame:SetSize(size, size)
    UpdateBorderSize()

    UpdateFontSize()
    UpdateCounter()
    CPC.NotifyOptions()
end

function CPC.SetFramePosition(x, y)
    frame:ClearAllPoints()
    frame:SetPoint("CENTER", UIParent, "CENTER", x, y)

    ComboPointCounterDB.point = "CENTER"
    ComboPointCounterDB.x = x
    ComboPointCounterDB.y = y

    CPC.NotifyOptions()
end

function CPC.GetFramePosition()
    return ComboPointCounterDB.x or 0, ComboPointCounterDB.y or 0
end

function CPC.SetDebugValue(value)
    ComboPointCounterDB.debugValue = value
    UpdateCounter()
    CPC.NotifyOptions()
end

function CPC.SetTextOffset(index, value)
    ComboPointCounterDB.textOffsets[index] = value or 0
    UpdateCounter()
    CPC.NotifyOptions()
end

function CPC.SetBackgroundColor(r, g, b, a)
    local c = ComboPointCounterDB.backgroundColor
    c.r = ClampChannel(r, c.r)
    c.g = ClampChannel(g, c.g)
    c.b = ClampChannel(b, c.b)
    c.a = ClampChannel(a, c.a)
    UpdateCounter()
    CPC.NotifyOptions()
end

function CPC.GetBackgroundColor()
    local c = ComboPointCounterDB.backgroundColor
    return c.r, c.g, c.b, c.a
end

function CPC.SetFinisherColor(r, g, b, a)
    local c = ComboPointCounterDB.finisherColor
    c.r = ClampChannel(r, c.r)
    c.g = ClampChannel(g, c.g)
    c.b = ClampChannel(b, c.b)
    c.a = ClampChannel(a, c.a)
    UpdateCounter()
    CPC.NotifyOptions()
end

function CPC.GetFinisherColor()
    local c = ComboPointCounterDB.finisherColor
    return c.r, c.g, c.b, c.a
end

function CPC.SetNumberColor(r, g, b, a)
    local c = ComboPointCounterDB.numberColor
    c.r = ClampChannel(r, c.r)
    c.g = ClampChannel(g, c.g)
    c.b = ClampChannel(b, c.b)
    c.a = ClampChannel(a, c.a)
    ApplyNumberColor()
    CPC.NotifyOptions()
end

function CPC.GetNumberColor()
    local c = ComboPointCounterDB.numberColor
    return c.r, c.g, c.b, c.a
end

function CPC.SetBorderTint(r, g, b, a)
    local c = ComboPointCounterDB.borderTint
    c.r = ClampChannel(r, c.r)
    c.g = ClampChannel(g, c.g)
    c.b = ClampChannel(b, c.b)
    c.a = ClampChannel(a, c.a)
    ApplyBorderTint()
    CPC.NotifyOptions()
end

function CPC.GetBorderTint()
    local c = ComboPointCounterDB.borderTint
    return c.r, c.g, c.b, c.a
end

function CPC.SetBorderAtlas(atlas)
    if not BORDER_ATLAS_LOOKUP[atlas] then
        return
    end

    ComboPointCounterDB.borderAtlas = atlas
    ApplyBorderAtlas()
    CPC.NotifyOptions()
end

function CPC.GetBorderAtlas()
    local atlas = ComboPointCounterDB.borderAtlas
    if BORDER_ATLAS_LOOKUP[atlas] then
        return atlas
    end

    return DEFAULT_BORDER_ATLAS
end

--========================================================--
-- Event Handling
--========================================================--
local function HandleEvent(self, event, unit, powerType)
    if event == "PLAYER_REGEN_DISABLED" or event == "PLAYER_REGEN_ENABLED" or event == "PLAYER_ENTERING_WORLD"
        or event == "UPDATE_SHAPESHIFT_FORM"
    then
        UpdateVisibility()
    elseif event == "UNIT_POWER_UPDATE" then
        if unit == "player" and powerType == "COMBO_POINTS" then
            UpdateCounter()
        end
    end
end

frame:RegisterEvent("PLAYER_REGEN_DISABLED")
frame:RegisterEvent("PLAYER_REGEN_ENABLED")
frame:RegisterEvent("UNIT_POWER_UPDATE")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
if class == "DRUID" then
    frame:RegisterEvent("UPDATE_SHAPESHIFT_FORM")
end
frame:SetScript("OnEvent", HandleEvent)

ApplyBorderAtlas()
ApplyNumberColor()
UpdateVisibility()
UpdateFontSize()
