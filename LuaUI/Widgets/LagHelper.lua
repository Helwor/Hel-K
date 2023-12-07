function widget:GetInfo()
    return {
        name      = 'Lag Helper',
        desc      = 'try to reduce lag,replace moving keys',
        author    = 'Helwor',
        version   = 'v1',
        date      = 'mid 2021',
        license   = 'GNU GPL, v2 or later',
        layer     = math.huge,
        enabled   = false,
        handler   = true,
    }
end

local spGetModKeyState          = Spring.GetModKeyState
local spGetKeyState             = Spring.GetKeyState
local spGetCameraState          = Spring.GetCameraState
local spSetCameraState          = Spring.SetCameraState
local spGetCameraPosition       = Spring.GetCameraPosition
local spSetCameraTarget         = Spring.SetCameraTarget
local spTraceScreenRay          = Spring.TraceScreenRay
local spGetGroundHeight         = Spring.GetGroundHeight
local spWarpMouse               = Spring.WarpMouse
local spSendCommands            = Spring.SendCommands
local spGetActiveCommand        = Spring.GetActiveCommand
local spGetMouseState           = Spring.GetMouseState
local spSetMouseCursor          = Spring.SetMouseCursor
local spGetGameRulesParam       = Spring.GetGameRulesParam
local spGetGameFrame            = Spring.GetGameFrame
local spGetUnitDefID            = Spring.GetUnitDefID
local spSelectUnitArray         = Spring.SelectUnitArray
local spGetSelectedUnits        = Spring.GetSelectedUnits
local spGetGameSpeed            = Spring.GetGameSpeed


local spGetConfigInt            = Spring.GetConfigInt
local spSetConfigInt            = Spring.SetConfigInt

local glPushMatrix              = gl.PushMatrix
local glColor                   = gl.Color 
local glLineStipple             = gl.LineStipple
local glLineWidth               = gl.LineWidth
local glDrawGroundCircle        = gl.DrawGroundCircle
local glPopMatrix               = gl.PopMatrix

local escape_key -- fixing WG.enteringText misfunctionning, doesnt get falsified when hit escape key
local speedUp = false -- speed up process when toi level up when fps are really good

local debugging = false
local DebugUp = function() end
local f = debugging and VFS.Include('LuaUI\\Widgets\\UtilsFunc.lua')

local Colors = {
     white          = { 1.0,    1,    1, 1.0 },
     black          = { 0.0,    0,    0, 1.0 },
     grey           = { 0.5,  0.5,  0.5, 1.0 },
     red            = { 1.0, 0.25, 0.25, 1.0 },
     darkred        = { 0.8,    0,    0, 1.0 },
     lightred       = {   1,  0.6,  0.6, 1.0 },
     magenta        = { 1.0, 0.25,  0.3, 1.0 },
     rose           = { 1.0,  0.6,  0.6, 1.0 },
     bloodyorange   = { 1.0, 0.45,    0, 1.0 },
     orange         = { 1.0,  0.7,    0, 1.0 },
     darkgreen      = { 0.0,  0.6,    0, 1.0 },
     green          = { 0.0,    1,    0, 1.0 },
     lightgreen     = { 0.5,    1,  0.5, 1.0 },
     lime           = { 0.5,    1,    0, 1.0 },
     blue           = { 0.3, 0.35,    1, 1.0 },
     turquoise      = { 0.3,  0.7,    1, 1.0 },
     lightblue      = { 0.7,  0.7,    1, 1.0 },
     yellow         = { 1.0,    1,  0.3, 1.0 },
     cyan           = { 0.3,    1,    1, 1.0 },
     brown          = { 0.9, 0.75,  0.3, 1.0 },
     purple         = { 0.9,    0,  0.7, 1.0 },
     hardviolet     = { 1.0, 0.25,    1, 1.0 },
     violet         = { 1.0,  0.4,    1, 1.0 },
}

-- Game Progress variables
local behind = 0
local osclock = os.clock
local lastTime = osclock()
local lastServerFrame = 0
local lastUserFrame = spGetGameFrame()
local caughtUp = 0
local caughtUpPerSec = 0
local gameOver
--

function GetCameraHeight(cs)
    local height = cs.height

    if not height then
        local gy = spGetGroundHeight(cs.px,cs.pz)
        height = cs.py - gy
    end
    return height
end



local loadAll,unloadAll

local CalcAverageLag

local pan_speed -- not used for now

local Echo = Spring.Echo
local round,floor = math.round,math.floor
local average_lag = 0
local ups = 30
local time = 0
local cycles = 0
local checkReplayFrame
local cs = spGetCameraState()
----- CONFIG
-- if debbuging, loading/unloading all active widgets each one at this interval
local interval = 0.1

local switch_method = 'auto' -- set 'auto' for automatical switching by lag (see below) or 'manual' by using ALT+ up or down or false to disable
local time_check = 5 -- if switch_method is auto, time in seconds to update quality, this sequence of time might produce an upgrading or downgrading by one level
local down_threshold = 10 -- if auto the minimum update cycles per seconds we're accepting until we go down a level
local up_threshold = 14-- same for going back up, to avoid switching everytime up and down because of lag improvement, set a slightly higher value than down threshold

-- LEVEL OF QUALITY SETTING steps of downgrading quality to improve performance -- any missing or lower original setting will be dismissed
local USER_SETTINGS = {}
local levelCount = 0
local LEVELS = { --updated and back values completed by user original set at initialization
--   |param or widget   |setting    |name of config     |back_value toward user original setting, or none for original
    {'Shadows',               0,    'Shadows'                   },
    {'Projectile Lights',                                       },
    -- {'Units on Fire',                                           },
    {'HighlightUnit GL4',                                       },
    -- {'Depth of Field Shader',                                   },
    -- {'Unit Icons',                                              },
    -- {'UnitShapes',                                              },
    -- {'disticon',            150,    'UnitIconDist'              },
    -- {'Bloom Shader',                                            },
    {'Reclaim Field Highlight',                                 catchingUp = true },
    {'Infos On Icons',                                          catchingUp = true },
    -- {'MetalFeatures GL4',                                       },
    {'maxparticles',       3000,    'MaxParticles'              },
    {'maxnanoparticles',   3000,    'MaxNanoParticles'          },
    -- {'disticon',             85,    'UnitIconDist'      ,150    },
    {'Outline No Shader',                                       },
    -- {'State Icons',                                       },

    {'maxparticles',        200,    'MaxParticles'      ,3000   },
    {'maxnanoparticles',    200,    'MaxNanoParticles'  ,3000   },

    -- {'distdraw',            100,    'UnitLodDist'               }, -- very crappy appearance // since last engine it is read only

    {'advmodelshading',       0,    'AdvUnitShading'            },
    -- {'advmapshading',       0,    'AdvMapShading'            }, -- can be too bright (or too dark?) when disabled

    --{'distdraw',              0,    'UnitLodDist'       ,100    }, -- very crappy appearance // since last engine it is read only

    -- {'Smart Builders',                                          catchingUp = true},
    -- {'UnitsIDCard',                                             catchingUp = true},
    -- {'Draw Terra2',                                             catchingUp = true},

    ['current']=0, -- which level are we in


}


----- helper
 -- give an average of the lasts values, addcount can be float (for update delta time, in that case, number of table items can be great so think about it when setting the maxcount)
 -- chunk param is used when a great number of count can be expected and we want to reduce the size of the count table so we make little averages then register it as one count
local function MakeAverageCalc(maxcount,chunk)
    local n,count,total,values,counts = 0,0,0,{},{}
    local subcount,subtotal
    if chunk then
        subcount,subtotal = 0, 0
    end
    local remove = table.remove
    local function CalcAverage(value,addcount)
        if value=='reset' then
            n,count,total,values,counts = 0, 0, 0, {}, {}
            if chunk then
                subcount,subtotal = 0, 0
            end
            return
        end
        if chunk then
            subcount = subcount + addcount
            subtotal = subtotal + value
            if subcount>=chunk then
                value, addcount = subtotal, subcount
                subcount,subtotal = 0, 0
            else
                return (subtotal + total) / (count + subcount)
            end
        end

        count, total = count + addcount, total + value
        while count > maxcount and n > 0 do -- remove the oldest values when we are at max period
            total = total - remove(values,1)
            count = count - remove(counts,1)
            n = n - 1
        end
        n = n + 1
        counts[n], values[n] = addcount, value
        return total/count
    end
    return CalcAverage
end

local function FormatTime(num)
    local h, m, s = num>3599 and num/3600, (num%3600)/60, num%60
    if h then
        return ('%d:%02d:%02d'):format(h, m , s)
    end
    return ('%02d:%02d'):format(m, s)
end

function LEVELS:Down() -- going down and applying setting of that lower level (going down is going further in the array)
    if not self[self.current+1] then return end
    self.current=self.current+1
    local level = self[self.current]
    local param,value,configName = unpack(level)

    if not configName then -- param is a widget
        local conditionSet = not level.catchingUp or tonumber(behind) and behind>300
        if conditionSet then
            if widgetHandler:FindWidget(param) then
                Echo('Lag Helper remove widget '..param)
                -- widgetHandler:DisableWidget(param)
                widgetHandler:Sleep(param)
                -- DebugUp(param,widgetHandler:FindWidget(param))
            else
                Echo('Lag Helper didnt find widget '.. param)
                -- DebugUp(param,'widget not found')
            end
        end
    else
        spSetConfigInt(configName,value)
        spSendCommands(param..' '..value)

        DebugUp(param,value)
    end
    return true
end
function LEVELS:Up() -- applying back value of the current level then going up (going up is going toward the start of the array)
    if self.current==0 then return end
    local level = self[self.current]
    local param,_,configName,back_value = unpack(level)
    if not configName then -- param is a widget
        -- if not widgetHandler:FindWidget(param) then
        --     widgetHandler:EnableWidget(param)
        --     -- DebugUp(param,widgetHandler:FindWidget(param))
        -- end
        if widgetHandler:FindWidget(param) then
            widgetHandler:Wake(param)
        end
    else
        spSetConfigInt(configName,back_value)
        spSendCommands(param..' '..back_value)
        -- DebugUp(param,spGetConfigInt(configName))
    end
    self.current=self.current-1
    return true
end
function LEVELS:Setup()
    local i=1
    while self[i] do
        local level = self[i]
        local widget,springsetting
        local setting, value, configName = unpack(level)
        
        if not configName then  -- it's a widget, we register it if it is enabled
            --[[Echo('remove',setting,'no configname or the widget doesnt exist')--]]
            if widgetHandler:FindWidget(setting) then
                USER_SETTINGS[setting] = true
                levelCount = levelCount + 1
                -- DebugUp(setting,true)
            else
                table.remove(self,i) i=i-1 -- it's a widget or a setting that didnt get registered in Initialize we remove the corresponding LEVEL
            end
        else
            local origValue = spGetConfigInt(configName)
            if origValue then
                -- it is a spring setting
                USER_SETTINGS[setting] = origValue
                --[[Echo('it is a spring setting: ',configName)--]]
                -- Echo("setting,origValue, value is ", setting,origValue, value)
                if origValue <= value then
                    -- Echo(setting,'of user is already lower or equal',origValue,'vs',value)
                    table.remove(self,i) i=i-1 -- this LEVEL is useless the default setting is already lower or equal
                else
                    DebugUp(setting,origValue)
                    levelCount = levelCount + 1
                    --[[Echo('origValue is ',origValue,'level has back value?', level[4])--]]
                    local back_value = level[4] -- the back value that will be applied when going back to higher LEVEL
                    -- back_value is either meant to be the final user setting or a step toward it, if it has already a value set in auto execute section.
                    -- if that's the latter, it must not be above original origValue
                    if not back_value or back_value>origValue then
                        --[[Echo('fix back value',origValue, ' to level')--]]
                        -- the back value is useless, original value is lower or equal
                        level[4]=origValue
                    end
                end
            else
                table.remove(self,i) i=i-1
            end
        end
        level.catchingUp = not not level.catchingUp
        i=i+1
    end
end

---------------------------------------------------------------------------------------
--

--- Getting panning Keys
local keys,combo = {},{0,0}
include('keysym.lua')
local _, ToKeysyms = include('Configs/integral_menu_special_keys.lua')
local function HotkeyChangeNotification()
    keys = {}

    local key = WG.crude.GetHotkeyRaw('moveleft')
    local keycode = ToKeysyms(key and key[1])
    if keycode then keys[keycode] = {-1,0} end

    key = WG.crude.GetHotkeyRaw('moveright')
    keycode = ToKeysyms(key and key[1])
    if keycode then keys[keycode] = {1,0} end

    key = WG.crude.GetHotkeyRaw('moveforward')
    keycode = ToKeysyms(key and key[1])
    if keycode then keys[keycode] = {0,1} end

    key = WG.crude.GetHotkeyRaw('moveback')
    keycode = ToKeysyms(key and key[1])
    if keycode then keys[keycode] = {0,-1} end
end
----
--------------------------

local panning
local x,z = 0,0
local speedFactor = 100
-- for panning with game frame
local clock = os.clock
local upd_time = 0
local gf_time = clock()
local newtime
local paused,switch_to_GF
local target_frame
local fps=0

--
local min_setting

local catchingUpStart = false

local function MeasureLatency(serverFrame)
    local userFrame = spGetGameFrame()
    behind = serverFrame-userFrame
    caughtUp = (userFrame-lastUserFrame)-(serverFrame-lastServerFrame)
    local time = osclock()
    caughtUpPerSec = (caughtUp/30) / (time-lastTime)
    if behind>300 then
        if not catchingUpStart then
            catchingUpStart = {time=time,userFrame=userFrame,serverFrame=serverFrame}
        end
        -- Echo('user is '..behind..' frames(' .. ('%.1f'):format(behind/30) .. ' seconds) behind the game')
        -- Echo('in '..('%.1f'):format(time-lastTime)..'seconds, user caught up '..caughtUp..' frames(' .. ('%.1f'):format(caughtUp/30) .. ' seconds)')
    elseif catchingUpStart then
        local totalFrames = serverFrame-catchingUpStart.userFrame
        Echo('Caught Up ~=' .. FormatTime(totalFrames/30) .. ' in ' .. FormatTime(osclock()-catchingUpStart.time) )
        catchingUpStart = false
    end
    lastTime = time
    lastServerFrame = serverFrame
    lastUserFrame = userFrame
end

local r_pairs = function(t)
    local keys, n  = {}, 0
    for k,v in pairs(t) do
        n = n + 1
        keys[n] = k
    end
    local i = n + 1
    return function()
        i = i - 1
        local key = keys[i]
        return key, t[key]
    end
end
local noUnload = {
    [widget:GetInfo().name] = true
    ,['Chili Pro Console'] = true
    ,['Chili Integral Menu'] = true
    ,['Chili Rejoigning Progress Bar'] = true
    ,['Chili Widget Selector'] = true
    ,['Chili Framework'] = true
    ,['Context Menu'] = true
    ,['Font Cache'] = true
}
local noLoad = {
    ['BlobShadow'] = true
}



local totaldt = 0
local dtcount = 0
local average_lag = 0
local lastavglag = 0
local lagdelta = 0
local action

local totalCaughtUpPerSec = 0
local avgCaughtUpPerSec = 0
local caughtUpCount = 0
local caughtUpDelta = 0
local lastAvgCaughtUpPerSec = 0
--
local levelChanged = false
local cs = Spring.GetCameraState()
local lastpx,lastpz = cs.px,cs.pz

---*** TEST 1***
local testFrameSkip = false
local lastFrameInUpdate = spGetGameFrame()
local echoUpd = clock()
---*** TEST 1***

function widget:Update(dt,forced)
---*** TEST 1***
    if testFrameSkip and not forced then
        local userWantedSpeed, speed = spGetGameSpeed()
        local laggingBehind = userWantedSpeed<speed*0.9
        local frame = spGetGameFrame()
        local msg
        local time = clock()
        if laggingBehind then
            -- the sim of the game goes too slow compared to the server speed
            msg = 'user is lagging behind'
        else
            if frame-lastFrameInUpdate>4 then
                -- the display update has skipped frames either because, it can be because user is rejoining, but it can also be because the drawing is too heavy to finish a frame in time
                -- Update/DrawWorld/DrawScreen ... tells us the real fps the user is watching
                msg = 'game is catching up'
            else
                -- msg = 'game is at time'
            end
        end
        if msg and time-echoUpd > 1 then
            Echo(msg,frame-lastFrameInUpdate)
            echoUpd=time
        end
        lastFrameInUpdate = frame
    end
---*** TEST 1***

    -- local cs =  Spring.GetCameraState()
    -- Spring.SetCameraState(cs,0)
    -- DebugUp('pz',math.round(math.abs(lastpz-cs.pz)))
    -- DebugUp('px',math.round(math.abs(lastpx-cs.px)))
    -- local dirx = lastpx-cs.px
    -- local sign = dirx>0 and 1 or -1
    -- cs.px = lastpx - math.min(math.abs(dirx),100)*sign
    -- Spring.SetCameraState(cs,0.50)
    -- Spring.SetCameraState(cs,1)
    
    -- lastpx, lastpz = cs.px, cs.pz
    -- Echo(GetCameraHeight(cs))
    if not forced and dt>1 then
        -- this is not usual and is probably due to some setting change/load we don't count it
        return
    end
    local skipMeasure = forced or levelChanged or dt > 0.8
    if levelChanged then -- since the last engine version we experience some noticeable freeze on level change that can fuck up the result so we ignore this cycle
        if debugging then
            Echo('On '.. levelChanged ..' level changed => ',dt,'( average lag: '..average_lag..')')
        end
        levelChanged = false
    end

    if not skipMeasure then
        average_lag = CalcAverageLag(dt,1) -- new stuff
        totaldt = totaldt + dt
        dtcount = dtcount +1
        speedUp = average_lag < 1/45 -- 45 fps we speed up the level up
        totalCaughtUpPerSec = totalCaughtUpPerSec + caughtUpPerSec
        caughtUpCount = caughtUpCount + 1

        if totaldt >= interval then

            avgCaughtUpPerSec = totalCaughtUpPerSec / caughtUpCount
            caughtUpDelta = avgCaughtUpPerSec - lastAvgCaughtUpPerSec
            lastAvgCaughtUpPerSec = avgCaughtUpPerSec
            caughtUpCount, totalCaughtUpPerSec = 0, 0


            lagdelta = average_lag - lastavglag
            lastavglag = average_lag
            dtcount, totaldt = 0, 0
            if action then
                -- Echo('last action was '..action, ' resulted in delta average_lag of ',lagdelta, 'caughtUpDelta is ',caughtUpDelta)
                Echo('last action was '..action, ' current Lag ',average_lag,'('..lagdelta..')', 'current CatchUpPerSec ',caughtUpPerSec,'('..caughtUpDelta..')')
                action = false
            end
            -- Echo("lagdelta ", lagdelta,'CaughtUp Delta is ',caughtUpDelta)
        end

    end


    -- measure average_lag and update setting


    if debugging then
        if dtcount == 0 then

            if unloadAll then
                unloadAll = false
                if WG.ActiveList then
                    for w_name in pairs(WG.ActiveList) do
                        if not noUnload[w_name] and not w_name:match('^Chili') and widgetHandler:FindWidget(w_name) then
                            -- Echo('Unloading '..w_name)
                            Spring.SendCommands("luaui disablewidget "..w_name)
                            action = 'Unloading '..w_name
                            unloadAll = true
                            noLoad[w_name] = false
                            if debugging then
                                -- DebugUp(w_name,'false')
                            end
                            break
                        end

                    end
                end
            elseif loadAll and dtcount == 0 then
                loadAll = false
                if WG.ActiveList then
                    for w_name in r_pairs(WG.ActiveList) do
                        if not noLoad[w_name] and not widgetHandler:FindWidget(w_name) then
                            -- Echo('Loading '..w_name)
                            local ret = Spring.SendCommands("luaui enablewidget "..w_name)
                            action = 'Loading '..w_name
                            loadAll = true
                            if debugging then
                                -- DebugUp(w_name,'true')
                            end
                            noLoad[w_name] = true
                            break
                        end
                    end
                end
            end
        end
    end




    if not skipMeasure  and switch_method=='auto' then
        cycles,time = cycles+1,time+dt
        if speedUp and time >= 1 or time>time_check then
            -- average_lag = time/cycles


            -- ups = cycles/time -- ups = update per sec
            ups = 1/average_lag
            -- Echo("average_lag,ups is ", average_lag,ups)
            -- Echo('ups: '..(round(ups,3)),'('..(round(average_lag,3))..')', 'fps: '..fps)
            if ups < 1 then Echo('lag > 1 sec, garbage:',collectgarbage('count') ) end
            time,cycles = 0,0
            -- f.Page(Spring,'play')
            if gameOver then
                MeasureLatency(lastServerFrame)
            end
            if isReplay then
                behind = false
                local this_frame = spGetGameFrame()
                if checkReplayFrame ~= this_frame then
                    local userSpeed, serverSpeed = Spring.GetGameSpeed()
                    behind = userSpeed>serverSpeed*1.1

                    -- if behind then
                    --     Echo('user is below the game speed wanted')
                    -- end
                end
                checkReplayFrame = this_frame
            end
            -- if true then
            --     return
            -- end
            if ups<down_threshold or behind and (behind==true or behind>300) then
                levelChanged = LEVELS:Down() and -1
            elseif ups>up_threshold then
                levelChanged = LEVELS:Up() and 1
            end
        end
    end
    --Echo('paused is ', paused)
    if not panning then return end
    -- switcher to Game Frame when laggy
    if not paused and average_lag>0.1 and not forced then
        if not switch_to_GF then switch_to_GF=true gf_time=clock() end
        return
    end
    -----------------------------------------
    -- panning if lag is ok or if it has been forced by KeyPress
    if switch_to_GF then switch_to_GF = false end
    local cs = spGetCameraState()
    local speed = speedFactor * GetCameraHeight(cs)/2000 * (1+dt*2)
    -- panning slightly more when forced
    if forced then
        speed = speed/2
    elseif panning<0.02 then
        if dt<0.02 then 
            speed=speed/3 
            panning=panning+dt --[[Echo('slow',panning)--]] 
        else
            panning=0.02
        end
    end
    local flip = -cs.flipped
    cs.px = cs.px + (speed * flip * x * pan_speed/30)
    cs.pz = cs.pz + (speed * flip * -z * pan_speed/30)

    -- spSetCameraState(cs, dt)
    spSetCameraState(cs, 0)
end
local function FormatTime(num)
    local h, m, s = num>3599 and num/3600, (num%3600)/60, num%60
    if h then
        return ('%d:%02d:%02d'):format(h, m , s)
    end
    return ('%02d:%02d'):format(m, s)
end

function widget:GameProgress(serverFrame) -- called every 150 game frame
    -- Echo("serverFrame is ", serverFrame,FormatTime(serverFrame/30))
    MeasureLatency(serverFrame)
end
function widget:GameOver(winners)
    gameOver = true
end

--local average_lag = 0
function widget:GamePaused(_,status)
    paused = status
end

function widget:GameStart()
    widgetHandler:UpdateWidgetCallIn('Update',widget)
end


-- frame per sec variable
local fps_time=clock()
local fps_frame = spGetGameFrame()




function widget:GameFrame(gf)
    local current_time = clock()

    lastFrame = gf
    -- measuring frame per sec that has nothing to do with the actual frame per sec we can watch, those can rather be estimated via Update delta, since it represent drawing cycles too
    -- measuring fps every 5 sec
    if current_time-fps_time>=5 then
        fps=(gf-fps_frame)/(current_time-fps_time)
        -- Echo('fps '..(round(fps,3)))
        fps_time = current_time
        fps_frame = gf
    end
    --

    if not (switch_to_GF and panning) then return end
    -- panning with GF is temporarily removed


    -- game frame has faster rate, we can move the view more responsively here // <- temporarily removed
    if not target_frame then
        newtime=clock()
        local diff = newtime-gf_time
        if diff>0.01 then target_frame=gf else target_frame = gf+round(0.01/diff) end
    end
    if gf>=target_frame then
        local cs = spGetCameraState()
        local flip = -cs.flipped
        local speed = speedFactor * GetCameraHeight(cs)/2000 * 0.50
        cs.px = cs.px + (speed * flip * x)
        cs.pz = cs.pz + (speed * flip * -z)
        spSetCameraState(cs, 0.25)
        target_frame=false
        gf_time=clock()
    end
end

function widget:SetConfigData(data)
    if data.ActiveList then
        WG.ActiveList = data.ActiveList
    end
end
function widget:GetConfigData()
    if WG.ActiveList and next(WG.ActiveList) then
        return {ActiveList = WG.ActiveList}
    --Echo("noDraw is "
    end
end
local switchWidget = function(name)
    local find = widgetHandler:FindWidget('Terraform Icon Draw')
    Spring.SendCommands('luaui '..(find and 'dis' or 'en')..'ablewidget '..name)

end
function widget:KeyPress(key,mods,isRepeat) 
    -- if mods.alt and key == 263 then -- alt + numpad 7
    --     local widgets = {}
    --     for name in pairs(widgetHandler.knownWidgets) do
    --         if widgetHandler:FindWidget(name) then
    --             widgets[name] = true
    --         end
    --     end
    --     WG.ActiveList = widgets
    -- end
-- Echo("Spring.GetHasLag ( ) is ", Spring.GetHasLag ( ))
-- return: bool hasLag
-- Echo("Spring.GetFrameTimer ( true--[[[ bool lastFrameTime ]--]] ) is ", Spring.GetFrameTimer ( true--[[[ bool lastFrameTime ]--]] ))
-- Echo(" is ", Spring.DiffTimers(   Spring.GetTimer(), Spring.GetFrameTimer ( --[[true--]]--[[[ bool lastFrameTime ]--]] ) ) )
-- return: timer
-- Get a timer for the start of the frame, this should give better results for camera interpolations. If given an optional boolean true, then it returns the game->lastFrameTime instead of the lastFrameStart

    if debugging then
        if mods.alt and key == 266 then -- alt + kp '.'
            switchWidget('Terraform Icon Draw')
        end
        if mods.alt and key == 256 then -- alt + 0
            if widgetHandler:FindWidget('Chili Framework') then
                Spring.SendCommands('luaui disablewidget Chili Framework')
            end
        end
        -- reload any Chili
        if mods.alt and key == 257 then -- alt + 1
            if WG.ActiveList and next(WG.ActiveList) then
                Spring.SendCommands('luaui enablewidget Chili Framework')
                for name in pairs(WG.ActiveList) do
                    if name:match('^Chili') then
                        Spring.SendCommands('luaui enablewidget '.. name)
                    end
                end
            end
        end
        if mods.alt and key == 258 then -- alt + 2 -- remake list
            local list, count = {}, 0
            for w_name in pairs(widgetHandler.knownWidgets) do
                if widgetHandler:FindWidget(w_name) then
                    list[w_name] = true
                    count = count + 1 
                end
            end
            Echo('Active list remade ('..count..')')
            WG.ActiveList = list
        end
        if mods.alt and key == 264 then -- alt + numpad 8
            unloadAll = not unloadAll
            if unloadAll then
                loadAll = false
            end
        end
        if mods.alt and key == 265 then -- alt + numpad 9
            loadAll = not loadAll
            if loadAll then
                unloadAll = false
            end
        end
    end



    local move = keys[key]
    -- alt + up/down go level up or down manually
    if mods.alt and move then
        if move[2]==1 then LEVELS:Up()
        elseif move[2]==-1 then LEVELS:Down()
        end
        return true
    end
    if move and switch_to_GF then
        -- temporarily removed
        -- if not isRepeat then
        --     x,z = x+move[1],z+move[2]
        --     if not panning then panning = 0 end
        --     -- forcing an update round to get quicker response if it's laggy
        --     if average_lag>0.1 then --[[Echo('send update')--]] widget:Update(average_lag,'forced') end
        -- end
        
        -- return true
    end
--[[    if key==53 and mods.alt and not isRepeat then -- ALT + 5 reload the widget
        spSendCommands('luaui disablewidget Lag Helper')
        spSendCommands('luaui enablewidget Lag Helper')
    end--]]
end
function widget:KeyRelease(key,mods)
     -- fixing WG.enteringText that doesnt update on escape key press
    if WG.enteringText then
        if key==escape_key then WG.enteringText=false end
        return
    end
    --
    if mods.alt then return end
    local move = keys[key]
    if move  then
        -- temporarily removed
        -- x,z = x-move[1],z-move[2]
        -- if x==0 and z==0 then
        --     panning=false
        -- end
        -- return true
    end
end
local function switch(Config,setting,val1,val2)
    if spGetConfigInt(Config)==val1 then
        Spring.SendCommands(setting..' '..val2)
        spSetConfigInt(Config,val2)
    else
        Spring.SendCommands(setting..' '..val1)
        spSetConfigInt(Config,val1)
    end
end


--- Drawing
local glColor = gl.Color
local fhDraw = fontHandler.Draw
local font = "LuaUI/Fonts/FreeSansBoldWOutline_14"
local UseFont = fontHandler.UseFont
local vsx,vsy
local green,yellow,red = Colors.green,Colors.yellow,Colors.red
function widget:GetViewSizes(new_vsx,new_vsy)
    vsx, vsy = new_vsx, new_vsy
end
function widget:DrawScreen()
    -- glColor(1,1,0,1) -- yellow
    UseFont(font)
    fhDraw( ('%.2f'):format(average_lag)..'('..LEVELS.current..'/'..levelCount..')', vsx-60, vsy-90)
    if tonumber(behind) and behind>300 then
        local s = caughtUp>=0 and '+' or ''
        glColor(caughtUp<0 and red or caughtUp<1 and yellow or green)
        fhDraw('>> '..s ..('%.1f'):format(caughtUpPerSec), vsx-50, vsy-104)
        if gameOver then
            glColor(1,1,1,1)
            fhDraw('Game Over', vsx-100, vsy-140)
        end
    end
    glColor(1,1,1,1)
end
-----
-- Updating the LEVELS to give it default value and remove useless index (non existent widget or default setting lower or equal)
function widget:Initialize()
    if Spring.GetGameFrame() <1 then
        widgetHandler:RemoveWidgetCallIn('Update',widget)
    end
    -- CalcAverageLag = f.MakeAverageCalc(8)
    if debugging then
        DebugUp = f.DebugWinInit(widget)
        if WG.ActiveList then -- now using Debug window for other purpose
            -- for name in pairs(WG.ActiveList) do
            --     DebugUp(name,(widgetHandler:FindWidget(name)))
            -- end
        end
    end
    paused = select(3,Spring.GetGameSpeed())
    isReplay = Spring.IsReplay()
    CalcAverageLag = MakeAverageCalc(30)
    escape_key = KEYSYMS.ESCAPE
    HotkeyChangeNotification()
    _,_,paused = Spring.GetGameSpeed()
    widget:GetViewSizes(Spring.GetViewSizes())
    pan_speed = spGetConfigInt('CamFreeScrollSpeed') -- FIXME need to take any camera mode into account

    -- set the fallback user settings

    --Unit_Range_widget = widgetHandler:FindWidget('Show selected unit range') -- this would need to add option to not show when too many units are selected
    --USER_SETTINGS['Show selected unit range']=widgetHandler:FindWidget('Show selected unit range') and true or nil
    --Echo("'maxnanoparticles' is ", spGetConfigInt('MaxNanoParticles'),USER_SETTINGS['maxnanoparticles'])
    
    --
    --USER_SETTINGS['grounddecals'] = spGetConfigInt('GroundDecals') -- don't seems to do a noticeable improvement

    --USER_SETTINGS['shadow_detail'] = spGetConfigInt('ShadowMapSize') -- possible values: 512, 1024, 2048, 4096, 8192, 16384 --2048 is nice enough, however not needed, doesnt change really anything in term of lag
    --USER_SETTINGS['GroundDetail'] = spGetConfigInt('GroundDetail')--don't see any difference

    --spSetConfigInt('SmoothLines',1)
    ---------------------------------

--[[    Spring.SendCommands('maxparticles 12000')
    spSetConfigInt('MaxParticles',22000)
    Spring.SendCommands('maxnanoparticles 12000')
    spSetConfigInt('MaxNanoParticles',22000)
    Spring.SendCommands('advmodelshading 1')
    spSetConfigInt('AdvUnitShading',1)
    Spring.SendCommands('disticon 125')
    spSetConfigInt('UnitIconDist',125)
    Spring.SendCommands('Shadows 1')
    spSetConfigInt('Shadows',1)
    Spring.SendCommands('distdraw 10000')
    spSetConfigInt('UnitLodDist',10000)--]]
    --Spring.SendCommands('GroundDetail 4')
    -----------------------------

    --switch('UnitLodDist','distdraw',1,10000)
    --switch('AdvUnitShading','advmodelshading',1,0)
    --switch('AdvUnitShading','advmodelshading',1,0)
    --switch('Shadows','Shadows',0,1)
    --switch('UnitIconDist','disticon',100,30)

    --widget:GamePaused()
    LEVELS:Setup()
end
function widget:Shutdown()
    while LEVELS:Up() do end
end

