function widget:GetInfo()
  return {
    name      = "Phoenix Drop",
    desc      = "Simulates DGUN/Drop behaviour like it would with a Thunderbird \n (WIP working in most case, using D key)",
    author    = "Helwor",
    date      = "May 2024",
    license   = "GNU GPL, v2 or later",
    layer     = -1, -- before Keep Attack
    enabled   = true,  --  loaded by default?
    handler   = true,
  }
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
local spGetMyTeamID = Spring.GetMyTeamID
local spGetUnitHeading = Spring.GetUnitHeading
local spGetUnitWeaponState = Spring.GetUnitWeaponState
local spGetUnitRulesParam = Spring.GetUnitRulesParam
local spGetUnitVelocity = Spring.GetUnitVelocity
local spGetUnitIsStunned = Spring.GetUnitIsStunned
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

options_path = 'Hel-K/' .. widget:GetInfo().name
local f = VFS.Include('LuaUI\\Widgets\\UtilsFunc.lua')

------------- DEBUG CONFIG
local Debug = { -- default values
    active=false -- no debug, no hotkey active without this
    ,global=false -- global is for no key : 'Debug(str)'

}


local phoenixDefID = UnitDefNames['bomberriot'].id

local selectedPhoenixes = false

local DROP_KEY = KEYSYMS.D
-------------


-- CONFIG -- 
local REMOVE_TIMEOUT = 1.2 -- if opt.RemoveOnTimeOut on non shift order, we will not wait to have every units assigned a different target, we will just cancel all of them and start fresh
local PING_LEEWAY = 0.02
local opt = {
    removeAnyAttack = true
}


--


-- shared variables

local got,rec,drawUnit = {},{},{}


local myTeamID = spGetMyTeamID()
local myPlayerID = Spring.GetMyPlayerID()
-- local lastCmd

local function IsReloaded(id)
    local noammo = spGetUnitRulesParam(id,'noammo')
    return noammo == 0 or noammo == nil
end

local function GetClosestDropLocation(id)
    -- Echo("spGetUnitHeading(id), spGetUnitPosition(id) is ", spGetUnitHeading(id), spGetUnitPosition(id))
    local vx, vy, vz, v = spGetUnitVelocity(id)
    local bx ,by ,bz = spGetUnitPosition(id)
    if vx < 5 and vz < 5 then -- in case the unit is temporarily slowed down and stunned
        vx, vz = vx*2, vz * 2
    end 
    local gx, gz = bx + vx * 20, bz + vz * 20
    local gy = spGetGroundHeight(gx, gz)
    return gx, gy, gz
end

local function InsertAttackGround(id, x,y,z)
    spGiveOrderToUnit(id, CMD_INSERT,{0, CMD_ATTACK, 0, x,y,z},CMD_OPT_ALT)
end
local function RemoveAnyAttack(id)
    spGiveOrderToUnit(id, CMD_REMOVE, CMD_ATTACK, CMD_OPT_ALT)
end
Process = function()
    if not selectedPhoenixes then
        return
    end
    for i = 1, #selectedPhoenixes do
        local id = selectedPhoenixes[i]
        if IsReloaded(id) 
            -- and not spGetUnitRulesParam(id,'att_abilityDisabled')==1
        then
            if opt.removeAnyAttack then
                RemoveAnyAttack(id)
            end
            InsertAttackGround(id, GetClosestDropLocation(id))
        end
    end
end

function widget:KeyPress(key,m, isRepeat) -- note: mods always appear in the order alt,ctrl,shift,meta when iterated  -- we can simulate the same by traversing the table {alt=true,ctrl=true,meta=true,shift=true}
    if isRepeat then
        return
    end

    if key == DROP_KEY then
        Process()
    end


end




function widget:CommandsChanged() 
    selectedPhoenixes = (WG.selectionDefID or spGetSelectedUnitsSorted() or EMPTY_TABLE)[phoenixDefID]
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




-- DRAWING --
-- do 
--     local glPushMatrix = gl.PushMatrix
--     local glTranslate = gl.Translate
--     local glBillboard = gl.Billboard
--     local glColor = gl.Color
--     local glText = gl.Text
--     local glPopMatrix = gl.PopMatrix
--     local glDrawGroundCircle = gl.DrawGroundCircle
--     local gluDrawGroundRectangle = gl.Utilities.DrawGroundRectangle
--     local glPointSize = gl.PointSize
--     local glNormal = gl.Normal
--     local glVertex = gl.Vertex
--     local GL_POINTS = GL.POINTS
--     local glBeginEnd = gl.BeginEnd
--     local glLineStipple = gl.LineStipple
--     local glLineWidth = gl.LineWidth
--     function widget:DrawWorld()
--         glLineStipple(true)
--         for id, color in pairs(drawUnit) do
--             glColor(color)
--             if spValidUnitID(id) then   
--                 local x,_,z,_,y = spGetUnitPosition(id,true)
--                 glPushMatrix()
--                 glDrawGroundCircle(x, y, z, 40, 40)
--                 glPopMatrix()
--             end
--         end
--         glLineStipple(false)
--         if rec[1] then
--             gluDrawGroundRectangle(unpack(rec))
--         end
--         local alpha = 1
--         for i=1, #got do
--             local g = got[i]
--             local x,y,z = unpack(g)

--             glColor(g.color)
--             glPointSize(5.0)
--             glBeginEnd(GL_POINTS, function()
--             glNormal(x, y, z)
--             glVertex(x, y, z)
--               end)
--             glPointSize(2.0)
--             --
--             -- if i<3 then
--                 glColor(1, 1, 1, alpha)
--                 glPushMatrix()
--                 glTranslate(x,y,z)
--                 glBillboard()
--                 -- glText(i..': '..g.i..', '..g.j..'|'..'x'..round(g[1])..', z'..round(g[3]),100,i*5,12,'h')
--                 -- glText(i..': x'..round(g[1])..', z'..round(g[3]),100,i*5,12,'h')
--                 glText(i..': x'..round(g[1])..', z'..round(g[3]),0,0,3,'h')
--                 -- glText(id, 0,-20,5,'h')
--                 glPopMatrix()

--                 glColor(1, 1, 1, 1)
--                 alpha = alpha - 0.5
--             -- end
--         end

--         -- for i,c in pairs(circle) do
--         --     local x,y,z,r = unpack(c)
--         --     glPushMatrix()
--         --     glDrawGroundCircle(x,y,z,r, 40)
--         --     glPopMatrix()
--         -- end

--         if not Debug.draw() then return end



--         for i=1,attackers.n do -- show the attackers in the order we made them
--             local attacker = attackers[i]
--             local x,y,z = spGetUnitPosition(attacker.id)
--             if x then
--                 glPushMatrix()
--                 glTranslate(x,y,z)
--                 glBillboard()
--                 glColor(1, 1, 1, 1)
--                 glText(i, 0,0,20,'h')
--                 -- glText(id, 0,-20,5,'h')
--                 glPopMatrix()
--                 glColor(1, 1, 1, 1)
--             end
--         end
--         for x,colx in pairs(targets.map) do -- show the coords of uniques current targets
--             for z, tgt in pairs(colx) do
--                 glPushMatrix()
--                 local y = spGetGroundHeight(x,z)
--                 glTranslate(x,y,z)
--                 glBillboard()
--                 glColor(1, 1, 1, 1)
--                 glText(x..','..z, 0,-6,5,'h')
--                 -- glText(id, 0,-20,5,'h')
--                 glPopMatrix()
--                 glColor(1, 1, 1, 1)
--             end
--         end
--         -- show the targets in order
--         for i=1,targets.n do
--             local target = targets[i]
--             local x,y,z = unpack(target)
--             if x then
--                 glPushMatrix()
--                 glTranslate(x,y,z)
--                 glBillboard()
--                 glColor(1, 1, 1, 1)
--                 glText(i, 0,0,25,'h')
--                 -- glText(id, 0,-20,5,'h')
--                 glPopMatrix()
--                 glColor(1, 1, 1, 1)
--             end
--         end
--         if Debug.draw_tag() then -- show only the tags of attacker.current, which is not mandatorily the current order, but the order we shall cancel
--             for i=1,attackers.n do
--                 local attacker = attackers[i]
--                 if attacker.current then

--                     local x,y,z = unpack(attacker.current)
--                     if x then
--                         glPushMatrix()
--                         glTranslate(x,y,z)
--                         glBillboard()
--                         glColor(0, 1, 0, 1)
--                         glText(attacker.tag, 0,-10,15,'h')
--                         -- glText(id, 0,-20,5,'h')
--                         glPopMatrix()
--                         glColor(1, 1, 1, 1)
--                     end
--                 end
--             end
--         end
--         -- show the average centers of groups, in order
--         for i,group in ipairs(groups) do
--             if group.x then
--                 local x,z = group.x,group.z
--                 local y = spGetGroundHeight(x,z)
--                 glPushMatrix()
--                 glTranslate(x,y,z)
--                 glBillboard()
--                 glColor(1, 1, 0, 1)
--                 glText('G'..i, 0,0,25,'h')
--                 -- glText(id, 0,-20,5,'h')
--                 glPopMatrix()
--                 glColor(1, 1, 1, 1)
--             end
--         end


--     end
-- end






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