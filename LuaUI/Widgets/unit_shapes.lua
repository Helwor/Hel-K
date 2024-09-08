function widget:GetInfo()
	return {
		name      = "UnitShapes",
		desc      = "0.5.8.zk.02 Draws blended shapes around units and buildings",
		author    = "Lelousius and aegis, modded Licho, CarRepairer, jK, Shadowfury333",
		date      = "30.07.2010",
		license   = "GNU GPL, v2 or later",
		-- layer     = -9, -- before draw grid, after outline no shader -- originally layer==2
		-- layer     = 1, -- before draw grid, after outline no shader -- originally layer==2
		later =  2000,
		enabled   = false,
		detailsDefault = 1
	}
end
local Echo = Spring.Echo
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local function SetupCommandColors(state)
	if state then
		WG.widgets_handling_selection = (WG.widgets_handling_selection or 1) - 1
		if WG.widgets_handling_selection > 0 then
			return
		end
	else
		WG.widgets_handling_selection = (WG.widgets_handling_selection or 0) + 1
	end

	local alpha = state and 1 or 0
	Spring.LoadCmdColorsConfig('unitBox  0 1 0 ' .. alpha)
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
local math_acos  = math.acos
local math_pi    = math.pi
local math_cos   = math.cos
local math_sin   = math.sin
local math_abs   = math.abs
local rad_con    = 180 / math_pi

local GL_KEEP                   = 0x1E00
local GL_REPLACE                = 0x1E01
local GL_ALWAYS                 = GL.ALWAYS
local GL_NEVER                  = GL.NEVER
local GL_INCR                   = GL.INCR
local GL_ONE_MINUS_DST_ALPHA    = GL.ONE_MINUS_DST_ALPHA
local GL_ONE_MINUS_SRC_ALPHA    = GL.ONE_MINUS_SRC_ALPHA
local GL_SRC_ALPHA              = GL.SRC_ALPHA
local GL_DST_ALPHA              = GL.DST_ALPHA
local GL_ONE                    = GL.ONE
local GL_EQUAL                  = GL.EQUAL
local GL_ZERO                   = GL.ZERO
local GL_POLYGON                = GL.POLYGON
local GL_GREATER                = GL.GREATER
local GL_LEQUAL                 = GL.LEQUAL
local GL_STENCIL_BUFFER_BIT     = GL.STENCIL_BUFFER_BIT
local GL_FUNC_ADD               = 0x8006
local GL_FUNC_REVERSE_SUBSTRACT = 0x800b
local GL_FUNC_SUBSTRACT         = 0x800a
local GL_MIN                    = 0x8007
local GL_MAX                    = 0x8008

local glClear               = gl.Clear
local glCreateList          = gl.CreateList
local glPushMatrix          = gl.PushMatrix
local glPopMatrix           = gl.PopMatrix
local glTranslate           = gl.Translate
local glScale               = gl.Scale
local glBeginEnd            = gl.BeginEnd
local glVertex              = gl.Vertex
local glColorMask           = gl.ColorMask
local glBlendFunc           = gl.BlendFunc
local glBlendFuncSeparate   = gl.BlendFuncSeparate
local glColor               = gl.Color
local glDepthMask           = gl.DepthMask
local glStencilFunc         = gl.StencilFunc
local glStencilOp           = gl.StencilOp
local glCallList            = gl.CallList
local glBlending            = gl.Blending
local glDepthTest           = gl.DepthTest
local glDrawListAtUnit      = gl.DrawListAtUnit
local glUnit                = gl.Unit
local glPolygonOffset       = gl.PolygonOffset
local glPushAttrib          = gl.PushAttrib
local glStencilTest         = gl.StencilTest
local glPopAttrib           = gl.PopAttrib
local glDeleteList          = gl.DeleteList

local spIsGUIHidden          = Spring.IsGUIHidden
local spGetUnitIsDead        = Spring.GetUnitIsDead
local spGetUnitHeading       = Spring.GetUnitHeading

local spGetVisibleUnits      = Spring.GetVisibleUnits
local spIsUnitVisible        = Spring.IsUnitVisible
local spGetSelectedUnits     = Spring.GetSelectedUnits
local spGetUnitDefID         = Spring.GetUnitDefID
local spIsUnitSelected       = Spring.IsUnitSelected

local spGetCameraPosition  = Spring.GetCameraPosition
local spGetGameFrame       = Spring.GetGameFrame
local spTraceScreenRay     = Spring.TraceScreenRay
local spGetMouseState      = Spring.GetMouseState

local spGetSpectatingState = Spring.GetSpectatingState
local spGetUnitTeam        = Spring.GetUnitTeam
local spGetMyTeamID        = Spring.GetMyTeamID
local spGetSelectedUnits   = Spring.GetSelectedUnits
local spGetUnitViewPosition= Spring.GetUnitViewPosition
local spGetTimer           = Spring.GetTimer
local spDiffTimers         = Spring.DiffTimers
local spGetHeadingFromVector = Spring.GetHeadingFromVector
local spGetUnitVelocity    = Spring.GetUnitVelocity
local SafeWGCall = function(fnName, param1) if fnName then return fnName(param1) else return nil end end
local GetUnitUnderCursor = function(onlySelectable) return SafeWGCall(WG.PreSelection_GetUnitUnderCursor, onlySelectable) end
local IsSelectionBoxActive = function() return SafeWGCall(WG.PreSelection_IsSelectionBoxActive) end
local GetUnitsInSelectionBox = function() return SafeWGCall(WG.PreSelection_GetUnitsInSelectionBox) end




--------------------------------------------------------------------------------
--------------------------------------------------------------------------------


local shapes = {}

-- local myTeamID = Spring.GetLocalTeamID()
local myTeamID = spGetMyTeamID()
--local r,g,b = Spring.GetTeamColor(myTeamID)
local maxAlpha = 1
local minAlpha = 0
local r,g,b      = 0.1, 1, 0.2
local rgba       = {r,g,b,maxAlpha}
local yellow     = {1,1,0.1,maxAlpha}
local teal       = {0.1,1,1,maxAlpha}
local red        = {1,0.2,0.1,maxAlpha}
local hoverColor = teal
local UPDATE_RATE = 0.03
local timePassed = 0

local wantHoverInner = true -- color the interior of the shape for hovered unit

local circleDivs      = 32 -- how precise circle? octagon by default
local innersize       = 0.9 -- circle scale compared to unit radius
local midsize     = 1.5
local outersize       = 1.8 -- outer fade size compared to circle scale (1 = no outer fade)
local scalefaktor     = 2.9
local rectangleFactor = 2.7
local CAlpha          = 0.89 -- min alpha

local hoverScaleDuration = 0.05
local hoverScaleStart    = 0.95
local hoverScaleEnd      = 1.0

local hoverRestedTime              = 0.05 --Time in ms below which the player is assumed to be rapidly hovering over different units
local hoverBufferDisplayTime       = 0.05 --Time in ms to keep showing hover when starting box selection
local hoverBufferScaleSuppressTime = 0.1 --Time in ms to stop box outermask from doing scale effect on a hovered unit

local boxedScaleDuration = 0.05
local boxedScaleStart    = 0.9
local boxedScaleEnd      = 1.0

local colorout = {   1,   1,   1,   0 } -- outer color
local CAlphaColor = {0, 0, 0, CAlpha} -- border color mask

-- local selColor  = {   r,   g,   b,   maxAlpha } -- inner color
-- local selColor  = {   r,   g,   b,   minAlpha } -- inner color
-- local selColor  = {   1,   1,   1,   maxAlpha } -- inner color

local teamColors = {}
local unitConf = {}
------------------------------------------------------------------------------------
------------------------------------------------------------------------------------

local lastBoxedUnits    = {}
local lastBoxedUnitsIDs = {}

local selectedUnits = {}

local visibleBoxed        = {}
local visibleAllySelUnits = {}
local hoveredUnit         = {}

local hasVisibleAllySelections = false
local forceUpdate = false
local selectionHasChanged = false

-- Speedups to avoid tiny table spam
local unitStartTimeMap  = {}
local unitDurationMap   = {}
local unitStartScaleMap = {}
local unitEndScaleMap   = {}
local unitScaleMap      = {}
local unitDefIDMap      = {}
local EMPTY_TABLE       = {}
------------------------------------------------------------------------------------
------------------------------------------------------------------------------------

local lastCamX, lastCamY, lastCamZ
local lastGameFrame = 0
local Cam, Visibles, NewView, isSpectating, fullSelect, _
local teams, teamColors, myTeamID = {}, {}
local lastDrawView, newDrawView, globalDraw, globalDraw2 = -1
local selMap, checkForSelBox = {}, false
local Units
local allySelUnits
local setupShapes, draw, startup, endDraw
local drawout, drawoutshader
local lastVisibleUnits, lastVisibleSelected, lastvisibleAllySelUnits
-- local lastDrawtoolSetting = WG.drawtoolKeyPressed

local hoverBuffer = 0
local hoverTime = 0 --how long we've been hovering
local cursorIsOn = "self"

local cheap = true


------------------------------------------------------------------------------------
------------------------------------------------------------------------------------
options_path = 'Settings/Interface/Selection/Selection Shapes'
options_order = {'allyselectionlevel', 'showallyplayercolours', 'showhover', 'showinselectionbox', 'animatehover', 'animateselectionbox'}
options = {
	allyselectionlevel = {
		name = 'Show Ally Selections',
		type = 'radioButton',
		items = {
			{name = 'Enabled',key='enabled', desc="Show selected unit of allies."},
			{name = 'Commshare Only',key='commshare', desc="Show when sharing unit control."},
			{name = 'Disabled',key='disabled', desc="Do not show any allied selection."},
		},
		value = 'commshare',
		OnChange = function(self)
			forceUpdate = true
			visibleAllySelUnits = {}
		end,
	},
	showallyplayercolours = {
		name = 'Use Player Colors when Spectating',
		desc = 'Highlight allies\' selected units with their color.',
		type = 'bool',
		value = false,
		OnChange = function(self)
			forceUpdate = true
		end,
		noHotkey = true,
	},
	showhover = {
		name = 'Highlight Hovered Unit',
		desc = 'Highlight the unit under your cursor.',
		type = 'bool',
		value = true,
		OnChange = function(self)
			hoveredUnit = {}
		end,
		noHotkey = true,
	},
	showinselectionbox = {
		name = 'Highlight Units in Selection Box',
		desc = 'Highlight the units in the selection box.',
		type = 'bool',
		value = true,
		noHotkey = true,
	},
	animatehover = {
		name = 'Animate Hover Shape',
		desc = '',
		type = 'bool',
		value = true,
		advanced = true,
		noHotkey = true,
	},
	animateselectionbox = {
		name = 'Animate Shapes in Selection Box',
		desc = '',
		type = 'bool',
		value = true,
		advanced = true,
		noHotkey = true,
	}
}

------------------------------------------------------------------------------------
------------------------------------------------------------------------------------

local function GetBoxedUnits() --Mostly a helper function for the animation system
	local allBoxedUnits = GetUnitsInSelectionBox()
	if not allBoxedUnits then
		return EMPTY_TABLE, EMPTY_TABLE
	end
	local boxedUnits = {}
	local n_boxed = 0
	local boxedUnitsIDs = {}
	local noAnimate = not options.animateselectionbox.value
	for i = 1, #allBoxedUnits do
		local unitID = allBoxedUnits[i]
		local unit = Units[unitID]
		local defID
		if unit then
			defID = unit.defID
		end
		if hoveredUnit[1] == unitID then --Transfer hovered unit here to avoid flickering
			n_boxed = n_boxed + 1
			boxedUnits[n_boxed] = unitID
			hoveredUnit[1] = nil
			boxedUnitsIDs[unitID] = n_boxed
		elseif hoverBuffer > 0 or selMap[unitID] or noAnimate then --don't scale if it just stopped being hovered over, reduces flicker effect
			n_boxed = n_boxed + 1
			boxedUnitsIDs[unitID] = n_boxed
			boxedUnits[n_boxed] = unitID
			unitStartTimeMap[unitID] = nil
			unitDurationMap[unitID] = nil
			unitStartScaleMap[unitID] = nil
			unitEndScaleMap[unitID] = nil
			unitScaleMap[unitID] = boxedScaleEnd
			unitDefIDMap[unitID] = defID or spGetUnitDefID(unitID)
		elseif not lastBoxedUnitsIDs[unitID] then
			n_boxed = n_boxed + 1
			boxedUnitsIDs[unitID] = n_boxed
			boxedUnits[n_boxed] = unitID
			unitStartTimeMap[unitID] = spGetTimer()
			unitDurationMap[unitID] = boxedScaleDuration
			unitStartScaleMap[unitID] = boxedScaleStart
			unitEndScaleMap[unitID] = boxedScaleEnd
			unitScaleMap[unitID] = nil
			unitDefIDMap[unitID] = defID or spGetUnitDefID(unitID)
		else
			n_boxed = n_boxed + 1
			boxedUnits[n_boxed] = lastBoxedUnits[lastBoxedUnitsIDs[unitID]]
			boxedUnitsIDs[unitID] = n_boxed
		end
	end
	return boxedUnits, boxedUnitsIDs
end

local HasVisibilityChanged
do
	local lastCamPos = -1
	HasVisibilityChanged = function()
		local newCamPos = NewView[2]
		if forceUpdate or newCamPos ~= lastCamPos or
			((Cam.frame - lastGameFrame) >= 15) or lastVisibleSelected[1] or selectionHasChanged then
			lastCamPos = newCamPos
			lastGameFrame = Cam.frame
			-- lastCamX, lastCamY, lastCamZ = camX, camY, camZ
			selectionHasChanged = false
			return true
		end
		return false
	end
end

function widget:SelectionChanged(selectedUnits)
	selectionHasChanged = true
end

local function GetVisibleUnits()
	local visibles = Visibles.not_iconsMap
	local visibleBoxed = EMPTY_TABLE
	local boxedUnits, boxedUnitsIDs
	if checkForSelBox and options.showinselectionbox.value then
		local _,_,lmb = spGetMouseState()
		if not lmb then
			checkForSelBox = false
		elseif next(visibles) and not WG.drawtoolKeyPressed and IsSelectionBoxActive() then --It's not worth rebuilding visible selected lists for selection box, but selection box needs to be updated per-frame
			-- local units = spGetVisibleUnits(-1, nil, false)

			boxedUnits, boxedUnitsIDs = GetBoxedUnits()
			if boxedUnits then
				local n_boxed = 0
				visibleBoxed = {}
				for unitID, boxed in pairs(boxedUnitsIDs) do
					if visibles[unitID] then
						n_boxed = n_boxed + 1
						visibleBoxed[n_boxed] = boxedUnits[boxed]
					end
				end
			end

		end

		if not boxedUnits then
			boxedUnits, boxedUnitsIDs = EMPTY_TABLE, EMPTY_TABLE
		end
		lastBoxedUnits = boxedUnits
		lastBoxedUnitsIDs = boxedUnitsIDs
	end
	if HasVisibilityChanged() then
		-- local units = spGetVisibleUnits(-1, nil, false)
		local visibleAllySelUnits, visibleSelected = EMPTY_TABLE, EMPTY_TABLE
		-- Echo("table.size(visibles) is ", table.size(visibles))
		if next(visibles) then
			allySelUnits = WG.allySelUnits
			local hasAllySel = next(allySelUnits) and   options.allyselectionlevel.value ~= "disabled" and options.allyselectionlevel.value == "enabled"
			if hasAllySel then
				local overrideAllyTeamID = isSpectating and not options.showallyplayercolours.value and 1
				visibleAllySelUnits = {}
				for unitID in pairs(allySelUnits) do
					if visibles[unitID] then
						local unit = Units[unitID]
						if unit then
							local teamIDIndex = overrideAllyTeamID or unit.teamID + 1
							if teamIDIndex then
								local visibleAllySel = visibleAllySelUnits[teamIDIndex]
								if not visibleAllySel then
									visibleAllySel = {}
									visibleAllySelUnits[teamIDIndex] = visibleAllySel
								end
								visibleAllySel[#visibleAllySel+1] = unitID
								hasVisibleAllySelections = true
							end
						end
					end
				end
			end
			if next(selMap) then
				visibleSelected = {}
				local sel_n = 0
				for unitID in pairs(selMap) do
					if visibles[unitID] then
						sel_n = sel_n + 1
						visibleSelected[sel_n] = unitID
					end
				end
			end
		end
		lastvisibleAllySelUnits = visibleAllySelUnits
		lastVisibleSelected = visibleSelected
		return visibleAllySelUnits, visibleSelected, visibleBoxed
	else
		return lastvisibleAllySelUnits, lastVisibleSelected, visibleBoxed
	end
end

local function GetHoveredUnit(dt) --Mostly a convenience function for the animation system
	local unitID = GetUnitUnderCursor(false)
	local newHoveredUnit = hoveredUnit
	local cursorIsOn = cursorIsOn
	if unitID and Visibles.not_iconsMap[unitID] then
		local unit = Units[unitID]
		local defID = unit and unit.defID
		if not newHoveredUnit[1] or unitID ~= newHoveredUnit[1] then
			if hoverTime < hoverRestedTime or not options.animatehover.value then --Only animate hover effect if player is not rapidly changing hovered unit
				newHoveredUnit[1] = unitID
				unitStartTimeMap[unitID] = nil
				unitDurationMap[unitID] = nil
				unitStartScaleMap[unitID] = nil
				unitEndScaleMap[unitID] = nil
				unitScaleMap[unitID] = hoverScaleEnd
				unitDefIDMap[unitID] = defID or spGetUnitDefID(unitID)
			else
				newHoveredUnit[1] = unitID
				unitStartTimeMap[unitID] = spGetTimer()
				unitDurationMap[unitID] = hoverScaleDuration
				unitStartScaleMap[unitID] = hoverScaleStart
				unitEndScaleMap[unitID] = hoverScaleEnd
				unitScaleMap[unitID] = nil
				unitDefIDMap[unitID] = defID or spGetUnitDefID(unitID)
			end

			-- local teamID = spGetUnitTeam(unitID)
			local unit = Units[unitID]
			local teamID = unit and unit.teamID
			if teamID then
				if teamID == myTeamID then
					cursorIsOn = "self"
				elseif teamID and Spring.AreTeamsAllied(teamID, myTeamID) then
					cursorIsOn = "ally"
				else
					cursorIsOn = "enemy"
				end
			end
			hoverTime = 0
		else
			hoverTime = math.min(hoverTime + dt, hoverRestedTime)
		end

		hoverBuffer = hoverBufferDisplayTime + hoverBufferScaleSuppressTime
		-- Echo("hoverBuffer is ", hoverBuffer)
	elseif hoverBuffer > 0 then
		hoverBuffer = math.max(hoverBuffer - dt, 0)

		if hoverBuffer <= hoverBufferScaleSuppressTime then --stop showing hover shape here, but if box selected within a short time don't do scale effect
			newHoveredUnit = {}
		end

		if hoverBuffer < hoverBufferScaleSuppressTime then
			cursorIsOn = "self" --Don't change colour at the last second when over enemy
		end
	end
	return newHoveredUnit, cursorIsOn
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

-- Creating polygons:
local function CreateDisplayLists(callbackShape)
	local displayLists = {}

	local zeroColor = {0, 0, 0, 0}

	displayLists.outermask = callbackShape.hollow(CAlphaColor, outersize, midsize) 
	displayLists.hover_inner_mask = callbackShape.hollow(CAlphaColor, innersize, midsize) 
	displayLists.hover = callbackShape.hollow(teal, outersize, midsize)

	-- displayLists.invertedSelect = callbackShape.hollow(colorout, selColor, outersize, midsize)
	displayLists.inner = callbackShape.hollow(nil,innersize, midsize)

	displayLists.inner_plain_mask = callbackShape.plain(nil, midsize)
	displayLists.outer = callbackShape.hollow(nil,outersize, midsize)
	-- displayLists.kill = callbackShape.plain(nil, outersize)
	-- displayLists.shape = callbackShape.hollow(zeroColor, CAlphaColor, innersize, midsize)
	
	return displayLists
end
local function CreateCircleLists()
	local callbackShape = {}
	
	function callbackShape.hollow(color, innersize, outersize)
		local colorout
		if color then
			-- colorout = {unpack(color)}
			-- colorout[4] = colorout[4] > 0.5 and 0 or 1
			colorout = {   1,   1,   1,   0 }
		end
		return glCreateList(function()
			glBeginEnd(GL.QUAD_STRIP, function()
				local radstep = (2.0 * math_pi) / circleDivs
				for i = 0, circleDivs do
					local a1 = (i * radstep)
					if color then
						glColor(color)
					end
					glVertex(math_sin(a1)*innersize, 0, math_cos(a1)*innersize)
					if color then
						glColor(colorout)
					end
					glVertex(math_sin(a1)*outersize, 0, math_cos(a1)*outersize)
				end
			end)
		end)
	end
	
	function callbackShape.plain(color, size)
		return glCreateList(function()
			glBeginEnd(GL.TRIANGLE_FAN, function()
				local radstep = (2.0 * math_pi) / circleDivs
				if color then
					glColor(color)
				end
				glVertex(0, 0, 0)
				for i = 0, circleDivs do
					local a1 = (i * radstep)
					glVertex(math_sin(a1)*size, 0, math_cos(a1)*size)
				end
			end)
		end)
	end
	
	shapes.circle = CreateDisplayLists(callbackShape)
end

local function CreatePolygonCallback(points, immediate)
	immediate = immediate or GL_POLYGON
	local callbackShape = {}
	
	function callbackShape.hollow(color, innersize, outersize)
		local diff = outersize - innersize
		local steps = {}
		
		for i=1, #points do
			local p = points[i]
			local x, z = p[1]*outersize, p[2]*outersize
			local xs, zs = (math_abs(x)/x and x or 1), (math_abs(z)/z and z or 1)
			steps[i] = {x, z, xs, zs}
		end
		local colorout
		if color then
			-- colorout = {unpack(color)}
			-- colorout[4] = colorout[4] > 0.5 and minAlpha or maxAlpha
			colorout = {   1,   1,   1,   0 }

		end


		return glCreateList(function()
			glBeginEnd(GL.TRIANGLE_STRIP, function()
				for i=1, #steps do
					local step = steps[i] or steps[i-#steps]
					local nexts = steps[i+1] or steps[i-#steps+1]
					if color then
						glColor(colorout)
					end
					glVertex(step[1], 0, step[2])
					if color then
						glColor(color)
					end
					glVertex(step[1] - diff*step[3], 0, step[2] - diff*step[4])
					
					if color then
						glColor(colorout)
					end
					glVertex(step[1] + (nexts[1]-step[1]), 0, step[2] + (nexts[2]-step[2]))
					if color then
						glColor(color)
					end
					glVertex(nexts[1] - diff*nexts[3], 0, nexts[2] - diff*nexts[4])
				end
			end)
		end)
	end
	
	function callbackShape.plain(color, size)
		return glCreateList(function()
			glBeginEnd(immediate, function()
				if (color) then
					glColor(color)
				end
				for i=1, #points do
					local p = points[i]
					glVertex(size*p[1], 0, size*p[2])
				end
			end)
		end)
	end
	
	return callbackShape
end

local function CreateSquareLists()
	local points = {
			{-1, 1},
			{1, 1},
			{1, -1},
			{-1, -1}
		}

	local callbackShape = CreatePolygonCallback(points, GL.QUADS)
	shapes.square = CreateDisplayLists(callbackShape)
end

local function CreateTriangleLists()
	local points = {
		{0, -1.3},
		{1, 0.7},
		{-1, 0.7}
	}
	
	local callbackShape = CreatePolygonCallback(points, GL.TRIANGLES)
	shapes.triangle = CreateDisplayLists(callbackShape)
end

local function DestroyShape(shape)
	for k,list in pairs(shape) do
		glDeleteList(list)
	end

	-- glDeleteList(shape.outermask)
	-- glDeleteList(shape.hover)
	-- glDeleteList(shape.invertedSelect)
	-- glDeleteList(shape.inner)
	-- glDeleteList(shape.inner_plain_mask)
	-- glDeleteList(shape.kill)
	-- glDeleteList(shape.shape)
end


function widget:Initialize()
	Cam = WG.Cam
	Visibles = WG.Visibles
	if not (Cam and Visibles) then
		Echo(widget:GetInfo().name .. ' requires HasViewChanged')
		widgetHandler:RemoveWidget(widget)
		return
	end
	Units = Cam.Units
	NewView = WG.NewView

	widget:PlayerChanged()
	if not WG.allySelUnits then
		WG.allySelUnits = {}
	end
	allySelUnits = WG.allySelUnits
	CreateCircleLists()
	CreateSquareLists()
	CreateTriangleLists()

	for udid, unitDef in pairs(UnitDefs) do
	
		local xsize, zsize = unitDef.xsize, unitDef.zsize
		local scale = scalefaktor*( xsize^2 + zsize^2 )^0.5
		local shape, xscale, zscale
		
		if unitDef.customParams and unitDef.customParams.selection_scale then
			local factor = (tonumber(unitDef.customParams.selection_scale) or 1)
			scale = scale*factor
			xsize = xsize*factor
			zsize = zsize*factor
		end
		
		
		if unitDef.isImmobile then
			shape = shapes.square
			xscale, zscale = rectangleFactor * xsize, rectangleFactor * zsize
		elseif (unitDef.canFly) then
			shape = shapes.triangle
			xscale, zscale = scale, scale
		else
			shape = shapes.circle
			xscale, zscale = scale, scale
		end

		unitConf[udid] = {
			shape = shape,
			xscale = xscale,
			zscale = zscale,
			noRotate = (unitDef.customParams.select_no_rotate and true) or shape == shapes.circle or false
		}
		
		if unitDef.customParams and unitDef.customParams.selection_velocity_heading then
			unitConf[udid].velocityHeading = true
		end
	end

	SetupCommandColors(false)
	widget:CommandsChanged()
end

function widget:Shutdown()
	SetupCommandColors(true)

	if globalDraw then glDeleteList(globalDraw) end
	if globalDraw2 then glDeleteList(globalDraw2) end
	for _, shape in pairs(shapes) do
		DestroyShape(shape)
	end
end


--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
local visibleSelected = {}
local degrot = {}

local HEADING_TO_RAD = 1/32768*math.pi
local RADIANS_PER_COBANGLE = math.pi / 32768

local function UpdateUnitListScale(unitList)
	if not (unitList and unitList[1]) then
		return
	end
	local now = spGetTimer()
	for i = 1, #unitList do
		local unitID = unitList[i]
		local startScale = unitStartScaleMap[unitID]
		local endScale = unitEndScaleMap[unitID]
		local scaleDuration = unitDurationMap[unitID]
		if scaleDuration and scaleDuration > 0 then
			unitScaleMap[unitID] = startScale + math.min(spDiffTimers(now, unitStartTimeMap[unitID]) / scaleDuration, 1.0) * (endScale - startScale)
		elseif startScale then
			unitScaleMap[unitID] = startScale
		elseif not unitScaleMap[unitID] then --implicitly allows explicit scale to be set on unitList entry creation
			unitScaleMap[unitID] = 1.0
		end
	end
end

local function UpdateUnitListRotation(unitList)
	if not unitList then
		return
	end
	for i = 1, #unitList do
		local unitID = unitList[i]
		local udid = unitDefIDMap[unitID] or spGetUnitDefID(unitID)
		local conf = udid and unitConf[udid]
		local rot
		if conf then
			if conf.noRotate then
				rot = 0
			elseif conf.velocityHeading then
				local vx,_,vz = spGetUnitVelocity(unitID)
				if vx then
					local speed = vx*vx + vz*vz
					if speed > 0.25 then
						local velHeading = spGetHeadingFromVector(vx, vz)*HEADING_TO_RAD
						rot = 180 + velHeading * rad_con
					end
				end
			end
		end
		if not rot then
			local heading = (not (spGetUnitIsDead(unitID)) and spGetUnitHeading(unitID) or 0) * RADIANS_PER_COBANGLE
			rot = 180 + heading * rad_con
		end
		degrot[unitID] = rot
	end
end
local function HasToDraw()
	if not (visibleSelected[1] or hoveredUnit[1] or visibleBoxed[1]) and not hasVisibleAllySelections then
		return
	end
	if spIsGUIHidden() then
		return
	end
	return true
end
function widget:Update(dt)
	timePassed = timePassed + dt
	
	if timePassed < UPDATE_RATE then
		return
	end
	timePassed = 0
	if options.showhover.value then
		hoveredUnit, cursorIsOn = GetHoveredUnit(dt)
	end
	visibleAllySelUnits, visibleSelected, visibleBoxed = GetVisibleUnits()

	if not HasToDraw() then
		return
	end

	if visibleBoxed[1] then
		cursorIsOn = "self"
	end
	
	UpdateUnitListRotation(visibleSelected)
	-- local teams = Spring.GetTeamList()
	if isSpectating and options.showallyplayercolours.value then
		for i=1, #teams do
			local team = teams[i]
			if visibleAllySelUnits[team + 1] then
				UpdateUnitListRotation(visibleAllySelUnits[team + 1])
				UpdateUnitListScale(visibleAllySelUnits[team + 1])
			end
		end
	elseif hasVisibleAllySelections then
		UpdateUnitListRotation(visibleAllySelUnits[1])
		UpdateUnitListScale(visibleAllySelUnits[1])
	end
	UpdateUnitListRotation(hoveredUnit)
	UpdateUnitListRotation(visibleBoxed)
	
	UpdateUnitListScale(visibleSelected)
	UpdateUnitListScale(hoveredUnit)
	UpdateUnitListScale(visibleBoxed)
end

local function DrawUnitShapes(unitList, color, stencil)
	if not unitList[1] then
		return
	end
	local len = #unitList
	glBlending(true)
	glBlendFunc(GL_ONE_MINUS_SRC_ALPHA, GL_SRC_ALPHA)
	glColorMask(false,false,false,true)
	for i = 1, #unitList do
		local unitID = unitList[i]
		local udid = unitDefIDMap[unitID] or spGetUnitDefID(unitID)
		local unit = unitConf[udid]
		local scale = unitScaleMap[unitID] or 1

		if unit then
			glDrawListAtUnit(unitID, unit.shape.outermask, false, unit.xscale * scale, 1.0, unit.zscale * scale, degrot[unitID], 0, degrot[unitID], 0)
		end
	end
	glColor(color)
	glColorMask(true,true,true,true)
	glBlending(true)
	glBlendFuncSeparate(GL_ONE_MINUS_DST_ALPHA, GL_DST_ALPHA, GL_ONE, GL_ONE)

	for i = 1, #unitList do
		local unitID = unitList[i]
		local udid = unitDefIDMap[unitID] or spGetUnitDefID(unitID)
		local unit = unitConf[udid]
		local scale = unitScaleMap[unitID] or 1

		if unit then
			glDrawListAtUnit(unitID, unit.shape.outer, false, unit.xscale * scale, 1.0, unit.zscale * scale, degrot[unitID], 0, degrot[unitID], 0)
		end
	end
end

local function DrawUnitShapes(unitList, color, stencil, hover_inner, exception)
	if not unitList[1] then
		return
	end
	local len = #unitList
	-- inner_plain_mask
	if stencil then -- used for any group except the hovered
		glStencilTest(true)
		glStencilFunc(GL_NEVER, 0, 1)
		glStencilOp(GL_INCR, GL_KEEP, GL_KEEP)

		for i = 1, len do
			local unitID = unitList[i]
			-- if not done then
			if not exception or not exception[unitID] then
				local udid = unitDefIDMap[unitID] or spGetUnitDefID(unitID)
				local unit = unitConf[udid]
				local scale = unitScaleMap[unitID] or 1

				if unit then
					-- glColor(color)
					-- local x,y,z = spGetUnitViewPosition(unitID)
					-- glPushMatrix()
					-- glTranslate(x,y,z)
					-- glScale(unit.xscale * scale, 1.0, unit.zscale * scale)
					-- glCallList(unit.shape.inner_plain_mask)
					-- glPopMatrix()
					glDrawListAtUnit(unitID, unit.shape.inner_plain_mask, false, unit.xscale * scale, 1.0, unit.zscale * scale, degrot[unitID], 0, degrot[unitID], 0)
				end
			end
		end
		-- glDepthMask(false)
		-- glColorMask(true, true,true,true)
		-- glColor(color)
		glStencilFunc(GL_EQUAL, 0, 0xff);
		glStencilOp(GL_KEEP, GL_KEEP, GL_REPLACE);
	end
	-----
	glBlending(true)

	glBlendFunc(GL_ONE_MINUS_SRC_ALPHA, GL_SRC_ALPHA)
	glBlendFuncSeparate(GL_ONE_MINUS_SRC_ALPHA, GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA, GL_SRC_ALPHA)
	glColorMask(false,false,false,true)
	for i = 1, len do
		local unitID = unitList[i]
		if not exception or not exception[unitID] then
			local udid = unitDefIDMap[unitID] or spGetUnitDefID(unitID)
			local unit = unitConf[udid]
			local scale = unitScaleMap[unitID] or 1

			if unit then
				if hover_inner then
					glDrawListAtUnit(unitID,unit.shape.hover_inner_mask, false, unit.xscale * scale, 1.0, unit.zscale * scale, degrot[unitID], 0, degrot[unitID], 0)
				else
					glDrawListAtUnit(unitID,unit.shape.outermask, false, unit.xscale * scale, 1.0, unit.zscale * scale, degrot[unitID], 0, degrot[unitID], 0)
				end
				

			end
		end
	end

	glColor(color)
	glColorMask(true,true,true,true)
	glBlending(true)
	glBlendFuncSeparate(GL_ONE_MINUS_DST_ALPHA, GL_DST_ALPHA, GL_ONE, GL_ONE)

	for i = 1, len do
		local unitID = unitList[i]
		if not exception or not exception[unitID] then
			local udid = unitDefIDMap[unitID] or spGetUnitDefID(unitID)
			local unit = unitConf[udid]
			local scale = unitScaleMap[unitID] or 1

			if unit then
				if hover_inner then
					glDrawListAtUnit(unitID, unit.shape.inner, false, unit.xscale * scale, 1.0, unit.zscale * scale, degrot[unitID], 0, degrot[unitID], 0)
				else
					glDrawListAtUnit(unitID, unit.shape.outer, false, unit.xscale * scale, 1.0, unit.zscale * scale, degrot[unitID], 0, degrot[unitID], 0)
				end
				
			end
		end
	end


	if stencil then
		glStencilTest(false)
	end
	glBlending(false)
end
local function DrawShapes()
	hoverColor = cursorIsOn == "enemy" and red or (cursorIsOn == "ally" and yellow or teal)
	-- local exception = {}
	-- for i,id in ipairs(visibleBoxed) do
	--  exception[id] = true
	-- end
	DrawUnitShapes(visibleSelected, rgba, true)
	if hasVisibleAllySelections then
		if isSpectating and options.showallyplayercolours.value then
			if fullSelect then hoverCall = "hover" end
			
			-- local teams = Spring.GetTeamList()
			for i = 1, #teams do
				local team = teams[i]
				if visibleAllySelUnits[team+1] then
				  DrawUnitShapes(visibleAllySelUnits[team+1], teamColors[team], true)
				end
			end
		elseif visibleAllySelUnits[1] then
			DrawUnitShapes(visibleAllySelUnits[1], yellow, true)
		end
	end
	-- glClear(GL_STENCIL_BUFFER_BIT)
	DrawUnitShapes(visibleBoxed, hoverColor, true)
	DrawUnitShapes(hoveredUnit, hoverColor, false, wantHoverInner)
	-- gl.StencilTest(false)
	glClear(GL_STENCIL_BUFFER_BIT)
end
local function Draw()
	-- glClear(GL_STENCIL_BUFFER_BIT)
	if timePassed == 0 then
		if globalDraw then
			glDeleteList(globalDraw)
			globalDraw = nil
		end
		if not HasToDraw() then
			return
		end
		globalDraw = glCreateList(DrawShapes)
	end
	if not globalDraw then
		return
	end

	-- glDepthTest(GL.ALWAYS)
	-- glCallList(globalDraw)
	-- glDepthTest(GL_LEQUAL)
	-- glBlending('reset')
	glDepthTest(GL.ALWAYS)
	glCallList(globalDraw)
	glDepthTest(GL_LEQUAL)
	glBlending('reset')
end
local function Init()
	glDepthTest(GL_LEQUAL)-- FIXME somewhere the depth test is not right when the widget is loaded for the first time
	widget.DrawWorldPreUnit = Draw
end

widget.DrawWorldPreUnit = Init
-- function widget:DrawWorld()
--  if not globalDraw then
--      return
--  end
--  glDepthTest(GL_LEQUAL)
--  glCallList(globalDraw)
--  glDepthTest(false)
--  glBlending('reset')
--  glColor(1,1,1,1)
-- end

function widget:MousePress(_,_,button)
	if button == 1 then
		checkForSelBox = true
	end
end
function widget:CommandsChanged()
	for k,v in pairs(selMap) do selMap[k] = nil end
	for i, id in ipairs(spGetSelectedUnits()) do
		selMap[id] = true
	end
end
function widget:PlayerChanged()
	myTeamID = spGetMyTeamID()
	isSpectating, _, fullSelect = spGetSpectatingState()
	teams = Spring.GetTeamList()
	for i = 1, #teams do
		local team = teams[i]
		local r,g,b = Spring.GetTeamColor(team)
		teamColors[team] = {r, g, b, 1}
	end
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
