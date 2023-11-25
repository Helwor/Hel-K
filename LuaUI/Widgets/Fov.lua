local versionNumber = "0.5"

function widget:GetInfo()
    return {
        name      = "FOV",
        desc      = "add Fov option for basic camera",
        author    = "Helwor",
        date      = "Jan 2023",
        license   = "GNU GPL, v2 or later",
        layer     = 1003, -- after COFC
        handler   = true,
        enabled   = true,
    }
end
local Echo = Spring.Echo

local spGetConfigInt = Spring.GetConfigInt
local spSetConfigInt = Spring.SetConfigInt
local spGetCameraState = Spring.GetCameraState
local spSetCameraState = Spring.SetCameraState
local spSendCommands = Spring.SendCommands
local spGetGroundHeight = Spring.GetGroundHeight
local spGetViewGeometry = Spring.GetViewGeometry
local spTraceScreenRay = Spring.TraceScreenRay
local spForceTesselationUpdate = Spring.ForceTesselationUpdate
local COFCName = 'Combo Overhead/Free Camera (experimental)'
local Cam = WG.Cam
local COFC
local recover

options = {}
local options = options -- avoid little freeze  when accessing global options?

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
    return pos
end

local AdaptDist -- adapt distance from cam pos to center view when changing FOV, in order to not feel the change of distance
do
    local spTraceScreenRay = Spring.TraceScreenRay
    -- local spGetCameraFOV = Spring.GetCameraFOV
    local spGetViewGeometry = Spring.GetViewGeometry
    local spSetCameraState = Spring.SetCameraState
    local PI = math.pi
    local HALFPI = PI/2
    local RADperDEGREE = PI/180
    local tan = math.tan

    -- cs.relHeight = height
    -- height = height * (45/cs.fov)
    -- if cs.mode == 4 then
    --     local dist = height - cs.height
    --     cs.px = cs.px + dist * -cs.dx
    --     cs.py = cs.py + dist * -cs.dy
    --     cs.pz = cs.pz + dist * -cs.dz
    -- end
    -- cs.height = height


    AdaptDist = function(cs, newFov)
        cs = cs or spGetCameraState()

        -- cs.px,cs.py,cs.pz = Spring.GetCameraPosition()
        if cs.mode == 4 then
            local vsx, vsy = spGetViewGeometry()
            local pos =  SafeTrace(vsx/2,vsy/2-1)
            if not pos then
                return
            end
            local dist = ((cs.px-pos[1])^2 + (cs.py-pos[2])^2 + (cs.pz-pos[3])^2)^0.5
            -- ensure cs got the correct direction -- (COFC might be the culprit here)
            cs.dx,cs.dy,cs.dz = 
                (pos[1]-cs.px) / dist,
                (pos[2]-cs.py) / dist,
                (pos[3]-cs.pz) / dist
            --
            local newdist = dist  * cs.fov / newFov
            -- set the new cam pos
            cs.px = pos[1] + newdist * -cs.dx
            cs.py = pos[2] + newdist * -cs.dy
            cs.pz = pos[3] + newdist * -cs.dz
        else
            -- ez
            cs.height = cs.height * cs.fov / newFov
        end
        cs.fov = newFov
        return cs
    end
end

local AdaptDetail = function(thisvalue, fov)
    if not options.adapt_detail.value then
        return thisvalue
    end
    local ratio = 45 / fov
    local fovPow = options.fovpow.value
    -- relvalue = thisvalue * ratio ^fovPow
    return thisvalue * ratio^fovPow
end

local GetDistTarget = function()
    local cs = spGetCameraState()
    local dist,relDist
    -- cs.px,cs.py,cs.pz = Spring.GetCameraPosition()
    if cs.mode == 4 then
        local vsx, vsy = spGetViewGeometry()
        local pos =  SafeTrace(vsx/2,vsy/2-1)
        if not pos then
            return
        end
        dist = ((cs.px-pos[1])^2 + (cs.py-pos[2])^2 + (cs.pz-pos[3])^2)^0.5
    else
        -- ez
        dist = cs.height
    end
    relDist = dist * cs.fov / 45
    return dist, relDist
end

local function AdjustCOFCfov(value)
    if not COFC then
        return
    end
    local COFCfov = COFC.options.fov
    if COFCfov.value~=value then
        COFCfov.value = value
        COFCfov:OnChange()
    else
        -- Echo('COFC has already been set this value')
    end
end
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
local cnt= 0
local last_cs = spGetCameraState()
-- function widget:Update(dt)
--     cnt = cnt + dt

--     if cnt>=0.5 then
--         local cs = spGetCameraState()
--         if cs.mode==1 and cs.height ~= last_cs.height or cs.mode==4 and cs.py~=last_cs.py then
--             spSendCommands('GroundDetail ' .. Spring.GetConfigInt('GroundDetail')+1)
--             spSendCommands('GroundDetail ' .. Spring.GetConfigInt('GroundDetail'))
--         end
--         last_cs = cs
--         cnt=0
--     end
--     -- local dist,relDist = GetDistTarget()
--     -- Echo('DIST:', dist,relDist,('%.1f'):format(dist/relDist*100)..'%','ratio12K:'..('%.2f'):format(dist/12000 * 100)..'%')
-- end

local cnt = 0
local spGetCameraVectors = Spring.GetCameraVectors
local spGetCameraFOV = Spring.GetCameraFOV
local spGetTimer = Spring.GetTimer
local spDiffTimers = Spring.DiffTimers
local lastDist = 0


-- old workaround to update the tesselation
    -- function widget:Update(dt)
    --     if WG.EzSelecting or not WG.panning and widgetHandler.mouseOwner then
    --         return
    --     end
    --     if not recover then
    --         local cs = Cam.state
    --         -- if cs.mode==1 and cs.height ~= last_cs.height or cs.mode==4 and cs.py~=last_cs.py then

    --         if math.abs(Cam.dist - lastDist)>lastDist*0.05 then
    --             lastDist = Cam.dist
    --             -- -- Echo("cs.py-last_cs.py is ", cs.py-last_cs.py)
    --             -- -- Echo('WHEEL SET DETAIL',options.map_detail.value+1)
    --             -- local detail = AdaptDetail(options.map_detail.value-1, Cam.fov)
    --             -- -- Echo('set detail ',detail)
    --             local time = spGetTimer()
    --             -- spSendCommands('GroundDetail ' .. detail)
    --             -- time = spDiffTimers(spGetTimer(), time)
    --             Spring.ForceTesselationUpdate(true, true)
    --             if time > 0.15 then
    --                 Echo('tesselation update took more than 0.15 sec',  ('%.2f'):format(time))
    --                 -- Echo('set detail -1 took more than 0.15 sec',  ('%.2f'):format(time))
    --             end
    --             -- recover = true
    --             -- cnt = WG.panning and -0.2 or 0
    --         end
    --         last_cs = cs
    --     end
    --     if recover then
    --         -- if cnt>0.05 then
    --         if cnt>0.20 then
    --             local detail = AdaptDetail(options.map_detail.value, Cam.fov)
    --             -- Echo('UPDATE RECOVER DETAIL',detail,'(' .. options.map_detail.value .. ') fov:' .. Cam.fov)
    --             local time = spGetTimer()
    --             spSendCommands('GroundDetail ' .. detail)
    --             time = spDiffTimers(spGetTimer(), time)
    --             if time > 0.15 then
    --                 Echo('set detail 0 took more than 0.15 sec', ('%.2f'):format(time))
    --             end

    --             cnt = 0
    --             recover = false
    --         end
    --         cnt = cnt + dt
    --     end
    -- end
--

function widget:Update(dt)
    if WG.EzSelecting or not WG.panning and widgetHandler.mouseOwner then
        return
    end
    if not recover then
        if math.abs(Cam.dist - lastDist)>lastDist*0.05 then
            lastDist = Cam.dist
            local time = spGetTimer()
            spForceTesselationUpdate(true, true)
            time = spDiffTimers(spGetTimer(), time)
            if time > 0.15 then
                Echo('tesselation update took more than 0.15 sec',  ('%.2f'):format(time))
            end
        end
    end
end


local baseDistIcon = 130
--------------------------------------------------------------------------------
----------------------------Configuration---------------------------------------

local DetectAndRefreshPanel


local PI = math.pi
local HALFPI = PI/2
local RADperDEGREE = PI/180
local tan = math.tan
local function GetFovFactor(fov)
    local currentFOVhalf_rad = (fov/2) * RADperDEGREE
    local fovFactor = tan(currentFOVhalf_rad) * (45 / fov)
    return fovFactor
end


options_path = ''
options_order = { 'feature_dist','fovpow','fov','wire_map','map_drawer','adapt_detail','switch_wire','map_detail','shadows','dist_icon','gccontrol','maxzoomout' }

options.feature_dist = {
        name = 'Feature Distance',
        desc = 'How far are features drawn',
        type = "number",
        value = 3000,
        min = 0,
        max = 50000,
        step = 50,
        noHotkey = true,
        update_on_the_fly = true,
        OnChange = function(self)
            -- spSendCommands('FeatureDrawDistance ' .. self.value)
            -- spSendCommands('FeatureFadeDistance ' .. self.value/3)
            spSetConfigInt('FeatureDrawDistance', self.value)
            spSetConfigInt('FeatureFadeDistance', self.value/2)
            -- return self.value
        end,
        -- tooltip_format = '%.2f'
    }

options.fovpow = { -- hidden option, dont touch or retain the best value before
        name = 'FOV Power',
        desc = 'Exponent to correct the FOV ratio applied to map detail',
        type = "number",
        value = 0.85, -- what I recommend
        min = 0.25,
        max = 1.5,
        step = 0.01,
        noHotkey = true,
        update_on_the_fly = true,
        OnChange = function(self)
            if options.adapt_detail.value then
                options.map_detail:OnChange()
            end
            -- return self.value
        end,
        hidden = true,
        -- tooltip_format = '%.2f'
    }
options.fov = {
        name = 'Field Of View',
        type = "number",
        value = Spring.GetCameraFOV(),
        min = 10,
        max = 100,
        step = 1,
        simpleMode = true,
        everyMode = true,
        tooltipFunction = function(self)
            local cs = spGetCameraState()
            -- Echo('setting FOV',self.value)
            if cs.fov~=self.value then
                AdaptDist(cs, self.value)
                cs.fov = self.value
                spSetCameraState(cs, 0)
            end
            local newDistIcon = baseDistIcon * 45/cs.fov
            spSetConfigInt('UnitIconDist', newDistIcon)
            spSendCommands('disticon '..newDistIcon)
            -- the quality vary depending on camera height and camera height vary depending on FOV, so we adjust
            options.map_detail:OnChange()

            return self.value
        end,
        OnChange = function(self)
            local cs = spGetCameraState()
            if cs.fov~=self.value then
                AdaptDist(cs, self.value)
                cs.fov = self.value
                spSetCameraState(cs, 0)
                -- local newDistIcon = baseDistIcon * 45/cs.fov
                -- spSetConfigInt('UnitIconDist', newDistIcon)
                -- spSendCommands('disticon '..newDistIcon)
            end
            options.map_detail:OnChange()
            options.dist_icon:OnChange()
            AdjustCOFCfov(self.value)
        end
    }

options.wire_map = {
        name = 'Wire Map',
        desc = 'Enable Wire Map to appreciate the level of detail of Map Meshes.',
        type = 'bool',
        value = false,
        OnChange = function(self)
            spSendCommands('WireMap ' .. (self.value and 1 or 0)) -- actually there is no value to give, it just switch wire map view --
        end,
        hidden = true,
    }
options.map_drawer = {
        name = 'Map Mesh Drawer',
        desc = 'Choose your way of processing map mesh',
        type = "radioButton",
        value = 2,
        items = {
            {key = 0,        name='GCM'},
            -- {key = 1,        name='HLOD'},
            {key = 2,        name='ROAM'},
        },
        OnChange = function(self)
            spSendCommands('MapMeshDrawer ' .. self.value)
            spSetConfigInt('MapMeshDrawer', self.value)
            options.map_detail:OnChange()
            -- local newDistIcon = 255 - cs.fov * 2
            -- local newDistIcon = 165 * 45/cs.fov
        end,
        noHotkey = true,
        hidden = true,
    }
options.adapt_detail =  {
        name = 'Adapt Detail by FOV',
        desc = 'Adapt detail depending on FOV',
        type = 'bool',
        value = true,
        hidden = true,
    }
options.switch_wire = {
        name = 'Switch Wire On Change',
        desc = 'Enable Wire Map when changing map detail.',
        type = 'bool',
        value = true,
        hidden = true,
    }

options.map_detail = {
        name = 'Map Detail',
        desc = 'How well is defined the map mesh',
        type = "number",
        value = 50,
        min = 0,
        max = 200,
        step = 1,
        -- update_on_the_fly = true,
        tooltipFunction = function(self)
            if options.switch_wire.value and self.state.hovered and not options.wire_map.value then
                options.wire_map.value = true
                options.wire_map:OnChange()
                options.map_detail.wireSwitched = true
                -- local hovered = WG.Chili.Screen0.hoveredControl
                -- Echo("hovered is ", hovered, hovered and hovered.caption,self.state.hovered, self.caption, hovered==self)
            end
            -- if not options.wire_map.value then
            --     options.wire_map.value = true
            --     options.wire_map:OnChange()
            -- end
            local thisvalue = AdaptDetail(self.value, spGetCameraState().fov)
            if options.map_drawer.value ~= 2 then
                thisvalue = thisvalue/(self.max/7)
            end

            -- Echo("options.adapt_detail is ", options.adapt_detail.value)
            -- Echo('TOOLTIP SET GROUND DETAIL',thisvalue)
            spSendCommands('GroundDetail ' ..thisvalue)
            -- spSetConfigInt('GroundDetail ', relvalue)
            recover = false 
            return math.round(self.value)
        end,
        OnChange = function(self)
            if self.wireSwitched then
            -- if options.wire_map.value then
                options.wire_map.value = false
                options.wire_map:OnChange()
                self.wireSwitched = false
            end

            local thisvalue = AdaptDetail(self.value, spGetCameraState().fov)
            if options.map_drawer.value ~= 2 then
                thisvalue = thisvalue/(self.max/7)
            end

            -- Echo('SET GROUND DETAIL',thisvalue,'('.. self.value .. ')', spGetCameraState().fov)
            spSendCommands('GroundDetail ' .. thisvalue)
            spSetConfigInt('GroundDetail ', thisvalue)
            recover = false
        end,
        noHotkey = true,
    }
options.dist_icon = {
        name = 'Dist Icon',
        type = "number",
        value = baseDistIcon,
        min = 1,
        max = 250,
        step = 1,
        simpleMode = true,
        everyMode = true,
        tooltipFunction = function(self)
            local fov = spGetCameraState().fov
            baseDistIcon = self.value
            local newDistIcon = baseDistIcon * 45/fov
            spSetConfigInt('UnitIconDist', newDistIcon)
            spSendCommands('disticon '..newDistIcon)

            return self.value
        end,
        OnChange = function(self)

            -- local fov = Spring.GetCameraFOV()
            local fov = spGetCameraState().fov
            baseDistIcon = self.value
            local newDistIcon = baseDistIcon * 45/fov
            spSetConfigInt('UnitIconDist', newDistIcon)
            spSendCommands('disticon '..newDistIcon)
        end
    }
options.gccontrol = {
        name = 'GC Control',
        desc = 'Garbage Collector rate 1/frame (0) or 30/sec (1)',
        type = "number",
        value = 0,
        min = 0,
        max = 1,
        step = 1,
        simpleMode = true,
        everyMode = true,
        tooltipFunction = function(self)
            return (self.value == 0 and '1/frame' or '30/sec')
        end,
        OnChange = function(self)
            spSetConfigInt('LuaGCControl', self.value)
            spSendCommands('LuaGCControl '..self.value)
        end
    }
options.shadows = {
        name = 'Shadows',
        -- must be updated/update into the code, must adapt to FOV change
        desc = 'Set shadows',
        type = 'number',
        min = 0, max = 4, step = 1,
        value = 1,
        update_on_the_fly = true,
        tooltipFunction = function(self)
            -- -- for reference
            -- local m = self.value%8
            -- local state = 
            --     self.value == 0 and 'none' or
            --     m < 2 and 'all' or --(1)
            --     (m < 4) and 'unit shadow' or --(2-3)
            --     (m < 6) and 'terrain shadow' or --(4-5)
            --     (m < 8) and 'model lighting only' -- (6-7)
            -- --
            local v = self.value
            local state =
                v == 0 and 'disabled' or
                v == 1 and 'model lighting only' or
                v == 2 and 'unit shadow' or 
                v == 3 and 'terrain shadow' or
                v == 4 and 'all shadows'

            return state
        end,
        OnChange = function(self)
            local v = self.value
            local param =
                v == 0 and 0 or 
                v == 1 and 6 or --(6 or 7)
                v == 2 and 2 or --(2 or 3)
                v == 3 and 4 or --(4 or 5)
                v == 4 and 1
            spSendCommands('Shadows ' .. param)
            spSetConfigInt('Shadows', param)
        end,
    }
options.maxzoomout = {
        name = 'Max Zoom Out',
        -- must be updated/update into the code, must adapt to FOV change
        desc = '% of the map fitting screen',
        type = 'number',
        min = 0.5, max = 3, step = 0.01,
        value = 1,
        tooltipFunction = function(self)
            -- FIX EPIC MENU it doesn't show 2 digits when above 1
            return ('%.2f'):format(self.value)
        end,
        OnChange = function(self)
        end,
    }



local origCOFCFovOnChange

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
    DetectAndRefreshPanel = function(optons_path)
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
local LinkOptions, UnlinkOptions
do
    local backups = {}
    LinkOptions = function(option1,option2)
        local oriOnChange1 = option1.OnChange
        local oriOnChange2 = option2.OnChange
        backups[option1] = oriOnChange1
        backups[option2] = oriOnChange2

        option1.OnChange = function(self)
            if option2.value~=self.value then
                option2.value = self.value
                if oriOnChange2 then
                    oriOnChange2(option2)
                end
            end
            return oriOnChange1 and oriOnChange1(self)
        end

        option2.OnChange = function(self)
            if option1.value~=self.value then
                option1.value = self.value
                if oriOnChange1 then
                    oriOnChange1(option1)
                end
            end
            return oriOnChange2 and oriOnChange2(self)
        end
    end
    UnlinkOptions = function(option1,option2)
        option1.OnChange = backups[option1]
        backups[option1] = nil
        option2.OnChange = backups[option2]
        backups[option2] = nil

    end
end

function WidgetInitNotify(w,name,preloading)
    if preloading then
        return
    end
    if name == COFCName then
        widget:Initialize()
        options.fov:OnChange()

    end
end


function WidgetRemoveNotify(w,name,preloading)
    if COFC and name == COFCName then
        -- Echo('COFC is getting removed',COFC.options.maxzoomout)
        UnlinkOptions(COFC.options.maxzoomout,options.maxzoomout)
        COFC = nil
        origCOFCFovOnChange = nil
        options.fov:OnChange()
        options.maxzoomout.hidden = true
        DetectAndRefreshPanel(options_path)
    end
end
function widget:Initialize()
    Cam = WG.Cam
    origCOFCFovOnChange = nil
    COFC = widgetHandler:FindWidget(COFCName)
    local COFCfov = COFC and COFC.options.fov
    if COFCfov then
        origCOFCFovOnChange = COFCfov.OnChange
        COFCfov.OnChange = function(self)
            if self.value~=options.fov.value then
                options.fov.value = self.value
                -- Echo('triggering FOV change from COFC',self.value)
                options.fov:OnChange()
            end
            return origCOFCFovOnChange(self)
        end

        LinkOptions(COFC.options.maxzoomout,options.maxzoomout)
        options.maxzoomout.hidden = false
    else
        
        options.maxzoomout.hidden = true
    end
    DetectAndRefreshPanel(options_path)
    if WG.MyClicks then
        WG.MyClicks.callbacks.AfterMouseWheel = WG.MyClicks.callbacks.AfterMouseWheel or {}
        WG.MyClicks.callbacks.AfterMouseWheel[widget:GetInfo().name]=AfterMouseWheel
    end
end
function widget:Shutdown()
    if origCOFCFovOnChange then
        local COFC = widgetHandler:FindWidget(COFCName)
        if COFC then
            COFC.options.fov.OnChange = origCOFCFovOnChange
            UnlinkOptions(COFC.options.maxzoomout,options.maxzoomout)
        end
    end
    if WG.MyClicks then
        WG.MyClicks.callbacks.AfterMouseWheel[widget:GetInfo().name]=nil
    end
end