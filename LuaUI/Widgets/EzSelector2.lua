

local version = '1.0'
function widget:GetInfo()
	return {
		name      = 'EzSelector ' .. version,
		desc      = 'A new and very sophisticated system of selection',
		author    = 'Helwor',
		date      = 'August, 2020',
    	license   = 'GNU GPL, v2 or later',
		layer     = -12, -- formerly 1000, now testing before EzTarget
		enabled   = true,
		handler   = true,
	}
end
local Echo = Spring.Echo
local Units -- attached to WG.UnitsIDCard or WG.Cam.Units in Initialize CallIn


local abs, max = math.abs, math.max

include('keysym.h.lua')
include('keysym.lua')
VFS.Include('LuaRules/Configs/customcmds.h.lua')

-- !!! Add CMD_FIND_PAD , CMD_EXCLUDE PAD , CMD_AUTO_CALL TRANSPORT
include("LuaRules/Configs/customcmds.h.lua")
local resX,resY = Spring.GetScreenGeometry()
local customCmds = VFS.Include("LuaRules/Configs/customcmds.lua")
local KEYSYMS = KEYSYMS
local specialKeys--[[, ToKeysyms--]] = include('Configs/integral_menu_special_keys.lua')
local MODS_FALSE = {shift=false,ctrl=false,meta=false,alt=false,internal=false,coded=0}
local EMPTY_TABLE = {}
local DEFAULT_DRAW_POS = {resX/2-50,resY/2} -- default of draw screen  in non cylinder mode selection info
local DEFAULT_CYLINDER_DRAW_POS = {(resX/2)-50,180}

VFS.Include('LuaUI\\Widgets\\Keycodes.lua')
--include("Widgets/COFCtools/TraceScreenRay.lua")

local f = VFS.Include('LuaUI\\Widgets\\UtilsFunc.lua')

local Page 					  = f.Page
local vunpack 				  = f.vunpack
local kunpack 				  = f.kunpack
local nround 				  = f.nround
local l 					  = f.l
local CheckTime 			  = f.CheckTime
local UniTraceScreenRay 	  = f.UniTraceScreenRay -- failsafe trace screen ray correcting mouse out of map
local Fade = f.Fade
local linesbreak 			  = f.linesbreak
local FullTableToStringCode   = f.FullTableToStringCode
local identical				  = f.identical

local GetCameraHeight		  = f.GetCameraHeight

local spGetUnitsInCylinder    = Spring.GetUnitsInCylinder
local spSelectUnitArray    	  = Spring.SelectUnitArray
local spGetVisibleUnits 	  = Spring.GetVisibleUnits
-- local spGetAllUnits			  = Spring.GetAllUnits
local spSetActiveCommand      = Spring.SetActiveCommand
local spSendCommands 		  = Spring.SendCommands

local spGetTimer 			  = Spring.GetTimer
local spGetModKeyState		  = Spring.GetModKeyState
local spDiffTimers 			  = Spring.DiffTimers
local spGetMyTeamID 		  = Spring.GetMyTeamID
local spGetSpectatingState 	  = Spring.GetSpectatingState
local spIsReplay 			  = Spring.IsReplay
local spValidUnitID 		  = Spring.ValidUnitID
local spGetCommandQueue		  = Spring.GetCommandQueue
local spGetUnitDefID 		  = Spring.GetUnitDefID
local spGetTeamUnits		  = Spring.GetTeamUnits
local spGetMouseState 		  = Spring.GetMouseState
local spGetUnitPosition 	  = Spring.GetUnitPosition
local spGetActiveCommand 	  = Spring.GetActiveCommand
local spGetUnitHealth 		  = Spring.GetUnitHealth
local spGetSelectedUnits      = Spring.GetSelectedUnits
local spGetCameraState        = Spring.GetCameraState
local spGetUnitIsDead 		  = Spring.GetUnitIsDead
local spuGetUnitFireState	  = Spring.Utilities.GetUnitFireState
local spuGetUnitMoveState	  = Spring.Utilities.GetUnitMoveState
local spuMergeTable 		  = Spring.Utilities.MergeTable
local spGiveOrderToUnit		  = Spring.GiveOrderToUnit
local spGetUnitIsActive 	  = Spring.GetUnitIsActive -- specific function used only in the macro table

local spGetUnitTransporter    = Spring.GetUnitTransporter
local spGetUnitIsTransporting = Spring.GetUnitIsTransporting







local round = math.round
local rand,rands = math.random,math.randomseed
local char = string.char
local floor = math.floor
local ceil = math.ceil
local clock = os.clock
local asymp = f.asymp
local remove = table.remove



function table.size(t)
	local count = 0
	for _ in pairs(t) do
		count = count + 1
	end
	return count
end

local glNormal			= gl.Normal
local glVertex			= gl.Vertex
local glPushMatrix		= gl.PushMatrix
local glLineStipple		= gl.LineStipple
local glLineWidth		= gl.LineWidth
local glColor			= gl.Color
local glDrawGroundCircle= gl.DrawGroundCircle
local glTranslate		= gl.Translate
local glBillboard		= gl.Billboard
local glText			= gl.Text
local glPopMatrix		= gl.PopMatrix
local glPointSize		= gl.PointSize
local glBeginEnd		= gl.BeginEnd



local CMD_MOVE = CMD.MOVE

local UnitDefs = UnitDefs





local IM -- Integral Menu

local currentSel = {}
local Cam
local g = { -- mini global, shared variables amongst widget to avoid upvalues limit
	ctrlGroups = {},
	gameStarted = false,
	SelFiltering = EMPTY_TABLE, -- Selection Hierarchy widget
	SM_Enabled = EMPTY_TABLE,
	SM_SwitchOn = false, -- handle of Selection Modkeys enable option to switch it when combo use left click

}

g.ctrlGroups = {
	byKey = {}, -- store the groups per key
	byUnitID = {},
	ticket = 0,
	selecting = false,
	toBeSelected = false,
	nearest = false,
	cfg = {
		selectThreshold = 300,
		uniqueIdPerGrpKey = true,
		deleteWhenSetNothing = true, -- delete all groups of that key if setting a group when none selected
	},
	optSelect = {
		byMostClosestCenter = false, -- if byMostClosestCenter, we can set a same unit on a same ctrlGrpKey but in different groups
		--, but this will be more costly as we have to check position of units to get to know which group is closest from the cursor
		byAreaCatchingMember = true, -- if the area selection catch a unit of that groupKey, it will be selected
	},

}
local ctrlGroups = g.ctrlGroups

function ctrlGroups:Get(key,units)
	local grps = self.byKey[key] or EMPTY_TABLE
	if not units then
		return grps
	end
	local byUnitID = self.byUnitID
	-- local uniquePerKey = self.uniqueIdPerGrpKey
	local common
	if units then
		common = {}
		for i, id in ipairs(units) do
			local grps = byUnitID[id]
			if grps then
				for grp in pairs(grps) do
					if grp.key == key then
						common[grp] = true
					end
				end
			end
		end
		Echo("units got " .. table.size(common) .. ' common groups of the key ' .. key)
	end
	return common or EMPTY_TABLE
end

function ctrlGroups:Delete(grp, key)
	if key then
		Echo('deleting all groups of key ' .. key)
		local byKey = self.byKey[key]
		for grp in pairs(byKey) do
			self:Delete(grp)
		end
		return
	end
	Echo('deleting group #' .. grp.id)
	local byUnitID = self.byUnitID
	local key = grp.key
	local grpUnits = grp.units
	for id, grps in pairs(grpUnits) do -- grps == byUnitID[id]
		grps[grp] = nil

		if not next(grps) then
			Echo('unitID '.. id .. ", doesn't belong to any other group and got deleted")
			byUnitID[id] = nil
		end
	end
	local byKey = self.byKey[key]
	byKey[grp] = nil
	if not next(byKey) then
		Echo('all groups of key ' .. key .. ' has been deleted')
		self.byKey[key] = nil
	end
end

local function GetRandomizedColor(n,alpha)
	-- create random but fixed color
	rands(n) -- random seed based on 3 characteristic of the macro
	local a,b,c=0,0,0
	while (a+b+c)<2.5 do a,b,c=rand(),rand(),rand() end -- get a color with minimal brightness
	return {a,b,c,alpha}
end

function ctrlGroups:New(key,units)
	self.ticket = self.ticket + 1
	local id = self.ticket
	local grp = {key = key, units = {}, id = id, mid = {0,0,0}, color = GetRandomizedColor(id,0.8)}
	local byUnitID = self.byUnitID
	local byKey = self.byKey[key]
	if not byKey then
		byKey = {} ; self.byKey[key] = byKey
	end
	byKey[grp] = true
	local grpUnits = grp.units
	for i, id in ipairs(units) do
		local grps = byUnitID[id]
		if not grps then
			grps = {} ; byUnitID[id] = grps
		end
		grps[grp] = true
		grpUnits[id] = grps
	end
	return grp
end
function ctrlGroups:Expand(grp, units)
	local byUnitID = self.byUnitID
	local grpUnits = grp.units
	for i, id in ipairs(units) do
		if not grpUnits[id] then
			local grps = byUnitID[id]
			if not grps then
				grps = {} ; byUnitID[id] = grps
			end
			grps[grp] = true
			grpUnits[id] = grps
		end
	end
end
function ctrlGroups:Set(key)
	local byKey = self.byKey[key]

	local toDelete
	if not currentSel[1] then
		if byKey and self.cfg.deleteWhenSetNothing then
			self:Delete(nil,key)
		end
	else
		local commonGrps = self:Get(key, currentSel)
		local numCommon = table.size(commonGrps)
		local createNew = false
		local expandGrp, identicalGrp
		local grp
		if numCommon > 0  then
			Echo(numCommon .. ' group ' .. (numCommon > 1 and 's' or '') .. ' containing at least one of the unit already exists')

			local selByID, selSize = {}, 0
			for i, id in ipairs(currentSel) do
				selByID[id] = true
				selSize = selSize + 1
			end
			

			-- see if the common group has unit external to the current sel
			for grp in pairs(commonGrps) do
				local size = table.size(grp.units)
				local expand = size < selSize
				local identical = size == selSize
				if identical or expand then
					for id in pairs(grp.units) do
						if not selByID[id] then
							Echo('common group #' .. grp.id .. ' got also unit(s) external from the selection')
							expand = false
							identical = false
							break
						end
					end
					if expand then
						expandGrp = grp
					end
					if identical then
						identicalGrp = grp
						break
					end
				end
			end
		end
		if identicalGrp then
			Echo('identical group #' .. identicalGrp.id .. ' has been found, deleting it')
			self:Delete(identicalGrp)
		elseif expandGrp then
			Echo('expand existing group #' .. expandGrp.id)
			self:Expand(expandGrp,currentSel)
		else
			local grp = self:New(key,currentSel)
			Echo('create a new group #' .. grp.id )
		end
	end
end


function ctrlGroups:Draw()
	if not self.selecting then
		return
	end
	local byKey = self.byKey[self.selecting]
	if not byKey then
		self.selecting = false
		return
	end
	local threshold = self:GetThreshold()


	local toBeSelected, nearest, poses = ctrlGroups:GetToBeSelected()
	if not poses then
		return
	end
	gl.Color(1,1,1,0.8)

	gl.LineStipple(true)
	gl.LineWidth(1.0)
--[[			for c in pairs(Circles) do
		local x,_,z,_,y = spGetUnitPosition(id,true)
		glPushMatrix()
		glDrawGroundCircle(x, y, z, 40, 40)
		glPopMatrix()
	end--]]
	for grp in pairs(byKey) do
		local width = grp == nearest and 1.75 or 1
		local stipple = grp ~= toBeSelected
		local alpha = grp == toBeSelected and 1 or 0.8
		local color = grp.color
		gl.Color(color[1],color[2],color[3],alpha)
		gl.LineStipple(stipple)
		gl.LineWidth(width)

		local mid = grp.mid
		gl.DrawGroundCircle(mid[1], mid[2], mid[3], threshold, 40)

		for id in pairs(grp.units) do
			local pos = poses[id]
			gl.DrawGroundCircle(pos[1], pos[2], pos[3], 40, 40)
		end
	end
	gl.Color(1, 1, 1, 1)
	gl.LineWidth(1.0)
	gl.LineStipple(false)

	-- show on screen the different groups of that key
end

function ctrlGroups:GetMid(grp, poses)
	local sumx, sumz, cnt = 0, 0, 0
	for id in pairs(grp.units) do
		cnt = cnt + 1

		if not poses[id] then
			local x,_,z,_,y = spGetUnitPosition(id, true)
			poses[id] = {x,y,z}
			-- Echo('pos for id',id,':',x)
		end
		local pos = poses[id]
		sumx, sumz = sumx + pos[1], sumz + pos[3]
	end
	local midx, midz = sumx/cnt, sumz/cnt
	local midy = Spring.GetGroundHeight(midx, midz)
	local mid = grp.mid
	mid[1], mid[2], mid[3] = midx, midy, midz

	return midx, midy, midz
end
function ctrlGroups:GetThreshold()
	local threshold = self.cfg.selectThreshold
	if Cam.dist < 4000 then
		threshold = math.max(threshold * (Cam.dist / 4000), 150)
	end
	return threshold
end
function ctrlGroups:GetToBeSelected()
	if not self.selecting then
		return
	end
	self.toBeSelected = false
	self.nearest = false
	local nearest, toBeSelected
	local byKey = self.byKey[self.selecting]
	if not byKey then
		self.selecting = false
		return
	end
	local threshold = self:GetThreshold()
	local mx,my = spGetMouseState()
	local _, pos = Spring.TraceScreenRay(mx,my, true) -- only coord
	if not pos then
		return
	end
	local mwx, mwz = pos[1], pos[3]
	local minDist = math.huge
	local poses = {}
	for grp in pairs(byKey) do
		local x,y,z = self:GetMid(grp, poses)
		-- local sx,sy = Spring.WorldToScreenCoords(x,y,z)
		-- local dist = (mx - sx)^2 + (mz - sz)^2
		local dist = (mwx - x)^2 + (mwz - z)^2
		if dist < minDist then
			minDist = dist
			nearest = grp
		end
	end
	if not nearest then
		return
	end
	

	self.nearest = nearest
	if minDist^0.5 <= threshold then
		toBeSelected = nearest
		self.toBeSelected = toBeSelected
	end
	return toBeSelected, nearest, poses
end






local last={callcount=0, chained = {}, chainCount = 0, time = os.clock()}




-- for k,v in pairs(customCmds) do
-- 	if k==34221 or v==34221 then
-- 		Echo(k,v)
-- 		break
-- 	end
-- end


local BASE_CAMERA_HEIGHT = 2418
local NO_SELECT_TIMEOUT = {
	[ UnitDefNames['cloakraid'].id ] = 0.2,
	[ UnitDefNames['shieldraid'].id ] = 0.2,
	[ UnitDefNames['vehraid'].id ] = 0.2,
	[ UnitDefNames['cloakassault'].id ] = 6,

}


-- for defID,def in pairs(UnitDefs) do
-- 	for k,v in def:pairs() do
-- 		-- if k:match('jump') then
-- 			Echo(def.name,def.humanName)
-- 		-- end
-- 	end
-- end
------------------------------------------------------------------------------------------------------------
---  CONFIG
------------------------------------------------------------------------------------------------------------
local zoom_scaling = 4 -- divisor to tone down how much the zoom affect the radius

local MAX_SELECTIONS = 20 -- set the maximum Selections you want to memorize
local LONGPRESS_THRESHOLD = 0.3
local DOUBLETAP_THRESHOLD = 0.25
local FASTDOUBLETAP_THRESHOLD = 0
local MOUSE_STILL_THRESHOLD = 15
local NO_SELECT_TIMEOUT_DEFAULT = 3
local currentLongPressTime =  LONGPRESS_THRESHOLD
local currentDoubleTapTime = DOUBLETAP_THRESHOLD
local currentFastDoubleTapTime = FASTDOUBLETAP_THRESHOLD

local copy = function(t) local copy = {} for k,v in pairs(t) do copy[k] = v end return copy end
-- local identical = function(t,t2)
-- 	if t.n~=t2.n then
-- 		return false
-- 	end
-- 	local byID2 = t2.byID
-- 	for id in pairs(t.byID) do
-- 		if not byID2[id] then
-- 			return false
-- 		end
-- 	end
-- 	return true
-- end
local function ByID(t)
	local cnt = 0
	local byID = {}
	for i, id in ipairs(t) do
		byID[id] = true
		cnt = i
	end
	t.byID = byID
	t.n = cnt
	return t
end
local SwitchImpulse = function()
	local cmdDescs = Spring.GetActiveCmdDescs()
	if not cmdDescs then
		return
	end
	local cmdDescImpulseIndex = Spring.GetCmdDescIndex(CMD_PUSH_PULL)
	if not  cmdDescImpulseIndex then
		return
	end
	local impulseState = cmdDescs[cmdDescImpulseIndex].params[1]

	local newState = impulseState=='1' and 0 or 1
	Spring.GiveOrder(CMD_PUSH_PULL,{newState,0},0)
end

-- NOTE Active Commands:
	--75 = LOAD UNITS
local HKCombos={length=0,byName={}}
	--- MACRO SETTING
local hotkeysCombos={
		-- TODO: implement XOR and maybe XNOT operator
		-- TODO: implement group 
		---- example of doubleTap of key use that allows one to select all cons on single tap of 'X' or 'C' or only idle cons on doubleTap with those same keys
		-- here single tap:
--[[		{name='Cons (prefer Idle)',
		method='cylinder', 
		keys={'SPACE','?AIR'}, -- 
		defs={['?']={['class']='conunit','isComm','isAthena'}},
		prefer={defs={'isIdle','!isComm'}}, -- syntaxe: prefer is what it means: it will filter out the found units after checking if at least one match the prefer conditions
		keep_on_fail=true,
		color={0, 1, 0.9,	0.8	},fading=0.6},--]]



		--- DEBUG SHORTCUTS -- work in progress
			{name='Debug Check Requirements',
			option_name='debugcheckreq',
			keys={'LCTRL','LALT','R','?AIR'}, -- 
			color={0.9, 0.9, 0.3, 1},fading=0.8},
			--
			{name='Debug Current Combo',
			option_name='debugcurrentcombo',
			keys={'LCTRL','LALT','O','?AIR'}, -- 
			color={0.9, 0.9, 1.0, 1},fading=0.8},
			--
			{name='Debug Show Names',
			option_name='debugshownames',
			keys={'LCTRL','LALT','N','?AIR'}, -- 
			color={0.4, 0.9, 1.0, 1},fading=0.8},
			--
			{name='Debug Previous',
			option_name='debugprevious',
			keys={'LCTRL','LALT','P','?AIR'}, -- 
			color={0.9, 0.5, 1.0, 1},fading=0.8},
			--

		--------------------
		--- AUTO TRANSPORT
			-- cascading combos, pushing L will order closest transport to pick up selected units, then , ordering them to load the currently selected units, they will follow the selected unit goal location (if any) to unload them
			-- if second call for getting the loaded transport fail, it will run a third call to get any transports 
				--[[{name='Get Transports',
					method='all', 
					from_cursor=true,
					keys={'L','?AIR'}, -- 
					defs={
						['?name']={'gunshiptrans','gunshipheavytrans'}
					},
					set_active_command=CMD_LOADUNITS_SELECTED, -- set active command to autoload selected units on finish 
					prefer={'!isTransporting'},
					on_press=true,
					shift=true,
					force=true,--
					second_call='Get LOADED Transports',
					color={0, 1, 0.5,	0.8	},fading=0.6},
					-- chaining the macro below
					
					{name='Get LOADED Transports', -- this is directly triggered by the macro above
					method='cylinder', 
					from_cursor=true,
					keys={}, -- 
					defs={
						
						['?name']={'gunshiptrans','gunshipheavytrans'}
					},
					prefer={['?']={'isTransporting',['order']=CMD.LOAD_UNITS},},
					force=true,
					on_press=true,
					call_on_fail='Get ANY Transports', -- call this if nothing got selected
					color={0, 1, 0.5,	0.8	},fading=0.6},

					{name='Get ANY Transports',
					method='cylinder', 
					from_cursor=true,
					keys={'SPACE','L','?AIR'}, -- 
					defs={
						['?name']={'gunshiptrans','gunshipheavytrans'}
					},
					force=true,
					color={0, 1, 0.5,	0.8	},fading=0.6},
				--]]

					---- abandoned,  this is not good enough, instead
					-- {name='Jump', 
					-- method='on_selection', 
					-- from_cursor=true,
					-- keys={'?SPACE','?LCTRL','?LSHIFT','LALT'}, -- 
					-- set_active_command='Jump', -- set active command to autoload selected units on finish 
					-- on_press=true,
					-- call_on_success = 'Un-Jump',
					-- no_select = true,
					-- hide= true,
					-- color={0, 1, 0.5,	0.8	},fading=0.6},

					-- {name='Un-Jump',
					-- method='on_selection', 
					-- set_active_command=0, -- set active command to autoload selected units on finish 
					-- force = true,
					-- force_finish = true, -- finish the call even if it should have been just terminated
					-- hide = true,
					-- color={0, 1, 0.5,	0.8	},fading=0.6},

					-------------

					{name='Call Transports',
					method='set_command', 
					-- from_cursor=true,
					keys={'SPACE','?AIR','T'}, -- 
					-- defs={
					-- 	['?name']={'gunshiptrans','gunshipheavytrans'}
					-- 	,'!isTransporting',['!order']=CMD.LOAD_UNITS
					-- },
					-- defs = {},
					set_active_command=CMD_LOADUNITS_SELECTED, -- set active command to autoload selected units on finish 
					-- prefer={'!isTransporting'},
					on_press=true,
					shift=true,
					force=true,--
					call_on_success='Get LOADING Transports',
					call_on_fail='Get LOADED Transports',
					color={0, 1, 0.5,	0.8	},fading=0.6},


					-- chaining the macro below
					{name='Get LOADING Transports', -- this is directly triggered by the macro above
					method='all', 
					on_delay=0.4,
					-- from_cursor=true,
					keys={}, -- 
					defs={
						-- ['?']={'isTransporting',['order']=CMD.LOAD_UNITS},
						name = {'gunshiptrans','gunshipheavytrans'},
						'!isTransporting',['order']=CMD.LOAD_UNITS
					},
					force=true,
					-- on_press=true,
					-- onrelease=true,
					-- continue = true,
					-- keep_on_fail=true,
					-- call_on_fail='Get LOADED Transports', -- call this if nothing got selected
					color={0, 1, 0.5,	0.8	},fading=0.6},


					{name='Get LOADED Transports', -- this is directly triggered by the macro above
					method='cylinder', 
					-- on_delay=0.5,
					-- from_cursor=true,
					keys={}, -- 
					defs={
						-- ['?']={'isTransporting',['order']=CMD.LOAD_UNITS},
						['?name']={'gunshiptrans','gunshipheavytrans'},'isTransporting'
					},
					force=true,
					-- on_press=true,
					-- onrelease=true,
					-- continue = true,
					-- keep_on_fail=true,

					call_on_fail='Get ANY Transports', -- call this if nothing got selected
					color={0, 1, 0.5,	0.8	},fading=0.6},


					{name='Get ANY Transports',
					method='cylinder', 
					from_cursor=true,
					on_press = true,
					keys={'SPACE','L','?AIR'}, -- 
					defs={
						['?name']={'gunshiptrans','gunshipheavytrans'}
					},
					force=true,
					keep_on_fail=true,
					share_radius = 'Get LOADED Transports',
					color={0, 1, 0.5,	0.8	},fading=0.6},

					{name='Set Retreat',
					method='set_command', 
					keys={'SPACE','?AIR','G'}, -- 
					defs={
						['?name']={'gunshiptrans','gunshipheavytrans'}
						,'!isTransporting',['!order']=CMD.LOAD_UNITS
					},
					set_active_command='sethaven', -- set active command to autoload selected units on finish 
					on_press=true,
					force=true,--
					color={0, 1, 0.5,	0.8	},fading=0.6},

		----------------
		----- CONS -----
		----------------

			{name='COM OR CON',
			method='cylinder',-- 'cylinder': units in radius around the mouse cursor 
			-- keys={'?AIR','SPACE'},	 --syntaxe: '?AIR', as combination must be exact for it to work, '?' will be used to make the key/mod optional, in this case: ?AIR means having the AIR lock beeing active or not doesnt matter
			defs={['?'] = {'isComm', class = 'conunit'}}, -- syntaxe: ['?']={} means only one condition in the table of '?' have to be fulfilled
			share_radius = 'Cons (Idle)',
			isTmpLock='AIR',
			byType = 'defID',
			from_cursor = true,
			color={0, 0.8, 0.9,	0.8	},fading=0.6},

			-- {name='COM',
			-- method='cylinder',-- 'cylinder': units in radius around the mouse cursor 
			-- keys={'E','longPress','?AIR'},	 --syntaxe: '?AIR', as combination must be exact for it to work, '?' will be used to make the key/mod optional, in this case: ?AIR means having the AIR lock beeing active or not doesnt matter
			-- defs={'isComm'}, -- syntaxe: ['?']={} means only one condition in the table of '?' have to be fulfilled
			-- share_radius = 'Cons (Idle)',
			-- force = true,
			-- longPressTime = 0.2,
			-- color={0, 0.8, 0.9,	0.8	},fading=0.6},

			-- {name='COM',
			-- method='all',-- 'cylinder': units in radius around the mouse cursor 
			-- from_cursor=true,
			-- want=1,
			-- keys={'E','doubleTap','?AIR'},	 --syntaxe: '?AIR', as combination must be exact for it to work, '?' will be used to make the key/mod optional, in this case: ?AIR means having the AIR lock beeing active or not doesnt matter
			-- defs={'isComm'}, -- syntaxe: ['?']={} means only one condition in the table of '?' have to be fulfilled
			-- -- share_radius = 'Cons (Idle)',
			-- force = true,
			-- longPressTime = 0.2,
			-- color={0, 0.8, 0.9,	0.8	},fading=0.6},


			{name='AIR',
			method='tmpToggle',-- 'cylinder': units in radius around the mouse cursor 
			-- on_press = true,
			keys={'?AIR',{'LClick','RClick'},'SPACE','?doubleTap'}, -- 
			-- ignore_from_sel = true,
			-- force = true,
			color={0, 0.8, 0.9,	0.8	},fading=0.6},


			{name='Com / Funnel',
			method='cylinder',-- 'cylinder': units in radius around the mouse cursor 
			-- on_press = true,
			keys={'?AIR','SPACE'}, -- 
			isTmpLock='AIR', -- this combo also trigger the temporary toggle on the lock AIR
			-- ignore_from_sel = true,
			fail_on_identical = true,
			from_cursor=true,
			defs={['?'] = {'isComm',name='striderfunnelweb'}}, -- syntaxe: ['?']={} means only one condition in the table of '?' have to be fulfilled
			keep_on_fail = true,
			no_force = true,
			byType = 'defID',
			call_on_fail = 'Cons (Idle)',
			try_on_success = 'Cons (Idle)',
			try_takeover_conditions = function(call, acquired) --
				-- Echo("acquired[1],call.time_length is ", acquired[1],call.time_length)
				if call.time_length < 0.3 then
					local curId, tryId = acquired[1], g.acquired[1]
					if not (tryId and curId and spValidUnitID(tryId) and spValidUnitID(curId)) then
						return false
					end
					if last.sel and identical(currentSel,g.acquired) then
						-- Echo('last sel is the same')
						return false
					end
					local tux,tuy,tuz = spGetUnitPosition(tryId)
					local cux, cuy,cuz = spGetUnitPosition(curId)
					-- Echo("id,curId is ", id,curId)
					local mx,my,mz = unpack(call.mouseStart)
					local tryUdist = ((tux-mx)^2 + (tuz-mz)^2) ^0.5
					local curUdist = ((cux-mx)^2 + (cuz-mz)^2) ^0.5
					if tryUdist < curUdist then
						-- Echo('try is closer',os.clock())
						return true
					else
						-- Echo('try is farther',os.clock())
					end
				end
			end,
			share_radius = 'Cons (Idle)',
			-- force = true,
			color={0, 0.8, 0.9,	0.8	},fading=0.6},


			-- {name='Add Idle Cons',
			-- method='cylinder',-- 'cylinder': units in radius around the mouse cursor 
			-- keys={'?AIR','SPACE','TAB','?doubleTap','?spam'},	 --syntaxe: '?AIR', as combination must be exact for it to work, '?' will be used to make the key/mod optional, in this case: ?AIR means having the AIR lock beeing active or not doesnt matter
			-- defs={['?']={['class']='conunit','isComm','isAthena'}}, -- syntaxe: ['?']={} means only one condition in the table of '?' have to be fulfilled
			-- share_radius = 'Cons (Idle)',
			-- shared_switch = 'Cons (Idle)',
			-- shift = true,
			-- force = true,
			-- color={0, 0.8, 0.9,	0.8	},fading=0.6},


			{name='Cons (Idle)',
			method='cylinder', 
			keys={'?AIR','SPACE','doubleTap'},
			-- from_cursor = true,
			isTmpLock='AIR',
			call_on_fail = 'Any Con',

			defs={
				['?']={class='conunit','isAthena'},
				['p:cloakerRadius'] = {0,'nil'},
			},

			-- shift_on_defs = {
			-- 	['?']={class='conunit','isAthena','isComm'},
			-- },
			doubleTap_time = 0.55,
			-- switch={
			-- 	 {'isUnit','isIdle',['?']={['class']='conunit','isComm','isAthena'}}
			-- 	,{'isUnit','!isIdle',['?']={['class']='conunit','isComm','isAthena'}}
			-- },
			--------------------------------------
			-- BYTYPE AND PREVIOUS SYSTEM
			-- alternate between defIDs with the 'previous' system, intelligently repick a different type  if available, in the middle of a call, and remember types that have been selected within .previous_time (default 5 sec)
			-- previous system also care on a per unit basis
			-- indeed, with 'want' when wanting a restricted number of units, it will then cycle through types AND avoid previously selected units
			-- byType can be 'defID','class' or 'family', it is not possible to combine them (I don't see a useful case of mixing 'class' + 'family' )
			-- byType='defID',	

			-- switch = {
			-- 	{'isComm', '!waitManual',['?']={ ['p:facplop']=1, '!manual' } }
			-- 	-- , {'isIdle'}
			-- 	-- , {'autoguard'}
			-- 	-- , { ['!p:cloak_shield']=2, ['?'] = {   {['order']={CMD.GUARD}, '!manual'}, 'isIdle', ['order']={CMD_RAW_MOVE} }   }
			-- 	, {['?']={['class']='conunit','isAthena'}, '!isComm', ['!p:cloak_shield']=2, '!manual', '!waitManual','!building'   }
			-- 	, {['?']={['class']='conunit','isAthena'}, ['!p:cloak_shield']=2, '!manual', '!waitManual'   }
			-- 	-- , {'!isComm', ['!p:cloak_shield']=2, '!waitManual',['?'] = {  '!manual', ['?order']={CMD_RAW_MOVE,CMD.RECLAIM} }   }
			-- 	-- ,{['!p:cloak_shield']=2, ['?']={ }      }  
			-- 	-- ,{['d:isGroundUnit']=true,'isIdle'}
			-- 	-- ,{['d:isGroundUnit']=false,'isIdle'}
			-- 	-- ,{'!isIdle','!manual', '!waitManual'}
			-- 	-- ,{['?']={['class']='conunit','isComm','isAthena'}, '!isIdle'}
			-- 	,{['?']={['class']='conunit','isComm','isAthena'}}
			-- },
			-- shift_on_same_last_call = true,
			switch_time = 0.1,
			add_last_call_pool = true,
			add_last_call_pool_if = 'Com / Funnel',
			-- previous_time = 1,
			-- reset_previous_on_reset_switch = true,
			-- use_prev = true,
			-- no_pick_in_prev = true,
			from_cursor = true,
			groups = {
				-- no building order, no order repairing unfinished build
				-- {'isComm'},
				-- {name='striderfunnelweb'},


				-- {['?'] = {'isIdle',{'!manual'},{order=CMD_RAW_MOVE,['!order']='moveFar'}}},
				-- {'!manual'},
				-- -- no cons ordered manually
				-- {['?'] = {  '!manual', ['?order']={'moveFar',CMD.RECLAIM} }   },
				-- {},
					{
						['?'] = {
							'isIdle',
							{'!manual','!waitManual'},
							{['order']=CMD_RAW_MOVE,['!order']='moveFar',['!hasOrder'] = 'building'}
						},
					},
					-- {},
					-- {
					-- 	order = 'building', ['?'] = {'manual','waitManual'}
					-- },
					-- {
					-- 	hasOrder = 'building'
					-- }
					-- {
					-- 	['?']={'manual','waitManual'}, '!building'
					-- },
					{

						['?']={
							'manual','waitManual',
						},
						{
							['?']={
								['!order']=CMD_RAW_MOVE, order = 'moveFar', hasOrder = 'building'
							}
						}
					},



				-- {['hasOrder'] = {'building',CMD.GUARD}},
				-- cons

				-- {'isComm', '!waitManual',['?']={ ['p:facplop']=1, '!manual',['!hasOrder'] = 'building' } }
				-- , {'isIdle'}
				-- , {'autoguard'}
				-- , { ['!p:cloak_shield']=2, ['?'] = {   {['order']={CMD.GUARD}, '!manual'}, 'isIdle', ['order']={CMD_RAW_MOVE} }   }
				-- , {'!isComm', ['!p:cloak_shield']=2, '!manual', '!waitManual','!building'   }
				-- , {'!isComm', ['!p:cloak_shield']=2, '!manual', '!waitManual'  }

				-- ,{['!p:cloak_shield']=2, ['?']={ }      }  
				-- ,{['d:isGroundUnit']=true,'isIdle'}
				-- ,{['d:isGroundUnit']=false,'isIdle'}
				-- ,{'!isIdle','!manual', '!waitManual'}
				-- ,{'!isIdle'}
			},

			switch_groups = 1, -- delay when repeating that macro will use the next group 
			-- current_to_prev = true, -- merge current sel in prev -- not working well

			-- keep_on_fail: it is what it means, it will keep the previous selection if nothing has been found during the call of the macro
			keep_on_fail = true,
			-- ignore_from_sel=true,

			switch_on_identical = true, -- switch on identical but also the fist matching switch is kept
			fail_on_identical = true,
			-- typeOrder = {
			-- 	'unknown'
			-- },
			-- byType = 'moveType',


			-- byType = 'class',
			-- pref_use_prev = true,
			-- previous_time=0.8,
			-- ignore_from_sel = true,



			-- only_prevTypes = true,
			-- from_cursor = true,
			color={0, 1, 0.9,	0.8	},fading=0.6},

			-- {name='One con (idle)',
			-- method='on_acquired',
			-- keys={'SPACE','?AIR','longPress','mouseStill'},
			-- from_cursor = true,
			-- want = 1,
			-- -- on_press=true,
			-- color={0.5, 0.9, 0.5, 1},fading=1},



			--get all cons on  double tap of the same key:
			{name='All Cons',
			method='cylinder',-- 'cylinder': units in radius around the mouse cursor 
			keys={'?AIR','SPACE','doubleTap','fastDoubleTap','?spam'},	 --syntaxe: '?AIR', as combination must be exact for it to work, '?' will be used to make the key/mod optional, in this case: ?AIR means having the AIR lock beeing active or not doesnt matter
			defs={['?']={['class']='conunit','isComm','isAthena'}}, -- syntaxe: ['?']={} means only one condition in the table of '?' have to be fulfilled
			share_radius = 'Cons (Idle)',
			-- longPressTime = 0.1,
			isTmpLock='AIR',
			fastDoubleTap_time = 0.33,
			force = true,
			color={0, 0.8, 0.9,	0.8	},fading=0.6},


			{name='Any Con',
			method='cylinder',-- 'cylinder': units in radius around the mouse cursor 
			defs={
				['?'] = {
					class='conunit',
					'isComm','isAthena',
					name = 'striderfunnelweb',

				},
			}, -- syntaxe: ['?']={} means only one condition in the table of '?' have to be fulfilled
			share_radius = 'Cons (Idle)',
			-- keep_on_fail = true,
			-- ifSecondary = {keep_on_fail = true},
			keep_on_identical = true,
			color={0, 0.8, 0.9,	0.8	},fading=0.6},
			--[[{name='Com',
				method='cylinder',-- 'cylinder': units in radius around the mouse cursor 
				keys={'SPACE','?AIR','longPress',?mouseStill},	 --syntaxe: '?AIR', as combination must be exact for it to work, '?' will be used to make the key/mod optional, in this case: ?AIR means having the AIR lock beeing active or not doesnt matter
				defs={'isComm'}, 
				keep_on_fail=true,
				color={0, 0.8, 0.9,	0.8	},fading=0.6
				},
			--]]


		--syntaxe: 'aboveN', 'underN', 'equalN'(more ore less 10%) for expressing health% requirement
		--
		----

		-----------------
		-- MIXED UNITS --
		-----------------

			{name='Ground Army / GS / ships',
				method='cylinder',
				keys={'N_1',2},--syntaxe: N_1 (KEYSIMS),  2 (as it appear on keyboard)-- both format work for the comfort of the user
				force_finish = true,
				no_key_order = true,
				-- add units matching those definitions if at least one unit have met the main definition
				add = {name={'shieldshield','amphlaunch'}}, 
				-- backup definitions if no units matching main defs are found yet
				default = {name={'shieldshield','amphlaunch'}},
				-- defs = {['?']={'!isTransport','!isTransported'}},
				-- defs = {'!isTransport','!isTransported',['?'] = {['!name']='cloakaa', {['name']='cloakaa',['!fireState']=0}}   },
				defs = {['?'] = {['!name']='cloakaa', {['name']='cloakaa',['!fireState']=0}}   },
				-- defs={
				-- 	   -- SYNTAXE: OPERATORS NOT and OR 
				-- 	   '!isComm','isUnit','!isAthena', ['!family']='plane', -- '!' means NOT
				-- 	   -- operators can be used before a required property ([!prop]=A, [!prop]={A,B} as below) or before a required condition-value (!c:isComm as above)
				-- 	   -- operators can also be used alone as key to negate or OR the elements of its paired subtable (as below)
				-- 	   -- ['?'] is OR operator, one match in the subtable is enough ,
				-- 	   -- logically you cannot use '?' in key without a subtable as value, that wouldnt make sense
				-- 	   -- in the example below, it literally means we don't want conunit unless it is a funnelweb
				-- 	   ['?']={		['!class']='conunit', ['?name']={'striderfunnelweb'}  	}
				-- 	   -- note: both operator can be mixed together, ['?!']={A,B} will means NOT A OR NOT B
				-- 	   -- here we don't want units having those names
				-- 	  ,['!name']={'spidercrabe','cloakbomb','shieldbomb','jumpbomb','spiderscout','spiderantiheavy'}
					   
				-- 	   -- you can also OR or OR+NOT subsets(subtables of requirements), logically NOTing multiple subsets without OR doesnt make sense
				-- 	   -- for the sake of visibility and simplicity, you don't need to specify ['?']={subest1,subset2}, it will be implictly assumed
				-- 	   -- , instead {subest1,subest2} is enough, see the macro 'One Commando' for an example
				-- },
				-- prefer = {['!family']='gunship',['?']={['!class']='raider',['name']='jumpraid'}},
				switch={
					-- switch definitions until one is matching immediately, if none, the loop will stop once all defs have been tested
					-- the starting switch is incremented at each new call
					{
					   -- SYNTAXE: OPERATORS NOT and OR 
					   -- XAND = {['?'] = {['?name']={'shieldshield','amphlaunch'}, family='ship' } }, -- adding shield if we found something
					   	
					   	['!family']={'gunship','ship','plane'}, -- '!' means NOT
					   	'!isAthena',
					   	'!isComm',
						-- operators can be used before a required property ([!prop]=A, [!prop]={A,B} as below) or before a required condition-value (!c:isComm as above)
						-- operators can also be used alone as key to negate or OR the elements of its paired subtable (as below)
						-- ['?'] is OR operator, one match in the subtable is enough ,
						-- logically you cannot use '?' in key without a subtable as value, that wouldnt make sense
						-- in the example below, it literally means we don't want conunit unless it is a funnelweb

						['?']={  ['!class']={'conunit','raider'}, ['?name']={'striderfunnelweb'}  	},
						-- ,['?!']={'isComm','!isIdle'} -- not is comm unless it is idle
						-- note: both operator can be mixed together, ['?!']={A,B} will means NOT A OR NOT B
						-- subtable means (A AND B) in those cases
						-- here we don't want units having those names
						['!name']={'shieldshield','amphlaunch','amphsupport','tankarty','heavyarty','spidercrabe','cloakbomb','shieldbomb','jumpbomb','amphbomb','spiderscout','spiderantiheavy','striderantiheavy','striderdante','cloakheavyraid'}
						  
						-- you can also OR or OR+NOT subsets(subtables of requirements), logically NOTing multiple subsets without OR doesnt make sense
						-- for the sake of visibility and simplicity, you don't need to specify ['?']={subest1,subset2}, it will be implictly assumed
						-- , instead {subest1,subest2} is enough, see the macro 'One Commando' for an example
					},
					{
						-- XAND = {['?name']={'shieldshield','amphlaunch'}},
						['?family']={'ship'},['!class']={'conunit','raider'}
					},
					{
						-- XAND = {name='shieldshield'},
						['family']='gunship',['!class']={'conunit','raider'},['!name']='gunshipbomb'
					}
					-- ,

					-- {
					-- 	XAND = {class='raider',['!name']={'spiderscout'}},
					-- 	'isUnit',['?name']={'shieldshield'}
					-- }

				},
				switch_time = 0.4,
				call_on_fail = 'Shields with raiders',
				share_radius = 'Ground Army / GS / ships',
				-- call_on_fail = 'Shields with raiders',
				color={1.0, 0.9, 0.9, 0.8},fading=0.6
			},




				{name='Shields with raiders',
				method='cylinder',
				keys={'N_1',4},--syntaxe: N_1 (KEYSIMS),  2 (as it appear on keyboard)-- both format work for the comfort of the user
				
				no_key_order = true,
				-- finish_current_call = true,
				defs={
					['AND'] = { -- 'AND' means we must find those different units together, or none will be selected
						{
							['?name'] = {'shieldshield','shieldassault','shieldcon'}
						},
						{
							['class'] = 'raider', ['!name'] = {'spiderscout','shieldscout'}
						},

					}
					
				},
				-- shift = true,


				share_radius = 'Raiders',
				call_on_fail = 'Shields', 

				color={1.0, 0.9, 0.9, 0.8},fading=0.6},





				{name='Army with raiders',
				method='cylinder',
				keys={'N_1',2,'doubleTap'},--syntaxe: N_1 (KEYSIMS),  2 (as it appear on keyboard)-- both format work for the comfort of the user
				shift = true,

				defs={
					   -- SYNTAXE: OPERATORS NOT and OR 
					   '!isComm','isUnit','!isAthena', ['!family']='plane', -- '!' means NOT
					   -- operators can be used before a required property ([!prop]=A, [!prop]={A,B} as below) or before a required condition-value (!c:isComm as above)
					   -- operators can also be used alone as key to negate or OR the elements of its paired subtable (as below)
					   -- ['?'] is OR operator, one match in the subtable is enough ,
					   -- logically you cannot use '?' in key without a subtable as value, that wouldnt make sense
					   -- in the example below, it literally means we don't want conunit unless it is a funnelweb
					   ['class']='raider'
					   -- note: both operator can be mixed together, ['?!']={A,B} will means NOT A OR NOT B
					   -- here we don't want units having those names
					  ,['!name']={'spiderscout','shieldscout'}
					   
					   -- you can also OR or OR+NOT subsets(subtables of requirements), logically NOTing multiple subsets without OR doesnt make sense
					   -- for the sake of visibility and simplicity, you don't need to specify ['?']={subest1,subset2}, it will be implictly assumed
					   -- , instead {subest1,subest2} is enough, see the macro 'One Commando' for an example
				},

				color={1.0, 0.9, 0.9, 0.8},fading=0.6
			},
			-- 	{name='Army with raiders',
			-- 	method='cylinder',
			-- 	keys={'N_1',2,'doubleTap'},--syntaxe: N_1 (KEYSIMS),  2 (as it appear on keyboard)-- both format work for the comfort of the user
				

			-- 	defs={
			-- 		   -- SYNTAXE: OPERATORS NOT and OR 
			-- 		   '!isComm','isUnit','!isAthena', ['!family']='plane', -- '!' means NOT
			-- 		   -- operators can be used before a required property ([!prop]=A, [!prop]={A,B} as below) or before a required condition-value (!c:isComm as above)
			-- 		   -- operators can also be used alone as key to negate or OR the elements of its paired subtable (as below)
			-- 		   -- ['?'] is OR operator, one match in the subtable is enough ,
			-- 		   -- logically you cannot use '?' in key without a subtable as value, that wouldnt make sense
			-- 		   -- in the example below, it literally means we don't want conunit unless it is a funnelweb
			-- 		   ['?']={		['!class']='conunit', ['name']={'striderfunnelweb'}  	}
			-- 		   -- note: both operator can be mixed together, ['?!']={A,B} will means NOT A OR NOT B
			-- 		   -- here we don't want units having those names
			-- 		  ,['!name']={'cloakbomb','shieldbomb','jumpbomb','gunshipbomb','spiderscout','spiderantiheavy','striderantiheavy','striderdante'}
					   
			-- 		   -- you can also OR or OR+NOT subsets(subtables of requirements), logically NOTing multiple subsets without OR doesnt make sense
			-- 		   -- for the sake of visibility and simplicity, you don't need to specify ['?']={subest1,subset2}, it will be implictly assumed
			-- 		   -- , instead {subest1,subest2} is enough, see the macro 'One Commando' for an example
			-- 	},
			-- 	prefer = { {['!family']='ship'}, {['!family']='gunship'} },
			-- 	-- in the example above, we prefer not having gunship nor raiders in the selection, unless there is nothing else matching the above criteria

			-- 	color={1.0, 0.9, 0.9, 0.8},fading=0.6
			-- },



			--[[{name='Army with cons',
					method='cylinder',
					--note: longPress is inclusive and woke (aswell as 'longClick'), it does not invalidate a combo unless there is one with the same keys + the 'longPress' tag as this one does. 															///// J/k, I hate liberals.
					-- with longPress, you can set 'mouseStill' or '?mouseStill' wether you require the mouse to stay still once the key is pushed or don't care
					keys={1,2,'LClick'},
					

					defs={'isUnit',['!family']='plane',
						   -- syntaxe: ['?'] is OR operator, one match in the subtable is enough , '!' before a requirement means NOT
						   -- note: you can also use ['!'] and ['?!'] as key for subtables for their respective operation ['?!']={A,B} will means NOT A OR NOT B
						   -- in this example, it literally means we don't want conunit unless it is a funnelweb
						  ['!name']={'cloakbomb','shieldbomb','staticshield','staticradar','staticjammer','spiderscout',}},
					--syntaxe: '!' to prohibit certain units
					--syntaxe: 'aboveN', 'underN', 'equalN'(more ore less 10%) for expressing health% requirement
					prefer = {['!family']='gunship'},
					color={1.0, 0.9, 0.9, 0.8},fading=0.6
			},--]]

			-- {name='Ground Combat without Cloaker',
			-- 		method='cylinder',
			--		no_key_order = true,
			-- 		keys={'N_1','N_2'},
			-- 		defs={
			-- 			'isUnit','!isComm'
			-- 			,['!family']={'plane','ship','gunship'}
			-- 			,['!class']={'conunit','raider'}
			-- 			,['!name']={'cloakbomb','shieldbomb','jumpbomb','cloakjammer','striderantiheavy','spiderantiheavy','striderdante'}},
			-- 		color={1.0, 0.9, 0.9, 0.8},fading=0.6
			-- },
			


			{name='Army and Cons',
				method='cylinder',

				keys={'N_1','N_2','LClick','?doubleLClick'},
				defs={'!isComm',['!family']='plane','isUnit',['!name']={'cloakbomb','shieldbomb','staticradar','striderdante','cloakheavyraid'}},
				force = true,
 			 	share_radius = 'Ground Army / GS / ships',
				color={1.0, 0.9, 0.9, 0.8},fading=0.6},

			{name='Ground Combat slow',
				method='cylinder',
				keys={'SPACE','N_1',2,'?AIR'},
				defs={'isUnit','!isComm'
					,['!family']='plane','isUnit'
					,['!class']={'conunit','raider'}
					,['!name']={'cloakbomb','shieldbomb','staticradar','staticjammer','striderantiheavy','spiderantiheavy','striderdante'}},
				color={1.0, 0.9, 0.9, 0.8},fading=0.6
			},


		------------------
		-- CYCLE
		-- Possibility to Cycle through different Macros under the same combination
			-- {name='Roaming',
			--  method='cycle',
			-- keys={'LALT','N_2','?AIR','?doubleTap','?spam'},
			-- time=5, -- cycle can reset overtime if wanted
			-- cycle={'Halt','Roaming MIN','Roaming MAX'}}, -- name the different macros beeing part of the cycle

			-- -----BRUSH ORDER IN CYCLE
			-- -- brush_order: sending command on wanted units without selecting them
			-- -- with the cycle method, we shall not set any keys for the following macros
			-- {name='Halt',
			-- method='cylinder',
			-- defs={'isUnit'},
			-- brush_order = {[CMD.MOVE_STATE]={0,0}}, -- CMD and param given directly to units covered by the method, without selecting them
			-- keep_on_fail = true, -- keep the previous selection
			-- color={0.8, 0.6, 0.0, 0.9  },	fading=0.6},

			-- {name='Roaming MIN', -- this name will be shown on screen
			-- method='cylinder',
			-- defs={'isUnit'},
			-- brush_order = {[CMD.MOVE_STATE]={1,0}},
			-- keep_on_fail = true, -- keeping previously selected units as we don't want selecting anything with this macrto, just apply some orders
			-- color={0.0, 1.0, 1, 0.9  },	fading=0.6},

			-- {name='Roaming MAX',
			-- method='cylinder',
			-- defs={'isUnit'},
			-- brush_order = {[CMD.MOVE_STATE]={2,0}},
			-- keep_on_fail = true,
			-- color={0.0, 1.0, 0.0, 0.9  },	fading=0.6},
		------------------------------
		-----------------------------

			-- brush hold fire on already acquired units, or fire at will if they are all already held
			{name='Hold Fire',
			method='on_selection',
			keys={'LALT','N_2','?AIR','?doubleTap','?spam'},
			force=true,
			defs={['fireState']={1,2},['d:canAttack']=true},
			hasStructure = true,
			on_press = true,
			brush_order = {[CMD.FIRE_STATE]={0,0}}, -- CMD and param given directly to units covered by the method, without selecting them 
			call_on_fail='Fire At Will', -- if no unit got fire at will unless it cannot attack, this call will be considered failed and then jumping to Fire At Will macro
			color={0.8, 0.6, 0.0, 0.9  },	fading=0.6},


			{name='Fire At Will',
			method='on_selection',
			brush_order = {[CMD.FIRE_STATE]={2,0}}, -- CMD and param given directly to units covered by the method, without selecting them
			force= true,
			hasStructure = true,
			color={0.8, 0.6, 0.5, 0.9  },	fading=0.6},

			-- same with move state
			{name='Hold Position',
			method='on_selection',
			keys={'LALT','UNKNOWN','?AIR','?doubleTap','?spam'},
			force=true,
			defs={['!moveState']=0--[[,['d:canAttack']=true--]]},
			on_press = true,
			brush_order = {[CMD.MOVE_STATE]={0,0}}, -- CMD and param given directly to units covered by the method, without selecting them 
			second_call = 'AI OFF',

			call_on_fail='Maneuver', -- if no unit got fire at will unless it cannot attack, this call will be considered failed and then jumping to Fire At Will macro
			color={0.8, 0.6, 0.0, 0.9  },	fading=0.6},


			{name='Maneuver',
			method='on_selection',
			brush_order = {[CMD.MOVE_STATE]={1,0}}, -- CMD and param given directly to units covered by the method, without selecting them
			force= true,
			second_call = 'AI ON',
			color={0.8, 0.6, 0.5, 0.9  },	fading=0.6},

			{name='AI OFF',
			method='on_selection',
			defs = {['!name']='vehraid'},
			brush_order = {[customCmds.UNIT_AI]={0,0}}, -- CMD and param given directly to units covered by the method, without selecting them
			force= true,
			color={0.8, 0.6, 0.5, 0.9  },	fading=0.6},

			{name='AI ON',
			method='on_selection',
			brush_order = {[customCmds.UNIT_AI]={1,0}}, -- CMD and param given directly to units covered by the method, without selecting them
			force= true,
			color={0.8, 0.6, 0.5, 0.9  },	fading=0.6},


		--[[
			{name='Fire State',
			 method='cycle',
			keys={'LALT','N_3','?AIR','?doubleTap'},
			time=5, -- cycle can reset overtime if wanted
			cycle={'Stop Fire','Riposte','Fire At Will'}},

			-----BRUSH ORDER IN CYCLE
			-- brush_order: sending command on wanted units without selecting them
			-- with the cycle method, we shall not set any keys for the following macros
			{name='Stop Fire',
			method='cylinder',
			defs={},
			brush_order = {[CMD.FIRE_STATE]={0,0}}, -- CMD and param given directly to units covered by the method, without selecting them
			keep_on_fail = true, -- keep the previous selection
			color={0.8, 0.6, 0.0, 0.9  },	fading=0.6},

			{name='Riposte', 
			method='cylinder',
			defs={},
			brush_order = {[CMD.FIRE_STATE]={1,0}},
			keep_on_fail = true,
			color={0.0, 1.0, 1, 0.9  },	fading=0.6},

			{name='Fire At Will',
			method='cylinder',
			defs={},
			brush_order = {[CMD.FIRE_STATE]={2,0}},
			keep_on_fail = true,
			color={0.0, 1.0, 0.0, 0.9  },	fading=0.6},
		--]]
		------------------------------
		------------------------------


		-----------
		---- SNIPER
		-----------
			{name='One Sniper',  -- select one sniper and cycle through each of them on each trigger
			method='cylinder',
			defs={['?name']={'cloaksnipe','spiderantiheavy','amphlaunch', 'hoverarty','jumpblackhole'}}, 
			
			-- syntaxe : !: values in the table must not be true
			-- syntaxe: ['reload']={weapnumber1,weapnumber2...} or ['reload']=weapnumber  for the weapon(s) to be reloaded
			keys={'N_3','LClick'},
			-- prefer={ {['reload']=1}},
			want=1, -- can specify the number you want to select, will cycle through valid units
			previous_time=1,
			from_cursor=true, -- close of cursor
			force=true},
			

			
			{name='Snipers', -- select all on double click
			method='cylinder',
			-- defs={['?name']={'cloaksnipe','amphlaunch', 'hoverarty','jumpblackhole'}},
			--params={['!order']={CMD.ATTACK,CMD.PATROL,CMD.FIGHT}},
			-- syntaxe : !: values in the table must not be true
			share_radius = 'One Sniper',
			same_units = true,
			force = true,
			keys={'N_3','LClick','doubleLClick','?spam'}
			},

			----------- Lobs
			{name='Lob'
			,method='cylinder'
			,keys={'LALT','E'}

			,from_cursor = true
			,defs={
				'isUnit'
				,['name']='amphlaunch'
			}
			,prefer = {
				['reload']=1
			}
			,want=1
			,force=true
			,disable_SM=true -- disable the selection mod keys widget for this call because this combo is a fall back of another using left click
							  -- and we don't want Selection Modkey widget to select unwanted unit under cursor on release
			--continue=true, --reset future selection at each update round
			
			,color={0.9, 0.9, 0.1, 1},fading=0.8},
			{name='All Lobs' 
			,method='cylinder'
			,keys={'LALT','E','?doubleTap','longPress'}

			,from_cursor = true
			,defs={
				'isUnit'
				,['name']='amphlaunch'
			}
			,force=true
			,longPressTime = 0.15
			,disable_SM=true -- disable the selection mod keys widget for this call because this combo is a fall back of another using left click
							  -- and we don't want Selection Modkey widget to select unwanted unit under cursor on release
			--continue=true, --reset future selection at each update round
			
			,color={0.9, 0.9, 0.1, 1},fading=0.8},



			{name='One More Lob' -- this doesn't have keys because it is a fall back call of 'One Bomb' below
			,method='cylinder'
			,keys={'LALT','E','doubleTap'}
			,from_cursor = true
			,defs={
				'isUnit'
				,['name']='amphlaunch'
				,['reload']=1
			}
			,want=1
			,shift=true
			,force=true
			,disable_SM=true -- disable the selection mod keys widget for this call because this combo is a fall back of another using left click
							  -- and we don't want Selection Modkey widget to select unwanted unit under cursor on release
			--continue=true, --reset future selection at each update round
			
			,color={0.9, 0.9, 0.1, 1},fading=0.8},

		--------------
		---- ANTI SUB 
		--------------

			-- {name='Sub / AntiSub', -- this doesn't have keys because it is a fall back call of 'One Bomb' below
			-- method='cylinder',
			-- switch={
			-- 	{['name']={'shiptorpraider'}},
			-- 	{['name']={'subraider'}},
			-- },
			-- switch_time=1,
			-- force=true,
			-- disable_SM=true, -- disable the selection mod keys widget for this call because this combo is a fall back of another using left click
			-- 				  -- and we don't want Selection Modkey widget to select unwanted unit under cursor on release
			-- --continue=true, --reset future selection at each update round
			-- share_radius = 'One Bomb',
			-- color={0.9, 0.9, 0.1, 1},fading=0.8},


			{name='Sub', -- this doesn't have keys because it is a fall back call of 'One Bomb' below
			method='cylinder',
			defs={
				{['name']={'subraider'}},
			},
			force=true,
			disable_SM=true, -- disable the selection mod keys widget for this call because this combo is a fall back of another using left click
							  -- and we don't want Selection Modkey widget to select unwanted unit under cursor on release
			--continue=true, --reset future selection at each update round
			share_radius = 'One Bomb',
			color={0.9, 0.9, 0.1, 1},fading=0.8},


		---------------------
		---- CLOAKED ROACHES
		---------------------
			-- same fashion a bit more sophisticated to work with cloaked roaches strategy:


			-- 1+LClick : select one bomb that is not already attacking, close from the cursor
			{name='One Bomb', 
			method='cylinder',
			keys={'?AIR','N_1','LClick'},
			byType='defID', -- alternate between defid if they differ
			defs={
				['?'] = {
					['?name']={'shieldbomb','cloakbomb','amphbomb','gunshipbomb','jumpbomb',},
					{ name={'gunshiptrans','gunshipheavytrans'},'!isTransporting' }
				}
			},

			-- keys={'?SPACE','N_1','LClick'},
			-- prefer={{['!order']={CMD.ATTACK,CMD.PATROL,CMD.FIGHT}}},-- preferably not fighting
			want=1, -- can specify the number you want to select, will cycle through valid units
			force=true,
			from_cursor=true, -- get the closest of cursor
			on_press = true,
			previous_time=DOUBLETAP_THRESHOLD,
			disable_SM=true,
			call_on_fail = 'Sub'}, -- call this macro if nothing found
			
			-- 1+double LClick: add more and more bombs as long as you spam clicks
			{name='+1 Bomb', 
			method='cylinder',

			must_have = {
				['?'] = {
					['?name']={'shieldbomb','cloakbomb','amphbomb','gunshipbomb','jumpbomb'},
					{ name={'gunshiptrans','gunshipheavytrans'},'!isTransporting' }
				}
			},
			keys={'?AIR','N_1','LClick','doubleLClick','?spam'},
			-- prefer={['!order']={CMD.ATTACK,CMD.PATROL,CMD.FIGHT}}, -- don't pickup bomb that have been sent to attack except if it's the only ones available
			shift=true, -- don't deselected the previous selection which will be bombs in this case
			want='5%',
			force=true,
			from_cursor = true,
			same_units=true,
			same_transported_state = true,
			same_transporting_state = true,
			share_radius = 'One Bomb',
			disable_SM=true,
			-- call_on_fail = 'Sub',
			shared_prev='One Bomb',}, -- use same 'previous' table as the cited macro


			-- 1+double LClick: add more and more bombs as long as you spam clicks
			{name='all Bombs', 
			method='cylinder',
			must_have = {
				['?'] = {
					['?name']={'shieldbomb','cloakbomb','amphbomb','jumpbomb','gunshipbomb'},
					{ name={'gunshiptrans','gunshipheavytrans'},'!isTransporting' }
				}
			},
			keys={'?AIR','N_1','LClick','longClick','?doubleLClick','?spam'},
			prefer={['!order']={CMD.ATTACK,CMD.PATROL,CMD.FIGHT}}, -- don't pickup bomb that have been sent to attack except if it's the only ones available
			force=true,
			same_units=true,

			share_radius = 'One Bomb',
			longPressTime=0.1,
			}, -- use same 'previous' table as the cited macro


			-- 1+RClick: get a group of jammer + bombs, if no bomb found, we pick any units under area cloak, except for fleas


			-------------------------
			---- Cloaked Stuff system


			{name='Cloaker'
			,method='cylinder'
			,from_cursor=true
			,keys={'?AIR','N_1','RClick'}
			,defs={	['p:cloak_shield']=2,[spGetUnitIsActive]=true}
			,prefer = {'isUnit'}
			,force=true
			-- ,on_press=true
			,want=1
			,call_on_success = 'Cloaked Group'
			,call_on_fail = 'Set Cloaker'
			,hasStructure = true
			,no_prev = true
			-- ,radius = 300,
			-- ,previous_time=0.2
			,share_radius = 'Shields'
			},

			{name='More Cloakers'
			,method='cylinder'
			,add_last_acquired = true
			-- ,from_cursor=true
			,keys={'?AIR','N_1','RClick','longClick'}
			,defs={	['p:cloak_shield']=2,[spGetUnitIsActive]=true}
			,prefer = {'isUnit'}
			,force=true
			-- ,on_press=true
			,call_on_success = 'Cloaked Group'

			-- ,call_on_fail = 'Set Cloaker'
			,no_prev = true
			-- ,previous_time=0.2
			-- ,shift = true
			-- ,remove_from_sel = true
			,longPressTime = 0.15
			,hasStructure = true
			,share_radius = 'Shields'
			},

			{name='Cloaker Alone',
			method='cylinder',
			from_cursor=true,
			keys={'?AIR','N_1','RClick','longClick','mouseStill'},
			defs={	['p:cloak_shield']=2,[spGetUnitIsActive]=true},
			prefer = {'isUnit'},
			force=true,
			on_press=true,
			want=1,
			-- previous_time=0.2,
			-- shared_prev = 'Cloaker',
			share_radius = 'Shields',
			hasStructure = true,
			no_prev = true,
			longPressTime = 0.1,
			},

			{name='Cloaker Alone',
			method='cylinder',
			keys={'?AIR','N_1','RClick','doubleRClick'},
			defs={	['p:cloak_shield']=2,[spGetUnitIsActive]=true},
			prefer = {'isUnit'},
			force=true,
			hasStructure = true,
			-- previous_time=0.2,
			-- shared_prev = 'Cloaker',
			no_prev = true,
			share_radius = 'Shields',
			},


			{name='Cloaked Group',
			method='around_last_acquired',
			add_last_acquired = true,
			-- ,pos_from_selected = true
			on_press = true,
			default = {},
			defs = {
				['p:cloakerRadius'] = {0,'nil'},
				['p:areacloaked']=1,
			},
			switch={	-- # any non attacking bomb and cloaker
				{  
					-- XAND = {name='cloakaa',['fireState']=0 }
					-- ,
					-- ['!class']={'conunit'},
						-- bombs that are not attacking
					name={'shieldbomb','cloakbomb','amphbomb','gunshipbomb','jumpbomb'},
					-- ['!order']={CMD.ATTACK,CMD.PATROL,CMD.FIGHT} ,
				},
					-- lobster
				{  
					['XAND'] = {
						['p:areacloaked']=1,
						['?name']={'hoverdepthcharge'}
					},
					['!class']={'conunit','skirm'},
						-- bombs that are not attacking
					{ ['name']={'amphlaunch'} },
				},
				{
				-- #2 any non con/bomb/raider unit under cloak
					XAND = {name='cloakaa',['fireState']=0 },
					-- ,
					'!isPlane','!isComm',
					['!class']={'raider','conunit','skirm','arty'},
					['!name']={'shieldbomb','cloakbomb','amphbomb','gunshipbomb','jumpbomb','cloaksnipe','cloakheavyraid','striderantiheavy','spiderantiheavy','spidercrabe','cloakarty'},
				},

				-- #3 raiders only, no fleas
				{
					['XAND'] = {
						['p:areacloaked']=1,
						['?name']={'hoverdepthcharge'}
					},
					-- ,
					'!isPlane','!isComm',
					['class']={'raider'},
					['!name']='spiderscout',
				},

				-- {
				-- 	'nothing'
				-- }
			},
			shift = true,
			radius = 500,
			fixed_radius = true,

			switch_time = 1,
			},

			-----------------------------
			-----------------------------



			{name='Cloak Off' -- Pick a deactivated cloaker and activate it if we didnt find activated one
			,method='on_selection'
			,keys = {'?AIR','LALT',1,'?RClick'}
			,defs={'isUnit', ['?'] = { ['p:cloak_shield']={2}} }
			,on_press=true
			,give_order={[CMD_CLOAK_SHIELD]={0,0}} -- activate the cloak shield, activate the cloak jammer if any
			,force=true
			,keep_on_fail=true
			,call_on_fail = 'Cloak On'
			,hasStructure = true
			-- same_units=true,
			}, -- use same 'previous' table as the cited macro

			{name='Cloak On' -- Pick a deactivated cloaker and activate it if we didnt find activated one
			,method='on_selection'
			,defs={['?'] = { ['?p:cloak_shield']={0,1}, {['?p:cloak_shield']=2,[spGetUnitIsActive]=false }} }
			,on_press=true
			,brush_order={[CMD_CLOAK_SHIELD]={1,0},[CMD_WANT_ONOFF]={1,0}} -- activate the cloak shield, activate the cloak jammer if any
			,force=true
			,keep_on_fail=true
			,call_on_fail = 'Switch Impulse'
			,hasStructure = true
			-- same_units=true,
			}, -- use same 'previous' table as the cited macro


			{name='Switch Impulse' -- Pick a deactivated cloaker and activate it if we didnt find activated one
			,method='on_selection'
			,defs={'isImpulse'}
			,no_select = true
			,on_press=true
			-- ,give_order={[CMD_CLOAK_SHIELD]={1,0},[CMD_WANT_ONOFF]={1,0}} -- activate the cloak shield, activate the cloak jammer if any
			,force=true
			,hasStructure = true
			,OnSuccessFunc = SwitchImpulse
			-- same_units=true,
			}, -- use same 'previous' table as the cited macro

			{name='High Prio' -- Pick a deactivated cloaker and activate it if we didnt find activated one
			,keys = {'?AIR','LALT',3}
			,method='on_selection'
			,defs={'d:canRepair', ['!p:buildpriority']=2 }
			,on_press=true
			,brush_order={[customCmds.PRIORITY]={2,0}} -- activate the cloak shield, activate the cloak jammer if any
			,force=true
			,keep_on_fail=true
			,call_on_fail = 'Normal Prio'
			,hasStructure = true
			-- same_units=true,
			}, -- use same 'previous' table as the cited macro

			{name='Normal Prio' -- Pick a deactivated cloaker and activate it if we didnt find activated one
			,method='on_selection'
			,defs={'d:canRepair', ['!p:buildpriority']=1 }
			,on_press=true
			,brush_order={[customCmds.PRIORITY]={1,0}} -- activate the cloak shield, activate the cloak jammer if any
			,force=true
			,keep_on_fail=true
			,hasStructure = true
			,call_on_fail = 'Misc High'

			-- same_units=true,
			}, -- use same 'previous' table as the cited macro

			{name='Misc High' -- Pick a deactivated cloaker and activate it if we didnt find activated one
			,method='on_selection'
			,defs={ ['p:miscpriority']={1,0} }
			,on_press=true
			,brush_order={[customCmds.MISC_PRIORITY]={2,0}} -- activate the cloak shield, activate the cloak jammer if any
			,force=true
			,keep_on_fail=true
			,hasStructure = true
			,call_on_fail = 'Misc Normal'
			-- same_units=true,
			}, -- use same 'previous' table as the cited macro

			{name='Misc Normal' -- Pick a deactivated cloaker and activate it if we didnt find activated one
			,method='on_selection'
			,defs={ ['p:miscpriority']={2,0} }
			,on_press=true
			,brush_order={[customCmds.MISC_PRIORITY]={1,0}} -- activate the cloak shield, activate the cloak jammer if any
			,force=true
			,keep_on_fail=true
			,hasStructure = true
			-- same_units=true,
			}, -- use same 'previous' table as the cited macro


			{name='Morph' -- Pick a deactivated cloaker and activate it if we didnt find activated one
			,method='on_selection'
			,keys = {'?AIR','LCTRL','doubleTap'}
			,defs={  }
			,on_press=true
			,brush_order={[customCmds.MORPH]={EMPTY_TABLE,0}} -- activate the cloak shield, activate the cloak jammer if any
			,force=true
			,keep_on_fail=true
			,hasStructure = true
			,doubleTap_time = 0.33
			-- same_units=true,
			}, -- use same 'previous' table as the cited macro


			{name='Set Cloaker' -- Pick a deactivated cloaker and activate it if we didnt find activated one
			,method='cylinder'
			,from_cursor=true
			,defs={
				['?'] = {
					['?p:cloak_shield']={0,1}
					,{['?p:cloak_shield']=2,[spGetUnitIsActive]=false }
				}
			}
			,prefer = {'isUnit'}
				-- NOTE: 0 is when cloak shield is fully disabled, 1 is when cloak shield is getting disabled BY USER
				--, 2 is when it is at max or augmenting
				-- if cloak jammer is getting stunned while cloak shield is on, the cloak_shield state is still 2 even though it is getting disabled non user action
				-- the cloak shield for cloak jammer is depending on ON OFF state and cloak shield state, but the shield state report 2 even if jammer is OFF
				-- so we check also for if the unit is active
			,on_press=true
			-- ,call_on_success = 'Cloaked Group'
			-- ignore_from_sel=true, -- remove from possible units those that are already selected, this to prevent priority2 to get overriden by units already selected

			,give_order={[CMD_CLOAK_SHIELD]={1,0},[CMD_WANT_ONOFF]={1,0}} -- activate the cloak shield, activate the cloak jammer if any
			,want=1
			,force=true
			,keep_on_fail=true
			,hasStructure = true
			-- same_units=true,
			,call_on_fail = "Shields"
			,share_radius = 'Cloaker'
			,shared_prev='Cloaker'}, -- use same 'previous' table as the cited macro





		------------
		-- COMMANDO
		------------
			-- select commandos in radius with 3+Right click
			-- long click will select all commandos
			-- multiple click will select one more same type commando, preferably unloaded
			-- except for scythes, when all will be selected in radius at once at second click
			{name='One Commando', -- stealth and close combat units
				method='cylinder',
				force_finish = true,
				keys={'?SPACE', '?AIR','N_3','RClick'},
				from_cursor=true,
				-- NOTE: to fasten search, precise a broader boolean category ('isUnit' here) as first index to avoid the four OR statements check on useless structures
				defs={'isUnit',['?name']={'cloakheavyraid','striderscorpion','striderantiheavy','spiderantiheavy'}},
				prefer={	{['?']={ -- Note: this is not with priority in contrary to the Cons (idle) macro (no different subsets), thanks to byType=defID, it will alternate through unit type, but it will not pick any unloaded
											{['name']='striderscorpion',['reload']=3},
											{['name']='spiderantiheavy'--[[,['reload']=1--]]},
											['?name']={'cloakheavyraid','striderantiheavy'},
							}},
						{'isUnit'}
				},
				byType='defID', -- alternate between defIDs
				-- typeOrder = 'byClosest',

				selname=true, -- show the unit name instead of the macro name
				want=1,
				pref_use_prev = true,
				previous_time = 0.5,
				color={0.6, 0.9, 0.85, 0.99},fading=0.5
			},


			{name='More Commando(s)', 
				method='cylinder',
				keys={'?AIR','?SPACE', 'N_3','RClick','doubleRClick','?spam'},
				from_cursor=true,
				defs={'isUnit',['?name']={'cloakheavyraid','striderscorpion','striderantiheavy','spiderantiheavy'}},
				prefer={	{['?']={ -- Note: this is not with priority in contrary to the Cons (idle) macro (no different subsets), thanks to byType=defID, it will alternate through unit type, but it will not pick any unloaded
											{['name']='striderscorpion',['reload']=3},
											{['name']='spiderantiheavy',['reload']=1},
											['?name']={'cloakheavyraid','striderantiheavy'},
							}},
						{'isUnit'}
				},
				same_units=true, -- picking same units name as current selection, if we have something in the selection

				ignore_from_sel=true, -- remove from possible units those that are already selected, this to prevent priority2 to get overriden by units already selected
				shift=true,
				want=1,
				wantIf={[{['name']='cloakheavyraid'}]=false}, -- want only one if the name is not 'cloakheavyraid' ('Scythe')
				shared_prev='One Commando', -- same previous system as 'One Commando' macro so we don't pick the same that were picked there
				color={0.2, 0.5, 1, 0.99},
				fading=0.5,
				share_radius = 'One Commando',
			},


			{name='All Commandos', 
				method='cylinder',
				keys={'?SPACE', '?AIR','N_3','RClick','longClick','?doubleRClick','?spam'},
				defs={'isUnit'},
				-- on_press=true,
				longPressTime = 0.15, -- longPress is evaluated true within 0.2 sec, very swiftly
				color={0.2, 0.5, 1, 0.99},
				fading=0.5,
				-- force_finish = true, -- achieve 'One Commando' call before starting this one
				same_units=true,
				share_radius = 'One Commando',
			},
			--[[{name='More Commando(s)', 
				method='cylinder',
				keys={'N_3','RClick','doubleRClick','?spam','?AIR,?SPACE'},
				from_cursor=true,
				same_units=true, -- picking same units name as current selection

				ignore_from_sel=true, -- remove from possible units those that are already selected, this to prevent priority2 to get overriden by units already selected
				shift=true,
				want=1,
				selname=true, -- show the unit name instead of the macro name
				shared_prev='One Commando',
				color={0.2, 0.5, 1, 0.99},fading=0.5
			},--]]

		------------
		-- STRIDER
		------------
			-- {name='One Strider', -- pick any non commando strider close of the cursor with SPACE + E, the more you spam the more you got, or long press to get them all at once
			-- 	method='cylinder',
			-- 	keys={'?AIR','SPACE','E','doubleTap'},
			-- 	defs={'isUnit',['family']='strider',['!name']={'striderscorpion','striderantiheavy'}},
			-- 	byType='defID',
			-- 	from_cursor=true,
			-- 	force=true,
			-- 	want=1,
			-- 	previous_time=1,
			-- 	color={0.2, 0.5, 1, 0.99},fading=0.5
			-- },

			-- {name='One More Strider', -- 
			-- 	method='cylinder',
			-- 	keys={'?AIR','SPACE', 'E','doubleTap','spam'},
			-- 	defs={'isUnit',['family']='strider',['!name']={'striderscorpion','striderantiheavy'}},
			-- 	same_units=true,
			-- 	from_cursor=true,
			-- 	force=true,
			-- 	want=1,
			-- 	shift=true,
			-- 	shared_prev='One Strider',
			-- 	color={0.2, 0.5, 1, 0.99},fading=0.5
			-- },

			-- {name='All Striders', -- 
			-- 	method='cylinder'
			-- 	,keys={'?SPACE', 'AIR','E','longPress'}
			-- 	,defs={'isUnit',['family']='strider',['!name']={'striderscorpion','striderantiheavy'}}
			-- 	,force=true
			-- 	,longPressTime = 0.2
			-- 	,color={0.2, 0.5, 1, 0.99},fading=0.5
			-- },

		------------
		-- PALADIN
		------------
			{name='One Paladin',
			method='cylinder',
			keys={'?SPACE', '?AIR',4,'LClick'},
			from_cursor=true,
			defs={['?name']={'striderbantha','striderdetriment'}},
			ignore_from_sel=true, -- remove from possible units those that are already selected, this to prevent priority2 to get overriden by units already selected
			prefer={{['reload']=3},{'isUnit'}},
			force=true,
			previous_time=1.5, -- forget the prev faster
			want=1,
			share_radius = 'Assault',
			color={0.2, 0.5, 0.85, 0.99},fading=0.5},


			{name='One More Paladin',
			method='cylinder',
			keys={'?SPACE', '?AIR',4,'LClick','doubleLClick','?spam'},
			defs={['name']='striderbantha'},
			from_cursor=true,
			ignore_from_sel=true, -- remove from possible units those that are already selected, this to prevent priority2 to get overriden by units already selected
			prefer={{['reload']=3},{'isUnit'}},
			shift=true,
			want=1,
			force=true,
			shared_prev='One Paladin',
			share_radius = 'Assault',
			color={0.2, 0.5, 1, 0.99},fading=0.5},

			{name='Paladins', 
			method='cylinder',
			keys={'?SPACE', '?AIR',4,'RClick','?doubleRClick'},
			defs={['?name']={'striderbantha','striderdetriment'}},
			force=true,
			share_radius = 'Assault',
			color={0.2, 0.5, 0.85, 0.99},fading=0.5},


		-------------
		---- FACTORYun
		-------------
			-- simple Tab tap cycle to next factory, long press select all factories of the last selected type
			-- with SPACE toggle it will select the air factory(ies)
			{name='Factory'
			,method='all'
			,from_cursor=true
			,defs={'!isUnit',['!name']={'staticrearm','staticmissilesilo'},['?']={'isFactory',name='striderhub'}}
			,prefer = {['!family'] = 'gunship'}
			,byType = 'family'
			,keys={'TAB'--[[,'?doubleTap'--]],'?spam'}
			-- ,want=1 -- can specify the number you want to select, will cycle through valid units
			-- ,byType='defID'
			,pref_use_prev = true
			,selname=true -- show the unit name as title of the macro
			,on_press=true
			,previous_time = 0.8
			,hasStructure = true
			,want=1
			,force=true}, -- force the hotkey

			{name='Same Factories'
			,method='all'
			,same_units = true
			,defs={'!isUnit',['!name']={'staticrearm','staticmissilesilo'},['?']={'isFactory',name='striderhub'}}
			,keys={'TAB','doubleTap','?spam'}
			-- ,want=1 -- can specify the number you want to select, will cycle through valid units
			-- ,byType='defID'
			,on_press=true
			,hasStructure = true
			,force=true}, -- force the hotkey


			{name='Air Factory'
			,method='all'
			,defs={['?name']={'factoryplane','plateplane'}}
			-- ,keys={'?SPACE','AIR','TAB','?doubleTap','?spam'}
			,prefer={name='factoryplane'}
			,want=1 -- can specify the number you want to select, will cycle through valid units
			,selname=true -- show the unit name as title of the macro
			,on_press=true
			,hasStructure = true
			,force=true}, -- force the hotkey

			-- {name='Same Factories'
			-- ,method='all'
			-- ,defs={'isFactory'}
			-- ,keys={'?SPACE', 'AIR','TAB','?doubleTap','?spam','longPress','?mouseStill'}
			-- ,same_units=true
			-- ,selname=true -- show the unit name as title of the macro
			-- ,on_press=true
			-- ,force=true}, -- force the hotkey

		----

		------------------
		{name='Super Weapons',
			method='all',
			keys={'?AIR','T','doubleTap'},
			force=true,
			defs={'isSpecialWeapon',['!name']={'staticmissilesilo'}},
			byType='defID',
			hasStructure = true,
			
			color={0.5, 0.9, 0.5, 1},fading=1
		},


		-------------------------------------
		-- LOCKED TOGGLE and TEMPORARY TOGGLE
			-- toggles are interpreted as modifiers that expand the use of same keys for different macros
			-- toggle lock work as a persistent modifier like CapsLock while tmp toggle work as the shift key
			-- you can attach to it one or more temporary toggle to switch them  temporarily

			-- with both those toggle and the macros corresponding in here you can either manage air units permanently or ground units permanently
			-- and switching to the other type temporarily with the temporary toggle activated by the key space here.
			-- example: you are commanding ground unit but you want to quickly call your unloaded bombers then come back to ground
			-- or example: you are the air player but you need to control some ground units from time to time

			-- example of lock toggle 
			{name='AIR', -- the name given here will be then be interpreted as a key that has been pressed
			 method='toggleLock',--special syntax of method to indicate this is a permanent toggle
			 keys={'?AIR','UNKNOWN'},--(UNKNOWN key is for my '²' key interpreted by KEYSIM) 
			 draw_pos={0,resY-88},-- you can specify size and position or it will stack them on default in the top left 
			 size=25,
			 on_press=true,
			 color={1.0, 0.9, 0.85, 0.99},fading=0.5},-- fading from alpha 0.99 to 0.5

			-- TEMPORARY TOGGLE: same a toggle lock except that it switch only when key is pressed, then it revert
			-- the name AIR beeing the same as the toggle lock name above, it will switch on to off, or off to on temporarily until key is released
			-- if you only want temporary toggle just make a fake lock with no keys and give tmpToggle the same name
			-- {name='AIR',
			--  method='tmpToggle',
			--  keys={'?AIR','space'},
			--  --removekey=true, -- uncomment if you want the key that trigger the toggle to not get registered
			-- },


		-- additional syntax keys in subtable, keys={{'N_1',N_2},ALT}  means ALT + (N_1 OR N_2) match
		-- additional setting : you can add hide=true to disable drawing for the particular combo

		--------------------
		--- ON SELECTION ---
		--------------------
			-- select half of selection by doubleTapping E
			{name='Half', -- to display a % sign you have to escape it with another percent sign
			method='on_selection', -- apply research on the previous selection
			keys={'?AIR',"Z",'doubleTap','?spam'},
			OnCallFunc=function() if IM then IM:KeyPress(KEYSYMS.Z,MODS_FALSE,false) end end,
			force=true,
			hasStructure = true,
			want="50%", -- selecting 50% of valid units caught
			-- force=true, -- force the combo, override an hotkey from regular game hotkeys
			-- set_active_command=-1, -- get out of factory table in case we were having cons in hand
			color={0.9, 0.9, 0.1, 1},fading=0.8},

			{name='One',
			method='on_selection', -- 
			keys={'?AIR',"Z",'doubleTap','?spam','longPress','?mouseStill'},
			want="1", 
			hasStructure = true,
			force=true, -- force the combo, override an hotkey from regular game hotkeys
			-- set_active_command=-1,
			color={0.9, 0.9, 0.1, 1},fading=0.8},

			-- {name='One more',
			-- method='on_selection', -- 
			-- keys={'?SPACE', 'AIR',"Z",'doubleTap','spam',},
			-- want="1", 
			-- shift=true,
			-- same_units=true,
			-- --force=true, -- force the combo, override an hotkey from regular game hotkeys
			-- color={0.9, 0.9, 0.1, 1},fading=0.8},


			
			-- RETREAT LOW HP UNITS ONLY --
			
				-- Keep unit from selection that have more than 50/70/95% (singleTap, doubleTap, tripleTap) hp with a press of space +  R and return wounded units to where they were registered by UnitsIDCard
				{name='Return under 50%%',
				method='on_selection',
				keys={'?AIR','SPACE', 'R','?RClick'}, -- RClick can be pressed when ordering moving at the same time
				defs={'under50%'},
				keep_on_fail = true,
				no_key_order = true,
				force = true,
				brush_order={'return'}, -- that special order will send the unit to a position close where the closest caretaker is or where it's been created/registered by UnitsIDCard
				mark_unit = {no_select=os.clock},
				second_call='Keep Above 50%%',
				color={0.9, 0.9, 0.1, 1},fading=0.8},

				{name='Keep Above 50%%',
				method='on_selection',
				defs={'above50%'},
				on_press=true,
				color={0.9, 0.9, 0.1, 1},fading=0.8},
				----------------
				{name='Return under 70%%',
				method='on_selection',
				keys={'?AIR','SPACE', 'R','doubleTap'},
				defs={'under70%'},
				keep_on_fail = true,
				brush_order={'return'},
				second_call='Keep Above 70%%',
				color={0.9, 0.9, 0.1, 1},fading=0.8},

				{name='Keep Above 70%%',
				method='on_selection',
				defs={'above70%'},
				on_press=true,
				color={0.9, 0.9, 0.1, 1},fading=0.8},
				----------------
				----------------
				{name='Return under 95%%',
				method='on_selection',
				keys={'SPACE','?AIR', 'R','doubleTap','spam'},
				defs={'under95%'},
				keep_on_fail = true,
				brush_order={'return'}, 
				second_call='Keep Above 95%%',
				color={0.9, 0.9, 0.1, 1},fading=0.8},

				{name='Keep Above 95%%',
				method='on_selection',
				defs={'above95%'},
				on_press=true,
				color={0.9, 0.9, 0.1, 1},fading=0.8},

		-------------------------------------------------------------------------
		-------------------------------------------------------------------------

		--------------------
		------ ESCORT ------
		--------------------
			-- Select Escort with a doubleTap of key, or the escorted with a doubleTap held longer
			-- {name='Guards',
			-- method='cylinder',
			-- keys={'G','doubleTap','?spam'},
			-- defs={'isGuarding'},
			-- force=true,
			-- continue=true,
			-- color={0.1, 0.9, 0.9, 1},fading=0.8},

			-- {name='Guarded',
			-- method='cylinder',
			-- keys={'G','doubleTap','?spam','longPress','?mouseStill'},
			-- lockedRepeat=true, -- if longPress is part of the combo and you don't want the combo itself to get repeated, just triggered once
			-- 				   -- so lockedrepeat will be interpreted as a long press, 
			-- force=true, -- will override regular hotkey bound and eventually reset active command
			-- continue=true,
			-- defs={'isGuarded'},
			-- color={0.9, 0.9, 0.1, 1},fading=0.8},


		-----------------------------
		-- UNIT class SELECTIONS -- pretty much an enhancement of the usual control groups that can have more refined params
		-----------------------------

			----- RAIDER ------
				-- -- OLD
					-- 	{name='Raiders',
					-- 	method='cylinder',
					-- 	keys={'?SPACE','N_1'},
					-- 	defs={['class']='raider'},
					-- 	prefer={['!name']={'jumpscout','spiderscout','shieldscout'}},
					-- 	byType='family',
					-- 	typeOrder={
					-- 		'cloak',
					-- 		'shield',
					-- 		'gunship',
					-- 	},
					-- 	only_prevTypes = true,
					-- 	force = true,
					-- 	pref_use_prev = true,
					-- 	avoid_non_pref = true, -- if prefered is in prev, pick it over a non prefered
					-- 	-- fail_on_identical = true,
					-- 	call_on_fail = 'Alt Raiders',
					-- 	retry_on_identical = true,
					-- 	previous_time = 0.85,
					-- 	ifSecondary = {on_press=true}, -- apply those prop if that call is not the main call
					-- 	color={0.9, 0.9, 0.1, 1},fading=0.8},







					-- 	{name='Alt Raiders',
					-- 	method='cylinder',
					-- 	keys={'?SPACE','N_1','doubleTap'},
					-- 	call_on_only_defs= {
					-- 		[ {name={'vehscout','vehraid'}} ] = 'Scorcher / Dart'
					-- 	},
					-- 	switch={
					-- 		{['?name']={'jumpscout','spiderscout','shieldscout','subraider','vehscout', 'tankraid'}},
					-- 		{['?name']={'jumpscout','spiderscout','shieldscout','subraider','vehraid', 'tankheavyraid'}},
					-- 	},
					-- 	keep_on_fail = true,
					-- 	switch_time = 1,
					-- 	doubleTap_time = 0.35,
					-- 	--continue=true, --reset future selection at each update round
					-- 	call_on_fail = 'Raiders',
					-- 	share_radius = 'Raiders',
					-- 	color={0.9, 0.9, 0.1, 1},fading=0.8},

					-- {name='Scorcher / Dart', -- no key, called immediately by Alt Raiders if defs are matching
					-- method='cylinder',
					-- -- on_press = true,
					-- add_last_call_pool = true,
					-- add_last_call_pool_if = 'Raiders',
					-- groups={
					-- 	{name='vehscout'},
					-- 	{name='vehraid'},
					-- },
					-- -- switch={
					-- -- 	{name='vehscout'},
					-- -- 	{name='vehraid'},
					-- -- },
					-- -- switch_time = 1,
					-- share_radius = 'Raiders',
					-- --continue=true, --reset future selection at each update round
					-- color={0.9, 0.9, 0.1, 1},fading=0.8},


				-- --

				{name='Raiders', -- 
				method='cylinder',
				keys={'?SPACE','N_1'},
				defs={['class']='raider'},
				default = {family = {'spider', 'jump'}},
				-- default = {['?'] = {family = 'spider', name = 'shieldscout'}},

				-- prefer={['!name']={--[['jumpscout',--]]'spiderscout','shieldscout'}},
				-- prefer={['!name']={'shieldscout'}},
				-- from_cursor = true,
				-- pref_use_prev = true,
				-- avoid_non_pref = true, -- if prefered is in prev, pick it over a non prefered
				-- previous_time = 0.5,
				-- only_prevTypes = true,
				groups = {
					{family = {'cloak','veh','hover'}},
					{family = {'tank','shield','amph'}, ['!name']={'shieldscout'}},
					{family = {'gunship'}},
					{family = 'jump',['!name'] = 'jumpscout'},
					{family = {'hover'}},
					{family = {'ship'}},

				},
				-- byType='family',
				-- typeOrder={
				-- 	'cloak',
				-- 	'shield',
				-- 	'gunship',
				-- },
				selname = true,
				force = true,
				-- fail_on_identical = true,
				-- call_on_fail = 'Alt Raiders',
				-- retry_on_identical = true,
				ifSecondary = {on_press=true}, -- apply those prop if that call is not the main call
				color={0.9, 0.9, 0.1, 1},fading=0.8},


				-- {name = 'Scouts',
				-- defs={['!name']={--[['jumpscout',--]]'spiderscout','shieldscout'}},
				-- from_cursor = true,
				-- }


				{name='Alt Raiders',
				method='cylinder',
				keys={'?SPACE','N_1','doubleTap','?spam'},
				-- defs={['class']='raider'},
				-- prefer={['name']={'jumpscout','spiderscout','shieldscout','gunshipemp',--[['gunshipemp','vehraid','vehscout'--]]}},
				defs={['name']={'jumpscout','spiderscout','shieldscout','gunshipemp', 'vehscout'}},
				
				byType = 'defID',
				from_cursor = true,
				keep_on_fail = true,


				only_prevTypes = true,
				force = true,
				-- pref_use_prev = true,
				-- avoid_non_pref = true, -- if prefered is in prev, pick it over a non prefered
				previous_time = 1,
				selname = true,
				doubleTap_time = 0.2,
				--continue=true, --reset future selection at each update round
				-- call_on_fail = 'Raiders',
				share_radius = 'Raiders',
				color={0.9, 0.9, 0.1, 1},fading=0.8},

				-- {name='Alt Raiders',
				-- method='cylinder',
				-- keys={'?SPACE','N_1','doubleTap'},
				-- call_on_only_defs= {
				-- 	[ {name={'vehscout','vehraid'}} ] = 'Scorcher / Dart'
				-- },
				-- switch={
				-- 	{['?name']={'jumpscout','spiderscout','shieldscout','subraider','vehscout', 'tankraid'}},
				-- 	{['?name']={'jumpscout','spiderscout','shieldscout','subraider','vehraid', 'tankheavyraid'}},
				-- },
				-- keep_on_fail = true,
				-- switch_time = 1,
				-- doubleTap_time = 0.35,
				-- --continue=true, --reset future selection at each update round
				-- call_on_fail = 'Raiders',
				-- share_radius = 'Raiders',
				-- color={0.9, 0.9, 0.1, 1},fading=0.8},






				-- {name='One Alt Raider',
				-- method='on_acquired',
				-- keys={'?SPACE','N_1','doubleTap','longPress','mouseStill'},
				-- from_cursor = true,
				-- want = 1,
				-- color={0.5, 0.9, 0.5, 1},fading=1},


				--[[
					{name='All Raiders',
					method='all',
					--on_press=true, -- will be executed on press instead of release, immediate selection and immediate end of call
					keys={'N_1','doubleTap','?spam','?SPACE'},
					defs={['class']='raider'},
					color={0.9, 0.9, 0.1, 1},fading=0.8},
				--]]

			------ SKIRM -------
				-- {name='All Skirms',
				-- method='cylinder',
				-- keys={'?SPACE',2,'doubleTap'},
				-- switch={{['class']='skirm',['!family']='gunship'}, {['class']='skirm'}},
				-- switch_time=1,
				-- force = true,
				-- color={0.5, 0.9, 0.5, 1},fading=1},

				-- OLD
					-- {name='Skirms',
					-- method='cylinder',
					-- keys={'?SPACE',2},
					-- switch= {
					-- 	{['name'] = {'jumpskirm','jumpblackhole'}},
					-- 	{['class']='skirm',['!family']='gunship', ['!name'] = 'jumpskirm'},
					-- 	{['class']='skirm'},
					-- },
					-- switch_time=1,
					-- force = true,
					-- -- byType = 'defID',
					-- color={0.5, 0.9, 0.5, 1},fading=1},
				--

				{name='Skirms',
				method='cylinder',
				keys={'?SPACE',2},
				defs = {
					['?'] = {
						class = 'skirm',
						name = 'jumpblackhole'
					}
				},
				groups= {
					{family = 'ship'},
					{family = 'veh'},
					{family = 'hover'},
					{family='gunship'},
					-- {name = {'jumpblackhole'}},
					{class = 'skirm' , ['!name'] = 'shieldfelon'},
					{name = {'shieldfelon','spiderskirm','shieldskirm','jumpskirm','cloakskirm','amphfloater'}},
					-- {name = 'shieldfelon'},
				},
				wantIf = {[{['name']='jumpblackhole'}]=1},
				force = true,
				-- byType = 'defID',
				color={0.5, 0.9, 0.5, 1},fading=1},




				-- {name='One Skirm',
				-- method='on_acquired',
				-- keys={'?SPACE',2,'longPress','mouseStill'},
				-- from_cursor = true,
				-- want = 1,
				-- color={0.5, 0.9, 0.5, 1},fading=1},


				-- {name='One Skirm',
				-- method='on_acquired',
				-- keys={'?SPACE',2,'longPress','mouseStill'},
				-- from_cursor = true,
				-- want = 1,
				-- color={0.5, 0.9, 0.5, 1},fading=1},


				-- {name='all skirm',
				-- method='all',
				-- keys={'?SPACE','N_2','doubleTap','?spam'},						
				-- defs={['class']='skirm'},
				-- on_press=true,
				-- color={0.7, 0.7, 0, 0.6},fading=1},




				-- {name='Alt Skirms',
				-- method='cylinder',
				-- keys={'?SPACE','N_2','doubleTap'},
				-- switch={
				-- 	{['?name']={'jumpskirm'}},
				-- 	{['?name']={'spiderskirm'}},
				-- },
				-- keep_on_fail = true,
				-- switch_time = 1,
				-- doubleTap_time = 0.35,
				-- --continue=true, --reset future selection at each update round
				-- call_on_fail = 'Skirms',
				-- share_radius = 'Skirms',
				-- color={0.9, 0.9, 0.1, 1},fading=0.8},

			------ RIOT -------

				{name='Riot',
				method='cylinder',
				-- defs={['class']='riot'},
				-- prefer={{['name']='striderdante'},{'isGS'}},
				switch={
					{['name']='striderdante'}
					,{['class']='riot',['!name']={'striderdante','jumpblackhole'},'!isGS'}
					,{['class']='riot',['?name']={'spideremp','jumpblackhole'}}
					,{['class']='riot',['?name']={'spiderriot'}}
					,{['class']='riot','isGS'}
				}
				,switch_time = 1
				,force = true
				-- ,call_on_fail = 'Alt Riot'
				-- ,byType='defID'
				-- ,byType='family'
				,from_cursor = true
				,keys={'?SPACE',3,--[['?doubleTap'--]]}
				,color={1, 0.7, 0.7, 1},fading=1},



				-- {name='Alt Riot',
				-- method='cylinder',
				-- keys={'?SPACE',3,'doubleTap'},
				-- defs={['class']='riot',['?name']={'spiderriot','jumpblackhole'}},
				-- share_radius = 'Riot',
				-- force = true,
				-- color={1, 0.7, 0.7, 1},fading=1},

				-- {name='Alt Riot',
				-- method='cylinder',
				-- from_cursor = true,
				-- -- keys={'?SPACE','?AIR',3,'doubleTap'},
				-- defs={['class']='riot'},
				-- prefer={['name']='jumpblackhole'},
				-- pref_use_prev = true,
				-- only_prev_types = true,
				-- byType = 'defID',
				-- previous_time = 0.5,
				-- share_radius = 'Riot',
				-- doubleTap_time = 0.5,
				-- force = true,
				-- color={1, 0.7, 0.7, 1},fading=1},


				{name='Alt Riot',
				method='cylinder',
				keys={'?SPACE',3,'doubleTap'},
				defs = {class = 'riot'},
				groups= { -- groups find the first matching group closest of cursor
					{
						['!name'] = 'spideremp',
					},
					{
						['!name']={'spiderriot'},
					}
				},
				-- different_units=true,
				switch_groups = 1,
				force = true,
				color={1, 0.8, 0.8, 1},fading=1},




				{name='Alt Riot 2',
				method='cylinder',
				-- keys={'?SPACE',3,'longPress','mouseStill'},
				defs={class='riot',['?name']={'spideremp','jumpblackhole'}},
				longPressTime = 0.2,
				share_radius = 'Riot',
				keep_on_fail = true,
				force = true,
				color={0.5, 0.7, 0.7, 1},fading=1},


				-- {name='One Riot',
				-- method='on_acquired',
				-- keys={'?SPACE',3,'longPress','mouseStill'},
				-- from_cursor = true,
				-- want = 1,
				-- color={0.5, 0.9, 0.5, 1},fading=1},


			------ ASSAULT -------
				{name='Alt Assault',
				method='cylinder',
				from_cursor = true,
				keys={'?SPACE','?AIR',4,'longPress','mouseStill'},
				longPressTime = 0.2,
				mouseStillThreshold = 40,
				defs={['name']='hoverassault'},
				-- share_radius = 'Assault',
				force = true,
				color={1, 1, 1, 1},fading=1},

				{name='Assault',
				method='cylinder',
				keys={'?SPACE',4},
				defs = {class = 'assault'},
				groups= {
					{
						['name'] = 'jumpsumo',
					},
					{
						['!name']={'striderbantha','jumpsumo'},
					}
					,
					{
						name='hoverassault',
					}
				},
				-- different_units=true,
				switch_groups = 1,
				force = true,
				color={1, 0.8, 0.8, 1},fading=1},

				-- {name='Assault (bis)',
				-- method='cylinder',
				-- keys={'?SPACE',4,'longPress'},

				-- switch= {
				-- 	{
				-- 		['name'] = 'jumpsumo'
				-- 	},
				-- 	{
				-- 		['class']='assault',['!name']={'striderbantha','jumpsumo'}
				-- 	}
				-- 	,
				-- 	{
				-- 		['class']='assault',['?name']={'hoverassault'}
				-- 	}
				-- },
				-- different_units=true,
				-- force = true,

				-- switch_time = 0.8,
				-- shared_switch = 'Assault',
				-- shared_prev = 'Assault',
				-- color={1, 0.8, 0.8, 1},fading=1},


				-- {name='One Assault',
				-- method='on_acquired',
				-- keys={'?SPACE',4,'longPress','mouseStill'},
				-- from_cursor = true,
				-- defs = {['class']='assault'},
				-- want = 1,
				-- color={0.5, 0.9, 0.5, 1},fading=1},
			------ ARTY -------

				{name='arty',
				method='cylinder',
				keys={'?SPACE',4,'doubleTap','?spam'},	
				byType='defID',
				from_cursor = true,
				defs={
					['class']='arty'
				},
				color={0.2, 0.2, 0.6, 1},fading=0.8},

				{name='arty',
				method='cylinder',
				keys={'?SPACE',5},
				byType='defID',
				defs={['class']='arty'},
				color={0.2, 0.2, 0.6, 1},fading=1},

				{name='One Arty',
				method='on_acquired',
				keys={'?SPACE',5,'longPress','mouseStill'},
				from_cursor = true,
				want = 1,
				color={0.5, 0.9, 0.5, 1},fading=1},

				{name='all arty',
				method='all',
				on_press=true, 
				keys={'?SPACE',5,'doubleTap','?spam'},
				defs={['class']='arty'},
				color={0.2, 0.2, 0.6, 1},fading=1},

			------ AA -------

				-- 2+LClick : pick up a cloaky aa to go scout, put it on hold fire
				{name='Scout', 
				method='cylinder',
				from_cursor=true,
				defs={['name']='cloakaa',['fireState']=0},
				keys={'?SPACE','N_2','LClick'},
				want=1, -- specify the number we want to select, will cycle through valid units
				from_cursor=true,
				on_press=true,
				-- prefer={{['fireState']=0},{'isUnit'}}, -- prefer one on hold fire if possible
				previous_time=1.5,
				call_on_fail='Set Scout', -- setting a scout if no available in the radius
				share_radius = 'Set Scout',
				},

				{name='Set Scout', -- Pick up an non hold-fire cloakaa closest to the cursor and put it on hold fire
				method='cylinder',
				from_cursor=true,
				defs={['name']='cloakaa',['!fireState']=0},
				on_press=true,
				-- ignore_from_sel=true, -- remove from possible units those that are already selected, this to prevent priority2 to get overriden by units already selected

				give_order={[CMD.FIRE_STATE]={0,0}}, -- put it on hold fire
				want=1,
				force=true,
				keep_on_fail=true,
				disable_SM=true,
				shared_prev='Scout',}, -- use same 'previous' table as the cited macro
				------------
				-- Set up more scouts by spamming lClick
				{name='Set +1 Scout',
				method='cylinder',
				from_cursor=true,
				defs={['name']='cloakaa',['!fireState']=0},
				keys={'?SPACE','N_2','LClick','doubleLClick'},
				-- ignore_from_sel=true, -- remove from possible units those that are already selected, this to prevent priority2 to get overriden by units already selected

				give_order={[CMD.FIRE_STATE]={0,0}}, -- put it on hold fire
				-- shift=true, -- don't deselected the previous selection 
				want=1,
				force=true,
				on_press=true,
				keep_on_fail=true,
				disable_SM=true,
				share_radius = 'Set Scout',
				shared_prev='Set Scout',}, -- use same 'previous' table as the cited macro
				------------
				-- Pick up all scouts on long double click with 2
				{name='Get All Scouts',
				method='cylinder',
				from_cursor=true,
				defs={['name']='cloakaa',['fireState']=0},
				keys={'?SPACE','N_2','LClick','longClick'},
				-- ignore_from_sel=true, -- remove from possible units those that are already selected, this to prevent priority2 to get overriden by units already selected
				-- want=1,
				force=true,
				share_radius = 'Set Scout',
				}, 
		

				{name='non scout AA', -- pick up any AA except the cloaky AA on hold-fire (preventing to picking scouts along)
				method='cylinder',
				keys={'?SPACE','N_2','doubleTap','?spam'},						
				-- defs={ ['class']='aaunit', ['?']={['!fireState']=0,['!name']='cloakaa'} },
				defs={ ['class']='aaunit'},
				prefer = {['!fireState']=0},
				color={0.2, 0.2, 0.6, 1},fading=1},

				{name='all AA', -- pick up all AA and put them back with fire ON
				method='cylinder',
				-- keys={'?SPACE','N_2','doubleTap','spam'},						
				keys={'?SPACE','N_2','doubleTap','longPress'},
				defs={ ['class']='aaunit' },
				give_order={[CMD.FIRE_STATE]={2,0}},
				color={0.2, 0.2, 0.6, 1},fading=1},

			------ SPECIAL -------

				{name='Special',
				method='cylinder',
				keys={'?AIR','SPACE','E'},						
				-- defs={		
				-- 	-- ['?']={'isStrider', ['?class']={'special1','special2','special3'}
				-- 		  --,['?name']={'amphlaunch'}
				-- 	['?name']={'vehcapture', 'amphtele'}
				-- },
				groups = {
					{name = 'vehcapture'},
					{name = 'amphtele'},
					{['name']={'bomberstrike'},['!p:noammo']={1,2}},
				},
				-- keep_on_fail=true,
				call_on_fail = 'Loaded Bomber Strike',
				call_on_only_defs = {
					[{['name']={'bomberstrike'},['!p:noammo']={1,2}}] = 'Loaded Bomber Strike', 
				},
				set_active_command=-1,
				force=true,
				color={0.5, 0.9, 0.5, 1},fading=0.8},

				{name='Loaded Bomber Strike',
				method='all',
				-- keys={'?AIR','SPACE','E'},						
				defs={		
				-- 	-- ['?']={'isStrider', ['?class']={'special1','special2','special3'}
				-- 		  --,['?name']={'amphlaunch'}
					['name']={'bomberstrike'},['!p:noammo']={1,2},
				},

				-- keep_on_fail=true,
				-- force=true,
				color={0.5, 0.9, 0.8, 1},fading=0.8},

				{name='Loaded Bomber Strike Around',
				method='cylinder', 

				keys={'SPACE','?AIR','E','longPress'--[[,'?mouseStill'--]]},	

				-- keys combination can be anything, even non-mods key together
				defs={['name']={'bomberstrike'},['!p:noammo']={1,2}}, -- definition of the unit (UnitDefs extended by my UnitsIDCard widget)
				--syntax : ['!p:noammo']={1,2} value must be either 1 or 2, '!' means 'not' so : 'noammo must not be either 1 or 2'
				longPressTime=0.2,


				color={0.0, 1.0, 0.0, 0.9  },	fading=0.6}, -- color and optional fading, here: opacity will go from 0.9 to 0.6

				{name='All Bomber Strike',
				method='all', 

				keys={'SPACE','?AIR','E','doubleTap','longPress'--[[,'?mouseStill'--]]},	

				-- keys combination can be anything, even non-mods key together
				defs={['name']={'bomberstrike'}}, -- definition of the unit (UnitDefs extended by my UnitsIDCard widget)
				--syntax : ['!p:noammo']={1,2} value must be either 1 or 2, '!' means 'not' so : 'noammo must not be either 1 or 2'
				longPressTime=0.2,


				color={0.0, 1.0, 0.0, 0.9  },	fading=0.6}, -- color and optional fading, here: opacity will go from 0.9 to 0.6


				{name='Shields',
				method='cylinder',
				keys={'?AIR','2','RClick'},						
				defs={['name']='shieldshield'},
				color={0.5, 0.9, 0.5, 1},fading=0.8},




		---------------------------------------------------
		---------------------------------------------------
		----------------------- AIR -----------------------
		---------------------------------------------------
		---------------------------------------------------
			{name='Swifts ',
				method='all',
				keys={'AIR','?SPACE',1},
				-- on_press=true,
				defs={['name']='planefighter'},
				-- no_key_order = true,
				color={0.9, 0.9, 0.3, 1},fading=0.8
			},

			{name='Swifts Around',
				method='cylinder',
				keys={'AIR','?SPACE',1,'longPress','?mouseStill'},
				-- on_press=true,
				longPressTime = 0.2,
				-- radius=1000,
				defs={['name']='planefighter'},
				-- no_key_order = true,
				keep_on_fail = true,
				color={0.9, 0.9, 0.3, 1},fading=0.8
			},


			-----------------
			-- BOMBER CONTROL
			-----------------

			-- while AIR lock active:
			-- tapping '3' will pick up all loaded bombers, then tapping again '3' repetively will reduce the number of bombers selected
			-- holding '3' long enough will select all bombers
			-- bombers are selected on press and from anywhere

			{name='Loaded Bombers',
			method='all', -- all units
			keys={'?SPACE','AIR','N_3'},	-- key and mods combination
			on_press=true, -- select on press and stop the call
			-- keys combination can be anything, even non-mods key together
			defs={['name']={'bomberprec'},['!p:noammo']={1,2},--[['isIdle',--]] --[[,['!order']=CMD.ATTACK--]]}, -- definition of the unit (UnitDefs extended by my UnitsIDCard widget)
			--syntax : ['!p:noammo']={1,2} value must be either 1 or 2, '!' means 'not' so : 'noammo must not be either 1 or 2'
			color={0.0, 1.0, 0.0, 0.9  },	fading=0.6}, -- color and optional fading, here: opacity will go from 0.9 to 0.6
														 -- if not mentioned, color will be randomized but fixed by name,method and position in the table
														 -- can also set pos and size for 'all' ,'onscreen' and 'toggleLock' methods
														 -- note: display can be deactivated with hide=true
			{name='Loaded Bombers Around',
			method='cylinder', 

			keys={'?SPACE','AIR','N_3','longPress','?mouseStill'},	

			-- keys combination can be anything, even non-mods key together
			defs={['name']={'bomberprec'},['!p:noammo']={1,2}}, -- definition of the unit (UnitDefs extended by my UnitsIDCard widget)
			--syntax : ['!p:noammo']={1,2} value must be either 1 or 2, '!' means 'not' so : 'noammo must not be either 1 or 2'
			longPressTime=0.2,


			color={0.0, 1.0, 0.0, 0.9  },	fading=0.6}, -- color and optional fading, here: opacity will go from 0.9 to 0.6
														 -- if not mentioned, color will be randomized but fixed by name,method and position in the table
														 -- can also set pos and size for 'all' ,'onscreen' and 'toggleLock' methods
														 -- note: display can be deactivated with hide=true


			-- {name='Loaded Bombers',
			-- method='all', 
			-- keys={'?SPACE','AIR','N_3','longPress','?mouseStill'},	
			-- -- radius = 1000,
			-- defs={['name']='bomberprec',['!p:noammo']={1,2}}, -- definition of the unit (UnitDefs extended by my UnitsIDCard widget)
			-- longPressTime=0.2,
			-- color={0.0, 1.0, 0.0, 0.9  },	fading=0.6},



			-- {name='Less loaded Bombers',
			-- method='on_selection',
			-- keys={'?SPACE','AIR','N_3','doubleTap','?spam'},
			-- on_press=true,
			-- want='85%',
			-- --want=-1,
			-- force=true,
			-- color={1.0, 0.0, 1.0, 0.8},fading=0.8},

			{name='All Bombers',
			method='all',
			keys={'?SPACE','AIR','N_3','doubleTap'}, 
			defs={['name']={'bomberprec', 'bomberstrike'}},
			on_press=true,
			ignore_no_select = true,
			color={1.0, 0.0, 1.0, 0.8},fading=0.8},


			-- same with napalms
			{name='Loaded Napalms',
			method='all', -- all units
			keys={'?SPACE','AIR','N_4'},	-- key and mods combination
			on_press=true, -- select on press and stop the call
			-- keys combination can be anything, even non-mods key together
			defs={['name']='bomberriot',['!p:noammo']={1,2}--[[,'isIdle',--]] --[[['!order']=CMD.ATTACK--]]},
			color={0.0, 1.0, 0.0, 0.9  },	fading=0.6},

			{name='Loaded Napalms Around',
			method='cylinder', 
			keys={'?SPACE','AIR','N_4','longPress','?mouseStill'},	
			radius = 1000,
			defs={['name']='bomberriot',['!p:noammo']={1,2}},
			longPressTime=0.2, -- how long a long press will be considered prior to trigger this macro
			color={0.5, 1.0, 0.0, 0.9  },	fading=0.6},

			-- {name='Loaded Napalms',
			-- method='all', 
			-- keys={'?SPACE','AIR','N_4','longPress','?mouseStill'},	
			-- defs={['name']='bomberriot',['!p:noammo']={1,2}},
			-- longPressTime=0.2,
			-- color={0.5, 1.0, 0.0, 0.9  },	fading=0.6},

			{name='All Napalms',
			method='all',
			keys={'?SPACE','AIR','N_4','doubleTap'}, 
			defs={['name']='bomberriot'},
			on_press=true,
			ignore_no_select = true,
			color={0.5, 0.0, 1.0, 0.8},fading=0.8},
			-----

			-----------------
			-- LIKHO CONTROL
			-----------------

			-- while AIR lock is active :
			-- tapping '5' will pickup the closest loaded likho from the cursor, then spamming 5 will pickup one more at each tap
			-- if '5' is held long enough, all likhos will be selected if '5' was tapped only once before, else it will selected all loaded likhos
			-- 


			{name='One Likho/Rag',
			method='all',
			keys={'?SPACE','N_5','AIR'},
			on_press=true,
			defs={['name']={'bomberheavy','bomberassault'},['!p:noammo']={1,2}},
			want=1,
			previous_time=0.01,-- forget previous selection faster, default is 5 second -- TODO make [previous] cancellable instead
			from_cursor=true,
			no_key_order = true,
			color={0.9, 0.9, 0.3, 1},fading=0.8},

			{name='One More Likho/Rag',
			method='all',
			keys={'?SPACE','AIR','N_5','doubleTap','?spam'},
			defs={--[[['name']={'bomberheavy','bomberassault'},--]]['!p:noammo']={1,2}},
			same_units = true, -->>
			want=1,
			previous_time=0.6,-- forget previous selection faster, default is 5 second
			on_press=true,
			from_cursor=true,
			shift=true,
			color={0.9, 0.9, 0.3, 1},fading=0.8},

			{name='All Loaded Likhos/Rag',
			method='all',
			keys={'?SPACE','AIR','N_5','doubleTap','longPress','?spam','?mouseStill'},
			defs={['!p:noammo']={1,2}},
			same_units = true,
			on_press=true,
			longPressTime = 0.2,
			color={1.0, 0.0, 0.5, 0.8},fading=0.6},

			{name='All Likhos',
			method='all',
			keys={'?SPACE','N_5','AIR','longPress','?mouseStill'},
			defs={['name']={'bomberheavy','bomberassault'}},
			on_press=true,
			longPressTime = 0.2,

			color={1.0, 0.0, 0.5, 0.8},fading=0.6},



			{name='raptors',
			method='all',
			keys={'?SPACE','AIR',2}, -- means the AIR toggle must be on, and  as SPACE can be used to temporary active the AIR lock, it might be on, so we put it optionally in the combo
			defs={['name']='planeheavyfighter'},
			on_press=true,
			color={0.5, 0.9, 0.5, 1},fading=0.8},

			---------------------
			-- RADAR PLANES CONTROL
			---------------------
			-- while AIR lock active, tapping '2' twice will pick up the closest radar plane available, spamming 2 will add more and more radar planes,
			-- tapping '2' twice then wait will pick all the radar planes
				
			{name='Owl',
			method='all',
			keys={'AIR','?SPACE',2,'doubleTap'},						
			defs={['?name']={'planescout','planelightscout'}},
			from_cursor=true,
			want=1,
			on_press=true,
			previous_time=0.6,
			color={0.5, 0.9, 0.5, 1},fading=0.8},

			{name='All Owls',
			method='all',
			keys={'AIR','?SPACE',2,'doubleTap', 'longPress', '?mouseStill'},						
			-- defs={['?name']={'planescout','planelightscout'}},
			same_units = true,
			from_cursor=true,
			-- want=1,
			on_press=true,
			longPressTime = 0.2,
			color={0.5, 0.9, 0.5, 1},fading=0.8},

			{name='More Owls',
			method='all',
			keys={'?SPACE','AIR',2,'doubleTap','spam'},						
			-- defs={['?name']={'planescout','planelightscout'}},
			same_units = true,
			from_cursor=true,
			want=1,
			on_press=true,
			shift=true,
			color={0.5, 0.9, 0.5, 1},fading=0.8},

			-------------------------
			-------------------------


			------------------------------------------
			--- STILETTO slightly different mechanism -- same '1' key than swift but we use doubleTap for it, can select more and more by spamming the key
			--- select the closests of cursor and must be reloaded (reload detection unfortunately fail in the mid-to-end of the firing salvo)
			--- longpress after a double tap will select all existing stilettos
			{name='One Stiletto',
			method='all',
			keys={'?SPACE','AIR','N_1','doubleTap'},
			defs={['name']='bomberdisarm',['!p:noammo']={1,2}--[[,['reload']={1}--]]},
			want=1,
			previous_time=0.30,-- forget previous selection faster, default is 5 second -- TODO make [previous] cancellable instead
			on_press=true, 
			from_cursor=true,
			color={0.8, 0.8, 0.8, 1},fading=0.8},

			{name='More Stilettos',
			method='all',
			keys={'?SPACE','AIR','N_1','doubleTap','spam'},
			defs={['name']='bomberdisarm',['!p:noammo']={1,2}--[[,['reload']={1}--]]},
			want=1,
			previous_time=0.25,-- forget previous selection faster, default is 5 second
			on_press=true,
			from_cursor=true,
			shift=true,
			color={0.8, 0.8, 0.8, 1},fading=0.8},

			{name='all Stilettos',
			method='all',
			keys={'AIR','?SPACE','N_1','doubleTap','?spam','longPress','?mouseStill'},						
			defs={['name']='bomberdisarm'},
			color={1, 1, 1, 1},fading=0.8},




		----- TACTICAL MISSILES -------
				-- select all missiles and their launchers
				--[[{name='Tacstuff',
					method='all',
					keys={'A','Z','?SPACE','doubleTap','?spam','?AIR'},
					force=true,				
					defs={['?name']={'staticmissilesilo','tacnuke','seismic','empmissile','napalmmissile'}},
					color={0.6, 0.6, 1, 0.8},fading=0.5},
				--]]
				--[[{name='Tacstuff',
					method='all',
					keys={'A','Z','?SPACE','doubleTap','?spam','?AIR'},
					force=true,				
					defs={['?name']={'staticmissilesilo','tacnuke','seismic','empmissile','napalmmissile'}},
					color={0.6, 0.6, 1, 0.8},fading=0.5},
				--]]


				-- select closest missile launcher with its missiles
				{name='close Tac Stuff',
				method='all',
				keys={'?AIR','A','Z'},
				force=true,
				from_cursor=true,				
				defs={['?name']={'staticmissilesilo','subtacmissile','shipcarrier'}},
				proximity={radius = 50, defs={['?name']={'tacnuke','seismic','empmissile','napalmmissile','missileslow'}}},-- pickup the desired units around the target within the desired radius
				want=1,
				hasStructure = true,
				on_press=true,
				previous_time=0.4,
				remove_active_command = true,
				color={0.6, 0.6, 1, 1},fading=0.8},

				{name='More Tacstuff',
				method='all',
				keys={'?AIR','A','Z','doubleTap','?spam'},
				force=true,
				from_cursor=true,	
				defs={['?name']={'staticmissilesilo','subtacmissile','shipcarrier'}},
				proximity={radius = 50, defs={['?name']={'tacnuke','seismic','empmissile','napalmmissile','missileslow'}}},-- pickup the desired units around the target
				want=1,
				shift=true,
				hasStructure = true,
				on_press=true,
				previous_time=0.4,
				color={0.6, 0.6, 1, 1},fading=0.8},

				{name='All Tacstuff',
				method='all',
				keys={'?AIR','A','Z','longPress','?mouseStill'},
				force=true,
				hasStructure = true,
				defs={['?name']={'staticmissilesilo','tacnuke','seismic','empmissile','napalmmissile','subtacmissile','shipcarrier'}},
				on_press=true,
				color={0.6, 0.6, 1, 1},fading=0.8},

				

		----- BROWSE THROUGH SELECTIONS
			-- quickly switch back to previous/next selection -- max selections to memorize are set in the top section of the widget
			{name='Last Selection',
			method='last',
			-- keys={'LALT','UNKNOWN','?doubleTap','?spam'}, --(UNKNOWN key is for my '²' key) 
			color={1, 1, 1, 0.9  },	fading=0.6},

			{name='Next Selection',
			method='next',
			-- keys={'LALT','N_1','?doubleTap','?spam'},
			color={1, 1, 1, 0.9  },	fading=0.6},
			---------

		--{name='DebugKeyDetect',method="option",keys={'CARET'}},
		---- Special Units

--[[			{name='AIR2',
		 method='toggleLock',
		 keys={'U','?AIR2','?AIR'},
		fading=0.8},

		{name='AIR2',method='tmpToggle',keys={'Y','?AIR2','?AIR'}},
--]]
}



--[[local UpdateKey = function(name)
	Echo("HKcombos is ", HKCombos)
	for _,combo in ipairs(HKCombos)do
		if combo.name==name then
			for key in pairs(Spring.GetPressedKeys())do
				key = KEYCODES[key]
				if key then
					showComboInLog = options.show_combo.value
					combo.keys[key]=true
				end
			end
		end
	end
end--]]



--for k,v in pairs(T) do Echo(type(k)) end

--f.Page(Spring,"screen")




--showComboInLog = options.show_combo.value
--debuggingKeyDetections = options.debugging_keys_detection
	






-- local TABLE_CUST_COMM_DRAW_DATA = {0.5, 1.0, 0.5, 1}

local sh={Aloss=0,Eloss=0,CurAl=0,CurEl=0,SelCost=0,Sel_n=0}


--FullTableToStringCode(T,{clip=true,breaks=1,sort=sort})
g.Selections = {n=0}
g.switchBackSelFiltering = false
local lastTime = round(clock()*10)
local fullSel

g.debuggingKeyDetections = false
local debugPrevious 

options_path = 'Hel-K/EzSelector'
options_order = { 'debugging_keys_detection','test','debugcheckreq','debugcurrentcombo','debugshownames','debugprevious'}
options = {
	debugging_keys_detection = {
		name = "debug key detection",
		type = "bool",
		OnChange = function(self)
			g.debuggingKeyDetections = self.value
		end,
		value = g.debuggingKeyDetections,
		desc = "debug key detection...",
	},
	test = {
		name = "test",
		OnChange = function(self) FullTableToStringCode(hotkeysCombos[3],{clip=true,breaks=1,sort=sort}) end,
		type = "button",
		desc = "open combo",
		hidden = true,

		--OnClick = {function(self) Echo(self.desc) end }
	},
	debugcheckreq = {
		name = "Debug Check Requirements",
		OnChange = function(self) end,
		type = "bool",
		value = false,

		--OnClick = {function(self) Echo(self.desc) end }
	},
	debugcurrentcombo = {
		name = "Debug Current COMBO",
		OnChange = function(self) end,
		type = "bool",
		value = false,

		--OnClick = {function(self) Echo(self.desc) end }
	},
	debugshownames = {
		name = "Show Names",
		desc = "Show Names of the main unit pool in console",
		OnChange = function(self) end,
		type = "bool",
		value = false,

		--OnClick = {function(self) Echo(self.desc) end }
	},
	debugprevious = {
		name = "Debug Previous System",
		OnChange = function(self) debugPrevious = self.value end,
		type = "bool",
		value = false,
		--OnClick = {function(self) Echo(self.desc) end }
	},

}



------------------------------------------------------------------------------------------------------------
---  END OF CONFIG
------------------------------------------------------------------------------------------------------------
local chk = f.CheckTime('start')
local myUnits={n=0}
local preGame = true
local Screen0
local selectionResized

g.acquired={n=0,byID={}}
g.validUnits={n=0,byID={}}
g.Type = false
g.hasPrefered = false
g.prefered = {checked={},types={},default={types={}}}
g.selCost=0
g.rmbSel=false
g.lastPress = 0
local myTeamID = spGetMyTeamID()

-- keys related
g.pressTime = clock()


g.keyChanged = false
g.inTweakMode=false -- fix the release of keys provoked by tweak mode (wont get registered by KeyRelease)

-- mouse implementation
local clicked={}
g.onClick = false
g.clickTime=clock()
local longPress={key=false,active=false,time=clock(),mouseStill=false,mx=-100,my=-100}

g.comID = false

local bufferRelease = {key=false,mods=false}-- buffer
g.waitUpdate = false

local possibleKeys ={
	[KEYSYMS.LALT] = true,
	[KEYSYMS.RALT] = true,
	[KEYSYMS.LCTRL] = true,
	[KEYSYMS.RCTRL] = true,
	[KEYSYMS.LSHIFT] = true,
	[KEYSYMS.RSHIFT] = true,
	[KEYSYMS.SPACE] = true,

}

local currentCombo={keys={}, raw = {}}
local ownedCombos={} -- for cycling translate combo name to combo index

g.hkCombo = false
g.HotkeyAlreadyBound = false  -- depending on the unit(s) selected, keys may or may not conflict, we have to check that
g.radius = 650
local memRadius={} -- radius for each macros memorized over game
g.lagFactor =0

local call -- the macro running
local lastCall -- to be able to change radius of calls that are on_press // not tested/implemented yet



--- drawing variables
local x, y, z

local locks={count=0, tmpPushed={},tmpToggleByKey={}}


local DRAW = {}

local CheckRequirements
local FindUnits
local GetPrefered
local PickType
local GetWantN
local SetDefinition
local ProcessFiltering

-------------------------------------------------
-------------------------------------------------
local merge = function(t,t2)
	local new
	local byID = t.byID
	local byType = t.byType
	local n = t.n
	for i,id in ipairs(t2) do
		if not byID[id] then
			n = n +1
			new = true
			byID[id] = n
			t[n] = id
			if byType then
				local thisType = Units[id][Type] or 'unknown'
				local thisType_table = byType[thisType] 
				if not thisType_table then
					byType[thisType]={n=0,byID={}}
					thisType_table=byType[thisType]
				end
				local thisType_count = thisType_table.n + 1
				
				thisType_table[thisType_count]=id
				thisType_table.byID[id]=thisType_count
				thisType_table.n = thisType_count

			end
		end
	end
	t.n = n
	return new
end

local function SortClosest(x,z)
	return function(a,b)
		local ax,_,az = spGetUnitPosition(a)
		local bx,_,bz = spGetUnitPosition(b)
		return ax and bx and (x-ax)^2+(z-az)^2<(x-bx)^2+(z-bz)^2
	end
end

local SetRetreat
do
	local caretakerDefID = UnitDefNames['staticcon'].id
	local indexedCommanderDefID = {}

	for defID, def in pairs(UnitDefs) do
		local cp = def.customParams
		if cp.level or cp.dynamic_comm then
			table.insert(indexedCommanderDefID, defID)
		end
	end
	local spGetTeamUnitsByDefs = Spring.GetTeamUnitsByDefs
	local currentRetreat, timeSet = false,0
	local possibles = {}
	SetRetreat = function(id)
		local time = os.clock()
		if time-timeSet < 0.1 then
			return currentRetreat
		end
		local x,_,z = spGetUnitPosition(id)
		timeSet = time
		currentRetreat = false
		possibles = spGetTeamUnitsByDefs(myTeamID,caretakerDefID)
		if not possibles[1] then
			possibles = spGetTeamUnitsByDefs(myTeamID,indexedCommanderDefID)
		end
		if possibles[1] then
			table.sort(possibles,SortClosest(x,z))
			currentRetreat = {spGetUnitPosition(possibles[1])}
		end
		
		return currentRetreat
	end
end

local function KFormat(n,max)
	return n<max and round(n) or round(n/1000)..'K'
end
-- Click status handling to complete detection of MousePress and MouseRelease -- used by Update
local function CheckClick()--detect missed clicks and release from Update round, also care about long click
	local mx,my
	mx,my,clicked[1],clicked[2],clicked[3]=spGetMouseState()
	g.onClick=false
	-- updating click status
	for i=1,3 do
		-- release of click when not MouseRelease detected it
		if clicked['N'..i] and not clicked[i] then
			widget:MouseRelease(mx,my,i)
		-- click missed by MousePress (usually when left click while right click is held)
		elseif not clicked['N'..i] and clicked[i] then 
			widget:MousePress(mx,my,i)
		end
		g.onClick=clicked[i] or g.onClick
	end
	if not g.onClick then currentCombo.keys['longClick']=nil end
	-- if anything clicked, check long click and try to find a combo
	-- if g.onClick and clock()-g.clickTime>0.66 then
	-- 	currentCombo.keys['longClick']=0
	-- 	local callCheck=HKCombos:Find(currentCombo.keys)
	-- 	Echo("callcheck is ", callcheck)
	-- 	if callCheck then
	-- 		g.hkCombo=callCheck
	-- 		g.keyChanged=true
	-- 	end
	-- 	currentCombo.keys['longClick']=nil
	-- end
end
local function UpdatePrev(prev)
 	if not prev then return end

 	------ erase part
 	if prev.needErase then 
 		if prev.byType and type(prev.needErase)~='boolean' then
 			if debugPrevious then Echo('prev: need erase of type '..prev.needErase) end
 			-- erase only the desired type
 			local t = prev.byType[prev.needErase]
 			if t then 
 				if t.n==prev.n then
 					if debugPrevious then
 						Echo('prev: only this type in prev, remove all prev')
 					end
			 		for i=1,prev.n do prev[i]=nil end
					prev.byID={}
					prev.n=0
 				else
	 				local off = 0
	 				local byID, t_byID = prev.byID, t.byID
	 				for i=1,prev.n do
	 					i = i + off
	 					local id = prev[i]
	 					if t_byID[id] then
	 						off = off - 1
		 					byID[id]=nil
	 						table.remove(prev,i)
						end
	 				end
	 				if debugPrevious then 
	 					Echo('remove '..t.n,'on '..prev.n)
	 				end
	 				prev.n=prev.n + off
	 			end

 				-- local before = prev.n
 				-- for id in pairs(t.byID) do
 				-- 	local n = prev.byID[id]
 				-- 	-- Echo('removing',n,table.remove(prev,n))
 				-- 	table.remove(prev,n)
 				-- 	prev.n=prev.n-1
 				-- 	prev.byID[id]=nil
 				-- end
 				-- Echo('removed ',before-prev.n,'remain',prev.n)
 				-- for i,id in ipairs(prev) do Echo(i,id) end
 				prev.byType[prev.needErase]=nil
 			end
 		else -- normal all erase
 			if debugPrevious then Echo('prev: need erase of all') end

	 		for i=1,prev.n do prev[i]=nil end
			prev.byID={}
			prev.n=0
 		end
 		--Page(prev)
		prev.time=clock()
		prev.needErase=false
 	end
 	if prev.forgetTypes then -- for switching types only
 		prev.types={}
		prev.typeMax = 0
		prev.typeIndex = {}

 		prev.forgetTypes=false
 		prev.time=clock()
 		if debugPrevious then Echo('prev: type switching: all types have been forgotten') end
 	end

	--------

	local Type = call.byType
	if Type and call.choice and not prev.types[call.choice] then
		prev.typeMax = prev.typeMax + 1
		prev.typeIndex[prev.typeMax] = call.choice
		prev.types[call.choice]=prev.typeMax
		if debugPrevious then
			local Type = call.choice
			if call.byType == 'defID' and tonumber(Type) then
				Type = Type .. ' (' .. UnitDefs[Type].name .. ')'
			end
			Echo('prev: ' .. Type..' has been added to previous types at index ' .. prev.typeMax)
		end
	end

	-- if not (call.want or call.prefer) then  -- we don't need to rmb units in particular if no further filtering has been made
	-- 	if debugPrevious then
	-- 		Echo('prev: ----------- end of call ' .. call.name .. ', not registering individual units')
	-- 	end
	-- 	return
	-- end

	local thisType
	if Type and call.choice then 
		thisType = prev.byType[call.choice]
		if not thisType then
			prev.byType[call.choice] = {n=0,byID={}}
			if debugPrevious then Echo('prev: new folder for units of type '..call.choice..' has been created') end
			thisType = prev.byType[call.choice]
		end
	end
	local byID = prev.byID
	local cnt,tcnt = 0,0
	if not call.only_prevTypes then
		for id in pairs(g.acquired.byID) do 
			if not byID[id] then
				cnt=cnt+1
				prev.n=prev.n+1
				prev[prev.n]=id
				byID[id]=prev.n
				if thisType then
					thisType.n = thisType.n+1
					thisType[thisType.n]=id
					thisType.byID[id]=true
				end
			end
		end
	end
	if debugPrevious then
		if cnt>0 then
			Echo('prev: '..cnt..' units have been added to prev'..(thisType and "'s "..call.choice..' folder' or ''))
		end

		Echo('prev: --------- ' .. 'end of ' .. call.name)
	end
end

local function MergeSelToPrev(prev,sel)
	local byID = prev.byID
	local Type = call.byType
	local byType
	if debugPrevious then
		Echo('prev: merging from current sel...')
	end

	if Type then byType=prev.byType end
	local byId = prev.byID
	local count,already = 0, 0
	for _,id in ipairs(sel) do
		if not byID[id] then
			prev.byID[id]=true
			prev.n=prev.n+1
			prev.byID[id]=prev.n
			prev[prev.n]=id
			count = count + 1
			if byType then
				local k = Units[id][Type]
				local t = byType[Type] 
				if not t then 
					if debugPrevious then
						Echo('prev: merged a new type '..k)
					end

					byType[k]={n=0,byID={}} t=byType[k]
				end
				t.n=t.n+1
				t.byID[id]=t.n
				t[t.n]=id

				if not prev.types[k] then
					prev.typeMax = prev.typeMax + 1
					prev.typeIndex[prev.typeMax] = k
					prev.types[k]=prev.typeMax
					if debugPrevious then
						Echo('type ' .. k .. ' added to types at index ' .. prev.typeMax)
					end
				end
			end
		else
			already = already + 1
		end
	end
	if debugPrevious then
		Echo('prev: merged ' .. count .. ' units to prev' .. (already and ' there was already ' .. already .. ' unit(s) from that selection in prev.' or ''))
	end
end

local function TreatOrders(id,cmd,params)
	if params=='return' then
		local unit = Units[id]
		if not unit then
			return
		end
		local posx,_,posz = spGetUnitPosition(id)
		local return_pos=SetRetreat(id) or unit.createpos
		if not return_pos then
			return
		end
		-- get direction from return_pos to current unit position
		local dirx,dirz = posx-return_pos[1],posz-return_pos[3]
		local biggest = max(abs(dirx),abs(dirz))
		local dist = (dirx^2+dirz^2)^0.5
		dirx,dirz = dirx/biggest,dirz/biggest
		local send_posx,send_posz = return_pos[1]+dirx*56, return_pos[3]+dirz*56
		local send_posy = Spring.GetGroundHeight(send_posx,send_posz)
		spGiveOrderToUnit(id, CMD.MOVE, {send_posx,send_posy,send_posz},0)
		unit.returning = dist
		--spGiveOrderToUnit(id, CMD.MOVE, unpack(Units[id].pos))
	else
		spGiveOrderToUnit(id, cmd, unpack(params))
	end
end



local function TerminateCall()
	WG.EzSelecting = false
	if not call then return end
	-- Echo('terminating call', call.name)
	call.duration = os.clock() - call.clock
	if call.isChained then
		local thiscall = last.chained[#last.chained]
		if thiscall.name ~= call.name then
			-- Echo('ERROR, the current call about to get terminated differ from the last chained clal !',thiscall.name, call.name)
		end
		thiscall.duration = call.duration
		if thiscall.finished == 'unknown' then
			thiscall.finished = 'ignored'
		end
	end

	if not call.success then call.failed = true end


	last.acquired = g.acquired
	g.acquired,g.validUnits,g.selCost={n=0,byID={}},{n=0,byID={}},0
	g.hasPrefered=false
	g.bestOrder = false
	g.prefered={checked={},types={},default={types={}}}
	want=false
	call.pressed=false
	if call.groups then
		call.groups.last_selected = call.success and call.groups.selected
		call.groups.selectedNum = 0
	end

	call.defOnTheFly = nil
	call.choice = false
	call.good = false
	call.prevIgnore = false
	call.last_clock = call.clock
	call.secondary = false
	g.hkCombo=false
	call.results = false
	if not call.hide then DRAW.finishing=true end
	call.locked = false --unblock // TESTING ATM
	call = false
end
local function RealizeCall(call, selecting, acquired, lastSel, success)
	local byID = acquired.byID
	local off = 0
	-- fixing freeze?
	for i=1, acquired.n do
		i = i+off
		local valid = spValidUnitID(id) and not spGetUnitIsDead(id)
		if not valid then
 			table.remove(acquired,i)
 			off = off - 1
 			byID[id] = nil
		end
	end

	if call.mark_unit then -- realize
		for i,id in ipairs(acquired) do
			local unit = Units[id]
			if unit then
				local marked = unit.marked or {}
				for k,v in pairs(call.mark_unit) do
					marked[k] = type(v) == 'function' and v(id) or v
				end
				unit.marked = marked
			end
		end
	end
	if selecting  then
		local shift_on_defs = call.shift_on_defs
		if shift_on_defs then
			local t = {n=0,byID={}}
			local base = {}
			currentSel.n = #currentSel

			local _,n = ProcessFiltering(t,shift_on_defs,nil,currentSel,'FOR SHIFT ')
			currentSel.n = nil
			shift_on_defs = n>0
		end
		local shift = shift_on_defs or call.shift or call.shift_on_same_last_call and (last.call == call)
		local time = os.clock()
		if not call.ignore_no_select then
			local off = 0
			for i=1, acquired.n do
				i = i+off
				local id = acquired[i]
				local unit = Units[id]
				if unit then
					local marked = unit.marked
					if marked and marked.no_select then
						local timeout = NO_SELECT_TIMEOUT[unit.defID] or NO_SELECT_TIMEOUT_DEFAULT
						if time - marked.no_select < timeout then
				 			table.remove(acquired,i)
				 			off = off - 1
				 			byID[id] = nil
				 		else
				 			marked.no_select = nil
				 		end
				 	end
				end
			end
			acquired.n = acquired.n + off
		end
		local final = acquired
		if call.remove_last_sel and lastSel and lastSel.n>0 then
			-- remove from acquired what is in the last sel
			final,f,shift={},0,false
			local lsByID = lastSel.byID
			local off = 0

			for i=1, acquired.n do
				i = i+off
				local id = acquired[i]
		 		if lsByID[id] then
		 			table.remove(acquired,i)
		 			off = off - 1
		 			byID[id] = nil
		 		else
		 			f=f+1 final[f]=id
		 		end
		 	end
		 	acquired.n = acquired.n + off
		 	-- adding the current selection purged from what is in the last sel
			if shift_on_defs or call.shift or call.shift_on_same_last_call and (last.call == call) then
			 	for i,id in ipairs(currentSel) do
			 		if not lsByID[id] then f=f+1 final[f]=id end
			 	end
			end
		end
		-- last.sel=acquired
		for i,id in ipairs(final) do final[i]=spGetUnitTransporter(id) or id end
		-- if call.keep_on_fail and not final[1] then
		-- 	-- dont deselect
		-- else
		local _,_,_,namecom = spGetActiveCommand()
		if namecom and namecom == 'Fight' then
			spSetActiveCommand(0)
		end
			spSelectUnitArray(final,shift)
		-- end
		if not final[1] and shift then
			-- keep fullSel in case we were just adding but nothing found
		else
			fullSel = final[1] and final
		end
		-- Echo('finish call ',call.name,'with',g.acquired.n)
		---lockSelection=true
	 	if call.give_order then
	 		for _,id in ipairs(acquired) do
	 			for cmd,params in pairs(call.give_order) do
	 				TreatOrders(id,cmd,params)
	 			end
	 		end
	 	end
 		if not call.prevIgnore then UpdatePrev(call.previous) end
 	end
	------- Memorize the last selections for browsing macros
 	if call.method~='last' and call.method~='next' and not UselessSelection(g.Selections[g.Selections.n],g.acquired) then
 		if g.Selections.n==MAX_SELECTIONS then
 			table.remove(g.Selections,1)
 		else
	 		g.Selections.n=g.Selections.n+1
 		end
 		g.Selections[g.Selections.n]=g.acquired
 	end
 	---------
	-- memorizing last
	--
	if call.set_active_command and (acquired[1] or call.method == 'set_command') then 
		if call.set_active_command==CMD_LOADUNITS_SELECTED then
		-- this command seems bugged, depending on order of unit selected, it is not always available even though it should
			-- but we can trigger the gadget
			success = widgetHandler:CommandNotify(CMD_LOADUNITS_SELECTED,{},MODS_FALSE)
		elseif type(call.set_active_command) == 'string' then
				success = spSetActiveCommand(call.set_active_command)

		elseif call.set_active_command<=0 then
			success = spSetActiveCommand(call.set_active_command)
		else
			local comID
			for i,id in ipairs(acquired) do
				comID = Spring.FindUnitCmdDesc(id, call.set_active_command)
				if comID then
					break
				end
			end
			if comID then
				success = spSetActiveCommand(comID)
			end
		end
	end
	return success
end

local function FinishCall(selecting)
	local acquired = g.acquired
	local keep_on_fail = call.keep_on_fail or call.secondary and call.ifSecondary and call.ifSecondary.keep_on_fail
	selecting = selecting and not call.no_select and not (call.only_acquire or keep_on_fail and acquired.n==0)
	call.time_length = os.clock() - call.clock
	call.finished = 'finished'
	-- Echo('finish call', call.name)
	local byID = acquired.byID
	local success = g.acquired.n>0
	local jumpCall
	local lastSel = last.sel
	-- if success and call.call_on_only_defs then -- moved to the call execution rather
	-- 	local cnt = 0
	-- 	for defs, thiscall in pairs(call.call_on_only_defs) do
	-- 		cnt = cnt + 1
	-- 		local _,n = ProcessFiltering({n=0,byID={}},defs,nil,acquired, 'JUMP TO CALL ON DEFS #' .. cnt .. ' ')
	-- 		if n == acquired.n then
	-- 			jumpCall = thiscall
	-- 			selecting = false
	-- 			break
	-- 		end
	-- 	end
	-- end

	local retry
	if success and (call.fail_on_identical or call.retry_on_identical and not call.isTried and g.validUnits.n>0 and g.validUnits.n>acquired.n) then
		local identical = acquired.n == #currentSel
		if identical then
			for i,id in ipairs(currentSel) do
				if not byID[id] then
					identical = false
					break
				end
			end
			if identical then
					selecting = false
				if call.retry_on_identical and not call.isTried then
					retry = true
				elseif call.fail_on_identical then
					success = false
				end
			end
		end
	end

	local lchained =  last.chained[#last.chained]
	if lchained and lchained.call == call then
		lchained.success = success
		if sh.sw then
			lchained.name = lchained.name .. ' sw: ' .. sh.sw
		end

	end

	call.success = success
	-- Echo('BEFORE TRY', call.name,success and 'success' or 'no success','last chained','#'..#last.chained, lchained and lchained.name, lchained.call, call)

	if call.isTried then
		call.results = {selecting, acquired, lastSel, success}
		return
	end
	if (success and call.try_on_success or retry) and not call.isTried then
		local mycall = call
		local trycall = retry and call or call.try_on_success
		local try_takeover_conditions = call.try_takeover_conditions
		local realOnPress = trycall.on_press
		trycall.on_press = true
		trycall.isTried = true
		if retry then
			RealizeCall(call, true, acquired, lastSel, success)
		end
		TerminateCall()
		g.hkCombo = trycall
		g.keyChanged= true
		widget:DrawGenesis(0)
		local takeover
		if call and trycall==call and trycall.success then
			if try_takeover_conditions then
				takeover = try_takeover_conditions(trycall, acquired)
			else
				takeover = true
			end
		end

		if takeover then
			call = trycall
			selecting, acquired, lastSel, success = unpack(trycall.results)
			-- Echo('try succeed')
		else
			call = mycall
			-- Echo('keep mycall')
		end
		trycall.isTried = false
		trycall.on_press = realOnPress
		-- Echo('trying ...',os.clock(), trycall and trycall.name,'takeover?',takeover)


	end

	success = RealizeCall(call, selecting, acquired, lastSel, success)
	call.success = success

	local lchained =  last.chained[#last.chained]
	-- Echo('AFTER', "call.name,success is ", call.name,success and 'success' or 'no success','last chained','#'..#last.chained, lchained and lchained.name, lchained.call == call)
	if lchained and lchained.call == call then
		lchained.success = success
	end



	if success and call.remove_active_command then
		spSetActiveCommand(-1)
	end

	last.SelCost = g.selCost
	if sh then last.sh={} for k,v in pairs(sh) do last.sh[k]=v end end
	last.myUnits = myUnits
	last.call = call
	--
	-- Echo("call.success is ", call.success)
	local second_call = call.second_call
	

	if not success and call.switch then
		call.switch.current_defs = 0
	end
	call.failed = not success
	if success and call.OnSuccessFunc then
		call.OnSuccessFunc()
	end
	local call_on_fail = not success and call.secondary ~= call.call_on_fail and call.call_on_fail
	local call_on_success = success and call.secondary ~= call.call_on_success and call.call_on_success
	local force = call.force
	---------------
	TerminateCall()
	---------------
	--- extra calls
	if success and last.call.force_finish then
		widget:CommandsChanged()
		local selAPI = widgetHandler:FindWidget('Selection API')
		if selAPI then
			selAPI:CommandsChanged() -- update immediately the WG.selectionDefID
		end
		
	end
	if jumpCall then
		g.hkCombo=jumpCall
		g.hkCombo.secondary = last.call.secondary or last.call
		g.keyChanged=true
		-- Echo(last.call.name,'ON =>',g.hkCombo.name)
		widget:DrawGenesis(0)
	end		
	if call_on_fail or call_on_success then
		g.hkCombo=call_on_fail or call_on_success
		g.hkCombo.secondary = last.call.secondary or last.call
		g.keyChanged=true
		-- Echo(last.call.name,'ON =>',g.hkCombo.name)
		widget:DrawGenesis(0)
	end	
	if second_call then
		g.hkCombo=second_call
		-- Echo(last.call.name,'second =>',g.hkCombo.name) 
		g.hkCombo.secondary = last.call.secondary or last.call
		g.keyChanged=true
		widget:DrawGenesis(0)
	end
	return selecting or force
end
---------------------------------------
---------------------------------------
---------------------------------------

local OptimizeDefs
do ---- **INITIALIZATION** ------
	-- COMBO REGISTERING
	-- annexes
	local rand,rands = math.random,math.randomseed
	local function GetRandomizedColor(n1,n2,n3,alpha)
		-- create random but fixed color
		rands(n1*n2*n3) -- random seed based on 3 characteristic of the macro
		local a,b,c=0,0,0
		while (a+b+c)<2 do a,b,c=rand(),rand(),rand() end -- get a color with minimal brightness
		return {a,b,c,alpha}
	end
	local function Key(key) -- make unified coding of the key that KEYCODES can understand, except for clicks
		--return the KEYSYMS symbol format using eventually specialKeys from Configs/integral_menu_special_keys.lua and eventually the question mark
		if not key then return
		elseif type(key)=='table' then -- unused
			for i,k in ipairs(key) do key[i]=Key(k) end
			return key
		else
			local Or
			key=tostring(key)
		--	Echo('key is ', key)
			Or,key=key:match('?') or '', key:gsub('?','')

			key=KEYCODES[
						 KEYSYMS[key] or
						 KEYSYMS[string.upper(key)] or
						 tonumber(key) and KEYSYMS['N_' .. key] or
						 specialKeys[key]
						]
				or key
			return Or..key	
		end
	end
	-- register combos
	function HKCombos:Add()
		for i,macro in ipairs(hotkeysCombos) do
			self.length=i
			self[i]={keys={},name=macro.name,index=i}
			self.byName[macro.name]=self[i]
		end
		for i,macro in ipairs(hotkeysCombos) do
			self:Set(macro,i)
		end
		for i,macro in ipairs(self) do
			-- add some automatic OR keys if not specified already, simulating key press to check if some other macro got same set of keys with mouseStill and spam mods
			local keysByKey = {}
			for i,key in ipairs(macro.keys) do 
				if type(key) == 'table' then
					key = key[1]
				end
				keysByKey[key:gsub('?','')]=i
			end

			local hasClick,hasDouble
			for key in pairs(keysByKey) do
				if key:match('double') then
					hasDouble=true
				end
			end

			-- simulate mouseStill with longPress or longClick
			if (keysByKey['longPress'] or keysByKey['longClick'])
			and not (keysByKey['mouseStill'] or keysByKey['?mouseStill']) then
				keysByKey['mouseStill']=0
				if not HKCombos:Find(keysByKey,'dontRmb') then
					-- if nothing triggered, we can safely add the '?mouseStill' key
					table.insert(macro.keys,'?mouseStill')
				end
			end
			-- simulate spam if macro got a doubleTap or double click
			if hasDouble then
				keysByKey['spam']=0
				if not HKCombos:Find(keysByKey,'dontRmb') then
					-- if nothing trigggered,  we can safely add the '?spam' key
					table.insert(macro.keys,'?spam')
				end

			end
			if --[[macro.name:match('+1 Scout') or macro.name=='Set Scout' or--]] macro.name=='All Commandos' then
				-- Echo('--')
				-- Echo(macro.name)
				-- for i,key in ipairs(macro.keys) do
				-- 	Echo(i,key)
				-- end
			end
		end
		-- check for macro having longPressTime
		for i,macro in ipairs(self) do
			-- if the macro is a longPress (or click) and has a longPressTime get the shortPress version or make a dummy macro
			-- to tell the longPressTime in advance

			if macro.longPressTime and not macro.isShortPressVersion then
				local mouseStillThreshold = macro.mouseStillThreshold
				-- Echo('longPress macro : ' .. macro.name)
				local keysByKey = {}
				for i,key in ipairs(macro.keys) do 
					if type(key) == 'table' then
						key = key[1]
					end
					if not key:match('^%?')  then
						-- Echo('add to keysByKey',key .. ' = ' .. i)
						keysByKey[key] = i
					end
					-- keysByKey[key:gsub('?','')]=i
				end

				local hasClick,hasDouble
				for key in pairs(keysByKey) do
					if key:match('Click') then
						hasClick=true
					end
					if key:match('double') then
						hasDouble=true
					end
				end
				local pressOrClick = hasClick and 'Click' or 'Press'


				keysByKey['long'..pressOrClick]=nil
				keysByKey['mouseStill']=nil


				-- for k,v in pairs(keysByKey) do
				-- 	Echo('try',k,v)
				-- end
				local shortPress_version = HKCombos:Find(keysByKey,'dontRmb'--[[,'tell'--]])
				if not shortPress_version then
					-- create a dummy macro
					local realKeys = {}
					for i,key in ipairs(macro.keys) do
						if type(key) == 'table' then
							key = key[1]
						end

						if not (key:match('long'..pressOrClick) or key:match('mouseStill')) then
							table.insert(realKeys,key)
						end
					end
					-- Echo('create dummy')
					-- for k,v in pairs(realKeys) do
					-- 	Echo('=>',k,v)
					-- end
					self.length=self.length+1
					self[self.length]={keys=realKeys,dummy=true,longPressTime=macro.longPressTime,index=self.length}
					shortPress_version = self[self.length]
				else
					-- Echo('got real short press version', shortPress_version.name)
				end
				-- Echo('short press version : ' .. (shortPress_version.name or 'dummy'))
				shortPress_version.longPressTime = macro.longPressTime
				shortPress_version.mouseStillThreshold = mouseStillThreshold
				shortPress_version.isShortPressVersion = true
				macro.longPressTime = nil
				macro.mouseStillThreshold = nil
			end

			if macro.doubleTap_time and not macro.dummy then
				local keysByKey = {}
				-- Echo('--')
				local hasSpam
				for i,key in ipairs(macro.keys) do 
					if key:match('spam') then
						hasSpam = true
					end
					if not key:match('^%?') then
						keysByKey[key]=i
						-- Echo(key)
					end
				end
				-- Echo('--')
				keysByKey['doubleTap']=nil
				keysByKey['mouseStill']=nil
				keysByKey['spam']=nil

				local singleTap_version = HKCombos:Find(keysByKey,'dontRmb')
				if not singleTap_version then
					-- create a dummy macro
					local realKeys = {}
					for i,key in ipairs(macro.keys) do
						if type(key) == 'table' then
							key = key[1]
						end

						if not (key:match('doubleTap')) then
							table.insert(realKeys,key)
						end
					end
					self.length=self.length+1
					self[self.length]={keys=realKeys,dummy=true,doubleTap_time=macro.doubleTap_time,index=self.length}
					singleTap_version = self[self.length]
				end

				singleTap_version.doubleTap_time = macro.doubleTap_time
				macro.doubleTap_time=nil
			end
			if macro.fastDoubleTap_time and not macro.dummy then
				local keysByKey = {}
				local hasDoubleTap
				local hasFastDoubleTap = true
				for i,key in ipairs(macro.keys) do 
					if type(key) == 'table' then
						key = key[1]
					end
					if not key:match('^%?') and key~='fastDoubleTap' and key~='doubleTap' then
						keysByKey[key]=i
						-- Echo(key)
					end
				end
				local non_fastDoubleTap_version = HKCombos:Find(keysByKey,'dontRmb')
				if not non_fastDoubleTap_version then
					-- create a dummy macro
					local realKeys = {}
					for i,key in ipairs(macro.keys) do
						if type(key) == 'table' then
							key = key[1]
						end
						if not (key:match('fastDoubleTap')) then
							table.insert(realKeys,key)
						end
					end
					self.length=self.length+1
					self[self.length]={keys=realKeys,dummy=true,fastDoubleTap_time=macro.fastDoubleTap_time,index=self.length}
					non_fastDoubleTap_version = self[self.length]
				end

				non_fastDoubleTap_version.fastDoubleTap_time = macro.fastDoubleTap_time
				macro.fastDoubleTap_time=nil
			end
		end




	end
	-- function HKCombos:SetKeys(macro,keys,method,name)	
	-- 	for n,v in pairs(keys) do
	-- 		local key = Key(v)-- convert  to a unique coding (so user can write keys according to KEYSIMS coding or in a more intuitive manner if he want) 
	-- 		possibleKeys[key:gsub('?','')]=true -- remember possible key to avoid useless work in detection process
	-- 		if key:match('LClick') then macro.disable_SM=true end
	-- 		if method=='tmpToggle' then
	-- 			locks.tmpToggleByKey[key]=set
	-- 			locks.tmpPushed[name]=false
	-- 		end
	-- 		table.insert(macro.keys,key)
	-- 		-- self[i].keys[key]=n
	-- 	end

	-- end

	local optimizedProp = {	name=true,class=true,defID=true,family=true	}
	OptimizeDefs = function(defs,combo)
		if not defs then
			return
		end
		for k,v in pairs(defs) do
			if type(v) == 'table' then

				local strippedK = type(k)=='string' and k:gsub('[?!]','')
				if strippedK and optimizedProp[strippedK] then
					if not v._opti then
						local paired ={_opti=true}
						for i,val in ipairs(v) do
							paired[val] = true
						end
						defs[k] = paired
					end
				else
					defs[k] = OptimizeDefs(v,combo)
				end
			elseif type(v) == 'string' and v:lower():match('transport') then
				combo.specifyTransport = true
			end
		end
		return defs
	end

	function HKCombos:Set(set,i) -- set proper parameters for each combo on initialization
		local combo = self[i]
		local usePreviousSystem = (set.use_prev or set.current_to_prev or set.shared_prev) and not set.no_prev
		if set.keys then --register keys
			local function addkey(key, n)
				key = Key(key)-- convert  to a unique coding (so user can write keys according to KEYSIMS coding or in a more intuitive manner if he want) 
				possibleKeys[key:gsub('?','')]=true -- remember possible key to avoid useless work in detection process
				if key:match('LClick') then
					combo.disable_SM=true
				end
				return key
			end
			for n,key in pairs(set.keys) do
				if type(key) == 'table' then
					for i, k in ipairs(key) do
						k = addkey(k, n)
						key[i] = k
					end
				else
					key = addkey(key,n)
					if (set.method=='tmpToggle' or set.isTmpLock) and not key:find('?') then
						locks.tmpToggleByKey[key]=set.isTmpLock and self.byName[set.isTmpLock] or set
						locks.tmpPushed[set.isTmpLock or set.name]=false
					end
				end
				table.insert(combo.keys,key)
				-- combo.keys[key]=n
			end
			combo.no_key_order = set.no_key_order
		end



		combo.on_delay = set.on_delay -- wait some delay before applying the call, might be needed when we have to wait for server response (ordering unit)

		
		-- Define the base of units to filter
		combo.method=set.method -- the method we gonna use to define our base of units that will be then filtered by definitions
		combo.from_cursor=set.from_cursor -- reorder base units to select closest of cursor amongst filtered units first (if we will not pick them all bc of 'want' or 'byType' etc)

		combo.pos_from_selected = set.pos_from_selected  -- this will set the circle of selection from the first selected unit's poses instead of the mouse, if method 'cylinder' or prop 'from_cursor'
		if set.method == 'around_selected' or set.method == 'around_last_acquired' then
			-- this will add up units to the base that are around each selected/last_acquired
			combo.around_radius = set.around_radius or 500
		end
		combo.hasStructure = set.hasStructure -- fasten the filtering by removing from myUnits (base) any structure building if this prop is not present
		--

		-- Definitions of filters
		combo.must_have = OptimizeDefs(set.must_have, combo) -- define units that user must have in selection for the call to pursue
		combo.defs=OptimizeDefs(set.defs,combo)
		combo.shift_on_defs = OptimizeDefs(set.shift_on_defs, combo)
		combo.add_last_call_pool = set.add_last_call_pool
		combo.add_last_call_pool_if = set.add_last_call_pool_if
		if set.call_on_only_defs then
			combo.call_on_only_defs = {}
			for defs,callName in pairs(set.call_on_only_defs) do
				combo.call_on_only_defs[OptimizeDefs(defs, combo)] = callName
			end
		end

		if set.switch then
			-- switch through all definitions immediately until one find matchings
			-- switch is incremented at each call, reset after some time
			combo.switch=OptimizeDefs(set.switch, combo)
			combo.switch.reset_time = set.switch_time or 1
			combo.switch.current_defs = 0
			combo.switch.time = 0

		end

		if set.groups then
			combo.groups = set.groups
			combo.from_cursor = true
			combo.groups.selected = false
			combo.groups.selectedNum = 0
			combo.switch_groups = set.switch_groups
			combo.last_selected = false
		end


		if combo.switch or set.shared_switch or combo.groups then
			combo.switch_on_identical = set.switch_on_identical
		end
		combo.add = OptimizeDefs(set.add, combo) -- add units once at least one unit have been filtered in through the main definitions
		combo.default = OptimizeDefs(set.default, combo) -- default definitions applying until at least one unit have been found matching the main definitions
		if set.same_units then
			-- similar units as previous selection, plate and factory get along
			-- modify temporarily call.defs and call.switch defs to match those states
			combo.same_units=set.same_units
			if not combo.defs then combo.defs={} end
		end
		-- same transporting/transported state as first found in selected
		-- modify temporarily call.defs and call.switch defs to match those states
		combo.same_transported_state = set.same_transported_state
		combo.same_transporting_state = set.same_transporting_state
		
		--
		combo.fail_on_identical = set.fail_on_identical

		combo.add_last_acquired = set.add_last_acquired -- reacquire what we acquired on the last call, that will be selected at the end

		combo.mark_unit = set.mark_unit -- add a prop to Units[id] table

		-- order of preference when call is using byType
		if type(set.typeOrder)=='string' then
			combo.typeOrder = set.typeOrder
		elseif set.typeOrder then
			combo.typeOrder={}
			local cnt = 0
			for i,type in ipairs(set.typeOrder) do
		 		combo.typeOrder[type] = i
		 		cnt = cnt + 1
		 	end
		 	combo.maxOrder = cnt
		end
		
		
		combo.force_finish = set.force_finish

		combo.ifSecondary = set.ifSecondary -- not fully implemented, apply those property if the call if secondarily launched by another


		-- ignore units marked as no_select rendering them selectable for this call
		combo.ignore_no_select = set.ignore_no_select
		--
		-- call function on success
		combo.OnSuccessFunc = set.OnSuccessFunc


		combo.longPressTime = set.longPressTime -- user defined time threshold for long press
		combo.doubleTap_time = set.doubleTap_time -- user defined time threshold for double tap
		combo.fastDoubleTap_time = set.fastDoubleTap_time

		combo.disable_SM = combo.disable_SM or set.disable_SM
		---------
		combo.option_name = set.option_name -- for hotkey modifying option

		if set.prefer then -- setup refined preferences that will override the matched but also added into 'previous' system
			-- prefer can have hierarchy by subsets index, if no indexed subtable found, we create one
			if type(set.prefer[1])~='table' then set.prefer={set.prefer} end
			-- Add an empty table at the end to represent units not fitting any preference
			if set.avoid_non_pref then
				combo.avoid_non_pref = true
			else
				table.insert(set.prefer,EMPTY_TABLE) -- treat the non prefered as prefered but with the lesser value
			end
			combo.prefer=OptimizeDefs(set.prefer, combo) 
			if not set.no_prev then
				usePreviousSystem = true
				combo.pref_use_prev = set.pref_use_prev

			end
		end
		--
		-- special case of ordering
		combo.give_order=set.give_order -- for sending orders 
		combo.brush_order=set.brush_order -- same but without selecting them
		combo.set_active_command=set.set_active_command -- set active command at the end of the call
		combo.remove_active_command = set.remove_active_command
		--
		combo.remove_last_sel = set.remove_last_sel -- don't keep/reselect anything that has been acquired from a previous combo
		combo.ignore_from_sel = set.ignore_from_sel  --don't consider units that are already selected
		--set.ignore_from_sel
		-- ways of selecting
		combo.continue=set.continue -- resetting call continuesly
		combo.early=set.early -- select on press, and on release (can be useful in some trickier scenario)
		combo.on_press=set.on_press or set.method=="next" or set.method=="last"-- select only on press and end the call immediately-- you can change the radius of that call within 5 seconds by holding alt and rolling the wheel
		combo.clock = clock()
		combo.last_clock = combo.clock


		combo.proximity=OptimizeDefs(set.proximity, combo) -- pickup another batch of units that are around the defined units -- see example 'Tac Stuff' in the macro table
		combo.keep_on_fail=set.keep_on_fail -- if there's nothing found, we keep the previous selection
		combo.shift=set.shift -- add to previous selection
		combo.shift_on_same_last_call = set.shift_on_same_last_call -- shift is used if last.call is the same as the current call

		-- discriminate by family,class or defID of unit and switch them with 'previous' system
		if set.byType then
			combo.byType=set.byType
			if not set.no_prev then
				usePreviousSystem = true
			end
			combo.from_cursor=set.from_cursor -- select closest of cursor amongst valid units
		end
		--
		--- restricted number selection within the matched units
		if set.want or set.wantIf then
			if set.wantIf then
				combo.wantIf = set.wantIf
				for def,n in pairs(combo.wantIf) do
					combo.wantIf[OptimizeDefs(def, combo)] = n
				end
			end
			if set.want then
				set.want=tostring(set.want)
				combo.percent, combo.want = set.want:match('%%') and true, tonumber(set.want:match('-?%d+'))
			end

			if not set.no_prev then
				usePreviousSystem = true
			end
		end
		--
		if set.share_radius then
			combo.share_radius = set.share_radius
		end
		if set.finish_current_call then
			combo.finish_current_call = true
		end

		if set.no_select then
			combo.no_select = true
		end
		if set.try_on_success then
			combo.try_on_success = self.byName[set.try_on_success]
			combo.try_takeover_conditions = set.try_takeover_conditions
		end


		--- cycle meta macro -- multiple trigger of the same combo will result in calling a new macro each time
		if set.cycle then 
			combo.cycle=set.cycle
			combo.cycle.selected=0
			combo.time=set.time -- reset to first item after a given time
			combo.timecheck= set.time and CheckTime("start") or nil
		end
		--
		combo.doRepeat=set.doRepeat -- repeat call on longPress
		combo.force=set.force -- override regular hotkeybound, but not the building ones for now
		combo.selname=set.selname


		-- radius for cylinder method, memorized for each combo over games
		if set.method=='cylinder' then
			combo.radius= set.radius or memRadius[set.name] or 650
		end

		combo.fixed_radius = set.fixed_radius

		combo.removekey=set.removekey -- for temporary toggle, if we want only the toggle mod to appear in the combo, and not the key itself
		----- optionable drawing ------
		combo.color=set.color  or GetRandomizedColor(#set.name, i , #set.method, set.method=='cylinder' and 1 or 0.6)
		combo.fading=set.fading or combo.color[4]
		combo.hide=set.hide

		-- Lock setting
		combo.isTmpLock = set.isTmpLock -- a normal combo can also trigger a temporary toggle of a Lock
		if set.method=='toggleLock' and not set.hide then
			combo.draw_pos=set.draw_pos or {0,resY-(68+22*locks.count)}
			combo.size=set.size or 35
			combo.active=false -- config data will update it
			table.insert(locks,combo)
			-- locks[set.name]=combo
			locks.count=locks.count+1
		else
			combo.draw_pos= set.draw_pos or set.method=='cylinder' and DEFAULT_CYLINDER_DRAW_POS or DEFAULT_DRAW_POS
			combo.size=set.size or 25
		end
		--------

		combo.OnCallFunc=set.OnCallFunc

		if usePreviousSystem then
			if set.reset_previous_on_reset_switch and combo.switch then
				combo.reset_previous_on_reset_switch = true
			end
			combo.current_to_prev = set.current_to_prev
			combo.no_pick_in_prev = set.no_pick_in_prev
			combo.previous_time=set.previous_time or 5 
			combo.previous= {byID={},n=0,time=clock(),previous_time=combo.previous_time}
			if combo.byType then
				combo.only_prevTypes = set.only_prevTypes
				combo.previous.byType={}
				combo.previous.types={}
				combo.previous.typeMax = 0
				combo.previous.typeIndex = {}
			end

		end

		combo.mouseStillThreshold = set.mouseStillThreshold
		------- PENDING SETTING: in a few cases, we may need to point to macros that have not been registered yet
		--------TODO: make a generic function for those
		------- therefore we mark the future macro to get notified and update it backward.
		combo.retry_on_identical = set.retry_on_identical
		if set.shared_prev then combo.previous = self.byName[set.shared_prev].previous  end
		if set.shared_switch then combo.switch = self.byName[set.shared_switch].switch   end
		if set.second_call then combo.second_call = self.byName[set.second_call] end
		if set.call_on_fail then combo.call_on_fail = self.byName[set.call_on_fail]  end
		if set.call_on_success then combo.call_on_success = self.byName[set.call_on_success]  end
		if set.call_on_only_defs then 
			for defs, callName in pairs(combo.call_on_only_defs) do
				combo.call_on_only_defs[defs] = self.byName[callName]
				self.byName[callName].calledFrom=combo
			end
		end
		combo.repeated = 0 --- not implemented?
		combo.duration = 0
		combo.no_force = set.no_force
		---
		if not (combo.defs or combo.switch) then
			combo.defs = {}
		end
		ownedCombos[set.name]=i 
	end
	------------------------------------------------------------------------
	-- Initialize
	-- local DisableOnSpec = f.DisableOnSpec(_,widget,'setupSpecsCallIns') -- initialize the call in switcher
	function WidgetInitNotify(w,name,preloading)
		if name == 'Chili Integral Menu' then
			IM = w
		end

		if preloading then
			return
		end
		


	    if name == 'Selection Hierarchy' then
	    	g.SelFiltering = w.options.useSelectionFilteringOption
	    end
	    if name == 'Selection Modkeys' then
	    	g.SM_Enabled = w.options.enable
	    end
		if name == 'UnitsIDCard' then
			if WG.UnitsIDCard and WG.UnitsIDCard.active then
				Units = WG.UnitsIDCard
				widgetHandler:Wake(widget)
			end
		end
	end
	function WidgetRemoveNotify(w,name,preloading)
		if name == 'Chili Integral Menu' then
			IM = nil
		end

		if preloading then
			return
		end

	    if name == 'Selection Modkeys' then
	    	g.SM_Enabled = EMPTY_TABLE
	    end
	    if name == 'Selection Hierarchy' then
	    	g.SelFiltering = EMPTY_TABLE
	    end

		if name == 'UnitsIDCard' then
			widgetHandler:Sleep(widget)
		end
		
	end



	function widget:Initialize()
	    -- if not WG.Dependancies:Require(widget,'Command Tracker',true) then
	    --     widgetHandler:RemoveWidget(self)
	    --     return
	    -- end
		Screen0		= WG.Chili.Screen0

		if Spring.GetSpectatingState() or Spring.IsReplay() --[[or string.upper(Game.modShortName or '') ~= 'ZK'--]] then
			-- widgetHandler:RemoveWidget(self)
			-- return
		end
		if not (WG.UnitsIDCard and WG.UnitsIDCard.active) then
			if not WG.Cam then
				widgetHandler:RemoveWidget(self)
				return
			end
		end
		if not WG.selectionMap then
			Echo(widget:GetInfo().name .. ' requires Selection API')
			widgetHandler:RemoveWidget(self)
			return
		end

		local SelHierarchy = widgetHandler:FindWidget("Selection Hierarchy")
		if SelHierarchy then
			g.SelFiltering = SelHierarchy.options.useSelectionFilteringOption
		end
	    local SM = widgetHandler:FindWidget('Selection Modkeys')
	    if SM then
	    	g.SM_Enabled = SM.options.enable
	    end

	    IM = widgetHandler:FindWidget('Chili Integral Menu')
	    Units=WG.UnitsIDCard and WG.UnitsIDCard.active and WG.UnitsIDCard or WG.Cam.Units
	    Cam = WG.Cam

	    -- DisableOnSpec(widgetHandler,widget)-- setup automatic callin disabler

	    


		-- UnitsIDCard widget
	    --
	    --
		resX, resY = widgetHandler:GetViewSizes()
		HKCombos:Add(hotkeysCombos)
		hotkeysCombos=nil
		widget:SelectionChanged(spGetSelectedUnits())
		widget:CommandsChanged()
		if Spring.GetGameFrame()>0 then 

			widget:GameStart()
			-- widgetHandler:RemoveWidgetCallIn("GameFrame", self)
		else -- deactivate any sensible callin during pre-game
			-- widgetHandler:RemoveWidgetCallIn("Update", self)
			-- widgetHandler:RemoveWidgetCallIn("KeyPress", self)
			-- widgetHandler:RemoveWidgetCallIn("MousePress", self)
			-- widget._AfterKeyRelease = widget.AfterKeyRelease
			-- widget.AfterKeyRelease = function()end
		end
	end
end


---------------------------------------
---------------------------------------
---------------------------------------
-----------	COMBO DETECTION -----------
do
	--// Annexes
	-- Finding own macros
	local valids,wrongs={},{}  --memorize combinations as string to call them faster, or reject them faster
	local spScaledGetMouseState = Spring.ScaledGetMouseState
	local GetLastUpdateSeconds = Spring.GetLastUpdateSeconds
	local spIsGUIHidden = Spring.IsGUIHidden
	function HKCombos:Find(pressedKeys,dontRmb,tell)
		if WG.panning then
			return
		end
		-- pick directly the right combo memorized by string of key pressed, if we wrote them down already
		local str='' 
		for key,pushed_N in pairs(pressedKeys) do str=str..key..pushed_N end
		-- Echo("str is ", str)
		local found,wrong=valids[str],wrongs[str]
		if found then return self[found] elseif wrong then return end
		--
		local length=l(pressedKeys)

		local keys
		local req_N = 0
		local notOrdered
		local last_pushed_N = 0
		local reqKey
		local valid
		local name
		-- local txt = '' for k,v in pairs(pressedKeys) do txt=txt..'|'..k..':'..v end
		local function isValidKey(key,i)
			local keyIsOptional, key = key:match('?'),key:gsub('?','') -- remove the '?' and note it is optional 

			local pushed_N = pressedKeys[key]
			if keyIsOptional then
				if not pushed_N then req_N=req_N-1 end
				valid=true
			elseif pushed_N then
				if notOrdered or pushed_N==0 or last_pushed_N < pushed_N then
					valid=true
				-- elseif debug then
				-- 	Echo("last_pushed_N, pushed_N, last_pushed_N < pushed_N is ", last_pushed_N, pushed_N, last_pushed_N < pushed_N)
				end
				if pushed_N > 0 then
					last_pushed_N = pushed_N
				end
				
			end
			-- if name == 'Raiders' then
			-- 	for k,v in pairs(pressedKeys) do
			-- 		Echo(k,v)
			-- 	end
			-- 	Echo("keyIsOptional, key is ", keyIsOptional, key, pushed_N,'valid',valid)
			-- end
			return valid
		end
		-- Echo("---- length:", length,'txt: '.. txt)

		for i=1,#self do
			-- local debug = tell and self[i].name and self[i].name:match('More Likho')
			name = self[i].name
			keys=self[i].keys
			req_N = 0
			notOrdered = self[i].no_key_order
			last_pushed_N = 0


			for n,key in ipairs(keys) do -- browse through keys required by the macro
				reqKey = key
				valid=false
				req_N=req_N+1
				-- unused,not sure it's working - treating OR operator signified by the presence of a subtable containing keys
				-- if debug then
				-- 	Echo('required key',reqKey)
				-- end
				if type(reqKey)=='table' then -- 
					for _,orKey in ipairs(reqKey) do
						if isValidKey(orKey) then
							break
						end
					end
				-- 
				else
					isValidKey(reqKey)
				end
				-- if debug then
				-- end
				-- if self[i].name=='All Commandos' then
				-- 	Echo('--',os.clock())
				-- 	Echo('key asked: ' .. reqKey)
				-- 	local keyIsOptional, key = reqKey:match('?'),reqKey:gsub('?','') -- remove the '?' and note it is optional 
				-- 	Echo('pressed?', pressedKeys[key])
				-- 	if not pressedKeys[key] and keyIsOptional then
				-- 		Echo('ok, not required...')

				-- 	else
				-- 		Echo('req_N is ', req_N)

				-- 	end
				-- 	Echo('valid?', valid, valid and self[valid].name or '')
				-- end
				if not valid then break end
			end
			-- verify that we are not dealing with a macro that need less keys than we have pressed, and we're good to go
			if valid and req_N==length then
				if not dontRmb then
					valids[str]=i -- memorize for faster indexing
				end
				-- Echo('RETURN', self[valid].name)
				return self[i]
			end
		end
		if not dontRmb then
			wrongs[str]=true
		end
	end
	---- Key Binding Detection
	local function FindTabHotkeys() -- annex of HotkeyIsBound
		local tabKeys={}
		if not WG.IntegralVisible and not IM then return tabKeys end
		local integralwindow=Screen0:GetChildByName("integralwindow")
		local tabs--,panel,layout1,layout2=false,false,false,false
		for _,child in ipairs(integralwindow.children) do

			local subchild=child.children[1]
			if subchild then 
				if subchild.name:match("stackpanel") then
				tabs=subchild
			-- TODO: make hotkey detection more clean when I will find out how to manipulate those objects without touching Integral Menu
			--[[elseif subchild and subchild.name:match("control") then  
					layout1=subchild.children
					layout2=child.children[2] and child.children[2].children--]]
				end
			end
		--[[if child.name:match("panel") then
				panel=child
			end--]]
		end
		if tabs then
			for _,tab in ipairs(tabs.children) do
				local name=tab.caption:match("%a+%s")
				local key= not tab.caption:match('%((%a)%)') and tab.caption:match('%(.*(%a)') -- second match will tell us those hotkeys are active bc of the colored text
				if key then tabKeys[key:lower()]=name end
			end
		end
		return tabKeys--, panel, tabs, layout1,layout2
	end
	local spGetKeyBindings 		= Spring.GetKeyBindings
	local spGetActiveCmdDescs   = Spring.GetActiveCmdDescs
	local function HotkeyIsBound(keyset) -- verify if there is already an hotkey active
		-- we find which hotkeys are active depending on the unit(s) selected, including tab menu hotkey from integral menu
		if pcall(char, keyset) then
			local tabKeys= FindTabHotkeys()
			if tabKeys[char(keyset)] then return tabKeys[char(keyset)].." Tab" end
		end
		local keyActions=spGetKeyBindings(keyset)
		if keyActions then
		 	local activeCommands=spGetActiveCmdDescs()
		 	for _,keyAction in ipairs(keyActions) do
				 for i,command in ipairs(activeCommands) do
			 		--if command.id>=0 then -- skip the building commands
			 			
				 		if command.action==keyAction.command then
				 			return command.action
				 		end
				 	--end
				end
			end
		end
		return false
	end
	--///
	------------
	-- KEY PRESS update currentCombo.keys with key or click and detect a call
	------------
	function AfterKeyPress(key, mods, isRepeat, keyset)
		-- Echo('after KP')
		-- if isRepeat then
		-- 	return
		-- end
		-- if call then
		-- 	return
		-- end
		-- local symbol = KEYCODES[key]
		if not currentCombo.raw[key] then
			-- Echo('EzSel: the key ', symbol, 'has been eaten ' .. ' fixing it')

			
			-- currentCombo.keys[symbol]=l(currentCombo.keys)+1
			-- if call then
			-- 	if call.force_finish then
			-- 		FinishCall(not call.brush_order)
			-- 	else -- though we stop the current call -- maybe it should be optionable
			-- 		TerminateCall()
			-- 	end
			-- end
			-- longPress.key = false
			-- longPress.active=false
			-- currentCombo.keys['mouseStill']=nil
			-- currentCombo.keys['longPress']=nil
			-- currentCombo.keys['longClick']=nil
			widget:KeyPress(key, mods, false, keyset)
		end
	end
	function AfterMousePress(mx,my,button, from, locked, owner)
		-- if from == 'MousePress' then -- this is either our own or a locked
		-- 	return
		-- end
		-- Echo('after KP')

		local buttonName = (button==1 and 'L' or button==2 and 'M' or 'R')..'Click'
		-- if g.lastKey~= buttonName then

		if not currentCombo.raw[buttonName] then
			-- if not widgetHandler.mouseOwner or widgetHandler.mouseOwner:GetInfo().name~='Pan View' then
				local owner = owner and owner:GetInfo().name or 'no owner'
				-- if owner~='EzTarget' and owner ~= 'Pan View' and owner ~= 'Draw Placement' and owner ~= 'CustomFormations2' then
				if owner~='EzTarget' and owner ~= 'Pan View' and owner ~= 'Draw Placement' and owner ~= 'CustomFormations2' and owner~='Mex Placement Handler' then
					-- Echo('EzSel: the button ' .. buttonName ..  'has been eaten by a widget, fixing it','from?',from,'locked?',locked, 'owner: ',owner )
				end
			-- end
			widget:MousePress(mx,my,button)
		end
		-- 	currentCombo.keys[buttonName]=l(currentCombo.keys)+1
		-- 	if call then
		-- 		if call.force_finish then
		-- 			FinishCall(not call.brush_order)
		-- 		else -- though we stop the current call -- maybe it should be optionable
		-- 			TerminateCall()
		-- 		end
		-- 	end
		-- 	longPress.key = false
		-- 	longPress.active=false
		-- 	currentCombo.keys['mouseStill']=nil
		-- 	currentCombo.keys['longPress']=nil
		-- 	currentCombo.keys['longClick']=nil
		-- end
	end
	function AfterMouseRelease(mx,my,button, from, wasOwner)
		local buttonName = (button==1 and 'L' or button==2 and 'M' or 'R')..'Click'
		if currentCombo.raw[buttonName] then
			-- local owner = wasOwner and wasOwner:GetInfo().name
			-- if owner and  owner~='EzTarget' and owner ~= 'Pan View' and owner ~= 'Draw Placement' and owner ~= 'CustomFormations2' and owner~='Mex Placement Handler' then
			-- 	-- Echo('we missed release of button '.. buttonName, owner )
			-- end
			-- CheckClick()
			widget:MouseRelease(mx,my,button)
		end
	end
	function AfterKeyRelease(key,...)
		if currentCombo.raw[key] then
			-- local thiskey = KEYCODES[key]
			-- Echo('we missed key ', thiskey, key)
			widget:KeyRelease(key,...)
		end
	end


	function widget:KeyPress(key, mods, isRepeat, keyset)

		-- Echo('home KP')
		-- Echo(key, 'isRepeat', isRepeat,'longPress',longPress.key,os.clock())

		if isRepeat then 
			if not currentCombo.raw[key] then
				Echo('EZ SELECTOR: KEY IS REPEATED BUT DIDNT GET REGISTERED', KEYCODES[key] or key)
			end
			return
		end

		currentCombo.raw[key] = true
		local isCtrlGroup

		if key~=longPress.key then
			local now = os.clock()
			g.lastKey = key
			g.lastPress = now
			longPress.time = now
			longPress.key = false
			longPress.active=false
		else

			-- local tm = os.clock() - g.lastPress
			-- if tm < 0.05 then
			-- 	Echo(KEYCODES[key] or key, 'getting spammed !','already pressed?', currentCombo.keys[ KEYCODES[key] ], tm, 'current long press time?', currentLongPressTime)
			-- 	return
			-- end
		end
		if g.debuggingKeyDetections and not longPress then Echo('KeyPress Got:',KEYCODES[key] or key) end
		if not longPress.active then -- updating current Combo and verify if there's a matching call
			if g.debuggingKeyDetections and  lockedCall then Echo('a new key (non repeated) is pressed, unlocking potential call...') end
			----- UPDATING CURRENT COMBO
			local click = not KEYCODES[key] and key -- key can be a number mouse's button sent by MousePress or CheckClick
			local symbol = click or KEYCODES[key]


			ctrlGroups.selecting = false
			if mods then
				local keybSym = KEYCODES[key]
				local num = keybSym:find('N_%d') and tonumber(keybSym:sub(3,-1))
				if num then
					if mods then
						if mods.ctrl then
							ctrlGroups:Set(num)
							isCtrlGroup = true
						elseif not (mods.alt or mods.meta or mods.shift) then
							local byKey = ctrlGroups.byKey[num]
							if byKey then
								ctrlGroups.selecting = num
							end
						end
					end

				end
			end





			if currentCombo.keys[symbol] then
				Echo('the key ', symbol, key,'has already been registered !',os.clock() - g.lastPress)
			end
			currentCombo.keys['mouseStill']=nil
			currentCombo.keys['longPress']=nil
			currentCombo.keys['longClick']=nil
			currentCombo.keys[symbol]=l(currentCombo.keys)+1
			-- Echo('pressed ' .. symbol .. ' at ' .. l(currentCombo.keys))
			if not g.gameStarted or not possibleKeys[symbol] or WG.panning then   -- this key doesnt belong to any combo, no need to go any further
				if call then 
					if call.force_finish then
						FinishCall(not call.brush_order)
					else -- though we stop the current call -- maybe it should be optionable
						TerminateCall()
					end
				end
				return isCtrlGroup
			end
			-- managing temporary lock
--[[			local tmpToggle = locks.tmpToggleByKey[symbol]
			if tmpToggle then
				Echo('TMP')
				local tog_name = tmpToggle.name
				locks.tmpPushed[tog_name]=true
				currentCombo.keys[tog_name]=currentCombo.keys[tog_name]==nil and 0 or nil
				Echo("HKCombos:Find(currentCombo.keys) is ", HKCombos:Find(currentCombo.keys))
			end--]]
			---
			local newPressTime = clock()
			longPress.time=newPressTime
			longPress.key=key
			longPress.mx, longPress.my = spGetMouseState()
			longPress.mouseStill = true
			--**managing doubleTap/ doubleClick and spam**--
			local doubled, fast_doubled
			local time_double = last.previousKey==key and newPressTime-g.pressTime
			if time_double then
				if time_double<currentDoubleTapTime+g.lagFactor/3 then
					doubled = 0
					if time_double<currentFastDoubleTapTime then
						fast_doubled = 0
					end
				end
			end
			local doubleKey = (click and 'double'..click or 'doubleTap')

			local spam = (doubled and last.previousDouble==doubleKey) and 0 or nil

			currentCombo.keys[doubleKey] = doubled
			currentCombo.keys['fast' .. doubleKey:gsub('double','Double')] = fast_doubled
			currentCombo.keys['spam']=spam or nil
			g.pressTime=newPressTime--spGetTimer()
			--

			last.previousKey=key
			last.previousDouble=doubled and doubleKey
			--if keyset==showcombo then showComboInLog=not showComboInLog end
			g.keyChanged=true
			--Echo(" is ", spDiffTimers(spGetTimer(), g.pressTime),'lag',g.lagFactor/3)
			--Echo(clock()-g.pressTime)
			--------------------------
			local newcall = not WG.panning and HKCombos:Find(currentCombo.keys)

			if newcall and call and (newcall==call or newcall==call.secondary) then
				g.keyChanged = false
				return isCtrlGroup
			end
			if call then
				if call.force_finish or newcall and newcall.finish_current_call then
					FinishCall(not call.brush_order)
				else
					TerminateCall()
				end
			end

			-- found a call?
			if newcall then 
				if newcall.longPressTime then
					currentLongPressTime =newcall.longPressTime
				else
					currentLongPressTime = LONGPRESS_THRESHOLD
				end
				if newcall.doubleTap_time then
					currentDoubleTapTime =newcall.doubleTap_time
				else
					currentDoubleTapTime = DOUBLETAP_THRESHOLD
				end
				if newcall.fastDoubleTap_time then
					currentFastDoubleTapTime =newcall.fastDoubleTap_time
				else
					currentFastDoubleTapTime = FASTDOUBLETAP_THRESHOLD
				end

				if newcall.dummy then
					return isCtrlGroup
				end
				g.hkCombo = newcall

				if newcall.removekey then currentCombo.keys[symbol]=nil end
				--showComboInLog=showComboInLog==nil or nil
									-- checking matching keybind vs active cmd or tab hotkey, then verify building grid hotkey from Integral Menu
				if not click and not g.hkCombo.force then
					if  HotkeyIsBound(keyset) then
						g.hkCombo=false
						if g.debuggingKeyDetections then Echo('KeyPress doesnt block, found a regular hotkey bound to the combination: '..g.hotkeyAlreadyBound) end
						return isCtrlGroup
					elseif IM and IM:KeyPress(key, mods, isRepeat) then -- trigger the Integral Menu to check for an action and ignore the call  and block the key if the action occured
						g.hkCombo=false
						return true
					end
				end
				-- cancelling potential call if a relevant command is active, or cancelling the command if .force is true
				local _,_,_,namecom = spGetActiveCommand()

				if nameom and namecom ~='Fight' and not (g.hkCombo and g.hkCombo.option_name) then
					if g.hkCombo and g.hkCombo.force then
						spSetActiveCommand(0)
					else
						g.hkCombo=false
						return isCtrlGroup
					end
				end
				-- updating toggle if any
				local lockName = (g.hkCombo.method=='toggleLock' or g.hkCombo.method=='tmpToggle') and g.hkCombo.name or g.hkCombo.isTmpLock
				if  lockName then -- setting up toggle if any -- replacing the key by the toggle
					currentCombo.keys[lockName]= currentCombo.keys[lockName]==nil and 0 or nil -- toggling with nil instead of false
					if g.hkCombo.method=='tmpToggle' or g.hkCombo.isTmpLock then
						locks.tmpPushed[lockName]=true
					end
					if not g.hkCombo.isTmpLock then
						g.hkCombo=false
						return true
					end
				end
			elseif not newcall then
				currentLongPressTime = LONGPRESS_THRESHOLD
			end -- end of non repeat
		-- CASE: long press active (custom repeat)
		elseif not (call and call.locked) then---- checking if any combo has longPress if we're allowed to
			if longPress.mouseStill then
				currentCombo.keys['mouseStill']=0
			else
				currentCombo.keys['mouseStill']=nil
			end
			local click = not tonumber(key)
			currentCombo.keys['long'..(click and 'Click' or 'Press')]=0
			currentCombo.keys['long'..(click and 'Press' or 'Click')]=nil
			local callCheck=HKCombos:Find(currentCombo.keys)
			if callCheck then
				if callCheck~=g.hkCombo or callCheck.doRepeat then
					if call then
						if callCheck.doRepeat or callCheck.finish_current_call or call.force_finish then
							FinishCall(not call.brush_order)
						else
							TerminateCall()
						end
					end
					g.hkCombo=callCheck
					g.keyChanged=true
				else

					return true -- return true on a valid macro not repeating, to avoid triggering unwanted behaviour in long press
				end
			end

		end
		if g.debuggingKeyDetections then
			if longPress.active then Echo('key '..(KEYCODES[key] or key)..' is getting repeated') end
			if call and call.locked then Echo('KP BLOCK normal behaviour (locked Call)')
			elseif g.hkCombo then Echo('KP BLOCK normal behaviour (combo detected: '..g.hkCombo.name..')') end
		end
		if g.hkCombo then --
			local no_force =  g.hkCombo.no_force
			-- local exec=widget:DrawGenesis(GetLastUpdateSeconds())
			local exec=widget:DrawGenesis(0)
			return exec and not no_force or isCtrlGroup
		elseif call then
			if call.force_finish then
				FinishCall()
			else
				TerminateCall()
			end
		end 
		return isCtrlGroup
	end
	------------------
	------ MOUSE PRESS
	------------------
	function widget:MousePress(mx,my,button)
		local time = clock()
		-- Echo('mouse pressed in EzSelector: '..time)
		-- ignore clicks on the GUI
		local clickName = button==1 and 'LClick'
				   	   or button==3 and 'RClick'
				       or 'MClick'
		clicked['N'..button]=clickName
		currentCombo.keys['longPress']=nil
		currentCombo.keys['longClick']=nil
		currentCombo.keys['spam']=nil	
		g.clickTime=clock()
		g.onClick = true	-- informing clicking is active for Update
		-- if spGetActiveCommand()~=0  then return end
		if not spIsGUIHidden() and Screen0:IsAbove(mx,my) then
			if call then
				if call.force_finish then
					FinishCall(not call.brush_order)
				else
					TerminateCall()
				end
			end
			return
		end


		if g.debuggingKeyDetections then Echo('MousePress detect '..clickName..', SEND TO KP for update and verify blocking') end
 		-- sending to keypress as a regular key to get treated and check its return (keypress will in turn trigger an Update round)
		local hasCombo = widget:KeyPress(clickName)
		if g.debuggingKeyDetections then
			if isBlocked then Echo('MousePress find '..clickName..' should be blocked')
			else Echo('MousePress find out '..clickName..' is NOT blocked in KP')
			end
			Echo('MP send to Update '..clickName..' for release detection')
		-- after we scanned once in update, if we don't find anything to select and keep_on_fail==true 
		-- we don't block the mouse, keep_on_fail is to keep the previous selection if nothing found 
		-- also it is to let the mouse do its normal action (ie:if we want to right click move but that trigger a more complex call)
--[[		if hasCombo and g.hkCombo.keep_on_fail and sel.n==0 then			if g.debuggingKeyDetections then Echo('keep_on_fail: '..clickName..' triggered a more complex call but found nothing, we keep the previous selection and mouse is not blocked')	end
		  return false
		end--]]
		end			
		return hasCombo
	end 
end

---------------------------------------
---------------------------------------
---------------------------------------
------- END OF COMBO DETECTION --------

local GetMouseOwner = f.GetMouseOwner
function widget:SelectionChanged(newsel)
	if selectionResized then
		local off = 0
		local n = #newsel
		for i=1,n do
			-- we have to do that since the unit can be destroyed before we know it by UnitDestroyed Call-In
			i = i + off
			local id = newsel[i]
			if not spValidUnitID(id) or spGetUnitIsDead(id) then
				table.remove(newsel,i)
				off = off - 1
				if selectionResized[id] then
					selectionResized[id] = nil
				end
			end
		end
		n = n + off
		if table.size(selectionResized) ~= n then
			selectionResized = false
		else
			for i,id in ipairs(newsel) do
				if not selectionResized[id] then
					selectionResized = false
					break
				end
			end
		end
	end

	if not selectionResized and newsel[1] then
		fullSel = newsel
	end
	if lockSelection then --[[Echo('LOCKED')--]] lockSelection=false return currentSel end
end




function widget:MouseRelease(mx,my,button)
	-- MouseRelease used normally and also arbitrarily by CheckClick function to complete click detection

	-- fixing Disowning Mouse to fix when multiple buttons have been held
	-- in case of not handler=true:
	--if (widgetHandler:IsMouseOwner())then 					
	--widgetHandler:DisownMouse() end
	-- in case of handler=true:
	if widgetHandler.mouseOwner == widget then
	 	if g.debuggingKeyDetections then Echo('MR: 2 buttons were pressed, forcing disownership') end
		widgetHandler.mouseOwner=nil
	end
	-- updating click status
	clicked['N'..button]=nil
	g.clickTime=clock()
	local clickName = (button==1 and 'L' or button==2 and 'M' or button==3 and 'R')..'Click'
	-- disable temporarily Selection Modkeys widget that may select unwanted unit under cursor when letclick is released
	if button==1 and (call and call.disable_SM and g.SM_Enabled.value
					  or last.call and (last.call.on_press or last.call.failed) and last.call.disable_SM) then
		g.SM_Enabled.value=false
		g.SM_SwitchOn=true

	end
	widget:KeyRelease(clickName)  -- sending click release to get treated as a regular key release
end


function widget:UnitDestroyed(id, defID, teamID)
	if teamID~=myTeamID then return end
	if selectionResized and selectionResized[id] then
		selectionResized[id]=nil
	end
	if ctrlGroups.byUnitID[id] then
		local grps = ctrlGroups.byUnitID[id]
		for grp in pairs(grps) do
			grp.units[id] = nil
			if not next(grp.units) then
				ctrlGroups:Delete(grp)
			end
		end
	end
	if not call then
		return
	end
	if g.validUnits.byID[id] then
		g.validUnits.byID[id]=nil
		g.validUnits.n=g.validUnits.n-1
	end
	if g.acquired.byID[id] then
		g.acquired.byID[id]=nil
		g.acquired.n=g.acquired.n-1
	end

end
local function Acquire(unitTable,want,prev,validated)
	-- Echo("unitTable.n is ", unitTable.n, prev)
	local acquired = g.acquired
	if acquired.n==want then return end
	if unitTable.n==0 then return end
	local new
	local prvByID,valByID,acqByID = prev and prev.byID, validated and validated.byID, g.acquired.byID
	local n = acquired.n
	local hadNone = n == 0
	for i=1,unitTable.n do
		local id=unitTable[i]
		-- Echo(id
		--  ,Units[id] and not acqByID[id]
		-- ,(not validated or valByID[id])
		-- ,(not prev or not prvByID[id]))
		if Units[id] and not acqByID[id]
		and (not validated or valByID[id])
		and	(not prev or not prvByID[id])
		then
			new = true
			n =	n + 1
			acqByID[id] = n
			acquired[n] = id
			if n==want then break end
		end
	end
	if new then
		acquired.n = n
		if hadNone then
			if call.call_on_only_defs then
				local cnt = 0
				for defs, thiscall in pairs(call.call_on_only_defs) do
					cnt = cnt + 1
					local _,n = ProcessFiltering({n=0,byID={}},defs,nil,myUnits, 'JUMP TO CALL ON DEFS #' .. cnt .. ' ')
					if n == acquired.n then
						TerminateCall()
						g.keyChanged = true
						g.hkCombo = thiscall

						return true, widget:DrawGenesis(0)
					end
				end
			end
		end
	end
	-- Echo("acquired.n is ", acquired.n)
	if new and call.selname and (not DRAW[2] or DRAW[13] ~= g.acquired[1]) then
		-- update the name of the call if wanted
		local firstID = g.acquired[1]
		local contextName
		if call.selname and firstID then
			local type = call.byType
			if not type or type == 'defID' then
				local defID = spGetUnitDefID(firstID)
				if defID then
					contextName = UnitDefs[ defID ].humanName
				end
			else
				local unit = Units[firstID]
				if unit and unit[type] then
					contextName = unit[type]
				end
			end
		end
		contextName = call.name .. (contextName and ': ' .. contextName  or '')
		DRAW[2]=contextName
		DRAW[13] = firstID
		DRAW.declare=true
	end
	return new
end
--------------------------
---- FILTERING UNITS -----
--------------------------



do
	local spGetUnitRulesParams = Spring.GetUnitRulesParams
	local spGetGameFrame = Spring.GetGameFrame
	local spGetUnitWeaponState = Spring.GetUnitWeaponState
	local spuGetUnitFireState     = Spring.Utilities.GetUnitFireState


	local propTables,propTable = {}
	local function echotable(t)
		Echo('----- echo table ------')
		for k,v in pairs(t) do
			Echo(k,v)
			if type(v) == 'table' then
				Echo('...')
				echotable(v)
			end
		end
	end
	 -- checking conditions defined in 'defs' table of the macro
	CheckRequirements = function(reqTable,id,Or,Inv,cnt)
		if not spValidUnitID(id) or spGetUnitIsDead(id) then return false end
		if not reqTable then return true end
		if not next(reqTable) then -- empty table == pass
			return true
		end

		-- if call.name:match('1 Bomb') then
		-- 	Echo('==============================================')
		-- 	for ind,def in pairs(call.defs) do
		-- 		Echo(ind,def)
		-- 		if type(def) == 'table' then
		-- 			for k,v in pairs(def) do
		-- 				Echo('in table ' ,tostring(ind), tostring(def),k,v)
		-- 			end
		-- 		end
		-- 	end
		-- end
		if not Units[id] then return false end

		local checkType
		local debugCheck = options.debugcheckreq.value
		local cnt = cnt and cnt+1 or 0
		
		if cnt==0 then
			proptable=Units[id] -- <= the proptable by default
			propTables['d'], propTables['p'] = proptable.ud, spGetUnitRulesParams(id) -- <- setting a quick access for other proptables
		end
		local checktype
		if debugCheck and cnt==0 then
			local checkNormal, checkPreFilter, checkPrefer,checkWantIf,checkSwitch, checkMustHave , checkGroups, checkTemp
			if call.defs and call.swDefs and call.defs==reqTable then checkPreFilter = true
			elseif call.defs and call.defs==reqTable then checkNormal = true end
			if call.prefer then for i,def in ipairs(call.prefer) do if def==reqTable then checkPrefer = i break end end end
			if call.switch then for i,def in ipairs(call.switch) do if def==reqTable then checkSwitch = i break end end end
			if call.wantIf then for def,n in pairs(call.wantIf) do if def==reqTable then checkWantIf=tostring(n) break end end end
			if call.must_have==reqTable then checkMustHave = true end
			if call.groups then for i,def in ipairs(call.groups) do if def==reqTable then checkGroups = i break end end end
			if call.tempdefs ==reqTable then checkTemp = true end
			checktype = checkPreFilter 										and 'PREFILTER CHECK'
					  or checkWantIf										and 'WANT IF CHECK FOR ' .. checkWantIf .. ': '
					  or checkMustHave										and 'MUST HAVE CHECK: '
					  or checkPrefer                                        and 'PREFERENCES #'..checkPrefer..' CHECK: '
					  or checkSwitch                                        and 'SWITCH #'..checkSwitch..' CHECK: '
				  	  or checkGroups										and 'GROUP #'..checkGroups..' CHECK: '
				  	  or call.proximity and (reqTable==call.proximity.defs) and 'PROXIMITY CHECK: '
				  	  or checkTemp											and 'TEMP CHECK '
					  or checkNormal										and 'NORMAL CHECK: '
					  or 													    'UNKNOWN CHECK: '
			Echo('<'..checktype..Units[id].name:upper()..'('..id..')>')
		end
		-- local tell = checktype and checktype:match('GROUP %#2')
		-- if tell then
		-- 	echotable(reqTable)
		-- end
		Or,Inv = not not Or,not not Inv -- get them non-nil in case they have not been specified
		
		local pass

		if debugCheck and cnt>0 then Echo("TABLE#"..cnt..(Or and ' (OR) ' or '')..(Inv and ' (NOT).' or ''))  end
		-- this browse through a table of definitions, if that table contains a subtable that has no key string or only '!' and/or '?' as key string, then it is subdefs and recursion will be applied
		for reqProp,reqVal in pairs(reqTable) do
			local subOr,subInv,standAlone = false,false,false
			pass=nil
			--- DISAMBIGUATE CONDITION, VALUE TO CHECK, SUBTABLE RECURSION AND OPERATORS
			--- briefing:  key==number => value is the subtable or (a standAlone condition + possible operator)
			--- 		   key==string => operators or/and proptable's tag + condition, value is a single value to check or a subtable of values to verify(key==condition) or a subtable to recurse in (key==only operators)

			-- case: key is a simple number index: the value is actually the prop, and it's value is true
			-- Echo("reqProp,reqVal is ", reqProp,reqVal)
			if type(reqProp)=='number' then 
				standAlone = type(reqVal)=='string' 
				reqProp,reqVal = reqVal, standAlone
			end
			-- local reqValStr = ''
			-- if type(reqVal) == 'table' then
			-- 	for k,v in pairs(reqVal) do
			-- 		reqValStr = reqValStr .. tostring(v) .. ','
			-- 	end
			-- end
			-- Echo("reqProp,reqVal is ", reqProp,reqVal,reqValStr)
			-- setting operators, proptable and removing them from the reqProp, and deducing recursion
			proptable=Units[id]
			if type(reqProp)=='string' then	
				subInv,reqProp= not not reqProp:match('!'), reqProp:gsub('!','') -- symbolize NOT operator -- can be for a condition to negate (with subtable of values or not) or a subtable to recurse in
				subOr,reqProp = not not reqProp:match('?'), reqProp:gsub('?','') -- symbolize OR operator  -- can only be for subtable of value or subtable to recurse in
				if not subOr and not subInv and type(reqVal)=='table' then
					-- implicit subOR '?' if reqVal is a table since the reqProp cannot be equal to 2 different val at the same time
					subOr = true
				end
				if reqProp=='' then-- no char left means there's a subtable to recurse in, reqProp become that subtable
					reqProp=reqVal
				else -- else we check if a custom property table is required ("d:" for UnitDefs, "p:" for UnitRulesParams, UnitsIDCard beeing default)
					local typeProp = reqProp:match('(%a)%:')
					if typeProp then proptable,reqProp = propTables[typeProp],reqProp:gsub('%a%:','') end
				end
			end
			-- Echo("subInv,subOr,reqProp,reqVal is ", subInv,subOr,reqProp,reqVal)
			if reqVal == 'nil' then
				reqVal = nil
			end
			-- disambiguation finished: reqProp = condition or a subtable to recurse in, reqVal = value(s) to check or irrelevant, operators and proptable are set
			---------------------------------------------------------------
			-- CASE SUBSET OF REQUIREMENTS => RECURSION
			if type(reqProp)=='table' then
				-- subOr = subOr or type(reqProp[1])=='table' -- no need to specify the key ['?'] in a case of subtable containing subtables, this is implicit
				if debugCheck then Echo('...recursion...') end
				pass=CheckRequirements(reqProp,id,subOr,subInv,cnt) -- subtable passed?

			-- CASE: CONDITION IS STANDALONE // requirements that have not been given any value, therefore must resolve to boolean
			elseif standAlone then
				if reqProp=='isTransported' then
					local trns = spGetUnitTransporter(id)
					pass = not not trns
				elseif reqProp=='isTransporting' then 
					local trns = spGetUnitIsTransporting(id)
					pass = trns and not not trns[1]
				elseif reqProp:match('%d') then
					local req,reqHP,percent=reqProp:match('(%a+)(%d+)(%%)')
					reqHP=tonumber(reqHP)
					local HP,maxHP=spGetUnitHealth(id)
					if percent then HP=HP/maxHP*100 end
					pass=req=='above' and HP>reqHP or
						 req=='under' and HP<reqHP or
						 req=='equal' and abs(HP-reqHP)<7
				else
					pass = not not proptable[reqProp]
				end
				if subInv then pass = not pass end
				if debugCheck then
					Echo('Stand Alone '..(Or and ' (OR) ' or '')..': '..(subInv and 'subNOT ' or '')..tostring(reqProp)..' => '..(pass and ' passed' or ' failed'))
				end

			--CASE: CONDITION IS A PROPERTY WITH MATCHING VALUE(s)
			else
				--translating the property into a value to match
				local val
				if type(reqProp)=='function' then
					val=reqProp(id)
				elseif reqProp=='reload' then
						local reloadState = spGetUnitWeaponState(id, reqVal,"reloadState")
						val= reloadState and reloadState<spGetGameFrame() and reqVal
				elseif reqProp=='hasOrder' then
					local reqVals
					if type(reqVal) == 'table' then
						reqVals = {}
						for i,subReqVal in ipairs(reqVal) do
							reqVals[subReqVal] = true
							-- Echo('setting sub reqval ' .. subReqVal)
						end
					end
					local mem = g.temp['hasOrder']
					if not mem then
						mem = {}
						g.temp['hasOrder'] = mem
					end
					local queue = mem[id]
					if not queue then
						queue = spGetCommandQueue(id,-1) or EMPTY_TABLE
						mem[id] = queue
					end

					for i,order in ipairs(queue) do
						
						val = order.id
						local params = order.params
						if reqVal=='building' or reqVals and reqVals['building'] then
							queue.building = false
							if (val<0 or val == CMD.REPAIR and not params[2]) then
								local unit = params[1] and Units[params[1]]
								if unit and unit.isGtBuilt then
									val = 'building'
									queue.building = val
								end
							end
						elseif reqVal == 'moveFar' then
							queue.moveFar = false
							if val == CMD_RAW_MOVE or val == CMD_RAW_BUILD or val == CMD_MOVE then
								local destX,_,destZ = unpack(order.params)
								if destZ then
									local x,_,z = spGetUnitPosition(id)
									if ((x-destX)^2 + (z-destZ)^2)^0.5 > 900 then
										val = 'moveFar' 
										queue.moveFar = val
									end
								end
							end
						end
						-- Echo("reqVals and reqVals[val], val, reqVal is ", reqVals and reqVals[val], val, reqVal)
						if reqVals and reqVals[val] or val == reqVal then
							reqVal = val
							break
						end
					end
				elseif reqProp=='order' then
					-- local str = (Or and '?' or '')..(subInv and '!' or '') ..'order'
					local mem = g.temp['order']
					local params
					if not mem then
						mem = {}
						g.temp['order'] = mem
					end
					if mem[id] then
						val = mem[id].val
						params = mem[id].params
					else
						val, params = false, EMPTY_TABLE
						local queue=spGetCommandQueue(id,2)
						local order = queue[1]
						if order then
							params = order.params
							val = order.id
							if (val==0 or val==CMD_RAW_BUILD) and queue[2] then
								-- in case of game paused and player stopped the con then ordered something else, the second order is relevant
								-- in case of RAW_BUILD inserted by the engine to move the unit toward the goal
								val=queue[2].id
								params = queue[2].params
							end
						end
						mem[id] = {val = val, params = params}
					end
					if reqVal =='building' then
						if (val<0 or val == CMD.REPAIR and not params[2]) then
							local unit = params[1] and Units[params[1]]
							if unit and unit.isGtBuilt then
								val = 'building'
							end
						end
					elseif reqVal == 'moveFar' then
						if val == CMD_RAW_MOVE or val == CMD_RAW_BUILD or val == CMD_MOVE then
							val = false
							local destX,_,destZ = unpack(params)
							if destZ then
								local x,_,z = spGetUnitPosition(id)
								if ((x-destX)^2 + (z-destZ)^2)^0.5 > 900 then
									val = 'moveFar' 
								end
							end
						else
							val = false
						end
					end
				elseif reqProp=='fireState' then
					val = spuGetUnitFireState(id)
				elseif reqProp=='moveState' then
					val = spuGetUnitMoveState(id)
				else
					val = proptable[reqProp]
				end
				
				-- SUBCASE: ONE PROP VS MULTIPLE VALUES, value is a table eg [!prop]={v1,v2}, [?prop]={v1,v2}, ['reload']={weapnum1,weapNum2}...
				if type(reqVal)=='table' and reqProp~='hasOrder' then 
					if reqVal._opti then -- for table of names and the like, we previously transformed indexed table into paired table
						pass = not not reqVal[val]
						if subInv then pass = not pass end
						if debugCheck then Echo((subInv and 'subNOT ' or '')..'( (opti) '..tostring(reqProp)..':'..tostring(val)..' )'..' => '..(pass and 'PASSED' or 'FAILED')) end
					else
						for _,subReqVal in ipairs(reqVal) do
							if subReqVal=='nil' then
								subReqVal = nil
							end
							if reqProp=='reload' then -- in that case, we couldnt define the prop in advance, note: even for a single weapon num to check, it has to be in a subtable
								local reloadState = spGetUnitWeaponState(id, subReqVal,"reloadState")
								pass= reloadState and reloadState<Spring.GetGameFrame()
							else
								pass = val==subReqVal
							end
							if subInv then pass = not pass end
							if debugCheck then Echo((subInv and 'subNOT ' or '')..'('..tostring(reqProp)..'=='..tostring(subReqVal)..')'..(subOr and ' (subOR)' or '')..' => '..(pass and 'PASSED' or 'FAILED')..' | my value=='..tostring(val)) end
							if subOr==pass then break end -- either not passed and not OR or passed and OR, we don't need to go further
						end
					end


				-- SUBCASE: ONE PROP VS ONE VALUE
				else
					pass = val==reqVal or reqVal==true and val
					if subInv then pass = not pass end
					if debugCheck then Echo((subInv and 'subNOT ' or '')..'('..tostring(reqProp)..'=='..tostring(reqVal)..')'..(Or and ' (OR)' or '')..' => '..(pass and 'PASSED' or 'FAILED')..' | my value=='..tostring(val)) end
				end
			end
			-- applying the eventual operators if we're in a recursion (subtable of defs)
			if Or==pass then break end
		end
		if debugCheck then
			if cnt>0 then Echo("END OF TABLE#"..cnt..(Or and ' (OR) ' or '')..(Inv and ' (NOT).' or ''),'passed?',pass)
			else          Echo('>'..checktype..Units[id].name:upper()..'('..id..') '..(pass and '' or 'NOT ')..'PASSED<')
			end
		end
		return pass
	end

	FindUnits = function(defs,ret,altUnits,comment,multiCheck)
		local debugMe = options.debugcheckreq.value
		if debugMe then
			Echo('*********** START CHECKING '.. call.name .. ' ' .. (comment or ' ') .. (multiCheck and 'multiCheck' or ' ') .. '*************')
		end

		local myUnits = altUnits or myUnits
		local validated = ret or g.validUnits
		local byID=validated.byID
		-- validated.checked = validated.checked or {}
		local checked = validated.checked
		local Type,byType = call.byType
		if Type then 
			byType = validated.byType
			if not byType then validated.byType={} byType=validated.byType end
		end
		local new
		local numDefs
		local debugName = options.debugshownames.value
		---
		-- local time = spGetTimer()
		for i=1,myUnits.n do
			id=myUnits[i]

			if not byID[id] and not (checked and checked[id]) then
				if debugName then Echo("name is ", Units[id].name, '#' .. id) end
				if checked then
					checked[id] = true
				end
				if spValidUnitID(id) and not spGetUnitIsDead(id) then
						-- Echo("checking",(Units[id].name..' ('..id..')'):upper())
					local pass
					if call.anyBP or (select(5,spGetUnitHealth(id)) or 0)>0.8 then  -- almost finished
						if multiCheck then
							for i,thoseDefs in ipairs(defs) do
								if debugMe then
									Echo('multiCheck now trying defs #'..i .. '/'..#defs)
								end
								if CheckRequirements(thoseDefs,id) then
							 		pass = true
							 		multiCheck = false
							 		defs = thoseDefs
							 		numDefs = i
							 		break
							 	end
							 end
						else
							pass = CheckRequirements(defs,id)
						end
					end
					if pass then
						new=true
						validated.n=validated.n+1
						validated[validated.n]=id
						byID[id]=true
						if byType then
							local k = Units[id][Type] or 'unknown'
							local t = byType[k] 
							if not t then
								byType[k]={n=0,byID={}}
								t=byType[k]
							end
							t.n=t.n+1
							t[t.n]=id
							t.byID[id]=t.n
						end
					end
				end
			end
		end
		-- time = spDiffTimers(spGetTimer(), time)
		-- if time > 0.07 then
		-- 	Echo('CheckReq took too long ! ', time, call.name .. ' ' .. (comment or ' '))
		-- end
		return validated,new, defs, numDefs
	end
	GetPrefered = function(pool,prev)

		local currentBest = g.hasPrefered
		local prefered = g.prefered
		local preferedTypes
		local alreadyChecked = g.prefered.checked
		local default = g.prefered.default
		local usePrev = call.pref_use_prev
		local folder,pref
 		local Type = call.byType
 		local typeOrder = call.thisTypeOrder

 		local bestOrder = g.bestOrder
 		local maxOrder = g.maxOrder and g.maxOrder + 1

 		local avoid_non_pref = call.avoid_non_pref
 		local maxPref = #call.prefer+1
		local n = 0
		for i=1,pool.n do
			local id = pool[i]
			if not alreadyChecked[id] then
				
				for i,prefTable in ipairs(call.prefer) do
					-- Echo('check pref #',i,'/'..#call.prefer)
				 	if CheckRequirements(prefTable,id) then
				 		local isDefault  = usePrev and prev and (call.only_prevTypes and prev.types[ Units[id][Type] ] or prev.byID[id])
				 		local folder = isDefault and default or prefered
				 		-- Echo(id,'get req ',i,'prev?',prev.byID[id])
				 		if isDefault then folder.got = true end
						pref = folder[i]
						preferedTypes = folder.types
						if not pref then
							folder[i] = {n=0,byID={},byType = Type and {}}
							pref = folder[i]
							if debugPrevious then
								Echo('prev: create prefered'..(isDefault and ' default' or '')..' folder for value '..i .. ' by the unit ' .. (Units[id] and Units[id].name or 'noname') .. ' #' .. id )
							end
						end
						if not isDefault then
							if (not currentBest or i<currentBest) then
								-- if not avoid_non_pref or i~=maxPref then
									currentBest=i
									-- as we found non default and better prefered, we reset the bestOrder
									bestOrder = false
								-- end
								-- Echo('set a new currentBest: ' .. i)
							end
						elseif not prefered.bestDefault or i<prefered.bestDefault then
							prefered.bestDefault = i
							if not currentBest then
								-- as we found a better default and no prefered available, we reset the bestOrder
								bestOrder = false
							end
						end
						pref.n=pref.n+1
						pref.byID[id]=pref.n
						pref[pref.n]=id
						if Type then
							local thisType = Units[id][Type] or 'unknown'
							-- Echo('this type ',thisType, 'default?', isDefault,call.only_prevTypes, prev.types[thisType])
							local byType = pref.byType[thisType]
							if not byType then pref.byType[thisType] = {n=0,byID={}} ; byType = pref.byType[thisType] end

							byType.n = byType.n+1
							byType.byID[id]=byType.n
							byType[byType.n] = id
							local preferedScore = preferedTypes[thisType]
							if not preferedScore or preferedScore>i then
								preferedScore = i
								preferedTypes[thisType] = preferedScore

								if typeOrder then
									if not currentBest or not isDefault then
										-- sorting out the best type to choose if this is non-default or default if no non-default available
										local thisOrder = typeOrder[thisType]

										if thisOrder and (not bestOrder or bestOrder>thisOrder) then
											bestOrder = thisOrder
											if debugPrevious then
												Echo('set a new bestOrder: ' .. bestOrder .. ', by the type: ' .. thisType .. (Type=='defID' and  ' (' .. UnitDefs[thisType].name .. ')' or ''))
											end
										end
									end

								end
								if debugPrevious then
									Echo('prev: '..thisType..' by the unit ' .. (Units[id] and Units[id].name or 'noname') .. ' #' .. id .. ' has been set to '..i..' as prefered type'..(isDefault and ' (default)' or ''))
								end
							end
						end
						


			 			break
			 		end
				end

				alreadyChecked[id]=true
			end
		end
		if currentBest~=g.hasPrefered or bestOrder ~= g.bestOrder then 
			if debugPrevious and currentBest then
				Echo('prev: preference # '..currentBest.. ' has been met')
				-- if call.groups and call.groups.selected then
				-- 	Echo("call.groups.selected is ", call.groups.selected)
				-- 	call.groups.selected = false
				-- end
			end
			g.hasPrefered = currentBest
			if g.acquired[1] then -- if we already acquired units, we reset it
				g.acquired = {n=0,byID={},byType = Type and {}}
				if call.add_last_acquired and last.acquired then
					Acquire(last.acquired)				
				end

			end
			if Type then -- in case a type choice has been made we ask for a new ruling
				if call.good then
					if preferedTypes[call.good]~=currentBest or bestOrder ~= g.bestOrder then
						if bestOrder ~= g.bestOrder then
							-- Echo('a best Order has been found', bestOrder)
						end
						call.good,call.choice = false,false
						if debugPrevious then Echo("prev: type choice has been resetted by GetPrefered") end
					end
				end
			end
		end
		g.bestOrder = bestOrder
	end

	ProcessFiltering = function(finalValid, defs, switch, pool,comment, multiCheck)

		local n = finalValid.n
		local XAND
		if defs and defs.XAND then
			XAND, defs.XAND = defs.XAND, nil
		end
		local newdefs, newdefsNum -- for multicheck, giving the first matching defs, newdefs is not fully implemented, the last multicheck will override the others in here -- will fix if it's ever getting needed
		if defs then
			local msg = ''
			if call.switch then
				for i,swDefs in ipairs(call.switch) do
					if swDefs==defs then
						msg='SWITCH #' .. i .. ' '
						break
					end
				end
			end
			if defs['AND'] then
				-- case: different units must be found together
				if n == 0 then
					-- Echo('N0')
					-- if nothing found yet, both must match
					local allValid = {n=0,byID={}}
					local current_n = 0
					local found = true
					for i,def in ipairs(defs['AND']) do
						-- Echo('CHECKING DEF #' .. i,allValid.n)
						local thisnew
						_, _, newdefs, newdefsNum = FindUnits(def,allValid,pool,(comment or '') .. msg .. "defs['AND'] #" .. i .. ' ', multiCheck)
						if allValid.n > current_n then
							current_n = allValid.n
						else
							found = false
							break
						end
					end
					if found then
						-- Echo('final',allValid.n,finalValid==g.validUnits)
						for k,v in pairs(allValid) do
							finalValid[k]=v
						end
						-- finalValid = allValid
						new = true
					end
					-- Echo(found,"current_n is ", current_n,finalValid[1])
				else
					-- if already found, any match add up
					-- Echo('N',n)
					local isnew
					for i,def in ipairs(defs.AND) do
						_, isnew, newdefs, newdefsNum = FindUnits(def,finalValid,pool,(comment or '') .. msg .. "defs['AND'] #" .. i .. ' ', multiCheck)
						new = new or isnew
					end
				end
			else
				-- usual case with a single set of definitions or multiCheck
				_,new, newdefs, newdefsNum = FindUnits(defs,finalValid,pool,(comment or '') .. msg .. 'DEFS ', multiCheck)
			end
		end


		---------------------
		n = finalValid.n
		if XAND then
			if n>0 then
				local isnew
				_,isnew, newdefs = FindUnits(XAND,finalValid,pool,(comment or '') ..  'XAND ')
				new = new or isnew
			end
			defs.XAND = XAND
			n = finalValid.n
		end
		if defs and defs[1]=='nothing' then -- unused
			call.success = true
			FinishCall(false)
			finished = true
			return _,n,new,finished, newdefs, newdefsNum
		end
		if n>0 and switch and call.switch_on_identical then
			local identical = n==#currentSel
			if identical then
				local byID = finalValid.byID
				for i,id in ipairs(currentSel) do
					if not byID[id] then
						identical = false
						break
					end
				end
				if identical then
					n = 0
				end
			end
		end
		if n==0 and switch then
			-- if nothing found and call.switch, we switch definitions, until we find something or we're back to start
			local swDefs=true
			while n==0 do
				local newcurrent = switch.current_defs + 1
				if not switch[newcurrent] then
					newcurrent = 1
				end
				switch.current_defs = newcurrent
				call.swDefs=switch[newcurrent]
				swDefs = call.swDefs
				sh.sw = newcurrent
				if swDefs==defs then
					-- we got back to where we started without finding anything
					break
				end
				local XAND
				if swDefs.XAND then
					XAND, swDefs.XAND = swDefs.XAND, nil
				end

				if swDefs['AND'] then
					--case: multiple different units must be found together
					local allValid = {n=0,byID={}}
					local current_n = 0
					local found = true
					for i,def in ipairs(swDefs['AND']) do
						local thisnew
						-- Echo('***  ' .. i..'/'..#swDefs.AND .. '  ***')
						_,_,newdefs = FindUnits(def,allValid,pool,(comment or '') .. "swDefs['AND'] #" .. i .. ' ' )
						-- Echo('***----***',allValid.n)
						if allValid.n > current_n then
							current_n = allValid.n
						else
							found = false
							break
						end
					end
					if found then
						finalValid = allValid
						new = true
					end
				else
					_,new,newdefs = FindUnits(swDefs,finalValid,pool,(comment or '') .. 'SWITCH #' .. switch.current_defs .. ' ')
				end

				n = finalValid.n
				if XAND then
					if n>0 then
						local isnew
						_,isnew,newdefs = FindUnits(XAND,finalValid,pool,(comment or '') .. 'XAND ')
						new = new or isnew
					end
					swDefs.XAND = XAND
					n = finalValid.n
				end
				if swDefs[1]=='nothing' then
					call.success = true
					FinishCall(false)
					finished = true
					break
				end
				if n>0 and switch and call.switch_on_identical then
					local identical = n==#currentSel
					if identical then
						local byID = finalValid.byID
						for i,id in ipairs(currentSel) do
							if not byID[id] then
								identical = false
								break
							end
						end

						if identical then
							n = 0
						end
					end
				end

			end
			defs=swDefs
		end
		n = finalValid.n
		-- Echo('RETURN',_,n,new,finished)
		-- for k,v in pairs(finalValid) do
		-- 	Echo(k,v)
		-- end
		return _,n,new,finished, newdefs, newdefsNum
	end


	PickType = function(Type,givenPool,prev) -- switching between different defID or class or family

		local choice = call.choice

		local pool = givenPool.byType[choice]
		if not pool then choice=false end
		local good = choice and call.good
		if good then return pool, false end

		local hasPrefered = g.hasPrefered
		local bestDefault = g.prefered and g.prefered.bestDefault
		local preferedTypes = g.hasPrefered and g.prefered.types

		local typeOrder = call.thisTypeOrder
		local refuse_non_pref = call.avoid_non_pref and not hasPrefered and bestDefault
		local bestOrder, maxOrder
		if typeOrder then
			bestOrder = g.bestOrder
			maxOrder = g.maxOrder
		end
		-- Echo("hasPrefered is ", hasPrefered, bestDefault)
		local pref -- = preferedTypes and preferedTypes[good]
		if next(prev.types) then
			-- case: there are previous type registered
			-- case: alse avoiding a previous type
			for k in pairs(givenPool.byType) do
				
				-- pick most prefered type not in prev, or just the next type if no preference
				if not prev.types[k] then

					if preferedTypes then -- pick the most prefered type
						local newpref = preferedTypes[k]
						if not pref or newpref and  (bestOrder or newpref<pref)  then
							good = k
							pref = newpref
							if pref==hasPrefered then -- found a best prefered, no need to go any further
								local bestFound
								local thisOrder
								if not bestOrder then
									bestFound = true
								else
									thisOrder = typeOrder[k]
									if thisOrder and thisOrder == bestOrder then
										bestFound = true
									end
								end
								if debugPrevious then
									Echo('prev: avoiding previous types and found a best prefered #' .. hasPrefered .. (bestFound and ' (no better pick) ' or '')  ..  ': ' .. k .. (thisOrder and ', order : '.. thisOrder or '') .. (bestOrder and  ', best order is ' .. bestOrder or ' there is no best order') )
								end
								if bestFound then
									break
								end
							end
						end
					elseif not refuse_non_pref then
						if not good then
							good = k
						end
						local bestFound
						local thisOrder
						thisOrder = typeOrder and typeOrder[k]
						if thisOrder then
							if not bestOrder or bestOrder>thisOrder then
								bestOrder = thisOrder
								good = k
							end
						end
						if thisOrder==1 then
							bestFound = true
						end
						if debugPrevious then
							Echo('prev: avoiding previous types and found type: ' .. k .. (bestFound and ' (no better pick) ' or '')  ..  (thisOrder and ', order : '.. thisOrder or '') .. (bestOrder and  ', best order is ' .. bestOrder or ' there is no best order') )
						end
						if bestFound then
							break
						end

					end
				end
			end
			-- if we didnt find a new type to pick, but got non default (non prev unit) of an already picked type that have some preference, we pick that type
			if not good and preferedTypes then
				for k in pairs(givenPool.byType) do
				-- Echo('type '.. k,preferedTypes[k])
				-- pick the most prefered type
					local newpref = preferedTypes[k]
					if not pref or newpref and (bestOrder or newpref<pref) then
						good = k
						pref = newpref
						local bestFound
						if pref==hasPrefered then -- found a best prefered, no need to go any further
							local thisOrder
							if not bestOrder then
								bestFound = true
							else
								thisOrder = typeOrder[k]
								if thisOrder and thisOrder == bestOrder then
									bestFound = true
								end
							end
							if debugPrevious then
								Echo('prev: no new type to pick, picking a best prefered type #' .. hasPrefered .. (bestFound and ' (no better pick) ' or '')  ..  ': ' .. k .. (thisOrder and ', order : '.. thisOrder or '') .. (bestOrder and  ', best order is ' .. bestOrder or '') )
							end
						end
					end
				end
			end
			-- choice = good or Units[ givenPool[1] ][Type]
			if good then
				choice = good
			else
				-- all possible types are in prev, picking one of the firsts type registered in prev, if there are units of this type in the pool
				choice = false
				for i, type in ipairs(prev.typeIndex) do
					if givenPool.byType[type] then
						choice = type
						if debugPrevious then
							Echo("prev: picked the first type registered and valid : " .. choice )
						end
						break
					end
				end
				if not choice then
					choice = Units[ givenPool[1] ][Type] or 'unknown'
					if debugPrevious then
						Echo("prev: picked the first type registered and valid : " .. choice )
					end
				end

			end
			-- choice = good or Units[ prev[1] ][Type]
			if debugPrevious and not good then
				Echo("prev: picked the first unit's type : " .. choice .. " in the pool ")
			end
			prev.forgetTypes = not good
			-- we don't erase types right away as prev can still be relevant if we find new ones during the call (eg: by cylinder method, moving the mouse around...)
			-- instead we indicate that we will want to forget all types for the next call
		else
			-- case no 
			if hasPrefered then
				if not bestOrder then
					choice = Units[ g.prefered[hasPrefered][1] ][Type] or 'unknown'
				else
					for typeName,o in pairs(typeOrder) do
						if o==bestOrder then
							choice = typeName
							if debugPrevious then
								Echo('prev: picking type of the best order : '.. choice .. ', order: ' .. o)
							end
							break
						end
					end
				end
			else
				choice = Units[ givenPool[1] ][Type] or 'unknown'
			end
			good = choice
		end

		if call.choice~=choice then -- resetting g.acquired now we picked another type
			pool=givenPool.byType[choice]
			if g.acquired[1] then
				g.acquired,g.selCost = {n=0,byID={}},0
				if call.add_last_acquired and last.acquired then
					Acquire(last.acquired)
				end

			end 
		end
		

		call.choice = choice
		prev.type_choice=choice
		call.good = good
		if debugPrevious then
			Echo('prev: '..choice..' has been chosen', good and ' good ' or 'default ' ..'choice')
		end
		g.bestOrder = bestOrder
		return pool,not good -- not good is when all types are in prev
	end
	GetWantN = function(pool,n,method)
		local want=call.want
		local percent = call.percent
		if call.wantIf then
			local newWant, success
			for req,value in pairs(call.wantIf) do
				success = true
				newWant = value
				for id in pairs(pool.byID) do
					if spValidUnitID(id) and not spGetUnitIsDead(id) then
						if not CheckRequirements(req,id) then
							success=false
							break
						end
					end
				end
			end
			if success then
				if not newWant then -- newWant can be false to cancel the default want
					want, percent = false, false
				else
					want= newWant and tostring(newWant)
					percent, want = want:match('%%') and true, tonumber(want:match('-?%d+'))
				end
			end
		end
		-- if g.Type and not want then want=n end
		local valByID = g.validUnits.byID
		-- local news={}
		if call.add_last_acquired and last.acquired then
			for id in pairs(last.acquired) do
				if not valByID[id] --[[and not news[id]--]] then
					n = n + 1
					-- news[id]=true
				end
			end
		end

		if want and not percent and want<0 and method=='on_selection' then
			want = pool.n+want
		end
		if percent and n>0 then
			want = ceil(n*call.want/100)
			if want==n and n>1 then want=want-1 end -- want one less unit if the rounding didnt make any change
		end


		---
		--Acquire( pool of units to pick from, want number of unit, previous selected unit to ignore, valid units for confirmation)
		-- if not want and not g.Type then call.prevIgnore=true end

		return want or n
	end
end
---------------------------------------------------------------------
-- Drawing variable to FIX
local dtTime=0
local tooHigh
local loss={Countdown=CheckTime('start'), alCur=0, enCur=0,ally=0,enemy=0}


local upTime=0
local num=100.7

--local spGetPressedKeys = Spring.GetPressedKeys
-------------
-- APPLY CALL
-------------
do
	g.FormatTime = function(n)
	    local h = math.floor(n/3600)
	    h = h>0 and h
	    local m = math.floor( (n%3600) / 60 )
	    m = (h or m>0) and m
	    local s = ('%.3f'):format(n%60)
	    return (h and h .. ':' or '') .. (m and m .. ':' or '') .. s
	end
	g.spGetGameSeconds = Spring.GetGameSeconds
	local spGetLastUpdateSeconds = Spring.GetLastUpdateSeconds

	local spGetSelectedUnitsSorted = Spring.GetSelectedUnitsSorted
	local preGame=Spring.GetGameSeconds()<0.1
	local function SetDrawing(call)
		local color = call.color
		local draw_pos = call.draw_pos
		local name = call.name
		if call.option_name then name=name..(options[call.option_name].value and ' ON' or ' OFF') end -- ('not' because the option hasnt been changed yet)
		local size=call.size
		local contextName = nil
		local firstID = g.acquired[1]

		DRAW = {declare=true
			   ,drawing=true
			   ,finishing=false
			   ,circle=call.method=='cylinder' 
			   ,name
			   ,contextName
			   ,color[1],color[2],color[3],color[4]
			   ,Fade(color[4],call.fading,5,1,true)
			   ,Fade(color[4],call.fading,5,1,true)
			   ,draw_pos[1]-name:len()*size/5,draw_pos[2]
			   ,size
			   ,call.on_press
			   ,firstID} -- the fader has to be modified in this case because call will terminate immediately without Fading In time
	end
	local function CheckLongPress()
		if longPress.key and not longPress.active then
			if WG.panning then
				longPress.key = false
				return
			end
			if longPress.mouseStill then
				local newmx,newmy = spGetMouseState()
				local threshold = call and call.mouseStillThreshold or MOUSE_STILL_THRESHOLD
				longPress.mouseStill = abs(newmx-longPress.mx)<threshold and abs(newmy-longPress.my)<threshold
				if not longPress.mouseStill then
					currentCombo.keys['mouseStill']=nil
				end
			end
			if clock()-g.lastPress>currentLongPressTime+g.lagFactor/3 then
				longPress.active=true
				-- Echo('activate longPress for',longPress.key, 'send a KeyPress event')
				widget:KeyPress(longPress.key)
				return true
			end
		end
	end
	-- function widget:GameFrame(gf)
	-- 	widgetHandler:UpdateWidgetCallIn("Update", self)
	-- 	widgetHandler:UpdateWidgetCallIn("KeyPress", self)
	-- 	widgetHandler:UpdateWidgetCallIn("MousePress", self)
	-- 	widget.AfterKeyRelease = widget._AfterKeyRelease
	-- 	widget._AfterKeyRelease=nil
	-- 	widgetHandler:RemoveWidgetCallIn("GameFrame", self)
	-- end
	function widget:DrawGenesis(delta) -- special arguments received from MousePress to start mouse release detection
		delta = delta or spGetLastUpdateSeconds()
		-- local t = {}
		-- for i = 1, 1000000 do
		-- 	t[i] = i
		-- end
		-- for i = 1, 1000000 do
		-- 	t[i] = nil
		-- end

		if WG.panning then 
			if call then
				if call.force_finish then
					FinishCall(not call.brush_order)
				else
					TerminateCall()
				end
				-- return true
			end
			-- currentCombo={keys={}}
			-- longPress.key = nil
			return
		end -- Pan View widget take over
		if call then 
			if call.skipUpdate then
				if delta>0 then
				 	call.skipUpdate=false
				 	return
				end
			end
		else
			if g.switchBackSelFiltering and not g.SelFiltering.value then
				g.SelFiltering.value = true
				g.SelFiltering:OnChange()
				g.switchBackSelFiltering = false
			end
			if g.SM_SwitchOn then
				-- put back selection modkey
				if g.SM_Enabled.value == false then
					g.SM_Enabled.value=true
				end
				g.SM_SwitchOn=false
			end

		end


	--[[if spGetSelectedUnits()[1] then
		local unitID = spGetSelectedUnits()[1]
	--Echo(Spring.GetUnitRulesParam(unit, "primary_weapon_override"))
		--Page(spGetUnitRulesParams(unitID))
	--Echo(Spring.GetUnitRulesParam(unitID, "primary_weapon_override"))
	end--]]
		-- Echo("call and call.name is ", call and call.name)
	    -- if preGame then
	    --    	preGame=Spring.GetGameSeconds()<0.1
	    --    	if preGame then return end
	    -- end
		---------------
		---------------
	--[[	-- detect Enter Key in case of Macro edition (overriden by chat)
		if Chili.Screen0:GetChildByName("EzSelectorWindow") then
			enterPressed = spGetPressedKeys()[13]
			Echo("enterPressed is ", enterPressed)
		end--]]
		---------------

		------------ adapt alpha layer of move orders to improve visibility when lot of units in play order
		------------ TODO: need to move that stuff away from this widget and complete it
		upTime=delta+upTime
		if upTime>10 then
			g.lagFactor = delta
			 -- this is bugged, if you chain a move order with a LEVEL order, that will break the UI
			-- local num=1/(#spGetAllUnits()/75)
			-- num=num<0.1 and 0.1 or num>0.7 and 0.7 or num
			-- TABLE_CUST_COMM_DRAW_DATA[4]=num
			-- Spring.SetCustomCommandDrawData(CMD_RAW_MOVE, num>0.5 and "RawMove" or "", TABLE_CUST_COMM_DRAW_DATA,false) -- remove the icon if alpha is <=0.5	
			-- upTime=0
		end
		---------------

		--------------- display call stuff on screen instead of from the mouse if too far from the ground
		--tooHigh=GetCameraHeight(spGetCameraState())>2000
		---------------

		--------------- registering loss value , NOT WORKING WELL, NEED A FIX AND PUT IT IN ANOTHER WIDGET
		dtTime=dtTime+delta
		-- if dtTime>3 then dtTime=0 loss.alCur, loss.enCur=0,0 end
		-- local alChange,enChange = WG.allyCost-loss.ally, WG.enemyCost-loss.enemy
		-- if alChange>0 then
		-- 	if alChange>(loss.alCur/10) then dtTime=0 end -- prolonging the countdown if some strong damage has been done
		-- 	loss.alCur=loss.alCur+alChange
		-- end
		-- if enChange>0  then
		-- 	if enChange>(loss.enCur/10) then dtTime=0 end
		-- 	loss.enCur=loss.enCur+enChange
		-- end
		-- loss.ally,loss.enemy= WG.allyCost, WG.enemyCost
		-- sh.Aloss,sh.Eloss,sh.CurAl,sh.CurEl=KFormat(loss.ally,2000),KFormat(loss.enemy,2000),KFormat(loss.alCur,2000),KFormat(loss.enCur,2000)
		-----------------


		-----------tweakMode fixing--KeyRelease won't register the release of the keys that provoked the tweak mode
	 	-- in case of not handler=true :
		--g.inTweakMode= g.inTweakMode or widgetHandler:InTweakMode()
		--if g.inTweakMode and not widgetHandler:InTweakMode() then g.inTweakMode=false currentCombo.keys={} end
		-- in case of handler=true :
		g.inTweakMode= g.inTweakMode or widgetHandler.tweakMode
		if g.inTweakMode and not widgetHandler.tweakMode then g.inTweakMode=false currentCombo={keys={}, raw = {}} end
		-----------------------------
		-- Same for when user is adding label by double click, the mapdrawing hotkey release will not be registered
		if next(currentCombo.raw) and Spring.IsUserWriting() then
			longPress.key = false
			longPress.active = false
			currentCombo={keys={}, raw = {}}
		end
		-- Completing ClickHandling, MousePress is not enough
		-- CheckClick()
		-- customized longPress time handling
		CheckLongPress()
		-----------------------------

		local delay = call and (call.on_delay or call.ifSecondary and call.secondary and call.ifSecondary.on_delay)
		if delay then
			if clock()-call.clock<delay then
				return
			end
		end


		--
		--------------------------------------
		--------------------------------------
		-------------- CALL OF COMBO
		-------------- finally the main stuff we're here for
		--------------------------------------
		--------------------------------------

		-------------------
		---------- NEW CALL
		-------------------
		if g.keyChanged  then -- g.keyChanged is the trigger of a new call (validated combo)
			if (not call or call.locked) and g.hkCombo then-- lockedCall is to ignore less complex combination triggered by release, also used to stop updating the current call
				if call then
					Echo('there are 2 calls together',call.name, g.hkCombo.name)
				end
				call=g.hkCombo
				WG.EzSelecting = true
			end 
			if g.debuggingKeyDetections then
				if (not call or call.locked) and HKCombos:Find(currentCombo.keys) then Echo('Update: call \''..HKCombos:Find(currentCombo.keys).name..'\' is locked. ') end
				if g.hotkeyAlreadyBound and HKCombos:Find(currentCombo.keys) then Echo('Update: call \''..HKCombos:Find(currentCombo.keys).name..'\' is cancelled, Hotkey is already bound to '..g.hotkeyAlreadyBound) end
			end
			g.keyChanged=false
			-- g.hotkeyAlreadyBound=false
			if call then




				local mx,my = spGetMouseState()
				x, y, z = UniTraceScreenRay(mx,my)
				call.mouseStart = {x,y,z}
				call.isChained = false
				last.callcount = last.callcount + 1
				if last.call then
					local main = last.call
					if main.secondary then
						main = main.secondary
					end
					if main == call  then
						main.repeated = main.repeated + 1
					else
						main.repeated = 0
					end
				end
				-- Echo("last.callcount is ", last.callcount)
				-- Echo(last.callcount,call.name,'last call:',last.call and last.call.name,last.acquired and #last.acquired or 0)
				-- if last.acquired then
				-- 	for i,id in ipairs(last.acquired) do
				-- 		Echo('in last acquired',id)
				-- 	end
				-- end
				if g.SelFiltering.value then
					g.switchBackSelFiltering = true
					g.SelFiltering.value = false
					g.SelFiltering:OnChange()
				end
				call.skipUpdate=true -- we cancel the next Update round, this one has been manually forced
				if call.OnCallFunc then
					call.OnCallFunc()
				end


				if g.debuggingKeyDetections then
					Echo('Update: call \' '..call.name..' \' approved.')
				end
				--getting fresh	
				call.failed = false
				if call.groups then 
					call.groups.selected = false
					call.groups.selectedNum = 0
				end
				local time = clock()

				if time - last.time < 0.5 then
					local maxcount = 15
					last.chainCount = last.chainCount + 1
					table.insert(last.chained, {call = call, name=call.name, duration=0, finished='unknown', gameTime = g.FormatTime(g.spGetGameSeconds())})
					call.isChained = true
					if last.chainCount > maxcount then
						Echo(widget:GetInfo().name .. ': Error, ' .. last.chainCount .. ' calls in the last half second')
						local str = ''
						for i=1, maxcount do
							str = str .. '\n ' .. last.chained[i].name
						end
						
						-- error(str)
					end
				else
					last.chainCount = 1
					last.time = time
					for k,v in pairs(last.chained) do last.chained[k] = nil end
					call.isChained = true
					last.chained[1] = {call = call, name=call.name, duration=0, finished='unknown', gameTime = g.FormatTime(g.spGetGameSeconds())}
				end
				call.clock = time

				call.pool = {}
				sh.SelCost=0
				sh.Sel_n=0
				sh.sw = false

				if call.option_name then 
					local opt = options[call.option_name]
					opt.value = not opt.value
					if opt.OnChange then
						opt:OnChange()
					end
					return true
				end

				-- f.Page(Spring,'trans')
				if call.same_transported_state then
					-- set definitions to pick only transported or only non transported
					local id = currentSel[1]

					local transported_state
					local newprop = 'isTransported'
					transported_state = id and (spGetUnitTransporter(id)--[[ or spGetUnitIsTransporting(id)--]])
					if not transported_state then
						local trns = id and spGetUnitIsTransporting(id)
						if trns and trns[1] then
							transported_state = true
						end
					end
					if not transported_state then
						newprop = '!' .. newprop
					end

					-- Echo(23951,"Spring.GetUnitTransporter(id), spGetUnitIsTransporting(id) is ", Spring.GetUnitTransporter(23951), spGetUnitIsTransporting(23951))
					local alldefs = {}
					if call.switch then
						for i,t in ipairs(call.switch) do
							table.insert(alldefs,t)
						end
					end
					if call.groups then
						for i,t in ipairs(call.groups) do
							table.insert(alldefs,t)
						end
					end
					if call.defs then
						table.insert(alldefs,call.defs)
					end
					for i,def in ipairs(alldefs) do
						for i,prop in ipairs(def) do
							if type(prop)=='string' and prop:match('isTransported') then
								table.remove(def,i)
								break
							end
						end
						table.insert(def,newprop)
					end
				end
				if call.same_transporting_state then
					-- set definitions to pick only transported or only non transported
					local id = currentSel[1]
					local newprop = 'isTransporting'
					local transporting = id and spGetUnitIsTransporting(id)
					transporting = transporting and transporting[1]
					if not transporting then
						newprop = '!' .. newprop
					end

					local alldefs = {}
					if call.switch then
						for i,t in ipairs(call.switch) do
							table.insert(alldefs,t)
						end
					end
					if call.groups then
						for i,t in ipairs(call.groups) do
							table.insert(alldefs,t)
						end
					end

					if call.defs then
						table.insert(alldefs,call.defs)
					end
					for i,def in ipairs(alldefs) do
						for i,prop in ipairs(def) do
							if type(prop)=='string' and prop:match('isTransporting') then
								table.remove(def,i)
								break
							end
						end
						table.insert(def,newprop)
					end
				end

				-- finish call if we don't have already the desired unit definitions in current selection
				if call.must_have then
					local sel = {n=0,byID={}}
					for i,id in ipairs(currentSel) do
						local isTransporting = spGetUnitIsTransporting(id)
						if isTransporting then
							for _,id in ipairs(isTransporting) do
								sel.n = sel.n+1
								sel[sel.n] = id
								sel.byID[id] = sel.n
							end
						end							
						sel.n = sel.n+1
						sel[sel.n] = id
						sel.byID[id] = sel.n
					end
					local _,n = ProcessFiltering({n=0,byID={}}, call.must_have,false, sel, 'MUST HAVE ')
					if n==0 then
						FinishCall()
						return true
					end
				end
				--
				if not call.hide then
					SetDrawing(call)
				end

				-- browsing selections -- really not useful and not used

				local off_sel = call.method=='last' and -1 or call.method=='next' and 1
				if off_sel then
					if g.Selections[1] and g.Selections[g.Selections.n+off_sel] then
						g.Selections.n=g.Selections.n+off_sel
						spSelectUnitArray(g.Selections[g.Selections.n],call.shift)
						--widget:CommandsChanged('force')
					end 
					FinishCall()
					return true
				end

				g.validUnits, g.acquired, g.selCost = {n=0,byID={}}, {n=0,byID={}}, 0
				g.preFilter = false
				g.add = call.add and {n=0,byID={}}
				g.using_add = false

				g.default = call.default and {n=0,byID={},checked={}}
				g.tempdefs = false
				g.using_default = false
				g.temp = {}
				if call.method == 'set_command' then
					FinishCall(false)
					return true
				end

				if call.add_last_acquired and last.acquired then
					Acquire(last.acquired)
				end


				if call.groups then
					call.groups.selected = false
					call.groups.selectedNum = 0
					if call.defs then
						g.preFilter = {n=0, byID = {}, checked={}}
					end
				end

				if call.byType then g.validUnits.byType={} end
				--
				-- Echo(" is ", (1 - (1 - (GetCameraHeight(spGetCameraState()) / 2000) ) /zoom_scaling))
				local ratio = (Cam and Cam.dist or GetCameraHeight(spGetCameraState())) / BASE_CAMERA_HEIGHT
				-- ratio = max(ratio,1)
				-- local ratio = (GetCameraHeight(spGetCameraState()) * 1.5 / 1000)
				if call.share_radius then
					call.radius = HKCombos.byName[call.share_radius].radius
				end
				-- Echo(call.name,call.share_radius)
				-- TO IMPROVE
				g.radius=(call.radius or 650) * (call.fixed_radius and 1 or (0.8 + (ratio-1)/zoom_scaling)) -- * (1 - (1 - (GetCameraHeight(spGetCameraState()) / 2000) ) /zoom_scaling)
				--

 				-- Wanting Same Units, modify defs to ask for same unit type as current selection, include plate as same as regular factories
				if call.same_units then
					if not  currentSel[1] then
						FinishCall()
						return true
					end
					call.defs['?name']={}
					local existing_names={}
					local hasTransport
					for defid in pairs(WG.selectionDefID or spGetSelectedUnitsSorted()) do
						local name = UnitDefs[defid].name
						if not existing_names[name] then  table.insert(call.defs['?name'],name) existing_names[name]=true end
						local other_fac = name:match('plate') and name:gsub('plate','factory') or name:match('factory') and name:gsub('factory','plate')
						if other_fac and not existing_names[other_fac] then
							table.insert(call.defs['?name'],other_fac)
							existing_names[other_fac]=true
						end
						if name=='gunshiptrans' or name=='gunshipheavytrans' then
							hasTransport = true
						end
					end
					if hasTransport then
						for i,id in ipairs(currentSel) do
							local isTransporting = spGetUnitIsTransporting(id)
							if isTransporting then
								for i,id in ipairs(isTransporting) do 
									local defID = spGetUnitDefID(id)
									local name = UnitDefs[defID].name
									if not existing_names[name] then
										table.insert(call.defs['?name'],name) existing_names[name]=true
									end
								end
							end		
						end
					end
					call.defs = OptimizeDefs(call.defs, call)
				end

				local switch = call.switch
				if switch then
					local newcurrent = switch.current_defs + 1
					if not switch[newcurrent] or call.clock - switch.time > switch.reset_time then
						newcurrent = 1
							
					end
					switch.current_defs = newcurrent

					call.swDefs=switch[newcurrent]
					sh.sw = newcurrent
					switch.time = call.clock
					if call.defs then
						g.preFilter = {n=0,byID={},checked={}}
					end
				end
				--
				prev = call.previous
				if prev then
					-- reset previous after given time
					if clock()>prev.time+call.previous_time or call.reset_previous_on_reset_switch and call.switch.current_defs==1 then
						if debugPrevious then
							Echo('--')
							if call.reset_previous_on_reset_switch and call.switch.current_defs==1 then
								sh.sw = 1
								Echo('prev: prev has been resetted by reset switch')
							else
								Echo('prev: time has passed, resetting')
							end
						end
						for i=1,prev.n do prev[i]=nil end
						prev.n=0
						prev.byID={} 
						if call.byType then
							prev.byType={}
							prev.types={}
							prev.typeIndex = {}
							prev.typeMax = 0
						end
					end
					if call.current_to_prev then
						MergeSelToPrev(prev,currentSel)
					end
					prev.time=clock()
					-- merge tables  of current and future sel in case of shift, required to avoid selecting the same instead of new one when limited number is wanted
					if call.shift then MergeSelToPrev(prev,currentSel) end
					if debugPrevious then
						local numInPrev = 0
						local detailPrev = ''
						local strTypes = ''
						if prev[1] then
							detailPrev = ', first is ' .. prev[1] 
							if call.byType then
								detailPrev = detailPrev .. (' of type ' .. (Units[ prev[1] ][ call.byType ] or 'unknown'))
							end
						end
						if call.byType then
							local numTypes = table.size(prev.types)
							strTypes = '\n\255\155\155\155Call is of type ' .. call.byType .. ', there are ' .. numTypes .. ' type' .. (numTypes>1 and 's' or '') ..  ' in Prev'

						end
						Echo('prev: <<< CALL ' .. call.name .. ' STARTED, there are ' .. numInPrev .. ' unit(s) in prev ' .. detailPrev .. strTypes ..' >>>')
					end
				end

				-- CYCLE: if the macro is a meta macro -- cycling through macros, changing the call
				local cycle = call.cycle
				if cycle then
					local maxtime=call.time -- time before reset
					if maxtime then
						if call.timecheck(maxtime) then
							cycle.selected=1
						else
							cycle.selected= (cycle[cycle.selected+1] and cycle.selected+1) or 1
						end
						call.timecheck('reset')
					else
						cycle.selected= (cycle[cycle.selected+1] and cycle.selected+1) or 1
					end
					call=HKCombos[ownedCombos[call.cycle[cycle.selected]]]
				end
				if (call.on_delay or call.ifSecondary and call.secondary and call.ifSecondary.on_delay) then return end
			end
		end
		-----------------------

		-----------------------
		--------- CALL UPDATING
		-----------------------
				--x,y,z = UniTraceScreenRay(spGetMouseState())

		--count = call and count+1 or 0
		if call  then
			if call.option_name then return end -- no need to do anything, this is just an option switch

			local method,defs = call.method,call.defs
			----------------- Drawing update 
			-- continue declaring world mouse pos until the fading (if any) is over
			if method=='cylinder' or call.from_cursor then

				if call.pos_from_selected and last.sel[1] and spValidUnitID(last.sel[1]) then
					x,y,z = spGetUnitPosition(last.sel[1])
				else
					local mx,my = spGetMouseState()
					x,y,z = UniTraceScreenRay(mx,my)
				end
			end
			----------------
			-----------------------------
			---------- CORE CALL
			-----------------------------
			---------- Set the base Units pool we have to scan
			local noStructure = not call.hasStructure
			if 	   method=='all' then				myUnits=spGetTeamUnits(myTeamID)
			elseif method=='onscreen' then 			myUnits=spGetVisibleUnits(myTeamID)
			elseif method=='on_selection' then		myUnits=spGetSelectedUnits()
			elseif method=='cylinder' then			myUnits=spGetUnitsInCylinder(x,z,g.radius,myTeamID) 
			elseif method=='on_acquired' then		myUnits=last.acquired or {}
			elseif method=='around_selected' or method=='around_last_acquired' then
				local radius = call.around_radius
				myUnits = {}
				local n = 0
				local subjects = method=='around_selected' and currentSel or last.acquired
				for _,id in ipairs(subjects) do
					local px,py,pz = spGetUnitPosition(id)
					if px then
						local units = spGetUnitsInCylinder(px,pz,radius,myTeamID) 
						for i,id in ipairs(units) do
							if not noStructure or not (Units[id] and Units[id].isStructure) then
								n = n + 1 
								myUnits[n] = id
							end
						end
					end
				end
				if n == 0 then
					FinishCall()
					return true
				end
			end
			myUnits.n=#myUnits
			if noStructure then
				local off = 0
				for i=1,myUnits.n do
					i = i+off
					local id = myUnits[i]
					if not Units[id] or	 Units[id].isStructure then
						table.remove(myUnits,i)
						off = off-1
					end
				end
				myUnits.n = myUnits.n + off
			end
			if call.ignore_from_sel then -- remove from myUnits what is in current selection
				if currentSel[1] and myUnits[1] then
					local selbyID = currentSel.byID -- it can happen it has already been IDed in Commands Changed
					if not selbyID then currentSel.byID={} selbyID=currentSel.byID end
					for i,id in ipairs(currentSel) do selbyID[id]=true end
					local off=0
					for i=1,myUnits.n do if selbyID[myUnits[i+off]] then table.remove(myUnits,i+off) off=off-1 end end
					myUnits.n=myUnits.n+off
				end
			end
			if call.from_cursor then -- sort units by distance from cursor
				table.sort(myUnits,SortClosest(x,z))
			end
			for i,id in ipairs(myUnits) do
				call.pool[id]=true
			end
			if call.add_last_call_pool and last.call then
				if not call.add_last_call_pool_if or call.add_last_call_pool_if == last.call.name then
					local n = myUnits.n
					local byID = {}
					for i,id in ipairs(myUnits) do
						byID[id] = true
					end
					for id in pairs(last.call.pool) do
						if not byID[id] then
							n = n + 1
							myUnits[n] = id
						end
					end
					myUnits.n = n
				end

			end

			-- if myUnits.n>0 and call.call_on_only_defs then
			-- 	local cnt = 0
			-- 	for defs, thiscall in pairs(call.call_on_only_defs) do
			-- 		cnt = cnt + 1
			-- 		local _,n = ProcessFiltering({n=0,byID={}},defs,nil,myUnits, 'JUMP TO CALL ON DEFS #' .. cnt .. ' ')
			-- 		if n == myUnits.n then
			-- 			TerminateCall()
			-- 			g.keyChanged = true
			-- 			g.hkCombo = thiscall

			-- 			return true, widget:DrawGenesis(0)
			-- 		end
			-- 	end
			-- end



			------------------------------------------------------------
			---------- FINDING UNITS with Restricted Selection handling
			------------------------------------------------------------
			prev = call.previous
			g.Type = call.byType
			if call.byType then
				if call.typeOrder then
					call.thisTypeOrder = call.typeOrder
					g.maxOrder = call.maxOrder
				elseif call.from_cursor then
					local common = {}
					local Type = call.byType
					local thisTypeOrder, n = {}, 0
					local off = 0
					for i=1,myUnits.n do
						local id = myUnits[i+off]
						if not (id  and Units[id]) then
							table.remove(myUnits,i+off)
							off = off -1

						else
							local type = Units[id][Type] or 'unknown'
							if not thisTypeOrder[type] then
								n = n + 1
								thisTypeOrder[type] = n
							end
						end
					end
					call.thisTypeOrder = thisTypeOrder
					g.maxOrder = n
					myUnits.n = myUnits.n + off
				end
			end
			----------
			if call.continue and g.validUnits[1] then -- forget everything, unused and let's try to avoid that
				g.acquired,g.validUnits,g.selCost={n=0,byID={},byType = call.byType and {}},{n=0,byID={}},0
				sh.SelCost=0
				sh.Sel_n=0
				if call.add_last_acquired and last.acquired then
					Acquire(last.acquired)				
				end

				if g.Type then g.validUnits.byType={} end
			end
			---------- Scan the designed pool to define (or update) g.validUnits made of matching defs
			local _,n,new,finished = nil,0,true,false
			-- if call.tempdefs then
			-- 	ProcessFiltering(g.preFilter, call.tempdefs, nil, nil, 'TEMP PREFILTER')
			-- end
			if (call.swDefs or call.groups) and call.defs then
				-- in this case call.defs act as a pre filter instead of giving directly valid units
				_,_,new = ProcessFiltering(g.preFilter, call.defs,nil,nil, 'PRE FILTER ')
			end
			-- if new then
			-- 	if call.defOnTheFly then
			-- 		Echo("before is ", g.validUnits.n)
			-- 		_,_,new = ProcessFiltering(g.validUnits, call.defOnTheFly, nil, myUnits, 'ON THE FLY ')
			-- 		Echo("after is ", g.validUnits.n)
			-- 	end
			-- end
			if new then
				local defs
				if call.groups then
					local groups = call.groups
					if not groups.selected then
						local newdefs, numdefs
						-- multichecking multiple defs on each unit and retain the first matching
						_, n, new, _, newdefs, numdefs = ProcessFiltering(g.validUnits, groups, nil, g.preFilter or myUnits, 'GROUPS ', 'multiCheck')
						if new then
							local switch_group = call.switch_groups and groups.last_selected == newdefs and call.clock - call.last_clock < call.switch_groups
							if not switch_group then
								if call.switch_on_identical then
									local identical = n==#currentSel
									if identical then
										local byID = g.validUnits.byID
										for i,id in ipairs(currentSel) do
											if not byID[id] then
												identical = false
												break
											end
										end
										if identical then
											switch_group = true
										end
									end
								end
							end
							if switch_group then
								local testing_defs = {unpack(groups)}
								for i=1,#groups do
									if groups[i] == newdefs then
										table.remove(testing_defs,i)
										break
									end
								end
								if testing_defs[1] then
									local alt_valid = {n=0, byID={}}
									local alt_defs, alt_n, alt_new, alt_num
									_, alt_n, alt_new,_,alt_defs, alt_num = ProcessFiltering(alt_valid, testing_defs,nil,g.preFilter or myUnits, 'GROUPS (switch on identical) ', 'multiCheck')
									if alt_new then
										g.validUnits = alt_valid
										n, new = alt_n, alt_new
										newdefs = alt_defs
										for i, defs in ipairs(groups) do
											if newdefs == defs then
												alt_num = i
												break
											end
										end
										numdefs = alt_num
									end
								end
							end
							groups.selected = newdefs
							groups.selectedNum = numdefs
						end
					else
						defs = groups.selected
					end
					sh.sw = groups.selectedNum
				else
					defs = call.swDefs or call.defs
				end

				if defs  then
					_,n,new,finished = ProcessFiltering(g.validUnits, defs, call.switch, g.preFilter or myUnits)
				end
				
			end
			-- Echo("n,new,finished is ", n,new,finished,"g.acquired.n,#g.acquired is ", g.acquired.n,#g.acquired,#g.validUnits,g.validUnits[#g.validUnits])
			if call.add then
				-- call.add give parallel definition to find new units once we have found at least one unit matching the main definitions
				-- but we scan already for them
				local _,addn,addnew = ProcessFiltering(g.add, call.add, nil, g.preFilter or myUnits, 'ADD ')
				if n>0 then
					if addnew or not g.using_add and addn>0 then
						new = merge(g.validUnits,g.add)
						n = g.validUnits.n
					end
					g.using_add = true
				end
			end
			if call.default then
				-- call.default give a backup definition until main definition is matched
				-- local _,defn,defnew = ProcessFiltering(g.default, call.default, nil, g.preFilter or myUnits, 'DEFAULT ')
				-- if n == 0 and defn>0 then
				-- 	n = defn
				-- 	new = defnew
				-- 	-- Acquire(g.default)
				-- 	g.using_default = true
				-- elseif n>0 and g.using_default then
				-- 	g.acquired = {n=0,byID={}}
				-- 	g.using_default = false
				-- 	new = true
				-- end
				if n == 0 then
					if not g.acquired[1] or g.using_default then
						_,n,new = ProcessFiltering(g.default, call.default, nil, g.preFilter or myUnits, 'DEFAULT ')
						if new then
							g.using_default = true
						end
					end
				elseif g.using_default then
					g.using_default = false
					g.acquired = {n=0,byID={}}
				end

			end
			-- Echo("g.using_default is ", g.using_default)
			if finished then
				return
			end
			-- breakdown:
			---------- want and prev to handle and keep track of previously selected units within the same macro, when 'want' define a restricted number of units
			if new and n>0 then
				if not g.using_default and g.validUnits.n == n and not call.specifyTransport then
					-- first time valid, we filter out different transport state than first
					local id = g.validUnits[1]
					local transported_state = id and (spGetUnitTransporter(id)--[[ or spGetUnitIsTransporting(id)--]])
					if not transported_state then
						local trns = id and spGetUnitIsTransporting(id)
						if trns and trns[1] then
							transported_state = true
						end
					end
					call.tempdefs = {(transported_state and '' or '!') .. 'isTransported'}
					local units = g.validUnits
					local oldValid = g.validUnits
					g.validUnits = {n=0,byID={}}
					_,n = ProcessFiltering(g.validUnits, call.tempdefs, nil, oldValid, 'TEMP ')
				end
				local pool=g.using_default and g.default or g.validUnits
				-- if not g.acquired[1] then 
				-- 	if not g.using_default then
				-- 		local id = pool[1]
				-- 		local transported_state = id and (Spring.GetUnitTransporter(id)--[[ or spGetUnitIsTransporting(id)--]])
				-- 		if not transported_state then
				-- 			local trns = id and spGetUnitIsTransporting(id)
				-- 			if trns and trns[1] then
				-- 				transported_state = true
				-- 			end
				-- 		end
				-- 		local def = (transported_state and '' or '!') .. 'isTransported'
				-- 		call.defOnTheFly = {def}
				-- 		local recv = {n=0, byID={}}
				-- 		ProcessFiltering(recv, call.defOnTheFly, nil, pool, 'ON THE FLY ')
				-- 		g.validUnits = recv
				-- 		pool = recv
				-- 	end
				-- end




				if call.prefer then
					GetPrefered(pool,prev)
				end	

				if prev then
					-- we give another chance to acquire a non previous unit
					if prev.needErase and g.acquired[1] then
						g.acquired,g.selCost={n=0,byID={},byType = call.byType and {} },0 
						prev.needErase=false
						sh.SelCost=0
						sh.Sel_n=0
						if call.add_last_acquired and last.acquired then
							Acquire(last.acquired)
						end

					end
					--


					
					if g.Type then -- choose a type and narrow down the pool to this type, the choice might change if it had to pick a type from prev before
						-- function take into account wether some prefered units has been found
						pool = PickType(g.Type,pool,prev)
						n = pool.n
						-- managing prefered for types

						if call.choice  then
							if call.prefer then 
								-- set the pool of prefered units from available or previous 
								local isInPrev  = not g.hasPrefered
								local prefFolder = isInPrev and g.prefered.default or g.prefered
								local index = prefFolder.types[call.choice]
								local preferedUnits = index and prefFolder[index] and prefFolder[index].byType[call.choice]
								if preferedUnits then
									if debugPrevious then
										local n = preferedUnits.n
										Echo('prev: in '..(isInPrev and 'default ' or '')..'type '..call.choice..' there '..(n==1 and 'is ' or 'are ')..n..' prefered unit'..(n>1 and 's ' or '')..' of value '..index)
									end
									pool = preferedUnits
								else
									if debugPrevious then
										Echo('prev: no prefered units found in type '..call.choice)
									end
								end
							end

						end
					else
						
						if g.hasPrefered then
							pool = g.prefered[g.hasPrefered]
						elseif g.prefered.bestDefault then
							
							pool = g.prefered.default[g.prefered.bestDefault]
						end
					end

					-- Echo("g.hasPrefered is ", g.hasPrefered)
					n = pool.n
					local want = GetWantN(pool,n,method)

					Acquire(pool,want,prev,false)
						-- if want is not lesser (fixed number) and we don't have enough, we pick from prev units in the order their appeared
					if not call.no_pick_in_prev then
						if (want>g.acquired.n and g.acquired.n<n) then
							
							--Acquire(prev,want,prev,pool)

							prev.needErase=prev.type_choice or true
							
						else
							prev.needErase=false
							if debugPrevious then Echo('prev: no need erasing') end
						end

						if prev.needErase then
							if debugPrevious then
								Echo('prev: remaining units to pick are insufficient','found '..n,'want '..want,'acquired '..g.acquired.n)
								Echo('prev: need erasing:'..(prev.needErase==true and 'all' or prev.needErase))
							end


								if debugPrevious then Echo('prev: picking in prev...') end
								Acquire(prev,want,false,pool)
							-- end
						end
					else
						if debugPrevious then
							Echo('prev: selected only non prev units','found '..n,'want '..want,'acquired '..g.acquired.n)
						end
					end

					-- if we had to use previous type or units, we got to delete prev at the end of the call
					-- this might be reversed in the future, depending on the call (cylinder method, more likely, will finally get us some new units)
					--prev.needErase = erasePrev
				else
					n = pool.n
					local want = GetWantN(pool,n,method)
					Acquire(pool,want,false,false)
				end


				if call.proximity and g.acquired.n>0 then -- TODO: need improved to set between picking -at- proximity of acquired and picking -along- the already acquired
					local radius,definitions = call.proximity.radius, call.proximity.defs
					for id in pairs(g.acquired.byID) do
						local px,py,pz = spGetUnitPosition(id)
						myUnits = spGetUnitsInCylinder(px,pz,radius,myTeamID) 
						myUnits.n = #myUnits
						local prox = FindUnits(definitions,{n=0,byID={}},nil,'PROXYMITY ')
						Acquire(prox,false,false)
					end
				end
				-------- special case of ordering instead of selecting, need to improve this method for a more flexible use
				if call.brush_order and g.acquired[1] then
					for cmd,params in pairs(call.brush_order) do
						for i,id in ipairs(g.acquired) do
							TreatOrders(id,cmd,params)
						end
					end
				end
				-------



			end

			---------- update the cost to display
			sh.SelCost= KFormat(g.selCost + (call.shift and last.sh and tonumber(last.sh.SelCost) or 0),2000)
			--Echo("AFTER is ", sh)
			sh.Sel_n=g.acquired.n + (call.shift and last.sh and last.sh.Sel_n or 0)

			----------

			---------------------------------------------
			------------------ SPECIAL WAYS OF SELECTING 
			---------------------------------------------
			if call.early and not call.pressed then
				call.pressed=true
		 		spSelectUnitArray(g.acquired, call.shift)
			 	if call.give_order then
			 		for _,id in ipairs(g.acquired) do
			 			for cmd,params in pairs(call.give_order) do
			 				TreatOrders(id,cmd,params)
			 			end
			 		end
			 	end
			-- select immediately and end the call
		 	elseif call.on_press or call.secondary and not call.secondary.on_press then 
				return FinishCall(not call.brush_order)
			end
			if call.on_delay or call.secondary and call.secondary.on_delay then
				return FinishCall(not call.brush_order)
			end
			if time then
				time = spDiffTimers(spGetTimer(), time)
				if time > 0.07 then
					Echo('new call took too long ! ', time, call.name)
				end
			end
		end
		-- if this Update Round got triggered by KeyPress, this latter CallIn will get Informed to block the key, and might in turn inform MousePress to do aswell
		return call
	end
end
----------- THIRD STEP (in almost every case) : Detect release ,end of call and select

	function widget:KeyRelease(key,mods,keyset) -- key release can also be triggred by MouseRelease which in turn might be triggred by CheckClick
		local ret = call and true
		local click= not KEYCODES[key] and key
		local symbol=click or KEYCODES[key]
		currentCombo.raw[key] = nil


		if ctrlGroups.selecting then
			local toBeSelected = ctrlGroups:GetToBeSelected()
			ctrlGroups.selecting = false
			if toBeSelected then
				if call then
					TerminateCall()
				end
				local addToMap = {}
				for id in pairs(toBeSelected.units) do
					local transporter = spGetUnitTransporter(id)
					if transporter then 
						addToMap[transporter] = true
						toBeSelected.units[id] = nil
					end
				end
				for id in pairs(addToMap) do
					toBeSelected.units[id] = true
				end
				Spring.SelectUnitMap(toBeSelected.units)
				ret = true
			end
		end

		-- if not currentCombo.keys[symbol] then
		-- 	return
		-- end
		currentCombo.keys[symbol]=nil
		if not possibleKeys[symbol] then
			return ret
		end 
		local tmpToggle = locks.tmpToggleByKey[symbol]
		if tmpToggle then 
			local tog_name = tmpToggle.name

			if locks.tmpPushed[tog_name] then
				locks.tmpPushed[tog_name]=false

				currentCombo.keys[tog_name]=currentCombo.keys[tog_name]==nil and 0 or nil
			end
		end
		currentCombo.keys[(click and 'double'..click or 'doubleTap')] = nil
		currentCombo.keys[(click and 'fastDouble'..click or 'fastDoubleTap')] = nil
		currentCombo.keys['spam'] = nil
		currentCombo.keys['longPress'] = nil
		currentCombo.keys['longClick'] = nil
		currentCombo.keys['mouseStill'] = nil
		longPress.active, longPress.key = false, false
		local newcall = not WG.panning and HKCombos:Find(currentCombo.keys)
		ret = ret or newcall
		-- Echo("newcall==call, newcall==(call and call.secondary) is ", )
		if call and newcall and (newcall==call or newcall==call.secondary) then
			return ret
		end
		if call	 then
			if call.on_delay and clock()-call.clock<call.on_delay then
				return ret
			end
			-- Echo(call.locked,"call~=HKCombos:Find(currentCombo.keys) is ", call~=HKCombos:Find(currentCombo.keys))
			if not call.locked and call~=newcall then
				if call.option_name then
					TerminateCall()
				else
					-- widget:DrawGenesis(0) -- this can terminate the call in some rare occasion (panning)
					if call then
						-- 	call ended successfully, we can select our findings now...
						FinishCall(not call.brush_order)
					end
				end
			else
				call.locked=true
			end

		end	
		g.keyChanged=true
		return ret
	end
	-------------- End Of KeyRelease


do
	local min,max=math.min,math.max
	local spGetModKeyState = Spring.GetModKeyState
	local ac=25
	function widget:MouseWheel(up,value)
--[[		----debugging all active command
			if spGetModKeyState() then
			ac=ac+(up and 1 or -1)
			--Echo(" is ", Spring.FindUnitCmdDesc(spGetSelectedUnits()[1],CMD_LOADUNITS_SELECTED))
			--Echo("spSetActiveCommand(ac) is ", spSetActiveCommand(30))
			local descs = Spring.GetUnitCmdDescs(spGetSelectedUnits()[1])
			for i,desc in pairs(descs) do if desc.name then Echo(i,desc.name) end end
			Echo("CMD_LOAD_SELECTED is ", CMD_LOADUNITS_SELECTED)
			
			
			--Echo(ac," is ", spGetActiveCommand())
			return true
		end--]]
		local macro=call
		-- allow the user to set the radius of the last call if he can't change it during the call (on_press=true) with ALT+MouseWheel, within 5 seconds after that call 
		if macro then
			longPress.key=false
		end
		-- Echo("macro and macro.name is ", macro and macro.name,macro and macro.on_release)

		if (not macro or not next(macro.keys)) and spGetModKeyState() then
			if macro then
				if macro.force_finish then
					FinishCall(not macro.brush_order)
				else
					TerminateCall()
				end
				-- return true
			end
			local mx,my = spGetMouseState()
			x,y,z = UniTraceScreenRay(mx,my)
			if not x then
				return
			end
			local lastCall=last.call
			-- not fullSel ,lastCall --[[and lastCall.on_press--]] and (lastCall.method=='cylinder' or lastCall.method=='around_selected') and clock()-lastCall.clock<5			
			-- lastCall --[[and lastCall.on_press--]] and (lastCall.method=='cylinder' or lastCall.method=='around_selected') and clock()-lastCall.clock<5 then
				-- Echo("lastCall and lastCall.name is ", lastCall and lastCall.name
				-- 	, lastCall and (lastCall.method=='cylinder' or lastCall.method=='around_selected')
				-- 	,lastCall and clock()-lastCall.clock<5
				-- 	,'fullSel', fullSel
				-- 	)

			if not fullSel and lastCall --[[and lastCall.on_press--]] and (lastCall.method=='cylinder' or lastCall.method=='around_selected') and clock()-lastCall.clock<5 then
				macro=lastCall
				local color = macro.color
				local draw_pos = macro.draw_pos
				macro.clock=clock()
				DRAW = {
					declare=true,
				   	drawing=true,
				   	finishing=true,
				   	circle=true,
				   	'Changing ' .. macro.name .. ' Radius',
				   	false,
				   	color[1],color[2],color[3],color[4],
				   	Fade(color[4],macro.fading,5,1,true),
				   	Fade(color[4],macro.fading,5,1,true),
				   	draw_pos[1]-200,draw_pos[2],
				   	macro.size or 25,
				   	true,
				}





			elseif fullSel then -- reduce/re-augment the selection, from closest of mouse
				local dists={}
					-- NOTE: interestingly enough, the dists table will be filled while using the sorting func as intended, but then after
					-- trying to traverse it with pairs() will not work, nor next() will find anything, the table is emptied
				local sortByDist = function(a,b)
					if not dists[a] then
						local ax,ay,az = spGetUnitPosition(a)
						dists[a] = ((ax-x)^2+(az-z)^2)^0.5
					end
					if not dists[b] then 
						local bx,by,bz = spGetUnitPosition(b)
						dists[b] = ((bx-x)^2+(bz-z)^2)^0.5
					end
					return dists[a]<dists[b]
				end
				local n=#fullSel
				local off = 0
				for i=1,n do
					i = i + off
					local id = fullSel[i]
					if not spValidUnitID(id) or spGetUnitIsDead(id) then
						table.remove(fullSel,i)
						off = off - 1
					end
				end
				n = n + off
				if n<=1 then return true end
				if not fullSel.partial then fullSel.partial=1 end
				if fullSel.partial==1 and up then return true end

				-- new method using unit type
				if not fullSel.defIDs then
					fullSel.defIDs = Spring.GetSelectedUnitsSorted()
					-- test if dead unit
					for defID, units in pairs(fullSel.defIDs) do
						for i, id in ipairs(units) do
							if spGetUnitIsDead(id) then
								Echo('sorted selection contain dead unit !, Units[id]?',Units[id])
							end

						end
					end

					-- sort defID by size so we pick the remaining little sized one if we can at the end
					local sortBySize = function(a,b)
						return a.size>b.size
					end
					local bySize = {}
					for defID,t in pairs(fullSel.defIDs) do
						t.defID = defID
						t.size = #t
						table.insert(bySize,t)
					end
					table.sort(bySize, sortBySize)
					-- we don't need to rmb the defIDs
					fullSel.defIDs = bySize
				end

				local step = max(fullSel.partial*abs(value)*0.1,1/n)-- step is 10% per notch or at least one unit
				fullSel.partial = min(max(step,fullSel.partial + step * (up and 1 or -1)),1)
				local nToSelect = max(1,round(n*fullSel.partial))

				local showNumberSelected = false
				if showNumberSelected then
					sh.Sel_n = nToSelect
				else
					-- if we don't want the number selected in parenthesis
					sh.Sel_n = 0
				end
				DRAW={declare=true
				   	 ,drawing=true
				   	 ,finishing=true
				   	 ,circle=false
				   	 -- ,'Selection Resize ' .. ('%d'):format(fullSel.partial * 100)  .. '%%'
				   	 ,'Sel ' .. ('%d'):format(fullSel.partial * 100)  .. '%%'
				   	 ,false
				   	 ,1,1,1,0.8
				   	 ,Fade(0.8,0.5,5,1,true)
				   	 ,Fade(0.8,0.5,5,1,true)
				   	 -- ,DEFAULT_DRAW_POS[1]-200,DEFAULT_DRAW_POS[2]
				   	 ,DEFAULT_DRAW_POS[1]-50,DEFAULT_DRAW_POS[2]
				   	 ,25
				   	 ,true}

				if nToSelect==1 then
					-- special case of selection resized to only one, give the closest one from mouse without caring about unit types
					table.sort(fullSel,sortByDist)
					spSelectUnitArray({fullSel[1]})
					selectionResized = { [ fullSel[1] ] = true }
					return true
				end


				-- Echo("nToSelect is ", nToSelect)

				local newSelection = {}
				local selected = 0
				local defIDs = fullSel.defIDs
				local n = #defIDs
				local off = 0
				for i=1,n do
					i = i+off
					local t = defIDs[i]
					local t_off = 0
					for j=1,t.size do
						j = j + t_off
						local id = t[j]
						if not spValidUnitID(id) or spGetUnitIsDead(id) then
							table.remove(t,j)
							t_off = t_off - 1
						end
					end
					t.size = t.size + t_off
					if not t[1] then
						table.remove(defIDs,i)
						off = off - 1
					else
						t.toSelect = 0
					end
				end
				-- Echo('fraction: ' .. fullSel.partial)
				for i,t in ipairs(defIDs) do
					table.sort(t,sortByDist)
					-- local inDefIDToSelect = ceil(t.size*fullSel.partial)
					local inDefIDToSelect = max(1,round(t.size*fullSel.partial))
					-- NOTE: if we use round, in case the fraction should be 0.5 it will be instead 0.49999998 so it might round to one less ie when 5 of a type + 5 of another type are selected
					-- also because round can give one less, it might end up with less in total than nToSelect
					-- completing then with defID that were the closest to pass to one more

					if inDefIDToSelect + selected > nToSelect then
						inDefIDToSelect = nToSelect - selected
					end
					selected = selected + inDefIDToSelect
					t.toSelect = inDefIDToSelect

					-- Echo('Add ' , t.toSelect , ' ' .. UnitDefs[t.defID].humanName ..' (' .. t.size  .. '*' .. fullSel.partial .. ' = ' .. t.size*fullSel.partial .. ')' , ' total added: ' .. selected )
					if nToSelect == selected then
						break
					end
				end
				if selected < nToSelect then
					local tries = 0
					-- get the ones that were the closest from passing to one more in first
					local function sortHighestHalf(a,b)
						return a.ratio>b.ratio
					end
					local ratios = {}
					for i,t in ipairs(defIDs) do
						-- the ones below n.5 will be higher
						t.ratio = (t.size*fullSel.partial + 0.5) % 1
						ratios[i] = t
					end
					table.sort(ratios, sortHighestHalf)
					---- debug ratios
					for i,t in ipairs(ratios) do
						-- Echo('sorted ratio', UnitDefs[t.defID].humanName, t.ratio)
					end
					----
					while selected < nToSelect do
						tries = tries + 1 ; if tries>500 then Echo('[' .. widget:GetInfo().name .. ']:ERROR infinite loop in resizing selection') break end
						for i,t in ipairs(ratios) do
						-- for i=#fullSel.defIDs,1,-1 do -- picking in the smallest size
							-- local t = fullSel.defIDs[i]
							if selected < nToSelect then
								selected = selected + 1
								t.toSelect = t.toSelect + 1
								-- Echo('Add an extra ' .. UnitDefs[t.defID].humanName .. ' to complete.')
							end
							t.ratio = nil
						end
					end
				end
				local byID = {}
				for i,t in ipairs(defIDs) do
					-- Echo('select ' .. t.toSelect ..  ' ' .. UnitDefs[t.defID].humanName)
					for i=1, t.toSelect do
						local id = t[i]
						table.insert(newSelection, id)
						byID[id] = true
					end
				end

				----- old Method not taking into account unit types
				-- table.sort(fullSel,sortByDist)
				-- for i=1,nToSelect do
				-- 	local id = fullSel[i]
				-- 	newSelection[i]=id
				-- end
				-----



				--
				local identical = #currentSel==nToSelect
				if identical then
					for i=1,nToSelect do
						local id = currentSel[i]
						if not byID[id] then
							identical = false
							break
						end
					end
				end
				if identical then return true end

				-- spSelectUnitArray(arr)

				selectionResized = byID
				-- if spGetActiveCommand() ~= 0 then -- cancelled as resizing a selection shouldnt prevent inevitably from an active command to be active
				-- 	spSetActiveCommand(0)
				-- end
				spSelectUnitArray(newSelection)

				return true
			end
			sh.SelCost=0
			sh.Sel_n=0
		end


		if macro then
			if up then
				g.radius = min(3000, g.radius*(1+0.1*value))	
			else
				g.radius = max(40, g.radius*(1+0.1*value))		
			end
			local ratio = (Cam and Cam.dist or GetCameraHeight(spGetCameraState())) / BASE_CAMERA_HEIGHT
			-- ratio = max(ratio,1)
			-- local ratio = (GetCameraHeight(spGetCameraState()) * 1.5 / 1000)
			local base_radius = g.radius / (macro.fixed_radius and 1 or (0.8 + (ratio-1)/zoom_scaling))--/ (1 - (1 - (GetCameraHeight(spGetCameraState()) / 2000) ) /zoom_scaling)
			HKCombos.byName[macro.share_radius or macro.name].radius = base_radius
			memRadius[macro.share_radius or macro.name] = base_radius 
			return true
		end
	end

end


	function widget:CommandNotify()
		if selectionResized then
			-- Echo('--- resized')
			-- for k,v in pairs(selectionResized) do
			-- 	Echo(k,v)
			-- end
			-- Echo('full')
			-- for k,v in pairs(fullSel) do
			-- 	Echo(k,v)
			-- end
		end

	end


	function widget:CommandsChanged(force)
		--Echo("round(clock()*10)-lastTime is ", round(clock()*10)-lastTime)
		-- chk('reset')
		-- local lastCall = last.call
		-- if lastCall then
		-- 	Echo('last call ',lastCall.name, 'succeed?' , lastCall.success)
		-- end

		last.sel = currentSel
		local newsel = spGetSelectedUnits()
		if identical(newsel,currentSel) then
			return
		else
			currentSel=ByID(newsel)
		end
		if not currentSel[1] then
			fullSel = false
		end


		-- -- the next lines are used for hotkey that switch between old selections, this is unused

		-------------- memorize non widget selections along with the internal ones for browsing purpose -- unused/unuseful
		-- local thistime = round(clock()*10)
		-- if force or not call and (thistime-lastTime>2) then
		-- 	-- check if it worth memorizing
		-- 	if UselessSelection(g.Selections[g.Selections.n],currentSel) then return end
		-- 	if g.Selections.n==MAX_SELECTIONS then
		-- 		table.remove(g.Selections,1)
		-- 	else
		-- 		g.Selections.n=g.Selections.n+1
		-- 	end
		-- 	g.Selections[g.Selections.n]=currentSel
		-- end
		-- lastTime = thistime

		--


		-- -- chk('say')
	end

	function UselessSelection(previous_sel,new_sel) -- are they identical
		if not previous_sel then return false end
		if not new_sel[1] then return true end
		if #previous_sel~=#new_sel then return false end
		local byID,byI = previous_sel.byID,new_sel
		if not byID then
			new_sel.byID={}
			byID,byI = new_sel.byID,previous_sel
			for i,id in ipairs(new_sel) do byID[id]=i end
		end
		for i,id in ipairs(byI) do if not byID[id] then return false end end
		return true
	end


--------------

------------------------------------------------------------------------------
------------------------------------------------------------------------------
------------------------------- DRAWING --------------------------------------
------------------------------------------------------------------------------
------------------------------------------------------------------------------


	do
		local dName,dSelName,dR,dG,dB,dAlpha,dFader,dFaderTxt,dPosX,dPosY,dSize,noFadeIn
		local dTextAlpha
		local masked_id
		local combo_display = ''
		local color = f.COLORS
		local vsx,vsy
		function widget:GetViewSizes(x,y)
			vsx,vsz = x,y
		end
		function widget:DrawWorld() 
			--- auto mask unit under cursor
			--glPushMatrix()
			--glDrawGroundCircle(pos[1], pos[2], pos[3], 40, 40)
			--glPopMatrix()
			ctrlGroups:Draw()
			if DRAW.drawing then
				if DRAW.declare then
					dName,dSelName,dR,dG,dB,dAlpha,dFader,dTxtFader,dPosX,dPosY,dSize,noFadeIn = unpack(DRAW)
					DRAW.declare=false
				end
				if DRAW.finishing then
					if dName=='Plus' or dName=='Minus' then
						dFader(0.1,1,1)
						dTxtFader(0.1,1,1)
					else
						dFader(0.1,noFadeIn and 5 or 100,-1) -- give lesser amplitude when call.on_press since it will not fade in
						dTxtFader(0.1,noFadeIn and 5 or 10,-1)
					end	
					DRAW.finishing=false
				end
				--local cost=g.selCost>0 and GetCameraHeight(spGetCameraState())<2000 and (g.selCost<2000 and round(g.selCost) or round(g.selCostit need to be 00)..'K')
				glColor(dR,dG,dB,dAlpha)
				glLineStipple(true)
				if DRAW.circle then
					glLineWidth(1.5)
					glPushMatrix()
					glDrawGroundCircle(x, y, z, g.radius, 40) -- draws a simple circle.
		--[[		if not tooHigh then -- show selection info near cursor when zoomed in, finally never doing it
						if call.continue then dsSelName = sel[1] end
						glText((dSelName or dName)..' ('..sel.n..')'..(sh.SelCost>0 and  '\n($'..sh.SelCost..')' or ''), 30, 50, 20, 'v') -- Displays text. First value is the string, second is a modifier for x (in this case it's x-25), third is a modifier for y, fourth is the size, then last is a modifier for the text itself. 'v' means vertical align.
					end--]]
					glPopMatrix()
				end
				glLineWidth(1.0)
	--[[			for c in pairs(Circles) do
					local x,_,z,_,y = spGetUnitPosition(id,true)
					glPushMatrix()
					glDrawGroundCircle(x, y, z, 40, 40)
					glPopMatrix()
				end--]]
				for id in pairs(g.acquired.byID) do
					if spValidUnitID(id) then	
						local x,_,z,_,y = spGetUnitPosition(id,true)
						-- glPushMatrix()
						glDrawGroundCircle(x, y, z, 40, 40)
						-- glPopMatrix()
					end
				end
				glColor(1, 1, 1, 1)
				glLineWidth(1.0)
				glLineStipple(false)

				if dAlpha<=0.1 and dTextAlpha<=0.1 then DRAW.drawing=false  end
				dAlpha = dFader()
				dTextAlpha = dTxtFader()
			end
		end
		local format = string.format
		local kConcat = table.kConcat
		local lLock,lname,lR,lG,lB,lalpha,lx,ly,lsize,lSet
		local done
		local t={}
		local sortNum = function(a,b)
			return t[a] < t[b]
		end

		function widget:DrawScreen()
			-- drawing selection info and call name
			if ctrlGroups.selecting then
				local toBeSelected = ctrlGroups.toBeSelected
				local suffix = ''
				glColor(1,1,1,0.7)
				if toBeSelected then
					glColor(toBeSelected.color)
					suffix = ': [' .. toBeSelected.id .. '] #' .. table.size(toBeSelected.units) .. ''
				end
				glText('CtrlGroup ' .. ctrlGroups.selecting .. suffix, DEFAULT_CYLINDER_DRAW_POS[1]-30,DEFAULT_CYLINDER_DRAW_POS[2]-50, 25)
				glColor(1,1,1,1)
			end
			if DRAW.drawing then
				glColor(dR,dG,dB,dTextAlpha)
				-- if call and call.continue and call.selname and g.acquired.n>0 then dsSelName = Units[next(g.acquired.byID,nil)].name end
				local extra = ''
				if sh.sw then
					extra = extra .. ' sw: '.. sh.sw
				end
	   			glText(format((dSelName or dName) .. extra ..(sh.Sel_n>0 and ' ('..sh.Sel_n..')' or '')..(g.hasPrefered and ' #' .. g.hasPrefered or '').. (sh.SelCost~=0 and  '\n($'..sh.SelCost..')' or '')), dPosX,dPosY, dSize)
			end
			--
			---Showing Costs (should go to another widget and finished)
			
		    if loss.ally then
		    	-- glColor(1,0,0,1)
		    	--glText(format('Ally Loss:'..sh.Aloss..(sh.CurAl~=0 and ' '..sh.CurAl or '')), 60,200, 15)
		    end
		    if loss.enemy then
				-- glColor(0,1,0,1)
		    	--glText(format('Enemy Loss:'..sh.Eloss..(sh.CurEl~=0 and ' '..sh.CurEl or '')), 60,180, 15)
		    end
			-- Showing Combo in bottom left if wanted
			if options.debugcurrentcombo.value then

				combo_display=''
				local box = {}
				for k,v in pairs(currentCombo.keys) do
					if v~=0 then 
						table.insert(box,k)
						table.insert(t,v)
					end
				end
				table.sort(box,sort)


				for k,v in pairs(currentCombo.keys) do 
					if v==0 then table.insert(box,k) end
				end
				for i,v in ipairs(box) do

					combo_display=combo_display.. (i==1 and '' or ' | ') ..v
				end


				local num = 8
				glColor(color.grey)
				local lasts = ''
				local finish = call and 2 or 1
				local len = #last.chained
				for i = num, finish, -1 do
					local thiscall = last.chained[len-i+finish]
					if thiscall then
						if thiscall.success then
							glColor(color.darkgreen)
						else
							glColor(color.grey)
						end
						local str = '[' .. thiscall.gameTime .. ']' .. (thiscall.name .. ' %.2f'):format(thiscall.duration)
						glText(str, 60,220 + (i) * 15, 15)
						-- lasts = lasts .. '[' .. thiscall.gameTime .. ']' .. (thiscall.name .. ' %.2f'):format(thiscall.duration)
					end
					-- lasts = lasts .. '\n'
				end

				-- glText(lasts, 60,220 + (num) * 15, 15)
				if call then 
					glColor(color.lime)
					glText(format(call.name), 60,220 + 15, 15)
				end

				glColor(color.white)
			-- glText(format(kConcat(currentCombo.keys)), 60,220, 15)

				glText(format(combo_display), 60,220, 15)
			end
			glColor(1,1,1,1)

			---Showing Locks
			if locks.count==0 then return end
			-- saving variable redeclaration if only one lock
			if not lSet and locks.count==1 then
				-- _,lLock=next(locks,nil)
				lLock = locks[1]
				lname = lLock.name
				lR,	lG,	lB,lalpha = unpack(lLock.color)
				lfading = lLock.fading
				lx,ly=unpack(lLock.draw_pos)
				lsize=lLock.size
				lSet = true
			end

			for name, lock in ipairs(locks) do 
				 -- if there is more than one lock
				if locks.count>1 then
					lname = lock.name
					lR,	lG,	lB,lalpha = unpack(lock.color)
					lfading = lock.fading
					lx,ly=unpack(lock.draw_pos)
					lsize=lock.size
				end
				--
				local isON = currentCombo.keys[lname]
				if not isON and lock.active then -- finishing, fading out
						lock.Fader(0.1,1,1)
						lock.active=false
				elseif not lock.active and isON then -- starting over
					lock.Fader=Fade(lalpha,lfading,4,-1,true)
					lock.active=true
				end
				if lock.Fader then

					-- calculate new alpha and applying
					lalpha=lock.Fader()
					if lalpha>0.1 then
						glColor(lR,lG,lB,lalpha)
					   	--glText(format(lock.name), x,resY-68, 25)
					   	glText(format(lname), lx,ly, lsize)
					else
						lock.Fader=false

					end
				end
			end
			glColor(1,1,1,1)
		end
	end

--------------------------------------------------------


function MyNewTeamID(id)
	myTeamID=id
end




function widget:SetConfigData(data)
	if not data.memRadius then data.memRadius=memRadius end
	memRadius = data.memRadius
	if not data.locks then data.locks={} end
	for name in pairs(data.locks) do
		currentCombo.keys[name]=0
	end
end
function widget:GetConfigData()

	local data_locks={}
	for name in pairs(locks) do
		if currentCombo.keys[name] then
			data_locks[name]=true
		end
	end
	return {memRadius=memRadius, locks=data_locks}
end
function widget:GameStart()
	g.gameStarted = true
	widgetHandler:RemoveWidgetCallIn('GameStart',widget)
end
function widget:Shutdown()
	if g.switchBackSelFiltering then
		g.SelFiltering.value = true
		g.SelFiltering:OnChange()
		g.switchBackSelFiltering = false
	end
	if Units then Units.subscribed[widget:GetInfo().name]=nil end
end
f.DebugWidget(widget)


