--local W, F, E, L = unpack((select(2, ...)))

local MyAddon = LibStub("AceAddon-3.0"):NewAddon("MyAddon", "AceConsole-3.0", "AceHook-3.0")

local _G = _G
local UIParent = UIParent
local UIDROPDOWNMENU_MAXBUTTONS = UIDROPDOWNMENU_MAXBUTTONS

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

function MyAddon:CreateMenu()
    if self.menu then
        return
    end

    local frame = CreateFrame("Button", "WTContextMenu", UIParent, "UIDropDownListTemplate")
    frame:Hide()

    frame:SetScript("OnShow", ContextMenu_OnShow)
    frame:SetScript("OnHide", nil)
    frame:SetScript("OnClick", nil)
    frame:SetScript("OnUpdate", nil)

    frame.buttons = {}

    for i = 1, UIDROPDOWNMENU_MAXBUTTONS do
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

        button:Hide()

        frame.buttons[i] = button
    end

    self.menu = frame
end

function MyAddon:UpdateMenu()
    local buttonIndex = 1

    self:UpdateButton(buttonIndex, {
        name = "test",
        supportTypes = {
            PARTY = true,
            PLAYER = true,
            RAID_PLAYER = true,
            FRIEND = true,
            BN_FRIEND = true,
            GUILD = true,
            CHAT_ROSTER = true,
            TARGET = true,
            FOCUS = true,
            COMMUNITIES_WOW_MEMBER = true,
            COMMUNITIES_GUILD_MEMBER = true,
            RAF_RECRUIT = true
        },
        isHidden = false,
        func = function(frame)
            MyAddon:Print("Clicked btn")
        end
    }, true)
    buttonIndex = buttonIndex + 1

    for i, button in pairs(self.menu.buttons) do
        if i >= buttonIndex then
            button:SetScript("OnClick", nil)
            button.Text:Hide()
            button.supportTypes = nil
        end
    end
end

function MyAddon:UpdateButton(index, config, closeAfterFunction)
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

function MyAddon:ShowMenu(frame)
    MyAddon:Print("ShowMenu")

    self.menu:SetParent(frame)
    self.menu:SetFrameStrata(frame:GetFrameStrata())
    self.menu:SetFrameLevel(frame:GetFrameLevel() + 2)

    local menuHeight = ContextMenu_OnShow(self.menu)
    frame:SetHeight(frame:GetHeight() + menuHeight)

    self.menu:ClearAllPoints()
    local offset = 16
    -- if C_AddOns_IsAddOnLoaded("RaiderIO") then
    --     for _, child in pairs {_G.DropDownList1:GetChildren()} do
    --         local name = child:IsShown() and child:GetName()
    --         if name and strfind(name, "^LibDropDownExtensionCustomDropDown") then
    --             offset = 47
    --         end
    --     end
    -- end

    self.menu:Point("BOTTOMLEFT", 0, offset)
    self.menu:Point("BOTTOMRIGHT", 0, offset)
    self.menu:Show()
end

function MyAddon:CloseMenu(frame)
    MyAddon:Print("CloseMenu")
end

function MyAddon:OnInitialize()
    MyAddon:Print("OnInitialize")
    MyAddon:Print(MyAddon)
    MyAddon:Print(self)
    MyAddon:Print(_G)
    
    self:CreateMenu()
    self:UpdateButton()
    self:SecureHookScript(_G.DropDownList1, "OnShow", "ShowMenu")
    self:SecureHookScript(_G.DropDownList1, "OnHide", "CloseMenu")
end

function MyAddon:OnEnable()
    MyAddon:Print("OnEnable")
end

function MyAddon:OnDisable()
    MyAddon:Print("OnDisable")
end