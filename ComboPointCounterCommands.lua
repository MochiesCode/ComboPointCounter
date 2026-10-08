local addonName, CPC = ...

-- Main file bails out for unsupported classes before creating the frame
if not CPC.frame then return end

local function Tokenize(msg)
    local t = {}
    for w in msg:gmatch("%S+") do
        t[#t + 1] = w
    end
    return t
end

local Commands = {}

local function OpenOptionsPanel()
    Settings.OpenToCategory(CPC.OptionsCategory:GetID())
end

-- Only listens for combat ending while an open is waiting
local openFrame = CreateFrame("Frame")
openFrame:SetScript("OnEvent", function(self)
    self:UnregisterEvent("PLAYER_REGEN_ENABLED")
    OpenOptionsPanel()
end)

Commands.options = function()
    if not InCombatLockdown() then
        OpenOptionsPanel()
        return
    end

    openFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
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

Commands.threshold = function(args)
    local t = tonumber(args[1])
    if t then
        CPC.SetFinisherThreshold(t)
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
