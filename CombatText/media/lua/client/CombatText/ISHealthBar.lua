require ("CombatTextBase.lua")
require ("CombatTextCache.lua")

ISHealthBar = ISUIElement:derive("ISHealthBar")

local core = getCore
local tm = getTextManager
local max = Math.max
local getCameraOffY = getCameraOffY
local tms = getTimeInMillis

function ISHealthBar:initialize()
	ISUIElement.initialise(self);
end

local function getScreenX(target, zoom)
	return (target:getScreenX() - getCameraOffX() - target:getOffsetX()) / zoom
end

local function getScreenY(target, zoom)
	return (target:getScreenY() - getCameraOffY() - target:getOffsetY() -CombatText.HealthBar.YOffset) / zoom
end

local function getScreenWidth(width, zoom)
	if zoom > 1 then 
		return width / (zoom*1.15);
	else
		return width
	end
end

local function getScreenHeight(height, zoom)
	if zoom > 1 then 
		return height / (zoom*1.15);
	else
		return height
	end
end

function ISHealthBar:getFontZoom(zoom)
	if zoom > 1.5 then 
		return 1 / (zoom-0.5);
	else
		return 1
	end
end

local function calculateLossStep(loss)
	if loss < 0.05 then return 0.03
	elseif loss < 0.15 then return 0.07
	elseif loss < 0.25 then return 0.15
	elseif loss < 0.4 then return 0.25
	else return 0.35 end
end

function ISHealthBar:render()
	if self.active and (self.visibleByPlayer or self.debug) then
		local zoom = core():getZoom(self.playerIndex)
		local width = getScreenWidth(self.cfgBar.Width, zoom)
		local height = getScreenHeight(self.cfgBar.Height, zoom)
		local minusWidthHalf = (-width/2)
		local widthPlusPadding = width+(self.padding*2)
		local heightPlusPadding = height+(self.padding*2)
		
		local x = getScreenX(self.target, zoom)
		local y = getScreenY(self.target, zoom)
		self:setX(x)
		self:setY(y)
		
		local playerAlpha = CombatText.Fn.getAlpha(self.target, self.playerIndex)
		local nowHpWidth = (self.currentHp / self.maxHp) * width
		
		local fontZoom = 0
		local txtWidth = 0
		local txtLeft = 0
		local txtTop = 0
		
		if self.cfgHpTotal.Visible then
			fontZoom = self:getFontZoom(zoom)
			txtWidth = self.hpTextWidth*fontZoom;
			txtLeft = -txtWidth/2
			txtTop = self.hpTextHeight*fontZoom;
		end

		if self.cfgBar.Visible then 
			self:drawRect(minusWidthHalf -self.padding, -self.padding, widthPlusPadding, heightPlusPadding, self.colors.Background.a*playerAlpha, self.colors.Background.r, self.colors.Background.g, self.colors.Background.b)
			self:drawRectBorder(minusWidthHalf -self.padding, -self.padding, widthPlusPadding, heightPlusPadding, self.colors.Border.a*playerAlpha, self.colors.Border.r, self.colors.Border.g, self.colors.Border.b)
			self:drawRect(minusWidthHalf, 0, nowHpWidth, height, self.colors.CurrentHealth.a*playerAlpha, self.colors.CurrentHealth.r, self.colors.CurrentHealth.g, self.colors.CurrentHealth.b)
			if self.isLoosingHp then
				local stampNow = tms();
				local frameDiff = self.maxHp * calculateLossStep(self.hpLoss) * ((stampNow - self.hpLossStart)/self.cfgBar.LoosingHpTick)
				self.hpLoss = max(0, self.hpLoss - frameDiff)
				self.hpLossStart = stampNow
				
				if self.hpLoss <= 0 then
					self:resetHpLoss()
				else
					self:drawRect(minusWidthHalf+nowHpWidth, 0, ((self.hpLoss / self.maxHp) * width), height, self.colors.LoosingHealth.a*playerAlpha, self.colors.LoosingHealth.r, self.colors.LoosingHealth.g, self.colors.LoosingHealth.b)
				end
			end
		end
		
		if self.cfgHpTotal.Visible then
			if self.cfgHpTotal.Position == "out-right" then
				txtLeft = (width/2)+self.padding+2;
				txtTop = -(txtTop/2)+self.padding
			elseif self.cfgHpTotal.Position == "out-left" then
				txtLeft = minusWidthHalf-txtWidth-self.padding-2;
				txtTop = -(txtTop/2)+self.padding
			elseif self.cfgHpTotal.Position == "out-bottom" then
				txtTop = height/2 + self.padding+2
			elseif self.cfgHpTotal.Position == "out-top-left" then
				txtTop = -txtTop-self.padding
				txtLeft = minusWidthHalf+self.padding;
			elseif self.cfgHpTotal.Position == "out-top-right" then
				txtTop = -txtTop-self.padding
				txtLeft = (width/2)-txtWidth-self.padding;
			elseif self.cfgHpTotal.Position == "out-bottom-left" then
				txtTop = height/2 + self.padding+2
				txtLeft = minusWidthHalf+self.padding;
			elseif self.cfgHpTotal.Position == "out-bottom-right" then
				txtTop = height/2 + self.padding+2
				txtLeft = (width/2)-txtWidth-self.padding;
			else
				txtTop = -txtTop -self.padding
			end
			
			self:drawTextZoomed(self.hpText, txtLeft, txtTop, fontZoom, self.cfgHpTotal.Color.r, self.cfgHpTotal.Color.g, self.cfgHpTotal.Color.b, self.cfgHpTotal.Color.a*playerAlpha, self.hpTextFont)
		end
		
		-- self:drawLine2(x-5, y-5, x+5, y+5, 1,1,1,1)
		-- self:drawLine2(x-5, y+5, x+5, y-5, 1,1,1,1)
		
	end
end

function ISHealthBar:update()
	if self.diedTimestamp ~= nil and self.hpLoss <= 0 and (self.diedTimestamp + self.cfgBar.FadeOutAfter < getTimeInMillis()) then 
		self:remove()
		return;
	end
	
	self.debug = getPlayer():isGodMod();
	self.visibleByPlayer = CombatText.Fn.getAlpha(self.target, self.playerIndex) > 0
end

function ISHealthBar:SetHp(hp)
	if self.isDead ~= true then
		if hp ~= self.currentHp then
			if hp < self.currentHp then		
				if self.isLoosingHp then
					self.hpLoss = self.hpLoss + (self.currentHp - max(0, hp));
				else
					self.hpLoss = self.currentHp - max(0, hp);
					self.hpLossStart = getTimeInMillis()
					self.isLoosingHp = true
				end
			else
				self.maxHp = hp;
			end
			self.currentHp = max(0, hp);
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
	self:removeFromUIManager();
end

function ISHealthBar:targetDead()
	self.diedTimestamp = getTimeInMillis()
	self:SetHp(0);
	self.isDead = true
end

function ISHealthBar:isValid(attacker, playerIndex)
	return playerIndex == self.playerIndex and CombatText.Fn.getEntityId(attacker) == self.UID and self.active == true;
end

function ISHealthBar:new(target, playerIndex)
	zoom = core():getZoom(playerIndex)
	cfgBar = CombatText.HealthBar
	
	width = getScreenWidth(cfgBar.Width, zoom)
	height = getScreenHeight(cfgBar.Height, zoom)
	x = getScreenX(target, zoom)
	y = getScreenY(target, zoom)

	local o = {};
    o = ISUIElement:new(x, y, width, height);
    setmetatable(o, self);
    self.__index = self;
	
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
	o.visibleByPlayer = CombatText.Fn.getAlpha(target, playerIndex) > 0;
	o.hpWidth = width;
	o.target = target;
	o.maxHp = target:getHealth();
	o.currentHp = o.maxHp
	o.minHp = 0;
	o.cfgHpTotal = CombatText.CurrentTotalHp;
	o.cfgBar = cfgBar;
	o.hpText = tostring(luautils.round(o.currentHp*100.0F,0))..'/'..tostring(luautils.round(o.maxHp*100.0F,0))
	o.hpTextFont = UIFont.FromString(CombatText.CurrentTotalHp.Font)
	o.hpFontHeight = tm():getFontHeight(o.hpTextFont)
	o.hpTextWidth = CombatText.Fn.measureStringX(o.hpTextFont, o.hpText);
	o.hpTextHeight = CombatText.Fn.measureStringY(o.hpTextFont, o.hpText);
	
			
    return o;
end