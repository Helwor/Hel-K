-- $Id: gui_commandinsert.lua 3171 2008-11-06 09:06:29Z det $
-------------------------------------------------------------------------------------

function widget:GetInfo()
	return {
		name = "CommandInsert2",
		desc = "Implements mid-queue command insertion via SPACE",
        author = "dizekat, GoogleFrog (structure block order), Helwor (rapid insert and Area Attack fix)",
		date = "Jan,2008", --16 October 2013
		license = "GNU GPL, v2 or later",
		layer = 5.5,
		enabled = true,
		handler = true,
		api = true,
	}
end

local Echo = Spring.Echo

-- default values before user touch the options
local debugMe = false
local debugDraw = false
local noInsertBeforeCurrentBuild = true
local useBuffer = false
local correctAfter = true
local reorderSequence = true
--


local debugCache = false

if reorderSequence then
	reorderSequence = {}
end


local PING_TIMEOUT_MULT = 2.2


local buffer, sequence = {}, {}
local oldWGCommandInsert = WG.CommandInsert
local askedPingF, ping = 0, 0
local t = 0
local page, frame = 0, Spring.GetGameFrame()
local EMPTY_TABLE = {}

local sizetable, offtable = {}, {}
local spGetTimer = Spring.GetTimer
local spDiffTimers = Spring.DiffTimers
local cachedItems = {}
local _cache
_cache = {
	used = 0, count = 0, elapsed = 0,
	clear = function(tell)
		if debugMe or tell then
			_cache:tell()
		end
		for k in pairs(cachedItems) do
			cachedItems[k] = nil
		end
		_cache.count, _cache.used, _cache.elapsed = 0, 0, 0
	end,
	tell = function()
		Echo('cache has ' .. _cache.count .. ' stored elements and has been used ' .. _cache.used .. ' times. Using cache took ' .. _cache.elapsed )
	end,
	time = function()
		if on then
			_cache.timer = spGetTimer()
		elseif _cache.timer then
			_cache.elapsed = _cache.elapsed + spDiffTimers(spGetTimer(), _cache.timer)
		end
	end,

}
local simplecache
simplecache = {
	clear = function()
		local tmp = simplecache.clear
		for k in pairs(simplecache) do
			simplecache[k] = nil
		end
		simplecache.clear = tmp
	end
}
local cache = not debugCache and simplecache or setmetatable( -- proxy to control access
	{},
	{
		__index = function(self,k) 
			_cache.time(true)
			local item = cachedItems[k]
			if item then
				_cache.used = _cache.used + 1
			end
			_cache.time(false)
			return item or _cache[k]
		end,
		__newindex = function(self,k,v) 
			_cache.time(true)
			_cache.count = _cache.count + 1
			cachedItems[k] = v
			_cache.time(false)
		end,
	}

)
for defID, def in pairs(UnitDefs) do
	local sx,sz = def.xsize*4 - 0.1, def.zsize*4 - 0.1
	if sx ~= sz then
		offtable[defID] = sz
	end
	sizetable[defID] = sx
end

-- NOTE Some command trigger an automatic RAW_BUILD which happen at the beginning of the next frame, widget:GameFrame is not yet triggered, only way to have the correct frame is to use Spring.GetGameFrame() in UnitCommand



local CommandInsert = function()end
local CMDNAMES
local function SetupCMDNAMES()
	CMDNAMES = {}
	local customCmds = VFS.Include("LuaRules/Configs/customcmds.lua")
	local actualCmds={[0]='STOP',[1]='INSERT',[2]='REMOVE',[16]='FIGHT',[20]='ATTACK'}
	for k,v in pairs(CMD) do CMDNAMES[v]=actualCmds[v] or k end
	for k,v in pairs(customCmds) do CMDNAMES[v]=actualCmds[v] or k end
	for k,v in pairs(UnitDefs) do CMDNAMES[-k]=v.name end
	setmetatable(CMDNAMES, {__index = function(t,k) return 'unknown ('..tostring(k)..')' end})
end
CMDNAMES = setmetatable({}, {__index = function(t,k) SetupCMDNAMES() return CMDNAMES[k] end })

local clear = function(t)
	for k in pairs(t) do
		t[k] = nil
	end
end



local function SwitchToOld(on)
	if on then -- keep our widget alive but remove the CallIn interactions
		local oldActive, oldExist =  widgetHandler:FindWidget('CommandInsert'), widgetHandler.knownWidgets['CommandInsert']
		if not oldExist then
			Echo("Old CommandInsert doesn't exist")
			return
		end
		if not widget.sleeping then
			local sleeping = false
			for k,v in pairs(widget) do
				if type(v) == 'function' and k~='PlayerChanged' then
					local isCallIn = widgetHandler[k .. 'List']
					if isCallIn then
						sleeping = true
						widgetHandler:RemoveWidgetCallIn(k, widget)
					end
				end
			end
			widget.sleeping = sleeping
			if debugMe then
				Echo('Attempt to put ' .. widget:GetInfo().name .. ' to sleep: ' .. (sleeping and 'success' or 'fail') .. '.')
			end
		end
		WG.CommandInsert = oldWGCommandInsert
		if not oldActive then
			Echo('Enabling CommandInsert')
			widgetHandler:EnableWidget('CommandInsert')
		end
	else
		local CI =  widgetHandler:FindWidget('CommandInsert')
		if CI then
			Echo('Disabling CommandInsert to be replaced by ' .. widget:GetInfo().name)
			widgetHandler:RemoveWidget(CI)
		end
		if widget.sleeping then
			local sleeping = true
			for k,v in pairs(widget) do
				if type(v) == 'function' and k~='PlayerChanged' then
					local isCallIn = widgetHandler[k .. 'List']
					if isCallIn then
						sleeping = false
						widgetHandler:UpdateWidgetCallIn(k, widget)
					end
				end
				widget.sleeping = sleeping

			end
			if debugMe then
				Echo('Attempt to wake up ' .. widget:GetInfo().name .. ': ' .. (sleeping and 'fail' or 'success') .. '.')
			end
		end
		WG.CommandInsert = CommandInsert

	end
	return true
end
local function GetPanel(path) -- Find out the option panel if it's visible
    for _,win in pairs(WG.Chili.Screen0.children) do
        if  type(win)     == 'table'
        and win.classname == "main_window_tall"
        and win.caption   == path
        then
            for panel in pairs(win.children) do
                if type(panel)=='table' and panel.name:match('scrollpanel') then
                    return panel
                end
            end
        end
    end
end
-- useBuffer is not up to date with the recent changes and not useful so far
options_path ='Hel-K/Command Insert 2'
options_order = {'desc','desc2','desc3','useold','no_insert_before_started_build',--[['usebuffer',--]]'correct','reorder_seq','debug','debugdraw'}
options = {}
options.useold = {
	name = 'Use Old Command Insert',
	type = 'bool',
	value = false,
	OnChange = function(self)
		local on = self.value
		if SwitchToOld(on) then
			options.debug.hidden = on
			options.debugdraw.hidden = on
			options.no_insert_before_started_build.hidden = on
			options.correct.hidden = on
		end
		if GetPanel(options_path) then
			WG.crude.OpenPath(options_path)
		end
	end,
}
options.desc = {
	name = '-Use virtual queue system to allow',
	type = 'label',
}
options.desc2 = {
	name = ' rapid/multi insert despite server delay',
	type = 'label',
}
options.desc3 = {
	name = '-Fix insert Area Attack behaviour',
	type = 'label',
}
options.no_insert_before_started_build = {
	name = "No shift ins before a build started",
	desc = "if a build would be placed before the one you've just started, it will be placed just after." ,
	type = 'bool',
	value = noInsertBeforeCurrentBuild,
	OnChange = function(self)
		noInsertBeforeCurrentBuild = self.value
	end
}
options.usebuffer = {
	name = "Use Buffer",
	desc = "Might be more reliable but more jerky, going batch per batch and waiting server response in between." ,
	type = 'bool',
	value = useBuffer,
	OnChange = function(self)
		useBuffer = self.value
	end
}
options.debug = {
	name = 'Console Debug',
	type = 'bool',
	value = debugMe,
	OnChange = function(self)
		debugMe = self.value
		if debugMe then
			-- if not CMDNAMES then
			-- 	SetupCMDNAMES()
			-- end
		elseif not options.debugdraw.value then
			CMDNAMES = setmetatable({}, {__index = function(t,k) SetupCMDNAMES() return CMDNAMES[k] end })
		end
	end
}
options.debugdraw = {
	name = 'Draw Debug',
	type = 'bool',
	value = debugDraw,
	OnChange = function(self)
		debugDraw = self.value
		if debugDraw then
			-- if not CMDNAMES then
			-- 	SetupCMDNAMES()
			-- end
		elseif not options.debug.value then
			CMDNAMES = setmetatable({}, {__index = function(t,k) SetupCMDNAMES() return CMDNAMES[k] end })
		end

	end
}
options.correct = {
	name = 'Correct queue afterward',
	desc = 'waiting for the server response time then correct the wrong order positions',
	type = 'bool',
	value = correctAfter,
	OnChange = function(self)
		correctAfter = self.value
	end,
}
options.reorder_seq = {
	name = 'Reorder Sequence',
	desc = 'Reorder given commands of sequence to be treated the farther first, resulting better on squares of build',
	type = 'bool',
	value = reorderSequence and true,
	OnChange = function(self)
		reorderSequence = self.value and {}
	end,
}
VFS.Include("LuaRules/Configs/customcmds.h.lua")

local spGetMyTeamID 			= Spring.GetMyTeamID
local spGetUnitTeam 			= Spring.GetUnitTeam
local spAreTeamsAllied 			= Spring.AreTeamsAllied
local spGetUnitPosition 		= Spring.GetUnitPosition
local spGetFeaturePosition 		= Spring.GetFeaturePosition
local spGetSelectedUnits 		= Spring.GetSelectedUnits
local spGiveOrder				= Spring.GiveOrder
local spGiveOrderToUnit			= Spring.GiveOrderToUnit
local spGiveOrderArrayToUnit	= Spring.GiveOrderArrayToUnit
local spGetCommandQueue			= Spring.GetCommandQueue
local spGetSelectedUnitsSorted 	= Spring.GetSelectedUnitsSorted
local spValidUnitID				= Spring.ValidUnitID
local spGetGroundBlocked 		= Spring.GetGroundBlocked

-- local spGetUnitsInRectangle		= Spring.GetUnitsInRectangle
local spGetUnitDefID			= Spring.GetUnitDefID

local CMD_OPT_ALT 	= CMD.OPT_ALT
local CMD_OPT_CTRL 	= CMD.OPT_CTRL
local CMD_OPT_META 	= CMD.OPT_META
local CMD_OPT_SHIFT = CMD.OPT_SHIFT
local CMD_OPT_RIGHT = CMD.OPT_RIGHT

local CMD_ATTACK 	= CMD.ATTACK
local CMD_RESURRECT = CMD.RESURRECT
local CMD_REPAIR 	= CMD.REPAIR
local CMD_INSERT 	= CMD.INSERT
local CMD_GUARD		= CMD.GUARD
local CMD_REMOVE	= CMD.REMOVE
local CMD_LEVEL		= CMD_LEVEL
local CMD_RECLAIM	= CMD.RECLAIM

local maxUnits = Game.maxUnits

local sqrt = math.sqrt


local positionCommand = {
	[CMD.MOVE] = true,
	[CMD_RAW_MOVE] = true,
	[CMD_RAW_BUILD] = true,
	[CMD_REPAIR] = true,
	[CMD.RECLAIM] = true,
	[CMD_RESURRECT] = true,
	[CMD.MANUALFIRE] = true,
	[CMD_GUARD] = true,
	[CMD.FIGHT] = true,
	[CMD_ATTACK] = true,
	[CMD_JUMP] = true,
	[CMD_LEVEL] = true,
}
for k,v in pairs(widget) do
    local num = tonumber(v)
    if num and num>39000 and num < 40000 then
        positionCommand[num] = true
    end
end
local moveCommand = {

	[CMD.MOVE] = true,
	[CMD_RAW_MOVE] = true,
	[CMD_RAW_BUILD] = true,
	-- [CMD.STOP] = true,
}


--


local flyingConDefID = {}
local buildRange = {}
for defID, def in pairs(UnitDefs) do
	if def.buildDistance then
		buildRange[defID] = def.buildDistance
	end
	if def.isBuilder and def.canFly then
		flyingConDefID[defID] = true
	end
end


local doNotHandleRaw = {
	[-UnitDefNames["staticmex"].id] = true,
}

local waitOrder, timeOut = {}, {}
local queues = {}
local gamePaused = select(3,Spring.GetGameSpeed())


--[[
-- use this for debugging:
function table.val_to_str ( v )
	if "string" == type( v ) then
		v = string.gsub( v, "\n", "\\n" )
		if string.match( string.gsub(v,"[^'\"]",""), '^" + $' ) then
			return "'" .. v .. "'"
		end
		return '"' .. string.gsub(v,'"', '\\"' ) .. '"'
	else
		return "table" == type( v ) and table.tostring( v ) or
			tostring( v )
	end
end

function table.key_to_str ( k )
	if "string" == type( k ) and string.match( k, "^[_%a][_%a%d]*$" ) then
		return k
	else
		return "[" .. table.val_to_str( k ) .. "]"
	end
end

function table.tostring( tbl )
	local result, done = {}, {}
	for k, v in ipairs( tbl ) do
		table.insert( result, table.val_to_str( v ) )
		done[ k ] = true
	end
	for k, v in pairs( tbl ) do
		if not done[ k ] then
			table.insert( result,
				table.key_to_str( k ) .. "=" .. table.val_to_str( v ) )
		end
	end
	return "{" .. table.concat( result, "," ) .. "}"
end
--]]




-- -- remove the block insertion system for a new one
-- -- Place the structure commands in the order issued by the user.
-- local structureSquenceCount

-- -- Use the first position in a block of structure commands as the command position
-- -- to keep the block together.
-- local structOverrideX, structOverrideY, structOverrideZ



local function CompareLastParams(t1,t2) -- num of params in t1 is the reference for looking into t2 params from the end -- this is useful for comparing params of direct order to param of inserted order
    local len, len2 = #t1, #t2
    local off = len2 - len
    for i=1, len do
        if t1[i] ~= t2[off + i] then
            return false
        end
    end
    return true
end

local function GetPositionCommand(commands, i,desc)
	local command = commands[i]
	while command and not command.pos do
		i = i + (desc and -1 or 1)
		command = commands[i]
	end
	return command, i
end

local function GetUnitOrFeaturePosition(id)
	if id <= maxUnits then
		return spGetUnitPosition(id)
	else
		return spGetFeaturePosition(id - maxUnits)
	end
end
----- debugging
local spGetTimer, spDiffTimers = Spring.GetTimer, Spring.DiffTimers
-----
local function GetCommandPosOLD(command) -- get the command position
	local strID = command.id .. '-'.. table.concat(command.params,'-') 
	local cached = cache[strID] -- ~6x faster with cache
	----- debugging strID
	-- 	local dbg = debug.traceback()
	-- 	local l = dbg:find('\n')
	-- 	l = dbg:find('\n',l+2)
	-- 	dbg = dbg:sub(l+2, dbg:find('\n',l+2))
	-- 	Echo("strID =>" .. strID)
	-- 	Echo('cpos cached: '.. tostring(cached) ..', called at ' .. dbg)
	----- debugging
	local timer
	-- if debugMe then
		timer = spGetTimer()
	-- end
	-----
	if cached then
		----- debugging
		-- if debugMe then
			cache.used = (cache.used or 0) + 1
			cache.usedtime = (cache.usedtime or 0) + spDiffTimers(spGetTimer(), timer)
		-- end
		-----
		return unpack(cached.pos or EMPTY_TABLE)
	end
	--------
	cache[strID] = command
	----- debugging
	-- if debugMe then
		cache.unused = (cache.unused or 0) + 1
		timer = spGetTimer()
	-- end
	-----
	local id = command.id
	if id < 0 or positionCommand[id] then
		local params = command.params
		if params[3] then
			x,y,z =  params[1], params[2], params[3]
		elseif params[1] then
			x,y,z = GetUnitOrFeaturePosition(params[1])
		end
	end
	command.pos = {x,y,z}
	----- debugging
	-- if debugMe then
		cache.unusedtime = (cache.unusedtime or 0) + spDiffTimers(spGetTimer(), timer)
	-- end
	-----
	return x,y,z
end

local function GetCommandPos(command) -- get the command position
	local id = command.id
	if id < 0 or positionCommand[id] then
		local params = command.params
		if params[3] then
			x,y,z =  params[1], params[2], params[3]
		elseif params[1] then
			x,y,z = GetUnitOrFeaturePosition(params[1])
		end
	end
	return x,y,z
end




--- Area Attack Processing
local subjectX, subjectZ
local dists, poses = {}, {}
local function sortEnemies(a,b)
	if not dists[a] then
		dists[a] = (subjectX - poses[a][1])^2 + (subjectZ - poses[a][3])^2
	end
	if not dists[b] then
		dists[b] = (subjectX - poses[b][1])^2 + (subjectZ - poses[b][3])^2
	end
	return dists[a] < dists[b]
end
local function GetEnemies(params)
	local strID = CMD_ATTACK .. '-' ..table.concat(params,'-')
	if cache[strID] then
		return unpack(cache[strID])
	end
	 
	local myTeamID = spGetMyTeamID()
	local units = Spring.GetUnitsInCylinder(params[1], params[3], params[4])
	local enemies = {}
	local enemyCount = 0
	for k in pairs(poses) do
		poses[k] = nil
	end
	for i=1, #units do
		local unitID = units[i]
		if not spAreTeamsAllied(myTeamID, spGetUnitTeam(unitID)) then
			enemyCount = enemyCount + 1
			enemies[enemyCount] = unitID
			poses[unitID] =  {spGetUnitPosition(unitID)}
		end
	end
	cache[strID] = {enemies, enemyCount}
	return enemies, enemyCount
end
local function ProcessAreaAttack(unitID, insert_pos, commands, coded, enemies, enemyCount, params)
	local done
	if enemyCount == 0 then
		return
	end
	if insert_pos == 0 then
		-- Echo('subjectX is unit pos', subjectX,subjectZ)
	else
		local _
		subjectX, _, subjectZ = GetCommandPos(commands[insert_pos])
		-- Echo('subjectX is command #' .. insert_pos, subjectX, subjectZ)
	end
	local strID = CMD_ATTACK .. '-' ..table.concat(params,'-')
	local cached = cache[strID]
	if not cached.sorted then
		for k in pairs(dists) do
			dists[k] = nil
		end
		table.sort(enemies, sortEnemies)
		cached.sorted = true
	end
	for i=1, enemyCount do
		local enemyID = enemies[i]
		spGiveOrderToUnit(unitID, CMD_INSERT, {insert_pos + i - 1, CMD_ATTACK, coded, enemyID}, CMD_OPT_ALT)		
		done = true
	end
	return done
end

------

local function ReportTimeOut(unitID, delay, id, params)
	if id then
		waitOrder[unitID] = params
		waitOrder[unitID].id = id
	end
	
	if gamePaused then
		timeOut[unitID] = t + delay / 30
		-- Echo("(commands.pingFrame/30) is ",commands.pingFrame, (commands.pingFrame/30))
	else
		timeOut[unitID] = frame + delay
		-- Echo('time out', timeOut[unitID],commands.pingFrame)
	end
end

local function QualifyCommands(commands, commands_len)
	-- remove any RAW_BUILD as we will ask for a remove on each insertion
	local i, order = 1, commands[1]
	while order do
		if order.id == CMD_RAW_BUILD then
			table.remove(commands,i)
			commands_len = commands_len - 1
		else
			i = i + 1
		end
		order = commands[i]
	end

	local last = commands[commands_len]
	local px2, py2, pz2
	local isTerra
	if last then
		if last.id > 39000 and last.id < 40000 then
			isTerra = true
			last.isTerra = true
		end
		px2, py2, pz2 = GetCommandPos(last)
		if px2 then
			last.pos = {px2, py2, pz2}
		end
	end
	for j = commands_len-1, 1, -1 do
		local command = commands[j]
		local px, py, pz
		local id = command.id
		if id < 0 then
			px,py,pz = GetCommandPos(command)
			if isTerra then
				if px == px2 and pz == pz2 then
					command.isTerra = true
				else
					isTerra = false
				end
			end
		elseif id > 39000 and id < 40000 then
			px,py,pz = GetCommandPos(command)
			isTerra = true
			command.isTerra = true
			if px2 and px == px2 and pz == pz2 then
				last.isTerra = id == CMD_LEVEL
			end
		elseif id == CMD_REPAIR then
			if isTerra then
				command.isTerra = true
				px, py, pz = px2, py2, pz2
				isTerra = false
			end
		elseif id == CMD_RAW_BUILD then
			if last.isTerra then
				command.isTerra = true
				px, py, pz = px2, py2, pz2
				isTerra = false -- in case it is true, faster than checking (?)
			end
		end
		if not px then
			px, py, pz = GetCommandPos(command)
			if px then
				isTerra = false
			end
		end
		if px then
			command.pos = {px, py, pz}
			cache[command.id..'-'..table.concat(command.pos,'-')] = command
			px2, py2, pz2 = px, py, pz
		end
		last = command
	end
	return commands_len
end

local function UpdateCommandsReach(commands, commands_len, buildDist, px,py,pz)
	local reachBuild
	local command, i = GetPositionCommand(commands, 1)
	if command then

		if command.id == CMD_RAW_BUILD then
		------------ not needed, RAW_BUILD should not appear
		-- 	local j = i + 1
		-- 	local nex = commands[j]
		-- 	while nex and not nex.dist do
		-- 		j = j + 1
		-- 		nex = commands[j]
		-- 	end
		-- 	if nex and nex.id < 0 then
		-- 		local dist = ((nex.params[1] - px)^2 + (nex.params[3] - pz)^2)^0.5
		-- 		if dist <= buildDist then
		-- 			table.remove(commands,i)
		-- 			commands_len = commands_len - 1
		-- 			reachBuild = true
		-- 			if debugMe then
		-- 				Echo('[f:'..frame..']:'..'REMOVE RAW BUILD x' .. command.params[1] .. ' UNIT REACH ')
		-- 			end
		-- 			j = j + 1
		-- 			local nex = commands[j]
		-- 			while nex and not nex.dist do
		-- 				j = j + 1
		-- 				nex = commands[j]
		-- 			end	
		-- 			if nex then
		-- 				nex.dist = ((nex.params[1] - px)^2 + (nex.params[3] - pz)^2)^0.5
		-- 			end
		-- 		end
		-- 	end
		------------
		elseif moveCommand[command.id] then
			if not gamePaused then
				local dist = ((command.params[1] - px)^2 + (command.params[3] - pz)^2)^0.5
				if dist < 32 then
					table.remove(commands,i)
					commands_len = commands_len - 1
					-- if debugMe then
						-- Echo('[f:'..frame..']:'..'REMOVE '.. command.id .. ' x' .. command.params[1] .. ' UNIT REACH ')
					-- end
					local nex = GetPositionCommand(commands, i+1)
					if nex then
						nex.dist = ((nex.params[1] - px)^2 + (nex.params[3] - pz)^2)^0.5
					end
				end
			end
		elseif command.id < 0 then
			local dist = ((command.params[1] - px)^2 + (command.params[3] - pz)^2)^0.5
			if dist <= buildDist then
				reachBuild = true
				-- Echo('REACHBUILD')
			end
		elseif command.id == CMD_REPAIR then
			local tx,ty,tz
			if command.isTerra then
				tx,ty,tz = unpack(command.pos)
			else
				local id = not command.params[2] and command.params[1]
				if id then
					cache[id] = cache[id] or {spGetUnitPosition(id)}
					tx,ty,tz = unpack(cache[id])
				end
			end
			if tx then
				local dist = ((tx - px)^2 + (tz - pz)^2)^0.5
				-- Echo("dist <= buildDist + 100 is ", dist , buildDist + 100)
				if dist <= buildDist + 100 then
					reachBuild = true
					-- Echo('REACH REPAIR')
				end	
			end
		end
	end
	return reachBuild, commands_len
end

local function GetInsertionPoint(unitID,buildDist,isFlyingCon, id, cx,cy,cz, params, coded, now, pendingInsert)
	-- queue is simulated until orders are received, this way a rapid multi insertion can be correctly placed among the current commands + the future commands
	-- limitation is it doesn't catch a non inserted command that has been given rapidly before that inserted, and therefore will not be accounted fo
	local commands = queues[unitID]
	local usingVirtualQueue
	if not commands or ((gamePaused and t or frame) > timeOut[unitID])  then
		commands = spGetCommandQueue(unitID, -1)
		if not commands then -- never happened
			Echo('NO COMMAND QUEUE FOR ' .. unitID)
			return
		end
		-- if commands[1] then
		-- 	for i = 1, 1000 do
		-- 		GetCommandPos(commands[1])
		-- 	end
		-- 	for i = 1, 1000 do
		-- 		GetCommandPos(commands[1], true)
		-- 	end
		-- end
		-- if not gamePaused and not useBuffer and not isFlyingCon then -- used to calculate when we should remove CMD_RAW_BUILD
			local pingNow
			if gamePaused then
				pingNow = 0.25
			elseif askedPingF + 30 < frame then
			 	pingNow = select(6,Spring.GetPlayerInfo(Spring.GetMyTeamID(), true))
			 	ping = pingNow
			 	askedPingF = frame
			else
			 	pingNow = ping
			end
			commands.pingFrame = math.ceil(30  *  pingNow --[[* 1.25--]] )
			-- if debugMe then
			-- 	Echo('ping is ',ping,'pingFrame',commands.pingFrame)
			-- end
		-- end
		commands.expected = {}
		if pendingInsert then -- used by buffer method , unfinished work
			local ins = math.min(#commands+1,pendingInsert[1]+1)
			table.insert(commands,ins,{id=pendingInsert[2],options={coded=pendingInsert[3]},params={select(4,unpack(pendingInsert))}})
			if debugMe then
				Echo('pendingInsert::::',CMDNAMES[pendingInsert[2]] .. ' ('..pendingInsert[2]..')'..' x'..pendingInsert[4] .. 'inserted at '..ins..'/'..#commands, '(ori ins pos: '..pendingInsert[1]..')')
			end
		end
		commands.count = 0
		queues[unitID] = commands
		commands.page = -1
		commands.unitID = unitID
		commands.frame = -1
	-- 	Echo('num of spQueue: ' .. #commands)
	else

		-- verify duplicate
		for i, order in ipairs(commands) do
			if order.id == id then
				if CompareLastParams(params, order.params) then
					ReportTimeOut(unitID, commands.pingFrame * PING_TIMEOUT_MULT)
					return
				end
			end
		end
		usingVirtualQueue = true
	-- 	Echo('num of queue: ' .. #commands)
	end
	-- Detect Sequence

	local px,py,pz = spGetUnitPosition(unitID)
	local prev_new = ((px-cx)^2 + (pz-cz)^2)  ^0.5

	local isTerra = id > 39000 and id < 39000
	local sqrt = math.sqrt

	local firstFound
	local min_dlen = 10000000
	local insert_pos = 0
	local commands_len = #commands
	local new_dist = prev_new
	local cur_dist = 0
	local isTerra = id > 39000 and id < 40000 
	local firstFound = true
	local isSequence
	if usingVirtualQueue then
		if debugMe then
			Echo(os.clock(),'Using Virtual Queue')
		end
		if gamePaused then
			isSequence = commands.frame == frame
		else
			isSequence = commands.page == page
		end

		if isSequence and reorderSequence then
			reorderSequence[unitID] = reorderSequence[unitID] or {}
			table.insert(reorderSequence[unitID], {unitID,buildDist,isFlyingCon, id, cx,cy,cz, params, coded, now, pendingInsert})
			return
		end

		-- if not gamePaused and not isFlyingCon then
		-- 	local first = commands[1]
		-- 	local j = 1
		-- 	while first and not first.dist do
		-- 		j=j+1
		-- 		first = commands[j] 
		-- 	end
		-- 	if first and not moveCommand[first.id] then
		-- 		local isTerra = first.id > 39000 and first.id < 39000
		-- 		if first.dist > buildDist +  (isTerra and 100 or 0) then
		-- 			-- accounting for the CMD_RAW_BUILD extra order that will pop in the queue if our order is placed first and it is outside the range of our build distance
		-- 			-- if terra order (id between 39K and 40K) then a terra unit will popup closer by 100 elmos
		-- 			local x,y,z = unpack(first.pos)
		-- 			commands.count = commands.count + 1
		-- 			table.insert(commands, j, {count = commands.count, id=CMD_RAW_BUILD,isTerra=isTerra, inspos = 0,params = {x,y,z}, dist = first.dist, pos = {x,y,z} })
		-- 			first.dist = 0
		-- 			commands_len = commands_len + 1
		-- 			if debugMe then
		-- 				-- FIXME: flying con don't have RAW_BUILD addition !  
		-- 				Echo('new sequence start, accounting for extra CMD_RAW_BUILD','total length',commands_len)
		-- 			end
		-- 		end
		-- 	end
		-- end
		local reachBuild
		if not gamePaused then
			-- remove RAW BUILD/ move command if our con has reached the range, getiformed about eaching the first command
			reachBuild, commands_len = UpdateCommandsReach(commands, commands_len, buildDist, px,py,pz)

			--------------- remove RAW_BUILD that should expire by the time our order get received
			--------------- NOT NEEDED, RAW_BUILD should not appear in the queue
				-- local i,command = 1,commands[1]
				-- while command do
				-- 	if command.id == CMD_RAW_BUILD and command.removeAt and frame >= command.removeAt then
				-- 		local j, nex = i+1, commands[i+1]
				-- 		while nex and not nex.dist do
				-- 			j = j+1
				-- 			nex = commands[j]
				-- 		end
				-- 		if nex then
				-- 			nex.dist = command.dist
				-- 		end
				-- 		table.remove(commands, i)
				-- 		commands_len = commands_len-1
				-- 		if debugMe then
				-- 			Echo('[f'..frame..']:Removing expired RAW_BUILD x'..command.pos[1]..' , ('.. command.removeAt .. ')  at '..i..',  now length of queue is '.. commands_len,'estimated real removal:'..command.removeAt + commands.pingFrame)
				-- 		end
				-- 	else
				-- 		i = i + 1
				-- 	end
				-- 	command = commands[i]
				-- end
			---------------
		end
		commands.page = page

		for j = 1, commands_len do
			local command = commands[j]
			-- Echo("cmd:"..table.tostring(command))
			local pos = command.pos
			if pos then
				px2, pz2 = pos[1], pos[3]
				local new_cur = sqrt((px2-cx)^2 + (pz2-cz)^2)
				command.dist = command.dist or sqrt((px2-px)^2 + (pz2-pz)^2)
				local prev_cur = command.dist
				local dlen = prev_new + new_cur - prev_cur
				-- if debugMe then
				-- 	Echo(
				-- 		 '#' .. j .. '/' .. commands_len,(CMDNAMES[command.id]) .. ' ('..command.id..')'..' x'..command.pos[1]
				-- 		,'dist: ' .. tostring(command.dist)
				-- 		,'dlen = prev_new '..prev_new..' + new_cur '..new_cur..' - prev_cur '..prev_cur..' = '..dlen
				-- 	)
				-- end

				-- dlen calculation, dlen is the change in travel distance between the point before and the point after if our command is inserted in there


				-- dlen is the change in travel distance if the command is inserted at this position.
				if dlen <= min_dlen then
					-- if option to not shift insert before a started build has been chosen
					-- if the insertion shoud be before the first command and that command is a build/terra order
					-- if that buildorder is in range of immediate start and not at the same position of the analyzed command

					if firstFound and noInsertBeforeCurrentBuild and new_cur > 0 then
--[[						if (isTerra) then
							local buildOrder = command.isTerra and 2 or command.id < 0 and 1 
							local immediateRange = buildOrder and buildDist and prev_cur < buildDist + (buildOrder == 2 and 100 or 0) --+ 10 -- + a little margin? with the wasp it looks like it need it
							-- if debugMe then
								Echo('First found','immediateRange is',immediateRange,prev_cur..'<'..buildDist..'+'..(buildOrder == 2 and 100 or 0),"buildOrder, buildDist is ", buildOrder, buildDist)
							-- end
							if immediateRange then
								dlen = min_dlen + 1 -- hack the dlen so the insert doesn't happen
								-- if debugMe then
									Echo("Build insertion is pushed after the current build")
								-- end
							end
						else--]]if reachBuild then
							dlen = min_dlen + 1 -- hack the dlen so the insert doesn't happen
							if debugMe then
								Echo("Build insertion is pushed after the current build")
							end
						end

					end
				end
				if dlen <= min_dlen then
					if not isTerra and id < 0 and new_cur == 0 and command.isTerra then
						-- build on same place than the current command, which is terra
						isTerra = true
					end
					insert_pos = j - 1
					new_dist = prev_new
					cur_dist = new_cur
					if debugMe then
						-- Echo('new insert pos at',insert_pos,'dlen',dlen, 'isTerra ?',isTerra)
					end
					min_dlen = dlen
					cur_dist = new_cur
				end
				px, pz = px2, pz2
				prev_new = new_cur
				firstFound = false
			else
				insert_pos = insert_pos + 1
			end
		end
		-- Echo("insert_pos==0, commands[1] and commands[1].id, CMD_RAW_BUILD is ", insert_pos==0, commands[1] and commands[1].id, CMD_RAW_BUILD)
	else
		if debugMe then
			Echo(os.clock(),'Using Real Queue')
		end



		---- Detect orders belonging to the same terra (aka RAW BUILD, REPAIR and BUILD for CMD_LEVEL) and consider the repair order pos the same as the terra
		commands_len = QualifyCommands(commands, commands_len)

		------ Not accounting for CMD_RAW_MOVE, removing them before insertion
		-- if not gamePaused and useBuffer then
		-- 	local first = commands[1]
		-- 	local j = 1
		-- 	while first and not first.pos do
		-- 		j=j+1
		-- 		first = commands[j] 
		-- 	end
		-- 	if first and not isFlyingCon and not moveCommand[first.id] then
		-- 		local isTerra = first.id > 39000 and first.id < 39000
		-- 		local x,y,z = unpack(first.pos)
		-- 		local dist = ((x - px)^2 + (z - pz)^2)^0.5
		-- 		if dist > buildDist +  (isTerra and 100 or 0) then
		-- 			-- accounting for the CMD_RAW_BUILD extra order that will pop in the queue if our order is placed first and it is outside the range of our build distance
		-- 			-- if terra order (id between 39K and 40K) then a terra unit will popup closer by 100 elmos
		-- 			if debugMe then
		-- 				Echo('+ EXTRA CMD_RAW_BUILD (real queue, using buffer) new sequence start')
		-- 			end
		-- 			table.insert(commands, j, {isTerra = first.isTerra, id=CMD_RAW_BUILD,params = {x,y,z}, pos = {x,y,z} })

		-- 			commands_len = commands_len + 1
		-- 		end
		-- 	end
		-- end
		----------------

		commands.frame = frame
		commands.page = page


		---- count (only used in debugging) and verify duplicate
		local isDuplicate
		local count = commands.count
		for i, order in ipairs(commands) do
			count = count + 1 + 1
			order.count = count
			-- Verify Duplicate
			if order.id == id then
				if CompareLastParams(params, order.params) then
					isDuplicate = true
				end
			end
			local strID = order.id .. '-'.. table.concat(order.params,'-') 
			order.strID = strID
			commands[strID] = order
		end
		commands.count = count

		if isDuplicate then
			ReportTimeOut(unitID, commands.pingFrame * PING_TIMEOUT_MULT, id, params)
			return
		end


		----- Find insertion point
		for j = 1, commands_len do
			local command = commands[j]
			-- Echo("cmd:"..table.tostring(command))


			-- assign pos of related command to a build, the location of that build
			-- RAW_BUILD -> REPAIR -> TERRA


			local pos = command.pos
			if pos then
				px2, py2, pz2 = pos[1], pos[2], pos[3]
				local new_cur = sqrt((px2-cx)^2 + (pz2-cz)^2)
				local prev_cur = sqrt((px2-px)^2 + (pz2-pz)^2)
				command.dist = prev_cur
				local dlen = prev_new + new_cur - prev_cur
				if debugMe then
					-- Echo(
					-- 	 'REAL #' .. j .. '/' .. commands_len,(CMDNAMES[command.id]) .. ' ('..command.id..')'..' x'..command.pos[1]
					-- 	 ,'#' .. command.count
					-- 	,'dist: ' .. tostring(command.dist)
					-- 	,'dlen = prev_new '..prev_new..' + new_cur '..new_cur..' - prev_cur '..prev_cur..' = '..dlen
					-- )
				end




				-- dlen calculation to find closest insertion point


				-- dlen is the change in travel distance if the command is inserted at this position.
				if dlen < min_dlen then
					-- if option to not shift insert before a started build has been chosen
					-- if the insertion shoud be before the first command and that command is a build order
					-- if that buildorder is in range of immediate start and not at the same position of the analyzed command
					if firstFound and noInsertBeforeCurrentBuild and new_cur > 0 then
						if (isTerra) then
							local buildOrder = command.isTerra and 2 or command.id < 0 and 1 
							local immediateRange = buildOrder and buildDist and prev_cur < buildDist + (buildOrder == 2 and 100 or 0) --+ 10 -- + a little margin? with the wasp it looks like it need it
							if debugMe then
								Echo('First found','immediateRange is',immediateRange,prev_cur..'<'..buildDist..'+'..(buildOrder == 2 and 100 or 0),"buildOrder, buildDist is ", buildOrder, buildDist)
							end
							if immediateRange then
								dlen = min_dlen + 1 -- hack the dlen so the insert doesn't happen
								if debugMe then
									Echo("Build insertion is pushed after the current build")
								end
							end
						elseif command.id < 0 then
							local reachBuild
							local dist = ((command.params[1] - px)^2 + (command.params[3] - pz)^2)^0.5
							if dist <= buildDist then
								reachBuild = true
								if debugMe then
									Echo('REACHBUILD')
								end
							end
							if reachBuild then
								dlen = min_dlen + 1 -- hack the dlen so the insert doesn't happen

								if debugMe then
									Echo("Build insertion is pushed after the current build")
								end
							end
						end
					
						-- check for immediate range of the first executing command
					end
				end

				if dlen < min_dlen then
					if not isTerra and id< 0 and new_cur == 0 and command.isTerra then
						isTerra = true
					end
					insert_pos = j - 1
					new_dist = prev_new
					cur_dist = new_cur
					min_dlen = dlen
					if debugMe then
						-- Echo('new insert pos at',insert_pos,'dlen',dlen, 'isTerra ?',isTerra)
					end

				end
				px, pz = px2, pz2
				prev_new = new_cur

				firstFound = false
			else
				insert_pos = insert_pos + 1
			end
		end
	end




	-- check for insert at end of queue if its shortest walk.
	if prev_new <= min_dlen then
		insert_pos = commands_len
		new_dist = prev_new
		if debugMe then
			Echo('new insert pos at end of queue',insert_pos,'prev_new (dist)',prev_new,'min_dlen',min_dlen)
		end

	end
	----------------------
	----------------------
	-- ------- Foresee when the RAW_BUILD will be removed
	-- ------- NOT needed, RAW_BUILD should not appear
	-- if usingVirtualQueue then
	-- 	if insert_pos==0 and not useBuffer and commands[1] and commands[1].id == CMD_RAW_BUILD and not commands[1].removeAt then 
	-- 		local removeAt = frame + commands.pingFrame
	-- 		-- 1x ping to receive our new order, which will trigger a new RAW_BUILD which in turn will trigger 1x ping later the removing of that RAW_BUILD
	-- 		-- from our queue we account for only 1x ping as to foresee the removal of it to decide the insert pos
	-- 		if debugMe then
	-- 			-- Echo('removing CMD_RAW_BUILD, new order will be at 0')
	-- 			Echo('[f'..frame..']:CMD_RAW_BUILD for x' .. commands[1].pos[1] .. ' should be removed at frame ' .. removeAt .. ' ('..frame..'+'..commands.pingFrame..'), real removal at '..removeAt + commands.pingFrame)
	-- 		end
	-- 		commands[1].removeAt = removeAt
	-- 	end
	-- end
	-- --------

	-- Note that insert position 0 means first position in our queue etc
	if debugMe then
		-- local after = commands[insert_pos + 1]
		Echo('[f'..frame..']:==>> Insert '..CMDNAMES[id] .. ' ('..id..')'..' x'..cx..' with dist '..new_dist..' at '..insert_pos..' in queue of #'.. #commands .. (after and (' before order ' .. CMDNAMES[after.id].. (after.pos and ' x'..after.pos[1]) or '') or ''))
	end
	
	local pushed = commands[insert_pos + 1]
	if pushed then
		-- pushed.dist = cur_dist
		local j = 1
		if not pushed.pos then
			while pushed and not pushed.pos do -- next order is not a positional order, we look for the next(s) after
				j = j + 1
				pushed = commands[insert_pos + j]
			end
		end
		if pushed then
			if debugMe then
				-- Echo('Pushing order #' .. pushed.count .. ' ' .. (CMDNAMES[pushed.id]) ..' ('..pushed.id..')'..' x'..cx .. ' to ' .. (insert_pos + j) ..  ' with new distance ' .. cur_dist )
			end
			pushed.dist = cur_dist -- or new_cur ?

		end
	end
	-- Echo('#'.. insert_pos + 1 .. ', insert with new dist',new_dist)

	-------- debugging
	if debugMe then
		local before, after = commands[insert_pos], commands[insert_pos + 1]
		local exp_result = ''
		if not after then
			exp_result = '-> End of queue ' .. (before and 'after ' .. (CMDNAMES[before.id]) ..' x' .. tostring(before.params[1]) or '')
		elseif not before then
			exp_result = '-> Start of queue ' .. (after and 'before ' .. (CMDNAMES[after.id]) ..' x' .. tostring(after.params[1]) or '')
		else
			exp_result = '-> Between ' .. ((CMDNAMES[before.id]) ..' x' .. tostring(before.params[1])) .. ' and ' .. ((CMDNAMES[after.id]) ..' x' .. tostring(after.params[1]))
		end

		commands.expected[id..params[1]..params[3]] = {len = commands_len, result = exp_result}
	end


	-------- Finalizing

	-- Detect Sequence and postpone the order sending to avoid RAW_BUILD intrusion
	local extra = 0

	commands.count = commands.count + 1
	local command = {count = commands.count,id=id, isTerra = isTerra, inspos = insert_pos,params = params, coded = coded, dist = new_dist, pos = {cx,cy,cz} }
	table.insert(commands, insert_pos + 1, command)
	cache[id..'-'..table.concat(params,'-')] = command
	if isSequence then
		sequence[unitID] = sequence[unitID] or {}
		table.insert(sequence[unitID], command) 
	end	

	---------- Managing automated command inserted before certain command
	if insert_pos == 0 and not gamePaused and buildDist then
		local addCommand
		if id > 39000 and id < 40000 then
			addCommand = CMD_REPAIR
		elseif id < 0 then
			local isFeature = cache[params]
			if isFeature == nil then
				local sx, off = sizetable[-id], offtable[-id]
				local sz
				if off then
					if (params[4] or 1)%2 == 0 then
						sx, sz = off, sx
					else
						sz = off
					end
				else
					sz = sx
				end
				-- sx,sz = sx - 0.1, sz - 0.1

				local type, id =  spGetGroundBlocked(cx-sx, cz-sz, cx+sx, cz+sz)
				Echo(id)
				
				isFeature = type == 'feature' and id
				cache[params] = isFeature
			end
			if isFeature then
				addCommand = CMD_RECLAIM
			else
				----- not accounting for RAW_BUILD, we remove them at each insertion
				-- if not isFlyingCon and new_dist > buildDist then
				-- 	addCommand = CMD_RAW_BUILD
				-- end
				-----
			end
		end
		if addCommand then
			if debugMe then
				Echo('+ extra '.. CMDNAMES[addCommand],'isTerra?',isTerra)
			end
			commands[insert_pos + 1].dist = 0
			commands.count = commands.count + 1
			local command = {count = commands.count, id=addCommand, isTerra=isTerra, inspos = insert_pos,params = isFeature and {isFeature} or {cx,cy,cz--[[fake params we dont use them--]]}, coded = coded, dist = new_dist, pos = {cx,cy,cz} }
			cache[addCommand..'-'..table.concat(command.params,'-')] = command
			table.insert(commands, insert_pos + 1, command)
			extra = extra + 1
		end
		---------------
	end
	ReportTimeOut(unitID, commands.pingFrame * PING_TIMEOUT_MULT, id, params)

	if isSequence then
		-- to be treated the next frame or the next page, meanwhile we gather more
		return
	end

	spGiveOrderToUnit(unitID, CMD_REMOVE, CMD_RAW_BUILD, CMD_OPT_ALT)


	return insert_pos, commands, extra
end

local testopts
do
	local tested  = {}
	local rand = math.random
	testopts = function(add, tries,reset)
		if reset then
			tested = {}
		end
		tries = tries or 1
		local opts = {
			OPT_ALT 		= rand()>0.5 and CMD_OPT_ALT,
			OPT_SHIFT		= rand()>0.5 and CMD_OPT_SHIFT,
			OPT_CTRL 		= rand()>0.5 and CMD_OPT_CTRL,
			OPT_META 		= rand()>0.5 and CMD_OPT_META,
			OPT_INTERNAL 	= rand()>0.5 and CMD_OPT_INTERNAL,
			OPT_RIGHT 		= rand()>0.5 and CMD_OPT_RIGHT,
		}
		if add then
			opts[add] = CMD[add]
		end
		local coded = 0
		local dbg = ''




		for opt, num in pairs(opts) do
			if  num then
				dbg = dbg .. opt .. ', '
				coded = coded + num
			end
		end
		dbg = dbg:sub(1,-3)
		if tested[coded] and tries < 50 then
			tries = tries + 1
			return testopts(add, tries)
		end
		Echo((not tested[coded] and 'NEW ' or '') .. 'Trying Opt '..dbg .. ' CODED: '..coded.. ', (' .. tries .. ' tries )','size',table.size(tested) ..'/' .. 2^(5 + (add and 1 or 0)))
		tested[coded] = true
		return coded
	end
end

local function ProcessCommand(id, params, options, sequence_order)

	local shift = options.shift

	-- Redefine the way in which modifiers apply to Area- Repair and Rez
	local ctrl = options.ctrl
	local meta = options.meta
    if id == CMD_AREA_GUARD and not params[2] then
        id = CMD_GUARD
    end

	if ctrl and not meta and id == CMD_REPAIR then
		-- Engine CTRL means "keep repairing even when being reclaimed" (now inaccessible)
		-- Engine META means "only repair live units, don't assist construction" (now CTRL)
		spGiveOrder(id, params, options.coded - CMD_OPT_CTRL + CMD_OPT_META)
		return true
	end
	if not meta and id == CMD_RESURRECT then
		-- Engine CTRL means "keep rezzing even when being reclaimed" (now inaccessible)
		-- Engine META means "only rez fresh wrecks, don't refill partially-reclaimed" (now default, CTRL disables)
		spGiveOrder(id, params, options.coded - (ctrl and CMD_OPT_CTRL or 0) + (ctrl and 0 or CMD_OPT_META))
		return true
	end

	-- Command insert
	if meta then
		local coded = options.coded
		if id == CMD_REPAIR and ctrl then
			coded = coded - CMD_OPT_CTRL
		elseif id == CMD_RESURRECT then
			if ctrl then
				coded = coded - CMD_OPT_CTRL - CMD_OPT_META
			else
				coded = coded
			end
        -- elseif id == CMD_AREA_GUARD then

		else
			coded = coded - CMD_OPT_META
		end

		local isAreaAttack = id == CMD_ATTACK and #params == 4
		local enemies, enemyCount
		if isAreaAttack then
			enemies, enemyCount = GetEnemies(params)
			if enemyCount == 0 and params[4] > 0 then
				return true
			end
		end

		if not shift then
			if isAreaAttack then
				local units = spGetSelectedUnits()
				local done = false
				if units[1] then
					local done
					for i = 1, #units do
						local unitID = units[i]
						local _
						subjectX, _, subjectZ = spGetUnitPosition(unitID)
						done = ProcessAreaAttack(unitID, 0, EMPTY_TABLE, coded, enemies, enemyCount, params) or done
					end
				end
				if not done and params[4] == 0 then -- the area attack didnt got triggered, user didnt drag the mouse enough we insert attack on ground at point
					spGiveOrder(CMD_INSERT, {sequence_order, id, coded, unpack(params)}, CMD_OPT_ALT)
				end
				return true
			elseif id ~= CMD_AREA_MEX and id ~= CMD_AREA_TERRA_MEX then
				spGiveOrder(CMD_INSERT, {sequence_order, id, coded, unpack(params)}, CMD_OPT_ALT)
				return true
			end
		end

		local my_command = {["id"] = id, ["params"] = params}

        local cx, cy, cz = GetCommandPos(my_command)
		if not cx then
			return false
		end
		-- Insert the command at the appropriate spot in each selected units queue.
		local now = os.clock()
		for defID, units in pairs(WG.selectionDefID or spGetSelectedUnitsSorted()) do
			for _, unitID in ipairs(units) do
				if useBuffer and waitOrder[unitID] then
					buffer[unitID] = buffer[unitID] or {}
					table.insert(buffer[unitID], {id, cx, cy, cz, params, coded, isAreaAttack,enemies, enemyCount})
				else
					local insert_pos, commands = GetInsertionPoint(unitID, buildRange[defID],flyingConDefID[defID], id, cx, cy, cz, params, coded, now)
					-- note that in case of an area attack, we account for the center of the area to define where it should be inserted, no matter where the enemy are in this area
					if insert_pos then
						local done
						if isAreaAttack then -- fixing the Area Attack
							done = ProcessAreaAttack(unitID, insert_pos, commands, coded, enemies, enemyCount) 
							if not done and params[4] > 0 then -- real area attack but no enemy inside, ignoring the command
								done = true
							end
						end
						if not done then
							spGiveOrderToUnit(unitID, CMD_INSERT, {insert_pos --[[+ sequence_order--]], id, coded, unpack(params)}, CMD_OPT_ALT)
							-- if insert_pos == 0 then
							-- 	local ux, uy, uz = spGetUnitPosition(unitID)
							-- 	spGiveOrderToUnit(unitID, CMD_INSERT, {0 --[[+ sequence_order--]], CMD_RAW_MOVE, coded, ux+32,uy,uz+32}, CMD_OPT_ALT )
							-- 	insert_pos = 1
							-- end
							-- Echo("Spring.GetUnitCMdDesc is ", Spring.FindUnitCMdDesc)




							-- spGiveOrderToUnit(unitID, CMD_INSERT, {insert_pos --[[+ sequence_order--]], id, coded, unpack(params)}, CMD_OPT_ALT + 84) -- META CTRL RIGHT
							-- spGiveOrderToUnit(unitID, CMD_REMOVE, CMD.RECLAIM, CMD_OPT_ALT)
							-- spGiveOrderToUnit(unitID, CMD_REMOVE, CMD_RAW_BUILD, CMD_OPT_ALT)
							-- Echo('send command at ',frame,Spring.GetGameFrame())
						end
					end
				end
			end
		end
		return true
	end
	return false
end

local function ReleaseBuffer(unitID, buf, pendingInsert)
	local defID = spGetUnitDefID(unitID)
	buffer[unitID] = nil
	if not defID then
		return
	end
	-- Echo('buffer',#buffer)
	local now = os.clock()
	local buildRange, flyingCon = buildRange[defID],flyingConDefID[defID]
	for i, t in ipairs(buf) do
		local id, cx, cy, cz, params, coded, isAreaAttack, enemies, enemyCount = unpack(t)
		local insert_pos, commands = GetInsertionPoint(unitID, buildRange, flyingCon, id, cx, cy, cz, params, coded, now, pendingInsert)
		-- note that in case of an area attack, we account for the center of the area to define where it should be inserted, no matter where the enemy are in this area
		if insert_pos then
			local done
			if isAreaAttack then -- fixing the Area Attack
				done = ProcessAreaAttack(unitID, insert_pos, commands, coded, enemies, enemyCount) 
				if not done and params[4] > 0 then -- real area attack but no enemy inside, ignoring the command
					done = true
				end
			end
			if not done then
				spGiveOrderToUnit(unitID, CMD_INSERT, {insert_pos --[[+ sequence_order--]], id, coded, unpack(params)}, CMD.OPT_ALT)
			end
		end
	end
	buffer[unitID] = nil
end


function widget:UnitCmdDone(unitID, _, _, cmdID, cmdParams)
	-- if cmdID == CMD_RAW_MOVE --[[or cmdID == CMD_RAW_BUILD--]] then
	-- 	Echo('[f:'..frame..']:'..'order '.. cmdID ..' x'..tostring(cmdParams[1]) .. ' Done.')
	-- end
	if true then
		return
	end
	if cmdID == CMD_RAW_BUILD then -- order RAW_BUILD can be removed and put back in the same time when an insert happen (even if the inserted order is further in the queue)

		return
	end
	local queue = queues[unitID]
	if queue then
		if debugMe then
			Echo('['..frame..']:'..(CMDNAMES[cmdID]) .. ' x'..tostring(cmdParams[1]).. ' Done.')
		end
		local present = false
		for i, order in ipairs(spGetCommandQueue(unitID, 5)) do
			if order and order.id == cmdID and cmdParams[1] == order.params[1] and cmdParams[3] == order.params[3] then
				present = true
				if debugMe then
					Echo('the order has just been pushed')
				end
				break
			end
		end
		if not present then
			for i, order in ipairs(queue) do
				if order.id == cmdID and cmdParams[1] == order.params[1] and cmdParams[3] == order.params[3] then
					if debugMe then
						Echo('order removed from virtual queue')
					end
					table.remove(queue,i)
					break
				end
			end
		end
	end
end
function widget:UnitCommand(unitID, _, _, cmdID, cmdParams)
	-- if cmdID == CMD_RAW_MOVE or cmdID == CMD_RAW_BUILD or cmdID == CMD_REMOVE then
	-- 	Echo('<<<[f:'..frame..']:'..'UC RECEIVE ' .. (CMDNAMES[cmdID]) ..' ('..cmdID..') '..(not cmdParams[3] and 'p' or 'x') .. tostring(cmdParams[1]),'length of real queue '..spGetCommandQueue(unitID,0))			
	-- end

	-- if queues[unitID] then
	-- 	if cmdID == CMD_INSERT then
	-- 		local len = spGetCommandQueue(unitID,0)
	-- 		local vQueue = queues[unitID]
	-- 		local inspos = cmdParams[1]
	-- 		local expected = vQueue[inspos+1] or EMPTY_TABLE

	-- 		local x, expX = tostring(cmdParams[4]), tostring(expected.params[1])
	-- 		local z, expZ = tostring(cmdParams[6]), tostring(expected.params[3])
	-- 		Echo('len ' .. len ..' inspos',inspos,'x'..x .. ' exp'..expX,'z'.. z .. 'exp'.. expZ .. ((x~=expX or z~=expZ) and 'WRONG' or ''))
	-- 	end
	-- end
	if debugMe then
		if cmdID == CMD_INSERT then
			local queue = spGetCommandQueue(unitID,-1) or EMPTY_TABLE
			local ins = cmdParams[1]
			local cmd = cmdParams[2]
			local x,z = cmdParams[4], cmdParams[6]
			local len = #queue
			-- Echo('<<<[f:'..frame..']:'..'UC RECEIVE insertion ' .. (CMDNAMES[cmd]) ..(cmd~=CMD_REMOVE and ' x'..tostring(x) or '') ..' at ' .. ins,'length of real queue '..len)
			if ins > len or ins == -1 then
				ins = len
			end
			local declare = '<<<[f:'..frame..','..Spring.GetGameFrame()..']:'..'UC: INSERT ' .. (CMDNAMES[cmd]) ..(cmd~=CMD_REMOVE and ' x'..tostring(x) or '') ..' at ' .. ins .. ', len:' .. len
			local result
			if (cmd < 0 or positionCommand[cmd])  then
				local before, after = queue[ins], queue[ins+1]
				if not after then
					result = '-> End of queue ' .. (before and 'after ' .. (CMDNAMES[before.id]) ..' x' .. tostring(before.params[1]) or '')
				elseif not before then
					result = '-> Start of queue ' .. (after and 'before ' .. (CMDNAMES[after.id]) ..' x' .. tostring(after.params[1]) or '')
				else
					result = '-> Between ' .. ((CMDNAMES[before.id]) ..' x' .. tostring(before.params[1])) .. ' and ' .. ((CMDNAMES[after.id]) ..' x' .. tostring(after.params[1]))
					if z and z~=before.params[3] and before.params[1]==after.params[1] and before.params[3]==after.params[3] then
						declare = declare .. '\nORDER '..CMDNAMES[before.id]..' x'..x..' IS MISPLACED !'
					end

				end



				Echo(declare)
				-- Echo(result)
				if z then
					local commands = queues[unitID]
					if commands then
						local expected = commands.expected[cmd..x..z]
						if expected then
							if expected.len ~= len then
								Echo('LEN EXPECTED DIFFERS: ' ..expected.len, 'real: '..len)
							else
								Echo('len expected ' ..expected.len, 'real: '..len)
							end
							if expected.result ~= result then
								Echo('RESULT DIFFER !' ..expected.result)
							else
								Echo('OK')
							end
						end
					end
				end
			else
				Echo(declare)
			end
		else
			Echo('<<<[f:'..frame..','..Spring.GetGameFrame()..']:'..'UC RECEIVE ' .. CMDNAMES[cmdID] ..(not cmdParams[3] and ' p' or ' x') .. tostring(cmdParams[1]),'length of real queue '..spGetCommandQueue(unitID,0))			
		    if cmdID == CMD_REMOVE then

				for i,order in ipairs(spGetCommandQueue(unitID,-1) or EMPTY_TABLE) do
					if order.tag == cmdParams[1] then
						Echo('ORDER REMOVED ' .. CMDNAMES[order.id] ..' x' .. tostring(order.params[1]), 'at',i)
						if order.id ~= CMD_RAW_BUILD then
							local commands = queues[unitID]
							if commands then
								for i, command in ipairs(commands) do
									if order.id == command.id then
										local paramsA, paramsB = order.params, command.params
										if paramsA[1] == paramsB[1] and paramsA[3] == paramsB[3] then
											Echo('ORDER REMOVED FROM VIRTUAL QUEUE',order.id, 'at',i)
											table.remove(commands,i)
											break
										end
									end
								end
							end
							break
						end
					end
				end


		    end

		end
	end
    local waitFor = waitOrder[unitID]
    if not waitFor then
        return
    end
	if cmdID == CMD_INSERT then
	    -- if waitFor.id == cmdParams[2] and CompareLastParams(waitFor, cmdParams) then
	    -- 	local buf = buffer[unitID]
	    --     waitOrder[unitID], queues[unitID], timeOut[unitID] = nil, nil, nil
	    --     if buf then
	    --     	if debugMe then
	    --     	Echo('RELEASE',#buf)
	    --     	end
	    --     	ReleaseBuffer(unitID, buf, cmdParams)
	    --     end

	    --     if debugMe then
	    -- 		Echo('---- Virtual queue of '..unitID..' erased in UC ----')
	    -- 	end
	    -- elseif cmdParams[2] == CMD_RAW_BUILD then 
	    -- 	-- -- CMD_RAW_BUILD is sent when a position command is too far to be executed immediately, which when happening is inserted at position 0 before the targetted order and with same coords
	    -- 	-- local commands = queues[unitID]
	    -- 	-- local x,y,z = unpack(commands[1].params)
	    -- 	-- table.insert(commands, 1, {id=CMD_RAW_BUILD, inspos = 0,params = {x,y,z}, dist = commands[1].dist, pos = {x,y,z} })
	    -- 	-- commands[1].dist = 0
	    -- 	-- -- if debugMe then
	    -- 	-- 	Echo('CMD_RAW_BUILD has been received during our virtual queue processing !')
	    -- 	-- -- end

	    -- end
	end
end



local SortByDist
do
	local dists = {}
	local x,y,z
	local sort = function(a,b)
		if not dists[a] then
			dists[a] = ((a[5] - x)^2 + (a[7] - z)^2)^0.5
		end
		if not dists[b] then
			dists[b] = ((b[5] - x)^2 + (b[7] - z)^2)^0.5
		end
		-- Echo('A',a[5],a[7], dists[a],'B', b[5], b[7],dists[b],'closer?',dists[a] < dists[b])
		return dists[a] >= dists[b]
	end
	SortByDist = function(raw_orders, unitID)
		x,y,z = spGetUnitPosition(unitID)
		table.sort(raw_orders,sort)
		dists = {}
	end
end



local CorrectQueue = function(unitID, vQueue)

	commands = spGetCommandQueue(unitID,-1)
	local i, order = 1,commands[1]
	while order do
		if order.id == CMD_RAW_BUILD then
			spGiveOrderToUnit(unitID, CMD_REMOVE, order.tag, 0)
			table.remove(commands, i)
		else
			i = i + 1
		end
		order = commands[i]
	end

	if not commands[2] then
		return false, commands
	end

	local corrected = false
	local cx,cy,cz
	-- local isTerra = id > 39000 and id < 39000


	local firstFound
	local commands_len = QualifyCommands(commands, #commands)

	local new_dist = prev_new
	local cur_dist = 0
	-- local isTerra = id > 39000 and id < 40000 
	local firstFound = true
	local ux, uy, uz = spGetUnitPosition(unitID)
	local i, order = 1, commands[1]
	local min_dlen = 10000000
	local tries = 0
	while order do
		tries = tries + 1
		if tries == 5000 then
			Echo('TOO MANY TRIES')
			return
		end
		local px, py, pz = ux, uy, uz
		local insert_pos = i
		
		local strID = order.id .. '-' .. table.concat(order.params, '-')
		local cached = cache[strID]

		if order.pos and cached and cached.inspos then
			cx,cy,cz =  unpack(order.pos)
			local prev_new = sqrt((px-cx)^2 + (pz-cz)^2)
			------ set the min_dlen according to the current pos
			local pvx, pvy, pvz
			local pn, nc, pc = prev_new, 0, 0

			local prev = GetPositionCommand(commands, i-1, true)
			if prev then
				pvx, pvy, pvz = unpack(prev.pos)
				pn = sqrt((pvx - cx)^2 + (pvz - cz)^2)
			else
				pvx, pvy, pvz = px, py, pz
			end
			local nex = GetPositionCommand(commands, i+1)
			if nex then
				local nx, ny, nz = unpack(nex.pos)
				nc = sqrt((nx - cx)^2 + (nz - cz)^2)
				pc = sqrt((pvx - nx)^2 + (pvz - nz)^2)
			end
			min_dlen = pn + nc - pc
			-------
			if debugMe then
				Echo('Looking for better order #'..i.. ' pos',(CMDNAMES[order.id]).. ' x'..cx,'min_dlen: '..min_dlen..' ('..pn..'+'..nc..'-'..pc..')')
			end
			for j, command in ipairs(commands) do
				if i~=j  then
					if command.pos then
						local px2, py2, pz2 = unpack(command.pos)	
						local new_cur = sqrt((px2-cx)^2 + (pz2-cz)^2)
						local prev_cur = sqrt((px2-px)^2 + (pz2-pz)^2)
						-- order.dist = prev_cur
						local dlen = prev_new + new_cur - prev_cur

						-- dlen is the change in travel distance if the command is inserted at this position.
						if dlen <= min_dlen then
							-- if option to not shift insert before a started build has been chosen
							-- if the insertion shoud be before the first command and that command is a build order
							-- if that buildorder is in range of immediate start and not at the same position of the analyzed command
							-- if firstFound and noInsertBeforeCurrentBuild and new_cur > 0 then
							-- 	-- check for immediate range of the first executing command
							-- 	if (id < 0 or id > 39000 and id < 40000) then
							-- 		local buildOrder = command.isTerra and 2 or command.id < 0 and 1 
							-- 		local immediateRange = buildOrder and buildDist and prev_cur < buildDist + (buildOrder == 2 and 100 or 0) --+ 10 -- + a little margin? with the wasp it looks like it need it
							-- 		if debugMe then
							-- 			-- Echo('First found','immediateRange is',immediateRange,prev_cur..'<'..buildDist..'+'..(buildOrder == 2 and 100 or 0),"buildOrder, buildDist is ", buildOrder, buildDist)
							-- 		end
							-- 		if immediateRange then
							-- 			dlen = min_dlen + 1 -- hack the dlen so the insert doesn't happen
							-- 			if debugMe then
							-- 				-- Echo("Build insertion is pushed after the current build")
							-- 			end
							-- 		end
							-- 	end
							-- end
						end
						-- if debugMe then
						-- 	Echo('#'..j..' cmd '..command.id, px..' to '..px2.. ' =>' ..dlen,'(pn' ..prev_new ..' + nc ' .. new_cur .. ' - pc ' .. prev_cur..')', dlen<min_dlen and 'better' or '')
						-- end
						if dlen < min_dlen then
							-- if not isTerra and id< 0 and new_cur == 0 and command.isTerra then
							-- 	isTerra = true
							-- end
							insert_pos = j-1
							-- new_dist = prev_new
							-- cur_dist = new_cur
							min_dlen = dlen
							-- if debugMe then
							-- 	Echo('=>new insert pos at',insert_pos,'dlen',dlen)
							-- end
						end
						px, pz = px2, pz2
						prev_new = new_cur
					else
						insert_pos = insert_pos + 1
					end
				end
			end
			if prev_new < min_dlen then
				insert_pos = commands_len
				-- new_dist = prev_new
				-- if debugMe then
					-- Echo('new insert pos at end of queue:'.. commands_len,insert_pos,'prev_new (dist)',prev_new,'min_dlen',min_dlen)
				-- end

			end

			if insert_pos~=i then
				-- local max,min = insert_pos>i and insert_pos or i, insert_pos<i and insert_pos or i
				-- table.insert(commands, min, table.remove(commands,max))
				if not order.i then
					order.i = i
				end
				if insert_pos < i then
					insert_pos = insert_pos + 1
					table.insert(commands, insert_pos, table.remove(commands,i))
					if debugMe then
						Echo('|||||||||||||==>>Correcting order #'..i..', ' ..  CMDNAMES[order.id] .. ' x' .. cx .. ' should be at ' .. insert_pos .. '/' .. commands_len)
					end
					i = insert_pos
					-- i = 1
				else
					order.moved  = insert_pos
					table.insert(commands, insert_pos, table.remove(commands,i))
					if debugMe then
						Echo('|||||||||||||==>>Correcting order #'..i..', ' ..  CMDNAMES[order.id] .. ' x' .. cx .. ' should be at ' .. insert_pos .. '/' .. commands_len)
					end
					-- i = 1
				end
				corrected = true
			end
		end

		i = i + 1
		order = commands[i]

	end
	-- clear RAW_BUILDs before our insertions
	-- spGiveOrderToUnit(unitID,CMD_REMOVE,CMD_RAW_BUILD,CMD_OPT_ALT)

	-- for i, order in ipairs(commands) do
	-- 	if order.i and order.i~=i then
	-- 		spGiveOrderToUnit(unitID,CMD_REMOVE,order.tag,0)
	-- 		spGiveOrderToUnit(unitID,CMD_INSERT, {i-1, order.id, order.options.coded, unpack(order.params)}, CMD_OPT_ALT)
	-- 	end
	-- end
	local send, s = {{CMD_REMOVE,CMD_RAW_BUILD,CMD_OPT_ALT}}, 1
	for i, order in ipairs(commands) do
		if order.i and order.i~=i then
			s = s + 1
			send[s] = {CMD_REMOVE,order.tag,0}
			s = s + 1
			send[s] = {CMD_INSERT, {i-1, order.id, order.options.coded, unpack(order.params)}, CMD_OPT_ALT}
			-- spGiveOrderToUnit(unitID,CMD_REMOVE,order.tag,0)
			-- spGiveOrderToUnit(unitID,CMD_INSERT, {i-1, order.id, order.options.coded, unpack(order.params)}, CMD_OPT_ALT)
		end
	end
	if s > 1 then
		-- using spGiveOrderArrayToUnit make sure there will be no intrusion of RAW_BUILD order
		spGiveOrderArrayToUnit(unitID,send)
	end
	return corrected, commands
end
function widget:GamePaused(_,status)
	gamePaused = status
	if gamePaused then
		-- convert timeouts
		for unitID, timeout in pairs(timeOut) do
			timeOut[unitID] = t + (timeout-frame)/30
		end
	else
		for unitID, timeout in pairs(timeOut) do
			timeOut[unitID] = frame + (timeout-t)*30
		end
	end
end
local function ProcessSequence()
	if reorderSequence and next(reorderSequence) then
		local seq = {}
		local tmp = reorderSequence
		reorderSequence = false
		for unitID, raw_orders in pairs(tmp) do	
			if spValidUnitID(unitID) then
				SortByDist(raw_orders, unitID)
				local commands = queues[unitID]
				sequence[unitID] = sequence[unitID] or {}
				local seq = sequence[unitID]
				for i, params in ipairs(raw_orders) do
					local insert_pos,_, extra = GetInsertionPoint(unpack(params))
					if insert_pos then
						local order = commands[insert_pos+extra+1]
						table.insert(seq, order)
					end
				end
			end
		end
		reorderSequence = {}
	end
	for unitID, seq in pairs(sequence) do
		-- spGiveOrderToUnit(unitID, CMD_REMOVE, CMD_RAW_BUILD, CMD_OPT_ALT)
		local send = {{CMD_REMOVE, CMD_RAW_BUILD, CMD_OPT_ALT}}
		for i, order in ipairs(seq) do
			send[i+1] = {CMD_INSERT, {order.inspos, order.id, order.coded, unpack(order.params)}, CMD_OPT_ALT}
			-- spGiveOrderToUnit(unitID, CMD_INSERT, {order.inspos, order.id, order.coded, unpack(order.params)}, CMD_OPT_ALT)
		end
		if send[2] then
			-- Echo('SENDING #'..#send..' orders')
			-- using spGiveOrderArrayToUnit prevent from getting some unwanted RAW_BUILD between orders
			spGiveOrderArrayToUnit(unitID,send)
		end
		sequence[unitID] = nil
	end
end
function widget:GameFrame(f)
	frame = f
	ProcessSequence()
	-- if removeRB then
	-- 	Echo('remove RB at ',f,Spring.GetGameFrame())
	-- 	spGiveOrderToUnit(removeRB[2], CMD_REMOVE, CMD_RAW_BUILD, CMD_OPT_ALT)
	-- end
	-- removeRB = false
end


function widget:Update(dt)
	page = page + 1
	t = t + dt

	if gamePaused then
		ProcessSequence()
	end


	if next(timeOut) then
		local remaining = false
		for unitID, timeout in pairs(timeOut) do
			if (gamePaused and t or frame) > timeout then
				if debugMe then
					Echo('<<<<<<<< Virtual Queue of unitID ' .. unitID .. ' erased by time out in Update #' .. #queues[unitID])
				end
		        if correctAfter then
		        	local corrected, commands = CorrectQueue(unitID, queues[unitID])
		        end
		        waitOrder[unitID], queues[unitID], timeOut[unitID] = nil, nil, nil
		    	local buf = buffer[unitID]
		        if buf then
		        	if debugMe then
		        		Echo('RELEASE', #buff)
		        	end
		        	ReleaseBuffer(unitID, buf, cmdParams)
		        end
		    else
		       	remaining = true
			end
		end
		if not remaining then
			----- debugging GetCommandPosOLD caching (need to also uncomment 'debugging' in GetCommandPos())
			-- Echo('clearing cache, used',cache.used,cache.used and  (cache.usedtime/cache.used or ''))
			-- Echo('unused',cache.unused, cache.unused and (cache.unusedtime/cache.unused or ''))
			-----
			cache.clear(true)
		end
	end

end


local timer, count = 0, 0

function widget:CommandNotify(id, params, options)
	-- Echo(" is ", (CMDNAMES[id]) ..table.concat(params))
	if doNotHandleRaw[id] then
		return false
	end

	if id == CMD_STOP or not (options.shift or options.meta) then
		for i, unitID in ipairs(spGetSelectedUnits()) do
			if queues[unitID] then
				waitOrder[unitID], queues[unitID], timeOut[unitID] = nil, nil, nil
				sequence[unitID] = nil
				if reorderSequence then
					reorderSequence[unitID] = nil
				end
			end
		end
		return
	elseif id == CMD_RECLAIM and options.coded == CMD_OPT_META then
		if params[1] and not params[2] then
			local tgt = params[1]
			if spValidUnitID(tgt) then
				local tx, _, tz = spGetUnitPosition(tgt)
				if tx then
					for i, unitID in ipairs(spGetSelectedUnits()) do
						local done
						local queue = spGetCommandQueue(unitID,3)
						for i, order in ipairs(queue) do
							if order.id < 0 then
								if order.params[1] == tx and order.params[3] == tz then
									spGiveOrderToUnit(unitID, CMD_REMOVE,order.tag,0)
									done = true
								end
							end
							if done then
								break
							end
						end
					end
				end
			end
		end
	end
	if debugMe then
		local now = os.clock()
		if now - timer>2 then
			Echo('************************************************************************')
			count = 0
		end
		timer = now
		count = count + 1
		Echo('***** [f:'..frame..']:'..'[#' .. count .. ']' .. "NOTIFY " ..(CMDNAMES[id]) ..' x'.. tostring(params[1]) .. ' *****')
	end
	return ProcessCommand(id, params, options, 0)
end

local function EncodeOptions(options)
	local coded = 0
	if options.alt   then coded = coded + CMD_OPT_ALT   end
	if options.ctrl  then coded = coded + CMD_OPT_CTRL  end
	if options.meta  then coded = coded + CMD_OPT_META  end
	if options.shift then coded = coded + CMD_OPT_SHIFT end
	if options.right then coded = coded + CMD_OPT_RIGHT end
	return coded
end

CommandInsert = function(id, params, options, seq, nonInsertIfPossible) 
	options.coded = (options.coded or EncodeOptions(options))
	seq = seq or 0
	if debugMe then
		local now = os.clock()
		if now - timer>2 then
			Echo('************************************************************************')
			timer = now
			count = 0
		end
		count = count + 1
		Echo('[up'..page..'f:'..frame..']:'..'>>>>>[#' .. count .. ']' .. "WG.CommandInsert called ", (CMDNAMES[id]) ..' ('..id..')', params[1] .. '<<<<<')
	end
	if ProcessCommand(id, params, options, seq) then
		return
	end

	if not options.shift then
		if seq == 0 then
			-- ProcessCommand ensures that META is also false at this point
			spGiveOrder (id, params, options.coded)
			return
		end

		-- Technically a SHIFT is not needed, but if you try to copy a queue with a shiftless
		-- order in it verbatim (i.e. without appending missing SHIFT manually) it will erase
		-- anything before it; as far as I can tell some other gadgets/widgets behave that way.
		-- At some point it would be good to fix them (TODO) but until then here's a workaround.
		options.shift = true
		options.coded = options.coded + CMD_OPT_SHIFT
	end

	local units = spGetSelectedUnits()
	for i = 1, #units do
		local unitID = units[i]
		local commands = spGetCommandQueue(unitID, 0)
		if commands then
			if nonInsertIfPossible then
				spGiveOrderToUnit(unitID, id, params, options.coded)
			else
				spGiveOrderToUnit(unitID, CMD_INSERT, {commands + seq, id, options.coded, unpack(params)}, CMD_OPT_ALT)
			end
		end
	end
end

local function DebugDrawCommands(commands,virtual,ux, uy, uz)
    local uniquePoses = {}
    local lasx, lasy, lasz = ux,uy,uz

    local i = 1
    local order = commands[i]
    while order do
    	if order.id == CMD_RAW_BUILD and order.removeAt and frame >= order.removeAt then
    		local j, new = i+1, commands[i+1]
    		while nex and not nex.pos do
    			j = j+1
    			nex = commands[j]
    		end
    		if nex then
    			nex.dist = order.dist
    		end
    		table.remove(commands,i)
    	else
    		i = i + 1
    	end
    	order = commands[i]
    end


	for i, order in ipairs(commands) do
		local px, py, pz
		if not virtual then
			px, py, pz = GetCommandPos(order)

		elseif order.pos then
			px, py, pz = unpack(order.pos)
		end

		if not px then
			px, py, pz = lasx, lasy, lasz
		end
		uniquePoses[px] = uniquePoses[px] or {}
		local commandStr = uniquePoses[px][pz]
		local ordername = (CMDNAMES[order.id]) ..' ('..order.id..')'
		if commandStr then
			commandStr.i = commandStr.i .. '&' .. tostring(i)
			table.insert(commandStr.orders, '&'..ordername)
			if virtual then
				commandStr.inspos = commandStr.inspos ..'&'..(order.inspos and order.inspos or 'noIns')
				commandStr.id = commandStr.id ..'&' .. order.count
				local dist = order.dist
				if dist ~= 0 then
					if type(dist)=='number' then
						dist = ('%.1f'):format(dist)
					end
					commandStr.dist = commandStr.dist .. '&wrong '..tostring(dist)
				end
				commandStr.terra = commandStr.terra .. (order.isTerra and '&t' or '&-')
			end
		else
			local dist = order.dist
			if type(dist)=='number' then
				dist = ('%.1f'):format(dist)
			end
			commandStr = {
				terra = 'terra:'..(order.isTerra and 't' or '-'),
				y = py,
				i = tostring(i),
				id = virtual and ('#' .. order.count) or nil,
				inspos = virtual and (order.inspos and 'ins'..order.inspos or 'noIns') or nil,
				dist = virtual and (dist and 'd:' ..tostring(dist) or 'nodist') or 'd:'..((px-lasx)^2 + (pz-lasz)^2)^0.5,
				orders = {ordername ..' x' .. px .. ' z' .. pz},
			}
			uniquePoses[px][pz] = commandStr
		end
		lasx, lasy, lasz = px, py, pz
	end
	for x,t in pairs(uniquePoses) do
		for z, commandStr in pairs(t) do
	        gl.PushMatrix()
	        gl.Translate(x,commandStr.y,z)
	        gl.Billboard()
	        if virtual then
				gl.Text(commandStr.inspos , 	 15,      -10, 10,'h')
        		gl.Text(commandStr.i , 			 15,        0, 10,'h')
        		gl.Text('id:'..commandStr.id , 	 15,       10, 10,'h')
				gl.Text(commandStr.dist , 		 15,       20, 10,'h')
				gl.Text(commandStr.terra , 		 15,       30, 10,'h')
				for i,orderstr in ipairs(commandStr.orders) do
					gl.Text(orderstr,			-10,  30+10*i, 10,'h')
				end

			else
				gl.Text(commandStr.i , 			 15,      -20, 10,'h')
				gl.Text(commandStr.dist , 		 15,      -30, 10,'h')
				for i,orderstr in ipairs(commandStr.orders) do
					gl.Text(orderstr,			-10, -30-10*i, 10,'h')
				end
			end

	        
	        gl.PopMatrix()

		end
	end
end
local current

function widget:DrawWorld()
	if not (debugMe or debugDraw) then
		return
	end
    local unitID, commands = next(queues)
    if not debugDraw then
    	if commands then
    		current = commands
    	end
    	return
    end
    if commands then
    	gl.Color(1,1,0,1)	--a more colored yellow when we rely on our queue system, (aka before receiving the last order)
    elseif current then
    	commands = current
    	unitID = commands.unitID
    	gl.Color(1,1,0.5,1)
    else
    	return
    end
    if not spValidUnitID(unitID) then
    	return
    end
    current = commands

    local ux,uy,uz = spGetUnitPosition(unitID)

    DebugDrawCommands(commands, true, ux, uy, uz)
    gl.Color(0,0.5,1,1)
	-- let's compare with the real current command queue
    DebugDrawCommands(spGetCommandQueue(unitID,-1) or EMPTY_TABLE, false, ux, uy, uz)

	gl.Color(1,1,1,1)
end


function widget:UnitDestroyed(unitID)
	if waitOrder[unitID] then
		waitOrder[unitID], queues[unitID], timeOut[unitID] = nil, nil ,nil
	end
end


function widget:Initialize()
	SwitchToOld(false)
end
function widget:Shutdown()
	pcall(SwitchToOld, true, function() Spring.Echo('FAILED TO RELOAD OLD COMMAND INSERT') end)
end
