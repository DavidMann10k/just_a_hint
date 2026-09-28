local _, NS = ...
local Report = {}
NS.StatusReport = Report

local function label(parent, font, width)
    local text = parent:CreateFontString(nil, "OVERLAY", font)
    text:SetWidth(width)
    text:SetJustifyH("LEFT")
    text:SetJustifyV("TOP")
    return text
end

function Report.Open(text)
    if not Report.frame then
        local frame = CreateFrame("Frame", "JustAHintReport", UIParent, "BackdropTemplate")
        frame:SetSize(650, 430)
        frame:SetPoint("CENTER")
        frame:SetFrameStrata("FULLSCREEN_DIALOG")
        frame:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8" })
        frame:SetBackdropColor(0.03, 0.035, 0.04, 1)
        frame:EnableMouse(true)
        local title = label(frame, "GameFontNormal", 585)
        title:SetPoint("TOPLEFT", 20, -18)
        title:SetText("Just a Hint report — Ctrl+A, Ctrl+C to copy. Escape to close.")
        local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
        close:SetPoint("TOPRIGHT")
        local scroll = CreateFrame("ScrollFrame", "JustAHintReportScroll", frame, "UIPanelScrollFrameTemplate")
        scroll:SetPoint("TOPLEFT", 20, -50)
        scroll:SetPoint("BOTTOMRIGHT", -40, 20)
        local edit = CreateFrame("EditBox", nil, scroll)
        edit:SetMultiLine(true)
        edit:SetFontObject("ChatFontNormal")
        edit:SetWidth(585)
        edit:SetAutoFocus(false)
        edit:SetScript("OnEscapePressed", function() frame:Hide() end)
        scroll:SetScrollChild(edit)
        frame.edit = edit
        UISpecialFrames = UISpecialFrames or {}
        table.insert(UISpecialFrames, "JustAHintReport")
        Report.frame = frame
    end
    Report.frame:Show()
    Report.frame.edit:SetText(text)
    Report.frame.edit:SetFocus()
    Report.frame.edit:HighlightText()
end
