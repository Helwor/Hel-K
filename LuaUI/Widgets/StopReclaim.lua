
function widget:GetInfo()
	return {
		name = "Stop Reclaim",
		desc = "Reclaim the build you've just started if pressed STOP",
		author = "Helwor",
		date = "Sept 2023",
		license = "GNU GPL, v2 or later",
		layer = -10.01, -- before the widget playing sound on command
		enabled = true,
		handler = true,
	}
end
local Echo = Spring.Echo
local debugMe = true
local TIMEOUT = 1

-- options_path ='Settings/Interface/Commands/Stop Reclaim'
options_path ='Hel-K/Stop Reclaim'
options_order = {'active','timeout'}
options = {}
options.active = {
	name = 'Stop Reclaim Active',
	desc = 'When ordering builder to stop a freshly started build, it will also reclaim it',
	type = 'bool',
	value = false,
	OnChange = function(self)
		local on = self.value

		if on then
			if widget.sleeping then
				local sleeping = true
				for k,v in pairs(widget) do
					if type(v) == 'function' then
						local isCallIn = widgetHandler[k .. 'List']
						if isCallIn then
							sleeping = false
							widgetHandler:UpdateWidgetCallIn(k, widget)
						end
					end
					widget.sleeping = sleeping

				end
				Echo('Attempt to wake up ' .. widget:GetInfo().name .. ': ' .. (sleeping and 'fail' or 'success') .. '.')
			end
		else
			if not widget.sleeping then
				local sleeping = false
				for k,v in pairs(widget) do
					if type(v) == 'function' then
						local isCallIn = widgetHandler[k .. 'List']
						if isCallIn then
							sleeping = true
							widgetHandler:RemoveWidgetCallIn(k, widget)
						end
					end
				end
				widget.sleeping = sleeping
				Echo('Attempt to put ' .. widget:GetInfo().name .. ' to sleep: ' .. (sleeping and 'success' or 'fail') .. '.')
			end
		end
	end,
}
options.timeout = {
	name = 'Timeout',
	desc = 'Time out in seconds before forgetting the build started (server response time doesnt matter)',
	type = 'number',
	min = 0.1,
	max = 30,
	step = 0.1,
	value = TIMEOUT,
	OnChange = function(self)
		TIMEOUT = self.value
	end,
}


local spGetMyTeamID = Spring.GetMyTeamID
local spGetUnitDefID = Spring.GetUnitDefID
local spGetSelectedUnitsSorted = Spring.GetSelectedUnitsSorted
local spGetCommandQueue = Spring.GetCommandQueue
local spGetUnitCurrentCommand = Spring.GetUnitCurrentCommand
local spGiveOrder = Spring.GiveOrder
local spGiveOrderToUnit = Spring.GiveOrderToUnit
local spGetUnitPosition = Spring.GetUnitPosition

local orderReclaim = false
local builders, builtBy, timeOut = {}, {}, {}
local builderSelected = {}
local OPTSFALSE = {alt=false, ctrl=false, meta=false, shift=false, coded=0, internal=false}
local t = 0
local _

local myTeamID = spGetMyTeamID()
local hasBuilder = false

local CMD_STOP = CMD.STOP
local CMD_RECLAIM = CMD.RECLAIM
local CMD_REPAIR = CMD.REPAIR

local builderDefID = {}
for defID, def in pairs(UnitDefs) do
	if def.isBuilder and not def.isFactory then
		builderDefID[defID] = true
	end
end

local function clear(t)
	for k in pairs(t) do
		t[k] = nil
	end
end
function widget:PlayerChanged()
	myTeamID = spGetMyTeamID()
end
function widget:Update(dt)
	t = t + dt
end



function widget:UnitCommand(unitID, _, _, cmd, params)
	-- Echo("unitID, cmd is ", unitID, cmd)
	if not hasBuilder then
		return
	end
	if cmd ~= CMD_STOP then
		return
	end
	if not builderSelected[unitID] then
		return
	end

	local cmd,_,_,p1,_,p3 = spGetUnitCurrentCommand(unitID)
	if not cmd then
		return
	end
	local buildID
	if cmd < 0 then
		buildID = builders[unitID]
		if buildID then
			local x,_,z = spGetUnitPosition(buildID)
			if not x or x ~= p1 or z ~= p3 then
				buildID = false
			end
		end
	elseif cmd == CMD_REPAIR then
		buildID = builtBy[p1] == unitID and p1
	end
	if not buildID then
		return
	end

	if t > timeOut[buildID] then
		-- Echo('timedout',t-timeOut[buildID],t ..'>'..timeOut[buildID])
		widget:UnitFinished(buildID,_,myTeamID)
	else
		orderReclaim = unitID
		widgetHandler:UnitCommandNotify(unitID, CMD_RECLAIM, {buildID}, OPTSFALSE)
		orderReclaim = nil
	end
end
function widget:UnitCommandNotify(unitID, cmd, params, opts) -- 
	if orderReclaim == unitID then
		if cmd == CMD_RECLAIM then
			spGiveOrderToUnit(unitID, CMD_RECLAIM,params[1],opts.coded) -- avoid the sound repeating
			return true
		end
		orderReclaim = nil
	end
end


function widget:CommandsChanged()
	hasBuilder = false
	clear(builderSelected)
	for defID, t in pairs(spGetSelectedUnitsSorted()) do
		if builderDefID[defID] then
			hasBuilder = true
			for i, id in ipairs(t) do
				builderSelected[id] = true
			end
		end
	end
end
function widget:UnitCreated(unitID, _, teamID, builderID)
	if teamID == myTeamID then
		if builderID then
			local defID = spGetUnitDefID(builderID)
			if defID and builderDefID[defID] then
				builders[builderID] = unitID
				builtBy[unitID] = builderID
				timeOut[unitID] = t + TIMEOUT
			end
		end
	end
end
function widget:UnitFinished(unitID, _, teamID)
	local builderID = builtBy[unitID]
	if builderID then
		builtBy[unitID] = nil
		builders[builderID] = nil
		timeOut[unitID] = nil
	end
end
widget.UnitDestroyed = widget.UnitFinished


function widget:Initialize()
	widget:CommandsChanged()
end