require ("CombatTextBase.lua")
require ("CombatTextCache.lua")
require ("ISHealthBar.lua")
require ("ISFloatingDmg.lua")

function getGameTimestamp()
	return getGameTime():getCalender():getTimeInMillis()
end

function distanceTo(x1,y1,x2,y2)
	return Float.valueOf(Math.sqrt(Math.pow((x2 - x1), 2.0D) + Math.pow((y2 - y1), 2.0D)))
end

function removeAll(uid, isDead)
	CombatTextCache.TrackingList[uid] = nil;
	if CombatTextCache.BarInstances[uid] ~= nil then
		if isDead then
			CombatTextCache.BarInstances[uid]:targetDead();
		else
			CombatTextCache.BarInstances[uid]:remove();
		end
		CombatTextCache.BarInstances[uid] = nil;
	end
end

function damageDiff(currentHp, previousHp)
	delta = (currentHp - previousHp)*100.0F
	diff = ""
	
	if Math.abs(delta) < 5 then
		diff = tostring(luautils.round(delta,2))
	elseif Math.abs(delta) < 10 then
		diff = tostring(luautils.round(delta,1))
	else
		diff = tostring(luautils.round(delta,0))
	end
	
	if currentHp > previousHp then 
		return "+"..diff 
	else
		return diff
	end
end

function getDamageColor(currentHp, previousHp, isOnFire, isCrit)
	if isOnFire then
		return CombatText.FloatingDamage.RgbOnFire
	end
	
	if currentHp > previousHp then -- heal 
		return CombatText.FloatingDamage.RgbPlus
	else
		return CombatText.FloatingDamage.RgbMinus
	end
end

function solveHealthBar(target, attacker)
	if CombatText.HealthBar.Visible or CombatText.CurrentTotalHp.Visible then
		if CombatTextCache.BarInstances[uid] ~= nil and CombatTextCache.BarInstances[uid]:isValid(target, attacker:getPlayerNum()) ~= true then
			CombatTextCache.BarInstances[uid]:remove()
			CombatTextCache.BarInstances[uid] = nil
		end

		if CombatTextCache.BarInstances[uid] == nil then
			CombatTextCache.BarInstances[uid] = ISHealthBar:new(target, attacker:getPlayerNum());
			CombatTextCache.BarInstances[uid]:initialize();
			CombatTextCache.BarInstances[uid]:addToUIManager();
		end
	end
end

--IsoGameCharacter attacker
--IsoGameCharacter target
--HandWeapon weapon
--Float damage split => not actual damage dealt (it is potential weapon dmg, this value is later processed into actual damage)
function onHit(attacker, target, weapon, damage)
	uid = target:getUID()
	ttype = target:getObjectName()
	
	if (ttype == "Zombie" or ttype == "Player" or ttype == "Survivor" or ttype == "DeadBody") then
		if CombatTextCache.TrackingList[uid] == nil then
			CombatTextCache.TrackingList[uid] = { ["hp"] = target:getHealth(), ["entity"] = target, ["isOnFire"] = false, ["weapon"] = weapon, ["isCrit"] = attacker:isCriticalHit(), ["tick"] = getGameTimestamp() }
			solveHealthBar(target, attacker);
		else
			CombatTextCache.TrackingList[uid].weapon = weapon;
			CombatTextCache.TrackingList[uid].isCrit = attacker:isCriticalHit();
		end
	end
end

function onHitZombie(zombie, attacker, bodyPart, weapon)
	print('is crit:'..tostring(attacker:isCriticalHit())..'|bodypart:'..tostring(bodyPart))
end

--IsoZombie zombie
function onZombieUpdate(zombie)
	uid = zombie:getUID()
	if zombie:isOnFire() then
		if CombatTextCache.TrackingList[uid] == nil then
			CombatTextCache.TrackingList[uid] = { ["hp"] = zombie:getHealth(), ["entity"] = zombie, ["isOnFire"] = true, ["tick"]=getGameTimestamp() }
			solveHealthBar(zombie, getPlayer())
		elseif CombatTextCache.TrackingList[uid].isOnFire ~= true then
			CombatTextCache.TrackingList[uid].isOnFire = true
		end
	elseif CombatTextCache.TrackingList[uid] ~= nil and CombatTextCache.TrackingList[uid].isOnFire == true then
		CombatTextCache.TrackingList[uid].isOnFire = false
	end
end

--IsoPlayer player
function onPlayerUpdate(player)
	local tick = getGameTimestamp()
	playerX = player:getX()
	playerY = player:getY()
	for uid, itm in pairs(CombatTextCache.TrackingList) do 
		if itm ~= nil then
			if ((itm.isOnFire and itm.tick + CombatText.FloatingDamage.FireDmgUpdate < tick) or itm.isOnFire == false or itm.entity:isDead()) then
				hpNow = itm.entity:getHealth()
				if hpNow ~= itm.hp then
					if hpNow < 0 then
						hpNow = 0
					end
				
					local diff = damageDiff(hpNow, itm.hp)
					wasCrit = itm.isCrit ~= nil and itm.isCrit == true;
					color = getDamageColor(hpNow, itm.hp, itm.isOnFire and itm.weapon == nil, wasCrit)
					
					-- abandoned => chatElement will keep text in buffer after entity die and show it when entity is revived/reused
					-- params:text|R|G|B|font|?messageRadius?|messageType|allowBBcode|allowImages|allowChatIcons|allowColors|allowFonts|equalizeLineHeights
					--itm.entity:addLineChatElement(diff, color.r, color.g, color.b, UIFont.Medium, 90.0F, "radio", true,true,true,true,true,true);
						
					itm.hp = hpNow
					itm.tick = tick
					
					if (CombatText.HealthBar.Visible or CombatText.CurrentTotalHp.Visible) and CombatTextCache.BarInstances[uid] ~= nil then
						CombatTextCache.BarInstances[uid]:SetHp(hpNow)
					end
					if CombatText.FloatingDamage.Visible and (itm.entity:getTargetAlpha(player:getPlayerNum()) > 0 or player:isGodMod()) then
						local floatingDmg = ISFloatingDmg:new(itm.entity, diff, color, wasCrit, player:getPlayerNum())
						floatingDmg:initialize();
						floatingDmg:addToUIManager();
					end
				else
					if (itm.tick+CombatText.HealthBar.HideWhenInactive.noDamageFor < tick) or (distanceTo(playerX,playerY,itm.entity:getX(), itm.entity:getY()) > CombatText.HealthBar.HideWhenInactive.distanceMoreThan) then
						removeAll(uid, false)
					end
				end
			end
			
			itm.weapon=nil;
			itm.isCrit=nil;
			
			if itm.entity:isDead() then
				removeAll(uid, true)
			end
		end
	end
end

-- register events
Events.OnWeaponHitCharacter.Add(onHit) -- mark target for tracking and show health bar
Events.OnZombieUpdate.Add(onZombieUpdate) -- serves mainly to detect zombies on fire
--Events.OnHitZombie.Add(onHitZombie)
Events.OnPlayerUpdate.Add(onPlayerUpdate) -- main logic processing happens here
