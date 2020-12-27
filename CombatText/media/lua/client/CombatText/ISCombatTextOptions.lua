require ("CombatTextBase.lua")
require ("HorizontalLine")
require ("ISLabel")
require ("ISButton")

local FONT_HGT_SMALL = getTextManager():getFontHeight(UIFont.Small)
local FONT_HGT_MEDIUM = getTextManager():getFontHeight(UIFont.Medium)
local ALL_FONT_LIST = {'Small', 'Medium', 'Large', 'Massive', 'MainMenu1', 'MainMenu2', 'Cred1', 'Cred2', 'NewSmall', 'NewMedium', 'NewLarge', 'Code', 'MediumNew', 'AutoNormSmall', 'AutoNormMedium', 'AutoNormLarge', 'Dialogue', 'Intro', 'Handwritten', 'DebugConsole', 'Title'}
local TAB_NAME = 'COMBAT TEXT'

local function translationName(name)
	return name;
end

local function optionName(name)
	return name;
end

local function getObjectVal(root, name)
	local current = root
	for w in string.gmatch(name, '([^_]+)') do
		current = current[w]
	end
	return current;
end

local function setObjectVal(root, name, value)
	local current = nil
	local key = nil;
	for w in string.gmatch(name, '([^_]+)') do
		if key == nil and current == nil then
			current = root;
		else
			current = current[key]
		end
		key = w;
	end
	current[key] = value;
end

local function getFontOptions()
	result = {};
	
	for _, fnt in ipairs(ALL_FONT_LIST) do
		if UIFont.FromString(fnt) ~= nil then table.insert(result, fnt); end
	end
	
	return result;
end

local function getPositionOptions()
	return {'out-top', 'out-right', 'out-left', 'out-bottom', 'out-top-left', 'out-top-right', 'out-bottom-left', 'out-bottom-right'}
end

local function getSelectedIndex(options, selected)
	for idx,val in ipairs(options) do
		if val == selected then return idx; end
	end
end

--************************************************************************--
--** GameOption
--************************************************************************--

local GameOption = ISBaseObject:derive("GameOption")

function GameOption:new(name, control, arg1, arg2)
	local o = {}
	setmetatable(o, self)
	self.__index = self
	o.name = name
	o.control = control
	o.arg1 = arg1
	o.arg2 = arg2
	if control.isCombobox then
		control.onChange = self.onChangeComboBox
		control.target = o
	end
	if control.isTickBox then
		control.changeOptionMethod = self.onChangeTickBox
		control.changeOptionTarget = o
	end
	if control.isSlider then
		control.targetFunc = self.onChangeVolumeControl
		control.target = o
	end
	return o
end

function GameOption:toUI()
	print('ERROR: option "'..self.name..'" missing toUI()')
end

function GameOption:apply()
	print('ERROR: option "'..self.name..'" missing apply()')
end

function GameOption:onChangeComboBox(box)
	self.gameOptions:onChange(self)
	if self.onChange then
		self:onChange(box)
	end
end

function GameOption:onChangeTickBox(index, selected)
	self.gameOptions:onChange(self)
	if self.onChange then
		self:onChange(index, selected)
	end
end

function GameOption:onChangeVolumeControl(control, volume)
	self.gameOptions:onChange(self)
	if self.onChange then
		self:onChange(control, volume)
	end
end

--************************************************************************--
--** HorizontalLine
--************************************************************************--

local HorizontalLine = ISPanel:derive("HorizontalLine")

function HorizontalLine:prerender()
end

function HorizontalLine:render()
	self:drawRect(0, 0, self.width, 1, 1.0, 0.5, 0.5, 0.5)
end

function HorizontalLine:new(x, y, width)
	local o = ISPanel.new(self, x, y, width, 2)
	return o
end

--************************************************************************--
--** MainOptions extension
--************************************************************************--

local oldCreate = MainOptions.create
local oldApply = MainOptions.apply

function onSliderChange(target, _newVal, _slider)
	_slider.label:setName(tostring(_newVal))
	setChanged(target);
end

function onResetClick(target, _self)
	CombatText[_self._cfgName] = CombatText.Fn.mergeCfgData(CombatText[_self._cfgName], CombatTextDefault[_self._cfgName]);
	target.gameOptions.changed = true
	for _,option in ipairs(target.gameOptions.options) do
		option:toUI()
	end
end

function setChanged(target)
	target.gameOptions.changed = true
end

function rgbColorPicker(target, color, mouseUp)
    target.backgroundColor = { r=color.r, g=color.g, b=color.b, a = 1 }
    local gameOptions = MainOptions.instance.gameOptions
    gameOptions:onChange()
end

function rgbPickerBtnClick(target, _self)
	_self.colorPicker2:setX(100)
    _self.colorPicker2:setY(100)
    
    local colorInfo = ColorInfo.new(_self.backgroundColor.r, _self.backgroundColor.g, _self.backgroundColor.b, 1)
    _self.colorPicker2:setInitialColor(colorInfo);
    target:addChild(_self.colorPicker2)
    _self.colorPicker2:setVisible(true);
    _self.colorPicker2:bringToTop();
end

function MainOptions:addSlider(x, y, w, h, name, min, max, step)
	local fontHgt = FONT_HGT_SMALL
	local value = getObjectVal(CombatText, name)

	local label = ISLabel:new(x, y + self.addY, fontHgt, getText('UI_CT_options_'..translationName(name)), 1, 1, 1, 1, UIFont.Small);
	label:initialise();
	self.mainPanel:addChild(label);
	
	local currentVal = ISLabel:new(x+20+w+5, y + self.addY, fontHgt, tostring(value), 1, 1, 1, 1, UIFont.Small, true);
	currentVal:initialise();
	self.mainPanel:addChild(currentVal);
	
	local panel2 = ISSliderPanel:new(x+20, y + self.addY + (math.max(fontHgt, h) - h) / 2, w, h, self, onSliderChange);
	panel2:initialise();
	panel2.label = currentVal;
	panel2.ct_onChange = onchange;
	
	panel2:setValues(min, max, step, step);
	panel2:setCurrentValue(value);
	panel2.selected = selected;
	panel2.default = selected;

	self.mainPanel:addChild(panel2);
	
	self.mainPanel:insertNewLineOfButtons(panel2)
	self.addY = self.addY + math.max(fontHgt, h) + 6;
	
	local gameOp = GameOption:new(optionName(name), panel2);
	gameOp._cfgName = name;
	function gameOp.toUI(self) 
		self.control:setCurrentValue(getObjectVal(CombatText, self._cfgName)); 
	end
	function gameOp.apply(self) 
		setObjectVal(CombatText, self._cfgName, self.control:getCurrentValue());
	end
	self.gameOptions:add(gameOp)
end

function MainOptions:addCheckBox(x, y, w, h, name)
	if luautils.stringStarts(CombatText.gameVersion, "40") then
		local cb = self:addCombo(x, y, w, h, getText('UI_CT_options_'..translationName(name)), {getText("UI_Yes"), getText("UI_No")}, getObjectVal(CombatText, name), self, setChanged)
		
		local cbGameOp = GameOption:new(optionName(name), cb)
		cbGameOp._cfgName = name;
		function cbGameOp.toUI(self)
			if getObjectVal(CombatText, self._cfgName) then
				self.control.selected = 1
			else
				self.control.selected = 2
			end
		end
		function cbGameOp.apply(self) 
			setObjectVal(CombatText, self._cfgName, self.control.selected == 1);
		end
		self.gameOptions:add(cbGameOp)
	
	else
		local yesNo = self:addYesNo(x, y, w, h, getText('UI_CT_options_'..translationName(name)))
		yesNo.changeOptionMethod = setChanged
		yesNo.changeOptionTarget = self;
		
		local gameOp = GameOption:new(optionName(name), yesNo)
		gameOp._cfgName = name;
		function gameOp.toUI(self) 
			self.control:setSelected(1, getObjectVal(CombatText, self._cfgName)); 
		end
		function gameOp.apply(self) 
			setObjectVal(CombatText, self._cfgName, self.control:isSelected(1));
		end
		self.gameOptions:add(gameOp)
	end
end

function MainOptions:rgbaColorPicker(x, y, w, h, name)
	local fontHgt = FONT_HGT_SMALL
	local rgba = getObjectVal(CombatText, name)
	local nx = x+20;
	local ox = 0

	local rgbLabel = ISLabel:new(nx+ox, y + self.addY, fontHgt, 'RGB:', 1, 1, 1, 1, UIFont.Small, true);
	rgbLabel:initialise();
	self.mainPanel:addChild(rgbLabel);
	ox = ox + rgbLabel.width+5;

	local highlightHgt = math.max(fontHgt, 15 + 4)
    local objHighColor = ISButton:new(nx+ox, y + self.addY + (highlightHgt - 15) / 2, 15, 15,"", self, rgbPickerBtnClick);
    objHighColor:initialise();
    objHighColor.backgroundColor = { r=rgba.r, g=rgba.g, b=rgba.b, a = 1 };
	
	ox = ox + objHighColor.width + 10
	local label = ISLabel:new(x, y + self.addY, fontHgt, getText('UI_CT_options_'..translationName(name)), 1, 1, 1, 1, UIFont.Small);
	label:initialise();

    objHighColor.colorPicker2 = ISColorPicker:new(0, 0)
    objHighColor.colorPicker2:initialise()
    objHighColor.colorPicker2.pickedTarget = objHighColor
	objHighColor.colorPicker2.pickedFunc = rgbColorPicker;
    objHighColor.colorPicker2.resetFocusTo = self
    objHighColor.colorPicker2:setInitialColor(ColorInfo.new(rgba.r, rgba.g, rgba.b, 1));

	local currentVal = ISLabel:new(x+w+25, y + self.addY, fontHgt, tostring(rgba.a), 1, 1, 1, 1, UIFont.Small, true);
	currentVal:initialise();

    self.mainPanel:addChild(objHighColor);
	self.mainPanel:addChild(label);
	self.mainPanel:addChild(currentVal);
	
	local aLabel = ISLabel:new(nx+ox, y + self.addY, fontHgt, 'A:', 1, 1, 1, 1, UIFont.Small, true);
	aLabel:initialise();
	self.mainPanel:addChild(aLabel);
	ox = ox + aLabel.width+5;
	
	local panel2 = ISSliderPanel:new(nx+ox, y + self.addY + (math.max(fontHgt, h) - h) / 2, w-ox, h, self, onSliderChange);
	panel2:initialise();
	panel2.label = currentVal;
	panel2.ct_onChange = onchange;
	
	panel2:setValues(0, 1, 0.01, 0.01);
	panel2:setCurrentValue(rgba.a);
	panel2.selected = selected;
	panel2.default = selected;

	self.mainPanel:addChild(panel2);
	self.mainPanel:insertNewLineOfButtons(panel2)
	self.addY = self.addY + math.max(fontHgt, h) + 6;

    gameOption = GameOption:new(optionName(name), objHighColor)
	gameOption._cfgName = name;
	gameOption._alpha = panel2;
    function gameOption.toUI(self)
		local clr = getObjectVal(CombatText, self._cfgName);
        self.control.backgroundColor = { r=clr.r, g=clr.g, b=clr.b, a = 1 };
		self._alpha:setCurrentValue(clr.a);
    end
    function gameOption.apply(self)
        local current = self.control.backgroundColor
        setObjectVal(CombatText, self._cfgName, {r=current.r,g=current.g,b=current.b,a=self._alpha:getCurrentValue()});
		CombatText.needSave = true;
		self.gameOptions.changed = true;
    end
    self.gameOptions:add(gameOption)
end

function MainOptions:addHLineWithName(name)
	local hLine = HorizontalLine:new(50, self.addY - 8, self.width - 50 * 2)
	hLine.anchorRight = true
	self.mainPanel:addChild(hLine)
	local label = ISLabel:new(100, self.addY, FONT_HGT_MEDIUM, getText('UI_CT_options_'..name..'_Title'), 1, 1, 1, 1, UIFont.Medium);
	label:setX(50);
	label:initialise();
	label:setAnchorRight(true);
	
	local reset = ISButton:new(label.x+label.width+10, self.addY, 100, FONT_HGT_MEDIUM, getText('UI_CT_options_ResetBtn'), self);
	reset._cfgName = name;
	reset.onclick = onResetClick;
    reset:initialise();

    self.mainPanel:addChild(reset);	
	self.mainPanel:addChild(label);
	self.addY = self.addY + FONT_HGT_MEDIUM + 10;
end

function MainOptions:addSelect(x, y, w, h, name, options)
	local combo = self:addCombo(x, y, w, h, getText('UI_CT_options_'..translationName(name)), options, getSelectedIndex(options, getObjectVal(CombatText, name)), self, setChanged)
	
	local gameOp = GameOption:new(optionName(name), combo)
	gameOp._cfgName = name;
	function gameOp.toUI(self)
		self.control.selected = getSelectedIndex(self.control.options, getObjectVal(CombatText, self._cfgName));
	end
	function gameOp.apply(self) 
		setObjectVal(CombatText, self._cfgName, self.control.options[self.control.selected]);
	end
	self.gameOptions:add(gameOp)
end

local function hasView(_self, name)
	return _self.tabs:getView(name) ~= nil
end

function OptionsProtected(_self)
	if not hasView(_self, TAB_NAME) then
		_self:addPage(TAB_NAME);
		_self.addY = 20;
		local splitpoint = _self:getWidth() / 3;
		local comboWidth = 300;

		---- HealthBar ----
		_self:addHLineWithName('HealthBar');
		_self:addCheckBox(splitpoint, 0, comboWidth, 20, 'HealthBar_Visible');
		_self:addSlider(splitpoint, 0, comboWidth, 20, 'HealthBar_Width', 25, 125, 5);
		_self:addSlider(splitpoint, 0, comboWidth, 20, 'HealthBar_Height', 1, 25, 1);
		_self:addSlider(splitpoint, 0, comboWidth, 20, 'HealthBar_YOffset', 50, 250, 5);
		_self:addSlider(splitpoint, 0, comboWidth, 20, 'HealthBar_Padding', 1, 10, 1);
		_self:rgbaColorPicker(splitpoint, 0, comboWidth, 20, 'HealthBar_Colors_Background');
		_self:rgbaColorPicker(splitpoint, 0, comboWidth, 20, 'HealthBar_Colors_Border');
		_self:rgbaColorPicker(splitpoint, 0, comboWidth, 20, 'HealthBar_Colors_CurrentHealth');
		_self:rgbaColorPicker(splitpoint, 0, comboWidth, 20, 'HealthBar_Colors_LoosingHealth');
		_self:addSlider(splitpoint, 0, comboWidth, 20, 'HealthBar_LoosingHpTick', 100, 500, 50);
		_self:addSlider(splitpoint, 0, comboWidth, 20, 'HealthBar_FadeOutAfter', 100, 1000, 100);
		_self:addSlider(splitpoint, 0, comboWidth, 20, 'HealthBar_HideWhenInactive_distanceMoreThan', 1, 20, 1);
		_self:addSlider(splitpoint, 0, comboWidth, 20, 'HealthBar_HideWhenInactive_noDamageFor', 1000, 30*60*1000, 1000);

		---- FloatingDamage ----
		_self.addY = _self.addY+20;
		_self:addHLineWithName('FloatingDamage');
		_self:addCheckBox(splitpoint, 0, comboWidth, 20, 'FloatingDamage_Visible');
		_self:addSlider(splitpoint, 0, comboWidth, 20, 'FloatingDamage_Ttl', 500, 5000, 100);
		_self:addSlider(splitpoint, 0, comboWidth, 20, 'FloatingDamage_Speed', 25, 125, 5);
		_self:addSlider(splitpoint, 0, comboWidth, 20, 'FloatingDamage_FireDmgUpdate', 1000, 10000, 100);
		_self:addSelect(splitpoint, 0, comboWidth, 20, 'FloatingDamage_NormalFont', getFontOptions());
		_self:addSelect(splitpoint, 0, comboWidth, 20, 'FloatingDamage_CritFont', getFontOptions());
		_self:rgbaColorPicker(splitpoint, 0, comboWidth, 20, 'FloatingDamage_RgbMinus');
		_self:rgbaColorPicker(splitpoint, 0, comboWidth, 20, 'FloatingDamage_RgbPlus');
		_self:rgbaColorPicker(splitpoint, 0, comboWidth, 20, 'FloatingDamage_RgbOnFire');
		_self:rgbaColorPicker(splitpoint, 0, comboWidth, 20, 'FloatingDamage_Background');

		---- CurrentTotalHp ----
		_self.addY = _self.addY+20;
		_self:addHLineWithName('CurrentTotalHp');
		_self:addCheckBox(splitpoint, 0, comboWidth, 20, 'CurrentTotalHp_Visible');
		_self:addSlider(splitpoint, 0, comboWidth, 20, 'CurrentTotalHp_ShowBelowZoom', 0.5, 2, 0.25);
		_self:rgbaColorPicker(splitpoint, 0, comboWidth, 20, 'CurrentTotalHp_Color');
		_self:addSelect(splitpoint, 0, comboWidth, 20, 'CurrentTotalHp_Font', getFontOptions());
		_self:addSelect(splitpoint, 0, comboWidth, 20, 'CurrentTotalHp_Position', getPositionOptions());

		_self.mainPanel:setScrollHeight(_self.addY + 50);
		if luautils.stringStarts(CombatText.gameVersion, "40") == false then
			_self:centerTabChildrenX(TAB_NAME);
		end
	end
end

function SaveProtected(_self)
	CombatText.Fn.saveSettings();
end

function MainOptions:create()
	oldCreate(self);
	local status, err = pcall(OptionsProtected, self);
	if not status then
		print('pcall error')
	end
end

function MainOptions:apply(closeAfter)
	oldApply(self, closeAfter)
	local status, err = pcall(SaveProtected, self);
	if not status then
		print('pcall error')
	end
end
