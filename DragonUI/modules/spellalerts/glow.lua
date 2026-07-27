local unusedOverlayGlows = {}
local numOverlays = 0

local ACTION_BUTTON_NAMES = {
	"ActionButton",
	"MultiBarBottomLeftButton",
	"MultiBarBottomRightButton",
	"MultiBarRightButton",
	"MultiBarLeftButton",
	"BonusActionButton",
}

local function IsAnimPlaying(self)
	return self.isPlaying
end

local function ApplyGlowLayout(button, overlay)
	local scale = DragonUISpellAlert_GetGlowScale()
	local alpha = DragonUISpellAlert_GetGlowAlpha()
	local frameWidth, frameHeight = button:GetSize()
	if not frameWidth or frameWidth == 0 then
		frameWidth = 36
	end
	if not frameHeight or frameHeight == 0 then
		frameHeight = 36
	end
	local overhang = (scale - 1) * 0.5
	overlay:SetParent(button)
	overlay:ClearAllPoints()
	overlay:SetSize(frameWidth * scale, frameHeight * scale)
	overlay:SetPoint("TOPLEFT", button, "TOPLEFT", -frameWidth * overhang, frameHeight * overhang)
	overlay:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", frameWidth * overhang, -frameHeight * overhang)
	overlay:SetFrameLevel(math.max(button:GetFrameLevel() + 10, 10))
	overlay:EnableMouse(false)
	overlay:SetAlpha(alpha)
end

function DragonUISpellAlertActionButton_Update(self)
	if not self or not self.action then
		return
	end
	if HasAction(self.action) then
		if not self.duiSpellAlertEventsRegistered then
			DragonUISpellAlert_RegisterEvent("DRAGONUI_SPELL_ALERT_GLOW_SHOW", self, DragonUISpellAlertActionButton_OnEventOverlayGlowShow)
			DragonUISpellAlert_RegisterEvent("DRAGONUI_SPELL_ALERT_GLOW_HIDE", self, DragonUISpellAlertActionButton_OnEventOverlayGlowHide)
			self.duiSpellAlertEventsRegistered = true
		end
	else
		if self.duiSpellAlertEventsRegistered then
			DragonUISpellAlert_UnregisterEvent("DRAGONUI_SPELL_ALERT_GLOW_SHOW", self)
			DragonUISpellAlert_UnregisterEvent("DRAGONUI_SPELL_ALERT_GLOW_HIDE", self)
			self.duiSpellAlertEventsRegistered = nil
		end
	end

	DragonUISpellAlertActionButton_UpdateOverlayGlow(self)
end

hooksecurefunc("ActionButton_Update", DragonUISpellAlertActionButton_Update)

function DragonUISpellAlertActionButton_GetOverlayGlow()
	local overlay = tremove(unusedOverlayGlows)
	if not overlay then
		numOverlays = numOverlays + 1
		overlay = CreateFrame("Frame", "DragonUIActionButtonOverlay" .. numOverlays, UIParent, "DragonUIActionBarButtonSpellActivationAlert")
		overlay:EnableMouse(false)
		local animOut = overlay.animOut
		animOut.isPlaying = false
		animOut.IsPlaying = IsAnimPlaying
	end
	return overlay
end

function DragonUISpellAlertActionButton_UpdateOverlayGlow(self)
	if not DragonUISpellAlert_ShowGlow() then
		DragonUISpellAlertActionButton_HideOverlayGlow(self)
		return
	end
	local globalID = DragonUISpellAlert_GetActionSpellID(self.action)
	if globalID and DragonUISpellAlert_IsSpellOverlayed(globalID) then
		DragonUISpellAlertActionButton_ShowOverlayGlow(self)
	else
		DragonUISpellAlertActionButton_HideOverlayGlow(self)
	end
end

function DragonUISpellAlertActionButton_ShowOverlayGlow(self)
	if self.duiSpellAlertOverlay then
		ApplyGlowLayout(self, self.duiSpellAlertOverlay)
		if self.duiSpellAlertOverlay.animOut:IsPlaying() then
			self.duiSpellAlertOverlay.animOut:Stop()
			self.duiSpellAlertOverlay.animIn:Play()
		end
	else
		self.duiSpellAlertOverlay = DragonUISpellAlertActionButton_GetOverlayGlow()
		ApplyGlowLayout(self, self.duiSpellAlertOverlay)
		self.duiSpellAlertOverlay.animIn:Play()
	end
	-- Ensure visible even if anim updates fail on this client.
	local overlay = self.duiSpellAlertOverlay
	if overlay then
		overlay:Show()
		overlay:SetAlpha(DragonUISpellAlert_GetGlowAlpha())
		if overlay.outerGlow then overlay.outerGlow:SetAlpha(1) end
		if overlay.ants then overlay.ants:SetAlpha(1) end
	end
end

function DragonUISpellAlertActionButton_HideOverlayGlow(self)
	if self.duiSpellAlertOverlay then
		if self.duiSpellAlertOverlay.animIn:IsPlaying() then
			self.duiSpellAlertOverlay.animIn:Stop()
		end
		if self:IsVisible() then
			self.duiSpellAlertOverlay.animOut:Play()
		else
			DragonUISpellAlertActionButton_OverlayGlowAnimOutFinished(self.duiSpellAlertOverlay.animOut)
		end
	end
end

function DragonUISpellAlertActionButton_OverlayGlowAnimOutFinished(animGroup)
	local overlay = animGroup:GetParent()
	local actionButton = overlay:GetParent()
	overlay:Hide()
	tinsert(unusedOverlayGlows, overlay)
	if actionButton then
		actionButton.duiSpellAlertOverlay = nil
	end
end

function DragonUISpellAlertActionButton_OnEvent(self, event)
	if event == "ACTIONBAR_PAGE_CHANGED" or event == "UPDATE_BONUS_ACTIONBAR" then
		local globalID = DragonUISpellAlert_GetActionSpellID(self.action)
		if not globalID then
			DragonUISpellAlertActionButton_HideOverlayGlow(self)
		end
		return
	end
end

hooksecurefunc("ActionButton_OnEvent", DragonUISpellAlertActionButton_OnEvent)

function DragonUISpellAlertActionButton_OnEventOverlayGlowShow(self, arg1)
	local globalID = DragonUISpellAlert_GetActionSpellID(self.action)
	if globalID and globalID == arg1 then
		DragonUISpellAlertActionButton_ShowOverlayGlow(self)
	end
end

function DragonUISpellAlertActionButton_OnEventOverlayGlowHide(self, arg1)
	local globalID = DragonUISpellAlert_GetActionSpellID(self.action)
	if globalID and globalID == arg1 then
		DragonUISpellAlertActionButton_HideOverlayGlow(self)
	end
end

function DragonUISpellAlertActionButton_ApplySettingsToActiveGlows()
	for i = 1, numOverlays do
		local overlay = _G["DragonUIActionButtonOverlay" .. i]
		if overlay and overlay:IsShown() then
			local button = overlay:GetParent()
			if button and button.duiSpellAlertOverlay == overlay then
				ApplyGlowLayout(button, overlay)
			else
				overlay:SetAlpha(DragonUISpellAlert_GetGlowAlpha())
			end
		end
	end
end

function DragonUISpellAlertActionButton_SyncAllButtons()
	for _, prefix in ipairs(ACTION_BUTTON_NAMES) do
		for i = 1, 12 do
			local button = _G[prefix .. i]
			if button then
				DragonUISpellAlertActionButton_Update(button)
			end
		end
	end
end

function DragonUISpellAlertActionButton_ForceGlowOnMainBar(enable)
	for i = 1, 12 do
		local button = _G["ActionButton" .. i]
		if button then
			if enable then
				DragonUISpellAlertActionButton_ShowOverlayGlow(button)
			else
				DragonUISpellAlertActionButton_HideOverlayGlow(button)
			end
		end
	end
end
