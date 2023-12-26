
function widget:GetInfo()
	return {
		name      = "FixWait",
		desc      = "Only unwait waiting units if any",
		author    = "Helwor",
		date      = "Oct 2023",
		license   = "GNU GPL, v2 or v3",
		layer     = -10, -- Before NoDuplicateOrders
		enabled   = true
	}
end

local Echo = Spring.Echo

local spGetSelectedUnits 		= Spring.GetSelectedUnits
local spGiveOrderToUnit			= Spring.GiveOrderToUnit
local spGetUnitCurrentCommand 	= Spring.GetUnitCurrentCommand
local CMD_WAIT 					= CMD.WAIT
local CMD_OPT_ALT 				= CMD.OPT_ALT
local EMPTY_TABLE				= {}


function IsWaiting(id)
    local cmd, opt = spGetUnitCurrentCommand(id)
    return cmd == CMD_WAIT and (opt % (2*CMD_OPT_ALT) < CMD_OPT_ALT)
end

function widget:CommandNotify(cmd, params, opts)
	if cmd ~= CMD_WAIT then
		return
	end
	local blockCommand
	for i, id in ipairs(spGetSelectedUnits() or EMPTY_TABLE) do
		if IsWaiting(id) then
			spGiveOrderToUnit(id, CMD_WAIT, EMPTY_TABLE, 0)
			blockCommand = true
		end
	end
	return blockCommand
end

function widget:Initialize()
	if Spring.GetSpectatingState() or Spring.IsReplay() then
		widgetHandler:RemoveWidget(widget)
	end
end