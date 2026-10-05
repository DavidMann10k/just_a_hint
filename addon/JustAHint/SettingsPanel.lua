local _, NS = ...
local Panel = {}
NS.SettingsPanel = Panel
local options = {
    { "arrowFlight", "Fly the requested arrow to the minimap" },
    { "arrowPulse", "Pulse around the requested arrow" },
    { "minimapPulse", "Pulse around the minimap" },
    { "sound", "Play a soft sound when requesting direction" },
    { "text", "Write requested hints in chat" },
}
function Panel.Value(key) return NS.DB.presentation[key] end
function Panel.Set(key, value)
    local known = false
    for _, entry in ipairs(options) do if entry[1] == key then known = true end end
    if not known or type(value) ~= "boolean" then return end
    NS.DB.presentation[key] = value
    if NS.Feedback then NS.Feedback.Update(0) end
end
function Panel.UpdateState()
    if not Panel.frame then return end
    local action = NS.Guard.Action()
    Panel.frame.modeToggle:SetText(action == "start" and "Start Just a Hint"
        or action == "retry" and "Retry restoration" or "Restore Blizzard guidance")
    Panel.frame.modeToggle:SetEnabled(not NS.InCombat())
    for key, check in pairs(Panel.frame.checks) do check:SetChecked(Panel.Value(key)) end
end
function Panel.Open()
    if not Panel.frame then
        local frame = CreateFrame("Frame", "JustAHintSettings", UIParent, "BackdropTemplate")
        Panel.frame = frame
        frame:Hide()
        frame:SetSize(470, 390)
        frame:SetScale(math.min(1, (UIParent:GetHeight() - 60) / 390, (UIParent:GetWidth() - 40) / 470))
        frame:SetPoint("CENTER")
        frame:SetFrameStrata("DIALOG")
        frame:EnableMouse(true)
        frame:SetClampedToScreen(true)
        frame:SetMovable(true)
        frame:RegisterForDrag("LeftButton")
        frame:SetScript("OnDragStart", frame.StartMoving)
        frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
        frame:SetBackdrop({bgFile="Interface\\Tooltips\\UI-Tooltip-Background",edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",
            tile=true,tileSize=16,edgeSize=16})
        frame:SetBackdropColor(0.055,0.06,0.07,0.98)
        local title = frame:CreateFontString(nil,"OVERLAY","GameFontNormalLarge")
        title:SetPoint("TOPLEFT",22,-22);title:SetText("Just a Hint — Settings")
        local close = CreateFrame("Button",nil,frame,"UIPanelCloseButton")
        close:SetPoint("TOPRIGHT",-3,-3)
        frame.checks = {}
        for index, entry in ipairs(options) do
            local key = entry[1]
            local check = CreateFrame("CheckButton",nil,frame,"UICheckButtonTemplate")
            check:SetSize(28,28);check:SetPoint("TOPLEFT",22,-62-(index-1)*40)
            local label = check:CreateFontString(nil,"OVERLAY","GameFontHighlight")
            label:SetPoint("LEFT",check,"RIGHT",5,0);label:SetText(entry[2])
            check:SetScript("OnClick",function(self) Panel.Set(key,self:GetChecked()==true);Panel.UpdateState() end)
            frame.checks[key] = check
        end
        local note = frame:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
        note:SetPoint("BOTTOMLEFT",24,64);note:SetWidth(420);note:SetJustifyH("LEFT")
        note:SetText("Replaces and hides Blizzard's quest tracker by default.\nOpen the Map & Quest Log to read quests and request Hint.")
        frame.modeToggle = CreateFrame("Button",nil,frame,"UIPanelButtonTemplate")
        frame.modeToggle:SetSize(225,26);frame.modeToggle:SetPoint("BOTTOMLEFT",22,22)
        frame.modeToggle:SetScript("OnClick",function()
            local action = NS.Guard.Action()
            local ok,err = NS.Guard.Toggle()
            NS.Message(ok and (action=="start" and "Just a Hint started." or "Saved guidance settings restored.") or err)
            Panel.UpdateState()
        end)
        local elapsed = 0
        frame:SetScript("OnUpdate",function(_,dt)
            elapsed=elapsed+dt
            if elapsed>=0.5 then elapsed=0;Panel.UpdateState() end
        end)
        UISpecialFrames = UISpecialFrames or {}
        table.insert(UISpecialFrames,"JustAHintSettings")
    end
    Panel.UpdateState()
    Panel.frame:Show()
end
