
function widget:GetInfo()
    return {
        name      = "OnWidgetState",
        desc      = "Home made CallIn to get triggered when a widget change state (load, init, activated, deactivated)",
        author    = "Helwor",
        date      = "April 2023",
        license   = "GNU GPL, v2",
        layer     = -math.huge + 1, 
        handler   = true,
        enabled   = true,
        api       = true,
    }
end
-- NOTE: unless rewriting cawidgets.lua there is no way to get this widget to be loaded first (it use VFS.DirList result as order and virtual files come first, then local widgets)
    -- to make that widget gettling loaded first among local widget, you need to put a dash or double A (caps) at first in the file name
local Echo = Spring.Echo

local debugging = false
local Log
-- Echo("VFS.DirList is ", VFS.DirList,LUAUI_DIRNAME .. 'Config/ZK_order.lua')
local t = VFS.DirList(LUAUI_DIRNAME .. 'Widgets/', "*.lua", VFSMODE)
local f = VFS.Include("LuaUI\\Widgets\\UtilsFunc.lua")

-- local path = 
    -- local chunk, err = loadfile(ORDER_FILENAME)
    -- if (chunk == nil) then
    --     self.orderList = {} -- safety
    --     return {}
    -- else
    --     local tmp = {}
    --     setfenv(chunk, tmp)
    --     self.orderList = chunk()
    --     if (not self.orderList) then
    --         self.orderList = {} -- safety
    --     end
options_path = 'Settings/On Widget State'
options_order = {'debug','log',--[['test'--]]}
options = {
    -- test = {
    --     name = 'Invert zoom',
    --     desc = 'Invert the scroll wheel direction for zooming.',
    --     type = 'bool',
    --     value = true,
    --     noHotkey = true,
    -- },
    debug = {
        name = 'Debug', -- NOTE: until gui epic menu is loaded, options aren't taken into account
        type = 'bool',
        value = debugging,
        OnChange = function(self) debugging = self.value end,
        noHotkey = true,
    },
    log = {
        name = 'Log',
        type = 'bool',
        value = false,
        OnChange = function(self)
            if self.value then
                if WG.LogHandler and WG.Chili then
                    Log = WG.LogHandler:New(widget)
                    Log:ToggleWin()
                    Echo = function(...) Log(...) Spring.Echo(...) end
                else
                    self.value = false
                    self:OnChange()
                end
            elseif Log then
                Log:Delete()
                Log = nil
                Echo = Spring.Echo
            end
        end,
        noHotkey = true,
    }
}

local sig = '[' .. widget:GetInfo().name .. ']: '
local debugSig = sig:sub(1,-2) .. '[dbg]: '

local Debug = function (...)
    if not debugging then
        return
    end
    local args = {...}
    args[1] = debugSig ..  tostring(args[1])
    return Echo(unpack(args)) or true

end

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


Debug(widget:GetInfo().name .. ' IS LOADING and ' .. (widgetHandler.LoadWidget and 'have ' or "DOESN'T HAVE ") ..  'WH LoadWidget callin.')

-- getting to know if we're at widgetHandler initialization
local WHInitPhase = widgetHandler.LoadWidget and not widgetHandler.knownWidgets[widget:GetInfo().name]
Debug('WH INIT PHASE is ' .. (not widgetHandler.LoadWidget and 'UNKNOWN' or WHInitPhase and 'TRUE' or 'FALSE'))
local WHoriginalNames = {
    'LoadWidget',
    'FinalizeWidget',
    'InsertWidget',
    'RemoveWidget',
    'Sleep',
    'Wake',
}
local callback_lists = {
    WidgetInitNotify=true,
    WidgetLoadNotify=true,
    WidgetRemoveNotify=true,
    WidgetSleepNotify=true,
    WidgetWakeNotify=true,

    -- can extends the list to more nuanced callins if needed
}

for funcName in pairs(callback_lists) do
    widget[funcName] = {}
end
-- memorizing who got callbacks to remove then when they shutdown
local callbackOwners = {}
-- when widgetHandler init phase is over, we send callbacks on Initialize one update round after it happens to let widgetHandler finish his work
--, in case the widget receiving the call in want to load another widget
local call_later = {}

local function Init(arg)
    local callin = WHoriginalNames[1]
    if not widgetHandler.LoadWidget then
        widgetHandler = GetRealHandler() or widgetHandler
    end
    -- if not oriLoadWidget and widgetHandler.LoadWidget then
    if not widget['ori' .. callin] and widgetHandler.LoadWidget then
        local problem
        for i,callin in ipairs(WHoriginalNames) do
            -- some may have been modified by EPIC menu, we find and change the original
            local original_callin = widgetHandler['Original' .. callin] and 'Original' .. callin or callin
            if widgetHandler[original_callin] then
                widget['ori' .. callin] = widgetHandler[original_callin]
                widgetHandler[original_callin] = widget['wh' .. callin]
                -- Echo('HOOKING ' .. tostring(original_callin), widget['wh' .. callin])
            else
                problem = true
                Debug('>>> PROBLEM, no ' .. tostring(original_callin) .. ' found in widgetHanlder ! <<<<')
            end
        end
        if not problem then
            Debug('widgetHandler callins successfully changed by ' .. widget:GetInfo().name .. ' at ' .. (arg or 'config') .. ' step')
        else
            Echo(sig .. "PROBLEM, change made at" .. (arg or 'config') .. " step but some widgetHandler's callins hasn't beed found !")
        end
    end
    -- end

end
local function Restore(arg)
    local callin = WHoriginalNames[1]
    if widget['ori' .. callin] then
        for i,callin in ipairs(WHoriginalNames) do
            -- some may have been modified by EPIC menu, we find and change the original
            local original_callin = widgetHandler['Original' .. callin] and 'Original' .. callin or callin
            widgetHandler[original_callin] = widget['ori' .. callin]
            widget['ori' .. callin] = nil
        end
        Debug('widgetHandler callins successfully restored by ' .. widget:GetInfo().name .. ' from ' .. arg)
    end
    
end

local function RegisterCallbacks(w,name)
    if callbackOwners[name] then
        return
    end
    local hasCallback
    for funcName in pairs(callback_lists) do
        local callback = w[funcName]
        if callback then
            hasCallBack = true
            Debug('registered ' .. name .. ', owner of callback ' .. funcName )
            widget[funcName][callback] = true
        end
    end
    if hasCallBack then
        callbackOwners[name] = true
    end
end
local function RemoveCallbacks(w,name)
    if not callbackOwners[name] then
        return
    end
    for funcName in pairs(callback_lists) do
        local callback = w[funcName]
        local cblist = widget[funcName]
        if callback and cblist[callback] then
            Debug('unregistering callback ' .. funcName .. ' of ' .. name)
            cblist[callback] = nil
        end
    end
    callbackOwners[name] = nil
end


function whSleep(wh,w,exception)
    local name = type(w) == 'string' and w
    w = oriSleep(wh,w,exception)
    if w then
        if not name then 
            name = w.whInfo.name
        end
        for cb in pairs(WidgetSleepNotify) do
            cb(w,name,WHInitPhase)
        end
    end
    return ret
end
function whWake(wh,w,exception)
    local name = type(w) == 'string' and w
    w = oriWake(wh,w,exception)
    if w then
        if not name then 
            name = w.whInfo.name
        end
        for cb in pairs(WidgetWakeNotify) do
            cb(w,name,WHInitPhase)
        end
    end
    return ret
end
-- Loading
local newwidget


function whLoadWidget(wh,filename, _VFSMODE)
    newwidget = nil
    local w = oriLoadWidget(wh,filename, _VFSMODE) 
    local thiswidget = newwidget
    newwidget = nil
    if w == widget then
        return w
    end
    local suffix = (WHInitPhase and ' (PRELOADING).' or '.')
    if w then
        local name = w.whInfo.name or w.whInfo.basename
        Debug(name .. ' has been loaded and is active' .. suffix )
        --- add callbacks of that widget if we find any
        RegisterCallbacks(w,name)
        ---
        for cb in pairs(WidgetLoadNotify) do
            cb(w,name,WHInitPhase)
        end
    elseif thiswidget  and debugging then
        local name = thiswidget.whInfo.name or thiswidget.whInfo.basename
        local ki = widgetHandler.knownWidgets[name]
        if not (ki and ki.active) then
            local err = widgetHandler:ValidateWidget(thiswidget)
            if err then
                Debug(name .. ' has been loaded but is inactive due to ' .. err .. suffix)
            else
                -- set inactive
                Debug(name .. ' has been loaded but is inactive' .. suffix)
            end
        else
            -- duplicate name or no GetInfo
            Debug(name .. ' has been loaded but dismissed' .. suffix)
        end
    elseif debugging then
        -- missing file or wrong code or crash or silent death
        Debug(filename .. ' has crashed at loading (or self ended)' .. suffix)
    end
    return w
end
function whFinalizeWidget(wh,widget, filename, basename)
    newwidget = widget
    return oriFinalizeWidget(wh,widget, filename, basename) 
end
--

-- Initializing
function whInsertWidget(wh,w)
    local ret = oriInsertWidget(wh,w) -- there is no return, but who knows the future
    if w then
        if w == widget then
            return ret
        end
        local suffix = WHInitPhase and ' (INIT).' or '.'
        local name = w.whInfo.name or w.whInfo.basename
        local active = widgetHandler.knownWidgets[name].active
        if not active then
            Debug(name .. ' has been removed on initialization' .. suffix)    
        else
            Debug(name .. ' has been initialized' .. suffix)
            if not WHInitPhase then -- we let one update cycle happen before sending the callback when not in init phase
                table.insert(call_later, function() 
                    for cb in pairs(WidgetInitNotify) do
                        cb(w,name, WHInitPhase)
                    end

                end)
                widgetHandler:UpdateWidgetCallIn('Update',widget)
            else
                for cb in pairs(WidgetInitNotify) do
                    cb(w,name, WHInitPhase)
                end
            end

            -- when a new widget is initialized, we check if it has some of our callbacks and register them, unless that has been done at load time
            RegisterCallbacks(w,name)
            -- --
        end
    end
    return ret
end

-- removing
function whRemoveWidget(wh,w)
    if w == widget then
        Restore('whRemoveWidget')
        return widgetHandler:RemoveWidget(widget)
    end
    local suffix = WHInitPhase and ' (INIT).' or '.'
    local ret = oriRemoveWidget(wh,w) -- there is no return, but who knows the future
    if w then
        local name = w.whInfo.name or w.whInfo.basename
        Debug(name .. ' has been shut down' .. suffix)
        -- when a widget is shutdown, we check if it had callbacks and remove them from our list
        RemoveCallbacks(w,name)
        if not WHInitPhase then -- we let one update cycle happen before sending the call back when not in init phase
            table.insert(call_later, function() 
                for cb in pairs(WidgetRemoveNotify) do
                    cb(w,name, WHInitPhase)
                end

            end)
            widgetHandler:UpdateWidgetCallIn('Update',widget)
        else
            for cb in pairs(WidgetRemoveNotify) do
                cb(w,name,WHInitPhase)
            end
        end
    end
    return ret
end


function widget:Update(dt)
    if WHInitPhase then
        Debug('first update cycle registered' .. (WHInitPhase and ' WH INIT PHASE is now FALSE.' or '.'))
        WHInitPhase = false
    end
    if call_later[1] then
        table.remove(call_later,1)()
        if not call_later[1] then
            widgetHandler:RemoveWidgetCallIn('Update',widget)
        end
    end
end

-- this trick to get the real widgetHandler at load time instead of init time
-- so that work around will only work at second ever load of the widget because SetConfigData will not be called until some data has been stored on disk ({dummy=true})

function widget:Initialize()
    Init('init')
end
widget.SetConfigData = function() return Init('config') end
Init('load')

function widget:GetConfigData()
    return {dummy=true}
end

function widget:Shutdown()
    if Log then
        Log:Delete()
        Log = nil
    end
    Restore("Shutdown")
end

