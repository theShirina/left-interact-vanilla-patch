-- Vanilla 1.12 binding-safety regression harness.
-- Run each scenario in a fresh Lua process.

local scenario = arg and arg[1] or "fresh-session"
local nativeBindings = {
    BUTTON1 = "CAMERAORSELECTORMOVE",
    BUTTON2 = "TURNORACTION",
}
local bindingActions = {}
for key, action in pairs(nativeBindings) do bindingActions[key] = action end
if scenario == "startup-reapply" or scenario == "startup-migration-100" then
    bindingActions = {}
end

local savedOriginals = {
    BUTTON1 = "CAMERAORSELECTORMOVE",
    BUTTON2 = "TURNORACTION",
    ["SHIFT-BUTTON1"] = "",
    ["SHIFT-BUTTON2"] = "",
}

if scenario == "reload-existing" then
    LeftInteractDB = {
        enabled = true,
        mode = "action",
        rightMove = true,
        movementMode = "combined",
        settingsVersion = 101,
        originalBindings = savedOriginals,
        originalsCaptured = true,
    }
    bindingActions.BUTTON1 = "LEFTINTERACT_ACTION"
    bindingActions.BUTTON2 = "LEFTINTERACT_COMBINED"
    bindingActions["SHIFT-BUTTON1"] = "CAMERAORSELECTORMOVE"
    bindingActions["SHIFT-BUTTON2"] = "TURNORACTION"
elseif scenario == "independent-movement" then
    LeftInteractDB = {
        enabled = true,
        mode = "action",
        rightMove = true,
        movementMode = "independent",
    }
elseif scenario == "startup-migration-100" then
    LeftInteractDB = {
        enabled = true,
        rightMove = true,
        movementMode = "combined",
        settingsVersion = 100,
        originalsCaptured = true,
        originalBindings = { BUTTON1 = "", BUTTON2 = "", ["SHIFT-BUTTON1"] = "", ["SHIFT-BUTTON2"] = "" },
        appliedBindings = { BUTTON1 = "TURNORACTION", BUTTON2 = "MOVEANDSTEER" },
    }
elseif scenario == "empty-click-migration-101" then
    LeftInteractDB = {
        enabled = true,
        rightMove = true,
        movementMode = "combined",
        settingsVersion = 101,
        emptyClickDeselect = false,
        originalsCaptured = true,
        originalBindings = savedOriginals,
        appliedBindings = {},
    }
elseif scenario == "future-settings-version" then
    LeftInteractDB = {
        enabled = true,
        rightMove = true,
        movementMode = "combined",
        settingsVersion = 102,
        originalsCaptured = true,
        originalBindings = savedOriginals,
        appliedBindings = {},
    }
else
    LeftInteractDB = {}
end

local controller
local cursorItem = false
local saveBindingsCalls = 0
local clearTargetCalls = 0
local targetExists = scenario == "empty-click-migration-101"
local createdFrames = {}
local namedFrames = {}
local widgetMethods = {}

function widgetMethods:SetText(text) rawset(self, "text", text) end
function widgetMethods:SetScript(name, handler)
    local scripts = rawget(self, "scripts")
    if not scripts then scripts = {}; rawset(self, "scripts", scripts) end
    scripts[name] = handler
end
function widgetMethods:GetScript(name)
    local scripts = rawget(self, "scripts")
    return scripts and scripts[name]
end
function widgetMethods:CreateFontString()
    local widget = setmetatable({ shown = true }, { __index = widgetMethods })
    table.insert(createdFrames, widget)
    return widget
end
function widgetMethods:CreateTexture()
    return setmetatable({}, { __index = widgetMethods })
end
function widgetMethods:GetCenter() return 0, 0 end
function widgetMethods:GetEffectiveScale() return 1 end
function widgetMethods:GetFrameLevel() return 1 end
function widgetMethods:IsShown() return rawget(self, "shown") and true or false end
function widgetMethods:Show() rawset(self, "shown", true) end
function widgetMethods:Hide() rawset(self, "shown", false) end
function widgetMethods:GetChecked() return false end
setmetatable(widgetMethods, {
    __index = function(_, key)
        local fn = function() end
        rawset(widgetMethods, key, fn)
        return fn
    end,
})

local function NewWidget()
    return setmetatable({ shown = true }, { __index = widgetMethods })
end

function CreateFrame(_, name)
    local frame = NewWidget()
    table.insert(createdFrames, frame)
    if name then namedFrames[name] = frame end
    if name == "LeftInteractController" then controller = frame end
    return frame
end

DEFAULT_CHAT_FRAME = { AddMessage = function() end }
GameTooltip = NewWidget()
UIParent = NewWidget()
Minimap = NewWidget()
WorldFrame = NewWidget()
SlashCmdList = {}
UISpecialFrames = {}

local originalMouseDownCalled = false
if scenario == "empty-click-hooks" or scenario == "empty-click-migration-101" then
    WorldFrame.leftInteractDeselectHooked = false
    if scenario == "empty-click-hooks" then
        WorldFrame:SetScript("OnMouseDown", function() originalMouseDownCalled = true end)
    end
    WorldFrame.HookScript = false
end

function GetBindingAction(key) return bindingActions[key] or "" end
function SetBinding(key, action)
    if action and action ~= "" then bindingActions[key] = action else bindingActions[key] = nil end
    return true
end
function SaveBindings()
    saveBindingsCalls = saveBindingsCalls + 1
    error("Left Interact Vanilla must never persist binding changes")
end
function LoadBindings() error("Left Interact Vanilla must not replace the current binding set") end
function CursorHasItem() return cursorItem end
function GetCursorPosition() return 0, 0 end
function GetTime() return 0 end
function UnitExists(unit)
    if unit == "target" then return targetExists end
    return false
end
function ClearTarget()
    clearTargetCalls = clearTargetCalls + 1
    targetExists = false
end
function GetAddOnMetadata(_, field) if field == "Version" then return "stale" end end

local function FireEvent(name, firstArg)
    event = name
    arg1 = firstArg
    this = controller
    controller.scripts.OnEvent()
    event, arg1, this = nil, nil, nil
end

local function FireUpdate(elapsed)
    arg1 = elapsed
    this = controller
    controller.scripts.OnUpdate()
    arg1, this = nil, nil
end

local function AssertOriginalsRestored(context)
    assert(bindingActions.BUTTON1 == nativeBindings.BUTTON1, context .. ": BUTTON1 not restored")
    assert(bindingActions.BUTTON2 == nativeBindings.BUTTON2, context .. ": BUTTON2 not restored")
    assert(bindingActions["SHIFT-BUTTON1"] == nil, context .. ": SHIFT-BUTTON1 not restored")
    assert(bindingActions["SHIFT-BUTTON2"] == nil, context .. ": SHIFT-BUTTON2 not restored")
end

dofile("LeftInteract.lua")
assert(controller and controller.scripts and controller.scripts.OnEvent, "controller OnEvent handler missing")
FireEvent("ADDON_LOADED", "LeftInteract")

if scenario == "startup-reapply" then
    assert(not LeftInteractDB.originalsCaptured, "startup captured bindings before PLAYER_LOGIN")
    for key, action in pairs(nativeBindings) do bindingActions[key] = action end
    FireEvent("PLAYER_LOGIN")
elseif scenario == "startup-migration-100" then
    assert(LeftInteractDB.originalBindings.BUTTON1 == "", "migration replaced the stale snapshot before PLAYER_LOGIN")
    for key, action in pairs(nativeBindings) do bindingActions[key] = action end
    FireEvent("PLAYER_LOGIN")
else
    FireEvent("PLAYER_LOGIN")
end

assert(saveBindingsCalls == 0, "addon called SaveBindings during load")
assert(LeftInteractDB.originalsCaptured == true, "original binding snapshot was not marked captured")
assert(LeftInteractDB.originalBindings.BUTTON1 == nativeBindings.BUTTON1, "original BUTTON1 was not preserved")
assert(LeftInteractDB.originalBindings.BUTTON2 == nativeBindings.BUTTON2, "original BUTTON2 was not preserved")
assert(bindingActions.BUTTON1 == "LEFTINTERACT_ACTION", "left interaction binding was not applied")
assert(bindingActions["SHIFT-BUTTON1"] == "CAMERAORSELECTORMOVE", "native left-click fallback missing")

if scenario == "fresh-session" then
    assert(bindingActions.BUTTON2 == "LEFTINTERACT_COMBINED", "fresh install must use the trusted W-compatible combined action")
    assert(bindingActions["SHIFT-BUTTON2"] == "TURNORACTION", "native right-click fallback missing")
elseif scenario == "startup-migration-100" then
    assert(LeftInteractDB.settingsVersion == 102, "v100 settings were not migrated")
    assert(LeftInteractDB.originalBindings.BUTTON1 == nativeBindings.BUTTON1, "migration did not replace stale BUTTON1")
    assert(LeftInteractDB.originalBindings.BUTTON2 == nativeBindings.BUTTON2, "migration did not replace stale BUTTON2")
elseif scenario == "future-settings-version" then
    assert(LeftInteractDB.settingsVersion == 102, "future settings version was downgraded")
elseif scenario == "reload-existing" then
    assert(LeftInteractDB.originalBindings.BUTTON1 == nativeBindings.BUTTON1, "reload overwrote saved original BUTTON1")
    assert(LeftInteractDB.originalBindings.BUTTON2 == nativeBindings.BUTTON2, "reload overwrote saved original BUTTON2")
elseif scenario == "independent-movement" then
    assert(bindingActions.BUTTON2 == "MOVEFORWARD", "independent movement must use MOVEFORWARD")
elseif scenario == "disable-restore" then
    SlashCmdList.LEFTINTERACT("off")
    AssertOriginalsRestored("disable")
    assert(LeftInteractDB.enabled == false, "disable did not update desired state")
elseif scenario == "external-change-preserved" then
    bindingActions.BUTTON2 = "EXTERNALACTION"
    SlashCmdList.LEFTINTERACT("off")
    assert(bindingActions.BUTTON1 == nativeBindings.BUTTON1, "owned BUTTON1 was not restored")
    assert(bindingActions.BUTTON2 == "EXTERNALACTION", "disable overwrote another addon's BUTTON2 change")
    assert(bindingActions["SHIFT-BUTTON1"] == nil, "owned SHIFT-BUTTON1 was not restored")
    assert(bindingActions["SHIFT-BUTTON2"] == nil, "owned SHIFT-BUTTON2 was not restored")
elseif scenario == "recover-originals" then
    SlashCmdList.LEFTINTERACT("recover")
    AssertOriginalsRestored("recover")
    assert(LeftInteractDB.enabled == false, "recover must leave the addon disabled")
elseif scenario == "logout-restore" then
    FireEvent("PLAYER_LOGOUT")
    AssertOriginalsRestored("logout")
    assert(LeftInteractDB.enabled == true, "logout restore must not disable the next session")
elseif scenario == "item-native-dispatch" then
    cursorItem = true
    FireUpdate(0.06)
    assert(bindingActions.BUTTON1 == nativeBindings.BUTTON1, "item cursor did not restore native BUTTON1")
    assert(bindingActions.BUTTON2 == "LEFTINTERACT_COMBINED", "item cursor should retain right movement")
    cursorItem = false
    FireUpdate(0.06)
    assert(bindingActions.BUTTON1 == "LEFTINTERACT_ACTION", "interaction binding did not return after item cleared")
elseif scenario == "changelog-page" then
    local whatsNew
    local correctVersion = false
    for _, frame in ipairs(createdFrames) do
        local scripts = rawget(frame, "scripts")
        if frame.text == "WHAT'S NEW" and scripts and scripts.OnClick then
            whatsNew = frame
        elseif frame.text == "v0.2.1" then
            correctVersion = true
        end
    end
    assert(correctVersion, "Vanilla GUI version is missing or stale")
    assert(whatsNew, "WHAT'S NEW button missing")
    whatsNew.scripts.OnClick()
    local page = namedFrames.LeftInteractChangelogPage
    assert(page and page:IsShown(), "changelog page did not open inside settings")
    local back
    for _, frame in ipairs(createdFrames) do
        local scripts = rawget(frame, "scripts")
        if frame.text == "BACK TO SETTINGS" and scripts and scripts.OnClick then back = frame; break end
    end
    assert(back, "BACK TO SETTINGS button missing")
    back.scripts.OnClick()
    assert(not page:IsShown(), "BACK TO SETTINGS did not close the changelog page")
elseif scenario == "empty-click-hooks" then
    assert(WorldFrame.scripts.OnMouseDown, "OnMouseDown handler was not installed")
    assert(WorldFrame.scripts.OnMouseUp, "OnMouseUp handler was not installed")
    this = WorldFrame
    arg1 = "LeftButton"
    WorldFrame.scripts.OnMouseDown()
    this, arg1 = nil, nil
    assert(originalMouseDownCalled, "existing WorldFrame OnMouseDown handler was not chained")
elseif scenario == "empty-click-migration-101" then
    assert(LeftInteractDB.settingsVersion == 102, "v101 settings were not migrated")
    assert(LeftInteractDB.emptyClickDeselect == true, "native-like empty-click deselection was not enabled")
    this = WorldFrame
    arg1 = "LeftButton"
    WorldFrame.scripts.OnMouseDown()
    WorldFrame.scripts.OnMouseUp()
    this, arg1 = nil, nil
    assert(clearTargetCalls == 1, "short empty click did not clear the target")
end

assert(saveBindingsCalls == 0, "addon called SaveBindings")
print(scenario .. ": PASS")
