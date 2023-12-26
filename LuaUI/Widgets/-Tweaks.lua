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
    name      = "Tweaks",
    desc      = "bag of tweaks",
    author    = "Helwor",
    date      = "august 2023",
    license   = "GNU GPL, v2 or later",
    layer     = -math.huge, 
    enabled   = true,  --  loaded by default?
    handler   = true,
    api       = true
  }
end

-- debug vars in a window

-- speeds up
local oldSpSetActiveCommand = Spring.SetActiveCommand



local spGetActiveCommand = Spring.GetActiveCommand
local spSetSelectionBoxByEngine = Spring.SetSelectionBoxByEngine
local spIsSelectionBoxActive = Spring.IsSelectionBoxActive
local Echo = Spring.Echo

local spGetGameSeconds = Spring.GetGameSeconds
local spGetActiveCommand = Spring.GetActiveCommand
local spGetMouseState = Spring.GetMouseState
local spGetModKeyState   = Spring.GetModKeyState
local osclock = os.clock
local traceback = debug.traceback
local concat = table.concat

include('keysym.h.lua')
local KEYSYMS = KEYSYMS
local UnitDefs = UnitDefs
local maxUnits = Game.maxUnits
local CMD_RAW_MOVE = 31109
local f = VFS.Include('LuaUI\\Widgets\\UtilsFunc.lua')


local blastwingDefID = UnitDefNames['gunshipbomb'].id

function widget:CommandNotify(cmd,params,opts)
    if cmd == CMD_RAW_MOVE then
        -- if not params[4] then
        --     params[4], params[5] = 8,0.05
        -- end
        -- Echo('unpack(params',unpack(params))
    end
end

function widget:UnitCommand(id,defid,team,cmd,params)
    -- Echo("id,defid,cmd,params is ", id,defid,team,cmd,unpack(params))
end


-- disable the selection box until we travel some distance with the mouse
-- local single_selecting = false
-- local box_select = false
-- local boxX, boxY = 0, 0
-- local POINT_SEL_LEEWAY = 150
-- local selTravel = 0
-- local Screen0
-- function widget:MousePress(mx, my, button)
--     if not Screen0 then
--         Screen0 = WG.Chili and WG.Chili.Screen0
--         if not Screen0 then
--             return
--         end
--     end
--     if button == 1 and not Screen0:IsAbove(mx,my) and  spGetActiveCommand() == 0 then
--         Echo('single selecting', os.clock())
--         single_selecting  = true
--         selTravel = 0
--         boxX, boxY = mx, my
        
--     end
--     -- 
-- end
-- function widget:Update(dt)
--     if single_selecting then
--         local mx, my, lmb, mmb, rmb, outsideSpring = spGetMouseState()
--         if not lmb or rmb or outsideSpring then
--             single_selecting = false
--             selTravel = 0
--             if selbox_disabled then
--                 Echo('reenable sel box')
--                 Spring.SetBoxSelectionByEngine(true, false)
--                 selbox_disabled = false
--             end
--             Echo('end single selecting', os.clock())

--         elseif not WG.PreSelection_IsSelectionBoxActive() then
--             -- skip
--         else
--             selTravel = selTravel + ((mx - boxX)^2 + (my - boxY)^2)^0.5
--             boxX, boxY = mx, my
--             if selTravel > POINT_SEL_LEEWAY then
--                 single_selecting = false
--                 selTravel = 0
--                 if selbox_disabled then
--                     Echo('reenable sel box')
--                     Spring.SetBoxSelectionByEngine(true, false)
--                     selbox_disabled = false
--                 end
--                 Echo('end single selecting', os.clock())
--             elseif not selbox_disabled then
--                 Echo('disable sel box')
--                 selbox_disabled = true
--                 Spring.SetBoxSelectionByEngine(false, false)
--             end
--         end    
--     end
-- end



---- debugging when spSetActiveCommand is getting spammed, except when it is from build commmand ------
local format = string.format

do -- detect ActiveCommand Spam
    local time = osclock()
    local count = 0
    local txt = ''

    function Spring.SetActiveCommand(n, line)
        line = line or ''
        local now = osclock()
        local comID, num, cmd, comname
        local ignore = true
        if now - time  < 0.05 then
            count = count + 1
            comID, cmd, num,  comname = spGetActiveCommand()
            -- plate is spammed from vanilla ZK when using the plate hotkey/button until the cursor is in the area around the given fac (maybe some dirty code ?)
            ignore = cmd and cmd < 0 or comname == 'plate'
        end
        if not ignore then
            -- local cur = select(4,Spring.GetActiveCommand())
            local cur
            if comname then
                cur = concat({comID, cmd, num, comname}, ', ')
            else
                cur = comID
            end

            txt = txt .. '\n' .. 'interval: ' .. now - time .. ' wanted Acom: ' .. n .. 'current: ' .. cur
                -- .. '\n' .. traceback():sub(1,30)
            if count > 5 then 
                Echo(traceback())
                Echo('SetActiveCommand Getting spammed !', txt)
                Echo('game time:', spGetGameSeconds())
                count = 0
                txt = ''
            end
        else
            count = 0
            txt = ''
        end
        time = now
        return oldSpSetActiveCommand(n)
    end
end

local FormatTime = function(n)
    local h = math.floor(n/3600)
    h = h>0 and h
    local m = math.floor( (n%3600) / 60 )
    m = (h or m>0) and m
    local s = ('%.3f'):format(n%60)
    return (h and h .. ':' or '') .. (m and m .. ':' or '') .. s
end
local AComHistory = {}
do -- register history
    local time = osclock()
    local count = 0
    function Spring.SetActiveCommand(n)
        local shift = select(4,spGetModKeyState())
        local txt = concat({FormatTime(spGetGameSeconds())
            ,n or 'nil'
            ,shift and 'shift is held' or 'no shift'
            ,'current command : ' .. tostring(spGetActiveCommand())
            ,debug.traceback()}, '\n')
        if count == 10 then
            table.remove(AComHistory,1)
        else
            count = count + 1
        end
        AComHistory[count] = txt
        return oldSpSetActiveCommand(n)
    end
end

function widget:KeyPress(key,mods, isRepeat)
    if key == 105 and mods.alt then -- alt + i
        if AComHistory[1] then
            local len = #AComHistory
            Echo('debug Acom',FormatTime(spGetGameSeconds())) 
            for i=math.max(len-10,1), len do
                Echo(AComHistory[i])
                Echo('------')
            end
        end
    end
end
-- function widget:DefaultCommand(type, id, engineCmd)
--     Echo(type,id, engineCmd,"spGetActiveCommand() is ", spGetActiveCommand())

-- end
function widget:Shutdown()
    Spring.SetActiveCommand = oldSpSetActiveCommand
end


f.DebugWidget(widget)