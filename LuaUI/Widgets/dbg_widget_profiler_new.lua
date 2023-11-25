--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function widget:GetInfo()
return {
	name      = "Widget Profiler New",
	desc      = "",
	author    = "jK, Bluestone",
	version   = "2.0",
	date      = "2007+",
	license   = "GNU GPL, v2 or later",
	layer     = math.huge,
	handler   = true,
	enabled   = false  --  loaded by default?
}
end
local glText = gl.Text

local usePrefixedNames = true
local PROFILE_POS_X = 425
local PROFILE_POS_Y = 80
local COL_SPACING = 420

local hooked
local boxes = {}
local recapbox
local Echo = Spring.Echo
local Chili
local StartHook, StopHook
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local prefixedWnames = {}
local function ConstructPrefixedName (ghInfo, name)
	local gadgetName = name or ghInfo.name
	local baseName = ghInfo.basename
	local _pos = baseName:find("_", 1)
	local prefix = ((_pos and usePrefixedNames) and (baseName:sub(1, _pos-1)..": ") or "")
	local prefixedGadgetName = "\255\200\200\200" .. prefix .. "\255\255\255\255" .. gadgetName
	
	prefixedWnames[gadgetName] = prefixedGadgetName
	return prefixedWnames[gadgetName]
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local callinStats       = {}

local spGetTimer = Spring.GetTimer
local spDiffTimers = Spring.DiffTimers
local spGetLuaMemUsage = Spring.GetLuaMemUsage

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local function ArrayInsert(t, f, g)
	if (f) then
		local layer = g.whInfo.layer
		local index = 1
		for i,v in ipairs(t) do
		if (v == g) then
			return -- already in the table
		end
		if (layer >= v.whInfo.layer) then
			index = i + 1
		end
		end
		table.insert(t, index, g)
	end
end


local function ArrayRemove(t, g)
	for k,v in ipairs(t) do
		if (v == g) then
		table.remove(t, k)
		-- break
		end
	end
end

-- TextBox

local function newbox(name,height,caption, shutdown)
	local win = Chili.Window:New{
		parent = Chili.Screen0
		,height = height or 600
		,horizontalScrollbar = false
		,verticalScrollbar = false
		,caption = caption or name
		,OnDispose = {
			function(self)
			end
		}
		,itemPadding = {0,0,0,0}
		,padding = {0,0,0,0}
		-- ,autosize = true
		-- ,height =800
		-- ,width = 800

	}
	local scroll = Chili.ScrollPanel:New{
		parent = win
		,x = 0
		,y = 24
		,right = 0
		,left = 0
		,top = 0
		,autosize = true
		,align = "left"
		,valign = "left"
		-- ,verticalSmartScroll = true
		,fontsize = 12
		,bottom = 0
		-- workaround to trigger the text updating on scroll, but there's probably a more decent way to do it
		,Update = function(self,...) self.children[1]:Invalidate() self.inherited.Update(self,...)   end
	}
	local box = Chili.TextBox:New{
		parent = scroll
		,autosize = true
		,text=name..'\nTEXT...'
		,OnParentPost = {function(self) self.font.size = 10 end }
	}
	local shutdown = Chili.Button:New{
		x=-25,
		width = 25,
		y=2, height = 20,
		caption="X",
		OnClick = {
			function(self)
				widgetHandler:ToggleWidget(widget:GetInfo().name)
			end
		},
		parent = win,
	}

	local button = Chili.Button:New{
		x=-100,
		width = 75,
		y=2, height = 20,
		caption="Stop",
		OnClick = {
			function(self)
				local newcaption
				if hooked then
					StopHook()
					newcaption = 'Start'
				else
					StartHook()
					newcaption = 'Stop'
				end
				for k,v in pairs(boxes) do
					v.button.caption = newcaption
					v.button:Invalidate()
				end
				recapbox.button.caption = newcaption
				recapbox.button:Invalidate()

			end
		},
		parent = win,
	}
	if WG.MakeMinizable then
		WG.MakeMinizable(win, true)
	end
	box.win = win
	box.button = button
	return box
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

-- make a table of the names of user widgets
local userWidgets = {}

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local oldUpdateWidgetCallIn
local oldInsertWidget

local listOfHooks = {}
setmetatable(listOfHooks, { __mode = 'k' })

local inHook = false
local function IsHook(func)
	return listOfHooks[func]
end

local function Hook(w,name) -- name is the callin
	local widgetName = w.whInfo.name

	local wname = prefixedWnames[widgetName] or ConstructPrefixedName(w.whInfo)

	local realFunc = w[name]
	w["_old" .. name] = realFunc

	if (widgetName=="Widget Profiler New") then
		-- return realFunc -- don't profile the profilers callins (it works, but it is better that our DrawScreen call is unoptimized and expensive anyway!)
	end

	local widgetCallinTime = callinStats[wname] or {}
	callinStats[wname] = widgetCallinTime
	widgetCallinTime[name] = widgetCallinTime[name] or {0,0,0,0}
	local c = widgetCallinTime[name]

	local t

	local helper_func = function(...)
		local dt = spDiffTimers(spGetTimer(),t)
		if dt > 0.075 then
			Echo(name .. ' in ' .. widgetName .. ' took more than 0.075 sec: ' .. ('%.2f'):format(dt),'Active command ?',Spring.GetActiveCommand())
		end
		local _,_,new_s,_ = spGetLuaMemUsage()
		local ds = new_s - s
		c[1] = c[1] + dt
		c[2] = c[2] + dt
		c[3] = c[3] + ds
		c[4] = c[4] + ds
		inHook = nil
		return ...
	end

	local hook_func = function(...)
		if (inHook) then
			return realFunc(...)
		end

		inHook = true
		t = spGetTimer()
		local _,_,new_s,_ = spGetLuaMemUsage()
		s = new_s
		return helper_func(realFunc(...))
	end

	listOfHooks[hook_func] = true

	return hook_func
end

StartHook = function()
	Spring.Echo("start profiling")

	local wh = widgetHandler

	local CallInsList = {}
	for name,e in pairs(wh) do
		local i = name:find("List")
		if (i)and(type(e)=="table") then
			CallInsList[#CallInsList+1] = name:sub(1,i-1)
		end
	end

	--// hook all existing callins
	for _,callin in ipairs(CallInsList) do
		local callinGadgets = wh[callin .. "List"]
		for _,w in ipairs(callinGadgets or {}) do
			w[callin] = Hook(w,callin)
		end
	end

	Spring.Echo("hooked all callins")

	--// hook the UpdateCallin function
	oldUpdateWidgetCallIn =  wh.UpdateWidgetCallIn
	wh.UpdateWidgetCallIn = function(self,name,w)
		local listName = name .. 'List'
		local ciList = self[listName]
		if (ciList) then
			local func = w[name]
			if (type(func) == 'function') then
				if (not IsHook(func)) then
				w[name] = Hook(w,name)
				end
				ArrayInsert(ciList, func, w)
			else
				ArrayRemove(ciList, w)
			end
			self:UpdateCallIn(name)
		else
			print('UpdateWidgetCallIn: bad name: ' .. name)
		end
	end

	Spring.Echo("hooked UpdateCallin")

	--// hook the InsertWidget function
	oldInsertWidget =  wh.InsertWidget
	if wh.OriginalInsertWidget then
		oldInsertWidget = wh.OriginalInsertWidget
	else
		oldInsertWidget = wh.InsertWidget
	end

	widgetHandler.InsertWidget = function(self,widget)
		if (widget == nil) then
			return
		end

		oldInsertWidget(self,widget)

		for _,callin in ipairs(CallInsList) do
			local func = widget[callin]
			if (type(func) == 'function') then
				widget[callin] = Hook(widget,callin)
			end
		end
	end
	hooked = true
	Spring.Echo("hooked InsertWidget")
end


StopHook = function()
	Spring.Echo("stop profiling")

	local wh = widgetHandler

	local CallInsList = {}
	for name,e in pairs(wh) do
		local i = name:find("List")
		if (i)and(type(e)=="table") then
			CallInsList[#CallInsList+1] = name:sub(1,i-1)
		end
	end

	--// unhook all existing callins
	for _,callin in ipairs(CallInsList) do
		local callinWidgets = wh[callin .. "List"]
		for _,w in ipairs(callinWidgets or {}) do
			if (w["_old" .. callin]) then
				w[callin] = w["_old" .. callin]
			end
		end
	end

	Spring.Echo("unhooked all callins")

	--// unhook the UpdateCallin and InsertWidget functions
	wh.UpdateWidgetCallIn = oldUpdateWidgetCallIn
	Spring.Echo("unhooked UpdateCallin")
	if wh.OriginalInsertWidget then
		wh.OriginalInsertWidget = oldInsertWidget
	else
		wh.InsertWidget = oldInsertWidget
	end
	Spring.Echo("unhooked InsertWidget")
	hooked = false
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local tick = 2
local averageTime = 4
local timeLoadAverages = {}
local spaceLoadAverages = {}
local startTimer

function widget:Update()
	widgetHandler:RemoveWidgetCallIn("Update", self)
	StartHook()
	startTimer = Spring.GetTimer()
end

function widget:Shutdown()
	StopHook()
	-- this make it disabled for the next game if widgetHandler is shutting down
	widgetHandler:DisableWidget(widget:GetInfo().name)
end

local lm,_,gm,_,um,_,sm,_ = spGetLuaMemUsage()

local allOverTime = 0
local allOverTimeSec = 0 -- currently unused
local allOverSpace = 0
local totalSpace = {}

local sortedList = {}
local function SortFunc(a,b)
	return a.plainname < b.plainname
end

local deltaTime
local redStrength = {}

local minPerc = 0.005 -- above this value, we fade in how red we mark a widget
local maxPerc = 0.02 -- above this value, we mark a widget as red
local minSpace = 10 -- Kb
local maxSpace = 100

local title_colour = "\255\160\255\160"
local totals_colour = "\255\200\200\255"
local maxLines = 50

local function CalcLoad(old_load, new_load, t)
	return old_load*math.exp(-tick/t) + new_load*(1 - math.exp(-tick/t))
end

function ColourString(R,G,B)
	R255 = math.floor(R*255)
	G255 = math.floor(G*255)
	B255 = math.floor(B*255)
	if (R255%10 == 0) then R255 = R255+1 end
	if (G255%10 == 0) then G255 = G255+1 end
	if (B255%10 == 0) then B255 = B255+1 end
	return "\255"..string.char(R255)..string.char(G255)..string.char(B255)
end

function GetRedColourStrings(v) --tLoad is %
	local tTime = v.tTime
	local sLoad = v.sLoad
	local name = v.plainname
	local u = math.exp(-deltaTime/5) --magic colour changing rate

	if tTime>maxPerc then tTime = maxPerc end
	if tTime<minPerc then tTime = minPerc end

	-- time
	local new_r = ((tTime-minPerc)/(maxPerc-minPerc))
	redStrength[name..'_time'] = redStrength[name..'_time'] or 0
	redStrength[name..'_time'] = u*redStrength[name..'_time'] + (1-u)*new_r
	local r,g,b = 1, 1-redStrength[name.."_time"]*((255-64)/255), 1-redStrength[name.."_time"]*((255-64)/255)
	v.timeColourString = ColourString(r,g,b)
	
	-- space
	new_r = math.max(0,math.min(1,(sLoad-minSpace)/(maxSpace-minSpace)))
	redStrength[name..'_space'] = redStrength[name..'_space'] or 0
	redStrength[name..'_space'] = u*redStrength[name..'_space'] + (1-u)*new_r
	g = 1-redStrength[name.."_space"]*((255-64)/255)
	b = g
	v.spaceColourString = ColourString(r,g,b)
end



function DrawWidgetList(list,name,x,y,j)
	local str,line = '',''
	-- glText(title, x+152, y-1-(12)*j, 10, "no")
	local part1 = ('%.2f%%'):format(list.allOverTime)
	local part2 = ('%.0f'):format(list.allOverSpace) .. 'kB/s'
	local caption = title_colour..name.." WIDGETS ".. part1 .. ' ' .. part2
	str = title_colour..name.." WIDGETS".. '\n'
			.. title_colour..part1..('  '):rep(16-part1:len())
			.. title_colour..part2
	boxes[name] = boxes[name] or newbox(name, nil, caption)
	local box = boxes[name]
	box.win.caption = caption
	box.win:Invalidate()
	-- Echo("box.classname is ", box.parent.parent.caption)
	for i=1,#list do
		local v = list[i]
		--local name = v.plainname
		local part1 = ('%.2f%%'):format(v.tLoad)
		local part2 = ('%.0f'):format(v.sLoad) .. 'kB/s'
		str = str .. '\n'
				.. v.timeColourString .. part1..('  '):rep(16-part1:len())
				.. v.spaceColourString .. part2..('\t'):rep(16-part2:len())
				.. v.fullname
	end


	box:SetText(str)
	return
end

local function UpdateRecap()
	local str = ''
	local line, part = '', ''


	-- Echo("recapbox.win.caption is ", recapbox.win.caption)
	-- glText(str, x+152, y-1-(12)*j, 10, "no")
	str = title_colour.."ALL"
	.. '\n' .. totals_colour.."total percentage of running time spent in luaui callins"
	.. '\n' .. totals_colour..('%.1f%%'):format(allOverTime)
	.. '\n' .. totals_colour.."total rate of mem allocation by luaui callins"
	.. '\n' .. totals_colour..('%.0f'):format(allOverSpace) .. 'kB/s'

	if gm then
		part = totals_colour..'total lua memory usage is '.. ('%.0f'):format(gm/1000) .. 'MB, of which:'
		str = str .. '\n' .. part
		if lm then
			part = totals_colour..'  '..('%.0f'):format(100*lm/gm) .. '% is from luaui'
			-- glText(part, x+65, y-1-(12)*j, 10, "no")
			str = str .. '\n' .. part
		end
		if um then
			part = totals_colour..'  '..('%.0f'):format(100*um/gm) .. '% is from unsynced states (luarules+luagaia+luaui)'
			-- glText(part, x+65, y-1-(12)*j, 10, "no")
			str = str .. '\n' .. part

		end
		if sm then
			part = totals_colour..'  '..('%.0f'):format(100*sm/gm) .. '% is from synced states (luarules+luagaia)'
			-- glText(part, x+65, y-1-(12)*j, 10, "no")
			str = str .. '\n' .. part
		end
	end
	part = title_colour.."All data excludes load from garbage collection & executing GL calls"
	-- glText(part, x+65, y-1-(12)*j, 10, "no")
	str = str .. '\n' .. part
	part = title_colour.."Callins in brackets are heaviest per widget for (time,allocs)"
	-- glText(part, x+65, y-1-(12)*j, 10, "no")
	str = str .. '\n' .. part
	part = title_colour.."Tick time: " .. tick .. "s"
	-- glText(part, x+65, y-1-(12)*j, 10, "no")
	str = str .. '\n' .. part
	part = title_colour.."Smoothing time: " .. averageTime .. "s"
	-- glText(part, x+65, y-1-(12)*j, 10, "no")
	str = str .. '\n' .. part
	recapbox:SetText(str)
end




local started
function widget:DrawScreen()
	if not (next(callinStats)) then
		return --// nothing to do
	end
	if not hooked then
		return
	end

	deltaTime = Spring.DiffTimers(Spring.GetTimer(),startTimer)

	-- sort & count timing
	if (deltaTime>=tick) or not started then
		started = true
		startTimer = Spring.GetTimer()
		sortedList = {}

		allOverTime = 0
		allOverSpace = 0
		local n = 1
		for wname,callins in pairs(callinStats) do
			local t = 0 -- would call it time, but protected
			local cmax_t = 0
			local cmaxname_t = "-"
			local space = 0
			local cmax_space = 0
			local cmaxname_space = "-"
			for cname,c in pairs(callins) do
				t = t + c[1]
				if (c[2]>cmax_t) then
					cmax_t = c[2]
					cmaxname_t = cname
				end
				c[1] = 0
				
				space = space + c[3]
				if (c[4]>cmax_space) then
					cmax_space = c[4]
					cmaxname_space = cname
				end
				c[3] = 0
			end

			local relTime = 100 * t / deltaTime
			timeLoadAverages[wname] = CalcLoad(timeLoadAverages[wname] or relTime, relTime, averageTime)
			
			local relSpace = space / deltaTime
			spaceLoadAverages[wname] = CalcLoad(spaceLoadAverages[wname] or relSpace, relSpace, averageTime)

			allOverTimeSec = allOverTimeSec + t

			local tLoad = timeLoadAverages[wname]
			local sLoad = spaceLoadAverages[wname]
			sortedList[n] = {plainname=wname, fullname=wname..' \255\200\200\200('..cmaxname_t..','..cmaxname_space..')', tLoad=tLoad, sLoad=sLoad, tTime=t/deltaTime}
			allOverTime = allOverTime + tLoad
			allOverSpace = allOverSpace + sLoad

			n = n + 1
		end

		table.sort(sortedList,SortFunc)
		
		for i=1,#sortedList do
			GetRedColourStrings(sortedList[i])
		end

		lm,_,gm,_,um,_,sm,_ = spGetLuaMemUsage()
	end

	if (not sortedList[1]) then
		return --// nothing to do
	end

	-- add to category and set colour
	local userList = {}
	local gameList = {}
	userList.allOverTime = 0
	gameList.allOverTime = 0
	userList.allOverSpace = 0
	gameList.allOverSpace = 0
	for i=1,#sortedList do
		if userWidgets[sortedList[i].plainname] then
			userList[#userList+1] = sortedList[i]
			userList.allOverTime = userList.allOverTime + sortedList[i].tLoad
			userList.allOverSpace = userList.allOverSpace + sortedList[i].sLoad
		else
			gameList[#gameList+1] = sortedList[i]
			gameList.allOverTime = gameList.allOverTime + sortedList[i].tLoad
			gameList.allOverSpace = gameList.allOverSpace + sortedList[i].sLoad
		end
	end

	x,j = DrawWidgetList(gameList,"GAME",x,y,j)
	x,j = DrawWidgetList(userList,"USER",x,y,j)
	UpdateRecap()
end

function widget:Initialize()
	Chili = WG.Chili
	recapbox = newbox('recap', 165, title_colour .. 'Widget Profiler', true)
	for name,wData in pairs(widgetHandler.knownWidgets) do
		userWidgets[prefixedWnames[name] or ConstructPrefixedName(wData,name)] = (not wData.fromZip)
	end
end




--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
