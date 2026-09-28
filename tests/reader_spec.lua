-- Behavioral fixtures, not a model of Forever's renderer or compatibility.
local total = 0
local function equal(actual, expected)
    assert(actual == expected, "expected " .. tostring(expected) .. ", got " .. tostring(actual))
end
local function fixture(saved)
    local env = setmetatable({}, { __index = _G })
    env._G = env
    local state = { map = "1", filters = {
        { filterID = 7, active = true }, { filterID = 99, active = true },
    }, key = "character-a", navigation = 123, writes = {}, reads = {}, combat = false,
        originalClicks = 0, hook = nil, modified = false, hints = 0 }
    local ns = {}
    env.JustAHintDB = saved
    env.C_CVar = {
        GetCVar = function(name) equal(name, "questPOI"); return state.map end,
        SetCVar = function(name, value)
            equal(name, "questPOI")
            state.writes[#state.writes + 1] = "map:" .. value
            if state.refuseMap then return false end
            state.map = value
            if state.hook then state.hook() end
            return true
        end,
    }
    env.C_Minimap = {
        GetNumTrackingTypes = function() return #state.filters end,
        GetTrackingFilter = function(index) return state.filters[index] end,
        GetTrackingInfo = function(index) return state.filters[index] end,
        SetTracking = function(index, value)
            state.writes[#state.writes + 1] = "filter:" .. index .. ":" .. tostring(value)
            if state.refuseMinimap then return end
            state.filters[index].active = value
            if state.hook then state.hook() end
        end,
    }
    env.Enum = { MinimapTrackingFilter = { QuestPOIs = 7 } }
    env.C_SuperTrack = {
        GetSuperTrackedQuestID = function() return state.navigation end,
        SetSuperTrackedQuestID = function(id)
            equal(id, 0) -- This addon must never request a destination.
            state.navigation = id
            if state.hook then state.hook() end
        end,
    }
    env.C_QuestLog = {
        GetNumQuestLogEntries = function() return 2 end,
        GetInfo = function(index)
            return index == 1 and {isHeader=true} or {questID=123, title="Original title"}
        end,
        IsOnQuest = function(id) return not state.removed and id == 123 end,
        GetQuestObjectives = function()
            return {{ text = tostring(state.progress or 3) .. "/8 Creatures slain" }}
        end,
        SetSelectedQuest = function() error("Reading must not select a quest") end,
        GetNextWaypoint = function() error("Reading must not ask for a destination") end,
    }
    env.GetQuestLogQuestText = function(index)
        equal(index, 2)
        state.reads[#state.reads+1] = index
        if state.noText then return nil end
        return "The original quest prose.", "The original quest objectives."
    end
    env.HaveQuestData = function() return not state.loading end
    env.UnitGUID = function(unit) equal(unit,"player"); return state.key end
    env.InCombatLockdown = function() return state.combat end
    env.IsModifiedClick = function() return state.modified end
    env.hooksecurefunc = function(object, method, callback)
        equal(object, env.C_SuperTrack); equal(method, "SetSuperTrackedQuestID")
        state.hook = callback
    end
    env.QuestObjectiveTracker = {
        OnBlockHeaderClick = function() state.originalClicks = state.originalClicks + 1 end,
        ItemButton = { untouched = true },
    }
    local function load(name)
        local chunk = assert(loadfile("addon/JustAHint/" .. name .. ".lua"))
        setfenv(chunk, env); chunk("JustAHint", ns)
    end
    load("Core"); load("ClientAdapter"); load("GuidanceGuard")
    ns.Initialize()
    ns.NativePane = {Check=function() return true end,Install=function() return true end,Restore=function() end}
    return ns, state, env, load
end
local function test(name, fn)
    local ok, err = pcall(fn)
    if not ok then error(name .. ": " .. tostring(err)) end
    total = total + 1
    print("ok - " .. name)
end




test("explicit start scopes controls to quest guidance", function()
    local ns, s, env = fixture()
    assert(ns.Guard.Start())
    equal(s.map,"0"); equal(s.filters[1].active,false); equal(s.filters[2].active,true)
    equal(s.navigation,0); equal(env.QuestObjectiveTracker.ItemButton.untouched,true)
    equal(ns.DB.recovery.questPOI,"1"); equal(ns.DB.recovery.minimap[s.key],true)
end)

test("raw modifier keys and quest-item actions survive tracker integration during combat", function()
    local ns, s, env = fixture()
    local item = env.QuestObjectiveTracker.ItemButton
    local uses = 0
    local useItem = function(self) equal(self,item); uses = uses + 1 end
    item.OnClick = useItem
    assert(ns.Guard.Start()); s.combat = true
    for _,key in ipairs({"IsShiftKeyDown", "IsControlKeyDown", "IsAltKeyDown"}) do
        env[key] = function() return true end
        env.QuestObjectiveTracker:OnBlockHeaderClick({id=123}, "LeftButton")
        equal(s.opened,nil)
        env[key] = nil
    end
    equal(s.originalClicks,3)
    env.QuestObjectiveTracker:OnBlockHeaderClick({id=123}, "LeftButton")
    equal(s.opened,nil); equal(s.originalClicks,4)
    equal(env.QuestObjectiveTracker.ItemButton,item); equal(item.OnClick,useItem)
    item:OnClick(); equal(uses,1)
    s.combat = false; assert(ns.Guard.Restore())
    equal(item.OnClick,useItem); item:OnClick(); equal(uses,2)
end)
test("combat refusal preserves recovery and active controls until restoration is retried", function()
    local ns, s = fixture(); assert(ns.Guard.Start())
    local writes, recovery = #s.writes, ns.DB.recovery
    s.combat = true
    equal(ns.Guard.Restore(),false)
    equal(#s.writes,writes); equal(ns.Guard.active,true); equal(ns.DB.enabled,true)
    equal(ns.DB.recovery,recovery); equal(recovery.questPOI,"1")
    equal(recovery.minimap[s.key],true)
    s.combat = false; assert(ns.Guard.Restore())
    equal(s.map,"1"); equal(s.filters[1].active,true); equal(ns.Guard.active,false)
end)

test("explicit auto-completion dialog still reaches Blizzard", function()
    local ns, s, env = fixture()
    env.QuestCache = {Get=function() return {isAutoComplete=true,IsComplete=function() return true end} end}
    assert(ns.Guard.Start())
    env.QuestObjectiveTracker:OnBlockHeaderClick({id=123},"LeftButton")
    equal(s.originalClicks,1); equal(s.opened,nil)
end)
test("new quest navigation is cleared without recursive event loops", function()
    local ns, s = fixture(); assert(ns.Guard.Start())
    s.navigation = 456; s.hook()
    equal(s.navigation,0); equal(#s.writes,2)
    assert(ns.Guard.Restore()); s.navigation = 789; s.hook(); equal(s.navigation,789)
end)
test("repeat start and reload preserve original settings, no hints resume", function()
    local ns, s = fixture(); assert(ns.Guard.Start()); assert(ns.Guard.Start())
    equal(ns.DB.recovery.questPOI,"1")
    local reloaded, nextState = fixture(ns.DB)
    nextState.map = "0"; nextState.filters[1].active = false
    assert(reloaded.Guard.Start()); assert(reloaded.Guard.Restore())
    equal(nextState.map,"1"); equal(nextState.filters[1].active,true); equal(nextState.opened,nil)
end)
test("originally disabled preferences stay disabled on restoration", function()
    local ns, s = fixture(); s.map = "0"; s.filters[1].active = false
    assert(ns.Guard.Start()); assert(ns.Guard.Restore())
    equal(s.map,"0"); equal(s.filters[1].active,false)
end)
test("minimap restoration resolves changed filter indexes", function()
    local ns, s = fixture(); assert(ns.Guard.Start())
    s.filters[1], s.filters[2] = s.filters[2], s.filters[1]
    assert(ns.Guard.Restore()); equal(s.filters[2].active,true); equal(s.filters[1].active,true)
end)
test("other characters recover their own filter when guidance is restored", function()
    local ns, s = fixture(); assert(ns.Guard.Start())
    s.key = "character-b"; s.filters[1].active = false
    assert(ns.Guard.Start()); assert(ns.Guard.Restore())
    equal(s.filters[1].active,false); equal(ns.DB.recovery.minimap["character-a"],true)
    s.key = "character-a"; assert(ns.Guard.Restore()); equal(s.filters[1].active,true)
end)
test("missing interfaces and combat refuse activation before mutations", function()
    local ns, s, env = fixture(); env.Enum.MinimapTrackingFilter.QuestPOIs = nil
    equal(ns.Guard.Start(),false); equal(#s.writes,0); equal(ns.DB.enabled,nil)
    env.Enum.MinimapTrackingFilter.QuestPOIs = 7; s.combat = true
    equal(ns.Guard.Start(),false); equal(#s.writes,0)
end)
test("failed activation restores partial writes", function()
    local ns, s = fixture(); s.refuseMinimap = true
    equal(ns.Guard.Start(),false); equal(s.map,"1"); equal(ns.DB.enabled,false)
    equal(ns.DB.recovery.questPOI,nil); equal(ns.Guard.active,false)
end)
test("failed restoration retains recovery values for retry", function()
    local ns, s = fixture(); assert(ns.Guard.Start()); s.refuseMap = true
    equal(ns.Guard.Restore(),false); equal(ns.DB.recovery.questPOI,"1")
    equal(ns.Guard.active,false); equal(s.filters[1].active,true)
    s.refuseMap = false; assert(ns.Guard.Restore()); equal(s.map,"1")
end)
test("restoring never clobbers another addon's replacement", function()
    local ns, s, env = fixture(); assert(ns.Guard.Start())
    local ours = env.QuestObjectiveTracker.OnBlockHeaderClick
    local newer = function(...) return ours(...) end
    env.QuestObjectiveTracker.OnBlockHeaderClick = newer
    assert(ns.Guard.Restore()); equal(env.QuestObjectiveTracker.OnBlockHeaderClick,newer)
    env.QuestObjectiveTracker:OnBlockHeaderClick({id=123},"LeftButton")
    equal(s.originalClicks,1)
end)
test("restoring Blizzard guidance explicitly clears the requested hint", function()
    local ns, s = fixture(); assert(ns.Guard.Start())
    ns.Hints = { Clear = function(reason) s.hintClearReason = reason end }
    assert(ns.Guard.Restore()); equal(s.hintClearReason, "blizzard-guidance-restored")
end)

test("activation toggle selects start restore and retry from current-character recovery", function()
 local ns,s=fixture();equal(ns.Guard.Action(),"start")
 assert(ns.Guard.Toggle());equal(ns.Guard.Action(),"restore")
 s.refuseMap=true;equal(ns.Guard.Toggle(),false);equal(ns.Guard.Action(),"retry")
 local before=#s.writes;equal(ns.Guard.Start(),false);equal(#s.writes,before)
 equal(ns.DB.recovery.questPOI,"1")
 s.refuseMap=false;assert(ns.Guard.Toggle());equal(ns.Guard.Action(),"start");equal(s.map,"1")
end)
test("toggle combat refusal never changes its activation state or recovery", function()
 local ns,s=fixture();s.combat=true;equal(ns.Guard.Toggle(),false);equal(ns.Guard.Action(),"start")
 equal(#s.writes,0);s.combat=false;assert(ns.Guard.Toggle())
 local before=#s.writes;s.combat=true;equal(ns.Guard.Toggle(),false)
 equal(ns.Guard.Action(),"restore");equal(#s.writes,before);equal(ns.DB.recovery.questPOI,"1")
end)
test("other-character recovery does not trap the current character in retry", function()
 local ns,s=fixture();ns.DB.recovery.minimap["other-character"]=true
 equal(ns.Guard.Action(),"start");assert(ns.Guard.Toggle());assert(ns.Guard.Toggle())
 equal(ns.Guard.Action(),"start");equal(ns.DB.recovery.minimap["other-character"],true)
end)
test("missing native controls fail before guidance settings change",function()
 local ns,s,env=fixture();local original=env.QuestObjectiveTracker.OnBlockHeaderClick
 ns.NativePane.Check=function() return false,"Native controls unavailable" end
 equal(ns.Guard.Start(),false);equal(#s.writes,0);equal(ns.DB.enabled,nil)
 equal(env.QuestObjectiveTracker.OnBlockHeaderClick,original)
end)
test("native observer startup failure rolls back guidance without installing tracker wrappers",function()
 local ns,s,env=fixture();local original=env.QuestObjectiveTracker.OnBlockHeaderClick
 ns.NativePane.Install=function() return false end;ns.NativePane.problem="Observer unavailable"
 local ok,err=ns.Guard.Start();equal(ok,false);assert(err:find("Observer unavailable"))
 equal(ns.Guard.active,false);equal(ns.DB.enabled,false);equal(s.map,"1");equal(s.filters[1].active,true)
 equal(ns.DB.recovery.questPOI,nil);equal(env.QuestObjectiveTracker.OnBlockHeaderClick,original)
end)
-- Parse every shipped file, including the presentation and event entrypoint.
for _, name in ipairs({"Core", "ClientAdapter", "GuidanceGuard", "SettingsPanel", "StatusReport", "NativeHintMarkers", "NativeQuestPane", "Commands"}) do
    assert(loadfile("addon/JustAHint/" .. name .. ".lua"))
end
print(total .. " reader/control fixture tests passed; native UI verification remains required.")
