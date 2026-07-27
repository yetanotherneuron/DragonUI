-- Safe progress helper: some 3.3.5 builds lack GetSmoothProgress or error on it.
local function AnimProgress(self)
	if self.GetSmoothProgress then
		local ok, progress = pcall(self.GetSmoothProgress, self)
		if ok and type(progress) == "number" then
			return progress
		end
	end
	if self.GetProgress then
		local progress = self:GetProgress()
		if type(progress) == "number" then
			return progress
		end
	end
	return 0
end

local function InitAlphaAnimation(self)
	local target = self.target
	if type(target) == "string" then
		target = _G[target]
		self.target = target
	end
	if not target then
		target = self:GetRegionParent()
		self.target = target
	end
	if not target then
		return
	end
	local change = self.change
	if not change then
		change = 0
		self.change = change
	end
	local frameAlpha = target:GetAlpha()
	self.frameAlpha = frameAlpha
	self.alphaFactor = change
end

local function TidyAlphaAnimation(self)
	self.alphaFactor = nil
	self.frameAlpha = nil
end

function DragonUISpellAlertAlphaTemplate_OnUpdate(self, elapsed)
	local progress = AnimProgress(self)
	if progress ~= 0 then
		if not self.played then
			InitAlphaAnimation(self)
			self.played = 1
		end
		local frameAlpha = self.frameAlpha
		if frameAlpha and self.target then
			self.target:SetAlpha(frameAlpha + self.alphaFactor * progress)
			if progress == 1 then
				TidyAlphaAnimation(self)
			end
		end
	end
end

function DragonUISpellAlertAlphaTemplate_OnStop(self)
	if self.frameAlpha then
		TidyAlphaAnimation(self)
	end
	self.played = nil
end

DragonUISpellAlertAlphaTemplate_OnFinished = DragonUISpellAlertAlphaTemplate_OnStop

local function InitScaleAnimation(self)
	local target = self.target
	if type(target) == "string" then
		target = _G[target]
		self.target = target
	end
	if not target then
		target = self:GetRegionParent()
		self.target = target
	end
	if not target then
		return nil
	end
	local scaleX = self.scaleX
	if not scaleX then
		scaleX = 0
		self.scaleX = scaleX
	end
	local scaleY = self.scaleY
	if not scaleY then
		scaleY = 0
		self.scaleY = scaleY
	end
	local width, height = target:GetWidth(), target:GetHeight()
	if not width or width == 0 then
		return nil
	end
	self.frameWidth, self.frameHeight = width, height
	self.widthFactor, self.heightFactor = width * scaleX - width, height * scaleY - height
	local parent = target:GetParent()
	if not parent then
		return 1
	end
	local setCenter
	local numPoints = target:GetNumPoints()
	if 1 <= numPoints then
		local point, relativeTo, relativePoint, xOffset, yOffset = target:GetPoint(1)
		if numPoints == 1 and point == "CENTER" then
			setCenter = false
		else
			local i = 1
			while true do
				if relativeTo ~= parent and yOffset ~= nil then
					local k = #self + 1
					self[k], self[k + 1], self[k + 2], self[k + 3], self[k + 4] = point, relativeTo, relativePoint, xOffset, yOffset
				end
				i = i + 1
				if i <= numPoints then
					point, relativeTo, relativePoint, xOffset, yOffset = target:GetPoint(i)
				else
					break
				end
			end
			target:ClearAllPoints()
			setCenter = true
		end
	else
		setCenter = true
	end
	if setCenter then
		local x, y = target:GetCenter()
		local parentX, parentY = parent:GetCenter()
		if x and y and parentX and parentY then
			target:SetPoint("CENTER", x - parentX, y - parentY)
		else
			target:SetPoint("CENTER", parent, "CENTER", 0, 0)
		end
	end
	return 1
end

local function TidyScaleAnimation(self)
	local target = self.target
	if target and #self ~= 0 then
		target:ClearAllPoints()
		for i = 1, #self, 5 do
			target:SetPoint(self[i], self[i + 1], self[i + 2], self[i + 3], self[i + 4])
			self[i], self[i + 1], self[i + 2], self[i + 3], self[i + 4] = nil
		end
	end
	self.widthFactor, self.heightFactor = nil
	self.frameWidth, self.frameHeight = nil
end

function DragonUISpellAlertScaleTemplate_OnUpdate(self, elapsed)
	local progress = AnimProgress(self)
	if progress ~= 0 then
		if not self.played then
			if InitScaleAnimation(self) then
				self.played = 1
			end
		end
		local frameWidth = self.frameWidth
		if frameWidth and self.target then
			self.target:SetSize(frameWidth + self.widthFactor * progress, self.frameHeight + self.heightFactor * progress)
			if progress == 1 then
				TidyScaleAnimation(self)
			end
		end
	end
end

function DragonUISpellAlertScaleTemplate_OnStop(self)
	if self.frameWidth then
		TidyScaleAnimation(self)
	end
	self.played = nil
end

DragonUISpellAlertScaleTemplate_OnFinished = DragonUISpellAlertScaleTemplate_OnStop
