require "ISUI/ISPanel"
require "ISUI/ISContextMenu"
require ("CombatTextBase.lua")

ISCombatTextOptions = ISPanel:derive("ISCombatTextOptions")

ISCombatTextOptions.showCtxMenu = function(panel, x, y)
	ctx = ISContextMenu.get(panel.playerIndex, panel.x, panel.top, 1, 1)
	ctx.anchorTop = false;
	ctx.anchorBottom = true;
	ctx:setFont(panel.font);
	ctx:addOption("--test--")
end

function ISCombatTextOptions:initialise()
	ISPanel.initialise(self);
end

function ISCombatTextOptions:setVisible(visible)
	self.javaObject(visible);
end

function ISCombatTextOptions:render()
	self:drawTextCentre(self.text, self.centerX, self.centerY, 1,1,1,1, self.font)
	
	if self.tooltip.show then
		self:drawRect(self.tooltip.box.x, self.tooltip.box.y, self.tooltip.box.width, self.tooltip.box.height, self.tooltip.backgroundColor.a, self.tooltip.backgroundColor.r, self.tooltip.backgroundColor.g, self.tooltip.backgroundColor.b)
		self:drawRectBorder(self.tooltip.box.x, self.tooltip.box.y, self.tooltip.box.width, self.tooltip.box.height, self.tooltip.borderColor.a, self.tooltip.borderColor.r, self.tooltip.borderColor.g, self.tooltip.borderColor.b)
		self:drawText(self.tooltip.text, self.tooltip.x, self.tooltip.y, self.tooltip.color.r, self.tooltip.color.g, self.tooltip.color.b, self.tooltip.color.a, self.tooltip.font)
	
	end
end

function ISCombatTextOptions:onMouseMove(dx, dy)
	self.tooltip.show = true;
end

function ISCombatTextOptions:onMouseMoveOutside(dx, dy)
	self.tooltip.show = false
end

function ISCombatTextOptions:onRightMouseDown(x, y)
	ISPanel.onRightMouseDown(self, x, y)
	self.rightMouseDown = true
end

function ISCombatTextOptions:onRightMouseUp(dx, dy)
	ISPanel.onRightMouseUp(self, dx, dy)
	if self.rightMouseDown == true then 
		self.tooltip.show = false;
		ISCombatTextOptions.showCtxMenu(self, dx, dy);
	end
	self.rightMouseDown = false
end

function ISCombatTextOptions:new(playerIndex, player, x, y, width, height)
	local o = {};
    o = ISPanel:new(x, y, width, height);
    setmetatable(o, self);
    self.__index = self;
	
	o.text = "CT"
	o.font = UIFont.Small
	o.centerX = width/2;
	o.centerY = height/2 - CombatText.Fn.measureStringX(o.font, o.text)/2;
	o.playerIndex = playerIndex;
	o.player = player;
	
	o.tooltip = {
		show = false,
		text = "CombatText options",
		font = UIFont.Small,
		padding = 2,
		color = {r=1, g=1, b=1, a=1},
		backgroundColor = {r=0, g=0, b=0, a=0.5},
		borderColor = {r=0.4, g=0.4, b=0.4, a=1}
	}
	o.tooltip.box = {
		width = CombatText.Fn.measureStringX(o.tooltip.font, o.tooltip.text)+o.tooltip.padding*2,
		height = CombatText.Fn.measureStringY(o.tooltip.font, o.tooltip.text)+o.tooltip.padding*2,
	}
	o.tooltip.x = o.tooltip.padding
	o.tooltip.y = -o.tooltip.box.height
	o.tooltip.box.x = 0;
	o.tooltip.box.y = o.tooltip.y-o.tooltip.padding;
	
	o.top = y-height-o.tooltip.padding;
	
    ISCombatTextOptions.instance = o
    return o;
end

--Integer idx => The player's PlayerIndex
--IsoPlayer player => which was created
function onCreatePlayer(idx, player)
	width = 25
	height = 25
	x = 5;
	y = getCore():getScreenHeight() - height -5;
	
	local opener = ISCombatTextOptions:new(idx, player, x, y, width, height)
	opener:initialise();
    opener:addToUIManager();
end

--Events.OnCreatePlayer.Add(onCreatePlayer)
