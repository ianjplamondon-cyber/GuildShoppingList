-- GSLCore.lua
-- Core logic for GuildShoppingList addon

addonName = ...
GSL = LibStub("AceAddon-3.0"):NewAddon("GuildShoppingList", "AceComm-3.0", "AceSerializer-3.0")


-- SavedVariables Initialization
GuildShoppingList_Config = GuildShoppingList_Config or {}
GuildShoppingList_SavedItems = GuildShoppingList_SavedItems or {}
GuildShoppingList_GSLBankCache = GuildShoppingList_GSLBankCache or {}
GuildShoppingList_GSLPlayerCache = GuildShoppingList_GSLPlayerCache or {}
GuildShoppingList_GSLDataSyncTimestamp = GuildShoppingList_GSLDataSyncTimestamp or nil
GuildShoppingList_ReagentData = GuildShoppingList_ReagentData or {}

function GSL:OnInitialize()
    GSLDebugPrint("|cff00ff00[GSL]|r [DEBUG] GSL:OnInitialize called.")
    GuildShoppingList_SavedItems = GuildShoppingList_SavedItems or {}
    items = GuildShoppingList_SavedItems
    VC = LibStub("VersionCheck-1.0", true)
    GuildShoppingList_ReagentData = GuildShoppingList_ReagentData or {}
    -- Do NOT overwrite GuildShoppingList_GSLBankCache on reload or initialization

    -- Ensure VC debug flag is enforced from SV for all characters
    GuildShoppingList_Config = GuildShoppingList_Config or {}
    if GuildShoppingList_Config.VCDebugEnabled == nil then
        GuildShoppingList_Config.VCDebugEnabled = false
    end
    _G.VC_DebugEnabled = GuildShoppingList_Config.VCDebugEnabled or false
    GSLDebugPrint("[GSL] SV cache loaded at OnInitialize, keys: " .. tostring(next(GuildShoppingList_GSLBankCache)))
end


-- Recipe Data Loading
professionList = { "Alchemy", "Blacksmithing", "Enchanting", "Engineering", "Leatherworking", "Tailoring", "Cooking" }

-- Debug Print
function GSLDebugPrint(msg)
    if GuildShoppingList_Config.DebugEnabled then
        print(msg)
    end
end

-- Utility Functions
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

-- Item Counting
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

-- Data Serialization
function serializeTable(tbl)
    local parts = {}
    for k, v in pairs(tbl) do
        table.insert(parts, tostring(k) .. "=" .. tostring(v))
    end
    return table.concat(parts, ";")
end

function deserializeTable(str)
    local tbl = {}
    for pair in string.gmatch(str or "", "([^;]+)") do
        local k, v = string.match(pair, "^(.-)=(.+)$")
        if k and v then
            tbl[k] = tonumber(v) or v
        end
    end
    return tbl
end

-- Communication Prefix
local GSL_COMM_PREFIX = "GSL_SHARE"
if RegisterAddonMessagePrefix then
    RegisterAddonMessagePrefix(GSL_COMM_PREFIX)
end

-- Sync Logic
function GSL:ShareShoppingList()
    GuildShoppingList_GSLDataSyncTimestamp = GuildShoppingList_GSLDataSyncTimestamp or time()
    local syncData = {
        player = UnitName("player"),
        GuildShoppingList_SavedItems = GuildShoppingList_SavedItems,
        GuildShoppingList_GSLBankCache = GuildShoppingList_GSLBankCache,
        GuildShoppingList_GSLPlayerCache = GuildShoppingList_GSLPlayerCache,
        GuildShoppingList_GSLDataSyncTimestamp = GuildShoppingList_GSLDataSyncTimestamp,
    }
    local serialized = self:Serialize(syncData)
    self:SendCommMessage("GSLShare", serialized, "GUILD")
    print("|cff00ff00[GSL]|r Shared GuildShoppingList data to guild. Timestamp: " .. tostring(GuildShoppingList_GSLDataSyncTimestamp))
end

function GSL:OnEnable()
    GSLDebugPrint("|cff00ff00[GSL]|r [DEBUG] GSL:OnEnable called. Registering AceComm callbacks.")
    self:RegisterComm("GSLShare")
    self:RegisterComm("GSLRequest")
    if LibStub and LibStub("VersionCheck-1.0", true) then
        local VC = LibStub("VersionCheck-1.0")
        if VC and VC.Enable then
            VC:Enable(GSL)
            print("[GSL] Called VC:Enable(GSL)")
        end
    end
end

-- Populate RecipeData from global recipe tables after all recipe files are loaded
RecipeData = RecipeData or {}
RecipeData["Alchemy"] = GuildShoppingList_AlchemyRecipes or {}
RecipeData["Blacksmithing"] = GuildShoppingList_BlacksmithingPlans or {}
RecipeData["Engineering"] = GuildShoppingList_EngineeringSchematics or {}
RecipeData["Leatherworking"] = GuildShoppingList_LeatherworkingPatterns or {}
RecipeData["Tailoring"] = GuildShoppingList_TailoringPatterns or {}
RecipeData["Cooking"] = GuildShoppingList_CookingRecipes or {}
RecipeData["Enchanting"] = GuildShoppingList_EnchantingFormulae or {}

return GSL
