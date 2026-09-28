local _, NS = ...
local Hints = { controller = NS.HintController.New(150, 1) }
NS.Hints = Hints

function Hints.Availability(id)
    if not NS.ID(id) then return "hidden" end
    local sample, reason = NS.HintData.Snapshot(id)
    if sample then return "ready" end
    if reason == "loading" then return "loading" end
    if reason == "unavailable" then return "pending" end
    return "hidden"
end

function Hints.UpdateButton(button, id)
    local state = Hints.Availability(id)
    if state == "ready" and Hints.active and Hints.active.id == id and Hints.active.pending then state = "loading" end
    if state == "ready" and NS.Area and NS.Area.active and NS.Area.active.id == id
        and NS.Area.active.presentation == "checking" then state = "loading" end
    button:SetShown(state ~= "hidden")
    button:SetEnabled(state == "ready" and NS.Guard.active and not NS.Guard.problem)
    button:SetText(state == "ready" and Hints.HasVisibleHint(id) and "Clear Hint"
        or state == "loading" and "Loading hint…" or "Hint")
    button.hintState = state
    return state
end

function Hints.HasVisibleHint(id)
    if not Hints.active or Hints.active.id ~= id or not Hints.controller.visible then return false end
    if Hints.controller.mode == "bearing" then
        return NS.Bearing.frame ~= nil and NS.Bearing.frame:IsVisible() == true
    end
    if Hints.controller.mode == "area" then
        return NS.Area and NS.Area.IsVisible and NS.Area.IsVisible(id) == true or false
    end
    return false
end

function Hints.Toggle(id, onReady)
    if Hints.HasVisibleHint(id) then
        Hints.Clear("cleared")
        return "cleared"
    end
    Hints.Request(id, onReady)
    return "requested"
end

local messages = {
    removed = "This quest is no longer in your log.",

    ["other-map"] = "Direction hints currently work only on your current map.",
    ["no-destination"] = "A clear direction is unavailable for this quest here.",
    loading = "Quest data is still loading. Try Hint again shortly.",
    unavailable = "Quest or location data is unavailable. Try Hint again shortly.",
}

function Hints.Clear(reason)
    Hints.controller:Clear(reason)
    Hints.active = nil
    if NS.RegionHints then NS.RegionHints.Clear() end
    NS.Bearing.Hide()
    if NS.Area then NS.Area.Clear() end
    NS.Note("hint", reason or "cleared")
    if NS.NativeMarkers then NS.NativeMarkers.Clear() end
    if NS.SettingsPanel then NS.SettingsPanel.UpdateState() end
end

local function failure(id, reason, message)
    Hints.Clear(reason)
    NS.Message(message)
end

local function suspend()
    if Hints.active then Hints.active.bearingSample = nil end
    Hints.controller:Update(nil)
    NS.Bearing.Hide()
    if Hints.controller.mode == "area" and NS.Area and not NS.Area.Suspend() then
        Hints.Clear("area-renderer-unavailable")
    end
end

local function render(sample)
    local active = Hints.active
    if not active or active.starting or Hints.controller.mode ~= "bearing" then return true end
    if not NS.Guard.active or NS.Guard.problem then Hints.Clear("guidance-controls-inactive"); return false end
    if not Hints.controller.visible then return true end
    -- Only validated data may authorize a bearing. Between data checks, rotate
    -- that same bearing with the live heading without querying quest/location data.
    sample = sample or active.bearingSample
    if not sample then return true end
    active.bearingSample = sample
    local facing = NS.HintData.Facing()
    if facing == nil then Hints.controller:Update(nil); NS.Bearing.Hide(); return true end
    local east = sample.player.y - active.target.y
    local north = active.target.x - sample.player.x
    local x, y = NS.HintController.ScreenDirection(east, north, facing)
    if not x then NS.Bearing.Hide(); return true end
    if NS.Feedback then NS.Feedback.x, NS.Feedback.y = x, y end
    local shown, err = NS.Bearing.Show(x, y)
    if not shown then
        failure(active.id, "renderer-unavailable", "The direction hint could not be displayed. Use /jah status for details.")
        NS.Note("bearingError", err)
    end
    return shown
end

local function disclose(id, sample, region, onReady)
    local mode = Hints.controller:Request(id, sample.distance, GetTime())
    NS.Note("hintQuest", id)
    NS.Note("hintSource", sample.destination.source)
    NS.Note("hintPhase", sample.phase or "objective")
    NS.Note("hintProximity", region and "confirmed native samples and player hit query; approximate boundaries" or "native point distance")
    NS.Note("arrivalTuning", "150 native world units / 1 second; game-yard equivalence unverified")
    if mode ~= "bearing" and mode ~= "area" then Hints.Clear("proximity-unavailable");return end
    local active = { id = id, mapID = sample.mapID, stage = sample.stage, phase = sample.phase,
        target = sample.target, source = sample.destination.source, region = region, starting = true }
    Hints.active = active
    if mode == "area" then
        if not NS.Area then
            failure(id, "area-module-unavailable", "Restart the beta to load the area hint update.")
            return
        end
        local shown, err = NS.Area.Show(id, sample.mapID, sample.destination)
        active.starting = nil
        if not shown then failure(id, "area-unavailable", err); return end
        if Hints.active ~= active or not NS.Guard.active or NS.Guard.problem then
            Hints.Clear("area-request-cancelled"); return
        end
        NS.Note("hint", "area requested")
        NS.SettingsPanel.UpdateState()
        return
    end
    active.starting = nil
    if not render(sample) then return end
    if NS.Feedback then NS.Feedback.BearingRequested(sample) end
    NS.Note("hint", "bearing requested")
    NS.SettingsPanel.UpdateState()
    if onReady then onReady() end
end

function Hints.Request(id, onReady)
    -- A request for another quest replaces the old hint even if data is missing.
    Hints.Clear("new-request")
    if not NS.ID(id) then return end
    if not NS.Guard.active or NS.Guard.problem then
        failure(id, "guidance-controls-inactive", "Start Just a Hint before requesting a hint."); return
    end
    local sample, reason = NS.HintData.Snapshot(id)
    if not sample then failure(id, reason, messages[reason] or messages.unavailable); return end
    if NS.RegionHints and sample.phase ~= "turn-in" then
        local pending = { id=id,mapID=sample.mapID,stage=sample.stage,pending=true }
        Hints.active=pending
        local started=NS.RegionHints.Start(id,sample,function(region)
            if Hints.active~=pending or not NS.Guard.active or NS.Guard.problem then return end
            if NS.InCombat() then Hints.Clear("request-combat-started");return end
            local fresh,why=NS.HintData.Snapshot(id)
            if not fresh or fresh.stage~=pending.stage or fresh.mapID~=pending.mapID then
                Hints.Clear(why or "quest-step-changed");return
            end
            if region then
                local choice=NS.RegionHints.Nearest(region,fresh.player)
                local distance=NS.RegionHints.Distance(region,fresh)
                if not choice or not distance then Hints.Clear("region-position-unavailable");return end
                fresh.target,fresh.destination,fresh.distance=choice.world,choice.point,distance
            end
            disclose(id,fresh,region,onReady)
        end)
        if started then NS.Note("hint","checking native regions");return end
        Hints.active=nil -- Failure may use only this explicit request's native point.
    end
    disclose(id,sample,nil,onReady)
end

function Hints.Update()
    local active = Hints.active
    if not active then return end
    if not NS.Guard.active or NS.Guard.problem then Hints.Clear("guidance-controls-inactive"); return end
    if active.pending then
        if NS.InCombat() then Hints.Clear("request-combat-started");return end
        local sample,why=NS.HintData.Snapshot(active.id)
        if not sample or sample.mapID~=active.mapID or sample.stage~=active.stage then
            Hints.Clear(why or "quest-step-changed")
        end
        return -- Query completion alone may disclose this still-current request.
    end
    if active.starting then return end -- Map opening can synchronously dispatch UI events.
    if Hints.controller.mode == "area" then
        local valid, why = NS.Area.Check()
        if not valid then Hints.Clear(why); return end
    end
    -- Detect leaving the map even when that map has no point for this quest.
    local mapID = NS.HintData.CurrentMap()
    if mapID and mapID ~= active.mapID then Hints.Clear("map-changed"); return end
    if not mapID then suspend(); return end
    local sample, reason, observedStage = NS.HintData.Snapshot(active.id)
    -- Completion clears the objective request even before turn-in location data
    -- becomes available. A new Hint is required to authorize that next phase.
    if observedStage and observedStage ~= active.stage then Hints.Clear("quest-step-changed"); return end
    if not sample then
        if reason == "removed" or reason == "complete" or reason == "other-map" then Hints.Clear(reason)
        else suspend() end
        return
    end
    if sample.mapID ~= active.mapID then Hints.Clear("map-changed"); return end
    if sample.stage ~= active.stage then Hints.Clear("quest-step-changed"); return end
    local shift = active.region and 0 or NS.HintData.Distance(active.target, sample.target)
    if not shift or (not active.region and sample.destination.source ~= active.source) then Hints.Clear("destination-changed"); return end
    if shift > 5 then
        -- Hide on the first changed point. Require two consistent readings to
        -- discard the request; a single transient point must not guide us.
        local confirmed = active.changedPoint and NS.HintData.Distance(active.changedPoint, sample.target)
        if confirmed and confirmed <= 1 then Hints.Clear("destination-changed")
        else active.changedPoint = sample.target; suspend() end
        return
    end
    active.changedPoint = nil
    if Hints.controller.mode == "area" then
        local shown, why = NS.Area.Update()
        if not shown then failure(active.id, why, "The area hint is unavailable now. Try Hint again.") end
        return -- Neither walking away nor missing facing changes an area to a bearing.
    end
    local distance
    if active.region then distance=NS.RegionHints.Distance(active.region,sample)
    else distance=NS.HintData.Distance(sample.player,active.target) end
    -- Missing facing interrupts the arrival dwell too.
    if NS.HintData.Facing() == nil then distance = nil end
    Hints.controller:Update(distance, GetTime())
    if Hints.controller.mode == "none" then Hints.Clear("arrived"); return end
    if not Hints.controller.visible then NS.Bearing.Hide(); return end
    render(sample)
end

local ticker, elapsed = CreateFrame("Frame"), 0
ticker:SetScript("OnUpdate", function(_, dt)
    if not Hints.active then elapsed = 0; return end
    elapsed = elapsed + dt
    if elapsed >= 0.1 then
        elapsed = 0
        Hints.Update() -- Validate lifecycle before rendering on a data-check frame.
    else
        render() -- Live rotation on every other frame; never acquires guidance.
    end
end)
