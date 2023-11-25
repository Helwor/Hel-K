
function widget:GetInfo()
	return {
		name      = "AllSleep",
		desc      = "Put all widgets to sleep on widget init, wake all on widgets shutdown",
		author    = "Helwor",
		date      = "May 2023",
		license   = "GNU GPL v2",
		layer     = math.huge, -- Before NoDuplicateOrders
		enabled   = false,
		handler   = true,
	}
end
local Echo = Spring.Echo

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--- this might break some widget that had callins already disabled when put to sleep then reenabled on shutdown of this widget, while they shouldnt be reenabled
--- it's only used for debugging
local ignore = {
	-- those are vital
	[widget:GetInfo().name] = true,
	['Chili Widget Selector'] = true,
	['Chili Framework'] = true,
	['Chili Pro Console'] = true,
	['EPIC Menu'] = true,
	['OnWidgetState'] = true,
	['Set Springsettings and Config'] = true,
	['Shared Functions'] = true,
	['i18n'] = true,
	['Chili Global Commands'] = true,
	['Local Widgets Config'] = true,
	['Simple Settings'] = true,
	['Integral Menu'] = true,
	['Pre-Selection Handler'] = true,
	['HasViewChanged'] = true,
	['MyClicks'] = true,
	['Selection API'] = true,
	-- this is useful to keep on
	['Widget Profiler New'] = true,
	['Cheat Sheet'] = true,
	['Combo Overhead/Free Camera (experimental)'] = true,
	-- those  will crash on reenabling
	['Display Keys 2'] = true,
	['Show selected unit range'] = true,
	['Chili Endgame Window'] = true,
	['Endgame Stats'] = true,
	['Endgame APM stats'] = true,
}
function widget:Initialize()
	for _,widget in pairs(widgetHandler.widgets) do
		local name = widget.whInfo.name
		if not ignore[name] then
			widgetHandler:Sleep(widget)
		end
	end
end

function widget:Shutdown()
	for _,widget in pairs(widgetHandler.widgets) do
		local name = widget.whInfo.name
		if not ignore[name] then
			widgetHandler:Wake(widget)
		end
	end
	widgetHandler:DisableWidget(widget:GetInfo().name)

end
