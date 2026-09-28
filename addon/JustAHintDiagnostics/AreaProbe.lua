local _, NS = ...
local Area = {}
NS.Area = Area

function Area.Clear(reason)
    if NS.SilentRegion then NS.SilentRegion.Finish("cancelled", reason or "manual") end
    local previous = Area.active
    Area.active = nil
    if NS.Region and NS.Region.active then NS.Region.Cancel(reason or "manual") end
    if Area.frame then
        pcall(function() Area.frame:DrawNone() end)
        Area.frame:Hide()
    end
    if previous then
        Area.clearReason = reason or "manual"
        if previous.recordID then
            NS.Record("area-cleared", { areaRecordID = previous.recordID,
                questID = previous.questID, mapID = previous.mapID, reason = Area.clearReason })
        end
        if NS.AreaPanel then NS.AreaPanel.Refresh() end
    end
end

local function mapContext()
    local map = WorldMapFrame
    if not map or type(map.IsShown) ~= "function" or not map:IsShown() then
        return nil, "open-world-map-manually"
    end
    if type(map.GetMapID) ~= "function" or type(map.GetCanvas) ~= "function" then
        return nil, "map-canvas-api-unavailable"
    end
    local mapID, canvas = map:GetMapID(), map:GetCanvas()
    if not NS.ID(mapID) or not canvas then return nil, "map-context-unavailable" end
    return { map = map, mapID = mapID, canvas = canvas }
end

function Area.Show(questID, phase, category, note)
    Area.Clear("new-request")
    local result = { questID = questID, context = NS.Adapter.Context(phase, category, note),
        accepted = NS.Adapter.Accepted(questID), visualResult = "unverified" }
    Area.lastResult = result
    Area.clearReason = nil
    if result.accepted.status ~= "ok" or result.accepted.value ~= true then
        result.status = "accepted-quest-not-confirmed"
        return result
    end
    if InCombatLockdown and InCombatLockdown() then
        result.status = "unavailable-in-combat"
        return result
    end
    local ok, status = pcall(function()
        local context, reason = mapContext()
        if not context then return reason end
        result.mapID = context.mapID
        local width, height = context.canvas:GetWidth(), context.canvas:GetHeight()
        if not NS.Number(width) or not NS.Number(height) or width <= 0 or height <= 0 then
            return "invalid-canvas-size"
        end
        -- Use the map's own layer definition rather than placing a blob under
        -- its art layers or guessing an absolute pin level.
        local levels = context.map.pinFrameLevelsManager
        if not levels or type(levels.GetValidFrameLevel) ~= "function" then
            return "map-frame-level-api-unavailable"
        end
        local frameLevel = levels:GetValidFrameLevel("PIN_FRAME_LEVEL_QUEST_BLOB")
        if not NS.Number(frameLevel) or frameLevel < 0 or frameLevel % 1 ~= 0 then
            return "invalid-map-frame-level"
        end
        result.frameLevel = frameLevel
        if not Area.frame then
            -- No Blizzard template/mixin: its OnShow would read supertracking.
            local frame = CreateFrame("QuestPOIFrame", nil, context.canvas)
            frame:Hide()
            Area.frame = frame
        end
        local frame = Area.frame
        result.methods = {}
        for _, method in ipairs({ "DrawBlob", "DrawNone", "SetMapID", "SetFillTexture",
            "SetBorderTexture", "SetFillAlpha", "SetBorderAlpha", "SetBorderScalar" }) do
            result.methods[method] = type(frame[method]) == "function"
            if not result.methods[method] then return "missing-blob-method:" .. method end
        end
        frame:SetParent(context.canvas)
        frame:ClearAllPoints()
        frame:SetAllPoints(context.canvas)
        frame:SetFrameLevel(frameLevel)
        frame:EnableMouse(false)
        frame:SetFillTexture("Interface\\WorldMap\\UI-QuestBlob-Inside")
        frame:SetBorderTexture("Interface\\WorldMap\\UI-QuestBlob-Outside")
        -- This is a visibility test, not the product's final visual treatment.
        frame:SetFillAlpha(255)
        frame:SetBorderAlpha(255)
        frame:SetBorderScalar(2.0)
        frame:DrawNone()
        frame:SetMapID(context.mapID)
        frame:SetScript("OnHide", function(self)
            if Area.active then Area.Clear("map-or-frame-hidden") end
        end)
        frame:SetScript("OnUpdate", function(_, elapsed)
            local active = Area.active
            if not active then return end
            local valid, current = pcall(mapContext)
            if not valid or not current or current.mapID ~= active.mapID
                or current.canvas ~= active.canvas then
                Area.Clear("map-context-changed")
                return
            end
            -- Blob geometry depends on canvas dimensions/scale. Clear the preview
            -- when these change; a fresh explicit probe can recreate it.
            if current.canvas:GetWidth() ~= active.width or current.canvas:GetHeight() ~= active.height
                or current.canvas:GetEffectiveScale() ~= active.scale then Area.Clear("canvas-changed"); return end
            if NS.Region and NS.Region.active then NS.Region.Update(elapsed) end
        end)
        frame:Show()
        frame:DrawBlob(questID, true)
        Area.active = { questID = questID, mapID = context.mapID, canvas = context.canvas,
            width = context.canvas:GetWidth(), height = context.canvas:GetHeight(),
            scale = context.canvas:GetEffectiveScale() }
        result.render = { fillAlpha = 255, borderAlpha = 255, borderScalar = 2.0,
            canvasWidth = width, canvasHeight = height, canvasScale = Area.active.scale,
            blobWidth = frame:GetWidth(), blobHeight = frame:GetHeight(), frameShown = frame:IsShown() }
        -- No documented return here establishes whether a visible native region exists.
        return "call-ok-unverified"
    end)
    result.status = ok and status or "error"
    if not ok then result.detail = tostring(status) end
    if result.status ~= "call-ok-unverified" then Area.Clear("probe-failed") end
    return result
end

-- Explicit, bounded experiment: query the same grid with this frame's region
-- undrawn, visibly drawn, zero-alpha drawn, then undrawn again. Recorded grid
-- hits are coarse samples, not polygons or objective identities. A miss is unknown.
local Region = { GRID = 32, PER_FRAME = 64, SETTLE = 0.15 }
NS.Region = Region
local phases = { "hiddenBefore", "drawn", "transparentDrawn", "hiddenAfter" }

local function finishRegion(status, reason)
    local active = Region.active
    if not active then return end
    Region.active = nil
    local result = active.result
    result.status, result.reason = status, reason
    result.previewRestored = false
    if Area.active == active.preview then
        -- Restore only the same still-authorized diagnostic preview.
        local restored, err = pcall(function()
            Area.frame:SetFillAlpha(255)
            Area.frame:SetBorderAlpha(255)
            Area.frame:DrawBlob(result.questID, true)
        end)
        result.previewRestored = restored
        if not restored then result.restoreError = tostring(err); Area.Clear("region-restore-failed") end
    end
    Region.lastResult = result
    local record = NS.Record("region-probe", result)
    Region.lastRecordID = record.id
    NS.Print("Region check #" .. record.id .. ": " .. status .. ". A missed sample does not prove no area exists.")
    if NS.AreaPanel then NS.AreaPanel.Refresh() end
end

function Region.Cancel(reason)
    finishRegion("cancelled", reason)
end

local function regionPhase(active, phase)
    active.phase, active.index, active.wait = phase, 0, Region.SETTLE
    active.result.phases[phases[phase]] = { samples = 0, matches = 0, otherQuests = 0, locations = {} }
    Area.frame:DrawNone()
    Area.frame:SetFillAlpha(phase == 3 and 0 or 255)
    Area.frame:SetBorderAlpha(phase == 3 and 0 or 255)
    if phase == 2 or phase == 3 then Area.frame:DrawBlob(active.result.questID, true) end
end

function Region.Start()
    if Region.active then NS.Print("The region check is already running."); return end
    local preview = Area.active
    if not preview then NS.Print("Open a diagnostic area preview first, then press Check region data."); return end
    if InCombatLockdown and InCombatLockdown() then NS.Print("Leave combat before checking region data."); return end
    local result = {
        questID = preview.questID, mapID = preview.mapID, areaRecordID = preview.recordID,
        method = "QuestPOIFrame.UpdateMouseOverTooltip",
        gridIntervals = Region.GRID, samplesPerPhase = (Region.GRID + 1)^2,
        maxCallsPerFrame = Region.PER_FRAME, settleSeconds = Region.SETTLE,
        phases = {}, visualResult = "unverified", absenceEstablished = false,
        spatialSamplesAreApproximate = true,
        questProbe = NS.Adapter.Probe(preview.questID, nil, "multi", "region spatial comparison"),
        context = Area.lastResult and Area.lastResult.context,
        cache = NS.Read("HaveQuestData", NS.Scalar, preview.questID),
        playerInsideRegion = NS.Read("C_Minimap.IsInsideQuestBlob", NS.Scalar, preview.questID),
    }
    Region.lastResult, Region.lastRecordID = nil, nil
    Region.active = { result = result, preview = preview }
    if type(Area.frame.UpdateMouseOverTooltip) ~= "function" then
        finishRegion("missing-api"); return
    end
    local ok, err = pcall(regionPhase, Region.active, 1)
    if not ok then finishRegion("error", tostring(err)); return end
    if NS.AreaPanel then NS.AreaPanel.Refresh() end
end

function Region.Update(elapsed)
    local active = Region.active
    if not active then return end
    if Area.active ~= active.preview then Region.Cancel("preview-changed"); return end
    if InCombatLockdown and InCombatLockdown() then
        Area.Clear("region-combat-started"); return
    end
    if not NS.Number(elapsed) or elapsed < 0 then return end
    active.wait = active.wait - elapsed
    if active.wait > 0 then return end
    local ok, err = pcall(function()
        local phase = active.result.phases[phases[active.phase]]
        local maximum = active.result.samplesPerPhase
        for _ = 1, Region.PER_FRAME do
            if active.index >= maximum then break end
            local x = (active.index % (Region.GRID + 1)) / Region.GRID
            local y = math.floor(active.index / (Region.GRID + 1)) / Region.GRID
            local id, count = Area.frame:UpdateMouseOverTooltip(x, y)
            if id ~= nil and id ~= 0 and not NS.ID(id) then error("invalid-query-quest-id") end
            if count ~= nil and (not NS.Number(count) or count < 0 or count % 1 ~= 0) then
                error("invalid-query-objective-count")
            end
            phase.samples = phase.samples + 1
            if id == active.result.questID then
                phase.matches = phase.matches + 1
                phase.locations[#phase.locations + 1] = { x = x, y = y, objectiveCount = count }
            elseif id ~= nil and id ~= 0 then phase.otherQuests = phase.otherQuests + 1 end
            active.index = active.index + 1
        end
        if active.index < maximum then return end
        if active.phase < #phases then regionPhase(active, active.phase + 1); return end
        local before, drawn, after = active.result.phases.hiddenBefore, active.result.phases.drawn,
            active.result.phases.hiddenAfter
        local transparent = active.result.phases.transparentDrawn
        local controlsClean = before.matches == 0 and after.matches == 0
            and before.otherQuests == 0 and drawn.otherQuests == 0 and after.otherQuests == 0
            and transparent.otherQuests == 0
        local status = not controlsClean and "inconclusive-controls"
            or (drawn.matches > 0 and "draw-dependent-hit" or "no-hit-unknown")
        active.result.transparentQueryResult = not controlsClean and "inconclusive-controls"
            or (drawn.matches == 0 and "no-visible-hit-unknown"
            or (transparent.matches > 0 and "transparent-drawn-hit" or "transparent-no-hit-unknown"))
        finishRegion(status)
    end)
    if not ok then finishRegion("error", tostring(err)) end
end

-- A disposable comparison on one open map, not the product's spoiler guard.
-- These are the exact templates used by Blizzard's quest data providers.
local Isolation = {}
NS.Isolation = Isolation
local questTemplates = { "QuestPinTemplate", "QuestBlobPinTemplate" }

local function questPins(map)
    if type(map.EnumeratePinsByTemplate) ~= "function" then error("pin-enumeration-unavailable") end
    local pins, counts = {}, {}
    for _, template in ipairs(questTemplates) do
        counts[template] = 0
        for pin in map:EnumeratePinsByTemplate(template) do
            if type(pin.IsShown) ~= "function" or type(pin.Hide) ~= "function"
                or type(pin.Show) ~= "function" or type(pin.IsProtected) ~= "function" then
                error("pin-visibility-api-unavailable")
            end
            if pin:IsProtected() then error("protected-quest-pin") end
            pins[pin] = { shown = pin:IsShown(), template = template }
            counts[template] = counts[template] + 1
        end
    end
    return pins, counts
end

function Isolation.Snapshot()
    local active = Isolation.active
    if not active then return { status = "inactive" } end
    return { status = "frames-hidden-unverified", scope = "world-map-quest-frames-only",
        recordID = active.recordID, mapID = active.mapID, templateCounts = active.counts }
end

function Isolation.Stop(reason)
    local active = Isolation.active
    if not active then return end
    Isolation.active = nil
    if Isolation.frame then Isolation.frame:Hide() end
    Area.Clear("isolation-ended")
    -- Restore only still-active pool members. Never show a released/stale pin.
    local ok, detail = pcall(function()
        local current = questPins(active.map)
        for pin, state in pairs(active.pins) do
            if current[pin] and current[pin].template == state.template and state.shown then pin:Show() end
        end
    end)
    local record = NS.Record("isolation-ended", { isolationRecordID = active.recordID,
        reason = reason or "manual", status = ok and "restore-called" or "restore-failed",
        detail = not ok and tostring(detail) or nil })
    NS.Print("Map comparison ended: " .. (reason or "manual") .. "; capture #" .. record.id .. ".")
    if not ok then NS.Print("Could not restore quest frames. /reload restores the original UI; no settings were changed.") end
    if NS.AreaPanel then
        NS.AreaPanel.Refresh()
        if NS.AreaPanel.picker then NS.AreaPanel.RefreshQuests(false) end
    end
end

function Isolation.Check()
    local active = Isolation.active
    if not active then return end
    local ok, reason = pcall(function()
        if not active.map:IsShown() or active.map:GetMapID() ~= active.mapID then return "map-changed" end
        if InCombatLockdown and InCombatLockdown() then return "combat-started" end
        local cvar = NS.Read("C_CVar.GetCVar", NS.Scalar, "questPOI")
        if cvar.status ~= "ok" or cvar.value ~= "1" then return "questPOI-changed" end
        local current = questPins(active.map)
        for _, state in pairs(current) do
            if state.shown then return "default-quest-frame-reappeared" end
        end
    end)
    if not ok then Isolation.Stop("verification-failed:" .. tostring(reason))
    elseif reason then Isolation.Stop(reason) end
end

function Isolation.Start()
    Isolation.Stop("new-comparison")
    local result = { scope = "world-map-quest-frames-only",
        questPOI = NS.Read("C_CVar.GetCVar", NS.Scalar, "questPOI") }
    if result.questPOI.status ~= "ok" or result.questPOI.value ~= "1" then
        result.status = "requires-questPOI-1"
        return result
    end
    if InCombatLockdown and InCombatLockdown() then result.status = "unavailable-in-combat"; return result end
    local ok, status = pcall(function()
        local context, reason = mapContext()
        if not context then return reason end
        result.mapID = context.mapID
        local pins, counts = questPins(context.map)
        result.templateCounts = counts
        if counts.QuestPinTemplate == 0 or counts.QuestBlobPinTemplate == 0 then
            return "quest-pin-templates-not-populated"
        end
        Area.Clear("isolation-started")
        Isolation.active = { map = context.map, mapID = context.mapID, pins = pins, counts = counts }
        for pin, state in pairs(pins) do if state.shown then pin:Hide() end end
        if not Isolation.frame then
            local frame = CreateFrame("Frame")
            frame:Hide()
            frame:SetScript("OnUpdate", Isolation.Check)
            frame:SetScript("OnHide", function() Isolation.Stop("map-closed") end)
            Isolation.frame = frame
        end
        Isolation.frame:SetParent(context.map)
        Isolation.frame:Show()
        return "frames-hidden-unverified"
    end)
    result.status = ok and status or "error"
    if not ok then result.detail = tostring(status) end
    if result.status ~= "frames-hidden-unverified" then Isolation.Stop("start-failed") end
    return result
end

-- Explicit cold-start experiment. This dedicated frame never receives visible
-- artwork: opacity and both blob alphas are zero before the first DrawBlob.
-- It observes the player's current map without opening or selecting native UI.
local Silent = { GRID = 32, PER_FRAME = 64, SETTLE = 0.15 }
NS.SilentRegion = Silent
local silentPhases = { "undrawnBefore", "transparentDrawn", "undrawnAfter" }

function Silent.Finish(status, reason)
    local active = Silent.active
    if not active then return end
    Silent.active = nil
    active.result.status, active.result.reason = status, reason
    if Silent.frame then
        pcall(function() Silent.frame:DrawNone(); Silent.frame:Hide() end)
    end
    Silent.lastResult = active.result
    local record = NS.Record("silent-region-probe", active.result)
    NS.Print("Invisible closed-map check #" .. record.id .. ": " .. status .. ".")
    NS.Print("No visible drawing requested. Report any flash; /reload saves this capture.")
end

local function silentPhase(active, index)
    active.phase, active.index, active.wait = index, 0, Silent.SETTLE
    active.result.phases[silentPhases[index]] = { samples = 0, matches = 0, otherQuests = 0, locations = {} }
    Silent.frame:DrawNone()
    if index == 2 then Silent.frame:DrawBlob(active.result.questID, true) end
end

function Silent.Start(id)
    if Silent.active then NS.Print("The invisible check is already running."); return end
    if not NS.ID(id) then NS.Print("Usage: /jahdiag silent QUEST_ID (with the world map closed)"); return end
    -- End earlier explicit previews; never hide or reopen Blizzard's map here.
    Area.Clear("silent-check-started")
    local result = { questID = id, method = "QuestPOIFrame.UpdateMouseOverTooltip",
        context = NS.Adapter.Context(nil, "multi", "closed-map zero-alpha-only comparison"),
        questProbe = NS.Adapter.Probe(id, nil, "multi", "closed-map zero-alpha-only comparison"),
        gridIntervals = Silent.GRID, samplesPerPhase = (Silent.GRID + 1)^2,
        maxCallsPerFrame = Silent.PER_FRAME, settleSeconds = Silent.SETTLE,
        phases = {}, spatialSamplesAreApproximate = true, absenceEstablished = false,
        visibleDrawingRequested = false, visualResult = "unverified" }
    Silent.active = { result = result }
    local ok, err = pcall(function()
        if InCombatLockdown and InCombatLockdown() then Silent.Finish("unavailable-in-combat"); return end
        result.worldMapShown = WorldMapFrame and WorldMapFrame:IsShown() or false
        if result.worldMapShown then Silent.Finish("close-world-map-first"); return end
        if result.questProbe.accepted.status ~= "ok" or result.questProbe.accepted.value ~= true then
            Silent.Finish("accepted-quest-not-confirmed"); return
        end
        local map = NS.Read("C_Map.GetBestMapForUnit", NS.Scalar, "player")
        if map.status ~= "ok" or not NS.ID(map.value) then Silent.Finish("player-map-unavailable"); return end
        result.mapID = map.value
        if not Silent.frame then
            local frame = CreateFrame("QuestPOIFrame", nil, UIParent)
            Silent.frame = frame
            frame:Hide()
            frame:SetAlpha(0)
            frame:SetFillAlpha(0); frame:SetBorderAlpha(0)
            frame:EnableMouse(false)
            frame:SetSize(1002, 668)
            frame:SetPoint("CENTER", UIParent, "CENTER")
            frame:SetFillTexture("Interface\\WorldMap\\UI-QuestBlob-Inside")
            frame:SetBorderTexture("Interface\\WorldMap\\UI-QuestBlob-Outside")
            frame:SetBorderScalar(2)
            frame:SetScript("OnUpdate", function(_, elapsed) Silent.Update(elapsed) end)
            frame.ready = true
        end
        local frame = Silent.frame
        if not frame.ready or type(frame.UpdateMouseOverTooltip) ~= "function" then
            Silent.Finish("missing-api"); return
        end
        result.render = { frameAlpha = 0, fillAlpha = 0, borderAlpha = 0,
            width = frame:GetWidth(), height = frame:GetHeight(), parent = "UIParent" }
        frame:DrawNone(); frame:SetMapID(result.mapID)
        silentPhase(Silent.active, 1)
        frame:Show()
        NS.Print("Invisible closed-map check running; leave the map closed and stay out of combat.")
    end)
    if not ok then Silent.Finish("error", tostring(err)) end
end

function Silent.Update(elapsed)
    local active = Silent.active
    if not active or not NS.Number(elapsed) or elapsed < 0 then return end
    local ok, err = pcall(function()
        if InCombatLockdown and InCombatLockdown() then Silent.Finish("cancelled", "combat-started"); return end
        if WorldMapFrame and WorldMapFrame:IsShown() then Silent.Finish("cancelled", "world-map-opened"); return end
        local map = NS.Read("C_Map.GetBestMapForUnit", NS.Scalar, "player")
        if map.status ~= "ok" or map.value ~= active.result.mapID then
            Silent.Finish("cancelled", "player-map-changed"); return
        end
        active.wait = active.wait - elapsed
        if active.wait > 0 then return end
        local phase = active.result.phases[silentPhases[active.phase]]
        for _ = 1, Silent.PER_FRAME do
            if active.index >= active.result.samplesPerPhase then break end
            local x = (active.index % (Silent.GRID + 1)) / Silent.GRID
            local y = math.floor(active.index / (Silent.GRID + 1)) / Silent.GRID
            local id, count = Silent.frame:UpdateMouseOverTooltip(x, y)
            if id ~= nil and id ~= 0 and not NS.ID(id) then error("invalid-query-quest-id") end
            if count ~= nil and (not NS.Number(count) or count < 0 or count % 1 ~= 0) then
                error("invalid-query-objective-count")
            end
            phase.samples = phase.samples + 1
            if id == active.result.questID then
                phase.matches = phase.matches + 1
                phase.locations[#phase.locations + 1] = { x = x, y = y, objectiveCount = count }
            elseif id ~= nil and id ~= 0 then phase.otherQuests = phase.otherQuests + 1 end
            active.index = active.index + 1
        end
        if active.index < active.result.samplesPerPhase then return end
        if active.phase < #silentPhases then silentPhase(active, active.phase + 1); return end
        local before, drawn, after = active.result.phases.undrawnBefore,
            active.result.phases.transparentDrawn, active.result.phases.undrawnAfter
        local clean = before.matches == 0 and after.matches == 0 and before.otherQuests == 0
            and drawn.otherQuests == 0 and after.otherQuests == 0
        Silent.Finish(not clean and "inconclusive-controls"
            or (drawn.matches > 0 and "closed-map-transparent-hit" or "no-hit-unknown"))
    end)
    if not ok then Silent.Finish("error", tostring(err)) end
end
