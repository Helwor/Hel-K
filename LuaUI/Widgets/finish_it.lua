--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--
--  file:    unit_smart_nanos.lua
--  brief:   Enables auto reclaim & repair for idle turrets
--  author:  Owen Martindell
--
--  Copyright (C) 2008.
--  Licensed under the terms of the GNU GPL, v2 or later.
--
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function widget:GetInfo()
  return {
    name      = "FinishIt",
    desc      = "Finish this goddamn build",
    author    = "Helwor",
    date      = "dec 2022",
    license   = "GNU GPL, v2 or later",
    layer     = 0,
    enabled   = false,  --  loaded by default?
    handler   = true,
  }
end
-- speeds up
local Echo = Spring.Echo
local spGetUnitHealth = Spring.GetUnitHealth
local spValidUnitID = Spring.ValidUnitID
local spGiveOrderToUnit = Spring.GiveOrderToUnit
local CMD_INSERT = CMD.INSERT
local CMD_REPAIR = CMD.REPAIR
local CMD_OPT_SHIFT = CMD.OPT_SHIFT
local CMD_OPT_ALT = CMD.OPT_ALT
local INSERT_PARAMS = {0, CMD_REPAIR, CMD_OPT_SHIFT}
local spGetCommandQueue = Spring.GetCommandQueue
local osclock = os.clock()
---------- updating teamID
local myTeamID
local MyNewTeamID = function()
    myTeamID = Spring.GetMyTeamID()
end
widget.TeamChanged = MyNewTeamID
widget.PlayerChanged = MyNewTeamID
widget.Playeradded = MyNewTeamID
widget.PlayerRemoved = MyNewTeamID
widget.TeamDied = MyNewTeamID
----------
local myDrawOrders
local orderByID = {}
local function OrderDraw(str,id,color)
    local order = orderByID[id]
    if order and myDrawOrders[order] then
        order.timeout = os.clock()+5
    else
        order = {str='!',type='font',pos={id},offy=8,timeout=os.clock()+5,blinking = 0.7,color=color}

        table.insert(
            myDrawOrders
            ,order
        )myDrawOrders[order] = true
        orderByID[id] = order
    end
    -- table.insert(DrawUtils.screen[widget]
    --     ,{type='rect',pos={150,200,50,100},timeout=os.clock()+5,blinking = 0.7,color=color}
    -- )

end

-- function widget:Update()
--     Echo('FSAA', Spring.GetConfigInt('FSAA'),'SmoothPoints', Spring.GetConfigInt('SmoothPoints'),'SmoothLines', Spring.GetConfigInt('SmoothLines'),'SetCoreAffinitySim',Spring.GetConfigInt('SetCoreAffinitySim'))
-- end

function widget:UnitCmdDone(id, defID, team, cmd, params,opts,tag)
    if team ~= myTeamID then
        return
    end
    if cmd~=CMD_REPAIR then
        return
    end
    if params[2] then
        return
    end
    if spValidUnitID(params[1]) then
        local bp = select(5,spGetUnitHealth(params[1]))

        if bp<1 and bp >=0.95 then
            local queue = spGetCommandQueue(id,3)
            local isInsert
            for i,order in ipairs(queue) do
                local isInsert =  (order.id == CMD_REPAIR and order.params[1] == params[1])
                if isInsert then
                    return
                end
            end
            -- Echo(id .. ':Finish this build ! ' .. params [1], 'bp:'..bp)
            OrderDraw('!',id,'white')
            OrderDraw('!',params[1],'yellow')
            -- INSERT_PARAMS[4] = params[1]
            -- spGiveOrderToUnit(id, CMD_INSERT,INSERT_PARAMS ,CMD_OPT_ALT)
        end
    end
end
function widget:Initialize()
    if Spring.GetSpectatingState() then
        widgetHandler:RemoveWidget(widget)
        return
    end
    myTeamID = Spring.GetMyTeamID()
    if not WG.DrawUtils then
        OrderDraw = function() end
    else
        DrawUtils = WG.DrawUtils
        DrawUtils.screen[widget] = {}
        myDrawOrders = DrawUtils.screen[widget]
    end
end
function widget:Shutdown()
    if DrawUtils then
        DrawUtils.screen[widget] = nil
    end
end
