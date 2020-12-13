CombatTextCache = {
	-- init objects with prefilled later used structure should help lua to better manage object content
	HealthBarManagers = {
	}, -- list of managers => one per player
	TrackingList = {
		init = { fullHp = 0, hp = 0, isDead = true, entity = nil, isOnFire = false, weapon = nil, isCrit = nil, tick=-1 }
	}, --list of monitored UID's
	TrackingListCount = 0
}

function clearInit()
	CombatTextCache.HealthBarManagers = {};
	CombatTextCache.TrackingList['init'] = nil;
	CombatTextCache.TrackingListCount = 0;
end

Events.OnGameBoot.Add(clearInit)