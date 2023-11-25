

function widget:GetInfo()
    return {
        name      = "DrawFire",
        desc      = "Allow drawing fire along multiple attacking ground position with alt.",
                      --//Area Attack doesnt get triggered on right click on unit, instead, a double right click or a brief right click then left click anywhere will trigger it.]],
        author    = "Helwor",
        date      = "August 2020",
        license   = "GNU GPL, v2 or later",
        layer     = -1000001,
        enabled   = true,
        handler   = true
    }
end


------------------------------------------------------------------------------------------------------------
---  CONFIG
------------------------------------------------------------------------------------------------------------

include('keysym.h.lua')
include("keysym.lua")
-- ADD FIND PAD AND EXCLUDE PAD TO EZ SELECTOR
include("LuaRules/Configs/customcmds.h.lua")
local customCmds = VFS.Include("LuaRules/Configs/customcmds.lua")
local KEYSYMS = KEYSYMS
local specialKeys--[[, ToKeysyms--]] = include("Configs/integral_menu_special_keys.lua")
VFS.Include("LuaUI\\Widgets\\Keycodes.lua")


VFS.Include('LuaGadgets/system.lua', nil,  VFS.ZIP_ONLY)





local f = VFS.Include("LuaUI\\Widgets\\UtilsFunc.lua")

local copy                      = f.copy
local Page                      = f.Page
local nround                    = f.nround
local l                         = f.l

local tracefunc                 = f.tracefunc
local arith_new                 = f.arith_new
local autotable                 = f.autotable
local g                         = f.StrCol.grey

local GetUpvaluesOf             = f.GetUpvaluesOf
local DisableOnSpec             = f.DisableOnSpec(_,widget,'setupSpecsCallIns')
local colors ={}
for k,v in pairs(f.COLORS) do colors[k]=f.upd_new(v)-1 end
-- f = nil -- release memory of useless funcs


local spFindUnitCmdDesc         = Spring.FindUnitCmdDesc
local spGetUnitCmdDescs         = Spring.GetUnitCmdDescs

local spGiveOrder               = Spring.GiveOrder
local spSetActiveCommand        = Spring.SetActiveCommand
local spGiveOrderToUnit         = Spring.GiveOrderToUnit
local spSendCommands            = Spring.SendCommands
local spGetUnitsInCylinder      = Spring.GetUnitsInCylinder


local spGetTimer                = Spring.GetTimer
local spGetModKeyState          = Spring.GetModKeyState
local spDiffTimers              = Spring.DiffTimers
local spGetMyTeamID             = Spring.GetMyTeamID
local spGetSpectatingState      = Spring.GetSpectatingState
local spIsReplay                = Spring.IsReplay
local spValidUnitID             = Spring.ValidUnitID

local spGetUnitDefID            = Spring.GetUnitDefID

local spGetMouseState           = Spring.GetMouseState
local spTraceScreenRay          = Spring.TraceScreenRay
local spGetUnitPosition         = Spring.GetUnitPosition


local spGetUnitHealth           = Spring.GetUnitHealth
local spGetUnitRulesParam       = Spring.GetUnitRulesParam
local spGetUnitRulesParams      = Spring.GetUnitRulesParams
local spGetSelectedUnits        = Spring.GetSelectedUnits
local spGetUnitIsActive         = Spring.GetUnitIsActive

local spGetCameraState          = Spring.GetCameraState
local spTestBuildOrder          = Spring.TestBuildOrder

local spGetUnitCurrentCommand   = Spring.GetUnitCurrentCommand
local spGetGroundHeight         = Spring.GetGroundHeight
--local spGetModseyState          = Spring.GetModKeyState

local spuGetUnitFireState       = Spring.Utilities.GetUnitFireState

local spGetCommandQueue         = Spring.GetCommandQueue

local spGetActiveCommand        = Spring.GetActiveCommand

local spGetUnitWeaponTestRange  = Spring.GetUnitWeaponTestRange
local spGetUnitWeaponState      = Spring.GetUnitWeaponState
local spGetUnitWeaponTarget     = Spring.GetUnitWeaponTarget
local spGetUnitWeaponVectors    = Spring.GetUnitWeaponVectors
local spGetUnitWeaponCanFire    = Spring.GetUnitWeaponCanFire
local spGetUnitWeaponHaveFreeLineOfFire = Spring.GetUnitWeaponHaveFreeLineOfFire
local spGetUnitPieceMap         = Spring.GetUnitPieceMap
local spGetUnitPiecePosition    = Spring.GetUnitPiecePosition
local spGetUnitVectors          = Spring.GetUnitVectors
local spGetUnitHeading          = Spring.GetUnitHeading
local spGetUnitVelocity         = Spring.GetUnitVelocity
local spGetUnitStates           = Spring.GetUnitStates
local spGetGameFrame            = Spring.GetGameFrame
local spGetUnitMoveTypeData     = Spring.GetUnitMoveTypeData
local spTestMoveOrder      = Spring.TestMoveOrder
local Echo                      = Spring.Echo



local spuCheckBit               = Spring.Utilities.CheckBit
local spuAndBit                 = Spring.Utilities.AndBit

local CMD_REMOVE                = CMD.REMOVE
local CMD_ATTACK                = CMD.ATTACK
local CMD_FIRESTATE             = CMD.FIRE_STATE
local CMD_OPT_INTERNAL          = CMD.OPT_INTERNAL
local CMD_INSERT                = CMD.INSERT
local CMD_OPT_ALT               = CMD.OPT_ALT
local CMD_OPT_SHIFT             = CMD.OPT_SHIFT
local CMD_MOVE                  = CMD.MOVE
local CMD_RAW_MOVE              = customCmds.RAW_MOVE
local CMD_MANUALFIRE            = CMD.MANUALFIRE
local CMD_STOP                  = CMD.STOP
local CMD_RECALL_DRONES         = customCmds.RECALL_DRONES
local CMD_WAIT                  = CMD.WAIT
local CMD_AIR_STRAFE            = customCmds.AIR_STRAFE
local CMD_ONECLICK_WEAPON       = customCmds.ONECLICK_WEAPON
local CMD_UNIT_CANCEL_TARGET    = CMD_UNIT_CANCEL_TARGET

--local MY_WIDGET_CODE            = tonumber(f.EncodeToNumber(widget:GetInfo().name)) -- doesnt work unfortunately
local MY_WIDGET_CODE            = 5
--local GetUnitUnderCursor        = WG.PreSelection_GetUnitUnderCursor


--local RAD_PER_ROT = (math.pi/(2^15)) -- local headingRad = Spring.GetUnitHeading(id)*RAD_PER_ROT
local round = math.round
local rand = math.random
local floor = math.floor
local max = math.max
local min = math.min
local abs = math.abs
local clock = os.clock
local insert = table.insert
local pairs = pairs
local ipairs = ipairs

local GL_POINTS         = GL.POINTS
local GL_LINES          = GL.LINES

local glVertex          = gl.Vertex
local glLineWidth       = gl.LineWidth
local glColor           = gl.Color
local glPointSize       = gl.PointSize
local glBeginEnd        = gl.BeginEnd
local glDepthTest       = gl.DepthTest
local uds

local setupvalue        = debug.setupvalue

local CF2MouseMove,numSpacing,spacing -- for CustomFormation2

local bufferAttacks={}
local xyzo = {0,0,0,MY_WIDGET_CODE} -- TODO: need to find a proper way to sign my widget orders
local INS ={0,CMD_ATTACK,CMD_OPT_INTERNAL,0,0,0,MY_WIDGET_CODE,CMD_OPT_ALT+CMD_OPT_SHIFT+CMD_OPT_INTERNAL}

local AUTO_REPEAT = true -- YET TO DECIDE: auto repeat for arty unit (or long ranged unit?)

local globalDebugging -- = true
local function Debug(...)
    if globalDebugging then Echo(...) end
end

local BOMBERS={
     [UnitDefNames['bomberprec'].id]=true
    ,[UnitDefNames['bomberriot'].id]=true
    ,[UnitDefNames['bomberdisarm'].id]=true
    ,[UnitDefNames['bomberheavy'].id]=true
}

-- CONFIG
local PER_SHOT = {-- those consume one target per shot of the salvo -- 
     staticarty         =true
    ,shipheavyarty      =true
    ,tankassault        =true
    ,gunshipheavyskirm  =true
    ,gunshipassault     =true
    ,cloakraid          =true
    ,striderarty        =true
    ,shipskirm          =true
    ,cloakriot          =true
    ,zenith             =true
    ,bomberdisarm       =true

}
local NO_WAIT = { -- those are not waiting for the salvo to be ended and head to the next target // now using no wait by default
     spiderscout=true
    ,hoverarty=true
    ,gunshipkrow=true
    ,striderbantha=true
    ,dyntrainer_support_base=true
}
local MULTI_WEAPONS ={-- those need to register multiple weapons, each defined to use a pershot method or not
     amphraid={         [1]=true,     [2]=true}
    ,shipheavyarty={    [1]='pershot',[2]='pershot',[3]='pershot'}
    ,gunshipkrow={      [1]=true,     [2]=true,     [3]='pershot',[4]=true}
    ,striderdetriment={ [1]='pershot',[2]='pershot',[3]='pershot',         [5]=true}
    ,striderbantha={    [1]=true,     [2]=true,     [3]='pershot'}
    ,striderscorpion={                [2]=true,     [3]='pershot',[4]=true,[5]=true}
    ,striderdante={     [1]=true,     [2]=true,     [3]='pershot',[4]=true}
    ,raveparty={        [1]=true,     [2]=true,     [3]=true,     [4]=true,[5]=true,[6]=true}
    ,shipcarrier={      [1]=true,     [2]=true}
    ,shipriot={         [1]=true,     [2]=true}
    ,shipassault={      [1]=true,     [2]=true}
    ,jumpsumo={                       [2]=true,     [3]=true,     [4]=true,[5]=true}
    ,turretimpulse={    [1]=true,     [2]=true}
}
local MULTI_CHECKS = { -- those have multiple weapons to check -- note it might differ from the above in a few case, duck (amphraid) in example shoot either one or the other weapon
     shipheavyarty      =true 
    ,gunshipkrow        =true
    ,striderdetriment   =true
    ,striderbantha      =true
    ,striderdante       =true
    ,striderscorpion    =true
    ,raveparty          =true
    ,shipcarrier        =true
    ,shipriot           =true
    ,shipassault        =true
    ,jumpsumo           =true
    ,turretimpulse      =true
}
local IS_NAME = {-- those are particular cases we handle differently
     staticheavyarty    ='isBertha'
    ,amphraid           ='isDuck'
    ,hoverdepthcharge   ='isClaymore'
    ,cloakskirm         ='isRonin'
    ,shieldriot         ='isOutlaw'
    ,gunshipkrow        ='isKrow'
    ,raveparty          ='isDRP'
    ,shipcarrier        ='isCarrier'
    ,zenith             ='isZenith'
    ,gunshipheavyskirm  ='isBrawler'
    ,tankheavyarty      ='isTremor'
    ,jumpsumo           ='isSumo'
    ,turretimpulse      ='isNewton'
    ,gunshipkrow        ='isKrow'
    ,bomberdisarm       ='isStiletto'
    ,bomberriot         ='isNapalm'
}

local ALLOWED_MANUAL = { -- allow manual fire  for specific unit or specific weapon name, indicating an optional pershot method if it's a weapon name
     striderbantha      =true
    ,striderdante       =true
    ,striderscorpion    =true
    ,striderdetriment   =true
    ,shipcarrier        =true
    ,slamrocket         =true
    ,multistunner       ='pershot'
    ,clusterbomb        ='pershot'
    ,disruptorbomb      =true
    ,disintegrator      =true
    ,gunshipkrow        =true
    ,bomberdisarm       =true
}
local OVERRIDE_MANUAL ={ -- override manual fire ordering when it is available but not in range this will force the unit to move closer to fire the weapon, by name of weapon or by name of unit with their weapon number
     multistunner=true
    ,striderdante=3
    ,gunshipkrow=3
    ,bomberdisarm=1
}
local SHOT_SPACING ={ -- special spacing for some units
    bomberriot=150*150
}

local IS_TYPE=function(ud)--idem
    return ud.isHoveringAirUnit and 'isGS' or ud.isImmobile and 'isImmobile' or ud.name:match'bomber' and 'isBomber' or ud.canFly and 'isPlane'
end
--


-- as I can't access scripts from widget, I recopy the aimFrom piece name here
-- this is to work around the mistaking spHaveFreeLineOfFire callin
-- and this workaround is because no callin work properly to check if my unit gonna be able to shoot a particular ground target or not
-- it will give the actual piece from where we have to aim and therefore verify if our unit actually gonna aim
-- however,once the aiming animation is over, we can check for line of fire, but it still not make a 100% certainty it will shoot, some rare case can happen
local AIM_FROM={-- list might not be exhaustive almost all of them -if not all- have been tested
     amphaa                  = 'torso'
    ,amphassault             = 'turret'
    ,amphbomb                = 'firepoint'
    ,amphfloater             = 'barrel'
    ,amphimpulse             = 'aimpoint'
    ,amphlaunch              = 'pelvis'
    ,amphraid                = 'head'
    ,amphriot                = 'flaremain'
    ,amphsupport             = 'head'
    --
    -- those should be useless
    ,armcom                  = 'torso'
    --
    ,assaultcruiser          = function(num) local weaps= {"flturret", "frturret", "slturret", "srturret", "mlturret", "mrturret"} return weaps[num] end
    --
    ,bomberassault           = 'bomb'
    ,bomberdisarm            = 'Drop' -- not used, made special behaviour for this
    ,bomberprec              = 'drop'

    --
    ,chicken_blimpy          = 'dodobomb'
    ,chicken_dragon          = function(num) local weaps= {'firepoint','spike1','spike2','spike3','firepoint','body'} return weaps[num] end
    ,chicken_rafflesia       = 'body'
    ,chicken_roc             = function(num)local weaps= {'firepoint','spore1','spore2','spore3'} return weaps[num] or 'body' end
    ,chicken_shield          = 'firepoint'
    ,chicken_tiamat          = function(num)  return num==2 and 'spike2' or num==4 and 'body' or 'firepoint' end
    ,chickena                = function(num)  return num==1 and 'head' or 'body'end
    ,chickenbroodqueen       = function(num)  return num==2 and 'spike1' or num==3 and 'spike2' or num==4 and 'spike3' or 'firepoint' end
    ,chickenflyerqueen       = function(num) local weaps={'firepoint','spore1','spore2','spore3'} return weaps[num] or 'body' end
    ,chickenlandqueen        = function(num)  local weaps={'firepoint','firepoint','spore1','spore2','spore3'}  return weaps[num] or 'body' end
    ,chickena                = function(num)  return num==1 and 'head' or 'body' end
    ,chickenc                = 'head'
    ,chickend                = 'firepoint'
    ,chickenf                = 'head'
    ,chickenr                = 'head'
    ,chickens                = 'head'
    ,chickenspire            = 'firepoint'
    ,chickenwurm             = 'fire'
    ,chickenblobber          = 'head'
    ,pigeon                  = 'head'
    --
    ,cloakarty               = 'center'
    ,cloakassault            = 'aim'
    ,cloakheavyraid          = 'head'
    ,cloakraid               = 'head'--,'head' -- even though the script tell to aim from 'head' the LoF checking is wrong--after verification, it actually aim from flare which is also the weapon position
    ,cloakriot               = 'chest'
    ,cloakskirm              = 'gunemit'
    ,cloaksnipe              = 'shoulderr'
    --
    ,commrecon               = 'armhold'
    ,commsupport             = 'armhold'
    ,corcom_alt              = 'torso'
    ,cremcom                 = 'torso'
    --
    ,cruisemissile           = 'base'
    ,dronefighter            = 'droneMain'
    ,dronecarry              = 'gunpod'
    --
    ,dynassault              = function(num,id,weapOrder)
        local pieceMap = spGetUnitPieceMap(id)
        local HAS_GATTLING = pieceMap.rgattlingflare and true or false
        local HAS_BONUS_CANNON = pieceMap.bonuscannonflare and true or false
        local rcannon_flare= HAS_GATTLING and 'rgattlingflare' or 'rcannon_flare'
        local lcannon_flare = HAS_BONUS_CANNON and 'bonuscannonflare' or 'lnanoflare'
        local isManual = spGetUnitRulesParam(id, "comm_weapon_manual_"..weapOrder)==1
        return not isManual and 'pelvis' or weapOrder==1 and rcannon_flare or lcannon_flare
     end
    ,dynrecon                = 'pelvis'
    ,dynstrike               = function(_,_,num) return num==1 and 'palm' or 'RightMuzzle' end
    ,dynsupport              = 'head'
    --
    ,grebe                   = 'aimpoint'
    --
    ,gunshipaa               = 'base'
    ,gunshipassault          = 'body'
    ,gunshipemp              = 'housing'
    ,gunshipheavyskirm       = 'eye'
    ,gunshipheavytrans       = function(num)local weaps={'RTurretBase','LTurretBase','FrontTurret'} return weaps[num] end
    ,gunshipkrow             = function(num)local weaps={'RightTurretSeat','LeftTurretSeat','subpoint','RearTurretSeat','Base','Base'} return weaps[num] end
    ,gunshipraid             = 'gun'
    ,gunshipskirm            = 'base'
    --
    ,hoveraa                 = 'turret'
    ,hoverarty               = 'aim'
    ,hoverassault            = 'turret'
    ,hoverdepthcharge        = 'pads'
    ,hoverheavyraid          = 'turret'
    ,hoverraid               = 'turret'
    ,hoverriot               = 'barrel'
    ,hoverskirm              = 'turret'
    --
    ,jumpaa                  = 'torso'
    ,jumparty                = 'torso'
    ,jumpassault             = 'ram'
    ,jumpblackhole           = 'chest'
    ,jumpcon                 = 'torso'
    ,jumpraid                = 'low_head'
    ,jumpscout               = 'gun'
    ,jumpskirm               = 'head'
    ,jumpsumo                = function(num)local weaps={'b_eye', 'l_turret', 'r_turret', 'l_turret', 'r_turret', 'b_eye'} return weaps[num] end
    --
    ,mahlazer                = 'SatelliteMuzzle' -- useless, this is not the piece aiming at ground/units and this is not the correct unit to check for,
    ,starlight_satellite     = 'SatelliteMuzzle' -- not used anymore -- note:was bad technique using 'LimbA1' piece which was one of the few pieces to move (but only 75% reliable) while satellite is aiming
                                                 -- found out an effective way by projecting the satellite's weapon's vectors

    ,nebula                  = function(num)local weaps={'turretPiece', 'turretPiece', 'turretPiece', 'turretPiece', 'base'} return weaps[num] end
    ,planefighter            = 'base'
    ,planeheavyfighter       = 'base'
    ,pw_hq                   = 'drone'
    ,pw_wormhole             = 'drone'
    ,pw_wormhole2            = 'drone'
    ,raveparty               = 'spindle'
    --
    ,shieldaa                = 'pod'
    ,shieldarty              = 'pelvis'
    ,shieldassault           = 'head'
    ,shieldraid              = 'head'
    ,shieldriot              = 'torso'
    ,shieldscout             = 'pelvis'
    ,shieldskirm             = 'popup'
    --
    ,shiparty                = 'turret'
    ,shipcarrier             = 'Radar'
    ,shipscout               = 'missile'
    ,shipheavyarty           = function(num)local weaps={'turret1', 'turret2', 'turret3'} return weaps[num] end
    ,shipriot                = function(num)local weaps={'gunb','gunf'} return weaps[num] end
    ,shipskirm               = 'turret'
    --
    ,spideraa                = 'turret'
    ,spideranarchid          = 'aim'
    ,spiderantiheavy         = 'turret'
    ,spiderassault           = 'turret'
    ,spidercrabe             = function() return num==1 and 'turret' or 'rocket' end
    ,spideremp               = 'turret'
    ,spiderriot              = 'barrel'
    ,spiderscout             = 'turret'
    ,spiderskirm             = 'box'
    --
    --
    ,staticarty              = 'sleeve'
    ,staticheavyarty         = 'query'
    --
    ,striderarty             = 'launchers'
    ,striderbantha           = function(num) return  num==2 and 'torso' or 'headflare' end
    ,striderdante            = 'torso'
    ,striderdetriment        = function(num)local weaps={'larmcannon', 'rarmcannon', 'AAturret', 'headlaser2', 'shouldercannon', 'lfoot', 'lfoot', 'lfoot'} return weaps[num] end
    ,striderscorpion         = function(num)local weaps={'body','tailgun','tailgun','gunl','gunr'} return weaps[num] end
    ,striderantiheavy        = 'head'
    --
    ,subraider               = 'firepoint'
    ,subtacmissile           = 'aimpoint'
    --
    ,tankarty                = 'barrel'
    ,tankassault             = 'turret'
    ,tankcon                 = 'turret'
    ,tankheavyarty           = 'triple'
    ,tankheavyassault        = function(num) return num==1 and 'turret1' or 'turret2' end
    ,tankheavyraid           = 'turret'
    ,tankraid                = 'turret'
    ,tankriot                = 'sleeve'
    --
    ,turretaaclose           = 'turret'
    ,turretaafar             = 'mc_rocket_ho'
    ,turretaaflak            = 'trueaim'
    ,turretaaheavy           = 'turret'
    ,turretlaser             = 'barrel'
    ,turretmissile           = 'pod'
    ,turretriot              = 'turret'
    --
    ,turretemp               = 'aim'
    ,turretheavy             = function(num) return num==1 and 'cannonAim' or 'heatrayBase' end
    ,turretheavylaser        = 'holder'
    ,turretimpulse           = 'center'
    ,turretsunlance          = 'breech'
    ,turrettorp              = 'base'
    --
    ,vehassault              = 'turret'
    ,vehaa                   = 'firepoint'
    ,vehcapture              = 'flare'
    ,vehraid                 = 'turret'
    ,vehriot                 = 'turret'
    ,vehscout                = 'turret'
    ,vehsupport              = 'aim'
    ,veharty                 = 'swivel'
    --
    ,zenith                  = 'firept'

    -- might not be exhaustive
}
------------------------------------------------------------------------------------------------------------
---  END OF CONFIG
------------------------------------------------------------------------------------------------------------




-- keys related



local oneAttacker

local Points = {}
local Lines = {}
local Weapons_By_UnitDef = {}
local unitsToTrace={}
local testUnits={}

local nextFrame = 0


local zone
local step,layers=16,40

local frame_morph = 0

-- local count=0

local page=0

local mouseUnit
local mouseTest = false
local debugTravel = false
local ownCallins = {}
local toggleCallins = {}
local autoreload = false
local myTeamID = spGetMyTeamID()
function MyNewTeamID(id) -- home made callin
    myTeamID = id
end
--[[local ret = EncodeToNumber('DrawFire')
Debug("ret is ", ret)
local ret2 = DecodeToString(ret)
Debug("ret2 is ", ret2)--]]


--local fun = function(x,z) return spGetGroundHeight(x,z) end
--[[function widget:UnitMoveFailed(id)
    Debug('FAILED',id)
end--]]
local function GetPieceAbsolutePosition(id,px,py,pz)
    local bx,by,bz = spGetUnitPosition(id)
    local front,top,right = spGetUnitVectors(id)
    return  bx + front[1]*pz + top[1]*py + right[1]*px,
            by + front[2]*pz + top[2]*py + right[2]*px,
            bz + front[3]*pz + top[3]*py + right[3]*px
end
local piece,num


local function CheckPings()
    local gaiaTeamID = Spring.GetGaiaTeamID()
    local teamList = Spring.GetTeamList()
    local players,isHosting,count,totalPing = {},{},0,0
    for i = 1, #teamList do
        local teamID = teamList[i]
        if teamID ~= gaiaTeamID then
            local A, leaderID, isDead, isAiTeam, B, allyTeamID = Spring.GetTeamInfo(teamID, false)
            Echo("A",A,"leaderID", leaderID,"isDead", isDead, "isAiTeam",isAiTeam, "B",B, "allyTeamID", allyTeamID)

            local _, _, hostingPlayerID = Spring.GetAIInfo(teamID)
            if hostingPlayerID then
                isHosting[leaderID] = teamID
            end
            if not isDead then
                -- Echo("teamID:"..teamID,"leaderID, isAiTeam, allyTeamID, hostingPlayerID is ", leaderID, isAiTeam, allyTeamID, hostingPlayerID)

                if leaderID < 0 then
                    leaderID = Spring.GetTeamRulesParam(teamID, "initLeaderID") or leaderID
                end
                if leaderID >= 0 then
                    if isAiTeam then
                        leaderID = nil
                    end
                end
                if leaderID then
                    local playerName, active, spectator, teamID, allyTeamID, pingTime, cpuUsage, country, rank = Spring.GetPlayerInfo(leaderID, false)
                    local speed1,sped2,speed3 = Spring.GetGameSpeed()
                    Echo("IN WIDGET:","playerName",playerName,"active",active, "spectator", spectator,"teamID",teamID,"allyTeamID",allyTeamID
                        ,"pingTime",pingTime,"cpuUsage",cpuUsage,"country",country,"rank",rank,"speed1",speed1,"speed2",speed2,"speed3",speed3 )                    local aiHosted = isHosting[leaderID]
                    players[leaderID] = {name = playerName,active = active,teamID = teamID, pingTime = pingTime, cpuUsage = cpuUsage}
                    count=count+1
                    totalPing = totalPing + pingTime
                    -- Echo("teamID:"..teamID,"LeaderID:",leaderID,"playerName, active, spectator, teamID, allyTeamID, pingTime, cpuUsage, country, rank is ", playerName, active, spectator, teamID, allyTeamID, pingTime, cpuUsage, country, rank)
                end
            end
        end
        -- ~not tested
        -- local isHostedAi = false
        -- local isBackupAi = false
        -- if Spring.GetTeamRulesParam(teamID, "initialIsAiTeam") then
        --     Echo(teamID .. ' is initial Ai Team ')
        --     if Spring.GetTeamLuaAI(teamID) then
        --         -- LuaAIs are always active, unless they exist for the purpose of backup.
        --         if Spring.GetTeamRulesParam(teamID, "backupai") == 1 then
        --             isBackupAi = true
        --         end
        --     else
        --         isHostedAi = true
        --         local _, _, hostingPlayerID = Spring.GetAIInfo(teamID)
        --         -- isAiTeam is false for teams that were AI teams, but had their hosting player drop.
        --         -- AI teams without any hosting player are effectively dead.
        --         if isAiTeam then
        --             -- Echo("leaderID,isAiTeam,hostingPlayerID is ", leaderID,isAiTeam,hostingPlayerID)
        --         end
        --     end
        -- end
    end
    local laggers = 0
    for playerID,player in pairs(players) do
        if player.pingTime>0.8 then
            laggers = laggers + 1
        end
    end
    return round(laggers/count), totalPing/count,totalPing,count -- 50%+ of players are lagging
end

function widget:KeyPress(key,mods)
    -- f.Page(Spring,'prog')
    -- local chk = f.CheckTime('start')
    -- for i=1,50000 do
    --     ("a,b,c,b,c,b,c,b,c,b,c,b,c"):split(',')
    -- end
    -- chk('reset','say')
    -- local string = string
    -- local str,sep = "a,b,c,b,c,b,c,b,c,b,c,b,c",','
    -- for i=1,50000 do
    --     ("a,b,c,b,c,b,c,b,c,b,c,b,c"):split2(',')
    -- end
    -- chk('stop','say')
    
    -- local text = 
    -- Echo(" is ", pcall(io.input,LUAUI_DIRNAME..'\\test9.txt'))

    -- Echo("io.input():close() is ", io.input():close())
    -- Echo("io.input() is ", io.input())
    -- Echo("io.output:close() is ", io.output())
    -- local function WriteNewFile(dir,filename,...)
    --     io.output(filename)
    --     local txt = io.input(filename)
    --     txt
    -- end


    --------- working ------
    -- local text = "text!" 
    -- local dir,name,ext = LUAUI_DIRNAME..'\\','test3','txt'
    -- f.WriteNewFile(dir,name,ext,text)
    ---

    -- io.write('test',',ok')
    -- io.output():close()
    -- io.input("")
    -- io.output(LUAUI_DIRNAME..'\\test9.txt')
    -- io.write('ghi')
    
    -- Echo("text is ", io.read())
 -- ("a,b,c,b,c,b,c,b,c,b,c,b,c"):split2(',')
    -- Echo(" is ", f.Page(("a,b,c,b,c,b,c,b,c,b,c,b,c"):split2(',')))
    -- time2 = os.clock()-time2
    -- Echo(time,time2)
    -- CheckPings()
    -- local unit = Spring.GetSelectedUnits()[1]
    -- if unit then
    --     f.Page(spGetUnitMoveTypeData(unit))
    -- end
    -- if unit then
    --     Echo("Spring.GetUnitVelocity is ",unit, )
    -- end

    -- local pc = math.random(1,10)
    -- local agg = 1
    -- for i=1,pc do
    --     agg = agg-((agg/2)/(i*1.2))
    -- end
    -- Echo('player count '..pc..', agg=> '..agg)    -- local pc = math.random(1,10)
    -- local scaling = 1.2
    -- techAccelPerPlayer = 4
    -- local techAccel = techAccelPerPlayer
    -- for i=2,pc do
    --     techAccel = techAccel + (techAccelPerPlayer/(i*scaling))
    -- end
    -- local techAccel = 1
    -- local malus = 0.8
    -- for i=2, pc do
    --     Echo(i,malus^(i-1))
    --     techAccel = techAccel + malus^(i-1)
    -- end
    -- Echo('player count '..pc..', techAccel=> '..techAccel)

    -- push Ctrl+M to show engine path finding
    if key==109 and mods.ctrl then debugTravel = not debugTravel Points,Lines, draw={},{}, {} end
     -- push ALT+M to toggle the mouseTesting, push J to simulate move+attack order
    if key==109 and not mods.ctrl and mods.alt then
        mouseTest=not mouseTest
        if not mouseTest then Points = {} end
        return true
    end
    if mouseTest then
        if key==264 then -- KP8 -- up the aim pos for testing purpose
            mouseUnit.aimpy=mouseUnit.aimpy+5
        end
        if key==258 then -- KP2 -- down
            mouseUnit.aimpy=mouseUnit.aimpy-5
        end
        if key==269 and mods.alt then -- alt + minus shrink debug zone
            if layers>5 then
                local z = -layers*step
                for step=step,-step,-2*step do 
                    for x=-layers*step,(layers-1)*step,step do
                        for b=z,layers*step,step do
                            z=b
                            zone[x][z]=nil
                        end
                    end
                end  
                layers=layers-1
                return true
            end
        end--minus
        if key==270 and mods.alt then -- alt + plus expand debug zone
            if layers<70 then
                autotable(zone,'on')
                layers=layers+1
                local z = -layers*step
                for step=step,-step,-2*step do
                    for x=-layers*step,(layers-1)*step,step do
                        for b=z,layers*step,step do 
                            z=b
                            zone[x][z]={tested=false}
                        end
                    end
                end
                autotable(zone,'off')
                return true
            end
        end
    end
    if key==111 then -- key O
--[[        test= not test
        if true then return true end--]]
        page=page+1
        local id = spGetSelectedUnits()[1]
        if oneAttacker then
            -- local ud = uds[spGetUnitDefID(id)]

            --Spring.SendCommands('track')
            --Debug("tracking ", ud.humanName,ud.name)

            --Page(spGetUnitRulesParams(id))

--[[            local map = spGetUnitPieceMap(id)
            piece,num = next(map,piece)
            if not piece then piece,num = next(map,piece) end
            Debug("piece,num is ", piece,num)
            if mouseUnit then
                Debug('CHECK')
                mouseUnit.aimPiece = num
                mouseUnit.aimFrom = piece
            end--]]

        end
    end

--[[    if key==94 then
        Spring.GiveOrderToUnitArray(spGetSelectedUnits(), CMD_AUTO_CALL_TRANSPORT, {1,21},0)
        --Spring.GiveOrderToUnitArray(spGetSelectedUnits(), CMD_FIND_PAD, 0,0)
        page=page+1
    end--]]

end
--GetPieceAbsolutePosition = tracefunc(GetPieceAbsolutePosition,'GetPieceAbsolutePosition')
--[[Debug("widget.MousePress is ", widget.MousePress) ;
(function()
    local loc=3
    local ori = widgetHandler.MousePress
    function widgetHandler:MousePress(dx,dy,button) Debug("from WH ", dx,dy,button) ori.MousePress(dx,dy,button) end
    function widget:MousePress(dx,dy,button) Debug('widget received',dx,dy,button) end
end)()--]]
--------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------
-------------------------------- DEFINING FUNCTIONS ----------------------------------------
--------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------

local function DefineBaseWeapons()
    for defID,ud in pairs(uds) do 
        if ud.canAttack and not ud.isFactory and ud.name~='staticnuke' then
            if ud.name=='mahlazer' or ud.name:match('dyn') then 
                -- skipping
            else
                local weapons
                if MULTI_WEAPONS[ud.name] then
                    Weapons_By_UnitDef[defID]={}
                    local weapons=Weapons_By_UnitDef[defID]
                    for weapNum,method in pairs(MULTI_WEAPONS[ud.name]) do
                        local wdef   = WeaponDefs[ ud.weapons[weapNum].weaponDef ]
                        if not wdef.manualFire or wdef.manualFire and ALLOWED_MANUAL[ud.name] then
                            --if ud.name=='shipcarrier' then for k,v in wdef:pairs() do if k:match('turn') then Debug(k,v) end end end
                            --if ud.name=='shipcarrier' then Page(wdef.customParams) end
                            --if ud.name=='striderdetriment' then Debug(weapNum,wdef.manualFire) end
                            
                            local posneg
                            if ud.name=='jumpsumo' or ud.name=='turretimpulse' then posneg = (not not wdef.name:match('pos')) end
                            local manualFire = wdef.manualFire
                            if ud.name=='bomberdisarm' and weapNum==2 then manualFire=true end
                            local aimFrom = AIM_FROM[ud.name] ; if type(aimFrom)=='function' then aimFrom=aimFrom(weapNum) end
                            weapons[#weapons+1]={ weapNum           = weapNum
                                                , stockpile         = wdef.stockpile
                                                , pershot           = method=='pershot'
                                                , aimFrom           = aimFrom
                                                , manualFire        = manualFire
                                                , reloadTime        = wdef.reload
                                                , wwaterWeapon      = wdef.waterWeapon
                                                , wtype             = wdef.type
                                                , wrange            = tonumber(wdef.customParams.combatrange) or wdef.range
                                                , wname             = wdef.name
                                                , posneg            = posneg}
                        end
                    end
                else
                    local weapNum
                    local reloadTime,wrange,wtype,wwaterWeapon,cylinderTargetting,name,manualFire = 1000,32
                    for i = 1, #ud.weapons do 
                        if ud.name=='shieldriot' then i=3 end
                        local weapon = ud.weapons[i]
                        local wdefid = weapon.weaponDef
                        local wdef   = WeaponDefs[ wdefid ]
                        --if ud.name=='bomberriot' then Debug(i,'wname',wdef.name,'wdef.range',wdef.range,'wtype',wdef.type,'wdef.reload',wdef.reload,'manual',wdef.manualFire) end -- need to fix vehcapture
                        --if ud.name=='bomberdisarm' then Debug(i,wdef.name,wdef.manualFire) end

                        if wdef.canAttackGround and (wdef.range>32 and wdef.range>wrange or ud.name=='bomberriot') and wdef.reload~=0 and not wdef.stockpile then
                            reloadTime = wdef.reload
                            weapNum = i
                            wtype=wdef.type
                            wwaterWeapon = wdef.waterWeapon
                            wrange = tonumber(wdef.customParams.combatrange) or wdef.range
                            cylinderTargetting = wdef.cylinderTargetting
                            wname = wdef.name
                            if ud.name=='bomberdisarm' then manualFire=true end
                            if ud.name=='amphsupport' or ud.name=='hoverdepthcharge' then  break  end -- correct weapon is the first one for those
                            --if ud.name=='gunshipheavyskirm' then Debug('-***') for k,v in wdef:pairs() do if k:match('cylinder') then Debug(k,v) end end end
                        end
                        if ud.name=='shieldriot' then break end 
                    end
                    --if ud.name=='bomberdisarm' then Debug("weapNum is ", weapNum) end

                    if weapNum then
                        local aimFrom = AIM_FROM[ud.name]
                        if type(aimFrom)=='function' then  aimFrom=aimFrom(weapNum) end
                        Weapons_By_UnitDef[defID]={
                            weapNum             = weapNum
                           ,cylinderTargetting  = cylinderTargetting
                           ,wwaterWeapon        = wwaterWeapon
                           ,wrange              = wrange
                           ,wtype               = wtype
                           ,reloadTime          = reloadTime
                           ,aimFrom             = aimFrom
                           ,wname               = wname
                           ,manualFire          = manualFire
                        }
                    end
                end
            end
        end
    end
end


--------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------
    
local GetReleaseFrame = (function() -- largely copied from unit_healthbars and simplified for our need
    local empDecline = 1/40
    local spGetUnitIsStunned = Spring.GetUnitIsStunned
    local spGetUnitHealth = Spring.GetUnitHealth
    local paralyzeOnMaxHealth = VFS.Include("gamedata/modrules.lua").paralyze.paralyzeOnMaxHealth

    return function(id,frame)
        local health, maxHealth, paralyzeDamage, capture, build = spGetUnitHealth(id)
        paralyzeDamage = spGetUnitRulesParam(id, "real_para") or paralyzeDamage
        if (not maxHealth)or(maxHealth < 1) then  maxHealth = 1  end
        local empHP = (not paralyzeOnMaxHealth) and health or maxHealth
        local emp = (paralyzeDamage or 0)/empHP
        local hp  = (health or 0)/maxHealth
        if hp < 0 then hp = 0  end
        --paralyze
        local paraFrame = frame
        if (emp > 0) and(emp < 1e8) and spGetUnitIsStunned(id) and paralyzeDamage >= empHP then
            paraFrame = paraFrame + (paralyzeDamage-empHP)/(maxHealth*empDecline)*15
        end
        local disarmFrame = spGetUnitRulesParam(id, "disarmframe")
        -- Debug("max(paraFrame,disarmFrame-1200) is ", max(paraFrame,disarmFrame-1200))
        return max(paraFrame,disarmFrame-1200)
    end
end)()

local function GetNewReload(id,unit,weapon,weapNum,frame,firstTime)
    local angleGood, reloaded, reloadFrame, salvo, stockPile = spGetUnitWeaponState(id,weapNum)

    -- NOTE: spGetUnitRulesParam(id, "gadgetStockpile") to get stockpile ammo creation progress
    --Debug("reloaded is ", spGetUnitWeaponState(id,4))
    --Debug(" is ", spGetUnitWeaponState(id,2))
    --Debug("spGetUnitRulesParam(id,'noammo') is ", spGetUnitRulesParam(id,'noammo'))
    if     unit.isOutlaw                                         then reloaded = frame==weapon.reloadFrame
    elseif unit.isCarrier and weapon.manualFire                  then reloaded = frame>weapon.reloadFrame and stockPile>0
    elseif unit.isBomber then
        if spGetUnitRulesParam(id,'noammo')==nil then reloaded = true
        elseif spGetUnitRulesParam(id,'noammo')~=0 then  reloaded = false end
    end
    if not firstTime then
        --NOTE: 'reloadFrame can be misleading, when it occurs with carrier and maybe other units, as it happens with 0 stockpile too, 
        -- detecting salvo firing, shot by shot
        local weapsalvo,salvosize = weapon.salvo,weapon.salvosize
        if weapon.shot_ended then weapon.shot_ended=false weapon.shooting=false end
        if unit.isCarrier and weapon.manualFire then  weapon.shot = weapon.stockPile>stockPile
        else weapon.shot = not reloaded and weapon.reloaded
        end
        weapon.shooting = weapon.shooting or weapon.shot 
        if unit.isKrow and weapon.manualFire and weapon.shooting and spGetUnitRulesParam(id,'selfMoveSpeedChange')==0.75 then
            -- Krow is carpet bombing until move speed back to normal
        elseif unit.isBomber and weapon.shooting and spGetUnitRulesParam(id,'noammo')==0 then
            -- Stiletto is shooting until 'noammo' is 1
        else
            weapon.subshot = salvosize>1 and salvo<salvosize-1 and weapsalvo==salvo+1 
            weapon.shot_ended = weapon.shooting and salvo==0
        end
        --if weapNum==1 then Debug("started:"..tostring(weapon.shooting),'ended:'..tostring(weapon.shot_ended)) end
    end
    weapon.angleGood, weapon.reloaded, weapon.reloadFrame, weapon.salvo, weapon.stockPile --angleGood is actually never used nor useful as far as I rmb
    =
         angleGood,    reloaded,          reloadFrame,        salvo,         stockPile
    --if weapon.reloaded and not reloaded then Debug(weapon.weapNum..' unloaded at '..frame) end
    return reloadFrame, salvo==0 and reloadFrame>frame, reloaded
end

local function GetNewReloads(id,unit,frame,firstTime)
    local nextFrame
    local releaseFrame = spGetUnitRulesParam(id,'att_abilityDisabled')==1 and GetReleaseFrame(id,frame)
    if unit.isStarlight then if releaseFrame and unit.nextFrame<releaseFrame then unit.nextFrame = releaseFrame  Debug('release in',unit.nextFrame-frame) end return end  
    if not unit[1] then -- no multi weapon
        nextFrame = GetNewReload(id,unit,unit,unit.weapNum,frame,firstTime)
        
        if unit.shooting and not releaseFrame then nextFrame=false end
    else
        local cemp,cfull=true,true
        local str=''
        local changeNextFrame=true
        for i,weap in ipairs(unit) do
            local reloadFrame,empty,reloaded = GetNewReload(id,unit,weap,weap.weapNum,frame,firstTime)
            if not releaseFrame and weap.shooting then changeNextFrame=false end
            if changeNextFrame then nextFrame = min(reloadFrame,nextFrame or reloadFrame) end
            cemp=cemp and empty
            cfull=cfull and (reloaded or weap.manualFire) -- don't count the manual weapon for the  fully reloaded variable
            weap.loaded=not empty
        end

        unit.fullEmpty=cemp
        unit.fullReload=cfull
        if not changeNextFrame then nextFrame = false end
    end
    if nextFrame then 
        if releaseFrame and (nextFrame-frame>10000 or releaseFrame>nextFrame) then nextFrame = releaseFrame end
        unit.nextFrame=nextFrame-4 -- maybe 4 is overkill
    end
    --Debug("unit.nextFrame is ", unit.nextFrame,frame)
end

--------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------

local DefineUnit = (function()
    -- wrapping 2 exclusives functions for DefineUnit
    local ud
    local function UpdateWeapon(id,weapNum,weapon)
        weapon.reaimTime = spGetUnitWeaponState(id,weapNum,'reaimTime')
        weapon.salvosize = spGetUnitWeaponState(id,weapNum,"burst")
        -- aiming part
        local aimFrom = weapon.aimFrom
        local aimpx,aimpy,aimpz,aimx,aimy,aimz,aimPiece
        aimPiece = aimFrom and spGetUnitPieceMap(id)[aimFrom]
        if aimPiece then
            aimpx,aimpy,aimpz = spGetUnitPiecePosition(id,aimPiece)
            aimx,aimy,aimz = GetPieceAbsolutePosition(id,aimpx,aimpy,aimpz)
        else
            aimx,aimy,aimz = select(4,spGetUnitPosition(id,true))
        end
        local wx,wy,wz,dirwx,dirwy,dirwz = spGetUnitWeaponVectors(id,weapNum)
        local diffx,diffy,diffz=wx-aimx,wy-aimy,wz-aimz
        local dist3D = (diffx^2+diffy^2+diffz^2)^0.5
        local dirx,diry,dirz=diffx/dist3D,diffy/dist3D,diffz/dist3D
        local aimDiff = abs(dirx-dirwx)+abs(diry-dirwy)+abs(dirz-dirwz)
         weapon.aimpx, weapon.aimpy, weapon.aimpz, weapon.aimx, weapon.aimy, weapon.aimz, weapon.wx, weapon.wy, weapon.wz, weapon.dirwx, weapon.dirwy, weapon.dirwz
        =    aimpx,      aimpy,        aimpz,        aimx,        aimy,        aimz,       wx,         wy,         wz,       dirwx,        dirwy,         dirwz
        weapon.aimPiece = aimPiece
        weapon.aimDiff=aimDiff
    end
    local function GetComWeapon(id,unit,weapOrder)
        -- Page(spGetUnitRulesParams(id))
        wdef=WeaponDefs[spGetUnitRulesParam(id,'comm_weapon_id_'..weapOrder)]
        if not wdef then
            return
        end

        local allowed
        local weapName = wdef.name:gsub('%d+_commweapon_',''):gsub('_improved','')
        if wdef and wdef.customParams.slot=='3' then allowed=ALLOWED_MANUAL[weapName] end -- slot 3 is the manual fire weapon
        if wdef and (wdef.customParams.slot~='3' or allowed)  then  -- ...and not a manual fire type except if allowed 
            weapNum=spGetUnitRulesParam(id,'comm_weapon_num_'..weapOrder)
            local scriptName = ud.scriptName:match('/(.*)%.lua')
            local aimFrom = scriptName and AIM_FROM[scriptName] -- normally the aim_from change depending on weapon number we track, for now we do only one weapon
            if type(aimFrom)=='function' then aimFrom=aimFrom(weapNum,id,2) end
            unit.manualOverride = OVERRIDE_MANUAL[weapName]
            return {  pershot=allowed=='pershot'
                    , manualFire=wdef.manualFire or nil
                    , weapNum=weapNum
                    , reloadTime=wdef.reload -- not used 
                    , wtype=wdef.type
                    , wrange=wdef.range
                    , aimFrom=aimFrom}
        end
    end
    -- the function to use
    local function Define(id,defID)
        ud = uds[defID]
        local frame = spGetGameFrame()
        if ud.name=='mahlazer' then
            local sat_ID=spGetUnitRulesParam(id,'has_satellite')
            if not sat_ID then return end
            local _,_,_,wdirx,wdiry,wdirz = spGetUnitWeaponVectors(sat_ID,2)
            return { aim=wdirx+wdiry+wdirz
                     , isStarlight=true
                     , sat_ID=sat_ID
                     , weapNum=1
                     , timeOut=0
                     , ncommands=0
                     , nextFrame=frame
                     , defID=defID
                     , id=id}
        end
        local isCom = ud.name:match('dyn') or ud.name:match('c%d+_base')
        -- Echo("isCom is ", isCom)
        local weapBases = not isCom and Weapons_By_UnitDef[defID]
        if not weapBases and not isCom then return end -- no valid unit
        local name = ud.name
        local multi
        local newUnit={}
        -- for both com and regular unit
        newUnit.pershot = PER_SHOT[name]
        newUnit.nowait=NO_WAIT[name]
        newUnit.id=id
        newUnit.defID=defID
        newUnit.heading = spGetUnitHeading(id)
        newUnit.timeOut = 0
        newUnit.name = name
        newUnit.shotAt=0
        newUnit.ncommands=0
        newUnit.repeating = AUTO_REPEAT and (name:match('arty')--[[ or ud.name:match('support') or newUnit.longrange--]])
        newUnit.speed = ud.speed
        newUnit.longestRange=120
        newUnit.manualOverride = OVERRIDE_MANUAL[name]
        newUnit.spacing = SHOT_SPACING[name]
        newUnit.lastFrame = spGetGameFrame()
        local isType=IS_TYPE(ud)
        if isType then newUnit[isType]=true end
        local isName=IS_NAME[name]
        if isName then newUnit[isName]=true end
        ---
        if isCom then
            weapBases = GetComWeapon(id,newUnit,1)
            local weap2 = GetComWeapon(id,newUnit,2)
            if weap2 then weapBases,multi={weapBases,weap2},true end
        end


        -- if only one weapon, there's not subtable (maybe it should?)
        if weapBases[1] then
            newUnit.multi= multi or MULTI_CHECKS[name]
            for i,base in ipairs(weapBases) do 
                newUnit[i]=copy(base)
                local weapon = newUnit[i]
                UpdateWeapon(id,weapon.weapNum,weapon)
                newUnit.longrange=newUnit.longrange or weapon.wrange>450
                if weapon.wrange> newUnit.longestRange then newUnit.longestRange=weapon.wrange end
            end
            GetNewReloads(id,newUnit,frame,'firstTime')
        else
            for k,v in pairs(weapBases) do newUnit[k]=v end
            UpdateWeapon(id,newUnit.weapNum,newUnit)
            GetNewReloads(id,newUnit,frame,'firstTime')
            if newUnit.wrange> newUnit.longestRange then newUnit.longestRange=newUnit.wrange end
        end


        return newUnit
    end
    return Define
end)()

 -- redefine weapons of com morphed
function MorphFinished(oldID,newID)
    if unitsToTrace[oldID] then --
        local frame = spGetGameFrame()
        frame_morph = frame
        unitsToTrace[newID]=DefineUnit(newID,spGetUnitDefID(newID))
        unitsToTrace[newID].ncommands=unitsToTrace[oldID].ncommands
        unitsToTrace[oldID]=nil
        if oneAttacker == oldID then oneAttacker = newID end
    end
end


--------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------
-------------------------------- UPDATE UNIT ORDERS ----------------------------------------
--------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------
-- release repeated orders after release of the mouse
local function ReleaseBuffer(id)
    local buffer = bufferAttacks[id]
    buffer.release,buffer.onClickRelease=nil,nil
    for _,xyzo in ipairs(buffer) do spGiveOrderToUnit(id,CMD_ATTACK,xyzo,spuAndBit(CMD_OPT_SHIFT,CMD_OPT_INTERNAL)) end
    bufferAttacks[id]=nil
end
-- 
local function RemoveOrder(id,unit,tag,x,y,z,param,switched)
    unit.moved=false -- unit has only one chance to look for a suitable position for each attack order
    -- Debug('switched',switched)
    if not switched then unit.switched=false end -- switched  will come only after a succesful switch of target
    if unit.cancelstrafe then spGiveOrderToUnit(id,CMD_AIR_STRAFE,0,0) end
--[[    if unit.waitManual then 
        unit.waitManual=false
        if unit.isCarrier and not unit.recalled then Debug('recalling...') spGiveOrderToUnit(id,CMD_RECALL_DRONES,0,spuAndBit(CMD_OPT_SHIFT,CMD_OPT_INTERNAL)) unit.recalled=spGetGameFrame() end
    end--]]
    local remove = true

    if unit.ncommands==1 and not spGetUnitStates(id)['repeat'] then
        -- it can happen an order hasnt been reported by CN and UCN with Starlight, we verify
        local queue = spGetCommandQueue(id, -1)
        local ln = #queue

        if ln==1 then
            unitsToTrace[id]=nil
            if unit.isStarlight then -- we don't remove the last order for starlight
                return
            end 
        elseif ln>1 then
            local ord = queue[2]
            if ord.id==20 and ord.params[3] then
                Debug('the ncommands mismatch, next order is  attack ground target, upping the ncommands, total queue: '..#queue )
                unit.ncommands=2
            end
        end
    end
    -- Echo('remove ',os.clock())
    spGiveOrderToUnit(id, CMD_REMOVE, tag, 0)
    unit.waitremove=tag
    unit.timeOut=0
    if not unit.has_stopped and param~='norepeat' and (spGetUnitStates(id)['repeat'] or unit.repeating) then
        unit.ncommands = unit.ncommands+1
        if not param and oneAttacker==id and select(3,spGetMouseState()) then param = 'onClickRelease' end
        if param then
            if not bufferAttacks[id] then bufferAttacks[id]={} if param=='onClickRelease' then bufferAttacks[id].onClickRelease=true end end
            insert(bufferAttacks[id],{x,y,z,MY_WIDGET_CODE}) -- wait the release of click to complete the loop, much more simple like that
        else 
            xyzo[1], xyzo[2], xyzo[3] = x,y,z

            --Page(xyzo)
            if unit.isStarlight or unit.isDRP then
                spGiveOrderToUnit(id,CMD_ATTACK,xyzo,CMD_OPT_SHIFT) 
            else
                spGiveOrderToUnit(id,CMD_ATTACK,xyzo,CMD_OPT_SHIFT+CMD_OPT_INTERNAL+CMD_OPT_ALT) 
            end
        end
    end
--[[    local nextorder = spGetCommandQueue(id,2)[2]
    if nextorder then Debug("nextorder.id is ", nextorder.id) end--]]
--[[    if nextorder and nextorder.id==20 and nextorder.params[3] then --spGiveOrderToUnit(id,CMD_UNIT_SET_TARGET,nextorder.params,0)
        local x,y,z=unpack(nextorder.params) Points[1]={x,y,z,color=colors.blue+1,size=30} --Debug('set new',Spring.GetCommandQueue(id,0)) Debug('--'..spGetGameFrame())
    else Debug('no next order')
    end--]]
    --if nextorder then Page(nextorder[1]) end
    --unit.ncommands=unit.ncommands-1
    --Debug("unit.ncommands is ", unit.ncommands)
    --if unit.ncommands==0 then unitsToTrace[id]=nil end
end
local function InsertOrder(unit,cmd,x,y,z,p1,p2,ins)
    INS[2] = cmd
    INS[4],INS[5],INS[6]=x,y,z
    if ins then INS[1] = ins end
    if p1 then INS[7],INS[8]=p1,p2 end--
    spGiveOrderToUnit(unit.id, CMD_INSERT, INS, CMD_OPT_ALT+CMD_OPT_SHIFT+CMD_OPT_INTERNAL )
    if unit.switched then unit.ncommands=unit.ncommands+1 end
    --INS[2]=CMD_ATTACK
    if p1 then INS[7],INS[8]=5,nil end -- back to widget code if p1 (mean that was a RAW_MOVE order)
end

--------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------
-------------ZONE CHECKING to find a spot to shoot from when stuck--------------------------
--------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------


-- simulating aiming from other positions, spiraling around the unit position to find a suitable spot to shoot from and eventually an extra waypoint to go to that spot
-- this is not quite effective with indirect weapon
-- there is a nice debugging option to visually see the zone, see KeyPress callin
local FindWay,resetzone
do
    zone = autotable{}
        zone[0][0]={tested=false}
        -- spiraling loop
        for layer=1,layers do -- this method seems overkill as it lock the z generator to one value half of the time, but it's actually 40% faster than while or repeat or even for loop with linked cells
            local z = -layer*step
            for step=step,-step,-2*step do -- browse half of perimeter per i
                for x=-layer*step,(layer-1)*step,step do -- start at first x, end at one step before last x / start at last x end at one step before first x
                    for b=z,layer*step,step do -- loop will stay at z value at each second to last iteration of x
                        z=b-- memorize b to keep the max value ready for the next iteration -- loop will iterate only once at each second iteration of x
                        zone[x][z]={tested=false}
                    end
                end
            end  
        end    
    autotable(zone,'off')
    resetzone = function() for _,col in pairs(zone) do for z in pairs(col) do col[z].tested=false end end end

    local cnt = 0
    local time = 0
    local bx,by,bz,x,y,z
    local range,betterRange,aimHeightDiff
    local debugging
    local id,defID,weapNum
    local function DefineCell(cell,nbx,nbz)
        cell.tested=true
        local nby = spGetGroundHeight(nbx,nbz)
        local naimy = nby+aimHeightDiff
        local move= spTestMoveOrder(defID, nbx, nby, nbz) 
        local LoF =  spGetUnitWeaponHaveFreeLineOfFire(id,weapNum,nbx,naimy,nbz,x,y,z)
        --local nwy = nby+weapHeightDiff
        --local LoF = spGetUnitWeaponHaveFreeLineOfFire(id,weapNum,nbx,nwy,nbz,x,y,z)
        local cellrange = ((nbx-x)^2+(nby-y)^2+(nbz-z)^2)^0.5
        local inRange = cellrange<=range
        local inbetterRange = inRange and cellrange<=betterRange
        local buildable = spTestBuildOrder(defID, nbx, 0, nbz, 1)==2 -- complete the move order testing -- TODO: fix the false positive on empty mex spot (ret==1)
        local distUnit = ((nbx-bx)^2+(nby-by)^2+(nbz-bz)^2)^0.5
        --
        cell.nby=nby
        cell.move = move
        cell.naimy = naimy
        cell.nwy = nwy
        cell.LoF = LoF
        cell.range = cellrange
        cell.inRange = cellrange<=range
        cell.inBetterRange = cellrange<=betterRange
        cell.buildable = buildable
        cell.distUnit = distUnit
        cell.validSpot=(buildable or testmove) and inRange and LoF
        cell.goodSpot=false
        cell.edge=false
        cell.step=false
        return LoF
    end
    local function CheckAround(cell,nbx,nbz,x,z) -- find out if the surrounding cells have LoF and also if they are in range,
                                                 -- LoF check to have a sweet spot to shoot from rather than on the edge that is on the way
        local isGoodSpot,isEdge=true,false
        local step,offz=step,-step
        for step=step,-step,-2*step do 
            for offx=-step,0,step do 
                for b=offz,step,step do 
                    offz=b
                    local c_cell = zone[x+offx] and zone[x+offx][z+offz]
                    if c_cell then
                        local LoF = not c_cell.tested and DefineCell(c_cell,nbx+offx, nbz+offz) or c_cell.LoF
                        if isGoodSpot then isGoodSpot=LoF end
                        if not isEdge and not c_cell.inRange then cell.edge,isEdge=true,true end
                        if isEdge and not isGoodSpot then return false end-- no need to check further
                    end
                end
            end
        end
        cell.goodSpot = isGoodSpot
    end
    local function IsPathable(cell,nbx,nbz,offx,offz,px,py,pz) -- check if the unit can walk to the spot - if px is defined, look from it, else look from the unit position
        if not px then px,py,pz = bx,by,bz end
        local nby = cell.nby
        local dist=cell.distUnit
        local dirx,dirz = nbx-px,nbz-pz
        dirx,dirz = dirx/dist,dirz/dist
        local projx,projy,projz = px,py,pz
        local inc, n, success, path
            =  0,  0,  false,   {}
        while abs(nbx-projx)>=8 or abs(nbz-projz)>=8 do
            inc=inc+1
            projx,projz=px+dirx*8*inc,pz+dirz*8*inc
            projy=spGetGroundHeight(projx,projz)
            success= spTestBuildOrder(defID, projx, 0, projz, 1)==2 or spTestMoveOrder(defID, projx,projy,projz)
            if not success then return end
            if inc>200 then Debug('TOO MANY TRIES')return end
            if debugging then
                n=n+1 ; path[n]={projx,projy,projz}
            end
        end 
        path.goal,path.dist,path.cell = {nbx,nby,nbz},dist,cell
        return path
    end
    local function FindSpot(ID,unit,weapon,WeapNum,tx,ty,tz,Debugging,two_step) -- TODO: FIX doesnt work so well for  indirect weapon, HaveFreeLineOfFire is not always relevant in that case
        debugging = Debugging
        weapNum = WeapNum
        x,y,z = tx,ty,tz
        id = ID
        local aimx,aimy,aimz 
        if weapon.aimPiece then
            aimx,aimy,aimz = GetPieceAbsolutePosition(id,spGetUnitPiecePosition(id,weapon.aimPiece))
        else
            aimx,aimy,aimz = select(4,spGetUnitPosition(id,true))
        end
        bx,by,bz = spGetUnitPosition(id)
        bx,bz=8+floor(bx/16)*16,8+floor(bz/16)*16 -- get a base position at a middle of a square
        by = spGetGroundHeight(bx,bz)
        local nbx,nby,nbz
        local currentRange = ((bx-x)^2+(bz-z)^2)^0.5
        aimHeightDiff = max(5,aimy-by) -- flea can sometime (when buried) have negative aimpoint which fucks up the aiming evaluation
        defID = unit.defID
        range = weapon.wrange

        betterRange=currentRange<range and currentRange or range 
        local path,movestep
        resetzone()

        local layer,maxlayers=0,150
        -- cannot test range with engine using customized position, that's a problem
        -- also note that engine (or unit script?) is bugged when not coming closer and staying out of range in some situation even with engine test Range reporting false correctly
        -- the FreeLineOfFire is not a good enough measure it can return true even on the edge of volume but unit will not shoot, so we get some margin by checking the cells around
        -- limitations: -range might not be correctly checked, depends on targetting of unit
        --              -TestMoveOrder return false on narrow spot even though the unit could go there

        -- ordinator
        DefineCell(zone[0][0],bx,bz)
        for layer=1,layers do 
            local offz = -layer*step
            for step=step,-step,-2*step do -- browse half of perimeter per iteration
                for offx=-layer*step,(layer-1)*step,step do -- start at first x, end at one step before last x // start at last x end at one step before first x
                    for b=offz,layer*step,step do
                        offz=b -- memorize b until last iteration -- loop will iterate only once at each second iteration of offx
                        nbx,nbz = bx+offx,bz+offz
                        local cell=zone[offx][offz]
                        if not cell.tested then DefineCell(cell,nbx,nbz) end
                        if cell.validSpot then CheckAround(cell,nbx,nbz,offx,offz) end -- find out if it's a goodSpot
                        if cell.goodSpot  then
                            if not path or cell.distUnit<path.dist then
                                 -- this pathable check is in case of looking for a waypoint before going to the shooting position,
                                 -- path finder of this widget is out of purpose and rudimentary, check only for a not-too-narrow pathable straight line
                                 -- , and eventually a second waypoint if needed
                                 -- TODO: rewrite a better pathfinder using already existing helpers
                                if not two_step or IsPathable(cell,nbx,nbz,offx,offz,x,y,z) then
                                    path = IsPathable(cell,nbx,nbz,offx,offz) or path
                                end
                            end
                            if not path and not cell.edge then -- remembering that cell for a future two_step move in case we don't find a path straight
                                if not movestep or cell.distUnit<movestep.distUnit then
                                    movestep=movestep or {}
                                    movestep.distUnit,movestep[1],movestep[2],movestep[3]=cell.distUnit,nbx,cell.nby,nbz
                                end
                            end
                        end
                    end
                end
            end
            if not debugging and path then break end -- no need to check further we won't find a shorter path spot (the more is 'layer' the farther it is)
        end
        return path or movestep, path and true
    end
    FindWay = function(id,unit,weapon,weapNum,x,y,z,debugging,pressed)
        cnt=cnt+1
        local record=spGetTimer()
        if unit.isImmobile or not debugging and unit.moved then return end
        local move,straight = FindSpot(id,unit,weapon,weapNum,x,y,z,debugging)
        local goal = straight and move.goal or move
        if goal then
            local moves={goal}
            local firstgoal={goal[1],goal[2],goal[3],color=colors.red+1,size=16}
             -- this might be dismissed in the future, the script is not meant to be a path finder
            if not straight then
                move,straight = FindSpot(id,unit,weapon,weapNum,goal[1],goal[2],goal[3],debugging,'moving')
            end
            if straight then
                goal = move.goal
                if goal then insert(moves,goal) end
                if not debugging then
                    for i,step in ipairs(moves) do InsertOrder(unit,CMD_RAW_MOVE,step[1],step[2],step[3],16,2) end-- set CMD_RAW_MOVE secondary params
                    unit.orders=nil
                else
                    if pressed and not unit.ordered then
                        InsertOrder(unit,CMD_ATTACK,x,y,z)
                        for i,step in ipairs(moves) do InsertOrder(unit,CMD_RAW_MOVE,step[1],step[2],step[3],16,2) end-- set CMD_RAW_MOVE secondary params
                        unit.ordered,unit.orders=true,nil
                    end
                    local white = colors.white+0.8
                    for i,p in ipairs(move) do p.color,p.size=white,12 ; Points[#Points+1]=p end -- make a white trail on the first waypoint
                    Points[#Points+1]=firstgoal
                    Points[#Points+1]={goal[1],goal[2],goal[3],color=colors.yellow+1,size=16}
                end
                unit.moved=true
                unit.timeOut=0
            else
                --Debug('third step...')
            end
        end
        time=(time+spDiffTimers(spGetTimer(),record))
        if cnt%10==0 then Debug(time/cnt) end
        return straight -- found one or 2 waypoints
    end
end
--------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------
----------- SHIFTING TARGET POS when couldnt find a spot to shoot --------------------------
--------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------
local news=0
local function GetNewTarget(id,unit,weapNum,x,y,z,ins) -- spiraling around the original ground target until finding a potential good spot
    if unit.switched then return end -- already tried a switch
    news=news+1
    Debug('get a new target',news,os.clock())
    INS[1]=ins and ins+1 or 0
    local wx,wy,wz = spGetUnitWeaponVectors(id,weapNum)
    local step = 8
    -- Points={}
    for layer=1,3 do
        local nz = z-layer*step
        for step=step,-step,-2*step do
            for nx=x-layer*step,x+(layer-1)*step,step do
                for b=nz,z+layer*step,step do
                    nz=b
                    local ny = spGetGroundHeight(nx,nz)
                    -- Points[#Points+1]={nx,ny,nz,color=colors.red+1,size=5}
                    --if spGetUnitWeaponCanFire(id,weapNum) then
                    if spGetUnitWeaponHaveFreeLineOfFire(id,weapNum,nil,nil,nil,nx,ny,nz)
                    and spGetUnitWeaponTestRange(id,weapNum,nx,ny,nz)
                    then
                        unit.switched=true
                        InsertOrder(unit,CMD_ATTACK,nx,ny,nz)
                        --spGiveOrderToUnit(id,CMD_INSERT,INS,spuAndBit(CMD_OPT_ALT+CMD_OPT_SHIFT,CMD_OPT_INTERNAL))
                        INS[1]=0
                        return true
                    end
                end
            end
        end
    end
    INS[1]=0
    return unit.switched
end

function widget:MousePress(mx,my,button)
    --spGetActiveCommand()==16 and button==1
    -- Echo('mp')
    -- local unit = spGetSelectedUnits()[1]
    -- if unit and button==3 then
    --     local _,pos = spTraceScreenRay(mx,my)
    --     pos[4],pos[5],pos[6] = 150,0
    --     spGiveOrderToUnit(unit,CMD_RAW_MOVE,pos,0)
    --     return true
    -- end
end
local function UpdateUnit(cmd,params,opts)
    local id = oneAttacker
    local unit = unitsToTrace[id]
    local validAttack = cmd==CMD_ATTACK and params[3] and 'direct' or cmd==CMD_INSERT and params[2]==20 and params[5] and 'insert'
    local registerAttack =   select(1,spGetModKeyState()) and cmd==20 and params[3]
                         or  validAttack and (spuCheckBit('name',opts.coded,CMD_OPT_INTERNAL) or unit and validAttack=='insert')
    if cmd==0 and unit then 
        unitsToTrace[id]=nil
        return
    end
    if registerAttack then
        if not unit then 
            unitsToTrace[id] = DefineUnit(id,spGetUnitDefID(id))
            unit = unitsToTrace[id]
            Debug('creating new unit',oneAttacker,id,unit)
            if not unit then return end
        end
        if not opts.shift then unit.ncommands=0 unit.timeOut=0 unit.waitManual=false unit.drop=false unit.nextFrame=spGetGameFrame() end
        if unit.isStiletto and unit.ncommands==12 then return true end
        if unit.spacing then 
            if spacing~=unit.spacing then
                spacing=unit.spacing ; setupvalue(CF2MouseMove,numSpacing,spacing)
                Debug('setup') Debug('--')
            end
        elseif spacing~=50*50 then
            spacing=50*50
            setupvalue(CF2MouseMove,numSpacing,spacing)
            Debug('setup') Debug('--') 
        end
        unit.ncommands = unit.ncommands+1
        Debug('>>'..unit.ncommands,spacing)

        --if unit.isStiletto and unit.ncommands>13 then ordersToRemove[id]=params return end
        --if unit.isImmobile and not spGetUnitWeaponTestRange(id,(unit.weapNum or unit[1].weapNum),params[1],params[2],params[3]) then ordersToRemove[id]=params ordersToRemove.fix=true end
        if not spGetMouseState() then oneAttacker=false end
        --for k,v in pairs(unitsToTrace[id]) do Debug(k,v) end
    end
    if not unit then return end
    
    if unit.isImmobile then
        local x,y,z = unpack(params)
        local weapNum = unit.weapNum or unit[1].weapNum
        if not spGetUnitWeaponTestRange(id,weapNum,x,y,z) then
            GetNewTarget(id,unit,weapNum,x,y,z)
            return true
        end
    end
    -- if only one combat unit is selected with the appropriate command
end
local currentSel
function widget:UnitCommandNotify(id,cmd,params,opts)
    if oneAttacker then return UpdateUnit(cmd,params,opts) end
end

function widget:CommandNotify(cmd, params, opts)

    -- --- MOVE THIS OUT OF THE WIDGET // just to better the moves of gunshiptrans and gunshipraid when trailing with custom formation // (it need the modification of Custom Formation present in here)
    -- NOTE: the params table argument is unique (like any table), other widgets will receive the modified table
    -- if cmd==CMD_RAW_MOVE and not params[4] then --CMD_RAW_MOVE
    --     --if not params[4] then cmd = CMD_MOVE end
    --     --cmd=CMD_MOVE
    --     for i,id in ipairs(currentSel) do
    --         local defid = spGetUnitDefID(id)

    --         local def = uds[defid]
    --         if not def then
    --             return
    --         end
    --         if def.name=='gunshiptrans' then params[4],params[5]=100,0.5  -- 100 is the distance in which the time out (0.5) begin 
    --         elseif def.name=='gunshipraid' then params[4],params[5]=175,0.5 
    --         else
    --             params[4],params[5]=nil,nil 

    --         end
    --     end
    --     return --true
    -- end
    ------------------
    if not oneAttacker then return end
    return widgetHandler:UnitCommandNotify(oneAttacker,cmd,params,opts)
end
local ordersToRemove={} -- immediately removing orders of inaccessible targets for static defense
local ordersToReplace={} -- immediately replacing order in some very special case (napalm bomber or disarm bomber)
-- for debugging
local cmdNames = {}
for k,v in pairs(CMD) do if v==1 then k='INSERT' elseif v==20 then k='ATTACK' elseif v==2 then k='REMOVE' elseif v==0 then k='STOP' end cmdNames[v]=k end
for k,v in pairs(customCmds) do if v==1 then k='INSERT' elseif v=='20' then  k='ATTACK' elseif v==2 then k='REMOVE' elseif v==0 then k='STOP' end cmdNames[v]=k end
--
local ACCEPTABLE_CMDS = {[CMD_AIR_STRAFE]=true,[CMD_WAIT]=true,[CMD_RECALL_DRONES]=true,[CMD.STOCKPILE]=true,[CMD_MANUALFIRE]=true,[CMD_INSERT]=true,[CMD_ATTACK]=true,[CMD.MOVE_STATE]=true,[CMD_REMOVE]=true,[CMD.FIRE_STATE]=true,[CMD.TRAJECTORY]=true,[CMD.REPEAT]=true,[CMD.ONOFF]=true}
local ACCEPTABLE_OPTCODE={[32]=true,[48]=true,[128]=true,[136]=true, [255]=true}
local cnt=0
local trailing

function widget:UnitCommand(id, defID, team, cmd, params, opts, tag)
--------- debugging
local unit = unitsToTrace[id]
if unit then
    -- Echo('cmd: '..cmd..' '..(cmdNames[cmd] or cmd))
    -- Echo('params:',unpack(params))
    -- local str = ''
    -- for k,v in pairs(opts) do str=str..k..': '..tostring(v)..', ' end
    -- Echo('opts:',str)
end
--[[if cmd==25 or cmd==45 or cmd==16 then return end

Debug('cmd: '..cmd..' '..(cmdNames[cmd] or cmd))
Debug('params:',unpack(params))
local str = ''
for k,v in pairs(opts) do str=str..k..': '..tostring(v)..', ' end
Debug('opts:',str)--]]
----------
if cmd==33410 then return end
cnt=cnt+1
    --Debug(cnt,spGetUnitCurrentCommand(id),(cmd==1 and params and 'insert '..params[2] or cmd==2 and params and 'remove '..params[1] or cmd))
    --Debug('--')
    if framemorph== spGetGameFrame() then
        return
    end
    local unit = unitsToTrace[id]
    if unit then
        if cmd==CMD_REMOVE then 
            if unit.waitremove==params[1] then 
                unit.ncommands=unit.ncommands-1
                unit.waitremove=false
                --Debug('<<',unit.ncommands,spGetGameFrame())
                if unit.ncommands==0 and not spGetUnitStates(id)['repeat'] then
                    --Debug('0 end, '..unit.name)
                    if unit.isGS then
                        -- GS will keep a fighting stance even with no more targets and order, therefore we order it to stop
                        if spGetCommandQueue(id,0)==1 then spGiveOrderToUnit(id,CMD_STOP,0,0) end
                    end
                    Debug('removed last order, stop tracking ', id)
                    unitsToTrace[id]=nil 
                end
                return
            elseif unit.needunstuck then
                spGiveOrderToUnit(unpack(unit.needunstuck))
                unit.needunstuck=nil
            end
        elseif not ACCEPTABLE_CMDS[cmd] and not ACCEPTABLE_OPTCODE[opts.coded] then
            spGiveOrderToUnit(id,CMD_UNIT_CANCEL_TARGET,0,0)
            --if cmd==CMD_STOP then unit.hasstopped=true end
--[[            Debug('CANCELLED by '..cmdNames[cmd])
            Debug("cmd:"..cmd,'Params: ',unpack(params))
            Debug("opts.coded is ", opts.coded)--]]
            local ud = uds[spGetUnitDefID(id)]
            unit.has_stopped=true
            Debug('command '..cmd..' with '..opts.coded..' stopped tracing '..ud.humanName,ud.name)
            -- Echo('command '..cmd..' with '..opts.coded..' stopped tracing '..ud.humanName,ud.name)
            unitsToTrace[id]=nil
            return
        end
    end
--[[    -- if only one combat unit is selected with the appropriate command
    local registerAttack =   oneAttacker and oneAttacker==id and select(1,spGetModKeyState()) and cmd==20
                         or  spuCheckBit('name',opts.coded,CMD_OPT_INTERNAL)
                         and (cmd==CMD_ATTACK and params[3] or cmd==CMD_INSERT and params[2]==20 and params[5])
    if registerAttack then
        if not unit then 
            unitsToTrace[id] = DefineUnit(id,defID)
            unit = unitsToTrace[id]
        end
        if not opts.shift then unit.ncommands=0 unit.timeOut=0 end
        unit.ncommands = unit.ncommands+1
        Debug('>>'..unit.ncommands)


        --if unit.isStiletto and unit.ncommands>13 then ordersToRemove[id]=params return end
        --if unit.isImmobile and not spGetUnitWeaponTestRange(id,(unit.weapNum or unit[1].weapNum),params[1],params[2],params[3]) then ordersToRemove[id]=params ordersToRemove.fix=true end
        if not spGetMouseState() then oneAttacker=false end
        --for k,v in pairs(unitsToTrace[id]) do Debug(k,v) end
    end--]]
end

local excludedFactory = {
    [UnitDefNames["factorygunship"].id] = true,
    [UnitDefNames["factoryplane"].id] = true
}

function widget:UnitFromFactory(unitID, unitDefId, team, factId, factDefId, userOrders)
    -- register valid units that have attacking orders from factory
    -- unstuck units attacking from their born position from factory
    local defID = spGetUnitDefID(unitID)
    local ud= uds[unitDefId]
    unitID = ud.canAttack and (Weapons_By_UnitDef[unitDefId]) and unitID
    if not unitID then return end
    local unit
    local onlyattacks=true
    for i,order in ipairs(spGetCommandQueue(unitID,-1)) do
        if order.id==20 and order.params[3] then
            if not unit then if not unitsToTrace[unitID] then unitsToTrace[unitID] = DefineUnit(unitID,unitDefId) end unit=unitsToTrace[unitID] end
            unit.ncommands=unit.ncommands+1
            -- unstuck part
            if i==2  and not excludedFactory[factDefId]then 
                -- in our situation, a move order is given when going out of factory, but is getting automatically removed
                -- therefore we check if our unit gonna stay on the factory creation spot and fix it if needed
                local tgtx,tgtz = order.params[1],order.params[3]
                local posx,posy,posz = spGetUnitPosition(unitID)
                local mindist = ((tgtx-posx)^2+(tgtz-posz)^2)^0.5 - 100
                local inRange
                if unit[1] then for i,weap in ipairs(unit) do inRange = mindist<weap.wrange if inRange then break end end
                else inRange=mindist<unit.wrange end
                if inRange then 
                    -- shift the direction randomly with a maximum of 2/3 of a turn
                    local dx,_,dz = Spring.GetUnitDirection(unitID)
                    local max = round(dx)==0 and dz or dx
                    local off = max-rand()*1.66*max
                    local bigoff= (abs(off)>0.5 and (off<0 and -1 or 1) or off) -- the shifted original direction (for the coord beeing -1 or 1)
                    local smalloff = (bigoff==1 and (1-abs(off)) or 1)*(rand()>0.5 and 1 or -1) -- adapt the ratio completing off, inversed randomly
                    dx=dx==max and bigoff or smalloff
                    dz=dz==max and bigoff or smalloff
                    -- expand more and more if a big amount of units are beeing produced around the factory
                    local expand = 100+#spGetUnitsInCylinder(posx,posy,posz,myTeamID, 250)*2
                    posx=posx+(dx)*expand
                    posz=posz+(dz)*expand
                    local posy=spGetGroundHeight(posx,posz)
                    -- give a delayed order applied when it will receive the remove order
                    unit.needunstuck={unitID,CMD_INSERT, {0, CMD_MOVE, 0, posx, posy, posz}, CMD_OPT_ALT}
                end
            end
            --widget:UnitCommandNotify(unitID,order.id,order.params)
        elseif i>1 then
            onlyattacks=false
        end
    end
end



-- should be useless
function widget:UnitCmdDone(unitID, unitDefID, unitTeam, cmdID, cmdParams, cmdOpts, cmdTag)
--Debug(cmdID,'done',spGetGameFrame())
--[[    local unit = unitsToTrace[unitID]
    if unit and cmdID==20 and cmdParams[3] then
        local cmdID,coded,tag,x,y,z = spGetUnitCurrentCommand(unitID)

        Points[4]={x,y,z              ,color=colors.white+0.5 ,size=50}
        if cmdID==20 and z and z~=cmdParams[3] then Debug(cmdParams[1]..':update set:'..x,spGetGameFrame()) spGiveOrderToUnit(unitID,CMD_UNIT_SET_TARGET,{x,y,z},0) end
    end--]]
--[[    local unit = unitsToTrace[unitID]
    if unit and cmdID==20 then
        if unit.waitremove==cmdTag then
            unit.waitremove=false
            unit.ncommands=unit.ncommands-1 
            --spGiveOrderToUnit(unitID,CMD_UNIT_CANCEL_TARGET,0,0)
            --local cmdID,coded,tag,x,y,z = spGetUnitCurrentCommand(unitID)
            --if cmdID==20 and z then spGiveOrderToUnit(unitID,CMD_UNIT_SET_TARGET,{x,y,z},0) end
            --Debug('<<'..unit.ncommands)

            if unit.ncommands==0 then
                Debug(stats.success..' success over'..stats.failed..' fails: '..round(stats.failed/(stats.success+stats.failed),2))
                stats.success,stats.failed = 0,0
            end
        end
    end--]]
end




function widget:CommandsChanged()
    currentSel = spGetSelectedUnits()
    oneAttacker = not currentSel[2] and currentSel[1]
    if oneAttacker  then
        local defID = spGetUnitDefID(oneAttacker)
        local ud= uds[defID]
        oneAttacker = ud.canAttack and not ud.isFactory and (Weapons_By_UnitDef[defID] or ud.name:match('dyn') or ud.name=='mahlazer') and oneAttacker
    end
end
------------------------------------------------------------------------
------------------------------------------------------------------------
------------------------------------------------------------------------
-------------------------- CHECKING FUNCTION
------------------------------------------------------------------------
------------------------------------------------------------------------
------------------------------------------------------------------------
local function CheckAiming(id,unit,weapon,wx,wy,wz,dirwx,dirwy,dirwz) -- compare muzzle direction to wanted direction
    local weapon = weapon or unit
    if not wx then
        wx,wy,wz,dirwx,dirwy,dirwz = spGetUnitWeaponVectors(id,weapon.weapNum)
    end
    local aimx,aimy,aimz 
    if weapon.aimPiece then
        aimx,aimy,aimz = GetPieceAbsolutePosition(id,spGetUnitPiecePosition(id,weapon.aimPiece))
    else
        aimx,aimy,aimz = select(4,spGetUnitPosition(id,true))
    end
    if aimx==wx and (unit.isBertha or unit.isRonin) then -- when bertha started with no order, GetUnitWeaponVector bug we get the correct piece ourself -- same for ronin
         wx,wy,wz = GetPieceAbsolutePosition(id,spGetUnitPiecePosition(id,spGetUnitPieceMap(id)['muzzle']))
    end
    local dirx,diry,dirz=wx-aimx,wy-aimy,wz-aimz
    local dist3D = (dirx^2+diry^2+dirz^2)^0.5
    dirx,diry,dirz=dirx/dist3D,diry/dist3D,dirz/dist3D
    local aimDiff = abs(dirx-dirwx)+abs(diry-dirwy)+abs(dirz-dirwz)
    local delta = abs(aimDiff-weapon.aimDiff)
    weapon.aimDiff=aimDiff
    return (unit.isDRP or unit.isBertha) and delta>0.001 or delta>0.005--[[ and aimDiff<weapon.aimDiff--]] , delta, aimy
end


local function isMoving(velx,vely,velz) return velx^2+vely^2+velz^2>0.008 end
local function IsDisabled(id)
    -- is active?
    if not spGetUnitIsActive(id) then return true end
    -- disarmed?
    if spGetUnitRulesParam(id, "disarmed")==1 then return true end
    -- paralyzed?
    local _,maxhp,paraDmg = spGetUnitHealth(id)
    local paralyzed = (spGetUnitRulesParam(id, "real_para") or paraDmg)>maxhp        
    if paralyzed then return true end    
end
local function CheckOutlaw(id,unit,weapon,x,y,z,tag)
    local _,_,reloadFrame = spGetUnitWeaponState(id,weapon.weapNum)
    local _,_,_,mx,my,mz = spGetUnitPosition(id,true,true)
    if ((mx-x)^2+(my-y)^2+(mz-z)^2)^0.5<290 then -- dist3D < 290
        if weapon.reloadFrame<reloadFrame then RemoveOrder(id,unit,tag,x,y,z) end
        weapon.reloadFrame=reloadFrame
    end
end
local function CheckZenith(id,unit,x,y,z,tag,frame)
    if IsDisabled(id) then return end
    unit.nextFrame=frame+45
    RemoveOrder(id,unit,tag,x,y,z)
end
local function CheckStarlight(id,unit,x,y,z,owner,tag,frame)
    local sat_ID = spGetUnitRulesParam(id,'has_satellite')
        -- no satellite?
    if not sat_ID then return
--[[        -- disabled?
        or IsDisabled(id)
        -- gonna unload?
        or spGetUnitWeaponCanFire(id,1,true,true,true)
        then unit.nextFrame=frame+30 Debug('wait 1 sec') return--]]
    end
    -- stuck?
    local wx,wy,wz,dirwx,dirwy,dirwz = spGetUnitWeaponVectors(sat_ID,2)
    local aim = dirwx+dirwy+dirwz
    if (aim-unit.aim)==0 then unit.timeOut=unit.timeOut+1 if unit.timeOut>30 then RemoveOrder(id,unit,tag,x,y,z) end end
    unit.aim=aim
    -- have valid target ?
    local targetType,isUserTarget,groundTarget = spGetUnitWeaponTarget(id,unit.weapNum)
    if targetType==1 then 
        -- Update: FIXED by sending Attack with CMD_OPT_SHIFT only instead of shift + alt + internal
        -- for some reason when on repeat, after the first cycle of order, the starlight conflict with the current ground target and a unit it would attack if it was stopped
        -- so laser hesitate between the two, and would give up the current ground attack order on its own after some delay.
        xyzo[1],xyzo[2],xyzo[3] = x,y,z
        -- unit.simple_remove = true
        -- RemoveOrder(id,unit,tag)
        -- Echo("CMD_UNIT_CANCEL_TARGET is ", CMD_UNIT_CANCEL_TARGET)
        spGiveOrderToUnit(id,CMD_UNIT_CANCEL_TARGET,0,0)

        spGiveOrderToUnit(id,CMD_UNIT_SET_TARGET,xyzo,0)
        return
    end
    if targetType~=2 or not isUserTarget and owner~=MY_WIDGET_CODE then
        Debug('bad command',targetType, isUserTarget, owner, MY_WIDGET_CODE,groundTarget and UnitDefs[Spring.GetUnitDefID(groundTarget)].humanName or groundTarget)
        return
    end
    -- is set to wrong target?
    local gx,gy,gz = unpack(groundTarget) --Points[1]={gx,gy,gz,color=colors.brown+0.8,size=30}
    if gx~=x or gz~=z then xyzo[1],xyzo[2],xyzo[3]=x,y,z spGiveOrderToUnit(id,CMD_UNIT_SET_TARGET,xyzo,0) Debug('set')  return end
    -- close enough of target?
    local dist3D = ((wx-x)^2 + (wy-y)^2 + (wz-z)^2)^0.5
    local projx,projy,projz = wx+dirwx*dist3D, wy+dirwy*dist3D, wz+dirwz*dist3D
    local laser_to_target = ((projx-x)^2 + (projy-y)^2 + (projz-z)^2)^0.5
    --Points[2]={projx,projy,projz,color=colors.blue+0.8,size=30}
    -- Echo("laser_to_target is ", laser_to_target, 'remaining ',unit.ncommands)
    if laser_to_target>60 then unit.nextFrame = tonumber(round(frame + laser_to_target/10)) return end
    
    if laser_to_target<17 then 
        -- if unit.ncommands==1 then
        --     -- we just let the starlight shoot at this last pos instead of removing, the user may want to keep it there
        --     Echo('stop tracing, let the last order')
        --     unitsToTrace[id]=nil
        -- else
            RemoveOrder(id,unit,tag,x,y,z) --[[spGiveOrderToUnit(id,CMD_UNIT_CANCEL_TARGET,0,0)--]]
        -- end
    end
    return 
end

local Is_GS_Strafing = function(id,unit)
    if not unit.isGS then return end
    local StrafeDesc=spGetUnitCmdDescs(id)[spFindUnitCmdDesc(id, CMD_AIR_STRAFE)]
    local isStrafing = not StrafeDesc or StrafeDesc.params[1]=='1'
    return isStrafing
end
local function CheckMoving(id,unit)
    local moving = isMoving(spGetUnitVelocity(id))
    if moving then return true end
    -- is paralyzed?
    local hp,maxhp,paraDmg = spGetUnitHealth(id)
    local paralyzed = (spGetUnitRulesParam(id, "real_para") or paraDmg)>maxhp        
    if paralyzed then return true end
    -- is turning?
    local heading = spGetUnitHeading(id)
    local isTurning = abs(heading-unit.heading)>4
    unit.heading=heading
    if isTurning then return true end
end
local function CheckRange(id,unit,weapon,weapNum,x,y,z,tag)
    local inRangeAndAngle = spGetUnitWeaponTestRange(id,weapNum,x,y,z)
    -- is in range?
    if inRangeAndAngle then return true end
    -- is it brawler with target below it?
    if unit.isBrawler and not Is_GS_Strafing(id,unit) then 
        local bx,by,bz = spGetUnitPosition(id)
        local diry = (y-by)
        local badangle = diry / ((x-bx)^2+(diry)^2+(z-bz)^2)^0.5  <  -0.90
        -- temporarily turn strafing on
        if badangle then spGiveOrderToUnit(id,CMD_AIR_STRAFE,1,0) unit.cancelstrafe=true unit.timeOut=0 return end
    end
    -- is static defense?
    if unit.isImmobile then  RemoveOrder(id,unit,tag,x,y,z,'norepeat',GetNewTarget(id,unit,weapNum,x,y,z)) return end
    -- if not the only weapon?
    if unit.multi and not unit.fullReload then --[[Debug('not in range but not full reload')--]] return end
    -- is moving?
    if CheckMoving(id,unit) then unit.timeOut=0 return  end
    unit.timeOut=unit.timeOut+1
    -- is it duck bug?
    if unit.isDuck and unit.timeOut>17 and  weapon==unit[2] and spGetUnitWeaponTestRange(id,1,x,y,z) then Debug('fix duck') RemoveOrder(id,unit,tag,x,y,z) return end

    -- is it hopeless?
    if unit.timeOut>30 then Debug('not in range trying to fix...') if not FindWay(id,unit,weapon,weapNum,x,y,z) then RemoveOrder(id,unit,tag,x,y,z,'norepeat') Debug(weapNum,'remove not in range',spGetGameFrame()) end return end
    return
end


local function CheckTimeOut(id,unit,time)
    unit.timeOut=unit.timeOut+1 --Debug("unit.timeOut is ", unit.timeOut)
    local maxwait=Is_GS_Strafing(id,unit) and 60 or time or 30
    return unit.timeOut>maxwait
end
local function CheckStiletto(id,unit,cmdID,x,y,z,tag,frame)
    if spGetUnitRulesParam(id,'att_abilityDisabled')==1 then return end
    local weapon,weapNum = unit,1
    --- ENDING -- 
    if weapon.shot_ended and weapon.pershot then 
        if cmdID==20 then RemoveOrder(id,unit,tag,x,y,z) end
        --if bufferAttacks[id] then bufferAttacks[id].release=true end
        return true
    end
    if not cmdID or not z then return end
    if spGetUnitRulesParam(id,'noammo') and spGetUnitRulesParam(id,'noammo')~=0 then
        local wx,wy,wz = spGetUnitWeaponVectors(id,weapNum)
        local dist2D = ((wx-x)^2 + (wz-z)^2)^0.5
        if dist2D>unit.longestRange then local newFrame = frame+(dist2D-unit.longestRange)/(unit.speed/30) if unit.nextFrame<newFrame then unit.nextFrame=newFrame  end return end
        return
    end
    --------
    local bx,_,bz = spGetUnitPosition(id)
    local inRange = ((x-bx)^2+(z-bz)^2)^0.5<250

    ---- Initiate Manual Fire
    if cmdID==20 and z and not unit.waitManual and weapon.reloaded and not weapon.shooting then
        InsertOrder(unit,CMD_RAW_MOVE,x,y,z)
        unit.waitManual=true
        unit.drop=false
        return true
    elseif weapon.shooting then
        -- don't care about range while disarming, keep removing orders by time elapsed
    elseif not inRange then

        local wx,wy,wz = spGetUnitWeaponVectors(id,weapNum)
        local dist2D = ((wx-x)^2 + (wz-z)^2)^0.5
        if dist2D>unit.longestRange then local newFrame = frame+(dist2D-unit.longestRange)/(unit.speed/30) if unit.nextFrame<newFrame then unit.nextFrame=newFrame  end return end
        return
    end
    ----
    if unit.waitManual and not unit.drop then
        local nextorders = spGetCommandQueue(id,3)
        local nextorder = nextorders[2]
        if not nextorder or nextorder.id~=20 then return end
        local bx,_,bz = spGetUnitPosition(id)
        -- is it very close?
        if ((x-bx)^2+(z-bz)^2)^0.5 > 200 then return end
        unit.lastFrame=frame
        unit.shooting=true -- can't detect the one click weapon (?)
        InsertOrder(unit,CMD_ONECLICK_WEAPON,1,0)
        unit.drop=true
        unit.achieved=0
        local third_order = nextorders[3]
        if cmdID==CMD_RAW_MOVE then
            spGiveOrderToUnit(id, CMD_REMOVE, tag, 0)
            if nextorder and nextorder.id==20 then RemoveOrder(id,unit,nextorder.tag,x,y,z) end
            if third_order then InsertOrder(unit,CMD_MOVE,unpack(third_order.params)) unit.achieved=1 end
        elseif cmdID==20 then
            RemoveOrder(id,unit,tag,x,y,z)
            if nextorder and nextorder.id==20 then InsertOrder(unit,CMD_MOVE,unpack(nextorder.params)) unit.achieved=1 end
        end
        return true
    end
    if unit.waitManual then
        if weapon.shooting then
            unit.waitManual=false
            unit.drop=false

        end
    end
    if weapon.shooting then 
         -- going onto next target per shot
        if weapon.pershot then
            -- removing order after some frame passed or if no current move order
            -- substitute attack orders by manual move order consecutively
            if unit.achieved>1 and spGetUnitStates(id)['repeat'] and unit.achieved>=unit.ncommands-1 then return end
            if frame-unit.lastFrame>5 then
                local nextorders = spGetCommandQueue(id,4)
                local nextorder,third_order = nextorders[2],nextorders[3]
                if cmdID==CMD_MOVE then
                    spGiveOrderToUnit(id, CMD_REMOVE, tag, 0)
                    if nextorder and nextorder.id==20 then RemoveOrder(id,unit,nextorder.tag,x,y,z) end
                    if third_order then InsertOrder(unit,CMD_MOVE,unpack(third_order.params)) unit.achieved=unit.achieved+1 end
                elseif cmdID==20 then
                    RemoveOrder(id,unit,tag,x,y,z)
                    if nextorder and nextorder.id==20 then InsertOrder(unit,CMD_MOVE,unpack(nextorder.params)) unit.achieved=unit.achieved+1 end
                end                
                unit.lastFrame=frame
                return true
            end
            return true
        -- else manual fire is removed automatically after successful first shot therefore we switch to the attack order without doing anything
        else
            RemoveOrder(id,unit,nextorder.tag,x,y,z)
            return true
        end
    end
    if weapon.reloaded then unit.timeOut=unit.timeOut+1 
        if unit.timeOut>150 then Debug('manual fire timed out') RemoveOrder(id,unit,tag,x,y,z) weapon.manualFire=true end
        return true
    end
    return true
end
local function CheckManualFire(id,unit,weapon,weapNum,cmdID,x,y,z,tag,frame)
    if not weapon.manualFire then return unit.waitManual end
    if spGetUnitRulesParam(id,'att_abilityDisabled')==1 then return end
    if cmdID==105 and not unit.waitManual and not weapon.shooting then RemoveOrder(id,unit,tag,x,y,z) end
    --- ENDING -- 
    if weapon.shot_ended then 
        unit.override=false
        if unit.isKrow then -- remove current order (move or attack) and next attack order that might under the krow
            local nextorder = spGetCommandQueue(id,2)[2]
            if nextorder then local nx,ny,nz = unpack(nextorder.params) end
            Points[#Points+1]={x,y,z,color=colors.white+0.5,size=25}
            --if nextorder then Points[#Points+1]={nx,ny,nz,color=colors.blue+0.5,size=25} end
            local bx,by,bz = spGetUnitPosition(id)
            local diry = (y-by)
            local badangle = diry / ((x-bx)^2+(diry)^2+(z-bz)^2)^0.5  <  -0.40
            if badangle then
                if cmdID==20 then RemoveOrder(id,unit,tag,x,y,z)
                else spGiveOrderToUnit(id, CMD_REMOVE, tag, 0) 
                end
--[[                if nextorder and nextorder.id==20 and nextorder.params[3] then
                    RemoveOrder(id,unit,nextorder.tag,unpack(nextorder.params))
                end--]]
            end
            --spGiveOrderToUnit(id,CMD_UNIT_SET_TARGET,0,0)
            spGiveOrderToUnit(id,CMD_UNIT_CANCEL_TARGET,0,0)
        end
        return true
    end
    --------
    local inRange = CheckRange(id,unit,weapon,weapNum,x,y,z,tag)
    ---- Initiate Manual Fire
    if (inRange or unit.manualOverride) and not unit.waitManual and weapon.reloaded and not weapon.shooting then
        InsertOrder(unit,unit.isKrow and CMD_MOVE or unit.isStiletto and CMD_RAW_MOVE or CMD_MANUALFIRE,x,y,z)
        if unit.isKrow then xyzo[1],xyzo[2],xyzo[3],xyzo[4]=x,y,z,nil spGiveOrderToUnit(id,CMD_UNIT_SET_TARGET,xyzo,0) xyzo[4]=MY_WIDGET_CODE end
        unit.waitManual=true
        unit.drop=false
        return true
    elseif not inRange then
        return
    end
    ----
    if unit.isKrow and unit.waitManual and not unit.drop then
        local bx,_,bz = spGetUnitPosition(id)
        -- is it very close?
        if ((x-bx)^2+(z-bz)^2)^0.5 > 150 then return end
        InsertOrder(unit,CMD_ONECLICK_WEAPON,1,0)
        unit.drop=true
        return true
    end
    if unit.waitManual then
        if weapon.shooting then
            unit.waitManual=false
            unit.drop=false
            if unit.isCarrier and not unit.recalled then Debug('recalling...') spGiveOrderToUnit(id,CMD_RECALL_DRONES,0,spuAndBit(CMD_OPT_SHIFT,CMD_OPT_INTERNAL)) unit.recalled=spGetGameFrame() end
        end
    end
    --Debug("#spGetCommandQueue(id,-1) is ", #spGetCommandQueue(id,-1))
    --if unit.drop and weapon.manualFire==true then Debug('finish',spGetGameFrame()) unit.drop=false end
    --Debug("manual: ", weapon.manualFire,'cmdID:',spGetUnitCurrentCommand(id),nil)

    if weapon.shooting then 
         -- going onto next target per shot
        if weapon.pershot then
            unit.override=true
            local manual_command
            if unit.isKrow then -- removing orders when approaching next move point
                local bx,_,bz = spGetUnitPosition(id)
                local maxDist = 150
                if ((x-bx)^2+(z-bz)^2)^0.5<maxDist then 
                    manual_command = CMD_MOVE
                end
            elseif weapon.shot or (weapon.subshot and weapon.salvo>0) then -- normal behaviour for manual fire
                manual_command = CMD_MANUALFIRE
            end
            -- substitute attack orders by manual fire orders consecutively (or move for krow/stiletto)
            if manual_command then
                --if third_order then Debug("third_order.id is ", third_order.id) end
                if cmdID==20 then RemoveOrder(id,unit,tag,x,y,z,param) 
                else  spGiveOrderToUnit(id, CMD_REMOVE, tag, 0)
                end
                local nextorders = spGetCommandQueue(id,3)
                local nextorder,third_order = nextorders[2],nextorders[3]
                if third_order and third_order.id==20 then -- at this point we should have a current cmd manual fire superposed to an attack order and a third order to attack a new ground target
                    if nextorder and nextorder.id==20 and nextorder.params[3] then 
                        RemoveOrder(id,unit,nextorder.tag,unpack(nextorder.params)) -- remove also the attack order in the usual way
                    end
                    InsertOrder(unit,manual_command,unpack(third_order.params)) -- insert a new manual fire command onto the third order
                    if unit.isKrow then spGiveOrderToUnit(id,CMD_UNIT_SET_TARGET,third_order.params,0) end
                end
                return true
            end
            return true
        -- else manual fire is removed automatically after successful first shot therefore we switch to the attack order without doing anything
        else
            return true
        end
    end
    if weapon.reloaded then unit.timeOut=unit.timeOut+1 
        if unit.timeOut>150 then Debug('manual fire timed out') RemoveOrder(id,unit,tag,x,y,z) weapon.manualFire=true end
        return true
    end
end

local time,lastFrame = clock(),spGetGameFrame()
local function Check (id,unit,frame,weapon)
    --Page(spGetUnitRulesParams(id))
    if not weapon then GetNewReloads(id,unit,frame) end -- update reload status and detect shot/subshot of salvo of weapon(s)
    if unit.shotAt==frame-1 then return end -- 1 frame is too short since we detect an after-shot frame (have to do it for multi weapon checks case when we don't want to register a valid shot happening at the same time from another weapon)
    -- wait to remove order?
    if unit.waitremove then return  end
    -- has multi weapons to check?
    local multi = unit.multi
    if not weapon and multi then
        for i,weapon in ipairs(unit) do Check(id,unit,frame,weapon) end
        return
    end
    if (unit.isSumo or unit.isNewton) and weapon.posneg~=spGetUnitIsActive(id) then return end -- don't check for unused wepaons of sumo/newton
    -- got valid order?
    local cmdID,coded,tag,x,y,z,owner = spGetUnitCurrentCommand(id)
    if unit.isStiletto then CheckStiletto(id,unit,cmdID,x,y,z,tag,frame) return end
    if not cmdID then
        -- this need more time when playing on server, time out: 10  for local, 50 for server
        if not bufferAttacks[id] then unit.timeOut=unit.timeOut+1 if unit.timeOut>=50 then Debug('unit got no cmd, timed out, stopping tracing ',id) unitsToTrace[id]=nil end end
        return
    end
    if unit.isStiletto then
        -- if unit.shooting then Debug('stiletto is shooting') else Debug('stiletto stop') end
    end

    if not
    (   cmdID==20 and  z
     or cmdID==105 and weapon.manualFire
     or cmdID==10 and (unit.isKrow and weapon.manualFire or unit.isStiletto and unit.manualFire)  )
    then return
    end
    --Points[1]={x,y,z,color=colors.red+1,size=15}
    -- is Starlight?
    if unit.isStarlight then CheckStarlight(id,unit,x,y,z,owner,tag,frame) return end
    if unit.isZenith then CheckZenith(id,unit,x,y,z,tag,frame) return end
    -- is Duck? switch weapon depending on environment
    if unit.isDuck then 
         -- by the way the duck is bugged, when the very top of unit is above water, the duck assume the wrong range of missile launcher instead of torpedo launcher, therefore it get stuck aiming without firing
         -- this widget is adapted to this bug but doesnt fix it
         -- it is the aim point position vs target position  vis-a-vis of waterline that is determining if the weapon gonna shoot
        weapon = select(2,GetPieceAbsolutePosition(id,spGetUnitPiecePosition(id,unit[1].aimPiece)))<0 and unit[2] or unit[1]
    end
    weapon=weapon or unit
    local weapNum = weapon.weapNum
    -- is it rearming?
    if unit.isBomber and not weapon.shooting  then
        local wx,wy,wz = spGetUnitWeaponVectors(id,weapNum)
        local dist2D = ((wx-x)^2 + (wz-z)^2)^0.5
        if dist2D>unit.longestRange*3 then local newFrame = frame+(dist2D-unit.longestRange*3)/(unit.speed/30) if unit.nextFrame<newFrame then unit.nextFrame=newFrame  end return end
        if not weapon.reloaded then return end
    end 
    -- is the weapon manual fire?
    if CheckManualFire(id,unit,weapon,weapNum,cmdID,x,y,z,tag,frame) then return end
    --if true then return end
    -- stiletto is fully handled in CheckManualFire
    -- is it travelling?
    if not unit.isImmobile then
        local state = (unit.isGS or unit.isPlane) and spGetUnitMoveTypeData(id).flyState or  spGetUnitMoveTypeData(id).progressState
        -- if state=='failed' then Debug('path failed') RemoveOrder(id,unit,tag,x,y,z,'norepeat',GetNewTarget(id,unit,weapon.weapNum,x,y,z)) return end
        if not (state=='done' or state=='attacking') then
            -- getting a new next frame
            local wx,wy,wz = spGetUnitWeaponVectors(id,weapNum)
            local dist3D = ((wx-x)^2 + (wy-y)^2 + (wz-z)^2)^0.5
            if dist3D>unit.longestRange*1.3 then local newFrame = frame+(dist3D-unit.longestRange*1.3)/(unit.speed/30) if unit.nextFrame<newFrame then unit.nextFrame=newFrame  end end
            return
        end
    end
    -- is it Outlaw? very simple check for him
    if unit.isOutlaw then CheckOutlaw(id,unit,weapon,x,y,z,tag) end
    -- is it in range?
    if not CheckRange(id,unit,weapon,weapNum,x,y,z,tag) then return end
    --is it claymore? have to switch weapon depends on target
    local fixweapTgt = unit.isClaymore and y>0 and 2 -- weap1 is relevant for reload in any case, weap 2 is to get ground target when aiming on ground -- claymore range is bugged as duck's -- 
    local targetType,isUserTarget,groundTarget = spGetUnitWeaponTarget(id,fixweapTgt or weapNum)
    -- have we got a ground target?
    local WeapHasGroundTarget = targetType==2
    if WeapHasGroundTarget then  
        --Points[2]={x,y,z,color=colors.brown+0.8,size=30}
        if not isUserTarget and owner~=MY_WIDGET_CODE then Debug('wrong',cmdID,weapon.manualFire)--[[Points[2]={x,y,z,color=colors.white+0.8,size=30}--]] return end
    end
    -- VALIDATING SHOT --
    local validShot
    -- are drone beeing recalled?
    if unit.isCarrier and unit.recalled and frame-unit.recalled < 50 then return else unit.recalled=false end
    --if unit.isStiletto and weapon.manualFire=='fired' then return end
    if unit.nowait then 
        validShot=weapon.shot
    elseif unit.pershot or weapon.pershot then
        validShot = weapon.shot or weapon.subshot
    else
        validShot=weapon.shot
        if unit.isNapalm then
            local nextorder = spGetCommandQueue(id,2)[2]
            if nextorder and nextorder.id==20 then InsertOrder(unit,CMD_MOVE,unpack(nextorder.params)) end
        end
        --validShot = weapon.shot_ended
    end
    if unit.name=='vehcapture' then validShot=CheckTimeOut(id,unit) end
    if  validShot then 
        --Debug('shot at '..frame..' ('..weapon.reloadFrame..')',weapNum,'=>',x,y,z)
        --Debug('shot with '..weapon.wname)
        unit.shotAt = frame
        RemoveOrder(id,unit,tag,x,y,z)
        return
    end
    ------- we don't go further if the shot has been accomplished
    if not CheckRange(id,unit,weapon,weapNum,x,y,z,tag) then return end
    if not weapon.reloaded or multi and not unit.fullReload then return end

    local LoF = spGetUnitWeaponHaveFreeLineOfFire(id,weapNum,nil,nil,nil,x,y,z)
    local wLoF
    --if not LoF then Debug('no LoF, canFire?',spGetUnitWeaponCanFire(id,weapNum))  end
    if LoF then --TODO: NEED A CLEAN UP FROM THERE
        local wx,wy,wz,dirwx,dirwy,dirwz = spGetUnitWeaponVectors(id,weapNum)
        wLoF = spGetUnitWeaponHaveFreeLineOfFire(id,weapNum,wx,wy,wz,x,y,z)
        if not wLoF then
            local aiming =CheckAiming(id,unit,weapon,wx,wy,wz,dirwx,dirwy,dirwz)
            if aiming then Debug('['..weapNum..']:no wLof but aiming') unit.timeOut=0 return end
            if CheckTimeOut(id,unit) then Debug('no wLoF, removed') RemoveOrder(id,unit,tag,x,y,z,'norepeat',GetNewTarget(id,unit,weapNum,x,y,z)) return end
        elseif weapon.reloaded then
            --got LoF and wLoF
            local aiming,_,aimy = CheckAiming(id,unit,weapon)
            if aiming then --[[Debug('['..weapNum..']:lof and wlof and reloaded but aiming')--]] unit.timeOut=0 return end
            --local aimy = GetPieceAbsolutePosition(id,spGetUnitPiecePosition(id,weapon.aimPiece))

            if aimy<0 and not weapon.wwaterWeapon and unit.timeOut>30 then RemoveOrder(id,unit,tag,x,y,z,'norepeat') Debug('impossible, weapon cant shoot under water') end 
            if unit.isDuck and aimy<0 and y>0 and unit.timeOut>30 then RemoveOrder(id,unit,tag,x,y,z) Debug('impossible, aimpoint underwater with target above water') end
            if unit.isTremor then return end
            if CheckTimeOut(id,unit,60) then 
                Debug('reloaded, got lof and wlof but dont fire,canFire?',spGetUnitWeaponCanFire(id,weapNum),CheckAiming(id,unit,weapon,wx,wy,wz,dirwx,dirwy,dirwz))
                if not FindWay(id,unit,weapon,weapNum,x,y,z) then RemoveOrder(id,unit,tag,x,y,z,'norepeat',GetNewTarget(id,unit,weapNum,x,y,z)) end
                return
            end
        end
    else
        if CheckMoving(id,unit) then Debug('no lof but moving') unit.timeOut=0 return end
        local aiming,_,aimy = CheckAiming(id,unit,weapon)
        if aiming then Debug('['..weapNum..']:no lof but aiming') unit.timeOut=0 return end
        if aimy<0 and y>0 and timeOut>30 then Debug('impossible, aimpoint underwater with target above water') RemoveOrder(id,unit,tag,x,y,z) end
        if CheckTimeOut(id,unit) then Debug('no lof... trying to fix') if not FindWay(id,unit,weapon,weapNum,x,y,z) then RemoveOrder(id,unit,tag,x,y,z,'norepeat',GetNewTarget(id,unit,weapNum,x,y,z)) end return end
        return
    end

    local canFire,noAngle,noTargetType, noReqDir = spGetUnitWeaponCanFire(id,weapNum), spGetUnitWeaponCanFire(id,weapNum,true),spGetUnitWeaponCanFire(id,weapNum,false,true),spGetUnitWeaponCanFire(id,weapNum,false,false,true)
    if weapon.reloaded and LoF and wLoF and not canFire then 
        if multi and not unit.fullReload then return end
        if spGetUnitRulesParam(id, "disarmed")==1 then return end
        if CheckTimeOut(id,unit) then 
            local aiming,_,aimy = CheckAiming(id,unit,weapon)
            if aiming then Debug('['..weapNum..']:all good but cannot fire, but aiming') unit.timeOut=0 return end
            Debug('all good but cant fire',weapNum)
            if unit.isDuck and aimy<0 and y>0 then Debug('['..weapNum..']:impossible, aimpoint underwater with target above water') end

            RemoveOrder(id,unit,tag,x,y,z,'norepeat',GetNewTarget(id,unit,weapNum,x,y,z))
            return 
        end
    end
end


----------------------DEBUGGING------------------------
-------------------------------------------------------
-------------------------------------------------------
-------------------------------------------------------
-------------------------------------------------------
-------------------------------------------------------
-- StandAlone Evaluate path function
local EvaluatePath
do
    local spGetUnitEstimatedPath = Spring.GetUnitEstimatedPath
    local spGetUnitCurrentCommand = Spring.GetUnitCurrentCommand
    local spGetGroundHeight = Spring.GetGroundHeight
    local spGetUnitDefID = Spring.GetUnitDefID
    local spGetUnitPosition = Spring.GetUnitPosition
    local UnitDefs = UnitDefs
    EvaluatePath = function (id)
        local cmd,_,_,gx,gy,gz = spGetUnitCurrentCommand(id)
        if cmd~=CMD_MOVE and cmd~=CMD_RAW_MOVE and cmd~=CMD_RAW_BUILD then return end -- note: CMD_RAW_BUILD 3110 is automatic move command when build is ordered, if build is too far
        local t1,t2 = spGetUnitEstimatedPath(id)
        --local dat=spGetUnitMoveTypeData(id)
        -- breakdown:
            -- not calculated yet or straight line => t1=nil, t2=nil
            -- t[1]={{path_point1},{path_point2}, ...}
            -- t2[1]=1, t2[2] = number of points of the refined path, t2[3] = total number of path points
        --
        local defID=spGetUnitDefID(id)
        --local prevx,prevy,prevz=spGetUnitPosition(id)
        local bx,by,bz = spGetUnitPosition(id)
        local unitSpeed = UnitDefs[spGetUnitDefID(id)].speed
        --
        local straightDist = ((gx-bx)^2+(gy-by)^2+(gz-bz)^2)^0.5
        local straightTime = straightDist/unitSpeed
        --
        local prevx,prevy,prevz = bx,by,bz 
        local nextx,nexty,nextz
        local pathDist,pathTime,diffTime,ratioDiff=0,0,0,1
        if t1 then
            for i,movepoint in ipairs(t1) do
                nextx,nexty,nextz = unpack(movepoint)
                pathDist = pathDist + ((nextx-prevx)^2+(nexty-prevy)^2+(nextz-prevz)^2)^0.5
                prevx,prevy,prevz=nextx,nexty,nextz
            end
            pathTime = pathDist/unitSpeed
            diffTime = pathTime-straightTime
            ratioDiff = pathDist/straightDiff
        end
        return ratioDiff, diffTime
    end
end


-- HOW TO PREDICT PATHABILITY

-- if 



local draw, draw2 = {}, {}
local IsTargetReachable
local function AnalayseLastSegment(defID, wps, n,  deep, dwps, moveID, radius)
    local n3 = dwps and #dwps
    deep = ', DEEP: '..' #'.. tostring(n3) ..', '..tostring(deep)
    -- for i=1, n3 do
    --     local p = dwps[i]
    --     Points[#Points+1] = {p[1], p[2], p[3], color = colors.purple+1 ,size=14}
    -- end
    local extra = ''
    local reachable

    if n3 then
        if n3>1 then -- never happening
            -- Echo('DEEP HAS MULTI SEGMENTS !')
        end
        -- draw[n] = nil
        local j = n-1
        local junction = wps[j]
        for i = 1, n3 do
            wps[i+j] = dwps[i]
        end

        local color=colors.blue+1
        -- Points[#Points+1] = {junction[1], junction[2], junction[3], color = colors.purple+1 ,size=14}
        if n3 == 2 then 

            local lastpoint = dwps[n3]
            local dirx,diry,dirz = lastpoint[1]-junction[1], lastpoint[2]-junction[2], lastpoint[3]-junction[3]
            local dist = (dirx^2 + dirz^2) ^0.5
            deep = deep .. ' d:' .. ('%d'):format(dist)
            dirx,diry,dirz=dirx/dist, diry/dist, dirz/dist
            local offset = 0
            for i=1, 50 do
                -- test move order would return false if we don't have LoS of the ground
                -- local moveTest = Spring.TestMoveOrder(defID, junction[1] + dirx*offset, junction[2] + diry*offset, junction[3] + dirz*offset, dirx,diry,dirz, true, true, true)
                offset = offset + 8
                local color = color
                local jx, jy, jz = junction[1] + dirx*offset, junction[2] + diry*offset, junction[3] + dirz*offset
                local placeable, feature = Spring.TestBuildOrder(defID,jx, jy, jz, 1)
                -- if not moveTest then
                if placeable==0   then
                    if reachable then
                        color = colors.yellow+1
                    else
                        if reachable == nil and i > 2  then
                            -- if we find an unpathable point after the second, we request a path with the point before
                            local res,_,ewps = IsTargetReachable(moveID, jx - dirx*8, jy - diry*8, jz - dirz*8, lastpoint[1], lastpoint[2], lastpoint[3], radius, defID, true )
                            
                            -- Points[#Points+1] = {jx - dirx*8, jy - diry*8, jz - dirz*8, color = colors.purple+1 ,size=14}
                            deep = deep .. 'extra test:'..tostring(res) ..', #'.. (ewps and #ewps)
                            if ewps and ewps[2] then
                                -- Points = {}
                                local dwLen = #wps - 1
                                for i = 1, #ewps do
                                    wps[i+dwLen] = ewps[i]
                                    -- draw[i+dwLen] = wps[i]
                                    -- draw[i] = wps[i]
                                    -- Echo("wps[i][1], wps[i][2], wps[i][3] is ", wps[i][1], wps[i][2], wps[i][3])
                                    -- Points[#Points+1] = {ewps[i][1], ewps[i][2], ewps[i][3], color = colors.orange+1 ,size=14}
                                end
                                reachable = true
                                break
                            end

                        end
                        reachable = false
                        color = colors.red+1
                    end
                elseif reachable==nil and dist - offset <= radius then
                    extra = ' lastSeg:' .. dist - offset
                    reachable = true
                end

                -- Points[#Points+1] = {junction[1] + dirx*offset, junction[2] + diry*offset, junction[3] + dirz*offset, color = color ,size=14}

                if offset+8 > dist then

                    break
                end
            end
        end

        deep = deep .. ', Reachable:' .. tostring(reachable):upper() .. extra
    end
    return deep, reachable
end


IsTargetReachable = function(moveID, ox,oy,oz,tx,ty,tz,radius,defID, nodeep)
    local result,lastcoordinate, waypoints
    local path = Spring.RequestPath( moveID,ox,oy,oz,tx,ty,tz, radius)
    local deep, dwps, reachable
    draw = {}
    if path then
        waypoints = path:GetPathWayPoints() --get crude waypoint (low chance to hit a 10x10 box). NOTE; if waypoint don't hit the 'dot' is make reachable build queue look like really far away to the GetWorkFor() function.
        draw = waypoints or draw
        local len = #waypoints
        lastcoordinate = waypoints[len]

        if lastcoordinate then --unknown why sometimes NIL
            local dx, dz = lastcoordinate[1]-tx, lastcoordinate[3]-tz
            local dist = math.sqrt(dx*dx + dz*dz)
            if dist <= radius+20 then ---- if last waypoint is the goal and path contains more than one waypoint, it's has good probability to be actually unreachable
                result = "reach:" .. (dist==0 and dist or ('%.2f'):format(dist))
                reachable = true
                if not nodeep and len>1 and dist == 0 then
                    
                    local ldx, ldz = waypoints[len-1][1] - tx, waypoints[len-1][3] - tz
                    local lastSegDist = math.sqrt(ldx*ldx + ldz*ldz)
                    result = result .. ',lastSeg:'..lastSegDist
                    local _
                    deep, _, dwps = IsTargetReachable (moveID, waypoints[len-1][1], waypoints[len-1][2], waypoints[len-1][3],tx,ty,tz,radius,defID, true)
                    -- deep, _, dwps = IsTargetReachable (moveID, lastcoordinate[1],lastcoordinate[2],lastcoordinate[3],tx,ty,tz,radius,defID, true)

                    if defID and deep and dwps then
                        deep, reachable = AnalayseLastSegment(defID, waypoints, len,  deep, dwps, moveID, radius)
                    else
                        deep = ''
                    end

                end
            else
                result = "outofreach:" .. ('%.2f'):format(dist)
                reachable = false
                if lastcoordinate[1] == ox and lastcoordinate[3] == oz then
                    result = result .. '-NO MOVE'
                    -- the waypoint is neither the base unit pos nor the mid unit pos but in between
                    -- Echo("orig" ..','..ox..','..oy..','..oz..','..'final coord'..','..lastcoordinate[1]..','..lastcoordinate[2]..','..lastcoordinate[3])
                end
            end
        end
    else
        result = "noreturn"
    end
    return result, lastcoordinate, waypoints, deep, dwps, reachable
end
local drawfunc = function(t)
    for i, point in ipairs(t) do
        if t[i+1] then
            gl.Vertex(unpack(t[i]))
            gl.Vertex(unpack(t[i+1]))
        end
    end
end
for k,v in pairs(Spring) do
    if k:lower():find('test') then
        Echo(k,v)
    end
end

local function AnalyzeSeg(defID, pStart, pEnd, radius)
    local sx, sy, sz = pStart[1], pStart[2], pStart[3]
    local dirx,diry,dirz = pEnd[1]-sx, pEnd[2]-sy, pEnd[3]-sz
    local dist = (dirx^2 + dirz^2) ^0.5
    dirx,diry,dirz = dirx/dist,diry/dist,dirz/dist
    local reachable, newpt
    local comment = ''
    local offset = 0
    local color = colors.blue+1
    for i=1, 50 do
        -- local moveTest = Spring.TestMoveOrder(defID, junction[1] + dirx*offset, junction[2] + diry*offset, junction[3] + dirz*offset, dirx,diry,dirz, true, true, true)
        -- test move order would return false if we don't have LoS of the ground
        offset = offset + 8
        local color = color
        local jx, jy, jz = sx + dirx*offset, sy + diry*offset, sz + dirz*offset
        local placeable, feature = Spring.TestBuildOrder(defID,jx, jy, jz, 1)
        -- if not moveTest then
        if placeable==0   then -- not placeable
            if reachable then -- previous point already good, we continue just for debugging
                color = colors.yellow+1
            else
                if reachable == nil and i > 2  then
                    -- the last previous point was pathable, we remember it
                    newpt = {jx-dirx*8, jy-diry*8, jz-dirz*8}
                end
                reachable = false
                color = colors.red+1
            end
        elseif reachable==nil and dist - offset <= radius then
            comment = ' d:' .. dist - offset
            reachable = true
        end
        -- Echo("jx, jy, jz is ", jx, jy, jz,'placeable?',reachable,offset,'color?',color)
        Points[#Points+1] = {jx, jy, jz, color = color ,size=14}

        if offset+8 > dist then
            break
        end
    end
    return reachable, newpt, comment
end

local function CheckDeepPath(moveID, defID, pStart,pEnd,radius, maxDeeplevel, deeplevel, result, wps, comment, analyze)
    maxDeepLevel = maxDeepLevel or 3
    deeplevel = deeplevel or 0

    comment = (comment and comment .. ', ' or '') .. '(' .. deeplevel .. ')'
    if deeplevel == maxDeepLevel then
        comment = (comment and comment .. ', ' or '') .. 'max deep level'
        return result, wps, comment
    end
    Points[#Points+1] = {pStart[1], pStart[2], pStart[3],color = colors.purple+1 ,size=14}
    local path = Spring.RequestPath( moveID, pStart[1] ,pStart[2] ,pStart[3] ,pEnd[1] ,pEnd[2] ,pEnd[3] ,radius)
    if not path then
        comment = (comment and comment .. ', ' or '') .. 'path is nil'
        Echo(comment)
        return result, wps, comment
    end
    local news = path:GetPathWayPoints()
    if not news and news[1] then
        comment = (comment and comment .. ', ' or '') .. 'no waypoints'
        return result, wps, comment
    end
    local newlen = #news
    -- if wps we append the new path to it, removing the last point

    local last = news[newlen]
    local dist = math.sqrt((last[1]-pEnd[1])^2 + (last[3]-pEnd[3])^2)
    if newlen == 2 then
        if pStart[1] == news[1][1] and pStart[3] == news[1][3] then
            comment = (comment and comment .. ', ' or '') .. 'first new pt removed'
            table.remove(news,1)
            newlen = 1
        end
    end
    local wplen
    if not wps then
        wps = news
        wplen = newlen
    else
        wplen = #wps
        if wps[wplen][1] == news[newlen][1] and wps[wplen][3] == news[newlen][3] then
            -- case reqpath gave same last wp as we had already in our registered path
            wps[wplen] = nil
            wplen =  wplen - 1
            comment = (comment and comment .. ', ' or '') .. 'remove last identical'
        end
        -- if news[newlen-1] and wps[wplen][1] == news[newlen-1][1] and wps[wplen][3] == news[newlen-1][3] then
        --     -- case reqpath gave the same first point as the last in our registered path
        --     wps[wplen] = nil
        --     wplen =  wplen - 1
        --     comment = (comment and comment .. ', ' or '') .. 'remove first identical'
        -- end
        -- if wps[wplen-1] and wps[wplen-1][1] == news[newlen][1] and wps[wplen-1][3] == news[newlen][3] then
        --     -- case most likely req path gave only one wp which is the same as the one before last wp of our registered path
        --     table.remove(wps, wplen-1)
        --     wplen =  wplen - 1
        --     comment = (comment and comment .. ', ' or '') .. 'remove unique first identical'
        -- end

        comment = (comment and comment .. ', ' or '') .. 'append ' .. newlen

        for i=1, newlen do
            wplen = wplen + 1
            wps[wplen] = news[i]
        end
    end
    comment = (comment and comment .. ', ' or '') .. 'd:' .. dist ..' #' .. newlen
    if dist == 0 and newlen > 1 then
        -- reporting a dist of 0 is often wrong, we look at the point before, to evaluate that last segment
        -- we request again the path for that last segment, if more waypoint are found, we go deeper
        -- if same waypoint are found, this time we analyze the pathability of that last segment, square per square
        pStart = news[newlen-1]
        local lastSegDist = math.sqrt((last[1]-pStart[1])^2 + (last[3]-pStart[3])^2)
        comment = (comment and comment .. ', ' or '') .. 'lastSegDist:' .. lastSegDist
        if lastSegDist <= radius then
            comment = (comment and comment .. ', ' or '') .. 'REACHABLE ALREADY !' -- should never happen, last seg should be greater than radius
            result = true
            return result, wps, comment
        end
        local analyze = true
        deeplevel = deeplevel + 1
        comment = (comment and comment .. ', ' or '') .. 'remove last pt of path'
        wps[wplen] = nil
        return CheckDeepPath(moveID, defID, pStart,pEnd,radius, maxDeeplevel, deeplevel, result, wps, comment, analyze)
    end
    if dist <= radius then
        if dist == 0 and analyze then

            local reachable, newpt, _comment = AnalyzeSeg(defID, news[newlen-1] or pStart, news[newlen], radius)
            if reachable then
                comment = (comment and comment .. ', ' or '') .. 'seg analyze success ' .. _comment
                result = true
            elseif newpt  then
                deeplevel = deeplevel + 1
                comment = (comment and comment .. ', ' or '') .. 'new pt to start from ' .. _comment
                comment = (comment and comment .. ', ' or '') .. 'remove last pt of path'
                wps[wplen] = nil
                pStart = newpt
                return CheckDeepPath(moveID, defID, pStart,pEnd,radius, maxDeeplevel, deeplevel, result, wps, comment, analyze)
            end
        else
            result = true
        end
    else
        comment = (comment and comment .. ', ' or '') .. 'OUT OF REACH'
    end
    if result then
        comment = (comment and comment .. ', ' or '') .. 'REACHABLE'
    end
    return result, wps, comment

end


local function ShowPath(id) ---------------------------
    local debug = true
    local cmd,_,_,gx,gy,gz = spGetUnitCurrentCommand(id)
    draw, draw2 = {}, {}

    -- local x,y,z,bx,by,bz,cx,cy,cz = Spring.GetUnitPosition(id,true,true) -- seems like we would need the base pos finally
    -- Points[#Points+1]={x,y,z,color=colors.blue+1,size=25}
    -- Points[#Points+1]={bx,by,bz,color=colors.red+1,size=25}
    -- Points[#Points+1]={cx,cy,cz,color=colors.green+1,size=25}
    if cmd~=CMD_MOVE and cmd~=CMD_RAW_MOVE and cmd~=CMD_RAW_BUILD then return end -- note: CMD_RAW_BUILD 31110 is automatic move command when build is ordered, if build is too far
    local t1,t2 = Spring.GetUnitEstimatedPath(id)
    -- for k,v in pairs(t1)
    local dat=spGetUnitMoveTypeData(id)
    -- f.Page(dat)
    local Echo = debug and Echo or function() end
    -- breakdown:
        -- not calculated yet or straight line => t1=nil, t2=nil
        -- t[1]={{path_point1},{path_point2}, ...}
        -- t2[1]=1, t2[2] = number of points of the refined path, t2[3] = total number of path points
    --
    local defID=spGetUnitDefID(id)
    --local prevx,prevy,prevz=spGetUnitPosition(id)
    local unitPosX, unitPosY, unitPosZ, uMidX, uMidY, uMidZ = spGetUnitPosition(id,true)
    local prevx,prevy,prevz = unitPosX, unitPosY, unitPosZ
    local nextx,nexty,nextz
    -- local heightDiff = uMidY-spGetGroundHeight(unitPosX, unitPosZ) -- height of the unit middle pos above the ground
    local spTestBuildOrder = Spring.TestBuildOrder
    local unitSpeed = UnitDefs[spGetUnitDefID(id)].speed
    local moveID = UnitDefs[defID].moveDef.id

    local function check()
        Points[#Points+1]={nextx,nexty,nextz,color=colors.white+0.3,size=15}
        local basedirx,basediry,basedirz = nextx-prevx,nexty-prevy,nextz-prevz
        local dist = (basedirx^2+basediry^2+basedirz^2)^0.5
        local dirx,diry,dirz=basedirx/dist, basediry/dist, basedirz/dist
        if dist>32 then
            local nx,nz = prevx+dirx*32,prevz+dirz*32
            -- local ny = spGetGroundHeight(nx,nz)+diry*32
            local ny = prevy+diry*32
            Lines[#Lines+1]={prevx, prevy, prevz,nx,ny,nz,color=colors.yellow+1}
            -- local place, feature = Spring.TestBuildOrder(defID,nx,ny,nz, 1)
            -- -- local movetest = Spring.TestMoveOrder(defID, nx, ny, nz,  0, 0, 0, true, true, false)
            -- local movetest = Spring.TestMoveOrder(defID, prevx,prevy,prevz, dirx, diry, dirz, true, true, false)
            Points[#Points+1]={nx,ny,nz,color=colors.green+1,size=25}
            -- local pt = Points[#Points]
            -- if place==0 then pt.color=colors.yellow+1 end
            -- if not movetest then pt.color=(place==0 and (colors.orange+1) or (colors.red+1)) end
        end
        return dist
    end
    local pathDist = 0
    local margin = 64
    -- local ret, _, reqpathwps = IsTargetReachable (moveID, unitPosX, unitPosY, unitPosZ, gx,gy,gz, margin)
    -- if reqpathwps and reqpathwps[2] then
    --     local j = #reqpathwps-1
    --     local lastSeg = reqpathwps[#reqpathwps-1]
    --     local segDetail
    --     ret, _, segDetail = IsTargetReachable (moveID, lastSeg[1], lastSeg[2], lastSeg[3], gx,gy,gz, margin)
    --     if segDetail then
    --         for i = 1, #segDetail do
    --             reqpathwps[j + i] = segDetail[1]
    --         end
    --     end
    -- end
    -- draw2 = reqpathwps or {}


    if t1 then
        for i,movepoint in ipairs(t1) do
            nextx,nexty,nextz = unpack(movepoint)
            if i==1 then
                prevy = nexty
            end
            if nextx then
                local dist = check()
                pathDist = pathDist + dist
            end
            --Points[#Points+1]={movepoint[1],movepoint[2],movepoint[3],color=colors.green+0.3,size=25}
            prevx,prevy,prevz=nextx,nexty,nextz
        end
        local estLen = #t1
        local last = t1[estLen]
        local prevLast = t1[estLen-1]
        local isPrevUnitPos

        if not prevLast then
            prevLast = {unitPosX, unitPosY, unitPosZ}
            isPrevUnitPos = true
        end
        if last then
            local estiDist = math.sqrt((gx -last[1])^2 + (gz -last[3])^2)
            local estiPrevDist = math.sqrt((gx -prevLast[1])^2 + (gz -prevLast[3])^2)
            local reach, _, wps, deep, dwps, reachable = IsTargetReachable (moveID, prevLast[1],prevLast[2],prevLast[3], last[1], last[2], last[3],margin,defID)
            local n, reach = tostring(wps and #wps), tostring(reach)

            if not isPrevUnitPos then
                -- for debugging show the full basic reqpath starting from the unit pos
                local path = Spring.RequestPath( moveID,unitPosX, unitPosY, unitPosZ,gx,gy,gz, margin)
                draw2 = path and path:GetPathWayPoints() or {}
            end

            draw = wps or {}

            deep = deep or ''
            do
                local reachable, wps, comment = CheckDeepPath(moveID, defID, prevLast,{last[1], last[2], last[3]},margin)
                Echo(
                    --estLen .. ' estimated points, esti->goal:'..('%d'):format(estiDist) .. ' lastSeg: ' ..('%d'):format(estiPrevDist),
                    estLen .. " estimated pts ", comment,'wps',wps and #wps
                )
                if wps then
                    draw = wps
                end
                for i=1, #wps do
                    Echo(i,unpack(wps[i]))
                end
                -- Echo("#wps is ", #wps)
                -- Echo('reachable:' .. tostring(reachable):upper(), comment)
            end

            -- Echo(
            --     '['..math.round(os.clock())..']',estLen .. ' estimated points, esti->goal:'..('%d'):format(estiDist) .. ' lastSeg: ' ..('%d'):format(estiPrevDist),
            --     'reqpath ' .. (isPrevUnitPos and 'unitpos' or 'prevLast') .. '->last' .. ': #' .. n ..', '.. reach .. deep,
            --     'reachable:' .. tostring(reachable):upper()
            --     -- ,'unit->' .. (isLastGoal and 'goal' or 'last') .. ', ' .. n2 ..', '.. reach2
            -- )

        else            
            local reach, _, wps, deep, dwps = IsTargetReachable (moveID, unitPosX, unitPosY, unitPosZ, gx, gy, gz,margin,defID)
            local n, reach = tostring(wps and #wps), tostring(reach)
            local extra = ''

            -- local reach2, _, wps2 = IsTargetReachable (moveID, uMidX, uMidY, uMidZ, gx, gy, gz, margin,defID)
            -- local n2, reach2 = tostring(wps2 and #wps2), tostring(reach2)
            -- if reach2 and reach~=reach2 then
            --     if not reach:match('^(.-):%d') or reach:match('^(.-):%d') ~= reach2:match('^(.-):%d') then

            --         extra = ', DIFFERENT RES WITH UNIT MID POS ! =>> unit midpos->goal, ' .. n2 ..', '.. reach2
            --     end
            -- end
            draw = wps or {}
            deep = deep or ''

            Echo(
                '['..math.round(os.clock())..']','estimated path is empty',
                'reqpath unitpos->goal, ' .. n ..', '.. reach .. deep .. extra
            )

        end            
    else

        local reach, _, wps, deep, dwps = IsTargetReachable (moveID, unitPosX, unitPosY, unitPosZ, gx, gy, gz, margin,defID)
        local n, reach = tostring(wps and #wps), tostring(reach)
        local extra = ''

        draw = wps or {}

        deep = deep or ''

        do
            local reachable, wps, comment = CheckDeepPath(moveID, defID, {unitPosX, unitPosY, unitPosZ}, {gx, gy, gz},margin)
            Echo(
                --estLen .. ' estimated points, esti->goal:'..('%d'):format(estiDist) .. ' lastSeg: ' ..('%d'):format(estiPrevDist),
                "no estim", comment,'wps',wps and #wps
            )
            if wps then
                draw = wps
            end
            -- Echo("#wps is ", #wps)
            -- Echo('reachable:' .. tostring(reachable):upper(), comment)
        end
   
        -- Echo(
        --     '['..math.round(os.clock())..'] no estimated path',
        --     ' unit pos->goal, ' .. n ..', '.. reach .. deep .. extra
        -- )
    end
    nextx,nexty,nextz = gx,gy,gz
    if nextx then check() end
    local pathTime,straightDist,straightTime,diffTime,ratioDiff=0,0,0,0,0
    if pathDist>0 then
        pathTime = pathDist/unitSpeed
        local dirx,diry,dirz = gx-unitPosX,gy-unitPosY,gz-unitPosZ
        
        straightDist = (dirx^2+diry^2+dirz^2)^0.5
        straightTime=straightDist/unitSpeed
        diffTime = pathTime-straightTime
    end
    return straightDist, pathDist
end

local function AimWithMouse(id,unit,weapon,weapNum) -- FOR DEBUGGING -- select an attacking unit push M to activate push J to order -- target is assigned on mouse position
    --ShowPath(id)
    --CheckZone(id,unit)
    weapon=weapon or unit
    local mx,my = spGetMouseState()
    local   _, pos = spTraceScreenRay(mx, my, true, false, false, false)
    local x,y,z = spGetUnitPosition(id)
    local aimx,aimy,aimz, LoF,aimLoF,wLoF,altLoF
    local alt_aimx,alt_aimy,alt_aimz
    local defID=unit.defID

    --weapNum=1
    if weapon.aimPiece then
        aimx,aimy,aimz = GetPieceAbsolutePosition(id,spGetUnitPiecePosition(id,weapon.aimPiece))
    else
        aimx,aimy,aimz = select(4,spGetUnitPosition(id,true))
    end
    alt_aimx,alt_aimy,alt_aimz = select(4,spGetUnitPosition(id,true))
    
    if pos then
        mousx,mousy,mousz = unpack(pos)
        aimLoF = spGetUnitWeaponHaveFreeLineOfFire(id,weapNum,aimx,aimy,aimz,mousx,mousy,mousz)
        LoF = spGetUnitWeaponHaveFreeLineOfFire(id,weapNum,nil,nil,nil,mousx,mousy,mousz)
        altLoF = spGetUnitWeaponHaveFreeLineOfFire(id,weapNum,alt_aimx,alt_aimy,alt_aimz,mousx,mousy,mousz)
        local wx,wy,wz = spGetUnitWeaponVectors(id,weapNum)
        wLoF = spGetUnitWeaponHaveFreeLineOfFire(id,weapNum,wx,wy,wz,mousx,mousy,mousz)
        local inRange = spGetUnitWeaponTestRange(id,weapNum,mousx,mousy,mousz)

--[[        
        Points[#Points+1]={mousx,mousy,mousz              ,color=colors.yellow+1 ,size=18}
        Points[#Points+1]={alt_aimx,alt_aimy,alt_aimz              ,color=colors.blue+0.5 ,size=10}
        Lines[#Lines+1] ={alt_aimx,alt_aimy,alt_aimz, mousx,mousy,mousz     ,color=colors.green+1          }
        
        
        Lines[#Lines+1]={x,y,z,mousx,mousy,mousz,color=colors.white+1}--]]
        Lines={} Points={}
        --Lines[#Lines+1] ={aimx,aimy,aimz ,mousx,mousy,mousz     ,color=colors.blue+1          }
        --Lines[#Lines+1] ={wx,wy,wz ,mousx,mousy,mousz     ,color=colors.red+1, size=3}
        if debugging then
            Points[#Points+1]={x,y,z,color=colors.yellow+1 ,size=14}
        end

        local canFireNoAngle = spGetUnitWeaponCanFire(id,weapNum,true)
        --Debug("["..weapNum.."]:Mouse: aimLoF,LoF,wLoF"..g, aimLoF,LoF,wLoF)
        --Debug("["..weapNum.."]:Mouse: aimLoF,LoF,wLoF,altLoF,inRange,canFireNoAngle\n"..g.."", aimLoF,LoF,wLoF,altLoF,inRange,canFireNoAngle)
        --local place, feature = Spring.TestBuildOrder(defID, mousx, 0, mousz, 1)
        --local movetest = Spring.TestMoveOrder(defID, mousx, mousy, mousz,  0, 0, 0, true, true, false)

        local pressed = Spring.GetKeyState(106) -- push J to test attack and move
        FindWay(id,unit,weapon,weapNum,mousx,mousy,mousz,'debugging',pressed)
        if unit.ordered and not pressed then unit.ordered=false end

        --Debug("place,feature is ", place,feature,movetest,(place==0 and not movetest or place>0 and movetest) and 'same' or 'NOT SAME')
        


    end 

    return mousx,mousy,mousz,aimLoF,LoF
end


function widget:Update(dt)
    -- debugging with AimWithMouse
    if oneAttacker then
        local id = oneAttacker
        -- Echo("spGetUnitMoveTypeData(id).progressState is ", spGetUnitMoveTypeData(id).progressState)
        if debugTravel then Points={} Lines={} ShowPath(id)--[[Debug(ShowPath(id))--]] end
        --Points={} Lines={}
        if mouseTest and oneAttacker then 
            if not mouseUnit or mouseUnit.id~=oneAttacker then mouseUnit = DefineUnit(oneAttacker,spGetUnitDefID(oneAttacker)) mouseUnit.id=oneAttacker end
            local unit = mouseUnit
            if not unit[1] then AimWithMouse(oneAttacker,unit,nil,unit.weapNum) return end
            -- if multi weapon, get the one that has the longest range and is not a manulaFire
            local longest_range,weapon=0
            for i,weap in ipairs(unit) do if weap.wrange>longest_range and not weap.manualFire then longest_range,weapon=weap.wrange,weap end end
            AimWithMouse(oneAttacker,unit,weapon,weapon.weapNum)
            return
        end
    end
    if next(ordersToRemove,nil) then  -- remove/fixing/remplace target on the fly when ordering static defense/bomber out of range
        local fix = ordersToRemove.fix
        ordersToRemove.fix=nil
        local id,target = next(ordersToRemove,nil)
        local x,y,z = unpack(target)

        local queue=spGetCommandQueue(id,-1)
        local unit = unitsToTrace[id]
        for i=1,#queue do 
            local order=queue[i]
            if order.id==20 then
                local px,pz = order.params[1],order.params[3]
                if px==x and pz==z then
                    if fix then GetNewTarget(id,unit,unit.weapNum or unit[1].weapNum,x,y,z,i) end
                    RemoveOrder(id,unit,order.tag,x,y,z,'norepeat')
                    ordersToRemove[id]=nil
                    break
                end
            end
        end
    end
end
--------------
--- MAIN EVENT
--------------
function widget:GameFrame(frame)
    if next(bufferAttacks,nil) then 
        for id,tbl in pairs(bufferAttacks) do
            if tbl.release or tbl.onClickRelease and not select(3,spGetMouseState()) then ReleaseBuffer(id) end -- send the  attacks buffered for repeat on the release of click or for some special units
        end
    end
    if frame<=frame_morph+1 then return end -- skip the frame when morph just happened
    -----------------------
    if not mouseTest and next(unitsToTrace) then
        for id,unit in pairs(unitsToTrace) do
            if frame>=unit.nextFrame then
                Check(id,unit,frame)
            end
        end
    end
end
------------
-----------------
function widget:UnitDestroyed(unitID)
    unitsToTrace[unitID]=nil
    if oneAttacker==unitID then oneAttacker=nil end
end

--------------------------------------------------------
local MouseMoveFunction
function widget:Initialize()
    autoreload = true
    if spIsReplay() or Spring.GetSpectatingState() then
        widgetHandler:RemoveWidget(widget)
        return
    end
    DisableOnSpec = DisableOnSpec(widgetHandler,widget)-- setup automatic callin disabler
    widgetHandler:RegisterGlobal('MorphFinished', MorphFinished)
    -- Hijack CustomFormation2 and replace a function by another, to get notified of the positions of path created before orders are given and also to modify the spacing of those positions
    local CF2 = widgetHandler:FindWidget('CustomFormations2')
    if CF2 then
        if not CF2._GiveNonNotifyingOrder then
            MouseMoveFunction = CF2.MouseMove
            local GiveNotifyingOrder = GetUpvaluesOf(MouseMoveFunction,'GiveNotifyingOrder')
            if not GiveNotifyingOrder then
                MouseMoveFunction = GetUpvaluesOf(MouseMoveFunction,'OriCF2MouseMove')
                if MouseMoveFunction then
                    GiveNotifyingOrder = GetUpvaluesOf(MouseMoveFunction,'GiveNotifyingOrder')
                end
                if not GiveNotifyingOrder then
                    Echo(Spring:GetInfo().name .. " can't find needed upvalues of CustomFormation2 MouseMove")
                    widgetHandler:RemoveWidget(widget)
                    return
                end
            end
            local GiveNonNotifyingOrder,num  = GetUpvaluesOf(MouseMoveFunction,'GiveNonNotifyingOrder')
            Echo('GiveNonNotifying', GiveNonNotifyingOrder,num)            
            CF2._GiveNonNotifyingOrder = GiveNonNotifyingOrder
            setupvalue(MouseMoveFunction, num, GiveNotifyingOrder)
        end
        spacing,numSpacing = GetUpvaluesOf(MouseMoveFunction,'minPathSpacingSq')

        CF2MouseMove = MouseMoveFunction
        CF2.modifiedBy = CF2.modifiedBy or {}
        CF2.modifiedBy[self:GetInfo().name]=true
    end
    uds=UnitDefs
    DefineBaseWeapons()
    --
    widget:CommandsChanged()
    Debug('LOADED')
end

-------------------------------------------------------------
-------------------------------------------------------------
---------------------------DRAWING---------------------------
-------------------------------------------------------------
-------------------------------------------------------------

local function drawPoints(point) return function() local x,y,z=unpack(point) glColor(point.color) glVertex(x,y,z) end end
local function drawLine(line)    return function() local x,y,z,x2,y2,z2=unpack(line) glColor(line.color)  glVertex(x,y,z) glVertex(x2,y2,z2) end end
local bonuscolor = (function()
    local white,lightblue,blue,darkgreen,lightgreen,green,lime,yellow,orange,red,darkred,magenta,hardviolet,violet,purple,black
        =
          colors.white+0.5, colors.lightblue+0.5,colors.blue+0.5, colors.darkgreen+0.5, colors.lightgreen+0.5, colors.green+0.5, colors.lime+0.5
         ,colors.yellow+0.5,colors.orange+0.5,colors.red+0.5,colors.darkred+0.5,colors.magenta+0.5,colors.hardviolet+0.5,colors.violet+1,colors.purple+0.5,colors.black+0.5

    local inRange, LoF, move, buildable, movable,validSpot,goodSpot,mark,border
    local function CellColor(cell)
        inRange, LoF, move, buildable = cell.inRange, cell.LoF, cell.move, cell.buildable
        movable = move or buildable
        validSpot,goodSpot,mark,border = cell.validSpot,cell.goodSpot,cell.mark,cell.edge
        return border              and white
            or mark                and yellow
            --or goodSpot and inBetterRange and lightblue
            or goodSpot            and lime
            or validSpot           and darkgreen
            or LoF and inRange     and orange
            or movable and inRange and lightblue
            or movable             and blue
            or                         magenta
    end
    return CellColor
end)()


function widget:DrawWorld()


    if draw[1] then
        if not draw[2] then
            local pos = draw[1]
            Points[#Points+1] = {pos[1], pos[2], pos[3],color=colors.purple+1 ,size=14}
        else
            gl.BeginEnd(GL.LINES, drawfunc, draw)
        end
    end
    if draw2[2] then
        gl.Color(0.8,0.5,0.5,1)
        gl.BeginEnd(GL.LINES, drawfunc, draw2)
    end

    if mouseTest and oneAttacker then
            local bx,by,bz = spGetUnitPosition(oneAttacker)
            bx,bz=8+floor(bx/16)*16,8+floor(bz/16)*16
            local nx,ny,nz
            glPointSize(7)
            for x,col in pairs(zone) do
                for z,cell in pairs(col) do
                    nx,nz=x+bx,z+bz
                    draw[1],draw[2],draw[3],draw.color = nx,spGetGroundHeight(nx,nz),nz,bonuscolor(cell)
                    glBeginEnd(GL_POINTS,drawPoints(draw))
                end
            end
            glPointSize(1)
    end
    if next(Points) then
        glDepthTest(false)
        for _,point in pairs(Points) do
            glPointSize(point.size)
            glBeginEnd(GL_POINTS,drawPoints(point))
        end
        glColor(1,1,1,1)
    end


    if Lines[1] then
        glDepthTest(true)
        for i,line in ipairs(Lines) do glLineWidth(line.size or 1) glBeginEnd( GL_LINES, drawLine(line) ) glLineWidth(1) end 
        glColor(1,1,1,1)
        glDepthTest(false)
    end
 
    --glDepthTest(false)    
end






function widget:SetConfigData(data)

end
function widget:GetConfigData()

end

function widget:GameOver()
    widgetHandler:RemoveWidget(self)
end

function widget:Shutdown()
    --if autoreload then spSendCommands('luaui enablewidget DrawFire') return  Debug('AUTORELOADED',autoreload) end
    widgetHandler:DeregisterGlobal('MorphFinished', MorphFinished)
    -- set back CustomFormation2 function to its original
    local CF2 = widgetHandler:FindWidget('CustomFormations2')
    if CF2 then
        if CF2.modifiedBy then
            CF2.modifiedBy[self:GetInfo().name]=nil
            if not next(CF2.modifiedBy,nil) then
                if CF2._GiveNonNotifyingOrder then
                    local _,num  = GetUpvaluesOf(MouseMoveFunction,'GiveNonNotifyingOrder')
                    setupvalue(MouseMoveFunction, num, CF2._GiveNonNotifyingOrder)
                    CF2._GiveNonNotifyingOrder=nil
                end
            end
        end
        numSpacing = select(2,GetUpvaluesOf(MouseMoveFunction,'minPathSpacingSq'))
        setupvalue(MouseMoveFunction, numSpacing, 50*50)
    end
end
f.DebugWidget(widget)
