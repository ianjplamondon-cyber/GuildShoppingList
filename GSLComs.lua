VC = LibStub("VersionCheck-1.0", true)

-- Broadcast your reagent data to the guild
local function BroadcastReagentData()
    local gslPlayer = GetGSLPlayer()
    local playerName = UnitName("player")
    if gslPlayer ~= playerName then
        print("|cffff0000[GSL]|r Only the GSL player can broadcast reagent data.")
        return
    end

    -- Prepare data for sync
    local lastReagentData = GuildShoppingList_GSLLastReagentData and GuildShoppingList_GSLLastReagentData[gslPlayer] or {}
    local savedItems = GuildShoppingList_SavedItems or {}
    local timestamp = time()

    -- Debug print: Show what is being broadcast
    GSLDebugPrint("Broadcasting items: " .. table.concat(savedItems, ", "))

    -- Serialize tables
    local function serializeTable(tbl)
        local parts = {}
        for k, v in pairs(tbl) do
            table.insert(parts, tostring(k) .. "=" .. tostring(v))
        end
        return table.concat(parts, ";")
    end

    local reagentDataStr = serializeTable(lastReagentData)
    local savedItemsStr = table.concat(savedItems, "||")
    local msg = "GSL_SYNC:" ..
        "reagents=" .. reagentDataStr ..
        "||items=" .. savedItemsStr ..
        "||timestamp=" .. tostring(timestamp) ..
        "||gslplayer=" .. gslPlayer

    -- Always use the classic API
    SendAddonMessage(GSL_COMM_PREFIX, msg, "GUILD", "")

    GuildShoppingList_GSLLastReagentTimestamp = GuildShoppingList_GSLLastReagentTimestamp or {}
    GuildShoppingList_GSLLastReagentTimestamp[gslPlayer] = timestamp
    print("|cff00ff00[GSL]|r GSL data (reagents and shopping list) shared to guild.")
end

-- Communication prefix for sharing
local GSL_COMM_PREFIX = "GSL_SHARE"

if RegisterAddonMessagePrefix then
    RegisterAddonMessagePrefix(GSL_COMM_PREFIX)
end


-- Automatically sync local data when bags change (item added/removed)
local bagSyncFrame = CreateFrame("Frame")
bagSyncFrame:RegisterEvent("BAG_UPDATE")
bagSyncFrame:SetScript("OnEvent", function(self, event, arg1)
    ScanAndSaveReagents()
    if GetGSLPlayer and GetGSLPlayer() == UnitName("player") then
        if CacheGSLPlayerBagCache then CacheGSLPlayerBagCache() end
    end
    if UpdateList then UpdateList() end
    if UpdateReagentList then UpdateReagentList() end
    if UpdateGSLReagentOverlay then UpdateGSLReagentOverlay() end
end)

local bankSyncFrame = CreateFrame("Frame")
bankSyncFrame:RegisterEvent("BANKFRAME_OPENED")
bankSyncFrame:RegisterEvent("BANKFRAME_CLOSED")
bankSyncFrame:SetScript("OnEvent", function(self, event)
    ScanAndSaveReagents()
    if event == "BANKFRAME_OPENED" and GetGSLPlayer and GetGSLPlayer() == UnitName("player") then
    -- Only scan bank when bank is open, not on load
    end
    if UpdateList then UpdateList() end
    if UpdateReagentList then UpdateReagentList() end
    if UpdateGSLReagentOverlay then UpdateGSLReagentOverlay() end
end)

-- Register comms on enable
function GSL:OnEnable()
    GSLDebugPrint("|cff00ff00[GSL]|r [DEBUG] GSL:OnEnable called. Registering AceComm callbacks.")
    self:RegisterComm("GSLShare")
    self:RegisterComm("GSLRequest")
    if self.RegisterMessage then
        self:RegisterMessage("OnCommReceived")
    end
end

-- RequestGSLData: Ask the guild for the latest GSL data
function GSL:RequestGSLData()
    GSLDebugPrint("|cff00ff00[GSL]|r [DEBUG] Sending Guild Sync request to guild. My timestamp: " .. tostring(GuildShoppingList_GSLDataSyncTimestamp))
    self:SendCommMessage("GSLRequest", tostring(GuildShoppingList_GSLDataSyncTimestamp or 0), "GUILD")
    print("|cff00ff00[GSL]|r Requested latest GuildShoppingList data from guild.")
end

-- OnCommReceived: Handle incoming data and requests
function GSL:OnCommReceived(prefix, message, distribution, sender)
    if prefix == "GSLShare" then
        GSLDebugPrint("|cff00ff00[GSL]|r [DEBUG] Received GSLShare from " .. (sender or "unknown") .. ". Message: " .. tostring(message))
        local success, syncData = self:Deserialize(message)
        if success and type(syncData) == "table" then
            GSLDebugPrint("[GSL DEBUG] Received syncData table:")
            for k, v in pairs(syncData) do
                GSLDebugPrint("  " .. tostring(k) .. " = " .. tostring(v))
            end
            GSLDebugPrint("[GSL DEBUG] GatherStartDate: " .. tostring(syncData.GatherStartDate))
            GSLDebugPrint("[GSL DEBUG] GatherEndDate: " .. tostring(syncData.GatherEndDate))
            local incomingTimestamp = tonumber(syncData.GuildShoppingList_GSLDataSyncTimestamp or 0)
            local localTimestamp = tonumber(GuildShoppingList_GSLDataSyncTimestamp or 0)
            GSLDebugPrint("|cff00ff00[GSL]|r [DEBUG] Incoming timestamp: " .. tostring(incomingTimestamp) .. ", Local timestamp: " .. tostring(localTimestamp))
            if incomingTimestamp > localTimestamp then
                GSLDebugPrint("|cff00ff00[GSL]|r [DEBUG] Updating local data from " .. (syncData.player or sender))
                GuildShoppingList_SavedItems = syncData.GuildShoppingList_SavedItems or {}
                GuildShoppingList_GSLBankCache = syncData.GuildShoppingList_GSLBankCache or {}
                print("[GSL DEBUG] GuildShoppingList_GSLBankCache updated by OnCommReceived (sync). Keys: " .. tostring(next(GuildShoppingList_GSLBankCache)))
                GSLDebugPrint("[GSL] OnCommReceived: GuildShoppingList_GSLBankCache=" .. (GuildShoppingList_GSLBankCache and tostring(#(GuildShoppingList_GSLBankCache)) or "nil"))
                for k,v in pairs(GuildShoppingList_GSLBankCache or {}) do GSLDebugPrint("[GSL] BankCache: " .. tostring(k) .. "=" .. tostring(v)) end
                GuildShoppingList_GSLPlayerCache = syncData.GuildShoppingList_GSLPlayerCache or {}
                GuildShoppingList_GSLDataSyncTimestamp = incomingTimestamp
                -- Sync date range to SV and cache for non-GSL players
                _G["GuildShoppingList_Config"] = _G["GuildShoppingList_Config"] or {}
                _G["GuildShoppingList_Config"].GatherStartDate = syncData.GatherStartDate or "YYYY-MM-DD"
                _G["GuildShoppingList_Config"].GatherEndDate = syncData.GatherEndDate or "YYYY-MM-DD"
                GuildShoppingList_GatherStartDate = syncData.GatherStartDate or "YYYY-MM-DD"
                GuildShoppingList_GatherEndDate = syncData.GatherEndDate or "YYYY-MM-DD"
                if UpdateGSLPlayerText then UpdateGSLPlayerText() end
                print("|cff00ff00[GSL]|r GuildShoppingList data updated from " .. (syncData.player or sender) .. ". |cffff0000Please /reload your UI to see the updated data.|r")
                if UpdateList then UpdateList() end
                if UpdateReagentList then UpdateReagentList() end
                if UpdateGSLReagentOverlay then UpdateGSLReagentOverlay() end
            else
                GSLDebugPrint("|cffffff00[GSL]|r [DEBUG] Received older or same data from " .. (syncData.player or sender) .. "; ignoring.")
            end
        else
            GSLDebugPrint("|cffff0000[GSL]|r [DEBUG] Failed to deserialize GSLShare message from " .. (sender or "unknown") .. ".")
        end
    elseif prefix == "GSLRequest" then
        GSLDebugPrint("|cff00ff00[GSL]|r [DEBUG] Received GSLRequest from " .. (sender or "unknown") .. ". Message: " .. tostring(message))
        local requesterTimestamp = tonumber(message or 0)
        local localTimestamp = tonumber(GuildShoppingList_GSLDataSyncTimestamp or 0)
        GSLDebugPrint("|cff00ff00[GSL]|r [DEBUG] Requester timestamp: " .. tostring(requesterTimestamp) .. ", Local timestamp: " .. tostring(localTimestamp))
        if localTimestamp > requesterTimestamp then
            print("|cff00ff00[GSL]|r [DEBUG] Sending updated data to " .. sender)
            -- Send data to the requester only
            local svTable = _G["GuildShoppingList_Config"] or {}
            local syncData = {
                player = UnitName("player"),
                GuildShoppingList_SavedItems = GuildShoppingList_SavedItems,
                GuildShoppingList_GSLBankCache = GuildShoppingList_GSLBankCache,
                GuildShoppingList_GSLPlayerCache = GuildShoppingList_GSLPlayerCache,
                GuildShoppingList_GSLDataSyncTimestamp = localTimestamp,
                GatherStartDate = svTable.GatherStartDate or "YYYY-MM-DD",
                GatherEndDate = svTable.GatherEndDate or "YYYY-MM-DD",
            }
            local serialized = self:Serialize(syncData)
            self:SendCommMessage("GSLShare", serialized, "WHISPER", sender)
            print("|cff00ff00[GSL]|r Sent GuildShoppingList data to " .. sender .. ".")
        else
            print("|cffffff00[GSL]|r [DEBUG] Local data is not newer than requester; not sending.")
        end
    end
end

-- Register comms when the addon is loaded
local gslCommInitFrame = CreateFrame("Frame")
gslCommInitFrame:RegisterEvent("ADDON_LOADED")
gslCommInitFrame:SetScript("OnEvent", function(self, event, arg1)
    if arg1 == addonName then
        if GSL.OnEnable then GSL:OnEnable() end
    end
end)

-- VersionCheck-1.0 integration
local VC = LibStub("VersionCheck-1.0")
VC:Enable(GSL) -- Pass your main addon object
GSL.Version = "1.0.0" -- Set your current addon version

