local _, NS = ...
local Feedback = {}
NS.Feedback = Feedback

local directions = { "north", "northeast", "east", "southeast", "south",
    "southwest", "west", "northwest" }
local REVEAL, HOLD, TRAVEL, PULSE = 0.18, 0.12, 0.68, 1.2
local FLIGHT = REVEAL + HOLD + TRAVEL
local ARRIVAL_PULSE, ARRIVAL_COUNT = 0.6, 2

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

local function finishFlight()
    Feedback.flying = nil
    if Feedback.frame and Feedback.frame.flight then
        Feedback.frame.flight:Hide()
        for _, texture in ipairs(Feedback.frame.trail) do texture:Hide() end
    end
    local arrow = NS.Bearing.frame and NS.Bearing.frame.arrow
    if arrow then pcall(function() arrow:SetAlpha(1) end) end
end

function Feedback.Hide()
    Feedback.elapsed, Feedback.owner, Feedback.pulseStart, Feedback.arriving = nil, nil, nil, nil
    finishFlight()
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

local function colorRing(pieces, r, g, b)
    for _, texture in ipairs(pieces) do texture:SetColorTexture(r, g, b, 1) end
end

local function ensureFrame()
    if not Feedback.frame then
        -- UIParent keeps the flight and pulses outside the minimap's bounds.
        local frame = CreateFrame("Frame", "JustAHintFeedback", UIParent)
        Feedback.frame = frame
        frame:Hide()
        frame:SetAllPoints(UIParent)
        frame:SetFrameStrata("TOOLTIP")
        frame:EnableMouse(false)
        frame.rim, frame.halo = ring(frame, 64), ring(frame, 24)
        frame:SetScript("OnUpdate", function(_, dt) Feedback.Update(dt) end)
    end
    if not Feedback.frame.rim or not Feedback.frame.halo then error("Minimap pulse rendering is unavailable.") end
    return Feedback.frame
end

local function drawRing(pieces, parent, cx, cy, radius, alpha)
    for i, texture in ipairs(pieces) do
        local angle = (i - 1) * 2 * math.pi / #pieces
        texture:SetSize(2 * math.pi * radius / #pieces + 1, 2)
        texture:SetRotation(angle + math.pi / 2)
        texture:ClearAllPoints()
        texture:SetPoint("CENTER", parent, "BOTTOMLEFT", cx + math.cos(angle) * radius, cy + math.sin(angle) * radius)
        texture:SetAlpha(alpha)
    end
end

local function finite(value)
    return type(value) == "number" and value == value and value > -math.huge and value < math.huge
end

local function geometry()
    local left, bottom, width, height = Minimap:GetRect()
    local scale = Minimap:GetEffectiveScale() / UIParent:GetEffectiveScale()
    if not finite(left) or not finite(bottom) or not finite(width) or not finite(height)
        or not finite(scale) or width <= 32 or height <= 32 or scale <= 0 then
        error("Minimap animation geometry is unavailable.")
    end
    local cx, cy = (left + width / 2) * scale, (bottom + height / 2) * scale
    local radius = math.min(width, height) / 2
    local x, y = Feedback.x or 0, Feedback.y or 1
    return cx, cy, radius * scale, cx + x * (radius - 16) * scale,
        cy + y * (radius - 16) * scale, scale
end

local function rotation(x, y)
    local length = math.sqrt(x * x + y * y)
    if length == 0 then return 0 end
    local angle = math.acos(math.max(-1, math.min(1, y / length)))
    return x > 0 and -angle or angle
end

local function flightTexture(frame)
    local texture = frame:CreateTexture(nil, "OVERLAY")
    texture:SetAtlas(NS.Bearing.atlas)
    texture:SetVertexColor(1, 0.82, 0.35)
    texture:Hide()
    return texture
end

local function drawFlight(tx, ty, scale)
    local frame = Feedback.frame
    local sx, sy = UIParent:GetWidth() / 2, UIParent:GetHeight() / 2
    local dx, dy = tx - sx, ty - sy
    local arrow = NS.Bearing.frame.arrow
    local width, height = arrow:GetWidth() * scale, arrow:GetHeight() * scale
    local startAngle = rotation(dx, dy)
    local turn = (rotation(Feedback.x or 0, Feedback.y or 1) - startAngle + math.pi) % (2 * math.pi) - math.pi
    local function draw(texture, elapsed, alpha)
        local progress = math.max(0, math.min(1, (elapsed - REVEAL - HOLD) / TRAVEL))
        local eased = progress * progress * (3 - 2 * progress)
        -- A gentle quadratic arc, sampled again for the trailing arrow echoes.
        local bend = 2 * eased * (1 - eased) * 0.12
        local x, y = sx + dx * eased - dy * bend, sy + dy * eased + dx * bend
        local reveal = math.max(0, math.min(1, elapsed / REVEAL))
        local size = (40 + 24 * math.sin(reveal * math.pi / 2)) * (1 - eased)
            + math.max(width, height) * eased
        local aspect = math.max(width, height)
        texture:SetSize(size * width / aspect, size * height / aspect)
        texture:SetRotation(startAngle + turn * eased)
        texture:ClearAllPoints()
        texture:SetPoint("CENTER", frame, "BOTTOMLEFT", x, y)
        texture:SetAlpha(alpha * reveal)
        texture:Show()
    end
    for index, texture in ipairs(frame.trail) do
        local age = Feedback.elapsed - index * 0.035
        if age > REVEAL + HOLD then draw(texture, age, 0.22 * (1 - index / (#frame.trail + 1)))
        else texture:Hide() end
    end
    draw(frame.flight, Feedback.elapsed, 1)
    arrow:SetAlpha(0)
end

function Feedback.Update(dt)
    if not Feedback.elapsed then return end
    local ok, err = pcall(function()
        if Feedback.arriving then
            -- The request has already been cleared. Arrival acknowledges its
            -- end without retaining a bearing or revealing another hint.
            if NS.Hints.active or NS.Hints.controller.reason ~= "arrived"
                or not NS.Guard.active or NS.Guard.problem or not Minimap:IsVisible()
                or not NS.DB.presentation.minimapPulse then Feedback.Hide(); return end
            if not finite(dt) or dt < 0 or dt > 0.5 then Feedback.Hide(); return end
            Feedback.elapsed = Feedback.elapsed + dt
            if Feedback.elapsed >= ARRIVAL_PULSE * ARRIVAL_COUNT then Feedback.Hide(); return end
            local cx, cy, radius, _, _, scale = geometry()
            local phase = (Feedback.elapsed % ARRIVAL_PULSE) / ARRIVAL_PULSE
            drawRing(Feedback.frame.rim, Feedback.frame, cx, cy, radius + (3 + phase * 9) * scale,
                0.7 * math.sin(phase * math.pi) ^ 2)
            return
        end
        if NS.Hints.active ~= Feedback.owner or NS.Hints.controller.mode ~= "bearing" or not NS.Hints.controller.visible
            or not NS.Guard.active or NS.Guard.problem or not Minimap:IsVisible()
            or not NS.Bearing.frame or not NS.Bearing.frame:IsVisible() then Feedback.Hide(); return end
        if not finite(dt) or dt < 0 or dt > 0.5 then Feedback.Hide(); return end
        Feedback.elapsed = Feedback.elapsed + dt
        local options = NS.DB.presentation
        if Feedback.flying and (not options.arrowFlight or Feedback.elapsed >= FLIGHT) then
            finishFlight()
            Feedback.pulseStart = Feedback.elapsed
        end
        if not Feedback.flying and (not options.arrowPulse and not options.minimapPulse
            or Feedback.elapsed - Feedback.pulseStart >= PULSE) then Feedback.Hide(); return end
        local cx, cy, radius, ax, ay, scale = geometry()
        if Feedback.flying then drawFlight(ax, ay, scale) end
        local phase = math.max(0, (Feedback.elapsed - Feedback.pulseStart) / PULSE)
        local alpha = (1 - phase) ^ 2 * math.sin(math.min(1, phase * 8) * math.pi / 2)
        drawRing(Feedback.frame.rim, Feedback.frame, cx, cy, radius + (3 + phase * 9) * scale,
            options.minimapPulse and alpha * 0.7 or 0)
        drawRing(Feedback.frame.halo, Feedback.frame, ax, ay, (17 + phase * 12) * scale,
            options.arrowPulse and alpha or 0)
    end)
    if not ok then Feedback.Hide(); NS.Note("feedbackError", err) end
end

function Feedback.Arrived(owner)
    local ok, err = pcall(function()
        if type(owner) ~= "table" or owner.arrivalNotified or NS.Hints.active
            or NS.Hints.controller.mode ~= "none" or NS.Hints.controller.reason ~= "arrived" then return end
        owner.arrivalNotified = true
        if not NS.Guard.active or NS.Guard.problem or not Minimap or not Minimap:IsVisible() then return end
        Feedback.Hide()
        local options = NS.DB.presentation
        if options.sound and SOUNDKIT and NS.ID(SOUNDKIT.MAP_PING) then
            NS.Call("PlaySound", SOUNDKIT.MAP_PING, "SFX")
        end
        if not options.minimapPulse then return end
        local frame = ensureFrame()
        colorRing(frame.rim, 0.35, 0.9, 0.5)
        for _, texture in ipairs(frame.halo) do texture:SetAlpha(0) end
        Feedback.arriving, Feedback.elapsed = owner, 0
        frame:Show()
        Feedback.Update(0)
    end)
    if not ok then Feedback.Hide(); NS.Note("feedbackError", err) end
end

function Feedback.BearingRequested(sample)
    local ok, err = pcall(function()
        -- No delayed notification: missing/hidden rendering must remain quiet.
        if not NS.Hints.active or NS.Hints.controller.mode ~= "bearing" or not NS.Hints.controller.visible
            or not NS.Bearing.frame or not NS.Bearing.frame:IsVisible() then return end
        local options = NS.DB.presentation
        chat(Feedback.Text(sample))
        if options.sound and SOUNDKIT and type(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON) == "number" then
            NS.Call("PlaySound", SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON, "SFX")
        end
        if not options.arrowFlight and not options.arrowPulse and not options.minimapPulse then return end
        Feedback.Hide()
        ensureFrame()
        colorRing(Feedback.frame.rim, 1, 0.82, 0.35)
        if options.arrowFlight and not Feedback.frame.flight then
            Feedback.frame.trail = {}
            for index = 1, 5 do Feedback.frame.trail[index] = flightTexture(Feedback.frame) end
            Feedback.frame.flight = flightTexture(Feedback.frame)
        end
        Feedback.owner = NS.Hints.active
        Feedback.elapsed = 0
        Feedback.flying = options.arrowFlight or nil
        Feedback.pulseStart = Feedback.flying and FLIGHT or 0
        Feedback.frame:Show()
        Feedback.Update(0)
    end)
    if not ok then Feedback.Hide(); NS.Note("feedbackError", err) end
end
