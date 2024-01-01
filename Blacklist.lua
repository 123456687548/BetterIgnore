local Blacklist = LibStub("AceAddon-3.0"):NewAddon("Blacklist", "AceConsole-3.0", "AceHook-3.0", "AceComm-3.0", "AceSerializer-3.0")

local StaticPopup_Show = StaticPopup_Show

local COM_PREFIX = "BLACKLIST"
local COM_PREFIX_ASYNC = COM_PREFIX.."-AS"

local blacklist

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

local ContextBtnTypes = {
    BLACKLIST = {
        name = "Blacklist",
        color = "|cffff0000",
        unitTypes = {
            "PARTY",
            "PLAYER",
            "ENEMY_PLAYER",
            "RAID_PLAYER",
            "RAID",
            "FRIEND",
            "GUILD",
            "GUILD_OFFLINE",
            "CHAT_ROSTER",
            "TARGET",
            "ARENAENEMY",
            "FOCUS",
            "WORLD_STATE_SCORE",
            "COMMUNITIES_WOW_MEMBER",
            "COMMUNITIES_GUILD_MEMBER",
            "RAF_RECRUIT",
        },
        func = function(self)
            local button = self.value;
            if ( button == "Blacklist" ) then
                local dropdownFrame = UIDROPDOWNMENU_INIT_MENU
                local unit = dropdownFrame.unit
                local name = dropdownFrame.name
                local server = dropdownFrame.server
                local className,classFile,classID

                if not server then
                    server = GetRealmName()
                end
                
                local playerServerName = name.."-"..server

                StaticPopup_Show("BLACKLIST_REASON_POPUP", nil, nil, playerServerName)
            end
        end,
    },
    PARDON = {
        name = "Pardon",
        color = "|cff00ff00",
        unitTypes = {
            "PARTY",
            "PLAYER",
            "ENEMY_PLAYER",
            "RAID_PLAYER",
            "RAID",
            "FRIEND",
            "GUILD",
            "GUILD_OFFLINE",
            "CHAT_ROSTER",
            "TARGET",
            "ARENAENEMY",
            "FOCUS",
            "WORLD_STATE_SCORE",
            "COMMUNITIES_WOW_MEMBER",
            "COMMUNITIES_GUILD_MEMBER",
            "RAF_RECRUIT",
        },
        func = function(self)
            local button = self.value;
            if ( button == "Pardon" ) then
                local dropdownFrame = UIDROPDOWNMENU_INIT_MENU
                local unit = dropdownFrame.unit
                local name = dropdownFrame.name
                local server = dropdownFrame.server

                if not server then
                    server = GetRealmName()
                end
                
                local playerServerName = name.."-"..server

                Blacklist:removeFromBlacklist(playerServerName)
            end
        end,
    }
}

local function tableHasValues(table, value)
    for _, tableValue in ipairs(table) do
        if tableValue == value then
            return true
        end
    end
    return false
end

local function addContextBtn(which, btnType)
    local info = UIDropDownMenu_CreateInfo()
    info.text = btnType.name
    info.owner = which
    info.notCheckable = 1
    info.func = btnType.func
    info.colorCode = btnType.color
    info.value = btnType.name
    UIDropDownMenu_AddButton(info)
end

function OnUnitPopup_ShowMenu(dropdownMenu, which, unit, name, userData, ...)
    if UIDROPDOWNMENU_MENU_LEVEL > 1 then
        return
    end

    if not tableHasValues(ContextBtnTypes.BLACKLIST.unitTypes, which) then
        return
    end

    if not UnitIsPlayer(unit) then
        return
    end

    local ownName = UnitName("player")
    local realm = GetRealmName()
    if which == "FRIEND" and name == ownName.."-"..realm then
        return
    end

    local dropdownFrame = UIDROPDOWNMENU_INIT_MENU

    local unit = dropdownFrame.unit
    local name = dropdownFrame.name
    local server = dropdownFrame.server

    if not server then
        server = GetRealmName()
    end

    local playerServerName = name.."-"..server

    local blacklistInfo = Blacklist:isBlacklisted(playerServerName)
    if not blacklistInfo then
        addContextBtn(which, ContextBtnTypes.BLACKLIST)
    else
        addContextBtn(which, ContextBtnTypes.PARDON)
    end
end

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

function Blacklist:OnInitialize()
    self:RegisterComm(COM_PREFIX_ASYNC, Blacklist.OnCommReceivedAsync)

    self.db = LibStub("AceDB-3.0"):New("BlacklistDB")

    if not self.db.global.blacklist then
        self.db.global.blacklist = {}
    end

    blacklist = self.db.global.blacklist

    hooksecurefunc("UnitPopup_ShowMenu", OnUnitPopup_ShowMenu)
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