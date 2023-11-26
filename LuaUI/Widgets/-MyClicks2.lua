


function widget:GetInfo()
    return {
        name      = 'MyClicks',
        desc      = 'callin for click/release of mouse',
        author    = 'Helwor',
        date      = 'Winter, 2021',
        license   = 'GNU GPL, v2 or later',
        layer     = -10e36, 
        enabled   = true,
        handler   = true,
        api       = true,
    }
end
local Echo = Spring.Echo

local debugState = false
options_path = 'Hel-K/' .. widget:GetInfo().name
options_order = {'debug_state'}
options = {}
options.debug_state = {
    name = 'Debug State',
    type = 'bool',
    value = debugState,
    OnChange = function(self)
        debugState = self.value
    end,
}



local f = VFS.Include("LuaUI\\Widgets\\UtilsFunc.lua")
VFS.Include('LuaUI\\Widgets\\Keycodes.lua')
local Page = f.Page
local spGetLastUpdateSeconds = Spring.GetLastUpdateSeconds
local spGetMouseState = Spring.GetMouseState
local spGetActiveCommand = Spring.GetActiveCommand

local mouseLocked, verifMouseState = false, false
local mouse={false,false,false}
local STATE = {}
WG.MyClicks = WG.MyClicks or {callbacks={}}
WG.MouseState = WG.MouseState or {spGetMouseState()}
local MouseState = WG.MouseState
local callbacks = WG.MyClicks.callbacks

local myWidgetName = widget:GetInfo().name
local wh
local mm = ''
local callbackNames = {
    -- 'BeforeUpdate',

    'BeforeMousePress',
    'AfterMousePress',

    'BeforeMouseRelease',
    'AfterMouseRelease',

    'BeforeMouseWheel',
    'AfterMouseWheel',

    'BeforeMouseMove',
    'AfterMouseMove',

    -- 'BeforeDefaultCommand',


    'BeforeKeyPress',
    'AfterKeyPress',

    'BeforeKeyRelease',
    'AfterKeyRelease',
}
local lasttime = os.clock()
local function callback(nameFunc,...)
    -- if os.clock()-lasttime > 3 then
    --     lasttime = os.clock()
    --     Echo('----------')
    -- end
    -- if nameFunc:find('MousePress') then
    --     Echo(nameFunc,'locked:' .. tostring(mouseLocked), 'verifMouseState:' .. tostring(verifMouseState),...)
    -- end
    local callbacks = callbacks[nameFunc]
    if not callbacks then
        return
    end
    for w_name,cb in pairs(callbacks) do
        cb(...)
    end
end





function widget:BeforeUpdate() -- unfortuantely I didnt find a way to get notified by mouse release when MousePress didnt returned true
    -- Echo("widget:BeforeMousePress == wh.MousePress is ", widget.BeforeMousePress == wh.MousePress)
    if verifMouseState then
        verifMouseState = false
        MouseState[1], MouseState[2], MouseState[3], MouseState[4], MouseState[5], MouseState[6] = spGetMouseState()
        for i=1,3 do
            local pressed = MouseState[i+2]
            if pressed then
                verifMouseState = true
            end
            if pressed~=mouse[i] then
                if mouse[i] then
                    mouse[i] = false
                    callback('AfterMouseRelease',MouseState[1],MouseState[2], i,'from Update')
                else
                    mouse[i] = true
                    callback('AfterMousePress',MouseState[1],MouseState[2], i,'from Update')
                end
            end
        end
    end


    return wh:_Update()
    -- if not pressRemains then
    --     wh.Update = wh._Update
    -- end
end

function widget:BeforeDefaultCommand(type,id,engineCmd)
    if verifMouseState then
        verifMouseState = false
        MouseState[1], MouseState[2], MouseState[3], MouseState[4], MouseState[5], MouseState[6] = spGetMouseState()
        for i=1,3 do
            local pressed = MouseState[i+2]
            if pressed then
                verifMouseState = true
            end
            if pressed~=mouse[i] then
                if mouse[i] then
                    mouse[i] = false
                    callback('AfterMouseRelease',MouseState[1],MouseState[2], i,'from DefaultCommand')
                else
                    mouse[i] = true
                    callback('AfterMousePress',MouseState[1],MouseState[2], i,'from DefaultCommand')
                end
            end
        end
    end
    return wh:_DefaultCommand(type,id,engineCmd)
end


local lastclick, lastclick_time = 0, 0
-- local pressed = false
-- function widget:DefaultCommand(type, id, engineCmd)
--     local mx, my, lmb, mmb, rmb = Spring.GetMouseState()
--     if not pressed and rmb then
--         pressed = true
--         Echo('pressed in Default Command', math.round(os.clock()))
--     end
--     if not rmb then
--         pressed = false
--     end
-- end

-- function widget:DefaultCommand()
--     local mx,my, b1, b2, b3, b4, b5 = spGetMouseState()
--     local realstate = {b1, b2, b3, b4, b5}
--     for i=1, 3 do
--         local pressed = mouse[i]
--         local real = realstate[i]
--         if pressed ~= real then
--             if not pressed then

--             end
--         end
--     end
-- end

-- NOTE when dragging an area command with left click this trick will not trigger the mouse release event
local fake = false

function widget:BeforeMousePress(mx,my,button,...)
    -- it happens only when mouse is not locked and some lag happening between click, we then notify a release before notifying a press again
    --NOTE: when an active command is getting operated with left click and then a right click occur, the right click will not be detected
    MouseState[1], MouseState[2], MouseState[button+2] = mx, my, true
    -- Echo('mouse press',button,mx,my, 'mouse?',mouse[button])
    if mouse[button] then
        mouse[button] = false
        -- MouseState[button+2] = false -- not wanna give an incorrect value
        verifMouseState = false
        mouseLocked = false
        Echo('mouse ' .. button .. ' has been found already pressed')
        callback('AfterMouseRelease',mx, my, button,'from MousePress')
    end
    mouse[button] = true

    -- this trick allow us to track every click release and mouse move (except when mixed clicks), 
    -- more speedily and accurately than our current method, but unfortunately it eats the engine mouse reaction
    -- it could work if a replacement of the engine behaviour is made on the widget side (selection box, selection change, right click on default command, area command)
    -- if fake then
    --     fake = false
    --     return true
    -- end
    --

    callback('BeforeMousePress',mx,my,button,'from MousePress')
    local ret =  wh:_MousePress(mx,my,button)
    mouseLocked = ret or mouseLocked -- if the mouse was locked, it means another button has been clicked and locked it and still not has been released
    verifMouseState = not mouseLocked
    -- Echo('mouse press',button,'locked:' .. tostring(mouseLocked),'verif state: ' .. tostring(verifMouseState))
    callback('AfterMousePress',mx,my,button,'from MousePress', mouseLocked, mouseLocked and wh.mouseOwner)

    -- this trick allow us to track every click release and mouse move (except when mixed clicks)
    -- if not ret then
    --     fake = true
    --     return false or Spring.SendCommands('mouse' .. button)
    -- end
    return ret
end
 

function widget:BeforeMouseRelease(mx,my,button) -- this is the MouseRelease called by he engine, triggered only when a mouse button is locked
    mm =''
    mouse[button]=false
    MouseState[button+2] = false

    mouseLocked = false -- the first release in case of mixed press will also unlock the mouse
    local wasOwner = wh.mouseOwner
    for i=1,3 do -- verifMouseState is never needed when mouse is locked, but if mixed press, we need it now
        if mouse[i] then
            verifMouseState = true
            break
        end
    end
    callback('BeforeMouseRelease',mx,my,button,'from MouseRelease',wasOwner)
    local ret = wh:_MouseRelease(mx,my,button) -- the ret normally is -1 in any case ?
    callback('AfterMouseRelease',mx,my,button,'from MouseRelease',wasOwner)
    return ret
end





-- function widget:CommandNotify(cmd)
--     -- Echo('CN cmd',cmd)
-- end
-- function widget:MousePress(mx,my,button)
--     Echo('my mp')
-- end
-- function widget:MouseRelease(mx,my,button)
--     Echo('my mr')
-- end
-- function widget:MouseMove(mx,my,dx,dy,button)
--     Echo('my mouse move',mx, my, dx,dy, button)
-- end
-- when mixed button, the last clicked one is the one given as buttom param
function widget:BeforeMouseMove(mx,my,dx,dy,button)
    -- Echo(mx,my,dx,dy,button)
    mm = mx .. 'x' .. my
    callback('BeforeMouseMove',mx,my,dx,dy,button,'from MouseMove')
    MouseState[1], MouseState[2] = mx, my
    local ret = wh:_MouseMove(mx,my,dx,dy,button) 
    callback('AfterMouseMove',mx,my,dx,dy,button,'from MouseMove', ret)
    return ret
end
function widget:BeforeMouseWheel(up,value)
    -- mouse is already locked, user is currently pressing another button that triggered a widget
    --, therefore only the next button release will be detected, so we complete the job by checking in Update()
    callback('BeforeMouseWheel',up,value,'from MouseWheel')
    local wheelLocked = wh:_MouseWheel(up, value) 
    callback('AfterMouseWheel',up, value,'from MouseWheel', wheelLocked)
    return wheelLocked
end

function widget:BeforeKeyPress(key, mods, isRepeat, label, unicode, scanCode, actions)
    -- Echo("key, mods, isRepeat is ", key, mods, isRepeat)
    callback('BeforeKeyPress',key, mods, isRepeat, label, unicode, scanCode, actions)
    if not isRepeat then
        if STATE[ key ] == 1 then
            Echo("key ", KEYCODES[key],key, 'is found already pressed')
            return
        end
        local cnt = (STATE[ key ] or 0) + 1
        STATE[ key ] = cnt
    end
    -- Echo(symb,STATE[ symb ], ' pressed')
    if KEYCODES[key] == 2 then
        Echo('returned')
        return
    end
    local ret = wh:_KeyPress(key, mods, isRepeat, label, unicode, scanCode, actions)
    callback('AfterKeyPress', key, mods, isRepeat, label, unicode, scanCode, actions)
    return ret
end

function widget:BeforeKeyRelease(...)
    callback('BeforeKeyRelease',...)
    local key = (...)
    local cnt = (STATE[ key ] or 0) - 1
    if cnt <= 0 then
        if cnt < 0 then
            Echo("key ", KEYCODES[key],key, 'was not registered before release !')
        end
        cnt = nil
    end
    STATE[ key ] = cnt
    -- Echo(symb, STATE[ symb ], ' release')
    if KEYCODES[key] == 2 then
        Echo('returned')
        return
    end

    local ret = wh:_KeyRelease(...)
    callback('AfterKeyRelease',...)
    return ret
end


-------- real initialization at the Update call
function widget:Update()
end

local Init = function()
    callbacks = WG.MyClicks.callbacks

    if not wh._MousePress    then wh._MousePress      = wh.MousePress      end
    if not wh._MouseRelease  then wh._MouseRelease    = wh.MouseRelease    end
    if not wh._MouseWheel    then wh._MouseWheel      = wh.MouseWheel    end
    if not wh._MouseMove    then wh._MouseMove      = wh.MouseMove    end

    if not wh._DefaultCommand    then wh._DefaultCommand      = wh.DefaultCommand    end

    if not wh._Update        then wh._Update          = wh.Update          end

    if not wh._KeyPress      then wh._KeyPress        = wh.KeyPress        end
    if not wh._KeyRelease    then wh._KeyRelease      = wh.KeyRelease      end

    wh.MousePress        = widget.BeforeMousePress
    wh.MouseRelease      = widget.BeforeMouseRelease
    wh.MouseWheel        = widget.BeforeMouseWheel
    wh.MouseMove         = widget.BeforeMouseMove

    wh.DefaultCommand    = widget.BeforeDefaultCommand

    wh.Update            = widget.BeforeUpdate
    wh.KeyPress          = widget.BeforeKeyPress
    wh.KeyRelease        = widget.BeforeKeyRelease


end



function WidgetInitNotify(w, name, preloading)
    if name == myWidgetName then
        return
    end
    for _,cbname in pairs(callbackNames) do
        if w[cbname] then
            if not callbacks[cbname] then
                callbacks[cbname] =  {}
            end
            callbacks[cbname][name] = w[cbname]
        end
    end
end
function WidgetRemoveNotify(w, name, preloading)
    if name == myWidgetName then
        return
    end
    for _,cbname in pairs(callbackNames) do
        if w[cbname] then
            if callbacks[cbname] then
                callbacks[cbname][name] = nil
                if not next(callbacks[cbname]) then
                    callbacks[cbname] = nil
                end
            end
            
        end
    end
end

local round = 0
local AfterWidgetsLoaded = function() -- this replace temporarily the widget:Update that we use to run a one time initialization 
    -- round = round +1
    -- if round == 10 then
        Init()
        widget.Update = widget._Update
        widget._Update = nil
        wh:RemoveWidgetCallIn('Update',widget)
    -- end
end


function widget:Initialize()
    wh = widgetHandler
    widget._Update = widget.Update
    widget.Update = AfterWidgetsLoaded
end

local format = string.format
local glText = gl.Text
local glColor = gl.Color
local height = 180
local buttonTXT = {
    'Left Click',
    'Middle Click',
    'Right Click',
}
function widget:DrawScreen()
    -- glColor(0,0.5,1)

    -- Debug verif mouse -- now working perfect, EXCEPT when switching to lobby and coming back

    MouseState[1], MouseState[2], MouseState[3], MouseState[4], MouseState[5], MouseState[6] = spGetMouseState()
    if debugState then
        local str = ''
        for k,v in pairs(STATE) do
            k = KEYCODES[k]
            str = str .. k .. '=' .. v .. ', '
        end
        str = str:sub(1,-3)
        glText(format(str), 60,height, 15)
        local str2, str3 = '', ''
        for k,v in ipairs(MouseState) do
            
            if k<3 then
                k = k == 1 and 'x:' or 'z:'
                str2 = str2 ..k .. '=' .. tostring(v) .. ', '
            elseif k<6 then
                local pressed = v
                if mouse[k-2] ~= v then
                    v = tostring(v)
                    v = v .. ' WRONG'
                    Echo('WE GOT THE MOUSE WRONG !',k-2,v,math.round(os.clock()))
                else 
                    v = tostring(v)
                end     
                k = buttonTXT[k-2]
                str3 = str3 .. (pressed and (k .. '  ') or '         ')
            end
            
        end
        str2 = str2:sub(1,-3)
        str3 = str3:sub(1,-3)
        glText(format(str2), 60,height-18*1, 15)
        glText(format(str3), 60,height-18*2, 15)
        local owner
        if  wh.mouseOwner then
            owner = wh.mouseOwner.GetInfo().name
        end
        if mouseLocked or verifMouseState or owner then
            -- if owner == 'Chili Framework' then
            --     local above = WG.Chili.Screen0:IsAbove(MouseState[1], MouseState[2])
            --     if above then
            --         above = WG.Chili.Screen0.hoveredControl
            --         if above then
            --             owner = owner ..  ' ' ..(above.caption or above.name or above.className or '')
            --         end
            --     end
            -- end
            glText(  
                (math.round(os.clock()) .. '     ' ) .. 'mm' .. mm .. (mouseLocked and 'locked  ' or '               ')
                .. (verifMouseState and 'need verif ' or '                 ')
                .. (owner or '') 
                ,60,height-18*3, 15
            )
            glText(                (WG.drawingPlacement and 'drawingPlacement' or '                 '  )
                .. (WG.EzSelecting and 'EzSelecting' or '                 '  )
                .. (WG.panning and 'panning' or ''  )
                ,60,height-18*4, 15
            )
        end
        -- glColor(1,1,1)
    end

end


---------
function widget:Shutdown()
    if wh._MousePress        then wh.MousePress       = wh._MousePress end
    if wh._MouseRelease      then wh.MouseRelease     = wh._MouseRelease end
    if wh._MouseWheel        then wh.MouseWheel       = wh._MouseWheel end
    if wh._MouseMove         then wh.MouseMove        = wh._MouseMove end
    if wh._DefaultCommand    then wh.DefaultCommand   = wh._DefaultCommand end

    if wh._Update            then wh.Update           = wh._Update end

    if wh._KeyPress          then wh.KeyPress         = wh._KeyPress end
    if wh._KeyRelease        then wh.KeyRelease       = wh._KeyRelease end
    WG.MouseState = nil
end