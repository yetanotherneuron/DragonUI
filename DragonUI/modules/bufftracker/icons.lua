local addon = select(2, ...)
if not addon then addon = _G.DragonUI end

local BT = DragonUIBuffTracker

local FRAME_TEXTURE = (addon._dir or "Interface\\AddOns\\DragonUI\\assets\\") .. "uiactionbariconframe.tga"
local BAR_REF = 37

local iconPool = {}
local activeIcons = {}

local function ResolveFrameOverhang(size)
	local scale = (size or BAR_REF) / BAR_REF
	if scale < 0.45 then scale = 0.45 end
	return 2.2 * scale, 2.3 * scale, -2.2 * scale, -2.2 * scale
end

local function DurationTextHeight(size)
	return math.max(9, math.floor((size or BAR_REF) * 0.26))
end

local function AnchorHost(host, button, size)
	local trX, trY, blX, blY = ResolveFrameOverhang(size)
	host:ClearAllPoints()
	host:SetPoint("TOPRIGHT", button, trX, trY)
	host:SetPoint("BOTTOMLEFT", button, blX, blY)
end

local function ApplyActionBarBorder(host)
	host.rounded:Show()
	if host.square then
		for _, tex in pairs(host.square) do
			tex:Hide()
		end
	end
	host.rounded:SetVertexColor(1, 1, 1, 1)
end

local function FormatDuration(seconds)
	if not seconds or seconds <= 0 then
		return ""
	end
	seconds = math.floor(seconds + 0.5)
	if seconds >= 3600 then
		return math.floor(seconds / 3600) .. "h"
	end
	if seconds >= 60 then
		return math.ceil(seconds / 60) .. "m"
	end
	return tostring(seconds)
end

local function ResetIconTint(icon)
	if not icon or not icon.icon then return end
	icon.icon:SetVertexColor(1, 1, 1, 1)
	if icon.icon.SetDesaturated then
		icon.icon:SetDesaturated(false)
	end
end

local function ClearIconCooldownState(icon)
	if not icon or not icon.cooldown then return end
	icon._cdStart = nil
	icon._cdDuration = nil
	if icon.cooldown.Clear then
		icon.cooldown:Clear()
	else
		icon.cooldown:SetCooldown(0, 0)
	end
	icon.cooldown:Hide()
end

local function ProtectCooldownSweep(cd)
	if not cd or cd._dui_sweepProtected then return end
	local origSetCooldown = cd.SetCooldown
	if not origSetCooldown then return end
	cd.SetCooldown = function(self, start, duration, ...)
		if self._dui_cdStart == start and self._dui_cdDur == duration then
			return
		end
		self._dui_cdStart = start
		self._dui_cdDur = duration
		return origSetCooldown(self, start, duration, ...)
	end
	cd._dui_sweepProtected = true
end

local function ApplySlotLayout(icon, size, durationBelow)
	local textH = DurationTextHeight(size)
	if durationBelow then
		icon:SetSize(size, size + textH)
		icon.icon:ClearAllPoints()
		icon.icon:SetPoint("TOPLEFT", icon, "TOPLEFT", 0, 0)
		icon.icon:SetPoint("TOPRIGHT", icon, "TOPRIGHT", 0, 0)
		icon.icon:SetHeight(size)

		icon.cooldown:ClearAllPoints()
		icon.cooldown:SetAllPoints(icon.icon)

		AnchorHost(icon.borderHost, icon.icon, size)

		icon.durationText:ClearAllPoints()
		icon.durationText:SetPoint("TOP", icon.icon, "BOTTOM", 0, -1)
		icon.durationText:SetPoint("LEFT", icon, "LEFT", -4, 0)
		icon.durationText:SetPoint("RIGHT", icon, "RIGHT", 4, 0)
		icon.durationText:SetWidth(0)
		icon.durationText:SetJustifyH("CENTER")
		icon.durationText:Show()

		icon.stackText:ClearAllPoints()
		icon.stackText:SetPoint("BOTTOMRIGHT", icon.icon, "BOTTOMRIGHT", -2, 2)
		icon.stackText:SetJustifyH("RIGHT")
	else
		icon:SetSize(size, size)
		icon.icon:SetAllPoints(icon)
		icon.cooldown:SetAllPoints(icon)
		AnchorHost(icon.borderHost, icon, size)

		icon.durationText:ClearAllPoints()
		icon.durationText:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", -1, 2)
		icon.durationText:SetJustifyH("RIGHT")
		icon.durationText:Hide()

		icon.stackText:ClearAllPoints()
		icon.stackText:SetPoint("BOTTOMLEFT", icon, "BOTTOMLEFT", 2, 2)
		icon.stackText:SetJustifyH("LEFT")
	end
	icon._durationBelow = durationBelow and true or false
end

local function ShowSpellTooltip(icon, spellID)
	if not spellID or spellID <= 0 then return end
	GameTooltip:SetOwner(icon, "ANCHOR_RIGHT")
	GameTooltip:SetHyperlink("spell:" .. spellID)
	GameTooltip:Show()
end

local function DisableChildMouse(frame)
	if frame and frame.EnableMouse then
		frame:EnableMouse(false)
	end
end

local function ConfigureIconMouseTargets(icon)
	DisableChildMouse(icon.cooldown)
	DisableChildMouse(icon.borderHost)
end

local function BindTooltip(icon, spellID, enabled)
	ConfigureIconMouseTargets(icon)
	if enabled then
		icon:EnableMouse(true)
		if icon.SetClipsChildren then
			icon:SetClipsChildren(false)
		end
		icon.spellID = spellID
		icon:SetScript("OnEnter", function(self)
			ShowSpellTooltip(self, self.spellID)
		end)
		icon:SetScript("OnLeave", function()
			GameTooltip:Hide()
		end)
	else
		icon:EnableMouse(false)
		icon.spellID = nil
		icon:SetScript("OnEnter", nil)
		icon:SetScript("OnLeave", nil)
	end
end

local function SyncIconGlow(icon, opts)
	if BT.StopActiveGlow then
		BT.StopActiveGlow(icon)
	end
	if not opts or not opts.glowEnabled or not opts.glowColor then
		return
	end
	if BT.PlayActiveGlow then
		BT.PlayActiveGlow(icon, opts.glowColor, opts.glowScale or 1.2, opts.glowAlpha or 1.0)
	end
end

local function AcquireIcon(parent)
	local icon = table.remove(iconPool)
	if not icon then
		local frame = CreateFrame("Frame", nil, parent)
		frame:SetSize(BAR_REF, BAR_REF)
		if frame.SetClipsChildren then
			frame:SetClipsChildren(false)
		end

		local tex = frame:CreateTexture(nil, "ARTWORK")
		tex:SetAllPoints(frame)
		tex:SetTexCoord(0.05, 0.95, 0.05, 0.95)
		frame.icon = tex

		local cd = CreateFrame("Cooldown", nil, frame, "CooldownFrameTemplate")
		cd:SetAllPoints(frame)
		cd:SetDrawEdge(false)
		cd:SetReverse(true)
		ProtectCooldownSweep(cd)
		frame.cooldown = cd

		local host = CreateFrame("Frame", nil, frame)
		host:SetFrameLevel(frame:GetFrameLevel() + 5)
		local rounded = host:CreateTexture(nil, "OVERLAY")
		rounded:SetAllPoints(host)
		rounded:SetTexture(FRAME_TEXTURE)
		host.rounded = rounded
		frame.borderHost = host

		local duration = frame:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
		duration:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -1, 2)
		duration:SetJustifyH("RIGHT")
		frame.durationText = duration

		local stacks = frame:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
		stacks:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 2, 2)
		stacks:SetJustifyH("LEFT")
		frame.stackText = stacks

		icon = frame
	end

	icon:SetParent(parent)
	icon:Show()
	activeIcons[icon] = true
	return icon
end

local function ReleaseIcon(icon)
	if not icon then return end
	activeIcons[icon] = nil
	icon:Hide()
	icon:ClearAllPoints()
	icon:SetScript("OnUpdate", nil)
	icon:EnableMouse(false)
	icon:SetScript("OnEnter", nil)
	icon:SetScript("OnLeave", nil)
	icon.durationText:SetText("")
	icon.durationText:Hide()
	icon.stackText:SetText("")
	ResetIconTint(icon)
	ClearIconCooldownState(icon)
	if BT.StopExpiredGlow then
		BT.StopExpiredGlow(icon)
	end
	if BT.StopActiveGlow then
		BT.StopActiveGlow(icon)
	end
	table.insert(iconPool, icon)
end

function BT.ReleaseAllIcons()
	for icon in pairs(activeIcons) do
		ReleaseIcon(icon)
	end
end

function BT.GetDurationTextHeight(size)
	return DurationTextHeight(size)
end

-- Returns false when the entry timer has expired and the icon should be removed.
function BT.UpdateIconFrame(icon, opts)
	if not icon then return false end

	local size = opts.size or BAR_REF
	local showDuration = opts.showDuration == true
	local hasTimer = showDuration and opts.expiration and opts.expiration > 0
	local remain = 0
	local duration = opts.duration

	if hasTimer then
		remain = opts.expiration - GetTime()
		if remain <= 0 then
			return false
		end
		if not duration or duration <= 0 then
			duration = remain
		end
	end

	local durationBelow = hasTimer and remain > 0
	if icon._durationBelow ~= durationBelow or icon._slotSize ~= size then
		ApplySlotLayout(icon, size, durationBelow)
		icon._slotSize = size
	end

	if opts.texture then
		icon.icon:SetTexture(opts.texture)
	end

	local host = icon.borderHost
	if durationBelow then
		AnchorHost(host, icon.icon, size)
	else
		AnchorHost(host, icon, size)
	end
	ApplyActionBarBorder(host)

	if durationBelow then
		icon.durationText:SetText(FormatDuration(remain))
		icon.durationText:Show()
		local start = opts.expiration - duration
		if icon._cdStart ~= start or icon._cdDuration ~= duration then
			icon.cooldown:SetCooldown(start, duration)
			icon._cdStart = start
			icon._cdDuration = duration
		end
		icon.cooldown:Show()
		if opts.icdOnly and icon.icon.SetDesaturated then
			icon.icon:SetDesaturated(true)
			icon.icon:SetVertexColor(0.65, 0.65, 0.65, 1)
		else
			ResetIconTint(icon)
		end
	else
		icon.durationText:SetText("")
		icon.durationText:Hide()
		ClearIconCooldownState(icon)
		ResetIconTint(icon)
	end

	local count = opts.count or 0
	if opts.showStacks and count > 0 then
		if opts.forceStacks or count > 1 then
			icon.stackText:SetText(tostring(count))
		else
			icon.stackText:SetText("")
		end
	else
		icon.stackText:SetText("")
	end

	BindTooltip(icon, opts.tooltipID or opts.spellID, opts.showTooltip == true)
	SyncIconGlow(icon, opts)
	return true
end

function BT.CreateOrUpdateIcon(parent, key, opts)
	local existing = opts.existing
	local icon = existing or AcquireIcon(parent)
	if not BT.UpdateIconFrame(icon, opts) then
		BT.ReleaseIcon(icon)
		return nil
	end
	icon.trackerKey = key
	return icon
end

function BT.ReleaseIcon(icon)
	ReleaseIcon(icon)
end

function BT.ClearIconCooldownState(icon)
	ClearIconCooldownState(icon)
end
