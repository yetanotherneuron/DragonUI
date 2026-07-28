local addon = select(2, ...)
if not addon then addon = _G.DragonUI end

local BT = DragonUIBuffTracker

local UnitBuff = UnitBuff
local UnitDebuff = UnitDebuff
local GetTime = GetTime

BT.engineState = BT.engineState or {
	firstSeen = {},
	wasConsumableActive = {},
	lastTexture = {},
	scanElapsed = 0,
}

local function GetConfig()
	return addon:GetModuleConfig("bufftracker")
end

local function GetPlayerClass()
	return select(2, UnitClass("player"))
end

local function ShouldShowConsumable(cfg, remain)
	local mode = cfg.consumable_show_mode or "threshold"
	if mode == "never" then
		return false
	end
	if mode == "always" then
		return true
	end
	local threshold = cfg.consumable_threshold_sec or 300
	return remain <= threshold
end

local function IsPlayerOwnedAura(unitCaster)
	if unitCaster == nil or unitCaster == "" then
		return true
	end
	if unitCaster == "player" or unitCaster == "pet" or unitCaster == "vehicle" then
		return true
	end
	if UnitIsUnit then
		if UnitIsUnit(unitCaster, "player") or UnitIsUnit(unitCaster, "pet") then
			return true
		end
	end
	if UnitGUID then
		local playerGUID = UnitGUID("player")
		if playerGUID then
			local casterGUID = UnitGUID(unitCaster)
			if casterGUID and casterGUID == playerGUID then
				return true
			end
			if type(unitCaster) == "string" and unitCaster == playerGUID then
				return true
			end
		end
	end
	return false
end

local function ParseAuraSpellID(v10, v11)
	if type(v11) == "number" and v11 > 0 then
		return v11
	end
	if type(v10) == "number" and v10 > 0 then
		return v10
	end
	return tonumber(v11) or tonumber(v10)
end

local function ReadAuraInto(active, name, icon, count, debuffType, duration, expirationTime, spellID)
	spellID = tonumber(spellID)
	if not spellID or spellID <= 0 then
		spellID = BT.ResolveSpellIdByName and BT.ResolveSpellIdByName(name)
	end
	if not spellID or spellID <= 0 then
		return
	end
	local now = GetTime()
	local expiration = (expirationTime and expirationTime > 0) and expirationTime or 0
	if expiration <= 0 and duration and duration > 0 then
		expiration = now + duration
	end
	active[spellID] = {
		spellID = spellID,
		name = name,
		texture = icon,
		count = count or 1,
		duration = (duration and duration > 0) and duration or 0,
		expiration = expiration,
		remain = expiration > 0 and (expiration - now) or 0,
	}
end

local function ScanUnitAura(active, unit, index, isDebuff, playerOnly)
	local name, rank, icon, count, debuffType, duration, expirationTime, unitCaster, isStealable, v10, v11
	if isDebuff then
		name, rank, icon, count, debuffType, duration, expirationTime, unitCaster, isStealable, v10, v11 =
			UnitDebuff(unit, index)
	else
		name, rank, icon, count, debuffType, duration, expirationTime, unitCaster, isStealable, v10, v11 =
			UnitBuff(unit, index)
	end
	if not name then
		return false
	end
	local spellID = ParseAuraSpellID(v10, v11)
	if playerOnly and not IsPlayerOwnedAura(unitCaster) then
		return true
	end
	ReadAuraInto(active, name, icon, count, debuffType, duration, expirationTime, spellID)
	return true
end

local function ScanPlayerAuras()
	local active = {}
	for i = 1, 40 do
		if not ScanUnitAura(active, "player", i, false) then
			break
		end
	end
	for i = 1, 40 do
		if not ScanUnitAura(active, "player", i, true) then
			break
		end
	end
	return active
end

local function ScanTargetDebuffs(watchMap)
	local active = {}
	if not UnitExists("target") or not watchMap then
		return active
	end
	for i = 1, 40 do
		local name, rank, icon, count, debuffType, duration, expirationTime, unitCaster, isStealable, v10, v11 =
			UnitDebuff("target", i)
		if not name then
			break
		end
		local rawSpellID = ParseAuraSpellID(v10, v11)
		if not rawSpellID or rawSpellID <= 0 then
			rawSpellID = BT.ResolveSpellIdByName(name)
		end
		local spellID, watch = BT.FindWatchForAura(watchMap, name, rawSpellID)
		if spellID and watch and watch.category == "stacks" then
			ReadAuraInto(active, name, icon, count, debuffType, duration, expirationTime, spellID)
		end
	end
	return active
end

local function CategoryRank(category)
	for i, key in ipairs(BT.CATEGORY_ORDER) do
		if key == category then
			return i
		end
	end
	return 99
end

local function ResolveShowFlags(cfg, watch, aura)
	local showDuration = cfg.show_duration ~= false
	if watch.showDuration == false then
		showDuration = false
	elseif watch.showDuration == true then
		showDuration = true
	end
	if aura.expiration and aura.expiration > 0 and watch.showDuration ~= false then
		showDuration = true
	end

	local showStacks = cfg.show_stacks ~= false
	if watch.showStacks ~= nil then
		showStacks = watch.showStacks == true
	end

	return showDuration, showStacks
end

local function ResolveGlowOptions(cfg, watch)
	if not cfg or cfg.icon_glow_enabled ~= true or not watch or watch.glow ~= true then
		return false, nil
	end
	local color = watch.glowColor
	if not color then
		local mode = watch.borderMode or watch.glowMode
		if mode and BT.BORDER_PRESETS and BT.BORDER_PRESETS[mode] then
			color = BT.BORDER_PRESETS[mode]
		end
	end
	if not color then
		return false, nil
	end
	return true, color
end

function BT.BuildDisplayEntries(cfg, activeAuras, previewEntries, watchMap)
	--[[
	if previewEntries then
		return previewEntries
	end
	]]

	watchMap = watchMap or BT.BuildWatchMap(cfg)
	local state = BT.engineState
	local display = {}
	local tick = GetTime()
	local resolvedActive = {}

	for auraKey, aura in pairs(activeAuras) do
		local rawSpellID = aura.spellID or auraKey
		local watchSpellID, watch = BT.FindWatchForAura(watchMap, aura.name, rawSpellID)
		if watch and BT.ShouldDisplayWatch(cfg, watch) then
			local spellID = watchSpellID or rawSpellID
			local displayKey = aura.icdOnly and tostring(auraKey) or tostring(spellID)
			resolvedActive[displayKey] = true
			if not state.firstSeen[displayKey] then
				state.firstSeen[displayKey] = tick
			end
			state.lastTexture[displayKey] = aura.texture

			local visible = true
			if (watch.category == "buffs" or watch.category == "consume") and watch.showLowTime then
				if aura.expiration and aura.expiration > 0 then
					aura.remain = aura.expiration - tick
					visible = BT.ShouldShowLowTimeBuff(cfg, watch, aura)
				else
					visible = false
				end
			elseif watch.category == "consume" then
				if aura.expiration > 0 then
					visible = ShouldShowConsumable(cfg, aura.remain)
				else
					visible = (cfg.consumable_show_mode or "threshold") == "always"
				end
			end

			if visible then
				local showDuration, showStacks = ResolveShowFlags(cfg, watch, aura)
				local glowEnabled, glowColor = ResolveGlowOptions(cfg, watch)
				display[#display + 1] = {
					key = displayKey,
					spellID = spellID,
					tooltipID = watch.tooltipID or spellID,
					category = watch.category,
					texture = aura.texture,
					expiration = aura.expiration,
					duration = aura.duration and aura.duration > 0 and aura.duration or nil,
					count = aura.count,
					showDuration = showDuration,
					showStacks = showStacks,
					forceStacks = watch.showStacks == true,
					icdOnly = aura.icdOnly == true,
					glowEnabled = glowEnabled,
					glowColor = glowColor,
					glowScale = cfg.icon_glow_scale or 1.2,
					glowAlpha = cfg.icon_glow_alpha or 1.0,
					firstSeen = state.firstSeen[displayKey],
					categoryRank = CategoryRank(watch.category),
				}
			end
		end
	end

	for spellID, wasActive in pairs(state.wasConsumableActive) do
		if wasActive and not activeAuras[spellID] then
			local watch = watchMap[spellID]
			if watch and watch.category == "consume" and cfg.consumable_expired_glow ~= false then
				local icon = BT.layoutState.iconsByKey[tostring(spellID)]
				if icon then
					BT.PlayExpiredGlow(icon, cfg.consumable_glow_scale or 1.2, 1.0, 3)
				end
			end
		end
	end

	local nextConsumable = {}
	for spellID in pairs(activeAuras) do
		local watch = watchMap[spellID]
		if watch and watch.category == "consume" then
			nextConsumable[spellID] = true
		end
	end
	state.wasConsumableActive = nextConsumable

	for spellID in pairs(state.firstSeen) do
		if not resolvedActive[spellID] then
			state.firstSeen[spellID] = nil
		end
	end

	table.sort(display, function(a, b)
		if a.categoryRank ~= b.categoryRank then
			return a.categoryRank < b.categoryRank
		end
		return (a.firstSeen or 0) < (b.firstSeen or 0)
	end)

	return display
end

local function ScanActiveAuras(cfg, watchMap)
	cfg = cfg or {}
	local active = ScanPlayerAuras()
	if cfg.track_target_debuffs ~= false then
		local targetDebuffs = ScanTargetDebuffs(watchMap)
		for spellID, aura in pairs(targetDebuffs) do
			active[spellID] = aura
		end
	end
	if BT.MergeICDProcAuras then
		BT.MergeICDProcAuras(active, watchMap, cfg)
	end
	return active
end

function BT.SyncEngineEvents(cfg)
	local frame = BT.engineFrame
	if not frame then return end
	frame:UnregisterEvent("UNIT_AURA")
	frame:RegisterEvent("UNIT_AURA")
	if BT.NeedsTargetAuraScan(cfg) then
		frame:RegisterEvent("PLAYER_TARGET_CHANGED")
	else
		frame:UnregisterEvent("PLAYER_TARGET_CHANGED")
	end
	if BT.SyncICDEvents then
		BT.SyncICDEvents(frame, cfg and BT.IsCategoryEnabled(cfg, "procs"))
	end
end

function BT.UpdateTracker()
	--[[
	if BT.previewActive and BT.previewEntries then
		local cfg = GetConfig()
		if cfg and addon:IsModuleEnabled("bufftracker") then
			BT.SyncEngineEvents(cfg)
		end
		BT.RefreshLayout(BT.previewEntries)
		if BT.ShouldEndPreview and BT.ShouldEndPreview() then
			if DragonUIBuffTracker_StopPreview then
				DragonUIBuffTracker_StopPreview()
			end
		end
		return
	end
	]]

	local cfg = GetConfig()
	if not cfg or not addon:IsModuleEnabled("bufftracker") then
		BT.HideTracker()
		return
	end

	BT.SyncEngineEvents(cfg)

	if not BT.ShouldShowTracker() then
		BT.HideTracker()
		return
	end

	local watchMap = BT.BuildWatchMap(cfg)
	local activeAuras = ScanActiveAuras(cfg, watchMap)
	local display = BT.BuildDisplayEntries(cfg, activeAuras, nil, watchMap)
	BT.RefreshLayout(display)
end

function BT.OnUpdateEngine(_, elapsed)
	local state = BT.engineState
	state.scanElapsed = (state.scanElapsed or 0) + elapsed
	if state.scanElapsed < 0.1 then
		return
	end
	state.scanElapsed = 0
	BT.UpdateTracker()
end

function BT.StartEngine()
	local frame = BT.engineFrame
	if not frame then
		frame = CreateFrame("Frame", "DragonUI_BuffTrackerEngine")
		frame:SetScript("OnEvent", function(_, event, unit)
			if event == "COMBAT_LOG_EVENT_UNFILTERED" then
				if BT.OnICDCombatLogEvent then
					BT.OnICDCombatLogEvent()
				end
				return
			end
			if event == "PLAYER_EQUIPMENT_CHANGED" then
				if BT.OnICDEquipmentChanged then
					BT.OnICDEquipmentChanged()
				end
				return
			end
			if event == "UNIT_AURA" then
				if unit == "player" or unit == "target" then
					BT.UpdateTracker()
				end
				return
			end
			BT.UpdateTracker()
		end)
		frame:RegisterEvent("PLAYER_ENTERING_WORLD")
		frame:RegisterEvent("PLAYER_TALENT_UPDATE")
		frame:RegisterEvent("SPELLS_CHANGED")
		frame:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
		BT.engineFrame = frame
	end
	frame:SetScript("OnUpdate", BT.OnUpdateEngine)
	local debuffRuntime = addon.Nameplates and addon.Nameplates.auras and addon.Nameplates.auras.DebuffRuntime
	if debuffRuntime and debuffRuntime.WarmSpellNameIndex then
		debuffRuntime.WarmSpellNameIndex()
	end
	BT.UpdateTracker()
end

function BT.StopEngine()
	if BT.engineFrame then
		BT.engineFrame:SetScript("OnUpdate", nil)
	end
	--[[
	BT.previewActive = false
	BT.previewEntries = nil
	]]
	BT.HideTracker()
end

function BT.ShutdownEngine()
	if BT.engineFrame then
		BT.engineFrame:SetScript("OnUpdate", nil)
		BT.engineFrame:UnregisterAllEvents()
		BT.engineFrame = nil
	end
	--[[
	BT.previewActive = false
	BT.previewEntries = nil
	]]
	BT.HideTracker()
end
