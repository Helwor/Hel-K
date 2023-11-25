function widget:GetInfo()
	return {
		name = "Lobster Launch Fix",
		desc = "Remove orders of the manually lobbed units",
        author = "Helwor",
		date = "Oct 2023", --16 October 2013
		license = "GNU GPL, v2 or v3",
		layer = -50000,
		enabled = true,
		handler = true,
	}
end

local Echo = Spring.Echo

local TIMEOUT_FRAME = 6 * 30 -- /30 = game time seconds of active wait between the order and the execution, after that, the lob is forgotten

-- lob info
local lobsterDefID = UnitDefNames['amphlaunch'].id
local LOB_LAUNCH_GATHER = UnitDefs[lobsterDefID].customParams.thrower_gather
local LOB_WEAPNUM, LOB_RELOAD

for weapNum, weapon in ipairs(UnitDefs[lobsterDefID].weapons) do
	local weapDefID = weapon.weaponDef
	local weapDef = WeaponDefs[weapDefID]
	if weapDef.description == 'Bogus Unit Launcher' then
		LOB_WEAPNUM = weapNum
		LOB_RELOAD = weapDef.reload * 30
	end
end
---
local spGetSelectedUnitsSorted 		= Spring.GetSelectedUnitsSorted
local spGetUnitsInCylinder 			= Spring.GetUnitsInCylinder
local spGetUnitPosition 			= Spring.GetUnitPosition
local spGetUnitDefID 				= Spring.GetUnitDefID
local spGetUnitCurrentCommand 		= Spring.GetUnitCurrentCommand
local spGiveOrderToUnit 			= Spring.GiveOrderToUnit
local spGetUnitWeaponState 			= Spring.GetUnitWeaponState
local spGetUnitTeam 				= Spring.GetUnitTeam

local abs = math.abs

local currentFrame = Spring.GetGameFrame()
local myTeamID = Spring.GetMyTeamID()

local launchable = {}
for defID, def in pairs(UnitDefs) do
	local moveType = Spring.Utilities.getMovetype(def)
	if moveType == 2 then
		launchable[defID] = true
	end
end

local CMD_MANUALFIRE = CMD.MANUALFIRE
local CMD_STOP = CMD.STOP



local done = {}
local waitFire = {}
local lobsterSelected = {}
local seltypes = {}
local EMPTY_TABLE = {}


function widget:UnitCmdDone(unitID,defID, team, cmd,params,opts)
	if cmd == CMD_MANUALFIRE and waitFire[unitID] then
		local _, loaded, reloadFrame, _, _ = spGetUnitWeaponState(unitID, LOB_WEAPNUM)
		local justFired = not loaded and reloadFrame and abs(reloadFrame - (currentFrame + LOB_RELOAD) ) < 5 -- on test it was actually 0 but I give it some leeway
		if justFired then
			local lx, _, lz = spGetUnitPosition(unitID)
			if lx then
				local unitsAround = spGetUnitsInCylinder(lx, lz, LOB_LAUNCH_GATHER)
				for _, uid in ipairs(unitsAround or EMPTY_TABLE) do
					if not done[uid] then
						done[uid] = currentFrame + 75 -- forget the lobbed unit for a while
						if spGetUnitTeam(uid) == myTeamID then
							local defID = spGetUnitDefID(uid)
							if defID and launchable[defID] then
								local cmd = spGetUnitCurrentCommand(uid)
								if cmd and cmd ~= CMD_STOP then
									spGiveOrderToUnit(uid, CMD_STOP,0,0)
								end
							end
						end
					end
				end
			end
		end
	end
end

function widget:GameFrame(f)
	currentFrame = f
	if f%15 ~= 0 then
		return
	end
	for unitID, timeout in pairs(waitFire) do
		if f > timeout then
			waitFire[unitID] = nil
		end
	end
	for unitID, timeout in pairs(done) do
		if f > timeout then
			done[unitID] = nil
		end
	end
end

function widget:CommandNotify(cmd, params,opts)
	if lobsterSelected and cmd == CMD_MANUALFIRE and not opts.shift then
		for i, lobID in ipairs(lobsterSelected) do
			waitFire[lobID] = currentFrame + TIMEOUT_FRAME
		end
	end
end

function widget:CommandsChanged()
	lobsterSelected =  (WG.selectionDefID or spGetSelectedUnitsSorted())[lobsterDefID]
end

function widget:PlayerChanged()
	myTeamID = Spring.GetMyTeamID()
end
function widget:Initialize()
	widget:PlayerChanged()
	widget:CommandsChanged()
end


