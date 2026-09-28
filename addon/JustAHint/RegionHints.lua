local _, NS = ...
-- Samples native quest geometry only after an explicit request. No polygons,
-- inferred circles, native selection, or visible preparation are manufactured.
local Regions = { GRID = 64, PER_FRAME = 64, SETTLE = 0.15 }
NS.RegionHints = Regions
local function finite(v) return type(v)=="number" and v==v and v>-math.huge and v<math.huge end

function Regions.Clear()
    Regions.job, Regions.region = nil, nil
    if Regions.frame then
        pcall(function() Regions.frame:DrawNone(); Regions.frame:Hide() end)
    end
end
local function read(x,y,id)
    local hit,count=Regions.frame:UpdateMouseOverTooltip(x,y)
    if hit~=nil and hit~=0 and not NS.ID(hit) then error("invalid-region-quest") end
    if count~=nil and (not finite(count) or count<0 or count%1~=0) then error("invalid-region-objective-count") end
    return hit==id and (count==nil or count>0)
end
local function add(job,x,y)
    if x<0 or x>1 or y<0 or y>1 then return end
    if not read(x,y,job.id) then return end
    local key=tostring(x)..":"..tostring(y)
    if job.seen[key] then return end
    local point={ mapID=job.mapID,x=x,y=y,source="native-region-sample" }
    local world=NS.HintData.WorldPoint(point)
    if not world or not NS.HintData.Distance(job.player,world) then error("region-world-position-unavailable") end
    job.seen[key]=true
    job.points[#job.points+1]={ point=point,world=world }
end
function Regions.Nearest(region,player)
    local best,distance
    for _,entry in ipairs(region.points) do
        local d=NS.HintData.Distance(player,entry.world)
        if not d then return end
        if not distance or d<distance then best,distance=entry,d end
    end
    return best,distance
end
local function finish(reason)
    local job=Regions.job
    if not job then return end
    Regions.job=nil
    local region
    if reason==nil and #job.points>0 then
        region={id=job.id,mapID=job.mapID,stage=job.stage,points=job.points}
        Regions.region=region -- Keep only the invisible geometry used by this request.
    else Regions.Clear() end
    NS.Note("regionQuery",reason or (region and "native samples ready" or "no-hit-unknown; native point fallback"))
    NS.Note("regionSamples",#job.points)
    local ok,err=pcall(job.done,region)
    if not ok then
        Regions.Clear();NS.Note("regionRequestError",tostring(err))
        if NS.Hints then NS.Hints.Clear("region-request-error") end
    end
end
function Regions.Update(dt)
    local job=Regions.job
    if not job or not finite(dt) or dt<0 then return end
    local ok,err=pcall(function()
        job.wait=job.wait-dt
        if job.wait>0 then return end
        for _=1,Regions.PER_FRAME do
            if job.phase=="seed" then
                local point=job.index==0 and job.playerPoint or job.destination
                if point then add(job,point.x,point.y) end
                job.index=job.index+1
                if job.index==2 then job.phase,job.index="grid",0 end
            elseif job.phase=="grid" then
                local x=(job.index%(Regions.GRID+1))/Regions.GRID
                local y=math.floor(job.index/(Regions.GRID+1))/Regions.GRID
                add(job,x,y);job.index=job.index+1
                if job.index>=(Regions.GRID+1)^2 then
                    local near=Regions.Nearest(job,job.player)
                    if not near then finish();return end
                    -- Refine around the nearest coarse hit; retain every other
                    -- coarse hit for arrival at any site. These are still samples.
                    job.phase,job.index,job.center="refine",0,near.point
                end
            else
                local x=job.center.x+((job.index%17)-8)/512
                local y=job.center.y+(math.floor(job.index/17)-8)/512
                add(job,x,y);job.index=job.index+1
                if job.index>=289 then finish();return end
            end
        end
    end)
    if not ok then finish(tostring(err)) end
end
function Regions.Start(id,sample,done)
    Regions.Clear()
    local ok,err=pcall(function()
        if not Regions.frame then
            local frame=CreateFrame("QuestPOIFrame",nil,UIParent)
            Regions.frame=frame
            frame:Hide();frame:SetAlpha(0);frame:SetFillAlpha(0);frame:SetBorderAlpha(0)
            frame:EnableMouse(false);frame:SetSize(1002,668);frame:SetPoint("CENTER",UIParent,"CENTER")
            frame:SetFillTexture("Interface\\WorldMap\\UI-QuestBlob-Inside")
            frame:SetBorderTexture("Interface\\WorldMap\\UI-QuestBlob-Outside")
            frame:SetBorderScalar(2)
            frame:SetScript("OnUpdate",function(_,dt) Regions.Update(dt) end)
            frame.ready=true
        end
        local frame=Regions.frame
        if not frame.ready or type(frame.UpdateMouseOverTooltip)~="function" then error("region-query-unavailable") end
        frame:DrawNone();frame:SetMapID(sample.mapID)
        Regions.job={id=id,mapID=sample.mapID,stage=sample.stage,player=sample.player,
            done=done,points={},seen={},index=0,phase="seed",wait=Regions.SETTLE,
            playerPoint=sample.playerPoint,destination=sample.destination}
        frame:Show();frame:DrawBlob(id,true)
        NS.Note("regionQuery","sampling requested quest invisibly")
    end)
    if not ok then Regions.Clear();NS.Note("regionQuery",tostring(err));return false end
    return true
end
function Regions.Distance(region,sample)
    if Regions.region~=region or region.mapID~=sample.mapID or region.stage~=sample.stage then return end
    local ok,distance=pcall(function()
        local point=sample.playerPoint
        if not point then return end
        if read(point.x,point.y,region.id) then return 0 end
        local _,nearest=Regions.Nearest(region,sample.player)
        return nearest -- Conservative distance to confirmed samples, not an exact edge.
    end)
    if not ok then NS.Note("regionQueryError",tostring(distance));return end
    return distance
end
