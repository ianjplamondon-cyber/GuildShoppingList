-- Slash command registration for debugging (must be top-level)
SLASH_VCD1 = "/vcd"
SLASH_VCDON1 = "/vcdon"
SLASH_VCDOFF1 = "/vcdoff"

SlashCmdList["VCD"] = function()
    VC_DebugEnabled = not VC_DebugEnabled
    GuildShoppingList_Config = GuildShoppingList_Config or {}
    GuildShoppingList_Config.VCDebugEnabled = VC_DebugEnabled
    print("[VersionCheck] Debugging " .. (VC_DebugEnabled and "enabled" or "disabled"))
end
SlashCmdList["VCDON"] = function()
    VC_DebugEnabled = true
    GuildShoppingList_Config = GuildShoppingList_Config or {}
    GuildShoppingList_Config.VCDebugEnabled = true
    print("[VersionCheck] Debugging enabled")
end
SlashCmdList["VCDOFF"] = function()
    VC_DebugEnabled = false
    GuildShoppingList_Config = GuildShoppingList_Config or {}
    GuildShoppingList_Config.VCDebugEnabled = false
    print("[VersionCheck] Debugging disabled")
end

local function VCPrint(msg)
    if _G.VC_DebugEnabled then
        print("[VersionCheck] " .. tostring(msg))
    end
end
-- VersionCheck-1.0.lua
-- Standalone library for WoW Classic addon version checking via AceComm-3.0
-- Usage: local VC = LibStub("VersionCheck-1.0")

local MAJOR, MINOR = "VersionCheck-1.0", 2
local VC, oldminor = LibStub:NewLibrary(MAJOR, MINOR)
if not VC then return end

VC.PREFIX = "VCHECK"
VC.RESPONSE_PREFIX = "VCRESP"

-- AceComm-3.0 integration

local AceComm = LibStub("AceComm-3.0")
local AceSerializer = LibStub("AceSerializer-3.0")


-- Host addon must call this once after loading
function VC:Enable(hostAddon)
    self.hostAddon = hostAddon
    local hostName = "unknown"
    if hostAddon and hostAddon.GetName then
        hostName = hostAddon:GetName()
    end
    VCPrint("Enable called for hostAddon: " .. tostring(hostName))
    AceComm:RegisterComm(self.PREFIX, function(prefix, message, distribution, sender)
        VCPrint("Received message on prefix: " .. tostring(prefix) .. " from " .. tostring(sender))
        VC:OnCommReceived(prefix, message, distribution, sender)
    end)
function VC:TriggerVersionCheck()
    local myVersion = (VC.hostAddon and VC.hostAddon.Version) or "unknown"
    VCPrint("TriggerVersionCheck called. My version: " .. tostring(myVersion))
    VC:SendVersionCheck(myVersion)
end
end

function VC:CompareVersion(ver1, ver2)
    local function split(v)
        local t = {}
        for s in string.gmatch(v, "[0-9]+") do table.insert(t, tonumber(s)) end
        return t
    end
    local v1, v2 = split(ver1), split(ver2)
    for i = 1, math.max(#v1, #v2) do
        local a, b = v1[i] or 0, v2[i] or 0
        if a < b then return -1 elseif a > b then return 1 end
    end
    return 0
end


function VC:SendVersionCheck(version)
    local serialized = AceSerializer:Serialize(version)
    VCPrint("Sending version check to GUILD. Version: " .. tostring(version))
    AceComm:SendCommMessage(VC.PREFIX, serialized, "GUILD")
end


function VC:OnCommReceived(prefix, message, distribution, sender)
    if prefix == VC.PREFIX then
        VCPrint("OnCommReceived: VCHECK from " .. tostring(sender) .. " via " .. tostring(distribution))
        local success, version = AceSerializer:Deserialize(message)
        if success then
            VCPrint("Deserialized version from " .. tostring(sender) .. ": " .. tostring(version))
            local myVersion = (VC.hostAddon and VC.hostAddon.Version) or "unknown"
            local response = AceSerializer:Serialize(myVersion)
            local recipient = sender
            if not recipient:find("-") then
                recipient = recipient .. "-" .. GetRealmName()
            end
            VCPrint("Sending VCRESP to recipient: '" .. tostring(recipient) .. "' with version " .. tostring(myVersion))
            AceComm:SendCommMessage(VC.RESPONSE_PREFIX, response, "WHISPER", recipient)
        else
            VCPrint("Failed to deserialize version from " .. tostring(sender))
        end
    elseif prefix == VC.RESPONSE_PREFIX then
        VCPrint("OnCommReceived: VCRESP from " .. tostring(sender) .. " via " .. tostring(distribution))
        local success, version = AceSerializer:Deserialize(message)
        if success then
            VCPrint(sender .. " is using version: " .. tostring(version))
        else
            VCPrint("Failed to deserialize response from " .. tostring(sender))
        end
    end

-- Slash command registration for debugging (must be top-level)
SLASH_VCD1 = "/vcd"
SLASH_VCDON1 = "/vcdon"
SLASH_VCDOFF1 = "/vcdoff"

SlashCmdList["VCD"] = function()
    VC_DebugEnabled = not VC_DebugEnabled
    GuildShoppingList_Config = GuildShoppingList_Config or {}
    GuildShoppingList_Config.VCDebugEnabled = VC_DebugEnabled
    print("[VersionCheck] Debugging " .. (VC_DebugEnabled and "enabled" or "disabled"))
end
SlashCmdList["VCDON"] = function()
    VC_DebugEnabled = true
    GuildShoppingList_Config = GuildShoppingList_Config or {}
    GuildShoppingList_Config.VCDebugEnabled = true
    print("[VersionCheck] Debugging enabled")
end
SlashCmdList["VCDOFF"] = function()
    VC_DebugEnabled = false
    GuildShoppingList_Config = GuildShoppingList_Config or {}
    GuildShoppingList_Config.VCDebugEnabled = false
    print("[VersionCheck] Debugging disabled")
end
end
