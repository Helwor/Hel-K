

function widget:GetInfo()
    return {
        name      = "Terra Unit Handler 2",
        desc      = "auto destroy any abandonned terra unit",
        author    = "Helwor",
        version   = "v1",
        date      = "Jan, 2021",
        license   = "GNU GPL, v2 or later",
        layer     = 0,
        enabled   = true,
        handler   = true,
    }
end

--------------------------------------------------------------------------------
-- Speedups
--------------------------------------------------------------------------------
local f = VFS.Include("LuaUI\\Widgets\\UtilsFunc.lua")

local Page                              = f.Page


local Echo                      = Spring.Echo
local spGetSelectedUnits        = Spring.GetSelectedUnits
local spGetCommandQueue         = Spring.GetCommandQueue
local spGiveOrderToUnit         = Spring.GiveOrderToUnit

local spGetUnitDefID            = Spring.GetUnitDefID

local spGetUnitCurrentCommand   = Spring.GetUnitCurrentCommand


local canRepairDefID = {}
for defID, def in pairs(UnitDefs) do
    if def.canRepair then
        canRepairDefID[defID] = true
    end
end

local Echo = Spring.Echo

local Debug = setmetatable({On=false},{__call=function(self,...) if self.On then Echo(...) end end})

Debug.On = false

local EMPTY_TABLE = {}


local myTeamID = Spring.GetMyTeamID()

local uds = UnitDefs

local CMD_LEVEL,CMD_RAW_BUILD,CMD_REPAIR,CMD_REMOVE,CMD_INSERT,CMD_STOP=39736,31110,40,2,1,0
local CMD_OPT_ALT, CMD_OPT_SHIFT = CMD.OPT_ALT, CMD.OPT_SHIFT


local map = setmetatable({},{__index=function(self,k,v)  self[k]={}  return self[k] end})
local builders=setmetatable({},{__index=function(self,k,v)  self[k]={}  return self[k] end})
local cons = {}
local levelTags = {}
local repairing = {}
local terras = {}
local getLevelTags = false

local currentTerra = false


local function New(terraID)
    Debug('NEW terras',terraID)
    local terra = {id=terraID,builders={},levelTags={},build=false}
    terras[terraID]= terra
    for conID in pairs(cons) do 
        builders[conID] = builders[conID] or {}
        builders[conID][terra]=true
        terra.builders[conID]=true
    end
    return terra
end


local function DetachBuilder(conID,terra,destroy,toReplace)
    Debug('detach',conID,'from',terra.id)
    terra.builders[conID]=nil
    if terra.build then 
        terra.build[conID]=nil
        -- if level was accompanied by a build and no more builders of it remain, we clear also the assisters of leveling 
        if not next(terra.build,nil) then
            for conID in pairs(terra.builders) do
                terra.builders[conID]=nil
            end
        end
    end
    Debug('terra '..terra.id..' has now '..table.size(terra.builders)..' builders')
    -- no more builders (or the building/unit to be built on top has been removed) => delete the terra unit from database, destroy it ingame if the leveling is aborted
    if toReplace then
        local queue = spGetCommandQueue(conID,-1)
        for i,order in ipairs(queue) do
            if order.id == CMD_REPAIR  and not order.params[2] and order.params[1] == terra.id then
                Debug(conID,'replacing order with new terra',toReplace.id)
                spGiveOrderToUnit(conID,CMD_REMOVE,order.tag,0)
                spGiveOrderToUnit(conID,CMD_INSERT,{i-1,CMD_REPAIR,CMD_OPT_SHIFT, toReplace.id}, CMD_OPT_ALT + CMD_OPT_SHIFT)
                -- toReplace.builders[conID]=true
                -- builders[conID][toReplace]=true
                break
            end
        end
    end
    if not next(terra.builders) then 
        if destroy then spGiveOrderToUnit(terra.id, 65, EMPTY_TABLE, 0) Debug('destroy ',terra.id) end
        Debug('delete ',terra.id)
        terras[terra.id]=nil
        local levelTag = terra.levelTags[conID]
        if levelTag then levelTags[levelTag]=nil end
    -- builders remaining, user removed the level order, remove the raw_build order and the repair order going along if the con was on the way on this leveling
    else
        local cmd,_,tag = spGetUnitCurrentCommand(conID)
        if cmd==CMD_RAW_BUILD and repairing[conID]==terra then
            spGiveOrderToUnit(conID,CMD_REMOVE,tag,0)
            spGiveOrderToUnit(conID,CMD_REMOVE,tag-1,0)
            -- spGiveOrderToUnit(conID,CMD_REMOVE,tag-2,0)
        end
        repairing[conID]=nil
    end
    builders[conID][terra]=nil
    -- builder doesn't have any more terra unit attached to it
    if not next(builders[conID],nil) then
        builders[conID]=nil
        repairing[conID]=nil
    end
    -- forget the order tag of leveling belonging to this con for this particular terra unit
    local levelTag = terra.levelTags[conID]
    if levelTag then
        levelTags[levelTag]=nil
    end
end

local function DetachBuilderFromAll(conID,destroy)

    Debug('detach ',conID,' from all')
    for terra in pairs(builders[conID]) do
        DetachBuilder(conID,terra,destroy)
    end
end

function widget:UnitCommand(conID, defID, teamID, cmd, cmdParams, opts, cmdTag, playerID, fromSynced, fromLua)

    if not next(terras,nil) then return end
    local inserting = cmd==CMD_INSERT
    local actualCmd = inserting and cmdParams[2] or cmd
    if actualCmd==CMD_STOP then
        if builders[conID] then DetachBuilderFromAll(conID,true) end
        return
    end

    if actualCmd==CMD_REPAIR then
        local terraID = cmdParams[ 1 + (inserting and 3 or 0) ]
        local terra = terras[terraID]
        if not terra then return end
        -- if a supplementary builder assist initial building
        if not terra.builders[conID] then 
            if not opts.shift and not inserting and builders[conID] then DetachBuilderFromAll(conID,true) end
            terra.builders[conID]=true
            builders[conID][terra]=true
        end
        Debug('terra '..terraID..' has now '..f.l(terra.builders)..' builders')
        --
        repairing[conID]=terras[terraID]
        return
    end

    -- if it's a build we memorize the order tag of current order aka LEVEL, for later to destroy terra if level order is removed by its tag
    if actualCmd==CMD_LEVEL then
        if not currentTerra.tag then 
            local ins = inserting and 3 or 0
            local x,z = cmdParams[1+ins] , cmdParams[3+ins]
            currentTerra.tag = cmdParams[4 + ins]
            local existing = map[x][z]
            if existing then
                Debug('deleting existing terra ' .. existing.id .. ' on same place',x,z)
                for conID in pairs(existing.builders) do
                    DetachBuilder(conID,existing,true,currentTerra)
                end
                map[x][z] = nil
            end
            map[x][z] = currentTerra

            getLevelTags = true
            Debug('mapping',cmdParams[4 + ins], 'to', x,z)
        end
        return
    end

    if actualCmd<0 then
        local ins = inserting and 3 or 0
        local x,z = cmdParams[1+ins] , cmdParams[3+ins]
        -- x is nil means it comes from factory
        if not x then return end
        --
        local terra = map[x][z]
        if terra  then
                local inTerraBuilders = false
                if terra.builders then

                    for id,v in pairs(terra.builders) do
                        if id == conID then
                            inTerraBuilders = true
                            break
                        end
                    end
                end
                if not inTerraBuilders or terra.build and terra.build[conID] then
                    Debug('the build order belong to a terra place, but builder is not building that terra, removing terra ', terra.id)
                    for conID in pairs(terra.builders) do
                        DetachBuilder(conID,terra,true,false)
                    end
                else
                    terra.build = terra.build or {}
                    terra.pos=terra.pos or {x,z}
                    Debug('added con ' .. conID .. ' to terra build',os.clock())
                    terra.build[conID]=true
                end


            -- if builders[conID] then
            --     Debug('deleting existing terra ' .. terra.id .. ', no-levelling build replacing it ',x,z)
            --     for conID in pairs(existing.builders) do
            --         DetachBuilder(conID,terra,true)
            --     end
            -- else
            -- end
        end
        return
    end

    if actualCmd==CMD_REMOVE then
        local tag = cmdParams[4] or cmdParams[1]
        local terra = levelTags[tag]
        if terra then DetachBuilder(conID,terra,true) end
        return
    end
    if not opts.shift and not inserting and opts.right and builders[conID] then
        DetachBuilderFromAll(conID,true)
        return
    end
end

function widget:UnitTaken(id, unitDefID, teamID)
    if teamID~=myTeamID then return end
    if not builders[id] then return end
    DetachBuilderFromAll(id,true)
end

function widget:UnitDestroyed(id, unitDefID, teamID)
    if teamID~=myTeamID then return end
    if builders[id] then
        DetachBuilderFromAll(id,true)
        return
    end
    local terra = terras[id]
    if terra then
        for conID in pairs(terra.builders) do
            DetachBuilder(conID,terra)
        end
    end
end


function widget:UnitCreated(id, defID, teamID,builderID)
    --if uds[unitDefID].name=='terraunit' then Debug('terra created: '..id) end
    if teamID~=myTeamID or uds[defID].name~='terraunit' then return end
    currentTerra = New(id)
    getLevelTags=true
end

function widget:Update()
    if getLevelTags then
        for conID in pairs(cons) do
            -- Echo("conID is ", conID)
            for i,order in ipairs(spGetCommandQueue(conID,-1)) do
                if order.id==CMD_LEVEL and not levelTags[order.tag] then
                    local x,_,z = unpack(order.params)
                    local terra = map[x][z]
                    -- Echo("terra? is ", terra)
                    if not terra then
                        Debug('PROBLEM, cmd Level has not been mapped',x,z)
                    else
                        levelTags[order.tag]=terra
                        -- Echo('order.tag =>', order.tag)
                        terra.levelTags[conID] = order.tag
                    end
                end
            end
        end
        -- for x in pairs(map) do map[x]=nil end
        getLevelTags = false
    end
end



function widget:CommandsChanged()
    cons={}
    for i,id in ipairs(spGetSelectedUnits()) do
        if canRepairDefID[spGetUnitDefID(id)] then
            cons[id]=true
        end
    end
end
function widget:Initialize()
    if Spring.GetSpectatingState() or Spring.IsReplay() then
        Spring.Echo(widget:GetInfo().name..' disabled for spectators')
        widgetHandler:RemoveWidget(self)
        return
    end
    widget:CommandsChanged()
end

f.DebugWidget(widget)
