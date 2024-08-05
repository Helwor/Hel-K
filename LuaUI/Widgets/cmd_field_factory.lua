function widget:GetInfo()
	return {
		name      = "Field Factory Selector",
		desc      = "Selects construction option from a factory",
		author    = "GoogleFrog",
		date      = "2 April 2024",
		license   = "GNU GPL, v2 or later",
		layer     = 0,
		enabled   = true,  --  loaded by default?
		handler   = true,
	}
end
local requirements = {
	exists = {
		[WIDGET_DIRNAME .. '-SelectionAPI.lua'] = {nil, nil, true}
	}
}

local Echo = Spring.Echo
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local CMD_FIELD_FAC_SELECT    = Spring.Utilities.CMD.FIELD_FAC_SELECT
local CMD_FIELD_FAC_UNIT_TYPE = Spring.Utilities.CMD.FIELD_FAC_UNIT_TYPE
local screenWidth, screenHeight = Spring.GetViewGeometry()

local OPT_WIDTH = 380
local OPT_HEIGHT = 148

local ROWS = 2
local COLUMNS = 6

local Chili
local optionsWindow

local _, factoryUnitPosDef = include("Configs/integral_menu_commands.lua", nil, VFS.RAW_FIRST)

local factoryDefs = {}
do

	local factories = {
		[[factoryshield]],
		[[factorycloak]],
		[[factoryveh]],
		[[factoryplane]],
		[[factorygunship]],
		[[factoryhover]],
		[[factoryamph]],
		[[factoryspider]],
		[[factoryjump]],
		[[factorytank]],
		[[factoryship]],
		[[striderhub]],
		[[plateshield]],
		[[platecloak]],
		[[plateveh]],
		[[plateplane]],
		[[plategunship]],
		[[platehover]],
		[[plateamph]],
		[[platespider]],
		[[platejump]],
		[[platetank]],
		[[plateship]],
	}

	for i = 1, #factories do
		local factoryName = factories[i]
		factoryDefs[UnitDefNames[factoryName].id] = true
	end
end


--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- declarations for the Invite part


local fieldFacRange = {}
for unitDefID = 1, #UnitDefs do
	local ud = UnitDefs[unitDefID]
	if ud.customParams.field_factory then
		fieldFacRange[unitDefID] = ud.buildDistance + 128
	end
end

-- local CMD_FIELD_FAC_QUEUELESS = Spring.Utilities.CMD.FIELD_FAC_QUEUELESS

local OPT_MINI_WIDTH = 300
local OPT_MINI_HEIGHT = 115
local OPT_EXTRA_HEIGHT = 80

local UPDATE_RATE = 30
local invSize = 60 -- default size
local rX = 7/11 -- relative position in the UI
local rY = 7/10  

local vsx, vsy = Spring.Orig.GetViewSizes()
local invX = vsx * rX
local invY = vsy * rY
local invite, invited, warned = false, false, false
local fieldIcon = 'LuaUI/Images/commands/Bold/fac_select.png'
local offsetY = 0
local targettedFacs = {}
local gamePaused = false
local tweakMode, gamePaused = false, false
local time
local field_tweak_win
local wh -- we don't have the real widgetHandler at loading

-- speed ups
local spGetUnitsInCylinder 		= Spring.GetUnitsInCylinder
local spGetUnitPosition 		= Spring.GetUnitPosition
local spGetUnitDefID 			= Spring.GetUnitDefID
local spGetUnitIsStunned 		= Spring.GetUnitIsStunned
local spGetScreenGeometry 		= Spring.GetScreenGeometry
local spIsGUIHidden 			= Spring.IsGUIHidden
local spGetUnitIsStunned		= Spring.GetUnitIsStunned
local spGetUnitRulesParam		= Spring.GetUnitRulesParam
local spGetSelectedUnitsSorted 	= Spring.GetselectedUnitsSorted

local ALLY_UNITS 	= Spring.ALLY_UNITS

local glPushMatrix 	= gl.PushMatrix
local glTexture 	= gl.Texture
local glTranslate 	= gl.Translate
local glScale		= gl.Scale
local glTexRect 	= gl.TexRect
local glBillboard 	= gl.Billboard
local glPopMatrix 	= gl.PopMatrix
local glColor		= gl.Color






local function MakeTweakWin() -- a window only to be interacted with during tweak mode
	field_tweak_win = {
		parent = WG.Chili.Screen0,
		name = 'field_tweak_win',
		-- NOTE: dockable beeing true  and if the control has fixed name, the window pos and size are recovered after unloading/reloading widget (use dockableSavePositionOnly=true to not really dock but only save position)
		-- but what if user doesn't have docking enabled
		-- dockable = true, 
		-- dockableSavePositionOnly = true,
		minWidth = 30,
		minHeight = 30,
		maxHeight = 100,
		maxWidth = 100,
		hitpadding = {0,0,0,0}, -- default is 4,4,4,4 -- need to lower it to catch grip when window is small
		x = invX,
		y = invY,
		width = invSize,
		height = invSize,
		fixedRatio = true,
		resizable = false,
		draggable = false,
		OnResize = { function(self)
			invSize = self.width
			-- resize grip area doesn't adapt with small window, and only bottom and right are changed to -1, -1 in tweakmode even if it visually appear shrinked
			local min = math.min
			local grip = self.boxes.resize -- -21 -21 -10 -10 as default
			grip[1], grip[2] = - min(invSize/4, 21), - min(invSize/4, 21)
			 -- grip[3], grip[4] = - min(invSize/10, 10), - min(invSize/10, 10) -- no need if we're doing this only in tweak mode
		end},
		tweakDraggable = true,
		tweakResizable = true,
		borderThickness = 0,
		color = {0,0,0,0}, -- avoid the window flashing between the time the tweak mode goes off and the time we can detect it happened (there's no direct callin to inform us)
	}
	WG.Chili.Window:New(field_tweak_win)
end



-------------------------------------------------------------------------------

--------------------------------------------------------------------------------

local function GetOptionsPosition(width, height)
	local x, y = Spring.ScaledGetMouseState()
	y = screenHeight - y
	x = x - width / 2
	y = y - height - 20
	
	if x + width > screenWidth - 2 then
		x = screenWidth - width - 2
	end
	if y + height > screenHeight - 2 then
		y = screenHeight - height - 2
	end
	
	local map = WG.MinimapPosition
	if map then
		-- Only move tooltip up and/or left if it overlaps the minimap. This is because the
		-- minimap does not have tooltips.
		if x < map[1] + map[3] and y < map[2] + map[4] then
			local inX = x + width - map[1] + 2
			local inY = y + height - map[2] + 2
			if inX > 0 and inY > 0 then
				if inX > inY then
					y = y - inY
				else
					x = x - inX
				end
			end
		end
		
		if x < 2 then
			x = 2
		end
		if y < 2 then
			y = 2
		end
		if x + width > screenWidth - 2 then
			x = screenWidth - width - 2
		end
		if y + height > screenHeight - 2 then
			y = screenHeight - height - 2
		end
	end
	
	return math.floor(x), math.floor(y)
end
local spGetUnitCurrentCommand = Spring.GetUnitCurrentCommand
local spGetSelectedUnits = Spring.GetSelectedUnits
local function IsSelectingFieldFac()
	for i, id in ipairs(spGetSelectedUnits()) do
		if spGetUnitCurrentCommand(id) == CMD_FIELD_FAC_SELECT then
			return true
		end
	end
end
local function GetButton(parent, x, y, unitDefID, ud, unitName, mini, offsetY, factoryID, stunned)
	local xStr = tostring((x - 1)*100/COLUMNS) .. "%"
	local yStr 
	local height
	if offsetY then
		height = 40
		yStr = offsetY + (y-1) * 40
	else
		height = "50%"
		yStr = tostring((y - 1)*100/ROWS) .. "%"
	end
	local function DoClick()
		if unitDefID then
			if mini then
				-- since we use insertion, overriding the nextDesiredUnitType from gadget before
				Spring.GiveOrder(CMD_FIELD_FAC_UNIT_TYPE, {unitDefID}, 0)
				Spring.GiveOrder(CMD.INSERT, {0, CMD_FIELD_FAC_SELECT, 0, factoryID}, CMD.OPT_ALT)

				-- alternative, but then it doesn't wait for factory to be finished
				-- Spring.GiveOrder(CMD_FIELD_FAC_QUEUELESS, {factoryID, unitDefID}, 0)
			else
				Spring.GiveOrder(CMD_FIELD_FAC_UNIT_TYPE, {unitDefID}, 0)
			end
		else
			if not mini then
				Spring.GiveOrder(CMD_FIELD_FAC_UNIT_TYPE, {-1}, 0)
			end
			-- Spring.GiveOrder(CMD.INSERT, {0, CMD_FIELD_FAC_UNIT_TYPE, 0, -1}, CMD.OPT_ALT)
		end
		invited = false
		optionsWindow:Dispose()
		optionsWindow = false
	end

	local button = Chili.Button:New {
		name = name,
		x = xStr,
		y = yStr,
		width = "16.7%",
		height = height,
		caption = false,
		noFont = true,
		padding = {0, 0, 0, 0},
		parent = parent,
		preserveChildrenOrder = true,
		tooltip = (unitName and "BuildUnit" .. unitName) or "Cancel",
		OnClick = {DoClick},
		backgroundColor = stunned and {0.9,0.4,0.2,1} or nil,
		focusColor = stunned and {0.9,0.4,0.2,1} or nil,
		-- backgroundHoveredColor = stunned and {0.9,0.4,0.2,1} or nil,

	}
	if unitDefID then
		Chili.Label:New {
			name = "bottomLeft",
			x = "15%",
			right = 0,
			bottom = 2,
			height = 12,
			fontsize = 12,
			parent = button,
			caption = ud.metalCost,
		}
		Chili.Image:New {
			x = "5%",
			y = "4%",
			right = "5%",
			bottom = 12,
			keepAspect = false,
			file = "#" .. unitDefID,
			file2 = WG.GetBuildIconFrame(ud),
			parent = button,
		}
	else
		Chili.Image:New {
			x = "7%",
			y = "10%",
			right = "7%",
			bottom = "10%",
			keepAspect = true,
			file = "LuaUI/Images/commands/Bold/cancel.png",
			parent = button,
		}
	end
end

local function GenerateOptionsSelector(factoryID, mini, combine)
	if not combine then
		warned = false
	end
	if not factoryID and mini then
		GetButton(optionsWindow.children[1], 1, 2, nil, nil, nil, mini, mini and offsetY)
		return
	end
	if optionsWindow and not combine then
		optionsWindow:Dispose()
		optionsWindow = false
	end
	local unitDefID = Spring.ValidUnitID(factoryID) and Spring.GetUnitDefID(factoryID)
	if not unitDefID then
		return
	end
	if not Spring.AreTeamsAllied(Spring.GetUnitTeam(factoryID), Spring.GetMyTeamID()) then
		return
	end
	if not factoryDefs[unitDefID] then
		return
	end
	local ud = UnitDefs[unitDefID]
	if not ud then
		return
	end
	local name = ud.name
	local buildList = ud.buildOptions
	local layoutData = factoryUnitPosDef[name]
	if not buildList then
		return
	end

	if combine then
		offsetY = offsetY + OPT_EXTRA_HEIGHT
	else
		offsetY = 0
	end
	
	local width, height, bottomGap
	if mini then
		height = OPT_MINI_HEIGHT
		width = OPT_MINI_WIDTH
	else
		height = OPT_HEIGHT
		width = OPT_WIDTH
	end

	local stunned, _, inbuild = spGetUnitIsStunned(factoryID)
	stunned = stunned or ((spGetUnitRulesParam(factoryID, "totalEconomyChange") or 1) <= 0)
	if stunned and not warned then
		bottomGap = mini and 21 or 24
		height = height + bottomGap
	else
		bottomGap = 0
	end

	
	local x, y = GetOptionsPosition(width, height)
	if combine then
		optionsWindow:Resize(nil, optionsWindow.height + OPT_EXTRA_HEIGHT + bottomGap)
	else
		optionsWindow = Chili.Window:New{
			x = x,
			y = y,
			width = width,
			height = height,
			padding = {14, 22, 14, 10},
			classname = "main_window_small",
			textColor = {1, 1, 1, 0.55},
			parent = Chili.Screen0,
			dockable  = false,
			resizable = false,
			caption = "Select blueprint to copy:",
			backgroundColor = {0,0,0,0}
		}
		if WG.MakeMinizable then
			WG.MakeMinizable(optionsWindow)
		end
		optionsWindow:BringToFront()
	end
	local panel
	if combine then
		panel = optionsWindow.children[1]
	else
		panel = Chili.Panel:New{
			x = 0,
			y = 0,
			right = 0,
			bottom = bottomGap,
			padding = {0, 0, 0, 0},
			backgroundColor = {1, 1, 1, 0},
			parent = optionsWindow,
		}
	end
	
	if stunned and not warned then
		Chili.Label:New{
			x      = 0,
			right  = 0,
			bottom = 0,
			height = bottomGap,
			caption = inbuild and "Warning: Factory must be complete" or "Warning: Factory must be functional",
			align  = "center",
			autosize = false,
			font   = {
				size = mini and 15 or 16,
				outline = true,
				outlineWidth = 1,
				outlineWeight = 1,
			},
			parent = optionsWindow,
		}
		warned = true
	end

	for i = 1, #buildList do
		local buildDefID = buildList[i]
		local bud = UnitDefs[buildDefID]
		local buildName = bud.name
		local position = buildName and layoutData and layoutData[buildName]
		local row, col
		if position then
			col, row = position.col, position.row
		else
			row = (i > 6) and 2 or 1
			col = (i - 1)%6 + row
		end
		GetButton(panel, col, row, buildDefID, bud, buildName, mini, mini and offsetY, factoryID, stunned)
	end
	if not mini then
		GetButton(panel, 1, 2)
	end
end

local function DrawInvite()
	if spIsGUIHidden() then
		return
	end
	if field_tweak_win.dragging then -- no OnDragging callin
		invX, invY = field_tweak_win.x, field_tweak_win.y
		rX, rY = invX / vsx, invY / vsy
	end
	-- Echo('pos of win', field_tweak_win.x, field_tweak_win.y,'invX', invX, 'rX', rX, 'vsx', vsx)
	glPushMatrix()
	local scale = WG.uiScale
	glScale(scale, scale, 1)
	glTranslate(invX, vsy/scale - (invY + invSize), 0)
	local t = (time -  os.clock())%2 - 1.2
	glColor(1, 1, 1, 0.35 + (t < 0 and - t or t))
	glTexture(fieldIcon)
	glTexRect(0, 0, invSize, invSize)
	glTexture(false)
	glPopMatrix()
	glColor(1, 1, 1, 1)
end
local function EndInvite()
	if invite then
		invite = false
		-- widgetHandler:RemoveWidgetCallIn('DrawScreen', widget)  -- we can't remove DrawScreen or TweakDrawScreen will not trigger
	end
end
local function DevelopInvite()
	EndInvite()

	invited = true
	local count = 0
	for _, factoryID in pairs(targettedFacs) do
		count = count + 1
		GenerateOptionsSelector(factoryID, true, count > 1)
	end
	targettedFacs = false
	GenerateOptionsSelector(nil, true)
	optionsWindow:UpdateLayout()
end

local function MakeInvite()
	if not invite then
		invite = true
		if not tweakMode then
			time = os.clock() + 1
		end
		-- widgetHandler:UpdateWidgetCallIn('DrawScreen', widget) -- we can't remove DrawScreen or TweakDrawScreen will not trigger
	end
end

------------------------------------------------------------------
------------------------------------------------------------------

-- CallIns

function widget:CommandNotify(cmdID, params, options)
	if (cmdID == CMD_FIELD_FAC_SELECT) and params and params[1] then
		EndInvite()
		invited = false
		GenerateOptionsSelector(params[1])
		return false
	end
	--if optionsWindow then
	--	optionsWindow:Dispose()
	--	Spring.GiveOrder(CMD_FIELD_FAC_UNIT_TYPE, {-1}, 0)
	--	optionsWindow = false
	--end
end


function widget:MousePress(x,y,button)
	if optionsWindow then
		if WG.uiScale and WG.uiScale ~= 1 then
			x, y = x/WG.uiScale, y/WG.uiScale
		end
		if not Chili.Screen0:IsAbove(x,y) then
			optionsWindow:Dispose()
			if invited then
				invited = false
			else
				Spring.GiveOrder(CMD_FIELD_FAC_UNIT_TYPE, {-1}, 0)
			end
			optionsWindow = false
		end
	else
		if button == 1 and invite then
			y = vsy - y
			if  x > invX and x < invX + invSize
			and y > invY and y < invY + invSize
			then
				DevelopInvite()
				return true
			end
		end
	end
end

function widget:DrawScreen()
	if tweakMode and not wh.tweakMode then
		tweakMode = false
		field_tweak_win:Hide()
	end
	if invite or tweakMode then
		DrawInvite()
	end
end

function widget:TweakDrawScreen()
	if not tweakMode then -- no callin to get informed we're entering Tweak mode
		tweakMode = true
		field_tweak_win:Show()
		time = os.clock() + 1
	end
end




local spFindUnitCmdDesc = Spring.FindUnitCmdDesc
function widget:CommandsChanged()
	candidates = false
	targettedFacs = false
	EndInvite()
	invited = false
	if optionsWindow then
		otionsWindow:Dispose()
		optionsWindow = false
	end
	if not WG.commandMap or WG.commandMap[CMD_FIELD_FAC_SELECT] then
		for defID, units in pairs(WG.selectionDefID or spGetSelectedUnitsSorted()) do
			local range = fieldFacRange[defID]
			if range then
				local valid, v = {}, 0
				for i, id in ipairs(units) do
					if spFindUnitCmdDesc(id, CMD_FIELD_FAC_SELECT) then
						v = v + 1
						valid[v] = id
					end
				end
				if v > 0 then
					if not candidates then candidates = {} end
					candidates[range] = valid
				end
			end
		end
		if candidates and gamePaused then
			widget:GameFrame(UPDATE_RATE)
		end
	end
end

function widget:GamePaused(_, isPaused)
	gamePaused = isPaused
end

function widget:GameFrame(f)
	if candidates and f%UPDATE_RATE == 0 then
		if not optionsWindow then
			targettedFacs = false
			for range, units in pairs(candidates) do
				for _, candidateID in ipairs(units) do
					local x, y, z = spGetUnitPosition(candidateID)
					local around = spGetUnitsInCylinder(x, z, range, ALLY_UNITS)
					for _, id in ipairs(around) do
						local defID = spGetUnitDefID(id)
						if factoryDefs[defID] then
							if not targettedFacs then 
								targettedFacs = { [defID] = id}
							else
								local oneAlready = targettedFacs[defID]
								if not oneAlready 
									or select(2, spGetUnitIsStunned(oneAlready))
									or ((spGetUnitRulesParam(oneAlready, "totalEconomyChange") or 1) <= 0)
								then
									targettedFacs[defID] = id
								end
							end
						end
					end
				end
			end
			if targettedFacs then
				MakeInvite()
			else
				EndInvite()
			end
		end
	end
end
-- saving position
function widget:GetConfigData()
	return {rX = rX, rY = rY}
end
function widget:SetConfigData(data)
	if data.rX then
		rX, rY = data.rX, data.rY
		invX, invY = vsx * rX, vsy * rY
	end
end

function widget:ViewResize(x, y)
	screenWidth = x/WG.uiScale
	screenHeight = y/WG.uiScale
	vsx, vsy = x, y
	invX, invY = rX * vsx, rY * vsy
end



function widget:Initialize()
	if widget.Requires and not widget:Requires(requirements) then
		return
	end

	-- widgetHandler:RemoveWidgetCallIn('DrawScreen', widget)  -- we can't remove DrawScreen or TweakDrawScreen will not trigger
	widget:ViewResize(gl.GetViewSizes()) -- or Spring.Orig.GetViewSizes
	Chili = WG.Chili

	wh = widgetHandler
	MakeTweakWin()

	field_tweak_win:Hide()


	widget:CommandsChanged()
	if Spring.GetGameFrame() > 0 then
		widget:GameFrame(UPDATE_RATE)
	end
end
