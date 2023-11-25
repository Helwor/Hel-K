
function widget:GetInfo()
	return {
		name = "Go Rearm On New Pad",
		desc = "Trigger a refresh on bomber behaviour to go rearm when a new pad is just built.",
		author = "Helwor",
		date = "October 2023",
		license = "GNU GPL, v2 or v3",
		layer = -10.5, 
		enabled = true,
		handler = true,
	}
end
local Echo = Spring.Echo

-- Default values before user start touching the options
local active = true
local includeAlly = true
local includeReef = true
local maxDistance = 4500
--

local debugMe = false

local indexedBomberDefID = {}
local bomberDefID = {}
for defID, def in pairs(UnitDefs) do
	if def.isBomber or def.customParams.reallyabomber or def.isBomberAirUnit  then
		-- Echo("def.name is ", def.name, def.isBomber and 'isBomber' or def.isBomberAirUnit and 'isBomberAirUnit' or def.customParams.reallyabomber and 'reallyabomber')
		table.insert(indexedBomberDefID, defID)
		bomberDefID[defID] = true
	end
end


-- more reliable for the future o_o
local allowedPad = VFS.Include("LuaRules/Configs/airpad_defs.lua", nil, VFS.GAME)
local reefDefID = -1
for defID in pairs(allowedPad) do
	if UnitDefs[defID].name == 'shipcarrier' then
		reefDefID = defID
		allowedPad[defID] = includeReef
	else
		allowedPad[defID] = true
	end
end

---- old
-- local airpadDefID       = UnitDefNames.staticrearm.id
-- local airFactoryDefID   = UnitDefNames.factoryplane.id
-- local reefDefID			= UnitDefNames.shipcarrier.id

-- local allowedPad = {
-- 	[airpadDefID]       = true,
-- 	[airFactoryDefID]   = true,
-- 	[reefDefID]			= includeReef,
-- }
-----


options_path ='Hel-K/Go Rearm on new Pad'
options_order = {'desc1','desc2','desc3','active','allypad','includereef','maxdist'}
options = {}
options.desc1 = {
	value = "Renewing bomber's order to go find a pad,",
	type = 'label',
}
options.desc2 = {
	 value = 'when a pad has been finished building.',
	 type = 'label',
}
options.desc3 = {
	value = 'Unstucking them eventually from busy pad.',
	type = 'label',
}
options.active = {
	name = 'Enabled',
	type = 'bool',
	value = active,
	OnChange = function(self)
		active = self.value
		if active then
			for k,v in pairs(widget) do
				if widgetHandler[k .. 'List'] then
					widgetHandler:UpdateWidgetCallIn(k, widget)
				end
			end
			widget:PlayerChanged()
		else
			for k,v in pairs(widget) do
				if widgetHandler[k .. 'List'] then
					widgetHandler:RemoveWidgetCallIn(k, widget)
				end
			end
		end
	end,
}
options.allypad = {
	name = 'Include Ally Pad',
	type = 'bool',
	value = includeAlly,
	OnChange = function(self)
		includeAlly = self.value
	end,
}
options.includereef = {
	name = 'Include Reefs',
	type = 'bool',
	value = includeReef,
	OnChange = function(self)
		includeReef = self.value
		allowedPad[reefDefID] = includeReef
	end,
}
options.maxdist = {
	name = 'Max Distance',
	desc = "Don't trigger a new rearm if the new pad built is beyond that distance from the current pad,"
	.."\n unless the bomber itself is close enough of it (half of that distance)",
	type = 'number',
	min  = 300,
	max  = 60000,
	step = 100,
	value = maxDistance,
	OnChange = function(self)
		maxDistance = self.value
	end,
}

local spGetMyTeamID = Spring.GetMyTeamID
local spGetUnitDefID = Spring.GetUnitDefID

local spGetCommandQueue = Spring.GetCommandQueue
-- local spGetUnitCurrentCommand = Spring.GetUnitCurrentCommand
-- local spGiveOrder = Spring.GiveOrder
local spGiveOrderToUnit = Spring.GiveOrderToUnit
local spGetUnitPosition = Spring.GetUnitPosition
local spGetTeamUnits = Spring.GetTeamUnits
local spGetTeamUnitsByDefs = Spring.GetTeamUnitsByDefs
local spGiveOrderArrayToUnit = Spring.GiveOrderArrayToUnit
local spAreTeamsAllied = Spring.AreTeamsAllied
local spGetUnitRulesParam = Spring.GetUnitRulesParam
local spGetUnitIsDead = Spring.GetUnitIsDead
local spGetUnitDefID = Spring.GetUnitDefID


local myTeamID = spGetMyTeamID()

local customCmds                = VFS.Include("LuaRules/Configs/customcmds.lua")
local CMD_REARM                 = customCmds.REARM    -- 33410
local CMD_RAW_MOVE				= customCmds.RAW_MOVE
local CMD_FIND_PAD				= customCmds.FIND_PAD -- FIND_PAD is capricious and cannot be inserted before unit orders

customCmds = nil


local EMPTY_TABLE = {}

local CMD_STOP = CMD.STOP
local CMD_INSERT = CMD.INSERT
local CMD_REMOVE = CMD.REMOVE

local CMD_OPT_SHIFT = CMD.OPT_SHIFT
local CMD_OPT_ALT = CMD.OPT_ALT
local CMD_OPT_INTERNAL = CMD.OPT_INTERNAL


local toSend = {}
local toProcess = {}

---------- debugging
-- local function ReadOpts(opts)
-- 	if tonumber(opts) then
-- 		return 'coded: ' .. opts
-- 	end
-- 	local str = ''
-- 	for k,v in pairs(opts) do
-- 		if v then
-- 			str = str .. k .. ': '.. tostring(v) .. ', '
-- 		end
-- 	end
-- 	return str:sub(1,-3)
-- end
-- 
-- function widget:CommandNotify(cmd,params,opts)
-- 	Echo("CN is ", cmd,'params',params[1],unpack(params))
-- 	Echo('CN opts',ReadOpts(opts))
-- end
-- 
-- function widget:UnitCommand(id,_,_,cmd, params,opts)
-- 	if id == 5860 then
-- 		if cmd == CMD_INSERT then
-- 			Echo('UC receive Insert', params[2], 'at ', params[1],'params',select(4,unpack(params)))
-- 			Echo('UC opts',readOpts(opts))
-- 		else
-- 			Echo('UC receive',cmd,'params',unpack(params))
-- 			Echo('UC opts',readOpts(opts))
-- 		end
-- 	end
-- end
----------


function widget:PlayerChanged()
	myTeamID = spGetMyTeamID()
end

function widget:UnitCommand(id,defID,team,cmd,params)
	if cmd == 1 then
		cmd = params[2]
		-- params = {select(4,unpack(params))}
	end
	if cmd == CMD_REARM then
		local noammo = spGetUnitRulesParam(id,'noammo')
		if noammo ~= 1 then
			Echo(id, UnitDefs[defID].name,'noammo is ' .. tostring(noammo) .. '!')
		end
	end
	
end

local function RemoveAllRearms(bomberID, queue)
	local i, order = 1, queue[1]
	while order do
		if order.id == CMD_REARM or order.id == CMD_FIND_PAD then
			spGiveOrderToUnit(CMD_REMOVE, order.tag,0)
			table.remove(queue,i)
		else
			i = i + 1
		end
		order = queue[i]
	end
end
local function Process(bomberID, newPadID, nx,ny,nz)
	local queue = spGetCommandQueue(bomberID,-1)
	local first = queue[1]
	if not first then
		return
	end

	if first.id == CMD_REARM then
		
		-- IDEA: the reservation bug may be caused by an order given when noammo is 1 and received when noammo is 2 (about to land)
		if spGetUnitRulesParam(bomberID,'noammo') == 1 then -- 1 is when bomber is going to rearm and not yet gonna land on the pad
			----- debugging
			-- local reserve = spGetUnitRulesParam(bomberID, "airpadReservation")
			-- local padTgt = first.params[1]
			-- Echo('bomber #'..bomberID..' '.. UnitDefs[spGetUnitDefID(bomberID)].name .. ', reserve?:'..tostring(reserve) .. ', pad ' ..UnitDefs[spGetUnitDefID(padTgt)].name.. '#'..padTgt)
			-- if reserve == 0 then
			-- 	Echo('bomber ' .. bomberID .. ' HAS NO RESERVATION!')
			-- 	return
			-- end
			-- if padTgt == newPadID then
			-- 	Echo('THE TARGET PAD IS ALREADY THE NEW PAD !!')
			-- 	return
			-- end
			-----
			-------- verify we're not too far

			local bx,_,bz,_,by = spGetUnitPosition(bomberID, true)
			local curPadID = not first.params[2] and first.params[1] -- failsafe, can REARM order be area order or missing params ?
			local distFromCurPad
			if curPadID then
				local px, py, pz = spGetUnitPosition(curPadID)
				if px then
					distFromCurPad = ((px - nx)^2 + (py - ny)^2 + (pz - nz)^2)^0.5
				end
			end
			local distFromBomber = ((bx - nx)^2 + (by - ny)^2 + (bz - nz)^2)^0.5

			local valid = false
			if not distFromCurPad then
				-- Default to the dist of the bomber (in case we don't know where the bomber is currently rearming to)
				valid = distFromBomber <= maxDistance
			else
				-- else check if too far, in that case we check if the bomber itself is closeby the new pad (half of the maxDistance).
				if distFromCurPad < 100 then
					Echo('bobmer '..bomberID..' is close to land')
				end
				if distFromCurPad > maxDistance then
					valid = distFromBomber <= maxDistance/2
				else
					valid = true
				end
			end
			-- Echo("maxDistance", maxDistance, distFromCurPad", distFromCurPad,"distFromBomber",  distFromBomber,'valid?',valid)
			--------
			if valid then
				-- unit_bomber_command.lua has a reservation bug when pad get (reclaimed fast or destroyed? and a CMD_FIND_PAD is triggered at this moment?)
				-- spGiveOrderToUnit(bomberID,CMD_REMOVE, first.tag, CMD_OPT_INTERNAL) -- 
				-- RemoveAllRearms(bomberID,queue)
				-- spGiveOrderToUnit(bomberID, CMD_STOP, 0, CMD_OPT_INTERNAL)
				spGiveOrderToUnit(bomberID, CMD_STOP, 0, 0)
				spGiveOrderToUnit(bomberID, CMD_FIND_PAD, EMPTY_TABLE, CMD_OPT_INTERNAL)
				-- Echo('unit #'..bomberID..', '..UnitDefs[spGetUnitDefID(bomberID)].name, 'reammo progress', spGetUnitRulesParam(bomberID, "reammoProgress"))
				if true then
					return
				end
				if not queue[2] then
					return
				end
				-- copy the rest of the queue to be reinserted
				local inserts = {}
				local off = 0
				local len = #queue
				for i=2, #queue do
					local order = queue[i]
					-- if order.id == CMD_REARM --[[or order.id == CMD_FIND_PAD--]] then
						Echo('unit #'..bomberID..', '..UnitDefs[spGetUnitDefID(bomberID)].name..' got cmd '.. order.id .. ' at '.. i ..'/'..len..' !')
					-- 	off = off - 1
					-- else
					-- 	inserts[i+off-1] = {CMD_INSERT, {i+off-1, order.id, order.options.coded, unpack(order.params)}, CMD_OPT_ALT}
					-- end
					inserts[i+off-1] = {CMD_INSERT, {i+off-1, order.id, order.options.coded, unpack(order.params)}, CMD_OPT_ALT}
					-- inserts[i-1] = {order.id, order.params, order.options.coded}
				end
				------- 
				-- local removes = {}
				-- for i=2, #queue do
				-- 	local order = queue[i]
				-- 	removes[i-1] = {CMD_REMOVE, order.tag, 0}
				-- end
				-- spGiveOrderArrayToUnit(bomberID, removes)
				-------
				spGiveOrderArrayToUnit(bomberID, inserts)
				return inserts
			end

		end
	end
end

---------- debugging
if debugMe then
	local spGetSelectedUnits = Spring.GetSelectedUnits
	local str = ''
	function widget:Update()
		local id = spGetSelectedUnits()[1]
		if not id then
			return
		end
		local defID = spGetUnitDefID(id)
		local bomberID = bomberDefID[defID] and id
		local newstr
		if bomberID then
			newstr = 'bomber #'..bomberID ..','..'reservation'..','..tostring(spGetUnitRulesParam(bomberID, "airpadReservation") or 'nil')..','..'noammo'..','..tostring(spGetUnitRulesParam(bomberID,'noammo') or 'nil')
		else
			local padID = allowedPad[defID] and id
			if padID then
				newstr = 'pad #'..padID ..','..'free room: '..tostring(spGetUnitRulesParam(padID,"unreservedPad") or 'nil')
			end
		end
		if newstr and newstr ~= str then
			str = newstr
			Echo(newstr)
		end
	end
end
-----------


function widget:UnitFinished(unitID, defID, teamID)
	if allowedPad[defID] then
		if teamID == myTeamID or includeAlly and spAreTeamsAllied(teamID, myTeamID) then
			if not spGetUnitIsDead(unitID) then -- can rarely happen
				local nx, ny, nz = spGetUnitPosition(unitID)
				-- Echo('newPadID is '..UnitDefs[defID].name .. ' #' .. unitID)
				for _, bomberID in ipairs(spGetTeamUnitsByDefs(myTeamID, indexedBomberDefID)) do
					Process(bomberID, unitID, nx,ny,nz)
					-- waiting one frame is mandatory to avoid reservation bug occuring often (pad reserving but bomber will never land on it)
					-- toSend[unitID] = Process(bomberID, unitID, nx,ny,nz)
					-- wait = 20
					-- toProcess[bomberID] = {unitID, nx,ny,nz}
				end
			end

		end
	end
end

widget.UnitGiven = widget.UnitFinished


function widget:Initialize()
	if Spring.IsReplay() or Spring.GetSpectatingState() then
		widgetHandler:RemoveWidget(widget)
		return
	end
	widget:PlayerChanged()
end
