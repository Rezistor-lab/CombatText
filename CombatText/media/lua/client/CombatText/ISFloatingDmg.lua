require "ISUI/ISUIElement"
require ("CombatTextBase.lua")
require ("CombatTextCache.lua")

ISFloatingDmg = ISUIElement:derive("ISFloatingDmg")

function ISFloatingDmg:initialize()
	ISUIElement.initialise(self);
end

function ISFloatingDmg:getScreenX(origin) return origin.x - getCameraOffX() - origin.offsetX end

function ISFloatingDmg:getScreenY(origin) return origin.y - getCameraOffY() - origin.offsetY - originPos.startY end

function ISFloatingDmg:timeOffset() return (getTimeInMillis() - self.timestamp) / self.speed end

function ISFloatingDmg:render()
	if self.active then
		zoom = getCore():getZoom(self.playerIndex)
		
		x = self:getScreenX(self.originPos) / zoom
		y = (self:getScreenY(self.originPos) - self:timeOffset()) / zoom
		
		self:setX(x)
		self:setY(y)
		
		self:drawTextCentre(self.text, 0, -self.originPos.shiftY, self.color.r, self.color.g, self.color.b, self.color.a, self.font)
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
	originPos = {
		x = target:getScreenX(),
		y = target:getScreenY(),
		offsetX = target:getOffsetX(),
		offsetY = target:getOffsetY(),
		startY = CombatText.HealthBar.YOffset,
		shiftY = CombatText.FontHeights.Medium
	}
	if wasCrit then originPos.shiftY = CombatText.FontHeights.Large end
	
	if CombatText.HealthBar.Visible then
		originPos.startY = originPos.startY + 2 + CombatText.HealthBar.Height;
	end
	if CombatText.CurrentTotalHp.Visible then
		originPos.shiftY = originPos.shiftY + 2 + CombatText.FontHeights.Small;
	end

	zoom = getCore():getZoom(playerIndex);
	x = self:getScreenX(originPos) / zoom;
	y = self:getScreenY(originPos) / zoom;

	local o = {};
    o = ISPanel:new(x, y, 5, 5);
    setmetatable(o, self);
    self.__index = self;

	o.font = UIFont.Medium
	if wasCrit then o.font = UIFont.Large end
	o.originPos = originPos;
	o.timestamp = getTimeInMillis();
	o.ttl = CombatText.FloatingDamage.Ttl;
	o.speed = CombatText.FloatingDamage.Speed;
	o.text = dmg;
	o.color = color;
	o.active = true;
	o.playerIndex = playerIndex;

    return o;
end