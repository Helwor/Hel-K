--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function widget:GetInfo()
	return {
		name      = "Sun and Atmosphere Handler",
		desc      = "Overrides sun and atmosphere for maps with poor settings",
		author    = "GoogleFrog",
		date      = "June 8, 2016",
		license   = "GNU GPL, v2 or later",
		layer     = 100000000,
		enabled   = true --  loaded by default?
	}
end
local Echo = Spring.Echo
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local spSetSunLighting = Spring.SetSunLighting

local sunPath   = 'Settings/Graphics/Sun, Fog & Water/Sun'
local fogPath   = 'Settings/Graphics/Sun, Fog & Water/Fog'
local waterpath = 'Settings/Graphics/Sun, Fog & Water/Water'

local OVERRIDE_DIR    = LUAUI_DIRNAME .. 'Configs/MapSettingsOverride/'
local MAP_FILE        = (Game.mapName or "") .. ".lua"
local MAPSIDE_FILE = "mapconfig/extraMapSettings.lua"

local OVERRIDE_FILE   = OVERRIDE_DIR .. MAP_FILE
local OVERRIDE_CONFIG = VFS.FileExists(OVERRIDE_FILE) and VFS.Include(OVERRIDE_FILE) or false
if not OVERRIDE_CONFIG then
	OVERRIDE_CONFIG = VFS.FileExists(MAPSIDE_FILE) and VFS.Include(MAPSIDE_FILE) or false
end

local SunSettingsList = {}
local zenithtingsGetSunMap = {}

local defaultFog = {
	["fogStart"] = 0.99,
	["fogEnd"] = 1,
}

local initialized              = false
local zenithtingsChanged       = false
local directionSettingsChanged = false
local fogSettingsChanged       = false
local waterSettingsChanged     = false

local skip = {
	["enable_fog"] = true,
	["save_map_settings"] = true,
	["load_map_settings"] = true,
}

local defaultWaterFixParams = {
	["ambientFactor"] = 0.8,
	["blurExponent"]= 1.8,
	["diffuseFactor"]= 1.15,
	["fresnelMin"]= 0.07,
	["surfaceAlpha"] = 0.32,
}

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- Settings Updates

local function ResetWater()
	Spring.SendCommands("water 4")
end

local sunDir = 0
local sunPitch = math.pi*0.8

local function SunDirectionFunc(newDir, newPitch)
	directionSettingsChanged = true
	sunDir = newDir or sunDir
	sunPitch = newPitch or sunPitch
	
	local sunX = math.cos(sunPitch)*math.cos(sunDir)
	local sunY = math.sin(sunPitch)
	local sunZ = math.cos(sunPitch)*math.sin(sunDir)
	
	Spring.SetSunDirection(sunX, sunY, sunZ)
end

local function GetSunDirection()
	local sx, sy, sz = gl.GetSun("pos")
	local dir = Spring.Utilities.Vector.Angle(sx, sz)
	
	-- Idk if GetSun is guranteed to return a unit
	local norm = Spring.Utilities.Vector.Dist3D(sx, sy, sz, 0, 0, 0)
	sx, sy, sz = sx/norm, sy/norm, sz/norm
	local pitch = math.asin(sy) or 1
	--Spring.Echo("SunVec", sx, sy, sz, pitch, dir)
	return pitch, dir
end

local function FullSunUpdate()
	local sunData = {}
	for i = 1, #SunSettingsList do
		local name = SunSettingsList[i]
		sunData[name] = options[name].value
	end
	spSetSunLighting(sunData)
end

local function UpdateSunValue(name, value)
	spSetSunLighting({[name] = value}) -- For specularExponent, which isn't in SunSettingsList
	FullSunUpdate()
	zenithtingsChanged = true
end

local function UpdateFogValue(name, value)
	Spring.SetAtmosphere({[name] = value})
	fogSettingsChanged = true
end

local function UpdateWaterValue(name, value)
	Spring.SetWaterParams({[name] = value})
	ResetWater()
	waterSettingsChanged = true
end

local function GetSunMapSetting(thing, colType)
	if colType == "shadowDensity" then
		if thing == "unit" then
			return gl.GetSun(colType, thing)
		end
		return gl.GetSun(colType)
	end
	if thing == "unit" then
		local r, g, b = gl.GetSun(colType, thing)
		return {r, g, b, 1}
	end
	local r, g, b = gl.GetSun(colType)
	return {r, g, b, 1}
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local function GetOptionsTable(pathMatch, filter, whitelistFilter)
	-- Filter is either a blacklist of a whitelist
	local retTable = {}
	for i = 1, #options_order do
		local name = options_order[i]
		if (not skip[name]) and ((not filter) or (whitelistFilter and filter[name]) or ((not whitelistFilter) and (not filter[name]))) then
			local option = options[name]
			if option.path == pathMatch then
				retTable[name] = option.value
			end
		end
	end
	return retTable
end

local function SaveSettings()
	local writeTable = {
		sun         = zenithtingsChanged       and GetOptionsTable(sunPath, {sunDir = true, sunPitch = true}, false),
		direction   = directionSettingsChanged and GetOptionsTable(sunPath, {sunDir = true, sunPitch = true}, true),
		fog         = fogSettingsChanged       and GetOptionsTable(fogPath),
		water       = waterSettingsChanged     and GetOptionsTable(waterpath),
	}
	if OVERRIDE_CONFIG.forceIsland ~= nil then
		writeTable.forceIsland = OVERRIDE_CONFIG.forceIsland
	end
	
	WG.SaveTable(writeTable, OVERRIDE_DIR, MAP_FILE, nil, {concise = true, prefixReturn = true, endOfFile = true})
end

local function ApplyDefaultWaterFix()
	Spring.SetWaterParams(defaultWaterFixParams)
	ResetWater()
end

local function SaveDefaultWaterFix()
	local writeTable = {
		fixDefaultWater = true,
		sun       = zenithtingsChanged       and GetOptionsTable(sunPath, {sunDir = true, sunPitch = true}, false),
		direction = directionSettingsChanged and GetOptionsTable(sunPath, {sunDir = true, sunPitch = true}, true),
		fog       = fogSettingsChanged       and GetOptionsTable(fogPath),
	}
	
	WG.SaveTable(writeTable, OVERRIDE_DIR, MAP_FILE, nil, {concise = true, prefixReturn = true, endOfFile = true})
end

local function ReadSunFromMap(sunConf, dirConf)
	for i = 1, #SunSettingsList do
		local name = SunSettingsList[i]
		if not sunConf[name] then
			options[name].value = GetSunMapSetting(zenithtingsGetSunMap[name][1], zenithtingsGetSunMap[name][2])
		end
	end
	
	local pitch, dir = GetSunDirection()
	if not dirConf["sunPitch"] then
		options["sunPitch"].value = pitch
	end
	if not dirConf["sunDir"] then
		options["sunDir"].value = dir
	end
end

local function LoadSunAndFogSettings()
	local override = OVERRIDE_CONFIG or {}
	local sun = override.sun
	if sun then
		spSetSunLighting(sun)
		zenithtingsChanged = true
		
		for name, value in pairs(sun) do
			if options[name] then
				options[name].value = value
			end
		end
	end
	
	local direction = override.direction
	if direction then
		SunDirectionFunc(direction.sunDir, direction.sunPitch)
		
		options["sunDir"].value = direction.sunDir
		options["sunPitch"].value = direction.sunPitch
	end
	ReadSunFromMap(sun or {}, direction or {})
	
	local fog = override.fog or defaultFog
	if fog then
		Spring.SetAtmosphere(fog)
		fogSettingsChanged = true
		
		for name, value in pairs(fog) do
			if options[name] then
				options[name].value = value
			end
		end
	end

	local water = override.water
	if water then
		Spring.SetWaterParams(water)
		waterSettingsChanged = true
		ResetWater()
	end
	
	if override.fixDefaultWater then
		ApplyDefaultWaterFix()
	end
end

local function LoadMinimapSettings()
	if (not OVERRIDE_CONFIG) or (not OVERRIDE_CONFIG.minimap) then
		return
	end
	local minimap = OVERRIDE_CONFIG.minimap
	Spring.Echo("Setting minimap brightness")
	spSetSunLighting(minimap)
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local waterColorDefaults = {
	{name = "absorb",        val = {0, 0, 0, 1}},
	{name = "baseColor",     val = {0, 0, 0, 1}},
	{name = "minColor",      val = {0, 0, 0, 1}},
	{name = "planeColor",    val = {0, 0.4, 0, 1}},
	{name = "surfaceColor",  val = {0.75, 0.8, 0.85, 1}},
	{name = "diffuseColor",  val = {1, 1, 1, 1}},
	{name = "specularColor", val = { 0.8, 0.8, 0.8, 1}},
}
local waterNumberDefaults = {
	{name = "ambientFactor", val = 1.0, minVal = 0, maxVal = 3},
	{name = "diffuseFactor", val = 1.0, minVal = 0, maxVal = 3},
	{name = "specularFactor", val = 1.0, minVal = 0, maxVal = 3},
	{name = "specularPower", val = 20.0, minVal = 0, maxVal = 50},

	{name = "surfaceAlpha", val = 0.5, minVal = 0, maxVal = 1},

	{name = "fresnelMin", val = 0.2, minVal = 0, maxVal = 3},
	{name = "fresnelMax", val = 0.8, minVal = 0, maxVal = 3},
	{name = "fresnelPower", val = 4.0, minVal = 0, maxVal = 10},

	{name = "reflectionDistortion", val = 1.0, minVal = 0, maxVal = 3},

	{name = "blurBase", val = 2.0, minVal = 0, maxVal = 10},
	{name = "blurExponent", val = 1.5, minVal = 0, maxVal = 10},

	{name = "perlinStartFreq", val = 8.0, minVal = 0, maxVal = 50},
	{name = "perlinLacunarity", val = 3.0, minVal = 0, maxVal = 10},
	{name = "perlinAmplitude", val = 0.9, minVal = 0, maxVal = 10},

	{name = "repeatX", val = 0.0, minVal = 0, maxVal = 50},
	{name = "repeatY", val = 0.0, minVal = 0, maxVal = 50},
}

local function GetOptions()
	local options = {}
	local options_order = {}
	
	local function AddOption(name, option)
		options[name] = option
		options_order[#options_order + 1] = name
	end
	
	local function AddColorOption(name, humanName, path, ApplyFunc, defaultVal)
		options[name] = {
			name = humanName,
			type = 'colors',
			value = defaultVal or {0.8, 0.8, 0.8, 1},
			OnChange = function (self)
				if initialized then
					Spring.Utilities.TableEcho(self.value, name)
					ApplyFunc(name, self.value)
				end
			end,
			advanced = true,
			developmentOnly = true,
			path = path
		}
		options_order[#options_order + 1] = name
	end
	
	local function AddNumberOption(name, humanName, path, ApplyFunc, defaultVal, minVal, maxVal)
		options[name] = {
			name = humanName,
			type = 'number',
			value = defaultVal or 0,
			min = minVal or -5, max = maxVal or 5, step = 0.01,
			OnChange = function (self)
				if initialized then
					ApplyFunc(name, self.value)
				end
			end,
			advanced = true,
			developmentOnly = true,
			path = path
		}
		options_order[#options_order + 1] = name
	end
	
	local function AddSunNumberOption(name, humanName, readFromMap, minVal, maxVal)
		local currentSetting = GetSunMapSetting(readFromMap[1], readFromMap[2])
		SunSettingsList[#SunSettingsList + 1] = name
		zenithtingsGetSunMap[name] = readFromMap
		AddNumberOption(name, humanName, sunPath, UpdateSunValue, currentSetting, minVal, maxVal)
	end

---------------------------------------
-- Sun
---------------------------------------
	local sunThings = {"ground", "unit"}
	local sunColors = {"Ambient", "Diffuse", "Specular"}
	local sunColorsLower = {"ambient", "diffuse", "specular"}
	for _, thing in ipairs(sunThings) do
		for i, color in ipairs(sunColors) do
			local name = thing .. color .. "Color"
			local currentColor = GetSunMapSetting(thing, sunColorsLower[i])
			SunSettingsList[#SunSettingsList + 1] = name
			zenithtingsGetSunMap[name] = {thing, sunColorsLower[i]}
			AddColorOption(name, thing .. " " .. color .. " Color", sunPath, UpdateSunValue, currentColor)
		end
	end
	
	AddSunNumberOption("groundShadowDensity", "Shadow Density when cast on ground", {"ground", "shadowDensity"}, 0, 2)
	AddSunNumberOption("modelShadowDensity", "Shadow Density when cast on units", {"unit", "shadowDensity"}, 0, 2)

	options["sunDir"] = {
		name = "Sun Direction",
		type = 'number',
		value = sunDir,
		min = 0, max = 2*math.pi, step = 0.01,
		update_on_the_fly = true,
		OnChange = function (self)
			if initialized then
				SunDirectionFunc(self.value, false)
				FullSunUpdate()
			end
		end,
		advanced = true,
		developmentOnly = true,
		path = sunPath
	}
	options_order[#options_order + 1] = "sunDir"
	
	options["sunPitch"] = {
		name = "Sun Pitch",
		type = 'number',
		value = sunPitch,
		min = 0.05*math.pi, max = 0.5*math.pi, step = 0.01,
		update_on_the_fly = true,
		OnChange = function (self)
			if initialized then
				SunDirectionFunc(false, self.value)
				FullSunUpdate()
			end
		end,
		advanced = true,
		developmentOnly = true,
		path = sunPath
	}
	options_order[#options_order + 1] = "sunPitch"

	-- I don't know how to read this from maps so it isn't in SunSettingsList.
	AddNumberOption("specularExponent", "Specular Exponent", sunPath, UpdateSunValue, 30, 0, 50)
	
---------------------------------------
-- Fog
---------------------------------------
	local fogThings = {"sun", "sky", "cloud", "fog"}
	for _, thing in ipairs(fogThings) do
		AddColorOption(thing .. "Color", thing .. " Color", fogPath, UpdateFogValue)
	end
	AddNumberOption("fogStart", "Fog Start", fogPath, UpdateFogValue, 0, -1, 1)
	AddNumberOption("fogEnd", "Fog End", fogPath, UpdateFogValue, -1, -1, 1)

---------------------------------------
-- Water
---------------------------------------
	for i = 1, #waterNumberDefaults do
		local data = waterNumberDefaults[i]
		AddNumberOption(data.name, data.name, waterpath, UpdateWaterValue, data.val, data.minVal, data.maxVal)
	end
	for i = 1, #waterColorDefaults do
		local data = waterColorDefaults[i]
		AddColorOption(data.name, data.name, waterpath, UpdateWaterValue, data.val)
	end

---------------------------------------
-- Save/Load
---------------------------------------
	AddOption("save_map_settings", {
		name = 'Save Settings',
		type = 'button',
		desc = "Save settings to infolog.",
		OnChange = SaveSettings,
		advanced = true
	})
	AddOption("load_map_settings", {
		name = 'Load Settings',
		type = 'button',
		desc = "Load the settings, if the map has a config.",
		OnChange = LoadSunAndFogSettings,
		advanced = true
	})
	AddOption("save_water_fix", {
		name = 'Save Water Fix',
		type = 'button',
		desc = "Save settings to infolog, overriding water with a minimal fix for default water.",
		OnChange = SaveDefaultWaterFix,
		advanced = true
	})
	AddOption("apply_water_fix", {
		name = 'Apply Water Fix',
		type = 'button',
		desc = "Test the minimal fix for default water.",
		OnChange = ApplyDefaultWaterFix,
		advanced = true
	})
	return options, options_order
end

options_path = 'Settings/Graphics/Sun, Fog & Water'
options, options_order = GetOptions()

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function WG.GetIslandOverride()
	if OVERRIDE_CONFIG and OVERRIDE_CONFIG.forceIsland ~= nil then
		return true, OVERRIDE_CONFIG.forceIsland
	end
	return false
end

local SunCourse = {}
local PI = math.pi
local HALFPI = PI/2

options["course"] = {
	name = "Sun Course",
	type = 'bool',
	value = false,
	OnChange = function(self)
		SunCourse:Stop(not self.value)
	end,
	path = sunPath .. '/Course',
}
options_order[#options_order + 1] = "course"

options["debugColor"] = {
	name = "Color debug",
	type = 'bool',
	value = false,
	OnChange = function(self)
		SunCourse.debugColor = self.value
	end,
	path = sunPath .. '/Course',
}
options_order[#options_order + 1] = "debugColor"


options["useGameTime"] = {
	name = "Use Game Time",
	desc = 'Accord the course to the game time instead of the real time passed.',
	type = 'bool',
	value = true,
	OnChange = function(self)
		SunCourse.useGameTime = self.value
	end,
	path = sunPath .. '/Course',
}
options_order[#options_order + 1] = "useGameTime"


options["coursePause"] = {
	name = "Pause",
	type = 'bool',
	value = false,
	OnChange = function(self)
		SunCourse.paused = self.value or options.pauseOnPause.value and select(3,Spring.GetGameSpeed()) 
	end,
	path = sunPath .. '/Course',
}
options_order[#options_order + 1] = "coursePause"



options["wholeTime"] = {
	name = "Course Time",
	type = 'number',
	desc = 'in minutes',
	value = 60,
	step = 0.5,
	min = 0.5,
	max = 300,
	OnChange = function(self)
		SunCourse.wholeTime = self.value * 60
		SunCourse.updateTime = self.value / 900
	end,
	path = sunPath .. '/Course',
}
options_order[#options_order + 1] = "wholeTime"

options["startAt"] = {
	name = "Start At",
	type = 'number',
	desc = 'Start the first course At',
	value = 35,
	step = 1,
	min = 0,
	max = 100,
	OnChange = function(self)
		SunCourse.StartAt = self.value / 100
	end,
	path = sunPath .. '/Course',
}
options_order[#options_order + 1] = "startAt"


options["courseStart"] = {
	name = "Course Start",
	desc = "a difference of 2 (or multiple of 2) between Course Start and Course End will produce a continuous circling",
	type = 'number',
	value = 0,
	min = -2,
	max = 0.45,
	step = 0.05,
	OnChange = function(self)
		SunCourse.min = SunCourse.start + options.courseStart.value * PI
		-- SunCourse:Reset()
	end,
	path = sunPath .. '/Course',
}
options_order[#options_order + 1] = "courseStart"

options["courseEnd"] = {
	name = "Course End",
	type = 'number',
	value = 1,
	min = 0,
	max = 3,
	step = 0.05,
	OnChange = function(self)
		SunCourse.max = SunCourse.start + options.courseEnd.value * PI
		-- SunCourse:Reset()
	end,
	path = sunPath .. '/Course',
}
options_order[#options_order + 1] = "courseEnd"


for k,v in pairs(Spring) do
	if k:find('Sun') then
		Echo(k,v)
	end
end

options["pitchStart"] = {
	name = "Sun Set",
	type = 'number',
	desc = 'Toward 0 will allow the Sun to be at lowest.',
	value = 0,
	min = 0,
	max = 0.85,
	step = 0.05,
	OnChange = function(self)
		SunCourse.minPitch = self.value * HALFPI
		-- SunCourse:Reset()
	end,
	path = sunPath .. '/Course',
}
options_order[#options_order + 1] = "pitchStart"

options["pitchEnd"] = {
	name = "Zenith",
	desc = 'Toward 1 will allow a totally vertical sun.',
	type = 'number',
	value = 1,
	min = 0.15,
	max = 5,
	step = 0.05,
	OnChange = function(self)
		SunCourse.maxPitch = self.value * HALFPI
		SunCourse.zenith = self.value * HALFPI
		-- SunCourse:Reset()
	end,
	path = sunPath .. '/Course',
}
options_order[#options_order + 1] = "pitchEnd"


options["nightPart"] = { -- should not be used, now should implement proper night with moon
	hidden = true,
	name = "Night Time",
	desc = " by % of the whole course time",
	type = 'number',
	value = 0.1,
	min = 0,
	max = 0.5,
	step = 0.005,
	OnChange = function(self)
		SunCourse.nightPart = self.value
		-- SunCourse:Reset()
	end,
	path = sunPath .. '/Course',
}
options_order[#options_order + 1] = "nightPart"

options["baseDir"] = {
	name = "Direction",
	type = 'number',
	value = 0,
	min = 0,
	max = 360,
	step = 1,
	update_on_the_fly = true,
	OnChange = function(self)
		SunCourse.baseDir = self.value / 360 * PI * 2
		-- SunCourse:Reset()
	end,
	path = sunPath .. '/Course',
}
options_order[#options_order + 1] = "baseDir"

options["defineDay"] = {
	name = "Define Day",
	desc = "How much % of the course is defined as day time ?",
	type = 'number',
	value = 50,
	min = 0,
	max = 100,
	step = 1,
	tooltipFunction = function(self)
		return self.value ..'%'
	end,
	update_on_the_fly = true,
	OnChange = function(self)
		SunCourse.defineDay = self.value / 100
		-- SunCourse:Reset()
	end,
	path = sunPath .. '/Course',
}
options_order[#options_order + 1] = "defineDay"

options["dayNight"] = {
	name = "Day / Night",
	desc = "Pull the Sun course toward day time or toward night time, day time % is defined above."
		.."\nConsider day time where Sun is the highest, if Zenith has been set very low, it will still count as day time here.",
	type = 'number',
	value = 50,
	min = 0,
	max = 100,
	step = 1,
	tooltipFunction = function(self)
		return self.value ..'%'
	end,
	update_on_the_fly = true,
	OnChange = function(self)
		SunCourse.dayNight = self.value / 100
		-- SunCourse:Reset()
	end,
	path = sunPath .. '/Course',
}
options_order[#options_order + 1] = "dayNight"


options["dilate"] = {
	name = "Dilate time",
	type = 'bool',
	value = false,
	OnChange = function(self)
		SunCourse.dilate = self.value
	end,
	path = sunPath .. '/Course',
}
options_order[#options_order + 1] = "dilate"


options["dilateAt"] = {
	name = "Dilate at [MidNight . <= . => . MidDay]",
	type = 'number',
	value = 50,
	min = 0,
	max = 100,
	step = 1,
	tooltipFunction = function(self)
		return self.value ..'%'
	end,
	update_on_the_fly = true,
	OnChange = function(self)
		SunCourse.dilateAt = 1 - self.value / 100
		-- SunCourse:Reset()
	end,
	path = sunPath .. '/Course',
}
options_order[#options_order + 1] = "dilateAt"

options["tellDay"] = {
	name = "Tell Day Progression",
	type = 'bool',
	value = false,
	OnChange = function(self)
		SunCourse.tellDay = self.value
		-- SunCourse:Reset()
	end,
	path = sunPath .. '/Course',
}
options_order[#options_order + 1] = "tellDay"



function widget:GamePaused(_, paused)
	if paused then
		if options.pauseOnPause.value then
			SunCourse.paused = true
		end
	elseif not options.coursePause.value then
		SunCourse.paused = false
	end
end
options["pauseOnPause"] = {
	name = "Pause on Game Pause",
	type = 'bool',
	value = true,
	OnChange = function(self)
		SunCourse.paused = select(3,Spring.GetGameSpeed()) and self.value or options.coursePause.value
	end,
	path = sunPath .. '/Course',
}
options_order[#options_order + 1] = "pauseOnPause"


local function GetPlayerFacingSouth()
	-- we assume that south is where the sun comes and on the map it is toward lower Z
	-- facing south therefore is spawning at higher Z
	local faceSouth = true
	local teamParams = Spring.GetTeamRulesParams(Spring.GetMyTeamID())
	if teamParams then
		local startpos = teamParams.start_box_id
		if startpos then
			local gameParams = Spring.GetGameRulesParams()
			if gameParams then
				local myStartBoxZ = gameParams['startbox_polygon_z_' .. startpos .. '_1_1']
				if myStartBoxZ then
					faceSouth = myStartBoxZ > Game.mapSizeZ / 2
				end
			end
		end
	end
	return faceSouth
end

options["sunFacing"] = {
	name = "Sun Facing",
	type = 'number',
	value = 0,
	step = 1,
	min = 0,
	max = 2,
	tooltipFunction = function(self)

		return self.value == 0 and 'auto' or self.value == 1 and 'yes' or 'no'
	end,
	OnChange = function(self)
		SunCourse.faceSouth = self.value == 0 and GetPlayerFacingSouth() or self.value == 1
		local start = SunCourse.faceSouth and PI or 0
		
		SunCourse.min = start + options.courseStart.value * PI
		SunCourse.max = start + options.courseEnd.value * PI

	end,
	path = sunPath .. '/Course',
}
options_order[#options_order + 1] = "sunFacing"




function widget:Initialize()
	-- See Mantis https://springrts.com/mantis/view.php?id=5280
	Spring.Echo("SetSunLighting")
	spSetSunLighting({groundSpecularColor = {0, 0, 0, 0}})

	if Spring.GetGameFrame() < 1 then
		LoadMinimapSettings()
	end
end

local function SetSunDir(sunDir, sunPitch)
	sunPitch = sunPitch or options.sunPitch.value
	local sunX = math.cos(sunPitch)*math.cos(sunDir)
	local sunY = math.sin(sunPitch)
	local sunZ = math.cos(sunPitch)*math.sin(sunDir)
	
	Spring.SetSunDirection(sunX, sunY, sunZ)
end


local updates = 0


SunCourse = {
	start = PI,
	min = PI,
	max = PI * 2,
	current = PI,
	faceSouth = true,
	currentPer = 0,
	wholeTime = 360,
	updateTime = 360/900,
	nextTime = 0,
	timePassed = 0,
	time = 0,
	paused = options.coursePause.value,
	stopped = options.course.value,
	zenith = HALFPI,
	minPitch = -0.1 * HALFPI,
	maxPitch = 1.1 * HALFPI,
	nightPart = 0,
	coursePer = 0,
	courseTime = 360,
	pitch = 0,
	night = false,
	baseDir = 0,
	dayNight = 0.5,
	defineDay = 0.5,
	dilate = true,
	dilateAt = 0.5,
	day = 0,
	tellDay = false,
	startAt = 0,
	courseColors = {},
	useGameTime = true,
	debugColor = false,
	Dilate = function(self,loc,current, min, max, soften) -- Dilate is actually putting closer values from loc more closer until reaching the ends min and max
		min, max = min or 0, max or 1
		soften = soften or 0.3 -- mult of the remaining of strength that can be applied (between 0,1), the bigger it is the softer is the Dilatation
		local debug = false
		if current ~= loc then
			local diff = current - loc
			local absdiff = math.abs(diff)
			if diff < 0 then
				local locRem = loc-min
				local strength = absdiff / (locRem) -- need to be configurable to smooth or harden the result
				-- if shrink then strength = 1 + (1 - strength) end
				local soft = (1 - strength ) * soften
				local test = loc + diff * (strength + soft)
				if debug then
					Echo(
						'current:' .. ('%.2f'):format(current)
						,'diff <0',diff
						,'locRem: ' .. ('%.2f'):format(locRem)
						,'strength: ' .. ('%.2f'):format(strength)
						,'delta => ' .. ('%.2f'):format(test-current)
					)
				end
				current = test
			else
				local locRem = max - loc
				local strength = absdiff / (locRem)
				local soft = (1 - strength ) * soften
				-- if shrink then strength = 1 + (1 - strength) end
				local test = loc + diff * (strength + soft)
				if debug then
					Echo(
						'current:' .. ('%.2f'):format(current)
						,'diff >0',diff
						,'locRem: ' .. ('%.2f'):format(locRem)
						,'strength: ' .. ('%.2f'):format(strength)
						,'delta => ' .. ('%.2f'):format(test-current)
					)
				end


				current = test
			end
		end
		return current
	end,
	Increment = function(self,timeDelta, step)
		if self.startAt then
			self.currentPer = self.startAt
			self.startAt = false
		end
		step = step or  1 / (self.wholeTime / timeDelta)
		self.step = step
		self.currentPer = self.currentPer + step
		if self.currentPer>1 then
			self.currentPer = 1
		end
		local nightPart = self.nightPart
		local coursePer = math.max(self.currentPer - nightPart/2, 0) * (1 + nightPart)
		-- Echo('coursePer ',coursePer,'currentPer',self.currentPer)

		if coursePer > 1 then
			coursePer = 1
		end
		if --[[false and--]] self.dilate then
			local loc = 1 - self.dilateAt
			local soften = 0.5
			local loc1, loc2 = loc / 2, 1 - (loc / 2)
			local test
			if coursePer <= 0.5 then
				test = self:Dilate(loc1, coursePer, 0, 0.5, soften)
			else
				test = self:Dilate(loc2, coursePer, 0.5, 1, soften)
			end
			-- Echo(
			-- 	'loc',loc,
			-- 	'coursePer:',math.round( (coursePer) * 100) .. '%',
			-- 	'diff:' .. math.round( (test - coursePer) * 100) .. '%'
			-- )
			coursePer = test

		end
		if false and self.dilate then
			-- no need for math shenaningan, now the function take range
			local loc = 1 - self.dilateAt
			local loc1, loc2 = loc/2, 1-(loc/2)
			if coursePer <= 0.5 then
				local test = self:Dilate(loc1*2, coursePer*2)
				test = test / 2
				-- Echo('gave',loc1*2, coursePer*2,
				-- 	'loc1',loc1,
				-- 	'coursePer:',math.round( (coursePer) * 100) .. '%',
				-- 	'diff:' .. math.round( (test - coursePer) * 100) .. '%')
				coursePer = test
			else
				local test = self:Dilate((loc2-0.5)*2, (coursePer-0.5)*2)
				test = test/2 + 0.5
				-- Echo('gave',(loc2-0.5)*2, (coursePer-0.5)*2,
				-- 	'loc2',loc2,
				-- 	'coursePer:',math.round( (coursePer) * 100) .. '%',
				-- 	'diff:' .. math.round( (test - coursePer) * 100) .. '%')
				coursePer = test
			end
		end
		self.coursePer = coursePer
		local current = self.min + (self.max - self.min) * coursePer
		current = current + self.baseDir
		-- FIX FOR MORE THAN ONE * PI
		local fromMidCourse = math.abs(coursePer - 0.5) * 2  -- percent from mid course, highest pitch


		if false and self.dilate then
		-- this doesnt really dilate time but dilate the pitch time from a given location, see above for real dilatation (no homo)
			local loc = self.dilateAt
			fromMidCourse = self:Dilate(loc,fromMidCourse)

		end

		local dayNight = self.dayNight
		if dayNight > 0.5 then
			-- pull fromMidCourse toward half (at maximum if 100% day) of its value (to approach to the highest point)
			local ratio = dayNight - 0.5
			fromMidCourse = fromMidCourse - (ratio * fromMidCourse)
		else
			-- pull fromMidCourse toward half (at maximum if 0% day) of its remaining value (to approach to the lowest point)
			local ratio = 0.5 - dayNight
			fromMidCourse = fromMidCourse + (1-fromMidCourse) * ratio
		end
		-- Echo("current%HALFPI is ", current%HALFPI)
		-- local pitch = zenithPitch + (0.5 + math.abs(coursePer - 0.5)) * HALFPI -- pitch with switched direction
		local pitch
		if self.maxPitch - self.minPitch > HALFPI then -- going beyond midday
			pitch = coursePer * (self.maxPitch - self.minPitch)
		else
			pitch = self.maxPitch - fromMidCourse * (self.maxPitch - self.minPitch)
		end
		if self.tellDay then
			local tellDay = math.round( (1- fromMidCourse) * 100) .. '%'
			if self.tellDay ~= tellDay then
				self.tellDay = tellDay
				-- Echo("day: " .. self.tellDay,'fromMidCourse:',math.round( (fromMidCourse) * 100) .. '%')
				Echo("day: " .. self.tellDay,'coursePer:',math.round( (coursePer) * 100) .. '%',('pitch: %.2f '):format(pitch/HALFPI))
				-- Echo("day: " .. self.tellDay)
			end
		end
		-- calculate day/night proportion
		-- FIX FOR PITCH MORE THAN ONE * PI
		local fromzenith = math.abs(1 - (pitch / HALFPI)) -- percent from zenith (different than fromMidCourse if maxPitch is <1*HALFPI)

		if pitch == self.pitch and current == self.current then -- night/idling time probably
			if not self.night then
				Echo('entered night/idling part')
				self.night = true
			end
			return
		end
		self.night = false
		self.current, self.pitch = current, pitch
		SetSunDir(current, pitch)
		local per = ('%0.f%%'):format(coursePer*100)
		local rFactor, gFactor, bFactor
		-- there is already an automatic setting when sun pitch go down, so we tweak it to colorize it a bit
		if fromzenith>0.95 then 
			if self.dayTime ~= 'night' then
				Echo('night',per)
				self.dayTime = 'night'
			end
			rFactor = 1/7
			gFactor = 1/100
			bFactor = 1/3
		elseif fromzenith>0.75 then 
			if self.dayTime ~= 'dawn / sunset' then
				Echo('dawn / sunset',per)
				self.dayTime = 'dawn / sunset'
			end

			rFactor = 1/3.5
			gFactor = 1/20
			bFactor = 1/7
		elseif fromzenith > 0.50 then
			if self.dayTime ~= 'sunrise / evening' then
				Echo('sunrise / evening',per)
				self.dayTime = 'sunrise / evening'
			end

			rFactor = 1/5
			gFactor = 1/15
			bFactor = 1/35
		elseif fromzenith>0.20 then
			if self.dayTime ~= 'morning / afternoon' then
				Echo('morning / afternoon',per)
				self.dayTime = 'morning / afternoon'
			end

			rFactor = 1/7
			gFactor = 1/18
			bFactor = 1/75
		else -- zenith
			if self.dayTime ~= 'midday' then
				Echo('midday',per)
				self.dayTime = 'midday'
			end

			rFactor = 1/6
			gFactor = 1/8
			bFactor = 1/100
		end
		local sunData = {}
		local options = options
		for i = 1, #SunSettingsList do
			local name = SunSettingsList[i]
			local value
			if name == 'sunPitch' then
				value = pitch
			elseif name == 'sunDir' then
				value = current
			else
				value = options[name].value
			end
			local thisColor = self.courseColors[name]

			if thisColor then
				local debug = self.debugColor and name:find('ground')

				if name == 'groundDiffuseColor' then
					rFactor, gFactor, bFactor = rFactor/2, gFactor/2, bFactor/2
				end
				thisColor[1], thisColor[2], thisColor[3], thisColor[4] = unpack(options[name].value)
				local green = thisColor[2]
				local capping = 0
				if green > 0.6 and fromzenith < 0.5 then
					capping =  0.4 * ((0.5-fromzenith)/0.5) -- fix the ground getting too bright on vertical sun
				end
				value = thisColor
				-- Echo("coursePer,(coursePer*10)%3 is ", math.round((coursePer*10000)%20)==0)
				local newR, newG, newB = 
					math.min(1, value[1] * (1 + (fromzenith * rFactor) ) ) - capping, -- adding some red when going away from zenith
					math.min(1, value[2] * (1 + (fromzenith * gFactor) ) ) - capping, -- adding some blue when going away from zenith
					math.min(1, value[3] * (1 + (fromzenith * bFactor) ) ) - capping-- adding some blue when going away from zenith
				if debug and math.round((coursePer*100000)%200)==0 then
					Echo('time to debug',name,os.clock())
					Echo('from zenith',fromzenith,'capping',capping, fromzenith)

					Echo(
						-- table.concat({
							'\nRed:', value[1], ' ==> ', newR,
							'\nGreen:', value[2], ' ==> ', newG,
							'\nBlue:', value[3], ' ==> ', newB
						-- })
					)
					if not SunSettingsList[i+1] then
						Echo('-------- end --------')
					end
				end
				value[1] = newR
				value[2] = newG
				value[3] = newB
				
				-- Echo("value[3] is ", value[3])
			end
			sunData[name] = value
		end
		spSetSunLighting(sunData)
	end,
	Stop = function(self, value)
		self.stopped = value
		if value and self.currentPer>0 then
			self:Reset()
		end
	end,
	Pause = function(self)
		self.paused = true
	end,
	Update = function(self, dt)
		if self.paused or self.stopped then
			return
		end
		if self.currentPer == 1 then
			self.timePassed = 0
			self.currentPer = 0
			self.nextTime = 0
			self.time = 0
			-- Echo('cycle ended',math.round(os.clock()))
		end
		self.timePassed = self.timePassed + dt
		if self.timePassed >= self.nextTime then
			self:Increment(self.timePassed - self.time)
			self.nextTime = self.timePassed + 5/self.courseTime--self.updateTime
			self.time = self.timePassed

		end
		if math.round(self.timePassed * 100)%200 == 0 then
			-- Echo('timePassed', self.timePassed, 'currentPer', self.currentPer, 'step:',self.step,'current',self.current)
		end
	end,
	Initialize = function(self,t)
		for i = 1, #SunSettingsList do
			local name = SunSettingsList[i]
			if name:match'Color' and options[name] and type(options[name].value) == 'table' then
				self.courseColors[name] = {unpack(options[name].value)}
			end
		end
		local faceSouth = options.sunFacing.value
		faceSouth = faceSouth == 0 and GetPlayerFacingSouth() or faceSouth == 1
		local start = (faceSouth and PI or 0)

		local steps = 900

		local wholeTime = options.wholeTime.value * 60
		local nightPart = options.nightPart.value
		self.start = start
		self.min = start + options.courseStart.value * PI
		self.max = start + options.courseEnd.value * PI
		self.minPitch = options.pitchStart.value * HALFPI
		self.maxPitch = options.pitchEnd.value * HALFPI
		self.zenith = self.maxPitch
		self.current = self.min
		self.faceSouth = faceSouth
		self.currentPer = 0
		self.wholeTime = wholeTime
		self.updateTime = wholeTime/steps
		self.nextTime = 0
		self.timePassed = 0
		self.time = 0
		self.day = 0
		self.coursePer = 0
		self.nightPart = nightPart
		self.courseTime = wholeTime * (1 - nightPart)
		self.dayNight = options.dayNight.value / 100
		self.defineDay = options.defineDay.value / 100
		self.useGameTime = options.useGameTime.value
		self.pitch = 0
		self.dilate = options.dilate.value
		self.dilateAt = 1 - options.dilateAt.value / 100
		self.tellDay = options.tellDay.value
		self.baseDir = options.baseDir.value / 360 * PI * 2
		self.paused = options.coursePause.value or options.pauseOnPause.value and select(3,Spring.GetGameSpeed()) 
		self.startAt = options.startAt.value / 100
		self.stopped = not options.course.value
		self.debugColor = options.debugColor.value
	end,
	Reset = function(self)
		self.currentPer = 0
		self.timePassed = 0
		self.time = 0
		self.nextTime = 0
		self.current = self.min
		SetSunDir(options.sunDir.value, options.sunPitch.value)
		local sunData = {}
		for _, name in ipairs(SunSettingsList) do
			sunData[name] = options[name].value
		end
		spSetSunLighting(sunData)
	end,
}
function widget:GameFrame(f)
	if initialized and SunCourse.useGameTime then
		SunCourse:Update(0.033)
	end
end
function widget:Update(dt)
	if initialized and not SunCourse.useGameTime then
		SunCourse:Update(dt)
		return
	end
	if not initialized then
		updates = updates + 1
		if updates == 4 or updates == 28 then
			
			LoadSunAndFogSettings()
			if updates == 28 then
				SunCourse:Initialize()
				local f = Spring.GetGameFrame()
				local progress = math.max(f,0) * 0.033
				progress = progress % SunCourse.wholeTime
				Echo( ('starting Sun Course at %.1f %%'):format(progress / SunCourse.wholeTime * 100) ) 
				SunCourse:Update(progress)
				initialized = true
				-- widgetHandler:RemoveCallIn("Update")
			end
		end
	end
end

function widget:Shutdown()
	SunCourse:Reset()
end