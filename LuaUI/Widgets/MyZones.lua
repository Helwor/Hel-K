function widget:GetInfo()
    return {
        name      = 'MyZones',
        desc      = 'callin for screen interactions',
        author    = 'Helwor',
        date      = 'Winter, 2021',
        license   = 'GNU GPL, v2 or later',
        layer     = -1000001, -- after custom formation 2 to register upvalues of it, then Lowering in Initialize
        enabled   = true,
        handler   = true,
    }
end
WG.MyZones = WG.MyZones or {}
local widgets = WG.MyZones

local Echo = Spring.Echo

function widget:MousePress(mx,my,button)
    for w,zones in pairs(widgets) do
        --for k,v in pairs(t) do Echo(k,v) end
        for i,zone in ipairs(zones) do
            if mx>zone.x and mx<zone.x2 and my>zone.y and my<zone.y2 then
                if zones.ci(zone,mx,my,button) then return true end
            end
        end
    end
end

function widget:Initialize()
    widgetHandler:LowerWidget(self)
end

function widget:Shutdown()
    for w in pairs(widgets) do widgets[w]=nil end
end
