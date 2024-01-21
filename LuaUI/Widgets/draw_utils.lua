

function widget:GetInfo()
    return {
        name      = "Draw Utils",
        desc      = "Draw Utils",
        author    = "Helwor",
        date      = "dec 2022",
        license   = "GNU GPL, v2",
        layer     = 4000, 
        enabled   = false,  --  loaded by default?
        handler   = true,
        api       = true,
    }
end

local Echo = Spring.Echo
local debugging = false -- need UtilsFunc.lua
local showMeExamples = false -- select a unit and push Ctrl + Alt + E to see all examples, push again Ctrl + Alt + E while it blinks to see the updated order

local f = debugging and VFS.Include('LuaUI\\Widgets\\UtilsFunc.lua')

local Units
local ignoreDefID = {
    [ UnitDefNames['terraunit'].id ] = true
}
for defID, def in pairs(UnitDefs) do
    if def.name:match('drone') then
        ignoreDefID[defID] = true
    end
end


local DrawUtils = {
    screen={}
}
local drawToScreen = DrawUtils.screen


local spGetUnitDefID                = Spring.GetUnitDefID
local spGetAllUnits                 = Spring.GetAllUnits
local spGetMyTeamID                 = Spring.GetMyTeamID
-- local spGetUnitPosition             = Spring.GetUnitPosition
-- local spAreTeamsAllied              = Spring.AreTeamsAllied
local spGetUnitTeam                 = Spring.GetUnitTeam
local spValidUnitID                 = Spring.ValidUnitID
local spGetUnitHealth               = Spring.GetUnitHealth
local spGetSpectatingState          = Spring.GetSpectatingState
local spGetUnitRulesParam           = Spring.GetUnitRulesParam
local spGetUnitHealth               = Spring.GetUnitHealth
local spGetUnitIsDead               = Spring.GetUnitIsDead
-- local spGetUnitTeam                 = Spring.GetUnitTeam
local spIsUnitIcon                  = Spring.IsUnitIcon


local spWorldToScreenCoords         = Spring.WorldToScreenCoords
local spGetUnitViewPosition         = Spring.GetUnitViewPosition
-- local spGetVisibleUnits          = Spring.GetVisibleUnits
-- local spGetSpectatingState       = Spring.GetSpectatingState
local spIsUnitVisible               = Spring.IsUnitVisible
-- local glText=gl.Text

-- local GetTextWidth        = fontHandler.GetTextWidth
-- local TextDraw            = fontHandler.Draw
local TextDrawCentered    = fontHandler.DrawCentered
-- local TextDrawRight       = fontHandler.DrawRight
-- local glRect              = gl.Rect

local glColor = gl.Color

local glPushMatrix = gl.PushMatrix
local glTranslate = gl.Translate
local glScale = gl.Scale
local glBeginEnd = gl.BeginEnd
local GL_LINE_STRIP = GL.LINE_STRIP
local glVertex = gl.Vertex
local glPopMatrix = gl.PopMatrix



local UnitDefs = UnitDefs

local remove = table.remove
local round = math.round

local myTeamID = Spring.GetMyTeamID()

local Units

local colors = {
     white          = {   1,    1,    1,   1 },
     black          = {   0,    0,    0,   1 },
     grey           = { 0.5,  0.5,  0.5,   1 },
     red            = {   1, 0.25, 0.25,   1 },
     darkred        = { 0.8,    0,    0,   1 },
     lightred       = {   1,  0.6,  0.6,   1 },
     magenta        = {   1, 0.25,  0.3,   1 },
     rose           = {   1,  0.6,  0.6,   1 },
     bloodyorange   = {   1, 0.45,    0,   1 },
     orange         = {   1,  0.7,    0,   1 },
     copper         = {   1,  0.6,  0.4,   1 },
     darkgreen      = {   0,  0.6,    0,   1 },
     green          = {   0,    1,    0,   1 },
     lightgreen     = { 0.7,    1,  0.7,   1 },
     blue           = { 0.3, 0.35,    1,   1 },
     fade_blue      = {   0,  0.7,  0.7, 0.6 },
     paleblue       = { 0.6,  0.6,    1,   1 },
     tainted_blue   = { 0.5,    1,    1,   1 },
     turquoise      = { 0.3,  0.7,    1,   1 },
     lightblue      = { 0.7,  0.7,    1,   1 },
     cyan           = { 0.3,    1,    1,   1 },
     lime           = { 0.5,    1,    0,   1 },
     yellow         = {   1,    1,  0.3,   1 },
     ocre           = {   1,    1,  0.3,   1 },
     brown          = { 0.9, 0.75,  0.3,   1 },
     purple         = { 0.9,    0,  0.7,   1 },
     hardviolet     = {   1, 0.25,    1,   1 },
     violet         = {   1,  0.4,    1,   1 },
     paleviolet     = {   1,  0.7,    1,   1 },
     nocolor        = {   0,    0,    0,   0 },
}


---------- updating teamID
local MyNewTeamID = function()
    myTeamID = spGetMyTeamID()
end
widget.TeamChanged = MyNewTeamID
widget.PlayerChanged = MyNewTeamID
widget.Playeradded = MyNewTeamID
widget.PlayerRemoved = MyNewTeamID
widget.TeamDied = MyNewTeamID
----------
local DrawExamples
do
    -- example of usage from another widget
    local ordersInLocal = setmetatable({},{__mode='v'}) -- this to keep references of the orders you sent, if one gets removed by DrawUtils, it will get deleted here too (but on a delay depending on garbage collector) 
    local function UpdateOrder(order_name,newparams)
        WG.DrawUtils.screen[widget] = WG.DrawUtils.screen[widget] or {}
        local myDrawOrders = WG.DrawUtils.screen[widget] -- this to keep an hand on your orders beeing currently processed

        local order = ordersInLocal[order_name]
        if newparams == nil then
            -- delete the order
            if order and myDrawOrders[order] then
                if order_name == 'textOnUnit' then
                    -- Echo(os.clock(),'nil the order')
                end

                myDrawOrders[order] = nil
                --
                ordersInLocal[order_name] = nil
            end
        elseif order and myDrawOrders[order] then
            if order_name == 'textOnUnit' then
                -- Echo(os.clock(),'update the order')
            end
            -- update the params of the existing order
            for k,v in pairs(newparams) do
                order[k] = v
            end
        else
            -- create the order
            order = newparams
            table.insert(myDrawOrders,order)
            -- it is required to add a reference of the order in that array, when and if this get niled, DrawUtils will terminate this order
            if order_name == 'textOnUnit' then
                -- Echo(os.clock(),'order #' .. #myDrawOrders ..  ' created')
            end
            myDrawOrders[order] = true
            --
            ordersInLocal[order_name] = order
        end
    end
    DrawExamples = function()
        WG.DrawUtils.screen[widget] = WG.DrawUtils.screen[widget] or {}
        local myDrawOrders = WG.DrawUtils.screen[widget] -- this to keep an hand on your orders beeing currently processed

        local id = Spring.GetSelectedUnits()[1]
        if id then
            ------ a text attached to unit position
            local order = ordersInLocal.textOnUnit
            if order and myDrawOrders[order] then
                -- Echo(os.clock(),'update text on unit')
                -- changing the existing order's parameter (on second press of hotkey)
                UpdateOrder('textOnUnit', {str = 'o', blinking = 0.2, timeout = os.clock() + 3, color = 'green'})
            else
                -- Echo(os.clock(),'create text on unit')
                -- if there's a timeout, the order will be deleted at timeout
                -- if it is attached to a unit and the unit is not anymore valid, the order will be deleted aswell
                UpdateOrder('textOnUnit', {str = "!", type = 'font', pos = {id}, offy = 5, timeout = os.clock() +5, blinking = 0.7,color = 'white'})
            end
            ----- a rectangle attached to unit position
            local order = ordersInLocal.rectOnUnit
            if order and myDrawOrders[order] then
                -- on second press of hotkey, delete that order
                UpdateOrder('rectOnUnit', nil)
            else
                UpdateOrder('rectOnUnit',{type='rect',pos={id,10,10},timeout=os.clock()+7,blinking = 0.7,color='red'})
            end
            -----
        end
        ------- A rectangle
        local order = ordersInLocal.rect
        if order and myDrawOrders[order] then
            -- on second press of hotkey, delete that order
            UpdateOrder('rect', nil)
        else
            UpdateOrder('rect', {type = 'rect',pos = {300,300,'30%','20%'}, timeout = os.clock()+7, color = 'orange'})
        end
        -------
        ------- a simple text
        local order = ordersInLocal.simpleText
        if order and myDrawOrders[order] then
            -- on second press of hotkey, change text and color then delete it after one sec
            UpdateOrder('simpleText', {str = 'user terminating the order', timeout = os.clock() + 1.5, color = 'cyan'})
        else
            UpdateOrder('simpleText', {
                    str = 'this will vanish in 7 seconds'
                    ,type = 'font'
                    ,font = 'LuaUI/Fonts/FreeSansBold_14'
                    ,pos = {'15%','10%'}
                    ,offx = 300
                    ,offy = 300
                    ,timeout = os.clock()+7
                    ,color = 'yellow'
                }
            )
        end

    end
end
--



local scale,vsy,vsy
local UseFont             = fontHandler.UseFont
local font            = "LuaUI/Fonts/FreeSansBold_14"
local fontWOutline    = "LuaUI/Fonts/FreeSansBoldWOutline_14"     -- White outline for font (special font set)
local monobold        = "LuaUI/Fonts/FreeMonoBold_12"


local function NumOrPercent(n,xOrY)
    if not n then 
        return
    end
    if type(n) == 'string' and n:match('%%') then
        n = tonumber(n:sub(1,-2)) / 100
    end
    n = tonumber(n)
    if n<1 and n>0 then
        n = (xOrY == 'x' and vsx or vsy) * n
    end
    return n
end

local DrawRectOnScreen
do
    local RectVertices = function(x,y,sx,sy)
        glVertex(x      ,      y)
        glVertex(x + sx ,      y)
        glVertex(x + sx , y + sy)
        glVertex(x      , y + sy)
        glVertex(x      ,      y)
    end
    DrawRectangleOnScreen = function(x,y,sx,sy)
        -- this put the y0 back to top
        glPushMatrix()
            glTranslate(0,vsy,0)
            glScale(1,-1,1)
            glScale(scale,scale,1)

            glBeginEnd(GL_LINE_STRIP, RectVertices, x,y,sx,sy)

        glPopMatrix()

    end
end

local TreatDrawScreenOrder = function(order)
    if not next(order) then
        return
    end
    local time = os.clock()
    if order.timeout and time>order.timeout then
        return false
    end
    local blinkTime = order.blinking
    if blinkTime and time%(blinkTime*2)>blinkTime then
        return
    end
    local mx,my,sx,sy = unpack(order.pos)
    if not mx then
        return false
    end
    local unitPos
    if order.world then
        mx,my = spWorldToScreenCoords(mx,my,sx)
    else
        unitPos = not my or sx and not sy
        if unitPos then
            sx,sy = my,sx
            local id = mx
            if spValidUnitID(id) then
                if spIsUnitVisible(id) or spIsUnitIcon(id) then
                    mx,my = spWorldToScreenCoords(spGetUnitViewPosition(id))
                    mx = mx + (order.offx or 0)
                    my = my + (order.offy or 0)
                else
                    return
                end
            else
                return false -- returning false will delete the order
            end
        end
    end
    mx, sx = NumOrPercent(mx,'x'), NumOrPercent(sx,'x')
    my, sy = NumOrPercent(my,'y'), NumOrPercent(sy,'y')
    mx = mx + (order.offx or 0)
    my = my + (order.offy or 0)

    local colorName = order.color
    if colorName then
        if type(colorName) == 'table' then
            glColor(colorName)
        elseif colors[colorName] then
            glColor(colors[colorName])
        end
    end
    if order.type == 'font' then
        if not unitPos and not order.world then
            my = vsy - my
        end
        UseFont(order.font or monobold)
        TextDrawCentered(order.str or '?', mx, my)
    elseif order.type == 'rect' then
        if unitPos then
            mx = mx - sx/2
            my = vsy - my 
            my = my - sy/2
        end
        DrawRectangleOnScreen(mx,my,sx,sy)
    end

end
function WidgetRemoveNotify(w,name)
    if drawToScreen and drawToScreen[widget] then
        drawToScreen[widget] = nil
    end
end
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
function widget:KeyPress(key,mods)
    if showMeExamples and key==101 and mods.alt and mods.ctrl then -- ctrl + alt + E
        DrawExamples()
    end
end

function widget:DrawScreen()
    if not next(drawToScreen) then
        return
    end
    for w,orders in pairs(drawToScreen) do
        local off = 0
        for i=1,#orders do
            local order = orders[i + off]
            if not orders[order] or TreatDrawScreenOrder(order)==false then
                table.remove(orders,i)
                off = off - 1
                orders[order] = nil
            end
        end
    end
    glColor(colors.white)
end

function widget:ViewResize(_vsx, _vsy)
    vsx,vsy = _vsx, _vsy
end

function widget:Initialize()
    Units = WG.UnitsIDCard and WG.UnitsIDCard.active and WG.UnitsIDCard
    if not Units then
        Echo(widget:GetInfo().name .. ' requires UnitsIDCard.')
        widgetHandler:RemoveWidget(widget)
        return
    end
    scale = WG.uiScale
    widget:ViewResize(Spring.GetViewGeometry())
    WG.DrawUtils = DrawUtils

end

function widget:Shutdown()
    WG.DrawUtils = nil
end


if debugging then
    f.DebugWidget(widget)
end
