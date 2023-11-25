
local ver = 0.1
function widget:GetInfo()
	return {
		name      = "Infos On Icons",
		desc      = "Draw on top of icon when zoomed out, health and wether ally unit is selected, ver " .. ver,
		author    = "Helwor",
		date      = "Jan 2023",
		license   = "GNU GPL, v2",
		layer     = 4000, 
		enabled   = true,  --  loaded by default?
		handler   = true,
	}
end
local Echo = Spring.Echo

local useList
local Cam
local InSight
local debugInSight = false
local currentFrame = Spring.GetGameFrame()
local normalScale = 1366*768
local scale = 1


local strSel = '*'
local strHealth = ' o'
local onlyOnIcons = false
local showAllySelected = true
local showHealth =true
local showCloaked = true
local alpha = 0.8
local alphaHealth = 1
local disarmUnits

local RADAR_TIMEOUT = 30 * 12






options_path = 'Hel-K/Draw On Icons'
-- local hotkeys_path = 'Hotkeys/Construction'

options_order = {
	'only_on_icons',
	'show_ally_selected',
	'alpha_selected',
	'show_health',
	'show_cloaked',
	'alpha_health',
	'debuginsight',
}
options = {
	only_on_icons = {
		name = 'Draw only on unit icons',
		type = 'bool',
		desc = "draw only when unit is an icon",
		value = false,
		OnChange = function(self)
			onlyOnIcons = self.value
		end
	},
	show_ally_selected = {
		name = 'Draw on unit selected by an ally',
		type = 'bool',
		value = true,
		OnChange = function(self)
			showAllySelected = self.value
		end
	},
	alpha_selected = {
		name            = 'Transparency on selected',
		type            = 'number',
		value           = 0.8,
		min             = 0,
		max             = 1,
		step            = 0.05,
		tooltipFunction = function(self)
							return self.value
						  end,
		OnChange        = function(self)
							alpha = self.value
						end
	},
	show_health = {
		name = 'draw health indicator',
		type = 'bool',
		value = true,
		OnChange = function(self)
			showHealth = self.value
		end
	},
	show_cloaked = {
		name = 'draw cloaked indicator',
		type = 'bool',
		value = true,
		OnChange = function(self)
			showCloaked = self.value
		end
	},
	alpha_health = {
		name            = 'Transparency health',
		type            = 'number',
		value           = 1,
		min             = 0,
		max             = 1,
		step            = 0.05,
		tooltipFunction = function(self)
							return self.value
						  end,
		OnChange        = function(self)
							alphaHealth = self.value
						end
	},
	debuginsight = {
		name ='debug units in sight',
		value = debugInSight,
		type = 'bool',
		OnChange = function(self)
			debugInSight = self.value
		end,
	}
}
for k,opt in pairs(options) do
	opt:OnChange()
end
local options = options
local debugging = true -- need UtilsFunc.lua
local f = debugging and VFS.Include('LuaUI\\Widgets\\UtilsFunc.lua')

local Units

local ignoreUnitDefID = {
	[UnitDefNames['terraunit'].id ] = true,
	[UnitDefNames['wolverine_mine'].id] = true,
	[UnitDefNames['shieldscout'].id] = true,
}
for defID, def in pairs(UnitDefs) do
	if def.name:match('drone') then
		ignoreUnitDefID[defID] = true
	end
end

local lowCostDefID = {}
for defID, def in pairs(UnitDefs) do
	if def.cost < 100 then
		lowCostDefID[defID] = true
	end
end

local spGetUnitDefID                = Spring.GetUnitDefID
local spGetAllUnits                 = Spring.GetAllUnits
local spGetMyTeamID                 = Spring.GetMyTeamID
local spGetUnitPosition             = Spring.GetUnitPosition
-- local spAreTeamsAllied              = Spring.AreTeamsAllied
local spGetUnitTeam                 = Spring.GetUnitTeam
local spValidUnitID                 = Spring.ValidUnitID
local spGetUnitHealth               = Spring.GetUnitHealth
local spGetSpectatingState          = Spring.GetSpectatingState
local spGetUnitRulesParam           = Spring.GetUnitRulesParam
local spGetUnitHealth               = Spring.GetUnitHealth
local spGetUnitIsDead               = Spring.GetUnitIsDead
-- local spGetUnitTeam                 = Spring.GetUnitTeam
local spIsUnitIcon                  = Spring.IsUnitIcon
local spIsUnitVisible               = Spring.IsUnitVisible
local spGetGameFrame                = Spring.GetGameFrame
local spGetUnitRulesParam           = Spring.GetUnitRulesParam
local UnitDefs = UnitDefs

local remove = table.remove
local round = math.round

local myTeamID = Spring.GetMyTeamID()

local Units

local colors = {
	 white          = {   1,    1,    1,   1 },
	 black          = {   0,    0,    0,   1 },
	 grey           = { 0.5,  0.5,  0.5,   1 },
	 lightgrey      = { 0.75,0.75, 0.75,   1 },
	 red            = {   1, 0.25, 0.25,   1 },
	 darkred        = { 0.8,    0,    0,   1 },
	 lightred       = {   1,  0.6,  0.6,   1 },
	 magenta        = {   1, 0.25,  0.3,   1 },
	 rose           = {   1,  0.6,  0.6,   1 },
	 bloodyorange   = {   1, 0.45,    0,   1 },
	 orange         = {   1,  0.7,    0,   1 },
	 copper         = {   1,  0.6,  0.4,   1 },
	 darkgreen      = {   0,  0.6,    0,   1 },
	 green          = {   0,    1,    0,   1 },
	 lightgreen     = { 0.7,    1,  0.7,   1 },
	 darkenedgreen  = { 0.4,    0.8,  0.4, 1 },
	 blue           = { 0.3, 0.35,    1,   1 },
	 fade_blue      = {   0,  0.7,  0.7, 0.6 },
	 paleblue       = { 0.6,  0.6,    1,   1 },
	 tainted_blue   = { 0.5,    1,    1,   1 },
	 turquoise      = { 0.3,  0.7,    1,   1 },
	 lightblue      = { 0.7,  0.7,    1,   1 },
	 cyan           = { 0.3,    1,    1,   1 },
	 ice            = {0.55,    1,    1,   1 },
	 lime           = { 0.5,    1,    0,   1 },
	 yellow         = {   1,    1,  0.3,   1 },
	 ocre           = {   1,    1,  0.3,   1 },
	 brown          = { 0.9, 0.75,  0.3,   1 },
	 purple         = { 0.9,    0,  0.7,   1 },
	 hardviolet     = {   1, 0.25,    1,   1 },
	 violet         = {   1,  0.4,    1,   1 },
	 paleviolet     = {   1,  0.7,    1,   1 },
	 whiteviolet    = {   1, 0.85,    1,   1 },
	 nocolor        = {   0,    0,    0,   0 },
}

local scale,vsy,vsy
local UseFont
local TextDrawCentered 

local font            = "LuaUI/Fonts/FreeSansBold_14"
local fontWOutline    = "LuaUI/Fonts/FreeSansBoldWOutline_14"     -- White outline for font (special font set)
local monobold        = "LuaUI/Fonts/FreeMonoBold_12"

local max,min = math.max,math.min
local floor = math.floor
-- Points Debugging
local spWorldToScreenCoords = Spring.WorldToScreenCoords
-- local GetTextWidth        = fontHandler.GetTextWidth
-- local TextDraw            = fontHandler.Draw
-- local TextDrawRight       = fontHandler.DrawRight
-- local glRect              = gl.Rect
local glColor = gl.Color
local glPushMatrix 	= gl.PushMatrix
local glScale      	= gl.Scale
local glPopMatrix  	= gl.PopMatrix
local glCallList   	= gl.CallList
local glCreateList 	= gl.CreateList
local glDeleteList 	= gl.DeleteList
local glTranslate  	= gl.Translate
local glPushMatrix 	= gl.PushMatrix
local glPopMatrix 	= gl.PopMatrix


local spGetUnitViewPosition = Spring.GetUnitViewPosition
-- local spGetTeamUnits = Spring.GetTeamUnits
local spGetUnitHealth = Spring.GetUnitHealth
-- local spGetVisibleUnits = Spring.GetVisibleUnits
-- local spGetSpectatingState = Spring.GetSpectatingState
local spIsUnitVisible = Spring.IsUnitVisible
local spGetAllUnits  = Spring.GetAllUnits

for i,color in pairs(colors) do
	color[4] = alpha
end
local    green,           yellow,           red,                white,              blue,               paleblue
	= colors.green,    colors.yellow,    colors.red,        colors.white,      colors.blue,         colors.paleblue
local    orange ,        turquoise,         paleviolet,         violet,             hardviolet
	= colors.orange,  colors.turquoise,  colors.paleviolet, colors.violet,     colors.hardviolet
local copper,             white,            grey,               lightgreen,         darkenedgreen,       lime
	= colors.copper,  colors.white,      colors.grey,       colors.lightgreen, colors.darkenedgreen,   colors.lime
local whiteviolet, lightblue, lightgrey  = colors.whiteviolet, colors.lightblue, colors.lightgrey 
local cyan, ice = colors.cyan, colors.ice
local nocolor = colors.nocolor

local b_ice, b_grey, b_grey2, b_whiteviolet = {unpack(ice)}, {unpack(grey)}, {unpack(grey)}, {unpack(whiteviolet)}
local blinkcolor = {
	[b_ice] = b_grey,
	[b_whiteviolet] = b_grey2,
	[b_grey] = b_ice,
	[b_grey2] = b_whiteviolet,
}
-- local font = {
--   classname     = 'font',

--   font          = "FreeSansBold.otf",
--   size          = 12,
--   outlineWidth  = 3,
--   outlineWeight = 3,

--   shadow        = false,
--   outline       = false,
--   color         = {1,1,1,1},
--   outlineColor  = {0,0,0,1},
--   autoOutlineColor = true,
-- }
-- local myFont = FontHandler.LoadFont(font, 20, 20, 3)
--     Echo("myFont is ", myFont)
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- local lastFrame = spGetGameFrame()
local counter = 0
-- local thisFrame = spGetGameFrame()
local lists = {}
for _,color in pairs(colors) do
  lists[color] = {}
end
for color1,color2 in pairs(blinkcolor) do
  lists[color1] = {}
  lists[color2] = {}
end

local NewView, Visibles, VisibleIcons
local problems = {}


local GetUnitPos = function(id, threshold)
    local unit = Units[id]
    if not unit then
    	return
    end
    local pos = unit.pos
    if not unit.isStructure and currentFrame > pos.frame + threshold then
        pos[1], pos[2], pos[3] = spGetUnitPosition(id)
        pos.frame = currentFrame
    end
    return  pos[1], pos[2], pos[3]
end
function widget:GameFrame(f)
	currentFrame = f
end
local lastStatus = {}
local inRadar = {}
local function ApplyColor(id, color, color2, blink)
	local x,y,z = GetUnitPos(id,0)
	if not x then
		return
	end

	local mx,my = spWorldToScreenCoords(x,y,z)
	if color2 then
	  	local list = lists[color2][strHealth]
		color2[4] = alphaHealth
		glColor(color2)
		if list then
		-- UseFont(monobold)
			glPushMatrix()
			glTranslate(floor(mx+0.5),floor(my+0.5),0)
			glCallList(list)
			glPopMatrix()
		else
			TextDrawCentered(strHealth, mx, my)
	  	end
	end
	if color then
		local color = blink and blinkcolor[color] or color
		color[4] = alpha
		glColor(color)
		local list = lists[color][strSel]
		if list then
			glPushMatrix()
			glTranslate(floor(mx+0.5),floor(my+0.5),0)
			glCallList(list)
			glPopMatrix()
		else
			TextDrawCentered(strSel, mx, my)
		  -- glPopMatrix()
		end
	end

end
local function Treat(id,allySelUnits,unit, blink, debugInSight)
	-- if spIsUnitVisible(id) and (not onlyOnIcons or spIsUnitIcon(id)) then
		local color, color2
		local x,y,z = GetUnitPos(id,0)
		if x then

			-- local hp,maxhp,_,_,bp = spGetUnitHealth(id)
			local health = unit.health
			local paralyzed
			local hp,maxhp,bp, para1, para2
			if health then
				hp,maxhp, paraDmg,bp = health[1], health[2], health[3], health[5]
				-- if not maxhp then
				-- 	Echo('no max hp for unit ',unit.defID and UnitDefs[unit.defID].name,unpack(health))
				-- 	return
				-- end
				paralyzed = paraDmg > maxhp
				-- health.frame = currentFrame
				health = hp/(maxhp*bp)

			end
			-- local alpha = alpha
			color = showAllySelected and allySelUnits[id] and white
			-- if unit.isKnown then color = violet
			-- end
			-- local builder = bp<1 and Units[unit.builtBy]
			color = color
				or bp and bp>=0.0001 and (
						bp<0.8 and grey
						or bp<0.9999 and lightgreen
					)
				or paralyzed and b_ice
				or disarmUnits[id]~=nil and b_whiteviolet
				-- or builder and not builder.isFactory and white
				or unit.tracked and (
						  -- unit.assisting and darkenedgreen
						unit.isIdle and blue
						or unit.autoguard and darkenedgreen
						or unit.building and unit.manual and red
						-- or unit.isFighting and turquoise
						or unit.manual and (unit.actualCmd==90 and hardviolet or orange)
						or unit.isFighting and turquoise
						or unit.waitManual and yellow
						-- or unit.actualCmd == 90 and paleviolet
						or unit.cmd and green
					)

			if not color then
				local jumpReload = unit.isJumper and unit.isMine and spGetUnitRulesParam(id,'jumpReload')
				if jumpReload then
					color = jumpReload>=1 and darkenedgreen
						  or jumpReload>=0.8 and lime
				end
			end
			-- if not color and showCloaked and unit.isCloaked then
			--   alpha = 0.7
			--   color = paleblue
			-- end
			color2 = showHealth and health and (health<0.3 and red or health<0.6 and orange)

			if debugInSight then
				color2 = white
			end


			-- if unit.isAllied then
			-- 	color2 = grey
			-- end
			-- if not color2 and unit.checkHealth then
			-- 	color2 = turquoise
			-- end
			-- if unit.health then
			-- 	color = yellow
			-- 	if unit.health[5] then
			-- 		color = false
			-- 	end
			-- else
			-- 	color = red
			-- end
			-- if unit.isAllied then
			-- 	color2 = white
			-- end
			-- if unit.isInSight then
			-- 	color = white
			-- end
			-- if unit.checkHealth then
			-- 	color2 = yellow
			-- end
			-- if unit.checkHealth and not unit.isInSight then
			-- end
			if color or color2 then
				local ls = lastStatus[id]
				if not ls then
					lastStatus[id] = {color, color2}
				else
					ls[1], ls[2] = color, color2
				end
				

				local mx,my = spWorldToScreenCoords(x,y,z)
				if color2 then
				  local list = lists[color2][strHealth]

					color2[4] = alphaHealth
					glColor(color2)
					if list then
					-- UseFont(monobold)
						glPushMatrix()
						glTranslate(floor(mx+0.5),floor(my+0.5),0)
						glCallList(list)
						glPopMatrix()
					else
						TextDrawCentered(strHealth, mx, my)
				  	end
				end
				if color then
					local color = blink and blinkcolor[color] or color
					color[4] = alpha
					glColor(color)
					local list = lists[color][strSel]
					if list then
						glPushMatrix()
						glTranslate(floor(mx+0.5),floor(my+0.5),0)
						glCallList(list)
						glPopMatrix()
					else
						TextDrawCentered(strSel, mx, my)
					  -- glPopMatrix()
					end
				end
			else
				lastStatus[id] = nil
			end
		end
	-- end

end
function widget:GameOver()
	widgetHandler:RemoveWidget(widget)
end
function widget:UnitEnteredLos(unitID)
	if lastStatus[unitID] then
		inRadar[unitID] = nil
		lastStatus[unitID] = nil
	end
end
function widget:UnitLeftLos(unitID)
	if lastStatus[unitID] then
		inRadar[unitID] = lastStatus[unitID]
		inRadar[unitID].toframe = currentFrame + RADAR_TIMEOUT
	end
end
function widget:UnitLeftRadar(unitID)
	if inRadar[unitID] then
		inRadar[unitID] = nil
		lastStatus[unitID] = nil
	end
end
function widget:UnitDestroyed(unitID)
	if inRadar[unitID] then
		inRadar[unitID] = nil
		lastStatus[unitID] = nil
	end
end
local globalList
local problems = {}
local GlobalDraw = function()
	UseFont(monobold)
	local allySelUnits = WG.allySelUnits
	local subjects = onlyOnIcons and VisibleIcons or Visibles

	local count = 0
	for id in pairs(problems) do
		if Units[id] then
			problems[id] = nil
		end
	end
	local blink = os.clock()%0.5 < 0.25
	local size = table.size(subjects)
	local avoidLowCost = size > 300
	for id in pairs(subjects) do
		local unit = Units[id]
		if unit then
			local defID = unit.defID
			if defID then

				-- if unit.checkHealth then
				-- 	count = count + 1
				-- end

				if not (avoidLowCost and lowCostDefID[defID] or ignoreUnitDefID[defID]) then
					Treat(id,allySelUnits, unit, blink, debugInSight)
				end
			-- elseif not spGetUnitIsDead(id) and spValidUnitID(id) then
				-- 	local defID = spGetUnitDefID(id)
				-- 	if defID then
				-- 		local name = defID and UnitDefs[defID].name
				-- 		if not problems[id] then
				-- 			Echo('problem with unit not dead',id,unit, 'unknown?',unit and unit.isUnknown, 'name?',name)
				-- 			problems[id] = name
				-- 		end
				-- 	end
			end
		end
	end
	-- Echo("table.size(inRadar) is ", table.size(inRadar))
	-- show last seen unit's symbol and color for a few sec ocne they gone out of view
	if not debugInSight then
		for id, t in pairs(inRadar) do
			if t.toframe < currentFrame then
				inRadar[id] = nil
				lastStatus[id] = nil
			else
				ApplyColor(id, t[1], t[2], blink)
			end
		end
	end
	-- for id in pairs(radar) do
	-- 	if 
	-- end
	if next(problems) then
		Echo('problems:',table.size(problems))
	end
	-- if math.round(os.clock()*10)%30 == 0 then
	-- 	Echo('count in Infos on icons',count)
	-- end
	glColor(white)
end


local lastView
function widget:DrawScreen()
	local thisFrame = spGetGameFrame()
	lastFrame = thisFrame
	if globalList then
		if lastView ~= NewView[5] then -- 50% faster
			glDeleteList(globalList)
			globalList = glCreateList(GlobalDraw)
		end
		glCallList(globalList)		
	else
		GlobalDraw()
	end
	lastView = NewView[5]
	-- local isSpectating = spGetSpectatingState()
end

function widget:ViewResize(vsx, vsy)
	-- vsx,vsy = vsx + 500, vsy + 500
	-- scale = (vsx*vsy) / normalScale
	-- Echo("scale is ", scale)
end

function WidgetRemoveNotify(w,name,preloading)
	if preloading then
		return
	end
	if name == 'HasViewChanged' then
		widgetHandler:Sleep(widget)
	end
end
function WidgetInitNotify(w,name,preloading)
	if preloading then
		return
	end

	if name == 'HasViewChanged' then
		-- Units = WG.UnitsIDCard
		widgetHandler:Wake(widget)
	end
end

function widget:Initialize()
	NewView = WG.NewView
	Visibles = WG.Visibles and WG.Visibles.anyMap
	VisibleIcons = WG.Visibles and WG.Visibles.iconsMap
	Cam = WG.Cam
	InSight = Cam.InSight
	disarmUnits = WG.disarmUnits or {}
	if not Cam then
		Echo(widget:GetInfo().name .. " requires HasViewChanged.")
		widgetHandler:RemoveWidget(widget)
		return
	end

	if WG.UnitsIDCard then
		Units = WG.UnitsIDCard
		Echo(widget:GetInfo().name .. ' use UnitsIDCard.')
	elseif Cam and Cam.Units then
		Units = Cam.Units
		Echo(widget:GetInfo().name .. ' use Cam.Units.')
	end

	widget:ViewResize(Spring.GetViewGeometry())
	-- local font = gl.LoadFont("FreeSansBold.otf", 12, 3, 3)
	if WG.MyFont then
		fontHandler = WG.MyFont -- it's a copy of mod_font.lua as widget, a parallel fontHandler that  doesn't reset the cache over time since there's no update
		useList = true -- list work with own fontHandler (2 times faster) then 50% even faster using global list if view don't change move
	end
	UseFont = fontHandler.UseFont
	UseFont(monobold)
	TextDrawCentered = fontHandler.DrawCentered
	if useList and glCallList then

		globalList = glCreateList(GlobalDraw)

		for color,t in pairs(lists) do
			-- t[strSel] = glCreateList(
			-- 	function()
			-- 		glColor(color)
			-- 		TextDrawCentered(strSel, 0, 0)
			-- 	end
			-- )
			-- t[strHealth] = glCreateList(
			-- 	function()
			-- 		glColor(color)
			-- 		TextDrawCentered(strHealth, 0, 0)
			-- 	end
			-- )
			t[strSel] = WG.MyFont.GetListCentered(strSel)
			t[strHealth] = WG.MyFont.GetListCentered(strHealth)
		end
	end
end
function widget:Shutdown()
	if globalList then
		glDeleteList(globalList)
	end
  	for color, t in pairs(lists) do
		for str, list in pairs(t) do
	  		glDeleteList(list)
		end
  	end

end

if debugging then
	f.DebugWidget(widget)
end
