

local version = '1.0'
function widget:GetInfo()
    return {
        name      = 'Ctrl Move Orbit (experimental)',
        author    = 'Helwor',
        desc      = '[EXPERIMENTAL] Use the orbital guard as move command in formation',
        date      = 'Dec 2023',
        license   = 'GNU GPL, v2 or later',
        layer     = -99,
        enabled   = true,
        handler   = true,
    }
end

local Echo = Spring.Echo

local spGetSelectedUnits = Spring.GetSelectedUnits
-- local spGiveOrder = Spring.GiveOrder
local spGiveOrderToUnit                 = Spring.GiveOrderToUnit
local spGetUnitPosition                 = Spring.GetUnitPosition
local spGetGroundHeight                 = Spring.GetGroundHeight
local spGetUnitCurrentCommand           = Spring.GetUnitCurrentCommand
local Angle = Spring.Utilities.Vector.Angle

local CMD_RAW_MOVE
local CMD_REMOVE = CMD.REMOVE

local CMD_OPT_ALT = CMD.OPT_ALT
local CMD_OPT_SHIFT = CMD.OPT_SHIFT
local CMD_OPT_CTRL = CMD.OPT_CTRL

local CMD_AREA_GUARD
local CMD_ORBIT, CMD_ORBIT_DRAW
do
    local customCmds = VFS.Include("LuaRules/Configs/customcmds.lua")
    CMD_AREA_GUARD = customCmds.AREA_GUARD
    CMD_ORBIT = customCmds.ORBIT
    CMD_ORBIT_DRAW = customCmds.ORBIT_DRAW
    CMD_RAW_MOVE = customCmds.RAW_MOVE
    -- for cmd, num in pairs(customCmds) do
    --     if cmd == 'AREA_GUARD' then
    --         CMD_AREA_GUARD = num
    --     elseif cmd == 'RAW_MOVE' then
    --         CMD_RAW_MOVE = num
    --     elseif
    --     end
    -- end
end
local cfg = {
    active = false,
}
options_path = 'Hel-K/' .. widget:GetInfo().name
options_order = {
    'active',
}
options = {}

options.active = {
    name = 'Active',
    type = 'bool',
    value = cfg.active,
    OnChange = function(self)
        if self.value then
            if widgetHandler.Wake then
                widgetHandler:Wake(widget)
            else
                for name in pairs(widget) do
                    if type(name) == 'string' and widgetHandler[name .. 'List'] then
                        widgetHandler:UpdateWidgetCallIn(name, widget)
                    end
                end
            end
        else
            if widgetHandler.Sleep then
                widgetHandler:Sleep(widget)
            else
                for name in pairs(widget) do
                    if type(name) == 'string' and widgetHandler[name .. 'List'] then
                        widgetHandler:RemoveWidgetCallIn(name, widget)
                    end
                end
            end
        end
    end
}


local function ReadOpts(opts)
    if tonumber(opts) then
        return 'coded: ' .. opts
    end
    local str = ''
    for k,v in pairs(opts) do
        if v then
            str = str .. k .. ': '.. tostring(v) .. ', '
        end
    end
    return str:sub(1,-3)
end
local function ReadParams(params)
    local str = ''
    for _,v in ipairs(params) do
        str = str .. tostring(v) .. ', '
    end
    return str:sub(1,-3)
end

local copy = false
local MIN_ANGLE = 11.000
local PI = math.pi
local MAX_ANGLE = MIN_ANGLE + PI * 2

local OPT_ORBIT = CMD_OPT_ALT
local OPT_ORBIT_DRAW = CMD_OPT_ALT + CMD_OPT_SHIFT

-- for k,v in pairs(math) do
--         Echo(k,v)
-- end

local selection, mySelection, selectionMap = false, false, false
local EMPTY_TABLE = {}


local ORBITS, ORBITING = {}, {}


local function MapSelection(sel)
    local t = {}
    for i, id in ipairs(sel) do
        t[id] = true
    end
    return t
end

function widget:CommandNotify(cmd, params, opts)

    -- Echo('command ' ..cmd, 'params ' ..ReadParams(params),'opts ' .. ReadOpts(opts))
    -- if cmd == CMD_AREA_GUARD then
    --     copy = {cmd, params, opts}
    -- end
    if cmd == CMD_RAW_MOVE and opts.ctrl then
        local sel = selection or spGetSelectedUnits()
        local selMap = selectionMap or MapSelection(sel)
        local count = mySelection.count or #sel
        if count < 2 then
            return
        end

        local refUnit = sel[1]
        local orderToGive = false
        for id in pairs(selMap) do
            local orbited = ORBITING[id]
            local wantedOrbit = ORBITS[refUnit]
            if orbited then
                -- verify in the selection if unit is orbitting to a wrong unit
                if orbited ~= refUnit then
                    orderToGive = true
                    ORBITING[id] = nil
                    local orbit = ORBITS[orbited]
                    if orbit then
                        orbit[id] = nil
                        if not next(orbit) then
                            ORBITS[orbited] = nil
                        end
                    end
                    local cmd, opt, tag, p1,p2, p3,p4 = spGetUnitCurrentCommand(id)
                    if cmd == CMD_ORBIT and p1 == orbited then -- or ask to remove any ORBIT in the queue ? => spGiveOrderToUnit(id, CMD_REMOVE, CMD_ORBIT, CMD_OPT_ALT)
                        spGiveOrderToUnit(id, CMD_REMOVE, tag, 0)
                    end
                else
                    -- the unit orbit to the desired unit, verify if it has the command
                    local cmd, opt, tag, p1,p2, p3,p4 = spGetUnitCurrentCommand(id)
                    if cmd ~= CMD_ORBIT or p1~=refUnit then 
                        -- the unit dont have actual orbit command where it should
                        ORBITING[id] = nil
                        wantedOrbit[id] = nil
                        if not next(wantedOrbit) then
                            ORBITS[refUnit] = nil
                        end
                        -- already registered and really orbitting, but to the wrong unit
                        if cmd == CMD_ORBIT then
                            spGiveOrderToUnit(id, CMD_REMOVE, tag, 0)
                        end
                    end
                end
            else
                orderToGive = true
            end
            -- verify if one unit in our selection is not also an orbit and then remove it with his follower
            if id ~= refUnit then
                local orbit = ORBITS[id]
                if orbit then
                    local orbited = id
                    for id in pairs(orbit) do
                        ORBITING[id] = nil
                        orbit[id] = nil
                        local cmd, opt, tag, p1,p2, p3,p4 = spGetUnitCurrentCommand(id)
                        if cmd == CMD_ORBIT and p1 == orbited then -- or ask to remove any ORBIT in the queue ? => spGiveOrderToUnit(id, CMD_REMOVE, CMD_ORBIT, CMD_OPT_ALT)
                            -- if it follow an unregistered unit, it's likely due to the fact that the user asked himself an orbit command later not passing by our widget
                            -- therefore to reduce error we only cancel if p1 == orbited
                            spGiveOrderToUnit(id, CMD_REMOVE, tag, 0)
                        end
                    end
                    ORBITS[id] = nil
                end
            end


        end
        local orbit = ORBITS[refUnit]
        -- verify if some units exterior to the selection is orbiting from our refUnit and remove order if any
        if orbit then
            for id in pairs(orbit) do
                if not selMap[id] then
                    orbit[id] = nil
                    ORBITING[id] = nil
                    local cmd, opt, tag, p1,p2, p3,p4 = spGetUnitCurrentCommand(id)
                    if cmd == CMD_ORBIT  and p1 == refUnit then -- or ask to remove any ORBIT in the queue ? 
                        spGiveOrderToUnit(id, CMD_REMOVE, tag, 0)
                    end
                end
            end
        else
            orbit = {}
            ORBITS[refUnit] = orbit
        end
        local refX, refY, refZ = spGetUnitPosition(refUnit)
        local midX, midZ = 0, 0, 0
        -- simulate an ORBIT COMMAND for each other unit in selection according to their relative position from the first unit
        if refX then
            midX, midZ = midX + refX, midZ + refZ
            local params_ORBIT = {refUnit,nil,nil,0}
            local params_ORBIT_DRAW = {refUnit,0}
            for i=2, count do
                local id = sel[i]
                local x,y,z = spGetUnitPosition(id)
                if x then
                    midX, midZ = midX + x, midZ + z
                    if orderToGive and ORBITING[id] ~= refUnit then
                        local length = ((x - refX)^2 + (z - refZ)^2)^0.5
                        local angle = Angle(refZ - z, refX - x)
                        local paramAngle = MAX_ANGLE - angle
                        -- Echo("length from " .. id .. ' to ' .. refUnit .. " is " .. length, 'angle: ' .. angle .. ' => ' .. paramAngle)
                        params_ORBIT[2] = length
                        params_ORBIT[3] = paramAngle
                        -- local cmd, opt, tag, p1,p2, p3,p4 = spGetUnitCurrentCommand(id)
                        -- Echo("cmd of follower is ", cmd, 'params', p1,p2, p3,p4)
                        spGiveOrderToUnit(id, CMD_ORBIT, params_ORBIT, OPT_ORBIT)
                        spGiveOrderToUnit(id, CMD_ORBIT_DRAW, refUnit, OPT_ORBIT_DRAW)
                        ORBITING[id] = refUnit
                        orbit[id] = true
                    end

                end
            end
            midX, midZ = midX / count, midZ / count
            local dirX, dirZ = params[1] - midX, params[3] - midZ
            local midOffRefX, midOffRefZ = midX - refX, midZ - refZ
            local refGoalX, refGoalZ = midX + dirX - midOffRefX, midZ + dirZ - midOffRefZ
            local refGoalY = spGetGroundHeight(refGoalX, refGoalZ)

            spGiveOrderToUnit(refUnit, cmd, {refGoalX, refGoalY, refGoalZ}, 0)
            return true
        end

    end

end
function widget:Initialize()
    selection = WG.selection
    mySelection = WG.mySelection or EMPTY_TABLE
    selectionMap = WG.selectionMap
    if not options.active.value then
        options.active:OnChange(options.active)
    end
end
-- function widget:UnitCommand(id, defID, team, cmd, params, opts)
--     if cmd ~= CMD_RAW_MOVE then
--         Echo("UC ", id, 'cmd ' .. cmd, 'params ' .. ReadParams(params),'opts ' ..ReadOpts(opts))
--     end

-- end