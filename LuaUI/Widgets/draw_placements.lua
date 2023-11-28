function widget:GetInfo()
	return {
		name      = "Draw Placement",
		desc      = "Place builds following cursor, respecting radius for eBuilds and much more",
		author    = "Helwor",
		version   = "v1",
		date      = "30th May, 2020",
		license   = "GNU GPL, v2 or later",
		layer     = -10001, -- before PBH
		enabled   = true,
		handler   = true,
	}
end

local Echo = Spring.Echo

include("keysym.lua")
VFS.Include("LuaRules/Configs/customcmds.h.lua")
local _, ToKeysyms = include("Configs/integral_menu_special_keys.lua")


----
--CONFIG
----
local MAX_REACH = 500 -- set radius of unit scan around the cursor, to detect connections of grid, 500 for pylon, 150 for singu/fusion


----- default value of options before user touche them
local neatFarm = false
local autoNeat = true
local useExtra = true -- use extra search around to choose between 2 best methods that return the same number of poses
local showRail = false
local useReverse = true
local tryEdges = false
-----

local myTeamID = Spring.GetMyTeamID()

--------------------------------------------------------------------------------
-- Speedups
--------------------------------------------------------------------------------
local f = VFS.Include("LuaUI\\Widgets\\UtilsFunc.lua")
--if not extraFunctions then extraFunctions = VFS.Include("LuaUI\\Widgets\\UtilsFunc.lua")
local callinsList 						= f.callinsList

local tracefunc 						= f.tracefunc

local Page 								= f.Page
local GetDirection 						= f.GetDirection
local s									= f.s
local GetDef 							= f.GetDef
local l									= f.l
local inTable							= f.inTable
local UniTraceScreenRay					= f.UniTraceScreenRay
local CheckCanSub						= f.CheckCanSub
local TestBuild                   		= f.TestBuild
local PushOut							= f.PushOut
local getconTable						= f.getconTable
local GetDist 							= f.GetDist
local GetPosOrder 						= f.GetPosOrder
local GetInsertPosOrder 				= f.GetInsertPosOrder

local GetTeamUnits						= f.GetTeamUnits

local roughequal 						= f.roughequal
local sbiggest 							= f.sbiggest
local rects 							= f.rects
-- local contiguous 						= f.contiguous
local corners 							= f.corners
local MergeRects 						= f.MergeRects
-- local minMaxCoord 						= f.minMaxCoord
local MapRect 							= f.MapRect
local IsOverlap							= f.IsOverlap
-- local StateToPos 						= f.StateToPos
local GetCons 							= f.GetCons
local GetCommandPos						= f.GetCommandPos
local res 								= f.res
local IsEqual 							= f.IsEqual

local color = f.COLORS


local MultiInsert 						= f.MultiInsert
local getcons 							= f.getcons
local deepcopy 							= f.deepcopy
-- local bet 								= f.bet
local toMouse 							= f.toMouse

-- local togrid 							= f.pointToGrid

local GetCameraHeight					= f.GetCameraHeight
-- local newTable 							= f.newTable


-- local toValidPlacement 					= f.toValidPlacement

-- local Overlapping 						= f.Overlapping
-- local Overlappings 						= f.Overlappings

-- local Turn90 							= f.Turn90

-- local vunpack 							= f.vunpack
local CheckTime 						= f.CheckTime

-- local nround							= f.nround

--local ListCallins 						= f.ListCallins


local UnitDefs = UnitDefs

local Points={} -- debugging
local Cam

local sign = function(x) return x<0 and -1 or 1 end

local sp = {

	GetActiveCommand 		= Spring.GetActiveCommand
	,SetActiveCommand 		= Spring.SetActiveCommand

	,GetModKeyState   		= Spring.GetModKeyState
	,GetUnitsInCylinder		= Spring.GetUnitsInCylinder
	,GetUnitsInRectangle	= Spring.GetUnitsInRectangle
	,GetUnitDefID	 		= Spring.GetUnitDefID
	,GetSelectedUnits 		= Spring.GetSelectedUnits
	,GetMyTeamID 			= Spring.GetMyTeamID
	,GetAllUnits 	 		= Spring.GetAllUnits


	,GetCommandQueue  		= Spring.GetCommandQueue
	,GiveOrderToUnit  		= Spring.GiveOrderToUnit
	,GiveOrderToUnitArray  	= Spring.GiveOrderToUnitArray

	,WarpMouse 		 		= Spring.WarpMouse
	,WorldToScreenCoords 	= Spring.WorldToScreenCoords
	,GetMouseState    		= Spring.GetMouseState
	,TraceScreenRay  	 	= Spring.TraceScreenRay
	,GetGroundHeight  		= Spring.GetGroundHeight

	,SendCommands			= Spring.SendCommands

	,ValidUnitID			= Spring.ValidUnitID
	,ValidFeatureID			= Spring.ValidFeatureID
	,GetUnitPosition 	    = Spring.GetUnitPosition
	,GetFeaturePosition		= Spring.GetFeaturePosition


	,GetBuildFacing			= Spring.GetBuildFacing
	,GetBuildSpacing		= Spring.GetBuildSpacing
	,SetBuildSpacing		= Spring.SetBuildSpacing
	,GetUnitBuildFacing		= Spring.GetUnitBuildFacing

	,GetCameraState			= Spring.GetCameraState
	,GetCameraPosition		= Spring.GetCameraPosition
	,SetCameraTarget		= Spring.SetCameraTarget

	,GetTimer				= Spring.GetTimer
	,DiffTimers 			= Spring.DiffTimers

	,Pos2BuildPos 			= Spring.Pos2BuildPos
	,ClosestBuildPos 		= Spring.ClosestBuildPos

	,FindUnitCmdDesc  		= Spring.FindUnitCmdDesc
	,GetMyTeamID     		= Spring.GetMyTeamID
	,GetUnitTeam 			= Spring.GetUnitTeam
	,SetMouseCursor 		= Spring.SetMouseCursor
	,GetUnitsInRectangle	= Spring.GetUnitsInRectangle

	,IsUnitAllied			= Spring.IsUnitAllied
	,GetCmdDescIndex		= Spring.GetCmdDescIndex

	,GetModKeyState			= Spring.GetModKeyState

}
------------------ SPEED MEMORY ACCESS BENCHMARK
-- do
-- 	local lSpring = Spring
-- 	local spGetUnitsInRectangle = Spring.GetUnitsInRectangle
-- 	local testfuncs = {
-- 		fn = function()
-- 			if Spring.GetUnitsInRectangle then end
-- 		end,
-- 		fn2 = function()
-- 			if sp.GetUnitsInRectangle then end
-- 		end,
-- 		fn3 = function()
-- 			if lSpring.GetUnitsInRectangle then end
-- 		end,
-- 		fn4 = function()
-- 			if spGetUnitsInRectangle then end
-- 		end,
-- 		fn5 = function(var)
-- 			if var then end
-- 		end,
-- 	}
-- 	Spring = Spring
-- 	testfuncs.fn1 = function()
-- 		if Spring.GetUnitsInRectangle then end
-- 	end




-- 	CheckTime = function(fn, it, comment,...)
-- 		local time = Spring.GetTimer()
-- 		for i=1, (it or 1) do
-- 			fn(...)
-- 		end
-- 		time = Spring.DiffTimers(Spring.GetTimer(), time)
-- 		Echo((comment or 'function').. ' took ' .. time)
-- 	end

-- 	CheckTime(testfuncs.fn, 2000000,'normal Spring')
-- 	CheckTime(testfuncs.fn1, 2000000,'global Spring')
-- 	CheckTime(testfuncs.fn2, 2000000,'local table')
-- 	CheckTime(testfuncs.fn3, 2000000,'local Spring')
-- 	CheckTime(testfuncs.fn4, 2000000,'upvalue')
-- 	CheckTime(testfuncs.fn5, 2000000,'local',spGetUnitsInRectangle)
-- end
--------------------



-- --
-- local oriSetActiveCommand = sp.SetActiveCommand
-- local tm, history = os.clock(), {}
-- function sp.SetActiveCommand(cmd)
-- 	local now = os.clock()
-- 	local spam = now - tm  < 0.1
-- 	if spam then
-- 		table.insert(history,now .. ' cmd: ' .. cmd)
-- 	else
-- 		if history[4] then
-- 			Echo('SetActiveCommand got spammed !', table.concat(history, '\n'))
-- 		end
-- 		history = {}
-- 	end
-- 	return oriSetActiveCommand(cmd)
-- end
-- ---




------ OPTIONS
local function GetPanel(path) -- Find out the option panel if it's visible
    for _,win in pairs(WG.Chili.Screen0.children) do
        if  type(win)     == 'table'
        and win.classname == "main_window_tall"
        and win.caption   == path
        then
            for panel in pairs(win.children) do
                if type(panel)=='table' and panel.name:match('scrollpanel') then
                    return panel
                end
            end
        end
    end
end
options_path = 'Hel-K/DrawingPlacement'

options_order = {'neatfarm','autoneat','useextra','usereverse','tryedges','showrail'}
options = {}

options.showrail = {
	name = 'Show Rail',
	type = 'bool',
	value = showRail,
	OnChange = function(self)
		showRail = self.value
	end,
}

options.neatfarm = {
	name = 'Paint Farm: neat squares only',
	desc = 'use only one method to place neat squares or use all available methods to find placable builds asap',
	type = 'bool',
	value = neatFarm,
	OnChange = function(self)
		neatFarm = self.value
		options.useextra.hidden = neatFarm
		options.autoneat.hidden = neatFarm
		options.usereverse.hidden = neatFarm
		options.tryedges.hidden = neatFarm
		local panel = GetPanel(options_path)
		if panel then
			WG.crude.OpenPath(options_path)
			local newpanel = GetPanel(options_path)
			if newpanel then
				newpanel.scrollPosY = panel.scrollPosY
			end
		end

	end,
}
options.autoneat = {
	name = 'Paint Farm: Auto Neat',
	desc = 'Choose automatically wether to use neat farm or not',
	type = 'bool',
	value = autoNeat,
	OnChange = function(self)
		autoNeat = self.value
	end,
}

options.useextra = {
	name = 'Paint Farm: Use extra search',
	desc = 'use extra search around to get the most desirable positions for our current poses',
	type = 'bool',
	value = useExtra,
	OnChange = function(self)
		useExtra = self.value
	end,
}
options.usereverse = {
	name = 'Paint Farm: Use reverse search',
	desc = 'use a third method going reverse to get better results',
	type = 'bool',
	value = useReverse,
	OnChange = function(self)
		useReverse = self.value
	end,
}
options.tryedges = {
	name = 'Paint Farm: Try edges method',
	desc = 'priviledgize pose that has touch the most edge points of posed builds',
	type = 'bool',
	value = tryEdges,
	OnChange = function(self)
		tryEdges = self.value
	end,
}

------------- DEBUG OPTIONS

local Debug = { -- default values, modifiable in options
    active = false, -- no debug, no other hotkey active without this
    global = true, -- global is for no key : 'Debug(str)'
    reload = true,

    paint = false,
    judge = false,
    edges = false,
    paintMethods = false,
}



local GetWidgetOption = WG.GetWidgetOption




local GetCloseMex



local max 		= math.max
local min		= math.min
local round 	= math.round
local abs 		= math.abs
local sqrt		= math.sqrt
local floor 	= math.floor
local ceil 		= math.ceil
-- local biggest 	= math.biggest
--local sbiggest  = math.sbiggest
-- local t   		= type
local clock 	= os.clock





local format 			= string.format


-- local SM = widgetHandler:FindWidget('Selection Modkeys')
-- if SM then
-- 	SM_Enabled = SM.options.enable
-- end


local g = {}

local PBH

local EMPTY_TABLE = {}
--[[
local toggleHeight   = KEYSYMS.B
local heightIncrease = KEYSYMS.C
local heightDecrease = KEYSYMS.V
--]]


local spacingIncrease = KEYSYMS.Z
local spacingDecrease = KEYSYMS.X

---------------------------------
-- Epic Menu
---------------------------------


--------------------------------------------------------------------------------
-- Config
--------------------------------------------------------------------------------

VFS.Include("LuaRules/Configs/customcmds.h.lua")

local opt = {
	connectWithAllied = true
}



--test()
--------------------------------------------------------------------------------
-- Local Vars
--------------------------------------------------------------------------------

--local time
--local tick={}
--local coroute={}

local DP={}
local eraser_color = { 0.6, 0.7, 0.5, 0.2}

local mexDefID = UnitDefNames["staticmex"].id
local pylonDefID = UnitDefNames['energypylon'].id
local pos = false

local noDraw = {
	[UnitDefNames["staticcon"].id]=true,
	[UnitDefNames["staticstorage"].id]=true,
	[UnitDefNames["staticrearm"].id]=true
}


local E_SPEC = {
	[UnitDefNames["energysolar"].id] = true,
	[UnitDefNames["energywind"].id] = true,
	[UnitDefNames["energypylon"].id] = true,
	[UnitDefNames['energyfusion'].id]=true,
	[UnitDefNames['energysingu'].id]=true,


}
local E_RADIUS={
	[UnitDefNames['staticmex'].id]=49,
	[UnitDefNames['energysolar'].id]=99,
	[UnitDefNames['energywind'].id]=60,
	[UnitDefNames['energyfusion'].id]=150,
	[UnitDefNames['energysingu'].id]=150,
	[UnitDefNames['energypylon'].id]=499,
	--[UnitDefNames['energypylon'].id]=3877,
}

-- for paint farm
local Paint -- paint farm function

local farm_spread = false
local FARM_SPREAD = { -- how far in half-sizes from the cursor a placement can occur
					  -- 1 is default, if 1 then there will be no placement on cursor, but an attempt to put 4 placements with common corner at cursor (offsetted by oddx)
					  -- if >1 then there will be an attempt to put 1 at center + all around,
					  -- if nothing on the way, 2 will bring 9 placement, 4 will bring 25 and so on
	[UnitDefNames['spiderscout'].id]=3, 
	[UnitDefNames['energywind'].id]=2,
}
local farm_scale = false
local FARM_SCALE = { -- separation of build in farm per defID
	[UnitDefNames['energywind'].id]=1,

}
local MAX_SCALE = {
	[UnitDefNames['energywind'].id]=3,
	[UnitDefNames['energysolar'].id]=7,
}
--------
local factoryDefID = {}
for defID, def in pairs(UnitDefs) do
	local cp = def.customParams
	if cp.parent_of_plate then
		factoryDefID[defID] = true
	end
end

local special = false




local overlapped = {}


local closeMex = {}
local cantMex={}

local switchSM, SM_enable_opt




local previMex = {}

-- local forgetMex = {} -- not used anymore
local spacing = false

local newmove


local preGame = Spring.GetGameSeconds()<0.1

local CURSOR_ERASE_NAME, CURSOR_ERASE = 'map_erase','eraser'

local mx,my = false,false

--local places

--local blockIndexes -- not used anymore, time consuming

local rail = {n=0}
local specs = {
	n=0, mexes = {},
	clear = function(self)
		for i=1,#self do
			self[i] = nil
		end
		for k in pairs(self.mexes) do
			self.mexes[k] = nil
		end
		self.n = 0
	end,
}
local mexes = specs.mexes

local connectedTo={}
local allGrids = {}


local placed={}



local primRail={n=0}
local mapSizeX,mapSizeZ = Game.mapSizeX,Game.mapSizeZ

-- local pushRail= false
-- local pushedRails={n=0}
-- local AVG = {n=0}


local Drawing = false

WG.drawEnabled = false


-- local rmbAct=false

local status ='none'
local waitReleaseShift=false


-- those are used with Backwarding and Warping functions which are currently not used anymore
	-- local backward = false
	-- local invisible = false
	-- local freeze = false
	-- local warpBack = false
	-- local oldCamPos = false
	-- local camPosChange = false
	-- local camGoal = false
	-- local panning = false
	-- local hold = false
	-- local washold = false
	-- local mousePos = {}
	-- local hold = false
--
local p = {}
local prev = {
	lasP_To_Cur=0,
	llasP_To_Cur=0,
	dist_drawn = 0,
	press_time = os.clock(),
	pos=false,
	pid=false,
	mexDist=0,
	x=false,
	y=false,
	mx=false,
	my=false,
	firstmx = false,
	firstmy = false,
}



local PID = false



local leftClick = false
local rightClick = false
local shift = false
local meta = false


local cons



local pointX = 0
local pointY = 0
local pointZ = 0


Echo("----------------------------------------------------------------")

local function getclosest(from,tbl)
	local closest,changed,bestDist=1
	local same={}
	local tbl_n = #tbl
	for i=1,tbl_n do
		local t=tbl[i]
		local dist = (from[1]-t[1])^2+(from[2]-t[2])^2
		if not bestDist then 
			bestDist=dist
		elseif bestDist==dist then
			same[i]=dist
		elseif dist<bestDist then
			bestDist=dist closest=i changed=true
		end

	end
	for i,dist in pairs(same) do
		if bestDist~=dist then same[i]=nil end
	end
	return changed,tbl[closest],closest,next(same) and same
end



local function ReorderClosest(total,first_i,last_i,con, startpoint)
	local startpoint=startpoint or total[first_i-1]
	if not startpoint then
		if not con then
			startpoint=total[first_i]
		else
		 	local x,_,z = Spring.GetUnitPosition(con)
		 	startpoint={x,z}
		end
	end
	local veryfirst = startpoint
	-- local last_startpoint
	local t,i = {},0
	for a=first_i,last_i do
		i=i+1
		-- Echo('add one item at ',a)
		t[i]=total[a]
	end
	for a=first_i,last_i do
		local _,_,i,same = getclosest(startpoint,t)
		if same and veryfirst~=startpoint then
			_,_,i = getclosest(veryfirst,t)
		end
		-- Echo("closest =>",i)
		-- startpoint=table.remove(t,i)
		-- total[a]=startpoint
		total[a] = table.remove(t,i)
	end
end

local function IsMexable(spot)
	local mexID = sp.GetUnitsInRectangle(spot.x,spot.z,spot.x,spot.z)[1]
	if not mexID then
		return true
	end
	if not sp.IsUnitAllied(mexID) then
		return false
	end
	local bp = select(5,Spring.GetUnitHealth(mexID))
	if not bp or bp <1  then
		return true
	end
		-- or select(5,Spring.GetUnitHealth(mexID))<1 and Spring.AreTeamsAllied(Spring.GetMyTeamID(), Spring.GetUnitTeam(mexID))

end


------------------ geos object

local geos = {
	map={},
	defID = UnitDefNames["energygeo"].id,
	cant = {},
}
function geos:Get()
	for i,fID in ipairs(Spring.GetAllFeatures()) do
	    if FeatureDefs[Spring.GetFeatureDefID(fID)].geoThermal then
	        local fx, fy, fz = Spring.GetFeaturePosition(fID)
	        fx,fz = (floor(fx/16)+0.5) * 16,(floor(fz/16)+0.5) * 16
	        -- Points[#Points+1]={fx,fy,fz}
	        local thisgeo = {x = fx, z = fz}
	        self[#self+1] = thisgeo
	        local map = self.map
	        for x=fx-32,fx+32,16 do
	            if not map[x] then map[x]={} end
	            for z=fz-32,fz+32,16 do
	                map[x][z]=thisgeo
	            end
	        end
	    end
	end
end
function geos:GetClosest(x,z,dist)
    if not dist then dist=math.huge end
    local maxDist = dist
    local spot
    for i,thisspot in ipairs(self) do
        local thisdist = ((thisspot.x-x)^2+(thisspot.z-z)^2)^0.5
        if thisdist<dist then spot,dist=thisspot,thisdist end
    end
    return spot,dist
end

function geos:BarOccupied()
	for i,spot in ipairs(self) do
		local geoX,geoZ = spot.x,spot.z
		local cantPlace,blockingStruct= TestBuild(geoX,geoZ,p,true,placed)
		if blockingStruct then
			for i,b in ipairs(blockingStruct) do
				if b.defID==self.defID then
					geos.cant[spot]=true
					break
				end
			end
		end
	end
end
function geos:Update(newx,newz)
	local geoX,_,geoZ = sp.ClosestBuildPos(0,PID, newx, 0, newz, 600 ,0 ,0)
	local spot
	local ClosestBuildPosFailed = geoX==-1
	if geoX==-1 then -- ClosestBuildPos can return -1 if it need terraformation first
		spot = self:GetClosest(newx,newz,500)
		if not spot then return end
		geoX,geoZ = spot.x,spot.z
	else 
		spot = self.map[geoX] and self.map[geoX][geoZ]
	end
	if not spot then return end
	if self.cant[spot] then return end
	self.cant[spot]=true
	if ClosestBuildPosFailed then
		-- if WG.movedPlacement[1] then
		-- 	geoX,_,geoZ = unpack(WG.movedPlacement)
		-- Echo("WG.movedPlacement[1] is ", WG.movedPlacement[1])
		-- else
		-- 	return
		-- end
		if WG.FindPlacementAround then
			WG.FindPlacementAround(geoX,geoZ)
			-- local needterra,_,blockingStruct = WG.CheckTerra(geoX,geoZ)
			if WG.movedPlacement[1]>-1 then
				geoX,_,geoZ = unpack(WG.movedPlacement)
			else
				return
			end
		else 
			-- local cantPlace = TestBuild(geoX,geoZ,p,true,placed,overlapped)
			-- if cantPlace then return end
			return
		end
	end
	return geoX,geoZ
end

----------------------





local SendCommand
do
	local TABLE_BUILD = {0, 0, CMD.OPT_SHIFT, 0, 0, 0, 0}
	local GiveOrder,			GetGround,			GetOrders,			HasCommand,		 		GetDelta
	 = sp.GiveOrderToUnit, sp.GetGroundHeight, sp.GetCommandQueue, sp.FindUnitCmdDesc, Spring.GetLastUpdateSeconds
	SendCommand =  function(PID)
		--local cons = sp.GetSelectedUnits()
		if not preGame and cons.n == 0 then	return end
		local nspecs=#specs
		if nspecs==0 then return end



		-- if global build command is active, check if it wants to handle the orders before giving units any commands.
		if WG.GlobalBuildCommand and WG.GlobalBuildCommand.CommandNotifyRaiseAndBuild(cons, -PID, pointX, pointY, pointZ, p.facing, s) then
			return
		end

		-- Didnt touch GlobalBuildCommand...won't probably work like that(Helwor)
		if nspecs==0 then
			return
		end
		-- putting every placements in one go, adding mexes if needed
		local facing = p.facing
		local total,n={},0
		for i=1,nspecs do
			local spec = specs[i]
			spec.pid = PID
			n=n+1; total[n]=spec
			local nspec = n
			if mexes[i] then
				local inmexes=mexes[i]
				for i=1,#inmexes do -- it can happen we have to put several mexes after one single building placement, (when placing pylon mostly)
					local inmex = inmexes[i]
					inmex.mex=true
					n=n+1
					total[n]=inmex
				end
				-- reorder mexes and the e Build to get closest of each others first
				ReorderClosest(total,nspec,n,i==1 and cons[1]--[[,i>1 and specs[i-1]--]])
			end
		end
		if mexes[nspecs+1] then -- in case we don't have one more specs but one more group of mexes?
			-- Echo('we have last mexes without spec')
			local inmexes=mexes[nspecs+1]
			local nspec = n
			for i=1,#inmexes do
				inmexes[i].mex=true
				n=n+1; total[n]=inmexes[i]
			end
			ReorderClosest(total,nspec,n,cons[1])
		end
		local opts = f.MakeOptions(nil, true)
		local shift = true
		if status=='paint_farm' then
			local spread = FARM_SPREAD[PID]
			local toReorder = (not spread and 4) or (spread - spread%2 + 1)^2
			ReorderClosest(total,1,nspecs>toReorder and toReorder or nspecs,cons[1])
		else

			if factoryDefID[PID] then
				local plate_placer = widgetHandler:FindWidget("Factory Plate Placer")
				if plate_placer and plate_placer.CommandNotify then
					for i=1, n do
						local p = total[i]
						plate_placer:CommandNotify(-PID,  {p[1],sp.GetGroundHeight(p[1],p[2]), p[2],1},opts)
					end
				end
			end
		end

		if PBH then -- Let PersistentBuildHeight do the job
			if PID == mexDefID then
				local done
				for i,p in ipairs(total) do
					done = PBH:CommandNotify(-mexDefID, {p[1],sp.GetGroundHeight(p[1],p[2]), p[2],1},opts) or done
				end
				if done then
					return
				end
			end
			WG.commandLot = WG.commandLot or {}
			local lot = WG.commandLot
			for k,v in ipairs(lot) do lot[k]=nil end
			for k,v in ipairs(total) do lot[k]=v end
			conTable = PBH.TreatLot(lot,PID,true)
			return
		end
		if preGame then
            local IQ = widgetHandler:FindWidget("Initial Queue ZK")
            if IQ then 
                -- hijacking CommandNotify of widget Initial Queue ZK, for it to take into consideration pre Game placement on unbuildable terrain
                for i,b in ipairs(total) do
                	IQ:CommandNotify(b.mex and -mexDefID or -PID,{b[1],GetGround(b[1],b[2]),b[2]},opts)
                end
            end
            return
		end


	    local time = os.clock()
	    for id,con in pairs(conTable.cons) do
	        con.canBuild = sp.FindUnitCmdDesc(id,-PID)
	    end

	    if not (shift or meta) then
	        conTable.inserted_time = false
	        conTable.waitOrder = false
	        for id,con in pairs(conTable.cons) do
	            con.commands = {}
	            con.queueSize = 0
	        end
	    elseif not conTable.inserted_time or conTable.inserted_time and time - conTable.inserted_time > 0.8 then
	        conTable.inserted_time = false
	        conTable.waitOrder = false
	        for id,con in pairs(conTable.cons) do
	            local queue = sp.GetCommandQueue(id,-1)
	            local commands = {}
	            for i,order in ipairs(queue) do
	                local posx,_,posz = GetCommandPos(order)
	                commands[i] = not posx and EMPTY_TABLE or {posx,posz}
	            end
	            con.commands = commands
	            con.queueSize = #queue
	        end
	    end
	    conTable.multiInsert = false
	    if shift and meta then 
	        -- workaround to have a virtually updated command queue until it is actually updated
	        local has2ndOrder, conRef
	        -- has2ndOrder => don't insert before the first order if there is only one order to send (terraform included)
	        -- hasSecondOrder = lot[2] and lot[2]~=lot[1] or lot[3] or false
	        -- use cons[1] as reference for position for every cons
	        conRef = cons[1]
	        MultiInsert(total,conTable,true,has2ndOrder,conRef) 
	    end
		-- local conTable =  MultiInsert(total)
		local codedOpt = {coded=CMD.OPT_ALT}
		local firstCon = true
        for i=1, #total do
            local x,z = unpack(total[i])
            for id,con in pairs(conTable.cons) do
            	if HasCommand(id,-PID) then
	                local cmds = GetOrders(id,-1)
	                local noAct = not shift and not meta or #cmds==0 or #cmds==1 and (cmds[1].id==0 or cmds[1].id==5)
	                local pos = (noAct or not meta) and -1 or (con.insPoses[i] or 0)
	                TABLE_BUILD[1]=pos
	                local buildPID = total[i].mex and -mexDefID or -PID
	                TABLE_BUILD[2]=buildPID
	                TABLE_BUILD[4]=x
	                TABLE_BUILD[5]=GetGround(x,z)
	                TABLE_BUILD[6]=z
	                TABLE_BUILD[7]=facing
	                if not widgetHandler:CommandNotify(CMD.INSERT,TABLE_BUILD,codedOpt) then
                    	GiveOrder(id,CMD.INSERT,TABLE_BUILD,CMD.OPT_ALT)
                    	if firstCon and conTable.inserted_time then
                    		conTable.waitOrder = {CMD.INSERT,TABLE_BUILD}
                    	end 
                    	firstCon = false
                    end
                    -- GiveOrder(id,CMD.INSERT,{pos,buildPID,CMD.OPT_SHIFT, x, GetGround(x,z), z, facing},CMD.OPT_ALT)
	            end
            end
        end
	    
	end
end

-- for k,v in pairs(widget) do
--     if tonumber(k) and tonumber(k) > 39000 then
--         Echo(k,v)
--     end
-- end

local EraseOverlap
do
	local mem = setmetatable({},{__mode='v'})
	-- local mem = {}
	EraseOverlap = function(x,z) 
	    local GetQueue,GiveOrder,CMD_REMOVE,pcall = sp.GetCommandQueue,sp.GiveOrderToUnit,CMD.REMOVE,pcall
	    sp.SetMouseCursor(CURSOR_ERASE_NAME)
	    if not x then
			x,z = pos[1],pos[3]
			-- x = floor((x + 8 - p.oddX)/16)*16 + p.oddX
			-- z = floor((z + 8 - p.oddZ)/16)*16 + p.oddZ
		end
	    local sx,sz = p.terraSizeX, p.terraSizeZ
	    local viewHeight = Cam and Cam.relDist or GetCameraHeight(sp.GetCameraState())
	    local factor = 1
	    if viewHeight>2500 then
	    	factor = 1+(viewHeight-2500)/2500
	    	sx, sz = sx * factor, sz * factor
	    end
	    g.erase_factor = factor
	    local erased
	    if preGame then
	        local IQ = widgetHandler:FindWidget("Initial Queue ZK")
	        if not IQ then return end
	        local queue =  WG.preGameBuildQueue
	        local j,n = 1,#queue
	        local optShift = {shift=true}
	        while j<=n do 
	            local order = queue[j]
	            local id,ix,iy,iz,facing = unpack(order)
	            local ud=UnitDefs[id] 
	            local isx,isz=ud.xsize*4,ud.zsize*4
	            local off=facing==1 or facing==3
	            if off then isx,isz=isz,isx end
	            if (x-ix)^2 < (sx+isx)^2 and (z-iz)^2 < (sz+isz)^2 then
		            IQ:CommandNotify(-id,{ix,iy,iz},optShift)
		            local newn = #queue
		            if newn~=n then 
		            	n=newn
		            	erased = true
		            	j=j-1
	                end
	            end
	        	j=j+1
	        end
	        return erased
	    end
	    -- f.Page(Spring.GetUnitRulesParams(cons[1]))
	    local plopped = {}
	    local known_command = {}
	    local temp_key = {}

	    for i,id in ipairs(cons) do
	    	mem[id] = mem[id] or setmetatable({},{__mode='v'})
	    	-- mem[id] = mem[id] or {}
	    	local mem_done = mem[id]
	        local queue=GetQueue(id,-1)
	        local levelx,levelz,leveltag
	        for j=1,#queue do -- not checking the first command, as the build may have been nanoframed if it is at first order

	            local command = queue[j]
	            local cmdid = command.id
	            local tag = command.tag
	            if not mem_done[tag] then
		            -- Echo('current command',Spring.GetUnitCurrentCommand(id))
		            if cmdid < 0 or cmdid == CMD_LEVEL then
		                local ud=cmdid < 0 and UnitDefs[-cmdid]
		                if ud then
		            		local params=command.params
		                    local ix,iz,facing = params[1],params[3],params[4]
		                    local isx,isz=ud.xsize*4,ud.zsize*4
		                    local off=facing==1 or facing==3
		                    if off then isx,isz=isz,isx end
		                    -- overlap check
		                    --Echo("overlap is ", (x-ix)^2 < (sx+isx)^2 and (z-iz)^2 < (sz+isz)^2)
		                    if (x-ix)^2 < (sx+isx)^2 and (z-iz)^2 < (sz+isz)^2 then
		                    	-- we verify the cons hasnt plopped the nanoframe yet
		                    	local authorized = true
		                    	if j==1 then
		                    		local ixiz = ix .. iz
			                    	if plopped[ixiz]==nil then 
			                    		plopped[ixiz] = sp.GetUnitsInRectangle(ix,iz,ix,iz)[1] or false
			                    	end
			                    	authorized = plopped[ixiz] == false
			                    end
		                    	if authorized then
			                        if levelx==ix and levelz==iz then 

			                            pcall(GiveOrder,id,CMD_REMOVE, leveltag, 0)
			                            mem_done[leveltag] = temp_key
			                        end
			                        GiveOrder(id,CMD_REMOVE, tag, 0)
			                        mem_done[tag] = temp_key
			                        erased=true
			                    end
		                    end
		                elseif cmdid == CMD_LEVEL then
	                    	levelx,levelz = command.params[1], command.params[3]
	                    	leveltag = command.tag
		                else
		                    levelx=false
		                end
		            else
		                local ix, iy, iz = GetCommandPos(command)
		                if ix and (x-ix)^2 < (sx)^2 and (z-iz)^2 < (sz)^2 then
		                	local tag = command.tag
		                	GiveOrder(id,CMD_REMOVE, tag, 0)
		                	mem_done[tag] = temp_key
		                    erased=true
		                else
		                	mem_done[command.tag] = temp_key
		                end

		            end
		        end

	        end
	    end
	    return erased
	end
end
local function GetPlacements() -- for now, only placements from current cons are considered

	if not (  preGame and  WG.preGameBuildQueue and WG.preGameBuildQueue[1]	or cons[1] and sp.ValidUnitID(cons[1])  ) then
		return EMPTY_TABLE
	end
	local lookForEbuild = PID and E_RADIUS[PID] and status ~= 'paint_farm' and sp.GetBuildSpacing() >= 7

	local time = Spring.GetTimer()
	local T,length={},0
	local eBuilds,copy = {},{}
	local buffered = conTable and conTable.inserted_time and os.clock() - conTable.inserted_time < 0.8 
	local queue = preGame and WG.preGameBuildQueue or buffered and conTable.cons[ cons[1] ].commands or sp.GetCommandQueue(cons[1],-1)
	for i,order in ipairs(queue) do
		local pid,x,y,z,facing
		if buffered then
			if order.cmd and order.cmd < 0 then
				x,z = order[1], order[2]
				pid, facing = -order.cmd, order.facing
			end
		elseif preGame then
			pid,x,y,z,facing = unpack(order)
		elseif order.id<0 then 
			pid,x,y,z,facing = -order.id, unpack(order.params)
		end
		if pid then
			local s=p:Measure(pid,facing)
			local sx,sz = s.sizeX,s.sizeZ
			local radius = E_RADIUS[pid]
			if pid==mexDefID and GetCloseMex --[[and not preGame--]] then
				local spot = GetCloseMex(x,z)
				if spot then
					-- cantMex[spot]=not IsMexable(spot)
					cantMex[spot]=true
				end
			end
			length=length+1
			local build = {x,z,sx,sz,radius=radius,defID=pid}
			T[length]=build
			if lookForEbuild and radius and radius<500 then
				eBuilds[build]=true
				-- Points[#Points+1] = {x,sp.GetGroundHeight(x,z),z,txt = x..'-'..z}
			end
			--Echo("UnitDefs[-order.id].name is ", UnitDefs[-order.id].name,sx,sz)
		end
	end
	--connect placements together

	--if special then

		local function LinkTogether(eBuild,link) -- this might need a limitation, if hundreds of solars are ordered
			local x,z = eBuild[1],eBuild[2]
			local radius = eBuild.radius
			local linked={}
			eBuild.grid=link
			eBuilds[eBuild]=nil
			
			for eBuild2 in pairs(eBuilds) do
				
				local ix,iz,iradius = eBuild2[1],eBuild2[2],eBuild2.radius
				if (x-ix)^2 + (z-iz)^2 < (radius+iradius)^2 then

					linked[eBuild2]=true
					eBuild2.grid=link
				end
			end
			-- Echo('-- link '..link)
			for eBuild in pairs(linked) do

				LinkTogether(eBuild,link)
			end
			-- Echo('--')
			
		end

		local link=0
		local eBuild = next(eBuilds)
		while eBuild do
			link=link+1
			LinkTogether(eBuild,'p'..link)
			eBuild=next(eBuilds)
		end
	--end

	return T
end

function widget:CommandsChanged()
--[[		for _, myCmd in pairs(buildQueue) do
			local cmd = myCmd.id
			if cmd < 0 then -- check visibility for building jobs
				local x, y, z, h = myCmd.x, myCmd.y, myCmd.z, myCmd.h
				if spIsAABBInView(x-1,y-1,z-1,x+1,y+1,z+1) then
					buildList[#buildList+1] = myCmd
				end--]]
	cons=getcons()
	conTable = getconTable()
	--if cons[1] then placed = GetPlacements() end -- FOR TESTING ONLY
end

local NormalizeRail
local GoStraight

do
	local start,start_r,last_good_spec_n,locked
	local cur_dirx, cur_dirz
	local color = f.COLORS
	local function GetOrthoDir(x1,x2,z1,z2)
		local rawx,rawz = ( x2 - x1 ), ( z2 - z1 )
		local abx, abz = abs(rawx), abs(rawz)
		local biggest =  max( abx, abz )
		local dirx, dirz = rawx / biggest, rawz / biggest
		local straight_dirx,straight_dirz = round(dirx), round(dirz)
		return straight_dirx,straight_dirz
	end
	GoStraight = function(on,x,z,railLength)
		start = rail[start_r] and rail[start_r].straight and rail[start_r] 
		if not on then
			if start then 
				g.unStraightened,locked = clock(),clock()
			end
			start, cur_dir, start_r = nil, nil,nil --[[Echo('return normal')--]]
			return false,locked,x,z,railLength
		else
			g.unStraightened = false
		end

		if not start then 
			start_r = rail.n
			start = rail[start_r]
			last_good_spec_n = specs.n
			if start then 
				start.straight=true
				start.color=color.blue
				locked=clock()
			end
		end
		if not start then --[[Echo('no start')--]] return false,locked,x,z,railLength end
		if not x then return end
		local rawx,rawz = ( x - start[1] ), ( z - start[3] )
		local abx, abz = abs(rawx), abs(rawz)
		local biggest =  max( abx, abz )
		local dirx, dirz = rawx / biggest, rawz / biggest
		local straight_dirx,straight_dirz = round(dirx), round(dirz)

		if cur_dirx~=straight_dirx or cur_dirz~=straight_dirz then
			cur_dirx, cur_dirz = straight_dirx, straight_dirz
			rail.processed = start_r
			for i=start_r+1, rail.n do rail[i]=nil end
			rail.n = start_r
			for i=last_good_spec_n+1,specs.n do specs[i]=nil end
			specs.n = last_good_spec_n

			NormalizeRail()
			if status=='paint_farm' then
				rail.processed=0
				specs:clear()
				Paint('reset') 
				TestBuild('reset memory')
				Paint()
			end
		end
		-- Echo("straight_dirx,straight_dirz is ", straight_dirx,straight_dirz)
		x,z = start[1] + straight_dirx * biggest, start[3] + straight_dirz * biggest
		-- local verx,verz = ( x - start[1] ), ( z - start[3] )
		-- Echo(rail.n,start[1],start[3],abx,abz,'correct',x,z,'verif',verx,verz)
		-- Points[1] = {x,sp.GetGroundHeight(x,z),z}
		-- Echo("start.straight is ", start.straight,start[1],start[3])
		return true,locked,x,z, rail.n
	end
end





local function reset(complete)
	--ControlFunc(1,"Def","break",DefineBlocks)
	if PID and select(4,sp.GetModKeyState()) and specs[1] then  waitReleaseShift=true end
	--Echo(debug.getinfo(2).currentline)
	WG.drawEnabled=false
	if complete then
		WG.showeco = g.old_showeco
	end
	-- paint farm stuff
	Paint('reset') 
	farm_spread=false
	farm_scale = false
	TestBuild('reset memory')
	--
	TestBuild('reset invalid')
	--
	GoStraight(false)
	g.unStraightened = false
	--
	pointX = false
	--cons = {}
	Drawing = false
	specs:clear()
	WG.drawingPlacement = false

	newmove = nil
	rail = {n=0}
	linked = {}
	-- pushedRails = {n=0}
	-- AVG={n=0}
	primRail={n=0}
	geos.cant={}
	cantMex={}
	previMex = {}
	knownUnits={}
	prev.pos = false
	prev.lasP_To_Cur = 0
	prev.llasP_To_Cur = 0
	prev.start_mx, prev.start_my = false, false
	overlapped={}
	connectedTo={}
	allGrids = {}

	local metalSpots = WG.metalSpots or EMPTY_TABLE
	for i=1,#metalSpots do metalSpots[i].grids=nil end


	spacing = false
	special = false

	-- forgetMex = {n=0}


	-- mousePos = {} -- belong to warping/backwarding


end
--[[function widget:TextCommand(command)
Echo("command is ", command)
end--]]

--[[local function CheckWarping() -- not used anymore
	-- if PID and status=='engaged' and shift or warpBack=="hold" then
	if PID and status=='engaged' and shift then


		local resX, resY = widgetHandler:GetViewSizes()
		local ud = UnitDefs[PID]
		local	_, pos = sp.TraceScreenRay(mx, my, true, false, false, not ud.floatOnWater)
		pos = pos or false
		if pos then
			local cam = sp.GetCameraState()


			local px,py,pz = cam.px, cam.py, cam.pz
			local diffpx = pos and px and px-pos[1]
			local diffpz = pos and pz and pz-pos[3]

		local maximum = mx<130 or mx>resX-130 or my<160 or my>resY-150		



			local camPos = {sp.GetCameraPosition()}

			camPosChange = oldCamPos and not roughequal({oldCamPos[1],oldCamPos[3]}, {camPos[1],camPos[3]}, 0)

			oldCamPos = {sp.GetCameraPosition()}	
			if maximum and not camPosChange then


				sp.SetCameraTarget(px - (diffpx)*0.85,py,pz-(diffpz)*1.3,0.50)
				warpBack = "ready"
				return true
			end

			-- if camPosChange and camGoal then
			if camPosChange then
			
				if prev.mx then
					mouseDir = GetDirection(prev.mx,prev.my,mx,my)
					--speed = math.sqrt(abs(mx-prev.mx)^2+abs(my-prev.my)^2)
					sp.WarpMouse(mx-(mx-resX/2)/4,my-(my-resY/2)/4)
					sp.SetActiveCommand(0)
				end
				--prev.mx=mx
				--prev.my=my

				--sp.SendCommands("Mouse1")
				return true
			elseif not camPosChange and freeze  then
				--defining a warpback position, either on last placement or on last mouse position, depending if the last placement is out of screen or not
				-- for now freeze got the recorded world pos of the mouse
				futX,futY = toMouse(specs[#specs])
				local maximum = futX<130 or futX>resX-130 or futY<160 or futY>resY-150		
				if not maximum then 
					freeze = specs[#specs] -- if placement is not out of screen, freeze become placement
				end
				warpBack = true
			end
		else
			Echo("hors limite")
			warpBack = false
			freeze=false
			
			return false
		end

	------------------------------------------------
		if warpBack=="ready" and not freeze then
			--recording mouse position in world pos as soon as we gonna pan view
			Echo("Getting freeze")

			local	_, pos = sp.TraceScreenRay(mx, my, true, false, false, not ud.floatOnWater)
			pos = pos or false
			if pos and not freeze then
				freeze = {pos[1],pos[2],pos[3]}
			end
			return true
		end



		if freeze and warpBack==true then

			sp.WarpMouse(toMouse(freeze)) 

			p:RecoverPID()
			if IsEqual(freeze,specs[#specs]) then
				sp.SendCommands("Mouse1") -- clicking mouse on placement for graphical coherance
			end
			warpBack = false
			freeze=false
			return true
		elseif not freeze  and warpBack==true then
			freeze=false
			warpBack = false

		end
		if camPosChange then -- waiting for view panning to be over
			return true
		end

	else

		warpBack = false
		freeze=false

		warpBack = false

	end

end--]]


--[[local function CheckBackward2() -- not used anymore
	backward = false
	local last = #specs-1>0 and #specs-1
	if last then

		local lastX, lastY = toMouse(specs[last]) -- getting a valid mouse position according to the new placement
		local curX,curY = toMouse(specs[#specs])

	--local oriDist = GetDist(mousePos[last][1],mousePos[last][2],mousePos[#specs][1],mousePos[#specs][2])
	--local newDist = GetDist(mousePos[last][1],mousePos[last][2],mx,my)
		local oriDist = GetDist(lastX,lastY,curX,curY)
		local newDist = GetDist(lastX,lastY,mx,my)
		local j = "current is last"
		for i=#specs-2, 1,-1 do -- if we are zoomed out and previous ones are close, we help the backwarding
			local iX,iY = toMouse(specs[i])

			--local prevOriDist = GetDist(mousePos[i][1],mousePos[i][2],mousePos[#specs][1],mousePos[#specs][2])
			local prevOriDist = GetDist(iX,iY,curX,curY)

			if prevOriDist<1500  then
			-- if prevOriDist<1500 and prevOriDist>oriDist  then
				j = "current is "..#specs-1-i.." before last"
				--local prevNewDist = GetDist(mousePos[i][1],mousePos[i][2],mx,my)
				local prevNewDist = GetDist(iX,iY,mx,my)
				if prevNewDist<=prevOriDist then 
					newDist = prevNewDist
					oriDist = prevOriDist
					backward = true
					break
				end
			else
	  			break
			end
		end
		--Echo(j, "backward=", backward)
		--Echo(speed)

		if (newDist<=oriDist ) and not invisible then 
		-- if (newDist<=oriDist or last2 and newDist2<oriDist2) and not invisible then 
		local last2 = #specs-2>0 and #specs-2
			if special and last2 then
				local oriDist2 = GetDist(mousePos[last2][1],mousePos[last2][2],mousePos[#specs][1],mousePos[#specs][2])
				local newDist2 = GetDist(mousePos[last2][1],mousePos[last2][2],mx,my)
				backward = newDist2<oriDist2
			else
				backward=true
			end
		
			backward = true
			--Echo(" backward")
			--Echo("--")
		end


		if backward and (newDist<oriDist*2/3) then
		-- if backward and (newDist<oriDist*2/3) or (last2 and newDist2<oriDist2) then
			--Echo("oriDist<1500 is ", oriDist<1500)
			if mexes[#specs] then
				
				local num = inTable(forgetMex, mexes[#specs])
				forgetMex[num]=nil
				mexes[#specs]=nil
			end

			specs[#specs]=nil




			--widgetHandler:UpdateWidgetCallIn("DrawWorld", self)

			--- little trick to place correctly placement grid from engine
			local curMouse = {mx,my}

			local mX, mY = toMouse(specs[#specs]) -- getting a valid mouse position according to the new placement
			sp.WarpMouse(mX,mY)

			sp.SendCommands("Mouse1")
			local impede = false
			if #specs>3 then-- in case we're crossing another placement we have to fully jump or we will get stuck
				for i=1, #specs-1 do
						
					impede=	pointX>specs[i][1]-p.footX*16 and pointX<=specs[i][1]+p.footX*16 and
					   		pointZ>specs[i][2]-p.footZ*16 and pointZ<=specs[i][2]+p.footZ*16
					if impede then

						break
					end
				end
			end
			if impede then
			-- if impede  or oriDist<1500 then
				--Echo("total warp")
				--sp.WarpMouse(unpack(mousePos[#specs]))
				sp.WarpMouse(mX,mY)
			else
				--local midX = curMouse[1]-(curMouse[1]-mousePos[#specs][1])/3
				--local midY = curMouse[2]-(curMouse[2]-mousePos[#specs][2])/3

				local midX = curMouse[1]-(curMouse[1]-mX)/3
				local midY = curMouse[2]-(curMouse[2]-mY)/3
				--Echo("little warp")
				sp.WarpMouse(midX,midY)
			end

			--sp.SetActiveCommand(activeCom) --renewing placement starting for graphical coherence

			--------
		end
		if backward then
			return true
		end
	end
	return false
end
--]]
local function CheckBackward() -- not used and older
	local specsLength = #specs
	backward = false
	local last = specsLength>1 and specs[specsLength-1]
	if last then
		local toScreen,GetGround = sp.WorldToScreenCoords,sp.GetGroundHeight

		local current = specs[specsLength]
		local toScreen = sp.WorldToScreenCoords
		local lastX, lastY = toScreen(last[1],last[2],last[3]) -- getting a valid mouse position according to the new placement
		local curX,curY = toScreen(current[1],current[2],current[3])

	--local oriDist = GetDist(mousePos[last][1],mousePos[last][2],mousePos[#specs][1],mousePos[#specs][2])
	--local newDist = GetDist(mousePos[last][1],mousePos[last][2],mx,my)
		local oriDist = (lastX-curX)^2 + (lastZ-curZ)^2
		local newDist = (lastX-mx)^2 + (lastZ-mz)^2
		local j = "current is last"
		for i=#specs-2, 1,-1 do -- if we are zoomed out and previous ones are close, we help the backwarding
			local spec=specs[i]
			local iX,iY = toScreen(spec[1],GetGround(spec[1],spec[2]),spec[2])

			--local prevOriDist = GetDist(mousePos[i][1],mousePos[i][2],mousePos[#specs][1],mousePos[#specs][2])
			local prevOriDist = GetDist(iX,iY,curX,curY)

			if prevOriDist<1500 --[[and prevOriDist>oriDist--]]  then
				j = "current is "..#specs-1-i.." before last"
				--local prevNewDist = GetDist(mousePos[i][1],mousePos[i][2],mx,my)
				local prevNewDist = GetDist(iX,iY,mx,my)
				if prevNewDist<=prevOriDist then 
					newDist = prevNewDist
					oriDist = prevOriDist
					backward = true
					break
				end
			else
	  			break
			end
		end
		--Echo(j, "backward=", backward)
		--Echo(speed)

		if (newDist<=oriDist --[[or last2 and newDist2<oriDist2--]]) and not invisible then 
			--[[local last2 = #specs-2>0 and #specs-2
			if special and last2 then
				local oriDist2 = GetDist(mousePos[last2][1],mousePos[last2][2],mousePos[#specs][1],mousePos[#specs][2])
				local newDist2 = GetDist(mousePos[last2][1],mousePos[last2][2],mx,my)
				backward = newDist2<oriDist2
			else
				backward=true
			end--]]
				backward = true
			--Echo(" backward")
			--Echo("--")
		end


		if backward and (newDist<oriDist*2/3)--[[ or (last2 and newDist2<oriDist2)--]] then
			--Echo("oriDist<1500 is ", oriDist<1500)
			if mexes[specsLength] then
				
				local num = inTable(forgetMex, mexes[specsLength])
				forgetMex[num]=nil
				mexes[specsLength]=nil

			end

			specs[specsLength]=nil
			specsLength=specsLength-1
			--widgetHandler:UpdateWidgetCallIn("DrawWorld", self)
			--- little trick to place correctly placement grid from engine
			local pmx, pmy = toMouse(specs[specsLength]) -- getting a valid mouse position according to the new placement
			sp.WarpMouse(pmx,pmy)

			sp.SendCommands("Mouse1")
			local impede = false
			if #specs>3 then-- in case we're crossing another placement we have to fully jump or we will get stuck
				for i=1, #specs-1 do
						
					impede=	pointX>specs[i][1]-p.footX*16 and pointX<=specs[i][1]+p.footX*16 and
					   		pointZ>specs[i][2]-p.footZ*16 and pointZ<=specs[i][2]+p.footZ*16
					if impede then

						break
					end
				end
			end
			if impede  --[[or oriDist<1500--]] then
				--Echo("total warp")
				--sp.WarpMouse(unpack(mousePos[#specs]))
				sp.WarpMouse(pmx,pmy)
			else
				--local midX = curMouse[1]-(curMouse[1]-mousePos[#specs][1])/3
				--local midY = curMouse[2]-(curMouse[2]-mousePos[#specs][2])/3

				local midX = mx-(mx-pmx)/3
				local midY = my-(my-pmy)/3
				--Echo("little warp")
				sp.WarpMouse(midX,midY)
			end

			--sp.SetActiveCommand(activeCom) --renewing placement starting for graphical coherence

			--------
		end
		if backward then
			return true
		end
	end
	return false
end
-------------
--------
--------
--------
---


--------
--------
--------
--------
--[[local function pushAway(pos,tgt,dir)
	local x,z = unpack(pos)	

	local ix,iz
	if t(tgt[1])=="table" then --then this is a block of rectangles
		--ix,iz = table.sumxz(tgt,1,2) -- make an average center of the block, to define the direction of push away
		--ix,iz = ix/#tgt,iz/#tgt
		--table.insert(AVG,{ix,iz}) -- just to check the drawing on map
		local minMax=minMaxCoord(tgt)
		ix,iz = table.sumxz(minMax,1,2) -- make an average center of the block, to define the direction of push away
		ix,iz = ix/2,iz/2
		table.insert(AVG,{ix,iz}) -- just to check the drawing on map
	else
		ix,iz = tgt[1],tgt[2]
	end

	local iDir = GetDirection(ix,iz,x,z)
	if iDir.x==0 and iDir.z==0 then iDir.x=math.random() iDir.z=math.random() end
	local pointRect = {x,z,p.sizeX*2,p.sizeZ*2}
	local tries=0
	while Overlapping(pointRect,tgt) do
		tries=tries+1
		x = x+8*(iDir.x)
		z = z+8*(iDir.z)
		pointRect = {x,z,p.sizeX*2,p.sizeZ*2}
		if tries==100 then Echo("tried too much") break end
	end
	return x,z, tries>0
end--]]

-- Check if is it in radius of a specific building or the last in the list of placements or all placements (all=true), 
local function IsInRadius(x,z,radius,all,target)
	local radius=(E_RADIUS[PID]*2)^2
	if target then return radius>(x-target[1])^2 + (z-target[2])^2 end

	local start = #specs
	local End = all and 1 or start
	for i=start,End, -1 do --reverse loop to save some CPU, mostly used for checking previous placement,
						    -- it can become useful to check others in case of drawing placements backward
		target=specs[i]
		--Echo("(x-target[1])^2 + (z-target[2])^2, radius is ", (x-target[1])^2 + (z-target[2])^2, radius)
		if radius>(x-target[1])^2 + (z-target[2])^2 then return true end
	end
	return false
end



--judge.connectedGrids = function(self) Echo('TEST',self) end


local function AdaptForMex(radius,name) -- unused
	if not GetCloseMex then
		return
	end
	local max = math.max
	local mPos, mDist = closeMex[1],closeMex[2]
	local mPosx,mPosy,mPosz = mPos.x,mPos.y,mPos.z

	local scMexPosX,scMexPosY = sp.WorldToScreenCoords(mPosx,mPosy,mPosz)
	local scMexDist = (scMexPosX-mx)^2 + (scMexPosY-my)^2
	local mexDist =  (abs((pointX-mPosx)/16)^2+abs((pointZ-mPosz)/16)^2)
	approaching = prev.mexDist==mexDist and approaching or mexDist<prev.mexDist
	prev.mexDist = mexDist
	local mDirx,mDirz = scMexPosX-mx, scMexPosY-my
	local biggest =  max( abs(mDirx), abs(mDirz) )
	mDirx,mDirz = mDirx/biggest, mDirz/biggest

	if name~="energypylon" then

		-- help mouse to navigate through mex
		if  mexDist<15 and not inTable(forgetMex, {mPosx, mPosz}) then -- forgetting mex once we reached it
			table.insert(forgetMex, {mPosx, mPosz})
		end
		------- REFINE IT OR MAYBE NOT USE IT AT ALL
--[[		if approaching and scMexDist<1000  and not inTable(forgetMex, {mPosx, mPosz})  then
			sp.WarpMouse(mx+3*(mDirx),my+3*(mDirz))
			Echo('attracting')
		elseif not approaching and scMexDist<5 then
			Echo('repulsing')
			sp.WarpMouse(mx+3*(-mDirx)*scMexDist/1000,my+3*(-mDirz)*scMexDist/1000)
		end--]]
		---------
	end
	-- push point away from mex
	local sx,sz = p.sizeX*2,p.sizeZ*2
	while IsOverlap(mPosx,mPosz,24,24,pointX,pointZ,sx,sz) do
		pointX = pointX+16*(mDirx--[[+ampX--]])
		pointZ = pointZ+16*(mDirz--[[+ampZ--]])
	end	-------------------------------------------------------------------------
end
	--local ampX = (1-abs(mexDirection[1])/2)*plusMin(mexDirection[1])
	--local ampZ = (1-abs(mexDirection[2])/2)*plusMin(mexDirection[2])
	--local impede = curX<p.footX and curZ<p.footZ
-- local centerpoint,outpoint


local function AvoidMex(x,z)
	if not GetCloseMex then
		return
	end
	local mPos,mDist = closeMex[1],closeMex[2]
	local mPosx,mPosy,mPosz = mPos.x,mPos.y,mPos.z
    --Echo(" mex ", mPos.x,mPos.z)
	--Echo("cursor", x,z)
	local sx,sz = p.sizeX,p.sizeZ
	local mDirx,mDirz = mPosx-x, mPosz-z
	local biggest =  math.max( abs(mDirx), abs(mDirz) )
	mDirx,mDirz = mDirx/biggest, mDirz/biggest
	x = floor((x + 8 - p.oddX)/16)*16 + p.oddX
	z = floor((z + 8 - p.oddZ)/16)*16 + p.oddZ

	--while IsOverlap(mPosx,mPosz,24,24,x,z,sx,sz) do
	while ((x-mPosx)^2 < (sx+24)^2 and (z-mPosz)^2 < (sz+24)^2) do
		x = x+16*-mDirx
		z = z+16*-mDirz
		x = floor((x + 8 - p.oddX)/16)*16 + p.oddX
		z = floor((z + 8 - p.oddZ)/16)*16 + p.oddZ
	end
	sp.WarpMouse(Spring.WorldToScreenCoords(x,sp.GetGroundHeight(x,z),z))
	return x,z
end

local function FixBetween(x,z,connected)
	local fixed
	local unitx,unitz = connected[1], connected[2]
	local ud = UnitDefs[ connected[3] ]
	local laspx,laspz = unpack(specs[specs.n])
	local w,h = p.sizeX*2,p.sizeZ*2
	local unitw,unith = ud.xsize*8,ud.zsize*8

	x = floor((x + 8 - p.oddX)/16)*16 + p.oddX
	z = floor((z + 8 - p.oddZ)/16)*16 + p.oddZ
	--local distance = sqrt( (laspx-unitx)^2 + (laspz-unitz)^2 )
	 -- arranging the placement on connection, between last spec and spotted econ building
--Echo(abs(connected[1]-laspec[1]),abs(connected[2]-laspec[2]))
	--pointX = pointX + (connected[1]-laspec[1])/32--*ratio
	--pointX = floor((pointX + 8 - p.oddX)/16)*16 + p.oddX

	--Echo(Overlapping( {x1,z1,w1,h1}, {x2,z2,w1,h1} ), Overlapping( {x1,z1,w1,h1}, {x3,z3,w3,h3} ))
	if
		IsOverlap( x,z,w,h, laspx,laspz,w,h )
	or
	   	IsOverlap( x,z,w,h, unitx,unitz,unitw,unith )
	then
		--local ratio = (UnitDefs[PID].name=='energysolar' and 1.5 or 1) / (UnitDefs[connected[3]].name=='energysolar' and 1.5 or 1)
--[[	local tX = pointX + (connected[1]-laspec[1])
		local tZ = pointX + (connected[2]-laspec[2])--]]
		x = abs(unitx+laspx)/2
		z = abs(unitz+laspz)/2
--[[				Echo("pointX,tX is ", pointX,tX)
		Echo("pointZ,tZ is ", pointZ,tZ)--]]
		x = floor((pointX + 8 - p.oddX)/16)*16 + p.oddX
		z = floor((pointZ + 8 - p.oddZ)/16)*16 + p.oddZ
		fixed={x,z}
	end

	--pointZ = pointZ + (connected[2]-laspec[2])/32--*ratio
    --pointZ = floor((pointZ + 8 - p.oddZ)/16)*16 + p.oddZ

--[[				pointX = distance<(radius*2) and pointX + (connected[1]-laspec[1])/32 or
								   pointX + (connected[1]-laspec[1])/48
	pointZ = distance<(radius*2) and pointZ + (connected[2]-laspec[2])/32 or
								   pointZ + (connected[2]-laspec[2])/48--]]
    return fixed
end
-- NOT USED ANYMORE, USING Judge function instead
local judge = (function() -- TODO: can be bettered to finetune the space between placements
	local t={}
	return {
		['disconnected']=function(dist,x,z)
			return not IsInRadius(x,z,p.radius,true) and 'before'
		end,
		['connectGrids']=function(dist,x,z)
			local llasp=specs[specs.n-1]
			if llasp and IsInRadius(x,z,p.radius,nil,llasp) then
				return 'replace'
			else
				return true
			end
		end,
		['out and in']=function(dist,x,z)
			local lasp=specs[specs.n]
			if lasp and not IsInRadius(x,z,p.radius,nil,lasp) then
				return 'out and in'
			else
				return true
			end
		end,
		['connect']=function(dist,x,z)
			local lasp=specs[specs.n]
			if status=='onGrid' and lasp and specs.n>1 and (lasp[1]-x)^2 < (p.sizeX*2)^2 and (lasp[2]-z)^2 < (p.sizeZ*2)^2 then return 'replace' end
			return not IsInRadius(x,z,p.radius,true) and 'before' or true
		end,
		['onGrid']=function(dist,x,z)
		local lasp=specs[specs.n]
		local llasp=specs[specs.n-1]
			if lasp.status=='connect' and IsInRadius(x,z,p.radius,nil,llasp) and not TestBuild(x,z,p,not WG.PBHisListening,placed,overlapped)
				then status='connect'
				return 'replace'
			else
				return false
			end
		end,
		['onLinkedGrid']=function(dist,x,z)
			return false
		end,
		['out']=function(dist,x,z)
			return not IsInRadius(x,z,p.radius,true) and 'before'
		end,
	}
end)()

local function UpdateMexes(px,pz,remove,at,virtual,irail)
	local IsMexOnSpot = sp.GetUnitsInRectangle
	local spotsPos=WG.metalSpotsByPos or EMPTY_TABLE
	local spots=WG.metalSpots or EMPTY_TABLE
	local rad = E_RADIUS[PID]
	if virtual then previMex = {} end
	for x,t in pairs(spotsPos) do
		for z,n in pairs(t) do
			local spot = spots[n]
			local dist = (px-x)^2 + (pz-z)^2
			-- if dist<(rad+49)^2  and not IsMexOnSpot(x,z,x,z)[1] then -- check if the virtual mex is in my range then
			if dist<(rad+49)^2  and IsMexable(spot) then -- check if the virtual mex is in my range then
				-- adding mex to place by the way
				if virtual then
					previMex[#previMex+1]={x,z}
				elseif remove then
					if mexes[at] --[[and not preGame--]]  then
						local imexes = mexes[at]
						for i=1,#imexes do cantMex[GetCloseMex(imexes[i][1],imexes[i][2])]=nil allGrids['m'..spotsPos[imexes[i][1]][imexes[i][2]]]=nil	end
						mexes[at]=nil
					end
				elseif not cantMex[spot] then
					if not mexes[at] then	mexes[at]={{x,z}}
					else local imexes = mexes[at]; imexes[#imexes+1]={x,z}
					end
					if irail then
						irail.mex = true
						irail.color = color.yellow
					end
					allGrids['m'..spotsPos[x][z]]=true
					cantMex[spot]=true
				end
				--
			end
		end
	end

end

local function CheckConnections(px,pz,previousCo) 
	--determine the grids of empty mexes in range if those mexes were built
	--see if different grids would actually be the same if the mex were built
	-- then decide accordingly to pose or not, comparing to previous connections
	-- localize globals to repeat call faster
	-- check also home made grid of ordered building and grid of existing unit, linking those who should be considered the same


	local GetUnitsInRange,			IsMexOnSpot,				GetPos,				GetDefID,			GetParam
	 = sp.GetUnitsInCylinder, sp.GetUnitsInRectangle, Spring.GetUnitPosition, sp.GetUnitDefID, Spring.GetUnitRulesParam
	local uds = UnitDefs
	local spotsPos=WG.metalSpotsByPos or EMPTY_TABLE
	local spots=WG.metalSpots or EMPTY_TABLE
	--
	local rad,mexrad = E_RADIUS[PID],E_RADIUS[mexDefID] -- ranges of our own econ building and mex for connection check

	--
	local connected
	local grids={} -- the current connections we gonna find
	local cm,cu,cp
	local huge = math.huge
	local cmdist,cudist,cpdist = huge, huge, huge
	--we add the units around cursor and detect if any real new grid is found or if it's linked to a virtualmex

	local newunits=GetUnitsInRange(px,pz,MAX_REACH+rad)-- the maximum reach (singu or fusion:150, pylon:500) + own rad 
	
	for i=1,#newunits do
		local id = newunits[i]
		if opt.connectWithAllied and sp.IsUnitAllied(id)
		or myTeamID==sp.GetUnitTeam(id)
		then -- TO TRY: try with allied unit too
			local idefid = GetDefID(id)
			local irad = E_RADIUS[idefid]
			if irad then
				local ix,iy,iz = GetPos(id)
				local def = uds[idefid]
				local isx,isz = def.xsize*4,def.zsize*4
				-- distance cursor->econ building and get it's grid
				local dist = (px-ix)^2 + (pz-iz)^2
				if dist < (irad+rad)^2 then
					--overlapped[#overlapped+1]={ix,iz,idefid}
					if dist<cudist then cu,cudist={ix,iz,isx,isz,dist},dist end
					local ugrid = GetParam(id,'gridNumber')
					--if idefid==mexDefID and grid==1 then grid = 'm'..spotsPos[ix][iz]  --[[Echo('-> grid', grid)--]] end
					if ugrid then
						grids[ugrid]=grids[ugrid] or {}
						-- REAL UNIT TO EMPTY MEX
						for x,t in pairs(spotsPos) do
							for z,n in pairs(t) do
								local spot = spots[n]
								if (ix-x)^2 + (iz-z)^2 < (irad+49)^2  and not IsMexOnSpot(x,z,x,z)[1] then -- check if the virtual mex is in my range then
									local mgrid = 'm'..n
									grids[mgrid]=grids[mgrid] or {}
									grids[ugrid][mgrid]=true
									grids[mgrid][ugrid]=true
								end
							end
						end
					end
				end
			end
		end
	end
	-- associate different grids linked by empty mex
--[[	for grid, links in pairs(grids) do
		if tostring(grid):match('m') then -- it's a unit grid
			for link1 in pairs(links) do
				for link2 in pairs(links) do if link2~=link1 then grids[link1][link2]=true end end
			end
		end
	end--]]
	--
	-- Now we check mexes around our cursor
	for x,t in pairs(spotsPos) do
		for z,n in pairs(t) do
			local spot = spots[n]
			local dist = ((px-x)^2 + (pz-z)^2)^0.5
			-- Echo("dist is ", dist)
			if dist<(rad+49)  and not IsMexOnSpot(x,z,x,z)[1] then -- check if the virtual mex is in my range then
				local mgrid = 'm'..n
				-- Echo('GOT ',n,dist)
				grids[mgrid]=grids[mgrid] or {}
				if dist<cmdist then cm,cmdist={x,z,24,24,dist},dist end
				-- adding mex to place by the way
--[[				if not cantMex[spot] then
					local n = specs.n==1 and 1 or specs.n+1
					if not mexes[n] then	mexes[n]={{x,z}}
					else local mexes = mexes[n]; mexes[#mexes+1]={x,z}
					end
					cantMex[spot]=true
				end--]]
				--
				local newunits=GetUnitsInRange(x,z,150+mexrad)-- the maximum reach (singu or fusion) + mex rad
				-- EMPTY MEX TO REAL UNIT
				for i=1,#newunits do
					local id = newunits[i]
					if sp.GetMyTeamID()==sp.GetUnitTeam(id) then
						local irad = E_RADIUS[GetDefID(id)]
						if irad then
							local ix,iy,iz = GetPos(id)
							if ( (x-ix)^2 + (z-iz)^2 ) < (irad+mexrad)^2 then-- distance mex->econ and get it's grid
								local ugrid = GetParam(id,'gridNumber')
								if ugrid then
									grids[ugrid]=grids[ugrid] or {}
									grids[ugrid][mgrid]=true
									grids[mgrid][ugrid]=true
								end
							end
						end
					end
				end
			end
		end
	end
	-- consider grid of placed buildings
	for i=1,#placed do
		local place=placed[i]
		local ix,iz = place[1],place[2]
		local irad=place.radius
		if irad then
			local dist = (px-ix)^2 + (pz-iz)^2
			if dist < (irad+rad)^2 then
				if dist<cpdist then cp,cpdist={ix,iz,place[3],place[4],dist},dist end
				local pgrid = place.grid or -1
				grids[pgrid]=grids[pgrid] or {}
				connected=true
				-- PLACEMENT TO REAL UNIT
				local newunits=GetUnitsInRange(ix,iz,MAX_REACH+irad)
				for i=1,#newunits do
					local id = newunits[i]
					local urad = E_RADIUS[GetDefID(id)]
					if urad then
						local ux,uy,uz = GetPos(id)
						if ( (ix-ux)^2 + (iz-uz)^2 ) < (irad+urad)^2 then-- distance placement->real eBuild and get it's grid
							local ugrid = GetParam(id,'gridNumber')
							if ugrid then 
								grids[ugrid]=grids[ugrid] or {}
								grids[ugrid][pgrid]=true
								grids[pgrid][ugrid]=true
							end
						end
					end
				end
				--
				-- check if there's a close empty mex near the placement

				for x,t in pairs(spotsPos) do
					for z,n in pairs(t) do
						local spot = spots[n]
						if (ix-x)^2 + (iz-z)^2 < (irad+49)^2  and not IsMexOnSpot(x,z,x,z)[1] then -- check if the virtual mex is in my range then
							local mgrid = 'm'..n
							grids[mgrid]=grids[mgrid] or {}
							grids[pgrid][mgrid]=true
							grids[mgrid][pgrid]=true
						end
					end
				end
				--
			end
		end
	end
	-- consider drawn projected current placements as grid, discarding the 3 last placements behind cursor
	local last = #specs-3
	if last>0 then
		--local irad=p.radius
		local irad = E_RADIUS[PID]
		local sx,sz = p.sizeX,p.sizeZ
		for i=1,last do 
			local place=specs[i]
			local ix,iz = place[1],place[2]
			local dist = (px-ix)^2 + (pz-iz)^2
			if dist < (irad+rad)^2 then
				if dist<cpdist then cp,cpdist={ix,iz,sx,sz,dist},dist end
				local pgrid = 's'
				grids[pgrid]=grids[pgrid] or {}
				connected=true
				break
			end
		end
	end




	-- we associate grids connected to each others -- FIXME: this doesnt detect a placement that is connected but not under the cursor radius, but we still can do our job
	for grid, links in pairs(grids) do
		for link1 in pairs(links) do
			for link2 in pairs(links) do if link2~=link1 then grids[link1][link2]=true end end
		end
	end

	local n=0
	local connect={}


	-- we discernate the real separate grids, register the newly connected grids
	local connectedTo = previousCo  or connectedTo
	for grid,links in pairs(grids) do

		if not links.done then
			n=n+1
			
			local isNew = not connectedTo[grid]
			for link in pairs(links) do
				if isNew then isNew=not connectedTo[link] end
				grids[link].done=true
			end
			if isNew then 
				connect[grid]=true
			end
			links.done=true
		end
		links.done=nil
	end
	for grid,links in pairs(grids) do links.done=nil end
	-- register if we get out of a grid

	local out={}
	for grid,links in pairs(connectedTo) do
		if not grids[grid] and not connectedTo[grid].done then
			out[grid]=true
			for link in pairs(links) do
				--Echo('link:', link)
				connectedTo[link].done=true
			end
		end
		links.done = true
	end
	for grid,links in pairs(connectedTo) do links.done=nil end
--if cu then overlapped[#overlapped+1]=cu end
	-- local function keysunpack(t,k)
	-- 	local k = next(t,k)
	-- 	if k then return k,keysunpack(t,k) end
	-- end

--[[	for grid,linkedTo in pairs(grids) do
		Echo('grid: '..grid..' |', keysunpack(linkedTo))
		--for link in pairs(linkedTo) do Echo('('..link..')') end
	end--]]
	-- finally we find out if there is any new grid to connect


--Echo("n is ", n,connect)
--[[	if n>0 then
		for grid in pairs(grids) do linked[grid]=true end
		--CompareGrids(connectedTo,grids,linked,px,pz)
		--connectedTo=grids
	else
		linked={}
	end--]]
	--Echo("connect,out is ", connect,out)

	return n,connect,out,grids
end

local function keysunpack(t,k)
	local k = next(t,k)
	if k then return k,keysunpack(t,k) end
end

local function copy(t)
	local T={}
	for k,v in pairs(t) do
		T[k]=v
	end
	return T
end

local function Link(grids)
	local T={}
	for g1,links in pairs(grids) do
		T[g1]={}
		for g2 in pairs(grids) do
			if g1~=g2 then T[g1][g2]=true end
		end
	end
	return T
end


local function Judge(rx,rz,sx,sz,lasp,llasp,PBH,irail,lastRail)
	-- FIXME: the grid system need to be bettered: make it so that we can know all grids we're connected to
--Page(connectedTo)
	--local isPylon = PID == UnitDefNames["energypylon"].id
	local spots = WG.metalSpots
	local radius = p.radius
	local n,newgrids,outgrids,grids = CheckConnections(rx,rz)
	--newgrids and outgrids register the connections and disconnections to current point from last point
	local n_new = l(newgrids)
	local connectToSelf
	if n_new == 1 and newgrids.s then
		connectToSelf = true
	end
	
	local overlapLasp = lasp and (abs(lasp[1]-rx)<sx*2 and abs(lasp[2]-rz)<sz*2)
	-- Echo("overlapLasp is ", overlapLasp,abs(lasp[1]-rx),sx,'|',abs(lasp[2]-rz),sz)
	local cantPlace,blockingStruct,_,overlapPlacement = TestBuild(rx,rz,p,true,placed,overlapped,specs)
	local tooSteep = cantPlace and not blockingStruct
	local hasRealOverlap = cantPlace and blockingStruct
	irail.tooSteep = tooSteep
	irail.overlapPlacement = not not overlapPlacement -- transform into bool
	-- Echo("overlapPlacement is ", overlapPlacement)
	local overlapOnlyLasp = not hasRealOverlap and overlapLasp and overlapPlacement and not overlapPlacement[2]

	local inRadius = lasp and IsInRadius(rx,rz,radius,true)
	local inRadiusOfLasp = lasp and IsInRadius(rx,rz,radius,nil,lasp)
	-- local inRadiusOfConnected = lasp and IsInRadius(rx,rz,radius,nil,lasp)
	local inRadiusOfLlasp = llasp and IsInRadius(rx,rz,radius,nil,llasp)
	--local canReplaceLasp = llasp and IsInRadius(rx,rz,radius*2,nil,llasp)
	local overlapLast = lasp and (lasp[1]-rx)^2 < (sx*2)^2 and (lasp[2]-rz)^2 < (sz*2)^2
	local status = lasp and lasp.status or rail[1].status
	-- Can we move the lasp (last placement) on that new rail point
	local canMoveConnection = inRadiusOfLlasp and (not tooSteep or lasp.tooSteep or PID == pylonDefID)
	-- Echo("canMoveConnection is ", canMoveConnection, 'lasp too steep', lasp.tooSteep,'inRadiusOfLlasp',inRadiusOfLlasp)
	-- check if we loose a connection if we replace the lasp by the current
	local debug = Debug.judge()

	if canMoveConnection then
		for k in pairs(lasp.newgrids) do
			if not grids[k]  then
				if k~='s' then
					canMoveConnection=false
					if debug then
						Echo('loosing',k, 'if replace',os.clock())
					end
				end
			end
		end
	end
	-- check the real new connections we can make
	local realnewgrids, n_realnew = {},0
	for k in pairs(newgrids) do
		if not allGrids[k] and k~='s' then
			realnewgrids[k]=true n_realnew=n_realnew+1
		end
	end


	if status == 'out' then
		if n_new>0 then status = 'connect' end
	elseif status == 'connect' then
		if n==0 then status = 'disconnect'
		elseif n_new==0 then status = 'onGrid'
		end
	elseif status=='disconnect' then 
		if n==0 then status='out'
		elseif n_new>0 then status = 'connect'
		end
	elseif status == 'onGrid' then
		if n==0 then status = 'disconnect'
		elseif n_new>0 then status = 'connect'
		end
	end

	local pose
	local reason
	if debug then

		Echo(
			'status: '..status
			,'ngrids:'..n
			,(next(newgrids) and 'news: ' ..table.concat({keysunpack(newgrids)},'-')..', ' or '')
			 ..(connectToSelf and 'connectToSelf, ' or '')
			 .. (tooSteep and 'tooSteep, ' or '')
			 ..(canMoveConnection and 'Can Move, ' or '')
		)
	end

	local pushBackR
	if status == 'onGrid' then
		for g,v in pairs(grids) do
			if string.find(g, 'm') then
				local n = tonumber(string.match(g,'%d+'))
				local at = specs.n
				if not cantMex[spots[n]] then
					UpdateMexes(rx,rz,nil,at)
				end
			end
		end
		--
		-- move the placement further away as long as the loosing connections of current are hold by the last placement
		if canMoveConnection and not hasRealOverlap and (not overlapPlacement or overlapOnlyLasp) then
			pose = 'replace'
			reason = 'can move up connection'
		elseif not pose and tooSteep then
			if lastRail and PID ~= pylonDefID and not (lastRail.overlapPlacement or lastRail.tooSteep) then
				pose = 'before'
				reason = 'before because too steep'
			end
		end
	elseif status == 'connect' then

		-- case of reaching a connection but this step make us loose the previous connection
		if (not lasp or --[[not lasp.status=='onGrid' or--]] lasp.status=='disconnect') and not inRadius then
			pose='before'
			reason = 'before to not get out of own radius'
		elseif connectToSelf and overlapPlacement then
			pose='before'
			reason = 'connecting to self queue before stepping on placement'
		elseif overlapOnlyLasp then
			if canMoveConnection then
				reason = 'can move up connection'
				pose ='replace'
			elseif PID ~= pylonDefID then
				local r = lasp and lasp.r - 1
				local pushable = r and rail[r] and rail[r].posable and rail[r]
				while pushable do
					local stillOverlap = (rx - pushable[1])^2 < (sx*2)^2 and (pushable[3]-rz)^2 < (sz*2)^2
					if not stillOverlap then
						-- pushed back enough
						break
					end
					r = r - 1
					pushable = r and rail[r] and rail[r].posable and rail[r]
				end
				if pushable then
					pose = 'pushback'
					pushBackR = r
					reason = 'pushing back last placement to pose self in order to connect'
				end
			end
		elseif not overlapPlacement then
			if canMoveConnection then
				reason = 'can move up connection'
				pose ='replace'
			elseif not overlapLast then
				if inRadius then
					reason = 'pose now to connect'
					pose = true
				else
					reason = 'pose before to not lose self connection'
					pose = 'before'
				end
			end
		end
	elseif status == 'out' then
		if --[[not hasRealOverlap and--]] not inRadiusOfLasp and not hasRealOverlap then 
			-- keep our connection with our last spec
			reason = 'need to pose before losing connection with lasp'
			pose = 'before'

		elseif tooSteep then
			-- avoid steepness if we can
			if lastRail and PID~=pylonDefID and not (lastRail.overlapPlacement or lastRail.tooSteep) then
				reason = 'pose before to avoid steepness'
				pose = 'before'
			end
		elseif not hasRealOverlap then
			-- pose on last cursor pos even if not connecting/disconnecting
			if not overlapPlacement then
				reason = 'out of grid and can pose now'
				pose= true
			elseif inRadiusOfLlasp and overlapOnlyLasp then
				reason = 'can move up placement'
				pose = 'replace'
			end
		end
		
	elseif status == 'disconnect' then
		pose = --[[not hasRealOverlap and --]]not inRadius and 'before'
		if not inRadius then
			reason = 'not in radius, pose before'
			pos = 'before'
		else
			if tooSteep then
				if lastRail and not (lastRail.overlapPlacement or lastRail.tooSteep) then
					reason = 'pose before to avoid steepness'
					pose = 'before'
				end
			elseif not hasRealOverlap then
			-- pose on last cursor pos even if not connecting/disconnecting
				if not overlapPlacement then
					reason = 'can pose now'
					pose= true
				-- elseif inRadiusOfLlasp then
				-- 	pose = 'replace'
				end
			end
		end
	end
	if pose=='replace' then
		-- status=lasp.status
		for k,v in pairs(lasp.newgrids) do newgrids[k]=true end
	end

	if pose then
		if debug then
			-- Echo(pose and "pose:"..(pose==true and "normal" or pose) or "",lasp and lasp.status,'=>'..status,'canMoveConnection:'..(canMoveConnection and 'yes' or 'no'),os.clock())
			Echo('POSE ' .. tostring(lasp.status)..'=>'..status,reason)
		end
	end

	return pose, grids, status, newgrids, pushBackR
end




local function PoseSpecialOnRail()
	--Echo("specs.n,#specs is ", specs.n,#specs)
	local mingap = math.min(p.footX,p.footZ) -- TODO: BETTER
	local n = #specs
	local lasp = specs[n]
	local llasp = specs[n-1]
	local railLength = rail.n
	local oddx,oddz = p.oddX,p.oddZ
	local sx,sz = p.sizeX,p.sizeZ
	local rx,rz

	local r = lasp and lasp.r or 1


	local a=rail.processed
	rx,rz = rail[a].rx, rail[a].rz
	if lasp and lasp.grids then connectedTo=lasp.grids end


	--Echo('complete from=>> :'..a..' gap: '..a-r..'('..mingap..')')

	--laspx,_,laspz = sp.ClosestBuildPos(0,PID, laspx, 0, laspz, 1000,0,p.facing)

	local pose,grids,status,newgrids
	local lastRail = rail[a]
	--Echo('run Posing at', a+1)
	
	while a<railLength do
		a=a+1
		local gap = a-r
		local irail = rail[a]
		rx,rz = irail.rx,irail.rz
		irail.specOverlap = lasp and (lasp[1]-rx)^2 < (sx*2)^2 and (lasp[2]-rz)^2 < (sz*2)^2
		irail.done = true
		local pushBackR
		if not pose then 
			pose,grids,status,newgrids, pushBackR = Judge(rx,rz,sx,sz,lasp,llasp,PBH,irail,lastRail)
		end

		if status == 'connect' then
			irail.color = color.teal
		elseif status == 'disconnect' then
			irail.color = color.purple
		end
		if pose then
			if pose == 'pushback' and pushBackR then
				Debug.judge('can push back to R', pushBackR)
				-- push back the last posed until we can place
				local pushed = rail[pushBackR]
				lasp[1], lasp[2] = pushed[1], pushed[3]
				pose = true
			end
			r = a
			if pose~='replace' then
				n = n + 1
			end

			if pose=='before' and lastRail then
				if not (lasp and (lasp[1]-lastRail.rx)^2 < (sx*2)^2 and (lasp[2]-lastRail.rz)^2 < (sz*2)^2) then
					irail = lastRail
					rx = lastRail.rx
					rz = lastRail.rz
					r=r-1
					irail.overlapPlacement = true

					-- irail.color = color.purple
					_,grids,status,newgrids, canMex = Judge(rx,rz,sx,sz,lasp,llasp,PBH,irail)
				else
					pose = false
					n = n - 1
					Debug.judge('placement refused at ',lastRail.rx,lastRail.rz)
				end
			end

				--Echo('pose',r-1)

--[[				if pose=='push back and pose' and a>3 then
					Echo('check')
					local tries=0
					while lasp and (lasp[1]-rx)^2 < (sx*2)^2 and (lasp[2]-rz)^2 < (sz*2)^2 and lasp.r > 3 and tries<10 do
						tries = tries+1
						local backr = lasp.r-1
						lasp[1],lasp[2],lasp.r = rail[backr][1], rail[backr][3], backr
						Echo('pushed back to ', backr)
						if tries==10 then Echo('too many tries') end
					end
				end--]]
			if pose then
				-- Echo('new pose',n,pose)
				if pose=='replace' then
					UpdateMexes(lasp[1],lasp[2],'remove',n)
				end
				irail.posable = true
				irail.color = irail.color or color.orange
				local grids = Link(grids)
				specs[n]={rx,rz, r=r,n=n, status=status, grids=grids,newgrids=newgrids, tooSteep=irail.tooSteep}
				connectedTo=grids
				-- allGrids = {}
				UpdateMexes(rx,rz,nil,n,false,irail)
				for g in pairs(grids) do
					allGrids[g] = true
				end
				-- for i=1,n do
				-- 	for k in pairs(specs[i].grids) do
				-- 		allGrids[k]=true 
				-- 	end
				-- end

					--Echo('pose',r)

				llasp=pose=='replace' and llasp or lasp
				lasp=specs[n]

				---connectedTo = Link(grids)
				pose= false

			end

		end
		lastRail=irail
	end
	rail.processed = railLength
	specs.n = n
	return
end


local function PoseOnRail()
	--Echo("specs.n
	local mingap = math.min(p.footX,p.footZ)+p.spacing -- TODO: BETTER

	local n = #specs
	local laspec = specs[n]
	local railLength = rail.n


	local r=laspec and laspec.r or 0
	local a=rail.processed
	--laspx,_,laspz = sp.ClosestBuildPos(0,PID, laspx, 0, laspz, 1000,0,p.facing)
	local sx,sz,oddx,oddz,facing = p.sizeX,p.sizeZ,p.oddX,p.oddZ,p.facing
	local rx,rz
	while a<railLength do
		a=a+1
		local gap = a-r
		local posable = gap>=mingap -- the minimum before caring to verify
		if posable then
			rx,_,rz=unpack(rail[a])
			rx = floor((rx + 8 - oddx)/16)*16 + oddx
			rz = floor((rz + 8 - oddz)/16)*16 + oddz

			local overlap,_,_,overlapPlacement = TestBuild(rx,rz,p,not PBH,placed,overlapped,specs)
			if not overlap and not overlapPlacement then
				r = a
				n=n+1
					--n=n+1
				specs[n]={rx,rz, r=r, n=n}
				-- laspx,laspz = rx,rz
			end
		end
	end
	rail.processed = rail.n
	specs.n = n
	return
end

-- Paint Function
do
	local min,max,abs,huge = math.min,math.max,math.abs,math.huge
	local GetGround = Spring.GetGroundHeight
	local coordsMemory = {}
	local SpiralSquare = f.SpiralSquare
	local poses,currentBarred, extraBarred,blockingStruct
	local method
	local rx,ry,rz,sx,sz, oddx,oddz
	local facing
	local scale
	local layers
	local max_possible

	----
	local edges = {}
	local debugEdges = false
	local fx,fz
	----
	local debug = false
	local debugMethods = false
	local solarDefID = UnitDefNames['energysolar'].id
	local windDefID = UnitDefNames['energywind'].id
	local firstTime = true
	local firstPose = false
	local useNeat
	local MarkEdge = function(layer,offx,offz)
		local x, z = fx + offx, fz + offz
		edges[x] = edges[x] or {}
		edges[x][z] = true
		if debugEdges then
			Points[#Points+1] = {x,sp.GetGroundHeight(x,z),z,color = color.red,txt='o'}
		end
	end
	local cnt, colcnt = 0, 0
	local function Bar(x,z,sx,sz,offx,offz,permanent,extra)
		local score = 0
		if permanent then -- permanent is barring existing or placed structures
			for x=x-sx+offx,x+sx,16 do
				coordsMemory[x] = coordsMemory[x] or {}
				for z=z-sz+offz,z+sz,16 do
					coordsMemory[x][z] = true
				end
			end
			return score
		end

		----- WIP: do circle instead of square ?
			local maxx, maxz = x+sx, z+sz
			local minx, minz = x-sx, z-sz
			-- local midx, midz = minx + (maxx-minx)/2, minz + (maxz-minz)/2
			-- local maxlen = (maxx-minx)/2 -- since we use only square for now -- TODO: implement rectangle
		-----
		------ WIP
		local edge
		------
		for x=x-sx,x+sx,16 do -- temporary barring our current projected placements
			for z=z-sz,z+sz,16 do
				if debug or debugEdges then
					edge = x==minx or x==maxx or z==minz or z==maxz
				end
				----- WIP
					--- circle?
					-- local fromEdge = ((x-midx)^2 + (z-midz)^2)^0.5 - maxlen
					-- local out = fromEdge >=16
					-- local edge = fromEdge >= 0 and not out
					---
				-----
				if tryEdges and not neatFarm then
					score = score + (edges[x] and edges[x][z] and 1 or 0)
				end
				if not (coordsMemory[x] and coordsMemory[x][z])
				and not (currentBarred[x] and currentBarred[x][z])
				then
					---- WIP
					-- if not out then
					----
						if not extra then
							currentBarred[x] = currentBarred[x] or {}
							currentBarred[x][z] = edge and 'e' or true
							if edge and (debug or debugEdges)--[[ and (x-minx)%(sx/4) == 0 and (z-minz)%(sz/4) == 0--]] then
								local num = #Points+1
								local txt = num -- round(num/10)
								Points[num] = {x, sp.GetGroundHeight(x,z), z, color = color.yellow, txt = 'x'}
							end
						elseif not (extraBarred[x] and extraBarred[x][z]) then
							extraBarred[x] = extraBarred[x] or {}
							extraBarred[x][z] = edge and 'e' or true
							-- if edge and (debug or debugEdges) and (x%160==0 or z%160==0) then
							-- 	Points[#Points+1] = {x, sp.GetGroundHeight(x,z), z, color = color.yellow}
							-- end

							-- Points[#Points+1] = {x, sp.GetGroundHeight(x,z), z, color = color.white}

						end
					---- WIP
					-- end
					----
				end
				-- edge = x==minx or x==maxx or z==maxz
			end
		end
		return score
	end
	local function UpdateMem(barred) -- we put the temporarily blocked into permanent
		for x,col in pairs(barred) do
			if not coordsMemory[x] then -- directly take the currentBarred column
				coordsMemory[x] = col
				-- if debug or debugEdges then
				-- 	for z, v in pairs(col) do
				-- 		if v=='e'then
				-- 			Points[#Points+1] = {x,sp.GetGroundHeight(x,z),z,color = v=='e' and color.red or color.yellow,txt='x'}
				-- 		end
				-- 		-- Points[#Points+1] = {x,sp.GetGroundHeight(x,z),z,color = v=='e' and color.red or color.yellow,txt='x'}
				-- 	end
				-- end
			else
				for z, v in pairs(col) do
					-- if debug or debugEdges then
					-- 	for z, v in pairs(col) do
					-- 		if v=='e'then
					-- 			Points[#Points+1] = {x,sp.GetGroundHeight(x,z),z,color = v=='e' and color.red or color.yellow,txt='x'}
					-- 		end
					-- 		-- Points[#Points+1] = {x,sp.GetGroundHeight(x,z),z,color = v=='e' and color.red or color.yellow,txt='x'}
					-- 	end
					-- end
					coordsMemory[x][z]=v
				end
			end
		end

		-- for x,col in pairs(barred) do
		-- 	for z in pairs(col) do
				
		-- 	end
		-- end
	end
	local function GetSeparation(t) -- add every separations between each poses of t
		local sep=0
		local p = t[1]
		local lastx,lastz = p[1], p[2]
		for i=1+1,t.n do
			p = t[i]
			if not p.extra then
				local x,z = p[1],p[2]
				sep = sep + ((lastx-x)^2+(lastz-z)^2)^0.5
				lastx,lastz = x,z
			end
		end
		return sep
	end
	local function SepOnExisting(t,ex)
		local sep = 0
		local n_ex = #ex
		for i=1,t.n do
			local tx,tz = t[i][1], t[i][2]
			for j=1, n_ex do
				sep = sep + ((tx-ex[j][1])^2 + (tz-ex[j][2])^2)^0.5
			end
		end
		return sep
	end
	local BarPlaced = function()
		for i, b in ipairs(placed) do
			local bx,bz = b[1],b[2]

			local bsx,bsz = b[3],b[4]
			local oddBx,oddBz = bsx%16,bsz%16
			local offx, offz = oddBx==oddx and 0 or oddx-oddBx, oddBz==oddz and 0 or oddz-oddBz
			-- Echo(UnitDefs[b.defID].name,'master',oddx,"oddBx", oddBx,'=>',offx)
			Bar(
				 bx
				,bz
				,bsx+sx-16
				,bsz+sz-16
				,0,0
				,'permanent'
			)
		end

	end

	local spTestBuildOrder = Spring.TestBuildOrder
	local FindPose = function(layer,offx,offz)
		local x = rx + offx
		local z = rz + offz
		-- Points[#Points+1] = {x,sp.GetGroundHeight(x,z),z,color = v=='e' and color.red or color.blue,txt='-'}
		local extra = layer>layers
		-- Echo("layer,layers is ", layer,layers)
		local onEdge
		if not (coordsMemory[x] and coordsMemory[x][z])
		and not (currentBarred[x] and currentBarred[x][z])
		and not (extra and extraBarred[x] and extraBarred[x][z])
		-- and InMapBounding(x,z)
		then 
			if (debug or debugEdges) and not extra and ceil(layer)==layers then
				if method ~= 3 then
					Points[#Points+1] = {x,sp.GetGroundHeight(x,z),z,color = color.yellow}
				end
			end
			-- Points[#Points+1]={x,GetGround(x,z),z,txt=extra and 'ex' or 'm'..poses.method}
			-- 'remember' will tell TestBuild to memorize coords that resulted in overlapping and return the sets of overlapped rects
			local cantPlace = spTestBuildOrder(PID, x, 0, z, facing) == 0
			if cantPlace then
				-- we bar just that position permanently
				-- Bar(x,z,0,0,0,0,'permanent')
				coordsMemory[x] = coordsMemory[x] or {}
				coordsMemory[x][z] = true
			else -- we found a good spot, we bar it and all around, temporarily
				local add = {x,z, r=a,extra=extra}
				add.score = Bar(x,z,(sx+scale*8)*2-16,(sz+scale*8)*2-16,false,false,false,extra) -- extra is extra check farther than normal, in case we got more there
				local dist = ((x-rx)^2 + (z-rz)^2)^0.5
				poses.n=poses.n+1
				poses[poses.n]=add
				poses.dist=poses.dist+dist
				-- if poses.method==2 then
				-- 	Echo("poses.n is ", poses.n)
				-- end
			end
		end
	end

	local function ExecuteMethod(method,layers,step,offset,reversed,findings,bestAtMax)
		poses = {n=0,dist=0,barred={},reversed=reversed,method=method,sep=0,score = 0}
	
		currentBarred = poses.barred
		extraBarred = {}
		SpiralSquare(layers,step,FindPose,offset,reversed)
		local real_n = 0
		for i=1,poses.n do
			local p = poses[i]
			if not p.extra then
				real_n=real_n+1
				poses.score = poses.score + p.score
				-- if reversed then
				-- 	Points[#Points+1] = {p[1],sp.GetGroundHeight(p[1],p[2]), p[2]}
				-- end
			end
		end
		poses.real_n = real_n
		if real_n == 0 then
			-- if debugMethods then
			-- 	Echo('Method #'..method.. ' found 0 poses')
			-- end
			return
		end

		table.insert(findings,poses)
		local isBest = bestAtMax and real_n == max_possible 
		if isBest then
			if debugMethods then
				Echo('Method #'..method.. ' found ideal poses: '..real_n..'.')
			end
		elseif real_n > 1 then
			poses.sep = GetSeparation(poses)
			-- if blockingStruct then
			-- 	poses.sep = poses.sep + SepOnExisting(poses,blockingStruct)
			-- end
			if debugMethods then
				Echo('Method #'..method.. ' found '.. poses.n .. ' (real: '..real_n..')' .. ' poses, dist: '..poses.dist..(poses.n>1 and ', sep: '..poses.sep or '').. '.')
			end
		end
		return poses, isBest
	end


	Paint = function(reset)
		--Echo("specs.n,#specs is ", specs.n,#specs)
		if reset then 
			for k,v in pairs(coordsMemory) do 
				coordsMemory[k]=nil
			end
			for k in pairs(edges) do
				edges[k]=nil
			end
			firstTime = true
			useNeat = false
			return
		end

		debugMethods = Debug.paintMethods()
		if tryEdges and not useNeat then
			debugEdges = Debug.edges()
			debug = false
		else
			debugEdges = false
			debug = Debug.paint()
		end


		sx,sz,oddx,oddz,facing = p.sizeX,p.sizeZ,p.oddX,p.oddZ,p.facing
		scale = farm_scale -- it should be better called 'spread' but ...

		local mingap = min(sx+scale*8,sz+scale*8) 
		local flexible = scale> 4


		local n = #specs
		local laspec = specs[n]
		local railLength = rail.n


		local r=laspec and laspec.r
		local lasR = rail[r]
		local a=rail.processed
		--laspx,_,laspz = sp.ClosestBuildPos(0,PID, laspx, 0, laspz, 1000,0,p.facing)
		local lasRx,lasRy,lasRz
		local offposeX, offposeZ
		if lasR and lasR.rpose then 
			lasRx,lasRy,lasRz = unpack(lasR.rpose)
			if useNeat then
				local Prx = floor((lasRx + mingap )/(mingap*2)) * (mingap*2) -- - offposeX
				local Prz = floor((lasRz + mingap )/(mingap*2)) * (mingap*2)  -- - offposeZ
				offposeX = lasRx - Prx
				offposeZ = lasRz - Prz
				-- Points[#Points+1]={Prx,ry,Prz,color = color.yellow}
			end
		end

		if firstTime then
			BarPlaced()
			firstTime = false
			firstPose = false
			useNeat = neatFarm or PID == solarDefID and scale >1 or PID == windDefID and scale > 1
		end
		max_possible=(farm_spread+1)^2

		----- measuring half size
		local numBuildsWide = farm_spread + 1
		local totalSep = farm_spread * scale  
		local halfSizeX = numBuildsWide*sx + totalSep * 8
		local halfSizeZ = numBuildsWide*sz + totalSep * 8
		------

		while a<railLength do
			a=a+1

			------------- Adjusting starting position
			rx,ry,rz=unpack(rail[a])
			rx = floor((rx + 8 - oddx)/16)*16 + oddx
			rz = floor((rz + 8 - oddz)/16)*16 + oddz
			if farm_spread%2==1 then
				rx=rx-oddx+(scale%2)*8
				rz=rz-oddx+(scale%2)*8
			end
			--------- clamp farm
 			local onMapEdge

			if rx <= halfSizeX then
				rx=halfSizeX
				onMapEdge = true
			elseif rx >= mapSizeX-halfSizeX then
				rx = mapSizeX-halfSizeX
				onMapEdge = true
			end
			if rz <= halfSizeZ then
				rz=halfSizeZ
				onMapEdge = true
			elseif rz >= mapSizeZ-halfSizeZ then
				rz = mapSizeZ-halfSizeZ
				onMapEdge = true
			end
			-------------

			local dist

			if lasRx then
				dist = max(abs(lasRx-rx),abs(lasRz-rz))
			end
			local posable = not lasRx or dist >=mingap/2
			-- local posable = true
			-- Echo((dist and 'dist '..dist..' ' or '') .. (posable and 'posable' or ''))

			if useNeat and lasRx then
				rx = floor((rx - offposeX + mingap )/(mingap*2)) * (mingap*2) + offposeX
				rz = floor((rz - offposeZ + mingap )/(mingap*2)) * (mingap*2) + offposeZ
				-- Echo("offposeX, offposeZ is ", offposeX, offposeZ)
				posable = lasRx~=rx or lasRz~=rz
				-- Points[#Points+1]={rx,ry,rz,color = color.red}
			end

			-- posable = true
			-- Echo("#allspecs is ", #allspecs)
			-- posable = true
	 		if posable then
	 		-- 	if lasR then
					-- Points[#Points+1]={lasRx,lasRy,lasRz}
				-- end
				-- Points[#Points+1]={rx,ry,rz,color = color.red, txt  = (dist or 'no')..'/'..(mingap-16)}
	 			--debug
	 			currentBarred = {}
	 			extraBarred = {}
	 			method = 0
				----- Define how far we check -----
				local offset,step
				-- farm_spread 1 by default will make a quad
				layers = floor((farm_spread+1)/2)

				offset = (farm_spread%2)*mingap -- we start at 0 on uneven farm_spread value (which is an even number of build)
				-----
				-- Echo("rx%16 is ", rx%16,sx,sz, farmW%16, farmH%16,oddz,oddx,mapSizeX%16,mapSizeZ%16 )

				---
				---- debug middle pos when on map edge
				-- if onMapEdge then
				-- 	Points[#Points+1] = {rx, sp.GetGroundHeight(rx,rz),rz,txt = 'o',size = 13}
				-- end
				----
				-- SpiralSquare(layers,16,FindPose,offset)
				method = 1
				local findings = {}
				local reversed = false
				local extra = useExtra and not useNeat and 1 or 0 -- checking extra layers to see what would fit the best with the environment, without actually posing them
				-- this is costly as none of the extra layer will be remembered
				-- method #1, looking for the neat square of placements

				repeat -- this is not a real loop, only used to break code execution

					local found, isBest = ExecuteMethod(method,layers+extra,mingap*2,offset,reversed,findings, 'bestAtMax')
					if (isBest or useNeat) then
						break
					end
					-- method #2, looking for possible placements starting from center (or oddx), in spiral, clockwise and starting at 10 o'clock
					method=method+1
					if farm_spread==1 and not onMapEdge then
						offset=oddx + scale*8
						layers = math.ceil((mingap*2-16)/16)
						-- layers=layers*1.33
					else
						if flexible then
							-- offset = offset - 16
							-- mingap = mingap - 16
						end
						layers = (mingap/16)*farm_spread
					end

					ExecuteMethod(method,layers+extra,16,offset,reversed,findings) 
					-- method #3, same as method #2 but counter clockwise and starting from exterior
					if useReverse then
						method=method+1
						reversed = true
						ExecuteMethod(method,layers+extra,16,offset,reversed,findings)
					end


				until true
				local best = findings[1]
				if best and debugMethods then
					Echo('method #'..best.method,'found: ' ..best.real_n..'/'..best.n,'sep: '..best.sep,'dist: '..best.dist,'score: '..best.score, ' => current best: '..best.method)
				end

				local strScore
				for i=2,#findings do
					local found=findings[i]
					-- strScore = strScore ..' | m'..found.method..': '.. found.score
					if found.real_n < best.real_n then
						-- skipping 
					elseif found.real_n == best.real_n then
						if found.n < best.n then
							-- skip, 'best' has more 'extra' than found
						elseif found.n > best.n 
							or found.score>best.score
							or found.sep<best.sep
							or found.sep==best.sep and found.dist<best.dist
						then
							best = found
						end
					else
						-- if found.method == 3 and best.method == 2 or i==3 then
						-- 	Echo('METHOD 3 ACTUALLY FOUND MORE THAN METHOD 2 !')
						-- 	Echo('method #'..best.method,'found: ' ..best.real_n..'/'..best.n,'sep: '..best.sep,'dist: '..best.dist,'score: '..best.score, ' => current best: '..best.method)
						-- 	Echo('method #'..found.method,'found: ' ..found.real_n..'/'..found.n,'sep: '..found.sep,'dist: '..found.dist,'score: '..found.score, ' => current best: '..best.method)
						-- end
						best = found
					end
					if debugMethods then
						Echo('method #'..found.method,'found: ' ..found.real_n..'/'..found.n,'sep: '..found.sep,'dist: '..found.dist,'score: '..found.score, ' => current best: '..best.method)
					end
				end
				if strScore and debugEdges then
					Echo(strScore)
				end



				if best then
					if debugMethods then
						Echo('=> BEST METHOD '..best.method..' ('..#findings..' findings)', 'found '..best.n..'/'..best.n,'sep '..best.sep,'dist '..best.dist,'score: '..best.score)
					end


					UpdateMem(best.barred) -- put the currentBarred into coordsMemory
					r=a
					lasRx,lasRz = rx,rz
					if useNeat and not offposeX then
						local Prx = floor((lasRx + mingap )/(mingap*2)) * (mingap*2) -- - offposeX
						local Prz = floor((lasRz + mingap )/(mingap*2)) * (mingap*2)  -- - offposeZ
						offposeX = lasRx - Prx
						offposeZ = lasRz - Prz
						-- Points[#Points+1]={Prx,ry,Prz,color = color.yellow}
					end
					-- Points[#Points+1] = {rx,ry,rz,color = color.blue,txt='P'}
					rail[a].specs=best
					local rpose = {rx,sp.GetGroundHeight(rx,rz),rz}
					rail[a].rpose = rpose
					for i,v in ipairs(best) do
						if not v.extra then
							if not firstPose then
								firstPose = v
							end
							n=n+1
							v.r = r
							v.n = n
							specs[n]=v
							rail[r].color=color.green
							if tryEdges and not useNeat then
								fx,fz = v[1], v[2]
								local limit = (sx+oddx+scale*8)-(scale%2)*8
								SpiralSquare(limit/16,16,MarkEdge,limit)
							end

							if debug then
								local x,z = v[1],v[2]
								Points[#Points+1] = {x,sp.GetGroundHeight(x,z),z,color = color.blue,txt='P'}
							end
						end
					end

					----- show the placements found per method as 'P' .. method in blue
					if debug or debugEdges then
						for _,found in ipairs(findings) do
							for _, p in ipairs(found) do
								local x,z =  p[1], p[2]
								Points[#Points+1] = {x,sp.GetGroundHeight(x,z),z,color = color.blue,txt='P'..found.method,size = 15}
							end
						end
					end
				end

				currentBarred={}
				extraBarred = {}
				

			end
		end
		rail.processed = rail.n
		-- Echo("rail.processed is ", rail.processed)
		specs.n = n
		return
	end
end
do
	local insert,remove,max,GetGround = table.insert,table.remove, math.max,sp.GetGroundHeight
	NormalizeRail = function(expensive) -- complete rail from received mouse points
		if not rail[2] then return end
		local railn = #rail
		local update

		-------------------
		--local x,y,z = unpack(rail[1])
	--[[	local p = rail.processed==1 and 2 or rail.processed
		local x,y,z = unpack(rail[p-1])
		rail.processed = p-1
		local lasR = rail[p-1]
		local tries=0
		local j=p--]]
		--Echo('--->norm at ',p-1--[[, 'processed:',rail.processed--]])
		local tries=0
		local pr = rail.processed
		local lasR = rail[pr]
		local j = pr+1
		--Echo('normalize:', p-1,railn)
		--Echo('normalize:', rail.processed,railn)
		local oddx,oddz = p.oddX,p.oddZ
		local sx,sz = p.sizeX,p.sizeZ
		while j<=railn do
			tries=tries+1
			local x,y,z = unpack(lasR)
			local jx,jy,jz,pushed = rail[j][1], rail[j][2], rail[j][3], rail[j].pushed
			-- if pushRail then -- not used anymore
			-- 	pushed=false
			-- 	local px,py,pz =  WG.AvailablePlacement(jx,jz,p)
			-- 	if px then
			-- 		jx = floor((px + 8 - p.oddX)/16)*16 + p.oddX
			-- 		jz = floor((pz + 8 - p.oddZ)/16)*16 + p.oddZ
			-- 		jy = GetGround(jx,jz)
			-- 		if jy<0 and p.floater then jy=0 end
			-- 		rail[j][1],rail[j][2],rail[j][3]=jx,jy,jz
			-- 		pushed=true
			-- 	end
			-- end
			local dirx,dirz = jx-x, jz-z
			local biggest =  max( abs(dirx), abs(dirz) )
			dirx,dirz = dirx/biggest, dirz/biggest
		--Echo(abs(x-jx), abs(z-jz))
			-- insert as many points as needed between two distanced points until distance is below/equal 16 for each coord
			while (abs(x-jx)>16 or abs(z-jz)>16)--[[ and tries1<2--]] do
				
				tries=tries+1
				x=x+dirx*16
				z=z+dirz*16
				local rx = floor((x + 8 - oddx)/16)*16 + oddx
				local rz = floor((z + 8 - oddz)/16)*16 + oddz
				local cantPlace,_,closest = TestBuild(rx,rz,p,not PBH,placed,overlapped)
				if cantPlace and closest then 
					rx,rz = PushOut(rx,rz,sx,sz,x,z,closest,p)
				end
				----------------------------
				local y = GetGround(x,z)
				if y<0 and p.floater then y=0 end
				insert(rail,j, { x,y,z, pushed=pushed, rx = rx, rz = rz, overlap = closest })

				--overlapped[#overlapped+1]={rx,rz,sx,sz}
				--Echo('insert',j,pr)
				railn=railn+1
				j=j+1
				if tries==1000 then Echo('too many tries',j,railn) break end
			end
			--Echo("total tries",tries1)
			-- remove the next point if it is now too close
			if (abs(x-jx)<16 and abs(z-jz)<16) then
				--Echo('remove',j,pr,rail[j].done)
				remove(rail,j)
				railn=railn-1
			-- the next point is at perfect distance but hasnt been updated, adding the missing keys
			elseif not rail[j].rx then
				local rx,rz = rail[j][1],rail[j][3]
				local cantPlace,_,closest = TestBuild(rx,rz,p,not PBH,placed,overlapped)
				if cantPlace and closest then 
					rx,rz = PushOut(rx,rz,sx,sz,x,z,closest,p)
				end
				rail[j].rx,rail[j].rz,rail[j].pushed,rail[j].overlap = rx,rz,pushed,closest

			end

			lasR = rail[j]
			j=j+1
			
			--Echo(lasR or 'NOT')
		end
			--Echo('normalized '..rail.n..' to '..railn)
		if prev.rail[1]~=rail[railn][1] or prev.rail[3]~=rail[railn][3] then
			update=true
			--Echo('update')
		end
		rail.n=railn
		prev.rail = rail[railn]
		if rail.processed>railn then rail.processed = railn end
		--Echo('<-- processed:', rail.processed)

		return update
		
	end
end
local function Init()

	if not rail[1] then return end
	local x,z = rail[1][1], rail[1][3]
	rail.processed=1
	specs:clear()

	WG.drawingPlacement = specs
	local hasOverlap = TestBuild(x,z,p,not PBH,placed,overlapped)
	if not hasOverlap and status~='paint_farm' then
		specs[1]={x,z,r=1}
		specs.n=1
	end
	if E_SPEC[PID] then
		g.old_showeco = WG.showeco
		WG.showeco = true
		WG.force_show_queue_grid = PID
	end
	if special then
		local n,newgrids,_,grids = CheckConnections(x,z)
		connectedTo=Link(grids)
		allGrids={}
		for k in pairs(grids) do allGrids[k]=true end
		local status = n==0 and 'out' or 'onGrid'
		if not hasOverlap then
			specs[1].status = status
			specs[1].grids = connectedTo
			specs[1].newgrids = newgrids
			UpdateMexes(x,z,nil,1)
		else 
			rail[1].status=status
			rail[1].grids=connectedTo
		end
		NormalizeRail()
		PoseSpecialOnRail()
	else

		NormalizeRail()
		if status=='paint_farm' then 
			rail.processed=0
			Paint()
		else
			PoseOnRail()
		end
	end
end

function widget:UnitCommand(unitID, unitDefID, unitTeam, cmdID, cmdParams, cmdOpts, cmdTag)
	-- Echo("cmd == CMD_FACTORY_GUARD is ", cmdID == CMD_FACTORY_GUARD, CMD_FACTORY_GUARD,cmdID)
    if conTable.waitOrder and conTable.cons[unitID] then
        local waitOrder = conTable.waitOrder
        if waitOrder[1] == cmdID and table.compare(waitOrder[2],cmdParams) then -- until the last user order has not been received here, we keep the virtual queue made by multiinsert
            conTable.inserted_time = false
            conTable.waitOrder = false
        end
        -- conTable.inserted_time = false
    end
end

function widget:CommandNotify(cmd, params, options)

	-- NOTE: when using Alt, it happens the active command get reset by some widget at CommandNotify stage
	-- if shift and PID and cmd==0 and #params==0  then
	-- 	if leftClick and #specs>0 then 
	-- 		local cmd
	-- 		rmbAct, cmd = sp.GetActiveCommand()
	-- 		-- if not cmd or cmd
	-- 		status='held'
	-- 	else 
	-- 		Spring.GiveOrderToUnitArray(getcons(),CMD.STOP, EMPTY_TABLE,EMPTY_TABLE)
	-- 	end
	-- 	sp.SetActiveCommand(0) -- cancel with S while placing multiple
	-- 	--[[Echo('stop command')--]] reset()
	-- end
end

--
-- local time=0
-- local PBS


local prevpx,prevpz=0,0

WG.PlacementModule = {}
local PlacementModule = WG.PlacementModule
function PlacementModule:Measure(PID,facing,ud)
	local t
	if not PID then 
		t,ud,PID,facing =self,self.ud, self.PID, self.facing
	else
		t,ud={},UnitDefs[PID]
	end
	-- Echo('PID',UnitDefs[-PID])
	local footX,footZ = ud.xsize/2, ud.zsize/2
	local offfacing = (facing == 1 or facing == 3)
	if offfacing then footX, footZ = footZ, footX end
	
	local oddX,oddZ = (footX%2)*8,(footZ%2)*8
	local sizeX,sizeZ = footX * 8, footZ * 8 

	t.footX=footX
	t.footZ=footZ
	t.oddX=oddX
	t.oddZ=oddZ
	t.sizeX=sizeX
	t.sizeZ=sizeZ
	t.terraSizeX=sizeX-0.1
	t.terraSizeZ=sizeZ-0.1
	t.offfacing=offfacing
	t.floater=ud.floatOnWater or not CheckCanSub(ud.name)
	t.height=ud.height
	t.name=ud.name
	t.radius=ud.name=="energypylon" and 3877 or (ud.radius^2)/8
	return t
end

function PlacementModule:Update()
	local _, PID = sp.GetActiveCommand()
	if PID then
		if PID > -1 then
			PID = false
		else
			PID = -PID
		end
	end
	
	if not Drawing or PID then
		local reMeasure
		if PID then
			if self.PID~=PID then
				reMeasure,self.spacing = true,sp.GetBuildSpacing()
				self.PID,self.lastPID = PID,self.PID or PID
				self.ud = UnitDefs[PID]
			end
			local facing = sp.GetBuildFacing()
			if facing and facing~=self.facing then
				reMeasure,self.facing = true, facing
			end
		end
		self.PID = PID
		if reMeasure then self:Measure() end
	end
end
function PlacementModule:RecoverPID()
	if not self.lastPID then
		return
	end
	if E_SPEC[self.lastPID] then
		WG.force_show_queue_grid = self.lastPID
	end
	local _,com,_,comname = sp.GetActiveCommand()
	-- local com = select(2, sp.GetActiveCommand())
	if select(2, sp.GetActiveCommand()) ~= -self.lastPID then
		if com then
			Echo('comname is ',comname,com, 'last pid is', self.lastPID )
		end
		local cmdIndex = self.lastPID and Spring.GetCmdDescIndex(-self.lastPID)
		return cmdIndex and sp.SetActiveCommand(cmdIndex)
	end
end


local Controls ={}


p=PlacementModule


local function FinishDrawing(fixedMex)
	local alt, ctrl, meta, shift = sp.GetModKeyState()
	if status=='paint_farm' then
		if specs[1] then SendCommand(PID) end
		reset()
		Drawing=false
		WG.drawingPlacement=false
		p:RecoverPID()
		status='engaged'
		return
	elseif status=='engaged' then
		-- finish correctly, ordering
		if shift then
		 	p:RecoverPID()
		 else
		 	status ='none'
		 end
		-- if Debug and WG.PBHisListening then Echo('DP release and catch PBH') end
		if specs[1] then
			SendCommand(PID)
			-- NOTE: when using Alt, it happens the active command get reset by some widget at CommandNotify stage
			-- so we redo it
			if alt  and shift then
				p:RecoverPID()
			end
		elseif (not prev.pos or prev.pos[1]==pointX and prev.pos[3]==pointZ) then
			if false and (Cam.relDist or  GetCameraHeight(sp.GetCameraState()))<2700 then -- zoomed in enough, we allow erasing placement
				EraseOverlap(pointX,pointZ)
			elseif WG.FindPlacementAround then -- if zoomed out and PBH is active, we look for a placement around
				if not pointX then
					Echo('Error in Draw Placement Finish Drawing, no pointX !')
				elseif not fixedMex then
					WG.FindPlacementAround(pointX,pointZ,placed)
					if WG.movedPlacement[1]>-1 then
						specs[1]={WG.movedPlacement[1],WG.movedPlacement[3]}
						specs.n=1
						SendCommand(PID)
					end
				end
			end
		end
		reset()
		Drawing=false
		WG.drawingPlacement=false
		WG.showeco = g.old_showeco
		WG.force_show_queue_grid = false
		-- Echo("prev.pos[1],pos[1] is ", prev.pos[1],pointX)
		-- if specs[1] then EraseOverlap(specs[1][1],specs[1][3]) end
		-- if (PID~=mexDefID) then status='none' end
		return
	end
end


function widget:Update(dt)	
	_,_,leftClick,_,rightClick = sp.GetMouseState()
	alt, ctrl, meta, shift = sp.GetModKeyState()
	-- time=time+dt

	p:Update()
--Page(p)
	PID = p.PID
	drawEnabled = PID and not noDraw[PID]
	WG.drawEnabled=drawEnabled
	special = drawEnabled and E_SPEC[PID] and status~='paint_farm' and sp.GetBuildSpacing()>=7
    if preGame then
        preGame=Spring.GetGameSeconds()<0.1
        -- Echo("#preGameBuildQueue is ", #preGameBuildQueue)
        if not preGame and preGameBuildQueue and preGameBuildQueue[1] then
            tasker=preGameBuildQueue.tasker
            -- Echo("preGameBuildQueue.tasker is ", preGameBuildQueue.tasker)
            if tasker then
                -- Echo("got tasker",tasker)
                ProcessPreGameQueue(tasker)
            end
        end
    end
    if PID and status=='none' then
    	status='ready'
    end

	-- if status:match'held' then
	-- 	if status:match'!R' and not rightClick then Echo('CHECK')  status='rollback' end -- meanwhile Drawing, rightClick press cancelled the Drawing, PID is recovered after rightClick is released
	-- end
	-- if status=='rollback' and not leftClick then
	-- end
	--if  and not leftClick and not shift then reset()  end
	if status=='held_!R' and not rightClick then
		status='rollbackL'
	end
	if status=='rollbackL' then -- waiting to roll back the PID 
		if not leftClick then
			-- Echo("2 widgetHandler.mouseOwner is ", widgetHandler.mouseOwner)
			p:RecoverPID()
			status='engaged'
			reset()
		end
		return
	end
	if status=='rollbackR' then -- waiting to roll back the PID 
		if not rightClick then
			-- Echo("2 widgetHandler.mouseOwner is ", widgetHandler.mouseOwner)
			p:RecoverPID()
			status='engaged'
			reset()
		end
		return
	end

	if status=='engaged' then
		if rightClick  then
			status='held_!R'
			sp.SetActiveCommand(0)
			WG.force_show_queue_grid = true
			reset()
			return
		end
	end -- reset but will recover PID on rightClick release
	if not PID and status~='erasing' then
		if status=='ready' then
			status='none'
		else
			return
		end
	end

	if not Drawing then
		if PID==mexDefID and status=='engaged' and not shift and not leftClick then
			status='none'
		end

	end
	--if PID==mexDefID and not shift then sp.SetActiveCommand(-1) end
	if status=='engaged' and not (shift or ctrl) then
		if not specs[1] then
			status='none'
		end
	end

	if status=='none' then
		local acom = select(2,sp.GetActiveCommand())
		if acom and acom < 0 and PID == -acom then
			if not widgetHandler.mouseOwner then
				sp.SetActiveCommand(-1)
				reset(true)
				return
			end
		end
		WG.showeco = g.old_showeco
		WG.force_show_queue_grid = false
		reset()
		return
	end

   	mx,my = sp.GetMouseState()
	pos = {UniTraceScreenRay(mx,my,not p.floater,p.sizeX,p.sizeZ)}



	if Drawing then --

		 -- don't use/show the engine build command, handle it ourself
		if sp.GetActiveCommand()>0 then 
			sp.SetActiveCommand(0)
		end
	end



	if status=='erasing' then
		-- EraseOverlap()
		sp.SetMouseCursor(CURSOR_ERASE_NAME)
		return
	end

	-- if Drawing and rightClick and status~='paint_farm' then status='held_!R' sp.SetActiveCommand(0) reset() end -- reset but will recover PID on rightClick release


--[[	warpBack = warpBack  or drawEnabled and not shift and "ready" -- getting back to position if shift got released then rehold

	washold = washold or hold--]]


--[[	if hold then
		widgetHandler:RemoveWidgetCallIn("DrawWorld", self)
		return
	end--]]


    if PID==geos.defID then
        local geoX,geoY,geoZ = sp.ClosestBuildPos(0,PID, pos[1], 0, pos[3], 500 ,0 ,0)
        if geoX>-1 then
        	local thisgeo = geos.map[geoX] and geos.map[geoX][geoZ]
        	if not geos.cant[thisgeo] then
            	pos={geoX,geoY,geoZ}
            end
        end
    end


	if Drawing and not (preGame or (cons[1] and sp.ValidUnitID(cons[1])) ) then
		reset()
		drawEnabled=false
		return
	end
	if Drawing and special then
		UpdateMexes(pos[1],pos[3],_,_,'virtual') 
	elseif previMex[1] then
		previMex={}
	end

--[[if not leftClick and PID then
tick[1],a,b,c,d,e = allow(tick[1],1,Continue, DefineBlocks, "Define")

else End("Define")
end
--]]

	------------------------------
	if not Drawing then return end
	------------------------------

--UnitDefNames["energywind"].id]

	if newmove and rail[2] then
		previMex={}
	 	local update = NormalizeRail() -- this will complete and normalize the rail by separating/creating each point by 16, no matter the speed of the mouse
	 	if update then
			NormalizeRail()
			if special then
				PoseSpecialOnRail()
			elseif status=='paint_farm' then
				Paint()
			else
			 	PoseOnRail()
			end
		end
		newmove=false
	end

	if status=='paint_farm' then return end
----------------------
--[[	if not special and wasspecial[PID] then
		special = true
		sp.SetBuildSpacing(100000)
	end--]]

	--wasspecial[PID] = E_SPEC[PID] and special or nil

	-- if leftClick then  sp.SetActiveCommand(-1) end

	p.spacing = p.spacing or sp.GetBuildSpacing()
	--Echo(" is ", spacing,sp.GetBuildSpacing())
	if p.spacing and p.spacing~=sp.GetBuildSpacing() then 
		p.spacing = sp.GetBuildSpacing()
		Init()
		--widgetHandler:UpdateWidgetCallIn("DrawWorld", self)	
		return
	end

	-- if alt and #primRail>2 then
	-- 	NormalizeRail("expensive")
	-- 	--Echo("after #primRail,#rail is ", #primRail,#rail)
	-- 	--PoseOnRail()
	-- 	return
	-- end
end

function widget:KeyRelease(key, mods)
    local newalt,newctrl,newmeta,newshift = mods.alt,mods.ctrl,mods.meta,mods.shift

	alt, ctrl, meta, shift = newalt,newctrl,newmeta,newshift

	-- if waitReleaseShift and not shift then sp.SetActiveCommand(0) waitReleaseShift=false end
	if Drawing and shift and PID then
		GoStraight(alt)
	end
	if (status=='engaged' or status=='erasing') and not (shift or ctrl) then
		if not specs[1] then
			status='none'
			sp.SetActiveCommand(-1)
			reset()
			PID=false
			WG.showeco = g.old_showeco
			WG.force_show_queue_grid = false
		end
		return
	end

	if specs[1] and shift and alt and not special and status~='paint_farm' then PoseOnRail() end --  also key 308=LALT
end
function widget:MouseWheel(up,value) -- verify behaviour of keypress on spacing change
	if ctrl then
		if PID and p.sizeX==p.sizeZ then
			local isPainting = status=='paint_farm'
			local modifyPainting = shift
			if modifyPainting then
				if not (PID == mexDefID and WG.metalSpotsByPos) then
					local changed
					local modifySpread = alt
					if modifySpread then
						local spread = FARM_SPREAD[PID] or 1
						spread = up and min(spread + 1,5) or max(spread - 1,1)
						changed = spread ~= (FARM_SPREAD[PID] or 1)
						FARM_SPREAD[PID]= spread ~= 1 and spread or nil
						farm_spread = spread
					else
						local scale = FARM_SCALE[PID] or 0
						scale = up and min(scale + 1, MAX_SCALE[PID] or 5) or max(scale - 1,0)
						changed = scale ~= (FARM_SCALE[PID] or 0)
						FARM_SCALE[PID]= scale ~= 0 and scale or nil
						farm_scale=scale
					end
					if isPainting and changed then
						Paint('reset')
						Init()
					end
				end
				return true
			end
		end
	end
	if shift and Drawing and PID then
		--if PBS then Echo("CHK") return PBS.MouseWheel(_,up,value) end
		--local block=drawEnabled and not up--[[checking if not buildspacing mousewheel--]]
		sp.SetBuildSpacing(p.spacing+value)
		if up then widget:KeyPress(spacingIncrease, EMPTY_TABLE)
		else widget:KeyPress(spacingDecrease, EMPTY_TABLE)
		end
		return true
	end
end

-- function Spring.GetUnitsInCircle(r,mx,my)
-- 	if not mx then
-- 		mx, my = Spring.GetMouseState()
-- 	end
-- 	local corners = {}
-- 	for i = -1, 1, 2 do
-- 		local where, pos = Spring.TraceScreenRay(mx + i * r, my + i * r,true,true,true,false)
-- 		if where == 'sky' then
-- 			pos[1], pos[2], pos[3] = pos[4], pos[5], pos[6]
-- 		end
-- 		Points[#Points+1] = {pos[1], pos[2], pos[3],size = 50}
-- 		corners[i] = pos
-- 	end
-- 	if corners[-1][1] > corners[1][1] then
-- 		corners[1][1], corners[-1][1] = corners[-1][1], corners[1][1]
-- 	end
-- 	if corners[-1][3] > corners[1][3] then
-- 		corners[1][3], corners[-1][3] = corners[-1][3], corners[1][3]
-- 	end

-- 	local left, 		  bottom,			right, 			  top 
-- 		= corners[-1][1], corners[-1][3], corners[1][1], corners[1][3] 
-- 		-- Echo("left,bottom,right,top is ", left,bottom,right,top)
-- 		Echo(" is ", #Spring.GetUnitsInRectangle(left,bottom,right,top))
-- 	for i, id in ipairs(Spring.GetUnitsInRectangle(left,bottom,right,top)) do
-- 		local ux,uy,uz = Spring.GetUnitPosition(id)
-- 		Points[#Points+1] = {ux,uy,uz,txt = 'o',size = 15}
-- 	end

-- end




function widget:KeyPress(key, mods,isRepeat)
	-- if mods.ctrl then
	-- 	Points = {}
	-- end
	-- if mods.ctrl and mods.alt then
	-- 	if isRepeat then
	-- 		return
	-- 	end
	-- 	local mx,my = sp.GetMouseState()
	-- 	local ux,uy,uz = sp.GetUnitPosition(15386)
	-- 	local r = Spring.GetUnitRadius(15386)
	-- 	Echo("ux,uy,uz is ", ux,uy,uz)
	-- 	local test, pos = Spring.TraceScreenRay(mx,my,true,false,false,false)
	-- 	local cx, cy, cz = pos[1], pos[2], pos[3]
	-- 	local cx, cy, cz = Spring.GetCameraPosition()
	-- 	local function dir(px,py,pz)
	-- 		local d = ((px - cx)^2 + (py - cy)^2 + (pz - cz)^2)^0.5
	-- 		return (px - cx)/d, (py - cy)/d, (pz - cz)/d, d
	-- 	end
	-- 	local function dirfrom(cx,cy,cz,px,py,pz)
	-- 		local d = ((px - cx)^2 + (py - cy)^2 + (pz - cz)^2)^0.5
	-- 		return (px - cx)/d, (py - cy)/d, (pz - cz)/d, d
	-- 	end
	-- 	local vsx, vsy = Spring.GetWindowGeometry()
	-- 	local test, center = Spring.TraceScreenRay(vsx/2,vsy/2,true,false,false,false)
	-- 	local cenx,ceny,cenz,D = dirfrom(center[1], center[2], center[3], cx,cy,cz)
	-- 	Echo("center[1], center[2], center[3], cx,cy,cz is ", center[1], center[2], center[3], cx,cy,cz)
	-- 	local planes = {}
	-- 	local _,_,_,camD = dir(pos[1], pos[2], pos[3])	
	-- 	local d = 5000
	-- 	-- local cx, cy, cz = Spring.GetCameraDirection()

	-- 	Points = {}
	-- 	-- for x = 0,0 do
	-- 	for x = -1, 1, 2 do
	-- 		for y = -1, 1, 2 do
	-- 		-- for y = 0, 0 do
	-- 			local where, pos = Spring.TraceScreenRay(mx + x * 100,my + y * 100,true,true,true,false,500)
	-- 			if where == 'sky' then
	-- 				pos[1], pos[2], pos[3] = pos[4], pos[5], pos[6]
	-- 			end
	-- 			local dx,dy,dz, d = dir(pos[1], pos[2], pos[3])	
	-- 			local dx,dy,dz, d = dirfrom(pos[1], pos[2], pos[3],pos[4], pos[5], pos[6])	
	-- 			local dx,dy,dz, d = dirfrom(cx, 0, cz,pos[4], pos[5], pos[6])	
	-- 			local dx,dy,dz, d = dir(pos[4], pos[5], pos[6])					
	-- 			-- dx,dy,dz = Spring.GetPixelDir(mx+ x * 100, my + y * 100)
	-- 			-- if x == -1 then
	-- 			-- 	dx = -dx
	-- 			-- end
	-- 			-- if y == -1 then
	-- 			-- 	dz = -dz
	-- 			-- end
	-- 			local plane = {dx,dy,dz}
	-- 			plane[4] = D
	-- 			-- plane[4] = d
	-- 			table.insert(planes, plane)
	-- 			Points[#Points+1] = {pos[4], pos[5], pos[6],size = 50}
	-- 			Points[#Points+1] = {pos[1], pos[2], pos[3],size = 50, txt = 'g'}
	-- 			local p = dx * ux + uy * dy + uz * dz

	-- 			-- Echo("dx2,dy2,dz2 is ", dir(pos[1], pos[2], pos[3]))
	-- 			if x == -1 and y == -1 then
	-- 				-- Echo("D is ", D)
	-- 				p = D
	-- 				local dx,dy,dz, d = dirfrom(pos[1], pos[2], pos[3],pos[4], pos[5], pos[6])	
	-- 				p = d 
	-- 				Echo("dx,dy,dz is ", dx,dy,dz, "d",d)
	-- 				Points[#Points+1] = {ux + dx * p, uy + dy * p, uz + dz * p, txt = 'n', color = color.red, size = 50}
	-- 				Points[#Points+1] = {ux, uy, uz, txt = 'p', color = color.red, size = 50}
	-- 				Echo(ux ..' => '.. (ux + dx * p),uy ..' => '.. (uy + dy * p),uz ..' => '.. (uz + dz * p))
	-- 				-- Echo("p is ", p,'vs', d )

	-- 			end
	-- 			if true then
	-- 				break
	-- 			end
	-- 		end
	-- 		if true then
	-- 			break
	-- 		end
	-- 	end
	-- 	local units = Spring.GetUnitsInPlanes(planes)
	-- 	Echo("#units is ", #units)
	-- 	for i, id in ipairs(units) do
	-- 		local ux,uy,uz = sp.GetUnitPosition(id)
	-- 		Points[#Points+1] = {ux,uy,uz,txt = X, size = 60, color = color.blue}
	-- 	end
	-- end
	local inc, dec = key == spacingIncrease,key == spacingDecrease
	if (inc or dec) then
		if Drawing and E_SPEC[PID] then
			special = sp.GetBuildSpacing()>=7 and inc
			if special then
				sp.SetBuildSpacing(7)
				return true
			end
		end
		return
	end
	-- toggling special treatment for solar/wind/pylons or back to normal 

	alt, ctrl, meta, shift = mods.alt, mods.ctrl, mods.meta, mods.shift


	-- if Drawing and shift and key==308 then
		--pushRail=not pushRail
		--rail=deepcopy(primRail)
	-- end
	if Drawing and PID and shift then
		GoStraight(alt)
	end
	if alt and shift and key==100 then -- Alt+Shift+D to toggle Drawing for tis particular build
		if PID then noDraw[PID] = not noDraw[PID] end
		Drawing = not noDraw[PID]
		-- WG.drawingPlacement=Drawing

		reset()
		drawEnabled=false
		if leftClick then sp.SetActiveCommand(-1) status='held' end
	end


end


--[[    function X(...)
       
        return call(%X, arg)
    end--]]

local testRail={n=0}



function __FILE__() return debug.getinfo(2, 'S').source end
function __LINE__() return debug.getinfo(2, 'l').currentline end
function __FUNC__() return debug.getinfo(2, 'n').name end

function printlinefilefunc()
    Echo("Line at "..__LINE__()..", FILE at "..__FILE__()..", in func: "..__FUNC__())
end


getLocalsof= function(level)

	local T = {}
	local i = 1
	while true do
	    local name, value = debug.getlocal(level+1, i)
	    if not name then break end
	    T[name]=value
	    i = i + 1
	end
	return T
end
getUpvaluesof= function(func,search)

	local T = not search and {}
	local i = 1
	while true do
	    local name, value = debug.getupvalue (func, i)
	    if not name then break end
	    if search and name==search then return value
	    elseif T then T[name]=value end
	    i = i + 1
	end
	return T
end


function widget:MousePress(mx, my, button)
	alt, ctrl, meta, shift = sp.GetModKeyState()
	if button==2 then return end
	if status == 'rollbackL' and button == 3
	or status == 'rollbackR' and button == 1 then
		return true -- block the mouse until the rollback occur
	end
	if (status =='paint_farm' or status=='erasing') and button==1 then
		status ='held_!L'
		sp.SetActiveCommand(0)
		WG.force_show_queue_grid = true
		reset() 
		return true
	end
	if status=='erasing' and button==1 then
		status='none'
		reset(true)
		return
	end
	if shift and not PID and (select(2,sp.GetActiveCommand()) or 0) < 0 then
		widget:Update(0)
		Echo('didnt have PID, now ?',PID,os.clock())
	end
	if button==1 and PID then
		if ctrl and shift then
		-- use the normal engine building system when ctrl and shift are pressed
			if PID ~= mexDefID or not WG.metalSpotsByPos then
				status='engaged'
				return
			end
		elseif not shift then
			-- status = 'wait1'
			status = 'engaged'
			return
		end
	end
	-- if button==1 and meta and not (shift or ctrl) and PID then status='engaged' return end
	local x,y,z
	if shift and PID then
		if status=="ready" and PBH then
			PBH.Process(mx,my) -- if user moved the cursor fast, PBH didnt scan for moved placement (etc...) at the current position
		end
		if button==3 and not Drawing then
			if ctrl then
				if p.sx==p.sz  then -- paint_farm has not rectangular build implemented yet
					if PID == mexDefID and WG.metalSpotsByPos then
						-- skip
					else
						status="paint_farm"
						if WG.DrawTerra and WG.DrawTerra.working then
							WG.DrawTerra.finish = true
						end
						farm_spread = FARM_SPREAD[PID] or 1
						farm_scale = FARM_SCALE[PID] or 0
						Points={}
					end
				end
			elseif status=='ready' or status=='engaged' then
				status='erasing'
				sp.SetActiveCommand(0)
				WG.force_show_queue_grid = true
				EraseOverlap()
				return true
			end
		end
		prev.firstmx, prev.firstmy = mx,my
		x,y,z=UniTraceScreenRay(mx,my,not p.floater,p.sizeX,p.sizeZ)
		-- x,y,z = unpack(pos)
		x = floor((x + 8 - p.oddX)/16)*16 + p.oddX
		z = floor((z + 8 - p.oddZ)/16)*16 + p.oddZ
		local myPlatforms = WG.myPlatforms
		-- Echo("myPlatforms is ", myPlatforms and myPlatforms.x)
		pointX, pointZ = x,z
		if myPlatforms and  myPlatforms.x then
			x = myPlatforms.x
			z = myPlatforms.z
        end

		if button==3 and not Drawing then
			if status=="paint_farm" then
				
				special = false
				Drawing=true
				WG.drawingPlacement=specs
				placed = GetPlacements()
				local r = {x,y,z,rx=x,rz=z}
				rail={r,n=1,processed=1}
				Init()
				prev.rail = rail[1]
				prev.mx = mx
				prev.my = my
				return true, widget:Update(Spring.GetLastUpdateSeconds())
			elseif status=='erasing' then
				EraseOverlap(x,z)
				Spring.SetMouseCursor(CURSOR_ERASE_NAME)
			end
			return true
		elseif drawEnabled and button==1 then
			if GetCloseMex then
				closeMex[1],closeMex[2] = GetCloseMex(x,z)
			end
			--x,z = AvoidMex(x,z)

			--local x,y,z = pointToGrid(16,x,z)
	--		cons = GetCons()
			p.spacing=sp.GetBuildSpacing()
			--places,blockIndexes=DefineBlocks()

	--[[		if getaround then
				map,Rects,places = WG.DefineBlocksNew(PID)
			end--]]

		--places,blockIndexes=DefineBlocks()
			Drawing=true
			WG.drawingPlacement=specs
			status= 'engaged'
			placed = GetPlacements()
			--x,y,z=sp.ClosestBuildPos(0,PID, x, y, z, 1000,0,p.facing)
	--[[		if GetCameraHeight(sp.GetCameraState())<5500 and EraseOverlap(x,z) then -- allow erasing only if not zoommed out too far
				local acom = sp.GetActiveCommand()
				reset() return true
			else--]]
				if WG.movedPlacement and WG.movedPlacement[1]>-1 then
					x,y,z = unpack(WG.movedPlacement)
				end
				local r = {x,y,z,rx=x,rz=z}
				rail={r,n=1,processed=1}
				primRail={r,n=1}	
				prev.dist_drawn = 0
				prev.press_time = os.clock()
				if PID==mexDefID and GetCloseMex --[[and not preGame--]] then
					local spot = GetCloseMex(x,z)
					if spot and not cantMex[spot] then
						cantMex[spot]=true
						if IsMexable(spot) then
							specs[1]={spot.x,spot.z,r=1}
							specs.n=1
						end
					end
				elseif PID==geos.defID then
					geos:BarOccupied()
					local geoX,geoZ = geos:Update(x,z)
					if geoX then 
						specs[1]={geoX,geoZ,r=1}
						specs.n=1
					end
				else
					Init()
				end
			--end
			prev.rail = rail[1]
			prev.mx = mx
			prev.my = my

			return true, widget:Update(Spring.GetLastUpdateSeconds())
		end
	end
end
function WidgetInitNotify (w, name, preloading)

	if name == 'Persistent Build Height 2' then
		PBH = w
	end
	if name == 'Selection Modkeys' then
		SM_enable_opt = w.options.enable
		do
			local isEnabled
			switchSM = function(backup) 
				if backup then 
					if isEnabled then
						SM_enable_opt.value = true
					end
				else
					isEnabled = SM_enable_opt.value
					if isEnabled then
						SM_enable_opt.value = false
					end

				end
			end
		end
	end

end
function widgetRemoveNotify(w, name, preloading)

	if name == 'Selection Modkeys' then
		switchSM = function() end
	end
	if name == 'Persistent Build Height 2' then
		PBH = false
	end

end



function widget:MouseRelease(mx,my,button)
	alt, ctrl, meta, shift = sp.GetModKeyState()
	if shift  then -- prevent from selecting unit when releasing left button above unit while shift is held
		switchSM()
	end
	if status=='held_!R' then
		if button==3 then 
			status='rollbackL'
			-- Echo("widgetHandler.mouseOwner is ", widgetHandler.mouseOwner)
		elseif button==1 then
			status='none'
		end
		widgetHandler.mouseOwner = nil -- disown the mouse after a leftClick + rightClick then release rightClick
	elseif status=='held_!L' then
		if button==1 then 
			status='rollbackR'
			-- Echo("widgetHandler.mouseOwner is ", widgetHandler.mouseOwner)
		elseif button==3 then
			status='none'
		end
		widgetHandler.mouseOwner = nil -- disown the mouse after a leftClick + rightClick then release rightClick
		return true
	elseif status=='erasing' and button==3 then
		if shift then
			status = 'engaged'
			p:RecoverPID()
		else
			status='none'
		end
		return true
	elseif Drawing then
		local fixedMetalSpot = PID == mexDefID and WG.metalSpots
		if status~='paint_farm' and not fixedMetalSpot and (prev.dist_drawn<=8 or os.clock()-prev.press_time<0.05) then
			while specs[2] do
				table.remove(specs,2)
			end
			specs.n = 1
		elseif not fixedMetalSpot then
			widget:MouseMove(mx,my,0,0,button) -- try to complete the rail before finishing
		end
		FinishDrawing(fixedMetalSpot)
	end
	return true, switchSM(true)
end
local function UpdateBasicRail(pos,rail) -- unused -- not working
	if not pos then return end
	local newx,newz = pos[1], pos[3]
	local railLength = #rail
	local lasR = rail[railLength]
	local gapx,gapz
	if lasR then
--			gapx = abs( pointX - newx ) or 10000
--			gapz = abs( pointZ - newz ) or 10000
		gapx = abs( lasR[1] - newx ) or 10000
		gapz = abs( lasR[3] - newz ) or 10000
		if gapx<16 and gapz<16 then
			return
		end
	end
	pointX, pointZ = newx, newz
	local px,py,pz = pos[1], pos[2], pos[3]
	railLength = railLength+1
	rail[railLength]={px,py,pz} -- depending on mouse speed points will not be evenly positionned, but we will use them to fill the blanks and normalize their distance
	rail.n = railLength

	return true
end
function widget:MouseMove(x, y, dx, dy, button)

	--if getaround and not places --[[and not blockIndexes--]] then return end
	-- if status=="paint_farm" then
	-- 	newmove = UpdateBasicRail(pos,rail)
	-- 	mx=x
	-- 	my=y
	-- 	return
	-- end
	-- if not Drawing --[[and not (warpBack=="ready")--]] then	return	end
	if prev.firstmx and (PID ~= mexDefID) then
		if clock() - prev.press_time < 0.09 then -- mouse click leeway
			-- Echo("clock() - prev.press_time is ", clock() - prev.press_time)
			return
		end
		if  ((prev.firstmx - x)^2 + (prev.firstmy - y)^2) ^0.5 < 20 then -- mouse move leeway
			return
		end
	end
	prev.firstmx = false
	if status=='erasing' then
		EraseOverlap()
		return
	end
	if not Drawing then return	end

	if g.unStraightened then
		if clock()-g.unStraightened < 0.3 then 
			return
		else
			g.unStraightened=false
		end
	end
	mx = x
	my = y
----------------------Warping Back ----------------------
--[[	if CheckWarping() then -- panningview, warping back when panning view or reholding shift
		widgetHandler:UpdateWidgetCallIn("DrawWorld", self)
		--if camPosChange then widgetHandler:UpdateWidgetCallIn("DrawWorld", self) end
	end--]]
---------------------------------------------------------
	-----
--Echo("(warpBack==ready) is ", (warpBack=="ready"))
	--end

	--pos = pos or false ??
	if pos then
		--Echo("stepping is ", not stepping and WG.map[pos[1]][pos[3]])
--		local tmpPointX, tmpPointZ = toValidPlacement(pos[1],pos[3],p.oddX,p.oddZ)
		local afar
		--local newx = floor((pos[1] + 8 - p.oddX)/16)*16 + p.oddX
		--local newz = floor((pos[3] + 8 - p.oddZ)/16)*16 + p.oddZ
		pos = {UniTraceScreenRay(x,y,not p.floater,p.sizeX,p.sizeZ)}
		if PID==mexDefID and GetCloseMex then
			local x,y,z = pos[1],pos[2],pos[3]
			local spot = GetCloseMex(x,z)
			if spot and not cantMex[spot] then 
				-- specs[#specs+1]={spot.x,spot.z,r=1}
				-- if not sp.GetUnitsInRectangle(spot.x,spot.z,spot.x,spot.z)[1] then
				if IsMexable(spot) then
					specs[#specs+1]={spot.x,spot.z,r=1}
				end
				cantMex[spot]=true
			end

			return
		end

		local newx,newy,newz = pos[1],pos[2], pos[3]
		local railLength = #rail
		local lasR = rail[railLength]
		local gapx,gapz
		if lasR then
--			gapx = abs( pointX - newx ) or 10000
--			gapz = abs( pointZ - newz ) or 10000
			gapx = abs( newx - lasR[1] ) or 10000
			gapz = abs( newz - lasR[3] ) or 10000
			if gapx<16 and gapz<16 then
				return
			end
-- 
			straight, locked, pos[1], pos[3], railLength = GoStraight(alt,newx,newz,railLength) -- transform to 8-directional if asked

			newx,newz= pos[1],pos[3]
			lasR = rail[railLength]

		end
		if PID==geos.defID then
			newx = floor((newx + 8 - p.oddX)/16)*16 + p.oddX
			newz = floor((newz + 8 - p.oddZ)/16)*16 + p.oddZ
			local geoX,geoZ = geos:Update(newx,newz)
			if geoX then 
				pointX,pointZ = geoX,geoZ
				specs.n=specs.n+1
				specs[specs.n]={geoX,geoZ,r=1}
			end
			return
		end
		pointX, pointZ = newx, newz
		local px,py,pz = newx,newy,newz

		local primRailLength = #primRail
		local specsLength = #specs


--[[		
		local pointsChanged = not pointX or  ( abs(tmpPointX-pointX)>=p.footX or abs(tmpPointZ-pointZ)>=p.footZ )
		if not pointsChanged then return end
--]]		
			--mousePos[1] = {mx,my}
		--if special then AdaptForMex(p.radius,p.name) end

--[[		if not mousePos[1] then
			mousePos[1] = {toMouse(specs[1])}

			widgetHandler:UpdateWidgetCallIn("DrawWorld", self)
		end--]]



--[[		if #specs<#rail then
			rail[#rail]=nil
			--rail[#rail]=nil
		end
		rail[#specs]=rail[#specs] or {}		
--]]

		--local curail = rail[#specs]

--		if #curail==0 then curail[1]={px,py,pz} end
--		if #rail==0 then curail[1]={px,py,pz} end


--Echo("after", #curail)
--		local x,y,z = unpack(curail[#curail])

---------- Remove rail on Backward ------------------------------------------------------------------
		-- comparing distance of 
		-- i-rail/cursor, i-rail/last placement, i-rail/last rail and last rail/cursor
		-- in order to erase the rail when cursor going backward
		if status~='paint_farm' and (not locked or clock()-locked>0.3) then

			if not rail[railLength] then error("No Rail Length") end
			local x,y,z = unpack(rail[railLength])
			local factor = Cam and Cam.relDist or GetCameraHeight(sp.GetCameraState())
			local llasP, llasPx,llasPz, llasP_To_Cur = specs[specsLength-1]
			if llasP then
				llasPx,llasPz = llasP[1],llasP[2]
				llasP_To_Cur = (llasPx-px)^2 + (llasPz-pz)^2 
			end

			local lasP, lasPx,lasPz, lasP_To_Cur = specs[specsLength]
			if lasP then
				lasPx,lasPz = lasP[1],lasP[2]
				lasP_To_Cur = (lasPx-px)^2 + (lasPz-pz)^2 
			end

			if llasP and llasP_To_Cur<prev.llasP_To_Cur and prev.llasP_To_Cur<factor then
				for i=llasP.r+1,railLength do rail[i]=nil end
				railLength = llasP.r
				if not railLength then error("NO Rail Length but got Llasp") end
				lasP = llasP

				if special then
					UpdateMexes(lasPx,lasPz,'remove',specsLength)
				end
				specs[specsLength]=nil
				specsLength=specsLength-1
				if special then allGrids={} for i=1,specsLength do for k in pairs(specs[i].grids) do allGrids[k]=true end end end

				--Echo('removed rails to previous of last spec')
			elseif lasP and lasP_To_Cur<prev.lasP_To_Cur and prev.lasP_To_Cur<factor then
				for i=lasP.r+1,railLength do rail[i]=nil end
				railLength = lasP.r
				if not railLength then error("NO RAIL LENGTH") end
				--Echo('removed rails to last spec')
			else			
				-- removing rail by distance of the cursor from a variable number of last rail points (depending on zoom)
				local lasRx,lasRy,lasRz = unpack(rail[railLength])
				--local fact = GetCameraHeight(sp.GetCameraState())/1000 -- more tolerance as more zoomed out
				--local fact = sp.GetBuildSpacing()
				--local fact = sp.GetBuildSpacing() + GetCameraHeight(sp.GetCameraState())/1000
				local fact = (Cam and Cam.relDist or GetCameraHeight(sp.GetCameraState()))/1000 --* sp.GetBuildSpacing() / 3
				-- Echo('---st')
				if not lasR.mex then
					for i=railLength-1, railLength-(7+fact)+(lasR.straight and 5 or 0)+(lasR.mex and 10 or 0), -1 do
						local ri = rail[i]
						if ri then
							if ri.mex then
								break
							end
							local rix,riy,riz=ri[1],ri[2],ri[3]
							local lasR_To_Cur = (lasRx-px)^2 + (lasRz-pz)^2 --
							local ri_To_Cur  = (rix-px)^2    + (riz-pz)^2 -- distance ri to cursor
							local ri_To_LasR = (rix-lasRx)^2 + (riz-lasRz)^2 -- distance ri to last rail point
							local ri_To_LasP = lasP and (rix-lasPx)^2 + (riz-lasPz)^2 -- distance ri to last placement

							if  ri_To_Cur<ri_To_LasR or specsLength==1 and railLength<8 and lasP_To_Cur<ri_To_LasP then
								rail[railLength]=nil
								railLength=railLength-1
								lasRx,lasRy,lasRz = unpack(rail[railLength])

								if lasP and lasP.r>railLength then
									--Echo('remove spec')
	--[[								if mexes[specsLength] then
										local smexes = mexes[specsLength]
										for i=1,#smexes do cantMex[GetCloseMex(smexes[i][1],smexes[i][2])]=nil	end
										mexes[specsLength]=nil
									end--]]
									if special then 
										UpdateMexes(lasPx,lasPz,'remove',specsLength)
									end
									specs[specsLength]=nil
									specsLength=specsLength-1
									if special then allGrids={} for i=1,specsLength do for k in pairs(specs[i].grids) do allGrids[k]=true end end end
									lasP=specs[specsLength]
								end
							end
							--Echo('rail reduced, now: '..railLength, 'processed: '..rail.processed )
						end
					end
				end
			end
		end


--[[			local lasR,llasR = rail[railLength],rail[railLength-1]
			if llasR then
				local gapx = abs(lasR[1]-llasR[1])
				local gapz = abs(lasR[3]-llasR[3])
				if gapx<16 and gapz<16 then
					Echo('removed rail because of gap')
					rail[railLength]=nil
					railLength=railLength-1
					lasRx,lasRy,lasRz = unpack(rail[railLength])

					if lasP and lasP.r>railLength then
						Echo('remove spec because of gap')
						specs[specsLength]=nil
						specsLength=specsLength-1
						lasP=specs[specsLength]
					end
				end
			end--]]


			prev.lasP_To_Cur = lasP_To_Cur or 0
			prev.llasP_To_Cur = llasP_To_Cur or 0
			prev.
			rail.n = railLength
			rail.processed =   
							   specs.n~=specsLength and (lasP and lasP.r)
--[[					       			(   specs.n==specsLength+1 and (lasP and lasP.r)
					       		     or specs.n==specsLength+2 and (llasP and llasP.r)	 )--]]
						       or railLength
			-- if specs.n~=specsLength and not (lasP and lasP.r) then error("NO LASP") end
			if not railLength then error("ERR NO rail Length") end
			local lasR, llasR = rail[railLength], rail[railLength-1]

			--Echo("rail.processed is ", rail.processed)


--[[			if specsLength==0 then 
				specs[1]={rail[1][1],rail[1][3],r=1}
				specsLength=1
				lasP = specs[1]
				Echo('back to 1')
			end--]]
			--rail.processed = lasP and lasP.r or 1
			--rail.processed = railLength
			--if not rail[rail.processed] then Echo('wrong',rail.n,lasP.r) end


			specs.n = specsLength
---------------- UPDATING RAIL --------------------
	

	--if not special then

		--if abs(x-px)>=16 or abs(z-pz)>=16 then
--[[			primRail.n=primRail.n+1
			primRail[primRail.n]={px,py,pz}--]]
			primRailLength = primRailLength+1
			primRail[primRailLength]={px,py,pz}
--[[			rail.n=rail.n+1
			rail[rail.n]={px,py,pz}--]]
			railLength = railLength+1
			rail[railLength]={px,py,pz,n=railLength} -- depending on mouse speed points will not be evenly positionned, but we will use them to fill the blanks and normalize their distance
			-- this can be used to transform points into valid placement point
			--Echo("Update send normalize is ")
			-- NormalizeRail() -- this will complete and normalize the rail, as the mouse go too fast
			newmove=true
			rail.n = railLength
			primRail.n = primRailLength
			-- PoseOnRail()
			--if not special then return end

		--updateRail()		
		--end
		--
		prev.dist_drawn = prev.dist_drawn + (abs(prev.mx - mx)^2 + abs(prev.my - my)^2) ^ 0.5
		prev.mx, prev.my = mx,my
		prev.pos = pos
		if rail[2] then
			previMex={}
		 	local update = NormalizeRail() -- this will complete and normalize the rail by separating/creating each point by 16, no matter the speed of the mouse
		 	if update then
				NormalizeRail()
				if special then
					PoseSpecialOnRail()
				elseif status=='paint_farm' then
					Paint()
				else
				 	PoseOnRail()
				end
			end
		end
	end
end

--------------------------------------------------------------------------------
-- Graphics
--------------------------------------------------------------------------------
local drawValue = true
local glLists = {}
do
	local GL_LINE_STRIP		= GL.LINE_STRIP
	local GL_LINES			= GL.LINES
	local GL_POINTS			= GL.POINTS
	local GL_ALWAYS			= GL.ALWAYS


	local glVertex			= gl.Vertex
	local glLineWidth   	= gl.LineWidth
	local glColor       	= gl.Color
	local glBeginEnd    	= gl.BeginEnd
	local glPushMatrix 		= gl.PushMatrix
	local glPopMatrix		= gl.PopMatrix
	local glText 			= gl.Text
	local glDrawGroundCircle=gl.DrawGroundCircle
	local glPointSize 		= gl.PointSize
	local glNormal 			= gl.Normal
	local glDepthTest		= gl.DepthTest
	local glTranslate 		= gl.Translate
	local glBillboard       = gl.Billboard
    local GL_POINTS			= GL.POINTS
    local glCallList		= gl.CallList

    local ToScreen = Spring.WorldToScreenCoords

    local white 			= {1,1,1,1}
    -- local pointList
    -- local listSize = 0

    local font            		= "LuaUI/Fonts/FreeMonoBold_12"
    local UseFont 				= fontHandler.UseFont
    local TextDrawCentered 		= fontHandler.DrawCentered


	glLists.point = gl.CreateList(
		glBeginEnd,GL.POINTS,
			function()
 				glNormal(1, 0, 1)
 				glVertex(1, 0, 1)
			end
	)




    local function drawPoints()
    	-- UseFont(font)
		if Points[4000] then
			Points = {}

			if table.size(glLists) > 500 then
				local simplepoint = glLists.point
				glLists.point = nil
				for k, l in pairs(glLists) do
					gl.DeleteList(l)
					glLists[k] = nil
				end
				glLists.point = simplepoint

			end
		end

        for i,p in ipairs(Points) do
            glPushMatrix()	
            -- local mx,my = ToScreen(unpack(p))                   
            --glColor(waterColor)
	        glTranslate(unpack(p))
	        glBillboard()
            glColor(p.color or white)
            -- if p.txt then my=my-10 end
            -- glText(i..(p.txt or ' '), mx-5, my, 10) 
			-- TextDrawCentered((p.txt or i), mx-3, my)
			local strID = 'point'..(p.txt or i)..'-'..(p.size or 10)
			local list  = glLists[strID]
			if not list then
				list = gl.CreateList(glText, (p.txt or i), -3, -3, p.size or 10)
				glLists[strID] = list
			end
			glCallList(list)
            -- glText((p.txt or i), -3, -3, p.size or 10) 

            glPopMatrix()
            --glPointSize(10.0)
            --glBeginEnd(GL.POINTS, pointfunc,x,y,z)
        end

    end
	function widget:DrawScreen()
	    glColor(1,1,1,1)

		local resX, resY = widgetHandler:GetViewSizes()
	    -- gl.PushMatrix()
	    -- gl.BeginText()
	    -- glColor(1,1,1,1)
	    -- glColor(1,0.5,1,1)
	    -------------------------
	 -- 	if Points[1] then
		-- 	drawPoints()
		-- end

	    -------------------------

	    -----------------
		if PID and ctrl and (alt or shift) then
			if not (PID == mexDefID and WG.metalSpotsByPos) then
				local sx,sz = p.sizeX,p.sizeZ
				UseFont(font)
				if sx==sz then
					local x,y,z = unpack(pos)
					local mx,my = ToScreen(x,y,z)
			        -- glPushMatrix()
			        -- glTranslate(x,y,z)
			        -- glBillboard()
			        
			        glColor(f.COLORS.yellow)

			        TextDrawCentered('f:'..((FARM_SPREAD[PID] or 1) + 1)..'|'..(FARM_SCALE[PID] or 0), mx + 15,my + 15)
			        -- glPopMatrix()
			    end
			end
		end

        -- debugging

		glColor(0.7,0.7,0.7,1)
	    glText(format(status), 0,resY-110, 25)
		if drawEnabled then
	       	glText(format("Drawing"), 0,resY-68, 25)

			-- if pushRail then
			-- 		glPushMatrix()	
		 --       		glText(format("pushing"), 0,resY-150, 25)
		 --            glPopMatrix()
			-- end
	       	if special then
	       		glColor(0.7,0.7,0,1)
	       		glText(format("eBuild"), 0,resY-89, 25)
	       	end
	    end
		glColor(1,1,1,1)
	end

	local function DrawRect(x,z,sx,sz)
		local strID = sx..'-'..sz
		local list = glLists[strID]
		if not list then
			list = gl.CreateList(
				glBeginEnd, GL_LINE_STRIP,
				function()
					glVertex( sx, 0,  sz)
					glVertex( sx, 0, -sz)
					glVertex(-sx, 0, -sz)
					glVertex(-sx, 0,  sz)
					glVertex( sx, 0,  sz)
				end
			)
			glLists[strID] = list
		end
		glPushMatrix()
		glTranslate(x, sp.GetGroundHeight(x,z), z)
		glCallList(list)
		glPopMatrix()

	end
	local gluDrawGroundRectangle = gl.Utilities.DrawGroundRectangle
	local function DrawRectangleLine(t,pl,mex)
		--[[h = h+3--]]
		 --h = pointY == 0.1 and  h+3 or h
		 local h = sp.GetGroundHeight(t[1], t[2])
		 if h<0 and (mex or p.floater) then
		 	h=0
		 end
		 local x,z,sx,sz = t[1],t[2]
		 if pl then
		 	if t[4] then
		 		sx,sz = t[3],t[4]
		 	else
		 		local defid=t[3]
		 		sx,sz = UnitDefs[defid].xsize*4,UnitDefs[defid].zsize*4
		 	end
		 elseif mex then
		 	sx,sz = 24,24
		 else
		 	sx,sz = p.sizeX,p.sizeZ
		 end
		 
		glVertex(x + sx, h, z + sz)
		glVertex(x + sx, h, z - sz)
		glVertex(x - sx, h, z - sz)
		glVertex(x - sx, h, z + sz)
		glVertex(x + sx, h, z + sz)
	end

	local lassoColor = {0.2, 1.0, 0.2, 0.8}
	local edgeColor = {0.2, 1.0, 0.2, 0.4}
	local waterColor = {0.2, 0.0, 1.0, 0.4}
	local red = {1, 1, 1, 1}
	function widget:DrawWorld()


	    -- if pointList then
	    -- 	local size = #Points
	    -- 	if listSize~=size then
	    -- 		gl.DeleteList(pointList)
	    -- 		listSize = 0
	    -- 		pointList = false
	    -- 	end
	    -- end
	    -- if Points[1] and not pointList then
	    -- 	listSize = #Points
	    -- 	pointList = gl.CreateList(drawPoints)
	    -- end
	    -- if pointList then
	    -- 	glPushMatrix()
	    -- 	-- glTranslate(0,0,resY/2)
	    -- 	glCallList(pointList)
	    -- 	glPopMatrix()
	    -- end

	    drawPoints()

	--Echo("not (warpBack==hold) is ", not (warpBack=="hold"))
		--if #rail==0 then return end
	--[[	if not drawEnabled and not (warpBack=="hold" and #specs>0) then
			widgetHandler:RemoveWidgetCallIn("DrawWorld", self)

			return
		end--]]

		-- DRAW M GRIDS
	--[[	local spotsPos=WG.metalSpotsByPos
		for x,t in pairs(spotsPos) do
			for z,n in pairs(t) do
			    glPushMatrix()
		        glTranslate(x,sp.GetGroundHeight(x,z),z)
		        glBillboard()
		        glColor(1, 1, 0, 0.6)
		        glText('m'..n, 0,0,30,'h')
		        glPopMatrix()
		        glColor(1, 1, 1, 1)
			end
		end--]]
		--
	    -- DRAW GROUND CIRCLE OF RADIUS
	--[[	if pos and PID and E_SPEC[PID] then 
			local mx,my = sp.GetMouseState()
			local	_, pos = sp.TraceScreenRay(mx, my, true, false, false, not p.floater)
			if pos then
				local ud = UnitDefs[PID]
			  	glColor(lassoColor)
				glDrawGroundCircle(pos[1],pos[2],pos[3], E_RADIUS[PID], 32)
			end
		end--]]
		-------
		if showRail then
			if primRail[1] then
				glColor(1.0, 0.0, 0.5, 0.4)
				glPointSize(1.0)
				for i=1, #primRail do
					local pr = primRail[i]
					glPushMatrix()
					glTranslate(pr[1], pr[2], pr[3])
					glCallList(glLists.point)
					glPopMatrix()
				end
				glColor(1, 1, 1, 1)
			end



			local railn=rail.n
			if railn>0 then
				glPointSize(2.5)
				for i=1, railn do
					local x,y,z = unpack(rail[i])
					if y<0 and p.floater then y=0 end
					glColor(1,1,1,1)
					local r = rail[i]
					if r.color then glColor(r.color) 
					elseif r.done then glColor(1,0,0,1) 
					elseif r.pushed then glColor(1,1,1,1) 
					end
					glPushMatrix()
					glTranslate(x,y,z)
					glCallList(glLists.point)
					glPopMatrix()
		--[[			if i==railn and E_SPEC[PID] then
				  		glColor(lassoColor)
				  		local ud=UnitDefs[PID]

						glDrawGroundCircle(x,y,z, (p.radius), 32)
						glBeginEnd(GL_LINE_STRIP, DrawRectangleLine, {x,z},nil,true) end
					glColor(1, 1, 1, 1)--]]
				end
				glPointSize(1.0)
				glColor(1, 1, 1, 1)
			end
		end





	--[[	if #rail>0 then
			for i=1, #rail do
				for j=1,#rail[i] do
					local x,y,z = unpack(rail[i][j])
					glColor(lassoColor)
					glPointSize(5.0)
					  glBeginEnd(GL.POINTS, function()
		    		glNormal(x, y, z)
		    		glVertex(x, y, z)
					  end)
					glPointSize(1.0)
					glColor(1, 1, 1, 1)
				end
			end
		end--]]
		-- showing the paint_farming spread
		-- if PID and ctrl and (alt or shift) then
		-- 	if not (PID == mexDefID and WG.metalSpotsByPos) then
		-- 		local sx,sz = p.sizeX,p.sizeZ
		-- 		UseFont(font)
		-- 		if sx==sz then
		-- 			local x,y,z = unpack(pos)
		-- 	        glPushMatrix()
		-- 	        glTranslate(x,y,z)
		-- 	        glBillboard()
		-- 	        glColor(f.COLORS.yellow)
		-- 	        -- glText('f:'..(FARM_SPREAD[PID] or 1)..'|'..(FARM_SCALE[PID] or 0), -sx,sx,30,'h')
		-- 	        TextDrawCentered('f:'..(FARM_SPREAD[PID] or 1)..'|'..(FARM_SCALE[PID] or 0), -sx,sx)
		-- 	        glPopMatrix()
		-- 	    end
		-- 	end
		-- end
		-- draw farm rectangle in diagonal
		if status == 'erasing' then
			local factor = g.erase_factor
			local sx,sz = p.terraSizeX * factor, p.terraSizeZ * factor
			local x,z = pos[1], pos[3]
			glColor(eraser_color)
			gluDrawGroundRectangle(x-sx,z-sz,x+sx,z+sz)
			glColor(1,1,1,1)
		end
		if PID and ctrl and (shift or alt) and pos then
			if not (PID == mexDefID and WG.metalSpotsByPos) then
				local sx,sz = p.sizeX,p.sizeZ
				gl.DepthTest(GL.ALWAYS)
				if sx==sz then
					glColor(f.COLORS.yellow)
					-- local x,y,z = unpack(pos)
					local spread = FARM_SPREAD[PID] or 1
					local scale = FARM_SCALE[PID] or 0
					x,y,z=UniTraceScreenRay(mx,my,not p.floater,sx,sz)
					-- x,y,z = unpack(pos)
					x = floor((x + 8 - p.oddX)/16)*16 + p.oddX
					z = floor((z + 8 - p.oddZ)/16)*16 + p.oddZ
					-- local limit = (sx+oddx+scale*8)-(scale%2)*8
					if spread%2==1 then
						x = x-p.oddX+(scale%2)*8
						z = z-p.oddZ+(scale%2)*8
					end
					for i=-spread,spread,2 do
						local sx,sz = sx,sz
						if i == 0 and status~='paint_farm' then -- for the middle square to be visible despite the build drawn
							sx,sz = sx+3, sz+3
						end
						DrawRect(x+i*(sx+scale*8),z+i*(sz+scale*8),sx,sz)
						-- glBeginEnd(GL_LINE_STRIP, DrawRectangleLine, {x+i*(sx+scale*8), z+i*(sz+scale*8), sx, sz}, true)
					end
			    end
			    gl.DepthTest(false)
			end
		end
		--
		local overlapped_ln = #overlapped
		if overlapped_ln>0 then
			glColor(1,0.3,0,1)
			for i=1, overlapped_ln do
				--Draw the placements
				local ol = overlapped[i]
				--if ol.tf then glColor(1,0.3,0,1) end
				local width = 3-(overlapped_ln-i)
				glLineWidth(width>1 and width or 1)
				glBeginEnd(GL_LINE_STRIP, DrawRectangleLine, ol, true)
			end
			glLineWidth(1.0)
			glColor(1, 1, 1, 1)
		end
		if previMex[1] then
			glColor(1,0.7,0,1)
			for i=1,#previMex do
				local mex = previMex[i]
				DrawRect(mex[1],mex[2],24,24)
				-- glBeginEnd(GL_LINE_STRIP, DrawRectangleLine, previMex[i],nil,true)
			end
			glColor(lassoColor)
		end
		local specLength = #specs

		if specLength>0 then
			glColor(lassoColor)
			local sx,sz = p.sizeX, p.sizeZ
			for i=1, specLength do
				--Draw the placements
				local spec = specs[i]
				if spec.tf then glColor(1,0.3,0,1) end
				local width = (6.5-(specLength-i))/2

				glLineWidth(width>1 and width or 1)
				DrawRect(spec[1],spec[2],sx,sz)
				-- glBeginEnd(GL_LINE_STRIP, DrawRectangleLine, spec)

				local mexes = mexes[i]
				if mexes then
					glColor(1,0.7,0,1)
					for i=1,#mexes do
						-- glBeginEnd(GL_LINE_STRIP, DrawRectangleLine, mexes[i],nil,true)
						local mex = mexes[i]
						DrawRect(mex[1],mex[2],24,24)
					end
					glColor(lassoColor)
				end
				
			end
			local lasmexes = mexes[specLength+1]
			if lasmexes then
				glColor(1,0.7,0,1)
				for i=1,#lasmexes do
					local mex = lasmexes[i]
					DrawRect(mex[1],mex[2],24,24)
					-- glBeginEnd(GL_LINE_STRIP, DrawRectangleLine, lasmexes[i],nil,true)
				end
				glColor(lassoColor)
			end
			glLineWidth(1.0)
			glColor(1, 1, 1, 1)
		end
	end
end


function DPCallin(self) -- homemade callin -- not used anymore
    Echo("TRIGGERED2", self.value)
end
function widget:GameFrame(gf)
	-- widgetHandler:RemoveWidgetCallIn('GameFrame',self)
end
function widget:PlayerChanged()
	myTeamID = sp.GetMyTeamID()
end

function widget:AfterInit()
	geos:Get()
	GetCloseMex= WG.metalSpots and WG.GetClosestMetalSpot
	widget.Update = widget._Update
	widget._Update = nil
end
function widget:Initialize()
	--widget._UpdateSelection = widgetHandler.UpdateSelection
	--widgetHandler.UpdateSelection = widget.UpdateSelection
  	if Spring.GetSpectatingState() or Spring.IsReplay() then
    	-- Spring.Echo("DrawPlacement disabled")
   		-- widgetHandler:RemoveWidget(self)
   		-- return
   		widgetHandler:RemoveWidgetCallIn('UnitCommand',widget)
  	end
  	widget:PlayerChanged()
  	PBH = widgetHandler:FindWidget('Persistent Build Height 2')
  	local w = widgetHandler:FindWidget('Selection Modkeys')
  	Cam = WG.Cam
  	if w then
		SM_enable_opt = w.options.enable
		do
			local isEnabled
			switchSM = function(backup) 
				isEnabled = SM_enable_opt.value
				if backup then 
					if isEnabled then
						SM_enable_opt.value = true
					end
				else
					isEnabled = SM_enable_opt.value
					if isEnabled then
						SM_enable_opt.value = false
					end

				end
			end
		end
	else
		switchSM = function() end
	end
	widget._Update = widget.Update
	widget.Update = widget.AfterInit
	widgetHandler:UpdateWidgetCallIn('GameFrame',widget)
	Spring.AssignMouseCursor(CURSOR_ERASE_NAME, CURSOR_ERASE, true, false)
	GetCloseMex = WG.metalSpots and WG.GetClosestMetalSpot
	WG.drawingPlacement = false
	Debug = f.CreateDebug(Debug,widget,options_path)
    if WG.HOOKS then
        WG.HOOKS:HookOption(widget,'Lasso Terraform GUI','structure_holdMouse',DPCallin)
    end

	-- if Spring.GetGameFrame()>0 then widget:GameFrame() end
	widget:CommandsChanged()
end

function widget:SetConfigData(data)
	if data.DP then
		noDraw = data.DP.noDraw
		-- pushRail = data.DP.pushRail
		FARM_SPREAD = data.DP.spreads or FARM_SPREAD
		FARM_SCALE = data.DP.scales or FARM_SCALE
	end
    if data.Debug then
        Debug.saved = data.Debug
    end
end
function widget:GetConfigData()
	--Echo("noDraw is "
	local ret = {DP={noDraw=noDraw,pushRail=pushRail,test = false,spreads=FARM_SPREAD, scales=FARM_SCALE}}
    if Debug and Debug.GetSetting then
        ret.Debug = Debug.GetSetting()
    end
    return ret
end



function widget:Shutdown()
	--widgetHandler.UpdateSelection = widget._UpdateSelection
	--widget.UpdateSelection = widget._UpdateSelection
	reset()
	WG.drawEnabled=false
	WG.drawingPlacement = false
	for k, list in pairs(glLists) do
		gl.DeleteList(list)
		glLists[k] = nil
	end
end
f.DebugWidget(widget)



