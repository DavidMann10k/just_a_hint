local _, NS = ...
local Tracker = {}
NS.NativeTracker = Tracker

function Tracker.Check()
    local ok, available = pcall(function()
        local frame = ObjectiveTrackerFrame
        return frame and type(frame.IsVisible) == "function" or false
    end)
    return ok and available == true, "Blizzard quest tracker unavailable."
end

-- The client's questPOI setting controls its guidance buttons. Keep the list,
-- item buttons, layout and quest-click handlers entirely owned by Blizzard.
function Tracker.Visible()
    local ok, visible = pcall(function()
        return ObjectiveTrackerFrame:IsVisible()
    end)
    if ok and type(visible) == "boolean" then return visible end
end
