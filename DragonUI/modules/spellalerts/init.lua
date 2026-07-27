local addon = select(2, ...)

local SpellAlertsModule = {
	initialized = false,
	applied = false,
}

if addon.RegisterModule then
	addon:RegisterModule(
		"spellalerts",
		SpellAlertsModule,
		(addon.L and addon.L["Spell Alerts"]) or "Spell Alerts",
		(addon.L and addon.L["Cataclysm-style spell activation overlays and action button glows"])
			or "Cataclysm-style spell activation overlays and action button glows",
		{ loadOnce = true }
	)
end

-- Lightweight: only push scale/alpha/spacing to currently visible effects.
function addon.ApplySpellAlertVisualSettings()
	if DragonUISpellActivationOverlay_ApplySettings then
		DragonUISpellActivationOverlay_ApplySettings()
	end
	if DragonUISpellAlertActionButton_ApplySettingsToActiveGlows then
		DragonUISpellAlertActionButton_ApplySettingsToActiveGlows()
	end
end

-- Full rebuild from current buffs + button sync (login / hard apply).
function addon.ApplySpellAlerts()
	SpellAlertsModule.applied = true
	addon.ApplySpellAlertVisualSettings()
	if DragonUISpellAlert_RefreshDisplay then
		DragonUISpellAlert_RefreshDisplay()
	end
	if DragonUISpellAlertActionButton_SyncAllButtons then
		DragonUISpellAlertActionButton_SyncAllButtons()
	end
end

-- Options toggles: rebuild alert state without rescanning every action button.
function addon.RefreshSpellAlerts()
	SpellAlertsModule.applied = true
	addon.ApplySpellAlertVisualSettings()
	if DragonUISpellAlert_RefreshDisplay then
		DragonUISpellAlert_RefreshDisplay()
	end
end

-- Prefer this from sliders so the options UI stays responsive.
function addon.RefreshSpellAlertSettings()
	addon.ApplySpellAlertVisualSettings()
end

addon.RefreshSpellAlertsSystem = addon.RefreshSpellAlerts
addon.ApplySpellAlertsSystem = addon.ApplySpellAlerts

local boot = CreateFrame("Frame")
boot:RegisterEvent("PLAYER_LOGIN")
boot:SetScript("OnEvent", function(self)
	self:UnregisterEvent("PLAYER_LOGIN")
	SpellAlertsModule.initialized = true
	addon.ApplySpellAlerts()
end)
