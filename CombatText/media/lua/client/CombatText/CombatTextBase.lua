CombatText = {
	gameVersion = getCore():getVersionNumber(),
	Fn = {
		measureStringX = function(font, text) return getTextManager():MeasureStringX(font, text) end,
		measureStringY = function(font, text) return getTextManager():MeasureStringY(font, text) end,
		fontHeight = function(fontStr) return getTextManager():getFontHeight(UIFont.FromString(fontStr)) end,
		getSettingsFileName = function() return 'CombatText\\settings.lua.cfg' end
	},
	defaultCfg = { HealthBar = {}, CurrentTotalHp = {}, FloatingDamage = {} },
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
		Background = {r=0, g=0, b=0, a=0.2}
	}
}

CombatText.Fn.getEntityId = function(entity)
	if entity == nil then return nil end

	if luautils.stringStarts(CombatText.gameVersion, "40") then return entity:getID()
	elseif luautils.stringStarts(CombatText.gameVersion, "41") then return entity:getUID()
	end
end

CombatText.Fn.getAlpha = function(entity, playerIndex)
	if entity == nil then return 0 end

	if luautils.stringStarts(CombatText.gameVersion, "40") then return entity:getTargetAlpha()
	elseif luautils.stringStarts(CombatText.gameVersion, "41") then return entity:getAlpha(playerIndex)
	end
end

--- simple key in table count
CombatText.Fn.countKeys = function(tbl)
	local n = 0
    for k,v in pairs(tbl) do
        n = n + 1
    end
    return n
end

--- recursive config merge
CombatText.Fn.mergeCfgData = function(currentData, localData)
	if localData == nil then return currentData end
	if currentData == nil then currentData = {} end
	
	if type(currentData) == 'table' then
		for ck,cv in pairs(currentData) do
			currentData[ck] = CombatText.Fn.mergeCfgData(cv, localData[ck])
		end
	else
		return localData
	end
	
	return currentData
end

--- recursive object write
CombatText.Fn.writeObject = function(writer, key, value, isLast, spaces)
	if type(value) == 'table' then
		writer:writeln(spaces..key..'={')
		local tblSize = countKeys(value)
		local idx = 1
		for tk,tv in pairs(value) do
			CombatText.Fn.writeObject(writer, tk, tv, idx==tblSize, spaces..'\t')
			idx = idx+1;
		end
		if isLast then writer:writeln(spaces..'}')
		else writer:writeln(spaces..'},') end
	else
		if value ~= nil then
			writer:write(spaces..key..'=')
			local vtype = type(value)
			if vtype == 'string' then writer:write('\''..value..'\'')
			else writer:write(tostring(value)) end
			if isLast == false then writer:write(',') end
			writer:writeln('')
		end
	end
end


CombatText.Fn.saveSettings = function()
	--FileOutputStream getFileWriter([string] filename, [bool] createIfNotExists, [bool] append)
	local writer = getFileWriter(CombatText.Fn.getSettingsFileName(), true, false)
	
	-- simplest was is to store config and prepare it to be called as function
	writer:writeln('CombatTextOptions={}')
	CombatText.Fn.writeObject(writer, 'CombatTextOptions.HealthBar', CombatText.HealthBar, true, '')
	CombatText.Fn.writeObject(writer, 'CombatTextOptions.CurrentTotalHp', CombatText.CurrentTotalHp, true, '')
	CombatText.Fn.writeObject(writer, 'CombatTextOptions.FloatingDamage', CombatText.FloatingDamage, true, '')
	writer:writeln('return CombatTextOptions');
	writer:close()
end

CombatText.Fn.loadSettings = function()
	--BufferedReader getFileReader([string] filename, [bool] createIfNotExists)
	local reader = getFileReader(CombatText.Fn.getSettingsFileName(), false)
	if reader == nil then return; end
	local cfgData = '';
	local isEof = false;
	repeat
		line = reader:readLine();
		if line == nil then isEof = true
		else cfgData = cfgData..line..'\r\n' end
	until isEof ~= false
	reader:close();
	
	-- read store data and call it as function
	local cfgLua = loadstring(cfgData);
	if cfgLua == nil then return; end
	local localCfgData = cfgLua();
	
	-- merge only expected objects
	CombatText.HealthBar = CombatText.Fn.mergeCfgData(CombatText.HealthBar, localCfgData.HealthBar);
	CombatText.CurrentTotalHp = CombatText.Fn.mergeCfgData(CombatText.CurrentTotalHp, localCfgData.CurrentTotalHp);
	CombatText.FloatingDamage = CombatText.Fn.mergeCfgData(CombatText.FloatingDamage, localCfgData.FloatingDamage);

end

function onGameBoot()
	-- create backup of default
	--CombatText.defaultCfg.HealthBar = CombatText.Fn.mergeCfgData(CombatText.defaultCfg.HealthBar, CombatText.HealthBar);
	--CombatText.defaultCfg.CurrentTotalHp = CombatText.Fn.mergeCfgData(CombatText.defaultCfg.CurrentTotalHp, CombatText.CurrentTotalHp);
	--CombatText.defaultCfg.FloatingDamage = CombatText.Fn.mergeCfgData(CombatText.defaultCfg.FloatingDamage, CombatText.FloatingDamage);

	-- load config
	--CombatText.Fn.loadSettings()
end

--Events.OnGameBoot.Add(onGameBoot)
