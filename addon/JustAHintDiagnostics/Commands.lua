local addonName, NS = ...

local Panel = {}
NS.AreaPanel = Panel
local phases = { normal = true, disabled = true, isolated = true }
local categories = { outdoor = true, delivery = true, multi = true, unclassified = true }

-- Explicit placement experiment. All writes target our UIParent-owned button;
-- native controls are only inspected and used as an anchor reference.
local NativeButton = {}
NS.NativeButtonProbe = NativeButton

function NativeButton.Clear(reason)
    local active = NativeButton.active
    NativeButton.active = nil
    if NativeButton.frame then NativeButton.frame:Hide() end
    if active then NS.Record("native-button-cleared", { buttonRecordID = active.recordID, reason = reason or "manual" }) end
end

function NativeButton.Show()
    NativeButton.Clear("new-request")
    local result = { status = "unavailable", scope = "display-only-button-below-native-row",
        nativeIntegrationVerified = false, visualResult = "unverified", clickEnabled = false }
    local ok, err = pcall(function()
        if type(InCombatLockdown) == "function" and InCombatLockdown() then result.status = "unavailable-in-combat"; return end
        local map = WorldMapFrame
        local details = QuestMapFrame and QuestMapFrame.DetailsFrame
        local anchor = details and details.TrackButton
        for _, frame in ipairs({ map or false, details or false, anchor or false }) do
            if not frame or type(frame.IsProtected) ~= "function" or frame:IsProtected() ~= false then
                result.status = "missing-or-protected-native-frame"; return
            end
            if not frame:IsVisible() then result.status = "open-native-quest-details-manually"; return end
        end
        local mapID = map:GetMapID()
        if not NS.ID(mapID) then result.status = "displayed-map-unavailable"; return end
        if not NativeButton.frame then
            local button = CreateFrame("Button", "JustAHintDiagnosticsNativeButton", UIParent, "UIPanelButtonTemplate")
            NativeButton.frame = button
            button:Hide()
            button:SetSize(100, 24)
            button:SetText("Hint")
            button:SetEnabled(false)
            button:EnableMouse(false)
            button:SetFrameStrata("DIALOG")
            button:SetScript("OnUpdate", function()
                local active = NativeButton.active
                if not active then return end
                local valid, visible = pcall(function()
                    return not (type(InCombatLockdown) == "function" and InCombatLockdown())
                        and WorldMapFrame == active.map and QuestMapFrame and QuestMapFrame.DetailsFrame == active.details
                        and active.details.TrackButton == active.anchor and active.map:IsVisible()
                        and active.details:IsVisible() and active.anchor:IsVisible()
                        and active.map:GetMapID() == active.mapID
                end)
                if not valid or not visible then NativeButton.Clear("native-context-changed") end
            end)
            button.ready = true
            -- No OnClick, native handler replacement, quest selection or draw.
        end
        local button = NativeButton.frame
        if not button.ready then error("native-button-construction-incomplete") end
        button:ClearAllPoints()
        button:SetPoint("TOPRIGHT", anchor, "BOTTOMRIGHT", 0, -6)
        NativeButton.active = { map = map, details = details, anchor = anchor, mapID = mapID }
        button:Show()
        result.status = "display-requested-unverified"
        result.mapID = mapID
        result.anchor = "QuestMapFrame.DetailsFrame.TrackButton"
        result.position = "TOPRIGHT to BOTTOMRIGHT; x=0, y=-6"
    end)
    if not ok then NativeButton.Clear("construction-failed"); result.status = "error"; result.detail = tostring(err) end
    return result
end

local reasons = {
    manual = "you cleared the preview",
    ["panel-closed"] = "you closed the comparison panel",
    ["new-request"] = "another area was requested",
    ["map-or-frame-hidden"] = "the map or drawing frame was hidden",
    ["map-context-changed"] = "the displayed map changed",
    ["canvas-changed"] = "the map size or zoom changed",
    QUEST_LOG_UPDATE = "the quest log updated",
    PLAYER_ENTERING_WORLD = "you entered the world or changed zones",
    ["command-failed"] = "the diagnostic command failed",
    ["isolation-started"] = "a map isolation comparison started",
    ["isolation-ended"] = "the map isolation comparison ended",
}

function Panel.Refresh()
    local frame = Panel.frame
    if not frame or not frame.result then return end
    local result = frame.result
    frame.title:SetText("Just a Hint " .. NS.VERSION .. ": area comparison — #" .. frame.recordID)
    local text = "Quest " .. result.questID .. " | map " .. tostring(result.mapID or "unavailable") .. "\n"
    if NS.Isolation.active then text = text .. "Blizzard quest frames hidden for this map comparison.\n" end
    if NS.Area.active then
        text = text .. "PREVIEW REQUESTED — strong fill and border.\n"
            .. "Compare Hide area / Show area on the same map.\n"
            .. "An active frame does not confirm that a quest region is visible."
    elseif result.status ~= "call-ok-unverified" then
        local instruction = "Press Copy results to capture this failure."
        if result.status == "accepted-quest-not-confirmed" then
            if result.accepted.status == "ok" and result.accepted.value == false then
                instruction = "This quest is no longer in your log.\nPress Quests to choose a current quest."
            else
                instruction = "Could not verify that this quest is in your log.\nPress Copy results to capture this failure."
            end
        elseif result.status == "open-world-map-manually" then
            instruction = "Open the relevant world map, then press Show area."
        elseif result.status == "unavailable-in-combat" then
            instruction = "Leave combat, then press Show area."
        end
        text = text .. "NOT DRAWN: " .. result.status .. "\n" .. instruction
    else
        text = text .. "HIDDEN: " .. (reasons[NS.Area.clearReason] or NS.Area.clearReason or "preview inactive") .. ".\n"
            .. "Open the same map and press Show area to compare again."
    end
    if NS.Region.active then
        text = text .. "\nRegion check: hidden / visible / transparent / hidden sampling in progress."
    elseif NS.Region.lastResult and NS.Region.lastResult.areaRecordID == frame.recordID then
        text = text .. "\nRegion check: " .. NS.Region.lastResult.status .. " (#" .. NS.Region.lastRecordID .. ")."
            .. "\nInvisible query: " .. tostring(NS.Region.lastResult.transparentQueryResult or "unverified")
    end
    if frame.regionButton then frame.regionButton:SetEnabled(NS.Area.active ~= nil and NS.Region.active == nil) end
    frame.status:SetText(text)
end

function Panel.Show(result, recordID, command)
    if not Panel.frame then
        local frame = CreateFrame("Frame", "JustAHintDiagnosticsAreaPanel", UIParent)
        frame:SetSize(490, 230)
        frame:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, 100)
        frame:SetFrameStrata("DIALOG")
        frame:EnableMouse(true)
        frame:SetMovable(true)
        frame:RegisterForDrag("LeftButton")
        frame:SetScript("OnDragStart", function(self) self:StartMoving() end)
        frame:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
        local background = frame:CreateTexture(nil, "BACKGROUND")
        background:SetAllPoints()
        background:SetColorTexture(0.04, 0.04, 0.07, 0.97)
        frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        frame.title:SetPoint("TOPLEFT", 14, -12)
        frame.status = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        frame.status:SetPoint("TOPLEFT", 14, -38)
        frame.status:SetSize(462, 116)
        frame.status:SetJustifyH("LEFT")
        frame.status:SetJustifyV("TOP")
        local function button(label, index, callback)
            local value = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
            value:SetSize(88, 26)
            value:SetPoint("BOTTOMLEFT", 14 + index * 93, 47)
            value:SetText(label)
            value:SetScript("OnClick", callback)
            return value
        end
        frame.showButton = button("Show area", 0, function() NS.RunCommand(frame.command) end)
        frame.hideButton = button("Hide area", 1, function() NS.Area.Clear("manual") end)
        frame.questsButton = button("Quests", 2, function()
            NS.RunCommand("area " .. frame.result.context.guidanceLabel)
        end)
        frame.exportButton = button("Copy results", 3, function()
            NS.RunCommand("export")
        end)
        frame.closeButton = button("Close", 4, function()
            NS.Area.Clear("panel-closed")
            frame:Hide()
        end)
        frame.restoreButton = button("Restore Blizzard map", 0, function() NS.RunCommand("restore") end)
        frame.restoreButton:ClearAllPoints()
        frame.restoreButton:SetPoint("BOTTOMLEFT", 14, 12)
        frame.restoreButton:SetSize(225, 26)
        frame.regionButton = button("Check region data", 0, function() NS.RunCommand("region") end)
        frame.regionButton:ClearAllPoints()
        frame.regionButton:SetPoint("BOTTOMLEFT", 251, 12)
        frame.regionButton:SetSize(225, 26)
        frame:SetScript("OnHide", function()
            NS.Area.Clear("panel-closed")
            NS.Isolation.Stop("panel-closed")
        end)
        UISpecialFrames[#UISpecialFrames + 1] = "JustAHintDiagnosticsAreaPanel"
        Panel.frame = frame
    end
    local frame = Panel.frame
    frame.result, frame.recordID, frame.command = result, recordID, command
    Panel.Refresh()
    frame:Show()
end

-- Listing quests is read-only. Only a labelled Show area button requests a probe;
-- acceptance is checked again at that point in case the list became stale.
local PAGE_SIZE = 8

function Panel.RefreshQuests(readClient)
    local frame = Panel.picker
    if readClient then
        local entries = NS.Adapter.Quests()
        local record = NS.Record("quest-list", entries)
        frame.entries, frame.errors, frame.listStatus = {}, 0, entries.status
        frame.captureID = record.id
        if entries.status == "ok" then
            for _, entry in ipairs(entries.value) do
                if entry.status == "ok" then
                    frame.entries[#frame.entries + 1] = entry.value
                else frame.errors = frame.errors + 1 end
            end
        end
    end
    local pages = math.max(1, math.ceil(#frame.entries / PAGE_SIZE))
    frame.page = math.max(1, math.min(frame.page, pages))
    local text = "Open the relevant world map, then choose Show area.\n"
        .. "Guidance label: " .. frame.phase .. " (tester supplied). "
        .. "Page " .. frame.page .. "/" .. pages .. "."
    if NS.Isolation.active then
        text = "Blizzard quest frames hidden on this map; choose Show area.\n"
            .. "Map changes end this comparison. Page " .. frame.page .. "/" .. pages .. "."
    end
    if frame.listStatus ~= "ok" then
        text = "Quest list unavailable: " .. frame.listStatus .. ". Press Refresh to retry."
    elseif #frame.entries == 0 then
        text = "No readable quests in your current log. Accept a quest, then press Refresh."
    end
    if frame.errors > 0 then text = text .. "\nUnreadable entries: " .. frame.errors .. "." end
    frame.status:SetText(text .. "\nList capture #" .. frame.captureID .. "; listing does not draw guidance.")
    for index, row in ipairs(frame.rows) do
        local entry = frame.entries[(frame.page - 1) * PAGE_SIZE + index]
        row.questID = entry and entry.questID or nil
        if entry then
            row:SetText("Show area: " .. entry.title)
            row:Show()
        else row:Hide() end
    end
end

function Panel.ShowQuests(phase)
    if not Panel.picker then
        local frame = CreateFrame("Frame", "JustAHintDiagnosticsQuestPicker", UIParent)
        frame:SetSize(490, 435)
        frame:SetPoint("CENTER")
        frame:SetFrameStrata("DIALOG")
        frame:EnableMouse(true)
        frame:SetMovable(true)
        frame:RegisterForDrag("LeftButton")
        frame:SetScript("OnDragStart", function(self) self:StartMoving() end)
        frame:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
        local background = frame:CreateTexture(nil, "BACKGROUND")
        background:SetAllPoints()
        background:SetColorTexture(0.04, 0.04, 0.07, 0.97)
        local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        title:SetPoint("TOPLEFT", 14, -12)
        title:SetText("Just a Hint " .. NS.VERSION .. ": current quests")
        frame.status = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        frame.status:SetPoint("TOPLEFT", 14, -38)
        frame.status:SetSize(462, 65)
        frame.status:SetJustifyH("LEFT")
        frame.status:SetJustifyV("TOP")
        frame.rows = {}
        for index = 1, PAGE_SIZE do
            local row = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
            row:SetSize(462, 27)
            row:SetPoint("TOPLEFT", 14, -110 - (index - 1) * 30)
            row:SetScript("OnClick", function(self)
                if not self.questID then return end
                frame.selectingQuest = true
                frame:Hide()
                frame.selectingQuest = nil
                NS.RunCommand("area " .. self.questID .. " " .. frame.phase .. " unclassified")
            end)
            frame.rows[index] = row
        end
        local function button(label, index, callback)
            local value = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
            value:SetSize(110, 26)
            value:SetPoint("BOTTOMLEFT", 14 + index * 117, 47)
            value:SetText(label)
            value:SetScript("OnClick", callback)
            return value
        end
        frame.previousButton = button("Previous", 0, function()
            frame.page = frame.page - 1
            Panel.RefreshQuests(false)
        end)
        frame.nextButton = button("Next", 1, function()
            frame.page = frame.page + 1
            Panel.RefreshQuests(false)
        end)
        frame.refreshButton = button("Refresh", 2, function() Panel.RefreshQuests(true) end)
        frame.closeButton = button("Close", 3, function() frame:Hide() end)
        frame.restoreButton = button("Restore Blizzard map", 0, function() NS.RunCommand("restore") end)
        frame.restoreButton:ClearAllPoints()
        frame.restoreButton:SetPoint("BOTTOMLEFT", 14, 12)
        frame.restoreButton:SetSize(462, 26)
        frame:SetScript("OnHide", function()
            if not frame.selectingQuest then NS.Isolation.Stop("picker-closed") end
        end)
        UISpecialFrames[#UISpecialFrames + 1] = "JustAHintDiagnosticsQuestPicker"
        Panel.picker = frame
    end
    Panel.picker.phase, Panel.picker.page = phase, 1
    Panel.RefreshQuests(true)
    Panel.picker:Show()
end

local function help()
    NS.Print("/jahdiag build | list | probe ID normal|disabled outdoor|delivery|multi [note]")
    NS.Print("/jahdiag scan normal|disabled (capture all accepted quests without drawing)")
    NS.Print("/jahdiag area [normal|disabled] (choose a current quest by name; default normal)")
    NS.Print("/jahdiag area ID normal|disabled outdoor|delivery|multi [note] (on the open world map)")
    NS.Print("/jahdiag silent QUEST_ID (zero-alpha-only query with the world map closed)")
    NS.Print("/jahdiag region (compare native hit-test data with the diagnostic region hidden/drawn/hidden)")
    NS.Print("/jahdiag ui (read native quest-pane structure; open a short copyable report)")
    NS.Print("/jahdiag button (show an inert Hint below the native buttons; open quest details manually first)")
    NS.Print("/jahdiag observe RECORD_ID visible|none|other-quests [note] | note [text]")
    NS.Print("/jahdiag clear | report [RECORD_ID] | export [RECORD_ID]")
    NS.Print("/jahdiag isolate (hide Blizzard quest frames on the open map; requires questPOI=1)")
    NS.Print("/jahdiag restore (end the comparison and restore Blizzard quest frames)")
end

local function findRecord(id)
    if not NS.DB then NS.Initialize() end
    for _, record in ipairs(NS.DB.records) do if record.id == id then return record end end
end

local function export(report)
    if not NS.exportFrame then
        local frame = CreateFrame("Frame", "JustAHintDiagnosticsExport", UIParent)
        frame:SetSize(740, 460)
        frame:SetPoint("CENTER")
        frame:SetFrameStrata("DIALOG")
        frame:EnableMouse(true)
        local background = frame:CreateTexture(nil, "BACKGROUND")
        background:SetAllPoints()
        background:SetColorTexture(0.06, 0.06, 0.08, 0.97)
        local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        title:SetPoint("TOPLEFT", 16, -14)
        title:SetText("Diagnostic capture — Ctrl+A, Ctrl+C to copy. Escape to close.")
        local scroll = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
        scroll:SetPoint("TOPLEFT", 16, -40)
        scroll:SetPoint("BOTTOMRIGHT", -36, 16)
        local edit = CreateFrame("EditBox", nil, scroll)
        edit:SetMultiLine(true)
        edit:SetAutoFocus(false)
        edit:SetFontObject("ChatFontNormal")
        edit:SetWidth(680)
        edit:SetHeight(380)
        edit:SetScript("OnEscapePressed", function() frame:Hide() end)
        scroll:SetScrollChild(edit)
        frame.edit = edit
        NS.exportFrame = frame
        UISpecialFrames[#UISpecialFrames + 1] = "JustAHintDiagnosticsExport"
    end
    NS.exportFrame.edit:SetText(report)
    NS.exportFrame:Show()
    NS.exportFrame.edit:SetFocus()
    NS.exportFrame.edit:HighlightText()
end

local function nativeUIReport(record)
    local function value(read)
        if read and read.status == "ok" then return tostring(read.value) end
        return "[" .. (read and read.status or "unavailable") .. "]"
    end
    local data, lines = record.data, {
        "Just a Hint diagnostic " .. NS.VERSION .. ": native UI capture #" .. record.id,
        "Read-only snapshot; native integration is not verified.",
    }
    if record.build.status == "ok" then
        local build = record.build.value
        lines[#lines + 1] = "Client: " .. build.version .. " / " .. build.build .. " / " .. build.interface
    end
    lines[#lines + 1] = "Displayed map: " .. value(data.displayedMap) .. "; player map: " .. value(data.playerMap)
    lines[#lines + 1] = "Quest IDs — focused: " .. value(data.focusedQuest) .. "; selected: "
        .. value(data.selectedQuest) .. "; details: " .. value(data.detailsQuest)
    lines[#lines + 1] = "questPOI: " .. value(data.context.questPOI)
    for _, frame in ipairs(data.frames) do
        local line = frame.source .. ": " .. frame.status
        if frame.status == "present" then
            line = line .. "; visible=" .. value(frame.visible) .. "; protected=" .. value(frame.protected)
            if frame.rect.status == "ok" then
                local rect = frame.rect.value
                line = line .. string.format("; rect=%.1f,%.1f %.1fx%.1f", rect.left, rect.bottom, rect.width, rect.height)
            else line = line .. "; rect=" .. value(frame.rect) end
        end
        lines[#lines + 1] = line
    end
    lines[#lines + 1] = "Copy this report with Ctrl+A, Ctrl+C. Escape closes it."
    return table.concat(lines, "\n")
end

function NS.Command(message)
    local command, rest = (message or ""):match("^%s*(%S*)%s*(.-)%s*$")
    command = command:lower()
    if command == "build" then
        local record = NS.Record("build", { capabilities = NS.Adapter.Capabilities(),
            context = NS.Adapter.Context("unlabelled", "unlabelled") })
        local build = record.build
        if build.status == "ok" then
            NS.Print("build " .. build.value.version .. " / " .. build.value.build
                .. "; interface " .. build.value.interface .. "; capture #" .. record.id)
        else NS.Print("GetBuildInfo: " .. build.status .. "; capture #" .. record.id) end
    elseif command == "ui" then
        local record = NS.Record("native-ui", NS.Adapter.NativeUI())
        export(nativeUIReport(record))
    elseif command == "button" then
        local record = NS.Record("native-button", NativeButton.Show())
        if NativeButton.active then NativeButton.active.recordID = record.id end
        NS.Print("button #" .. record.id .. ": " .. record.data.status)
        NS.Print("Placement only: Hint is disabled. /jahdiag clear removes it.")
    elseif command == "list" then
        local entries = NS.Adapter.Quests()
        local record = NS.Record("quest-list", entries)
        if entries.status == "ok" then
            for _, entry in ipairs(entries.value) do
                if entry.status == "ok" then NS.Print(entry.value.questID .. " — " .. entry.value.title)
                else NS.Print("quest-log entry: " .. entry.status) end
            end
        else NS.Print("quest list: " .. entries.status) end
        NS.Print("capture #" .. record.id .. "; no quest was selected or navigated.")
    elseif command == "scan" then
        if not phases[rest] then help(); return end
        local quests = NS.Adapter.Quests()
        local results = {}
        if quests.status == "ok" then
            for _, entry in ipairs(quests.value) do
                if entry.status == "ok" then
                    local result = NS.Adapter.Probe(entry.value.questID, rest, "unclassified")
                    result.title = entry.value.title
                    results[#results + 1] = result
                end
            end
        end
        local record = NS.Record("scan", { context = NS.Adapter.Context(rest, "unclassified"),
            capabilities = NS.Adapter.Capabilities(), questListStatus = quests.status, results = results })
        local destinations = 0
        for _, result in ipairs(results) do
            if result.destination and result.destination.status == "ok" then destinations = destinations + 1 end
        end
        NS.Print("scan #" .. record.id .. ": " .. #results .. " quests; " .. destinations .. " returned destinations.")
        NS.Print("No guidance drawn. /reload flushes captures; external evidence import can then read them.")
    elseif command == "isolate" then
        local result = NS.Isolation.Start()
        local record = NS.Record("isolation", result)
        if NS.Isolation.active then NS.Isolation.active.recordID = record.id end
        NS.Print("map isolation #" .. record.id .. ": " .. result.status)
        if result.status == "frames-hidden-unverified" then Panel.ShowQuests("isolated")
        elseif result.status == "requires-questPOI-1" then
            NS.Print("Restore map objectives with /console questPOI 1 before this comparison.")
        end
    elseif command == "silent" then
        NS.SilentRegion.Start(tonumber(rest))
    elseif command == "region" then
        NS.Region.Start()
    elseif command == "restore" then
        NS.Isolation.Stop("manual")
    elseif command == "probe" or command == "area" then
        if command == "area" and (rest == "" or phases[rest]) then
            Panel.ShowQuests(rest == "" and "normal" or rest)
            return
        end
        local id, phase, category, note = rest:match("^(%d+)%s+(%S+)%s+(%S+)%s*(.*)$")
        id = tonumber(id)
        if not NS.ID(id) or not phases[phase] or not categories[category] then help(); return end
        if phase == "isolated" then
            NS.Isolation.Check()
            if not NS.Isolation.active then
                NS.Print("The map comparison has ended. Run /jahdiag isolate on the open map to start again.")
                return
            end
        end
        local data
        if command == "probe" then data = NS.Adapter.Probe(id, phase, category, note)
        else
            local questProbe = NS.Adapter.Probe(id, phase, category, note)
            data = NS.Area.Show(id, phase, category, note)
            data.questProbe = questProbe
        end
        local record = NS.Record(command, data)
        if command == "area" then
            if NS.Area.active then NS.Area.active.recordID = record.id end
            NS.AreaPanel.Show(data, record.id, "area " .. rest)
        end
        NS.Print(command .. " #" .. record.id .. ": " .. data.status)
        if data.destination then NS.Print("destination: " .. data.destination.status
            .. "; objectives: " .. data.objectives.status) end
        if command == "area" and data.status == "call-ok-unverified" then
            NS.Print("Use the area comparison panel: Hide area / Show area. Drag its background to move it.")
        end
    elseif command == "observe" then
        local id, outcome, note = rest:match("^(%d+)%s+(%S+)%s*(.*)$")
        local record = findRecord(tonumber(id))
        if not record or record.kind ~= "area" or record.data.status ~= "call-ok-unverified"
            or (outcome ~= "visible" and outcome ~= "none" and outcome ~= "other-quests") then
            NS.Print("Observe a call-ok-unverified area capture using visible, none, or other-quests.")
            return
        end
        -- Observation evidence remains separate from the API invocation status.
        NS.Record("area-observation", { areaRecordID = record.id, visualResult = outcome, testerNote = note })
        NS.Print("Observation saved for area capture #" .. record.id .. ".")
    elseif command == "note" then
        if rest == "" then NS.Print("Usage: /jahdiag note your test observations"); return end
        local record = NS.Record("tester-note", { text = rest })
        NS.Print("note saved as capture #" .. record.id)
    elseif command == "clear" then
        NativeButton.Clear("manual")
        NS.SilentRegion.Finish("cancelled", "manual")
        NS.Area.Clear()
        NS.Print("Diagnostic previews cleared.")
    elseif command == "report" or command == "export" then
        if not NS.DB then NS.Initialize() end
        local record = rest ~= "" and findRecord(tonumber(rest)) or nil
        if rest ~= "" and not record then NS.Print("Capture not found."); return end
        local report = NS.Report(record)
        if command == "export" then export(report)
        else for line in report:gmatch("[^\n]+") do NS.Print(line) end end
    else help() end
end

function NS.RunCommand(message)
    local ok, reason = pcall(NS.Command, message)
    if not ok then
        NS.SilentRegion.Finish("cancelled", "command-failed")
        NativeButton.Clear("command-failed")
        NS.Isolation.Stop("command-failed")
        NS.Area.Clear("command-failed")
        NS.Print("Diagnostic failed: " .. tostring(reason))
    end
end

SLASH_JUSTAHINTDIAGNOSTICS1 = "/jahdiag"
SlashCmdList.JUSTAHINTDIAGNOSTICS = NS.RunCommand

local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:RegisterEvent("QUEST_LOG_UPDATE")
events:SetScript("OnEvent", function(_, event, loadedAddon)
    if event == "ADDON_LOADED" and loadedAddon == addonName then NS.Initialize()
    elseif event == "PLAYER_ENTERING_WORLD" or event == "QUEST_LOG_UPDATE" then
        NS.SilentRegion.Finish("cancelled", event)
        NativeButton.Clear(event)
        -- Milestone 0 previews are disposable. Product lifecycle rules come later.
        NS.Area.Clear(event)
        NS.Isolation.Stop(event)
    end
end)
