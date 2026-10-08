local addonName, CPC = ...

-- Main file bails out for unsupported classes before creating the frame
if not CPC.frame then return end

local function OpenOptionsPanel()
    Settings.OpenToCategory(CPC.OptionsCategory:GetID())
end

-- Only listens for combat ending while an open is waiting
local openFrame = CreateFrame("Frame")
openFrame:SetScript("OnEvent", function(self)
    self:UnregisterEvent("PLAYER_REGEN_ENABLED")
    OpenOptionsPanel()
end)

SLASH_COMBOPOINTCOUNTER1 = "/cpc"
SlashCmdList.COMBOPOINTCOUNTER = function()
    if not InCombatLockdown() then
        OpenOptionsPanel()
        return
    end

    openFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
    print("Combo Point Counter: options can't open in combat. They will open when combat ends.")
end
