local _, NS = ...
local Bearing = {}
NS.Bearing = Bearing

-- These names come from Blizzard's navigation and map UI. Their presence in
-- another client's source is not a compatibility guarantee; probe this client.
local function artwork()
    for _, atlas in ipairs({ "Navigation-Tracked-Arrow", "UI-WorldMapArrow" }) do
        local ok, info = NS.Call("C_Texture.GetAtlasInfo", atlas)
        if ok and type(info) == "table" and type(info.width) == "number"
            and type(info.height) == "number" and info.width > 0 and info.width < math.huge
            and info.height > 0 and info.height < math.huge then
            return atlas, info.width, info.height
        end
    end
    error("Built-in arrow artwork is unavailable in this client.")
end

function Bearing.Hide()
    if NS.Feedback then NS.Feedback.Hide() end
    if Bearing.frame then Bearing.frame:Hide() end
end

function Bearing.Show(x, y)
    local ok, err = pcall(function()
        if not Minimap or not Minimap:IsVisible() then Bearing.Hide(); return end
        if not Bearing.frame then
            local atlas, width, height = artwork()
            local frame = CreateFrame("Frame", "JustAHintBearing", Minimap)
            frame:Hide()
            Bearing.frame = frame -- Hide partial construction if any method fails.
            frame:SetAllPoints(Minimap)
            frame:SetFrameLevel(Minimap:GetFrameLevel() + 20)
            frame:EnableMouse(false)
            local texture = frame:CreateTexture(nil, "OVERLAY")
            texture:SetAtlas(atlas)
            texture:SetVertexColor(1, 0.82, 0.35)
            local scale = 24 / math.max(width, height)
            texture:SetSize(width * scale, height * scale)
            frame.arrow = texture
            frame.ready = true
            Bearing.atlas = atlas
        end
        local frame = Bearing.frame
        if not frame.ready then error("Built-in arrow rendering is unavailable.") end
        local radius = math.min(Minimap:GetWidth(), Minimap:GetHeight()) / 2 - 16
        if radius <= 0 then error("Minimap size is unavailable.") end
        -- Both native arrows face up at zero rotation. Texture rotation is
        -- counterclockwise; x/y are the controller's normalized screen bearing.
        local rotation = math.acos(math.max(-1, math.min(1, y)))
        if x > 0 then rotation = -rotation end
        frame.arrow:SetRotation(rotation)
        frame.arrow:SetAlpha(NS.Feedback and NS.Feedback.flying and 0 or 1)
        frame.arrow:ClearAllPoints()
        frame.arrow:SetPoint("CENTER", frame, "CENTER", x * radius, y * radius)
        frame:Show()
    end)
    if not ok then Bearing.Hide(); return false, tostring(err) end
    return true
end
