
function widget:GetInfo()
	return {
		name      = "FixAutoGuard",
		desc      = "Remove autoguard when user issue a manual order meanwhile server delay",
		author    = "Helwor",
		date      = "Oct 2023",
		license   = "GNU GPL, v2 or v3",
		layer     = -10, -- Before NoDuplicateOrders
		enabled   = true
	}
end
local Echo = Spring.Echo

local debugCheck = 30 * 60 * 5 -- check if all good every 5 minutes 

-- local debugMe = true


local debug = debugMe and Echo or function() end


---------- sequence
-- unit created
-- (might have sent manual shift order) -- note it
-- [update 1]unit finished
-- [update 1]receive autoguard orders
-- [update 1]unit from factory -> set timeout
-- [update 2]unit receive again autoguard orders
-- (might have  sent manual shift order) ||
-- [update 4] time out check if user sent a manual order and then remove autoguard





-- local removableCommand = {
-- 	[CMD.GUARD] = true,
-- 	[CMD.PATROL] = true,
-- 	[CMD_ORBIT] = true,
-- 	[CMD_AREA_GUARD] = true,
-- }

local indexedBuilderDefID = {}
local builderDefID, facDefID = {}, {}
for defID, def in pairs(UnitDefs) do
	if def.isFactory then
		facDefID[defID] = true
    elseif def.isBuilder and def.canAssist then
        builderDefID[defID] = true
        table.insert(indexedBuilderDefID, defID)
    end
end


local CMD_GUARD = CMD.GUARD
local CMD_REMOVE = CMD.REMOVE

local spGetMyTeamID = Spring.GetMyTeamID
local spGetUnitDefID = Spring.GetUnitDefID
local spGetSelectedUnitsSorted = Spring.GetSelectedUnitsSorted
local spGetUnitRulesParam = Spring.GetUnitRulesParam
local spGetCommandQueue = Spring.GetCommandQueue
local spGiveOrderToUnit = Spring.GiveOrderToUnit

local builderSelected = false
local myUnits, verify = {}, {}
local page, frame = 0, Spring.GetGameFrame()
local time = 0

local myTeamID = spGetMyTeamID()


local gamePaused

local Getping
do
	local ping = 0.233
	local spGetPlayerInfo = Spring.GetPlayerInfo
	GetPing = function()
		local pingNow
		local askedPingF = -100
		if gamePaused then
			pingNow = ping
		elseif askedPingF + 30 < frame then
		 	pingNow = select(6,spGetPlayerInfo(myTeamID, true))
		 	ping = pingNow
		 	askedPingF = frame
		else
		 	pingNow = ping
		end
		return pingNow
	end
end


function widget:GamePaused(_,status)
	gamePaused = status
end

function widget:GameFrame(f)
	frame = f
	if debugCheck and f%debugCheck == 0 then
		Echo('periodical check if tables are empty ',table.size(myUnits),table.size(verify))
	end
end
function widget:PlayerChanged()
	myTeamID = spGetMyTeamID()
end
function widget:CommandsChanged()
	builderSelected = false
	for defID, t in pairs(WG.selectionDefID or spGetSelectedUnitsSorted()) do
		if builderDefID[defID] then
			for i, id in ipairs(t) do
				local subject = myUnits[id]
				if subject then
					builderSelected = builderSelected or {}
					builderSelected[id] = true
				end
			end
		end
	end
end
function widget:Initialize()
	if Spring.IsReplay() or Spring.GetSpectatingState() then
		widgetHandler:RemoveWidget(widget)
		return
	end
	widget:GamePaused(select(3,Spring.GetGameSpeed()))
	widget:PlayerChanged()
	for i, id in ipairs(Spring.GetTeamUnitsByDefs(myTeamID, indexedBuilderDefID)) do
		local facID = spGetUnitRulesParam(id, "parentFactory")
		if facID then
			local defID = spGetUnitDefID(id)
			widget:UnitCreated(id, defID, myTeamID, facID)
		end
	end
	indexedBuilderDefID = nil
	widget:CommandsChanged()
end
function widget:UnitCreated(id, defID, team, builderID)
	if team == myTeamID then
		if builderDefID[defID] and builderID and facDefID[spGetUnitDefID(builderID)] then
			myUnits[id] = true
		end
	end
end

local function RemoveAutoGuard(id)
	local queue = spGetCommandQueue(id,4)
	local remove
	for i=#queue, 1, -1 do
		local order = queue[i]
		-- debug("order.id is ", order.id,'at',i)
		if order.id == CMD_GUARD then
			remove = true
		end
		if remove then
			spGiveOrderToUnit(id, CMD_REMOVE, order.tag, 0)
			-- debug('removing '.. order.id .. ' at '..i)
		end
	end
	if remove then
		-- debug('['..time..'page: '..page..']'..'autoguard removal sent for unit #'..id)
		-- Echo('['..time..'page: '..page..']'..'autoguard removal sent for unit #'..id)
		debug('['..time..'page: '..page..']'..'autoguard removal sent for unit #'..id)
		-- verifRemove[id] = GetPing() + time
	else
		-- Echo('['..time..'page: '..page..']'..'no guard order found')
		debug('['..time..'page: '..page..']'..'no guard order found')
	end
end


function widget:Update(t)
	page = page + 1
	time = time + t
	for id, timeout in pairs(verify) do
		-- timeout = timeout - 1
		if timeout == page then

		-- if time >= timeout then
			-- debug('['..time..'page: '..page..']'..'unit #'..id..' timed out, unit is manual ?',myUnits[id])
			-- Echo('['..time..'page: '..page..']'..'unit #'..id..' timed out, unit is manual ?',myUnits[id])
			if myUnits[id] == 'manual' then
				debug('remove auto guard')
				RemoveAutoGuard(id)
			end
			verify[id] = nil
			myUnits[id] = nil
		else
			debug('[page: '..page..']'..'unit #'..id..' not timed out yet')
		end


		-- else
		-- 	verify[id] = timeout
		-- end

	end

end

function widget:UnitCommand(id, defID, teamID, cmd, params, opts, playerID,  tag, fromSynced, fromLua)
	if myUnits[id] then
		if cmd == CMD_GUARD then
			debug('['..time..'page: '..page..']'..'unit #'.. id .. ' received guard order')
			-- Echo('['..time..'page: '..page..']'..'unit #'.. id .. ' received guard order')
		elseif cmd~=2 then
			debug('['..time..'page: '..page..']'..'unit #'.. id .. ' received '.. cmd)
		end
	end
end
function widget:CommandNotify(id, params, opts)
	if builderSelected then
		if not opts.shift then -- the autoguard will already be cancelled because of that non shift order
			for id in pairs(builderSelected) do
				myUnits[id] = nil
				verify[id] = nil
			end
			builderSelected = false
			-- debug('['..time..'page: '..page..']'..'CN, the order is not a shift order....')
			return
		end
		
		for id in pairs(builderSelected) do
			if myUnits[id] then
				myUnits[id] = 'manual'
				if verify[id] then
					-- local responseTime = GetPing() + time  -- push timeout
					-- debug('['..time..'page: '..page..']'..'CN, the unit #'.. id .. ' is already out of factory pushing timeout to '.. responseTime)
					-- verify[id] = responseTime
					debug('['..time..'page: '..page..']'..'CN, the unit #'.. id .. ' is already out of factory keeping timeout to '.. verify[id])
				else
					debug('['..time..'page: '..page..']'..'CN, the unit is not out of factory yet')
				end
			else
				debug('['..time..'page: '..page..']'..'CN, the unit #' .. id .. ' has timed out')
				builderSelected[id] = nil
			end

		end
	-- else
	-- 	debug('CN, no builder selected...')
	end
end

function widget:UnitFromFactory(id, defID, team, factID, factDefID, userOrders)
	local unit = myUnits[id]
	if not unit then
		return
	end
	if userOrders then -- already processed by other means
		myUnits[id] = nil
		return
	end
	local autoguard
	for i, order in ipairs(spGetCommandQueue(id,3)) do
		if order.id == CMD_GUARD then
			autoguard = true
			break
		end
	end
	if not autoguard then -- nothing to do
		myUnits[id] = nil
		return
	end
	-- local responseTime = GetPing() + time 
	-- verify[id] = responseTime
	-- debug('['..time..'page: '..page..']'..'unit from fac #'.. id .. ', timeout set to ' .. responseTime)
	verify[id] = page + 3
	debug('['..time..'page: '..page..']'..'unit from fac #'.. id .. ', timeout set to page' .. page + 3)
end

function widget:UnitFinished(id, defID, team)
	if team == myTeamID  and myUnits[id] then
		debug('['..time..'page: '..page..']'..'unit finished #'.. id)
	end
end

function widget:UnitDestroyed(id, defID, team)
	if team == myTeamID  and myUnits[id] then
		myUnits[id] = nil
		verify[id] = nil
	end
end

-- function widget:KeyPress(key, mods, isRepeat)
-- 	if not isRepeat and  mods.ctrl and key == 109 then-- CTRL + M
-- 		local id = Spring.GetSelectedUnits()[1]
-- 		if id then
-- 			for i, order in ipairs(spGetCommandQueue(id,-1)) do
-- 				debug(i,order.id)
-- 			end
-- 		end
-- 	end
-- end