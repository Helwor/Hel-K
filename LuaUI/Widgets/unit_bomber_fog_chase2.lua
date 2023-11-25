
function widget:GetInfo()
	return {
		name      = "Bomber Fog Chase2",
		desc      = "Adds several features to Likho, Raven, Phoenix and Thunderbird:\n1. If an attacked unit becomes cloaked, bombers will hit its presumptive location (accounting for last seen position and velocity)\n2. Submerged units can be targeted, the water surface above the target will be hit, accounting for units speed. Raven may hit fast submerged units like Seawolf.\n3. If a targeted unit got destroyed by something else, and there was not a queued command, the bomber will return to air factory or airpad, to avoid dangerous circling at the frontline.\n4. In contrast to 'Smart Bombers' widget (which should be disabled to use this one), this widget not only temporarily turns on the 'Free Fire' state when Attack Move is issued, but also discards the Attack Move command after firing. Thus the Attack Move becomes one-time action rather than a kind of a state.",
		author    = "rollmops -- rewrote Helwor",
		date      = "2022",
		license   = "GNU GPL, v2 or later",
		layer     = -math.huge,
		enabled   = false  --  loaded by default
	}
end

--------------------------------------------------------------------------------
-- Speedups
--------------------------------------------------------------------------------
local Echo = Spring.Echo
local f = VFS.Include("LuaUI\\Widgets\\UtilsFunc.lua")
local sqrt = math.sqrt

local spGetUnitPosition         = Spring.GetUnitPosition
local spGiveOrderToUnit         = Spring.GiveOrderToUnit
local spGetTeamUnits            = Spring.GetTeamUnits
local spGetUnitDefID            = Spring.GetUnitDefID
local spEcho                    = Spring.Echo
local spGetCommandQueue			= Spring.GetCommandQueue
local spGetUnitCommands         = Spring.GetUnitCommands
local spGetUnitCurrentCommand	= Spring.GetUnitCurrentCommand
local spGetUnitVelocity         = Spring.GetUnitVelocity
local spGetUnitHealth           = Spring.GetUnitHealth
local spGetSpecState            = Spring.GetSpectatingState
local spIsUnitInLos             = Spring.IsUnitInLos
local spGetUnitTeam             = Spring.GetUnitTeam
local spValidUnitID				= Spring.ValidUnitID
local spGetGameFrame			= Spring.GetGameFrame
local spGetPositionLosState		= Spring.GetPositionLosState
local spGetUnitIsDead			= Spring.GetUnitIsDead
local spGetGroundHeight			= Spring.GetGroundHeight
local spGetUnitRulesParam 		= Spring.GetUnitRulesParam
local spGetUnitWeaponState		= Spring.GetUnitWeaponState
local spGetUnitWeaponHaveFreeLineOfFire = Spring.GetUnitWeaponHaveFreeLineOfFire
local spGetUnitIsRepeat			= Spring.GetUnitIsRepeat
local spGetUnitWeaponTestRange 	= Spring.GetUnitWeaponTestRange
local spGetUnitLosState			= Spring.GetUnitLosState
local spGetUnitHeight			= Spring.GetUnitHeight

local CMD_ATTACK            	= CMD.ATTACK -- same number (20) as LOOPBACKATTACK
local CMD_REMOVE                = CMD.REMOVE
local CMD_INSERT                = CMD.INSERT
local CMD_OPT_ALT               = CMD.OPT_ALT
local CMD_STOP                  = CMD.STOP
local CMD_OPT_INTERNAL          = CMD.OPT_INTERNAL
local CMD_OPT_SHIFT             = CMD.OPT_SHIFT
local CMD_FIGHT           		= CMD.FIGHT
local CMD_FIRE_STATE            = CMD.FIRE_STATE
local CMD_FIRESTATE_HOLDFIRE    = CMD.FIRESTATE_HOLDFIRE
local CMD_FIRESTATE_FIREATWILL  = CMD.FIRESTATE_FIREATWILL
local CMD_WAIT					= CMD.WAIT
local CMD_STOP					= CMD.STOP
local CMD_PATROL				= CMD.PATROL

local customCmds                = VFS.Include("LuaRules/Configs/customcmds.lua")
local CMD_REARM                 = customCmds.REARM    -- 33410
local CMD_RAW_MOVE              = customCmds.RAW_MOVE -- 31109
local CMD_AIR_MANUALFIRE		= customCmds.AIR_MANUALFIRE
local TABLE_ZERO = {0}
local EMPTY_TABLE = {}
local _
local attackingOrder = {
	[CMD_ATTACK] = true,
	[CMD_FIGHT] = true,
	[CMD_PATROL] = true,
	[CMD_AIR_MANUALFIRE] = true,
}
--------------------------------------------------------------------------------
-- Config
--------------------------------------------------------------------------------
local TARGET_TIMEOUT = 120 
local TARGET_DELETE_TIME = 200 -- to avoid deleting/remaking targets everytime, we let the target live a bit before destroying it
local FAST_SPEED = 96 -- for now removed, non practical
local predictWhenFast = false
local unloadClearAttacks = true
local updateNow = {}
local updateBomberNow = {}
local timeouts = {}
local selectedBombers = {}
local gameFramesInterval = 8
local checkReturn = {}
-- only for debugging
local Points = {}
local yellow = {1,1,0,1}
local blue = {0,0,1,1}


local mapSizeX, mapSizeZ = Game.mapSizeX, Game.mapSizeZ
local function clamp(x,z,threshold)
	if x < threshold then x = threshold elseif x > mapSizeX - threshold then x = mapSizeX - threshold end 
	if z < threshold then z = threshold elseif z > mapSizeZ - threshold then z = mapSizeZ - threshold end 
	return x,z
end

local function VelFromPoses(pos1, pos2, frameDiff)
	local x1, y1, z1 = unpack(pos1)
	local x2, y2, z2 = unpack(pos2)

	local velx, vely, velz = (x2 - x1)/frameDiff, (y2 - y1)/frameDiff, (z2 - z1)/frameDiff
	local speed = (velx^2 + vely^2 + velz^2) ^ 0.5
	return velx, vely, velz, speed
end

local ownReturn, fogPursueTime, movePursue, Debug

options_path = 'Hel-K/Bomber Fog Chase 2'
options_order = {'own_return','fog_timeout','clear_attacks_on_unload','move_pursue','predict_fast','debug'}
options = {}
options.own_return = {
	name = 'Rearm to my pads',
	type = 'bool',
	value = true,
	desc = 'Bomber go rearm to our own closest pad.',
	OnChange = function(self)
		ownReturn = true
	end
}
options.fog_timeout = {
	name = 'Fog TimeOut',
	desc = 'How long we hope finding that unit gone out of radar until returning to the fold',
	type = 'number',
	min = 0.5, max = 20, step = 0.25,
	value = 5,
	OnChange = function(self)
		fogPursueTime = self.value * 30
	end

}

options.clear_attacks_on_unload = {
	name = 'Clear all attacks on unload',
	type = 'bool',
	value = unloadClearAttacks,
	OnChange = function(self)
		unloadClearAttacks = self.value
	end

}
options.move_pursue = {
	name = 'Pursue with move, no blind bomb',
	type = 'bool',
	value = movePursue,
	OnChange = function(self)
		movePursue = self.value
	end

}

options.predict_fast = {
	name = 'Predict on Fast Target',
	desc ='experimental, might hurt your own unit, in progress',
	type = 'bool',
	value = predictWhenFast,
	OnChange = function(self)
		predictWhenFast = self.value
	end

}
options.debug = {
	name = 'Debug',
	type = 'bool',
	value = false,
	OnChange = function(self)
		if self.value then
			Debug = function(...)
				Echo(...)
				return true
			end
		else
			Debug = function() end
		end
	end

}
-- giving default value until config is loaded
for _,opt in pairs(options) do
	opt:OnChange()
end
--


local ravenUntargettable = {
	planescout = true,
	planelightscout = true,
	planefighter = true,
	planeheavyfighter = true,
	bomberprec = true,
	bombernapalm = true,
	bomberheavy = true,
	bomberriot = true,
	bomberdisarm = true,
	bomberassault = true,

	gunshipemp = true,
	gunshipbomb = true,
	gunshipraid = true,

	dronelight = true,
	droneheavyslow = true,

}
local ravenUntargettableDefID = {}
local immobileDefID = {}
local speedDefID = {}
local ravenCanHitDefID = {}
local fastSpeedDefID = {}
local spuGetMoveType = Spring.Utilities.getMovetype

for defID, def in pairs(UnitDefs) do
	if not spuGetMoveType(def) then
		immobileDefID[defID] = true
		ravenCanHitDefID[defID] = true
	else
		if ravenUntargettable[def.name] then
			ravenUntargettableDefID[defID] = true
		else
			local speed = def.speed
			speedDefID[defID] = speed
			if speed >= FAST_SPEED then
				fastSpeedDefID[defID] = true
			else
				ravenCanHitDefID[defID] = true
			end
		end
	end
end

local bombersDefID = {}
for name, projSpeed in pairs({bomberheavy = 12.5, bomberdisarm = 100, bomberriot = 9, bomberprec = 5,--[[untested:--]] bomberstrike = 5, bomberassault = 5}) do
	local def = UnitDefNames[name]
	bombersDefID[def.id] = {
		name = def.name,
		humanName = def.humanName,
		projectileSpeed = projSpeed,
	}
end
-- local bombersDefID = { -- The four managed bombers types. Projectile speed adjusted manually.
-- 	[UnitDefNames.bomberheavy.id ] = {humanName = UnitDefNames.bomberheavy.humanName,  projectileSpeed = 12.5, },
-- 	[UnitDefNames.bomberdisarm.id] = {humanName = UnitDefNames.bomberdisarm.humanName, projectileSpeed = 100,},
-- 	[UnitDefNames.bomberriot.id  ] = {humanName = UnitDefNames.bomberriot.humanName,   projectileSpeed = 9,  },
-- 	[UnitDefNames.bomberprec.id  ] = {humanName = UnitDefNames.bomberprec.humanName,   projectileSpeed = 5.5,},
-- }

--------------------------------------------------------------------------------
-- Constants
--------------------------------------------------------------------------------

local myTeamID          = Spring.GetMyTeamID()
local myAllyTeamID      = Spring.GetMyAllyTeamID()

local airpadDefID       = UnitDefNames.staticrearm.id
local airFactoryDefID   = UnitDefNames.factoryplane.id
local airPalteDefID     = UnitDefNames.plateplane.id

local currentFrame

--------------------------------------------------------------------------------
-- Globals
--------------------------------------------------------------------------------

local bombers = {}  -- Bomber Class Objects, per bomber
local WATCH_ID

local targets = {}
-- Targeted units. Several bombers could have the same target, so targets' data resides in this table:
-- [unitID] -> { inLos=bool, inRadar=bool, inWater=bool, lastKnownPos={x,y,z}, vel={x,y,z,speed}, lastSeen=currentFrame }
-- inLos updated by UnitEnteredLos/UnitLeftLos
-- inRadar updated by UnitEnteredRadar/UnitLeftRadar
-- inWater, lastKnownPos, vel(ocity), and lastSeen updated repeatedly in GameFrame() while target is in LoS,
-- that's because, while position can be obtained in UnitLeftLos(), velocity cannot, so
-- for data consistency, all are obtained in GameFrame().

-- following are own only, not allied; used as a destination to return if the target gone and there are no queued commands.
local airpads   = {}    -- [unitID] -> {x,y,z} (position)
local airFacs   = {}    -- [unitID] -> {x,y,z}
local airPlates = {}    -- [unitID] -> {x,y,z}
local myAirpads = {}
--------------------------------------------------------------------------------
-- Functions
--------------------------------------------------------------------------------



local function GetHumanName(unitID)
	return spGetUnitDefID(unitID) and UnitDefs[spGetUnitDefID(unitID)] and UnitDefs[spGetUnitDefID(unitID)].humanName or "noname"
end

local function GetAimPosition(unitID)
	local _,_,_, x, y, z = spGetUnitPosition(unitID, false, true) -- last 2 args: bool return midPos , bool return aimPos
	if z then
		return {x, y, z}
	end
end
local function IdentifyTarget(target, targetID)
	local targetDefID = spGetUnitDefID(targetID)
	if not targetDefID then
		return
	end

	local isImmobile = immobileDefID[targetDefID]
	if isImmobile then
		target.isImmobile = true
	else
		target.isFast = fastSpeedDefID[targetDefID]
		target.ravenNoFlyingTarget = ravenUntargettableDefID[targetDefID]
	end
	target.defID = targetDefID
end

local function BombersPursue(targetID, target)
	for _, bomber in pairs(bombers) do
		if bomber.target == targetID then
			-- the command is removed when unit leave radar, we have to note it
			updateNow[targetID] = target
			local immobile = target.isImmobile

			if not immobile then
				-- a targetted pos will be estimated until/unless the unit is reentering radar
				-- unfortunately there is no cheap way I found to discern if the unit has left radar because it vanished or because it just get out
				timeouts[targetID] = currentFrame + fogPursueTime
			end
			Debug('bomber fog pursue ' .. (immobile and 'static ' or 'moving ') .. 'target ' .. targetID)	
			return
			-- local bx,by,bz = unpack(bomber:GetPosition(0))
			-- if bx then
			-- 	local dist = ((bx - targetPos[1])^2 + (bz - targetPos[3])^2) ^0.5
			-- 	if dist < 2000 then
			-- 		Debug('bomber pursue ', targetID)
			-- 		attached  =true
			-- 		bomber:HitTargetPosition(targetPos)
			-- 	elseif not timeout then
			-- 		-- time out, in case the radar coverage will come back soon ?
			-- 		attached = true
			-- 		Debug('bomber fog pursue ',targetID)	
			-- 		timeout = true
			-- 	end
			-- end
		end
	end
	if timeout then
		timeouts[targetID] = currentFrame + fogPursueTime
	end
end
local function MixedBombersHitTarget(targetID, targetPos)
	for id, bomber in pairs(bombers) do
		if bomber.target == targetID then
			if bomber.name == 'bomberheavy' then
				bomber:HitTargetPosition(targetPos)
			else
				spGiveOrderToUnit(id, CMD_ATTACK, targetID, CMD_OPT_INTERNAL)
			end
		end
	end
end
local function BombersHitTargetPosition(targetID, targetPos)
	for _, bomber in pairs(bombers) do
		if bomber.target == targetID then
			bomber:HitTargetPosition(targetPos)
		end
	end
end

local function BombersHitTargetID(targetID)
	for id, bomber in pairs(bombers) do
		if bomber.target == targetID then
			bomber:HitTargetID(targetID)
		end
	end
end
local function TargetTimeOut(targetID)
	timeouts[targetID] = currentFrame + TARGET_TIMEOUT
end
local function TargetIsGone(targetID, delete)
	Debug('target ' .. targetID ..' is gone')
	for id, bomber in pairs(bombers) do
		if bomber.target == targetID then
			bomber.target = nil
			-- spGiveOrderToUnit(id, CMD_REMOVE, CMD_ATTACK, CMD_OPT_ALT)
			bomber:CancelLast()
			if spGetCommandQueue(id,0) == 1 then
				Debug('Bomber ' .. id .. ' has gone target ' .. targetID ..  ' and only one command in queue, returning to base')
				bomber:Return()
			end
		end
	end
	targets:decrease(targetID, true, delete)
end

local function UpdateTarget(targetID, target)
	if target.updated == currentFrame then
		return
	end
	target.updated = currentFrame
	if target.count == 0 then
		if target.delete <= currentFrame then
			targets[targetID] = nil
			Debug(' -- orphaned target ' .. targetID .. ' TTL has expired.')
		-- else
		-- 	Debug(' -- target ' .. targetID .. 'TTL is ' .. math.round((target.delete - currentFrame)/30))
		end
		return
	elseif target.inRadar and spGetUnitIsDead(targetID) then -- GetUnitIsDead is expensive so we avoid using it without condition
		Debug(' -- target ' .. targetID .. ' has just died.')
		TargetIsGone(targetID, true, true)
		return
	end
	-- if not target.inRadar then
	-- 	return
	-- end
	local lastSeen = target.lastSeen
	-- Debug("target.lastSeen is ", lastSeen,'in los', target.inLos,'in radar', target.inRadar,'vel?', target.vel)
	local pos, vx,vy,vz,v 
	if target.inLos then
		pos = GetAimPosition(targetID)
		if not target.isImmobile then
			vx,vy,vz,v = spGetUnitVelocity(targetID)
		end
	elseif target.inRadar then -- 
		pos = GetAimPosition(targetID)
		if not target.isImmobile and lastSeen then
			-- get approximate velocity
			-- Debug("pos1, pos2 is ", pos1, pos2)
			vx, vy, vz, v = VelFromPoses(target.lastKnownPos, pos, currentFrame - lastSeen)
		end
		-- Debug('in radar, pos ?',pos and pos.z)
	end

	if pos then
		-- Echo("v is ", v)
		if vx and v then
			target.vel = {x=vx, y=vy, z=vz, speed=v}
		end
		target.lastKnownPos = pos
		-- Points[1] = {color = yellow,unpack(pos)}
		target.lastSeen     = currentFrame
		lastSeen = currentFrame
	elseif not target.lastSeen then
		Debug('target' .. targetID .. ' has never been located !') -- may happen rarely (never yet) if the unit is updated for the first time in game frame instead of Update, and the unit go out of radar in that same frame?
		TargetIsGone(targetID)
		return
	elseif target.vel and currentFrame - lastSeen > 60 then
		Debug('target last known position is too old to predict current')
		target.vel = nil
	end
	-- local targetDefID = target.defID
	-- Debug('targetID', targetID, "targetDefID is ", target.defID, 'name:', target.defID and UnitDefs[target.defID].name)

	local ravensTreated

	if pos and target.ravenNoFlyingTarget then
		target.flying = pos[2] > spGetGroundHeight(pos[1], pos[3]) + 60
		if target.flying then 
			-- Debug('flying target bad for raven, removing ', targetID)

			for id, bomber in pairs(bombers) do
				if bomber.target == targetID then
					if bomber.name == 'bomberprec' or bomber.name == 'bomberassault' then
						bomber:RemoveTarget(true)
					end
					-- WATCH_ID = id
					-- Debug('bomber ' .. id .. ' target correct: ' .. bomber.target)
				end
			end
			ravensTreated = true
		end
		if target.count == 0 then
			-- no more bomber attached to this target
			return
		end
	elseif pos and pos[2] < 0 then
		if not target.height then
			target.height = spGetUnitHeight(target.id)
		end
		if target.height and target.height < -pos[2] then
			for id, bomber in pairs(bombers) do
				if bomber.target == targetID then
					if bomber.name == 'bomberstrike' then
						bomber:RemoveTarget(true)
						Debug('bomber strike' .. id .. ' cannot reach under water: ' .. targetID)
					end
					-- WATCH_ID = id
					-- Debug('bomber ' .. id .. ' target correct: ' .. bomber.target)
				end
			end
		end
	end



	local vel = target.vel
	local likhoWantGround = pos and pos[2] < 0 

	local anyWantGround = not pos and not target.flying
	-- local nonLikhoWantGround = target.isFast and target.vel
	local nonLikhoWantGround = predictWhenFast and vel and vel.speed > 2 -- 
	-- Debug("target.isFast, target.vel is ", target.isFast, target.vel)
	local targetPos
	if anyWantGround or likhoWantGround or nonLikhoWantGround then
		if not vel then
			-- skip
		elseif pos then -- having pos means we have the current pos and dont need to guess a base location blindly
			targetPos = pos
		else
			-- guessing the base location of the target

			local lastPos = target.lastKnownPos
			local gy = spGetGroundHeight(lastPos[1], lastPos[3])
			local cancelled = false
			if lastPos[2] - math.max(gy,0) > 45 then
				cancelled = true
				Debug('not blind bombing flying unit')
			end
				-- skip
			if not cancelled then
				local frameDiff = currentFrame - lastSeen
				local x,y,z = 
					lastPos[1] + vel.x * frameDiff,
					lastPos[2] + vel.y * frameDiff,
					lastPos[3] + vel.z * frameDiff
				-- Echo("((x - lastPos[1])^2 + (z - lastPos[3])^2) is ", ((x - lastPos[1])^2 + (z - lastPos[3])^2)^0.5)
				targetPos =  {
					x,y,z
				}
				if Debug() then
					Echo('guessing the location',unpack(targetPos))

				end
				-- Points[1] = {color = blue, unpack(lastPos)}
				-- points[2] = {color = yellow, unpack(targetPos)}
			end
		end
	end
	-- Echo("anyWantGround, nonLikhoWantGround is ", anyWantGround, nonLikhoWantGround)
	local wasInWater
	if pos then
		if pos[2] < 0 then
			target.inWater = true
			-- BombersHitTargetPosition(targetID, pos)
			-- MixedBombersHitTarget(targetID, pos)
		elseif target.inWater then -- was submerged but not now
			wasInWater = true
			target.inWater = false
			-- BombersHitTargetID(targetID)
		end
	end

	for id, bomber in pairs(bombers) do
		if bomber.target == targetID then
			-- WATCH_ID = id	
			if bomber.name == 'bomberprec' then

				if (anyWantGround or nonLikhoWantGround) --[[and targetPos--]] then
					bomber:HitTargetPosition(targetPos, nonLikhoWantGround) -- 2nd arg: targetting ground is not necessary, avoid if too far away
				else
					bomber:HitTargetID(targetID)
				end

			elseif bomber.name == 'bomberheavy' then
				if (likhoWantGround or anyWantGround) --[[and targetPos--]] then
					-- Debug('likho want ground')
					bomber:HitTargetPosition(targetPos)
				else
					-- Debug('likho want target')
					bomber:HitTargetID(targetID)
				end
			else
				-- if (nonLikhoWantGround or anyWantGround) and targetPos then
				-- 	-- Debug('any want ground')
				-- 	bomber:HitTargetPosition(targetPos, nonLikhoWantGround) -- 2nd arg == targetting ground is not necessary, avoid if too far away				else
				-- end
				bomber:HitTargetID(targetID)
			end
			-- Debug('bomber ' .. id .. ' target correct: ' .. bomber.target)
		end
	end
end
-- to debug "Bad command from..." messages in log; see AllowCommandParams in gadgets.lua which issues these msgs.
--local SIZE_LIMIT = 10^8
--local function CheckCommandParams(cmdParams)
--	for i = 1, #cmdParams do
--		if (not cmdParams[i]) or cmdParams[i] ~= cmdParams[i] or cmdParams[i] < -SIZE_LIMIT or cmdParams[i] > SIZE_LIMIT then
--			Debug("Bad command: i=",i,"param=",cmdParams[i])
--		end
--	end
--end
--local function DebugGiveOrder(...)
--	CheckCommandParams(select(3, ...))
--	spGiveOrderToUnit(...)
--end
local targetsMethods = {}
local huge = math.huge
setmetatable(targets, { __index = targetsMethods}) -- we put methods aside so pairs loop is not annoyed by those functions, targets will only contains targetIDs=target pairs
function targetsMethods:create(targetID)
	local inLos = spIsUnitInLos(targetID, myAllyTeamID)
	local target = {inRadar = true, inLos = inLos, id = targetID, count = 0, delete = huge}
	timeouts[targetID] = nil
	IdentifyTarget(target, targetID)
	self[targetID] = target
	Debug(' -- new target ' .. targetID .. ' -- ')
	return target
end
function targetsMethods:increase(targetID)
	local target = self[targetID] or self:create(targetID)
	target.count = target.count + 1
	target.delete = huge
	return target
	-- Debug('target', targetID, 'count', target.count)
end
function targetsMethods:decrease(targetID, all, delete)
	if not targetID then
		return
	end
	local target = self[targetID]
	if not target then
		return
	end
	if delete then
		Debug(' -- target ' .. targetID .. ' is removed definitively -- ')
		self[targetID] = nil
		return
	end
	target.count = target.count - (all and target.count or 1)
	-- Debug('target', targetID, 'count', target.count)
	if target.count == 0 then
		-- self[targetID] = nil
		Debug(' -- target ' .. targetID .. ' will be removed in ' .. TARGET_DELETE_TIME ..' frames -- ')
		target.delete = currentFrame + TARGET_DELETE_TIME
	end
end

--------------------------------------------------------------------------------
-- Bomber Class and its Methods
--------------------------------------------------------------------------------


local bomberClass = {}
local bomberMT = {__index = bomberClass}
function bomberClass:New(unitID, unitDefID)
	local o = {}
	local defID = unitDefID or spGetUnitDefID(unitID)
	local def = bombersDefID[defID]
	setmetatable(o, bomberMT)
	o.id            = unitID
	o.defID         = defID
	o.humanName     = def.humanName
	o.name			= def.name
	o.weaponSpeed   = def.projectileSpeed
	o.speed			= def.speed
	o.attackMove    = false
	o.unloaded		= true
	o.pos 			= {frame = currentFrame, spGetUnitPosition(unitID)}
	                -- Commands added by UnitCommand, removed (restored) by RestoreQueuedCmds
	return o
end

local done = 0
function bomberClass:CancelLast()
	local lastCommand = self.lastCommand

		 -- work around to remove a command that may have not yet returned to us due to server ping, we repeat the last command given with OPT_SHIFT, that will automatically remove it and seemlessly get replaced in the same time by our new command

	if not lastCommand[3] then
		-- local current = spGetCommandQueue(self.id,1)[1]
		-- Echo('got really that command?',current and current.params[1])
	end
	local cmd = movePursue and lastCommand[3] and CMD_RAW_MOVE or CMD_ATTACK
	spGiveOrderToUnit(self.id, cmd, not lastCommand[3] and lastCommand[1] or lastCommand, CMD_OPT_SHIFT)
	self.lastCommand = nil

end
function bomberClass:Order(p1,p2,p3)
	-- if self:CheckUnload() then
	-- 	Debug('ordering while unloaded !')
	-- end
	local lastCommand = self.lastCommand
	if lastCommand then
		if p1 == lastCommand[1] and (not p3 or p2 == lastCommand[2] and p3 == lastCommand[3]) then
			return
		end
		if p3 and not lastCommand[3] then
			spGiveOrderToUnit(self.id, CMD_UNIT_CANCEL_TARGET, 0, 0) -- remove eventual target set on unit
		end
	end

	-- Debug('inserting',params[1], 'unloaded ?',self:CheckUnload())
	local cmd = p3 and movePursue and CMD_RAW_MOVE or CMD_ATTACK
	spGiveOrderToUnit(self.id, CMD_INSERT, {0, cmd, CMD_OPT_SHIFT + CMD_OPT_INTERNAL, p1,p2,p3}, CMD_OPT_ALT)
	-- Debug('removing',lastCommand[1])
	if lastCommand then
		-- Debug('new command',select(1,...), 'cancel last command',lastCommand[1])
		self:CancelLast()
	end
	self.lastCommand = {p1,p2,p3}
	return true
end
function bomberClass:HitTargetID(targetID)
	self:Order(targetID)
end
function bomberClass:HitTargetPosition(targetPos, cancelIfFar)
	-- For cloaked and submerged targets, hit their position with "Force Fire Point".
	-- Approximating ballistic trajectory with constant speed trajectory, see:
	-- https://playtechs.blogspot.com/2007/04/aiming-at-moving-target.html
	-- if self.stopOrdering then
	-- 	Debug('predicted')
	-- 	return
	-- end
	if not (targetPos) then
		return
	end

	local targetID = self.target 
	local target = targets[targetID]
	local x,y,z = unpack(self:GetPosition(1))
	if cancelIfFar then
		-- local tx,_,tz = spGetUnitPosition(targetID)
		-- if tx then
		-- 	local dist = ((tx-x)^2 + (tz-z)^2)^0.5
		-- 	if dist > 1000 then
		-- 		too far, just stick to id targetting for now
		-- 		Debug('too far, targetting unit for now')
		-- 		self:HitTargetID(targetID)
		-- 		return
		-- 	end
		-- end
	end
	local vel = target.vel
	if not vel then
		Debug('no vel, targetting pos')
		self:Order(targetPos)
		return
	elseif vel.speed < 1  and target.inLos then
		Debug('current speed is low, targetting unit')
		self:HitTargetID(targetID)
		return
	end
	local tx,ty,tz = unpack(targetPos)
	local dx,dy,dz = tx-x, ty-y, tz-z
	-- relative position of the target (in relation to bomber's position)
	-- original algorithm uses relative velocity,
	-- but it seems bombers' weapons speed doesn't depend on bomber's speed, -- no it doesn't
	-- hence using target's absolute velocity.
	local ovx, ovy, ovz, ov = spGetUnitVelocity(self.id)
	local vx = vel.x
	local vy = vel.y
	local vz = vel.z
	local speed = vel.speed
	-- Debug("vx,vy,vz is ", vx,vy,vz)
	-- Debug("self.weaponSpeed, targets[self.target].vel.speed is ", self.weaponSpeed, targets[self.target].vel.speed)
	local a = self.weaponSpeed^2 - speed^2
	--if a < 0.01 then
		-- should not happen as weapon speed > target speed -- yes it happens for raven targetting darts and the like
		-- return
	--end
	local b = dx * vx + dy * vy + dz * vz 
	-- local b = dx * (vx+ovx)/2 + dy * (vy+ovy)/2 + dz * (vz+ovz)/2
	-- local b = dx + dy + dz
	-- b = b / 2
	local c = dx^2 + dy^2 + dz^2 -- dist3D between target pos and bomber pos

	-- Echo("ov is ", ov)
	local d = b^2 + a * c

	if d >= 0 then
		local t = (b + sqrt(d)) / a
		if t > 750 then
			Debug('prediction too far off, capping')
			t = 750
		end
		--local t2 = (b - sqrt(d)) / a
		--if t2 > 0 then Debug("T2 POSITIVE: t=", t, "t2 = ", t2) end    -- should not happen
		-- if math.abs(t * speed) > 2000 then
		-- 	Debug('prediction too far off, targetting unit')
		-- 	self:HitTargetID(targetID)
		-- 	return
		-- end
		-- Echo("dx,dy,dz is ", dx,dy,dz,'b',b,'d',sqrt(d))
		-- Echo("vx*t, vy*t, vz*t is ", vx*t, vy*t, vz*t)
		-- Echo("b is ", b)
		local aimX, aimY, aimZ =
			tx + vx * t,
			ty + vy * t,
			tz + vz * t
		-- Debug("aimX, aimY,aimZ is ", aimX, aimY,aimZ,t,a)
		local cAimX, cAimZ = clamp(aimX, aimZ, 16)
		local cAimY = aimY
		if cAimX ~= aimX or cAimZ ~= aimZ then
			local height = aimY - spGetGroundHeight(aimX, aimZ)
			local distRatio = ((cAimX-x)^2 + (cAimZ-z)^2) ^ 0.5 / ((aimX-x)^2 + (aimZ-z)^2) ^ 0.5
			cAimY = spGetGroundHeight(cAimX, cAimZ) + height * distRatio
		end
		-- doesnt work unfortunately, we make another workaround in UnitCommand
		-- local ovx,ovy,ovz,ov = spGetUnitVelocity(self.id) 
		-- local inRange
		-- for i=1, gameFramesInterval do
		-- 	local futX, futY, futZ =
		-- 		cAimX -  ovx * i,
		-- 		cAimY -  ovy * i,
		-- 		cAimZ -  ovz * i

		-- 	inRange = spGetUnitWeaponTestRange(self.id,2,futX,futY,futZ)
		-- 	if inRange then
		-- 		break
		-- 	end
		-- end
		-- if inRange then
		-- 	-- work around to avoid spamming new positions as the bomber gonna shoot on the next one,
		-- 	-- if not done, the newly inserted poses, even cancelled afterward, might trigger a duplicate insertion of REARM before the end of the course, if user queued moving position after the attack
		-- 	self.stopOrdering = true
		-- end
		-- Debug('predicting unit pos with vel',math.round(os.clock()))

		local dist_predicted = ((cAimX - targetPos[1])^2 + (cAimZ - targetPos[3])^2)^0.5
		if dist_predicted > 1700 then
			Debug('prediction goes too far ' .. dist_predicted .. ' targetting unit')
			self:HitTargetID(targetID)
			return
		end	
		self:Order(cAimX, cAimY, cAimZ)

	else
		Debug ("d is negative, targetting unit")  
		self:HitTargetID(targetID)
		return
	end
end
function bomberClass:AddTarget(targetID)
	if self.target then
		targets:decrease(self.target)
	end
	self.target = targetID
	self.lastCommand = {targetID}
	return targets:increase(targetID)
end
function bomberClass:RemoveTarget(cancel, Return)
	local targetID = self.target
	targets:decrease(targetID)
	self.target = nil
	if targetID and cancel then
		self:CancelLast()
	else
		self.lastCommand = nil
	end
	if Return then
		self:Return()
	end
	return targetID
end
function bomberClass:CheckUnload()
	-- NOTE: when waiting for an unload, reloadFrame < currentFrame will  come first, few moment later noammo will comes up
	-- when waiting for a load, reloadFrame is irrelevant and only noammo will tell us
	local name = self.name
	local noammo = spGetUnitRulesParam(self.id,'noammo')
	local reloaded = noammo==nil or  noammo == 0
	if self.unloaded and not reloaded then
		return true
	end
	-- local reloaded = reloadFrame1 <= currentFrame
	local reloadFrame
	if reloaded then
		-- local angle, reloaded, reloadFrame, salvo, stockpile = spGetUnitWeaponState(self.id, weapNum)
		local _
		local weapNum = name == 'bomberprec' and 2 or 1
		_,_,reloadFrame = spGetUnitWeaponState(self.id, weapNum)
		reloaded = reloadFrame <= currentFrame
	end
	Debug(self.humanName .. "#" .. self.id .. " RELOADED?: " .. tostring(reloaded) .. " ... noammo is ", noammo,'reloadFrame',reloadFrame, 'currentFrame', currentFrame)

	if reloaded and self.unloaded then
		Debug(' -- ' .. self.humanName .. ' reloaded --')
	end
	if not reloaded and not self.unloaded then
		if unloadClearAttacks then
			spGiveOrderToUnit(self.id, CMD_REMOVE, CMD_ATTACK, CMD_OPT_ALT)
		end

	end
	self.unloaded = not reloaded
	-- Debug("weap2 is ", angle2, reloaded, reloadFrame, salvo2, stockpile)
	return not reloaded
end
function bomberClass:GetPosition(threshold)
	local pos = self.pos
	if currentFrame < pos.frame + threshold then
		return pos
	end
	pos.frame = currentFrame
	pos[1], pos[2], pos[3] = spGetUnitPosition(self.id)
	-- Echo("pos[3] is ", pos[3])
	return pos

end
function bomberClass:GetClosestPad(t, pos)
	local closest
	local dist = math.huge
	local bx,by,bz = unpack(pos or self:GetPosition(15))
	if bz then
		for id, pad in pairs(t) do
			local thisdist = ((bx-pad[1])^2 + (bz-pad[3])^2) ^ 0.5
			if thisdist < dist then
				dist = thisdist
				closest = pad
			end
		end
	end
	return closest
end

function bomberClass:UpdateState(cmd, params, shift, meta, stop) -- TODO: IMPLEMENT META

	local id, bomber = self.id, self
	local targetID
	if cmd == CMD_ATTACK then
		targetID = not params[2] and params[1]
		if params[4] then
			bomber.areaAtt = true
			-- wait in unitCommand to get the target
			return true
		end
		if targetID then
			if stop or spGetUnitIsDead(targetID) or not spValidUnitID(targetID) then
				targetID = false
			end
		end
	end
	local target
	if bomber.target then
		if not targetID then

			-- Echo('no targetID in UpdateState')
			local removeGroundTarget =  meta and bomber.lastCommand and bomber.lastCommand[3]
			local currentTgtID = bomber.target
			if removeGroundTarget then -- queueing the current target
				Debug(id .. 'remove target ground and requeuing target ID ' .. currentTgtID)
				local cmd = movePursue and CMD_RAW_MOVE or CMD_ATTACK
				spGiveOrderToUnit(id, CMD_INSERT,{0, cmd, CMD_OPT_SHIFT + CMD_OPT_INTERNAL, currentTgtID}, CMD_OPT_ALT)
			end
			
			bomber:RemoveTarget(removeGroundTarget)
			-- spGiveOrderToUnit(id, CMD_INSERT,{0, CMD_UNIT_CANCEL_TARGET, 0, 0}, CMD_OPT_ALT)
		elseif bomber.target == targetID then
			local lastCommand = bomber.lastCommand
			if shift then -- shift is only reported from CommandNotify in some special condition, reminder: UpdateState only work on the current order
				-- the user reclicked the same current target, we cancel the command to come if it's not a direct attack order
				if lastCommand and lastCommand[3] then -- we are predicting position, there will be an order to attack directly the unit instead of cancelling, so we prevent that order to be achieved by repeating it

					bomber:RemoveTarget(true) -- remove target and cancel the last ground target command
					local cmd = movePursue and CMD_RAW_MOVE or CMD_ATTACK
					spGiveOrderToUnit(bomber.id, cmd, targetID, CMD_OPT_INTERNAL + CMD_OPT_SHIFT)
				else
					bomber:RemoveTarget(false) -- just remove the target without cancelling the attack, the engine will do it by itself
					-- spGiveOrderToUnit(bomber.id, CMD_ATTACK, targetID, CMD_OPT_INTERNAL + CMD_OPT_SHIFT)
					spGiveOrderToUnit(id, CMD_UNIT_CANCEL_TARGET, 0, 0) -- yet we gotta remove the eventual set target
				end
			elseif not meta then
				-- the user reclicked the same target, there will be an attack order we want to cancel if we are predicting position
				if lastCommand and lastCommand[3] then
					bomber.lastCommand = {targetID} -- we tell our system that the last command is attacking the unit so it will cancel it
					updateNow[targetID] = targets[targetID] -- for cancelling it ASAP
				end
			else

			end
		else
			target = bomber:AddTarget(targetID)
		end
	elseif targetID then
		target = bomber:AddTarget(targetID)
	end
	-- Echo('update','target',bomber.target,'cmd',cmd)

	if cmd == CMD_FIGHT then
		spGiveOrderToUnit(id, CMD_FIRE_STATE, CMD_FIRESTATE_FIREATWILL, CMD_OPT_INTERNAL)
		bomber.attackMove = true
	elseif bomber.attackMove then
		spGiveOrderToUnit(id, CMD_FIRE_STATE, CMD_FIRESTATE_HOLDFIRE, CMD_OPT_INTERNAL)
		-- spGiveOrderToUnit(id, CMD_REMOVE, CMD_FIGHT, CMD_OPT_ALT)
		bomber.attackMove = false
		if not cmd and not bomber.unloaded then
			bomber:Return()
		end
	end
	if target then
		spGiveOrderToUnit(id, CMD_UNIT_CANCEL_TARGET, 0, 0)
	end
	return true, target
end
local rand = math.random
function bomberClass:Return(rearm, shift)
	local from
	local queue = spGetCommandQueue(self.id,-1)
	for i=1, #queue do
		local order = queue[i]
		if order.id == CMD_RAW_MOVE then
			Echo('raw move params', unpack(order.params))
		end
		if order.id == CMD_RAW_MOVE and order.params[3] then
			from = order.params
		end
	end
	local pad = self:GetClosestPad(myAirpads,from)
	if not pad then
		return
	end
	Debug(' -- bomber ' .. self.id .. ' return to own pad ' .. (rearm and 'for rearming' or ''),os.clock())
	local opt = CMD_OPT_INTERNAL + (shift and CMD_OPT_SHIFT or 0)
	if rearm then
		-- NOT giving rearm command, the engine will issue the rearming once bomber has arrived close to the airpad
		-- spGiveOrderToUnit(self.id, CMD_INSERT, {shift and -1 or 0, CMD_REARM, CMD_OPT_INTERNAL, pad.id}, CMD_OPT_ALT )
		-- return true
	end
	if not self.returned or self.returned + 45 < currentFrame then 
		---- workaround
		-- it appears the engine (?) ignore a same raw move order sent twice recently at same location, even though the command order is visible, it is not applied  (NoDuplicateOrders has nothing to do with it).
		local r = rand()
		local posNeg1 = rand()<0.5 and -1 or 1
		local posNeg2 = rand()<0.5 and -1 or 1
		pad = {pad[1] + 64 * r * posNeg1, pad[2], pad[3] + 64 * r * posNeg2 }
	end
	self.returned = currentFrame
	if rearm then
		-- Echo('shift?',shift)
		spGiveOrderToUnit(self.id, CMD_INSERT, {shift and -1 or 0, CMD_RAW_MOVE, CMD_OPT_INTERNAL, unpack(pad)}, CMD_OPT_ALT )
		return true
	end



	spGiveOrderToUnit(self.id, CMD_RAW_MOVE, pad, opt)


end



--------------------------------------------------------------------------------
-- Callins
--------------------------------------------------------------------------------


-- NOTE: The position one can get with spGetUnitPosition in UnitLeftLos is as precise as a wobbling radar dot, varying by 64 elmos as far as my tests goes
-- HOW THIS SHENANINGAN WORK:
-- The visibility is organized by square of 32, pretty much the footprints and center of lotus builds, center formula: x=floor(x/32)*32q + 16, z=floor(pz/32)*32 + 16
-- Therefore we cannot get from this if a unit has left our LoS or just vanished before our eyes (it should be something we can get from a widget)
-- only solution is to get unit position prior to when it leave LoS which is costly
-- ALSO NOTE: checking pos in GameFrame at the same frame than UnitLeftLos got triggered would give us the real position,
-- but GameFrame occur before UnitLeftLos, then we would need to continuously checking GameFrame
-- ALSO NOTE TOO: Update know the last position of a unit before GameFrame,
-- but it can happen multiple frames in GameFrame will be processed until a next Update occur (depending if your comp takes time  drawing I suppose)
-- in any case, Update will still know the new position of a unit before GameFrame (!)

local function tableString(t)
	if not t then
		return tostring(t)
	end
	local str = ''
	for k,v in pairs(t) do
		str = str .. tostring(k) .. '=' .. tostring(v) .. ', '
	end
	return str:sub(1,-3)
end


function widget:UnitLeftLos(unitID, unitTeam, allyTeam, unitDefID)
	-- Echo(unitID, math.round(os.clock()),'left los')
	-- local _,_,_,x,y,z = spGetUnitPosition(unitID,true)
	-- Points[1] = {x,y,z}
	if targets[unitID] then
		--Debug("Target Left Los:", GetHumanName(unitID), unitID)
		targets[unitID].inLos = false
		local target = targets[unitID]
		if not target.isImmobile then
			target.defID = false
		end
		updateNow[unitID] = targets[unitID]
	end
end
function widget:UnitEnteredLos(unitID, unitTeam, allyTeam, unitDefID)
	if targets[unitID] then
		if spGetUnitIsDead(unitID) then
			TargetIsGone(unitID,true)
		else
			local target = targets[unitID]
			if target.count > 0 then
				timeouts[unitID] = nil
			end
			--Debug("Target Entered Los:", GetHumanName(unitID), unitID)
			target.inLos = true
			if not target.defID then
				IdentifyTarget(target, unitID)
			end
			updateNow[unitID] = target
		end
	end
end


function widget:UnitLeftRadar(unitID)
	-- Also called when a unit leaves LOS without any radar coverage.
	-- For widgets, this is called just after a unit leaves radar coverage,
	-- so widgets cannot get the position of units that left their radar.
	-- Echo(unitID, math.round(os.clock()),'left radar')
	if targets[unitID] then
		local target = targets[unitID]
		if target.count == 0 then
			return
		end
		--Debug("Target Left Radar:", GetHumanName(unitID), unitID)
		target.inRadar = false
		local pos = target.lastKnownPos
		if pos then
			-- cannot detect vanished 
			-- TESTER CA
			-- local visible, losState, inRadar, jammed, identified = spGetPositionLosState(pos.x, pos.y,pos.z)
			-- if not inRadar then
			-- 	-- last known pos was in radar and not anymore
			-- end
			-- if target.defID and not target.isImmobile then
		-- 	return
			-- end
			BombersPursue(unitID, target)

			-- timeouts[targetID] = currentFrame + TARGET_TIMEOUT
			-- BombersHitTargetPosition(unitID, pos,false,true) -- will continue to get adjusted commands from GameFrame()
		else
			Debug('left radar without pos, removing target', unitID)
			-- TargetTimeOut(unitID)
			TargetIsGone(unitID, true)
		end
	end
end

function widget:UnitEnteredRadar(unitID, unitTeam, allyTeam, unitDefID)
-- Also called when a unit enters LOS without any radar coverage.

	if not targets[unitID] then
		return
	end
	local target = targets[unitID]
		--Debug("Target Entered Radar:", GetHumanName(unitID), unitID)
	target.inRadar = true
	if target.count>0 then
		if timeouts[unitID] then
			timeouts[unitID] = nil
			updateNow[unitID] = target
		end

		-- local pos = GetAimPosition(unitID)
		-- if pos and pos[2] then
		-- 	target.lastKnownPos = pos
		-- 	target.lastSeen     = currentFrame
		-- 	if pos[2] >= 0 then -- if y<0 (submerged), will get commands from GameFrame
		-- 		BombersHitTargetID(unitID)
		-- 	end
		-- end

	end
end
function widget:GameFrame(gameFrame)
	currentFrame = gameFrame
	-- for id, bomber in pairs(selectedBombers) do
	-- 	-- local ret1, ret2, ret3, ret4
	-- 	-- if bomber.receivedOrder and bomber.receivedOrder[3] then
	-- 	-- 	ret1, ret2 = bomber:CheckUnload(false, bomber.receivedOrder)
	-- 	-- end
	-- 	-- if bomber.lastCommand and bomber.lastCommand[3] then
	-- 	-- 	ret3, ret4 = bomber:CheckUnload(false, bomber.lastCommand)
	-- 	-- end
	-- 	-- Debug(ret1, ret2, ret3, ret4)
	-- end
	for id, bomber in pairs(updateBomberNow) do
		-- Echo('queue',spGetCommandQueue(id,0))
		widget:UnitCmdDone(id, _, _, _, _, EMPTY_TABLE)
		updateBomberNow[id] = nil
	end

	for id, bomber in pairs(checkReturn) do
		-- Echo('queue',spGetCommandQueue(id,0))
		if spGetCommandQueue(id,0) == 0 then
			Debug('bomber ' .. bomber.id .. " don't have any more order, returning to base")
			bomber:Return()
		end
		checkReturn[id] = nil
	end
	for targetID, frame_timeout in pairs(timeouts) do
		if gameFrame >= frame_timeout then
			-- targets:decrease(targetID, true)
			Debug('target gone on time out',targetID)
			TargetIsGone(targetID)
			timeouts[targetID] = nil
		end
	end
	if gameFrame % gameFramesInterval ~= gameFramesInterval - 1 then
		if next(updateNow) then
			Debug('UPDATING TARGETS in GAME FRAME!')
			for targetID, target in pairs(updateNow) do -- this is for debugging, we dont want new updating to be done in here 
				-- (which is in the next frame) but in Update; just after the CommandNotify callin, unfortunately UnitCmdDone get triggered after update, so we will have to wait for the next GameFrame trigger
				UpdateTarget(targetID, target)
				updateNow[targetID]  = nil
			end
		end
		return
	end
	for targetID, target in pairs(targets) do
		UpdateTarget(targetID, target)
	end
end


function widget:Update()
	-- this callin is triggered after commands are received, so we can use it as a mark when a unit have to be updated immediately before the next frame
	if next(updateNow) then
		-- Debug('Updating target in Update')
		for targetID, target in pairs(updateNow) do
			-- 
			UpdateTarget(targetID, target)
			updateNow[targetID] = nil
		end
	end
end
function widget:DrawScreen()
	-- this callin is triggered after commands are received, so we can use it as a mark when a unit have to be updated immediately before the next frame
	if next(updateNow) then
		Debug('Updating target in DrawScreen !','currentFrame: ' .. currentFrame) -- never happened
		for targetID, target in pairs(updateNow) do
			UpdateTarget(targetID, target)
			updateNow[targetID] = nil
		end
	end
end

function widget:UnitFinished(unitID, unitDefID, unitTeam)
	if unitTeam == myTeamID then
		if bombersDefID[unitDefID] and not bombers[unitID] then
			bombers[unitID] = bomberClass:New(unitID, unitDefID)
		elseif unitDefID == airpadDefID then
			local pos = {id = unitID, spGetUnitPosition(unitID)}
			airpads[unitID] = pos
			if unitTeam == myTeamID then
				myAirpads[unitID] = pos
			end
		elseif unitDefID == airFactoryDefID then
			local pos = {id = unitID, spGetUnitPosition(unitID)}
			airFacs[unitID] = pos
			if unitTeam == myTeamID then
				myAirpads[unitID] = pos
			end
		elseif unitDefID == airPalteDefID then -- plate don't receive landing planes?
			local pos = {id = unitID, spGetUnitPosition(unitID)}
			airPlates[unitID] = pos
			if unitTeam == myTeamID then
				myAirpads[unitID] = pos
			end
		end
	end
end

function widget:UnitGiven(unitID, unitDefID, unitTeam)
	local _,_,_,_,buildProgress = spGetUnitHealth (unitID)
	if buildProgress and buildProgress == 1 then
		widget:UnitFinished(unitID, unitDefID, unitTeam)
	end
end

function widget:UnitDestroyed(unitID)
	--Debug("unit destroyed")  -- takes long time to arrive? (after destroying cloaked target)
	if targets[unitID] then
		--Debug("target destroyed", GetHumanName(unitID))
		TargetIsGone(unitID, true)
	elseif bombers[unitID] then
		--Debug("bomber destroyed")
		bombers[unitID] = nil
	elseif airpads[unitID] then
		airpads[unitID] = nil
		myAirpads[unitID] = nil
	elseif airFacs[unitID] then
		airFacs[unitID] = nil
	elseif airPlates[unitID] then
		airPlates[unitID] = nil
	end
end

function widget:UnitTaken(unitID)
	widget:UnitDestroyed(unitID)
end
function widget:UnitIdle(unitID)
	-- Echo(math.round(os.clock()),'unit idle',unitID)
	if bombers[unitID] then
		local bomber = bombers[unitID]
		if bomber.target then
			bomber:RemoveTarget(nil,true)
		end
	end
end
function widget:UnitCmdDone(unitID, unitDefID, unitTeam, cmdID, cmdParams, cmdOpts, cmdTag)
-- NOTE: the engine (?) apply a time out on target gone out of radar, the command is not shown anymore but the bomber continue its course for some time
--, then the order is removed and UnitCmdDone get triggered, the bomber then just stop on place
-- if we 
	if cmdID == CMD_ATTACK then
		return
	end
	if not bombers[unitID] then
		return
	end

	local bomber = bombers[unitID]
	-- Debug('reloaded, reloadFrame, currentFrame', reloaded, reloadFrame, currentFrame)
	if bomber.unloaded then
		if cmdID == CMD_REARM and not bomber:CheckUnload() then
			-- unloaded property updated
		else
			-- still unloaded, nothing to do
			return
		end
	end
	local current = spGetCommandQueue(unitID,1)[1]
	local cmd = current and current.id
	-- Echo('cmdDone', cmdID,'current:',current and current.id)
	bomber.held = cmd == CMD_WAIT
	if not cmd  then
		if bomber.target then
			-- Debug(bomber.id .. ' no more order in UnitCmdDone BUT BOMBER GOT TARGET!, niling lastCommand')
			-- bomber.lastCommand = nil
			Debug(unitID .. ' no more order in UnitCmdDone BUT BOMBER GOT TARGET! CMD done?', cmdID)
			-- bomber:RemoveTarget()
			-- bomber.lastCommand = nil
			-- checkReturn[unitID] = bomber
		end
		-- if bomber.target then
		--	local targetID = bomber.target
		--	bomber:RemoveTarget(false)
		-- 	if not targets[targetID] then
		-- 		Debug(' ... from UnitCmdDone')
		-- 	end
		-- end
		bomber:UpdateState(nil, params)
		return
	end
	if cmdOpts.alt then
		return
	end

	local params = current.params
	-- if not current or current.id~=CMD_RAW_MOVE and current.id ~= CMD_ATTACK then
	if (cmd == cmdID and  params[1] == cmdParams[1] and params[3] == cmdParams[3] ) then
		-- when a command is inserted, both cmd done and current are the same and we have nothing to do with inserted commands (spam of ground target)
		return
	end
	if cmd == CMD_ATTACK and not params[3] and params[1] == bomber.target then
		-- user reclicked the same as current target, already treated in CommandNotify
		return
	end
	-- Debug(
	-- 	'Cmd done', cmdID .. ' => ' .. cmd
	-- 	,tostring(cmdParams[1]) .. ' => ' .. tostring(params[1])
	-- 	,'unloaded: ' .. tostring(bomber.unloaded)
	-- )
	-- end


	-- if cmd ~= CMD_RAW_MOVE and cmd ~= CMD_ATTACK then
	Debug(bomber.id .. ' new order queued ', cmd, 'params', params[1])
	checkReturn[unitID] = nil

	-- end
	local _, target = bomber:UpdateState(cmd, params)
	if target then
		updateNow[target.id] = target
	end
end

local acceptableCmd = {
	[CMD_ATTACK] = true,
	[CMD_RAW_MOVE] = true,
	[CMD_REARM] = true,
	[CMD_FIGHT] = true,
	[CMD_STOP] = true,
}

function widget:UnitCommandNotify(id, cmd,params,opts)
	if opts.alt then
		return
	end
	if not acceptableCmd[cmd] then
		return
	end
	local bomber = selectedBombers[id]
	if not bomber then
		return
	end
	-- Debug('targetID in CN?',targetID,'cmd',cmd,'params',unpack(params))
		-- better to immediately stop processing bomber here to avoid clunkiness
	local target
	local shift, meta = opts.shift, opts.meta
	local isNow = not shift
	local continue

	local isNow = (isNow or spGetCommandQueue(id,0) == 0 or not params[3] and bomber.target == params[1])
	if isNow then
		bomber:CheckUnload()
		if bomber.unloaded and attackingOrder[cmd] then
			bomber.held = true
			Debug(' -- bomber is still unloaded, waiting for release -- ')
		elseif cmd == CMD_WAIT then
			bomber.held = true
			Debug(' -- bomber is manually waiting -- ')
		else
			bomber.held = false
			continue, target = bomber:UpdateState(cmd, params, shift, meta)
			if not continue then
				return
			end
		end
	end
	if target then
		updateNow[target.id] = target
		Debug('update required for target ' .. target.id,'currentFrame: ' .. currentFrame)
		-- UpdateTarget(target.id, target)
	end
end

function widget:CommandNotify(cmd, params, opts) -- META IS NOT IMPLEMENTED YET, will only work correctly without shift and used once on a target
	if not next(selectedBombers) then
		return
	end
	if not acceptableCmd[cmd] then
		return
	end
	if opts.alt then
		return
	end
	-- Debug('targetID in CN?',targetID,'cmd',cmd,'params',unpack(params))
		-- better to immediately stop processing bomber here to avoid clunkiness
	local target
	local shift, meta = opts.shift, opts.meta
	local isNow = not shift
	local continue = true
	for id, bomber in pairs(selectedBombers) do
		local isNow = (isNow or spGetCommandQueue(id,0) == 0 or not params[3] and bomber.target == params[1])
		if isNow then
			bomber:CheckUnload()
			if bomber.unloaded and attackingOrder[cmd] then
				bomber.held = true
				Debug(' -- bomber is still unloaded, waiting for release -- ')
			elseif cmd == CMD_WAIT then
				bomber.held = true
				Debug(' -- bomber is manually waiting -- ')
			else
				bomber.held = false
				continue, target = bomber:UpdateState(cmd, params, shift, meta, not continue)
				if not continue then
					return
				end
			end
		end
	end
	if target then
		updateNow[target.id] = target
		Debug('update required for target ' .. target.id,'currentFrame: ' .. currentFrame)
		-- UpdateTarget(target.id, target)
	end
end

local optString = function(opts)
	local str = ''
	for opt, bool in pairs(opts) do
		if bool then
			str = str .. opt .. ':' .. tostring(bool) .. ', '
		end
	end
	return str:sub(1,-3)
end
function widget:UnitCommand(unitID, unitDefID, unitTeam, cmdID, cmdParams, cmdOpts, cmdTag)
	if not bombers[unitID] then
		return
	end
	local bomber = bombers[unitID]
	-- Debug("UC:",CMD[cmdID],cmdID,"p1=",cmdParams[1],"p2=",cmdParams[2],"p3=",cmdParams[3],"p4=",cmdParams[4],"shift=",cmdOpts.shift,"internal=",cmdOpts.internal,"alt=",cmdOpts.alt)

	-- Catching player-issued commands.
	-- Placed here and not in CommandNotify as to also catch commands issued as a result of ForceFire+drag
	if bomber.areaAtt then
		if cmdID == CMD_ATTACK and not cmdParams[2] then
			local _, target = bomber:UpdateState(cmdID, cmdParams)
			if target then
				updateNow[target.id] = target
			end
		end
		bomber.areaAtt = nil
		return
	end
	if WATCH_ID == unitID then
		Debug('watched unit ' .. unitID .. ' receive order ', cmdID, unpack(cmdParams))
	end
	local inserting = cmdID == 1
	local isInternal, isNow, coded
	local paramOffset
	if inserting then
		coded = cmdParams[3]
		isInternal = coded%(CMD_OPT_INTERNAL*2) >= CMD_OPT_INTERNAL
		isNow = cmdParams[1] == 0
		cmdID = cmdParams[2]
		paramOffset = 3
	else
		isInternal = cmdOpts.internal
		isNow = not cmdOpts.shift
		paramOffset = 0
	end
	-- Debug('UC received','cmd',cmdID,'param',cmdParams[paramOffset + 1], cmdParams[paramOffset + 2], cmdParams[paramOffset + 3],'inserting',inserting,'isInternal',isInternal)
	-- if bomber.held  then
	-- 	-- when bomber is held on pad for rearm, any command send will be accompanied by 2 consecutives CMD_WAIT command with opt 0 going prior the order
	-- 	if cmdID == CMD_WAIT then
	-- 		if not bomber:CheckUnload() then
	-- 			bomber.held = false
	-- 			Debug(' -- bomber released --')
	-- 			widget:UnitCmdDone(unitID, _, _, CMD_WAIT, TABLE_ZERO, EMPTY_TABLE) -- check for a queued order waiting
	-- 		end
	-- 	end
	-- 	return
	-- end
	if cmdID == CMD_WAIT then
		bomber:CheckUnload()
		-- Debug(' -- bomber released --')
		updateBomberNow[unitID] = true
		return
	end


	if cmdID == CMD_REARM then
		bomber.unloaded = true
		Debug(' -- bomber go rearming -- ','inserting?',inserting)
	end
	-- NOTE: there is a server delay between order given and order received, the last(s) ground position ordered doesnt come in time to be executed before attack's fire
	-- we get 
	if bomber.target then

		-- if bomber:CheckUnload() then
		local name = bomber.name
		if  bomber:CheckUnload() then -- check if the shot occured at any order incoming, this may be improved depending on bomber type, but most of them will be checked as unloaded in the spam of ground targetting
			--, we want to detect the unload as soon as possible, to cancel the spam attack as soon as possible
			--, ideally if we could calculate in advance an unload depending on ground target pos and bomber pos, it would be perfect so we can stop sending new ground attack order and avoid cancelling Rearms and attacks

			-- Echo('unload detected at order',cmdID,'inserting?',inserting)
			local current = spGetCommandQueue(unitID,1)[1]
			local curStr = ''
			if current and current.id then
				curStr = 'cmd ' .. current.id .. 'params ' .. current.params[1]
			end
			-- Echo('unload detected, curent order:',curStr)
			spGiveOrderToUnit(unitID, CMD_REMOVE, CMD_ATTACK, CMD_OPT_ALT)

			local targetID = bomber:RemoveTarget()
			-- if not targets[targetID] then
			-- 	Debug(' ... from Unit Command')
			-- end
			if ownReturn then -- do we want our own return ?
				bomber.waitRearm = nil
				bomber:Return(true, true)
				spGiveOrderToUnit(unitID, CMD_REMOVE, CMD_REARM, CMD_OPT_ALT)  -- remove all REARM that has been ordered until now (not onlt those already received)
				return
			else
				bomber.waitRearm = 0
			end
		end			
		return
	elseif bomber.waitRearm then
		if cmdID == CMD_REARM then
			if bomber.waitRearm == 0 then
				bomber.waitRearm = 1
			elseif bomber.waitRearm == 1 then -- a second rearm has been inserted because of attack spam occurring after target has been falsified and weapon unloaded, because of server delay, we have to fix it
				-- Debug('fixing')
				-- remove all rearm
				spGiveOrderToUnit(unitID, CMD_REMOVE, CMD_REARM, CMD_OPT_ALT)  -- remove all REARM
				-- insert same rearm as received in back of the queue
				spGiveOrderToUnit(unitID, CMD_INSERT, {-1, CMD_REARM, CMD_OPT_SHIFT + CMD_OPT_INTERNAL, cmdParams[paramOffset + 1]}, CMD_OPT_ALT )
				bomber.waitRearm = nil
			end
			-- bomber.waitRearm = nil
		end
		return
	end
end





local spGetSelectedUnitsSorted = Spring.GetSelectedUnitsSorted
function widget:CommandsChanged()
	local selSorted = spGetSelectedUnitsSorted()
	for id in pairs(selectedBombers) do
		selectedBombers[id] = nil
	end
	if selSorted.n == 0 then
		return
	end
	selSorted.n = nil
	for defID, t in pairs(bombersDefID) do
		local t = selSorted[defID]
		if t then
			for _, id in ipairs(t) do
				local bomber = bombers[id]
				if bomber then
					selectedBombers[id] = bomber
				end
			end

		end
	end
	
end

function widget:Initialize()
	currentFrame = Spring.GetGameFrame()
	myTeamID = Spring.GetMyTeamID()
	if (Spring.GetSpectatingState() or Spring.IsReplay()) then
		widgetHandler:RemoveWidget(widget)
	end
	local myUnits = spGetTeamUnits(myTeamID)
	if myUnits then
		for _, unitID in pairs(myUnits) do
			widget:UnitGiven(unitID, spGetUnitDefID(unitID), myTeamID)
		end
	end
	widget:CommandsChanged()
end

function widget:PlayerChanged(playerID)
	if spGetSpecState() then
		widgetHandler:RemoveWidget(widget)
	end
end




local GL_POINTS			= GL.POINTS
local glVertex			= gl.Vertex
local glColor       	= gl.Color
local glBeginEnd    	= gl.BeginEnd
local glPointSize 		= gl.PointSize
local glNormal 			= gl.Normal

local white = {1,1,1,1}


function widget:DrawScreen()
	if WG.DrawOnUnits then
		if Debug() then
			WG.DrawOnUnits:Run(bombers, true, true)
		else
			WG.DrawOnUnits:Stop(bombers)
		end
	end
end

function widget:DrawWorld()
	glPointSize(6.0)

	for _, point in pairs(Points) do
		local x,y,z = unpack(point)
		glColor(point.color or white)
		glBeginEnd(GL_POINTS, function()
			-- glNormal(x, y, z)
			glVertex(x, y, z)
		end)

	end
	glPointSize(1.0)
	glColor(1, 1, 1, 1)
end

function widget:Shutdown()
	if WG.DrawOnUnits then
		WG.DrawOnUnits:Stop(bombers)
	end
end

f.DebugWidget(widget)