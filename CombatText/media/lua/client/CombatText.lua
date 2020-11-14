local CT = {
	Fn = {
		print = print,
		pairs = pairs,
		tostring = tostring,
		getGametimeTimestamp = getGametimeTimestamp
	},
	FireDmgUpdate = 5,
	TrackingList = {}, --list of monitored UID's
	RgbMinus = {R=1.0D, G=0.4D, B=0.4D, A=1.0D},
	RgbPlus = {R=0.6D, G=1.0D, B=0.6D, A=1.0D},
	RgbOnFire = {R=0.8D, G=0.55D, B=0.0D, A=1.0D}
}

CT.Fn.damageDiff = function(currentHp, previousHp)
	delta = (currentHp - previousHp)*100.0F
	diff = ""
	
	if Math.abs(delta) < 5 then
		diff = CT.Fn.tostring(luautils.round(delta,2))
	elseif Math.abs(delta) < 10 then
		diff = CT.Fn.tostring(luautils.round(delta,1))
	else
		diff = CT.Fn.tostring(luautils.round(delta,0))
	end
	
	if currentHp > previousHp then 
		return "+"..diff 
	else
		return diff
	end
end

CT.Fn.getDamageColor = function(currentHp, previousHp, isOnFire)
	if isOnFire then
		return CT.RgbOnFire
	end
	
	if currentHp > previousHp then -- heal 
		return CT.RgbPlus
	else
		return CT.RgbMinus
	end
end

--IsoGameCharacter attacker
--IsoGameCharacter target
--HandWeapon weapon
--Float damage split => not actual damage dealt (it is potential weapon dmg, this value is later processed into actual damage)
function onHit(attacker, target, weapon, damage)
	uid = target:getUID()
	ttype = target:getObjectName()
	
	if (ttype == "Zombie" or ttype == "Player" or ttype == "Survivor" or ttype == "DeadBody") and CT.TrackingList[uid] == nil then
		CT.TrackingList[uid] = { ["hp"] = target:getHealth(), ["entity"] = target, ["isOnFire"] = false, ["tick"] = CT.Fn.getGametimeTimestamp() }
	end
end

--IsoZombie zombie
function onZombieUpdate(zombie)
	uid = zombie:getUID()
	if zombie:isOnFire() then
		if CT.TrackingList[uid] == nil then
			CT.TrackingList[uid] = { ["hp"] = zombie:getHealth(), ["entity"] = zombie, ["isOnFire"] = true, ["tick"]=CT.Fn.getGametimeTimestamp() }
		elseif CT.TrackingList[uid].isOnFire ~= true then
			CT.TrackingList[uid].isOnFire = true
		end
	elseif CT.TrackingList[uid] ~= nil and CT.TrackingList[uid].isOnFire == true then
		CT.TrackingList[uid].isOnFire = false
	end
end

--IsoPlayer player
function onPlayerUpdate(player)
	tick = CT.Fn.getGametimeTimestamp()
	for uid, itm in CT.Fn.pairs(CT.TrackingList) do 
		if itm ~= nil and ((itm.isOnFire and itm.tick + CT.FireDmgUpdate < tick) or itm.isOnFire == false) then
			hpNow = itm.entity:getHealth()
			if hpNow ~= itm.hp then
				diff = CT.Fn.damageDiff(hpNow, itm.hp)
				color = CT.Fn.getDamageColor(hpNow, itm.hp, itm.isOnFire)
				
				-- params:text|R|G|B|font|?messageRadius?|messageType|allowBBcode|allowImages|allowChatIcons|allowColors|allowFonts|equalizeLineHeights
				itm.entity:addLineChatElement(diff, color.R, color.G, color.B, UIFont.Medium, 90.0F, "radio", true,true,true,true,true,true);
				itm.hp = hpNow
				itm.tick = tick
			end
			
			if itm.entity:isDead() then 
				CT.TrackingList[uid] = nil
			end
		end
	end
end

-- register events
Events.OnWeaponHitCharacter.Add(onHit) --occurs before lowering target's health => store data in watchlist
Events.OnZombieUpdate.Add(onZombieUpdate) --occurs during every zombie update => update isOnFire flag for burning damage indication
Events.OnPlayerUpdate.Add(onPlayerUpdate) --occurs during every player update (much faster than OnZombieUpdate) => 
