

local version = '1.0'
function widget:GetInfo()
    return {
        name      = 'Impaler Targetter',
        author    = 'Helwor',
        desc      = 'Make Impaler prefer targetting structure and non-moving targets',
        date      = 'Autumn, 2021',
        license   = 'GNU GPL, v2 or later',
        layer     = -1000,
        enabled   = false,
        handler   = true,
    }
end
local debugScore = true
local Echo=Spring.Echo

local f = VFS.Include("LuaUI\\Widgets\\UtilsFunc.lua")

local Units
local MyUnitsByDefID
local myTeamID = Spring.GetMyTeamID()
local ignoreTargetName = {
    wolverine_mine = true,
}
structArmoredDefID={}
for id,def in ipairs(UnitDefs) do
    if def.armoredMultiple<1 and def.isImmobile and def.name~='turretantiheavy' and def.name~='turretheavy' and def.name~='energysolar' then
        structArmoredDefID[id] = true
    end
end
local weapNum = 1 -- until they change it, the weap number of Impaler to check is 1
local impaler_defID = UnitDefNames['vehheavyarty'].id
local wdef = WeaponDefs[UnitDefs[impaler_defID].weapons[weapNum].weaponDef]
local range = wdef.range
local reloadTime = wdef.reload*30 -- the reloadTime is not correct, we fix it in GameFrame
local weapTimer = wdef.customParams.weapontimer*30

local spGetUnitWeaponTarget = Spring.GetUnitWeaponTarget
local spGetUnitCurrentCommand = Spring.GetUnitCurrentCommand
local spGiveOrderToUnit = Spring.GiveOrderToUnit
local spGetUnitWeaponTarget = Spring.GetUnitWeaponTarget
local spGetUnitsInCylinder = Spring.GetUnitsInCylinder
local spGiveOrderToUnit = Spring.GiveOrderToUnit
local spGetUnitWeaponState = Spring.GetUnitWeaponState
local spGetUnitPosition = Spring.GetUnitPosition
local spGetUnitVelocity = Spring.GetUnitVelocity
local spGetUnitIsStunned = Spring.GetUnitIsStunned
local spGetUnitArmored = Spring.GetUnitArmored
local spValidUnitID = Spring.ValidUnitID
local spGetSelectedUnitsSorted = Spring.GetSelectedUnitsSorted
local spuGetUnitFireState = Spring.Utilities.GetUnitFireState
local spGetUnitRulesParam = Spring.GetUnitRulesParam
local min,max,abs,round = math.min,math.max,math.abs,math.round
local mol,nround = f.mol,f.nround

local customCmds = VFS.Include("LuaRules/Configs/customcmds.lua")
local CMD_UNIT_SET_TARGET = customCmds.UNIT_SET_TARGET
local CMD_UNIT_CANCEL_TARGET = customCmds.UNIT_CANCEL_TARGET
local CMD_ATTACK = CMD.ATTACK
local CMD_REMOVE = CMD.REMOVE


options_path = 'Hel-K/Impaler Targetter'
------------- DEBUG CONFIG
local Debug = { -- default values
    active=true -- no debug, no hotkey active without this
    ,global=false -- global is for no key : 'Debug(str)'

    ,score = false
}
-- Debug.hotkeys = {
--     active =            {'ctrl','alt','M'} -- this hotkey active the rest
--     ,global =           {'ctrl','alt','G'}

--     ,score =            {'ctrl','alt','S'}
-- }



local TARGET_UNIT = 2


--local f = VFS.Include('LuaUI\\Widgets\\UtilsFunc.lua')
local ATTACK_TABLE = {}
local impalers={}
local impalersSelected

local myDrawOrders
local nextframe
local orderByID = {}
local function OrderDraw(str,id,color)
    str = tostring(str)
    local order = orderByID[id]
    if order and myDrawOrders[order] then
        order.str = str
        order.timeout = os.clock()+5
    else
        order = {str=str,type='font',pos={id},timeout = os.clock()+5,color=color}

        table.insert(
            myDrawOrders
            ,order
        )
        myDrawOrders[order] = true
        orderByID[id] = order
    end
    -- table.insert(DrawUtils.screen[widget]
    --     ,{type='rect',pos={150,200,50,100},timeout=os.clock()+5,blinking = 0.7,color=color}
    -- )

end


function widget:MyNewTeamID(id)
    myTeamID = id
    knownUnits={}
end
local function CheckTarget(id,unit)
    if not unit.isEnemy or unit.isWobbling then
        return
    end
    if ignoreTargetName[unit.name] then
        return
    end
    local score
    local isArmored
    if unit.isStructure then
        score = 2
        if unit.name == 'staticmex' then
            score = score +2
        elseif (unit.cost>=400 or unit.name=='turretriot' or unit.name == 'staticcon') then
            score = score + 1
        end
        local unitArmored = spGetUnitArmored(id)
        if unitArmored==true then
            isArmored = 1
        elseif unitArmored==nil and structArmoredDefID[unit.defID] then
            isArmored = 1
        end
        -- if structArmoredDefID[unit.defID] then
        --     Echo("unit.name, spGetUnitArmored(id) is ", unit.name, spGetUnitArmored(id), isArmored, score)
        -- end
    elseif unit.cost and unit.cost>100 then
        if spGetUnitIsStunned(id) then 
            score = 2
        elseif unit.name=='shieldshield' then 
            score = 1
        else
            local velx,vely,velz = spGetUnitVelocity(id)
            if velx and (abs(velx)+abs(velz))<0.3 then
                score=1
            end
            if unit.name=='shieldassault' or unit.name=='shieldfelon' or unit.name=='shieldcon' then
                score = (score or 0) +  0.5
            end
        end
        if score and not unit.cost then
            OrderDraw(score,id,'red')
            -- f.Page(unit)
        end
        if score then
            if unit.cost>=400 then
                score = score + 1
            end
        end
    end
    if score then
        if isArmored then
            score = score - isArmored
        end
        if Debug.score() then
            local txt = score%1 == 0 and score or ('%.1f'):format(score)
            OrderDraw(txt .. (isArmored and 'a' or ''),id,'white')
        end
    end
    return score
end
-- fixing bad reloadTime -- old method, not using it anymore since we want to set attack before the end of reload, or missile will rectract
-- local lastReload = {rf=false,estimate=false}
-- local fixReloadTime=true
-- NOTE, impaler take about 2 seconds to deploy its missile, which make reloadtime longer if it hasnt set any target yet
function widget:GameFrame(gf)
    if not nextFrame or  nextFrame>gf then return end
    impalers = MyUnitsByDefID[impaler_defID]

    if impalers and next(impalers) then
        nextFrame = false
        -- first check which impalers we gonna take care of, this round, and set the next frame
        local impsToTreat = {}
        for id,imp in pairs(impalers) do
            if not imp.isGtBuilt and spValidUnitID(id) and not (Units[id].manual and Units[id].cmd == CMD_ATTACK) and spuGetUnitFireState(id)==2 then
                local angleGood, reloaded, reloadFrame, salvo, stockPile = spGetUnitWeaponState(id,weapNum)
                -- Echo('time elapsed between 2 reloads '..(reloadFrame-lastRF)/30)
                local nextReload
                -- OLD METHOD, bad because we need to set target before the reloadFrame so it gives time for the missile to deploy and be rdy in time
                -- if reloadFrame>gf+1 then -- we're in the middle of a reload
                    -- nextReload = reloadFrame-1
                    -- if fixReloadTime and lastReload.estimate==gf then reloadTime=reloadFrame-lastReload.rf fixReloadTime=false Echo('\nreloadTime fixed to '..reloadTime,reloadTime/30,check,check/30) end
                -- else  
                    -- nextReload = max(reloadFrame-1,gf-1)+reloadTime
                -- end

                -- if fixReloadTime then
                --     lastReload.rf = reloadFrame==gf+1 and reloadFrame
                --     lastReload.estimate= lastReload.rf and nextReload
                -- end
                -- Echo("we're at frame "..gf, 'reloadFrame is '..reloadFrame,'our next reload estimate is '..nextReload,reloadFrame<=gf+1 and '\n'..id..' is about to shoot' or '')

                -- next reload at reloadFrame minus weapon deployment time (in order for the weapon to deploy just in time for the shot )
                -- next reload is also just before the reload time to switch/fix target
                nextReload =  reloadFrame<=gf+1 and reloadFrame+reloadTime-weapTimer-5
                           or reloadFrame-1


                -- Echo("nextReload is ", nextReload,nextFrame)
                -- if nextReload>gf then
                if nextReload>gf then
                    nextFrame = not nextFrame and nextReload or min(nextFrame,nextReload)
                end
                -- end
                -- we don't wait for reloadFrame to be so close, we need to set target way before, because of the missile deployment time
                -- if reloadFrame<=gf+1 then -- those gonna shoot immediately
                    impsToTreat[id]=imp
                -- end
            end
        end
        if not nextFrame then
            nextFrame = gf + 60
        end

        if not next(impsToTreat) then return end
        -- then we gather all units in range of them without duplicate
        local validTargets={}
        for id,imp in pairs(impsToTreat) do

            imp.potentialTargets = {}
            local x,y,z = spGetUnitPosition(id)
            local inrange = spGetUnitsInCylinder(x,z,range)
            for i=1,#inrange do
                local uid = inrange[i]
                if spValidUnitID(uid) then
                    local unit = Units[uid]
                    if unit then
                        imp.potentialTargets[uid]=unit
                        validTargets[uid]=unit
                    end
                end
            end
            local manual_target = imp.manual_target
            if manual_target then
                if imp.ground_target then
                    -- ground target
                elseif not imp.potentialTargets[imp.manual_target] then
                    imp.manual_target = false
                end
            end
        end
        -- then we remove non relevant units
        local maxScore=0
        for id,unit in pairs(validTargets) do
            local score = CheckTarget(id,unit)
            -- if score then Echo('setting score '..score..' to '..unit.name..', id '..id) end
            validTargets[id]=score -- score can be nil
            if score and score>maxScore then
                maxScore=score
            end
        end
        if not next(validTargets) then 
            -- Echo('no valid units at all, rechecking in '..nround((nextFrame-gf)/30,0.5)..' seconds' )
            return
        else
            -- Echo('got valid unit, rechecking in '..nround((nextFrame-gf)/30,0.5)..' seconds' )
        end -- no valid Units, we recheck in max 2 seconds
        -- then we set the target or correct the existing one
        for id,imp in pairs(impsToTreat) do
            local _,isUserTarget,tgt_id= spGetUnitWeaponTarget(id,weapNum)
            if imp.ground_target and not isUserTarget then
                imp.ground_target, imp.manual_target = false, false
            end
            -- Echo("isUserTarget, tgt_id is ", isUserTarget, tgt_id)
            local cmd,opt,tag,tgt_cmd = spGetUnitCurrentCommand(id)
            local hasSetTarget
            -- local target_type = spGetUnitRulesParam(id, "target_type")
            -- Echo("target_type is ", target_type,cmd)
            -- if imp.manual_target then
            --     if target_type==TARGET_UNIT then
            --         local tgtID = spGetUnitRulesParam(id, "target_id") -- NOTE: there is still the last target id even if the targetting has been cancelled ! (should fix)
            --         if tgtID and tgtID~=0 and spValidUnitID(tgtID) then
            --             -- Echo(id,'the user has a manual target',tgtID) 
            --         end
            --     end
            -- end
            -- Echo(os.clock(),"isUserTarget is ", isUserTarget,tgt_id,imp.manual_target)
            -- if not isUserTarget then
            if imp.manual_target then
                -- Echo(id, 'target is manual')
            else
                -- Echo('targetting auto')
                -- imp.manual = false
                -- Echo("validTargets[tgt_id] is ", validTargets[tgt_id])
                local tgt_score = validTargets[tgt_id]
                local tgt_cmd_score = validTargets[tgt_cmd_score]
                
                if tgt_score and tgt_score==maxScore then 
                    -- Echo('impaler '..id..' got already a best target '..Units[tgt_id].name..' '..id,'score: '..tgt_score,'maxScore: '..maxScore)
                    if cmd==CMD_ATTACK and tgt_cmd~=tgt_id then
                        -- Echo('attacking bad target, changing order to attack ',tgt_id)
                        spGiveOrderToUnit(id,CMD_REMOVE,tag,0)
                        ATTACK_TABLE[1]=tgt_id
                        spGiveOrderToUnit(id,CMD_ATTACK,ATTACK_TABLE,0)
                    end
                end

                if not tgt_score or tgt_score<maxScore then
                    
                    local score,target
                    for uid,unit in pairs(imp.potentialTargets) do
                        local s = validTargets[uid]
                        if s then
                            if not score or s>score then score,target = s,uid end
                            if score==maxScore then break end
                        end

                    end

                    if target then
                        if tgt_id then spGiveOrderToUnit(id,CMD_UNIT_CANCEL_TARGET,0,0) end

                        -- Echo('targetting '..Units[target].name..', it has a score of '..score)
                        ATTACK_TABLE[1]=target
                        spGiveOrderToUnit(id,CMD_UNIT_SET_TARGET,ATTACK_TABLE,CMD.OPT_INTERNAL)
                        if cmd==CMD_ATTACK and tgt_cmd~=target then
                            -- Echo('switching Attack target')
                            spGiveOrderToUnit(id,CMD_REMOVE,tag,0)
                            ATTACK_TABLE[1]=target
                            spGiveOrderToUnit(id,CMD_ATTACK,ATTACK_TABLE,0)
                        end

                        -- spGiveOrderToUnit(id,CMD_ATTACK,ATTACK_TABLE,0)
                    else
                        -- Echo('no potential target for '..id..' rechecking in max 2 seconds') nextFrame=min(gf+60,nextFrame)
                    end
                end
            end
        end
        -- Echo("--",nextFrame,gf)
    else
        nextFrame = gf+60 -- check for new impalers in 2 seconds
    end

end
function widget:CommandNotify(cmd,params)

    if impalersSelected then
        if cmd==CMD_UNIT_SET_TARGET or cmd == CMD_ATTACK then
            local tgtID = params[1]
            for i,id in ipairs(impalersSelected) do
                local impaler = impalers[id]
                if impaler then
                    impaler.manual_target = tgtID
                    impaler.ground_target = params[3]
                    -- Echo(id,'manual target =>', tgtID, 'ground target?', impaler.ground_target)
                end
            end
        end
    end

    -- Echo("cmd is ", cmd)
end
function widget:CommandsChanged()
    impalersSelected = (WG.selectionDefID or spGetSelectedUnitsSorted())[impaler_defID]

end
function widget:UnitFinished(id,defID)
    if defID == impaler_defID then
        local unit = Units[id]
        if unit and unit.isMine then
            nextFrame = Spring.GetGameFrame()
        end
    end
end

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

function widget:Initialize()
    -- if not WG.Dependancies:Require(widget,'Command Tracker',true) then
    --     Echo(widget:GetInfo().name .. "don't have the required widgets loaded")
    --     widgetHandler:RemoveWidget(self)
    --     return
    -- end
    -- Debug Weapon Details
    -- local wdef = WeaponDefs[UnitDefs[impaler_defID].weapons[weapNum].weaponDef]
    -- this formula is 3/4 frames sec short of the reloadTime+deployment (378 vs real 374/375 frames)
    --                    15f                         2.0999999 sec                  10.0000095 sec
    -- local frames = wdef.customParams.reaim_time + wdef.customParams.weapontimer*30 + wdef.reload*30
    -- Echo("check is ", frames,frames/30,wdef.customParams.weapontimer)

    nextFrame = (Spring.GetGameFrame() or 0) +1

    Units=WG.UnitsIDCard
    MyUnitsByDefID=Units.mine.byDefID
    impalers = MyUnitsByDefID[impaler_defID]
    Debug = f.CreateDebug(Debug,widget, options_path)
    
    if WG.DrawUtils then
        DrawUtils = WG.DrawUtils
        DrawUtils.screen[widget] = {}
        myDrawOrders = DrawUtils.screen[widget]
    else
        OrderDraw = function() end
    end
    widget:CommandsChanged()
    --
end
function widget:Shutdown()
    if myDrawOrders then
        for order in pairs(myDrawOrders) do
            myDrawOrders[order] = nil
        end
    end
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
--         end

end
