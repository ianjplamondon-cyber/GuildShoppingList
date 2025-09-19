-- GSLUtilities.lua
-- Utility functions and slash command handlers for GuildShoppingList

-- Debug Print
function GSLDebugPrint(msg)
    if GuildShoppingList_Config and GuildShoppingList_Config.DebugEnabled then
        print(msg)
    end
end

-- Utility: Find the designated GSL player in the guild
function GetGSLPlayer()
    local function TruncateRealm(name)
        return name and name:match("^[^%-]+") or name
    end
    if GuildShoppingList_ForcedGSLPlayer and GuildShoppingList_ForcedGSLPlayer ~= "" then
        return TruncateRealm(GuildShoppingList_ForcedGSLPlayer)
    end
    return TruncateRealm(cachedGSLPlayer)
end

function PrintCurrentGSLPlayer()
    local gslPlayer = GetGSLPlayer and GetGSLPlayer() or "unknown"
    GSLDebugPrint("|cff00ff00[GSL]|r Current GSL player: |cffffff00" .. gslPlayer .. "|r")
end

-- Utility: Scan the GSL player's bags and bank and update caches
function CacheGSLPlayerBagCache()
    local playerName = UnitName("player")
    if GetGSLPlayer() == playerName then
        local bagCache = {}
        for bag = 0, 4 do
            for slot = 1, C_Container.GetContainerNumSlots(bag) do
                local itemLink = C_Container.GetContainerItemLink(bag, slot)
                if itemLink then
                    local name = GetItemInfo(itemLink)
                    local info = C_Container.GetContainerItemInfo(bag, slot)
                    local itemCount = info and info.stackCount or 0
                    if name then
                        bagCache[name] = (bagCache[name] or 0) + itemCount
                    end
                end
            end
        end
        GuildShoppingList_GSLPlayerCache = bagCache
    end
end


-- Call CacheGSLPlayerInventory on login/reload for the GSL player
local initFrameGSLPlayerCache = CreateFrame("Frame")
initFrameGSLPlayerCache:RegisterEvent("ADDON_LOADED")
initFrameGSLPlayerCache:SetScript("OnEvent", function(self, event, arg1)
    if arg1 == addonName then
        if GetGSLPlayer and GetGSLPlayer() == UnitName("player") then
            CacheGSLPlayerInventory()
        end
    end
end)


-- Function to cache the current inventory for the GSL player
local function CacheGSLPlayerInventory()
    local playerName = UnitName("player")
    if GetGSLPlayer and GetGSLPlayer() == playerName then
        local inventory = {}
        for bag = 0, 4 do
            for slot = 1, C_Container.GetContainerNumSlots(bag) do
                local itemLink = C_Container.GetContainerItemLink(bag, slot)
                if itemLink then
                    local name = GetItemInfo(itemLink)
                    local info = C_Container.GetContainerItemInfo(bag, slot)
                    local itemCount = info and info.stackCount or 0
                    if name then
                        inventory[name] = (inventory[name] or 0) + itemCount
                    end
                end
            end
        end
        GuildShoppingList_GSLPlayerCache = inventory
        -- print("|cff00ff00[GSL]|r GSLPlayerCache updated for GSL player: " .. playerName)
    end
end


-- Utility: Scan your own reagents and save to SavedVariables
function ScanAndSaveReagents()
    local reagentCounts = {}
    local reagentTotals = {}
    for _, item in ipairs(items) do
        local recipeName, count = item:match("^(.-) x(%d+)$")
        count = tonumber(count) or 1
        for prof, recipes in pairs(RecipeData) do
            if recipes[recipeName] then
                for _, reagent in ipairs(recipes[recipeName].reagents or {}) do
                    if reagent.name then
                        reagentTotals[reagent.name] = (reagentTotals[reagent.name] or 0) + (reagent.count or 1) * count
                    end
                end
            end
        end
    end
    for reagentName in pairs(reagentTotals) do
        reagentCounts[reagentName] = GetTotalItemCount(reagentName)
    end
    local playerName = UnitName("player")
    GuildShoppingList_ReagentData[playerName] = reagentCounts
end


-- Utility: Get total count of an item in bags and bank
function GetTotalItemCount(itemName)
    local total = 0
    local playerName = UnitName("player")
    -- Bags (0-4)
    for bag = 0, 4 do
        for slot = 1, C_Container.GetContainerNumSlots(bag) do
            local itemLink = C_Container.GetContainerItemLink(bag, slot)
            if itemLink then
                local name = GetItemInfo(itemLink)
                if name == itemName then
                    local info = C_Container.GetContainerItemInfo(bag, slot)
                    local itemCount = info and info.stackCount or 0
                    total = total + itemCount
                end
            end
        end
    end
    -- Bank: live scan if open, otherwise use cache
    if BankFrame and BankFrame:IsShown() then
        -- Main bank slots (bank bag -1)
        for slot = 1, C_Container.GetContainerNumSlots(-1) do
            local itemLink = C_Container.GetContainerItemLink(-1, slot)
            if itemLink then
                local name = GetItemInfo(itemLink)
                if name == itemName then
                    local info = C_Container.GetContainerItemInfo(-1, slot)
                    local itemCount = info and info.stackCount or 0
                    total = total + itemCount
                end
            end
        end
        -- Bank bags (5-11)
        for bag = 5, 11 do
            for slot = 1, C_Container.GetContainerNumSlots(bag) do
                local itemLink = C_Container.GetContainerItemLink(bag, slot)
                if itemLink then
                    local name = GetItemInfo(itemLink)
                    if name == itemName then
                        local info = C_Container.GetContainerItemInfo(bag, slot)
                        local itemCount = info and info.stackCount or 0
                        total = total + itemCount
                    end
                end
            end
        end
    elseif GuildShoppingList_BankCache and GuildShoppingList_BankCache[playerName] and GuildShoppingList_BankCache[playerName][itemName] then
        total = total + GuildShoppingList_BankCache[playerName][itemName]
    end
    return total
end



-- Slash command to toggle debug
SLASH_GSLDEBUG1 = "/gsldebug"
SlashCmdList["GSLDEBUG"] = function(arg)
    arg = arg and arg:lower()
    if arg == "on" then
        GuildShoppingList_Config.DebugEnabled = true
        print("|cff00ff00[GSL]|r Debugging enabled.")
    elseif arg == "off" then
        GuildShoppingList_Config.DebugEnabled = false
        print("|cffff0000[GSL]|r Debugging disabled.")
    else
        print("|cff00ff00[GSL]|r Debugging is currently " .. (GuildShoppingList_Config.DebugEnabled and "|cffffff00ON|r" or "|cffff0000OFF|r"))
        print("|cffffff00Usage: /gsldebug on|off|r")
    end
end

-- Help command
SLASH_GSLHELP1 = "/gslhelp"
SlashCmdList["GSLHELP"] = function()
    print("|cff00ff00GuildShoppingList Commands:|r")
    print("|cffffff00/gsldebug on|off|r - Enable or disable debug output")
    print("|cffffff00/gslvcheck|r - Send a version check to the guild")
    print("|cffffff00/gslhelp|r - Show this help message")
    -- Add more commands here as needed
end

-- Slash command for /gslshare (AceComm-based sync)
SLASH_GSLSHARE1 = "/gslshare"
SlashCmdList["GSLSHARE"] = function()
    GSL:ShareShoppingList()
end

SLASH_GSLCLEAR1 = "/gslclear"
SlashCmdList["GSLCLEAR"] = function()
    GuildShoppingList_SavedItems = {}
    GuildShoppingList_BankCache = {}
    GuildShoppingList_GSLBankCache = {}
    print("[GSL DEBUG] GuildShoppingList_GSLBankCache wiped by /gslclear command.")
    GuildShoppingList_GSLPlayerCache = {}
    GuildShoppingList_GSLDataSyncTimestamp = nil
    print("|cffff0000[GSL]|r All GuildShoppingList data has been cleared. |cffff0000Please /reload your UI to fully reset.|r")
    if UpdateList then UpdateList() end
    if UpdateReagentList then UpdateReagentList() end
end

SLASH_GSLHELP1 = "/gslhelp"
SlashCmdList["GSLHELP"] = function()
    print("|cff00ff00GuildShoppingList Commands:|r")
    print("|cffffff00/gsl|r - Toggle the main Guild Shopping List window.")
    print("|cffffff00/gsl share|r - Save your current reagent data for offline viewing (does not broadcast).")
    print("|cffffff00/gsl who|r - Print the current GSL player for your guild.")
    print("|cffffff00/gslreagents|r - Toggle the GSL Reagent Tracker overlay window.")
    print("|cffffff00/gslshare|r - Broadcast your Guild Shopping List data to the guild (GSL player only).")
    print("|cffffff00/gslrequest|r - Request the latest Guild Shopping List data from the guild (non-GSL players).")
    print("|cffffff00/gslclear|r - Clear all Guild Shopping List data (irreversible, use with caution).")
    print("|cffffff00/gslhelp|r - Show this help message.")
end


-- Slash command to show/hide
SLASH_GUILDSHOPPINGLIST1 = "/gsl"
SlashCmdList["GUILDSHOPPINGLIST"] = function(msg)
    msg = msg and msg:lower() or ""
    if msg == "share" then
        -- Only update local data, do not broadcast
        ScanAndSaveReagents()
        print("|cff00ff00[GSL]|r Data saved for offline viewing.")
    elseif msg == "who" then
        PrintCurrentGSLPlayer()
    else
        if frame:IsShown() then
            frame:Hide()
        else
            frame:Show()
        end
    end
end

-- Slash command to show/hide the overlay
SLASH_GSLREAGENTS1 = "/gslreagents"
SlashCmdList["GSLREAGENTS"] = function()
    if GSLReagentOverlayFrame:IsShown() then
        GSLReagentOverlayFrame:Hide()
    else
        UpdateGSLReagentOverlay()
        GSLReagentOverlayFrame:Show()
    end
end

-- Slash command to trigger version check
SLASH_GSLVCHECK1 = "/gslvcheck"
SlashCmdList["GSLVCHECK"] = function()
    VC:TriggerVersionCheck()
    print("|cff00ff00[GSL]|r Version check sent to guild.")
end

return {
    GSLDebugPrint = GSLDebugPrint,
    GetGSLPlayer = GetGSLPlayer,
    PrintCurrentGSLPlayer = PrintCurrentGSLPlayer
}
