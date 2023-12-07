

-- Author Helwor
-- License GPL v2 or v3
-- now registering only what we need from global before we change environment, aswell will quicken access

local Echo      		= Spring.Echo
local round 			= math.round
local abs 				= math.abs
local sqrt				= math.sqrt
local floor 			= math.floor
local ceil 				= math.ceil
local huge 				= math.huge
local max				= math.max
local atan2 			= math.atan2
local sin 				= math.sin
local cos 				= math.cos
local pi				= math.pi
local pi2				= pi*2

local t 				= type
local type 				= type
local table 			= table
local pairs 			= pairs
local ipairs 			= ipairs
local next 				= next
local debug     		= debug
local tostring  		= tostring
local tonumber  		= tonumber
local getfenv   		= getfenv
local string 			= string
local unpack 			= unpack
local loadstring		= loadstring
local debug     		= debug
local setmetatable 		= setmetatable
local getmetatable 		= getmetatable
local math 				= math
local coroutine 		= coroutine
local select 			= select
local pcall 			= pcall
local xpcall 			= xpcall
local error 			= error
local setfenv 			= setfenv
local rawset 			= rawset
local include 			= include
local find 				= find
local gettable_event 	= gettable_event
local loadstring 		= loadstring
local char				= string.char
local os				= os
local io				= io
local CMD 		   = CMD
local Game 		   = Game
local UnitDefs 	   = UnitDefs
local UnitDefNames = UnitDefNames
local FeatureDefs  = FeatureDefs
local WG 		   = WG
local clock 	   = os.clock

local gl 		   = gl

local glVertex     = gl.Vertex


local Spring = Spring

local sp = {

	GetActiveCommand 		= Spring.GetActiveCommand,
	SetActiveCommand 		= Spring.SetActiveCommand,
	GetMouseState    		= Spring.GetMouseState,
	TraceScreenRay  	 	= Spring.TraceScreenRay,
	GetGroundHeight  		= Spring.GetGroundHeight,
	GetSelectedUnits 		= Spring.GetSelectedUnits,
	GetModKeyState   		= Spring.GetModKeyState,
	GetUnitDefID	 		= Spring.GetUnitDefID,
	GetFeatureDefID         = Spring.GetFeatureDefID,
	ValidFeatureID			= Spring.ValidFeatureID,
	GetSelectedUnits 		= Spring.GetSelectedUnits,
	GetUnitTeam      		= Spring.GetUnitTeam,
	GetMyTeamID      		= Spring.GetMyTeamID,
	GetAllUnits 	 		= Spring.GetAllUnits,
	GetCommandQueue  		= Spring.GetCommandQueue,
	GiveOrderToUnit  		= Spring.GiveOrderToUnit,
	GiveOrderToUnitArray  	= Spring.GiveOrderToUnitArray,
	WarpMouse 		 		= Spring.WarpMouse,
	WorldToScreenCoords 	= Spring.WorldToScreenCoords,
	SendCommands			= Spring.SendCommands,
	ValidUnitID				= Spring.ValidUnitID,
	DiffTimers 				= Spring.DiffTimers,
	GetTimer 				= Spring.GetTimer,
	SendCommands 			= Spring.SendCommands,
	GetSpectatingState 		= Spring.GetSpectatingState,
	GetUnitsInRectangle     = Spring.GetUnitsInRectangle,
	GetUnitPosition 	    = Spring.GetUnitPosition,
	GetFeaturePosition		= Spring.GetFeaturePosition,
	GetBuildFacing			= Spring.GetBuildFacing,
	GetBuildSpacing			= Spring.GetBuildSpacing,
	SetBuildSpacing			= Spring.SetBuildSpacing,

	AreTeamsAllied 			= Spring.AreTeamsAllied,
	GetCameraState			= Spring.GetCameraState,
	SetCameraTarget			= Spring.SetCameraTarget,
	GetTimer 				= Spring.GetTimer,
	DiffTimers				= Spring.DiffTimers,
	SetClipboard 			= Spring.SetClipboard,
	GetClipboard 			= Spring.GetClipboard,
	TableEcho 				= Spring.Utilities.TableEcho
}
local spu = {
	CheckBit				= Spring.Utilities.CheckBit,
	spuIsBitSet 			= Spring.Utilities.IsBitSet,
	spuAndBit 				= Spring.Utilities.AndBit,
}
include("keysym.lua")
local KEYSYMS = KEYSYMS
VFS.Include("LuaRules/Configs/customcmds.h.lua")


VFS.Include("LuaUI/callins.lua")
-- translating commands
local cmdNames = {}
local customCmds = VFS.Include("LuaRules/Configs/customcmds.lua")
local actualCmds={[0]='STOP',[1]='INSERT',[2]='REMOVE',[16]='FIGHT',[20]='ATTACK'}
for k,v in pairs(CMD) do cmdNames[v]=actualCmds[v] or k end
for k,v in pairs(customCmds) do cmdNames[v]=actualCmds[v] or k end
for k,v in pairs(UnitDefs) do cmdNames[-k]='BUILD '..v.name end
--

local mexDefID = UnitDefNames['staticmex'].id


local CallInsMap = CallInsMap

local _, ToKeysyms = include("Configs/integral_menu_special_keys.lua")

local widgetHandler = widgetHandler
local widget = widget 

local mapSizeX, mapSizeZ = Game.mapSizeX, Game.mapSizeZ

--META:		4
--INTERNAL:	8
--RIGHT:	16
--SHIFT:	32
--CTRL:		64
--ALT:		128

local positionCommand = {
	[CMD.MOVE] = true,
	[CMD_RAW_MOVE] = true,
	[CMD_RAW_BUILD] = true,
	[CMD.REPAIR] = true,
	[CMD.RECLAIM] = true,
	[CMD.RESURRECT] = true,
	[CMD.MANUALFIRE] = true,
	[CMD.GUARD] = true,
	[CMD.FIGHT] = true,
	[CMD.ATTACK] = true,
	[CMD_JUMP] = true,
	[CMD_LEVEL] = true,
}
for k,v in pairs(widget) do
    local num = tonumber(v)
    if num and num>39000 and num < 40000 then
        positionCommand[num] = true
    end
end

-- this table declared like that will be traversed in the same order as the mods param passed in KeyPress
local MODS = {alt=false,ctrl=false,meta=false,shift=false}
local WhiteStr   = "\255\255\255\255"
local BlackStr   = "\255\001\001\001"
local GreyStr    = "\255\155\155\155"
local RedStr     = "\255\255\061\061"
local PinkStr    = "\255\255\064\064"
local GreenStr   = "\255\041\255\031"
local BlueStr    = "\255\041\051\255"
local CyanStr    = "\255\031\255\255"
local YellowStr  = "\255\255\255\031"
local MagentaStr = "\255\255\031\255"


local Colors = {
	 white   		= {   1,    1,    1,   1 },
	 black   		= {   0,    0,    0,   1 },
	 grey    		= { 0.5,  0.5,  0.5,   1 },
	 red     		= {   1, 0.25, 0.25,   1 },
	 darkred 		= { 0.8,    0,    0,   1 },
	 lightred 		= {   1,  0.6,  0.6,   1 },
	 magenta 		= {   1, 0.25,  0.3,   1 },
	 rose			= {   1,  0.6,  0.6,   1 },
	 bloodyorange  	= {   1, 0.45,    0,   1 },
	 orange  		= {   1,  0.7,    0,   1 },
	 copper			= {   1,  0.6,  0.4,   1 },
	 darkgreen		= {   0,  0.6,    0,   1 },
	 green   		= {   0,    1,    0,   1 },
     lightgreen     = { 0.7,    1,  0.7,   1 },
     darkenedgreen  = { 0.4,    0.8,  0.4, 1 },
	 lime       	= { 0.5,    1,    0,   1 },
	 blue    		= { 0.3, 0.35,    1,   1 },
     fade_blue      = {   0,  0.7,  0.7, 0.6 },
	 paleblue     	= { 0.6,  0.6,    1,   1 },
     tainted_blue   = { 0.5,    1,    1,   1 },
     turquoise      = { 0.3,  0.7,    1,   1 },
     teal           = { 0.1,    1,    1,   1 },
	 lightblue  	= { 0.7,  0.7,    1,   1 },
     cyan           = { 0.3,    1,    1,   1 },
	 yellow  		= {   1,    1,  0.3,   1 },
     ocre           = {   1,    1,  0.3,   1 },
	 brown   		= { 0.9, 0.75,  0.3,   1 },
	 purple  		= { 0.9,    0,  0.7,   1 },
	 hardviolet 	= {   1, 0.25,    1,   1 },
	 violet  		= {   1,  0.4,    1,   1 },
	 paleviolet  	= {   1,  0.7,    1,   1 },
	 nocolor		= {   0,    0,    0,   0 },
}

---------------------------------------------------------------------------------------------------
local localEnv = {} 
setfenv(1,localEnv) -- setting from now on this env as its own global

--Echo(find("LuaRules/colors.h.lua"))

--RedStr=RedStr
StrCol = {
	white   = "\255\255\255\255",
	black   = "\255\001\001\001",
	grey    = "\255\155\155\155",
	red     = "\255\255\061\061",
	pink    = "\255\255\064\064",
	green   = "\255\041\255\031",
	blue    = "\255\041\051\255",
	cyan    = "\255\031\255\255",
	yellow  = "\255\255\255\031",
	magenta = "\255\255\031\255",
}

local EMPTY_TABLE = {}


CMD_NAMES = cmdNames
COLORS = Colors
UnitDefs = UnitDefs
UnitDefNames = UnitDefNames
FeatureDefs = FeatureDefs
Game = Game
CMD = CMD
table = table
coroutine = coroutine


--[[include( unpack(col))
Echo(col)
Echo("WhiteStr is ", WhiteStr.."TEST")--]]
----------------------------------- SCREEN ------------------------------------
StateToPos = function(fun) -- calculate future camera position from camera State optionally modified by function
	local fun = fun or function(px,py,pz)return px,py,pz end
	local State=sp.GetCameraState()
	local newPx = State.px
	local newPy = State.py-State.dy*State.height
	local newPz = State.pz-State.dz*State.height

	newPx,newPy,newPz = fun(newPx,newPy,newPz)
	return {newPx,newPy,newPz}
end




------------------------------------- MATH ---------------------------------------

asymp = function(n,f) -- asymptote ?
	return 1/n^(f or 2)
end

mathAngle = function (x1,y1, x2,y2)   --Angle de la trajectoire
	if x1 ~= nil and y1 ~= nil and x2 ~= nil and y2 ~= nil then 
		return math.deg(math.atan2(y2-y1, x2-x1))
	end
end

 -- give an average of the lasts values, addcount can be float (for update delta time, in that case, number of table items can be great so think about it when setting the maxcount)
 -- chunk param is used when a great number of count can be expected and we want to reduce the size of the count table so we make little averages then register it as one count
function MakeAverageCalc(maxcount,chunk)
    local n,total_count,total_values,values,counts = 0,0,0,{},{}
    local subcount,subtotal
    if chunk then
        subcount,subtotal = 0, 0
    end
    local remove = table.remove
    local function CalcAverage(value,addcount)
        if value=='reset' then
            n,total_count,total_values,values,counts = 0, 0, 0, {}, {}
            if chunk then
                subcount,subtotal = 0, 0
            end
            return
        end
        if chunk then
            subcount = subcount + addcount
            subtotal = subtotal + value * addcount
            if subcount>=chunk then
                value, addcount = subtotal, subcount
                subcount,subtotal = 0, 0
            else
                return (subtotal + total_values) / (total_count + subcount)
            end
        end

        total_count, total_values = total_count + addcount, total_values + value * addcount
        while total_count > maxcount and n > 0 do -- remove the oldest values when we are at max period
            total_values = total_values - remove(values,1)
            total_count = total_count - remove(counts,1)
            n = n - 1
        end
        n = n + 1
        counts[n], values[n] = addcount, value*addcount
        -- Echo(total_values.." / "..total_count)
        return total_values / total_count
    end
    return CalcAverage
end



nround = function(numb,n) -- round at n close instead of 1 close

	return round(numb/n)*n --- numb%n
end

smallest = function(a,b) return a<b and a or b end
ssmallest= function(a,b) return abs(a)<abs(b) and a or b end
biggest = function(a,b) return a>b and a or b end

sbiggest = function(...) -- biggest absolute
	local args={...}
	args = t(args[1])=="table" and args[1] or args
	local biggest
	biggest={args[1],1}
	for i=2,#args do
		if abs(args[i])>abs(biggest[1]) then
			biggest = {args[i],i}
		end
	end
	return unpack(biggest)
end


s = function (X)
	return X>0 and 1 or X<0 and -1 or 0
end

roughequal = function(a,b,tolerance)
	return abs(a-b)<=tolerance
end

---------------

---------------------------------------- GEOMETRY -------------------------------------

ClampScreenPosToWorld = function (mx,my)
    if not mx then
        mx, my = spGetMouseState()
    end

    local nature,center
    nature,center = sp.TraceScreenRay(mx,my,true,true,true,false)
    -- when mouse fall into the sky
    -- we use the coord from the sky, but the trace goes to 0 height
    -- which will offset when clamping back to map bounds and map height
    -- to avoid this we reask mouse pos from that sky position but lowered by the groundheight of this position
    -- then we reask the world sky version from this new screen pos that will give us a negative offset of the world pos that will be reoffsetted when clamped
    if not center then return end
    -- debugging
    -- local cx,cy,cz,c2x,c2y,c2z = unpack(center)
    -- local height = spGetGroundHeight(center[4],center[6])
    -- Echo(nature .. ' : ' .. round(cx),round(cy),round(cz) .. '   |   ' .. round(c2x),round(c2y),round(c2z) .. '| height: '.. round(height))
    --
    local clamp = function(x,z,off)
    	local off = off or 1
        if x>mapSizeX - off then
            x=mapSizeX - off
        elseif x<off then
            x=off
        end

        if z>mapSizeZ - off then
            z=mapSizeZ - off
        elseif z<off then
            z=off
        end
        return x,z
    end
    if nature == 'sky' then
    	
        -- local height = sp.GetGroundHeight(clamp(center[4],center[6],8))
        local height = sp.GetGroundHeight(center[4],center[6])
        Echo("height is ", height)
        local downBy = height
        center[5] = -height
        -- mx, my = sp.WorldToScreenCoords(center[4],center[5],center[6])
        -- local _
        -- _,center = sp.TraceScreenRay(mx,my,true,true,true,false)
        if not center then return end

        -- if nature == 'ground' then
        --     center[2] = center[2] + spGetGroundHeight(center[1],center[3])
        -- end
        for i=1,3 do table.remove(center,1) end
        center[1], center[3] = clamp(center[1],center[3],8)
        -- if center[1]>mapSizeX - 8 then
        --     center[1]=mapSizeX - 8
        -- elseif center[1]<8 then
        --     center[1]=8
        -- end

        -- if center[3]>mapSizeZ - 8 then
        --     center[3]=mapSizeZ - 8
        -- elseif center[3]<8 then
        --     center[3]=8
        -- end
        -- local upby = sp.GetGroundHeight(center[1],center[3]) - center[2]
        -- Echo('down by ' .. downBy,'upby ' .. sp.GetGroundHeight(center[1],center[3]) - center[2])

        -- center[2] = sp.GetGroundHeight(center[1],center[3])
        -- center[2] = center[2] + height
        mx, my = sp.WorldToScreenCoords(unpack(center)) 
    end
    return mx,my, center, nature
end

function MakeTrail(from,to,step,minstep,maxstep,strict)
	
	local fx,fy,fz = unpack(from)
	local trail,t={{fx,fy,fz}},1
	local tx,_,tz = unpack(to)
	local dist = ( (tx-fx)^2 + (tz-fz)^2 ) ^ 0.5
	-- the remaining to distribute in adaptative mode
	local steps = floor(dist/step)
	if steps==0 then
	end
	step = step+(strict and 0 or dist%step)/steps
	if not strict then 
		step = step + dist%step/steps
		if maxstep and step>maxstep then step=maxstep end
		if steps<2 and minstep then
			steps = floor(dist/minstep)
			step = step+(dist%step)/steps
			step = minstep
		end
	end

	for i=2,steps do
		local dx,dz = (tx-fx)/dist,(tz-fz)/dist
		fx=fx+dx*step
		fz=fz+dz*step
		fy = sp.GetGroundHeight(fx,fz)
		t=i
		trail[t]={fx,fy,fz}
		dist = ( (tx-fx)^2 + (tz-fz)^2 ) ^ 0.5
	end
	if not strict then t=t+1 trail[t]=to end
	return trail,t
end


function clampangle(angle)
	local s = angle<0 and -1 or 1
	if angle*s>pi then angle = - s * (pi - (angle*s-pi) ) end
	return angle,s
end

function turnbest(turn)
	turn = turn % (pi2)
	local s = turn<0 and -1 or 1
	if turn*s>pi then turn, s = -(pi2-turn*s)*s, -s end
	return turn,s
end

UniTraceScreenRay = (function() -- TraceScreenRay usage to keep validity out of map and follow the x or y of the mouse there
	local mapSizeX,mapSizeZ = Game.mapSizeX,Game.mapSizeZ
	local spTraceScreenRay = sp.TraceScreenRay
	local x,y,z
	local offset={0,0,0,set=true}
	local onMap={0,0,0}
	local offMap=false

	return function(mx,my,waterline,mrg_x,mrg_z)
		mrg_x,mrg_z = mrg_x or 0, mrg_z or 0
		local nature,pos =  spTraceScreenRay(mx,my,true,true,true,waterline)
		offMap = nature=='sky'
		if offMap then 
			if not offset.set then
				   offset[1],	  offset[2],   offset[3]
				= onMap[1]-pos[4], onMap[2], onMap[3]-pos[6]
				offset.set=true
			end
			x,y,z = pos[4],pos[5],pos[6]
		else
			x,y,z = pos[1],pos[2],pos[3]
			onMap=pos
			offset.set=false
		end
		if x>mapSizeX-mrg_x then x=mapSizeX-mrg_x elseif x<mrg_x then x=mrg_x --[[elseif offset.set then x=x+offset[1]--]] end
		if z>mapSizeZ-mrg_z then z=mapSizeZ-mrg_z elseif z<mrg_z then z=mrg_z --[[elseif offset.set then z=z+offset[3]--]] end
		return x,y,z,offMap
	end
end)()


	-- CIRCLE MANIP

local pi = math.pi
function area(r)
	return r^2*pi
end

function radius(ar)
	return (ar/pi)^0.5
end
local pi = math.pi
function sq_rad(r)
	-- get the radius of circle having the area of a square inscribing the original circle (diameter 2*r)
	return r*2/pi^0.5
	--return (r^2*4/pi)^0.5
end
function hyp(a,b) -- can be used to get the radius of circle inscribing a square inscribing the original circle: hyp(r,r)
	return (a^2+b^2)^0.5
end

function to_ar(ar,r,n)
	-- augment area by a given number of unit radius
	return ar+ n * r^2*pi
	--return ar+area(r)*n
end
function to_rad(rad,r,n)
	-- augment radius rad of a circle beeing inserted n circles of radius r
	return ( rad^2 + n*r^2 ) ^ 0.5 
	--return radius(area(rad)+(area(r)*n))
end
function in_ar(ar,r)
	-- how many unit of radius r contained in area ar
	return ar/pi/r^2
	--return (radius(ar)/r)^2
	--return ar/area(r)
end
function in_rad(rad,r)
	-- how many unit of r radius are contained in a circle of radius rad
	return (rad/r)^2
	--return area(rad)/area(r)
end




rotate = function (cenx,cenz,x,z,rotation)
	local offx,offz = x-cenx,z-cenz
	local hyp = (offx^2+offz^2)^0.5
	local angle = atan2(offx,offz) + rotation
	return cenx+sin(angle)*hyp,cenz+cos(angle)*hyp
end
MapCoords = function()

	local maxX= Game.mapSizeX
	local maxZ = Game.mapSizeZ

	local corx,corz
	local x,z
	local metx =  {__index = function(t,k)
						if k<0 then return end
						if k>maxX then return end
						corx=(round(k/8)*8)
						x=k~=corx and x
						return t[corx] -- correcting wrong x
					end
					}
	local metz = {	__index = function(t,k)
						corz=(round(k/8)*8)
						z=k~=corx and z
						
						return t[corz] -- correcting wrong x
					end,
					__newindex=function(t,k,v) -- if trying to change value of an unknown index(wrong), the value of the closest is affected
						corz=(round(k/8)*8)
					

						t[corz]=v
						--t[k]=v

					end} -- 
 
	local map={}
	local maxX= Game.mapSizeX
	local maxZ = Game.mapSizeZ

	for x=0, maxX,8 do
		map[x]={}

		for z=0, maxZ,8 do
			map[x][z]=false

		end
		setmetatable(map[x], metz)
	end
	setmetatable(map, metx)
	return map
end

MapRect =function(map,toggle,x,z,sx,sz)
Echo("--++--")
	local str=x..","..z..","..sx..","..sz
--	local sx=sx-32
--	local sz=sz-32
	local midx,midz=x,z
	local hsx,hsz=sx/2,sz/2

	local x,z = midx-hsx-64,midz-hsz-64
	local endx,endz = x+sx+128,z+sz+128
	local oldv,oldx,oldz,newv
	local relx,relz
	local related={}

	local relstr
	for x=x,endx,16 do
		relx=abs(x-midx)
		for z=z,endz,16 do
			relz=abs(z-midz)

			oldv = map.num[x][z]
			local calcul=biggest(relx-hsx,relz-hsz)
			local numx,numz= relx-hsx,relz-hsz
			numx,numz	=	numx>=numz and numx or 64,
							numz>=numx and numz or 64

			if toggle then
				if oldv then 
					oldx,oldz=oldv:match('(%-?%d-),(%-?%d+)')
					--Echo("oldv is ", oldv,oldx,oldz)
					oldx,oldz=tonumber(oldx),tonumber(oldz)
					oldv=smallest(oldx,oldz)
				end
				oldv = oldv  or 1000

				newv = numx..","..numz
				if calcul<oldv then
					map.num[x][z]=newv
					map.rect[x][z]=str
				end
			elseif toggle==false then
				if oldv then 
					oldx,oldz=oldv:match('(%-?%d-),(%-?%d+)')
					--Echo("oldv is ", oldv,oldx,oldz)
					oldx,oldz=tonumber(oldx),tonumber(oldz)
					oldv=smallest(oldx,oldz)
				end
				relstr=map.rect[x][z]
				if relstr and not (relstr==str) and not related[relstr] then
					related[relstr]=true
				end
				if oldv==calcul then
				--local invcalcul=smallest(-relx+(16+64+hsx)+(oldv-calcul),-relz+(16+64+hsz)+(oldv-calcul))
				--local invcalcul=smallest(-relx+(16+64+hsx)-oldv,-relz+(16+64+hsz)-oldv)
					newv=false
					map.num[x][z]=newv
				end
			end
		end
	end
	if toggle==false then
		return related
	end

end

--[[MapRect =function(map,toggle,x,z,sx,sz)
	local sx=sx-32
	local sz=sz-32
	local x,z = x-sx/2, z-sz/2
	local endx,endz = x+sx,z+sz
	for x=x,endx,16 do
		for z=z,endz,16 do
			map[x][z]=toggle
		end
	end
end--]]


minMaxCoord = function(T)
	local i1,first=next(T,nil)
	local firstx,firstz=vunpack(first)
	local minx,maxx,minz,maxz = firstx,firstx,firstz,firstz
	local nex= next(T,i1)
	while nex do
		minx = minx>T[nex][1] and T[nex][1] or minx
		maxx = maxx<T[nex][1] and T[nex][1] or maxx
		minz = minz>T[nex][2] and T[nex][2] or minz
		maxz = maxz<T[nex][2] and T[nex][2] or maxz
		nex= next(T,nex)
	end
	return {{minx,minz},{maxx,maxz}}
end




do
	-- local knownUnits={} -- unused, might need to check if it worth it to memorize buildings
	local invalid={}
	local GetUnitsInRange,           GetUnitsInRectangle,             GetPos,               GetDef,                GetParam
	 = Spring.GetUnitsInCylinder, Spring.GetUnitsInRectangle, Spring.GetUnitPosition, Spring.GetUnitDefID, Spring.GetUnitRulesParam
	local GetUnitInRectangle,		GetUnitBuildFacing,         TestBuildOrder,         GetGroundBlocked
	 = Spring.GetUnitInRectangle, Spring.GetUnitBuildFacing, Spring.TestBuildOrder, Spring.GetGroundBlocked
	local spGetGroundHeight = Spring.GetGroundHeight
	local spuGetMoveType = Spring.Utilities.getMovetype
	local memory = {ex={},pl={}}
	local mexDefID = UnitDefNames["staticmex"].id
	local uds = UnitDefs
	local huge = math.huge
	local spotsPos = WG.metalSpotsByPos
	local spots = WG.metalSpots
	local terraUnitDefID = UnitDefNames['terraunit'].id
	TestBuild = function(px,pz,p,steepness,placed,overlapped,extra,remember,Points, offset)
        offset = offset or 0
		if px=="reset invalid" then	for k,v in pairs(invalid) do invalid[k]=nil end return
		elseif px=="reset memory" then memory={ex={},pl={}} return
		elseif px=="forget_extra" then
			local toForget,Points = pz,p
			for x,col in pairs(toForget) do
				local memx = memory.ex[x]
				if memx then
					for z in pairs(col) do
						memx[z]=nil
						if Points then
							Points[#Points+1]={x,spGetGroundHeight(x,z),z}
						end
					end
					if not next(memx) then memory.ex[x]=nil end
				end
			end
			return
		elseif type(p)=="number" then p=IdentifyPlacement(p)
		end


		-- local tsx,tsz=p.terraSizeX,p.terraSizeZ
		local sx,sz = p.sizeX + offset,p.sizeZ + offset
		
		local cantPlace
		local blockingStruct,bln={},0
		local overlapExtra, onPlaced
		local cdist = huge

		local test  = steepness and TestBuildOrder(p.PID, px, 0, pz, p.facing)
		cantPlace = test==0

		if remember then
			blockingStruct = memory[px] and memory[px][pz] or blockingStruct
			overlapExtra = extra and memory.ex[px] and memory.ex[px][pz]
			onPlaced = placed and memory.pl[px] and memory.pl[px][pz]
			if overlapExtra then
				if Points then
					Points[#Points+1]={px,spGetGroundHeight(px,pz),pz}
				end
			end
			cantPlace = blockingStruct[1] or cantPlace
			if blockingStruct[1] or overlapExtra or onPlaced then
				return cantPlace,cantPlace and blockingStruct[1] and blockingStruct,blockingStruct.c,overlapExtra, onPlaced
			end
		end
		--TestBuildOrder will return 0 on either terrain too steep or structure blocking or mex
		--also TestBuildOrder is flawed on checking some factories, we can't rely on it
		--the only use of it will be if the terrain is too steep and we don't have PBH active


		-- Placed Check, ordered buildings
		if placed then 
			for i=1,#placed do
				local ix,iz,isx,isz,defID = unpack(placed[i])
				--overlap check
				local dx,dz = (px-ix)^2, (pz-iz)^2
				if  dx < (sx+isx)^2 and dz < (sz+isz)^2 then
					local dist=dx+dz
					bln=bln+1;blockingStruct[bln]=placed[i]
					cantPlace=true
					onPlaced = true
					if dist<cdist then
						cdist = dist
						if overlapped then overlapped[1]=blockingStruct[bln] end
						if remember then 
							memory[px] = memory[px] or {} ; memory[px][pz]=blockingStruct
							memory.pl[px] = memory.pl[px] or {} ; memory.pl[px][pz]=blockingStruct
						end
						blockingStruct.c=blockingStruct[bln]
					end
				end
			end
		end



		-- Real Unit Check
		local units = GetUnitsInRectangle(px-sx-80,pz-sz-80,px+sx+80,pz+sz+80)
		for i=1,#units do
			local id=units[i]
			local defID = GetDef(id)
			local def = uds[defID]
			if invalid[id] then
				-- nothing to do, invalid in there means that's a moving unit, we don't care about it
			elseif def then
				if defID==terraUnitDefID or spuGetMoveType(def) then
					invalid[id]=true
				else
					local ix,iy,iz = GetPos(id)
					local isx,isz = def.xsize*4,def.zsize*4
					local facing = GetUnitBuildFacing(id) or 0 -- if facing  doesnt return, it's an enemy, we can't do much about it or TODO: should check for each ground blocked
					if facing%2==1 then isx,isz=isz,isx end
					local dx,dz = (px-ix)^2, (pz-iz)^2
					if  dx < (sx+isx)^2 and dz < (sz+isz)^2 then
						cantPlace=true
						local dist = dx+dz
						bln=bln+1; blockingStruct[bln]={ix,iz,isx,isz,dist,defID=defID,id=id}
						if dist < cdist then
							cdist=dist
							if overlapped then overlapped[1]=blockingStruct[bln] end
							if remember then memory[px] = memory[px] or {} ; memory[px][pz]=blockingStruct end
							blockingStruct.c=blockingStruct[bln]
						end
					end
				end
			end
		end
		-- Empty Mex Spot Check
		if p.PID~=mexDefID then
			local spotsPos= spotsPos or WG.metalSpotsByPos
			local spots = spots or WG.metalSpots
			if spotsPos and spots then
				for ix,t in pairs(spotsPos) do
					for iz,n in pairs(t) do
						local spot = spots[n]
						if not GetUnitsInRectangle(ix,iz,ix,iz)[1] then
							local dx,dz = (px-ix)^2, (pz-iz)^2
							if  dx < (sx+24)^2 and dz < (sz+24)^2 then
								cantPlace=true
								local dist = dx+dz
								bln=bln+1; blockingStruct[bln]={ix,iz,24,24,dist,isEmptyMex=true}
								if dist < cdist then
									cdist=dist
									if overlapped then overlapped[1]=blockingStruct[bln] end
									if remember then memory[px] = memory[px] or {} ; memory[px][pz]=blockingStruct end
									blockingStruct.c=blockingStruct[bln]
								end
							end
						end
					end
				end
			end
		end

		if extra then -- check for extra table (projected placements overlap ie: in Drawing Placement widget)
			local ex=0
			local sx,sz = p.sizeX,p.sizeZ
			for i=1,#extra do
				local ix,iz = unpack(extra[i])
				--overlap check
				local dx,dz = (px-ix)^2, (pz-iz)^2
				if  dx < (sx*2)^2 and dz < (sz*2)^2 then
					overlapExtra=overlapExtra or {}
					ex=ex+1 overlapExtra[ex]={ix,iz,sx,sz}
					if remember then
						memory.ex[px] = memory.ex[px] or {} ; memory.ex[px][pz]=overlapExtra
						-- if Points then
					 -- 		Points[#Points+1]={px,spGetGroundHeight(px,pz),pz}
					 -- 	end
					end
				--[[local dist=dx+dz
					bln=bln+1;blockingStruct[bln]={ix,iz,sx,sz,dist}
					if dist<cdist then
						cdist = dist
						if overlapped then overlapped[1]=blockingStruct[bln] end
						c=blockingStruct[bln]
					end
				--]]
				end
			end
		end
		--******* obsolete because of the wrong factory check, we get units in rectangle instead
		--[[-- , if we have PBH active, we have to discern those and ignore if it's because of the terrain
		if WG.PBHisListening then
			local tsx,tsz=p.terraSizeX,p.terraSizeZ
			 for gx=px-tsx, px+tsx-8,8 do
				for gz=pz-tsz, pz+tsz-8,8 do
					local objType,id=GetGroundBlocked(gx,gz,gx+8,gz+8)
					-- as spGroundBlocked return any first found object, it might be a feature when actually a structure is blocking too, we have to be sure about it so we ask square per square
					if objType=='unit' then
						local defId = GetDef(id)
						local def = uds[defId]
						--Page(def)
						if not def.canMove or def.isFactory then
							local ix,iy,iz = GetPos(id)
							local isx,isz = def.xsize*4,def.zsize*4
							local facing = Spring.GetUnitBuildFacing(id)
							if facing==1 or facing==3 then  isx,isz=isz,isx end
							local dist = (ix-px)^2 + (iz-pz)^2
							blockingStruct[#blockingStruct+1]={ix,iz,isx,isz,dist}
							cantPlace=true
							if dist<cdist then
								cx,cz,csx,csz,cdist = ix,iz,isx,isz,dist
								if overlapped then overlapped[1]={cx,cz,csx,csz,cdist} end
							end
						end
					end
				end
			end
		end
		--]]
	--********
		--for i=1, #blockingStruct do overlapped[#overlapped+1]=blockingStruct[i] end
		-- Get the middle point

		-- CANCELLED: this is cancelled because even though it could be placed there physically, the engine will refuse the order anyway
		-- workaround to fix floating unit like hover made by Athena, engine report wrong statement that it cannot be built because terrain under water can be too steep
		-- we have to check if that's the reason
		-- if test==0 and not blockingStruct[1] and not p.needTerraOnWater and spGetGroundHeight(px,pz)<0 then
		-- 	cantPlace=false
		-- 	for x=px-sx, px+sx,8 do
		-- 		for z=pz-sz, pz+sz,8 do
		-- 			if spGetGroundHeight(x,z)>5 then cantPlace=true brokeloop=true break end
		-- 		end
		-- 		if brokeloop then break end
		-- 	end
		-- end

		return cantPlace, cantPlace and blockingStruct[1] and blockingStruct, blockingStruct.c, overlapExtra, onPlaced
	end
end


function PushOut(rx,rz,sx,sz,x,z,obst,p)
	local ix,iz,isx,isz = unpack(obst)
	local dirx,dirz = (x-ix), (z-iz)
	local biggest = math.max(abs(dirx),abs(dirz))
--[[	local mx,my = sp.GetMouseState()
	local _, pos = sp.TraceScreenRay(mx, my, true, false, false, false)
	x,z = pos[1],pos[3]--]]
	dirx,dirz = dirx/biggest, dirz/biggest
--[[	dirx = abs(dirx)<0.5 and 1*sign(dirx) or dirx
	dirz = abs(dirz)<0.5 and 1*sign(dirz) or dirz--]]
	--dirx,dirz = round(dirx), round(dirz)
	--dirx = sign(dirx)-abs(dirx)
	--dirz = sign(dirz)-abs(dirz)


	local tries = 0
	local oddx,oddz = p.oddX,p.oddZ
	--while it is overlapping
	--centerpoint={ix,sp.GetGroundHeight(ix,iz),iz}
	while ((rx-ix)^2 < (sx+isx)^2 and (rz-iz)^2 < (sz+isz)^2) do
		tries=tries+1
		if tries>20 then break end
		x = x+16*dirx
		z = z+16*dirz
		rx = floor((x + 8 - oddx)/16)*16 + oddx
		rz = floor((z + 8 - oddz)/16)*16 + oddz
	end
	--outpoint={x,sp.GetGroundHeight(x,z),z}

	return rx,rz,tries<=20
end

function SpiralSquare(layers,step,callback,offset,reverse,ortho)
	-- LOOP iterating squares clockwise from center to exterior, starting at bottom left corner
	-- reverse is anticlockwise, from exterior to center, starting at top right
	-- first point is always at center if offset is explicit 0
	local brokeloop=false
	offset = offset and offset/step
	local startlayer = offset or 1
	-- Echo("layers,startlayer,step is ", layers,startlayer,step)
	-- reverse mode will start from top right and go anticlockwise
	local ret
	if startlayer==0 then
		ret = callback(0,0,0)
		if ret then return ret end
		startlayer=1
	end
	local inc = 1
	-- reverse: from exterior to interior
	if reverse then
		inc = -inc
		step=-step
		startlayer,layers = layers-(layers+startlayer)%1,startlayer
	end
    local edge
	--
	for layer=startlayer,layers,inc do 
        -- Echo("layer,layers,inc is ", layer,layers,inc)
		local offz = -layer*step
		for s=step,-step,-2*step do -- browse half of perimeter per iteration (positive x and z then negative x and z)
			-- Echo("-layer*s,(layer-1)*s,s is ", -layer*s,(layer-1)*s,s)            
			for offx = -layer*s, (layer-1)*s, s do -- start at first x, end at one step before last x // start at last x end at one step before first x
				for b = offz, layer*s, s do
					offz=b -- memorize b until last iteration -- loop will iterate only once at each second iteration of offx, so z will be stuck while x will change
					ret=callback(layer
                        ,reverse and offz or offx
                        , reverse and offx or offz)
					if ret~=nil then return ret end
				end
			end
		end
	end
end
function SpiralOrthoSquare(layers,step,callback,offset,reverse) -- LOOP iterating squares clockwise from center to exterior, starting at bottom left corner
	local brokeloop=false
	local startlayer = offset and offset/step or 1
	-- Echo("layers,startlayer,step is ", layers,startlayer,step)
	-- reverse mode will start from top right and go anticlockwise
	local ret
	if startlayer==0 then
		ret = callback(0,0,0)
		if ret then return ret end
		startlayer=1
	end

	if reverse then step=-step end
	for layer=startlayer,layers do 
		local offx = 0
		for s=step,-step,-2*step do -- browse half of perimeter per iteration (positive x and z then negative x and z)
			-- Echo("-layer*s,(layer-1)*s,s is ", -layer*s,(layer-1)*s,s)            
			for offz = -layer*s, layer*s, s do -- start at first x, end at one step before last x // start at last x end at one step before first x

			end
			for offx = -layer*s, layer*s, s do -- start at first x, end at one step before last x // start at last x end at one step before first x
				for b = offz, layer*s, s do
					offz=b -- memorize b until last iteration -- loop will iterate only once at each second iteration of offx, so z will be stuck while x will change
					ret=callback(layer,reverse and offz or offx, reverse and offx or offz)
					if ret then return ret end
				end
			end
		end
	end
end
MergeRects = function (T)
	local changed = false
	local a,b=1,2
	local length=l(T)

	while a<length do 
		local newrect = contiguous(T[a],T[b])
		if newrect then
			 T[a]=newrect
			 table.remove(T,b)
			 length=length-1
			 changed = true
		
		else 
			b=b+1
		end
		if b>length then
			a = a+1
			b = a+1
		end
	end


	return changed
end

--[[MergeRects = function (T)
	local changed = false
	local a,r1=next(T,nil)
	

	local b,r2=next(T,a)
	while b do 
		local newrect = contiguous(r1,r2)
		--Page({corners(T[a])})
		if newrect then
			 T[a]=newrect
			 table.remove(T,b)
			 changed = true
		else 
			b=next(T,b)
		end
		if not b then
			a = next(T,a)
			b = next(T,a)
		end
	end
	return changed
end--]]

contiguous = function(rectA,rectB) -- faster
	local a1x,a1z,a2x,a2z,a3x,a3z,a4x,a4z = corners(rectA)
	local b1x,b1z,b2x,b2z,b3x,b3z,b4x,b4z = corners(rectB)
	local newrect = a1x==b4x and a1z==b4z and a2x==b3x and a2z==b3z and {b1x,b1z,b2x,b2z,a3x,a3z,a4x,a4z} or
					a2x==b1x and a2z==b1z and a3x==b4x and a3z==b4z and {a1x,a1z,b2x,b2z,b3x,b3z,a4x,a4z} or
					a2x==b1x and a2z==b1z and a3x==b4x and a3z==b4z and {a1x,a1z,b2x,b2z,b3x,b3z,a4x,a4z} or

					a3x==b2x and a3z==b2z and a4x==b1x and a4z==b1z and {a1x,a1z,a2x,a2z,b3x,b3z,b4x,b4z} or
					a1x==b2x and a1z==b2z and a4x==b3x and a4z==b3z and {b1x,b1z,a2x,a2z,a3x,a3z,b4x,b4z}

	if newrect then
		local n1x,n1z,n2x,n2z,n3x,n3z,n4x,n4z  = unpack (newrect)

		local minx,minz,maxx,maxz = n1x,n1z,n3x,n3z
		local x,z = (minx+maxx)/2, (minz+maxz)/2
		local sx = maxx-minx
		local sz = maxz-minz

		newrect = {x,z,sx,sz}
	end
	return newrect
end

--[[
contiguous = function(rectA,rectB) -- slower
	local a1,a2,a3,a4 = corners(rectA)
	local b1,b2,b3,b4 = corners(rectB)

	local newrect = IsEqual(a1,b4) and IsEqual(a2,b3) and {b1,b2,a3,a4} or
					IsEqual(a2,b1) and IsEqual(a3,b4) and {a1,b2,b3,a4} or
					IsEqual(a3,b2) and IsEqual(a4,b1) and {a1,a2,b3,b4} or
					IsEqual(a1,b2) and IsEqual(a4,b3) and {b1,a2,a3,b4}

	if newrect then
		local na1,na2,na3,na4 = unpack(newrect)
		local minx,minz,maxx,maxz = na1[1],na1[2],na3[1],na3[2]
		local x,z = (minx+maxx)/2, (minz+maxz)/2
		local sx = maxx-minx
		local sz = maxz-minz
		newrect = {x,z,sx,sz}
	end
	return newrect
end
--]]

corners = function(rect,coord,y)
	local x,z,sx,sz = unpack(rect)
	local sx,sz= sx/2,sz/2
	

	local c1x, c1z= x-sx, z-sz
	local c2x, c2z= x-sx, z+sz
	local c3x, c3z= x+sx, z+sz
	local c4x, c4z= x+sx, z-sz
	if coord then
		if y then 
			return {c1x,y,c1z},{c2x,y,c2z},{c3x,y,c3z},{c4x,y,c4z}
		else
			return {c1x,c1z},{c2x,c2z},{c3x,c3z},{c4x,c4z}
		end
	else
		return c1x,c1z,c2x,c2z,c3x,c3z,c4x,c4z
	end
end


MakeHollowRectanglePoints = function(x,z,w,h,inc)
	local startx,endx=x-w,x+w
	local startz,endz=z-h,z+h
	local x,z=startx,startz
	local pointTable={x={startx},z={startz}}
	local px,pz=pointTable.x,pointTable.z
	for inc=1,-1,-2 do
		for x=startx+inc,endx,inc do px[#px+1]=x pz[#pz+1]=z end
		x=endx
		for z=startz+inc,endz,inc do px[#px+1]=x pz[#pz+1]=z end
		z=endz
		startx,endx=endx,startx	
		startz,endz=endz,startz
	end
	return pointTable
end


hollowRectangle = function (x,z,w,h,inc) -- clockwise hollow rectangle generator -- deprecated too expensive
	local startx,endx=x-w,x+w
	local startz,endz=z-h,z+h
	local x,z=startx,startz
	local switch = false
	local starting = true
	local cardinal = "N"
	return function()
		if starting then 
			starting=false	
			return x,z,"NW"
		elseif x==endx then 
			if z==endz then
				cardinal = "S"
				inc=-inc
				switch=true
				startx,startz,endx,endz=endx,endz,startx,startz
			else
				cardinal = switch and "W" or "E"
				z=z+inc
				if z==endz then
					if not switch then 
						return x,z,"SE"
					end
					return
				end
				return x,z,cardinal
			end
		end
		x=x+inc
		if x==endx then 
			return x,z, switch and "SW" or "NE"
		end
		return x,z,cardinal
	end
end


spiral = function(x,z,endx,endz,inc) -- generator spiraling a rectangle from exterior to interior clockwise -- DEPRECATED TOO EXPENSIVE -- QUITE BETTER VERSION IN ZONE FROM DRAW FIRE
	local starting = true
	local inc=inc
	local face=1
	local firstround=true
	return function()
		if starting then starting = false return x,z end
		if i==endi then
			if finishing then return end
			face=face+1
			if face==5 then face=1 end
			if face%2==0 then
				if firstround then endz=z
					firstround=false
				else 
					endz=z+inc 
				end
				z=i
				i,endi=x,endx
				if x==endx then return end
				--Echo("x:"..i.."->"..endi)
			else
				--Echo("endx-(x+inc)<inc is ", endx-(x+inc)<inc)-- A TESTER
				endx=x+inc
				x=i
				i,endi=z,endz
				if z==endz then return end
				inc=-inc
				--Echo("z:"..i.."->"..endi)
			end
		end
		i=i+inc
		if face%2==0 then 
			return i,z
		else
			return x,i
		end
	end
end	

--[[
corners = function(rect)
	local x,z,sx,sz = unpack(rect)
	local sx,sz= sx/2,sz/2


	local c1={x-sx, z-sz}
	local c2={x-sx, z+sz}
	local c3={x+sx, z+sz}
	local c4={x+sx, z-sz}
	
	return c1,c2,c3,c4
end
--]]


rects = function(...)-- making rectangle from id, or from defid or ud if there is  x and y
	local args={...}
	args = t(args[1])=="table" and args or {args}
	local rects={}
	for i=1, #args do
		local ud,x,z = unpack(args[i])
		if not (x and z) then
			x,_,z = GetUnitOrFeaturePosition(ud)
		end
		local ud,res = GetDef(ud)

		local p = IdentifyPlacement(ud)
		local sx,sz = p.sizeX*2,p.sizeZ*2
		table.insert(rects, {x,z,sx,sz})

	end
	return unpack(rects)
end





function pointToGrid(n,...) -- move points to a grid of n 
	local args={...}
	local x,y,z	
	if t(args[1])=="table" then
		args=args[1]
	end
	if l(args)==3 then
		Echo("check")
		x,_,z = unpack(args)
	elseif l(args)==2 then
		x,z = unpack(args)
	end
	x=x+  (  x%n<n/2 and -x%n 
				or (n-x%n)   )

	z=z+  (  z%n<n/2 and -z%n 
				or (n-z%n)   )
	y = sp.GetGroundHeight(x,z)
	return x,y,z
end


GetDist = function (x1,z1,x2,z2)
	-- can use args as table
	local t1,t2 = false,false
	t1 = t(x1)=="table" and x1
	t2 = t(z1)=="table" and z1 or t(x2)=="table" and x2

	z2 = t2 and res(2,next(t2,1)) or t1 and x2 or z2
	x2 = t2 and res(2,next(t2,nil)) or t1 and z1 or x2
	z1 = t1 and res(2,next(t1,1)) or z1
	x1 = t1 and res(2,next(t1,nil)) or x1
	--
	--Echo("", x1,z1,x2,z2)
	return (x1-x2)^2 + (z1-z2)^2
end

validP = function(px,pz,defs) -- quicker
	local oddx=8*((1+defs.xsize/2)%2) -- 8 si la demi taille est pair
	local oddz=8*((1+defs.zsize/2)%2)	
	px= floor((px+oddx)/16)*16+8-oddx
	pz= floor((pz+oddz)/16)*16+8-oddz
	return px,pz
end


validPlacement = function(px,pz,defs) -- explained version
		local oddx=8*((1+ud.xsize/2)%2) -- 8 si la demi taille est pair
		local oddz=8*((1+ud.zsize/2)%2)	
		px=px+oddx -- -- on décale de 8 notre future grille si c'est pair
		pz=pz+oddz
		px=px-px%16 -- on réduit à 0 chaque écart de 16 (0 à 8 => 0 si c'est pair, 0 à 16 => 0 si c'est impair )
		pz=pz-pz%16
		px=px+8-oddx -- on décale de 8 les coordonnées finales si c'est impair
		pz=pz+8-oddz --   pair: (de 0 à 8 =>  0, de 8 à 24 => 16...)
						 -- impair: (de 0 à 16 => 8, de 16 à 32 => 24)
	return px,pz
end
canSub ={
	striderantiheavy=true
	,subtacmissile=true
	,striderdetriment=true
	,amphtele=true
	,cloakjammer=true
	,shieldshield=true
	,factoryamph=true
	,energyfusion=true
	,staticstorage=true
}	
CheckCanSub = function (name)
	return canSub[name]
end
IdentifyPlacement = function (PID,facing)

	local ud = t(PID)=="table" and PID or UnitDefs[PID]
    if not ud then
        Echo('no UD for',PID)
    end
	local facing = facing or sp.GetBuildFacing()
	local offfacing = (facing == 1 or facing == 3)

	local footX = ud.xsize/2
	local footZ = ud.zsize/2

	if offfacing then
		footX, footZ = footZ, footX
	end
	
	local oddX = (footX%2)*8
	local oddZ = (footZ%2)*8
	
	local sizeX = footX * 8 
	local sizeZ = footZ * 8 
	local canSub = not (ud.floatOnWater or ud.name:match('hover') or ud.maxWaterDepth<30 or ud.minWaterDepth>0 )

	-- Echo("ud.maxWaterDepth is ", ud.maxWaterDepth)
	-- Echo("ud.canBuild is ", ud.isBuilder)
	-- for k,v in ud:pairs() do if k:match('[Ww]ater') then Echo(k,v) end end
	return {
			PID=PID
			,facing=facing
			,footX=footX
			,footZ=footZ
			,oddX=oddX
			,oddZ=oddZ
			,sizeX=sizeX
			,sizeZ=sizeZ
			,terraSizeX=sizeX-0.1
			,terraSizeZ=sizeZ-0.1
			,offfacing=offfacing
			,canSub=canSub
			,needTerraOnWater=not canSub and not ud.name:match('hover')
			,floatOnWater=ud.floatOnWater
			,height=ud.height
			,name=ud.name
			,radius=ud.name=="energypylon" and 3877 or (ud.radius^2)/8
			}
end

Turn90 = function(dir,lr)
	local newdirx,newdirz
	local exe
	if lr=="left" or lr==false then exe=false
	else exe = lr=="right" or lr==true or  math.random()>0.5
	end

	newdirx = not exe and -dir.z or dir.z
	newdirz = exe and -dir.x or dir.x
	return {x=newdirx,z=newdirz}
end

GetDirection = function (preX,preZ, X,Z,fix)
	local   x,z = X-preX, Z-preZ
	local biggest =  max( abs(x), abs(z) )
	x,z = x/biggest, z/biggest
	if fix and x==0 and z==0 then
		local random=math.random
		local head = random()>0.5
		if head then
			x=1 z=random()
		else
			z=1 x=random()
		end
	end
	local dir = {x=x,z=z}
	local orthoDir = {x=round(x), z=round(z)}

	return dir, orthoDir
end


ReorderPlacements = function (first,placements) -- by distance from first
	for i=1 ,#placements-1 do
		for j=i+1, #placements do
			--Echo("x , z ,  cQueue[i].params[1], cQueue[i].params[3 is ", x , z ,  cQueue[i].params[1], cQueue[i].params[3])
			if  getDist( first[1] , first[2] ,  placements[i][1], placements[i][2])
											 >
				getDist( first[1] , first[2] ,  placements[j][1], placements[j][2])
			then
					table.insert(placements, i,placements[j])
					table.remove(placements, j+1)
					table.insert(placements, j+1,placements[i+1])
					table.remove(placements, i+1)
				--Echo("Order Switched",i,j)
			end
		end
	end
	if #duplicate==0 then
	 table.insert(placements,1,first)
	end
	first ={}
	duplicate = {}
	Echo("placements ==",#placements)
	for i=1, #placements do
		Echo("placements[i][1] is ", placements[i])
	end
end


-- this is just for memory but can be useful, it deduce if the engine make multiple placement
MultiplePlacements = function (PID,start,pos) -- detecting multiple placement from engine
	local ud = UnitDefs[PID]
	local facing = sp.GetBuildFacing()
	
	local footX = ud.xsize/2
	local footZ = ud.zsize/2
	
	if (facing == 1 or facing == 3) then
		footX, footZ = footZ, footX
	end
	
	local oddX = (footX%2)*8
	local oddZ = (footZ%2)*8
		

	local pointX = floor((pos[1] + 8 - oddX)/16)*16 + oddX
	local pointZ = floor((pos[3] + 8 - oddZ)/16)*16 + oddZ


	local multiple
-- the important part
	local spacing = sp.GetBuildSpacing()			
	local gapX = abs((pointX-start[1])/16)
	local gapZ = abs((pointZ-start[2])/16)

	return gapX > spacing*0.6 + round(footX*2/3) or 
		   gapZ > spacing*0.6 + round(footZ*2/3)
end
Overlapping2 = function (rect1,rect2,addx,addz) --quicker version?
	addx,addz = addx or 0,addz or 0
	local x,z,sx,sz=unpack(rect1)
	local x2,z2,sx2,sz2=unpack(rect2)
	if abs(x-x2)>= sx/2+sx2/2+addx/2 then return false
	elseif  abs(z-z2)>= sz/2+sz2/2+addz/2 then return false
	else return true
	end
end

Overlapping = function (rect1,rect2,addx,addz,reverse) -- too expensive
	addx,addz = addx or 0,addz or 0
	--Echo("addx,addz is ", addx,addz)

	if t(rect2[1])~="table" then -- adapting for checking multiple or one rect2, the tested rectangle size can be augmented
		rect2={rect2}
	end
	local knownPID={}
	local x1,z1,w1,h1 = rect1[1],rect1[2],rect1[3],rect1[4]
	w1=w1+addx

	h1=h1+addz
	x1,z1 = x1-w1/2, z1-h1/2
	local x2,z2,w2,h2
	local start,finish
	if reverse then
		start,finish = #rect2,1
	else
		start,finish = 1,#rect2
	end

	for i=start, finish do
		local r2 = rect2[i]
		x2,z2,w2,h2 = r2[1],r2[2],r2[3],r2[4]
		if not h2 then -- in case we treat a pack of rectangles with different size
			if not knownPID[w2] then knownPID[w2]={UnitDefs[w2].sizex,UnitDefs[w2].sizez} end
			w2,h2 = knownPID[w2][1],knownPID[w2][2]
		end

		x2,z2 = x2-w2/2, z2-h2/2

		if 	(x1 < x2 + w2) and
			(x1 + w1 > x2) and
			(z1 < z2 + h2) and
			(z1 + h1 > z2) then
			return r2
		end
	end
	return false
end
function overlapped(x,z,sx,sz, ix,iz,isx,isz)
	return (x-ix)^2 < (sx+isx)^2 and (z-iz)^2 < (sz+isz)^2 -- <==== better, the less variables are checked the faster it is -- TODO test with rounded values vs non rounded
end
function IsOverlap(x1,z1,w1,h1,x2,z2,w2,h2)
	return (x1 < x2 + w2) and (x1 + w1 > x2) and (z1 < z2 + h2) and	(z1 + h1 > z2)
end

function Overlappings(x,z,sx,sz,rects)
	for i,r in ipairs(rects) do
		if (x-r[1])^2 < (sx+r[3])^2 and (z-r[2])^2 < (sz+r[4])^2 then
			return true
		end
	end
end
---------------------------------------------------------------------------------
-------------------------------------STRINGS--------------------------------------
---------------------------------------------------------------------------------

words = function(s) return s:gmatch('[%a]+') end


lines_noblank = function(s)
	return s:gmatch('[^\r\n]+')
end


linesbreak = function(s)
		if s:sub(-1)~="\n" then s=s.."\n" end
		return s:gmatch("(.-)\n")
end




function string:codeescape() -- code string that is escaped character into decimal representation and vice versa
  	return (self:gsub("\\(.)", function (x)
    	return ("\\%03d"):format(x:byte())
    end))
end
function string:decodeescape()
  	return (self:gsub("\\(%d%d%d)", function (d)
  	                return "\\" .. d:char()
  	end))
end
function string:sol(pos) -- get start of the line where pos is
	if pos>self:len() then
		return
	end
	return self:sub(1,pos):match(".*\n()") or 1 -- fastest solution after different testings, (see end of file to see different solution testing)
end
function string:rfind(search,pos)
	return self:sub(1,pos):match(".*"..search.."()") or 1 
end
local function RoundTrim(n,maxdec)
	return (('%.'..maxdec..'f'):format(n):gsub('%.?0+$',""))
end

local function TrimComma(str)
	return (str:gsub(',%s*$',''))
end
function string:line(pos)
	local sol = self:sol(pos)
	if sol then
		return self:sub(sol,self:find('\n',sol)), sol
	end
end
function string:word(pos)
	local _,endPos = self:sub(pos):find('^%w+')
	if endPos then
		pos, endPos = self:sub(1,pos-1):find('%w+$') or pos,    pos + endPos - 1
		return self:sub(pos,endPos), pos, endPos
	end
end


do
	local char, concat = string.char, table.concat
	local round = function(n) -- that way of declaring function ('local f = function()' instead of 'local function f()' make the function ignore itself so I can call round function inside it which is math.round)
		n=round(n)
		return n==0 and 1 or n
	end
	string.color = function(color)
	   return concat({char(255),char(round(color[1]*255)),char(round(color[2]*255)),char(round(color[3]*255))})
	end
end
-- function string.color(str,color)
--    return char(255,round(color[1]*255),round(color[2]*255),round(color[3]*255)) .. str
-- end


do
	local t,n
	local func = function(ret) n=n+1 t[n]=ret end
	function string:split(sep)
		sep,t,n = sep or ",", {}, 0
		self:gsub('[^'..sep.."]+",func)
		return t
	end
end

function int2hex(int) -- for the reverse we can just do tonumber(hex,16)
	local digits,ret, i = "0123456789ABCDEF",""
	if int==0 then return '0x0' end
	while int>0 do
		int, i = floor(int/16), 1 + int%16
		ret = digits:sub(i,i)..ret
	end
	return "0x"..ret
end


comboKeyset= (function()
	local charKeyset = function(match) return not match:find('E') and '+'..match:char():upper() or '' end
	return function(keyset)	
		return keyset:gsub('%+?(0x.*)',charKeyset)
	end
end)()

function string:purgecomment(commented) -- remove comment and inform if the EoL is in block comment
	local line
	if not commented then
		line = self:gsub('%-%-%[%[.-%-%-%]%]','') -- removing block comments first that are in the same line
		--Echo(num..':after removing same line block\n'..line)
		line = line:gsub('%-%-[^%[][^%[].*$','') -- then remove normal line comment to not get fooled
		--Echo(num..':after removing simple comment\n'..line)
		line,commented = line:gsub('%-%-%[%[(.-)$','') -- then detect start of multi line block comment and remove it
		--Echo(num..':after removing start of block\n'..line)
		commented = commented>0 -- end of line is in a block comment or not
	else
		local uncommented
		line,uncommented = self:gsub('^(.-)%]%]','') -- detect end of multi line block comment and remove it
		commented=uncommented==0
		if uncommented>0 then -- check what is after the block comment with recursion
			--Echo(num..':after end of block\n'..line)
			line,commented = line:purgecomment(false)
		else
			--Echo(num..':line is totally commented')
			line ='' 
		end
	end
	return line,commented
end
function string:matchOptDot(pbefore,p,pafter)
	local withdot = '%.'..p
	local match
	local new_match = self:match(pbefore..p..pafter,1)
	while new_match do
		match=new_match
		p=p..withdot
		new_match=self:match(pbefore..p..pafter,1)
	end
	return match
end

function EncodeToNumber(str) -- transform unique string to unique number  -- NOTE: the number is too long for it to be useful
	local base64bytes = {['A']=0,['B']=1,['C']=2,['D']=3,['E']=4,['F']=5,['G']=6,['H']=7,['I']=8,['J']=9,['K']=10,['L']=11,['M']=12,['N']=13,['O']=14,['P']=15,['Q']=16,['R']=17,['S']=18,['T']=19,['U']=20,['V']=21,['W']=22,['X']=23,['Y']=24,['Z']=25,['a']=26,['b']=27,['c']=28,['d']=29,['e']=30,['f']=31,['g']=32,['h']=33,['i']=34,['j']=35,['k']=36,['l']=37,['m']=38,['n']=39,['o']=40,['p']=41,['q']=42,['r']=43,['s']=44,['t']=45,['u']=46,['v']=47,['w']=48,['x']=49,['y']=50,['z']=51,['0']=52,['1']=53,['2']=54,['3']=55,['4']=56,['5']=57,['6']=58,['7']=59,['8']=60,['9']=61,['-']=62,['_']=63,[' ']=64}
	local result=""
	for pos=1,string.len(str) do
		local num =  base64bytes[str:sub(pos,pos):upper()] or ''
		result=result..string.len(num)..num
	end
	return result
end
function DecodeToString(num) --decode number to original string, based on the code of the above function
	local base64chars = {[0]='A',[1]='B',[2]='C',[3]='D',[4]='E',[5]='F',[6]='G',[7]='H',[8]='I',[9]='J',[10]='K',[11]='L',[12]='M',[13]='N',[14]='O',[15]='P',[16]='Q',[17]='R',[18]='S',[19]='T',[20]='U',[21]='V',[22]='W',[23]='X',[24]='Y',[25]='Z',[26]='a',[27]='b',[28]='c',[29]='d',[30]='e',[31]='f',[32]='g',[33]='h',[34]='i',[35]='j',[36]='k',[37]='l',[38]='m',[39]='n',[40]='o',[41]='p',[42]='q',[43]='r',[44]='s',[45]='t',[46]='u',[47]='v',[48]='w',[49]='x',[50]='y',[51]='z',[52]='0',[53]='1',[54]='2',[55]='3',[56]='4',[57]='5',[58]='6',[59]='7',[60]='8',[61]='9',[62]='-',[63]='_',[64]=' '}
	local result,pos='',1
	while pos<string.len(num) do
		local ln = tonumber(num:sub(pos,pos))
		result=result..base64chars[tonumber(num:sub(pos+1,pos+ln))]
		pos=pos+ln+1
	end
	return result
end


function string:explode(sep)
	if not sep then sep = ',' end
	local t = {}
	for w in self:gmatch('[^'..sep..']+') do
		table.insert(t,w)
	end
	return t
end

function explode(div,str) --copied from gui_epicmenu.lua
  if (div=='') then return false end
  local pos,arr = 0,{}
  -- for each divider found
  for st,sp in function() return string.find(str,div,pos,true) end do
	table.insert(arr,string.sub(str,pos,st-1)) -- Attach chars left of current divider
	pos = sp + 1 -- Jump past current divider
  end
  table.insert(arr,string.sub(str,pos)) -- Attach chars right of last divider
  return arr
end

do
	local char, byte, pairs, floor = string.char, string.byte, pairs, math.floor
	local table_insert, table_concat = table.insert, table.concat
	local unpack = table.unpack or unpack

	local function unicode_to_utf8(code)
	   -- converts numeric UTF code (U+code) to UTF-8 string
	   local t, h = {}, 128
	   while code >= h do
	      t[#t+1] = 128 + code%64
	      code = floor(code/64)
	      h = h > 32 and 32 or h/2
	   end
	   t[#t+1] = 256 - 2*h + code
	   return char(unpack(t)):reverse()
	end

	local function utf8_to_unicode(utf8str, pos)
	   -- pos = starting byte position inside input string (default 1)
	   pos = pos or 1
	   local code, size = utf8str:byte(pos), 1
	   if code >= 0xC0 and code < 0xFE then
	      local mask = 64
	      code = code - 128
	      repeat
	         local next_byte = utf8str:byte(pos + size) or 0
	         if next_byte >= 0x80 and next_byte < 0xC0 then
	            code, size = (code - mask - 2) * 64 + next_byte, size + 1
	         else
	            code, size = utf8str:byte(pos), 1
	         end
	         mask = mask * 32
	      until code < mask
	   end
	   -- returns code, number of bytes in this utf8 char
	   return code, size
	end

	local map_1252_to_unicode = {
	   [0x80] = 0x20AC,
	   [0x81] = 0x81,
	   [0x82] = 0x201A,
	   [0x83] = 0x0192,
	   [0x84] = 0x201E,
	   [0x85] = 0x2026,
	   [0x86] = 0x2020,
	   [0x87] = 0x2021,
	   [0x88] = 0x02C6,
	   [0x89] = 0x2030,
	   [0x8A] = 0x0160,
	   [0x8B] = 0x2039,
	   [0x8C] = 0x0152,
	   [0x8D] = 0x8D,
	   [0x8E] = 0x017D,
	   [0x8F] = 0x8F,
	   [0x90] = 0x90,
	   [0x91] = 0x2018,
	   [0x92] = 0x2019,
	   [0x93] = 0x201C,
	   [0x94] = 0x201D,
	   [0x95] = 0x2022,
	   [0x96] = 0x2013,
	   [0x97] = 0x2014,
	   [0x98] = 0x02DC,
	   [0x99] = 0x2122,
	   [0x9A] = 0x0161,
	   [0x9B] = 0x203A,
	   [0x9C] = 0x0153,
	   [0x9D] = 0x9D,
	   [0x9E] = 0x017E,
	   [0x9F] = 0x0178,
	   [0xA0] = 0x00A0,
	   [0xA1] = 0x00A1,
	   [0xA2] = 0x00A2,
	   [0xA3] = 0x00A3,
	   [0xA4] = 0x00A4,
	   [0xA5] = 0x00A5,
	   [0xA6] = 0x00A6,
	   [0xA7] = 0x00A7,
	   [0xA8] = 0x00A8,
	   [0xA9] = 0x00A9,
	   [0xAA] = 0x00AA,
	   [0xAB] = 0x00AB,
	   [0xAC] = 0x00AC,
	   [0xAD] = 0x00AD,
	   [0xAE] = 0x00AE,
	   [0xAF] = 0x00AF,
	   [0xB0] = 0x00B0,
	   [0xB1] = 0x00B1,
	   [0xB2] = 0x00B2,
	   [0xB3] = 0x00B3,
	   [0xB4] = 0x00B4,
	   [0xB5] = 0x00B5,
	   [0xB6] = 0x00B6,
	   [0xB7] = 0x00B7,
	   [0xB8] = 0x00B8,
	   [0xB9] = 0x00B9,
	   [0xBA] = 0x00BA,
	   [0xBB] = 0x00BB,
	   [0xBC] = 0x00BC,
	   [0xBD] = 0x00BD,
	   [0xBE] = 0x00BE,
	   [0xBF] = 0x00BF,
	   [0xC0] = 0x00C0,
	   [0xC1] = 0x00C1,
	   [0xC2] = 0x00C2,
	   [0xC3] = 0x00C3,
	   [0xC4] = 0x00C4,
	   [0xC5] = 0x00C5,
	   [0xC6] = 0x00C6,
	   [0xC7] = 0x00C7,
	   [0xC8] = 0x00C8,
	   [0xC9] = 0x00C9,
	   [0xCA] = 0x00CA,
	   [0xCB] = 0x00CB,
	   [0xCC] = 0x00CC,
	   [0xCD] = 0x00CD,
	   [0xCE] = 0x00CE,
	   [0xCF] = 0x00CF,
	   [0xD0] = 0x00D0,
	   [0xD1] = 0x00D1,
	   [0xD2] = 0x00D2,
	   [0xD3] = 0x00D3,
	   [0xD4] = 0x00D4,
	   [0xD5] = 0x00D5,
	   [0xD6] = 0x00D6,
	   [0xD7] = 0x00D7,
	   [0xD8] = 0x00D8,
	   [0xD9] = 0x00D9,
	   [0xDA] = 0x00DA,
	   [0xDB] = 0x00DB,
	   [0xDC] = 0x00DC,
	   [0xDD] = 0x00DD,
	   [0xDE] = 0x00DE,
	   [0xDF] = 0x00DF,
	   [0xE0] = 0x00E0,
	   [0xE1] = 0x00E1,
	   [0xE2] = 0x00E2,
	   [0xE3] = 0x00E3,
	   [0xE4] = 0x00E4,
	   [0xE5] = 0x00E5,
	   [0xE6] = 0x00E6,
	   [0xE7] = 0x00E7,
	   [0xE8] = 0x00E8,
	   [0xE9] = 0x00E9,
	   [0xEA] = 0x00EA,
	   [0xEB] = 0x00EB,
	   [0xEC] = 0x00EC,
	   [0xED] = 0x00ED,
	   [0xEE] = 0x00EE,
	   [0xEF] = 0x00EF,
	   [0xF0] = 0x00F0,
	   [0xF1] = 0x00F1,
	   [0xF2] = 0x00F2,
	   [0xF3] = 0x00F3,
	   [0xF4] = 0x00F4,
	   [0xF5] = 0x00F5,
	   [0xF6] = 0x00F6,
	   [0xF7] = 0x00F7,
	   [0xF8] = 0x00F8,
	   [0xF9] = 0x00F9,
	   [0xFA] = 0x00FA,
	   [0xFB] = 0x00FB,
	   [0xFC] = 0x00FC,
	   [0xFD] = 0x00FD,
	   [0xFE] = 0x00FE,
	   [0xFF] = 0x00FF,
	}
	local map_unicode_to_1252 = {}
	for code1252, code in pairs(map_1252_to_unicode) do
	   map_unicode_to_1252[code] = code1252
	end

	function string.fromutf8(utf8str)
	   local pos, result_1252 = 1, {}
	   while pos <= #utf8str do
	      local code, size = utf8_to_unicode(utf8str, pos)
	      pos = pos + size
	      code = code < 128 and code or map_unicode_to_1252[code] or ('?'):byte()
	      table_insert(result_1252, char(code))
	   end
	   return table_concat(result_1252)
	end

	function string.toutf8(str1252)
	   local result_utf8 = {}
	   for pos = 1, #str1252 do
	      local code = str1252:byte(pos)
	      table_insert(result_utf8, unicode_to_utf8(map_1252_to_unicode[code] or code))
	   end
	   return table_concat(result_utf8)
	end


end

---------------------------------------------------------------------------------
----------------------------------METATABLES-------------------------------------
---------------------------------------------------------------------------------
setnotifyproxy = function(t,cb_index,cb_newindex) -- transfert pairs of t into a new table and make t a proxy
    local _t = {}
    for k,v in pairs(t) do
        t[k] = nil
        _t[k] = v
    end
    mt = {
         __index = cb_index and function(t,k) cb_index(t,k) return _t[k]  end or _t
        ,__newindex= cb_newindex and function(t,k,v) cb_newindex(t,k,v) _t[k] = v  end or _t
    }

    setmetatable(t,mt)
    return _t
end

-- USAGE KEYRING
--[[
local equal = (function() 
	local mt = { __add=function(self,arg) self[arg]=true return self end
				,__eq=function(self,arg)  for k in pairs(self) do Echo('k',k,'vs',arg[k]) if not arg[k] then return false end end return true end}
	return function(t) return setmetatable(t,mt) end
end)()
local KEYRING={[equal{[100]=true,alt=true}]='key1'}
setmetatable(KEYRING,{ __index=function(self,key) for k,name in pairs(self) do if k==key then return name end end end})


function widget:KeyPress(key, mods)
	local key=equal(mods)+key
	local ret = KEYRING[key] -- ALT+D = true
end
--]]


--fasttable
-- 2 times faster to unpack for constant table, create a function for each subtable with fixed length of arguments instead of the table
-- usage: main_table = fasttable(n) -- n for the number of element in subtables
-- main_table.sub_table={a,b,c,d}
-- unpacking: a,b,c,d = main_table.sub_table()
-- as it is not a table you cannot index it...
-- function for specific length of elements must be defined below as in example
function fasttable(n)
	local create =  n==4  and  function (a,b,c,d) return function() return a,b,c,d end end
				 or n==1  and  function (a) return function() return a end end
				 or n==26 and  function (a,b,c,d,e,f,g,h,i,j,k,l,m,n,o,p,q,r,s,t,u,v,w,x,y,z) return function() return a,b,c,d,e,f,g,h,i,j,k,l,m,n,o,p,q,r,s,t,u,v,w,x,y,z end end
	return setmetatable({}, { __newindex=function(self,k,t) rawset(self, k, create(unpack(t))) end } )
end
function __tostring(self)
	local g="\255\155\155\155"
	local n,cont = 0,true
	for i in pairs(self) do n=n+1 if i~=n then cont=false break end end
	if n==0 then return 'empty table' end
	local str,n='',0
	if cont then for k,v in pairs(self) do n=n+1 if n%10==0 then str=str..'\n' end str=str..g..tostring(v)..', ' end return str--:sub(0,-2)
	else for k,v in pairs(self) do n=n+1 if n%5==0 then str=str..'\n' end str=str..g..'['..tostring(k)..']='..tostring(v)..',  ' end return str--:sub(0,-2)
	end
end
-- compare/operate table(s) by length or number, return number or bool
comp_length = (function()
	local n=function(tbl)if type(tbl)=='number' then return arg end local n=0 for _ in pairs(tbl) do n=n+1 end return n end
	local mt = {}
	mt.__lt  = function(self,arg) return n(self)<n(arg) end
	mt.__le  = function(self,arg) return n(self)<=n(arg) end
	mt.__gt  = function(self,arg) return n(self)>n(arg) end
	mt.__ge  = function(self,arg) return n(self)>=n(arg) end
	mt.__eq  = function(self,arg) return n(self)==n(arg) end
	mt.__add = function(self,arg) return n(self)+n(arg) end
	mt.__sub = function(self,arg) return n(self)-n(arg) end
	mt.__tostring=__tostring
	return function(t) -- keep original meta and override the operators meta methods
		local ownmeta = getmetatable(t)
		if not ownmeta then return setmetatable(t,mt)
		else for k,v in pairs(mt) do ownmeta[k]=v end return setmetatable(t,ownmeta)
		end
	end
end)()
-- compare/operate total additionned numbers in table(s)
comp_total = (function()
	local n=function(tbl) if type(tbl)=='number' then return arg end local n=0 for _,v in pairs(tbl) do n=n+v end return n end
	local mt = {}
	mt.__lt  = function(self,arg) return n(self)<n(arg) end
	mt.__le  = function(self,arg) return n(self)<=n(arg) end
	mt.__gt  = function(self,arg) return n(self)>n(arg) end
	mt.__ge  = function(self,arg) return n(self)>=n(arg) end
	mt.__eq  = function(self,arg) return n(self)==n(arg) end
	mt.__add = function(self,arg) return n(self)+n(arg) end
	mt.__sub = function(self,arg) return n(self)-n(arg) end
	mt.__tostring=__tostring
	return function(t) -- keep original meta and override the operators meta methods
		local ownmeta = getmetatable(t)
		if not ownmeta then return setmetatable(t,mt)
		else for k,v in pairs(mt) do ownmeta[k]=v end return setmetatable(t,ownmeta)
		end
	end
end)()
-- metamethods to compare table by their content number, absolute: return false if any value doesnt match
comp_content = (function()
	local mt = {}
	mt.__lt=function(self,arg) for k,v in pairs(self) do if v>=arg[k] then return false end end return true end
	mt.__le=function(self,arg) for k,v in pairs(self) do if v> arg[k] then return false end end return true end
	mt.__gt=function(self,arg) for k,v in pairs(self) do if v<=arg[k] then return false end end return true end
	mt.__ge=function(self,arg) for k,v in pairs(self) do if v< arg[k] then return false end end return true end
	mt.__eq=function(self,arg) for k,v in pairs(self) do if v~=arg[k] then return false end end return true end
	mt.__tostring=__tostring
	return function(t) -- override the operators meta methods,keep the rest if any
		local ownmeta = getmetatable(t)
		if not ownmeta then return setmetatable(t,mt)
		else for k,v in pairs(mt) do ownmeta[k]=v end return setmetatable(t,ownmeta)
		end
	end
end)()
-- perform arithmetic on table
arith = (function ()
	local mt = {}
	mt.__add=function(self,arg) if type(arg)=='number' then for k,v in pairs(self) do self[k]=v+arg end else for k,v in pairs(arg) do self[k]=(self[k] or 0)+v end end end
	mt.__sub=function(self,arg) if type(arg)=='number' then for k,v in pairs(self) do self[k]=v-arg end else for k,v in pairs(arg) do self[k]=(self[k] or 0)-v end end end
	mt.__mul=function(self,arg) if type(arg)=='number' then for k,v in pairs(self) do self[k]=v*arg end else for k,v in pairs(arg) do self[k]=(self[k] or 0)*v end end end
	mt.__div=function(self,arg) if type(arg)=='number' then for k,v in pairs(self) do self[k]=v/arg end else for k,v in pairs(arg) do self[k]=(self[k] or 0)/v end end end
	mt.__mod=function(self,arg) if type(arg)=='number' then for k,v in pairs(self) do self[k]=v%arg end else for k,v in pairs(arg) do self[k]=(self[k] or 0)%v end end end
	mt.__tostring=__tostring
	return function(t) -- keep original meta and override the operators meta methods
		local ownmeta = getmetatable(t)
		if not ownmeta then return setmetatable(t,mt)
		else for k,v in pairs(mt) do ownmeta[k]=v end return setmetatable(t,ownmeta)
		end
	end
end)()
 --same but keeping the original intact
arith_new = (function ()
	local mt = {}
	mt.__add=function(self,arg) local new={} if type(arg)=='number' then for k,v in pairs(self) do new[k]=v+arg end else for k,v in pairs(arg) do new[k]=(self[k] or 0)+v end end return setmetatable(new,getmetatable(self)) end
	mt.__sub=function(self,arg) local new={} if type(arg)=='number' then for k,v in pairs(self) do new[k]=v-arg end else for k,v in pairs(arg) do new[k]=(self[k] or 0)-v end end return setmetatable(new,getmetatable(self)) end
	mt.__mul=function(self,arg) local new={} if type(arg)=='number' then for k,v in pairs(self) do new[k]=v*arg end else for k,v in pairs(arg) do new[k]=(self[k] or 0)*v end end return setmetatable(new,getmetatable(self)) end
	mt.__div=function(self,arg) local new={} if type(arg)=='number' then for k,v in pairs(self) do new[k]=v/arg end else for k,v in pairs(arg) do new[k]=(self[k] or 0)/v end end return setmetatable(new,getmetatable(self)) end
	mt.__mod=function(self,arg) local new={} if type(arg)=='number' then for k,v in pairs(self) do new[k]=v%arg end else for k,v in pairs(arg) do new[k]=(self[k] or 0)%v end end return setmetatable(new,getmetatable(self)) end
	mt.__tostring=__tostring
	return function(t) -- keep original meta and override the operators meta methods
		local ownmeta = getmetatable(t)
		if not ownmeta then return setmetatable(t,mt)
		else for k,v in pairs(mt) do ownmeta[k]=v end return setmetatable(t,ownmeta)
		end
	end
end)()
--- remove/add/update a table   -- if argument is a non table: if add: a new element is inserted with that value
															 --if sub: the number of elements removed from the end is indicated by the value
								-- if argument is a table    : if add: update the corresponding pairs
															 --if sub: nil the corresponding pairs
upd = (function ()
	local g="\255\155\155\155"
	local mt = {}
	local insert = table.insert
	mt.__add=function(self,arg)
		if arg==nil then return self
		elseif type(arg)~='table' then insert(self,arg) return self
		else for k,v in pairs(arg) do self[k]=v end return self
		end
	end
	mt.__sub=function(self,arg)
		if type(arg)=='number' then local i=#self for i=i,i-arg+1,-1 do self[i]=nil end return self
		elseif type(arg)=='table' then for k,v in pairs(arg) do self[k]=nil end return self
		else return self
		end
	end
	mt.__tostring=__tostring
	return function(t) -- keep original meta and override the operators meta methods
		local ownmeta = getmetatable(t)
		if not ownmeta then return setmetatable(t,mt)
		else for k,v in pairs(mt) do ownmeta[k]=v end return setmetatable(t,ownmeta)
		end
	end
end)()
upd_new = (function () -- same but return a new table (shallow copy)
	local mt = {}
	local insert = table.insert
	mt.__add=function(self,arg)
		local self=copy(self)
		if arg==nil then return self
		elseif type(arg)~='table' then insert(self,arg) return self
		else for k,v in pairs(arg) do self[k]=v end return self
		end
	end
	mt.__sub=function(self,arg)
		local self=copy(self)
		if type(arg)=='number' then local i=#self for i=i,i-arg+1,-1 do self[i]=nil end return self
		elseif type(arg)=='table' then for k,v in pairs(arg) do self[k]=nil end return self
		else return self
		end
	end
	mt.__tostring=__tostring
	return function(t) -- keep original meta and override the operators meta methods
		local ownmeta = getmetatable(t)
		if not ownmeta then return setmetatable(t,mt)
		else for k,v in pairs(mt) do ownmeta[k]=v end return setmetatable(t,ownmeta)
		end
	end
end)()

-- create empty subtable automatically when queried key doesnt exist, beware it will create subtable no matter the query
-- reset the table with autotable(tbl,'off') when done, or get the feature back with autotable(tbl,any-true-value)
function autotable(tbl,onoff)
	local mt={__index=function(self,k) self[k]=setmetatable({},mt) return self[k] end}
	local function reset(tbl)
		if onoff=='off' then setmetatable(tbl,nil) else setmetatable(tbl,mt) end
		for k,v in pairs(tbl) do if t(v)=='table' and getmetatable(tbl)==getmetatable(v) then reset(v) end end
	end
	if onoff then reset(tbl) return tbl end
	return setmetatable(tbl,mt)
end
function weak_autotable(tbl,onoff)
	local mt={__index=function(self,k) self[k]=setmetatable({},mt) return self[k] end
			 ,__mode='kv'
	}
	local function reset(tbl)
		if onoff=='off' then setmetatable(tbl,nil) else setmetatable(tbl,mt) end
		for k,v in pairs(tbl) do if t(v)=='table' and getmetatable(tbl)==getmetatable(v) then reset(v) end end
	end
	if onoff then reset(tbl) return tbl end
	return setmetatable(tbl,mt)
end
-- same but differently
local function autoK(t,maxlevel,level)
    
    local level = level or 1

    return setmetatable(
        {}
        ,{  __index=function(self,k)
            Echo('index '..k..' is triggered')
            t[k]=t[k] or level<maxlevel and paraKV({},level+1) or {}
            return t[k]
        end
            ,__newindex=function(self,k,v)
                if v==nil then
                    setmetatable(self,nil)
                end
                t[k]=v
            end
        }
    )
end

--------------------------------------- TABLES ---------------------------------------

function identical(t1,t2)
	if #t1~=#t2 then
		return
	end
	for i,v in ipairs(t1) do
		if v ~= t2[i] then
			return
		end
	end
	return true
end
function identicalkv(t1,t2)
	if l(t1)~=l(t2) then
		return
	end
	for k,v in pairs(t1) do
		if t2[k]~=v then
			return
		end
	end
	return true
end


do
	local bool = {[true]='true',[false]='false'}

	function table:kConcat(separator,only_true,debug_options)
		separator = separator or ' | '
		local str = ''
        local coded = ''
		for k,v in pairs(self) do
			if debug_options and k=='coded' then
				coded = k..':'..v..separator
			elseif not only_true or v then
				str=str..k..separator
			end
		end
        str = coded .. str
		return str:sub(1,-(separator:len()+1))
	end
	function table:kvConcat(separator,only_true)
		separator = separator or ' | '
		local str = ''
		for k,v in pairs(self) do
			if not only_true or v then
				str=str..'['..k..']: '..tostring(v)..separator
			end
		end
		return str:sub(1,-(separator:len()+1))
	end
end

table.concatsep = function(t,sep)
	sep = sep or ','
    local str = ''
    for i,p in ipairs(t) do
        str = str .. p .. ','
    end
    return str:sub(1,str:len()-1)
end

function idtable(t) -- link a parallel subtable 'byID' usage: t:remove(id) t:add(id)
	t.byID={}
	local byID=t.byID
	for i,id in ipairs(t) do
		byID[id]=i
	end
	return setmetatable(
		 t
		,{
			__index={
			remove=function(id) Echo('id id',id)
						local i,nxid,ind=byID[id],next(byID,id)
						while nxid do byID[nxid],nxid,ind=ind-1,next(byID,nxid) end
						return table.remove(t,i),i
					end
				  ,add=function(id) local len=#t+1  byID[id],t[len]=len,id  end}}
	)
end
function alter(t) -- generator looping indexed table
	local i,len = 0,#t
	return function()
		i = i==len and 1 or i+1
		return t[i]
	end
end
-- alternative of the function below to test if it's faster (avoid using 'next' function)
function consumer(t,n) -- generator alternating between indexed subtables and consuming them according to their n property
	-- prepare the generator
	local index,len ={},#t
	for i=1,len do index[i],t[i]._consumed_n = t[i],t[i][n] end
	local i = 0
	--
	return function()
		i = i==len and 1 or i+1 -- get next index or back to the first
		local element=index[i]
		if not element then return end -- if no index, everything has been consumed, we're done
		-- update the n value or destroy the indexed element and the tracking property
		local n = element._consumed_n-1
		if n==0 then n,len = nil,len-1 table.remove(index,i) i=i-1 end
		element._consumed_n = n 
		return element, n and n+1 or 1 -- (if that was the last, n has been niled)
	end
end
--[[function consumer(t,n) -- generator alternating between indexed subtables and consuming them according to their n property
	-- prepare the generator
	local index ={}
	for i=1,#t do index[i]=t[i][n] end
	local i,n
	--
	return function()
		i,n = next(index,i)  if not i then i,n = next(index,i) end -- get next index or back to the first
		if not i then return end -- if still no index, everything has been consumed, we're done
		n=n-1  if n==0 then n=nil end  index[i]=n -- update the n value or destroy the element index
		return t[i]
	end
end--]]

-- reverse indexed table
function reverse(t)
	local ln = #t
	for i=1,floor(ln/2) do
		t[i],t[ln-i+1] = t[ln-i+1],t[i]
	end
end

function copy(tbl) 
	if not tbl then return nil end
	local new={}
	for k,v in pairs(tbl) do new[k]=v end
	return setmetatable(new,copy(getmetatable(tbl)))
end
function deepcopy(tbl)
	if not tbl then return nil end
	local new={}
	for k,v in pairs(tbl) do new[t(k)=='table' and deepcopy(k) or k] =  t(v)=='table' and deepcopy(v) or v end
	return setmetatable(new,deepcopy(getmetatable(tbl)))
end



function OrderPointsByProximity(points,startPoint) -- reorder table to get each one next to each other
	local i,n=0,#points
	local current,nextp = startPoint,points[1]
	-- each points is compared to all the others, then we move forward, maybe it could be handled better to avoid that many iterations (hungarian method?)
	while i<n do
		local j=i+1
		 -- we assume the closest is the next point, and update the index c if we find a closest one
		local nextp,closest,c = points[j],nextp,j
		local dist = (current[1]-closest[1])^2 + (current[3]-closest[3])^2 -- this is not the real distance to avoid doing one more operation, but the end goal is achieved, real dist would need to be the square root of this
		while j<n do
			j=j+1
			local compared=points[j]
			local newdist = (current[1]-compared[1])^2 + (current[3]-compared[3])^2
			if newdist < dist then
				closest,dist,c = compared,newdist,j
			end
		end
		-- we switch elements of the table: next i become the closest, index of closest receive the element that was in next i
		i=i+1
		points[i],points[c]=closest,nextp 
		current = closest
	end
end
pairedtable = { -- create a live indexed table with unique values, with attached a keyed table
	new = function(self,obj)
		obj = obj or {}
		local byval = {}
		local n = #obj
		for i=1,n do
			byval[ obj[i] ] = i
		end
		obj.byval, obj.n = byval, n
		return setmetatable(obj,{__index=self})
	end
	-- set is only useful for the user to replace a value in a table, and can be triggered with t[i] = v
	-- if the value given already exist somewhere else, it will switch with its new place
	-- if the value 
	,removevals = function(t,vals) -- this need to be checked for performance, vs multiple removeval call on different size of table and different number of value to remove
		local n = t.n
		local n_vals = #vals
		local nextIndex = n
		local deleted = 0
		for i=1,n_vals do
			local v = vals[i]
			if v~=nil then
				local index = t.byval[v]
				Echo('delete',index,t[index],'index verif',t.byval[v])
				t[index], t.byval[v] = nil, nil
				deleted = deleted + 1
				if index < nextIndex then
					nextIndex = index
					Echo('set min index at '..nextIndex)
				end
			end
		end
		if deleted == 0 then
			Echo('no values found')
			return false
		end
		-- move the values to not have any niled index
		Echo('browse from ' .. nextIndex .. ' to ' .. t.n)
		for i = nextIndex+1, t.n do
			local v = t[i]
			Echo('current t['..i..'] == '..tostring(v))
			if v~=nil then
				Echo('move ' .. v .. ' from ' .. i .. ' to ' .. nextIndex)
				t[nextIndex], t[i] = v, nil
				t.byval[v] = nextIndex
				nextIndex = nextIndex+1
			end
				
		end
		return true
	end
	,len = function(t)
		return t.n
	end
	,insert = function(t,index,v)
		t.n = t.n + 1
		if v==nil then
			v,index = index,t.n
		end
		if t.byval[v]~=nil then
			-- the value already exist
			return false
		end

		table.insert(t,index, v)
		t.byval[v] = index
		for i=index + 1, t.n do
			t.byval[ t[i] ] = i
		end
		return index
	end
	,insertvals = function(t,start,vals)
		if vals==nil then
			vals,start = start,t.n+1
		end

		local n = t.n
		local n_vals = #vals
		local new_n = n + n_vals
		local added = 0
		if start > n  then
			-- the insertion is at the end, very simple
			for i=1, n_vals do
				local v = vals[i]
				if not t.byval[v] then
					n = n + 1
					t[n] = v
					t.byval[v] = n
					added = added + 1
				end
			end
			return added~=0 and added
		end
		-- the insertion is between values
		local toShift = 0
		-- don't count vals that are already in our table
		for i = 1, (vals.n or #vals) do
			local v = vals[i]
			if not t.byval[ v ] then 
				toShift = toShift + 1
			end
		end
		if toShift == 0 then
			return false
		end
		Echo('toShift is ' .. toShift)
		-- first, push old values, starting from the last
		for i = n , start, -1 do
			local v, newi = t[i], i + toShift
			Echo('i:'..i,'v:'..tostring(v),'=> '.. newi)
			t[newi] = v
			t.byval[v] = newi
			Echo('val ' .. v .. ' from ' .. i .. ' pushed to ' .. newi)
		end
		-- finally adding our new vals
		local off = -1
		for i = 1, n_vals do
			local v = vals[i]
			if t.byval[v] then
				off = off - 1
			else
				local index = start + i + off
				t[index], t.byval[v] = v, index
				Echo(' insert new value ' .. v .. ' at index ' .. index)
			end
		end
		return toShift
	end
	,remove = function(t,index)
		index = index or t.n
		local v = table.remove(t,index)
		t.n = t.n - 1
		for i = index, t.n do
			t.byval[ t[i] ] = i
		end
		return v
	end
	,removeval = function(t,value)
		local index = t.byval[value]
		if not index then
			return
		end
		table.remove(t,index)
		t.n=t.n-1
		for i=index, t.n do
			t.byval[ t[i] ] = i
		end
		return index
	end
	,removerange = function(t,start,finish)
		finish = math.min(finish or t.n, t.n)
		if finish==t.n then
			for i=start, finish do
				t.byval[ t[i] ]=nil
				t[i]=nil
			end
			t.n = start-1
		else

			for i=start, finish do
				-- Echo('delete',i,t[i],t.byval[ t[i] ] )
				t.byval[ t[i] ] = nil
				t[i]=nil
			end
			local diff = (finish - start + 1)
			-- that way the table doesn't reorganize until the last one has been moved, instead of getting reupdated on each remove
			for i=finish + 1,t.n do
				-- Echo('set index',t[i],i .. ' to ' .. i-diff)
				t.byval[ t[i] ] = i-diff
				t[i-diff], t[i] = t[i], nil 
			end
			t.n = t.n - diff
		end
	end
	,indexof = function(t,val)
		return t.byval[value]
	end
	,clear = function(t)
		t[t.n+1]='dummy' -- add this so the last index doesn't get niled until the end, so the table doesn't reorganize itself several time during the process
		for v,i in pairs(t.byval) do
			t.byval[v] = nil
			t[i] = nil
		end
		t[t.n+1]=nil
		t.n = 0
	end
}


function newTable()
	local t,n={},0
	return setmetatable(
		{	   
		   ln=0,
		   n=function()return n end,
		   add=function(_,v) n=n+1 t[n]=v end,
		   pop=function(_,k) n=n-1 t[n]=nil end,
		   t=t,
		   rem_range=function(_,start,finish)
				local c=0
				for i=start, n do 
					c=c+1
					t[i],t[finish+c] = t[finish+c],nil
				end
				n=n-(finish-start)-1
			end
		}, 
		{ 
			__index=t
		}
	)
end


-- create an indexed table filled with nil except the last one (stackoverflow if >19963)
-- this can help for performance on big table that will be filled progressively
NilTable = function(i,max)
	i=i+1
	if i<max then
		return nil,unp(i,max)
	else 
		return true
	end
end

-- create a table with a length attached -- for study performance
pack = function(...)

	return { n = select("#", ...), ... }
end

function test(...)
--[[    local values = pack(...)
	local arr = {}
	for i, v in pairs(values) do
		-- iterates only the non-nil fields of "values"
		arr[i] = v
	end
	return unpack(arr, 1, values.n)--]]
end
selectplus = function(selection,...) -- select several alone or multiple arguments at once,
-- eg: with selection={1,"2-5","3-max","all"} return arg1, {arg2 to arg5}, all args from args3, all args
	local results={}
	args={...}
	args = t(args[1])=="table" and #args==1 and args[1] or args
	local sel,first,last,tres
	local length = #args
	for i=1, #selection do
		sel=selection[i]
		if t(sel)=="number" then

			if sel>length then return false, Echo(WhiteStr.."selectplus:"..GreyStr.."number exceed length of results: "..sel) end
			results[#results+1]=args[sel]
		elseif t(sel)=="string" then
				tres={}
			first = sel=="all" and 1 or tonumber(sel:sub(1,1))
			last = (sel== "all" or sel:sub(3,6)=="max") and length or tonumber(sel:sub(3,3))
			
			if first>#args or last>length then return false, Echo(WhiteStr.."selectplus:"..GreyStr.."range exceed the results: "..sel) end
			local j=first
			while j<=last do
				tres[#tres+1]=args[j]
				j=j+1
			end
			results[#results+1]=tres
		end
	end
	return unpack(results)
end

table.haskey=function(T,key)
	for k,v in pairs(T) do
		if k==key then return true end
	end
return false
end


table.valtostr = function(T)
local str=""
	for _,v in pairs(T) do
		v= t(v)=="string" and "'"..v.."'" or tostring(v)
		str=str..v..",\n"
	end
	str=str:sub(0,-3)
	return str
end


table.tostring = function(T,tocode)
local str=""
local first = false
	for k,v in pairs(T)do
		if tocode then
			v= t(v)=="string" and "'"..v.."'" or tostring(v)
			k = t(tonumber(k))=="number" and "["..k.."]" or k
			str = str..""..k.."="..v..", "
		else

			str = "      "..RedStr..str.."["..k.."]="..tostring(v)..", \n"
		end
	end
	str=str:sub(0,-3)
	return str
end


table.removes = function(T,n) -- remove n number of elements at the end of the table
	if t(n)=="number" then
		local length = #T
		for i=length,length-n+1,-1 do
			T[i]=nil
		end
	end
end


table.findcoords = function(T,argument,...)
	if l(T)==0 then return false end
	if argument=="places" then
		local search={...}
		local x,z=search[1],search[#search]
		for i=1,#T do
			if x==T[i][1] and z==T[i][2] then
				return i
			end
		end
	end
	return false
end



table.mul = function(T1,mul)-- multiply table by a value or a table of values
	local tmul = t(mul)=="table"
	mul = tmul and table.kiter(mul) or mul -- if mul is a table
	for i=1,#T1 do
		local mul=tmul and mul[i] or mul
		T[i]=T[i]*mul
	end
end
tableforeach = function (T,f) 
	local checked=true
	local checking
	for k, v in pairs (T) do
	  checking = f(k, v) -- checking adds the possibility to verify a condition applying to all elements
	  checked = checked and checking -- checked will stay false if checking been false once
	end 
	return checked
end
table.kiter = function(T)
	local newTable={}
	local n = 0
	for _,v in pairs(T) do

		newTable[n] = v
	end
	return newTable
end

TVerif = function (T,x,z) --simple and quick 
local ln = #T
if ln==0 then return false end
	for i=1, ln do
		if T[i][1]==x and T[i][2]==z then
			return true
		end
	end
	return false
end


table.samecoords = function (T,arg)
	local l = l
	local x,y,z = false,false,false
	local newt
	T = table.kiter(T)
	arg = kiter(arg)
	
		for i,v in ipairs(T) do
			if arg[1]==v then
				table.insert(newt, v)
				if T[i+1] and t(T[i+1])=="number" then 
					table.insert(newt,T[i+1])
					if T[i+2] and t(T[i+2])=="number" then 
						table.insert(newt,T[i+2])
					end
				end
				break
			end
		end

	if l(newt)==3 then
		if l(arg)==2 and arg[2]==newt[3] then return true,false
		elseif l(arg)==3 and arg[2]==newt[2] and arg[3]==newt[3] then return true, true
		elseif l(arg)==3 and arg[3]==newt[3] then return true, false
		end
	elseif l(newt)==2 then
		if l(arg)==2 and arg[2]==newt[2] then return true,true
		elseif l(arg)==3 and arg[2]==newt[3] then return true, false
		end
	end
end


IsEqual =  function (tA, tB)
	local A,B = false,false
	if not tA or (t(tA)~="table") then A="A" end
	if not tB or (t(tB)~="table") then B="B" end
	if A or B then return false  end --Echo(A or B..(A and B and "and B are not ts" or " is not a table"))

	if #tA~=#tB then return false
	end

	for i=1, #tA do
		if tA[i]~=tB[i] then return false
		end
	end

	return true
end



table.exact = function  (tA, tB)
	if l(tA)~=l(tB) then
		return false--, Echo("IsEqual: table lengths differ")
	end
	local areTables= function(v1,v2) return  (t(v1)=="table" and t(v2)=="table") end
	local cnt1=0
	local cnt2=0

	for k1,v1 in pairs(tA)do
		cnt1=cnt1+1		
		for k2,v2 in pairs(tB)do
			cnt2=cnt2+1
			if cnt1==cnt2 then
			--Echo(k1.."=",v1,"vs "..k2.."=",v2 )
				if k1==k2 and (areTables(v1,v2) or v1==v2) then
					cnt2=0
					break
				else
					return false
				end
			end
		end

	end
	return true
end



l = function(T)
  if t(T)~="table" then return false, Echo("l: ",T, " is ",t(T)) end
  local count = 0
  for _ in pairs(T) do count = count + 1 end
  return count
end

bet = function (a,x,b) return (a<=x and x<=b or b<=x and x<=a) end

deepcopy = function (orig)
	local orig_type = t(orig)
	local copy
	if orig_type == 'table' then
		copy = {}
		for orig_key, orig_value in next, orig, nil do
			copy[deepcopy(orig_key)] = deepcopy(orig_value)
		end
		setmetatable(copy, deepcopy(getmetatable(orig)))
	else -- number, string, boolean, etc
		copy = orig
	end
	return copy
end

correctKey = function (T,searchValue)
	local key={}
	local value={}
	for k,v in pairs(T) do
		if t(k)=="number" and v==searchValue then
			return k
		elseif t(v)~="table" then
			table.insert(key, tostring(k))
			table.insert(value, v)
		end
	end
	table.sort(key)
	--Echo(key)
	--Echo("+-+-")
	for k,v in pairs(T) do
		if v== searchValue then

			for i=1, #key do

				if key[i]==k or key[i]==tostring(k) then
					return i
				end
			end
			return Echo("no key for this")
		end
	end
	return Echo("value not found")
end

vunpack = function(T)
	newT={}
	for k,v in pairs(T) do
		table.insert(newT,v)
	end
	return unpack(newT)
end

kunpack = function(T)
	newT={}
	for k,v in pairs(T) do
		table.insert(newT,k)
	end
	return unpack(newT)
end

keysunpack = function (t,k)
	local k = next(t,k)
	if k then return k,keysunpack(t,k) end
end


--[[InTable2 = function (t,...) -- even simpler
	local args = {...}
	if t(args[1])=="table" then 
		args = unpack(args)		   
	end
	local list = {}
	local one = false
	local checked = 0
	for i=1, #args do
		for k,v in pairs(t) do
			if t(v)=="table" then
				return InTable(v, args) 
			elseif (args[i] == v) then
				one = true
				table.insert(list, v)
				checked=checked+1
					break
			end
			
		end
	end

	return one,checked>=#args,list
end--]]

function table.size(t)
    local count = 0
    for _ in pairs(t) do
        count = count + 1
    end
    return count
end

function table.getkelems(T,Ti) -- extract listed elements (table Ti) from T
	local newt={}
	for k in pairs(Ti) do
		table.insert(newt,T[k])
	end
	return newt
end


function table.getelems(T,Ti) -- extract listed elements (table Ti) from T
	local newt={}
	for n=1,#Ti do
		table.insert(newt,T[Ti[n]])
	end
	return newt
end


function table.sumxz(T,x,z) --sum values of indexes x,z of each tables in T
  local rx,rz = 0,0
---  Echo("vunpack(T) is ", vunpack(T))
  for _,sub in pairs(T) do
	if t(sub)=="table" then

		rx = rx + sub[x]
		rz = rz + sub[z]
	end
  end
  return rx,rz
end

function table.inserts(T,...)
	local args={...}
	for i=1,#args do
		table.insert(T,args[i])
	end
	return l(T)
end


function table.merge2(T1,T2) -- add values of T2 to T1
	for k in pairs(T2) do
		table.insert(T1,T2[k])
	end
end 
function table.update(T1,T2,noret) -- add non-existent values of T2 in T1, also return the newly found values
	local changed=false
	for k,v in pairs(T2) do
		if not table.hasvalue(T1,v)
			then table.insert(T1,v)
			if not noret then
				if not changed then changed={} end
				table.insert(changed,v)
			elseif not changed then changed = true
			end
		end
	end
	return changed
end

function table.update2(T1,T2) -- add key/value pairs of T2 to T1, same keys will be replaced
	for k,v in pairs(T2) do
		T1[k]=v
	end
end

table.hasvalue = function (tA,B)
		for k,v in pairs(tA) do
			if v==B then
				return true
			end
		end
	return false
end

table.has = function(tA,B) -- verify if table contains exact same table, or same argument to one sublevel

	if t(B)=="table" then
		if isEqual(v,B) then
				return true
		else
			for _,v in pairs(tA) do
				if t(v)=="table" then 
					if isEqual(v,B) then
						return true
					end
				end
			end
		end
	else
		for k,v in pairs(tA) do
			if t(v)=="table" then
				for k2,v2 in pairs(v) do
					if v2==B then
						return true
					end
				end
			elseif v==B then 
				return true
			end
		end
	end
	return false
end
typematch = function(k,v,...)
	local args = {...}
	if t(args[1])=="table" then -- if arguments passed are in table
		args=args[1]
	end
	for i=1, #args do
		if args[i]=="metatable" then
			if k and getmetatable(k) or v and getmetatable(v) then return true end
		elseif k~=nil and t(k)==args[i] or v~=nil and t(v)==args[i]  then
			return true	
		end
	end
	return false
end

elemstrmatch = function(k,v,exact,...) -- case insensitive

	local args = {...}
	if t(args[1])=="table" then -- if arguments passed are in table
		args=args[1]
	end
	for i=1, #args do
			if exact then 
				if k==args[i] or v==args[i] then return true end
			else
				args[i] = tostring(args[i]):lower()
				k = t(k)=="string" and k:lower() or tostring(k):lower()
				v = t(v)=="string" and v:lower() or tostring(v):lower()
				if k:match(args[i]) or v:match(args[i])  then return true end
			end
	end
	return false
end


strinTable = function (T,...) -- Verif of elements in a table simpler and quicker version of InTable 
	--declaring arguments as a table imply that each element must be contained in the same table or subtable of the target
	local args = {...}
	if t(args[1])=="table" then -- if arguments passed are in table
		args=args[1]
	end
	local list = {}
	local one = false
	local checked = 0
	for i=1, #args do
		for k,v in pairs(T) do
			--Echo("k,v", k,v)
			if (t(k)=="string" and k:match(args[i]) or t(v)=="string" and v:match(args[i])) then
				one = true
				list[k]=v
				checked=checked+1
					break
			end
			
		end
	end

	return one,checked>=#args,list -- more detailed return : one match, all arguments match, table of each matched arguments
end

 inTable = function (T,...) -- Verif of elements in a table simpler and quicker version of InTable 
	--declaring arguments as a table imply that each element must be contained in the same table or subtable of the target
	local args = {...}
	if t(args[1])=="table" then 
		for k,v in pairs(T) do
			if t(v)=="table" then --subtable vs table scenario
				local _,res2 = inTable(v, unpack(args[1])) -- recursion for each subtable and lower levels
				if res2 then
					return true
				end
			else --table vs table scenario
				local _,res2 = inTable(T, unpack(args[1])) 
				if res2 then
					return true
				end
			end
		end
	return false
	end
---- base func : table vs separate arguments scenario
	local list = {}
	local one = false
	local checked = 0
	for i=1, #args do
		for k,v in pairs(T) do
			--Echo("k,v", k,v)
			if (args[i] == v) then
				one = true
				table.insert(list, v)
				checked=checked+1
					break
			end
			
		end
	end

	return one,checked>=#args,list -- more detailed return : one match, all arguments match, table of each matched arguments
end


InTable = function (T,spec,...) -- Check tables and subtables, can find out coords, elements, keys (and return their value)
								   -- return multiple results if multiple founds, result is detailed and sorted per pertinence (exact coords, exact same tables...)
	if t(T)~="table" then	   -- first return is always a bool telling if something relevant enough has been found(all arguments founds in at least one table, at least partial but correct coords({x,z} vs {x,y,z}), correct key found)
								   -- second return is the number of findings
								   -- third return is the table composed of each detailed result
								   -- each finding has a path attached to track back where it was found
								   -- ignorelist to avoid self referencing table

		return false, Echo("not a table")
	end
	local isTable = t(spec or ...)=="table"
	local isCoord = spec=="coord"  
	local isKey   = spec=="key"
	local shallow = spec=="shallow"

	local args
	if isCoord or isKey or shallow then --
		args = t(...)=="table" and ...  -- "..." is a table we keep it as is for our research (too lazy to care about multiple tables)
				  or {...}		 			-- else we assume there are only separate value, we pack them into table to iterate them
	else
		args = t(spec)=="table" and spec -- same without coord asked, consider arguments including isCoord
				  or {spec,...}		 		
	end


	local alength = l(args)

	local allFounds = {}
	local nFound=0
	local path2={}
	local good = false
	local path = {}
	local ignorelist = {t}
	local recurCount=0

	-- guessing if we ask coords, then return will not be the same""
	--local allNumbers = table.foreach(args, function (k,v)  return t(v)=="number" end)

	----------------------------
	local function recursion(T)


		local ignoring = false
		local identical = false
		local length = l(T)
		local checked = 0
		local allin = false
		local sameValues = alength==length and isTable
		local fullCoords = false
		local XZcoords = false
		local acount, tcount = 0,0
		local coordsFound = false

		tcount=0 
		for k,v in pairs(T) do
			ignoring=false
			if isKey and args[1]==k then
				--Echo("found key")
				table.insert(allFounds,{true,v,path=path})
				nFound = nFound+1
				good = true
			end
			if t(v)=="table"  then -- ignoring identical table to avoid infinite recursion with self referencing table
				for i=1,#ignorelist do
					--Echo("checking ign #"..i,vunpack(ignorelist[i]))
					--Echo("vs v", vunpack(v))
					if IsEqual(ignorelist[i], v) then
						ignoring=true
						Echo("ignoring table ",k)
						--Echo("--	")
						break
						--Echo("found exact same ",k)
					end
				end
			end	
			tcount = tcount+1
			acount = 0	
			local cTKeys,cTValues = correctTable(T) -- named keys aren't ordered the same as indexed, we correct that
			-- ignore already seen same table name with same table length to avoid infinite recursion in self referencing table

			if t(v)=="table" and recurCount<5 and not ignoring and not shallow then -- if subtable => recursion and we note the path
				path[#path+1]=k -- updating path for the next instance of recursion

				--Echo("------new table to ignore("..k.."):", vunpack(v))
				ignorelist[#ignorelist+1]=v
				--Echo("new ign, length=", l(ignorelist[#ignorelist]))
				for k,v in pairs(ignorelist[#ignorelist])do
					--Echo("--------new ign content.."..k.." =",v)
				end
				recurCount = recurCount+1
				--Echo("recursion #"..recurCount.." in ",unpack(path))

				recursion(v)-- changing dimension 'o.o
				path[#path]=nil -- back now in this instance, we remove the last path
				--Echo("back to ", unpack(path))
			elseif not isKey and not coordsFound then

				for i,j in pairs(args) do
					acount = acount+1				
					local cAKeys,cAValues = correctTable(args)

					if isCoord then -- this will recognize matching pattern of coords values in a table: X,_,Z or X,Y,Z,
									-- no matter if the table got other elements in it as long as X,Y,Z or X,Z follows
									-- arguments of research must be {x,z} or {x,y,z}

						local I = alphaKey(j,cAKeys,cAValues) -- getting equivalent of arg key in alphabetical order to fix named keys order...
						local K = alphaKey(v,cTKeys,cTValues)
						if j==v and I==1 then -- if found x value of our searched coord, checking other values in alphabetical order
							local j2 = alphaValue(I+1,cAKeys,cAValues)
							local j3 = alphaValue(I+2,cAKeys,cAValues)

							local v0 = alphaValue(K-1,cTKeys,cTValues)
							local invalidv0 = not (v0 and t(v0)=="number")
							local v2 = alphaValue(K+1,cTKeys,cTValues)
							local v3 = alphaValue(K+2,cTKeys,cTValues)
							local invalidv3 = not (v3 and t(v3)=="number")

							fullCoords  = fullCoords or
										  length==2 and alength==2 and j2==v2 or 									-- arg{x,z} vs t{x,z}
										  length>=3 and invalidv0 and invalidv3 and alength==2 and j2 and j2==v2 or -- arg{x,z} vs t{...,x,z,notnumber,...}
										  length>=3 and alength==3 and j2 and j2==v2 and j3 and j3==v3 				-- arg{x,y,z} vs t{...,x,y,z,...}
							XZcoords	= XZcoords or fullCoords or
										  alength==2 and invalidv0 and j2 and v3 and j2==v3 or 						-- arg{x,z} vs t{...,x,y,z,...}
										  alength==3 and invalidv0 and invalidv3 and j3 and j3==v2 					-- arg{x,y,z} vs t{...,notnumber,x,z,notnumber,...}
							good = good or XZcoords or fullCoords
							coordsFound = XZcoords or fullCoords
							if XZcoords or fullCoords then
								table.insert(allFounds,{XZcoords,fullCoords,path=path})
								nFound=nFound+1
							end
							break
						end
					elseif (j == v) then -- normal search

						
						--Echo("match")
						--Echo("Arg     ["..i.."] = "..j.." vs ")
						--Echo("Table  ["..k.."] = "..v)
						sameValues = (j==v and I==K)-- same table but type of key can differ
								or	 I~=K and sameValues  
						identical =  length==alength and i==k and j==v or (acount~=tcount and identical) -- same exact table, (parallel: keys, type of keys, values; and same length)
	
						checked=checked+1
						allin = checked>=alength
						good = good or allin
						break
					end
					--Echo("j=",j,"v=",v)
				end
				if tcount == length and allin then

					table.insert(allFounds,{allin,sameValues,identical,path=path}) -- found a table with at least all matching arguments
					nFound=nFound+1
				end
			end
		
		end
	end
	----------------------------
	recursion(T)


	if #allFounds>1 and not isKey then -- giving best result at start of the array 
		if isCoord and not allFounds[1][2] then
			local best = 1
			while best<3 do
				for i=2, #allFounds do 
					if allFounds[i][best] then
						table.insert(allFounds,1,table.remove(allFounds,i)) --switching elements
					end
				end
				best=best+1
			end
		elseif not allFounds[1][3] then
			local best = 2
			while best<4 do		
				for i=1, #allFounds do 
					if allFounds[i][best] then
						table.insert(allFounds,1,table.remove(allFounds,i))
					end
				end
				best=best+1
			end
		end
		return good,nFound,allFounds		
	elseif #allFounds==1 then
		return unpack(allFounds[1])
	end
	return false,false,false,false

end
---------------------------------------------------------------------

--------------------------------------------------------
--Allow to compare named values vs indexed values in the same order
--------------------------------------------------------

correctTable =function (T) -- give 2 tables, one of key the other of values, both sorted alphabetically (subtable removed)
	local keys={}
	local values={}
	for k,v in pairs(T) do -- create table filled by keys as strings
		--if t(v)~="table" then
			table.insert(keys, tostring(k))
		--end
	end
	table.sort(keys)  -- sorting keys alphabetically
	for i=1, #keys do -- iterating through key and making new table of values in the right orders
		for k,v in pairs(T) do
			if keys[i]==tostring(k) then
				table.insert(values, v)
			end
		end
	end
	return keys,values -- now we got 2 parallel tables with same index for each pair
end

alphaKey =function (searchValue,keys,values) -- complementary function of correctTable to find position of element in alphabetical order
	if not keys or not values or #keys~=#values then
		return false, Echo("wrong tables")
	end
	for i=1, #values do
		if searchValue==values[i] then
			return i -- return the position in alphabetical order
		end
	end
	return false
end

realKey = function (searchValue,keys,values) -- complementary function of correctTable to find position of element in alphabetical order
	if not keys or not values or #keys~=#values then
		return false, Echo("wrong tables")
	end
	for i=1, #values do
		if searchValue==values[i] then
			local realKey = tonumber(keys[i])~=nil and tonumber(keys[i]) or keys[i]
			return realKey -- return the corresponding key of the true table
		end
	end
	return false
end

alphaValue = function (searchIndex,keys,values) -- complementary function of correctTable to find value of element by its alphabetical order
	if not keys or not values or #keys~=#values then
		return false, Echo("wrong tables")
	end
	for i=1, #keys do
		if searchIndex==i then
			return values[i] -- return the value sorted alphabetically
		end
	end
	return false
end
----------------------
----------------------
--------------------------------------------------------- DEF ----------------------------------------------




GetCommandName=function(cmd)

	for k,v in pairs(CMD)do
		--if tonumber(v) and tonumber(v)>30000 then Echo("k,v is ", k,v) end
		--Echo("k is ", k)
		if v==cmd then
			return k
		end 
	end
	return "unknown command"
end
do
	local bool={[false]='false',[true]='true'}
	DebugUnitCommand=function (id, defID, team, cmd, params, opts, tag, fromSynced, fromLua)
		
		local name=UnitDefs[defID] and UnitDefs[defID].name or "UNKNOWN BUILD"

		--fromLua = fromLua==nil and 'nil' or bool[fromLua] or fromLua
		--fromSynced = fromSynced==nil and 'nil' or bool[fromSynced] or fromSynced
		--tag = tag==nil and 'nil' or bool[tag] or tag
		local myTeamID=sp.GetMyTeamID()

		local side=team==myTeamID and "MY " or
				 sp.AreTeamsAllied(team, myTeamID) and "ALLIED " or "ENEMY "
	  --local cmdname=GetCommandName(cmd)
		local debugcmd = cmd==1 and 'INSERT '..(cmdNames[params[2]]..'('..params[2]..')' or 'UNKNOWN')..' at '..params[1]..
									'\n'..GreyStr..'option(param3):('..table.kConcat(Decode(params[3]),' | ', 'only_true','debug_options'):upper()..')'
						 or cmd==2 and 'REMOVE Order '..tostring(params[1])
						 or (cmdNames[cmd] or 'UNKNOWN')..'('..cmd..')'
		local main = side..name:upper()..' ('..id..'): '..debugcmd..(tag and ' tag:'..tag or '')..(fromLua and ' (LUA)' or '')..(fromSynced and ' (SYNCED)' or '')
		Echo(main)
		Echo('PARAMS: '..table.kvConcat(params):upper())
		Echo('OPTIONS:'..table.kConcat(opts,' | ', 'only_true','debug_options'):upper())
		Echo('--')
		--Echo(table.tostring(params))
		--Echo(table.tostring(opts))

		return cmdname,name
	end
end

GetDef = function(id)
	if not tonumber(id) then return false and Echo("Invalid ID") end
	if t(id)=="table" then
		return id, "ud" 
	elseif sp.ValidUnitID(id) then
		return UnitDefs[sp.GetUnitDefID(id)], "unit"
	elseif UnitDefs[id] then
		return UnitDefs[id], "unit"
	elseif FeatureDefs[id] then
		return FeatureDefs[id], "feature"
	elseif sp.ValidFeatureID(id) then
		return FeatureDefs[sp.GetFeatureDefID(id)], "feature"
	else
		return false and Echo("Invalid ID")
	end
end

GetUnitOrFeaturePosition = function (id)
	if id <= Game.maxUnits then

		return sp.GetUnitPosition(id)
	else

		return sp.GetFeaturePosition(id - Game.maxUnits)
	end
end

GetTeamUnits = function ()
	local sel = sp.GetSelectedUnits()
	local units = sp.GetAllUnits()

	local myTeam = sp.GetMyTeamID()
	local teamUnits = {}
	for _,unitID in ipairs(units) do
		local unitTeam = sp.GetUnitTeam(unitID)
		if unitTeam == myTeam then
			table.insert(teamUnits, unitID)
		end
	end
	return teamUnits
end
IsGroupNumber = function(key) return key>=49 and key<=58 end

-------------------------------------------------------- UTILS --------------------------------------------

FullTableToStringCode = function (T,p)
	 --+ you can stop at any desired subtable level
	 --+ sort syntaxe must be a table like: {['element1']=orderNumber,...} orderNumber can be negative as it will signify to put it from the end of the string
	 -- orderNumbs doesnt have to be exact, as some elements asked might miss, so the smallest numbers will get first places, same for the end of table
	 --+ you need to give userdata names in a table as follow {[userdata1]="name of userdata1",[userdata2]="name of userdata2"...},
	 -- you can skip this if your userdatas are  paired with their name
	 --+ the sorting and breaklines can be applied until reached the level you want: params "breaks" as number or true if infinite, sortLevel: infinite by default if there is a sort table

	local clip,breaks,breaksLevel,userdatas,sort,level,sortLevel,offset = p.clip,p.breaks,p.breaksLevel,p.userdatas,p.sort,p.level,p.sortLevel,p.offset
	local str=""
	
	sortLevel = sort and tonumber(sortLevel) or sort and math.huge or 0

	offset=offset or  "   "

	local breaksLevel =  tonumber(breaks) or tonumber(breakslevel)  or breaks and math.huge or 0
	local maxLevel = level and tonumber(level) or level and math.huge or 1
	level=1
	local function Recursion(T,p)

		local level,breaksLevel,sortLevel = p.level, p.breaksLevel,p.sortLevel 
		local br=breaksLevel>0

		local sorting = sortLevel>0
		if level<maxLevel then return "<table>" end
		local indexes,sortIndex={},{}
		local udcount,min,max=0,0,0
		local elements={}

		-- Pair to String Conversion part
		for i in ipairs(T)do indexes[i]=true end
		local str=''
		for k,v in pairs(T) do
			local kstr,vstr,kvstr='','',''
			--
			if type(k)=='table' then kstr= "["..Recursion(k,{level=level+1,breaksLevel=breaksLevel-1,sortLevel=sortLevel-1})..']='
			elseif type(k)=="userdata" then
				udcount=udcount+1
				kstr=userdatas and userdatas[k]..'=' or
				type(v)=='string' and v or
				'<userdata'..udcount..'>='
			elseif type(k)=='string' then
				if k:match('%A') then kstr='["'..k..'"]='
								 else kstr=k.."=" end
			elseif type(k)=='boolean' then kstr='['..tostring(k)..']='
			elseif type(k)=='number' then
				if indexes[k] then kstr=''
							  else kstr='['..k..']=' end
			end
			if br then  kstr = offset:rep(level)..kstr end
			--
			if type(v)=='table' then vstr= Recursion(v,{level=level+1,breaksLevel=breaksLevel-1,sortLevel=sortLevel-1})
			elseif type(v)=='string' then vstr='"'..v..'"'
			elseif type(v)=='boolean' then vstr=tostring(v)
			elseif type(v)=='userdata' then 
				udcount=udcount+1	
				vstr=userdatas and userdatas[v] or
					 type(k)=='string' and k or
					 '<userdata'..udcount..'>='
			elseif type(v)=="number" then vstr=v
			end
			--
			kvstr=kstr..vstr..", "
			str=str..kvstr
			if br then str=str..'\n' end

			if sorting then -- if sorting then keeping only matched search in another table, with reversed key/value (num=string)
				elements[#elements+1]=kvstr

				local search=kvstr:match('^[%s]-(%a+)')
				--Echo("search is ", search)
				local num=sort[search]

				if num then

					sortIndex[num]=search
					
					-- noting min, max values found for later iteration
					if num>max then max=num	elseif num<min then min=num	end	
				end
			end

		end -- end conversion
		------- Ordering part

		if sorting then
			-- define the real place where matched elements should go
			local neworder={} 
			local endpos=0 -- insert positive elements found in the correct index
			for i=1,max    do  if sortIndex[i] then endpos=endpos+1 neworder[ sortIndex[i] ]=endpos end end
			local place=#elements+1 -- insert negative ones from the end of the future table
			for i=0,min,-1 do  if sortIndex[i] then	place=place-1 neworder[ sortIndex[i] ]=place end end
			--
			--Page(neworder)
			local orderedElements={}
			-- now putting the matching elements at their defined place in a new table and removing them from the elements list
			Page(sortIndex)
			local lng=#elements
			for i=1,lng do 
				local elem=elements[i]
				local ordNum=neworder[elem:match('^[%s]-(%a+)')]
				if  ordNum then
					--Echo("elem,ordNum is ", elem,ordNum)
					orderedElements[ordNum]=elem
					elements[i]=nil
				end
			end
 --Echo("=>",Page(orderedElements)) 
			for k,v in pairs(elements) do Echo(k,v) end
			-- finally completing the new list with the rest of elements

			for i=1,lng do
				local elem=elements[i]
				
				if elem then  endpos=endpos+1  orderedElements[endpos]=elem --[[table.insert(orderedElements,elem)--]] end
			end
			--
--

			str=""
			for _,elem in ipairs(orderedElements) do
			  str=str..elem
			  if br then str=str.."\n" end
			end
			--f.Page(orderedElements)
		end
		--- end of ordering

		str=(br and "{\n" or "{")..str
		str=str:sub(0,br and -4 or -3)..(br and "\n"..offset:rep(level-1).."}" or "}")

		if clip then sp.SetClipboard(str) end

		return str
	end
	str= Recursion(T,{level=level,breaksLevel=breaksLevel,sortLevel=sortLevel})
	return str
end



GetMouseOwner = function()
	local owner = wid.handler.mouseOwner and wid.handler.mouseOwner
	local ownerName = owner and owner.GetInfo and owner:GetInfo().name
	return owner,ownerName
end




Range = function(range) -- wrapper create and update table with fixed range size, giving also average and length
	range=not range and inf or range
	local items,nI={},0
	return function (item)
			nI=#items+1
			if nI>range then table.remove(items,1) nI=nI-1 end			
			items[nI]=item
			return items,table.sum(items)/nI,nI,nI==range
		end
end

AverageTrend = function (range,gap) -- wrapper produce a trend between two dynamic averages separated by a gap (if no gap given, first average will never change)

	local range1,avg1,r1length,r1Full={},0,0,false
	local range2,avg2,r2length,r2Full={},0,0,false
	local items,iLength,iFull={},0,false
	local avg1,avg2,trend
	local UpdateItems=Range((gap and gap or 0)+range*2)
	local UpdateRange1=Range(range)
	local UpdateRange2=Range(range)


	local tmpavg1,tmpavg2,count,tmptrend=0,0,0,1
	return function (item)

			items,_,iLength,iFull=UpdateItems(item)

			if iLength>range*2 then
				range1,avg1,r1length,r1Full=UpdateRange1(items[range+1])

			else
				local half=floor(#items/2)
				half=half==0 and 1 or half				
				range1,avg1,r1length,r1Full=UpdateRange1(items[half])
			end
			range2,avg2,r2length,r2Full=UpdateRange2(items[iLength])


				trend=round(avg2/avg1,2)

			return trend,avg1,avg2
		end
end


TimeStr = function (time)
	time=math.round(time)
	local second = math.round(time%60)
	second=second>10 and second or "0"..second
	return time>59 and floor(time/60)..","..round(time%60).."min" or round(time).."sec"
end


Table = function(t)
	return setmetatable(t, {__index = table})
end


badtimer= function(n) -- not precise but standalone
	return nround(clock(),n)==nround(clock()+1,n)
end

local co = coroutine.create(function (f)
	while f do
	f = coroutine.yield(f())
	end
end)

---
function CheckTime(origOrder,...) -- can execute function and check its time of execution
	--if function is the order then it will check time of execution
	--if function and argument are in '...' then it will wrap a function that execute the argfunc with its arguments when called with 'run'
	local time

	local renew
	local func, funcArgs
	local GetTimer=sp.GetTimer
	local DiffTimers=sp.DiffTimers
	local elapsed, average, count = 0,0,0
	local origArgs = {...}
	local renewfunc=function(pause)
        time, renew, elapsed,  count = not pause and GetTimer(), false,0,0
    end
	if origOrder=="start" then
		time=GetTimer()
	elseif origOrder =='set' then
		-- nothing
	end

	if t(origOrder)=='function' then
		time=GetTimer()
		local code = wid.code
		local linecount=0
		local name
		local currentline = debug.getinfo(2).currentline
		for word in wid.codelines[currentline]:gmatch('[%a]+') do
			if (wid.mainfuncs[word] or wid.utilfuncs[word]) and not word=='CheckTime' then
				name=word
				break	
			end
		end
		if not name then name = wid.codelines[currentline]:match('CheckTime%((%s-.*%))') end
		local ret = {origOrder(...)}		
		elapsed=DiffTimers(GetTimer(),time)
		Echo(--[["function "..--]]name.."\n"..GreyStr.." finished in:"..elapsed )
		return unpack(ret)
	else
		if t(origArgs[1])=='function' then
			func=table.remove(origArgs,1)
		end
		return function(order,comment,...)
			--Echo("self.verify is ", self.verify)
			local norestart
			if time then 
				elapsed=elapsed+(DiffTimers(GetTimer(),time))
				time= (order~='pause' and order~='stop') and GetTimer()
			end
            if order == 'count' then
                if count == comment then
                    comment = (...)
                    comment = (comment and comment .. ', ' or '') .. ('elapsed: ' .. elapsed .. ',average: ' .. elapsed / count .. ' (' .. count .. ' counts).')
                    renew = true
                else
                    comment = nil
                end
                count = count + 1
                if not time then
                    time = GetTimer()
                end

			elseif order=='average' then
				if not time then
					time = GetTimer()
					return
				else
					count=count+1
				end
				if count==comment then
					comment = (...) or 'say'
					elapsed = elapsed/count
					renew = true
					norestart = true
				else
					time=nil
				end
			elseif order=='run' then
				func(unpack(origArgs))
			elseif tonumber(order) then
				return tonumber(order)<=elapsed
			elseif order=="reset" then
				renew=true
			elseif order=='restart' then
				return CheckTime(origOrder,unpack(origArgs))
			elseif order=="say" and not comment then
				comment='say'
			elseif order=="resume" and not time then -- can be used as a  start too
				time=GetTimer()
			end
			if comment then

				Echo((comment=="say" and "elapsed:"..elapsed or comment))
			end

			return elapsed, renew and renewfunc(norestart)
		end

	end
end

--local res={allow(tick[1],1,Continue, A, "A")}
--local res = {allow(tick[1],1,Continue, A, "A")}
--local allowed, newtick, valid,ended, results = res[1],res[2],res[3],res[4],select(5,unpack(res))
--Echo("allowed, newtick, valid,ended is ", allowed, newtick, valid,ended,results)
-- allowed,tick[1],valid,ended,res1,res2,e = allow(tick[1],1,Continue, A, "A")
--Echo("  allowed,tick[1],valid,ended,res1,res2,e is ",   allowed,tick[1],valid,ended,res1,res2,e)
--[[tick[1]=newtick
if allowed and ended then
	if valid then 
		Echo("results ",unpack( results))
	else
		Echo("restarting")
	end
end--]]
--[[local newtick, valid,ended, results = res[1],res[2],res[3],res[4],select(5,unpack(res))

		tick[1]=newtick
 if ended then 

end--]]

--[[function f (s)
  print ("Entering f with value", s)
  v = coroutine.yield ()
  print ("After yield, v is", v)
  return 22
end -- f

resumer = coroutine.wrap (f) 
resumer (88)  -- start thread
resumer (99)  -- resume after yield

--]]
local tick={}
function ControlFunc(delay,route,argument,func,...) -- using allow and orderRoutine control execution of function(delay,ending, variable added...)
	--- Example ---
--[[		local validA,endedA,resultsA = ControlFunc(1,"Def","end_now",DefineBlocks)
		if validA and endedA then
			places,blockIndexes=unpack(resultsA)
		end--]]
	----
	local immediate= delay==0 or argument=="end_now" or argument=="break"
	local res
	local allowed, newtick,valid,ended,results
	local msg
	if not immediate then
		res={allow(tick[route],delay,orderRoutine,argument,route,func,...)}
		allowed, tick[route],valid,ended,results = res[1],res[2],res[3],res[4],res[5]

	else
		res={orderRoutine(argument,route,func,...)}
		valid,ended,results = res[1],res[2],res[3]

	end

	if allowed or  immediate then 
		return valid,ended,results
	end
end

function allow(tick,nsec,f,...) -- run a function every n second(s) (n can be a fraction)

	local time=nround(clock(),nsec)
	if tick~=time then
		tick = time
		if f then
			return true,tick,f(...)
		else
			return true,tick
		end
	end
	return false,tick
end
routes={}

function orderRoutine(argument,name,func,...)
	local current=routes[name]
	if argument=="restart" then
		routes[name]=nil
		routes[name]=coroutine.create(func)
	elseif (argument=="end" or argument=="end_now") and not current then
		routes[name]=coroutine.create(func)
		--return false,false,false,Echo("no such thread: "..name)
	elseif not current and not argument=="break" or argument=="loop" and coroutine.status(current)=="dead" then
		routes[name]=coroutine.create(func)
	elseif coroutine.status(current)=="dead" then
		return false,false,false,Echo("thread "..name.." has ended")
	end
	current=routes[name]
	local res
	if argument=="break" then
		Echo("break")
		--res={coroutine.resume(current,"Break",...)}
		routes[name]=nil
		return false,false,false
	elseif argument=="end_now" then
		repeat 
			res={coroutine.resume(current,"end_now",...)}
		until coroutine.status(current)=="dead"
	else res={coroutine.resume(current,...)}
	end

	local valid=res[1]
	local ended=coroutine.status(current)=="dead"
	local results={select(2,unpack(res))}
	return valid,ended,results
end

function memoize (f)
	local mem = {} -- memoizing table
	setmetatable(mem, {__mode = "kv"}) -- make it weak
	return function (x) -- new version of ’f’, with memoizing
		local r = mem[x]
		if r == nil then -- no previous result?
			r = f(x) -- calls original function
			mem[x] = r -- store result for reuse
		end
		return r
end	end




function toValidPlacement(x,z,oddx,oddz)

	x = floor((x + 8 - oddx)/16)*16 + oddx
	z = floor((z + 8 - oddz)/16)*16 + oddz
	return x,z
end


function toMouse(...)

	local x,y,z	= ...
	if t(x)=="table" then
		x,y,z = x[1],x[2],x[3]
	end

	if not z then
		y,z = sp.GetGroundHeight(x,y), y
	end
	return sp.WorldToScreenCoords(x,y,z)
end



function clone_function(fn)
  local dumped = string.dump(fn)
  local cloned = loadstring(dumped)
  local i = 1
  while true do
	local name = debug.getupvalue(fn, i)
	Echo(name)
	if not name then
	  break
	end
	local a = debug.setupvalue(cloned, i, fn, i)
	Echo(a)
	i = i + 1
  end
  return cloned
end


function research(t,max,term,maxtables)
	local found
	local checks=0
	local alltables=0
	local function search(t,path,max,level)
		if found then return end
		level = level+1 
		checks=checks+1
		for k,v in pairs(t) do 
			if k==term then Echo('Found!',k,v,path) found=true return end
			if v==term then Echo('Found!',k,v,path) found=true return end
		end
		if found then return end
		for k,v in pairs(t) do 
			alltables=alltables+1
			if alltables>maxtables then return end
			if type(k)=='table' then search(k,path..'/'..tostring(v),max,level) end
			if type(v)=='table' then search(v,path..'/'..tostring(k),max,level) end
			if found then return end

		end
	end
	for k,v in pairs(t) do
		if k==term then Echo('Found!',k,v,'getfenv') found=true return end
		if v==term then Echo('Found!',k,v,'getfenv') found=true return end
	end
	for k,v in pairs(t) do
		if type(k)=='table' then  search(k,tostring(v),max,0) end
		if type(v)=='table' then  search(v,tostring(k),max,0) end
			alltables=alltables+1
			if alltables>maxtables then return end
	end
end



res = function (n,...)
	local results={...}
	return results[n]
end


function BenchMark(init1,code1,iterations,init2,code2) -- testing operations time by loadstring, need more testing, might be useless
	init1 = loadstring(init1)
	init1()
	code1=loadstring(code1)
	local time=clock()
	for i=1,iterations do code1() end
	local res1=clock()-time
	init2 = loadstring(init2)
	init2()
	code2=loadstring(code2)
	time=clock()
	for i=1,iterations do code2() end
	local res2=clock()-time
	return res1/res2, res1,res2
end


function GetRealWidgetHandler(w)
	local w = w or widget
	if w.widgetHandler.widgets then
		return w.widgetHandler
	end
	local i,n,v = 0, true
	while n do
		i=i+1 
		n,v=getupvalue(widgetHandler.RemoveCallIn, i)
		if n=='self' then
			return v
		end
	end
end
function GetBaseName()
    for i=4, 12 do 
        local k,v = debug.getlocal(i,5)
        if k=='basename' then
            return v
        end
    end
end

function GetWidgetName(w)
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

 -- CALL IN AUTO DISABLER -- disable every callins except for the ones that inform us of team changing-- this is intended to  reactivate widget fully when coming from spec to play
 -- wrapper in 2 steps,
 -- optional: is to setup team changing CallIns from here if you need them only for checking that and you don't want them to put in the body of your widget
 -- in that case and if you need to get notified whenever your team change, you can put the function MyNewTeamID(teamID) in the widget body, that will work as a CallIn
 -- usage: local DisableOnSpec =  DisableOnSpec(_,widget,true) in the body of the widget
 --
 -- with or without the optional first step, next step is setting up the disabler that will only toggle the callins (except the ones that check the team changing, and a few other)
 -- usage: after declaring the local in the body, do DisableOnSpec  =  DisableOnSpec(widgetHandler,widget) in Initialize CallIn 
 -- if you didnt opt to create team changing CallIns here, you will have to put DisableOnSpec() in your team changing CallIns instead
function DisableOnSpec(widgetHandler,widget,setupTeamChangers)
	local excluded = setmetatable({},{__index=function(_,k) return k:match'Player' or k:match('Team') or k:match('List') or k=='Initialize' or k=='Shutdown' end})
	local ownCallins,toggleCallins = {},{}
	local getupvalue = debug.getupvalue
	local spGetSpectatingState,spGetMyTeamID = sp.GetSpectatingState,sp.GetMyTeamID
	local realHandler
	local MyNewTeamID,disabled
	local disabler = function()
		
		if MyNewTeamID then MyNewTeamID(spGetMyTeamID()) end
		if spGetSpectatingState() then 
			
			if not  disabled then Echo('disabling..') for ci in pairs(toggleCallins) do Echo(ci..'...') realHandler:RemoveWidgetCallIn(ci,widget) end disabled=true end
		else
			if      disabled then Echo('enabling..') for ci in pairs(toggleCallins) do Echo(ci..'...') realHandler:UpdateWidgetCallIn(ci,widget) end disabled=false end
			
		end
	end
	local function registerer(widgetHandler,widget)
		MyNewTeamID = widget.MyNewTeamID
		local i,n,v,callInList = 0,true    	
		if widget:GetInfo().handler then
			realHandler=widgetHandler
		else -- if widget doesnt use the real widgetHandler, we gonna find it ourself...
			while n do i=i+1 n,v=getupvalue(widgetHandler.RemoveCallIn, i) if n=='self' then realHandler=v break end end
		end
		i,n=0,true -- then we can find the callins name registered in widgetHandlers...
		while n do i=i+1 n,v=getupvalue(realHandler.UpdateCallIns, i) if n=='callInList' then callInList=v break end end
		for k,v in pairs(realHandler) do
			if widget[k] and type(v)=='function' then -- ...and deduce what callins are in our widget
				ownCallins[k]=true
				if not excluded[k] then
					toggleCallins[k]=true
				end
			end
		end
		return disabler -- return the disabler in case it is needed by the user either bc he didnt choose 'setupTeamChangers' or he wants it for other means
	end
	if setupTeamChangers then 
		function widget:TeamChanged()   disabler() end
		function widget:TeamDied()      disabler() end
		function widget:PlayerAdded()   disabler() end
		function widget:PlayerChanged() disabler() end
		function widget:PlayerRemoved() disabler() end
		return registerer -- return a prepared function to be run in Initialize (TODO:verify if its needed to be in Initialize)
	end
	return registerer(widgetHandler,widget) -- return directly the disabler
end

table.round = function(ori,makeCopy)
	local T = makeCopy and {} or ori
	for k,v in pairs(ori) do T[k]=round(v) end
	return T
end

unpackstrKV = function(T,k)
	local k,v = next(T,k)
	return k==nil and '' or tostring(k)..'='..tostring(v)..', '..unpackstr(T,k):sub(0,-2)
end
unpackstr = function(T,k)
    local k,v = next(T,k)
    return k==nil and '' or tostring(v)..(next(T,k) and ', '..unpackstr(T,k) or '')
end
function table:subtoline(k)
    local str = ''
    for t,sub in pairs(self) do
        local substr = type(sub) == 'table' and sub[k]
        if substr then
            str = str .. substr .. ', '
        end
    end
    return str:sub(0,-3)
end
table.toline = function(T,tocode,maxLength,ndec)
	local str=""
	local len = 0
    local cnt = 0
	for k,v in pairs(T) do 
		local add
        cnt = cnt+1
        if type(v) == 'number' and ndec then
            v = ('%.' .. ndec .. 'f'):format(v)
        end
		if tocode then
			v= t(v)=="string" and '"'..v..'"' or tostring(v)
			k = t(tonumber(k))=="number" and "["..k.."]" or tostring(k)
			add = k.."="..v..", "
		else
            if k==cnt then
                add = tostring(v) ..", "
            else
			    add = "["..tostring(k).."]="..tostring(v)..", "
            end
		end
		if maxLength then
			local newlen = len + #add
			if newlen > maxLength then
				return str .. '...'
			end
			len = newlen
		end
		str = str .. add
	end
	return str:sub(0,-3)
end
table.tostring = function(T,tocode,length)
local str=""
local add = ""
	for k,v in pairs(T)do
		if tocode then
			v= t(v)=="string" and "'"..v.."'" or tostring(v)
			k = t(tonumber(k))=="number" and "["..k.."]" or k
			str = str..""..k.."="..v..", "
		else
			
			str = GreyStr..str..add.."["..k.."]="..tostring(v)..", \n"..GreyStr
			add= (function()  while length and add:len()<length*2 do add=add.."  " end return add end)()
		end
	end
	str=str:sub(0,-8)
	--Echo("stringresult:",str)
	return str
end



------------------ FUNCTIONMENT -------------------------




----------------------------------- DEBUGGING ----------------------------------------------------------

function CreateDebug(Debug,widget,path)
    if not Debug then
        Echo('DEBUG FOR '..widget:GetInfo().name.." HASN'T BEEN GIVEN !")
        return {}
    end
    local allKeys = {} -- create a tree of relevant keys
    local varDebug
    local widgetDebug = Debug

    if Debug.saved then
        Debug, Debug.saved = Debug.saved, nil
    end

    local internalkey = {
        haskey = true,
        keys = true,
        hotkeys = true,
        callbacks = true,
    }


    local notboolkey = {
        reload = true,
        log = true,
        Log = true,
        debugvar = true,
        debugVar = true,
    }

	-- update the options name and hotkeys of Debug to conform to the widget Version in case they have been edited since the last config loading
	for optName,v in pairs(widgetDebug) do
		if Debug[optName]==nil then
			Debug[optName] = v
		end
	end
	for optName,v in pairs(Debug) do
		if widgetDebug[optName]==nil then
			Debug[optName] = nil
		end
	end
	Debug.hotkeys = widgetDebug.hotkeys
    local callbacks = widgetDebug.callbacks
    Debug.haskey={}
    for opt_name,keys in pairs(Debug.hotkeys or {}) do
        if Debug[opt_name]~=nil then
        	local validKey,wrongKey
    		-- verify the valid key
        	for i,key in ipairs(keys) do
        		if MODS[key:lower()]==nil then
        			validKey = KEYSYMS[key:upper()]
	        		if validKey then
	        			Debug.haskey[validKey]=true
	        		else
	        			wrongKey=key
	        		end
        			break
        		end

        	end
        	if validKey then
		        local thiskey = allKeys
	    		for mod in pairs(MODS) do -- we must keep the same order as the mods table
			        for i,m in ipairs(keys) do
			            if mod==m:lower() then
			                thiskey[mod] = thiskey[mod] or {}
			                thiskey = thiskey[mod]
			            end
			        end
			    end
			    thiskey[validKey]=opt_name
            else
            	if wrongKey then
            		Echo(widget:GetInfo().name..' Debug Creation: the key '..wrongKey..' for '..opt_name..' is not recognized.' )
            	else
            		Echo(widget:GetInfo().name..' Debug Creation: the hotkey for '..opt_name.." doesn't have any non-mod key" )
            	end
            end
        else
        	local strKey = ''
        	for i,key in ipairs(keys) do strKey=strKey..key..(next(keys,i) and ' + ' or '') end
        	Echo(widget:GetInfo().name.." Debug Creation: the hotkey '"..strKey.."' refer to an inexistant '"..opt_name.."' in Debug, it will be ignored")
        end
    end
    Debug.keys = allKeys
    local proxy = {}
    proxy.dummy = function() return false end
    proxy.Echo = function(...)
        return true, select('#',...)>0 and Echo(...) or nil 
    end
    proxy.Switch = function(opt_name, on_off)
        -- if not (opt_name and (Debug.active or opt_name=='active')) then return end

        if opt_name == 'reload' then
            if Debug[opt_name] then
                Echo('Reloading ' .. widget:GetInfo().name)
                Spring.SendCommands('luaui disablewidget ' .. widget:GetInfo().name )
                Spring.SendCommands('luaui enablewidget ' .. widget:GetInfo().name )
            end
        else
            if on_off==nil then
                on_off = not Debug[opt_name]
            end
            if Debug[opt_name] == on_off then
                return
            end
            Debug[opt_name] = on_off
            if opt_name:lower() == 'log' then
                if on_off then
                    if proxy._Log then
                        proxy._Log:CreateWin()
                        proxy[opt_name] = proxy._Log
                    else
                        proxy[opt_name] = proxy.dummy
                    end
                else

                    if proxy._Log and proxy._Log.win and proxy._Log.win.visible then
                        proxy._Log.win:Hide()
                    end
                    proxy[opt_name] = proxy.dummy
                end
            elseif opt_name~='active' and not notboolkey[opt_name] then
                if Debug.active then
                    if on_off then
                        proxy[opt_name] = proxy.Echo
                    else
                        proxy[opt_name] = proxy.dummy
                    end
                end

            end
            -- if opt_name:lower()=='log' then
            --     if self.Log then
            --         self.Log:Delete()
            --     end
            --     self.Log = WG.LogHandler:New(widget)
            -- end
            
            Echo(widget:GetInfo().name..': debugging '..(opt_name~='active' and "'"..opt_name.."'" or '')..' is now '..(Debug[opt_name] and 'ON' or 'OFF').. (Debug[opt_name] and not Debug.active and ' (but debugging is inactive)' or '')  .. '.')
            if opt_name =='active' then
                for k, wantActive in pairs(Debug) do
                    if not internalkey[k] and k~='active' and not notboolkey[k] then
                        if wantActive then
                            if on_off then
                                proxy[k] = proxy.Echo
                                -- Echo('...activating '.. k)
                            else
                                proxy[k] = proxy.dummy
                                -- Echo('...deactivating ' .. k)
                            end
                        end
                    end
                end
            end
        end
    end
    proxy.GetPanel = function(path) -- 
        if path =='' then
            path = 'INGAME MENU'
        end
        for _,elem in pairs(WG.Chili.Screen0.children) do
            if  type(elem)     == 'table'
            and elem.classname == "main_window_tall"
            and elem.caption   == path
            then
                local scrollpanel,scrollPosY
                for key,v in pairs(elem.children) do
                    if type(key)=='table' and key.name:match('scrollpanel') then
                        scrollpanel=key
                        break
                    end
                end
                if scrollpanel then 
                    scrollPosY = scrollpanel.scrollPosY
                end
                return elem,scrollpanel,scrollPosY
            end
        end
    end
    proxy.CheckKeys = function(key,mods)
        if not Debug.haskey[key] then return end
        local hotkey = Debug.keys
        for mod,v in pairs(mods) do
            if v then
                hotkey = hotkey[mod]
                if not hotkey then return end
            end
        end

        local opt_name = hotkey[key]
        local allowed = opt_name == 'active' or Debug.active
        if opt_name and allowed then
            if path then

                -- widget have debugging in option panel
                if widget.options[opt_name].type == 'bool' then
                    widget.options[opt_name].value = not widget.options[opt_name].value
                end
                widget.options[opt_name]:OnChange()
                -- check if panel is open and refresh it
                local panel,_,scrollY = proxy.GetPanel(path)
                if panel then
                    WG.crude.OpenPath(path)
                    if scrollY and scrollY~=0 then
                        local _,scrollpanel = proxy.GetPanel(path)
                        scrollpanel.scrollPosY=scrollY -- scrolling back
                    end
                end
                --
            else
                proxy.Switch(opt_name)
            end
        end
        return
    end
    proxy.GetSetting = function()
        return Debug
    end

    -- Setup the initial function of each option
    for k,on in pairs(Debug) do
        if not internalkey[k] then
            if k=='debugVar' then
                if not widget.debugVars then
                    Echo('widget.debugVars is not present in widget ' .. widget:GetInfo().name)
                elseif on then
                    varDebug = DebugWinInit2(widget,unpack(widget.debugVars))
                    if widget.DebugUp then
                        widget.DebugUp = varDebug.DebugUp
                    end
                end
            else
                if k:lower() == 'log' then
                    if WG.DebugCenter then
                        proxy._Log = WG.DebugCenter.Add(widget,{Log='Log'})
                    else
                        proxy._Log = WG.LogHandler:New(widget)
                    end
                    -- Echo(os.clock(),k,v)
                    if on then
                        if proxy._Log then
                            proxy._Log:CreateWin()
                            proxy[k] = proxy._Log
                        else
                            proxy[k] = proxy.dummy
                        end
                    else

                        if proxy._Log and proxy._Log.win and proxy._Log.win.visible then
                            proxy._Log.win:Hide()
                        end
                        proxy[k] = proxy.dummy
                    end
                elseif not notboolkey[k] then
                    if on and Debug.active then
                        -- Echo('initialize '.. k .. ' as On')
                        proxy[k] = proxy.Echo
                    else
                        -- Echo('initialize '.. k .. ' as Off')
                        proxy[k] = proxy.dummy
                    end
                end
            end
        end
    end
    proxy.Shutdown = function()
        if type(proxy._Log) == 'table' then
            proxy._Log:Delete()
            proxy._Log = nil
        end
    end

    setmetatable(
        proxy
        ,{
            -- __index = function(self,opt_name)
            --     return Debug.active and Debug[opt_name] and (opt_name:lower()=='log' and self._Log or self.Echo)  or self.dummy
            -- end,
            __call = function(self,...)
                return proxy.global(...)
            end,
        }
    )

    if path then
        widget.options_order = widget.options_order or {}
        widget.options = widget.options or {}
        local setting =  proxy.GetSetting()
        local orderIndex = {lbl_debug=0,reload=1,active=2,global=3}
        local sort = function(a,b)
            if orderIndex[a] then
                return not orderIndex[b] or orderIndex[a] < orderIndex[b]
            end
        end    
        local debugOrder = {}
        for k,v in pairs(setting) do
            if not internalkey[k] then
                if k=='debugVar' then

                    widget.options[k] = {
                        name = 'debugVar',
                        type = 'bool',
                        value = v,
                        path = path,
                        OnChange = function(self)
                            if not widget.debugVars then
                                Echo('widget.debugVars is not present in widget ' .. widget:GetInfo().name)
                                return
                            end
                            if self.value then
                                if not varDebug then
                                    varDebug = DebugWinInit2(widget,unpack(widget.debugVars))
                                    if widget.DebugUp then
                                        widget.DebugUp = varDebug.DebugUp
                                    end
                                    widget.varDebug = varDebug
                                    varDebug.win:Show()
                                end
                            else
                                if varDebug then
                                    varDebug:Delete()
                                    varDebug = nil
                                    if widget.DebugUp then
                                        widget.DebugUp = function() end
                                    end
                                    widget.varDebug = nil
                                end
                            end
                        end
                    }

                elseif k=='reload' then
                    widget.options[k] = {
                        name = 'Reload Widget',
                        type = 'button',
                        value = v,
                        path = path,
                        OnChange = function(self)
                            Echo('Reloading ' .. widget:GetInfo().name)
                            Spring.SendCommands('luaui disablewidget ' .. widget:GetInfo().name )
                            Spring.SendCommands('luaui enablewidget ' .. widget:GetInfo().name )
                        end
                    }
                elseif not notboolkey[k] or k:lower()=='log' then
                    widget.options[k] = {
                        name = 'debug ' .. k,
                        type = 'bool',
                        value = v,
                        desc = k=='active' and 'this active the rest' or '',
                        path = path,
                        OnChange = function(self)
                            if callbacks and callbacks[k] then
                                callbacks[k](self)
                            end
                            proxy.Switch(k, self.value)
                        end
                    }

                end
                table.insert(debugOrder,k)
            end
        end
        widget.options.lbl_debug = {name='Debug',type='label',path=path}
        table.insert(debugOrder,1,'lbl_debug')
        table.sort(debugOrder,sort)
        for i,name in ipairs(debugOrder) do
            table.insert(widget.options_order,name)
        end

    end
    return proxy
end


do
	local lastPage,lastTable
	Page = function (T,...) ----- display and handle content of table, 
		local r,w = RedStr,WhiteStr
		if not T then return false, Echo(w..'Page: table is '..tostring(T)) end
		if not T or t(T)=='string' and T:match('help') then help=true
		elseif t(T)~="table" then return false, Echo(w.."Page: argument#1 is not a table")
		elseif l(T)==0 then	return "end", Echo("Page: table is empty")
		end
		if help then
			local info = {
				 'Page Usage:'
				,'  Page(table [, [params_table | arg1,.arg3] ])'
				,'  (you can copy this to clipboard with Page("cliphelp"))'
				,'  params_table='
				,'   { page    	=n               --page number'
				,'    ,nblines    =n             --lines per page,27 by default'
				,'    ,fIn        =str|{str,.}   --name(s) for match, '
				,'    ,fOut    	=str|{str,.}     --exclusion(s) '
				,'    ,fKType    	=str         --type of key to find'
				,'    ,fVType    	=str         --type of value to find'
				,'    ,fType    	=str         --type of k or v to find'
				,'    ,exactmatch =bool          --false by default '
				,'    ,highlight  =str|{str,.}   --highlight given found key(s)'
				,'    ,content    =bool          --show also content of found tables'
				,'    ,keys       =bool          --return keys'
				,'    ,obj        =bool          --return first value found'
				,'    ,objs       =bool          --return table of found values'
				,'    ,report     =bool          --return the whole result as string'
				,'    ,clip       =bool          --copy result to clip'
				,'    ,tocode     =bool          --return and show result as code'
				,'    ,show       =bool          --show result, on by default'
				,'    ,loop       =bool          --return to arg.page or 1 if beyond'
				,'	  ,iterator   =function      --replace the "pairs" iterator by a customized one'
				,'	  ,next   	  =function      --next function must be given along the iterator'

				,'    ,all        =bool          --show all at once'
				,'   }'
				,'  Non-Table Arguments:(in any order and number)'
				,'  a number for the page,'
				,'  a string for name'
				,'  a string describing type to filter'
			}
			local str=''
			if T=='cliphelp' then
				for i,line in ipairs(info) do
					if i>1 then str=str..'\n' end
					str=str..line

				end
				sp.SetClipboard(str)
			else
				for i,line in ipairs(info) do
					if i==1 then str=r..line
					else str=str..'\n'..w..line
					end
				end
				Echo(str)
			end
			return
		end
		local args={...}
		if args[1] then
			if t(args[1])~='table' then
                -- case: quick params without table: (see help above)
				local isType = {['function']=true,['userdata']=true,['number']=true,['table']=true,['boolean']=true,['string']=true}
				for i=1,3 do
					if not args[i] 				then break
					elseif tonumber(args[i]) and not args.page       then args.page  = args[i] 
					elseif isType[args[i]]      				     then args.fType = args[i] 
					elseif t(args[i])=='string' or tonumber(args[i]) then args.fIn   = args[i]
					else Echo(r..'Page: wrong argument #'..i..', '..tostring(args[i])..' will not be taken into account\n'..w..'Type Page("help") for help' )
					end
					args[i]=nil
				end
			else
				args=args[1]
				if args.page and not tonumber(args.page) then Echo(r..'Page: warn page argument is not a number, showing first page...' ) args.page=1 end
			end
		end


		local page=tonumber(args.page)
		local fIn=args.fIn -- look for specific word, alone or in table (not case sensitive)
		local fOut=args.fOut -- reject some unwanted results (reverse of fIn)--same possibilities
		local fType=args.fType -- look for a specific type 'table', 'function'...
		local fKType=args.fKType -- look for a specific type of key: 'table', 'function'...
		local fVType=args.fVType -- look for a specific type of value: 'table', 'function'...
		local highlight= args.highlight -- improve visiblity of elements founds by given keywords--same possibilities
		local exactmatch = args.exactmatch
		local content= args.content -- open found subtables at one level

		local keys= args.keys and {} -- return keys
		local obj = args.obj -- return first found value
		local objs = args.objs and {} -- return table of values
		local report = args.report  --return one big string with linebreak
		local clip = args.clip -- send also found results in clipboard
		local tocode = args.tocode and "" -- format result to code
		local concat = (report or clip) and "" 
		local show = args.show~=false -- show results, true by default
		local loop = args.loop~=false -- loop back to arg page when max page is reached, true by default
		local all = args.all or args.all==nil and (keys or obj or objs or report or strings) --all results at once, by default for some options
		local nblines= args.nblines or all and 1000000 or 27 -- nb of lines per page to show/research 27 by default, fitting right side of screen

		local iterator,next = pairs,next
		if args.iterator then
			if not args.next then
				Echo(r..'Page: You must give a next function in as params.next along with the iterator...' )
				return
			end
			iterator = args.iterator
			next = args.next
            if t(iterator)~='function' then
                Echo(r..'Page: the given iterator is not a function' )
                return
            end
            if t(next)~='function' then
                Echo(r..'Page: the given "next" is not a function' )
                return
            end
		end

		if fIn and t(fIn)~="table" then fIn={fIn}  end
		if fOut and t(fOut)~="table" then fOut={fOut}  end
		if fType and t(fType)~="table" then fType={fType} end

		if not page then 
			if lastPage and lastTable==T then -- we assume the user don't want to browse page using a variable, we will do it for him
				page = lastPage+1
				lastPage = page
				loop=true
			else
				page = 1
			end
		end
		lastTable,lastPage=T,page

		nblines = nblines or 27

		local length =0
		if not args.iterator then 
			length = l(T)
		else
			for _ in iterator(T) do length=length+1 end
		end

		local totalres=length
		local results={}


		local ln = 0 
		local filter
		local nbres=0
		local light
		local newk
		for k,v in iterator(T) do
			ln=ln+1
			local filter=false
			filter= fIn and not elemstrmatch(k,v,exactmatch,fIn)
			filter = filter or fOut and elemstrmatch(k,v,exactmatch,fOut)
			filter= filter or fType and not typematch(k,v,fType)
			filter= filter or fKType and not typematch(k,nil,fKType)
			filter= filter or fVType and not typematch(nil,v,fVType)
			light= highlight and elemstrmatch(k,v,highlight,exactmatch) and "\n" or ""

			if filter then
				ln=ln-1
				totalres=totalres-1

			elseif ln > (page-1)*nblines and ln <= (page)*nblines then -- if we're at the desired page
				nbres=nbres+1
				if obj==true then obj=v end

				if keys then keys[nbres]=k end
				if objs then objs[k]=v end
				if content and t(v)=="table" then
					if tocode then
						newk = t(tonumber(k))=="number" and "["..k.."]" or k
						tocode =tocode..newk.."={"..table.tostring(v,true).."},\n"
					end
					results[nbres]=light..ln..":["..k.."]:{"..table.tostring(v,false,tostring(k):len()+5).."}"

				else 
					if tocode then
						newv = t(v)=="string" and "'"..v.."'" or tostring(v)
						newk = t(tonumber(k))=="number" and "["..k.."]" or tostring(k)
						tocode=tocode..newk.."="..newv..", \n"
					end
					--if type(v)=='table' and v.GetInfo then v=v.GetInfo().name end
					local k,v = k,v
					if type(k)=='table' and k.GetInfo and k.GetInfo() then k=k.GetInfo().name end
					if type(v)=='table' and v.GetInfo and v.GetInfo() then v=v.GetInfo().name end
					results[nbres]=light..ln..":["..tostring(k).."]:"..tostring(v)..(t(v)=="table" and "("..l(v)..")" or "")
				end
				if concat then
					concat=concat..results[nbres].."\n"
				end
			end
			if ln < (page)*nblines and not next(T,k) then
				break
			end		
		end
		if tocode then
			tocode=tocode:sub(0,-4)
		end
		
		local nbpages = ceil(totalres/nblines)
		if nbpages==0 then
			return false, Echo("Page found nothing.")
		end

		if page>nbpages then -- this is to loop back to page 1 if we're using an iterator to swipe page
			if loop then 
				args.page = ((args.page or page)-1)%nbpages +1
			else 
				return false
			end
			return Page(T,args)
		end
		if nbres>0 then

			if show then Echo("------- page: "..page.."/"..nbpages..", ("..totalres.." results /"..length.." elements) --------")
				for i=1, nbres do
					Echo(results[i])
				end
				if page==nbpages then
					Echo("------ End ------")
				else 
					Echo("---- end "..page.."/"..nbpages.." ----")
				end			
			end
		end
		local clipcontent= clip and (tocode and tocode or keys and table.valtostr(keys) or obj and obj or objs and table.valtostr(objs) or concat)
		if clip then sp.SetClipboard(clipcontent) end


		if nbres>0 then	
			return tocode and "{"..tocode.."}" or keys or obj or objs or (report or clip) and concat
				   or page~=nbpages and "more"
				   or 'end'
		else return false
		end
	end
end




FindVar = function(search,Type,loc,noreply) -- research are made from the location of the calling function
	-- loc is where you want to search, leave it blank to search everywhere
	-- Type is what type you want to search, leave it blank to search any type
	-- no reply is to not make it verbose, as it could be misleading, if this function is called by another function
	local i=1
	if not loc or loc=="local" then
		while true do
			local name, value = debug.getlocal(2, i)
			if not name then break end
			if search==name and (t(value)==Type or not Type)  then
				return value,i,"local", not noreply and Echo("found "..t(value).." "..name.." as local#"..i.. ": ", value)
			end
			i = i + 1
		end
	end
	i=1
	if not loc or loc=="upvalue" then
		while true do
			local name, value = debug.getupvalue(debug.getinfo(2).func, i)
			if not name then break end
			if search==name and (t(value)==Type or not Type) then 
				return value,i,"upvalue", not noreply and Echo("found "..t(value).." "..name.." as upvalue#"..i.. ": ", value) 
			end
			i = i + 1
		end
	end
	i=1
	if not loc or loc=="env" then
		for name,value in pairs(getfenv(debug.getinfo(2).func)) do
			if not name then break end
			if search==name and (t(value)==Type or not Type)  then
				return value,i,"env", not noreply and Echo("found "..t(value).." "..name.." in its own environment #"..i.. ": ", value) 
			end
			i = i + 1
		end
	end
	return false, Echo("didn't find variable "..search)
end

function GetLocal(level,search)
	local getlocal = debug.getlocal
	local name,i,value = true,1
	while name do
		name, value = getlocal(level, i)
		if name==search then
			return value
		end
		i = i + 1
	end
end

GetLocalsOf= function(level,search)

	local T, Ti = {}, {}
	local i = 1
	while true do
		local name, value = debug.getlocal(level+1, i)
		if not name then break end
		if search then
			if search==value then return value,i end
		else
			T[name]=value
			Ti[name]=i
		end
		i = i + 1
	end
	return T,Ti
end


GetUpvaluesOf= function(func,search)
	local T = not search and {}
	local i = 1
	while true do
		local name, value = debug.getupvalue(func, i)
		if not name then break end
		if search and name==search then return value, i
		elseif T then T[name]=value end
		i = i + 1
	end
	return T
end
function listing(i)
	local max = i+1
	while debug.getinfo(i) and i<max do
		local func = debug.getinfo(i).func
		if func then
			Echo("--- FUNCTION: ",i)
			Page(debug.getinfo(i))
			Echo("--- LOCALS:",i)
			Page(GetLocalsOf(i))
			Echo("--- UPVALUES:",i)
			Page(GetUpvaluesOf(func))
		end
		i=i+1
	end
	return --GetLocalsOf(i)["(*temporary)"]
	--local upmpress = f.GetUpvaluesOf(debug.getinfo(4).func).func
	--return debug.getinfo(upmpress)

end

GetWidgetCode = function()
	-- local env = getfenv()
	local getinfo = debug.getinfo
    for i=1,13 do
        local info = getinfo(i)
        if info.name and info.name:match("LoadWidget") then
            local locals=GetLocalsOf(i)
            if locals.text and locals.widget and locals.filename then
                return locals.text
            end
		end
	end
end

GetWidgetInfos =function() 
	local getinfo = debug.getinfo
    local widget
    for i=1,13 do
        local info = getinfo(i)
        if info.name and info.name:match("LoadWidget") then
            local locals=GetLocalsOf(i)
            if locals.text and locals.widget and locals.filename then
                widget={
                    code=locals.text,               
                    handler=locals.self,
                    widget=locals.widget,
                    filename=locals.filename,
                    basename = locals.basename,
                    source=getinfo(i).source, -- actually it's a long src
                    [getinfo(i).source]=true,
                    name = locals.basename,
                    nicename = locals.widget.GetInfo and locals.widget:GetInfo().name or locals.basename -- if the chunk had error, we won't get the nice name
                }
                break
            end

        end
    end
	if not widget then
		Echo('ERROR, couldnt find the widget source')
		widget={name='unknown',code=''}
	end
	--- now registering funcs---
	-- adding current environment's function (utilfuncs)
	local utilfuncs={}	
	local source=debug.getinfo(1).source	
	if source~=widget.source then
		utilfuncs[source]=true
		for k,v in pairs(getfenv(1)) do -- get global functions in here
			if t(v)=="function" then
				defined=debug.getinfo(v).linedefined
				utilfuncs[k]=defined
				utilfuncs[defined]=k
			end
		end
	end
	widget.utilfuncs=utilfuncs


	-- adding callins and main function by scanning the code
	local callins,mainfuncs={},{}
	local linecount=0
	local code = UncommentCode(widget.code or '',false)

	
	-- Spring.SetClipboard(code)
	local word
	
	-- matching function to find a word or wordA.wordB.wordC... within a given pattern (pattern before, pattern with dot or not, pattern after, occurrences)



	local codelines={}
	local commented
	for line in code:gmatch('[^\n]+') do
		linecount=linecount+1
		--if linecount>32 and linecount<37 then
		-- line,commented = line:purgecomment(commented)
		--Echo(linecount..':'..line)
		--end

		codelines[linecount]=line
		word = line:match("function%s-widget:".."([%a]+)",1)
		if word then
			 callins[word]=linecount
			 callins[linecount]=word
		else
			local word = 
						 line:matchOptDot('function%s-','[%a_]+',':([%a_]+)%(',1) or  -- syntax function A:b(
						 line:matchOptDot('function%s-(','[%a_]+',')%s-%(',1) or
						 line:matchOptDot('(','[%a_]+',')%s-=%s-%(-%s-function',1) -- syntax a = function( or a = (function(   NOTE:the latter might not be a function everytime
			if word then
			 mainfuncs[word]=linecount
			 mainfuncs[linecount]=word
			end
		end
	end

	local comp_linecount = 0
	local commented_code = widget.code
	for line in commented_code:gmatch('[^\n]+') do
		comp_linecount = comp_linecount + 1
	end
	
	widget.codelines = codelines
	mainfuncs[widget.source]=widget.nicename
	widget.callins=callins
	widget.mainfuncs=mainfuncs

	return widget
end

function CheckIfValid(pos,line,sym,endPos) -- -- NOTE: CheckIfValid is used to Uncomment in a particular order, it doesn't ensure the validity of a sym in any circumstance
	local tries = 0
	local inString, str_end, quote = line:find("([\"']).-"..sym..".-%1")
	-- check if the found sym is not actually before this, or if the number of quotes are actually even
	if inString and ( pos<inString or select(2, line:sub(1,str_end):gsub(quote,''))%2==1 ) then
		inString=false
	end
	while inString do -- try a next one in the line, if any
		tries = tries + 1 if tries>1000 then Echo('TOO MANY TRIES 2') return end
		pos, endPos = line:find(sym, str_end+1)
		if not pos then
			return
		end
		inString, str_end, quote = line:find("([\"']).-"..sym..".-%1",str_end+1)
		if inString and ( pos<inString or select(2, line:sub(1,str_end):gsub(quote,''))%2==1 ) then
			inString=false
		end
	end
	return pos, endPos
end

function GetSym(sym,curPos,code,tries) -- NOTE: GetSym is used to Uncomment in a particular order, it doesn't ensure the validity of a sym in any circumstance
	local pos, endPos = code:find(sym, curPos)
	if not pos then
		return
	end
	local line,sol = code:line(pos)
	pos, endPos = CheckIfValid(pos - sol + 1, line, sym, endPos - sol + 1)-- convert to pos of the line
	if not pos then
		tries = (tries or 0) + 1 if tries>500 then Echo('TOO MANY TRIES 3') return end
		return GetSym(sym,sol+line:len(),code,tries)
	end
	return pos and pos + sol - 1, line, sol, endPos and endPos + sol - 1
end

function ReachEndOfFunction(pos,code) -- NOTE: ReachEndOfFunction is used to Uncomment in a particular order, it doesn't ensure it will find the function in any circumstance
	local l,r = '[%s%)}%]]','[%s%(%[{]'
	local openings = {l..'if'..r, l..'else'..r, l..'do'..r, l..'elseif'..r, l..'function'..r}
	local ending = l..'end'..r
	local _
	local o,c
	local nomore_o,nomore_c
	local check = function()
	end
	-- get any openings until we get an even number of 'end'
	local sum = 1 -- it is assumed that the 'function' starting pos has already been found and the given pos is at least one char ahead of this starting pos, so we start at sum = 1
	local tries = 0
	while sum>0 do
		tries = tries+1 if tries>500 then Echo('ERROR, TOO MANY FUNC TRIES') break end
		-- get the next end
		if not (c or nomore_c) then
			_,c = code:find(ending,pos+1)
			nomore_c = not c
		end
		-- get the next opening
		if not (o or nomore_o) then
			for _, opening in ipairs(openings) do
				local _,this_o = code:find(opening,pos+1)
				if this_o and (not o or this_o < o) then
					o = this_o
				end
			end
			nomore_o = not o
		end
		if c and (not o or c < o) then
			pos,c = c, false
			sum = sum - 1 
		elseif o then
			pos,o = o, false
			sum = sum + 1 
		else
			Echo('ERROR, FUNCTION NEVER ENDED')
			break
		end
	end
	return pos
end
-- NOTE: GetClosure doesn't ensure finding closure in any circonstances (block and comment preprocess is needed)
-- GetClosure can work with any string, even same strings, same strings will be considered closing or opening aiming at make it even
function GetClosure(code, opening,closing, startpos) -- actually string.match got a method with %b
	local pos, sum = startpos or 1, 0
	local start
	local tries = 0
	while pos do
		tries = tries+1
		if tries>100 then
			Echo('ERROR, too many tries')
			return
		end
		local open,_,_,end_open = GetSym(opening,pos,code)

		local close,_,_,end_close = GetSym(closing,pos,code)

		if not (start or open) then
			-- Echo('ERROR, no opening: '..opening..' found.')
			return
		elseif not start then
			start = open
		elseif not close then
			-- Echo('ERROR, no (more) closing "'..closing..'" found, closure never ended')
			return start
		end
		if open and close then
			-- case both opening and closing are found at same pos, either because they are the same or because they start the same
			if open==close then
				-- same pos, we select the one that make it even 
				if sum%2==1 then 
					open = nil
				else
					close = nil
				end
			elseif close<open then
				open = nil
			else
				close = nil
			end
		end
		sum = sum + (open and 1 or close and -1)
		if sum==0 then
			return start,end_close
		end
		pos = (open and end_open+1 or close and end_close+1)
	end
end

function RemoveEmptyLines(str)
    local charSym = '%S'
    local t, n = {}, 0
    for line in str:gmatch('[^\n]+') do
        local _,chars = line:gsub(charSym,'')
        if chars>0 then
            n = n + 1
            t[n] = line
        end
    end
    return table.concat(t,'\n')
end
function DeclareSpringLocals(modifFunc, avoidRedeclare) -- avoidRedeclare will correctly work only if declaration are only made in main widget scope
    local code = GetWidgetCode()
    if not code then
        return
    end
    -- code = code and UncommentCode(code,false)
    local sort = function(a,b)
        return a<b
    end
    local declaredInCode = {}
    local new, newDeclare
    local lines, l = {}, 0
    local nameChar = '[A-Z][%a%d_]'
    local notNameChar = '[^%a%d_]'

    local allTypes = {
        sps = {
            elements = {},
            prefix = 'Spring.',
            localPrefix = 'sp',
            isFunc = true,
        },
        gls = {
            elements = {},
            prefix = 'gl.',
            localPrefix = 'gl',
            isFunc = true,
        },
        GLs = {
            elements = {},
            prefix = 'GL.',
            localPrefix = 'GL_',
            isFunc = false,
        },
    }
    local typeOrder = {'sps','gls','GLs'}

    for line in code:gmatch('[^\n]+') do
        local newline = line
        for _, params in pairs(allTypes) do
            local isFunc = params.isFunc
            local prefix, localPrefix = params.prefix, params.localPrefix
            local patPrefix = prefix:gsub('%.','%%.')
            local parenthesis = isFunc and '(' or ''
            local patParenthesis = isFunc and '%s-%(' or ''
            local noParenthesis = '[^%(%a%d_]'
            local tbl = params.elements

            local isDeclared = {}

            for name in line:gmatch(notNameChar.."?"..patPrefix.."("..nameChar.."+)"..noParenthesis,1) do
                local localName = localPrefix..name
                if line:match("local%s+".. localName.."%s-=%s-"..patPrefix ..name) then
                    declaredInCode[localName] = true
                    isDeclared[localName] = true
                end
            end

            for name in line:gmatch(notNameChar.."?"..patPrefix.."("..nameChar.."+)"..patParenthesis,1) do
                local localName = localPrefix..name
                if not isDeclared[localName] then
                    -- Echo("localName, declared[localName] is ", localName, declared[localName])
                    if not tbl[localName] and not (avoidRedeclare and declaredInCode[localName]) then
                        local declareStr = 'local ' .. localName .. ' = '..prefix..name
                        tbl[localName] = declareStr
                        newDeclare = true
                    end
                    if modifFunc then
                        newline = newline:gsub("("..notNameChar.."?)("..prefix..nameChar.."+)"..patParenthesis, '%1'..localName..parenthesis)
                        new = true
                        -- Echo('newline is',newline)
                    end
                end
            end
            -- making declaration also for names looking already localized
            for name in line:gmatch(notNameChar.."?"..localPrefix.."("..nameChar.."+)"..patParenthesis,1) do
                local localName = localPrefix..name
                -- Echo(localName, tbl[localName],avoidRedeclare, declaredInCode[localName])
                if not tbl[localName] and not (avoidRedeclare and declaredInCode[localName]) then
                    tbl[localName] = 'local ' .. localName .. ' = '..prefix..name
                    newDeclare = true
                end
            end
            --
        end
        if modifFunc then
            l = l + 1
            lines[l] = newline
        end
    end
    local newcode
    if new or newDeclare then
        newcode = modifFunc and table.concat(lines,'\n') or code
        if newDeclare then
            newDeclare = false
            for _,typeTable in pairs(allTypes) do
                local count = 0
                local indexed = {}
                for localName, declareStr in  pairs(typeTable.elements) do
                    -- if not (avoidRedeclare and declaredInCode[localName]) then
                        count = count + 1
                        indexed[count] = declareStr
                    -- end
                    typeTable[localName] = nil
                end
                typeTable.indexed = indexed
                if count > 0 then
                    newDeclare = true
                    table.sort(indexed,sort)
                    typeTable.declarationString = table.concat(indexed,'\n')
                
                end

            end
        end
        if newDeclare then
            local declarationTable = {'------- Spring locals auto declared'}
            for i, typeName in ipairs(typeOrder) do
                local typeTable = allTypes[typeName]
                if typeTable.declarationString then
                    table.insert(declarationTable, typeTable.declarationString)
                    table.insert(declarationTable,'--------')
                end
            end
            table.remove(declarationTable)
            table.insert(declarationTable, '----------------------------')
            local pos = newcode:find('widget:GetInfo%(')
            if pos then
                pos = newcode:find('end',pos+1)
                pos = pos and pos + 3 or 0
            end
            local before = newcode:sub(0,pos or 0)
            local after = newcode:sub((pos or 0) + 1,-1)
            newcode = table.concat({
                    before,
                    table.concat(declarationTable,'\n'),
                    after,
                }, '\n'
            )
        end
    end
    Spring.SetClipboard(newcode or 'nothing to change')
    return newcode
end



function UncommentCode(code,removeComLine,clip)
    -- Echo('*********************************')
	-- code = RemoveEmptyLines(code) -- for debug only
	code = code:codeescape() -- code the escaped chars so we won't get fooled by them
	local t,n = {}, 0

	local commentSym ='%-%-'
	local blockSym = '%[%['
	local endBlockSym = '%]%]'
	local charSym = '%S'
	local tries = 0

	local curPos,newPos,_ = 0
	local comStart, line
    local sol, lastSol = 1, 1
	local block, _, blkSol = GetSym(blockSym,curPos,code)
    local cursol = 0

	-- we register the pos of the very next block symbol
	-- we register the pos of the very next comment symbol
	-- if the block is before the comment we verify the validity of the block by jumping to its line and checking if it's just chars in a string
	-- , or if there is another valid block in this line
    local count = 0
	while curPos do
		tries = tries +1 if tries>3000 then Echo('TOO MANY TRIES', tries) break end
		curPos = curPos+1
		if not comStart then
			comStart, line, sol = GetSym(commentSym,curPos,code) 
            -- if count < 8 then
            --     Echo(count, 'found comStart at',code:sub(comStart,comStart + 20))
            -- end
		end
		local part
        local falsify
        local mark
		if not comStart then
			-- no more comment, we pick the remaining code
			part = code:sub(curPos)
		elseif block and comStart>=block-2 then
			-- the very next block is before the very next comment or it is a block comment
			_,newPos = code:find(endBlockSym,block+2)
			if comStart==block-2 then
				-- this is a block comment, we keep what is behind
                
                local endPart = comStart-1
                local suffix = ''
                if code:sub(endPart,endPart):match(charSym) and code:sub(newPos+1,newPos+1):match(charSym) then
                    suffix = ' '
                    -- count = count + 1
                    -- Echo(count, code:sub(curPos-20,newPos+20))
                else
                    if removeComLine then
                        local _, chars = code:sub(sol,endPart):gsub(charSym,'')
                         if chars == 0 then
                            endPart = sol-2
                            -- suffix = '>>'..code:sub(sol-2,sol-1)..'<<'
                        end
                    end
                end


                if not removeComLine then
                    -- if the block has multiple line between start and end, we count them
                   _,nl = code:sub(block+2,newPos):gsub('\n','')
                    if nl>0 then 
                        -- nl = nl-1 
                        suffix = ('\n'):rep(nl)
                    end
                else
                    -- check behind the start of block if it is on a new line
                    local _, chars = code:sub(sol,comStart-1):gsub(charSym,'')
                    if chars == 0 then
                        endPart = sol-3
                        -- if endPart == curPos+1 then

                            -- count = count +1
                            -- Echo(count,code:sub(comStart-20,comStart+20))
                        -- end
                    end
                end
                if suffix == '' then
                    -- we add a space at the end in order to not stick the before and the after
                    if code:sub(endPart,endPart):match(charSym) and code:sub(newPos+1,newPos+1):match(charSym) then
                        suffix = ' '
                    end

                end

			    part = code:sub(curPos,endPart)..suffix

				comStart = false
			else
				-- block is valid and comment is after the start of block, this is a block string, we can safely pick everything until the end of the block
				part = code:sub(curPos,newPos)
				if not newPos or comStart<newPos then
					-- the comment symbol was inside the block, or the block never ended (latter shouldn't happen if the code is valid)
					comStart = false
				end
			end
            if not newPos then
                -- if no newPos, the block never ended
                block = false
            else
			    block,_,blkSol = GetSym(blockSym,newPos+1,code)
            end
		else
			-- this is simple line uncommenting
			-- look if no char is left on the (last) line to pick after uncommenting
			local _,chars = code:sub(sol,comStart-1):gsub(charSym,'')
			-- set it to sol-1 instead of sol-2 if you want to keep the empty newline after uncommenting
			-- set it to comStart-1 no matter what if you want to keep also the non characters (tabs or spaces usually)
			-- local endPart = chars==0 and sol-(removeComLine and 2 or 1) or comStart-1 
            local endPart
            if removeComLine and chars == 0 then
                mark = true
                endPart = sol-3
            else
                endPart = comStart-1
            end
                
            if curPos == comStart then
                -- the next comment is at the very start of the next line
                -- if not removeComLine then
                --     part = '\n'
                -- end

			elseif curPos<=endPart then
				part = code:sub(curPos,endPart)
            end
            newPos = code:find('\n',comStart)
            if newPos then
                newPos = newPos-1
            end
            if block and blkSol == sol then
                -- the very next block start into a commented line we cancel it and look for a new block
                block,_,blkSol = GetSym(blockSym,newPos+1,code)

            end
			
            -- if count and math.round(count*100) >= 2112 then
            --     Echo(tostring(justAfter),'newPos set >>',code:sub(newPos,newPos + 20))
            --     Echo('gone after the comment',code:sub(comStart,comStart + 20))
            --     Echo('current block ?',block and code:sub(block,block + 20))
            --     -- Echo('comStart?',comStart,'block ?',block,'endPart?',endPart)
            --     -- Echo('comStart text '..code:sub(comStart,comStart + 20))
            -- end
            falsify = true
		end
        if falsify then
            comStart = false
            if part then
                -- if mark then
                --     part =  '>>*' .. part .. '*<<'
                -- else
                --     part = '>>' .. part .. '<<'
                -- end
            end
        end
		if part then
			n = n + 1
            if falsify then
			 t[n], part = part:decodeescape()--[[..'>>'..n..'<<'--]], false
            else
                t[n], part = part:decodeescape()--[[..'<<'..n..'>>'--]], false
            end
		end
		curPos, newPos = newPos, false
	end
    local ret = table.concat(t)
    if clip then
        Spring.SetClipboard(ret)
    end
	return ret
end

function GetTableOrderFromCode(code,nameVar,occurrence,uncommented,thetable,noMissing)
	-- return array of keys of a table as it appear in the code
	-- occurrence, to select which table to pick as it appear reading the code, by default pick the last
	-- NOTE: case with auto exec function are not (yet?) covered eg: local t = (function() return {} end)()
	-- case with keys defined by variable or string is not covered either, I wouldn't see how it is possible to get the correct values used
	-- therefore, keys must be written litterally or, if the table is given as argument or is accessible by checkings globals and locals, the missings keys will be added at the end
	local t,gotAlready = {}, {}
	if type(nameVar)~='string' then
		Echo('ERROR, ',nameVar, 'is not a string')
		return t
	end
	-- we have to uncomment all the code in case of block comment so we don't fall on a fake table
	if not uncommented then
		code = UncommentCode(code,true)
	end
	-- code the escaped symbol so we don't get fooled
	code = code:codeescape()
	-- we have to remove every string blocks so we don't fall again in a fake table
	code = code:gsub("%[%[.-%]%]","")
	
	local tries = 0
	local pos,_ = 1
	local tcode
	local current = 0
	while tries<(occurrence or 20) do
		_,_,_,pos = GetSym(nameVar..'%s-=%s-{',pos,code)
		tries = tries+1
		if not pos then
			if occurrence then
				Echo('ERROR, no valid initialization of '..nameVar..' found at desired occurrence. Ended at occurrence '..current)
			end
			break
		end
		current=current+1
		if not occurrence or current==occurrence then
			local str_start, str_end = GetClosure(code, '{','}', pos)

			tcode = str_end and code:sub(str_start,str_end)
			if occurrence then
				break
			end
		end
		pos = pos + 1
	end
	if not tcode then
		Echo('ERROR, no valid table of '..nameVar..' has been found.')
		return t
	end

	-- this way works but not with key wrote with variable and string
	-- remove any string so we don't get fooled by non-code
	-- Spring.SetClipboard(tcode)
	tcode = tcode:gsub("([\"\']).-%1","")
	-- remove any double equal
	tcode = tcode:gsub("==","")
	-- remove any subtable so we get only our first level keys with an equal sign
	tcode = '{'..tcode:sub(2):gsub("%b{}","")
	-- remove functions
	local funcpos = tcode:find('function')
	while funcpos do
		local endPos = ReachEndOfFunction(funcpos+1,tcode)
		if funcpos==endPos then Echo('ERROR, never found anything after "function" ') break end
		tcode = tcode:sub(1,funcpos-1)..tcode:sub(endPos+1)
		funcpos = tcode:find('function')
	end
	--
	tcode:decodeescape()
	-- now we can get our keys
	for k in tcode:gmatch('[{,]%s-([%w_]+)%s-%=') do
		if not gotAlready[k] then
			table.insert(t,k)
			gotAlready[k] = true
		end
	end

	-- if the table has already been initialized at this point and is accessible from here, the verif can occur
	local obj = thetable or (function() for i=3,8 do local obj = GetLocal(i,nameVar) if obj then return obj end end end)() or widget[nameVar]

	if obj then
		local k=1
		while  t[k] do
			if obj[t[k]]==nil then 
				-- Echo('BAD KEY: '..t[k])
				table.remove(t,k)
			else
				k=k+1
			end
		end
		for k in pairs(obj) do
			if not gotAlready[k] then
				if noMissing then
					table.insert(t,k) -- putting the missing keys at the end
				end
				-- Echo(k..' IS MISSING')
			end
		end
	end
	return t
end

activateDW = function(toggle) return wid.handler:UpdateWidgetCallIn("DrawWorld", wid.widget) end
removeDW = function() return wid.handler:RemoveWidgetCallIn("DrawWorld", wid.widget) end


local spGetTimer, spDiffTimers = Spring.GetTimer, Spring.DiffTimers
local done = false
function tracefunc(oriFunc,Log,warn) -- wrap function to add properly traced back error message
	------ function info
	local info = debug.getinfo(oriFunc)
	local definedline = info.linedefined
	local funcsource = info.source	
	local name = wid.utilfuncs[funcsource] and wid.utilfuncs[definedline] or
				 wid.mainfuncs[funcsource] and ( wid.mainfuncs[definedline] or wid.callins[definedline] )

	local funcfilename=funcsource:gsub('LuaUI[\\/]Widgets[\\/](.-)%.lua','%1')
	--Echo('tracing func',name,funcfilename)
	--
    local makeReportfunc_line = false

    local debugfunc_line = false
    local runfunc_line = false

    local makeReport = function(STR, isError)
        local report=""
        if not makeReportfunc_line then
            makeReportfunc_line=debug.getinfo(1).linedefined
        end
        if isError then
            if not debugfunc_line then
                debugfunc_line=debug.getinfo(2).linedefined
                runfunc_line = debug.getinfo(3).linedefined
            end
        elseif not runfunc_line then
            runfunc_line = debug.getinfo(2).linedefined
        end
        if not STR then 
            Echo('ERROR',funcsource,name,definedline)
            local report = debug.traceback()
            return report, Log and Log(report)
        end
        STR = "["..STR..'\n'--..traceback
        --Echo("\nError in widget "..wid.nicename)
        .."\n"..GreyStr
        for line in linesbreak(STR) do 
            if  not line:find(debugfunc_line or 0)
            and not line:find(runfunc_line)
            and not line:find(makeReportfunc_line)
            and not line:find'C\]: in function.-pcall\''
            and not line:find'%(tail call%):?'
            and not line:find'stack traceback'
            and not line:find'cawidgets.lua'
            and not line:find'camain.lua'
            and not line:find'chili_old/'
               then
                local widname = line:match('string "LuaUI[\\/]Widgets[\\/](.-)%.lua"')
                local current_line = tonumber(line:match':(%d*):')
                local defined_line = tonumber(line:match':(%d*)>')
                local callin_name = wid.callins[defined_line]
                local func_name = wid.mainfuncs[defined_line] or wid.utilfuncs[defined_line]
                local inThis = func_name   and ": in function '"..func_name.."'"
                            or callin_name and ": in CallIn '"..callin_name.."'"
                if inThis then
                    report=report.."["..(widname or 'unknown widget').."]:"..current_line..inThis.."\n"..GreyStr
                else
                    line = line:gsub('string "LuaUI[\\/]Widgets[\\/](.-)%.lua"','%1') -- remove useless path
                    line = line:sub(2)
                    report=report..line.."\n"..GreyStr
                end

            end
            if not name and line:find'cawidgets.lua' then
                local foundname = line:match('in function \'(.-)\'')
                if foundname then
                    name = foundname
                end
            end

        end
        report = (name or 'unknown')..' in widget '..(wid.nicename or wid.name or 'no widget name found')
            .. report
            .. "\n---"

        return report 
    end

	local debugging=function(res)
        if not res[2] then 
            Echo('ERROR',funcsource,name,definedline)
            local report = debug.traceback()
            return error(report), Log and Log(report)
        end
		local report=makeReport(res[2], true)
		return error(Echo('\nError in ' .. report)) 
	end
	local runFunc=function(thisfunc,...)
		local args={...}
        local function anonfunc()
            return thisfunc(unpack(args))
        end
        local time = warn and spGetTimer()
		local res = {
                xpcall(
                    anonfunc            
                    , debug.traceback
            )
        }

		local succeed = res[1]
		if not wid then Echo("Widget stopped") return end
		if succeed then
            
            if time then
                time = spDiffTimers(spGetTimer(), time)
                if time>0.002 then
                    local report = makeReport(debug.traceback())
                    Echo('\nFunction took longer than 0.2 sec: \n' .. report)
                    if Log then
                        Log(report)
                    end
                end
            end
            return select(2,unpack(res))
        else
            debugging(res)
        end
		--
	end
    local function anonfunc2(...) -- 
        return runFunc(oriFunc,...)
    end

	return anonfunc2
end




function DebugWidget(widget,Log,warn)
	for k,v in pairs(widget) do 
		if t(v)=='function' and wid.callins[k] then widget[k] = tracefunc(v,Log, warn) end
	end
end




-- debugging variables in a window

DebugWinVars = {instances = {}}
function DebugWinVars:New(widget,...)
	if not WG.Chili then
		Echo('[DebugWinVars]:[ERROR]:Chili is not available')
		return false
	end
    local name = GetWidgetName(widget)
    local _obj = self.instances[name]
    if _obj then
        if self.instances[_obj] == widget then
            -- the obj already exist and it belong to the same widget
            return _obj
        end
        -- the existing obj is from another instance of widget of the same name
        _obj:Delete()
    end
	local obj = setmetatable({proxies={}},{__index = self})
    self.instances[obj] = widget
    self.instances[name] = obj
    local Label = WG.Chili.Label
    local Checkbox = WG.Chili.Checkbox
    local debugLabels = {}
    local columns ={}
    obj.columns = columns
    local values = {}
    local colnames = {}
    local currentCol = 0
    for i,v in ipairs({...}) do

    	local name = (type(v) == 'boolean') and ' ' or (type(v)=='string') and v
    	if name then
    		table.insert(colnames,v)
    		currentCol = currentCol + 1

    	elseif type(v)=='table' then
    		if currentCol == 0 then
    			currentCol = 1
    			colnames[1] = ''
    		end
    		values[currentCol] = values[currentCol] or {}
    		table.insert(values[currentCol],v)
    	else
    		Echo('[' .. widget:GetInfo().name .. ']:[DebugWinInit2]:[ERROR]:bad arument type #' .. i,v,type(v) )
    		return
    	end
    end

    
    local win,grid = obj:CreateWin(widget)
    local white,grey = Colors.white, Colors.grey
    local DebugUp = function(k,v,icol)
        if not (grid and grid.visible) then
        	return
        end
        icol = icol or 1
        local column = columns[icol]
        local key = k

        local label = column.labels[key]
        if label==nil then
            -- debugLabels[k] = Label:New{x=14,height=14,y=#column.children*7}
			column.labels[key] = Checkbox:New{
					height=14,
					-- y=#column.children*14,
					-- left = 1,
					caption = '',
					-- noFont = true,
					textalign = "right",
					boxAlign = 'left',
					checked = true,
					-- align ='center',
					OnChange = {
						function(self)
							self.parent:RemoveChild(self)
                            column.labels[key] = false
							-- self.font:SetColor(self.checked and grey or white)
							-- self:Invalidate()
						end,
					},
			}
            -- column:AddChild(checkbox)
            label = column.labels[key]
            column:AddChild(label)
        end
        if label==false then
            return
        end

       	v = tostring(v):gsub('\n',' -- ')
        local newStr = tostring(k)..' = '..tostring(v)
        if label.caption ~= newStr then
       	    label.caption = newStr
       	    label:Invalidate()
        end
		--label:SetCaption(k..' = '..tostring(v))
    end
    obj.DebugUp = DebugUp

    for numCol,name in ipairs(colnames) do
    	obj:AddColumn(name)
    	for i,vals in ipairs(values[numCol]) do
    		obj:AttachTable(numCol,vals,DebugUp)
    	end
	end
   --  local oriShutdown = widget.Shutdown
  	-- widget.Shutdown = function()
  	-- 	win:Dispose()
  	-- 	return oriShutdown and oriShutdown(widget)
  	-- end
    return obj
end
function DebugWinVars:Delete(nodispose)
	-- Echo("self.win,self.win.disposed is ", self.win,self.win and self.win.disposed)
	-- if not nodispose and self.win and not self.win.disposed then
		-- self.win:Dispose()

		-- self.win = nil
		-- Echo("disposed is ",self.win.disposed)
	if self.instances[self] then
        local name = self.instances[self]
		self:UnsetProxies()
		if not nodispose and self.win then
			self.win:Dispose()
		end
		for k,v in pairs(self) do
			self[k] = nil
		end
		self.instances[self] = nil
        self.instances[name] = nil
	end


end
function DebugWinVars:CreateWin(widget)
    local name = (widget.whInfo.name or widget.whInfo.basename) .. ' Debugger'
    local win, grid
    local ESCAPE = KEYSYMS.ESCAPE
    local selfObj = self
    win = {
        parent = WG.Chili.Screen0
        ,y=35
        ,dockable = false -- NOTE: dockable beeing true  and if the control has fixed name, the window pos and size are recovered after unloading/reloading widget (use dockableSavePositionOnly=true to not really dock but only save position)
        ,width = 200
        ,height = 300
        ,caption = ''
        ,minWidth = 100
        ,minHeight = 28
        ,resizable = true
        ,children = {grid}
        ,padding = {3,25,3,0}
        ,name = name
        ,caption = name

        -- user defined
        ,normalWidth = 600
        ,normalHeight = 500
        ,userClick = false
        ,userResize = false
        ,moveThreshold = false
        --
        ,OnKeyPress = {
        	function(self,key)
        		if self.height~=28 and key==ESCAPE
        			then self:Hide()
        			return true
        		end
        	end
        }
        ,OnDispose = {
        	function(self)
        		selfObj:Delete(true)
        		selfObj = nil
        	end
        }
    }

    WG.Chili.Window:New(win)


    grid = WG.Chili.Grid:New{
    	parent = win
        ,columns = 0
        ,width = '100%'
        ,height='100%'
        ,padding = {1,1,1,1}
        ,itemPadding = {1,1,1,1}
        ,itemMargin = {1,1,1,1}
    }
    if WG.MakeMinizable then
    	WG.MakeMinizable(win)
    end
    self.win,self.grid = win, grid
    return win, grid

end
function DebugWinVars:AddColumn(name)
	local grid, columns = self.grid, self.columns
	local numCol = grid.columns+1
    grid.columns = numCol
    local children = {}
    if name then
    	children[1] = WG.Chili.Label:New{
        		caption=name
        		,align = 'center'
        		,width = '100%'
        		,height=14
        		,autosize = false
        		,textColor = Colors.yellow
        }
    end
	columns[numCol] =  WG.Chili.StackPanel:New{ -- it can be StackPanel or Window
        children = children
		-- ,resizable = false -- param for Window
		-- ,draggable = false -- param for Window
		,centerItems = false -- param for StackPanel
		,resizeItems = false -- param for StackPanel
		,itemPadding = {0,0,0,0}
		,itemMargin = {0,3,0,0}

        -- user specific
        ,labels={}
    }
    grid:AddChild(columns[numCol])

end
function DebugWinVars:SetNotifyProxy(t,cb_index,cb_newindex) -- transfert pairs of t into a new table and make t a proxy
    local _t = {}
    for k,v in pairs(t) do
        t[k] = nil
        _t[k] = v
    end
    t._real = _t
    mt = {
         __index = cb_index and function(t,k) cb_index(t,k) return _t[k]  end or _t
        ,__newindex= cb_newindex and function(t,k,v) cb_newindex(t,k,v) _t[k] = v  end or _t
    }

    setmetatable(t,mt)
    self.proxies[t] = _t
    return _t
end
function DebugWinVars:UnsetProxy(proxy,backup) -- unset proxy and give back the values
	backup = backup or self.proxies[proxy]
	setmetatable(proxy,nil)
	for k,v in pairs(backup) do
		proxy[k] = v
	end
    proxy._real = nil
	self.proxies[proxy] = nil
end
function DebugWinVars:UnsetProxies()
	for proxy, backup in pairs(self.proxies) do
		self:UnsetProxy(proxy,backup)
	end
end
function DebugWinVars:AttachTable(numCol,t)
	local DebugUp = self.DebugUp
	if not self.columns[numCol] then
		self:AddColumn()
		numCol = self.grid.columns
	end

	for k,v in pairs(t) do
		DebugUp(k,v,numCol)
	end
	self:SetNotifyProxy(t,false,function(t,k,v) DebugUp(k,v,numCol) end)
end



function DebugWinInit2(widget,...) -- added the possibility of directly hook tables of values to avoid using DebugUp in the code
	return DebugWinVars:New(widget,...)
end



---- OLD

function DebugWinInit(widget,...)
    local Chili = WG.Chili
    local ESCAPE = KEYSYMS.ESCAPE
    local debugLabels = {}
    local columns = {}
    local colnames = {...}
    if not colnames[1] then colnames[1] = ' ' end
    local debugWin
    local Window = Chili.Window
    local grid
    -- for k,v in pairs(Chili.Screen0.children_hidden) do
    	-- Echo(k,v,type(k),"k and k.name is ", v and v.height)
    	-- Echo(k,v,(type(v)=='userdata' or type(v)=='table') and v.name,(type(v)=='userdata' or type(v)=='table') and v.height)
    -- end
    debugWin = Window:New{
        parent = Chili.Screen0
        ,y=35
        ,dockable = true -- NOTE: dockable beeing true  and if the control has fixed name, the window pos and size are recovered after unloading/reloading widget (use dockableSavePositionOnly=true to not really dock but only save position)
        ,width = 100
        ,height = 28
        ,caption = ''
        ,minWidth = 100
        ,minHeight = 28
        ,resizable = true
        ,children = {grid}
        ,padding = {3,25,3,0}
        -- user defined
        ,normalWidth = 600
        ,normalHeight = 500
        ,userClick = false
        ,userResize = false
        ,moveThreshold = false
        --
        ,OnParentPost={ -- OnParentPost is not really what it is, parent don't have children at this point, therefore self:Hide() doesn't work
            function(self)
                local name = widget.GetInfo and widget:GetInfo().name or self.name
                self.name = 'Debug Window ' .. name
	            self.caption = self.name
	            local tmpFont = Chili.Font:New(self.font) -- font has not been made at this point (it should, no?), so we make one temporarily to get the size
	            self.minWidth = self.padding[1] + tmpFont:GetTextWidth(self.caption) + self.padding[3]
	            tmpFont:Dispose()
	            -- self.width = self.minWidth
	            -- self.height = self.minHeight
	            -- self.resizable = false
	            -- Echo("self.children_hidden is ", next(self.children_hidden))
            end
        }
        ,Resize = function(self,w,h,x,y) -- this save the normal size of window 
        	if h==self.minHeight and w==self.minWidth then
        		self.resizable = false
        		grid:Hide()
        	else
        		self.normalWidth = w
        		self.normalHeight = h
        		self.resizable = true
        		grid:Show()
        	end
        	return Window.Resize(self,w,h,x,y)
       	end
       	,OnResize = { -- this trigger the save
       		function(self,w,h,x,y)
       			if not self.children[1] then return end -- the OnResize can be triggered when setting minWidth in ParentPost, problem is there is no child of debugWin at this point even though grid got it as parent (need to fix chili)
       			if self.height == self.minHeight
       			and self.width == self.minWidth
       			then
       				if self.userResize then -- stop the resizing by mouse when mini size is reached
						self:MouseUp(0,0,1)
					else
       					self:Resize(self.width,self.height)
       				end
       				
       				return true
       			end
       			if self.userClick then
       				self.userResize = true
       			end
       			-- Echo("self.children[1],w,h,x,y is ", self.children[1],w,h,x,y)
       		end
       	}
        ,MouseDown = function(self,x,y,button,...) -- MouseDown give the real x and y of the window, while OnMouseDown doesn't get triggered on the border, and x and y are offset by the borders
	       	if y<25 and button==1 then
        		self.moveThreshold = 3
        	end
        	self.userClick = true
    		return Window.MouseDown(self,x,y,button,...)
        end
        ,MouseMove = function(self,...)
        	local threshold = self.moveThreshold
        	self.moveThreshold = threshold and threshold>0 and threshold-1
        	return Window.MouseMove(self,...)
        end
        ,MouseUp = function(self,...) -- this switch mini/normal size and also trigger the save
        	if self.moveThreshold then
        		if self.height == self.minHeight and self.width == self.minWidth then
	            	self:Resize(self.normalWidth,self.normalHeight)
	        	else
	        		self:Resize(self.minWidth,self.minHeight)
	        	end
	        elseif self.userResize then
	        	self:Resize(self.width,self.height)
	        	self.userResize = false
        	end
        	self.userClick = false

        	return Window.MouseUp(self,...)
        end
        ,OnKeyPress = {
        	function(self,key)
        		if self.height~=28 and key==ESCAPE
        			then self:Hide()
        			return true
        		end
        	end
        }
    }
    grid = WG.Chili.Grid:New{
    	parent = debugWin
        ,columns = #colnames
        ,width = '100%'
        ,height='100%'
        ,padding = {1,1,1,1}
        ,itemPadding = {1,1,1,1}
        ,itemMargin = {1,1,1,1}
    }

    for i,name in ipairs(colnames or {''}) do
    	columns[i] =  WG.Chili.Window:New{ -- it can be StackPanel or Window
	        children = {
	        	name~='' and WG.Chili.Label:New{
	        		caption=name
	        		,align = 'center'
	        		,width = '100%'
	        		,height=14
	        		,autosize = false
	        		,textColor = Colors.yellow
	        	}
	        	or nil}
  			,resizable = false -- param for Window
  			,draggable = false -- param for Window
  			-- ,centerItems = false -- param for StackPanel
  			-- ,resizeItems = false -- param for StackPanel
	    }
	    grid:AddChild(columns[i])
	end
    local DebugUp = function(k,v,col)
        if not (grid and grid.visible) then return end
        local column = columns[col or 1]
        if not debugLabels[k] then
            debugLabels[k] = Chili.Label:New{height=14,y=#column.children*14}
            column:AddChild(debugLabels[k])
        end
		debugLabels[k]:SetCaption(k..' = '..tostring(v))
        
    end
    return DebugUp
end
------------------------------------------------
--------------------------------
memoize = function(func)
	local concat=table.concat
	local args
	local results = setmetatable({},{     
		__mode = "v",
		__index=function(res,k) res[k]={func(unpack(args))} return unpack(res[k]) end
	})
	return function(...)
		args={...}
		return results[concat(args)]
	end
end

timer = function(time, action, isRepeat, condition,defaultaction, delta)

-- this timer can be used to do a delayed action (can repeat infinitely or on defined timercount)
-- it can also be used to trigger an action on condition (within a certain time or not)
-- or checking time before the condition is met (and optionally trigger also a default action)(can also be repetitive),
-- action can be optional in all circumstance
-- it can recheck with delay after a success if delta is set
-- action and defaultaction can be functions passed as arguments without "()"
  local start = 0
  local timercount = 0
  local timerEnabled = true
  local totalTime = 0
  local success = false
	local work = function()
	  if not timerEnabled then
	   return
	  elseif timerEnabled and start == 0 then
	   start = sp.GetTimer()
	  elseif timerEnabled and t(start) == "userdata" then
		local diffTime = sp.DiffTimers(sp.GetTimer(), start)
		local delay= success and delta or 0

		if t(isRepeat)=="number" and timercount<isRepeat or isRepeat==true or timercount == 0 then
		  if condition~= nil and condition==true and diffTime>delay then --
			  timercount = timercount+1
			  action = action and action()
			  start = delta and 0

			  Echo("condition reached at "..diffTime-delay.."")
			  totalTime = totalTime+diffTime
			  success = true
			  return true, totalTime
		  elseif condition~=nil and condition==false and time and diffTime-delay > time then
			  timercount = timercount+1
			  defaultaction = defaultaction and defaultaction()
			  start = 0
			  totalTime = totalTime+diffTime
			  Echo("Time Elapsed", isRepeat==true and "retrying" or timercount<isRepeat and "retries left: "..(isRepeat-timercount) or "end")
			  success = false
			  return false, delta
		  elseif condition==nil and time and diffTime > time then -- 
			  timercount = timercount+1
			  Echo(timercount)
			  action = action and action()
			  start = 0
		  end
		end
	  end
	end
end


-------------------------------------------- OPTIONS ------------------------------------------


do
    local code={meta=4,internal=8,right=16,shift=32,ctrl=64,alt=128}
    local spGetModKeyState = Spring.GetModKeyState
    local spGetMouseState = Spring.GetMouseState
    local signedIn,widgetSignature, maxSignatureCode = {},{},0
    local round = math.round
    -- sadly can't work
	    function GetWidgetSignature(name)
	    	local signCode
	    	if not signedIn[name] then
	    		maxSignatureCode = maxSignatureCode+1
	    		signCode = maxSignatureCode
	    		signedIn[name] = signCode
	    		signedIn[signCode] = name
	    	else
	    		signCode = signedIn[name]
	    	end
	    	return round(signCode/10000,4)
	    	-- number%(2*bit) >= bit
	    end
	    function GetOrderOwner(coded)
	    	return signedIn[round(coded-coded%1,4)*10000]
	    end
    --
    function MakeOptions(internal, forceShift)
        local opts = {}
        opts.alt, opts.ctrl, opts.meta, opts.shift = spGetModKeyState()
        opts.shift = opts.shift or forceShift
        opts.right = select(5,spGetMouseState())
        opts.internal = internal
        local coded = 0
        for opt, isTrue in pairs(opts) do
            if isTrue then
            	coded=coded+code[opt]
            end
        end
        opts.coded=coded
        return opts
    end
	function CodeOptions(options)
		local coded = 0
		for opt, isTrue in pairs(options) do
			if isTrue then coded=coded+code[opt] end
		end
		options.coded=coded
		return options
	end
	function Decode(coded)
		local options={coded=coded,meta=false,internal=false,right=false,ctrl=false,alt=false}
		if coded==0 then return options end
		for opt,num in pairs(code) do
			options[opt]=coded%(num*2)>=num
		end
		return options
	end
    function ReadOpts(opts)
        if tonumber(opts) then
            return 'coded: ' .. opts
        end
        local str = ''
        for k,v in pairs(opts) do
            if v then
                str = str .. k .. ': '.. tostring(v) .. ', '
            end
        end
        return str:sub(1,-3)
    end
end



-------------------------------------------- UNITS ------------------------------------------


function GetUnitsInOrientedRectangle(p1,p2,width)
	local spGetUnitPosition = sp.GetUnitPosition
	if p1[1]>p2[1] then p1,p2 = p2,p1 end -- get p1 as the left point to get the good minmax later
	local x1,y1,z1 = unpack(p1)
	if not z1 then z1 = y1 end -- make it compatible with 2d and 3d pos
	local x2,y2,z2 = unpack(p2)
	if not z2 then z2=y2 end
	local relx,relz = x2-x1,z2-z1
	local hyp = (relx^2+relz^2)^0.5
	local dx,dz = relx/hyp,relz/hyp -- direction to second point
	local offx, offz = -dz*width,dx*width-- offset to direction 90° left
	local c1x, c1z, c2x, c2z = x1-offx, z1-offz, x2+offx, z2+offz -- most left corner and its opposite
	local units
	if dz<0 then -- finding the min maxes of the inscribing rectangle of our oriented rectangle, so we scan only the relevant units
		units = sp.GetUnitsInRectangle(c1x,z2-offz,c2x,z1+offz)
	else
		units = sp.GetUnitsInRectangle(x1+offx,c1z,x2-offx,c2z)
	end
	local ret,n = {},0
	for i=1,#units do
		local id =units[i]
		local x,y,z = spGetUnitPosition(id)
		local rx1, rz1, rx2, rz2 = c1x-x, c1z-z, c2x-x,c2z-z -- unit pos relative to corners
		if  rx1*dz>rz1*dx  -- above bottom
		and rx2*dz<rz2*dx  -- under top
		and rx1*dx<rz1*-dz -- at right of left side (comparison with directions 90° left)
		and rx2*dx>rz2*-dz -- at left of right side
		then
			n=n+1
			ret[n]=id
		end
	end
	return ret,n
end



table.compare = function(t1,t2)
	local eq,t1count,t2count = false,0,0
	for k,v in pairs(t1) do
		t1count=t1count+1
		if type(v)=='table' and type(t2[k])=='table' then
			eq = table.compare(v,t2[k])
		else 
			-- Echo("v,t2[k] is ", v,t2[k])
			eq = v==t2[k]
		end
		if not eq then return false end
	end
	for _ in pairs(t2) do
		t2count=t2count+1
	end
	return t1count==t2count
end

table.compareK = function(t1,t2)
	local eq,t1count,t2count = false,0,0
	for k,v in pairs(t1) do
		t1count=t1count+1
		if type(v)=='table' and type(t2[k])=='table' then
			eq = table.compareK(v,t2[k])
		else
			-- Echo("v,t2[k] is ", v,t2[k])
			eq = t2[k]~=nil
		end
		if not eq then return false end
	end
	for _ in pairs(t2) do
		t2count=t2count+1
	end
	-- return false

	return t1count==t2count
end

MultiInsert = function(lot,conTable,keepExisting,includeConPos,conRef)

	-- to find correct insert position, we can't rely on current command queue because we gonna insert multiple placement, thus command queue will change in the future, not yet, so we simulate this change
	--function will return a table that give insert position for each coords received
	--cons[ID].insPos{num,num,num,...} parallel to the coord table we receive

	--Step1. register existing coords order in a cons[conID][commandPos]={coords} Table


	-- defining table of cons
							--[id]
								--.current commands = table
								--.commands {[posCommand] = coords}
	-- keepExisting = false
	local sameCommands,baseCommands,firstID
	local cons = conTable.cons

	for id,con in pairs(cons) do
        con.insPoses = {}
		-- if not firstID then
		-- 	firstID=id
		-- 	baseCommands = cons[firstID].commands
		-- else
		-- 	sameCommands = table.compare(baseCommands,con.commands)
		-- end
	end
    local PID = select(2,sp.GetActiveCommand())
    local facing = sp.GetBuildFacing()
	for id,con in pairs(cons) do

		-- if id~=firstID and sameCommands then
		-- 	con.insPoses = cons[firstID].insPoses
		-- 	con.commands = cons[firstID].commands
		-- else
			local commands = con.commands
			local insPoses = con.insPoses
			local lastx,lastz,lastins
			for i=1,#lot do
				local coords=lot[i]
				local newx,newz = coords[1], (coords[3] or coords[2])
				local ins
				local t = {newx,newz, cmd = coords.mex and mexDefID or PID, facing = coords.mex and 0 or facing}
                -- Echo('add in multiinsert',newx,newz, coords.mex and mexDefID or PID,coords.mex and 0 or facing)
				if lastx and lastx==newx and lastz==newz then 
					ins = lastins
				else
					ins = GetInsertPosOrder(id,newx,newz,commands,includeConPos,conRef)
				end
				insPoses[i]=ins
				table.insert(commands,ins+1,t)
				lastx,lastz,lastins=newx,newz,ins
			end
		-- end
	end
    -- local str = ''
    -- for id, con in pairs(cons) do
    --     str = str .. '[' .. id .. ']:' .. #con.commands .. ', '
    -- end
    -- Echo(str .. (not conTable.inserted_time and 'from queue' or os.clock() - conTable.inserted_time))
    conTable.multiInsert = true
	conTable.inserted_time = os.clock()


	return conTable
end

GetInsertPosOrder = function (unitID, X, Z, lot, includeCon,conRef) -- modified to fit searching in custom table
	if includeCon==nil then
		includeCon = true
	end
--Echo("---- Ins process ----")
--	Echo("------------- Lot Ins -------------")

	local unitPosX,_,unitPosZ = sp.GetUnitPosition(conRef or unitID)
	local unitPos = {unitPosX,unitPosZ}
	local new = {X,Z}
	local minDist = GetDist(new,  unitPos)
	local n
	if not lot then
		lot, n  = {}, 0
		for i,order in ipairs(sp.GetCommandQueue(id,-1)) do
			local posx,_,posz = GetCommandPos(order)
			-- Echo("posx,posz is ", posx,posz)
			n = n + 1 
			lot[n] = not posx and EMPTY_TABLE or {posx,posz}
		end
	else
		n = #lot
	end

	if n==0  then
		return 0, minDist
	end
	local sqrt = sqrt
	local pos = {n=0}

	local j = 0
	-- register the commands that have position in a separate table indicating their position in the queue
	for i=1, n do 
		local thislot = lot[i]
		if thislot[1] then
			j=j+1
			pos[j],pos.n = { thislot[1],thislot[2], orderPos=i }, j
		end
	end

	if not pos[j] then
		return 0, minDist
	end

	local I=0
	local start = 1
	if includeCon then
		pos[0]={unitPosX,unitPosZ,orderPos=0}
		start = 0
	end
	local bestDist=huge
	-- Echo("--")
	--  NOTE, sqrt is mandatory 
	for i=start,pos.n do -- getting insert point that add the least distance
		local this,next = pos[i],pos[i+1]
		local new_next -- we don't need to recalculate 'this_new' as it is the previous 'new_next'
		if not next or this[1]~=next[1] or this[2]~=next[2] then -- to gain some cpu we don't consider order that have same poses than its next (happening mostly when terraforming)
			-- Echo(i,this[1],next and next[1] or 0,this[2])
			local this_new = new_next or sqrt((this[1]-X)^2+(this[2]-Z)^2)
			new_next = next and sqrt((next[1]-X)^2+(next[2]-Z)^2) or 0
			local this_next = next and sqrt((next[1]-this[1])^2+(next[2]-this[2])^2) or 0
    		local newDist = (this_new+new_next)-this_next
			if newDist <= bestDist then 
				bestDist = newDist
				I = this.orderPos
			end
		end
	end
	-- Echo('best dist is ',bestDist)
	return I,bestDist

end

GetInsertPosOrder2 = function (unitID, X, Z, lot) -- bader
--Echo("---- Ins process ----")
--	Echo("------------- Lot Ins -------------")

	local unitPosX,_,unitPosZ = sp.GetUnitPosition(unitID)
	local unitPos = {unitPosX,unitPosZ}
	local new = {X,Z}
	local minDist = GetDist(new,  unitPos)
	local cQueue = lot or sp.GetCommandQueue(unitID,-1)

	if not cQueue[1]  then

		return 0, minDist
	end

	local pos = {}
	local tag = false
	local I=0
	local stop = false
	local j = 1 

		for i=1, #cQueue do --skippping first of the queue if player stopped while game is paused
			if lot then
				local x= lot[i][1]
				local z = lot[i][3] and lot[i][3] or lot[i][2]
				pos[i] = { x, z, orderPos=i }

				--Echo("lot i",i, " = ", lot[i][1], lot[i][2])
			elseif cQueue[i].params[3] then -- only adding order that has coords
				pos[j] = { cQueue[i].params[1], cQueue[i].params[3], orderPos=i }
				j = j+1
			elseif #cQueue[i].params>=1 then
				local x, y, z = GetUnitOrFeaturePosition(cQueue[i].params[1])
				if x then 
				pos[j] = { x, z, orderPos=i }
				j = j+1
				end
			end
		end


	for i=1, #pos do -- getting closest order

		local distance	= GetDist(new,  pos[i])
		if distance <= minDist then		
			minDist = distance
			I = i
		end
	end
	--I is closest point
--Echo(" ---- closest ----", I)

	if  I==0 then --if I didnt change, order is closest of player, we can return 0
		--Echo("Insert Pos=> 0")
		return 0, minDist
	elseif I==1 then 
		if GetDist(pos[I],  unitPos) --if dist
			>
		   GetDist(new,  unitPos) then
			--Echo("Insert Pos=> 0")
			return 0,minDist

		else
			--Echo("Insert Pos=> 1")
			return 1,minDist
		end
	else
		--making sure (for terra) we get the earliest of order that has same coords before checking
		while I>1 and GetDist(pos[I],  pos[I-1]) == 0 do
			I = I-1
		end
		local prevDist = I>1 and GetDist(pos[I-1],  pos[I])
		--checking wether we have to place order before the closest
		--if current order pos is farther from previous order pos than new command pos,
		if I>1 and prevDist > GetDist(new,  pos[I-1]) then
			--Echo("Insert Pos=> ",pos[I-1].orderPos)
			return pos[I-1].orderPos,minDist -- insertion must be before the closest

		else -- else we reach the latest of the closest and put the order after
			while pos[I+1]~=nil and GetDist(pos[I],  pos[I+1]) == 0 do
				I = I+1
			end
			--Echo("Insert Pos=> ",pos[I].orderPos)			
			return pos[I].orderPos,minDist
		end
	end
end




GetCommandPos = function (command) -- get the command position
	local cmd = command.id
	if cmd < 0 or positionCommand[cmd] then
		local params = command.params
		if params[3] then
			return params[1], params[2], params[3]
		elseif params[1] then
			return GetUnitOrFeaturePosition(params[1])
		end
	end
end


checkImmediate = function()
	local reach, closeCons = CheckReach(cons, pointX, pointZ) -- checking if any con get first buildingplacement in its build distance range
	if not reach then return false end
	local _,_,meta,shift = sp.GetModKeyState()
	for i=1, #closeCons do
		local con = closeCon[i].id
		local posOrder = closeCon[i].posOrder
		local queue = sp.GetCommandQueue(con,-1)
		local pertinent = not queue[1] or (queue[1].id==0 or queue[1].id==5)
		immediate = (meta or (posOrder==0 and shift==meta) or
					(shift and not oldQueue[1]) or
					(not shift and not meta))
		if immediate then return true end
	end
	return false
end

getcons = function (PID)
	local units = sp.GetSelectedUnits()
	local GetDefID,UDs = sp.GetUnitDefID,UnitDefs
	local cons={}
	local n=0
	for i=1, #units do
		n=n+1
		local ud = UDs[GetDefID(units[i])]

		if ud and ud.isBuilder then
			table.insert(cons,units[i])
		end
	end
	cons.n=n
	return cons
end
getconTable = function ()
	local units = sp.GetSelectedUnits()
	local GetDefID,UDs = sp.GetUnitDefID,UnitDefs
	local cons={}
	for i=1, #units do
		local id = units[i]
		local ud = UDs[GetDefID(id)]
		if ud and ud.isBuilder then
			cons[id]={buildDistance = ud.buildDistance,isImmobile=ud.isImmobile,size=ud.xsize*4,commands={}}
		end
	end
	return {cons=cons}
end


GetCons = function ()
	local GetDefID,UDs = sp.GetUnitDefID,UnitDefs
	local units = sp.GetSelectedUnits()
	local cons,n = {},0
	for i=1, #units do
		local ud = UDs[GetDefID(units[i])]
		if ud and ud.isBuilder then
			n = n+1		 	
			cons[n] = {id = units[i], bDistance = ud.buildDistance}
		end
	end
	cons.n=n
	return cons
end




SwitchOrder = function (unitID, queue, pos1,pos2)
	local first = pos1<pos2 and pos1 or pos2
	local last = pos2~=first and pos2 or pos1

	local copyFirst = deepcopy(queue[first])

	if last == first+1 then
		sp.GiveOrderToUnit(unitID,CMD.REMOVE,queue[first].tag,0)
		sp.GiveOrderToUnit(unitID,CMD.INSERT,{last-1,copyFirst.id,CMD.OPT_SHIFT, unpack(copyFirst.params)},CMD.OPT_ALT)
	else
	       local copyLast = deepcopy(queue[last])

		  sp.GiveOrderToUnit(unitID,CMD.REMOVE,queue[last].tag,0)
		  sp.GiveOrderToUnit(unitID,CMD.REMOVE,queue[first].tag,0)	
		  sp.GiveOrderToUnit(unitID,CMD.INSERT,{first-1,copyLast.id,CMD.OPT_SHIFT, unpack(copyLast.params)},CMD.OPT_ALT)
		  sp.GiveOrderToUnit(unitID,CMD.INSERT,{last-1,copyFirst.id,CMD.OPT_SHIFT, unpack(copyFirst.params)},CMD.OPT_ALT)
	end
end
QueueChanged = function (currentQueue,oldQueue)
	local curlength,oldlength = #currentQueue,#oldQueue
	if curlength==0 and oldlength==0 then return false
	elseif curlength~=oldlength then return true
	elseif curlength==oldlength then
		for i,order in ipairs(curentQueue) do if order.tag~=oldQueue[i].tag then return order end end
	end
end

GetPosOrder = function (unitID, X,Z, id, tag) -- get position in order queue that either  has X,Z given coords, given id, or given tag
	local cQueue = sp.GetCommandQueue(unitID,-1)

	if #cQueue == 0 then return false end
	for i=1, #cQueue do
		if (id==nil or cQueue[i].id==id) and
		   (tag==nil or cQueue[i].tag==tag) and
		   (X==nil or (cQueue[i].params[1]==X and cQueue[i].params[3]==Z))
		   then
			return i, cQueue[i].id, cQueue[i].tag
		end
	end
	Echo("Doesn't find required command in the queue")
end

CheckReach = function (cons, X,Z) --- return any con that can reach a building order without moving
	local dist = 0
	local posOrder = false
	local ud = false
	local closeCons = {}
	local new
	for i=1, #cons do
		ud = UnitDefs[sp.GetUnitDefID(cons[i].id)]
		posOrder,dist = GetInsertPosOrder(cons[i].id, X,Z)
		cons[i].posOrder=posOrder -- updating received contable, might need to test
		cons[i].dist=dist
		dist = sqrt(dist)
		if ud.buildDistance > dist then
			table.insert(closeCons, {id=cons[i], posOrder=posOrder})
		end
		if #closeCons>0 then
			return true, closeCons
		else
			return false, false
		end
	end
end

---------------------------- DRAWING -----------------------------------

-- Fade In/Out function with flat/decelaration/acceleration and amplification options, can hold timer when goal is reached to keep fade factor and origin
-- needHold will likely be used in case of unfinished fading (until release) if one want to keep the current fadeFactor.
Fade = function (alphaStart,alphaEnd,amp,acc,needHold)
	local spGetTimer = sp.GetTimer
	local spDiffTimers = sp.DiffTimers
	local timer=spGetTimer()
	local time,holdtime=0,0
	local fadeFactor=1
	if alphaStart==1 then alphaStart=0.9999 end
	if alphaEnd==1 then alphaEnd=0.9999 end
	local fadeIn=alphaEnd>alphaStart
	local newAlpha=alphaStart
	local hold=false
	local amp=amp or 1
	local acc=acc or 1
	local Fader =  function(newAlphaEnd,newamp,newacc,newNeedHold)
		if newamp then amp=newamp end
		if newacc then acc=newacc end
		if newNeedHold then needHold=true end
		if newAlphaEnd then
			alphaEnd=newAlphaEnd
			if alphaEnd==1 then alphaEnd=0.9999 end
			if not needHold then alphaStart=newAlpha end
			fadeIn = alphaEnd>alphaStart 
			if hold then hold=false end
			if not timer then timer=spGetTimer() end
		end
		
		if newAlpha~=alphaEnd then
			time=holdtime + spDiffTimers(spGetTimer(),timer)
			fadeFactor =(time*amp)
			if acc==-1 then
				if fadeIn then
					fadeFactor =1/((fadeFactor*8)+1)
					newAlpha=newAlpha+(fadeFactor/10)
				else
					fadeFactor =1/(fadeFactor+1)					
					newAlpha=alphaStart*fadeFactor

				end
			elseif acc==1 then
				if fadeIn then
					newAlpha=newAlpha+fadeFactor						
				else 			
					newAlpha=newAlpha^(fadeFactor+1)
				end	
			else
				if fadeIn then	
					newAlpha=alphaStart+fadeFactor/2						
				else 			
					newAlpha=alphaStart-fadeFactor/2
				end
			end
		end
		-- if fading finished
		if fadeIn and alphaEnd<newAlpha
		or not fadeIn and alphaEnd>newAlpha
		or nround(newAlpha,0.05)==nround(alphaEnd,0.05)
		then
			if not hold and needHold then
				hold=true
				holdtime = holdtime+spDiffTimers(spGetTimer(),timer)
			end
			timer=false
			newAlpha=alphaEnd
		end
		return newAlpha
	end
	return Fader
end
Autolist = function(func,update) -- wrapper recreate and launch list -- update the list outside of DrawCallIn, run it inside
	local glCreateList,glCallList,glDeleteList = gl.CreateList,gl.CallList,gl.DeleteList
	local active=true
	local args={func}
	local exec= function(cmd,...)
		if update and update() then glDeleteList(list) ; list = glCreateList(unpack(args)) end
		if cmd~=nil then
			if 	   cmd=='new' 				  then active=true glDeleteList(list) ; list = glCreateList(func,...) ; args={func,...}
			elseif cmd=='off' and active 	  then active=false glDeleteList(list)
			elseif cmd=='on'  and not active  then list,active = glCreateList(unpack(args)),true
			end
			return
		end
		if active then glCallList(list) end
	end
	return exec
end

local pointOnMouse = (function()
	local spTraceScreenRay = sp.TraceScreenRay
	local spGetMouseState = sp.GetMouseState
	local color = {1,1,1,1}
	local pos
	local x,y = spGetMouseState()
	local pointOnMouse = function(newcolor)
		color = newcolor or color
		glBeginEnd(GL_POINTS, function()
				glColor(color)
				glPointSize(2500)
				glVertex(pos[1],pos[2],pos[3])
		end)
	end
	local update = function()
		local newx,newy = spGetMouseState()
		if newx~=x or newy~=y then
			x,y=newx,newy
			_, pos = spTraceScreenRay(x, y, true, false, true, false)
			if pos then return true end
		end
	end

	return Autolist(pointOnMouse,update)
end)()

Autolists_MouseMove = function(...) -- wrapper recreate and launch list whenever mouse move -- usage: local update = new_autolist(functions...) then run update() in Draw CallIn -- limitation: for some reason glPointSize is not applied
	local spGetMouseState=sp.GetMouseState
	local glCreateList,glCallList,glDeleteList = gl.CreateList,gl.CallList,gl.DeleteList
	local myLists = {}
	local x,y = spGetMouseState()
	for _,func in ipairs({...}) do  myLists[ func ]=glCreateList(func,x,y)  end
	local active=true
	local function init()  active=true  for   func in pairs(myLists) do myLists[func] = glCreateList(func,x,y) end  end
	local function stop()  active=false for   func in pairs(myLists) do glDeleteList(myLists[func]) end end
	local function renew()              for   func in pairs(myLists) do glDeleteList(myLists[func]) ; myLists[func] = glCreateList(func,x,y) ; glCallList(myLists[func]) end end
	local function call()			    for _,list in pairs(myLists) do glCallList(list) end end
	local update= function(onoff)
		if onoff~=nil then
			if not onoff then if active then stop() end
			elseif not active then	init()
			end
			return
		end
		if not active then return end
		local new_x,new_y = spGetMouseState()
		if x~=new_x or y~=new_y then x,y=new_x,new_y ; renew()  return true
		else call()
		end
	end
	return update
end

DrawGroundRectangle =function(gP,y,flat,hide)
	local prev=false
	local hidden
	for i=2,#gP do
		hidden = hide and not flat and (gP[i-1].hidden or gP[i].hidden)
		if not hidden then
			glVertex(gP[i-1][1], flat and y or gP[i-1][2], gP[i-1][3])
			glVertex(gP[i][1], flat and y or gP[i][2], gP[i][3])
		end
		
	end
end
DrawFlatRect = function(rect,y)
	local x,z,sx,sz = unpack(rect)
	local sx,sz= sx/2,sz/2
	local c1= {x-sx, y, z-sz}
	local c2= {x-sx, y, z+sz}
	local c3= {x+sx, y, z+sz}
	local c4= {x+sx, y, z-sz}
	local cornersdraw={c1,c2,c2,c3,c3,c4,c4,c1}
	for i,corner in ipairs(cornersdraw) do
		glVertex(unpack(corner))
	end
end


------------------------------------------- FILE ---------------------------------------------------



function WriteOnFile(dir,name,ext,...)
	local file = dir..name..(ext and '.'..ext or '')
	local f = io.open(file, "a")
	f:write(...)
	f:close()
end
-- seek for file in given dir with pattern 'name.ext' then 'name(n).ext' until none is found, then write that new file
function WriteNewFile(dir,name,ext,...)   
    local filename = name..'.'..ext
    local num,tries = 0, 0
    while io.open(dir..filename,'rw') do
        tries = tries+1 if tries>99999 then Echo('TOO MANY TRIES') return end
        num=num+1
        filename = name..'('..num..').'..ext
    end
    local success =  io.output(dir..filename) and io.write(...)
    io.output():close()
    return success and filename,dir
end

------------------------------------- TIME ------------------------------------
function FormatTimeFull(num)
	local d, h, m, s = num>(3600*24)-1 and num/(3600*24), num>3599 and (num%(3600*24))/3600, (num%3600)/60, num%60
	if d then
		return ('%02d:%02d:%02d:%02d'):format(d, h, m , s)
	end
	if h then
		return ('%d:%02d:%02d'):format(h, m , s)
	end
	return ('%02d:%02d'):format(m, s)
end

function FormatTime(num)
	local h, m, s = num>3599 and num/3600, (num%3600)/60, num%60
	if h then
		return ('%d:%02d:%02d'):format(h, m , s)
	end
	return ('%02d:%02d'):format(m, s)
end


function GetCameraHeight(cs)
    local height = cs.height

    if not height then
        local gy = sp.GetGroundHeight(cs.px,cs.pz)
        height = cs.py - gy
    end
    return height
end

wid = GetWidgetInfos()




-------------------------------------------------------------------------------------


--------- testing ground for benchmarking different function to get start of line from text position
if false then
	local pos = TEST:find("3")
	if pos then
		-- solutions
		local solutions = {
			(function()
		    	local sol
				local checkfunc = function(a)
			    	if a<pos then
			    		sol=a
			    	end
				end
				return function()
					sol=1
				    TEST:gsub("\n()",checkfunc)
				    return sol
				end
			end)(),
			--
			function()
				local sol = 1
				for p in TEST:gmatch("\n()",'') do
					if p>pos then
						return sol
					end
					sol = p
				end
			    return sol
			end,

	    	--
	    	function() -- roughly equal to fastest
	    		local _,sol = TEST:sub(1,pos):find(".*\n")
	    		return sol and sol+1 or 1
	    	end,
	    	--
	    	function() -- roughly equal to fastest
	    		return  TEST:sub(1,pos):match(".*\n()") or 1
	    	end,
		    --
	    	function()
	    		return  pos - (TEST:sub(1,pos):reverse():find("\n") or pos+1) + 2
	    	end,
	    	--
	    	function()
	    		local _pos, sol = 1,1
			    while _pos and _pos<pos do
			    	sol = _pos + 1
			    	_pos = TEST:find('\n',sol)
			    end
			    return sol
	    	end
		}
		if true then
			for i,solution in ipairs(solutions) do
				local time = os.clock()
				local sol
				for j=1,1000 do
					sol = solution()
				end
				Echo('time for solution '..i..' is '..(os.clock()-time),'found sol at ', sol)
			end
		end
	end
end


return localEnv
 -- make the env available as table, can be called in widget like 
	--local utils = VFS.Include("LuaUI\\Widgets\\UtilsFunc.lua")
	-- then localize functions you want ie: local GetDist = utils.GetDist then nil the table to free memory
