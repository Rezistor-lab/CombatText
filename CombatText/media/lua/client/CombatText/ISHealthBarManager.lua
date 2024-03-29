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
local cache = CombatTextCache

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
	getAlpha = CombatText.Fn.getAlpha,
	fontHeight = CombatText.Fn.fontHeight,
	measureStringX = CombatText.Fn.measureStringX,
	measureStringY = CombatText.Fn.measureStringY
};

--- get string representation of damage
utils.damageDiff = function(currentHp, previousHp)
	local delta = (currentHp - previousHp)
	local diff = ""
	
	if utils.abs(delta) < 0.01 then
		return nil;
	elseif utils.abs(delta) < 5 then
		diff = tostring(utils.round(delta,2));
	elseif utils.abs(delta) < 10 then
		diff = tostring(utils.round(delta,1));
	else
		diff = tostring(utils.round(delta,0));
	end
	
	if currentHp > previousHp then 
		return "+"..diff;
	else
		return diff;
	end
end

--- select correct color for health change
utils.getDamageColor = function(settings, currentHp, previousHp, isOnFire, isCrit)
	if isOnFire then
		return settings.RgbOnFire
	end
	
	if currentHp > previousHp then -- heal 
		return settings.RgbPlus
	else
		return settings.RgbMinus
	end
end

utils.playerColor = function(playerIndex)
	if playerIndex == 0 then return {r=0,g=1,b=1} end
	if playerIndex == 1 then return {r=1,g=1,b=0} end
	if playerIndex == 2 then return {r=1,g=1,b=1} end
	return {r=1,g=0,b=1}
end

utils.calculateHpStep = function(hpChange)
	if hpChange <= 5 then return 0.03 end
	if hpChange <= 15 then return 0.07 end
	if hpChange <= 25 then return 0.15 end
	if hpChange <= 40 then return 0.25 end
	return utils.min(0.35, hpChange)
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

utils.getFontZoom = function(zoom)
	if zoom > 1.5 then 
		return 1 / (zoom-0.5);
	else
		return 1
	end
end

utils.getTotalHpTextOffset = function(barItm, position, _self, zScrX, zScrY, tw, th)
	local txtWidth = tw * _self.renderData.fontZoom;
	local textHeight = th * _self.renderData.fontZoom;
	local txtLeft = zScrX - txtWidth/2;
	local txtTop = zScrY - textHeight - (_self.renderData.height/2) - barItm.Padding

	if position == 'out-right' then
		txtLeft = zScrX + (_self.renderData.width/2) + barItm.Padding*2;
		txtTop = zScrY - (textHeight/2) + barItm.Padding
	-- elseif position == 'out-top' then 
	elseif position == 'out-left' then
		txtLeft = zScrX - (_self.renderData.width/2) - txtWidth - barItm.Padding*2;
		txtTop = zScrY - (textHeight/2) + barItm.Padding
	elseif position == 'out-bottom' then
		txtTop = zScrY + (_self.renderData.height/2) + barItm.Padding*2;
	
	elseif position == 'out-top-left' then
		txtLeft = zScrX - (_self.renderData.width/2);
	elseif position == 'out-top-right' then
		txtLeft = zScrX + (_self.renderData.width/2) - txtWidth - barItm.Padding;
	elseif position == 'out-bottom-left' then
		txtLeft = zScrX - (_self.renderData.width/2);
		txtTop = zScrY + (_self.renderData.height/2) + barItm.Padding*2;
	elseif position == 'out-bottom-right' then
		txtLeft = zScrX + (_self.renderData.width/2) - txtWidth - barItm.Padding;
		txtTop = zScrY + (_self.renderData.height/2) + barItm.Padding*2;
	end

	return txtLeft, txtTop
end

utils.getEntityHealth = function(entity)
	if entity:getObjectName() == "Player" then
		return entity:getBodyDamage():getHealth()
	end
	return entity:getHealth() * 100.0F;
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
	local zScrX = isoToScreenX(_self.playerIndex, zx, zy, zz)-_self.renderData.xWithOffset
	local zScrY = isoToScreenY(_self.playerIndex, zx, zy, zz)-_self.renderData.offsetY;
	
	_self:drawText('iso X:'..tostring(round(zx,2))..' Y:'..tostring(round(zy,2))..' Z:'..tostring(round(zz,2))..' | screen X:'..tostring(round(zScrX, 2))..' Y:'..tostring(round(zScrY,2))..' | inactivity remove after:'..tostring((tv.tick+_self.HealthBar.HideWhenInactive.noDamageFor-gameTick)), startX, startY, _self.color.r, _self.color.g, _self.color.b, 1, _self.hpTextFont)
	startY = startY + _self.hpFontHeight+2;
	
	return startX, startY;
end

debugRender.healthBar = function(_self, startX, startY, bv, gameTick)
	local zx = bv.entity:getX();
	local zy = bv.entity:getY();
	local zz = bv.entity:getZ();
	local zScrX = isoToScreenX(_self.playerIndex, zx, zy, zz)-_self.renderData.xWithOffset;
	local zScrY = isoToScreenY(_self.playerIndex, zx, zy, zz)-_self.y;
	
	local px = _self.player:getX();
	local py = _self.player:getY();
	local pz = _self.player:getZ();
	local pIsoX = isoToScreenX(_self.playerIndex, px, py, pz)-_self.renderData.xWithOffset;
	local pIsoY = isoToScreenY(_self.playerIndex, px, py, pz)-_self.y;
	
	local dist = utils.distanceTo(zx,zy,px,py)
	
	if _self.HealthBar.Visible and _self.CurrentTotalHp.Visible and (_self.CurrentTotalHp.Position == 'out-bottom-left' or _self.CurrentTotalHp.Position == 'out-bottom' or _self.CurrentTotalHp.Position == 'out-bottom-right') then 
		zScrY = zScrY - _self.renderData.height - _self.HealthBar.Padding; 
	end
	
	_self:drawRect(zScrX-2,zScrY-2, 4, 4, 0.5F, _self.color.r, _self.color.g, _self.color.b);
	_self:drawTextCentre('dist:'..tostring(utils.round(dist,2)), zScrX-2,zScrY-2, _self.color.r, _self.color.g, _self.color.b, 1, UIFont.Small);
	_self:drawLine2(zScrX, zScrY, pIsoX, pIsoY, 1, _self.color.r, _self.color.g, _self.color.b)
	
	_self:drawText('health bar:'..tostring(round(bv.maxHp, 2))..'/'..tostring(utils.round(bv.currentHp,2))..' lossing health:'..tostring(bv.isChangingHp)..' health loss:'..tostring(utils.round(bv.hpChange, 2))..' isDead:'..tostring(bv.isDead)..' dist:'..tostring(utils.round(dist,2))..' toRemove:'..tostring(dist > _self.HealthBar.HideWhenInactive.distanceMoreThan), startX, startY, _self.color.r, _self.color.g, _self.color.b, 1, _self.hpTextFont)
	startY = startY + _self.hpFontHeight+2;
	_self:drawText('hp text:'..bv.Position..' zoom:'..tostring(_self.renderData.zoom)..' fontZoom:'..tostring(_self.renderData.fontZoom), startX, startY, _self.color.r, _self.color.g, _self.color.b, 1, _self.hpTextFont)
	startY = startY + _self.hpFontHeight+2;
	
	local tw = utils.measureStringX(_self.hpTextFont, 'o-t')
	local th = utils.measureStringY(_self.hpTextFont, 'o-t')
	
	local hpX, hpY = utils.getTotalHpTextOffset(bv, 'out-top', _self, zScrX, zScrY-_self.renderData.offsetY, tw, th)
	_self.javaObject:DrawText(_self.hpTextFont, 'o-t', hpX,hpY, _self.renderData.fontZoom, _self.color.r, _self.color.g, _self.color.b, 0.5F);
	local hpX, hpY = utils.getTotalHpTextOffset(bv, 'out-right', _self, zScrX, zScrY-_self.renderData.offsetY, tw, th)
	_self.javaObject:DrawText(_self.hpTextFont, 'o-r', hpX,hpY, _self.renderData.fontZoom, _self.color.r, _self.color.g, _self.color.b, 0.5F);
	local hpX, hpY = utils.getTotalHpTextOffset(bv, 'out-left', _self, zScrX, zScrY-_self.renderData.offsetY, tw, th)
	_self.javaObject:DrawText(_self.hpTextFont, 'o-l', hpX,hpY, _self.renderData.fontZoom, _self.color.r, _self.color.g, _self.color.b, 0.5F);
	local hpX, hpY = utils.getTotalHpTextOffset(bv, 'out-bottom', _self, zScrX, zScrY-_self.renderData.offsetY, tw, th)
	_self.javaObject:DrawText(_self.hpTextFont, 'o-b', hpX,hpY, _self.renderData.fontZoom, _self.color.r, _self.color.g, _self.color.b, 0.5F);
	
	local hpX, hpY = utils.getTotalHpTextOffset(bv, 'out-top-left', _self, zScrX, zScrY-_self.renderData.offsetY, tw, th)
	_self.javaObject:DrawText(_self.hpTextFont, 'otl', hpX,hpY, _self.renderData.fontZoom, _self.color.r, _self.color.g, _self.color.b, 0.5F);
	local hpX, hpY = utils.getTotalHpTextOffset(bv, 'out-top-right', _self, zScrX, zScrY-_self.renderData.offsetY, tw, th)
	_self.javaObject:DrawText(_self.hpTextFont, 'otr', hpX,hpY, _self.renderData.fontZoom, _self.color.r, _self.color.g, _self.color.b, 0.5F);
	
	local hpX, hpY = utils.getTotalHpTextOffset(bv, 'out-bottom-left', _self, zScrX, zScrY-_self.renderData.offsetY, tw, th)
	_self.javaObject:DrawText(_self.hpTextFont, 'obl', hpX,hpY, _self.renderData.fontZoom, _self.color.r, _self.color.g, _self.color.b, 0.5F);
	local hpX, hpY = utils.getTotalHpTextOffset(bv, 'out-bottom-right', _self, zScrX, zScrY-_self.renderData.offsetY, tw, th)
	_self.javaObject:DrawText(_self.hpTextFont, 'obr', hpX,hpY, _self.renderData.fontZoom, _self.color.r, _self.color.g, _self.color.b, 0.5F);
	
	return startX, startY;
end

debugRender.base = function(_self, startX, startY, gameTick)
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
	_self:drawText('Tracking items:'..tostring(cache.TrackingListCount)..' | dmg total:'..tostring(dmgTotal)..' | dmg active:'..tostring(dmgActive)..' | bars:'..tostring(barsTotal), startX, startY, _self.color.r, _self.color.g, _self.color.b, 1, _self.hpTextFont)
	startY = startY + _self.hpFontHeight+2;
	--16.6ms => 60fps
	--33.3ms => 30fps
	_self:drawText('Render time:'..tostring(_self.renderTime)..'ms/idle:'..tostring(_self.renderIdleTime)..'ms | Update time:'..tostring(_self.updateTime)..'ms | GameTick:'..tostring(gameTick), startX, startY, _self.color.r, _self.color.g, _self.color.b, 1, _self.hpTextFont)
	startY = startY + _self.hpFontHeight+2;
	
	return startX, startY;
end

debugRender.damage = function(_self, startX, startY, damages, tick)
	_self:drawText('Floating items:'..tostring(damages.count), startX, startY, _self.color.r, _self.color.g, _self.color.b, 1, _self.hpTextFont)
	startY = startY + _self.hpFontHeight+2;	

	for i=0,damages.count-1,1 do
		local itm = damages.items[i];
		if itm.expired == false then
			local timeOffset = (tick-itm.timestamp)/_self.FloatingDamage.Speed;
			local zScrX = isoToScreenX(_self.playerIndex, itm.zx, itm.zy, itm.zz)
			local zScrY = isoToScreenY(_self.playerIndex, itm.zx, itm.zy, itm.zz)-_self.renderData.offsetY-itm.shiftY-timeOffset+itm.textHeight;
			_self:drawRect(zScrX-2,zScrY-2, 4, 4, 0.5F, _self.color.r, _self.color.g, _self.color.b);
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
			local zScrX = isoToScreenX(_self.playerIndex, zx, zy, zz);
			local zScrY = isoToScreenY(_self.playerIndex, zx, zy, zz);
			
			local dist = utils.distanceTo(px, py, zx, zy);
			_self:drawText('P'..tostring(i)..' dist:'..tostring(utils.round(dist,2)), startX, startY, _self.color.r, _self.color.g, _self.color.b, 1, _self.hpTextFont)
			startY = startY + _self.hpFontHeight+2

			_self:drawLine2(zScrX, zScrY, pIsoX, pIsoY, 1, _self.color.r, _self.color.g, _self.color.b)
		end
	end
	
	return startX, startY;
end

--************************************************************************--
--** local data manipulation functions
--************************************************************************--

local function updateHealthBarHp(item, hp)
	if item.currentHp >= 0 then
		if hp ~= item.currentHp then
			if hp < item.currentHp or hp > item.currentHp then		
				if item.isChangingHp then
					item.hpChange = item.hpChange + (item.currentHp - utils.max(0, hp));
				else
					item.hpChange = item.currentHp - utils.max(0, hp);
					item.hpChangeStart = tms()
					item.isChangingHp = true
				end
			end
			if hp > item.maxHp then item.maxHp = hp; end
			
			item.currentHp = utils.max(0, hp);
			item.hpText = tostring(utils.round(item.currentHp,0))..'/'..tostring(utils.round(item.maxHp,0))
			item.hpTextWidth = utils.measureStringX(item.hpTextFont, item.hpText);
			item.hpTextHeight = utils.measureStringY(item.hpTextFont, item.hpText)
		end
	end
end

local function setTargetDead(itm)
	itm.diedTimestamp = tms()
	updateHealthBarHp(itm, 0);
	itm.isDead = true
end

local function removeAll(_self, uid, isDead)
	if cache.TrackingList[uid] ~= nil then
		cache.TrackingList[uid] = nil;
		cache.TrackingListCount = cache.TrackingListCount-1;
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
	local hp = utils.getEntityHealth(entity);
	local hpText = tostring(round(hp,0))..'/'..tostring(round(hp,0));
	local position = _self.CurrentTotalHp.Position
	
	_self.barList[uid] = {
		hpChange = 0, currentHp = hp, entity = entity, isChangingHp = false, hpChangeStart = nil, maxHp = hp,
		hpText = hpText, diedTimestamp = nil, isDead = false, hpTextFont = _self.hpTextFont,
		playerAlpha = utils.getAlpha(entity, _self.playerIndex), weapon = weapon, isCrit = isCrit, 
		hpTextWidth = utils.measureStringX(_self.hpTextFont, hpText),
		hpTextHeight = utils.measureStringY(_self.hpTextFont, hpText),
		shiftBar = position == 'out-bottom-left' or position == 'out-bottom' or position == 'out-bottom-right',
		
		Colors = _self.HealthBar.Colors, 
		Padding = _self.HealthBar.Padding,
		FadeOutAfter = _self.HealthBar.FadeOutAfter,
		ChangingHpTick = _self.HealthBar.LoosingHpTick,
		
		Position = position,
		HpTotalColor = _self.CurrentTotalHp.Color
	};
	
	return _self.barList[uid];
end

local function addDmg(_self, uid, diff, color, wasCrit, target, isBurningDmg)
	if _self.dmgList[uid] == nil then 
		_self.dmgList[uid] = { items = {
			[0] = { --precreate first item => helps lua to build hashtable right from start
				diff = true, color = true, wasCrit = true, font = true, zx = true, zy = true, zz = true, expired = false, 
				timestamp = true, startY = true, shiftY = true, textWidth = true, textLeft = true, textHeight = true
			}
		}, 
			count = 0, active = 0, target = target, playerAlpha = utils.getAlpha(target, _self.playerIndex), 
			Background = _self.FloatingDamage.Background, 
			Speed = _self.FloatingDamage.Speed, Ttl = _self.FloatingDamage.Ttl
		} 
	end
	local dmgItm = _self.dmgList[uid];

	local font = _self.FloatingDamage.NormalFont;
	if wasCrit then font = _self.FloatingDamage.CritFont; end
	
	local startY = _self.HealthBar.YOffset;
	local shiftY = utils.fontHeight(font);
	font = UIFont.FromString(font);
	
	if _self.HealthBar.Visible then
		startY = startY + 2 + _self.HealthBar.Height;
	end
	if _self.CurrentTotalHp.Visible then
		shiftY = shiftY + 2 + utils.fontHeight(_self.CurrentTotalHp.Font);
	end

	local textWidth = utils.measureStringX(font, diff);
	local textHeight = utils.measureStringY(font, diff);
	dmgItm.items[dmgItm.count] = { 
		diff = diff, color = color, wasCrit = wasCrit, font = font,
		zx = target:getX(), zy = target:getY(), zz = target:getZ(), 
		expired = false, timestamp = tms(), startY = startY, shiftY = shiftY,
		textWidth = textWidth, textLeft = textWidth/2,
		textHeight = utils.measureStringY(font, diff),
		visible = (_self.FloatingDamage.ShowFireDamage and isBurningDmg) or (isBurningDmg == false)
	}
	dmgItm.count = dmgItm.count+1;
	dmgItm.active = dmgItm.active+1;
end

--************************************************************************--
--** local render functions
--************************************************************************--

local function updateRenderData(_self)
	_self.renderData.zoom = core():getZoom(_self.playerIndex);
	_self.renderData.width = utils.getBarWidth(_self.HealthBar.Width, _self.renderData.zoom);
	_self.renderData.height = utils.getBarHeight(_self.HealthBar.Height, _self.renderData.zoom);
	_self.renderData.xWithOffset = _self.x;
	_self.renderData.offsetY = (_self.HealthBar.YOffset / _self.renderData.zoom);
	_self.renderData.yWithOffset = _self.y+_self.renderData.offsetY;
	_self.renderData.fontZoom = utils.getFontZoom(_self.renderData.zoom);
	_self.renderData.totalHpVisible = _self.renderData.zoom <= _self.CurrentTotalHp.ShowBelowZoom;
end

local function renderHealthBar(_self, barItm, tick, hpBar, totalHp)
	local zx = barItm.entity:getX()
	local zy = barItm.entity:getY()
	local zz = barItm.entity:getZ()
	local zScrX = isoToScreenX(_self.playerIndex, zx, zy, zz)-_self.renderData.xWithOffset;
	local zScrY = isoToScreenY(_self.playerIndex, zx, zy, zz)-_self.renderData.yWithOffset;
	local nowHpWidth = (barItm.currentHp / barItm.maxHp) * _self.renderData.width
	local minusWidthHalf = zScrX-(_self.renderData.width/2)
	
	if hpBar and totalHp and _self.renderData.totalHpVisible and barItm.shiftBar then zScrY = zScrY - _self.renderData.height - barItm.Padding; end
	
	if hpBar then
		if barItm.isChangingHp then
			local changeStep = utils.calculateHpStep(barItm.hpChange)
			local tickDiff = (tick - barItm.hpChangeStart)
			local changingHpTick = (tickDiff/barItm.ChangingHpTick)
			local frameDiff = barItm.maxHp * changeStep * changingHpTick
			barItm.hpChange = utils.max(0, barItm.hpChange - frameDiff);
			barItm.hpChangeStart = tick
			
			if barItm.hpChange <= 0 then
				barItm.hpChange = 0;
				barItm.isChangingHp = false;
			end
		end
		
		--_self.javaObject:DrawTextureScaledCol(nil, minusWidthHalf-barItm.Padding, zScrY-barItm.Padding, _self.renderData.width+barItm.Padding*2, _self.renderData.height+barItm.Padding*2, 
		--	barItm.Colors.Background.r, barItm.Colors.Background.g, barItm.Colors.Background.b, barItm.Colors.Background.a*barItm.playerAlpha);
		_self:drawRect(minusWidthHalf-barItm.Padding, zScrY-barItm.Padding, _self.renderData.width+barItm.Padding*2, _self.renderData.height+barItm.Padding*2, 
			barItm.Colors.Background.a*barItm.playerAlpha, barItm.Colors.Background.r, barItm.Colors.Background.g, barItm.Colors.Background.b)

		--_self.javaObject:DrawTextureScaledCol(nil, minusWidthHalf, zScrY, nowHpWidth, _self.renderData.height, 
		--	barItm.Colors.CurrentHealth.r, barItm.Colors.CurrentHealth.g, barItm.Colors.CurrentHealth.b, barItm.Colors.CurrentHealth.a*barItm.playerAlpha);
		_self:drawRect(minusWidthHalf, zScrY, nowHpWidth, _self.renderData.height, 
			barItm.Colors.CurrentHealth.a*barItm.playerAlpha, barItm.Colors.CurrentHealth.r, barItm.Colors.CurrentHealth.g, barItm.Colors.CurrentHealth.b)
			
		if barItm.isChangingHp then
			--_self.javaObject:DrawTextureScaledCol(nil, minusWidthHalf+nowHpWidth, zScrY, ((barItm.hpChange / barItm.maxHp) * _self.renderData.width), _self.renderData.height, 
			--	barItm.Colors.LoosingHealth.r, barItm.Colors.LoosingHealth.g, barItm.Colors.LoosingHealth.b, barItm.Colors.LoosingHealth.a*barItm.playerAlpha);
			_self:drawRect(minusWidthHalf+nowHpWidth, zScrY, ((barItm.hpChange / barItm.maxHp) * _self.renderData.width), _self.renderData.height, 
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
		barItm.Colors.Border.a*barItm.playerAlpha, barItm.Colors.Border.r, barItm.Colors.Border.g, barItm.Colors.Border.b);
	end
	
	if totalHp and _self.renderData.totalHpVisible then
		local txtLeft, txtTop = utils.getTotalHpTextOffset(barItm, barItm.Position, _self, zScrX, zScrY, barItm.hpTextWidth, barItm.hpTextHeight)
		
		_self.javaObject:DrawText(barItm.hpTextFont, barItm.hpText, txtLeft, txtTop, _self.renderData.fontZoom, 
			barItm.HpTotalColor.r, barItm.HpTotalColor.g, barItm.HpTotalColor.b, barItm.HpTotalColor.a*barItm.playerAlpha)
	end
end

local function renderFloatingDmgs(_self, damages, tick)
	for i=0, damages.count-1, 1 do
		local d = damages.items[i]
		if d.expired == false then
			local timeOffset = (tick-d.timestamp)/damages.Speed;
			local zScrX = isoToScreenX(_self.playerIndex, d.zx, d.zy, d.zz)-_self.renderData.xWithOffset
			local zScrY = isoToScreenY(_self.playerIndex, d.zx, d.zy, d.zz)-_self.renderData.yWithOffset-d.shiftY-timeOffset;
			
			if d.visible == true then
				_self.javaObject:DrawTextureScaledCol(nil, zScrX-d.textLeft-1, zScrY+2, d.textWidth+2, d.textHeight-2, 
					damages.Background.r, damages.Background.g, damages.Background.b, damages.Background.a*damages.playerAlpha);
				--_self:drawRect(zScrX-d.textLeft-1, zScrY+2, d.textWidth+2, d.textHeight-2, 
				--	damages.Background.a*damages.playerAlpha, damages.Background.r, damages.Background.g, damages.Background.b) 

				_self.javaObject:DrawText(d.font, d.diff, zScrX-d.textLeft, zScrY, d.color.r, d.color.g, d.color.b, d.color.a*damages.playerAlpha);
				--_self:drawText(d.diff, zScrX-d.textLeft, zScrY, d.color.r, d.color.g, d.color.b, d.color.a*damages.playerAlpha, d.font)
			end
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
	if self.barList[uid] ~= nil and self.FloatingDamage.Visible then
		local itm = self.barList[uid];
		local diff = utils.damageDiff(0, itm.currentHp)
		if diff ~= nil then		
			local wasCrit = itm.isCrit ~= nil and itm.isCrit == true;
			local color = utils.getDamageColor(self.FloatingDamage, 0, itm.currentHp, isOnFire and itm.weapon == nil, wasCrit);
			addDmg(self, uid, diff, color, wasCrit, itm.entity, isOnFire and itm.weapon == nil);
		end
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
		
		--if self.debug.base then startX, startY = debugRender.base(self, startX, startY, gameTick); end
		--if self.debug.playerLink then startX, startY = debugRender.playerLink(self, startX, startY); end

		--if self.debug.trackingData then
		--	for tk,tv in pairs(cache.TrackingList) do
		--		startX, startY = debugRender.trackingData(self, startX, startY, tk, tv, gameTick);
		--	end
		--end
		
		if self.HealthBar.Visible or self.CurrentTotalHp.Visible then
			for uid,itm in pairs(self.barList) do
				renderHealthBar(self, itm, tick, self.HealthBar.Visible, self.CurrentTotalHp.Visible);

				--if self.debug.healthBar then startX, startY = debugRender.healthBar(self, startX, startY, itm, gameTick); end
			end
		end
		if self.FloatingDamage.Visible then
			for uid,itm in pairs(self.dmgList) do
				renderFloatingDmgs(self, itm, tick)
				
				--if self.debug.damage then startX, startY = debugRender.damage(self, startX, startY, itm, tick) end
			end
		end
		
		--if self.debug.border then debugRender.border(self); end
		
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
		if (self.HealthBar.Visible or self.CurrentTotalHp.Visible or self.FloatingDamage.Visible) and (distance < self.HealthBar.HideWhenInactive.distanceMoreThan) then
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
		local cch = cache;
		
		for uid, itm in pairs(cache.TrackingList) do 
			if itm then
				local barItm = self.barList[uid];
				
				-- distance check => add bar only if we are close to target
				local distance = utils.distanceTo(playerX,playerY,itm.entity:getX(), itm.entity:getY());
				if (self.HealthBar.Visible or self.CurrentTotalHp.Visible or self.FloatingDamage.Visible) and barItm == nil and (distance < self.HealthBar.HideWhenInactive.distanceMoreThan) then
					barItm = addBar(self, uid, itm.entity, itm.weapon, itm.isCrit);
				end
				
				if barItm ~= nil then
					-- check if tracked zombie received damage
					barItm.isDead = barItm.entity:isDead();
					
					if (((barItm.entity:isOnFire() and (itm.tick + self.FloatingDamage.FireDmgUpdate) < tick) or 
						 (itm.isBleeding and (itm.tick + self.FloatingDamage.FireDmgUpdate) < tick) or 
						 (barItm.entity:isOnFire() == false and itm.isBleeding == false) or (itm.weapon ~= nil)
						) or barItm.isDead) then
						local hpNow = utils.getEntityHealth(barItm.entity);

						if hpNow ~= barItm.currentHp then
							if hpNow < 0 then
								isDead = true;
								hpNow = 0;
							end
						
							local diff = utils.damageDiff(hpNow, barItm.currentHp);
							local wasCrit = barItm.isCrit ~= nil and barItm.isCrit == true;
							local color = utils.getDamageColor(self.FloatingDamage, hpNow, barItm.currentHp, barItm.entity:isOnFire() and barItm.weapon == nil, wasCrit);
								
							if itm.hp ~= hpNow then itm.hp = hpNow; end
							itm.tick = tick
							
							if (self.HealthBar.Visible or self.CurrentTotalHp.Visible or self.FloatingDamage.Visible) then
								updateHealthBarHp(barItm, hpNow);
							end

							-- add floating damage only for non-dead zombies, finishing blow is handled in separate event
							if diff ~= nil and self.FloatingDamage.Visible and barItm.isDead == false then
								addDmg(self, uid, diff, color, wasCrit, barItm.entity, barItm.entity:isOnFire() and barItm.weapon == nil);
							end
						end
					end
					
					if barItm.weapon ~= nil or barItm.isCrit ~= nil then
						barItm.weapon = nil;
						barItm.isCrit = nil;
					end
					
					-- try to check remove condition for bar
					if barItm.isDead or ((itm.tick+self.HealthBar.HideWhenInactive.noDamageFor-tick) < 0) or (distance >= self.HealthBar.HideWhenInactive.distanceMoreThan) then
						removeAll(self, uid, barItm.isDead);
					end
				end
				
				if itm ~= nil then
					if itm.weapon ~= nil or itm.isCrit ~= nil then
						itm.weapon=nil;
						itm.isCrit=nil;
					end
					-- second removal check
					if itm.entity:isDead() or ((itm.tick+self.HealthBar.HideWhenInactive.noDamageFor-tick) < 0) or (distance >= self.HealthBar.HideWhenInactive.distanceMoreThan) then
						removeAll(self, uid, itm.entity:isDead());
					end
				end
				
			end
		end
		
		for uid, itm in pairs(self.barList) do
			if itm.isDead then 
				if itm.hpChange == 0 and itm.currentHp > 0 and not itm.isChangingHp then
					-- killing blow fix in MP for client who was watching kill
					local diff = utils.damageDiff(0, itm.currentHp);
					local wasCrit = itm.isCrit ~= nil and itm.isCrit == true;
					local color = utils.getDamageColor(self.FloatingDamage, 0, itm.currentHp, itm.entity:isOnFire() and itm.weapon == nil, wasCrit);
					addDmg(self, uid, diff, color, wasCrit, itm.entity, itm.entity:isOnFire() and itm.weapon == nil)
					setTargetDead(itm);
				else
					if itm.hpChange == 0 and itm.currentHp == 0 then 
						self.barList[uid] = nil;
						if cache.TrackingList[uid] ~= nil then
							cache.TrackingList[uid] = nil;
							cache.TrackingListCount = cache.TrackingListCount-1;
						end
					end
				end
			else
				if cache.TrackingList[uid] == nil then
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
				if (dmgItm.timestamp + self.FloatingDamage.Ttl) < gameTick then 
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

function ISHealthBarManager:onSettingsChange()
	self.HealthBar = CombatText.HealthBar;
	self.CurrentTotalHp = CombatText.CurrentTotalHp;
	self.FloatingDamage = CombatText.FloatingDamage;
	self.hpTextFont = UIFont.FromString(CombatText.CurrentTotalHp.Font);
	self.debug = CombatText.debug;
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
	
	o.HealthBar = CombatText.HealthBar;
	o.CurrentTotalHp = CombatText.CurrentTotalHp;
	o.FloatingDamage = CombatText.FloatingDamage;
		
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
	o.renderData.width = utils.getBarWidth(o.HealthBar.Width, o.renderData.zoom);
	o.renderData.height = utils.getBarHeight(o.HealthBar.Height, o.renderData.zoom);
	o.renderData.xWithOffset = o.x;
	o.renderData.offsetY = (o.HealthBar.YOffset / o.renderData.zoom);
	o.renderData.yWithOffset = o.y+o.renderData.offsetY;
	o.renderData.fontZoom = utils.getFontZoom(o.renderData.zoom);
	o.renderData.totalHpVisible = o.renderData.zoom <= o.CurrentTotalHp.ShowBelowZoom;
	
	o.barList = {};
	o.dmgList = {};
	
	o.debug = CombatText.debug;
	
	o:setCapture(false);
	
    return o;
end