function widget:GetInfo()

  return {
    name      = "Debug Center",
    desc      = "Centralized system of debugging with a bunch of tool",
    author    = "Helwor",
    date      = "Dec 2022",
    license   = "GNU GPL v2 or later",
    layer     = 1002, -- after chili_addon
    enabled   = true,  --  
    handler   = true,
    api       = true,
  }
end
local Echo = Spring.Echo
local debugMe = false


local disabled = false
local sig = '['..widget:GetInfo().name..']:'

local LINE_HEIGHT = 20
local yellow = {1,1,0,1}
-- VFS.Include("LuaUI/Widgets/chili_old/Headers/links.lua")
local f = VFS.Include("LuaUI\\Widgets\\UtilsFunc.lua")

local Chili
local Window
local TextBox
local main_win
local hidePanel = false
local widgetHistoryControls = {}
widgets = {}
local icon = "LuaUI/Images/commands/states/autoassist_on.png"
local win_text, content, button

local function UnlinkSafe(link)
    local link = link
    while (type(link) == "userdata") do
        link = link()
    end
    return link
end

local function GetBaseName()
    for i=4, 12 do 
        local k,v = debug.getlocal(i,5)
        if k=='basename' then
            return v
        end
    end
end

local function GetWidgetName(w)
    w = w or widget
    local wi = w.whInfo
    local name, basename
    if wi then
        -- the widget is loaded and finalized (we're past those steps)
        name, basename = wi.name, wi.basename
        return wi.name, wi.basename
    elseif w then
        name = w.GetInfo and w.GetInfo().name
    end
    if not w or w~=widget then
        return name or basename
    end
    -- the widget looked for is the one we're in and it is getting loaded
    basename = GetBaseName()
    return name or basename
    -- for i,v in ipairs (widgetHandler.widgets) do
    --     if v == w then
    --         Echo('found widget')
end

local copy = function(t)
    local c = {}
    for k,v in pairs(t) do
        c[k] = v
    end
    return c
end
local EMPTY_LABEL = {
    caption = '--'
    ,valign = 'center'
    ,align = 'center'
}


local colNames = {'widget','Log','Var Debug'}
local controlNames = {
    widget = 'widget',
    Log = 'Log',
    ['Var Debug'] = 'varDebug',
}
local widgetControls = {}
local colFuncs = {
    widget = function(w,name)
        return Chili.Label:New{
            caption = name
            -- ,OnClick = { function(self) Echo("hi I'm button A") end }
            ,HitTest = function(self,x,y)
                return self
            end
            ,height = LINE_HEIGHT
            ,OnMouseDown = {
                function(self,x,y,...)
                end
            }
            ,valign = 'center'
            ,align = 'center'
        }
    end
    ,Log = function(w,name,Log)
        if not Log then
            return Chili.Label:New(copy(EMPTY_LABEL))
        end
        return Chili.Button:New{
            caption = 'Log'
            ,height = LINE_HEIGHT

            ,OnClick = { 
                function(self)
                    Log:ToggleWin()
                end
            }
            ,height = LINE_HEIGHT
            ,OnDispose = {
                function()
                    Log:Delete()
                end
            }

        }
    end
    ,['varDebug'] = function(w,name,Log,varDebug)
        if not varDebug then
            return Chili.Label:New(copy(EMPTY_LABEL))
        end
        varDebug.win:Hide()
        
        -- table.insert(debugWin.OnDispose, function()debugWin = nil end)
        return Chili.Button:New{
            caption = 'Var Debug'
            ,height = LINE_HEIGHT
            ,OnClick = { 
                function(self)
                    if varDebug.win then
                        if varDebug.win.hidden then
                            self.winVisible = true
                            varDebug.win:Show()
                        else
                            self.winVisible = false
                            varDebug.win:Hide()
                        end
                    end
                end 
            }
            ,OnDispose = {
                function()
                    varDebug:Delete()
                end
            }
        }
    end
}
local rows = {}
local grid



---------- updating teamID
local myTeamID
local MyNewTeamID = function()
    myTeamID = Spring.GetMyTeamID()
end
widget.TeamChanged = MyNewTeamID
widget.PlayerChanged = MyNewTeamID
widget.Playeradded = MyNewTeamID
widget.PlayerRemoved = MyNewTeamID
widget.TeamDied = MyNewTeamID
----------



function table.deepcopy(_t)
    local t = {}
    for k,v in pairs(_t) do
        if type(v)=='table' then
            v = table.deepcopy(v)
        end
        t[k] = v
    end
    return t
end


function widget:GameFrame(f)

--     if f%60 == 0 then
--         -- Echo('Muuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuul' .. '\n' .. 'ti' .. '\n' .. 'line' ..'\n frame is ' .. f)
--         Echo('frame is ' .. f)
--         Echo('frame is ' .. f)
--     end
end


function widget:Update()
    if WG.GlobalCommandBar and not hidePanel then
        local function ToggleWindow()
            if main_win.visible then
                main_win:Hide()
            else
                main_win:Show()
            end
        end
        if WG.debug_center_command_button then -- work around since GlobalCommandBar doesn't have a remove function
            WG.debug_center_command_button.OnClick = {ToggleWindow}
            WG.debug_center_command_button:Show()
        else
            WG.debug_center_command_button = WG.GlobalCommandBar.AddCommand(icon, widget:GetInfo().name, ToggleWindow)
        end
        -- Echo('links of Command button: ' .. #getmetatable(WG.debug_center_command_button)._obj._hlinks)
    end
    Echo('[' .. widget:GetInfo().name .. ']:[Init]:' .. ' Done')
    widgetHandler:RemoveWidgetCallIn("Update", widget)

end



local function MakeMainWindow()

    main_win ={
        name   = 'debug_center'
        ,parent = Chili.Screen0
        ,caption = widget:GetInfo().name
        ,color = {0, 0, 0, 0.5}
        ,width = 400
        ,height = 300
        ,right = 0
        ,top = 100
        ,y = 100
        ,dockable = true
        ,draggable = true
        ,resizable = false
        ,minWidth = 270
        ,minHeight = 200
        ,resizable = true
        ,padding = {0, 20, 0, 0}
        -- ,itemPadding = {0, 0, 0, 0}
        ,preserveChildrenOrder = true

        ,widgets = {}
        ,indexes = {}
        ,maxIndex = 0
    }

    grid = {
        columns = #colNames
        ,width = '100%'
        ,height=0
        -- ,right = 1
        ,padding = {0,0,0,0}
        ,itemPadding = {0,0,0,0}
        ,itemMargin = {0,0,0,0}
        ,preserveChildrenOrder = true
        -- ,autosize = true

    }

    local headerGrid = {
        columns = #colNames
        ,width = '100%'
        ,height=LINE_HEIGHT+5
        ,y=0
        ,padding = {1,1,1,1}
        ,itemPadding = {1,1,1,1}
        ,itemMargin = {1,1,1,1}
        -- ,preserveChildrenOrder = true
        -- ,autosize = true

    }

    local columnHead = {
        align = 'center'
        ,width = '100%'
        -- ,top = 1
        ,height=LINE_HEIGHT
        ,autosize = false
        ,textColor = yellow
    }

    -- making headers
    local headers = {}
    for i,name in ipairs(colNames) do
        local head = table.deepcopy(columnHead)
        head.caption = name
        Chili.Label:New(head)
        headers[i] = head
    end
    headerGrid.children = headers
    Chili.Grid:New(headerGrid)

    -- grid.parent = main_win

    grid.children = {}
    Chili.Grid:New(grid)



    -- local stack = {
    --     x=1,
    --     y=1,
    --     height = '100%',
    --     right = 1,
    --     padding = {0,0,0,0},
    --     itemPadding = {0,0,0,0},
    --     itemMargin = {0,0,0,0},
    --     children = {},
    -- }

    -- Chili.StackPanel:New(stack)

    local scroll = {
        x=5
        ,y=20
        ,right=5
        ,bottom = 25
        ,padding = {0,0,0,0}
        ,itemPadding = {0,0,0,0}
        ,itemMargin = {0,0,0,0}

        ,children = { grid }
    }

    Chili.ScrollPanel:New(scroll)
    main_win.children = { headerGrid, scroll }
    -- stack.children = labels
    -- Chili.StackPanel:New(stack)

    -- Chili.ScrollPanel:New(scroll)

    -- main_win.children = {stack}




    Chili.Window:New(main_win)

    if WG.MakeMinizable then
        WG.MakeMinizable(main_win)
    end
end


local function AddRow(w,wname,Log,varDebug)
    widgetControls[w] = {}
    grid:Resize(nil,grid.height + LINE_HEIGHT)
    for i, name in ipairs(colNames) do
        local ctrlName = controlNames[name]
        local func = colFuncs[ ctrlName ]
        local ctrl = func(w,wname,Log,varDebug)
        -- table.insert(widgetControls[w],ctrl)
        widgetControls[w][ ctrlName ] = ctrl
        grid:AddChild(ctrl)
        -- 

        if widgetHistoryControls[wname] and widgetHistoryControls[wname][ctrlName] then
            for _,clickFunc in ipairs(ctrl.OnClick) do
                clickFunc(ctrl)
            end
        end
        -- grid:AddChild(button)
    end
end
-- local function UpdateCtrlOfWidget(w,Log,varDebug)
--     if Log == 'Log' then
--         -- the widget ask to handle the log
--         Log = WG.LogHandler:New(w)
--     end
--     if varDebug then
--         varDebug = f.DebugWinInit2(w,unpack(varDebug))
--     end
-- end
local function RemoveWidget(widget,wname)
    wname = wname or GetWidgetName(widget)

    local controls = widgetControls[widget]
    widgetHistoryControls[wname] = {}
    if controls then
        for i,v in pairs(controls) do
            widgetHistoryControls[wname][i] = v.winVisible
            grid:RemoveChild(v)

            v:Dispose()
        end
        widgetControls[widget]=nil
    end
    if main_win then
        local index = main_win.indexes[widget]
        if index then
            for w,i in  pairs(main_win.indexes) do
                if i>index then 
                    main_win.indexes[w] = i-1
                end
            end
            main_win.maxIndex = main_win.maxIndex - 1
            main_win.indexes[widget] = nil
            grid:Resize(nil,grid.height - LINE_HEIGHT)
        end
        main_win.widgets[wname] = nil
    end
    widget.modifiedShutdown = false
    if widget.DebugUp then
        widget.DebugUp = function() end
    end
    widgets[widget] = nil
end

local ChangeShutdown = function(w,name,index)
    local oriShutdown = w.Shutdown
    if w.modifiedShutdown then
        return
    end
    w.Shutdown = function(self) RemoveWidget(self,name) return oriShutdown and oriShutdown(self) end
    w.modifiedShutdown = true
end

local function AddWidget(w,params)
    local index
    local wname = GetWidgetName(w)
    local _w = main_win.widgets[wname]
    if _w and _w~=w then
        -- widget has been shut down and is now different
        Echo(sig .. '[WARN]:' .. ' a different widget of the same name was already registered') 
        RemoveWidget(_w,wname)
        _w = false
    end
    local Log, varDebug = params.Log, params.varDebug
    if Log == 'Log' then
        -- the widget ask to handle the log
        Log = WG.LogHandler:New(w)
    end
    if varDebug then
        varDebug = f.DebugWinInit2(w,unpack(varDebug))
        w.DebugUp = varDebug.DebugUp
    end
    if _w and _w==w then

        local controls = widgetControls[_w]
        -- updating the existing row of the widget
        for ctrlName,v in pairs(params) do
            local ctrl = controls[ctrlName]
            if ctrl then
                local objDirect = UnlinkSafe(ctrl)
                local index
                for i,v in pairs(objDirect.parent.children) do
                    if objDirect == v then
                        index = i
                        break
                    end
                end
                if index then
                    local success = grid:RemoveChild(ctrl)
                    local func = colFuncs[ctrlName]
                    
                    local newctrl = func(w,wname,Log,varDebug)
                    controls[ ctrlName ] = nil
                    controls[ ctrlName ] = newctrl
                    -- using index param to AddChild work only one time for some reason, after that, remove child fail
                    -- but using SetChildLayer work everytime
                    grid:AddChild(newctrl)
                    grid:SetChildLayer(newctrl,index)
                    if widgetHistoryControls[wname] and widgetHistoryControls[wname][ctrlName] then
                        for _,clickFunc in ipairs(ctrl.OnClick) do
                            clickFunc(ctrl)
                        end
                    end

                end
            end
        end
        return Log, varDebug
    end


    local index = main_win.maxIndex+1
    main_win.maxIndex = index
    AddRow(w,wname,Log,varDebug)
    ChangeShutdown(w,wname, index)

    main_win.widgets[wname] = w
    main_win.indexes[w] = index
    widgets[w] = true
    return Log, varDebug
end


local function Init()
    MakeMainWindow()
    main_win:Hide()
end

function widget:Initialize()
    WG.DebugCenter = {Add = AddWidget, Remove = RemoveWidget, widgets = widgets}
    Chili = WG.Chili
    Window = Chili.Window
    TextBox = Chili.TextBox
    Init()
    if debugMe then
        widget.Log = AddWidget(widget,'Log')
        local Log = widget.Log
        local spEcho = Spring.Echo
        Echo = function(...) Log(...) spEcho(...) end
    end

end

function widget:Shutdown()
    WG.DebugCenter = nil
    if Log then
        Log:Delete()
    else
        -- Spring.Echo("Log doesn't exist")
    end
    if WG.debug_center_command_button then
        WG.debug_center_command_button:Hide()
    end
    if main_win then
        main_win:Dispose()
    end
end
