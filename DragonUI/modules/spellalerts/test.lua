local addon = select(2, ...)
if not addon then
	addon = _G.DragonUI
end

local TEXTURE_PATH = "Interface\\AddOns\\DragonUI\\Textures\\SpellAlerts\\Overlays\\"
local PREVIEW_SPELL_ID = -91001
local PREVIEW_DURATION = 8

local CATALOG = {
	{ key = "art_of_war", class = "PALADIN", label = "Art of War", texture = "Art_of_War.blp", positions = "Left + Right (Flipped)", scale = 1, r = 255, g = 255, b = 255, glowSpellIDs = { 19750, 48785, 48819, 48825 } },
	{ key = "denounce", class = "PALADIN", label = "Denounce", texture = "Denounce.blp", positions = "Top", scale = 1, r = 255, g = 255, b = 255, glowSpellIDs = { 2812 } },
	{ key = "sword_and_board", class = "WARRIOR", label = "Sword and Board", texture = "Sword_and_Board.blp", positions = "Left + Right (Flipped)", scale = 1, r = 255, g = 255, b = 255, glowSpellIDs = { 23922, 47488 } },
	{ key = "sudden_death", class = "WARRIOR", label = "Sudden Death", texture = "Sudden_Death.blp", positions = "Left + Right (Flipped)", scale = 1, r = 255, g = 255, b = 255, glowSpellIDs = { 5308, 47471 } },
	{ key = "blood_surge", class = "WARRIOR", label = "Blood Surge", texture = "Blood_Surge.blp", positions = "Left + Right (Flipped)", scale = 1, r = 255, g = 255, b = 255, glowSpellIDs = { 1464, 47475 } },
	{ key = "hot_streak", class = "MAGE", label = "Hot Streak", texture = "Hot_Streak.blp", positions = "Left + Right (Flipped)", scale = 1, r = 255, g = 255, b = 255, glowSpellIDs = { 133, 42891 } },
	{ key = "brain_freeze", class = "MAGE", label = "Brain Freeze", texture = "Brain_Freeze.blp", positions = "Left + Right (Flipped)", scale = 1, r = 255, g = 255, b = 255, glowSpellIDs = { 116, 42873 } },
	{ key = "impact", class = "MAGE", label = "Impact", texture = "Impact.blp", positions = "Top", scale = 1, r = 255, g = 255, b = 255, glowSpellIDs = { 2136, 42921 } },
	{ key = "arcane_missiles", class = "MAGE", label = "Arcane Missiles", texture = "Arcane_Missiles.blp", positions = "Left + Right (Flipped)", scale = 1, r = 255, g = 255, b = 255, glowSpellIDs = { 5143, 42846 } },
	{ key = "frozen_fingers", class = "MAGE", label = "Frozen Fingers", texture = "Frozen_Fingers.blp", positions = "Top", scale = 1, r = 255, g = 255, b = 255, glowSpellIDs = { 116 } },
	{ key = "killing_machine", class = "DEATHKNIGHT", label = "Killing Machine", texture = "Killing_Machine.blp", positions = "Left + Right (Flipped)", scale = 1, r = 255, g = 255, b = 255, glowSpellIDs = { 49020, 51425 } },
	{ key = "rime", class = "DEATHKNIGHT", label = "Rime", texture = "Rime.blp", positions = "Top", scale = 1, r = 255, g = 255, b = 255, glowSpellIDs = { 45477, 51411 } },
	{ key = "maelstrom_weapon", class = "SHAMAN", label = "Maelstrom Weapon", texture = "Maelstrom_Weapon.blp", positions = "Top", scale = 1, r = 255, g = 255, b = 255, glowSpellIDs = { 331, 49273 } },
	{ key = "lock_and_load", class = "HUNTER", label = "Lock and Load", texture = "Lock_and_Load.blp", positions = "Top", scale = 1, r = 255, g = 255, b = 255, glowSpellIDs = { 3044, 49052 } },
	{ key = "master_marksman", class = "HUNTER", label = "Master Marksman", texture = "Master_Marksman.blp", positions = "Top", scale = 1, r = 255, g = 255, b = 255, glowSpellIDs = { 19434, 49050 } },
	{ key = "eclipse_sun", class = "DRUID", label = "Eclipse (Solar)", texture = "Eclipse_Sun.blp", positions = "TopRight", scale = 1, r = 244, g = 244, b = 244, glowSpellIDs = { 5176, 48461 } },
	{ key = "eclipse_moon", class = "DRUID", label = "Eclipse (Lunar)", texture = "Eclipse_Moon.blp", positions = "TopLeft", scale = 1, r = 244, g = 244, b = 244, glowSpellIDs = { 2912, 48463 } },
	{ key = "natures_grace", class = "DRUID", label = "Nature's Grace", texture = "Natures_Grace.blp", positions = "Left + Right (Flipped)", scale = 1, r = 255, g = 255, b = 255, glowSpellIDs = { 5176 } },
	{ key = "surge_of_light", class = "PRIEST", label = "Surge of Light", texture = "Surge_of_Light.blp", positions = "Left + Right (Flipped)", scale = 1, r = 255, g = 255, b = 255, glowSpellIDs = { 585, 48123 } },
	{ key = "serendipity", class = "PRIEST", label = "Serendipity", texture = "Serendipity.blp", positions = "Top", scale = 1, r = 255, g = 255, b = 255, glowSpellIDs = { 2061, 48071 } },
	{ key = "nightfall", class = "WARLOCK", label = "Nightfall", texture = "Nightfall.blp", positions = "Left + Right (Flipped)", scale = 1, r = 255, g = 255, b = 255, glowSpellIDs = { 686, 47809 } },
	{ key = "molten_core", class = "WARLOCK", label = "Molten Core", texture = "Molten_Core.blp", positions = "Left + Right (Flipped)", scale = 1, r = 255, g = 255, b = 255, glowSpellIDs = { 686, 47809 } },
	{ key = "backlash", class = "WARLOCK", label = "Backlash", texture = "Backlash.blp", positions = "Top", scale = 1, r = 255, g = 255, b = 255, glowSpellIDs = { 686, 47809 } },
	{ key = "imp_empowerment", class = "WARLOCK", label = "Imp Empowerment", texture = "Imp_Empowerment.blp", positions = "Left + Right (Flipped)", scale = 1, r = 255, g = 255, b = 255, glowSpellIDs = { 686 } },
}

local byKey = {}
for _, entry in ipairs(CATALOG) do
	byKey[entry.key] = entry
end

local previewState = {
	activeKey = nil,
	glowIDs = {},
	forcedMainBar = false,
	savedStrata = nil,
	savedLevel = nil,
}

local CLASS_LABELS = {
	WARRIOR = "Warrior",
	PALADIN = "Paladin",
	HUNTER = "Hunter",
	ROGUE = "Rogue",
	PRIEST = "Priest",
	DEATHKNIGHT = "Death Knight",
	SHAMAN = "Shaman",
	MAGE = "Mage",
	WARLOCK = "Warlock",
	DRUID = "Druid",
}

local function GetClassLabel(classToken)
	return CLASS_LABELS[classToken] or classToken
end

local function BuildPreviewDropdown()
	local values, order = {}, {}
	for _, entry in ipairs(CATALOG) do
		values[entry.key] = GetClassLabel(entry.class) .. ": " .. entry.label
		order[#order + 1] = entry.key
	end
	return values, order
end

addon = addon or {}
addon.SpellAlertsPreview = addon.SpellAlertsPreview or {}
addon.SpellAlertsPreview.values, addon.SpellAlertsPreview.order = BuildPreviewDropdown()

function DragonUISpellAlert_GetPreviewCatalog()
	return CATALOG
end

function DragonUISpellAlert_GetPreviewDropdownValues()
	return addon.SpellAlertsPreview.values
end

function DragonUISpellAlert_GetPreviewDropdownOrder()
	return addon.SpellAlertsPreview.order
end

function DragonUISpellAlert_GetDefaultPreviewKey()
	local playerClass = select(2, UnitClass("player"))
	for _, entry in ipairs(CATALOG) do
		if entry.class == playerClass then
			return entry.key
		end
	end
	return CATALOG[1] and CATALOG[1].key
end

local function HidePreviewOverlaysInstant()
	local frame = DragonUISpellActivationOverlayFrame
	if not frame or not frame.overlaysInUse then
		return
	end
	local overlayList = frame.overlaysInUse[PREVIEW_SPELL_ID]
	if not overlayList then
		return
	end
	for i = #overlayList, 1, -1 do
		local overlay = overlayList[i]
		if overlay then
			if overlay.animIn and overlay.animIn:IsPlaying() then
				overlay.animIn:Stop()
			end
			if overlay.animOut and overlay.animOut:IsPlaying() then
				overlay.animOut:Stop()
			end
			if overlay.pulse then
				overlay.pulse:Stop()
			end
			overlay:Hide()
			tinsert(frame.unusedOverlays, overlay)
		end
	end
	frame.overlaysInUse[PREVIEW_SPELL_ID] = nil
end

local function RestoreOverlayFrameStrata()
	local frame = DragonUISpellActivationOverlayFrame
	if not frame then
		return
	end
	if previewState.savedStrata then
		frame:SetFrameStrata(previewState.savedStrata)
		previewState.savedStrata = nil
	end
	if previewState.savedLevel then
		frame:SetFrameLevel(previewState.savedLevel)
		previewState.savedLevel = nil
	end
end

local function RaiseOverlayFrameForPreview()
	local frame = DragonUISpellActivationOverlayFrame
	if not frame then
		return
	end
	if not previewState.savedStrata then
		previewState.savedStrata = frame:GetFrameStrata() or "MEDIUM"
		previewState.savedLevel = frame:GetFrameLevel() or 1
	end
	-- Options panel is DIALOG; preview must draw above it.
	frame:SetFrameStrata("FULLSCREEN_DIALOG")
	frame:SetFrameLevel(200)
	frame:Show()
end

function DragonUISpellAlert_StopPreview()
	HidePreviewOverlaysInstant()

	for spellID in pairs(previewState.glowIDs) do
		if DragonUISpellAlert_PreviewGlowHide then
			DragonUISpellAlert_PreviewGlowHide(spellID)
		end
		previewState.glowIDs[spellID] = nil
	end

	if previewState.forcedMainBar and DragonUISpellAlertActionButton_ForceGlowOnMainBar then
		DragonUISpellAlertActionButton_ForceGlowOnMainBar(false)
		previewState.forcedMainBar = false
	end

	RestoreOverlayFrameStrata()
	previewState.activeKey = nil
end

function DragonUISpellAlert_PreviewAlert(key)
	local entry = byKey[key]
	if not entry then
		-- Fallback: if Options stored an unexpected key, still try the default.
		key = DragonUISpellAlert_GetDefaultPreviewKey() or "art_of_war"
		entry = byKey[key]
		if not entry then
			return false
		end
	end

	DragonUISpellAlert_StopPreview()

	local frame = DragonUISpellActivationOverlayFrame
	if not frame then
		return false
	end

	-- Ensure pools exist even if OnLoad did not run for some reason.
	frame.overlaysInUse = frame.overlaysInUse or {}
	frame.unusedOverlays = frame.unusedOverlays or {}

	if DragonUISpellActivationOverlay_ApplySettings then
		DragonUISpellActivationOverlay_ApplySettings()
	end

	RaiseOverlayFrameForPreview()
	frame:SetAlpha(1)

	DragonUISpellActivationOverlay_ShowAllOverlays(
		frame,
		PREVIEW_SPELL_ID,
		TEXTURE_PATH .. entry.texture,
		entry.positions,
		entry.scale or 1,
		entry.r or 255,
		entry.g or 255,
		entry.b or 255
	)

	-- Force every preview piece visible above the options UI.
	local list = frame.overlaysInUse[PREVIEW_SPELL_ID]
	if list then
		for i = 1, #list do
			local overlay = list[i]
			if overlay then
				if overlay.animIn then overlay.animIn:Stop() end
				if overlay.animOut then overlay.animOut:Stop() end
				overlay:SetAlpha(1)
				overlay:Show()
				if overlay.texture then
					overlay.texture:SetAlpha(1)
					overlay.texture:Show()
				end
				if overlay.pulse and not overlay.pulse:IsPlaying() then
					overlay.pulse:Play()
				end
			end
		end
	end

	if entry.glowSpellIDs and DragonUISpellAlert_PreviewGlowShow then
		for _, spellID in ipairs(entry.glowSpellIDs) do
			previewState.glowIDs[spellID] = true
			DragonUISpellAlert_PreviewGlowShow(spellID)
		end
	end

	if DragonUISpellAlertActionButton_ForceGlowOnMainBar then
		DragonUISpellAlertActionButton_ForceGlowOnMainBar(true)
		previewState.forcedMainBar = true
	end

	previewState.activeKey = key

	if addon and addon.After then
		addon:After(PREVIEW_DURATION, function()
			if previewState.activeKey == key then
				DragonUISpellAlert_StopPreview()
			end
		end)
	end

	return true
end

addon.SpellAlertsPreview.GetDropdownValues = DragonUISpellAlert_GetPreviewDropdownValues
addon.SpellAlertsPreview.GetDropdownOrder = DragonUISpellAlert_GetPreviewDropdownOrder
addon.SpellAlertsPreview.GetDefaultKey = DragonUISpellAlert_GetDefaultPreviewKey
addon.SpellAlertsPreview.Preview = DragonUISpellAlert_PreviewAlert
addon.SpellAlertsPreview.Stop = DragonUISpellAlert_StopPreview
addon.PreviewSpellAlert = DragonUISpellAlert_PreviewAlert
addon.StopSpellAlertPreview = DragonUISpellAlert_StopPreview

-- Slash helper for debugging preview without the options UI.
SLASH_DUISPELLALERTPREVIEW1 = "/duipreview"
SlashCmdList.DUISPELLALERTPREVIEW = function(msg)
	msg = strtrim(msg or "")
	if msg == "stop" or msg == "clear" then
		DragonUISpellAlert_StopPreview()
		return
	end
	local key = msg ~= "" and msg or DragonUISpellAlert_GetDefaultPreviewKey() or "art_of_war"
	local ok = DragonUISpellAlert_PreviewAlert(key)
	if ok then
		print("|cff00ccffDragonUI:|r Previewing spell alert:", key)
	else
		print("|cff00ccffDragonUI:|r Preview failed for:", key)
	end
end
