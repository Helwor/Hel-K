-- $Id: gui_commandinsert.lua 3171 2008-11-06 09:06:29Z det $
-------------------------------------------------------------------------------------

function widget:GetInfo()
	return {
		name = "Strider Hub Alt",
		desc = "Implement a one time build for strider hub on repeat using Alt",
        author = "Helwor",
		date = "Sept 2023",
		license = "GNU GPL, v2",
		layer = 5,
		enabled = true,
		handler = true,
		api = true,
	}
end
local Echo = Spring.Echo
local striderHubDefID 	= UnitDefNames['striderhub'].id
local athenaDefID 		= UnitDefNames['athena'].id

local spGiveOrderToUnit = Spring.GiveOrderToUnit
local spGetCommandQueue = Spring.GetCommandQueue
local CMD_REMOVE = CMD.REMOVE


local selectionDefID

function widget:TextCommand(txt)
	if txt == 'stopproduction' then
		local athenas = selectionDefID[athenaDefID]
		local striderHubs = selectionDefID[striderHubDefID]
		if athenas then
			for i, unitID in ipairs(athenas) do
				local queue = spGetCommandQueue(unitID,-1)
				for i, order in ipairs(queue) do
					if order.id < 0 then
						spGiveOrderToUnit(unitID, CMD_REMOVE, order.tag, 0)
					end
				end
			end
		end
		if striderHubs then
			for i, unitID in ipairs(striderHubs) do
				local queue = spGetCommandQueue(unitID,-1)
				for i, order in ipairs(queue) do
					if order.id < 0 then
						spGiveOrderToUnit(unitID, CMD_REMOVE, order.tag, 0)
					end
				end
			end
		end

	end
end
function widget:UnitCmdDone(unitID,defID,teamID,cmd,params,opts)
	-- Echo("unitID,defID,teamID,cmd,params,opts is ", unitID,defID,teamID,cmd,params,opts)
	if cmd > 0 then 
		return
	end
	if defID ~= striderHubDefID and defID ~= athenaDefID then
		return
	end
	if not opts.alt then
		return
	end
	local queue = spGetCommandQueue(unitID,-1)
	
	local lastOrder = queue[#queue]
	local remove
	if lastOrder and lastOrder.id == cmd then
		remove = true
		for i, p in ipairs(lastOrder.params) do
			if i~=2 and p ~= params[i] then
				remove =false
				break
			end
		end

	end
	if remove then
		spGiveOrderToUnit(unitID, CMD_REMOVE, lastOrder.tag, 0)
	end


end

function widget:Initialize()
	if Spring.GetSpectatingState() then
		widgetHandler:RemoveWidget(self)
		return
	end
	selectionDefID = WG.selectionDefID
	-- myTeamID = spGetMyTeamID()
end
