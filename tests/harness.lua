-- Mock WoW environment for ComboPointCounter. Not part of the addon (not listed in the .toc).
-- Usage, from the addon folder: luajit tests/harness.lua [addonDir]
local print = print -- tests replace the global print, keep the real one for reporting

local SCRIPT_DIR = arg[0]:match("^(.*)[/\\]") or "."
local ADDON_DIR = arg[1] or (SCRIPT_DIR .. "/..")

-- Load files in the same order the game does
local FILES = {}
for line in io.lines(ADDON_DIR .. "/ComboPointCounter.toc") do
    local file = line:match("^%s*([^#%s][^\r]-%.lua)%s*$")
    if file then
        FILES[#FILES + 1] = file
    end
end
assert(#FILES > 0, "no .lua files found in ComboPointCounter.toc")

local passed, failed = 0, 0
local function check(cond, msg)
    if cond then passed = passed + 1 else failed = failed + 1; print("  FAIL: " .. msg) end
end
local function approx(a, b) return math.abs(a - b) < 1e-6 end

-- Strict globals: reading an undefined global is an error (catches typos / removed APIs)
local ALLOWED_NIL = { ComboPointCounterDB = true }
setmetatable(_G, { __index = function(_, k)
    if ALLOWED_NIL[k] then return nil end
    error("read of undefined global '" .. tostring(k) .. "'", 2)
end })

local state

---------------------------------------------------------------- widgets
local Widget = {}
Widget.__index = function(self, k)
    local m = rawget(Widget, k)
    if m then return m end
    if type(k) == "string" and k:match("^[A-Z]") then
        return function() end -- any other API method is a no-op
    end
    return nil
end

local function NewWidget(kind, parent, template)
    local w = setmetatable({ kind = kind, parent = parent, scripts = {}, hooks = {}, events = {},
        unitEvents = {}, shown = true, text = "", checked = false, enabled = true,
        value = 0, min = 0, max = 1, points = {} }, Widget)
    state.widgets[#state.widgets + 1] = w
    if template == "MinimalSliderWithSteppersTemplate" then
        w.Slider, w.callbacks = NewWidget("Slider", w), {}
        w.Slider:SetScript("OnValueChanged", function(_, v)
            for _, cb in ipairs(w.callbacks) do cb.fn(cb.owner, v) end
        end)
    elseif template == "SettingsDropdownWithButtonsTemplate" then
        w.Dropdown = NewWidget("DropdownButton", w)
        w.DecrementButton, w.IncrementButton = NewWidget("Button", w), NewWidget("Button", w)
    end
    return w
end

function Widget:SetScript(name, fn) self.scripts[name] = fn end
function Widget:HookScript(name, fn) self.hooks[name] = fn end
function Widget:Fire(name, ...)
    if self.scripts[name] then self.scripts[name](self, ...) end
    if self.hooks[name] then self.hooks[name](self, ...) end
end
function Widget:RegisterEvent(e) self.events[e] = true end
function Widget:UnregisterEvent(e) self.events[e] = nil end
function Widget:RegisterUnitEvent(e, unit) self.events[e] = true; self.unitEvents[e] = unit end
function Widget:Show() self.shown = true end
function Widget:Hide() self.shown = false end
function Widget:SetShown(s) self.shown = not not s end
function Widget:IsShown() return self.shown end
function Widget:IsEnabled() return self.enabled end
function Widget:SetEnabled(e) self.enabled = e end
function Widget:SetText(t) self.text = tostring(t == nil and "" or t); if self.kind == "EditBox" then self:Fire("OnTextChanged", false) end end
function Widget:GetText() return self.text end
function Widget:SetChecked(c) self.checked = not not c end
function Widget:GetChecked() return self.checked end
function Widget:GetCursorPosition() return #self.text end
function Widget:EnableMouse(e) self.mouse = e end
-- EditBox focus: one box at a time, with the old box losing focus first
function Widget:HasFocus() return state.focus == self end
function Widget:SetFocus()
    if state.focus == self then return end
    if state.focus then state.focus:ClearFocus() end
    state.focus = self
    self:Fire("OnEditFocusGained")
end
function Widget:ClearFocus()
    if state.focus ~= self then return end
    state.focus = nil
    self:Fire("OnEditFocusLost")
end
function Widget:SetMinMaxValues(a, b) self.min, self.max = a, b end
function Widget:SetValue(v)
    local inner = rawget(self, "Slider")
    if inner then return inner:SetValue(v) end -- stepper frame forwards to its slider
    v = math.max(self.min, math.min(self.max, v))
    if v ~= self.value then self.value = v; self:Fire("OnValueChanged", v) end
end
function Widget:GetWidth() return 600 end
function Widget:GetTop() return 500 end
function Widget:GetBottom() return 100 end
function Widget:SetPoint(...) self.points[#self.points + 1] = { ... }; self.lastPoint = { ... } end
function Widget:ClearAllPoints() self.points = {} end
function Widget:GetPoint() return unpack(self.lastPoint or { "CENTER", nil, "CENTER", 0, 0 }) end
function Widget:SetColorTexture(r, g, b, a) self.color = { r, g, b, a } end
function Widget:SetTextColor(r, g, b, a) self.textColor = { r, g, b, a } end
function Widget:SetVertexColor(r, g, b, a) self.vertex = { r, g, b, a } end
function Widget:SetAtlas(a) self.atlas = a end
function Widget:SetSize(w, h) self.w, self.h = w, h end
function Widget:SetFont(f, s, fl) self.fontSize = s end
function Widget:GetFont() return "Fonts\\FRIZQT__.TTF", 16, "" end
function Widget:CreateTexture() return NewWidget("Texture", self) end
function Widget:CreateMaskTexture() return NewWidget("MaskTexture", self) end
function Widget:CreateFontString() return NewWidget("FontString", self) end
-- MinimalSliderWithSteppersTemplate
function Widget:Init(value, lo, hi) self.Slider:SetMinMaxValues(lo, hi); self.Slider:SetValue(value) end
function Widget:RegisterCallback(event, fn, owner) self.callbacks[#self.callbacks + 1] = { fn = fn, owner = owner } end
-- WowStyle1DropdownTemplate: GenerateMenu rebuilds the radios and shows the selected one's text
function Widget:SetupMenu(gen) self.menuGen = gen; self:GenerateMenu() end
function Widget:GenerateMenu()
    local radios = {}
    local root = { CreateRadio = function(_, text, isSelected, setSelected, data)
        radios[#radios + 1] = { text = text, isSelected = isSelected, setSelected = setSelected, data = data }
    end }
    self.menuGen(self, root)
    self.radios = radios
    for _, r in ipairs(radios) do if r.isSelected(r.data) then self.text = r.text end end
end

---------------------------------------------------------------- boot
local function Boot(class, db, opts)
    opts = opts or {}
    state = { widgets = {}, timers = {}, prints = {}, opened = {}, combat = false, lockdown = false,
        power = opts.power or 0, maxPower = opts.maxPower or 7, formID = opts.formID }

    rawset(_G, "ComboPointCounterDB", db)
    rawset(_G, "SlashCmdList", {})
    rawset(_G, "UnitClass", function() return class:lower(), class end)
    rawset(_G, "CreateFrame", function(kind, name, parent, template) return NewWidget(kind, parent, template) end)
    rawset(_G, "UIParent", NewWidget("Frame"))
    rawset(_G, "GameFontNormalLarge", NewWidget("Font"))
    rawset(_G, "CAT_FORM", 1)
    rawset(_G, "GetShapeshiftFormID", function() return state.formID end)
    rawset(_G, "UnitPower", function(unit, pt) assert(unit == "player" and pt == 4); return state.power end)
    rawset(_G, "UnitPowerMax", function(unit, pt) assert(unit == "player" and pt == 4); return state.maxPower end)
    rawset(_G, "Enum", { PowerType = { ComboPoints = 4 } })
    rawset(_G, "UnitAffectingCombat", function() return state.combat end)
    rawset(_G, "InCombatLockdown", function() return state.lockdown end)
    rawset(_G, "IsShiftKeyDown", function() return state.shift end)
    rawset(_G, "C_Timer", { After = function(_, fn) state.timers[#state.timers + 1] = fn end })
    rawset(_G, "C_AddOns", { GetAddOnMetadata = function(name, field) assert(name == "ComboPointCounter" and field == "Version"); return "1.3" end })
    rawset(_G, "Settings", {
        RegisterCanvasLayoutCategory = function(panel, name) return { GetID = function() return 42 end } end,
        RegisterAddOnCategory = function() end,
        OpenToCategory = function(id) state.opened[#state.opened + 1] = id end,
    })
    rawset(_G, "ScrollUtil", { InitScrollFrameWithScrollBar = function() end })
    rawset(_G, "MinimalSliderWithSteppersMixin", { Event = { OnValueChanged = "OnValueChanged" }, Label = { Right = 2 } })
    local picker = NewWidget("Frame")
    function picker:SetupColorPickerAndShow(info) self.info = info end
    function picker:GetColorRGB() return unpack(self.rgb) end
    function picker:GetColorAlpha() return self.alpha end
    rawset(_G, "ColorPickerFrame", picker)
    rawset(_G, "print", function(...) state.prints[#state.prints + 1] = table.concat({ ... }, " ") end)

    local ns = {}
    for _, f in ipairs(FILES) do
        local chunk = assert(loadfile(ADDON_DIR .. "/" .. f))
        chunk("ComboPointCounter", ns)
    end
    return ns
end

local function RunTimers()
    local n = #state.timers
    local t = state.timers
    state.timers = {}
    for _, fn in ipairs(t) do fn() end
    return n
end

local function FireEvent(frame, event, ...) frame.scripts.OnEvent(frame, event, ...) end

local function Find(pred)
    for _, w in ipairs(state.widgets) do if pred(w) then return w end end
end

local function Test(name, fn)
    print(name)
    local ok, err = xpcall(fn, debug.traceback)
    if not ok then failed = failed + 1; print("  ERROR: " .. err) end
end

---------------------------------------------------------------- tests
Test("Rogue, fresh install: defaults, events, initial state", function()
    local CPC = Boot("ROGUE", nil)
    local db = ComboPointCounterDB
    check(db.size == 25 and db.finisherThreshold == 6 and db.alwaysShow == false, "scalar defaults")
    check(db.textOffsets[0] == 0 and db.textOffsets[7] == 0 and db.textOffsets[8] == nil, "textOffsets 0..7")
    check(db.backgroundColor.a == 0.6 and db.borderTint.r == 1, "color defaults")
    check(db.backgroundColor ~= CPC.DEFAULTS.backgroundColor, "DB tables are copies, not aliases of DEFAULTS")
    check(db.borderAtlas == "ChallengeMode-KeystoneSlotFrameGlow", "default border atlas")
    local f = CPC.frame
    check(f.unitEvents.UNIT_POWER_UPDATE == "player", "UNIT_POWER_UPDATE registered for player only")
    check(f.events.PLAYER_REGEN_DISABLED and f.events.PLAYER_ENTERING_WORLD, "core events registered")
    check(not f.events.UPDATE_SHAPESHIFT_FORM, "rogue does not register shapeshift event")
    check(not f.shown, "hidden out of combat by default")
    check(SlashCmdList.COMBOPOINTCOUNTER and SLASH_COMBOPOINTCOUNTER1 == "/cpc", "slash command registered")
end)

Test("Combat flow: show, update, finisher colors, coalescing, hidden skip", function()
    local CPC = Boot("ROGUE", nil)
    local f = CPC.frame
    RunTimers()
    FireEvent(f, "UNIT_POWER_UPDATE", "player", "COMBO_POINTS")
    check(#state.timers == 0, "no update queued while hidden")

    state.combat = true
    FireEvent(f, "PLAYER_REGEN_DISABLED")
    check(f.shown, "shown on entering combat")
    check(RunTimers() == 1, "one update queued on show")

    local text = Find(function(w) return w.kind == "FontString" and w.parent == f end)
    local fill = Find(function(w) return w.kind == "Texture" and w.parent == f end)
    state.power = 3
    FireEvent(f, "UNIT_POWER_UPDATE", "player", "ENERGY")
    check(#state.timers == 0, "energy updates ignored")
    FireEvent(f, "UNIT_POWER_UPDATE", "player", "COMBO_POINTS")
    FireEvent(f, "UNIT_POWER_UPDATE", "player", "COMBO_POINTS")
    CPC.UpdateCounter()
    check(RunTimers() == 1, "multiple updates in one frame coalesce into one")
    check(text.text == "3", "text shows 3")
    check(approx(fill.color[4], 0.6) and approx(text.textColor[2], 0.82), "normal colors below threshold")

    state.power = 6
    FireEvent(f, "UNIT_POWER_UPDATE", "player", "COMBO_POINTS")
    RunTimers()
    check(text.text == "6", "text shows 6")
    check(approx(fill.color[1], 0.75) and approx(text.textColor[2], 1), "finisher colors at threshold")

    CPC.SetTextOffset(6, -2)
    RunTimers()
    check(text.lastPoint[4] == -2, "text offset applied")

    state.combat = false
    FireEvent(f, "PLAYER_REGEN_ENABLED")
    check(not f.shown, "hidden after combat")
    CPC.SetAlwaysShow(true)
    check(f.shown and ComboPointCounterDB.alwaysShow == true, "always show")
end)

Test("Existing saved variables are preserved", function()
    local CPC = Boot("ROGUE", {
        size = 40, alwaysShow = true, backgroundColor = { r = 1 }, textOffsets = { [3] = 5 },
        borderAtlas = "not-a-real-atlas", finisherThreshold = 4,
    })
    local db = ComboPointCounterDB
    check(db.size == 40 and db.alwaysShow == true and db.finisherThreshold == 4, "saved scalars kept")
    check(db.backgroundColor.r == 1 and db.backgroundColor.a == 0.6, "partial color merged")
    check(db.textOffsets[3] == 5 and db.textOffsets[0] == 0, "partial offsets merged")
    check(db.borderAtlas == "ChallengeMode-KeystoneSlotFrameGlow", "invalid atlas reset")
    check(CPC.frame.shown, "alwaysShow respected on load")
end)

Test("Force Number does not survive a reload", function()
    Boot("ROGUE", { debugValue = 3 })
    check(ComboPointCounterDB.debugValue == nil, "debugValue cleared on load")
end)

Test("Finisher threshold above max combo points still triggers at max", function()
    local CPC = Boot("DRUID", nil, { formID = 1, maxPower = 5 })
    local f = CPC.frame
    local fill = Find(function(w) return w.kind == "Texture" and w.parent == f end)
    state.combat = true
    state.power = 4
    FireEvent(f, "PLAYER_REGEN_DISABLED")
    RunTimers()
    check(approx(fill.color[4], 0.6), "4 of 5 points: normal background")
    state.power = 5
    FireEvent(f, "UNIT_POWER_UPDATE", "player", "COMBO_POINTS")
    RunTimers()
    check(approx(fill.color[1], 0.75), "5 of 5 points with threshold 6: finisher background")
end)

Test("Druid: only shown in cat form", function()
    local CPC = Boot("DRUID", nil)
    local f = CPC.frame
    check(f.events.UPDATE_SHAPESHIFT_FORM, "druid registers shapeshift event")
    state.combat = true
    FireEvent(f, "PLAYER_REGEN_DISABLED")
    check(not f.shown, "hidden in caster form (formID nil)")
    state.formID = 5
    FireEvent(f, "UPDATE_SHAPESHIFT_FORM")
    check(not f.shown, "hidden in bear form")
    state.formID = 1
    FireEvent(f, "UPDATE_SHAPESHIFT_FORM")
    check(f.shown, "shown in cat form")
end)

Test("Unsupported class loads nothing and errors nothing", function()
    local CPC = Boot("WARRIOR", nil)
    check(CPC.frame == nil and CPC.OptionsPanel == nil, "no frame or panel")
    check(SlashCmdList.COMBOPOINTCOUNTER == nil, "no slash command")
end)

Test("Options panel: refresh, out-of-range size not clobbered, controls", function()
    local CPC = Boot("ROGUE", { size = 200 })
    local panel = CPC.OptionsPanel
    panel:Fire("OnShow")
    check(ComboPointCounterDB.size == 200, "opening options keeps size 200 (slider clamp not written back)")

    local version = Find(function(w) return w.kind == "FontString" and w.text:match("^v%d") end)
    check(version and version.text == "v1.3", "header shows .toc version")

    -- size slider user drag
    local sizeSlider = Find(function(w) return w.kind == "Slider" and w.max == 128 end)
    sizeSlider:SetValue(64)
    check(ComboPointCounterDB.size == 64, "slider drag sets size")
    local threshSlider = Find(function(w) return w.kind == "Slider" and w.max == 7 end)
    threshSlider:SetValue(3)
    check(ComboPointCounterDB.finisherThreshold == 3, "threshold slider sets threshold")

    -- reset buttons
    local resets = {}
    for _, w in ipairs(state.widgets) do if w.kind == "Button" and w.text == "Reset" then resets[#resets + 1] = w end end
    check(#resets == 9, "4 setting resets + 5 color resets (got " .. #resets .. ")")
    for _, r in ipairs(resets) do r:Fire("OnClick") end
    local db = ComboPointCounterDB
    check(db.size == 25 and db.finisherThreshold == 6 and db.x == 0 and db.y == 0, "resets restore defaults")

    -- color picker: pick, then cancel
    local swatchButtons = {}
    for _, w in ipairs(state.widgets) do if w.kind == "Button" and w.swatch then swatchButtons[#swatchButtons + 1] = w end end
    check(#swatchButtons == 5, "five color swatches")
    swatchButtons[1]:Fire("OnClick")
    local info = ColorPickerFrame.info
    check(info and info.hasOpacity, "color picker opened")
    ColorPickerFrame.rgb, ColorPickerFrame.alpha = { 0.2, 0.4, 0.6 }, 0.5
    info.swatchFunc()
    local bg = db.backgroundColor
    check(approx(bg.r, 0.2) and approx(bg.b, 0.6) and approx(bg.a, 0.5), "picked color saved")
    check(approx(swatchButtons[1].swatch.color[1], 0.2), "swatch refreshed via NotifyOptions")
    info.cancelFunc()
    check(approx(bg.r, 0) and approx(bg.a, 0.6), "cancel restores previous color")

    -- border atlas dropdown -> Solid Color shows tint row
    local dd = Find(function(w) return w.menuGen end)
    check(#dd.radios == 6, "six border choices")
    check(dd.text == "Glow 1", "dropdown shows current border")
    local tintRow = swatchButtons[5].parent
    check(not tintRow.shown, "tint row hidden for default border")
    for _, r in ipairs(dd.radios) do if r.text == "Solid Color" then r.setSelected(r.data) end end
    check(db.borderAtlas == "talents-node-circle-sheenmask", "border atlas set")
    check(dd.text == "Solid Color" and tintRow.shown, "dropdown text updated and tint row shown")

    -- arrows step through the border list and stop at the ends
    local stepper = dd.parent
    check(not stepper.IncrementButton.enabled and stepper.DecrementButton.enabled, "next arrow disabled on last border")
    stepper.DecrementButton:Fire("OnClick")
    check(db.borderAtlas == "services-cover-ring" and dd.text == "Ring", "previous arrow selects Ring")
    check(stepper.IncrementButton.enabled and not tintRow.shown, "next arrow re-enabled, tint row hidden")
    stepper.IncrementButton:Fire("OnClick")
    check(db.borderAtlas == "talents-node-circle-sheenmask", "next arrow steps forward")
    CPC.SetColor("borderTint", 1, 0, 0, 1)
    local border = Find(function(w) return w.atlas == "talents-node-circle-sheenmask" end)
    check(border and approx(border.vertex[2], 0), "border tint applied")

    local borderReset = Find(function(w) return w.kind == "Button" and w.text == "Reset" and w.parent == stepper.parent end)
    borderReset:Fire("OnClick")
    check(db.borderAtlas == "ChallengeMode-KeystoneSlotFrameGlow" and dd.text == "Glow 1", "border reset restores default")
    check(not stepper.DecrementButton.enabled and not tintRow.shown, "border reset updates arrows and tint row")

    -- force number checkbox + box
    local debugBox
    for _, w in ipairs(state.widgets) do if w.kind == "EditBox" and w.scripts.OnEditFocusGained then debugBox = w end end
    debugBox:SetFocus()
    debugBox.text = "9"
    debugBox:Fire("OnEnterPressed")
    check(db.debugValue == 7 and debugBox.text == "7", "force number clamps to 7")
end)

Test("Options typing: refresh keeps the edit, focus loss commits, Escape undoes", function()
    local CPC = Boot("ROGUE", nil)
    CPC.OptionsPanel:Fire("OnShow")
    local db = ComboPointCounterDB
    local boxes = {}
    for _, w in ipairs(state.widgets) do if w.kind == "EditBox" then boxes[#boxes + 1] = w end end
    local posX, posY, offset0 = boxes[1], boxes[2], boxes[4]
    local sizeSlider = Find(function(w) return w.kind == "Slider" and w.max == 128 end)

    posX:SetFocus()
    posX.text = "123"
    sizeSlider:SetValue(40)
    check(db.size == 40 and posX.text == "123", "slider refresh leaves the box being typed in alone")
    posX:Fire("OnEnterPressed")
    check(db.x == 123 and not posX:HasFocus(), "Enter commits")

    posX:SetFocus()
    posX.text = "7"
    posX:Fire("OnTabPressed")
    check(db.x == 7 and posY:HasFocus(), "Tab commits and moves to the next box")

    posY.text = "50"
    posY:Fire("OnEscapePressed")
    check(db.y == 0 and posY.text == "0", "Escape undoes the edit")

    offset0:SetFocus()
    offset0.text = "-"
    offset0:Fire("OnEnterPressed")
    check(db.textOffsets[0] == 0 and offset0.text == "0", "invalid text reverts to the saved value")
end)

Test("Mouse is only taken while Shift is held", function()
    local CPC = Boot("ROGUE", nil)
    local f = CPC.frame
    check(not f.mouse, "no mouse by default")
    state.shift = true
    FireEvent(f, "MODIFIER_STATE_CHANGED", "LSHIFT", 1)
    check(f.mouse, "Shift down takes the mouse")
    state.shift = false
    FireEvent(f, "MODIFIER_STATE_CHANGED", "LSHIFT", 0)
    check(not f.mouse, "Shift up releases it")

    state.shift = true
    FireEvent(f, "MODIFIER_STATE_CHANGED", "LSHIFT", 1)
    f:Fire("OnDragStart")
    state.shift = false
    FireEvent(f, "MODIFIER_STATE_CHANGED", "LSHIFT", 0)
    check(f.mouse, "mouse kept mid-drag after Shift is let go")
    f.lastPoint = { "CENTER", UIParent, "CENTER", 10.4, -5.6 }
    f:Fire("OnDragStop")
    check(not f.mouse and ComboPointCounterDB.x == 10 and ComboPointCounterDB.y == -6, "drag end saves position and releases the mouse")

    state.shift = true
    f:Fire("OnDragStart")
    state.shift = false
    f:Hide()
    f:Fire("OnHide")
    check(not f.mouse, "hiding mid-drag ends the drag")
end)

Test("Slash command: opens options, defers in combat", function()
    local CPC = Boot("ROGUE", nil)
    SlashCmdList.COMBOPOINTCOUNTER("")
    check(state.opened[1] == 42, "/cpc opens options category")
    SlashCmdList.COMBOPOINTCOUNTER("options extra args")
    check(#state.opened == 2, "args are ignored")

    state.lockdown = true
    SlashCmdList.COMBOPOINTCOUNTER("")
    check(#state.opened == 2 and #state.prints == 1, "in combat: not opened, message printed")
    local openFrame = Find(function(w) return w.events.PLAYER_REGEN_ENABLED and w ~= CPC.frame end)
    check(openFrame ~= nil, "waits for combat end")
    state.lockdown = false
    openFrame:Fire("OnEvent", "PLAYER_REGEN_ENABLED")
    check(#state.opened == 3 and not openFrame.events.PLAYER_REGEN_ENABLED, "opens after combat and stops listening")
end)

print(("\n%d passed, %d failed"):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
