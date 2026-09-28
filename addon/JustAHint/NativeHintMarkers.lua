local _, NS = ...
local Markers = { frames = {}, count = 0 }
NS.NativeMarkers = Markers

function Markers.Clear()
    Markers.count = 0
    for _, frame in ipairs(Markers.frames) do frame:Hide() end
end
local function finite(v) return type(v)=="number" and v==v and v>-math.huge and v<math.huge end
local function rect(frame)
    if not frame or not frame:IsVisible() then return end
    local x,y,w,h=frame:GetRect()
    local scale=frame:GetEffectiveScale()/UIParent:GetEffectiveScale()
    if not finite(x) or not finite(y) or not finite(w) or not finite(h) or not finite(scale)
        or w<=0 or h<=0 or scale<=0 then return end
    return x*scale,y*scale,w*scale,h*scale,scale
end
local function artwork()
    for _,name in ipairs({"Navigation-Tracked-Arrow","UI-WorldMapArrow"}) do
        local ok,info=NS.Call("C_Texture.GetAtlasInfo",name)
        if ok and type(info)=="table" and finite(info.width) and finite(info.height) and info.width>0 and info.height>0 then
            return name,info.width,info.height
        end
    end
    error("Native hint marker artwork unavailable")
end
local function show(anchor, list, viewport)
    local x,y,w,h,scale=rect(anchor)
    if not x then return end
    if viewport then
        local vx,vy,vw,vh=rect(viewport)
        if not vx or y<vy or y+h>vy+vh or x<vx or x>vx+vw then return end
    end
    local index=Markers.count+1
    local frame=Markers.frames[index]
    if not frame then
        local atlas,aw,ah=artwork()
        frame=CreateFrame("Frame",nil,UIParent)
        Markers.frames[index]=frame
        frame:Hide();frame:EnableMouse(false)
        frame:SetSize(16,20)
        local texture=frame:CreateTexture(nil,"OVERLAY")
        texture:SetAtlas(atlas);texture:SetSize(16*aw/math.max(aw,ah),16*ah/math.max(aw,ah))
        texture:SetPoint("CENTER",frame,"CENTER");texture:SetVertexColor(1,0.82,0.35)
        frame.ready=true
    end
    if not frame.ready then error("Native hint marker setup incomplete") end
    -- Read native geometry; anchor only to UIParent. No native layout, parents,
    -- handlers, pools, quest selection or protected frame relationships change.
    frame:SetFrameStrata(anchor:GetFrameStrata())
    frame:SetFrameLevel(anchor:GetFrameLevel()+5)
    frame:ClearAllPoints()
    frame:SetPoint("CENTER",UIParent,"BOTTOMLEFT",x+(list and 8 or -10)*scale,
        list and y+h/2 or y+h-8*scale)
    frame:Show();Markers.count=index
end
function Markers.Update()
    Markers.Clear()
    if not NS.Guard.active or NS.Guard.problem or not NS.Hints.active then return end
    local id=NS.Hints.active.id
    if not NS.Hints.HasVisibleHint(id) then return end
    local ok,err=pcall(function()
        for _,name in ipairs({"QuestObjectiveTracker","CampaignQuestObjectiveTracker"}) do
            local module=_G[name]
            if module and type(module.GetExistingBlock)=="function" then
                local block=module:GetExistingBlock(id)
                if block and block.id==id then show(block,false) end
            end
        end
        local scroll=QuestScrollFrame or (QuestMapFrame and QuestMapFrame.QuestsFrame and QuestMapFrame.QuestsFrame.ScrollFrame)
        local pool=scroll and scroll.titleFramePool
        if pool and type(pool.EnumerateActive)=="function" and scroll:IsVisible() then
            local visited=0
            for row in pool:EnumerateActive() do
                visited=visited+1;if visited>200 then break end
                if row.questID==id then show(row,true,scroll);break end
            end
        end
        NS.Note("nativeHintMarkers",Markers.count)
    end)
    if not ok then
        Markers.Clear();NS.Note("nativeHintMarkerError",err)
    end
end
local ticker,elapsed=CreateFrame("Frame"),0
ticker:SetScript("OnUpdate",function(_,dt)
    elapsed=elapsed+dt
    if elapsed>=0.1 then elapsed=0;Markers.Update() end
end)
