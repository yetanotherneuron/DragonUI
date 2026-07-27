local addon = select(2, ...)

local band = bit.band
local CreateFrame = CreateFrame
local GetActionInfo = GetActionInfo
local lshift = bit.lshift
local next = next
local OVERLAY_GLOW_SPELL_MAP = DUI_SPELLALERTS_OVERLAY_GLOW_SPELL_MAP
local OVERLAY_GLOW_SPELL_TABLE = DUI_SPELLALERTS_OVERLAY_GLOW_SPELL_TABLE
local OVERLAY_MAP = DUI_SPELLALERTS_OVERLAY_MAP
local OVERLAY_TABLE = DUI_SPELLALERTS_OVERLAY_TABLE
local OVERLAYS_UPPER_BOUND = DUI_SPELLALERTS_OVERLAYS_UPPER_BOUND
local pairs = pairs
local PlayerFrame = PlayerFrame
local rshift = bit.rshift
local UnitBuff = UnitBuff

local TEXTURE_PATH = "Interface\\AddOns\\DragonUI\\Textures\\SpellAlerts\\Overlays\\"
local NUM_ACTION_BUTTONS = 12 * 12

-- 3.3.5 GetActionInfo returns type, id, subType only. Some clients also return a
-- 4th spellID (Cata-style). Prefer the 4th when present; otherwise use id for spells.
-- Macros resolve via GetSpellLink so glow works on macroed abilities too.
function DragonUISpellAlert_GetActionSpellID(action)
	if not action then
		return nil
	end
	local actionType, id, subType, spellID = GetActionInfo(action)
	if actionType == "spell" then
		if type(spellID) == "number" and spellID > 0 then
			return spellID
		end
		if type(id) == "number" and id > 0 then
			return id
		end
		return nil
	end
	if actionType == "macro" and id then
		local spellName = GetMacroSpell(id)
		if spellName then
			local link = GetSpellLink(spellName)
			if link then
				local sid = link:match("spell:(%d+)")
				return sid and tonumber(sid) or nil
			end
		end
	end
	return nil
end

local actionButtons = {
	nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,
	nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,
	nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,
	nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,
	nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,
	nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,
	nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,
	nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,
	nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,
	nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,
	nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,
	nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,
}
local buffGlowSpells = {}
local buffs = {}
local spellsOverlayed = {}
local eventOverlayShowListeners = {}
local eventOverlayHideListeners = {}
local eventOverlayGlowShowListeners = {}
local eventOverlayGlowHideListeners = {}
local eventListeners = {
	["DRAGONUI_SPELL_ALERT_OVERLAY_SHOW"] = eventOverlayShowListeners,
	["DRAGONUI_SPELL_ALERT_OVERLAY_HIDE"] = eventOverlayHideListeners,
	["DRAGONUI_SPELL_ALERT_GLOW_SHOW"] = eventOverlayGlowShowListeners,
	["DRAGONUI_SPELL_ALERT_GLOW_HIDE"] = eventOverlayGlowHideListeners,
}
local eventFrame1 = CreateFrame("Frame")
local eventFrame2 = CreateFrame("Frame")

local function GetConfig()
	local db = addon.db and addon.db.profile and addon.db.profile.modules
	return db and db.spellalerts
end

function DragonUISpellAlert_IsEnabled()
	local cfg = GetConfig()
	return not cfg or cfg.enabled ~= false
end

function DragonUISpellAlert_ShowOverlay()
	if not DragonUISpellAlert_IsEnabled() then
		return false
	end
	local cfg = GetConfig()
	return not cfg or cfg.show_overlay ~= false
end

function DragonUISpellAlert_ShowGlow()
	if not DragonUISpellAlert_IsEnabled() then
		return false
	end
	local cfg = GetConfig()
	return not cfg or cfg.show_glow ~= false
end

function DragonUISpellAlert_GetGlowScale()
	local cfg = GetConfig()
	local scale = cfg and cfg.glow_scale
	if type(scale) ~= "number" then
		return 1.4
	end
	return scale
end

function DragonUISpellAlert_GetGlowAlpha()
	local cfg = GetConfig()
	local alpha = cfg and cfg.glow_alpha
	if type(alpha) ~= "number" then
		return 1.0
	end
	return alpha
end

function DragonUISpellAlert_GetOverlayScale()
	local cfg = GetConfig()
	local scale = cfg and cfg.overlay_scale
	if type(scale) ~= "number" then
		return 1.0
	end
	return scale
end

function DragonUISpellAlert_GetOverlayAlpha()
	local cfg = GetConfig()
	local alpha = cfg and cfg.overlay_alpha
	if type(alpha) ~= "number" then
		return 1.0
	end
	return alpha
end

function DragonUISpellAlert_GetOverlaySpacing()
	local cfg = GetConfig()
	local spacing = cfg and cfg.overlay_spacing
	if type(spacing) ~= "number" then
		return 30
	end
	return spacing
end

local function AddOverlayGlow(globalID)
	if not DragonUISpellAlert_ShowGlow() then
		return
	end
	local overlayedCount = spellsOverlayed[globalID]
	if not overlayedCount then
		spellsOverlayed[globalID] = 1
		for frame, func in pairs(eventOverlayGlowShowListeners) do
			func(frame, globalID)
		end
	else
		spellsOverlayed[globalID] = overlayedCount + 1
	end
end

local function RemoveOverlayGlow(globalID)
	local overlayedCount = spellsOverlayed[globalID]
	if not overlayedCount then
		return
	end
	if overlayedCount == 1 then
		spellsOverlayed[globalID] = nil
		for frame, func in pairs(eventOverlayGlowHideListeners) do
			func(frame, globalID)
		end
	else
		spellsOverlayed[globalID] = overlayedCount - 1
	end
end

local function SetAction(action, globalID)
	actionButtons[action] = globalID
	if globalID then
		local glowSpellK = OVERLAY_GLOW_SPELL_MAP()[globalID]
		if glowSpellK then
			local overlayGlowSpellTable = OVERLAY_GLOW_SPELL_TABLE()
			local spellID = overlayGlowSpellTable[glowSpellK]
			repeat
				local glowSpells = buffGlowSpells[spellID]
				if not glowSpells then
					buffGlowSpells[spellID] = {
						[globalID] = 1,
					}
					if buffs[spellID] and DragonUISpellAlert_ShowGlow() then
						AddOverlayGlow(globalID)
					end
				else
					local refCount = glowSpells[globalID]
					if not refCount then
						glowSpells[globalID] = 1
						if buffs[spellID] and DragonUISpellAlert_ShowGlow() then
							AddOverlayGlow(globalID)
						end
					else
						glowSpells[globalID] = refCount + 1
					end
				end
				glowSpellK = glowSpellK + 1
				spellID = overlayGlowSpellTable[glowSpellK]
			until not spellID
		end
	end
end

local function ChangeAction(action, newGlobalID)
	local globalID = actionButtons[action]
	if globalID then
		local glowSpellK = OVERLAY_GLOW_SPELL_MAP()[globalID]
		if glowSpellK then
			local overlayGlowSpellTable = OVERLAY_GLOW_SPELL_TABLE()
			local spellID = overlayGlowSpellTable[glowSpellK]
			repeat
				local glowSpells = buffGlowSpells[spellID]
				local refCount = glowSpells[globalID]
				if refCount == 1 then
					glowSpells[globalID] = nil
					if next(glowSpells) == nil then
						glowSpells = nil
						buffGlowSpells[spellID] = nil
					end
					if buffs[spellID] then
						RemoveOverlayGlow(globalID)
					end
				else
					glowSpells[globalID] = refCount - 1
				end
				glowSpellK = glowSpellK + 1
				spellID = overlayGlowSpellTable[glowSpellK]
			until not spellID
		end
	end
	SetAction(action, newGlobalID)
end

local function BuffGained(spellID, k, overlayTable)
	if DragonUISpellAlert_ShowOverlay() and k < OVERLAYS_UPPER_BOUND then
		local texture = TEXTURE_PATH .. overlayTable[k + 1]
		local positions = overlayTable[k + 2]
		local scale = overlayTable[k + 3]
		local vertexColor = overlayTable[k + 4]
		local r = rshift(lshift(vertexColor, 8), 24)
		local g = rshift(lshift(vertexColor, 16), 24)
		local b = band(vertexColor, 0xff)
		for frame, func in pairs(eventOverlayShowListeners) do
			func(frame, spellID, texture, positions, scale, r, g, b)
		end
	end
	if DragonUISpellAlert_ShowGlow() then
		local glowSpells = buffGlowSpells[spellID]
		if glowSpells then
			for globalID in pairs(glowSpells) do
				AddOverlayGlow(globalID)
			end
		end
	end
end

local function BuffLost(spellID)
	if DragonUISpellAlert_ShowOverlay() then
		for frame, func in pairs(eventOverlayHideListeners) do
			func(frame, spellID)
		end
	end
	-- Always attempt glow removal when buff is lost so refcounts stay correct
	local glowSpells = buffGlowSpells[spellID]
	if glowSpells then
		for globalID in pairs(glowSpells) do
			RemoveOverlayGlow(globalID)
		end
	end
end

function DragonUISpellAlert_RefreshDisplay()
	for frame, func in pairs(eventOverlayHideListeners) do
		func(frame)
	end
	for globalID in pairs(spellsOverlayed) do
		for frame, func in pairs(eventOverlayGlowHideListeners) do
			func(frame, globalID)
		end
	end
	spellsOverlayed = {}
	if not DragonUISpellAlert_IsEnabled() then
		return
	end
	for spellID, hasBuff in pairs(buffs) do
		if hasBuff then
			local k = OVERLAY_MAP()[spellID]
			if k then
				local overlayTable = OVERLAY_TABLE()
				BuffGained(spellID, k, overlayTable)
			end
		end
	end
end

local function eventFrame1_OnEventActionbarSlotChanged(self, event, action)
	if action ~= 0 then
		local globalID = DragonUISpellAlert_GetActionSpellID(action)
		if globalID then
			if actionButtons[action] ~= globalID then
				ChangeAction(action, globalID)
			end
		else
			if actionButtons[action] then
				ChangeAction(action, nil)
			end
		end
	else
		for actionIndex = 1, NUM_ACTION_BUTTONS do
			local globalID = DragonUISpellAlert_GetActionSpellID(actionIndex)
			if globalID then
				if actionButtons[actionIndex] ~= globalID then
					ChangeAction(actionIndex, globalID)
				end
			else
				if actionButtons[actionIndex] then
					ChangeAction(actionIndex, nil)
				end
			end
		end
	end
end

local function eventFrame2_OnEventUnitAura(self, event, unitID)
	local unit = PlayerFrame.unit
	if unitID == unit then
		do
			local name, _, _, count, _, _, _, _, _, _, spellID = UnitBuff(unit, 1)
			if name then
				local overlayMap = OVERLAY_MAP()
				local overlayTable
				local j = 1
				repeat
					local k = overlayMap[spellID]
					if k then
						if not overlayTable then
							overlayTable = OVERLAY_TABLE()
						end
						if not (count < overlayTable[k]) then
							local hasBuff = buffs[spellID]
							buffs[spellID] = false
							if hasBuff == nil then
								BuffGained(spellID, k, overlayTable)
							end
						end
					end
					j = j + 1
					name, _, _, count, _, _, _, _, _, _, spellID = UnitBuff(unit, j)
				until not name
			end
		end
		for spellID, hasBuff in pairs(buffs) do
			if not hasBuff then
				buffs[spellID] = true
			else
				buffs[spellID] = nil
				BuffLost(spellID)
			end
		end
	end
end

local function eventFrame1_OnEventPlayerLogin(self)
	eventFrame1:UnregisterEvent("PLAYER_LOGIN")
	do
		for action = 1, NUM_ACTION_BUTTONS do
			local globalID = DragonUISpellAlert_GetActionSpellID(action)
			if globalID then
				SetAction(action, globalID)
			end
		end
	end
	eventFrame1:SetScript("OnEvent", eventFrame1_OnEventActionbarSlotChanged)
	eventFrame1:RegisterEvent("ACTIONBAR_SLOT_CHANGED")
	do
		local unit = PlayerFrame.unit
		local name, _, _, count, _, _, _, _, _, _, spellID = UnitBuff(unit, 1)
		if name then
			local overlayMap = OVERLAY_MAP()
			local overlayTable
			local j = 1
			repeat
				local k = overlayMap[spellID]
				if k then
					if not overlayTable then
						overlayTable = OVERLAY_TABLE()
					end
					if not (count < overlayTable[k]) then
						buffs[spellID] = true
						BuffGained(spellID, k, overlayTable)
					end
				end
				j = j + 1
				name, _, _, count, _, _, _, _, _, _, spellID = UnitBuff(unit, j)
			until not name
		end
	end
	eventFrame2:SetScript("OnEvent", eventFrame2_OnEventUnitAura)
	eventFrame2:RegisterEvent("UNIT_AURA")
end

eventFrame1:SetScript("OnEvent", eventFrame1_OnEventPlayerLogin)
eventFrame1:RegisterEvent("PLAYER_LOGIN")

function DragonUISpellAlert_IsSpellOverlayed(spellID)
	return spellsOverlayed[spellID] and true or false
end

function DragonUISpellAlert_RegisterEvent(event, frame, func)
	local listeners = eventListeners[event]
	if listeners then
		listeners[frame] = func
	end
end

function DragonUISpellAlert_UnregisterEvent(event, frame)
	local listeners = eventListeners[event]
	if listeners then
		listeners[frame] = nil
	end
end

-- Force-add/remove glow for preview tooling (bypasses buff tracking).
function DragonUISpellAlert_PreviewGlowShow(globalID)
	if not globalID then
		return
	end
	local overlayedCount = spellsOverlayed[globalID]
	if not overlayedCount then
		spellsOverlayed[globalID] = 1
		for frame, func in pairs(eventOverlayGlowShowListeners) do
			func(frame, globalID)
		end
	else
		spellsOverlayed[globalID] = overlayedCount + 1
	end
end

function DragonUISpellAlert_PreviewGlowHide(globalID)
	if not globalID then
		return
	end
	if not spellsOverlayed[globalID] then
		return
	end
	spellsOverlayed[globalID] = nil
	for frame, func in pairs(eventOverlayGlowHideListeners) do
		func(frame, globalID)
	end
end
