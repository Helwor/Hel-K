
function widget:GetInfo()
    return {
        name      = "AutoManeuverOnPatrol",
        desc      = "Set temporary Maneuvering state on hold position units that received a manual patrol/ attack move order",
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
local spugetMovetype            = Spring.Utilities.getMovetype
local spGetUnitDefID            = Spring.GetUnitDefID

EXCEPTION_DEFID = {
    [UnitDefNames['vehsupport'].id] = true,
    [UnitDefNames['amphsupport'].id] = true,
    [UnitDefNames['jumpblackhole'].id] = true,
}
local elligibleDefID = {}
for defID, def in pairs(UnitDefs) do
    if spugetMovetype(def) and not EXCEPTION_DEFID[defID] then
        elligibleDefID[defID] = true
    end
end

local CMD_REMOVE = CMD.REMOVE
local CMD_PATROL = CMD.PATROL
local CMD_FIGHT = CMD.FIGHT
local CMD_MOVE_STATE = CMD.MOVE_STATE

local myTeamID = spGetMyTeamID()

local modifiedState, firstTime = {}, {}
local manual = setmetatable({}, {__mode = 'v'})
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
    desc = "Set temporary Maneuvering state on units that received a manual patrol/attack move order",
    type = 'bool',
    value = active,
    OnChange = function(self)
        active = self.value
        if not active then
            for id, oriState in pairs(modifiedState) do
                spGiveOrderToUnit(id, CMD_MOVE_STATE, oriState, 0)
                modifiedState[id] = nil
                firstTime[id] = nil
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
        if not elligibleDefID[defID] then
            return
        end
        if manual[id] then
            manual[id] = nil
            return
        elseif modifiedState[id] then
            if params[1] ~= 1 then
                firstTime[id], modifiedState[id] = nil, nil
                -- Echo('mod and firstTime niled')
            elseif firstTime[id] then
                -- Echo('firstTime niled')
                firstTime[id] = nil
            else
                -- some move state order has been given through other means, we forget about that unit 
                -- Echo('mod niled')
                modifiedState[id] = nil
            end
        end
    end
end
function widget:UnitIdle(id, defID, team)
    if team ~= myTeamID then
        return
    end
    local oriState = modifiedState[id]
    if oriState then
        if not firstTime[id] then 
            spGiveOrderToUnit(id, CMD_MOVE_STATE, oriState, 0)
            modifiedState[id] = nil
        end
    end
end

function widget:UnitCommandNotify(id, cmd, params, opts)

    if cmd == CMD_MOVE_STATE then -- user is manually setting move state, we forget about this unit
        local defID = spGetUnitDefID(id)
        if not elligibleDefID[defID] then
            return
        end
        modifiedState[id] = nil
        firstTime[id] = nil
        manual[id] = params
    end
    if cmd ~= CMD_PATROL and cmd ~= CMD_FIGHT then
        return
    end
    local defID = spGetUnitDefID(id)
    if not elligibleDefID[defID] then
        return
    end
    if not (manual[id] or firstTime[id]) then
        local moveState = spuGetUnitMoveState(id)
        if moveState == 0 then
            -- Echo('send',os.clock())
            modifiedState[id] = moveState
            firstTime[id] = true
            spGiveOrderToUnit(id, CMD_MOVE_STATE, 1, 0)
        end
    end
end
function widget:CommandNotify(cmd, params)
    if cmd == CMD_MOVE_STATE then -- user is manually setting move state, we forget about those units
        for defID, units in pairs(WG.selectionDefID or spGetSelectedUnitsSorted()) do
            if elligibleDefID[defID] then
                for i, id in ipairs(units) do
                    manual[id] = params
                    modifiedState[id] = nil
                    firstTime[id] = nil
                end
            end
        end
    end
    if cmd ~= CMD_PATROL and cmd ~= CMD_FIGHT then
        return
    end
    for defID, units in pairs(WG.selectionDefID or spGetSelectedUnitsSorted()) do
        if elligibleDefID[defID] then
            for i, id in ipairs(units) do
                if not (manual[id] or firstTime[id]) then
                    local moveState = spuGetUnitMoveState(id)
                    if moveState == 0 or modifiedState[id] then
                        -- Echo('send',os.clock())
                        -- reapply even if the moveState is 1 and has been modified, in case the patrol order arrive after UnitIdle is triggered
                        modifiedState[id] = moveState
                        firstTime[id] = true
                        spGiveOrderToUnit(id, CMD_MOVE_STATE, 1, 0)
                    end
                end
            end
        end
    end
end

local switch = true
function widget:KeyPress(key,mods,isRepeat)
    if isRepeat then
        return
    end
    -- if mods.ctrl then
    --     switch = not switch
    --     Echo('always draw queue set to ' .. tostring(switch))
    --     Spring.LoadCmdColorsConfig("alwaysDrawQueue " .. (switch and '1' or '0'))
    -- end
end


function widget:UnitDestroyed(id, defID, team)
    if team~=myTeamID then
        return
    end
    if modifiedState[id] then
        modifiedState[id] = nil
        firstTime[id] = nil
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
