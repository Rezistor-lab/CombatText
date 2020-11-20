require ("CombatTextBase.lua")
require ("CombatTextCache.lua")

ISHealthBar = ISPanel:derive("ISHealthBar")

function ISHealthBar:initialize()
	ISPanel.initialise(self);
end

function ISHealthBar:getScreenX(target, zoom)
	return (target:getScreenX() - getCameraOffX() - target:getOffsetX()) / zoom
end

function ISHealthBar:getScreenY(target, zoom)
	return (target:getScreenY() - getCameraOffY() - target:getOffsetY() -CombatText.HealthBar.YOffset) / zoom
end

function ISHealthBar:getScreenWidth(zoom)
	if zoom > 1 then 
		return CombatText.HealthBar.Width / (zoom*1.15);
	else
		return CombatText.HealthBar.Width
	end
end

function ISHealthBar:getScreenHeight(zoom)
	if zoom > 1 then 
		return CombatText.HealthBar.Height / (zoom*1.15);
	else
		return CombatText.HealthBar.Height
	end
end

function calculateLossStep(loss)
	if loss < 0.05 then return 0.03
	elseif loss < 0.15 then return 0.07
	elseif loss < 0.25 then return 0.15
	elseif loss < 0.4 then return 0.25
	else return 0.35 end
end

function ISHealthBar:render()
	if self.active and (self.visibleByPlayer or self.debug) then
		zoom = getCore():getZoom(self.playerIndex)
		width = self:getScreenWidth(zoom)
		height = self:getScreenHeight(zoom)
		
		fontZoom = zoom--????
		
		x = self:getScreenX(self.target, zoom)
		y = self:getScreenY(self.target, zoom)
		self:setX(x)
		self:setY(y)
		self:setWidth(width)
		self:setHeight(height)
		
		nowHpWidth = (self.currentHp / self.maxHp) * width
		
		currentTotalHpHeightOffset = -CombatText.FontHeights.Small-2
		if CombatText.HealthBar.Visible then 
			currentTotalHpHeightOffset = currentTotalHpHeightOffset -(height/2)
		end
		
		if CombatText.CurrentTotalHp.Visible then
			self:drawTextZoomed(self.hpText, -((CombatText.Fn.measureStringX(UIFont.Small, self.hpText)*fontZoom)/2), currentTotalHpHeightOffset, 1/fontZoom, CombatText.CurrentTotalHp.Color.r, CombatText.CurrentTotalHp.Color.g, CombatText.CurrentTotalHp.Color.b, CombatText.CurrentTotalHp.Color.a, UIFont.Small)
		end
		
		if CombatText.HealthBar.Visible then 
			self:drawRect((-width/2) -self.padding, -self.padding, width+(self.padding*2), height+(self.padding*2), self.colors.Background.a, self.colors.Background.r, self.colors.Background.g, self.colors.Background.b)
			self:drawRectBorder((-width/2) -self.padding, -self.padding, width+(self.padding*2), height+(self.padding*2), self.colors.Border.a, self.colors.Border.r, self.colors.Border.g, self.colors.Border.b)
			self:drawRect((-width/2), 0, nowHpWidth, height, self.colors.CurrentHealth.a, self.colors.CurrentHealth.r, self.colors.CurrentHealth.g, self.colors.CurrentHealth.b)
			if self.isLoosingHp then
				stampNow = getTimeInMillis();
				frameDiff = self.maxHp * calculateLossStep(self.hpLoss) * ((stampNow - self.hpLossStart)/CombatText.HealthBar.LoosingHpTick)
				self.hpLoss = Math.max(0, self.hpLoss - frameDiff)
				self.hpLossStart = stampNow
				
				if self.hpLoss <= 0 then
					self:resetHpLoss()
				else
					loosingHpWidth = ((self.hpLoss / self.maxHp) * width)
					self:drawRect((-width/2)+nowHpWidth, 0, loosingHpWidth, height, self.colors.LoosingHealth.a, self.colors.LoosingHealth.r, self.colors.LoosingHealth.g, self.colors.LoosingHealth.b)
				end
			end
		end
	end
end

function ISHealthBar:update()
	if self.diedTimestamp ~= nil and self.hpLoss <= 0 and (self.diedTimestamp + CombatText.HealthBar.FadeOutAfter < getTimeInMillis()) then 
		self:remove()
		return;
	end
	
	self.debug = getPlayer():isGodMod();
	self.visibleByPlayer = self.target:getTargetAlpha() > 0
end

function ISHealthBar:SetHp(hp)
	if self.isDead ~= true then
		if hp ~= self.currentHp then
			if hp < self.currentHp then		
				if self.isLoosingHp then
					self.hpLoss = self.hpLoss + (self.currentHp - Math.max(0, hp));
				else
					self.hpLoss = self.currentHp - Math.max(0, hp);
					self.hpLossStart = getTimeInMillis()
					self.isLoosingHp = true
				end
			else
				self.maxHp = hp;
			end
			self.currentHp = Math.max(0, hp);
			self.hpText = tostring(luautils.round(self.currentHp*100.0F,0))..'/'..tostring(luautils.round(self.maxHp*100.0F,0))
		end
	end
end

function ISHealthBar:resetHpLoss()
	self.hpLoss = 0
	self.isLoosingHp = false
end

function ISHealthBar:remove()
	-- stop rendering
	self.active = false; 
	-- parent calls to remove element
	self:close();
	self:removeFromUIManager();
end

function ISHealthBar:targetDead()
	self.diedTimestamp = getTimeInMillis()
	self:SetHp(0);
	self.isDead = true
end

function ISHealthBar:isValid(attacker, playerIndex)
	return playerIndex == self.playerIndex and target:getUID() == self.UID and self.active == true;
end

function ISHealthBar:new(target, playerIndex)
	zoom = getCore():getZoom(playerIndex)
	width = self:getScreenWidth(zoom)
	height = self:getScreenHeight(zoom)
	x = self:getScreenX(target, zoom)
	y = self:getScreenY(target, zoom)

	local o = {};
    o = ISPanel:new(x, y, width, height);
    setmetatable(o, self);
    self.__index = self;
	
	-- we will create custom background
	o:noBackground();
	
	-- essentials
	o.playerIndex = playerIndex;
	o.active = true;
	o.UID = target:getUID();
	o.debug = getPlayer():isGodMod()
	
	-- local copy
	o.padding = CombatText.HealthBar.Padding;
	o.colors = CombatText.HealthBar.Colors;
	
	-- defaults
	
	o.hpLoss = 0;
	o.visibleByPlayer = target:isTargetVisible();
	o.hpWidth = width;
	o.target = target;
	o.maxHp = target:getHealth();
	o.currentHp = o.maxHp
	o.minHp = 0;
	o.hpText = tostring(luautils.round(o.currentHp*100.0F,0))..'/'..tostring(luautils.round(o.maxHp*100.0F,0))
	
    return o;
end