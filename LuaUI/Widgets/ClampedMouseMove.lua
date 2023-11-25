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
    name      = "Clamped Mouse Move",
    desc      = "Tool to Clamp the mouse click inside the world map",
    author    = "Helwor",
    date      = "8 Sept 2022",
    license   = "GNU GPL, v2 or later",
    layer     = 1000001, -- after CF2
    enabled   = true,  --  loaded by default?
    handler   = true,
  }
end
-- speeds up
local Echo = Spring.Echo

local Screen0
local spGetSelectedUnitsCount = Spring.GetSelectedUnitsCount
local selected = spGetSelectedUnitsCount()


local ClampScreenPosToWorld
WG.ClampScreenPosToWorld = false
local ReplaceMouseMove
local OriCF2MouseMove
local floor, round, huge, abs, max = math.floor, math.round, math.huge, math.abs, math.max
local round = function(x)
    return tonumber(round(x))
end


local f = VFS.Include('LuaUI\\Widgets\\UtilsFunc.lua')

function widget:CommandsChanged()
    selected = spGetSelectedUnitsCount()
end

function ReplaceMouseMove(w,mx,my,dx,dy,button)
    local _mx, _my = ClampScreenPosToWorld(mx,my)
    return OriCF2MouseMove(w,_mx or mx,_my or my,dx,dy,button)
end
function ReplaceMousePress(w,mx,my,button)
    local _mx, _my
    if selected>0 and not Screen0:IsAbove(mx,my) then
        _mx, _my = ClampScreenPosToWorld(mx,my)
        cmdOverride = CMD_RAW_MOVE
    end
    -- Spring.WarpMouse(_mx or mx,_my or my)
    return OriCF2MousePress(w,_mx or mx,_my or my,button)
end

do
    local spWorldToScreenCoords = Spring.WorldToScreenCoords
    local mapSizeX, mapSizeZ = Game.mapSizeX,Game.mapSizeZ
    local spTraceScreenRay = Spring.TraceScreenRay
    local spGetGroundHeight = Spring.GetGroundHeight
    local clamp = function(x,z,off)
        local off = off or 1
        if x>mapSizeX - off then
            x=mapSizeX - off
        elseif x<off then
            x=off
        end

        if z>mapSizeZ - off then
            z=mapSizeZ - off
        elseif z<off then
            z=off
        end
        return x,z
    end
    local function process(center,height)
        -- local newY = math.max(center[5] - height, 0)
        local newY = center[5] - height
        local mx, my = spWorldToScreenCoords(center[4],newY,center[6])
        local center2 = {center[4],newY,center[6]}
        local _,test = spTraceScreenRay(mx,my,true,true,true,false)
        if not test then
            return
        end
        for i=1,3 do table.remove(test,1) end

        test[1], test[3] = clamp(test[1],test[3],24)
        test[2] = spGetGroundHeight(test[1],test[3])
        return mx,my,test, center2
    end
    ClampScreenPosToWorld = function (mx,my)
        if not mx then
            mx, my = spGetMouseState()
        end
        local center2,center3,center4
        local nature,center
        nature,center = spTraceScreenRay(mx,my,true,true,true,false)
        if not center then
            return mx, my
         end
        local center2 = {center[4],center[5],center[6]}
        -- when mouse fall into the sky
        -- we use the coord from the sky, but the trace goes to 0 height
        -- which will offset when clamping back to map bounds and map height
        -- to avoid this we reask mouse pos from that sky position but lowered by the groundheight of this position
        -- then we reask the world sky version from this new screen pos that will give us a negative offset of the world pos that will be reoffsetted when clamped
        -- debugging
        -- local cx,cy,cz,c2x,c2y,c2z = unpack(center)
        -- local height = spGetGroundHeight(center[4],center[6])
        -- Echo(nature .. ' : ' .. round(cx),round(cy),round(cz) .. '   |   ' .. round(c2x),round(c2y),round(c2z) .. '| height: '.. round(height))
        --
        if nature == 'sky' then
            local test
            local height, newY

            height = spGetGroundHeight(center[4],center[6])
            mx,my,test = process(center,height)
            if not test then
                return
            end
            local correct = abs(height - test[2]) > abs(height/2)
             -- Echo("math.abs(height - test[2]) is ", math.abs(height - test[2]))
            -- Echo("newY,'vs',test[2] is ", height,'vs',test[2],'correct',correct,(height + test[2]) / 2)
            correct = true
            if correct then
                height = (height + test[2]) / 2
                mx,my,test = process(center,height)
                if not test then
                    return
                end

            end
            center[1], center[2], center[3] = test[1], test[2], test[3]
            mx, my = spWorldToScreenCoords(unpack(center)) 
            -- nature,center = spTraceScreenRay(mx,my,true,true,false,false)
            -- if not center then
            --     return
            -- end

        end
        -- Echo("h,h2 is ", h,h2)
        return mx,my, center, center2, center3, center4
    end
    WG.ClampScreenPosToWorld = ClampScreenPosToWorld
end


local CF2
function widget:Initialize()
    Screen0 = WG.Chili.Screen0
    if not Screen0 then
        widgetHandler:RemoveWidget(self)
        return
    end
    if Spring.GetSpectatingState() then
        widgetHandler:RemoveWidget(self)
        return
    end
    CF2 = widgetHandler:FindWidget('CustomFormations2')

    if CF2 then
        OriCF2MouseMove = CF2.MouseMove
        CF2.MouseMove = ReplaceMouseMove
        OriCF2MousePress = CF2.MousePress
        CF2.MousePress = ReplaceMousePress
    end
    WG.ClampScreenPosToWorld = ClampScreenPosToWorld
    widget:CommandsChanged()
end


function widget:Shutdown()
    if CF2 and OriCF2MouseMove then
        CF2.MouseMove = OriCF2MouseMove
    end
    if CF2 and OriCF2MousePress then
        CF2.MousePress = OriCF2MousePress
    end
end

f.DebugWidget(widget)