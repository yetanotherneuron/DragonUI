local addon = select(2, ...)
if not addon then addon = _G.DragonUI end

-- ============================================================================
-- DragonUI Buff Tracker - Data schema, color presets, watch-list helpers
-- ============================================================================

DragonUIBuffTracker = DragonUIBuffTracker or {}

local BT = DragonUIBuffTracker

BT.CLASS_TOKENS = {
	"WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST",
	"DEATHKNIGHT", "SHAMAN", "MAGE", "WARLOCK", "DRUID",
}

BT.CATEGORY_ORDER = {
	"classes_actives",
	"classes_passives",
	"buffs",
	"procs",
	"consume",
	"stacks",
	"enchants",
}

BT.BORDER_PRESETS = {
	red            = { r = 1.00, g = 0.15, b = 0.15 },
	utility        = { r = 0.20, g = 0.50, b = 1.00 },
	consumables    = { r = 1.00, g = 0.65, b = 0.10 },
	spells         = { r = 1.00, g = 0.15, b = 0.15 },
	buffs_enchants = { r = 0.65, g = 0.30, b = 0.90 },
	procs          = { r = 1.00, g = 0.35, b = 0.45 },
	stacks         = { r = 0.55, g = 0.55, b = 0.55 },
}

BT.BORDER_MODE_LABELS = {
	red = "Red (default)",
	class = "Class Color",
	utility = "Utility (blue)",
	consumables = "Consumables (orange)",
	spells = "Spells (red)",
	buffs_enchants = "Buffs / Enchants (purple)",
	procs = "Procs (pink-red)",
	stacks = "Stacks (gray)",
}

BT.CATEGORY_DEFAULTS = {
	classes_actives = "spells",
	classes_passives = "procs",
	buffs = "utility",
	procs = "procs",
	consume = "consumables",
	stacks = "stacks",
	enchants = "buffs_enchants",
}

BT.CATEGORY_DEFAULTS_ENABLED = {
	classes_actives = true,
	classes_passives = true,
	buffs = false,
	procs = true,
	consume = false,
	stacks = true,
	enchants = false,
}

local function Trim(s)
	if not s then return "" end
	return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

function BT.ParseSpellIDs(raw)
	local ids = {}
	if not raw or raw == "" then
		return ids
	end
	for token in string.gmatch(raw, "[^,;]+") do
		local id = tonumber(Trim(token))
		if id and id > 0 then
			ids[#ids + 1] = id
		end
	end
	table.sort(ids)
	return ids
end

function BT.NormalizeSpellEntry(entry)
	if type(entry) == "number" then
		return { spellID = entry }
	end
	if type(entry) ~= "table" then
		return nil
	end

	local auraID = entry.auraID or entry.aura or entry.id or entry.spellID
	if not auraID or auraID <= 0 then
		return nil
	end

	local tooltipID = entry.spellID or entry.tooltipID or auraID

	local border = entry.border or entry.borderMode
	local borderColor = entry.borderColor or entry.color
	if type(border) == "table" and border.r then
		borderColor = border
		border = nil
	end

	local showDuration = entry.duration
	if showDuration == nil then
		showDuration = entry.showDuration
	end
	local showStacks = entry.stacks
	if showStacks == nil then
		showStacks = entry.showStacks
	end
	local showLowTime = entry.lowTime
	if showLowTime == nil then
		showLowTime = entry.showLowTime
	end

	local ranks = entry.ranks
	if type(ranks) ~= "table" or #ranks == 0 then
		ranks = nil
	end

	return {
		spellID = auraID,
		tooltipID = tooltipID,
		borderMode = type(border) == "string" and border or nil,
		borderColor = borderColor,
		showDuration = showDuration,
		showStacks = showStacks,
		showLowTime = showLowTime,
		ranks = ranks,
	}
end

function BT.IsCategoryEnabled(cfg, categoryKey)
	if not cfg or not cfg.categories then
		local default = BT.CATEGORY_DEFAULTS_ENABLED[categoryKey]
		return default ~= false
	end
	local val = cfg.categories[categoryKey]
	if val == nil then
		local default = BT.CATEGORY_DEFAULTS_ENABLED[categoryKey]
		return default ~= false
	end
	return val == true
end

function BT.ShouldDisplayWatch(cfg, watch)
	if not cfg or not watch then
		return false
	end
	if watch.category == "stacks" then
		return cfg.track_target_debuffs ~= false
	end
	return BT.IsCategoryEnabled(cfg, watch.category)
end

function BT.GetClassColor(classToken)
	local cc = RAID_CLASS_COLORS and RAID_CLASS_COLORS[classToken]
	if cc then
		return cc.r, cc.g, cc.b
	end
	return 1, 0.15, 0.15
end

function BT.ResolveBorderColor(borderMode, playerClass, borderColor)
	if borderColor and borderColor.r then
		return borderColor.r, borderColor.g, borderColor.b
	end
	local preset = BT.BORDER_PRESETS[borderMode]
	if preset then
		return preset.r, preset.g, preset.b
	end
	if borderMode == "class" and playerClass then
		return BT.GetClassColor(playerClass)
	end
	local fallback = BT.BORDER_PRESETS.red
	return fallback.r, fallback.g, fallback.b
end

function BT.GetListConfig(cfg, categoryKey, classToken)
	local lists = cfg and cfg.lists
	if not lists then return nil end

	if categoryKey == "classes_actives" or categoryKey == "classes_passives" then
		local branch = categoryKey == "classes_actives" and "actives" or "passives"
		local classes = lists.classes
		if classes and classes[branch] and classToken then
			return classes[branch][classToken]
		end
		return nil
	end

	return lists[categoryKey]
end

function BT.GetCategoryBorderMode(cfg, categoryKey, classToken)
	local listCfg = BT.GetListConfig(cfg, categoryKey, classToken)
	if listCfg and listCfg.border_mode and listCfg.border_mode ~= "" then
		return listCfg.border_mode
	end
	if cfg and cfg.default_border_mode and cfg.default_border_mode ~= "" then
		return cfg.default_border_mode
	end
	return BT.CATEGORY_DEFAULTS[categoryKey] or "red"
end

function BT.GetHardcodedEntries(categoryKey, classToken)
	local lists = BT.WATCH_LISTS
	if not lists then return {} end

	local raw
	if categoryKey == "classes_actives" then
		raw = lists.classes and lists.classes.actives and lists.classes.actives[classToken]
	elseif categoryKey == "classes_passives" then
		raw = lists.classes and lists.classes.passives and lists.classes.passives[classToken]
	else
		raw = lists[categoryKey]
	end

	if not raw then return {} end

	local normalized = {}
	for i = 1, #raw do
		local entry = BT.NormalizeSpellEntry(raw[i])
		if entry then
			normalized[#normalized + 1] = entry
		end
	end
	return normalized
end

function BT.BuildWatchEntries(cfg)
	local entries = {}
	local seen = {}
	cfg = cfg or {}

	local function registerWatchID(spellID, normalized, categoryKey, classToken)
		if not spellID or spellID <= 0 or seen[spellID] then
			return
		end
		seen[spellID] = true

		local borderMode = normalized.borderMode or BT.GetCategoryBorderMode(cfg, categoryKey, classToken)
		entries[#entries + 1] = {
			spellID = spellID,
			primarySpellID = normalized.spellID,
			tooltipID = normalized.tooltipID or spellID,
			category = categoryKey,
			classToken = classToken,
			borderMode = borderMode,
			borderColor = normalized.borderColor,
			showDuration = normalized.showDuration,
			showStacks = normalized.showStacks,
			showLowTime = normalized.showLowTime,
		}
	end

	local function registerEntry(normalized, categoryKey, classToken, requireCategory)
		if not normalized or not normalized.spellID or normalized.spellID <= 0 then
			return
		end
		if requireCategory and not BT.IsCategoryEnabled(cfg, categoryKey) then
			return
		end

		registerWatchID(normalized.spellID, normalized, categoryKey, classToken)

		local ranks = normalized.ranks
		if ranks then
			for i = 1, #ranks do
				registerWatchID(ranks[i], normalized, categoryKey, classToken)
			end
		end
	end

	local function addHardcodedList(categoryKey, classToken)
		local list = BT.GetHardcodedEntries(categoryKey, classToken)
		for i = 1, #list do
			registerEntry(list[i], categoryKey, classToken, false)
		end
	end

	local function addFromConfig(categoryKey, listCfg, classToken)
		if not listCfg then return end
		local ids = BT.ParseSpellIDs(listCfg.spell_ids)
		for i = 1, #ids do
			registerEntry({ spellID = ids[i] }, categoryKey, classToken, true)
		end
	end

	for _, classToken in ipairs(BT.CLASS_TOKENS) do
		addHardcodedList("classes_actives", classToken)
		addHardcodedList("classes_passives", classToken)
	end

	addHardcodedList("buffs")
	addHardcodedList("procs")

	if BT.ICD_RegisterWatchEntries then
		BT.ICD_RegisterWatchEntries(registerWatchID, seen)
	end

	addHardcodedList("consume")
	addHardcodedList("stacks")
	addHardcodedList("enchants")

	for _, classToken in ipairs(BT.CLASS_TOKENS) do
		addFromConfig("classes_actives", BT.GetListConfig(cfg, "classes_actives", classToken), classToken)
		addFromConfig("classes_passives", BT.GetListConfig(cfg, "classes_passives", classToken), classToken)
	end

	addFromConfig("buffs", cfg.lists and cfg.lists.buffs)
	addFromConfig("procs", cfg.lists and cfg.lists.procs)
	addFromConfig("consume", cfg.lists and cfg.lists.consume)
	addFromConfig("stacks", cfg.lists and cfg.lists.stacks)
	addFromConfig("enchants", cfg.lists and cfg.lists.enchants)

	return entries
end

function BT.BuildWatchMap(cfg)
	local map = {}
	local nameMap = {}
	local watchEntries = BT.BuildWatchEntries(cfg)
	for i = 1, #watchEntries do
		local entry = watchEntries[i]
		map[entry.spellID] = entry
		local spellName = GetSpellInfo(entry.spellID)
		if spellName then
			nameMap[string.lower(spellName)] = entry.spellID
		end
	end
	BT.watchNameMap = nameMap
	BT.stackWatchIDs = BT.stackWatchIDs or {}
	wipe(BT.stackWatchIDs)
	for id, entry in pairs(map) do
		if entry.category == "stacks" then
			BT.stackWatchIDs[#BT.stackWatchIDs + 1] = id
		end
	end
	return map
end

function BT.ResolveSpellIdByName(name)
	if not name or name == "" then
		return nil
	end
	local key = string.lower(name)
	if BT.watchNameMap and BT.watchNameMap[key] then
		return BT.watchNameMap[key]
	end
	local debuffRuntime = addon.Nameplates and addon.Nameplates.auras and addon.Nameplates.auras.DebuffRuntime
	if debuffRuntime then
		if debuffRuntime.WarmSpellNameIndex then
			debuffRuntime.WarmSpellNameIndex()
		end
		if debuffRuntime.ResolveSpellIdByName then
			return debuffRuntime.ResolveSpellIdByName(name)
		end
	end
	return nil
end

function BT.GetWatchDisplayKey(watch, watchSpellID, rawSpellID, aura)
	if aura and aura.icdOnly then
		return tostring(aura.spellID or rawSpellID)
	end
	if watch and watch.primarySpellID then
		return tostring(watch.primarySpellID)
	end
	return tostring(watchSpellID or rawSpellID)
end

function BT.FindWatchForAura(watchMap, name, spellID)
	if not watchMap then
		return nil, nil
	end

	spellID = tonumber(spellID)
	if spellID and spellID > 0 and watchMap[spellID] then
		return spellID, watchMap[spellID]
	end

	if name then
		local resolved = BT.ResolveSpellIdByName(name)
		if resolved and watchMap[resolved] then
			return resolved, watchMap[resolved]
		end

		local key = string.lower(name)
		local stackIDs = BT.stackWatchIDs
		if stackIDs then
			for i = 1, #stackIDs do
				local id = stackIDs[i]
				local watchName = GetSpellInfo(id)
				if watchName and string.lower(watchName) == key then
					return id, watchMap[id]
				end
			end
		end
	end

	return nil, nil
end

function BT.DefaultClassListsTable(borderMode)
	local out = {}
	for _, classToken in ipairs(BT.CLASS_TOKENS) do
		out[classToken] = {
			spell_ids = "",
			border_mode = borderMode,
		}
	end
	return out
end

function BT.DefaultListsTable()
	return {
		classes = {
			actives = BT.DefaultClassListsTable(BT.CATEGORY_DEFAULTS.classes_actives),
			passives = BT.DefaultClassListsTable(BT.CATEGORY_DEFAULTS.classes_passives),
		},
		buffs = { spell_ids = "", border_mode = BT.CATEGORY_DEFAULTS.buffs },
		procs = { spell_ids = "", border_mode = BT.CATEGORY_DEFAULTS.procs },
		consume = { spell_ids = "", border_mode = BT.CATEGORY_DEFAULTS.consume },
		stacks = { spell_ids = "", border_mode = BT.CATEGORY_DEFAULTS.stacks },
		enchants = { spell_ids = "", border_mode = BT.CATEGORY_DEFAULTS.enchants },
	}
end

function BT.DefaultCategoriesTable()
	return {
		classes_actives = true,
		classes_passives = true,
		buffs = false,
		procs = true,
		consume = false,
		stacks = true,
		enchants = false,
	}
end

function BT.GetLowTimeShowMode(cfg)
	local mode = cfg and cfg.buff_low_time_show_mode
	if mode == "always" or mode == "never" or mode == "low_time" then
		return mode
	end
	return "low_time"
end

function BT.ShouldShowLowTimeBuff(cfg, watch, aura, displayKey, state)
	if not watch or not watch.showLowTime then
		return true
	end
	if not aura or not aura.expiration or aura.expiration <= 0 then
		return false
	end

	local tick = GetTime()
	local remain = aura.remain
	if remain == nil or remain <= 0 then
		remain = aura.expiration - tick
	end
	if remain <= 0 then
		return false
	end

	local threshold = (cfg and cfg.buff_low_time_threshold_sec) or 300
	local pct = (cfg and cfg.buff_low_time_percent) or 0.10
	local total = aura.duration

	if displayKey and state then
		state.lowTimeSession = state.lowTimeSession or {}
		local session = state.lowTimeSession[displayKey]
		if not session then
			session = {}
			state.lowTimeSession[displayKey] = session
		end

		local lastRemain = session.lastRemain
		local lastExpiration = session.lastExpiration
		-- Detect rebuff/refresh: remaining time or expiration jumped up.
		if (lastRemain and remain > lastRemain + 5)
			or (lastExpiration and aura.expiration > lastExpiration + 5) then
			session.peak = remain
		elseif not session.peak or remain > session.peak then
			session.peak = remain
		end

		session.lastRemain = remain
		session.lastExpiration = aura.expiration

		if (not total or total <= 0) and session.peak then
			total = session.peak
		elseif session.peak and session.peak > total then
			total = session.peak
		end
	end

	-- Prefer % of total duration when known (e.g. last 10% of a 10m shout).
	-- Absolute threshold is only a fallback when total duration is unknown.
	if total and total > 0 then
		return remain <= (total * pct)
	end
	if remain <= threshold then
		return true
	end
	return false
end

function BT.NeedsTargetAuraScan(cfg)
	cfg = cfg or {}
	return cfg.track_target_debuffs ~= false
end
