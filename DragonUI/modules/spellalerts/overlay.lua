local BASE_SIZE_SCALE = 0.8

local function GetLongSide()
	return 256 * BASE_SIZE_SCALE * DragonUISpellAlert_GetOverlayScale()
end

local function GetShortSide()
	return 128 * BASE_SIZE_SCALE * DragonUISpellAlert_GetOverlayScale()
end

function DragonUISpellActivationOverlay_OnLoad(self)
	self.overlaysInUse = {}
	self.unusedOverlays = {}

	DragonUISpellAlert_RegisterEvent("DRAGONUI_SPELL_ALERT_OVERLAY_SHOW", self, DragonUISpellActivationOverlay_OnEventOverlayShow)
	DragonUISpellAlert_RegisterEvent("DRAGONUI_SPELL_ALERT_OVERLAY_HIDE", self, DragonUISpellActivationOverlay_OnEventOverlayHide)

	local longSide = GetLongSide()
	self:SetSize(longSide, longSide)
	self:SetAlpha(DragonUISpellAlert_GetOverlayAlpha())
end

function DragonUISpellActivationOverlay_OnEventOverlayShow(self, spellID, texture, positions, scale, r, g, b)
	if DragonUISpellAlert_ShowOverlay() then
		DragonUISpellActivationOverlay_ShowAllOverlays(self, spellID, texture, positions, scale, r, g, b)
	end
end

function DragonUISpellActivationOverlay_OnEventOverlayHide(self, spellID)
	if spellID then
		DragonUISpellActivationOverlay_HideOverlays(self, spellID)
	else
		DragonUISpellActivationOverlay_HideAllOverlays(self)
	end
end

local complexLocationTable = {
	["RIGHT (FLIPPED)"] = {
		RIGHT = { hFlip = true },
	},
	["BOTTOM (FLIPPED)"] = {
		BOTTOM = { vFlip = true },
	},
	["LEFT + RIGHT (FLIPPED)"] = {
		LEFT = {},
		RIGHT = { hFlip = true },
	},
	["TOP + BOTTOM (FLIPPED)"] = {
		TOP = {},
		BOTTOM = { vFlip = true },
	},
}

function DragonUISpellActivationOverlay_ShowAllOverlays(self, spellID, texturePath, positions, scale, r, g, b)
	positions = strupper(positions)
	if complexLocationTable[positions] then
		for location, info in pairs(complexLocationTable[positions]) do
			DragonUISpellActivationOverlay_ShowOverlay(self, spellID, texturePath, location, scale, r, g, b, info.vFlip, info.hFlip)
		end
	else
		DragonUISpellActivationOverlay_ShowOverlay(self, spellID, texturePath, positions, scale, r, g, b, false, false)
	end
end

function DragonUISpellActivationOverlay_ShowOverlay(self, spellID, texturePath, position, scale, r, g, b, vFlip, hFlip)
	local overlay = DragonUISpellActivationOverlay_GetOverlay(self, spellID, position)
	overlay.spellID = spellID
	overlay.position = position

	overlay:ClearAllPoints()

	local texLeft, texRight, texTop, texBottom = 0, 1, 0, 1
	if vFlip then
		texTop, texBottom = 1, 0
	end
	if hFlip then
		texLeft, texRight = 1, 0
	end
	overlay.texture:SetTexCoord(texLeft, texRight, texTop, texBottom)

	local longSide = GetLongSide()
	local shortSide = GetShortSide()
	local gap = DragonUISpellAlert_GetOverlaySpacing()
	local width, height
	if position == "CENTER" then
		width, height = longSide, longSide
		overlay:SetPoint("CENTER", self, "CENTER", 0, 0)
	elseif position == "LEFT" then
		width, height = shortSide, longSide
		overlay:SetPoint("RIGHT", self, "LEFT", -gap, 0)
	elseif position == "RIGHT" then
		width, height = shortSide, longSide
		overlay:SetPoint("LEFT", self, "RIGHT", gap, 0)
	elseif position == "TOP" then
		width, height = longSide, shortSide
		overlay:SetPoint("BOTTOM", self, "TOP", 0, gap)
	elseif position == "BOTTOM" then
		width, height = longSide, shortSide
		overlay:SetPoint("TOP", self, "BOTTOM", 0, -gap)
	elseif position == "TOPRIGHT" then
		width, height = shortSide, shortSide
		overlay:SetPoint("BOTTOMLEFT", self, "TOPRIGHT", gap, gap)
	elseif position == "TOPLEFT" then
		width, height = shortSide, shortSide
		overlay:SetPoint("BOTTOMRIGHT", self, "TOPLEFT", -gap, gap)
	elseif position == "BOTTOMRIGHT" then
		width, height = shortSide, shortSide
		overlay:SetPoint("TOPLEFT", self, "BOTTOMRIGHT", gap, -gap)
	elseif position == "BOTTOMLEFT" then
		width, height = shortSide, shortSide
		overlay:SetPoint("TOPRIGHT", self, "BOTTOMLEFT", -gap, -gap)
	else
		return
	end

	overlay:SetSize(width * scale, height * scale)

	overlay.texture:SetTexture(texturePath)
	overlay.texture:SetVertexColor(r / 255, g / 255, b / 255)
	overlay.texture:Show()

	if overlay.animOut and overlay.animOut:IsPlaying() then
		overlay.animOut:Stop()
	end
	overlay:SetAlpha(1)
	overlay:Show()
end

function DragonUISpellActivationOverlay_GetOverlay(self, spellID, position)
	local overlayList = self.overlaysInUse[spellID]
	local overlay
	if overlayList then
		for i = 1, #overlayList do
			if overlayList[i].position == position then
				overlay = overlayList[i]
			end
		end
	end

	if not overlay then
		overlay = DragonUISpellActivationOverlay_GetUnusedOverlay(self)
		if overlayList then
			tinsert(overlayList, overlay)
		else
			self.overlaysInUse[spellID] = { overlay }
		end
	end

	return overlay
end

function DragonUISpellActivationOverlay_HideOverlays(self, spellID)
	local overlayList = self.overlaysInUse[spellID]
	if overlayList then
		for i = 1, #overlayList do
			local overlay = overlayList[i]
			overlay.pulse:Pause()
			overlay.animOut:Play()
		end
	end
end

function DragonUISpellActivationOverlay_HideAllOverlays(self)
	for spellID, overlayList in pairs(self.overlaysInUse) do
		DragonUISpellActivationOverlay_HideOverlays(self, spellID)
	end
end

function DragonUISpellActivationOverlay_GetUnusedOverlay(self)
	local overlay = tremove(self.unusedOverlays, #self.unusedOverlays)
	if not overlay then
		overlay = DragonUISpellActivationOverlay_CreateOverlay(self)
	end
	return overlay
end

function DragonUISpellActivationOverlay_CreateOverlay(self)
	return CreateFrame("Frame", nil, self, "DragonUISpellActivationOverlayTemplate")
end

function DragonUISpellActivationOverlayTexture_OnShow(self)
	-- Always become visible immediately. Fade-in animations are unreliable on some
	-- 3.3.5 clients and previously left overlays stuck at alpha 0.
	self:SetAlpha(1)
	if self.animIn then
		self.animIn:Stop()
	end
	if self.pulse then
		self.pulse:Play()
	end
end

function DragonUISpellActivationOverlayTexture_OnFadeInPlay(animGroup)
	-- no-op: visibility is handled in OnShow
end

function DragonUISpellActivationOverlayTexture_OnFadeInFinished(animGroup)
	local overlay = animGroup:GetParent()
	overlay:SetAlpha(1)
	if overlay.pulse and not overlay.pulse:IsPlaying() then
		overlay.pulse:Play()
	end
end

function DragonUISpellActivationOverlayTexture_OnFadeOutFinished(anim)
	DragonUISpellAlertAlphaTemplate_OnFinished(anim)
	local overlay = anim:GetRegionParent()
	local overlayParent = overlay:GetParent()
	overlay.pulse:Stop()
	overlay:Hide()
	tDeleteItem(overlayParent.overlaysInUse[overlay.spellID], overlay)
	tinsert(overlayParent.unusedOverlays, overlay)
end

function DragonUISpellActivationOverlay_ApplySettings()
	local frame = DragonUISpellActivationOverlayFrame
	if not frame then
		return
	end
	local longSide = GetLongSide()
	frame:SetSize(longSide, longSide)
	frame:SetAlpha(DragonUISpellAlert_GetOverlayAlpha())
end
