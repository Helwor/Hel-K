

function widget:GetInfo()
    return {
        name      = "Time Out",
        desc      = "A simple handler to execute func on delay and/or for a defined time",
        author    = "Helwor",
        date      = "April 2023",
        license   = "GNU GPL, v2",
        layer     = -math.huge, 
        enabled   = true,  --  loaded by default?
        handler   = true,
        api       = true,
    }
end
local Echo                          = Spring.Echo
-- local f = VFS.Include("LuaUI\\Widgets\\UtilsFunc.lua")


local todo,n = {},0
local time = os.clock()

function widget:Update(dt)
    local off = 0
    for i=1,n do
        local obj = todo[i + off]
        local delete
        if obj.when>0 then
            obj.when = obj.when - dt
        else
            if obj.howLong then
                if obj.howLong < 0 then
                    delete = true
                else
                    obj.howLong = obj.howLong - dt
                    obj.func()
                end
            else
                obj.func()
            end
        end
        if delete then
            table.remove(todo,i+off)
            n, off = n - 1, off - 1
        end
    end

end
WG.todo = todo
WG.TimeOut = function(func,when,howLong) -- when: 0 = immediately; howLong: 0 = once, false/nil = forever, number = time
    n = n + 1

    todo[n] = {
        func = func,
        when = when,
        howLong = howLong
    }
end
-- f.DebugWidget(widget)
function widget:Shutdown()
    WG.todo = {}
end