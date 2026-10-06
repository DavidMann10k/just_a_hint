-- UI policy fixtures; these do not verify native rendering or secure actions.
local total=0
local function equal(a,b) assert(a==b,'expected '..tostring(b)..', got '..tostring(a)) end
local function near(a,b,tolerance) assert(math.abs(a-b)<(tolerance or 0.00001),'expected near '..tostring(b)..', got '..tostring(a)) end
local function test(name,fn)
 local ok,err=pcall(fn);assert(ok,name..': '..tostring(err));total=total+1;print('ok - '..name)
end
local function load(ns,env,name)
 local chunk=assert(loadfile('addon/JustAHint/'..name..'.lua'));setfenv(chunk,env);chunk('JustAHint',ns)
end
local function fixture(saved)
 local env=setmetatable({},{__index=_G});env._G=env
 local s={time=0,messages={},sounds=0,soundLog={},requests=0,mapID=2521,events={},availability='ready'}
 local function ui(parent)
  local f={shown=true,enabled=true,scripts={},points={},parent=parent}
  for _,name in ipairs({'SetAllPoints','SetFrameLevel','EnableMouse','SetBackdrop','SetBackdropColor',
   'SetClampedToScreen','SetJustifyH','SetJustifyV',
   'SetVertexColor','SetBackdropBorderColor','SetMovable','RegisterForDrag','SetFontObject','SetFont','SetSpacing','StartMoving','StopMovingOrSizing'}) do
   f[name]=function() if s.textureError and name=='SetColorTexture' then error('restricted texture') end end
  end
  function f:SetColorTexture(...)
   if s.textureError then error('restricted texture') end
   self.color={...}
  end
  function f:SetPoint(...) self.points[#self.points+1]={...} end
  function f:ClearAllPoints() self.points={} end
  function f:GetPoint(i) return unpack(self.points[i or 1] or {}) end
  function f:GetNumPoints() return #self.points end
  function f:SetSize(w,h) self.width,self.height=w,h end
  function f:SetWidth(w) self.width=w end
  function f:SetHeight(h) self.height=h end
  function f:GetFont() return nil end
  function f:GetStringHeight() return 40 end
  function f:SetScrollChild(child) self.child=child end
  function f:SetVerticalScroll(value) self.scroll=value end
  function f:Disable() self.enabled=false end
  function f:SetText(text) self.text=text end
  function f:SetAlpha(alpha) self.alpha=alpha end
  function f:SetAtlas(atlas) if s.atlasError then error('atlas unavailable') end;self.atlas=atlas end
  function f:SetRotation(angle) self.rotation=angle end
  function f:SetScale(scale) self.scale=scale end
  function f:SetFrameStrata(strata) self.strata=strata end
  function f:EnableMouse(enabled) self.mouseEnabled=enabled end
  function f:SetScript(name,fn) self.scripts[name]=fn end
  function f:RegisterEvent(event)
   if s.refuseEvents then error('event unavailable') end
  end
  function f:SetShown(value) self.shown=value end
  function f:Show() self.shown=true end
  function f:Hide() self.shown=false end
  function f:IsShown() return self.shown end
  function f:IsVisible() return self.shown and (not self.parent or self.parent:IsVisible()) end
  function f:IsProtected() return self.protected or false end
  function f:SetEnabled(value) self.enabled=value end
  function f:IsEnabled() return self.enabled end
  function f:GetWidth() return self.width or 160 end
  function f:GetHeight() return self.height or 160 end
  function f:GetFrameLevel() return 1 end
  function f:GetFrameStrata() return 'DIALOG' end
  function f:GetEffectiveScale() return self.scale or 1 end
  function f:GetRect() return unpack(self.rect or {100,100,160,160}) end
  function f:SetChecked(value) self.checked=value end
  function f:GetChecked() return self.checked end
  function f:CreateTexture() return ui() end
  function f:CreateFontString() return ui() end
  function f:GetFontString() return ui() end
  return f
 end
 env.CreateFrame=function(_,_,parent) local frame=ui(parent);s.lastFrame=frame;return frame end
 env.UIParent=ui();env.UIParent:SetSize(1920,1080);env.UISpecialFrames={}
 env.Minimap=ui();env.WorldMapFrame=ui()
 function env.WorldMapFrame:GetMapID() return s.mapID end
 function env.WorldMapFrame:SetMapID(id) s.mapID=id end
 env.EventRegistry={TriggerEvent=function(_,event) s.events[#s.events+1]=event end}
 env.QuestMapFrame={DetailsFrame=ui(env.WorldMapFrame)}
 local details=env.QuestMapFrame.DetailsFrame
 details.RewardsFrameContainer=ui(details)
 details.RewardsFrameContainer:SetPoint('BOTTOMLEFT',details,'BOTTOMLEFT',0,23)
 details.DestinationMapButton=ui(details);details.WaypointMapButton=ui(details)
 details.TrackButton=ui(details);details.AbandonButton=ui(details);details.ShareButton=ui(details)
 env.QuestMapFrame_GetFocusedQuestID=function() return s.focused end
 env.C_QuestLog={GetSelectedQuest=function() return s.selected end}
 env.QuestMapFrame_ShowQuestDetails=function(id)
  s.selected,s.focused,details.questID=id,id,id
  details:Show();env.WorldMapFrame:Show();details.DestinationMapButton:Show()
  if s.nativeMapID~=0 then
   env.WorldMapFrame:SetMapID(s.nativeMapID or 999);env.EventRegistry:TriggerEvent('MapCanvas.PingQuestID',id)
  end
  if s.detailsError then error('details failed') end
 end
 env.QuestMapFrame_OpenToQuestDetails=function(id) env.QuestMapFrame_ShowQuestDetails(id) end
 env.HideUIPanel=function(frame) s.closes=(s.closes or 0)+1;frame:Hide() end
 env.GetTime=function() return s.time end
 env.InCombatLockdown=function() return s.combat end
 env.SOUNDKIT={IG_MAINMENU_OPTION_CHECKBOX_ON=856,MAP_PING=3175}
 env.PlaySound=function(id,channel)
  s.sounds=s.sounds+1;s.soundLog[#s.soundLog+1]={id=id,channel=channel}
  if s.soundError then error('sound unavailable') end
 end
 env.DEFAULT_CHAT_FRAME={AddMessage=function(_,text) s.messages[#s.messages+1]=text end}
 env.JustAHintDB=saved
 local ns={};load(ns,env,'Core');ns.Initialize()
 ns.Guard={active=true,Action=function() return "restore" end};ns.Bearing={frame=ui(env.Minimap),atlas='Navigation-Tracked-Arrow'}
 ns.Bearing.frame.arrow=ui();ns.Bearing.frame.arrow:SetSize(16,24)
 ns.Hints={active={id=1},controller={mode='bearing',visible=true},
  Request=function(id) s.requests=s.requests+1;s.requestID=id end,
  UpdateButton=function(button,id)
   button:SetShown(s.availability~='hidden');button:SetEnabled(s.availability=='ready');return s.availability
  end}
 ns.Hints.Toggle=function(id) ns.Hints.Request(id);return 'requested' end
 load(ns,env,'HintFeedback');load(ns,env,'SettingsPanel');load(ns,env,'NativeQuestPane')
 return ns,s,env
end
local function sample(east,north,distance)
 return {player={x=0,y=east},target={x=north,y=0},distance=distance or 500}
end

local function arrivalFixture(saved)
 local ns,s,env=fixture(saved)
 env.C_Texture={GetAtlasInfo=function() return {width=32,height=48} end}
 load(ns,env,'MinimapBearing');load(ns,env,'HintController')
 s.distance,s.stage=500,'stage-one'
 ns.Area={Clear=function() s.areaShown=false end}
 ns.HintData={
  CurrentMap=function() return s.mapID end,
  Facing=function() if not s.noFacing then return 0 end end,
  Distance=function(a,b) return math.sqrt((a.x-b.x)^2+(a.y-b.y)^2) end,
  Snapshot=function()
   if s.dataError then return nil,s.dataError end
   return {stage=s.stage,mapID=s.mapID,target={x=0,y=0,space=0},player={x=-s.distance,y=0,space=0},
    distance=s.distance,destination={source='fixture-native-point'}}
  end,
 }
 load(ns,env,'Hints')
 return ns,s,env
end

local function arrive(ns,s)
 s.distance=140
 for _,time in ipairs({0.1,0.4,0.7,1.0,1.2}) do s.time=time;ns.Hints.Update() end
 equal(ns.Hints.active,nil);equal(ns.Hints.controller.reason,'arrived')
 equal(ns.Bearing.frame:IsShown(),false)
end

test('preferences preserve false and reload never starts feedback',function()
 local ns,s=fixture({presentation={text=false,arrowPulse=false,standalone=true}})
 equal(ns.DB.presentation.text,false);equal(ns.DB.presentation.arrowPulse,false)
 equal(ns.DB.presentation.standalone,nil);equal(ns.DB.presentation.sound,true)
 equal(ns.Feedback.elapsed,nil);equal(s.requests,0);equal(#s.messages,0)
 equal(ns.DB.presentation.arrowFlight,true);equal(ns.Feedback.flying,nil)
 ns=fixture({presentation={arrowFlight=false}});equal(ns.DB.presentation.arrowFlight,false)
end)
test('plainspoken direction uses world bearings and broad distances',function()
 local ns=fixture();local words={'north','northeast','east','southeast','south','southwest','west','northwest'}
 for i,v in ipairs({{0,1},{1,1},{1,0},{1,-1},{0,-1},{-1,-1},{-1,0},{-1,1}}) do
  equal(ns.Feedback.Text(sample(v[1],v[2])),'Head '..words[i]..". It's a fair way from here.")
 end
 equal(ns.Feedback.Text(sample(1,0,200)),"Head east. It's not far from here.")
 equal(ns.Feedback.Text(sample(1,0,1000)),"Head east. It's a long way from here.")
end)
test('explicit bearing produces a bounded pulse without closing settings',function()
 local ns,s,env=fixture();ns.Feedback.x,ns.Feedback.y=1,0
 ns.SettingsPanel.Set('arrowFlight',false)
 ns.Feedback.BearingRequested(sample(1,0))
 equal(env.WorldMapFrame:IsShown(),true);equal(ns.Reader,nil)
 equal(s.closes,nil);equal(s.sounds,1);equal(#s.messages,1);equal(ns.Feedback.elapsed,0)
 ns.Feedback.Update(0.3);assert(ns.Feedback.frame.rim[1].alpha>0);assert(ns.Feedback.frame.halo[1].alpha>0)
 equal(s.requests,0);ns.Feedback.Update(1);equal(ns.Feedback.elapsed,nil);equal(ns.Feedback.frame:IsShown(),false)
 ns.Feedback.Update(0.1);equal(s.sounds,1);equal(#s.messages,1)
end)
test('settings independently disable feedback without changing the active hint',function()
 local ns,s=fixture();local active=ns.Hints.active
 for _,key in ipairs({'arrowFlight','arrowPulse','minimapPulse','sound','text'}) do ns.SettingsPanel.Set(key,false) end
 ns.Feedback.BearingRequested(sample(1,0));equal(s.sounds,0);equal(#s.messages,0);equal(ns.Feedback.frame,nil)
 equal(ns.Hints.active,active);ns.SettingsPanel.Open()
 for key,check in pairs(ns.SettingsPanel.frame.checks) do equal(check:GetChecked(),ns.SettingsPanel.Value(key)) end
end)
test('chat duplicates are limited while explicit requests can pulse again',function()
 local ns,s=fixture();ns.Feedback.BearingRequested(sample(1,0))
 s.time=1;ns.Feedback.BearingRequested(sample(1,0));equal(#s.messages,1);equal(s.sounds,2)
 s.time=11;ns.Feedback.BearingRequested(sample(1,0));equal(#s.messages,2)
end)
test('arrival gaps hidden minimap and errors cannot revive feedback',function()
 for _,case in ipairs({'arrival','gap','hidden','guard','replacement','area','guard-problem'}) do
  local ns,s,env=fixture();ns.Feedback.BearingRequested(sample(1,0))
  if case=='arrival' then ns.Hints.active=nil elseif case=='gap' then ns.Hints.controller.visible=false
  elseif case=='hidden' then env.Minimap:Hide() elseif case=='guard' then ns.Guard.active=false
  elseif case=='replacement' then ns.Hints.active={id=1} elseif case=='area' then ns.Hints.controller.mode='area'
  else ns.Guard.problem='failed' end
  ns.Feedback.Update(0.1);equal(ns.Feedback.elapsed,nil);equal(ns.Feedback.frame:IsShown(),false)
  equal(ns.Bearing.frame.arrow.alpha,1);equal(ns.Feedback.flying,nil)
  ns.Hints.active={id=1};ns.Hints.controller.visible=true;env.Minimap:Show();ns.Guard.active=true
  ns.Feedback.Update(0.1);equal(ns.Feedback.frame:IsShown(),false);equal(s.sounds,1)
 end
 local ns,s=fixture();s.textureError=true;ns.Feedback.BearingRequested(sample(1,0))
 equal(ns.Feedback.elapsed,nil);equal(ns.Feedback.frame:IsShown(),false);assert(ns.DB.lastCheck.feedbackError)
end)
test('feedback alone never calls the native panel closure',function()
 local ns,s,env=fixture()
 env.HideUIPanel=function() error('native panel must not be touched') end
 ns.Feedback.BearingRequested(sample(1,0));equal(#s.messages,1);equal(s.sounds,1);assert(ns.Feedback.frame)
end)
test('a hidden arrow has no deferred notification',function()
 local ns,s=fixture();ns.Bearing.frame:Hide();ns.Feedback.BearingRequested(sample(1,0))
 equal(#s.messages,0);equal(s.sounds,0);equal(ns.Feedback.frame,nil)
 ns.Bearing.frame:Show();ns.Feedback.Update(0.1);equal(ns.Feedback.frame,nil)
end)
test('arrow and minimap pulses can be disabled independently',function()
 for _,key in ipairs({'arrowPulse','minimapPulse'}) do
  local ns=fixture();ns.SettingsPanel.Set('arrowFlight',false);ns.SettingsPanel.Set(key,false)
  ns.Feedback.BearingRequested(sample(1,0));ns.Feedback.Update(0.3)
  equal(ns.Feedback.frame.rim[1].alpha>0,key~='minimapPulse')
  equal(ns.Feedback.frame.halo[1].alpha>0,key~='arrowPulse')
 end
end)
test('requested arrow reveals at screen center, follows a curved trail and hands off to a landing ripple',function()
 local ns,s,env=fixture();env.Minimap.rect={1680,840,160,160};ns.Feedback.x,ns.Feedback.y=1,0
 ns.Feedback.BearingRequested(sample(1,0));local frame=ns.Feedback.frame
 equal(frame.parent,env.UIParent);equal(frame.strata,'TOOLTIP');equal(frame.mouseEnabled,false)
 equal(frame.flight.atlas,ns.Bearing.atlas);equal(ns.Bearing.frame.arrow.alpha,0)
 local point=frame.flight.points[1];near(point[4],960);near(point[5],540)
 ns.Feedback.Update(0.18);near(frame.flight.height,64);equal(frame.flight.alpha,1)
 ns.Feedback.Update(0.12);point=frame.flight.points[1]
 near(point[4],960);near(point[5],540);near(frame.rim[1].alpha,0.7)
 near(frame.rim[1].points[1][5],540)
 near(frame.rim[1].points[1][4],960+64*0.65+6)
 ns.Feedback.Update(0.125);point=frame.flight.points[1]
 near(point[4],960);near(point[5],540);assert(frame.rim[1].alpha>0)
 ns.Feedback.Update(0.005+0.68/0.75/2);point=frame.flight.points[1]
 near(point[4],(960+1824)/2-380*0.06);near(point[5],(540+920)/2+864*0.06)
 assert(frame.flight.height<64);assert(frame.trail[1]:IsShown());assert(frame.trail[1].alpha>0)
 equal(frame.rim[1].alpha,0);equal(frame.halo[1].alpha,0)
 ns.Feedback.Update(0.68/0.75/2-0.01);point=frame.flight.points[1]
 near(point[4],1824,1);near(point[5],920,1);near(frame.flight.height,24,0.1)
 near(frame.flight.rotation,-math.pi/2,0.01)
 ns.Feedback.Update(0.02);equal(ns.Feedback.flying,nil);equal(frame.flight:IsShown(),false)
 equal(ns.Bearing.frame.arrow.alpha,1)
 for _,texture in ipairs(frame.trail) do equal(texture:IsShown(),false) end
 ns.Feedback.Update(0.15);assert(frame.rim[1].alpha>0);assert(frame.halo[1].alpha>0)
 for i=1,3 do ns.Feedback.Update(0.4) end
 equal(ns.Feedback.elapsed,nil);equal(frame:IsShown(),false);equal(s.sounds,1);equal(#s.messages,1)
 ns.Feedback.BearingRequested(sample(1,0));equal(ns.Feedback.frame,frame);equal(#frame.trail,5)
 equal(ns.Feedback.flying,true);equal(s.requests,0)
end)
test('one center pulse follows the departing arrow and respects arrow-pulse preferences',function()
 for _,options in ipairs({{}, {arrowPulse=false}, {minimapPulse=false}}) do
  local ns,s,env=fixture({presentation=options});env.Minimap.rect={1680,840,160,160}
  ns.Feedback.BearingRequested(sample(1,0));local frame=ns.Feedback.frame
  ns.Feedback.Update(0.3)
  near(frame.flight.points[1][4],960);near(frame.flight.points[1][5],540)
  near(frame.rim[1].alpha,options.arrowPulse==false and 0 or 0.7)
  ns.Feedback.Update(0.2)
  local arrowPoint,ringPoint=frame.flight.points[1],frame.rim[1].points[1]
  assert(arrowPoint[4]~=960 or arrowPoint[5]~=540)
  near(ringPoint[5],arrowPoint[5])
  near(ringPoint[4],arrowPoint[4]+math.max(frame.flight.width,frame.flight.height)*0.65+10)
  if options.arrowPulse~=false then assert(frame.rim[1].alpha>0 and frame.rim[1].alpha<0.7) end
  ns.Feedback.Update(0.1);equal(frame.rim[1].alpha,0)
  ns.Feedback.Update(0.2);equal(frame.rim[1].alpha,0)
  ns.Feedback.Update(0.4);equal(ns.Feedback.flying,true);equal(frame.rim[1].alpha,0)
  ns.Feedback.Update(0.14);equal(ns.Feedback.flying,nil)
  ns.Feedback.Update(0.15)
  equal(frame.rim[1].alpha>0,options.minimapPulse~=false)
  equal(frame.halo[1].alpha>0,options.arrowPulse~=false)
  equal(s.sounds,1);equal(#s.messages,1)
 end
end)
test('flight and landing track the live bearing and moved or scaled minimap on wide and narrow screens',function()
 for _,screen in ipairs({{1920,1080},{800,600}}) do
  local ns,s,env=fixture();env.UIParent:SetSize(screen[1],screen[2]);env.UIParent:SetScale(0.8)
  env.Minimap:SetScale(0.6);env.Minimap.rect={600,440,200,160}
  ns.Feedback.BearingRequested(sample(1,0));local frame=ns.Feedback.frame
  near(frame.flight.points[1][4],screen[1]/2);near(frame.flight.points[1][5],screen[2]/2)
  ns.Feedback.Update(0.4);env.Minimap.rect={520,420,200,160};ns.Feedback.x,ns.Feedback.y=0,-1
  ns.Feedback.Update(0.4);ns.Feedback.Update(0.4);ns.Feedback.Update(0.18+0.25+0.68/0.75-1.21)
  -- Effective scale ratio is 0.75: the south-rim position is (465, 327).
  near(frame.flight.points[1][4],465,1);near(frame.flight.points[1][5],327,1)
  near(math.abs(frame.flight.rotation),math.pi,0.01);near(frame.flight.height,18,0.1)
  ns.Feedback.Update(0.02);ns.Feedback.Update(0.15)
  local point=frame.halo[1].points[1]
  near(point[5],327);assert(point[4]>465)
  equal(ns.Bearing.frame.arrow.alpha,1);equal(ns.Hints.active.id,1)
 end
end)
test('flight remains independent of pulses and can be disabled during animation without hiding the bearing',function()
 local ns,s=fixture();local active=ns.Hints.active
 ns.SettingsPanel.Set('arrowPulse',false);ns.SettingsPanel.Set('minimapPulse',false)
 ns.Feedback.BearingRequested(sample(1,0));ns.Feedback.Update(0.4)
 equal(ns.Feedback.flying,true);equal(ns.Bearing.frame.arrow.alpha,0)
 ns.SettingsPanel.Set('arrowFlight',false)
 equal(ns.Feedback.elapsed,nil);equal(ns.Feedback.frame:IsShown(),false);equal(ns.Bearing.frame.arrow.alpha,1)
 equal(ns.Hints.active,active);equal(ns.Bearing.frame:IsVisible(),true)
 ns.SettingsPanel.Set('arrowFlight',true);equal(ns.Feedback.elapsed,nil)
 ns.Feedback.BearingRequested(sample(1,0));ns.Feedback.Update(0.4);ns.Feedback.Update(0.4);ns.Feedback.Update(0.4);ns.Feedback.Update(0.2)
 equal(ns.Feedback.elapsed,nil);equal(ns.Bearing.frame.arrow.alpha,1);equal(ns.Hints.active,active)
end)
test('stalls and unavailable animation geometry or artwork restore the bearing without replaying feedback',function()
 for _,case in ipairs({'stall','geometry','malformed','atlas','rotation'}) do
  local ns,s,env=fixture();ns.Feedback.BearingRequested(sample(1,0));local active=ns.Hints.active
  ns.Feedback.Update(0.4)
  if case=='geometry' then env.Minimap.GetRect=function() error('restricted geometry') end
  elseif case=='malformed' then env.Minimap.rect={0,0,0/0,160}
  elseif case=='atlas' then
   ns.Feedback.Hide();ns.Feedback.frame.flight=nil;s.atlasError=true;ns.Feedback.BearingRequested(sample(1,0))
  elseif case=='rotation' then ns.Feedback.frame.flight.SetRotation=function() error('restricted texture') end end
  ns.Feedback.Update(case=='stall' and 2 or 0.1)
  equal(ns.Feedback.elapsed,nil);equal(ns.Feedback.frame:IsShown(),false);equal(ns.Bearing.frame.arrow.alpha,1)
  equal(ns.Hints.active,active);equal(ns.Bearing.frame:IsVisible(),true)
  if case~='stall' then assert(ns.DB.lastCheck.feedbackError) end
  env.Minimap.rect={100,100,160,160};ns.Feedback.Update(0.1);equal(ns.Feedback.frame:IsShown(),false)
  equal(s.requests,0)
 end
end)

test('arrival clears the bearing before one distinct sound and exactly two green minimap pulses',function()
 local ns,s=arrivalFixture();ns.Hints.Request(1);local owner=ns.Hints.active
 equal(s.soundLog[1].id,856)
 arrive(ns,s)
 equal(s.sounds,2);equal(s.soundLog[2].id,3175);equal(s.soundLog[2].channel,'SFX')
 equal(ns.Feedback.arriving,owner);equal(ns.Feedback.flying,nil)
 local frame=ns.Feedback.frame
 near(frame.rim[1].color[1],0.35);near(frame.rim[1].color[2],0.9);near(frame.rim[1].color[3],0.5)
 equal(frame.halo[1].alpha,0);equal(frame.flight:IsShown(),false)
 near(frame.rim[1].alpha,0)
 ns.Feedback.Update(0.3);near(frame.rim[1].alpha,0.7)
 ns.Feedback.Update(0.3);near(frame.rim[1].alpha,0)
 ns.Feedback.Update(0.3);near(frame.rim[1].alpha,0.7)
 ns.Feedback.Update(0.31);equal(frame:IsShown(),false);equal(ns.Feedback.elapsed,nil)
 equal(ns.Feedback.arriving,nil);equal(#s.messages,1);equal(s.areaShown,false)
 ns.Feedback.Arrived(owner);ns.Feedback.Update(0.3)
 equal(s.sounds,2);equal(frame:IsShown(),false)
 s.distance=500;s.time=3;ns.Hints.Update();equal(ns.Bearing.frame:IsShown(),false)
end)

test('arrival works after the request animation has finished',function()
 local ns,s=arrivalFixture();ns.Hints.Request(1)
 for i=1,8 do ns.Feedback.Update(0.4) end
 equal(ns.Feedback.frame:IsShown(),false)
 arrive(ns,s);equal(ns.Feedback.elapsed,0);equal(s.sounds,2)
 ns.Feedback.Update(0.3);assert(ns.Feedback.frame.rim[1].alpha>0)
end)

test('arrival sound and minimap pulses respect saved preferences independently',function()
 for _,options in ipairs({{sound=false},{minimapPulse=false},{sound=false,minimapPulse=false}}) do
  local ns,s=arrivalFixture({presentation=options});ns.Hints.Request(1);arrive(ns,s)
  local sounds=options.sound==false and 0 or 2
  equal(s.sounds,sounds)
  equal(ns.Feedback.arriving~=nil,options.minimapPulse~=false)
  ns.SettingsPanel.Set('sound',true);ns.Feedback.Update(0.1)
  equal(s.sounds,sounds)
 end
 local ns,s=arrivalFixture({presentation={arrowFlight=false,arrowPulse=false}})
 ns.Hints.Request(1);arrive(ns,s);assert(ns.Feedback.arriving)
 equal(ns.Feedback.frame.flight,nil);equal(ns.Feedback.frame.halo[1].alpha,0)
end)

test('disabling arrival pulses or hiding the minimap cancels without replay',function()
 for _,case in ipairs({'setting','hidden','stall','geometry'}) do
  local ns,s,env=arrivalFixture();ns.Hints.Request(1);arrive(ns,s);ns.Feedback.Update(0.3)
  if case=='setting' then ns.SettingsPanel.Set('minimapPulse',false)
  elseif case=='hidden' then env.Minimap:Hide()
  elseif case=='geometry' then env.Minimap.rect={0,0,0/0,160} end
  ns.Feedback.Update(case=='stall' and 2 or 0.1)
  equal(ns.Feedback.elapsed,nil);equal(ns.Feedback.frame:IsShown(),false)
  env.Minimap:Show();env.Minimap.rect={100,100,160,160};ns.SettingsPanel.Set('minimapPulse',true)
  ns.Feedback.Update(0.3);equal(ns.Feedback.frame:IsShown(),false);equal(s.sounds,2)
 end
end)

test('arrival pulses follow a moved and scaled minimap without needing a bearing',function()
 local ns,s,env=arrivalFixture();ns.Hints.Request(1);arrive(ns,s)
 env.UIParent:SetScale(0.8);env.Minimap:SetScale(0.6);env.Minimap.rect={520,420,200,160}
 ns.Feedback.Update(0.3)
 local point=ns.Feedback.frame.rim[1].points[1]
 near(point[4],465+60+7.5*0.75);near(point[5],375)
 equal(ns.Bearing.frame:IsShown(),false);equal(ns.Hints.active,nil)
end)

test('missing arrival sound kits and playback failures do not prevent pulses',function()
 for _,case in ipairs({'missing-ping','missing','error'}) do
  local ns,s,env=arrivalFixture();ns.Hints.Request(1)
  if case=='missing-ping' then env.SOUNDKIT.MAP_PING=nil
  elseif case=='missing' then env.SOUNDKIT=nil
  else s.soundError=true end
  arrive(ns,s);assert(ns.Feedback.arriving)
  equal(s.sounds,case=='error' and 2 or 1)
  ns.Feedback.Update(0.3);assert(ns.Feedback.frame.rim[1].alpha>0)
 end
end)

test('clear replacement zoning restoration and completion never announce arrival',function()
 for _,case in ipairs({'clear','replacement','zone','restore','complete','missing','heading'}) do
  local ns,s=arrivalFixture();ns.Hints.Request(1)
  if case=='clear' then ns.Hints.Clear('cleared')
  elseif case=='replacement' then ns.Hints.Request(2)
  elseif case=='zone' then s.mapID=999;ns.Hints.Update()
  elseif case=='restore' then ns.Guard.active=false;ns.Hints.Update()
  elseif case=='complete' then s.stage='turn-in';ns.Hints.Update()
  elseif case=='missing' then s.dataError='unavailable';ns.Hints.Update()
  else s.noFacing=true;ns.Hints.Update() end
  equal(ns.Feedback.arriving,nil)
  for _,sound in ipairs(s.soundLog) do equal(sound.id,856) end
 end
end)

test('arrival with a hidden minimap has no delayed sound or flash',function()
 local ns,s,env=arrivalFixture();ns.Hints.Request(1);env.Minimap:Hide();arrive(ns,s)
 equal(s.sounds,1);equal(ns.Feedback.arriving,nil)
 env.Minimap:Show();ns.Feedback.Update(0.3);ns.Hints.Update()
 equal(s.sounds,1);equal(ns.Feedback.frame:IsShown(),false)
end)

test('new requests restore gold and cleanup interrupts an arrival pulse',function()
 for _,case in ipairs({'request','clear','zone','restore'}) do
  local ns,s=arrivalFixture();ns.Hints.Request(1);arrive(ns,s);ns.Feedback.Update(0.3)
  if case=='request' then
   s.distance=500;ns.Hints.Request(2)
   equal(ns.Hints.active.id,2);equal(ns.Feedback.arriving,nil)
   equal(s.sounds,3);near(ns.Feedback.frame.rim[1].color[1],1)
   near(ns.Feedback.frame.rim[1].color[2],0.82);near(ns.Feedback.frame.rim[1].color[3],0.35)
  else
   if case=='restore' then ns.Guard.active=false end
   ns.Hints.Clear(case);ns.Feedback.Update(0.3)
   equal(ns.Feedback.arriving,nil);equal(ns.Feedback.frame:IsShown(),false);equal(s.sounds,2)
  end
 end
end)

test('native default observes controls without opening quests or altering native functions and layout',function()
 local ns,s,env=fixture({presentation={standalone=false}})
 local detailFn,mapFn,eventFn=env.QuestMapFrame_ShowQuestDetails,env.WorldMapFrame.SetMapID,env.EventRegistry.TriggerEvent
 assert(ns.NativePane.Install());equal(ns.NativePane.Open,nil);equal(ns.NativePane.button,nil)
 equal(env.QuestMapFrame_ShowQuestDetails,detailFn);equal(env.WorldMapFrame.SetMapID,mapFn)
 equal(env.EventRegistry.TriggerEvent,eventFn);equal(s.requests,0)
 local _,_,_,_,y=env.QuestMapFrame.DetailsFrame.RewardsFrameContainer:GetPoint(1);equal(y,23)
 ns.SettingsPanel.Open();equal(ns.SettingsPanel.frame.checks.standalone,nil)
end)
test('restriction observers preserve bounded evidence without changing UI or guidance',function()
 local ns,s,env=fixture(nil,false);env.SlashCmdList={};load(ns,env,'Commands')
 local onEvent=s.lastFrame.scripts.OnEvent;local active=ns.Hints.active
 onEvent(nil,'ADDON_ACTION_BLOCKED','JustAHint','ProtectedFunction()')
 equal(ns.DB.securityEvents[1].event,'ADDON_ACTION_BLOCKED')
 equal(ns.DB.securityEvents[1].arguments[2],'ProtectedFunction()')
 equal(ns.Hints.active,active);equal(s.requests,0);equal(s.sounds,0);equal(#s.messages,0)
 for i=1,8 do onEvent(nil,'LUA_WARNING',string.rep('x',1000)) end
 equal(#ns.DB.securityEvents,5);equal(#ns.DB.securityEvents[5].arguments[1],512)
end)
test('unsupported restriction events do not break addon startup',function()
 local ns,s,env=fixture(nil,false);env.SlashCmdList={};s.refuseEvents=true
 -- Normal startup events are already supported by the client; restrict only
 -- diagnostic registration in this fixture.
 local create=env.CreateFrame
 env.CreateFrame=function(...)
  local frame=create(...)
  frame.RegisterEvent=function(_,event)
   if event=='ADDON_ACTION_BLOCKED' or event=='ADDON_ACTION_FORBIDDEN' or event=='LUA_WARNING' then error('unknown event') end
  end
  return frame
 end
 load(ns,env,'Commands');assert(ns.securityEventRegistrationFailed);equal(ns.NativePane.installed,nil)
end)
local function readDetails(ns,s,env,id)
 s.selected,s.focused=id,id;env.QuestMapFrame.DetailsFrame.questID=id
end
test('explicit working button leaves native functions and layout untouched',function()
 local ns,s,env=fixture();readDetails(ns,s,env,42)
 local details=env.QuestMapFrame.DetailsFrame
 local detailsFn,mapFn,eventFn=env.QuestMapFrame_ShowQuestDetails,env.WorldMapFrame.SetMapID,env.EventRegistry.TriggerEvent
 for _,frame in ipairs({env.WorldMapFrame,details,details.RewardsFrameContainer,details.TrackButton,details.AbandonButton,details.ShareButton}) do
  frame.SetPoint=function() error('native anchors changed') end
  frame.SetSize=function() error('native size changed') end
 end
 assert(ns.NativePane.ShowButton());equal(ns.NativePane.button.parent,env.UIParent)
 equal(ns.NativePane.button.points[1][2],details.TrackButton);equal(ns.NativePane.button.points[1][5],-6)
 equal(s.requests,0);equal(ns.NativePane.button:IsEnabled(),true)
 ns.NativePane.RefreshButton();equal(s.requests,0)
 ns.NativePane.button.scripts.OnClick();equal(s.requests,1);equal(s.requestID,42)
 equal(env.QuestMapFrame_ShowQuestDetails,detailsFn);equal(env.WorldMapFrame.SetMapID,mapFn)
 equal(env.EventRegistry.TriggerEvent,eventFn);equal(s.mapID,2521);equal(#s.events,0)
end)
test('native button loading and omitted destinations never acquire guidance when ready',function()
 local ns,s,env=fixture();readDetails(ns,s,env,42);s.availability='loading'
 assert(ns.NativePane.ShowButton());equal(ns.NativePane.button:IsShown(),true);equal(ns.NativePane.button:IsEnabled(),false)
 ns.NativePane.button.scripts.OnClick();equal(s.requests,0)
 s.availability='hidden';ns.NativePane.RefreshButton();equal(ns.NativePane.button:IsShown(),false)
 equal(ns.NativePane.ticker:IsShown(),true)
 s.availability='ready';ns.NativePane.ticker.scripts.OnUpdate(nil,0.6)
 equal(ns.NativePane.button:IsShown(),true);equal(ns.NativePane.button:IsEnabled(),true);equal(s.requests,0)
end)
test('stale native quest identity cannot request either the old or new quest',function()
 for _,case in ipairs({'selected','focused','details'}) do
  local ns,s,env=fixture();readDetails(ns,s,env,42);assert(ns.NativePane.ShowButton())
  if case=='selected' then s.selected=43 elseif case=='focused' then s.focused=43
  else env.QuestMapFrame.DetailsFrame.questID=43 end
  ns.NativePane.button.scripts.OnClick();equal(s.requests,0);equal(ns.NativePane.active,nil)
  equal(ns.NativePane.button:IsShown(),false)
 end
end)
test('explicit clicks reach Request even when data disappears after paint',function()
 local ns,s,env=fixture();readDetails(ns,s,env,42);assert(ns.NativePane.ShowButton())
 s.availability='hidden';ns.NativePane.button.scripts.OnClick();equal(s.requests,1);equal(s.requestID,42)
end)
test('button cleanup and unavailable controls cannot resume an old request later',function()
 for _,case in ipairs({'map','close','combat','guard','restore'}) do
  local ns,s,env=fixture();readDetails(ns,s,env,42);assert(ns.NativePane.ShowButton())
  if case=='map' then s.mapID=9 elseif case=='close' then env.WorldMapFrame:Hide()
  elseif case=='combat' then s.combat=true elseif case=='guard' then ns.Guard.active=false
  else ns.NativePane.Restore() end
  ns.NativePane.RefreshButton();equal(ns.NativePane.active,nil);equal(ns.NativePane.button:IsShown(),false)
  s.mapID=2521;s.combat=false;ns.Guard.active=true;env.WorldMapFrame:Show();ns.NativePane.RefreshButton()
  equal(ns.NativePane.button:IsShown(),false);equal(s.requests,0)
 end
 local ns,s,env=fixture();readDetails(ns,s,env,42);env.QuestMapFrame.DetailsFrame.TrackButton.protected=true
 equal(ns.NativePane.ShowButton(),false);equal(ns.NativePane.button,nil)
end)
test('restricted getters and partial construction fail without opening native details',function()
 local ns,s,env=fixture();readDetails(ns,s,env,42)
 env.QuestMapFrame_GetFocusedQuestID=function() error('restricted') end
 equal(ns.NativePane.ShowButton(),false);equal(ns.NativePane.button,nil)
 env.QuestMapFrame_GetFocusedQuestID=function() return 42 end
 local create=env.CreateFrame
 env.CreateFrame=function(...)
  local frame=create(...);frame.SetEnabled=function() error('control setup failed') end;return frame
 end
 equal(ns.NativePane.ShowButton(),false);equal(ns.NativePane.active,nil);equal(ns.NativePane.button:IsShown(),false)
 env.CreateFrame=create;equal(ns.NativePane.ShowButton(),false);equal(s.mapID,2521);equal(s.requests,0)
end)
test('native button dispatch runs the actual Hint service only on click',function()
 local ns,s,env=fixture();readDetails(ns,s,env,42)
 env.C_Texture={GetAtlasInfo=function() return {width=32,height=48} end}
 load(ns,env,'MinimapBearing')
 ns.Area={Clear=function() end}
 load(ns,env,'HintController')
 ns.HintData={Facing=function() return 0 end,
  Snapshot=function(id)
   return {stage='stage-one',mapID=2521,target={x=0,y=0,space=0},player={x=-500,y=0,space=0},
    distance=500,destination={source='fixture-native-point'}}
  end}
 load(ns,env,'Hints');local hintTicker=s.lastFrame;equal(ns.Hints.active,nil)
 assert(ns.NativePane.ShowButton());ns.NativePane.RefreshButton();equal(ns.Hints.active,nil)
 ns.NativePane.button.scripts.OnClick();equal(ns.Hints.active.id,42);equal(ns.Hints.controller.mode,'bearing')
 equal(env.WorldMapFrame:IsShown(),false);equal(s.closes,1);equal(s.mapID,2521)
 equal(ns.NativePane.active,nil);equal(ns.NativePane.button:IsShown(),false)
 ns.NativePane.RefreshButton();equal(s.closes,1);equal(ns.Hints.active.id,42)
 equal(ns.Feedback.flying,true);equal(ns.Bearing.frame.arrow.alpha,0)
 hintTicker.scripts.OnUpdate(nil,0.01);equal(ns.Bearing.frame.arrow.alpha,0)
 for _,dt in ipairs({0.4,0.4,0.4,0.2}) do ns.Feedback.Update(dt) end
 equal(ns.Feedback.flying,nil);equal(ns.Bearing.frame.arrow.alpha,1)
 hintTicker.scripts.OnUpdate(nil,0.01);equal(ns.Bearing.frame.arrow.alpha,1)
 ns.Hints.Clear('cleared');equal(ns.Feedback.elapsed,nil);equal(ns.Feedback.frame:IsShown(),false)
 equal(ns.Bearing.frame:IsShown(),false)
end)
test('delayed native hint completion closes only the original quest context and never retries failures',function()
 for _,case in ipairs({'same','quest-changed','map-changed','combat','restricted'}) do
  local ns,s,env=fixture();readDetails(ns,s,env,42)
  local complete
  ns.Hints.Toggle=function(id,callback)
   ns.Hints.active={id=id,pending=true};ns.Hints.controller.mode='none'
   complete=function()
    ns.Hints.active={id=id};ns.Hints.controller.mode='bearing';callback()
   end
   return 'requested'
  end
  assert(ns.NativePane.ShowButton());ns.NativePane.button.scripts.OnClick()
  equal(s.closes,nil);equal(env.WorldMapFrame:IsShown(),true)
  if case=='quest-changed' then readDetails(ns,s,env,43)
  elseif case=='map-changed' then s.mapID=999
  elseif case=='combat' then s.combat=true
  elseif case=='restricted' then env.HideUIPanel=function() s.closes=(s.closes or 0)+1;error('restricted') end end
  complete();complete()
  equal(s.closes,(case=='same' or case=='restricted') and 1 or nil)
  equal(env.WorldMapFrame:IsShown(),case~='same')
 end
end)
test('native map closes only for a successfully rendered matching bearing',function()
 for _,case in ipairs({'area','failed','hidden','wrong-quest','changed-map','combat'}) do
  local ns,s,env=fixture();readDetails(ns,s,env,42);assert(ns.NativePane.ShowButton())
  ns.Hints.Request=function(id)
   ns.Hints.active={id=id};ns.Hints.controller.mode='bearing';ns.Hints.controller.visible=true
   if case=='area' then ns.Hints.controller.mode='area'
   elseif case=='failed' then ns.Hints.active=nil
   elseif case=='hidden' then ns.Bearing.frame:Hide()
   elseif case=='wrong-quest' then ns.Hints.active.id=43
   elseif case=='changed-map' then s.mapID=999
   elseif case=='combat' then s.combat=true end
  end
  ns.NativePane.button.scripts.OnClick();equal(s.closes,nil);equal(env.WorldMapFrame:IsShown(),true)
 end
end)
test('native map-close errors preserve requested guidance without retry',function()
 local ns,s,env=fixture();readDetails(ns,s,env,42);assert(ns.NativePane.ShowButton())
 ns.Hints.Request=function(id) ns.Hints.active={id=id} end
 local calls=0
 env.HideUIPanel=function() calls=calls+1;error('restricted map close') end
 ns.NativePane.button.scripts.OnClick();equal(calls,1);equal(ns.Hints.active.id,42)
 equal(env.WorldMapFrame:IsShown(),true);equal(ns.DB.lastCheck.nativeMapClose,'failed')
 assert(ns.DB.lastCheck.nativeMapCloseError)
 ns.NativePane.RefreshButton();equal(calls,1)
end)
test('native tracker keeps original handlers and observer attaches only an inert Hint control',function()
 local ns,s,env=fixture();local calls=0
 env.QuestMapFrame_OpenToQuestDetails=function() error('addon must never open native quests') end
 env.QuestObjectiveTracker={OnBlockHeaderClick=function() calls=calls+1;readDetails(ns,s,env,42) end}
 local original=env.QuestObjectiveTracker.OnBlockHeaderClick
 assert(ns.NativePane.Install())
 equal(env.QuestObjectiveTracker.OnBlockHeaderClick,original)
 ns.NativePane.Observe();equal(ns.NativePane.button,nil)
 env.QuestObjectiveTracker:OnBlockHeaderClick({id=42},'LeftButton');equal(calls,1)
 ns.NativePane.observer.scripts.OnUpdate(nil,0.2)
 equal(ns.NativePane.active.questID,42);equal(s.requests,0)
 ns.NativePane.Observe();equal(s.requests,0)
 readDetails(ns,s,env,43);ns.NativePane.Observe();equal(ns.NativePane.active.questID,43);equal(s.requests,0)
 env.WorldMapFrame:Hide();ns.NativePane.Observe();equal(ns.NativePane.active,nil)
end)


test('observer restoration and construction failures cannot loop or request guidance',function()
 local ns,s,env=fixture();assert(ns.NativePane.Install());readDetails(ns,s,env,42)
 env.CreateFrame=function() error('restricted creation') end
 ns.NativePane.Observe();equal(s.requests,0);equal(ns.NativePane.active,nil)
 local note=ns.DB.lastCheck.nativeButtonError;ns.NativePane.Observe();equal(ns.DB.lastCheck.nativeButtonError,note)
 ns.NativePane.Restore();equal(ns.NativePane.observer:IsShown(),false)
 equal(ns.NativePane.Open,nil)
end)
test('native Clear toggle removes guidance while preserving map, quest selection and quiet feedback',function()
 local ns,s,env=fixture();readDetails(ns,s,env,42);assert(ns.NativePane.ShowButton())
 ns.Hints.Toggle=function(id) equal(id,42);ns.Hints.active=nil;return 'cleared' end
 ns.NativePane.button.scripts.OnClick()
 equal(ns.Hints.active,nil);equal(env.WorldMapFrame:IsShown(),true);equal(s.closes,nil)
 equal(s.selected,42);equal(s.requests,0);equal(s.sounds,0);equal(#s.messages,0)
end)
test('nearby chat respects the text setting and adds no map caption, pulse or sound',function()
 local ns,s,env=fixture()
 ns.Hints.active={id=42};ns.Hints.controller.mode='area'
 ns.Area={active={id=42,drawn=true},frame=env.WorldMapFrame,IsVisible=function(id) return id==42 and env.WorldMapFrame:IsVisible() end}
 ns.Feedback.AreaRequested();equal(#s.messages,1)
 assert(s.messages[1]:find("You're close. Search around here.",1,true))
 equal(s.sounds,0);equal(ns.Feedback.frame,nil);equal(s.closes,nil)
 ns.Feedback.AreaRequested();equal(#s.messages,1)
 s.time=11;ns.SettingsPanel.Set('text',false);ns.Feedback.AreaRequested();equal(#s.messages,1)
 ns.SettingsPanel.Set('text',true);ns.Area.active.id=43;ns.Feedback.AreaRequested();equal(#s.messages,1)
 ns.Area.active.id=42;ns.Guard.active=false;ns.Feedback.AreaRequested();equal(#s.messages,1)
end)
test('nearby pin uses distinct chat wording without claiming an exact target or playing feedback',function()
 local ns,s,env=fixture();ns.Hints.active={id=42};ns.Hints.controller.mode='area'
 ns.Area={active={id=42,drawn=true,presentation='point'},IsVisible=function(id) return id==42 end}
 ns.Feedback.AreaRequested();assert(s.messages[1]:find("Look around the marked spot.",1,true))
 equal(s.sounds,0);equal(ns.Feedback.frame,nil)
end)

test('retired native button and read commands expose help without hidden UI actions',function()
 local ns,s,env=fixture();env.SlashCmdList={};load(ns,env,'Commands')
 for _,command in ipairs({'native','button','read 42'}) do env.SlashCmdList.JUSTAHINT(command) end
 equal(s.requests,0);equal(ns.NativePane.button,nil);equal(ns.NativePane.active,nil)
 equal(#s.messages,3);assert(s.messages[1]:find('/jah settings',1,true))
 assert(not s.messages[1]:find('/jah button',1,true));assert(not s.messages[1]:find('/jah native',1,true))
end)

test('reload drops stale runtime notes while preserving settings recovery and restriction evidence',function()
 local ns,s=fixture({lastCheck={nativeReading='old probe'},enabled=false,
  presentation={text=false},recovery={questPOI='1',minimap={}},securityEvents={{event='ADDON_ACTION_BLOCKED'}}})
 equal(next(ns.DB.lastCheck),nil);equal(ns.DB.presentation.text,false)
 equal(ns.DB.recovery.questPOI,'1');equal(#ns.DB.securityEvents,1)
end)


test('settings is the only addon panel and retains toggle feedback options and saved preference migration',function()
 local ns,s,env=fixture({presentation={standalone=true,text=false}})
 local action='start';local toggles=0
 ns.Guard.Action=function() return action end
 ns.Guard.Toggle=function() toggles=toggles+1;action='restore';return true end
 ns.SettingsPanel.Open();local root=ns.SettingsPanel.frame
 equal(root.parent,env.UIParent);equal(root.modeToggle.text,'Start Just a Hint')
 equal(root.checks.standalone,nil);equal(ns.DB.presentation.standalone,nil);equal(ns.Reader,nil)
 root.modeToggle.scripts.OnClick();equal(root.modeToggle.text,'Restore Blizzard guidance')
 action='retry';root.scripts.OnUpdate(root,0.6);equal(root.modeToggle.text,'Retry restoration')
 s.combat=true;root.scripts.OnUpdate(root,0.6);equal(root.modeToggle:IsEnabled(),false)
 s.combat=false;root.scripts.OnUpdate(root,0.6);equal(root.modeToggle:IsEnabled(),true)
 root:Hide();ns.SettingsPanel.Open();equal(ns.SettingsPanel.frame,root);equal(toggles,1)
 equal(root.checks.text:GetChecked(),false);equal(s.requests,0)
end)
test('unavailable native controls never install a fallback reader or mutate click handlers',function()
 local ns,s,env=fixture();env.QuestMapFrame=nil
 local original=function() error('must not be called') end
 env.QuestObjectiveTracker={OnBlockHeaderClick=original}
 equal(ns.NativePane.Check(),false);equal(ns.NativePane.Install(),false)
 equal(ns.Reader,nil);equal(env.QuestObjectiveTracker.OnBlockHeaderClick,original)
 equal(s.requests,0)
end)
local function markerFixture()
 local ns,s,env=fixture();env.C_Texture={GetAtlasInfo=function() return {width=32,height=48} end}
 local function row(id,rect,parent)
  local f=env.CreateFrame('Frame',nil,parent);f.questID=id;f.id=id;f.rect=rect;return f
 end
 local scroll=row(nil,{280,200,300,300},env.WorldMapFrame)
 local title=row(42,{300,350,270,16},scroll)
 local block=row(42,{750,350,270,100})
 local children={title}
 scroll.titleFramePool={EnumerateActive=function()
  local i=0;return function() i=i+1;return children[i] end
 end}
 env.QuestScrollFrame=scroll
 env.QuestObjectiveTracker={GetExistingBlock=function(_,id) if block.id==id then return block end end,
  OnBlockHeaderClick=function() error('marker must not click') end}
 local owner=42
 ns.Hints.active={id=42};ns.Hints.HasVisibleHint=function(id) return owner==id end
 load(ns,env,'NativeHintMarkers')
 return ns,s,env,title,block,scroll,function(id) owner=id;ns.Hints.active=id and {id=id} or nil end
end
test('native markers observe matching tracker and quest-log rows without selection or layout changes',function()
 local ns,s,env,title,block,scroll,owner=markerFixture()
 local original=env.QuestObjectiveTracker.OnBlockHeaderClick
 ns.NativeMarkers.Update();equal(ns.NativeMarkers.count,2);equal(s.requests,0)
 equal(ns.NativeMarkers.frames[1].parent,env.UIParent);equal(ns.NativeMarkers.frames[2].parent,env.UIParent)
 equal(#title.points,0);equal(#block.points,0);equal(env.QuestObjectiveTracker.OnBlockHeaderClick,original)
 equal(s.selected,nil);equal(s.focused,nil)
 title.questID=43;ns.NativeMarkers.Update();equal(ns.NativeMarkers.count,1)
 block.id=43;ns.NativeMarkers.Update();equal(ns.NativeMarkers.count,0)
 owner(43);ns.NativeMarkers.Update();equal(ns.NativeMarkers.count,2)
 owner(nil);ns.NativeMarkers.Update();equal(ns.NativeMarkers.count,0)
end)
test('native markers hide for recycled clipped hidden suspended or unavailable rows',function()
 local ns,s,env,title,block,scroll=markerFixture();ns.NativeMarkers.Update()
 title.rect={300,550,270,16};ns.NativeMarkers.Update();equal(ns.NativeMarkers.count,1)
 block:Hide();ns.NativeMarkers.Update();equal(ns.NativeMarkers.count,0)
 block:Show();title.rect={300,350,270,16};scroll:Hide();ns.NativeMarkers.Update();equal(ns.NativeMarkers.count,1)
 ns.Guard.active=false;ns.NativeMarkers.Update();equal(ns.NativeMarkers.count,0)
 ns.Guard.active=true;ns.Hints.HasVisibleHint=function() return false end
 ns.NativeMarkers.Update();equal(ns.NativeMarkers.count,0);equal(s.requests,0)
end)
test('native marker artwork and restricted geometry failures preserve requested assistance',function()
 local ns,s,env,title,block=markerFixture();local active=ns.Hints.active
 env.C_Texture=nil;ns.NativeMarkers.Update();equal(ns.NativeMarkers.count,0);equal(ns.Hints.active,active)
 env.C_Texture={GetAtlasInfo=function() return {width=32,height=48} end}
 block.GetRect=function() error('restricted') end
 ns.NativeMarkers.Update();equal(ns.NativeMarkers.count,0);equal(ns.Hints.active,active);equal(s.requests,0)
end)
print(total..' presentation fixture tests passed; native layout, sound and secure actions remain unverified.')
