CombatText = {
	gameVersion = getCore():getVersionNumber(),
	Fn = {
		measureStringX = function(font, text) return getTextManager():MeasureStringX(font, text) end,
		measureStringY = function(font, text) return getTextManager():MeasureStringY(font, text) end
	},
	FontHeights = {
		Small = getTextManager():getFontHeight(UIFont.Small),
		Medium = getTextManager():getFontHeight(UIFont.Medium),
		Large = getTextManager():getFontHeight(UIFont.Large)
	},
	
	HealthBar = {
		Visible = true,
		Width = 75.0F,
		Height = 5.0F,
		YOffset = 125,
		Padding = 2,
		Colors = {
			Background = {r=0, g=0, b=0, a=0.5},
			Border = {r=0.4, g=0.4, b=0.4, a=1},
			CurrentHealth = {r=0.8, g=0, b=0, a=1},
			LoosingHealth = {r=1.0, g=0.5, b=0, a=1}
		},
		LoosingHpTick = 250,
		FadeOutAfter = 500,
		HideWhenInactive = {
			distanceMoreThan = 20,
			noDamageFor = 10*60*1000 --ingame time in ms
		}
	},
	CurrentTotalHp = {
		Visible = false,
		Color = {r=1, g=1, b=1, a=1},
		Position = "out-top" --[[
			out-top | out-right | out-left | out-bottom
			in-left | in-center | in-right
		]]--
	},
	FloatingDamage = {
		Visible = true,
		Ttl = 2000,
		Speed = 75.0F,
		FireDmgUpdate = 5000,
		RgbMinus = {r=1.0D, g=0.4D, b=0.4D, a=1.0D},
		RgbPlus = {r=0.6D, g=1.0D, b=0.6D, a=1.0D},
		RgbOnFire = {r=0.8D, g=0.55D, b=0.0D, a=1.0D},
	}
}

CombatText.Fn.getEntityId = function(entity)
	if luautils.stringStarts(CombatText.gameVersion, "40") then return entity:getID()
	elseif luautils.stringStarts(CombatText.gameVersion, "41") then return entity:getUID()
	end
end

CombatText.Fn.getTargetAlpha = function(entity, playerIndex)
	if entity == nil then return 0 end

	if luautils.stringStarts(CombatText.gameVersion, "40") then return entity:getTargetAlpha()
	elseif luautils.stringStarts(CombatText.gameVersion, "41") then return entity:getTargetAlpha(playerIndex)
	end
end
