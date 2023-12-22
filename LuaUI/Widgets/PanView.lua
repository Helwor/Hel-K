function widget:GetInfo()
    return {
        name      = "Pan View",
        desc      = "Pan view by holding space and left click down and dragging mouse",
        author    = "Helwor",
        version   = "v1",
        date      = "mid 2021",
        license   = "GNU GPL, v2 or later",
        -- layer     = 10000,
        layer     = -100,
        -- layer     = -10000.5,
        -- layer     = 10000,
        enabled   = true,
        handler   = true,
    }
end

local Echo = Spring.Echo
local f = VFS.Include("LuaUI\\Widgets\\UtilsFunc.lua")
local wh
include('keysym.h.lua')
local KEYSYMS = KEYSYMS
-- speedups
local spGetModKeyState          = Spring.GetModKeyState
local spGetKeyState             = spGetKeyState

local spGetCameraState          = Spring.GetCameraState
local spSetCameraState          = Spring.SetCameraState
local spGetCameraPosition       = Spring.GetCameraPosition
local spGetGroundHeight         = Spring.GetGroundHeight
local spSetCameraTarget         = Spring.SetCameraTarget
local spTraceScreenRay          = Spring.TraceScreenRay
local spGetCameraVectors        = Spring.GetCameraVectors
local spSendCommands            = Spring.SendCommands
local spGetActiveCommand        = Spring.GetActiveCommand
local spSetActiveCommand        = Spring.SetActiveCommand
local spWorldToScreenCoords     = Spring.WorldToScreenCoords
local spGetLastUpdateSeconds    = Spring.GetLastUpdateSeconds
local spGetGameSeconds          = Spring.GetGameSeconds
local spGetMouseState           = Spring.GetMouseState
local spSetMouseCursor          = Spring.SetMouseCursor
local spWarpMouse               = Spring.WarpMouse

local spGetUnitDefID            = Spring.GetUnitDefID
local spSelectUnitArray         = Spring.SelectUnitArray
local spGetSelectedUnits        = Spring.GetSelectedUnits
local glPushMatrix              = gl.PushMatrix
local glColor                   = gl.Color 
local glLineStipple             = gl.LineStipple
local glLineWidth               = gl.LineWidth
local glDrawGroundCircle        = gl.DrawGroundCircle
local glPopMatrix               = gl.PopMatrix

local min,max,round,sqrt,abs, atan2, pi = math.min,math.max,math.round,math.sqrt,math.abs,math.atan2, math.pi

local CMD_FIGHT = CMD.FIGHT


local page = 0

local WG = WG
local Cam = WG.Cam
local usedAcom

-- debug v in a window
local debugMe = false
DebugUp = function() end
--

local function FormatTime(n)
    local h = math.floor(n/3600)
    h = h>0 and h
    local m = math.floor( (n%3600) / 60 )
    m = (h or m>0) and m
    local s = ('%.4f'):format(n%60)
    return (h and h .. ':' or '') .. (m and m .. ':' or '') .. s
end

-- f.Page(Spring,'icon')

local mapSizeX,mapSizeZ = Game.mapSizeX,Game.mapSizeZ
local cs = Spring.GetCameraState()

--
-- NOTE: the real height will change the size of world on screen depending on the FOV
local cfg = {
    MAX_TOP_ALTITUDE = max(mapSizeX, mapSizeZ) * 5/3
    ,MAX_MIN_ZOOM_BACK_RATIO = 0.95
    ,maxTACam = max(mapSizeX, mapSizeZ) * 5/3 -- this give the max possible altitude for TA cam -- unfortunately very low FOV will not allow to see all the map with TA cam
-- INGAME CONFIG

--
-- CONFIG
    ,zoom_choice = 'auto_zoom_out'
    ,altitude_ratio = 0.8 -- this is the current height ratio of TA Cam  maxHeight

    ,wait_before_panning = false -- false or some value in second
    ,smoothness = 0.13
    ,smoothness_zoom = 0.13
    ,smoothness_zoom_back = 0.2

    ,use_origins = true -- wether or not we should recall some v.panning start position
    ,dir_sensibility = 0.5 -- what max angle variance we accept for stating the mouse go toward an origin point
    ,origin_max = 1 -- maximum last positions we should recall
    ,magnet_to_origin = true -- when zoomed out and auto_zoom_in is true and user release near the original point of view, camera come back to that origin, precisely
    ,magnet_sensibility = 1 -- sensibility of the ratio world distance from current to origin vs height of camera
    ,use_origin_height = false

    ,auto_zoom_out = true -- auto zoom out when v.panning start
    ,onlyUnitInfoWhenCentered = true -- don't retain the panning because mouse is above a unit, unless the mouse has been centered
    ,auto_zoom_in = false -- auto zoom in when v.panning start with no zoom back -- false or threshold
    ,zoom_in = 2000 --2000-- zoom_in at this height with same keys when already zoomed out // changed to cs.height dynamically now
    ,min_zoom_back = 5000
    ,min_zoom_back_ratio = 0.50 -- if this is not false, must be a number between 0-1, it replace min_zoom_back by the ratio of the current v.altitude
    ,stay_at_own_height = false -- don't zoom back in/out on release
    ,AMPLITUDE = 2
    ,circleHelper_ratio = 0.85
    ,zoom_out_from_click = true -- take the point of view from where the click happened
    ,spawn_at_center = true -- spawn the cursor at center of screen when panning is over
    ,follow_ground = true -- make the camera follow the ground during the panning for COFC mode, TA cam use it by default
    ,clamp = 1.15 -- how much the center view can go out of the map for COFC -- false for no limit
    ,forceOnFight = true
    ,late_space_tol = 0
--
}
-- this old formula is good for default cam mode, but COFC can go beyond
-- local top_altitude = min(cfg.MAX_TOP_ALTITUDE,cfg.maxTACam ) -- some maps are so huge, that it make it unwantable (gargantuan field of isis, max v.altitude make the map unviewable)
local top_altitude = cfg.MAX_TOP_ALTITUDE
-- local top_altitude = cfg.MAX_TOP_ALTITUDE

local format = function(text,n)
    return ('%.' .. n .. 'f'):format(text)
end

options_path = 'Hel-K/PanView'
options_order = {'help','zoom_choice'
    ,'late_space_tol'
    ,'lbl_auto_zoom_out','altitude_ratio','min_zoom_back','min_zoom_back_ratio'
    ,'lbl_auto_zoom_in','zoom_in'}
options = { -- TODO finish adding options
    help = {
        name = 'Descrition',
        type = 'text',
        value = [[
    Hold SPACE + Left Click and drag  to pan the view swiftly.
    It will zoom you out/in until you release the click
    Right clicking during panning will temporarily put back the original height you were at, until release.
    While panning, you can use the mouse wheel to modify appropriate setting depending on the current state you are at.]],
    },
    zoom_choice = {
        name = 'Zoom choice',
        type = 'radioButton',
        value = cfg.zoom_choice,
        items = {
            {key = 'auto_zoom_out',         name='Auto Zoom Out'},
            {key = 'auto_zoom_in',          name='Auto Zoom In'},
            {key = 'no_zoom',               name='No Zoom'},
        },
        OnChange = function(self)
            cfg.auto_zoom_out = self.value=='auto_zoom_out'
            cfg.auto_zoom_in = self.value=='auto_zoom_in'
            cfg.zoom_choice = self.value
        end,
        noHotkey = true,
    },
    lbl_auto_zoom_out = {
        name='Auto Zoom Out',
        type='label',
    },
    altitude_ratio = {
        name = "Height by % of Top Altitude",
        desc = 'Top Altitude is set by the map dimension and value 1 represent the maximum TA Cam can go (with a FOV of 45)'
        .. '\nHeight can be changed on-the-fly while beeing auto zoomed-out and using the Mouse Wheel.'
        .. "\nNo zoom out will occur if you're starting height is not below this.",

        type            = 'number',
        value           = cfg.altitude_ratio,
        min             = 0.05,
        max             = 1.8,
        step            = 0.05,
        tooltipFunction = function(self)
                            local tip = format(self.value,2) .. ' => ' .. format(top_altitude,0 * self.value)
                            if cs.mode==1 and self.value>1 then
                                tip = tip .. "\nYou're using TA Cam, use COFC (or up the fov above 45) cam to go beyond 1."
                            end
                            return tip
                          end,
        OnChange        = function(self)
                            cfg[self.key] = self.value
                            -- Echo("Obj == self is ",Obj, Obj == self,self)
                            -- Echo("WG.Chili.Screen0.FindObjectByName is ", )

                                -- Echo("WG.Chili.Screen0:GetObjectByName(options_path) is ", WG.Chili.Screen0:GetObjectByName(options_path))
                            -- self:tooltipFunction()
                          end,
        path            = options_path,
    },


    min_zoom_back = {
        name = "Zoom Back In (fixed value)",
        desc = "When left Click is released, it will auto zoom back to that height instead of the original height if it's higher.",
        type            = 'number',
        value           = cfg.min_zoom_back,
        min             = 300,
        max             = top_altitude,
        step            = 150,
        tooltipFunction = function(self)
                            return self.value
                          end,
        OnChange        = function(self)
                            cfg.min_zoom_back=self.value
                          end,
        path            = options_path,
    },
    min_zoom_back_ratio = {
        name = "Zoom Back In (%)",
        desc = "This override the above unless it is at 0 (false), set a zoom back by % of the current zoomed out altitude",
        type            = 'number',
        value           = cfg.min_zoom_back_ratio,
        min             = 0,
        max             = 0.95,
        step            = 0.05,
        tooltipFunction = function(self)
                            return tostring(self.value>0 and ('%.2f'):format(self.value))
                          end,
        OnChange        = function(self)
                            cfg.min_zoom_back_ratio=self.value>0 and self.value
                          end,
        path            = options_path,
    },
    lbl_auto_zoom_in = {
        name='Auto Zoom In',
        type='label',
    },
    zoom_in = {
        name = 'Height Value (fixed)',
        desc = 'Zoom In Altitude, if starting height is below this, no zoom will occur',
        type            = 'number',
        value           = cfg.zoom_in,
        min             = 0,
        max             = top_altitude*0.8,
        step            = 150,
        noHotkey        = true,
        OnChange = function(self)
            cfg[self.key] = self.value
        end
    },
    late_space_tol = {
        name = 'Late Space Tolerance',
        desc = 'How long can SPACE be pressed after the click',
        type = 'number',
        value = cfg.late_space_tol,
        min = 0, max = 1, step = 0.02,
        OnChange = function(self)
            cfg[self.key] = self.value
        end
    },
}
local function UpdateOption(key,value,path) -- much faster than reopening the panel
    local opt = options[key]
    if not opt then
        return
    end
    if opt.value == value then
        return
    end
    opt.value = value
    if opt.OnChange then
        opt:OnChange()
    end
    path = path or options_path
    local panel
    for _,elem in pairs(WG.Chili.Screen0.children) do
        if  type(elem)     == 'table'
        and elem.classname == "main_window_tall"
        and elem.caption   == path
        then
            local scrollpanel,scrollPosY
            for key,v in pairs(elem.children) do
                if type(key)=='table' and key.name:match('scrollpanel') then
                    scrollpanel=key
                    break
                end
            end
            if scrollpanel then 
                scrollPosY = scrollpanel.scrollPosY
            end
            panel = scrollpanel
        end
    end
    if not panel then
        return
    end
    local found
    for i,v in ipairs(panel.children) do
        if found then break end
        for i,v in ipairs(v.children) do
            if found then break end
            local after
            for i,child in ipairs(v.children) do
                if after then
                    found = child
                    break
                end
                if child.caption == opt.name then
                    after = true
                end
            end
        end
    end
    if not found then
        return
    end
    if found.value and opt.value~=found.value and found.SetValue then
        found:SetValue(opt.value)
    end
end


local opt = options

-- ToolTip fixing and SmoothCam override
local GetUnitUnderCursor 
local MakeStatsWindow
local Tip_Widget,Screen0,unit
local SmoothCam
--

local CalcMouseSpeedAverage, CalcLagAverage, CalcMouseAngleAverage
local GetCameraHeight
---- variables
local alt,ctrl,meta,shift = spGetModKeyState()

local origins = {}
local v = {
    altitude = 0
    ,circleHelper_height = 0  -- v.draw a circle to grossly represent view limits when it will zoom back in
    ,mouse = {false,false,false}
    ,move = false
    ,draw = false
    ,panning = false
    ,height_backup = false
    ,ori_mx = false
    ,ori_my = false
    ,zoomed_in = false
    ,zooming_out = false
    ,amp_mod = false
    ,flip = false
    ,active = false
    ,mouse_angle = 0
    ,mouse_speed = 0
    ,mouse_time = 0
    ,mouse_delta = 0
    ,last_px = 0
    ,last_pz = 0
    ,started_time = 0
    ,travel = 0
    ,last_mx = 0
    ,last_my = 0

}
if cfg.clamp then 
    -- v.clampValue, v.clampValue  = mapSizeX*(cfg.clamp-1), mapSizeZ*(cfg.clamp-1)
    v.clampValue = math.min(mapSizeX,mapSizeZ)*(cfg.clamp-1)
end

table.insert(options_order,'lbl_extra')
options.lbl_extra = {
    type = 'label', name = 'Extra'
}
local exception = {
    MAX_TOP_ALTITUDE=true,
    MAX_MIN_ZOOM_BACK_RATIO=true,
    maxTACam=true,
    auto_zoom_in=true,
    auto_zoom_out=true,
}

for key,value in pairs(cfg) do -- add some raw options for testing, might not be useful/used
    if not (options[key] or exception[key]) then
        options[key] = {
            name = key,
            type = type(value)=='boolean' and 'bool' or 'number',
            value = value,
            OnChange = function(self)
                cfg[key] = self.value
            end,
        }
        if type(value) == 'number' then
            options[key].min = value*0.5
            options[key].max = value*1.5
            options[key].step = value*0.01
            options[key].tooltipFunction = function(self) return self.value end
        end
        if key == 'clamp' then
            options[key].OnChange = function(self)
                cfg[key] = self.value
                v.clampValue = math.min(Game.mapSizeX,Game.mapSizeZ)*(cfg.clamp-1)
            end
        end

        table.insert(options_order,key)
    end
end

------------- DEBUG CONFIG
local Debug = { -- default values
    active=false -- no debug, no hotkey active without this
    ,global=false -- global is for no key : 'Debug(str)'

    ,debugVar = false
}
-- Debug.hotkeys = {
--     active =            {'ctrl','alt','P'} -- this hotkey active the rest
--     ,global =           {'ctrl','alt','G'}

--     ,debugVar =         {'ctrl','alt','V'}  
-- }

debugVars = {'cs',cs,'variables',v,'constants',cfg}
-- drawing
local center_x,center_y
--
-- local AdaptHeightToFOV, UpdateFovParams
-- do
--     local RADperDEGREE = math.pi/180
--     local DEFAULT_FOV = 45
--     local tan = math.tan
--     local spGetCameraFOV = Spring.GetCameraFOV
--     local fov, currentFOVhalf_rad
--     UpdateFovParams = function()
--         fov = spGetCameraFOV()
--         currentFOVhalf_rad = (fov/2) * RADperDEGREE
--     end
--     AdaptHeightToFOV = function(height)
--         return height / tan(currentFOVhalf_rad)
--         -- cfg.min_zoom_back = cfg.min_zoom_back / tan(currentFOVhalf_rad)
--         -- v.altitude = 
--     end
    
-- end
-- UpdateFovParams()




local DetectAndRefreshPanel
do
    local function GetPanel(options_path) -- 

        if options_path =='' then
            options_path = 'INGAME MENU'
        end
        for _,elem in pairs(WG.Chili.Screen0.children) do
            if  type(elem)     == 'table'
            and elem.classname == "main_window_tall"
            and elem.caption   == options_path
            then
                Echo('name',elem.name)
                local scrollpanel,scrollPosY
                for key,v in pairs(elem.children) do
                    if type(key)=='table' and key.name:match('scrollpanel') then
                        scrollpanel=key
                        break
                    end
                end
                if scrollpanel then 
                    scrollPosY = scrollpanel.scrollPosY
                end
                return elem,scrollpanel,scrollPosY
            end
        end
    end
    DetectAndRefreshPanel = function(options_path)
        local panel,_,scrollY = GetPanel(options_path)
        if panel then
            WG.crude.OpenPath(options_path)
            if scrollY and scrollY~=0 then
                local _,scrollpanel = GetPanel(options_path)
                scrollpanel.scrollPosY=scrollY -- scrolling back
            end
        end
    end
end


local function UpdateOptions(name)
    options[name].value = cfg[name]~=nil and cfg[name] or v[name]
    DetectAndRefreshPanel(options_path)
end





local tooltip = {
    NO_TOOLTIP = "NONE",
    timeOut = false,
    win = false,
    FindWin = function(self)
        self.win = Screen0.childrenByName['tooltipWindow']
        if not self.win then
            for k,v in pairs(Screen0.children_hidden) do
                if type(k) == 'table' and k.name =='tooltipWindow' then
                    self.win = k
                    break
                end
            end
        end
    end,
    Set = function(self,text)
        if not self.win then
            self:FindWin()
        end
        Screen0.currentTooltip = text

        if self.win then -- take over the tooltipWindow of Chili Selections and CursorTip
            local win = self.win
            -- get the textbox
            local tooltipBox = win.children[1]
            if tooltipBox and tooltipBox.SetText then
                tooltipBox:SetText(text)
                win:SetVisibility(true)
                win:BringToFront()
                win:SetPos(center_x, center_y, nil, nil, true)
            end
        end

        self.timeOut = 2.3
    end,

    UpdateTime = function(self,dt)
        self.timeOut = self.timeOut-dt
        if self.timeOut<=0 then
            self.timeOut = false
            -- allow normal tooltips if we're not panning
            if v.panning then
                Screen0.currentTooltip = self.NO_TOOLTIP
            else
                Screen0.currentTooltip = nil
            end
        end

    end
}
local function CopyInto(t1,t2)
    for k,v in pairs(t1) do
        t2[k]=v
    end
end
local function CalculateAmp(AMP,height,fov)
    local fovFactor = ( 8 + (45/cs.fov) ) / 9
    local amp = AMP * ((height + 1500) / fovFactor / 1000)
    return min(amp,35)
end
local function AllowDraw(bool)
    if v.draw == bool then
        return
    end
    if bool then
        v.draw = true
        wh:UpdateWidgetCallIn('DrawWorld',widget)
        return
    end
    v.draw = false
    wh:RemoveWidgetCallIn('DrawWorld',widget)
end
local function SetCameraTarget(cs,x, y, z, transTime)
    -- NOTE: the dx,dy,dz are not correctly set in the camera state if  moving or titlting the camera camera before doing this
-- in normal TA cam, px,py,pz is the ground position where the cam look at, height is the distance between the ground position and the cam
-- in free cam (COFC) px,py,pz is the position of the camera itself, there is no height prop
    if cs.mode ~= 4 then
        cs.px, cs.pz = x,z
        spSetCameraState(cs,transTime)
    else
        --if using Freestyle cam, especially when using "camera_cofc.lua"
        --"0.46364757418633" is the default pitch given to FreeStyle camera (the angle between Target->Camera->Ground, tested ingame) and is the only pitch that original "Spring.SetCameraTarget()" is based upon.
        --"cs.py-y" is the camera height.
        --"math.pi/2 + cs.rx" is the current pitch for Freestyle camera (the angle between Target->Camera->Ground). Freestyle camera can change its pitch by rotating in rx-axis.
        --The original equation is: "x/y = math.tan(rad)" which is solved for "x"
        local ori_zDist = math.tan(0.46364757418633) * (cs.py - y) --the ground distance (at z-axis) between default FreeStyle camera and the target. We know this is only for z-axis from our test.
        local xzDist = math.tan(math.pi / 2 + cs.rx) * (cs.py - y) --the ground distance (at xz-plane) between FreeStyle camera and the target.
        local xDist = math.sin(cs.ry) * xzDist ----break down "xzDist" into x and z component.
        local zDist = math.cos(cs.ry) * xzDist
        x = x - xDist --add current FreeStyle camera to x-component
        z = z - ori_zDist - zDist --remove default FreeStyle z-component, then add current Freestyle camera to z-component
        if x and y and z then
            spSetCameraTarget(x, y, z, transTime) --return new results
        end
    end
end
local function SetHeight(height)
    cs.relHeight = height
    height = height * (45/cs.fov)
    if cs.mode == 4 then
        local dist = height - cs.height
        cs.px = cs.px + dist * -cs.dx
        cs.py = cs.py + dist * -cs.dy
        cs.pz = cs.pz + dist * -cs.dz
    end
    cs.height = height
end

local function SetCamViewPos(cs,pos)
    if cs.mode == 1 then
        cs.px, cs.py, cs.pz = unpack(pos)
        cs.viewPos = pos
        return
    end
    local height = cs.height
    cs.px, cs.py, cs.pz = 
        pos[1] + height * -cs.dx,
        pos[2] + height * -cs.dy,
        pos[3] + height * -cs.dz
    cs.viewPos = pos
end
local ClampFromEdges = function(mx, my)
    if abs(center_x-mx)>center_x*0.9 or abs(center_y-my)>center_y*0.9 then
        spWarpMouse(center_x, center_y)
        -- Echo('warp clamp')
        v.last_mx, v.last_my = center_x, center_y
        return center_x, center_y
    end
    return mx, my
end
local function Locking(cs,transTime, mx, my)
    if not transTime then
        v.this_smoothness = cfg.smoothness
        if v.zooming_out then
            v.this_smoothness = max(v.zooming_out,v.this_smoothness)
            transTime = v.this_smoothness
        end
        tooltip.timeOut = 0
    end
    unit = false

    -- spSetMouseCursor('none')
    -- spWarpMouse(center_x, center_y)
    v.last_mx, v.last_my = mx, my
    v.panning,WG.panning = true,true 
    spSetCameraState(cs._real or cs, transTime) 
    AllowDraw(v.height_backup and v.height_backup<v.circleHelper_height and not cfg.auto_zoom_in)
    -- v.last_px = false
    -- v.mouse_angle = 0 ; DebugUp('v.mouse_angle')


end
local function Copy(t)
    local copy = {}
    for k,v in pairs(t._real or t) do
        copy[k] = v
    end
    return copy
end
local function Clamp(pos)
    local clamp = v.clampValue

    local x,z = pos[1], pos[3]

    local clampedX = x < -clamp and -clamp
        or x >= clamp + mapSizeX and clamp + mapSizeX
    local clampedZ =  z < -clamp and -clamp
        or z >= clamp + mapSizeZ and clamp + mapSizeZ
    if clampedX or clampedZ then
        if clampedX then
            pos[1] = clampedX
        end
        if clampedZ then
            pos[3] = clampedZ
        end
        pos[2] = spGetGroundHeight(pos[1], pos[3])
    end
    -- Echo((clampedX or clampedZ) and 'clamped' or 'in bound', 'pos=>', unpack(pos))
    return clampedX, clampedZ

end
local function SafeTrace(x,y)
    local type,pos = spTraceScreenRay(x,y,true,false,true,true)
    if not pos then
        return
    end
    if type=='sky' then
        for i=1,3 do
            table.remove(pos,1)
        end
    end
    local clampedX, clampedZ
    if cfg.clamp then
        clampedX, clampedZ = Clamp(pos)
    end
    return pos, clampedX, clampedZ
end
local function SlideCamera(cs,dx,dy)
    if (cs.mode == 1) then
        local flip = cs.flipped
        -- simple, forward and right are locked
        cs.px = min(mapSizeX, max(cs.px - flip * dx, 0))
        cs.pz = min(mapSizeZ, max(cs.pz + flip * dy, 0))
        cs.py = spGetGroundHeight(cs.px,cs.pz)
        cs.viewPos[1], cs.viewPos[2], cs.viewPos[3] = cs.px, cs.py, cs.pz
    else
        -- forward, up, right, top, bottom, left, right
        local camVecs = spGetCameraVectors()
        local cf = camVecs.forward
        local len = math.sqrt((cf[1] * cf[1]) + (cf[3] * cf[3]))
        local dfx = cf[1] / len
        local dfz = cf[3] / len
        local cr = camVecs.right
        local len = math.sqrt((cr[1] * cr[1]) + (cr[3] * cr[3]))
        local drx = cr[1] / len
        local drz = cr[3] / len
        local diffX, diffZ = (dx * drx) + (dy * dfx), (dx * drz) + (dy * dfz)
        local set
        local prev_gy = cs.viewPos[2]
        cs.viewPos[1] = cs.viewPos[1] + diffX
        cs.viewPos[3] = cs.viewPos[3] + diffZ
        cs.viewPos[2] = spGetGroundHeight(cs.viewPos[1],cs.viewPos[3])
        if cfg.clamp then
            local clampedX, clampedZ = Clamp(cs.viewPos)
            if clampedX or clampedZ then
                SetCamViewPos(cs,cs.viewPos)
                set = true
            end
        end
        if cfg.follow_ground then
            cs.py = cs.py + (cs.viewPos[2] - prev_gy)
        end

        if not set then
            -- slide normally
            cs.px = cs.px + diffX
            cs.pz = cs.pz + diffZ
        end
    end
end
local function GetCameraHeight(cs)
    local height
    if cs.mode==1 then
        height = cs.height
    else
        local pos = SafeTrace(center_x,center_y)
        if not pos then
            return
        end
        height = ((pos[1]-cs.px)^2 + (pos[2]-cs.py)^2 + (pos[3]-cs.pz)^2) ^ 0.5
    end
    cs.relHeight = height * cs.fov / 45
    return height
end
-- local function GetCameraHeight(cs)
--     local height --= cs.height
--     -- if not height then
--         local gy = spGetGroundHeight(cs.px,cs.pz)
--         height = cs.py - gy
--     -- end
--     -- Echo('HEIGHT',height)
--     return height
-- end
 -- give an average of the lasts values, addcount can be float (for update delta time, in that case, number of table items can be great so think about it when setting the maxcount)
 -- chunk param is used when a great number of count can be expected and we want to reduce the size of the count table so we make little averages then register it as one count
local function MakeAverageCalc(maxcount,chunk)
    local n,total_count,total_values,values,counts = 0,0,0,{},{}
    local subcount,subtotal
    if chunk then
        subcount,subtotal = 0, 0
    end
    local remove = table.remove
    local function CalcAverage(value,addcount)
        if value=='reset' then
            n,total_count,total_values,values,counts = 0, 0, 0, {}, {}
            if chunk then
                subcount,subtotal = 0, 0
            end
            return
        end
        if chunk then
            subcount = subcount + addcount
            subtotal = subtotal + value * addcount
            if subcount>=chunk then
                value, addcount = subtotal, subcount
                subcount,subtotal = 0, 0
            else
                return (subtotal + total_values) / (total_count + subcount)
            end
        end

        total_count, total_values = total_count + addcount, total_values + value * addcount
        while total_count > maxcount and n > 0 do -- remove the oldest values when we are at max period
            total_values = total_values - remove(values,1)
            total_count = total_count - remove(counts,1)
            n = n - 1
        end
        n = n + 1
        counts[n], values[n] = addcount, value*addcount
        -- Echo(total_values.." / "..total_count)
        return total_values / total_count
    end
    return CalcAverage
end





function AfterMouseRelease(mx,my,button)
    -- if button==1 and v.active then

end


-- for k,v in pairs(Spring) do
--     if k:lower():match('key') then
--         Echo(k,v)
--     end
-- end

--- MAIN
local FormatTime = function(n)
    local h = math.floor(n/3600)
    h = h>0 and h
    local m = math.floor( (n%3600) / 60 )
    m = (h or m>0) and m
    local s = ('%.3f'):format(n%60)
    return (h and h .. ':' or '') .. (m and m .. ':' or '') .. s
end

local spGetKeyState = Spring.GetKeyState
local SPACE = KEYSYMS.SPACE
local lastclick, lastclick_time = 0, 0
local pressx, pressy, presstime, pressbutton, presspage = 0,0, os.clock(), 0, 0
local checkForMeta = false
local reasonHistory, n_reason = {}, 0
function widget:MousePress(mx, my, button, fake)
    local _,_,lmb,_,rmb = spGetMouseState()
    unit = false
    pressx, pressy, presstime, pressbutton, presspage = mx, my, os.clock(), button, page
    checkForMeta = false
    -- Echo('press',button .. (fake and ', fake' or ''),math.round(os.clock()))
    if not (lmb or rmb) then
        return
    end
    if button == 3 and not v.active then
        return
    end
    if v.active and button == 1 then -- called artificially by MouseRelease of rmb

        v.mousemove = false

    end
    if button == 1 and rmb and not v.active then
        return
    end



    if v.active and not lmb then
        widget:MouseRelease(1, mx,my, 'fake')
        presstime = 0
        return
    end
    if button==1  then

        local reason

        -- local _alt, _ctrl, _meta, _shift = spGetModKeyState()
        -- local SpacePressed =  spGetKeyState(SPACE)

        -- if _alt ~= alt or _ctrl ~= ctrl or _meta ~= meta or _shift ~= shift then
        --     Echo(
        --         'Get mods Key State differs from KeyPress/Release ! \n' ..
        --         'alt',alt,_alt,'ctrl',ctrl, _ctrl,'meta',meta,_meta,'shift',shift,_shift
        --     )
        -- end
        -- if meta ~= SpacePressed then
        --     Echo('meta differ from spGetKeyState(SPACE) !', meta, spGetKeyState(SPACE))
        -- end
        -- alt,ctrl,meta,shift = _alt, _ctrl, _meta, _shift

        alt, ctrl, meta, shift = spGetModKeyState()
        local _,cmd,num,aCom = spGetActiveCommand()
        


        local keyGood = (v.active or meta) and not (alt or ctrl or shift)
        if not keyGood then
            checkForMeta = not (v.active or meta or alt or ctrl or shift)
            reason = 'not keyGood ' .. FormatTime(spGetGameSeconds()) .. ' '
                .. (v.active     and ' active' or '')
                .. (meta         and ' meta' or '')
                .. (alt          and ' alt' or '')
                .. (ctrl         and ' ctrl' or '')
                .. (shift        and ' shift' or '')
                .. (checkForMeta and ' checkForMeta' or '')
        else
            local isAbove = not v.active and Screen0:IsAbove(mx,my)
            if isAbove then
                reason = 'isAbove'
            elseif WG.drawingPlacement then
                reason = 'Drawing Placement'
            elseif cs.mode~=1 and cs.mode~=4 then
                reason = 'bad camera mode'
            else
                -- if usedAcom and aCom then
                --     spSetActiveCommand(0)
                --     aCom = nil
                --     usedAcom = false
                --     Echo('acom used',FormatTime(spGetGameSeconds()))
                -- end
                local cancelFight = aCom == 'Fight' and cfg.forceOnFight
                if (aCom~=nil and not cancelFight) and  not v.active then
                    reason = 'aCom ' .. cmd ..' = ' .. tostring(aCom)

                end

                if not reason then
                    local tm = os.clock()
                    local spam = tm - lastclick_time < 0.03 and lastclick == button
                    lastclick, lastclick_time = button, tm
                    if spam and v.active then
                        reason = 'MousePress ' .. lastclick ..' getting spammed in PanView ! interv:' .. tm - lastclick_time .. ', active?' .. tostring(v.active) ..  ', fake? ' .. tostring(fake)
                            .. ', owner ? ' .. tostring(wh.mouseOwner and wh.mouseOwner.GetInfo and wh.mouseOwner:GetInfo().name)
                    end
                    if cancelFight then
                        spSetActiveCommand(0)
                        aCom = nil
                    end
                    if not MakeStatsWindow then
                        MakeStatsWindow=WG.MakeStatsWindow
                    end
                    if not v.active and Cam.relDist < 1800 then
                        if not GetUnitUnderCursor then GetUnitUnderCursor=WG.PreSelection_GetUnitUnderCursor end
                        
                        
                        if SmoothCam then wh:RemoveWidgetCallIn("Update", SmoothCam) end
                        -- memorize the unit if the v.panning started with a unit under cursor
                        -- if not unit then
                            unit = GetUnitUnderCursor(false,true)
                            if unit then
                                -- Echo('UNIT',os.clock())
                            end
                        -- end
                    end
                    spSetMouseCursor('none')
                    -- 1. determine height backup if we will have to zoom in/out
                    -- 2. auto zoom out if wanted and possible
                    -- 3. draw helping circle if configuration allow it
                    -- 4. zoom in with no return if already zoomed out
                    v.travel = 0
                    CopyInto(spGetCameraState(),cs)
                    -- if cs.mode == 4 then
                    --     cs.px,cs.py,cs.pz = spGetCameraPosition()
                    -- end
                    -- if not cs.height then
                    --     return
                    -- end
                    if cs.mode == 4 then
                    -- it is needed to be done to have the correct dz value as it seems to go wrong when camera has been moved by usual means before
                        local pos, clampedX, clampedZ = SafeTrace(center_x,center_y)

                        if not pos then -- never happened
                            Echo('PAN VIEW NO SAFE TRACE ??')
                            return
                        end

                        cs.viewPos = pos
                        -- Echo("cs.viewPos is ", cs.viewPos)
                        -- FIX ME -- when looking at the falling edge of map, the height (distance cam - > ground at center screen) is wrong and the view then is not well centered
                        cs.px,cs.py,cs.pz = spGetCameraPosition()
                        
                        cs.height, cs.flipped = GetCameraHeight(cs), cs.flipped or -1
                        if not cs.height then -- never happened
                            Echo('Pan View: Trace failed', debug.traceback())
                            return
                        end
                        cs.dx,cs.dy,cs.dz = 
                            (pos[1]-cs.px) / cs.height,
                            (pos[2]-cs.py) / cs.height,
                            (pos[3]-cs.pz) / cs.height
                        -- Echo (
                        --     (pos[1]-cs.px) / cs.height,
                        --     (pos[2]-cs.py) / cs.height,
                        --     (pos[3]-cs.pz) / cs.height
                        -- )
                        -- SetCameraTarget(cs._real or cs, pos[1], cs.py, pos[3],1) -- work 
                        -- SetCameraTarget(cs._real or cs, pos[1], cs.py, pos[3],5) -- work 
                        -- spSetCameraState(cs)
                        -- CopyInto(spGetCameraState(),cs)
                        -- SetCameraTarget(cs._real or cs, pos[1], cs.py, pos[3],0)
                        -- CopyInto(spGetCameraState(),cs)
                    else
                        cs.height, cs.flipped = GetCameraHeight(cs), cs.flipped or -1
                        if not cs.height then -- never happened
                            Echo('Pan View: Trace failed', debug.traceback())
                            return
                        end

                        cs.viewPos = {cs.px,cs.py,cs.pz}
                    end
                    -- cs.height, cs.flipped = GetCameraHeight(cs), cs.flipped or -1
                    local _
                    -- reset the last data we had on mouse speed
                    CalcMouseSpeedAverage('reset')
                    v.mouse_time = os.clock() 
                    v.mouse_speed = 0 
                    CalcMouseAngleAverage('reset')
                    v.mouse_angle = 0 
                    -- 

                    if cfg.auto_zoom_in then
                        local type,pos = spTraceScreenRay(mx,my,true,false,true,true)
                        if not pos then 
                            Echo('Pan View: Trace failed', debug.traceback())
                            return
                        end
                        if type=='sky' then
                            for i=1,3 do
                                table.remove(pos,1)
                            end
                        end
                        if cs.relHeight > cfg.zoom_in then
                            v.height_backup = cs.relHeight
                        end
                        -- cs.px,_, cs.pz = unpack(pos)
                        SetCamViewPos(cs,pos)
                        SetHeight(cfg.zoom_in)

                        v.zoomed_in = true 
                    else
                        if not v.active then
                            if cfg.zoom_out_from_click then
                                local pos = SafeTrace(mx,my)
                                if pos then
                                    -- if unit and cfg.onlyUnitInfoWhenCentered then
                                    --     --- helper to not trigger the info unit  when clicking without dragging, in order to effectively slide briefly the pos of cam
                                    --     if cs.height > 3000 then
                                    --         local lastpx, lastpy, lastpz = unpack(cs.viewPos or {0,0,0})
                                    --         -- Echo(
                                    --         --     abs(lastpx-pos[1]) > lastpx*0.10
                                    --         --     , abs(lastpy-pos[2]) > lastpy*0.20
                                    --         --     , abs(lastpz-pos[3]) > lastpz*0.10
                                    --         -- )
                                    --         if abs(lastpx-pos[1]) > lastpx*0.10
                                    --             or abs(lastpy-pos[2]) > lastpy*0.20
                                    --             or abs(lastpz-pos[3]) > lastpz*0.10
                                    --         then
                                    --             unit = false
                                    --         end
                                    --     end
                                    -- end

                                    SetCamViewPos(cs,pos)

                                end
                            end
                            v.zoomed_in = false 
                            if cfg.use_origins and not v.panning then

                                local pos = cs.viewPos
                                local x,z = pos[1],pos[3]
                                cs.viewPos = pos
                                v.last_px,v.last_pz = x, z
                                v.mouse_speed = 0 
                                local closest,c
                                for i,origin in ipairs(origins) do -- update the origin dists and find the closest
                                    origin.dist = ((origin.viewPos[1]-x)^2 + (origin.viewPos[3]-z)^2)^0.5
                                    if not closest or origin.dist<closest.dist then
                                        closest, c = origin, i
                                    end
                                end
                                -- if closest is too close of our starting pos or if we reached the max origin, we remove it 
                                if origins[cfg.origin_max] or closest and closest.dist<cs.relHeight/5 then
                                    table.remove(origins,c)
                                end
                                local origin = {}
                                CopyInto(cs._real or cs, origin)

                                origin.dist = 0
                                origin.viewPos = {unpack(pos)}
                                origins.closest = origin
                                table.insert(origins,1,origin)
                            end
                        end
                        v.altitude = top_altitude * cfg.altitude_ratio
                        if cs.relHeight<v.altitude then
                            if cfg.auto_zoom_out then
                                -- Echo(" is ", cfg.min_zoom_back_ratio and v.altitude*cfg.min_zoom_back_ratio, min(cfg.min_zoom_back,v.altitude), cs.relHeight)
                                local zoom_back = cfg.min_zoom_back_ratio and v.altitude*cfg.min_zoom_back_ratio or cfg.min_zoom_back
                                v.height_backup = max(zoom_back,cs.relHeight)
                                SetHeight(v.altitude)
                                v.zooming_out = cfg.smoothness_zoom
                            end
                        end
                    end
                    v.amp_mod = CalculateAmp(cfg.AMPLITUDE, cs.relHeight)

                    v.flip = -cs.flipped
                    ----

                    v.last_mx, v.last_my = mx, my
                    -- Echo("GetUnitUnderCursor(false,true) is ", GetUnitUnderCursor(false,true))
                    -- fixing cursor tip behaviour, will bring back cursor tip and trigger the space+click on unit if we didnt v.move from click to release
                    -- if no unit under cursor we don't have to bother waiting for zooming
                    if not unit --[[and (v.height_backup or v.zoomed_in)--]] then
                        v.this_smoothness = cfg.smoothness
                        if v.zooming_out then
                            v.this_smoothness = max(v.zooming_out,v.this_smoothness)
                        end
                        Locking(cs,v.this_smoothness, mx, my) 
                    else
                        -- Echo('holding !',os.clock())
                    end
                    --
                    -- if Tip_Widget then -- remove the tooltip produced by press of meta (old method)
                    --     local win = Screen0:GetChildByName("tooltipWindow")
                    --     if win then 
                            if not tooltip.timeOut then
                                Screen0.currentTooltip = tooltip.NO_TOOLTIP
                            end
                    --         wh:RemoveWidgetCallIn("Update", Tip_Widget)
                    --         win:Hide()
                    --     end
                    -- end
                    --

                    --wh:UpdateWidgetCallIn("Update", self)
                    if not v.active then
                        v.active = true 
                        v.started_time = os.clock()
                        v.mousemove = true
                    end
                    v.mouse[1] = true
                    -- Echo(' => button',button,FormatTime(os.clock()))
                    return true
                end

            end
        end
        if not v.active and reason then
            n_reason = n_reason + 1
            local str = '[' .. FormatTime(spGetGameSeconds()) .. ']: ' .. reason .. ' Press ' .. button .. ' page: ' .. page
            reasonHistory[n_reason] = str

            if reason and not reason:match('not keyGood') and not reason:sub(1,6) == 'aCom -' then
                -- don't debug wrong key or active command build
                Echo('Pan view didnt trigger because ' .. reason)
            end
        end
        usedAcom = aCom and not shift

    end
    -- switch to zoom in/out with right click while panning
    if button==3 and v.active then 
        spSetMouseCursor('none')

        v.mousemove = true
        if v.height_backup and v.panning then
            CopyInto(spGetCameraState(),cs)
            cs.height, cs.flipped = GetCameraHeight(cs), cs.flipped or -1
            if not cs.height then
                Echo('Pan View: Trace failed', debug.traceback())
                return
            end
            if round(cs.relHeight)~=round(v.height_backup) then
                SetHeight(v.height_backup)

                v.amp_mod = CalculateAmp(cfg.AMPLITUDE, cs.relHeight)
                v.zoomed_in = not cfg.auto_zoom_in
                AllowDraw(not v.zoomed_in)
            else
                SetHeight(v.altitude)

                v.amp_mod = CalculateAmp(cfg.AMPLITUDE, cs.relHeight)
                v.zoomed_in = false
                AllowDraw(round(v.altitude)>round(v.circleHelper_height))
            end

            spSetCameraState(cs._real or cs, smoothness_zoom)
            -- Echo("cs.viewPos[1], cs.viewPos[3] is ", cs.viewPos[1], cs.viewPos[3])
            v.mouse[3] = true
        end

        return true
    end
    --
end

local avglag = 0

local totaldt = 0
local dtcount = 0


local dt = 0
local spGetLastUpdateSeconds = Spring.GetLastUpdateSeconds

local function Move(mx,my,dx,dy)
    -- Echo("mx, my is ", mx, my)
    spSetMouseCursor('none')
    -- Echo('moving, unit?',unit)
    if cfg.wait_before_panning and time-v.started_time < cfg.wait_before_panning then
        return
    end
    if not v.move then
        -- start panning and apply zoom out or zoom in with delay, we started with an unit under cursor
        Locking(cs, nil, mx, my)
        --
        v.move=true      
    end
    v.last_px, v.last_pz = cs.viewPos[1], cs.viewPos[3]
    v.mouse_delta = (dx^2 + dy^2)^0.5
    -- Echo("mx,my is ", mx,my)
    -- Echo("dx,dy is ", dx,dy)
    local time = os.clock()
    local move_time = time-v.mouse_time
     -- Echo("v.mouse_delta is ", v.mouse_delta,  (v.amp_mod * v.flip * (v.ori_my - my)))
    v.mouse_time = time
    -- Echo('MouseMove ',dx,dy,(mx - v.ori_mx), (my - v.ori_my))
    -- if v.move then

        -- local pos, clampedX, clampedZ = SafeTrace(center_x,center_y)
        -- if pos and (clampedX or clampedZ) then
        --     SetCamViewPos(cs,pos)
        -- else
            -- local dx,dy = v.amp_mod * (mx - v.ori_mx), v.amp_mod * (my - v.ori_my)
            -- we don't need to warp mouse with MouseMove, the amp can be reduced
            -- local lagfactor = math.max(1, spGetLastUpdateSeconds() / 0.04)
            local lagfactor = 1
            -- Echo("lagfactor is ", lagfactor)
            v.travel = v.travel + (dx^2 + dy^2)^0.5
            -- local dx,dy = lagfactor * v.amp_mod * 0.25 * (dx), lagfactor *  v.amp_mod * 0.25 * (dy)
            local dx,dy = lagfactor * v.amp_mod * dx, lagfactor *  v.amp_mod * dy
            SlideCamera(cs,dx,dy)
        -- end
        
        -- cs.px = cs.px + (v.amp_mod * v.flip * (mx - v.ori_mx) --[[* (1+dt*2)--]])
        -- cs.pz = cs.pz + (v.amp_mod * v.flip * (v.ori_my - my) --[[* (1+dt*2)--]])
        -- cs.px, cs.pz = max(0, min( cs.px, mapSizeX)), max(0, min( cs.pz, mapSizeZ))
    -- end
    v.this_smoothness = cfg.smoothness

    if v.zooming_out then
        v.zooming_out = v.zooming_out-move_time
        if v.zooming_out<=0 then
            v.zooming_out = false
        end
        -- DebugUp('v.zooming_out',v.zooming_out)
    end

    if v.zooming_out then
        -- v.this_smoothness = max(v.zooming_out,v.this_smoothness)
    end

    spSetCameraState(cs._real or cs, v.this_smoothness--[[spGetLastUpdateSeconds()--]])

    if cfg.use_origins then
        v.mouse_speed = CalcMouseSpeedAverage(v.mouse_delta,move_time) -- ; DebugUp('v.mouse_speed',v.mouse_speed)
        if v.last_px then
            v.mouse_angle = CalcMouseAngleAverage(atan2(cs.viewPos[1] - v.last_px, cs.viewPos[3] - v.last_pz),move_time)
        else
            Echo('NO LAST PX')
            v.mouse_angle = CalcMouseAngleAverage(v.mouse_angle,move_time)
        end

    end

    -- Echo('MouseMove:',move_time,'('..v.mouse_delta..')','angle: '..v.mouse_angle,'speed: '..v.mouse_speed)
    if abs(v.mouse_angle)>3*pi then
        Echo('weird angle:'..atan2(cs.viewPos[1] - v.last_px, cs.viewPos[3] - v.last_pz),'v.move time:'..move_time,cs.viewPos[1],v.last_px, cs.viewPos[3],v.last_pz)
    end
    -- spWarpMouse(v.ori_mx,v.ori_my)

    -- define the closest origin to go on release
    if cfg.use_origins and origins[1] then
        local closest
        local big_threshold = cs.relHeight * cfg.magnet_sensibility * (v.mouse_speed/300) --; DebugUp('big_threshold',big_threshold)
        local x,z = cs.viewPos[1], cs.viewPos[3]
        for i,origin in ipairs(origins) do
            local ox,oz = origin.viewPos[1], origin.viewPos[3]
            origin.dist = ((ox-x)^2 + (oz-z)^2)^0.5
            local good = origin.dist  < cs.relHeight^0.75 * cfg.magnet_sensibility
            if not good then
                if origin.dist<big_threshold then
                    if v.mouse_speed>300 then -- could be scaling the threshold?
                        local diff_angle = abs(v.mouse_angle-atan2(ox - x, oz - z))
                        local getting_closer = diff_angle < cfg.dir_sensibility or ( diff_angle > pi * 2  - cfg.dir_sensibility )
                        if getting_closer then
                            origin.getting_closer = os.clock()
                            -- Echo('getting closer',v.mouse_angle,diff_angle)
                        elseif origin.getting_closer and origin.getting_closer>0.5 then
                            origin.getting_closer = false
                        end
                        good = origin.getting_closer
                        -- Echo('good?',good)
                    end
                end
            end

            if good and (not closest or origin.dist<closest.dist) then
                closest = origin
            end
        end
        origins.closest = closest
    end
    mx, my = ClampFromEdges(mx, my)
    v.last_mx, v.last_my = mx, my
end

function widget:MouseMove(mx,my,dx,dy,button)
    -- Echo('Mouse Move',dx,dy)
    Move(mx,my,dx,dy)
    -- if dx==0 and dy==0 then -- never happening
    --     Echo('PanView mouse move 0 pixel!?',os.clock())
    -- end
    return true
end
-- local verif = false
-- local DGcount = 0
-- local DScount = 0
-- function widget:DrawGenesis()
--     if verif then
--         verif = verif + 1
--         if verif == 4 then
--             verif = false
--         end
--     end
--     DGcount = DGcount + 1
--     if verif then
--         Echo(verif, '=> DG',DGcount)
--     end

-- end
-- function widget:DrawScreen()
--     if verif then
--         verif = verif + 1
--         if verif == 4 then
--             verif = false
--         end
--     end
--     DScount = DScount + 1
--     if verif then
--         Echo(verif,'=> DS',DScount)
--     end

-- end
-- for k,v in pairs(Spring) do
--     if k:lower():match('sel') then
--         Echo(k,v)
--     end
-- end
-- for k,v in pairs(Spring.Utilities) do
--     if k:lower():match('sel') then
--         Echo('u',k,v)
--     end
-- end
local Points = {}

local function WorkAroundTraceGround()
    -- CAN'T WORK THIS DOESNT TAKE INTO ACCOUNT THE NEW CAMERA POS
    local mx,my = spGetMouseState()
    local _,startPoint = spTraceScreenRay(mx,my,true,false,true,true)

    if startPoint then
        local cs = spGetCameraState()
        local radarHeight = 10
        local offset = {0,0,-300}
        startPoint[2] = startPoint[2] + radarHeight
        local csground = {}
        CopyInto(csground, cs)
        local wantedX, wantedZ = startPoint[1] + offset[1],startPoint[3] + offset[3]
        local wantedY = spGetGroundHeight(wantedX, wantedZ)
        if wantedY then
            if cs.mode == 4 then
                -- put the camera almost totally horizontal
                local PI = math.pi
                csground.rx = -0.06
                -- csground.rx = - PI/2
                csground.ry = - PI
                csground.px, csground.py, csground.pz = unpack(startPoint)
            else
                csground.height = radarHeight
            end
            spSetCameraState(csground)
            local mx, my = spWorldToScreenCoords(wantedX, wantedY, wantedZ) -- CAN'T WORK THIS DOESNT TAKE INTO ACCOUNT THE NEW CAMERA POS
            local type,tracePos = spTraceScreenRay(mx,my,true,false,true,true)
            local testInReal = true
            if tracePos then
                -- if type == 'sky' then
                --     tracePos[1], tracePos[2], tracePos[3] = tracePos[4], tracePos[5], tracePos[6]
                -- end
                local tracedGround = spGetGroundHeight(tracePos[1], tracePos[3])
                if tracedGround then
                    Echo("mx,my is ", mx,my,'traced',tracePos[1], tracePos[2],'(ground ' .. tracedGround .. ')', tracePos[3])
                    local green, blue, yellow, red = {0,1,0,1}, {0,0,1,1}, {1,1,0,1}, {1,0,0,1}
                    Points[1] = {color = green, unpack(startPoint)}
                    Points[2] = {color = blue, wantedX, wantedY, wantedZ}
                    Points[3] = {color = yellow, tracePos[1], tracePos[2], tracePos[3]}
                    Points[4] = {color = red, tracePos[1], tracedGround, tracePos[3]}
                else
                    Echo("mx,my is ", mx,my,'traced',tracePos[1], tracePos[2],'( traced ground error !)', tracePos[3])
                end

            end
            if testInReal then
                -- see where the mouse would go and don't put back the camera where it was
                spWarpMouse(mx,my) -- IT JUST MOVE AT THE LOCATION OF WORLD WITHOUT TAKING INTO ACCOUNT THE NEW CAMERA
                spSetCameraState(cs)
                -- SetCameraTarget(cs, cs.px, cs.py, cs.pz,0)
            else
                spSetCameraState(cs)
                -- SetCameraTarget(cs, cs.px, cs.py, cs.pz,0)
            end
        end
    end
end

function widget:KeyPress(key, mods, isRepeat)
    if mods.alt and key == 102 then -- ALT + F
        -- WorkAroundTraceGround()  -- UNFORTUNATELY CANNOT WORK
            -- Echo('DG: ' .. DGcount)
        -- Echo('DS: ' .. DScount)
        -- Echo('page: ' .. page)
    end
    alt, ctrl,meta,shift = mods.alt, mods.ctrl, mods.meta, mods.shift
    if v.panning then
         return true
    end
    if not isRepeat and (meta or key == 32) then
        if checkForMeta then
            -- WORK AROUND: when  key press happens just a few millisec before the click, the mousepress come before anyway, we fix this by resending a mouse press
            checkForMeta = false
            if not v.active then
                if pressbutton == 1 then
                    local _,_,lmb,_,rmb = spGetMouseState()

                    local time = os.clock()
                    -- if time - presstime < 0.03 then
                    if lmb and not rmb and time - presstime < cfg.late_space_tol --[[and page <= presspage + 2--]] then

                        local alt, ctrl, meta, shift = spGetModKeyState()
                        if meta and not (ctrl or alt or shift) then
                            local _,cmd,num,aCom = spGetActiveCommand()
                            local cancelFight = aCom == 'Fight' and cfg.forceOnFight
                            if (not aCom or cancelFight) and not wh.mouseOwner then
                                n_reason = n_reason +1
                                local str= '[' .. FormatTime(spGetGameSeconds()) .. ']: ' .. 'from KeyPress: meta has been pressed just after left click ! sending mouse click, interv ' .. (time - presstime) .. ' page: ' .. page .. ', presspage: ' .. presspage
                                reasonHistory[n_reason] = str
                                pressbutton = false
                                presstime = 0
                                lastclick, lastclick_time = 0, 0
                                -- Echo(str)
                                Spring.SendCommands({'mouse1'}) -- resend a mouse press to apply the panning
                                return true
                            end
                        end
                    end
                end

                return
            end
            return
        end
    end
    if key == 100 and mods.alt then -- alt + D
        for i=n_reason-10, n_reason do
            if reasonHistory[i] then
                Echo('reason #' .. i .. ' Pan View Didnt trigger:' .. reasonHistory[i] )
            end
        end
    -- spSendCommands('mouse3')
        -- local rand = math.random()
        
        -- Echo("options.altitude_ratio.children is ", options.altitude_ratio.parent)
        -- for k,v in pairs(options.altitude_ratio) do
        --     Echo(k,v)
        -- end
    end
end



function widget:Update(deltaTime)
    page = page + 1

    -- if verif then
    --     verif = verif + 1
    --     if verif == 4 then
    --         verif = false
    --     end
    -- end
    -- if verif then
    --     Echo(verif,'=> Update',page)
    -- end
    if tooltip.timeOut then
        tooltip:UpdateTime(deltaTime)
    end
    if not v.active then
        if opt.debugVar.value then
            CopyInto(spGetCameraState(),cs)
        end
        -- if checkForMeta then
        --     checkForMeta = false
        --     if pressbutton == 1 then
        --         local time = os.clock()
        --         local _,_,lmb,_,rmb = spGetMouseState()

        --         local time = os.clock()
        --         -- if time - presstime < 0.03 then
        --         if lmb and not rmb and time - presstime < 0.03 and page <= presspage + 2 then
        --             local alt, ctrl, meta, shift = spGetModKeyState()
        --             if meta and not (ctrl or alt or shift) then
        --                 local _,cmd,num,aCom = spGetActiveCommand()
        --                 local cancelFight = aCom == 'Fight' and cfg.forceOnFight
        --                 if (not aCom or cancelFight) and not wh.mouseOwner then
        --                     n_reason = n_reason +1
        --                     local str= '[' .. FormatTime(spGetGameSeconds()) .. ']: ' .. 'from Update: meta has been pressed just after left click ! sending mouse click, interv ' .. (time - presstime) .. ' page: ' .. page .. ', presspage: ' .. presspage .. ', ' .. ' meta? ' .. tostring(meta) .. ' key pressed 32? ' .. tostring(Spring.GetKeyState(32))
        --                     presstime = 0
        --                     pressbutton = false
        --                     lastclick, lastclick_time = 0, 0
        --                     reasonHistory[n_reason] = str
        --                     -- Echo(str)
        --                     Spring.SendCommands({'mouse1'})
        --                 end
        --             end
        --         end
        --     end
        -- end

        return
    end
    if not tooltip.timeOut then
        Screen0.currentTooltip = tooltip.NO_TOOLTIP
    end
    -- Echo("wh.mouseOwner is ", wh.mouseOwner)
    if not v.active then
        return
    end
    dt = deltaTime
    -- if not v.move then
    --     -- start panning and apply zoom out or zoom in with delay, we started with an unit under cursor

    --     Locking(cs)
    --     --
    --     v.move=true      
    -- end
    -- if true then
    --     return
    -- end
    -- if not wh.mouseOwner then
    --     wh.mouseOwner = widget
    -- end
    local mx, my, lmb, _, rmb = spGetMouseState()
    -- Echo(mx-v.mmmx, my-v.mmmy)
    ------------
     -- fixing left/right click release detection if both has been used while panning
    -- local zoom_in_expected_state = (v.zoomed_in and cfg.auto_zoom_out or not v.zoomed_in and cfg.auto_zoom_in)
    -- if not lmb and not zoom_in_expected_state  then
    --     widget:MouseRelease(mx,my,1)
    --     return
    -- end
    -- if not rmb and zoom_in_expected_state then
    --     widget:MouseRelease(mx,my,3)
    --     return
    -- end
    -- if not (lmb or rmb) then 
    --     return
    -- end
    -- Echo("v.mouse[1], v.mouse[3] is ", v.mouse[1], v.mouse[3])
    if not lmb and v.mouse[1]  then
        Echo('fix lmb')
        widget:MouseRelease(mx,my,1)
        v.mouse[1] = false -- fixing bug ?
        return
    end
    if not rmb and v.mouse[3] then
        Echo('fix rmb')
        widget:MouseRelease(mx,my,3)
        v.mouse[3] = false -- fixing bug ?
        return
    end
    spSetMouseCursor('none')
-----

    -- Echo("v.last_mx is ", v.last_mx,'update')
    -- local stay_still = mx-v.ori_mx==0 and v.ori_my-my==0
    local dx,dy = mx - v.last_mx, my - v.last_my
    -- Echo("mx,my is ", mx,my,'last',v.last_mx, v.last_my,"dx,dy is ", dx,dy)
    -- Echo(dx, dy)
    v.mouse_delta = (dx~=0 or dy~=0) and (dx^2 + dy^2)^0.5  or 0
    local time = os.clock()
    local move_time = time-v.mouse_time
    v.mouse_time = time

    local moveUpdate =  not v.mousemove and v.mouse_delta > 0
    v.last_mx, v.last_my = mx, my
    
    if moveUpdate then
        Move(mx, my, dx, dy)
    end

    v.last_px, v.last_pz = cs.px, cs.pz

    if cfg.use_origins then
        v.mouse_speed = CalcMouseSpeedAverage(v.mouse_delta,move_time) -- ; DebugUp('v.mouse_speed',v.mouse_speed)
        if v.last_px then
            local angle
            if v.mouse_delta == 0 then
                CalcMouseAngleAverage(0,move_time)
            else
                v.mouse_angle = CalcMouseAngleAverage(atan2(cs.viewPos[1] - v.last_px, cs.viewPos[3] - v.last_pz),move_time)
            end
        else
            Echo('NO LAST PX')
            v.mouse_angle = CalcMouseAngleAverage(v.mouse_angle,move_time)
        end

    end
    


    -- Echo("Update:", move_time,'('..v.mouse_delta..')','angle: '..v.mouse_angle,'speed: '..v.mouse_speed)
    if v.zooming_out then
        v.zooming_out = v.zooming_out-move_time
        if v.zooming_out<=0 then
            v.zooming_out = false
        end
        -- DebugUp('v.zooming_out',v.zooming_out)
    end
    if not moveUpdate then
        return
    end

    if cfg.use_origins and origins[1] then
        local closest
        local big_threshold = cs.relHeight * cfg.magnet_sensibility * (v.mouse_speed/300); DebugUp('big_threshold',big_threshold)
        local x,z = cs.viewPos[1], cs.viewPos[3]
        for i,origin in ipairs(origins) do
            local ox,oz = origin.viewPos[1], origin.viewPos[3]
            origin.dist = ((ox-x)^2 + (oz-z)^2)^0.5
            local good = origin.dist  < cs.relHeight^0.75 * cfg.magnet_sensibility
            if not good then
                if origin.dist<big_threshold then
                    if v.mouse_speed>300 then -- could be scaling the threshold?
                        local diff_angle = abs(v.mouse_angle-atan2(ox - x, oz - z))
                        local getting_closer = diff_angle < cfg.dir_sensibility or ( diff_angle > pi * 2  - cfg.dir_sensibility )
                        if getting_closer then
                            origin.getting_closer = os.clock()
                            -- Echo('getting closer',v.mouse_angle,diff_angle)
                        elseif origin.getting_closer and origin.getting_closer>0.5 then
                            origin.getting_closer = false
                        end
                        good = origin.getting_closer
                        -- Echo('good?',good)
                    end
                end
            end

            if good and (not closest or origin.dist<closest.dist) then
                closest = origin
            end
        end
        origins.closest = closest
    end



    --
    -- Echo("v.altitude-cs.height)/v.altitude is ", (v.altitude-cs.height)/v.altitude)   
    -- Echo("v.mouse_speed is ", v.mouse_speed,mx,my)
    -- local smoothness = v.zooming_out and (smoothness_zoom*(v.altitude-cs.height)/v.altitude) or smoothness 

    v.this_smoothness = cfg.smoothness
    if v.zooming_out then
        v.this_smoothness = max(v.zooming_out,v.this_smoothness)
    end

    spSetCameraState(cs._real or cs, v.this_smoothness)   

    -- spWarpMouse(v.ori_mx,v.ori_my)
--[[    else
    wh:RemoveWidgetCallIn("Update", self)--]]

end

local function OwnMouse()
    wh.mouseOwner = widget
end
-- NOTE: when 2 mouse press occur at same time, Mouse Release will detect only one, we have have to work around it by using Update and sending fake call of mouse release when needed
function BeforeMouseRelease(mx,my,button)
    -- Echo('before release',button)
end
function widget:MouseRelease(mx, my, button, fake)
    -- Echo("Release is ", button .. (fake and ', fake' or ''), math.round(os.clock()))
    -- Echo("mx,my is ", mx,my, 'release')
    if not v.active then return end 
    if button == 2 then
        return
    end
    v.mouse[button] = false
    local _,_,lmb,_,rmb = spGetMouseState()
    if lmb and button~=1 or rmb and button~=3 then
        -- Echo('another button is held')
        -- if another button is still held
        if wh.mouseOwner and wh.mouseOwner:GetInfo().name == 'Pan View' then
            wh.mouseOwner = nil
        end
    else
        -- Echo('no other button is held')
    end
    -- Echo("mx, 'mouseRelease' is ", mx, 'mouseRelease')
    v.last_mx, v.last_my = mx, my
    if button==3 then 
        if lmb then
            v.mousemove = false
            -- Echo('fake press',mx, my)
            return -1, widget:MousePress(mx,my,1,'fake')
        end
        -- return false, OwnMouse()

    end
    if rmb then
        return --- 1
    end
    CalcMouseSpeedAverage('reset')
    if SmoothCam then wh:UpdateWidgetCallIn("Update", SmoothCam) end
    --------------
    -- fixing space+click behaviour
    if unit  then 
        -- normal behaviour, panning didnt really happen
        if not v.move then
            if Tip_Widget then
                local ud = UnitDefs[spGetUnitDefID(unit)]
                if ud then
                    MakeStatsWindow(ud, mx, my, unit)
                end
            end
        else
        -- if v.panning happened and had unit under cursor, fix the add in selection
            local got_unit -- check if we got the unit under cursor selected already
            for i,id in ipairs(spGetSelectedUnits()) do if id==unit then got_unit=true break end end
            if not got_unit then -- we gonna have to remove the unit from selection
                wh:UpdateWidgetCallIn("SelectionChanged", self)
            end
            DebugUp('got_unit',got_unit)
        end
        unit = false
    end
    v.move = false
    -- unhide the tooltip window if there's one (old method)
    -- local win = Screen0:GetChildByName("tooltipWindow")
    -- if win then 
        if not tooltip.timeOut then -- allow normal tooltip
            Screen0.currentTooltip = nil
        end
    --     win:Show() -- bring back the tooltip
    --     wh:UpdateWidgetCallIn("Update", Tip_Widget)
    -- end
    ------------
    v.active = false   
    v.last_px = false
    -- if we started on a unit and didnt move, no panning happened
    if not v.panning then
        v.height_backup,origins.closest = false, false

        return
    end
    --------------
    v.panning,WG.panning = false,false
    AllowDraw(false)
    --------------
    -- in auto_zoom_out mode, zoom back in if needed
    local new_height
    -- CopyInto(spGetCameraState(),cs)
    -- cs.height, cs.flipped = GetCameraHeight(cs), cs.flipped or -1
    local new_cs
    if cfg.use_origins and origins.closest then
        CopyInto(origins.closest,cs)
        new_cs = true
        if cfg.use_origin_height then
            new_height = origins.closest.relHeight
        end
    end
    if not new_height and v.height_backup and not cfg.stay_at_own_height then
        new_height = v.height_backup
    end
    if new_height then
        SetHeight(new_height)
    end
    if new_cs or new_height then
        spSetCameraState(cs._real or cs, cfg.smoothness_zoom_back)
    end
    

    origins.closest = false
    v.height_backup = false 

    --
    -- in auto_zoom_in mode, put the mouse at center
    if v.zoomed_in then
        v.zoomed_in = false 
    end
    if cfg.spawn_at_center and not v.active and mx ~= center_x and my ~= center_y then
        spWarpMouse(center_x,center_y)
        -- Echo('warp mouse release')
        v.last_mx, v.last_my = center_x, center_y
    end
    -- fixing mouseOwner in case Right click during v.panning occured
    -- if wh.mouseOwner and wh.mouseOwner:GetInfo().name == 'Pan View' then wh.mouseOwner=nil end -- mouseOwner stay when multiple button are held together and released -- the MouseRelease call-in doesnt work properly to manage click combination
    --------------
    return true
end

-- function AfterKeyRelease(key,...)
--     local thiskey = KEYCODES[key]
--     if thiskey and currentCombo.keys[thiskey] then
--         Echo('we missed key '..thiskey)
--         widget:KeyRelease(key,...)
--     end
-- end
function AfterMouseRelease(mx,my,button)
    if v.mouse[button] and v.active then
        -- local buttonName = (button==1 and 'l' or button==2 and 'm' or 'r')..'Click'
        -- Echo('PanView missed button '..buttonName, os.clock())
        widget:MouseRelease(mx, my, button, 'fake')
    end
end
--------------
-- AUTO CONFIG changing v.altitude ratio with  mouse wheel while v.panning


-------

function widget:MouseWheel(up,value)
    if not v.panning then
        return
    end

    if not v.zoomed_in then
        local update =  not v.height_backup or cs.relHeight>v.height_backup*0.98
        local new_altitude_ratio
        if v.height_backup then
            new_altitude_ratio = cfg.altitude_ratio*(1-value/10)
        else
            new_altitude_ratio = (cs.relHeight/top_altitude)*(1-value/10)
        end
        
        if cs.mode==1 then
            -- if value<0 and cfg.altitude_ratio * top_altitude >= cfg.maxTACam then
            if value<0 and cs.height >= cfg.maxTACam then
                tooltip:Set('Pan View:\nYou cannot go further higher with TA cam, use COFC ! ')
                return true
            elseif new_altitude_ratio * top_altitude * (45/cs.fov) > cfg.maxTACam then
                new_altitude_ratio = cfg.maxTACam / top_altitude / (45/cs.fov)
                tooltip:Set('Pan View:\nMax top altitude ' .. format(cfg.maxTACam,0) .. ' reached for TA Cam, use COFC to go further !\nAltitude Ratio: ' .. format(new_altitude_ratio,3))
            end
                
        end
        -- if new_altitude_ratio>1.5 then
        --     if cs.mode==4 then
        --         top_altitude = new_altitude_ratio * top_altitude
        --     end
        --     new_altitude_ratio=1.5
        -- end

        local new_altitude = top_altitude*new_altitude_ratio
        -- Echo("new_altitude,min_zoom_back is ", new_altitude,min_zoom_back)
        -- if cfg.min_zoom_back and new_altitude < cfg.min_zoom_back*1.5 then
        --     return true
        -- end

        -- Update the zoom back according to our new height

        -- if no ratio
        -- local new_zoom_back
        -- if not cfg.min_zoom_back_ratio then
        --     -- no zoom back ratio, we use a fixed value cfg.min_zoom_back, we don't have to update it, as we are zoomed out
        --     new_zoom_back = math.max(cfg.min_zoom_back, v.height_backup or 0)
        -- else

        -- end


        local new_zoom_back = math.max(cfg.min_zoom_back, v.height_backup or 0)
        if cfg.min_zoom_back_ratio then
            new_zoom_back = math.max(cfg.min_zoom_back_ratio * new_altitude, v.height_backup or 0)
        end
        if new_altitude < new_zoom_back * 1.02 and v.height_backup then
            -- Echo('returned true')
            return true
        end
        -- Echo('passed')
        if cfg.altitude_ratio~=new_altitude_ratio then
            cfg.altitude_ratio = new_altitude_ratio 
            UpdateOption('altitude_ratio',new_altitude_ratio)
        end
        if not cfg.min_zoom_back_ratio then
            cfg.min_zoom_back = new_zoom_back
            UpdateOption('min_zoom_back',new_zoom_back)
        end
        if v.height_backup or new_zoom_back * 1.02 <= cs.relHeight then
            v.height_backup = new_zoom_back
        end
        if new_altitude~=v.altitude then
            tooltip:Set('Pan View:'
                ..'\nabsolute: ' .. ('%.2f'):format(cs.height) ..', rel: ' .. ('%.2f'):format(cs.relHeight)
                ..'\nAltitude Ratio: ' .. format(cfg.altitude_ratio,3)
                .. '\nAltitude: ' .. format(new_altitude,0) .. ' (max: '..format(top_altitude,0)..')')
            
        end
        v.altitude = new_altitude 
        v.circleHelper_height = v.altitude*cfg.circleHelper_ratio 
        if update then 
            SetHeight(v.altitude )
            v.amp_mod = CalculateAmp(cfg.AMPLITUDE, cs.relHeight)
            spSetCameraState(cs._real or cs, cfg.smoothness)
        end
    else
        local current_ratio = cfg.min_zoom_back_ratio or cfg.min_zoom_back / v.altitude
        local new_zoom_back_ratio = current_ratio*(1-value/10)

        if new_zoom_back_ratio>cfg.MAX_MIN_ZOOM_BACK_RATIO then
            new_zoom_back_ratio=cfg.MAX_MIN_ZOOM_BACK_RATIO
        elseif new_zoom_back_ratio*v.altitude <500 then
            new_zoom_back_ratio = 500/v.altitude
        end
        if current_ratio == new_zoom_back_ratio then
            return true
        end
        local new_zoom_back = v.altitude * new_zoom_back_ratio

        -- local new_zoomback = top_altitude*new_zoom_back_ratio
        if cfg.min_zoom_back_ratio then
            cfg.min_zoom_back_ratio = new_zoom_back_ratio
            UpdateOption('min_zoom_back_ratio',new_zoom_back_ratio)
        else
            cfg.min_zoom_back = new_zoom_back
            UpdateOption('min_zoom_back',new_zoom_back)
        end
        
        
        -- Echo("new_zoomback,min_zoom_back is ", new_zoomback,min_zoom_back)


        tooltip:Set('Pan View:\nZoom Back Ratio: ' .. format(new_zoom_back_ratio,3) .. '\nZoom Back: '..format(new_zoom_back,0)..' (Max: '..format(v.altitude * 0.95,3)..')')

        SetHeight(new_zoom_back)
        v.height_backup = new_zoom_back


        v.amp_mod = CalculateAmp(cfg.AMPLITUDE, cs.relHeight)
        spSetCameraState(cs._real or cs, cfg.smoothness)

    end
    return true
end

---------------
-- DRAWING
function widget:ViewResize(vsx, vsy)
    center_x,center_y = math.round(vsx/2), math.round(vsy/2 - 1)
    -- Echo("vsy,center_y is ", vsy,center_y)
end
local col_origin_noback = {0.2,0.2,0.9,0.6} -- dark blue
local col_origin_back = {0.6,0.6,1,1} -- brighter
local PI = math.pi
local HALFPI = PI/2
local RADperDEGREE = PI/180
local tan = math.tan
-- for Point Debugging
local glTranslate = gl.Translate
local glBillboard = gl.Billboard
local glVertex = gl.Vertex
local glPointSize = gl.PointSize
local glBeginEnd = gl.BeginEnd
local white = {1,1,1,1}
local GL_POINTS = GL.POINTS
local pointFunc = function(x,y,z)
    glVertex(x,y,z)
end
function widget:DrawWorld()
    if Points[1] then
        for i,p in ipairs(Points) do
            glColor(p.color or white)
            local x,y,z = unpack(p)
            if gl.txt then
                glPushMatrix()  
                glTranslate(x,y,z)
                glBillboard()
                glText(
                    type(p.txt) == 'string' and p.txt or i,
                    -3,
                    -3,
                    p.size or 10
                )
                glPopMatrix()
            else
                glPointSize(p.size or 7.0)
                glBeginEnd(GL_POINTS, pointFunc,x,y,z)
            end
        end
    end
    if not v.draw then
        return
    end
    local pos =  SafeTrace(center_x,center_y)
    if not pos then
        return
    end
    local currentFOVhalf_rad = (cs.fov/2) * RADperDEGREE
    local fovFactor = tan(currentFOVhalf_rad) * (45 / cs.fov)
    if cs.rx then
        fovFactor = fovFactor * (HALFPI/math.abs(cs.rx))
    end
    local x,z = pos[1], pos[3]
    -- local fovFactor =  1/2
    glPushMatrix()
    glColor(1,0.5,0.3,0.6)
    glLineWidth(1)
    glDrawGroundCircle(x, 0, z, 50, 40) 
    glLineStipple(true)
    glLineWidth(1.5)
    glDrawGroundCircle(x, 0, z, v.height_backup*fovFactor, 40) 
    glColor(1,1,1,0.3)
    glDrawGroundCircle(x, 0, z, v.height_backup*fovFactor, 40) 
    if cfg.use_origins then
        glLineWidth(2)
        for i,origin in ipairs(origins) do
            glColor(origin==origins.closest and col_origin_back or col_origin_noback)
            glDrawGroundCircle(origin.viewPos[1], 0, origin.viewPos[3], origin.relHeight*fovFactor, 40) 
        end
    end

    glLineStipple(true)
    glPopMatrix()
end
--
-- function widget:KeyPress(key,mods)
--     if key==261 and mods.alt then -- Alt + numpad 5
--         Echo('reloading PanView')
--         Spring.SendCommands('luaui disablewidget Pan View')
--         Spring.SendCommands('luaui enablewidget Pan View')
--         return true
--     end
-- end
-- remove the unit wrongly added
function widget:SelectionChanged(sel)
    local ret
    for i,id in ipairs(sel) do
        if id==unit then
            table.remove(sel,i)
            ret = sel
            break
        end
    end
    return ret, wh:RemoveWidgetCallIn("SelectionChanged", self)
    -- spSelectUnitArray(sel)
end
function widget:KeyRelease(key,mods)
    alt, ctrl,meta,shift = mods.alt, mods.ctrl, mods.meta, mods.shift
end

function WidgetInitNotify(w,name,preloading)
    if name == 'Chili Selections & CursorTip v2' then
        Tip_Widget = wh:FindWidget("Chili Selections & CursorTip v2")
    end
end
function WidgetRemoveNotify(w,name,preloading)
    if name == 'Chili Selections & CursorTip v2' then
        Tip_Widget = nil
    end

end

function widget:Initialize()
    GetUnitUnderCursor = WG.PreSelection_GetUnitUnderCursor
    Screen0 = WG.Chili.Screen0 
    tooltip:FindWin()
    v.altitude = top_altitude*cfg.altitude_ratio 
    v.circleHelper_height = v.altitude*cfg.circleHelper_ratio 
    if debugMe then
        -- local obj = f.DebugWinInit2(widget)
        -- DebugUp = obj.DebugUp
        -- local t = {A=5,B=6}
        -- obj:AttachTable(1,t)
        -- t.A = 7
        if WG.DebugCenter then
            local _
            widget.Log, widget.varDebug = WG.DebugCenter.Add(widget,{Log='Log',varDebug={'variables',v,'constants',cfg}})
        end
        -- local Log = widget.Log
        -- local spEcho = Echo
        -- Echo = function(...) Log(...) spEcho(...) end

    end
    Debug = f.CreateDebug(Debug,widget, options_path)
    wh = widgetHandler
    CalcMouseSpeedAverage = MakeAverageCalc(0.1)
    CalcMouseAngleAverage = MakeAverageCalc(0.1)
    CalcLagAverage = MakeAverageCalc(8)
    SmoothCam = wh:FindWidget("SmoothCam")
    Tip_Widget = wh:FindWidget("Chili Selections & CursorTip v2")
    wh:RemoveWidgetCallIn("SelectionChanged", self)
    --wh:RemoveWidgetCallIn("Update", self)
    wh:RemoveWidgetCallIn("DrawWorld", self)
    widget:ViewResize(wh:GetViewSizes())
    MakeStatsWindow = WG.MakeStatsWindow

    -- Echo('Pan View init v.altitude',v.altitude)
end

function widget:Shutdown()

    if Debug.Shutdown then
        Debug.Shutdown()
    end

    if widget.Log then
        widget.Log:Delete()
    end
    if widget.varDebug then
        widget.varDebug:Delete()
    end
    WG.panning=false
end

function widget:SetConfigData(data)
    if data.Debug then
        Debug.saved = data.Debug
    end
    -- if data.altitude_ratio then
    --     cfg.altitude_ratio=data.altitude_ratio
    --     cfg.min_zoom_back = data.min_zoom_back
    --     cfg.min_zoom_back_ratio = data.min_zoom_back_ratio

    -- end

end
function widget:GetConfigData()
    -- local standard = min(cfg.MAX_TOP_ALTITUDE, max(mapSizeX, mapSizeZ) * 5/3)
    -- if top_altitude>standard then
    --     cfg.altitude_ratio = min( 1, (cfg.altitude_ratio * top_altitude) / standard )
    -- end

    local ret = {
        -- altitude_ratio = cfg.altitude_ratio
        -- ,min_zoom_back =  cfg.min_zoom_back
        -- ,min_zoom_back_ratio = cfg.min_zoom_back_ratio
    }
    if Debug.GetSetting then
        ret.Debug = Debug.GetSetting()
    end
    return ret
end

f.DebugWidget(widget)