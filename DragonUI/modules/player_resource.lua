local addon = select(2, ...)

-- ============================================================================
-- DragonUI - Player Resource Display (Personal Resource)
-- Opt-in stacked health + power bars above the castbar (retail PRD style).
-- ============================================================================

local UnitHealth, UnitHealthMax = UnitHealth, UnitHealthMax
local UnitPower, UnitPowerMax = UnitPower, UnitPowerMax
local UnitPowerType = UnitPowerType
local UnitExists, UnitIsDeadOrGhost = UnitExists, UnitIsDeadOrGhost
local UnitHasVehicleUI = UnitHasVehicleUI
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

local CASTBAR_ATLAS = "Interface\\AddOns\\DragonUI\\Textures\\CastbarOriginal\\uicastingbar2x"
local UV_BORDER = { 0.412109375, 0.828125, 0.001953125, 0.060546875 }
local UV_BACKGROUND = { 0.0009765625, 0.4130859375, 0.3671875, 0.41796875 }

local DEFAULT_WIDTH = 220
local DEFAULT_HEALTH_HEIGHT = 16
local DEFAULT_POWER_HEIGHT = 14
local DEFAULT_SPACING = 3
local DEFAULT_TEXT_SIZE = 11
local DEFAULT_TEXT_FORMAT = "both"
local DEFAULT_WIDGET_ANCHOR = "CENTER"
local DEFAULT_WIDGET_X = 0
local DEFAULT_WIDGET_Y = -220

local POWER_FALLBACK = "Interface\\AddOns\\DragonUI\\Textures\\Unitframe\\UI-HUD-UnitFrame-Player-PortraitOn-Bar-Mana"
local HEALTH_FALLBACK = "Interface\\AddOns\\DragonUI\\Textures\\Unitframe\\UI-HUD-UnitFrame-Player-PortraitOn-Bar-Health"

-- ============================================================================
-- CONFIG HELPERS
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

-- Bump first-ship tiny defaults / BOTTOM placement to the larger layout.
local function MigrateLegacyDefaults()
    local cfg = GetModuleConfig()
    if cfg then
        if cfg.width == 120 and cfg.health_height == 8 and cfg.power_height == 8 then
            cfg.width = DEFAULT_WIDTH
            cfg.health_height = DEFAULT_HEALTH_HEIGHT
            cfg.power_height = DEFAULT_POWER_HEIGHT
            cfg.spacing = DEFAULT_SPACING
        end
        if cfg.show_health_text == nil then
            cfg.show_health_text = true
        end
        if cfg.show_power_text == nil then
            cfg.show_power_text = true
        end
        if cfg.health_text_format == nil then
            cfg.health_text_format = DEFAULT_TEXT_FORMAT
        end
        if cfg.power_text_format == nil then
            cfg.power_text_format = DEFAULT_TEXT_FORMAT
        end
        if cfg.text_size == nil then
            cfg.text_size = DEFAULT_TEXT_SIZE
        end
        if cfg.break_up_large_numbers == nil then
            cfg.break_up_large_numbers = true
        end
    end

    local widget = GetWidgetConfig()
    if widget then
        if widget.anchor == "BOTTOM" and tonumber(widget.posY) == 230 then
            widget.anchor = DEFAULT_WIDGET_ANCHOR
            widget.posX = DEFAULT_WIDGET_X
            widget.posY = DEFAULT_WIDGET_Y
        elseif (widget.anchor == "CENTER" or not widget.anchor) then
            local y = tonumber(widget.posY)
            -- Old BOTTOM 230 often lands near -301 in editor CENTER coords
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
    local width = tonumber(cfg.width) or DEFAULT_WIDTH
    local healthHeight = tonumber(cfg.health_height) or DEFAULT_HEALTH_HEIGHT
    local powerHeight = tonumber(cfg.power_height) or DEFAULT_POWER_HEIGHT
    local spacing = tonumber(cfg.spacing) or DEFAULT_SPACING
    return width, healthHeight, powerHeight, spacing
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

local function GetHealthTexture()
    local uf = addon.UF
    if uf and uf.TEXTURES and uf.TEXTURES.player and uf.TEXTURES.player.HEALTH_BAR then
        return uf.TEXTURES.player.HEALTH_BAR
    end
    return HEALTH_FALLBACK
end

local function GetPowerTexture(powerToken)
    local uf = addon.UF
    local bars = uf and uf.TEXTURES and uf.TEXTURES.player and uf.TEXTURES.player.POWER_BARS
    if bars then
        return bars[powerToken] or bars.MANA or POWER_FALLBACK
    end
    return POWER_FALLBACK
end

local function GetBarFontPath()
    if addon.Fonts and addon.Fonts.ARIALN then
        return addon.Fonts.ARIALN
    end
    return "Fonts\\ARIALN.TTF"
end

-- ============================================================================
-- TEXT HELPERS
-- ============================================================================

local function FormatBarText(current, maximum, textFormat, useBreakup)
    local TextSystem = addon.TextSystem
    if TextSystem and TextSystem.FormatStatusText then
        return TextSystem.FormatStatusText(current, maximum, textFormat, useBreakup)
    end

    if not current or not maximum or maximum == 0 then
        return ""
    end

    local cur = tostring(current)
    local maxv = tostring(maximum)
    local percent = floor((current / maximum) * 100)
    if textFormat == "numeric" then
        return cur
    elseif textFormat == "percentage" then
        return percent .. "%"
    elseif textFormat == "both" then
        return { left = percent .. "%", right = cur }
    end
    return cur .. " / " .. maxv
end

local function EnsureBarTexts(bar)
    if bar.textCenter then
        return
    end

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
    if not bar then
        return
    end
    local fontPath = GetBarFontPath()
    if bar.textCenter then
        bar.textCenter:SetFont(fontPath, size, "OUTLINE")
    end
    if bar.textLeft then
        bar.textLeft:SetFont(fontPath, size, "OUTLINE")
    end
    if bar.textRight then
        bar.textRight:SetFont(fontPath, size, "OUTLINE")
    end
end

local function SetBarText(bar, show, current, maximum, textFormat, useBreakup)
    if not bar then
        return
    end
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
-- FRAME CREATION
-- ============================================================================

local function StyleBarChrome(bar)
    local bg = bar:CreateTexture(nil, "BACKGROUND")
    bg:SetTexture(CASTBAR_ATLAS)
    bg:SetTexCoord(unpack(UV_BACKGROUND))
    bg:SetAllPoints(bar)
    bar.bg = bg

    local border = bar:CreateTexture(nil, "ARTWORK", nil, 0)
    border:SetTexture(CASTBAR_ATLAS)
    border:SetTexCoord(unpack(UV_BORDER))
    border:SetPoint("TOPLEFT", bar, "TOPLEFT", -2, 2)
    border:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", 2, -2)
    bar.border = border
end

local function CreateBars(container)
    local health = CreateFrame("StatusBar", "DragonUI_PlayerResourceHealth", container)
    health:EnableMouse(false)
    health:SetStatusBarTexture(GetHealthTexture())
    health:SetStatusBarColor(1, 1, 1, 1)
    health:SetMinMaxValues(0, 1)
    health:SetValue(1)
    StyleBarChrome(health)
    EnsureBarTexts(health)

    local power = CreateFrame("StatusBar", "DragonUI_PlayerResourcePower", container)
    power:EnableMouse(false)
    power:SetStatusBarTexture(GetPowerTexture("MANA"))
    power:SetStatusBarColor(1, 1, 1, 1)
    power:SetMinMaxValues(0, 1)
    power:SetValue(1)
    StyleBarChrome(power)
    EnsureBarTexts(power)

    return health, power
end

local function LayoutBars()
    local frames = PlayerResourceModule.frames
    if not frames.container or not frames.health or not frames.power then
        return
    end

    local width, healthHeight, powerHeight, spacing = GetSizeConfig()
    local totalHeight = healthHeight + spacing + powerHeight

    frames.container:SetSize(width, totalHeight)
    if frames.anchor then
        frames.anchor:SetSize(width, totalHeight)
    end

    frames.health:ClearAllPoints()
    frames.health:SetSize(width, healthHeight)
    frames.health:SetPoint("TOP", frames.container, "TOP", 0, 0)

    frames.power:ClearAllPoints()
    frames.power:SetSize(width, powerHeight)
    frames.power:SetPoint("TOP", frames.health, "BOTTOM", 0, -spacing)
end

local function ApplyWidgetPosition()
    local anchor = PlayerResourceModule.frames.anchor
    if not anchor then
        return
    end

    local widget = GetWidgetConfig()
    local point = (widget and widget.anchor) or DEFAULT_WIDGET_ANCHOR
    local x = (widget and widget.posX) or DEFAULT_WIDGET_X
    local y = (widget and widget.posY) or DEFAULT_WIDGET_Y

    anchor:ClearAllPoints()
    anchor:SetPoint(point, UIParent, point, x, y)
end

local function AnchorContainerToMover()
    local frames = PlayerResourceModule.frames
    if not frames.container or not frames.anchor then
        return
    end

    frames.container:ClearAllPoints()
    frames.container:SetPoint("CENTER", frames.anchor, "CENTER", 0, 0)
end

local function UpdateWidgets()
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

    local width, healthHeight, powerHeight, spacing = GetSizeConfig()
    local totalHeight = healthHeight + spacing + powerHeight

    -- Keep CreateUIFrame defaults (FULLSCREEN mover) so editor mode can grab it
    local anchor = addon.CreateUIFrame(width, totalHeight, "PlayerResource")
    frames.anchor = anchor

    -- Visual bars live on UIParent and track the mover (same pattern as castbar)
    local container = CreateFrame("Frame", "DragonUI_PlayerResource", UIParent)
    container:EnableMouse(false)
    container:SetFrameStrata("MEDIUM")
    container:SetFrameLevel(10)
    frames.container = container

    frames.health, frames.power = CreateBars(container)

    LayoutBars()
    ApplyWidgetPosition()
    AnchorContainerToMover()
    ApplyTextStyle()

    return frames
end

-- ============================================================================
-- UPDATES
-- ============================================================================

local function UpdateHealth()
    local health = PlayerResourceModule.frames.health
    if not health then
        return
    end

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
    health:SetStatusBarTexture(GetHealthTexture())
    health:SetStatusBarColor(1, 1, 1, 1)
    SetBarText(health, textCfg.showHealth, curHealth, maxHealth, textCfg.healthFormat, textCfg.breakUp)
end

local function UpdatePower()
    local power = PlayerResourceModule.frames.power
    if not power then
        return
    end

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

    power:SetStatusBarTexture(GetPowerTexture(powerToken))
    power:SetStatusBarColor(1, 1, 1, 1)
end

local function UpdateAll()
    UpdateHealth()
    UpdatePower()
end

local function ShouldShow()
    if not IsModuleEnabled() then
        return false
    end
    if not UnitExists("player") then
        return false
    end
    if UnitIsDeadOrGhost("player") then
        return false
    end
    if UnitHasVehicleUI and UnitHasVehicleUI("player") then
        return false
    end
    return true
end

local function IsEditorActive()
    return addon.EditorMode and addon.EditorMode.IsActive and addon.EditorMode:IsActive()
end

local function SetVisible(visible)
    local frames = PlayerResourceModule.frames
    if not frames.container then
        return
    end

    if visible then
        if frames.anchor then
            frames.anchor:Show()
        end
        frames.container:Show()
    else
        frames.container:Hide()
        -- Keep mover visible while editing so it can still be dragged
        if frames.anchor and not IsEditorActive() then
            frames.anchor:Hide()
        end
    end
end

-- ============================================================================
-- EVENTS
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
            and event ~= "PLAYER_LOGIN" then
            return
        end
    end

    if not ShouldShow() then
        SetVisible(false)
        return
    end

    SetVisible(true)

    if event == "UNIT_HEALTH" or event == "UNIT_MAXHEALTH" or event == "UNIT_HEALTH_FREQUENT" then
        UpdateHealth()
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
    else
        UpdateAll()
    end
end

local function RegisterEvents(frame)
    local events = {
        "PLAYER_ENTERING_WORLD",
        "PLAYER_LOGIN",
        "PLAYER_DEAD",
        "PLAYER_ALIVE",
        "PLAYER_UNGHOST",
        "UNIT_HEALTH",
        "UNIT_MAXHEALTH",
        "UNIT_DISPLAYPOWER",
        "UNIT_MANA",
        "UNIT_MAXMANA",
        "UNIT_RAGE",
        "UNIT_MAXRAGE",
        "UNIT_ENERGY",
        "UNIT_MAXENERGY",
        "UNIT_FOCUS",
        "UNIT_MAXFOCUS",
        "UNIT_RUNIC_POWER",
        "UNIT_MAXRUNIC_POWER",
        "UNIT_ENTERED_VEHICLE",
        "UNIT_EXITED_VEHICLE",
    }

    -- Newer clients / backports
    pcall(frame.RegisterEvent, frame, "UNIT_POWER")
    pcall(frame.RegisterEvent, frame, "UNIT_MAXPOWER")
    pcall(frame.RegisterEvent, frame, "UNIT_POWER_UPDATE")
    pcall(frame.RegisterEvent, frame, "UNIT_HEALTH_FREQUENT")

    for _, event in ipairs(events) do
        frame:RegisterEvent(event)
        table.insert(PlayerResourceModule.registeredEvents, { frame = frame, event = event })
    end

    frame:SetScript("OnEvent", OnEvent)
end

local function UnregisterEvents()
    local eventFrame = PlayerResourceModule.frames.eventFrame
    if eventFrame then
        eventFrame:UnregisterAllEvents()
        eventFrame:SetScript("OnEvent", nil)
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
    if not anchor then
        return
    end

    addon:RegisterEditableFrame({
        name = "player_resource",
        frame = anchor,
        configPath = { "widgets", "player_resource" },
        editorVisible = function()
            return IsModuleEnabled()
        end,
        hasTarget = function()
            return IsModuleEnabled()
        end,
        showTest = function()
            EnsureFrames()
            UpdateWidgets()
            local frames = PlayerResourceModule.frames
            if frames.anchor then
                frames.anchor:Show()
            end
            if frames.container then
                frames.container:Show()
            end
            local textCfg = GetTextConfig()
            local health = frames.health
            local power = frames.power
            if health then
                health:SetMinMaxValues(0, 100)
                health:SetValue(75)
                health:SetStatusBarTexture(GetHealthTexture())
                health:SetStatusBarColor(1, 1, 1, 1)
                SetBarText(health, textCfg.showHealth, 75, 100, textCfg.healthFormat, textCfg.breakUp)
            end
            if power then
                power:SetMinMaxValues(0, 100)
                power:SetValue(60)
                power:SetStatusBarTexture(GetPowerTexture("MANA"))
                power:SetStatusBarColor(1, 1, 1, 1)
                SetBarText(power, textCfg.showPower, 60, 100, textCfg.powerFormat, textCfg.breakUp)
            end
        end,
        hideTest = function()
            if ShouldShow() then
                UpdateAll()
                SetVisible(true)
            else
                SetVisible(false)
            end
        end,
        onHide = function()
            UpdateWidgets()
            if ShouldShow() then
                UpdateAll()
                SetVisible(true)
            else
                SetVisible(false)
            end
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
        if ShouldShow() then
            UpdateAll()
            SetVisible(true)
        else
            SetVisible(false)
        end
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

    if ShouldShow() then
        UpdateAll()
        SetVisible(true)
    else
        SetVisible(false)
    end
end

local function Restore()
    UnregisterEvents()
    local frames = PlayerResourceModule.frames
    if frames.container then
        frames.container:Hide()
    end
    if frames.anchor then
        frames.anchor:Hide()
    end
    PlayerResourceModule.applied = false
end

function addon.ApplyPlayerResourceSystem()
    if not IsModuleEnabled() then
        return
    end
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

-- ============================================================================
-- INIT
-- ============================================================================

local function Initialize()
    if PlayerResourceModule.initialized then
        return
    end
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
