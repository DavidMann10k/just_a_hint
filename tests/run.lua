-- Behavioral fixtures only. This does not execute Blizzard's renderer or prove
-- Forever compatibility. Uses Lua 5.1-compatible syntax in addon code and tests.
local source = "addon/JustAHintDiagnostics/"
local passed, failed = 0, 0

local function equal(actual, expected, message)
    if actual ~= expected then
        error((message or "values differ") .. ": expected " .. tostring(expected)
            .. ", got " .. tostring(actual), 2)
    end
end

local function truth(value, message)
    if not value then error(message or "expected truthy value", 2) end
end

local function vector(x, y)
    return { GetXY = function() return x, y end }
end

local function fixture()
    local state = { frames = {}, drawCalls = {}, waypointCalls = 0, mutations = 0,
        mapID = 7, questPOI = "1", superTracked = 99, waypoint = { 7, 0.8, 0.7 },
        cached = true, accepted = true, supported = true, missingMethods = {},
        playerContinent = 1, destinationContinent = 1, playerPosition = vector(0.2, 0.3),
        objectiveCount = 3, messages = {}, combat = false }
    _G.JustAHintDiagnosticsDB = nil
    _G.WOW_PROJECT_ID = 123 -- Deliberately fictional fixture metadata.
    _G.GetBuildInfo = function() return "fixture", "fixture-build", "fixture-date", 999999 end
    _G.date = function() return "fixture-timestamp" end
    _G.HaveQuestData = function() return state.cached end
    _G.CreateVector2D = vector
    _G.InCombatLockdown = function() return state.combat end
    local function mutation()
        state.mutations = state.mutations + 1
        error("diagnostics must never mutate guidance")
    end
    _G.SetCVar = mutation
    _G.QuestMapFrame = nil
    _G.QuestMapFrame_GetFocusedQuestID = nil
    _G.QuestMapFrame_ShowQuestDetails = mutation
    _G.QuestMapFrame_OpenToQuestDetails = mutation
    _G.C_CVar = { GetCVar = function() return state.questPOI end, SetCVar = mutation }
    _G.C_SuperTrack = { GetSuperTrackedQuestID = function() return state.superTracked end,
        SetSuperTrackedQuestID = mutation }
    _G.C_QuestLog = {
        IsOnQuest = function() return state.accepted end,
        IsComplete = function() return false end,
        GetNextWaypoint = function()
            state.waypointCalls = state.waypointCalls + 1
            if not state.waypoint then return nil end
            return state.waypoint[1], state.waypoint[2], state.waypoint[3]
        end,
        GetQuestObjectives = function()
            return { { text = state.objectiveCount .. "/8", type = "monster", finished = false,
                numFulfilled = state.objectiveCount, numRequired = 8, objectiveType = 1 } }
        end,
        GetNumQuestLogEntries = function() return 3, 2 end,
        GetInfo = function(index)
            if index == 1 then return { isHeader = true } end
            return { questID = index + 40, title = "Fixture quest " .. index, isHeader = false }
        end,
        SetSelectedQuest = mutation,
        GetSelectedQuest = function() return state.selectedQuest or 0 end,
    }
    _G.C_Map = {
        GetBestMapForUnit = function() return 7 end,
        GetPlayerMapPosition = function() return state.playerPosition end,
        GetWorldPosFromMapPos = function(_, position)
            local x, y = position:GetXY()
            local continent = x == 0.2 and state.playerContinent or state.destinationContinent
            return continent, vector(x * 1000, y * 1000)
        end,
        SetUserWaypoint = mutation,
        OpenWorldMap = mutation,
    }
    _G.SlashCmdList = {}
    _G.UISpecialFrames = {}
    _G.DEFAULT_CHAT_FRAME = { AddMessage = function(_, message)
        state.messages[#state.messages + 1] = message
    end }

    local methods = {}
    function methods:RegisterEvent(event) self.events[event] = true end
    function methods:SetScript(event, fn) self.scripts[event] = fn end
    function methods:Show()
        local wasShown = self.shown
        self.shown = true
        if not wasShown and self.scripts.OnShow then self.scripts.OnShow(self) end
    end
    function methods:Hide()
        local wasShown = self.shown
        self.shown = false
        if wasShown and self.scripts.OnHide then self.scripts.OnHide(self) end
        -- Simulate ancestor visibility changes separately from a child's shown flag.
        for _, child in ipairs(state.frames) do
            if child.parent == self and child.shown and child.scripts.OnHide then
                child.scripts.OnHide(child)
            end
        end
    end
    function methods:IsShown() return self.shown and (not self.parent or self.parent:IsShown()) end
    function methods:IsVisible() return self:IsShown() end
    function methods:GetName() return self.name end
    function methods:GetObjectType() return self.kind end
    function methods:GetParent() return self.parent end
    function methods:GetRect() return 100,80,self:GetWidth(),self:GetHeight() end
    function methods:IsProtected() return self.protected or false end
    function methods:SetParent(parent) self.parent = parent end
    function methods:SetAllPoints(parent) self.anchored = parent end
    function methods:SetSize(width, height) self.width, self.height = width, height end
    function methods:SetWidth(width) self.width = width end
    function methods:SetHeight(height) self.height = height end
    function methods:GetWidth() return self.anchored and self.anchored:GetWidth() or self.width end
    function methods:GetHeight() return self.anchored and self.anchored:GetHeight() or self.height end
    function methods:GetEffectiveScale() return self.scale end
    function methods:GetFrameLevel() return self.level end
    function methods:SetFrameLevel(level) self.level = level end
    function methods:SetMapID(mapID) self.mapID = mapID end
    function methods:DrawNone() self.drawnQuestID = nil end
    function methods:DrawBlob(id, draw)
        truth(draw)
        self.drawnQuestID = id
        state.drawCalls[#state.drawCalls + 1] = id
        state.drawRenders = state.drawRenders or {}
        state.drawRenders[#state.drawRenders+1] = { alpha=self.alpha, fill=self.fillAlpha, border=self.borderAlpha, parent=self.parent }
    end
    function methods:UpdateMouseOverTooltip(x, y)
        state.queryCalls = (state.queryCalls or 0) + 1
        if state.hitMode == "error" then error("restricted query") end
        if state.hitMode == "malformed" then return "unexpected-id", 1 end
        if state.hitMode == "always" then return 42, 1 end
        if self.drawnQuestID and state.hitMode == "multi-site"
            and ((x == 0.25 and y == 0.25) or (x == 0.75 and y == 0.75)) then
            return self.drawnQuestID, 2
        end
        if self.drawnQuestID and x >= 0.25 and x <= 0.5 and y >= 0.25 and y <= 0.5 then
            if state.hitMode == "drawn" then return self.drawnQuestID, 1 end
            if state.hitMode == "visible-only" and self.fillAlpha ~= 0 then return self.drawnQuestID, 1 end
            if state.hitMode == "other" then return 99, 1 end
        end
    end
    for _, method in ipairs({ "SetPoint", "ClearAllPoints", "EnableMouse", "SetFillTexture",
        "SetBorderTexture", "SetBorderScalar", "SetFrameStrata",
        "SetMultiLine", "SetAutoFocus", "SetFontObject", "SetScrollChild", "SetFocus", "HighlightText", "SetEnabled" }) do
        methods[method] = function() end
    end
    for _, method in ipairs({ "SetMovable", "RegisterForDrag", "StartMoving", "StopMovingOrSizing" }) do
        methods[method] = function() end
    end
    function methods:SetPoint(...) self.point = { ... } end
    function methods:SetAlpha(value) self.alpha=value end
    function methods:SetFillAlpha(value) self.fillAlpha=value end
    function methods:SetBorderAlpha(value) self.borderAlpha=value end
    function methods:SetEnabled(value) self.enabled = value end
    function methods:EnableMouse(value) self.mouseEnabled = value end
    function methods:SetText(text) self.text = text end
    function methods:CreateTexture()
        return { SetAllPoints = function() end, SetColorTexture = function() end }
    end
    function methods:CreateFontString()
        return { SetPoint = function() end, SetText = methods.SetText, SetSize = methods.SetSize,
            SetJustifyH = function() end, SetJustifyV = function() end }
    end
    _G.CreateFrame = function(kind, name, parent)
        if kind == "QuestPOIFrame" and not state.supported then error("unsupported frame type") end
        local frame = { kind = kind, name = name, parent = parent, scripts = {}, events = {},
            width = 640, height = 400, scale = 1, level = 1, shown = true }
        for method, fn in pairs(methods) do
            if kind ~= "QuestPOIFrame" or not state.missingMethods[method] then frame[method] = fn end
        end
        state.frames[#state.frames + 1] = frame
        if name then _G[name] = frame end
        return frame
    end
    _G.UIParent = CreateFrame("Frame")
    state.canvas = CreateFrame("Frame", nil, UIParent)
    _G.WorldMapFrame = CreateFrame("Frame", nil, UIParent)
    WorldMapFrame.GetMapID = function() return state.mapID end
    WorldMapFrame.GetCanvas = function() return state.canvas end
    state.pinPools = {}
    WorldMapFrame.EnumeratePinsByTemplate = function(_, template)
        local index = 0
        return function()
            index = index + 1
            return (state.pinPools[template] or {})[index]
        end
    end
    function state.addPin(template, hidden)
        local pin = CreateFrame("Frame", nil, WorldMapFrame)
        state.pinPools[template] = state.pinPools[template] or {}
        table.insert(state.pinPools[template], pin)
        if hidden then pin:Hide() end
        return pin
    end
    WorldMapFrame.pinFrameLevelsManager = { GetValidFrameLevel = function(_, levelType)
        equal(levelType, "PIN_FRAME_LEVEL_QUEST_BLOB")
        return 2100 -- Fixture only: implementation reads the installed map's value.
    end }

    local ns = {}
    for _, file in ipairs({ "Core.lua", "ClientAdapter.lua", "AreaProbe.lua", "Commands.lua" }) do
        assert(loadfile(source .. file))("JustAHintDiagnostics", ns)
    end
    state.eventFrame = state.frames[#state.frames]
    function state.fire(event, arg)
        state.eventFrame.scripts.OnEvent(state.eventFrame, event, arg)
    end
    state.fire("ADDON_LOADED", "JustAHintDiagnostics")
    function state.update()
        if ns.SilentRegion.frame and ns.SilentRegion.frame:IsShown() then
            ns.SilentRegion.frame.scripts.OnUpdate(ns.SilentRegion.frame, 0.02)
        end
        if ns.NativeButtonProbe.frame and ns.NativeButtonProbe.frame:IsShown() then
            ns.NativeButtonProbe.frame.scripts.OnUpdate(ns.NativeButtonProbe.frame, 0.02)
        end
        if ns.Isolation.frame and ns.Isolation.frame:IsShown() then
            ns.Isolation.frame.scripts.OnUpdate(ns.Isolation.frame)
        end
        if ns.Area.frame and ns.Area.frame.scripts.OnUpdate then
            ns.Area.frame.scripts.OnUpdate(ns.Area.frame, 0.02)
        end
    end
    return ns, state
end

local function test(name, fn)
    local ok, errorMessage = pcall(fn)
    if ok then passed = passed + 1
    else failed = failed + 1; io.stderr:write("FAIL " .. name .. ": " .. tostring(errorMessage) .. "\n") end
end

test("startup and quest events stay quiet", function()
    local ns, state = fixture()
    state.fire("QUEST_LOG_UPDATE")
    state.fire("PLAYER_ENTERING_WORLD")
    equal(#ns.DB.records, 0)
    equal(#state.drawCalls, 0)
    equal(state.waypointCalls, 0)
    equal(state.mutations, 0)
    equal(ns.Area.frame, nil)
    equal(#state.messages, 0)
end)

local function nativePane()
    _G.QuestMapFrame = CreateFrame("Frame", "FixtureQuestPane", WorldMapFrame)
    QuestMapFrame.QuestsFrame = CreateFrame("Frame", nil, QuestMapFrame)
    local details = CreateFrame("Frame", "FixtureQuestDetails", QuestMapFrame.QuestsFrame)
    QuestMapFrame.DetailsFrame = details
    QuestMapFrame.QuestsFrame.DetailsFrame = details
    details.questID = 42
    for _,name in ipairs({"ScrollFrame","RewardsFrameContainer","BackFrame","AbandonButton","ShareButton","TrackButton"}) do
        details[name] = CreateFrame("Frame", nil, details)
    end
    _G.QuestMapFrame_GetFocusedQuestID = function() return details.questID end
    return details
end

test("native UI inspection reads structure without selecting, opening, drawing or creating frames", function()
    local ns,state=fixture();local details=nativePane();state.selectedQuest=43
    details.protected=true
    local frames=#state.frames
    local result=ns.Adapter.NativeUI()
    equal(result.status,"captured");equal(result.nativeIntegrationVerified,false)
    equal(result.focusedQuest.value,42);equal(result.detailsQuest.value,42)
    equal(result.selectedQuest.value,43) -- Preserve disagreement, never resolve it by selecting.
    equal(result.frames[4].name.value,"FixtureQuestDetails")
    equal(result.frames[4].parentName.status,"no-data") -- Unnamed parent stays unnamed.
    equal(result.frames[4].protected.value,true);equal(result.frames[4].rect.value.width,640)
    equal(#state.frames,frames);equal(#state.drawCalls,0);equal(state.waypointCalls,0);equal(state.mutations,0)
    equal(#ns.DB.records,0);equal(state.mapID,7);equal(state.superTracked,99);equal(details.questID,42)
end)
test("native UI missing frames and closed panes are distinct from visible details", function()
    local ns,state=fixture();local result=ns.Adapter.NativeUI()
    equal(result.frames[2].status,"missing-frame");equal(result.detailsQuest.status,"missing-frame")
    equal(result.focusedQuest.status,"missing-api");equal(result.selectedQuest.status,"no-data")
    local details=nativePane();details:Hide()
    result=ns.Adapter.NativeUI()
    equal(result.frames[4].status,"present");equal(result.frames[4].visible.value,false)
    equal(result.detailsQuest.value,42);equal(result.nativeIntegrationVerified,false)
    equal(state.mutations,0);equal(#state.drawCalls,0)
end)
test("native UI restricted, malformed and missing getters retain individual failures", function()
    local ns,state=fixture();local details=nativePane()
    details.GetRect=function() error("restricted geometry") end
    details.IsProtected=function() return "unknown" end
    details.GetName=nil
    WorldMapFrame.GetRect=function() return 0,0,math.huge,300 end
    QuestMapFrame_GetFocusedQuestID=function() error("unavailable focus") end
    local result=ns.Adapter.NativeUI()
    equal(result.frames[4].rect.status,"error");equal(result.frames[4].protected.status,"invalid-data")
    equal(result.frames[4].name.status,"missing-api");equal(result.frames[4].visible.value,true)
    equal(result.frames[1].rect.status,"invalid-data");equal(result.focusedQuest.status,"error")
    equal(result.detailsQuest.value,42);equal(state.mutations,0)
end)
test("native UI command records a bounded snapshot and opens only its copy report", function()
    local ns,state=fixture();nativePane();ns.RunCommand("ui")
    equal(#ns.DB.records,1);equal(ns.DB.records[1].kind,"native-ui")
    local record=ns.DB.records[1]
    equal(#record.data.frames,11);equal(record.data.nativeIntegrationVerified,false)
    truth(ns.exportFrame.edit.text:find("native UI capture #1",1,true))
    truth(ns.exportFrame.edit.text:find("focused: 42",1,true))
    truth(ns.DB.evidenceHex:match("^[0-9a-f]+$"))
    equal(QuestMapFrame.DetailsFrame.questID,42);equal(WorldMapFrame:IsShown(),true)
    equal(state.mutations,0);equal(#state.drawCalls,0);equal(state.waypointCalls,0)
end)

test("actual data shape preserves both world-position returns", function()
    local ns, state = fixture()
    local result = ns.Adapter.Probe(42, "normal", "outdoor")
    equal(result.status, "captured")
    equal(result.destination.value.mapID, 7)
    equal(result.playerWorld.value.continentID, 1)
    equal(result.destinationWorld.value.x, 800)
    equal(result.distance.status, "ok")
    truth(math.abs(result.distance.worldUnits - math.sqrt(600 * 600 + 400 * 400)) < 0.001)
    equal(result.distance.unitVerification, "Forever-unverified")
    equal(result.objectives.value[1].numFulfilled, 3)
    equal(#state.drawCalls, 0)
    equal(state.mutations, 0)
end)

test("missing destination API is distinct from no returned data", function()
    local ns = fixture()
    C_QuestLog.GetNextWaypoint = nil
    equal(ns.Adapter.Probe(42, "normal", "outdoor").destination.status, "missing-api")
end)

test("nil destination alone never claims loading", function()
    local ns, state = fixture()
    state.waypoint = nil
    local result = ns.Adapter.Probe(42, "normal", "outdoor")
    equal(result.destination.status, "no-data")
    equal(result.destinationCause, "unknown")
    equal(result.distance.status, "unavailable")
end)

test("known uncached quest data is recorded without invented destination", function()
    local ns, state = fixture()
    state.cached, state.waypoint = false, nil
    local result = ns.Adapter.Probe(42, "disabled", "outdoor")
    equal(result.destination.status, "no-data")
    truth(result.destinationCause:find("not%-cached"))
    equal(state.waypointCalls, 1)
end)

test("malformed and non-finite waypoints fail validation", function()
    local ns, state = fixture()
    for _, waypoint in ipairs({ { 7, -0.1, 0.5 }, { 7, 0.5, 1.1 },
        { 0, 0.5, 0.5 }, { 7, 0 / 0, 0.5 }, { 7, math.huge, 0.5 }, { 7, "0.5", 0.5 } }) do
        state.waypoint = waypoint
        equal(ns.Adapter.Destination(42).status, "invalid-data")
    end
end)

test("map-coordinate zero is valid", function()
    local ns, state = fixture()
    state.waypoint = { 7, 0, 0 }
    equal(ns.Adapter.Destination(42).status, "ok")
end)

test("different continents do not produce a distance", function()
    local ns, state = fixture()
    state.destinationContinent = 2
    local result = ns.Adapter.Probe(42, "normal", "delivery")
    equal(result.distance.status, "different-continents")
    equal(result.distance.worldUnits, nil)
end)

test("continent identifier zero is preserved", function()
    local ns, state = fixture()
    state.playerContinent, state.destinationContinent = 0, 0
    local result = ns.Adapter.Probe(42, "normal", "outdoor")
    equal(result.playerWorld.status, "ok")
    equal(result.playerWorld.value.continentID, 0)
    equal(result.destinationWorld.value.continentID, 0)
    equal(result.distance.status, "ok")
end)

test("missing player position cannot mean near", function()
    local ns, state = fixture()
    state.playerPosition = nil
    local result = ns.Adapter.Probe(42, "normal", "multi")
    equal(result.playerPosition.status, "no-data")
    equal(result.distance.status, "unavailable")
end)

test("API and returned-value inspection errors are captured", function()
    local ns = fixture()
    C_QuestLog.GetNextWaypoint = function() error("fixture API failure") end
    local result = ns.Adapter.Probe(42, "normal", "outdoor")
    equal(result.destination.status, "error")
    truth(result.destination.detail:find("fixture API failure", 1, true))
    C_Map.GetPlayerMapPosition = function()
        return { GetXY = function() error("fixture inaccessible data") end }
    end
    equal(ns.Adapter.Probe(42, "normal", "outdoor").playerPosition.status, "error")
end)

test("unaccepted quest never queries a destination", function()
    local ns, state = fixture()
    state.accepted = false
    equal(ns.Adapter.Probe(42, "normal", "outdoor").status, "accepted-quest-not-confirmed")
    equal(state.waypointCalls, 0)
    equal(ns.Area.Show(42, "normal", "outdoor").status, "accepted-quest-not-confirmed")
    equal(#state.drawCalls, 0)
end)

test("unavailable acceptance check is explicit", function()
    local ns, state = fixture()
    C_QuestLog.IsOnQuest = nil
    local result = ns.Adapter.Probe(42, "normal", "outdoor")
    equal(result.accepted.status, "missing-api")
    equal(result.status, "accepted-quest-not-confirmed")
    equal(state.waypointCalls, 0)
end)

test("quest listing excludes headers and records failures", function()
    local ns, state = fixture()
    local result = ns.Adapter.Quests()
    equal(#result.value, 2)
    equal(result.value[1].value.questID, 42)
    C_QuestLog.GetInfo = function() error("log failure") end
    local partial = ns.Adapter.Quests()
    equal(partial.value[1].status, "error")
    ns.Command("list")
    equal(state.waypointCalls, 0)
    equal(state.mutations, 0)
    equal(#state.drawCalls, 0)
end)

test("guidance labels do not override measured settings", function()
    local ns, state = fixture()
    ns.Command("probe 42 disabled outdoor tester disabled guidance")
    local result = ns.DB.records[1].data
    equal(result.context.guidanceLabel, "disabled")
    equal(result.context.questPOI.value, "1")
    equal(result.context.superTrackedQuestID.value, 99)
    equal(result.context.guidanceFullyDisabled, "not-established-by-these-readings")
    equal(state.mutations, 0)
end)

test("invalid command labels never query or render", function()
    local ns, state = fixture()
    ns.Command("area 42 arbitrary outdoor")
    ns.Command("probe 42 normal arbitrary")
    ns.Command("probe 0 normal outdoor")
    equal(#ns.DB.records, 0)
    equal(#state.drawCalls, 0)
    equal(state.waypointCalls, 0)
end)

test("only explicit area command draws and success remains unverified", function()
    local ns, state = fixture()
    ns.Command("build")
    ns.Command("probe 42 normal outdoor")
    equal(#state.drawCalls, 0)
    ns.Command("area 42 normal outdoor")
    equal(#state.drawCalls, 1)
    equal(state.drawCalls[1], 42)
    equal(ns.Area.frame.drawnQuestID, 42)
    equal(ns.Area.frame.level, 2100)
    equal(ns.DB.records[3].data.status, "call-ok-unverified")
    equal(ns.DB.records[3].data.visualResult, "unverified")
    equal(state.mutations, 0)
end)

test("new area replaces the previous one and probe does not", function()
    local ns = fixture()
    ns.Area.Show(42, "normal", "outdoor")
    ns.Command("probe 43 normal multi")
    equal(ns.Area.active.questID, 42)
    ns.Area.Show(43, "normal", "multi")
    equal(ns.Area.active.questID, 43)
    equal(ns.Area.frame.drawnQuestID, 43)
end)

test("unavailable new area clears the old one", function()
    local ns, state = fixture()
    ns.Area.Show(42, "normal", "outdoor")
    state.accepted = false
    ns.Area.Show(43, "normal", "multi")
    equal(ns.Area.active, nil)
    equal(ns.Area.frame.drawnQuestID, nil)
    equal(ns.Area.frame:IsShown(), false)
end)

test("unsupported native frame and missing methods are failures", function()
    local ns, state = fixture()
    state.supported = false
    equal(ns.Area.Show(42, "normal", "outdoor").status, "error")
    equal(#state.drawCalls, 0)
    ns, state = fixture()
    state.missingMethods.DrawBlob = true
    equal(ns.Area.Show(42, "normal", "outdoor").status, "missing-blob-method:DrawBlob")
    equal(#state.drawCalls, 0)
end)

test("hidden map, incompatible canvas and combat do not draw", function()
    local ns, state = fixture()
    WorldMapFrame:Hide()
    equal(ns.Area.Show(42, "normal", "outdoor").status, "open-world-map-manually")
    WorldMapFrame:Show()
    WorldMapFrame.GetCanvas = nil
    equal(ns.Area.Show(42, "normal", "outdoor").status, "map-canvas-api-unavailable")
    state.combat = true
    equal(ns.Area.Show(42, "normal", "outdoor").status, "unavailable-in-combat")
    equal(#state.drawCalls, 0)
end)

test("unavailable map layering is explicit instead of guessed", function()
    local ns, state = fixture()
    WorldMapFrame.pinFrameLevelsManager = nil
    equal(ns.Area.Show(42, "normal", "outdoor").status, "map-frame-level-api-unavailable")
    equal(#state.drawCalls, 0)
end)

test("explicit clear hides preview", function()
    local ns = fixture()
    ns.Area.Show(42, "normal", "outdoor")
    ns.Command("clear")
    equal(ns.Area.active, nil)
    equal(ns.Area.frame.drawnQuestID, nil)
    equal(ns.Area.frame:IsShown(), false)
end)

test("map changes and canvas changes clear without replacement", function()
    local ns, state = fixture()
    ns.Area.Show(42, "normal", "outdoor")
    state.mapID = 8
    state.update()
    equal(ns.Area.active, nil)
    equal(#state.drawCalls, 1)
    state.mapID = 7
    ns.Area.Show(42, "normal", "outdoor")
    state.canvas:SetWidth(900)
    state.update()
    equal(ns.Area.active, nil)
    ns.Area.Show(42, "normal", "outdoor")
    state.canvas.scale = 2
    state.update()
    equal(ns.Area.active, nil)
end)

test("world map close cannot resurrect preview on reopening", function()
    local ns, state = fixture()
    ns.Area.Show(42, "normal", "outdoor")
    -- Native ancestor hide fires child OnHide; exercise that hook explicitly.
    WorldMapFrame:Hide()
    ns.Area.frame.scripts.OnHide(ns.Area.frame)
    WorldMapFrame:Show()
    state.update()
    equal(ns.Area.active, nil)
    equal(ns.Area.frame.drawnQuestID, nil)
    equal(#state.drawCalls, 1)
end)

test("diagnostic quest/world events discard preview, never upgrade it", function()
    local ns, state = fixture()
    for _, event in ipairs({ "QUEST_LOG_UPDATE", "PLAYER_ENTERING_WORLD" }) do
        ns.Area.Show(42, "normal", "outdoor")
        state.fire(event)
        equal(ns.Area.active, nil)
        equal(ns.Area.frame.drawnQuestID, nil)
    end
    equal(#state.drawCalls, 2)
end)

test("observations remain separate from invocation results", function()
    local ns = fixture()
    ns.Command("area 42 normal outdoor")
    ns.Command("clear")
    ns.Command("observe 1 none no native region appeared")
    equal(ns.DB.records[1].data.status, "call-ok-unverified")
    equal(ns.DB.records[1].data.visualResult, "unverified")
    equal(ns.DB.records[2].kind, "area-cleared")
    equal(ns.DB.records[2].data.reason, "manual")
    equal(ns.DB.records[3].kind, "area-observation")
    equal(ns.DB.records[3].data.areaRecordID, 1)
    equal(ns.DB.records[3].data.visualResult, "none")
    ns.Command("observe 2 visible cannot observe an observation")
    equal(#ns.DB.records, 3)
end)

test("bounded captures contain exact fixture build and no frame state", function()
    local ns = fixture()
    for _ = 1, 102 do ns.Command("build") end
    equal(#ns.DB.records, 100)
    equal(ns.DB.records[1].id, 3)
    equal(ns.DB.records[100].build.value.interface, 999999)
    equal(ns.DB.active, nil)
    equal(ns.DB.frame, nil)
    local saved = ns.DB
    ns = fixture()
    JustAHintDiagnosticsDB = saved
    ns.Initialize()
    equal(#ns.DB.records, 100)
    equal(ns.Area.active, nil)
    equal(ns.Area.frame, nil)
end)

test("copyable report export does not draw guidance", function()
    local ns, state = fixture()
    ns.Command("probe 42 normal outdoor")
    ns.Command("export 1")
    truth(ns.exportFrame.edit.text:find("fixture%-build"))
    truth(ns.exportFrame.edit.text:find("unverified", 1, true))
    equal(#state.drawCalls, 0)
    equal(state.mutations, 0)
end)

test("entrypoint catches unexpected failures", function()
    local ns, state = fixture()
    ns.Command = function() error("unexpected fixture failure") end
    SlashCmdList.JUSTAHINTDIAGNOSTICS("probe 42 normal outdoor")
    truth(state.messages[1]:find("Diagnostic failed", 1, true))
    equal(state.mutations, 0)
end)

test("scan captures accepted quests without drawing or changing guidance", function()
    local ns, state = fixture()
    ns.Command("scan normal")
    equal(ns.DB.records[1].kind, "scan")
    equal(#ns.DB.records[1].data.results, 2)
    equal(#state.drawCalls, 0)
    equal(state.mutations, 0)
    truth(ns.DB.evidenceHex:match("^[0-9a-f]+$"))
    local decoded = ns.DB.evidenceHex:gsub("%x%x", function(pair) return string.char(tonumber(pair, 16)) end)
    truth(decoded:find('"kind":"scan"', 1, true))
    truth(decoded:find('"records":[', 1, true))
end)

test("JSON transport escapes control characters and unsupported numbers", function()
    local ns = fixture()
    equal(ns.JSON('quote" slash\\ newline\n'), '"quote\\" slash\\\\ newline\\u000a"')
    equal(ns.JSON(0 / 0), "null")
    equal(ns.JSON({ true, false, 3 }), "[true,false,3]")
end)

test("map POIs remain independent evidence when next waypoint is absent", function()
    local ns, state = fixture()
    state.waypoint = nil
    C_QuestLog.GetQuestsOnMap = function(mapID)
        equal(mapID, 7)
        return { { questID = 42, x = 0.4, y = 0.5, isMapIndicatorQuest = false },
                 { questID = 99, x = 0.1, y = 0.2, isMapIndicatorQuest = true } }
    end
    C_QuestLog.GetNextWaypointForMap = function() return nil end
    local result = ns.Adapter.Probe(42, "normal", "outdoor")
    equal(result.destination.status, "no-data")
    equal(result.mapWaypoint.status, "no-data")
    equal(result.mapPOIs.status, "ok")
    equal(#result.mapPOIs.value, 1)
    equal(result.mapPOIs.value[1].questID, 42)
    equal(result.mapPOIs.value[1].destinationUsefulness, "not-verified")
    equal(result.mapPOIs.value[1].worldPosition.value.x, 400)
    equal(result.mapPOIs.value[1].worldPosition.value.continentID, 1)
    equal(result.mapPOIs.value[1].distance.worldUnits, math.sqrt(80000))
    equal(result.mapPOIs.value[1].distance.unitVerification, "Forever-unverified")
    equal(result.distance.status, "unavailable")
    equal(state.mutations, 0)
    equal(#state.drawCalls, 0)
end)

test("map candidate conversions reject incomparable world spaces", function()
    local ns, state = fixture()
    state.destinationContinent = 2
    C_QuestLog.GetQuestsOnMap = function() return { { questID = 42, x = 0.4, y = 0.5 } } end
    C_QuestLog.GetNextWaypointForMap = function() return 0.4, 0.5 end
    local result = ns.Adapter.Probe(42, "normal", "outdoor")
    equal(result.mapPOIs.value[1].distance.status, "different-continents")
    equal(result.mapWaypoint.value.distance.status, "different-continents")
    equal(result.mapWaypoint.value.worldPosition.value.continentID, 2)
    equal(result.mapWaypoint.value.destinationUsefulness, "not-verified")
    equal(state.mutations, 0)
end)

test("unavailable candidate conversion preserves the native map point", function()
    local ns, state = fixture()
    C_QuestLog.GetQuestsOnMap = function() return { { questID = 42, x = 0.4, y = 0.5 } } end
    C_QuestLog.GetNextWaypointForMap = function() return 0.4, 0.5 end
    C_Map.GetWorldPosFromMapPos = nil
    local result = ns.Adapter.Probe(42, "normal", "outdoor")
    equal(result.mapPOIs.value[1].x, 0.4)
    equal(result.mapPOIs.value[1].worldPosition.status, "missing-api")
    equal(result.mapPOIs.value[1].distance.status, "unavailable")
    equal(result.mapWaypoint.value.distance.status, "unavailable")
    equal(#state.drawCalls, 0)
end)

test("invalid map candidates fail without inventing a destination", function()
    local ns = fixture()
    C_QuestLog.GetQuestsOnMap = function() return { { questID = 42, x = -1, y = 0.4 } } end
    C_QuestLog.GetNextWaypointForMap = function() return 0 / 0, 0.5 end
    local result = ns.Adapter.Probe(42, "normal", "outdoor")
    equal(result.mapPOIs.status, "invalid-data")
    equal(result.mapWaypoint.status, "invalid-data")
end)

test("clearing is visible and recorded once without automatic redrawing", function()
    local ns, state = fixture()
    ns.Command("area 42 normal outdoor")
    local panel = ns.AreaPanel.frame
    truth(panel:IsShown())
    truth(panel.status.text:find("PREVIEW REQUESTED", 1, true))
    state.fire("QUEST_LOG_UPDATE")
    truth(panel.status.text:find("HIDDEN", 1, true))
    truth(panel.status.text:find("quest log updated", 1, true))
    equal(ns.DB.records[2].kind, "area-cleared")
    equal(ns.DB.records[2].data.areaRecordID, 1)
    equal(ns.DB.records[2].data.reason, "QUEST_LOG_UPDATE")
    state.fire("QUEST_LOG_UPDATE")
    equal(#ns.DB.records, 2)
    equal(#state.drawCalls, 1)
    equal(state.mutations, 0)
end)

test("comparison buttons require explicit requests and never resurrect a hidden map", function()
    local ns, state = fixture()
    ns.Command("area 42 normal outdoor")
    local panel = ns.AreaPanel.frame
    panel.hideButton.scripts.OnClick()
    equal(ns.Area.active, nil)
    equal(#state.drawCalls, 1)
    panel.showButton.scripts.OnClick()
    equal(ns.Area.active.questID, 42)
    equal(#state.drawCalls, 2)
    equal(ns.DB.records[#ns.DB.records].data.questProbe.questID, 42)
    equal(ns.DB.records[#ns.DB.records].data.render.canvasWidth, 640)
    WorldMapFrame:Hide()
    state.update()
    panel.showButton.scripts.OnClick()
    equal(ns.Area.active, nil)
    equal(#state.drawCalls, 2)
    truth(panel.status.text:find("NOT DRAWN", 1, true))
    WorldMapFrame:Show()
    equal(#state.drawCalls, 2)
    panel.closeButton.scripts.OnClick()
    truth(not panel:IsShown())
    equal(state.mutations, 0)
end)

test("zero canvas size is an explicit failure", function()
    local ns, state = fixture()
    state.canvas:SetWidth(0)
    equal(ns.Area.Show(42, "normal", "outdoor").status, "invalid-canvas-size")
    equal(#state.drawCalls, 0)
end)

test("quest picker opening and refreshing preserve guidance until an explicit choice", function()
    local ns, state = fixture()
    ns.Command("area 99 normal outdoor")
    ns.Command("area disabled")
    local picker = ns.AreaPanel.picker
    truth(picker:IsShown())
    equal(picker.rows[1].questID, 42)
    equal(picker.rows[2].questID, 43)
    picker.refreshButton.scripts.OnClick()
    equal(ns.Area.active.questID, 99)
    equal(#state.drawCalls, 1)
    equal(state.waypointCalls, 1)
    equal(ns.DB.records[#ns.DB.records].kind, "quest-list")
    picker.rows[2].scripts.OnClick(picker.rows[2])
    equal(ns.Area.active.questID, 43)
    equal(state.drawCalls[2], 43)
    equal(#state.drawCalls, 2)
    local result = ns.DB.records[#ns.DB.records].data
    equal(result.context.guidanceLabel, "disabled")
    equal(result.context.questCategory, "unclassified")
    equal(result.questProbe.questID, 43)
    equal(picker:IsShown(), false)
    equal(state.mutations, 0)
end)

test("removed picker quest refuses drawing and offers a fresh list", function()
    local ns, state = fixture()
    ns.Command("area")
    local picker = ns.AreaPanel.picker
    equal(picker.phase, "normal")
    state.accepted = false
    picker.rows[1].scripts.OnClick(picker.rows[1])
    equal(#state.drawCalls, 0)
    equal(state.waypointCalls, 0)
    local panel = ns.AreaPanel.frame
    truth(panel.status.text:find("no longer in your log", 1, true))
    truth(not panel.status.text:find("Open the relevant", 1, true))
    C_QuestLog.GetNumQuestLogEntries = function() return 1 end
    C_QuestLog.GetInfo = function() return { questID = 100, title = "New quest" } end
    panel.questsButton.scripts.OnClick()
    equal(picker.rows[1].questID, 100)
    equal(picker.rows[2].questID, nil)
    equal(picker.rows[2]:IsShown(), false)
    picker.closeButton.scripts.OnClick()
    equal(#state.drawCalls, 0)
    equal(state.mutations, 0)
end)

test("picker pages preserve IDs and report partial or unavailable lists", function()
    local ns, state = fixture()
    C_QuestLog.GetNumQuestLogEntries = function() return 11 end
    C_QuestLog.GetInfo = function(index)
        if index == 11 then error("unreadable fixture entry") end
        return { questID = index + 100, title = "Quest " .. index }
    end
    ns.Command("area")
    local picker = ns.AreaPanel.picker
    truth(picker.status.text:find("Unreadable entries: 1", 1, true))
    picker.nextButton.scripts.OnClick()
    equal(picker.rows[1].questID, 109)
    equal(picker.rows[2].questID, 110)
    equal(picker.rows[3].questID, nil)
    picker.nextButton.scripts.OnClick()
    equal(picker.page, 2)
    picker.previousButton.scripts.OnClick()
    equal(picker.rows[1].questID, 101)
    C_QuestLog.GetNumQuestLogEntries = nil
    picker.refreshButton.scripts.OnClick()
    truth(picker.status.text:find("Quest list unavailable: missing-api", 1, true))
    equal(picker.rows[1].questID, nil)
    C_QuestLog.GetNumQuestLogEntries = function() return 0 end
    picker.refreshButton.scripts.OnClick()
    truth(picker.status.text:find("No readable quests", 1, true))
    equal(#state.drawCalls, 0)
    equal(state.mutations, 0)
end)

test("isolation hides only known quest frames and restores their previous visibility", function()
    local ns, state = fixture()
    local quest = state.addPin("QuestPinTemplate")
    local hidden = state.addPin("QuestPinTemplate", true)
    local blob = state.addPin("QuestBlobPinTemplate")
    local other = state.addPin("UnrelatedFixturePin")
    ns.Command("isolate")
    equal(ns.DB.records[1].data.status, "frames-hidden-unverified")
    truth(ns.AreaPanel.picker:IsShown())
    truth(not quest:IsShown() and not blob:IsShown())
    truth(other:IsShown())
    equal(#state.drawCalls, 0)
    ns.Command("area 42 isolated outdoor")
    equal(#state.drawCalls, 1)
    truth(ns.Area.frame:IsShown())
    equal(ns.DB.records[3].data.context.mapIsolation.recordID, 1)
    ns.AreaPanel.frame.restoreButton.scripts.OnClick()
    equal(ns.Isolation.active, nil)
    equal(ns.Area.active, nil)
    truth(quest:IsShown() and blob:IsShown() and other:IsShown())
    truth(not hidden:IsShown())
    equal(state.questPOI, "1")
    equal(state.mutations, 0)
end)

test("isolation ends on native redisplay and cannot authorize a stale area request", function()
    local ns, state = fixture()
    local quest = state.addPin("QuestPinTemplate")
    state.addPin("QuestBlobPinTemplate")
    ns.Command("isolate")
    ns.Command("area 42 isolated outdoor")
    quest:Show()
    state.update()
    equal(ns.Isolation.active, nil)
    equal(ns.DB.records[#ns.DB.records].data.reason, "default-quest-frame-reappeared")
    equal(ns.Area.active, nil)
    ns.AreaPanel.frame.showButton.scripts.OnClick()
    equal(#state.drawCalls, 1)
    truth(quest:IsShown())
end)

test("closing diagnostic panels restores isolation but choosing a quest preserves it", function()
    local ns, state = fixture()
    local quest = state.addPin("QuestPinTemplate")
    state.addPin("QuestBlobPinTemplate")
    ns.Command("isolate")
    ns.AreaPanel.picker.closeButton.scripts.OnClick()
    equal(ns.Isolation.active, nil)
    truth(quest:IsShown())
    ns.Command("isolate")
    local row = ns.AreaPanel.picker.rows[1]
    row.scripts.OnClick(row)
    truth(ns.Isolation.active)
    equal(ns.Area.active.questID, 42)
    ns.AreaPanel.frame.closeButton.scripts.OnClick()
    equal(ns.Isolation.active, nil)
    equal(ns.Area.active, nil)
    truth(quest:IsShown())
end)

test("isolation rejects disabled settings and incomplete or protected template sets", function()
    local ns, state = fixture()
    state.questPOI = "0"
    equal(ns.Isolation.Start().status, "requires-questPOI-1")
    equal(state.questPOI, "0")
    state.questPOI = "1"
    local quest = state.addPin("QuestPinTemplate")
    equal(ns.Isolation.Start().status, "quest-pin-templates-not-populated")
    local blob = state.addPin("QuestBlobPinTemplate")
    blob.protected = true
    equal(ns.Isolation.Start().status, "error")
    truth(quest:IsShown() and blob:IsShown())
    equal(state.mutations, 0)
end)

test("isolation restores after partial failure without showing released pins", function()
    local ns, state = fixture()
    local quest = state.addPin("QuestPinTemplate")
    local blob = state.addPin("QuestBlobPinTemplate")
    local hide = blob.Hide
    blob.Hide = function() error("fixture hide failure") end
    equal(ns.Isolation.Start().status, "error")
    equal(ns.Isolation.active, nil)
    truth(quest:IsShown() and blob:IsShown())
    blob.Hide = hide
    ns.Command("isolate")
    state.pinPools.QuestPinTemplate = {}
    ns.Command("restore")
    truth(not quest:IsShown())
    truth(blob:IsShown())
end)

test("map and quest changes end isolation without persistent settings or hooks", function()
    for _, change in ipairs({ "close", "map", "combat", "quest", "cvar" }) do
        local ns, state = fixture()
        local quest = state.addPin("QuestPinTemplate")
        state.addPin("QuestBlobPinTemplate")
        ns.Command("isolate")
        if change == "close" then WorldMapFrame:Hide()
        elseif change == "map" then state.mapID = 8
        elseif change == "combat" then state.combat = true
        elseif change == "quest" then state.fire("QUEST_LOG_UPDATE")
        elseif change == "cvar" then state.questPOI = "0" end
        state.update()
        equal(ns.Isolation.active, nil, change)
        if change == "close" then WorldMapFrame:Show() end
        truth(quest:IsShown())
        equal(state.mutations, 0)
        equal(#state.drawCalls, 0)
    end
end)

test("acceptance read failure is distinguished from confirmed removal", function()
    local ns, state = fixture()
    C_QuestLog.IsOnQuest = nil
    ns.Command("area 42 normal outdoor")
    truth(ns.AreaPanel.frame.status.text:find("Could not verify", 1, true))
    truth(not ns.AreaPanel.frame.status.text:find("no longer in your log", 1, true))
    equal(#state.drawCalls, 0)
end)

local function finishRegion(ns,state)
    for _ = 1,200 do
        if not ns.Region.active then return end
        local before = state.queryCalls or 0
        state.update()
        truth((state.queryCalls or 0)-before <= ns.Region.PER_FRAME, "bounded queries per frame")
    end
    error("region fixture did not finish")
end

test("region query requires its own explicit action and an active preview", function()
    local ns,state=fixture();ns.Command("region");equal(ns.Region.active,nil)
    ns.Command("area 42 normal outdoor");state.update();equal(state.queryCalls,nil)
    state.hitMode="drawn";ns.AreaPanel.frame.regionButton.scripts.OnClick();truth(ns.Region.active)
    finishRegion(ns,state);equal(ns.Region.lastResult.status,"draw-dependent-hit")
    equal(ns.Region.lastResult.absenceEstablished,false);equal(ns.Region.lastResult.visualResult,"unverified")
    equal(ns.Region.lastResult.phases.hiddenBefore.matches,0)
    truth(ns.Region.lastResult.phases.drawn.matches>0)
    equal(ns.Region.lastResult.phases.hiddenAfter.matches,0)
    equal(ns.Region.lastResult.transparentQueryResult,"transparent-drawn-hit")
    equal(#ns.Region.lastResult.phases.drawn.locations,ns.Region.lastResult.phases.drawn.matches)
    equal(ns.Region.lastResult.phases.drawn.locations[1].x,0.25)
    equal(ns.Region.lastResult.phases.drawn.locations[1].objectiveCount,1)
    equal(ns.Area.frame.fillAlpha,255);equal(ns.Area.frame.borderAlpha,255)
    equal(state.queryCalls,4*1089);equal(ns.Area.frame.drawnQuestID,42);equal(state.mutations,0)
    equal(ns.DB.records[#ns.DB.records].kind,"region-probe")
end)
test("spatial sampling preserves separated sites rather than averaging their coordinates", function()
    local ns,state=fixture();state.hitMode="multi-site"
    ns.Command("area 42 normal multi");ns.Command("region");finishRegion(ns,state)
    for _,phase in ipairs({"drawn","transparentDrawn"}) do
        local sites=ns.Region.lastResult.phases[phase].locations
        equal(#sites,2);equal(sites[1].x,0.25);equal(sites[1].y,0.25)
        equal(sites[2].x,0.75);equal(sites[2].y,0.75)
        equal(sites[1].objectiveCount,2)
    end
    equal(ns.Region.lastResult.spatialSamplesAreApproximate,true)
    equal(ns.Region.lastResult.transparentQueryResult,"transparent-drawn-hit")
end)
test("transparent query misses remain unknown and restore the visible authorized preview", function()
    local ns,state=fixture();state.hitMode="visible-only"
    ns.Command("area 42 normal multi");ns.Command("region");finishRegion(ns,state)
    equal(ns.Region.lastResult.status,"draw-dependent-hit")
    equal(ns.Region.lastResult.transparentQueryResult,"transparent-no-hit-unknown")
    equal(#ns.Region.lastResult.phases.transparentDrawn.locations,0)
    equal(ns.Area.frame.fillAlpha,255);equal(ns.Area.frame.borderAlpha,255)
    equal(ns.Area.frame.drawnQuestID,42);equal(state.mutations,0)
end)
test("zero hits remain unknown, never proof that a region is absent", function()
    local ns,state=fixture();ns.Command("area 42 normal outdoor");ns.Command("region")
    finishRegion(ns,state);equal(ns.Region.lastResult.status,"no-hit-unknown")
    equal(ns.Region.lastResult.absenceEstablished,false);equal(ns.Area.frame.drawnQuestID,42)
end)
test("hidden-state or other-quest hits invalidate the comparison", function()
    for _,mode in ipairs({"always","other"}) do
        local ns,state=fixture();state.hitMode=mode
        ns.Command("area 42 normal outdoor");ns.Command("region");finishRegion(ns,state)
        equal(ns.Region.lastResult.status,"inconclusive-controls")
        equal(ns.Region.lastResult.absenceEstablished,false);equal(state.mutations,0)
    end
end)
test("cancelled checks cannot revive areas after clear, map, quest or combat changes", function()
    for _,change in ipairs({"clear","map","quest","combat","replace"}) do
        local ns,state=fixture();state.hitMode="drawn"
        ns.Command("area 42 normal outdoor");ns.Command("region");state.update()
        if change=="clear" then ns.Command("clear")
        elseif change=="map" then state.mapID=8;state.update()
        elseif change=="quest" then state.fire("QUEST_LOG_UPDATE")
        elseif change=="combat" then state.combat=true;state.update()
        else ns.Command("area 43 normal outdoor") end
        equal(ns.Region.active,nil);equal(ns.Region.lastResult.status,"cancelled")
        equal(ns.Region.lastResult.previewRestored,false)
        state.update();equal(ns.Area.frame.drawnQuestID,change=="replace" and 43 or nil)
    end
end)
test("missing, restricted and malformed query results are recorded without changing guidance", function()
    for _,mode in ipairs({"missing","error","malformed"}) do
        local ns,state=fixture();state.hitMode=mode;ns.Command("area 42 normal outdoor")
        if mode=="missing" then ns.Area.frame.UpdateMouseOverTooltip=nil end
        ns.Command("region");finishRegion(ns,state)
        equal(ns.Region.lastResult.status,mode=="missing" and "missing-api" or "error")
        equal(ns.Region.lastResult.absenceEstablished,false);equal(state.mutations,0)
    end
end)

test("native button placement is explicit and writes only to an inert addon-owned control", function()
    local ns,state=fixture();local details=nativePane()
    equal(ns.NativeButtonProbe.frame,nil);equal(ns.NativeButtonProbe.active,nil)
    local originalOpen,originalDetails=QuestMapFrame_OpenToQuestDetails,QuestMapFrame_ShowQuestDetails
    local originalMap=WorldMapFrame.SetMapID
    local anchor=details.TrackButton
    for _,frame in ipairs({WorldMapFrame,details,details.RewardsFrameContainer,details.AbandonButton,details.ShareButton,anchor}) do
        frame.SetPoint=function() error("native anchors must be untouched") end
        frame.SetSize=function() error("native sizes must be untouched") end
        frame.SetWidth=function() error("native widths must be untouched") end
    end
    ns.RunCommand("button")
    local record=ns.DB.records[#ns.DB.records]
    equal(record.kind,"native-button");equal(record.data.status,"display-requested-unverified")
    equal(record.data.nativeIntegrationVerified,false);equal(record.data.clickEnabled,false)
    local button=ns.NativeButtonProbe.frame
    equal(button.parent,UIParent);equal(button.enabled,false);equal(button.mouseEnabled,false)
    equal(button.point[1],"TOPRIGHT");equal(button.point[2],anchor)
    equal(button.point[3],"BOTTOMRIGHT");equal(button.point[5],-6);equal(button.scripts.OnClick,nil)
    equal(QuestMapFrame_OpenToQuestDetails,originalOpen);equal(QuestMapFrame_ShowQuestDetails,originalDetails)
    equal(WorldMapFrame.SetMapID,originalMap);equal(state.mutations,0);equal(#state.drawCalls,0)
end)
test("native button refuses unavailable hidden protected and combat contexts", function()
    for _,case in ipairs({"missing","hidden","protected","combat"}) do
        local ns,state=fixture();local details=case~="missing" and nativePane()
        if case=="hidden" then details:Hide()
        elseif case=="protected" then details.TrackButton.protected=true
        elseif case=="combat" then state.combat=true end
        ns.RunCommand("button");equal(ns.NativeButtonProbe.active,nil);equal(ns.NativeButtonProbe.frame,nil)
        truth(ns.DB.records[#ns.DB.records].data.status~="display-requested-unverified")
        equal(state.mutations,0);equal(#state.drawCalls,0)
    end
end)
test("native button cleanup cannot reappear after clear closure map quest or combat changes", function()
    for _,case in ipairs({"clear","close","map","quest","combat","details"}) do
        local ns,state=fixture();local details=nativePane();ns.RunCommand("button")
        truth(ns.NativeButtonProbe.active)
        if case=="clear" then ns.RunCommand("clear")
        elseif case=="close" then WorldMapFrame:Hide()
        elseif case=="map" then state.mapID=8
        elseif case=="quest" then state.fire("QUEST_LOG_UPDATE")
        elseif case=="combat" then state.combat=true
        else details:Hide() end
        state.update();equal(ns.NativeButtonProbe.active,nil);truth(not ns.NativeButtonProbe.frame:IsShown())
        state.combat=false;WorldMapFrame:Show();details:Show();state.update()
        truth(not ns.NativeButtonProbe.frame:IsShown());equal(state.mutations,0)
    end
end)
test("restricted reads and partial native button construction stay hidden on retry", function()
    local ns,state=fixture();local details=nativePane()
    details.TrackButton.IsProtected=function() error("restricted frame read") end
    ns.RunCommand("button");equal(ns.NativeButtonProbe.frame,nil)
    equal(ns.DB.records[#ns.DB.records].data.status,"error")
    details.TrackButton.IsProtected=function() return false end
    local create=CreateFrame
    CreateFrame=function(...)
        local frame=create(...)
        frame.SetEnabled=function() error("control setup failed") end
        return frame
    end
    ns.RunCommand("button");equal(ns.NativeButtonProbe.active,nil);truth(not ns.NativeButtonProbe.frame:IsShown())
    CreateFrame=create;ns.RunCommand("button")
    equal(ns.DB.records[#ns.DB.records].data.status,"error");truth(not ns.NativeButtonProbe.frame:IsShown())
    equal(state.mutations,0);equal(#state.drawCalls,0)
end)

local function finishSilent(ns,state)
    for _=1,200 do
        if not ns.SilentRegion.active then return end
        local before=state.queryCalls or 0
        state.update()
        truth((state.queryCalls or 0)-before <= ns.SilentRegion.PER_FRAME)
    end
    error("silent fixture did not finish")
end

test("closed-map cold queries never request visible drawing and preserve separated samples", function()
    local ns,state=fixture();WorldMapFrame:Hide();state.hitMode="multi-site"
    ns.Command("silent 42");finishSilent(ns,state)
    local r=ns.SilentRegion.lastResult
    equal(r.status,"closed-map-transparent-hit");equal(r.worldMapShown,false)
    equal(r.visibleDrawingRequested,false);equal(r.absenceEstablished,false)
    equal(r.phases.undrawnBefore.matches,0);equal(r.phases.undrawnAfter.matches,0)
    equal(#r.phases.transparentDrawn.locations,2)
    equal(r.phases.transparentDrawn.locations[2].x,0.75)
    equal(state.queryCalls,3*1089);equal(#state.drawCalls,1)
    equal(state.drawRenders[1].alpha,0);equal(state.drawRenders[1].fill,0)
    equal(state.drawRenders[1].border,0);equal(state.drawRenders[1].parent,UIParent)
    equal(ns.SilentRegion.frame:IsShown(),false);equal(ns.SilentRegion.frame.drawnQuestID,nil)
    equal(WorldMapFrame:IsShown(),false);equal(state.mutations,0)
    equal(ns.DB.records[#ns.DB.records].kind,"silent-region-probe")
end)
test("closed-map misses and contaminated controls preserve uncertainty", function()
    for _,mode in ipairs({"none","always","other"}) do
        local ns,state=fixture();WorldMapFrame:Hide();state.hitMode=mode
        ns.Command("silent 42");finishSilent(ns,state)
        equal(ns.SilentRegion.lastResult.status,mode=="none" and "no-hit-unknown" or "inconclusive-controls")
        equal(ns.SilentRegion.lastResult.absenceEstablished,false);equal(state.mutations,0)
    end
end)
test("closed-map check refuses open map combat unaccepted quests and invalid IDs", function()
    for _,mode in ipairs({"map","combat","removed","invalid"}) do
        local ns,state=fixture()
        if mode~="map" then WorldMapFrame:Hide() end
        if mode=="combat" then state.combat=true end
        if mode=="removed" then C_QuestLog.IsOnQuest=function() return false end end
        ns.Command("silent "..(mode=="invalid" and "oops" or "42"))
        equal(ns.SilentRegion.active,nil);equal(#state.drawCalls,0);equal(state.mutations,0)
    end
end)
test("closed-map checks cancel without resuming after world quest combat clear or map changes", function()
    for _,mode in ipairs({"map","zone","combat","clear","quest","world","preview"}) do
        local ns,state=fixture();WorldMapFrame:Hide();state.hitMode="drawn"
        ns.Command("silent 42");state.update()
        if mode=="map" then WorldMapFrame:Show()
        elseif mode=="zone" then C_Map.GetBestMapForUnit=function() return 8 end
        elseif mode=="combat" then state.combat=true
        elseif mode=="clear" then ns.Command("clear")
        elseif mode=="quest" then state.fire("QUEST_LOG_UPDATE")
        elseif mode=="world" then state.fire("PLAYER_ENTERING_WORLD")
        else ns.Command("area 42 normal multi") end
        state.update();equal(ns.SilentRegion.active,nil)
        equal(ns.SilentRegion.lastResult.status,"cancelled")
        equal(ns.SilentRegion.frame:IsShown(),false);equal(ns.SilentRegion.frame.drawnQuestID,nil)
        local calls=#state.drawCalls;state.update();equal(#state.drawCalls,calls);equal(state.mutations,0)
    end
end)
test("closed-map query errors and unavailable methods clear only owned invisible frames", function()
    for _,mode in ipairs({"error","malformed","missing","unsupported"}) do
        local ns,state=fixture();WorldMapFrame:Hide();state.hitMode=mode
        if mode=="missing" then state.missingMethods.UpdateMouseOverTooltip=true end
        if mode=="unsupported" then state.supported=false end
        ns.Command("silent 42");finishSilent(ns,state)
        equal(ns.SilentRegion.lastResult.status,mode=="missing" and "missing-api" or "error")
        equal(ns.SilentRegion.active,nil);equal(WorldMapFrame:IsShown(),false);equal(state.mutations,0)
    end
end)

io.write(string.format("%d diagnostic fixture tests passed; %d failed. No in-game verification.\n", passed, failed))
if failed > 0 then os.exit(1) end
