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
    name      = "EzTarget",
    desc      = "When zoomed out, help you targetting while using right click",
    author    = "Helwor",
    date      = "8 Sept 2022",
    license   = "GNU GPL, v2 or later",
    -- layer     = -10e36, -- before the normal selection and its sound happen
    layer     = -11, -- before the normal selection and its sound happen
    -- layer     = 1002, -- 1001 is mex placement
    enabled   = true,  --  loaded by default?
    handler   = true,
  }
end

-- debug vars in a window
local debugMe = false
local DebugUp


-- speeds up
local Echo = Spring.Echo


local spGetCommandQueue             = Spring.GetCommandQueue
local spGetSelectedUnits            = Spring.GetSelectedUnits
local spGetUnitPosition             = Spring.GetUnitPosition
local spValidUnitID                 = Spring.ValidUnitID
local spGetUnitIsDead               = Spring.GetUnitIsDead
local spGetGroundHeight             = Spring.GetGroundHeight
local spGetUnitDefID                = Spring.GetUnitDefID
local spTraceScreenRay              = Spring.TraceScreenRay
local spGiveOrderToUnitArray        = Spring.GiveOrderToUnitArray
local spGiveOrderArrayToUnitArray   = Spring.GiveOrderArrayToUnitArray
local spGiveOrderToUnit             = Spring.GiveOrderToUnit
local spGiveOrder                   = Spring.GiveOrder
local spSetActiveCommand            = Spring.SetActiveCommand
local spGetActiveCommand            = Spring.GetActiveCommand
local spGetSelectedUnitsCounts      = Spring.GetSelectedUnitsCounts
local spGetSelectedUnitsCount       = Spring.GetSelectedUnitsCount
local spGetMouseState               = Spring.GetMouseState
local spSelectUnitArray             = Spring.SelectUnitArray
local spGetUnitNoSelect             = Spring.GetUnitNoSelect
local spGetDefaultCommand           = Spring.GetDefaultCommand
local spuGetMoveType                = Spring.Utilities.getMovetype
local spGetUnitHealth               = Spring.GetUnitHealth
local spGetSelectedUnitsSorted = Spring.GetSelectedUnitsSorted
local spGetUnitTransporter          = Spring.GetUnitTransporter
local spGetLastUpdateSeconds        = Spring.GetLastUpdateSeconds
local spGetCmdDescIndex             = Spring.GetCmdDescIndex
-- local spGetUnitsInCylinder = Spring.GetUnitsInCylinder
-- local spGetUnitsInRectangle = Spring.GetUnitsInRectangle
local spIsUnitVisible               = Spring.IsUnitVisible
local spIsUnitAllied = Spring.IsUnitAllied
local spGetUnitTeam = Spring.GetUnitTeam
local spGetTeamUnitsByDefs = Spring.GetTeamUnitsByDefs
-- local spGetGameFrame                = Spring.GetGameFrame
local spGetUnitRulesParam           = Spring.GetUnitRulesParam
local spGetModKeyState = Spring.GetModKeyState
-- local iconTypesPath = LUAUI_DIRNAME .. "Configs/icontypes.lua"
-- local icontypes = VFS.FileExists(iconTypesPath) and VFS.Include(iconTypesPath)

local CMD_INSERT, CMD_OPT_ALT, CMD_OPT_SHIFT, CMD_OPT_INTERNAL = CMD.INSERT, CMD.OPT_ALT, CMD.OPT_SHIFT, CMD.OPT_INTERNAL
local CMD_OPT_RIGHT = CMD.OPT_RIGHT
local CMD_MOVE, CMD_ATTACK, CMD_REMOVE = CMD.MOVE, CMD.ATTACK, CMD.REMOVE
local CMD_GUARD, CMD_REPAIR = CMD.GUARD,CMD.REPAIR
local CMD_LOAD_ONTO = CMD.LOAD_ONTO
local CMD_MANUALFIRE = CMD.MANUALFIRE
local CMD_RESURRECT = CMD.RESURRECT
local CMD_RECLAIM = CMD.RECLAIM
local CMD_MOVE = CMD.MOVE
local CMD_UNLOAD_UNITS = CMD.UNLOAD_UNITS
local CMD_LOAD_UNITS = CMD.LOAD_UNITS

local customCmds = VFS.Include("LuaRules/Configs/customcmds.lua")
local CMD_AIR_MANUALFIRE = customCmds.AIR_MANUALFIRE
local CMD_UNIT_SET_TARGET = customCmds.UNIT_SET_TARGET
local CMD_REARM = customCmds.REARM
local CMD_JUMP = customCmds.JUMP
local CMD_UNIT_CANCEL_TARGET = customCmds.UNIT_CANCEL_TARGET
local CMD_EXCLUDE_PAD = customCmds.EXCLUDE_PAD

local opts = CMD_OPT_ALT + CMD_OPT_INTERNAL

local buildMexDefID = -UnitDefNames['staticmex'].id

local checkForSelBox = os.clock()

WG.EzTarget = WG.EzTarget or {}
local shared = WG.EzTarget


local tsort = table.sort
local osclock = os.clock

local isIcon

local Cam

local MouseState

local TARGET_TABLE = {}
local commandMap, mySelection, selection, selectionMap -- from 'Selection API'
local cacheCloakedRepairSuppress = {time = 0, value = false}
local tables -- tables iterator
local v,selContext,s, cf2 = {}, {}, {}, {}
local context = {}
shared.v = v
v.acquiredTarget = false
local wh
local lists = {}
local vsx, vsy
local screen0
local Units
local PreSelection_IsSelectionBoxActive
local floor, round, huge, abs, max = math.floor, math.round, math.huge, math.abs, math.max
local round = function(x)
    return tonumber(round(x))
end



include('keysym.h.lua')
local KEYSYMS = KEYSYMS
local UnitDefs = UnitDefs
local maxUnits = Game.maxUnits




local f = VFS.Include('LuaUI\\Widgets\\UtilsFunc.lua')


options_path = 'Hel-K/EzTarget'



------------- DEBUG CONFIG
local Debug = { -- default values
    active=true -- no debug, no hotkey active without this
    ,global=false -- global is for no key : 'Debug(str)'

    ,UC = false
    ,EZ= false
    ,Mouse=false
    ,CF2=false
    ,debugVar = false
}
-- Debug.hotkeys = {
--     active =            {'ctrl','alt','E'} -- this hotkey active the rest
--     ,global =           {'ctrl','alt','G'}

--     ,UC =               {'ctrl','alt','L'}
--     ,EZ =               {'ctrl','alt','Z'}
--     ,Mouse =            {'ctrl','alt','M'}
--     ,CF2 =              {'ctrl','alt','F'}  
--     ,debugVar =         {'ctrl','alt','V'}  
-- }
debugVars = {'V',v,'has',selContext,'S',s, 'CF2', cf2}
-------------

local lobsterDefID = UnitDefNames['amphlaunch'].id

local ignoreTargetDefID = {
    [UnitDefNames['terraunit'].id] = true,
    [UnitDefNames['wolverine_mine'].id] = true,
}
local ignoreSelectDefID = {
    [UnitDefNames['terraunit'].id] = true,
    [UnitDefNames['wolverine_mine'].id] = true,
}
for defID, def in pairs(UnitDefs) do
    if def.name:find('drone') then
        -- ignoreTargetDefID[defID] = true
        ignoreSelectDefID[defID] = true
    end
end
local dgunOnAltDefID = {
    [UnitDefNames['amphlaunch'].id] = true,   
    [UnitDefNames['shipcarrier'].id] = true,   
    [UnitDefNames['striderdante'].id] = true,   
    [UnitDefNames['striderbantha'].id] = true,   
    [UnitDefNames['striderscorpion'].id] = true,   
    [UnitDefNames['bomberassault'].id] = true,   
}
local airDgunDefID = {
    [UnitDefNames['bomberassault'].id] = true,   
}
local transportDefID = {
    [UnitDefNames['gunshiptrans'].id] = true,   
    [UnitDefNames['gunshipheavytrans'].id] = true,   
}

local morphedComDGUN = {}




-- local iconSizeDefID = {}
-- for defID,def in ipairs(UnitDefs) do
--     if def.name == 'shieldbomb' then
--         iconSizeDefID[defID] = 1.8
--     else
--         iconSizeDefID[defID] = ( icontypes[(def.iconType or "default")] or icontypes["default"] ).size or 1.8
--     end
-- end
local jumperDefID = {}
for defID,def in ipairs(UnitDefs) do
    if not (def.name:match('plate') or def.name:match('factory')) then
        if def.customParams.canjump then
            jumperDefID[defID] = true
        end
    end
end
local puppyDefID = UnitDefNames['jumpscout'].id


local defIDCanAttack = {}
for defID,def in ipairs(UnitDefs) do
    if def.canAttack then
        defIDCanAttack[defID]=true
    end
end
local airAttackerDefID = {}
for defID,def in ipairs(UnitDefs) do
    if def.isAirUnit and not def.name:match('con') then
        airAttackerDefID[defID]=true
    end
end

local airpadDefID = {}
do
    local airpadDefs = VFS.Include("LuaRules/Configs/airpad_defs.lua", nil, VFS.GAME)
    for defID in pairs(airpadDefs) do
        airpadDefID[defID] = true
    end
end
local controllableRepairerDefID = {}
local controllableRepairerDefIDIndex = {}
for defID,def in ipairs(UnitDefs) do
    if def.canRepair and not def.isBuilding then -- NOTE: strider hub and caretaker doesn't have .isBuilding, so it's good for us, but if it has in the futur, we need to change this
        controllableRepairerDefID[defID] = true
        table.insert(controllableRepairerDefIDIndex, defID)
    end
end

local staticBuildingDefID = {}
for defID,def in ipairs(UnitDefs) do
    if not spuGetMoveType(def) then
        staticBuildingDefID[defID] = true
    end
end
local factoryDefID = {}
for defID,def in ipairs(UnitDefs) do
    if def.name=='striderhub' or def.isFactory and def.name ~= 'staticrearm'  then -- NOTE airpad got .isFactory (should FIX)
        factoryDefID[defID] = true
    end
end

local EzAlliedDefID = {} -- allied unit's defID we might look for 
for defID in pairs(airpadDefID) do
    EzAlliedDefID[defID] = true
end



local terraUnitDefID = UnitDefNames['terraunit'].id


local yellow = unpack({f.COLORS.yellow}) -- color that is used on the fly during evaluation
local pink = {1,0.7,1,1}

local enemies, mines, allied = {}, {}, {}
local minesByDist = {}
local poses = {}
-- same as gui_selection_modkeys.lua
local toleranceTime = Spring.GetConfigInt('DoubleClickTime', 300) * 0.001 -- no event to notify us if this changes but not really a big deal
toleranceTime = toleranceTime + 0.03 -- fudge for Update 
-- MY OWN TOLERANCE
toleranceTime = 0.3
--

-- CONFIG -- 

local EZTARGET_THRESHOLD = 25 -- if the above radius translated in elmos is smaller, EzTarget is deactivated
local MIN_SEARCH_RADIUS = 50 -- minimum radius in elmos where to search for units
local SPOT_RADIUS = 3
local opt = {

    ezTarget = true,

    ezTargetRadius = 18,



    targetHelper = true, -- help to target when click land to ground
    ezSelect = true, -- same as ezTarget but for selecting unit
    mouse_leeway = 25, -- threshold in pixel until we consider this is not a selection box but a single select
    target_mouse_leeway = 10,
    -- use EzTarget even when not holding alt
    alwaysEZ = true,
    -- draw the possible target -- but that make extra work every Update round
    drawEz = true,
    -- since EzTarget produce an attack v.cmd around enemy units by quite a margin, it can be preferable to force a move v.cmd when user right click and drag
    -- and cancel effectively Eztarget for the time
    -- this of course can only work if custom formations 2 is enabled
    cancelWhenDrag = true,
    -- if we also want to provoke a move trail with cf2.CF2 when right click and dragging on enemy that is directly pointed by the mouse without the help of EzTarget
    cancelWhenDragOnDefault = true,
    -- set move to edge of map when right clicked out
    clampToWorld = true,


    findPad = true,
    suppressRepairCloaked = true,
    findStaticRepair = true,

    findBuilderToGuard = true,
    findUnitToGuard = true,


    selSwitchStatic = true,

    forceJump = true,
    forceDGUN = true,
    forceExclude = true,
    forceAttack = true,
}


options_path = 'Hel-K/' .. widget:GetInfo().name
options_order = {
    'descHeader',
    'desc1',
    'desc2',

    'ezTargetRadius',

    'lbl_rclick',
    'findPad',
    'suppressRepairCloaked',
    'findStaticRepair',

    'lbl_alt_rclick',
    'findBuilderToGuard',
    'findUnitToGuard',

    'lbl_sel',
    'selSwitchStatic',

    'lbl_alt',
    'forceJump',
    'forceDGUN',
    'forceExclude',
    'forceAttack',




}
options = {}

options.descHeader = {
    name = 'Description',
    type = 'label',
}

options.desc1 = {
    name = '    Help the user point selecting and',
    type = 'label',
}
options.desc2 = {
    name = '    targetting.',
    type = 'label',
}


options.ezTargetRadius = {
    name = 'Helper Radius',
    desc = 'In pixel distance from the cursor, some custom radius per unit type can be defined in the widget, as number or as a % string',
    value = opt.ezTargetRadius,
    type = 'number',
    min = 1, max = 50, step = 1,
    OnChange = function(self)
        opt[self.key] = self.value
    end,
}


options.lbl_rclick = {
    name = 'Right Click behaviour (without alt)',
    type = 'label',
}

options.findPad = {
    name = 'Find Pad to rearm',
    desc = 'this would override other right click behaviour',
    type = 'bool',
    value = opt.findPad,
    noHotkey = true,
    OnChange = function(self)
        opt[self.key] = self.value
    end,
}

options.suppressRepairCloaked = {
    name = 'No repair for con in area cloak',
    type = 'bool',
    value = opt.suppressRepairCloaked,
    desc = 'Unless Alt is held, con cloaked in cloak shield will move instead of repairing',
    noHotkey = true,
    OnChange = function(self)
        opt[self.key] = self.value
        widget:CommandsChanged()
    end,
}
options.findStaticRepair = {
    name = 'Find static building to repair',
    type = 'bool',
    value = opt.findStaticRepair,
    noHotkey = true,
    OnChange = function(self)
        opt[self.key] = self.value
    end,
}



options.lbl_alt_rclick = {
    name = 'Right Click behaviour (with alt)',
    type = 'label',
}


options.findBuilderToGuard = {
    name = 'Find another builder to guard',
    desc = 'if ALT is held and a con is selected, will help find another builder to guard',
    type = 'bool',
    value = opt.findBuilderToGuard,
    noHotkey = true,
    OnChange = function(self)
        opt[self.key] = self.value
    end,
}
options.findUnitToGuard = {
    name = 'Find unit to guard',
    desc = 'if ALT is held, will help find another unit to guard',
    type = 'bool',
    value = opt.findUnitToGuard,
    noHotkey = true,
    OnChange = function(self)
        opt[self.key] = self.value
    end,
}



options.lbl_sel = {
    name = 'Point Selection Behaviour',
    type = 'label',
}
options.selSwitchStatic = {
    name = 'Alternate static building/unit',
    type = 'bool',
    value = opt.selSwitchStatic,
    desc = 'Unless Alt is held, left clicking on same target will alternatively select closest building/ closest unit',
    noHotkey = true,
    OnChange = function(self)
        opt[self.key] = self.value
    end,
}

options.lbl_alt = {
    name = 'ALT + Right Click Override',
    desc = 'order of following options respect the predominance of each one',
    type = 'label',
}

options.forceJump = {
    name = 'Jump',
    type = 'bool',
    value = opt.forceJump,
    desc = 'Jump override any other behaviour as it can be meant to escape rapidly.',
    noHotkey = true,
    OnChange = function(self)
        opt[self.key] = self.value
    end,
}

options.forceDGUN = {
    name = 'DGUN',
    type = 'bool',
    value = opt.forceDGUN,
    desc = 'use DGUN with alt if no alt override',
    noHotkey = true,
    OnChange = function(self)
        opt[self.key] = self.value
    end,
}
options.forceAttack = {
    name = 'Attack with puppy',
    type = 'bool',
    value = opt.forceAttack,
    desc = 'Puppy can make a pseudo damaging jump by attacking',
    noHotkey = true,
    OnChange = function(self)
        opt[self.key] = self.value
    end,
}

options.forceExclude = {
    name = 'Exclude Pad',
    type = 'bool',
    value = opt.forceExclude,
    desc = 'trigger exclude pad command',
    noHotkey = true,
    OnChange = function(self)
        opt[self.key] = self.value
    end,
}


-- function widget:UnitCmdDone(id,defid,cmd,_,params)
--     Echo('cmd done',cmd, params[1])
-- end
EXCEPTION_EZ = {
    -- [UnitDefNames['cloakheavyraid'].id]=true,
    -- [UnitDefNames['cloakbomb'].id]=true,
    -- [UnitDefNames['vehraid'].id]=true,
    -- [UnitDefNames['bomberheavy'].id]=true,
    -- [UnitDefNames['bomberdisarm'].id]=true,
    -- [UnitDefNames['bomberriot'].id]=true,
    -- [UnitDefNames['striderantiheavy'].id]=true,
    -- [UnitDefNames['spiderantiheavy'].id]=true,
    -- ,[UnitDefNames['cloakraid'].id]=true
}

NO_HELPER_TARGET = {
    [UnitDefNames['cloakheavyraid'].id]=true,
    [UnitDefNames['cloakbomb'].id]=true,

    [UnitDefNames['striderantiheavy'].id]=true,
    [UnitDefNames['spiderantiheavy'].id]=true,

}
-- custom radius to find target
CUSTOM_RADIUS = { -- can be expressed in number or in % as string
    [UnitDefNames['cloakraid'].id]=7,
    [UnitDefNames['vehraid'].id]=7,
    -- [UnitDefNames['bomberheavy'].id]=7,
    [UnitDefNames['bomberdisarm'].id]=2,
    -- [UnitDefNames['bomberriot'].id]=7,
    -- [UnitDefNames['bomberprec'].id]=7,
}
-- for k,v in pairs(Spring) do
--     if k:lower():find('sel') then
--         Echo(k,v)
--     end
-- end

local cmdByName = {
    ['Attack'] = CMD_ATTACK,
    ['ManualFire'] = CMD_MANUALFIRE,
    ['Jump'] = CMD_JUMP,
}


--
-- main functions
local EzTarget, Execute, UpdateSelection
-- annexes
local ClampScreenPosToWorld
local CanJumpNow, IsDefaultCommandActive, MakeOptions, ByIDs, ByIndex, CompareIDTables, GetVisibleUnits, SortMines --, SortEnemies

-- shared variables
local mods = (
    function() local alt, ctrl, meta, shift = spGetModKeyState()
        return {alt=alt, ctrl=ctrl, meta=meta, shift=shift}
    end
    )()
local sel = spGetSelectedUnits()
local mempoints = {n=0}

selContext.hasValidAttacker, selContext.hasAirAttackerUnit, selContext.hasControllableRepairer = false, false, false
selContext.lobsters, selContext.hasDgunOnAlt, selContext.hasJumper, selContext.hasPuppy = false, false, false, false
selContext.hasTransport = false

v.lastAcquiredSelect = false
v.mousePressed = false
local controllableRepairersMap = {}
local jumpers = {}

cf2.CF2, cf2.CF2_TakeOver,cf2.lastx,cf2.lasty, cf2.lastclock = false, false, false, false, false

v.cmd, v.defaultCmd, v.defaultTarget = false, false, false

v.moddedTarget, v.moddedCmd, v.cmdOverride, v.cancelEZ = false, false, false, false
v.moddedActiveCommand = false
v.customRadius = false
v.noHelperTarget = false

v.clamped = false
local upd = {}


upd.treatedFrame, upd.frame, upd.last_mx, upd.last_my, upd.keyChanged, updating = -1, Spring.GetGameFrame(), -1, -1, false, false
upd.triggered = os.clock()

local INSERT_TABLE = {-1, CMD_ATTACK, 0}
local EMPTY_TABLE = {}

s.defaultSelect, s.moddedSelect, s.acquiredSelect = false, false, false
s.last_click_mx, s.last_click_my = 0, 0
s.selBoxActive = false

s.clickTime = 0
s.modCtrl = false
s.selectionChanged = false


local opts
local points,rec,drawUnit,drawCircle = {},{},{},{}

---------- updating teamID
v.myTeamID = Spring.GetMyTeamID()

----------
---- MAIN
-- main callins are ordered below chronologically

function reset()
    -- if v.moddedActiveCommand then
    --     v.moddedActiveCommand = false
    --     local Acmd = select(5, spGetActiveCommand())
    --     if Acmd == v.moddedActiveCommand then
    --         spSetActiveCommand(0)
    --     end            
    -- end
    v.moddedTarget,s.moddedSelect, v.moddedCmd,drawCircle=nil,nil,nil,EMPTY_TABLE

end
function widget:GameFrame(f)
    upd.frame = f
end

local function SwitchCommand(commandName, command, namecom)
    v.moddedActiveCommand = commandName
    -- Echo("namecom, v.moddedActiveCommand is ", namecom, v.moddedActiveCommand)
    if namecom ~= v.moddedActiveCommand then
        spSetActiveCommand(commandName:gsub(' ',''))
    end

    v.moddedCmd = command
end
local function SetColor(id,color)
    if not drawCircle[id] then
        -- local _,_,_,x,y,z = spGetUnitPosition(v.moddedTarget,true)
        local pos = poses[id]
        if not pos then
            return
        end
        drawCircle[id] = {pos[1], pos[2],0,SPOT_RADIUS,color,1,false,true,true,true}

    else
        drawCircle[id][5] = color
        drawCircle[id][6] = 1
    end
end
local function Evaluate(type, id, engineCmd)


    -- if not selContext.hasValidAttacker then
    --     return v.cmdOverride
    -- end
    -- Echo("v.cmdOverride is ", v.cmdOverride)
    -- Echo("os.clock() is ", os.clock())
    -- Echo("v.cmdOverride or v.moddedCmd is ", v.cmdOverride or v.moddedCmd)
    -- Echo("spGetActiveCommand() is ", spGetActiveCommand())
    -- Echo("v.moddedCmd is ", v.moddedCmd)


    -- if v.moddedActiveCommand then
    --     local Acmd = select(4, spGetActiveCommand())
    --     -- Echo("Acmd is ", Acmd, v.moddedActiveCommand, spGetActiveCommand())
    --     local alt = spGetModKeyState()
    --     if Acmd == v.moddedActiveCommand and not alt then
    --         v.moddedActiveCommand = false
    --         v.moddedCmd = false
    --         spSetActiveCommand(0)
    --     elseif Acmd then
    --         v.moddedActiveCommand = false
    --         v.moddedCmd = false
    --     end            
    -- end
    if v.cmdOverride then
        return v.cmdOverride
    end
    if WG.drawingPlacement or WG.EzSelecting or WG.panning then
        reset()
        upd.updating = false
        -- v.moddedActiveCommand = false

        return 
    end

    local mx,my,lmb,mmb,rmb, outsideSpring = spGetMouseState()
    local realMousePress = lmb or mmb or rmb
    if v.mousePressed and not realMousePress then
        v.mousePressed = false
    end

    if realMousePress and not v.mousePressed then
        upd.updating = false
        s.acquiredSelect = false
        checkForSelBox = false
        -- v.moddedActiveCommand = false

        reset()
        Echo('Mouse press hasnt been registered in EzTarget !', math.round(os.clock()))
        return
    end
    -- Echo('in default command', realMousePress, v.mousePressed, v.moddedActiveCommand)
    local panning = WG.panning
    -- Echo("lmb, s.acquiredSelect, checkForSelBox)", lmb, s.acquiredSelect, checkForSelBox)
    -- Echo("checkForSelBox in Evaluate ", checkForSelBox)
    if (lmb and (s.acquiredSelect or not checkForSelBox))--[[ or rmb--]] or panning then
        upd.updating = false
        if panning then
            -- v.moddedActiveCommand = false
        end
        return v.cmdOverride or v.moddedCmd
    end
    -- if rmb then -- return the modded cmd if rmb, don't change
    --     upd.updating = false
    --     -- Echo('return',v.cmdOverride, v.moddedCmd,os.clock())
    --     return v.cmdOverride or v.moddedCmd
    -- end
    v.defaultCmd = engineCmd
    -- if (upd.last_mx==mx and upd.last_my==my and upd.treatedFrame == upd.frame) and not upd.keyChanged then
    --     upd.updating = false
    --     v.moddedActiveCommand = false
    --     return v.cmdOverride or v.moddedCmd
    -- end
    local wantSelect = opt.ezSelect or debugging
    upd.treatedFrame = upd.frame
    upd.keyChanged = false
    upd.last_mx,upd.last_my = mx, my

    v.defaultTarget, s.defaultSelect = false, false
    local mcom, acom, _, namecom = spGetActiveCommand()

    -- if namecom then namecom = namecom:lower():gsub(' ','') end

    local alt, ctrl, meta, shift = spGetModKeyState()
    -- if alt~=mods.alt or meta~=mods.meta or ctrl~=mods.ctrl or shift~=mods.shift then
    --     -- Echo('MODS key from KeyPress was bugged in EzTarget !',alt, ctrl, meta, shift, mods.meta)
    -- end
    if acom~=nil and (namecom and namecom~=v.moddedActiveCommand) then -- not doing anything when there is an active command 
        -- v.moddedActiveCommand = false
        reset()
        upd.updating = false
        return v.cmdOverride
    end
    if alt and rmb then
        if v.moddedCmd == CMD_MANUALFIRE and not selContext.lobsters and wh.mouseOwner and wh.mouseOwner:GetInfo().name == 'CustomFormations2' then
            -- continue working for CF2 -- TODO: make CF2 ask for it
            v.moddedTarget =  EzTarget(true)
        end
        return v.moddedCmd or v.cmdOverride
    end
    -- v.moddedActiveCommand = false

    if outsideSpring  or screen0:IsAbove(mx,my)  then
        reset()
        upd.updating = false
        return v.cmdOverride
    end        

    local debugging = Debug.EZ()
    local wantTarget = engineCmd~=buildMexDefID and (selContext.hasValidAttacker or selContext.hasTransport) and ((opt.ezTarget and not ctrl) or debugging)

    -- if s.acquiredSelect or v.acquiredTarget then
    --     return
    -- end
    -- if --[[v.defaultCmd == CMD_REPAIR or--]] --[[v.defaultCmd == CMD_REARM or--]] --[[alt or--]] opt.ezTarget and (not opt.ezSelect) and v.defaultCmd~=CMD_ATTACK and v.defaultCmd~=CMD_RAW_MOVE and v.defaultCmd~=CMD_MOVE and v.defaultCmd ~= CMD_RECLAIM then
    --     reset()
    --     upd.updating = false
    --     return v.cmdOverride
    -- end
    upd.updating = true
    -- Echo("v.defaultCmd is ", v.defaultCmd)
    -- local defID
    -- if type=='unit' then
    --     defID = spGetUnitDefID(id)
    --     f.Page(UnitDefs[spGetUnitDefID(id)])
    -- end
    local traced, tracedDefID,  isAllied, isMine
    local onSelf
    if type=='unit' then
        local unit = Units[id]
        if unit then
            traced = id
            onSelf = unit.isMine and traced == sel[1] and not sel[2] 
            -- local defID = spGetUnitDefID(id)
            local defID = unit.defID
            tracedDefID = defID
            -- local isAllied = unit.isAllied
            isAllied = unit.isAllied
            isMine = unit.isMine
            if wantTarget and not ctrl and (not isAllied) and not (defID and ignoreTargetDefID[defID]) then
                 v.defaultTarget = id
            end
            if wantSelect and not (defID and ignoreSelectDefID[defID]) and unit.isMine and not spGetUnitTransporter(id) then
                s.defaultSelect = id
            end
        else
            --it can happen if the unit got dead, (or just got out of sight afaik, need verify for sure)
            v.moddedCmd = CMD_RAW_MOVE
            return v.moddedCmd
            -- local defID = spGetUnitDefID(id)
            -- Echo('EzTarget, unit', id, defID, defID and UnitDefs[defID].name , 'is not registered in Units!','lmb?',lmb,'rmb?',rmb, Spring.GetGameSeconds(), 'defaultCmd:', engineCmd,'valid?',spValidUnitID(id),'dead?',spGetUnitIsDead(id))
        end
    end
    -- if not v.defaultTarget and v.noHelperTarget and not wantSelect then
    --     reset()
    --     return v.cmdOverride
    -- end
    -- if alt and not sel[2] then -- this let ForceMove.lua do its job
    --     -- -- Echo('reset')
    --     -- reset()
    --     -- return v.cmdOverride
    -- else
    --     -- Echo('continue')
    -- end
    v.moddedTarget, s.moddedSelect =  EzTarget(wantTarget and not v.noHelperTarget, wantSelect, selContext.hasAirAttackerUnit)
    local modSelDefID
    if s.moddedSelect then
        modSelDefID = mines[s.moddedSelect]
    end

    local canTransport = commandMap[CMD_UNLOAD_UNITS]
    local canUnload =  mySelection.isTransporting
    local canLoadLight, canLoadHeavy = mySelection.canLoadLight, mySelection.canLoadHeavy
    
    -- looking for pad under flying own unit if needed


    local padToRearm, padToExclude
    if selContext.hasAirAttackerUnit then
        if not alt and opt.findPad or alt and opt.forceExclude then
            local pad = false
            if not v.moddedTarget and defaultCMD~=CMD_REARM then
                -- if we got an air unit that can land and there is a airpad-like type around the cursor which is not the closest and no ezTarget to attack then, 
                if s.moddedSelect and s.moddedSelect ~= s.defaultSelect then
                    if airpadDefID[modSelDefID] then
                        pad = s.moddedSelect
                    end
                end
                if not pad then
                    for i,id in ipairs(minesByDist) do
                        local defID = mines[id]
                        if airpadDefID[defID] then
                            -- got a pad around the cursor that is not the closest but we take it anyway
                            pad = id
                            break
                        end
                    end
                end
                if not pad then
                    for id, defID in pairs(allied) do
                        if airpadDefID[defID] then
                            -- got a pad around the cursor that is not the closest but we take it anyway
                            pad = id
                            break
                        end
                    end
                end

                if pad then
                    if not alt then
                        v.moddedTarget = pad
                        padToRearm = pad
                    else
                        padToExclude = pad
                    end
                end
            end
        end
    end






    -- if we got a unit that can repair, and a //static// building unfinished around, and no target to attack, we target the //static// building
    -- when holding alt, point to the nearest builder with another builder and activate the guard command
    -- when not holding alt, point to the nearest unfinished static build and activate the repair command
    local buildToFinish,builderToGuard = false,false
    local unitToGuard = false



    ----- managing behaviours with alt that require active command


    if alt then
        if selContext.hasJumper then
            local fromBuilderToBuilder
            -- if selContext.hasControllableRepairer then
            --     if factoryAround then
            --         fromBuilderToBuilder = true
            --     else
            --         local selDefID = s.defaultSelect and tracedDefID
            --         if selDefID and controllableRepairerDefID[selDefID] then
            --             fromBuilderToBuilder = true
            --         end
            --     end

            -- end

            if opt.forceJump and (not fromBuilderToBuilder or onSelf) then
                if shift or CanJumpNow(jumpers) then
                    SwitchCommand('Jump', CMD_JUMP, namecom)
                    return --[[v.cmdOverride or--]] v.moddedCmd
                end
            end
        end
        if selContext.hasDgunOnAlt and opt.forceDGUN then
            local airDgun = selContext.hasAirDgun
            local commandName = (airDgun and 'Air ' or '') .. 'Manual' .. (airDgun and ' ' or '') .. 'Fire'
            if v.hasLobster then
                v.moddedTarget = false
            elseif not v.moddedTarget and v.defaultTarget and not (isMine or isAllied) then
                v.moddedTarget = v.moddedTarget or v.defaultTarget
            else
                v.moddedTarget = false
            end
            SwitchCommand(commandName, airDgun and CMD_AIR_MANUALFIRE or CMD_MANUALFIRE, namecom)
            return --[[v.cmdOverride or--]] v.moddedCmd
        elseif canTransport and canUnload and (engineCmd ~= CMD_LOAD_UNITS and (not v.moddedCmd or v.moddedCmd == CMD_RAW_MOVE or v.moddedCmd == CMD_ATTACK)) then -- giving the name of the command doesn't work for UNLOAD_UNITS
            SwitchCommand('Unload units', CMD_UNLOAD_UNITS, namecom)
            return v.moddedCmd
        elseif selContext.hasPuppy and opt.forceAttack then
            v.moddedActiveCommand = 'Attack'
            SwitchCommand('Attack', CMD_ATTACK, namecom)
            return v.moddedCmd
        elseif selContext.hasAirAttackerUnit and opt.forceExclude then
            if not padToExclude and engineCmd == CMD_REARM then
                padToExclude = s.defaultSelect or isAllied and airpadDefID[tracedDefID] and traced
                -- if v.moddedTarget then
                --     v.moddedTarget = false -- in case there is an ez targetted enemy close by
                -- end
                -- v.moddedTarget = padToExclude
            elseif v.moddedTarget then -- we override the modded target to our pad if any
                for id, defID in pairs(mines) do
                    if airpadDefID[defID] then
                        -- got a pad around the cursor that is not the closest but we take it anyway
                        padToExclude = id
                        break
                    end
                end

            end

            if padToExclude then
                SetColor(padToExclude, yellow)
                SwitchCommand('Exclude', CMD_EXCLUDE_PAD, namecom)
                return v.moddedCmd
            end
        end
    end
    -- if a moded active command has been set, the function returned
    if v.moddedActiveCommand then
        v.moddedActiveCommand = false
        spSetActiveCommand(0)
    end

    ----- managing behaviours with alt that doesnt require active command

    if alt then
        if selContext.hasControllableRepairer then
            if opt.findBuilderToGuard then
                for i, id in ipairs(minesByDist) do
                    local defID = mines[id]
                    if factoryDefID[defID] or controllableRepairerDefID[defID] then
                        if not onSelf then
                            builderToGuard = id
                            break
                        end
                    end
                end
                if builderToGuard then
                    v.moddedTarget = builderToGuard
                    SetColor(builderToGuard, yellow)
                end
            end
        end
        if not builderToGuard and opt.findUnitToGuard then
            unitToGuard = minesByDist[1]
            if unitToGuard then
                v.moddedTarget = unitToGuard
                SetColor(unitToGuard, yellow)
            end
        end


    end


    ----- managing non alt behaviour

    if not alt then

        -- switch selection (not alt) static build/unit under cursor
        if modSelDefID and opt.selSwitchStatic then
            -- if we have a modded selection, and it's a building //that is not a factory//, we look for the closest unit that is not a building //or is a factory
            if staticBuildingDefID[modSelDefID] --[[and not factoryDefID[modSelDefID]--]] then
                -- Echo('got building under mouse')
                local closest
                local minDist = math.huge
                for i, id in ipairs(minesByDist) do
                    local defID = mines[id]
                    if not staticBuildingDefID[defID] --[[or factoryDefID[defID]--]] then
                        if v.lastAcquiredSelect == id then
                            -- if we already picked that unit before, now we pick the building
                            break
                        else
                            closest = id
                            break
                        end
                    end
                end
                if closest then
                    s.moddedSelect = closest
                    SetColor(closest, pink)
                end
            else
                -- Echo('no building')
            end
        end

        if selContext.lobsters and not selContext.hasValidAttacker and v.defaultCmd == CMD_ATTACK then
            v.moddedCmd = CMD_RAW_MOVE
            v.moddedTarget = false
            return v.moddedCmd
            -- use Move with normal right click if no attacker 
        end

        if selContext.hasControllableRepairer then
            if not padToRearm then
                if v.defaultCmd == CMD_REPAIR then
                    local suppressRepair, hasCloakedConUnderAreaCloak = false, false
                    if v.moddedCmd == CMD_ATTACK then
                        suppressRepair = true
                    elseif opt.suppressRepairCloaked then
                        local time = os.clock()
                        if time > cacheCloakedRepairSuppress.time + 0.4 then
                            for id in pairs(controllableRepairersMap) do
                                if id~='n' then
                                    if spGetUnitRulesParam(id, 'areacloaked') == 1 then
                                        suppressRepair = true
                                        hasCloakedConUnderAreaCloak = true
                                        break
                                    end
                                end
                            end
                            cacheCloakedRepairSuppress.time = time
                            cacheCloakedRepairSuppress.value = hasCloakedConUnderAreaCloak
                        else
                            local value = cacheCloakedRepairSuppress.value
                            suppressRepair = value
                            hasCloakedConUnderAreaCloak = value
                        end
                    end

                    if suppressRepair then
                    -- Echo('falsified',math.round(os.clock()))
                        v.moddedCmd = false
                        v.moddedTarget = false
                        if not alt and hasCloakedConUnderAreaCloak then
                            v.moddedCmd = CMD_RAW_MOVE
                            return v.moddedCmd
                        end
                        return v.cmdOverride
                    end
                    if not v.moddedTarget and opt.findStaticRepair then -- finally also make it on default repair, so it doesnt drag a circle when pointing on the unit
                        -- find a build to finish if any
                        for i,id in ipairs(minesByDist) do
                            if not controllableRepairersMap[id] or controllableRepairersMap.n>1 then
                                local hp,maxhp,_,_,bp = spGetUnitHealth(id)
                                if bp < 1 then
                                -- if select(5,spGetUnitHealth(id))<1 then
                                    buildToFinish = id
                                    break
                                elseif not buildToFinish and not onSelf and hp<maxhp then
                                    buildToFinish = id
                                end
                            end
                        end
                        if buildToFinish then
                            v.moddedTarget = buildToFinish
                            SetColor(buildToFinish, yellow)
                        end
                        -- if ALT is held and a con is selected and a factory is around then we order to guard the factory
                    end
                end
            end
        end
    end


    --
    v.moddedCmd = v.moddedTarget and (
            (builderToGuard or unitToGuard) and CMD_GUARD
            or padToRearm and CMD_REARM
            or buildToFinish and CMD_REPAIR
            or canTransport and not alt and (canLoadLight or canLoadHeavy) and CMD_LOAD_UNITS
            or commandMap['Attack'] and CMD_ATTACK
        )
        or not alt and (
                engineCmd == CMD_GUARD
                or engineCmd == CMD_LOAD_UNITS
                or engineCmd == CMD_LOAD_ONTO
            )   
            and CMD_RAW_MOVE


        -- or canTransport and alt and CMD_UNLOAD_UNITS
    if canTransport and v.moddedCmd == CMD_LOAD_UNITS then
        return v.cmdOverride or v.moddedCmd
    end
    -- Echo("v.cmdOverride, v.moddedCmd is ", v.cmdOverride, v.moddedCmd)

    -- if Debug.EZ() and engineCmd == CMD_GUARD then
    --     return 0
    -- end
    -- Echo("spGetUnitRulesParams('areacloaked') is ",v.defaultTarget--[[, spGetUnitRulesParams('areacloaked')--]])

    -- Echo("v.defaultCmd is ", v.defaultCmd,Spring.GetDefaultCommand())


    v.moddedActiveCommand = false



    if ctrl and engineCmd~= CMD_RECLAIM then -- ctrl + move with a con will not reclaim
        return v.cmdOverride
    end

    if not (v.moddedCmd)  then
        -- Echo('...', engineCmd, alt)
        if not engineCmd 
            or onSelf and engineCmd == CMD_GUARD
            or not alt and (engineCmd == CMD_GUARD or engineCmd == CMD_RECLAIM or engineCmd == CMD_RESURRECT or engineCMD == CMD_MOVE)
        then
            v.moddedCmd = CMD_RAW_MOVE
        end
    end
    -- Echo("v.cmdOverride or v.moddedCmd is ", v.cmdOverride or v.moddedCmd)
    return v.cmdOverride or v.moddedCmd
end

function widget:CommandsChanged()
    -- Echo('CommandsChanged upd.triggered',#spGetSelectedUnits())
    if not s.selectionChanged then
        return
    end
    s.selectionChanged = false




    -- Echo('no more s.acquiredSelect',os.clock())
    -- Echo('reset by new selection', os.clock())

    v.moddedTarget,v.moddedCmd,drawUnit=nil,nil,EMPTY_TABLE
    upd.treatedFrame = false
    local selTypes = WG.selectionDefID or spGetSelectedUnitsSorted()
    sel = selection or spGetSelectedUnits()
    local customRadius = false
    local noHelperTarget =  true
    jumpers = {}
    controllableRepairersMap = {n=0}
    local hasDgunOnAlt, hasAirDgun, hasAirAttackerUnit, lobsters, hasJumper, hasPuppy, hasDgunCom = false, false, false, false, false, false, false
    local hasControllableRepairer = false
    local hasValidAttacker, hasAttacker = false, false
    for defID, units in pairs(selTypes) do
        -- applied if at least one air unit is selected
        if not hasAirAttackerUnit and airAttackerDefID[defID] then
            hasAirAttackerUnit = true
        end
        if not hasDgunOnAlt and dgunOnAltDefID[defID] then
            hasDgunOnAlt = true
        end
        if not hasAirDgun and airDgunDefID[defID] then
            hasAirDgun = true
        elseif defID == lobsterDefID then
            lobsters = units
            hasDGunOnAlt = true
        elseif defID == puppyDefID then
            hasPuppy = true
        elseif jumperDefID[defID] then
            table.merge(jumpers,units)
            hasJumper = true
        end

        if controllableRepairerDefID[defID] then
            local n = 0
            for i,id in ipairs(units) do
                controllableRepairersMap[id] = defID
                n = n + 1
            end
            controllableRepairersMap.n = n
            hasControllableRepairer = true
        end

        if noHelperTarget then
             -- applied only if all units type don't need helper
            noHelperTarget = NO_HELPER_TARGET[defID]
        end
        if not hasAttacker and defIDCanAttack[defID] then
            if defID~=lobsterDefID and not EXCEPTION_EZ[defID] then
                hasValidAttacker = true
            end
            hasAttacker = true
            -- using ezTarget if at least one type of unit want it
        end

    end

    local dGunCom = next(morphedComDGUN)
    if dGunCom and selectionMap[dGunCom]  then
        hasDgunOnAlt = true
        hasDgunCom = true
    end



    if not noHelperTarget then
        local minRadius = 10000
        local defaultRadius = opt.ezTargetRadius
        for defID in pairs(selTypes) do
            local thisRadius = CUSTOM_RADIUS[defID]
            if thisRadius then
                if type(thisRadius) == 'string' then
                    local percent = thisRadius:gsub('%%','')
                    thisRadius = math.round(defaultRadius * percent / 100)
                end
                if thisRadius<minRadius then
                    minRadius = thisRadius
                end
            end
        end
        if minRadius < 10000 then
            customRadius = minRadius
        end
    end

    v.noHelperTarget = noHelperTarget
    v.customRadius = customRadius

    -- copying relevant keys to feed API's mySelection table in order to reuse them elsewhere eventually
    selContext.hasValidAttacker             = hasValidAttacker

    mySelection.hasAttacker                 = hasAttacker


    selContext.hasJumper                    = hasJumper
    mySelection.hasJumper                   = hasJumper

    selContext.hasPuppy                     = hasPuppy
    mySelection.hasPuppy                    = hasPuppy

    selContext.hasAirAttackerUnit           = hasAirAttackerUnit
    mySelection.hasAirAttackerUnit          = hasAirAttackerUnit


    selContext.lobsters                     = lobsters
    mySelection.lobsters                    = lobsters

    selContext.hasDgunOnAlt                 = hasDgunOnAlt

    selContext.hasAirDgun                   = hasAirDgun
    mySelection.hasAirDgun                  = hasAirDgun

    mySelection.hasDgunCom                  = hasDgunCom


    selContext.hasControllableRepairer      = hasControllableRepairer
    mySelection.hasControllableRepairer     = hasControllableRepairer

    mySelection.controllableRepairersMap    = controllableRepairersMap

    mySelection.jumpers                     = jumpers

    selContext.hasTransport                 = mySelection.hasTransport



end
UpdateSelection = function(sel,newsel)
    local alt, ctrl, meta, shift = spGetModKeyState()

    local selects, ignore, selByID
    local selByID = shift and ByIDs(sel) or {}
    -- Echo('update selection',os.clock())
    -- for k,v in pairs(selByID) do
    --     Echo(k,v)
    -- end
    if s.modCtrl then
        selects = GetVisibleUnits(s.acquiredSelect)
        ignore = shift and s.acquiredSelect -- in the double click, user selected or unselected the pointed unit, we don't take it into account
    else
        -- if s.defaultSelect == s.acquiredSelect then
        --     return
        -- end
        selects, n_selects = {[s.acquiredSelect] = true}, 1
    end
    -- Echo("s.modCtrl is ", s.modCtrl)
        -- Echo('update sel in selection changed')
    local newselByID = ByIDs(newsel)
    local unselect = shift --and not s.modCtrl
    if unselect then
        for id in pairs(selects) do
            -- Echo('id',id)
            if not selByID[id] --[[and ignore~=id--]] then
                unselect = false
                break
            end
        end
    end
    -- Echo("unselect is ", unselect)
    if unselect then
        for id in pairs(selByID) do
            if selects[id] then
                selByID[id] = nil
            end
        end
    else
        for id in pairs(selects) do
            selByID[id] = true
        end
        -- for k,v in pairs(selByID) do
        --     Echo('in selByID',k,v)
        -- end
    end
    s.acquiredSelect = false
    checkForSelBox = false
    -- Echo("want",f.l(selByID)," newsel is ",f.l(newselByID))
    if not CompareIDTables(selByID,newselByID) then
        -- Echo('tables differ', ByIndex(selByID)[1])
        -- for k,v in pairs(ByIndex(selByID)) do
        --     Echo('in index',k,v)
        -- end
        -- Echo(os.clock(),"change selection")
        return ByIndex(selByID)
    -- else
    --     Echo(os.clock(),'tables are the same')
    end
    return
    -- Echo("sel[1] is ", sel[1],'s.acquiredSelect:',s.acquiredSelect)

end


function widget:SelectionChanged(newsel,less)
    s.selectionChanged = true
    -- Echo('=> selection changed','s.acquiredSelect is',s.acquiredSelect,'s.defaultSelect',s.defaultSelect,#newsel)
    if not s.acquiredSelect then
        return
    end
    local _,_,lmb = spGetMouseState()
    if lmb then
        return
    end
    checkForSelBox = false
    -- if s.acquiredSelect == s.defaultSelect then
    --     s.acquiredSelect = false
    --     checkForSelBox = false
    --     -- Echo('returned')
    --     return
    -- end
    -- if not spValidUnitID(s.acquiredSelect) or spGetUnitIsDead(s.acquiredSelect) then
    --     s.acquiredSelect = false
    --     -- checkForSelBox = false
    --     return
    -- end
    local ret = UpdateSelection(sel,newsel)
    return ret
end
function widget:DefaultCommand(type, id, engineCmd) -- NOTE: DefaultCommand run only if at least one unit is selected, we complete the Evaluation in Update when this is not  active

    upd.triggered = os.clock()
    if --[[s.selBoxActive or--]] WG.panning --[[or WG.EzSelecting--]] then
        reset()
         WG.contextCmd = engineCmd
         -- WG.cmdOverride = v.cmdOverride
        return
    end
    -- local before = table.concat({spGetActiveCommand()},', ')
    
    local ret = Evaluate(type, id, engineCmd)
    -- Echo('ret', ret,spGetActiveCommand(), 'before:', before)
    -- return ret
    WG.contextCmd = ret
    -- WG.cmdOverride = v.cmdOverride
    return ret
end




function widget:Update(dt)

    local mx,my,lmb,mmb,rmb, outsideSpring = spGetMouseState()
    local realMousePress = lmb or mmb or rmb
    if v.mousePressed and not realMousePress then
        Echo('EzTARGET CORRECTED IN UPDATE, actually NOT PRESSED ',spGetMouseState())
        Echo('MouseState:',unpack(MouseState))
        v.mousePressed = false
    end
    if realMousePress and not v.mousePressed then
        Echo('EzTARGET CORRECTED IN UPDATE, actually PRESSED ',spGetMouseState())
        Echo('MouseState:',unpack(MouseState))

        s.acquiredSelect = false
        checkForSelBox = false
        reset()
        return
    end
    if rmb then
        return
    end
    if WG.panning or WG.EzSelecting or WG.drawingPlacement then 
        s.acquiredSelect = false
        checkForSelBox = false

        reset()
        return
    end
    -- checkForSelbox is active from the left mousepress until the release or under the drag leeway just after this line
    -- we give a chance to capture a unit under the mouse if no modded selection has been captured since the click
    local captureDuringClick = checkForSelBox and not s.acquiredSelect
    if captureDuringClick and s.moddedSelect then 
        s.acquiredSelect = s.moddedSelect
        captureDuringClick = false
    end

    -- Echo("checkForSelBox in Update is ", checkForSelBox)
    if not lmb and checkForSelBox then
        checkForSelBox = false
    end
    if outsideSpring or screen0:IsAbove(mx, my) then
        if not lmb  and checkForSelBox then
            s.acquiredSelect = false
            checkForSelBox = false
            reset()
        end
        return
    end
    -- WG.PreSelection_IsSelectionBoxActive()
    s.selBoxActive = checkForSelBox and WG.PreSelection_IsSelectionBoxActive()
    if s.acquiredSelect then
        if s.selBoxActive then
            -- Echo("( (s.last_click_mx-mx)^2 + (s.last_click_my-my)^2 ) ^ 0.5 is ", ( (s.last_click_mx-mx)^2 + (s.last_click_my-my)^2 ) ^ 0.5)
            -- we give a larger leeway when time since click is very short, so the usermay have slipped the mouse in a rapid click by accident
            local mult = os.clock() - checkForSelBox < 0.2 and 1.5 or 1
            if ( (s.last_click_mx-mx)^2 + (s.last_click_my-my)^2 ) ^ 0.5 > opt.mouse_leeway * mult then
                s.acquiredSelect = false
                checkForSelBox = false
                reset()
            end
        else
            if not lmb then
                -- Echo("s.defaultSelect,s.acquiredSelect is ", s.defaultSelect,s.acquiredSelect)
                -- Echo('Update Selection in UPDATE')
                local newsel = UpdateSelection(sel,spGetSelectedUnits())
                if newsel then
                    spSelectUnitArray(newsel)
                end
                s.acquiredSelect = false
                checkForSelBox = false
                -- Echo('now acquired is false')
            end
        end
        return
    end
    -- Echo('def',spGetDefaultCommand())
    if s.selBoxActive then
        return
    end
    -- work around to know if widget:DefaultCommand() is active or not
    if IsDefaultCommandActive(dt) then
        -- NOTE: if DefaultCommand is active, we don't need to Evaluate again, as the function has been upd.triggered in the call in already
        return
    end
    local _,defaultCommand = spGetDefaultCommand()
    WG.contextCmd = defaultCommand
    -- Echo("defaultCommand is ", defaultCommand,round(os.clock()))
    if defaultCommand == nil or defaultCommand == buildMexDefID then
     -- this complement the action of DefaultCommand which is not active when nothing is selected or when mouse is out of map or with mex placement 
        if lmb  and not captureDuringClick then
            reset()
            -- Echo('returned', math.round(os.clock()))
            return
        end
        -- s.defaultSelect, s.moddedSelect = false, false
        local nature, id = spTraceScreenRay(mx,my)
        if nature == 'ground' then
            nature,id = nil, nil
        end
        -- if nature == 'unit' and spGetUnitTeam(id)==v.myTeamID then
        --     s.defaultSelect = id
        -- end
        -- local _ze
        -- _, s.moddedSelect = EzTarget(false,true)
        Evaluate(nature, id)
    end
    -- v.moddedTarget = selContext.hasValidAttacker and (opt.ezTarget or Debug.EZ()) and EzTarget()
    -- Echo(" owner: "..(wh.mouseOwner and wh.mouseOwner:GetInfo().name or 'none'))
end

function widget:MousePress(mx,my,button) 
    -- Echo('mouse press', button)
    -- local t = {}
    -- for i = 1, 2500000 do
    --     t[i] = i
    -- end
    -- for i = 1, 2500000 do
    --     t[i] = nil
    -- end
    v.mousePressed = true
    if cf2.CF2_TakeOver then -- happen when trailing and another button is clicked, this will cancel the CF2 trailing        cf2.CF2_TakeOver = false
        cf2.CF2_TakeOver = false
        wh.mouseOwner = cf2.widget
        v.cmdOverride = false
        reset()
        return --cf2.CF2:MousePress(mx, my, button)
    end
    if screen0:IsAbove(mx,my) or button == 2 then
        reset()
        -- if button == 3 then 
        --     if namecom then
        --         -- Echo('IS ABOVE, active command is ',activeCommand,namecom,'v.cmdOverride is', v.cmdOverride,'v.moddedCmd',v.moddedCmd)
        --     end
        --     -- spSetActiveCommand(0)
        --     -- return true

        --     return
        -- else
        --     return
        -- end
        -- WG.cmdOverride = 'toto'
        return
    end
    if v.clamped then
        mx,my = v.clamped[1], v.clamped[2]
    end
    local activeCommand,_,_, namecom = spGetActiveCommand()
    -- Echo("v.moddedActiveCommand is ", v.moddedActiveCommand, namecom)
    -- Echo("namecom, v.moddedActiveCommand is ", namecom, v.moddedActiveCommand)
    if namecom and namecom == v.moddedActiveCommand then
        -- when default command and active command are the same and right button is pressed, we remove the active command so the default command will be executed-
        spSetActiveCommand(0)
        -- Echo(Spring.GetGameSeconds(),'set 0, default command ?', v.moddedCmd)
        v.moddedActiveCommand = false
        activeCommand=0
        if button == 3 then
            -- should execute the default command which should be the same as the active command before we just switched it to 0
            v.acquiredTarget = v.moddedTarget or v.defaultTarget -- will be used by CustomFormation2
            -- WG.cmdOverride = 'momo'
            -- Echo('returned, moddedCmd?',v.moddedCmd,os.clock())
            return
        end
    end
    if activeCommand~=0 then
        if button == 3 then 
            -- Echo('active command is ',activeCommand,namecom,'v.cmdOverride is', v.cmdOverride,'v.moddedCmd',v.moddedCmd)
            -- spSetActiveCommand(0)
            -- return true
            WG.cmdOverride = 'zozo'
            return
        else
            return
        end
    end

    s.acquiredSelect = false

    local alt, ctrl, meta, shift = spGetModKeyState()
    if button==1 then
        checkForSelBox  = os.clock()
        -- Echo('button click', s.moddedSelect, s.defaultSelect)
        -- s.acquiredSelect = s.moddedSelect or s.defaultSelect
        -- if not s.acquiredSelect then
        --     return
        -- end
        -- s.last_click_mx,s.last_click_my = mx,my
        -- local time = os.clock()
        -- local doubleClick = time-s.clickTime <= toleranceTime
        -- -- Echo(" is ", toleranceTime, time-s.clickTime, time-s.clickTime <= toleranceTime)
        -- s.modCtrl = ctrl or doubleClick
        -- Echo("s.modCtrl ,s.acquiredSelect is ", s.modCtrl,s.acquiredSelect)
        -- s.clickTime = time
        -- return
        
        -- on shift + left click set target
        if (shift--[[ or alt--]]) and (v.moddedCmd == CMD_ATTACK or v.defaultCmd==CMD_ATTACK) then
        -- if (shift) and commandMap['Set Target'] and v.moddedCmd == CMD_ATTACK or  then
            v.acquiredTarget = v.moddedTarget or v.defaultTarget
            local tgt = v.acquiredTarget and Units[v.acquiredTarget]
            if not (tgt and tgt.isEnemy) then
                return
            end
            s.acquiredSelect = false
            checkForSelBox = false
            v.moddedCmd = CMD_UNIT_SET_TARGET
            -- Echo('set target', math.round(os.clock()))
            opts = MakeOptions(--[[true--]])
            


            return Execute(button)

        else
            s.acquiredSelect = s.moddedSelect or s.defaultSelect
            v.lastAcquiredSelect = s.acquiredSelect
            -- Echo('set last s.acquiredSelect',s.acquiredSelect)
        end
        -- Echo("s.moddedSelect or s.defaultSelect is ", s.moddedSelect, s.defaultSelect)
        local time = os.clock()
        local sameSelect = s.acquiredSelect and not sel[2] and s.acquiredSelect == sel[1]
        local doubleClick = time-s.clickTime <= toleranceTime

        -- Echo('doubleClick',doubleClick," : ", toleranceTime, time-s.clickTime, time-s.clickTime <= toleranceTime)
        s.modCtrl = ctrl or doubleClick and sameSelect
        s.clickTime = time
        s.last_click_mx, s.last_click_my = mx,my
        return

    end
    if button~=3 then
         return
    end
--[[    if alt then
        return
    end--]]
    -- local type, id = spTraceScreenRay(mx,my)

    local _,defaultCommand, _, nameDefCom = spGetDefaultCommand()

    -- local alttype, altid = type, id
    -- if type=='ground' then
    --     type,id = nil, nil
    -- end
    
    -- NOTE: if DefaultCommand is active, we don't need to Evaluate again, as the function has been upd.triggered in the call-in already
    -- if not IsDefaultCommandActive() then
        -- Echo("defaultCommand is ", defaultCommand)
        -- Evaluate(type, id, defaultCommand,'TEST')
    -- Echo("nameDefCom is ", nameDefCom, v.defaultCmd, 'v.moddedCmd', v.moddedCmd)
    -- end
    -- Echo("nameDefCom is ", nameDefCom)
    local _, activeCmdID,  _, namecom = spGetActiveCommand() 
    -- Echo("activeCmdID, namecom is ", activeCmdID, namecom)
    if namecom=='Attack' then
        -- Echo('namecom is Attack in EzTarget !',os.clock())
    end

    if namecom and namecom == v.moddedActiveCommand then
        -- when default command and active command are the same and right button is pressed, we remove the active command so the default command will be executed-
        spSetActiveCommand(0)
        v.moddedActiveCommand = false
        activeCommand=0
    end
    -- v.moddedTarget, s.moddedSelect =  EzTarget(selContext.hasValidAttacker and ((opt.ezTarget and not ctrl) or debugging), opt.ezSelect or debugging )
    v.acquiredTarget = v.moddedTarget or v.defaultTarget
    -- local _,_,_,v.defaultCmd = spGetDefaultCommand()

    if not v.clamped then 
        if nameDefCom ~= 'staticmex'  and v.moddedCmd~=CMD_UNLOAD_UNITS  then
            if not (selContext.hasValidAttacker or (selContext.hasControllableRepairer or commandMap[CMD_UNLOAD_UNITS]) and v.moddedTarget) --[[or (alt and not sel[2])--]]
                or not (v.moddedTarget or (v.defaultTarget --[[or v.defaultCmd == 'Attack'--]] ) and opt.cancelWhenDragOnDefault) then

                -- if nameDefCom == 'Attack' then
                --     local t = {'COCO',"nameDefCom is ", nameDefCom, v.moddedTarget, v.defaultTarget,
                --          v.moddedCmd, v.defaultCmd, type,id,alttype,altid}
                --     for i=1, #t do t[i] = tostring(t[i]) end
                --     Echo(table.concat(t, ', '))
                -- end
                WG.cmdOverride = nameDefCom

                return
            end
        end

    end
    opts = MakeOptions(--[[true--]]) -- using CMD_INTERNAL when ordering an attack on a target that has been SET already, if the unit is on maneuver, it will instead auto attack the nearest target
    -- Debug.Mouse('MousePress: '..mx..', '..my..', '..button)
    -- Echo("v.cmdOverride is ", v.cmdOverride)
    -- if select(2,spGetDefaultCommand()) ~= v.cmdOverride then
    --     Echo(os.clock(),"Default command is not Raw move !",spGetDefaultCommand())
    -- end
    cf2.CF2 = cf2.widget
    cf2.lastx,cf2.lasty,cf2.lastclock=mx,my,osclock()
    -- check if cf2.CF2 want control
    if cf2.CF2 then
        v.cmdOverride=CMD_RAW_MOVE -- this will change briefly the return of widget:DefaultCommand that is called by cf2.CF2


        cf2.CF2 = cf2.CF2:MousePress(cf2.lastx,cf2.lasty,button,'by Ez') and cf2.CF2
        if cf2.CF2 then
            mempoints = {n=0}
            return true
        else
            -- if namecom=='Attack' then
            --     Echo('CF2 rejected but namecom is Attack !','actve command is ',activeCommand,namecom,'v.cmdOverride is', v.cmdOverride,'v.moddedCmd',v.moddedCmd)
            -- end
            v.cmdOverride=false
        end
    -- elseif cf2.widget then
    --     Echo('CF2 didnt take this !',os.clock())
    end
    v.cmdOverride = false
    if not v.defaultTarget then
        Execute(button) -- ordering on click instead of release as usual in default, is it a problem? responsiveness on laggy game should be better on click. 
    end
    local ret = not not (v.moddedTarget or v.defaultTarget)
    -- if nameDefCom == 'Attack' and not ret then
    --     Echo('EzTarget let the area attack pass !')
    -- end
    -- WG.cmdOverride = 'popo'
    return ret
end

function widget:MouseMove(mx,my,dx,dy,button)
    -- as soon as the mouse move slightly and the click lasted for long enough, we give it away to cf2.CF2 and send back the missing points
    if not cf2.CF2 or button == 1  then
        return
    end
    if opt.clampToWorld then
        local _mx, _my
        _mx,_my = ClampScreenPosToWorld(mx,my)
        if _mx and (mx~=_mx or my~=_my) then
            v.clamped = {_mx,_my}
            mx, my = _mx, _my
        end
    end

    if cf2.CF2_TakeOver then
        return cf2.CF2:MouseMove(mx,my,dx,dy,button)
    else
        local off = max(abs(mx-cf2.lastx),abs(my-cf2.lasty))

        if  osclock()-cf2.lastclock<0.2 and off<opt.target_mouse_leeway * 1.5 -- up the leeway by 50% if the release occured fast
        or off<opt.target_mouse_leeway
        then
            if mempoints.n==0 then
                mempoints[1] = {cf2.lastx,cf2.lasty}
                mempoints.n=1
            end
            mempoints.n=mempoints.n+1
            mempoints[mempoints.n] = {mx,my}
            return
        end
        Debug.CF2('giving away control to cf2.CF2')
        cf2.CF2_TakeOver = true
        v.cmdOverride = CMD_RAW_MOVE
        for i=1,mempoints.n do
            local point = mempoints[i] 
            cf2.CF2:MouseMove(point[1],point[2],dx,dy,button)
        end
        return cf2.CF2:MouseMove(mx,my,dx,dy,button)
    end
end
-- always trigger at mouse press
function BeforeMousePress(mx, my, button, from) 
    -- Echo('mouse press',button,'from',from,os.clock())
    v.mousePressed = MouseState[3] or MouseState[4] or MouseState[5]
end
function AfterMousePress(mx, my, button, from) 
    -- Echo('mouse press',button,'from',from,os.clock())
    v.mousePressed = MouseState[3] or MouseState[4] or MouseState[5]
end

-- trigger if any button release when a mouse has been locked
function BeforeMouseRelease(mx, my, button, from)
    v.mousePressed = MouseState[3] or MouseState[4] or MouseState[5]
end
-- trigger after any mouse release, even if the mouse is actually just repressed (can happen only if mouse is not locked), in that case, BeforeMousePress will be called just after and spGetMouseState or WG.MouseState will give the button actually pressed
function AfterMouseRelease(mx, my, button, from)
    v.mousePressed = MouseState[3] or MouseState[4] or MouseState[5]
    -- Echo('mouse release',from,button, v.mousePressed,MouseState[3], MouseState[4], MouseState[5])
end

function widget:MouseRelease(mx,my,button)
    Debug.Mouse('Mouse Release '..mx,my,button)
    local mx,my,lmb,mmb,rmb, outsideSpring = spGetMouseState()
    v.mousePressed = (lmb or mmb or rmb)
    v.cmdOverride = false
    if not cf2.CF2 then -- 
        return
    end
    if button==1 then
        return
    end

    if opt.clampToWorld then
        local _mx, _my
        _mx,_my = ClampScreenPosToWorld(mx,my)
        if mx~=_mx or my~=_my then
            v.clamped = {_mx,_my}
            mx, my = _mx, _my
        end
    end
    if cf2.CF2_TakeOver then
        cf2.CF2_TakeOver = false
        Debug.CF2("CF2 took over")
        return cf2.CF2:MouseRelease(mx,my,button)
    else
        if v.acquiredTarget or v.clamped or v.defaultCmd == buildMexDefID then
            Debug.CF2("processing on release...")
            -- tell CustomFormation2 to cancel the operation by giving it the opposite button
            local cancel = Execute(button)
            cf2.CF2:MouseRelease(cf2.lastx,cf2.lasty,cancel and (button==1 and 3 or 1) or button)
            -- local alt, ctrl, meta, shift = spGetModKeyState()

            -- if alt or v.moddedTarget and not v.defaultTarget then
            -- Echo("v.moddedTarget,v.moddedCmd is ", v.acquiredTarget,v.moddedCmd,v.defaultCmd)
            return cancel
            -- if v.acquiredTarget then
                
            --     Echo('execute')
            --     return Execute(button)
            -- end
            -- end
            -- return 
        end
    end

end

-- function widget:UnitCommandNotify(id,cmd,params,opts)
--     if Debug.UC() then
--         Echo(id..' received: v.cmd: '..cmd..',\nparams: '..unpackstr(table.round(params))..'\nopts: '..unpackstr(opts))
--     end
-- end
-- function widget:CommandNotify(cmd,params,opts)
--     if Debug.UC() then
--         Echo('Command received, cmd: '..cmd..',\nparams: '..unpackstr(table.round(params))..'\nopts: '..unpackstr(opts))
--     end
-- end
-- function widget:UnitCommand(id,defID,teamID,cmd,params)
--     if Debug.UC() then
--         Echo(id..' points ordered '..cmd, unpack(table.round(params)))
--     end
-- end

function widget:KeyPress(key,m) 
    mods = m
    -- Echo('key pressed',key)
    -- for k,v in pairs(m) do
    --     Echo(k,v)
    -- end
    if key == 107 then -- K
        local id = WG.PreSelection_GetUnitUnderCursor()
        if id then
            -- local def = UnitDefs[spGetUnitDefID(id)]
            -- for k,v in def:pairs() do
            --     if k:lower():find('trans') then
            --         Echo(k,v)
            --     end
            -- end
        end
    end
    if not isRepeat then
        upd.keyChanged = true
        -- return Debug.CheckKeys(key,m)
    end
    -- return v.panning
end

function widget:KeyRelease(key,m)
    mods = m
    upd.keyChanged = true
    -- return v.panning
end

Execute = function() -- execute a single target cmd if CF2 didnt take over to make a trail
    if v.defaultCmd == buildMexDefID then
        local mx, my = spGetMouseState()
        local _, pos = spTraceScreenRay(mx,my,true,true,true,false)
        if not pos then
            return
        end
        pos[4], pos[5], pos[6] = nil
        if wh:CommandNotify(v.defaultCmd,pos,opts) then
            return true
        else
            spGiveOrder(cmd,TARGET_TABLE,opts.coded)
            return true
        end
    end
    local cmd = v.moddedCmd or v.defaultCmd

    if not cmd or cmd == CMD_RAW_MOVE or  not v.acquiredTarget or not spValidUnitID(v.acquiredTarget) or spGetUnitIsDead(v.acquiredTarget) then

        return
    end
    -- Echo("v.acquiredTarget,v.moddedCmd is ", v.acquiredTarget,v.moddedCmd)
    TARGET_TABLE[1] = v.acquiredTarget
    if not wh:CommandNotify(cmd,TARGET_TABLE,opts) then
        spGiveOrder(cmd,TARGET_TABLE,opts.coded)
    end
    if spGetActiveCommand()~=0 then
        Echo(os.clock(),'Active Command should have been 0 !')
        -- spSetActiveCommand(0)
    end
    return true
end

------

do -- a better version exist now in a separate widget
    local spWorldToScreenCoords = Spring.WorldToScreenCoords
    local mapSizeX, mapSizeZ = Game.mapSizeX,Game.mapSizeZ
    local spTraceScreenRay = Spring.TraceScreenRay
    local spGetGroundHeight = Spring.GetGroundHeight
    local clamp = function(x,z,off)
        local off = off or 1
        if x>mapSizeX - off then
            x=mapSizeX - off
        elseif x<off then
            x=off
        end

        if z>mapSizeZ - off then
            z=mapSizeZ - off
        elseif z<off then
            z=off
        end
        return x,z
    end
    local function process(center,height)
        -- local newY = math.max(center[5] - height, 0)
        local newY = center[5] - height
        local mx, my = spWorldToScreenCoords(center[4],newY,center[6])
        local center2 = {center[4],newY,center[6]}
        local _,test = spTraceScreenRay(mx,my,true,true,true,false)
        if not test then
            return
        end
        for i=1,3 do table.remove(test,1) end

        test[1], test[3] = clamp(test[1],test[3],8)
        test[2] = spGetGroundHeight(test[1],test[3])
        return mx,my,test, center2
    end
    ClampScreenPosToWorld = function (mx,my)
        if not mx then
            mx, my = spGetMouseState()
        end
        local center2,center3,center4
        local nature,center
        nature,center = spTraceScreenRay(mx,my,true,true,true,false)
        
        local center2 = center[4] and {center[4],center[5],center[6]} -- NOTE: when mouse is at the very bottom left then come back, center got only 3 value
        -- when mouse fall into the sky
        -- we use the coord from the sky, but the trace goes to 0 height
        -- which will offset when clamping back to map bounds and map height
        -- to avoid this we reask mouse pos from that sky position but lowered by the groundheight of this position
        -- then we reask the world sky version from this new screen pos that will give us a negative offset of the world pos that will be reoffsetted when clamped
        if not center then return end
        -- debugging
        -- local cx,cy,cz,c2x,c2y,c2z = unpack(center)
        -- local height = spGetGroundHeight(center[4],center[6])
        -- Echo(nature .. ' : ' .. round(cx),round(cy),round(cz) .. '   |   ' .. round(c2x),round(c2y),round(c2z) .. '| height: '.. round(height))
        --
        local offmap
        if nature == 'sky' then
            offmap = true
            local test
            local height, newY

            height = spGetGroundHeight(center[4],center[6])
            mx,my,test = process(center,height)
            if not test then
                return
            end
            local correct 
            -- correct = math.abs(height - test[2]) > math.abs(height/2)
             -- Echo("math.abs(height - test[2]) is ", math.abs(height - test[2]))
            -- Echo("newY,'vs',test[2] is ", height,'vs',test[2],'correct',correct,(height + test[2]) / 2)
            correct = true
            if correct then
                height = (height + test[2]) / 2
                mx,my,test = process(center,height)
                if not test then
                    return
                end

            end
            center[1], center[2], center[3] = test[1], test[2], test[3]
            mx, my = spWorldToScreenCoords(unpack(center)) 
            -- nature,center = spTraceScreenRay(mx,my,true,true,false,false)
            -- if not center then
            --     return
            -- end

        end
        -- Echo("h,h2 is ", h,h2)
        return mx,my, center, center2, center3, center4, offmap
    end
    ClampScreenPosToWorld = WG.ClampScreenPosToWorld or ClampScreenPosToWorld
end

do --- EzTarget ---

    local iconTypesPath = LUAUI_DIRNAME .. "Configs/icontypes.lua"
    local icontypes = VFS.FileExists(iconTypesPath) and VFS.Include(iconTypesPath)
    local _, iconFormat = VFS.Include(LUAUI_DIRNAME .. "Configs/chilitip_conf.lua" , nil, VFS.ZIP)
    local iconSizeByDefID = {}
    for defID,def in ipairs(UnitDefs) do
        if def.name == 'shieldbomb' then
            iconSizeByDefID[defID] = 1.8
        else
            iconSizeByDefID[defID] = ( icontypes[(def.iconType or "default")] or icontypes["default"] ).size or 1.8
        end
    end

    local spWorldToScreenCoords = Spring.WorldToScreenCoords
    local spGetMouseState = Spring.GetMouseState

    local spGetCameraState = Spring.GetCameraState
    local spGetCameraPosition = Spring.GetCameraPosition
    local spGetGroundHeight = Spring.GetGroundHeight
    local spGetUnitDefID = Spring.GetUnitDefID
    local ceil,min = math.ceil,math.min
    local spGetUnitsInCylinder = Spring.GetUnitsInCylinder
    local mapSizeX, mapSizeZ = Game.mapSizeX,Game.mapSizeZ
    local spIsUnitIcon = Spring.IsUnitIcon
    local spGetGroundHeight = Spring.GetGroundHeight
    local red = {unpack(f.COLORS.red)}
    local blue = {unpack(f.COLORS.blue)}
    local yellow = {unpack(f.COLORS.yellow)}
    -- local lightblue = {unpack(f.COLORS.lightblue)}
    local white = {unpack(f.COLORS.white)}
    local darkred = {unpack(f.COLORS.darkred)}
    local green = {unpack(f.COLORS.green)}
    green[4] = 0.7
    local lightgreen = {unpack(f.COLORS.lightgreen)}
    local teal = {unpack(f.COLORS.teal)}
    local yellow = {unpack(f.COLORS.yellow)}
    local lightred = {unpack(f.COLORS.lightred)}
    local orange = {unpack(f.COLORS.orange)}
    local yellow = {unpack(f.COLORS.yellow)}
    local white = {unpack(f.COLORS.white)}
    local cos,sin,pi = math.cos, math.sin, math.pi
    local spGetUnitsInScreenRectangle = Spring.GetUnitsInScreenRectangle
    
    local freeze

--- OLD
    EzTarget = function(getTarget, getSelect)

        if cancelEz then return end
        if freeze then return end  
        if not (getTarget or (getSelect)) then
            return
        end

        local mx,my = spGetMouseState()

        local center, center2
        local r = opt.ezTargetRadius
        local th = 1--EZTARGET_THRESHOLD
        drawCircle = {} -- for ops and debug
        points={} -- for debug
        enemies, mines={}, {}
        local unitPool = {}
        local id, pos
        local _
        local clamp = opt.clampToWorld
        v.clamped = false
        local offmap
        -- local clampedCenter
        if clamp then
            local _mx, _my
            _mx,_my, center, center2 = ClampScreenPosToWorld(mx,my)
            if _mx and (mx~=_mx or my~=_my) then
                v.clamped = {_mx,_my}
                mx, my = _mx, _my
            end
        else
            local nature
            nature, center = spTraceScreenRay(mx,my,true,true,true,false)
            if nature == 'sky' then
                offmap = true
            end
        end
        -- _,_, clampedCenter, center2 = ClampScreenPosToWorld(mx,my)
        if not center then
            return
        end

        local expensive = true
        if expensive then
            -- unit at this pos ignoring water line
            type, id = spTraceScreenRay(mx,my,false,false,true,true)
            if type=='unit' then
                unitPool[id] = true
            end
            -- unit at this pos in undersea
            type, id = spTraceScreenRay(mx,my,false,false,true,false)
            if type=='unit' then
                unitPool[id]=true
            end
        end

        -- check if we're not too zoomed in, and note the max distance in elmos possible
        local step = 2/10

        local maxdist = 0

        for i=-1,1,step do
            -- trace points all around the cursor
            angle = i*pi
            local mx,my = mx+sin(angle)*r,my+cos(angle)*r
            if expensive then
                -- unit at this pos ignoring water line
                type, id = spTraceScreenRay(mx,my,false,false,true,true)
                if type=='unit' then
                    unitPool[id] = true
                end
                -- unit at this pos in undersea
                type, id = spTraceScreenRay(mx,my,false,false,true,false)
                if type=='unit' then
                    unitPool[id]=true
                end
            end
            -- ground pos in the world map
            nature, pos = spTraceScreenRay(mx,my,true,true,true,false)
            if pos then
                -- get the farthest dist on world, from points all around the cursor
                -- for i=1,#pos do pos[i] = round(pos[i]) end
                -- Echo(#points+1,"=> ", unpack(pos))
                if nature=='ground' then
                    -- local dist=round((center[1]-pos[1])^2+(center[3]-pos[3])^2)
                    local dist=((center[1]-pos[1])^2+(center[3]-pos[3])^2)^0.5
                    dist = max(dist,MIN_SEARCH_RADIUS)
                    if dist<th then
                        -- Echo(i,'dist is too short !',dist)
                        return
                    else
                        if dist>maxdist then maxdist = dist end
                        -- Echo(i,'dist is ok',dist)
                    end
                end
            end
        end
        -- get all units in the max distance possible and filter them out depending on their distance from screen cursor
        -- in case of wobbling radar dots, spGetUnitsInCylinder might not catch the unit that is falling under our screen radius
        -- because the function care bout the real position of unit
        -- then we have to enlarge the circle slightly
        local wobbling = 50
        if not offmap then
            local around = spGetUnitsInCylinder(center[1],center[3],maxdist+wobbling) 
            for i=1,#around do
                local id = around[i]
                unitPool[id] = true
            end
        end
        -- Echo('around',#around)
        if Debug.EZ() and not offmap then
            -- make some ground circle for debugging
            center[4] = maxdist
            center[5] = lightgreen
            center[6] = 1 -- alpha
            center[7] = true -- following ground
            center[8] = false -- not plain
            center[9] = false -- on world (not on screen)
            drawCircle.maxdist = center
            local c = {unpack(center)}
            c[4]=maxdist+wobbling
            c[5]=white
            c[6] = 0.75
            drawCircle.wobbling = c
        end
        local mindistEnemy, closestEnemy = huge
        local mindistMine, closestMine = huge
        local wantEnemy = getTarget
        local wantMine = getSelect or (selContext.hasAirAttackerUnit and getTarget)
        enemiesByDist = {}
        minesByDist = {}
        poses = {}

        -- Echo('screen radius is '..round(r),'there are '..#around..' units around.')
        local str = ''
        -- local state = spGetCameraState()
        -- local cx,cy,cz = spGetCameraPosition()
        local cx,cy,cz = unpack(Cam.pos)
        -- local camHeight = state.height
        -- local px,pz = state.px,state.pz
        for id in pairs(unitPool)  do
            local unit = Units[id]
            if unit then
                -- local isEnemy, isMine = not spIsUnitAllied(id), spGetUnitTeam(id) == v.myTeamID
                local isEnemy, isMine = unit.isEnemy, unit.isMine
                -- local defID = spGetUnitDefID(id)
                local defID = unit.defID
                if isEnemy and wantEnemy or isMine and wantMine then
                    local bx,by,bz,x,y,z = unit:GetPos(3,true)
                    if x then
                        -- local x,y,z = spGetUnitPosition(id)
                        local gy = spGetGroundHeight(x,z)
                        -- if y == gy then
                        --     local height = UnitDefs[defID].height
                        --     y = y + height/2
                        -- end
                        -- local def = UnitDefs[defID]
                        -- local heightOfIcon = iconSizeByDefID[defID] * ratioSize * 64
                        -- max(camHeight,1000)/1000
                        
                        local distFromCam = ( (cx-x)^2 + (cy-y)^2 + (cz-z)^2 ) ^ 0.5
                        -- if id == 31007 then
                        -- getting the center pos of icon
                        local isIcon = isIcon[id]
                        if isIcon and defID then
                            local IconWorldHeight = iconSizeByDefID[defID]  * 22 * (1+ (distFromCam-6000)/10000 )
                            -- if id==13857 then
                            --     Echo("IconWorldHeight is ", IconWorldHeight,'(size: '..iconSizeByDefID[defID]..', mult: '..(1+ (distFromCam-6000)/10000 )..')','vs',y-gy)
                            -- end
                            -- IconWorldHeight = 0
                            -- local height = max(y-gy, IconWorldHeight)
                            -- if id==13857 then
                                -- Echo(y,gy,"y-gy", y-gy,"IconWorldHeight is", IconWorldHeight,'defID',defID,'name',UnitDefs[defID].name, 'icon size is', iconSizeByDefID[defID])
                            -- end
                            if y-gy<IconWorldHeight then
                                -- Echo('y: ' .. y .. ' => ' .. gy + IconWorldHeight)   
                                y = gy + IconWorldHeight
                            end
                            -- Echo('icon size mult',iconSizeByDefID[defID],cx,cy,cz,"distFromCam is ", distFromCam,'size on screen', vsy * (20/distFromCam))
                        end
                        -- end
                        -- f.Page(icontypes[def.iconType])
                        local sx,sy = spWorldToScreenCoords(x,y,z) 
                        -- local x,y,z = spGetUnitPosition(id,true)
                        -- Echo("sizeOfIcon is ", sizeOfIcon,'height',height)
                        -- y = gy + math.max(height,)
                        -- local isIcon = spIsUnitIcon(id)
                        -- Echo(",isIcon,y is ",isIcon,y)

                        -- local corrected
                        -- if isIcon then
                        --     local gy = spGetGroundHeight(x,z)
                        --     local height = y-gy
                        --     local limit = 75
                        --     if gy>0 and y<gy+limit then
                        --         local newy = gy+limit
                        --        corrected = {x,y,z}
                        --        y=newy
                        --     end
                        -- end
                        -- Echo('height',y-spGetGroundHeight(x,z))
                        -- local gy = spGetGroundHeight(x,z)
                        -- local gsx,gsy = spWorldToScreenCoords(x,gy,z) 
                        -- local srcDistFromGround = ( (gsx-sx)^2 + (gsy-sy)^2 ) ^ 0.5
                        -- local height = y-gy
                        -- Echo("srcDistFromGround is ", srcDistFromGround)
                        local scrDist = ((mx-sx)^2 + (my-sy)^2)^0.5
                        -- str = str .. ', [' .. id .. '] dist: ' .. round(scrDist)
                        -- local nature, pos = spTraceScreenRay(sx,sy,true,true,true,false)
                        local inRange = scrDist <=r
                        if  inRange then
                            if isEnemy and wantEnemy and not ignoreTargetDefID[defID] then
                                if not v.customRadius or scrDist<=v.customRadius then
                                    if scrDist<mindistEnemy then
                                        mindistEnemy = scrDist
                                        closestEnemy = id
                                    end
                                    enemies[id]=scrDist
                                    poses[id] = {sx,sy,corrected = corrected}
                                end
                            elseif isMine and wantMine and not (spGetUnitNoSelect(id) or spGetUnitTransporter(id) or ignoreSelectDefID[defID]) then
                                if scrDist<mindistMine then
                                    mindistMine = scrDist
                                    closestMine = id
                                end
                                mines[id]=scrDist
                                poses[id] = {sx,sy,corrected = corrected}
                                table.insert(minesByDist,id)
                            end
                        end
                    end
                end
            end
        end
        table.sort(minesByDist,SortMines)
        table.sort(enemiesByDist,SortEnemies)
        -- f.Page(Spring.GetCameraState())
        -- Echo(str)
        if closestEnemy then
            -- local gx,gy,gz,x,y,z = spGetUnitPosition(closestEnemy,true)
            local sx,sy = unpack(poses[closestEnemy])
            drawCircle[closestEnemy] = {sx,sy,0,SPOT_RADIUS,orange,1,false,true,true,true}
            -- enemies[closestEnemy]=nil
        end
        if closestMine then
            -- local gx,gy,gz,x,y,z = spGetUnitPosition(closestMine,true)
            local sx,sy = unpack(poses[closestMine])

            drawCircle[closestMine] = {sx,sy,0,SPOT_RADIUS,lightgreen,1,false,true,true,true}
            -- Echo("size is ", iconSizeByDefID[spGetUnitDefID(closestMine)])
            local defID = spGetUnitDefID(closestMine)
            local height = UnitDefs[defID].height
            -- if poses[closestMine].corrected then
            --     sx,sy = spWorldToScreenCoords(unpack(poses[closestMine].corrected))
            --     drawCircle[closestMine .. 'bis'] = {sx,sy,0,SPOT_RADIUS,red,1,false,true,closestMine,true}
            -- end
            -- mines[closestMine]=nil
        end

        ------ debugging show colored dots on max positions
        if Debug.EZ() then
            local n=1
            points[#points+1]=center
            center.color = green
            if center2 then
                points[#points+1]=center2
                center2.color = yellow
            end

            if center4 then
                points[#points+1]=center4
                center4.color = white
            end
            if center3 then
                points[#points+1]=center3
                center3.color = orange
            end

            for i=-1,1,step do
                angle = i*pi
                local mx,my = mx+sin(angle)*r,my+cos(angle)*r
                nature, pos = spTraceScreenRay(mx,my,true,true,true,false)
                if pos then
                    n = n+1
                    points[#points+1]=pos

                    if nature=='sky' then
                        for k=1,3 do table.remove(pos,1) end
                        pos.color = red
                    else
                        pos.color= blue
                    end

                end
            end
            for id in pairs(enemies) do
                if id ~= closestEnemy then
                    -- local gx,gy,gz,x,y,z = spGetUnitPosition(id,true)
                    local sx,sy = unpack(poses[id])
                    drawCircle[id] = {sx,sy,0,SPOT_RADIUS,darkred,0.5,false,true,true,true}
                end
            end
            for id in pairs(mines) do
                if id ~= closestMine then
                    -- local gx,gy,gz,x,y,z = spGetUnitPosition(id,true)
                    local sx,sy = unpack(poses[id])
                    drawCircle[id] = {sx,sy,0,SPOT_RADIUS,lightgreen,0.5,false,true,true,true}
                end
                -- local x,y,z = spGetUnitPosition(id)
                -- y = spGetGroundHeight(x,z)
                -- local sx,sy = spWorldToScreenCoords(x,y,z)
                -- drawCircle[id .. 'ground'] = {sx,sy,0,SPOT_RADIUS,darkred,1,false,true,id,true}
            end
        end
        ---------
        return closestEnemy, closestMine
    end
---------


    local cacheNoSelect = setmetatable({}, {__mode = 'k'})
    do
        local oldSpGetUnitNoSelect = spGetUnitNoSelect
        function spGetUnitNoSelect(id,cached) -- barely changing anything
            if cached[id] == nil then
                cached[id] = oldSpGetUnitNoSelect(id)
            end
            return cached[id]
        end
    end
    local tsort, tinsert = table.sort, table.insert -- much faster
    EzTarget = function(getTarget, getSelect, wantAllied)

        if cancelEz then return end
        if freeze then return end  
        if not (getTarget or (getSelect)) then
            return
        end

        local mx,my = spGetMouseState()

        local center, center2
        local rSelect = opt.ezTargetRadius
        local rTarget = v.customRadius or rSelect
        local rMax = math.max(rSelect, rTarget)
        local th = 1--EZTARGET_THRESHOLD
        drawCircle = {} -- for ops and debug
        points={} -- for debug
        enemies, mines, allied = {}, {}, {}
        local unitPool = {}
        local id, pos
        local _
        local clamp = opt.clampToWorld
        v.clamped = false
        local offmap
        -- local clampedCenter
        if clamp then
            local _mx, _my
            _mx,_my, center, center2 = ClampScreenPosToWorld(mx,my)
            if _mx and (mx~=_mx or my~=_my) then
                v.clamped = {_mx,_my}
                mx, my = _mx, _my
            end
        else
            local nature
            nature, center = spTraceScreenRay(mx,my,true,true,true,false)
            if nature == 'sky' then
                offmap = true
            end
        end
        -- _,_, clampedCenter, center2 = ClampScreenPosToWorld(mx,my)
        if not center then
            return
        end


        -- check if we're not too zoomed in, and note the max distance in elmos possible


        -- get all units in the max distance possible and filter them out depending on their distance from screen cursor
        -- in case of wobbling radar dots, spGetUnitsInCylinder might not catch the unit that is falling under our screen radius
        -- because the function care bout the real position of unit
        -- then we have to enlarge the circle slightly
        local wobbling = 50


        local mindistEnemy, closestEnemy = huge
        local mindistMine, closestMine = huge
        local mindistAllied, closestAllied = huge
        local wantEnemy = getTarget
        local wantMine = getSelect or (selContext.hasAirAttackerUnit and getTarget)
        -- enemiesByDist = {}
        minesByDist, mbd = {}, 0
        poses = {}

        -- Echo('screen radius is '..round(r),'there are '..#around..' units around.')
        local str = ''
        -- local state = spGetCameraState()
        -- local cx,cy,cz = spGetCameraPosition()
        local cx,cy,cz = unpack(Cam.pos)
        -- local camHeight = state.height
        -- local px,pz = state.px,state.pz
        local cached = next(cacheNoSelect)
        if not cached then
            cached = {}
            cacheNoSelect[cached] = true
        end
        for _, id in pairs(spGetUnitsInScreenRectangle(mx - rMax, my - rMax, mx + rMax, my + rMax))  do
            local unit = Units[id]
            if unit then
                -- local isEnemy, isMine = not spIsUnitAllied(id), spGetUnitTeam(id) == v.myTeamID
                local isEnemy, isMine, isAllied = unit.isEnemy, unit.isMine, unit.isAllied
                -- local defID = spGetUnitDefID(id)
                local defID = unit.defID
                if isEnemy and wantEnemy or isMine and wantMine or wantAllied and isAllied then
                    local bx,by,bz,x,y,z = unit:GetPos(1,true)
                    if x then
                        -- local x,y,z = spGetUnitPosition(id)
                        local gy = spGetGroundHeight(x,z)
                        -- if y == gy then
                        --     local height = UnitDefs[defID].height
                        --     y = y + height/2
                        -- end
                        -- local def = UnitDefs[defID]
                        -- local heightOfIcon = iconSizeByDefID[defID] * ratioSize * 64
                        -- max(camHeight,1000)/1000
                        
                        local distFromCam = ( (cx-x)^2 + (cy-y)^2 + (cz-z)^2 ) ^ 0.5

                        -- if id == 31007 then
                        -- getting the center pos of icon
                        local isIcon = isIcon[id]
                        if isIcon and defID then
                            local IconWorldHeight = iconSizeByDefID[defID]  * 22 * (1+ (distFromCam-6000)/10000 )
                            -- if id==13857 then
                            --     Echo("IconWorldHeight is ", IconWorldHeight,'(size: '..iconSizeByDefID[defID]..', mult: '..(1+ (distFromCam-6000)/10000 )..')','vs',y-gy)
                            -- end
                            -- IconWorldHeight = 0
                            -- local height = max(y-gy, IconWorldHeight)
                            -- if id==13857 then
                                -- Echo(y,gy,"y-gy", y-gy,"IconWorldHeight is", IconWorldHeight,'defID',defID,'name',UnitDefs[defID].name, 'icon size is', iconSizeByDefID[defID])
                            -- end
                            if y-gy<IconWorldHeight then
                                -- Echo('y: ' .. y .. ' => ' .. gy + IconWorldHeight)   
                                y = gy + IconWorldHeight
                            end
                            -- Echo('icon size mult',iconSizeByDefID[defID],cx,cy,cz,"distFromCam is ", distFromCam,'size on screen', vsy * (20/distFromCam))
                        end
                        -- end
                        -- f.Page(icontypes[def.iconType])
                        local sx,sy = spWorldToScreenCoords(x,y,z) 
                        -- local x,y,z = spGetUnitPosition(id,true)
                        -- Echo("sizeOfIcon is ", sizeOfIcon,'height',height)
                        -- y = gy + math.max(height,)
                        -- local isIcon = spIsUnitIcon(id)
                        -- Echo(",isIcon,y is ",isIcon,y)

                        -- local corrected
                        -- if isIcon then
                        --     local gy = spGetGroundHeight(x,z)
                        --     local height = y-gy
                        --     local limit = 75
                        --     if gy>0 and y<gy+limit then
                        --         local newy = gy+limit
                        --        corrected = {x,y,z}
                        --        y=newy
                        --     end
                        -- end
                        -- Echo('height',y-spGetGroundHeight(x,z))
                        -- local gy = spGetGroundHeight(x,z)
                        -- local gsx,gsy = spWorldToScreenCoords(x,gy,z) 
                        -- local srcDistFromGround = ( (gsx-sx)^2 + (gsy-sy)^2 ) ^ 0.5
                        -- local height = y-gy
                        -- Echo("srcDistFromGround is ", srcDistFromGround)
                        local scrDist = ((mx-sx)^2 + (my-sy)^2)^0.5
                        -- str = str .. ', [' .. id .. '] dist: ' .. round(scrDist)
                        -- local nature, pos = spTraceScreenRay(sx,sy,true,true,true,false)
                        local inMaxRange = scrDist <= rMax
                        if  inMaxRange then
                            if isEnemy and wantEnemy and not ignoreTargetDefID[defID] then
                                if scrDist <= rTarget then
                                    -- if not v.customRadius or scrDist<=v.customRadius then
                                        if scrDist<mindistEnemy then
                                            mindistEnemy = scrDist
                                            closestEnemy = id
                                        end
                                        enemies[id]=defID
                                        poses[id] = {sx,sy,corrected = corrected}
                                    -- end
                                end
                            elseif scrDist <= rSelect then
                                if isMine and wantMine and not (spGetUnitNoSelect(id, cached) or spGetUnitTransporter(id) or ignoreSelectDefID[defID]) then
                                    if scrDist<mindistMine then
                                        mindistMine = scrDist
                                        closestMine = id
                                    end
                                    mines[id]=defID
                                    poses[id] = {sx,sy,corrected = corrected}
                                    mbd = mbd + 1
                                    minesByDist[mbd] = id
                                    -- tinsert(minesByDist,id)
                                elseif isAllied and wantAllied and EzAlliedDefID[defID] then
                                    if scrDist<mindistAllied then
                                        mindistAllied = scrDist
                                        closestAllied = id
                                    end
                                    allied[id]=defID
                                    poses[id] = {sx,sy,corrected = corrected}
                                end
                            end
                        end
                    end
                end
            end
        end
        tsort(minesByDist,SortMines)
        -- tsort(enemiesByDist,SortEnemies)
        -- f.Page(Spring.GetCameraState())
        -- Echo(str)
        if closestEnemy then
            -- local gx,gy,gz,x,y,z = spGetUnitPosition(closestEnemy,true)
            local sx,sy = unpack(poses[closestEnemy])
            drawCircle[closestEnemy] = {sx,sy,0,SPOT_RADIUS,orange,1,false,true,true,true}
            -- enemies[closestEnemy]=nil
        end
        if closestMine then
            -- local gx,gy,gz,x,y,z = spGetUnitPosition(closestMine,true)
            local sx,sy = unpack(poses[closestMine])

            drawCircle[closestMine] = {sx,sy,0,SPOT_RADIUS,teal,1,false,true,true,true}
            -- Echo("size is ", iconSizeByDefID[spGetUnitDefID(closestMine)])
            local defID = spGetUnitDefID(closestMine)
            local height = UnitDefs[defID].height
            -- if poses[closestMine].corrected then
            --     sx,sy = spWorldToScreenCoords(unpack(poses[closestMine].corrected))
            --     drawCircle[closestMine .. 'bis'] = {sx,sy,0,SPOT_RADIUS,red,1,false,true,closestMine,true}
            -- end
            -- mines[closestMine]=nil
        end
        if closestAllied then
            -- local gx,gy,gz,x,y,z = spGetUnitPosition(closestMine,true)
            local sx,sy = unpack(poses[closestAllied])

            drawCircle[closestAllied] = {sx,sy,0,SPOT_RADIUS,lightgreen,1,false,true,true,true}
            -- Echo("size is ", iconSizeByDefID[spGetUnitDefID(closestMine)])
            local defID = spGetUnitDefID(closestAllied)
            local height = UnitDefs[defID].height
            -- if poses[closestMine].corrected then
            --     sx,sy = spWorldToScreenCoords(unpack(poses[closestAllied].corrected))
            --     drawCircle[closestMine .. 'bis'] = {sx,sy,0,SPOT_RADIUS,red,1,false,true,closestAllied,true}
            -- end
            -- mines[closestMine]=nil
        end
        ------ debugging show colored dots on max positions
        if Debug.EZ() then
            local n=1
            for id in pairs(enemies) do
                if id ~= closestEnemy then
                    -- local gx,gy,gz,x,y,z = spGetUnitPosition(id,true)
                    local sx,sy = unpack(poses[id])
                    drawCircle[id] = {sx,sy,0,SPOT_RADIUS,darkred,0.5,false,true,true,true}
                end
            end
            for id in pairs(mines) do
                if id ~= closestMine then
                    -- local gx,gy,gz,x,y,z = spGetUnitPosition(id,true)
                    local sx,sy = unpack(poses[id])
                    drawCircle[id] = {sx,sy,0,SPOT_RADIUS,lightgreen,0.5,false,true,true,true}
                end
                -- local x,y,z = spGetUnitPosition(id)
                -- y = spGetGroundHeight(x,z)
                -- local sx,sy = spWorldToScreenCoords(x,y,z)
                -- drawCircle[id .. 'ground'] = {sx,sy,0,SPOT_RADIUS,darkred,1,false,true,id,true}
            end
            drawCircle.circleDebug = {mx,my,0,r,white,0.35,false,true,false,true}
        end
        ---------
        return closestEnemy, closestMine
    end
end

-- function widget:KeyPress()
--     -- f.Page(Spring.GetCameraState())
-- end




-- annexes

CanJumpNow = function(t)
    local canJump = false
    -- local frame = spGetGameFrame()
    for i,id in ipairs(t) do
        local reloadJump = spGetUnitRulesParam(id, "jumpReload")
        -- Echo("reloadJump is ", reloadJump)
        if (reloadJump or -1)>=0.2 then
            return true
        end
    end
end

IsDefaultCommandActive = function(dt)
    local time = os.clock()
    if time-upd.triggered <= (dt or spGetLastUpdateSeconds()) then
        return true
    end

end

GetVisibleUnits = function(targetID)
    local defID = spGetUnitDefID(s.acquiredSelect)
    local typeUnits = spGetTeamUnitsByDefs(v.myTeamID or spGetUnitTeam(targetID), defID)
    local unitList = {}
    for i = 1, #typeUnits do
        local id = typeUnits[i]
        if spIsUnitVisible(id) then
            unitList[id] = true
        end
    end
    return unitList
end

ByIDs = function(t)
    local byIDs = {}
    for i,id in pairs(t) do
        byIDs[id] = i
    end
    return byIDs
end

ByIndex = function(t)
    local byIndex, n = {}, 0
    for id in pairs(t) do
        n = n +1
        byIndex[n] = id
    end
    return byIndex
end

CompareIDTables = function(t1, t2)
    local cnt, cnt2 = 0, 0
    for id in pairs(t1) do
        cnt = cnt + 1
        if not t2[id] then
            return
        end
    end

    for _ in pairs(t2) do
        cnt2 = cnt2 + 1
    end
    return cnt == cnt2
end
SortMines = function(id1,id2)
    return mines[id1]<mines[id2]
end
SortEnemies = function(id1,id2)
    return enemies[id1]<enemies[id2]
end

do
    local code={meta=4,internal=8,right=16,shift=32,ctrl=64,alt=128}
    local spGetModKeyState = Spring.GetModKeyState
    local spGetMouseState = Spring.GetMouseState
    MakeOptions = function(internal)
        local opts = {}
        opts.alt, opts.ctrl, opts.meta, opts.shift = spGetModKeyState()
        opts.right = select(5,spGetMouseState())
        opts.internal = internal
        local coded = 0
        for opt,num in pairs(code) do
            if opts[opt] then coded=coded+num end
        end
        opts.coded=coded
        return opts
    end
end








-- DRAWING --

do 
    local glDrawGroundCircle = gl.DrawGroundCircle -- this one is making hollow circle following ground
    local gluDrawGroundCircle = gl.Utilities.DrawGroundCircle -- this one is making plain circle following ground
    local glPushMatrix = gl.PushMatrix
    local glTranslate = gl.Translate
    local glBillboard = gl.Billboard
    local glColor = gl.Color
    local glText = gl.Text
    local glPopMatrix = gl.PopMatrix
    local gluDrawGroundRectangle = gl.Utilities.DrawGroundRectangle
    local glPointSize = gl.PointSize
    local glNormal = gl.Normal
    local glVertex = gl.Vertex
    local GL_POINTS = GL.POINTS
    local glBeginEnd = gl.BeginEnd
    local glLineStipple = gl.LineStipple
    local glLineWidth = gl.LineWidth
    local glCallList = gl.CallList
    local glScale = gl.Scale
    local glBillboard = gl.Billboard
    local spWorldToScreenCoords = Spring.WorldToScreenCoords



    local CreateCircle = function(divs,plain)
        local list = function()
            gl.BeginEnd(plain and GL.TRIANGLE_FAN or GL.LINE_LOOP, function() 
                for i = 0, divs - 1 do
                    local r = 2.0 * math.pi * (i / divs)
                    local cosv = math.cos(r)
                    local sinv = math.sin(r)
                    gl.TexCoord(cosv, sinv)
                    gl.Vertex(cosv, 0, sinv)
                end
            end)
        end
        return gl.CreateList(list)
    end
    local plainCircle = CreateCircle(40,true)
    local hollowCircle = CreateCircle(40,false)
    lists[plainCircle] = true
    lists[hollowCircle] = true





    local DrawCircle = function(x,y,z,r,ground,plain,toScreen)
        if ground then
            if toScreen then
                return
            end
            if plain then
                return gluDrawGroundCircle(x,z,r)
            else
                return glDrawGroundCircle(x,y,z,r,40)
            end
        end
        -- drawing non-following ground circle
        glPushMatrix()
        glTranslate(x, y, z)
        if toScreen then
            gl.Billboard()
        end
        glScale(r, y, r)
        glCallList(plain and plainCircle or hollowCircle)
        glPopMatrix()
    end
    function widget:DrawScreen()
        for x,y,z,r,color,alpha,ground,plain,centerWhite,toScreen in tables(drawCircle) do
            if toScreen then
                color[4]=alpha
                glColor(color)
                color[4]=1
                DrawCircle(x,y,z,r,ground,plain,toScreen)

                glColor(1,1,1,1)
                -- Echo("simple is ", simple)
                if centerWhite then
                    DrawCircle(x,y,z,r-2,ground,plain,toScreen)
                end
                -- Echo(gl.DepthTest())
                -- if spValidUnitID(id) then
                --     -- Echo("Spring.GetUnitViewPosition(id) is ", Spring.GetUnitViewPosition(id))
                --     local _x,_y,_z = Spring.GetUnitPosition(id,true)
                --     alpha = 0
                --     x,y,z = _x,_y,_z

                --     color[4]=alpha
                --     glColor(color)
                --     DrawCircle(x,y,z,r,ground,plain,id,toScreen)
                --     color[4]=1

                -- else
                --     Echo('NOT AN ID',id,x,y,z)
                -- end
            end
        end

    end
    function widget:DrawWorldPreUnit()
        glLineStipple(true)
        -- for id, color in pairs(drawUnit) do
        --     glColor(color)
        --     if spValidUnitID(id) then   
        --         local x,_,z,_,y = spGetUnitPosition(id,true)
        --         DrawCircle(x,y,z,40,false,true)
        --     end
        -- end

        for x,y,z,r,color,alpha,ground,plain,id,toScreen in tables(drawCircle) do
            if not toScreen then
                color[4]=alpha
                glColor(color)
                DrawCircle(x,y,z,r,ground,plain,id)
                color[4]=1
            end
            -- Echo(gl.DepthTest())
        end

        glLineStipple(false)
        if rec[1] then
            gluDrawGroundRectangle(unpack(rec))
        end
        local alpha = 1
        for i=1, #points do
            local g = points[i]
            local x,y,z = unpack(g)
            if not x then
                Echo('bad point',i)
            end
            glColor(g.color)
            glPointSize(5.0)
            glBeginEnd(GL_POINTS, function()
                glNormal(x, y, z)
                glVertex(x, y, z)
              end)
            glPointSize(2.0)
            --
            -- if i<3 then
                glColor(1, 1, 1, alpha)
                glPushMatrix()
                glTranslate(x,y,z)
                glBillboard()
                -- glText(i..': '..g.i..', '..g.j..'|'..'x'..round(g[1])..', z'..round(g[3]),100,i*5,12,'h')
                -- glText(i..': x'..round(g[1])..', z'..round(g[3]),100,i*5,12,'h')
                if g.text then
                    glText(i..': '..g.text,0,0,6,'h')
                else
                    if i==1 then
                        glText(i..': x'..round(g[1])..', y'..round(g[2])..', z'..round(g[3]),0,0,6,'h')
                    end
                end
                -- glText(id, 0,-20,5,'h')
                glPopMatrix()

                alpha = alpha - 0.5
            -- end
        end
        glColor(1, 1, 1, 1)

        -- for i,c in pairs(circle) do
        --     local x,y,z,r = unpack(c)
        --     glPushMatrix()
        --     glDrawGroundCircle(x,y,z,r, 40)
        --     glPopMatrix()
        -- end

        -- if not Debug.draw() then return end

    end

end



unpackstr = function(T,k) -- debug k = v in table as str
    local k,v = next(T,k)
    return k==nil and '' or tostring(k)..'='..tostring(v)..(next(T,k) and ', '..unpackstr(T,k) or '')
end


-- generator for unpacking subtables
do
    local EMPTY_TABLE = {}
    tables=function(ts)
        local k,v
        return function()
            k,v = next(ts,k)
            -- if type(k)=='string' then
            --     k,v = next(ts,k)
            -- end
            return unpack(v or EMPTY_TABLE)
        end
    end
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

function widget:GameOver()
    -- wh:RemoveWidget(widget)
end
function widget:PlayerChanged()
    v.myTeamID = Spring.GetMyTeamID()
    if Spring.GetSpectatingState() then
        wh:RemoveWidget(widget)
    end
end

function MorphFinished(oldID,newID)
    if oldID and morphedComDGUN[oldID] then
        morphedComDGUN[newID] = true
        morphedComDGUN[oldID] = nil
        return
    end
    local defID = spGetUnitDefID(newID)
    if not defID then
        return
    end
    if jumperDefID[defID] then
        return
    end
    local def = UnitDefs[defID]
    local isCom = def.name:match('dyn') or def.name:match('c%d+_base')
    if not isCom then
        return
    end
    for i, weap in ipairs(def.weapons) do
        local wdefID = spGetUnitRulesParam(newID,'comm_weapon_id_'..i)
        if wdefID then
            local wdef=WeaponDefs[wdefID]
            if wdef then
                if wdef.customParams.slot=='3' then
                    morphedComDGUN[newID] = true
                    return
                end
            end
        end

    end
    -- widget:CommandsChanged()
end


function widget:SetConfigData(data)

end
function widget:GetConfigData()

end



function widget:Initialize()
    screen0 = WG.Chili.Screen0
    if Spring.GetSpectatingState() then
        widgetHandler:RemoveWidget(self)
        return
    end
    if not widgetHandler:FindWidget('UnitsIDCard') then
        Echo(widget:GetInfo().name .. ' requires UnitsIDCard')
        widgetHandler:RemoveWidget(self)
        return
    end
    if not WG.Visibles then
        Echo(widget:GetInfo().name .. ' requires HasViewChanged')
        widgetHandler:RemoveWidget(self)
        return
    end
    if not WG.MouseState then
        Echo(widget:GetInfo().name .. ' requires MyClicks')
        widgetHandler:RemoveWidget(self)
        return
    end
    if not WG.mySelection then
        Echo(widget:GetInfo().name .. ' requires Selection API')
        widgetHandler:RemoveWidget(self)
        return
    end        
    MouseState = WG.MouseState
    v.mousePressed = MouseState[3] or MouseState[4] or MouseState[5]
    widget:PlayerChanged()

    isIcon = WG.Visibles.iconsMap
    Cam = WG.Cam
    Units = WG.UnitsIDCard
    commandMap = WG.commandMap or {}
    mySelection = WG.mySelection
    selectionMap = WG.selectionMap
    selection = WG.selection


    PreSelection_IsSelectionBoxActive = WG.PreSelection_IsSelectionBoxActive
    wh = widgetHandler
    s.selectionChanged = true
    widget:ViewResize(Spring.GetWindowGeometry())

    widgetHandler:RegisterGlobal(widget,'MorphFinished', MorphFinished)
    for i, id in ipairs(Spring.GetTeamUnits(v.myTeamID)) do
        MorphFinished(nil,id) -- check for dgun morphed com if we load midgame
    end

    widget:CommandsChanged()
    Debug = f.CreateDebug(Debug,widget, options_path)
    cf2.widget = wh:FindWidget('CustomFormations2')
    DebugUp = function() end
    if debugMe then
        -- old
            -- local obj = f.DebugWinInit2(widget)
            -- DebugUp = obj.DebugUp
            -- local t = {A=5,B=6}
            -- obj:AttachTable(1,t)
            -- t.A = 7
        --
        -- new
            -- if WG.DebugCenter then
            --     local _
            --     widget.Log, widget.varDebug = WG.DebugCenter.Add(widget,{varDebug={'variables',v,'sel',s,'update',upd}})
            --     DebugUp = widget.varDebug.DebugUp
            -- end
        --
        -- old
            -- local Log = widget.Log
            -- local spEcho = Echo
            -- Echo = function(...) Log(...) spEcho(...) end
        --

    end
    -- Echo("widget.MorphFinished is ", widget.MorphFinished)
    -- widgetHandler:RegisterGlobal('MorphUpdate', MorphUpdate)
    -- widgetHandler:RegisterGlobal('MorphStart', MorphStart)
    -- widgetHandler:RegisterGlobal('MorphStop', MorphStop)
    -- widgetHandler:RegisterGlobal('MorphDrawProgress', function() return true end)
    -- local MorphFinishedOwner = widgetHandler.globals['MorphFinished']
    -- if MorphFinishedOwner then
    --     MorphFinishedOwner.

end

function widget:Shutdown()
    Echo("EzTarget is Off")
    if Debug.Shutdown then
        Debug.Shutdown()
    end
    if widget.Log then
        widget.Log:Delete()
    end
    if widget.varDebug then
        widget.varDebug:Delete()
    end
--         for list in pairs(lists) do
--             gl.DeleteList(list)
-- --         end
--     widgetHandler:DeregisterGlobal('MorphUpdate', MorphUpdate)
    widgetHandler:DeregisterGlobal(widget,'MorphFinished', MorphFinished)
--     widgetHandler:DeregisterGlobal('MorphStart', MorphStart)
--     widgetHandler:DeregisterGlobal('MorphStop', MorphStop)
--     widgetHandler:DeregisterGlobal('MorphDrawProgress')
end
function WidgetInitNotify(w, name, preloading)
    if name == 'CustomFormations2' then
        cf2.widget = w
    end
    if preloading then
        return
    end
    if name == 'UnitsIDCard' then
        Units = WG.UnitsIDCard
        widgetHandler:Wake(widget)
    end
end
function WidgetRemoveNotify(w, name, preloading)
    if name == 'CustomFormations2' then
        cf2.widget = nil
    end
    if preloading then
        return
    end
    if name == 'UnitsIDCard' then
        widgetHandler:Sleep(widget)
    end

end

function widget:ViewResize(x,y)
    vsx, vsy = x,y

end

f.DebugWidget(widget)