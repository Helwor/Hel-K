
function widget:GetInfo()
	return {
		name      = "Guard Remove",
		desc      = "Removes non-terminating orders when they seem to have been used accidentally.",
		author    = "Google Frog",
		date      = "13 July 2017",
		license   = "GNU GPL, v2 or later",
		layer     = -10, -- Before NoDuplicateOrders
		enabled   = true,
		handler	  = true,
	}
end
local Echo = Spring.Echo
include("keysym.lua")
VFS.Include("LuaRules/Configs/customcmds.h.lua")

--------------------------------------------------------------------------------
-- Epic Menu Options
--------------------------------------------------------------------------------

options_path = 'Settings/Unit Behaviour'
options = {
	shiftRemovesGuard = {
		name = "Additional queue removes guard",
		type = "bool",
		value = true,
		desc = "Removes non-terminating commands (guard and patrol) from command queues when additional commands are queued.",
		noHotkey = true,
	},
	repairGuards = {
		name = "Repair in factory queues guard",
		type = "bool",
		value = true,
		desc = "Prevents accidentally not assisting by right clicking on the unit in the factory instead of the factory.",
		noHotkey = true,
	},
}

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local spGetCommandQueue = Spring.GetCommandQueue



local doCommandRemove = false

local removableCommand = {
	[CMD.GUARD] = true,
	[CMD.PATROL] = true,
	[CMD_ORBIT] = true,
	[CMD_AREA_GUARD] = true,
}

local CMD_REPAIR = CMD.REPAIR
local CMD_GUARD = CMD.GUARD
local CMD_INSERT = CMD.INSERT
local validUnitDefIDs = {}
for unitDefID, unitDef in pairs(UnitDefs) do
	if unitDef.isBuilder and not unitDef.isFactory then
		validUnitDefIDs[unitDefID] = true
	end
end

local function CheckGuardAdd(id, params, cmdOptions)
	if id ~= CMD_REPAIR then
		return false
	end
	if not options.repairGuards.value then
		return false
	end
	if cmdOptions.meta then
		return false
	end
	if params and #params == 1 then
		local targetID = params[1]
		if Spring.ValidUnitID(targetID) then
			local factoryID = Spring.GetUnitRulesParam(targetID, "parentFactory")
			if factoryID then
				local units = Spring.GetSelectedUnits()
				if #units > 0 then
					WG.sounds_gaveOrderToUnit(units[1])
					local codedWithShift = cmdOptions.coded
					if not cmdOptions.shift then
						codedWithShift = codedWithShift + CMD.OPT_SHIFT
					end
					for i = 1, #units do
						local unitID = units[i]
						if validUnitDefIDs[Spring.GetUnitDefID(unitID)] then
							Spring.GiveOrderToUnit(unitID, CMD_REPAIR, params, cmdOptions.coded)
							Spring.GiveOrderToUnit(unitID, CMD_GUARD, {factoryID}, codedWithShift)
						end
					end
					return true
				end
			end
		end
	end
	return false
end

local function CheckGuardRemove(id, params, cmdOptions, posCommand)
	if not doCommandRemove then
		return
	end
	if not options.shiftRemovesGuard.value then
		return
	end
	if not cmdOptions.shift then
		doCommandRemove = false
		return
	end

	local units = Spring.GetSelectedUnits()
	for i = 1, #units do
		local unitID = units[i]
		if validUnitDefIDs[Spring.GetUnitDefID(unitID)] then
			local cmd = Spring.GetCommandQueue(unitID, -1)
			if cmd then
				for c = 1, #cmd do
					-- Do not remove commands that are about to be shift-click removed.
					if removableCommand[cmd[c].id] and not (cmdOptions.shift and cmd[c].id == id and cmd[c].params and cmd[c].params[1] == params[1]) then
						Spring.GiveOrderToUnit(unitID, CMD.REMOVE, {cmd[c].tag}, 0)
					end
				end
			end
		end
	end
	
	doCommandRemove = false
end

function widget:UnitFromFactory(unitID)
	local guardTag
	local previousOrder
	for i,order in ipairs(spGetCommandQueue(unitID,-1)) do
		-- Echo(unitID,'order from factory',order.id)
		if not guardTag then
			previousOrder = order
		end
		if order.id == CMD_GUARD then
			guardTag = order.tag
			-- Echo('got guard',guardTag)
		elseif guardTag then
			Spring.GiveOrderToUnit(unitID, CMD.REMOVE, {guardTag}, 0)
			-- Echo('remove guard')
			break
		end
	end
end
local function DebugCommandNotify(id,params,options)
	local str = ''
	str = str .. 'cmd: ' .. id 
	str = str .. ', params: '
	for i,p in ipairs(params) do
		str = str .. math.round(p) .. ','
	end
	str = str .. ' opts: '
	for opt,v in pairs(options) do
		if opt == 'coded' then
			coded = v
		elseif v then
			str = str .. opt .. ','
		end
	end
	if coded then
		str = str .. 'coded: ' .. coded
	end
	Echo(str)
	return str
end
function widget:CommandNotify(id, params, cmdOptions)


	-- DebugCommandNotify(id, params, cmdOptions)
	local posCommand
	if id == CMD_INSERT then
		params = {unpack(params)}
		posCommand = table.remove(params,1)
		id = table.remove(params,1)
		-- Echo("posCommand,id is ", posCommand,id)
		if posCommand == -1 then
			cmdOptions.shift = true
		end
	end

	if CheckGuardAdd(id, params, cmdOptions) then
		-- Echo('returned true')
		return true
	end
	CheckGuardRemove(id, params, cmdOptions,posCommand)
	return false
end

function widget:KeyPress(key, modifier, isRepeat)
	if not isRepeat and (key == KEYSYMS.LSHIFT or key == KEYSYMS.RSHIFT) then
		doCommandRemove = true
	end
end
function widget:Initialize()
	if Spring.IsReplay() or Spring.GetSpectatingState() then
		widgetHandler:RemoveWidget(widget)
		return
	end
end