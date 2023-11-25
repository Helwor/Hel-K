local version = "v1.544"
function widget:GetInfo()
	return {
		name      = "Initial Queue ZK",
		desc      = version .. " Allows you to queue buildings before game start",
		author    = "Niobium, KingRaptor",
		date      = "7 April 2010",
		license   = "GNU GPL, v2 or later",
		layer     = -1, -- Puts it below cmd_mex_placement.lua, to catch mex placement order before the cmd_mex_placement.lua does.
		enabled   = true,
		handler   = true
	}
end
-- 12 jun 2012: "uDef.isMetalExtractor" was replaced by "uDef.extractsMetal > 0" to fix "metal" mode map switching (by [teh]decay, thx to vbs and Beherith)
-- 20 march 2013: added keyboard support with BA keybinds (Bluestone)
-- august 2013: send queue length to cmd_idle_players (BrainDamage)

--TODO: find way to detect GameStart countdown, so that we can remove button before GameStart (not after gamestart) since it will cause duplicate button error.
------------------------------------------------------------
-- Config
------------------------------------------------------------
local buildOptions = VFS.Include("gamedata/buildoptions.lua")

local MAX_QUEUE = 30
local REDCHAR = string.char(255,255,64,32)

-- Colors
local buildDistanceColor = {0.3, 1.0, 0.3, 0.7}
local buildLinesColor = {0.3, 1.0, 0.3, 0.7}
local borderNormalColor = {0.3, 1.0, 0.3, 0.5}
local borderClashColor = {0.7, 0.3, 0.3, 1.0}
local borderValidColor = {0.0, 1.0, 0.0, 1.0}
local borderInvalidColor = {1.0, 0.0, 0.0, 1.0}
local buildingQueuedAlpha = 0.5

local metalColor = '\255\196\196\255' -- Light blue
local energyColor = '\255\255\255\128' -- Light yellow
local buildColor = '\255\128\255\128' -- Light green
local whiteColor = '\255\255\255\255' -- White

local fontSize = 20

------------------------------------------------------------
-- Globals
------------------------------------------------------------
local myTeamID = Spring.GetMyTeamID()
local myPlayerID = Spring.GetMyPlayerID()




--++ Adding interaction with Persistent Build Height 2 and terraform visualization. Helwor 

local PBH2=false
local PBH2msg = false
local Echo = Spring.Echo
local spGetMouseState  = Spring.GetMouseState
local spGetGroundHeight = Spring.GetGroundHeight
local spGetCameraState = Spring.GetCameraState

local f = VFS.Include("LuaUI\\Widgets\\UtilsFunc.lua")
local hollowRectangle=f.hollowRectangle
local glVertex = gl.Vertex
local glLineWidth = gl.LineWidth
local glBeginEnd = gl.BeginEnd
local GL_LINES	= GL.LINES
local CheckTerra = false
--++


local sDefID = Spring.GetTeamRulesParam(myTeamID, "commChoice") or UnitDefNames.dyntrainer_strike_base.id-- Starting unit def ID
local sDef = UnitDefs[sDefID]
local buildDistance = sDef.buildDistance

local selDefID = nil -- Currently selected def ID

--local buildQueue = {}
local buildQueue --++ linked to WG.preGameBuildQueue in CallIn Initialize. Helwor


local buildNameToID = {}
local gameStarted = false
local othersBuildQueue = {}

local isMex = {} -- isMex[uDefID] = true / nil
local weaponRange = {} -- weaponRange[uDefID] = # / nil

local changeStartUnitRegex = '^\138(%d+)$'
local startUnitParamName = 'startUnit'

local scrW, scrH = Spring.GetViewGeometry()

local mCost, eCost, bCost, buildTime = 0, 0, 0, 0

local CMD_STOP = CMD.STOP

------------------------------------------------------------
-- Local functions
------------------------------------------------------------
local function GetBuildingDimensions(uDefID, facing)
	local bDef = UnitDefs[uDefID]
	if (facing % 2 == 1) then
		return 4 * bDef.zsize, 4 * bDef.xsize
	else
		return 4 * bDef.xsize, 4 * bDef.zsize
	end
end

--[[local function DrawGroundRectangle(bx, bz, bw,  bh, inc)
	local prev=false
	for x,z in hollowRectangle(bx, bz, bw,  bh, 8) do
		local y = spGetGroundHeight(x,z)
		if prev then
			glVertex(prev[1], prev[2], prev[3])
			glVertex(x, y, z)
		else
			prev={}
		end
		prev[1], prev[2], prev[3]=x, y, z
	end
end--]]
local function DrawGroundRectangle(gP,y,flat)
	local prev=false
	--local prevx,prevy,prevz
	local hidden
	local count=0
	for i=2,#gP do
		
		hidden = not flat and (gP[i-1].hidden or gP[i].hidden)
		if not hidden then
			count=count+1
			glVertex(gP[i-1][1], flat and y or gP[i-1][2], gP[i-1][3])
			glVertex(gP[i][1], flat and y or gP[i][2], gP[i][3])
		end
		
	end
end
local function DrawBorders(gP,b1,b2)
	local x,y,z,cardinal,corner
	local sy
	for i=1,#b2 do
		x,y,z,cardinal=unpack(b2[i])
		corner = cardinal=="NW" or cardinal=="NE" or cardinal=="SE" or cardinal=="SW"
		if  not corner then 
			if cardinal=="N" then
				sy=spGetGroundHeight(x,z+8)
				glVertex(x, y, z)
				glVertex(x, sy ,z+8)
			elseif cardinal=="E" then
				sy=spGetGroundHeight(x-8,z)
				glVertex(x, y, z)
				glVertex(x-8, sy ,z)
			elseif cardinal=="S" then
				sy=spGetGroundHeight(x,z-8)
				glVertex(x, y, z)
				glVertex(x, sy ,z-8)
			elseif cardinal=="W" then
				sy=spGetGroundHeight(x+8,z)
				glVertex(x, y, z)
				glVertex(x+8, sy ,z)
			end
		end
	end
	for i=1,#gP do
		x,y,z,cardinal=unpack(gP[i])
		if cardinal=="NW" then
			sy=spGetGroundHeight(x,z-8)
			glVertex(x, y, z)
			glVertex(x, sy ,z-8)
			sy=spGetGroundHeight(x-8,z)
			glVertex(x, y, z)
			glVertex(x-8, sy ,z)
		elseif cardinal=="NE" then
			sy=spGetGroundHeight(x,z-8)
			glVertex(x, y, z)
			glVertex(x, sy ,z-8)
			sy=spGetGroundHeight(x+8,z)
			glVertex(x, y, z)
			glVertex(x+8, sy ,z)
		elseif cardinal=="SE" then
			sy=spGetGroundHeight(x,z+8)
			glVertex(x, y, z)
			glVertex(x, sy ,z+8)
			sy=spGetGroundHeight(x+8,z)
			glVertex(x, y, z)
			glVertex(x+8, sy ,z)
		elseif cardinal=="SW" then
			sy=spGetGroundHeight(x,z+8)
			glVertex(x, y, z)
			glVertex(x, sy ,z+8)
			sy=spGetGroundHeight(x-8,z)
			glVertex(x, y, z)
			glVertex(x-8, sy ,z)


		elseif cardinal=="N" then
			sy=spGetGroundHeight(x,z-8)
			glVertex(x, y, z)
			glVertex(x, sy ,z-8)
		elseif cardinal=="E" then
			sy=spGetGroundHeight(x+8,z)
			glVertex(x, y, z)
			glVertex(x+8, sy ,z)
		elseif cardinal=="S" then
			sy=spGetGroundHeight(x,z+8)
			glVertex(x, y, z)
			glVertex(x, sy ,z+8)
		elseif cardinal=="W" then
			sy=spGetGroundHeight(x-8,z)
			glVertex(x, y, z)
			glVertex(x-8, sy ,z)
		end
	end
end
--[[local function DrawVerticals(bx, by, bz, bw,  bh) -- draw only cardinals and corners verticals
	local minx,maxx,minz,maxz = bx-bw, bx+bw, bz-bh, bz+bh
	local gy1 = spGetGroundHeight(minx,minz)
	local westy = spGetGroundHeight(minx,bz)
	local gy2 = spGetGroundHeight(maxx,minz)
	local southy = spGetGroundHeight(bx,minz)
	local gy3 = spGetGroundHeight(maxx,maxz)
	local easty = spGetGroundHeight(maxx,bz)
	local gy4 = spGetGroundHeight(minx,maxz)
	local northy = spGetGroundHeight(bx,maxz)

	glVertex(minx, by, minz)
	glVertex(minx, gy1, minz)

	glVertex(maxx, by, minz)
	glVertex(maxx, gy2,	minz)

	glVertex(maxx, by, maxz)
	glVertex(maxx, gy3, maxz)
	
	glVertex(minx, by, maxz)
	glVertex(minx, gy4, maxz)
	--

	glVertex(minx, by, bz)--
	glVertex(minx, westy, bz)

	glVertex(bx, by, minz)--
	glVertex(bx, southy, minz)

	glVertex(maxx, by, bz)--
	glVertex(maxx, easty, bz)

	glVertex(bx, by, maxz)--
	glVertex(bx, northy, maxz)

end--]]
	local function DrawVerticals(gP, by)
		local cam = spGetCameraState()
		local flipped= (cam.flipped or -1)==1
		local camx=cam.px
		local hidden
		local x,gy,z,cardinal
		for i=1,#gP do
			x,gy,z,cardinal=unpack(gP[i])
			hidden = not flipped and cardinal=="N" and gy<by or
					 flipped and cardinal=="S" and gy<by or 
					 not flipped and (cardinal=="E" or cardinal=="NE") and gy<by and x>camx or
					 not flipped and (cardinal=="W" or cardinal=="NW") and gy<by and x<camx or
					 flipped and (cardinal=="W" or cardinal=="SW") and gy<by and x<camx or 
					 flipped and (cardinal=="E" or cardinal=="SE") and gy<by and x>camx
					 --flipped and cardinal=="E" and gy<by
			gP[i].hidden=hidden
			if not hidden then
				glVertex(x,gy,z)
				glVertex(x,by,z)
			end
		end
	end
	local drawData={} -- Helwor
	local drawAll={} -- Helwor


local function DrawBuilding(buildData, borderColor, buildingAlpha, drawRanges,teamID,drawSelectionBox)

	local bDefID, bx, by, bz, facing, needTerra = buildData[1], buildData[2], buildData[3], buildData[4], buildData[5], buildData[6]

	local bw, bh = GetBuildingDimensions(bDefID, facing)

	gl.DepthTest(false)
	gl.Color(borderColor)

--[[	if drawSelectionBox then
		gl.Shape(GL.LINE_LOOP, {{v={bx - bw, by, bz - bh}},
								{v={bx + bw, by, bz - bh}},
								{v={bx + bw, by, bz + bh}},
								{v={bx - bw, by, bz + bh}}})
	end--]]
	if needTerra then-- drawing verticals and cropped ground for terraforming previsualization --++ PBH2 Helwor

		glLineWidth(1.0)
		local groundPoints, border1,border2
		local strID= bDefID..bx..by..bz..facing
		if not drawData[strID] then
			groundPoints,border1,border2={},{},{}			
			drawData[strID]={groundPoints=groundPoints,border1=border1,border2=border2}

			local y
			for x,z,cardinal in hollowRectangle(bx, bz, bw,  bh, 8) do
				y = spGetGroundHeight(x,z)
				groundPoints[#groundPoints+1]={x, y, z, cardinal}
			end
			groundPoints[#groundPoints+1]=groundPoints[1] -- to finish the loop of vertices
			for x,z,cardinal in hollowRectangle(bx, bz, bw+8,  bh+8, 8) do
				y = spGetGroundHeight(x,z)
				border1[#border1+1]={x, y, z, cardinal}
			end
			border1[#border1+1]=border1[1]
			for x,z,cardinal in hollowRectangle(bx, bz, bw+16,  bh+16, 8) do
				y = spGetGroundHeight(x,z)
				border2[#border2+1]={x, y, z, cardinal}
			end
			border2[#border2+1]=border2[1]

		end
		groundPoints=drawData[strID].groundPoints
		border1=drawData[strID].border1
		border2=drawData[strID].border2
		--Echo("#border1,#border2 is ", #border1,#border2)
		glBeginEnd(GL_LINES, DrawVerticals,groundPoints,by)
		glBeginEnd(GL_LINES, DrawVerticals,groundPoints, by) -- draw verticals and finding out hidden
		glLineWidth(1.0)
		glBeginEnd(GL_LINES, DrawGroundRectangle,groundPoints,by) -- draw original ground curves on rectangle, with hiding
		glBeginEnd(GL_LINES, DrawGroundRectangle,groundPoints,by,true) -- draw selection rectangle, with hiding
		--glBeginEnd(GL_LINES, DrawGroundRectangle,border1,by)
		--glBeginEnd(GL_LINES, DrawBorders,groundPoints,border1,border2)
	end



	if drawRanges then
		--[[
		if isMex[bDefID] then
			gl.Color(1.0, 0.3, 0.3, 0.7)
			gl.DrawGroundCircle(bx, by, bz, Game.extractorRadius, 40)
		end
		]]

		local wRange = weaponRange[bDefID]
		if wRange then
			gl.Color(1.0, 0.3, 0.3, 0.7)
			gl.DrawGroundCircle(bx, by, bz, wRange, 40)
		end
	end

	gl.DepthTest(false)
	gl.DepthMask(true)

	if buildingAlpha == 1 then gl.Lighting(true) end
	gl.Color(1.0, 1.0, 1.0, buildingAlpha)

	gl.PushMatrix()
		gl.LoadIdentity()
		gl.Translate(bx, by, bz)
		gl.Rotate(90 * facing, 0, 1, 0)
		gl.Texture("%"..bDefID..":0") --.s3o texture atlas for .s3o model
		gl.UnitShape(bDefID, teamID, false, false, false)
		gl.Texture(false)
	gl.PopMatrix()

	gl.Lighting(false)
	gl.DepthTest(false)
	gl.DepthMask(false)

end
local function DrawUnitDef(uDefID, uTeam, ux, uy, uz, rot)

	gl.Color(1.0, 1.0, 1.0, 1.0)
	gl.DepthTest(GL.LEQUAL)
	gl.DepthMask(true)
	gl.Lighting(true)

	gl.PushMatrix()
		gl.LoadIdentity()
		gl.Translate(ux, uy, uz)
		gl.Rotate(rot, 0, 1, 0)
		gl.UnitShape(uDefID, uTeam, false, false, true)
	gl.PopMatrix()

	gl.Lighting(false)
	gl.DepthTest(false)
	gl.DepthMask(false)
end
local function DoBuildingsClash(buildData1, buildData2)

	local w1, h1 = GetBuildingDimensions(buildData1[1], buildData1[5])
	local w2, h2 = GetBuildingDimensions(buildData2[1], buildData2[5])

	return math.abs(buildData1[2] - buildData2[2]) < w1 + w2 and
	       math.abs(buildData1[4] - buildData2[4]) < h1 + h2
end
local function SetSelDefID(defID)
	selDefID = defID

	-- if (isMex[selDefID] ~= nil) ~= (Spring.GetMapDrawMode() == "metal") then
		-- Spring.SendCommands("ShowMetalMap")
	-- end
	-- if defID then
		-- Spring.SetActiveCommand(defID)
	-- end
end

local function GetSelDefID(defID)
	return selDefID
end

local function GetUnitCanCompleteQueue(uID)

	local uDefID = Spring.GetUnitDefID(uID)
	if uDefID == sDefID then
		return true
	end

	-- What can this unit build ?
	local uCanBuild = {}
	local uBuilds = UnitDefs[uDefID].buildOptions
	for i = 1, #uBuilds do
		uCanBuild[uBuilds[i]] = true
	end

	-- Can it build everything that was queued ?
	for i = 1, #buildQueue do
		if not uCanBuild[buildQueue[i][1]] then
			return false
		end
	end

	return true
end
local function GetQueueBuildTime()
	local t = 0
	for i = 1, #buildQueue do
		t = t + UnitDefs[buildQueue[i][1]].buildTime
	end
	return t / sDef.buildSpeed
end
local function GetQueueCosts()
	local mCost = 0
	local eCost = 0
	local bCost = 0
	for i = 1, #buildQueue do
		local uDef = UnitDefs[buildQueue[i][1]]
		mCost = mCost + uDef.metalCost
		eCost = eCost + uDef.energyCost
		bCost = bCost + uDef.buildTime
	end
	return mCost, eCost, bCost
end

local function GetBuildOptions()
	return buildOptions
end




------------------------------------------------------------
-- Drawing
------------------------------------------------------------
--local queueTimeFormat = whiteColor .. 'Queued: ' .. buildColor .. '%.1f sec ' .. whiteColor .. '[' .. metalColor .. '%d m' .. whiteColor .. ', ' .. energyColor .. '%d e' .. whiteColor .. ']'
local queueTimeFormat = whiteColor .. 'Queued ' .. metalColor .. '%dm ' .. buildColor .. '%.1f sec'
--local queueTimeFormat = metalColor .. '%dm ' .. whiteColor .. '/ ' .. energyColor .. '%de ' .. whiteColor .. '/ ' .. buildColor .. '%.1f sec'


-- "Queued 23.9 seconds (820m / 2012e)" (I think this one is the best. Time first emphasises point and goodness of widget)
	-- Also, it is written like english and reads well, none of this colon stuff or figures stacked together

local timer = 0
local updateFreq = 0.15

-- check if we're chosen a new comm

function widget:Update(dt) 
	--Echo("#buildQueue is ", #buildQueue)
	timer = timer + dt
	if timer > updateFreq then
		local defID = Spring.GetTeamRulesParam(myTeamID, "commChoice")
		if defID and defID ~= sDefID then
			local def = UnitDefs[defID]
			if def then
				sDefID = defID
				sDef = def
				buildDistance = sDef.buildDistance
				mCost, eCost, bCost = GetQueueCosts()
				buildTime = bCost / sDef.buildSpeed
			end
		end
		timer = 0
	end
end





function widget:DrawScreen()
	gl.PushMatrix()
	gl.Translate(scrW*0.4, scrH*0.35, 0)
	local num = #buildQueue
	if num > 0 then
		--gl.Text(string.format(queueTimeFormat, mCost, buildTime), 0, 0, fontSize, 'cdo')
		local str = "Queue: " .. num .. "/" .. MAX_QUEUE
		if num >= MAX_QUEUE then
			str = REDCHAR .. str
		end
		gl.Text(str, 0, 0, fontSize, 'cdo')
	end
	gl.PopMatrix()
end

local function DrawWorldFunc()
	--don't draw anything once the game has started; after that engine can draw queues itself
	if gameStarted then
		return
	end

	-- local clash = false
	
	-- Set up gl
	gl.LineWidth(1.49) -- 

	-- We need data about currently selected building, for drawing clashes etc
	local selBuildData
	if selDefID then
		local mx, my = Spring.GetMouseState()
		local _, pos = Spring.TraceScreenRay(mx, my, true)
		if pos then
			local bx, by, bz = Spring.Pos2BuildPos(selDefID, pos[1], pos[2], pos[3])
			local buildFacing = Spring.GetBuildFacing()
			selBuildData = {selDefID, bx, by, bz, buildFacing}
		end
	end
	
	-- local myTeamID = Spring.GetMyTeamID()
	local sx, sy, sz = Spring.GetTeamStartPosition(myTeamID) -- Returns -100, -100, -100 when none chosen
	local startChosen = (sx > 0)
	if startChosen then
		-- Correction for start positions in the air
		sy = Spring.GetGroundHeight(sx, sz)

		-- Draw the starting unit at start position
		local rot = (math.abs(Game.mapSizeX/2 - sx) > math.abs(Game.mapSizeZ/2 - sz))
			and ((sx>Game.mapSizeX/2) and 270 or 90)
			or ((sz>Game.mapSizeZ/2) and 180 or 0)
		DrawUnitDef(sDefID, myTeamID, sx, sy, sz, rot)

		-- Draw start units build radius
		gl.Color(buildDistanceColor)
		gl.DrawGroundCircle(sx, sy, sz, buildDistance, 40)
	end

	-- Draw all the buildings
	local queueLineVerts = startChosen and {{v={sx, sy, sz}}} or {}
	for b = 1, #buildQueue do
		local buildData = buildQueue[b]
		--[[
		if selBuildData and DoBuildingsClash(selBuildData, buildData) then
			DrawBuilding(buildData, borderClashColor, buildingQueuedAlpha,false,myTeamID,true)
			clash = true
		end
		--]]
		--else

			DrawBuilding(buildData, borderNormalColor, buildingQueuedAlpha,false,myTeamID,true)
		--end
		
		queueLineVerts[#queueLineVerts + 1] = {v={buildData[2], buildData[3], buildData[4]}}
	end

	-- Draw queue lines
	gl.Color(buildLinesColor)
	gl.LineStipple("springdefault")
	gl.Shape(GL.LINE_STRIP, queueLineVerts)
	gl.LineStipple(false)

	for teamID,playerXBuildQueue in pairs(othersBuildQueue)do
		sx, sy, sz = Spring.GetTeamStartPosition(teamID) -- Returns -100, -100, -100 when none chosen
		startChosen = sx and (sx > 0)

		-- Draw all the buildings
		queueLineVerts = startChosen and {{v={sx, sy, sz}}} or {}
		for b = 1, #playerXBuildQueue do
			local buildData = playerXBuildQueue[b]
			DrawBuilding(buildData, borderNormalColor, buildingQueuedAlpha,false,teamID,false)
			queueLineVerts[#queueLineVerts + 1] = {v={buildData[2], buildData[3], buildData[4]}}
		end
		-- Draw queue lines
		gl.Color(buildLinesColor)
		gl.LineStipple("springdefault")
		gl.Shape(GL.LINE_STRIP, queueLineVerts)
		gl.LineStipple(false)
	end
	
	-- Draw selected building
	--[[
	if selBuildData then
		if (not clash) and Spring.TestBuildOrder(selDefID, selBuildData[2], selBuildData[3], selBuildData[4], selBuildData[5]) ~= 0 then
			DrawBuilding(selBuildData, borderValidColor, 1.0, true,myTeamID,true)
		else
			DrawBuilding(selBuildData, borderInvalidColor, 1.0, true,myTeamID,true)
		end
	end
	--]]

	-- Reset gl
	gl.Color(1.0, 1.0, 1.0, 1.0)
	gl.LineWidth(1.0)
end

function widget:DrawWorld()
	DrawWorldFunc()
end
function widget:DrawWorldRefraction()
	DrawWorldFunc()
end

function widget:ViewResize(vsx, vsy)
	scrW = vsx
	scrH = vsy
end

local function explode(div,str) --copied from gui_epicmenu.lua
  if (div=='') then return false end
  local pos,arr = 0,{}
  -- for each divider found
  for st,sp in function() return string.find(str,div,pos,true) end do
    table.insert(arr,string.sub(str,pos,st-1)) -- Attach chars left of current divider
    pos = sp + 1 -- Jump past current divider
  end
  table.insert(arr,string.sub(str,pos)) -- Attach chars right of last divider
  return arr
end

function widget:RecvLuaMsg(msg, playerID)
	if myPlayerID~=playerID and msg:sub(1,3) == "IQ|" then
		--Example: IQ|4|404|648|2|3304|1
		--Header|unitdefID|x|y|z|facing
		msg = msg:sub(4)
		local msgArray = explode('|',msg)
		local typeArg, unitDefID = tonumber(msgArray[1]), tonumber(msgArray[2])
		if typeArg == 5 then -- Cancel queue
			local teamID = select(4,Spring.GetPlayerInfo(playerID, false))
			othersBuildQueue[teamID] = {}
			return
		end
		if not UnitDefs[unitDefID] or typeArg > 5 or typeArg < 1 then
			return --invalid unitDefID and message type
		end
		local x,y,z,face = tonumber(msgArray[3]),tonumber(msgArray[4]),tonumber(msgArray[5]),tonumber(msgArray[6])
		if not (x and y and z and face) then
			return --invalid coordinate and facing
		end
		local teamID = select(4,Spring.GetPlayerInfo(playerID, false))
		othersBuildQueue[teamID] = othersBuildQueue[teamID] or {}
		local playerXBuildQueue = othersBuildQueue[teamID]
		if typeArg == 1 then
			table.insert(playerXBuildQueue, 1, {unitDefID,x,y,z,face})
		elseif typeArg == 2 then
			table.remove(playerXBuildQueue, unitDefID)
		elseif typeArg == 3 then
			playerXBuildQueue[#playerXBuildQueue+1] = {unitDefID,x,y,z,face}
		elseif typeArg == 4 then
			othersBuildQueue[teamID] = {{unitDefID,x,y,z,face}}
		end
	end
end

------------------------------------------------------------
-- Game start
------------------------------------------------------------

function widget:GameFrame(n)

	if not gameStarted then
		gameStarted = true
	end

	-- Don't run if we are a spec
	local areSpec = Spring.GetSpectatingState()
	if areSpec then
		widgetHandler:RemoveWidget(self)
		return
	end
	
	-- Don't run if we didn't queue anything
	if (#buildQueue == 0) then
		widgetHandler:RemoveWidget(self)
		return
	end

	if (n < 2) then return end -- Give the unit frames 0 and 1 to spawn
	
	--inform gadget how long is our queue
	local buildTime = GetQueueBuildTime()
	--Spring.SendCommands("luarules initialQueueTime " .. buildTime)
	
	if (n == 4) then
		--Spring.Echo("> Starting unit never spawned !")
		widgetHandler:RemoveWidget(self)
		return
	end
	
	local tasker
	-- Search for our starting unit
	local units = Spring.GetTeamUnits(Spring.GetMyTeamID())
	for u = 1, #units do
		local uID = units[u]
		if GetUnitCanCompleteQueue(uID) then --Spring.GetUnitDefID(uID) == sDefID then
			--we found our com, assigning queue to this particular unit
			tasker = uID
			break
		end
	end
	if tasker then
		buildQueue.tasker=tasker --++ Helwor for PBH2
		--Spring.Echo("sending queue to unit")
		-- notify other widgets that we're giving orders to the commander.
		if WG.GlobalBuildCommand then WG.GlobalBuildCommand.CommandNotifyPreQue(tasker) end
		if not widgetHandler:FindWidget("Persistent Build Height 2") then --++ 
			for b = 1, #buildQueue do
				local buildData = buildQueue[b]
				Spring.GiveOrderToUnit(tasker, -buildData[1], {buildData[2], buildData[3], buildData[4], buildData[5]}, CMD.OPT_SHIFT)
			end
		end
		if selDefID and UnitDefs[selDefID] and UnitDefs[selDefID].name then
			WG.InitialActiveCommand = "buildunit_" .. UnitDefs[selDefID].name
		end
		widgetHandler:RemoveWidget(self)
	end
	
end

------------------------------------------------------------
-- Mouse
------------------------------------------------------------
--[[
--Task handled by CommandNotify()
function widget:MousePress(mx, my, mButton)
	if selDefID then
		if mButton == 1 then
			local mx, my = Spring.GetMouseState()
			local _, pos = Spring.TraceScreenRay(mx, my, true)
			if not pos then return end
			local bx, by, bz = Spring.Pos2BuildPos(selDefID, pos[1], pos[2], pos[3])

			if isMex[selDefID] then
				local bestSpot = WG.GetClosestMetalSpot(bx, bz)
				bx, by, bz = bestSpot.x, bestSpot.y, bestSpot.z
			end
			local buildFacing = Spring.GetBuildFacing()
	
			if Spring.TestBuildOrder(selDefID, bx, by, bz, buildFacing) ~= 0 then
	
				local buildData = {selDefID, bx, by, bz, buildFacing}
				local _, _, meta, shift = Spring.GetModKeyState()
				if meta then
					table.insert(buildQueue, 1, buildData)
	
				elseif shift then
	
					local anyClashes = false
					for i = #buildQueue, 1, -1 do
						if DoBuildingsClash(buildData, buildQueue[i]) then
							anyClashes = true
							table.remove(buildQueue, i)
						end
					end
	
					if not anyClashes then
						buildQueue[#buildQueue + 1] = buildData
					end
				else
					buildQueue = {buildData}
				end
				
				mCost, eCost, bCost = GetQueueCosts()
				buildTime = bCost / sDef.buildSpeed
	
				if not shift then
					SetSelDefID(nil)
				end
			end
	
			return true
	
		elseif mButton == 3 then
			SetSelDefID(nil)
			return true
		end
	end
end
function widget:MouseMove(mx, my, dx, dy, mButton)
	if areDragging then
		wl = wl + dx
		wt = wt + dy
	end
end
function widget:MouseRelease(mx, my, mButton)
	areDragging = false
end
--]]
------------------------------------------------------------
-- Command Button
------------------------------------------------------------
function widget:CommandsChanged()

	if (gameStarted) then
		return
	end
	for i=1, #buildOptions do
		local unitName = buildOptions[i]
		if not Spring.GetGameRulesParam("disabled_unit_" .. unitName) then
			table.insert(widgetHandler.customCommands, {
				id      = -1*UnitDefNames[unitName].id,
				type    = 20,
				tooltip = "Build: " .. UnitDefNames[unitName].humanName .. " - " .. UnitDefNames[unitName].tooltip,
				cursor  = unitName,
				action  = "buildunit_" .. unitName,
				params  = {},
				texture = "", --"#"..id,
				name = unitName,
			})
		end
	end
	table.insert(widgetHandler.customCommands, {
		id      = CMD_STOP,
		type    = CMDTYPE.ICON,
		tooltip = "Stop",
		action  = "stop",
		params  = {},
	})
    table.insert(widgetHandler.customCommands, {
        id      = CMD_AREA_MEX,
        type    = CMDTYPE.ICON_AREA,
        tooltip = 'Area Mex: Click and drag to queue metal extractors in an area.',
        name    = 'Mex',
        cursor  = 'Mex',
        action  = 'areamex',
        params  = {},
})


end

local function GetClosestMetalSpot(x, z) --is used by single mex placement, not used by areamex
	local bestSpot
	local bestDist = math.huge
	local bestIndex
	for i = 1, #WG.metalSpots do
		local spot = WG.metalSpots[i]
		local dx, dz = x - spot.x, z - spot.z
		local dist = dx*dx + dz*dz
		if dist < bestDist then
			bestSpot = spot
			bestDist = dist
			bestIndex = i
		end
	end
	return bestSpot
end
local function InsertInQueue(buildQueue, buildData)
	if not buildQueue[2] then
		table.insert(buildQueue, buildData)
		return
	end
	local _,cx,cy,cz = unpack(buildData)
	-- Echo('inserting',cx,cy,cz, '...')
	local _,px,py,pz = unpack(buildQueue[1])
	local px2, pz2
	local sqrt = math.sqrt
	local prev_new = sqrt((px-cx)^2 + (pz-cz)^2)

	local min_dlen = prev_new
	local insert_pos = 1
	local queueLen = #buildQueue
	local new_dist = prev_new
	local cur_dist = 0
	for i=2,queueLen do 
		local build = buildQueue[i]
		px2, pz2 = build[2], build[4]
		local new_cur = sqrt((px2-cx)^2 + (pz2-cz)^2)
		-- build.dist = build.dist or sqrt((px2-px)^2 + (pz2-pz)^2)
		local prev_cur = build.dist or sqrt((px2-px)^2 + (pz2-pz)^2)
		local dlen = prev_new + new_cur - prev_cur
		-- Echo('x'..px,'z'..pz,'travel: ' ..prev_cur .. ' => ' ..prev_new .. ' + ' .. new_cur ..' = ' .. (prev_new + new_cur), 'change: ' .. dlen, 'min_dlen: ' .. min_dlen)
		if dlen < min_dlen then
			-- Echo('closer, new insert: ' .. insert_pos)
			insert_pos = i
			new_dist = prev_new
			cur_dist = new_cur
			min_dlen = dlen
		end
		px, pz = px2, pz2
		prev_new = new_cur

	end
	if prev_new < min_dlen then
		insert_pos = queueLen + 1
		-- Echo('closer at end of queue, new insert: ' .. insert_pos)
		new_dist = prev_new

	end
	-- buildData.dist = new_dist
	local pushed = buildQueue[insert_pos]
	if pushed then
		-- pushed.dist = cur_dist -- or new_cur ?
	end
	-- Echo('inserted at ',insert_pos)
	table.insert(buildQueue, insert_pos, buildData)
end
local function CancelQueue()
	--buildQueue = {}
	for i=1,#buildQueue do buildQueue[i]=nil end -- Helwor

	Spring.SendLuaUIMsg("IQ|5",'a')
	Spring.SendLuaUIMsg("IQ|5",'s')
	mCost, eCost, bCost = GetQueueCosts()
	buildTime = bCost / sDef.buildSpeed
end

local function InitialQueueHandleCommand(cmdID, cmdParams, cmdOptions)
	local areSpec = Spring.GetSpectatingState()
	if areSpec then
		return false
	end
	if cmdID == CMD_STOP then
		-- This only handles pressing the stop button in integral menu.
		CancelQueue()
		return true
	end
	if cmdID >= 0 or not(cmdParams[1] and cmdParams[2] and cmdParams[3]) then --can't handle other command.
		return false
	end
	SetSelDefID(-cmdID)
	local bx,by,bz = cmdParams[1],cmdParams[2],cmdParams[3]
	local buildFacing = Spring.GetBuildFacing()
	local msg, msg2
	
	local function CheckClash(buildData)
		for i = #buildQueue, 1, -1 do
			if DoBuildingsClash(buildData, buildQueue[i]) then
				if not (WG.drawingPlacement and (WG.drawingPlacement[2] or WG.drawingPlacement.mexes[1])) then -- dont allow placement erasing when drawing more than one placement
					table.remove(buildQueue, i)
					msg = "IQ|2|"..i
				end

				return true
			end
		end
	end
	--local unbuildableTerrain=Spring.TestBuildOrder(selDefID, bx, by, bz, buildFacing) == 0
	-- local needTerra = cmdParams[5] --~Helwor from PBH
	PBH2 = widgetHandler:FindWidget("Persistent Build Height 2")
	CheckTerra = PBH2 and WG.CheckTerra
	local needTerra=false
	if CheckTerra then 
		needTerra, by = CheckTerra(bx,bz) -- modifying height determined by PBH2. Helwor
	elseif Spring.TestBuildOrder(selDefID, bx, by, bz, buildFacing) == 0 then
		return false
	end

	if isMex[selDefID] and WG.metalSpots then
		local bestSpot = GetClosestMetalSpot(bx, bz)
		bx, bz = bestSpot.x, bestSpot.z
		by = CheckTerra and select(2,CheckTerra(bx,bz,selDefID)) or math.max(0, Spring.GetGroundHeight(bx, bz)) -- modifying height determined by PBH2. Helwor
	end
	local buildData = {selDefID, bx, by, bz, buildFacing,needTerra}

	if cmdOptions.meta then	-- space insert at front
		local anyClashes = CheckClash(buildData)
		if not anyClashes then
			if not cmdOptions.shift then
				table.insert(buildQueue, 1, buildData)
				msg = "IQ|1|"..selDefID.."|"..math.modf(bx).."|"..math.modf(by).."|"..math.modf(bz).."|"..buildFacing
			else
				InsertInQueue(buildQueue, buildData)
				local msg = "IQ|4|"..selDefID.."|"..math.modf(bx).."|"..math.modf(by).."|"..math.modf(bz).."|"..buildFacing
				Spring.SendLuaUIMsg(msg,'a')
				Spring.SendLuaUIMsg(msg,'s')

				for i=2,#buildQueue do 
					local buildData = buildQueue[i]
					local msg = "IQ|3|"..buildData[1].."|"..math.modf(buildData[1]).."|"..math.modf(buildData[2]).."|"..math.modf(buildData[3]).."|"..buildData[4]
					Spring.SendLuaUIMsg(msg,'a')
					Spring.SendLuaUIMsg(msg,'s')
				end
			end
			if buildQueue[MAX_QUEUE + 1] then	-- exceeded max queue, remove the one at the end
				table.remove(buildQueue, MAX_QUEUE + 1)
				local msg = "IQ|2|".. (MAX_QUEUE + 1)
				Spring.SendLuaUIMsg(msg,'a')
				Spring.SendLuaUIMsg(msg,'s')
			end
		end
	elseif cmdOptions.shift then	-- shift-queue
		local anyClashes = CheckClash(buildData)
		if not anyClashes then
			if not buildQueue[MAX_QUEUE] then	-- disallow if already reached max queue
				buildQueue[#buildQueue + 1] = buildData
				msg = "IQ|3|"..selDefID.."|"..math.modf(bx).."|"..math.modf(by).."|"..math.modf(bz).."|"..buildFacing
			end
		end
	else	-- normal build
		for i=1,#buildQueue do buildQueue[i]=nil end --++ Helwor
		buildQueue[1]=buildData --++
		-- buildQueue = {buildData}
		msg = "IQ|4|"..selDefID.."|"..math.modf(bx).."|"..math.modf(by).."|"..math.modf(bz).."|"..buildFacing
		--msg = "IQ|4|404|648|2|3304|1" --example spoof. This will not work
	end

	if msg then
		Spring.SendLuaUIMsg(msg,'a')
		Spring.SendLuaUIMsg(msg,'s') --need 2 msg because since Spring 97 LuaUIMsg without parameter is send info to EVERYONE (including enemy)
	end
	if msg2 then
		Spring.SendLuaUIMsg(msg2,'a')
		Spring.SendLuaUIMsg(msg2,'s')
	end
	
	mCost, eCost, bCost = GetQueueCosts()
	buildTime = bCost / sDef.buildSpeed

	SetSelDefID(nil)
	return true
end

local function InitialQueueGetTail()
	if not (buildQueue and buildQueue[1]) then
		return false
	end
	local lastQueue = buildQueue[#buildQueue]
	return lastQueue[2], lastQueue[4]
end

function widget:CommandNotify(cmdID, cmdParams, cmdOptions)
	-- Echo('receive command',cmdParams[1],cmdParams[3],'queue length',#buildQueue)
	return InitialQueueHandleCommand(cmdID, cmdParams, cmdOptions)
end

------------------------------------------------------------
-- Initialize/shutdown
------------------------------------------------------------

local function GetUnlockedBuildOptions(fullOptions)
    local teamID = Spring.GetMyTeamID()
    local unlockedCount = Spring.GetTeamRulesParam(teamID, "unlockedUnitCount")
    if not unlockedCount then
        return fullOptions
    end
    local unlockedMap = {}
    for i = 1, unlockedCount do
        local unitDefID = Spring.GetTeamRulesParam(teamID, "unlockedUnit" .. i)
        if unitDefID then
            unlockedMap[unitDefID] = true
        end
    end
    local newOptions = {}
    for i = 1, #fullOptions do
        if unlockedMap[fullOptions[i]] then
            newOptions[#newOptions + 1] = fullOptions[i]
        end
    end
    return newOptions
end

function widget:Initialize()
	WG.InitialQueueHandleCommand = InitialQueueHandleCommand
	WG.InitialQueueGetTail = InitialQueueGetTail
	if (Spring.GetGameFrame() > 0) then		-- Don't run if game has already started
		Spring.Echo("Game already started or Start Position is randomized. Removed: Initial Queue ZK") --added this message because widget removed message might not appear (make debugging harder)
		widgetHandler:RemoveWidget(self)
		return
	end
	if Spring.GetModOptions().singleplayercampaignbattleid then -- Don't run in campaign battles.
		widgetHandler:RemoveWidget(self)
		return
	end
	for uDefID, uDef in pairs(UnitDefs) do
		if uDef.customParams.ismex then
			isMex[uDefID] = true
		end

		if uDef.maxWeaponRange > 16 then
			weaponRange[uDefID] = uDef.maxWeaponRange
		end
	end
	if UnitDefNames["staticmex"] then
		isMex[UnitDefNames["staticmex"].id] = true;
	end
	WG.InitialQueue = true
	WG.preGameBuildQueue={}
	buildQueue=WG.preGameBuildQueue
	
	buildOptions = GetUnlockedBuildOptions(buildOptions)
end

function widget:Shutdown()
	WG.InitialQueue = nil
end



------------------------------------------------------------
-- Misc
------------------------------------------------------------
function widget:TextCommand(cmd)
	-- Facing commands are only handled by spring if we have a building selected, which isn't possible pre-game
	local m = cmd:match("^buildfacing (.+)$")
	if m then

		local oldFacing = Spring.GetBuildFacing()
		local newFacing
		if (m == "inc") then
			newFacing = (oldFacing + 1) % 4
		elseif (m == "dec") then
			newFacing = (oldFacing + 3) % 4
		else
			return false
		end

		Spring.SetBuildFacing(newFacing)
		Spring.Echo("Buildings set to face " .. ({"South", "East", "North", "West"})[1 + newFacing])
		return true
	end
	local buildName = cmd:match("^buildunit_([^%s]+)$")
	if buildName then
		local bDefID = buildNameToID[buildName]
		if bDefID then
			SetSelDefID(bDefID)
			return true
		end
	end
	if cmd == "stop" then
		-- This only handles the stop hotkey
		CancelQueue()
	end
end
