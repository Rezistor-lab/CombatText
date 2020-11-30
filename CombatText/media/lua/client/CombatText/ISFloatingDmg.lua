require "ISUI/ISUIElement"
require ("CombatTextBase.lua")
require ("CombatTextCache.lua")

ISFloatingDmg = ISUIElement:derive("ISFloatingDmg")

function ISFloatingDmg:initialize()
	ISUIElement.initialise(self);
end

function ISFloatingDmg:getScreenX(origin) return origin.x - getCameraOffX() - origin.offsetX end

function ISFloatingDmg:getScreenY(origin) return origin.y - getCameraOffY() - origin.offsetY - origin.startY end

function ISFloatingDmg:timeOffset() return (getTimeInMillis() - self.timestamp) / self.speed end

function ISFloatingDmg:render()
	if self.active then
		local zoom = getCore():getZoom(self.playerIndex)
		local x = self:getScreenX(self.originPos) / zoom
		local y = (self:getScreenY(self.originPos) - self:timeOffset()) / zoom
		local playerAlpha = CombatText.Fn.getAlpha(self.target, self.playerIndex)
		
		self:setX(x)
		self:setY(y)
		
		self:drawRect(-(self.textWidth/2)-1, -self.originPos.shiftY+2, self.textWidth+2, self.textHeight-2, self.bg.a*playerAlpha, self.bg.r, self.bg.g, self.bg.b) 
		self:drawText(self.text, -(self.textWidth/2), -self.originPos.shiftY, self.color.r, self.color.g, self.color.b, self.color.a*playerAlpha, self.font)
		
		--self:drawLine2(x-5, y-5, x+5, y+5, 1,1,1,1)
		--self:drawLine2(x-5, y+5, x+5, y-5, 1,1,1,1)
	end
end

function ISFloatingDmg:update()
	if self.timestamp + self.ttl < getTimeInMillis() then
		self.active = false;
		self:removeFromUIManager();
	end
end

function ISFloatingDmg:new(target, dmg, color, wasCrit, playerIndex)
	local font = CombatText.FloatingDamage.NormalFont
	if wasCrit then font = CombatText.FloatingDamage.CritFont end
	
	local originPos = {
		x = target:getScreenX(),
		y = target:getScreenY(),
		offsetX = target:getOffsetX(),
		offsetY = target:getOffsetY(),
		startY = CombatText.HealthBar.YOffset,
		shiftY = CombatText.Fn.fontHeight(font)
	}
	
	if CombatText.HealthBar.Visible then
		originPos.startY = originPos.startY + 2 + CombatText.HealthBar.Height;
	end
	if CombatText.CurrentTotalHp.Visible then
		originPos.shiftY = originPos.shiftY + 2 + CombatText.Fn.fontHeight(CombatText.CurrentTotalHp.Font);
	end

	zoom = getCore():getZoom(playerIndex);
	x = self:getScreenX(originPos) / zoom;
	y = self:getScreenY(originPos) / zoom;

	local o = {};
    o = ISPanel:new(x, y, 5, 5);
    setmetatable(o, self);
    self.__index = self;

	o.font = UIFont.FromString(font)
	o.originPos = originPos;
	o.target = target;
	o.timestamp = getTimeInMillis();
	o.ttl = CombatText.FloatingDamage.Ttl;
	o.speed = CombatText.FloatingDamage.Speed;
	o.text = dmg;
	o.color = color;
	o.bg = CombatText.FloatingDamage.Background;
	o.active = true;
	o.playerIndex = playerIndex;
	o.textWidth = CombatText.Fn.measureStringX(o.font, o.text)
	o.textHeight = CombatText.Fn.measureStringY(o.font, o.text)

    return o;
end