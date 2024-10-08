function widget:GetInfo()
	return {
		name      = "Pre-Selection Handler",
		desc      = "Utility Functions for handling units in selection box and under selection cursor",
		author    = "Shadowfury333",
		date      = "Jan 6th, 2016",
		license   = "GPLv2",
		version   = "1",
		layer     = 999, -- originally 1000 but mouse press on active control would not be detected clicking and 'holdingForSelection' would stay true
		enabled   = true,  --  loaded by default?
		api       = true,
		alwaysStart = true,
	}
end
local Echo = Spring.Echo

local spGetBoxSelectionByEngine = Spring.GetBoxSelectionByEngine
local spGetUnitNoSelect 		= Spring.GetUnitNoSelect
local spGetUnitViewPosition 	= Spring.GetUnitViewPosition
local spGetSpectatingState 		= Spring.GetSpectatingState
local spGetUnitsInRectangle 	= Spring.GetUnitsInRectangle
local spGetActiveCommand		= Spring.GetActiveCommand
local spGetMyTeamID				= Spring.GetMyTeamID
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
local myTeamID = spGetMyTeamID()

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
	local aboveMinimap = spIsAboveMiniMap(x, y)

	if outsideSpring or
		onlySelectable and cannotSelect or
		WG.drawtoolKeyPressed or
		WG.MinimapDraggingCamera and aboveMinimap or
		WG.Chili and WG.Chili.Screen0.hoveredControl or
		not ignoreSelectionBox and WG.PreSelection_IsSelectionBoxActive() or
		(WG.Chili and WG.Chili.Screen0:IsAbove(x,y)) then
		return
	end
	local type, id
	local EzTarget = WG.EzTarget
	if EzTarget  and not aboveMinimap then
		local modTarget = EzTarget.v.moddedTarget
		local modSel = EzTarget.s.moddedSelect
		local poses = EzTarget.poses
		-- Echo("modSel or modTarget is ", modSel,modSel and poses[modSel], modTarget, modTarget and poses[modTarget])
		if modSel or (modTarget and modTarget ~= EzTarget.v.defaultTarget) then
			type = 'unit'
			id = ((modSel and poses[modSel][3] or 1000)) < ((modTarget and poses[modTarget][3]) or 1000) and modSel or modTarget
			-- Echo(modSel, modTarget,"pick => ", id)
		end
	end
	if not id then
	 	type, id = SafeTraceScreenRay(x, y, false, aboveMnimap,false,true)
	end

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

local PreSelection_IsSelectionBoxActive = function (thresholdMatters)
	local x, y, lmb = spGetMouseState()
	if not lmb then
		return false
	end
	local _, here = SafeTraceScreenRay(x, y, true, thruMinimap)
	if lmb and not cannotSelect and holdingForSelection and
		not (thresholdMatters or here[1] == start[1] and here[2] == start[2] and here[3] == start[3]) then

		return true
	end
	return false
end
local PreSelection_GetUnitsInSelectionBox = function ()
	-- Echo('get units in sel box',math.round(os.clock()),spGetBoxSelectionByEngine())

	local x, y, lmb = spGetMouseState()

	if lmb and not cannotSelect and holdingForSelection then
		local spec, fullview, fullselect = spGetSpectatingState()

		if thruMinimap then
			local posX, posY, sizeX, sizeY = Spring.GetMiniMapGeometry()
            local alwaysSelectedID = WG.SelectionModkeys_GetUnitReleaseWouldClick and WG.SelectionModkeys_GetUnitReleaseWouldClick()

			x = math_max(x, posX)
			x = math_min(x, posX+sizeX)
			y = math_max(y, posY)
			y = math_min(y, posY+sizeY)
			local _, here = SafeTraceScreenRay(x, y, true, thruMinimap)
			local left = math_min(start[1], here[1])
			local bottom = math_min(start[3], here[3])
			local right = math_max(start[1], here[1])
			local top = math_max(start[3], here[3])
			local units = spGetUnitsInRectangle(left, bottom, right, top)
			if spec and fullselect then
                if alwaysSelectedID then
                    local found = false
                    for i = 1, #units do
                        if units[i] == alwaysSelectedID then
                            found = true
                            break
                        end
                    end
                    if not found then
                        units[#units + 1] = alwaysSelectedID
                    end
                end
				return (WG.SelectionRank_GetFilteredSelection and WG.SelectionRank_GetFilteredSelection(units)) or units --nil if empty
			else
				local myUnits = {}
				local teamID = 0
				local n = 0
				for i = 1, #units do
					teamID = Spring.GetUnitTeam(units[i])
					if teamID == myTeamID and not spGetUnitNoSelect(units[i]) then
						n = n + 1
						myUnits[n] = units[i]
					end
				end
				if n > 0 then
					return (WG.SelectionRank_GetFilteredSelection and WG.SelectionRank_GetFilteredSelection(myUnits)) or myUnits
				else
					return nil
				end
			end
		else
			local allBoxedUnits = {}
			local units = {}
            local alwaysSelectedID = WG.SelectionModkeys_GetUnitReleaseWouldClick and WG.SelectionModkeys_GetUnitReleaseWouldClick()
            if alwaysSelectedID then
                allBoxedUnits[#allBoxedUnits + 1] = alwaysSelectedID
            end
			if spec and fullselect then
				units = Spring.GetAllUnits()
			else
				units = Spring.GetTeamUnits(myTeamID)
			end
			local n = 0
			for i=1, #units do
				local uvx, uvy, uvz = spGetUnitViewPosition(units[i], true)
				if uvz then
					local ux, uy, uz = spWorldToScreenCoords(uvx, uvy, uvz)
					local hereMouseX, hereMouseY = x, y
					local id = units[i]
                    if ux and (id ~= alwaysSelectedID) and not spGetUnitNoSelect(id) then
                        if ux >= math_min(screenStartX, hereMouseX) and ux < math_max(screenStartX, hereMouseX) and
                                uy >= math_min(screenStartY, hereMouseY) and uy < math_max(screenStartY, hereMouseY) then
                            n = n + 1
                            allBoxedUnits[n] = id
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
    local activeControl = WG.Chili and WG.Chili.Screen0.activeControl
    if activeControl then
        return
    end
	if not boxedUnitIDs then
		boxedUnitIDs = {}
		local boxedUnits = WG.PreSelection_GetUnitsInSelectionBox()
		if boxedUnits then
			for i=1, #boxedUnits do
				boxedUnitIDs[boxedUnits[i]] = true
			end
		end
	end
	if WG.SelectionModkeys_GetUnitReleaseWouldClick and (unitID == WG.SelectionModkeys_GetUnitReleaseWouldClick()) then
		return true
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
	holdingForSelection = false
	if (button == 1) then
		if spGetActiveCommand() == 0 then
			thruMinimap = not WG.MinimapDraggingCamera and spIsAboveMiniMap(x, y)
			if not (WG.Chili and WG.Chili.Screen0:IsAbove(x,y)) then
				local _
				_, start = SafeTraceScreenRay(x, y, true, thruMinimap)
				holdingForSelection = true
			end
		end
	end
end
function widget:PlayerChanged()
	myTeamID = spGetMyTeamID()
end

function widget:Initialize() -- work around to effectively get the functions working in the same environment as the working widget
	-- indeed, when duplicate widget is encountered, the one replacing (local widget in my case) is loaded twice, but the first load result in initialization
	-- while the second load stop before, but then, the WG functions are working with the second environment that has been aborted,
	--  while the validated widget callins are working with the first
	WG.PreSelection_GetUnitUnderCursor = PreSelection_GetUnitUnderCursor
	WG.PreSelection_IsSelectionBoxActive = PreSelection_IsSelectionBoxActive
	WG.PreSelection_GetUnitsInSelectionBox = PreSelection_GetUnitsInSelectionBox
	WG.PreSelection_IsUnitInSelectionBox = PreSelection_IsUnitInSelectionBox
	widget:PlayerChanged()
end
