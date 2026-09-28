local _, NS = ...
local Adapter = {}
NS.Adapter = Adapter

function Adapter.QuestPOI()
    local ok, value = NS.Call("C_CVar.GetCVar", "questPOI")
    if not ok or (value ~= "0" and value ~= "1") then return nil, "Cannot read map objective setting." end
    return value
end

function Adapter.SetQuestPOI(value)
    local ok, result = NS.Call("C_CVar.SetCVar", "questPOI", value)
    if not ok or result == false or Adapter.QuestPOI() ~= value then
        return false, "Map objective setting did not change."
    end
    return true
end

-- Resolve the semantic filter each time; indexes can change with spells.
-- Never toggle other filters, clear all tracking, or match localized labels.
function Adapter.QuestTracking()
    local filterID = NS.Resolve("Enum.MinimapTrackingFilter.QuestPOIs")
    if type(filterID) ~= "number" then return nil, "Minimap quest filter is unavailable." end
    local ok, count = NS.Call("C_Minimap.GetNumTrackingTypes")
    if not ok or type(count) ~= "number" or count < 0 or count > 1000 or count % 1 ~= 0 then
        return nil, "Cannot read minimap filters."
    end
    for index = 1, count do
        local read, filter = NS.Call("C_Minimap.GetTrackingFilter", index)
        if read and type(filter) == "table" and filter.filterID == filterID then
            local infoOK, info = NS.Call("C_Minimap.GetTrackingInfo", index)
            if infoOK and type(info) == "table" and type(info.active) == "boolean" then
                return { index = index, active = info.active }
            end
        end
    end
    return nil, "Cannot identify the minimap quest filter on this client."
end

function Adapter.SetQuestTracking(value)
    local info, err = Adapter.QuestTracking()
    if not info then return false, err end
    if info.active == value then return true end
    local ok = NS.Call("C_Minimap.SetTracking", info.index, value)
    local after = Adapter.QuestTracking()
    if not ok or not after or after.active ~= value then return false, "Minimap quest filter did not change." end
    return true
end

function Adapter.ClearQuestNavigation()
    local ok, id = NS.Call("C_SuperTrack.GetSuperTrackedQuestID")
    if not ok then return false, "Cannot read quest navigation." end
    if id == nil or id == 0 then return true end
    if not NS.ID(id) then return false, "Quest navigation returned an unexpected value." end
    local cleared = NS.Call("C_SuperTrack.SetSuperTrackedQuestID", 0)
    local read, after = NS.Call("C_SuperTrack.GetSuperTrackedQuestID")
    if not cleared or not read or (after ~= nil and after ~= 0) then
        return false, "Quest navigation could not be cleared."
    end
    return true
end

function Adapter.PlayerKey()
    local ok, guid = NS.Call("UnitGUID", "player")
    if ok and type(guid) == "string" and guid ~= "" then return guid end
end
