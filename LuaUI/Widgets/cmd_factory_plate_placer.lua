--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- can use modified unit_initial_queue.lua to be used in pregame



function widget:GetInfo()
	return {
		name      = "Factory Plate Placer",
		desc      = "Replaces factory placement with plates of the appropriate type, and integrates CMD_BUILD_PLATE behaviour",
		author    = "GoogleFrog/DavetheBrave",
		date      = "23 September 2021",
		license   = "GNU GPL, v2 or later",
		layer     = -1, -- to catch build before Draw Placement
		enabled   = true,
	}
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- Speedup
local Echo = Spring.Echo
local preGame = Spring.GetGameFrame() < 2

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
local spGetPlayerInfo	 = Spring.GetPlayerInfo
local spGetCmdDescIndex  = Spring.GetCmdDescIndex

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
options_order = {'ctrl_use'}
options = {
	ctrl_use = {
		name = "Ctrl toggles Factory/Plate",
		type = 'radioButton',
		items = { 
			{key = '0', name = 'Unused', desc = 'When placing a factory or plate, press Ctrl to select whether a factory or construction plate is placed.',},
			{key = '1', name = 'On Press', desc = 'When placing a factory or plate, press Ctrl to select whether a factory or construction plate is placed.',},
			{key = '2', name = 'When held', desc = 'When placing a factory or plate, press Ctrl to select whether a factory or construction plate is placed.',},
		},
		default = '0',
		value = '0',
		noHotkey = true,
		desc = 'When placing a factory or plate, press Ctrl to select whether a factory or construction plate is placed.',
		OnChange = function(self)
			if self.value == '0' then
				reverse = false
			end
		end
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
local facOfPlate = {}
local plateOfFac = {}
local floatOnWater = {}
local queuedFactories = {}

for i = 1, #UnitDefs do
	local ud = UnitDefs[i]
	local cp = ud.customParams
	if (cp.parent_of_plate or cp.child_of_factory) then
		buildAction[i] = "buildunit_" .. ud.name
		oddX[i] = (ud.xsize % 4)*4
		oddZ[i] = (ud.zsize % 4)*4
		floatOnWater[i] = ud.floatOnWater
		
		if cp.child_of_factory then
			facOfPlate[i] = UnitDefNames[cp.child_of_factory].id
		end
		if cp.parent_of_plate then
			plateOfFac[i] = UnitDefNames[cp.parent_of_plate].id
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
local reverse = false
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

local copy = function(t)
	local c = {}
	for k,v in pairs(t) do
		c[k] = v
	end
	return c
end
local tempQueue = false
local gamePaused = select(3,Spring.GetGameSpeed())
local GetPing
function widget:GamePaused(_,status)
	gamePaused = status
end
do
	lastAsked = 0
	local ping = gamePaused and 0.250 or select(6,spGetPlayerInfo(myPlayerID, true))
	GetPing = function(now)
		if gamePaused then
			return ping
		end
		if now > lastAsked + 1.5 then
			ping = select(6,spGetPlayerInfo(myPlayerID, true))

			lastAsked = now
		end
		return ping
	end
end
function widget:CommandNotify(cmd, params, opts)
	if cmd < 0 and (plateOfFac[-cmd] or facOfPlate[-cmd]) then
		-- Echo('CN',cmd,os.clock())
		if not tempQueue then
			tempQueue = {}
		end
		local now = os.clock()
		tempQueueTimeOut = now + GetPing(now) * 2.2
		tempQueue[params[1] .. '-' .. params[3]] = {unitDefID = -cmd, x = params[1], y = params[2], z = params[3], queued = true, timeOut = tempQueueTimeOut}
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
	-- if cmd == 1 or cmd < 0 then
	-- 	Echo('UC received',cmd,'params',unpack(params))
	-- end
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



local function UpdateQueuedFactories()
	local selSorted = WG.selectionDefID or spGetSelectedUnitsSorted()
	local now = os.clock()
	if tempQueue then -- tempQueue allow to detect queued building before the order is given back from the server
		for id, data in pairs(tempQueue) do
			if now > data.timeOut then
				tempQueue[id] = nil
				-- Echo('fac plate placer 2 timed out', data.unitDefID)
			end
		end
		if not next(tempQueue) then
			tempQueue = false
		end
	end
	local ret = copy(tempQueue or {})
	queuedFactories = ret
	WG.queuedFactories = ret
	WG.queuedFactoriesUpdateTime = now
	if not selSorted then
		return ret
	end
	if WG.InitialQueue then
		local queue = WG.preGameBuildQueue
		if queue then
			for i, build in ipairs(queue) do
				local defID = build[1]
				if plateOfFac[defID] then
					local x,y,z = build[2], build[3], build[4]
					if not ret[x .. '-' .. z] then
						ret[x .. '-' .. z] = {unitDefID = defID, x=x, y=y, z=z, queued = true}
					end
				end
			end
		end
	else
		for defID, units in pairs(selSorted) do
			if builderDefID[defID] then
				for i, id in ipairs(units) do
					local queue = spGetCommandQueue(id, -1)
					if queue then
						for i, order in ipairs(queue) do
							if order.id < 0 and plateOfFac[-order.id] then
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
	end
	return ret
end


local function GetClosestFactory(x, z, unitDefID, includeQueued)
	local nearID, nearDistSq, nearData, isQueued
	UpdateQueuedFactories()
	for _, t in pairs{factories.dataByKey, queuedFactories} do
		for unitID, data in pairs(t) do
			if not unitDefID or data.unitDefID == unitDefID then
				local dSq = DistSq(x, z, data.x, data.z)
				if (not nearDistSq) or (dSq < nearDistSq) then
					if not data.queued or includeQueued then
						nearID = unitID
						nearDistSq = dSq
						nearData = data
						isQueued = data.queued
					end
				end
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

local function CheckTransformPlateIntoFactory(plateDefID, shift, reverse)
	local mx, mz = GetMousePos(not floatOnWater[plateDefID])
	if not mx then
		return
	end
	
	local factoryDefID = facOfPlate[plateDefID]
	mx, mz = SnapBuildToGrid(mx, mz, plateDefID) -- Make sure the plate is in range when it is placed
	local unitID, distSq, factoryData, isQueued = GetClosestFactory(mx, mz, factoryDefID, shift)
	-- Echo("isQueued , shift is ", isQueued, shift)
	if not unitID then
		closestFactoryData = nil
		if not reverse then
			spSetActiveCommand(buildAction[factoryDefID])
			return true
		end
	end
	-- if not unitID or isQueued and shift then
	-- 	-- local cmdName = select(4, spGetActiveCommand())
	-- 	-- if cmdName and ('buildunit_'..cmdName) == buildAction[plateDefID] then
	-- 	-- 	spSetActiveCommand(buildAction[factoryDefID])
	-- 	-- end
	-- 	-- Echo('returned')
	-- 	return
	-- end
	closestFactoryData = factoryData
	-- Echo('checking', math.round(os.clock()))
	local switch = reverse == (distSq and distSq < FACTORY_RANGE_SQ)

	if switch then
		spSetActiveCommand(buildAction[factoryDefID])
		return true
	end
end



local function CheckTransformFactoryIntoPlate(factoryDefID, shift, reverse)
	local mx, mz = GetMousePos(not floatOnWater[factoryDefID])
	if not mx then
		return
	end
	local plateDefID = plateOfFac[factoryDefID]
	mx, mz = SnapBuildToGrid(mx, mz, plateDefID) -- Make sure the plate is in range when it is placed
	local unitID, distSq, factoryData, isQueued = GetClosestFactory(mx, mz, factoryDefID, shift)
	if not unitID then
		closestFactoryData = nil
		if reverse then
			spSetActiveCommand(buildAction[plateDefID])
			return true
		end
		return
	end
	
	-- Plates could be disabled by modoptions or otherwise unavailible.
	local cmdDescID = spGetCmdDescIndex(-plateDefID)
	if not cmdDescID then
		return
	end

	closestFactoryData = factoryData

	local switch = reverse == (distSq > FACTORY_RANGE_SQ)

	if switch then
		spSetActiveCommand(buildAction[plateDefID])
		return true
	end
	return
end

local function CheckInRange()
	local mx, mz = GetMousePos(not floatOnWater[factoryDefID])
	if not mx then
		return
	end
	local plateDefID = plateOfFac[factoryDefID]
	mx, mz = SnapBuildToGrid(mx, mz, plateDefID) -- Make sure the plate is in range when it is placed
	local unitID, distSq, factoryData, isQueued = GetClosestFactory(mx, mz, factoryDefID)
	if not unitID then
		return
	end
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
	local plateDefID = plateOfFac[factoryDefID]
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
		plateDefID = plateOfFac[factoryDefID]
		if floatOnWater[plateDefID] then
			return
		end
	end

	mx, mz = SnapBuildToGrid(mx, mz, plateDefID) -- Make sure the plate is in range when it is placed
	-- Plates could be disabled by modoptions or otherwise unavailable.
	local cmdDescID = spGetCmdDescIndex(-plateDefID)
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
-- if not Spring.__oriSetActiveCommand then
-- 	Spring.__oriSetActiveCommand = Spring.SetActiveCommand
-- 	Spring.SetActiveCommand = function(...)
-- 		Echo(math.round(os.clock()),...)
-- 		return Spring.__oriSetActiveCommand(...)
-- 	end
-- end
function widget:Update()
	local _, cmdID = spGetActiveCommand()
	buildPlateCommand = cmdID and ((CMD_BUILD_PLATE == cmdID) or (cmdPlateDefID))
	
	if (buildFactoryDefID or cmdFactoryDefID or closestFactoryData) and CMD_BUILD_PLATE ~= cmdID then
		-- Echo('reset', math.round(os.clock()))
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
			-- Echo(unitDefID, unitDefID == buildFactoryDefID and 'build Fac' or unitDefID == buildPlateDefID and 'build Plate', activeCmdOverride and 'Override')	
			if select(3, spGetMouseState()) then
				return
			end
			local ctrl,_,shift = select(2,spGetModKeyState())
			if options.ctrl_use.value == '2' or WG.InitialQueue then
				reverse = ctrl
			end
			-- Echo(plateOfFac[unitDefID] and 'fac' or facOfPlate[unitDefID] and 'plate')
			if plateOfFac[unitDefID] then
				buildFactoryDefID = unitDefID
				buildPlateDefID = plateOfFac[unitDefID]
				-- Echo('check in to plate', math.round(os.clock()))
				if CheckTransformFactoryIntoPlate(unitDefID, shift, reverse) then
					-- Echo(Spring.GetActiveCommand())
				end
			elseif facOfPlate[unitDefID] then
				buildFactoryDefID = facOfPlate[unitDefID]
				buildPlateDefID = unitDefID
				-- Echo('check into fac', math.round(os.clock()))
				if CheckTransformPlateIntoFactory(unitDefID, shift, reverse) then
					-- Echo(Spring.GetActiveCommand())
				end
			end
			if reverse and (options.ctrl_use.value == '2' or WG.InitialQueue) then
				reverse = false
			end
		end
	end
end


--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function widget:KeyPress(key, mods, isRepeat)
	if isRepeat then
		return
	end
	if not (buildFactoryDefID and buildPlateDefID) then
		return
	end

	if not (options.ctrl_use.value == '1' and (key == KEYSYMS.LCTRL or key == KEYSYMS.RCTRL)) then
		return
	end
	reverse = not reverse
	return true
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------


function widget:UnitCreated(unitID, unitDefID)
	if not (plateOfFac[unitDefID] and Spring.GetUnitAllyTeam(unitID) == myAllyTeamID) then
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
	if not plateOfFac[unitDefID] then
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
	gamePaused = select(3,Spring.GetGameSpeed())
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
	for _, t in pairs{factories.dataByKey, queuedFactories} do
		for unitID, data in pairs(t) do
			if buildPlateCommand or data.unitDefID == buildFactoryDefID then
				drawn = true
				local drawDef, inRange
				if data == closestFactoryData and DistSq(mx, mz, data.x, data.z) < FACTORY_RANGE_SQ then
					drawDef, inRange = inCircle, true
				else
					drawDef, inRange = outCircle, false
				end
				if buildPlateCommand and drawPlateDefID and data.unitDefID ~= drawFactoryDefID then
					inRange = false
					drawDef = outCircle
				end
				
				glLineWidth(drawDef.miniWidth)
				glColor(drawDef.color[1], drawDef.color[2], drawDef.color[3], drawDef.color[4])
				glDrawCircle(data.x, data.z, drawDef.range)
			end
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
		for _, t in pairs{factories.dataByKey, queuedFactories} do
			for unitID, data in pairs(t) do
				if buildPlateCommand or data.unitDefID == drawFactoryDefID then
					drawn = true
					local drawDef, inRange
					if data == closestFactoryData and DistSq(mx, mz, data.x, data.z) < FACTORY_RANGE_SQ then
						drawDef, inRange = inCircle, true
					else
						drawDef, inRange = outCircle, false
					end
					-- Echo('not in range',buildPlateCommand and drawPlateDefID and data.unitDefID ~= drawFactoryDefID)
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
