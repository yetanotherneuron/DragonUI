local addon = select(2, ...)
if not addon then addon = _G.DragonUI end

local BT = DragonUIBuffTracker

-- ============================================================================
-- Expired consumable glow (Spell Alerts IconAlert template)
-- ============================================================================

local unusedGlows = {}
local numGlows = 0

local function IsAnimPlaying(self)
	return self.isPlaying
end

local function ApplyGlowLayout(button, overlay, scale, alpha)
	scale = scale or 1.2
	alpha = alpha or 1.0
	local frameWidth, frameHeight = button:GetSize()
	if not frameWidth or frameWidth == 0 then frameWidth = 32 end
	if not frameHeight or frameHeight == 0 then frameHeight = 32 end
	local overhang = (scale - 1) * 0.5
	overlay:SetParent(button)
	overlay:ClearAllPoints()
	overlay:SetSize(frameWidth * scale, frameHeight * scale)
	overlay:SetPoint("TOPLEFT", button, "TOPLEFT", -frameWidth * overhang, frameHeight * overhang)
	overlay:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", frameWidth * overhang, -frameHeight * overhang)
	overlay:SetFrameLevel(math.max(button:GetFrameLevel() + 12, 12))
	overlay:EnableMouse(false)
	overlay:SetAlpha(alpha)
end

local function ReturnGlow(overlay)
	local parent = overlay:GetParent()
	if parent and parent.duiExpiredGlow == overlay then
		parent.duiExpiredGlow = nil
	end
	overlay:Hide()
	overlay:SetParent(UIParent)
	table.insert(unusedGlows, overlay)
end

local function GetOverlayGlow()
	local overlay = table.remove(unusedGlows)
	if not overlay then
		numGlows = numGlows + 1
		overlay = CreateFrame("Frame", "DragonUIBuffTrackerGlow" .. numGlows, UIParent, "DragonUIActionBarButtonSpellActivationAlert")
		overlay:EnableMouse(false)
		overlay:Hide()
		local animOut = overlay.animOut
		animOut.isPlaying = false
		animOut.IsPlaying = IsAnimPlaying
		overlay.duiBuffTrackerGlowOwned = true
		if animOut then
			animOut:HookScript("OnFinished", function(anim)
				local glowFrame = anim:GetParent()
				if glowFrame and glowFrame.duiBuffTrackerGlowOwned then
					ReturnGlow(glowFrame)
				end
			end)
		end
	end
	return overlay
end

function BT.PlayActiveGlow(icon, color, scale, alpha)
	if not icon or not color then return end
	scale = scale or 1.2
	alpha = alpha or 1.0

	local overlay = icon.duiActiveGlow
	if not overlay then
		overlay = GetOverlayGlow()
		icon.duiActiveGlow = overlay
	end

	ApplyGlowLayout(icon, overlay, scale, alpha)
	if DragonUISpellAlert_ApplyBorderGlowOnly then
		DragonUISpellAlert_ApplyBorderGlowOnly(overlay, icon, color)
	else
		icon:Show()
		overlay:Show()
	end
end

function BT.StopActiveGlow(icon)
	if not icon then return end
	local overlay = icon.duiActiveGlow
	if overlay then
		if overlay.animIn and overlay.animIn:IsPlaying() then
			overlay.animIn:Stop()
		end
		ReturnGlow(overlay)
		icon.duiActiveGlow = nil
	end
end

function BT.PlayExpiredGlow(icon, scale, alpha, duration)
	if not icon then return end
	scale = scale or 1.2
	alpha = alpha or 1.0
	duration = duration or 3

	local overlay = icon.duiExpiredGlow
	if not overlay then
		overlay = GetOverlayGlow()
		icon.duiExpiredGlow = overlay
	end

	ApplyGlowLayout(icon, overlay, scale, alpha)
	if DragonUISpellAlert_ApplyBorderGlowOnly then
		DragonUISpellAlert_ApplyBorderGlowOnly(overlay, icon)
	else
		icon:Show()
		overlay:Show()
	end

	local elapsed = 0
	icon:SetScript("OnUpdate", function(self, dt)
		elapsed = elapsed + dt
		if elapsed >= duration then
			self:SetScript("OnUpdate", nil)
			if overlay.animIn and overlay.animIn:IsPlaying() then
				overlay.animIn:Stop()
			end
			if overlay.animOut and overlay.animOut:IsPlaying() then
				overlay.animOut:Stop()
			end
			ReturnGlow(overlay)
			self.duiExpiredGlow = nil
		end
	end)
end

function BT.StopExpiredGlow(icon)
	if not icon then return end
	icon:SetScript("OnUpdate", nil)
	local overlay = icon.duiExpiredGlow
	if overlay then
		if overlay.animIn and overlay.animIn:IsPlaying() then
			overlay.animIn:Stop()
		end
		ReturnGlow(overlay)
		icon.duiExpiredGlow = nil
	end
end
