local _, NS = ...
NS.VERSION = "0.7.1"

function NS.Initialize()
    if type(JustAHintDB) ~= "table" then JustAHintDB = {} end
    NS.DB = JustAHintDB
    NS.DB.lastCheck = {} -- Runtime observations must not carry stale prototype state across reload.
    NS.DB.schema = 1
    NS.DB.recovery = NS.DB.recovery or { minimap = {} }
    NS.DB.recovery.minimap = NS.DB.recovery.minimap or {}
    if type(NS.DB.presentation) ~= "table" then NS.DB.presentation = {} end
    for _, key in ipairs({ "arrowFlight", "arrowPulse", "minimapPulse", "sound", "text" }) do
        if type(NS.DB.presentation[key]) ~= "boolean" then NS.DB.presentation[key] = true end
    end
    NS.DB.presentation.standalone = nil -- Retired reader-mode preference.
    -- No selected quest, hint, location, or open reader is saved.
end

function NS.Message(message)
    if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage("|cffffd16aJust a Hint:|r " .. tostring(message)) end
end

function NS.Resolve(path)
    local value = _G
    for part in path:gmatch("[^.]+") do
        if type(value) ~= "table" then return nil end
        value = value[part]
    end
    return value
end

function NS.Call(path, ...)
    local fn = NS.Resolve(path)
    if type(fn) ~= "function" then return false, "Missing " .. path end
    return pcall(fn, ...)
end

function NS.ID(value)
    return type(value) == "number" and value > 0 and value < math.huge and value % 1 == 0
end

function NS.InCombat()
    return type(InCombatLockdown) == "function" and InCombatLockdown()
end

function NS.Note(key, value)
    NS.DB.lastCheck = NS.DB.lastCheck or {}
    NS.DB.lastCheck[key] = tostring(value)
end

-- Observe the client's restriction event without replacing its error handler,
-- dismissing its popup or trying the blocked action again.
function NS.RecordSecurity(event, ...)
    if not NS.DB then return end
    local records = NS.DB.securityEvents
    if type(records) ~= "table" then records = {}; NS.DB.securityEvents = records end
    local record = { event = event, version = NS.VERSION, arguments = {} }
    for index = 1, math.min(select("#", ...), 6) do
        local value = select(index, ...)
        local ok, text = pcall(function()
            if type(value) == "string" or type(value) == "number" or type(value) == "boolean" then
                return tostring(value):sub(1, 512)
            end
            return "<unavailable>"
        end)
        record.arguments[index] = ok and text or "<unreadable>"
    end
    records[#records + 1] = record
    while #records > 5 do table.remove(records, 1) end
end
