-- Native-region request boundaries using fixtures; no claim about client geometry.
local total=0
local function equal(a,b) assert(a==b,"expected "..tostring(b)..", got "..tostring(a)) end
local function test(name,fn)
    local ok,err=pcall(fn);assert(ok,name..": "..tostring(err));total=total+1;print("ok - "..name)
end
local function fixture()
    local env=setmetatable({}, {__index=_G});env._G=env
    local s={queries=0,open=false,mapID=2521,width=700,height=500,scale=1,opens=0,draws={},visible={},notes={}}
    local ns={Note=function(k,v) s.notes[k]=v end}
    local function ui()
        local f={scripts={},shown=false}
        for _,method in ipairs({"SetSize","SetPoint","SetAtlas","ClearAllPoints","SetAllPoints","SetFrameLevel",
            "EnableMouse","SetBackdrop","SetBackdropColor","SetText","SetJustifyH","SetParent","SetClampedToScreen"}) do
            f[method]=function() end
        end
        function f:SetPoint(...) self.point={...} end
        function f:SetSize(w,h) self.width,self.height=w,h end
        function f:GetFrameLevel() return 2007 end
        function f:IsVisible() return self.shown and s.open end
        f.CreateTexture=ui
        function f:SetScript(name,fn) self.scripts[name]=fn end
        function f:Show() self.shown=true end
        function f:Hide()
            local shown=self.shown;self.shown=false
            if shown and self.scripts.OnHide then self.scripts.OnHide(self) end
        end
        f.CreateFontString=ui
        return f
    end
    local canvas={GetWidth=function() return s.width end,GetHeight=function() return s.height end,
        GetEffectiveScale=function() return s.scale end}
    env.WorldMapFrame={IsShown=function() return s.open end,GetMapID=function() return s.mapID end,
        GetCanvas=function() return s.canvas or canvas end,GetFrameLevel=function() return 1 end,
        pinFrameLevelsManager={GetValidFrameLevel=function() return 2007 end}}
    env.C_Texture={GetAtlasInfo=function() if not s.noAtlas then return {width=32,height=32} end end}
    env.OpenWorldMap=function(id)
        s.opens=s.opens+1
        if s.openError then error("map unavailable") end
        s.open=true;s.mapID=id
    end
    env.InCombatLockdown=function() return s.combat end
    env.CreateFrame=function(kind,_,parent,template)
        local f=ui()
        if kind=="QuestPOIFrame" then
            equal(template,nil) -- No template that activates native navigation.
            for _,name in ipairs({"SetMapID","SetFillTexture","SetBorderTexture","SetFillAlpha",
                "SetBorderAlpha","SetBorderScalar"}) do f[name]=function() end end
            function f:DrawNone() s.visible={} end
            function f:DrawBlob(id,draw)
                if s.drawError then error("draw failed") end
                equal(draw,true);s.draws[#s.draws+1]=id
                -- A successful call may legitimately have no region.
                if not s.noRegion then s.visible[id]=true end
            end
            function f:UpdateMouseOverTooltip(x,y)
                s.queries=s.queries+1
                if s.queryError then error('query unavailable') end
                if not s.noRegion and x==0.5 and y==0.5 then return s.draws[#s.draws],1 end
            end
            s.blob=f
        elseif kind=="Button" then s.clear=f end
        return f
    end
    for _,name in ipairs({"Core","QuestArea"}) do
        local chunk=assert(loadfile("addon/JustAHint/"..name..".lua"));setfenv(chunk,env);chunk("JustAHint",ns)
    end
    ns.Note=function(k,v) s.notes[k]=v end
    ns.Hints={Clear=function(reason) s.cleared=reason;ns.Area.Clear() end}
    return ns,s,env
end

test("only an explicit area request opens the map and draws only its quest",function()
    local ns,s=fixture();equal(ns.Area.Update(),false);equal(s.opens,0);equal(#s.draws,0)
    assert(ns.Area.Show(12,2521,{mapID=2521,x=0.5,y=0.5}));equal(s.opens,1);equal(#s.draws,0)
    assert(ns.Area.Update());equal(#s.draws,1);equal(s.draws[1],12);equal(s.visible[12],true)
    assert(ns.Area.Show(34,2521,{mapID=2521,x=0.5,y=0.5}));equal(next(s.visible),nil);assert(ns.Area.Update())
    equal(s.visible[12],nil);equal(s.visible[34],true)
end)
test("count updates do not redraw; canvas changes redraw only the authorized quest",function()
    local ns,s=fixture();assert(ns.Area.Show(12,2521,{mapID=2521,x=0.5,y=0.5}));ns.Area.Update()
    ns.Area.Update();equal(#s.draws,1)
    s.width=900;s.scale=1.3;assert(ns.Area.Update());equal(#s.draws,2);equal(s.draws[2],12)
end)
test("map closure and clear remove regions without opening or restoring the map",function()
    local ns,s=fixture();ns.Area.Show(12,2521,{mapID=2521,x=0.5,y=0.5});ns.Area.Update()
    s.open=false;s.blob.scripts.OnHide(s.blob)
    equal(ns.Area.active,nil);equal(next(s.visible),nil);equal(s.opens,1)
    s.open=true;equal(ns.Area.Update(),false);equal(#s.draws,1)
    ns.Area.Show(12,2521,{mapID=2521,x=0.5,y=0.5});ns.Area.Update();equal(s.clear,nil);ns.Hints.Clear("cleared")
    equal(next(s.visible),nil);equal(s.open,true);equal(ns.Area.active,nil)
end)
test("changing maps clears before drawing on the new map",function()
    local ns,s=fixture();ns.Area.Show(12,2521,{mapID=2521,x=0.5,y=0.5});ns.Area.Update();s.mapID=999
    s.blob.scripts.OnUpdate();equal(ns.Area.active,nil);equal(next(s.visible),nil);equal(#s.draws,1)
end)
test("suspension removes geometry and cannot revive it after clear",function()
    local ns,s=fixture();ns.Area.Show(12,2521,{mapID=2521,x=0.5,y=0.5});ns.Area.Update();assert(ns.Area.Suspend())
    equal(next(s.visible),nil);assert(ns.Area.active);equal(ns.Area.caption,nil)
    ns.Area.Update();equal(s.visible[12],true);equal(ns.Area.caption,nil)
    ns.Area.Clear();equal(ns.Area.Update(),false);equal(next(s.visible),nil)
end)
test("a call with no native region never creates substitute geometry or claims visibility",function()
    local ns,s=fixture();s.noRegion=true;assert(ns.Area.Show(12,2521,{mapID=2521,x=0.5,y=0.5}));assert(ns.Area.Update())
    equal(next(s.visible),nil);assert(s.notes.area:find("checking region"));equal(#s.draws,1)
end)
test("combat and missing map APIs do not leave a pending disclosure",function()
    local ns,s,env=fixture();s.combat=true;equal(ns.Area.Show(12,2521,{mapID=2521,x=0.5,y=0.5}),false);equal(s.opens,0)
    s.combat=false;equal(ns.Area.Update(),false);equal(s.opens,0);equal(#s.draws,0)
    env.OpenWorldMap=nil;equal(ns.Area.Show(12,2521,{mapID=2521,x=0.5,y=0.5}),false);equal(ns.Area.active,nil)
end)
test("render failure is reported and clearing removes partial presentation",function()
    local ns,s=fixture();ns.Area.Show(12,2521,{mapID=2521,x=0.5,y=0.5});s.drawError=true
    local ok,why=ns.Area.Update();equal(ok,false);equal(why,"area-renderer-unavailable")
    ns.Area.Clear();equal(s.blob.shown,false);equal(ns.Area.caption,nil);equal(next(s.visible),nil)
end)
test("nearby feedback happens only on the first draw of an explicit request",function()
 local ns,s=fixture();local messages=0
 ns.Feedback={AreaRequested=function() messages=messages+1 end}
 assert(ns.Area.Show(12,2521,{mapID=2521,x=0.5,y=0.5}));equal(messages,0);equal(ns.Area.caption,nil)
 ns.Area.Update();ns.Area.Probe(0.2);equal(messages,1)
 s.width=900;ns.Area.Update();ns.Area.Suspend();ns.Area.Update();equal(messages,1)
 ns.Area.Clear();ns.Area.Update();equal(messages,1)
 assert(ns.Area.Show(12,2521,{mapID=2521,x=0.5,y=0.5}));ns.Area.Clear();ns.Area.Update();equal(messages,1)
 assert(ns.Area.Show(12,2521,{mapID=2521,x=0.5,y=0.5}));s.drawError=true;equal(ns.Area.Update(),false);equal(messages,1)
end)
test("unconfirmed region falls back to native artwork at the requested point and clears with the map",function()
 local ns,s=fixture();s.noRegion=true
 assert(ns.Area.Show(12,2521,{mapID=2521,x=0.7,y=0.3}));ns.Area.Update()
 equal(ns.Area.IsVisible(12),false);equal(ns.Area.active.presentation,'checking')
 ns.Area.Probe(0.2);assert(s.queries<=64);equal(ns.Area.active.presentation,'checking')
 for i=1,18 do ns.Area.Probe(0.02) end
 equal(ns.Area.active.presentation,'point');equal(ns.Area.IsVisible(12),true)
 equal(next(s.visible),nil);assert(ns.Area.marker.ready);assert(s.notes.area:find('unconfirmed'))
 assert(math.abs(ns.Area.marker.point[4]-490)<0.00001);equal(ns.Area.marker.point[5],-150)
 equal(ns.Area.marker.width,12)
 s.width=900;s.scale=1.5;ns.Area.Update();equal(ns.Area.IsVisible(12),true)
 assert(math.abs(ns.Area.marker.point[4]-630)<0.00001);equal(ns.Area.marker.width,8)
 ns.Area.Clear();equal(ns.Area.marker.shown,false);equal(ns.Area.IsVisible(12),false)
 ns.Area.Probe(1);equal(ns.Area.marker.shown,false)
end)
test("matching region keeps shading without a destination pin",function()
 local ns,s=fixture();ns.Area.Show(12,2521,{mapID=2521,x=0.5,y=0.5});ns.Area.Update();ns.Area.Probe(0.2)
 equal(ns.Area.active.presentation,'region');equal(ns.Area.IsVisible(12),true);equal(ns.Area.marker,nil)
 s.width=900;ns.Area.Update();equal(ns.Area.active.presentation,'region');equal(ns.Area.marker,nil)
end)
test("unsupported query falls back while missing artwork or invalid coordinates fail without phantom guidance",function()
 for _,case in ipairs({'no-query','no-artwork','invalid-point','map-change'}) do
  local ns,s=fixture();s.noRegion=true
  local point={mapID=2521,x=0.5,y=0.5}
  if case=='invalid-point' then point.x=2 end
  ns.Area.Show(12,2521,point);ns.Area.Update();s.blob.UpdateMouseOverTooltip=nil
  if case=='no-artwork' then s.noAtlas=true elseif case=='map-change' then s.mapID=999 end
  ns.Area.Probe(0.2)
  if case=='no-query' then equal(ns.Area.active.presentation,'point');equal(ns.Area.IsVisible(12),true)
  else equal(ns.Area.active,nil);equal(ns.Area.IsVisible(12),false) end
 end
end)
print(total.." area fixture tests passed; native rendering still requires a playtest.")
