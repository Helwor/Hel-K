-------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------

function widget:GetInfo()
	return {
		name      = "Gadget Icons",
		desc      = "Shows icons from gadgets that cannot access the widget stuff by themselves.",
		author    = "CarRepairer and GoogleFrog",
		date      = "2012-01-28",
		license   = "GNU GPL, v2 or later",
		layer     = 5,
		enabled   = true,
		alwaysStart = true,
	}
end
local Echo = Spring.Echo
-------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------

local spGetUnitCurrentCommand = Spring.GetUnitCurrentCommand
local spGetFactoryCommands = Spring.GetFactoryCommands
local spGetUnitRulesParam = Spring.GetUnitRulesParam

local min   = math.min
local floor = math.floor

----------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------

local SetUnitIcon

local unitList = {}
local unitIndex = {}
local unitCount = 0
local unitDefIDMap = {}
local myTeamID, myPlayerID
local currentIndex = 0

local CMD_WAIT = CMD.WAIT

local CMD_WAITCODE_NONE   = 0
local CMD_WAITCODE_DEATH  = CMD.WAITCODE_DEATH
local CMD_WAITCODE_SQUAD  = CMD.WAITCODE_SQUAD
local CMD_WAITCODE_GATHER = CMD.WAITCODE_GATHER
local CMD_WAITCODE_TIME   = CMD.WAITCODE_TIME





local COMMAND_LEEWAY = 30

local powerTexture = 'Luaui/Images/visible_energy.png'
local facplopTexture = 'Luaui/Images/factory.png'
local nofacTexture = 'Luaui/Images/nofactory.png'
local rearmTexture = 'LuaUI/Images/noammo.png'
local retreatTexture = 'LuaUI/Images/unit_retreat.png'
local excludedPadTexture = 'LuaUI/Images/commands/Bold/excludeairpad.png'

local waitTexture = {
	[CMD_WAITCODE_NONE  ] = 'LuaUI/Images/commands/Bold/wait.png',
	[CMD_WAITCODE_DEATH ] = 'LuaUI/Images/commands/Bold/wait_death.png',
	[CMD_WAITCODE_SQUAD ] = 'LuaUI/Images/commands/Bold/wait_squad.png',
	[CMD_WAITCODE_GATHER] = 'LuaUI/Images/commands/Bold/wait_gather.png',
	[CMD_WAITCODE_TIME  ] = 'LuaUI/Images/commands/Bold/wait_time.png',
}

local lowpowerON	 = {name = 'lowpower', 	 texture = powerTexture}
local lowpowerOFF	 = {name = 'lowpower', 	 texture = nil}
local facplopON		 = {name = 'facplop', 	 texture = facplopTexture}
local facplopOFF	 = {name = 'facplop', 	 texture = nil}
local nofactoryON	 = {name = 'nofactory',  texture = nofacTexture}
local nofactoryOFF	 = {name = 'nofactory',  texture = nil}
local rearmON	 	 = {name = 'rearm', 	 texture = rearmTexture}
local rearmOFF	 	 = {name = 'rearm', 	 texture = nil}
local retreatON		 = {name = 'retreat', 	 texture = retreatTexture}
local retreatOFF	 = {name = 'retreat', 	 texture = nil}
local padExcludeON	 = {name = 'padExclude', texture = excludedPadTexture}
local padExcludeOFF	 = {name = 'padExclude', texture = nil}
-- multiple wait
local waitON = {}
for cmd, tex in pairs(waitTexture) do
	waitON[cmd] = {name = 'wait', texture = tex}
end
local waitOFF	 	 = {name = 'wait', 		 texture = nil}

local lastLowPower = {}
local lastFacPlop = {}
local lastNofactory = {}
local lastRearm = {}
local lastRetreat = {}
local lastWait = {}
local everWait = {}
local lastExcludedPad = {}

local lowPowerUnitDef = {}
local facPlopUnitDef = {}
local facPlateUnitDef = {}
local factoryUnitDef = {}
local rearmUnitDef = {}
local retreatUnitDef = {}
local excludedPadUnitDef = {}
local waitUnitDef = {}

local checkAtCreationDefID = {}


for unitDefID = 1, #UnitDefs do
	local checkAtCreation = false
	local ud = UnitDefs[unitDefID]
	local cp = ud.customParams
	if cp.neededlink then
		lowPowerUnitDef[unitDefID] = true
		checkAtCreation = true
	end
	if cp.level then
		facPlopUnitDef[unitDefID] = true
		checkAtCreation = true
	end
	if cp.reammoseconds then
		rearmUnitDef[unitDefID] = true
		checkAtCreation = true
	end
	if not ud.isImmobile then
		retreatUnitDef[unitDefID] = true
		checkAtCreation = true
	end
	if not cp.removewait then
		waitUnitDef[unitDefID] = true
		checkAtCreation = true
	end
	if cp.ispad then
		excludedPadUnitDef[unitDefID] = true
		checkAtCreation = true
	end

	if cp.child_of_factory then
		facPlateUnitDef[unitDefID] = true
	end

	if ud.isFactory then
		factoryUnitDef[unitDefID] = true
	end

	if checkAtCreation then
		checkAtCreationDefID[unitDefID] = true
	end
end

-------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------

local function RemoveUnit(unitID)
	local index = unitIndex[unitID]
	unitList[index] = unitList[unitCount]
	unitIndex[unitList[unitCount]] = index
	unitList[unitCount] = nil
	unitCount = unitCount - 1
	unitIndex[unitID] = nil
	unitDefIDMap[unitID] = nil
	lastLowPower[unitID] = nil
	lastFacPlop[unitID] = nil
	lastExcludedPad[unitID] = nil
	lastNofactory[unitID] = nil
	lastRearm[unitID] = nil
	lastRetreat[unitID] = nil
	lastWait[unitID] = nil
	everWait[unitID] = nil
end

-------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------

local function GetFirstCmdAndFirstParam(unitID, unitDefID)
	if not factoryUnitDef[unitDefID] then
		local cmdID, _, _, cmdParam1 = spGetUnitCurrentCommand(unitID)
		return cmdID, cmdParam1
	end
	local cQueue = spGetFactoryCommands(unitID, 1)
	if cQueue and cQueue[1] and cQueue[1].params then -- nil check or it will crash when spectator switch ally team view
		return cQueue[1].id, cQueue[1].params[1]
	end
end

local function isWaiting(unitID, unitDefID)
	local cmdID, cmdParam = GetFirstCmdAndFirstParam(unitID, unitDefID)
	if not cmdID then
		if everWait[unitID] < Spring.GetGameFrame() then
			everWait[unitID] = nil
		end
		return false
	end

	if cmdID ~= CMD_WAIT then
		return false
	end

	return cmdParam1 or CMD_WAITCODE_NONE
end

local function UpdateUnitIcons(unitID)
	local unitDefID = unitDefIDMap[unitID]
	-- calculate which units can have these states and check them first
	-- seems like it base the check on wether or not the rule param is anything, as it has been set once to on (1) then off (0) but being nil if nothing happêned yet
	-- problem is when changing team, at least for excludePad, it will be nil because the new teamID never excluded that same pad, and then the icon will stay up wrongly

	local lowpower = lowPowerUnitDef[unitDefID] and spGetUnitRulesParam(unitID, "lowpower")
	if lowpower then
		local _,_,inbuild = Spring.GetUnitIsStunned(unitID)
		if inbuild then
			lowpower = 0 -- Draw as if not on low power
		end
		if lastLowPower[unitID] ~= lowpower then
			lastLowPower[unitID] = lowpower
			if lowpower ~= 0 then
				SetUnitIcon( unitID, lowpowerON )
			else
				SetUnitIcon( unitID, lowpowerOFF )
			end
		end
	end
	
	local facplop = facPlopUnitDef[unitDefID] and spGetUnitRulesParam(unitID, "facplop")
	if facplop or lastFacPlop[unitID] == 1 then
		if not facplop then
			facplop = 0
		end
		if lastFacPlop[unitID] ~= facplop then
			lastFacPlop[unitID] = facplop
			if facplop ~= 0 then
				SetUnitIcon( unitID, facplopON )
				WG.icons.SetPulse( 'facplop', true )
			else
				SetUnitIcon( unitID, facplopOFF )
			end
		end
	end
	
	local nofactory = facPlateUnitDef[unitDefID] and spGetUnitRulesParam(unitID, "nofactory")
	if nofactory then
		if lastNofactory[unitID] ~= nofactory then
			lastNofactory[unitID] = nofactory
			if nofactory == 1 then
				SetUnitIcon( unitID, nofactoryON )
			else
				SetUnitIcon( unitID, nofactoryOFF )
			end
		end
	end
	
	local rearm = rearmUnitDef[unitDefID] and spGetUnitRulesParam(unitID, "noammo")
	if rearm then
		if lastRearm[unitID] ~= rearm then
			lastRearm[unitID] = rearm
			if rearm == 1 or rearm == 2 then
				SetUnitIcon( unitID, rearmON )
			elseif rearm == 3 then
				-- SetUnitIcon( unitID, {name='rearm', texture=repairTexture} ) -- FIXME doesn't exist
				SetUnitIcon( unitID, rearmOFF )
			else
				SetUnitIcon( unitID, rearmOFF )
			end
		end
	end
	
	local retreat = retreatUnitDef[unitDefID] and spGetUnitRulesParam(unitID, "retreat")
	if retreat then
		if lastRetreat[unitID] ~= retreat then
			lastRetreat[unitID] = retreat
			if retreat ~= 0 then
				SetUnitIcon( unitID, retreatON )
			else
				SetUnitIcon( unitID, retreatOFF )
			end
		end
	end

	if excludedPadUnitDef[unitDefID] then
		-- rule param can be nil if the unit has changed team, we need to do it differently
		local padExcluded = spGetUnitRulesParam(unitID, "padExcluded" .. myTeamID)
		if lastExcludedPad[unitID] ~= padExcluded then
			lastExcludedPad[unitID] = padExcluded
			if padExcluded == 1 then
				SetUnitIcon( unitID, padExcludeON )
			else
				SetUnitIcon( unitID, padExcludeOFF )
			end
		end
	end

	if everWait[unitID] and waitUnitDef[unitDefID] then
		local wait = isWaiting(unitID, unitDefID)
		if lastWait[unitID] ~= wait then
			lastWait[unitID] = wait
			if wait then
				SetUnitIcon( unitID, waitON[wait] )
			else
				SetUnitIcon( unitID, waitOFF )
			end
		end
	end
end

function SetIcons()
	local unitID
	local limit = math.ceil(unitCount/4)
	for i = 1, limit do
		currentIndex = currentIndex + 1
		if currentIndex > unitCount then
			currentIndex = 1
		end
		unitID = unitList[currentIndex]
		if not unitID then
			return
		end
		UpdateUnitIcons(unitID)
	end
end

function widget:UnitCreated(unitID, unitDefID, unitTeam)
	if not checkAtCreationDefID[unitDefID] then
		return
	end

	if unitIndex[unitID] then
		return
	end
	
	unitCount = unitCount + 1
	unitList[unitCount] = unitID
	unitIndex[unitID] = unitCount
	unitDefIDMap[unitID] = unitDefID
end

function widget:UnitDestroyed(unitID, unitDefID, unitTeam)
	-- There should be a better way to do this, lazy fix.
	SetUnitIcon( unitID, lowpowerOFF )
	SetUnitIcon( unitID, facplopOFF )
	SetUnitIcon( unitID, nofactoryOFF )
	SetUnitIcon( unitID, rearmOFF )
	SetUnitIcon( unitID, retreatOFF )
	SetUnitIcon( unitID, waitOFF )
	SetUnitIcon( unitID, padExcludeOFF )
	
	if unitIndex[unitID] then
		RemoveUnit(unitID)
	end
end

function widget:UnitGiven(unitID, unitDefID, unitTeam, oldTeam)
	widget:UnitCreated(unitID, unitDefID, unitTeam)
	everWait[unitID] = Spring.GetGameFrame() + COMMAND_LEEWAY -- For lagmonitor
end

function widget:UnitTaken(unitID, unitDefID, unitTeam, newTeam)
	widget:UnitDestroyed(unitID, unitDefID, unitTeam)
end

function widget:UnitCommand(unitID, unitDefID, unitTeam, cmdID, cmdParams, cmdOpts)
	if cmdID == CMD_WAIT then
		everWait[unitID] = Spring.GetGameFrame() + COMMAND_LEEWAY
	end
end

-------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------

function widget:GameFrame(f)
	if f%4 == 0 then
		SetIcons()
	end
end



function widget:PlayerChanged(playerID)
	if myPlayerID == playerID then
		local myNewTeamID = Spring.GetMyTeamID()
		if myTeamID ~= myNewTeamID then
			widget:Shutdown()
			widget:Initialize()
		end
	end
end

function widget:Shutdown()
	for _, unitID in ipairs(unitList) do
		widget:UnitDestroyed(unitID)
	end
end

function widget:Initialize()
	WG.icons.SetOrder('lowpower', 2)
	WG.icons.SetOrder('retreat', 5)
	WG.icons.SetDisplay('retreat', true)
	WG.icons.SetPulse('retreat', true)
	
	SetUnitIcon = WG.icons.SetUnitIcon
	myPlayerID = Spring.GetMyPlayerID()
	myTeamID = Spring.GetMyTeamID()
	for _, unitID in ipairs(Spring.GetAllUnits()) do
		local unitDefID = Spring.GetUnitDefID(unitID)
		widget:UnitCreated(unitID, unitDefID, myTeamID)
	end
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
