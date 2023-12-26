--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--
--  file:    unit_smart_nanos.lua
--  brief:   Enables auto reclaim & repair for idle turrets
--  author:  Owen Martindell
--
--  Copyright (C) 2008.
--  Licensed under the terms of the GNU GPL, v2 or later.
--
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function widget:GetInfo()
  return {
    name      = "Smart Builders",
    desc      = "Enables smart auto reclaim & assist for builders",
    author    = "Helwor",
    date      = "mid 2021",
    license   = "GNU GPL, v2 or later",
    layer     = -1000000, -- before Draw Placement and Persistent Build Height 2 so they can override this widget orders
    enabled   = false,  --  loaded by default?
    handler   = true,
  }
end
local Echo = Spring.Echo


local facDefID = {}
for defID,def in pairs(UnitDefs) do
    if def.isFactory then
        facDefID[defID] = true
    end
end
local tagConv = {
    manual = 'm',
    reclaiming = 'c',
    repairing = 'r',
    listening = 'l',
    building = 'b',
}
local f = VFS.Include("LuaUI\\Widgets\\UtilsFunc.lua")
local debugMe = false



local myDrawOrders
local DrawUtils
local drawBalance = {}
local drawPos = {}
local myClusters = {}
local lists = {}

local res = {

Mstalling = false
,Estalling = false
,OverEnergy = false
,OverMetal = false
,ePer = 0
,mPer = 0
,eCur = false
,eMax = false
,mCur = false
,mMax = false
,wantM = 0
,wantE = 0
,mIncome = false
,mRegular = false
,energyIncome = false
,M_reserve = false
,E_reserve = false
,mExtra = 0
,eExtra = 0
,needStorage = false
,fullBuildCap = 0
,buildCap = 0
,buildTick = false

}



------------- Partial DEBUG
local Debug = { -- default values
    active=false -- no debug, no hotkey active without this
    ,global=false -- global is for no key : 'Debug(str)'
    ,reload = true
    ,prevision = false
    ,showBalance = false
    ,prio = false
    ,sequence = false
    ,pos = false
    ,range = false
    ,Log = false
    ,cluster = false
    ,allowed = false
    ,roam = false
    ,debugVar = false

}

debugVars = {'res',res}



Debug.callbacks = {
    pos = function(self)
        if not self.value then
            for k,order in pairs(drawPos) do
                drawPos[k]=nil
                myDrawOrders[order] = nil
            end
        end
    end
}
-- Debug.hotkeys = {
--     active =            {'ctrl','alt','M'} -- this hotkey active the rest
--     ,global =           {'ctrl','alt','G'}
--     -- ,reload =           {'ctrl','alt','R'}

--     -- ,prevision =        {'ctrl','alt','K'}
--     ,pos =              {'ctrl','alt','P'}
--     ,prio =             {'ctrl','alt','H'}
--     ,sequence =         {'ctrl','alt','Q'}
-- }
local cfg = {
    allow_roam = true,
    roam_value=120,
    roam_time_out = 0,
    allow_roam_on_fight = true,
    draw_range = true,
    draw_alpha = 0.5,
    disallow_comms = true,
    smart_conjurer = true,
    replace_fight = true,
    override_autoguard = true,

    big_roam_at_fac = true,
    -- roam_at_fac = 700,
    detect_cluster = true,
    cluster_range = 600,
    min_cluster_size = 5,
    max_away_cluster = 500,

    draw_tag = true,
    temp_draw_cluster = false,
    temp_draw = false,
    antilag = true,
}
local Units
local builders = {}
local builderClass = {}

local rangeColor = {0.4,0.5,0.7,cfg.draw_alpha}
local osclock = os.clock
options_path = 'Hel-K/Smart Builders'
options_order = {
    'lbl_roam','allow_roam','roam_value','roam_time_out',
    'lbl_fight_roam','allow_roam_on_fight','replace_fight',
    'lbl_restriction','antilag','disallow_comms','smart_conjurer','override_autoguard',
    'lbl_cluster','detect_cluster','old_detect','cluster_range','min_cluster_size','max_away_cluster',
    'lbl_draw','draw_tag','draw_range','draw_alpha',
}
options = {
    lbl_roam = {
        name = 'Roaming',
        type = 'label',
    },
    allow_roam = {
        name = 'Allow Roaming',
        type = 'bool',
        desc = 'Constructor will be able to move depending on the move state it have',
        value = cfg.allow_roam,
        OnChange = function(self)

            cfg[self.key] = self.value
            for id,b in pairs(builders) do
                b:UpdateRoam()
            end
            cfg.temp_draw = 1
        end,
    },
    roam_value = {
        name = 'Roaming value',
        type = 'number',
        min = 50,
        value = cfg.roam_value,
        max = 500,
        desc = 'Set the base of roaming distance that will be multiplied by the move state',
        tooltipFunction = function(self)
            cfg.roam_value = self.value
            for id,b in pairs(builders) do
                b:UpdateRoam()
            end
            cfg.temp_draw = 1
            return self.value
        end,
        OnChange = function(self)
            cfg[self.key] = self.value
        end,
    },
    roam_time_out = {
        name = 'Roam Timing',
        type = 'number',
        min = 0,
        value = cfg.roam_time_out,
        max = 10,
        step = 0.1,
        desc = 'Set the time in seconds until con is allowed to roam once beeing idle.',
        tooltipFunction = function(self)
            return ('%.2f'):format(self.value) .. 'seconds'
        end,
        OnChange = function(self)
            cfg[self.key] = self.value
            for id,b in pairs(builders) do
                b:UpdateRoam()
            end

        end,
    },
    ---------------------------
    lbl_fight_roam = {
        name = 'Patol Roaming',
        type = 'label',
    },

    allow_roam_on_fight = {
        name = 'Allow Roaming on A-Move/Patrol',
        type = 'bool',
        desc = 'Allow the widget to replace current auto order, if wanted.',
        value = cfg.allow_roam_on_fight,
        OnChange = function(self)
            cfg[self.key] = self.value
            for id,b in pairs(builders) do
                b:UpdateRoam()
            end

        end,
    },
    replace_fight = {
        name = 'Fully Replace A-Move/Patrol',
        type = 'bool',
        desc = "This way the widget will not be bothered by unwanted order appearing"
        .."\n and thus, stopping him from going forward if there's nothing good around.",
        value = cfg.replace_fight,
        OnChange = function(self)
            cfg[self.key] = self.value
            for id,b in pairs(builders) do
                b:UpdateRoam()
            end

        end,
    },
    ------------------------
    lbl_restriction = {
        name = 'Restrictions',
        type = 'label',
    },
    disallow_comms = {
        name = 'Disallow Commanders roaming',
        type = 'bool',
        desc = 'You can also put it on hold position, that work too.',
        value = cfg.disallow_comms,
        OnChange = function(self)
            cfg[self.key] = self.value
            for id,b in pairs(builders) do
                b:UpdateRoam()
            end
        end,
    },
    smart_conjurer = {
        name = 'Smart Conjurers',
        type = 'bool',
        desc = 'Conjurer will not be controlled by widget when cloaked and away from friendly units.'
        ..'\nCluster detection must be activated to work.',
        value = cfg.smart_conjurer,
        OnChange = function(self)
            if cfg[self.key] ~= self.value then
                cfg[self.key] = self.value
                cfg.temp_draw_cluster = 3
                for id,b in pairs(builders) do
                    b:UpdateRoam()
                end
            end
        end,
    },
    override_autoguard = {
        name = 'Override Auto-guard',
        type = 'bool',
        desc = 'cons Autoguarding fac when created will not count as manual',
        value = cfg.override_autoguard,
        OnChange = function(self)
            cfg[self.key] = self.value
            for id,b in pairs(builders) do
                b:UpdateRoam()
            end
        end,
    },
    antilag = {
        name = 'Anti Lag',
        type = 'bool',
        desc = 'reduce check rate depending on lag',
        value = cfg.antilag,
        OnChange = function(self)
            cfg[self.key] = self.value
        end,
    },
    -----   -----------------
    lbl_cluster = {
        name = 'Cluster Detection',
        type = 'label',
    },
    detect_cluster = {
        name = 'Detect Cluster',
        desc = 'Detect cluster of friendly units, used by smart Conjurers',
        type = 'bool',
        value = cfg.detect_cluster,
        OnChange = function(self)
            if cfg[self.key] ~= self.value then
                cfg.temp_draw_cluster = 6
                cfg[self.key] = self.value
            end
        end,
    },
    old_detect = {
        name = 'Use Old Detection',
        type = 'bool',
        value = false,
    },
    cluster_range = {
        name = 'Cluster Range',
        type = 'number',
        min = 50,
        value = cfg.cluster_range,
        max = 800,
        tooltipFunction = function(self)
            if cfg[self.key] ~= self.value then
                cfg.cluster_range = self.value
                cfg.temp_draw_cluster = 6
                return self.value
            end
        end,
        OnChange = function(self)
            if cfg[self.key] ~= self.value then
                cfg.temp_draw_cluster = 1.5
                cfg[self.key] = self.value
            end
        end,
    },
    min_cluster_size = {
        name = 'Min Cluster Size',
        type = 'number',
        min = 1,
        value = cfg.min_cluster_size,
        max = 30,
        tooltipFunction = function(self)
            if cfg[self.key] ~= self.value then
                cfg.min_cluster_size = self.value
                cfg.temp_draw_cluster = 6
                return self.value
            end
        end,
        OnChange = function(self)
            if cfg[self.key] ~= self.value then
                cfg[self.key] = self.value
                cfg.temp_draw_cluster = 2
            end
        end,
    },
    max_away_cluster = {
        name = 'Max Away From Cluster',
        desc = 'How far from friendly cluster of unit a cloaked cloak builder is allowed to be controlled by the widget',
        type = 'number',
        min = 0,
        value = cfg.max_away_cluster,
        max = 1000,
        tooltipFunction = function(self)
            cfg.max_away_cluster = self.value
            cfg.temp_draw_cluster = 6
            return self.value
        end,
        OnChange = function(self)
            cfg.temp_draw_cluster = 2
            cfg[self.key] = self.value
        end,
    },


    ---------------------
    lbl_draw = {
        name = 'Graphics',
        type = 'label',
    },
    draw_range = {
        name = 'Draw Roaming range',
        type = 'bool',
        value = cfg.draw_range,
        OnChange = function(self)
            cfg[self.key] = self.value
        end,
    },

    draw_alpha = {
        name = 'Transparency',
        type = 'number',
        min = 0,
        value = cfg.draw_alpha,
        max = 1,
        step = 0.01,
        desc = 'Draw roaming range transparency',
        tooltipFunction = function(self)
            rangeColor[4] = self.value
            cfg.draw_alpha = self.value
            cfg.temp_draw = 1
            return self.value==0 and 'disabled' or ('%.2f'):format(self.value)
        end,
        OnChange = function(self)
            cfg[self.key] = self.value
        end,
    },
    draw_tag = {
        name = 'Draw Tags',
        type = 'bool',
        value = cfg.draw_tag,
        desc = 'Draw tag on constructors, commenting their state',
        OnChange = function(self)
            cfg[self.key] = self.value
        end,
    },


}
-------------



local terraunitDefID = UnitDefNames['terraunit'].id
local trackedUnits

local builderDefID = {}
for defID, def in pairs(UnitDefs) do
    if def.isBuilder and not def.isFactory then
        builderDefID[defID] = def
    end
end

--addon.UnitCmdDone(bID, unitDefID, unitTeam, cmdID, cmdParams, cmdOpts, cmdTag)
--addon.builderIDle(bID, unitDefID, unitTeam)
--Spring.Echo(Spring.GetUnitCurrentCommand(UnitDefs[GetUnitDefID(builders[bID])]))
--Spring.GetUnitRulesParams(id)
--Spring.GetUnitStates(id)
--spring.SetActiveCommand() or Spring.SetActiveCommand()
--addon.TerraformComplete(bID, unitDefID, unitTeam, buildbuilderID, buildUnitDefID, buildUnitTeam)
---------------------------------------------
---------Setting up Priorities
-- very expensive unit about to die -20%
-- most damaged com about to die -33%         (reclaim Efeatures if needed)
-- com about to die -33%                      (reclaim Efeatures if needed)
-- most damaged allied com about to die -33%  (reclaim Efeatures if needed)
-- allied com about to die -33%               (reclaim Efeatures if needed)
-- expensive unit about to die -33%           (reclaim Efeatures if needed)
-- expensive defense about to die -33%        (reclaim Efeatures if needed)
-- same for 33 to 50%                         (reclaim Efeatures if needed)
-- small units to 100%                        (reclaim Efeatures if needed)
-- medium units to 75%                        (reclaim Efeatures if needed)
-- reclaim if no more metal
-- reclaim if EEstalling
-- finish repairing if no more metal
-- reclaim if would like more metal
-- help building

-- **player order overwriting priority until turret is on patrol or on no order


--------------------------------------------------------------------------------
--[[VFS.Include("LuaRules/Utilities/ClampPosition.lua")
local GiveClampedOrderToUnit = Spring.Utilities.GiveClampedOrderToUnit--]]
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

--include("callins.lua")
--include("LuaUI/utilities.lua")
--include('LuaRules/gadgets.lua')
--include ("LuaRules/Gadgets/unit_priority.lua")
--include("LuaRules/Configs/customcmds.h.lua")
--include("LuaRules/Configs/constants.lua")
--include ("LuaUI/Configs/integral_menu_commands.lua")





--- CONFIG

local UPDATE_CLUSTER_RATE = 100 -- rate of frame to evaluate clusters
local UPDATE_RESOURCE_RATE = 100
local UPDATE_RATE = 20 -- number of game frames to perform a full cycle for all builders
local MAX_BUILDERS_PER_FRAME = 3 --   that might extend the time of a cycle but it's less taxing
local CHECK_DELAY = 0 -- is recalculated on each new builder created/destroyed
local BUILDERS_PER_FRAME = 0 -- same
---
local lag
local check_delay, builders_per_frame = 0, 0 -- final value adjusted for lag
local currentFrame = Spring.GetGameFrame()
local lastResFrame = currentFrame
local roundFrame = currentFrame
--
local terraUnitDefID = UnitDefNames['terraunit'].id
local updateResourceFrame = currentFrame + UPDATE_RESOURCE_RATE


VFS.Include("LuaRules/Configs/customcmds.h.lua")
local l = f.l
local checkTime = f.checkTime

local kunpack = f.kunpack
local Page = f.Page
--UnitCmdDone() --> "bID, unitDefID, unitTeam, cmdID, cmdTag, cmdParams, cmdOptions" cmdParams and cmdOptions are only available from version 95.0
--Spring.GetUnitCurrentBuildPower
--Spring.FindUnitCmdDesc ( number bID, number cmdID ) -> nil | number index
--CommandsChanged() --> unknown (none?)
--UnitFromFactory() --> "bID, unitDefID, unitTeam, factID, factDefID, userOrders"
--builderIDle() --> "bID, unitDefID, teamID"
--addon.UnitFromFactory(bID, unitDefID, unitTeam, factID, factDefID, userOrders) (when fac has finished unit)
--function gadgetHandler:UnitPreDamaged(  bID,  unitDefID,  unitTeam,  damage,  paralyzer,  weaponDefID,  projectileID,  attackerID,  attackerDefID,  attackerTeam)
--function gadgetHandler:UnitDamaged(  bID,  unitDefID,  unitTeam,  damage,  paralyzer,  weaponDefID,  projectileID,  attackerID,  attackerDefID,  attackerTeam)
--function gadgetHandler:FeatureCreated(featureID, allyTeam)
--function gadgetHandler:FeatureDestroyed(featureID, allyTeam)
--function gadgetHandler:FeatureDamaged(  featureID,  featureDefID,  featureTeam,  damage,  weaponDefID,  projectileID,  attackerID,  attackerDefID,  attackerTeam)

local GetUnitDefID                = Spring.GetUnitDefID
local GetAllUnits                 = Spring.GetAllUnits
local GetMyTeamID                 = Spring.GetMyTeamID
local GetUnitNearestEnemy         = Spring.GetUnitNearestEnemy
local spGetUnitHealth             = Spring.GetUnitHealth
local GetUnitsInCylinder          = Spring.GetUnitsInCylinder
local spGetCommandQueue           = Spring.GetCommandQueue
local GetFeatureDefID             = Spring.GetFeatureDefID
local GetFeatureResources         = Spring.GetFeatureResources
local AreTeamsAllied              = Spring.AreTeamsAllied
local GetFeaturePosition          = Spring.GetFeaturePosition
local GetGameSeconds              = Spring.GetGameSeconds
local GetSelectedUnits            = Spring.GetSelectedUnits
local GetUnitTeam                 = Spring.GetUnitTeam
local GetTeamResources            = Spring.GetTeamResources
local GetUnitCurrentBuildPower    = Spring.GetUnitCurrentBuildPower
local GetUnitMaxRange             = Spring.GetUnitMaxRange
local GetFeaturesInCylinder       = Spring.GetFeaturesInCylinder
local spValidUnitID               = Spring.ValidUnitID
local spValidFeatureID            = Spring.ValidFeatureID
local spSendCommands              = Spring.SendCommands
local spuCheckBit                 = Spring.Utilities.CheckBit
local spGetTeamRulesParam        = Spring.GetTeamRulesParam
local spGetTeamResources          = Spring.GetTeamResources
local spGetUnitRulesParam         = Spring.GetUnitRulesParam
local widgetName
local spGetUnitCurrentCommand     = Spring.GetUnitCurrentCommand
local spGetUnitCurrentBuildPower  = Spring.GetUnitCurrentBuildPower
local spGetUnitIsDead             = Spring.GetUnitIsDead
local spGetGameSeconds              = Spring.GetGameSeconds
local spGetSelectedUnits          = Spring.GetSelectedUnits
local spGiveOrderToUnit           = Spring.GiveOrderToUnit
local spGetUnitIsCloaked          = Spring.GetUnitIsCloaked
local spGetUnitsInCylinder        = Spring.GetUnitsInCylinder
local spGetUnitPosition           = Spring.GetUnitPosition
local spGetGameFrame              = Spring.GetGameFrame
local spGetUnitStates             = Spring.GetUnitStates
local spGetGroundHeight           = Spring.GetGroundHeight
local glPushMatrix      = gl.PushMatrix
local glTranslate       = gl.Translate
local glBillboard       = gl.Billboard
local glColor           = gl.Color
local glText            = gl.Text
local glPopMatrix       = gl.PopMatrix
local glCallList        = gl.CallList


local maxUnits = Game.maxUnits
local max = math.max
local min = math.min
local abs = math.abs
local round = math.round
local round = function(x)return tonumber(round(x)) end
local ceil = math.ceil
local rand = math.random
local nround = f.nround


---
local preGame
local EMPTY_TABLE       = {}
local TABLE_ZERO        = {0}
local TABLE_1           = {1}
local TABLE_2           = {1}
local TABLE_PARAM         = {}
local CMD_STOP          = CMD.STOP
local CMD_REPAIR        = CMD.REPAIR
local CMD_RECLAIM       = CMD.RECLAIM
local CMD_GUARD         = CMD.GUARD
local CMD_OPT_INTERNAL  = CMD.OPT_INTERNAL
local CMD_OPT_SHIFT     = CMD.OPT_SHIFT
local CMD_OPT_ALT       = CMD.OPT_ALT
local CMD_REMOVE        = CMD.REMOVE
local SB_INTERNAL       = 9
local CMD_FIGHT         = CMD.FIGHT
local CMD_INSERT        = CMD.INSERT
local CMD_MOVE_STATE    = CMD.MOVE_STATE
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local GiveOrderToUnit

local CommandTracker


local bID
local next_frame = 1
local n_builders = 0

local featReclaimed = {}
local rezedFeatures
local num = {reclaiming=0,building=0,repairing=0}
local waiting = {}
local FeatureDefs = FeatureDefs


local selBuilders = {}

local g = {}

local wantedFeatureDefID = {}
for defID, def in pairs(FeatureDefs) do
    if def.reclaimable and not (def.name:match('_base_') or def.name:match('dyn')) then
        wantedFeatureDefID[defID] = true
    end
end
-- local cntleft,cntright,cntafterleft,cntafterright = 0,0,0,0





local newround
local numbd = 0
local cnt = 0

local thisRound = {}

local gotBuilders

local METAL_BALANCE = {
    [true]     =  1,
    [false]    =  0,
    reclaiming =  0,
    building   = -1,
    repairing  =  0,
    listening  =  0
}
local ENERGY_BALANCE = {
    [true]     =  1,
    [false]    =  0,
    reclaiming =  0,
    building   = -1,
    repairing  = -1,
    listening  =  0
}
local GetUnitPos = function(id, threshold)
    local unit = Units[id]
    local pos = unit.pos
    if not unit.isStructure and pos.frame < currentFrame + threshold then
        pos[1], pos[2], pos[3] = spGetUnitPosition(id)
    end
    return  pos[1], pos[2], pos[3]
end

local function AdjustForLag()

-- adjust with lag
    local new_builders_per_frame =  max(1,BUILDERS_PER_FRAME / lag[1])
    -- local adjusted = new_builders_per_frame / BUILDERS_PER_FRAME 
    local adjusted = 1
    local new_check_delay = CHECK_DELAY * lag[1] * adjusted 
    -- if n_builders==614 then
    --     Echo('UPDATE_RATE',UPDATE_RATE,'/n_builders ',n_builders, 'is ', UPDATE_RATE/n_builders,'new_builders_per_frame:',new_builders_per_frame,
    --         'checkdelay',CHECK_DELAY,'new check delay',new_check_delay,'lag:',lag[1])
    -- end
    return new_builders_per_frame, new_check_delay
end

-- screen debugging
local font = "LuaUI/Fonts/FreeSansBold_14"
local FormatNum = function(num)
    return ('%.1f'):format(num):gsub('%.0','')
end
local OrderDraw = function(Type,arg,params)
    if Type == 'pos' then
        local id = arg
        -- Echo("id,params and unpack(params) is ", id,params and unpack(params))
        local order = drawPos[id]
        if not params then
            if order then
                myDrawOrders[order] = nil
                drawPos[id] = nil
            end
        else
            if not order then

                local str = type(id)~='string' and spValidUnitID(id) and 'x' or tostring(id)
                order = {world=true,str=str,type='font',font=font,pos=params,color='paleblue'}
                table.insert(
                    myDrawOrders
                    ,order
                )myDrawOrders[order] = true
                drawPos[id] = order
            else
                order.pos[1], order.pos[2], order.pos[3] = unpack(params)
            end
        end
    end
    if Type == 'balance' then
        if not arg then
            if next(drawBalance) then
                local orderM, orderE = drawBalance[1], drawBalance[2]
                if orderM then
                    myDrawOrders[orderM] = nil
                    drawBalance[1] = nil
                end
                if orderE then
                    myDrawOrders[orderE] = nil
                    drawBalance[2] = nil
                end
            end
            return

        end
        if arg=='M' then
            local strM = FormatNum(res.mExtra) --[[.. ':' .. FormatNum(res.needM)--]]
            local orderM = drawBalance[1]
            if orderM and myDrawOrders[orderM] then
                orderM.str = strM
            else
                orderM = {str=strM,type='font',font=font,pos={'48%',41},color='paleblue'}
                table.insert(
                    myDrawOrders
                    ,orderM
                )myDrawOrders[orderM] = true
                drawBalance[1] = orderM

            end
        end
        if arg == 'E' then
            local orderE = drawBalance[2]
            local strE = FormatNum(res.eExtra) --[[.. ':' .. FormatNum(res.needE)--]]
            if orderE and myDrawOrders[orderE] then
                orderE.str = strE
            else
                orderE = {str=strE,type='font',font=font,pos={'72%',41},color='yellow'}
                table.insert(
                    myDrawOrders
                    ,orderE
                )
                myDrawOrders[orderE] = true
                drawBalance[2] = orderE
            end
        end
    end
end
---------



---------- updating teamID
local myTeamID = Spring.GetMyTeamID()
local MyNewTeamID = function()
    myTeamID = Spring.GetMyTeamID()
end
widget.TeamChanged = MyNewTeamID
widget.PlayerChanged = MyNewTeamID
widget.Playeradded = MyNewTeamID
widget.PlayerRemoved = MyNewTeamID
widget.TeamDied = MyNewTeamID
----------

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
local function IsOwnOrder(coded)
    -- Echo("SB_INTERNAL, CMD_OPT_SHIFT, CMD_OPT_ALT is ", SB_INTERNAL, CMD_OPT_SHIFT, CMD_OPT_ALT)
    return coded == SB_INTERNAL + CMD_OPT_SHIFT or coded == CMD_OPT_ALT + CMD_OPT_SHIFT + SB_INTERNAL
end
local function Name(ID)
  if spValidUnitID(ID)  and GetUnitDefID(ID) then
    return UnitDefs[GetUnitDefID(ID)].humanName
  end
  if spValidFeatureID(ID) then
    return FeatureDefs[GetFeatureDefID(ID)].tooltip
  end
  return false
end
local function FactoryAround(id)
    -- Echo('fac around ?')
    local x,y,z = GetUnitPos(id, 15)
    local units = spGetUnitsInCylinder(x,z,250,myTeamID)
    -- Echo("myTeamID is ", myTeamID)
    for i,id in ipairs(units) do
        local unit = Units[id]
        if unit and unit.isFactory then
            return true
        end
    end
end
local function FindIntersect(x,z,s1,s2,e1,e2)
    -- get the corresponding point on a line, x,z beeing the pos to transform, s1,s2 start of line, e1, e2, end of line
    -- count = (count or 0) + 1
    -- Echo("x,z,s1,s2,e1,e2 is ", x,z,s1,s2,e1,e2)
    local se = ((s1-e1)^2 + (s2-e2)^2) ^ 0.5
    local ps = ((x-s1)^2 + (z-s2)^2) ^ 0.5
    local pe = ((x-e1)^2 + (z-e2)^2) ^ 0.5
    local hyps = (se^2 + ps^2) ^ 0.5
    local hype = (se^2 + pe^2) ^ 0.5
    -- Echo("ps,se,pe is ", ps,se,pe)
    -- Echo(count,"ps,hype is ", ps,hype)
    if pe>hyps then
        -- Echo(count,'unit is closer to the start')
        -- unit is out but closer from the start
        return s1, s2
    elseif ps>hype then
        -- Echo(count,'unit is closer to the end')
        return e1, e2
    else
        -- Echo('unit is between the points')
        -- unit is between the points
        local dx,dz = (e1-s1), (e2-s2)
        local ratio = ps/(pe+ps)
        local posX, posZ = s1 + (dx * ratio), s2 + (dz * ratio)
        -- Echo(count,'ps',ps,'pe',pe,"dx,dz", dx,dz,"ratio",ratio,"posX,posZ",posX,posZ)
        return posX, posZ
    end
        -- unit is beyond the end
end
local function UpdateResources()
    --local metalIncome    = p.metalIncome") or 0
    -- NOTE: Asking team rules params is TAXING, you would think that would go faster to ask for the whole table but no, the table has 50K+ entries !
    local extraMetalPull  = spGetTeamRulesParam(myTeamID,'extraMetalPull') or 0
    local metalMisc       = spGetTeamRulesParam(myTeamID,'OD_team_metalMisc') or 0
    local metalBase       = spGetTeamRulesParam(myTeamID,'OD_team_metalBase') or 0
    local metalOverdrive  = spGetTeamRulesParam(myTeamID,'OD_team_metalOverdrive') or 0
    local mPull, mInc, mExp
    local ePull, eInc, eExp

    local energyOverdrive = spGetTeamRulesParam(myTeamID,'OD_energyOverdrive') or 0
    local extraEnergyPull = spGetTeamRulesParam(myTeamID,'extraEnergyPull') or 0
    --local energyChange    = spGetTeamRulesParam(myTeamID,'OD_energyChange") or 0
    --local extraChange     = math.min(0, energyChange) - math.min(0, energyOverdrive)
    --local energyMisc      = spGetTeamRulesParam(myTeamID,'OD_team_energyMisc") or 0
    res.energyIncome          = spGetTeamRulesParam(myTeamID,'OD_team_energyIncome') or 0

    res.mCur, res.mMax, mPull, mInc, mExp = GetTeamResources(myTeamID, "metal")
    res.eCur, res.eMax, ePull, eInc, eExp = GetTeamResources(myTeamID, "energy")


    res.E_reserve             = res.eMax > 0 and spGetTeamRulesParam(myTeamID,'energyReserve') or 0
    res.M_reserve             = res.mMax > 0 and spGetTeamRulesParam(myTeamID,'metalReserve') or 0

    res.mMax = res.mMax - 10000 -- aka HIDDEN_STORAGE
    res.eMax = res.eMax - 10000

    res.ePer = (res.eCur / res.eMax)
    res.mPer = (res.mCur / res.mMax)

    --local totalPull = ePull + extraEnergyPull + extraChange
    res.needStorage = res.eMax==0 or res.mMax==0

    res.eCur = min(res.eMax,res.eCur-res.energyIncome)
    res.eExtra = res.energyIncome - ePull - extraEnergyPull




    res.mRegular = (metalMisc+metalBase+metalOverdrive)
    res.mCur = max(0,  min(res.mMax,res.mCur - res.mRegular)  )
    res.mExtra = mInc - extraMetalPull - mPull

    --*******Echo("update",res.mExtra)
    --Echo("Spent "..res.mMax-res.mCur,'vs',WG.TerraCost)
    -- get the maximum build capacity for the next second (aka the minimum of M or E with their respective income added)
    --Echo("res.E_reserve is ", res.E_reserve,res.eCur)
    local usable_E = ceil(res.eCur)-res.E_reserve
    local usable_M = ceil(res.mCur)-res.M_reserve
    --res.buildCap = (usable_E<res.energyIncome or res.mCur<mInc) and min(usable_E+res.energyIncome,res.mCur+mInc) or min(usable_E,res.mCur)
    -- local fullbuildCap = min(ceil(res.mCur)+res.mExtra,ceil(res.eCur)+res.eExtra)
    res.buildCap = min(ceil(res.mCur)+res.mExtra-res.M_reserve,ceil(res.eCur)+res.eExtra-res.E_reserve)
    res.buildTick = min(res.energyIncome,mInc)



    ----(this to prevent Caretakers switching everytime between reclaim and building/repair)
    res.Mstalling = res.Mstalling or  (res.mPer<0.05 and res.mCur<75 ) -- res.Mstalling stay true or become true at <5% (or <75 metal if big storage)
    res.Mstalling = res.Mstalling and (res.mPer<0.15 and res.mCur<225) -- res.Mstalling become false >15% or >225
    
    res.Estalling = res.Estalling or  (res.ePer<0.05 and res.eCur<75 ) -- same for Energy
    res.Estalling = res.Estalling and (res.ePer<0.15 and res.eCur<225) -- 
    --
    res.OverEnergy = res.ePer > 0.98
    res.OverMetal = res.mPer > 0.98

    if ((res.mMax - res.mCur) < mInc) then res.OverMetal = true else res.OverMetal = false end
    --if res.mCur < 50 or res.mCur < (res.mMax * 0.1) then res.Mstalling = true else res.Mstalling = false end
    -- if we're expending more than income and we're below 50 percent stock, wouldlikereclaim become true -- not used for now

    wouldlikereclaim = ((mPull / mInc) > 0.95 and (mPull / mInc) < 1.05 and (res.mPer < 0.5))

    res.wantM = res.mMax==0 and -res.mExtra or res.mMax - (max(res.mCur,res.M_reserve) + res.mExtra)
    if res.wantM<res.mMax*0.01 then res.wantM=0 end
    res.needM = res.M_reserve - res.mCur - res.mExtra

        -- Echo('res updated ','needM: ' .. FormatNum(res.needM), 'needE: ' .. FormatNum(res.needE))
    OrderDraw('balance',Debug.showBalance() and 'M')


    res.wantE = res.eMax==0 and -res.eExtra or res.eMax - (max(res.eCur,res.E_reserve) + res.eExtra)
    if res.wantE<res.eMax*0.01 then res.wantE=0 end
    res.needE = res.E_reserve - res.eCur - res.eExtra
    OrderDraw('balance',Debug.showBalance() and 'E')




end

local function UpdateResourcesQuick()
-- quick eco update
    res.mCur = GetTeamResources(myTeamID, "metal")
        res.mCur = max(0,  min(res.mMax,res.mCur - res.mRegular))
    res.wantM = res.mMax==0 and -res.mExtra or res.mMax - (max(res.mCur,res.M_reserve) + res.mExtra)
    if res.wantM<res.mMax*0.01 then res.wantM=0 end
    OrderDraw('balance',Debug.showBalance() and 'M')


    res.eCur = GetTeamResources(myTeamID, "energy")
        res.eCur = max(0,  min(res.eMax,res.eCur-res.energyIncome))
    res.wantE = res.eMax==0 and -res.eExtra or res.eMax - (max(res.eCur,res.E_reserve) + res.eExtra)
    if res.wantE<res.eMax*0.01 then res.wantE=0 end
    OrderDraw('balance',Debug.showBalance() and 'E')


end
function builderClass:UpdateRoam()
    local debug = false
    local unit = self.unit
    if not self.canMove then
        -- self.canRoam = false
        -- self:GetRange()
        if debug then
            Echo(self.humanName,self.id,'cannot move')
        end
        self:GetRange()
        return false
    end
    if unit.isComm and (cfg.disallow_comms or self.wantCloak) then
        self.canRoam = false
        self:GetRange()
        if debug then
            Echo(self.humanName,self.id,'is comm and not allowed')
        end
        return false
    end
    if unit.isFighting or self.isFighting then
        if not cfg.allow_roam_on_fight then
            self.canRoam = false
            self:GetRange()
            if debug then
                Echo(self.humanName,self.id,'is not allowed in fight')
            end
            return false
        end
    else
        if not cfg.allow_roam then
            self.canRoam = false
            self:GetRange()
            if debug then
                Echo(self.humanName,self.id,'is not allowed on place')
            end
            return false
        end
        if unit.isIdle and cfg.roam_time_out>0 then
            if spGetGameSeconds() < self.idleTime + cfg.roam_time_out then
                self.canRoam = false
                self:GetRange()
                if debug then
                    Echo(self.humanName,self.id,'is waiting idle time out')
                end

                return false
            end
        end
    end
    self.canRoam = true
    self:GetRange()
    if debug then
        Echo(self.humanName,self.id,'is allowed')
    end
    return true
end
function builderClass:GetRange()
    local moveState = self.moveState
    if not self.canRoam or moveState == 0 then
        self.range = self.buildDistance
        self.extraRange = 0
        return self.buildDistance, 0
    end
    local extraRange = moveState * cfg.roam_value
    self.range = self.buildDistance + extraRange
    self.extraRange = extraRange
    return self.buildDistance, extraRange
end
function builderClass:GetFightingOrder()
    local debugPos = Debug.pos()
    if self.canRoam and (self.isFighting or self.unit.isFighting) then
        local id = self.id
        local x,y,z = GetUnitPos(id, 15)
        local queue = spGetCommandQueue(id,-1)
        if queue then
            for i,order in ipairs(queue) do
                -- Echo(i,'=>',order.id)
                if order.id==CMD_RAW_MOVE and IsOwnOrder(order.options.coded) then
                    return
                end
                if order.id==CMD_FIGHT then
                    local s1,s2 = self.posX,self.posZ
                    local e1,e2
                    -- Echo('#params',#order.params)
                    if order.params[6] then
                        s1,s2 = order.params[1], order.params[3]
                        e1,e2 = order.params[4], order.params[6]
                    else
                        e1,e2 = order.params[1], order.params[3]
                    end
                    self.fightingOrder = {s1,s2,e1,e2,uptime = spGetGameSeconds()+1.5}
                    local posX,posZ = FindIntersect(x,z,s1,s2,e1,e2)
                    self.posX, self.posY, self.posZ = posX, spGetGroundHeight(posX,posZ), posZ
                    if Debug.pos() then
                        OrderDraw('pos','p',{x,y,z})
                        OrderDraw('pos','_s',{s1,spGetGroundHeight(s1,s2),s2})
                        OrderDraw('pos','__e',{e1,spGetGroundHeight(e1,e2),e2})
                        OrderDraw('pos',id,{self.posX,self.posY,self.posZ})
                    end
                    -- Echo('found fight',i,#order.params..' params',unpack(order.params))
                    return order.tag
                end
            end
        end
    end
end

local spGetUnitIsActive = Spring.GetUnitIsActive

function builderClass:CheckSmartConjurer()
    local humanName = self.humanName
    if humanName ~= 'Conjurer' then
        return true
    end
    local id = self.id

    if self.isFighting and self.canRoam then
        Debug.allowed(humanName .. ' #' .. id .. ' is Allowed (Roam Fighting).')
        return truesy
    end

    local unit = self.unit

    if unit.isFighting then
        Debug.allowed(humanName .. ' #' .. id .. ' is Allowed (Fighting).')
        return true
    end

    if unit.isCloaked then
        if spGetUnitRulesParam(id,'areacloaked')==1 then
            Debug.allowed(humanName .. ' #' .. id .. ' is NOT Allowed (under area cloak).')
            return false
        end
        if unit.name == 'cloakcon' then
            if spGetUnitRulesParam(id,'cloak_shield') == 2  and spGetUnitIsActive(id) then
                Debug.allowed(humanName .. ' #' .. id .. ' is NOT Allowed (cloak shield).')
                return false
            end
            if not (cfg.detect_cluster and cfg.smart_conjurer) then
                Debug.allowed(humanName .. ' #' .. id .. ' is NOT Allowed (cloaked and no cluster detection/smart conjurer).')
                return false
            end
            local allowed = false
            local maxAway = cfg.max_away_cluster
            local x,y,z = self.posX,self.posY,self.posZ
            for i,cluster in ipairs(myClusters) do
                local cx,cy,cz = unpack(cluster.mid)
                if ((x-cx)^2 + (z-cz)^2) ^0.5 < maxAway then
                    allowed = true
                    break
                end
            end
            Debug.allowed(humanName .. ' #' .. id .. ' is ' .. (not allowed and 'NOT ' or '') .. 'allowed' ..  (not allowed and ' (too away from cluster)' or '(close enough of cluster') .. '.')
            return allowed
        end
        Debug.allowed(humanName .. ' #' .. id .. ' is NOT Allowed (cloaked and is not conjurer).')
    end
    Debug.allowed(humanName .. ' #' .. id .. ' is Allowed.')
    return true
end
do
    local PARAMS = {}
    local INSERT_PARAMS = {0,false,CMD_OPT_SHIFT + SB_INTERNAL,false}
    local OPTS = SB_INTERNAL + CMD_OPT_SHIFT
    local INSERT_OPTS = CMD_OPT_ALT + CMD_OPT_SHIFT + SB_INTERNAL
    function builderClass:GiveOrder(cmd,target)
        if self.isFighting or self.unit.isFighting then
            INSERT_PARAMS[2], INSERT_PARAMS[4] = cmd, target
            GiveOrderToUnit(self.id,CMD_INSERT,INSERT_PARAMS,INSERT_OPTS)
        else
            PARAMS[1] = target
            GiveOrderToUnit(self.id,cmd,PARAMS,OPTS)
        end
    end
end
function builderClass:New(id, unitDefID, unitTeam, def)
    if CommandTracker and not trackedUnits[id] then
        CommandTracker.SetTrackedUnit(id,true)
        -- Echo('tracking', id)
    else
        -- Echo((not CommandTracker and 'Command Tracker doesnt exist') or (id .. ' is already tracked'))
    end
    local posX,posY,posZ = GetUnitPos(id,0)
    local cmdID,_,_,curID = spGetUnitCurrentCommand(id)
    numbd=numbd+1
    local unit = trackedUnits[id]
    if not unit then
        return
    end
    local moveState, _ = 0
    if def.canMove then
        _, moveState = spGetUnitStates(id, false)
    end

    local unit = Units[id]
    local currentAction = unit.manual and 'manual' or "listening"
    local tag = unit.manual and 'm' or "l"
    local builder = {
    unitDefID = unitDefID,
    --buildDistance = def.canMove and def.buildDistance*2 or def.buildDistance,
    buildDistance = def.buildDistance,
    canMove = def.canMove,
    buildSpeed = def.buildSpeed,
    autoOrder = EMPTY_TABLE,
    isComm = unit and unit.isComm,
    posX = posX,
    posY = posY,
    posZ = posZ,
    canMove = def.canMove,
    idleTime = 0,
    moveState = moveState,
    range = def.buildDistance,
    currentAction = currentAction,
    tag = tag,
    action = false,
    recM = false,
    recE = false,
    noMoreEfeatures = false,
    id = id,
    humanName = def.humanName,
    unit = unit,
    lastCommand=false,
    treated = 0,
    priority = 'normal',
    name = def.name,
    sign = '[' .. Name(id) .. '#' .. id ..']:'

    }
    setmetatable(builder,{__index=builderClass})

    builder:UpdateRoam()
    -- Echo("builder.humanName,builder.canRoam,builder.range is ", builder.humanName,builder.canRoam,builder.range)
    builders[id] = builder

    OrderDraw('pos',id,Debug.pos() and {posX,posY,posZ})
    n_builders = n_builders+1
    CHECK_DELAY = max(1,round(UPDATE_RATE/n_builders)) --* lag[1]
    BUILDERS_PER_FRAME = min (round(1/(UPDATE_RATE/n_builders)), MAX_BUILDERS_PER_FRAME)
    -- builder_per_frame = round(math.max(1, builder_per_frame / lag[1]))

    if BUILDERS_PER_FRAME<1 then
        BUILDERS_PER_FRAME=1
    end
    if cfg.antilag and lag[1]> 1 then
        updateResourceFrame = lastResFrame + UPDATE_RESOURCE_RATE * lag[1]
        builders_per_frame, check_delay = AdjustForLag()
    else
        updateResourceFrame = lastResFrame + UPDATE_RESOURCE_RATE
        builders_per_frame, check_delay = BUILDERS_PER_FRAME, CHECK_DELAY
    end

    
    Debug.Log(builders[id].sign .. 'Created')

end

function widget:UnitFinished(id, unitDefID, unitTeam)
    if (unitTeam ~= myTeamID) then 
        return
    end
    local def = builderDefID[unitDefID]
    if def then
        builderClass:New(id, unitDefID, unitTeam, def)
    end
end

-------------------------------------------------------------------------------
---------------------- Getting Manual Command  --------------------------------

function widget:CommandNotify(cmd,params)
    if cmd == CMD_WANT_CLOAK then
        local applied
        if gotBuilders then
            for id, b in pairs(selBuilders) do
                if b.isComm then
                    local wantCloak = params[1] == 1
                    b.wantCloak = wantCloak
                    applied = true
                    if wantCloak then -- if want cloak remove the automatic orders
                        local curCmd,curTag,curOwn
                        local queue = spGetCommandQueue(id,2)
                        local current = queue[1]

                        if current then
                            curCmd,curTag,curOwn,curTgt = current.id, current.tag, current.options and IsOwnOrder(current.options.coded), not current.params[3] and current.params[1]
                            if not curOwn then
                                if curCmd == CMD_RAW_BUILD then
                                    local nex = queue[2]
                                    if nex and IsOwnOrder(nex.options.coded) then
                                        -- Echo(id,1,'remove order')
                                        -- GiveOrderToUnit(id, CMD_REMOVE, {nex.tag}, 0)
                                        Stop(id)
                                        -- it seems like removing an order while RAW_BUILD, the order disappear but the unit continue it's course
                                        -- so we better completely stop
                                    end
                                    -- the raw build will be removed by itself
                                    -- GiveOrderToUnit(id, CMD_REMOVE, {curTag}, 0)
                                end
                            else
                                if curCmd~=CMD_RAW_MOVE then -- when order is our own and cmd is RAW_MOVE, the builder has been manually set for SB to handle a fight order
                                    local nex = queue[2]
                                    if nex and IsOwnOrder(nex.options.coded) then
                                        -- Echo(id,1,'remove order')
                                        GiveOrderToUnit(id, CMD_REMOVE, {nex.tag}, 0)
                                    end
                                    GiveOrderToUnit(id, CMD_REMOVE, {curTag}, 0)
                                end
                            end
                        end
                    end

                end
            end
        end
        -- if not applied then
        --     Echo('debug SB, want cloak but no com detected ?', os.clock())
        -- end
    end
end

function widget:CommandsChanged()
    local sel = spGetSelectedUnits()
    selBuilders={}
    gotBuilders = false
    local n = 0
    for i=1,#sel do
        local id = sel[i]
        if builders[id] then 
            builders[id].lastCommand=nil
            gotBuilders = true
            selBuilders[id] = builders[id]
        end
    end
end
--------------------------------------------------------------------------------------

function widget:KeyPress(key,m) -- note: mods always appear in the order alt,ctrl,shift,meta when iterated  -- we can simulate the same by traversing the table {alt=true,ctrl=true,meta=true,shift=true}
    -- if Debug.CheckKeys(key,m) then
    --     return true
    -- end

end
local relevantCmd = setmetatable(
    {
        [CMD_RECLAIM] = true,
        [CMD_REPAIR] = true,
    },
    {
        __index = function(self,k)
            return k and k < 0
        end
    }
)
local function IsNewAction(b,cmd,params)
    if b.cmd then
        if b.cmd == cmd and b.params[1] == params[1] then
            Debug.prevision('the order is the same',b.cmd,b.params[1])
            return false
        end
    end
    if b.maincmd then
        if b.maincmd == cmd and b.mainparams[1] == params[1] then
            Debug.prevision(b.sign .. 'the main order is the same',b.maincmd,b.mainparams[1])
            return false
        end
    end
    return true
end



local UpdateAction = function(b,cmd,params)
    params = params or EMPTY_TABLE
    if b.cmd == cmd and b.params[1] == params[1] then
        Debug.prevision(b.sign .. 'the action has already been registered in the Update process, it is just confirmed in NotifyExecute')
        -- the action has already been registered in the Update process, it is just confirmed in NotifyExecute
        return b.action, false
    end
    b.cmd, b.params = cmd, params
    if not (b.action or relevantCmd[cmd]) then
        Debug.prevision(b.sign .. 'no relevant cmd, no current action, nothing to do')
        -- no relevant cmd, no current action, nothing to do
        return false, false
    end
    local eChange, mChange = 0, 0
    local action = false

    if b.action then
        -- removing the current action and retaining that change on eco
        featReclaimed[b.rec or 0] = nil
        eChange   = - ENERGY_BALANCE[b.action] - ENERGY_BALANCE[b.recE]
        mChange   = - METAL_BALANCE[b.action] - METAL_BALANCE[b.recM]
        -- Echo('before change',"b.action,b.recE,b.recM is ", b.action,b.recE,b.recM,'eChange',eChange,'mChange',mChange)
        b.rec, b.recM, b.recE =  false, false, false
    end

    if cmd == CMD_RECLAIM then
        if not params[2] or params[5]  then  -- when giving FIGHT command and unit goes on a target, it happens 5 params, the first being the target, and 4 other that define an area
            action = 'reclaiming'
            local fm,_,fe
            if params[1]>maxUnits then
                local featureID = params[1]-maxUnits
                if spValidFeatureID(featureID) then
                    fm,_,fe  = GetFeatureResources(featureID)
                    b.recE = fe>0.001
                    b.recM = fm>0.001
                    b.rec = featureID
                    featReclaimed[b.rec] = true
                end
            else
                b.recM = true
            end
        end
        --Echo("Order:",Units[bID].name,"=>",res.mExtra, "frame", frame)
    elseif cmd == CMD_REPAIR then        
        if not params[2] or params[5] then
            local tgt = Units[params[1]]
            if tgt then
                if tgt.isGtBuilt or tgt.defID == terraunitDefID then
                    action = 'building'
                else
                    action = 'repairing'
                end
            end
        end
    elseif cmd and cmd<0 then
        action = 'building'
    end

    if action then 
        -- action updated, add the eco change of it
        eChange = eChange + ENERGY_BALANCE[action] + ENERGY_BALANCE[b.recE]
        mChange = mChange + METAL_BALANCE[action] + METAL_BALANCE[b.recM]
        -- Echo('after change',"b.action,b.recE,b.recM is ", b.action,b.recE,b.recM,'eChange',eChange,'mChange',mChange)
    end
    -- update the eco
    -- Echo("eChange,mChange is ", eChange,mChange)
    if eChange ~= 0 then
        res.eExtra = res.eExtra + eChange * b.buildSpeed
        res.wantE = res.eMax==0 and -res.eExtra or res.eMax - (max(res.eCur,res.E_reserve) + res.eExtra)
        if res.wantE<res.eMax*0.01 then res.wantE=0 end
        res.needE = res.E_reserve - res.eCur - res.eExtra
        OrderDraw('balance',Debug.showBalance() and 'E')
    end
    if mChange ~= 0 then
        res.mExtra = res.mExtra + mChange * b.buildSpeed
        res.wantM = res.mMax==0 and -res.mExtra or res.mMax - (max(res.mCur,res.M_reserve) + res.mExtra)
        if res.wantM<res.mMax*0.01 then res.wantM=0 end
        res.needM = res.M_reserve - res.mCur - res.mExtra
        OrderDraw('balance',Debug.showBalance() and 'M')
    end

    b.action = action

    return action, true
end

local function PutOnListening(b)
    b.currentAction = 'listening'
    b.tag = tagConv[b.currentAction]
    -- b.maincmd, b.mainparams = false, EMPTY_TABLE
    local actBefore, eBefore, mBefore = b.action, res.eExtra, res.mExtra
    local newaction = UpdateAction(b,false)
    if Debug.prevision() and newaction then
        Echo(
            b.sign .. 
            'cmd: '.. tostring(unit.cmd),'(realcmd: ' .. tostring(unit.realcmd) .. ')'
            ,'action: ' .. tostring(actBefore) .. ' => ' .. tostring(newaction)
            ,'M '.. round(mBefore,1) .. ' => ' .. round(res.mExtra,1)
            ,'E ' .. round(eBefore,1) .. ' => ' .. round(res.eExtra,1)
            ,'needM '.. round(needMBefore,1) .. ' => ' .. round(res.needM,1)
            ,'needE ' .. round(needEBefore,1) .. ' => ' .. round(res.needE,1)
        )
    end
    return newaction
end
local function ResetUnit(id,unit)
    local b = builders[id]
    if b then
        local debugPos = Debug.pos()
        -- UpdateOrder(id,builders[id],spGetGameFrame())
        local wasManual = b.currentAction == 'manual'
        local newaction = PutOnListening(b)



        b.maincmd, b.mainparams = false, false
        if b.canMove and wasManual --[[and b.currentAction == 'listening'--]] then
            b.posX,b.posY,b.posZ = GetUnitPos(id,3)
            -- b.posX,b.posY,b.posZ = unpack(Units[id].pos)
            OrderDraw('pos',b.id,debugPos and {b.posX,b.posY,b.posZ})
        end


        waiting[id]=b
        -- if trackedUnits[id] then
        --     trackedUnits[id].text = trackedUnits[id].text:gsub('\nAUTO','')
        -- end
        -- b.auto=false
    end

end
function NotifyIdle(id,unit)
    local b = builders[id]
    if not b then
        return
    end
    b.isIdle = true
    if Debug.sequence() then
        -- Echo('unit idle put in waiting')
        Echo('unit idle, Updating order')
    end
    b.idleTime = spGetGameSeconds()
    b.fightingOrder = false
    b.isFighting = false
    b:UpdateRoam()
    ResetUnit(id,unit)
end

function NotifyExecute(unit,id,cmd,params,opts,tag,fromCmdDone,fromLua,realcmd,realparams,realopts,realtag,maincmd,mainparams)
    local b = builders[id]
    if not b then
        return
    end
    b.isIdle = false
    -- Echo("cmd,realcmd,maincmd,unit.isFighting is ", cmd,realcmd,maincmd,unit.isFighting)
    if unit.autoguard then
        b.currentAction = 'manual'
        b.tag = tagConv[b.currentAction]
        -- local queue = Spring.GetCommandQueue(id,-1)
        -- if queue[2] and queue[2].id == CMD.GUARD then
        --     GiveOrderToUnit(id,CMD.REMOVE,{queue[2].tag},0)
        -- end
    end
    local wasManual = b.currentAction == 'manual'
    local isOwn = IsOwnOrder(realopts.coded)
    -- Echo(b.sign .. '[notify execute]: cmd-realcmd', cmd,unit.realcmd,
    --     unit.manual and 'manual' or isOwn and 'Own order' or 'not manual','opt',realopts.coded,
    --     -- 'autoguard',unit.autoguard,
    --     'unit.isFighting:' .. tostring(unit.isFighting)
    -- )
    if debugMe then
        Debug.Log(b.sign .. '[notify execute]: cmd-realcmd', cmd,unit.realcmd, unit.manual and 'manual' or 'not manual')
    end
    if Debug.prevision() then
        Echo(b.sign .. '[execute]: cmd', cmd, 'maincmd',maincmd,'params[1]',params[1], unit.manual and 'manual' or 'not manual')
    end
    if cmd==CMD_RAW_BUILD then
        cmd,params = maincmd, mainparams
    end
        


    if isOwn and cmd == CMD_GUARD or not isIOwn and unit.autoguard and cfg.override_autoguard then
        ResetUnit(id,unit)
        -- Echo('our own guard => reset')
        return     
    end



    -- Echo("cmd,params, realcmd, realparams is ", cmd,params, realcmd, realparams)
    -- Echo('res before', 'M ' .. res.mExtra,'E ' .. res.eExtra)
    local actBefore, mBefore, eBefore, needMBefore, needEBefore = b.action, res.mExtra, res.eExtra, res.needM, res.needE
    local newaction = UpdateAction(b,cmd,params)
    b.maincmd, b.mainparams = maincmd, mainparams
    if Debug.sequence() then
        Echo('notify',cmd,'real:',realcmd,'currentAction',b.currentAction,'unit.manual:',unit.manual,'b.action',b.action)
    end
    -- Echo('notify',cmd,'real:',realcmd,'opts.coded',opts.coded,'currentAction',b.currentAction,'unit.manual:',unit.manual,'b.action',b.action,'own:',IsOwnOrder(realopts.coded),realopts.coded,'realtag',realtag)
    -- b.isFighting is a pseudo fighting state when Fight order is replaced by a move order of our own
    if not isOwn then
        b.fightingOrder = false
        b.isFighting = false
        -- Echo('not own, b.isFighting is now false')
    end
    if realcmd == CMD_RAW_MOVE and IsOwn then
        b.isFighting = true

    end

    -- check if unit can roam and update its range
    b:UpdateRoam()
    if not b.canRoam then
        -- Echo('cant roam, b.isFighting is now false')
        b.isFighting = false
    end
    -- if unit.isFighting and b.canRoam and realcmd~=CMD_FIGHT and  not IsOwnOrder(realopts.coded) then
    --     GiveOrderToUnit(id,CMD_REMOVE,{realtag},SB_INTERNAL)
    -- end
    if unit.isFighting and b.canRoam  then
        -- Echo("b.isFighting is ", b.isFighting)
        b.fightOrder = false
        local tag = b:GetFightingOrder()
        if tag and cfg.replace_fight then
            Debug.roam(b.sign .. 'replace fighting order by raw move')
            local _,_,x,z =  unpack(b.fightingOrder)
            local y = spGetGroundHeight(x,z)
            GiveOrderToUnit(id,CMD_INSERT,{0,CMD_RAW_MOVE,CMD_OPT_SHIFT + SB_INTERNAL,x,y,z},CMD_OPT_ALT + CMD_OPT_SHIFT + SB_INTERNAL)
            GiveOrderToUnit(id,CMD_REMOVE,{tag},0)
            if realcmd~= CMD_FIGHT and tag ~= realtag then
                Debug.roam(b.sign .. 'remove also automatic order from Fight command')
                GiveOrderToUnit(id,CMD_REMOVE,{realtag},0)
            end
            b.isFighting = true
        end
    end
    local debugPos = Debug.pos()

    if wasManual or unit.manual then
        local x,y,z = GetUnitPos(id,3)
        b.posX,b.posY,b.posZ = x,y,z
        OrderDraw('pos',b.id,debugPos and {b.posX,b.posY,b.posZ})
    end
    -- if unit.waitManual and isOwn then
    --     Echo('order should be removed for ',id) -- it seems to be handled, but not sure it is in every case
    -- end
    if unit.manual

        or not isOwn -- work around to detect manual shifted order (other than build) just after an own order removed
        or (unit.isFighting or b.isFighting) and not b.canRoam then
        -- widget don't act upon builder if currentAction == 'manual'
        -- Echo("unit is manual or fighting but builder is not allowed",b.currentAction .. ' => ' .. 'manual')
        b.currentAction = 'manual'
        b.tag = tagConv[b.currentAction]
        b.isFighting = false
    elseif b.action and b.currentAction~='manual' then
        -- Echo('b.action exist and currentAction is not manual',b.currentAction .. ' => ' .. b.action)
        b.currentAction = b.action
        b.tag = tagConv[b.currentAction]
    elseif b.canRoam then
        -- Echo('canRoam, reset unit')
        ResetUnit(id,unit) 
    else
        -- Echo('no response') 
    end
end
local dist = {}
local x,z
local ByDistFeatures = function(a,b)
    if not dist[a] then
        local fx,_,fz = GetFeaturePosition(a)
        dist[a] = ((x-fx)^2 + (z-fz)^2) ^ 0.5
    end
    if not dist[b] then
        local fx,_,fz = GetFeaturePosition(b)
        dist[b] = ((x-fx)^2 + (z-fz)^2) ^ 0.5
    end
    return dist[a]<dist[b]
end
local ByDistUnits = function(a,b)
    if not dist[a] then
        local ux,_,uz = spGetUnitPosition(a)
        dist[a] = ((x-ux)^2 + (z-uz)^2) ^ 0.5
    end
    if not dist[b] then
        local ux,_,uz = spGetUnitPosition(b)
        dist[b] = ((x-ux)^2 + (z-uz)^2) ^ 0.5
    end
    return dist[a]<dist[b]
end

-- local checkpass = f.CheckTime('set')
local function UpdateOrder(bID,b,frame)
    -- update the commandedManually property or return
    local unit = Units[bID]
    if unit and unit.waitManual then
        return
    end
    -- if b.commandedManually then
    --     if os.clock() - b.commandedManually > 0.8 then
    --         if Debug.sequence() then
    --             Echo('Update Order skip commandedManually and proceed normally bc of time out')
    --         end
    --         b.commandedManually = false
    --     else
    --         if Debug.sequence() then
    --             Echo('Update Order cancelled due to manual command')
    --         end
    --         return
    --     end
    -- end
    -- Echo("unit is ", unit)
    -- if unit then
    --     Echo("unit.manual,unit.waitManual is ", unit.manual,unit.waitManual)
    -- end
    --

    -- checkpass('average')
    ------------------------------
    ----- Correcting currentAction
    ------------------------------
    local cmdID,opt,tag,curID =  spGetUnitCurrentCommand(bID)
    local currentAction = b.currentAction
    b:UpdateRoam()
    local range = b.range
    local isFighting = b.isFighting or unit.isFighting

    b.treated = frame
    local gameTime = spGetGameSeconds()

    if Debug.sequence() then
        Echo('Update Order, current action:',currentAction,'cmdID',cmdID,'manual ? ',Units[bID].manual)
    end
    if b.toRemoveOrder then
        local queue = spGetCommandQueue(bID,-1)
        for i,order in ipairs(queue) do
            if order.id~=CMD_RAW_BUILD and IsOwnOrder(order.options.coded) then
                GiveOrderToUnit(bID, CMD_REMOVE, {order.tag}, SB_INTERNAL)
                if Debug.sequence() then
                    Echo('removing useless auto order',order.tag)
                end
            end
        end
        -- b.currentAction = 'manual'
        b.toRemoveOrder = false
    end
    if b.currentAction == 'repairing' then
        local order = spGetCommandQueue(bID,1)[1]
        if order and order.id == CMD_REPAIR and not order.params[2] then
            local tgtID = order.params[1]
            local tgtX,_,tgtZ = spGetUnitPosition(tgtID)
            if tgtX then
                local dist = ( (b.posX-tgtX)^2 + (b.posZ-tgtZ)^2) ^0.5
                if dist > range then
                    spGiveOrderToUnit(bID, CMD_REMOVE,{order.tag}, SB_INTERNAL)
                    PutOnListening(b)
                end
            else
                PutOnListening(b)
            end
        end

    end
    -- local isCloaked = spGetUnitIsCloaked(bID)

    if b.currentAction == 'manual' then
        return
    end
    if b.wantCloak then
        return false
    end
    -- if not b.sign:match('Engineer') then
    --     Count = (Count or 0) + 1
    --     Echo(b.sign .. ' update order #' .. Count)
    -- end
    -- if spGetUnitIsCloaked(bID) and not (isFighting and b.canRoam) then
    --     return
    -- end
    if not b:CheckSmartConjurer() then
        -- Echo(b.humanName,'not allowed')
        return false
    end

    if b.fightingOrder and b.fightingOrder.uptime<gameTime then
        b.fightingOrder.uptime = gameTime + 1.5
        local x,y,z = GetUnitPos(bID, 5)
        local s1,s2,e1,e2 = unpack(b.fightingOrder)
        local posX,posZ = FindIntersect(x,z,s1,s2,e1,e2)
        b.posX, b.posY, b.posZ = posX, spGetGroundHeight(posX,posZ), posZ
        local debugPos = Debug.pos()
        if debugPos then
            OrderDraw('pos','p',{x,y,z})
            OrderDraw('pos','_s',{s1,spGetGroundHeight(s1,s2),s2})
            OrderDraw('pos','__e',{e1,spGetGroundHeight(e1,e2),e2})
            OrderDraw('pos',b.id,{b.posX,b.posY,b.posZ})
        end
    end

    ---------------------------------------------------------------------------------------------
    ----------------------- ORDERING Part -------------------------------------------------------
    ---------------------------------------------------------------------------------------------


    --Echo("res.mExtra is ", res.mExtra)

    --if b.canMove --[[and b.currentAction == 'listening'--]] then b.posX,b.posY,b.posZ = spGetUnitPosition(bID) end


    --Echo("nearUnits of Caretaker #", bID, "=>", nearUnits[1], ":", Name(nearUnits[1]), nearUnits[2], ":", Name(nearUnits[2]))
    --local minM,minE = -b.buildSpeed,-b.buildSpeed + (res.eMax>0 and res.E_reserve or 0)
    local bestFeature,recM,recE,debugFeature = false,false,false,false

    if res.wantM > b.buildSpeed/2 or res.wantE > b.buildSpeed/2 then
        bestFeature, recM, recE = CheckFeatures(b, res.wantM, res.wantE,res.needM > b.buildSpeed/2, res.needE > b.buildSpeed/2)
    --[[            if not res.needM and res.wantM and recM then minM = 0                               ; res.needM = res.mCur+res.mExtra<minM end
            if not res.needE and res.wantE and recE then minE = 0  + (res.eMax>0 and res.E_reserve or 0); res.needE = res.eCur+res.eExtra<minE end--]]
    end

    local mChange,eChange
    local canRepair = res.needE <= b.buildSpeed/2
    local canBuild  = res.needM <= b.buildSpeed/2 and canRepair

    --Echo("eChange is ", res.eCur+res.eExtra + b.buildSpeed * eChange - (res.eMax>0 and res.E_reserve or 0))
    --Echo(Units[bID].name,"canBuild", canBuild,"=>>",res.mExtra, mChange)
    if not canRepair and currentAction=="repairing" then
    --[[            res.eExtra=res.eExtra+eChange
            Stop(bID)
            currentAction='listening'--]]
    end
    if not canBuild and currentAction=="building" then
    --[[            res.mExtra=res.mExtra+mChange
            Stop(bID)
            currentAction='listening'--]]
    end
    ------------------------- best Unit to build/repair/reclaim ----------------------------------
    local Prio1, Prio2, Prio3

    local debugPrio
    local SpecialReclaim
    local AttackReclaim


    local nearUnits = GetUnitsInCylinder(b.posX,b.posZ,range)
    local EfeaturesCount = 0
    local recM,recE = false,false
    if b.extraRange>0 then
        dist = {}
        x,z = b.posX, b.posZ
        table.sort(nearUnits,ByDistUnits) -- the dist table is auto emptied after the sorting, don't ask me why
    end
    if nearUnits[2] then
        local buildSpeed = b.buildSpeed
        
        local Cheapest = false
        local MostDamaged = false
        local MostDamagedDefense = false
        local SoonDead = false
        local LeastPercent = false
        local CheapStruct = false
        local CheapUnit = false
        local Mex = false
        local Wind = false
        local Solar = false
        local Fusion = false
        local DmgedComm = false
        local Rworthy = false
        local Bworthy = false
        local Caretaker = false
        local Storage = false
        local mostInvested = false
        local MostCritical = false
        local Reclaim = bestFeature
        local isE = false
        local MostDamagedAllied = false
        local FinishIt = false
        local Faster= false

        local somethingToBuild = false

        for i,id in pairs(nearUnits) do
            local n=Units[id]
            if n and n.isInSight--[[(spValidUnitID(id) and n) and not spGetUnitIsDead(id)--]] then
                -- Echo("n.isEnemy,n.isGtBuilt is ", id,n.isEnemy,n.isGtBuilt)
                local HP, maxHP, buildP = n.health[1], n.health[2], n.health[5]
                if n.isEnemy then
                    AttackReclaim = buildP<1--[[n.isGtBuilt--]] and id or AttackReclaim
                elseif (n.isAllied or n.isMine) and not (bID == id or n.isDrone) then -- and spGetUnitHealth(id) and  (n.isGtBuilt or spGetUnitHealth(id) < (select(2, spGetUnitHealth(id))))
                    -- HP, _,_ ,_ ,buildP    = spGetUnitHealth(id)
                    if HP==maxHP and buildP>=1 then
                        n.dmgFrame = false
                        n.frame = frame
                    else --if canBuild == n.isGtBuilt or canRepair and not n.isGtBuilt or n.isGtReclaimed then




                        --Echo(Units[bID].name,"is reChecking",id,Name(id))
                        
                        --Echo("buildP is ", buildP)
                        --Echo("bID is ", Units[bID].name,'frame',(frame-n.frame))
                        -- if not thisRound[n] then
                            thisRound[n] = true
                        --if (frame-n.frame)>29 or not n.started then
                            -- register builders around unit to evaluate buildTime
                            if buildP<1 then
                                -- Build Time Estimation if all builders work on unit n
                                -- registering the total build potential we can get with all builders in reach
                                local buildPotential = n.buildPotential
                                if not n.builders then 
                                    n.builders={[bID]=true}
                                    buildPotential = b.buildSpeed
                                elseif not n.builders[bID] then
                                    n.builders[bID]=true
                                    buildPotential = buildPotential+b.buildSpeed
                                end
                                n.buildPotential = buildPotential
                                --
                                if not n.buildTime or frame>n.builders.frame+29 then
                                    n.builders.frame = frame

                                    n.minBuildTime = n.cost/buildPotential
                                    local buildPotential = min(res.buildCap,buildPotential)

                                    local rembuild = (n.cost*(1-buildP))

                                    -- res.buildCap the maximum possible expense
                                    local timeToDeplete = res.buildCap/buildPotential
                                    timeToDeplete = timeToDeplete==1 and 0 or timeToDeplete

                                    local maxSpeedCapacity = timeToDeplete>0 and res.buildCap + timeToDeplete*res.buildTick or 0
                                    n.canBuildAtMaxSpeed = maxSpeedCapacity>0
                                    n.buildTime =  maxSpeedCapacity==0 and rembuild/res.buildTick
                                                or rembuild<maxSpeedCapacity and rembuild/buildPotential
                                                or maxSpeedCapacity/buildPotential + (rembuild-maxSpeedCapacity)/res.buildTick
                                    n.bworth    = n.cost/n.buildTime
                                    if n.isAllied then n.bworth=n.bworth*0.7 end
                                    -- n.bworth    = nround(n.bworth,0.001) * 1.000
                                    n.bworth       = n.bworth*1000
                                end
                            elseif n.buildTime then
                                n.builders,n.buildTime,n.bworth = nil,nil,nil
                            end
                            --

                            --if n.bworth then Echo(n.name..':'..tostring(n.bworth)) end
                            
                            n.started                 = true
                            n.frame                   = frame
                            n.TrueHP                  = HP
                            HP                      = n.isAllied and HP*1.30 or HP
                            n.invested                = n.cost * buildP

                            -- n.worth                   = nround(n.invested / maxHP,0.001) -- 
                            n.worth                   = n.invested / maxHP
                            if n.isAllied and res.OverMetal then
                                n.worth = n.worth*0.3
                            end
                            
                            n.remb                    = round(n.cost - n.invested)
                           --Echo("Check", Name(id), id)
                            n.perHP                   = HP / maxHP
                            n.truePerHP               = n.TrueHP / maxHP
                            n.dmgPer                  = buildP - n.perHP
                            n.isDamaged               = n.truePerHP < buildP
                            -- n.isDamaged               = nround(n.truePerHP,0.001) < nround(buildP,0.001)
                            if n.isDamaged then -- determining net percent loss hp per sec
                                if not n.dmgFrame then n.dmgFrame = n.frame end
                                local newtime         = round(n.frame-n.dmgFrame)/30 -- not needed if we keep a main update rate for the whole thing
                                if n.attack_time~=newtime then
                                    n.attack_time     = newtime>2 and 2 or newtime
                                    n.hpDelta         = n.lastState and n.lastState-n.dmgPer or n.dmgPer
                                    n.lastHit         = (not n.lastHit or n.hpDelta<0)  and n.hpDelta or n.lastHit
                                    n.dmgRate         = n.dmgPer/(n.attack_time+1) -- average of loss per sec within the last 3 secs
                                    n.critical        = n.dmgRate/n.perHP -- proportion of the loss per sec to the remaining hp
                                    if n.isComm then n.critical=n.critical*1.3 end
                                    if n.isAllied then n.critical=n.critical*0.7 end
                                    -- n.critical        = nround(n.critical,0.001)
                                    n.lastState       = n.dmgPer
                                end
                            else
                                n.hpDelta,n.dmgRate,n.critical,   n.lastHit,n.attack_time,n.lastState = 0,0,false, false,false,false
                            end

                            n.dmg                     = n.dmgPer*maxHP
                            n.dmg                     = n.isAllied and n.dmg*0.6 or n.dmg
                            n.dmgCost                 = n.cost * n.dmgPer
                            n.TrueDamage              = n.dmg
                            -- n.rworth                  = n.isDamaged and nround(n.invested / HP / n.perHP, 0.001)
                            -- repair worth, how much metal cost per hp, mult by how much it is damaged
                            n.rworth                  = n.isDamaged and (n.invested / HP / n.perHP )
                            -- Echo(n.name,"n.invested, HP, n.perHP is ", n.invested, HP, n.perHP ,'=>>',n.rworth)

          --Echo(Name(id),"rworth:", n.rworth)

                            n.isBurning               = spGetUnitRulesParam(id, "on_fire") == 1
                            n.isHopeless              = n.isBurning and n.cost<90 and n.TrueHP<150
                        --end
                        -- end
                            LeastPercent              = n.perHP < 1 and                   (not LeastPercent  or   n.perHP < Units[LeastPercent].perHP  ) and id or LeastPercent
                            if n.isDamaged and not n.isGtReclaimed and not n.isHopeless then
                                MostDamaged        = n.isDamaged and                                       (not MostDamaged   or   n.dmgPer    > Units[MostDamaged].dmgPer      ) and id or MostDamaged
                                MostDamagedDefense = n.isDefense and n.isDamaged and                       (not MostDamaged   or   n.dmgPer    > Units[MostDamaged].dmgPer      ) and id or MostDamagedDefense
                                DmgedComm          = n.isComm and                                          (not DmgedComm     or   HP        < Units[DmgedComm].health[1]            ) and id or DmgedComm
                                Rworthy            = n.rworth and                                          (not Rworthy       or   n.rworth    > Units[Rworthy].rworth          ) and id or Rworthy
                                MostCritical       = n.critical and (n.critical>0) and                     (not MostCritical  or   n.critical  > Units[MostCritical].critical   ) and id or MostCritical

                            elseif n.ReallyDamaged then
                                ReallyDamaged = n.dmg>1 and not n.isHopeless  and (not ReallyDamaged or   n.TrueDamage   > Units[ReallyDamaged].TrueDamage) and id or ReallyDamaged
                            end

                        if not n.isAllied then
                            if n.isGtBuilt  and not n.isGtReclaimed and not n.isEnemy
                                and (n.defID ~= terraunitDefID or buildP>0.01) -- ignoring terraunit not started to be built yet
                                then 
                                somethingToBuild = true
                                FinishIt      = n.buildTime and n.buildTime<3
                                 and n.cost>200
                                 and (not FinishIt
                                       or   n.buildTime < (Units[FinishIt].buildTime or 100000)        )
                                 and id or FinishIt
                                Mex           = n.isMex           and (not Mex           or   n.remb         < Units[Mex].remb         ) and id or Mex
                                Cheapest      =                       (not Cheapest      or   n.remb         < Units[Cheapest].remb    ) and id or Cheapest
                                CheapStruct   = n.isStructure     and (not CheapStruct   or   n.remb         < Units[CheapStruct].remb ) and id or CheapStruct
                                CheapUnit     = n.isUnit          and (not CheapUnit     or   n.remb         < Units[CheapUnit].remb   ) and id or CheapUnit
                                Bworthy       = n.bworth          and (not Bworthy       or   n.bworth       > Units[Bworthy].bworth   ) and id or Bworthy
                                Faster        = n.buildTime       and (not Faster        or   n.buildTime    < Units[Faster].buildTime ) and id or Faster
                                if not eStalling and not mStalling then
                                    Caretaker     = n.isCaretaker     and (not Caretaker     or   n.remb < Units[Caretaker].remb  ) and id or Caretaker
                                end
                            end
                            if n.remb>0 then
                                Wind          = n.isWind          and (not Wind          or   n.remb < Units[Wind].remb       ) and id or Wind
                                Solar         = n.isSolar         and (not Solar         or   n.remb < Units[Solar].remb      ) and id or Solar
                                Fusion        = n.isFusion        and (not Fusion        or   n.remb < Units[Fusion].remb     ) and id or Fusion
                                if res.wantM==0 or res.needStorage then
                                     Storage       = n.isStorage     and (not Storage         or   n.remb < Units[Storage].remb  ) and id or Storage
                                end
                            end
                        -- else
                            -- MostDamagedAllied        = n.isDamaged and                                       (not MostDamagedAllied   or   n.dmgPer    > Units[MostDamagedAllied].dmgPer      ) and id or MostDamagedAllied
                        end

                    end
                    SpecialReclaim  = SpecialReclaim or n.isGtReclaimed and n.isMine and id
                    --Echo("Units[SpecialReclaim].name is ",SpecialReclaim and  Units[SpecialReclaim].name)
                end
            end
        end -- loop end nearunits
        --Echo("Units[Bworthy].remb is ", BWorthy and  Units[Bworthy].remb)

        local debug = Debug.prio()

        local spEcho, Echo = Echo, Echo
        if debug then

            debug = function(prioNum,comment,id,extraK)
                extraK = (extraK and ', ' .. extraK .. ': ' .. Units[id][extraK] or '')
                debugPrio = '[' .. b.sign  .. ']:Prio' .. prioNum .. ':' .. comment .. ': ' .. id .. ', ' .. Name(id) .. extraK
                -- Echo(debugStr)
                return true
            end
        else
            debug = function() return true end
        end
        --Debug=true

        Prio1   = 
              Storage and res.needStorage and                                                                               debug(1, 'Storage',             Storage                     )   and Storage
              or  DmgedComm and Units[DmgedComm].perHP<0.3 and DmgedComm and                                                debug(1, 'High DmgedComm',      DmgedComm                   )  and DmgedComm
              or  FinishIt and                                                                                              debug(1, 'FinishIt',            FinishIt, 'buildTime'       )   and FinishIt
              -- or not canRepair and (Wind or Solar or Fusion) and                                                 debug(1, 'Energy',              (Wind or Solar or Fusion)   )   and (Wind or Solar or Fusion)      
              or MostCritical and Units[MostCritical].critical>0.25 and ( not (res.OverMetal and somethingToBuild) or Units[MostCritical].rworth>1.5)  and    debug(1,'MostCritical>0.25',MostCritical,'critical')    and MostCritical

              or Mex and                                                                                                    debug(1, 'Mex',                 Mex                         )   and (Mex)      
              or res.needE and (Wind or Solar or Fusion and Faster==Fusion) and                                                 debug(1, 'Energy',              (Wind or Solar or Fusion)   )   and (Wind or Solar or Fusion)      
              -- or (Caretaker or Storage) and (res.OverMetal or res.OverEnergy) and                                           debug(1, 'CareTaker/Storage',   (Caretaker or Storage)      )   and (Caretaker or Storage) 
              or (Storage) and (res.OverMetal or res.OverEnergy) and                                           debug(1, 'Storage',   (Storage)      )   and (Storage) 
              or (Caretaker) and (res.wantM<res.mMax*0.8 and res.wantE<res.eMax*0.8) and                                           debug(1, 'CareTaker',   (Caretaker)      )   and (Caretaker) 


          --[[        or  LeastPercent and Units[LeastPercent].perHP<0.25 and LeastPercent and                                debug(":Prio1: Percent<25", LeastPercent, Name(LeastPercent))                                                                          and LeastPercent
              or  Bworthy and Units[Bworthy].bworth>200 and                                                              debug(":Prio1: Bworthy>0.200", Bworthy, Name(Bworthy), "Bworth:",Units[Bworthy].bworth)                                                 and Bworthy
              or  res.Mstalling and Mex and                                                                                   debug(":Prio1: Mex", Mex, Name(Mex))                                                                                                   and Mex
              or  res.Estalling and Wind and                                                                                  debug(":Prio1: Wind", Wind, Name(Wind))                                                                                                and Wind
              or  res.Estalling and Fusion and Units[Fusion].remb  < 400 and                                              debug(":Prio1: Fusion", Fusion, Name(Fusion))                                                                                          and Fusion
              or  res.Estalling and Solar and                                                                                 debug(":Prio1: Solar", Solar, Name(Solar))                                                                                             and Solar
              or  MostDamaged and Units[MostDamaged].HP<400 and Units[MostDamaged].cost> 500 and                          debug(":Prio1: MostDamaged", MostDamaged, Name(MostDamaged))                                                                           and MostDamaged
              or  not res.OverMetal and SpecialReclaim and                                                                    debug(":Prio1: SpecialReclaim", SpecialReclaim, Name(SpecialReclaim))                                                                  and SpecialReclaim
              or  Caretaker and                                                                                           debug(":Prio1: Caretaker", Caretaker, Name(Caretaker))                                       and Caretaker

              or  CheapUnit and Units[CheapUnit].remb  < 100 and Units[CheapUnit].cost>400  and                       debug(":Prio1: CheapUnit", CheapUnit, Name(CheapUnit))                                       and CheapUnit

              or  CheapStruct and Units[CheapStruct].remb  < 200 and Units[CheapStruct].cost > 400 and                debug(":Prio1: CheapStruct 200<rembuild<400", CheapStruct, Name(CheapStruct))              and CheapStruct
              or  CheapStruct and Units[CheapStruct].remb  < 300 and                                                  debug(":Prio1: CheapStruct rembuild<300", CheapStruct, Name(CheapStruct))                  and CheapStruct 
          --]]

        if not Prio1 then
            -- Echo("Units[Bworthy].bworth is ",Units[Bworthy] and  Units[Bworthy].bworth)
            Prio2 = 
              --  MostDamaged and                                                                                         debug(":Prio2: MostDamaged", MostDamaged, Name(MostDamaged))                                                                          and MostDamaged
                  MostCritical and Units[MostCritical].critical>0.2  and not (res.OverMetal and somethingToBuild)  and      debug(2, 'MostCritical',    MostCritical,           'critical'  )   and MostCritical
              or  Faster and Units[Faster].buildTime<5 and                                                                  debug(2, 'Faster',          Faster,                 'buildTime' )   and Faster
              or (Mex or Wind or Solar) and                                                                                 debug(2, 'Energy/Mex',      (Mex or Wind or Solar)              )   and (Mex or Wind or Solar)                                                                                   
              or  MostCritical and Units[MostCritical].critical>0.1  and not (res.OverMetal and somethingToBuild)  and      debug(2, 'MostCritical',    MostCritical,           'critical'  )   and MostCritical

              or  Bworthy and Units[Bworthy].bworth>20 and                                                                  debug(2, 'Bworthy',         Bworthy,                'bworth'    )   and Bworthy
              or  MostCritical and Units[MostCritical].critical>0.1 and                                                     debug(2, 'MostCritical',    MostCritical,           'critical'  )   and MostCritical
              --or  not bestFeature and rand(1)<0.5 and MostCritical and                                                                                      debug(":Prio2: MostCritical", Name(MostCritical), Units[MostCritical].critical)                                                                      and MostCritical
              or  Bworthy and                                                                                               debug(2, 'Bworthy',         Bworthy,                'bworth'    )   and Bworthy
              -- or  (not bestFeature or rand(0,1)==1) and Rworthy and                                                         debug(2, 'Rworthy',         Rworthy,                'rworth'    )   and Rworthy
              or  Rworthy and Units[Rworthy].rworth>1.8 and                                                                   debug(2, 'Rworthy',         Rworthy,                'rworth'    )   and Rworthy
              --[[
              or  Cheapest and Units[Cheapest].remb<200  and                                                                debug(":Prio2: Cheapest<200", Units[Cheapest].remb, Name(Cheapest))                                          and Cheapest
              or  SpecialReclaim and                                                                                      debug(":Prio2: SpecialReclaim", SpecialReclaim, Name(SpecialReclaim))                                                                 and SpecialReclaim
              or  Cheapest and Units[Cheapest].remb<400 and                                                                debug(":Prio2: Cheapest<400", Units[Cheapest].remb, Name(Cheapest))                                          and Cheapest

              or  res.needE<=0 and mostDamagedAllied and                                                                                        debug(":Prio2: mostDamagedAllied", Units[mostDamagedAllied].critical, Name(mostDamagedAllied))                                                                      and mostDamagedAllied
              or  res.needM<=0 and Cheapest and                                                                                            debug(":Prio2: Cheapest", Units[Cheapest].remb, Name(Cheapest))                                          and Cheapest
              or  AttackReclaim and                                                                                       debug(":Prio2: AttackReclaim", AttackReclaim, Name(AttackReclaim))                                                                    and AttackReclaim
              or  LeastPercent and Units[LeastPercent].perHP<0.50 and LeastPercent and                                debug(":Prio2: Percent<40", LeastPercent, Name(LeastPercent))                                                                         and LeastPercent
              or  MostDamaged and Units[MostDamaged].HP/Units[MostDamaged].BuildP<400 and Units[MostDamaged].cost>220 and debug(":Prio2: High MostDamaged", MostDamaged, Name(MostDamaged))                                                                     and MostDamaged
              or  Bworthy and Units[Bworthy].worth>0.3 and                                                               debug(":Prio2: Bworthy>0.30", Bworthy, Name(Bworthy), "Bworth:",Units[Bworthy].worth)                                                and Bworthy
              or  Cheapest and                                                                                            debug(":Prio2: Cheapest", Cheapest, Name(Cheapest))                                          and Cheapest
              or  DmgedComm and Units[DmgedComm].HP<2000 and not res.OverMetal and                                            debug(":Prio2: DmgedComm", DmgedComm, Name(DmgedComm))                                                                                and DmgedComm
              or  CheapStruct and Units[CheapStruct].remb <100 and                                                    debug(":Prio2: High CheapStruct", CheapStruct, Name(CheapStruct))                         and CheapStruct
              or  CheapUnit and Units[CheapUnit].remb < 100 and Units[CheapUnit].cost > 200 and                       debug(":Prio2: CheapUnit", CheapUnit, Name(CheapUnit))                                      and CheapUnit
              or  CheapStruct and                                                                                         debug(":Prio2: CheapStruct", CheapStruct, Name(CheapStruct))                              and CheapStruct
              or  MostDamaged and                                                                                         debug(":Prio2: MostDamaged", MostDamaged, Name(MostDamaged))                                                                          and MostDamaged
          --]]         
              -- or  ReallyDamaged and                                                                                       debug(2, 'ReallyDamaged', ReallyDamaged                           )   and ReallyDamaged
          --or  Cheapest and                                                                                            debug(":Prio2: Cheapest", Cheapest, Name(Cheapest))                                          and Cheapest

        else 
            Prio2 = nil
        end
        if not (Prio1 or Prio2 or bestFeature) then
            Prio3 = canRepair and Rworthy
        else
            Prio3 = nil
        end
    end -- END NEARUNITS SCAN


    local new_target = Prio1 or Prio2 or Prio3
    --Echo(" is ", Prio1 and 1 or prio2 and 2)
    -- if new_target then
    --     Echo("Units[new_target].name is ", Units[new_target].name)
    -- end
    local wantedAction = (not Units[new_target] or (new_target==SpecialReclaim or new_target==AttackReclaim)) and 'listening'
                         or Units[new_target].isGtBuilt and "building"
                         or "repairing"

    if bestFeature and b.action == 'reclaiming' and (wantedAction == 'building' or wantedAction=='repairing') then
        -- check if we can afford the change
        mChange   = - METAL_BALANCE[b.action] - METAL_BALANCE[b.recM] + METAL_BALANCE[wantedAction]
        eChange   = - ENERGY_BALANCE[b.action] - ENERGY_BALANCE[b.recE] + ENERGY_BALANCE[wantedAction]
        local resultM = res.needM - mChange * b.buildSpeed
        local resultE = res.needE - eChange * b.buildSpeed
        -- cancelling build if we cannot afford it and there is reclaim to take
        -- unless the build is Energy and we need it
        if resultM > b.buildSpeed/2 or resultE > b.buildSpeed/2  then
            Prio2, Prio3, newtarget = nil,nil,nil
            if Debug.prevision() then
                Echo(b.sign .. wantedAction .. ' cancelled', 'needM: ' .. res.needM .. ' => ' .. resultM, 'needE: ' .. res.needE .. ' => ' .. resultE)
            end
        end
        -- Echo("mChange,eChange is ", mChange,eChange)
        -- if resultE>0 or resultM>0 then
        -- Echo("resultE,resultM is ", res.needE .. ' => ' .. resultE,res.needM  .. ' => ' .. resultM)
        -- end
    end


    -- determine if we can afford the change
    local eChange, mChange = 0, 0
    if new_target and new_target==curID and currentAction==wantedAction then
        -- same target
        -- Prio1,Prio2,Prio3,debugPrio, new_target = nil,nil,nil, nil,nil


    elseif wantedAction=="building" or wantedAction=="repairing" then
        
        -- eChange = (ENERGY_BALANCE[wantedAction] - ENERGY_BALANCE[currentAction] - ENERGY_BALANCE[b.recE])
        -- mChange = (METAL_BALANCE[wantedAction]  - METAL_BALANCE[currentAction]  - METAL_BALANCE[b.recM])
        --[[if res.mCur+(res.mExtra + b.buildSpeed * mChange) < -b.buildSpeed
        or res.eCur+(res.eExtra + b.buildSpeed * eChange) < -b.buildSpeed + res.E_reserve
        then
            Echo("we can't afford it",Units[Prio1 or Prio2].name)
            Prio1,Prio2 = nil,nil
        end--]]
    end

    --Echo("cur:"..currentAction, "want:"..wantedAction,"e:"..eChange,"m:"..mChange--[[,ENERGY_BALANCE[wantedAction],ENERGY_BALANCE[currentAction],ENERGY_BALANCE[b.recE]--]])
    --Echo("name is ", new_target and Units[new_target].name)
    ---------------------------------------------------------------------------------------------
    if bestFeature  and (new_target) and ((wantedAction=="building" and canBuild) or (wantedAction=="repairing" and canRepair))  then
        bestFeature, recM, recE, debugFeature = false,false,false, false
        -- not reclaiming metal if we're building Energy and we're stalling on E
        -- if res.needM<=0 and res.needE and not recE and wantedAction=="building" and Units[Prio1 or Prio2].isE then bestFeature,recM,recE = false,false,false end

        -- prevent ordering reclaim of energy if building is wanted and metal is depleted
        -- if     wantedAction=="building"  and not canBuild  and not recM then bestFeature,recM,recE = false,false,false
        -- prevent ordering reclaim of metal if repairing is wanted and energy is depleted
        -- elseif wantedAction=="repairing" and not canRepair and not recE then bestFeature,recM,recE = false,false,false
        -- end
    end
    -- Echo("new_target, bestFeature is ", new_target, bestFeature)
    --
    local manualTarget = manualTarget
    if manualTarget then
        local x,y,z
        if spValidFeatureID(manualTarget-maxUnits) then
            x,y,z = GetFeaturePosition(manualTarget-maxUnits)
        else
            x,y,z = spGetUnitPosition(manualTarget)
        end
        if x then 
            -- Echo(b.posX..' - '..x,b.posZ..' - '..z.." == "..(((b.posX-x)^2 + (b.posZ-z)^2)^0.5)..' vs '..b.buildDistance)
            -- local bx,_,bz = spGetUnitPosition(b.id)
            -- if ((bx-x)^2 + (bz-z)^2)^0.5>b.buildDistance then
            local bx, _, bz = GetUnitPos(bID,5)
            if ((b.posX-x)^2 + (b.posZ-z)^2)^0.5 > range then
                manualTarget=false
            end
        end
    end
    local debug = Debug.prio()
    local debugReclaim
    if debug then
        debug = function(id, comment)
            debugReclaim = ':' .. comment .. ':' .. Name(id) .. ' #' .. id
            return true
        end
    else
        debug = function() return true end
    end
    local toReclaim = (
          AttackReclaim     and debug(AttackReclaim-maxUnits,'AttackReclaim')   and AttackReclaim
        or SpecialReclaim   and debug(SpecialReclaim-maxUnits,'SpecialReclaim') and SpecialReclaim
        or manualTarget     and spValidFeatureID(manualTarget-maxUnits) and debug(manualTarget-maxUnits,'manualTarget') and manualTarget
        or bestFeature      and debug(bestFeature,'bestFeature', FeatureDefs[GetFeatureDefID(bestFeature)].name)                and bestFeature + maxUnits 
    )

    if toReclaim -- and
       -- (not new_target
       --  or not canBuild and wantedAction=="building" or not canRepair and wantedAction=="repairing"
       --  or SpecialReclaim or AttackReclaim
       --  or manualTarget --[[and spValidFeatureID(manualTarget-maxUnits) and manualTarget--]])
        then

        local isNew = IsNewAction(b,CMD_RECLAIM,{toReclaim})

        if isNew then
        -- if (tgtID~=curID or cmdID~=CMD_REPAIR)   --[[or Units[tgtID].isGtBuilt~=(wantedAction=="building")--]] then
            local actBefore, mBefore, eBefore, needMBefore, needEBefore = b.action, res.mExtra, res.eExtra, res.needM, res.needE
            local action = UpdateAction(b,CMD_RECLAIM,{toReclaim})
            if Debug.prevision() then
                Echo(
                    b.sign ..
                    'action: ' .. tostring(actBefore) .. ' => ' .. tostring(action)
                    ,'M '.. round(mBefore,1) .. ' => ' .. round(res.mExtra,1)
                    ,'E ' .. round(eBefore,1) .. ' => ' .. round(res.eExtra,1)
                    ,'needM '.. round(needMBefore,1) .. ' => ' .. round(res.needM,1)
                    ,'needE ' .. round(needEBefore,1) .. ' => ' .. round(res.needE,1)
                )
            end
        -- if toReclaim~=curID and cmdID~=CMD_RECLAIM  then
            if debugReclaim then
                Echo(b.sign .. debugReclaim,os.clock())
            end
            num.reclaiming = num.reclaiming+1
            -- if b.priority~= "normal" then
            --     GiveOrderToUnit(bID, CMD_PRIORITY, TABLE_1,SB_INTERNAL)
            --     b.priority = "normal"
            -- end
            -- Echo(b.humanName,'reclaim')
            b:GiveOrder(CMD_RECLAIM,toReclaim)
            b.currentAction = action
            b.tag = tagConv[b.currentAction]
            -- b.rec = toReclaim
        end
        
   -----

    elseif new_target then
        -- if Prio1 then
        --     if b.priority ~= "high" then
        --         GiveOrderToUnit(bID, CMD_PRIORITY, TABLE_2,SB_INTERNAL)
        --         b.priority = "high"
        --     end
        -- elseif b.priority~= "normal" then
        --   GiveOrderToUnit(bID, CMD_PRIORITY, TABLE_1,SB_INTERNAL)
        --   b.priority = "normal"
        -- end

        -- num.building = wantedAction=="building" and num.building+1 or num.building
        -- num.repairing = wantedAction=="repairing" and num.repairing+1 or num.repairing


        

        local isNew = IsNewAction(b,CMD_REPAIR,{new_target})

        if isNew then
        -- if (new_target~=curID or cmdID~=CMD_REPAIR)   --[[or Units[new_target].isGtBuilt~=(wantedAction=="building")--]] then
            local actBefore, mBefore, eBefore, needMBefore, needEBefore = b.action, res.mExtra, res.eExtra, res.needM, res.needE
            local action = UpdateAction(b,CMD_REPAIR,{new_target})
            if Debug.prevision() then
                Echo(
                    b.sign ..
                    'action: ' .. tostring(actBefore) .. ' => ' .. tostring(action)
                    ,'M '.. round(mBefore,1) .. ' => ' .. round(res.mExtra,1)
                    ,'E ' .. round(eBefore,1) .. ' => ' .. round(res.eExtra,1)
                    ,'needM '.. round(needMBefore,1) .. ' => ' .. round(res.needM,1)
                    ,'needE ' .. round(needEBefore,1) .. ' => ' .. round(res.needE,1)
                )
            end
            if debugPrio then
                Echo(os.clock(),debugPrio)
            end
            if wantedAction == 'building' then
                local builtBy = Units[new_target] and Units[new_target].builtBy
                if cmdID==CMD_GUARD and curID==builtBy then
                    -- let it guard the fac/builder
                    -- if bID == 3509 then
                    --     Echo('let it guard')
                    -- end
                elseif builtBy  and Units[builtBy] and Units[builtBy].isFactory then
                    -- else make it guard, if factory
                    --     Echo('make it guard')
                    -- TABLE_PARAM[1] = builtBy
                    -- GiveOrderToUnit(bID,CMD_GUARD,TABLE_PARAM,SB_INTERNAL + CMD_OPT_SHIFT)
                    b:GiveOrder(CMD_GUARD,builtBy)
                else
                    --     Echo('build it directly')
                    -- TABLE_PARAM[1] = new_target
                    -- GiveOrderToUnit(bID,CMD_REPAIR,TABLE_PARAM,SB_INTERNAL + CMD_OPT_SHIFT)
                    b:GiveOrder(CMD_REPAIR,new_target)
                end
            else
                -- TABLE_PARAM[1] = new_target
                -- GiveOrderToUnit(bID,CMD_REPAIR,TABLE_PARAM,SB_INTERNAL + CMD_OPT_SHIFT)
                b:GiveOrder(CMD_REPAIR,new_target)
            end
        end
    elseif cmdID==CMD_RECLAIM and b.recM and res.mCur==res.mMax or b.recE and res.eCur==res.eMax then
        -- res.eExtra = res.eExtra - ENERGY_BALANCE[b.recE] * b.buildSpeed
        -- res.mExtra = res.mExtra - METAL_BALANCE[b.recM] * b.buildSpeed

        Stop(bID,isFighting,tag)
    end -- end bestFeature? and order
    --Echo("bd:"..num.building,"rec:"..num.reclaiming,"rep:"..num.repairing)
    -- Echo("res.mExtra is ", res.mExtra,res.buildCap)

    -- Echo("res.eExtra,res.mExtra is ", res.eExtra,res.mExtra)
    -- checkpass('average',50,'say')

end

function widget:UnitCommand(id, defID, unitTeam, newCmd, params, opts, cmdTag, playerID, fromSynced, fromLua)
    local b = builders[id]
    if b then
        -- Echo("newCmd,opts.coded is ", newCmd,opts.coded,(newCmd==1 and 'insert newCmd ' .. params[2] .. 'coded: ' .. params[3] or ''))
        if Debug.sequence() then
            -- Echo('UC: received order',((newCmd==1) and params[2]..' insert at '.. params[1]) or newCmd,'current action:',b.currentAction,'current command:',Spring.GetUnitCurrentCommand(id))
            -- Echo('UC: received order',newCmd,unpack(params))
            local queue = spGetCommand(id,1)
            Echo('UC: current action:',b.currentAction,'current command:',queue[1] and queue[1].id,'manual ? ',Units[id].manual)
        end
        -- Echo("newCmd==CMD_RAW_BUILD is ", newCmd==CMD_RAW_BUILD,IsOwnOrder(opts.coded))
        if newCmd == CMD_MOVE_STATE and b.canMove then
            if Units[id].isComm and cfg.disallow_comms then
                return
            end
            b.moveState = params[1]

            if b.isIdle then
                ResetUnit(id,Units[id])
            end
            return
        end
        if newCmd==CMD_RAW_BUILD or newCmd==CMD_INSERT and params[2]==CMD_RAW_BUILD then
            return
        end
        if newCmd==CMD_REMOVE then
            return
        end
        if newCmd==CMD_INSERT then

            newCmd = params[2]
            params = {unpack(params)}
            for i=1,3 do
                table.remove(params,1)
            end
        end
        if newCmd == CMD_STOP then
            return
        end
        --f.DebugUnitCommand(id, defID, unitTeam, newCmd, params, opts, cmdTag, playerID, fromSynced, fromLua)

        -- update the commandedManually property
        -- if b.commandedManually and (b.lastCommand == newCmd or os.clock() - b.commandedManually > 0.8) then
        --     if Debug.sequence() then
        --         Echo('UC: commandedManually is now false bc '
        --             ,b.lastCommand == newCmd and 'order received is the command ('..newCmd..')'
        --             or os.clock() - b.commandedManually > 0.8 and 'manual command timed out')
        --     end
        --     b.commandedManually = false
        -- end
        --

        -- Echo("'unit command',newCmd is ", 'unit command','Frame:'..Spring.GetGameFrame(),newCmd,unpack(params))
        local newOwn = IsOwnOrder(opts.coded)
        -- Echo("newOwn is ", newOwn,spGetUnitPosition())
        -- Echo("newOwn,newCmd is ", newOwn,newCmd)
        local curCmd,curTag,curOwn
        local queue = spGetCommandQueue(id,2)
        local current = queue[1]
        local nex = queue[2]
        -- Echo(newCmd,"trackedUnits[id].manual is ", trackedUnits[id].manual,'Units[id].manual',Units[id].manual,"Units[id] == trackedUnits[id]",Units[id] == trackedUnits[id])
        -- Echo("trackedUnits[id].holder is ", trackedUnits[id].holder.creation_time,Units[id].holder.creation_time)
        if current then
            curCmd,curTag,curOwn,curTgt = current.id, current.tag, current.options and IsOwnOrder(current.options.coded), not current.params[3] and current.params[1]
        end
        -- Echo("newOwn,curOwn, nex.id is ", newOwn,curOwn, nex.id)
        if current then
            -- Echo('have current',curCmd,' order = ',newCmd,'internal?',curOwn,'code:',current.options.coded,CMD_OPT_SHIFT)
            -- Echo("curOwn , IsOwnOrder(opts.coded) is ", curOwn , IsOwnOrder(opts.coded))
            local unit = Units[id]
            -- if curOwn and not newOwn and unit.isFighting then
            --     Echo('received not own newCmd while fighting',current.id,'=>',newCmd)
            -- end
            if not newOwn then 
                if not curOwn then
                    if curCmd == CMD_RAW_BUILD then
                        if nex and IsOwnOrder(nex.options.coded) then
                            -- Echo(id,1,'remove order')
                            GiveOrderToUnit(id, CMD_REMOVE, nex.tag, 0)
                        end
                        GiveOrderToUnit(id, CMD_REMOVE, curTag, 0)
                        return
                    end
                else
                    if curCmd~=CMD_RAW_MOVE then

                        if nex and nex.id == CMD_GUARD then
                            -- Echo(id,1,'remove order')
                            GiveOrderToUnit(id, CMD_REMOVE, nex.tag, 0)
                        end
                        GiveOrderToUnit(id, CMD_REMOVE, curTag, 0)
                        return
                    end
                end
            else
                if curOwn and curCmd == CMD_GUARD and newCmd == CMD_GUARD then
                    -- remove the extra guard command
                    -- Echo('remove extra guard')
                    -- Echo(id,2,'remove order')
                    GiveOrderToUnit(id, CMD_REMOVE, curTag, 0)
                    return
                end
            end
            -- Echo("curCmd,newCmd is ", current and current.id,current and current.params[1],newCmd,params[1],'own?',newOwn)
            if not curOwn and newOwn then 
                if Units[id].waitManual then
                    -- Echo('Unit is about to be manual but an auto order has just been received !')
                    Stop(id)
                    return
                end
                if newCmd==CMD_RAW_MOVE then
                    -- our own move order happen 
                    return
                end
                local overrideFight = unit.isFighting and b.canRoam
                if overrideFight then
                    if curCmd ~= CMD_FIGHT then
                        Debug.sequence(b.sign .. '=> order ' .. newCmd .. ' allowed to override fighting order' .. curCmd .. '')
                        -- Echo(b.sign .. '=> order ' .. newCmd .. ' allowed to override fighting order' .. curCmd .. '')
                        if curCmd == CMD_RAW_BUILD and nex then
                            -- no need to remove the RAW_BUILD order, it will be gone along with its main order
                            GiveOrderToUnit(id, CMD_REMOVE, nex.tag, 0)
                        else
                            GiveOrderToUnit(id, CMD_REMOVE, curTag, 0)
                        end
                    end
                    return
                else
                -- an automatic order have come just after a manual/normal order -- it can happen when an order has been issued a short moment before UnitIdle get triggered,  but has not yet been confirmed by the server
                    b.toRemoveOrder = true
                    -- Echo(b.sign .. '=> automatic order ' .. newCmd .. ' just came after manual order ' .. curCmd .. ' , removing the auto')
                    Debug.sequence(b.sign .. '=> automatic order ' .. newCmd .. ' just came after manual order ' .. curCmd .. ' , removing the auto')
                end
            elseif curOwn and newOwn then

                if curCmd~=CMD_RAW_MOVE and newCmd~=CMD_RAW_MOVE then
                    -- or an internal order is replacing another
                    -- Echo(id,3,'remove order')
                    -- Echo('REPLACING ' .. curCmd .. ', ' .. current.params[1] .. ' by ' .. newCmd .. ', ' .. params[1])
                    GiveOrderToUnit(id, CMD_REMOVE, curTag, 0)
                    -- if nex and nex.id == CMD_GUARD then
                    --     GiveOrderToUnit(id, CMD_REMOVE, {nex.tag}, 0)
                    -- end
                end

            end

            if fromLua and curCmd == CMD_RAW_MOVE and newCmd == CMD.GUARD then
                -- Echo('guarding factory')
                -- Debug.Log(b.sign .. 'guarding factory, is put on manual' )
                b.currentAction = 'manual'
                b.tag = tagConv[b.currentAction]
                b.guardFac = not unit.manual
                return
            end
            local nexCMD,nexTag = nex and nex.id, nex and nex.tag
            -- Echo("curCmd,curTag,curOwn is ", curCmd,curTag,curOwn)
            -- cancel current guarding if one more command is issued
            -- Echo("curCmd,CMD_GUARD is ", curCmd,CMD_GUARD,nexCMD,id,#queue)
            -- Echo("nexCMD==CMD_GUARD is ", nexCMD==CMD_GUARD)

            -- REMOVE the guarding if a manual command is issued, no matter where in the queue it is issued
            -- local tracked = trackedUnits[id]
            -- if not fromLua and trackedUnits[id].manual and (curCmd==CMD_GUARD or nexCMD==CMD_GUARD) and opts.shift then
                -- REMOVE AUTO GUARDING FAC
                -- Echo('remove guarding',os.clock(),newCmd)
                -- if nexCMD==CMD_GUARD then -- if b is set to guard factory on creation, we remove the guard order which is the second in this case
                --     -- TABLE_PARAM[1] = nexTag

                --     GiveOrderToUnit(id, CMD_REMOVE, {nexTag}, 0)
                -- end
                -- -- TABLE_PARAM[1] = curTag
                -- GiveOrderToUnit(id, CMD_REMOVE, {curTag}, 0)
            -- end


            -- NOTE: when issuing order with spGiveOrder() ie to reclaim stuff, user may click at the same moment to give another order
            --, in that case, the clicked order will be executed BEFORE the one issued by spGiveOrderToUnit()
            --, and we don't want that, we want the order from widget beeing cancelled if user issue a click order
        else
        end

        --
        -- manual command --
        -- Echo("trackedUnits[id].manual, trackedUnits[id].waitManual is ", trackedUnits[id].manual, trackedUnits[id].waitManual)
        -- Echo("curOwn,curCmd,curTag,opts.coded is ", curOwn,curCmd,curTag,opts.coded)
        -- if newCmd<0 or newCmd==1 and (params[2] or 0)<0 and b.currentAction~='manual' then
        --     b.currentAction='manual'
        --     manualCommand = "building"

        --     if b.priority == "high" then
        --       GiveOrderToUnit(id, CMD_PRIORITY, TABLE_1,SB_INTERNAL)
        --       b.priority = 'normal'
        --     end
        -- end
        if not newOwn and (Units[id].manual or Units[id].waitManual or newCmd and not is) then
            if curOwn and curCmd~=CMD_RAW_MOVE--[[and curCmd and curTag--]] --[[opts.shift--]] then
                --cancel internal command to be replaced by manual command
                -- Echo(os.clock(),'canceled internal command',curCmd)
                -- Echo(id,4,'remove order')
                GiveOrderToUnit(id, CMD_REMOVE, {curTag}, SB_INTERNAL)
            end
            b.currentAction = "manual"
            b.tag = tagConv[b.currentAction]

            -- Echo('non internal order, put b on manual',newCmd)
            manualTarget = params[1]
            local unit = spValidUnitID(manualTarget) and not spGetUnitIsDead(manualTarget) and Units[manualTarget]
            manualCommand =  newCmd == (CMD_REPAIR or newCmd<0) and (unit and (select(5, spGetUnitHealth(manualTarget)))<1 and "building" or "repairing")
                          or newCmd == CMD_RECLAIM and "reclaiming"
            if manualCommand     == "reclaiming" and unit then unit.isGtReclaimed = true 
            elseif manualCommand == "building"  and unit then unit.isGtReclaimed = false
            end
            if b.priority == "high" then
              GiveOrderToUnit(id, CMD_PRIORITY, TABLE_1,SB_INTERNAL)
              b.priority = 'normal'
            end
        end

    end
end

function widget:PlayerResigned(playerID)
    if playerID == Spring.GetMyPlayerID() then
        widgetHandler:RemoveWidget(widget)
    end
end

-- local cycle,time = 0,os.clock()
function widget:Update()
    if cfg.antilag and lag[1]> 1 then
        updateResourceFrame = lastResFrame + UPDATE_RESOURCE_RATE * lag[1]
        builders_per_frame, check_delay = AdjustForLag()
    else
        updateResourceFrame = lastResFrame + UPDATE_RESOURCE_RATE
        builders_per_frame, check_delay = BUILDERS_PER_FRAME, CHECK_DELAY
    end
end
function widget:GameFrame(frame)
    currentFrame = frame
    if not next(builders) then
        return false
    end
    -- Echo("b.unit.isFighting is ", b.unit.isFighting,b.unit.manual)
  ------------------ full Definition of Energy and Metal States every 30 frames (1 sec in the best time) --------------------
    local debugCluster = Debug.cluster()
    if (cfg.detect_cluster or debugCluster) and frame %UPDATE_CLUSTER_RATE==0 or cfg.temp_draw_cluster and frame%15==0 then
        -- local round = math.round
        if cfg.detect_cluster or debugCluster then
            local spGetTimer,spDiffTimers = Spring.GetTimer, Spring.DiffTimers
            local time1,time2
            if debugCluster then
                time1 = spGetTimer()
            end
            -- local units = Spring.GetTeamUnits(myTeamID)
            local t = {}
            local old = options.old_detect.value
            if old then
                for id, unit in pairs(Units) do
                    if tonumber(id) and (unit.isMine or unit.isAllied) and not (unit.isCon or unit.isComm) then
                        local x, y, z = GetUnitPos(id,15)
                        t[id] = {x,y,z}
                    end
                end
            else
                local n = 0
                for id, unit in pairs(Units) do
                    if tonumber(id) and (unit.isMine or unit.isAllied) and not (unit.isCon or unit.isComm) then
                        n = n + 1
                        local x, y, z = GetUnitPos(id,15)
                        t[n] = {id, x, z}
                    end
                end
                t.n = n
            end
            if debugCluster then
                time1 = spDiffTimers(spGetTimer(),time1)
                time2 = spGetTimer()
            end
            if next(t) then
                local noise
                if old then
                    myClusters, noise = WG.DBSCAN_clusterOLD(t,cfg.cluster_range,cfg.min_cluster_size)
                else
                    myClusters, noise = WG.DBSCAN_cluster3(t,cfg.cluster_range,cfg.min_cluster_size)
                end
                for i,cluster in ipairs(myClusters) do
                    local totalx,totalz, cnt = 0, 0, cluster.n or #cluster
                    -- Echo('cluster #' .. i,'count' .. cnt)
                    -- for i,id in pairs(cluster) do
                    --     Echo("i,id is ", i,id)
                    -- end
                    if old then
                        for i,id in ipairs(cluster) do
                            local x,_, z = unpack(t[id])
                            totalx = totalx + x
                            totalz = totalz + z
                        end
                    else
                        for i,obj in ipairs(cluster) do
                            local x,z = obj[2], obj[3]
                            totalx = totalx + x
                            totalz = totalz + z
                        end
                    end
                    local x,z = totalx/cnt, totalz/cnt
                    -- Echo(i,"cnt is ", cnt)
                    cluster.mid = {x,spGetGroundHeight(x,z),z}
                end
                if debugCluster then
                    time2 = spDiffTimers(spGetTimer(),time2)
                    Echo('clusters processed in ' .. time1 .. ' + ' .. time2 .. ' = ' .. time1 + time2 )
                    local str = ''
                    local total = 0
                    local all_n = #myClusters
                    for i = 1, all_n do
                        local cnt = #myClusters[i]
                        str = str .. '#'..i .. ': ' .. cnt .. ', '
                        total = total + cnt
                    end 
                    Echo(all_n .. ' clusters,\n' .. str:sub(1,-3),'total: ' .. total,noise and ('noises: ' .. #noise) or '')

                end
            else
                myClusters = EMPTY_TABLE
            end
        end
    end
    if frame >= updateResourceFrame then
        UpdateResources()
        updateResourceFrame = currentFrame + UPDATE_RESOURCE_RATE * lag[1]
        lastResFrame = currentFrame
    -- elseif frame % 10 == 1 then
    --     UpdateResourcesQuick()
    end

    -- if not res.energyIncome then return end


    ---////////////////////////////////
    ---////////////////////////////////
    ---- BUILDER ORDERING
    ---////////////////////////////////
    ---////////////////////////////////
    if next(waiting) then
        if Debug.sequence() then
            Echo('in waiting list')
        end
        for id,b in pairs(waiting) do
            if spValidUnitID(id) and not spGetUnitIsDead(id) then
                UpdateOrder(id,b,frame)
                -- FIXME the unit is not sent to update order because he is not getting idle due to guard command
                -- count = (count or 0) + 1
                -- Echo(count)
            end

            waiting[id]=nil
        end
    end

    if frame < roundFrame + check_delay then return end
    -- full cycle of all builders in minimum of 1 second, 1 builder per frame if they exceed 30
    roundFrame = frame


    -- if round(os.clock()-time)>=1 then
    --     Echo("fps",cycle-frame)
    --     cycle,time = frame,os.clock()
    -- end
    local count = math.max(builders_per_frame,1) -- how many builder per frame we have to process

    while count > 0 do
        if not builders[bID] then
            bID = nil -- happens
        else
            bID, b = next(builders,bID)
        end
        if not bID then -- new cycle
            thisRound = {}
            -- Echo("new cycle",frame-cycle,"done in ",os.clock()-time)
            -- Echo("builders_per_frame is ", builders_per_frame)
            -- cycle,time = frame,os.clock()
            bID,b = next(builders)
            --Echo("before l:"..cntleft,"r:"..cntright)
            --Echo("after l:"..cntafterleft,"r:"..cntafterright)
            -- cntleft,cntright,cntafterleft,cntafterright=0,0,0,0

            --for k in pairs(featReclaimed) do --[[if not spValidFeatureID(k+maxUnits) then featReclaimed[k]=nil end--]] cnt=cnt+1 end

            --Echo("features:"..cnt,"rec:"..num.reclaiming,"bd:"..num.building,"rep:"..num.repairing)
            num.reclaiming = 0
            num.building = 0
            num.repairing = 0
          
        end
        ---------------------
        if frame >= b.treated + UPDATE_RATE then
            UpdateOrder(bID,b,frame)
            b.treated = frame
        end
        count = count - 1
    end
    preGame=false
end
        --------- De coté
--[[              local nearEnemyID = GetUnitNearestEnemy(bID,n.buildDistance)
          if nearEnemyID and (not bestUnit) then
            if (prevCommand ~= CMD_RECLAIM) or (prevUnit ~= nearEnemyID) then
              orderQueue[bID] = {1, CMD_RECLAIM, nearEnemyID}
            end
            ordered = true
          end
        
          if (bestUnit ~= nil) and (not ordered) then
            if (prevCommand ~= CMD_REPAIR) or (prevUnit ~= bestUnit) then
              orderQueue[bID] = {1, CMD_REPAIR, bestUnit}
            end
            ordered = true
          elseif (nextUnit ~= nil) and (not ordered) then
            if (prevCommand ~= CMD_REPAIR) or (prevUnit ~= nextUnit) then
              orderQueue[bID] = {1, CMD_REPAIR, nextUnit}
            end
            ordered = true
          end--]]

        --------

    ------------------------------ Best Feature definition ---------------------------------------
local features = {}
function CheckFeatures(b,wantM,wantE,needM,needE)
    local bestFeature
    local noMoreEfeatures = b.noMoreEfeatures
    if res.wantE>b.buildSpeed/2 and res.wantM <= b.buildSpeed/2 and noMoreEfeatures then return false,false,false end
    local prefered={}
    local brokeloop, hasE
    local range = b.range
    local nearFeatures = GetFeaturesInCylinder(b.posX,b.posZ,range)
    if nearFeatures == nil then return end
    local EfeaturesCount = 0
    local recM,recE = false,false
    local buildSpeed = b.buildSpeed
    local wantM, wantE = res.wantM, res.wantE
    local matchM, matchE
    local p = 6
    local range = b.range
    if b.extraRange>0 then
        dist = {}
        x,z = b.posX, b.posZ
        table.sort(nearFeatures,ByDistFeatures)
    end
    x,z = b.posX, b.posZ
    for i,featureID in ipairs(nearFeatures) do
        if not rezedFeatures[featureID] and wantedFeatureDefID[GetFeatureDefID(featureID)] then
            local fx,_,fz  = GetFeaturePosition(featureID)
            if ((fx-x)^2 + (fz-z)^2)^0.5 < range then -- GetUnitInCylinder catch some farther feature
                local fm,_,fe  = GetFeatureResources(featureID)
                recM = fm>0.001
                recE = fe>0.001
                matchM, matchE = (res.wantM > b.buildSpeed/2) == recM, (res.wantE > b.buildSpeed/2) == recE
                if noMoreEfeatures then
                    if matchM then 
                        if not featReclaimed[featureID] or featureID==b.rec then
                            -- ideal pick, matching and we're already on it or not reclaimed
                            prefered = {featureID,recM,recE}
                            break
                        elseif p > 1 then
                            -- else any other
                            p = 1
                            prefered = {featureID,recM,recE}
                        end
                    end
                else
                    hasE = hasE or recE
                    --matching want/offer of both M,E
                    if matchM and matchE then
                        if not featReclaimed[featureID] or featureID==b.rec then
                            -- ideal pick, matching both and we're already on it or is new
                            prefered = {featureID,recM,recE}
                            brokeloop = true
                            break
                        elseif p > 1 then
                            -- else one that is not getting reclaimed
                            p = 1
                            prefered = {featureID,recM,recE}
                        end
                    -- only one match
                    elseif (matchM or matchE) and p > 1 then
                        if p > 2 and (recM and wantM>wantE or recE and wantE>wantM) then
                            -- the most wanted is matched
                            p = 2
                            prefered = {featureID,recM,recE}
                        elseif p > 3 and featureID==b.rec then
                            -- the least wanted is matched
                            -- keep the one we're reclaiming
                            p = 3
                            prefered = {featureID,recM,recE}
                        elseif p > 4 and not featReclaimed[featureID] then
                            -- or find one that noone is reclaiming
                            p = 4
                            prefered = {featureID,recM,recE}
                        elseif p > 5 then
                            p = 5
                            prefered = {featureID,recM,recE}
                        end
                    end
                end
            end
        end
    end
    if not (noMoreEfeatures or hasE or brokeloop or b.canMove) then
        b.noMoreEfeatures = true
    end
    -- Echo('res.wantM,res.wantE',res.wantM,res.wantE,'res.needM,res.needE',res.needM,res.needE,"recM,recE is ", recM,recE,bestFeature)
    Debug.Log(b.sign .. 'Check Best Feature:',unpack(prefered))
    return unpack(prefered)
end

function Stop(bID,isFighting,tag)
    if isFighting then
        GiveOrderToUnit(bID,CMD_REMOVE,{tag},0)
    else
        GiveOrderToUnit(bID, CMD_STOP, TABLE_ZERO, SB_INTERNAL)
    end
    -- if b.priority=='high' then
    --     b.priority = 'normal'
    --     GiveOrderToUnit(bID, CMD_PRIORITY, TABLE_1,SB_INTERNAL)
    -- end
    -- if b.rec then
    --     local rec = b.rec
    --     if featReclaimed[rec] then featReclaimed[rec]=nil end
    -- end
    -- b.recM,b.recE = false,false
    -- b.currentAction = "listening"
end


function widget:UnitGiven(id, unitDefID, unitTeam)
    if unitTeam~=myTeamID then return end
    local _, _, _, _, BP = spGetUnitHealth(id)
    if (BP == 1) then
        widget:UnitFinished(id, unitDefID, myTeamID)
    else
        widget:UnitCreated(id, unitDefID, myTeamID,false)
    end
end

-- register the builder and its buildspeed for time estimation

function widget:UnitCreated(unitID, unitDefID, unitTeam,builderID)
    if unitTeam~=myTeamID then return end
    local builder = builderID and Units[builderID]
    if builder then
        local unit = Units[unitID]
        if not unit then return end
        unit.builders={[builderID]=true}
        unit.buildPotential = builder.ud.buildSpeed or 0
    end
    if builderDefID[unitDefID] then
        if CommandTracker then
            CommandTracker.SetTrackedUnit(unitID)
        end
    end
end

function widget:UnitDestroyed(id, unitDefID, unitTeam)
  if unitTeam~=myTeamID then return end
  local b = builders[id]
  if not b then return end
  local rec = b.rec
  if rec and featReclaimed[rec or rec-maxUnits] then featReclaimed[rec or rec-maxUnits]=nil end
  builders[id] = nil
  n_builders = n_builders-1
  BUILDERS_PER_FRAME = round(UPDATE_RATE/n_builders)
  OrderDraw('pos',id)
  if BUILDERS_PER_FRAME<1 then BUILDERS_PER_FRAME=1 end
end

function widget:UnitTaken(id, unitDefID, unitTeam)
    if unitTeam~=myTeamID then return end
    widget:UnitDestroyed(id, unitDefID, myTeamID)
end
function widget:UnitReverseBuilt(id, unitDefID, unitTeam)
    if unitTeam~=myTeamID then return end
    widget:UnitDestroyed(id, unitDefID, myTeamID)
end
local drawValue = true
function widget:DrawScreen()
    if Debug.showBalance() and res.mExtra then
        glColor(0.5,0.7,1,1)
        glText(string.format('Metal Balance:%.0f',res.mExtra), 420,680, 25)
        glColor(0.9,0.9,0.2,1)
        glText(string.format('Energy Balance:%.0f',res.eExtra), 755,680, 25)
    end
end
local glDrawGroundCircle = gl.DrawGroundCircle
local glLineWidth = gl.LineWidth
local GL_LINE_BITS = GL.LINE_BITS
local GL_LINES = GL.LINES
local glDepthTest = gl.DepthTest
local glPopAttrib = gl.PopAttrib
local glPushAttrib = gl.PushAttrib
local glLineStipple = gl.LineStipple
local glBeginEnd = gl.BeginEnd
local glVertex = gl.Vertex
local function LineVerts(x1,y1,z1,x2,y2,z2)
    glVertex(x1,y1,z1)
    glVertex(x2,y2,z2)
end

local TimeChecker = f.CheckTime()

function widget:DrawWorld()
    if cfg.detect_cluster and (Debug.cluster() or cfg.temp_draw_cluster) then
        if cfg.temp_draw_cluster then
            cfg.temp_draw_cluster = cfg.temp_draw_cluster - Spring.GetLastUpdateSeconds()
            if cfg.temp_draw_cluster < 0 then
                cfg.temp_draw_cluster = false
            end
        end
        local range = cfg.cluster_range
        for i,cluster in ipairs(myClusters) do
            local mid = cluster.mid
            glDrawGroundCircle(mid[1],mid[2],mid[3], range , 90)
        end
        -- show
        glColor(0,0.7,0.1)
        for i,cluster in ipairs(myClusters) do
            local mid = cluster.mid
            glDrawGroundCircle(mid[1],mid[2],mid[3], cfg.max_away_cluster , 90)
        end

    end
    if cfg.draw_alpha>0 and (cfg.draw_range or cfg.temp_draw or Debug.range()) then
        if cfg.temp_draw then
            cfg.temp_draw = cfg.temp_draw - Spring.GetLastUpdateSeconds()
            if cfg.temp_draw < 0 then
                cfg.temp_draw = false
            end
        end
        glLineWidth(0.2)
        glColor(rangeColor)

        for id,b in pairs(builders) do

            if not b.unit.manual or cfg.temp_draw then
                local px,py,pz = b.posX,b.posY,b.posZ
                local x,y,z = GetUnitPos(id,5)
                glDrawGroundCircle(px,py,pz, b.range , 90)
                glDrawGroundCircle(px,py,pz, 2 , 90)
                if x~=px and z~=pz then
                    -- glLineStipple(2,4095)
                    glLineStipple(true)
                    glBeginEnd(GL_LINES, LineVerts, x,y,z,px,py,pz)
                    glLineStipple(false)
                end
            end

        end
        -- glPushAttrib(GL_LINE_BITS)
        -- for id,b in pairs(builders) do
        -- end
        -- glPopAttrib()
        glLineWidth(1)
        glColor(1,1,1,1)
    end
    -- for i,id in ipairs(Spring.GetAllFeatures()) do
    --     local x,y,z = GetFeaturePosition(id)
    --     cnt = cnt + 1
    --     glPushMatrix()
    --     glTranslate(x,y,z)
    --     glBillboard()
    --     glText(id, 0,0,25,'h')
    --     -- glText(id, 0,-20,5,'h')
    --     glPopMatrix()
       
    -- end

    if cfg.draw_tag then

        for id,b in pairs(builders) do
            glColor(1, 1, 0, 0.6)
            if spValidUnitID(id) then
                --local txt = Units[id].isIdle and 'I' or 'O'
                -- Echo("id is ", id)

                -- if id==42 then
                --     local nearUnits = GetUnitsInCylinder(b.posX,b.posZ,b.buildDistance)
                --     for i,id in ipairs(nearUnits) do
                --         local ix,iy,iz = unpack(Units[id].pos)
                --         glPushMatrix()
                --         glTranslate(ix,iy,iz)
                --         glBillboard()
                --         glColor(1, 1, 1, 0.6)
                --         glText('near', 0,-10,5,'h')
                --         glPopMatrix()
                --         glColor(1, 1, 1, 1)
                -- end
                local x,y,z = GetUnitPos(id,5)

                -- gl.Color(1,1,1,1)
                -- gl.DrawGroundCircle(x,y,z, b.buildDistance, 90)

                --     end
                local tag = b.tag
                glPushMatrix()
                glTranslate(x,y,z)

                -- using list is ~=2 time faster in this case
                local list = lists[tag]
                if list then
                    glBillboard()
                    glCallList(list)
                else
                    glBillboard()
                    glText(tag, 0,0,25,'h')
                end
                glPopMatrix()
            end
        end
        glColor(1, 1, 1, 1)
        -- time = time + spDiffTimers(spGetTimer(),timer)
        -- if cnt == 1000 then
        --     Echo(cnt .. ' counts of draw value in ' .. time .. ' seconds.')
        --     cnt = 0
        --     time = 0
        -- end
    end
end


function widget:GameStart()
    UpdateResources()
end
function WidgetRemoveNotify(w,name,preloading)
    if preloading then
        return
    end
    if name == 'Command Tracker' then
        widgetHandler:Sleep(widget)
    end
end
function WidgetInitNotify(w,name,preloading)
    if preloading then
        return
    end

    if name == 'Command Tracker' then
        Units = WG.UnitsIDCard
        trackedUnits = WG.TrackedUnits
        CommandTracker = w
        myTeamID = Spring.GetMyTeamID()
        for id in pairs(builders) do
            if not spValidUnitID(id) then
                widget:UnitTaken(id, GetUnitDefID(id), myTeamID)
            end
        end
        for id,unit in pairs(builders) do
            unit.unit = Units[id]
        end
        for _,id in ipairs(Spring.GetTeamUnits(myTeamID)) do
            if not builders[id] then
                -- Echo("trackedUnits[bID] is ", trackedUnits[bID])
                widget:UnitGiven(id, GetUnitDefID(id), myTeamID)
            end
        end
        widgetHandler:Wake(widget)

    end
end
WidgetWakeNotify = function(...) return WidgetInitNotify(...) end
WidgetSleepNotify = function(...) return WidgetRemoveNotify(...) end


function widget:Initialize()
    lag = WG.lag or {1}
    if Spring.GetSpectatingState() or Spring.IsReplay() then
        Spring.Echo(widget:GetInfo().name..' disabled for spectators')
        widgetHandler:RemoveWidget(self)
        return
    end
    if not WG.commandTrackerActive then
        widgetHandler:RemoveWidget(self)
        return
    end
    -- -- Now replaced by -OnWidgetState.lua
    -- if not WG.Dependancies:Require(widget,'Command Tracker',true) then
    --     Echo(widget:GetInfo().name .. " don't have command tracker")
    --     widgetHandler:RemoveWidget(self)
    --     -- Spring.SendCommands('luaui disablewidget ' .. widget:GetInfo().name)
    --     return
    -- end
    --

    Debug = f.CreateDebug(Debug,widget,options_path)
    -- if WG.DebugCenter then
    --     WG.DebugCenter.Add(widget,{varDebug={'res',res}})
    -- end
    if not WG.DrawUtils then
        OrderDraw = function() end
    else
        DrawUtils = WG.DrawUtils
        DrawUtils.screen[widget] = {}
        myDrawOrders = DrawUtils.screen[widget]
    end
    --
    if glCallList then
        for _, txt in pairs({'c','m','s','b','r','l'}) do
            lists[txt] = gl.CreateList(
                function()
                    glColor(1, 1, 0, 0.6)
                    glText(txt, 0,0,25,'h')
                end
            )
        end
    end
    if Spring.GetGameFrame()>0 then
        widget:GameStart()
    end
    MyNewTeamID(Spring.GetMyTeamID())

    trackedUnits = WG.TrackedUnits
    CommandTracker = widgetHandler:FindWidget('Command Tracker')

    GiveOrderToUnit = function(id,cmd,params,...)
        local b = builders[id]
        if cmd==0 then
            b.auto = true
        elseif cmd~=CMD_PRIORITY and cmd~=2 then
            -- Echo('auto order given',id,cmd,params[1],f.CMD_NAMES[cmd])
            -- local autoOrder = b.autoOrder
            -- autoOrder[1],autoOrder[2] = cmd,params[1]
            -- b.auto = true
        end
        if Debug.sequence() then
            Echo('order given',cmd)
        end
        spGiveOrderToUnit(id,cmd,params,...)
    end

    Units=WG.UnitsIDCard
    rezedFeatures = Units.rezedFeatures
    -- Units.subscribed[widget:GetInfo().name]=true
    for _,bID in ipairs(Spring.GetTeamUnits(myTeamID)) do
        local unitDefID = GetUnitDefID(bID)
        widget:UnitGiven(bID, unitDefID, myTeamID)

    end
    widget:CommandsChanged()

end

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
function widget:Shutdown()
    for _, list in pairs(lists) do
        gl.DeleteList(list)
    end
    if DrawUtils then
        DrawUtils.screen[widget] = nil
    end
    if Debug.Shutdown then
        Debug.Shutdown()
    end
    -- if type(Log)=='table' then
    --     Log:Delete()
    -- end
    -- if Units then Units.subscribed[widget:GetInfo().name]=nil end
    -- WG.Dependancies:Require(widget,'UnitsIDCard',false) 
end

f.DebugWidget(widget)


