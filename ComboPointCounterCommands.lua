-- Only load if player is a rogue
local _, class = UnitClass("player")
if class ~= "ROGUE" then return end

local addonName, CPC = ...

local function Tokenize(msg)
    local t = {}
    for w in msg:gmatch("%S+") do
        t[#t + 1] = w
    end
    return t
end

local Commands = {}

local function OpenOptionsPanel()
    if InCombatLockdown and InCombatLockdown() then
        return false
    end

    if Settings and Settings.OpenToCategory and CPC.OptionsCategory and CPC.OptionsCategory.GetID then
        Settings.OpenToCategory(CPC.OptionsCategory:GetID())
        return true
    end

    if InterfaceOptionsFrame_OpenToCategory and CPC.OptionsPanel then
        InterfaceOptionsFrame_OpenToCategory(CPC.OptionsPanel)
        InterfaceOptionsFrame_OpenToCategory(CPC.OptionsPanel)
        return true
    end

    return false
end

local pendingOpen = false
local openFrame = CreateFrame("Frame")
openFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
openFrame:SetScript("OnEvent", function()
    if pendingOpen then
        pendingOpen = false
        OpenOptionsPanel()
    end
end)

Commands.options = function()
    if OpenOptionsPanel() then
        return
    end

    pendingOpen = true
    print("Combo Point Counter: options can't open in combat. They will open when combat ends.")
end

Commands.show = function()
    CPC.SetAlwaysShow(true)
end

Commands.combat = function()
    CPC.SetAlwaysShow(false)
end

Commands.pos = function(args)
    local x, y = tonumber(args[1]), tonumber(args[2])
    if x and y then
        CPC.SetFramePosition(x, y)
    end
end

Commands.size = function(args)
    local s = tonumber(args[1])
    if s then
        CPC.SetFrameSize(s)
    end
end

Commands.offset = function(args)
    local i, v = tonumber(args[1]), tonumber(args[2])
    if i and v then
        CPC.SetTextOffset(i, v)
    end
end

Commands.debug = function(args)
    if args[1] == "off" then
        CPC.SetDebugValue(nil)
    else
        CPC.SetDebugValue(tonumber(args[1]))
    end
end

SLASH_COMBOPOINTCOUNTER1 = "/cpc"
SlashCmdList.COMBOPOINTCOUNTER = function(msg)
    local args = Tokenize(msg:lower())
    local cmd = table.remove(args, 1)
    if Commands[cmd] then
        Commands[cmd](args)
    end
end
