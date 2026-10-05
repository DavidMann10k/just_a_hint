local _, NS = ...
local Tracker = {}
NS.NativeTracker = Tracker

function Tracker.Check()
    local ok, available = pcall(function()
        local frame = ObjectiveTrackerFrame
        return frame and type(frame.GetParent) == "function" and type(frame.SetParent) == "function"
            and type(frame.IsVisible) == "function" or false
    end)
    return ok and available == true, "Blizzard quest tracker unavailable."
end

function Tracker.Apply()
    -- Parenting under a hidden frame also covers native Show calls in combat.
    -- Preserve native events, handlers, anchors and the frame's own shown state.
    if NS.InCombat() then return true end
    local supported, reason = Tracker.Check()
    if not supported then return false, reason end
    local ok, err = pcall(function()
        local frame = ObjectiveTrackerFrame
        if Tracker.saved and Tracker.saved.frame ~= frame then error("Blizzard quest tracker changed.") end
        if not Tracker.hidden then
            Tracker.hidden = CreateFrame("Frame", nil, UIParent)
            Tracker.hidden:Hide()
            Tracker.hidden:SetAllPoints(UIParent)
        end
        if not Tracker.saved then Tracker.saved = { frame = frame, parent = frame:GetParent() } end
        if frame:GetParent() ~= Tracker.hidden then frame:SetParent(Tracker.hidden) end
        if frame:GetParent() ~= Tracker.hidden or frame:IsVisible() then
            error("Blizzard quest tracker could not be hidden.")
        end
    end)
    NS.Note("nativeTracker", ok and "hidden" or tostring(err))
    return ok, not ok and tostring(err) or nil
end

function Tracker.Restore()
    if not Tracker.saved then return true end
    if NS.InCombat() then return false, "Restore the Blizzard quest tracker out of combat." end
    local ok, err = pcall(function()
        local saved = Tracker.saved
        -- A subsequent addon reparenting the tracker owns its new placement.
        if saved.frame:GetParent() == Tracker.hidden then
            saved.frame:SetParent(saved.parent)
            if saved.frame:GetParent() ~= saved.parent then error("Blizzard quest tracker restoration failed.") end
        end
        Tracker.saved = nil
    end)
    NS.Note("nativeTracker", ok and "restored" or tostring(err))
    return ok, not ok and tostring(err) or nil
end
