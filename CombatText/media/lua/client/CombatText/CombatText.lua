--- get in-game timestamp in miliseconds
local function getGameTimestamp()
	return getGameTime():getCalender():getTimeInMillis()
end

--- check if attack was critical hit (always false in case of B40)
-- @entity attacker
local function isCriticalHit(entity)
	if luautils.stringStarts(CombatText.gameVersion, "40") then return false
	elseif luautils.stringStarts(CombatText.gameVersion, "41") then return entity:isCriticalHit()
	end
end

local function isNPC(entity)
	if luautils.stringStarts(CombatText.gameVersion, "40") then return false
	elseif luautils.stringStarts(CombatText.gameVersion, "41") then return entity:getIsNPC()
	end
end

local function getHp(entity)
	local hpNow = entity:getHealth() * 100.0F;
	if entity:getObjectName() == "Player" then
		hpNow = entity:getBodyDamage():getHealth()
	end
	return hpNow;
end

--IsoGameCharacter attacker
--IsoGameCharacter target
--HandWeapon weapon
--Float damage split => not actual damage dealt (it is potential weapon dmg, this value is later processed into actual damage)
function onHit(attacker, target, weapon, damage)
	-- only if player attacked zombie
	if ((target:getObjectName() == "Zombie" and attacker:getObjectName() == "Player") or 
		(target:getObjectName() == "Player" and isNPC(target) and attacker:getObjectName() == "Player" and CombatText.HealthBar.ShowOnSurviors)) then
		local uid = CombatText.Fn.getEntityId(target)
		local trackingItm = CombatTextCache.TrackingList[uid];

		local isCrit = isCriticalHit(attacker);
		if trackingItm == nil then
			CombatTextCache.TrackingList[uid] = { 
				fullHp = getHp(target), hp = getHp(target), isDead = target:isDead(), entity = target, 
				isOnFire = false, isBleeding = false, weapon = weapon, isCrit = isCrit, tick = getGameTimestamp() 
			}
			CombatTextCache.TrackingListCount = CombatTextCache.TrackingListCount+1
			trackingItm = CombatTextCache.TrackingList[uid];
		else
			trackingItm.weapon = weapon;
			trackingItm.isCrit = isCriticalHit(attacker);
			trackingItm.tick = getGameTimestamp()
		end
		
		for i,v in pairs(CombatTextCache.HealthBarManagers) do
			if v ~= nil then v:onHit(uid, weapon, isCrit, trackingItm) end
		end
	end
end

--IsoZombie zombie
function onZombieUpdate(zombie)
	local uid = CombatText.Fn.getEntityId(zombie)
	local trackingItm = CombatTextCache.TrackingList[uid];
	
	-- solve on fire problem
	if zombie:isOnFire() and CombatText.FloatingDamage.ShowFireDamage then
		if trackingItm == nil then
			if zombie:getHealth() > 0 then
				CombatTextCache.TrackingList[uid] = { 
					fullHp = zombie:getHealth(), hp = zombie:getHealth(), isDead = zombie:isDead(), entity = zombie, 
					isOnFire = true, isBleeding = false, weapon = nil, isCrit = nil, tick=getGameTimestamp() 
				}
				CombatTextCache.TrackingListCount = CombatTextCache.TrackingListCount+1
			end
		elseif trackingItm.isOnFire ~= true then
			trackingItm.isOnFire = true
		end
	elseif trackingItm ~= nil and trackingItm.isOnFire then
		trackingItm.isOnFire = false
	end
	
	if trackingItm ~= nil and (zombie:isDead() == true or zombie:getHealth() <= 0.0f) then
		-- update existing
		for i,v in pairs(CombatTextCache.HealthBarManagers) do
			if v ~= nil then v:onZombieDead(uid, zombie:isOnFire()) end
		end
	end
end

function onCreatePlayer(idx, player)
	if isNPC(player) == false then
		-- remove if same manager is store => possible after rejoin 
		if CombatTextCache.HealthBarManagers[idx] ~= nil then
			CombatTextCache.HealthBarManagers[idx]:removeFromUIManager();
			CombatTextCache.HealthBarManagers[idx] = nil;
		end
		
		-- update existing
		for i,v in pairs(CombatTextCache.HealthBarManagers) do
			if v ~= nil then v:onNewPlayer() end
		end
		
		-- add new player
		CombatTextCache.HealthBarManagers[idx] = ISHealthBarManager:new(idx, player);
		CombatTextCache.HealthBarManagers[idx]:initialize();
		CombatTextCache.HealthBarManagers[idx]:instantiate();
		CombatTextCache.HealthBarManagers[idx]:addToUIManager();
	end
end

function onZombieDead(zombie)
	local uid = CombatText.Fn.getEntityId(zombie)
	-- update existing
	for i,v in pairs(CombatTextCache.HealthBarManagers) do
		if v ~= nil then v:onZombieDead(uid, zombie:isOnFire()) end
	end
end

function onPlayerDead(player)
	if isNPC(player) and CombatText.HealthBar.ShowOnSurviors then
		local uid = CombatText.Fn.getEntityId(player)
		-- update existing
		for i,v in pairs(CombatTextCache.HealthBarManagers) do
			if v ~= nil then v:onZombieDead(uid, player:isOnFire()) end
		end
	end
end

function onPlayerUpdate(player)
	if isNPC(player) and CombatText.HealthBar.ShowOnSurviors then
		local uid = CombatText.Fn.getEntityId(player)
		local trackingItm = CombatTextCache.TrackingList[uid];
		local isBleeding = player:getBodyDamage():getNumPartsBleeding() > 0;
		
		if isBleeding then
			if trackingItm == nil then
				CombatTextCache.TrackingList[uid] = { 
					fullHp = getHp(player), hp = getHp(player), isDead = player:isDead(), entity = player, 
					isOnFire = false, isBleeding = true, weapon = nil, isCrit = nil, tick=getGameTimestamp() 
				}
				CombatTextCache.TrackingListCount = CombatTextCache.TrackingListCount+1
			elseif trackingItm.isBleeding ~= true then
				trackingItm.isBleeding = true;
			end
		elseif trackingItm ~= nil and trackingItm.isBleeding then
			trackingItm.isBleeding = false;
		end
	end
end

-- splitscreen support
Events.OnCreatePlayer.Add(onCreatePlayer);

-- damage detection
Events.OnWeaponHitCharacter.Add(onHit); -- mark target for tracking and show health bar
Events.OnZombieUpdate.Add(onZombieUpdate); -- serves mainly to detect zombies on fire
Events.OnZombieDead.Add(onZombieDead);

if luautils.stringStarts(getCore():getVersionNumber(), "41") then
	Events.OnCharacterDeath.Add(onPlayerDead);
end

Events.OnPlayerUpdate.Add(onPlayerUpdate);