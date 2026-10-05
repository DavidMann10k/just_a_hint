local _, NS = ...
local Area = {}
NS.Area = Area

local function positive(value)
    return type(value) == "number" and value > 0 and value < math.huge
end

function Area.Clear()
    Area.active = nil -- OnHide must not recurse into Hints.Clear.
    if Area.marker then Area.marker:Hide() end
    if Area.frame then
        pcall(Area.frame.DrawNone, Area.frame)
        Area.frame:Hide()
    end
end

local function context(mapID)
    local map = WorldMapFrame
    if not map or not map:IsShown() then return nil, "map-closed" end
    if map:GetMapID() ~= mapID then return nil, "map-changed" end
    local canvas = map:GetCanvas()
    if not canvas then return nil, "map-canvas-unavailable" end
    local width, height, scale = canvas:GetWidth(), canvas:GetHeight(), canvas:GetEffectiveScale()
    if not positive(width) or not positive(height) or not positive(scale) then
        return nil, "map-size-unavailable"
    end
    return { map = map, canvas = canvas, width = width, height = height, scale = scale }
end

local function marker(active, current)
    local point = active.point
    if not point or point.mapID ~= active.mapID or type(point.x) ~= "number" or type(point.y) ~= "number"
        or point.x ~= point.x or point.y ~= point.y or point.x < 0 or point.x > 1
        or point.y < 0 or point.y > 1 then error("nearby-point-unavailable") end
    if not Area.marker then
        local frame = CreateFrame("Frame", nil, current.canvas)
        Area.marker = frame
        frame:Hide()
        frame:EnableMouse(false)
        local atlas
        for _, candidate in ipairs({ "Waypoint-MapPin-Untracked", "QuestNormal" }) do
            local ok, info = NS.Call("C_Texture.GetAtlasInfo", candidate)
            if ok and type(info) == "table" and positive(info.width) and positive(info.height) then atlas = candidate; break end
        end
        if not atlas then error("built-in-map-pin-unavailable") end
        local texture = frame:CreateTexture(nil, "OVERLAY")
        texture:SetAtlas(atlas)
        texture:SetAllPoints(frame)
        frame.ready = true
        NS.Note("nearbyPinArtwork", atlas)
    end
    if not Area.marker.ready then error("nearby-pin-setup-incomplete") end
    Area.marker:SetParent(current.canvas)
    Area.marker:SetFrameLevel(Area.frame:GetFrameLevel() + 1)
    Area.marker:SetSize(12 / current.scale, 12 / current.scale)
    Area.marker:ClearAllPoints()
    Area.marker:SetPoint("CENTER", current.canvas, "TOPLEFT", point.x * current.width, -point.y * current.height)
    Area.marker:Show()
end

function Area.IsVisible(id)
    local active = Area.active
    if not active or active.id ~= id or not active.drawn then return false end
    if active.presentation == "region" then return Area.frame:IsVisible() == true end
    if active.presentation == "point" then return Area.marker and Area.marker:IsVisible() == true or false end
    return false
end

local function acknowledge(active)
    if active.notify and Area.IsVisible(active.id) then
        active.notify = nil
        if NS.Feedback then NS.Feedback.AreaRequested() end
    end
end

local function finishProbe(active, current, region)
    active.probe = nil
    active.presentation = region and "region" or "point"
    if not region then
        -- A missed sample means unconfirmed, not proof that no region exists.
        Area.frame:DrawNone()
        marker(active, current)
    end
    NS.Note("area", region and "region confirmed by matching native query"
        or "native point shown; region unconfirmed")
    acknowledge(active)
end

function Area.Probe(dt)
    local active = Area.active
    if not active or not active.probe or not active.drawn then return end
    local ok, err = pcall(function()
        local current, why = context(active.mapID)
        if not current or current.canvas ~= active.canvas then error(why or "area-canvas-changed") end
        local probe = active.probe
        if type(dt) ~= "number" or dt ~= dt or dt < 0 then return end
        probe.wait = probe.wait - dt
        if probe.wait > 0 then return end
        if type(Area.frame.UpdateMouseOverTooltip) ~= "function" then finishProbe(active, current, false); return end
        -- Test the native destination first, then a bounded 33-by-33 grid.
        -- Work is spread across frames; only this requested quest can confirm it.
        for _ = 1, 64 do
            local x, y
            if probe.index == -1 then
                if active.point then x, y = active.point.x, active.point.y end
            else x, y = (probe.index % 33) / 32, math.floor(probe.index / 33) / 32 end
            probe.index = probe.index + 1
            if type(x) == "number" and type(y) == "number" then
                local id = Area.frame:UpdateMouseOverTooltip(x, y)
                if id == active.id then finishProbe(active, current, true); return end
            end
            if probe.index >= 1089 then finishProbe(active, current, false); return end
        end
    end)
    if not ok then
        NS.Note("nearbyPresentationError", err)
        NS.Hints.Clear("nearby-renderer-unavailable")
        if NS.Message then NS.Message("The nearby hint could not be displayed. Use /jah status for details.") end
    end
end

function Area.Check()
    if not Area.active then return false, "area-closed" end
    local ok, current, reason = pcall(context, Area.active.mapID)
    if not ok then return false, "area-map-unavailable" end
    if not current then return false, reason end
    if current.canvas ~= Area.active.canvas then return false, "area-canvas-changed" end
    return true
end

function Area.Suspend()
    if not Area.active then return false end
    local ok = pcall(Area.frame.DrawNone, Area.frame)
    Area.active.drawn = false
    Area.active.probe = nil
    if Area.marker then Area.marker:Hide() end
    if not ok then Area.Clear() end
    return ok
end

function Area.Show(id, mapID, point)
    Area.Clear()
    if NS.InCombat() then return false, "Leave combat, then ask for the area hint again." end
    if not NS.ID(id) or not NS.ID(mapID) then return false, "A search area is unavailable here." end
    local ok, err = pcall(function()
        -- Open the map only from an explicit nearby Hint request. Do not select,
        -- focus, supertrack, or navigate to the quest as a map-opening shortcut.
        local opened, why = NS.Call("OpenWorldMap", mapID)
        if not opened then error(why) end
        local current, reason = context(mapID)
        if not current then error(reason) end
        local manager = current.map.pinFrameLevelsManager
        if not manager or type(manager.GetValidFrameLevel) ~= "function" then
            error("map-frame-level-api-unavailable")
        end
        local level = manager:GetValidFrameLevel("PIN_FRAME_LEVEL_QUEST_BLOB")
        if type(level) ~= "number" or level < 0 or level >= math.huge or level % 1 ~= 0 then
            error("map-frame-level-unavailable")
        end
        if not Area.frame then
            -- A bare native frame: Blizzard's template would read supertracking.
            Area.frame = CreateFrame("QuestPOIFrame", nil, current.canvas)
            Area.frame:Hide()
            Area.frame:SetScript("OnHide", function()
                if Area.active then NS.Hints.Clear("area-map-hidden") end
            end)
            Area.frame:SetScript("OnUpdate", function(_, dt)
                if not Area.active then return end
                local valid, why = Area.Check()
                if not valid then NS.Hints.Clear(why); return end
                Area.Probe(dt)
            end)
        end
        local frame = Area.frame
        frame:SetParent(current.canvas)
        frame:ClearAllPoints()
        frame:SetAllPoints(current.canvas)
        frame:SetFrameLevel(level)
        frame:EnableMouse(false)
        frame:SetFillTexture("Interface\\WorldMap\\UI-QuestBlob-Inside")
        frame:SetBorderTexture("Interface\\WorldMap\\UI-QuestBlob-Outside")
        frame:SetFillAlpha(192)
        frame:SetBorderAlpha(255)
        frame:SetBorderScalar(1.0)
        frame:DrawNone()
        frame:SetMapID(mapID)
        frame:Show()
        -- Draw on the next validated update, after the newly opened map lays out.
        Area.active = { id = id, mapID = mapID, canvas = current.canvas, point = point, notify = true, presentation = "checking" }
    end)
    if not ok then
        Area.Clear()
        NS.Note("areaError", err)
        return false, "A search area is unavailable here. Use /jah status for details."
    end
    NS.Note("area", "requested; waiting for map layout")
    return true
end

function Area.Update()
    local active = Area.active
    if not active then return false, "area-closed" end
    local ok, reason = pcall(function()
        local current, why = context(active.mapID)
        if not current then return why end
        if current.canvas ~= active.canvas then return "area-canvas-changed" end
        if not active.drawn or current.width ~= active.width or current.height ~= active.height
            or current.scale ~= active.scale then
            -- Lifecycle validation in Hints.Update precedes every redraw. Zoom
            -- may redraw this authorized quest, never acquire another quest.
            if active.presentation == "point" then
                marker(active, current)
            else
                Area.frame:DrawNone()
                Area.frame:SetMapID(active.mapID)
                Area.frame:DrawBlob(active.id, true)
                if active.presentation == "checking" then active.probe = { wait = 0.15, index = -1 } end
            end
            active.drawn = true
            active.width, active.height, active.scale = current.width, current.height, current.scale
            acknowledge(active)
            if active.presentation == "checking" then NS.Note("area", "native draw requested; checking region") end
        end
    end)
    if not ok then NS.Note("areaError", reason); return false, "area-renderer-unavailable" end
    if reason then return false, reason end
    return true
end
