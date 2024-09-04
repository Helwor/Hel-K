function widget:GetInfo()
	return {
		name      = "Close Enemy Range",
		desc      = "Displays range of close enemy",
		author    = "Helwor",
		date      = "May 2024",
		license   = "GNU GPL v2",
		layer     = 0,
		enabled   = true
	}
end




local Echo = Spring.Echo
-- Technicalities

local ENEMY_UNITS = Spring.ENEMY_UNITS  -- -4 code for GetUnitsInCylinder


local MAXRANGE = 1200
local MARGIN = 300
-- Config
local IGNORE_COUNT = 50 -- don't do anything when selection is equal or above this many
local USE_CLUSTERIZATION = true
local ALPHA = 0.35
local SHOW_ALL_CLOSE = true -- we cannot use GetNearestEnemy because it may return some harmless unit instead
local USE_BALLISTIC_CALC = true
local RANGE_COLOR = {1,1,0,ALPHA}
local MAX_RANGE = 1500
local MAX_SEL = 10
local MAX_CIRCLES = 6

local DEBUG_TIME = true

local EMPTY_TABLE = {}

local myPlayerID = Spring.GetMyPlayerID()
local myTeamID = Spring.GetMyTeamID()
local spec, specFullRead = Spring.GetSpectatingState()

local lastFrame = -1
local closeEnemies, toDrawNoCalc = {}, {}
local allDists = {}
local sel = EMPTY_TABLE
local cache = setmetatable({}, {__mode = 'k'})

local timeDrawing = 0
local timeDrawingCount = 0
local timeDrawingAverage = 0
local reused = 0


local timeCalc = 0
local timeCalcCount = 0
local timeCalcAverage = 0


local weapRanges = WG.weapRanges or {}
local commDefIDs = WG.commDefIDs or {}
WG.commDefIDs = WG.commDefIDs or (function()
	for unitDefID, unitDef in pairs(UnitDefs) do
		if unitDef.customParams.dynamic_comm then
			commDefIDs[unitDefID] = true
		end
	end
	return commDefIDs
end)()
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




-- local function DefineBaseWeapons()
--     for defID,ud in pairs(UnitDefs) do 
--         if ud.canAttack and not ud.isFactory and ud.name~='staticnuke' then
--             if ud.name=='mahlazer' --[[or ud.name:match('dyn')--]] then -- it takes a lot more time to load if we include the commanders defID (dyn)
--                 -- skipping
--             else
--                 local weapons

--                 local weapNum, weaponDef, weaponRange
--                 local reloadTime,wrange,wtype,wwaterWeapon,cylinderTargetting,name,manualFire = 1000,32
--                 for i = 1, #ud.weapons do 
--                     if ud.name=='shieldriot' then i=3 end
--                     local weapon = ud.weapons[i]
--                     local wdefid = weapon.weaponDef
--                     local wdef   = WeaponDefs[ wdefid ]
--                     --if ud.name=='bomberriot' then Debug(i,'wname',wdef.name,'wdef.range',wdef.range,'wtype',wdef.type,'wdef.reload',wdef.reload,'manual',wdef.manualFire) end -- need to fix vehcapture
--                     --if ud.name=='bomberdisarm' then Debug(i,wdef.name,wdef.manualFire) end

--                     if wdef.canAttackGround and (wdef.range>32 and wdef.range>wrange or ud.name=='bomberriot') and wdef.reload~=0 and not wdef.stockpile then
--                     	if not weaponRange or weaponRange > wdef.range then
-- 	                        reloadTime = wdef.reload
-- 	                        weapNum = i
-- 	                        weaponDef = wdef

-- 	                        wtype=wdef.type
-- 	                        wwaterWeapon = wdef.waterWeapon
-- 	                        wrange = tonumber(wdef.customParams.combatrange) or wdef.range
-- 	                        weaponRange = wrange
-- 	                        cylinderTargetting = wdef.cylinderTargetting
-- 	                        wname = wdef.name
-- 	                        if ud.name=='bomberdisarm' then manualFire=true end
-- 	                        if ud.name=='amphsupport' or ud.name=='hoverdepthcharge' then  break  end -- correct weapon is the first one for those
-- 	                        --if ud.name=='gunshipheavyskirm' then Debug('-***') for k,v in wdef:pairs() do if k:match('cylinder') then Debug(k,v) end end end
-- 	                    end
--                     end
--                     if ud.name=='shieldriot' then break end 
--                 end
--                 --if ud.name=='bomberdisarm' then Debug("weapNum is ", weapNum) end

--                 if weaponDef then
--                     weapRanges[defID] = {
--                     	weaponDef = weaponDef,
--                     	radius = weaponRange,
--                     }
--                 end
--             end

--         end
--     end
-- end
-- DefineBaseWeapons()
----------------------------------------
-- do
-- 	local spuGetMoveType = Spring.Utilities.getMovetype
-- 	for defID, def in pairs(UnitDefs) do
-- 		if true or spuGetMoveType(def) then
-- 			local weaponDef
-- 			-- if def.weapons then
-- 			-- 	local biggest = 0
-- 			-- 	for i,weap in pairs(def.weapons) do
-- 			-- 		local wDef = WeaponDefs[weap.weaponDef]
-- 			-- 		local range = wDef.range
-- 			-- 		if range > biggest then
-- 			-- 			biggest = range
-- 			-- 			weaponDef = wDef
-- 			-- 		end
-- 			-- 	end
-- 			-- end
-- 			local weaponDef = def.weapons and def.weapons[1] and WeaponDefs[def.weapons[1].weaponDef]
-- 			if weaponDef then
-- 				weapRanges[defID] = {
-- 					weaponDef = weaponDef,
-- 					radius = weaponDef.range,
-- 				}
-- 			else
-- 				Echo('no def for',def.name)
-- 			end
-- 		end
-- 	end
-- 	spuGetMoveType = nil
-- end
-- speedups
local gl 	= gl
local GL_LINE_STRIP         	= GL.LINE_STRIP
local glBeginEnd            	= gl.BeginEnd
local glCallList            	= gl.CallList
local glColor               	= gl.Color
local glCreateList          	= gl.CreateList
local glDeleteList          	= gl.DeleteList
local glLineWidth           	= gl.LineWidth
local glVertex              	= gl.Vertex
local spGetPositionLosState 	= Spring.GetPositionLosState
local spGetUnitDefID        	= Spring.GetUnitDefID
local spGetUnitPosition     	= Spring.GetUnitPosition
local spIsGUIHidden 			= Spring.IsGUIHidden
local spGetUnitNearestEnemy 	= Spring.GetUnitNearestEnemy
local spGetGameFrame 			= Spring.GetGameFrame
local spGetSelectedUnits 		= Spring.GetSelectedUnits
local spGetUnitsInCylinder  	= Spring.GetUnitsInCylinder
local spGetMyTeamID				= Spring.GetMyTeamID
local spIsUnitAllied			= spIsUnitAllied
local spGetTimer				= Spring.GetTimer
local spDiffTimers				= Spring.DiffTimers
local spIsUnitAllied 			= Spring.IsUnitAllied
local spGetUnitRulesParam		= Spring.GetUnitRulesParam
local spGetSelectedUnitsCount 	= Spring.GetSelectedUnitsCount
local spGetSpectatingState		= Spring.GetSpectatingState
local spGetGroundHeight			= Spring.GetGroundHeight
local CalcBallisticCircle 		= VFS.Include("LuaUI/Utilities/engine_range_circles.lua")


local floor = math.floor







--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local function CircleVerts(verts)
	for i = 1, #verts do
		glVertex(verts[i])
	end
	glVertex(verts[1])
end

local function clear(t)
	for k in pairs(t) do t[k] = nil end
end
local function ResetTime()
	local timeDrawing = 0
	local timeDrawingCount = 0
	local timeDrawingAverage = 0


	local timeCalc = 0
	local timeCalcCount = 0
	local timeCalcAverage = 0
	to = 0
	reused = 0
end
local dist = function(x1,z1,x2,z2)
	return ( (x1-x2)^2 + (z1-z2)^2 )^0.5
end
local function sortDistance(a,b)
	return a < b
end
local lastPoses = setmetatable({}, {__mode = 'v'})

local function Reset()
	clear(closeEnemies)
	clear(lastPoses)
	toDrawNoCalc = false
	ResetTime()
	lastFrame = - 1
end

--------------------------------------------------------------------------------

options = {}
options_path = 'Hel-K/' .. widget:GetInfo().name


-- options.allClose = { -- we don't let that choice because using GetUnitNearestEnemy can return an harmless unit
-- 	name = 'Show All Close Enemies Range',
-- 	desc = 'Or only the closest of each of your selected unit',
-- 	type = 'bool',
-- 	value = SHOW_ALL_CLOSE,
-- 	OnChange = function(self)
-- 		SHOW_ALL_CLOSE = self.value
-- 		ResetTime()
-- 	end,
-- }
options.maxRange = {
	name = 'Max Range',
	desc = 'How far we look for unit to check',
	type = 'number',
	min = 200, step = 10, max = 4000,
	value = MAX_RANGE,
	update_on_the_fly = true,
	OnChange = function(self)
		MAX_RANGE = self.value
		Reset()
	end,
}

options.margin = {
	name = 'Margin',
	desc = 'How close to reach selected unit we should draw the enemy range',
	type = 'number',
	min = 50, step = 10, max = 300,
	value = MARGIN,
	update_on_the_fly = true,
	OnChange = function(self)
		MARGIN = self.value
		Reset()
	end,
}
options.maxSel = {
	name = 'Maximum Scans',
	desc = 'Beyond how many selected units we stop scanning and evaluating enemies\nWARN This can be very resource heavy',
	type = 'number',
	min = 1, step = 1, max = 101,
	value = MAX_SEL,
	update_on_the_fly = true,
	OnChange = function(self)
		MAX_SEL = self.value
		Reset()
	end,
}

options.maxUnits = {
	name = 'Maximum Range Circles',
	desc = 'WARN This can be very resource heavy especially with using the Ballistic Calculation',
	type = 'number',
	min = 1, step = 1, max = 101,
	value = MAX_CIRCLES,
	update_on_the_fly = true,
	OnChange = function(self)
		MAX_CIRCLES = self.value
		Reset()
	end,
}

options.dontWantStatic = {
	name = "Dont Include static building",
	type = 'bool',
	value = DONT_WANT_STATIC,
	OnChange = function(self)
		DONT_WANT_STATIC = self.value
		Reset()
	end,
}

options.useBallisticCalc = {
	name = 'Use Ballistic Calc',
	type = 'bool',
	desc = 'Allow to get the real engine range but at a cost',
	value = USE_BALLISTIC_CALC,
	OnChange = function(self)
		USE_BALLISTIC_CALC = self.value
		Reset()
	end,
}

options.useClusterization = {
	name = 'Use Clusterization',
	type = 'bool',
	desc = 'Clusterize selection to avoid rescanning units close to each other\nyou must have the mod version of api_cluster_detection.lua',
	value = USE_CLUSTERIZATION,
	OnChange = function(self)
		USE_CLUSTERIZATION = self.value
		Reset()
	end,
}


options.color = {
	name = 'Range Color',
	type = 'colors',
	value = RANGE_COLOR,
	update_on_the_fly = true,
	OnChange = function(self)
		if type(self.value) == 'table' then
			for k,v in pairs(self.value) do
				RANGE_COLOR[k] = v
			end
		end
	end,
}
options.debugTime = {
	name = 'Debug Time',
	type = 'bool',
	value = DEBUG_TIME,
	OnChange = function(self)
		DEBUG_TIME = self.value
		Reset()
	end,
}


function widget:CommandsChanged()
	sel = spGetSelectedUnits()
	lastFrame = - 2
	local knownUnits = next(cache)
	if knownUnits then
		cache[knownUnits] = nil
	end
end

function widget:PlayerChanged(playerID)
	if playerID == myPlayerID then
		spec, specFullRead = spGetSpectatingState()
	end
end


local function SortByDefID(units)
	local defIDs = {}
	for id, obj in pairs(units) do
		if obj and obj.noCalcDraw then
			local defID = obj.defID
			local t = defIDs[defID]
			if not t then
				t = {n = 0}
				defIDs[defID] = t
			end
			t.n = t.n + 1
			t[t.n] = id
		end
	end
	return defIDs
end
local byDistReach = function(a,b)
	return a.distReach < b.distReach
end
local function SortEnemiesByDistReach(enemies)
	local t, n = {}, 0
	for id, obj in pairs(enemies) do
		if obj and obj.distReach then
			n = n + 1
			obj.id = id
			t[n] = obj
		end
	end
	table.sort(t, byDistReach)
	return t
end


local function ProcessEnemiesFromPoint(ux,uz, max_range)
	local hasNewNoCalc
	-- if not SHOW_ALL_CLOSE then -- we can't do that because it may return an harmless unit
	-- 	enemies = {spGetUnitNearestEnemy(id, MAX_RANGE)}
	-- else
		enemies = spGetUnitsInCylinder(ux,uz, max_range, ENEMY_UNITS)
		-- TODO: clusterize the selection so we don't spam GetUnitsInCylinder for nothing
		if spec and specFullRead then -- engine doesnt give enemy list but all when spec full read
			for i, id in pairs(enemies) do
				local state = closeEnemies[id]
				if state then
					enemies[i] = nil
				elseif state == false then
					enemies[i] = nil
				elseif spIsUnitAllied(id) then
					closeEnemies[id] = false
					enemies[i] = nil
				end
			end
		end
	-- end
	if enemies and next(enemies) then
		for _, enemy in pairs(enemies) do
			local thisEnemy = closeEnemies[enemy]
			if thisEnemy ~= false then
				local defID, conf
				if thisEnemy == nil then
					defID = spGetUnitDefID(enemy)
					conf = defID and weapRanges[defID]
					if not conf or conf.static and DONT_WANT_STATIC then
						closeEnemies[enemy], thisEnemy = false, false
					else
						thisEnemy = {defID = defID}
						closeEnemies[enemy] = thisEnemy
					end
				else
					defID = thisEnemy.defID
					conf = weapRanges[defID]
				end
				if thisEnemy then

					local x,y,z
					if not thisEnemy[1] then
						x,y,z = spGetUnitPosition(enemy)
						if x then
							thisEnemy[1], thisEnemy[2], thisEnemy[3] = x,y,z
						else
							closeEnemies[enemy], thisEnemy = false, false
						end
					else
						x,y,z = thisEnemy[1], thisEnemy[2], thisEnemy[3]
					end
					if x then
						local weapNum1, weapNum2 = thisEnemy.weapNum1, thisEnemy.weapNum2
						if weapNum1 == nil then
							if commDefIDs[defID] then
								weapNum1 = spGetUnitRulesParam(enemy, "comm_weapon_num_1")
								weapNum2 = spGetUnitRulesParam(enemy, "comm_weapon_num_2")
								thisEnemy.weapNum1, thisEnemy.weapNum2 = weapNum1, weapNum2
							else
								thisEnemy.weapNum1 = false
							end
						end
						for i=1, #conf do
							local weapNum = conf['weaponNum' .. i]
							if not weapNum1 or weapNum == weapNum1 or weapNum == weapNum2 then
								-- it is not prefect as
									-- 1. we should update the distReach if it is found to be closer from another weapon, but this is already expensive
									-- 2. we should correct the real distReach in case of using the BallisticCalc but this would mean to check for each vertex to find the closest one (very expensive)
								local radius = conf[i]
								local distReach = floor( dist(ux,uz,x,z) - radius   + 0.5)

								if distReach > -MARGIN and distReach < MARGIN then
									local currentDistReach = thisEnemy.distReach
									if not currentDistReach or distReach < currentDistReach then
										thisEnemy.distReach = distReach
										thisEnemy.weaponDef = conf['weaponDef' .. i]
										thisEnemy.radius = radius
									end
									break
								end
							end
						end
					else
						closeEnemies[enemy] = false
					end
				end
			end
		end
		-- final result
		local sorted = SortEnemiesByDistReach(closeEnemies)
		----- some other debugging
		-- local cnt = table.size(closeEnemies)
		-- local cntFalse, cntReach = 0, 0
		-- for k,v in pairs(closeEnemies) do
		-- 	if not v then
		-- 		cntFalse = cntFalse + 1
		-- 	elseif v.distReach then
		-- 		cntReach = cntReach + 1
		-- 	end
		-- end
		-----------------
		for i, thisEnemy in pairs(sorted) do
			if i <= MAX_CIRCLES then
				if USE_BALLISTIC_CALC then
					local enemy = thisEnemy.id
					local lastPos = lastPoses[enemy]
					local x,y,z = thisEnemy[1], thisEnemy[2], thisEnemy[3]
					if lastPos and lastPos[1] == x and lastPos[2] == y and lastPos[3] == z then
						closeEnemies[enemy] = lastPos
						reused = reused + 1
					else
						thisEnemy.verts = CalcBallisticCircle(x,y,z, thisEnemy.radius, thisEnemy.weaponDef)
						lastPoses[enemy] = thisEnemy
					end
				else
					thisEnemy.noCalcDraw = true
					hasNewNoCalc = true
				end
			end
		end
		--------- some other debugging
		-- local cntVerts = 0
		-- for id, thisEnemy in pairs(closeEnemies) do
		-- 	if thisEnemy and thisEnemy.verts then
		-- 		cntVerts = cntVerts + 1
		-- 	end
		-- end
		-- Echo("cnt, cntReach, , #sorted, verts", cnt, cntReach, #sorted, cntVerts )
		-------------
		return hasNewNoCalc
	end
end

local to = 0
function widget:Update(dt)
	to = to + dt
	if to >= 20 and DEBUG_TIME then
		Echo('size of lastPoses:',table.size(lastPoses),'num of reused time',reused,'average draw time',timeDrawingAverage,'average calc time',timeCalcAverage)
		to = 0
		ResetTime()
	end
	if sel[IGNORE_COUNT] then
		return
	end
	if sel[1] then
		local frame = spGetGameFrame()
		if lastFrame ~= frame then
			local time
			if DEBUG_TIME then
				time = spGetTimer()
			end
			lastFrame = frame
			clear(closeEnemies)
			local totalUnits = 0
			local enByDists = {}
			toDrawNoCalc = false
			local hasNewNoCalc = false

			-- cache[next(cache)] = nil -- test

			local knownUnits = next(cache)
			if not knownUnits then
				knownUnits = {wrongs = {}, valids = {}}
				cache[knownUnits] = true
			end
			local subjects, mid
			if sel[2] and USE_CLUSTERIZATION and WG.DBSCAN_cluster3 then -- we group units that are close together to avoid rechecking around each of them
                local t, n = {}, 0
                for i, id in pairs(sel) do
                    local x, _, z = spGetUnitPosition(id)
                   	if x then
	                    n = n + 1
                    	t[n] = {id, x, z}
                    end
                end
                if n > 0 then
	                t.n = n
	                for i,cluster in ipairs(WG.DBSCAN_cluster3(t, 150, 1)) do
	                	if i <= MAX_SEL then
		                    local totalx,totalz, cnt = 0, 0, cluster.n or #cluster
		                    -- Echo('cluster #' .. i,'count' .. cnt)
		                    -- for i,id in pairs(cluster) do
		                    --     Echo("i,id is ", i,id)
		                    -- end
		                    for i=1, cnt do
		                    	local obj = cluster[i]
		                        totalx = totalx + obj[2]
		                        totalz = totalz + obj[3]
		                    end

		                    local ux,uz = totalx/cnt, totalz/cnt
		                    -- Echo(i,"cnt is ", cnt)
		                    hasNewNoCalc = ProcessEnemiesFromPoint(ux,uz, MAX_RANGE + 300) or hasNewNoCalc
		                end
	                end
	            end
            else
				for i, id in pairs(sel) do
					if i <= MAX_SEL then
						local enemies
						local ux,_,uz = spGetUnitPosition(id)
						if ux then
							hasNewNoCalc = ProcessEnemiesFromPoint(ux,uz, MAX_RANGE) or hasNewNoCalc
						end
					end
				end

			end
			if hasNewNoCalc then
				toDrawNoCalc = SortByDefID(closeEnemies)
			end

			if DEBUG_TIME then
				timeCalcCount = timeCalcCount + 1
				timeCalc = timeCalc +  spDiffTimers(spGetTimer(), time)
				timeCalcAverage = timeCalc / timeCalcCount
			end
		end
	elseif next(closeEnemies) then
		clear(closeEnemies)
		toDrawNoCalc = false
	end
end
function widget:DrawWorldPreUnit()
	if spIsGUIHidden() or next(closeEnemies) == nil then
		return
	end
	local time, got
	if DEBUG_TIME then
		time = spGetTimer()
	end
	glColor(RANGE_COLOR)
	glLineWidth(1.3)
	if USE_BALLISTIC_CALC then
		for _,thisEnemy in pairs(closeEnemies) do
			-- if thisEnemy then
			-- 	Echo("thisEnemy, thisEnemy and thisEnemy.verts is ", thisEnemy, thisEnemy and thisEnemy.verts)
			-- end
			local verts = thisEnemy and thisEnemy.verts
			if verts then
				got = true
				glBeginEnd(GL_LINE_STRIP, CircleVerts, verts)
			end
		end
	else
		if toDrawNoCalc and WG.DrawUnitTypeRanges then
			for defID, units in pairs(toDrawNoCalc) do
				got = true
				WG.DrawUnitTypeRanges(defID, units, RANGE_COLOR, 1.3, true)
			end
		end
	end
	glColor(1, 1, 1, 1)
	glLineWidth(1.0)
	if got and DEBUG_TIME then
		timeDrawingCount = timeDrawingCount + 1
		timeDrawing = timeDrawing +  spDiffTimers(spGetTimer(), time)
		timeDrawingAverage = timeDrawing / timeDrawingCount
	end
end


function widget:Initialize()
	widget:PlayerChanged(myPlayerID)
	widget:CommandsChanged()
end


function widget:Shutdown()

end

