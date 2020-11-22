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
		Font = "Small",
		Position = "out-top-right" --[[
			out-top | out-right | out-left | out-bottom
			out-top-left | out-top-right
			out-bottom-left | out-bottom-right
		]]--
	},
	FloatingDamage = {
		Visible = true,
		Ttl = 2000,
		Speed = 75.0F,
		FireDmgUpdate = 5000,
		NormalFont = "Medium",
		CritFont = "Large",
		RgbMinus = {r=1.0, g=0.4, b=0.4, a=1.0},
		RgbPlus = {r=0.6, g=1.0, b=0.6, a=1.0},
		RgbOnFire = {r=0.8, g=0.55, b=0.0, a=1.0},
		Background = {r=0, g=0, b=0, a=0.15}
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
