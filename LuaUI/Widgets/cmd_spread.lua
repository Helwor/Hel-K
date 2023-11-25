
--https://controlc.com/fc26919c
function widget:GetInfo()
	return {
		name      = "Spread Command",
		desc      = "Order your unit to spread",
		author    = "Helwor",
		date      = "June 2023",
		license   = "GNU GPL v2",
		layer     = -math.huge, 
		enabled   = false,
		handler   = true,
	}
end
local Echo = Spring.Echo
local function Proceed() Echo('dummy func') end

local SPREAD_FACTOR = 2.5 -- default Spread value
local HOTKEY = 'Alt+X' -- default Hotkey

local showradius = false
local centerx, centery, centerz, radius = 0, 0, 0, 0
local timeshow = 0
local function GetHotkey()
end
options_path = 'Hel-K/Spread Command'

options_order = {
	'factor', 'execute'
}
options = {
	factor = {
		name = 'Spread Factor',
		type = 'number',
		min = 1, max = 7, step = 0.05,
		value = SPREAD_FACTOR,
		update_on_the_fly = true,
		OnChange = function(self)
			SPREAD_FACTOR = self.value
			showradius = os.clock() + 3
		end,
	},
	execute = {
		name = 'Spread',
		type = 'button',
		hotkey = HOTKEY,
		OnChange = function(self)
			Proceed(true)
		end
	}
}

-- localizing make access faster, and gain some time
local spGetUnitPosition = Spring.GetUnitPosition
local spGetSelectedUnitsSorted = Spring.GetSelectedUnitsSorted
local spGetGroundHeight = Spring.GetGroundHeight
local spGiveOrderToUnit = Spring.GiveOrderToUnit
local customCmds = VFS.Include("LuaRules/Configs/customcmds.lua")
local CMD_RAW_MOVE = customCmds.RAW_MOVE
local randomseed, random = math.randomseed, math.random
local osclock = os.clock
local tsort = table.sort
local FindHungarian, GetOrderNoX

local units, u_len = {}, 0
local totalsize = 0

-- include("keysym.lua")
local sizeDefID = {}
for defID, def in pairs(UnitDefs) do
	if not def.isImmobile then
		sizeDefID[defID] = def.xsize * 8
	end
end


Proceed = function(full)
	if u_len < 2 then
		return false
	end
	local sumx,sumz = 0, 0
	local poses = {}

	for i=1, u_len do
		local id = units[i]
		local x,_,z = spGetUnitPosition(id)
		poses[i] = {x,false,z}
		sumx, sumz = sumx + x, sumz + z
	end

	centerx, centerz = sumx / u_len, sumz / u_len
	radius = SPREAD_FACTOR * (totalsize / math.pi)^0.5
	-- Echo("u_len is ", u_len, radius,'SPREAD',SPREAD_FACTOR)
	if full == false then
		return true
	end
	local dests = {}
	-- randomseed(1)
	for i=1, u_len do
		-- TODO: instead of random, make certain the units are well spread out, much work
		local posnegX, posnegZ = random()>0.5 and 1 or -1, random()>0.5 and 1 or -1
		local dx, dz = centerx + (random() * radius * posnegX), centerz + (random() * radius * posnegZ)
		local dy = spGetGroundHeight(dx,dz)
		-- TODO: retry until not spGetGroundBlocked
		dests[i] = {dx,dy,dz}
	end
	GetOrdersNoX(dests, poses, units, u_len) -- function will add  id/dest pairs at poses[2] and poses[4]
	-- TODO: Hungarian method optionnable

    for i=1,u_len do
        local res = poses[i]
        local id = res[2]
        local dest = res[4]
        spGiveOrderToUnit(id, CMD_RAW_MOVE, dest, 0)
    end
    return true
end



function widget:CommandsChanged()
	-- happens when different (or none) units are selected
	-- we register the units we want (no static)
	u_len = 0
	totalsize = 0
	units = {}
	for defID, t in pairs(WG.selectionDefID or spGetSelectedUnitsSorted()) do
		local size = sizeDefID[defID]
		if size then
			local len = #t
			totalsize = totalsize + size^2 * math.pi * len
			for i, id in ipairs(t) do
				u_len = u_len + 1
				units[u_len] = id

			end
		end
	end
end
--------------------------------------------------------------------------------
local glDrawGroundCircle = gl.DrawGroundCircle
local glColor = gl.Color
function widget:DrawWorld()
	
	if not showradius then
		return
	end
	if showradius < osclock() then
		showradius = false
		return
	end
	if not Proceed(false) then
		return
	end
	glColor(0,1,1,1)
	glDrawGroundCircle(centerx, centery, centerz, radius, 32)
	glColor(1,1,1,1)

end


function widget:Initialize()
	widget:CommandsChanged()
	-- not needed
	-- widgetHandler.actionHandler:AddAction(widget, "epic_spread_command_execute", Proceed, nil, 'tp')
end
function widget:Shutdown()
	-- not needed
	-- widgetHandler.actionHandler:RemoveAction(widget, "epic_spread_command_execute", Proceed, nil, 'tp')
end
local press = false
-- function widget:Update()
-- 	if press then
-- 		local real = select(3,Spring.GetMouseState())
-- 		Echo('press', press,' in update, real?', real)
-- 		if not real then
-- 			press = false
-- 		end
-- 	end
-- end
-- function widget:DefaultCommand()
-- 	if press then
-- 		local real = select(3,Spring.GetMouseState())
-- 		Echo('press', press,' in DefCom, real?', real)
-- 		if not real then
-- 			press = false
-- 		end
-- 	end

-- end
function widget:MousePress(mx,my,button)
	-- if button == 1 and math.random()<0.5 then
		-- Echo('press', os.clock())
		press = true
	    -- local t = {}
	    -- local time = Spring.GetTimer()
	    -- for i = 1, 5000000 do
	    --     t[i] = i
	    -- end
        -- Spring.GetDefaultCommand()

	    -- Echo(Spring.DiffTimers(Spring.GetTimer(),time))
		-- return true, Spring.SendCommands('mouse1')
	-- end
end
function widget:MouseRelease()
	-- Echo('released')
	-- press = false
 --    Spring.GetDefaultCommand()
end
------------------
-- Hungarian / OrdersNoX  methods
-- copied from Custom Formation 2 and modified a bit
    -------------------------------------------------------------------------------------
    -------------------------------------------------------------------------------------
    -- (the following code is written by gunblob)
    --   this code finds the optimal solution (slow, but effective!)
    --   it uses the hungarian algorithm from http://www.public.iastate.edu/~ddoty/HungarianAlgorithm.html
    --   if this violates gpl license please let gunblob and me know
    -------------------------------------------------------------------------------------
    -------------------------------------------------------------------------------------
do
    local doPrime, stepPrimeZeroes, stepFiveStar
    local t
    FindHungarian = function(array, n)
        
        t = osclock()
        -- Vars
        local colcover = {}
        local rowcover = {}
        local starscol = {}
        local primescol = {}
        
        -- Initialization
        for i = 1, n do
            rowcover[i] = false
            colcover[i] = false
            starscol[i] = false
            primescol[i] = false
        end
        
        -- Subtract minimum from rows
        for i = 1, n do
            
            local aRow = array[i]
            local minVal = aRow[1]
            for j = 2, n do
                if aRow[j] < minVal then
                    minVal = aRow[j]
                end
            end
            
            for j = 1, n do
                aRow[j] = aRow[j] - minVal
            end
        end
        
        -- Subtract minimum from columns
        for j = 1, n do
            
            local minVal = array[1][j]
            for i = 2, n do
                if array[i][j] < minVal then
                    minVal = array[i][j]
                end
            end
            
            for i = 1, n do
                array[i][j] = array[i][j] - minVal
            end
        end
        
        -- Star zeroes
        for i = 1, n do
            local aRow = array[i]
            for j = 1, n do
                if (aRow[j] == 0) and not colcover[j] then
                    colcover[j] = true
                    starscol[i] = j
                    break
                end
            end
        end
        
        -- Start solving system
        while true do
            
            -- Are we done ?
            local done = true
            for i = 1, n do
                if not colcover[i] then
                    done = false
                    break
                end
            end
            
            if done then
                return starscol
            end
            
            -- Not done
            local r, c = stepPrimeZeroes(array, colcover, rowcover, n, starscol, primescol)
            stepFiveStar(colcover, rowcover, r, c, n, starscol, primescol)
        end
    end
    doPrime = function(array, colcover, rowcover, n, starscol, r, c, rmax, primescol)
        
        primescol[r] = c
        
        local starCol = starscol[r]
        if starCol then
            
            rowcover[r] = true
            colcover[starCol] = false
            
            for i = 1, rmax do
                if not rowcover[i] and (array[i][starCol] == 0) then
                    local rr, cc = doPrime(array, colcover, rowcover, n, starscol, i, starCol, rmax, primescol)
                    if rr then
                        return rr, cc
                    end
                end
            end
            
            return
        else
            return r, c
        end
    end
    stepPrimeZeroes = function(array, colcover, rowcover, n, starscol, primescol)
        
        -- Infinite loop
        while true do
            
            -- Find uncovered zeros and prime them
            for i = 1, n do
                if not rowcover[i] then
                    local aRow = array[i]
                    for j = 1, n do
                        if (aRow[j] == 0) and not colcover[j] then
                            local i, j = doPrime(array, colcover, rowcover, n, starscol, i, j, i-1, primescol)
                            if i then
                                return i, j
                            end
                            break -- this row is covered
                        end
                    end
                end
            end
            
            -- Find minimum uncovered
            local minVal = huge
            for i = 1, n do
                if not rowcover[i] then
                    local aRow = array[i]
                    for j = 1, n do
                        if (aRow[j] < minVal) and not colcover[j] then
                            minVal = aRow[j]
                        end
                    end
                end
            end
            
            -- There is the potential for minVal to be 0, very very rarely though. (Checking for it costs more than the +/- 0's)
            
            -- Covered rows = +
            -- Uncovered cols = -
            for i = 1, n do
                local aRow = array[i]
                if rowcover[i] then
                    for j = 1, n do
                        if colcover[j] then
                            aRow[j] = aRow[j] + minVal
                        end
                    end
                else
                    for j = 1, n do
                        if not colcover[j] then
                            aRow[j] = aRow[j] - minVal
                        end
                    end
                end
            end
        end
    end
    stepFiveStar = function(colcover, rowcover, row, col, n, starscol, primescol)
        
        -- Star the initial prime
        primescol[row] = false
        starscol[row] = col
        local ignoreRow = row -- Ignore the star on this row when looking for next
        
        repeat
            if osclock()-t>0.8 then
                break
            end
            local noFind = true

            for i = 1, n do
                
                if (starscol[i] == col) and (i ~= ignoreRow) then
                    
                    noFind = false
                    
                    -- Unstar the star
                    -- Turn the prime on the same row into a star (And ignore this row (aka star) when searching for next star)
                    
                    local pcol = primescol[i]
                    primescol[i] = false
                    starscol[i] = pcol
                    ignoreRow = i
                    col = pcol
                    
                    break
                end
            end
        until noFind
        
        for i = 1, n do
            rowcover[i] = false
            colcover[i] = false
            primescol[i] = false
        end
        
        for i = 1, n do
            local scol = starscol[i]
            if scol then
                colcover[scol] = true
            end
        end
    end
end
-------------------------------------
GetOrdersNoX = function(nodes, unitPoses, units, unitCount)
    -- Remember when  we start
    -- This is for capping total time
    -- Note: We at least complete initial assignment
    
    ---------------------------------------------------------------------------------------------------------
    -- Find initial assignments
    ---------------------------------------------------------------------------------------------------------
    local unitSet = {}
    local unitSet = unitPoses
    local fdist = -1
    local fm
    local t = osclock()
    for u = 1, unitCount do
        local unit = units[u]
        -- Get unit position
        -- local ux, uz = unit[1],unit[3]
        -- unitSet[u] = {ux, unit, uz, -1} -- Such that x/z are in same place as in nodes (So we can use same sort function)
        local pos = unitSet[u]
        local ux,uz = pos[1],pos[3]
        pos[2]=unit
        pos[4]=-1


        -- Work on finding furthest points (As we have ux/uz already)
        for i = u - 1, 1, -1 do
            
            local up = unitSet[i]
            local vx, vz = up[1], up[3]
            local dx, dz = vx - ux, vz - uz
            local dist = dx^2 + dz^2
            
            if (dist > fdist) then
                fdist = dist
                fm = (vz - uz) / (vx - ux)
            end
        end
    end
    
    -- Maybe nodes are further apart than the units
    for i = 1, unitCount - 1 do
        
        local np = nodes[i]
        local nx, nz = np[1], np[3]
        
        for j = i + 1, unitCount do
            
            local mp = nodes[j]
            local mx, mz = mp[1], mp[3]
            local dx, dz = mx - nx, mz - nz
            local dist = dx*dx + dz*dz
            
            if (dist > fdist) then
                fdist = dist
                fm = (mz - nz) / (mx - nx)
            end
        end
    end
    
    local function sortFunc(a, b)
        -- y = mx + c
        -- c = y - mx
        -- c = y + x / m (For perp line)
        return (a[3] + a[1] / fm) < (b[3] + b[1] / fm)
    end
    
    tsort(unitSet, sortFunc)
    tsort(nodes, sortFunc)
    
    for u = 1, unitCount do
        unitSet[u][4] = nodes[u]
    end
    
    ---------------------------------------------------------------------------------------------------------
    -- Main part of algorithm
    ---------------------------------------------------------------------------------------------------------
    
    -- M/C for each finished matching
    local Ms = {}
    local Cs = {}
    
    -- Stacks to hold finished and still-to-check units
    local stFin = {}
    local stFinCnt = 0
    local stChk = {}
    local stChkCnt = 0
    
    -- Add all units to check stack
    for u = 1, unitCount do
        stChk[u] = u
    end
    stChkCnt = unitCount
    
    -- Begin algorithm
    while stChkCnt > 0 do
        
        -- Get unit, extract position and matching node position
        local u = stChk[stChkCnt]
        local ud = unitSet[u]
        local ux, uz = ud[1], ud[3]
        local mn = ud[4]
        local nx, nz = mn[1], mn[3]
        
        -- Calculate M/C
        local Mu = (nz - uz) / (nx - ux)
        local Cu = uz - Mu * ux
        
        -- StartProcess for clashes against finished matches
        local clashes = false
        
        for i = 1, stFinCnt do
            
            -- Get opposing unit and matching node position
            local f = stFin[i]
            local fd = unitSet[f]
            local fdx,fdz,tn = fd[1],fd[3],fd[4]
            -- Get collision point
            local ix = (Cs[f] - Cu) / (Mu - Ms[f])
            local iz = Mu * ix + Cu
            
            -- StartProcess bounds
            -- if ux==nx and uz==nz and fdx==tn[1] and fdz==tn[3] then
            if ux==fdx and uz==fdz then
                -- skip or it will be endless
            elseif (ux - ix) * (ix - nx) > 0 and
               (uz - iz) * (iz - nz) > 0 and
               (fdx - ix) * (ix - tn[1]) > 0 and
               (fdz - iz) * (iz - tn[3]) > 0 then
                
                -- Lines cross
                
                -- Swap matches, note this retains solution integrity
                ud[4] = tn
                fd[4] = mn
                
                -- Remove clashee from finished
                stFin[i] = stFin[stFinCnt]
                stFinCnt = stFinCnt - 1
                
                -- Add clashee to top of check stack
                stChkCnt = stChkCnt + 1
                stChk[stChkCnt] = f
                
                -- No need to check further
                if osclock()-t > 0.8 then 

                    -- Debug.algo('NoX took too long\n'..(ux - ix), (ix - nx)..' | '..(uz - iz), (iz - nz)..' | '..(fd[1] - ix), (ix - tn[1])..' |'..(fd[3] - iz), (iz - tn[3]))
                    -- Debug.algo('NoX coords\n'..ux..','..uz..' | '..nx..','..nz..' | '..fd[1]..','..fd[3]..' | '..tn[1]..','..tn[3])
                    break
                end
                clashes = true
                break
            end
        end
        
        if not clashes then
            
            -- Add checked unit to finished
            stFinCnt = stFinCnt + 1
            stFin[stFinCnt] = u
            
            -- Remove from to-check stack (Easily done, we know it was one on top)
            stChkCnt = stChkCnt - 1
            
            -- We can set the M/C now
            Ms[u] = Mu
            Cs[u] = Cu
        end
    end
end


