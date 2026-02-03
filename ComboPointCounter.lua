-- Only load if player is a rogue
local _, class = UnitClass("player")
if class ~= "ROGUE" then return end

-- Namespace
local addonName, CPC = ...

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
border:SetAtlas("ChallengeMode-KeystoneSlotFrameGlow")
border:SetSize(ComboPointCounterDB.size * 2, ComboPointCounterDB.size * 2)

--========================================================--
-- Counter Text
--========================================================--
local text = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
local BASE_FONT, BASE_FONT_SIZE, BASE_FONT_FLAGS = GameFontNormalLarge:GetFont()
local BASE_FRAME_SIZE = 25
text:SetShadowOffset(1.5, -1.5)
text:SetShadowColor(0, 0, 0, 0.8)

--========================================================--
-- Core Update Functions
--========================================================--
local function UpdateCounter()
    C_Timer.After(0, function() -- Delayed by a frame because it doesn't always update offsets correctly if I don't
        local comboPoint = ComboPointCounterDB.debugValue or UnitPower("player", Enum.PowerType.ComboPoints) or 0

        text:SetText("") -- More offset weirdness, need this for some reason
        text:SetText(comboPoint)
        local xOffset = ComboPointCounterDB.textOffsets[comboPoint] or 0
        text:SetPoint("CENTER", frame, "CENTER", xOffset, 0)

        if comboPoint >= 5 then
            fill:SetColorTexture(0.75, 0.5, 0, 1)
        else
            fill:SetColorTexture(0, 0, 0, 0.6)
        end
    end)
end
CPC.UpdateCounter = UpdateCounter

local function UpdateVisibility()
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
    border:SetSize(size * 2, size * 2)

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

--========================================================--
-- Event Handling
--========================================================--
local function HandleEvent(self, event, unit, powerType)
    if event == "PLAYER_REGEN_DISABLED" or event == "PLAYER_REGEN_ENABLED" or event == "PLAYER_ENTERING_WORLD"
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
frame:SetScript("OnEvent", HandleEvent)

UpdateVisibility()
UpdateFontSize()
