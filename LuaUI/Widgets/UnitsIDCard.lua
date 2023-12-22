

function widget:GetInfo()
	return {
		name      = "UnitsIDCard",
		desc      = "produce extended ID card of units",
		author    = "Helwor",
		date      = "August 2020",
		license   = "GNU GPL, v2 or later",
		layer     = -10e37, -- NOTE: math.huge == 10e38
		enabled   = false,  --  loaded by default?
		handler   = true,
		api		  = true,
	}
end
local Echo = Spring.Echo
local f = VFS.Include("LuaUI\\Widgets\\UtilsFunc.lua")
local GetCameraHeight = f.GetCameraHeight
-- WG.Dependancies:Check(widget) 
-- local debugProps = {'name','isWobbling','isGtBuilt','isUnknown','critical','isEnemy','isAllied','isMine','id'} -- show the properties we want on units
-- local debugProps = {'name','isWobbling','isGtBuilt','isUnknown','critical','bworth','rworth'} -- show the properties we want on units
-- local debugProps = {'manualOrder'}
-- local debugProps = {'isIdling','isCloaked','defID','isIdle'}
-- local debugProps = {'id','builtBy'}
-- local debugProps = {'id','isWobbling'}
-- local debugProps = {'id','defID'}
-- local debugProps = {'id','moveType'}
-- local debugProps = {'name','id','autoguard','isInRadar'}
-- local debugProps = {'name','id','isInSight','isInRadar'}
-- local debugProps = {'isKnown'}
-- local debugProps = {'health'}
-- local debugProps = {'id','cost'}
local debugProps = {'id','isMine'}



-- local debugProps = false
local isCommDefID = {}
local isPlaneDefID = {}
local isFactoryDefID = {}
local isDefenseDefID = {}
for defID, def in pairs(UnitDefs) do
	local name = def.name
	if name:match("(dyn)") or name:match("_base") then
		isCommDefID[defID] = true
	end
	if name:match('bomber') or (name:match('plane') and not def.isFactory ) then
		isPlaneDefID[defID] = true
	end
	if def.isFactory and name~='staticrearm' and name~="striderhub" then
		isFactoryDefID[defID] = true
	end
	if name:find("turret") or name=='staticarty' or name=='staticheavyarty' or name=='staticantiheavy' then
		isDefenseDefID[defID] = true
	end
end
options_path = 'Hel-K/'..widget:GetInfo().name
------------- Partial DEBUG
local Debug = { -- default values
    active=false -- no debug, no hotkey active without this
    ,global=false -- global is for no key : 'Debug(str)'

    ,update = false


}
Debug.hotkeys = {
    active =            {'ctrl','alt','U'} -- this hotkey active the rest
    ,global =           {'ctrl','alt','G'}

    ,update = 			{'ctrl','alt','X'}
}

-------------

WG.SelectionMap = WG.SelectionMap or {n=0}
local SelectionMap = WG.SelectionMap
local debuggingUnit = {}


local CheckTime = f.CheckTime
local vunpack   = f.vunpack
local Page = f.Page

local currentFrame = Spring.GetGameFrame()
-- local selByID = {}
-- local selByUnit = {}
local createdByFactory = {}
local CMD = CMD
local DebugUnitCommand = f.DebugUnitCommand
local passiveCommands = {}
for name,id in pairs(CMD) do
	if type(name)=='string' and name:match('STATE') or name=='REPEAT' then
		passiveCommands[id]=true
	end
end



local customCmds = VFS.Include("LuaRules/Configs/customcmds.lua")

local spGetUnitDefID                = Spring.GetUnitDefID
local spGetAllUnits                 = Spring.GetAllUnits
local spGetMyTeamID                 = Spring.GetMyTeamID
local spGetUnitPosition             = Spring.GetUnitPosition
local spAreTeamsAllied              = Spring.AreTeamsAllied
local spGetUnitTeam                 = Spring.GetUnitTeam
local spValidUnitID               	= Spring.ValidUnitID
local spGetGameSeconds				      = Spring.GetGameSeconds
local spGetUnitHealth 				      = Spring.GetUnitHealth
local spIsReplay                    = Spring.IsReplay
local spGetSpectatingState          = Spring.GetSpectatingState
local spGetCommandQueue             = Spring.GetCommandQueue
local spGetUnitRulesParam           = Spring.GetUnitRulesParam
local spGetGameFrame                = Spring.GetGameFrame
local spGetUnitHealth               = Spring.GetUnitHealth
local spGetUnitIsDead               = Spring.GetUnitIsDead
local spGetUnitCurrentCommand       = Spring.GetUnitCurrentCommand
local spGetSelectedUnits            = Spring.GetSelectedUnits
local spGetGroundHeight             = Spring.GetGroundHeight
local spGetSelectedUnits            = Spring.GetSelectedUnits
local spuGetMoveType                = Spring.Utilities.getMovetype
local spValidFeatureID              = Spring.ValidFeatureID
local spGiveOrderToUnit             = Spring.GiveOrderToUnit
local spGetCameraState				= Spring.GetCameraState
local spGetUnitHealth				= Spring.GetUnitHealth
local spGetUnitLosState 			= Spring.GetUnitLosState

local UnitDefs = UnitDefs


local classByName,familyByName={},{}


do
	local families = {
		['sub']='ship',['bomber']='plane',['ship']='ship', -- put ship as key-value pair to check for gunship first, (indexed values are checked first in the iteration)
		'amph','strider','jump','spider','cloak','tank','veh','gunship','plane','shield','hover'
	}
	local unitClasses = {
	    raider = {
	        --planefighter = true,

	        shipscout = true,
	        shiptorpraider = true,
	        spiderscout = true,
	        shieldscout = true,
	        cloakraid = true,
	        shieldraid = true,
	        vehraid = true,
	        amphraid = true,
	        vehscout = true,
	        jumpraid = true,
	        hoverraid = true,
	        subraider = true,
	        tankraid = true,
	        gunshipraid = true,
	        gunshipemp = true,      
	        jumpscout = true,
	        tankheavyraid = true,

	    },
	    skirm = {
	        cloakskirm = true,
	        spiderskirm = true,
	        jumpskirm = true,
	        shieldskirm = true,
	        shipskirm = true,
	        amphfloater = true,
	        vehsupport = true,
	        gunshipskirm = true,
	        shieldfelon = true,
	        hoverskirm = true,
	    },
	    riot = {
	        amphimpulse = true, 
	        cloakriot = true,
	        shieldriot = true,
	        spiderriot = true,
	        spideremp = true,
	        jumpblackhole = true,
	        vehriot = true,
	        tankriot = true,
	        amphriot = true,
	        shiptorpraider = true,
	        hoverriot = true,
	        hoverdepthcharge = true,
	        gunshipassault = true,
	        shipriot = true,
	        striderdante = true,
	    },
	    assault = {
	        jumpsumo = true,
	        cloakassault = true,
	        spiderassault = true,
	        tankheavyassault = true,
	        tankassault = true,
	        shipassault = true,
	        amphassault = true,
	        vehassault = true,
	        shieldassault = true,
	        jumpassault = true,
	        hoverassault = true,
	        hoverheavyraid = true,
	        shipassault = true,
	        --bomberprec = true,
	        --bomberheavy = true,
	        gunshipkrow = true,
	        striderdetriment = true,
	    },
	    arty = {
	        cloakarty = true,
	        amphsupport = true,
	        striderarty = true,
	        shieldarty = true,
	        jumparty = true,
	        veharty = true,
	        tankarty = true,
	        spidercrabe = true,
	        shiparty = true,
	        shipheavyarty = true,
	        shipcarrier = true,
	        hoverarty = true,
	        gunshipheavyskirm = true,
	        tankheavyarty = true,
	        vehheavyarty = true,
	    },
	    special1 = {
	        cloakheavyraid = true,
	        vehcapture = true,    
	        spiderantiheavy = true,   
	        shieldshield = true,
	        cloakjammer = true,
	        --planescout = true,
	    },
	    special2 = {
	        gunshiptrans = true,    
	        shieldbomb = true,
	        cloakbomb = true,
	        gunshipbomb = true,
	        jumpbomb = true,
	        gunshipheavytrans = true,
	        subtacmissile = true,
	        spiderscout = true,
	        amphtele = true,
	        --bomberdisarm = true,
	        striderantiheavy = true,
	        striderscorpion = true,
	    },
	    special3 = {
	        cloaksnipe = true,
	        amphlaunch = true,
	        --planescout = true,
	    },
	    aaunit = {
	        gunshipaa = true,
	        shieldaa = true,
	        cloakaa = true,
	        vehaa = true,
	        hoveraa = true,
	        amphaa = true,
	        spideraa = true,
	        jumpaa = true,
	        tankaa = true,
	        shipaa = true,
	    },
	    conunit = {
	        amphcon = true,
	        planecon = true,
	        cloakcon = true,
	        spidercon = true,
	        jumpcon = true,
	        tankcon = true,
	        hovercon = true,
	        shieldcon = true,
	        vehcon = true,
	        gunshipcon = true,
	        shipcon = true,
	        planecon = true,
	        striderfunnelweb = true,
	    },

	}
	for className,classTable in pairs(unitClasses) do
		for unitName in pairs(classTable) do
			classByName[unitName]=className
		end
	end
	for _,unit in pairs(UnitDefs) do
		for altFamily,family in pairs(families) do
			if not tonumber(altFamily) and unit.name:match(altFamily) or unit.name:match(family) then
				familyByName[unit.name]=family
				break
			end
		end
	end
end
--[[local function FalsifyTable(T)
	for k in pairs(T) do T[k]=false end
end--]]


local CamUnits
local Cam
local idlingUnits = {}
local UnitDefs = UnitDefs
local Units,name
local UnitsByDefID
local unitModels = {}
local MyUnits
local MyUnitsByDefID
local UnitCallins
local rezedFeatures
local maxUnits = Game.maxUnits
local cache
local myTeamID = Spring.GetMyTeamID()
WG.allyCost=0
WG.enemyCost=0
WG.curAllyCost=0
WG.curEnemyCost=0

-- local teams = Spring.GetTeamList()
-- local isChickenGame, chickenTeams = false, {}
-- for _, teamID in pairs(teams) do
-- 	local teamLuaAI = Spring.GetTeamLuaAI(teamID)
-- 	if teamLuaAI and string.find(string.lower(teamLuaAI), "chicken") then
-- 		isChickenGame=true
-- 		chickenTeams[teamID]=true
-- 		--break
-- 	end
-- end

local checkTime=CheckTime("start")

local shift,meta = false,false
local isBomber = {['bomberprec']=true,['bomberdisarm']=true,['bomberriot']=true,['bomberheavy']=true}
local isE = {['energywind']=true,['energysolar']=true,['energyfusion']=true,['energysingu']=true}
local specialWeapons = {['raveparty']=true,['zenith']=true,['mahlazer']=true,['staticnuke']=true,['staticmissilesilo']=true,['staticheavyarty']=true} -- weapons that often need to be ordered manually
local UNKNOWN = {isUnknown=true,isEnemy=true,isRadarBleep=true,isWobbling=true,isInSight=false}
local UNKNOWN_PLANE = {isUnknown=true,isEnemy=true,isRadarBleep=true,isPlane=true,isWobbling=true,isInSight=false}

local function dumfunc()
	-- a dummy func
end
local copy = function(t,t2)
	for k,v in pairs(t2) do
		t[k] = v
	end
	return t
end
local function clear(t)
	for k in pairs(t) do
		t[k] = nil
	end
end

local function GetPos(self,threshold,mid) -- method of unit to get its position, to be used by any widget, threshold is the frame delta acceptance
    local pos = self.pos
	if mid then
		local update
		if not pos.midframe then
			pos.midframe = true
			pos.frame = currentFrame
			update = true
		elseif not self.isStructure and pos.frame < currentFrame + threshold then
			update = true
			pos.frame = currentFrame
		end
		if update then
			pos[1], pos[2], pos[3], pos[4], pos[5], pos[6] = spGetUnitPosition(self.id,true)
		end
		return pos[1], pos[2], pos[3], pos[4], pos[5], pos[6]
	end
    if not self.isStructure and pos.frame < currentFrame + threshold then
    	pos.midframe = false
    	pos.frame = currentFrame
        pos[1], pos[2], pos[3] = spGetUnitPosition(self.id)
    end
    return  pos[1], pos[2], pos[3]

end

local function IsImpulseUnit(ud)
	for _, w in pairs(ud.weapons) do
		local wd = WeaponDefs[w.weaponDef]
		if wd and wd.customParams and wd.customParams.impulse then
			return true
		end
	end
	return false
end
local impulseDefID = {}
for defID,def in ipairs(UnitDefs) do
	if IsImpulseUnit(def) then
		impulseDefID[defID] = true
	end
end
local jumperDefID = {}
for defID,def in ipairs(UnitDefs) do
    if not (def.name:match('plate') or def.name:match('factory')) then
        if def.customParams.canjump then
            jumperDefID[defID] = true
        end
    end
end
local CMD_RESURRECT = CMD.RESURRECT
local CMD_RECLAIM = CMD.RECLAIM


local function UpdateUnitCommand(id,defID,teamID)
	 -- Echo("teamID,myTeamID", teamID, myTeamID)
	-- if not (teamID) then -- never happening
	-- 	Echo('UnitsIDCard [WARN]: no team ID for unit '..id,teamID)
	-- 	teamID = Spring.GetUnitTeam(id)
	-- 	return
	-- end
	if defID and (teamID == myTeamID) then 
		-- local curC=spGetCommandQueue(id,1)[1]-- this crash when switching selected view in spec
		local queue = spGetCommandQueue(id, 1) 
		local curC = queue and queue[1]
		if curC and not passiveCommands[curC.id] then
			widget:UnitCommand(id,defID,teamID,curC.id,curC.params,curC.options,curC.tag)
		else
			-- widget:UnitIdle(id)
		end
	end
end

local function AddUnit(unit,id)
	Units[id]=unit

	local defID = unit.defID
	if not defID then return unit end

	if not UnitsByDefID[defID] then UnitsByDefID[defID]={} end
	UnitsByDefID[defID][id]=unit
	-- Echo('adding',unit.defID)

	if unit.isMine then
		MyUnits[id]=unit
		if not MyUnitsByDefID[defID] then MyUnitsByDefID[defID]={} end
		MyUnitsByDefID[defID][id]=unit
	end
	return unit
end
local function RemoveUnit(unit,id)
	if not Units[id] then 
		return
	end
	Units[id]=nil
	unit.GetPos = dumfunc
	local defID = unit.defID
	if not defID then return unit end
	if unit.isMine then
		MyUnits[id]=nil
		if MyUnitsByDefID[defID] then
			MyUnitsByDefID[defID][id]=nil
			if not next(MyUnitsByDefID[defID],nil) then MyUnitsByDefID[defID]=nil end
		end
	end
	if not UnitsByDefID[defID] then -- FIXME : somehow there's been a crash by nil check, Units[id] has been created without having it in the byDefID table, need to find where, the crash happened on UnitLeftRadar
		return unit
	end
	UnitsByDefID[defID][id]=nil
	if not next(UnitsByDefID[defID],nil) then UnitsByDefID[defID]=nil end
	return unit
end

local function ProduceIDCardOLD(id, defID, teamID)
	-- Echo('produce...',id,os.clock())
	local ud = UnitDefs[defID]
	name = ud.name
	local mine = teamID==myTeamID
	local allied = not mine and teamID ~= myTeamID and spAreTeamsAllied(teamID, myTeamID)
	local enemy = not (mine or allied)

	-- if update and Units[id] then
	-- 	return Units[id]
	-- end
	local moveType = spuGetMoveType(ud) or -1
	local isUnit = moveType>-1
	local pos = {spGetUnitPosition(id)}

	local unit
	local a,b,c,d,e = spGetUnitHealth(id)
	if enemy then
		unit = {
					 name                    = name
					,ud                      = ud
					,defID                   = defID
					,id                      = id
					,team                    = teamID
					,isEnemy                 = true
					,cost					 = ud.cost

		}
		if isUnit then
			unit.isUnit                  = true
			unit.isComm                  = isCommDefID[defID]
			unit.isPlane                 = isPlaneDefID[defID]
			unit.isGS                    = ud.isHoveringAirUnit--[[ud.airStrafe--]] and name ~= "athena" or nil
			unit.isTransport			 = ud.isTransport
		else
			unit.isStructure			 = true
		end

	else
		unit= {
			 name                    = name
			,ud                      = ud
			,maxHP                   = b
			,defID                   = defID
			,id                      = id
			,team                    = teamID
			,isMine                  = mine or nil
			,isAllied                = allied or nil
			,cost                    = ud.cost
			,frame                   = currentFrame
		} 
		if isUnit then
			unit.isUnit					 = true
			unit.isTransport			 = ud.isTransport
			local class					 = classByName[name] or 'unknown' 
			unit.class                   = class
			unit.family                  = familyByName[name] or 'unknown'
			unit.moveType				 = moveType
			if isPlaneDefID[defID] then
				unit.isPlane                 = true
				if isBomber[name] then
					unit.isBomber = true
				end
			elseif ud.isHoveringAirUnit then
				if name == 'athena' then
					unit.isAthena = true
				else
					unit.isGS = true
				end
			elseif jumperDefID[defID] then
				unit.isJumper = true
			end
			if name:match('scout') then
				unit.isScout = true
			elseif class=="conunit" then
				unit.isCon = true
			elseif name:match('strider') then
				unit.isStrider = true
			elseif isCommDefID[defID] then
				unit.isComm = true
			end
		else
			unit.isStructure             = true
			unit.isMex                   = name == "staticmex" or nil
			unit.isFactory               = isFactoryDefID[defID]
			unit.isCaretaker             = name == "staticcon" or nil
			unit.isDefense               = isDefenseDefID[defID]
			unit.isSpecialWeapon         = specialWeapons[name]
			unit.isStorage               = name == "staticstorage" or nil
			unit.class					 = 'unknown'
			unit.family					 = 'unknown'

			if isE[name] then
				if name=="energysolar" then
					unit.isSolar = true
				elseif name == "energywind" then
					unit.isWind = true
				elseif name == "energyfusion" then
					unit.isFusion = true
				end
			end

		end
		unit.isImpulse				 = impulseDefID[defID]
		if mine then
			unit.createpos = {pos[1], pos[2], pos[3]}

		end
	end
	unit.id = id
	unit.moveType				 = moveType
	unit.health = {a,b,c,d,e}
	unit.health.frame = currentFrame
	-- unit.pos   = {spGetUnitPosition(id)}
    -- Echo('produce ',id,unit.defID)

    -- if Units[id] then
    -- 	local _unit,unit = unit, Units[id]
    -- 	for k,v in pairs(unit) do
    -- 		unit[k]=nil
    -- 	end
    -- 	for k,v in pairs(_unit) do
    -- 		unit[k]=v
    -- 	end
    -- end
	return unit
end


local function ProduceIDCard(id, defID, teamID, camUnit)
	-- Echo('produce...',id,os.clock())

	local unit = {}
	local pos
	for k,v in pairs(camUnit) do
		unit[k] = v
	end
	pos = unit.pos

	-- local ud = UnitDefs[defID]
	-- name = ud.name
	local mine = teamID==myTeamID
	local allied = unit.isAllied or not mine and teamID ~= myTeamID and spAreTeamsAllied(teamID, myTeamID)
	-- local allied = not mine and teamID ~= myTeamID and spAreTeamsAllied(teamID, myTeamID)
	local enemy = not (mine or allied)
	-- if update and Units[id] then
	-- 	return Units[id]
	-- end

	-- local pos = {spGetUnitPosition(id)}

	-- local a,b,c,d,e = spGetUnitHealth(id)
	if enemy then
		
		unit.id                      = id
		unit.teamID                    = teamID
		unit.isEnemy                 = true
	else
		unit.id                      = id
		unit.teamID                    = teamID
		unit.frame                   = currentFrame
	 
		if mine then
			unit.isMine = true
			unit.createpos = {pos[1], pos[2], pos[3]}
		else
			unit.isAllied = true
		end
	end
	-- unit.health = {a,b,c,d,e}
	-- unit.health.frame = currentFrame
	-- unit.pos = pos
    -- Echo('produce ',id,unit.defID)

    -- if Units[id] then
    -- 	local _unit,unit = unit, Units[id]
    -- 	for k,v in pairs(unit) do
    -- 		unit[k]=nil
    -- 	end
    -- 	for k,v in pairs(_unit) do
    -- 		unit[k]=v
    -- 	end
    -- end
	setmetatable(unit, unitModels[defID].mt)

	return unit
end


local function CreateUnitModel(defID, ud)
	name = ud.name
	local moveType = spuGetMoveType(ud) or -1
	local isTransportable = not (ud.canFly or ud.cantBeTransported)
	local heavy
	if isTransportable then
		heavy = ud.customParams.requireheavytrans
	end
	local isUnit = moveType>-1

	local unit= {
		 name                    = name
		,ud                      = ud
		,maxHP                   = ud.health
		,defID                   = defID
		,cost                    = ud.cost or 0
	} 
	if isUnit then
		unit.isUnit					 = true
		unit.isTransport			 = ud.isTransport
		unit.isTransportable		 = isTransportable
		unit.heavy					 = heavy
		local class					 = classByName[name] or 'unknown' 
		unit.class                   = class
		unit.family                  = familyByName[name] or 'unknown'
		unit.moveType				 = moveType
		if isPlaneDefID[defID] then
			unit.isPlane                 = true
			if isBomber[name] then
				unit.isBomber = true
			end
		elseif ud.isHoveringAirUnit then
			if name == 'athena' then
				unit.isAthena = true
			else
				unit.isGS = true
			end
		elseif jumperDefID[defID] then
			unit.isJumper = true
		end
		if name:match('scout') then
			unit.isScout = true
		elseif class=="conunit" then
			unit.isCon = true
		elseif name:match('strider') then
			unit.isStrider = true
		elseif isCommDefID[defID] then
			unit.isComm = true
		end
	else
		unit.isStructure             = true
		unit.isMex                   = name == "staticmex" or nil
		unit.isFactory               = isFactoryDefID[defID]
		unit.isCaretaker             = name == "staticcon" or nil
		unit.isDefense               = isDefenseDefID[defID]
		unit.isSpecialWeapon         = specialWeapons[name]
		unit.isStorage               = name == "staticstorage" or nil
		unit.class					 = 'unknown'
		unit.family                  = familyByName[name] or 'unknown'

		if isE[name] then
			if name=="energysolar" then
				unit.isSolar = true
			elseif name == "energywind" then
				unit.isWind = true
			elseif name == "energyfusion" then
				unit.isFusion = true
			end
		end

	end
	unit.isImpulse				 = impulseDefID[defID]
	unit.moveType				 = moveType
	unit.model = unit
	return unit
end



local function UpdateGuarding(proteged,guard,change)
	local protegedCard,guardCard=Units[proteged],Units[guard]
	if change=="proteged killed" and protegedCard then
		for guard in pairs(protegedCard.isGuarded) do
			if Units[guard] then
				Units[guard].isGuarding=false
			end
		end
	elseif change=="unguarding" and protegedCard and guard then
		if protegedCard then
			protegedCard.escortNum            = protegedCard.escortNum-1

			if guard and protegedCard.isGuarded then protegedCard.isGuarded[guard]     = nil end
			if protegedCard.escortNum==0 then
				protegedCard.isGuarded=nil
			end
		end
		guardCard.isGuarding              = false
		
	elseif change=="new guard" and protegedCard and guard then

		if protegedCard.escortNum==0 then protegedCard.isGuarded={} end
		if guard and protegedCard.isGuarded then protegedCard.isGuarded[guard]     = true end
		protegedCard.escortNum            = protegedCard.escortNum+1
		guardCard.isGuarding=proteged
	 end
end

local spTraceScreenRay = Spring.TraceScreenRay
local spGetMouseState = Spring.GetMouseState

function widget:KeyPress(key,mods)
	shift,meta = mods.shift,mods.meta
    if Debug.CheckKeys(key,mods) then
        return true
    end

	local debug=true
    if key == 267 and mods.alt then -- 267 == KP_/
        local id = spGetSelectedUnits()[1] or WG.PreSelection_GetUnitUnderCursor()
        if id and Units[id] then
        	local obj = debuggingUnit[id]
        	if obj then
        		obj:Delete()
        	end
        	local newobj = f.DebugWinInit2(widget,(Units[id].name and Units[id].name .. ' ' or '') .. 'id '..id,Units[id])
        	newobj.win.OnHide = {
        		function(self)
        			newobj:Delete()
        			debuggingUnit[id] = nil
        		end
        	}
            debuggingUnit[id] = newobj
            
        end
    end

	if debug and mods.ctrl and key==118 then -- Ctrl+V
		-- above 2 units the api_cluster_detection widget is getting crashed by gui_recv_unit_indicator
		-- I don't try to debug it as it is useless
		local mx, my = spGetMouseState()
		local type, id = spTraceScreenRay(mx,my)
		if type == 'unit' then
			local team = spGetUnitTeam(id)
			if spAreTeamsAllied(spGetMyTeamID(), team) then
				local uid = Spring.GetSelectedUnits()[1]
				if uid then
					-- Echo('unit',uid,'team:',Spring.GetUnitTeam(uid),Spring.GetUnitAllyTeam(uid),Spring.IsUnitAllied(uid))
					Spring.ShareResources(team,"units") -- can only give own stuff, even with cheats active
				end
			end
		end
		return true
	end
	-- -- Spring.SendLuaRulesMsg("forceresign") -- tested ?
end
function widget:KeyRelease(key,mods)
	shift,meta = mods.shift,mods.meta
end
-- function widget:Update() -- this in case we have to Reload UnitsIDCards, we reload the widgets that depends on it
	-- 	-- we can't do that in Initialize for some reason

	-- --[[  local id=Spring.GetSelectedUnits()[1]
	-- 	if not id then return end
	-- 	local unit = Units[id]
	-- 	if not unit or not unit.isMine then return end--]]
	-- 	----Echo(Spring.GetUnitCurrentCommand(id))
	-- 	--*******--Echo("Spring.GetUnitWeaponTarget(id,1) is ", Spring.GetUnitWeaponTarget(id,1))
	-- 	----Echo(Units[unit].isGuarding)
	-- --[[  if unit.isGuarded then
	-- 	 -- --Echo(Units[unit].isGuarded)        
	-- 		for k,v in pairs(unit.isGuarded) do --Echo(unit.name.." is guarded by", Units[k].name.."("..k..")" ) end
	-- 	end
	-- 	if unit.isGuarding then

	-- 		--Echo(unit.name.." is guarding "..Units[unit.isGuarding].name)
	-- 	end
-- end--]]

function widget:CommandsChanged()
	clear(SelectionMap)
	local sel = spGetSelectedUnits()
	local n = #sel
	for i=1, n do
		local id = sel[i]
		SelectionMap[id] = Units[id]
	end
	SelectionMap.n = n
end



-- local CMD_FIRE_STATE = CMD.FIRE_STATE
-- local TABLE_2 = {2}
-- local TABLE_1 = {1,0}
-- local spuGetUnitFireState = Spring.Utilities.GetUnitFireState

function widget:UnitCloaked(id, defID, team)
	local unit=Units[id]
	if unit then
		unit.isCloaked=true
		-- if unit.isMine then
		-- 	local name = unit.name
		-- 	if name~='cloaksnipe' and name~='cloakaa' and name~='wolverine_mine' then
		-- 		local fireState = spuGetUnitFireState(id)
		-- 		if fireState ~= 0 then
		-- 			unit.uncloakedFireState = spuGetUnitFireState(id)
		-- 			TABLE_1[1] = 0
		-- 			spGiveOrderToUnit(id, CMD_FIRE_STATE, TABLE_1, 0)
		-- 		end
		-- 	end
		-- end
	end
end


function widget:UnitDecloaked(id, defID, team)
	local unit=Units[id]
	if unit then
		unit.isCloaked=false
		-- if unit.isMine then
		-- 	local fireState = unit.uncloakedFireState
		-- 	if fireState then
		-- 		TABLE_1[1] = fireState
		-- 		spGiveOrderToUnit(id, CMD_FIRE_STATE, TABLE_1, 0)
		-- 		unit.uncloakedFireState = nil
		-- 	end
		-- end
		-- if unit.isMine then spGiveOrderToUnit(id, CMD_FIRE_STATE, TABLE_2, 0) end
	end
end

function widget:GameFrame(gf)
	currentFrame = gf
	if checkResurrect then
		for id in pairs(checkResurrect) do
			local cmd,_,_,target = spGetUnitCurrentCommand(id)
			if cmd==CMD_RESURRECT then rezedFeatures[target-maxUnits]=true end
		end
		checkResurrect=nil
		return
	end
	if gf%30==0 and next(rezedFeatures) then
		for id in pairs(rezedFeatures) do
			if not spValidFeatureID(id) then rezedFeatures[id]=nil end
		end
	end
end

--Echo("CMD.ATTACK,CMD.REPAIR,CMD.RESURRECT,CMD.AREA_RECLAIM,CMD.AREA_REPAIR is ", CMD.ATTACK,CMD.REPAIR,CMD.RESURRECT,customCmds.AREA_RECLAIM,customCmds.AREA_REPAIR)

--for k,v in pairs(CMD) do if tostring(k):match(check) or tostring(v):match(check) then Echo(k,v) end end
-- function widget:UnitIdle(id)
-- 	local unit = Units[id]
-- 	if unit then 
-- 		unit.isIdling = true
-- 		unit.isIdle = true
-- 		-- Echo(unit.name..' is idling...')
-- 	end
-- 	idlingUnits[id]=true
-- end
-- local manualOrders={[CMD.ATTACK]=true,[CMD.REPAIR]=true,[CMD.RESURRECT]=true,[CMD.RECLAIM]=true,[CMD_RAW_BUILD]=true}


 -- note: cmdTag is not cmdTag, I think it is playerID, to know the tag, I think we must check the next round in widget:Update() in the unitCommandQueue
function widget:UnitCommand(id, defID, teamID, cmd, params--[[, opts, playerID,  tag, fromSynced, fromLua--]])
-- Echo("UnitCommand: ", id, defID, teamID, cmd, params, opts, playerID,  tag, fromSynced, fromLua)

	if cmd~=CMD_RESURRECT then
		return
	end
-- Echo("tag is ", tag)
	-- DebugUnitCommand(id, defID, teamID, cmd, params, opts, tag,fromSynced,fromLua)
	-- if fromLua then return end -- ignore automatic orders (jiggling around while attacking etc ...)
	-- if passiveCommands[cmd] then return end

	-- -- if idlingUnits[id] then
	-- -- 	local unit = Units[id]
	-- -- 	if unit then unit.isIdling = false end
	-- -- 	idlingUnits[id]=false
	-- -- end
	-- if teamID~=myTeamID then return end
	-- if cmd==CMD_RESURRECT then
		if params[2] then -- case this is an area resurrect, we can't know right now which feature is getting rezzed
			checkResurrect=checkResurect or {}
			checkResurrect[id]=true
		else
			rezedFeatures[params[1]-maxUnits]=true
		end
	-- end
	-- local unit=Units[id]
	-- if not unit then return end
--Echo("id, defID, teamID, cmd, params, opts, tag,fromSynced,fromLua is ", id, defID, teamID, cmd, params, opts, tag,fromSynced,fromLua)
--[[  if (cmd==25 or cmd==13924) and params[1]~=id then --(guard or area guard)
		UpdateGuarding(params[1],id,"new guard")
	elseif not (cmd==25 or cmd==13924) then
		if unit.isGuarding then
			----Echo('unguarded')
			UpdateGuarding(unit.isGuarding,id,"unguarding")
		end
	end--]]
	
	-- register manual target
	--if opts.internal and cmd==CMD.REPAIR then return end -- ignore command from smart builder
	--Echo("cmd is ", cmd)
	-- if opts.coded==9 then unit.isIdle = true return end -- ignore smart builder automatic orders
	-- local actualOrder = cmd==1 and params[2] or cmd
	-- if opts.shift or shift or meta then
	-- 	if unit.isIdle and manualOrders[actualOrder] or actualOrder<0 then unit.isIdle=false end
	-- 	return
	-- end
	-- if manualOrders[actualOrder] or actualOrder<0 then unit.isIdle=false else unit.isIdle=true end

--[[  if opts.coded==9 then unit.manualTargetIDs = nil return end -- ignore smart builder automatic orders
	if not opts.shift and not shift and not meta and cmd~=1 then unit.manualTargetIDs = nil end
	local targetID =  cmd==1  and not params[6] and params[4]
								 or not params[3] and params[1] -- unit target and not ground target
	if targetID and spValidUnitID(targetID) and not spGetUnitIsDead(targetID) then
		local manualTargetIDs = unit.manualTargetIDs
		if not manualTargetIDs then unit.manualTargetIDs={} ; manualTargetIDs = unit.manualTargetIDs end
		if manualTargetIDs[targetID] then
			manualTargetIDs[targetID]=nil
			if not next(manualTargetIDs,nil) then unit.manualTargetIDs=nil end
		else
			manualTargetIDs[targetID]=true
		end
	end--]]

	--if opts and opts.shift then --Echo("opts.shift is ", opts.shift) else --Echo('else') end
 
--[[  
	
	--Echo("UC:id, defID, teamID, cmd, opts, params, tag, playerID, fromSynced, fromLua is ", id, defID, teamID, cmd, opts, params, tag, playerID, fromSynced, fromLua)
	--Echo('OPTS:')
	Page(opts)
	--Echo('PARAMS')
	Page(params)
--]]
end
function widget:UnitCmdDone(unitID, defID, teamID, cmdID, cmdParams, cmdOptions, cmdTag, fromSynced, fromLua)

	-- if teamID~=myTeamID then return end
	-- local unit=Units[unitID]
	-- if not (unit and unit.isMine)then
	-- 	return
	-- end
	-- Attempt to track a manual order given
	-- if not unit then return end
	-- if unit.manualOrder and unit.manualOrder[1]==cmdID then unit.manualOrder=false end


	-- local nextcmd = spGetUnitCurrentCommand(unitID)
	-- Echo("CMD DONE:unitID, defID, teamID, cmdID, cmdParams, cmdOptions, cmdTag is ", unitID, defID, teamID, cmdID, cmdParams, cmdOptions, cmdTag)
	-- Echo('CMD DONE PARAMS',unpack(cmdParams))
	-- Echo('CMD DONE, next CMD?',nextcmd)
	-- if not nextcmd then unit.isIdle=true return end
	-- if manualOrders[cmdID] or cmdID<0 then
	-- 	if manualOrders[nextcmd] or nextcmd<0 then unit.isIdle=false else unit.isIdle=true end
	-- end
--[[  local manualTargetIDs = unit.manualTargetIDs
	if manualTargetIDs and manualTargetIDs[ cmdParams[1] ] and not cmdParams[3] then
		manualTargetIDs[ cmdParams[1] ]=nil
		if not next(manualTargetIDs,nil) then unit.manualTargetIDs=nil end
	end--]]
	--Page(cmdOptions)  
	--Page(cmdParams)
end
function widget:UnitCommandNotify(id, cmd, params, opts)
	-- Echo("UCN:id, cmd, params, opts is ", id, cmd, params, opts)

	-- Attempt to track a manual order given
	-- local unit = Units[id]
	-- if not unit then return end
	-- if not opts.shift then
	--   local order = {cmd, params, opts}
	--     unit.manualOrder = order
	-- end

end
local busyCmd = {
	[CMD.ATTACK]=true,
	[CMD.REPAIR]=true,
}
function widget:CommandNotify(cmd, params, options)
	-- Echo('CN',cmd,'opt:', (function()local str = '' for k,v in pairs(options) do str = str..','..k..'='..tostring(v) end return str end)(),unpack(params) )
	-- local isIdle = not (cmd<0 or busyCmd[cmd])

	-- for id in pairs(selByID) do
	-- 	if Units[id] then
	-- 		Units[id].isIdle = isIdle
	-- 	end
	-- end
	-- Attempt to track a manual order given
	-- if not options.shift then

	--   for id in pairs(selByID) do
	--     local unit = Units[id]
	--     if unit then unit.manualOrder = order end
	--   end
	-- end



	if cmd==CMD.RECLAIM and (not params[2] or params[5]) and Units[params[1]] then Units[params[1]].isGtReclaimed=true end
--[[  --Echo("id, params, options,a,b,c,d,e,f,g is ", id, params, options)
	Page(params)
	Page(options)--]]
end
function widget:UnitCommandNotify(id, cmd, params, options)
	if cmd==CMD.RECLAIM and (not params[2] or params[5]) then
		local target = params[1]
		if target and target ~= id and Units[target] then
			Units[target].isGtReclaimed=true
	 	end
	end

end

function widget:UnitCreated(id, defID, teamID,builderID) -- unit created can happen after unit finished ie when factory get plopped
	local camUnit = CamUnits[id]
	if not camUnit then
		return
	end
	local unit = Units[id]
	if unit and not unit.isUnknown then
		return
	end
	local unit = AddUnit(ProduceIDCard(id, defID, teamID, camUnit),id)

	unit.isGtReclaimed  = false
	unit.isGtBuilt = true --not spGetUnitRulesParam(id, "ploppee") -- don't need anymore
	-- unit.isInSight = true
	local builder = Units[builderID]

	if builder then
		unit.builtBy = builder.id

	end
	-- Echo("builder,unit.builtBy is ", builder,unit.builtBy)
	-- unit.isIdling=true
	-- Echo("created",id,unit.name)
	-- idlingUnits[id]=true
	if UnitCallins then for callin in pairs(UnitCallins) do callin(id, unit) end end
end

function widget:UnitFinished(id, defID, teamID)
	local camUnit = CamUnits[id]
	if not camUnit then
		return
	end
	local unit, recycled
	local oldUnit = Units[id]
	if oldUnit and oldUnit.isUnknown then
		oldUnit = false
	end
	if oldUnit then
		recycled = oldUnit.defID~=defID or oldUnit.teamID~=teamID
	end
	if not oldUnit or recycled then
		unit=AddUnit(ProduceIDCard(id, defID, teamID, camUnit),id)
	else
		unit = oldUnit
	end
	unit.isGtBuilt = false
	unit.isGtReclaimed = false
	-- unit.isInSight = true
	UpdateUnitCommand(id, defID, teamID)
	-- Echo('finished',id,unit.name,'idling?',unit.isIdling)
	if UnitCallins then for callin in pairs(UnitCallins) do callin(id, unit) end end
end
function widget:UnitReverseBuilt(id, defID, teamID)
	local unit = Units[id]
	if unit then 
		unit.isGtReclaimed = true
		unit.isGtBuilt = true
		if UnitCallins then for callin in pairs(UnitCallins) do callin(id, unit) end end
	end
end

function widget:UnitDestroyed(id, defID, teamID)
	local unit = Units[id]
	cache[id]=nil
	if not unit then return end
	RemoveUnit(unit,id)
	local cost = unit.cost or 0
	-- if unit.isEnemy then
	-- 	WG.enemyCost=WG.enemyCost+cost
	-- else 
	-- 	WG.allyCost=WG.allyCost+cost
	-- end

	-- if unit.isMine then 
	-- 	if unit.isGuarded then UpdateGuarding(id,nil,"proteged killed") end
	-- 	if unit.isGuarding then UpdateGuarding(unit.isGuarding,id,"unguarding") end
	-- end
	if UnitCallins then for callin in pairs(UnitCallins) do callin(id, nil,destroyedUnit) end end
end

function widget:UnitGiven(id, defID, to, from)
	-- Echo('given',defID,from,to)
		local unit=Units[id]
		if not unit or unit.isUnknown then
			local cached = cache[id]
			if cached then
				cache[id]=nil
			end
		end

		
		if unit then
			if spAreTeamsAllied(myTeamID,from) then
				return -- if it's a gift, it's already been treated in unitTaken
			else
				if not to then -- it crashed in some occasion in a chicken game when a player was capturing chicken, not each time one got captured, so I didnt have time to define what was the problem
					Echo('UnitsIDCard [WARN]: UnitGiven didnt report to whom unit is given',to)
					to = Spring.GetUnitTeam(id)
				end
				-- trigger the lines below, recreate IDCard, now IDCard of enemies are very basic compared to mine and allied
				RemoveUnit(unit,id)
			end
		end
		local _, _, _, _, BP = spGetUnitHealth(id)
		if (BP < 1) then 
			widget:UnitCreated(id, defID, to)
		else 
			widget:UnitFinished(id, defID, to)
		end
		unit = Units[id]
		-- need to merge progressively toward CamUnits
		local camUnit = CamUnits[id]
		if camUnit then
			for k,v in pairs(camUnit) do
				unit[k] = v
			end
		end
		if UnitCallins then for callin in pairs(UnitCallins) do callin(id, unit) end end
end

function widget:UnitTaken(id, defID, from,to)
	--widget:UnitDestroyed(id, defID, teamID)
	-- Echo('taken',defID,from,to)
	local _, _, _, _, BP = spGetUnitHealth(id)
	local unit = Units[id]
	if unit then
		RemoveUnit(unit,id)
	end
	if (BP < 1) then 
		widget:UnitCreated(id, defID, to)
	else 
		widget:UnitFinished(id, defID, to)
	end
	unit = Units[id]
	local camUnit = CamUnits[id]
	if camUnit then
		for k,v in pairs(camUnit) do
			unit[k] = v
		end
	end

	if UnitCallins then for callin in pairs(UnitCallins) do callin(id, unit) end end

end

function widget:UnitEnteredRadar(id,teamID)
	local unit
	local cached = cache[id]
	if cached then
		-- Debug.update(id,cached.name, 'entered radar, acquired from cache')
		if cached.isStructure then
			AddUnit(cached,id)
			-- local pos = cached.pos
			-- pos[1], pos[2], pos[3] = spGetUnitPosition(id)
			cached.isInRadar = true
			cached.isWobbling = false

			cache[id]=nil

		end

	end

	unit = Units[id]
	if unit then

		if unit.name then -- UnitEnteredRadar come after UnitEnteredLos when the unit is discovered by Los, another case is if the unit is a structure we knew, we ignore this
			-- Echo('unit '..id..' entered radar ',unit and unit.name,unit and unit.isWobbling and 'isWobbling' or '')
			-- unit.isInSight = false
			unit.isInRadar = true
			-- local pos = unit.pos
			-- pos[1], pos[2], pos[3] = spGetUnitPosition(id)
			if not unit.isStructure then unit.isWobbling=true end
			return
		end
	end

	-- Debug.update(id,'unknown', 'entered radar')
	local x, y, z = spGetUnitPosition (id)
	local gy = spGetGroundHeight(x,z)
	Units[id]= copy(
		{pos = {frame=currentFrame,x,y,z}, GetPos = GetPos, id = id}
		,CamUnits[id] or (y-gy>40 and UNKNOWN_PLANE or UNKNOWN)
	)



	-- Echo('unit entered radar',id, Units[id])
	-- Echo('unknown unit '..id..' entered radar ',unit and unit.isWobbling and 'isWobbling' or '')

	if UnitCallins then for callin in pairs(UnitCallins) do callin(id, unit,teamID) end end
end
function widget:UnitEnteredLos(id,teamID)
	local unit = Units[id]
	-- Echo('unit '..id..' entered LOS ',unit and unit.name,unit and unit.isRadarBleep and 'isBleep' or '',unit and unit.isUnknown and 'isUnknown' or '')
	if unit and unit.name then
		 -- don't redo if we already know this unit
		-- Debug.update(id,unit.name, 'entered LoS, we already know this unit')
		unit.isWobbling=false
		unit.isInSight = true
		local camUnit = CamUnits[id]
		if camUnit then
			for k,v in pairs(camUnit) do
				unit[k] = v
			end
		end

		return
	end
	local cached = cache[id]


	if cached then
		-- Debug.update(id,cached.name,'entered LoS','bring back from cache')
		unit = AddUnit(cached,id)
		-- local pos = cached.pos
		-- Echo('GOT FROM CACHE')
		-- pos[1], pos[2], pos[3] = spGetUnitPosition(id)

		cache[id]=nil
		unit.isWobbling=false
		unit.isInSight = true
		-- if unit.teamID ~= teamID and not spAreTeamsAllied(unit.teamID, teamID) then
		-- 	if unit.isEnemy then
		-- 		widget:UnitGiven(id,teamID, unit.teamID)
		-- 	else
		-- 		widget:UnitTaken(id,unit.teamID, teamID)
		-- 	end
		-- end
		local camUnit = CamUnits[id]
		if camUnit then
			for k,v in pairs(camUnit) do
				unit[k] = v
			end
		end
	else
		local _, _, _, _, BP = spGetUnitHealth(id)
		if BP<1 then
			widget:UnitCreated(id,spGetUnitDefID(id),teamID)
		else
			widget:UnitFinished(id,spGetUnitDefID(id),teamID)
		end
		-- Debug.update('enteredLoS',id,'produce',Units[id].name)
	end
	if UnitCallins then for callin in pairs(UnitCallins) do callin(id, unit,teamID) end end
end
function widget:UnitLeftLos(id,teamID)

	local unit = Units[id]
	if not unit then 
		-- Debug.update('not registered unit ',id,'left Los')
		return
	end
	unit.isInSight = false
	if not unit.isStructure then
		unit.isWobbling = true
	end
	local camUnit = CamUnits[id]
	if camUnit then
		for k,v in pairs(camUnit) do
			unit[k] = v
		end
	end

	-- Debug.update(id,unit.name,'left LoS')
	-- if UnitCallins then for callin in pairs(UnitCallins) do callin(id, unit) end end
end
function widget:UnitLeftRadar(id,teamID)
	--Echo('left radar',id)
	local unit = Units[id]
	if unit and unit.name then
		-- Debug.update(unit.name..' added to cache')
		-- unit.isWobbling=false
		unit.isInRadar = false

		local camUnit = CamUnits[id]
		if camUnit then
			for k,v in pairs(camUnit) do
				unit[k] = v
			end
		end
		if Cam.fullview == 1 then
			return
		end

		cache[id]=unit
	end
	RemoveUnit(unit,id)

	
	-- if UnitCallins then for callin in pairs(UnitCallins) do callin(id) end end
	----Echo("left radar", id)
end

--[[local oneSec=CheckTime()
function widget:Update()


	if oneSec("resume")>=1 then
			oneSec=CheckTime()
			heck("say", count)
			heck=CheckTime()
			count=0
	end

end--]]


local function Scan()
	------------- Get all units and wether they are on our side -----------------
--------------- Check their build Progress and sort them --------------------
	local defID,teamID
	local allUnits=spGetAllUnits()
	for _,id in ipairs(allUnits) do
		teamID = spGetUnitTeam(id)
		defID = spGetUnitDefID(id)
		local losState = spGetUnitLosState(id)
		local los = losState and losState.los
		-- Echo(defID,(teamID==myTeamID and "my" or spAreTeamsAllied(teamID, myTeamID) and "allied" or "enemy").." "..(defID and UnitDefs[defID].name or "unknown").." #"..id )
		if los then
			-- local _, _, _, _, BP = spGetUnitHealth(id)
			widget:UnitEnteredLos(id,teamID)

			-- if (BP and BP < 1) then 
			-- 	widget:UnitCreated(id, defID, teamID)
			-- else 
			-- 	widget:UnitFinished(id, defID, teamID)
			-- end
			-- if Units[id] and cache[id] and cache[id].builtBy then
			-- 	Units[id].builtBy = cache[id].builtBy
			-- end

		else 
			widget:UnitEnteredRadar(id,teamID)
		end

		for _,id in ipairs(allUnits) do
			teamID = spGetUnitTeam(id)
			defID = spGetUnitDefID(id)
			UpdateUnitCommand(id,defID,teamID)
		end
	end
end

function widget:AfterInit(dt) -- this replace widget:Update() for the first round after Initialize()
	if next(Units.subscribed) then
		for w_name in pairs(Units.subscribed) do
			if widgetHandler.knownWidgets[w_name] then
				Echo('[' .. widget:GetInfo().name .. ']:' .. w_name..' is dependant, reloading it...')
				Spring.SendCommands("luaui enablewidget "..w_name)
				local w = widgetHandler:FindWidget(w_name)
				if not w then
					Echo('[' .. widget:GetInfo().name .. ']: [WARN]: There was a problem reloading' .. w_name)
				elseif w.UnitUpdate then
					if not UnitCallins then Units.UnitCallins={} ; UnitCallins=Units.UnitCallins end
					UnitCallins[w.UnitUpdate]=true
				end
			else
				Echo('[' .. widget:GetInfo().name .. ']: [WARN]: ' .. 'widget' .. w_name .. " is unknown, couldn't reload it")
			end

		end
	end
	widget.Update = widget._Update
	widget._Update = nil
	-- widgetHandler:RemoveWidgetCallIn('Update',self)
end



local f = VFS.Include('LuaUI\\Widgets\\UtilsFunc.lua')
-- local DisableOnSpec = f.DisableOnSpec(_,widget,'setupSpecsCallIns') -- initialize the call in switcher
function widget:Initialize()
	if --[[spIsReplay() or--]] string.upper(Game.modShortName or '') ~= 'ZK' then
		widgetHandler:RemoveWidget(self)
		return
	end 
	-- if Spring.GetSpectatingState() then
	-- 	widgetHandler:RemoveWidget(self)
	-- 	return
	-- end
	Echo('UnitsIDCard Loading...')
	CamUnits = WG.Cam and WG.Cam.Units
	Cam = WG.Cam
	if not CamUnits then
		Echo(widget:GetInfo().name .. 'requires HasViewChanged')
		widgetHandler:RemoveWidget(widget)
		return
	end

	Debug = f.CreateDebug(Debug,widget,options_path)
	-- DisableOnSpec(widgetHandler,widget)
	-- CheckIfSpectator()

	myTeamID = spGetMyTeamID()  
	local oldUnits = WG.UnitsIDCard
	WG.UnitsIDCard = {
		-- subscribed = oldUnits and oldUnits.subscribed or {}
		subscribed = {}
		,UnitCallins= {}
		,byDefID= {}
		,mine={ byDefID = {} }
		,cache= oldUnits and oldUnits.cache or {}
		,rezedFeatures = {}
		,active = true
		,creation_time = os.clock()
	}
	Units=WG.UnitsIDCard
	rezedFeatures = Units.rezedFeatures
	cache=Units.cache
	-- in case of reboot, reuse both old units and old cache for Scan(), work around to reidentify static building that spGetDefID don't identify even though it has been discovered in the past and icon is showing
	if oldUnits then
		for id,unit in pairs(oldUnits) do 
			if tonumber(id) and not unit.isUnknown and not cache[id] then
				cache[id]=unit
			end
		end
		-- for id,unit in pairs(cache) do Echo(id,unit.name) end
	end
	--
	UnitsByDefID=Units.byDefID
	MyUnits=Units.mine
	MyUnitsByDefID=MyUnits.byDefID
	UnitDefs=UnitDefs
	for defID, ud in pairs(UnitDefs) do
		unitModels[defID] = CreateUnitModel(defID, ud)
		unitModels[defID].mt = {__index = unitModels[defID]}
	end
	Scan()

	-- widget._Update = widget.Update
	-- widget.Update = widget.AfterInit --

	-- if subscribed then -- reload widgets that depends on this widget
	-- 	for w_name in pairs(subscribed) do

	-- 		if widgetHandler.knownWidgets[w_name] then 
	-- 			-- for some reason it is not possible to enable widget in Initialize so we will do it in the first  Update round aka AfterInit func

	-- 				-- Spring.SendCommands("luaui disablewidget "..w_name)
	-- 				WG.UnitsIDCard.subscribed[w_name]=true
	-- 		end
	-- 	end
	-- end
	WG.UnitsIDCard.active = true
	-- WG.Dependancies:Check(self)
end

function widget:Shutdown()
	-- Echo('UnitsIDCards shutdown')
	if WG.UnitsIDCard then
		WG.UnitsIDCard.active = false
	end
	-- Echo("<< ".. widget:GetInfo().name .." shutting Down... >>")
	-- if not (WG.UnitsIDCard and WG.UnitsIDCard.subscribed) then
	-- 	Echo('[WARN]','WG.UnitsIDCard' .. (not WG.UnitsIDCard and '' or '.subscribed ') .. 'does not exist')
	-- 	return
	-- end
	-- if next(WG.UnitsIDCard.subscribed) then
	-- 	Echo(widget:GetInfo().name .. ' disable dependant widgets...')
	-- else
	-- 	Echo('...no dependant widget subscribed.')
	-- 	return
	-- end
	-- local keepSubscribed = {}
	-- for w_name in pairs(WG.UnitsIDCard.subscribed) do
	-- 	local w = widgetHandler:FindWidget(w_name)
	-- 	if w then
	-- 		Echo("...disabling ".. w_name)
	-- 		-- Spring.SendCommands("luaui disablewidget "..w_name)
	-- 		widgetHandler:RemoveWidget(w)
	-- 		keepSubscribed[w_name] = true
	-- 	else
	-- 		Echo('[WARN]'.. w_name .." subscribed but is not active")
	-- 	end
	-- end
	-- WG.UnitsIDCard.subscribed = keepSubscribed
	if Debug.Shutdown then
		Debug.Shutdown()
	end
	-- Echo('>> UnitsIDCard end disabling <<')
	--widgetHandler.UpdateSelection = widgetHandler.__UpdateSelection
	--GameOver is irreversable with cheats, thus removing 
	Echo(">>>>> ! UnitsIDCard Shutdown ! <<<<<")
end



---------- updating teamID
local MyNewTeamID = function()
    myTeamID = Spring.GetMyTeamID()
end
widget.TeamChanged = MyNewTeamID
widget.PlayerChanged = MyNewTeamID
widget.Playeradded = MyNewTeamID
widget.PlayerRemoved = MyNewTeamID
widget.TeamDied = MyNewTeamID
----------
-- Memorize Debug config over games
function widget:SetConfigData(data)
    if data.Debug then
        Debug.saved = data.Debug
    end
end
function widget:GetConfigData()
	if Debug.GetSetting then
    	return {Debug=Debug.GetSetting()}
    end
end

do -- debugging
	local spValidUnitID                 = Spring.ValidUnitID
	local spGetUnitPosition             = Spring.GetUnitPosition
	local glColor                       = gl.Color
	local glText                        = gl.Text
	local glTranslate                   = gl.Translate
	local glBillboard                   = gl.Billboard
	local glPushMatrix                  = gl.PushMatrix
	local glPopMatrix                   = gl.PopMatrix
	local green, yellow, red, white, blue     = f.COLORS.green, f.COLORS.yellow, f.COLORS.red, f.COLORS.white, f.COLORS.blue
	local orange =  f.COLORS.orange
	local glLists = {}
	function widget:DrawWorld()
		if not (debugProps and debugProps[1] and Debug()) then
			return
		end
		if (Cam and Cam.relDist or GetCameraHeight(spGetCameraState()))>2000 then
			return
		end
		for id,unit in pairs(Units) do
			if tonumber(id) then
				local ix,iy,iz = spGetUnitPosition(id)
				if ix then
					glPushMatrix()
					glTranslate(ix,iy,iz)
					glBillboard()
					local color = unit.isMine and green or unit.isAllied and blue or unit.isEnemy and orange
					glColor(color)
					local off=0
					for _,prop_name in ipairs(debugProps) do
						local prop = unit[prop_name]

						if prop then
							off=off-6
							-- if prop_name == 'manualOrder' then
							-- 	prop_name,prop = prop[1],true
							-- end
							glText((prop_name and prop_name~='name' and prop_name.." " or '')..(type(prop)=="boolean" and "" or tostring(prop)), 0,off,5,'h')
						end
					end
					glPopMatrix()
				end
			end
		end
		glColor(white)
	end
end

function widget:PlayerChanged()
	if spGetSpectatingState() then
		-- widgetHandler:RemoveWidget(widget)
	end
end


f.DebugWidget(widget)
