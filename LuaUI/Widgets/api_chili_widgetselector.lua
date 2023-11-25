function widget:GetInfo()
  return {
    name      = "Chili Widget Selector", --needs epic menu to dynamically update widget checkbox colors.
    desc      = "v1.013 Chili Widget Selector",
    author    = "CarRepairer",
    date      = "2012-01-11", --2013-06-11 (add crude filter/search capability)
    license   = "GNU GPL, v2 or later",
    layer     = -100000,
    handler   = true,
    enabled   = true,
    alwaysStart = true,
  }
end
local Echo = Spring.Echo


local spGetModKeyState = Spring.GetModKeyState


function MakeWidgetList() end
function KillWidgetList() end
local window_widgetlist

options_path = 'Settings/Misc'
options =
{
	widgetlist_2 = {
		name = 'Widget List',
		type = 'button',
		--hotkey = {key='f11', mod='A'}, -- In zk_keys.lua
		advanced = true,
		OnChange = function(self)
			if window_widgetlist then
				KillWidgetList()
			elseif not window_widgetlist then
				MakeWidgetList()
			end
		end
	}
}


--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local echo = Spring.Echo

--------------------------------------------------------------------------------
-- Config file data
--------------------------------------------------------------------------------

local file = LUAUI_DIRNAME .. "Configs/epicmenu_conf.lua"
local confdata = VFS.Include(file, nil, VFS.ZIP)
local color = confdata.color

local spGetMouseState = Spring.GetMouseState

-- Chili control classes
local Chili
local Button
local Label
local Colorbars
local Checkbox
local Window
local ScrollPanel
local StackPanel
local LayoutPanel
local Grid
local Trackbar
local TextBox
local Image
local Progressbar
local Colorbars
local Control
local Object
local screen0

--------------------------------------------------------------------------------
-- Global chili controls


local widget_categorize = true
local filterUserInsertedTerm = "" --the term used to filter down the list of widget
local startMinized = true
--------------------------------------------------------------------------------
-- Misc
local B_HEIGHT = 26
local C_HEIGHT = 16

local scrH, scrW = 0,0

local window_w
local window_h
local window_x
local window_y


--------------------------------------------------------------------------------
--For widget list
local USERLOCAL = "User local"

local widget_checks = {}
local green = {0,1,0,1}
local darkgreen = {0,0.6,0,1}
local orange =  {1,0.5,0,1}
local gray =  {0.7,0.7,0.7,1}
local groupDescs = {
	api     = "For Developers",
	always	= "ALWAYS",
	camera  = "Camera",
	cmd     = "Commands",
	dbg     = "For Developers",
	gfx     = "Effects",
	gui     = "GUI",
	hook    = "Commands",
	ico     = "GUI",
	init    = "Initialization",
	map		= "Map",
	minimap = "Minimap",
	mission	= "Mission",
	snd     = "Sound",
	test    = "For Developers",
	unit    = "Units",
	ungrouped    = "Ungrouped",
	userlocal    = USERLOCAL,
}




----------------------------------------------------------------
--May not be needed with new chili functionality
local function AdjustWindow(window)

    -- if window.height == window.minHeight --[[and window.width == window.minWidth--]] then
    --     -- Spring.Echo('mini size detected')
    --     window.minWidth = window.minizedWidth
    --     window:Resize(window.minizedWidth,window.height)
    --     -- trigger the minizing if the window is loaded with mini size
    -- end



	local nx
	if (0 > window.x) then
		nx = 0
	elseif (window.x + window.width > screen0.width) then
		nx = screen0.width - window.width
	end

	local ny
	if (0 > window.y) then
		ny = 0
	elseif (window.y + window.height > screen0.height) then
		ny = screen0.height - window.height
	end

	if (nx or ny) then
		window:SetPos(nx,ny)
	end
end

-- Adding functions because of "handler=true"
local function AddAction(cmd, func, data, types)
	return widgetHandler.actionHandler:AddAction(widget, cmd, func, data, types)
end
local function RemoveAction(cmd, types)
	return widgetHandler.actionHandler:RemoveAction(widget, cmd, types)
end


-- returns whether widget is enabled
local function WidgetEnabled(wname)
	local order = widgetHandler.orderList[wname]
	return order and (order > 0)
end
			




-- Update colors for labels of widget checkboxes in widgetlist window
local function checkWidget(widget)
	if type(widget) == 'string' then
		name = widget
		widget = widgetHandler:FindWidget(name)
	else
		name = widget.whInfo.name
	end
	local wcheck = widget_checks[name]
	if wcheck then
		local wdata = widgetHandler.knownWidgets[name]
		local hilite_color = (wdata.active and green) or (WidgetEnabled(name) and orange) or gray
		if hilite_color == green and widget and widget.isSleeping then
			hilite_color = darkgreen
		end
		wcheck.font:SetColor(hilite_color)
		wcheck:Invalidate()
	end
end
local UpdateCheck = function(w,name,preloading) 
	if not preloading then
		checkWidget(w)
	end
end
WidgetInitNotify = UpdateCheck
WidgetRemoveNotify = UpdateCheck
WidgetSleepNotify = UpdateCheck
WidgetWakeNotify = UpdateCheck

WG.cws_checkWidget = function() end --function is declared in widget:Initialized()

-- Kill Widgetlist window
KillWidgetList = function()
	if window_widgetlist then
		window_x = window_widgetlist.x
		window_y = window_widgetlist.y
		
        window_h = window_widgetlist.height
        window_w = window_widgetlist.width
        -- window_h = window_widgetlist.backupH
        -- window_w = window_widgetlist.backupW
        if window_widgetlist.Dispose then
            window_widgetlist:Dispose()
        end
        window_widgetlist = nil
        filterUserInsertedTerm = ""
		
	end
end
-- Make widgetlist window
MakeWidgetList = function(minize)

	widget_checks = {}

	if window_widgetlist then
        -- KillWidgetList()
        window_x = window_widgetlist.x
        window_y = window_widgetlist.y
        
        window_h = window_widgetlist.height
        window_w = window_widgetlist.width
		window_widgetlist:Dispose()

	end

	local widget_children = {}
	local widgets_cats = {}
	local listIsEmpty = true
	
	
	local buttonWidth = window_w - 20
	
	for name,data in pairs(widgetHandler.knownWidgets) do
		-- if not data.alwaysStart then
			data.basename = data.basename or ''
			data.desc = data.desc or '' --become NIL if zipfile/archive corrupted
			local _, _, category = string.find(data.basename, "([^_]*)")
			if data.alwaysStart then
				category = 'always'
			end
			local lowercase_name = name:lower()
			local lowercase_category = category:lower()
			local lowercase_desc = data.desc:lower()
			
			if filterUserInsertedTerm == "" or
			lowercase_name:find(filterUserInsertedTerm) or
			lowercase_desc:find(filterUserInsertedTerm) or
			lowercase_category:find(filterUserInsertedTerm)
			then
			
				if not data.fromZip then
					category = 'userlocal'
				elseif not groupDescs[category] or not widget_categorize then
					category = 'ungrouped'
				end

				local catdesc = groupDescs[category]
				widgets_cats[catdesc] = widgets_cats[catdesc] or {}

				widgets_cats[catdesc][#(widgets_cats[catdesc])+1] = {
					catname      = catdesc,
					name         = name,
					active       = data.active,
					desc         = data.desc,
				}
				listIsEmpty = false
			end
		-- end
	end
	
	local widgets_cats_i = {}
	for catdesc, catwidgets in pairs(widgets_cats) do
		widgets_cats_i[#widgets_cats_i + 1] = {catdesc, catwidgets}
	end
	
	--Sort widget categories
	table.sort(widgets_cats_i, function(t1,t2)
		return (t1[1] == USERLOCAL) or (t2[1] ~= USERLOCAL and t1[1] < t2[1])
	end)
	
	for _, data in ipairs(widgets_cats_i) do
		local catdesc = data[1]
		local catwidgets = data[2]
	
		--Sort widget names within this category
		table.sort(catwidgets, function(t1,t2)
			return t1.name < t2.name
		end)
		widget_children[#widget_children + 1] =
			Label:New{ caption = '- '.. catdesc ..' -', textColor = color.sub_header, align='center', }
		
		for _, wdata in ipairs(catwidgets) do
			local enabled = WidgetEnabled(wdata.name)
			
			--Add checkbox to table that is used to update checkbox label colors when widget becomes active/inactive
			widget_checks[wdata.name] = Checkbox:New{
					caption = wdata.name,
					checked = enabled,
					tooltip = tostring(wdata.desc),
					OnChange = {
						function(self,value)
							-- little hack
							-- OnChange is called by Toggle() in CheckBox class
							-- reverse the value, to be reverted again by Toggle if we want it to stay as it is
							-- we enable the right click to override the toggling for the right click to trigger our Hook widget on the widget
							local _, _, lmb, _, rmb = spGetMouseState()
							if rmb then
								self.checked = not self.checked 
								if WG.HOOK and widgetHandler:FindWidget(wdata.name) then
									local inst = WG.HOOK:New(nil,nil,wdata.name)
									if inst then
										inst:Switch()
									end
								end
								return true
							end
							local alt,ctrl,m,shift = spGetModKeyState()
							if shift then
								local w = widgetHandler:FindWidget(wdata.name)
								if w then
									self.checked = not self.checked 
									if w.isSleeping then
										widgetHandler:Wake(w)
										checkWidget(wdata.name)
									else
										widgetHandler:Sleep(w)
										checkWidget(wdata.name)
									end
									return true
								end
							end
							widgetHandler:ToggleWidget(wdata.name)
							checkWidget(wdata.name)
						end,
					},
				}
			widget_children[#widget_children + 1] = widget_checks[wdata.name]
			checkWidget(wdata.name) --sets color of label for this widget checkbox
		end
	end
	if listIsEmpty then
		widget_children[1] =
			Label:New{ caption = "- no match for \"" .. filterUserInsertedTerm .."\" -", align='center', }
		widget_children[2] =
			Label:New{ caption = " ", align='center', }
	end
	
	local hotkey = WG.crude.GetHotkey("epic_chili_widget_selector_widgetlist_2")
	if hotkey and hotkey ~= "" then
		hotkey = " (" .. hotkey .. ")"
	else
		hotkey = ''
	end
        --
	window_widgetlist = {
		x = window_x,
		y = window_y,
		width  = window_w,
		height = window_h,
		classname = "main_window_small_tall",
		parent = screen0,
		backgroundColor = color.sub_bg,
		caption = 'Widget List' .. hotkey,
        name = 'widget_selector',
        minWidth = 250,
        minHeight = 400,
        height = 28,


		children = {
			ScrollPanel:New{
				x=5,
				y=15,
				right=5,
				bottom = C_HEIGHT*2,
				children = {
					StackPanel:New{
						x=1,
						y=1,
						height = #widget_children*C_HEIGHT,
						right = 1,
						
						itemPadding = {1,1,1,1},
						itemMargin = {0,0,0,0},
						children = widget_children,
					},
				},
			},
			
			
			--Categorization checkbox
			Checkbox:New{
				caption = 'Categorize',
				tooltip = 'List widgets by category',
				OnClick = { function() widget_categorize = not widget_categorize end, KillWidgetList, MakeWidgetList },
				textColor=color.sub_fg,
				checked = widget_categorize,
				
				x = 5,
				width = '30%',
				height= C_HEIGHT,
				bottom=4,
			},
			
			--Search button
			Button:New{
				caption = 'Search',
				OnClick = { function() Spring.SendCommands("chat","PasteText /searchwidget:") end },
				--backgroundColor=color.sub_close_bg,
				--textColor=color.sub_close_fg,
				--classname = "navigation_button",
				
				x = '33%',
				bottom=4,
				width='30%',
				height=B_HEIGHT,
			},
			
			--Close button
			Button:New{
				caption = 'Close',
				OnClick = { KillWidgetList },
				--backgroundColor=color.sub_close_bg,
				--textColor=color.sub_close_fg,
				--classname = "navigation_button",
				
				x = '66%',
				bottom=4,
				width='30%',
				height=B_HEIGHT,
			},

		},
	}
    Window:New(window_widgetlist)
    if WG.MakeMinizable then
        WG.MakeMinizable(window_widgetlist,minize == 'minize')
    end

	AdjustWindow(window_widgetlist)
end


function widget:Initialize()
	if (not WG.Chili) then
		widgetHandler:RemoveWidget(widget)
		return
	end
	-- setup Chili
	Chili = WG.Chili
	Button = Chili.Button
	Label = Chili.Label
	Colorbars = Chili.Colorbars
	Checkbox = Chili.Checkbox
	Window = Chili.Window
	ScrollPanel = Chili.ScrollPanel
	StackPanel = Chili.StackPanel
	LayoutPanel = Chili.LayoutPanel
	Grid = Chili.Grid
	Trackbar = Chili.Trackbar
	TextBox = Chili.TextBox
	Image = Chili.Image
	Progressbar = Chili.Progressbar
	Colorbars = Chili.Colorbars
    Control = Chili.Control
    Object = Chili.Object
	screen0 = Chili.Screen0
	widget:ViewResize(Spring.GetViewGeometry())
	window_w = 200
	window_h = 28
    -- window_x = (scrW - window_w)/2
    -- window_y = (scrH - window_h)/2
    
    window_x = 0
    window_y = 80
    
	Spring.SendCommands({
		"unbindkeyset f11"
	})
	
	WG.cws_checkWidget = function(widget)
		checkWidget(widget)
	end
    MakeWidgetList('minize')
end

function widget:ViewResize(vsx, vsy)
	scrW = vsx
	scrH = vsy
end

function widget:Shutdown()
	  -- restore key binds
  KillWidgetList()
  Spring.SendCommands({
    "bind f11  luaui selector"
  })
end
function widget:KeyPress(key,mods)
	if mods.ctrl and key==262 then -- Ctrl + KP6 to reload
		Spring.Echo('Reloading ' .. widget:GetInfo().name .. ' api')
		Spring.SendCommands('luaui disablewidget ' .. widget:GetInfo().name)
		Spring.SendCommands('luaui enablewidget ' .. widget:GetInfo().name)
	end
end
function widget:TextCommand(command)
	if window_widgetlist and command:sub(1,13) == "searchwidget:" then
		filterUserInsertedTerm = command:sub(14)
		filterUserInsertedTerm = filterUserInsertedTerm:lower() --Reference: http://lua-users.org/wiki/StringLibraryTutorial
		Spring.Echo("Widget Selector: filtering \"" .. filterUserInsertedTerm.."\"")
		MakeWidgetList()
		return true
	end
	return false
end
