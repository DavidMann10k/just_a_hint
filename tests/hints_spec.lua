-- Policy and orchestration fixtures. Native direction/units/rendering need playtests.
local total = 0
local function equal(a,b) assert(a == b, "expected " .. tostring(b) .. ", got " .. tostring(a)) end
local function near(a,b) assert(math.abs(a-b)<0.00001, tostring(a).." != "..tostring(b)) end
local function test(name,fn)
    local ok,err=pcall(fn); assert(ok,name..": "..tostring(err))
    total=total+1; print("ok - "..name)
end
local function load(ns,env,name)
    local chunk=assert(loadfile("addon/JustAHint/"..name..".lua"))
    setfenv(chunk,env); chunk("JustAHint",ns)
end
local policy={}
load(policy,_G,"HintController")
local Controller=policy.HintController

test("first request chooses bearing far and area near",function()
    local c=Controller.New(); equal(c.mode,"none")
    equal(c:Request(1,500,0),"bearing")
    equal(c:Request(2,150,0),"area"); equal(c.questID,2)
end)
test("repeated far requests never disclose an area",function()
    local c=Controller.New()
    for i=1,20 do equal(c:Request(1,500,i),"bearing") end
end)
test("arrival removes assistance and stays quiet after wandering away",function()
    local c=Controller.New(); c:Request(1,500,0)
    for _,t in ipairs({0.1,0.4,0.7,1.0}) do equal(c:Update(140,t),"bearing") end
    equal(c:Update(140,1.2),"none"); equal(c.reason,"arrived"); equal(c.visible,false)
    equal(c:Update(500,1.4),"none")
    equal(c:Request(1,500,2),"bearing")
end)
test("brief threshold crossings reset dwell",function()
    local c=Controller.New(); c:Request(1,500,0)
    c:Update(140,0.1); c:Update(140,0.5); c:Update(151,0.7); c:Update(140,0.9)
    c:Update(140,1.2); c:Update(140,1.5); equal(c.mode,"bearing")
    c:Update(140,1.8); equal(c.mode,"bearing")
    c:Update(140,2.0); equal(c.mode,"none")
end)
test("missing positions hide and interrupt dwell without a new disclosure",function()
    local c=Controller.New(); c:Request(1,500,0); c:Update(140,0.1); c:Update(140,0.5)
    c:Update(nil,0.6); equal(c.visible,false); equal(c.mode,"bearing")
    c:Update(140,0.7); c:Update(140,1.1); c:Update(140,1.5); equal(c.mode,"bearing")
    c:Update(140,1.8); equal(c.mode,"none")
end)
test("stalls and clock reversal cannot manufacture continuous arrival",function()
    local c=Controller.New(); c:Request(1,500,0); c:Update(140,0.1)
    c:Update(140,9); equal(c.mode,"bearing"); equal(c.nearSince,9)
    c:Update(140,1); equal(c.mode,"bearing"); equal(c.nearSince,1)
end)
test("missing or invalid data on a new request replaces old guidance",function()
    local c=Controller.New()
    for _,value in ipairs({-1,math.huge,0/0}) do
        c:Request(1,500,0); equal(c:Request(2,value,0),"none")
    end
    c:Request(1,500,0); equal(c:Request(2,nil,0),"none")
end)
test("fixed and rotated minimap cardinal bearings",function()
    local x,y=Controller.ScreenDirection(1,0,0); near(x,1); near(y,0)
    x,y=Controller.ScreenDirection(0,1,0); near(x,0); near(y,1)
    x,y=Controller.ScreenDirection(1,0,3*math.pi/2); near(x,0); near(y,1) -- facing east
    x,y=Controller.ScreenDirection(0,1,3*math.pi/2); near(x,-1); near(y,0)
    x,y=Controller.ScreenDirection(-1,0,math.pi/2); near(x,0); near(y,1) -- facing west
    equal(Controller.ScreenDirection(0,0,0),nil)
end)

local function bearingFixture()
    local env=setmetatable({}, {__index=_G}); env._G=env
    local ns={}
    local s={atlases={ ["Navigation-Tracked-Arrow"]={width=32,height=48} },visible=true}
    env.C_Texture={GetAtlasInfo=function(name) return s.atlases[name] end}
    env.Minimap={IsVisible=function() return s.visible end,GetWidth=function() return 160 end,
        GetHeight=function() return 160 end,GetFrameLevel=function() return 1 end}
    local texture={
        SetAtlas=function(_,atlas) s.atlas=atlas end,
        SetVertexColor=function() end,
        SetSize=function(_,w,h) s.width=w;s.height=h end,
        SetRotation=function(_,angle) if s.renderError then error("texture unavailable") end;s.rotation=angle end,
        SetAlpha=function(_,alpha) s.alpha=alpha end,
        ClearAllPoints=function() end,SetPoint=function(_,_,_,_,x,y) s.x=x;s.y=y end,
    }
    env.CreateFrame=function()
        return {Hide=function() s.shown=false end,Show=function() s.shown=true end,
            SetAllPoints=function() end,SetFrameLevel=function() end,EnableMouse=function() end,
            CreateTexture=function() return texture end}
    end
    load(ns,env,"Core");load(ns,env,"MinimapBearing")
    return ns,s,env
end
test("native artwork rotates with screen bearings and hides on render failure",function()
    local ns,s=bearingFixture()
    assert(ns.Bearing.Show(0,1));equal(s.atlas,"Navigation-Tracked-Arrow");near(s.rotation,0)
    near(s.width/s.height,32/48);equal(s.shown,true);assert(s.y>0)
    assert(ns.Bearing.Show(1,0));near(s.rotation,-math.pi/2);assert(s.x>0);near(s.y,0)
    assert(ns.Bearing.Show(-1,0));near(s.rotation,math.pi/2);assert(s.x<0)
    assert(ns.Bearing.Show(0,-1));near(math.abs(s.rotation),math.pi);assert(s.y<0)
    s.renderError=true;local ok=ns.Bearing.Show(0,1);equal(ok,false);equal(s.shown,false)
end)
test("artwork selection tolerates missing atlases and unavailable texture API",function()
    local ns,s,env=bearingFixture();s.atlases={}
    local ok,why=ns.Bearing.Show(0,1);equal(ok,false);assert(why:find("artwork is unavailable"));equal(ns.Bearing.frame,nil)
    s.atlases["UI-WorldMapArrow"]={width=32,height=32}
    assert(ns.Bearing.Show(0,1));equal(s.atlas,"UI-WorldMapArrow")
    s.visible=false;assert(ns.Bearing.Show(0,1));equal(s.shown,false)
    ns,s,env=bearingFixture();env.C_Texture=nil
    equal(ns.Bearing.Show(0,1),false);equal(ns.Bearing.frame,nil)
end)

local function dataFixture()
    local env=setmetatable({}, {__index=_G}); env._G=env
    local ns={}
    local s={fulfilled=3, required=8, wording="Creatures slain",complete=false,accepted=true,
        mapID=2521, targetX=0.6,targetY=0.5,playerX=0.2,playerY=0.5,rotated="0"}
    env.HaveQuestData=function() return s.cached end
    local function vector(x,y) return {GetXY=function() return x,y end} end
    env.CreateVector2D=vector
    env.C_QuestLog={
        IsOnQuest=function() return s.accepted end,
        IsComplete=function() return s.complete end,
        GetQuestObjectives=function()
            return {{type="monster",numFulfilled=s.fulfilled,numRequired=s.required,finished=s.finished or false,
                text=s.fulfilled.."/"..s.required.." "..s.wording}}
        end,
        GetNextWaypoint=function() if s.nextMap then return s.nextMap,0.6,0.5 end end,
        GetNextWaypointForMap=function() end,
        GetQuestsOnMap=function()
            local points={{questID=1,x=s.targetX,y=s.targetY,isMapIndicatorQuest=s.mapIndicator}}
            if s.ambiguous then points[2]={questID=1,x=0.8,y=0.7} end
            points[#points+1]={questID=99,x=0.8,y=0.9}
            return points
        end,
    }
    env.C_Map={
        GetBestMapForUnit=function() return s.mapID end,
        GetPlayerMapPosition=function() return vector(s.playerX,s.playerY) end,
        GetWorldPosFromMapPos=function(_,v)
            local x,y=v:GetXY(); return 0,vector(-y*1000,-x*1000)
        end,
    }
    env.C_CVar={GetCVar=function(name) equal(name,"rotateMinimap"); return s.rotated end}
    env.GetPlayerFacing=function() return s.facing end
    load(ns,env,"Core"); load(ns,env,"HintData")
    return ns,s,env
end
test("native map-point fallback converts comparable coordinates including space zero",function()
    local ns,s=dataFixture(); local sample=assert(ns.HintData.Snapshot(1))
    near(sample.distance,400); equal(sample.target.space,0); equal(sample.destination.source,"native-map-point")
end)
test("partial counts preserve stage; completion and wording changes do not",function()
    local ns,s=dataFixture(); local before=assert(ns.HintData.Snapshot(1)).stage
    s.fulfilled=4; equal(assert(ns.HintData.Snapshot(1)).stage,before)
    s.wording="Different creatures slain"; assert(assert(ns.HintData.Snapshot(1)).stage~=before)
    s.wording="Creatures slain"; s.finished=true; assert(assert(ns.HintData.Snapshot(1)).stage~=before)
    s.complete=true; local value=assert(ns.HintData.Snapshot(1)); equal(value.stage,"turn-in");equal(value.phase,"turn-in");assert(value.stage~=before)
end)
test("only an explicit negative cache result means loading",function()
    local ns,s,env=dataFixture();s.cached=false
    local result,why=ns.HintData.Snapshot(1);equal(result,nil);equal(why,"loading")
    s.cached=true;s.targetX=2;result,why=ns.HintData.Snapshot(1);equal(result,nil);equal(why,"no-destination")
    env.HaveQuestData=nil;result,why=ns.HintData.Snapshot(1);equal(result,nil);equal(why,"no-destination")
    s.targetX=0.6;assert(ns.HintData.Snapshot(1))
end)
test("removed, malformed, ambiguous and cross-map destinations are unavailable",function()
    local ns,s=dataFixture()
    s.accepted=false; local v,why=ns.HintData.Snapshot(1); equal(v,nil); equal(why,"removed")
    s.accepted=true; s.targetX=2; equal(ns.HintData.Snapshot(1),nil)
    s.targetX=0.6; s.ambiguous=true; equal(ns.HintData.Snapshot(1),nil)
    s.ambiguous=false; s.nextMap=999; v,why=ns.HintData.Snapshot(1); equal(v,nil); equal(why,"other-map")
    s.nextMap=nil; s.mapIndicator=true; equal(ns.HintData.Snapshot(1),nil)
end)
test("conversion failures and restricted vector reads fail without navigation",function()
    local ns,s,env=dataFixture()
    env.C_Map.GetWorldPosFromMapPos=function() return 0,{GetXY=function() error("restricted") end} end
    equal(ns.HintData.Snapshot(1),nil)
end)
test("fixed minimap needs no facing; rotating minimap cannot assume a missing heading",function()
    local ns,s=dataFixture(); equal(ns.HintData.Facing(),0)
    s.rotated="1"; equal(ns.HintData.Facing(),nil)
    s.facing=math.pi; equal(ns.HintData.Facing(),math.pi)
end)

local function serviceFixture()
    local env=setmetatable({}, {__index=_G}); env._G=env
    local ns={DB={lastCheck={}}}
    local s={time=0,distance=500,stage="first",mapID=2521,shown=false,queries=0,targetX=0,
        source="native-map-point",areaRequests=0,areaDraws=0,bearingDraws=0,facing=0}
    env.GetTime=function() return s.time end
    env.CreateFrame=function() return {SetScript=function(_,_,fn) s.tick=fn end} end
    load(ns,env,"Core"); load(ns,env,"HintController")
    ns.Note=function(k,v) ns.DB.lastCheck[k]=v end
    ns.Message=function(m) s.message=m end
    ns.SettingsPanel={UpdateState=function() end}
    ns.Guard={active=true,Action=function() return "restore" end,Resume=function() end}
    ns.Bearing={Hide=function() s.shown=false end,Show=function(x,y)
        s.bearingDraws=s.bearingDraws+1
        if s.renderError then return false,"texture unavailable" end
        s.shown=true;s.x=x;s.y=y;return true
    end}
    ns.Area={
        IsVisible=function(id) return s.areaShown==true and s.areaID==id end,
        Clear=function() s.areaShown=false;s.areaActive=false end,
        Show=function(id,mapID)
            s.areaRequests=s.areaRequests+1;s.areaID=id;s.areaMap=mapID
            if s.openCallback then s.openCallback(ns) end
            if s.areaError then return false,"Area unavailable" end
            s.areaActive=true;return true
        end,
        Check=function() return s.areaActive and not s.mapClosed,"map-closed" end,
        Suspend=function() s.areaShown=false;return true end,
        Update=function() s.areaDraws=s.areaDraws+1;s.areaShown=true;return true end,
    }
    ns.HintData={
        CurrentMap=function() return s.mapID end,
        Facing=function() if s.noFacing then return nil end; return s.facing end,
        Distance=function(a,b) if a.space~=b.space then return nil end;return math.sqrt((a.x-b.x)^2+(a.y-b.y)^2) end,
        Snapshot=function(id)
            s.queries=s.queries+1
            if s.error then return nil,s.error,s.observedStage end
            return {stage=s.stage,mapID=s.mapID,target={x=s.targetX,y=0,space=0},player={x=-s.distance,y=0,space=0},
                distance=s.distance,destination={source=s.source}}
        end,
    }
    load(ns,env,"Hints")
    return ns,s,env
end


test("toggle clears an owned bearing or area and only requests when nothing is visible for that quest",function()
 for _,distance in ipairs({500,100}) do
  local ns,s,env=serviceFixture()
  ns.Bearing.frame={IsVisible=function() return s.shown end}
  ns.Area.frame={IsVisible=function() return s.areaShown end}
  s.distance=distance;ns.Hints.Request(1);ns.Hints.Update()
  if distance==100 then ns.Area.active={id=1,drawn=true} end
  local requests=s.bearingDraws+s.areaRequests
  equal(ns.Hints.Toggle(1),'cleared');equal(ns.Hints.active,nil)
  equal(s.bearingDraws+s.areaRequests,requests)
  equal(s.shown,false);equal(s.areaShown,false)
  equal(ns.Hints.Toggle(2),'requested');equal(ns.Hints.active.id,2)
 end
end)



test("idle and read-only activity cannot acquire a hint",function()
    local ns,s=serviceFixture(); ns.Hints.Update(); s.tick(nil,1)
    equal(s.queries,0); equal(s.shown,false); equal(ns.Hints.active,nil)
end)
test("turning updates each frame while quest snapshots remain throttled",function()
    local ns,s=serviceFixture();ns.Hints.Request(1);equal(s.queries,1)
    for i=1,6 do
        s.time=i*0.01;s.facing=i*0.2;s.tick(nil,0.01)
        near(s.x,math.sin(s.facing));near(s.y,math.cos(s.facing))
        equal(s.queries,1);equal(s.bearingDraws,i+1)
    end
    s.time=0.11;s.tick(nil,0.05);equal(s.queries,2);equal(s.bearingDraws,8)
end)
test("animation cannot redraw a cleared, suspended, or replaced hint",function()
    for _,change in ipairs({"clear","arrive","missing","destination","stage","area","replacement"}) do
        local ns,s=serviceFixture();ns.Hints.Request(1)
        if change=="clear" then ns.Hints.Clear("cleared")
        elseif change=="arrive" then
            s.distance=140
            for _,t in ipairs({0.1,0.4,0.7,1.0,1.2}) do s.time=t;ns.Hints.Update() end
        elseif change=="missing" then s.error="unavailable";ns.Hints.Update();s.error=nil
        elseif change=="destination" then s.targetX=20;ns.Hints.Update();s.targetX=0
        elseif change=="stage" then s.stage="second";ns.Hints.Update()
        elseif change=="area" then s.distance=100;ns.Hints.Request(2)
        else s.error="no-destination";ns.Hints.Request(2) end
        local draws,queries=s.bearingDraws,s.queries
        for i=1,3 do s.time=s.time+0.01;s.facing=i;s.tick(nil,0.01) end
        equal(s.shown,false);equal(s.bearingDraws,draws);equal(s.queries,queries)
    end
end)
test("missing heading between data checks interrupts the arrival dwell",function()
    local ns,s=serviceFixture();ns.Hints.Request(1);s.distance=140
    s.time=0.1;ns.Hints.Update();s.time=0.5;ns.Hints.Update()
    s.noFacing=true;s.time=0.51;s.tick(nil,0.01);equal(s.shown,false)
    equal(ns.Hints.controller.nearSince,nil)
    s.noFacing=false;s.time=0.52;s.tick(nil,0.01);equal(s.shown,false)
    s.time=0.6;ns.Hints.Update();equal(s.shown,true)
    for _,t in ipairs({0.9,1.2,1.5}) do s.time=t;ns.Hints.Update();assert(ns.Hints.active) end
    s.time=1.7;ns.Hints.Update();equal(ns.Hints.active,nil)
end)
test("frame rendering checks controls and failures and validates after a stall",function()
    for _,change in ipairs({"guard","renderer","stalled-stage"}) do
        local ns,s=serviceFixture();ns.Hints.Request(1)
        if change=="guard" then ns.Guard.active=false
        elseif change=="renderer" then s.renderError=true
        else s.stage="second" end
        local draws=s.bearingDraws
        s.time=change=="stalled-stage" and 2 or 0.01;s.tick(nil,s.time)
        equal(s.shown,false);equal(ns.Hints.active,nil)
        equal(s.bearingDraws,draws+(change=="renderer" and 1 or 0))
    end
end)
test("one requested bearing clears on arrival and never reappears automatically",function()
    local ns,s=serviceFixture(); ns.Hints.Request(1); equal(s.shown,true)
    near(s.x,0); near(s.y,1)
    s.distance=140
    for _,t in ipairs({0.1,0.4,0.7,1.0,1.2}) do s.time=t; ns.Hints.Update() end
    equal(s.shown,false); equal(ns.Hints.active,nil); equal(ns.DB.lastCheck.hint,"arrived")
    s.distance=500;s.time=3;ns.Hints.Update();equal(s.shown,false)
    equal(s.areaRequests,0);equal(s.areaDraws,0)
end)
test("point and native-region arrivals notify once only after clearing visible guidance",function()
    for _,kind in ipairs({"point","region"}) do
        local ns,s=serviceFixture();local notifications=0
        ns.Bearing.frame={IsVisible=function() return s.shown end}
        ns.Feedback={BearingRequested=function() end,Arrived=function(owner)
            equal(owner.id,1);equal(ns.Hints.active,nil);equal(s.shown,false)
            equal(ns.Hints.controller.reason,"arrived");notifications=notifications+1
        end}
        ns.Hints.Request(1)
        if kind=="region" then
            ns.Hints.active.region={}
            ns.RegionHints={Clear=function() end,Distance=function() return s.distance end}
        end
        s.distance=140
        for _,t in ipairs({0.1,0.4,0.7,1.0}) do s.time=t;ns.Hints.Update();equal(notifications,0) end
        s.time=1.2;ns.Hints.Update();equal(notifications,1)
        s.distance=500;s.time=3;ns.Hints.Update();equal(notifications,1)
        equal(s.areaRequests,0);equal(s.areaDraws,0)
    end
end)
test("nearby first requests and interrupted arrival dwell never announce an early arrival",function()
    local ns,s=serviceFixture();local notifications=0
    ns.Bearing.frame={IsVisible=function() return s.shown end}
    ns.Feedback={BearingRequested=function() end,Arrived=function() notifications=notifications+1 end}
    s.distance=100;ns.Hints.Request(1)
    for _,t in ipairs({0.1,0.4,0.7,1.0,1.2}) do s.time=t;ns.Hints.Update() end
    equal(notifications,0);equal(ns.Hints.controller.mode,"area")
    s.distance=500;s.time=2;ns.Hints.Request(1)
    s.distance=140;s.time=2.1;ns.Hints.Update();s.time=2.4;ns.Hints.Update()
    s.error="unavailable";s.time=2.5;ns.Hints.Update();equal(notifications,0)
    s.error=nil
    for _,t in ipairs({2.6,2.9,3.2,3.5}) do s.time=t;ns.Hints.Update();equal(notifications,0) end
    s.time=3.7;ns.Hints.Update();equal(notifications,1)
end)
test("requesting B with no data clears A",function()
    local ns,s=serviceFixture(); ns.Hints.Request(1); s.error="no-destination"; ns.Hints.Request(2)
    equal(s.shown,false);equal(ns.Hints.active,nil)
end)
test("loading feedback clears the prior hint and cannot acquire one when data arrives",function()
    local ns,s=serviceFixture();ns.Hints.Request(1);s.error="loading";ns.Hints.Request(2)
    equal(s.shown,false);equal(ns.Hints.active,nil)
    assert(s.message:find("still loading"));s.error=nil;ns.Hints.Update()
    equal(s.shown,false);equal(ns.Hints.active,nil)
    ns.Hints.Request(2);equal(s.shown,true)
end)
test("an authorized area can survive a loading gap only with its unchanged stage",function()
    local ns,s=serviceFixture();s.distance=100;ns.Hints.Request(1);ns.Hints.Update()
    s.error="loading";ns.Hints.Update();equal(s.areaShown,false)
    s.error=nil;s.stage="new-step";ns.Hints.Update();equal(ns.Hints.active,nil);equal(s.areaShown,false)
end)

test("nearby first request directly authorizes the native area, never a bearing",function()
    local ns,s=serviceFixture();s.distance=100;ns.Hints.Request(1)
    equal(s.shown,false);equal(ns.Hints.controller.mode,"area");equal(s.areaRequests,1)
    equal(s.areaID,1);equal(s.areaMap,2521);ns.Hints.Update();equal(s.areaShown,true)
    s.distance=500;s.noFacing=true;ns.Hints.Update();equal(s.shown,false);equal(s.areaShown,true)
end)
test("far repeated requests cannot open an area",function()
    local ns,s=serviceFixture()
    for i=1,10 do ns.Hints.Request(1);ns.Hints.Update() end
    equal(s.areaRequests,0);equal(s.areaDraws,0);equal(s.shown,true)
end)
test("unavailable area or a replacement quest clears the old disclosure",function()
    local ns,s=serviceFixture();s.distance=100;ns.Hints.Request(1);ns.Hints.Update()
    s.areaError=true;ns.Hints.Request(2);equal(s.areaShown,false);equal(ns.Hints.active,nil)
    s.areaError=false;ns.Hints.Request(1);ns.Hints.Update()
    s.error="no-destination";ns.Hints.Request(2);equal(s.areaShown,false);equal(ns.Hints.active,nil)
    s.error=nil;s.distance=500;ns.Hints.Request(2);equal(s.areaShown,false);equal(s.shown,true)
end)
test("area lifecycle is validated before any redraw",function()
    for _,change in ipairs({"stage","mapID","removed","complete","mapClosed","guard"}) do
        local ns,s=serviceFixture();s.distance=100;ns.Hints.Request(1);ns.Hints.Update()
        equal(s.areaDraws,1)
        if change=="stage" then s.stage="second" elseif change=="mapID" then s.mapID=999
        elseif change=="mapClosed" then s.mapClosed=true elseif change=="guard" then ns.Guard.active=false
        else s.error=change end
        ns.Hints.Update();equal(s.areaShown,false);equal(ns.Hints.active,nil);equal(s.areaDraws,1)
    end
end)
test("area data gaps suspend; a changed stage cannot resume the old request",function()
    local ns,s=serviceFixture();s.distance=100;ns.Hints.Request(1);ns.Hints.Update()
    s.error="unavailable";ns.Hints.Update();equal(s.areaShown,false);assert(ns.Hints.active)
    s.error=nil;ns.Hints.Update();equal(s.areaShown,true)
    s.error="unavailable";ns.Hints.Update();s.error=nil;s.stage="new";ns.Hints.Update()
    equal(s.areaShown,false);equal(ns.Hints.active,nil)
end)
test("synchronous map-open events cannot draw or revive a cancelled request",function()
    local ns,s=serviceFixture();s.distance=100
    s.openCallback=function(current) current.Hints.Update();equal(s.areaDraws,0);current.Hints.Clear("cancelled") end
    ns.Hints.Request(1);equal(ns.Hints.active,nil);equal(s.areaShown,false);equal(s.areaDraws,0)
end)
test("step changes, zoning, removal and completion clear without selecting the next target",function()
    for _,change in ipairs({"stage","mapID","removed","complete"}) do
        local ns,s=serviceFixture();ns.Hints.Request(1)
        if change=="stage" then s.stage="second" elseif change=="mapID" then s.mapID=2522 else s.error=change end
        ns.Hints.Update();equal(s.shown,false);equal(ns.Hints.active,nil)
    end
end)
test("one changed destination hides; a repeated change clears; tiny drift is tolerated",function()
    local ns,s=serviceFixture();ns.Hints.Request(1)
    s.targetX=0.5;ns.Hints.Update();equal(s.shown,true)
    s.targetX=20;ns.Hints.Update();equal(s.shown,false);assert(ns.Hints.active)
    s.targetX=0;ns.Hints.Update();equal(s.shown,true)
    s.targetX=20;ns.Hints.Update();ns.Hints.Update();equal(ns.Hints.active,nil)
end)
test("zoning clears even when the new map supplies no quest destination",function()
    local ns,s=serviceFixture();ns.Hints.Request(1)
    s.mapID=2522;s.error="no-destination";ns.Hints.Update()
    equal(ns.Hints.active,nil);equal(s.shown,false)
    s.mapID=2521;s.error=nil;ns.Hints.Update();equal(s.shown,false)
end)
test("temporary missing data hides without revoking an unchanged request",function()
    local ns,s=serviceFixture();ns.Hints.Request(1);s.error="unavailable";ns.Hints.Update()
    equal(s.shown,false);assert(ns.Hints.active)
    s.error=nil;ns.Hints.Update();equal(s.shown,true)
end)
test("missing facing hides and interrupts dwell on a rotating minimap",function()
    local ns,s=serviceFixture();ns.Hints.Request(1);s.distance=140;s.time=0.1;ns.Hints.Update()
    s.noFacing=true;s.time=0.4;ns.Hints.Update();equal(s.shown,false)
    s.noFacing=false;s.time=0.7;ns.Hints.Update();equal(s.shown,true)
    s.time=1.1;ns.Hints.Update();s.time=1.5;ns.Hints.Update();assert(ns.Hints.active)
    s.time=1.8;ns.Hints.Update();equal(ns.Hints.active,nil)
end)
test("restoring or failing guidance controls revokes the active hint",function()
    local ns,s=serviceFixture();ns.Hints.Request(1);ns.Guard.active=false;ns.Hints.Update()
    equal(s.shown,false);equal(ns.Hints.active,nil)
end)
test("world entry clears both hint modes even when the map and quest are unchanged",function()
    for _,distance in ipairs({500,100}) do
        local ns,s,env=serviceFixture();s.distance=distance;ns.Hints.Request(1);ns.Hints.Update()
        ns.Guard.Enforce=function() end
        env.SlashCmdList={}
        local onEvent
        env.CreateFrame=function() return {RegisterEvent=function() end,SetScript=function(_,_,fn) onEvent=fn end} end
        load(ns,env,"Commands")
        onEvent(nil,"PLAYER_ENTERING_WORLD",false,false)
        equal(ns.Hints.active,nil);equal(s.shown,false);equal(s.areaShown,false)
        equal(ns.DB.lastCheck.hint,"world-changed")
        local queries=s.queries
        s.tick(nil,0.01);s.tick(nil,0.2);onEvent(nil,"QUEST_POI_UPDATE")
        equal(s.queries,queries);equal(s.shown,false);equal(s.areaShown,false)
    end
end)
test("removal and turn-in events clear only the active quest immediately",function()
    for _,event in ipairs({"QUEST_REMOVED","QUEST_TURNED_IN"}) do
        local ns,s,env=serviceFixture();s.distance=100;ns.Hints.Request(1);ns.Hints.Update()
        ns.Guard.Enforce=function() end
        env.SlashCmdList={}
        local onEvent
        env.CreateFrame=function() return {RegisterEvent=function() end,SetScript=function(_,_,fn) onEvent=fn end} end
        load(ns,env,"Commands")
        onEvent(nil,event,2);assert(ns.Hints.active);equal(s.areaShown,true)
        onEvent(nil,event,1);equal(ns.Hints.active,nil);equal(s.areaShown,false);equal(s.shown,false)
    end
end)
test("passive Hint availability waits for data without starting or replacing guidance",function()
    local ns,s=serviceFixture();ns.Hints.Request(1)
    local active=ns.Hints.active
    local button={SetShown=function(self,v) self.shown=v end,SetEnabled=function(self,v) self.enabled=v end,
        SetText=function(self,v) self.text=v end}
    s.error="loading";equal(ns.Hints.UpdateButton(button,2),"loading")
    equal(button.shown,true);equal(button.enabled,false);assert(button.text:find("Loading"))
    equal(ns.Hints.active,active);equal(ns.Hints.active.id,1)
    s.error=nil;equal(ns.Hints.UpdateButton(button,2),"ready");equal(button.enabled,true)
    equal(ns.Hints.active,active);s.error="no-destination"
    equal(ns.Hints.UpdateButton(button,2),"hidden");equal(button.shown,false);equal(ns.Hints.active,active)
end)

test("only successful explicit bearing requests trigger presentation feedback",function()
    local ns,s=serviceFixture();local notifications=0
    ns.Feedback={BearingRequested=function() notifications=notifications+1 end}
    ns.Hints.Request(1);equal(notifications,1)
    s.tick(nil,0.01);ns.Hints.Update();equal(notifications,1)
    s.distance=100;ns.Hints.Request(2);equal(notifications,1)
    s.error="loading";ns.Hints.Request(3);equal(notifications,1)
    s.error=nil;ns.Hints.Update();equal(notifications,1)
end)
for _,name in ipairs({"HintController","HintData","MinimapBearing","Hints"}) do
    assert(loadfile("addon/JustAHint/"..name..".lua"))
end
test("completed accepted quests use current native destination data without requiring objective records",function()
 local ns,s,env=dataFixture();s.complete=true
 env.C_QuestLog.GetQuestObjectives=function() error('completed phase must not require objectives') end
 local result=assert(ns.HintData.Snapshot(1));equal(result.stage,'turn-in');equal(result.phase,'turn-in')
 equal(result.destination.source,'native-map-point')
 s.targetX=0.9;local nextResult=assert(ns.HintData.Snapshot(1))
 assert(nextResult.target.y~=result.target.y) -- Re-read current native data, never the objective's saved point.
 s.targetX=2;local missing,reason,stage=ns.HintData.Snapshot(1)
 equal(missing,nil);equal(reason,'no-destination');equal(stage,'turn-in')
 s.accepted=false;missing,reason=ns.HintData.Snapshot(1);equal(missing,nil);equal(reason,'removed')
end)
test("completion clears objective guidance before turn-in data is ready and a new request uses the normal modes",function()
 for _,distance in ipairs({500,100}) do
  local ns,s=serviceFixture();ns.Hints.Request(1);equal(s.shown,true)
  s.error='no-destination';s.observedStage='turn-in';ns.Hints.Update()
  equal(ns.Hints.active,nil);equal(s.shown,false);equal(s.areaRequests,0)
  s.error=nil;s.observedStage=nil;s.stage='turn-in';s.distance=distance
  ns.Hints.Update();equal(ns.Hints.active,nil) -- Data becoming available is not permission.
  ns.Hints.Request(1);equal(ns.Hints.active.stage,'turn-in')
  equal(ns.Hints.controller.mode,distance==500 and 'bearing' or 'area')
  ns.Hints.Update();assert(ns.Hints.active) -- The completed phase remains stable.
  s.error='removed';ns.Hints.Update();equal(ns.Hints.active,nil)
 end
end)
print(total.." hint fixture tests passed; native bearing and distance units remain unverified.")
