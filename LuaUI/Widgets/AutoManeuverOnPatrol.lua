
function widget:GetInfo()
    return {
        name      = "AutoManeuverOnPatrol",
        desc      = "Set temporary Maneuvering state on hold position units that received a manualMove patrol/ attack move order",
        author    = "Helwor",
        date      = "Oct 2023",
        license   = "GNU GPL, v2 or v3",
        layer     = -10, -- Before NoDuplicateOrders
        enabled   = true,
        handler   = true,
    }
end

-- option by default
local active = false
--

local Echo = Spring.Echo


local spGetMyTeamID             = Spring.GetMyTeamID
local spGiveOrderToUnit         = Spring.GiveOrderToUnit
local spGetSelectedUnitsSorted  = Spring.GetSelectedUnitsSorted
local spuGetUnitMoveState       = Spring.Utilities.GetUnitMoveState
local spuGetUnitFireState       = Spring.Utilities.GetUnitFireState
local spugetMovetype            = Spring.Utilities.getMovetype
local spGetUnitDefID            = Spring.GetUnitDefID

EXCEPTION_MOVE_DEFID = {
    [UnitDefNames['vehsupport'].id] = true,
    [UnitDefNames['amphsupport'].id] = true,
    [UnitDefNames['jumpblackhole'].id] = true,
}
local canMoveDefID = {}
for defID, def in pairs(UnitDefs) do
    if spugetMovetype(def) and not EXCEPTION_MOVE_DEFID[defID] then
        canMoveDefID[defID] = true
    end
end
local canFireDefID = {}
for defID, def in pairs(UnitDefs) do
    if def.canAttack then
        canFireDefID[defID] = true
    end
end

local CMD_REMOVE = CMD.REMOVE
local CMD_PATROL = CMD.PATROL
local CMD_FIGHT = CMD.FIGHT
local CMD_MOVE_STATE = CMD.MOVE_STATE
local CMD_FIRE_STATE = CMD.FIRE_STATE
local CMD_MOVESTATE_MANEUVER = CMD.MOVESTATE_MANEUVER
local CMD_FIRESTATE_FIREATWILL = CMD.FIRESTATE_FIREATWILL 


local myTeamID = spGetMyTeamID()

local oriMoveState, firstTimeChangeMove = {}, {}
local oriFireState, firstTimeChangeFire = {}, {}
local manualMove = setmetatable({}, {__mode = 'v'})
local manualFire = setmetatable({}, {__mode = 'v'})
local function Sleep(bool)
    if widgetHandler.Sleep then
        return widgetHandler[bool and 'Sleep' or 'Wake'](widgetHandler,widget, {PlayerChanged = true})
    else
        for k,v in pairs(widget) do
            if type(k)=='string' and type(v)=='function' then
                if k ~= 'PlayerChanged' and widgetHandler[k .. 'List'] then
                    widgetHandler[(bool and 'Remove' or 'Update')..'WidgetCallIn'](widgetHandler,k,widget)
                end
            end
        end
    end
end


options_path = 'Settings/Interface/Commands'
options_order = {'active'}
options = {}
options.active = {
    name = 'Auto Maneuver On Patrol',
    desc = "Set temporary Maneuvering state and fire at will on units on Hold Position/Hold Fire that received a manual patrol/attack move order",
    type = 'bool',
    value = active,
    OnChange = function(self)
        active = self.value
        if not active then
            for id, oriState in pairs(oriMoveState) do
                spGiveOrderToUnit(id, CMD_MOVE_STATE, oriState, 0)
                oriMoveState[id] = nil
                firstTimeChangeMove[id] = nil
            end
            for id, oriState in pairs(oriFireState) do
                spGiveOrderToUnit(id, CMD_FIRE_STATE, oriState, 0)
                oriFireState[id] = nil
                firstTimeChangeFire[id] = nil
            end
        end
        Sleep(not active)
    end
}

function widget:PlayerChanged()
    myTeamID = spGetMyTeamID()
end

function widget:UnitCommand(id, defID, team, cmd, params, _, _, _, _, fromLua)
    if team ~= myTeamID then
        return
    end
    if cmd == CMD_MOVE_STATE and not fromLua then
        if not canMoveDefID[defID] then
            return
        end
        if manualMove[id] then
            manualMove[id] = nil
            return
        elseif oriMoveState[id] then
            if params[1] ~= CMD_MOVESTATE_MANEUVER then
                firstTimeChangeMove[id], oriMoveState[id] = nil, nil
                -- Echo('external order received before our own, mod and firstTimeChangeMove niled')
            elseif firstTimeChangeMove[id] then
                -- Echo('firstTimeChangeMove niled')
                firstTimeChangeMove[id] = nil
            else
                -- some move state order has been given through other means, we forget about that unit 
                -- Echo('mod niled')
                oriMoveState[id] = nil
            end
        end
    elseif cmd == CMD_FIRE_STATE and not fromLua then
        if not canFireDefID[defID] then
            return
        end
        if manualFire[id] then
            manualFire[id] = nil
            return
        elseif oriFireState[id] then
            if params[1] ~= CMD_FIRESTATE_FIREATWILL then
                firstTimeChangeFire[id], oriFireState[id] = nil, nil
                -- Echo('external order received before our own, mod and firstTimeChangeFire niled')
            elseif firstTimeChangeFire[id] then
                -- Echo('firstTimeChangeFire niled')
                firstTimeChangeFire[id] = nil
            else
                -- some fire state order has been given through other means, we forget about that unit 
                -- Echo('mod niled')
                oriFireState[id] = nil
            end
        end
    end
end
function widget:UnitIdle(id, defID, team)
    if team ~= myTeamID then
        return
    end
    local oriState = oriMoveState[id]
    if oriState then
        if not firstTimeChangeMove[id] then 
            spGiveOrderToUnit(id, CMD_MOVE_STATE, oriState, 0)
            oriMoveState[id] = nil
        end
    end
    local oriState = oriFireState[id]
    if oriState then
        if not firstTimeChangeFire[id] then 
            spGiveOrderToUnit(id, CMD_FIRE_STATE, oriState, 0)
            oriFireState[id] = nil
        end
    end

end

function widget:UnitCommandNotify(id, cmd, params, opts)

    if cmd == CMD_MOVE_STATE then -- user is manually setting move state, we forget about this unit
        local defID = spGetUnitDefID(id)
        if not canMoveDefID[defID] then
            return
        end
        oriMoveState[id] = nil
        firstTimeChangeMove[id] = nil
        manualMove[id] = params
    end
    if cmd == CMD_FIRE_STATE then -- user is manually setting move state, we forget about this unit
        local defID = spGetUnitDefID(id)
        if not canFireDefID[defID] then
            return
        end
        oriFireState[id] = nil
        firstTimeChangeFire[id] = nil
        manualFire[id] = params
    end
    if cmd ~= CMD_PATROL and cmd ~= CMD_FIGHT then
        return
    end
    local defID = spGetUnitDefID(id)
    if canMoveDefID[defID] and not (manualMove[id] or firstTimeChangeMove[id]) then
        local moveState = spuGetUnitMoveState(id)
        if moveState == 0 then
            -- Echo('send',os.clock())
            oriMoveState[id] = moveState
            firstTimeChangeMove[id] = true
            spGiveOrderToUnit(id, CMD_MOVE_STATE, CMD_MOVESTATE_MANEUVER, 0)
        end
    end
    if canFireDefID[defID] and not (manualFire[id] or firstTimeChangeFire[id]) then
        local fireState = spuGetUnitFireState(id)
        if fireState == 0 then
            -- Echo('send',os.clock())
            oriFireState[id] = fireState
            firstTimeChangeFire[id] = true
            spGiveOrderToUnit(id, CMD_FIRE_STATE, CMD_FIRESTATE_FIREATWILL, 0)
        end
    end
end
function widget:CommandNotify(cmd, params)
    if cmd == CMD_MOVE_STATE then -- user is manually setting move state, we forget about those units
        for defID, units in pairs(WG.selectionDefID or spGetSelectedUnitsSorted()) do
            if canMoveDefID[defID] then
                for i, id in ipairs(units) do
                    manualMove[id] = params
                    oriMoveState[id] = nil
                    firstTimeChangeMove[id] = nil
                end
            end
        end
        return
   elseif cmd == CMD_FIRE_STATE then -- user is manually setting move state, we forget about those units
        for defID, units in pairs(WG.selectionDefID or spGetSelectedUnitsSorted()) do
            if canFireDefID[defID] then
                for i, id in ipairs(units) do
                    manualFire[id] = params
                    oriFireState[id] = nil
                    firstTimeChangeFire[id] = nil
                end
            end
        end
        return
    elseif cmd == CMD_PATROL or cmd == CMD_FIGHT then
        for defID, units in pairs(WG.selectionDefID or spGetSelectedUnitsSorted()) do
            if canMoveDefID[defID] then
                for i, id in ipairs(units) do
                    if not (manualMove[id] or firstTimeChangeMove[id]) then
                        local moveState = spuGetUnitMoveState(id)
                        if moveState == 0 or oriMoveState[id] then
                            -- Echo('send',os.clock())
                            -- reapply even if the moveState is 1 and has been modified, in case the patrol order arrive after UnitIdle is triggered
                            oriMoveState[id] = moveState
                            firstTimeChangeMove[id] = true
                            spGiveOrderToUnit(id, CMD_MOVE_STATE, CMD_MOVESTATE_MANEUVER, 0)
                        end
                    end
                end
            end
            if canFireDefID[defID] then
                for i, id in ipairs(units) do
                    if not (manualFire[id] or firstTimeChangeFire[id]) then
                        local fireState = spuGetUnitFireState(id)
                        if fireState == 0 or oriFireState[id] then


                            -- Echo('send',os.clock())
                            -- reapply even if the moveState is 1 and has been modified, in case the patrol order arrive after UnitIdle is triggered
                            oriFireState[id] = fireState
                            firstTimeChangeFire[id] = true
                            spGiveOrderToUnit(id, CMD_FIRE_STATE, CMD_FIRESTATE_FIREATWILL, 0)
                        end
                    end
                end
            end
        end
    end
end


function widget:UnitDestroyed(id, defID, team)
    if team~=myTeamID then
        return
    end
    if oriMoveState[id] then
        oriMoveState[id] = nil
        firstTimeChangeMove[id] = nil
    end
    if oriFireState[id] then
        oriFireState[id] = nil
        firstTimeChangeFire[id] = nil
    end
end

function widget:Initialize()
    if Spring.IsReplay() or Spring.GetSpectatingState() then
        widgetHandler:RemoveWidget(widget)
        return
    end
    widget:PlayerChanged()
    if not active then
        Sleep(true)
    end
end
