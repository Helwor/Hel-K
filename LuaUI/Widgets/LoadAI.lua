--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function widget:GetInfo()
  return {
    name      = "Load AI",
    desc      = "when issuing a manual load command, order unit(s) to be loaded, to wait",
    author    = "Helwor",
    date      = "Sept 2023",
    license   = "GNU GPL, v2 or later",
    layer     = -1, -- before cmd_select_load to get informed
    handler   = true,
    enabled   = true,
  }
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
local Echo = Spring.Echo

--------
local dropCloseGround = 50
local adjust = true
local debugging = false
--------

options_path = 'Hel-K/' .. widget:GetInfo().name
options_order = {'dropclose','adjust','debugging'}
options = {}

options.adjust = {
    name = 'Ajust Unload Position',
    type = 'bool',
    value = 'adjust',
    OnChange = function(self)
        adjust = self.value
    end,
}

options.dropclose = {
    name = 'Drop when unloading close to ground',
    type = 'number',
    min = 0, max = 200, step = 2,
    value = dropCloseGround,
    OnChange = function(self)
        dropCloseGround = self.value
    end,
}

options.debugging = {
    name = 'Debugging',
    type = 'bool',
    value = debugging,
    OnChange = function(self)
        debugging = self.value
    end,
}

local customCmds = VFS.Include("LuaRules/Configs/customcmds.lua")


local CMD_MOVE = CMD.MOVE
local CMD_SET_WANTED_MAX_SPEED = CMD.SET_WANTED_MAX_SPEED

local CMD_LOADUNITS_SELECTED = customCmds.LOADUNITS_SELECTED
local CMD_ONECLICK_WEAPON = customCmds.ONECLICK_WEAPON
local CMD_UNLOAD_UNIT = CMD.UNLOAD_UNIT



local transDefID        = {}
local lightTransDefID   = {}
local heavyDefID        = {}
local waitForLoad       = {}
local toDrop = {}

for defID, def in pairs(UnitDefs) do
    if (def.canFly or def.cantBeTransported) then
        if def.isTransport then
            transDefID[defID] = true
            if def.customParams.islighttransport then
                lightTransDefID[defID] = true
            end
        end
    elseif def.customParams.requireheavytrans then
        heavyDefID[defID] = true
    end
end


--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- From transport AI

local EMPTY_TABLE = {}
local MAX_UNITS = Game.maxUnits
local areaTarget -- used to match area command targets

local moveCommand = {
    [CMD.MOVE] = true,
    [customCmds.RAW_MOVE] = true,
    [customCmds.RAW_BUILD] = true,

    [CMD.GUARD] = true,
    [CMD.RECLAIM] = true,
    [CMD.REPAIR] = true,
    -- [CMD.RESURRECT] = true,
    [customCmds.JUMP] = true,
}


--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
local spGetGroundBlocked            = Spring.GetGroundBlocked
local spClosestBuildPos             = Spring.ClosestBuildPos
local spTestBuildOrder              = Spring.TestBuildOrder

local solarDefID                    = UnitDefNames['energysolar'].id
local stardustDefID                 = UnitDefNames['turretriot'].id
local starlightDefID                = UnitDefNames['mahlazer'].id

local spGetUnitDefID                = Spring.GetUnitDefID
local spGetUnitSeparation           = Spring.GetUnitSeparation
local spGetUnitPosition             = Spring.GetUnitPosition
local spGetUnitDefDimensions        = Spring.GetUnitDefDimensions
local spGetUnitCurrentCommand       = Spring.GetUnitCurrentCommand
local spGiveOrderToUnit             = Spring.GiveOrderToUnit
local spGetSelectedUnits            = Spring.GetSelectedUnits
local spClosestBuildPos             = Spring.ClosestBuildPos
local spGetSelectedUnitSorted       = Spring.GetSelectedUnitsSorted
local spGetUnitIsTransporting       = Spring.GetUnitIsTransporting
local spValidUnitID                 = Spring.ValidUnitID
local spGetMyTeamID                 = Spring.GetMyTeamID
local spGetCommandQueue             = Spring.GetCommandQueue
local spGetUnitCurrentCommand       = Spring.GetUnitCurrentCommand
local spGetGroundHeight             = Spring.GetGroundHeight
local spGetUnitVelocity             = Spring.GetUnitVelocity
local spGetGroundBlocked            = Spring.GetGroundBlocked
local spGetUnitRadius               = Spring.GetUnitRadius


local strargs = function(...)
    return table.concat({...},', ')
end


local CONST_TRANSPORT_STOPDISTANCE = 130 -- how close by has transport be to stop the unit
local EMPTY_TABLE = {}

local CMD_OPT_ALT = CMD.OPT_ALT
local CMD_WAIT = CMD.WAIT
local CMD_LOAD_UNITS = CMD.LOAD_UNITS
local CMD_INSERT = CMD.INSERT

local toPick, toGetPicked = {}, {}
local toDrop, toBeDropped = {}, {}
local transDefID        = {}
local lightTransDefID   = {}
local heavyTransDefID   = {}
local heavyDefID        = {}
local waitForLoad       = {}

for defID, def in pairs(UnitDefs) do
    if (def.canFly or def.cantBeTransported) then
        if def.isTransport then
            transDefID[defID] = true
            if def.customParams.islighttransport then
                lightTransDefID[defID] = true
            else
                heavyTransDefID[defID] = true
            end
        end
    elseif def.customParams.requireheavytrans then
        heavyDefID[defID] = true
    end
end

function IsWaitCommand(unitID)
    local cmdID, cmdOpts, tag = spGetUnitCurrentCommand(unitID)
    return cmdID == CMD_WAIT and (cmdOpts % (2*CMD_OPT_ALT) < CMD_OPT_ALT), tag
end

function StopCloseUnits() -- stops units which are close to transport
    for transID, unitID in pairs(toPick) do
        local dist = spGetUnitSeparation(transID, unitID, true)
        if (dist and dist < CONST_TRANSPORT_STOPDISTANCE) then
            local canStop = true
            if not IsWaitCommand(unitID) then
                spGiveOrderToUnit(unitID, CMD_WAIT, EMPTY_TABLE, 0)
            end
            toPick[transID] = nil
            toGetPicked[unitID] = nil
        end
    end
end

local function CheckToDrop()
    if debugging then
        Echo('sizes',table.size(toDrop),table.size(toBeDropped))
    end
    for transID, t in pairs(toDrop) do
        if t.gx then

            local x,y,z = spGetUnitPosition(t.id, true)
            if not x then
                toDrop[transID] = nil
                toBeDropped[toDrop.id] = nil
                return
            end
            local distToGoal = ((t.gx-x)^2 + (t.gz-z)^2)^0.5
            if debugging then
                Echo(
                    transID
                    ,"height", y - math.max(spGetGroundHeight(x,z), 0)
                    -- ,'radius',t.radius
                    ,'goal',distToGoal
                    ,'VEL',strargs(spGetUnitVelocity(transID))
                    ,'Blocked',spGetGroundBlocked(t.gx - t.radius, t.gz - t.radius, t.gx + t.radius, t.gz + t.radius)
                )
            end
            if distToGoal > 48 then
                return
            end
            local ground = spGetGroundHeight(x,z)
            local height = y - math.max(ground, 0)
            -- Echo('height', height,'radius', t.radius, 'waitHigh', t.waitHigh,'=>',t.radius * mult)
            -- Echo('height',height, 'threshold =>',t.radius * dropCloseGround, '('..t.radius..')', 'vel:',spGetUnitVelocity(transID))

            local velx, vely,velz = spGetUnitVelocity(transID)
            if vely > 0.5 or math.abs(velx) > 1 and math.abs(velz) > 1  then
                return
            end
            local radius = t.radius
            if ground <= 0
            or height <= dropCloseGround
            or height <= (dropCloseGround*1.5)
                and spGetGroundBlocked(t.gx - radius, t.gz - radius, t.gx + radius, t.gz + radius)
            then
                -- Echo(transID,'DROP',spGetGroundBlocked(t.gx - radius, t.gz - radius, t.gx + radius, t.gz + radius))
                -- Echo(transID,'DROP')s
                -- spGiveOrderToUnit(transID, CMD.STOP,0,CMD.OPT_SHIFT)
                -- spGiveOrderToUnit(transID, CMD_ONECLICK_WEAPON, 1, 0)
                -- spGiveOrderToUnit(transID, CMD_ONECLICK_WEAPON, 1, 0)
                spGiveOrderToUnit(transID,CMD_INSERT,{0,CMD_ONECLICK_WEAPON,0,1}, CMD_OPT_ALT)
                toBeDropped[t.id] = nil
                toDrop[transID] = nil
            end
        end
    end
end


function widget:GameFrame(f)
    if f%10 == 0 then
        CheckToDrop()
    elseif f%15 == 0 then
        StopCloseUnits()
    end
    -- Echo("waitForCmd ", table.size(waitForCmd),'toDrop',table.size(toDrop))


end

local function CheckToWait(unitID,p1, p2, p3)
    if p1 and not p2 then
        local transported = spGetUnitIsTransporting(unitID)
        if transported and not transported[1] then
            toPick[unitID] = p1
            toGetPicked[p1] = unitID
            StopCloseUnits()
        end
    end
end

local function NewDropTable(transID, unitID)
    local dropTable = {id=unitID,transID=transID, radius = spGetUnitRadius(unitID), waitHigh = true}
    toDrop[transID] = dropTable
    toBeDropped[unitID] = dropTable
    local order = spGetCommandQueue(transID,1)[1]
    local cmd,_,_,p1,p2,p3 = spGetUnitCurrentCommand(transID)
    if cmd == CMD_UNLOAD_UNIT then
        dropTable.gx, dropTable.gy, dropTable.gz = p1, p2, p3
    end
end

function widget:UnitCommand(unitID, defID, team, cmd, params, opts)
    if team ~= myTeamID then
        return
    end
    --- update dropTable
    if cmd == CMD_INSERT then
        if params[2] == CMD_UNLOAD_UNIT and toDrop[unitID] then
            -- Echo('ok', params[1], spGetUnitCurrentCommand(unitID))
            if params[1] == 0 or not spGetUnitCurrentCommand(unitID) then
                local dropTable = toDrop[unitID]
                dropTable.gx, dropTable.gy, dropTable.gz = params[4], params[5], params[6]
            end
        end
    elseif cmd == CMD_UNLOAD_UNIT and not opts.shift then
        local dropTable = toDrop[unitID]
        if dropTable then
            dropTable.gx, dropTable.gy, dropTable.gz = unpack(params)
        end
    elseif not opts.shift then
        local dropTable = toDrop[unitID]
        if dropTable then
            dropTable.gx = false       
        end
    end

end

function widget:UnitCmdDone(unitID, defID, teamID, cmdDone, paramsDone)
    if teamID ~= myTeamID then
        return
    end
    if transDefID[defID] then
        local cmd,_,_,p1,p2,p3 = spGetUnitCurrentCommand(unitID)
        if cmd == cmdDone and paramsDone[1] == p1 and paramsDone[2] == p2 and paramsDone[3] == p3 then
            -- NOTE/BUG: when an order is inserted  at first place,
            -- the real current command cannot be retrieved at this moment (either by spGetUnitCurrentCommand or by spGetCommandQueue)
            -- so we ignore this when that happen
            return
        end
        local dropTable = toDrop[unitID]
        if not cmd then
            if dropTable then
                dropTable.gx = false
            end
        end
        if cmd == CMD_LOAD_UNITS then
            CheckToWait(unitID,p1, p2, p3)
        elseif cmd == CMD_UNLOAD_UNIT then
            if dropTable then
                dropTable.gx, dropTable.gy, dropTable.gz = p1, p2, p3
            end
        else
            if dropTable then
                dropTable.gx = false
            end
        end
    end
end
local function AdjustForBlockedGround(location,defID)
    local x, y, z = location[1], location[2], location[3]
    
    -- local function CheckBlocked(layer, offx, offz)
    -- local blocking = Spring.TestBuildOrder(solarDefID, x, y, z, 1)
    -- local radius = spGetUnitRadius(unitID)
    -- Echo("spGetGroundBlocked(x - 100, z - 100, x + 100, z + 100)  is ", spGetGroundBlocked(x - radius, z - radius, x + radius, z + radius) )
    -- local testMove = Spring.TestMoveOrder()
    -- local gblock = spGetGroundBlocked(x - 100, z - 100, x + 100, z + 100)
    
    -- if gblock == 'feature' then

    -- end
    -- Echo("gblock is ", gblock)
    -- if gblock then
    --  x, y, z = spClosestBuildPos(0,solarDefID, x, 0, z, 200 ,0 ,0)
    --  if x then
    --      location[1], location[2], location[3] = x, y, z
    --      -- Echo('=>',x,y,z)
    --  end
    -- end
    -- if not gblock then
        local ax, ay, az = spClosestBuildPos(0,defID, x, 0, z, 200 ,0 ,0)
        if ax and ax~=x or az~=z then
            return ax, ay, az
            -- Echo('=>',x,y,z)
        end
    -- end
    -- end
end
local CodeOptions
do
    local code={meta=4,internal=8,right=16,shift=32,ctrl=64,alt=128}
    CodeOptions = function(options)
        local coded = 0
        for opt, isTrue in pairs(options) do
            if isTrue then coded=coded+code[opt] end
        end
        options.coded=coded
        return options
    end
end

function widget:CommandNotify(cmd, params, opts)
    if not transportSelected then
        return
    end
    if opts.shift then
        return
    end
    if cmd == CMD_LOAD_UNITS  then
        if params[1] and not params[2] then
            local unitID = params[1]
            if not spValidUnitID(unitID) then
                return
            end
            local isHeavy = heavyDefID[spGetUnitDefID(unitID)]
            for defID, units in pairs(transportSelected) do
                if heavyTransDefID[defID] or lightTransDefID[defID] and not isHeavy then
                    for i, transID in ipairs(units) do
                        local transported = spGetUnitIsTransporting(transID)
                        if transported and not transported[1] then
                            toPick[transID] = unitID
                            toGetPicked[unitID] = transID
                            StopCloseUnits()
                            return
                        end
                    end
                end
            end
        end
    else

        if next(toPick) then
            for defID, units in pairs(transportSelected) do
                if transDefID[defID] then
                    for i, transID in ipairs(units) do
                        local unitToPick = toPick[transID]
                        if unitToPick then
                            toPick[transID] = nil
                            toGetPicked[unitToPick] = nil
                        end
                    end
                end
            end
        end

        -- adjust unload location
        if cmd == CMD_UNLOAD_UNIT and adjust then
            local known = {}
            for defID, units in pairs(transportSelected) do
                for i, transID in ipairs(units) do
                    local transported = spGetUnitIsTransporting(transID)
                    transported = transported and transported[1]
                    if transported then
                        local defID = spGetUnitDefID(transported)
                        local modParams = params
                        if not known[defID] then
                            local x,y,z = AdjustForBlockedGround(params, defID)
                            modParams = x and {x,y,z} or params
                            known[defID] = modParams
                        end                        
                        spGiveOrderToUnit(transID, CMD_UNLOAD_UNIT, modParams, opts.coded or CodeOptions(opts).coded)
                    end
                end
            end
            return true
        end
    end
end

function widget:CommandsChanged()
    local seltypes = spGetSelectedUnitSorted()
    for defID, units in pairs(seltypes) do
        if transDefID[defID] then
            transportSelected = seltypes
            return
        end
    end
    transportSelected = false
end
function widget:UnitCommandNotify(unitID, cmd, params, opts)
    if cmd == CMD_LOAD_UNITS and params[1] and not params[2] and not opts.shift then
        toPick[unitID] = params[1]
        toGetPicked[params[1]] = unitID
        StopCloseUnits()
        return
    end
    if cmd == CMD_UNLOAD_UNIT and adjust then
        local transported = spGetUnitIsTransporting(unitID)
        transported = transported and transported[1]
        if transported then
            local defID = spGetUnitDefID(transported)
            local x,y,z = AdjustForBlockedGround(params, defID)
            local modParams = x and {x,y,z} or params
            spGiveOrderToUnit(unitID, CMD_UNLOAD_UNIT, modParams, opts.coded or CodeOptions(opts).coded)
            return true
        end
    end
end
function widget:UnitDestroyed(unitID, defID, teamID)
    if teamID ~= myTeamID then
        return
    end

    local unitToPick = toPick[unitID]
    if unitToPick then
        toPick[unitID] = nil
        toGetPicked[unitToPick] = nil
        if spValidUnitID(unitToPick) then
            local waiting, orderTag = IsWaitCommand(unitToPick)
            if waiting then
                spGiveOrderToUnit(unitID, CMD_REMOVE, orderTag, 0)
            end
        end
    end
    ---------------
    local dropTable = toBeDropped[unitID] or toDrop[unitID]
    if dropTable then
        toBeDropped[dropTable.id] = nil
        toDrop[dropTable.transID] = nil
    end
end
widget.UnitReverseBuild = widget.UnitDestroyed

function widget:PlayerChanged()
    myTeamID = spGetMyTeamID()
end
function widget:Initialize()
    if Spring.GetSpectatingState() or Spring.IsReplay() then
        widgetHandler:RemoveWidget(widget)
        return
    end    
    widget:PlayerChanged()
    local indexedTransDef = {}
    for defID in pairs(transDefID) do
        table.insert(indexedTransDef, defID)
    end
    for i, transID in ipairs(Spring.GetTeamUnitsByDefs(myTeamID,indexedTransDef)) do
        local transported = spGetUnitIsTransporting(transID)
        transported = transported and transported[1]
        if transported then
            widget:UnitLoaded(transported, spGetUnitDefID(transported), Spring.GetUnitTeam(transported), transID, myTeamID)
        end
    end
    widget:CommandsChanged()
end

---- Auto drop feature
-------------- Drop close ground feature


function widget:UnitLoaded(unitID, unitDefID, unitTeam, transID, transportTeam)
    if transportTeam ~= myTeamID then
        return
    end
    NewDropTable(transID, unitID)

end

function widget:UnitUnloaded(unitID, unitDefID, unitTeam, transID, transportTeam)
    if transportTeam ~= myTeamID then
        return
    end
    local dropTable = toDrop[transID]
    if dropTable then
        toBeDropped[dropTable.id] = nil
        toDrop[transID] = nil
    end
end







