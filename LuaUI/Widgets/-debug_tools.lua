
function widget:GetInfo()
	return {
		name      	= "Debug Tools",
		desc      	= "gonna move progressively in the WG area",
		author    	= "Helwor",
		date      	= "Nov, 2023",
		license   	= "GNU GPL, v2 or v3",
		layer     	= -math.huge,
		enabled   	= true,
		AlwaysStart = true,
		api		  	= true,
	}
end
local Echo = Spring.Echo
local f = VFS.Include("LuaUI\\Widgets\\UtilsFunc.lua")
--------------------------------------------------------------------------------
-- Speedups
--------------------------------------------------------------------------------




local glText 				= gl.Text
local spWorldToScreenCoords = Spring.WorldToScreenCoords
local spGetSelectedUnits 	= Spring.GetSelectedUnits
local spGetUnitPosition		= Spring.GetUnitPosition
local EMPTY_TABLE			= {}
local format 				= string.format
local glTranslate			= gl.Translate
local glPushMatrix			= gl.PushMatrix
local glPopMatrix			= gl.PopMatrix
local glBillboard			= gl.Billboard

local DrawOnUnits = {
	holders = {},
}

function DrawOnUnits:Run(unitsHolder, useSelected, screen)
	local usedHolder = self.holders[unitsHolder]
	if not usedHolder then
		usedHolder = useSelected and {} or unitsHolder
		self.holders[unitsHolder] = usedHolder
	end
	if useSelected and not next(usedHolder) then
		for i, id in ipairs(spGetSelectedUnits() or EMPTY_TABLE) do
			usedHolder[id] = unitsHolder[id]
		end
	end
	for id, unit in pairs(usedHolder) do
		self:DrawOnUnit(id, unit, screen)
	end
end
function DrawOnUnits:Stop(unitsHolder)
	self.holders[unitsHolder] = nil
end

function DrawOnUnits:DrawOnUnit(id, unit, screen)
	local _,_,_,wx,wy,wz = spGetUnitPosition(id, true)
	if not wx then
		return
	end
	local txtSize, margin = 10, 3
	local size = table.size(unit)
	local even = size%2
	local offY = (size/2 + (even and 1 or 0) * 0.5) * (txtSize + margin)
	if screen then
		local x,y = spWorldToScreenCoords(wx,wy,wz)
		y = y - offY
		for prop, value in pairs(unit) do
			glText(('%s : %s'):format(tostring(prop), tostring(value)), x,y, txtSize)
			y = y + txtSize + margin
		end
	else
        glPushMatrix()
        glTranslate(wx,wy,wz)
        glBillboard()
        local x,y = 0, -offY
		for prop, value in pairs(unit) do
			glText(('%s : %s'):format(tostring(prop), tostring(value)), x,y, txtSize)
			y = y + txtSize + margin
		end
        glPopMatrix()
	end

end

WG.DrawOnUnits = DrawOnUnits


f.DebugWidget(widget)