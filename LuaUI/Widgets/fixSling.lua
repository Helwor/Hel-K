
function widget:GetInfo()
	return {
		name      = "FixSling",
		desc      = "Remove Bad target for Slings",
		author    = "Helwor",
		date      = "Oct 2023",
		license   = "GNU GPL, v2 or v3",
		layer     = -10, -- Before NoDuplicateOrders
		enabled   = true
	}
end
local Echo = Spring.Echo


-- local debugMe = true
local MAX_SEND = 50 -- max orders to send per update round
local MAX_ORDER_CHECK = 25 -- max orders to check per update round
local debug = debugMe and Echo or function() end



local artyDefID = {}
for defID, def in pairs(UnitDefs) do
	if def.name == 'cloakarty' then
		artyDefID[defID] = true
	end
end

local CMD_ATTACK = CMD.ATTACK
local CMD_REMOVE = CMD.REMOVE

local spGetMyTeamID = Spring.GetMyTeamID
local spGetUnitDefID = Spring.GetUnitDefID
local spGetSelectedUnitsSorted = Spring.GetSelectedUnitsSorted
local spGetUnitRulesParam = Spring.GetUnitRulesParam
local spGetCommandQueue = Spring.GetCommandQueue
local spGiveOrderToUnit = Spring.GiveOrderToUnit
local spValidUnitID = Spring.ValidUnitID

local artySelected, copyArtySelected
local myUnits, verify = {}, {}
local page, frame = 0, Spring.GetGameFrame()
local time = 0

local myTeamID = spGetMyTeamID()
local idWaitOrder
local toTreat, toOrder = {}, {}
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

local function deepcopy(t)
	local copy = {}
	for k,v in pairs(t) do
		if type(v) == 'table' then
			copy[k] = deepcopy(v)
		else
			copy[k] = v
		end
	end
	return copy
end

function widget:GamePaused(_,status)
	gamePaused = status
end


function widget:PlayerChanged()
	myTeamID = spGetMyTeamID()
end
function widget:Initialize()
	if Spring.IsReplay() or Spring.GetSpectatingState() then
		widgetHandler:RemoveWidget(widget)
		return
	end
	widget:CommandsChanged()
end

local function Treat()
	local total = 0
	for myUnits in pairs(toTreat) do
		local bads = {}
		for defID, units in pairs(myUnits) do
			local u_len = #units
			for i=u_len, 1, -1 do
				local id = units[i]
				local toRemove,n = {}, 0
				local queue = spGetCommandQueue(id, -1)
				local len = #queue
				total = total + len
				local targets = 0
				if queue then
					for _, order in ipairs(queue) do
						if order.id == CMD_ATTACK and not order.params[2] then
							targets = targets + 1
							local tgt = order.params[1]
							-- Echo("Units[tgt] is ", WG.Cam.Units[tgt])
							-- local unit = Units[tgt]
							-- if unit then
							-- 	for k,v in pairs(unit) do
							-- 		Echo(k,v)
							-- 	end
							-- end
							local isBad = bads[tgt]
							if isBad then
								n = n + 1
								toRemove[n] = order.tag
								-- spGiveOrderToUnit(id, CMD_REMOVE, order.tag, 0)

							elseif isBad == nil then
								local enemy = Units[tgt]
								if not (enemy and enemy.isStructure) then
									bads[tgt] = true
									n = n + 1
									toRemove[n] = order.tag
									-- spGiveOrderToUnit(id, CMD_REMOVE, order.tag, 0)
								else
									bads[tgt] = false
								end
							end
						end
					end
				end
				if targets == n then
					return -- there is no structure in the enemy targets pool
				end
					-- spGiveOrderToUnit(id, CMD_REMOVE, toRemove, 0)
				toOrder[id] = toRemove
				units[i] = nil
				if total > MAX_ORDER_CHECK then
					return
				end
			end
			myUnits[defID] = nil
		end
		toTreat[myUnits] = nil
	end
end

function widget:Update(t)
	if next(toTreat) then
		Treat()
	end
	if next(toOrder) then
		local maxPerUnit = math.ceil(MAX_SEND / table.size(toOrder))
		for id, toRemove in pairs(toOrder) do
			if not spValidUnitID(id) then
				toOrder[id] = nil
			else
				if toRemove[maxPerUnit+1] then
					rest = {}
					for i = maxPerUnit+1, #toRemove do
						rest[i-maxPerUnit], toRemove[i] = toRemove[i], nil
					end
					toOrder[id] = rest
				else
					toOrder[id] = nil
				end
				
				spGiveOrderToUnit(id, CMD_REMOVE, toRemove, 0)
			end
		end
	end
end
function widget:CommandsChanged()
	artySelected, copyArtySelected = false, false
	for defID, units in pairs(WG.selectionDefID or spGetSelectedUnitsSorted()) do
		if artyDefID[defID] then
			artySelected = artySelected or {}
			table.insert(artySelected, units)
			-- Echo("CC, 'artySelected[1] is ", artySelected[1][1])
		end
	end
end


local function ReadOpts(opts)
	if tonumber(opts) then
		return 'coded: ' .. opts
	end
	local str = ''
	for k,v in pairs(opts) do
		if v then
			str = str .. k .. ': '.. tostring(v) .. ', '
		end
	end
	return str:sub(1,-3)
end


function widget:UnitCommand(id, defID, teamID, cmd, params, opts, playerID,  tag, fromSynced, fromLua)
	-- Echo(id,'cmd',cmd,'opts',ReadOpts(opts),'p',unpack(params))
	if idWaitOrder == id then
		if copyArtySelected then
			toTreat[copyArtySelected] = true
		end
		idWaitOrder = false
	end
end
function widget:UnitCommandNotify(id, cmd, params, opts)

end

local function ReadOpts(opts)
	if tonumber(opts) then
		return 'coded: ' .. opts
	end
	local str = ''
	for k,v in pairs(opts) do
		if v then
			str = str .. k .. ': '.. tostring(v) .. ', '
		end
	end
	return str:sub(1,-3)
end

function widget:CommandNotify(cmd, params, opts)
	if artySelected and cmd == CMD_ATTACK and params[4] then
		copyArtySelected = deepcopy(artySelected)
		-- Echo('CNNNN',artySelected[1][1],artySelected,'cmd',cmd,'opts',ReadOpts(opts),'p',unpack(params))
		idWaitOrder = copyArtySelected[1][1]
	end
end

function widget:Initialize()
	if Spring.GetSpectatingState() or Spring.IsReplay() then
		widgetHandler:RemoveWidget(widget)
		return
	end
	Units = WG.UnitsIDCard and WG.UnitsIDCard.active and WG.UnitsIDCard
	if not Units then
		Echo(widget:GetInfo().name .. ' requires UnitsIDCard.')
		widgetHandler:RemoveWidget(widget)
		return
	end
	widget:CommandsChanged()
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