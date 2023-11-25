--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function widget:GetInfo()
	return {
		name      = "Factory Plate Placer",
		desc      = "Replaces factory placement with plates of the appropriate type, and integrates CMD_BUILD_PLATE behaviour",
		author    = "GoogleFrog/DavetheBrave",
		date      = "23 September 2021",
		license   = "GNU GPL, v2 or later",
		layer     = -1,
		enabled   = true,
	}
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- Speedup
local Echo = Spring.Echo


include("keysym.lua")
VFS.Include("LuaRules/Utilities/glVolumes.lua")
local GetMiniMapFlipped = Spring.Utilities.IsMinimapFlipped
include("LuaRules/Configs/customcmds.h.lua")

local spGetActiveCommand = Spring.GetActiveCommand
local spSetActiveCommand = Spring.SetActiveCommand
local spTraceScreenRay   = Spring.TraceScreenRay
local spGetMouseState    = Spring.GetMouseState
local spGetGroundHeight  = Spring.GetGroundHeight
local spGetUnitDefID     = Spring.GetUnitDefID

local floor = math.floor
local mapX = Game.mapSizeX
local mapZ = Game.mapSizeZ

local glColor               = gl.Color
local glLineWidth           = gl.LineWidth
local glDepthTest           = gl.DepthTest
local glTexture             = gl.Texture
local glDrawCircle          = gl.Utilities.DrawCircle
local glDrawGroundCircle    = gl.DrawGroundCircle
local glPopMatrix           = gl.PopMatrix
local glPushMatrix          = gl.PushMatrix
local glTranslate           = gl.Translate
local glBillboard           = gl.Billboard
local glText                = gl.Text
local glScale               = gl.Scale
local glRotate              = gl.Rotate
local glLoadIdentity        = gl.LoadIdentity
local glLineStipple         = gl.LineStipple

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

options_path = 'Settings/Interface/Building Placement'
options_order = { 'ctrl_toggle'}
options = {
	ctrl_toggle = {
		name = "Ctrl toggles Factory/Plate",
		type = 'bool',
		value = false,
		noHotkey = true,
		desc = 'When placing a factory or plate, press Ctrl to select whether a factory or construction plate is placed.',
	},
}

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local FACTORY_RANGE_SQ = VFS.Include("gamedata/unitdefs_pre.lua", nil, VFS.GAME).FACTORY_PLATE_RANGE^2

local outCircle = {
	range = math.sqrt(FACTORY_RANGE_SQ),
	color = {0.8, 0.8, 0.8, 0.4},
	width = 2.5,
	miniWidth = 1.5,
	circleDivs = 128
}

local inCircle = {
	range = math.sqrt(FACTORY_RANGE_SQ),
	color = {0.1, 1, 0.3, 0.6},
	width = 2.5,
	miniWidth = 1.5,
	circleDivs = 128
}

local oddX = {}
local oddZ = {}
local buildAction = {}
local childOfFactory = {}
local parentOfPlate = {}
local floatOnWater = {}

for i = 1, #UnitDefs do
	local ud = UnitDefs[i]
	local cp = ud.customParams
	if (cp.parent_of_plate or cp.child_of_factory) then
		buildAction[i] = "buildunit_" .. ud.name
		oddX[i] = (ud.xsize % 4)*4
		oddZ[i] = (ud.zsize % 4)*4
		floatOnWater[i] = ud.floatOnWater
		
		if cp.child_of_factory then
			childOfFactory[i] = UnitDefNames[cp.child_of_factory].id
		end
		if cp.parent_of_plate then
			parentOfPlate[i] = UnitDefNames[cp.parent_of_plate].id
		end
	end
end

local myPlayerID = Spring.GetLocalPlayerID()
local myAllyTeamID = Spring.GetMyAllyTeamID()

local IterableMap = VFS.Include("LuaRules/Gadgets/Include/IterableMap.lua")
local factories = IterableMap.New()

local buildPlateCommand
local buildFactoryDefID
local buildPlateDefID
local closestFactoryData
local activeCmdOverride
local cmdFactoryDefID
local cmdPlateDefID

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local function DistSq(x1, z1, x2, z2)
	return (x1 - x2)*(x1 - x2) + (z1 - z2)*(z1 - z2)
end

local spGetSelectedUnitsSorted = Spring.GetSelectedUnitsSorted
local spGetCommandQueue = Spring.GetCommandQueue
local function copy(t)
	local c = {}
	for k, v in pairs(t) do
		c[k] = v
	end
	return c
end
local function merge(T,t)
	for k,v in pairs(t) do
		T[k] = v
	end
end
local builderDefID = {}
for defID, def in pairs(UnitDefs) do
	if def.isFactory then
		--
    elseif def.isBuilder and def.canAssist then
        builderDefID[defID] = true
    end
end

local tempQueue

function widget:CommandNotify(cmd, params, opts)

	if cmd < 0 and parentOfPlate[-cmd] then
		if not tempQueue then
			tempQueue = {}
		end
		tempQueueClock = os.clock()
		tempQueue[params[1] .. '-' .. params[3]] = {unitDefID = -cmd, x = params[1], y = params[2], z = params[3], queued = true}
	end
end

local FormatTime = function(n)
    local h = math.floor(n/3600)
    h = h>0 and h
    local m = math.floor( (n%3600) / 60 )
    m = (h or m>0) and m
    local s = ('%.3f'):format(n%60)
    return (h and h .. ':' or '') .. (m and m .. ':' or '') .. s
end
local spGetGameSeconds = Spring.GetGameSeconds

function widget:UnitCommand(id, _,_,cmd, params,opts)
	if tempQueue then
		if cmd == 1 then -- insertion case
			cmd = params[2]
			params[1], params[3] = params[4], params[6]
		end
		if cmd < 0 then
			if not params[1] then
				Echo(FormatTime(spGetGameSeconds()),'build order ' ,cmd , " don't have params.")
			elseif tempQueue[params[1] .. '-' .. params[3]] and tempQueue[params[1] .. '-' .. params[3]].unitDefID == -cmd then
				-- the order has been received
				tempQueue = false
			end
		end
	end
end

local function GetQueuedFactories()
	local t = spGetSelectedUnitsSorted()
	
	if tempQueue and tempQueueClock + 1 < os.clock() then
		tempQueue = false
	end
	local ret = tempQueue or {}
	if not t then
		return ret
	end
	for defID, units in pairs(t) do
		if builderDefID[defID] then
			for i, id in ipairs(units) do
				local queue = spGetCommandQueue(id, -1)
				if queue then
					for i, order in ipairs(queue) do
						if order.id < 0 and parentOfPlate[-order.id] then
							local x,y,z = unpack(order.params)
							if not ret[x .. '-' .. z] then
								ret[x .. '-' .. z] = {unitDefID = -order.id, x=x, y=y, z=z, queued = true}
							end
						end
					end
				end
			end
		end
	end
	return ret
end


local function GetClosestFactory(x, z, unitDefID)
	local nearID, nearDistSq, nearData, isQueued
	-- if building a specific factory
	local allfacs = GetQueuedFactories()
	for unitID, data in IterableMap.Iterator(factories) do
		allfacs[unitID] = data
	end
	if unitDefID then
		for unitID, data in pairs(allfacs) do
			if data.unitDefID == unitDefID then
				local dSq = DistSq(x, z, data.x, data.z)
				if (not nearDistSq) or (dSq < nearDistSq) then
					nearID = unitID
					nearDistSq = dSq
					nearData = data
					isQueued = data.queued
				end
			end
		end
	-- otherwise if using CMD_BUILD_PLATE
	else
		for unitID, data in pairs(allfacs) do
			local dSq = DistSq(x, z, data.x, data.z)
			if (not nearDistSq) or (dSq < nearDistSq) then
				nearID = unitID
				nearDistSq = dSq
				nearData = data
				isQueued = data.queued
			end
		end
	end
	return nearID, nearDistSq, nearData, isQueued
end

local function SnapBuildToGrid(mx, mz, unitDefID)
	local facing = Spring.GetBuildFacing()
	local offFacing = (facing == 1 or facing == 3)
	if offFacing then
		mx = math.floor((mx + 8 - oddZ[unitDefID])/16)*16 + oddZ[unitDefID]
		mz = math.floor((mz + 8 - oddX[unitDefID])/16)*16 + oddX[unitDefID]
	else
		mx = math.floor((mx + 8 - oddX[unitDefID])/16)*16 + oddX[unitDefID]
		mz = math.floor((mz + 8 - oddZ[unitDefID])/16)*16 + oddZ[unitDefID]
	end
	return mx, mz
end
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local function GetMousePos(ignoreWater)
	local mouseX, mouseY = spGetMouseState()
	local _, mouse = spTraceScreenRay(mouseX, mouseY, true, true, false, ignoreWater)
	if not mouse then
		return
	end
	
	return mouse[1], mouse[3]
end

local function CheckTransformPlateIntoFactory(plateDefID, shift)
	local mx, mz = GetMousePos(not floatOnWater[plateDefID])
	if not mx then
		return
	end
	
	local factoryDefID = childOfFactory[plateDefID]
	mx, mz = SnapBuildToGrid(mx, mz, plateDefID) -- Make sure the plate is in range when it is placed
	local unitID, distSq, factoryData, isQueued = GetClosestFactory(mx, mz, factoryDefID)
	
	if not unitID or isQueued and not shift then
		local cmdName = select(4, spGetActiveCommand())
		if cmdName and ('buildunit_'..cmdName) == buildAction[plateDefID] then
			spSetActiveCommand(buildAction[factoryDefID])
		end
		return
	end
	closestFactoryData = factoryData
	if distSq >= FACTORY_RANGE_SQ then
		spSetActiveCommand(buildAction[factoryDefID])
	end
	return true
end



local function CheckTransformFactoryIntoPlate(factoryDefID, shift)
	local mx, mz = GetMousePos(not floatOnWater[factoryDefID])
	if not mx then
		return
	end
	local plateDefID = parentOfPlate[factoryDefID]
	mx, mz = SnapBuildToGrid(mx, mz, plateDefID) -- Make sure the plate is in range when it is placed
	local unitID, distSq, factoryData, isQueued = GetClosestFactory(mx, mz, factoryDefID)
	
	if not unitID then
		return
	end
	
	-- Plates could be disabled by modoptions or otherwise unavailible.
	local cmdDescID = Spring.GetCmdDescIndex(-plateDefID)
	if not cmdDescID then
		return
	end
	
	closestFactoryData = factoryData
	if distSq < FACTORY_RANGE_SQ and plateDefID then

		if not isQueued or shift then
			spSetActiveCommand(buildAction[plateDefID])
			return true
		else 
			local cmdName = select(4, spGetActiveCommand())
			if cmdName and ('buildunit_'..cmdName) == buildAction[plateDefID] then
				spSetActiveCommand(buildAction[factoryDefID])
			end
		end
	end
	return
end

local function MakePlateFromCMD()
	local mx, mz = GetMousePos()
	if not mx then
		return
	end

	local unitID, distSq, factoryData = GetClosestFactory(mx, mz)
	if not unitID then
		return
	end

	local factoryDefID = spGetUnitDefID(unitID)
	local plateDefID = parentOfPlate[factoryDefID]
	if not floatOnWater[plateDefID] and Spring.GetGroundHeight(mx, mz) < 0 then
		mx, mz = GetMousePos(true)
		if not mx then
			return
		end
		unitID, distSq, factoryData = GetClosestFactory(mx, mz)
		if not unitID then
			return
		end
		factoryDefID = spGetUnitDefID(unitID)
		plateDefID = parentOfPlate[factoryDefID]
		if floatOnWater[plateDefID] then
			return
		end
	end

	mx, mz = SnapBuildToGrid(mx, mz, plateDefID) -- Make sure the plate is in range when it is placed
	-- Plates could be disabled by modoptions or otherwise unavailable.
	local cmdDescID = Spring.GetCmdDescIndex(-plateDefID)
	if not cmdDescID then
		return
	end

	closestFactoryData = factoryData
	if distSq < FACTORY_RANGE_SQ then
		spSetActiveCommand(buildAction[plateDefID])
		return factoryDefID, plateDefID
	else
		spSetActiveCommand("buildplate")
		return
	end
end

local function ResetInterface()
	cmdFactoryDefID = nil
	buildFactoryDefID = nil
	buildPlateDefID = nil
	closestFactoryData = nil
end

local spGetModKeyState = Spring.GetModKeyState

function widget:Update()
	local _, cmdID = spGetActiveCommand()
	buildPlateCommand = cmdID and ((CMD_BUILD_PLATE == cmdID) or (cmdPlateDefID))
	
	if (buildFactoryDefID or cmdFactoryDefID or closestFactoryData) and CMD_BUILD_PLATE ~= cmdID then
		ResetInterface()
	end

	if cmdID then
		local unitDefID = -cmdID
		-- check for cmd plate first, otherwise do previous behaviour
		if CMD_BUILD_PLATE == cmdID then
			cmdFactoryDefID, cmdPlateDefID = MakePlateFromCMD()
			return
		elseif cmdPlateDefID then
			if unitDefID == cmdPlateDefID then
				cmdFactoryDefID, cmdPlateDefID = MakePlateFromCMD()
			else
				cmdPlateDefID = nil
				ResetInterface()
			end
			return
		else
			if activeCmdOverride then
				if (unitDefID == buildFactoryDefID or unitDefID == buildPlateDefID) then
					return
				end
				activeCmdOverride = nil
			end
			local shift = select(4,spGetModKeyState())
			if parentOfPlate[unitDefID] then
				buildFactoryDefID = unitDefID
				buildPlateDefID = parentOfPlate[unitDefID]
				CheckTransformFactoryIntoPlate(unitDefID, shift)
				return
			end
			if childOfFactory[unitDefID] then
				buildFactoryDefID = childOfFactory[unitDefID]
				buildPlateDefID = unitDefID
				CheckTransformPlateIntoFactory(unitDefID, shift)
				return
			end
		end
	end
end


--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function widget:KeyPress(key, mods, isRepeat, label, unicode)
	if isRepeat then
		return
	end
	if not (buildFactoryDefID and buildPlateDefID) then
		return
	end
	if not (options.ctrl_toggle.value and (key == KEYSYMS.LCTRL or key == KEYSYMS.RCTRL)) then
		return
	end
	
	activeCmdOverride = true
	local _, cmdID = spGetActiveCommand()
	local unitDefID = -cmdID
	if unitDefID == buildFactoryDefID then
		spSetActiveCommand(buildAction[buildPlateDefID])
	else
		spSetActiveCommand(buildAction[buildFactoryDefID])
	end
	return true
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------


function widget:UnitCreated(unitID, unitDefID)
	if not (parentOfPlate[unitDefID] and Spring.GetUnitAllyTeam(unitID) == myAllyTeamID) then
		return
	end
	local x,y,z = Spring.GetUnitPosition(unitID)
	IterableMap.Add(factories, unitID, {
		unitDefID = unitDefID,
		x = x,
		y = y,
		z = z,
	})
end

function widget:UnitDestroyed(unitID, unitDefID, teamID)
	if not parentOfPlate[unitDefID] then
		return
	end
	IterableMap.Remove(factories, unitID)
end

function widget:UnitGiven(unitID, unitDefID, newTeamID, teamID)
	widget:UnitCreated(unitID, unitDefID, teamID)
end

function widget:UnitTaken(unitID, unitDefID, oldTeamID, teamID)
	widget:UnitDestroyed(unitID, unitDefID, teamID)
end

function widget:Initialize()
	IterableMap.Clear(factories)
	
	local units = Spring.GetAllUnits()
	for i = 1, #units do
		local unitID = units[i]
		widget:UnitCreated(unitID, Spring.GetUnitDefID(unitID))
	end
end

function widget:PlayerChanged(playerID)
	if myPlayerID ~= playerID then
		return
	end
	if myAllyTeamID == Spring.GetMyAllyTeamID() then
		return
	end
	myAllyTeamID = Spring.GetMyAllyTeamID()
	widget:Initialize()
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
local function DoLine(x1, y1, z1, x2, y2, z2)
	gl.Vertex(x1, y1, z1)
	gl.Vertex(x2, y2, z2)
end

local function GetDrawDef(mx, mz, data)
	if DistSq(mx, mz, data.x, data.z) < FACTORY_RANGE_SQ then
		return inCircle, true
	end
	return outCircle, false
end

local function DrawFactoryLine(x, y, z, unitDefID, drawDef)
	local mx, mz = GetMousePos(not floatOnWater[unitDefID])
	if not mx then
		return
	end
	
	local _, cmdID = spGetActiveCommand()
	if cmdID and cmdID < 0 then
		if not (cmdID and (oddX[-cmdID])) then
			return
		end
		
		mx, mz = SnapBuildToGrid(mx, mz, -cmdID)
	end
	local my = spGetGroundHeight(mx, mz)

	glLineWidth(drawDef.width)
	glColor(drawDef.color[1], drawDef.color[2], drawDef.color[3], drawDef.color[4])
	gl.BeginEnd(GL.LINE_STRIP, DoLine, x, y, z, mx, my, mz)

	glLineStipple(false)
	glLineWidth(1)
	glColor(1, 1, 1, 1)
end

function widget:DrawInMiniMap(minimapX, minimapY)
	if not (buildFactoryDefID or buildPlateCommand) then
		return
	end
	local mx, mz = GetMousePos(not ((not buildPlateCommand) and floatOnWater[buildFactoryDefID]))
	if not mx then
		return
	end
	if not buildPlateCommand then
		mx, mz = SnapBuildToGrid(mx, mz, buildPlateDefID)
	end
	
	if GetMiniMapFlipped() then
		glTranslate(minimapY, 0, 0)
		glScale(-minimapX/mapX, minimapY/mapZ, 1)
	else
		glTranslate(0, minimapY, 0)
		glScale(minimapX/mapX, -minimapY/mapZ, 1)
	end
	
	local drawn = false
	for unitID, data in IterableMap.Iterator(factories) do
		if buildPlateCommand or data.unitDefID == buildFactoryDefID then
			drawn = true
			local drawDef = GetDrawDef(mx, mz, data)
			if buildPlateCommand and drawPlateDefID and data.unitDefID ~= drawFactoryDefID then
				inRange = false
				drawDef = outCircle
			end
			
			glLineWidth(drawDef.miniWidth)
			glColor(drawDef.color[1], drawDef.color[2], drawDef.color[3], drawDef.color[4])
			
			glDrawCircle(data.x, data.z, drawDef.range)
		end
	end
	
	if drawn then
		glScale(1, 1, 1)
		glLineStipple(false)
		glLineWidth(1)
		glColor(1, 1, 1, 1)
	end
end

function widget:DrawWorld()
	if cmdPlateDefID then
		drawFactoryDefID = cmdFactoryDefID
		drawPlateDefID = cmdPlateDefID
	else
		drawFactoryDefID = buildFactoryDefID
		drawPlateDefID = buildPlateDefID
	end
	
	if not (drawFactoryDefID or buildPlateCommand or closestFactoryData) then
		return
	end
	
	local mx, mz = GetMousePos(not ((not buildPlateCommand) and floatOnWater[buildFactoryDefID]))
	if not mx then
		return
	end
	
	local drawInRange = false
	if drawFactoryDefID or buildPlateCommand then
		if not buildPlateCommand then
			mx, mz = SnapBuildToGrid(mx, mz, drawPlateDefID)
		end
		
		local drawn = false
		for unitID, data in IterableMap.Iterator(factories) do
			if buildPlateCommand or data.unitDefID == drawFactoryDefID then
				drawn = true
				local drawDef, inRange = GetDrawDef(mx, mz, data)
				if buildPlateCommand and drawPlateDefID and data.unitDefID ~= drawFactoryDefID then
					inRange = false
					drawDef = outCircle
				end
				drawInRange = drawInRange or inRange
				
				gl.DepthTest(false)
				glLineWidth(drawDef.width)
				glColor(drawDef.color[1], drawDef.color[2], drawDef.color[3], drawDef.color[4])
				
				glDrawGroundCircle(data.x, data.y, data.z, drawDef.range, drawDef.circleDivs)
			end
		end
		
		if drawn then
			glLineStipple(false)
			glLineWidth(1)
			glColor(1, 1, 1, 1)
		end
	end
	
	if closestFactoryData then
		DrawFactoryLine(closestFactoryData.x, closestFactoryData.y, closestFactoryData.z, drawFactoryDefID, drawInRange and inCircle or outCircle)
	end
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
