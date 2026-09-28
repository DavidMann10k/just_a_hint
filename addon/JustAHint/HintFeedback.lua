local _, NS = ...
local Feedback = {}
NS.Feedback = Feedback

local directions = { "north", "northeast", "east", "southeast", "south",
    "southwest", "west", "northwest" }

function Feedback.Text(sample)
    local east = sample.player.y - sample.target.y
    local north = sample.target.x - sample.player.x
    local length = math.sqrt(east * east + north * north)
    if length == 0 then return nil end
    local angle = math.acos(math.max(-1, math.min(1, north / length)))
    if east < 0 then angle = 2 * math.pi - angle end
    local direction = directions[math.floor(angle / (math.pi / 4) + 0.5) % 8 + 1]
    -- Broad phrasing uses the same native units as arrival; never claim yards.
    local distance = sample.distance < 350 and "It's not far from here."
        or sample.distance < 1000 and "It's a fair way from here."
        or "It's a long way from here."
    return "Head " .. direction .. ". " .. distance
end

local function chat(text)
    if not NS.DB.presentation.text or not text then return end
    local now = GetTime()
    if text ~= Feedback.lastText or not Feedback.lastTime or now < Feedback.lastTime
        or now - Feedback.lastTime >= 10 then
        NS.Message(text)
        Feedback.lastText, Feedback.lastTime = text, now
    end
end

function Feedback.AreaRequested()
    local ok, err = pcall(function()
        local area = NS.Area and NS.Area.active
        if not NS.Guard.active or NS.Guard.problem or not area or not area.drawn
            or not NS.Hints.active or NS.Hints.active.id ~= area.id
            or NS.Hints.controller.mode ~= "area" or not NS.Hints.controller.visible
            or not NS.Area.IsVisible(area.id) then return end
        chat(area.presentation == "point" and "You're close. Look around the marked spot."
            or "You're close. Search around here.")
    end)
    if not ok then NS.Note("feedbackError", err) end
end

function Feedback.Hide()
    Feedback.elapsed = nil
    if Feedback.frame then Feedback.frame:Hide() end
end

local function ring(parent, count)
    local pieces = {}
    for i = 1, count do
        local texture = parent:CreateTexture(nil, "OVERLAY")
        texture:SetColorTexture(1, 0.82, 0.35, 1)
        pieces[i] = texture
    end
    return pieces
end

local function drawRing(pieces, parent, cx, cy, radius, alpha)
    for i, texture in ipairs(pieces) do
        local angle = (i - 1) * 2 * math.pi / #pieces
        texture:SetSize(2 * math.pi * radius / #pieces + 1, 2)
        texture:SetRotation(angle + math.pi / 2)
        texture:ClearAllPoints()
        texture:SetPoint("CENTER", parent, "CENTER", cx + math.cos(angle) * radius, cy + math.sin(angle) * radius)
        texture:SetAlpha(alpha)
    end
end

function Feedback.Update(dt)
    if not Feedback.elapsed then return end
    local ok, err = pcall(function()
        if not NS.Hints.active or NS.Hints.controller.mode ~= "bearing" or not NS.Hints.controller.visible
            or not NS.Guard.active or NS.Guard.problem or not Minimap:IsVisible()
            or not NS.Bearing.frame or not NS.Bearing.frame:IsVisible() then Feedback.Hide(); return end
        Feedback.elapsed = Feedback.elapsed + dt
        if Feedback.elapsed >= 1.2 then Feedback.Hide(); return end
        local options = NS.DB.presentation
        if not options.arrowPulse and not options.minimapPulse then Feedback.Hide(); return end
        local phase = Feedback.elapsed / 1.2
        local alpha = math.sin(phase * math.pi * 2) ^ 2 * (1 - phase)
        local radius = math.min(Minimap:GetWidth(), Minimap:GetHeight()) / 2
        local x, y = Feedback.x or 0, Feedback.y or 1
        drawRing(Feedback.frame.rim, Feedback.frame, 0, 0, radius + 3 + phase * 5,
            options.minimapPulse and alpha * 0.7 or 0)
        drawRing(Feedback.frame.halo, Feedback.frame, x * (radius - 16), y * (radius - 16), 17 + phase * 7,
            options.arrowPulse and alpha or 0)
    end)
    if not ok then Feedback.Hide(); NS.Note("feedbackError", err) end
end

function Feedback.BearingRequested(sample)
    local ok, err = pcall(function()
        -- No delayed notification: missing/hidden rendering must remain quiet.
        if not NS.Hints.active or NS.Hints.controller.mode ~= "bearing" or not NS.Hints.controller.visible
            or not NS.Bearing.frame or not NS.Bearing.frame:IsVisible() then return end
        local active = NS.Hints.active
        -- NativeQuestPane owns map closing after its explicit button click.
        if NS.Hints.active ~= active or NS.Hints.controller.mode ~= "bearing" or not NS.Hints.controller.visible then return end
        local options = NS.DB.presentation
        chat(Feedback.Text(sample))
        if options.sound and SOUNDKIT and type(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON) == "number" then
            NS.Call("PlaySound", SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON, "SFX")
        end
        if not options.arrowPulse and not options.minimapPulse then return end
        if not Feedback.frame then
            local frame = CreateFrame("Frame", "JustAHintFeedback", Minimap)
            Feedback.frame = frame
            frame:Hide()
            frame:SetAllPoints(Minimap)
            frame:SetFrameLevel(Minimap:GetFrameLevel() + 21)
            frame:EnableMouse(false)
            frame.rim, frame.halo = ring(frame, 64), ring(frame, 24)
            frame:SetScript("OnUpdate", function(_, dt) Feedback.Update(dt) end)
        end
        if not Feedback.frame.rim or not Feedback.frame.halo then error("Minimap pulse rendering is unavailable.") end
        Feedback.elapsed = 0
        Feedback.frame:Show()
    end)
    if not ok then Feedback.Hide(); NS.Note("feedbackError", err) end
end
