-- todo: zombies on fire are not showing dmg texts

local print = print
local context = {
	TrackingList = {}, --list of monitored UID's
	rgbMinus = {R=1.0F, G=0.4F, B=0.4F},
	rgbPlus = {R=0.6F, G=1.0F, B=0.6F}
}

function len(tbl)
  local count = 0
  for _ in pairs(tbl) do count = count + 1 end
  return count
end

function updateCached(entity)
	uid = entity:getUID()
	
	if context.TrackingList[uid] ~= nil then
		if entity:isDead() == false then 
			hpNow = entity:getHealth()
			lastHP = contextTrackingList[uid]
			if hpNow ~= lastHP then
				diff = tostring(luautils.round((hpNow - lastHP)*100.0F,0))
				colors = context.rgbMinus
				if hpNow > lastHP then -- heal 
					diff = '+'..diff
					colors = context.rgbPlus
					print(uid..' - lastHP:'..tostring(lastHP)..'|now:'..tostring(hpNow)..'|heal:'..diff)
				else -- damage
					print(uid..' - lastHP:'..tostring(lastHP)..'|now:'..tostring(hpNow)..'|dmg:'..diff)
				end
				
				-- direct use of addLineChatElement instead of Say method to get around restrictions
				-- params:text|R|G|B|font|?messageRadius?|type|allowBBcode|allowImages|allowChatIcons|allowColors|allowFonts|equalizeLineHeights
				entity:addLineChatElement(diff, colors.R, colors.G, colors.B, UIFont.Medium, 90.0F, "radio", true,true,true,true,true,true)
			end
		else
			print(uid..' - dead')
		end
		context.TrackingList[uid] = nil
	end
end

--IsoGameCharacter attacker
--IsoGameCharacter target
--HandWeapon weapon
--Float damage split => not actual damage dealt (it is potential weapon dmg, this value is later processed into actual damage)
function onHit(attacker, target, weapon, damage)
	uid = target:getUID()
	ttype = target:getObjectName()
	
	if ttype == "Zombie" or ttype == "Player" or ttype == "Survivor" then
		if target:isDead() then
			if context[ttype..'List'][uid] ~= nil then
				context[ttype..'List'][uid] = nil
				print(ttype..' - '..uid..' - removed from watchlist, reason:dead')
			end
		else
			if context[ttype..'List'][uid] == nil then
				context[ttype..'List'][uid] = target:getHealth()
				print(ttype..' - '..uid..' - added to watchlist, reason:hit')
			else
				print(ttype..' - '..uid..' - still in watchlist, reason:hit')
			end
		end
		print(ttype..' watch count:'..tostring(len(context[ttype..'List'])))
	end
end

--IsoZombie zombie
function onZombieUpdate(zombie)
	updateCached(zombie)
end
--IsoZombie zombie
function onZombieKilled(zombie)
	updateCached(zombie)
end

--IsoSurvivor survior
function onSurviorUpdate(survior)
	updateCached(survior)
end

--IsoPlayer player
function onPlayerUpdate(player)
	updateCached(player)
end
--IsoPlayer player
function onPlayerKilled(player)
	updateCached(player)
end


function onBoot()
	-- unregister first
	Events.OnWeaponHitCharacter.Remove(onHit)
	Events.OnZombieUpdate.Remove(onZombieUpdate)
	Events.OnPlayerUpdate.Remove(onPlayerUpdate)
	Events.OnNPCSurvivorUpdate.Remove(onSurviorUpdate)
	Events.OnZombieDead.Remove(onZombieKilled)
	Events.OnPlayerDeath.Remove(onPlayerKilled)
	
	-- register events
	Events.OnWeaponHitCharacter.Add(onHit) --occurs before lowering target's health => store UID and current health which is used later in OnZombieUpdate|OnPlayerUpdate|OnNPCSurvivorUpdate events to determine "damage done"
	Events.OnZombieUpdate.Add(onZombieUpdate) --occurs during every zombie update => check if we have tracking UID (we got hit) and show health change
	Events.OnPlayerUpdate.Add(onPlayerUpdate) --occurs during every player update => check if we have tracking UID (we got hit) and show health change
	Events.OnNPCSurvivorUpdate.Add(onSurviorUpdate) --occurs during every NPC update => check if we have tracking UID (we got hit) and show health change
	Events.OnZombieDead.Add(onZombieKilled)
	Events.OnPlayerDeath.Add(onPlayerKilled)
	
	print('GameBoot - event registration finished')
end

Events.OnGameBoot.Add(onBoot)
