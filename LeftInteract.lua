local ADDON_NAME = "LeftInteract"
local ADDON_VERSION = "0.2.1"

LeftInteractDB = LeftInteractDB or {}

local controller = CreateFrame("Frame", "LeftInteractController")
local optionsFrame
local minimapButton
local active = false
local cursorHasItem = false
local cursorCheckElapsed = 0
local recaptureBindingsOnLogin = false
local BINDING_KEYS = { "BUTTON1", "BUTTON2", "SHIFT-BUTTON1", "SHIFT-BUTTON2" }

local function Print(message)
    DEFAULT_CHAT_FRAME:AddMessage("|cff62d8ffLeft Interact Vanilla:|r " .. message)
end

local function SetSessionBinding(key, action)
    if action and action ~= "" then
        return SetBinding(key, action)
    end
    return SetBinding(key)
end

local function CurrentBindingAction(key)
    return GetBindingAction(key) or ""
end

local function SetTrackedBinding(key, action)
    local normalizedAction = action or ""
    if not SetSessionBinding(key, normalizedAction) then
        return false
    end
    LeftInteractDB.appliedBindings = LeftInteractDB.appliedBindings or {}
    LeftInteractDB.appliedBindings[key] = normalizedAction
    return true
end

local function CaptureOriginalBindings()
    if LeftInteractDB.originalsCaptured and LeftInteractDB.originalBindings then
        return
    end

    LeftInteractDB.originalBindings = {}
    for _, key in ipairs(BINDING_KEYS) do
        LeftInteractDB.originalBindings[key] = GetBindingAction(key) or ""
    end
    LeftInteractDB.originalsCaptured = true
end

local function RestoreOriginalKeys(force)
    CaptureOriginalBindings()
    LeftInteractDB.appliedBindings = LeftInteractDB.appliedBindings or {}
    local restored = true
    local conflict = false
    for _, key in ipairs(BINDING_KEYS) do
        local expectedAction = LeftInteractDB.appliedBindings[key]
        local currentAction = CurrentBindingAction(key)
        if force or (expectedAction ~= nil and currentAction == expectedAction) then
            if not SetSessionBinding(key, LeftInteractDB.originalBindings[key]) then
                restored = false
            end
        elseif expectedAction ~= nil and currentAction ~= expectedAction then
            conflict = true
        end
        LeftInteractDB.appliedBindings[key] = nil
    end
    return restored, conflict
end

local function MovementName()
    if LeftInteractDB.movementMode == "independent" then
        return "Legacy MOVEFORWARD (shares W)"
    end
    return "W-compatible + seamless left hold"
end

local function ConfigSummary()
    local movement = LeftInteractDB.rightMove and MovementName() or "native right click"
    return "world interaction, " .. movement
end

local function RefreshOptions()
    if optionsFrame and optionsFrame.Refresh then
        optionsFrame:Refresh()
    end
end

local function ApplyBindings(silent)
    CaptureOriginalBindings()
    local restored, conflict = RestoreOriginalKeys(false)
    if not restored or conflict then
        active = false
        if not silent then
            if conflict then
                Print("A mouse binding changed after Left Interact applied it. The newer binding was preserved; use recover to force the recorded originals.")
            else
                Print("The client rejected a binding restore. Run /leftinteract recover or restart the client.")
            end
        end
        RefreshOptions()
        return false
    end

    cursorHasItem = CursorHasItem and CursorHasItem() and true or false
    local leftAction = "LEFTINTERACT_ACTION"
    if cursorHasItem then
        leftAction = LeftInteractDB.originalBindings.BUTTON1
    end

    local applied = SetTrackedBinding("BUTTON1", leftAction)
    if LeftInteractDB.rightMove then
        local movementAction = LeftInteractDB.movementMode == "combined" and "LEFTINTERACT_COMBINED" or "MOVEFORWARD"
        applied = SetTrackedBinding("BUTTON2", movementAction) and applied
        applied = SetTrackedBinding("SHIFT-BUTTON2", "TURNORACTION") and applied
    end
    applied = SetTrackedBinding("SHIFT-BUTTON1", "CAMERAORSELECTORMOVE") and applied

    if not applied then
        RestoreOriginalKeys(false)
        active = false
        if not silent then
            Print("The client rejected a session binding. Original bindings restored.")
        end
        RefreshOptions()
        return false
    end

    active = true
    if not silent then
        Print("Enabled - " .. ConfigSummary() .. ".")
    end
    RefreshOptions()
    return true
end

local function RemoveBindings(silent, force)
    local restored, conflict = RestoreOriginalKeys(force and true or false)
    active = false
    cursorHasItem = false
    if not silent then
        if conflict then
            Print("Disabled. A binding changed by another addon was preserved; other originals were restored.")
        elseif restored then
            Print("Disabled. Original mouse bindings restored.")
        else
            Print("A binding restore was rejected. Run /leftinteract recover or restart the client.")
        end
    end
    RefreshOptions()
    return restored and not conflict
end

local function SetEnabled(enabled, silent)
    local wasEnabled = LeftInteractDB.enabled and true or false
    if enabled and not wasEnabled then
        -- A deliberate re-enable happens after the previous originals were restored.
        -- Capture any binding changes the user made while the addon was disabled.
        LeftInteractDB.originalsCaptured = false
        LeftInteractDB.originalBindings = nil
    end

    LeftInteractDB.enabled = enabled and true or false
    if LeftInteractDB.enabled then
        ApplyBindings(silent)
    else
        RemoveBindings(silent)
    end
end

local function ShowStatus()
    if active then
        Print("Enabled - " .. ConfigSummary() .. ". Session bindings are active.")
    elseif LeftInteractDB.enabled then
        Print("Enabled in settings, but session bindings are not active.")
    else
        Print("Disabled - recorded original bindings are active.")
    end
end

local ToggleGUI
SLASH_LEFTINTERACT1 = "/leftinteract"
SLASH_LEFTINTERACT2 = "/li"
SlashCmdList.LEFTINTERACT = function(message)
    local _, _, command, argument = string.find(string.lower(message or ""), "^%s*(%S*)%s*(.-)%s*$")
    command = command or ""
    argument = argument or ""

    if command == "on" or command == "enable" then
        SetEnabled(true, false)
    elseif command == "off" or command == "disable" then
        SetEnabled(false, false)
    elseif command == "toggle" then
        SetEnabled(not LeftInteractDB.enabled, false)
    elseif command == "status" then
        ShowStatus()
    elseif command == "recover" or command == "restore" then
        LeftInteractDB.enabled = false
        RemoveBindings(false, true)
        Print("Recovery complete. Original mouse bindings restored; addon left disabled.")
    elseif command == "rightmove" then
        if argument == "on" then
            LeftInteractDB.rightMove = true
        elseif argument == "off" then
            LeftInteractDB.rightMove = false
        else
            Print("Usage: /leftinteract rightmove on|off")
            return
        end
        if LeftInteractDB.enabled then ApplyBindings(true) end
        Print("Right-click movement " .. (LeftInteractDB.rightMove and "enabled." or "disabled."))
    elseif command == "movement" or command == "move" then
        if argument == "combined" or argument == "w" or argument == "w-compatible" then
            LeftInteractDB.movementMode = "combined"
        elseif argument == "independent" or argument == "seamless" then
            LeftInteractDB.movementMode = "independent"
        else
            Print("Usage: /leftinteract movement combined|independent")
            return
        end
        LeftInteractDB.rightMove = true
        if LeftInteractDB.enabled then ApplyBindings(true) end
        Print("Movement mode: " .. MovementName() .. ".")
    elseif command == "gui" or command == "config" or command == "options" or command == "" then
        if ToggleGUI then ToggleGUI() end
    else
        Print("Commands: gui, on, off, toggle, status, recover, rightmove on/off, movement combined/independent")
    end
end

local function SetupEmptyClickDeselect()
    if not WorldFrame or WorldFrame.leftInteractDeselectHooked then
        return
    end
    WorldFrame.leftInteractDeselectHooked = true

    local leftDownTime
    local leftDownX
    local leftDownY
    local previousMouseDown = WorldFrame:GetScript("OnMouseDown")
    WorldFrame:SetScript("OnMouseDown", function()
        local button = arg1
        if previousMouseDown then previousMouseDown() end
        if button ~= "LeftButton" or not active or not LeftInteractDB.emptyClickDeselect then
            leftDownTime = nil
            return
        end
        if cursorHasItem or (CursorHasItem and CursorHasItem()) then
            leftDownTime = nil
            return
        end
        leftDownTime = GetTime()
        leftDownX, leftDownY = GetCursorPosition()
    end)

    local previousMouseUp = WorldFrame:GetScript("OnMouseUp")
    WorldFrame:SetScript("OnMouseUp", function()
        local button = arg1
        if previousMouseUp then previousMouseUp() end
        if button ~= "LeftButton" or not leftDownTime then
            return
        end

        local downTime, downX, downY = leftDownTime, leftDownX, leftDownY
        leftDownTime, leftDownX, leftDownY = nil, nil, nil
        if not active or not LeftInteractDB.emptyClickDeselect or cursorHasItem or (CursorHasItem and CursorHasItem()) then
            return
        end
        if UnitExists("mouseover") or not UnitExists("target") then
            return
        end

        local upX, upY = GetCursorPosition()
        local dx, dy = upX - downX, upY - downY
        if GetTime() - downTime > 0.28 or (dx * dx + dy * dy) > 64 then
            return
        end
        pcall(ClearTarget)
    end)
end

local function MakeLabel(parent, text, size)
    local label = parent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    if label.SetFont and size then
        label:SetFont("Fonts\\FRIZQT__.TTF", size)
    end
    label:SetText(text)
    return label
end

local CHANGELOG_TEXT = [[
UNRELEASED
CHANGED
- Enable short empty-world click deselection by default and migrate v0.2.1 settings once.

v0.2.1 - 2026-08-04
ADDED
- Use locally installed trusted FrameXML actions for seamless held-left steering with W-compatible right-click movement.
- Reapply saved settings on PLAYER_LOGIN after account keybindings finish loading.
- Recapture original mouse bindings once when upgrading from the early startup capture.
- Keep protected movement calls outside addon Lua and never call SaveBindings.

v0.1.0 - 2026-08-04
ADDED
- Fork the addon into a private Vanilla 1.12.1 port for Microbot.
- Target Interface 11200 and Vanilla frame callback semantics.
- Replace 3.3.5 override bindings with reversible session-only SetBinding changes.
- Never call SaveBindings and restore recorded mouse actions on disable or logout.
- Preserve newer mouse-binding changes made by another addon during normal disable or logout.
- Preserve original bindings across /reload and add /leftinteract recover.
- Support Microbot's patched MOVEANDSTEER and stock MOVEFORWARD movement modes.
- Restore native BUTTON1 while an inventory item is attached to the cursor.
- Replace the unavailable script-hook method with chained GetScript and SetScript handlers.
- Keep the settings and What's New pages while removing server-specific guidance.
]]

local function CreateChangelogPage(parent)
    local page = CreateFrame("Frame", "LeftInteractChangelogPage", parent)
    page:SetPoint("TOPLEFT", parent, "TOPLEFT", 12, -68)
    page:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -12, 12)
    page:SetFrameLevel(parent:GetFrameLevel() + 5)
    page:EnableMouse(true)

    local background = page:CreateTexture(nil, "BACKGROUND")
    background:SetTexture("Interface\\Buttons\\WHITE8X8")
    background:SetVertexColor(0.025, 0.03, 0.04, 1)
    background:SetAllPoints(page)

    local title = MakeLabel(page, "WHAT'S NEW", 18)
    title:SetTextColor(0.35, 0.85, 1)
    title:SetPoint("TOPLEFT", page, "TOPLEFT", 18, -18)

    local back = CreateFrame("Button", nil, page, "UIPanelButtonTemplate")
    back:SetWidth(135); back:SetHeight(28)
    back:SetPoint("TOPRIGHT", page, "TOPRIGHT", -18, -14)
    back:SetText("BACK TO SETTINGS")
    back:SetScript("OnClick", function() page:Hide() end)

    local scroll = CreateFrame("ScrollFrame", "LeftInteractChangelogScrollFrame", page, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", page, "TOPLEFT", 20, -58)
    scroll:SetPoint("BOTTOMRIGHT", page, "BOTTOMRIGHT", -38, 18)

    local scrollChild = CreateFrame("Frame", nil, scroll)
    scrollChild:SetWidth(390); scrollChild:SetHeight(520)
    scroll:SetScrollChild(scrollChild)

    local text = MakeLabel(scrollChild, CHANGELOG_TEXT, 12)
    text:SetTextColor(0.9, 0.92, 0.94)
    text:SetWidth(380)
    text:SetJustifyH("LEFT")
    text:SetJustifyV("TOP")
    text:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 0, 0)

    page:Hide()
    return page
end

local function CreateOptionsGUI()
    if optionsFrame then return end

    local frame = CreateFrame("Frame", "LeftInteractOptionsFrame", UIParent)
    frame:SetWidth(480); frame:SetHeight(560)
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, 20)
    frame:SetFrameStrata("DIALOG")
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function() this:StartMoving() end)
    frame:SetScript("OnDragStop", function() this:StopMovingOrSizing() end)
    frame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 }
    })
    frame:Hide()
    optionsFrame = frame
    table.insert(UISpecialFrames, "LeftInteractOptionsFrame")

    local header = frame:CreateTexture(nil, "BACKGROUND")
    header:SetTexture("Interface\\Buttons\\WHITE8X8")
    header:SetVertexColor(0.025, 0.11, 0.17, 0.96)
    header:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -12)
    header:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -12, -12)
    header:SetHeight(55)

    local title = MakeLabel(frame, "Left Interact Vanilla", 20)
    title:SetPoint("TOPLEFT", frame, "TOPLEFT", 24, -20)
    local subtitle = MakeLabel(frame, "Private Microbot 1.12.1 accessibility port", 12)
    subtitle:SetTextColor(0.55, 0.8, 1)
    subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
    local version = MakeLabel(frame, "v" .. ADDON_VERSION, 11)
    version:SetTextColor(0.55, 0.65, 0.7)
    version:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -48, -31)

    local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -5, -5)

    local enabled = CreateFrame("CheckButton", nil, frame, "UICheckButtonTemplate")
    enabled:SetPoint("TOPLEFT", frame, "TOPLEFT", 24, -76)
    local enabledText = MakeLabel(frame, "Enable Left Interact", 14)
    enabledText:SetPoint("LEFT", enabled, "RIGHT", 4, 1)
    enabled:SetScript("OnClick", function()
        SetEnabled(this:GetChecked() and true or false, false)
        frame:Refresh()
    end)
    frame.enabledCheck = enabled

    local whatsNew = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    whatsNew:SetWidth(110); whatsNew:SetHeight(26)
    whatsNew:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -24, -76)
    whatsNew:SetText("WHAT'S NEW")
    whatsNew:SetScript("OnClick", function() frame.changelogPage:Show() end)

    local movementCard = frame:CreateTexture(nil, "BACKGROUND")
    movementCard:SetTexture("Interface\\Buttons\\WHITE8X8")
    movementCard:SetVertexColor(0.06, 0.075, 0.09, 0.88)
    movementCard:SetPoint("TOPLEFT", frame, "TOPLEFT", 18, -112)
    movementCard:SetPoint("BOTTOMRIGHT", frame, "TOPRIGHT", -18, -244)

    local moveTitle = MakeLabel(frame, "MOVEMENT", 13)
    moveTitle:SetTextColor(0.3, 0.8, 1)
    moveTitle:SetPoint("TOPLEFT", frame, "TOPLEFT", 30, -124)

    local combined = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    combined:SetWidth(198); combined:SetHeight(28)
    combined:SetPoint("TOPLEFT", moveTitle, "BOTTOMLEFT", 0, -10)
    combined:SetScript("OnClick", function()
        LeftInteractDB.movementMode = "combined"
        LeftInteractDB.rightMove = true
        if LeftInteractDB.enabled then ApplyBindings(true) end
        frame:Refresh()
    end)
    frame.combinedButton = combined

    local independent = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    independent:SetWidth(198); independent:SetHeight(28)
    independent:SetPoint("LEFT", combined, "RIGHT", 12, 0)
    independent:SetScript("OnClick", function()
        LeftInteractDB.movementMode = "independent"
        LeftInteractDB.rightMove = true
        if LeftInteractDB.enabled then ApplyBindings(true) end
        frame:Refresh()
    end)
    frame.independentButton = independent

    local rightMove = CreateFrame("CheckButton", nil, frame, "UICheckButtonTemplate")
    rightMove:SetPoint("TOPLEFT", combined, "BOTTOMLEFT", 0, -8)
    local rightMoveText = MakeLabel(frame, "Use right click for movement", 13)
    rightMoveText:SetPoint("LEFT", rightMove, "RIGHT", 4, 1)
    rightMove:SetScript("OnClick", function()
        LeftInteractDB.rightMove = this:GetChecked() and true or false
        if LeftInteractDB.enabled then ApplyBindings(true) end
        frame:Refresh()
    end)
    frame.rightMoveCheck = rightMove

    local movementHelp = MakeLabel(frame, "", 11)
    movementHelp:SetTextColor(0.65, 0.7, 0.74)
    movementHelp:SetWidth(400)
    movementHelp:SetJustifyH("LEFT")
    movementHelp:SetPoint("TOPLEFT", rightMove, "BOTTOMLEFT", 3, -3)
    frame.movementHelp = movementHelp

    local interactionCard = frame:CreateTexture(nil, "BACKGROUND")
    interactionCard:SetTexture("Interface\\Buttons\\WHITE8X8")
    interactionCard:SetVertexColor(0.06, 0.075, 0.09, 0.88)
    interactionCard:SetPoint("TOPLEFT", frame, "TOPLEFT", 18, -252)
    interactionCard:SetPoint("BOTTOMRIGHT", frame, "TOPRIGHT", -18, -336)

    local interactTitle = MakeLabel(frame, "INTERACTION", 13)
    interactTitle:SetTextColor(0.3, 0.8, 1)
    interactTitle:SetPoint("TOPLEFT", frame, "TOPLEFT", 30, -264)
    local interactText = MakeLabel(frame, "Left click: NPCs, loot, gathering and world objects. Shift + left: native selection and camera.", 11)
    interactText:SetTextColor(0.85, 0.88, 0.9)
    interactText:SetWidth(410)
    interactText:SetJustifyH("LEFT")
    interactText:SetPoint("TOPLEFT", interactTitle, "BOTTOMLEFT", 0, -6)

    local deselect = CreateFrame("CheckButton", nil, frame, "UICheckButtonTemplate")
    deselect:SetPoint("TOPLEFT", interactText, "BOTTOMLEFT", -4, -5)
    local deselectText = MakeLabel(frame, "Short empty click clears target (experimental)", 11)
    deselectText:SetPoint("LEFT", deselect, "RIGHT", 4, 1)
    deselect:SetScript("OnClick", function()
        LeftInteractDB.emptyClickDeselect = this:GetChecked() and true or false
        frame:Refresh()
    end)
    frame.deselectCheck = deselect

    local safetyCard = frame:CreateTexture(nil, "BACKGROUND")
    safetyCard:SetTexture("Interface\\Buttons\\WHITE8X8")
    safetyCard:SetVertexColor(0.11, 0.075, 0.035, 0.94)
    safetyCard:SetPoint("TOPLEFT", frame, "TOPLEFT", 18, -344)
    safetyCard:SetPoint("BOTTOMRIGHT", frame, "TOPRIGHT", -18, -480)

    local safetyTitle = MakeLabel(frame, "VANILLA BINDING SAFETY", 13)
    safetyTitle:SetTextColor(1, 0.75, 0.2)
    safetyTitle:SetPoint("TOPLEFT", frame, "TOPLEFT", 30, -356)
    local safetyText = MakeLabel(frame, "Vanilla has no temporary override API. This build changes only the current session, never saves bindings, and restores your recorded mouse actions when disabled or at logout.", 11)
    safetyText:SetTextColor(0.9, 0.9, 0.9)
    safetyText:SetWidth(410)
    safetyText:SetJustifyH("LEFT")
    safetyText:SetPoint("TOPLEFT", safetyTitle, "BOTTOMLEFT", 0, -6)

    local recover = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    recover:SetWidth(150); recover:SetHeight(28)
    recover:SetPoint("TOPLEFT", safetyText, "BOTTOMLEFT", 0, -8)
    recover:SetText("RESTORE ORIGINALS")
    recover:SetScript("OnClick", function()
        LeftInteractDB.enabled = false
        RemoveBindings(false, true)
        Print("Recovery complete. Original mouse bindings restored; addon left disabled.")
        frame:Refresh()
    end)
    local recoveryHelp = MakeLabel(frame, "Emergency: /leftinteract recover", 11)
    recoveryHelp:SetTextColor(0.7, 0.75, 0.78)
    recoveryHelp:SetPoint("LEFT", recover, "RIGHT", 10, 0)

    local hint = MakeLabel(frame, "Item drag: native. Shift + left: selection and camera.", 11)
    hint:SetTextColor(0.7, 0.7, 0.7)
    hint:SetPoint("BOTTOM", frame, "BOTTOM", 0, 49)
    local status = MakeLabel(frame, "", 11)
    status:SetWidth(440)
    status:SetJustifyH("CENTER")
    status:SetPoint("BOTTOM", frame, "BOTTOM", 0, 20)
    frame.statusText = status

    function frame:Refresh()
        self.enabledCheck:SetChecked(LeftInteractDB.enabled and true or false)
        self.rightMoveCheck:SetChecked(LeftInteractDB.rightMove and true or false)
        self.deselectCheck:SetChecked(LeftInteractDB.emptyClickDeselect and true or false)
        local combinedSelected = LeftInteractDB.movementMode == "combined"
        local independentSelected = LeftInteractDB.movementMode == "independent"
        self.combinedButton:SetText(combinedSelected and ">  W-compatible + seamless" or "W-compatible + seamless")
        self.independentButton:SetText(independentSelected and ">  Legacy MOVEFORWARD" or "Legacy MOVEFORWARD")
        if combinedSelected then self.combinedButton:LockHighlight() else self.combinedButton:UnlockHighlight() end
        if independentSelected then self.independentButton:LockHighlight() else self.independentButton:UnlockHighlight() end
        if independentSelected then
            self.movementHelp:SetText("Legacy fallback: right click can be re-pressed, but it shares movement state with W.")
        else
            self.movementHelp:SetText("Default: W stays independent and held-left steering resumes after right release.")
        end
        if active then
            self.statusText:SetText("Enabled - " .. ConfigSummary())
            self.statusText:SetTextColor(0.35, 1, 0.35)
        else
            self.statusText:SetText("Disabled - recorded original bindings active")
            self.statusText:SetTextColor(1, 0.45, 0.35)
        end
    end

    frame.changelogPage = CreateChangelogPage(frame)
    frame:SetScript("OnShow", function() frame:Refresh() end)
end

local function UpdateMinimapButtonPosition()
    if not minimapButton then return end
    local angle = math.rad(LeftInteractDB.minimapAngle or 220)
    minimapButton:ClearAllPoints()
    minimapButton:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * 80, math.sin(angle) * 80)
end

local function CreateMinimapButton()
    if minimapButton or not Minimap then return end
    local button = CreateFrame("Button", "LeftInteractMinimapButton", Minimap)
    button:SetWidth(32); button:SetHeight(32)
    button:SetFrameStrata("MEDIUM"); button:SetFrameLevel(8)
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    button:RegisterForDrag("LeftButton")

    local icon = button:CreateTexture(nil, "BACKGROUND")
    icon:SetTexture("Interface\\Icons\\Ability_Rogue_Sprint")
    icon:SetWidth(22); icon:SetHeight(22)
    icon:SetPoint("CENTER", button, "CENTER", 0, 0)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    local border = button:CreateTexture(nil, "OVERLAY")
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    border:SetWidth(54); border:SetHeight(54)
    border:SetPoint("TOPLEFT", button, "TOPLEFT", 0, 0)
    button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

    button:SetScript("OnClick", function()
        if arg1 == "RightButton" then
            SetEnabled(not LeftInteractDB.enabled, false)
        else
            ToggleGUI()
        end
    end)
    button:SetScript("OnEnter", function()
        GameTooltip:SetOwner(this, "ANCHOR_LEFT")
        GameTooltip:AddLine("Left Interact Vanilla", 0.4, 0.85, 1)
        GameTooltip:AddLine("Left click: Open settings", 1, 1, 1)
        GameTooltip:AddLine("Right click: Enable or disable", 1, 1, 1)
        GameTooltip:AddLine("Drag: Move this button", 0.7, 0.7, 0.7)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function() GameTooltip:Hide() end)
    button:SetScript("OnDragStart", function()
        button:SetScript("OnUpdate", function()
            local mx, my = Minimap:GetCenter()
            local px, py = GetCursorPosition()
            local scale = UIParent:GetEffectiveScale()
            px, py = px / scale, py / scale
            LeftInteractDB.minimapAngle = math.deg(math.atan2(py - my, px - mx))
            UpdateMinimapButtonPosition()
        end)
    end)
    button:SetScript("OnDragStop", function() button:SetScript("OnUpdate", nil) end)

    minimapButton = button
    UpdateMinimapButtonPosition()
end

ToggleGUI = function()
    CreateOptionsGUI()
    if optionsFrame:IsShown() then optionsFrame:Hide() else optionsFrame:Show() end
end

controller:RegisterEvent("ADDON_LOADED")
controller:RegisterEvent("PLAYER_LOGIN")
controller:RegisterEvent("PLAYER_LOGOUT")
controller:SetScript("OnEvent", function()
    if event == "ADDON_LOADED" then
        if arg1 ~= ADDON_NAME then return end

        local firstRun = next(LeftInteractDB) == nil
        local savedSettingsVersion = tonumber(LeftInteractDB.settingsVersion) or 0
        if LeftInteractDB.enabled == nil then LeftInteractDB.enabled = true end
        if LeftInteractDB.rightMove == nil then LeftInteractDB.rightMove = true end
        if LeftInteractDB.emptyClickDeselect == nil or savedSettingsVersion < 102 then
            LeftInteractDB.emptyClickDeselect = true
        end
        if firstRun then
            LeftInteractDB.movementMode = "combined"
        elseif LeftInteractDB.movementMode ~= "independent" and LeftInteractDB.movementMode ~= "combined" then
            LeftInteractDB.movementMode = "combined"
        end
        recaptureBindingsOnLogin = savedSettingsVersion < 101
        if savedSettingsVersion < 102 then
            LeftInteractDB.settingsVersion = 102
        end

        CreateOptionsGUI()
        CreateMinimapButton()
        SetupEmptyClickDeselect()
        controller:UnregisterEvent("ADDON_LOADED")
    elseif event == "PLAYER_LOGIN" then
        if recaptureBindingsOnLogin then
            LeftInteractDB.originalsCaptured = false
            LeftInteractDB.originalBindings = nil
            LeftInteractDB.appliedBindings = {}
            recaptureBindingsOnLogin = false
        end
        if LeftInteractDB.enabled then ApplyBindings(false) else RestoreOriginalKeys(false) end
        controller:UnregisterEvent("PLAYER_LOGIN")
    elseif event == "PLAYER_LOGOUT" then
        RestoreOriginalKeys(false)
        active = false
    end
end)

controller:SetScript("OnUpdate", function()
    if not active then return end
    cursorCheckElapsed = cursorCheckElapsed + (arg1 or 0)
    if cursorCheckElapsed < 0.05 then return end
    cursorCheckElapsed = 0

    local hasItem = CursorHasItem and CursorHasItem() and true or false
    if hasItem ~= cursorHasItem then
        ApplyBindings(true)
    end
end)
