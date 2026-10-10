-- Only load if player is a supported class
local _, class = UnitClass("player")
if class ~= "ROGUE" and class ~= "DRUID" then return end

-- Namespace
local addonName, CPC = ...

-- Border choices in menu order. scale/x/y adjust atlases whose art isn't sized or centered like the rest.
local BORDERS = {
    { atlas = "ChallengeMode-KeystoneSlotFrameGlow", label = "Glow 1" },
    { atlas = "lemixArtifact-node-circle-glw-FX", label = "Glow 2" },
    { atlas = "ChallengeMode-KeystoneSlotFrame", label = "Ornate" },
    { atlas = "dragonflight-landingbutton-circlehighlight", label = "Container", scale = 0.63, x = -0.5, y = -0.5 },
    { atlas = "services-cover-ring", label = "Ring", scale = 0.63, x = -0.5, y = -0.6 },
    { atlas = "talents-node-circle-sheenmask", label = "Solid Color", scale = 0.84 },
}

local BORDER_BY_ATLAS = {}
for i, info in ipairs(BORDERS) do
    info.index = i
    BORDER_BY_ATLAS[info.atlas] = info
end

local DEFAULT_BORDER_ATLAS = BORDERS[1].atlas
local BORDER_TINT_ATLAS = "talents-node-circle-sheenmask"
CPC.BORDERS = BORDERS
CPC.BORDER_BY_ATLAS = BORDER_BY_ATLAS
CPC.BORDER_TINT_ATLAS = BORDER_TINT_ATLAS

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
if not BORDER_BY_ATLAS[ComboPointCounterDB.borderAtlas] then
    ComboPointCounterDB.borderAtlas = DEFAULT_BORDER_ATLAS
end
-- Force Number is only a preview, so it never survives a reload
ComboPointCounterDB.debugValue = nil

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
frame:RegisterForDrag("LeftButton")
CPC.frame = frame

--========================================================--
-- Drag Handling
--========================================================--
-- The frame only takes the mouse while Shift is held, so it never blocks clicks on the world.
-- A drag keeps the mouse until it ends, even if Shift is let go first.
local dragging = false

local function UpdateMouse()
    frame:EnableMouse(dragging or IsShiftKeyDown())
end

local function StopDrag(self)
    self:StopMovingOrSizing()
    dragging = false
    UpdateMouse()

    local _, _, _, x, y = self:GetPoint()
    CPC.SetFramePosition(math.floor(x + 0.5), math.floor(y + 0.5))
end

frame:SetScript("OnDragStart", function(self)
    if IsShiftKeyDown() then
        dragging = true
        self:StartMoving()
    end
end)

frame:SetScript("OnDragStop", StopDrag)

-- Combat can end mid-drag and hide the frame
frame:SetScript("OnHide", function(self)
    if dragging then
        StopDrag(self)
    end
end)

--========================================================--
-- Background
--========================================================--
local fill = frame:CreateTexture(nil, "BACKGROUND")
fill:SetAllPoints()

local mask = frame:CreateMaskTexture()
mask:SetTexture("Interface/CharacterFrame/TempPortraitAlphaMask")
mask:SetAllPoints(fill)
fill:AddMaskTexture(mask)

local border = frame:CreateTexture(nil, "BORDER")
border:SetSnapToPixelGrid(false)
border:SetTexelSnappingBias(0)

--========================================================--
-- Counter Text
--========================================================--
local text = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
text:SetShadowOffset(1.5, -1.5)
text:SetShadowColor(0, 0, 0, 0.8)

--========================================================--
-- Core Update Functions
--========================================================--
local function ApplyColors(comboPoint)
    local db = ComboPointCounterDB
    -- Never ask for more points than the player can hold (druids and untalented rogues cap at 5)
    local maxPoints = UnitPowerMax("player", Enum.PowerType.ComboPoints)
    local threshold = math.max(1, math.min(db.finisherThreshold, maxPoints))
    local isFinisher = comboPoint >= threshold
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
    local scale = ComboPointCounterDB.size / DEFAULTS.size
    local fontSize = math.floor(BASE_FONT_SIZE * scale + 0.5)
    text:SetFont(BASE_FONT, fontSize, BASE_FONT_FLAGS)
end

local function UpdateBorderSize()
    local sizeScale = BORDER_BY_ATLAS[ComboPointCounterDB.borderAtlas].scale or 1
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
    local info = BORDER_BY_ATLAS[ComboPointCounterDB.borderAtlas]

    border:ClearAllPoints()
    border:SetPoint("CENTER", frame, "CENTER", info.x or 0, info.y or 0)
    border:SetAtlas(info.atlas)
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
    ComboPointCounterDB.finisherThreshold = value
    UpdateCounter()
    CPC.NotifyOptions()
end

-- key is one of the color tables in DEFAULTS (backgroundColor, borderTint, ...)
function CPC.SetColor(key, r, g, b, a)
    local c = ComboPointCounterDB[key]
    c.r, c.g, c.b, c.a = r, g, b, a
    if key == "borderTint" then
        ApplyBorderTint()
    else
        UpdateCounter()
    end
    CPC.NotifyOptions()
end

function CPC.GetColor(key)
    local c = ComboPointCounterDB[key]
    return c.r, c.g, c.b, c.a
end

function CPC.SetBorderAtlas(atlas)
    if not BORDER_BY_ATLAS[atlas] then
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
    elseif event == "MODIFIER_STATE_CHANGED" then
        UpdateMouse()
    else
        UpdateVisibility()
    end
end

frame:RegisterEvent("PLAYER_REGEN_DISABLED")
frame:RegisterEvent("PLAYER_REGEN_ENABLED")
frame:RegisterUnitEvent("UNIT_POWER_UPDATE", "player")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("MODIFIER_STATE_CHANGED")
if class == "DRUID" then
    frame:RegisterEvent("UPDATE_SHAPESHIFT_FORM")
end
frame:SetScript("OnEvent", HandleEvent)

ApplyBorderAtlas()
UpdateFontSize()
UpdateVisibility()
