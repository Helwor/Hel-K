function widget:GetInfo()
	return {
		name      = "Decloak Range",
		desc      = "Display decloak range around cloaked units. v2",
		author    = "banana_Ai, dahn, GoogleFrog (rewrite), ashdnazg (effectively), Helwor (implement sphere and some optimization)",
		date      = "15 Jul 2016",
		license   = "GNU GPL v2",
		layer     = 0,
		enabled   = true,
	}
end

VFS.Include("LuaRules/Utilities/glVolumes.lua")
local Echo = Spring.Echo
local Chili

local spGetUnitDefID			= Spring.GetUnitDefID
local spGetUnitPosition			= Spring.GetUnitPosition
local spGetUnitRulesParam  		= Spring.GetUnitRulesParam
local spGetUnitIsCloaked		= Spring.GetUnitIsCloaked
local spGetSelectedUnits		= Spring.GetSelectedUnits
local spGetUnitIsCloaked		= Spring.GetUnitIsCloaked
local spGetSelectedUnitsSorted 	= Spring.GetSelectedUnitsSorted
local spIsSphereInView			= Spring.IsSphereInView

local gl 						= gl
local GL						= GL
local Spring					= Spring
local glColor					= gl.Color
local drawAlpha = 0.17
local disabledColor = { 0.9,0.5,0.3, drawAlpha}
local cloakedColor = { 0.4, 0.4, 0.9, drawAlpha} -- drawAlpha on purpose!
local disabledColor_less = { 0.9,0.5,0.3, drawAlpha/2}
local cloakedColor_less = { 0.4, 0.4, 0.9, drawAlpha/2} -- drawAlpha on purpose!


local decloakDist = setmetatable({}, {__index = function(self, defID) rawset(self, defID, UnitDefs[defID].decloakDistance or false) end})
local currentSelection = false
local selectionMap = false
local selectionCanCloak = false
local myPlayerID, myTeamID
local spec, fullview = Spring.GetSpectatingState()
local merged, useSphere = true, false -- defaults

options_path = 'Settings/Interface/Defence and Cloak Ranges'
options_order = {
	"label",
	"drawranges",
	"mergeCircles",
	"useSphere",
}

options = {
	label = { type = 'label', name = 'Decloak Ranges' },
	drawranges = {
		name = 'Draw decloak ranges',
		type = 'bool',
		value = true,
		OnChange = function (self)
			if self.value then
				widgetHandler:UpdateCallIn("DrawWorldPreUnit")
			else
				widgetHandler:RemoveCallIn("DrawWorldPreUnit")
			end
		end
	},
	mergeCircles = {
		name = "Draw merged cloak circles",
		desc = "Merge overlapping grid circle visualisation. Does not work on older hardware and should automatically disable.",
		type = 'bool',
		value = merged,
		OnChange = function(self)
			merged = self.value
		end,
	},
	useSphere = {
		name = "Use Sphere",
		desc = "Use sphere instead of circle on ground (real decloak range is spherical)",
		type = 'bool',
		value = useSphere,
		path = 'Hel-K/' ..widget.GetInfo().name,
		OnChange = function(self)
			useSphere = self.value
		end,
	},
}

-------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------
-- Drawing
local function GetSubjects(wantMerged)
	local cloakeds = {}
	local pass1, pass2
	if wantMerged then
		pass1, pass2 = {}, {}
	else
		pass1 = {}
	end
	for i = 1, #currentSelection do
		local unitID = currentSelection[i]
		local unitDefID = spGetUnitDefID(unitID)
		if unitDefID then
			local cloaked = spGetUnitIsCloaked(unitID)
			local wantCloak = (not cloaked) and ((spGetUnitRulesParam(unitID, "wantcloak") == 1) or (spGetUnitRulesParam(unitID, "areacloaked") == 1))
			if cloaked or wantCloak then
				local radius
				local commCloaked = spGetUnitRulesParam(unitID, "comm_decloak_distance")
				if commCloaked and (commCloaked > 0) then
					radius = commCloaked
				end
				
				local areaCloaked = spGetUnitRulesParam(unitID, "areacloaked_radius")
				if areaCloaked and (areaCloaked > 0) then
					radius = areaCloaked
				end
				if not radius then
					radius = decloakDist[unitDefID]
				end
				if radius then
					local x, y, z, _, y2 = spGetUnitPosition(unitID, true)
					if spIsSphereInView(x, y2, z, radius) then
						if pass2 and not cloaked then
							pass2[unitID] = radius
						else
							pass1[unitID] = radius
							cloakeds[unitID] = cloaked
						end
					end
				end
			end
		end
	end
	return pass1, pass2, cloakeds
end

local function SphereVertex(x, y, z, neg)
    if neg then
        gl.Normal(-x, -y, -z)
    else
        gl.Normal(x, y, z)
    end
    gl.Vertex(x, y, z)
end



local function Sphere(divs, arcs, neg)
	local cos, sin = math.cos, math.sin
	local PI = math.pi
	local twoPI = PI * 2

    local divRads = PI / divs
    local minRad = sin(divRads)
    
    -- top
    gl.BeginEnd(GL.TRIANGLE_FAN, function()
        SphereVertex(0, 1, 0, neg)
        local bot = cos(divRads)
        local botRad = sin(divRads)
    
        for i = 0, arcs do
            local a = i * twoPI / arcs
            SphereVertex(sin(a) * botRad, bot, cos(a) * botRad, neg)
        end
    end)
    -- sides
    for d = 1, divs - 2 do -- 
        -- gl.BeginEnd(GL.QUAD_STRIP, function()
        gl.BeginEnd(GL.TRIANGLE_STRIP, function() -- much faster than GL.QUAD_STRIP
            local topRads = divRads * (d + 0)
            local botRads = divRads * (d + 1)
            local top = cos(topRads)
            local bot = cos(botRads)
            local topRad = sin(topRads)
            local botRad = sin(botRads)
        
            for i = 0, arcs do
                local a = i * twoPI / arcs
                SphereVertex(sin(a) * topRad, top, cos(a) * topRad, neg)
                SphereVertex(sin(a) * botRad, bot, cos(a) * botRad, neg)
            end
        end)
    end
    -- bottom 
    gl.BeginEnd(GL.TRIANGLE_FAN, function()
        SphereVertex(0, -1, 0, neg)
        for i = 0, arcs do
            local a = -i * twoPI / arcs
            SphereVertex(sin(a) * minRad, -cos(divRads), cos(a) * minRad, neg)
        end
    end)
end
local list = {}
list.sphere = gl.CreateList(Sphere, 16, 32, false)

list.mergeVolumes = gl.CreateList(
	function() -- Draw only where it has not been drawn
		gl.Clear(GL.STENCIL_BUFFER_BIT, 0)
		gl.DepthMask(false)
		gl.StencilTest(true)
		gl.DepthTest(true)
		gl.StencilOp(GL.KEEP, GL.KEEP, GL.INCR)
		gl.StencilMask(1)
		gl.StencilFunc(GL.EQUAL, 0, 1)
	end
)

list.mergeVolumesEnd = gl.CreateList(
	function ()
		gl.DepthTest(false)
		gl.StencilTest(false)
		gl.StencilMask(0xff)
		gl.Clear(GL.STENCIL_BUFFER_BIT)
	end
)


function gl.Utilities.DrawSimpleSphere(x, y, z, radius)
  gl.PushMatrix()
  gl.Translate(x, y, z)
  gl.Scale(radius, radius, radius)
  gl.CallList(list.sphere)
  gl.PopMatrix()
end

-- copied from glVolume (couldn't find a way to do it per batch)
-- merge the ground inprint of volume
list.stencilMergeInp = gl.CreateList(
	function()
		gl.DepthMask(false)
		if (gl.DepthClamp) then gl.DepthClamp(true) end
		gl.StencilTest(true)

		gl.Culling(false)
		gl.DepthTest(true)
		gl.ColorMask(false, false, false, false)
		gl.StencilOp(GL.KEEP, GL.INVERT, GL.KEEP)
		gl.StencilMask(1)
		gl.StencilFunc(GL.ALWAYS, 0, 1)
	end
)
list.stencilMergeInpApply = gl.CreateList(
	function()
		gl.Culling(GL.FRONT)
		gl.DepthTest(false)
		gl.ColorMask(true, true, true, true)
		gl.StencilOp(GL.KEEP, GL.INCR, GL.INCR)
		gl.StencilMask(3)
		gl.StencilFunc(GL.EQUAL, 1, 3)
	end
)

list.stencilMergeInpEnd = gl.CreateList(
	function()
		if (gl.DepthClamp) then gl.DepthClamp(false) end
		gl.StencilTest(false)
		-- gl.DepthTest(true)
		gl.Culling(false)
	end
)


function MergeInprint(vol_dlist)
	gl.CallList(list.stencilMergeInp)
	gl.CallList(vol_dlist)
	gl.CallList(list.stencilMergeInpApply)
	gl.CallList(vol_dlist)
	gl.CallList(list.stencilMergeInpEnd)
end

function gl.Utilities.DrawMergedSphereInprint(x, y, z, radius) -- Draw ground inprint of spheres
  gl.PushMatrix()
  gl.Translate(x, y, z)
  gl.Scale(radius, radius, radius)
  MergeInprint(list.sphere)
  gl.PopMatrix()
end

local DrawSphereInprint = gl.Utilities.DrawMergedSphereInprint


local function DrawDecloakRanges(pass, cloakeds)
	if not next(pass) then
		return
	end
	local merged = merged and next(pass, next(pass))
	local drawGroundCircle, DrawSphere = false, false
	if useSphere and gl.Utilities.DrawSimpleSphere then
		DrawSphere = gl.Utilities.DrawSimpleSphere
	else
		drawGroundCircle = options.mergeCircles.value and gl.Utilities.DrawMergedGroundCircle or gl.Utilities.DrawGroundCircle
	end

	if DrawSphere --[[and merged--]] then
		for unitID, radius in pairs(pass) do
			glColor(cloakeds[unitID] and cloakedColor or disabledColor)
			local _, _, _, x, y, z = spGetUnitPosition(unitID, true)
			DrawSphereInprint(x, y, z, radius)
		end

	end
	if DrawSphere then
		gl.BlendFuncSeparate(GL.SRC_ALPHA, GL.ONE, GL.ONE_MINUS_SRC_ALPHA, GL.ONE_MINUS_DST_ALPHA)
		if merged then
			gl.CallList(list.mergeVolumes)
		else
			gl.Culling(GL.BACK)
			gl.DepthTest(true)
		end
	end
	for unitID, radius in pairs(pass) do
		if DrawSphere then
			glColor(cloakeds[unitID] and cloakedColor_less or disabledColor_less)
		else
			glColor(cloakeds[unitID] and cloakedColor or disabledColor)
		end
		if DrawSphere then
			local _, _, _, x, y, z = spGetUnitPosition(unitID, true)
			DrawSphere(x ,y ,z, radius)
		else
			local x, y, z = spGetUnitPosition(unitID)
			drawGroundCircle(x, z, radius)
		end
	end

	if DrawSphere then
		gl.BlendFuncSeparate(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA, GL.ONE, GL.ZERO)
		if merged then
			gl.CallList(list.mergeVolumesEnd)
		else
			gl.Clear(GL.STENCIL_BUFFER_BIT, 0)
		end
	else
		gl.Clear(GL.STENCIL_BUFFER_BIT, 0)
	end
end

function widget:CommandsChanged()

	currentSelection = spGetSelectedUnits()
	selectionCanCloak = false
	selectionMap = {}
	for i = 1, #currentSelection do
		local unitID = currentSelection[i]
		selectionMap[unitID] = true
		if not selectionCanCloak then
			if spGetUnitDefID(unitID) then
				if spGetUnitIsCloaked(unitID)
				or spGetUnitRulesParam(unitID, "wantcloak") == 1
				or spGetUnitRulesParam(unitID, "areacloaked") == 1
				then
					selectionCanCloak = true
				end
			end
		end
	end
end

function widget:UnitCloaked(curID, curUnitDefID, teamID)
	if selectionCanCloak or teamID ~= myTeamID and not (spec or fullview) then
		return
	end
	selectionCanCloak = selectionMap[curID]
end

local function DrawRanges()
	local pass1, pass2, cloakeds = GetSubjects(merged)
	DrawDecloakRanges(pass1, cloakeds)
	if pass2 then
		DrawDecloakRanges(pass2, cloakeds)
	end
end

function DrawFunc()
	if Spring.IsGUIHidden() then
		return
	end
	if selectionCanCloak then
		DrawRanges()
		glColor(1,1,1,1)
	end
end
function widget:PlayerChanged(playerID)
	if playerID == myPlayerID then
		myTeamID = Spring.GetMyTeamID()
		spec, fullview = Spring.GetSpectatingState()
	end
end
function widget:DrawWorldPreUnit()
	DrawFunc()
end

function widget:Initialize()
	myPlayerID = Spring.GetMyPlayerID()
	widget:PlayerChanged(myPlayerID)
	widget:CommandsChanged()
end

function widget:Shutdown()
	for _, l in pairs(list) do
		gl.DeleteList(l)
	end
end
