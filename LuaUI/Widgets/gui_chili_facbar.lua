-------------------------------------------------------------------------------

local version = "v0.053"

function widget:GetInfo()
	return {
	name      = "Chili FactoryBar",
	desc      = version .. " - Chili buildmenu for factories.",
	author    = "CarRepairer (converted from jK's Buildbar)",
	date      = "2010-11-10",
	license   = "GNU GPL, v2 or later",
	layer     = 1001,
	enabled   = true,
	handler   = true,
	}
end
local Echo = Spring.Echo
include("Widgets/COFCTools/ExportUtilities.lua")
VFS.Include("LuaRules/Configs/customcmds.h.lua")
local GetLeftRightAllyTeamIDs = VFS.Include("LuaUI/Headers/allyteam_selection_utilities.lua")
local UnitDefs = UnitDefs
local f = WG.utilFuncs
-------------------------------------------------------------------------------
-------------------------------------------------------------------------------

local playerActive = false
local specActive = true
local force_update = false
local initialized = false

WhiteStr   = "\255\255\255\255"
GreyStr    = "\255\210\210\210"
GreenStr   = "\255\092\255\092"

local buttonColor = {0,0,0,0.5}
local queueColor = {0.0,0.4,0.4,0.9}
local progColor = {1,0.7,0,0.6}

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local Chili
local Button
local Label
local Window
local StackPanel
local Grid
local TextBox
local Image
local Progressbar
local screen0
-------------------------------------------------------------------------------
-------------------------------------------------------------------------------

local window_facbar, window_facbar2, stack_main, stackmain2, title, title2
local echo = Spring.Echo

-------------------------------------------------------------------------------
-------------------------------------------------------------------------------

local function RecreateFacbar() end
local function ShowTitles(bool) end




options_path = 'Settings/HUD Panels/FactoryBar'
options = {
	maxVisibleBuilds = {
		type = 'number',
		name = 'Visible Units in Que',
		desc = "The maximum units to show in the factory's queue",
		min = 2, max = 14,
		value = 5,
	},
	
	buttonsize = {
		type = 'number',
		name = 'Button Size',
		min = 40, max = 100, step=5,
		value = 50,
		OnChange = function() RecreateFacbar() end,
	},
}


local function Sleep(bool)
    if widgetHandler.Sleep then
        return widgetHandler[bool and 'Sleep' or 'Wake'](widgetHandler,widget )
    else
        for k,v in pairs(widget) do
            if type(k)=='string' and type(v)=='function' then
                if widgetHandler[k .. 'List'] 
                	-- and k ~= 'PlayerChanged' 
                then
                	Echo((bool and 'Remove' or 'Update')..'WidgetCallIn',k)
                    widgetHandler[(bool and 'Remove' or 'Update')..'WidgetCallIn'](widgetHandler,k,widget)
                end
            end
        end
    end
end

local helk_path = 'Hel-K/' .. widget:GetInfo().name
options.active = {
	name = 'Active as Player',
	type = 'bool',
	value = playerActive,
	OnChange = function(self)
		playerActive = self.value
		if Spring.GetSpectatingState() then
			return
		end
		Sleep(not playerActive)
		if not playerActive then
			widget:Shutdown()
		elseif not initialized then
			widget:Initialize()
		end
	end,
	path = helk_path,
}
options.spec_active = {
	name = 'Active as Spec',
	type = 'bool',
	value = specActive,
	OnChange = function(self)
		specActive = self.value
		if not Spring.GetSpectatingState() then
			return
		end
		Sleep(not specActive)
		if not specActive then
			widget:Shutdown()
		elseif not initialized then
			widget:Initialize()
		end


		if initialized and self.value then
			force_update = true
			widget:PlayerChanged(Spring.GetMyPlayerID())
		end
	end,
	path = helk_path,
}
options.show_title = {
	name = 'Show Title bar',
	type = 'bool',
	value = true,
	OnChange = function(self)
		ShowTitles(self.value)
	end,
	path = helk_path,
}
-------------------------------------------------------------------------------
-------------------------------------------------------------------------------

local EMPTY_TABLE = {}

-- list and interface vars
local facs = {}
local unfinished_facs = {}
local pressedFac  = -1
local waypointFac = -1
local waypointMode = 0   -- 0 = off; 1=lazy; 2=greedy (greedy means: you have to left click once before leaving waypoint mode and you can have units selected)

local myPlayerID = Spring.GetMyPlayerID()
local myAllyTeamID = Spring.GetMyAllyTeamID()
local myTeamID = Spring.GetMyTeamID()
local inTweak  = false
local leftTweak, enteredTweak = false, false
local cycle_half_s = 1
local cycle_2_s = 1
local SPECMODE_1V1 = nil 
local LEFT, RIGHT

-------------------------------------------------------------------------------
-- SOUNDS
-------------------------------------------------------------------------------

local sound_waypoint  = LUAUI_DIRNAME .. 'Sounds/buildbar_waypoint.wav'
local sound_click     = LUAUI_DIRNAME .. 'Sounds/buildbar_click.WAV'
local sound_queue_add = LUAUI_DIRNAME .. 'Sounds/buildbar_add.wav'
local sound_queue_rem = LUAUI_DIRNAME .. 'Sounds/buildbar_rem.wav'

-------------------------------------------------------------------------------

local image_repeat    = LUAUI_DIRNAME .. 'Images/repeat.png'

local GetTeamColor = Spring.GetTeamColor

-------------------------------------------------------------------------------
-- SCREENSIZE FUNCTIONS
-------------------------------------------------------------------------------
local vsx, vsy   = widgetHandler:GetViewSizes()

function widget:ViewResize(viewSizeX, viewSizeY)
	vsx = viewSizeX
	vsy = viewSizeY
end


-------------------------------------------------------------------------------

local GetUnitDefID      = Spring.GetUnitDefID
local GetUnitHealth     = Spring.GetUnitHealth
local DrawUnitCommands  = Spring.DrawUnitCommands
local GetSelectedUnits  = Spring.GetSelectedUnits
local GetFullBuildQueue = Spring.GetFullBuildQueue
local GetUnitIsBuilding = Spring.GetUnitIsBuilding

local push        = table.insert


-------------------------------------------------------------------------------
local facDefID, facDefIDArray = {}, {}
for defID, def in pairs(UnitDefs) do
	if def.isFactory  and def.buildOptions then
		table.insert(facDefIDArray, defID)
		facDefID[defID] = true
	else
		local cp = def.customParams
		if (cp.child_of_factory) and def.buildOptions then
			table.insert(facDefIDArray, defID)
			facDefID[defID] = true
		end
	end
end


local function GetBuildQueue(unitID)
	local result = {}
	local queue = GetFullBuildQueue(unitID)
	if (queue ~= nil) then
	for _,buildPair in ipairs(queue) do
		local udef, count = next(buildPair, nil)
		if result[udef]~=nil then
		result[udef] = result[udef] + count
		else
		result[udef] = count
		end
	end
	end
	return result
end



local function UpdateFac(i, facInfo)
	--local unitDefID = facInfo.unitDefID
	
	local unitBuildDefID = -1
	local unitBuildID    = -1

	-- building?
	local progress = 0
	unitBuildID      = GetUnitIsBuilding(facInfo.unitID)
	if unitBuildID then
		unitBuildDefID = GetUnitDefID(unitBuildID)
		_, _, _, _, progress = GetUnitHealth(unitBuildID)
		--unitDefID      = unitBuildDefID
		
	elseif (unfinished_facs[facInfo.unitID]) then
		_, _, _, _, progress = GetUnitHealth(facInfo.unitID)
		if (progress>=1) then
			progress = -1
			unfinished_facs[facInfo.unitID] = nil
		end
		
	end

	local buildList   = facInfo.buildList
	local buildQueue  = GetBuildQueue(facInfo.unitID)
	for j,unitDefIDb in ipairs(buildList) do
		if not facs[i].boStack then
			echo('<Chili Facbar> Strange error #1' )
		else
			local boButton = facs[i].boStack.childrenByName[unitDefIDb]
			local qButton = facs[i].qStore[i .. '|' .. unitDefIDb]
			
			local boBar = boButton.childrenByName['bp'].childrenByName['prog']
			local qBar = qButton.childrenByName['bp'].childrenByName['prog']
			
			local amount = buildQueue[unitDefIDb] or 0
			local boCount = boButton.childrenByName['count']
			local qCount = qButton.childrenByName['count']
			
			facs[i].qStack:RemoveChild(qButton)
			
			boBar:SetValue(0)
			qBar:SetValue(0)
			if unitDefIDb == unitBuildDefID then
				boBar:SetValue(progress)
				qBar:SetValue(progress)
			end
			
			if amount > 0 then
				boButton.backgroundColor = queueColor
			else
				boButton.backgroundColor = buttonColor
			end
			boButton:Invalidate()
			
			boCount:SetCaption(amount > 0 and amount or '')
			qCount:SetCaption(amount > 0 and amount or '')
		end
	end
end
local function UpdateFacQ(i, facInfo)
	local unitBuildDefID = -1
	local unitBuildID    = -1

	-- building?
	local progress = 0
	unitBuildID      = GetUnitIsBuilding(facInfo.unitID)
	if unitBuildID then
		unitBuildDefID = GetUnitDefID(unitBuildID)
		_, _, _, _, progress = GetUnitHealth(unitBuildID)
	end
	local buildQueue  = Spring.GetFullBuildQueue(facInfo.unitID, options.maxVisibleBuilds.value +1)
				
	if (buildQueue ~= nil) then
		
		local n,j = 1,options.maxVisibleBuilds.value
		
		while (buildQueue[n]) do
			local unitDefIDb, count = next(buildQueue[n], nil)
			
			local qButton = facs[i].qStore[i .. '|' .. unitDefIDb]
			
			if not facs[i].qStack:GetChildByName(qButton.name) then
				facs[i].qStack:AddChild(qButton)
			end
		
			j = j-1
			if j==0 then break end
			n = n+1
		end
	end
end

local tooltipButton = WG.Translate("interface", "lmb") .. ' - ' .. GreenStr .. WG.Translate("interface", "select") .. '\n'
	.. WhiteStr ..  WG.Translate("interface", "mmb") .. ' - ' .. GreenStr .. WG.Translate("interface", "go_to") .. '\n'
	.. WhiteStr ..  WG.Translate("interface", "rmb") .. ' - ' .. GreenStr .. WG.Translate("interface", "quick_rallypoint_mode")


local function AddFacButton(unitID, unitDefID, tocontrol, stackname, prefTooltip)
	tocontrol:AddChild(
		Button:New{
			caption = '',
			width = options.buttonsize.value*1.2,
			height = options.buttonsize.value*1.0,
			tooltip = (prefTooltip or '') .. tooltipButton
				,
			backgroundColor = buttonColor,
			
			OnClick = {
				unitID ~= 0 and
					function(_,_,_,button)
						if button == 2 then
							local x,y,z = Spring.GetUnitPosition(unitID)
							SetCameraTarget(x,y,z)
						elseif button == 3 then
							Spring.Echo("FactoryBar: Entered easy waypoint mode")
							Spring.PlaySoundFile(sound_waypoint, 1, 'ui')
							waypointMode = 2 -- greedy mode
							waypointFac  = stackname
						else
							Spring.PlaySoundFile(sound_click, 1, 'ui')
							Spring.SelectUnitArray({unitID})
						end
					end
					or nil
			},
			padding={3, 3, 3, 3},
			--margin={0, 0, 0, 0},
			children = {
				unitID ~= 0 and
					Image:New {
						file = "#"..unitDefID,
						file2 = WG.GetBuildIconFrame(UnitDefs[unitDefID]),
						keepAspect = false;
						width = '100%',
						height = '100%',
					}
				or nil,
			},
		}
	)

	local boStack = StackPanel:New{
		name = stackname .. '_bo',
		itemMargin={0,0,0,0},
		itemPadding={0,0,0,0},
		padding={0,0,0,0},
		--margin={0, 0, 0, 0},
		x=0,
		width=700,
		height = options.buttonsize.value,
		resizeItems = false,
		orientation = 'horizontal',
		centerItems = false,
	}
	local qStack = StackPanel:New{
		name = stackname .. '_q',
		itemMargin={0,0,0,0},
		itemPadding={0,0,0,0},
		padding={0,0,0,0},
		--margin={0, 0, 0, 0},
		x=0,
		width=700,
		height = options.buttonsize.value,
		resizeItems = false,
		orientation = 'horizontal',
		centerItems = false,
	}
	local qStore = {}
	
	local facStack = StackPanel:New{
		name = stackname,
		itemMargin={0,0,0,0},
		itemPadding={0,0,0,0},
		padding={0,0,0,0},
		--margin={0, 0, 0, 0},
		width=800,
		height = options.buttonsize.value*1.0,
		resizeItems = false,
		centerItems = false,
	}
	
	facStack:AddChild( qStack )
	tocontrol:AddChild( facStack )
	return facStack, boStack, qStack, qStore
end

local function MakeButton(unitDefID, facID, facIndex)

	local ud = UnitDefs[unitDefID]
	local tooltip = "Build Unit: " .. ud.humanName .. " - " .. ud.tooltip .. "\n"
	
	return
		Button:New{
			name = unitDefID,
			tooltip=tooltip,
			x=0,
			caption='',
			width = options.buttonsize.value,
			height = options.buttonsize.value,
			padding = {4, 4, 4, 4},
			--padding = {0,0,0,0},
			--margin={0, 0, 0, 0},
			backgroundColor = queueColor,
			OnClick = {
				function(_,_,_,button)
					local alt, ctrl, meta, shift = Spring.GetModKeyState()
					local rb = button == 3
					local lb = button == 1
					if not (lb or rb) then return end
					
					local opt = 0
					if alt   then opt = opt + CMD.OPT_ALT   end
					if ctrl  then opt = opt + CMD.OPT_CTRL  end
					if meta  then opt = opt + CMD.OPT_META  end
					if shift then opt = opt + CMD.OPT_SHIFT end
					if rb    then opt = opt + CMD.OPT_RIGHT end
					
					Spring.GiveOrderToUnit(facID, -(unitDefID), EMPTY_TABLE, opt)
					
					if rb then
						Spring.PlaySoundFile(sound_queue_rem, 0.97, 'ui')
					else
						Spring.PlaySoundFile(sound_queue_add, 0.95, 'ui')
					end
					
					--UpdateFac(facIndex, facs[facIndex])
					
				end
			},
			children = {
				Label:New {
					name='count',
					autosize=false;
					width="100%";
					height="100%";
					align="right";
					valign="top";
					caption = '';
					fontSize = 14;
					fontShadow = true;
				},

				
				Label:New{ caption = ud.metalCost .. ' m', fontSize = 11, x=2, bottom=2, fontShadow = true, },
				Image:New {
					name = 'bp',
					file = "#"..unitDefID,
					file2 = WG.GetBuildIconFrame(ud),
					keepAspect = false;
					width = '100%',height = '80%',
					children = {
						Progressbar:New{
							value = 0.0,
							name    = 'prog';
							max     = 1;
							color       = progColor,
							backgroundColor = {1,1,1,  0.01},
							x=4,y=4, bottom=4,right=4,
							skin=nil,
							skinName='default',
						},
					},
				},
			},
		}
	
end


-------------------------------------------------------------------------------


-------------------------------------------------------------------------------
-------------------------------------------------------------------------------

local function WaypointHandler(x,y,button)
	if (button==1)or(button>3) then
	Spring.Echo("FactoryBar: Exited easy waypoint mode")
	Spring.PlaySoundFile(sound_waypoint, 1, 'ui')
	waypointFac  = -1
	waypointMode = 0
	return
	end

	local alt, ctrl, meta, shift = Spring.GetModKeyState()
	local opt = CMD.OPT_RIGHT
	if alt   then opt = opt + CMD.OPT_ALT   end
	if ctrl  then opt = opt + CMD.OPT_CTRL  end
	if meta  then opt = opt + CMD.OPT_META  end
	if shift then opt = opt + CMD.OPT_SHIFT end

	local type,param = Spring.TraceScreenRay(x,y)
	if type=='ground' then
	Spring.GiveOrderToUnit(facs[waypointFac].unitID, CMD_RAW_MOVE,param,opt)
	elseif type=='unit' then
	Spring.GiveOrderToUnit(facs[waypointFac].unitID, CMD.GUARD,{param},opt)
	elseif type~='feature' then
	return -- sky, ignore
	else --feature
	type,param = Spring.TraceScreenRay(x,y,true)
	if not param then
		return -- there's sky behind the feature, ignore
	end
	Spring.GiveOrderToUnit(facs[waypointFac].unitID, CMD_RAW_MOVE,param,opt)
	end

	--if not shift then waypointMode = 0; return true end
end

RecreateFacbar = function()
	if not initialized then
		return
	end
	enteredTweak = false
	if inTweak then return end
	
	stack_main:ClearChildren()
	if SPECMODE_1V1 ~= nil then
		stack_main2:ClearChildren()
	end

	for i,facInfo in ipairs(facs) do
		local unitDefID = facInfo.unitDefID
		
		local unitBuildDefID = -1
		local unitBuildID    = -1
		local progress

		-- building?
		--[[unitBuildID      = GetUnitIsBuilding(facInfo.unitID)
		if unitBuildID then
			unitBuildDefID = GetUnitDefID(unitBuildID)
			_, _, _, _, progress = GetUnitHealth(unitBuildID)
			unitDefID      = unitBuildDefID
		else--]]if (unfinished_facs[facInfo.unitID]) then
			_, _, _, _, progress = GetUnitHealth(facInfo.unitID)
			if (progress>=1) then
				progress = -1
				unfinished_facs[facInfo.unitID] = nil
			end
		end
		-- Echo("facInfo.allyTeamID is ", facInfo.allyTeamID)
		local stack_main = stack_main
		local prefTooltip
		if SPECMODE_1V1~=nil then
			if facInfo.allyTeamID == RIGHT.allyTeamID then
				stack_main = stack_main2
				prefTooltip = RIGHT.tooltip .. '\n'
				-- Echo('ok put to stack 2')
			else
				prefTooltip = LEFT.tooltip .. '\n'
			end
		end
		local facStack, boStack, qStack, qStore = AddFacButton(facInfo.unitID, unitDefID, stack_main, i, prefTooltip)
		facs[i].facStack  = facStack
		facs[i].boStack   = boStack
		facs[i].qStack    = qStack
		facs[i].qStore    = qStore
		
		local buildList   = facInfo.buildList
		local buildQueue  = GetBuildQueue(facInfo.unitID)
		for j,unitDefIDb in ipairs(buildList) do
			boStack:AddChild( MakeButton(unitDefIDb, facInfo.unitID, i) )
			qStore[i .. '|' .. unitDefIDb] = MakeButton(unitDefIDb, facInfo.unitID, i)
		end
		
	end

	stack_main:Invalidate()
	stack_main:UpdateLayout()
	if SPECMODE_1V1 ~= nil then
		stack_main2:Invalidate()
		stack_main2:UpdateLayout()
	end
	ShowTitles(options.show_title.value)
end


local function ListFactoryTeam(teamID)

	-- Echo('list factory',teamID,'myTeamID',myTeamID,'myAllyTeamID', myAllyTeamID)
	local teamUnits = Spring.GetTeamUnitsByDefs(teamID, facDefIDArray)
	local totalUnits = #teamUnits
	local allyTeamID
	for num = 1, totalUnits do
		local unitID = teamUnits[num]
		local unitDefID = GetUnitDefID(unitID)
		if facDefID[unitDefID] then
			local bo =  UnitDefs[unitDefID].buildOptions
			if bo and bo[1] then
				if not allyTeamID then
					allyTeamID = Spring.GetUnitAllyTeam(unitID)
				end
				push(facs,{ unitID=unitID, unitDefID=unitDefID, allyTeamID = allyTeamID, buildList=bo })
				local _, _, _, _, buildProgress = GetUnitHealth(unitID)
				if (buildProgress)and(buildProgress<1) then
					unfinished_facs[unitID] = true
				end
			end
		end
	end
end

local function UpdateFactoryList()
	facs = {}
	if SPECMODE_1V1 then
		ListFactoryTeam(0)
		ListFactoryTeam(1)
	else
		ListFactoryTeam(myTeamID)
	end
	RecreateFacbar()
end

------------------------------------------------------

function widget:DrawWorld()
	-- Draw factories command lines
	if waypointMode>1 then
		local unitID
		if waypointMode>1 then
			unitID = facs[waypointFac].unitID
		end
		DrawUnitCommands(unitID)
	end
end

function widget:UnitCreated(unitID, unitDefID, unitTeam)
	if (unitTeam ~= myTeamID and not SPECMODE_1V1) then
		return
	end
	if not facDefID[unitDefID] then
		return
	end
	local bo =  UnitDefs[unitDefID].buildOptions
	if bo and bo[1] then
		push(facs,{ unitID=unitID, unitDefID=unitDefID, allyTeamID = Spring.GetUnitAllyTeam(unitID), buildList=UnitDefs[unitDefID].buildOptions })
		--UpdateFactoryList()
		RecreateFacbar()
	end
	unfinished_facs[unitID] = true
end

function widget:UnitGiven(unitID, unitDefID, unitTeam, oldTeam)
	widget:UnitCreated(unitID, unitDefID, unitTeam)
end

function widget:UnitDestroyed(unitID, unitDefID, unitTeam)
	if (unitTeam ~= myTeamID and not SPECMODE_1V1) then
		return
	end
	if not facDefID[unitDefID] then
		return
	end
	for i,facInfo in ipairs(facs) do
		if unitID==facInfo.unitID then
			
			table.remove(facs,i)
			unfinished_facs[unitID] = nil
			--UpdateFactoryList()
			RecreateFacbar()
			return
		end
	end
end

function widget:UnitTaken(unitID, unitDefID, unitTeam, newTeam)
	widget:UnitDestroyed(unitID, unitDefID, unitTeam)
end


function widget:PlayerChanged(playerID)
	if myPlayerID ~= playerID then
		return
	end
	local myNewAllyTeamID = Spring.GetMyAllyTeamID()
	local myNewTeamID = Spring.GetMyTeamID()
	-- Echo("myAllyTeamID is ", myAllyTeamID)
	if SPECMODE_1V1 ~= nil then
		
		local spectating, fullread = Spring.GetSpectatingState()
		if SPECMODE_1V1 == false then
			if fullread then -- add the other player facs
				-- Echo('add team facs',myAllyTeamID == 0 and 1 or 0)
				if force_update then
					UpdateFactoryList()
					force_update = false
				else
					ListFactoryTeam(myTeamID == 0 and 1 or 0)
					RecreateFacbar()
				end
				myAllyTeamID = myNewAllyTeamID
				myTeamID = myNewTeamID
				SPECMODE_1V1 = true
				return
			else
				if myAllyTeamID == myNewAllyTeamID then
					if force_update then
						UpdateFactoryList()
						force_update = false
					end
					return -- nothing to do
				end
			end
		else
			if fullread then
				myAllyTeamID = myNewAllyTeamID
				myTeamID = myNewTeamID

				if force_update then
					UpdateFactoryList()
					force_update = false
				end
				return -- nothing todo we still track both team
			end
			SPECMODE_1V1 = false
		end
	end
	myAllyTeamID = myNewAllyTeamID
	myTeamID = myNewTeamID

	UpdateFactoryList()
end

function widget:Update()
	inTweak = widgetHandler.tweakMode
	
	cycle_half_s = (cycle_half_s % 16) + 1
	cycle_2_s = (cycle_2_s % (32*2)) + 1
	
	
	if cycle_half_s == 1 then
		for i,facInfo in ipairs(facs) do
			if Spring.ValidUnitID( facInfo.unitID ) then
				if cycle_2_s == 1 then
					UpdateFac(i, facInfo)
				end
				UpdateFacQ(i, facInfo)
			end
		end
	end
	
	
	if inTweak and not enteredTweak then
		enteredTweak = true
		stack_main:ClearChildren()
		for i = 1,5 do
			local facStack, boStack, qStack, qStore = AddFacButton(0, 0, stack_main, i)
		end
		stack_main:Invalidate()
		stack_main:UpdateLayout()
		if stack_main2 then
			stack_main2:ClearChildren()
			for i = 1,5 do
				local facStack, boStack, qStack, qStore = AddFacButton(0, 0, stack_main2, i)
			end
			stack_main2:Invalidate()
			stack_main2:UpdateLayout()
		end
		leftTweak = true
	end
	
	if not inTweak and leftTweak then
		enteredTweak = false
		leftTweak = false
		RecreateFacbar()
	end
end



-------------------------------------------------------------------------------
-------------------------------------------------------------------------------


function widget:SelectionChanged(selectedUnits)
	if facs[pressedFac] then
		local qStack = facs[pressedFac].qStack
		local boStack = facs[pressedFac].boStack
		facs[pressedFac].facStack:RemoveChild(boStack)
		facs[pressedFac].facStack:AddChild(qStack)
	end

	pressedFac = -1
	
	if (#selectedUnits == 1) then
		for cnt, f in ipairs(facs) do
			if f.unitID == selectedUnits[1] then
				pressedFac = cnt
				
				local qStack = facs[pressedFac].qStack
				local boStack = facs[pressedFac].boStack
				facs[pressedFac].facStack:RemoveChild(qStack)
				facs[pressedFac].facStack:AddChild(boStack)
			end
		end
	end
end


function widget:MouseRelease(x, y, button)
	if (waypointMode>0)and(not inTweak) and (waypointMode>0)and(waypointFac>0) then
		WaypointHandler(x,y,button)
	end
	return -1
end

function widget:MousePress(x, y, button)
	-- if not DONE then
	-- 	window_facbar:SetPos(winx, winy)
	-- 	window_facbar2:SetPos(win2x, win2y)
	-- 	DONE = true
	-- end

	if waypointMode>1 then
		-- greedy waypointMode
		return (button~=2) -- we allow middle click scrolling in greedy waypoint mode
	end
	if waypointMode>1 then
		Spring.Echo("FactoryBar: Exited easy waypoint mode")
		Spring.PlaySoundFile(sound_waypoint, 1, 'ui')
	end
	waypointFac  = -1
	waypointMode = 0
	return false
end

local function CreateWin(winx, winy, i, title)
	-- setup Chili
	local stack = Grid:New{
		padding = {0,0,0,0},
		itemPadding = {0, 0, 0, 0},
		itemMargin = {0, 0, 0, 0},
		width='100%',
		height = '100%',
		resizeItems = false,
		orientation = 'horizontal',
		centerItems = false,
		columns=2,
	}
	local titlectrl = Label:New{ 
		x = 2,
		caption = title or WG.Translate("interface", "factories"),
		-- padding = 
	}
	local win = Window:New{

		padding = {3,3,3,3,},
		dockable = true,
		name = "facbar_win" .. i,
		x = winx, y = winy,
		width  = 600,
		height = 200,
		parent = Chili.Screen0,
		draggable = false,
		tweakDraggable = true,
		tweakResizable = true,
		resizable = false,
		dragUseGrip = false,
		minWidth = 56,
		minHeight = 56,
		color = {0,0,0,0},
		children = {
			titlectrl,
			stack,
		},
		OnMouseDown={ function(self)
			local alt, ctrl, meta, shift = Spring.GetModKeyState()
			if not meta then return false end
			WG.crude.OpenPath(options_path)
			WG.crude.ShowMenu()
			return true
		end },
	}
	local font = titlectrl.font
	font.autoOutlineColor = false
	return win, stack, titlectrl
end
local function ShowTitle(stack, title, bool)
	if not (stack and title) then
		return
	end
	if bool and not stack.children[1] then
		bool = false
	end
	if title.hidden ~= not bool then
		stack.y = bool and 10 or 0
		if bool then
			title:Show()
		else
			title:Hide()
		end
	end
end
function ShowTitles(bool)
	if stack_main then
		ShowTitle(stack_main, title, bool)
	end
	if stack_main2 then
		ShowTitle(stack_main2, title2, bool)
	end
end

local function GetOpposingAllyTeams()
	local gaiaAllyTeamID = select(6, Spring.GetTeamInfo(Spring.GetGaiaTeamID(), false))
	local allyObjs = {}
	local allyTeamList = GetLeftRightAllyTeamIDs()
	for i = 1, #allyTeamList do
		local allyTeamID = allyTeamList[i]

		local teamList = Spring.GetTeamList(allyTeamID)

		if allyTeamID ~= gaiaAllyTeamID and teamList[1] then
			local name = Spring.GetGameRulesParam("allyteam_long_name_" .. allyTeamID)
			-- if string.len(name) > 10 then
			-- 	name = Spring.GetGameRulesParam("allyteam_short_name_" .. allyTeamID)
			-- end
			allyObjs[i] = {
				allyTeamID = allyTeamID, 
				name = name, 
				teamID = teamList[1], 
				color = {Spring.GetTeamColor(teamList[1])} or {1,1,1,1},
			}
		end
	end
	if #allyObjs ~= 2 then
		return
	end
	return allyObjs[1], allyObjs[2]
end

local function strColor(str, c)
	return table.concat({
		'\255',
		string.char(math.floor(c[1]*255)),
		string.char(math.floor(c[2]*255)),
		string.char(math.floor(c[3]*255)),
		str,
		'\008'
	})
	-- return '\255' .. string.char(math.floor(c[1]*255))..string.char(math.floor(c[2]*255))..string.char(math.floor(c[3]*255)) .. str .. '\008'
end


function widget:Initialize()
	-- if true then
	-- 	widgetHandler:RemoveWidget(widget)
	-- 	return
	-- end
	if (not WG.Chili) then
		widgetHandler:RemoveWidget(widget)
		return
	end
	local spectating, fullread = Spring.GetSpectatingState()
	if not spectating and not options.active.value then
		options.active:OnChange()
		return
	elseif spectating and not options.spec_active.value then
		option.spec_active:OnChange()
		return
	end
	myAllyTeamID = Spring.GetMyAllyTeamID()
	myTeamID = Spring.GetMyTeamID()

	-- Echo('myTeamID',myTeamID,'myAllyTeamID',myAllyTeamID)
	if spectating then
		local teams = Spring.GetTeamList()
		if teams[3] and not teams[4] then
			LEFT, RIGHT = GetOpposingAllyTeams()
			LEFT.tooltip = strColor(LEFT.name, LEFT.color)
			RIGHT.tooltip = strColor(RIGHT.name, RIGHT.color)
			SPECMODE_1V1 = fullread
		end
	end
	self:ViewResize(widgetHandler:GetViewSizes())

	Chili = WG.Chili
	Button = Chili.Button
	Label = Chili.Label
	Window = Chili.Window
	StackPanel = Chili.StackPanel
	Grid = Chili.Grid
	TextBox = Chili.TextBox
	Image = Chili.Image
	Progressbar = Chili.Progressbar
	screen0 = Chili.Screen0

	local winx, winy, win2x, win2y
	if SPECMODE_1V1 ~= nil then
		winx, winy, win2x, win2y = vsx * 1/10, vsy * 1/9, vsx * (1/2 + 1/20), vsy * 1/9
		winx, winy, win2x, win2y = math.round(winx), math.round(winy), math.round(win2x), math.round(win2y) -- if not rounded the controls are blurry
		window_facbar, stack_main, title = CreateWin(winx, winy, 1, LEFT.tooltip)
		window_facbar2, stack_main2, title2 = CreateWin(win2x, win2y, 2, RIGHT.tooltip)
	else
		winx, winy = 0, '30%'
		window_facbar, stack_main, title = CreateWin(winx, winy, '')
	end
	ShowTitles(options.show_title.value)
	initialized = true

	UpdateFactoryList()
end

function widget:Shutdown()
	if window_facbar then
		window_facbar:Dispose()
		window_facbar = nil
	end
	if window_facbar2 then
		window_facbar2:Dispose()
		window_facbar2 = nil
	end
	if stack_main then
		stack_main:Dispose()
		stack_main = nil
	end
	if stack_main2 then
		stack_main2:Dispose()
		stack_main2 = nil
	end
	if title then
		title:Dispose()
		title = nil
	end
	if title2 then
		title2:Dispose()
		title2 = nil
	end
	initialized = false
end

f.DebugWidget(widget)
