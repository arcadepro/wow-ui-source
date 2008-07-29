
PowerBarColor = {};
PowerBarColor["MANA"] = { r = 0.00, g = 0.00, b = 1.00 };
PowerBarColor["RAGE"] = { r = 1.00, g = 0.00, b = 0.00 };
PowerBarColor["FOCUS"] = { r = 1.00, g = 0.50, b = 0.25 };
PowerBarColor["ENERGY"] = { r = 1.00, g = 1.00, b = 0.00 };
PowerBarColor["HAPPINESS"] = { r = 0.00, g = 1.00, b = 1.00 };
PowerBarColor["RUNES"] = { r = 0.50, g = 0.50, b = 0.50 };
PowerBarColor["RUNIC_POWER"] = { r = 0.00, g = 0.82, b = 1.00 };
-- vehicle colors
PowerBarColor["AMMOSLOT"] = { r = 0.80, g = 0.60, b = 0.00 };
PowerBarColor["FUEL"] = { r = 0.0, g = 0.55, b = 0.5 };

-- these are mostly needed for a fallback case, in case the code tries to index a power token above is missing from the table
PowerBarColor[0] = PowerBarColor["MANA"];
PowerBarColor[1] = PowerBarColor["RAGE"];
PowerBarColor[2] = PowerBarColor["FOCUS"];
PowerBarColor[3] = PowerBarColor["ENERGY"];
PowerBarColor[4] = PowerBarColor["HAPPINESS"];
PowerBarColor[5] = PowerBarColor["RUNES"];
PowerBarColor[6] = PowerBarColor["RUNIC_POWER"];

--[[
	This system uses "update" functions as OnUpdate, and OnEvent handlers.
	This "Initialize" function registers the events to handle.
	The "update" function is set as the OnEvent handler (although they do not parse the event),
	as well as run from the parent's update handler.

	TT: I had to make the spellbar system differ from the norm.
	I needed a seperate OnUpdate and OnEvent handlers. And needed to parse the event.
]]--

function UnitFrame_Initialize (self, unit, name, portrait, healthbar, healthtext, manabar, manatext)
	self.unit = unit;
	self.name = name;
	self.portrait = portrait;
	self.healthbar = healthbar;
	self.manabar = manabar;
	UnitFrameHealthBar_Initialize(unit, healthbar, healthtext);
	UnitFrameManaBar_Initialize(unit, manabar, manatext);
	UnitFrame_Update(self);
	self:RegisterForClicks("LeftButtonUp", "RightButtonUp");
	self:RegisterEvent("UNIT_NAME_UPDATE");
	self:RegisterEvent("UNIT_PORTRAIT_UPDATE");
	self:RegisterEvent("UNIT_DISPLAYPOWER");
end

function UnitFrame_SetUnit (self, unit, healthbar, manabar)
	self.unit = unit;
	healthbar.unit = unit;
	manabar.unit = unit;
	self:SetAttribute("unit", unit);
	UnitFrame_Update(self);
end

function UnitFrame_Update (self)
	self.name:SetText(GetUnitName(self.unit));
	SetPortraitTexture(self.portrait, self.unit);
	UnitFrameHealthBar_Update(self.healthbar, self.unit);
	UnitFrameManaBar_Update(self.manabar, self.unit);
end

function UnitFrame_OnEvent(self, event, ...)
	local arg1 = ...
	
	local unit = self.unit;
	if ( event == "UNIT_NAME_UPDATE" ) then
		if ( arg1 == unit ) then
			self.name:SetText(GetUnitName(unit));
		end
	elseif ( event == "UNIT_PORTRAIT_UPDATE" ) then
		if ( arg1 == unit ) then
			SetPortraitTexture(self.portrait, unit);
		end
	elseif ( event == "UNIT_DISPLAYPOWER" ) then
		if ( arg1 == unit ) then
			UnitFrame_UpdateManaType(self);
		end
	end
end

function UnitFrame_OnEnter (self)
	-- If showing newbie tips then only show the explanation
	if ( SHOW_NEWBIE_TIPS == "1" ) then
		if ( self == PlayerFrame ) then
			GameTooltip_SetDefaultAnchor(GameTooltip, self);
			GameTooltip_AddNewbieTip(self, PARTY_OPTIONS_LABEL, 1.0, 1.0, 1.0, NEWBIE_TOOLTIP_PARTYOPTIONS);
			return;
		elseif ( self == TargetFrame and UnitPlayerControlled("target") and not UnitIsUnit("target", "player") and not UnitIsUnit("target", "pet") ) then
			GameTooltip_SetDefaultAnchor(GameTooltip, self);
			GameTooltip_AddNewbieTip(self, PLAYER_OPTIONS_LABEL, 1.0, 1.0, 1.0, NEWBIE_TOOLTIP_PLAYEROPTIONS);
			return;
		end
	end
	UnitFrame_UpdateTooltip(self);
end

function UnitFrame_OnLeave ()
	if ( SHOW_NEWBIE_TIPS == "1" ) then
		GameTooltip:Hide();
	else
		GameTooltip:FadeOut();	
	end
end

function UnitFrame_UpdateTooltip (self)
	GameTooltip_SetDefaultAnchor(GameTooltip, self);
	if ( GameTooltip:SetUnit(self.unit) ) then
		self.UpdateTooltip = UnitFrame_UpdateTooltip;
	else
		self.UpdateTooltip = nil;
	end
	local r, g, b = GameTooltip_UnitColor(self.unit);
	--GameTooltip:SetBackdropColor(r, g, b);
	GameTooltipTextLeft1:SetTextColor(r, g, b);
end

function UnitFrame_UpdateManaType (unitFrame)
	assert(unitFrame);
	if ( not unitFrame.manabar ) then
		return;
	end
	local powerType, powerToken = UnitPowerType(unitFrame.unit);
	local prefix = getglobal(powerToken);
	local info = PowerBarColor[powerToken];
	if ( not info ) then
		-- couldn't find a power token entry...default to indexing by power type
		info = PowerBarColor[powerType];
	end
	unitFrame.manabar:SetStatusBarColor(info.r, info.g, info.b);
	--Hack for pets
	if ( unitFrame.unit == "pet" and powerToken ~= "HAPPINESS" ) then
		return;
	end
	-- Update the manabar text
	if ( not unitFrame.noTextPrefix ) then
		SetTextStatusBarTextPrefix(unitFrame.manabar, prefix);
	end
	TextStatusBar_UpdateTextString(unitFrame.manabar);

	-- Setup newbie tooltip
	if ( unitFrame:GetName() == "PlayerFrame" ) then
		unitFrame.manabar.tooltipTitle = prefix;
		unitFrame.manabar.tooltipText = getglobal("NEWBIE_TOOLTIP_MANABAR_"..powerType);
	else
		unitFrame.manabar.tooltipTitle = nil;
		unitFrame.manabar.tooltipText = nil;
	end
end

function UnitFrameHealthBar_Initialize (unit, statusbar, statustext)
	if ( not statusbar ) then
		return;
	end

	statusbar.unit = unit;
	SetTextStatusBarText(statusbar, statustext);
	statusbar:RegisterEvent("UNIT_HEALTH");
	statusbar:RegisterEvent("UNIT_MAXHEALTH");
	statusbar:SetScript("OnEvent", UnitFrameHealthBar_OnEvent);

	-- Setup newbie tooltip
	if ( statusbar and (statusbar:GetParent() == PlayerFrame) ) then
		statusbar.tooltipTitle = HEALTH;
		statusbar.tooltipText = NEWBIE_TOOLTIP_HEALTHBAR;
	else
		statusbar.tooltipTitle = nil;
		statusbar.tooltipText = nil;
	end
end

function UnitFrameHealthBar_OnEvent(self, event, ...)
	if ( event == "CVAR_UPDATE" ) then
		TextStatusBar_OnEvent(self, event, ...);
	else
		UnitFrameHealthBar_Update(self, ...);
	end
end

function UnitFrameHealthBar_Update(statusbar, unit)
	if ( not statusbar ) then
		return;
	end
	
	if ( unit == statusbar.unit ) then
		local currValue = UnitHealth(unit);
		local maxValue = UnitHealthMax(unit);

		statusbar.showPercentage = nil;
		
		-- Safety check to make sure we never get an empty bar.
		statusbar.forceHideText = false;
		if ( maxValue == 0 ) then
			maxValue = 1;
			statusbar.forceHideText = true;
		elseif ( maxValue == 100 ) then
			--This should be displayed as percentage.
			statusbar.showPercentage = true;
		end

		statusbar:SetMinMaxValues(0, maxValue);

		if ( not UnitIsConnected(unit) ) then
			statusbar:SetStatusBarColor(0.5, 0.5, 0.5);
			statusbar:SetValue(maxValue);
		else
			statusbar:SetStatusBarColor(0.0, 1.0, 0.0);
			statusbar:SetValue(currValue);
		end
	end
	TextStatusBar_UpdateTextString(statusbar);
end

function UnitFrameHealthBar_OnValueChanged(self, value)
	TextStatusBar_OnValueChanged(self, value);
	HealthBar_OnValueChanged(self, value);
end

function UnitFrameManaBar_Initialize (unit, statusbar, statustext)
	if ( not statusbar ) then
		return;
	end
	statusbar.unit = unit;
	SetTextStatusBarText(statusbar, statustext);
	statusbar:RegisterEvent("UNIT_MANA");
	statusbar:RegisterEvent("UNIT_RAGE");
	statusbar:RegisterEvent("UNIT_FOCUS");
	statusbar:RegisterEvent("UNIT_ENERGY");
	statusbar:RegisterEvent("UNIT_HAPPINESS");
	statusbar:RegisterEvent("UNIT_RUNIC_POWER");
	statusbar:RegisterEvent("UNIT_MAXMANA");
	statusbar:RegisterEvent("UNIT_MAXRAGE");
	statusbar:RegisterEvent("UNIT_MAXFOCUS");
	statusbar:RegisterEvent("UNIT_MAXENERGY");
	statusbar:RegisterEvent("UNIT_MAXHAPPINESS");
	statusbar:RegisterEvent("UNIT_MAXRUNIC_POWER");
	statusbar:RegisterEvent("UNIT_DISPLAYPOWER");
	statusbar:SetScript("OnEvent", UnitFrameManaBar_OnEvent);
end

function UnitFrameManaBar_OnEvent(self, event, ...)
	if ( event == "CVAR_UPDATE" ) then
		TextStatusBar_OnEvent(self, event, ...);
	else
		UnitFrameManaBar_Update(self, ...);
	end
end

function UnitFrameManaBar_Update(statusbar, unit)
	if ( not statusbar ) then
		return;
	end
	
	if ( unit == statusbar.unit ) then
		local maxValue = UnitManaMax(unit);

		statusbar:SetMinMaxValues(0, maxValue);

		-- If disconnected

		if ( not UnitIsConnected(unit) ) then
			statusbar:SetValue(maxValue);
			statusbar:SetStatusBarColor(0.5, 0.5, 0.5);
		else
			local currValue = UnitMana(unit);
			statusbar:SetValue(currValue);
			UnitFrame_UpdateManaType(statusbar:GetParent());
		end
	end
	TextStatusBar_UpdateTextString(statusbar);
end

function GetUnitName(unit, showServerName)
	local name, server = UnitName(unit);
	if ( server and server ~= "" ) then
		if ( showServerName ) then
			return name.." - "..server;
		else
			return name..FOREIGN_SERVER_LABEL;
		end
	else
		return name;
	end
end
