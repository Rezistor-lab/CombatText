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

function ISHealthBar:getFontZoom(zoom)
	if zoom > 1.5 then 
		return 1 / (zoom-0.5);
	else
		return 1
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
		minusWidthHalf = (-width/2)
		widthPlusPadding = width+(self.padding*2)
		heightPlusPadding = height+(self.padding*2)
		
		x = self:getScreenX(self.target, zoom)
		y = self:getScreenY(self.target, zoom)
		self:setX(x)
		self:setY(y)
		
		nowHpWidth = (self.currentHp / self.maxHp) * width
		
		if CombatText.CurrentTotalHp.Visible then
			fontZoom = self:getFontZoom(zoom)
			txtWidth = self.hpTextWidth*fontZoom;
			txtLeft = -txtWidth/2
			txtTop = self.hpTextHeight*fontZoom;
		end

		if CombatText.HealthBar.Visible then 
			self:drawRect(minusWidthHalf -self.padding, -self.padding, widthPlusPadding, heightPlusPadding, self.colors.Background.a, self.colors.Background.r, self.colors.Background.g, self.colors.Background.b)
			self:drawRectBorder(minusWidthHalf -self.padding, -self.padding, widthPlusPadding, heightPlusPadding, self.colors.Border.a, self.colors.Border.r, self.colors.Border.g, self.colors.Border.b)
			self:drawRect(minusWidthHalf, 0, nowHpWidth, height, self.colors.CurrentHealth.a, self.colors.CurrentHealth.r, self.colors.CurrentHealth.g, self.colors.CurrentHealth.b)
			if self.isLoosingHp then
				stampNow = getTimeInMillis();
				frameDiff = self.maxHp * calculateLossStep(self.hpLoss) * ((stampNow - self.hpLossStart)/CombatText.HealthBar.LoosingHpTick)
				self.hpLoss = Math.max(0, self.hpLoss - frameDiff)
				self.hpLossStart = stampNow
				
				if self.hpLoss <= 0 then
					self:resetHpLoss()
				else
					loosingHpWidth = ((self.hpLoss / self.maxHp) * width)
					self:drawRect(minusWidthHalf+nowHpWidth, 0, loosingHpWidth, height, self.colors.LoosingHealth.a, self.colors.LoosingHealth.r, self.colors.LoosingHealth.g, self.colors.LoosingHealth.b)
				end
			end
		end
		
		if CombatText.CurrentTotalHp.Visible then
			if CombatText.CurrentTotalHp.Position == "out-right" then
				txtLeft = (width/2)+self.padding+2;
				txtTop = -(txtTop/2)+self.padding
			elseif CombatText.CurrentTotalHp.Position == "out-left" then
				txtLeft = minusWidthHalf-txtWidth-self.padding-2;
				txtTop = -(txtTop/2)+self.padding
			elseif CombatText.CurrentTotalHp.Position == "out-bottom" then
				txtTop = height/2 + self.padding+2
			elseif CombatText.CurrentTotalHp.Position == "out-top-left" then
				txtTop = -txtTop-self.padding
				txtLeft = minusWidthHalf+self.padding;
			elseif CombatText.CurrentTotalHp.Position == "out-top-right" then
				txtTop = -txtTop-self.padding
				txtLeft = (width/2)-txtWidth-self.padding;
			elseif CombatText.CurrentTotalHp.Position == "out-bottom-left" then
				txtTop = height/2 + self.padding+2
				txtLeft = minusWidthHalf+self.padding;
			elseif CombatText.CurrentTotalHp.Position == "out-bottom-right" then
				txtTop = height/2 + self.padding+2
				txtLeft = (width/2)-txtWidth-self.padding;
			else
				txtTop = -txtTop -self.padding
			end
			
			self:drawTextZoomed(self.hpText, txtLeft, txtTop, fontZoom, CombatText.CurrentTotalHp.Color.r, CombatText.CurrentTotalHp.Color.g, CombatText.CurrentTotalHp.Color.b, CombatText.CurrentTotalHp.Color.a, self.hpTextFont)
		end
		
		-- self:drawLine2(x-5, y-5, x+5, y+5, 1,1,1,1)
		-- self:drawLine2(x-5, y+5, x+5, y-5, 1,1,1,1)
		
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
			self.hpTextWidth = CombatText.Fn.measureStringX(self.hpTextFont, self.hpText);
			self.hpTextHeight = CombatText.Fn.measureStringY(self.hpTextFont, self.hpText)
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
	return playerIndex == self.playerIndex and CombatText.Fn.getEntityId(target) == self.UID and self.active == true;
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
	o.UID = CombatText.Fn.getEntityId(target);
	o.debug = getPlayer():isGodMod()
	
	-- local copy
	o.padding = CombatText.HealthBar.Padding;
	o.colors = CombatText.HealthBar.Colors;
	
	-- defaults
	
	o.hpLoss = 0;
	o.visibleByPlayer = CombatText.Fn.getTargetAlpha(target, playerIndex) > 0;
	o.hpWidth = width;
	o.target = target;
	o.maxHp = target:getHealth();
	o.currentHp = o.maxHp
	o.minHp = 0;
	o.hpText = tostring(luautils.round(o.currentHp*100.0F,0))..'/'..tostring(luautils.round(o.maxHp*100.0F,0))
	o.hpTextFont = UIFont.FromString(CombatText.CurrentTotalHp.Font)
	o.hpFontHeight = CombatText.FontHeights[CombatText.CurrentTotalHp.Font]
	o.hpTextWidth = CombatText.Fn.measureStringX(o.hpTextFont, o.hpText);
	o.hpTextHeight = CombatText.Fn.measureStringY(o.hpTextFont, o.hpText)
			
    return o;
end