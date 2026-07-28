local addon = select(2, ...)
if not addon then addon = _G.DragonUI end

local BT = DragonUIBuffTracker

-- ============================================================================
-- Layout: horizontal icon row above Personal Resource Display
-- ============================================================================

BT.layoutState = BT.layoutState or {
	container = nil,
	iconsByKey = {},
}

local function GetConfig()
	return addon:GetModuleConfig("bufftracker")
end

local DEFAULT_STRATA = "MEDIUM"
local DEFAULT_LEVEL = 20
local UNDER_OPTIONS_STRATA = "BACKGROUND"

local function IsOptionsPanelOpen()
	local frame = _G.DragonUIOptionsPanel
	if frame and frame.IsShown and frame:IsShown() then
		return true
	end
	local panel = addon.OptionsPanel
	return panel and panel.IsOpen and panel:IsOpen() or false
end

function BT.SyncContainerStrata()
	local container = BT.layoutState and BT.layoutState.container
	if not container then
		return
	end
	if IsOptionsPanelOpen() then
		container:SetFrameStrata(UNDER_OPTIONS_STRATA)
		container:SetFrameLevel(1)
	else
		container:SetFrameStrata(DEFAULT_STRATA)
		container:SetFrameLevel(DEFAULT_LEVEL)
	end
end

function BT.GetPreviewWidgetAnchor()
	local widgets = addon.db and addon.db.profile and addon.db.profile.widgets
	local widget = widgets and widgets.player_resource
	local point = (widget and widget.anchor) or "CENTER"
	local x = (widget and widget.posX) or 0
	local y = (widget and widget.posY) or -220
	return point, x, y
end

--[[
function BT.BeginPreviewLayout()
	local container = BT.EnsureContainer()
	BT.previewLayoutState = BT.previewLayoutState or {}
	container:SetAlpha(1)
	container:Show()
	BT.SyncContainerStrata()
end

function BT.EndPreviewLayout()
	BT.previewLayoutState = nil
	BT.SyncContainerStrata()
end
]]

function BT.GetAnchorFrame()
	local prd = addon.PlayerResourceModule and addon.PlayerResourceModule.frames
	if prd and prd.container and prd.container:IsShown() then
		return prd.container
	end
	if prd and prd.container then
		return prd.container
	end
	return UIParent
end

function BT.ShouldShowTracker()
	local cfg = GetConfig()
	if not cfg or not addon:IsModuleEnabled("bufftracker") then
		return false
	end
	if cfg.require_prd ~= false then
		if not addon:IsModuleEnabled("player_resource") then
			return false
		end
		local prd = addon.PlayerResourceModule and addon.PlayerResourceModule.frames
		if not prd or not prd.container then
			return false
		end
	end
	return true
end

function BT.EnsureContainer()
	local state = BT.layoutState
	if state.container then
		return state.container
	end

	local container = CreateFrame("Frame", "DragonUI_BuffTracker", UIParent)
	container:SetFrameStrata("MEDIUM")
	container:SetFrameLevel(20)
	container:EnableMouse(false)
	state.container = container
	return container
end

function BT.AnchorContainer()
	local cfg = GetConfig() or {}
	local container = BT.EnsureContainer()
	local offsetY = cfg.row_offset_y or 6

	container:ClearAllPoints()
	local anchor = BT.GetAnchorFrame()
	if anchor == UIParent then
		local point, x, y = BT.GetPreviewWidgetAnchor()
		container:SetPoint("BOTTOMLEFT", UIParent, point, x, y + offsetY)
	else
		container:SetPoint("BOTTOMLEFT", anchor, "TOPLEFT", 0, offsetY)
	end
end

local function ResolveEntryFlags(entry, cfg)
	local showDuration = entry.showDuration
	if showDuration == nil then
		showDuration = cfg.show_duration ~= false
	end
	local showStacks = entry.showStacks
	if showStacks == nil then
		showStacks = cfg.show_stacks ~= false
	end
	return showDuration, showStacks
end

local function EntryHasActiveTimer(entry, showDuration)
	if not showDuration then
		return false
	end
	if not entry.expiration or entry.expiration <= 0 then
		return false
	end
	return entry.expiration > GetTime()
end

function BT.LayoutIcons(entries)
	local cfg = GetConfig() or {}
	local state = BT.layoutState
	local container = BT.EnsureContainer()
	local iconSize = cfg.icon_size or 32
	local spacing = cfg.icon_spacing or 4
	local showTooltip = cfg.show_tooltip == true
	local durationTextH = BT.GetDurationTextHeight and BT.GetDurationTextHeight(iconSize) or 9

	local usedKeys = {}
	local ordered = entries or {}
	local visible = {}
	local rowHeight = iconSize

	for i = 1, #ordered do
		local entry = ordered[i]
		local showDuration = ResolveEntryFlags(entry, cfg)
		local hasExpiration = entry.expiration and entry.expiration > 0
		local timerActive = hasExpiration and entry.expiration > GetTime()

		if showDuration and hasExpiration and not timerActive then
		else
			if showDuration and timerActive then
				rowHeight = math.max(rowHeight, iconSize + durationTextH)
			end
			visible[#visible + 1] = entry
		end
	end

	local totalWidth = #visible * iconSize + math.max(0, #visible - 1) * spacing
	local x = 0

	if #visible > 0 then
		container:SetSize(math.max(totalWidth, iconSize), rowHeight)
	else
		container:SetSize(1, 1)
	end

	container:EnableMouse(false)

	for i = 1, #visible do
		local entry = visible[i]
		local key = entry.key or tostring(entry.spellID)
		local showDuration, showStacks = ResolveEntryFlags(entry, cfg)
		local timerActive = showDuration and EntryHasActiveTimer(entry, showDuration)

		local icon = state.iconsByKey[key]
		icon = BT.CreateOrUpdateIcon(container, key, {
			existing = icon,
			size = iconSize,
			texture = entry.texture,
			spellID = entry.spellID,
			tooltipID = entry.tooltipID or entry.spellID,
			showDuration = timerActive,
			showStacks = showStacks,
			forceStacks = entry.forceStacks,
			showTooltip = entry.showTooltip == true or showTooltip,
			expiration = entry.expiration,
			duration = entry.duration,
			count = entry.count,
			icdOnly = entry.icdOnly,
			glowEnabled = entry.glowEnabled,
			glowColor = entry.glowColor,
			glowScale = entry.glowScale,
			glowAlpha = entry.glowAlpha,
		})
		if not icon then
			state.iconsByKey[key] = nil
		else
			usedKeys[key] = true
			icon:ClearAllPoints()
			icon:SetPoint("TOPLEFT", container, "TOPLEFT", x, 0)
			--[[
			if BT.previewActive then
				icon:SetFrameLevel(baseLevel + 5 + i)
				icon:Show()
			end
			]]
			state.iconsByKey[key] = icon
			x = x + iconSize + spacing
		end
	end

	for key, icon in pairs(state.iconsByKey) do
		if not usedKeys[key] then
			if BT.StopExpiredGlow then
				BT.StopExpiredGlow(icon)
			end
			BT.ReleaseIcon(icon)
			state.iconsByKey[key] = nil
		end
	end

	if #visible == 0 then
		container:Hide()
	else
		container:Show()
	end
end

function BT.HideTracker()
	local state = BT.layoutState
	if state.container then
		state.container:Hide()
	end
	for key, icon in pairs(state.iconsByKey) do
		BT.ReleaseIcon(icon)
		state.iconsByKey[key] = nil
	end
end

function BT.RefreshLayout(entries)
	if not BT.ShouldShowTracker() then
		BT.HideTracker()
		return
	end
	BT.AnchorContainer()
	BT.LayoutIcons(entries or {})
	BT.SyncContainerStrata()
end
