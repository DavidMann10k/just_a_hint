local _, NS = ...
-- Blizzard owns native opening. We observe details and own only our controls.
-- The separate explicit Hint button writes only to addon-owned controls.
local Pane = { available = true }
NS.NativePane = Pane

function Pane.ClearButton(reason)
    Pane.active = nil
    if Pane.button then Pane.button:Hide() end
    if Pane.ticker then Pane.ticker:Hide() end
    NS.Note("nativeButton", reason or "cleared")
end

local function context(expected)
    if NS.InCombat() then return nil, "Leave combat before requesting a hint." end
    if not NS.Guard.active or NS.Guard.problem then return nil, "Start Just a Hint before requesting a hint." end
    local map = WorldMapFrame
    local details = QuestMapFrame and QuestMapFrame.DetailsFrame
    local anchor = details and details.TrackButton
    for _, frame in ipairs({ map or false, details or false, anchor or false }) do
        if not frame or type(frame.IsProtected) ~= "function" or frame:IsProtected() ~= false
            or not frame:IsVisible() then return nil, "Open a quest's details first." end
    end
    local mapID = map:GetMapID()
    if not NS.ID(mapID) then return nil, "The displayed map is unavailable." end
    local id = details.questID
    local focusedOK, focused = NS.Call("QuestMapFrame_GetFocusedQuestID")
    local selectedOK, selected = NS.Call("C_QuestLog.GetSelectedQuest")
    NS.Note("nativeButtonDetailsQuest", id or "none")
    NS.Note("nativeButtonFocusedQuest", focusedOK and focused or "unavailable")
    NS.Note("nativeButtonSelectedQuest", selectedOK and selected or "unavailable")
    if not NS.ID(id) or not focusedOK or focused ~= id or not selectedOK or selected ~= id then
        return nil, "The displayed quest could not be confirmed. Use /jah status for details."
    end
    if expected and (map ~= expected.map or details ~= expected.details or anchor ~= expected.anchor
        or mapID ~= expected.mapID or id ~= expected.questID) then return nil, "The quest or map changed." end
    return { map = map, details = details, anchor = anchor, mapID = mapID, questID = id }
end

function Pane.RefreshButton()
    if not Pane.active then return end
    local ok, current, reason = pcall(context, Pane.active)
    if not ok or not current then Pane.ClearButton(ok and reason or "Native controls are unreadable."); return end
    local updated, state = pcall(NS.Hints.UpdateButton, Pane.button, current.questID)
    if not updated then Pane.ClearButton("Hint availability could not be read."); return end
    NS.Note("nativeButton", state)
    -- The independent ticker keeps checking even if unavailable data hides the
    -- button; becoming ready never requests a hint or changes an existing one.
end

function Pane.ShowButton()
    Pane.ClearButton("new-details")
    local ok, current, reason = pcall(context)
    if not ok or not current then
        local why = ok and reason or "Native controls are unreadable."
        NS.Note("nativeButton", why)
        return false, why
    end
    local built, err = pcall(function()
        if not Pane.button then
            local button = CreateFrame("Button", "JustAHintNativeHint", UIParent, "UIPanelButtonTemplate")
            Pane.button = button
            button:Hide()
            button:SetSize(100, 24)
            button:SetText("Hint")
            button:SetFrameStrata("DIALOG")
            button:EnableMouse(true)
            button:SetEnabled(false)
            button:SetScript("OnClick", function()
                if not Pane.active or not button:IsVisible() or not button:IsEnabled() then return end
                local valid, clicked = pcall(context, Pane.active)
                if not valid or not clicked then Pane.ClearButton("Quest identity changed before the click."); return end
                -- Request owns data revalidation and replacement, including when
                -- a destination disappears after the button was enabled.
                local closeAttempted = false
                local function closeBearing()
                    if closeAttempted then return end
                    local hints = NS.Hints
                    if not hints.active or hints.active.id ~= clicked.questID
                        or hints.controller.mode ~= "bearing" or not hints.controller.visible
                        or not NS.Bearing.frame or not NS.Bearing.frame:IsVisible() then return end
                    local unchanged, same = pcall(context, clicked)
                    if not unchanged or not same then return end
                    closeAttempted = true
                    local closed, problem = NS.Call("HideUIPanel", clicked.map)
                    NS.Note("nativeMapClose", closed and "requested" or "failed")
                    if not closed then NS.Note("nativeMapCloseError", problem); return end
                    Pane.ClearButton("direction-requested")
                end
                if NS.Hints.Toggle(clicked.questID, closeBearing) == "cleared" then
                    Pane.RefreshButton()
                    return -- Clearing leaves the native map open and plays no feedback.
                end
                -- Synchronous fallback and delayed region completion both close
                -- only after rendering and rechecking the original click context.
                closeBearing()
                if Pane.active then Pane.RefreshButton() end
            end)
            Pane.ticker = CreateFrame("Frame", nil, UIParent)
            Pane.ticker:Hide()
            local elapsed = 0
            Pane.ticker:SetScript("OnUpdate", function(_, dt)
                elapsed = elapsed + dt
                if elapsed >= 0.5 then elapsed = 0; Pane.RefreshButton() end
            end)
            button.ready = true
        end
        if not Pane.button.ready then error("Hint button setup is incomplete. Reload to retry.") end
        Pane.button:ClearAllPoints()
        Pane.button:SetPoint("TOPRIGHT", current.anchor, "BOTTOMRIGHT", 0, -6)
        Pane.active = current
        Pane.ticker:Show()
        Pane.RefreshButton()
    end)
    if not built then Pane.ClearButton("construction-failed"); NS.Note("nativeButtonError", err); return false, tostring(err) end
    if not Pane.active then return false, NS.DB.lastCheck.nativeButton or "Hint control unavailable." end
    return true
end

local function sameContext(a, b)
    return a and b and a.questID == b.questID and a.mapID == b.mapID
        and a.map == b.map and a.details == b.details and a.anchor == b.anchor
end

function Pane.Observe()
    if not Pane.available or not NS.Guard.active or NS.Guard.problem then return end
    local ok, current = pcall(context)
    if not ok then
        Pane.available = false
        Pane.problem = "Native details could not be observed. Use /jah status for details."
        Pane.Restore()
        NS.Note("nativeObserverError", current)
        return
    end
    if not current then
        if Pane.active then Pane.ClearButton("native-context-hidden-or-unconfirmed") end
        Pane.observed = nil
        return
    end
    if sameContext(Pane.observed, current) then return end
    Pane.observed = current -- One attachment attempt per stable native context.
    local attached, reason = Pane.ShowButton()
    NS.Note("nativeAttachment", attached and "attached without navigation" or tostring(reason))
end

function Pane.Check()
    local ok, supported = pcall(function()
        local details = QuestMapFrame and QuestMapFrame.DetailsFrame
        for _, frame in ipairs({ WorldMapFrame or false, details or false, details and details.TrackButton or false }) do
            if not frame or type(frame.IsProtected) ~= "function" or frame:IsProtected() ~= false then return false end
        end
        return type(NS.Resolve("QuestMapFrame_GetFocusedQuestID")) == "function"
            and type(NS.Resolve("C_QuestLog.GetSelectedQuest")) == "function"
    end)
    return ok and supported == true, "Native quest controls unavailable. Open the Map & Quest Log to load them."
end

function Pane.Install()
    local supported = Pane.Check()
    Pane.available = supported == true
    if not Pane.available then
        Pane.problem = "Native quest controls unavailable. Open the Map & Quest Log to load them."
        Pane.Restore()
        return false
    end
    Pane.problem = nil
    local built, err = pcall(function()
        if not Pane.observer then
            Pane.observer = CreateFrame("Frame", "JustAHintNativeObserver", UIParent)
            Pane.observer:Hide()
            local elapsed = 0
            Pane.observer:SetScript("OnUpdate", function(_, dt)
                elapsed = elapsed + dt
                if elapsed >= 0.1 then elapsed = 0; Pane.Observe() end
            end)
        end
        Pane.observer:Show()
    end)
    if not built then
        Pane.available = false
        Pane.problem = "Native observer unavailable. Use /jah status for details."
        Pane.Restore()
        NS.Note("nativeObserverError", err)
        return false
    end
    return true
end

function Pane.Restore()
    if Pane.observer then Pane.observer:Hide() end
    Pane.observed = nil
    Pane.ClearButton("native-button-restored")
end
