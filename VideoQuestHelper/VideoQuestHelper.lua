local addonName, addon = ...
local events = CreateFrame("Frame")
local popup, button
local videos

local function questID(value)
    local id = tonumber(value)
    if id and id > 0 and id <= 2147483647 and id % 1 == 0 then
        return id
    end
end

local function detailsFrame()
    return QuestMapFrame and (QuestMapFrame.DetailsFrame
        or (QuestMapFrame.QuestsFrame and QuestMapFrame.QuestsFrame.DetailsFrame))
end

local function selectedQuest()
    local details = detailsFrame()
    if details and details:IsVisible() then
        return questID(details.questID)
    end
end

local function encode(value)
    return (value:gsub("[^%w%-_%.~]", function(char)
        return string.format("%%%02X", char:byte())
    end))
end

local function validVideoID(value)
    return type(value) == "string" and #value == 11 and value:match("^[%w_-]+$")
end

local function parseVideoID(value)
    local id = value:match("^https://www%.youtube%.com/watch%?v=([%w_-]+)$")
        or value:match("^https://youtu%.be/([%w_-]+)$")
        or value
    return validVideoID(id) and id
end

local function buildLink(id)
    local title = C_QuestLog.GetTitleForQuestID(id)
    local video = videos and videos[id]
    local seconds = 0
    if not validVideoID(video) then
        local entry = addon.FindVideo(id, title)
        if entry then video, seconds = entry[1], entry[2] end
    end
    if validVideoID(video) then
        local timestamp = seconds > 0 and ("&t=" .. seconds .. "s") or ""
        return "https://www.youtube.com/watch?v=" .. video .. timestamp, title, video, seconds
    end
    local query = string.format('WoW Forever "%s" quest walkthrough',
        title and title ~= "" and title or ("quest " .. id))
    return "https://www.youtube.com/results?search_query=" .. encode(query), title, nil, nil, query
end

local function showLink(id, openFromButton)
    local url, title, video, seconds, query = buildLink(id)
    if openFromButton and videos and videos.autoOpen then
        if popup then popup:Hide() end
        if video then
            addon.SignalVideo(video, seconds)
        else
            addon.SignalSearch(query)
        end
        return
    end
    if not popup then
        popup = CreateFrame("Frame", "VideoQuestHelperLinkFrame", UIParent, "BackdropTemplate")
        popup:SetSize(460, 138)
        popup:SetPoint("CENTER")
        popup:SetFrameStrata("DIALOG")
        popup:SetClampedToScreen(true)
        popup:EnableMouse(true)
        popup:SetBackdrop({
            bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
            edgeSize = 24, insets = { left = 6, right = 6, top = 6, bottom = 6 },
        })
        local close = CreateFrame("Button", nil, popup, "UIPanelCloseButton")
        close:SetPoint("TOPRIGHT", -4, -4)
        popup.title = popup:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        popup.title:SetPoint("TOPLEFT", 20, -18)
        popup.title:SetWidth(390)
        popup.title:SetJustifyH("LEFT")
        popup.hint = popup:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        popup.hint:SetPoint("TOPLEFT", 20, -57)
        local edit = CreateFrame("EditBox", nil, popup, "InputBoxTemplate")
        edit:SetPoint("BOTTOMLEFT", 25, 23)
        edit:SetSize(410, 26)
        edit:SetAutoFocus(false)
        edit:SetScript("OnEscapePressed", function() popup:Hide() end)
        edit:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)
        popup.edit = edit
        tinsert(UISpecialFrames, popup:GetName())
    end
    popup.title:SetText(title and title ~= "" and title or ("Quest " .. id))
    popup.hint:SetText(video and "Video link. Ctrl+C copies the link."
        or "No catalog video for this quest. Ctrl+C copies the search link.")
    popup.edit:SetText(url)
    popup:Show()
    popup.edit:SetFocus()
    popup.edit:HighlightText()
end

local function attachButton()
    local details = detailsFrame()
    if not details then return end
    if button and button:GetParent() == details then return end
    if button then button:Hide() end
    button = CreateFrame("Button", nil, details, "UIPanelButtonTemplate")
    button:SetSize(146, 22)
    button:SetPoint("TOPRIGHT", details, "TOPRIGHT", -9, -10)
    button:SetText("|cffffffffYouTube Tutorial|r")
    local label = button:GetFontString()
    label:ClearAllPoints()
    label:SetPoint("CENTER", button, "CENTER", 9, 0)

    local badge = button:CreateTexture(nil, "ARTWORK")
    badge:SetSize(20, 13)
    badge:SetPoint("LEFT", button, "LEFT", 9, 0)
    badge:SetColorTexture(1, 0, 0)

    -- Draw the play symbol with solid textures so it does not depend on font glyphs.
    for column = 0, 4 do
        local triangle = button:CreateTexture(nil, "OVERLAY")
        triangle:SetSize(1, 9 - 2 * column)
        triangle:SetPoint("LEFT", badge, "LEFT", 8 + column, 0)
        triangle:SetColorTexture(1, 1, 1)
    end
    button:SetScript("OnClick", function()
        local id = selectedQuest()
        if id then showLink(id, true) end
    end)
end

events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_LOGIN")
events:SetScript("OnEvent", function(self, event, name)
    if event == "ADDON_LOADED" and name == addonName then
        if type(VideoQuestHelperDB) ~= "table" then VideoQuestHelperDB = {} end
        videos = VideoQuestHelperDB
    end
    attachButton()
    if not self.hooked and type(QuestMapFrame_ShowQuestDetails) == "function" then
        hooksecurefunc("QuestMapFrame_ShowQuestDetails", attachButton)
        self.hooked = true
    end
    if videos and button and self.hooked then
        self:UnregisterEvent("ADDON_LOADED")
        self:UnregisterEvent("PLAYER_LOGIN")
    end
end)

local function say(message)
    print("|cffff5555Video Quest Helper:|r " .. message)
end

SLASH_VIDEOQUESTHELPER1 = "/vqh"
SlashCmdList.VIDEOQUESTHELPER = function(message)
    local action, arg, value = message:match("^%s*(%S*)%s*(%S*)%s*(.-)%s*$")
    local id = questID(arg)
    if (action == "auto" or action == "manual") and videos then
        videos.autoOpen = action == "auto"
        say(videos.autoOpen and "Automatic opening enabled. Start the Windows helper." or "Click the button to copy a YouTube link.")
    elseif action == "set" and id and videos then
        local video = parseVideoID(value)
        if video then
            videos[id] = video
            say("Saved video for quest " .. id .. ".")
        else
            say("Use a YouTube video ID or a clean watch/share URL without extra parameters.")
        end
    elseif action == "clear" and id and videos then
        videos[id] = nil
        say("Removed saved video for quest " .. id .. ".")
    elseif action == "" or (action == "show" and (id or arg == "")) then
        id = id or selectedQuest()
        if id then showLink(id) else say("Open a quest in the quest log, or use /vqh show QUEST_ID.") end
    else
        say("/vqh show [QUEST_ID] | /vqh set QUEST_ID VIDEO | /vqh clear QUEST_ID")
    end
end
