--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function widget:GetInfo()
	return {
		name        = "Chili Framework",
		desc        = "Hot GUI Framework",
		author      = "jK",
		date        = "WIP",
		license     = "GPLv2",
		version     = "2.1",
		layer       = 1000,
		enabled     = true,  --  loaded by default?
		handler     = true,
		api	        = true,
		alwaysStart = true,
	}
end
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
local Echo = Spring.Echo
-- Use old chili if unable to use RTT
local USE_OLD_CHILI = (Spring.GetConfigInt("ZKUseNewChiliRTT") ~= 1) or not ((gl.CreateFBO and gl.BlendFuncSeparate) ~= nil)

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- UI Scaling

local UI_SCALE_MESSAGE = "SetInterfaceScale "

local function SetUiScale(scaleFactor)
	-- Scale such that width is an integer, because the UI aligns along the bottom of the screen.
	local realWidth = gl.GetViewSizes()
	WG.uiScale = realWidth/math.floor(realWidth/scaleFactor)
end
SetUiScale((Spring.GetConfigInt("interfaceScale", 100) or 100)/100)

function widget:RecvLuaMsg(msg)
	if string.find(msg, UI_SCALE_MESSAGE) == 1 then
		local value = tostring(string.sub(msg, 19))
		if value then
			SetUiScale(value/100)
			local vsx, vsy = Spring.Orig.GetViewSizes()
			local widgets = widgetHandler.widgets
			for i = 1, #widgets do
				local w = widgets[i]
				if w.ViewResize then
					w:ViewResize(vsx, vsy)
				end
			end
		end
	end
end

local glPushMatrix 	= gl.PushMatrix
local glTranslate 	= gl.Translate
local glScale 		= gl.Scale
local glPopMatrix 	= gl.PopMatrix
local glColor 		= gl.Color
local glCreateList, glCallList, glDeleteList = gl.CreateList, gl.CallList, gl.DeleteList

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

if not USE_OLD_CHILI then

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

Spring.Echo("Not USE_OLD_CHILI")

local Chili
local screen0
local th
local tk
local tf
local th_Update, tk_Update, tf_Update
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- Chili's location

local function GetDirectory(filepath)
	return filepath and filepath:gsub("(.*/)(.*)", "%1")
end

local source = debug and debug.getinfo(1).source
local DIR = GetDirectory(source) or (LUAUI_DIRNAME.."Widgets/")
CHILI_DIRNAME = DIR .. "chili/"

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function widget:Initialize()
	Chili = VFS.Include(CHILI_DIRNAME .. "core.lua", nil, VFS.ZIP)

	screen0 = Chili.Screen:New{}
	th = Chili.TextureHandler
	tk = Chili.TaskHandler
	tf = Chili.FontHandler
	th_Update, tk_Update, tf_Update = th.Update, tk.Update, tf.Update
	--// Export Widget Globals
	WG.Chili = Chili
	WG.Chili.Screen0 = screen0

	--// do this after the export to the WG table!
	--// because other widgets use it with `parent=Chili.Screen0`,
	--// but chili itself doesn't handle wrapped tables correctly (yet)
	screen0 = Chili.DebugHandler.SafeWrap(screen0)
end

function widget:Shutdown()
	--table.clear(Chili) the Chili table also is the global of the widget so it contains a lot more than chili's controls (pairs,select,...)
	WG.Chili = nil
end

function widget:Dispose()
	screen0:Dispose()
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function widget:DrawScreen()
	if (not screen0:IsEmpty()) then
		glPushMatrix()
		local vsx,vsy = gl.GetViewSizes()
		glTranslate(0,vsy,0)
		glScale(1,-1,1)
		glScale(WG.uiScale,WG.uiScale,1)
		screen0:Draw()
		glPopMatrix()
	end
end


function widget:TweakDrawScreen()
	if (not screen0:IsEmpty()) then
		glPushMatrix()
		local vsx,vsy = gl.GetViewSizes()
		glTranslate(0,vsy,0)
		glScale(1,-1,1)
		glScale(WG.uiScale,WG.uiScale,1)
		screen0:TweakDraw()
		glPopMatrix()
	end
end

function widget:DrawGenesis()
	glColor(1,1,1,1)
	tf_Update()
	th_Update()
	tk_Update()
	glColor(1,1,1,1)
end


function widget:IsAbove()
	local x, y, lmb, mmb, rmb, outsideSpring = Spring.ScaledGetMouseState()
	return (not outsideSpring) and (not screen0:IsEmpty()) and screen0:IsAbove(x,y)
end


local mods = {}
function widget:MousePress(x,y,button)
	if WG.uiScale and WG.uiScale ~= 1 then
		x, y = x/WG.uiScale, y/WG.uiScale
	end
	if Spring.IsGUIHidden() then return false end
	
	local alt, ctrl, meta, shift = Spring.GetModKeyState()
	mods.alt=alt; mods.ctrl=ctrl; mods.meta=meta; mods.shift=shift;
	return screen0:MouseDown(x,y,button,mods)
end


function widget:MouseRelease(x,y,button)
	if WG.uiScale and WG.uiScale ~= 1 then
		x, y = x/WG.uiScale, y/WG.uiScale
	end
	if Spring.IsGUIHidden() then return false end
	local alt, ctrl, meta, shift = Spring.GetModKeyState()
	mods.alt=alt; mods.ctrl=ctrl; mods.meta=meta; mods.shift=shift;

	return screen0:MouseUp(x,y,button,mods)
end


function widget:MouseMove(x,y,dx,dy,button)
	if WG.uiScale and WG.uiScale ~= 1 then
		x, y, dx, dy = x/WG.uiScale, y/WG.uiScale, dx/WG.uiScale, dy/WG.uiScale
	end
	if Spring.IsGUIHidden() then return false end
	local alt, ctrl, meta, shift = Spring.GetModKeyState()
	mods.alt=alt; mods.ctrl=ctrl; mods.meta=meta; mods.shift=shift;

	return screen0:MouseMove(x,y,dx,dy,button,mods)
end


function widget:MouseWheel(up,value)
	local x,y = Spring.ScaledGetMouseState()
	local alt, ctrl, meta, shift = Spring.GetModKeyState()
	mods.alt=alt; mods.ctrl=ctrl; mods.meta=meta; mods.shift=shift;

	return screen0:MouseWheel(x,y,up,value,mods)
end


local keyPressed = true
function widget:KeyPress(key, mods, isRepeat, label, unicode, scanCode)
	keyPressed = screen0:KeyPress(key, mods, isRepeat, label, unicode, scanCode)
	return keyPressed
end


function widget:KeyRelease()
	local _keyPressed = keyPressed
	keyPressed = false
	return _keyPressed -- block engine actions when we processed it
end


function widget:TextInput(utf8, ...)
	if Spring.IsGUIHidden() then return false end

	return screen0:TextInput(utf8, ...)
end


function widget:ViewResize(vsx, vsy)
	screen0:Resize(vsx/(WG.uiScale or 1), vsy/(WG.uiScale or 1))
end

widget.TweakIsAbove	  = widget.IsAbove
widget.TweakMousePress   = widget.MousePress
widget.TweakMouseRelease = widget.MouseRelease
widget.TweakMouseMove	= widget.MouseMove
widget.TweakMouseWheel   = widget.MouseWheel

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
else -- Old Chili
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

Spring.Echo("USE_OLD_CHILI")

local Chili
local screen0
local th
local tk
local tf
local th_Update, tk_Update, tf_Update

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- Chili's location

local function GetDirectory(filepath)
	return filepath and filepath:gsub("(.*/)(.*)", "%1")
end

assert(debug)
local source = debug and debug.getinfo(1).source
local DIR = GetDirectory(source) or ((LUA_DIRNAME or LUAUI_DIRNAME) .."Widgets/")
CHILI_DIRNAME = DIR .. "chili_old/"

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
local slowDownGen = false
local slowDownScreen = false


local list, list2 = false, false
local count, count2 = 0, 0
local lastTime, lastTime2 = os.clock(), os.clock()


-- not really helping
options_path = ''
options_order = {'slowdownScreen','slowdownGen'}
options = {}
options.slowdownScreen = {
	hidden = true,
	name = 'Slow down Chili DrawScreen',
	value = slowDownScreen,
	type = 'bool',
	OnChange = function(self)
		slowDownScreen = self.value
		if not slowDownScreen and list then
			glDeleteList(list)
			list = false
		end
	end,
}
options.slowdownGen = {
	hidden = true,
	name = 'Slow down Chili DrawGenesis',
	value = slowDownGen,
	type = 'bool',
	OnChange = function(self)
		slowDownGen = self.value
		if not slowDownGen and list2 then
			glDeleteList(list2)
			list2 = false
		end
	end,
}


function widget:Initialize()
	Chili = VFS.Include(CHILI_DIRNAME .. "core.lua", nil, VFS.ZIP)

	screen0 = Chili.Screen:New{}
	th = Chili.TextureHandler
	tk = Chili.TaskHandler
	tf = Chili.FontHandler
	th_Update, tk_Update, tf_Update = th.Update, tk.Update, tf.Update

	--// Export Widget Globals
	WG.Chili = Chili
	WG.Chili.Screen0 = screen0

	--// do this after the export to the WG table!
	--// because other widgets use it with `parent=Chili.Screen0`,
	--// but chili itself doesn't handle wrapped tables correctly (yet)
	screen0 = Chili.DebugHandler.SafeWrap(screen0)

end

function widget:Shutdown()
	--table.clear(Chili) the Chili table also is the global of the widget so it contains a lot more than chili's controls (pairs,select,...)
	WG.Chili = nil
	if list then 
		glDeleteList(list)
		list = false
	end
	if list2 then 
		glDeleteList(list2)
		list2 = false
	end

end

function widget:Dispose()
	screen0:Dispose()
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local DrawScreenFunc = function()
	glColor(1,1,1,1)
	if (not screen0:IsEmpty()) then
		glPushMatrix()
			local vsx,vsy = gl.GetViewSizes()
			glTranslate(0,vsy,0)
			glScale(1,-1,1)
			glScale(WG.uiScale,WG.uiScale,1)
			screen0:Draw()
		glPopMatrix()
	end
	glColor(1,1,1,1)
end
function widget:DrawScreen()
	if slowDownScreen then
		count = count + 1
		local now = os.clock()
		if count>30 or now - lastTime > 1 then
			if list then
				glDeleteList(list)
			end

			list = false
			count = 0
			lastTime = now
		end
		if not list then
			list = glCreateList(DrawScreenFunc)
		end
		glCallList(list)
	else
		DrawScreenFunc()
	end
end


function widget:DrawLoadScreen()
	glColor(1,1,1,1)
	if (not screen0:IsEmpty()) then
		glPushMatrix()
			local vsx,vsy = gl.GetViewSizes()
			glScale(1/vsx,1/vsy,1)
			glTranslate(0,vsy,0)
			glScale(1,-1,1)
			screen0:Draw()
		glPopMatrix()
	end
	glColor(1,1,1,1)
end


function widget:TweakDrawScreen()
	glColor(1,1,1,1)
	if (not screen0:IsEmpty()) then
		glPushMatrix()
			local vsx,vsy = gl.GetViewSizes()
			glTranslate(0,vsy,0)
			glScale(1,-1,1)
			glScale(WG.uiScale,WG.uiScale,1)
			screen0:TweakDraw()
		glPopMatrix()
	end
	glColor(1,1,1,1)
end

local DrawGenesisFunc = function()
	glColor(1,1,1,1)
	tf_Update()
	th_Update()
	tk_Update()
	glColor(1,1,1,1)
end

function widget:DrawGenesis()
	if slowDownGen then
		count2 = count2 + 1
		local now = os.clock()
		if count2>30 or now - lastTime2 > 1 then
			if list2 then
				glDeleteList(list2)
			end

			list2 = false
			count2 = 0
			lastTime2 = now
		end
		if not list2 then
			list2 = glCreateList(DrawGenesisFunc)
		end
		glCallList(list2)
	else
		DrawGenesisFunc()
	end
end


function widget:IsAbove(x,y)
	if WG.uiScale and WG.uiScale ~= 1 then
		x, y = x/WG.uiScale, y/WG.uiScale
	end
	if Spring.IsGUIHidden() then
		return false
	end
	local x, y, lmb, mmb, rmb, outsideSpring = Spring.ScaledGetMouseState()
	if outsideSpring then
		return false
	end

	return screen0:IsAbove(x,y)
end


local mods = {}
function widget:MousePress(x,y,button)
	if WG.uiScale and WG.uiScale ~= 1 then
		x, y = x/WG.uiScale, y/WG.uiScale
	end
	if Spring.IsGUIHidden() then return false end

	local alt, ctrl, meta, shift = Spring.GetModKeyState()
	mods.alt=alt; mods.ctrl=ctrl; mods.meta=meta; mods.shift=shift;
	return screen0:MouseDown(x,y,button,mods)
end


function widget:MouseRelease(x,y,button)
	if WG.uiScale and WG.uiScale ~= 1 then
		x, y = x/WG.uiScale, y/WG.uiScale
	end
	if Spring.IsGUIHidden() then return false end

	local alt, ctrl, meta, shift = Spring.GetModKeyState()
	mods.alt=alt; mods.ctrl=ctrl; mods.meta=meta; mods.shift=shift;
	return screen0:MouseUp(x,y,button,mods)
end


function widget:MouseMove(x,y,dx,dy,button)
	if WG.uiScale and WG.uiScale ~= 1 then
		x, y, dx, dy = x/WG.uiScale, y/WG.uiScale, dx/WG.uiScale, dy/WG.uiScale
	end
	if Spring.IsGUIHidden() then return false end

	local alt, ctrl, meta, shift = Spring.GetModKeyState()
	mods.alt=alt; mods.ctrl=ctrl; mods.meta=meta; mods.shift=shift;
	return screen0:MouseMove(x,y,dx,dy,button,mods)
end


function widget:MouseWheel(up,value)
	if Spring.IsGUIHidden() then return false end

	local x,y = Spring.ScaledGetMouseState()
	local alt, ctrl, meta, shift = Spring.GetModKeyState()
	mods.alt=alt; mods.ctrl=ctrl; mods.meta=meta; mods.shift=shift;
	return screen0:MouseWheel(x,y,up,value,mods)
end


local keyPressed = true
function widget:KeyPress(key, mods, isRepeat, label, unicode, scanCode)
	if Spring.IsGUIHidden() then return false end

	keyPressed = screen0:KeyPress(key, mods, isRepeat, label, unicode, scanCode)
	return keyPressed
end


function widget:KeyRelease()
	if Spring.IsGUIHidden() then return false end

	local _keyPressed = keyPressed
	keyPressed = false
	return _keyPressed -- block engine actions when we processed it
end

function widget:TextInput(utf8, ...)
	if Spring.IsGUIHidden() then return false end

	return screen0:TextInput(utf8, ...)
end


function widget:ViewResize(vsx, vsy)
	screen0:Resize(vsx/(WG.uiScale or 1), vsy/(WG.uiScale or 1))
end

widget.TweakIsAbove	  = widget.IsAbove
widget.TweakMousePress   = widget.MousePress
widget.TweakMouseRelease = widget.MouseRelease
widget.TweakMouseMove	= widget.MouseMove
widget.TweakMouseWheel   = widget.MouseWheel

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------



end
