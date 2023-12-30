local Blacklist = LibStub("AceAddon-3.0"):NewAddon("Blacklist", "AceConsole-3.0", "AceHook-3.0", "AceComm-3.0", "AceSerializer-3.0")

local C_AddOns_IsAddOnLoaded = C_AddOns.IsAddOnLoaded

local StaticPopup_Show = StaticPopup_Show

local COM_PREFIX = "BLACKLIST"
local COM_PREFIX_ASYNC = COM_PREFIX.."-AS"
local COM_PREFIX_CHECK = COM_PREFIX.."-CHECK"
local COM_PREFIX_ANSWER = COM_PREFIX.."-ANSWER"

local _G = _G
local UIParent = UIParent

local blacklist

local PredefinedType = {
    BLACKLIST = {
        name = "Blacklist",
        color = { r = 255, g = 0, b = 0},
        supportTypes = {
            PARTY = true,
            PLAYER = true,
            ENEMY_PLAYER = true,
            RAID_PLAYER = true,
            RAID = true,
            FRIEND = true,
            GUILD = true,
            GUILD_OFFLINE = true,
            CHAT_ROSTER = true,
            TARGET = true,
            ARENAENEMY = true,
            FOCUS = true,
            WORLD_STATE_SCORE = true,
            COMMUNITIES_WOW_MEMBER = true,
            COMMUNITIES_GUILD_MEMBER = true,
            RAF_RECRUIT = true
        },
        func = function(frame)
            local playerName = Blacklist:getPlayerNameFromFrame(frame)

            if not playerName then
                return
            end

            StaticPopup_Show("BLACKLIST_REASON_POPUP", nil, nil, playerName)
            --Blacklist:addToBlacklist(playerName)
        end,
        isHidden = function(frame)
            --NPC
            if frame.unit and frame.unit == "target" then
                if not UnitPlayerControlled("target") then
                    return true
                end
            end

            --NPC
            if frame.unit and frame.unit == "focus" then
                if not UnitPlayerControlled("focus") then
                    return true
                end
            end

            --self
            if frame.name == UnitName('player') then
                if not frame.server or frame.server == GetRealmName() then
                    return true
                end
            end

            local playerName = Blacklist:getPlayerNameFromFrame(frame)
            if not playerName then
                return true
            end

            local blacklistInfo = Blacklist:isBlacklisted(playerName)
            if blacklistInfo then
                return true
            end
            
            return false
        end
    },
    PARDON = {
        name = "Pardon",
        color = { r = 0, g = 255, b = 0},
        supportTypes = {
            PARTY = true,
            PLAYER = true,
            ENEMY_PLAYER = true,
            RAID_PLAYER = true,
            RAID = true,
            FRIEND = true,
            GUILD = true,
            GUILD_OFFLINE = true,
            CHAT_ROSTER = true,
            TARGET = true,
            ARENAENEMY = true,
            FOCUS = true,
            WORLD_STATE_SCORE = true,
            COMMUNITIES_WOW_MEMBER = true,
            COMMUNITIES_GUILD_MEMBER = true,
            RAF_RECRUIT = true
        },
        func = function(frame)
            local playerName = Blacklist:getPlayerNameFromFrame(frame)

            if not playerName then
                return
            end

            Blacklist:removeFromBlacklist(playerName)
        end,
        isHidden = function(frame)
            --NPC
            if frame.unit and frame.unit == "target" then
                if not UnitPlayerControlled("target") then
                    return true
                end
            end

            --NPC
            if frame.unit and frame.unit == "focus" then
                if not UnitPlayerControlled("focus") then
                    return true
                end
            end

            --self
            if frame.name == UnitName('player') then
                if not frame.server or frame.server == GetRealmName() then
                    return true
                end
            end

            local playerName = Blacklist:getPlayerNameFromFrame(frame)
            if not playerName then
                return true
            end

            local blacklistInfo = Blacklist:isBlacklisted(playerName)
            if not blacklistInfo then
                return true
            end

            return false
        end
    }
}

local asyncCounter = 1

function Blacklist:sendMessage(msg, prefix)
    prefix = prefix or COM_PREFIX
    Blacklist:SendCommMessage(prefix, Blacklist:Serialize(msg), "RAID", nil)
end

function Blacklist:sendAnswer(msg)
    Blacklist:SendCommMessage(msg.prefix, Blacklist:Serialize(msg.answer), msg.channel, msg.receiver)
end

function Blacklist:createAskMessage(playerName, task)
    local prefix = COM_PREFIX_ASYNC..asyncCounter
    asyncCounter = asyncCounter + 1 % 9999
    return {
        ask = playerName,
        task = task,
        prefix = prefix,
        channel = "WHISPER",
        receiver = self:getUnitNameAndRealmFromTarget("player")
    }
end

function Blacklist:buildNextMessageHandler(askMessage, callback)
    self:RegisterComm(askMessage.prefix, callback)
end

function Blacklist:sendAskAsync(askMessage, callback)
    Blacklist:buildNextMessageHandler(askMessage, callback)
    Blacklist:SendCommMessage(COM_PREFIX_ASYNC, Blacklist:Serialize(askMessage), "RAID", nil)
end

function Blacklist:getUnitNameAndRealmFromTarget(unit)
    local unitName, unitRealm = UnitName(unit)

    if not unitRealm then
        unitRealm = GetRealmName()
    end

    return unitName.."-"..unitRealm
end

function Blacklist:getLeaderNameAndServerFromName(leaderName)
    if not string.find(leaderName, "-") then
        leaderName = leaderName.."-"..GetRealmName()
    end
    return leaderName
end

function Blacklist:getPlayerNameFromFrame(frame)
    local playerName
    if frame.unit then
        playerName = self:getUnitNameAndRealmFromTarget(frame.unit)
    end

    if frame.chatTarget and not playerName then
        playerName = frame.chatTarget
    end

    if not playerName then
        Dump(frame, "CAN'T CREATE KEY")
        return nil
    end

    return playerName
end

function Blacklist:addToBlacklist(playerName, reason)
    --todo: frame.which alle möglichkeiten abdecken
    
    if blacklist[playerName] then
        Dump(frame, "UNIT ALREADY BLACKLISTED")
        return
    end

    blacklist[playerName] = {
        date = date("%Y.%m.%d %H:%M:%S"),
        reason = reason,
    }

    Blacklist:Print("Added < "..playerName.." > to Blacklist")
end

local function removeKeyFromTable(table, playerName)
    table[playerName] = nil
end

function Blacklist:removeFromBlacklist(playerName)
    removeKeyFromTable(blacklist, playerName)
    Blacklist:Print("Removed < "..playerName.." > from Blacklist")
end

function Blacklist:isBlacklisted(playerName)
    return blacklist[playerName]
end

function Blacklist:isBlacklistedRemote(askMessage, callback)
    Blacklist:sendAskAsync(askMessage, callback)
end

local function ContextMenuButton_OnEnter(button)
    _G[button:GetName() .. "Highlight"]:Show()
end

local function ContextMenuButton_OnLeave(button)
    _G[button:GetName() .. "Highlight"]:Hide()
end

local function ContextMenu_OnShow(menu)
    local parent = menu:GetParent() or menu
    local width = parent:GetWidth()
    local height = 16
    for i = 1, #menu.buttons do
        local button = menu.buttons[i]
        if button:IsShown() then
            button:SetWidth(width - 32)
            height = height + 16
        end
    end
    menu:SetHeight(height)
    return height
end

function Blacklist:SkinDropDownList(frame)
    local Backdrop = _G[frame:GetName() .. "Backdrop"]
    local menuBackdrop = _G[frame:GetName() .. "MenuBackdrop"]

    if Backdrop then
        Backdrop:Kill()
    end

    if menuBackdrop then
        menuBackdrop:Kill()
    end
end

function Blacklist:SkinButton(button)
    local r = 255
    local g = 0
    local b = 0

    local highlight = _G[button:GetName() .. "Highlight"]
    --highlight:SetTexture(E.Media.Textures.Highlight)
    highlight:SetBlendMode("BLEND")
    highlight:SetDrawLayer("BACKGROUND")
    highlight:SetVertexColor(r, g, b)

    button:SetScript("OnEnter", ContextMenuButton_OnEnter)
    button:SetScript("OnLeave", ContextMenuButton_OnLeave)

    _G[button:GetName() .. "Check"]:SetAlpha(0)
    _G[button:GetName() .. "UnCheck"]:SetAlpha(0)
    _G[button:GetName() .. "Icon"]:SetAlpha(0)
    _G[button:GetName() .. "ColorSwatch"]:SetAlpha(0)
    _G[button:GetName() .. "ExpandArrow"]:SetAlpha(0)
    _G[button:GetName() .. "InvisibleButton"]:SetAlpha(0)
end

function Blacklist:SetHighlight(button, config)
    local r = config.color.r
    local g = config.color.g
    local b = config.color.b

    local highlight = _G[button:GetName() .. "Highlight"]
    --highlight:SetTexture(E.Media.Textures.Highlight)
    highlight:SetBlendMode("BLEND")
    highlight:SetDrawLayer("BACKGROUND")
    highlight:SetVertexColor(r, g, b)
end

function Blacklist:CreateMenu()
    if self.menu then
        return
    end

    local frame = CreateFrame("Button", "BlacklistMenu", UIParent, "UIDropDownListTemplate")
    --self:SkinDropDownList(frame)
    --frame:Hide()

    frame:SetScript("OnShow", ContextMenu_OnShow)
    frame:SetScript("OnHide", nil)
    frame:SetScript("OnClick", nil)
    frame:SetScript("OnUpdate", nil)

    frame.buttons = {}

    local i = 1
    for _ in pairs(PredefinedType) do
        local button = _G["BlacklistMenuButton"..i]
        if not button then
            button = CreateFrame("Button", "BlacklistMenuButton"..i, frame, "UIDropDownMenuButtonTemplate")
        end

        local text = _G[button:GetName() .. "NormalText"]
        text:ClearAllPoints()
        text:SetPoint("TOPLEFT", button, "TOPLEFT", 0, 0)
        text:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 0, 0)
        button.Text = text

        button:SetScript("OnEnable", nil)
        button:SetScript("OnDisable", nil)
        button:SetScript("OnClick", nil)

        self:SkinButton(button)

        button:Hide()

        frame.buttons[i] = button
        i = i + 1
    end

    self.menu = frame
end

function Blacklist:UpdateButton(index, config, closeAfterFunction)
    local button = self.menu.buttons[index]
    if not button then
        return
    end

    button.Text:SetText(config.name)
    button.Text:Show()

    button.supportTypes = config.supportTypes
    button.isHidden = config.isHidden

    self:SetHighlight(button, config)

    button:SetScript(
        "OnClick",
        function()
            config.func(self.cache)
            if closeAfterFunction then
                CloseDropDownMenus()
            end
        end
    )
end

function Blacklist:UpdateMenu()
    local buttonIndex = 1

    self:UpdateButton(buttonIndex, PredefinedType.BLACKLIST, true)
    buttonIndex = buttonIndex + 1

    self:UpdateButton(buttonIndex, PredefinedType.PARDON, true)
    buttonIndex = buttonIndex + 1

    for i, button in pairs(self.menu.buttons) do
        if i >= buttonIndex then
            button:SetScript("OnClick", nil)
            button.Text:Hide()
            button.supportTypes = nil
        end
    end
end

function Blacklist:DisplayButtons()
    local buttonOrder = 0
    for _, button in pairs(self.menu.buttons) do
        if button.supportTypes and button.supportTypes[self.cache.which] then
            if not button.isHidden(self.cache) then
                buttonOrder = buttonOrder + 1
                button:Show()
                button:ClearAllPoints()
                button:SetPoint("TOPLEFT", self.menu, "TOPLEFT", 16, -16 * buttonOrder)
            else
                button:Hide()
            end
        else
            button:Hide()
        end
    end

    return buttonOrder > 0
end

local info = {}
function Blacklist_CreateBarDropdown(self, level)
    Blacklist:Print("Blacklist_CreateBarDropdown")
	if not level then return end
	for k in pairs(info) do info[k] = nil end

    Dump(self, "self")

	if not self then --and not self.relativeTo.LeftText then
        return
    end

    Blacklist:Print("after check")

    local player = Blacklist.cache.name
		if level == 1 then
			info.isTitle = 1
			info.text = player
			info.notCheckable = true
			UIDropDownMenu_AddButton(info, level)

			info = UIDropDownMenu_CreateInfo()

            info.isTitle = nil
            info.notCheckable = true
            info.hasArrow = true
            info.disabled = nil
            info.text = "AnnounceDropDownMenu"
            info.value = { ["Key"] = "AnnounceDropDownMenu" }
            info.arg1 = Blacklist.cache.name
            UIDropDownMenu_AddButton(info, level)
        end
end

function Blacklist:newDropdown(frame, dropdown)
    Blacklist:Print("newDropdown")
	MyDropdown = CreateFrame("Frame", "Blacklist_BarDropDownMenu", frame)
	MyDropdown.displayMode = "MENU"
	MyDropdown.initialize = Blacklist_CreateBarDropdown
	--UIDropDownMenu_SetAnchor(MyDropdown, 0, 0, "TOPLEFT", frame, "TOPRIGHT")
    --CloseDropDownMenus(1)
    ToggleDropDownMenu(1, nil, MyDropdown)
end

function Blacklist:ShowMenu(frame)
    -- Blacklist:Print("ShowMenu")
    local dropdown = frame.dropdown
    -- Blacklist:newDropdown(frame, dropdown)

    -- if true then
    --     return
    -- end

    wipe(self.cache)
    self.cache = {
        which = dropdown.which,
        name = dropdown.name,
        unit = dropdown.unit,
        server = dropdown.server,
        chatTarget = dropdown.chatTarget,
        communityClubID = dropdown.communityClubID,
        bnetIDAccount = dropdown.bnetIDAccount
    }

    if self.cache.which then
        if self:DisplayButtons() then
            self.menu:SetParent(frame)
            self.menu:SetFrameStrata(frame:GetFrameStrata())
            self.menu:SetFrameLevel(frame:GetFrameLevel() + 2)

            local menuHeight = ContextMenu_OnShow(self.menu)
            frame:SetHeight(frame:GetHeight() + menuHeight)

            self.menu:ClearAllPoints()
            local offset = 0
            if C_AddOns_IsAddOnLoaded("RaiderIO") then
                for _, child in pairs {_G.DropDownList1:GetChildren()} do
                    local name = child:IsShown() and child:GetName()
                    if name and strfind(name, "^LibDropDownExtensionCustomDropDown") then
                        offset = 47
                    end
                end
            end

            self.menu:SetPoint("BOTTOMLEFT", 0, offset)
            self.menu:SetPoint("BOTTOMRIGHT", 0, offset)
            self.menu:Show()
        end
    end
end

function Blacklist:CloseMenu(frame)
    if self.menu then
        self.menu:Hide()
    end
end

local function remoteTooltipAdd(tooltip, playerName)
    local remoteBlocks = {}

    local askMessage = Blacklist:createAskMessage(playerName, "isBlacklisted")
    Blacklist:isBlacklistedRemote(askMessage, function(self, message, channel, sender)
        if askMessage.prefix ~= self or not Blacklist.Deserialize or sender == UnitName('player') then
            return
        end

        local success, msg = Blacklist:Deserialize(message)

        if remoteBlocks[playerName] and remoteBlocks[playerName][sender] then
            return
        end

        remoteBlocks[playerName] = {[sender] = true}

        tooltip:AddLine("-------------------------", 255, 0, 0)
        tooltip:AddLine("Blocked by "..sender, 255, 0, 0)
        if msg.reason and msg.reason ~= "" then
            tooltip:AddLine("Reason: "..msg.reason, 255, 0, 0)
        end
        if msg.date then
            tooltip:AddLine("Date: "..msg.date, 255, 0, 0)
        end
        tooltip:AddLine("-------------------------", 255, 0, 0)
        tooltip:Show()
    end)
end

local function TooltipCallback(self)
    local _, unit = self:GetUnit()
    if not unit or not UnitIsPlayer(unit) then
        return
    end

    local playerName = Blacklist:getUnitNameAndRealmFromTarget(unit)

    local tooltip = self

    remoteTooltipAdd(tooltip, playerName)

    local blacklistInfo = Blacklist:isBlacklisted(playerName)

    if blacklistInfo then
        tooltip:AddLine("Player is Blacklisted!", 255, 0, 0)
        if blacklistInfo.reason and blacklistInfo.reason ~= "" then
            tooltip:AddLine("Reason: "..blacklistInfo.reason, 255, 0, 0)
        end
        if blacklistInfo.date then
            tooltip:AddLine("Date: "..blacklistInfo.date, 255, 0, 0)
        end
    end

    tooltip:Show()
end

local function SetSearchEntry(tooltip, resultID, _)
    local entry = C_LFGList.GetSearchResultInfo(resultID)
    local leaderName = Blacklist:getLeaderNameAndServerFromName(entry.leaderName)

    remoteTooltipAdd(tooltip, leaderName)

    local blacklistInfo = Blacklist:isBlacklisted(leaderName)

    if blacklistInfo then
        tooltip:AddLine("Player is Blacklisted!", 255, 0, 0)
        if blacklistInfo.reason and blacklistInfo.reason ~= "" then
            tooltip:AddLine("Reason: "..blacklistInfo.reason, 255, 0, 0)
        end
        if blacklistInfo.date then
            tooltip:AddLine("Date: "..blacklistInfo.date, 255, 0, 0)
        end
        tooltip:Show()
    end
end

local function remoteTextChange(frame, playerName, originalName)
    local remoteBlocks = {}

    local askMessage = Blacklist:createAskMessage(playerName, "isBlacklisted")
    Blacklist:isBlacklistedRemote(askMessage, function(self, message, channel, sender)
        if askMessage.prefix ~= self or not Blacklist.Deserialize or sender == UnitName('player') then
            return
        end

        local success, msg = Blacklist:Deserialize(message)

        if remoteBlocks[playerName] and remoteBlocks[playerName][sender] then
            return
        end

        remoteBlocks[playerName] = {[sender] = true}

        frame.Name:SetText("[B] "..originalName)
        frame.Name:SetTextColor(255, 0, 0)
    end)
end

local function OnLFGListSearchEntryUpdate(self)
    local searchResultInfo = C_LFGList.GetSearchResultInfo(self.resultID)

    if searchResultInfo.leaderName then
        local leaderName = Blacklist:getLeaderNameAndServerFromName(searchResultInfo.leaderName)

        remoteTextChange(self, leaderName, searchResultInfo.name)

        local blacklistInfo = Blacklist:isBlacklisted(leaderName)

        if blacklistInfo then
            self.Name:SetText("[B] "..searchResultInfo.name)
            self.Name:SetTextColor(255, 0, 0)
        end
    end
end

local function OnUpdateApplicantMember(member, appID, memberIdx, status, pendingStatus)
	local name = C_LFGList.GetApplicantMemberInfo(appID, memberIdx);

    local applicantName = Blacklist:getLeaderNameAndServerFromName(name)

    remoteTextChange(member, applicantName, name)

    local blacklistInfo = Blacklist:isBlacklisted(applicantName)

    if blacklistInfo then
        member.Name:SetText("[B] "..name)
        member.Name:SetTextColor(255, 0, 0)
    end
end

local OnEnterApplicant
local OnLeaveApplicant
local hooked = {}

local function HookApplicantButtons(buttons)
    for _, button in pairs(buttons) do
        if not hooked[button] then
            hooked[button] = true
            button:HookScript("OnEnter", OnEnterApplicant)
            button:HookScript("OnLeave", OnLeaveApplicant)
        end
    end
end

function OnEnterApplicant(self)
    if self.applicantID and self.Members then
        HookApplicantButtons(self.Members)
    elseif self.memberIdx then
        local parent = self:GetParent()
        local fullName = C_LFGList.GetApplicantMemberInfo(parent.applicantID, self.memberIdx)
        local applicantName = Blacklist:getLeaderNameAndServerFromName(fullName)

        remoteTooltipAdd(GameTooltip, applicantName)

        local blacklistInfo = Blacklist:isBlacklisted(applicantName)

        if blacklistInfo then
            GameTooltip:AddLine("Player is Blacklisted!", 255, 0, 0)
            if blacklistInfo.reason and blacklistInfo.reason ~= "" then
                GameTooltip:AddLine("Reason: "..blacklistInfo.reason, 255, 0, 0)
            end
            if blacklistInfo.date then
                GameTooltip:AddLine("Date: "..blacklistInfo.date, 255, 0, 0)
            end
            GameTooltip:Show()
        end
    end
end

function OnLeaveApplicant(self)
    GameTooltip:Hide()
end

function Blacklist:OnCommReceived(message, channel, sender) --(prefix, message, _, sender)
    local prefix = self

	if prefix ~= COM_PREFIX or not Blacklist.Deserialize or sender == UnitName('player') then
        return
    end

    local success, msg = Blacklist:Deserialize(message)
end

function Blacklist:OnCommReceivedCheck(message, channel, sender) --(prefix, message, _, sender)
    local prefix = self
	if prefix ~= COM_PREFIX_CHECK or not Blacklist.Deserialize or sender == UnitName('player') then
        return
    end

    local success, msg = Blacklist:Deserialize(message)
end

function Blacklist:OnCommReceivedAnswer(message, channel, sender) --(prefix, message, _, sender)
    local prefix = self
	if prefix ~= COM_PREFIX_ANSWER or not Blacklist.Deserialize or sender == UnitName('player') then
        return
    end

    local success, msg = Blacklist:Deserialize(message)
end

function Blacklist:OnCommReceivedAsync(message, channel, sender) --(prefix, message, _, sender)
    local prefix = self
	if prefix ~= COM_PREFIX_ASYNC or not Blacklist.Deserialize or sender == UnitName('player') then
        return
    end

    local success, msg = Blacklist:Deserialize(message)

    if msg.task == "isBlacklisted" then
        local blacklistInfo = Blacklist:isBlacklisted(msg.ask)
        
        if blacklistInfo then
            Blacklist:sendAnswer({
                prefix = msg.prefix,
                answer = blacklistInfo,
                channel = msg.channel,
                receiver = msg.receiver
            })
        end
    end
end

StaticPopupDialogs["BLACKLIST_REASON_POPUP"] = {
	text = "Blacklist reason",
	button1 = "Save",
	button2 = "Cancel",
	OnAccept = function(self, data, data2)
        local reason = self.editBox:GetText()
        Blacklist:addToBlacklist(data, reason)
 	end,
	timeout = 0,
	whileDead = true,
	hideOnEscape = true,
    hasEditBox = true,
    enterClicksFirstButton = true
}

function Blacklist:OnInitialize()
    self:RegisterComm(COM_PREFIX, Blacklist.OnCommReceived)
    self:RegisterComm(COM_PREFIX_CHECK, Blacklist.OnCommReceivedCheck)
    self:RegisterComm(COM_PREFIX_ANSWER, Blacklist.OnCommReceivedAnswer)
    self:RegisterComm(COM_PREFIX_ASYNC, Blacklist.OnCommReceivedAsync)

    self.db = LibStub("AceDB-3.0"):New("BlacklistDB")

    if not self.db.global.blacklist then
        self.db.global.blacklist = {}
    end

    blacklist = self.db.global.blacklist

    self.cache = {}

    self:CreateMenu()
    self:UpdateMenu()
    self:SecureHookScript(_G.DropDownList1, "OnShow", "ShowMenu")
    self:SecureHookScript(_G.DropDownList1, "OnHide", "CloseMenu")

    hooksecurefunc("LFGListUtil_SetSearchEntryTooltip", SetSearchEntry)
    --hooksecurefunc(FriendsTooltip, "Show", TooltipCallback) eigener callback
    hooksecurefunc("LFGListSearchEntry_Update", OnLFGListSearchEntryUpdate)
    hooksecurefunc("LFGListApplicationViewer_UpdateApplicantMember", OnUpdateApplicantMember)

    LFGListFrame.ApplicationViewer.ScrollBox:RegisterCallback(ScrollBoxListMixin.Event.OnUpdate, function()
        local scrollBox = LFGListFrame.ApplicationViewer.ScrollBox
        local frames = scrollBox:GetFrames()
        frames = scrollBox:GetFrames()

        for _, frame in ipairs(frames) do
            frame:HookScript("OnEnter", OnEnterApplicant)
            frame:HookScript("OnLeave", OnLeaveApplicant)
        end
    end)

    LFGListFrame.ApplicationViewer.ScrollBox:RegisterCallback(ScrollBoxListMixin.Event.OnScroll, function()
        GameTooltip:Hide()
    end)
end

function Dump(table, desc)
    Blacklist:Print(desc)
    DevTools_Dump(table)
end

TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit, TooltipCallback)