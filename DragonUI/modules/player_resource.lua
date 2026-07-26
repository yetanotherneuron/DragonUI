local addon = select(2, ...)

-- ============================================================================
-- DragonUI - Player Resource Display (Personal Resource)
-- Opt-in stacked health + power above the castbar.
-- ============================================================================

local UnitHealth, UnitHealthMax = UnitHealth, UnitHealthMax
local UnitPower, UnitPowerMax = UnitPower, UnitPowerMax
local UnitPowerType = UnitPowerType
local UnitExists, UnitIsDeadOrGhost = UnitExists, UnitIsDeadOrGhost
local UnitHasVehicleUI = UnitHasVehicleUI
local UnitAffectingCombat = UnitAffectingCombat
local floor = math.floor

local PlayerResourceModule = {
    initialized = false,
    applied = false,
    originalStates = {},
    registeredEvents = {},
    hooks = {},
    stateDrivers = {},
    frames = {},
    editableRegistered = false,
    mouseOver = false,
}

addon.PlayerResourceModule = PlayerResourceModule

if addon.RegisterModule then
    addon:RegisterModule(
        "player_resource",
        PlayerResourceModule,
        (addon.L and addon.L["Player Resource Display"]) or "Player Resource Display",
        (addon.L and addon.L["Show personal health and power bars above the castbar."])
            or "Show personal health and power bars above the castbar."
    )
end

-- ============================================================================
-- CONSTANTS
-- ============================================================================

local DEFAULT_WIDTH = 220
local DEFAULT_HEALTH_HEIGHT = 16
local DEFAULT_POWER_HEIGHT = 14
local DEFAULT_TEXT_SIZE = 11
local DEFAULT_TEXT_FORMAT = "both"
local DEFAULT_WIDGET_ANCHOR = "CENTER"
local DEFAULT_WIDGET_X = 0
local DEFAULT_WIDGET_Y = -220

local BORDER_SIZE = 2          -- outer black border
local DIVIDER_SIZE = 1         -- 1px between health and power

local POWER_FALLBACK = "Interface\\AddOns\\DragonUI\\Textures\\Unitframe\\UI-HUD-UnitFrame-Player-PortraitOn-Bar-Mana"
local HEALTH_FALLBACK = "Interface\\AddOns\\DragonUI\\Textures\\Unitframe\\UI-HUD-UnitFrame-Player-PortraitOn-Bar-Health"
local SOLID_TEX = "Interface\\Buttons\\WHITE8X8"

-- Status bar texture styles (grayscale ones need SetStatusBarColor)
local BAR_TEXTURE_PATHS = {
    blizzard      = "Interface\\TargetingFrame\\UI-StatusBar",
    blizzard_flat = "Interface\\ChatFrame\\ChatFrameBackground",
    smooth        = "Interface\\PaperDollInfoFrame\\UI-Character-Skills-Bar",
    aluminium     = "Interface\\BUTTONS\\WHITE8X8",
    litestep      = "Interface\\PaperDollInfoFrame\\UI-Character-Tab-Highlight",
}
local BAR_TEXTURE_VALID = {
    dragonui = true,
    blizzard = true,
    blizzard_flat = true,
    smooth = true,
    aluminium = true,
    litestep = true,
}
local HEALTH_BAR_COLOR = { r = 0.0, g = 1.0, b = 0.0 }
local POWER_BAR_COLORS = {
    MANA        = { r = 0.00, g = 0.00, b = 1.00 },
    RAGE        = { r = 1.00, g = 0.00, b = 0.00 },
    FOCUS       = { r = 1.00, g = 0.50, b = 0.25 },
    ENERGY      = { r = 1.00, g = 1.00, b = 0.00 },
    HAPPINESS   = { r = 0.00, g = 1.00, b = 1.00 },
    RUNES       = { r = 0.50, g = 0.50, b = 0.50 },
    RUNIC_POWER = { r = 0.00, g = 0.82, b = 1.00 },
}

-- ============================================================================
-- CONFIG
-- ============================================================================

local function GetModuleConfig()
    return addon:GetModuleConfig("player_resource")
end

local function IsModuleEnabled()
    return addon:IsModuleEnabled("player_resource")
end

local function GetWidgetConfig()
    if addon.db and addon.db.profile and addon.db.profile.widgets then
        return addon.db.profile.widgets.player_resource
    end
    return nil
end

local function MigrateLegacyDefaults()
    local cfg = GetModuleConfig()
    if not cfg then
        return
    end

    if cfg.width == 120 and cfg.health_height == 8 and cfg.power_height == 8 then
        cfg.width = DEFAULT_WIDTH
        cfg.health_height = DEFAULT_HEALTH_HEIGHT
        cfg.power_height = DEFAULT_POWER_HEIGHT
    end
    cfg.spacing = 0
    if cfg.show_health_text == nil then cfg.show_health_text = true end
    if cfg.show_power_text == nil then cfg.show_power_text = true end
    if cfg.health_text_format == nil then cfg.health_text_format = DEFAULT_TEXT_FORMAT end
    if cfg.power_text_format == nil then cfg.power_text_format = DEFAULT_TEXT_FORMAT end
    if cfg.text_size == nil then cfg.text_size = DEFAULT_TEXT_SIZE end
    if cfg.break_up_large_numbers == nil then cfg.break_up_large_numbers = true end
    if cfg.bar_texture == nil or not BAR_TEXTURE_VALID[cfg.bar_texture] then
        cfg.bar_texture = "blizzard"
    end
    if cfg.show_on_hover == nil then cfg.show_on_hover = false end
    if cfg.show_in_combat == nil then cfg.show_in_combat = false end
    if cfg.hide_in_combat == nil then cfg.hide_in_combat = false end
    if cfg.visibility_logic == nil then cfg.visibility_logic = "or" end
    if cfg.show_when_health_below == nil then cfg.show_when_health_below = false end
    if cfg.health_below_percent == nil then cfg.health_below_percent = 35 end
    if cfg.show_when_power_below == nil then cfg.show_when_power_below = false end
    if cfg.power_below_percent == nil then cfg.power_below_percent = 35 end

    local widget = GetWidgetConfig()
    if widget then
        if widget.anchor == "BOTTOM" and tonumber(widget.posY) == 230 then
            widget.anchor = DEFAULT_WIDGET_ANCHOR
            widget.posX = DEFAULT_WIDGET_X
            widget.posY = DEFAULT_WIDGET_Y
        elseif (widget.anchor == "CENTER" or not widget.anchor) then
            local y = tonumber(widget.posY)
            if y and y <= -290 and y >= -320 then
                widget.anchor = DEFAULT_WIDGET_ANCHOR
                widget.posX = tonumber(widget.posX) or DEFAULT_WIDGET_X
                widget.posY = DEFAULT_WIDGET_Y
            end
        end
    end
end

local function GetSizeConfig()
    local cfg = GetModuleConfig() or {}
    return tonumber(cfg.width) or DEFAULT_WIDTH,
        tonumber(cfg.health_height) or DEFAULT_HEALTH_HEIGHT,
        tonumber(cfg.power_height) or DEFAULT_POWER_HEIGHT
end

local function GetTextConfig()
    local cfg = GetModuleConfig() or {}
    return {
        showHealth = cfg.show_health_text ~= false,
        showPower = cfg.show_power_text ~= false,
        healthFormat = cfg.health_text_format or DEFAULT_TEXT_FORMAT,
        powerFormat = cfg.power_text_format or DEFAULT_TEXT_FORMAT,
        textSize = tonumber(cfg.text_size) or DEFAULT_TEXT_SIZE,
        breakUp = cfg.break_up_large_numbers ~= false,
    }
end

local function GetBarTextureSetting()
    local cfg = GetModuleConfig()
    local setting = cfg and cfg.bar_texture or "blizzard"
    if not BAR_TEXTURE_VALID[setting] then
        return "blizzard"
    end
    return setting
end

local function UsesDragonBarTexture()
    return GetBarTextureSetting() == "dragonui"
end

local function GetDragonHealthTexture()
    local uf = addon.UF
    if uf and uf.TEXTURES and uf.TEXTURES.player and uf.TEXTURES.player.HEALTH_BAR then
        return uf.TEXTURES.player.HEALTH_BAR
    end
    return HEALTH_FALLBACK
end

local function GetDragonPowerTexture(powerToken)
    local uf = addon.UF
    local bars = uf and uf.TEXTURES and uf.TEXTURES.player and uf.TEXTURES.player.POWER_BARS
    if bars then
        return bars[powerToken] or bars.MANA or POWER_FALLBACK
    end
    return POWER_FALLBACK
end

local function GetHealthTexture()
    if UsesDragonBarTexture() then
        return GetDragonHealthTexture()
    end
    local path = BAR_TEXTURE_PATHS[GetBarTextureSetting()]
    return path or BAR_TEXTURE_PATHS.blizzard
end

local function GetPowerTexture(powerToken)
    if UsesDragonBarTexture() then
        return GetDragonPowerTexture(powerToken)
    end
    local path = BAR_TEXTURE_PATHS[GetBarTextureSetting()]
    return path or BAR_TEXTURE_PATHS.blizzard
end

local function GetPowerBarColor(powerToken)
    if PowerBarColor and powerToken and PowerBarColor[powerToken] then
        local c = PowerBarColor[powerToken]
        if c.r then
            return c.r, c.g, c.b
        end
    end
    local c = POWER_BAR_COLORS[powerToken] or POWER_BAR_COLORS.MANA
    return c.r, c.g, c.b
end

local function ApplyHealthBarStyle(health)
    if not health then return end
    health:SetStatusBarTexture(GetHealthTexture())
    if UsesDragonBarTexture() then
        health:SetStatusBarColor(1, 1, 1, 1)
    else
        health:SetStatusBarColor(HEALTH_BAR_COLOR.r, HEALTH_BAR_COLOR.g, HEALTH_BAR_COLOR.b, 1)
    end
end

local function ApplyPowerBarStyle(power, powerToken)
    if not power then return end
    powerToken = powerToken or "MANA"
    power:SetStatusBarTexture(GetPowerTexture(powerToken))
    if UsesDragonBarTexture() then
        power:SetStatusBarColor(1, 1, 1, 1)
    else
        local r, g, b = GetPowerBarColor(powerToken)
        power:SetStatusBarColor(r, g, b, 1)
    end
end

local function GetBarFontPath()
    if addon.Fonts and addon.Fonts.ARIALN then
        return addon.Fonts.ARIALN
    end
    return "Fonts\\ARIALN.TTF"
end

local function GetHealthPercent()
    local maxH = UnitHealthMax("player") or 0
    if maxH <= 0 then return 100 end
    return ((UnitHealth("player") or 0) / maxH) * 100
end

local function GetPowerPercent()
    local powerType = UnitPowerType("player")
    local maxP = UnitPowerMax("player", powerType) or 0
    if maxP <= 0 then return 100 end
    return ((UnitPower("player", powerType) or 0) / maxP) * 100
end

-- ============================================================================
-- TEXT
-- ============================================================================

local function FormatBarText(current, maximum, textFormat, useBreakup)
    local TextSystem = addon.TextSystem
    if TextSystem and TextSystem.FormatStatusText then
        return TextSystem.FormatStatusText(current, maximum, textFormat, useBreakup)
    end
    if not current or not maximum or maximum == 0 then return "" end
    local cur, maxv = tostring(current), tostring(maximum)
    local percent = floor((current / maximum) * 100)
    if textFormat == "numeric" then return cur end
    if textFormat == "percentage" then return percent .. "%" end
    if textFormat == "both" then return { left = percent .. "%", right = cur } end
    return cur .. " / " .. maxv
end

local function EnsureBarTexts(bar)
    if bar.textCenter then return end
    local fontPath = GetBarFontPath()
    local size = DEFAULT_TEXT_SIZE

    local center = bar:CreateFontString(nil, "OVERLAY")
    center:SetFont(fontPath, size, "OUTLINE")
    center:SetPoint("CENTER", bar, "CENTER", 0, 0)
    center:SetJustifyH("CENTER")
    center:SetTextColor(1, 1, 1, 1)
    bar.textCenter = center

    local left = bar:CreateFontString(nil, "OVERLAY")
    left:SetFont(fontPath, size, "OUTLINE")
    left:SetPoint("LEFT", bar, "LEFT", 4, 0)
    left:SetJustifyH("LEFT")
    left:SetTextColor(1, 1, 1, 1)
    bar.textLeft = left

    local right = bar:CreateFontString(nil, "OVERLAY")
    right:SetFont(fontPath, size, "OUTLINE")
    right:SetPoint("RIGHT", bar, "RIGHT", -4, 0)
    right:SetJustifyH("RIGHT")
    right:SetTextColor(1, 1, 1, 1)
    bar.textRight = right
end

local function ApplyBarTextSize(bar, size)
    if not bar then return end
    local fontPath = GetBarFontPath()
    if bar.textCenter then bar.textCenter:SetFont(fontPath, size, "OUTLINE") end
    if bar.textLeft then bar.textLeft:SetFont(fontPath, size, "OUTLINE") end
    if bar.textRight then bar.textRight:SetFont(fontPath, size, "OUTLINE") end
end

local function SetBarText(bar, show, current, maximum, textFormat, useBreakup)
    if not bar then return end
    EnsureBarTexts(bar)
    if not show then
        bar.textCenter:Hide()
        bar.textLeft:Hide()
        bar.textRight:Hide()
        return
    end
    local formatted = FormatBarText(current, maximum, textFormat, useBreakup)
    if type(formatted) == "table" then
        bar.textCenter:Hide()
        bar.textLeft:SetText(formatted.left or "")
        bar.textRight:SetText(formatted.right or "")
        bar.textLeft:Show()
        bar.textRight:Show()
    else
        bar.textLeft:Hide()
        bar.textRight:Hide()
        bar.textCenter:SetText(formatted or "")
        bar.textCenter:Show()
    end
end

local function ApplyTextStyle()
    local frames = PlayerResourceModule.frames
    local textCfg = GetTextConfig()
    ApplyBarTextSize(frames.health, textCfg.textSize)
    ApplyBarTextSize(frames.power, textCfg.textSize)
end

-- ============================================================================
-- FRAMES
-- ============================================================================

local function StyleContainerBox(container)
    container:SetBackdrop({
        bgFile = SOLID_TEX,
        edgeFile = SOLID_TEX,
        edgeSize = BORDER_SIZE,
        insets = { left = BORDER_SIZE, right = BORDER_SIZE, top = BORDER_SIZE, bottom = BORDER_SIZE },
    })
    container:SetBackdropColor(0, 0, 0, 0.85)
    container:SetBackdropBorderColor(0, 0, 0, 1)
end

local function CreateBars(container)
    local health = CreateFrame("StatusBar", "DragonUI_PlayerResourceHealth", container)
    health:EnableMouse(false)
    ApplyHealthBarStyle(health)
    health:SetMinMaxValues(0, 1)
    health:SetValue(1)
    EnsureBarTexts(health)

    local power = CreateFrame("StatusBar", "DragonUI_PlayerResourcePower", container)
    power:EnableMouse(false)
    ApplyPowerBarStyle(power, "MANA")
    power:SetMinMaxValues(0, 1)
    power:SetValue(1)
    EnsureBarTexts(power)

    local divider = container:CreateTexture(nil, "ARTWORK")
    divider:SetTexture(SOLID_TEX)
    divider:SetVertexColor(0, 0, 0, 1)
    divider:SetHeight(DIVIDER_SIZE)
    container.divider = divider

    return health, power
end

local function HideLegacyClassHost()
    local host = PlayerResourceModule.frames.classHost
    if host then
        host:Hide()
    end
end

local function LayoutBars()
    local frames = PlayerResourceModule.frames
    if not frames.container or not frames.health or not frames.power then
        return
    end

    local width, healthHeight, powerHeight = GetSizeConfig()
    -- Box = outer border + health + 1px divider + power + outer border
    local boxHeight = BORDER_SIZE + healthHeight + DIVIDER_SIZE + powerHeight + BORDER_SIZE

    frames.container:SetSize(width, boxHeight)
    if frames.anchor then
        frames.anchor:SetSize(width, boxHeight)
    end

    local innerW = width - (BORDER_SIZE * 2)

    frames.health:ClearAllPoints()
    frames.health:SetSize(innerW, healthHeight)
    frames.health:SetPoint("TOPLEFT", frames.container, "TOPLEFT", BORDER_SIZE, -BORDER_SIZE)

    if frames.container.divider then
        frames.container.divider:ClearAllPoints()
        frames.container.divider:SetHeight(DIVIDER_SIZE)
        frames.container.divider:SetPoint("TOPLEFT", frames.health, "BOTTOMLEFT", 0, 0)
        frames.container.divider:SetPoint("TOPRIGHT", frames.health, "BOTTOMRIGHT", 0, 0)
        frames.container.divider:Show()
    end

    frames.power:ClearAllPoints()
    frames.power:SetSize(innerW, powerHeight)
    frames.power:SetPoint("TOPLEFT", frames.health, "BOTTOMLEFT", 0, -DIVIDER_SIZE)

    HideLegacyClassHost()
end

local function ApplyWidgetPosition()
    local anchor = PlayerResourceModule.frames.anchor
    if not anchor then return end
    local widget = GetWidgetConfig()
    local point = (widget and widget.anchor) or DEFAULT_WIDGET_ANCHOR
    local x = (widget and widget.posX) or DEFAULT_WIDGET_X
    local y = (widget and widget.posY) or DEFAULT_WIDGET_Y
    anchor:ClearAllPoints()
    anchor:SetPoint(point, UIParent, point, x, y)
end

local function AnchorContainerToMover()
    local frames = PlayerResourceModule.frames
    if not frames.container or not frames.anchor then return end
    frames.container:ClearAllPoints()
    frames.container:SetPoint("CENTER", frames.anchor, "CENTER", 0, 0)
end

-- ============================================================================
-- VISIBILITY
-- ============================================================================

local function IsMouseOverPRD()
    local frames = PlayerResourceModule.frames
    if PlayerResourceModule.mouseOver then
        return true
    end
    if frames.container and frames.container:IsMouseOver() then
        return true
    end
    return false
end

local function EvaluateShowWhen()
    local cfg = GetModuleConfig() or {}
    local inCombat = UnitAffectingCombat and UnitAffectingCombat("player")

    if cfg.hide_in_combat and inCombat then
        return false
    end

    local checks = {}
    if cfg.show_on_hover then
        table.insert(checks, IsMouseOverPRD())
    end
    if cfg.show_in_combat then
        table.insert(checks, inCombat and true or false)
    end
    if cfg.show_when_health_below then
        local threshold = tonumber(cfg.health_below_percent) or 35
        table.insert(checks, GetHealthPercent() <= threshold)
    end
    if cfg.show_when_power_below then
        local threshold = tonumber(cfg.power_below_percent) or 35
        table.insert(checks, GetPowerPercent() <= threshold)
    end

    -- No show-when conditions → always visible (unless hide_in_combat already applied)
    if #checks == 0 then
        return true
    end

    local logic = cfg.visibility_logic or "or"
    if logic == "and" then
        for i = 1, #checks do
            if not checks[i] then
                return false
            end
        end
        return true
    end

    for i = 1, #checks do
        if checks[i] then
            return true
        end
    end
    return false
end

local function NeedsVisibilityPolling()
    local cfg = GetModuleConfig() or {}
    return cfg.show_on_hover == true
        or cfg.show_when_health_below == true
        or cfg.show_when_power_below == true
end

local function ShouldShow()
    if not IsModuleEnabled() then return false end
    if not UnitExists("player") then return false end
    if UnitIsDeadOrGhost("player") then return false end
    if UnitHasVehicleUI and UnitHasVehicleUI("player") then return false end
    return EvaluateShowWhen()
end

local function IsEditorActive()
    return addon.EditorMode and addon.EditorMode.IsActive and addon.EditorMode:IsActive()
end

-- Forward declarations (assigned below; used by RefreshVisibility)
local UpdateHealth, UpdatePower, UpdateAll, UpdateWidgets

local function SetVisible(visible)
    local frames = PlayerResourceModule.frames
    if not frames.container then return end

    if visible then
        if frames.anchor then frames.anchor:Show() end
        frames.container:Show()
    else
        frames.container:Hide()
        HideLegacyClassHost()
        if frames.anchor and not IsEditorActive() then
            frames.anchor:Hide()
        end
    end
end

local function RefreshVisibility()
    if not PlayerResourceModule.applied then return end
    if ShouldShow() then
        SetVisible(true)
        UpdateHealth()
        UpdatePower()
    else
        SetVisible(false)
    end
end

UpdateHealth = function()
    local health = PlayerResourceModule.frames.health
    if not health then return end
    local textCfg = GetTextConfig()
    local maxHealth = UnitHealthMax("player") or 0
    local curHealth = UnitHealth("player") or 0
    if maxHealth <= 0 then
        health:SetMinMaxValues(0, 1)
        health:SetValue(0)
        SetBarText(health, textCfg.showHealth, 0, 1, textCfg.healthFormat, textCfg.breakUp)
        return
    end
    health:SetMinMaxValues(0, maxHealth)
    health:SetValue(curHealth)
    ApplyHealthBarStyle(health)
    SetBarText(health, textCfg.showHealth, curHealth, maxHealth, textCfg.healthFormat, textCfg.breakUp)
end

UpdatePower = function()
    local power = PlayerResourceModule.frames.power
    if not power then return end
    local textCfg = GetTextConfig()
    local powerType, powerToken = UnitPowerType("player")
    powerToken = powerToken or "MANA"
    local maxPower = UnitPowerMax("player", powerType) or 0
    local curPower = UnitPower("player", powerType) or 0
    if maxPower <= 0 then
        power:SetMinMaxValues(0, 1)
        power:SetValue(0)
        SetBarText(power, textCfg.showPower, 0, 1, textCfg.powerFormat, textCfg.breakUp)
    else
        power:SetMinMaxValues(0, maxPower)
        power:SetValue(curPower)
        SetBarText(power, textCfg.showPower, curPower, maxPower, textCfg.powerFormat, textCfg.breakUp)
    end
    ApplyPowerBarStyle(power, powerToken)
end

UpdateAll = function()
    UpdateHealth()
    UpdatePower()
end

UpdateWidgets = function()
    LayoutBars()
    ApplyWidgetPosition()
    AnchorContainerToMover()
    ApplyTextStyle()
end

local function EnsureFrames()
    local frames = PlayerResourceModule.frames
    if frames.container then
        return frames
    end

    local width, healthHeight, powerHeight = GetSizeConfig()
    local boxHeight = BORDER_SIZE + healthHeight + DIVIDER_SIZE + powerHeight + BORDER_SIZE

    local anchor = addon.CreateUIFrame(width, boxHeight, "PlayerResource")
    frames.anchor = anchor

    local container = CreateFrame("Frame", "DragonUI_PlayerResource", UIParent)
    container:EnableMouse(true) -- needed for show-on-hover
    container:SetFrameStrata("MEDIUM")
    container:SetFrameLevel(10)
    StyleContainerBox(container)
    container:SetScript("OnEnter", function()
        PlayerResourceModule.mouseOver = true
        RefreshVisibility()
    end)
    container:SetScript("OnLeave", function()
        PlayerResourceModule.mouseOver = false
        RefreshVisibility()
    end)
    frames.container = container

    frames.health, frames.power = CreateBars(container)

    LayoutBars()
    ApplyWidgetPosition()
    AnchorContainerToMover()
    ApplyTextStyle()

    return frames
end

-- ============================================================================
-- EVENTS / POLL
-- ============================================================================

local function OnEvent(_, event, unit)
    if not IsModuleEnabled() or not PlayerResourceModule.applied then
        return
    end

    if unit and unit ~= "player" and unit ~= "vehicle" then
        if event ~= "PLAYER_ENTERING_WORLD"
            and event ~= "PLAYER_DEAD"
            and event ~= "PLAYER_ALIVE"
            and event ~= "PLAYER_UNGHOST"
            and event ~= "PLAYER_LOGIN"
            and event ~= "PLAYER_REGEN_DISABLED"
            and event ~= "PLAYER_REGEN_ENABLED" then
            return
        end
    end

    RefreshVisibility()

    if not ShouldShow() then
        return
    end

    if event == "UNIT_HEALTH" or event == "UNIT_MAXHEALTH" or event == "UNIT_HEALTH_FREQUENT" then
        UpdateHealth()
        if GetModuleConfig() and GetModuleConfig().show_when_health_below then
            RefreshVisibility()
        end
    elseif event == "UNIT_DISPLAYPOWER" then
        UpdatePower()
    elseif event == "UNIT_MANA"
        or event == "UNIT_MAXMANA"
        or event == "UNIT_RAGE"
        or event == "UNIT_MAXRAGE"
        or event == "UNIT_ENERGY"
        or event == "UNIT_MAXENERGY"
        or event == "UNIT_FOCUS"
        or event == "UNIT_MAXFOCUS"
        or event == "UNIT_RUNIC_POWER"
        or event == "UNIT_MAXRUNIC_POWER"
        or event == "UNIT_POWER"
        or event == "UNIT_MAXPOWER"
        or event == "UNIT_POWER_UPDATE" then
        UpdatePower()
        if GetModuleConfig() and GetModuleConfig().show_when_power_below then
            RefreshVisibility()
        end
    elseif event == "PLAYER_REGEN_DISABLED" or event == "PLAYER_REGEN_ENABLED" then
        -- visibility already refreshed
    else
        UpdateAll()
    end
end

local function RegisterEvents(frame)
    local events = {
        "PLAYER_ENTERING_WORLD", "PLAYER_LOGIN", "PLAYER_DEAD", "PLAYER_ALIVE", "PLAYER_UNGHOST",
        "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED",
        "UNIT_HEALTH", "UNIT_MAXHEALTH", "UNIT_DISPLAYPOWER",
        "UNIT_MANA", "UNIT_MAXMANA", "UNIT_RAGE", "UNIT_MAXRAGE",
        "UNIT_ENERGY", "UNIT_MAXENERGY", "UNIT_FOCUS", "UNIT_MAXFOCUS",
        "UNIT_RUNIC_POWER", "UNIT_MAXRUNIC_POWER",
        "UNIT_ENTERED_VEHICLE", "UNIT_EXITED_VEHICLE",
    }
    pcall(frame.RegisterEvent, frame, "UNIT_POWER")
    pcall(frame.RegisterEvent, frame, "UNIT_MAXPOWER")
    pcall(frame.RegisterEvent, frame, "UNIT_POWER_UPDATE")
    pcall(frame.RegisterEvent, frame, "UNIT_HEALTH_FREQUENT")

    for _, event in ipairs(events) do
        pcall(frame.RegisterEvent, frame, event)
        table.insert(PlayerResourceModule.registeredEvents, { frame = frame, event = event })
    end
    frame:SetScript("OnEvent", OnEvent)

    -- Light poll for hover / threshold visibility
    local elapsed = 0
    frame:SetScript("OnUpdate", function(_, dt)
        if not NeedsVisibilityPolling() then return end
        elapsed = elapsed + dt
        if elapsed < 0.1 then return end
        elapsed = 0
        RefreshVisibility()
    end)
end

local function UnregisterEvents()
    local eventFrame = PlayerResourceModule.frames.eventFrame
    if eventFrame then
        eventFrame:UnregisterAllEvents()
        eventFrame:SetScript("OnEvent", nil)
        eventFrame:SetScript("OnUpdate", nil)
    end
    wipe(PlayerResourceModule.registeredEvents)
end

-- ============================================================================
-- EDITOR
-- ============================================================================

local function RegisterEditable()
    if PlayerResourceModule.editableRegistered or not addon.RegisterEditableFrame then
        return
    end
    local anchor = PlayerResourceModule.frames.anchor
    if not anchor then return end

    addon:RegisterEditableFrame({
        name = "player_resource",
        frame = anchor,
        configPath = { "widgets", "player_resource" },
        editorVisible = function() return IsModuleEnabled() end,
        hasTarget = function() return IsModuleEnabled() end,
        showTest = function()
            EnsureFrames()
            UpdateWidgets()
            local frames = PlayerResourceModule.frames
            if frames.anchor then frames.anchor:Show() end
            if frames.container then frames.container:Show() end
            local textCfg = GetTextConfig()
            if frames.health then
                frames.health:SetMinMaxValues(0, 100)
                frames.health:SetValue(75)
                ApplyHealthBarStyle(frames.health)
                SetBarText(frames.health, textCfg.showHealth, 75, 100, textCfg.healthFormat, textCfg.breakUp)
            end
            if frames.power then
                frames.power:SetMinMaxValues(0, 100)
                frames.power:SetValue(60)
                ApplyPowerBarStyle(frames.power, "MANA")
                SetBarText(frames.power, textCfg.showPower, 60, 100, textCfg.powerFormat, textCfg.breakUp)
            end
        end,
        hideTest = function()
            RefreshVisibility()
        end,
        onHide = function()
            UpdateWidgets()
            RefreshVisibility()
        end,
        UpdateWidgets = UpdateWidgets,
        module = PlayerResourceModule,
    })
    PlayerResourceModule.editableRegistered = true
end

-- ============================================================================
-- LIFECYCLE
-- ============================================================================

local function Apply()
    MigrateLegacyDefaults()

    if PlayerResourceModule.applied then
        UpdateWidgets()
        RefreshVisibility()
        return
    end

    EnsureFrames()
    UpdateWidgets()
    RegisterEditable()

    local eventFrame = PlayerResourceModule.frames.eventFrame
    if not eventFrame then
        eventFrame = CreateFrame("Frame", "DragonUI_PlayerResourceEvents")
        PlayerResourceModule.frames.eventFrame = eventFrame
    end
    RegisterEvents(eventFrame)
    PlayerResourceModule.applied = true
    RefreshVisibility()
end

local function Restore()
    UnregisterEvents()
    local frames = PlayerResourceModule.frames
    if frames.container then frames.container:Hide() end
    HideLegacyClassHost()
    if frames.anchor then frames.anchor:Hide() end
    PlayerResourceModule.applied = false
end

function addon.ApplyPlayerResourceSystem()
    if not IsModuleEnabled() then return end
    Apply()
end

function addon.RestorePlayerResourceSystem()
    Restore()
end

function addon.RefreshPlayerResourceSystem()
    if IsModuleEnabled() then
        Apply()
    else
        Restore()
    end
end

local function Initialize()
    if PlayerResourceModule.initialized then return end
    PlayerResourceModule.initialized = true
    if IsModuleEnabled() then
        Apply()
    end
end

local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("PLAYER_LOGIN")
initFrame:SetScript("OnEvent", function(self)
    Initialize()
    self:UnregisterEvent("PLAYER_LOGIN")
end)
PlayerResourceModule.frames.initFrame = initFrame
