function widget:GetInfo()
  return {
    name      = "Move Away From Level Build",
    desc      = "as the title says",
    author    = "Helwor",
    date      = "jan 2023",
    license   = "GNU GPL, v2 or later",
    layer     = -1000000, -- before Draw Placement and Persistent Build Height 2 so they can override this widget orders
    enabled   = true,  --  loaded by default?
    handler   = true,
  }
end
local Echo = Spring.Echo


local f = VFS.Include("LuaUI\\Widgets\\UtilsFunc.lua")


local terraunitDefID = UnitDefNames['terraunit'].id
local trackedUnits

local builderDefID = {}
for defID, def in pairs(UnitDefs) do
    if def.isBuilder and not def.isFactory then
        builderDefID[defID] = def
    end
end


VFS.Include("LuaRules/Configs/customcmds.h.lua")

local GetUnitDefID                = Spring.GetUnitDefID
local GetAllUnits                 = Spring.GetAllUnits
local GetMyTeamID                 = Spring.GetMyTeamID
local GetUnitNearestEnemy         = Spring.GetUnitNearestEnemy
local spGetUnitHealth                      = Spring.GetUnitHealth
local GetUnitsInCylinder          = Spring.GetUnitsInCylinder
local GetUnitPosition             = Spring.GetUnitPosition
local spGetCommandQueue           = Spring.GetCommandQueue
local GetFeatureDefID             = Spring.GetFeatureDefID
local GetFeatureResources         = Spring.GetFeatureResources
local AreTeamsAllied              = Spring.AreTeamsAllied
local spGiveOrderToUnit           = Spring.GiveOrderToUnit
local spGetGroundHeight           = Spring.GetGroundHeight
local spGetUnitHealth             = Spring.GetUnitHealth
local spGetUnitDefID              = Spring.GetUnitDefID
local spGetUnitPosition           = Spring.GetUnitPosition
local max = math.max
local min = math.min
local abs = math.abs
local round = math.round
local round = function(x)return tonumber(round(x)) end
local ceil = math.ceil
local rand = math.random
local nround = f.nround


---

local EMPTY_TABLE       = {}

local TABLE_PARAM         = {}
local CMD_STOP          = CMD.STOP
local CMD_REPAIR        = CMD.REPAIR
local CMD_RECLAIM       = CMD.RECLAIM
local CMD_GUARD         = CMD.GUARD
local CMD_OPT_INTERNAL  = CMD.OPT_INTERNAL
local CMD_OPT_SHIFT     = CMD.OPT_SHIFT
local CMD_OPT_ALT       = CMD.OPT_ALT
local CMD_REMOVE        = CMD.REMOVE
local CMD_INSERT        = CMD.INSERT
local CMD_MOVE          = CMD.MOVE
local UnitDefs = UnitDefs
local SQUARE_SIZE = 8
local Units
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
function table:compare3(t2)
    return self[1]==t2[1] and self[2]==t2[2] and self[3]==t2[3]
end

local CommandTracker
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


local ignoreUnitName = {
    'spidercon',
    'striderfunnelweb',
    'planecon',
    'gunshipcon',
}

----------
-- function widget:UnitCommand(id, defID, teamID, cmd, params, opts, playerID,  tag, fromSynced, fromLua)
--    f.DebugUnitCommand(id, defID, teamID, cmd, params, opts, tag,fromSynced,fromLua)
-- end
function NotifyExecute(unit,id,cmd,params,opts,tag,fromCmdDone,fromLua,realcmd,realparams,realopts,realtag,maincmd,mainparams)
    if unit.building and not ignoreUnitName[unit.name] then
        local nextOrder
        if (cmd == CMD_LEVEL) then
            nextOrder = spGetCommandQueue(id,2)[2]
        elseif cmd == CMD_REPAIR then
            local built_unit =  (not params[4] or params[5]) and Units[params[1]]
            
            if built_unit and built_unit.defID == terraunitDefID then
                local queue = spGetCommandQueue(id,3)
                -- Echo("queue[2] and queue[2].id is ", queue[2] and queue[2].id)
                -- Echo("queue[1] and queue[1].id is ", queue[1] and queue[1].id)
                -- Echo("queue[3] and queue[3].id is ", queue[3] and queue[3].id)
                if queue[2] and queue[2].id ==  CMD_LEVEL then
                    -- Echo('nextOrder',queue[3] and queue[3].id)
                    params = queue[2].params
                    nextOrder = queue[3]
                elseif  queue[3] and queue[3].id == CMD_LEVEL then
                    -- it happen when meta is held and not other command was in queue and the build is on the same place as the con, 
                    -- the order CMD_LEVEL .. BUILD is reversed
                    if queue[2].id < 0 then
                        params = queue[3].params
                        nextOrder = queue[2]
                    end
                end
                -- Echo('got terra unit')
            end
        end
        if nextOrder and nextOrder.id<0 and table.compare3(params,nextOrder.params) then
            local x,y,z = params[1],params[2], params[3]
            local gy = spGetGroundHeight(x,z)
            local height = abs(y-gy)

            local px,py,pz = spGetUnitPosition(id)
            local dirx, dirz = px-x, pz-z
            local def = UnitDefs[-nextOrder.id]
            local selfsize = UnitDefs[spGetUnitDefID(id)].xsize -- all con types are squared (right?)
            local sx,sz = def.xsize,def.zsize
            local offset = math.ceil(height/28) * SQUARE_SIZE-- for 28 height diff the pyramid half size enlarge by 8 on a flat surface, we follow this and assume the terrain would be flat
            local tolerance = 4*SQUARE_SIZE
            local minDeltaX = (sx * SQUARE_SIZE)/2 + (selfsize * SQUARE_SIZE)/2 + (offset) + tolerance
            local minDeltaZ = (sz * SQUARE_SIZE)/2 + (selfsize  * SQUARE_SIZE)/2 + (offset) + tolerance
            local neededX, neededZ = minDeltaX - abs(dirx), minDeltaZ - abs(dirz)
            -- Echo('sx',sx,'H',gy,'future H',y,height,"offset,selfsize * SQUARE_SIZE is ", offset,selfsize * SQUARE_SIZE,neededX,neededZ)
            local moveOrder
            -- as the basic RAW_MOVE order stop when goal is reached under a radius of 16 (2 squares)
            local max = (UnitDefs[spGetUnitDefID(id)].buildDistance or 0) + def.radius
            neededX, neededZ = math.min(neededX, max), math.min(neededZ, max)
            if neededX>tolerance and neededZ>tolerance then
                if neededX<neededZ then
                    moveOrder = true
                    local signX= dirx>0 and 1 or -1
                    px = px + neededX * signX
                    -- Echo('move X',neededX * signX)
                else
                    moveOrder = true
                    local signZ = dirz>0 and 1 or -1
                    pz = pz + neededZ * signZ
                    -- Echo('move Z',neededZ * signZ)
                end

            end
            if moveOrder then
                spGiveOrderToUnit(id,CMD_INSERT,{0,CMD_MOVE,CMD_OPT_SHIFT,px,spGetGroundHeight(px,pz),pz},CMD_OPT_ALT+(--[[shift and CMD_OPT_SHIFT or--]] 0)+CMD_OPT_INTERNAL)
            end
        end
    end
end
function widget:UnitGiven(bID, unitDefID, unitTeam)
    if unitTeam~=myTeamID then return end
    local _, _, _, _, BP = spGetUnitHealth(bID)
    if (BP == 1) then
        widget:UnitFinished(bID, unitDefID, myTeamID)
    end
end

-- register the builder and its buildspeed for time estimation

function widget:UnitFinished(unitID, unitDefID, unitTeam,builderID)
    if unitTeam~=myTeamID then return end
    if builderDefID[unitDefID] then
        CommandTracker.SetTrackedUnit(unitID)
    end
end


function widget:Initialize()

    if Spring.GetSpectatingState() or Spring.IsReplay() then
        Spring.Echo(widget:GetInfo().name..' disabled for spectators')
        widgetHandler:RemoveWidget(self)
        return
    end
    CommandTracker = widgetHandler:FindWidget('Command Tracker')
    if not CommandTracker then
        Echo('Command Tracker is required for ' .. widget:GetInfo().name)
        widgetHandler:RemoveWidget(self)
        return
    end
    -- if not WG.Dependancies:Require(widget,'Command Tracker',true) then
    --     Echo(widget:GetInfo().name .. " don't have command tracker")
    --     widgetHandler:RemoveWidget(self)
    --     -- Spring.SendCommands('luaui disablewidget ' .. widget:GetInfo().name)
    --     return
    -- end
    MyNewTeamID(Spring.GetMyTeamID())

    trackedUnits = WG.TrackedUnits

    CommandTracker.callbacksExec[widget:GetInfo().name] = NotifyExecute
    CommandTracker.callbacksIdle[widget:GetInfo().name] = NotifyIdle
    Units = WG.UnitsIDCard
    for _,id in ipairs(Spring.GetTeamUnits(myTeamID)) do
        local unitDefID = spGetUnitDefID(id)
        widget:UnitGiven(id, unitDefID, myTeamID)
    end

end


f.DebugWidget(widget)





