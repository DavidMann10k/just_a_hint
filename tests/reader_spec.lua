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
    env.JustAHintDB = saved or { enabled = false }
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
    state.frames = {}
    env.CreateFrame = function(_, _, parent)
        local frame = { parent = parent, shown = true, scripts = {}, events = {} }
        function frame:GetParent() return self.parent end
        function frame:SetParent(value)
            if self == env.ObjectiveTrackerFrame then
                assert(not state.combat, "Native tracker parenting during combat")
                if state.refuseTracker then return end
            end
            self.parent = value
        end
        function frame:Show() self.shown = true end
        function frame:Hide() self.shown = false end
        function frame:IsShown() return self.shown end
        function frame:IsVisible() return self.shown and (not self.parent or self.parent:IsVisible()) end
        function frame:SetAllPoints(value) self.anchor = value end
        function frame:RegisterEvent(event) self.events[event] = true end
        function frame:SetScript(event, callback) self.scripts[event] = callback end
        state.frames[#state.frames + 1] = frame
        return frame
    end
    env.UIParent = env.CreateFrame("Frame")
    env.ObjectiveTrackerFrame = env.CreateFrame("Frame", nil, env.UIParent)
    env.SlashCmdList = {}
    local function load(name)
        local chunk = assert(loadfile("addon/JustAHint/" .. name .. ".lua"))
        setfenv(chunk, env); chunk("JustAHint", ns)
    end
    load("Core"); load("ClientAdapter"); load("NativeTracker"); load("GuidanceGuard")
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

test("native quest handlers remain intact while the tracker is hidden", function()
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
    equal(ns.Guard.Start(),false); equal(#s.writes,0); equal(ns.DB.enabled,false)
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
 equal(ns.Guard.Start(),false);equal(#s.writes,0);equal(ns.DB.enabled,false)
 equal(env.QuestObjectiveTracker.OnBlockHeaderClick,original)
end)
test("native observer startup failure rolls back guidance without installing tracker wrappers",function()
 local ns,s,env=fixture();local original=env.QuestObjectiveTracker.OnBlockHeaderClick
 ns.NativePane.Install=function() return false end;ns.NativePane.problem="Observer unavailable"
 local ok,err=ns.Guard.Start();equal(ok,false);assert(err:find("Observer unavailable"))
 equal(ns.Guard.active,false);equal(ns.DB.enabled,false);equal(s.map,"1");equal(s.filters[1].active,true)
 equal(ns.DB.recovery.questPOI,nil);equal(env.QuestObjectiveTracker.OnBlockHeaderClick,original)
end)

local function entrypoint(ns, state, load)
    ns.SettingsPanel = { UpdateState = function() end, Open = function() end }
    load("Commands")
    local frame = state.frames[#state.frames]
    return function(event, ...) return frame.scripts.OnEvent(frame, event, ...) end
end

test("fresh installation activates on login without a command or hint", function()
    local ns, s, env, load = fixture({})
    equal(ns.DB.enabled,true); equal(#s.writes,0)
    local event = entrypoint(ns,s,load)
    event("PLAYER_LOGIN")
    equal(ns.Guard.active,true); equal(s.map,"0"); equal(s.filters[1].active,false)
    equal(env.ObjectiveTrackerFrame:IsVisible(),false); equal(s.hints,0)
    equal(ns.DB.recovery.questPOI,"1"); equal(ns.DB.recovery.minimap[s.key],true)
end)

test("saved opt-out remains disabled across login and reload", function()
    local ns, s, env, load = fixture({enabled=false})
    entrypoint(ns,s,load)("PLAYER_LOGIN")
    equal(ns.Guard.active,false); equal(ns.DB.enabled,false); equal(#s.writes,0)
    equal(env.ObjectiveTrackerFrame:IsVisible(),true)
    local nextNS, nextState, _, nextLoad = fixture(ns.DB)
    entrypoint(nextNS,nextState,nextLoad)("PLAYER_LOGIN")
    equal(nextNS.Guard.active,false); equal(#nextState.writes,0)
end)

test("legacy recovery without activation preference does not enable the addon", function()
    local ns = fixture({recovery={questPOI="1",minimap={}}})
    equal(ns.DB.enabled,false); equal(ns.Guard.Action(),"retry")
end)

test("login during combat waits until combat ends before automatic activation", function()
    local ns, s, env, load = fixture({}); s.combat = true
    local event = entrypoint(ns,s,load); event("PLAYER_LOGIN")
    equal(ns.Guard.active,false); equal(#s.writes,0); equal(env.ObjectiveTrackerFrame:IsVisible(),true)
    s.combat = false; event("PLAYER_REGEN_ENABLED")
    equal(ns.Guard.active,true); equal(env.ObjectiveTrackerFrame:IsVisible(),false)
end)

test("load-on-demand native UI initializes without opening the map or reentering startup", function()
    local ns, s, env, load = fixture({})
    local event = entrypoint(ns,s,load)
    ns.NativePane.Check = function() return s.nativeReady == true,"Native controls unavailable" end
    env.C_AddOns = {LoadAddOn=function(name)
        equal(name,"Blizzard_WorldMap"); s.nativeLoads = (s.nativeLoads or 0) + 1
        s.nativeReady = true; event("ADDON_LOADED",name)
    end}
    event("PLAYER_LOGIN")
    equal(s.nativeLoads,1); equal(ns.Guard.active,true); equal(s.hints,0); equal(s.opened,nil)
end)

test("late tracker loading retries startup without changing preferences prematurely", function()
    local ns, s, env, load = fixture({})
    local tracker = env.ObjectiveTrackerFrame; env.ObjectiveTrackerFrame = nil
    local event = entrypoint(ns,s,load); event("PLAYER_LOGIN")
    equal(ns.DB.enabled,true); equal(ns.Guard.active,false); equal(#s.writes,0)
    env.ObjectiveTrackerFrame = tracker; event("ADDON_LOADED","Blizzard_ObjectiveTracker")
    equal(ns.Guard.active,true); equal(tracker:IsVisible(),false)
end)

test("native tracker redisplay remains invisible in combat without protected mutations", function()
    local ns, s, env = fixture(); assert(ns.Guard.Start())
    local tracker = env.ObjectiveTrackerFrame
    equal(tracker:IsShown(),true); equal(tracker:IsVisible(),false)
    equal(ns.NativeTracker.hidden.anchor,env.UIParent)
    s.combat = true; tracker:Hide(); tracker:Show(); assert(ns.Guard.Enforce())
    equal(tracker:IsVisible(),false); equal(tracker:GetParent(),ns.NativeTracker.hidden)
    s.combat = false; assert(ns.Guard.Restore())
    equal(tracker:GetParent(),env.UIParent); equal(tracker:IsVisible(),true)
end)

test("restoration preserves native tracker content visibility and addon parenting", function()
    local ns, s, env = fixture(); local tracker = env.ObjectiveTrackerFrame
    tracker:Hide(); assert(ns.Guard.Start()); assert(ns.Guard.Restore())
    equal(tracker:GetParent(),env.UIParent); equal(tracker:IsShown(),false)
    tracker:Show(); assert(ns.Guard.Start())
    local replacement = env.CreateFrame("Frame",nil,env.UIParent)
    tracker:SetParent(replacement); assert(ns.Guard.Restore())
    equal(tracker:GetParent(),replacement); equal(ns.NativeTracker.saved,nil)
end)

test("tracker suppression failure rolls back map and minimap settings", function()
    local ns, s, env = fixture(); s.refuseTracker = true
    equal(ns.Guard.Start(),false); equal(ns.Guard.active,false); equal(ns.DB.enabled,false)
    equal(s.map,"1"); equal(s.filters[1].active,true); equal(env.ObjectiveTrackerFrame:GetParent(),env.UIParent)
    equal(ns.NativeTracker.saved,nil); equal(ns.DB.recovery.questPOI,nil)
end)

test("tracker restoration failure retains its parent snapshot and offers retry", function()
    local ns, s, env = fixture(); assert(ns.Guard.Start()); s.refuseTracker = true
    equal(ns.Guard.Restore(),false); equal(ns.DB.enabled,false); equal(ns.Guard.Action(),"retry")
    equal(env.ObjectiveTrackerFrame:GetParent(),ns.NativeTracker.hidden)
    equal(s.map,"1"); equal(s.filters[1].active,true)
    s.refuseTracker = false; assert(ns.Guard.Toggle())
    equal(ns.NativeTracker.saved,nil); equal(env.ObjectiveTrackerFrame:GetParent(),env.UIParent)
    equal(ns.Guard.Action(),"start")
end)

-- Parse every shipped file, including the presentation and event entrypoint.
for _, name in ipairs({"Core", "ClientAdapter", "NativeTracker", "GuidanceGuard", "SettingsPanel", "StatusReport", "NativeHintMarkers", "NativeQuestPane", "Commands"}) do
    assert(loadfile("addon/JustAHint/" .. name .. ".lua"))
end
print(total .. " reader/control fixture tests passed; native UI verification remains required.")
