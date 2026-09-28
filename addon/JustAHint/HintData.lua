local _, NS = ...
local Data = {}
NS.HintData = Data

local function finite(value)
    return type(value) == "number" and value == value and value > -math.huge and value < math.huge
end
local function point(mapID, x, y, source)
    if NS.ID(mapID) and finite(x) and finite(y) and x >= 0 and x <= 1 and y >= 0 and y <= 1 then
        return { mapID = mapID, x = x, y = y, source = source }
    end
end
local function convert(pos)
    local ok, vector = NS.Call("CreateVector2D", pos.x, pos.y)
    if not ok then return nil end
    local converted, space, world = NS.Call("C_Map.GetWorldPosFromMapPos", pos.mapID, vector)
    if not converted or not finite(space) or not world or type(world.GetXY) ~= "function" then return nil end
    local x, y = world:GetXY()
    if not finite(x) or not finite(y) then return nil end
    return { x = x, y = y, space = space }
end

function Data.WorldPoint(pos)
    local ok,result=pcall(convert,pos)
    if ok then return result end
end

function Data.Distance(a, b)
    if not a or not b or a.space ~= b.space then return nil end
    local dx, dy = a.x - b.x, a.y - b.y
    local result = math.sqrt(dx * dx + dy * dy)
    return finite(result) and result or nil
end

function Data.CurrentMap()
    local ok, mapID = NS.Call("C_Map.GetBestMapForUnit", "player")
    if ok and NS.ID(mapID) then return mapID end
end

local function destination(id, mapID)
    local ok, nextMap, x, y = NS.Call("C_QuestLog.GetNextWaypoint", id)
    local result = ok and point(nextMap, x, y, "next-waypoint")
    if result then return result end
    ok, x, y = NS.Call("C_QuestLog.GetNextWaypointForMap", id, mapID)
    result = ok and point(mapID, x, y, "map-waypoint")
    if result then return result end
    local read, entries = NS.Call("C_QuestLog.GetQuestsOnMap", mapID)
    if not read or type(entries) ~= "table" then return nil end
    for _, entry in ipairs(entries) do
        if type(entry) == "table" and entry.questID == id then
            -- A map indicator can be an entrance/other map, not this outdoor step.
            if entry.isMapIndicatorQuest then return nil end
            local candidate = point(mapID, entry.x, entry.y, "native-map-point")
            if not candidate then return nil end
            if result and (result.x ~= candidate.x or result.y ~= candidate.y) then return nil end
            result = candidate
        end
    end
    return result
end

local function stage(id)
    local ok, complete = NS.Call("C_QuestLog.IsComplete", id)
    if not ok or type(complete) ~= "boolean" then return nil, "unavailable" end
    if complete then return "turn-in", nil, "turn-in" end
    local read, objectives = NS.Call("C_QuestLog.GetQuestObjectives", id)
    if not read or type(objectives) ~= "table" or #objectives == 0 then return nil, "unavailable" end
    local parts = {}
    for _, objective in ipairs(objectives) do
        if type(objective) ~= "table" or type(objective.type) ~= "string"
            or type(objective.text) ~= "string" or type(objective.finished) ~= "boolean"
            or not finite(objective.numRequired) or not finite(objective.numFulfilled) then return nil, "unavailable" end
        -- The tested Forever objectives use n/N text. Remove only this progress
        -- token, retaining the actual objective wording and other numbers.
        local token = tostring(objective.numFulfilled) .. "/" .. tostring(objective.numRequired)
        local first, last = objective.text:find(token, 1, true)
        local wording = objective.text
        if first then wording = wording:sub(1, first - 1) .. "<count>" .. wording:sub(last + 1) end
        local fields = { objective.type, tostring(objective.numRequired), tostring(objective.finished), wording }
        for _, field in ipairs(fields) do parts[#parts + 1] = #field .. ":" .. field end
    end
    return "objective|" .. table.concat(parts, "|"), nil, "objective"
end

local function snapshot(id)
    local ok, accepted = NS.Call("C_QuestLog.IsOnQuest", id)
    if ok and accepted == false then return nil, "removed" end
    if not ok or accepted ~= true then return nil, "unavailable" end
    -- Only an explicit negative cache reading establishes loading. A missing
    -- destination or missing cache API must not be labelled "still loading".
    local cacheOK, cached = NS.Call("HaveQuestData", id)
    if cacheOK and cached == false then return nil, "loading" end
    local identity, reason, phase = stage(id)
    if not identity then return nil, reason end
    local mapOK, mapID = NS.Call("C_Map.GetBestMapForUnit", "player")
    if not mapOK or not NS.ID(mapID) then return nil, "unavailable", identity end
    local got, player = NS.Call("C_Map.GetPlayerMapPosition", mapID, "player")
    if not got or not player or type(player.GetXY) ~= "function" then return nil, "unavailable", identity end
    local px, py = player:GetXY()
    local playerPoint = point(mapID, px, py)
    if not playerPoint then return nil, "unavailable", identity end
    local target = destination(id, mapID)
    if not target then return nil, "no-destination", identity end
    if target.mapID ~= mapID then return nil, "other-map", identity end
    local playerWorld, targetWorld = convert(playerPoint), convert(target)
    local distance = Data.Distance(playerWorld, targetWorld)
    if not distance then return nil, "unavailable", identity end
    return { stage = identity, phase = phase, mapID = mapID, player = playerWorld, target = targetWorld,
        destination = target, distance = distance, playerPoint = playerPoint }
end

function Data.Snapshot(id)
    -- Keep normalizers and arithmetic inside pcall for restricted/malformed data.
    local ok, result, reason, identity = pcall(snapshot, id)
    if not ok then return nil, "unavailable" end
    return result, reason, identity
end

function Data.Facing()
    local ok, rotated = NS.Call("C_CVar.GetCVar", "rotateMinimap")
    if not ok or (rotated ~= "0" and rotated ~= "1") then return nil end
    if rotated == "0" then return 0 end
    local read, facing = NS.Call("GetPlayerFacing")
    if read and finite(facing) then return facing end
end
