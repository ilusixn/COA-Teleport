-- CoA Teleports: browse every teleport (stock + CoA) and click to go. Needs a GM account (uses .go xyz).
local ADDON = "CoA_Teleports"
local data = CoATeleports_Data or {}
local CATS = { "All places", "Eastern Kingdoms", "Kalimdor", "Outland", "Northrend", "Dungeons, raids & maps", "CoA custom", "Fading Islands" }
local ROWS, ROW_H = 15, 20

CoATeleportsDB = CoATeleportsDB or {}
local fav = {}

local f = CreateFrame("Frame", "CoATeleportsFrame", UIParent)
f:SetSize(660, 470)
f:SetPoint("CENTER")
f:SetFrameStrata("HIGH")
f:SetMovable(true)
f:EnableMouse(true)
f:SetClampedToScreen(true)
f:RegisterForDrag("LeftButton")
f:SetScript("OnDragStart", f.StartMoving)
f:SetScript("OnDragStop", f.StopMovingOrSizing)
f:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true, tileSize = 32, edgeSize = 32,
    insets = { left = 11, right = 12, top = 12, bottom = 11 },
})
f:Hide()
tinsert(UISpecialFrames, "CoATeleportsFrame")

local header = f:CreateTexture(nil, "ARTWORK")
header:SetTexture("Interface\\DialogFrame\\UI-DialogBox-Header")
header:SetSize(300, 64)
header:SetPoint("TOP", 0, 12)
local title = f:CreateFontString(nil, "ARTWORK", "GameFontNormal")
title:SetPoint("TOP", header, "TOP", 0, -14)
title:SetText("Teleports")

local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
close:SetPoint("TOPRIGHT", -6, -6)

-- search box
local search = CreateFrame("EditBox", "CoATeleportsSearch", f, "InputBoxTemplate")
search:SetSize(300, 20)
search:SetPoint("TOPLEFT", 190, -34)
search:SetAutoFocus(false)
local searchLabel = f:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
searchLabel:SetPoint("RIGHT", search, "LEFT", -8, 0)
searchLabel:SetText("Search")

local count = f:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
count:SetPoint("LEFT", search, "RIGHT", 10, 0)

-- category list (left)
local cat = 1
local catButtons = {}
for i, name in ipairs(CATS) do
    local b = CreateFrame("Button", nil, f)
    b:SetSize(150, 22)
    b:SetPoint("TOPLEFT", 22, -62 - (i - 1) * 24)
    b.text = b:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    b.text:SetPoint("LEFT", 6, 0)
    b.text:SetText(name)
    b:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
    b.sel = b:CreateTexture(nil, "BACKGROUND")
    b.sel:SetAllPoints()
    b.sel:SetTexture("Interface\\QuestFrame\\UI-QuestLogTitleHighlight")
    b.sel:SetVertexColor(1, 0.82, 0, 0.35)
    b.sel:Hide()
    b:SetScript("OnClick", function() cat = i; f.offset = 0; f:Update() end)
    catButtons[i] = b
end
local favBtn = CreateFrame("CheckButton", nil, f, "UICheckButtonTemplate")
favBtn:SetSize(24, 24)
favBtn:SetPoint("TOPLEFT", 18, -62 - #CATS * 24 - 8)
favBtn.text = favBtn:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
favBtn.text:SetPoint("LEFT", favBtn, "RIGHT", 2, 0)
favBtn.text:SetText("Favourites only")
favBtn:SetScript("OnClick", function() f.offset = 0; f:Update() end)

-- list (right)
local list = CreateFrame("Frame", nil, f)
list:SetPoint("TOPLEFT", 190, -62)
list:SetSize(430, ROWS * ROW_H)
list:SetBackdrop({
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 14,
    insets = { left = 3, right = 3, top = 3, bottom = 3 },
})
list:SetBackdropColor(0, 0, 0, 0.6)

local scroll = CreateFrame("ScrollFrame", "CoATeleportsScroll", f, "FauxScrollFrameTemplate")
scroll:SetPoint("TOPLEFT", list, "TOPLEFT", 4, -4)
scroll:SetPoint("BOTTOMRIGHT", list, "BOTTOMRIGHT", -26, 4)

local shown = {}
local selected
local rows = {}

local function Fav(e) return CoATeleportsDB[e[2] .. ":" .. e[1]] end

local function Refresh()
    local text = (search:GetText() or ""):lower()
    local onlyFav = favBtn:GetChecked()
    wipe(shown)
    for _, e in ipairs(data) do
        if (cat == 1 or e[7] == cat - 1) and (text == "" or e[1]:lower():find(text, 1, true)) and (not onlyFav or Fav(e)) then
            shown[#shown + 1] = e
        end
    end
    count:SetText(#shown .. " places")
    for i, b in ipairs(catButtons) do
        if i == cat then b.sel:Show() else b.sel:Hide() end
    end
    FauxScrollFrame_Update(scroll, #shown, ROWS, ROW_H)
    local off = FauxScrollFrame_GetOffset(scroll)
    for i = 1, ROWS do
        local r, e = rows[i], shown[i + off]
        if e then
            r.entry = e
            r.name:SetText((Fav(e) and "|cffffd100*|r " or "") .. e[1])
            r.coord:SetText(string.format("%d  %.0f, %.0f, %.0f", e[2], e[3], e[4], e[5]))
            if selected == e then r.sel:Show() else r.sel:Hide() end
            r:Show()
        else
            r.entry = nil
            r:Hide()
        end
    end
end
f.Update = Refresh

local info = f:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
info:SetPoint("BOTTOMLEFT", 192, 46)
info:SetText("Click a place, then Teleport (or double-click).")

local function Go(e)
    if not e then return end
    SendChatMessage(string.format(".go xyz %.3f %.3f %.3f %d %.3f", e[3], e[4], e[5], e[2], e[6]), "SAY")
end

local function Select(e)
    selected = e
    if e then
        info:SetText(string.format("|cffffd100%s|r  -  map %d  (%.1f, %.1f, %.1f)", e[1], e[2], e[3], e[4], e[5]))
    end
    Refresh()
end

for i = 1, ROWS do
    local r = CreateFrame("Button", nil, f)
    r:SetSize(400, ROW_H)
    r:SetPoint("TOPLEFT", list, "TOPLEFT", 6, -4 - (i - 1) * ROW_H)
    r:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
    r.sel = r:CreateTexture(nil, "BACKGROUND")
    r.sel:SetAllPoints()
    r.sel:SetTexture("Interface\\QuestFrame\\UI-QuestLogTitleHighlight")
    r.sel:SetVertexColor(1, 0.82, 0, 0.4)
    r.name = r:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    r.name:SetPoint("LEFT", 4, 0)
    r.name:SetWidth(240)
    r.name:SetJustifyH("LEFT")
    r.coord = r:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    r.coord:SetPoint("RIGHT", -4, 0)
    r.coord:SetJustifyH("RIGHT")
    r:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    r:SetScript("OnClick", function(self, btn)
        if not self.entry then return end
        if btn == "RightButton" then
            local k = self.entry[2] .. ":" .. self.entry[1]
            CoATeleportsDB[k] = (not CoATeleportsDB[k]) or nil
            Refresh()
        else
            Select(self.entry)
        end
    end)
    r:SetScript("OnDoubleClick", function(self, btn)
        if self.entry and btn == "LeftButton" then Go(self.entry) end
    end)
    r:SetScript("OnEnter", function(self)
        if not self.entry then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine(self.entry[1], 1, 0.82, 0)
        GameTooltip:AddLine(string.format("Map %d", self.entry[2]), 1, 1, 1)
        GameTooltip:AddLine(string.format(".go xyz %.1f %.1f %.1f %d", self.entry[3], self.entry[4], self.entry[5], self.entry[2]), 0.7, 0.7, 0.7)
        GameTooltip:AddLine("Left-click: select   Double-click: teleport", 0.5, 1, 0.5)
        GameTooltip:AddLine("Right-click: favourite", 0.5, 1, 0.5)
        GameTooltip:Show()
    end)
    r:SetScript("OnLeave", function() GameTooltip:Hide() end)
    rows[i] = r
end

scroll:SetScript("OnVerticalScroll", function(self, offset)
    FauxScrollFrame_OnVerticalScroll(self, offset, ROW_H, Refresh)
end)
f:EnableMouseWheel(true)
f:SetScript("OnMouseWheel", function(_, delta)
    local bar = _G["CoATeleportsScrollScrollBar"]
    if bar then bar:SetValue(bar:GetValue() - delta * ROW_H * 3) end
end)

local go = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
go:SetSize(130, 26)
go:SetPoint("BOTTOMRIGHT", -26, 18)
go:SetText("Teleport")
go:SetScript("OnClick", function()
    if selected then Go(selected) else info:SetText("|cffff5555Pick a place first.|r") end
end)

local here = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
here:SetSize(130, 26)
here:SetPoint("RIGHT", go, "LEFT", -8, 0)
here:SetText("Show my position")
here:SetScript("OnClick", function()
    local x, y = GetPlayerMapPosition("player")
    info:SetText(string.format("You are at %s - %s (map %.1f, %.1f). Use .gps for exact coordinates.", GetZoneText() or "?", GetSubZoneText() or "", x * 100, y * 100))
end)

search:SetScript("OnTextChanged", function() f.offset = 0; Refresh() end)
search:SetScript("OnEscapePressed", search.ClearFocus)
search:SetScript("OnEnterPressed", search.ClearFocus)
f:SetScript("OnShow", function() Refresh() end)

-- minimap button
local mb = CreateFrame("Button", "CoATeleportsMinimapButton", Minimap)
mb:SetSize(31, 31)
mb:SetFrameStrata("MEDIUM")
mb:SetFrameLevel(8)
mb:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
local ring = mb:CreateTexture(nil, "OVERLAY")
ring:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
ring:SetSize(53, 53)
ring:SetPoint("TOPLEFT")
local icon = mb:CreateTexture(nil, "BACKGROUND")
icon:SetTexture("Interface\\Icons\\Spell_Arcane_PortalOrgrimmar")
icon:SetSize(20, 20)
icon:SetPoint("CENTER", 0, 1)
local function PlaceButton()
    local a = math.rad(CoATeleportsDB.angle or 215)
    mb:SetPoint("CENTER", Minimap, "CENTER", math.cos(a) * 80, math.sin(a) * 80)
end
mb:RegisterForDrag("RightButton")
mb:SetScript("OnDragStart", function(self)
    self:SetScript("OnUpdate", function()
        local mx, my = Minimap:GetCenter()
        local px, py = GetCursorPosition()
        local s = Minimap:GetEffectiveScale()
        CoATeleportsDB.angle = math.deg(math.atan2(py / s - my, px / s - mx))
        self:ClearAllPoints()
        PlaceButton()
    end)
end)
mb:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)
mb:SetScript("OnClick", function() if f:IsShown() then f:Hide() else f:Show() end end)
mb:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:AddLine("CoA Teleports", 1, 0.82, 0)
    GameTooltip:AddLine("Click to open. Right-drag to move.", 1, 1, 1)
    GameTooltip:Show()
end)
mb:SetScript("OnLeave", function() GameTooltip:Hide() end)

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:SetScript("OnEvent", function() CoATeleportsDB = CoATeleportsDB or {}; PlaceButton() end)

SLASH_COATELEPORTS1 = "/tp"
SLASH_COATELEPORTS2 = "/teleports"
SlashCmdList["COATELEPORTS"] = function() if f:IsShown() then f:Hide() else f:Show() end end
