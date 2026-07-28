local addon = select(2, ...)
if not addon then addon = _G.DragonUI end

-- ============================================================================
-- Internal cooldown tracking via combat log (trinket / weapon procs)
-- ============================================================================

local BT = DragonUIBuffTracker

local GetTime = GetTime
local tonumber = tonumber
local string_sub = string.sub
local pairs = pairs
local wipe = wipe
local select = select

local INVALID_CLEU_EVENTS = {
	SPELL_DISPEL = true,
	SPELL_DISPEL_FAILED = true,
	SPELL_STOLEN = true,
	SPELL_AURA_REMOVED = true,
	SPELL_AURA_REMOVED_DOSE = true,
	SPELL_AURA_BROKEN = true,
	SPELL_AURA_BROKEN_SPELL = true,
	SPELL_CAST_FAILED = true,
}

BT.icdState = BT.icdState or {
	byItem = {},
	procAuras = {},
	lookupsReady = false,
	spellToItem = {},
	cooldowns = {},
	itemToSpells = {},
	itemPrimarySpell = {},
}

local state = BT.icdState

local function NormalizeItemEntry(entry)
	if type(entry) == "table" then
		return entry
	end
	return { entry }
end

function BT.BuildICDLookups()
	if state.lookupsReady then
		return
	end

	wipe(state.spellToItem)
	wipe(state.cooldowns)
	wipe(state.itemToSpells)
	wipe(state.itemPrimarySpell)

	local spellToItem = BT.ICD_SPELL_TO_ITEM or {}
	for rawSpellID, itemEntry in pairs(spellToItem) do
		local spellID = tonumber(rawSpellID)
		if spellID and spellID > 0 then
			state.spellToItem[spellID] = itemEntry
			local items = NormalizeItemEntry(itemEntry)
			for i = 1, #items do
				local itemID = items[i]
				if itemID and itemID > 0 then
					local bucket = state.itemToSpells[itemID]
					if not bucket then
						bucket = {}
						state.itemToSpells[itemID] = bucket
					end
					bucket[#bucket + 1] = spellID
				end
			end
		end
	end

	local primarySpells = BT.ICD_ITEM_PRIMARY_SPELL or {}
	for rawItemID, spellID in pairs(primarySpells) do
		local itemID = tonumber(rawItemID)
		spellID = tonumber(spellID)
		if itemID and spellID then
			state.itemPrimarySpell[itemID] = spellID
		end
	end

	for itemID, spells in pairs(state.itemToSpells) do
		if not state.itemPrimarySpell[itemID] and spells[1] then
			state.itemPrimarySpell[itemID] = spells[1]
		end
	end

	local cooldowns = BT.ICD_COOLDOWNS or {}
	for rawSpellID, rawDuration in pairs(cooldowns) do
		local spellID = tonumber(rawSpellID)
		local duration = tonumber(rawDuration)
		if spellID and spellID > 0 and duration and duration > 0 then
			state.cooldowns[spellID] = duration
		end
	end

	state.lookupsReady = true
end

function BT.IsICDItemEquipped(itemID)
	itemID = tonumber(itemID)
	if not itemID or itemID <= 0 then
		return false
	end
	for slot = 0, 19 do
		if GetInventoryItemID("player", slot) == itemID then
			return true
		end
	end
	return false
end

function BT.GetICDCooldownDuration(spellID)
	spellID = tonumber(spellID)
	if not spellID then
		return BT.ICD_DEFAULT_DURATION or 45
	end
	return state.cooldowns[spellID] or BT.ICD_DEFAULT_DURATION or 45
end

function BT.ItemHasActiveProcAura(itemID, activeAuras, watchMap)
	local spells = state.itemToSpells[itemID]
	if not spells or not activeAuras then
		return false
	end
	for i = 1, #spells do
		local spellID = spells[i]
		if activeAuras[spellID] then
			return true
		end
		if BT.FindWatchForAura then
			for activeID, aura in pairs(activeAuras) do
				local resolvedID = BT.FindWatchForAura(watchMap, aura.name, activeID)
				if resolvedID == spellID then
					return true
				end
			end
		end
	end
	return false
end

function BT.SetICDCooldown(itemID, spellID)
	itemID = tonumber(itemID)
	spellID = tonumber(spellID)
	if not itemID or not spellID then
		return
	end
	local duration = BT.GetICDCooldownDuration(spellID)
	if duration <= 0 then
		return
	end
	local now = GetTime()
	state.byItem[itemID] = {
		itemID = itemID,
		procSpellID = spellID,
		start = now,
		duration = duration,
		expiration = now + duration,
	}
end

function BT.NoteICDProcAura(spellID)
	spellID = tonumber(spellID)
	if not spellID or spellID <= 0 then
		return
	end

	local name, _, icon = GetSpellInfo(spellID)
	local now = GetTime()
	local duration = BT.ICD_PROC_BUFF_DURATION or 30

	state.procAuras[spellID] = {
		spellID = spellID,
		name = name,
		texture = icon,
		count = 1,
		duration = duration,
		expiration = now + duration,
		remain = duration,
		fromICD = true,
	}
end

function BT.HandleICDCombatLog()
	if not CombatLogGetCurrentEventInfo then
		return false
	end

	BT.BuildICDLookups()

	local _, event, _, sourceGUID, _, _, _, destGUID, _, _, _, spellID = CombatLogGetCurrentEventInfo()
	spellID = tonumber(spellID)
	if not spellID or spellID <= 0 then
		return false
	end
	if INVALID_CLEU_EVENTS[event] then
		return false
	end
	if string_sub(event, 1, 6) ~= "SPELL_" then
		return false
	end

	local playerGUID = UnitGUID("player")
	if not playerGUID then
		return false
	end
	if destGUID ~= playerGUID and sourceGUID ~= playerGUID then
		return false
	end
	if destGUID == playerGUID and sourceGUID and sourceGUID ~= playerGUID and sourceGUID ~= destGUID then
		return false
	end

	local itemEntry = state.spellToItem[spellID]
	if not itemEntry then
		return false
	end

	if event == "SPELL_AURA_APPLIED" or event == "SPELL_AURA_REFRESH" then
		BT.NoteICDProcAura(spellID)
	end

	local handled = false
	local items = NormalizeItemEntry(itemEntry)
	for i = 1, #items do
		local itemID = items[i]
		if BT.IsICDItemEquipped(itemID) then
			BT.SetICDCooldown(itemID, spellID)
			handled = true
		end
	end
	return handled or event == "SPELL_AURA_APPLIED" or event == "SPELL_AURA_REFRESH"
end

function BT.PruneICDState(activeAuras)
	local now = GetTime()
	for itemID, icd in pairs(state.byItem) do
		if not BT.IsICDItemEquipped(itemID) or (icd.expiration and icd.expiration <= now) then
			state.byItem[itemID] = nil
		end
	end

	for spellID, aura in pairs(state.procAuras) do
		if aura.expiration and aura.expiration <= now then
			state.procAuras[spellID] = nil
		elseif activeAuras and activeAuras[spellID] then
			state.procAuras[spellID] = nil
		end
	end
end

function BT.MergeICDProcAuras(activeAuras, watchMap, cfg)
	if not activeAuras or not cfg then
		return activeAuras
	end
	if not BT.IsCategoryEnabled(cfg, "procs") then
		BT.PruneICDState(activeAuras)
		return activeAuras
	end

	BT.BuildICDLookups()
	BT.PruneICDState(activeAuras)

	for spellID, aura in pairs(state.procAuras) do
		if not activeAuras[spellID] then
			local resolvedID, watch = BT.FindWatchForAura(watchMap, aura.name, spellID)
			if watch and BT.ShouldDisplayWatch(cfg, watch) then
				activeAuras[resolvedID or spellID] = aura
			end
		end
	end

	local now = GetTime()
	for itemID, icd in pairs(state.byItem) do
		if BT.IsICDItemEquipped(itemID) and icd.expiration and icd.expiration > now then
			if not BT.ItemHasActiveProcAura(itemID, activeAuras, watchMap) then
				local primarySpell = state.itemPrimarySpell[itemID] or icd.procSpellID
				local _, watch = BT.FindWatchForAura(watchMap, GetSpellInfo(primarySpell), primarySpell)
				if watch and BT.ShouldDisplayWatch(cfg, watch) then
					local texture = select(10, GetItemInfo(itemID))
					if not texture then
						texture = select(3, GetSpellInfo(primarySpell))
					end
					activeAuras["icd:" .. itemID] = {
						spellID = primarySpell,
						name = GetSpellInfo(primarySpell),
						texture = texture,
						count = 1,
						duration = icd.duration,
						expiration = icd.expiration,
						remain = icd.expiration - now,
						icdOnly = true,
						itemID = itemID,
					}
				end
			end
		end
	end

	return activeAuras
end

function BT.ICD_RegisterWatchEntries(registerWatchID, seen)
	BT.BuildICDLookups()
	for rawSpellID in pairs(state.spellToItem) do
		local spellID = tonumber(rawSpellID)
		if spellID and not seen[spellID] then
			registerWatchID(spellID, {
				spellID = spellID,
				tooltipID = spellID,
				borderMode = "procs",
				showDuration = true,
			}, "procs", nil)
		end
	end
end

function BT.ClearICDState()
	wipe(state.byItem)
	wipe(state.procAuras)
end

function BT.SyncICDEvents(frame, enabled)
	if not frame then
		return
	end
	if enabled then
		frame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
	else
		frame:UnregisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
	end
end

function BT.OnICDEquipmentChanged()
	BT.ClearICDState()
	if BT.UpdateTracker then
		BT.UpdateTracker()
	end
end

function BT.OnICDCombatLogEvent()
	local cfg = addon:GetModuleConfig("bufftracker")
	if not cfg or not addon:IsModuleEnabled("bufftracker") then
		return
	end
	if not BT.IsCategoryEnabled(cfg, "procs") then
		return
	end
	if BT.HandleICDCombatLog() then
		BT.UpdateTracker()
	end
end
