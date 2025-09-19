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
    AceComm:RegisterComm(self.PREFIX, function(prefix, message, distribution, sender)
        VC:OnCommReceived(prefix, message, distribution, sender)
    end)
function VC:TriggerVersionCheck()
    local myVersion = (VC.hostAddon and VC.hostAddon.Version) or "unknown"
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
    AceComm:SendCommMessage(VC.PREFIX, serialized, "GUILD")
end


function VC:OnCommReceived(prefix, message, distribution, sender)
    if prefix == VC.PREFIX then
        local success, version = AceSerializer:Deserialize(message)
        if success then
            local myVersion = (VC.hostAddon and VC.hostAddon.Version) or "unknown"
            local response = AceSerializer:Serialize(myVersion)
            AceComm:SendCommMessage(VC.RESPONSE_PREFIX, response, "WHISPER", sender)
        end
    elseif prefix == VC.RESPONSE_PREFIX then
        local success, version = AceSerializer:Deserialize(message)
        if success then
            print("[VersionCheck] " .. sender .. " is using version: " .. tostring(version))
        end
    end
end
