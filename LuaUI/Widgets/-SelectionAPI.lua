
function widget:GetInfo()
  return {
	name      = "Selection API",
	desc      = "set of tools to get info about selection",
	author    = "Helwor",
	date      = "Sept 2023",
	license   = "GNU GPL, v2 or later",
	layer     = -1000000,
	enabled   = true,  --  loaded by default?
	handler   = true,
	api       = true,
	alwaysStart = true,
  }
end
local Echo = Spring.Echo

if not f then -- compat with old Hel-K
	f = VFS.Include("LuaUI\\Widgets\\UtilsFunc.lua")
end
include("LuaRules/Configs/customcmds.h.lua")
-- speedups
local spGetModKeyState          = Spring.GetModKeyState
local spGetKeyState             = Spring.GetKeyState

local spGetCameraState          = Spring.GetCameraState
local spSetCameraState          = Spring.SetCameraState
local spGetCameraPosition       = Spring.GetCameraPosition
local spSetCameraTarget         = Spring.SetCameraTarget
local spTraceScreenRay          = Spring.TraceScreenRay
local spSetActiveCommand        = Spring.SetActiveCommand
local spSendCommands            = Spring.SendCommands
local spGetActiveCommand        = Spring.GetActiveCommand

local spGetMouseState           = Spring.GetMouseState
local spSetMouseCursor          = Spring.SetMouseCursor
local spWarpMouse               = Spring.WarpMouse
local spGetUnitRulesParam       = Spring.GetUnitRulesParam

local spFindUnitCmdDesc         = Spring.FindUnitCmdDesc
local spGetCmdDescIndex         = Spring.GetCmdDescIndex
local spGetSelectedUnitsSorted  = Spring.GetSelectedUnitsSorted
local spGetUnitIsTransporting   = Spring.GetUnitIsTransporting
local spGetUnitDefID            = Spring.GetUnitDefID

local spGetUnitCurrentCommand   = Spring.GetUnitCurrentCommand
local spGetCommandQueue         = Spring.GetCommandQueue
local CMD_UNLOAD_UNITS = CMD.UNLOAD_UNITS
local CMD_LOAD_UNITS = CMD.LOAD_UNITS
-- f.DebugWidget(widget)
local EMPTY_TABLE = setmetatable({}, { __newindex = function() error('EMPTY_TABLE must stay empty !') end })

local wh
WG.commandMap           = WG.commandMap or {}
WG.selectionMap         = WG.selectionMap or {}
WG.selectionDefID       = WG.selectionDefID or {}
WG.selection            = WG.selection or {}
WG.mySelection          = WG.mySelection or {}
WG.transportedUnit      = WG.transportedUnit or {}

local currentCommands   = {}
local commandMap        = WG.commandMap
local selection         = WG.selection
local selectionMap      = WG.selectionMap
local selectionDefID    = WG.selectionDefID
local mySelection       = WG.mySelection
local transportedUnits  = WG.transportedUnits or {}


local function clear(t)
	for k in pairs(t) do
		t[k] = nil
	end
end
------
local morphedComDGUN = {}
------
local puppyDefID = UnitDefNames['jumpscout'].id
local lobsterDefID = UnitDefNames['amphlaunch'].id
local widowDefID = UnitDefNames['spiderantiheavy'].id
local revDefID = UnitDefNames['gunshipassault'].id
local krowDefID = UnitDefNames['gunshipkrow'].id
local impalerDefID = UnitDefNames['vehheavyarty'].id
--- air stuff
local airDgunDefID = {
	[UnitDefNames['bomberassault'].id] = true,   
}
local airAttackerDefID = {}
for defID,def in ipairs(UnitDefs) do
	if def.isAirUnit and def.canAttack then
		airAttackerDefID[defID]=true
	end
end
local bomberDefID = {}
for defID, def in pairs(UnitDefs) do
	if def.isBomber or def.isBomberAirUnit or def.customParams.reallyabomber then
		-- Echo("def.name is ", def.name, def.isBomber and 'isBomber' or def.isBomberAirUnit and 'isBomberAirUnit' or def.customParams.reallyabomber and 'reallyabomber')
		bomberDefID[defID] = true
	end
end
local bombDefID = {}
for defID, def in pairs(UnitDefs) do
	if def.name:match('bomb$') then
		bombDefID[defID] = true
	end
end

local gunshipDefID = {}
local planeDefID = {}
local GUNSHIP_MOVE_TYPE = 1
local athenaDefID = UnitDefNames['athena'].id
local spuGetMoveType = Spring.Utilities.getMovetype
for defID, def in pairs(UnitDefs) do
    if def.isBomber or def.isBomberAirUnit or def.customParams.reallyabomber then
        -- Echo("def.name is ", def.name, def.isBomber and 'isBomber' or def.isBomberAirUnit and 'isBomberAirUnit' or def.customParams.reallyabomber and 'reallyabomber')
        bomberDefID[defID] = true
        planeDefID[defID] = true
    elseif spuGetMoveType(def) == GUNSHIP_MOVE_TYPE then -- def.isHoveringAirUnit can work too
        gunshipDefID[defID] = true
    elseif def.canFly then
    	planeDefID[defID] = true
    end
end

----

local jumperDefID = {}
for defID,def in ipairs(UnitDefs) do
	if def.customParams.canjump then
		if not (def.name:match('plate') or def.name:match('factory')) then
			jumperDefID[defID] = true
		end
	end
end

------
local transportDefID = UnitDefNames['gunshiptrans'].id
local heavyTransportDefID = UnitDefNames['gunshipheavytrans'].id
------

local immobileDefID, turretDefID = {}, {}
for defID, def in pairs(UnitDefs) do
	if def.isImmobile then
		immobileDefID[defID] = true
		if def.canAttack then
			turretDefID[defID] = true
		end
	end
end





WG.selectionGotCurrentLoadOrder = function()
	for defID, units in pairs(selectionDefID or EMPTY_TABLE) do
		if defID == transportDefID or defID == heavyTransportDefID then
			for i, id in pairs(units) do
				if spGetUnitCurrentCommand(id) == CMD_LOAD_UNITS then
					return true
				end
			end
		end
	end
	return false
end
WG.selectionGotLoadOrder = function()
	for defID, units in pairs(selectionDefID or EMPTY_TABLE) do
		if defID == transportDefID or defID == heavyTransportDefID then
			for i, id in pairs(units) do
				local queue = spGetCommandQueue(id, -1)
				if queue then
					for i, order in pairs(queue) do
						if order.id == CMD_LOAD_UNITS then
							return true
						end
					end
				end
			end
		end
	end
	return false
end

local function UpdateTransport()

	local hasTransport, isTransporting, canLoadLight, canLoadHeavy = false, false, false, false
	if commandMap['Unload units'] then
		local light = selectionDefID[transportDefID]

		if light then
			hasTransport = true
			for i, id in ipairs(light) do
				local tr = spGetUnitIsTransporting(id)

				if tr and tr[1] then
					isTransporting = true
					-- if canLoadLight then
					--     break
					-- end
				else
					canLoadLight = true
				end
			end
		end
		local heavy = selectionDefID[heavyTransportDefID]
		if heavy then
			hasTransport = true
			for i, id in ipairs(heavy) do
				local tr = spGetUnitIsTransporting(id)
				if tr and tr[1] then
					isTransporting = true
					-- if canLoadHeavy then
					--     break
					-- end
				else
					canLoadHeavy = true
				end
			end
		end
	end
	mySelection.hasTransport = hasTransport
	mySelection.isTransporting = isTransporting
	mySelection.canLoadLight = canLoadLight
	mySelection.canLoadHeavy = canLoadHeavy
end


local function RemapCommands()
	currentCommands = wh.commands
	clear(commandMap)
	for i, command in pairs(wh.commands) do
		if i~='n' then

			-- if command.name == 'Unload units' then -- note : some different got same name, but different id, ex: LOAD_ONTO and LOAD_UNITS have the same name 'Load units'
			--     for k,v in pairs(command) do
			--         Echo(k,v)
			--     end
			--     Echo('params?',table.size(command.params))
			--     for k,v in pairs(command.params) do
			--         Echo('params',k,v)
			--     end
			-- end
			command.pos = i
			commandMap[command.name] = command
			commandMap[command.id] = command
		end
	end
	UpdateTransport()
end
-- function widget:Update()
--     Echo("next(transportedUnits) is ", next(transportedUnits))
-- end
function widget:Update()
	if currentCommands ~= wh.commands then
		currentCommands = wh.commands
		RemapCommands()
	end
end


function widget:CommandsChanged()
	-- for k,v in pairs(customCmds) do
	--     Echo(k,v)
	-- end
	clear(selectionMap)
	clear(selectionDefID)
	clear(selection)
	clear(mySelection)
	-- Echo('--')

	local totalCount = 0

	---------
	local hasNoFloater = true

	local hasLobster, lobsters = false, EMPTY_TABLE
	local hasJumper, jumpers = false, EMPTY_TABLE

	local hasPlane, hasBomber = false, false
	local hasGunship, hasKrow, hasRev, hasAthena, hasOnlyAthena = false, false, false, false, false
	local hasAirAttacker, hasAirDgun = false, false

	local hasBomb = false

	local hasPuppy, hasWidow, hasImpaler = false, false, false

	local hasImmobile, hasTurret = false, false

	local hasDgunCom = false

	-- local isSmall -- defined at the end
	-------

	local floatPlacingInfo = WG.floatPlacingInfo


	local sorted = spGetSelectedUnitsSorted()
	for defID, t in pairs(sorted) do

		local count = 0
		selectionDefID[defID] = t
		for i, id in ipairs(t) do
			selectionMap[id] = defID
			selection[totalCount + i] = id
			count = count + 1
		end
        t.count = count
		totalCount = totalCount + count


		---- registering some custom 'hasUnit' infos
		if hasNoFloater and floatPlacingInfo[defID].reallyFloat then
			--and (ud[defID].floatOnWater or not f.CheckCanSub(ud.name)) then
			hasNoFloater = false
		end

		if not hasLobster and defID == lobsterDefID then
			lobsters = t
			hasLobster = true

		elseif not hasPuppy and defID == puppyDefID then
			hasPuppy = true
		elseif not hasWidow and defID == widowDefID then
			hasWidow = true
		elseif not hasImpaler and defID == impalerDefID then
			hasImpaler = true

		elseif immobileDefID[defID] then
			hasImmobile = true
			if not hasTurret and turretDefID[defID] then
				hasTurret = true
			end

		elseif gunshipDefID[defID] then
			hasGunship = true
			if not hasKrow and defID == krowDefID then
				hasKrow = true
			elseif not hasRev and defID == revDefID then
				hasRev = true
			elseif not hasAthena and defID == athenaDefID then
				hasAthena = true
				if next(sorted) == athenaDefID and not next(sorted, athenaDefID) then
					hasOnlyAthena = true
				end
			end

		elseif planeDefID[defID] then
			if not hasBomber and bomberDefID[defID] then
				hasBomber = true
			end
			hasPlane = true

		elseif jumperDefID[defID] then
			if jumpers == EMPTY_TABLE then
				jumpers = {}
			end
			table.merge(jumpers,t)
			hasJumper = true
		end

		if airAttackerDefID[defID] then
			hasAirAttacker = true
			if not hasAirDgun and airDgunDefID[defID] then
				hasAirDgun = true
			end
		end

		if not hasBomb and bombDefID[defID] then
			hasBomb = true
		end

	end

	for id in pairs(morphedComDGUN) do
		if selectionMap[id]  then
			hasDgunCom = true
			break
		end
	end
	--
	local mySelection = mySelection
	mySelection.hasNoFloater    = hasNoFloater

	mySelection.hasPuppy        = hasPuppy
	mySelection.hasWidow        = hasWidow
	mySelection.hasImpaler      = hasImpaler

	mySelection.hasLobster      = hasLobster
	mySelection.lobsters        = lobsters

	mySelection.hasAirAttacker  = hasAirAttacker

	mySelection.hasPlane 		= hasPlane
	mySelection.hasBomber       = hasBomber
	mySelection.hasAirDgun      = hasAirDgun

	mySelection.hasGunship		= hasGunship
	mySelection.hasKrow         = hasKrow
	mySelection.hasRev          = hasRev
	mySelection.hasAthena		= hasAthena
	mySelection.hasOnlyAthena	= hasOnlyAthena

	mySelection.hasJumper       = hasJumper
	mySelection.jumpers         = jumpers

	mySelection.hasImmobile     = hasImmobile
	mySelection .hasTurret      = hasTurret

	mySelection.hasBomb         = hasBomb

	mySelection.hasDgunCom      = hasDgunCom

	mySelection.count 			= totalCount
	mySelection.isSmall			= totalCount < 4

	mySelection.hasAirAttacker  = hasAirAttacker

	--
	RemapCommands()
end





function widget:UnitDestroyed(unitID)
	if transportedUnits[unitID] then
		UpdateTransport()
		transportedUnits[unitID] = nil
	end
end

function widget:UnitLoaded(unitID, unitDefID, unitTeam, transportID, transportTeam)
	if selectionMap[transportID] then
		-- RemapCommands()
		UpdateTransport()
		transportedUnits[unitID] = unitDefID
	end
end


function widget:UnitUnloaded(unitID, unitDefID, unitTeam, transportID, transportTeam)
	if selectionMap[transportID] then
		-- RemapCommands()
		UpdateTransport()
		transportedUnits[unitID] = nil
	end
end

function MorphFinished(oldID, newID)
	-- Echo("oldID, newID is ", oldID, newID,'time', math.round(os.clock()))
	if oldID and morphedComDGUN[oldID] then
		morphedComDGUN[newID] = true
		morphedComDGUN[oldID] = nil
		return
	end
	local defID = spGetUnitDefID(newID)
	if not defID then
		return
	end
	local def = UnitDefs[defID]
	local isCom = def.name:match('dyn') or def.name:match('c%d+_base')
	-- Echo("isCom is ", isCom)
	if not isCom then
		return
	end
	-- Echo("#def.weapons is ", #def.weapons)
	for i, weap in ipairs(def.weapons) do
		local wdefID = spGetUnitRulesParam(newID,'comm_weapon_id_'..i)
		-- Echo('=>',wdefID, wdefID and WeaponDefs[wdefID], wdefID and WeaponDefs[wdefID] and WeaponDefs[wdefID].customParams.slot)
		if wdefID then
			local wdef=WeaponDefs[wdefID]

			if wdef then
				if tonumber(wdef.customParams.slot) == 3 then
					morphedComDGUN[newID] = true
					-- Echo('morphedComDUN', newID, morphedComDGUN[newID])
					return
				end
			end
		end

	end
	-- widget:CommandsChanged()
end




function widget:Initialize()
	-- if Spring.GetSpectatingState() then
	--     widgetHandler:RemoveWidget(widget)
	--     return
	-- end
	WG.selectionAPI = true
	wh = widgetHandler
	local success = wh:RegisterGlobal(widget,'MorphFinished', MorphFinished)

	for i, id in ipairs(Spring.GetTeamUnits(Spring.GetMyTeamID())) do
		MorphFinished(nil, id) -- check for dgun morphed com if we load midgame
	end
	-- widgetHandler:RegisterGlobal('MorphUpdate', MorphUpdate)
	-- widgetHandler:RegisterGlobal('MorphStart', MorphStart)
	-- widgetHandler:RegisterGlobal('MorphStop', MorphStop)
	-- widgetHandler:RegisterGlobal('MorphDrawProgress', function() return true end)
	widget:CommandsChanged()

end

function widget:Shutdown()
	wh:DeregisterGlobal(widget,'MorphFinished')
	WG.selectionAPI = false
end
