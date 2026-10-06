-- Native geometry is simulated here; these tests establish request/lifecycle
-- rules, bounded work and sample handling, not Forever renderer compatibility.
local total=0
local function equal(a,b) assert(a==b,tostring(a).." ~= "..tostring(b)) end
local function test(name,fn) fn();total=total+1;print("ok - "..name) end
local function load(ns,env,name)
 local chunk=assert(loadfile("addon/JustAHint/"..name..".lua"));setfenv(chunk,env);chunk("JustAHint",ns)
end
local function fixture()
 local state={time=0,px=0.25,py=0.9,stage="objective",mapID=1,phase="objective",
  queryCalls=0,draws=0,feedback=0,arrivals=0,areas=0,frames={},nativeX=0.8,nativeY=0.5,notes={}}
 local env=setmetatable({}, {__index=_G});env._G=env;env.UIParent={}
 env.GetTime=function() return state.time end
 env.CreateFrame=function(kind,_,parent)
  local f={kind=kind,parent=parent,shown=true,scripts={}}
  function f:Hide() self.shown=false end
  function f:Show() self.shown=true end
  function f:IsVisible() return self.shown end
  function f:SetAlpha(v) self.alpha=v end
  function f:SetFillAlpha(v) self.fill=v end
  function f:SetBorderAlpha(v) self.border=v end
  function f:SetScript(k,v) self.scripts[k]=v end
  function f:DrawNone() self.quest=nil end
  function f:DrawBlob(id,draw)
   equal(draw,true);equal(self.alpha,0);equal(self.fill,0);equal(self.border,0)
   self.quest=id;state.draws=state.draws+1
  end
  function f:UpdateMouseOverTooltip(x,y)
   state.queryCalls=state.queryCalls+1
   if state.queryError then error("restricted native query") end
   if state.malformed then return "invalid",1 end
   if not self.quest or state.noRegion then return end
   if state.tiny then
    if math.abs(x-state.px)<0.0001 and math.abs(y-state.py)<0.0001 then return self.quest,1 end
    return
   end
   if (math.abs(x-0.2)<=0.03 or math.abs(x-0.8)<=0.03) and math.abs(y-0.5)<=0.03 then
    if state.zeroCount then return self.quest,0 end
    return self.quest,2
   end
  end
  for _,name in ipairs({"EnableMouse","SetSize","SetPoint","SetFillTexture","SetBorderTexture","SetBorderScalar","SetMapID"}) do f[name]=function() end end
  state.frames[#state.frames+1]=f
  return f
 end
 local ns={}
 ns.ID=function(v) return type(v)=="number" and v>0 and v%1==0 end
 ns.Note=function(k,v) state.notes[k]=v end
 ns.Message=function(m) state.message=m end
 ns.InCombat=function() return state.combat==true end
 ns.Guard={active=true};ns.SettingsPanel={UpdateState=function() end}
 local function world(p) return {x=p.x*10000,y=p.y*10000,space=1} end
 local function distance(a,b) if a.space~=b.space then return end;return math.sqrt((a.x-b.x)^2+(a.y-b.y)^2) end
 ns.HintData={WorldPoint=world,Distance=distance,CurrentMap=function() return state.mapID end,Facing=function() return 0 end}
 function ns.HintData.Snapshot(id)
  if state.dataError then return nil,state.dataError,state.stage end
  local point={mapID=state.mapID,x=state.nativeX,y=state.nativeY,source="native-map-point"}
  local playerPoint={mapID=state.mapID,x=state.px,y=state.py}
  local player,target=world(playerPoint),world(point)
  return {mapID=state.mapID,stage=state.stage,phase=state.phase,player=player,playerPoint=playerPoint,
   target=target,destination=point,distance=distance(player,target)}
 end
 ns.Bearing={frame={IsVisible=function() return state.shown==true end},Hide=function() state.shown=false end,
  Show=function(x,y) state.shown=true;state.arrowX=x;state.arrowY=y;return true end}
 ns.Area={Clear=function() state.areaShown=false end,Show=function(id,_,point)
  state.areas=state.areas+1;state.areaShown=true;state.areaPoint=point;return true end,
  IsVisible=function() return state.areaShown end,Check=function() return state.areaShown,"map-closed" end,
  Update=function() return true end,Suspend=function() state.areaShown=false;return true end}
 ns.Feedback={BearingRequested=function(sample) state.feedback=state.feedback+1;state.feedbackSample=sample end,
  Arrived=function(owner)
   equal(owner.id,1);equal(ns.Hints.active,nil);equal(state.shown,false)
   equal(ns.RegionHints.region,nil);equal(ns.Hints.controller.reason,"arrived")
   state.arrivals=state.arrivals+1
  end}
 load(ns,env,"HintController");load(ns,env,"RegionHints");load(ns,env,"Hints")
 function state.tick()
  state.time=state.time+0.02
  for _,frame in ipairs(state.frames) do
   if frame.shown and frame.scripts.OnUpdate then frame.scripts.OnUpdate(frame,0.02) end
  end
 end
 function state.finish()
  for _=1,200 do
   if not ns.RegionHints.job then return end
   local before=state.queryCalls
   state.tick()
   -- Bulk query work plus at most one live arrival-position check.
   assert(state.queryCalls-before<=65)
  end
  error("region request never completed")
 end
 return ns,state,env
end

test("passive availability never samples regions and pending requests disable Hint",function()
 local ns,s=fixture();equal(ns.Hints.Availability(1),"ready");equal(s.queryCalls,0);equal(s.draws,0)
 local button={SetShown=function() end,SetEnabled=function(self,v) self.enabled=v end,SetText=function(self,v) self.text=v end}
 ns.Hints.Request(1);assert(ns.Hints.active.pending);equal(s.shown,false);equal(s.feedback,0)
 ns.Hints.UpdateButton(button,1);equal(button.enabled,false);equal(button.text,"Loading hint…")
 s.finish();equal(ns.Hints.controller.mode,"bearing");equal(s.feedback,1)
 equal(ns.Hints.active.source,"native-region-sample");assert(ns.Hints.active.target.x<3000)
 assert(ns.Hints.active.region);equal(s.draws,1)
end)
test("nearest sample stays inside a native site and the requested target never switches",function()
 local ns,s=fixture();ns.Hints.Request(1);s.finish()
 local target=ns.Hints.active.target
 assert(target.x>=1700 and target.x<=2300);assert(target.y>=4700 and target.y<=5300)
 s.px=0.7;s.py=0.9;s.nativeX=0.9;ns.Hints.Update()
 equal(ns.Hints.active.target,target);equal(s.draws,1);equal(s.feedback,1)
end)
test("arrival at another region acknowledges once without revealing more or reviving after walking away",function()
 local ns,s=fixture();ns.Hints.Request(1);s.finish();assert(ns.Hints.active.target.x<3000)
 s.px=0.8;s.py=0.5
 for _=1,65 do s.tick() end
 equal(ns.Hints.active,nil);equal(s.shown,false);equal(s.areas,0);equal(s.feedback,1);equal(s.arrivals,1)
 equal(ns.RegionHints.region,nil);equal(ns.RegionHints.frame.shown,false)
 s.py=0.9;for _=1,20 do s.tick() end;equal(s.shown,false);equal(s.areas,0);equal(s.arrivals,1)
end)
test("being inside any site authorizes an area directly despite a distant native point",function()
 local ns,s=fixture();s.px=0.2;s.py=0.5;s.nativeX=0.8
 ns.Hints.Request(1);s.finish();equal(ns.Hints.controller.mode,"area")
 equal(s.areas,1);equal(s.feedback,0);equal(s.shown,false);equal(s.arrivals,0)
 assert(s.areaPoint.x<0.3);ns.Hints.Clear();equal(s.areaShown,false);equal(ns.RegionHints.region,nil)
end)
test("seeding current position catches tiny native regions missed by a regular grid",function()
 local ns,s=fixture();s.px=0.234567;s.py=0.56789;s.tiny=true
 ns.Hints.Request(1);s.finish();equal(ns.Hints.controller.mode,"area");equal(s.areas,1)
 assert(#ns.Hints.active.region.points>=1)
end)
test("ordinary progress preserves samples while new stages clear all invisible geometry",function()
 local ns,s=fixture();ns.Hints.Request(1);s.finish();local r=ns.Hints.active.region
 ns.Hints.Update();equal(ns.Hints.active.region,r);equal(s.draws,1)
 s.stage="new objective";ns.Hints.Update();equal(ns.Hints.active,nil);equal(ns.RegionHints.frame.shown,false)
 equal(s.areas,0);equal(s.feedback,1);equal(s.arrivals,0)
end)
test("pending cancellation cannot complete or resurrect a replaced request",function()
 for _,why in ipairs({"clear","stage","zone","combat","removed","restore"}) do
  local ns,s=fixture();ns.Hints.Request(1);local late=ns.RegionHints.job.done
  if why=="clear" then ns.Hints.Clear()
  elseif why=="stage" then s.stage="other"
  elseif why=="zone" then s.mapID=2
  elseif why=="combat" then s.combat=true
  elseif why=="removed" then s.dataError="removed"
  else ns.Guard.active=false end
  ns.Hints.Update();equal(ns.Hints.active,nil);late(nil)
  equal(s.feedback,0);equal(s.areas,0);equal(s.shown,false);equal(s.arrivals,0);equal(ns.RegionHints.job,nil)
 end
 local ns,s=fixture();ns.Hints.Request(1);local late=ns.RegionHints.job.done
 ns.Hints.Request(2);late(nil);assert(ns.Hints.active.pending);equal(ns.Hints.active.id,2)
 s.finish();equal(ns.Hints.active.id,2);equal(s.feedback,1)
end)
test("misses malformed queries and restrictions fall back only for the explicit request",function()
 for _,why in ipairs({"noRegion","queryError","malformed","zeroCount"}) do
  local ns,s=fixture();s[why]=true;ns.Hints.Request(1);s.finish()
  equal(ns.Hints.active.source,"native-map-point");equal(ns.Hints.active.region,nil)
  equal(ns.Hints.controller.mode,"bearing");equal(s.feedback,1);equal(s.areas,0)
  equal(ns.RegionHints.frame.shown,false)
 end
end)
test("turn-in requests keep native point behavior and skip region sampling",function()
 local ns,s=fixture();s.stage="turn-in";s.phase="turn-in"
 ns.Hints.Request(1);equal(ns.Hints.controller.mode,"bearing");equal(s.draws,0);equal(s.queryCalls,0)
end)
test("native click completion callbacks run once after rendering and never after clear",function()
 local ns,s=fixture();local calls=0
 ns.Hints.Request(1,function() calls=calls+1;equal(s.shown,true) end)
 equal(calls,0);s.finish();equal(calls,1);s.tick();equal(calls,1)
 ns.Hints.Request(2,function() calls=calls+1 end);ns.Hints.Clear();s.finish();equal(calls,1)
end)
test("restricted live position query suspends rather than swapping to unsolicited guidance",function()
 local ns,s=fixture();ns.Hints.Request(1);s.finish();local target=ns.Hints.active.target
 s.queryError=true;ns.Hints.Update();equal(s.shown,false);equal(s.areas,0);equal(ns.Hints.active.target,target)
 s.queryError=false;ns.Hints.Update();equal(s.shown,true);equal(s.feedback,1);equal(ns.Hints.active.target,target)
end)
test("failed completion callbacks clear pending and visible owned guidance",function()
 local ns,s=fixture();ns.Hints.Request(1,function() error("failed callback") end);s.finish()
 equal(ns.Hints.active,nil);equal(s.shown,false);equal(ns.RegionHints.frame.shown,false)
end)
print(total.." region request fixture tests passed; native sampling and arrival still require playtesting.")
