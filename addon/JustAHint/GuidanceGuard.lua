local _, NS = ...
local Guard = { active = false, busy = false }
NS.Guard = Guard

function Guard.PendingRestoration()
    local recovery = NS.DB.recovery
    local key = NS.Adapter.PlayerKey()
    return recovery.questPOI ~= nil or (key and recovery.minimap[key] ~= nil)
        or (not key and next(recovery.minimap) ~= nil) or false
end

function Guard.Action()
    if Guard.active or NS.DB.enabled then return "restore" end
    return Guard.PendingRestoration() and "retry" or "start"
end

function Guard.Toggle()
    local action = Guard.Action()
    if action == "start" then return Guard.Start() end
    return Guard.Restore()
end

function Guard.Preflight()
    if NS.InCombat() then return nil, "Start Just a Hint out of combat." end
    for _, path in ipairs({ "C_CVar.SetCVar", "C_Minimap.SetTracking",
        "C_SuperTrack.GetSuperTrackedQuestID", "C_SuperTrack.SetSuperTrackedQuestID",
        "hooksecurefunc" }) do
        if type(NS.Resolve(path)) ~= "function" then return nil, "Missing " .. path end
    end
    local nativeOK = NS.NativePane.Check()
    local trackerOK = NS.NativeTracker.Check()
    if not nativeOK or not trackerOK then
        local loadAddon = NS.Resolve("C_AddOns.LoadAddOn") or NS.Resolve("LoadAddOn")
        if type(loadAddon) == "function" then
            if not nativeOK then pcall(loadAddon, "Blizzard_WorldMap") end
            if not trackerOK then pcall(loadAddon, "Blizzard_ObjectiveTracker") end
        end
    end
    local paneOK, paneError = NS.NativePane.Check()
    if not paneOK then return nil, paneError end
    local available, trackerError = NS.NativeTracker.Check()
    if not available then return nil, trackerError end
    local map, mapError = NS.Adapter.QuestPOI()
    if map == nil then return nil, mapError end
    local minimap, miniError = NS.Adapter.QuestTracking()
    if not minimap then return nil, miniError end
    local key = NS.Adapter.PlayerKey()
    if not key then return nil, "Enter the world before starting Just a Hint." end
    return { map = map, minimap = minimap.active, key = key }
end

function Guard.Enforce()
    if not Guard.active or Guard.busy then return true end
    Guard.busy = true
    local ok, err = pcall(function()
        local map, readError = NS.Adapter.QuestPOI()
        if map == nil then error(readError) end
        if map ~= "0" then
            local changed, changeError = NS.Adapter.SetQuestPOI("0")
            if not changed then error(changeError) end
        end
        local filtered, filterError = NS.Adapter.SetQuestTracking(false)
        if not filtered then error(filterError) end
        local cleared, clearError = NS.Adapter.ClearQuestNavigation()
        if not cleared then error(clearError) end
    end)
    Guard.busy = false
    Guard.problem = not ok and tostring(err) or nil
    NS.Note("guidanceControls", ok and "applied" or Guard.problem)
    if not ok and Guard.lastWarning ~= Guard.problem then
        Guard.lastWarning = Guard.problem
        NS.Message("Guidance controls need attention: " .. Guard.problem .. " Use /jah restore to restore settings.")
    end
    return ok, Guard.problem
end

function Guard.Start()
    if not Guard.active and not NS.DB.enabled and Guard.PendingRestoration() then
        return false, "Restore saved guidance settings before starting Just a Hint again."
    end
    local before, err = Guard.Preflight()
    if not before then NS.Note("start", err); return false, err end
    local recovery = NS.DB.recovery
    -- Keep the first snapshot across repeated starts and /reload.
    if recovery.questPOI == nil then recovery.questPOI = before.map end
    if recovery.minimap[before.key] == nil then recovery.minimap[before.key] = before.minimap end
    NS.DB.enabled = true
    Guard.active = true
    if not NS.NativePane.Install() then
        local problem = NS.NativePane.problem or "Native quest controls unavailable."
        local restored, err = Guard.Restore()
        return false, problem .. (restored and " Settings restored." or " " .. err)
    end
    if not Guard.hooked then
        local hooked, hookError = pcall(hooksecurefunc, C_SuperTrack, "SetSuperTrackedQuestID", function()
            Guard.Enforce()
        end)
        if not hooked then
            Guard.Restore()
            return false, "Quest navigation hook failed: " .. tostring(hookError)
        end
        Guard.hooked = true
    end
    local applied, applyError = Guard.Enforce()
    if not applied then
        local restored, restoreError = Guard.Restore()
        return false, applyError .. (restored and " Settings restored." or " " .. restoreError)
    end
    NS.Note("start", "Just a Hint active")
    return true
end

function Guard.Resume()
    if Guard.resuming or Guard.active or not NS.DB.enabled then return end
    -- A load-on-demand addon may fire ADDON_LOADED inside Preflight.
    if NS.InCombat() or not NS.Adapter.PlayerKey() then return end
    Guard.resuming = true
    local ok, err = Guard.Start()
    Guard.resuming = false
    if not ok and Guard.resumeError ~= err then NS.Message("Startup: " .. err) end
    Guard.resumeError = not ok and err or nil
    return ok, err
end

function Guard.Restore()
    if NS.InCombat() then
        return false, "Leave combat, then use Restore Blizzard guidance again."
    end
    if NS.Hints then NS.Hints.Clear("blizzard-guidance-restored") end
    -- Disable enforcement before writing back settings (events may be synchronous).
    Guard.active = false
    if NS.NativePane then NS.NativePane.Restore() end
    NS.DB.enabled = false
    local recovery, errors = NS.DB.recovery, {}
    if recovery.questPOI ~= nil then
        local ok, err = NS.Adapter.SetQuestPOI(recovery.questPOI)
        if ok then recovery.questPOI = nil else errors[#errors + 1] = err end
    end
    local key = NS.Adapter.PlayerKey()
    if key and recovery.minimap[key] ~= nil then
        local ok, err = NS.Adapter.SetQuestTracking(recovery.minimap[key])
        if ok then recovery.minimap[key] = nil else errors[#errors + 1] = err end
    elseif not key and next(recovery.minimap) then
        errors[#errors + 1] = "Enter the world to restore this character's minimap setting."
    end
    -- Other characters' filter snapshots are restored on their next login.
    Guard.problem = #errors > 0 and table.concat(errors, " ") or nil
    NS.Note("restoration", Guard.problem or "saved settings restored for this character")
    return #errors == 0, Guard.problem
end
