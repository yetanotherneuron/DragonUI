local addon = select(2, ...)

local BuffTrackerModule = {
	initialized = false,
	applied = false,
}

if addon.RegisterModule then
	addon:RegisterModule(
		"bufftracker",
		BuffTrackerModule,
		(addon.L and addon.L["Buff Tracker"]) or "Buff Tracker",
		(addon.L and addon.L["Track selected player buffs above the Personal Resource Display."])
			or "Track selected player buffs above the Personal Resource Display.",
		{ loadOnce = true }
	)
end

function addon.ApplyBuffTracker()
	BuffTrackerModule.applied = true
	if DragonUIBuffTracker_StartEngine then
		DragonUIBuffTracker_StartEngine()
	end
end

function addon.RefreshBuffTracker()
	if not addon:IsModuleEnabled("bufftracker") then
		if DragonUIBuffTracker_StopEngine then
			DragonUIBuffTracker_StopEngine()
		end
		return
	end
	BuffTrackerModule.applied = true
	if DragonUIBuffTracker_StartEngine then
		DragonUIBuffTracker_StartEngine()
	elseif DragonUIBuffTracker_UpdateTracker then
		DragonUIBuffTracker_UpdateTracker()
	end
end

function addon.RestoreBuffTracker()
	BuffTrackerModule.applied = false
	--[[
	if DragonUIBuffTracker_StopPreview then
		DragonUIBuffTracker_StopPreview()
	end
	]]
	if DragonUIBuffTracker_ShutdownEngine then
		DragonUIBuffTracker_ShutdownEngine()
	end
end

addon.RefreshBuffTrackerSystem = addon.RefreshBuffTracker
addon.ApplyBuffTrackerSystem = addon.ApplyBuffTracker
addon.RestoreBuffTrackerSystem = addon.RestoreBuffTracker

function DragonUIBuffTracker_StartEngine()
	local BT = DragonUIBuffTracker
	if BT and BT.StartEngine then
		BT.StartEngine()
	end
end

function DragonUIBuffTracker_StopEngine()
	local BT = DragonUIBuffTracker
	if BT and BT.StopEngine then
		BT.StopEngine()
	end
end

function DragonUIBuffTracker_ShutdownEngine()
	local BT = DragonUIBuffTracker
	if BT and BT.ShutdownEngine then
		BT.ShutdownEngine()
	end
end

function DragonUIBuffTracker_UpdateTracker()
	local BT = DragonUIBuffTracker
	if BT and BT.UpdateTracker then
		BT.UpdateTracker()
	end
end

local boot = CreateFrame("Frame")
boot:RegisterEvent("PLAYER_LOGIN")
boot:SetScript("OnEvent", function(self)
	self:UnregisterEvent("PLAYER_LOGIN")
	BuffTrackerModule.initialized = true
	if addon:IsModuleEnabled("bufftracker") then
		addon.ApplyBuffTracker()
	end
end)

if addon.RefreshPlayerResourceSystem then
	hooksecurefunc(addon, "RefreshPlayerResourceSystem", function()
		if BuffTrackerModule.applied and DragonUIBuffTracker_UpdateTracker then
			DragonUIBuffTracker_UpdateTracker()
		end
	end)
end

--[[
local BT = DragonUIBuffTracker

local CATALOG = {
	{
		key = "consume_warning",
		texture = "Interface\\Icons\\INV_Alchemy_Elixir_04",
		category = "consume",
		expirationOffset = 270,
		spellID = 53758,
	},
	{
		key = "consume_expired",
		texture = "Interface\\Icons\\INV_Alchemy_Elixir_04",
		category = "consume",
		triggerExpiredGlow = true,
		spellID = 53758,
	},
	{
		key = "class_passive",
		texture = "Interface\\Icons\\Ability_Warrior_BloodSurge",
		category = "classes_passives",
		spellID = 46916,
	},
	{
		key = "raid_buff",
		texture = "Interface\\Icons\\Ability_Shaman_Heroism",
		category = "buffs",
		expirationOffset = 25,
		spellID = 32182,
	},
	{
		key = "active_cd",
		texture = "Interface\\Icons\\Spell_Holy_AvengineWrath",
		category = "classes_actives",
		expirationOffset = 18,
		spellID = 31884,
	},
	{
		key = "retaliation",
		texture = "Interface\\Icons\\Ability_Warrior_Challange",
		category = "classes_actives",
		expirationOffset = 12,
		count = 12,
		showDuration = true,
		showStacks = true,
		forceStacks = true,
		spellID = 20230,
	},
	{
		key = "target_stack",
		texture = "Interface\\Icons\\Ability_Warrior_Sunder",
		category = "stacks",
		expirationOffset = 30,
		count = 5,
		forceStacks = true,
		spellID = 7386,
	},
	{
		key = "weapon_enchant",
		texture = "Interface\\Icons\\Spell_Nature_BloodLust",
		category = "enchants",
		expirationOffset = 600,
		spellID = 59620,
	},
	{
		key = "item_proc",
		texture = "Interface\\Icons\\Spell_Holy_Heal",
		category = "procs",
		expirationOffset = 12,
		spellID = 67771,
	},
}

local byKey = {}
for _, entry in ipairs(CATALOG) do
	byKey[entry.key] = entry
end

local previewRestore = {}

local function ClearPreviewIconCooldowns()
	local state = BT.layoutState
	if not state or not state.iconsByKey then return end
	for key, icon in pairs(state.iconsByKey) do
		if type(key) == "string" and key:match("^preview_") and BT.ClearIconCooldownState then
			BT.ClearIconCooldownState(icon)
		end
	end
end

local function BeginPreviewEnvironment()
	previewRestore = {}

	if BT.BeginPreviewLayout then
		BT.BeginPreviewLayout()
	end

	if addon.ShowPlayerResourceBuffTrackerPreview then
		previewRestore.prdForced = addon.ShowPlayerResourceBuffTrackerPreview() == true
	end
end

local function EndPreviewEnvironment()
	if BT.EndPreviewLayout then
		BT.EndPreviewLayout()
	end
	if previewRestore.prdForced and addon.HidePlayerResourceBuffTrackerPreview then
		addon.HidePlayerResourceBuffTrackerPreview()
	end
	previewRestore = {}
end

local function BuildPreviewEntry(entry)
	local duration = entry.expirationOffset or 0
	local expiration = 0
	if duration > 0 then
		expiration = GetTime() + duration
	end

	return {
		key = "preview_" .. entry.key,
		spellID = entry.spellID or -90000,
		category = entry.category,
		texture = entry.texture,
		expiration = expiration,
		duration = duration > 0 and duration or nil,
		count = entry.count or 1,
		showDuration = entry.showDuration,
		showStacks = entry.showStacks,
		forceStacks = entry.forceStacks,
		showTooltip = true,
	}
end

local function BuildPreviewEntries()
	local entries = {}
	for _, entry in ipairs(CATALOG) do
		entries[#entries + 1] = BuildPreviewEntry(entry)
	end
	return entries
end

function BT.ShouldEndPreview()
	if not BT.previewActive or not BT.previewEntries then
		return false
	end
	local now = GetTime()
	local hasTimedEntry = false
	for _, entry in ipairs(BT.previewEntries) do
		if entry.duration and entry.duration > 0 and entry.expiration and entry.expiration > 0 then
			hasTimedEntry = true
			if entry.expiration > now then
				return false
			end
		end
	end
	return hasTimedEntry
end

function DragonUIBuffTracker_Preview()
	if BT.previewActive and DragonUIBuffTracker_StopPreview then
		DragonUIBuffTracker_StopPreview()
	end

	BT.previewActive = true
	BT.previewEntries = BuildPreviewEntries()

	if DragonUIBuffTracker_StartEngine then
		DragonUIBuffTracker_StartEngine()
	end

	BeginPreviewEnvironment()
	BT.RefreshLayout(BT.previewEntries)

	for _, previewEntry in ipairs(BT.previewEntries) do
		local catalogKey = previewEntry.key:match("^preview_(.+)$")
		local catalogEntry = catalogKey and byKey[catalogKey]
		if catalogEntry and catalogEntry.triggerExpiredGlow then
			local cfg = addon:GetModuleConfig("bufftracker") or {}
			local icon = BT.layoutState.iconsByKey[previewEntry.key]
			if icon and cfg.consumable_expired_glow ~= false then
				BT.PlayExpiredGlow(icon, cfg.consumable_glow_scale or 1.2, 1.0, 3)
			end
		end
	end

	return true
end

function DragonUIBuffTracker_StopPreview()
	BT.previewActive = false
	BT.previewEntries = nil
	ClearPreviewIconCooldowns()
	EndPreviewEnvironment()
	BT.UpdateTracker()
end

addon.BuffTrackerPreview = addon.BuffTrackerPreview or {}
addon.BuffTrackerPreview.Preview = DragonUIBuffTracker_Preview
addon.BuffTrackerPreview.Stop = DragonUIBuffTracker_StopPreview
]]
