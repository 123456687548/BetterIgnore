local Blacklist = LibStub("AceAddon-3.0"):NewAddon("MyAddon", "AceConsole-3.0", "AceHook-3.0")

local _G = _G
local UIParent = UIParent
local UIDROPDOWNMENU_MAXBUTTONS = UIDROPDOWNMENU_MAXBUTTONS

local PredefinedType = {
    BLACKLIST = {
        name = "Blacklist",
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
            Blacklist:addToBlacklist(frame)
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

            return false
        end
    },
}

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

function Blacklist:addToBlacklist(frame)
    if not self.db.global.blacklist then
        self.db.global.blacklist = {}
    end

    --todo: frame.which alle möglichkeiten abdecken
    local key
    if frame.unit then
        key = self:getUnitNameAndRealmFromTarget(frame.unit)
    end

    if frame.chatTarget and not key then
        key = frame.chatTarget
    end

    if not key then
        Blacklist:Print("CAN'T CREATE KEY")
        Dump(frame)
        return
    end

    if self.db.global.blacklist[key] then
        Blacklist:Print("UNIT ALREADY BLACKLISTED")
        Dump(frame)
        return
    end

    Blacklist:Print("Adding to Blacklist: "..key)
    Dump(frame)

    self.db.global.blacklist[key] = {
        date = date("%Y.%m.%d %H:%M:%S"),
        reason = "NONE",
    }
end

function Blacklist:isBlacklisted(key)
    return self.db.global.blacklist[key] ~= nil
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
    --local r, g, b = unpack(E.media.rgbvaluecolor)
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

function Blacklist:CreateMenu()
    if self.menu then
        return
    end

    local frame = CreateFrame("Button", "WTContextMenu", UIParent, "UIDropDownListTemplate")
    --self:SkinDropDownList(frame)
    frame:Hide()

    frame:SetScript("OnShow", ContextMenu_OnShow)
    frame:SetScript("OnHide", nil)
    frame:SetScript("OnClick", nil)
    frame:SetScript("OnUpdate", nil)

    frame.buttons = {}

    for i = 1, 2 do--UIDROPDOWNMENU_MAXBUTTONS do
        local button = _G["WTContextMenuButton" .. i]
        if not button then
            button = CreateFrame("Button", "WTContextMenuButton" .. i, frame, "UIDropDownMenuButtonTemplate")
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

function Blacklist:ShowMenu(frame)
    Blacklist:Print("ShowMenu")
    local dropdown = frame.dropdown

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
    Dump(dropdown)
    if self.cache.which then
        if self:DisplayButtons() then
            self.menu:SetParent(frame)
            self.menu:SetFrameStrata(frame:GetFrameStrata())
            self.menu:SetFrameLevel(frame:GetFrameLevel() + 2)

            local menuHeight = ContextMenu_OnShow(self.menu)
            frame:SetHeight(frame:GetHeight() + menuHeight)

            self.menu:ClearAllPoints()
            local offset = -16

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

local function TooltipCallback(self)
    --Blacklist:Print("TooltipCallback")
    local _, unit = self:GetUnit()
    if not unit or not UnitIsPlayer(unit) then
        return
    end

    local key = Blacklist:getUnitNameAndRealmFromTarget(unit)
    --Blacklist:Print(key)

    self:AddLine("Test")
    self:AddLine(key)

    if Blacklist:isBlacklisted(key) then
        self:AddLine("Player is Blacklisted!")
    end

    self:Show()
end

local function SetSearchEntry(tooltip, resultID, _)
    local entry = C_LFGList.GetSearchResultInfo(resultID)
    local leaderName = Blacklist:getLeaderNameAndServerFromName(entry.leaderName)

    if Blacklist:isBlacklisted(leaderName) then
        tooltip:AddLine("Player is Blacklisted!")
    end
    tooltip:AddLine("test")

    tooltip:Show()
end

local function OnLFGListSearchEntryUpdate(self)
    local searchResultInfo = C_LFGList.GetSearchResultInfo(self.resultID)
    local leaderName = Blacklist:getLeaderNameAndServerFromName(searchResultInfo.leaderName)

    if Blacklist:isBlacklisted(leaderName) then
        self.Name:SetTextColor(255, 0, 0)
    end
end

local function test(member, appID, memberIdx, status, pendingStatus)
    Blacklist:Print("LFGListApplicationViewer_UpdateApplicantMember")
	local name = C_LFGList.GetApplicantMemberInfo(appID, memberIdx);
    Blacklist:Print(name)
    local applicantName = Blacklist:getLeaderNameAndServerFromName(name)
    if Blacklist:isBlacklisted(applicantName) then
        member.Name:SetTextColor(255, 0, 0)
        member.Name:SetText("[B] "..name)
    end
end

function Blacklist:OnInitialize()
    self.db = LibStub("AceDB-3.0"):New("BlacklistDB")
    self.cache = {}

    self:CreateMenu()
    self:UpdateMenu()
    self:SecureHookScript(_G.DropDownList1, "OnShow", "ShowMenu")
    self:SecureHookScript(_G.DropDownList1, "OnHide", "CloseMenu")

    self.tempButton = CreateFrame("Button", "WTContextMenuTempButton", UIParent, "SecureActionButtonTemplate")
    self.tempButton:SetAttribute("type1", "macro")

    hooksecurefunc("LFGListUtil_SetSearchEntryTooltip", SetSearchEntry)
    --hooksecurefunc(FriendsTooltip, "Show", TooltipCallback) eigener callback
    hooksecurefunc("LFGListSearchEntry_Update", OnLFGListSearchEntryUpdate)
    hooksecurefunc("LFGListApplicationViewer_UpdateApplicantMember", test)
end

function Dump(tbl)
    Blacklist:Print()
    DevTools_Dump(tbl)
end

TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit, TooltipCallback)