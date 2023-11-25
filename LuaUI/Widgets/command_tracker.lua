

function widget:GetInfo()
    return {
        name      = "Command Tracker",
        desc      = "register current order of tracked units",
        author    = "Helwor",
        date      = "October 2022",
        license   = "GNU GPL, v2",
        layer     = -1000000000, -- before Smart Builders
        enabled   = false,  --  loaded by default?
        handler   = true,
        api       = true,
    }
end
local Echo                          = Spring.Echo
local f = VFS.Include("LuaUI\\Widgets\\UtilsFunc.lua")
local ploppableDefs = {}
for unitDefID, unitDef in pairs(UnitDefs) do
    local cp = unitDef.customParams
    if cp.ploppable then
        ploppableDefs[unitDefID] = true
    end
end
------------- Partial DEBUG
local Debug = { -- default values
    active=false, -- no debug, no hotkey active without this
    global=true, -- global is for no key : 'Debug(str)'
    UC = false,
    selected = false,
    drawCmd = false,
    autoguard = false,

}
-- Debug.hotkeys = {
--     active =            {'ctrl','alt','T'} -- this hotkey active the rest
--     ,global =           {'ctrl','alt','G'}
--     ,UC =               {'ctrl','alt','U'}
-- }
options_path = 'Hel-K/' .. widget:GetInfo().name
-- setmetatable(Debug,{__index=function(t,k) return function()end end,__call=function(t,k) return function()end end})
-------------

-- local debugProps = false

-- config
-- local trackAll = false -- track every units

local trackedUnits

local engineTag = {}
local manualTag = {}
local vunpack   = f.vunpack
local Page = f.Page
local selByID = {}

local page = 0

local CMD = CMD
local cmdNames = setmetatable(f.CMD_NAMES, {__index=function(t,k) return 'UNKNOWN' .. (k<0 and 'BUILD' or '')  end })
local DebugUnitCommand = f.DebugUnitCommand

local spGetUnitDefID                = Spring.GetUnitDefID
local spGetAllUnits                 = Spring.GetAllUnits
local spGetMyTeamID                 = Spring.GetMyTeamID
local spGetUnitPosition             = Spring.GetUnitPosition
local spAreTeamsAllied              = Spring.AreTeamsAllied
local spGetUnitTeam                 = Spring.GetUnitTeam
local spValidUnitID                 = Spring.ValidUnitID
local spGetGameSeconds              = Spring.GetGameSeconds

local spIsReplay                    = Spring.IsReplay
local spGetSpectatingState          = Spring.GetSpectatingState
local spGetCommandQueue             = Spring.GetCommandQueue
local spGetUnitRulesParam           = Spring.GetUnitRulesParam
local spGetGameFrame                = Spring.GetGameFrame
local spGetUnitHealth               = Spring.GetUnitHealth
local spGetUnitIsDead               = Spring.GetUnitIsDead
local spGetUnitCurrentCommand       = Spring.GetUnitCurrentCommand
local spGetUnitCommands             = Spring.GetUnitCommands
local spGetFactoryCommands          = Spring.GetFactoryCommands

local spGetSelectedUnits            = Spring.GetSelectedUnits
local spGetGroundHeight             = Spring.GetGroundHeight
local spuGetMoveType                = Spring.Utilities.getMovetype
local spValidFeatureID              = Spring.ValidFeatureID
local spGiveOrderToUnit             = Spring.GiveOrderToUnit




local UnitDefs = UnitDefs

local remove = table.remove
local round = math.round

local gamePaused

local rezedFeatures = {}
local checkCommands = {}
local confirm = {}
local removeAutoGuard = {}
local UpdateUnpause = {}
local debugSelected = {}
local maxUnits = Game.maxUnits
local myTeamID = Spring.GetMyTeamID()
local EMPTY_TABLE = {}
local Units

local hasTrackedUnit = false

local shift,meta = false,false

local customCmds = VFS.Include("LuaRules/Configs/customcmds.lua")

local CMD_RESURRECT = CMD.RESURRECT
local CMD_RECLAIM = CMD.RECLAIM
local CMD_FIGHT,CMD_ATTACK,CMD_RAW_MOVE = CMD.FIGHT,CMD.ATTACK,customCmds.RAW_MOVE
local CMD_FIRE_STATE = CMD.FIRE_STATE
local CMD_GUARD = CMD.GUARD
local CMD_REPAIR = CMD.REPAIR
local CMD_REMOVE = CMD.REMOVE
local CMD_STOP = CMD.STOP
local CMD_OPT_SHIFT, CMD_OPT_INTERNAL = CMD.OPT_SHIFT, CMD.OPT_INTERNAL
local terraunitDefID = UnitDefNames['terraunit'].id


local passiveCommands = {
    [CMD_PRIORITY] = true
    ,[CMD_WANT_CLOAK] = true
    ,[CMD_WANT_ONOFF] = true
}

local isBuildingCommand = setmetatable(
    {
        [CMD.RESTORE] = true
        ,[CMD_RAISE] = true
        ,[CMD_RAMP] = true
        ,[CMD_LEVEL] = true
        ,[CMD_SMOOTH] = true
    },
    {
        __index = function(t,k)
        -- NOTE: newly plane con get a -29 order (bomberheavy) for some reason (??)
            return k and k<0 and k~=-29
        end
    }
)

for name,id in pairs(CMD) do
    if type(name)=='string' and (name:match('_STATE') or name=='REPEAT' or name:match('ONOFF') or name == 'IDLEMODE' ) then
        passiveCommands[id]=true
    end
end

local cheatCommand = {
    [customCmds.CHEAT_GIVE] = true

}

local commandIssued
local areaCmd = {
    [CMD.RECLAIM] = true
    ,[CMD.REPAIR] = true
    ,[CMD_RESURRECT] = true
    ,[CMD.LOAD_UNITS] = true
    ,[CMD.UNLOAD_UNITS] = true
}



local TABLE_2 = {2}
local TABLE_1 = {1}


local fightingCmds = {
    [CMD_ATTACK]=true
    ,[CMD_RAW_MOVE]=true
}


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

function table:compare3(t2)
    return self[1]==t2[1] and self[2]==t2[2] and self[3]==t2[3]
end

local optsread = function(options)
    local str = ''
    for k,v in pairs(options) do
        if k == 'coded' or v then
            str = str .. k .. ': ' .. tostring(v) .. ' | '
        end
    end
    -- Echo(str:sub(1-4))
    return str:sub(1,-4)
end
local function UpdateUnitCommand(unit,id,fromCmdDone,fromLua,ifChanged,justFinished)
    local curC=unit.isFactory and spGetFactoryCommands(id,1)[1] or spGetUnitCommands(id,1)[1]

    local cmd, tag
    if curC then
        cmd,tag  = curC.id, curC.tag
    end
    if cmd and cmd<0 then
        
    elseif unit.isFactory then
        return
    end

    if ifChanged then
        local changed = unit.cmd ~= cmd
        local oldParams = unit.params
        if not changed and curC.params and oldParams then
            for i,p in ipairs(curC.params) do
                if p~=oldParams[i] then
                    changed = true
                    -- Echo('command has changed, params '..i..': '..p..', differs from previous param ('..oldParams[i]..')')
                    break
                end
            end
        end
        if not changed then
            -- Echo('command has not changed')
            return
        end

    end
    -- Echo("curC and cmd is ", curC and cmd)
    -- local queue = spGetCommandQueue(id,-1)
    -- for i,v in ipairs(queue) do
    --     Echo('in queue',i,v.id)
    -- end
    local realcmd, realparams, realopts, realtag, maincmd, mainparams
    -- Echo("cmd is ", curC and cmd)

    -- unit.isFighting = cmd==CMD_FIGHT 
    -- if not unit.isFighting and curC and curC.params[5] then
    --     local queue = spGetCommandQueue(id,2)
    --     if queue[2] and queue[2].id == CMD_FIGHT then
    --         unit.isFighting = true
    --     end
    -- end
    -- Echo(cmd,'unit.expectedCmd in UpdateCommand',unit.expectedCmd,'fromLua',fromLua)
    if cmd and not (passiveCommands[cmd] or cmd==CMD_STOP and unit.isGtBuilt) then
        -- widget:UnitCommand(id,spGetUnitDefID(id),spGetUnitTeam(id),cmd,curC.params,curC.options,curC.tag)
        -- Echo('update unit command: '.. tostring(cmd))
        if cmd ~= CMD_RAW_BUILD then
            unit.building = false
            unit.assisting = false
        end
        local repairing, queueIndex = cmd==CMD_REPAIR, 1
        local queue

        if isBuildingCommand[cmd] then
            unit.building = true

        elseif cmd == CMD_RAW_BUILD  then
            queue = spGetCommandQueue(id,4)
            -- if queue[3] and queue[3].id == CMD_FIGHT and fromLua then
            --     -- Echo('put on fighting',unit.manual,unit.waitCmd,unit.cmd,unit.params,unit.params and table.compare3(queue[2].params, unit.params))
            --     -- unit.isFighting = true
            -- end
                -- Echo("queue[2] and queue[2].id is ", queue[2] and queue[2].id)
            if queue[2] then
                realcmd = queue[2].id
                realparams = queue[2].params
                realtag = queue[2].tag
                realopts = queue[2].options
            end

            
            if realcmd == CMD_REPAIR then
                repairing, queueIndex = true, 2
            -- elseif justFinished then
            --     if realcmd~=CMD_GUARD --[[or queue[3]--]] then
            --         unit.manual = true
            --         unit.autoguard = false
            --     end

            end

        end

        if repairing then
            local queue = queue or spGetCommandQueue(id,queueIndex + 2 )
            local params = queue[queueIndex].params
            local tgt = (not params[2] or params[5]) and params[1] and Units[params[1]]
            if tgt then
                if tgt.defID == terraunitDefID then
                    unit.building = true
                    local nextOrder = queue[queueIndex+1]
                    if nextOrder then
                        if nextOrder and nextOrder.id>0 and isBuildingCommand[nextOrder.id] then
                            maincmd, mainparams = nextOrder.id, nextOrder.params
                        end
                        if nextOrder.id == CMD_LEVEL then
                            local afterOrder = queue[queueIndex+2]
                            -- Echo('verif fourth',fourth and fourth.id <0,fourth and fourth.id <0 and table.compare3(fourth.params,queue[3].params))
                            if afterOrder and afterOrder.id <0 and table.compare3(afterOrder.params, nextOrder.params) then
                                maincmd = afterOrder.id
                                mainparams = afterOrder.params
                             end
                        end
                    end
                elseif tgt.isGtBuilt then
                    unit.building = true
                    -- unit.actualCmd = -tgt.defID
                    local builtBy = tgt.builtBy
                    if builtBy then 
                        if builtBy ~= id then
                            unit.assisting = builtBy
                        else

                        end
                    end
                end
            end
        end
        unit.actualCmd = realcmd
        -- Echo("realcmd,realparams is ", realcmd,realparams)
        local relevantCmd = realcmd or cmd
        local relevantTag = realtag or tag
        if unit.expectedCmd==CMD_FIGHT then
            unit.isFighting = true
            if relevantCmd~=CMD_FIGHT then
                -- Echo('set engine tag',relevantTag,'relevantCmd',relevantCmd,'cmd',cmd,'tag',tag,'realcmd',realcmd,'realtag',realtag)
                engineTag[relevantTag] = relevantCmd
            end
        end
        -- Echo("fromCmdDone", fromCmdDone,'cmd',cmd,'tag',tag,'relevantCmd',relevantCmd,'relevantTag',relevantTag,'expected:',unit.expectedCmd)
        if fromCmdDone then
            if relevantCmd == CMD_FIGHT then
                unit.isFighting = true
                unit.manual = false
                -- Echo('relevant cmd is fight')
            elseif engineTag[relevantTag] then
                -- Echo('detected engine tag: ' .. relevantTag .. ', cmd => ' .. engineTag[relevantTag] .. ', unit is fighting')
                unit.isFighting = true
                unit.manual = false
            else
                if unit.expectedCmd and unit.expectedCmd~=CMD_FIGHT then
                    unit.manual = true
                end
                -- FIX: not perfect, we're just guessing that this order has been given through manual means
                -- unit.manual = true
            end
        end

        if unit.manual then
            if fromLua and unit.isFighting then
                unit.manual = false
            else
                unit.isFighting = false
            end
            -- Echo('set to false bc manual, fromLua ?',fromLua)
        end
        -- Echo("cmd,curC.options.coded,realcmd,realoptions and realoptions.coded is ", cmd,curC.options.coded,realcmd,realopts and realopts.coded)
        NotifyExecute(id,cmd,curC.params,curC.options,curC.tag,fromCmdDone,fromLua, realcmd, realparams,realopts,realtag,maincmd,mainparams)

    else
        unit.manual = false
        unit.actualCmd = false
        unit.actualParams = false
        if not unit.isIdle then
            widgetHandler:UnitIdle(id)
        end
    end
    return true
end

local function SetTrackedUnit(id,justFinished, forDebug)
    if forDebug and trackedUnits[id] then
        return
    end

    trackedUnits[id] = Units[id] -- or {}

    -- Echo('Command Tracker is setting a new unit ',id,"IDCard?",Units and Units[id],trackedUnits[id] == Units[id])
    local unit = trackedUnits[id]
    if not unit then
        trackedUnits[id] = nil
        return
    end
    unit.forDebug = forDebug
    unit.isIdle = false
    unit.tracked = true
    -- unit.manual = unit.manual or false
    -- unit.expectedCmd = unit.expectedCmd
    -- unit.actualCmd = unit.actualCmd
    unit.justFinished = justFinished
    unit.lastOrderTime = unit.lastOrderTime or 0
    UpdateUnitCommand(unit,id,nil,nil,nil,justFinished)
end

function widget:KeyPress(key,mods)
    shift,meta = mods.shift,mods.meta
    -- debugging
    -- if Debug.CheckKeys(key,mods) then
    --     return true
    -- end
    if not debugging then
        return
    end

    -- if key==106 and mods.alt then -- Alt + J track selected units or untrack if all are already tracked
    --     local sel = spGetSelectedUnits()
    --     local untrack = true
    --     for _,id in pairs(sel) do
    --         if not trackedUnits[id] then
    --             untrack = false
    --             break
    --         end
    --     end
    --     for i, id in pairs(sel) do
    --         if untrack then
    --             trackedUnits[id] = nil
    --         else
    --             SetTrackedUnit(id)
    --         end
    --     end
    -- end
    --
end
function widget:KeyRelease(key,mods)
    shift,meta = mods.shift,mods.meta
end
function widget:CommandsChanged()

    local sel = spGetSelectedUnits()
    selByID = {}
    hasTrackedUnit = false
    local debugSel = Debug.selected()

    for i,id in ipairs(sel) do 
        selByID[id]=true
        if debugSel then
            if not trackedUnits[id] then
                SetTrackedUnit(id,false, true)
            end
            debugSelected[id] = trackedUnits[id]
            -- Echo('debug tracking selected ' .. UnitDefs[spGetUnitDefID(id)].name, '#'..id)
        end
        if trackedUnits[id] then
            hasTrackedUnit = true
            -- return
        end
    end
    if debugSel then
        for id in pairs(debugSelected) do
            if not selByID[id]  then
                debugSelected[id] = nil
                -- Echo('undebug tracking '.. UnitDefs[spGetUnitDefID(id)].name, '#'..id)
                if trackedUnits[id] then
                    if trackedUnits[id].forDebug then
                        trackedUnits[id].tracked = false
                        trackedUnits[id]=nil
                    else
                        -- Echo('but unit is still tracked')
                    end
                end
            end
        end
    end
end
-- NOTE: when areaCmd is ordered UNPAUSED, an immediate and INVISIBLE insertion happen to apply the order to an unit, this widget will notify the latest current command happening at the next game frame or updte cycle, it might not notify the area command that has been pushed at second or third position
-- NOTE: when AREA RECLAIM is issued an INVISIBLE FROM UNITCOMMAND AND FROM CMDDONE command to reclaim a feature is inserted before, if the con is too far, a VISIBLE RAW_BUILD command is inserted again before all
-- those Insertions APPEARS WHILE GAME IS NOT PAUSED
-- /// not anymore, the notification now report the area command /// NOTE: when some area commands (listed in areaCmd) are ordered while game is paused, the command will not be changed immediately at unpause, a few moment pass before
-- NOTE: AREA UNLOAD_UNIT bug, while PAUSED then ordering, the order doesn't show up in the order queue, and will not be removed if another AREA UNLOAD_UNIS is issued, instead it will be added up
-- local ids = {22263,5593,5602}
function widget:Update()
    page = page + 1
    -- local id = ids[2]
    -- local queueCount = Spring.GetCommandQueue(id,0)
    -- local queue = Spring.GetCommandQueue(id,-1)
    -- local curOrder = queue[1]
    -- local nexOrder = queue[2]
    -- local third = queue[3]
    -- -- Echo("QUEUE #"..queueCount.."=>", ((curOrder and curOrder.id and curOrder.id..(curOrder.params[1] and ','..curOrder.params[1]..' #'..#curOrder.params or '')) or '')
    -- Echo("QUEUE #"..queueCount..(curOrder and curOrder.id and "=>"..curOrder.id..'('..cmdNames[curOrder.id]..'):'..(curOrder.params[1] and table.concatsep(curOrder.params) or '') or '')
    --     .. ((nexOrder and nexOrder.id and " | NEXT: "..nexOrder.id..'('..cmdNames[nexOrder.id]..'):'..(nexOrder.params[1] and ','..nexOrder.params[1]..' #'..#nexOrder.params or '')) or '')
    --     .. ((third and third.id and " | THIRD: "..third.id..'('..cmdNames[third.id]..'):'..(third.params[1] and ','..third.params[1]..' #'..#third.params or '')) or '')
    --     )
    -- CONFIRM when order comes from UnitCommand, Check when refresh detected by UnitCmdDone
    for unitID in pairs(removeAutoGuard) do
        local queue = spGetCommandQueue(unitID,-1)
        local debugSel = debugSelected[unitID]
        Debug.autoguard('['..page..']'..'trying to remove autoguard')

        for i, order in ipairs(queue) do
            Debug.autoguard('['..page..']'..' ...checking order in update '.. order.id,'p1: '..tostring(order.params[1]))
            if order.id == CMD_GUARD then

                spGiveOrderToUnit(CMD_REMOVE,unitID, order.tag,0)
                -- if debugSel then
                    Echo('remove auto guard from Update')
                -- end
                local before = queue[i-1]
                if before then
                    if before.id == CMD_REPAIR then
                        spGiveOrderToUnit(CMD_REMOVE,unitID, before.tag,0)
                        -- if debugSel then
                            Echo('remove repair order from update')
                        -- end
                    elseif before.id == CMD_RAW_MOVE  then
                        spGiveOrderToUnit(CMD_REMOVE,unitID, before.tag,0)
                        -- if debugSel then
                            Echo('remove raw move order from update')
                        -- end
                    end
                end
                break
            end
        end
        removeAutoGuard[unitID] = nil
    end


    if next(confirm) then
        -- Echo('confirming order in Update',os.clock())
        for id,fromLua in pairs(confirm) do
            local unit = trackedUnits[id]
            if unit then
                UpdateUnitCommand(unit,id,nil,fromLua)
            end
            checkCommands[id] = nil
            confirm[id] = nil
        end
    end

    
    if next(checkCommands) then
        -- Echo('processing next order in Update',os.clock())
        for id,unit in pairs(checkCommands) do
            -- local order = {spGetUnitCurrentCommand(id)}
            -- if not order[1] then
            --     widgetHandler:UnitIdle(id)
            -- else
            --     local str = remove(order,1) .. ': \n'
            --     remove(order,1) ; remove(order,1)
            --     unit.text = str .. table.concatsep(order)

            -- end
            unit.actualCmd, unit.expectedCmd = false, false
            UpdateUnitCommand(unit,id,true)
            -- Echo('command checked')
            checkCommands[id] = nil
        end
    end
end

function widget:GameFrame(gf)
    -- Echo("next(UpdateUnpause) is ", (next(UpdateUnpause)))

    if next(confirm) then
        -- Echo('confirming order in GF',os.clock())
        for id,fromLua in pairs(confirm) do
            local unit = trackedUnits[id]
            if unit then
                UpdateUnitCommand(unit,id,nil,fromLua)
            end
            checkCommands[id] = nil
            confirm[id] = nil
        end
    end
    if next(checkCommands) then
        -- Echo('processing next order in GF',os.clock())
        for id,unit in pairs(checkCommands) do
            -- local order = {spGetUnitCurrentCommand(id)}
            -- if not order[1] then
            --     widgetHandler:UnitIdle(id)
            -- else

            --     local str = remove(order,1) .. ': \n'
            --     remove(order,1) ; remove(order,1)
            --     unit.text = str .. table.concatsep(order)
            -- end

            unit.actualCmd, unit.expectedCmd = false, false
            UpdateUnitCommand(unit,id,true)
            -- Echo('command checked')
            checkCommands[id] = nil
        end
    end
    if next(UpdateUnpause) then
        -- Echo(gf,"next(UpdateUnpause) is ", next(UpdateUnpause))
        for id,fromLua in pairs(UpdateUnpause) do
            
            local unit = trackedUnits[id]
            if not unit then
                UpdateUnpause[id] = nil
            else
                local changed = UpdateUnitCommand(unit,id,nil,fromLua,true)
                if changed then
                    UpdateUnpause[id] = nil
                end
            end
        end
    end

    if checkResurrect then
        for id in pairs(checkResurrect) do
            local cmd,_,_,target = spGetUnitCurrentCommand(id)
            if cmd==CMD_RESURRECT then rezedFeatures[target-maxUnits]=true end
        end
        checkResurrect=nil
        return
    end
    if (gf+25)%30==0 and next(rezedFeatures) then
        for id in pairs(rezedFeatures) do
            if not spValidFeatureID(id) then rezedFeatures[id]=nil end
        end
    end
end

callbacksExec = {}
local function CallbackExec(...)
    for name,cb in pairs(callbacksExec) do
        cb(...)
    end
end
callbacksIdle = {}
local function CallbackIdle(...)
    for name,cb in pairs(callbacksIdle) do
        cb(...)
    end
end

function NotifyIdle(id,unit)
    CallbackIdle(id,unit)
end
function widget:UnitIdle(id)
    local unit = trackedUnits[id]
    if not unit then
        return
    end
    if unit.waitManual then
        if os.clock() - unit.waitManual > 0.8 then
            unit.waitManual = false
        else
            -- Echo('WAIT MAN',os.clock())
            return
        end
    end
    unit.isIdle = true
    -- Echo('REAL IDLE',os.clock())
    unit.manual = false
    unit.building = false
    unit.cmd, unit.params = false, false
    unit.realcmd = false
    unit.realparams = false
    unit.maincmd = false
    unit.mainparams = false
    unit.actualCmd = false
    unit.assisting = false
    unit.autoguard = false
    unit.expectedCmd = false
    unit.expectedParams = false
    unit.isFighting = false
    NotifyIdle(id,unit)
end


function NotifyExecute(id,cmd,params,opts,tag,fromCmdDone,fromLua,realcmd,realparams,realopts,realtag,maincmd,mainparams)
    -- Echo('notify',os.clock(),'id: ' .. id,'realcmd ' ..  tostring(realcmd), 'cmd '..cmd,unpack(params))
    local unit = trackedUnits[id]
    UpdateUnpause[id]=nil
    if not unit then
        return
    end
    -- Echo('notif',cmd,opts.coded)
    -- Echo("notify execute, cmd", cmd,'realcmd',realcmd,'expectedCmd', unit.expectedCmd, 'realparams',realparams,unpack(params))
    -- Echo(id..' is executing '..cmd, unpack(params))
    -- local rparams = table.round(params,true)
    -- local str = cmdNames[realcmd or cmd] .. '(' .. (realcmd or cmd) .. ') : \n' .. (realcmd~=cmd and '...' or table.concatsep(rparams))
    
    if unit.building then
        
    end
    if not unit.actualCmd then
        unit.actualCmd = cmd
    end
    realcmd = realcmd or cmd
    realparams = realparams or params
    realopts = realopts or opts
    realtag = realtag or tag
    maincmd = maincmd or realcmd
    mainparams = mainparams or realparams

    unit.cmd = cmd
    unit.params = params
    unit.realcmd = realcmd
    unit.realparams = realparams
    unit.maincmd = maincmd
    unit.mainparams = mainparams
    -- if unit.isFighting then
    --     str = str .. '\nis fighting'
    -- end
    if unit.replaceCurrent==2 then
        -- str = str .. '\ncurrent replaced'
        unit.replaceCurrent = false
    elseif fromCmdDone then
        -- str = str .. '\nexec next order'
    end


    unit.isIdle = false
    -- Echo('Final building',unit.building)
    -- Echo('in notify exec unit.manual is',unit.manual,Units[id].manual)


    CallbackExec(unit,id,cmd,params,opts,tag,fromCmdDone,fromLua,realcmd,realparams,realopts,realtag,maincmd,mainparams)
    -- f.Page(opts)
end
-- for k,v in pairs(CMD) do
--     if tonumber(k) == 13337 or tonumber(v)==13337 then
--         Echo('k,v')
--     end
-- end
function widget:GamePaused(_,paused)
    gamePaused = paused
end
function widget:UnitCommandNotify(id,cmd,params)
    if hasTrackedUnit then
        local unit = trackedUnits[id]
        if unit then
            if unit.isGtBuilt then
                unit.manual = true
            else
                unit.waitCmd = cmd~=1 and cmd or params[2]
                unit.waitParams = cmd~=1 and params or params[4] and {select(4,unpack(params))} or EMPTY_TABLE
                unit.waitManual = os.clock()
            end
        end
    else
        commandIssued = false
    end

end

function widget:CommandNotify(cmd,params,opt)
    -- Echo('CN',cmd,unpack(params))
    -- if cmd<0 then
    --     Echo("cmd is ", cmd)
    --     Echo(" is ", spGetGroundHeight(params[1],params[3]), params[2])
    -- end

    if cheatCommand[cmd] then
        return
    end
    if passiveCommands[cmd] then
        return
    end
    Debug.autoguard('['..page..']'..'Cmd Notif ' .. cmd, hasTrackedUnit and 'has tracked' or 'no tracked')
    -- Echo('[opt]:'..table.kConcat(opt,' | ', 'only_true','debug_options'))
    -- Echo('[params]:{'..table.toline(params,nil,nil,0 )..'}')
    if hasTrackedUnit then
        -- Echo('command notif')
        for id in pairs(selByID) do
            -- commandIssued = cmd
            local unit = trackedUnits[id]
            if unit then
                if unit.isGtBuilt then
                    unit.manual = true
                    -- Echo('manual')
                else
                    unit.waitCmd = cmd==1 and params[2] or cmd
                    unit.waitParams = cmd==1 and params[4] and {select(4,unpack(params))} or params 
                    unit.waitManual = os.clock()
                    Debug.autoguard('['..page..']'..'wait manual','auto guard ?',unit.autoguard)
                    -- if unit. autoguard then
                    --     local queue = spGetCommandQueue(unit.id,4)
                    --     for i,order in ipairs(queue) do
                    --         Echo('order : ' .. order.id, 'options: '..optsread(order.options))
                    --         if order.id == CMD_GUARD and order.options.coded == CMD_OPT_SHIFT then

                    --         end
                    --     end
                    -- end
                end
            end
        end
    else
        commandIssued = false
    end
    -- Echo('CN',commandIssued)
end

-- NOTE: UnitCmdDone is triggered when an order is inserted before the current
-- UnitCmdDone tell that the currentOrder is done, even though in this case it is not yet accomplished 
-- checking queue will not tell about the newly inserted order, it will only tell the current so called 'done' order which is still present in this queue at this time
-- However UnitCommand will report the insertion before UnitCmdDone trigger
-- therefore it is not possible to guess from UnitCmdDone that our current order is done.
-- but we can check the next update, once it has triggered
-- another problem:
-- UnitCmdDone also get triggered when an order is removed, but then checking for the next order at this time might give a false information
-- if another order got inserted to replace the removed at the same time
-- again in this case UnitCommand has been triggered before
-- Since we can't know which order is done from the current queue, we check in the next Update/GameFrame cycle at each trigger of UnitCmdDone
function widget:UnitCmdDone(id, defID, team, cmd, params,opts,tag)
    local unit = trackedUnits[id]
    if not unit then
        return
    end
    if unit.replaceCurrent==1 then
        unit.replaceCurrent = 2
    end

    -- Echo('Cmd ' .. cmd .. ' Done')
    -- Echo(
    --     '[opt]:'..table.kConcat(opts,' | ', 'only_true','debug_options'),
    --     '[params]:{'..table.toline(params,nil,nil,0 )..'}',
    --     '[tag]:' .. tag
    -- )
    local curcmd,opt,curtag,p1,p2,p3,p4--[[,p5,p6,p7,p8--]] = spGetUnitCurrentCommand(id)
    -- NOTE: in case of insertion GetUnitCurrentCommand give the same as done command, and spGetCommandQueue(id,1) give the real current command
    -- if curtag == tag then
    -- -- if curcmd==cmd and table.compare(params,{p1,p2,p3,p4,p5,p6,p7,p8}) then
    --     local queue = spGetCommandQueue(id,2)
    --     local order1 = queue[1] and queue[1].id
    --     local order2 = queue[2] and queue[2].id
    --     Echo('Done CMD and current CMD is the same => Insertion occurring',order1,order2)
    -- elseif curcmd then
    --     Echo('Current: ' .. curcmd)
    --     Echo(
    --         -- '[cmd]:' .. curcmd, 
    --         '[opt]:'..table.kConcat(f.Decode(opt),' | ', 'only_true','debug_options'),
    --         '[params]:{'..table.toline({p1,p2,p3,p4,p5,p6,p7,p8},nil,nil,0 )..'}',
    --         '[tag]:' .. curtag
    --     )
    -- else
    --     Echo('no current cmd')
    -- end
    if unit.isFighting then
        if cmd==CMD_FIGHT and not p4 and curcmd~=CMD_FIGHT then
            -- Echo('fighting is over')
            unit.isFighting = false

            unit.manual = true -- FIX: this is a guess, we assume that order that have been put after fight is manual
            if unit.expectedCmd == CMD_FIGHT then
                unit.expectedCmd = false
            end
        elseif not unit.expectedCmd then
            unit.expectedCmd = CMD_FIGHT
        else
            -- in case an insertion happen and we're leaving an order that never got notified while fighting
            if curtag == tag then
                -- Echo('==> Insertion while fighting, rmb the tag',tag,cmd)
                engineTag[tag] = cmd
            end
        end
    end

    -- if curcmd==CMD_FIGHT or opt==CMD_INTERNAL and p5 then
    --     unit.isFighting = true
    --     unit.manual = false
    -- elseif cmd==CMD_FIGHT and not p4 and curcmd~=CMD_FIGHT then
    --     unit.manual=true
    --     Echo('put on manual')
    --     unit.isFighting = false
    -- end
    -------- cancelled -------
    -- local next = {spGetUnitCurrentCommand(id)}
    -- Echo('CMD DONE id:', id, 'cmd:', cmd,'tag:',tag,'params:', remove(params,1), unpack(params))
    -- -- Echo('CMD DONE, next CMD?',spGetUnitCurrentCommand(id))
    -- local queue = spGetUnitCommands(id,2)
    -- local n_orders = spGetUnitCommands(id,0)
    -- local nextOrder = queue[2]
    -- local currentOrder = queue[1]
    -- -- Echo("n_orders is ", n_orders)
    -- -- Echo('current Order ?',currentOrder and currentOrder.id,currentOrder and unpack(currentOrder.params))
    -- -- Echo('next Order?',nextOrder and nextOrder.id,nextOrder and unpack(nextOrder.params))
    -- if not nextOrder then
    --     -- 
    --     -- checkCommands[id]=unit
    -- else
    --     -- local opts = f.Decode(remove(next,2))
    --     -- NotifyExecute(id,nextOrder.id,nextOrder.params,nextOrder.options)
    -- end
    --------------
    checkCommands[id]=unit

end
-- NOTE: while fighting or aggroing, engine can send an order of ATTACK that doesn't pass by the UnitCommand CallIN
-- NOTE: even some command passed through UnitCommand can end up not beeing applied, for example strider hub is asked to build something outside of its range
 -- note: cmdTag is not cmdTag, I think it is playerID, to know the tag, I think we must check the next round in widget:Update() in the unitCommandQueue
local Decode = f.Decode 
function widget:UnitCommand(id, defID, teamID, cmd, params, opts, playerID,  tag, fromSynced, fromLua)
    local unit = trackedUnits[id]
    if not unit then
        return
    end
    local count = 0
    local time = os.clock()
    -- if unit.justFinished then
    if Debug.UC() and (not Debug.selected() or debugSelected[id]) then
        DebugUnitCommand(id, defID, teamID,  cmd, params, opts, tag,fromSynced,fromLua)
    end
        -- Echo('unit fighting ?',unit.isFighting)
    -- end
    -- if unit.justFinished== true then
    --     unit.justFinished = 4
    -- end
    -- if unit.justFinished then
    --     unit.justFinished = unit.justFinished - 1
    --     if unit.justFinished == 0 then
    --         unit.justFinished = false
    --     end
    -- end
    -- Echo('UC current',spGetUnitCurrentCommand(id))
    -- Echo('UC in CT: received order',cmd,unpack(params))

    -- if fromLua then  -- ignore automatic orders (jiggling around while attacking etc ...)
    --     return
    -- end

    if cmd == 2 then
        Debug.autoguard('['..page..']'..'received REMOVE tag '..tostring(params[1]))
    end

    local isShiftOrder = opts.coded%(CMD_OPT_SHIFT*2)>=CMD_OPT_SHIFT
    -- Echo("unit.waitManual is ", unit.waitManual,unit.waitCmd,'cmd is',cmd)
        
    local inserting = cmd==1
    local place = 0
    local isFactory = unit.isFactory
    local _cmd = cmd
    if inserting then
        params = {unpack(params)}
        place = remove(params,1)
        cmd = remove(params,1)
        opts = Decode(remove(params,1))
    elseif isShiftOrder or isFactory then
        place = -1
    end
    count = count+1
    if unit.waitManual  then
        -- Echo("unit.waitCmd==cmd, table.compare(unit.waitParams,params) is ", unit.waitCmd==cmd, table.compare(unit.waitParams,params))
        if os.clock() - unit.waitManual > 0.8 then
            unit.waitManual, unit.waitCmd, unit.waitParams = false, false, false
        end
    end

    -- Echo("spGetUnitCurrentCommand(id) is ", spGetUnitCurrentCommand(id))
    if passiveCommands[cmd] then
        return
    end
    if isFactory and cmd>2 then
        return
    end

    unit.replaceCurrent = false
    if cmd==2 then
        return
    end

    local curCmd, curCmd2
    if isFactory then
        local curOrder = spGetFactoryCommands(id,1)[1]
        curCmd = curOrder and curOrder.id
    else
        curCmd = spGetUnitCurrentCommand(id)
        -- curCmd2 = spGetCommandQueue(id,-1)[1]
        -- curCmd2 = curCmd2 and curCmd2.id
        -- if curCmd~=curCmd2 then -- never happened
        --     Echo('curCmd differ! : ',curCmd,curCmd2)
        -- end
    end
    local queue, queueLength
    local dbg = Debug.autoguard
    Debug.autoguard('['..page..']'.."cmd,place is ", cmd,place .. (fromLua and ', (lua)' or ''))

    if place~=0 then
        if (not curCmd or curCmd==0 and not gamePaused) then
            place = 0
        elseif not isFactory then
            -- removing guard order when order is inserted after, for first and second pos, not more ?
            queue, queueLength = spGetCommandQueue(id,5), spGetCommandQueue(id,0)
            -- Echo('cmd',cmd,'place',place,'orders',1,queue[1] and queue[1].id,2, queue[2] and queue[2].id,3,queue[3] and queue[3].id)
            -- for i, order in ipairs(queue) do
            --     Echo('-orders are #'..i,order.id,'tag '..order.tag)
            -- end
            local guardPos
            local first = queue[1]
            if first then
                if first.id == CMD_GUARD and (place>0 or place==-1) then
                    guardPos = 1
                    Debug.autoguard('['..page..']'..'command tracker is removing guard order at first pos, place of new cmd : '.. place)
                    spGiveOrderToUnit(id,CMD_REMOVE,first.tag,0)
                    guardPos = 1
                elseif queue[2] and queue[2].id == CMD_GUARD and (place>1 or place==-1) then
                    guardPos = 2
                    spGiveOrderToUnit(id,CMD_REMOVE,queue[2].tag,0)
                    local removeAssist = false
                    if unit.autoguard then
                        if first.id == CMD_RAW_MOVE or first.id == CMD_REPAIR then
                            removeAssist = true
                            spGiveOrderToUnit(id,CMD_REMOVE,first.tag,0)
                        end

                    end                    
                    Debug.autoguard('['..page..']'..'command tracker is removing guard and '.. (removeAssist and '' or '(not)') ..' assisting order '.. (removeAssist and first.id or '') .. ', place of new cmd : '.. place)

                    -- spGiveOrderToUnit(id,CMD_REMOVE,{first.tag},0) --// finally don't remove the assisting order, do as the gadget removing guard, does
                end
            end
            if guardPos == queueLength then
                Debug.autoguard('['..page..']'..'place moved to 0')
                place = 0
            end
            if unit.autoguard and guardPos then
                Debug.autoguard('['..page..']'..'autoguard falsified')
                unit.autoguard = false
            end

            -- place = spGetCommandQueue(id,0) or 0
        end
    end
    if fromLua and cmd == CMD_GUARD then
        if (unit.manual or unit.waitManual) then
            Debug.autoguard('['..page..']'..'remove auto guard>>>',2)
            removeAutoGuard[id] = 2
        else
            unit.autoguard = true
            Debug.autoguard('['..page..']'..'unit set to autoguard')
        end
        -- Echo(id,'unit is on auto guard,manual ?',unit.manual)
    end
    -- Echo("cmd,place is ", cmd,place)
    if isBuildingCommand[cmd] and not fromLua then
        -- if --[[place==1 and --]]unit.expectedCmd == CMD_LEVEL then
        --     unit.expectedCmd = cmd
        -- end

        if place == 0 and not unit.building then
            unit.building = true
        end
        if not unit.manual then
            unit.manual = true
            unit.isFighting = false
            unit.autoguard = false
        end
        -- Echo(id,'set to manual',cmd)
    end
    if place~=0 then
        unit.lastOrderTime = time
        if unit.waitManual then
            local removeManual = true
            if unit.autoguard then
                queue = queue or spGetUnitCommands(id,6)
                local lastOrder,prevLastOrder, guardPos
                for i, order in ipairs(queue) do
                    -- Echo('['..page..']'..'check order #'..i..' for autoguard',order.id, ' opts: '..optsread(order.options), 'tag: '..order.tag)
                    if order.id == CMD_GUARD then
                        guardPos = i
                        spGiveOrderToUnit(CMD_REMOVE,order.tag,0)
                        Debug.autoguard('['..page..']'..'removed autoguard at #'..i,'tag '..order.tag)
                        if lastOrder and (lastOrder.id == CMD_RAW_MOVE or lastOrder.id == CMD_REPAIR) then
                            -- Echo('['..page..']'..'removed #1'.. (lastOrder.id == CMD_RAW_MOVE and 'RAW_MOVE' or 'REPAIR'))
                            spGiveOrderToUnit(CMD_REMOVE,lastOrder.tag,0)
                            if prevLastOrder then
                                if prevLastOrder.id == CMD_RAW_MOVE and prevLastOrder.options.coded == CMD_OPT_INTERNAL then
                                    -- Echo('['..page..']'..'removed third internal '.. 'RAW_MOVE','tag '..prevLastOrder.tag)
                                    spGiveOrderToUnit(CMD_REMOVE,prevLastOrder.tag,0)
                                end
                            end
                        end
                    end
                    prevLastOrder = lastOrder
                    lastOrder = order
                end
                unit.autoguard = false
                queueLength = queueLength or spGetUnitCommands(id,0)
                -- Echo('['..page..']'..'queueLength '..queueLength, queue[queueLength] and queue[queueLength].id)
                -- Echo('['..page..']'..'queueLength',spGetCommandQueue(id,0),spGetUnitCommands(id,0))
                if queueLength == guardPos then
                    removeManual = false
                    place = 0
                    Debug.autoguard('['..page..']'..'dont remove manual, place is now 0 ')
                end
            end
            if removeManual then
                Debug.autoguard('['..page..']'..'unmanual')
                unit.waitManual, unit.waitCmd, unit.waitParams = false, false, false
            end
        end
        if place~=0 then
            return
        end
    end
    -- Echo(count,'place?',place,cmd,unpack(params))
    if inserting then
        -- Echo('replace current in UC')
        unit.replaceCurrent = 1
    end
    -- 
    -- Echo("unit.expectedCmd is ", unit.expectedCmd)
    if unit.waitManual  then
        -- Echo("unit.waitCmd==cmd, table.compare(unit.waitParams,params) is ", unit.waitCmd==cmd, table.compare(unit.waitParams,params))
        if unit.waitCmd == CMD_GUARD and fromLua or unit.waitCmd==cmd and table.compare(unit.waitParams,params) then
            if unit.waitCmd == CMD_FIGHT then
                unit.isFighting = true
                unit.manual = false
            else
                unit.manual = true
                unit.isFighting = false
            end
            

            unit.autoguard = false
            Debug.autoguard('['..page..']'..'unit.waitManual ended')
            unit.waitManual, unit.waitCmd, unit.waitParams = false, false, false
        end
    end
    -- Echo(cmd,"fromLua is ", fromLua)
    if fromLua then
        queue = queue or spGetCommandQueue(id,2)
        if queue[2] and queue[2].id == CMD_FIGHT then
            unit.isFighting = true
        end
        -- Echo('cmd from lua',cmd,unit.isFighting)
        -- unit.actualCmd = unit.expectedCmd
    elseif cmd == CMD_LEVEL and (unit.lastOrderTime and unit.expectedCmd) and unit.expectedCmd<0 and time-(unit.lastOrderTime)<0.1  then
        --
    else
        if cmd~=CMD_FIGHT then
            -- this order is not from engine while fighting
            unit.isFighting = false
        end

        unit.expectedCmd = cmd
        unit.expectedParams = params
        unit.actualCmd = false
        unit.realcmd = false
        unit.realparams = false
    end
    unit.lastOrderTime = time
    if cmd==CMD_RESURRECT then
        if not params[4] then -- case this is an area resurrect, we can't know right now which feature is getting rezzed
            rezedFeatures[params[1]-maxUnits]=true
        end
    end
    -- if areaCmd[cmd] and params[4] and not params[5] then
    --     -- NOTE: for the purpose of notifying an area order that would be directly replaced by a targetted order (or no order at all) we notify this area order, even if it doesn't show in the queue
    --     NotifyExecute(id,cmd,params,options,tag,fromLua)
    --     local queue = Spring.GetCommandQueue(id,-1)
    --     UpdateUnpause[id] = true
    --     return
    -- end
    confirm[id] = fromLua -- it happens that some command, (at least the strider hub  in case of my PBH version (FIX THIS) ordered to build outside of its range) pass through UnitCommand, se we verify at the next Update/GameFrame
end

function widget:UnitDestroyed(id, defID, teamID)
    trackedUnits[id]=nil
end

function widget:UnitGiven(id, defID, to, from)
    if trackedUnits[id] then
        UpdateUnitCommand(trackedUnits[id],id)
    end
end

function widget:UnitTaken(id, defID, from,to)
    trackedUnits[id]=nil
end

function widget:UnitFinished(id,defID,teamID)
    if teamID~=myTeamID or not trackAll then
        return
    end
    SetTrackedUnit(id,true)
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
-------
function WidgetRemoveNotify(w,name,preloading)
    if preloading then
        return
    end
    if name == 'UnitsIDCard' then
        -- widgetHandler:RemoveWidget(widget)
        widgetHandler:Sleep(widget)
    end

    callbacksExec[name] = nil
    callbacksIdle[name] = nil
end    



local ownName = widget:GetInfo().name 
function WidgetInitNotify(w,name,preloading)
    if w == widget then
        return
    end
    if name == 'UnitsIDCard' then
        Units = WG.UnitsIDCard
        widgetHandler:Wake(widget)
    end
    callbacksExec[name] = w.NotifyExecute
    callbacksIdle[name] = w.NotifyIdle
end

-- local DisableOnSpec = f.DisableOnSpec(_,widget,'setupSpecsCallIns') -- initialize the call in switcher
function widget:Initialize()
    if spIsReplay() --[[or string.upper(Game.modShortName or '') ~= 'ZK'--]] then
        widgetHandler:RemoveWidget(self)
        return
    end 
    if Spring.GetSpectatingState() then
        widgetHandler:RemoveWidget(self)
        return
    end
    if not WG.UnitsIDCard and WG.UnitsIDCard.active then
        widgetHandler:RemoveWidget(self)
        return
    end        
    -- if not (WG.Dependancies and WG.Dependancies:Require(widget,'UnitsIDCard',true) )then
    --     widgetHandler:RemoveWidget(self)
    --     -- Spring.SendCommands('luaui disablewidget ' .. widget:GetInfo().name)
    --     return
    -- end
    Debug = f.CreateDebug(Debug,widget,options_path)
    Echo(self:GetInfo().name .. ' is loading ...')

    myTeamID = Spring.GetMyTeamID()
    -- Spring.SendCommands('luaui enablewidget UnitsIDCard')
    widget.SetTrackedUnit = SetTrackedUnit
    WG.commandTrackerActive = true
    WG.TrackedUnits = WG.TrackedUnits or {}
    trackedUnits = WG.TrackedUnits
    -- widget._Update = widget.Update
    -- widget.Update = AfterWidgetsLoaded

    -- WG.Dependancies:Check(widget)
    Units = WG.UnitsIDCard
    -- if WG.UnitsIDCard then
    --     Units = WG.UnitsIDCard
    --     Echo('Command Tracker use UnitsIDCard, active ? ',Units.active)
    -- else
    --     Echo("Command Tracker don't use UnitsIDCard")
    -- end
    local ownName = widget:GetInfo().name
    for i,w in ipairs(widgetHandler.widgets) do
        local name = w.GetInfo and w.GetInfo().name or i
        if name~=ownName then
            if w.NotifyExecute then
                callbacksExec[name] = w.NotifyExecute
            end
            if w.NotifyIdle then
                callbacksIdle[name] = w.NotifyIdle
            end
        end
    end
    if trackAll then
        for _, id in ipairs(Spring.GetTeamUnits(myTeamID)) do
            SetTrackedUnit(id)
        end
    else
        for id in pairs(trackedUnits) do
            if spValidUnitID(id) then
                SetTrackedUnit(id)
            else
                trackedUnits[id].tracked = nil
                trackedUnits[id] = nil
            end
        end
    end
    widget:GamePaused(nil,select(3,Spring.GetGameSpeed()))
    widget:CommandsChanged()

end
function widget:Shutdown()
    -- Echo(widget:GetInfo().name .. ' ||| shutting down...')
    WG.commandTrackerActive = false
    if trackedUnits then
        for id in pairs(trackedUnits) do
            trackedUnits[id].tracked = nil
            -- trackedUnits[id] = nil
        end
    end
    if Debug.Shutdown then
        Debug.Shutdown()
    end
end

do -- debugging
    local fade_blue = {0, 0.7,  0.7, 0.6} 
    local strong_blue = {0, 0.9, 0.9, 0.9}
    local white = {1,1,1,1}
    local purple = {1,0,1,1}
    local ocre = {1,1,0.3,1}
    local tainted_blue = {0.5,1,1,1}
    local custColor = {1,1,0.4,1}
    local max,min = math.max,math.min
    -- Points Debugging
    local ToScreen = Spring.WorldToScreenCoords
    local glText=gl.Text

    local GetTextWidth        = fontHandler.GetTextWidth
    local UseFont             = fontHandler.UseFont
    local TextDraw            = fontHandler.Draw
    local TextDrawCentered    = fontHandler.DrawCentered
    local TextDrawRight       = fontHandler.DrawRight
    local glRect              = gl.Rect
    local font            = "LuaUI/Fonts/FreeSansBold_14"
    local fontWOutline    = "LuaUI/Fonts/FreeSansBoldWOutline_14"     -- White outline for font (special font set)

    function widget:DrawScreen()
        -- if PID and PID==windDefID and pointX then
        --     local minW,incW,maxW,avgW,mult = GetWindAt(pointY)
        --     local str =  (minW and ('%.1f'):format(minW)..' < ' or '')..('%.2f'):format(incW)..(avgW and ' ( avg:'..('%.1f'):format(avgW)..')' or '')
        --     local color = white
        --     local mx,my = ToScreen(pointX,pointY,pointZ-24)
        --     if min then
        --         color = custColor
        --         local malus = 1-minW/mult -- how much left from a maxed min
        --         local bonus = (incW/maxW)*0.4 -- ratio income vs max income, 0.4 beeing the max possible bonus
        --         red = 0.5+malus -- to make strong yellow we need red at 1
        --         green = 1-malus+bonus
        --         color[1] = red
        --         color[2] = green
        --         color[4] = 0.6
        --         -- color[3] = red*0.5 -- need to compensate the reddish colors for visibility
        --         UseFont(font)
        --     else
        --     end
        --     glColor(color)
        --     TextDrawCentered(str, mx, my+40)
        --     -- glText(str, mx-(min and 30 or 5), my+10, 11)    -- not enough visible without outline
        --     glColor(white)


        -- end
        -- -- if true then return end
        -- for i,p in ipairs(Points) do
                 
        --     local mx,my = ToScreen(unpack(p))                   
        --     --glColor(waterColor)
        --     glText(p.txt or i, mx-5, my, 10)                   
        --     --glPointSize(10.0)
        --     --glBeginEnd(GL.POINTS, pointfunc,x,y,z)
        -- end
    end

    local spValidUnitID                 = Spring.ValidUnitID
    local spGetUnitPosition             = Spring.GetUnitPosition
    local glColor                       = gl.Color
    local glText                        = gl.Text
    local glTranslate                   = gl.Translate
    local glBillboard                   = gl.Billboard
    local glPushMatrix                  = gl.PushMatrix
    local glPopMatrix                   = gl.PopMatrix
    local green,              yellow,           red,         white,         blue,           orange ,        turquoise,          paleblue
        = f.COLORS.green, f.COLORS.yellow, f.COLORS.red, f.COLORS.white, f.COLORS.blue, f.COLORS.orange,  f.COLORS.turquoise, f.COLORS.paleblue


    function widget:DrawWorld()
        if not Debug.drawCmd() then
            return
        end
        local debugSel = Debug.selected()
        for id,unit in pairs(debugSel and debugSelected or trackedUnits) do
            if spValidUnitID(id) then
                local color =
                    --[[unit.expectedCmd and (unit.realcmd~=unit.expectedCmd or not table.compare3(unit.expectedParams,unit.realparams)) and white
                    or--]] unit.isFighting and turquoise
                    or unit.manual and orange
                    or unit.autoguard and paleblue
                    or unit.building and (unit.manual or unit.waitManual) and red
                    or unit.waitManual and yellow
                    or unit.isIdle and blue
                    or green
                glColor(color)
                local ix,iy,iz = spGetUnitPosition(id)
                glPushMatrix()
                glTranslate(ix,iy,iz)
                glBillboard()
                if unit.isIdle then
                    glText('Idle' , 0,20,10,'h')
                else
                    local cmd, maincmd, params, mainparams = unit.cmd, unit.maincmd, unit.params,unit.mainparams
                    local l1,l2,l3
                    if maincmd or cmd then
                        l1 = cmdNames[maincmd or cmd]
                    else
                        Echo('error',maincmd or cmd)
                    end
                    if unit.isFighting and unit.manual then
                        l1 = l1 .. ' (M)'
                    end
                    if unit.expectedCmd then
                        l1 = l1 .. ' exp:'..unit.expectedCmd
                    end
                    l2 = '\n['.. (maincmd or cmd) .. ']:' .. table.toline(mainparams or params,nil,nil,0)
                    l3 = cmd~=maincmd and '\n(' .. cmd .. ')' or ''
                    
                    glText(l1 .. l2 .. l3 , 0,20,10,'h')
                end
                glPopMatrix()
            end
        end
        glColor(white)
    end
end
f.DebugWidget(widget)
