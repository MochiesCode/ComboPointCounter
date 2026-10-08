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
local BORDER_TINT_ATLAS = "talents-node-circle-sheenmask"
CPC.BORDER_ATLAS_CHOICES = BORDER_ATLAS_CHOICES
CPC.BORDER_ATLAS_LOOKUP = BORDER_ATLAS_LOOKUP
CPC.BORDER_TINT_ATLAS = BORDER_TINT_ATLAS

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
local CAT_FORM_ID = CAT_FORM or 1

--========================================================--
-- Saved Variables
--========================================================--
local DEFAULTS = {
    alwaysShow = false,
    point = "CENTER",
    x = 0,
    y = 0,
    size = 25,
    textOffsets = { [0] = 0, 0, 0, 0, 0, 0, 0, 0 },
    finisherThreshold = 6,
    backgroundColor = { r = 0, g = 0, b = 0, a = 0.6 },
    finisherColor = { r = 0.75, g = 0.5, b = 0, a = 1 },
    numberColor = { r = 1, g = 0.82, b = 0, a = 1 },
    finisherNumberColor = { r = 1, g = 1, b = 1, a = 1 },
    borderTint = { r = 1, g = 1, b = 1, a = 1 },
    borderAtlas = DEFAULT_BORDER_ATLAS,
}
CPC.DEFAULTS = DEFAULTS

-- Fills in any missing keys without overwriting saved values
local function ApplyDefaults(db, defaults)
    for key, value in pairs(defaults) do
        if type(value) == "table" then
            if type(db[key]) ~= "table" then
                db[key] = {}
            end
            ApplyDefaults(db[key], value)
        elseif db[key] == nil then
            db[key] = value
        end
    end
end

ComboPointCounterDB = ComboPointCounterDB or {}
ApplyDefaults(ComboPointCounterDB, DEFAULTS)
if not BORDER_ATLAS_LOOKUP[ComboPointCounterDB.borderAtlas] then
    ComboPointCounterDB.borderAtlas = DEFAULT_BORDER_ATLAS
end

--========================================================--
-- Options Sync
--========================================================--
function CPC.NotifyOptions()
    if CPC.OptionsPanel and CPC.OptionsPanel:IsShown() then
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
border:SetSnapToPixelGrid(false)
border:SetTexelSnappingBias(0)

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
    value = tonumber(value)
    if not value then
        return fallback
    end
    if value < 0 then return 0 end
    if value > 1 then return 1 end
    return value
end

local function ApplyColors(comboPoint)
    local db = ComboPointCounterDB
    local isFinisher = comboPoint >= db.finisherThreshold
    local fillColor = isFinisher and db.finisherColor or db.backgroundColor
    local numberColor = isFinisher and db.finisherNumberColor or db.numberColor
    fill:SetColorTexture(fillColor.r, fillColor.g, fillColor.b, fillColor.a)
    text:SetTextColor(numberColor.r, numberColor.g, numberColor.b, numberColor.a)
end

local updatePending = false

local function DoUpdateCounter()
    updatePending = false
    local comboPoint = ComboPointCounterDB.debugValue or UnitPower("player", Enum.PowerType.ComboPoints) or 0

    text:SetText("") -- More offset weirdness, need this for some reason
    text:SetText(comboPoint)
    local xOffset = ComboPointCounterDB.textOffsets[comboPoint] or 0
    text:SetPoint("CENTER", frame, "CENTER", xOffset, 0)

    ApplyColors(comboPoint)
end

-- Delayed by a frame because it doesn't always update offsets correctly if I don't.
-- Multiple calls within the same frame collapse into a single update.
local function UpdateCounter()
    if updatePending then return end
    updatePending = true
    C_Timer.After(0, DoUpdateCounter)
end
CPC.UpdateCounter = UpdateCounter

local function IsDisplaySupported()
    return class == "ROGUE" or GetShapeshiftFormID() == CAT_FORM_ID
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

function CPC.SetFinisherThreshold(value)
    value = tonumber(value)
    if not value then return end

    value = math.floor(value + 0.5)
    if value < 1 then value = 1 end
    if value > 7 then value = 7 end

    ComboPointCounterDB.finisherThreshold = value
    UpdateCounter()
    CPC.NotifyOptions()
end

-- Colors that need something other than UpdateCounter to redraw
local COLOR_APPLIERS = {
    borderTint = ApplyBorderTint,
}

-- key is one of the color tables in DEFAULTS (backgroundColor, borderTint, ...)
function CPC.SetColor(key, r, g, b, a)
    local c = ComboPointCounterDB[key]
    c.r = ClampChannel(r, c.r)
    c.g = ClampChannel(g, c.g)
    c.b = ClampChannel(b, c.b)
    c.a = ClampChannel(a, c.a)
    local apply = COLOR_APPLIERS[key] or UpdateCounter
    apply()
    CPC.NotifyOptions()
end

function CPC.GetColor(key)
    local c = ComboPointCounterDB[key]
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

--========================================================--
-- Event Handling
--========================================================--
local function HandleEvent(self, event, unit, powerType)
    if event == "UNIT_POWER_UPDATE" then
        -- Hidden frames get refreshed by UpdateVisibility when they're shown
        if powerType == "COMBO_POINTS" and frame:IsShown() then
            UpdateCounter()
        end
    else
        UpdateVisibility()
    end
end

frame:RegisterEvent("PLAYER_REGEN_DISABLED")
frame:RegisterEvent("PLAYER_REGEN_ENABLED")
frame:RegisterUnitEvent("UNIT_POWER_UPDATE", "player")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
if class == "DRUID" then
    frame:RegisterEvent("UPDATE_SHAPESHIFT_FORM")
end
frame:SetScript("OnEvent", HandleEvent)

ApplyBorderAtlas()
UpdateFontSize()
UpdateVisibility()
