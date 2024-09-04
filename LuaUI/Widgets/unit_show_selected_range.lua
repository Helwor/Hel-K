-- mod version externalize the function to  draw units range WG.DrawUnitTypeRanges
function widget:GetInfo() return {
	name    = "Show selected unit range",
	author  = "very_bad_soldier / versus666",
	date    = "October 21, 2007 / September 08, 2010",
	license = "GNU GPL v2",
	layer   = 0,
	enabled = true,
} end


local Echo = Spring.Echo

local spGetSelUnitsSorted		= Spring.GetSelectedUnitsSorted
local spGetUnitViewPosition		= Spring.GetUnitViewPosition
local spGetUnitRulesParam   	= Spring.GetUnitRulesParam
local spGetUnitWeaponState  	= Spring.GetUnitWeaponState
local spIsGUIHidden 			= Spring.IsGUIHidden
local spGetSelectedUnitsCount 	= Spring.GetSelectedUnitsCount

local glColor            = gl.Color
local glLineWidth        = gl.LineWidth
local glDrawGroundCircle = gl.DrawGroundCircle


local optMaxSelection = 20
local EMPTY_TABLE = {}
local USE_BALLISTIC = true

options_path = 'Settings/Interface/Defence and Cloak Ranges'
options = {
	showselectedunitrange = {
		name = 'Show selected unit(s) range(s)',
		type = 'bool',
		value = false,
		OnChange = function (self)
			if self.value then
				widgetHandler:UpdateCallIn("DrawWorldPreUnit")
				widgetHandler:UpdateCallIn("CommandsChanged")
				widget:CommandsChanged()
			else
				widgetHandler:RemoveCallIn("DrawWorldPreUnit")
				widgetHandler:RemoveCallIn("CommandsChanged")
			end
		end,
	},
}
local helk_path = 'Hel-K/' .. widget:GetInfo().name
options.maxSelection = {
	type = 'number',
	name = 'Max Selection',
	min = 0, max = 301, step = 1,
	value = optMaxSelection,
	update_on_the_fly = true,
	tooltipFunction = function(self)
		if self.value == 301 then
			return 'unlimited'
		else
			return tostring(self.value)
		end
	end,
	OnChange = function(self)
		if self.value == 301 then
			optMaxSelection = math.huge
		else	
			optMaxSelection = self.value
		end
	end,
	path = helk_path,
}


local commDefIDs = WG.commDefIDs or {}
WG.commDefIDs = WG.commDefIDs or (function()
	for unitDefID, unitDef in pairs(UnitDefs) do
		if unitDef.customParams.dynamic_comm then
			commDefIDs[unitDefID] = true
		end
	end
	return commDefIDs
end)()
WG.weapRanges = false
local weapRanges = WG.weapRanges or {}
WG.weapRanges = WG.weapRanges or (function()
	local WeaponDefs = WeaponDefs
	local spuGetMoveType = Spring.Utilities.getMovetype
	for unitDefID, unitDef in pairs(UnitDefs) do

		local weapons = unitDef.weapons
		if weapons[1] then
			local t = {}
			local entryIndex = 0
			t.static = not spuGetMoveType(unitDef)
			for weaponIndex = 1, #weapons do
				local weaponDef = WeaponDefs[weapons[weaponIndex].weaponDef]
				local weaponRange = tonumber(weaponDef.customParams.combatrange) or weaponDef.range
				if (weaponRange > 32) then -- 32 and under are fake weapons
					entryIndex = entryIndex + 1
					t['weaponNum' .. entryIndex] = weaponIndex
					t[entryIndex] = weaponRange
					t['weaponDef' .. entryIndex] = weaponDef
				end
			end
			weapRanges[unitDefID] = t
		end
	end
	return weapRanges
end)()

local function DrawRangeCircle(ux,uy,uz,range,r, color)
	local strength = (1 - r/5)
	if color then
		glColor(color[1] * strength, color[2] * strength, color[3] - strength, color[4] or 0.35)
	else
		glColor(1.0 - (r / 5), 0, 0, 0.35)
	end
	glDrawGroundCircle(ux, uy, uz, range, 40)
end




local knownUnits = setmetatable({},{__mode = 'v'})
local reused = 0

local function DrawComRanges(unitDefID, unitIDs, color, isEnemy)
	for i = 1, #unitIDs do
		local unitID = unitIDs[i]
		local ux, uy, uz = spGetUnitViewPosition(unitID)
		if ux then
			local known = knownUnits[unitID]
			if known then
				weapRange1, weapRange2 = known[1], known[2]
				reused = reused + 1
				if weapRange1 then
					DrawRangeCircle(ux,uy,uz,weapRange1,1)
				end
				if weapRange2 then
					DrawRangeCircle(ux,uy,uz,weapRange2,2)
				end
			else
				known = {}
				local weap1 = spGetUnitRulesParam(unitID, "comm_weapon_num_1")
				if weap1 then
					local weapRange = weapRanges[unitDefID][weap1]
					local weapRange2 =  spGetUnitWeaponState(unitID,weap1,"range")
					if weapRange and weapRange2 and weapRange ~= weapRange2 then
						Echo('Weapon State range is not static !',weapRange, weapRange2, math.round(os.clock()))
					end
					if weapRange then
						DrawRangeCircle(ux,uy,uz,weapRange,1, color)
						known[1] = weapRange
					end
				end

				local weap2 = spGetUnitRulesParam(unitID, "comm_weapon_num_2")
				if weap2 then
					local weapRange = weapRanges[unitDefID][weap2]
					-- local weapRange2 = spGetUnitWeaponState(unitID,weap2,"range")
					if weapRange then
						DrawRangeCircle(ux,uy,uz,weapRange,2, color)
						known[2] = weapRange
					end
				end
				knownUnits[unitID] = known
			end
		end
	end
end
local function DrawUnitsRanges(uDefID, uIDs, color)
	local uWepRanges = weapRanges[uDefID]
	if uWepRanges then
		for i = 1, #uIDs do
			local ux, uy, uz = spGetUnitViewPosition(uIDs[i])
			if ux then
				for r = 1, #uWepRanges do
					DrawRangeCircle(ux,uy,uz,uWepRanges[r],r, color)
				end
			end
		end
	end
end
local function DrawUnitTypeRanges(uDefID, uIDs, color, width, isEnemy)
	if width then
		glLineWidth(width)
	end
	if commDefIDs[uDefID] then -- Dynamic comm have different ranges and different weapons activated
		DrawComRanges(uDefID, uIDs, color, isEnemy)
	else
		DrawUnitsRanges(uDefID, uIDs, color)
	end
	if width then
		glLineWidth(1)
	end
end

-- local to = 0
-- function widget:Update(dt)
-- 	to = to + dt
-- 	if to >= 100 then
-- 		Echo('reused', reused,'size of known',table.size(knownUnits))
-- 		to = 0
-- 	end
-- end


local selUnits

function widget:CommandsChanged()
	if spGetSelectedUnitsCount() <= optMaxSelection then
		selUnits = spGetSelUnitsSorted()
	else
		selUnits = EMPTY_TABLE
	end
end

function widget:DrawWorldPreUnit()
	if spIsGUIHidden() then
		return
	end

	glLineWidth(1.5)

	for uDefID, uIDs in pairs(selUnits) do
		DrawUnitTypeRanges(uDefID, uIDs)
	end

	glColor(1, 1, 1, 1)
	glLineWidth(1.0)
end

function widget:Initialize()
	widgetHandler:RemoveCallIn("DrawWorldPreUnit")
	widgetHandler:RemoveCallIn("CommandsChanged")
	WG.DrawUnitTypeRanges = DrawUnitTypeRanges
end

function widget:Shutdown()
	WG.DrawUnitTypeRanges = nil
end