function widget:GetInfo()
	return {
		name      = "Fix Wait",
		desc      = "Only unwait waiting units if any",
		author    = "Helwor",
		date      = "Oct 2023",
		license   = "GNU GPL, v2 or v3",
		layer     = -10, -- Before NoDuplicateOrders
		enabled   = true
	}
end


local spGetSelectedUnits 		= Spring.GetSelectedUnits
local spGiveOrderToUnit			= Spring.GiveOrderToUnit
local spGiveOrderToUnitArray    = Spring.GiveOrderToUnitArray
local spGetUnitCurrentCommand 	= Spring.GetUnitCurrentCommand
local spGetCommandQueue			= Spring.GetCommandQueue
local CMD_WAIT 					= CMD.WAIT
local CMD_OPT_ALT 				= CMD.OPT_ALT
local CMD_OPT_SHIFT				= CMD.OPT_SHIFT
local EMPTY_TABLE				= {}


function IsWaiting(id, shift)
	local cmd, opt
	if shift then
		local queue = (spGetCommandQueue(id,-1) or EMPTY_TABLE)
		local lastOrder = queue[#queue]
		if lastOrder then
			cmd, opt = lastOrder.id, lastOrder.options.coded
		end
	else
		cmd, opt = spGetUnitCurrentCommand(id)
	end
    return cmd == CMD_WAIT and (opt % (2*CMD_OPT_ALT) < CMD_OPT_ALT)
end

function widget:CommandNotify(cmd, params, opts)
	if cmd ~= CMD_WAIT then
		return
	end
	local sel = (spGetSelectedUnits() or EMPTY_TABLE)
	if not sel[1] then
		return
	end

	local ids, cnt = {}, 0
	local len = #sel
	local shift = opts.shift
	local commandBlocked

	for i = 1, len do
		local id = sel[i]
		if IsWaiting(id, shift) then
			cnt = cnt + 1
			ids[cnt] = id
		end
	end

	if cnt > 0 and cnt < len then
		-- giving order one by one is smooth and doesnt take more time or very barely
		for i=1, cnt do
			spGiveOrderToUnit(ids[i], CMD_WAIT, EMPTY_TABLE, shift and CMD_OPT_SHIFT or 0)
		end
		-- provoke freeze on big number
		-- spGiveOrderToUnitArray(ids, CMD_WAIT, EMPTY_TABLE, shift and CMD_OPT_SHIFT or 0)
		return true
	end
end

function widget:Initialize()
	if Spring.GetSpectatingState() or Spring.IsReplay() then
		widgetHandler:RemoveWidget(self)
	end
end
