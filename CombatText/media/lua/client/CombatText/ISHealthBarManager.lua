require ("CombatTextBase.lua")
require ("CombatTextCache.lua")
require ("luautils.lua")

ISHealthBarManager = ISUIElement:derive("ISHealthBarManager")

--************************************************************************--
--** functions and utils local copy
--************************************************************************--

local getGameTime = getGameTime;
local tms = getTimeInMillis;
local core = getCore
local tm = getTextManager
local tostring = tostring;
local isoToScreenX = isoToScreenX
local isoToScreenY = isoToScreenY
local getPlayerScreenLeft = getPlayerScreenLeft
local getPlayerScreenTop = getPlayerScreenTop
local getPlayerScreenWidth = getPlayerScreenWidth
local getPlayerScreenHeight = getPlayerScreenHeight
local getNumActivePlayers = getNumActivePlayers

local utils = {
	-- get in-game timestamp in miliseconds
	getGameTimestamp = function() return getGameTime():getCalender():getTimeInMillis() end,
	getSystemTimestamp = getTimestampMs,
	max = function(left, right) if left > right then return left else return right end end,
	min = function(left, right) if left < right then return left else return right end end,
	abs = function(val) if val < 0 then return val*(-1) else return val end end,
	
	-- calculate distance between 2 points without math lib
	distanceTo = function(x1,y1,x2,y2) return (((x2 - x1)*(x2 - x1)) + ((y2 - y1)*(y2 - y1)))^0.5F end,
	getBarWidth = function(width, zoom) if zoom > 1 then return width / (zoom*1.15) else return width end end,
	getBarHeight = function(height, zoom) if zoom > 1 then return height / (zoom*1.15) else return height end end,
	getFontZoom = function(zoom) if zoom > 1.5 then return 1 / (zoom-0.5) else return 1 end end,
	round = luautils.round,
	getAlpha = CombatText.Fn.getAlpha
};

--- get string representation of damage
utils.damageDiff = function(currentHp, previousHp)
	local delta = (currentHp - previousHp)*100.0F
	local diff = ""
	
	if utils.abs(delta) < 5 then
		diff = tostring(utils.round(delta,2))
	elseif utils.abs(delta) < 10 then
		diff = tostring(utils.round(delta,1))
	else
		diff = tostring(utils.round(delta,0))
	end
	
	if currentHp > previousHp then 
		return "+"..diff 
	else
		return diff
	end
end

--- select correct color for health change
utils.getDamageColor = function(currentHp, previousHp, isOnFire, isCrit)
	if isOnFire then
		return CombatText.FloatingDamage.RgbOnFire
	end
	
	if currentHp > previousHp then -- heal 
		return CombatText.FloatingDamage.RgbPlus
	else
		return CombatText.FloatingDamage.RgbMinus
	end
end

utils.playerColor = function(playerIndex)
	if playerIndex == 0 then return {r=0,g=1,b=1} end
	if playerIndex == 1 then return {r=1,g=1,b=0} end
	if playerIndex == 2 then return {r=1,g=1,b=1} end
	return {r=1,g=0,b=1}
end

utils.calculateLossStep = function(loss)
	if loss <= 0.05 then return 0.03 end
	if loss <= 0.15 then return 0.07 end
	if loss <= 0.25 then return 0.15 end
	if loss <= 0.4 then return 0.25 end
	return utils.min(0.35, loss)
end

utils.countDamages = function(_self)
	local total = 0;
	local active = 0;
	for uid,itm in pairs(_self.dmgList) do
		total = total+itm.count;
		active = active+itm.active
	end
	return total, active;
end

utils.countBars = function(_self)
	local total = 0;
	for uid,itm in pairs(_self.barList) do
		total = total+1;
	end
	return total, active;
end

--************************************************************************--
--** debug render functions
--************************************************************************--

local debugRender = {};

debugRender.trackingData = function(_self, startX, startY, tk, tv, gameTick)
	_self:drawText('========================================', startX, startY, _self.color.r, _self.color.g, _self.color.b, 1, _self.hpTextFont)
	startY = startY + _self.hpFontHeight+2
	_self:drawText('ID:'..tk, startX, startY, _self.color.r, _self.color.g, _self.color.b, 1, _self.hpTextFont)
	startY = startY + _self.hpFontHeight+2
	
	local zx = tv.entity:getX();
	local zy = tv.entity:getY();
	local zz = tv.entity:getZ();
	local zIsoX = isoToScreenX(_self.playerIndex, zx, zy, zz)-_self.renderData.xWithOffset
	local zIsoY = isoToScreenY(_self.playerIndex, zx, zy, zz)-_self.renderData.offsetY;
	
	_self:drawText('iso X:'..tostring(round(zx,2))..' Y:'..tostring(round(zy,2))..' Z:'..tostring(round(zz,2))..' | screen X:'..tostring(round(zIsoX, 2))..' Y:'..tostring(round(zIsoY,2))..' | inactivity remove after:'..tostring(utils.max(0, ((tv.tick+CombatText.HealthBar.HideWhenInactive.noDamageFor)-gameTick))), startX, startY, _self.color.r, _self.color.g, _self.color.b, 1, _self.hpTextFont)
	startY = startY + _self.hpFontHeight+2;
	
	return startX, startY;
end

debugRender.healthBar = function(_self, startX, startY, bv, gameTick)
	local zx = bv.entity:getX();
	local zy = bv.entity:getY();
	local zz = bv.entity:getZ();
	local zIsoX = isoToScreenX(_self.playerIndex, zx, zy, zz)-_self.renderData.xWithOffset
	local zIsoY = isoToScreenY(_self.playerIndex, zx, zy, zz)-_self.renderData.yWithOffset
	
	local px = _self.player:getX();
	local py = _self.player:getY();
	local pz = _self.player:getZ();
	local pIsoX = isoToScreenX(_self.playerIndex, px, py, pz)-_self.renderData.xWithOffset
	local pIsoY = isoToScreenY(_self.playerIndex, px, py, pz)-_self.renderData.yWithOffset
	
	local dist = utils.distanceTo(zx,zy,px,py)
	
	_self:drawRect(zIsoX-2,zIsoY-2, 4, 4, 0.5F, _self.color.r, _self.color.g, _self.color.b);
	_self:drawTextCentre('dist:'..tostring(utils.round(dist,2)), zIsoX-2,zIsoY-2, _self.color.r, _self.color.g, _self.color.b, 1, UIFont.Small);
	_self:drawLine2(zIsoX, zIsoY, pIsoX, pIsoY, 1, _self.color.r, _self.color.g, _self.color.b)
	
	_self:drawText('health bar:'..tostring(round(bv.maxHp*100, 0))..'/'..tostring(utils.round(bv.currentHp*100,0))..' lossing health:'..tostring(bv.isLoosingHp)..' health loss:'..tostring(utils.round(bv.hpLoss, 2))..' isDead:'..tostring(bv.isDead)..' dist:'..tostring(utils.round(dist,2))..' toRemove:'..tostring(dist > CombatText.HealthBar.HideWhenInactive.distanceMoreThan), startX, startY, _self.color.r, _self.color.g, _self.color.b, 1, _self.hpTextFont)
	startY = startY + _self.hpFontHeight+2;
	
	return startX, startY;
end

debugRender.base = function(_self, startX, startY)
	local px = _self.player:getX();
	local py = _self.player:getY();
	local pz = _self.player:getZ();
	local isoX = isoToScreenX(_self.playerIndex, px, py, pz)-_self.renderData.xWithOffset
	local isoY = isoToScreenY(_self.playerIndex, px, py, pz)-_self.y
	local dmgTotal, dmgActive = utils.countDamages(_self);
	local barsTotal = utils.countBars(_self);
	
	_self:drawRect(isoX-2,isoY-2, 4, 4, 0.5F, _self.color.r, _self.color.g, _self.color.b);

	_self:drawText('Player ID:'..tostring(_self.playerIndex), startX, startY, _self.color.r, _self.color.g, _self.color.b, 1, _self.hpTextFont)
	startY = startY + _self.hpFontHeight+2;
	_self:drawText('iso X:'..tostring(utils.round(px,2))..' Y:'..tostring(utils.round(py,2))..' Z:'..tostring(utils.round(pz,2))..'| screen X:'..tostring(utils.round(isoX, 2))..' Y:'..tostring(round(isoY,2)), startX, startY, _self.color.r, _self.color.g, _self.color.b, 1, _self.hpTextFont)
	startY = startY + _self.hpFontHeight+2;
	_self:drawText('Tracking items:'..tostring(CombatTextCache.TrackingListCount)..' | dmg total:'..tostring(dmgTotal)..' | dmg active:'..tostring(dmgActive)..' | bars:'..tostring(barsTotal), startX, startY, _self.color.r, _self.color.g, _self.color.b, 1, _self.hpTextFont)
	startY = startY + _self.hpFontHeight+2;
	--16.6ms => 60fps
	--33.3ms => 30fps
	_self:drawText('Render time:'..tostring(_self.renderTime)..'ms/idle:'..tostring(_self.renderIdleTime)..'ms | Update time:'..tostring(_self.updateTime)..'ms', startX, startY, _self.color.r, _self.color.g, _self.color.b, 1, _self.hpTextFont)
	startY = startY + _self.hpFontHeight+2;
	
	return startX, startY;
end

debugRender.damage = function(_self, startX, startY, damages, tick)
	_self:drawText('Floating items:'..tostring(damages.count), startX, startY, _self.color.r, _self.color.g, _self.color.b, 1, _self.hpTextFont)
	startY = startY + _self.hpFontHeight+2;	

	for i=0,damages.count-1,1 do
		local itm = damages.items[i];
		if itm.expired == false then
			local timeOffset = (tick-itm.timestamp)/CombatText.FloatingDamage.Speed;
			local zIsoX = isoToScreenX(_self.playerIndex, itm.zx, itm.zy, itm.zz)
			local zIsoY = isoToScreenY(_self.playerIndex, itm.zx, itm.zy, itm.zz)-_self.renderData.offsetY-itm.shiftY-timeOffset+itm.textHeight;
			_self:drawRect(zIsoX-2,zIsoY-2, 4, 4, 0.5F, _self.color.r, _self.color.g, _self.color.b);
		end
	end
	
	return startX, startY;
end

debugRender.border = function(_self)
	local areaOff = 2
	_self:drawRectBorder(areaOff,areaOff, _self.renderWidth-areaOff*2, _self.renderHeight-areaOff*2, 1, _self.color.r, _self.color.g, _self.color.b)
end

debugRender.playerLink = function(_self, startX, startY)
	local px = _self.player:getX();
	local py = _self.player:getY();
	local pz = _self.player:getZ();
	local pIsoX = isoToScreenX(_self.playerIndex, px, py, pz);
	local pIsoY = isoToScreenY(_self.playerIndex, px, py, pz);

	for i=0, _self.players-1, 1 do
		if i ~= _self.playerIndex then
			local other = getSpecificPlayer(i)
			local zx = other:getX();
			local zy = other:getY();
			local zz = other:getZ();
			local zIsoX = isoToScreenX(_self.playerIndex, zx, zy, zz);
			local zIsoY = isoToScreenY(_self.playerIndex, zx, zy, zz);
			
			local dist = utils.distanceTo(px, py, zx, zy);
			_self:drawText('P'..tostring(i)..' dist:'..tostring(utils.round(dist,2)), startX, startY, _self.color.r, _self.color.g, _self.color.b, 1, _self.hpTextFont)
			startY = startY + _self.hpFontHeight+2

			_self:drawLine2(zIsoX, zIsoY, pIsoX, pIsoY, 1, _self.color.r, _self.color.g, _self.color.b)
		end
	end
	
	return startX, startY;
end

--************************************************************************--
--** local data manipulation functions
--************************************************************************--

local function updateHealthBarHp(item, hp)
	if item.isDead ~= true then
		if hp ~= item.currentHp then
			if hp < item.currentHp then		
				if item.isLoosingHp then
					item.hpLoss = item.hpLoss + (item.currentHp - utils.max(0, hp));
				else
					item.hpLoss = item.currentHp - utils.max(0, hp);
					item.hpLossStart = tms()
					item.isLoosingHp = true
				end
			else
				item.maxHp = hp;
			end
			item.currentHp = utils.max(0, hp);
			item.hpText = tostring(utils.round(item.currentHp*100.0F,0))..'/'..tostring(utils.round(item.maxHp*100.0F,0))
			item.hpTextWidth = CombatText.Fn.measureStringX(item.hpTextFont, item.hpText);
			item.hpTextHeight = CombatText.Fn.measureStringY(item.hpTextFont, item.hpText)
		end
	end
end

local function setTargetDead(itm)
	itm.diedTimestamp = tms()
	updateHealthBarHp(itm, 0);
	itm.isDead = true
end

local function removeAll(_self, uid, isDead)
	local db = CombatTextCache.TrackingList;

	if CombatTextCache.TrackingList[uid] ~= nil then
		CombatTextCache.TrackingList[uid] = nil;
		CombatTextCache.TrackingListCount = CombatTextCache.TrackingListCount-1;
	end
	if _self.barList[uid] ~= nil then
		if isDead then
			setTargetDead(_self.barList[uid]);
		else
			_self.barList[uid] = nil;
		end
	end
end

local function addBar(_self, uid, entity, weapon, isCrit)
	local hp = entity:getHealth();
	
	_self.barList[uid] = {
		hpLoss = 0, currentHp = hp, entity = entity, isLoosingHp = false, hpLossStart = nil, maxHp = hp,
		hpText = tostring(round(hp*100.0F,0))..'/'..tostring(round(hp*100.0F,0)), 
		hpTextWidth = 0, hpTextHeight = 0, diedTimestamp = nil, isDead = false,
		playerAlpha = utils.getAlpha(entity, _self.playerIndex), weapon = weapon, isCrit = isCrit, 
		Colors = CombatText.HealthBar.Colors, Padding = CombatText.HealthBar.Padding
	};
	_self.barList[uid].hpTextWidth = CombatText.Fn.measureStringX(_self.hpTextFont, _self.barList[uid].hpText);
	_self.barList[uid].hpTextHeight = CombatText.Fn.measureStringY(_self.hpTextFont, _self.barList[uid].hpText);
	return _self.barList[uid];
end

local function addDmg(_self, uid, diff, color, wasCrit, target)
	if _self.dmgList[uid] == nil then 
		_self.dmgList[uid] = { items = {
			[0] = { --precreate first item => helps lua to build hashtable right from start
				diff = true, color = true, wasCrit = true, font = true, zx = true, zy = true, zz = true, expired = false, 
				timestamp = true, startY = true, shiftY = true, textWidth = true, textLeft = true, textHeight = true
			}
		}, 
			count = 0, active = 0, target = target, playerAlpha = utils.getAlpha(target, _self.playerIndex), 
			Background = CombatText.FloatingDamage.Background, 
			Speed = CombatText.FloatingDamage.Speed, Ttl = CombatText.FloatingDamage.Ttl
		} 
	end
	local dmgItm = _self.dmgList[uid];

	local font = CombatText.FloatingDamage.NormalFont;
	if wasCrit then font = CombatText.FloatingDamage.CritFont; end
	
	local startY = CombatText.HealthBar.YOffset;
	local shiftY = CombatText.Fn.fontHeight(font);
	font = UIFont.FromString(font);
	
	if CombatText.HealthBar.Visible then
		startY = startY + 2 + CombatText.HealthBar.Height;
	end
	if CombatText.CurrentTotalHp.Visible then
		shiftY = shiftY + 2 + CombatText.Fn.fontHeight(CombatText.CurrentTotalHp.Font);
	end

	local textWidth = CombatText.Fn.measureStringX(font, diff);
	local textHeight = CombatText.Fn.measureStringY(font, diff);
	dmgItm.items[dmgItm.count] = { 
		diff = diff, color = color, wasCrit = wasCrit, font = font,
		zx = target:getX(), zy = target:getY(), zz = target:getZ(), 
		expired = false, timestamp = tms(), startY = startY, shiftY = shiftY,
		textWidth = textWidth, textLeft = textWidth/2,
		textHeight = CombatText.Fn.measureStringY(font, diff)
	}
	dmgItm.count = dmgItm.count+1;
	dmgItm.active = dmgItm.active+1;
end

--************************************************************************--
--** local render functions
--************************************************************************--

local function updateRenderData(_self)
	_self.renderData.zoom = core():getZoom(_self.playerIndex);
	_self.renderData.width = utils.getBarWidth(CombatText.HealthBar.Width, _self.renderData.zoom);
	_self.renderData.height = utils.getBarHeight(CombatText.HealthBar.Height, _self.renderData.zoom);
	_self.renderData.fontZoom = 0;
	_self.renderData.xWithOffset = _self.x;
	_self.renderData.offsetY = (CombatText.HealthBar.YOffset / _self.renderData.zoom);
	_self.renderData.yWithOffset = _self.y+_self.renderData.offsetY;
	if CombatText.CurrentTotalHp.Visible then _self.renderData.fontZoom = utils.getFontZoom(_self.renderData.zoom); end
end

local function renderHealthBar(_self, barItm, tick)
	local zx = barItm.entity:getX()
	local zy = barItm.entity:getY()
	local zz = barItm.entity:getZ()
	local zScrX = isoToScreenX(_self.playerIndex, zx, zy, zz)-_self.renderData.xWithOffset;
	local zScrY = isoToScreenY(_self.playerIndex, zx, zy, zz)-_self.renderData.yWithOffset;
	
	if barItm.isLoosingHp then
		local lossStep = utils.calculateLossStep(barItm.hpLoss)
		local tickDiff = (tick - barItm.hpLossStart)
		local loosingHpTick = (tickDiff/CombatText.HealthBar.LoosingHpTick)
		local frameDiff = barItm.maxHp * lossStep * loosingHpTick
		barItm.hpLoss = utils.max(0, barItm.hpLoss - frameDiff);
		barItm.hpLossStart = tick
		
		if barItm.hpLoss <= 0 then
			barItm.hpLoss = 0;
			barItm.isLoosingHp = false;
		end
	end
	
	local nowHpWidth = (barItm.currentHp / barItm.maxHp) * _self.renderData.width
	local minusWidthHalf = zScrX-(_self.renderData.width/2)
	
	--_self.javaObject:DrawTextureScaledCol(nil, minusWidthHalf-barItm.Padding, zScrY-barItm.Padding, _self.renderData.width+barItm.Padding*2, _self.renderData.height+barItm.Padding*2, 
	--	barItm.Colors.Background.r, barItm.Colors.Background.g, barItm.Colors.Background.b, barItm.Colors.Background.a*barItm.playerAlpha);
	_self:drawRect(minusWidthHalf-barItm.Padding, zScrY-barItm.Padding, _self.renderData.width+barItm.Padding*2, _self.renderData.height+barItm.Padding*2, 
		barItm.Colors.Background.a*barItm.playerAlpha, barItm.Colors.Background.r, barItm.Colors.Background.g, barItm.Colors.Background.b)

	--_self.javaObject:DrawTextureScaledCol(nil, minusWidthHalf, zScrY, nowHpWidth, _self.renderData.height, 
	--	barItm.Colors.CurrentHealth.r, barItm.Colors.CurrentHealth.g, barItm.Colors.CurrentHealth.b, barItm.Colors.CurrentHealth.a*barItm.playerAlpha);
	_self:drawRect(minusWidthHalf, zScrY, nowHpWidth, _self.renderData.height, 
		barItm.Colors.CurrentHealth.a*barItm.playerAlpha, barItm.Colors.CurrentHealth.r, barItm.Colors.CurrentHealth.g, barItm.Colors.CurrentHealth.b)
		
	if barItm.isLoosingHp then
		--_self.javaObject:DrawTextureScaledCol(nil, minusWidthHalf+nowHpWidth, zScrY, ((barItm.hpLoss / barItm.maxHp) * _self.renderData.width), _self.renderData.height, 
		--	barItm.Colors.LoosingHealth.r, barItm.Colors.LoosingHealth.g, barItm.Colors.LoosingHealth.b, barItm.Colors.LoosingHealth.a*barItm.playerAlpha);
		_self:drawRect(minusWidthHalf+nowHpWidth, zScrY, ((barItm.hpLoss / barItm.maxHp) * _self.renderData.width), _self.renderData.height, 
			barItm.Colors.LoosingHealth.a*barItm.playerAlpha, barItm.Colors.LoosingHealth.r, barItm.Colors.LoosingHealth.g, barItm.Colors.LoosingHealth.b)
	end
	
	--local ba = barItm.Colors.Border.a*barItm.playerAlpha
	--local b_x = minusWidthHalf-barItm.Padding
	--local b_y = zScrY-barItm.Padding
	--local b_w = _self.renderData.width+barItm.Padding*2
	--local b_h = _self.renderData.height+barItm.Padding*2
	--_self.javaObject:DrawTextureScaledColor(nil, b_x, b_y, 1, b_h, barItm.Colors.Border.r, barItm.Colors.Border.g, barItm.Colors.Border.b, ba);
	--_self.javaObject:DrawTextureScaledColor(nil, b_x+1, b_y, b_w-2, 1, barItm.Colors.Border.r, barItm.Colors.Border.g, barItm.Colors.Border.b, ba);
	--_self.javaObject:DrawTextureScaledColor(nil, b_x+b_w-1, b_y, 1, b_h, barItm.Colors.Border.r, barItm.Colors.Border.g, barItm.Colors.Border.b, ba);
	--_self.javaObject:DrawTextureScaledColor(nil, b_x+1, b_y+b_h-1, b_w-2, 1, barItm.Colors.Border.r, barItm.Colors.Border.g, barItm.Colors.Border.b, ba);

	_self:drawRectBorder(minusWidthHalf-barItm.Padding, zScrY-barItm.Padding, _self.renderData.width+barItm.Padding*2, _self.renderData.height+barItm.Padding*2, 
		barItm.Colors.Border.a*barItm.playerAlpha, barItm.Colors.Border.r, barItm.Colors.Border.g, barItm.Colors.Border.b)
end

local function renderFloatingDmgs(_self, damages, tick)
	for i=0, damages.count-1, 1 do
		local d = damages.items[i]
		if d.expired == false then
			local timeOffset = (tick-d.timestamp)/damages.Speed;
			local zIsoX = isoToScreenX(_self.playerIndex, d.zx, d.zy, d.zz)-_self.renderData.xWithOffset
			local zIsoY = isoToScreenY(_self.playerIndex, d.zx, d.zy, d.zz)-_self.renderData.yWithOffset-d.shiftY-timeOffset;
			
			_self.javaObject:DrawTextureScaledCol(nil, zIsoX-d.textLeft-1, zIsoY+2, d.textWidth+2, d.textHeight-2, 
				damages.Background.r, damages.Background.g, damages.Background.b, damages.Background.a*damages.playerAlpha);
			--_self:drawRect(zIsoX-d.textLeft-1, zIsoY+2, d.textWidth+2, d.textHeight-2, 
			--	damages.Background.a*damages.playerAlpha, damages.Background.r, damages.Background.g, damages.Background.b) 

			_self.javaObject:DrawText(d.font, d.diff, zIsoX-d.textLeft, zIsoY, d.color.r, d.color.g, d.color.b, d.color.a*damages.playerAlpha);
			--_self:drawText(d.diff, zIsoX-d.textLeft, zIsoY, d.color.r, d.color.g, d.color.b, d.color.a*damages.playerAlpha, d.font)
			
			if d.timestamp + damages.Ttl < tick then 
				d.expired = true 
				damages.active = damages.active -1;
			end
		end
	end
end

--************************************************************************--
--** ISHealthBarManager
--************************************************************************--

function ISHealthBarManager:initialize()
	ISUIElement.initialise(self);
end

function ISHealthBarManager:onZombieDead(uid, isOnFire)
	if self.barList[uid] ~= nil and CombatText.FloatingDamage.Visible then
		local itm = self.barList[uid];
		local diff = utils.damageDiff(0, itm.currentHp)
		local wasCrit = itm.isCrit ~= nil and itm.isCrit == true;
		local color = utils.getDamageColor(0, itm.currentHp, isOnFire and itm.weapon == nil, wasCrit);
		addDmg(self, uid, diff, color, wasCrit, itm.entity);
	end

	removeAll(self, uid, true);
end

function ISHealthBarManager:prerender()
	self:setStencilRect(0,0,self.renderWidth,self.renderHeight)
end

function ISHealthBarManager:render()
	if self.active then
		local sysTick = utils.getSystemTimestamp();
		self.renderIdleTime = sysTick - self.renderIdleTime;
		local tick = tms();
		local gameTick = utils.getGameTimestamp();
		updateRenderData(self);
		
		local startX = 65;
		local startY = 35;
		
		if CombatText.debug.base then startX, startY = debugRender.base(self, startX, startY); end
		if CombatText.debug.playerLink then startX, startY = debugRender.playerLink(self, startX, startY); end

		if CombatText.debug.trackingData then
			for tk,tv in pairs(CombatTextCache.TrackingList) do
				startX, startY = debugRender.trackingData(self, startX, startY, tk, tv, gameTick);
			end
		end
		
		if CombatText.HealthBar.Visible then
			for uid,itm in pairs(self.barList) do
				renderHealthBar(self, itm, tick)
				
				if CombatText.debug.healthBar then startX, startY = debugRender.healthBar(self, startX, startY, itm, gameTick); end
			end
		end
		if CombatText.FloatingDamage.Visible then
			for uid,itm in pairs(self.dmgList) do
				renderFloatingDmgs(self, itm, tick)
				
				if CombatText.debug.damage then startX, startY = debugRender.damage(self, startX, startY, itm, tick) end
			end
		end
		
		if CombatText.debug.border then	 debugRender.border(self); end
		
		self.renderTime = utils.getSystemTimestamp() - sysTick;
		self.renderIdleTime = utils.getSystemTimestamp()
	end
	
	self:clearStencilRect();
end

function ISHealthBarManager:onHit(uid, weapon, isCrit, trackingItm)
	local barItm = self.barList[uid];
	if barItm ~= nil then
		barItm.weapon = weapon;
		barItm.isCrit = isCrit;
	else
		local playerX = self.player:getX();
		local playerY = self.player:getY();
		
		local distance = utils.distanceTo(playerX,playerY,trackingItm.entity:getX(), trackingItm.entity:getY());
		if (CombatText.HealthBar.Visible or CombatText.CurrentTotalHp.Visible) and (distance < CombatText.HealthBar.HideWhenInactive.distanceMoreThan) then
			barItm = addBar(self, uid, trackingItm.entity, weapon, isCrit);
		end	
	end
end

function ISHealthBarManager:update()
	if self.active then
		local sysTick = utils.getSystemTimestamp();
		local tick = utils.getGameTimestamp();
		local gameTick = tms();
		local playerX = self.player:getX();
		local playerY = self.player:getY();
		
		for uid, itm in pairs(CombatTextCache.TrackingList) do 
			if itm then
				local barItm = self.barList[uid];
				
				-- distance check => add bar only if we are close to target
				local distance = utils.distanceTo(playerX,playerY,itm.entity:getX(), itm.entity:getY());
				if (CombatText.HealthBar.Visible or CombatText.CurrentTotalHp.Visible) and barItm == nil and (distance < CombatText.HealthBar.HideWhenInactive.distanceMoreThan) then
					barItm = addBar(self, uid, itm.entity, itm.weapon, itm.isCrit);
				end
				
				if barItm ~= nil then
					-- check if tracked zombie received damage
					barItm.isDead = barItm.entity:isDead();
					if (((itm.isOnFire and itm.tick + CombatText.FloatingDamage.FireDmgUpdate < tick) or itm.isOnFire == false) or barItm.isDead) then
						local hpNow = barItm.entity:getHealth();
						if hpNow ~= barItm.currentHp then
							if hpNow < 0 then
								isDead = true;
								hpNow = 0;
							end
						
							local diff = utils.damageDiff(hpNow, barItm.currentHp);
							local wasCrit = barItm.isCrit ~= nil and barItm.isCrit == true;
							local color = utils.getDamageColor(hpNow, barItm.currentHp, itm.isOnFire and barItm.weapon == nil, wasCrit);
								
							if itm.hp ~= hpNow then itm.hp = hpNow; end
							itm.tick = tick
							
							if (CombatText.HealthBar.Visible or CombatText.CurrentTotalHp.Visible) then
								updateHealthBarHp(barItm, hpNow);
							end
							
							-- add floating damage only for non-dead zombies, finishing blow is handled in separate event
							if CombatText.FloatingDamage.Visible and barItm.isDead == false then
								addDmg(self, uid, diff, color, wasCrit, barItm.entity);
							end
						end
					end
					
					barItm.weapon = nil;
					barItm.isCrit = nil;
				end
				
				itm.weapon=nil;
				itm.isCrit=nil;
				
				if barItm.isDead or (itm.tick+CombatText.HealthBar.HideWhenInactive.noDamageFor < tick) then
					removeAll(self, uid, barItm.isDead);
				end
			end
		end
		
		for uid, itm in pairs(self.barList) do
			if itm.isDead then 
				if itm.hpLoss == 0 and itm.currentHp == 0 then self.barList[uid] = nil; end
			else
				if CombatTextCache.TrackingList[uid] == nil then
					self.barList[uid] = nil;
				else
					itm.playerAlpha = utils.getAlpha(itm.entity, self.playerIndex);
				end
			end
		end
		
		for uid, itm in pairs(self.dmgList) do
			local allExpired = true;
			for i=0,itm.count-1,1 do
				local dmgItm = itm.items[i];
				if dmgItm.timestamp + CombatText.FloatingDamage.Ttl < gameTick then 
					dmgItm.expired = true 
				end
				
				allExpired = allExpired and dmgItm.expired
			end
			
			if allExpired then 
				self.dmgList[uid] = nil 
			else
				itm.playerAlpha = utils.getAlpha(itm.target, self.playerIndex);
			end
		end
		
		self.updateTime = utils.getSystemTimestamp()-sysTick;
	end
end

function ISHealthBarManager:onNewPlayer()
	local offsetX = getPlayerScreenLeft(self.playerIndex);
	local offsetY = getPlayerScreenTop(self.playerIndex);
	
	self:setX(offsetX);
	self:setY(offsetY);
	
	self.renderWidth = getPlayerScreenWidth(self.playerIndex);
	self.renderHeight = getPlayerScreenHeight(self.playerIndex);
	self.players = getNumActivePlayers();
end

function ISHealthBarManager:new(playerIndex, player)
	local offsetX = getPlayerScreenLeft(playerIndex);
	local offsetY = getPlayerScreenTop(playerIndex);
	
	local o = {};
    o = ISUIElement:new(offsetX, offsetY, 1, 1);
    setmetatable(o, self);
    self.__index = self;
	
	-- essentials
	o.playerIndex = playerIndex;
	o.color = utils.playerColor(playerIndex);
	o.renderWidth = getPlayerScreenWidth(playerIndex);
	o.renderHeight = getPlayerScreenHeight(playerIndex);
	o.player = player;
	o.players = getNumActivePlayers();
	o.active = true;
	o.hpTextFont = UIFont.FromString(CombatText.CurrentTotalHp.Font);
	o.hpFontHeight = tm():getFontHeight(o.hpTextFont);
	o.updateTime = 0;
	o.renderTime = 0;
	o.renderIdleTime = 0;
	
	o.renderData = {};
	o.renderData.zoom = core():getZoom(playerIndex);
	o.renderData.width = utils.getBarWidth(CombatText.HealthBar.Width, o.renderData.zoom);
	o.renderData.height = utils.getBarHeight(CombatText.HealthBar.Height, o.renderData.zoom);
	o.renderData.fontZoom = 0;
	o.renderData.xWithOffset = o.x;
	o.renderData.offsetY = (CombatText.HealthBar.YOffset / o.renderData.zoom);
	o.renderData.yWithOffset = o.y+o.renderData.offsetY;
	if CombatText.CurrentTotalHp.Visible then o.renderData.fontZoom = utils.getFontZoom(o.renderData.zoom); end
	
	o.barList = {};
	o.dmgList = {};
	
	o:setCapture(false);
	
    return o;
end