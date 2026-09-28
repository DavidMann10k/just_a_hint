local _, NS = ...
local Controller = {}
Controller.__index = Controller
NS.HintController = Controller

local function finite(value)
    return type(value) == "number" and value == value and value > -math.huge and value < math.huge
end

function Controller.New(radius, dwell)
    return setmetatable({ radius = radius or 150, dwell = dwell or 1, mode = "none", visible = false }, Controller)
end

function Controller:Clear(reason)
    self.mode, self.visible = "none", false
    self.questID, self.nearSince, self.lastSample = nil, nil, nil
    self.reason = reason or "cleared"
end

-- Requests determine disclosure from proximity, never from click count.
function Controller:Request(questID, distance, now)
    self:Clear("requested")
    if not finite(distance) or distance < 0 or not finite(now) then return self.mode end
    self.questID = questID
    self.mode = distance <= self.radius and "area" or "bearing"
    self.visible, self.lastSample = true, now
    return self.mode
end

function Controller:Update(distance, now)
    if self.mode ~= "bearing" then return self.mode end
    if not finite(distance) or distance < 0 or not finite(now) then
        self.visible, self.nearSince, self.lastSample = false, nil, nil
        return self.mode
    end
    -- A stall, lost position, or clock discontinuity cannot count as continuous arrival.
    if not self.lastSample or now < self.lastSample or now - self.lastSample > 0.5 then self.nearSince = nil end
    self.lastSample, self.visible = now, true
    if distance <= self.radius then
        self.nearSince = self.nearSince or now
        if now - self.nearSince >= self.dwell then self:Clear("arrived") end
    else self.nearSince = nil end
    return self.mode
end

-- World coordinates in the tested zone have north=+X and west=+Y.
-- Facing is counterclockwise from north. Rotating minimaps put facing at the top.
function Controller.ScreenDirection(east, north, facing)
    if not finite(east) or not finite(north) or not finite(facing) then return nil end
    local length = math.sqrt(east * east + north * north)
    if not finite(length) or length == 0 then return nil end
    local cosine, sine = math.cos(facing), math.sin(facing)
    return (east * cosine + north * sine) / length, (north * cosine - east * sine) / length
end
