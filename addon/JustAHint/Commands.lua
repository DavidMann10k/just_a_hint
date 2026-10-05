local addonName, NS = ...

local function report()
    local lines = { "Just a Hint " .. NS.VERSION .. " preview" }
    local ok, version, build, _, interface = NS.Call("GetBuildInfo")
    lines[#lines + 1] = "Build: " .. (ok and table.concat({tostring(version), tostring(build), tostring(interface)}, " / ") or "unavailable")
    lines[#lines + 1] = "Enabled: " .. tostring(NS.DB.enabled == true)
    lines[#lines + 1] = "Controls active: " .. tostring(NS.Guard.active)
    local trackerVisible = NS.NativeTracker and NS.NativeTracker.Visible()
    lines[#lines + 1] = "Native quest list visible: " .. (trackerVisible == nil and "unavailable" or tostring(trackerVisible))
    lines[#lines + 1] = "Native pane: " .. tostring(NS.NativePane and NS.NativePane.problem or "available or not yet loaded")
    lines[#lines + 1] = "Native observer: " .. tostring(NS.NativePane and NS.NativePane.observer and NS.NativePane.observer:IsShown() or false)
    lines[#lines + 1] = "Native Hint control: " .. tostring(NS.NativePane and NS.NativePane.active ~= nil)
    lines[#lines + 1] = "Native hint markers: " .. tostring(NS.NativeMarkers and NS.NativeMarkers.count or 0)
    for _, record in ipairs(NS.DB.securityEvents or {}) do
        lines[#lines + 1] = "Client restriction (" .. tostring(record.version) .. "): " .. tostring(record.event)
            .. " — " .. table.concat(record.arguments or {}, " / ")
    end
    lines[#lines + 1] = "Control error: " .. tostring(NS.Guard.problem or "none")
    lines[#lines + 1] = "Hint modules: " .. tostring(NS.Hints ~= nil)
    lines[#lines + 1] = "Active hint: " .. (NS.Hints and NS.Hints.controller.mode or "unavailable")
    lines[#lines + 1] = "Region query pending: " .. tostring(NS.RegionHints and NS.RegionHints.job ~= nil)
    lines[#lines + 1] = "Requested region samples: " .. tostring(NS.Hints and NS.Hints.active and NS.Hints.active.region and #NS.Hints.active.region.points or 0)
    lines[#lines + 1] = "Arrow shown: " .. tostring(NS.Bearing and NS.Bearing.frame and NS.Bearing.frame:IsVisible() or false)
    lines[#lines + 1] = "Arrow artwork: " .. tostring(NS.Bearing and NS.Bearing.atlas or "not loaded")
    lines[#lines + 1] = "Area module: " .. tostring(NS.Area ~= nil)
    lines[#lines + 1] = "Area draw requested: " .. tostring(NS.Area and NS.Area.active and NS.Area.active.drawn or false)
    lines[#lines + 1] = "questPOI: " .. tostring(NS.Adapter.QuestPOI())
    local mini, miniError = NS.Adapter.QuestTracking()
    lines[#lines + 1] = "Minimap quest filter: " .. (mini and tostring(mini.active) or tostring(miniError))
    local navigationOK, navigation = NS.Call("C_SuperTrack.GetSuperTrackedQuestID")
    lines[#lines + 1] = "Supertracked quest: " .. (navigationOK and tostring(navigation) or "unavailable")
    for _, path in ipairs({ "C_CVar.SetCVar", "C_Minimap.GetTrackingFilter",
        "C_Minimap.SetTracking", "C_SuperTrack.SetSuperTrackedQuestID", "QuestObjectiveTracker.OnBlockHeaderClick",
        "GetPlayerFacing", "C_Map.GetWorldPosFromMapPos", "C_QuestLog.GetQuestsOnMap", "C_Texture.GetAtlasInfo", "OpenWorldMap" }) do
        lines[#lines + 1] = path .. ": " .. tostring(type(NS.Resolve(path)) == "function")
    end
    local keys = {}
    for key in pairs(NS.DB.lastCheck or {}) do keys[#keys + 1] = key end
    table.sort(keys)
    for _, key in ipairs(keys) do lines[#lines + 1] = key .. ": " .. NS.DB.lastCheck[key] end
    return table.concat(lines, "\n")
end

SLASH_JUSTAHINT1 = "/jah"
SlashCmdList.JUSTAHINT = function(message)
    local command = message:match("^%s*(%S*)")
    command = command:lower()
    if command == "start" then
        local ok, err = NS.Guard.Start()
        NS.Message(ok and "Just a Hint started. Restore Blizzard guidance with /jah restore." or err)
        NS.SettingsPanel.Open()
    elseif command == "restore" then
        local ok, err = NS.Guard.Restore()
        NS.Message(ok and "Saved guidance settings restored." or err)
        NS.SettingsPanel.UpdateState()
    elseif command == "clear" then
        if NS.Hints then NS.Hints.Clear("cleared") end
    elseif command == "status" then
        NS.StatusReport.Open(report())
    elseif command == "settings" then
        NS.SettingsPanel.Open()
    elseif command == "" then
        NS.SettingsPanel.Open()
    else
        NS.Message("/jah — settings; /jah settings — settings; /jah start — start Just a Hint; /jah clear — clear hint; /jah restore — restore Blizzard guidance; /jah status — copy report.")
    end
end

local frame = CreateFrame("Frame")
for _, event in ipairs({ "ADDON_LOADED", "PLAYER_LOGIN", "PLAYER_ENTERING_WORLD", "QUEST_LOG_UPDATE",
    "QUEST_ACCEPTED", "QUEST_REMOVED", "QUEST_TURNED_IN", "QUEST_POI_UPDATE", "SUPER_TRACKING_CHANGED",
    "CVAR_UPDATE", "MINIMAP_UPDATE_TRACKING", "PLAYER_REGEN_ENABLED" }) do
    frame:RegisterEvent(event)
end
for _, event in ipairs({ "ADDON_ACTION_BLOCKED", "ADDON_ACTION_FORBIDDEN", "LUA_WARNING" }) do
    -- The names are present in the installed executable. Registration still
    -- needs native verification and must not prevent addon startup if absent.
    local ok = pcall(frame.RegisterEvent, frame, event)
    if not ok then NS.securityEventRegistrationFailed = event end
end
frame:SetScript("OnEvent", function(_, event, ...)
    if event == "ADDON_ACTION_BLOCKED" or event == "ADDON_ACTION_FORBIDDEN" or event == "LUA_WARNING" then
        NS.RecordSecurity(event, ...)
        return
    end
    if event == "ADDON_LOADED" then
        if ... == addonName then NS.Initialize() end
        if NS.DB and NS.loggedIn then NS.Guard.Resume() end
        if NS.DB and NS.Guard.active and not NS.InCombat() then
            if NS.NativePane then NS.NativePane.Install() end
            NS.Guard.Enforce()
        end
        return
    end
    if not NS.DB then return end
    if event == "PLAYER_ENTERING_WORLD" then
        if NS.Hints then NS.Hints.Clear("world-changed") end
        if NS.NativePane then NS.NativePane.ClearButton("world-changed") end
    end
    if (event == "QUEST_REMOVED" or event == "QUEST_TURNED_IN") and NS.Hints and NS.Hints.active
        and NS.Hints.active.id == ... then NS.Hints.Clear(event == "QUEST_REMOVED" and "removed" or "turned-in") end
    if event == "PLAYER_LOGIN" then
        NS.loggedIn = true
        if NS.DB.enabled then
            NS.Guard.Resume()
        else
            local ok, err = NS.Guard.Restore()
            if not ok then NS.Message(err) end
        end
    elseif event == "QUEST_LOG_UPDATE" or event == "QUEST_POI_UPDATE" then
        NS.Guard.Enforce()
        if NS.Hints then NS.Hints.Update() end
    else
        if event == "PLAYER_ENTERING_WORLD" or event == "PLAYER_REGEN_ENABLED" then NS.Guard.Resume() end
        NS.Guard.Enforce()
        NS.SettingsPanel.UpdateState()
    end
end)
