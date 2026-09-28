local _, NS = ...
local A = {}
NS.Adapter = A

local function positiveID(value)
    if value == nil then return "no-data" end
    if not NS.ID(value) then return "invalid-data" end
    return "ok", value
end

local function boolean(value)
    if value == nil then return "no-data" end
    if type(value) ~= "boolean" then return "invalid-data" end
    return "ok", value
end

local function vector(value)
    if value == nil then return "no-data" end
    if type(value.GetXY) ~= "function" then return "invalid-data" end
    local x, y = value:GetXY()
    if not NS.Number(x) or not NS.Number(y) then return "invalid-data" end
    return "ok", { x = x, y = y }
end

local function position(value)
    local status, result = vector(value)
    if status ~= "ok" then return status end
    if result.x < 0 or result.x > 1 or result.y < 0 or result.y > 1 then
        return "invalid-data"
    end
    return status, result
end

local function worldPosition(continentID, value)
    if continentID == nil and value == nil then return "no-data" end
    -- This is an opaque coordinate-space identifier, not a positive UI map ID.
    -- Preserve zero rather than discarding a potentially valid conversion.
    if not NS.Number(continentID) then return "invalid-data" end
    local status, result = vector(value)
    if status ~= "ok" then return "invalid-data" end
    result.continentID = continentID
    return "ok", result
end

function A.Build()
    return NS.Read("GetBuildInfo", function(version, build, buildDate, interface)
        if version == nil then return "no-data" end
        if type(version) ~= "string" or type(build) ~= "string"
            or type(buildDate) ~= "string" or not NS.ID(interface) then
            return "invalid-data"
        end
        return "ok", { version = version, build = build, buildDate = buildDate,
            interface = interface, projectID = WOW_PROJECT_ID }
    end)
end

function A.Capabilities()
    local result = {}
    -- Every name here comes from the documented modern API or its UI source.
    -- This is a presence check, never a Forever compatibility claim.
    for _, path in ipairs({
        "GetBuildInfo", "HaveQuestData", "CreateVector2D",
        "C_QuestLog.GetNumQuestLogEntries", "C_QuestLog.GetInfo",
        "C_QuestLog.IsOnQuest", "C_QuestLog.GetQuestObjectives",
        "C_QuestLog.GetNextWaypoint", "C_QuestLog.IsComplete",
        "C_QuestLog.GetQuestsOnMap", "C_QuestLog.GetNextWaypointForMap",
        "C_Map.GetBestMapForUnit", "C_Map.GetPlayerMapPosition",
        "C_Map.GetWorldPosFromMapPos", "C_CVar.GetCVar",
        "C_SuperTrack.GetSuperTrackedQuestID",
    }) do result[path] = type(NS.Resolve(path)) == "function" end
    return result
end

function A.Context(phase, category, note)
    return {
        guidanceLabel = phase,
        questCategory = category,
        testerNote = note or "",
        questPOI = NS.Read("C_CVar.GetCVar", NS.Scalar, "questPOI"),
        superTrackedQuestID = NS.Read("C_SuperTrack.GetSuperTrackedQuestID", NS.Scalar),
        guidanceFullyDisabled = "not-established-by-these-readings",
        mapIsolation = NS.Isolation and NS.Isolation.Snapshot() or { status = "inactive" },
    }
end

function A.Accepted(questID)
    return NS.Read("C_QuestLog.IsOnQuest", boolean, questID)
end

-- Read only the frames/getters named in Blizzard's quest-pane source. Their
-- presence here must be measured in Forever, not inferred from another client.
local function uiRead(source, read)
    local ok, status, value = pcall(read)
    if not ok then return { source = source, status = "error", detail = tostring(status) } end
    return { source = source, status = status, value = value }
end

local function stringValue(value)
    if value == nil then return "no-data" end
    if type(value) ~= "string" then return "invalid-data" end
    return "ok", value
end

local function numberValue(value)
    if value == nil then return "no-data" end
    if not NS.Number(value) then return "invalid-data" end
    return "ok", value
end

local function rectangle(left, bottom, width, height)
    if left == nil and bottom == nil and width == nil and height == nil then return "no-data" end
    if not NS.Number(left) or not NS.Number(bottom) or not NS.Number(width) or not NS.Number(height)
        or width < 0 or height < 0 then return "invalid-data" end
    return "ok", { left = left, bottom = bottom, width = width, height = height }
end

local function uiMethod(path, name, normalize)
    return uiRead(path .. ":" .. name, function()
        local frame = NS.Resolve(path)
        if frame == nil then return "missing-frame" end
        if type(frame[name]) ~= "function" then return "missing-api" end
        return normalize(frame[name](frame))
    end)
end

local function inspectFrame(path)
    local result = uiRead(path, function()
        local frame = NS.Resolve(path)
        if frame == nil then return "missing-frame" end
        if type(frame) ~= "table" and type(frame) ~= "userdata" then return "invalid-data" end
        return "present"
    end)
    if result.status ~= "present" then return result end
    result.name = uiMethod(path, "GetName", stringValue)
    result.objectType = uiMethod(path, "GetObjectType", stringValue)
    result.shown = uiMethod(path, "IsShown", boolean)
    result.visible = uiMethod(path, "IsVisible", boolean)
    result.protected = uiMethod(path, "IsProtected", boolean)
    result.rect = uiMethod(path, "GetRect", rectangle)
    result.scale = uiMethod(path, "GetEffectiveScale", numberValue)
    result.parentName = uiMethod(path, "GetParent", function(parent)
        if parent == nil then return "no-data" end
        if type(parent.GetName) ~= "function" then return "missing-api" end
        return stringValue(parent:GetName())
    end)
    return result
end

local function selectedID(value)
    if value == 0 then return "no-data" end
    return positiveID(value)
end

function A.NativeUI()
    local result = { status = "captured", scope = "read-only-native-ui-inspection",
        nativeIntegrationVerified = false, frames = {}, capabilities = {},
        context = A.Context("observed", "native-ui"),
        displayedMap = uiMethod("WorldMapFrame", "GetMapID", positiveID),
        playerMap = NS.Read("C_Map.GetBestMapForUnit", positiveID, "player"),
        focusedQuest = NS.Read("QuestMapFrame_GetFocusedQuestID", selectedID),
        selectedQuest = NS.Read("C_QuestLog.GetSelectedQuest", selectedID),
        detailsQuest = uiRead("QuestMapFrame.DetailsFrame.questID", function()
            if not NS.Resolve("QuestMapFrame.DetailsFrame") then return "missing-frame" end
            return selectedID(NS.Resolve("QuestMapFrame.DetailsFrame.questID"))
        end),
    }
    for _, path in ipairs({ "QuestMapFrame_GetFocusedQuestID", "C_QuestLog.GetSelectedQuest",
        "QuestMapFrame_ShowQuestDetails", "QuestMapFrame_OpenToQuestDetails", "hooksecurefunc" }) do
        -- Mutating detail-opening functions are inspected for presence only.
        result.capabilities[path] = type(NS.Resolve(path)) == "function"
    end
    for _, path in ipairs({ "WorldMapFrame", "QuestMapFrame", "QuestMapFrame.QuestsFrame",
        "QuestMapFrame.DetailsFrame", "QuestMapFrame.QuestsFrame.DetailsFrame",
        "QuestMapFrame.DetailsFrame.ScrollFrame", "QuestMapFrame.DetailsFrame.RewardsFrameContainer",
        "QuestMapFrame.DetailsFrame.BackFrame", "QuestMapFrame.DetailsFrame.AbandonButton",
        "QuestMapFrame.DetailsFrame.ShareButton", "QuestMapFrame.DetailsFrame.TrackButton" }) do
        result.frames[#result.frames + 1] = inspectFrame(path)
    end
    return result
end

function A.Quests()
    local count = NS.Read("C_QuestLog.GetNumQuestLogEntries", function(value)
        if value == nil then return "no-data" end
        if not NS.Number(value) or value < 0 or value % 1 ~= 0 or value > 1000 then
            return "invalid-data"
        end
        return "ok", value
    end)
    if count.status ~= "ok" then return count end
    local entries = {}
    for index = 1, count.value do
        local entry = NS.Read("C_QuestLog.GetInfo", function(info)
            if info == nil then return "no-data" end
            if type(info) ~= "table" then return "invalid-data" end
            if info.isHeader then return "header" end
            if not NS.ID(info.questID) or type(info.title) ~= "string" then
                return "invalid-data"
            end
            return "ok", { questID = info.questID, title = info.title }
        end, index)
        -- Preserve gaps/errors rather than interpreting a partial list as complete.
        if entry.status ~= "header" then entries[#entries + 1] = entry end
    end
    return { source = "C_QuestLog.GetInfo", status = "ok", value = entries }
end

function A.Destination(questID)
    return NS.Read("C_QuestLog.GetNextWaypoint", function(mapID, x, y)
        if mapID == nil and x == nil and y == nil then return "no-data" end
        if not NS.ID(mapID) or not NS.Number(x) or not NS.Number(y)
            or x < 0 or x > 1 or y < 0 or y > 1 then return "invalid-data" end
        return "ok", { mapID = mapID, x = x, y = y }
    end, questID)
end

local function convert(mapID, pos)
    local create = NS.Resolve("CreateVector2D")
    if type(create) ~= "function" then
        return { source = "CreateVector2D", status = "missing-api" }
    end
    local ok, value = pcall(create, pos.x, pos.y)
    if not ok then return { source = "CreateVector2D", status = "error", detail = tostring(value) } end
    return NS.Read("C_Map.GetWorldPosFromMapPos", worldPosition, mapID, value)
end

local function distanceBetween(playerWorld, targetWorld)
    if not playerWorld or playerWorld.status ~= "ok" or not targetWorld or targetWorld.status ~= "ok" then
        return { status = "unavailable" }
    end
    local player, target = playerWorld.value, targetWorld.value
    if player.continentID ~= target.continentID then return { status = "different-continents" } end
    local dx, dy = target.x - player.x, target.y - player.y
    local distance = math.sqrt(dx * dx + dy * dy)
    return { status = NS.Number(distance) and "ok" or "invalid-data",
        worldUnits = NS.Number(distance) and distance or nil, unitVerification = "Forever-unverified" }
end

function A.Probe(questID, phase, category, note)
    local result = { questID = questID, context = A.Context(phase, category, note),
        accepted = A.Accepted(questID) }
    if result.accepted.status ~= "ok" or result.accepted.value ~= true then
        result.status = "accepted-quest-not-confirmed"
        return result
    end
    result.status = "captured"
    result.cache = NS.Read("HaveQuestData", boolean, questID)
    result.complete = NS.Read("C_QuestLog.IsComplete", boolean, questID)
    result.objectives = NS.Read("C_QuestLog.GetQuestObjectives", function(objectives)
        if objectives == nil then return "no-data" end
        if type(objectives) ~= "table" then return "invalid-data" end
        local normalized = {}
        for index, objective in ipairs(objectives) do
            if type(objective) ~= "table" or type(objective.text) ~= "string"
                or type(objective.type) ~= "string" or type(objective.finished) ~= "boolean"
                or not NS.Number(objective.numFulfilled) or not NS.Number(objective.numRequired) then
                return "invalid-data"
            end
            normalized[index] = { text = objective.text, type = objective.type,
                finished = objective.finished, numFulfilled = objective.numFulfilled,
                numRequired = objective.numRequired, objectiveType = objective.objectiveType }
        end
        return "ok", normalized
    end, questID)
    result.destination = A.Destination(questID)
    result.destinationCause = "unknown"
    if result.cache.status == "ok" and result.cache.value == false then
        result.destinationCause = "quest-data-not-cached; retry-explicitly"
    end
    result.playerMap = NS.Read("C_Map.GetBestMapForUnit", positiveID, "player")
    if result.playerMap.status == "ok" then
        -- Independent native-map candidates after a real beta capture showed
        -- cached quests without GetNextWaypoint data. These are diagnostic
        -- observations, never an automatic substitute destination.
        local mapID = result.playerMap.value
        result.mapPOIs = NS.Read("C_QuestLog.GetQuestsOnMap", function(entries)
            if entries == nil then return "no-data" end
            if type(entries) ~= "table" then return "invalid-data" end
            local normalized = {}
            for _, entry in ipairs(entries) do
                if type(entry) ~= "table" or not NS.ID(entry.questID)
                    or not NS.Number(entry.x) or not NS.Number(entry.y)
                    or entry.x < 0 or entry.x > 1 or entry.y < 0 or entry.y > 1
                    or (entry.isMapIndicatorQuest ~= nil and type(entry.isMapIndicatorQuest) ~= "boolean") then
                    return "invalid-data"
                end
                if entry.questID == questID then
                    normalized[#normalized + 1] = { questID = entry.questID, mapID = mapID,
                        x = entry.x, y = entry.y, isMapIndicatorQuest = entry.isMapIndicatorQuest,
                        destinationUsefulness = "not-verified" }
                end
            end
            return "ok", normalized
        end, mapID)
        result.mapWaypoint = NS.Read("C_QuestLog.GetNextWaypointForMap", function(x, y)
            if x == nil and y == nil then return "no-data" end
            if not NS.Number(x) or not NS.Number(y) or x < 0 or x > 1 or y < 0 or y > 1 then
                return "invalid-data"
            end
            return "ok", { mapID = mapID, x = x, y = y, destinationUsefulness = "not-verified" }
        end, questID, mapID)
        result.playerPosition = NS.Read("C_Map.GetPlayerMapPosition", position, result.playerMap.value, "player")
        if result.playerPosition.status == "ok" then
            result.playerWorld = convert(result.playerMap.value, result.playerPosition.value)
        end
    end
    if result.destination.status == "ok" then
        result.destinationWorld = convert(result.destination.value.mapID, result.destination.value)
    end
    result.distance = distanceBetween(result.playerWorld, result.destinationWorld)
    -- Native map points exist for the tested beta quest even without a next
    -- waypoint. Test their conversion independently; numeric success still
    -- does not establish an appropriate objective destination or game yards.
    if result.mapPOIs and result.mapPOIs.status == "ok" then
        for _, point in ipairs(result.mapPOIs.value) do
            point.worldPosition = convert(point.mapID, point)
            point.distance = distanceBetween(result.playerWorld, point.worldPosition)
        end
    end
    if result.mapWaypoint and result.mapWaypoint.status == "ok" then
        local point = result.mapWaypoint.value
        point.worldPosition = convert(point.mapID, point)
        point.distance = distanceBetween(result.playerWorld, point.worldPosition)
    end
    return result
end
