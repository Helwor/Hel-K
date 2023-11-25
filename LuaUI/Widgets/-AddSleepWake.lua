function widget:GetInfo()
    return {
        name      = "Add Sleep/WakeUp",-- Add Sleep Wake must be called '-AddSleepWake.lua' in order to be loaded firstly and before '-OnWidgetState.lua'
        desc      = "Add Sleep and WakeUp call to widgetHandler, switching all callins of a widget",
        author    = "Helwor",
        date      = "April 2023",
        license   = "GNU GPL, v2",
        layer     = -10e38, 
        handler   = true,
        enabled   = true,
        api       = true,
    }
end
local Echo = Spring.Echo

local function GetRealHandler()
    local i, n = 0, true
    while n do
        i=i+1
        n,v=debug.getupvalue(widgetHandler.RemoveCallIn, i)
        if n=='self' and type(v)=='table' and v.LoadWidget then
            return v
        end
    end
end

widgetHandler = GetRealHandler()
if not widgetHandler then
    return false
end
local EMPTY_TABLE = {}

function widgetHandler:Sleep(w,exception)
    exception = exception or EMPTY_TABLE
    if type(w) == 'string' then
        w = widgetHandler:FindWidget(w)
    end
    if not w then return false end
    if w.isSleeping then
        return 
    end
    for k,v in pairs(w) do
        if type(k)=='string' and type(v)=='function' then
            if not exception[k] and self[k .. 'List'] then
                self:RemoveWidgetCallIn(k,w)
            end
        end
    end
    Echo(w.whInfo.name .. ' has been put to sleep.')
    w.isSleeping = true
    return w
end
function widgetHandler:Wake(w,exception)
    exception = exception or EMPTY_TABLE
    if type(w) == 'string' then
        w = widgetHandler:FindWidget(w)
    end
    if not w then return false end
    if not w.isSleeping then
        return 
    end
    for k,v in pairs(w) do
        if type(k)=='string' and type(v)=='function' then
            if not exception[k] and self[k .. 'List'] then
                self:UpdateWidgetCallIn(k,w)
            end
        end
    end
    Echo(w.whInfo.name .. ' has woken.')
    w.isSleeping = false
    return w
end
return false