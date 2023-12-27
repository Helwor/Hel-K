local ver = 0.1
function widget:GetInfo()
    return {
        name      = "Ctrl Move Fix (experimental)",
        desc      = "[NOT WORKING REALLY] Adjust group speed continuously according to their 2D speed (speed change when climbing/ going down hill)",
        author    = "Helwor",
        version   = ver,
        date      = "June 2023",
        license   = "GNU GPL, v2 or later",
        layer     = -100,
        enabled   = true,
        handler   = true,
    }
end

local Echo = Spring.Echo
local spGetSelectedUnitsSorted = Spring.GetSelectedUnitsSorted
local spGetSelectedUnits = Spring.GetSelectedUnits
local spGetUnitPosition = Spring.GetUnitPosition
local spGetUnitVelocity = Spring.GetUnitVelocity
local spGiveOrderToUnitMap = Spring.GiveOrderToUnitMap
local spGiveOrderToUnit = Spring.GiveOrderToUnit
local spValidUnitID = Spring.ValidUnitID
local spGetUnitMoveTypeData = Spring.GetUnitMoveTypeData
-- local Units

local selection, selDefIDS = {n=0}, {}

local currentFrame = Spring.GetGameFrame()

local speedDefID = {}
local CMD_WANTED_SPEED, CMD_RAW_MOVE
do
    local customCmds = VFS.Include("LuaRules/Configs/customcmds.lua")
    CMD_WANTED_SPEED = customCmds.WANTED_SPEED
    CMD_RAW_MOVE =  customCmds.RAW_MOVE
end
local CMD_MOVE = CMD.MOVE
local groupByID, groups, poses, updateNow = {}, {}, {}, {}, {}


local THRESHOLD = 3 -- minimum diff of slowest speed at which we start caring about updating unit speed
local SMOOTH = 0.5 -- maximum speed up change relative to max possible speed between cycle
local SMOOTH_FLOOR = 15 -- minimum smoothing allowed in absolute value

--- FUNCTIONMENT
    -- we set a group leader at first that have the min speed
    -- when a unit is slowed down below the slowest, the whole group must slow down to this lowest
    -- we check periodically if a unit is below the min speed and if it is, we set all the others to that speed
    -- and we set that unit speed to the normal min speed
    -- we mark that unit as the current leader
    -- the whole group will adapt to that leader, leader will change if another unit get slowed down even more
    -- or go back to the normal min speed unit
---


local cfg = {
    active = false,
    updateRate = 19,-- number of frames between update
    drawDebug = true,
    speedDebug = false,
}
options_path = 'Hel-K/' .. widget:GetInfo().name
options_order = {
    'active',
    'updateRate',
    'drawDebug',
    'speedDebug',
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
            widget:CommandsChanged()
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

options.updateRate = {
    name = 'Update Rate',
    type = 'number',
    min = 1, max = 60, step = 1,
    value = cfg.updateRate,
    OnChange = function(self)
        cfg[self.key] = self.value
    end,
}

options.drawDebug = {
    name = 'Draw Debug',
    type = 'bool',
    value = cfg.drawDebug,
    OnChange = function(self)
        cfg[self.key] = self.value
    end,
}
options.speedDebug = {
    name = 'Speed Debug',
    type = 'bool',
    value = cfg.speedDebug,
    OnChange = function(self)
        cfg[self.key] = self.value
    end,
}


local SPEED_TABLE = {-1}

local GetRandomizedColor
do
    local rand,rands = math.random,math.randomseed
    GetRandomizedColor = function(unique,alpha)
        -- create random but fixed color
        rands(unique) -- random seed based 
        local a,b,c=0,0,0
        while (a+b+c)<2 do a,b,c=rand(),rand(),rand() end -- get a color with minimal brightness
        return {a,b,c,alpha}
    end
end

local function copy(t)
    local c = {}
    for k,v in pairs(t) do
        if k~='n' then
            c[k] = v
        end
    end
    return c
end

for defID, def in pairs(UnitDefs) do
    if def.canMove then
        speedDefID[defID] = def.speed
    end
end
-- function WidgetInitNotify(w, name, preloading)
--     if preloading then
--         return
--     end
--     if name == 'UnitsIDCard' then
--         Units = WG.UnitsIDCard
--     end
-- end

-- function WidgetRemoveNotify(w, name, preloading)
--     if preloading then
--         return
--     end
--     if name == 'UnitsIDCard' then
--         Units = nil
--     end
-- end

function widget:Initialize()
    if not options.active.value then
        options.active:OnChange(options.active)
    else
        widget:CommandsChanged()
    end

end

local NewGroup = function()
    return {units = {}, speed = 10000, idealSpeed = 10000, leader = -1, initialized = false,  color = GetRandomizedColor(os.clock(),1)}
end


local function GetLowest2DSpeedOLD(group) -- finally useless
    local speedChangeUnits = {}
    local sp = 10000
    local naturalLowestSpeed = group.idealSpeed
    -- Echo('group low speed = ' .. naturalLowestSpeed)
    for id, unit in pairs(group.units) do
        local baseSpeed = unit.baseSpeed
        local ax, ay,az = unpack(poses[id])
        local bx,by,bz = spGetUnitPosition(id)
        local climb = 0
        local diffY = by-ay
        if diffY > 0 then
            local sqDiffY = diffY^2
            local dist = ((bx - ax)^2 + sqDiffY + (bz - az)^2)
            climb = sqDiffY / dist
        end

        if baseSpeed > naturalLowestSpeed then
            speedChangeUnits[id] = true
        else
            local vx,vy,vz, v = spGetUnitVelocity(id)
            -- local md = Spring.GetUnitMoveTypeData(id)
            -- for k,v in pairs(md) do
            --  Echo(k,v)
            -- end
            local thisspeed = (vx^2 + vz^2) ^ 0.5
            local v = thisspeed * 30
            -- the max walking bot can climb is a 2/3 inclination
            -- at 0.2 inclination, the speed is reduced by ~half
            -- at 0.66, the speed is divided by ~5
            -- the speed reduction augment exponentially
            -- Echo("(1-climb)^ is ", (1-climb)^1.5)
            local climbMult = (1 - climb) / (1.67) -- that's not the formula
            -- Echo("2/3 - climb is ", 2/3 - climb)
            local oClimbMult = (climb / (2/3))
            Echo('climb: ' .. math.round(climb * 100) .. '%',"max climb ratio: ", math.round(oClimbMult * 100) .. '%', math.round(( v / baseSpeed) * 100) .. "%")
            -- Echo("climbMult is ", climbMult)
            local climbSpeed = baseSpeed * climbMult
            -- Echo('id #' .. id,'base speed: ' .. baseSpeed,"v is " .. (v ),'climb :' .. climb,'real speed predict ' .. climbSpeed )
             if v>5 and v < sp then
                sp = v
                -- Echo('... new sp',sp * 30)
            end
        end
    end
    -- Echo('====> ',sp * 30)
    if sp == 10000 then
        -- Echo('use normal low speed', naturalLowestSpeed)
        return naturalLowestSpeed, speedChangeUnits
    end
    if math.round(sp * 1000) == math.round(group.speed * 1000) then
        -- Echo(' no need to do anything')
        return sp
    end
    return sp, speedChangeUnits
end
local f = VFS.Include('LuaUI\\Widgets\\UtilsFunc.lua')
local function GetLowest2DSpeed(group)
    local debugMe = cfg.debugSpeed
    if debugMe then
        Echo('---------------------')
    end
    local speedChangeUnits = {}

    local idealSpeed = group.idealSpeed
    local leader = group.leader -- the leader is the one that is the slowest but having the ideal speed limitation
    -- if the leader happen to have same speed than the last given speed, 
    local naturalLowestSpeed = idealSpeed
    local smoothing = math.max(naturalLowestSpeed * SMOOTH, SMOOTH_FLOOR)
    naturalLowestSpeed = math.min(leader.currentSpeed  + smoothing, naturalLowestSpeed)
    -- local totalMoveSpeedChange = Spring.GetUnitRulesParam(id,'totalMoveSpeedChange')

    local naturalSlowest = leader
    local units = group.units
    local groupSpeed = group.speed
    if not group.initialized then
        -- for id, unit in pairs(units) do
        --     if groupSpeed < unit.baseSpeed then
        --         unit.nerfedSpeed = groupSpeed
        --     end
        -- end
        group.initialized = true
    else
        local smoothing = math.max(naturalLowestSpeed * SMOOTH, SMOOTH_FLOOR)
        naturalLowestSpeed = math.min(leader.currentSpeed  + smoothing, naturalLowestSpeed)
    end

    local speedLowered = false

    -- local dbg = false
    for id, unit in pairs(units) do
        -- if not dbg then
        --     f.Page(spGetUnitMoveTypeData(id), {all = true})
        -- end
        local vx,_,vz, speed3D = spGetUnitVelocity(id)
        local speed2D = 30 * ((vx^2 + vz^2) ^ 0.5)
        -- if id == next(units) then
        --     Echo(id,'speed3D',(speed3D * 30) .. '/' .. unit.baseSpeed)
        -- end
        -- Echo("speed2D, Spring.GetUnitSpeed(id) is ", speed2D)
        if debugMe then
            Echo('# ' .. id .. ' ' .. UnitDefs[Spring.GetUnitDefID(id)].name,'base',unit.baseSpeed,'current:',('%.1f'):format(speed2D),'nerfedSpeed:',unit.nerfedSpeed and ('%.1f'):format(unit.nerfedSpeed) or tostring(unit.nerfedSpeed))
        end
        unit.currentSpeed = speed2D
        unit.currentSpeed3D = speed3D
        local nerfedSpeed = unit.nerfedSpeed
        if not nerfedSpeed or speed2D < (nerfedSpeed - THRESHOLD) then
            -- we count the speed of the unit if it's not nerfed, or if it is even slower than its nerf due to natural cause
            if speed2D < (naturalLowestSpeed - THRESHOLD) then
                naturalLowestSpeed = speed2D
                naturalSlowest = unit
                speedLowered = true
            end
        end
    end
    -- if slowest unit of the last cycle is the same as this one and it's 


    if naturalSlowest ~= leader then
        leader = naturalSlowest
        group.leader = naturalSlowest
        -- Echo('leader changed:',UnitDefs[Spring.GetUnitDefID(leader.id)].name .. ' => ' .. UnitDefs[Spring.GetUnitDefID(naturalSlowest.id)].name)
        -- spGiveOrderToUnit(naturalSlowest.id,CMD_WANTED_SPEED,{idealSpeed},0)
        -- we free the unit from any nerf so it will get back to ideal speed in best case
    end

    if debugMe then
        Echo('naturalSlowest = ' .. (naturalSlowest and UnitDefs[Spring.GetUnitDefID(naturalSlowest.id)].name or 'none'), ('%.1f'):format(naturalLowestSpeed), 'idealSpeed', idealSpeed)
    end
    for id, unit in pairs(units) do
        -- if unit is too fast or have been nerfed too much, we set the it the current slowest speed (not counting the nerfed one)
        if unit.currentSpeed > (naturalLowestSpeed + THRESHOLD) then
            if debugMe then
                Echo('Set because too fast: ' .. '# ' .. id .. ' ' .. UnitDefs[Spring.GetUnitDefID(unit.id)].name ..  ' => ' .. ('%.1f'):format(naturalLowestSpeed))
            end
            unit.nerfedSpeed = naturalLowestSpeed

            speedChangeUnits[id] = true

        elseif unit.nerfedSpeed and unit.nerfedSpeed < (naturalLowestSpeed + THRESHOLD) then
            if debugMe then
                Echo('Set because too slow: ' .. '# ' .. id .. ' ' .. UnitDefs[Spring.GetUnitDefID(unit.id)].name ..  ' => ' .. ('%.1f'):format(naturalLowestSpeed))
            end

            -- unit.nerfedSpeed = unit.baseSpeed > naturalLowestSpeed and naturalLowestSpeed
            unit.nerfedSpeed = naturalLowestSpeed < idealSpeed and naturalLowestSpeed

            speedChangeUnits[id] = true

        -- if id ~= naturalSlowest.id then
        elseif unit.nerfedSpeed and group.idealSpeed == naturalLowestSpeed and math.round(unit.nerfedSpeed) == naturalLowestSpeed then
            unit.nerfedSpeed = nil
        end
    end
    return naturalLowestSpeed, speedChangeUnits
end




local function SetGroupSpeed(group, cnt)
    local sp, speedChangeUnits = GetLowest2DSpeed(group)

    if speedChangeUnits then
        if cfg.debugSpeed then
           Echo('group #' .. cnt .. ', size: ' .. table.size(group) .. ', to be reduced: ' .. table.size(speedChangeUnits) .. ', lowest speed ' .. ' : ' .. sp)
        end
        SPEED_TABLE[1] = sp
        spGiveOrderToUnitMap(speedChangeUnits,CMD_WANTED_SPEED,SPEED_TABLE,0)
        group.speed = sp
        -- updateNow[group] = true
    end
end

local function AddToGroup(id, unit, group)
    -- Echo('add',id)
    groupByID[id] = group
    group.units[id] = unit

    if unit.baseSpeed < group.idealSpeed  then
        group.idealSpeed = unit.baseSpeed
        group.leader = unit

    end
    group.initialized = false
    -- Echo('leader is',group.leader.id)
    group.speed = group.idealSpeed
end
local function RemoveFromGroup(id)
    -- Echo('remove', id)
    local group = groupByID[id]
    local unit = group.units[id]
    group.units[id] = nil
    groupByID[id] = nil
    local remaining = table.size(group.units)
    if remaining == 1 then
        local id = next(group.units)
        spGiveOrderToUnit(id,CMD_WANTED_SPEED,{-1},0)
        groups[group] = nil
    else
        updateNow[group] = true
    end
    return unit
end
local function GetGroup(t)
    local id = next(t)
    local group = groupByID[id]
    if group then
        -- verify if we have this group of units already created
        -- Echo("table.size(group) , table.size(t) is ", table.size(group) , table.size(t) - 1)
        if table.size(group.units) ~= table.size(t)-1 then
            return NewGroup(), false
        end
        for id in pairs(t) do
            if id~='n' then
                local thisgroup = groupByID[id]
                if thisgroup ~= group then
                    return NewGroup(), false
                end
            end
        end
        return group, true
    end
    return NewGroup(), false
end
local function RemoveWholeGroup(group)
    for id in pairs(group.units) do
        groupByID[id] = nil
    end
    groups[group] = nil
end
local orderFrame = -100
function widget:UnitCommandNotify(id, cmd, params, opts)
    if orderFrame ~= currentFrame then
        widget:CommandNotify(cmd, params, opts)     
        orderFrame = currentFrame
    end
end
function widget:CommandNotify(cmd, params, opts)
    local updateLowSpeed = {}
    if (cmd == CMD_RAW_MOVE or cmd == CMD_MOVE) and opts.ctrl and selection.n > 1 then

        local group, processing = GetGroup(selection)
        -- Echo("group, processing is ", group,table.size(group.units), processing,'selection',selection.n)
        if processing then
            return
        end
        groups[group] = true
        for id, baseSpeed in pairs(selection) do
            if id~='n' then
                local unit
                if groupByID[id] then
                    unit = RemoveFromGroup(id)
                end
                if not unit then
                    unit = {id = id, baseSpeed = baseSpeed, currentSpeed = baseSpeed, currentSpeed3D = baseSpeed, nerfedSpeed = nil}
                end
                AddToGroup(id, unit, group)
                poses[id] = {spGetUnitPosition(id)}
            end
        end
        -- SetGroupSpeed(group, 'x')
    else
        local checked
        for id in pairs(selection) do
            if id~='n' then
                if groupByID[id] then
                    if not checked then -- check for identical group to go faster deleting it
                        local group, processing = GetGroup(selection)
                        if processing then
                            RemoveWholeGroup(group)
                            -- the game already remove the speed limitation we have nothing else to do (VERIF bc of order delay)
                            return
                        end
                        checked = true
                    end
                    RemoveFromGroup(id)

                end
            end
        end
        local cnt = 0
        for group in pairs(updateLowSpeed) do
            cnt = cnt + 1
            local min = 10000
            for id, unit in pairs(group.units) do
                if unit.baseSpeed < min then
                    min = unit.baseSpeed
                end
                poses[id] = {spGetUnitPosition(id)}
            end
            group.idealSpeed = min
            -- SetGroupSpeed(group, 'x' .. cnt)
        end
    end
end
function widget:UnitIdle(id)
    if groupByID[id] then
        RemoveFromGroup(id)
    end
end
local function EchoGroups()
    local strGroup = 'There are currently ' .. table.size(groups) .. ' groups'
    if next(groups) then
        strGroup = strGroup .. ': '
        for group in pairs(groups) do
            strGroup = strGroup ..  '[' .. table.size(group.units) .. '] = {'
            for id in pairs(group.units) do
                strGroup = strGroup .. id .. ', '
            end
            strGroup = strGroup:sub(1,-3)
            strGroup = strGroup .. '}, '
        end
        strGroup = strGroup:sub(1,-3)
    end
    Echo( strGroup )
end

function widget:GameFrame(f)
    currentFrame = f
    for group in pairs(updateNow) do
        SetGroupSpeed(group, 'now')
        updateNow[group] = nil
    end
    -- if f%cfg.updateRate == math.round(cfg.updateRate)/2 then
    --     if next(groups) then
    --         local cnt = 0
    --         for group in pairs(groups) do
    --             cnt = cnt + 1
    --             for id in pairs(group.units) do
    --                 poses[id] = {spGetUnitPosition(id)}
    --             end
    --         end
    --     end
    -- end
    if f%cfg.updateRate == 0 then
        if next(groups) then
            
            local cnt = 0
            for group in pairs(groups) do
                cnt = cnt + 1
                SetGroupSpeed(group, cnt)
            end
        end
    end
    -- if f%cfg.updateRate == 0 then
    --     -- EchoGroups()
    -- end
end
function widget:UnitDestroyed(id)
    selection[id] = nil
    if groupByID[id] then
        RemoveFromGroup(id)
    end
end

function widget:CommandsChanged()

    local n = 0
    for k in pairs(selection) do
        selection[k] = nil
    end
    for defID,t in pairs(WG.selectionDefID or spGetSelectedUnitsSorted()) do
        local baseSpeed = speedDefID[defID]
        if baseSpeed then
            for i, id in ipairs(t) do
                n = n + 1
                selection[id] = baseSpeed
            end
        end
    end
    selection.n = n
end

local glDrawGroundCircle = gl.DrawGroundCircle
local glLineWidth = gl.LineWidth
local GL_LINE_BITS = GL.LINE_BITS
local GL_LINES = GL.LINES
local glDepthTest = gl.DepthTest
local glPopAttrib = gl.PopAttrib
local glPushAttrib = gl.PushAttrib
local glLineStipple = gl.LineStipple
local glBeginEnd = gl.BeginEnd
local glVertex = gl.Vertex
local glColor = gl.Color
local glPushMatrix = gl.PushMatrix
local glPopMatrix = gl.PopMatrix
local glTranslate = gl.Translate
local glBillboard = gl.Billboard
local glText = gl.Text
local function LineVerts(x1,y1,z1,x2,y2,z2)
    glVertex(x1,y1,z1)
    glVertex(x2,y2,z2)
end



function widget:DrawWorld()
    if not cfg.drawDebug then
        return
    end


    for group in pairs(groups) do
        local idealSpeed = group.idealSpeed
        local gspeed = math.round(group.speed*10)/10
        glColor(group.color)

        for id, unit in pairs(group.units) do
            if id~='n' then
                if spValidUnitID(id) then
                    --local txt = Units[id].isIdle and 'I' or 'O'
                    -- Echo("id is ", id)

                    -- if id==42 then
                    --     local nearUnits = GetUnitsInCylinder(b.posX,b.posZ,b.buildDistance)
                    --     for i,id in ipairs(nearUnits) do
                    --         local ix,iy,iz = unpack(Units[id].pos)
                    --         glPushMatrix()
                    --         glTranslate(ix,iy,iz)
                    --         glBillboard()
                    --         glColor(1, 1, 1, 0.6)
                    --         glText('near', 0,-10,5,'h')
                    --         glPopMatrix()
                    --         glColor(1, 1, 1, 1)
                    -- end
                    local x,y,z = unpack(poses[id])

                    -- gl.Color(1,1,1,1)
                    -- gl.DrawGroundCircle(x,y,z, b.buildDistance, 90)

                    --     end
                    glPushMatrix()
                    glTranslate(x,y,z)

                    -- using list is ~=2 time faster in this case
                    -- Echo("baseSpeed ~= speed is ", idealSpeed ~= speed,idealSpeed, speed)
                    glBillboard()

                    local txt = ''
                    if id == group.leader.id then
                        txt = txt .. '[L] ' 
                    end
                    txt = txt .. (' [%.0f g:%.1f]'):format(idealSpeed, gspeed)
                    if unit.nerfedSpeed then
                        txt = txt .. (' nerf: %.1f'):format(unit.nerfedSpeed )
                    end
                    local moveData = spGetUnitMoveTypeData(id)
                    local D_maxWantedSpeed = moveData.maxWantedSpeed
                    local D_wantedSpeed = moveData.wantedSpeed
                    txt = txt .. (' W: %.1f / %.1f'):format(D_wantedSpeed or 0, D_maxWantedSpeed or 0 )
            
                

                    local vx, _, vz, speed3D = spGetUnitVelocity(id)
                    if vx then
                        local realSpeed = 30 * (vx^2 + vz^2) ^0.5
                        txt = txt .. (' real: %.1f 3D: %.1f' ):format(realSpeed, speed3D * 30)
                    end
                    glText(txt, 0,0,25,'h')
                    glPopMatrix()
                end
            end
        end
    end
    glColor(1, 1, 1, 1)
    -- time = time + spDiffTimers(spGetTimer(),timer)
    -- if cnt == 1000 then
    --     Echo(cnt .. ' counts of draw value in ' .. time .. ' seconds.')
    --     cnt = 0
    --     time = 0
    -- end

end