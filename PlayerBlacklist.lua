local BI = LibStub("AceAddon-3.0"):NewAddon("PlayerBlacklist", "AceConsole-3.0", "AceHook-3.0", "AceComm-3.0", "AceSerializer-3.0")

local L = LibStub("AceLocale-3.0"):GetLocale("PlayerBlacklist")

local StaticPopup_Show = StaticPopup_Show

local COM_PREFIX = "BLACKLIST"
local COM_PREFIX_ASYNC = COM_PREFIX.."-AS"

local blacklist

local function lStrFormat(key, ...)
    return string.format(L[key], ...)
end

StaticPopupDialogs["BLACKLIST_REASON_POPUP"] = {
	text = L["reasonPopupText"],
	button1 = L["saveBtn"],
	button2 = L["cancelBtn"],
	OnAccept = function(self, data, data2)
        local reason = self.editBox:GetText()
        BI:addToBlacklist(data, reason)
 	end,
	timeout = 0,
	whileDead = true,
	hideOnEscape = true,
    hasEditBox = true,
    enterClicksFirstButton = true
}

local ContextBtnTypes = {
    BLACKLIST = {
        name = L["blacklistBtn"],
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
            if ( button == L["blacklistBtn"] ) then
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
        name = L["pardonBtn"],
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
            if ( button == L["pardonBtn"] ) then
                local dropdownFrame = UIDROPDOWNMENU_INIT_MENU
                local unit = dropdownFrame.unit
                local name = dropdownFrame.name
                local server = dropdownFrame.server

                if not server then
                    server = GetRealmName()
                end
                
                local playerServerName = name.."-"..server

                BI:removeFromBlacklist(playerServerName)
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

    if which ~= "FRIEND" and not UnitIsPlayer(unit) then
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

    local blacklistInfo = BI:isBlacklisted(playerServerName)
    if not blacklistInfo then
        addContextBtn(which, ContextBtnTypes.BLACKLIST)
    else
        addContextBtn(which, ContextBtnTypes.PARDON)
    end
end

local asyncCounter = 1

function BI:sendMessage(msg, prefix)
    prefix = prefix or COM_PREFIX
    BI:SendCommMessage(prefix, BI:Serialize(msg), "RAID", nil)
end

function BI:sendAnswer(msg)
    BI:SendCommMessage(msg.prefix, BI:Serialize(msg.answer), msg.channel, msg.receiver)
end

function BI:createAskMessage(playerName, task)
    local prefix = COM_PREFIX_ASYNC..asyncCounter
    asyncCounter = asyncCounter + 1
    if asyncCounter > 9999 then
        asyncCounter = 1
    end
    return {
        ask = playerName,
        task = task,
        prefix = prefix,
        channel = "WHISPER",
        receiver = self:getUnitNameAndRealmFromTarget("player")
    }
end

function BI:buildNextMessageHandler(askMessage, callback)
    self:RegisterComm(askMessage.prefix, callback)
end

function BI:sendAskAsync(askMessage, callback)
    BI:buildNextMessageHandler(askMessage, callback)
    BI:SendCommMessage(COM_PREFIX_ASYNC, BI:Serialize(askMessage), "RAID", nil)
end

function BI:OnCommReceivedAsync(message, channel, sender) --(prefix, message, _, sender)
    local prefix = self
	if prefix ~= COM_PREFIX_ASYNC or not BI.Deserialize or sender == UnitName('player') then
        return
    end

    local success, msg = BI:Deserialize(message)

    if msg.task == "isBlacklisted" then
        local blacklistInfo = BI:isBlacklisted(msg.ask)
        
        if blacklistInfo then
            BI:sendAnswer({
                prefix = msg.prefix,
                answer = blacklistInfo,
                channel = msg.channel,
                receiver = msg.receiver
            })
        end
    end
end

function BI:getUnitNameAndRealmFromTarget(unit)
    local unitName, unitRealm = UnitName(unit)

    if not unitRealm then
        unitRealm = GetRealmName()
    end

    return unitName.."-"..unitRealm
end

function BI:getLeaderNameAndServerFromName(leaderName)
    if not string.find(leaderName, "-") then
        leaderName = leaderName.."-"..GetRealmName()
    end
    return leaderName
end

function BI:getPlayerNameFromFrame(frame)
    local playerName
    if frame.unit then
        playerName = self:getUnitNameAndRealmFromTarget(frame.unit)
    end

    if frame.chatTarget and not playerName then
        playerName = frame.chatTarget
    end

    if not playerName then
        Dump(frame, L["dbgCantCreateKey"])
        return nil
    end

    return playerName
end

function BI:addToBlacklist(playerName, reason)
    --todo: frame.which alle möglichkeiten abdecken
    
    if blacklist[playerName] then
        return
    end

    blacklist[playerName] = {
        date = date("%Y.%m.%d %H:%M:%S"),
        reason = reason,
    }

    BI:Print(lStrFormat("addedToBlacklist", playerName))
end

local function removeKeyFromTable(table, playerName)
    table[playerName] = nil
end

function BI:removeFromBlacklist(playerName)
    removeKeyFromTable(blacklist, playerName)
    BI:Print(lStrFormat("removedFromBlacklist", playerName))
end

function BI:isBlacklisted(playerName)
    return blacklist[playerName]
end

function BI:isBlacklistedRemote(askMessage, callback)
    BI:sendAskAsync(askMessage, callback)
end

local function remoteTooltipAdd(tooltip, playerName)
    if C_PvP.IsPVPMap() then
        return
    end

    local remoteBlocks = {}

    local askMessage = BI:createAskMessage(playerName, "isBlacklisted")
    BI:isBlacklistedRemote(askMessage, function(self, message, channel, sender)
        if askMessage.prefix ~= self or not BI.Deserialize or sender == UnitName('player') then
            return
        end

        local success, msg = BI:Deserialize(message)

        if remoteBlocks[playerName] and remoteBlocks[playerName][sender] then
            return
        end

        remoteBlocks[playerName] = {[sender] = true}

        tooltip:AddLine("-------------------------", 255, 0, 0)
        tooltip:AddLine(lStrFormat("blockedByTooltip", sender), 255, 0, 0)
        if msg.reason and msg.reason ~= "" then
            tooltip:AddLine(lStrFormat("reasonTooltip", msg.reason), 255, 0, 0)
        end
        if msg.date then
            tooltip:AddLine(lStrFormat("dateTooltip", msg.date), 255, 0, 0)
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

    local playerName = BI:getUnitNameAndRealmFromTarget(unit)

    local tooltip = self

    remoteTooltipAdd(tooltip, playerName)

    local blacklistInfo = BI:isBlacklisted(playerName)

    if blacklistInfo then
        tooltip:AddLine(L["isBlacklistedTooltip"], 255, 0, 0)
        if blacklistInfo.reason and blacklistInfo.reason ~= "" then
            tooltip:AddLine(lStrFormat("reasonTooltip", blacklistInfo.reason), 255, 0, 0)
        end
        if blacklistInfo.date then
            tooltip:AddLine(lStrFormat("dateTooltip", blacklistInfo.date), 255, 0, 0)
        end
    end

    tooltip:Show()
end

local function SetSearchEntry(tooltip, resultID, _)
    local entry = C_LFGList.GetSearchResultInfo(resultID)
    local leaderName = BI:getLeaderNameAndServerFromName(entry.leaderName)

    remoteTooltipAdd(tooltip, leaderName)

    local blacklistInfo = BI:isBlacklisted(leaderName)

    if blacklistInfo then
        tooltip:AddLine(L["isBlacklistedTooltip"], 255, 0, 0)
        if blacklistInfo.reason and blacklistInfo.reason ~= "" then
            tooltip:AddLine(string.format(L["reasonTooltip"], blacklistInfo.reason), 255, 0, 0)
        end
        if blacklistInfo.date then
            tooltip:AddLine(string.format(L["dateTooltip"], blacklistInfo.date), 255, 0, 0)
        end
        tooltip:Show()
    end
end

local function remoteTextChange(frame, playerName, originalName)
    if C_PvP.IsPVPMap() then
        return
    end
    
    local remoteBlocks = {}

    local askMessage = BI:createAskMessage(playerName, "isBlacklisted")
    BI:isBlacklistedRemote(askMessage, function(self, message, channel, sender)
        if askMessage.prefix ~= self or not BI.Deserialize or sender == UnitName('player') then
            return
        end

        local success, msg = BI:Deserialize(message)

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
        local leaderName = BI:getLeaderNameAndServerFromName(searchResultInfo.leaderName)

        remoteTextChange(self, leaderName, searchResultInfo.name)

        local blacklistInfo = BI:isBlacklisted(leaderName)

        if blacklistInfo then
            self.Name:SetText("[B] "..searchResultInfo.name)
            self.Name:SetTextColor(255, 0, 0)
        end
    end
end

local function OnUpdateApplicantMember(member, appID, memberIdx, status, pendingStatus)
	local name = C_LFGList.GetApplicantMemberInfo(appID, memberIdx);

    local applicantName = BI:getLeaderNameAndServerFromName(name)

    remoteTextChange(member, applicantName, name)

    local blacklistInfo = BI:isBlacklisted(applicantName)

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
        local applicantName = BI:getLeaderNameAndServerFromName(fullName)

        remoteTooltipAdd(GameTooltip, applicantName)

        local blacklistInfo = BI:isBlacklisted(applicantName)

        if blacklistInfo then
            GameTooltip:AddLine(L["isBlacklistedTooltip"], 255, 0, 0)
            if blacklistInfo.reason and blacklistInfo.reason ~= "" then
                GameTooltip:AddLine(lStrFormat("reasonTooltip", blacklistInfo.reason), 255, 0, 0)
            end
            if blacklistInfo.date then
                GameTooltip:AddLine(lStrFormat("dateTooltip", blacklistInfo.date), 255, 0, 0)
            end
            GameTooltip:Show()
        end
    end
end

function OnLeaveApplicant(self)
    GameTooltip:Hide()
end

function BI:OnInitialize()
    self:RegisterComm(COM_PREFIX_ASYNC, BI.OnCommReceivedAsync)

    self.db = LibStub("AceDB-3.0"):New("PlayerBlacklistDB")

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
    BI:Print(desc)
    DevTools_Dump(table)
end

TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit, TooltipCallback)