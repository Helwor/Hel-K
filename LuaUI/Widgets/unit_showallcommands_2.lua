-- $Id$
function widget:GetInfo()
  return {
    name      = "Show All Commands v2",
    desc      = "Populates the 'Settings/Interface/Command Visibility' option set",
    author    = "Google Frog, msafwan",
    date      = "Mar 1, 2009, July 1 2013",
    license   = "GNU GPL, v2 or later",
    layer     = 0,
    enabled   = true  --  loaded by default?
  }
end
local Echo = Spring.Echo
--Changelog:
--July 1 2013 (msafwan add chili radiobutton and new options!)
--NOTE: this options will behave correctly if "alwaysDrawQueue == 0" in cmdcolors.txt

-------------
local includeAllySel 	= false
local includeAllies 	= true
local includeNeutral 	= true
local cacheTargTypes 	= true
local debugMe 			= false
-------------


local spDrawUnitCommands      = Spring.DrawUnitCommands
local spGetAllUnits           = Spring.GetAllUnits
local spIsGUIHidden           = Spring.IsGUIHidden
local spGetModKeyState        = Spring.GetModKeyState
local spGetUnitAllyTeam       = Spring.GetUnitAllyTeam
local spGetSelectedUnits      = Spring.GetSelectedUnits
local spGetUnitPosition       = Spring.GetUnitPosition
local spGetUnitRulesParam     = Spring.GetUnitRulesParam
local spGetUnitTeam           = Spring.GetUnitTeam
local spGetUnitCurrentCommand = Spring.GetUnitCurrentCommand
local spGetUnitDefID		  = Spring.GetUnitDefID
local spAreTeamsAllied		  = Spring.AreTeamsAllied
local spGetTimer			  = Spring.GetTimer
local spDiffTimers			  = Spring.DiffTimers

local glVertex      = gl.Vertex
local glPushAttrib  = gl.PushAttrib
local glLineStipple = gl.LineStipple
local glDepthTest   = gl.DepthTest
local glLineWidth   = gl.LineWidth
local glColor       = gl.Color
local glBeginEnd    = gl.BeginEnd
local glPopAttrib   = gl.PopAttrib
local glCreateList  = gl.CreateList
local glCallList    = gl.CallList
local glDeleteList  = gl.DeleteList
local GL_LINES      = GL.LINES

-- Constans
local TARGET_NONE = 0
local TARGET_GROUND = 1
local TARGET_UNIT= 2

local CMD_ATTACK = CMD.ATTACK
local setTargetAlpha = math.min(0.5, (tonumber(Spring.GetConfigString("CmdAlpha") or "0.7") or 0.7))


local selectedUnitCount = 0
local selectedUnits = {}

local Units = {}
local canTarget = {}
local unitCount = 0


local commandLevel = 4

local spectating 
local myAllyTeamID
local myTeamID
local myPlayerID

local gaiaTeamID

local setTargetUnitDefIDs = {}
for i = 1, #UnitDefs do
	local ud = UnitDefs[i]
	if ((not (ud.canFly and ((ud.isBomber or ud.isBomberAirUnit) and not ud.customParams.can_set_target))) and
			ud.canAttack and ud.canMove and ud.maxWeaponRange and ud.maxWeaponRange > 0) or ud.isFactory then
		setTargetUnitDefIDs[i] = true
	end
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local clear = function(t)
	for k in pairs(t) do
		t[k] = nil
	end
end



local function UpdateSelection(newSelectedUnits)
	clear(selectedUnits)
	selectedUnitCount = 0
	for _, id in pairs(newSelectedUnits) do
		selectedUnitCount = selectedUnitCount + 1
		selectedUnits[id] = true
	end
end



options_path = 'Settings/Interface/Command Visibility'
options_order = {
	'showallcommandselection','lbl_filters','includeallies', 'includeallysel', 'includeneutral','cachetargtypes'
	,'debugme'
}
options = {
	showallcommandselection = {
		type='radioButton',
		name='Commands are drawn for',
		items = {
			{name = 'All units',
				key='showallcommand',
				desc="Command always drawn on all units.", hotkey=nil},
			{name = 'Selected units, All with SHIFT',
				key='onlyselection',
				desc="Command always drawn on selected unit, pressing SHIFT will draw it for all units.", hotkey=nil},
			{name = 'Selected units',
				key='onlyselectionlow',
				desc="Command always drawn on selected unit.", hotkey=nil},
			{name = 'All units with SHIFT',
				key='showallonshift',
				desc="Commands always hidden, but pressing SHIFT will draw it for all units.", hotkey=nil},
			{name = 'Selected units on SHIFT',
				key='showminimal',
				desc="Commands always hidden, pressing SHIFT will draw it on selected units.", hotkey=nil},
		},
		value = 'onlyselection',  --default at start of widget
		OnChange = function(self)
			local key = self.value
			UpdateSelection(spGetSelectedUnits())
			commandLevel = 	key == 'showallcommand' 	and 5
						or 	key == 'onlyselection' 		and 4
					 	or 	key == 'onlyselectionlow'  	and 3
						or  key == 'showallonshift' 	and 2
						or	key == 'showminimal'		and 1
			
			if key == 'showminimal' or key == 'showallonshift' then
				Echo('draw queue set to 0')
				Spring.LoadCmdColorsConfig("alwaysDrawQueue 0")
			else
				Echo('draw queue set to 1')
				Spring.LoadCmdColorsConfig("alwaysDrawQueue 1")
			end
		end,
	},
	lbl_filters = {name='Filters', type='label'},
	includeallies = {
		name = 'Include ally selections',
		desc = 'When showing commands for selected units, show them for both your own and your allies\' selections.',
		type = 'bool',
		value = includeAllySel,
		OnChange = function(self)
			includeAllySel = self.value
			widgetHandler:UpdateCallIn("GameFrame")
		end
	},
	includeallysel = {
		name = 'Include ally units',
		desc = 'When showing commands, show them for both your own and your allies units.',
		type = 'bool',
		value = includeAllies,
		OnChange = function(self)
			includeAllies = self.value
			widgetHandler:UpdateCallIn("GameFrame")
		end,
	},
	includeneutral = {
		name = 'Include Neutral Units',
		desc = 'Toggle whether to show commands for neutral units (relevant while spectating).',
		type = 'bool',
		value = includeNeutral,
		OnChange = function(self)
			includeNeutral = self.value
			widgetHandler:UpdateCallIn("GameFrame")
		end,
	},
	cachetargtypes = {
		name = 'Cache Target Type',
		desc = 'Getting target types is very taxing, updating slowly',
		type = 'bool',
		value = cacheTargTypes,
		OnChange = function(self)
			cacheTargTypes = self.value
		end,
	},
	debugme = {
		name = 'Console Debug',
		value = debugMe,
		type = 'bool',
		OnChange = function(self)
			debugMe = self.value
		end,
	},
}



--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- Unit Handling



local function AddUnit(unitID, unitDefID)
	if Units[unitID]==nil then
		Units[unitID] = setTargetUnitDefIDs[unitDefID] or false
		unitCount = unitCount + 1
	end
end

local function RemoveUnit(unitID)
	if Units[unitID] ~= nil then
		Units[unitID] = nil
		unitCount = unitCount - 1
	end
end

function PoolUnit()
	clear(Units)
	clear(canTarget)
	unitCount = 0
	for _, unitID in ipairs(spGetAllUnits()) do
		widget:UnitCreated(unitID, spGetUnitDefID(unitID), spGetUnitTeam(unitID))
	end
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- Drawing
local drawList = 0

local function GetDrawLevel()
	local shiftHeld = select(4,spGetModKeyState())
	if commandLevel == 1 then 
		return shiftHeld, false, shiftHeld
	elseif commandLevel == 2 then
		return false, shiftHeld, shiftHeld
	elseif commandLevel == 3 then
		return true, false, true
	elseif commandLevel == 4 then
		return true, shiftHeld, true
	else -- commandLevel == 5
		return true, true, true
	end
end
-- spGetUnitRulesParam(unitID,"target_type") is very taxing when a lot of units are involved so we just check it if a SET_TARGET command has been received

local cache = {targetTypes = {time=os.clock()}, towards = {}, targetPos = {time=os.clock()}, pos = {} }
local GetTargetType = function(unitID, useCache)
	if not useCache then
		return spGetUnitRulesParam(unitID,"target_type") or TARGET_NONE
			,spGetUnitRulesParam(unitID,"target_towards")

	end
	local targetTypes = cache.targetTypes
	local towards = cache.towards
	if not targetTypes[unitID] then
		targetTypes[unitID] = spGetUnitRulesParam(unitID,"target_type") or TARGET_NONE
		towards[unitID] = spGetUnitRulesParam(unitID,"target_towards")
	end
	return targetTypes[unitID], towards[unitID]
end


local function getTargetPosition(unitID, useCache)
	local target_type, fireTowards = GetTargetType(unitID, useCache)
	if fireTowards == 0 then
		fireTowards = false
	end
	useCache = false
	if useCache then
		if cache.targetPos[unitID] then
			return unpack(cache.targetPos[unitID])
		end
	end
	local tx, ty, tz
	
	if target_type == TARGET_GROUND then
		tx = spGetUnitRulesParam(unitID, "target_x")
		ty = spGetUnitRulesParam(unitID, "target_y")
		tz = spGetUnitRulesParam(unitID, "target_z")
	elseif target_type == TARGET_UNIT then
		local targetID = spGetUnitRulesParam(unitID, "target_id")
		local cmdID, cmdOpts, _, cmdParam1, cmdParam2 = spGetUnitCurrentCommand(unitID)
		if cmdID == CMD_ATTACK and cmdParam1 == targetID and not cmdParam2 then
			-- Do not draw set target and attack on the same target.
			return nil
		end
		if targetID and targetID ~= 0 and Spring.ValidUnitID(targetID) then
			_, _, _, tx, ty, tz = spGetUnitPosition(targetID, true)
		else
			return nil
		end
	else
		return nil
	end
	if useCache then
		cache.targetPos[unitID] = {tx, ty, tz, fireTowards}
	end
	return tx, ty, tz, fireTowards
end
local GL_LINES = GL.LINES
local drawline = function(x,y,z, x2, y2, z2)
	glVertex(x,y,z)
	glVertex(x2,y2,z2)
end
local function DrawUnitTarget(unitID,useCache)
	if not unitID then
		return
	end
	
	local tx,ty,tz,fireTowards = getTargetPosition(unitID, useCache)
	if tx then
		local _,x,y,z
		useCache = false
		if useCache then

			if cache.pos[unitID] then
				x,y,z = unpack(cache.pos[unitID])
			else
				_,_,_,x,y,z = spGetUnitPosition(unitID,true)
				cache.pos[unitID] = {x,y,z}
			end
		else
			_,_,_,x,y,z = spGetUnitPosition(unitID,true)
		end
		if fireTowards then
			local dist = ((x - tx)^2 + (y - ty)^2 + (z - tz)^2) ^0.5
			if dist < fireTowards then
				glColor(1, 0.8, 0, setTargetAlpha)
				glBeginEnd(GL_LINES,drawline, x,y,z, tx, ty, tz)
			else
				local mult = fireTowards / dist
				local mx, my, mz = (tx - x)*mult + x, (ty - y)*mult + y, (tz - z)*mult + z
				glColor(1, 0.8, 0, setTargetAlpha)
				glBeginEnd(GL_LINES,drawline, x,y,z, mx, my, mz)
				glColor(1, 1, 0, setTargetAlpha)
				glBeginEnd(GL_LINES,drawline, tx,ty,tz, mx, my, mz)
			end
		else
			glColor(1, 0.8, 0, setTargetAlpha)
			glBeginEnd(GL_LINES,drawline, x,y,z, tx, ty, tz)
		end
	end
end


local dbgcount, dbgmaxcount = 0, 250
local dbgtime = 'not yet calculated'
local time = 0

local function updateDrawing()
	-- if true then
	-- 	return
	-- end
	local drawSelected, drawAll, selectedAlreadyDrawn = GetDrawLevel()
	local redrawSelection = not selectedAlreadyDrawn or selectedUnitCount < 75 -- redraw Selection for a brighter command when not too many units are selected
	local n = 0
	local toDraw = {}
	local timer
	if debugMe then
		timer = spGetTimer()
		dbgcount = dbgcount + 1
	end
	-- Echo("drawSelected, drawAll is ", drawSelected, drawAll)
	if cacheTargTypes then
		local now = os.clock()
		if now - cache.targetTypes.time > 0.6 then
			clear(cache.targetTypes)
			cache.targetTypes.time = now
			clear(cache.towards)
		end
		if now - cache.targetPos.time > 0.15 then
			clear(cache.targetPos)
			cache.targetPos.time = now
			clear(cache.pos)
		end
	end
	if drawAll then
		local useCache = cacheTargTypes and unitCount > 300
		for id, canTarget in pairs(Units) do
			if canTarget then
				DrawUnitTarget(id,useCache)
			end
			if not selectedUnits[id] or redrawSelection then
				n = n + 1
				toDraw[n] = id
			end
		end
	elseif drawSelected then
		local useCache = cacheTargTypes and selectedUnitCount > 100
		for id, canTarget in pairs(selectedUnits) do
			if canTarget then -- canTarget
				DrawUnitTarget(id,useCache)
			end
			if redrawSelection then
				n = n + 1
				toDraw[n] = id
			end
		end
		if includeAllySel then

			local allySelUnits = WG.allySelUnits
			local useCache = cacheTargTypes and table.size(allySelUnits) > 100
			for id in pairs(allySelUnits) do
				if includeAllies and Units[id] or canTarget[id] then -- canTarget
					DrawUnitTarget(id,useCache)
				end
				n = n + 1
				toDraw[n] = id
			end
		end
	end
	if n > 0 then
		spDrawUnitCommands(toDraw)
	end
	if debugMe then
		time = time + spDiffTimers(spGetTimer(), timer)
		if dbgcount == dbgmaxcount then
			dbgtime = time / dbgmaxcount
			dbgcount = 0
			time = 0
		end
		Echo(
			drawAll and 'DRAW ALL' or drawSelected and 'DRAW SEL'
			,'averagetime',dbgtime
			,"redrawSelection is ", redrawSelection,'toDraw:',n,'selectedAlreadyDrawn, ',selectedAlreadyDrawn,'size slected',table.size(selectedUnits)
		)
	end

end

function widget:Update()
	if drawList ~= 0 then
		glDeleteList(drawList)
		drawList = 0
	end
	
	if not spIsGUIHidden() then
		drawList = glCreateList(updateDrawing)
	end
end

function widget:DrawWorld()
	if drawList ~= 0 then
		glPushAttrib(GL.LINE_BITS)
		glLineStipple("springdefault")
		glDepthTest(false)
		glLineWidth(1)
		glCallList(drawList)
		updateDrawing()
		glColor(1, 1, 1, 1)
		glLineStipple(false)
		glPopAttrib()
	end
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- Callins
function widget:SelectionChanged(newSelection)
	UpdateSelection(newSelection)
end

function widget:PlayerChanged(playerID)
	if myPlayerID == playerID then
		spectating = Spring.GetSpectatingState()
		myAllyTeamID = Spring.GetLocalAllyTeamID()
		myTeamID = Spring.GetMyTeamID()
		PoolUnit()
	end
end

function widget:UnitCreated(unitID, unitDefID, teamID)
	if spectating and (teamID ~= gaiaTeamID or includeNeutral)
	or teamID == myTeamID 
	then
		AddUnit(unitID, unitDefID)
	elseif spAreTeamsAllied(myTeamID, teamID) then
		if includeAllies then
			AddUnit(unitID, unitDefID)
		elseif includeAllySel then
			canTarget[unitID] = setTargetUnitDefIDs[unitDefID]
		end
	end
end

function widget:UnitGiven(unitID, unitDefID, teamID, oldTeamID)
	if spectating and (teamID ~= gaiaTeamID or includeNeutral)
	or teamID == myTeamID 
	then
		AddUnit(unitID, unitDefID)
	elseif spAreTeamsAllied(myTeamID, teamID) then
		if includeAllies then
			AddUnit(unitID, unitDefID)
		elseif includeAllySel then
			canTarget[unitID] = setTargetUnitDefIDs[unitDefID]
		end
	else
		RemoveUnit(unitID)
	end
end
function widget:UnitTaken(unitID)
	RemoveUnit(unitID)
end
function widget:UnitDestroyed(unitID)
	RemoveUnit(unitID)
end

function widget:GameFrame(n)
	if (n > 0) then
		PoolUnit()
		widgetHandler:RemoveCallIn("GameFrame")
	end
end
function widget:Initialize()
	widget:PlayerChanged(myPlayerID)
	options.showallcommandselection:OnChange()
end