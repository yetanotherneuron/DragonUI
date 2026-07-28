--[[
================================================================================
DragonUI Options Panel - Unit Frames Tab
================================================================================
Player, target, focus, pet, party, ToT, ToF unit frame options.
Sub-tabs for each frame type.
================================================================================
]]

local addon = DragonUI
if not addon then return end

local L = addon.L
local LO = addon.LO
local C = addon.PanelControls
local Panel = addon.OptionsPanel

-- ============================================================================
-- SHARED VALUES
-- ============================================================================

local textFormatValues = {
    numeric    = LO["Current Value"],
    percentage = LO["Percentage"],
    both       = LO["Numbers + %"],
    formatted  = LO["Current / Max"],
}

local dragonValues = {
    none      = LO["None"],
    elite     = LO["Elite (Golden)"],
    rareelite = LO["RareElite (Winged)"],
}

local alternateManaFormatValues = {
    numeric    = LO["Current Value"],
    formatted  = LO["Current / Max"],
    percentage = LO["Percentage"],
    both       = LO["Percentage + Current/Max"],
}

local partyOrientationValues = {
    vertical   = LO["Vertical"],
    horizontal = LO["Horizontal"],
}

local function RefreshUnitFramesTabAfterToggle(refreshFunc)
    if refreshFunc then
        refreshFunc()
    end
    if Panel and Panel.SelectTab then
        Panel:SelectTab("unitframes")
    end
end

local function HandleClassPortraitToggle(unitKey, refreshFunc, enabled)
    if enabled then
        C:SetDBValue("unitframe." .. unitKey .. ".alternativeClassIcons", true)
    end
    RefreshUnitFramesTabAfterToggle(refreshFunc)
end

local function ResetDetachedFrameToDatabaseDefaults(unitKey, refreshFunc)
    local defaults = addon.defaults and addon.defaults.profile
    local profile = addon.db and addon.db.profile

    if not (defaults and profile and defaults.unitframe and defaults.unitframe[unitKey]) then
        RefreshUnitFramesTabAfterToggle(refreshFunc)
        return
    end

    local function CopyValue(value)
        if type(addon.DeepCopy) == "function" then
            return addon.DeepCopy(value)
        end
        if type(value) ~= "table" then
            return value
        end

        local copy = {}
        for k, v in pairs(value) do
            copy[k] = CopyValue(v)
        end
        return copy
    end

    profile.unitframe = profile.unitframe or {}
    profile.unitframe[unitKey] = CopyValue(defaults.unitframe[unitKey])

    if defaults.widgets and defaults.widgets[unitKey] then
        profile.widgets = profile.widgets or {}
        profile.widgets[unitKey] = CopyValue(defaults.widgets[unitKey])
    end

    RefreshUnitFramesTabAfterToggle(refreshFunc)
end

-- ============================================================================
-- ACTIVE SUB-TAB STATE
-- ============================================================================

local activeSubTab = "player"

local subTabs = {
    { key = "player",   label = LO["Player"] },
    { key = "target",   label = LO["Target"] },
    { key = "focus",    label = LO["Focus"] },
    { key = "pet",      label = LO["Pet"] },
    { key = "tot",      label = LO["ToT / ToF"] },
    { key = "party",    label = LO["Party"] },
    { key = "boss",     label = LO["Boss"] },
    { key = "resource", label = LO["Personal Resource"] },
}

-- Search navigation sub-tab setter.
Panel.subTabSetters = Panel.subTabSetters or {}
Panel.subTabSetters["unitframes"] = function(key) activeSubTab = key end

-- ============================================================================
-- COMMON CONTROLS BUILDER
-- ============================================================================

local function AddCommonControls(parent, unitKey, refreshFunc, opts)
    opts = opts or {}

    C:AddSlider(parent, {
        label = LO["Scale"],
        dbPath = "unitframe." .. unitKey .. ".scale",
        min = 0.5, max = 2.0, step = 0.01,
        width = 200,
        callback = refreshFunc,
    })

    C:AddToggle(parent, {
        label = LO["Class Color Health"],
        dbPath = "unitframe." .. unitKey .. ".classcolor",
        callback = refreshFunc,
    })

    if opts.hasClassPortrait then
        C:AddToggle(parent, {
            label = LO["Class Portrait"],
            desc = LO["Class icon instead of 3D model for players."],
            dbPath = "unitframe." .. unitKey .. ".classPortrait",
            callback = function(value)
                HandleClassPortraitToggle(unitKey, refreshFunc, value)
            end,
        })

        C:AddToggle(parent, {
            label = LO["Alternative Class Icons"],
            desc = LO["Use DragonUI alternative class icons instead of Blizzard's class icon atlas."],
            dbPath = "unitframe." .. unitKey .. ".alternativeClassIcons",
            disabled = function()
                return not C:GetDBValue("unitframe." .. unitKey .. ".classPortrait")
            end,
            callback = refreshFunc,
        })
    end

    C:AddToggle(parent, {
        label = LO["Format Large Numbers"],
        dbPath = "unitframe." .. unitKey .. ".breakUpLargeNumbers",
        callback = refreshFunc,
    })

    C:AddDropdown(parent, {
        label = LO["Text Format"],
        dbPath = "unitframe." .. unitKey .. ".textFormat",
        values = textFormatValues,
        callback = refreshFunc,
    })

    C:AddToggle(parent, {
        label = LO["Always Show Health Text"],
        dbPath = "unitframe." .. unitKey .. ".showHealthTextAlways",
        callback = refreshFunc,
    })

    C:AddToggle(parent, {
        label = LO["Always Show Mana Text"],
        dbPath = "unitframe." .. unitKey .. ".showManaTextAlways",
        callback = refreshFunc,
    })

    if opts.hasThreatGlow then
        C:AddToggle(parent, {
            label = LO["Threat Glow"],
            dbPath = "unitframe." .. unitKey .. ".enableThreatGlow",
            callback = refreshFunc,
        })
    end
end

-- ============================================================================
-- SUB-TAB BUILDERS
-- ============================================================================

local function BuildPlayerSection(scroll)
    local refreshPlayer = function()
        if addon.PlayerFrame and addon.PlayerFrame.RefreshPlayerFrame then
            addon.PlayerFrame.RefreshPlayerFrame()
        end
    end

    local s = C:AddSection(scroll, LO["Player Frame"])
    AddCommonControls(s, "player", refreshPlayer, {
        hasClassPortrait = true,
    })

    C:AddDropdown(s, {
        label = LO["Dragon Decoration"],
        dbPath = "unitframe.player.dragon_decoration",
        values = dragonValues,
        callback = refreshPlayer,
    })

    -- Glow Effects
    C:AddHeading(s, LO["Glow Effects"])

    C:AddToggle(s, {
        label = LO["Show Rest Glow"],
        desc = LO["Golden glow around the player frame when resting (inn or city). Works with all frame modes."],
        dbPath = "unitframe.player.show_rest_glow",
        callback = refreshPlayer,
    })

    C:AddToggle(s, {
        label = LO["Show Combat Flash"],
        desc = LO["Pulsing glow effect when entering combat. Works with all frame modes."],
        dbPath = "unitframe.player.combat_flash_enabled",
        callback = function(val)
            refreshPlayer()
            Panel:SelectTab("unitframes")
        end,
    })

    C:AddSlider(s, {
        label = LO["Combat Flash Opacity"],
        desc = LO["Maximum opacity of the combat flash pulse effect."],
        dbPath = "unitframe.player.combat_flash_opacity",
        min = 0.1, max = 1.0, step = 0.05,
        width = 200,
        disabled = function()
            return not C:GetDBValue("unitframe.player.combat_flash_enabled")
        end,
        callback = refreshPlayer,
    })

    -- Alternate mana (druid)
    C:AddHeading(s, LO["Alternate Mana (Druid)"])

    C:AddToggle(s, {
        label = LO["Always Show"],
        desc = LO["Druid mana text visible at all times, not just on hover."],
        dbPath = "unitframe.player.alwaysShowAlternateManaText",
        callback = refreshPlayer,
    })

    C:AddDropdown(s, {
        label = LO["Text Format"],
        dbPath = "unitframe.player.alternateManaFormat",
        values = alternateManaFormatValues,
        callback = refreshPlayer,
    })

    -- Fat Health Bar
    C:AddHeading(s, LO["Fat Health Bar"])

    C:AddToggle(s, {
        label = LO["Enable"],
        desc = LO["Full-width health bar. Auto-disabled in vehicles."],
        dbPath = "unitframe.player.fat_healthbar",
        callback = function(val)
            refreshPlayer()
            -- Rebuild tab so disabled states on mana controls update
            Panel:SelectTab("unitframes")
        end,
    })

    C:AddToggle(s, {
        label = LO["Hide Mana Bar"],
        desc = LO["Completely hide the mana bar when Fat Health Bar is active."],
        dbPath = "unitframe.player.fat_manabar_hidden",
        disabled = function()
            return not C:GetDBValue("unitframe.player.fat_healthbar")
        end,
        callback = function(val)
            refreshPlayer()
            Panel:SelectTab("unitframes")
        end,
    })

    C:AddSlider(s, {
        label = LO["Mana Bar Width"],
        dbPath = "unitframe.player.fat_manabar_width",
        min = 50, max = 300, step = 1,
        width = 200,
        disabled = function()
            return not C:GetDBValue("unitframe.player.fat_healthbar")
        end,
        callback = refreshPlayer,
    })

    C:AddSlider(s, {
        label = LO["Mana Bar Height"],
        dbPath = "unitframe.player.fat_manabar_height",
        min = 4, max = 30, step = 1,
        width = 200,
        disabled = function()
            return not C:GetDBValue("unitframe.player.fat_healthbar")
        end,
        callback = refreshPlayer,
    })

    C:AddDropdown(s, {
        label = LO["Mana Bar Texture"],
        desc = LO["Choose the texture style for the power/mana bar. Only applies in Fat Health Bar mode."],
        dbPath = "unitframe.player.manabar_texture",
        values = {
            dragonui       = LO["DragonUI (Default)"],
            blizzard       = LO["Blizzard Classic"],
            blizzard_flat  = LO["Flat Solid"],
            smooth         = LO["Smooth"],
            aluminium      = LO["Aluminium"],
            litestep       = LO["LiteStep"],
        },
        disabled = function()
            return not C:GetDBValue("unitframe.player.fat_healthbar")
        end,
        callback = function()
            refreshPlayer()
            Panel:SelectTab("unitframes")
        end,
    })

    -- Power bar color pickers (only visible when using override textures in fat mode)
    local isFat = C:GetDBValue("unitframe.player.fat_healthbar")
    local texSetting = C:GetDBValue("unitframe.player.manabar_texture") or "dragonui"
    local showColors = isFat and texSetting ~= "dragonui"

    if showColors then
        C:AddHeading(s, LO["Power Bar Colors"])

        local powerColorEntries = {
            { key = "MANA",        label = LO["Mana"] },
            { key = "RAGE",        label = LO["Rage"] },
            { key = "ENERGY",      label = LO["Energy"] },
            { key = "FOCUS",       label = LO["Focus"] },
            { key = "RUNIC_POWER", label = LO["Runic Power"] },
            { key = "HAPPINESS",   label = LO["Happiness"] },
            { key = "RUNES",       label = LO["Runes"] },
        }

        for _, entry in ipairs(powerColorEntries) do
            C:AddColorPicker(s, {
                label = entry.label,
                dbPath = "unitframe.player.power_colors." .. entry.key,
                hasAlpha = false,
                callback = function() refreshPlayer() end,
            })
        end

        C:AddButton(s, {
            label = LO["Reset Colors to Default"],
            width = 200,
            callback = function()
                local defaults = {
                    MANA         = { r = 0.02, g = 0.32, b = 0.71 },
                    RAGE         = { r = 1.00, g = 0.00, b = 0.00 },
                    FOCUS        = { r = 1.00, g = 0.50, b = 0.25 },
                    ENERGY       = { r = 1.00, g = 1.00, b = 0.00 },
                    HAPPINESS    = { r = 0.00, g = 1.00, b = 1.00 },
                    RUNES        = { r = 0.50, g = 0.50, b = 0.50 },
                    RUNIC_POWER  = { r = 0.00, g = 0.82, b = 1.00 },
                }
                C:SetDBValue("unitframe.player.power_colors", defaults)
                refreshPlayer()
                Panel:SelectTab("unitframes")
            end,
        })
    end

    C:AddHeading(s, LO["Visibility"])
    C:AddVisibilityFadeToggles(s, {
        dbPrefix = "unitframe.player",
        hoverDesc = LO["Fade the player frame until you hover over it."],
        combatDesc = LO["Fade the player frame until you enter combat."],
        callback = refreshPlayer,
    })
end

local function BuildTargetSection(scroll)
    local refreshTarget = function()
        if addon.TargetFrame and addon.TargetFrame.RefreshTargetFrame then
            addon.TargetFrame.RefreshTargetFrame()
        end
    end

    local s = C:AddSection(scroll, LO["Target Frame"])
    AddCommonControls(s, "target", refreshTarget, {
        hasClassPortrait = true,
    })

    C:AddToggle(s, {
        label = LO["Show Name Background"],
        desc = LO["Show the colored name background behind the target name."],
        dbPath = "unitframe.target.show_name_background",
        callback = refreshTarget,
    })

    C:AddHeading(s, LO["Visibility"])
    C:AddDescription(s, LO["Also fades the Target of Target and target cast bar, attached or not."])
    C:AddVisibilityFadeToggles(s, {
        dbPrefix = "unitframe.target",
        hoverDesc = LO["Fade the target frame group until you hover over it."],
        combatDesc = LO["Fade the target frame group until you enter combat."],
        callback = refreshTarget,
    })
end

local function BuildFocusSection(scroll)
    local refreshFocus = function()
        if addon.RefreshFocusFrame then addon.RefreshFocusFrame() end
    end

    local s = C:AddSection(scroll, LO["Focus Frame"])
    AddCommonControls(s, "focus", refreshFocus, {
        hasClassPortrait = true,
    })

    C:AddToggle(s, {
        label = LO["Show Name Background"],
        desc = LO["Show the colored name background behind the focus name."],
        dbPath = "unitframe.focus.show_name_background",
        callback = refreshFocus,
    })

    C:AddToggle(s, {
        label = LO["Show Buff/Debuff on Focus"],
        desc = LO["Uses the native large focus frame mode to show buffs and debuffs on the focus frame."],
        dbPath = "unitframe.focus.show_buff_debuff",
        callback = refreshFocus,
    })

    C:AddHeading(s, LO["Visibility"])
    C:AddDescription(s, LO["Also fades the Target of Focus and focus cast bar, attached or not."])
    C:AddVisibilityFadeToggles(s, {
        dbPrefix = "unitframe.focus",
        hoverDesc = LO["Fade the focus frame group until you hover over it."],
        combatDesc = LO["Fade the focus frame group until you enter combat."],
        callback = refreshFocus,
    })
end

local function BuildPetSection(scroll)
    local refreshPet = function()
        if addon.RefreshPetFrame then addon.RefreshPetFrame() end
    end

    local s = C:AddSection(scroll, LO["Pet Frame"])

    C:AddSlider(s, {
        label = LO["Scale"],
        dbPath = "unitframe.pet.scale",
        min = 0.5, max = 2.0, step = 0.01,
        width = 200,
        callback = refreshPet,
    })

    C:AddDropdown(s, {
        label = LO["Text Format"],
        dbPath = "unitframe.pet.textFormat",
        values = textFormatValues,
        callback = refreshPet,
    })

    C:AddToggle(s, {
        label = LO["Format Large Numbers"],
        dbPath = "unitframe.pet.breakUpLargeNumbers",
        callback = refreshPet,
    })

    C:AddToggle(s, {
        label = LO["Always Show Health Text"],
        dbPath = "unitframe.pet.showHealthTextAlways",
        callback = refreshPet,
    })

    C:AddToggle(s, {
        label = LO["Always Show Mana Text"],
        dbPath = "unitframe.pet.showManaTextAlways",
        callback = refreshPet,
    })

    C:AddToggle(s, {
        label = LO["Threat Glow"],
        dbPath = "unitframe.pet.enableThreatGlow",
        callback = refreshPet,
    })

    C:AddHeading(s, LO["Position"])

    local positionWidgets = {}
    local function RegisterPositionWidget(widget, disabledFunc)
        table.insert(positionWidgets, { widget = widget, disabledFunc = disabledFunc })
        return widget
    end
    local function RefreshPositionControlStates()
        for _, entry in ipairs(positionWidgets) do
            if entry.widget and entry.widget.SetDisabled and entry.disabledFunc then
                entry.widget:SetDisabled(entry.disabledFunc())
            end
        end
    end
    -- Only used while attached; detached position comes from Editor Mode.
    local IsPetAttached = function()
        return C:GetDBValue("unitframe.pet.override")
    end

    C:AddToggle(s, {
        label = LO["Override Position"],
        desc = LO["Move the pet frame independently from the player frame."],
        dbPath = "unitframe.pet.override",
        callback = function()
            refreshPet()
            RefreshPositionControlStates()
        end,
    })

    RegisterPositionWidget(C:AddSlider(s, {
        label = LO["X Position"],
        dbPath = "unitframe.pet.x",
        min = -2500, max = 2500, step = 1,
        width = 200,
        disabled = IsPetAttached,
        callback = refreshPet,
    }), IsPetAttached)

    RegisterPositionWidget(C:AddSlider(s, {
        label = LO["Y Position"],
        dbPath = "unitframe.pet.y",
        min = -2500, max = 2500, step = 1,
        width = 200,
        disabled = IsPetAttached,
        callback = refreshPet,
    }), IsPetAttached)

    C:AddHeading(s, LO["Visibility"])
    C:AddVisibilityFadeToggles(s, {
        dbPrefix = "unitframe.pet",
        hoverDesc = LO["Fade the pet frame until you hover over it."],
        combatDesc = LO["Fade the pet frame until you enter combat."],
        callback = refreshPet,
    })
end

local function BuildToTSection(scroll)
    local refreshToT = function()
        if addon.TargetOfTarget and addon.TargetOfTarget.RefreshToTFrame then
            addon.TargetOfTarget.RefreshToTFrame()
        end
    end

    local tot = C:AddSection(scroll, LO["Target of Target"])
    C:AddDescription(tot,
        LO["Follows the Target frame by default. Move it in Editor Mode (/dragonui edit) to detach and position freely."])

    C:AddSlider(tot, {
        label = LO["Scale"],
        dbPath = "unitframe.tot.scale",
        min = 0.5, max = 2.0, step = 0.01,
        width = 200,
        callback = refreshToT,
    })

    C:AddToggle(tot, {
        label = LO["Class Color Health"],
        dbPath = "unitframe.tot.classcolor",
        callback = refreshToT,
    })

    C:AddToggle(tot, {
        label = LO["Class Portrait"],
        dbPath = "unitframe.tot.classPortrait",
        callback = function(value)
            HandleClassPortraitToggle("tot", refreshToT, value)
        end,
    })

    C:AddToggle(tot, {
        label = LO["Alternative Class Icons"],
        desc = LO["Use DragonUI alternative class icons instead of Blizzard's class icon atlas."],
        dbPath = "unitframe.tot.alternativeClassIcons",
        disabled = function()
            return not C:GetDBValue("unitframe.tot.classPortrait")
        end,
        callback = refreshToT,
    })

    -- Attachment status indicator
    local totOverride = C:GetDBValue("unitframe.tot.override")
    if totOverride then
        C:AddDescription(tot, "|cff1784d1- " .. LO["Detached — positioned freely via Editor Mode"] .. "|r")
    else
        C:AddDescription(tot, "|cffaaaaaa- " .. LO["Attached — follows Target frame"] .. "|r")
    end

    -- Re-attach button (only useful when detached)
    C:AddButton(tot, {
        label = LO["Re-attach to Target"],
        width = 200,
        disabled = function() return not C:GetDBValue("unitframe.tot.override") end,
        callback = function()
            ResetDetachedFrameToDatabaseDefaults("tot", refreshToT)
        end,
    })

    -- ====================================================================
    -- Target of Focus
    -- ====================================================================
    local refreshToF = function()
        if addon.TargetOfFocus and addon.TargetOfFocus.RefreshToFFrame then
            addon.TargetOfFocus.RefreshToFFrame()
        end
    end

    local fot = C:AddSection(scroll, LO["Target of Focus"])
    C:AddDescription(fot,
        LO["Follows the Focus frame by default. Move it in Editor Mode (/dragonui edit) to detach and position freely."])

    C:AddSlider(fot, {
        label = LO["Scale"],
        dbPath = "unitframe.fot.scale",
        min = 0.5, max = 2.0, step = 0.01,
        width = 200,
        callback = refreshToF,
    })

    C:AddToggle(fot, {
        label = LO["Class Color Health"],
        dbPath = "unitframe.fot.classcolor",
        callback = refreshToF,
    })

    C:AddToggle(fot, {
        label = LO["Class Portrait"],
        dbPath = "unitframe.fot.classPortrait",
        callback = function(value)
            HandleClassPortraitToggle("fot", refreshToF, value)
        end,
    })

    C:AddToggle(fot, {
        label = LO["Alternative Class Icons"],
        desc = LO["Use DragonUI alternative class icons instead of Blizzard's class icon atlas."],
        dbPath = "unitframe.fot.alternativeClassIcons",
        disabled = function()
            return not C:GetDBValue("unitframe.fot.classPortrait")
        end,
        callback = refreshToF,
    })

    -- Attachment status indicator
    local fotOverride = C:GetDBValue("unitframe.fot.override")
    if fotOverride then
        C:AddDescription(fot, "|cff1784d1- " .. LO["Detached — positioned freely via Editor Mode"] .. "|r")
    else
        C:AddDescription(fot, "|cffaaaaaa- " .. LO["Attached — follows Focus frame"] .. "|r")
    end

    -- Re-attach button (only useful when detached)
    C:AddButton(fot, {
        label = LO["Re-attach to Focus"],
        width = 200,
        disabled = function() return not C:GetDBValue("unitframe.fot.override") end,
        callback = function()
            ResetDetachedFrameToDatabaseDefaults("fot", refreshToF)
        end,
    })
end

local function BuildPartySection(scroll)
    local refreshParty = function()
        if addon.RefreshPartyFrames then addon.RefreshPartyFrames() end
    end

    local s = C:AddSection(scroll, LO["Party Frames"])

    C:AddSlider(s, {
        label = LO["Scale"],
        dbPath = "unitframe.party.scale",
        min = 0.5, max = 2.0, step = 0.01,
        width = 200,
        callback = refreshParty,
    })

    C:AddToggle(s, {
        label = LO["Class Color Health"],
        dbPath = "unitframe.party.classcolor",
        callback = refreshParty,
    })

    C:AddToggle(s, {
        label = LO["Format Large Numbers"],
        dbPath = "unitframe.party.breakUpLargeNumbers",
        callback = refreshParty,
    })

    C:AddToggle(s, {
        label = LO["Always Show Health Text"],
        dbPath = "unitframe.party.showHealthTextAlways",
        callback = refreshParty,
    })

    C:AddToggle(s, {
        label = LO["Always Show Mana Text"],
        dbPath = "unitframe.party.showManaTextAlways",
        callback = refreshParty,
    })

    C:AddDropdown(s, {
        label = LO["Text Format"],
        dbPath = "unitframe.party.textFormat",
        values = textFormatValues,
        callback = refreshParty,
    })

    C:AddDropdown(s, {
        label = LO["Orientation"],
        dbPath = "unitframe.party.orientation",
        values = partyOrientationValues,
        callback = refreshParty,
    })

    C:AddSlider(s, {
        label = LO["Vertical Padding"],
        desc = LO["Space between party frames in vertical mode."],
        dbPath = "unitframe.party.padding_vertical",
        min = 10, max = 150, step = 1,
        width = 200,
        callback = refreshParty,
    })

    C:AddSlider(s, {
        label = LO["Horizontal Padding"],
        desc = LO["Space between party frames in horizontal mode."],
        dbPath = "unitframe.party.padding_horizontal",
        min = 10, max = 150, step = 1,
        width = 200,
        callback = refreshParty,
    })

    C:AddHeading(s, LO["Visibility"])
    C:AddVisibilityFadeToggles(s, {
        dbPrefix = "unitframe.party",
        hoverDesc = LO["Fade party frames until you hover over them."],
        combatDesc = LO["Fade party frames until you enter combat."],
        callback = refreshParty,
    })
end

local function BuildBossSection(scroll)
    local refreshBoss = function()
        if addon.RefreshBossFrames then addon.RefreshBossFrames() end
    end

    local s = C:AddSection(scroll, LO["Boss Frames"])

    C:AddSlider(s, {
        label = LO["Scale"],
        dbPath = "unitframe.boss.scale",
        min = 0.5, max = 2.0, step = 0.01,
        width = 200,
        callback = refreshBoss,
    })

    C:AddHeading(s, LO["Visibility"])
    C:AddVisibilityFadeToggles(s, {
        dbPrefix = "unitframe.boss",
        hoverDesc = LO["Fade boss frames until you hover over them."],
        combatDesc = LO["Fade boss frames until you enter combat."],
        callback = refreshBoss,
    })
end

-- ============================================================================
-- BUFF TRACKER (above Personal Resource Display)
-- ============================================================================

local buffTrackerWatchTab = "classes_actives"
local buffTrackerClass = "WARRIOR"

local function BuildBuffTrackerSection(scroll)
    local function EnsureModuleTable(moduleName)
        return C:EnsureModuleTable(moduleName)
    end

    local function GetModuleField(moduleName, field)
        local m = addon.db.profile.modules
        return m and m[moduleName] and m[moduleName][field]
    end

    local function IsBuffTrackerEnabled()
        return GetModuleField("bufftracker", "enabled") == true
    end

    local function RefreshBuffTracker()
        if addon.RefreshBuffTracker then addon.RefreshBuffTracker() end
    end

    C:AddSpacer(scroll)
    local buffTrackerSection = C:AddSection(scroll, LO["Buff Tracker"])

    local BT_DB = "modules.bufftracker"

    C:AddDescription(buffTrackerSection, LO["Shows selected player buff and debuff icons above the Personal Resource Display using action bar-style icon borders."])

    C:AddToggle(buffTrackerSection, {
        label = LO["Enable Buff Tracker"],
        desc = LO["Track configured player buffs above the Personal Resource Display."],
        getFunc = function() return IsBuffTrackerEnabled() end,
        setFunc = function(val)
            EnsureModuleTable("bufftracker").enabled = val
            RefreshBuffTracker()
        end,
    })

    C:AddToggle(buffTrackerSection, {
        label = LO["Require Personal Resource Display"],
        desc = LO["Hide the buff tracker when the Personal Resource Display is disabled."],
        getFunc = function() return GetModuleField("bufftracker", "require_prd") ~= false end,
        setFunc = function(val)
            EnsureModuleTable("bufftracker").require_prd = val
            RefreshBuffTracker()
        end,
        disabled = function() return not IsBuffTrackerEnabled() end,
    })

    C:AddHeading(buffTrackerSection, LO["Track Categories"])

    local categoryToggles = {
        { key = "classes_actives", label = LO["Track Class Actives"] or "Track Class Actives" },
        { key = "classes_passives", label = LO["Track Class Passives"] or "Track Class Passives" },
        { key = "buffs", label = LO["Track Buffs"] or "Track Buffs" },
        { key = "procs", label = LO["Track Procs"] or "Track Procs" },
        { key = "consume", label = LO["Track Consumables"] or "Track Consumables" },
        { key = "stacks", label = LO["Track Target Stacks"] or "Track Target Stacks" },
        { key = "enchants", label = LO["Track Enchants"] or "Track Enchants" },
    }

    for _, cat in ipairs(categoryToggles) do
        C:AddToggle(buffTrackerSection, {
            label = cat.label,
            getFunc = function()
                local cats = GetModuleField("bufftracker", "categories")
                if cats and cats[cat.key] ~= nil then
                    return cats[cat.key] == true
                end
                return cat.key == "classes_actives" or cat.key == "classes_passives" or cat.key == "procs"
            end,
            setFunc = function(val)
                EnsureModuleTable("bufftracker")
                local mod = addon.db.profile.modules.bufftracker
                mod.categories = mod.categories or {}
                mod.categories[cat.key] = val
                RefreshBuffTracker()
            end,
            disabled = function() return not IsBuffTrackerEnabled() end,
        })
    end

    C:AddToggle(buffTrackerSection, {
        label = LO["Track Target Debuffs"],
        -- desc = LO["Show your target debuffs (Sunder Armor, diseases, etc.) above the Personal Resource Display. Disable to track them on nameplates only."],
        getFunc = function() return GetModuleField("bufftracker", "track_target_debuffs") ~= false end,
        setFunc = function(val)
            EnsureModuleTable("bufftracker").track_target_debuffs = val
            RefreshBuffTracker()
        end,
        disabled = function() return not IsBuffTrackerEnabled() end,
    })

    C:AddToggle(buffTrackerSection, {
        label = LO["Show Tooltip on Hover"],
        desc = LO["Show the spell tooltip when hovering a tracked icon."],
        getFunc = function() return GetModuleField("bufftracker", "show_tooltip") == true end,
        setFunc = function(val)
            EnsureModuleTable("bufftracker").show_tooltip = val
            RefreshBuffTracker()
        end,
        disabled = function() return not IsBuffTrackerEnabled() end,
    })

    C:AddSlider(buffTrackerSection, {
        label = LO["Icon Size"],
        desc = LO["Size of each tracked buff icon."],
        min = 20, max = 48, step = 1,
        getFunc = function() return GetModuleField("bufftracker", "icon_size") or 32 end,
        setFunc = function(val) EnsureModuleTable("bufftracker").icon_size = val end,
        callback = RefreshBuffTracker,
        disabled = function() return not IsBuffTrackerEnabled() end,
        width = 200,
    })

    C:AddSlider(buffTrackerSection, {
        label = LO["Icon Spacing"],
        desc = LO["Gap between tracked buff icons."],
        min = 0, max = 16, step = 1,
        getFunc = function() return GetModuleField("bufftracker", "icon_spacing") or 4 end,
        setFunc = function(val) EnsureModuleTable("bufftracker").icon_spacing = val end,
        callback = RefreshBuffTracker,
        disabled = function() return not IsBuffTrackerEnabled() end,
        width = 200,
    })

    C:AddSlider(buffTrackerSection, {
        label = LO["Offset Above PRD"],
        desc = LO["Vertical gap between the Personal Resource Display and the buff row."],
        min = 0, max = 40, step = 1,
        getFunc = function() return GetModuleField("bufftracker", "row_offset_y") or 6 end,
        setFunc = function(val) EnsureModuleTable("bufftracker").row_offset_y = val end,
        callback = RefreshBuffTracker,
        disabled = function() return not IsBuffTrackerEnabled() end,
        width = 200,
    })

    C:AddToggle(buffTrackerSection, {
        label = LO["Show Duration"],
        desc = LO["Show remaining time on tracked buff icons."],
        getFunc = function() return GetModuleField("bufftracker", "show_duration") ~= false end,
        setFunc = function(val) EnsureModuleTable("bufftracker").show_duration = val end,
        callback = RefreshBuffTracker,
        disabled = function() return not IsBuffTrackerEnabled() end,
    })

    C:AddToggle(buffTrackerSection, {
        label = LO["Show Stacks"],
        desc = LO["Show stack count when a tracked aura has more than one application."],
        getFunc = function() return GetModuleField("bufftracker", "show_stacks") ~= false end,
        setFunc = function(val) EnsureModuleTable("bufftracker").show_stacks = val end,
        callback = RefreshBuffTracker,
        disabled = function() return not IsBuffTrackerEnabled() end,
    })

    C:AddHeading(buffTrackerSection, LO["Low-Time Buffs"])

    C:AddDescription(buffTrackerSection, LO["Applies to shouts, blessings, flasks, food, and other watchlist entries marked as low-time."])

    C:AddDropdown(buffTrackerSection, {
        label = LO["Low-Time Show Mode"],
        desc = LO["When to show low-time tracked buff and consumable icons."],
        values = {
            low_time = LO["Below percent only"] or "Below percent only",
            always = LO["Always while active"] or "Always while active",
            never = LO["Never"] or "Never",
        },
        getFunc = function() return GetModuleField("bufftracker", "buff_low_time_show_mode") or "low_time" end,
        setFunc = function(val) EnsureModuleTable("bufftracker").buff_low_time_show_mode = val end,
        callback = RefreshBuffTracker,
        disabled = function() return not IsBuffTrackerEnabled() end,
        width = 260,
    })

    C:AddSlider(buffTrackerSection, {
        label = LO["Low-Time Percent"],
        desc = LO["Show icons when remaining duration is at or below this percentage of the buff total. Default 10% = last tenth of the timer."],
        min = 5, max = 50, step = 1,
        getFunc = function()
            return math.floor(((GetModuleField("bufftracker", "buff_low_time_percent") or 0.10) * 100) + 0.5)
        end,
        setFunc = function(val)
            EnsureModuleTable("bufftracker").buff_low_time_percent = val / 100
        end,
        callback = RefreshBuffTracker,
        disabled = function()
            return not IsBuffTrackerEnabled()
                or (GetModuleField("bufftracker", "buff_low_time_show_mode") or "low_time") ~= "low_time"
        end,
        width = 200,
    })

    C:AddSlider(buffTrackerSection, {
        label = LO["Low-Time Fallback (sec)"],
        desc = LO["When total duration is unknown, show icons below this many seconds remaining. Default 300 = 5 minutes."],
        min = 30, max = 900, step = 30,
        getFunc = function() return GetModuleField("bufftracker", "buff_low_time_threshold_sec") or 300 end,
        setFunc = function(val) EnsureModuleTable("bufftracker").buff_low_time_threshold_sec = val end,
        callback = RefreshBuffTracker,
        disabled = function()
            return not IsBuffTrackerEnabled()
                or (GetModuleField("bufftracker", "buff_low_time_show_mode") or "low_time") ~= "low_time"
        end,
        width = 200,
    })

    C:AddHeading(buffTrackerSection, LO["Consumables"])

    C:AddDescription(buffTrackerSection, LO["Flasks, elixirs, and food use the Low-Time Buffs settings above."])

    C:AddToggle(buffTrackerSection, {
        label = LO["Expired Consumable Glow"],
        desc = LO["Pulse a small glow when a tracked consumable falls off."],
        getFunc = function() return GetModuleField("bufftracker", "consumable_expired_glow") ~= false end,
        setFunc = function(val) EnsureModuleTable("bufftracker").consumable_expired_glow = val end,
        disabled = function() return not IsBuffTrackerEnabled() end,
    })

    C:AddSlider(buffTrackerSection, {
        label = LO["Expired Glow Scale"],
        min = 1.0, max = 2.0, step = 0.05,
        getFunc = function() return GetModuleField("bufftracker", "consumable_glow_scale") or 1.2 end,
        setFunc = function(val) EnsureModuleTable("bufftracker").consumable_glow_scale = val end,
        disabled = function()
            return not IsBuffTrackerEnabled()
                or GetModuleField("bufftracker", "consumable_expired_glow") == false
        end,
        width = 200,
    })

    --[[
    C:AddHeading(buffTrackerSection, LO["Preview"])

    C:AddButton(buffTrackerSection, {
        label = LO["Preview Buffs"],
        desc = LO["Show sample buff icons above PRD for a few seconds without needing active auras."],
        callback = function()
            local previewFn = (addon.BuffTrackerPreview and addon.BuffTrackerPreview.Preview)
                or DragonUIBuffTracker_Preview
            if previewFn then
                pcall(previewFn)
            end
        end,
        disabled = function() return not IsBuffTrackerEnabled() end,
        width = 220,
    })

    C:AddButton(buffTrackerSection, {
        label = LO["Stop Buff Preview"],
        desc = LO["Clear the buff tracker preview."],
        callback = function()
            local stopFn = (addon.BuffTrackerPreview and addon.BuffTrackerPreview.Stop)
                or DragonUIBuffTracker_StopPreview
            if stopFn then stopFn() end
        end,
        disabled = function() return not IsBuffTrackerEnabled() end,
        width = 220,
    })
    ]]

    --[[
    C:AddSpacer(buffTrackerSection)
    C:AddLabel(buffTrackerSection, LO["Watch Lists"], { color = C.Theme.textGold })
    C:AddDescription(buffTrackerSection, LO["Add spell IDs to track. Icons appear in category order, then by activation order within each category."])

    local watchSubTabs = {
        { key = "classes_actives", label = LO["Class Actives"] or "Class Actives" },
        { key = "classes_passives", label = LO["Class Passives"] or "Class Passives" },
        { key = "buffs", label = LO["Track Buffs"] or "Buffs" },
        { key = "procs", label = LO["Track Procs"] or "Procs" },
        { key = "consume", label = LO["Track Consumables"] or "Consumables" },
        { key = "stacks", label = LO["Track Target Stacks"] or "Stacks" },
        { key = "enchants", label = LO["Track Enchants"] or "Enchants" },
    }

    local classValues = {
        WARRIOR = LO["Warrior"] or "Warrior",
        PALADIN = LO["Paladin"] or "Paladin",
        HUNTER = LO["Hunter"] or "Hunter",
        ROGUE = LO["Rogue"] or "Rogue",
        PRIEST = LO["Priest"] or "Priest",
        DEATHKNIGHT = LO["Death Knight"] or "Death Knight",
        SHAMAN = LO["Shaman"] or "Shaman",
        MAGE = LO["Mage"] or "Mage",
        WARLOCK = LO["Warlock"] or "Warlock",
        DRUID = LO["Druid"] or "Druid",
    }

    local function BuildWatchListTab(scrollChild)
        local listKey = buffTrackerWatchTab
        local dbListPath
        local dbBorderPath

        if listKey == "classes_actives" or listKey == "classes_passives" then
            local branch = listKey == "classes_actives" and "actives" or "passives"
            dbListPath = BT_DB .. ".lists.classes." .. branch .. "." .. buffTrackerClass .. ".spell_ids"
            dbBorderPath = BT_DB .. ".lists.classes." .. branch .. "." .. buffTrackerClass .. ".border_mode"
            C:AddDropdown(scrollChild, {
                label = LO["Class"],
                values = classValues,
                getFunc = function() return buffTrackerClass end,
                setFunc = function(val)
                    buffTrackerClass = val
                    Panel:SelectTab("unitframes")
                end,
                disabled = function() return not IsBuffTrackerEnabled() end,
                width = 200,
            })
        else
            dbListPath = BT_DB .. ".lists." .. listKey .. ".spell_ids"
            dbBorderPath = BT_DB .. ".lists." .. listKey .. ".border_mode"
        end

        C:AddDropdown(scrollChild, {
            label = LO["Category Border Color"],
            desc = LO["Default border color for spells in this watch list."],
            values = borderModeValues,
            getFunc = function() return C:GetDBValue(dbBorderPath) or "red" end,
            setFunc = function(val) C:SetDBValue(dbBorderPath, val) end,
            callback = RefreshBuffTracker,
            disabled = function() return not IsBuffTrackerEnabled() end,
            width = 260,
        })

        C:AddSpellFilterList(scrollChild, {
            dbPath = dbListPath,
            disabled = function() return not IsBuffTrackerEnabled() end,
            callback = RefreshBuffTracker,
            rebuildUI = function()
                Panel:SelectTab("unitframes")
            end,
        })
    end

    local watchBuilders = {}
    for _, tab in ipairs(watchSubTabs) do
        watchBuilders[tab.key] = BuildWatchListTab
    end

    C:AddSubTabs(buffTrackerSection, watchSubTabs, buffTrackerWatchTab, function(key)
        buffTrackerWatchTab = key
        Panel:SelectTab("unitframes")
    end, watchBuilders)

    if not Panel.indexing then
        local watchBuilder = watchBuilders[buffTrackerWatchTab]
        if watchBuilder then
            watchBuilder(buffTrackerSection)
        end
    end
    ]]
end

local function BuildPersonalResourceSection(scroll)
    local refresh = function()
        if addon.RefreshPlayerResourceSystem then
            addon.RefreshPlayerResourceSystem()
        end
    end

    local enabled = addon.IsModuleEnabled and addon:IsModuleEnabled("player_resource")
    if not enabled then
        C:AddDescription(scroll, LO["Enable Player Resource Display under Modules to configure these options."])
    else
    local textFormats = {
        numeric    = LO["Current Value"],
        percentage = LO["Percentage"],
        both       = LO["Numbers + %"],
        formatted  = LO["Current / Max"],
    }

    local size = C:AddSection(scroll, LO["Size"])
    C:AddSlider(size, {
        label = LO["Width"],
        dbPath = "modules.player_resource.width",
        min = 100, max = 400, step = 1,
        callback = refresh,
    })
    C:AddSlider(size, {
        label = LO["Health Height"],
        dbPath = "modules.player_resource.health_height",
        min = 8, max = 40, step = 1,
        callback = refresh,
    })
    C:AddSlider(size, {
        label = LO["Power Height"],
        dbPath = "modules.player_resource.power_height",
        min = 8, max = 40, step = 1,
        callback = refresh,
    })
    C:AddDropdown(size, {
        label = LO["Bar Texture"],
        desc = LO["Status bar texture for health and power."],
        dbPath = "modules.player_resource.bar_texture",
        values = {
            blizzard      = LO["Blizzard Classic"],
            dragonui      = LO["DragonUI (Default)"],
            blizzard_flat = LO["Flat Solid"],
            smooth        = LO["Smooth"],
            aluminium     = LO["Aluminium"],
            litestep      = LO["LiteStep"],
        },
        order = { "blizzard", "dragonui", "blizzard_flat", "smooth", "aluminium", "litestep" },
        callback = refresh,
    })
    -- PRD heal prediction disabled for now.
    --[[
    C:AddToggle(size, {
        label = LO["Heal Prediction"],
        desc = LO["Show incoming heal prediction on the personal resource health bar. Requires Unit Frame Layers to be enabled."],
        dbPath = "modules.player_resource.heal_prediction",
        disabled = function()
            return not (addon.IsModuleEnabled and addon:IsModuleEnabled("unitframe_layers"))
        end,
        callback = refresh,
    })
    C:AddButton(size, {
        label = LO["Test Heal Prediction"],
        desc = LO["Fake low health with incoming heal and absorb overlays for a few seconds."],
        width = 200,
        disabled = function()
            return not (addon.IsModuleEnabled and addon:IsModuleEnabled("unitframe_layers"))
        end,
        callback = function()
            if not (addon.IsModuleEnabled and addon:IsModuleEnabled("unitframe_layers")) then
                return
            end
            if addon.TestPlayerResourceHealPrediction then
                addon.TestPlayerResourceHealPrediction(8)
            elseif addon.UFL_TestHealPrediction then
                addon.UFL_TestHealPrediction(8)
            end
        end,
    })
    ]]

    local text = C:AddSection(scroll, LO["Text"])
    C:AddToggle(text, {
        label = LO["Show Health Text"],
        dbPath = "modules.player_resource.show_health_text",
        callback = refresh,
    })
    C:AddDropdown(text, {
        label = LO["Health Text Format"],
        dbPath = "modules.player_resource.health_text_format",
        values = textFormats,
        callback = refresh,
    })
    C:AddToggle(text, {
        label = LO["Show Power Text"],
        dbPath = "modules.player_resource.show_power_text",
        callback = refresh,
    })
    C:AddDropdown(text, {
        label = LO["Power Text Format"],
        dbPath = "modules.player_resource.power_text_format",
        values = textFormats,
        callback = refresh,
    })
    C:AddSlider(text, {
        label = LO["Text Size"],
        dbPath = "modules.player_resource.text_size",
        min = 8, max = 20, step = 1,
        callback = refresh,
    })
    C:AddToggle(text, {
        label = LO["Format Large Numbers"],
        dbPath = "modules.player_resource.break_up_large_numbers",
        callback = refresh,
    })

    local vis = C:AddSection(scroll, LO["Show When"])
    C:AddDescription(vis, LO["Leave all show conditions off to always display the bars. Enable one or more to limit when they appear."])
    C:AddVisibilityFadeToggles(vis, {
        dbPrefix = "modules.player_resource",
        hideInCombat = true,
        hoverDesc = LO["Only show the personal resource display while the mouse is over it."],
        combatDesc = LO["Only show the personal resource display while in combat."],
        hideInCombatDesc = LO["Hide the personal resource display while in combat."],
        callback = refresh,
    })
    C:AddToggle(vis, {
        label = LO["Show When Health Below"],
        desc = LO["Show when player health is at or below the percent threshold."],
        dbPath = "modules.player_resource.show_when_health_below",
        callback = refresh,
    })
    C:AddSlider(vis, {
        label = LO["Health Below %"],
        dbPath = "modules.player_resource.health_below_percent",
        min = 1, max = 100, step = 1,
        callback = refresh,
    })
    C:AddToggle(vis, {
        label = LO["Show When Power Below"],
        desc = LO["Show when player power (mana/rage/energy/runic) is at or below the percent threshold."],
        dbPath = "modules.player_resource.show_when_power_below",
        callback = refresh,
    })
    C:AddSlider(vis, {
        label = LO["Power Below %"],
        dbPath = "modules.player_resource.power_below_percent",
        min = 1, max = 100, step = 1,
        callback = refresh,
    })
    end

    BuildBuffTrackerSection(scroll)
end

-- ============================================================================
-- SUB-TAB DISPATCH
-- ============================================================================

local subTabBuilders = {
    player   = BuildPlayerSection,
    target   = BuildTargetSection,
    focus    = BuildFocusSection,
    pet      = BuildPetSection,
    tot      = BuildToTSection,
    party    = BuildPartySection,
    boss     = BuildBossSection,
    resource = BuildPersonalResourceSection,
}

-- ============================================================================
-- MAIN TAB BUILDER
-- ============================================================================

local function BuildUnitframesTab(scroll)
    C:AddSubTabs(scroll, subTabs, activeSubTab, function(key)
        activeSubTab = key
        Panel:SelectTab("unitframes")
    end, subTabBuilders)

    -- AddSubTabs already harvests all sub-tabs during indexing.
    if not Panel.indexing then
        local builder = subTabBuilders[activeSubTab]
        if builder then builder(scroll) end
    end
end

-- Register the tab
Panel:RegisterTab("unitframes", LO["Unit Frames"], BuildUnitframesTab, 6)
