function widget:GetInfo()
	return {
		name      = "Pre-Selection Handler",
		desc      = "Utility Functions for handling units in selection box and under selection cursor",
		author    = "Shadowfury333",
		date      = "Jan 6th, 2016",
		license   = "GPLv2",
		version   = "1",
		layer     = 1000,
		enabled   = true,  --  loaded by default?
		api       = true,
		alwaysStart = true,
	}
end
local Echo = Spring.Echo

----------------------------------------------------------------------------
-------------------------Interface---------------------------------------

WG.PreSelection_GetUnitUnderCursor = function (onlySelectable)
	--return nil | unitID
end

WG.PreSelection_IsSelectionBoxActive = function ()
	--return boolean
end

WG.PreSelection_GetUnitsInSelectionBox = function ()
	--return nil | {[1] = unitID, etc.}
end

WG.PreSelection_IsUnitInSelectionBox = function (unitID)
	--return boolean
end

----------------------------------------------------------------------------
----------------------Implementation-------------------------------------

include("Widgets/COFCtools/TraceScreenRay.lua")


local math_acos             = math.acos
local math_atan2            = math.atan2
local math_pi               = math.pi
local math_min              = math.min
local math_max              = math.max
local spIsUnitSelected      = Spring.IsUnitSelected
local spTraceScreenRay      = Spring.TraceScreenRay
local spGetMouseState       = Spring.GetMouseState
local spIsAboveMiniMap      = Spring.IsAboveMiniMap
local spWorldToScreenCoords = Spring.WorldToScreenCoords
local spValidUnitID			= Spring.ValidUnitID

local start
local screenStartX, screenStartY = 0, 0
local cannotSelect = false
local holdingForSelection = false
local thruMinimap = false
local memo = {}
local boxedUnitIDs

-- local function SafeTraceScreenRay(x, y, onlyCoords, useMinimap, includeSky, ignoreWater)
-- 	local type, pt = Spring.TraceScreenRay(x, y, onlyCoords, useMinimap, includeSky, ignoreWater)
-- 	if not pt then
-- 		local cs = Spring.GetCameraState()
-- 		local camPos = {px=cs.px,py=cs.py,pz=cs.pz}
-- 		local camRot = {}
-- 		if cs.rx then
-- 			camRot = {rx=cs.rx,ry=cs.ry,rz=cs.rz}
-- 		else
-- 			local ry = (math_pi - math_atan2(cs.dx, -cs.dz)) --goes from 0 to 2PI instead of -PI to PI, but the trace maths work either way
-- 			camRot = {rx=math_pi/2 - math_acos(cs.dy),ry=ry,rz=0}
-- 		end
-- 		local vsx, vsy = Spring.GetViewGeometry()
-- 		local gx, gy, gz = TraceCursorToGround(vsx, vsy, {x=x, y=y}, cs.fov, camPos, camRot, -4900)
-- 		pt = {gx, gy, gz}
-- 		type = "ground"
-- 	end
-- 	return type, pt
-- end
local lastTime = os.clock()
local lastAsk = ''
local lastResponse = {'ground',{0,0,0,0,0,0}}
local lastX, lastY = 0, 0
local lastArgs = ''
local spTraceScreenRay = Spring.TraceScreenRay

local argsToString = function(a,b,c,d)
	return table.concat({tostring(a), tostring(b), tostring(c), tostring(d)})
end

local function SafeTraceScreenRay(x, y, onlyCoords, useMinimap, includeSky, ignoreWater)
	-- Echo('my func is used')
	local time = os.clock()
	local newArgs = argsToString(onlyCoords, useMinimap, includeSky, ignoreWater) 
	if time - lastTime < 0.15 and lastX==x and lastY==y and lastArgs == newArgs then
		return lastResponse[1], lastResponse[2]
	end
	lastTime, lastX, lastY, lastArgs = time, x, y, newArgs
	--
	local wantedSky = includeSky
	includeSky = true
	local type, pt = spTraceScreenRay(x, y, onlyCoords, useMinimap, includeSky, ignoreWater)
	if type == 'sky' and not wantedSky then
		pt[1], pt[2], pt[3], pt[4], pt[5], pt[6] = pt[4], pt[5], pt[6]
		type = "ground"
	end
	--
	lastResponse[1], lastResponse[2] = type, pt
	return type, pt
end
local PreSelection_GetUnitUnderCursor = function (onlySelectable, ignoreSelectionBox)
	local x, y, lmb, mmb, rmb, outsideSpring = spGetMouseState()

	if mmb or rmb or outsideSpring then
		cannotSelect = true
	elseif cannotSelect and not lmb then
		cannotSelect = false
	end

	if outsideSpring or
		onlySelectable and cannotSelect or
		WG.drawtoolKeyPressed or
		WG.MinimapDraggingCamera and spIsAboveMiniMap(x, y) or
		not ignoreSelectionBox and WG.PreSelection_IsSelectionBoxActive() then
		return
	end
	local  type, id = SafeTraceScreenRay(x, y, false, true)
	if type ~= 'unit' or not spValidUnitID(id) then
		return
	end
	return id
	-- local aboveMiniMap = spIsAboveMiniMap(x, y)
	-- local onAndUsingMinimap = (not WG.MinimapDraggingCamera and aboveMiniMap) or not aboveMiniMap
	-- if not onlySelectable or (onlySelectable and not cannotSelect)
	-- if (ignoreSelectionBox or not WG.PreSelection_IsSelectionBoxActive()) and
	-- 		onAndUsingMinimap and
	-- 		(not onlySelectable or (onlySelectable and not cannotSelect)) then
	-- 	--holding time when starting box selection, that way it avoids flickering if the hovered unit is selected quickly in the box selection
	-- 	local pointedType, data = SafeTraceScreenRay(x, y, false, true)
	-- 	if pointedType == 'unit' and Spring.ValidUnitID(data) and not WG.drawtoolKeyPressed then -- and not spIsUnitIcon(data) then
	-- 		return data
	-- 	else
	-- 		return nil
	-- 	end
	-- end
end

local PreSelection_IsSelectionBoxActive = function ()
	local x, y, lmb = spGetMouseState()
	if not lmb then
		return false
	end
	local _, here = SafeTraceScreenRay(x, y, true, thruMinimap)
	if lmb and not cannotSelect and holdingForSelection and
		not (here[1] == start[1] and here[2] == start[2] and here[3] == start[3]) then

		return true
	end
	return false
end

local PreSelection_GetUnitsInSelectionBox = function ()

	local x, y, lmb = spGetMouseState()

	if lmb and not cannotSelect and holdingForSelection then
		local spec, fullview, fullselect = Spring.GetSpectatingState()
		local myTeamID = Spring.GetMyTeamID()

		if thruMinimap then
			local posX, posY, sizeX, sizeY = Spring.GetMiniMapGeometry()
			x = math_max(x, posX)
			x = math_min(x, posX+sizeX)
			y = math_max(y, posY)
			y = math_min(y, posY+sizeY)
			local _, here = SafeTraceScreenRay(x, y, true, thruMinimap)
			local left = math_min(start[1], here[1])
			local bottom = math_min(start[3], here[3])
			local right = math_max(start[1], here[1])
			local top = math_max(start[3], here[3])
			local units = Spring.GetUnitsInRectangle(left, bottom, right, top)
			if spec and fullselect then
				return (WG.SelectionRank_GetFilteredSelection and WG.SelectionRank_GetFilteredSelection(units)) or units --nil if empty
			else
				local myUnits = {}
				local teamID = 0
				for i = 1, #units do
					teamID = Spring.GetUnitTeam(units[i])
					if teamID == myTeamID and not Spring.GetUnitNoSelect(units[i]) then
						myUnits[#myUnits+1] = units[i]
					end
				end
				if #myUnits > 0 then
					return (WG.SelectionRank_GetFilteredSelection and WG.SelectionRank_GetFilteredSelection(myUnits)) or myUnits
				else
					return nil
				end
			end
		else
			local allBoxedUnits = {}
			local units = {}

			if spec and fullselect then
				units = Spring.GetAllUnits()
			else
				units = Spring.GetTeamUnits(myTeamID)
			end
			local n = 0
			for i=1, #units do
				local uvx, uvy, uvz = Spring.GetUnitViewPosition(units[i], true)
				if uvz then
					local ux, uy, uz = spWorldToScreenCoords(uvx, uvy, uvz)
					local hereMouseX, hereMouseY = x, y
					if ux and not Spring.GetUnitNoSelect(units[i]) then
						if ux >= math_min(screenStartX, hereMouseX) and ux < math_max(screenStartX, hereMouseX) and uy >= math_min(screenStartY, hereMouseY) and uy < math_max(screenStartY, hereMouseY) then
							n = n +1
							allBoxedUnits[n] = units[i]
						end
					end
				end
			end
			if n > 0 then
				return (WG.SelectionRank_GetFilteredSelection and WG.SelectionRank_GetFilteredSelection(allBoxedUnits)) or allBoxedUnits
			else
				return nil
			end
		end
	else
		holdingForSelection = false
		return nil
	end
end

local PreSelection_IsUnitInSelectionBox = function (unitID)
	if not boxedUnitIDs then
		boxedUnitIDs = {}
		local boxedUnits = WG.PreSelection_GetUnitsInSelectionBox()
		if boxedUnits then
			for i=1, #boxedUnits do
				boxedUnitIDs[boxedUnits[i]] = true
			end
		end
	end
	return boxedUnitIDs[unitID] or false
end

function widget:Shutdown()
	WG.PreSelection_GetUnitUnderCursor = nil
	WG.PreSelection_IsSelectionBoxActive = nil
	WG.PreSelection_GetUnitsInSelectionBox = nil
	WG.PreSelection_IsUnitInSelectionBox = nil
end

function widget:Update()
	boxedUnitIDs = nil
end

function widget:MousePress(x, y, button)
	screenStartX = x
	screenStartY = y
	if button == 1 then
		holdingForSelection = false
		if Spring.GetActiveCommand() == 0 then
			thruMinimap = not WG.MinimapDraggingCamera and spIsAboveMiniMap(x, y)
			local _

			if not WG.Chili.Screen0:IsAbove(x,y) then
				_, start = SafeTraceScreenRay(x, y, true, thruMinimap)
				holdingForSelection = true
			end
		end
	end
end

function widget:Initialize() -- work around to effectively get the functions working in the same environment as the working widget
	-- indeed, when duplicate widget is encountered, the one replacing (local widget in my case) is loaded twice, but the first load result in initialization
	-- while the second load stop before, but then, the WG functions are working with the second environment that has been aborted,
	--  while the validated widget callins are working with the first
	WG.PreSelection_GetUnitUnderCursor = PreSelection_GetUnitUnderCursor
	WG.PreSelection_IsSelectionBoxActive = PreSelection_IsSelectionBoxActive
	WG.PreSelection_GetUnitsInSelectionBox = PreSelection_GetUnitsInSelectionBox
	WG.PreSelection_IsUnitInSelectionBox = PreSelection_IsUnitInSelectionBox
end
