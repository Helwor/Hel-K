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
    name      = "Split Attack",
    desc      = "Hold ALT while attacking with another single target will split your attackers among their targets and the one to come",
    author    = "Helwor",
    date      = "2 Sept 2022",
    license   = "GNU GPL, v2 or later",
    layer     = -1, -- before Keep Attack
    enabled   = true,  --  loaded by default?
    handler   = true,
  }

-- TODO: when custom formation is not enabled, holding alt + right click on target attack the ground, which is not what we want

end
-- speeds up
local Echo = Spring.Echo

local spGetCommandQueue = Spring.GetCommandQueue
local spGetSelectedUnits = Spring.GetSelectedUnits
local spGetUnitPosition = Spring.GetUnitPosition
local spValidUnitID = Spring.ValidUnitID
local spGetUnitIsDead = Spring.GetUnitIsDead
local spGetGroundHeight = Spring.GetGroundHeight
local spGetUnitDefID = Spring.GetUnitDefID
local spTraceScreenRay = Spring.TraceScreenRay
local spGiveOrderToUnitArray = Spring.GiveOrderToUnitArray
local spGiveOrderArrayToUnitArray = Spring.GiveOrderArrayToUnitArray
local spGiveOrderToUnit = Spring.GiveOrderToUnit
local spGiveOrder = Spring.GiveOrder
local spSetActiveCommand = Spring.SetActiveCommand
local spGetActiveCommand = Spring.GetActiveCommand
local spGetSelectedUnitsCounts = Spring.GetSelectedUnitsCounts
local spGetSelectedUnitsCount = Spring.GetSelectedUnitsCount
local spGetMouseState = Spring.GetMouseState
local spGetUnitRulesParam = Spring.GetUnitRulesParam
local spGetSelectedUnitsSorted = Spring.GetSelectedUnitsSorted
-- local spGetUnitsInCylinder = Spring.GetUnitsInCylinder
-- local spGetUnitsInRectangle = Spring.GetUnitsInRectangle
local spIsUnitAllied = Spring.IsUnitAllied

local CMD_INSERT, CMD_OPT_ALT, CMD_OPT_SHIFT, CMD_OPT_INTERNAL = CMD.INSERT, CMD.OPT_ALT, CMD.OPT_SHIFT, CMD.OPT_INTERNAL
local CMD_MOVE, CMD_ATTACK, CMD_REMOVE = CMD.MOVE, CMD.ATTACK, CMD.REMOVE
local CMD_GUARD = CMD.GUARD
local customCmds = VFS.Include("LuaRules/Configs/customcmds.lua")
local CMD_UNIT_CANCEL_TARGET = customCmds.UNIT_CANCEL_TARGET
local CMD_UNIT_SET_TARGET = customCmds.UNIT_SET_TARGET
local TARGET_UNIT = 2
local opts = CMD_OPT_ALT + CMD_OPT_INTERNAL

local tsort = table.sort
local osclock = os.clock


local wh


local floor, round, huge, abs, max = math.floor, math.round, math.huge, math.abs, math.max
local round = function(x)return tonumber(round(x)) end

include('keysym.h.lua')
local KEYSYMS = KEYSYMS
local UnitDefs = UnitDefs
local maxUnits = Game.maxUnits
local hasCandidate = false
options_path = 'Hel-K/Split Attack'
local f = VFS.Include('LuaUI\\Widgets\\UtilsFunc.lua')

------------- DEBUG CONFIG
local Debug = { -- default values
    active=false -- no debug, no hotkey active without this
    ,global=false -- global is for no key : 'Debug(str)'

    ,ordering=false
    ,algo=false
    ,dist=false
    ,draw=false
    ,draw_tag=false
    ,ground_target=false
    ,attackers=false
    ,cancel=false
    ,UC=false
    ,nextTarget=false
    ,command = false
    ,CF2 = false
}
Debug.hotkeys = {
    active =            {'ctrl','alt','COMMA'} -- this hotkey active the rest
    ,global =           {'ctrl','alt','G'}

    ,ordering =            {'ctrl','alt','O'}
    ,attackers =        {'ctrl','alt','A'}
    ,ground_target =    {'ctrl','alt','R'}
    ,draw =             {'ctrl','alt','W'}
    ,draw_tag =         {'ctrl','alt','T'}
    ,algo =             {'ctrl','alt','L'}
    ,cancel =           {'ctrl','alt','C'}
    ,UC =               {'ctrl','alt','U'}

    ,CF2 =              {'ctrl','shift','F'}
    ,nextTarget =       {'ctrl','shift','N'}
    ,command =          {'ctrl','shift','C'}
    ,dist =             {'ctrl','shift','I'}

}


local bomberDefID = {}
for defID, def in pairs(UnitDefs) do
    if def.isBomber or def.isBomberAirUnit or def.customParams.reallyabomber then
        -- Echo("def.name is ", def.name, def.isBomber and 'isBomber' or def.isBomberAirUnit and 'isBomberAirUnit' or def.customParams.reallyabomber and 'reallyabomber')
        bomberDefID[defID] = true
    end
end

local subjectDefID = {

}

for k,v in pairs(bomberDefID) do
    subjectDefID[k] = v
end
for id,def in pairs(UnitDefs) do
    if def.name:match('arty') or def.name=='cloaksnipe' or def.name=='gunshipemp' or def.name=='gunshipraid' or def.name == 'spiderantiheavy' then
        subjectDefID[id] = true
    end
end

-------------


-- CONFIG -- 
local MAX_ELDER_TIME = 2 -- how long until we forget about old targets, if opt.removeOldest is, they can be cancelled first when split is maxed and shift is not held
local REMOVE_TIMEOUT = 1.2 -- if opt.RemoveOnTimeOut on non shift order, we will not wait to have every units assigned a different target, we will just cancel all of them and start fresh
local opt = {
    -- which algrorythmn should we use to attach units to the differents targets
    -- (setting all to true would be useless)
    -- hungarian look for the least total distance traveled
    useHungarian = false
    -- NoX attach units to targets in a fashion that they don't cross each other way, it seems to be preferable
    ,useNoX = true
    --
    -- what to do when shift is not held and each unit got a separate goal already
    -- removeOldest can fail depending on the MAX_ELDER_TIME and the time of the target and then, the next 'true' option is checked
    ,removeOldest = true  -- 
    -- remove the farthest from the click
    ,removeFarthest = false -- 
    ,removeAll = true
    -- removeOnTimeOut will remove all on timeout
    ,removeOnTimeOut = true
}


--
-- main functions
local StartProcess, Register, DefineGroups, AttachTargets, DistributeOrders
-- annexes
local SendOrders, CancelAttacks
local FindHungarian, GetOrdersNoX
local FilterSel, ReorderTable, ByClosest, identical
local AddAttackerToGroup, MapTarget
local AdjustTargets, GetFarthest, GetOldest, AddToElder, RemoveFromElder, RemoveTarget
local GetPos, GetPosOrder, IDsOf, Disown
local CodeOptions

-- shared variables
local attackers,targets,groups= {n=0}, {n=0,map={}, mapOthers={}}, {n=0}
local sel,allsel,mods = {},{},{}
local elder = {time=osclock(),empty=true}
local mempoints = {n=0}
local active, nextTarget, nextTargetOnPressed, processed

local CF2, CF2_TakeOver,lastx,lasty, lastclock, memcom, acom, memcomname, blockCN
local cmd
local acceptableCmd={[CMD_RAW_MOVE]=true,[CMD_ATTACK]=true,[CMD_UNIT_SET_TARGET]=true}


local time = 0

local INSERT_TABLE = {-1, CMD_ATTACK, 0}
local TARGET_TABLE = {}
local canAttackDefID,canMoveDefID = {},{}
for defid,def in pairs(UnitDefs) do
    if def.canAttack then
        canAttackDefID[defid]=true
    end
    if def.canMove then
        canMoveDefID[defid]=true
    end
end

local got,rec,drawUnit = {},{},{}


local myTeamID = Spring.GetMyTeamID()

-- local lastCmd

---- MAIN
-- main callins are ordered chronologically
function widget:KeyPress(key,m, isRepeat) -- note: mods always appear in the order alt,ctrl,shift,meta when iterated  -- we can simulate the same by traversing the table {alt=true,ctrl=true,meta=true,shift=true}
    if isRepeat then
        return
    end
    Debug.CheckKeys(key,m)
    mods = m
    if not m.alt then memcom=nil return end
    local acom, _
    memcom, acom, _, memcomname = spGetActiveCommand()
    if memcomname and memcomname~='Attack' then
        memcomname=nil
    end


end




function widget:CommandsChanged() 
    memcom = nil
    -- forget the old targets after some time
    if opt.removeOldest then
        local time = osclock()
        if time-elder.time>MAX_ELDER_TIME then
            -- Echo('elder reset')
            elder = {time=time,empty=true}
        end
    end
    allsel = spGetSelectedUnits()
    hasCandidate = false
    for i,id in ipairs(allsel) do
        local defID = spGetUnitDefID(id)
        if subjectDefID[defID] then
            hasCandidate = true
            break
        end
    end
end


-- function widget:Update()
--     if opt.ezTarget or Debug.EZ() then EzTarget() end
-- end
-- recover the active command lost by CustomFormation
function widget:UnitCommandNotify()
    if memcomname then
        if spGetActiveCommand()==0 then
            spSetActiveCommand(memcomname)
        end
    end
end
function widget:MousePress(mx,my,button)
    memcomname = nil
    if button==1 and mods.alt then
        local acom, _
        memcom,acom, _, memcomname = spGetActiveCommand()

        if memcomname and memcomname~='Attack' then
            memcomname = nil
        end
    end
end

function widget:CommandNotify(cmdID,params,opts)

    if (cmdID~=CMD_ATTACK and cmdID~=CMD_RAW_MOVE and cmdID~=CMD_UNIT_SET_TARGET) then
        return
    end

    if not (mods.alt or mods.shift and cmdID==CMD_UNIT_SET_TARGET) then
        -- we count the time for opt.removeOnTimeOut --// or NOT?
        -- time=os.clock()
        -- Echo("time is ", time)

        return
    end
    if not hasCandidate then
        return
    end
    if memcomname then -- keep the active command after release of mouse and until the release of alt
        if spGetActiveCommand() == 0 then
            spSetActiveCommand(memcomname)
        end
    end
    if not allsel[2] then -- case with one in selection and alt is handled by ForceMove widget
        return
    end
    nextTarget = params[3] and params or params[1]
    -- in case of right click on enemy, it will attack the ground if we don't do that
    if (cmdID==CMD_ATTACK or cmdID==CMD_UNIT_SET_TARGET) and memcom==0 and params[3] then
        local mx,my = spGetMouseState()
        local nature,id = spTraceScreenRay(mx,my,false,true,true,false)
        if nature=='unit' then
            nextTarget = id
        end
    end
    cmd = cmdID
    local proc = StartProcess()
    -- lastCmd = cmd
    return proc

end

function widget:KeyRelease(key,m)
    mods = m
    if memcomname and not m.alt then
        local old = memcomname
        local acom, _
        memcom, acom, _, memcomname = spGetActiveCommand()
        if memcomname and memcomname ~= 'Terra Mex' and old == memcomname then
            spSetActiveCommand(0)
            memcomname = false
        end
    end
end

------






StartProcess = function() -- First, verify and adjust our command, units, nextTarget
    -- if not sel.n or sel.hasCandidate or lastCmd~=cmd then FilterSel() end



    FilterSel()

    if sel.n<2 then return end

    Debug('--- Start process ---')

    -- maps can make unique position among different attacker order, that make it easy to check for similar order swiftly
    -- 'map' is registering pos that might need to be switched
    --, mapOthers register other orders that we won't touch, but we need to know if we're clicking on one of those orders
    --, startMap make unique startpos for our attackers so we can know if all attacker start from same position
    --, in this case, algorythm would be used with no purpose and also break,


    -- Set the nextTarget
    -- do it first, so we can check after if we're clicking on existing order and then abort process immediately
    if type(nextTarget)~='number' and type(nextTargetOnPressed)=='number' then
        Debug.nextTarget('prefer getting nextTarget OnPressed as it is an id')
        nextTarget = nextTargetOnPressed
    end

    Debug.nextTarget("nextTarget before treating: "..tostring(nextTarget))

    if type(nextTarget)=='number' then
        tx,ty,tz = GetPos(nextTarget)

        tx,tz = round(tx/16)*16, round(tz/16)*16
        ty=spGetGroundHeight(tx,tz)

        nextTarget = {id=nextTarget,round(tx),round(ty),round(tz)}
    elseif not nextTarget then

        local _,pos = spTraceScreenRay(lastx,lasty,true,false,false,true)
        if not pos then
            Debug.cancel('no unit and no position found')
            return
        end
        pos[1],pos[2],pos[3],pos[4],pos[5],pos[6] = round(pos[1]),round(pos[2]),round(pos[3])

        pos[1],pos[3] = round(pos[1]/16)*16, round(pos[3]/16)*16
        pos[2]=spGetGroundHeight(pos[1],pos[3])
        nextTarget = pos
    end
    nextTarget.cmd = cmd
    
    Debug.nextTarget('nextTarget after ...'..(nextTarget.id and 'id: '..nextTarget.id or '')..(not nextTarget.id and 'pos: ' or 'ground: ')..'x'..nextTarget[1]..', '..'z'..nextTarget[3])

    if not nextTarget[3] then
        Debug.cancel('nextTarget was invalid',unpack(nextTarget))
        return true
    end
    return Register()
end





Register = function()
    local shift = mods.shift and cmd~=CMD_UNIT_SET_TARGET
    local targets_n = 0
    local attackers_n = 0
    local tid
    local tx,ty,tz = unpack(nextTarget)
    local timed_out = osclock()-time>REMOVE_TIMEOUT
    local getOthers = opt.removeOnTimeOut and timed_out
    if timed_out then
        Debug.cancel('TIMED OUT')
    end
    time = osclock()
    -- Echo("time is ", time)
    if opt.removeOldest then
        AddToElder(nextTarget)
    end

    local mapDiffCmd={}
                                                           -- , then will never decrease again if all other attackers got that same start pos (same last order when shift)

    local map,mapOthers,startMap = {},{},{}

    targets = {n=0,map=map,mapOthers=mapOthers}
    groups = {n=0,startMap=startMap,sameStart=mods.shift and 2} -- sameStart will be decreased to 1 when the first start position is found


    -- local map = targets.map
    -- local mapOthers = targets.mapOthers
    -- local startMap = groups.startMap

    map[round(tx)] = {[round(tz)]=nextTarget}
    mapOthers[round(tx)] = {[round(tz)]=nextTarget}

    targets_n = targets_n+1
    targets[targets_n]=nextTarget
    --
    local acceptableCmd = acceptableCmd
    if cmd == CMD_UNIT_SET_TARGET then
        acceptableCmd = {[CMD_UNIT_SET_TARGET]=true}
    end

    local inc = shift and -1 or 1
    for i,attacker in ipairs(attackers) do
        local id = attacker.id
        local queue = spGetCommandQueue(id,-1) -- NOTE: when cheating we cannot get queue from a controlled enemy unit (or there might be a way I didnt find yet)
        if cmd==CMD_UNIT_SET_TARGET then
            -- Echo("Spring.SetUnitTarget,Spring.GetUnitTarget is ", Spring.SetUnitTarget,Spring.GetUnitTarget)
                -- Echo("1 is ", Spring.GetUnitRulesParam(id, "target_type"))
            if timed_out then
                queue = {}
                -- Echo(id,os.clock(),'queue empty')
            else
                local target_type = spGetUnitRulesParam(id, "target_type")
                if target_type==TARGET_UNIT then
                    local tgtID = spGetUnitRulesParam(id, "target_id") -- NOTE: there is still the last target id even if the targetting has been cancelled ! (should fix)
                    if tgtID and tgtID~=0 then
                        if shift then
                            table.insert(queue,{id=CMD_UNIT_SET_TARGET,params={tgtID}})
                        else
                            queue = {{id=CMD_UNIT_SET_TARGET,params={tgtID}}}
                        end    
                    end
                end
            end
        end
        local queue_i = inc<0 and #queue or 1

        local order = queue[queue_i]
        -- 'Others' will not count as cancellable
        local getOthers = getOthers or shift and not queue[2]
        if order and order.id==0 then 
            -- in case the game is paused and a stop order has been issued while paused
            queue_i=2
            order = queue[queue_i]
            getOthers = getOthers or shift and not queue[3]
        end
        local map = getOthers and mapOthers or targets.map
        -- local order = queue[queue_i]

        --
        -- in case of shift, the starting position (aka attacker[1]...attacker[3]) is the last order that got position
        -- , if no shift, this is the unit itself


        while order do
            tid,tx,ty,tz = GetPosOrder(order)
            -- Echo('attacker '..attacker.id,'order #'..queue_i..', cmd '..order.id,(tid and 'id: '..tid or 'no id'),'pos: '..'x'..round(tx or -1)..', '..'z'..round(tz or -1))
            -- found a position order
            if tz then
                -- if not set yet, set the starting position for this attacker
                tx,tz = round(tx/16)*16, round(tz/16)*16
                ty=spGetGroundHeight(tx,tz)
                if shift and getOthers and not attacker[3] then
                    Debug.attackers('attacker '..attacker.id..' found a last pos at order #'..queue_i)
                    attacker[1],attacker[2],attacker[3]= tx,ty,tz
                    if groups.sameStart then
                        local _, new = MapTarget(tx,ty,tz,nil,startMap,order.id)
                        if new then
                            groups.sameStart = groups.sameStart-1
                            if groups.sameStart==0 then groups.sameStart=false end
                        end
                    end
                end
                -- if cmd == order.id then
                if acceptableCmd[order.id] then
                   
                    local target, new, existing = MapTarget(tx,ty,tz,tid,map,order.id)
                    if existing and not timed_out and cmd~=CMD_UNIT_SET_TARGET then
                        Debug.cancel('clicked an already existing target on '..(getOthers and 'another' or shift and 'last' or 'first')..' order.')
                        return true
                    end
                    if not getOthers then
                        if new then
                            targets_n = targets_n+1
                            targets[targets_n] = target
                        end
                        attacker.current=target
                        attacker.tag = order.tag
                    end
                elseif not getOthers and not shift and cmd~=CMD_UNIT_SET_TARGET then -- in case the unit got another order, it has to be removed if no shift
                    Debug.ordering('attacker '..id..' got a non-attack order, cmd:'..order.id, tid and 'id: '..tid or 'ground: x'..tx..', z'..tz )
                    attacker.current = MapTarget(tx,ty,tz,tid,mapDiffCmd,order.id) -- the details doesn't matter in this case, we just want DistributeOrder to cancel this
                    attacker.tag = order.tag
                end
            end
            -- now we look for other order in the queue that got position, either to know them for not reordering it
            -- , or also to look for a starting position when shift is held
            queue_i = queue_i+inc
            order=queue[queue_i]
            if not getOthers then
                getOthers=true
                map=mapOthers
            end
        end
        -- in case of shift, and no other positionned order found, the attacker starting point is itself
        if not attacker[3] then 
            Debug.attackers('attacker '..id.." didn't find any order to start from, it will start from itself")
            groups.sameStart=false
            local x,y,z = spGetUnitPosition(id)
            attacker[1],attacker[2],attacker[3] = round(x),round(y),round(z)

        end

        attackers_n=i
    end
    targets.n=targets_n
    -- Echo('targets =>',targets.n)
    -- Echo("targets.n,attackers.n is ", targets.n,attackers.n)
    if not (targets[2] and attackers[2]) then
        if attackers[1] and targets[1] then
            Debug.attackers('no multiple targets,'..targets.n..' vs '..attackers.n..', ordering normal attack')
            -- we're just configuring targets to appear as a group for DistributeOrder()
            attackers.target = nextTarget
            groups[1] = attackers
            groups.n=1
            DistributeOrders()
        else
            Debug.cancel('no target or no attacker, '..targets.n..' vs '..attackers.n)
        end
        
        return true
    end
    if targets_n>attackers_n then
        if mods.shift then
            Debug.attackers('more targets than attackers,#targets '..targets.n..' vs #attackers'..attackers.n..', and shift is held, setting the new target for all attackers')
            -- make attackers as a group

            SendOrders({[nextTarget]=IDsOf(attackers)})
            return true
        else
            Debug.attackers('more targets than attackers,#targets '..targets.n..' vs #attackers'..attackers.n..', and no shift, replacing the farthest target' )
            -- remove the target but not the attackers.current and attacker.tag so they will get ordered to cancel it
            if AdjustTargets() then
                return true
            end
        end
    end       
    -- 
    if opt.removeOldest then
        for i=2,targets.n do -- we already put nextTarget before so we start at 2
            AddToElder(targets[i])
        end
    end
    --
    DefineGroups()
    return true
end

DefineGroups = function () -- TODO: can probably improve algorythms, 
    

    local split = targets.n/attackers.n
    local groups_n = split>1 and attackers.n or targets.n
    local att_per_group = split >=1 and 1 or floor(attackers.n/targets.n)
    local remaining_att = split >= 1 and 0 or attackers.n%targets.n

    ---- now there will be no more extra targets in here
    -- local tgt_per_group = split <=1 and 1 or floor(split)
    -- local remaining_tgt = split <=1 and 0 or targets.n%attackers.n  -- remaining targets to distribute
    ----

    Debug('attackers: '..attackers.n,'targets: '..targets.n,'groups: '..groups_n,'att_per_group: '..att_per_group
        , 'remaining att: '..tostring(remaining_att) --[[,'tgt_per_group '..tgt_per_group, 'remaining tgt: '..tostring(remaining_tgt)--]])

    ---- Define groups
    groups.n=groups_n
    -- reorder attackers by closest of the first, first beeing the most at left, and then the most ot bottom
    -- TODO:this really need to be improved, to shape groups better
    ReorderTable(attackers)
    
    for i=1,groups_n do 
        groups[i]={i=i,n=0,x=0,z=0}
    end
    local group = groups[1]
    local group_i = 0
    local current_group = 1
    local off=0
    for i=1,attackers.n-remaining_att do
        -- Echo((i+off)..' => ',current_group)
        group_i = AddAttackerToGroup(attackers[i+off],group,group_i)
        if (i)%(att_per_group)==0 then
            if remaining_att>0 then
                remaining_att=remaining_att-1
                off=off+1
                group_i = AddAttackerToGroup(attackers[i+off],group,group_i)
                -- Echo('rem',(i+off)..' => ',current_group)
            end
            group.n = group_i
            if current_group==groups_n then
                break
            end
            -- selecting the next group
            current_group = current_group+1
            group=groups[current_group]
            group_i = 0
        end
    end

    -- calculate group centers
    for i=1,groups_n do
        local group = groups[i]
        group.x,group.z = group.x/group.n, group.z/group.n
    end

    AttachTargets()
end

AttachTargets = function()
    ---- Design pair group/target by using either Hungarian method or NoX method or none if we start from the same unique position
    -- Hungarian gives the most even distances between each pairs, NoX prevent pairs to cross each others on the way
    -- after use, NoX is definitely the choice to take


    -- if true then return end
    if Debug.dist() then
        for i=1,groups_n do
            local group = groups[i]
            local x,z = group.x, group.z
            for j=1,groups_n do 
                local target = targets[j]
                local tx,ty,tz = unpack(target)
                local dist = round((x-tx)^2 + (z-tz)^2)
                Debug.dist('dist '..i,j..' : '..dist)
            end
        end
    end


    local groups_n = groups.n
    if groups.sameStart then -- keeping the way targets got inserted, it doesn't matter, since all groups start from same position
        for i=1,groups_n do
            groups[i].target = targets[i]
        end
    elseif opt.useHungarian then
        Debug.algo('running hungarian...') -- need to check with large numbers
        local dist_table = {}
        local total_dist,min_dist,closest = 0,huge
        for i=1,groups_n do
            local group = groups[i]
            local x,z = group.x, group.z
            dist_table[i]={}
            local dist_col = dist_table[i]
            for j=1,groups_n do 
                local target = targets[j]
                local tx,ty,tz = unpack(target)
                local dist = round((x-tx)^2 + (z-tz)^2)
                total_dist = total_dist + dist
                if dist<min_dist then min_dist,closest = dist, {i,j} end
                dist_col[j] = dist
            end
        end
        -- local avg_dist = total_dist/groups_n^2
        -- Echo('average distance: '..avg_dist,'min distance: '..min_dist, 'closest is group '..closest[1]..' to target '..closest[2]..'by '..((1-(min_dist/avg_dist))*100)..' %.' )
        for i,j in ipairs(FindHungarian(dist_table,groups_n)) do 
            groups[i].target = targets[j]
        end

    elseif opt.useNoX then
        Debug.algo('running NoX') -- need to check with large numbers
        groups.poses={}
        local poses = groups.poses
        for i=1, groups_n do
            local group = groups[i]
            poses[i]={group.x,false,group.z}
        end
        GetOrdersNoX(targets,poses,groups,groups_n) -- function will add the pairs group/target at poses[2] and poses[4]
        for i=1,groups_n do
            local res = poses[i]
            local group = res[2]
            local target = res[4]
            group.target = target
        end
    end

    DistributeOrders()

end
    --
DistributeOrders = function()
    -- distributing orders
    
    local debugGround = Debug.ground_target() and not Debug.ordering()
    local debug = debugGround or Debug.ordering()
    local cur_target,curGroundTarget,new_target,newGroundTarget
    local want_cancel = {ids={},orders={}}
    local new_attacks = {}
    local want_c=0

    for i=1,groups.n do
        local group = groups[i]
        local target = group.target
        local want_a,new_attack=0
        -- Echo('group #'..i..' got target at '..'x'..target[1]..', z'..target[3])

        for j=1, group.n do
            local attacker = group[j]
            local id = attacker.id
            cur_target = attacker.current
            local debug = debug
            if debug then
                curGroundTarget = cur_target and not cur_target.id
                newGroundTarget = target and not target.id
                debug = not debugGround or curGroundTarget or newGroundTarget
            end

            if cur_target~=target then -- attacker don't have the desired target (or nothing) as current
                -- local switch_to_attack = (not cur_target or cur_target.cmd==CMD_RAW_MOVE) and target.cmd==CMD_ATTACK

                -- if switch_to_attack and bomberDefID[spGetUnitDefID(id)] and (spGetUnitRulesParam(id,'noammo')==1) then
                --     Debug.attackers('the bomber '..id..' cannot afford to switch to attack as it is unloaded')
                --     Echo('the bomber '..id..' cannot afford to switch to attack as it is unloaded')
                --     --skip, the bomber cannot afford to switch to attack as it is unloaded
                -- else
                    local possible = target.id and attacker.canAttack or attacker.canMove -- not ideal, the ideal would be to know in advance which unit will have to switch to something impossible and filter them out but this is decided by algo
                    if possible then
                        attacker.attack = target
                        attacker.cancel = attacker.tag -- attacker have another target to cancel
                    end
                    -- Echo('attacker '..attacker.id.." have current target: "..(cur_target and (cur_target.id or 'ground: '..'x'..cur_target[1]..', z'..cur_target[3]) or 'none'))
                    -- Echo('attacker '..attacker.id.." don't have"..(attacker.cancel and ' the good'or '')..' target '..(attacker.cancel and ', need to cancel order '..attacker.cancel or '.'))
                -- end
            end
            -- used for debugging
            --
            if attacker.cancel then
                -- debugging
                if debug then
                    Echo('attacker '..id..' from group #'..i..' is switching target from '
                         ..(curGroundTarget and 'ground: '..'x'..round(cur_target[1])..', '..'z'..round(cur_target[3]) or 'id: '..cur_target.id)..' (tag:'..attacker.cancel..')'
                         ..' to '..(newGroundTarget and 'ground: '..'x'..round(target[1])..', '..'z'..round(target[3]) or 'id: '..target.id))
                end
                --

                want_c=want_c+1
                want_cancel.ids[want_c]=id
                want_cancel.orders[want_c]={CMD_REMOVE,attacker.cancel,0}

                -- spGiveOrderToUnit(id,CMD_REMOVE,attacker.cancel,0)
                -- spGiveOrderToUnit(id,CMD_UNIT_CANCEL_TARGET,0,0)
            end
            if attacker.attack then
                if not new_attacks[target] then
                    new_attacks[target]={}
                    new_attack = new_attacks[target]
                end
                want_a = want_a+1
                new_attack[want_a] = attacker.id
                -- debugging
                if debug and not cur_target then
                    Echo('attacker '..attacker.id.." don't have any target, need order to attack "
                         ..(newGroundTarget and 'ground: '..'x'..round(target[1])..', '..'z'..round(target[3]) or 'id: '..target.id))
                end
                --
            end
        end
    end
    if want_c>0 then
        CancelAttacks(want_cancel)
    end
    if next(new_attacks) then
        SendOrders(new_attacks)
    end
end




function widget:UnitCommand(id,defID,teamID,cmd,params)
    if Debug.UC() then
        for i,p in pairs(params) do
            params[i]=round(p)
        end
        Echo(id..' got ordered '..cmd, unpack(params))
    end
end



function widget:Initialize()
    if Spring.GetSpectatingState() then
        widgetHandler:RemoveWidget(self)
        return
    end
    Debug = f.CreateDebug(Debug,widget,options_path)
    wh = widgetHandler
    widget:CommandsChanged()
end


-- annexes

FilterSel = function()
    local attacking = cmd==CMD_ATTACK or cmd==CMD_UNIT_SET_TARGET
    sel={}
    attackers={n=0}

    local n = 0
    for defid, units in pairs(WG.selectionDefID or spGetSelectedUnitsSorted()) do
        local canAttack,canMove = canAttackDefID[defid], canMoveDefID[defid]
        if attacking and subjectDefID[defid] then
            sel.hasCandidate=true
            for i,id in ipairs(units) do
                if spGetUnitRulesParam(id,'noammo')~=1 then -- the bomber can attack
                    n=n+1
                    sel[n]=id
                    attackers[n]={id=id,defid=defid,canAttack=canAttack,canMove=canMove}
                else
                    Debug.attackers('the bomber '..id..' has been filtered out, it cannot attack as it is unloaded')
                end
            end
        else
            if (attacking and canAttack) or (not attacking and canMove) then
                for i,id in ipairs(units) do
                    n=n+1
                    sel[n]=id
                    attackers[n]={id=id,defid=defid,canAttack=canAttack,canMove=canMove}
                end
            end
        end
    end
    sel.n = n
    attackers.n=n
    return sel
end

CancelAttacks = function(cancel)
    if cmd==CMD_UNIT_SET_TARGET then
        return
    end
    spGiveOrderArrayToUnitArray(cancel.ids,cancel.orders,true) -- true for 'pairwise' = 1 order per id
    if cmd==CMD_ATTACK then
        spGiveOrderToUnitArray(cancel.ids, CMD_UNIT_CANCEL_TARGET,0,0)
    end
end
SendOrders = function(t)
    -- finally not using insertion for non shift
    -- INSERT_TABLE[1] = mods.shift and -1 or 0
    -- local cmd = cmd
    local shift = mods.shift and cmd~=CMD_UNIT_SET_TARGET
    for target, ids in pairs(t) do

        local cmd = target.cmd
        INSERT_TABLE[2] = cmd
        if shift then
            if target.id and (cmd==CMD_ATTACK or cmd==CMD_UNIT_SET_TARGET) then
                INSERT_TABLE[4],INSERT_TABLE[5],INSERT_TABLE[6]--[[,INSERT_TABLE[7],INSERT_TABLE[8]--]] = target.id
            else
                INSERT_TABLE[4],INSERT_TABLE[5],INSERT_TABLE[6] = unpack(target)
            end
            spGiveOrderToUnitArray(ids, CMD_INSERT, INSERT_TABLE, opts)
        else
            if target.id and (cmd==CMD_ATTACK or cmd==CMD_UNIT_SET_TARGET) then
                target = target.id
            else

                -- table.insert(target,1,0)
                -- target[4],target[5] = 32,2
            end
            -- for i,id in ipairs(ids) do
            --     Echo('send order '..cmd..' to '..ids[i]..' at '..(type(target)=='number' and 'id: '..target or 'ground: x'..target[1]..', z'..target[3]) )
            -- end
            spGiveOrderToUnitArray(ids, cmd, target, 0)
        end
    end
    if (cmd==CMD_ATTACK) then
        -- add the targets of group mates after the main target, so they will be attacked once the main target die, working like CTRL+area attack
        for i,tgt in ipairs(targets) do
            local tgtID = tgt.id
            if tgt.id and spValidUnitID(tgtID) and not spGetUnitIsDead(tgtID) then
                TARGET_TABLE[1] = tgt.id
                for _,attacker in ipairs(attackers) do
                    if (attacker.attack and attacker.attack.id or attacker.current and attacker.current.id)~=tgt.id then
                        -- Echo('add ',tgt.id,'to',attacker.id)
                        if not type(tgt.id) == 'number' then
                            Echo(i,'BAD TGT.ID',tgt.id)
                        end
                        spGiveOrderToUnit(attacker.id,cmd,{tgt.id},CMD_OPT_ALT + CMD_OPT_SHIFT)
                    end
                end
            end
        end
    end
end

AdjustTargets = function()
    local toRemove, i
    if opt.removeOldest and not elder.empty then
        toRemove, i = GetOldest('remove')
    end
    if not toRemove and opt.GetFarthest then
        toRemove, i = GetFarthest(nextTarget,targets)
    end
    if not toRemove and opt.removeAll then
        SendOrders({[nextTarget]=IDsOf(attackers)})
        return true
    end
    RemoveTarget(toRemove, i or 2) 
end
AddAttackerToGroup = function(attacker,group,group_i)
    group_i=group_i+1
    group[group_i] = attacker
    local ax,ay,az = unpack(attacker)
    group.x,group.z = group.x+ax, group.z+az
    return group_i
end


RemoveTarget = function(target,ti)
    local tmapX = targets.map[target[1]]
    if tmapX and tmapX[target[3]] then
        tmapX[target[3]]=nil
        if not next(tmapX) then targets.map[target[1]] = nil end
        table.remove(targets,ti)
        targets.n = targets.n-1
    end
end
AddToElder = function(target)
    local tid, tx,ty,tz = target.id, unpack(target)
    local time = osclock()
    if tid and not elder[tid] then
        elder[tid] = time
    else
        elder[tx] = elder[tx] or {}
        if not elder[tx][tz] then
            elder[tx][tz] = time
            -- Echo('added ',tx,tz,'time: '..time)
        else
            -- Echo('target already exist',tx,tz,'time: '..elder[tx][tz])
        end
    end
    elder.time = time
    elder.empty=false
end
RemoveFromElder = function(tid,tx,tz)
    if elder[tid] then
        elder[tid]=nil
    else
        local elX = elder[tx]
        if elX[tz] then
            elX[tz]=nil
        end
        if not next(elX) then
            elder[tx]=nil
        end
    end
    -- local count=0
    -- for _ in pairs(elder) do
    --     count=count+1
    -- end
    -- Echo('total',count-2)
    local count=0
    for _ in pairs(elder) do
        count=count+1
        if count>2 then
            break
        end
    end
    if count==2 then
        elder.empty=true
        elder.time=osclock()
    end
end
GetOldest = function(remove)
    local oldest
    local time=huge
    local I
    for i=1,targets.n do
        local target = targets[i]
        local tid,tx,tz = target.id, target[1],target[3]
        if i==1 then
            -- Echo('target #1: ',tx,tz)
        end
        local target_time = elder[tid] or elder[tx] and elder[tx][tz]
        if target_time then
            -- Echo('target ',i,tx,tz,'time: '..target_time..(target==nextTarget and ' <nextTarget>' or ''))
            if target_time<time then
                I=i
                time = target_time
                oldest = target
            end
        end
    end
    if remove and oldest then
        -- Echo("oldest is ",I, 'x'..oldest[1],'z'..oldest[3])
        RemoveFromElder(oldest.id,oldest[1],oldest[3])
    end
    return oldest,I
end

GetFarthest = function(from,t)
    local fx,fy,fz = unpack(from)
    local farDist=0
    local fi
    for i=1,t.n do
        local tx,ty,tz = unpack(t[i])
        local dist = round((tx-fx)^2 + (tz-fz)^2)
        if dist>farDist then
            farDist=dist
            farthest = t[i]
            fi = i
        end
    end
    return farthest,fi
end


do 
    local maxUnits = Game.maxUnits
    local spGetFeaturePosition = Spring.GetFeaturePosition
    local positionCommand
    GetPos = function(tid)
        if spValidUnitID(tid) then
            return spGetUnitPosition(tid)
        else
            return spGetFeaturePosition(tid)
        end
    end
    GetPosOrder = function(order)
        local cmd,params = order.id,order.params
        local tid,x,y,z
        if cmd < 0 or positionCommand[cmd] then
            if params[3] then
                x,y,z = unpack(params)
            else
                tid = params[1]
                if not tid or tid==0 then return end
                x,y,z = GetPos(tid)
            end
        end
        return tid,x,y,z
    end
    positionCommand = {
        [CMD.MOVE] = true,
        [CMD_RAW_MOVE] = true,
        [CMD_RAW_BUILD] = true,
        [CMD.REPAIR] = true,
        [CMD.RECLAIM] = true,
        [CMD.RESURRECT] = true,
        [CMD.MANUALFIRE] = true,
        [CMD.GUARD] = true,
        [CMD.FIGHT] = true,
        [CMD.ATTACK] = true,
        [CMD_JUMP] = true,
        [CMD_LEVEL] = true,
        [CMD_UNIT_SET_TARGET] = true,
    }
end

MapTarget = function(tx,ty,tz,tid,map,cmd) -- make unique points
    local new,existing
    tx,tz = round(tx),round(tz)
    local tmapX = map[tx]
    local target
    if not tmapX then
        map[tx] = {}
        tmapX = map[tx]
    else
        target = tmapX[tz]
        if target == nextTarget then  -- the user clicked an already attacked unit
            existing = true
        end
    end
    if not target then
        target={tx,ty,tz,id=tid,cmd=cmd}
        tmapX[tz]=target
        new = true
    end
    return target, new, existing
end



ByClosest = function(a,b)
    return a.dist<b.dist
end
ReorderTable = function(t)
    local first
    local lesserX,lesserZ = huge,huge
    for i=1,t.n do
        local elem = t[i]
        local x,y,z = unpack(elem)
        -- x,y,z = tonumber(x),tonumber(y),tonumber(z)
        -- Echo("x,y,z is ", x,y,z)
        if x<lesserX or x==lesserX and z<lesserZ then
            lesserX,lesserZ = x,z
            first = elem
        end
    end
    local fx,fy,fz = unpack(first)
    first.dist=0
    for i=1,t.n do
        local elem = t[i]
        local ax,ay,az = unpack(elem)
        elem.dist = round((ax-fx)^2 + (az-fz)^2)
    end
    table.sort(t,ByClosest)
end

identical = function(t1,t2)
    local len = #t1
    local identical = len==#t2

    if identical then
        local common = {}
        for i=1,len do common[t1[i]]=true end
        for i=1,len do if not common[t2[i]] then identical=false break end end
    end
    return identical
end
IDsOf = function(t)
    local ids = {}
    for i=1,t.n do
        ids[i]=t[i].id
    end
    return ids
end

Disown = function()
    wh.mouseOwner = nil
end
do
    local code={meta=4,internal=8,right=16,shift=32,ctrl=64,alt=128}
    CodeOptions = function(options)
        local coded = 0
        for opt,num in pairs(code) do
            if options[opt] then coded=coded+num end
        end
        options.coded=coded
        return options
    end
end

-- DRAWING --
do 
    local glPushMatrix = gl.PushMatrix
    local glTranslate = gl.Translate
    local glBillboard = gl.Billboard
    local glColor = gl.Color
    local glText = gl.Text
    local glPopMatrix = gl.PopMatrix
    local glDrawGroundCircle = gl.DrawGroundCircle
    local gluDrawGroundRectangle = gl.Utilities.DrawGroundRectangle
    local glPointSize = gl.PointSize
    local glNormal = gl.Normal
    local glVertex = gl.Vertex
    local GL_POINTS = GL.POINTS
    local glBeginEnd = gl.BeginEnd
    local glLineStipple = gl.LineStipple
    local glLineWidth = gl.LineWidth
    function widget:DrawWorld()
        glLineStipple(true)
        for id, color in pairs(drawUnit) do
            glColor(color)
            if spValidUnitID(id) then   
                local x,_,z,_,y = spGetUnitPosition(id,true)
                glPushMatrix()
                glDrawGroundCircle(x, y, z, 40, 40)
                glPopMatrix()
            end
        end
        glLineStipple(false)
        if rec[1] then
            gluDrawGroundRectangle(unpack(rec))
        end
        local alpha = 1
        for i=1, #got do
            local g = got[i]
            local x,y,z = unpack(g)

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
                glText(i..': x'..round(g[1])..', z'..round(g[3]),0,0,3,'h')
                -- glText(id, 0,-20,5,'h')
                glPopMatrix()

                glColor(1, 1, 1, 1)
                alpha = alpha - 0.5
            -- end
        end

        -- for i,c in pairs(circle) do
        --     local x,y,z,r = unpack(c)
        --     glPushMatrix()
        --     glDrawGroundCircle(x,y,z,r, 40)
        --     glPopMatrix()
        -- end

        if not Debug.draw() then return end



        for i=1,attackers.n do -- show the attackers in the order we made them
            local attacker = attackers[i]
            local x,y,z = spGetUnitPosition(attacker.id)
            if x then
                glPushMatrix()
                glTranslate(x,y,z)
                glBillboard()
                glColor(1, 1, 1, 1)
                glText(i, 0,0,20,'h')
                -- glText(id, 0,-20,5,'h')
                glPopMatrix()
                glColor(1, 1, 1, 1)
            end
        end
        for x,colx in pairs(targets.map) do -- show the coords of uniques current targets
            for z, tgt in pairs(colx) do
                glPushMatrix()
                local y = spGetGroundHeight(x,z)
                glTranslate(x,y,z)
                glBillboard()
                glColor(1, 1, 1, 1)
                glText(x..','..z, 0,-6,5,'h')
                -- glText(id, 0,-20,5,'h')
                glPopMatrix()
                glColor(1, 1, 1, 1)
            end
        end
        -- show the targets in order
        for i=1,targets.n do
            local target = targets[i]
            local x,y,z = unpack(target)
            if x then
                glPushMatrix()
                glTranslate(x,y,z)
                glBillboard()
                glColor(1, 1, 1, 1)
                glText(i, 0,0,25,'h')
                -- glText(id, 0,-20,5,'h')
                glPopMatrix()
                glColor(1, 1, 1, 1)
            end
        end
        if Debug.draw_tag() then -- show only the tags of attacker.current, which is not mandatorily the current order, but the order we shall cancel
            for i=1,attackers.n do
                local attacker = attackers[i]
                if attacker.current then

                    local x,y,z = unpack(attacker.current)
                    if x then
                        glPushMatrix()
                        glTranslate(x,y,z)
                        glBillboard()
                        glColor(0, 1, 0, 1)
                        glText(attacker.tag, 0,-10,15,'h')
                        -- glText(id, 0,-20,5,'h')
                        glPopMatrix()
                        glColor(1, 1, 1, 1)
                    end
                end
            end
        end
        -- show the average centers of groups, in order
        for i,group in ipairs(groups) do
            if group.x then
                local x,z = group.x,group.z
                local y = spGetGroundHeight(x,z)
                glPushMatrix()
                glTranslate(x,y,z)
                glBillboard()
                glColor(1, 1, 0, 1)
                glText('G'..i, 0,0,25,'h')
                -- glText(id, 0,-20,5,'h')
                glPopMatrix()
                glColor(1, 1, 1, 1)
            end
        end


    end
end






------------------
-- Hungarian / OrdersNoX  methods
-- copied from Custom Formation 2 and modified a bit
    -------------------------------------------------------------------------------------
    -------------------------------------------------------------------------------------
    -- (the following code is written by gunblob)
    --   this code finds the optimal solution (slow, but effective!)
    --   it uses the hungarian algorithm from http://www.public.iastate.edu/~ddoty/HungarianAlgorithm.html
    --   if this violates gpl license please let gunblob and me know
    -------------------------------------------------------------------------------------
    -------------------------------------------------------------------------------------
do
    local doPrime, stepPrimeZeroes, stepFiveStar
    local t
    FindHungarian = function(array, n)
        
        t = osclock()
        -- Vars
        local colcover = {}
        local rowcover = {}
        local starscol = {}
        local primescol = {}
        
        -- Initialization
        for i = 1, n do
            rowcover[i] = false
            colcover[i] = false
            starscol[i] = false
            primescol[i] = false
        end
        
        -- Subtract minimum from rows
        for i = 1, n do
            
            local aRow = array[i]
            local minVal = aRow[1]
            for j = 2, n do
                if aRow[j] < minVal then
                    minVal = aRow[j]
                end
            end
            
            for j = 1, n do
                aRow[j] = aRow[j] - minVal
            end
        end
        
        -- Subtract minimum from columns
        for j = 1, n do
            
            local minVal = array[1][j]
            for i = 2, n do
                if array[i][j] < minVal then
                    minVal = array[i][j]
                end
            end
            
            for i = 1, n do
                array[i][j] = array[i][j] - minVal
            end
        end
        
        -- Star zeroes
        for i = 1, n do
            local aRow = array[i]
            for j = 1, n do
                if (aRow[j] == 0) and not colcover[j] then
                    colcover[j] = true
                    starscol[i] = j
                    break
                end
            end
        end
        
        -- Start solving system
        while true do
            
            -- Are we done ?
            local done = true
            for i = 1, n do
                if not colcover[i] then
                    done = false
                    break
                end
            end
            
            if done then
                return starscol
            end
            
            -- Not done
            local r, c = stepPrimeZeroes(array, colcover, rowcover, n, starscol, primescol)
            stepFiveStar(colcover, rowcover, r, c, n, starscol, primescol)
        end
    end
    doPrime = function(array, colcover, rowcover, n, starscol, r, c, rmax, primescol)
        
        primescol[r] = c
        
        local starCol = starscol[r]
        if starCol then
            
            rowcover[r] = true
            colcover[starCol] = false
            
            for i = 1, rmax do
                if not rowcover[i] and (array[i][starCol] == 0) then
                    local rr, cc = doPrime(array, colcover, rowcover, n, starscol, i, starCol, rmax, primescol)
                    if rr then
                        return rr, cc
                    end
                end
            end
            
            return
        else
            return r, c
        end
    end
    stepPrimeZeroes = function(array, colcover, rowcover, n, starscol, primescol)
        
        -- Infinite loop
        while true do
            
            -- Find uncovered zeros and prime them
            for i = 1, n do
                if not rowcover[i] then
                    local aRow = array[i]
                    for j = 1, n do
                        if (aRow[j] == 0) and not colcover[j] then
                            local i, j = doPrime(array, colcover, rowcover, n, starscol, i, j, i-1, primescol)
                            if i then
                                return i, j
                            end
                            break -- this row is covered
                        end
                    end
                end
            end
            
            -- Find minimum uncovered
            local minVal = huge
            for i = 1, n do
                if not rowcover[i] then
                    local aRow = array[i]
                    for j = 1, n do
                        if (aRow[j] < minVal) and not colcover[j] then
                            minVal = aRow[j]
                        end
                    end
                end
            end
            
            -- There is the potential for minVal to be 0, very very rarely though. (Checking for it costs more than the +/- 0's)
            
            -- Covered rows = +
            -- Uncovered cols = -
            for i = 1, n do
                local aRow = array[i]
                if rowcover[i] then
                    for j = 1, n do
                        if colcover[j] then
                            aRow[j] = aRow[j] + minVal
                        end
                    end
                else
                    for j = 1, n do
                        if not colcover[j] then
                            aRow[j] = aRow[j] - minVal
                        end
                    end
                end
            end
        end
    end
    stepFiveStar = function(colcover, rowcover, row, col, n, starscol, primescol)
        
        -- Star the initial prime
        primescol[row] = false
        starscol[row] = col
        local ignoreRow = row -- Ignore the star on this row when looking for next
        
        repeat
            if osclock()-t>0.8 then
                Debug.algo('Hungarian took too long')
                break
            end
            local noFind = true

            for i = 1, n do
                
                if (starscol[i] == col) and (i ~= ignoreRow) then
                    
                    noFind = false
                    
                    -- Unstar the star
                    -- Turn the prime on the same row into a star (And ignore this row (aka star) when searching for next star)
                    
                    local pcol = primescol[i]
                    primescol[i] = false
                    starscol[i] = pcol
                    ignoreRow = i
                    col = pcol
                    
                    break
                end
            end
        until noFind
        
        for i = 1, n do
            rowcover[i] = false
            colcover[i] = false
            primescol[i] = false
        end
        
        for i = 1, n do
            local scol = starscol[i]
            if scol then
                colcover[scol] = true
            end
        end
    end
end
-------------------------------------
GetOrdersNoX = function(nodes, unitPoses, units, unitCount)
    -- Remember when  we start
    -- This is for capping total time
    -- Note: We at least complete initial assignment
    
    ---------------------------------------------------------------------------------------------------------
    -- Find initial assignments
    ---------------------------------------------------------------------------------------------------------
    local unitSet = {}
    local unitSet = unitPoses
    local fdist = -1
    local fm
    local t = osclock()
    for u = 1, unitCount do
        local unit = units[u]
        -- Get unit position
        -- local ux, uz = unit[1],unit[3]
        -- unitSet[u] = {ux, unit, uz, -1} -- Such that x/z are in same place as in nodes (So we can use same sort function)
        local pos = unitSet[u]
        local ux,uz = pos[1],pos[3]
        pos[2]=unit
        pos[4]=-1


        -- Work on finding furthest points (As we have ux/uz already)
        for i = u - 1, 1, -1 do
            
            local up = unitSet[i]
            local vx, vz = up[1], up[3]
            local dx, dz = vx - ux, vz - uz
            local dist = dx^2 + dz^2
            
            if (dist > fdist) then
                fdist = dist
                fm = (vz - uz) / (vx - ux)
            end
        end
    end
    
    -- Maybe nodes are further apart than the units
    for i = 1, unitCount - 1 do
        
        local np = nodes[i]
        local nx, nz = np[1], np[3]
        
        for j = i + 1, unitCount do
            
            local mp = nodes[j]
            local mx, mz = mp[1], mp[3]
            local dx, dz = mx - nx, mz - nz
            local dist = dx*dx + dz*dz
            
            if (dist > fdist) then
                fdist = dist
                fm = (mz - nz) / (mx - nx)
            end
        end
    end
    
    local function sortFunc(a, b)
        -- y = mx + c
        -- c = y - mx
        -- c = y + x / m (For perp line)
        return (a[3] + a[1] / fm) < (b[3] + b[1] / fm)
    end
    
    tsort(unitSet, sortFunc)
    tsort(nodes, sortFunc)
    
    for u = 1, unitCount do
        unitSet[u][4] = nodes[u]
    end
    
    ---------------------------------------------------------------------------------------------------------
    -- Main part of algorithm
    ---------------------------------------------------------------------------------------------------------
    
    -- M/C for each finished matching
    local Ms = {}
    local Cs = {}
    
    -- Stacks to hold finished and still-to-check units
    local stFin = {}
    local stFinCnt = 0
    local stChk = {}
    local stChkCnt = 0
    
    -- Add all units to check stack
    for u = 1, unitCount do
        stChk[u] = u
    end
    stChkCnt = unitCount
    
    -- Begin algorithm
    while stChkCnt > 0 do
        
        -- Get unit, extract position and matching node position
        local u = stChk[stChkCnt]
        local ud = unitSet[u]
        local ux, uz = ud[1], ud[3]
        local mn = ud[4]
        local nx, nz = mn[1], mn[3]
        
        -- Calculate M/C
        local Mu = (nz - uz) / (nx - ux)
        local Cu = uz - Mu * ux
        
        -- StartProcess for clashes against finished matches
        local clashes = false
        
        for i = 1, stFinCnt do
            
            -- Get opposing unit and matching node position
            local f = stFin[i]
            local fd = unitSet[f]
            local fdx,fdz,tn = fd[1],fd[3],fd[4]
            -- Get collision point
            local ix = (Cs[f] - Cu) / (Mu - Ms[f])
            local iz = Mu * ix + Cu
            
            -- StartProcess bounds
            -- if ux==nx and uz==nz and fdx==tn[1] and fdz==tn[3] then
            if ux==fdx and uz==fdz then
                -- skip or it will be endless
            elseif (ux - ix) * (ix - nx) > 0 and
               (uz - iz) * (iz - nz) > 0 and
               (fdx - ix) * (ix - tn[1]) > 0 and
               (fdz - iz) * (iz - tn[3]) > 0 then
                
                -- Lines cross
                
                -- Swap matches, note this retains solution integrity
                ud[4] = tn
                fd[4] = mn
                
                -- Remove clashee from finished
                stFin[i] = stFin[stFinCnt]
                stFinCnt = stFinCnt - 1
                
                -- Add clashee to top of check stack
                stChkCnt = stChkCnt + 1
                stChk[stChkCnt] = f
                
                -- No need to check further
                if osclock()-t > 0.8 then 

                    Debug.algo('NoX took too long\n'..(ux - ix), (ix - nx)..' | '..(uz - iz), (iz - nz)..' | '..(fd[1] - ix), (ix - tn[1])..' |'..(fd[3] - iz), (iz - tn[3]))
                    Debug.algo('NoX coords\n'..ux..','..uz..' | '..nx..','..nz..' | '..fd[1]..','..fd[3]..' | '..tn[1]..','..tn[3])
                    break
                end
                clashes = true
                break
            end
        end
        
        if not clashes then
            
            -- Add checked unit to finished
            stFinCnt = stFinCnt + 1
            stFin[stFinCnt] = u
            
            -- Remove from to-check stack (Easily done, we know it was one on top)
            stChkCnt = stChkCnt - 1
            
            -- We can set the M/C now
            Ms[u] = Mu
            Cs[u] = Cu
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
function widget:Shutdown()
    if Debug.Shutdown then
        Debug.Shutdown()
    end
end


f.DebugWidget(widget)