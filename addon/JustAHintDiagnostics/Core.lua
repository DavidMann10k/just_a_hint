local _, NS = ...

NS.VERSION = "0.0.10"
NS.MAX_RECORDS = 100
local unpackValues = unpack or table.unpack

function NS.Resolve(path)
    local value = _G
    for component in path:gmatch("[^.]+") do
        if type(value) ~= "table" then return nil end
        value = value[component]
    end
    return value
end

function NS.Number(value)
    return type(value) == "number" and value == value
        and value > -math.huge and value < math.huge
end

function NS.ID(value)
    return NS.Number(value) and value > 0 and value % 1 == 0
end

-- Normalizers run inside the protected call too: successful API invocation
-- does not imply that returned values can safely be inspected.
function NS.Read(path, normalize, ...)
    local fn = NS.Resolve(path)
    if type(fn) ~= "function" then
        return { source = path, status = "missing-api" }
    end
    local args = { n = select("#", ...), ... }
    local ok, status, value = pcall(function()
        return normalize(fn(unpackValues(args, 1, args.n)))
    end)
    if not ok then
        return { source = path, status = "error", detail = tostring(status) }
    end
    return { source = path, status = status, value = value }
end

function NS.Scalar(value)
    if value == nil then return "no-data" end
    local kind = type(value)
    if kind == "string" or kind == "boolean" or NS.Number(value) then
        return "ok", value
    end
    return "invalid-data"
end

function NS.Initialize()
    if type(JustAHintDiagnosticsDB) ~= "table" then JustAHintDiagnosticsDB = {} end
    local db = JustAHintDiagnosticsDB
    db.schema = 1
    if type(db.records) ~= "table" then db.records = {} end
    if not NS.ID(db.nextID) then db.nextID = 1 end
    NS.DB = db
end

function NS.Record(kind, data)
    if not NS.DB then NS.Initialize() end
    local record = {
        id = NS.DB.nextID,
        kind = kind,
        addonVersion = NS.VERSION,
        timestamp = NS.Read("date", NS.Scalar, "!%Y-%m-%dT%H:%M:%SZ"),
        build = NS.Adapter.Build(),
        data = data,
    }
    NS.DB.nextID = record.id + 1
    table.insert(NS.DB.records, record)
    while #NS.DB.records > NS.MAX_RECORDS do table.remove(NS.DB.records, 1) end
    -- Hex keeps the JSON transport readable by external tools without executing
    -- SavedVariables as Lua. It contains records only, never active UI state.
    local json = NS.JSON({ schema = 1, addonVersion = NS.VERSION, records = NS.DB.records })
    NS.DB.evidenceHex = json:gsub(".", function(character) return string.format("%02x", character:byte()) end)
    return record
end

local function jsonString(value)
    return '"' .. value:gsub('[%z\1-\31\\"]', function(character)
        if character == '"' then return '\\"' end
        if character == '\\' then return '\\\\' end
        return string.format("\\u%04x", character:byte())
    end) .. '"'
end

function NS.JSON(value)
    local kind = type(value)
    if value == nil then return "null" end
    if kind == "boolean" then return value and "true" or "false" end
    if kind == "number" then return NS.Number(value) and tostring(value) or "null" end
    if kind == "string" then return jsonString(value) end
    if kind ~= "table" then return jsonString("unsupported:" .. kind) end
    local count, length, array = 0, #value, #value > 0
    local keys = {}
    for key in pairs(value) do
        count = count + 1
        keys[#keys + 1] = key
        if type(key) ~= "number" or key < 1 or key > length or key % 1 ~= 0 then array = false end
    end
    array = array and count == length
    local parts = {}
    if array then
        for index = 1, length do parts[#parts + 1] = NS.JSON(value[index]) end
        return "[" .. table.concat(parts, ",") .. "]"
    end
    table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
    for _, key in ipairs(keys) do parts[#parts + 1] = jsonString(tostring(key)) .. ":" .. NS.JSON(value[key]) end
    return "{" .. table.concat(parts, ",") .. "}"
end

function NS.Print(message)
    if DEFAULT_CHAT_FRAME then
        -- Keep captured text from interpreting chat links/colors as UI actions.
        DEFAULT_CHAT_FRAME:AddMessage("Just a Hint: " .. tostring(message):gsub("|", "||"))
    end
end

local function append(lines, value, prefix)
    if type(value) ~= "table" then
        lines[#lines + 1] = prefix .. " = " .. tostring(value)
        return
    end
    local keys = {}
    for key in pairs(value) do keys[#keys + 1] = key end
    table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
    if #keys == 0 then lines[#lines + 1] = prefix .. " = {}" end
    for _, key in ipairs(keys) do append(lines, value[key], prefix .. "." .. tostring(key)) end
end

function NS.Report(record)
    local lines = {
        "Just a Hint diagnostic evidence; these are client captures, not a compatibility verdict.",
        "An area call that did not throw is only call-ok-unverified until visually checked.",
        "Guidance labels are supplied by the tester. Observed questPOI/supertracking is partial evidence.",
    }
    append(lines, record or NS.DB.records, "capture")
    return table.concat(lines, "\n")
end
