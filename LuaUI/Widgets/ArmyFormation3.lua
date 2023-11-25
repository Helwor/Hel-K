


function widget:GetInfo()
	return {
		name      = 'Army Formation3',
		desc      = 'Awesome stuff' ,
		author    = 'Helwor',
		date      = 'winter, 2021',
    	license   = 'GNU GPL, v2 or later',
		layer     = 1000001, -- after custom formation 2 to register upvalues of it, then Lowering in Initialize
		enabled   = false,
		handler   = true,
	}
end

if not WG.UnitIDCards then -- for some reason I can't run a widget from Initialize()
	Spring.SendCommands("luaui enablewidget UnitsIDCard")
end
------------------------------------------------------------------------------------
------------------------------------------------------------------------------------
--------------------------------- DECLARATION --------------------------------------
------------------------------------------------------------------------------------
------------------------------------------------------------------------------------



	--------------------------------------------------
	----------------- Importations -------------------
	--------------------------------------------------

		local custcmds = VFS.Include('LuaRules/Configs/customcmds.lua')

		include('keysym.h.lua')
		include('keysym.lua')
		include("LuaRules/Configs/customcmds.h.lua")
		include('LuaUI/Widgets/chili_old/Headers/unicode.lua')
		local KEYSYMS = KEYSYMS
		local specialKeys--[[, ToKeysyms--]] = include('Configs/integral_menu_special_keys.lua')-- 
		local f = VFS.Include('LuaUI\\Widgets\\UtilsFunc.lua')
		VFS.Include('LuaUI\\Widgets\\Keycodes.lua')
		local Units -- Unit Info widget defined in Initialize

		local colors = f.COLORS

	--------------------------------------------------
	------------------- Config -----------------------
	--------------------------------------------------
	
		local DebugOn = false
		local dontDrawCommands = true -- don't draw the units commands ordered by the formation system
		local SPOT_THRESHOLD = 100 -- the minimum distance from mouse for an order to be spottable in inspect mode
		local MOVE_SPOT = 25 -- the minimum distance from mouse for an order to be movable in inspect mode
		local AUTOROTATE = true -- add intelligent rotate order whenever a next order have an angle difference exceeding ROT_TOL
		local ROT_TOL = 0.50 -- the threshold radian when a rotation sequence should happen, consider pi beeing 180°
		local MROT_TOL = 0.02 -- the threshold when manually rotating on place
		local TURN = 0.05 -- each step of the rotation
		local Zones = { -- positions and colors of clickable zones on screen
			{name='Debug At',		x=0.15,y=0.25,size=20,color_checked='yellow',alpha_checked=0.8,color_unchecked='white',alpha_unchecked=0.3,offx=true}
			,{name='Debug Ctrls',	x=0.15,y=0.25,size=20,color_checked='yellow',alpha_checked=0.8,color_unchecked='white',alpha_unchecked=0.3,offx=true}
			,{name='Debug Layers',	x=0.15,y=0.25,size=20,color_checked='yellow',alpha_checked=0.8,color_unchecked='white',alpha_unchecked=0.3,offx=true}
		}
		local CONFIG={ -- (biggest portion is taken into account for each place)
			assault		={	place = 5,		portion = 0.5,	color = 'orange'	 	}
			,riot		={	place = 4,		portion = 1,	color = 'blue'			}
			,skirm		={	place = 4,		portion = 1,	color = 'green'	 		}
			,raider		={	place = 3,		portion = 1,	color = 'yellow'	 	}
			,aaunit		={	place = 2,		portion = 1,	color = 'turquoise' 	}
			,special1	={	place = 2,		portion = 1,	color = 'red'	 		}
			,special2	={	place = 2,		portion = 1,	color = 'purple'	 	}
			,special3	={	place = 2,		portion = 1,	color = 'violet'	 	}
			,arty		={	place = 1,		portion = 1,	color = 'lightblue' 	}
			,conunit	={	place = 1,		portion = 1,	color = 'brown'	 		}
			,unknown	={	place = 1,		portion = 1,	color = 'white'	 		}
		}
		local layerColors = {
			'blue'
			,'orange'
			,'turquoise'
			,'lime'
			,'violet'
		}
		local actHotkeys = {
			-- {name='move_rotate',		'C','posed','!lClick','shift'}
			{name='rmove_rotate',		'C','rposed','!rClick'}
			--,{name='posed',				'C','lClick','shift'}
			,{name='rposed',			'C','rClick','!alt'}
			,{name='grabbing',			'C','!posed','!rposed'}
			,{name='fmode',				'sel','ctrl','f','Key'} -- 'Key' means the Update event must be a key 
			,{name='unselect',			'C','escape','Key','!cmd'}

			,{name='inspect',			'C','space'}
			,{name='angle_offset',		'shift','C','ctrl','!alt'}

			,{name='shifted',			'C','shift'}

			,{name='stop',				'!trailing','!shift','!rposed','C','rClick'}
			,{name='trailing',			'C','alt','rClick','!cmd'}
			-- ,{name='trailing',			'C','alt','lClick','cmd'}
			,{name='lock_angle',		'C','ctrl','alt'}

			

			,{name='reset_offset',		'z','C','ctrl'}
			,{name='rotate',			'alt','C','lClick','!ctrl','!shift'}

			,{name='cleanmem',			'm','ctrl','alt'}
			,{name='debug_layer',		'r','ctrl','alt'}
			,{name='debug_uradius',		'u','ctrl','alt'}
			,{name='reload_widget',		'n_5','alt'}
			,{name='debug_echo',		'd','ctrl','alt'}

			,{name='instant_regroup',   'C','c','ctrl'}




		}

	--------------------------------------------------
	------------- Localized functions ----------------
	--------------------------------------------------

		--------- Spring ---------
			local spGetUnitsInCylinder  = Spring.GetUnitsInCylinder
			local spSelectUnitArray    	= Spring.SelectUnitArray
			local spGetVisibleUnits 	= Spring.GetVisibleUnits
			local spSetActiveCommand    = Spring.SetActiveCommand
			local spSendCommands 		= Spring.SendCommands
			local spGiveOrderToUnit     = Spring.GiveOrderToUnit

			local spGetTimer 			= Spring.GetTimer
			local spGetGameSeconds 		= Spring.GetGameSeconds
			local spGetModKeyState		= Spring.GetModKeyState
			local spDiffTimers 			= Spring.DiffTimers
			local spGetMyTeamID 		= Spring.GetMyTeamID
			local spGetSpectatingState 	= Spring.GetSpectatingState
			local spIsReplay 			= Spring.IsReplay
			local spValidUnitID 		= Spring.ValidUnitID
			local spGetCommandQueue		= Spring.GetCommandQueue
			local spGetUnitDefID 		= Spring.GetUnitDefID
			local spGetTeamUnits		= Spring.GetTeamUnits
			local spGetMouseState 		= Spring.GetMouseState

			local spTraceScreenRay 		= Spring.TraceScreenRay

			local spGetUnitPosition 	= Spring.GetUnitPosition
			local spGetGroundHeight 	= Spring.GetGroundHeight
			local spGetActiveCommand 	= Spring.GetActiveCommand

			local spGetSelectedUnits    = Spring.GetSelectedUnits
			local spGetSelectedUnitsSorted = Spring.GetSelectedUnitsSorted
			local spGetSelectedUnitsCounts = Spring.GetSelectedUnitsCounts
			local spGetUnitIsDead 		= Spring.GetUnitIsDead

			local spugetMovetype 		= Spring.Utilities.getMovetype

			local spGetUnitCollisionVolumeData = Spring.GetUnitCollisionVolumeData

			local Echo					= Spring.Echo

			local insert = table.insert
			local clock = os.clock

		---------- Own -----------
			local Page 					= f.Page
			local vunpack 				= f.vunpack
			local kunpack 				= f.kunpack
			local l 					= f.l
			local MakeTrail				= f.MakeTrail
			local comboKeyset 			= f.comboKeyset
			local CheckTime 			= f.CheckTime
			local GetMouseOwner 		= f.GetMouseOwner
			local linesbreak 			= f.linesbreak
			local DebugUnitCommand 		= f.DebugUnitCommand
			local DisableOnSpec         = f.DisableOnSpec
			local autotable				= f.autotable
			local reverse 				= f.reverse
			local consumer				= f.consumer
			local identicalkv 			= f.identicalkv
			local UniTraceScreenRay 	= f.UniTraceScreenRay

		---------- Math ----------

			local round = math.round
			local max = math.max
			local min = math.min
			local abs = math.abs
			local sqrt = math.sqrt
			local rand = math.random
			---- Own
			local nround 				= f.nround
			local roughequal			= f.roughequal
			local ceil = function(x,n) 
				n=10^(n or 0)
				return round(x*n+(0.5/n))/n
			end

			local floor = function(x,n) 
				n=10^(n or 0)
				return round(x*n-(0.5/n))/n
			end
			local sign = function(x) return x<0 and -1 or 1 end

		-------- Geometry --------
			local sin = math.sin
			local cos = math.cos
			local deg = math.deg
			local arcsin = math.asin
			local acos = math.acos
			local pi = math.pi
			local pi2 = pi*2
			local ra = pi/2
			local atan2 = math.atan2
			---- Own
			local turnbest	 = f.turnbest
			local clampangle = f.clampangle
			local area		 = f.area
			local radius	 = f.radius
			local sq_rad	 = f.sq_rad
			local to_ar		 = f.to_ar
			local to_rad	 = f.to_rad
			local in_ar		 = f.in_ar
			local in_rad	 = f.in_rad

		--- unused own geometry --
			--[[
				local function degtri(angle)-- angle of triangle to degree
					return angle/pi*180
				end
				-- note: radians are proportions of pi2 // circonference is radius * pi2 therefore arc length is arc in radians * radius
				local function arc(Ur,r) -- chord to angle of arc in radian, giving chord and radius 
					-- deduce angle of arc by 2 * (rightangle in radians - arc cosinus of the cosinus of angle of triangle rectangle inscribed in isoscele triangle r-r-chord)
					return ( ra-acos(Ur/r) ) -- == arcsin(Ur/2/r)
				end
				local function arcln(Ur,r) -- length of arc
					return r*arc(Ur,r)
				end
				local function UperLayer(Ur,r) -- simplify pi2 / arc(Ur,r)
					return pi / arcsin(Ur/r)  -- == pi / ( ra-acos(Ur/2/r) )
				end
			--]]

	--------------------------------------------------
	-------------- Shared variables ------------------
	--------------------------------------------------
		---- Debugging

		---- Own
		DisableOnSpec = f.DisableOnSpec(_,widget,'setupSpecsCallIns') -- auto call-in disabler when speccing/unspeccing
		----
		local last_mx,last_my = spGetMouseState()
		local Sel
		---- defined in Initialize
		local myTeamID
		local UDS -- UnitDefsID 
		---- Drawing -----
		local outPoint = {0,0,0}
		local drawFormationName=true
		local Circles={}
		local Points={}
		local Texts={}
		local txtx,txty
		local mouseDragging=false
		---- constants -----
		local NO_SPEED = {0.1}
		local NORMAL_SPEED = {0}
		local CMD_MOVE = CMD.MOVE
		local CMD_RAW_MOVE = CMD_RAW_MOVE
		local CMD_FIGHT = CMD.FIGHT
		local OPTCODE = CMD.OPT_RIGHT+CMD.OPT_ALT+CMD.OPT_CTRL -- common used opt for any command for now, TODO: implement attack and patrol
		-- check/unchecked on-screen text debug
		local CHECKED = 'o'
		local UNCHECKED = string.char(215) -- little x
		-- unused: translating heading to radians = Spring.GetUnitHeading(id)*RAD_PER_ROT
		local RAD_PER_ROT = (pi/(2^15))
		---- Custom Formation 2 components
		local findHungarian
		local GetOrdersNoX
		local GetOrdersHungarian
		local MHU_num
		local CF2_MatchUnitsToNodes
		local FCMDS_num
		local CF2_MousePress
		---- Show All Commands v2 components
		local PreventDrawCmds = function() end
		local AllowDrawCmds = function() end
		---- unused: picking 2 callin function from Icon Zoom Transition to remove icons when needed -- TODO: find a way to achieve this
		local IZT_LeftLos
		local IZT_Entered_Los
		---- handles
		local C -- current formation selected, either a project or an active one
		local cmd -- chosen command
		----- classes
		local FORMATION 	= {}
		local UNIT 			= {}
		local ORDERS		= {}
		local MOVEMAP		= {}
		local CONTROLS		= setmetatable({keys={},statuses={},acts={},debugstr='',debugstr2='',debugstr4='',debugstr3=''},{__index=function(self,k) return C and C[k] end})
		local DELAY_REMOVE	= {formations={}}
		local Debug		    = {At={},Ctrls={},Layers={}}
		local ZONES			= {ci=false} -- screen interaction
		local OPTIONS		= {}
		local DEFINE		= {} -- 
		------ storing object
		local ACTIVES 		= {n=0,selected=false,spotted=false}-- stock of active formations (that have been ordered in their life time)
		local ACTIVEIDS 	= {} -- ids of Actives pointing to unit objects -- it's not possible to have 2 active formations having common units (for now?)
		local MEMORY		= {most_used_shapes={},oriSHAPES={},formations={}}
		local currentSel 	= {n=0}
		local opts 			= {alt = false, ctrl = false, meta = false, shift = false, right = false}
		---- Shape register and their annexes
		local SHAPES, SET_BEFORE, SET_AFTER, OFF_PORTION
		----

	--------------------------------------------------
	------------------ Options -----------------------
	--------------------------------------------------
		-- not used anymore, using own system now, TODO: will need to reimplement option with the new system 
			--[[
				function OPTIONS:GetHotkey(key)
					local w_name = widget:GetInfo().name:gsub(' ','_'):lower()
					return WG.crude.GetHotkey("epic_"..w_name..'_'..key)
				end

				function CONTROLS:AddKey(key,hotkey)
					local keys = self.keys
					if keys[key] then keys[ keys[key] ]=nil end
					keys[hotkey]=key
					keys[key]= hotkey
				end



				options_path = "Hel-K/Army Formation 3"
				options_order = {--[=['debug','fswitch'--]=]}
				options = {
					--[=[
						debug = {
							 name = "Debug"
							,type = "bool"
							,value = false
							,desc = "debugging"
							,hotkey = 'Ctrl'
							,OnChange = function()  Echo('OnChange') Debug.On = not Debug.On end
							,OnHotkeyChange = function()  CONTROLS:AddKey('debug',OPTIONS:GetHotkey('debug')) end
						},
					--]=]
					--[=[			
						fswitch = {
							 name = "Formation Mode"
							,type = "button"
							,desc = "debugging"
							,hotkey = 'H'
							,OnChange = function() Echo('on change')  Echo('--') return false end
							,OnHotkeyChange = function() CONTROLS:AddKey('fswitch',OPTIONS:GetHotkey('fswitch')) end
						},
					--]=]
				}
			--]]


------------------------------------------------------------------------------------
------------------------------------------------------------------------------------
----------------------------- FORMATION CREATION -----------------------------------
------------------------------------------------------------------------------------
------------------------------------------------------------------------------------

	function FORMATION:new(sel)
		---
		local f = FORMATION:Create(sel)
		f:UpdatePoses(f.center)
		f.mouse_center = {unpack(f.center)}
		f.last_center = {unpack(f.center)}
		f.shift_center = {unpack(f.center)}
		f.pose_center= {unpack(f.center)}
		f.ghost_center = {unpack(f.center)}
		f.aim_center = f.ghost_center

		f:SetLayers()
		f:PopulateLayers()
		f:SetPoints()
		f:SetPoints('m')
		f.update_angle=true
		f.move_angle = f.angle
		f:SetGhostFormation()

		-- replace the current if it's inactive or add a new one
		--
		---
		return f
	end


	function FORMATION:Create(sel)
		local f = setmetatable(
			 {	 gametime=spGetGameSeconds(), rem_delay=Spring.GetLastUpdateSeconds(), gameframe=Spring.GetGameFrame()
			 	,orders=setmetatable({f=false,n=0,done=0,expand=1,turn_offset=0,angle=0,['#']=0},{__index=ORDERS})
			 	,active=false
			 	,size=0
			 	,Repeat={}
			 	,uTypes={}
			 	,allIDs={}
			 	,places={}
			 	,layers={}
			 	,area=0,rad=0,angle=0,turn_offset=0
			 	,at=0,status='no order'
			 	,gAngle = 0
			 	,update_ghost=true
			 	,moving=false, onTheMove=0
			 	,spotted=false,selected=false
			 	,moving_shape_num=0,shift_shape_num=0
			 	,maintain_speeds=false,update_angle=false,update_move_angle=false
				,update_unit_at={},update_units_at=false,update_order=false,update_speeds=false
			 	,ETA=0,check_eta=false,ETA_threshold=0
			 	,rem_pending={}
			 	,center={},last_center={},mouse_center={},ghost_center={}
			 	,aim_center={},shift_center={},pose_center={}
			 	,pose_angle=false}
			,{  __index=FORMATION}
		)
		f.f=f
		for defid,ids in pairs(sel) do f:NewUnitType(defid,ids)	end
		local speed = 999999
		for _,uType in pairs(f.uTypes) do speed = uType.speed<speed and uType.speed or speed end
		f:CreateScoring()
		f.speed=speed
		--
		local shape_num,expand = f:RecallPreferences()
		f.shape_num,f.expand = shape_num,expand
		f.shape = SHAPES[shape_num]
		f.moving_shape_num = shape_num
		f.shift_shape_num = shape_num
		f.orders.f=f

		--
		return f
	end

	----------------------------------------------------------------------------
	---------------------------- UNITS CREATION --------------------------------
	----------------------------------------------------------------------------
		function FORMATION:NewUnitType(defid,ids)
			-- create a defid table that hold:
			-- common properties of this defid
			-- properties of the whole (area,n...)
			-- indexeds tables in parallel for individual units
			local class = Units[ ids[1] ].class
			local config = CONFIG[class]
			local place,portion = config.place, config.portion
			local n = #ids
			local r = UNIT:GetRadius(ids[1],defid)
			local sq_r = sq_rad(r)
			local area = area(sq_r*n)
			--
			local allIDs = self.allIDs
			local byID,poses,points,moves,gPoints,mPoints,units={},{},{},{},{},{},{}

			local uType ={
						   ---- reference to the formation
					        f = self
					       ---- reference to unit tables by id
					       ,byID	= byID
					       ---- common properties of that unit type
						   ,color	= config.color
						   ,speed	= UDS[defid].speed
						   ,defid	= defid
						   ,name	= UnitDefs[defid].name
						   ,class	= class
						   ,place	= place
						   ,portion	= portion
						   ,r		= r
						   ,sq_r	= sq_r
						   ---- layer#
						   ,l		= 0
						   ---- properties of the whole
						   ,n		= n
						   ,area	= area
						   ---- indexed table of ids
						   ,ids		= ids
						   --   indexed table of units
						   ,units   = units
						   -- parallel indexed subtables of units
						   ,poses	= poses 	-- poses of units
						   ,points	= points 	-- point of the formation project
						   ,gPoints	= gPoints 	-- current progression of formation as ghost
						   ,mPoints	= mPoints 	-- order points of the moving formation 
						   ,moves	= moves 	-- current and pending move orders of units
					   	   --
					     }
			self:MakeUnits(defid,ids,uType,allIDs,   byID,poses,points,moves,gPoints,mPoints,units)
			------

			self.uTypes[defid] = uType
			if not self.places[place] then self.places[place]={} end
			self.places[place][defid] = uType
			self.area = self.area+area
			self.size=self.size+n
		end
		function FORMATION:AddUnitsInType(defid,ids)

		end
		function FORMATION:MakeUnits(defid,ids,uType,allIDs,   byID,poses,points,moves,gPoints,mPoints,units)
			local speed = uType.speed
			for i,id in ipairs(ids) do
				local pos, point, gPoint, mPoint, uMoves = {spGetUnitPosition(id)}, {i=i}, {i=i}, {i=i}, MOVEMAP:New(self,id)
				local unit = { 
							   uType		= uType
							  ,f			= self
							  ,defid		= defid
							  ,i			= i
							  ,id			= id

							  ,at			= 0
							  ,status		= 'idling'

							  ,speed		= speed
							  ,wantedSpeed 	= {speed}
							  ,ignore_time	= false -- don't take into account the units too much in late for setting the best speeds of units

							  ,r			= uType.r

							  ,pos			= pos
							  ,point		= point
							  ,uMoves		= uMoves
							  ,gPoint		= gPoint
							  ,mPoint 		= mPoint

							  -- layer#,sublayer# and index of sublayer
							  ,l			= 0
							  ,s			= 0
							  ,sn			= 0
							  --

							  ,ETA			= 0
							  ,goal			= false
							  ,last_order	= false
							  ,resent    	= false
							  ,deleted      = false
							 }
				uMoves.unit=unit
		 		--setmetatable(unit,{__index=passUNIT})
		 		setmetatable(unit,{__index=UNIT})

				 points[i], poses[i], moves[i], gPoints[i], mPoints[i], units[i]
				=  point,    pos,      uMoves,    gPoint,     mPoint,    unit
				-- all ids of the formation, and all ids from all formations
				 byID[id], allIDs[id]
				= unit,       unit
			end
			return byID,poses,points,moves,gPoints,mPoints,units
		end

		function UNIT:GetRadius(id,defid) -- lots of trying but didnt find a perfect definition of room occupied by unit
			local def = UDS[defid]
			local scx,scy,scz = spGetUnitCollisionVolumeData(id)
			local x,y,z=spGetUnitPosition(id)
			local rad = def.radius

			-- different radius setting
				--[[
					--local testrad=max(((scx/2)*(scy/2)*(scz/2))^(1/3),rad,(16*def.xsize*def.zsize)^0.5)
					--local volrad = ((scx/2)*(scy/2)*(scz/2))^(1/3)
					--volrad = rad>volrad and volrad+rad/2 or volrad
					--volrad=(scx/2*scz/2)^0.5
					--volrad=rad>(scx/2*scz/2)^0.5 and volrad+rad/2 or volrad

					--local col = def.collisionVolume
					--volrad = (col.scaleX/2*col.scaleZ/2)^0.5
					--Debug("scx,scy,scz is ", scx,scy,scz)
					--volrad=(def.xsize*def.zsize*16)^0.5

					--local bRad=col.boundingRadius
					--if bRad>volrad then volrad = (volrad+bRad)/2 end
					--if col.defaultToSphere then volrad=def.radius end
					--volrad = bRad>volrad and (volrad+bRad)/2 or volrad
					--volrad=bRad
					--Page(col)
					
					--Debug("def.radius is ", def.radius)
					--Debug("volrad is ", volrad,bRad)

					--Debug("volrad,rad is ", volrad,rad)

					--[=[
					Page(col)
					Debug('\nRouge: bounding Radius',bRad,
						  '\nVert: def.radius',rad,
						  '\nBleu: scaleX',scx/2,
						  '\nViolet: moyenne scale',(scx/2*scy/2*scz/2)^(1/3),
						  '\nJaune: moyenne scale+bounding',(bRad+scx/2)/2,
						  '\nBlanc: xsize',(def.xsize*def.zsize*16)^0.5,
						  '\nNoir: radius/2',rad/2,
						  '\nOrange: moyenne xsize&scale',((def.xsize)*4+scx/2)/2 -- sphere vs spehre
						  )
					--]=]

					--[=[
					Circles[#Circles+1]={x,y,z,bRad,{1,0,0,1}} -- bounding rouge
					Circles[#Circles+1]={x,y,z,rad,{0,1,0,1}} -- radius vert
					Circles[#Circles+1]={x,y,z,scx/2,{0,0,1,1}} -- bleu -- cylindre
					Circles[#Circles+1]={x,y,z,(scx/2*scy/2*scz/2)^(1/3),{1,0,1,1}} --violet
					Circles[#Circles+1]={x,y,z,(bRad+scx/2)/2,{1,1,0,1}} -- jaune 
					Circles[#Circles+1]={x,y,z,(def.xsize*def.zsize*16)^0.5,{1,1,1,1}} -- blanc
					Circles[#Circles+1]={x,y,z,rad/2,{0,0,0,1}} -- noir
					Circles[#Circles+1]={x,y,z,((def.xsize)*4+scx/2)/2,{1,0.5,0,1}} -- orange
					--]=]	
				--]]

			return ( (def.xsize*2+scx/4)^2 + (def.zsize*2+scz/4)^2 ) ^0.5
			--return def.xsize*2+scx/4
		end
		-- unused ONLY HUNGARIAN which is freezing on hundreds on units
			--[[
				function FORMATION:AttachUnits() -- compare positions of units to points of layer and pair them by least distance travelled
				--, updatings order of points, keeping order of ids
					self:UpdatePoses()
							local cnt =0
					for _,uType in pairs(self.units) do
						local travels={}
						local mindist=math.huge
						local ids,points,poses = uType.ids,uType.points,uType.poses
						for i,pos in ipairs(poses) do
							local id=ids[i]
							travels[i]={}
							local travel = travels[i]
							for j,point in ipairs(points) do
								local dist=floor( ((pos[1]-point[1])^2+(pos[3]-point[3])^2)^0.5 + 0.5 ) 
								--local dist=(pos[1]-point[1])^2+(pos[3]-point[3])^2
								travel[j]= dist
								cnt=cnt+1
							end
						end
						local time = clock()
						local result = findHungarian(travels,uType.n) -- get the best index of points per index of ids
						Debug(uType.name,clock()-time)
						local new_points={}
						local byID = uType.byID
						for _,res in ipairs(result) do
							local i,newi = res[1],res[2]
							local id = ids[i]
							local point = points[newi]
							local unit = byID[id]
							unit.point=point
							new_points[i]=point
						end
						uType.points=new_points
					end
				end
			--]]

		--unused checkpoint before accessing UNIT methods, verifying if the unit is not already destroyed (removal of unit is delayed)
			--[[ 
				local passUNIT = (function()local dummy = function()end	; return function(self,k) return self.deleted and Echo('denied')==nil and dummy or UNIT[k] end end)()
			--]]

	----------------------------------------------------------------------------
	------------------------------- Layers -------------------------------------
	----------------------------------------------------------------------------

		function FORMATION:UpdatePoses(from,copy)
			local sum,sumx,sumz = 0,0,0
			for id,unit in pairs(self.allIDs) do
				local x,y,z = spGetUnitPosition(id)
				local pos = unit.pos
				pos[1],pos[2],pos[3] = x,y,z
				sum,sumx,sumz = sum+1,sumx+x,sumz+z
			end
			if not (from or copy) then return end
			local cx,cz = sumx/sum, sumz/sum
			local cy = spGetGroundHeight(cx,cz)
			if from then from[1],from[2],from[3] = cx,cy,cz end
			if copy then copy[1],copy[2],copy[3] = cx,cy,cz end
		end

		function FORMATION:SetLayers()
			local layers={}
			local function sortTypes(a,b) return a.n<b.n end
			local l=0
			-- sort layer by place and portion
			for i=1,5 do 
				local p = self.places[i]
				if p then
					l=l+1
					local layer = {uTypes={},rad=0,l=l,n=0}
					for defid,uType in pairs(p) do

						uType.l=l
						layer.n=layer.n+uType.n
						layer.portion = max(layer.portion or uType.portion,uType.portion)
						table.insert(layer.uTypes,uType)
					end
					-- rearrange the layer by portion, inform uType, set radius
					table.sort(layer.uTypes,sortTypes)
					-- set radius of the layer, its sublayers and update the formation layer
					self:SetRadius(layer)
					table.insert(layers,layer)
				end
			end
			self.layers=layers
			-----------
		end

		function FORMATION:SetRadius(layer)
			-- Echo("====layer:"..layer.l..'====')


			local r,sq,n=0,0,0
			-- set an average radius, total num, total sq_radius TODO: might need a better method
			for i,u in ipairs(layer.uTypes) do
				n = n+u.n
				r,sq =  r + u.r*u.n, sq + u.sq_r*u.n
			end
			sq = sq/n
			if layer.portion<1 then
				sq = ( (sq^2)/layer.portion  )  ^ 0.5
			end
			r = r/n
			-- if layer.l==2 then self.rad=self.rad+15 end
			local rad = self.rad

			-- what is the global radius becoming if we add this many units 
			--NOTE: the current formation radius is augmented by sq_radius* n units  (rad of the circle having area of a square inscribing the circle made by r)
			local raw = to_rad(rad,sq,n)
			-- what is the thickness of the main_layer
			local main_layer = raw-rad

			-- how many radiuses (half of a sub layer thickness) fit in the main layer
			local width = main_layer/r--- !!!! NOTE: MAIN LAYER IS DEFINED BY SQ_R AND NOT R, for each unit, there is 
			-- how many sublayers does that make
			-- Set Radius of sublayers
			local sublayers={}
			-- Echo("width%2 is ",width, width%2,in_ar(area(raw)-area(rad),sq))
			if layer.l>1 then
				self.rad=self.rad+(width%2)*r
				rad = self.rad
				raw = to_rad(rad,sq,n)
				main_layer = raw-rad
				width = main_layer/r--- !!!! NOTE: MAIN LAYER IS DEFINED BY SQ_R AND NOT R, for each unit, there is 
				-- Echo('now width is ',width, width%2)
			end
			-- if rad ==0 then
			-- 	Echo('center rad can'..(width%2<0.8 and 'not' or '')..' have a center unit',width%2)
			-- end
			if rad==0 then -- very first layer
				if main_layer==sq then -- just one unit
					table.insert(sublayers,1,{rad=0,r=r,sq=sq})
				else
					for i=width-1,0,-2 do -- starting from last make it more easy for the offset
						--Debug('normal i is',i)
						if i<1 then i = i<0.5 and 0 or 1 end
						local lrad = rad+i*r
						table.insert(sublayers,1,{rad=lrad,r=r,sq=sq})
						if i<2 and  i>1.75 then
							table.insert(sublayers,1,{rad=0,r=r,sq=sq}) 
						end
					end
				end
			else
				local offset = 2*(width%2)
				if offset<0.9 and width>=1 then
					-- offset the radiuses a little to avoid having almost empty last sublayer
					for i=width-1,0,-2 do 
						local lrad = rad+i*r
						table.insert(sublayers,1,{rad=lrad,r=r,sq=sq})
					end
					if not sublayers[1] then
					end
				else
					for i=1,ceil(width/2)*2,2 do -- 
						local lrad = rad+i*r
						table.insert(sublayers,{rad=lrad,r=r,sq=sq})
					end
				end
			end
			----- complete sublayers info
			local remains = layer.n
			for i,subl in ipairs(sublayers) do
				if rad==0 and i==1 and subl.rad==0 then
					subl.area=area(sq)
				else
					subl.area = area(subl.rad+r)-area(subl.rad-r) 
				end
				subl.contains = round(in_ar(subl.area,sq))
				subl.n = min(remains,subl.contains)
				remains = max(0,remains-subl.contains)
			end
			--Debug('TOTAL:'..total)
			layer.sublayers=sublayers

			self.rad = sublayers[#sublayers].rad+r
			--
			local cenx,ceny,cenz = unpack(self.center)
			Circles['l'..layer.l]={cenx,ceny,cenz,rad,colors.white}
			--
		end

		function FORMATION:PopulateLayers()
			for l,layer in ipairs(self.layers) do
				local uTypes = layer.uTypes
				local altunit = consumer(layer.uTypes,'n') -- create generator alternating between units, ignoring those that have reached repetition defined in 'n' prop
				local sublayers = layer.sublayers
				local nsub = #sublayers
				for s=nsub,1,-1 do -- filling the most external sublayers first, to put alternated units in there
					local sublayer = sublayers[s]
					local contains = round(sublayer.contains) 
					local n=0
					for c=1,sublayer.n do
						-- give a new unit with its index in 'ids'
						local uType,i = altunit() if not uType then break end --no more units to distribute
						local id = uType.ids[i]
						local unit = uType.byID[id]
						unit.l,unit.s,unit.sn=l,s,c
						--Debug('put '..uType.name, '#'..i,'id:'..id,'at layer '..l,'sublayer '..s)
						sublayer[c]=unit
						--n=n+1
					end
					--sublayer.n=n
				end
				 -- it can appear contains was a bit too short, we add the missing ones to the last sublayer
				local missing,i = altunit()
				while missing do
					local id = missing.ids[i]
					local unit = missing.byID[id]
					local sublayer = sublayers[nsub]
					local n=sublayer.n+1
					unit.l,unit.s,unit.sn = l,nsub,n
					--Debug('put the missing '..missing.name, '#'..i,'id:'..id,'at layer '..l,'sublayer '..nsub)
					sublayer[n]=unit
					sublayer.n=n
					missing,i = altunit()
				end
				
			end
		end

	----------------------------------------------------------------------------
	------------------------------- Points -------------------------------------
	----------------------------------------------------------------------------

		--- setting the base point offset from the center with their angle, according to the selected shape
		function FORMATION:SetPoints(moving)
			local shape = SHAPES[moving and self.moving_shape_num or self.shape_num]
			local fRadius = self.rad
			local x,z = self.center[1], self.center[3]
			local angle = 0 -- no more mixing up current self angle
			local layers = self.layers
			local lastL = layers[#layers]
			local lastS = lastL.sublayers[#lastL.sublayers]
			local maxoffset = lastS.rad
			local minoffset = layers[1].sublayers[1].rad

			--local maxoffset = fRadius * self[1].pos
			--local minoffset = fRadius * (1-self[1].pos)
			local nlayers = #layers
			local set_before = SET_BEFORE[shape] -- get shape corresponding function modifying initial values
			local set_after = SET_AFTER[shape] -- modify result
			for l=1, nlayers do
				local layer = layers[l]
				local sublayers = layer.sublayers
				for s=1,#sublayers do
					local sublayer = sublayers[s]
					local offset = sublayer.rad
					angle = angle + (layer.ori or 0) -- not used for now, but could be for rotating a portion<1
					local portion = (layer.portion or 1)*2 -- TODO: re-implement  portions afterward, but now it has to be differentiated within the same sublayer
					local num = sublayer.n
					local rotate
					local full = portion<1.8 and 1 or 0
					local sep = portion/(num-(num>1 and full or 0))
					local hf = ceil(portion/2, 4)
					if num==1 then hf,full,sep = 0,1,1 end
					local n=0
					local inv=false
					local st,fin,step = -hf, hf-(1-full)*sep+0.000001, sep
					if portion<2 then
						local I=0
						for i = st,fin,step do
							I=I+1
						end
						--Echo('I:',I)
						--Echo('shape',shape)
						local off = OFF_PORTION[shape]
						--Echo("moving and self.moving_shape_num is ", moving and self.moving_shape_num)
						st,fin = st+I*off*step,fin+I*off*step
					end
					--local a = st
			 		for a = st,fin,step do -- a is the proportion of pi to perform the rotation, starting at -1(opposite of cursor direction) to ~0 (cursor direction) to 1-step (back)
			 			n=n+1

						local unit = sublayer[n]

						local sig = a<0 and -1 or 1
						local rotangle = angle+a*pi
						local offset=offset

						if set_before then
							offset,rotangle,rotate = set_before(sig,a,angle,offset,rotangle,rotate)
						end

						local shiftx, shiftz = sin(rotangle)*offset, cos(rotangle)*offset
						local fx,fz = x + shiftx, z + shiftz
						local offx,offz = fx-x, fz-z
						local biggest = max(abs(offx),abs(offz),1e-7)
						local dirx,dirz =  offx/biggest,offz/biggest

						local off = ((dirx*offset)^2+(dirz*offset)^2)^0.5
						local ratio = (dirx^2+dirz^2)^0.5 -- hypothenus
						local sdx,sdz = dirx<0 and -1 or 1, dirz<0 and -1 or 1

						if set_after then
							fx,fz,rotate = set_after(x,z,sig,shiftx,shiftz,a,angle,fx,fz,dirx,dirz,sdx,sdz,ratio,offset,minoffset,maxoffset,nlayers,fRadius,off,offx,offz)
						end
						if rotate then
							local offx,offz = fx-x,fz-z
							local offhyp = (offx^2+offz^2)^0.5
							local nangle = atan2(offx,offz)
							fx,fz = x+sin(rotate+nangle)*offhyp, z+cos(rotate+nangle)*offhyp
						end
						local fy = spGetGroundHeight(fx,fz)

						local dist = ((fx-x)^2+(fz-z)^2)^0.5
						local angle = atan2(fx-x,fz-z)

						-- register the original point angle without self rotation and original distance without expansion
						local point=moving and unit.mPoint or unit.point
						point[1],point[2],point[3],point.dist,point.angle = fx,fy,fz,dist,angle
						point.l,point.s,point.sn = l,s,n

						--[[
				 			if n>1 then
				 				inv=not inv
				 				a=-a
					 		end
			 				if not inv then
			 					a=a+step
			 				end
		 				--]]
					end
				end
			end
			self:RecenterPoints(moving)
			-- turn the new formation to the current angle and expand to the current expansion
			if self.angle~=0 then self:Turn(0) end
			if self.expand~=1 then self:Expand(0) end

		end

		function FORMATION:RecenterPoints(m) -- offsets the points to get them around the center, if the layers contains PORTIONS<1 or is a special shape
			local toDo = SHAPES[m and self.moving_shape_num or self.shape_num]~='CIRCLE'
			local uTypes = self.uTypes
			if not toDo then
				for l,layer in pairs(self.layers) do
			 		if layer.portion<1 then toDo=true break end
				end
			end
			if not toDo then return end
			local point_key = m and 'mPoints' or 'points'
			local cnt,sumx,sumz=0,0,0
			local cx,cy,cz = unpack(self.center)
			for _,uType in pairs(uTypes) do
				for _,point in ipairs(uType[point_key]) do
					local x,_,z = unpack(point)
					cnt,sumx,sumz = cnt+1,sumx+x,sumz+z
				end
			end

			local cenx,cenz = sumx/cnt,sumz/cnt
			local offx,offz = cx-cenx,cz-cenz

			for _,uType in pairs(uTypes) do
				for _,point in ipairs(uType[point_key]) do
					local x,z = point[1]+offx,point[3]+offz
					point[1],point[3] = x,z
					point[2] = spGetGroundHeight(x,z)
					point.dist = ((x-cx)^2+(z-cz)^2)^0.5
					point.angle = atan2(x-cx,z-cz)
				end
			end
		end

		-- square points function for study
			--[[
				local function CreateSquarePoints(formation,ox,oz,s)
					local rad = formation[1].units[1].radius
					local x,z = ox-s+rad,oz-s+rad
					local started
					for i,layer in ipairs(formation) do
						local n=0
						for i,unit in ipairs(layer.units) do
							rad = unit.radius
							for i=1,unit.num do
								if x>=ox+s then x,z=ox-s+rad, z+rad*2 end
								n=n+1
								local y = spGetGroundHeight(x,z)
								layer[n]={x,y,z,rad=rad}
								x=x+rad*2
							end
						end
					end
				end
			--]]

------------------------------------------------------------------------------------
------------------------------------------------------------------------------------
-------------------------------ORDER MANAGEMENT-------------------------------------
------------------------------------------------------------------------------------
------------------------------------------------------------------------------------

	--------------------------------------------------------------------------
	----------------------------- Main Ordinator -----------------------------
	--------------------------------------------------------------------------

		function FORMATION:RemoveOrder(at)
			local orders = self.orders
			o = table.remove(orders,at)
			for i,order in ipairs(orders) do orders[i].n=orders[i].n-1 end
			orders.n=orders.n-1
			if CONTROLS.spottedOrder==o then CONTROLS.spottedOrder=false CONTROLS.acts.uninspect() end
			return o
		end

		function FORMATION:GiveNextOrder(manual)
			local init = not self.moving
			if manual and not init then return end
			local orders = self.orders
			self:OrderReset()
			local prevO 
			------ if formation wasn't moving, setting formation as active and waiting 3 rounds of update before checking units orders
			if init then
				self:InitOrders()
				self.update_order=3
			--------------------------------------------------------------------------------------------------------------------------
			else
				prevO = self:RemoveOrder(1)
				if prevO then
					self.gAngle=prevO.angle
				end
				--- in case we modified the shape while order was processing (rotating) ----
				if prevO.shapeshift and self.moving_shape_num~=prevO.shape_num then
					--self:ShapeShift(o.shape_num)
					Echo('Inserted shape:',SHAPES[prevO.shape_num])
					local newo = self.orders[1]
					if newo and newo.name~='Regroup' then
						self:AddRegroup(prevO.to,prevO.to,1,prevO.angle,prevO.expand,prevO.shape_num)
					end
				end
				---------------------------------------------------------
				--self.update_order=3
			end
			local order = self.orders[1]

			if not order then 

				-- Echo('======== End ========')
				self:EndOrders()
				return
			end
			-- if shapeshift and not regroup then insert a regroup with the new shape before the order
			--	, cancel the shapeshift of this order, remove also an eventual rotate
			if order.name~='Regroup' and order.shapeshift then
				order.shapeshift=false
				local new_shape_num = order.shape_num
				-- if order to come is Rotate remove it
				if order.name=='Rotate' then
					prevO = self:RemoveOrder(1)
				end
				self:AddRegroup(order.from,order.from,1,order.angle,order.expand,order.shape_num,'strict')
				order = self.orders[1] 
			end
			-- add Rotate if needed
			if prevO then
				--Echo( prevO and ('before #'..prevO['#']..' '..prevO.name..' ==> #'..order['#']..' '..order.name) or ('#'..order['#']..' '..order.name)
				     --, 'angle diff:'..abs(turnbest(prevO.angle-order.angle))--[[,'vs',abs(turnbest(self.gAngle-order.angle))--]])
			end
			-- insert a rotate if the order to come appear to have enough of a difference in angle with the previous order
			if AUTOROTATE and not order.attaching then
				if not (prevO or order.rotated) and abs(turnbest(self.gAngle-order.angle))>ROT_TOL
				or prevO and prevO.name~='Regroup' and abs(turnbest(prevO.angle-order.angle))>ROT_TOL then
					--if prevO then Echo('insert Rotate before #',order['#'], order.name) end
					--Echo('insert Rotate with angle:'..order.angle)
				--if order.name=='Move' and not order.rotated then
					--if prevO then Echo("> ",prevO.name, abs(turnbest(prevO.angle-order.angle))) end
					local tol = order.strict and 0.01 or ROT_TOL
					--if abs(turnbest(order.angle-self.gAngle))>tol then
						order.shapeshift=false
						order.rotated=true
						self:AddRotate(order.from,1,order.angle,order.expand,order.strict,order.shape_num,false)
						order = self.orders[1]
					--end
				end
			end
			-- Echo('--- '..order.name..' --- '..(order.strict and 'strict' or ''))
			-- Echo(prevO and ('#'..prevO['#']..' '..prevO.name..',('..prevO.angle..') ==> #'..order['#']..' '..order.name..',('..order.angle..')') or ('#'..order['#']..' '..order.name..'('..order.angle..')'))
			-- execute order
			if not ORDERS[order.name](order) then
				-- Echo('#'..order['#']..' '..order.name..' useless, aborted.')
				for i,order in ipairs(orders) do order.n=i order['#']=order['#']-1 end
				return self:GiveNextOrder()
			else
				-- Echo('order ',order['#'],'accomplished')
			end
			self:OrderReset()
			self.at=order.n
			self.status = order.name
			local allorders = order.cmds
			self:GiveBestSpeeds()
			-- self.ETA_threshold = max(self.ETA*0.1,3)
			local lowest_speed=1000000
			for defid, t in pairs(self.uTypes) do
				if t.speed<lowest_speed then lowest_speed=t.speed end
			end
			self.ETA_threshold=(1/lowest_speed)*100

			self.check_eta = 1
			for unit,orderArray in pairs(allorders) do
				--unit:UpdateSpeed(speed or {orderArray.speed},self.gameframe)
				--Spring.GiveOrderArrayToUnitArray({unit.id},{unpack(orderArray)})
				local lasti=1
				local oArray={}
				for i,order in ipairs(orderArray) do
					unit.uMoves:Add(order[2])
					-- Spring.GiveOrderToUnit(unit.id,unpack(order))
					-- Echo("add order ",unpack(order[2]))
					lasti=i
				end
				-- remove and put back bad params contained in orderArray
				local keys={}
				for k,v in pairs(orderArray) do	if type(k)=='string' then keys[k]=v orderArray[k]=nil end	end
				Spring.GiveOrderArrayToUnitArray({unit.id},orderArray)
				for k,v in pairs(keys) do orderArray[k]=v end
				unit.goal = orderArray[lasti][2]
					--Echo(unit.id,'got '..#unit.uMoves..' moves')
			end
		end
		local function isStuck(unit)
			local md = Spring.GetUnitMoveTypeData(unit.id)
			local curSpeed = round(md.currentSpeed)+0.1
			local ownWantedSpeed = round(unit.wantedSpeed[1])+0.1
			local pathing = (md.currwaypointx~=md.goalx or md.currwaypointz~=md.goalz) and 'contourning' or 'straight'
			return pathing=='contourning' and curSpeed/ownWantedSpeed<0.5
		end
		function FORMATION:CheckProgression(gt_delta) -- remove order when an unit seems to be stuck by ETA check
			if gt_delta==0 then return end
			self.ETA=self.ETA-gt_delta
			local ETA = self.ETA
			self.check_eta = self.check_eta-gt_delta
			local order = self.orders[1]
			local last_order = not self.orders[2]
			local nextO = self.orders[2]
			--[[if order.name=='Rotate' then
				Echo('turn:'..abs(turnbest(order.angle-self.gAngle)))
			end--]]
			--[[if order.name=='Rotate' and nextO then
				if abs(turnbest(nextO.angle-order.angle))>0.3 then return end
			end--]]
			-- Echo("gametime is ", gametime)
			-- if Spring.GetGameFrame()%30==0 then Echo("ETA is ", ETA) end

			-- Echo("-------------")
			local id,unit = next(self.allIDs)
			-- local md = Spring.GetUnitMoveTypeData(id)
			-- for k,v in pairs(md) do
			-- 	Echo(k,v)
			-- end
			if order.strict then
				if ETA<0.3 then
					--Echo('done by ETA<0.3',order.name)
					self:GiveNextOrder()
				end
			elseif last_order  then 
				if ETA<-1 then
					--Echo('done by ETA<-1',order.name) 
					self:EndOrders()
				end
			--[[elseif ETA<self.ETA_threshold then
				self.ETA_threshold = max(self.ETA_threshold -0.2,0.5)
				Echo('done by ETA<'..self.ETA_threshold,order.name) 
				self:GiveNextOrder()--]]
			elseif ETA<self.ETA_threshold then
				-- self.ETA_threshold = max(self.ETA_threshold -0.2,0.5)
				--Echo('done by ETA<threshold=='..self.ETA_threshold,order.name) 
				self:GiveNextOrder()
			elseif self.check_eta <0 then
				self.check_eta=1
				 -- pick up the ETA of units with the current wanted speed, to find out if there are some units in late
				local time_table = self:GetTimeTable('withWanted')
				local has_removed = false
				for unit,time_needed in pairs(time_table.wantedSpeed) do
					-- if unit.last_dist_to_goal then
					-- Echo("unit.dist is ", unit.dist_to_goal,unit.speed)
					-- maybe a problem with ETA to look into (getting way too high number with wanted speed sometime, but it might be explainable), but so far it works well
					--if time_needed>self.ETA+1 then Echo('ETA:'..self.ETA,'time_needed:'..time_needed-self.ETA) end
					unit.stuck = isStuck(unit) and unit.stuck+1 or 0
					if time_needed>self.ETA+0.5 or unit.stuck>0 then
						local cmd,_,tag = Spring.GetUnitCurrentCommand(unit.id)
						if cmd then
							if cmd and (not last_order or order.cmds[unit].n>1) then
								Debug.At(unit.id..' took too long,removed order, stuck?',unit.stuck)
								local tx,ty,tz = spGetUnitPosition(unit.id)
								Circles['toolong'..unit.id]={tx,ty,tz,50,colors.red}
								-- Echo("Order removed ",tag)
								spGiveOrderToUnit(unit.id,CMD.REMOVE,tag,CMD.OPT_ALT)

								self.update_unit_at[unit]=true
								self.update_units_at=2
								self.update_speeds=1
								unit.ignore_time=true
								--time_table.wantedSpeed[unit]=nil
								--time_table.speed[unit]=nil
								unit:UpdateSpeed(NORMAL_SPEED,self.gameframe)
								--order.cmds[unit]=nil
								has_removed = true
							end
						end
					else
						if unit.ignore_time then
							unit.ignore_time=false
						end
						if Circles['toolong'..unit.id] then
							Circles['toolong'..unit.id]=nil
						end
					end
				end
			end
		end

	---------------------------------------------------------------------------
	---------------------------- Order Creation -------------------------------
	---------------------------------------------------------------------------


		function FORMATION:AddSimpleMove(from,to,at,shape_num)
			shape_num = shape_num or self.shape_num
			local orders = self.orders
			---
			local shapeshift,from
			local previous = orders[at-1]
			local last_shape_num = previous and previous.shape_num or self.moving_shape_num
			if last_shape_num~=shape_num then shapeshift=true end
			if previous then from = previous.to else from = self.ghost_center end
			---
			local num
			orders['#']=orders['#']+1
			if orders[at] then
				num = orders[at]['#']
				for i=at,orders.n do
					local order= orders[i]
					order['#']=order['#']+1
				end
			else
				num = orders['#']
			end
			--
			local main_order = {   name='SimpleMove'
								  ,n=at,nsub=1,at=0
								  ,['#']=num


								  ,from={unpack(from)}
								  ,to={unpack(to)}


		 						  ,dirx=self.dirx,dirz=self.dirz
		 						  ,f=self
								  ,angle=self.angle
								  ,turn_offset=self.turn_offset
								  ,speed={NORMAL_SPEED}
								  ,expand=self.expand
								  ,cmds={},cmd=CMD_MOVE
								  ,shape_num=shape_num
								  ,shapeshift=shapeshift		}
			self.last_center={unpack(from)}
			self.shift_center={unpack(to)}
			table.insert(orders,at,main_order)
			local n = orders.n+1
			if at<n then for i=at+1,n do orders[i].n=i end end
			orders.n=n
			--local str = ''	for i=1,orders.n do if orders[i] then str=str..'|'..i end end
			--Echo('added simple move at',at,str)
			self.move_angle = self.angle
			return at+1
		end

		function FORMATION:AddMoveRotate(from,to,at,start_angle,end_angle,expand,strict,shape_num)
			shape_num = shape_num or self.shape_num
			--Echo('move-rotate from angle',start_angle,'to',end_angle)
			at = self:AddMove(from,to,at,start_angle,expand,strict,shape_num)
			self:AddRotate(to,at,end_angle,expand,strict,shape_num)
		end

		function FORMATION:AddMove(from,to,at,angle,expand,strict,shape_num,cmd)
			local orders = self.orders
			shape_num = shape_num or self.shape_num
			self.maintain_speeds=2-- the speed orders are resetted when user click for a new move, we maintain it
			if not self.attached then
				self:AddRegroup(from,from,at,angle,expand,shape_num)
				self:SetGhostFormation()
				self:AttachUnits() self:AttachUnits('m')  self.attached=true
				self.orders[at].attaching=true
				self.last_center=from
				self.shift_center=to
				at=at+1
			end
			---

			--
			----
			local shapeshift,from
			local previous = orders[at-1]

			local last_shape_num = previous and previous.shape_num or self.moving_shape_num
			if last_shape_num~=shape_num then shapeshift=true end

			if previous and previous.name=='Rotate' and previous.strict then
				self:RemoveOrder(previous.n)
				at=at-1
				orders['#']=orders['#']-1
				previous=orders[at-1]
			end
			if previous then
				from = previous.to
			else
				from = self.ghost_center
			end
			-----
			--self:Translate(self.shift_center,goal)
			from = {unpack(from)}
			to = {unpack(to)}

			self.last_center=from
			self.shift_center=to
			local function add(from,to,at,strict)
				local num
				orders['#']=orders['#']+1
				if orders[at] then
					num = orders[at]['#']
					for i=at,orders.n do
						local order= orders[i]
						order['#']=order['#']+1
					end
				else
					num = orders['#']
				end


				local main_order = {   name='Move'
									  ,n=at,nsub=1,at=0
								  	  ,['#']=num

									  ,from=from
									  ,to=to

			 						  ,dirx=self.dirx,dirz=self.dirz
			 						  ,f=self
									  ,speed={self.speed}
									  ,cmds={},cmd=not cmd and CMD_MOVE or cmd
									  ,angle=angle or self.angle
									  ,turn_offset=self.turn_offset
									  ,expand=expand
									  ,shape_num=shape_num
									  ,shapeshift=shapeshift
									  ,strict=strict		}
				table.insert(orders,at,main_order)
				local n = orders.n+1

				if at<n then for i=at+1,n do orders[i].n=i end end
				orders.n=n
			end
			-- create a trail of point with given step as separation
			-- , strict=true: place only points that are on step
			-- else adapt the steps depending on the total length, therefore endtrail will match the endpoint given, unless a maxstep prevent it

			local trail,n = MakeTrail(from,to,80)
			for t=1,n-1 do
				if trail[t+1] then
					local strict = strict and (t==1 or not trail[t+2])
					add(trail[t],trail[t+1],at,strict)
					--Texts[#Texts+1]={{'from:'..orders.n+1,0,0,12,'h'},pos=trail[t]}
					--Texts[#Texts+1]={{'           to:'..orders.n+1,0,0,12,'h'},pos=trail[t+1]}
					--Echo('Move at'..at,'n:'..orders.n)
					at=at+1
					from = trail[t+1]
				end
				shapeshift=nil
			end

			--local str = ''	for i=1,orders.n do if orders[i] then str=str..'|'..i end end
			--Echo('added move at',at,str)
			self.move_angle = self.angle
			--if not self.moving then self:GiveNextOrder() end
			return at
		end


		function FORMATION:AddRotate(center,at,angle,expand,strict,shape_num,isUser) -- prepare rotate orders 
			shape_num = shape_num or self.shape_num

			local orders = self.orders
			----
			local shapeshift,from
			local previous = orders[at-1]
			local last_shape_num = previous and previous.shape_num or self.moving_shape_num
			if last_shape_num~=shape_num then shapeshift=true end
			if previous then from = previous.to else from = self.ghost_center end
			local from, to = {unpack(center)}, {unpack(center)}
			----
			---
			local num
			orders['#']=orders['#']+1
			if orders[at] then
				num = orders[at]['#']
				for i=at,orders.n do
					local order= orders[i]
					order['#']=order['#']+1
				end
			else
				num = orders['#']
			end
			--
			local main_order = {   name='Rotate'
								  ,['#']=num
								  ,angles={}
								  ,turn_offset=self.turn_offset
								  ,angle=angle
								  ,strict=strict
								  ,n=at,nsub=0,at=0
								  ,f=self
								  ,cmds={},cmd=CMD_MOVE

								  ,center={unpack(center)}
								  ,from=from
								  ,to=to

								  ,expand=expand
								  ,shape_num=shape_num
								  ,shapeshift=shapeshift		
								  ,isUser=isUser}

			--self.shift_center={unpack(center)}

			table.insert(orders,at,main_order)
			local n = orders.n+1
			if at<n then for i=at+1,n do orders[i].n=i end end
			--Texts[#Texts+1]={{'from:'..orders.n+1,0,0,12,'h'},pos=from}
			orders.n=n
			--local str = ''	for i=1,orders.n do if orders[i] then str=str..'|'..i end end
			--Echo('added rotate at',at,str)

			self.move_angle = angle
			return at+1
		end


		function FORMATION:AddRegroup(from,to,at,angle,expand,shape_num)
			shape_num = shape_num or self.shape_num
			local orders = self.orders
			---
			local shapeshift,from
			local previous = orders[at-1]
			local last_shape_num = previous and previous.shape_num or self.moving_shape_num
			if last_shape_num~=shape_num then shapeshift=true end
			if previous then from = previous.to else from = self.ghost_center end

			---
			local num
			orders['#']=orders['#']+1
			if orders[at] then
				num = orders[at]['#']
				for i=at,orders.n do
					local order= orders[i]
					order['#']=order['#']+1
				end
			else
				num = orders['#']
			end
			--
			angle = angle or self.angle
			local main_order = {   name='Regroup'
								  ,['#']=num

								  ,from={unpack(from)}
								  ,to={unpack(to)}

								  ,speed=NORMAL_SPEED
								  ,dirx=self.dirx,dirz=self.dirz -- note: not needed but would be wrong in case of move-rotate or insert I guess
								  ,n=at,nsub=1,at=0
							  	  ,f=self
								  ,cmds={}
								  ,cmd=CMD_MOVE
								  ,angle=angle
								  ,turn_offset=self.turn_offset
								  ,expand=expand
								  ,shape_num=shape_num
								  ,shapeshift=shapeshift		}

			--self.shift_center={unpack(to)}
			self.last_center={unpack(from)}
			table.insert(orders,at,main_order)
			local n = orders.n+1
			if at<n then for i=at+1,n do orders[i].n=i end end
			orders.n=n
			--local str = ''	for i=1,orders.n do if orders[i] then str=str..'|'..i end end
			--Echo('added regroup at',at,str)

			self.move_angle = angle
			return at+1
		end

	---------------------------------------------------------------------------
	---------------------------- Execute order --------------------------------
	---------------------------------------------------------------------------

		function UNIT:AddOrder(params,rot,formation_cmds) -- add order to unit when deploying main planned order
			local id = self.id
			local Array = formation_cmds[self]
			local x,y,z = unpack(params)
			local cmd = params.cmd
			local last_order = self.last_order
			local last = last_order and last_order[2] or {spGetUnitPosition(id)}
			if roughequal(last[1],x,17) and roughequal(last[3],z,17)  then
				self.compAngle=rot 
				-- Echo('last was '..(last_order and 'last_order' or 'unit pos'),last[1],last[3]..' vs '..x,z)
				return false
			end
			--
			if not Array then formation_cmds[self]={n=0,dist=0, angles={[0]=rot}}   Array=formation_cmds[self] end
			--
			Array.dist = Array.dist + ( (x-last[1])^2 + (z-last[3])^2 ) ^ 0.5
			Array.n=Array.n+1
			Array.angles[Array.n]=rot
			--Echo('#'..Array.n..' dist:'..( (x-last[1])^2 + (z-last[3])^2 ) ^ 0.5)
			--local order = {CMD_MOVE,params,CMD.OPT_SHIFT+OPTCODE}
			local order = {cmd or CMD_MOVE,params,OPTCODE+ (Array.n>1 and CMD.OPT_SHIFT or 0)}
			Array[Array.n]= order
			self.last_order = order
			--Echo('passed')
			--uMoves.n=uMoves.n+1
			return true
		end


		-- apply dist and angle according to mPoint set from ordered shape
		function FORMATION:MovePoint(gx,gz,point,rot,expand)
			local angle,dist = point.angle+rot, point.dist*expand
			local fx,fz = gx+sin(angle)*dist, gz+cos(angle)*dist
			--Points[#Points+1]={fx,spGetGroundHeight(fx,fz),fz,size=8,color=colors.red}
			return fx,spGetGroundHeight(fx,fz),fz
		end

		-- set point dists and angles according to the order's shape
		function FORMATION:ShapeShift(shape_num)
			-- update the current shape used for moving
			self.moving_shape_num=shape_num
			-- set moving point angle and dist reference according to current shape
			self:SetPoints('m')
			-- update ghost points with the new refs immediately
			self:SetGhostFormation('manual')
			-- reorder and attach moving point according to best dist referenced by ghost point
			self:AttachUnits('m')
	 		if not CONTROLS.shifted and not CONTROLS.inspect then 
				if C and  C.shape_num~=shape_num then
					C.shape_num=shape_num
					C:SetPoints()
				end
			end
		end

		function ORDERS:Rotate()

			local has_order = false
			local angle = self.f.gAngle
			local end_angle = self.angle
			--if roughequal(angle-angle,0,0.001) then Echo('returned') return end
			local rem_turn,s = turnbest(end_angle-angle)

			local tol = self.strict and 0.01 or self.isUser and MROT_TOL or ROT_TOL
			local from_angle = angle
			local f = self.f
			--self.from = {unpack(f.ghost_center)}
			local expand = self.expand
			local gx,_,gz = unpack(self.center)
			if self.shapeshift then f:ShapeShift(self.shape_num,angle) end
			--
			if rem_turn*s>tol then
				local cmd = self.cmd
				local cmds=self.cmds
				local angles = self.angles
				angles[1]=angle
				local nsub=0
				while rem_turn*s>0.01 do
					local new_turn = min(rem_turn*s,TURN)*s -- break up rotation by TURN (2*pi for full turn) or less for the last
					angle = new_turn+angle
					local need
					for id,unit in pairs(f.allIDs) do
						-- prepare self, update array of orders, don't register orders that are too close of their last move self/pos
						need = unit:AddOrder(   {at=nsub+1,name='rotate',cmd=CMD_MOVE,FORMATION:MovePoint(gx,gz,unit.mPoint,angle,expand)},angle,   cmds)
						    or need
					end
					rem_turn = rem_turn-new_turn
				
					if need then
						nsub = nsub+1
						--if angle*s>pi then angle = s*(pi - (angle*s)%pi) end

						angles[nsub+1] = angle
					end 
				end
				------------------------------------------------------------------------------------------------------------
				----  pre-set unit speed accordingly for them to arrive at same time in end of rotation
				--Echo('from '..from_angle..' to '..end_angle..', =>:'..turnbest(end_angle-from_angle),'Rotating?',nsub > 0	)
				if nsub > 0 then
					-- update the main order now it is confirmed
					self.nsub=nsub
					has_order = true
					self.f:SetScore()
				end
			end
			return has_order
		end


		function ORDERS:Move(goal)
			--Echo('order move')
			local f = self.f
			--Echo('move',self.shape_num)
			if self.shapeshift then f:ShapeShift(self.shape_num) end
			f:SetScore()
			self.from = {unpack(f.ghost_center)}
			local new
			local rot = self.angle
			local expand = self.expand
			local cmds = self.cmds
			local gx,gy,gz = unpack(self.to)
			for id,unit in pairs(f.allIDs) do
				new = unit:AddOrder(   {at=1,name='move',cmd=self.cmd or CMD_MOVE,FORMATION:MovePoint(gx,gz,unit.mPoint,rot,expand)},rot,    cmds)
				    or new
			end
			return new	
		end

		function ORDERS:SimpleMove()
			local f = self.f
			self.from = {unpack(f.ghost_center)}
			if self.shapeshift then f:ShapeShift(self.shape_num) end
			local new
			local cmds = self.cmds
			local rot = self.angle
			local gx,gy,gz = unpack(self.to)
			for id,unit in pairs(f.allIDs) do
				new = unit:AddOrder(   {at=1,name='simpleMove',cmd=CMD_MOVE,gx,gy,gz},rot,    cmds)
				    or new
			end
			return new	
		end


		function ORDERS:Regroup()
			local f = self.f
			self.from = {unpack(f.ghost_center)}
			if self.shapeshift then f:ShapeShift(self.shape_num) end
			f:SetScore()
			local new
			local rot = self.angle
			local expand = self.expand
			local cmds = self.cmds
			local gx,_,gz = unpack(self.to)

			for id,unit in pairs(f.allIDs) do
				new = unit:AddOrder(    {at=1,name='regroup',cmd=CMD_MOVE,FORMATION:MovePoint(gx,gz,unit.mPoint,rot,expand)}, rot,   cmds)
				   or new
			end

			return new
		end

		function FORMATION:Stop()
			self:EndOrders()
			self.shift_center = self.ghost_center
			Spring.GiveOrderToUnitMap(self.allIDs,CMD.STOP,0,0)
		end

	--------------------------------------------------------------------------
	--------------------------- Inits and resets -----------------------------
	--------------------------------------------------------------------------

		function FORMATION:InitOrders()
			-- Debug('----------init-----------')
			-- Echo('init')
			--local order = self.orders[1]
			self.moving=true
			self:Activate()
			--self.rotating=false
			--self.status=order.name
			--self.at=order.n
			self.gametime=spGetGameSeconds()
			self.gameframe = Spring.GetGameFrame()
			self.ETA_threshold=0
			self.update_speeds=2
			Spring.LoadCmdColorsConfig("alwaysDrawQueue 0")
			if dontDrawCommands then PreventDrawCmds(self.allIDs) end
			self:OrderReset()
			self.update_ghost=true

		end

		function FORMATION:EndOrders()
			while table.remove(self.orders,1) do  end
			for id,unit in pairs(self.allIDs) do unit:Reset() end
			Spring.GiveOrderToUnitMap(self.allIDs,CMD_WANTED_SPEED,NORMAL_SPEED,0) 
			self.moving=false
			-- self.update_ghost=false
			self.update_order=false
			self.orders.n=0
			self.at=0
			self.orders['#']=0
			self.status='no order'
			self.orders.done=0
			if dontDrawCommands then AllowDrawCmds(self.allIDs,self.size) end
			self.ETA_threshold=0
			self.update_speeds=false

			self:OrderReset()
			-- Debug('---------------no more orders----------------')
			-- Echo("no more orders")
		end

		function FORMATION:OrderReset() -- at each new formation order, reset 'at' of uMoves and few other things...
			self.onTheMove=0
			self.ETA=0
			self.check_eta = 0
			self.update_units_at=false
			self.update_unit_at={}
			for id,unit in pairs(self.allIDs) do unit:Reset() end
			local order = self.orders[1]
			if order then
				local unitsAt={}
				for i=1,order.nsub do unitsAt[i]=0 end
				order.unitsAt = unitsAt
			end
		end

		function UNIT:Delete() -- destroying anything that is needed to be detroyed instantly -- the whole formation will get updated on a delay
			local f = self.f
			if f.moving then
				f.update_order=1
				f.update_unit_at[self]=nil
				f.update_units_at=2
				if self.uMoves[1] then f.onTheMove=f.onTheMove-1 end
				for i,order in ipairs(f.orders) do
					local cmds = order.cmds
					cmds[self]=nil
				end
			end
		end

		function UNIT:Reset()
			self.stuck=0
			self.uMoves:Reset()
			self.goal=false 
			self.resent=false
			self.ignore_time=false
			self.wantedSpeed=NORMAL_SPEED
			self.compAngle=self.f.gAngle
		end

	---------------------------------------------------------------------------
	------------------------------ Tracking -----------------------------------
	---------------------------------------------------------------------------

		----------------- MOVEMAP Module  -------------------

			function MOVEMAP:New(f,id)
				return setmetatable({n=0,f=f, id=id, at=0,status='no order',total=0,completed=0, last_move=false, map={}}, {__index=MOVEMAP} )
			end

			function MOVEMAP:Reset()
				while self:Remove() do end
				self.status,self.at,self.total,self.completed,self.ETA='no order',0,0,0,0
			end

			function MOVEMAP:Add(t)
				local x,y,z = unpack(t)
				self.n=self.n+1
				self[self.n]=t
				self.map[x] = self.map[x] or {}
				self.map[x][z] = t
				self.total=self.total+1

			end

			function MOVEMAP:Remove()
				if not self[1] then return end
				self.completed = self.completed+1
				local cur = table.remove(self,1)
				self.last_move = cur
				local cx,_,cz = unpack(cur)
				self.map[cx][cz]  = nil
				if not next(self.map[cx]) then self.map[cx]=nil end
				self.n=self.n-1
				return self[1]
			end

			function MOVEMAP:GetByCoord(x,z)
				local found = self.map[x] and self.map[x][z]
				--Debug.At(found and 'found '..found.at..', '..found.name or 'not found')
				return found, found and found.at~=self.at
			end

			function MOVEMAP:GetStatus()
				local at,at_s,at_move
				local cmd,_,tag,x,y,z = Spring.GetUnitCurrentCommand(self.id)
				-- Echo("current command: "..(cmd or 'no cmd'),x,y,z,'TAG',tag)
				if not cmd then
					if self[1] then 
						at,at_s = self[1].at,'no order'
						--Echo('got move but no order',at)
					else
						at,at_s = 0,'no move'
						--Echo('no order, no move',at)
					end
				elseif not (cmd==CMD_MOVE or cmd==CMD_RAW_MOVE or cmd==CMD_FIGHT) then
					at,at_s = self.at, 'other order'
					--Echo('other order',at)
				else
					at_move = self:GetByCoord(x,z)
					if at_move then
						at,at_s = at_move.at,at_move.name
						--Echo('has order, at move',at)
					else
						at,at_s = self.at,'not at move'
						--Echo('has order, not at move',at)
					end
				end
				return at, at_s, self.at, self.status, at_move
			end

		--------------- Update and decide -------------------

			function widget:UnitCmdDone(id, defid, teamID, cmd, params, cmdOptions, cmdTag, fromSynced, fromLua)
				if teamID~=myTeamID then return end
				if not (cmd==CMD_MOVE or cmd==CMD_RAW_MOVE or CMD_FIGHT) then return end
				local unit = ACTIVEIDS[id]
				if not (unit and unit.f.moving and unit.uMoves[1]) then return end
				-- Echo('cmd done : '..cmd,unpack(params))
				unit:UpdateAt()
			end


			function FORMATION:UpdateAllUnitsAt()
				local order = self.orders[1]
				local unitsAt=order.unitsAt
				for id,unit in pairs(self.allIDs) do
					local uMoves=unit.uMoves
					if uMoves.at==0 then
						unit:UpdateAt()
					end
				end
				for at,n in ipairs(unitsAt) do if n>0 then order.at=at break end end
				if order.at==0 then self.update_order=5 end
			end


			function FORMATION:UpdateUnitsAt()
				for unit in pairs(self.update_unit_at) do
					unit:UpdateAt()
				end
			end

			function UNIT:UpdateAt(forced)
				--Echo('update at')
				local uMoves = self.uMoves
				local move = uMoves[1]
				if not move then return end
				local f =self.f
				local order = f.orders[1]
				local cmds = order.cmds
				local unitsAt = order.unitsAt
				local send_next = false
				local at,at_s,from,from_s,at_move = uMoves:GetStatus()
				--if move and at_move then Echo("move.at,at_move.at is ", move.at,at_move.at) end
				if at_move and move~=at_move then
					while uMoves[1]~=at_move do
						uMoves:Remove() table.remove(cmds[self],1) cmds[self].n = cmds[self].n-1 -- destroy the orders stocked in main order also, to get accurate speed adjustment by distance in CheckProgression
					end
				end
				--Echo("at,at_s,from,from_s,at_move is ", at,at_s,from,from_s,at_move)
				--Debug(self.id, Units[self.id].name..' is now at '..at_s..' '..at..'('..uMoves.completed..'/'..uMoves.total..' (rem:'..#uMoves..') from: ' ..from_s..'('..from..'), on the move:'..f.onTheMove)

				-- Echo('normal:'..Spring.GetUnitMoveTypeData(self.id).progressState)
				-- for k,v in pairs(Spring.GetUnitMoveTypeData(self.id)) do Echo(k,v) end
				if at_s=='no order' and move then
					if uMoves.completed==uMoves.total-1 then
						local goal = self.goal
						local pos={spGetUnitPosition(self.id)}
						--Page(Spring.GetUnitMoveTypeData(self.id))
						self.pos=pos
						if not self.resent and not (roughequal(pos[1],goal[1],17) and roughequal(pos[3],goal[3],17)) then
							--local moveData = Spring.GetUnitMoveTypeData(self.id)
							--Echo("moveData.progressState is ", moveData.progressState)
							-- Echo('resent',os.clock())
							spGiveOrderToUnit(self.id,CMD_MOVE,goal,OPTCODE)
							f.update_unit_at[self]=true
							f.update_units_at=2
							self.resent=true
							--f.update_order=2
							return
						end
						uMoves:Remove() table.remove(cmds[self],1) cmds[self].n = cmds[self].n-1
						f.onTheMove = f.onTheMove-1
						at_s='arrived'
						-- everyone is arrived
						if f.onTheMove==0 then send_next=true end
					else
						--Echo(self.id,'got no order, completed '..uMoves.completed..'/'..uMoves.total..', at:'..at)
						--uMoves:Remove()
						--spGiveOrderToUnit(self.id,CMD_MOVE,uMoves[1],CMD.OPT_SHIFT+OPTCODE)
						--at,at_s=uMoves[1].at,uMoves[1].name
						--Echo('resent')
					end
					self.compAngle = cmds[self].angles[uMoves.completed]
				elseif at~=from then
					if from == 0 then f.onTheMove=f.onTheMove+1 end
					if from > 0 then unitsAt[from] = unitsAt[from]-1 end
					if not unitsAt[at] then Echo('NO UNITS AT '.. at) Page(unitsAt) end
					unitsAt[at] = unitsAt[at] + 1
					self.compAngle = cmds[self].angles[uMoves.completed]
					if order.nsub>1 then f.update_move_angle = true end
				end
				uMoves.at,uMoves.status = at,at_s
				--self.compAngle = self.angles[uMoves.completed]

				--Debug(self.id, Units[self.id].name..' is now at '..at_s..' '..at..'('..uMoves.completed..'/'..uMoves.total..' (rem:'..#uMoves..') from: ' ..from_s..'('..from..'), on the move:'..f.onTheMove)
				-- this could be directly in place of 'send_next' 7 lines above but I want to see the debug in the right order
				if send_next then
					f:GiveNextOrder()
					if order.name=='move' and not self.resent then
					 	f.ETA_threshold=f.ETA+0.2 Echo('new threshold:'..f.ETA+0.2)
					end
				end
			end

	---------------------------------------------------------------------------
	--------------------------- Speed Management ------------------------------
	---------------------------------------------------------------------------

		function FORMATION:GetTimeTable(withWanted)
			self:UpdatePoses()
			local order = self.orders[1]
			local allorders = order.cmds
			local max_time,max_time_withWanted = 0,0
			local time_table={speed={},wantedSpeed={}}
			for unit,uOrders in pairs(allorders) do
				-- measure time it will take for a unit to arrive at goal with full speed
				-- set the maximum time taking account the different unit maxspeed
				local dist = 0
				local px,_,pz = unpack(unit.pos)
				for i,order in ipairs(uOrders) do
					local goal = order[2]
					dist = dist + ( (px-goal[1])^2 + (pz-goal[3])^2) ^0.5
					px,pz = goal[1],goal[3]
				end
				unit.dist_to_goal = dist
				local time_needed = dist/unit.speed
				if not unit.ignore_time then
					max_time = max(max_time, time_needed)
				end
				time_table.speed[unit]=time_needed
				--  do the same with actual wanted speed of unit
				if withWanted then 
					local time_needed_withWanted = dist/max(unit.wantedSpeed[1],1)
					max_time_withWanted = max(max_time_withWanted, time_needed_withWanted)
					time_table.wantedSpeed[unit]=time_needed_withWanted
				end
			end
			return time_table, max_time, max_time_withWanted
		end


		function FORMATION:GiveBestSpeeds(time_table,time_wanted) -- give best speeds in order for units to arrive at the same time
			if not time_table then
				time_table,max_time = self:GetTimeTable()
			end
			local table_speed = time_table.speed
			for id,unit in pairs(self.allIDs) do
				local time_needed = table_speed[unit]
				local mod_speed = max_time>0 and time_needed and {max(time_needed/max_time * unit.speed,5)} or NORMAL_SPEED
				unit:UpdateSpeed(mod_speed,self.gameframe)
			end
			self.ETA = max_time
			return max_time
		end

		function FORMATION:UpdateAllSpeeds(speed)
			for id,unit in pairs(self.allIDs) do
				unit:UpdateSpeed(speed,self.gameframe)
			end
		end

		do
			local spGetUnitMoveTypeData = Spring.GetUnitMoveTypeData
			function UNIT:UpdateSpeed(speed,gf)
				if speed then self.wantedSpeed=speed end
				local id = self.id
				speed = self.wantedSpeed
				local moveData = spGetUnitMoveTypeData(id)
				local D_maxWantedSpeed = moveData.maxWantedSpeed
				local D_wantedSpeed = moveData.wantedSpeed
				-- Echo("D_wantedSpeed,D_maxWantedSpeed is ", D_wantedSpeed,D_maxWantedSpeed)
				--Page()
				if not roughequal(D_maxWantedSpeed,speed[1],5) then
					spGiveOrderToUnit(id, CMD_WANTED_SPEED, speed, 0)
					--Debug(self.id, Units[id].name..' set speed to '..speed[1]..' (WS:'..D_wantedSpeed..' maxWS:'..D_maxWantedSpeed..')')
				else
					--Debug(self.id, Units[id].name..' is already at '..D_maxWantedSpeed)
				end
			end
		end

------------------------------------------------------------------------------------
------------------------------------------------------------------------------------
-------------------------------- MAIN UPDATE ---------------------------------------
------------------------------------------------------------------------------------
------------------------------------------------------------------------------------

	----------------------------------------------------------------------------
	-------------------------- Update Routines ---------------------------------
	----------------------------------------------------------------------------

		function widget:Update(delta)

			DELAY_REMOVE:CheckTime(delta)
			FORMATION:UpdateActivesFormations(delta)
			local alt, ctrl, meta, shift = Spring.GetModKeyState()
			local mx,my,lClick,_,rClick = spGetMouseState()
			CONTROLS:Update('Mouse',delta)
			if C then
			 	if CONTROLS.rot then 
			 		CONTROLS.rot = CONTROLS.rot-delta
			 	end
				if CONTROLS.newmove or C.update_angle then
					C.update_angle=false
			 		if CONTROLS.rot and CONTROLS.rot<0 then 
						C:AddRotate(C.ghost_center,C.orders.n+1,C.angle,C.expand,'strict')
			 			C:GiveNextOrder('manual')
			 			-- activate rotation repeat with given period
			 			CONTROLS.rot=0.5
			 			--
			 		end
					local mouse = C.mouse_center
					mouse[1],mouse[2],mouse[3] = UniTraceScreenRay(mx,my)

			 		if CONTROLS.inspect then
			 			if not CONTROLS.clickedOrder then
			 			-- Set distance from spotted order
			 				C:SpotOrder(mouse[1],mouse[3])
 							local order=CONTROLS.spottedOrder
 							if order then
								CONTROLS.distSpotted = ( (order.from[1]-CONTROLS.px)^2 + (order.from[3]-CONTROLS.pz)^2 ) ^ 0.5
							end
						else
						-- move or rotate spotted order
							local order=CONTROLS.spottedOrder
							local orders=C.orders
							local prevO,nextO = orders[order.n-1],orders[order.n+1]
							
							if order and order.n>1 then
								local from = order.from
								if CONTROLS.movingSpotted then
									from[1],from[2],from[3]=CONTROLS.px,CONTROLS.py,CONTROLS.pz
									function adaptangle(order)
										if order.name=='Move' then
											local newangle = atan2(order.to[1]-order.from[1],order.to[3]-order.from[3])
											if order.ori_angle then
												local add=newangle-order.ori_angle
												order.ori_angle = newangle
												order.angle=clampangle(order.angle+add)
											else
												order.angle=newangle
											end
										end
									end
									if prevO.n>1 then
										prevO.to=from
										adaptangle(prevO)
									end
									adaptangle(order)
									C.angle=order.angle
									--order.angle=atan2(order.to[1]-from[1],order.to[3]-from[3])
								elseif CONTROLS.rotateSpotted then
									local angle=order.angle
									local diff_angle = atan2(CONTROLS.px-from[1],CONTROLS.pz-from[3])-angle
									if not order.ori_angle then order.ori_angle=angle end
									order.mark_mod_angle=true

									--Echo("diff_angle:"..diff_angle,'real:'..atan2(CONTROLS.px-from[1],CONTROLS.pz-from[3]),'ori:'..order.angle,'add:'..clampangle(diff_angle),'=> '..order.angle+diff_angle)
									--order.angle=atan2(CONTROLS.px-from[1],CONTROLS.pz-from[3])--atan2(CONTROLS.px-from[1],CONTROLS.pz-from[3])
									order.angle=clampangle(order.angle+diff_angle)
									C.angle=order.angle
									if orders.n>order.n then
										for i=order.n+1,orders.n do
											local order=orders[i]
											if order.mark_mod_angle then break end
											if not order.ori_angle then order.ori_angle=angle end
											order.angle=clampangle(order.angle+diff_angle)
										end
										--Echo("clampangle is ", clampangle)
									end
								end
							end
						end
			 		end

					if CONTROLS.lock_angle or CONTROLS.spottedOrder then
						C:UpdatePoints()
					else
						C:SetAngle(C.aim_center,mouse)
					end
					if C.update_ghost then C:SetGhostFormation() end
				end
				last_mx,last_my = mx,my
			end
	 		if ctrl and ACTIVES.n>0 then
				local x,y,z = UniTraceScreenRay(mx,my)
				local bestdist = 500
				local spotted
				for i,f in ipairs(ACTIVES) do
					if f~=C then
						f.spotted=false
						local spot
						spot = f.ghost_center
						local dist = ((spot[1]-x)^2 + (spot[3]-z)^2)^0.5
						if dist<bestdist then spotted,bestdist = i,dist end
					end
				end
				if spotted then ACTIVES[spotted].spotted=true ACTIVES.spotted=ACTIVES[spotted] end
			elseif ACTIVES.spotted then
				ACTIVES.spotted.spotted=false
				ACTIVES.spotted=nil
			end
		end


		function FORMATION:UpdateActivesFormations(delta)
			if ACTIVES.n>0  then
				local gametime = spGetGameSeconds()
				local gameframe = Spring.GetGameFrame()
				for i,f in ipairs(ACTIVES) do
					local gt_delta = gametime-f.gametime
					local gf_delta = (gameframe - f.gameframe) 
			--Echo("Spring.GetGameSpeed() is ", Spring.GetGameSpeed())
					local rem_pending = f.rem_pending
					f.gametime = gametime
					f.gameframe= gameframe
					if f.moving then
						f:CheckProgression(gt_delta)
						if f.update_units_at then
							f.update_units_at=f.update_units_at-1
							if f.update_units_at==0 then
								f:UpdateUnitsAt()
								f.update_units_at=false
							end
						end
						if f.update_speeds then
							f.update_speeds=f.update_speeds-gt_delta
							if f.update_speeds<0 then
								f.update_speeds=1
								f:GiveBestSpeeds()
							end
						end

						if f.maintain_speeds then
							f.maintain_speeds=f.maintain_speeds-1
							if f.maintain_speeds==0 then
								f.maintain_speeds=false
								f:UpdateAllSpeeds()
							end
						end

						if f.update_order then
							f.update_order=f.update_order-1
							if f.update_order==0 then
								f.update_order=false
								f:UpdateAllUnitsAt('init')
							end
						end

					end
					if f~=C and f.update_ghost then f:SetGhostFormation() end
				end
			end
		end

	----------------------------------------------------------------------------
	--------------------------- Units Removal ----------------------------------
	----------------------------------------------------------------------------

		-- unused meta function for unit deleted
			--[[
				function UNIT:Deleted(unit,id) -- this is a checkpoint before going to the real methods
					unit.deleted = not Spring.ValidUnitID(id) or Spring.GetUnitIsDead(id)
					return unit.deleted
				end
			--]]

		function widget:UnitDestroyed(id, defid, team)
			if team~=myTeamID then return end
			if ACTIVEIDS[id] then
				local unit = ACTIVEIDS[id]
				DELAY_REMOVE:Add(id,defid,unit)
				ACTIVEIDS[id]=nil
				unit.f.allIDs[id]=nil
				unit:Delete()
				if currentSel[id] then currentSel[id],currentSel.n = nil,currentSel.n-1 end
			end
			-- in case the unit belong (also) to a project aka not beeing ordered yet
			if C and C.allIDs[id] and not C.active then 
				DELAY_REMOVE:Add(id,defid,C.allIDs[id])
				C.allIDs[id]=nil
			 	currentSel[id],currentSel.n = nil,currentSel.n-1
			end
		end



		function FORMATION:ReplaceUnitType(defid,ids)
			local uType,allIDs=self.uTypes[defid],self.allIDs

			-- replace directly the new tables
			  uType.ids, uType.byID, uType.poses, uType.points, uType.moves, uType.gPoints, uType.mPoints, uType.units
			=    ids,       self:MakeUnits(defid,ids,uType,allIDs,   {},{},{},{},{},{},{})
			-- update the previous values
			local n = #ids
			self.size=self.size-uType.n+n
			uType.n = n
			local area = area(uType.sq_r*n)
			uType.area = area
			local diff = area - uType.area
			self.area = self.area + diff
			-- remake layers composition
			self:UpdatePoses(self.aim_center)
			self:SetLayers()
			self:PopulateLayers()	
		end

		function FORMATION:RemoveUnitType(defid)
			-- remove everything related to this defid
			self.size=self.size-uType.n
			self.uTypes[defid]=nil
			self.area = self.area - uType.area
			self.places[uType.place][defid]=nil
			if #self.places[uType.place]==0 then self.places[uType.place]=nil end
			self:UpdatePoses(self.aim_center)
			self:SetLayers()
			self:PopulateLayers()
		end

		function FORMATION:RemoveIDs(defid,remids)
			local remove = table.remove
			local uType = self.uTypes[defid]
			local byID = uType.byID
			local n=#remids
			for i,id in ipairs(remids) do
				byID[id]=nil
			end
			local ownids,    poses,		  points,	    moves,		 gPoints,		mPoints,	   units
			 = uType.ids, uType.poses, uType.points, uType.moves, uType.gPoints, uType.mPoints, uType.units
			local i,id = 1,ownids[1]
			while id do
				local unit = byID[id]
				if unit then 
					unit.i=i
					points[i].i,mPoints[i].i,gPoints[i].i=i,i,i
				else
					remove(ownids,i) remove(poses,i) remove(points,i) remove(moves,i) remove(gPoints,i) remove(mPoints,i) remove(units,i)
					i=i-1
				end
				i=i+1
				id = ownids[i]
			end
			uType.n=uType.n-n
			self.size=self.size-n
			local area = area(uType.sq_r*uType.n)
			local diff = area - uType.area
			self.area = self.area + diff
			uType.area = area

			self:UpdatePoses(self.ghost_center)
			self:SetLayers()
			self:PopulateLayers()	
		end

		function FORMATION:RemoveUnits(remTypes,fromDelayed)
			Echo('main remove')
			for defid,ids in pairs(remTypes) do
				local own = self.uTypes[defid]
				local toDelete = #ids
				-- don't remake the whole uType if only a few unit has to be deleted
				if toDelete<own.n*0.5 then
					self:RemoveIDs(defid,ids)
				elseif toDelete==own.n then
					self:RemoveUnitType(defid)
				else
					self:ReplaceUnitType(defid,ids)
				end
				if fromDelayed then self.rem_pending[defid]=nil end
			end
		end

		function DELAY_REMOVE:Add(id,defid,unit)
			local f = unit.f
			f.rem_delay = 3
			if not self.formations[f] then self.formations[f]=f end
			if not f.rem_pending[defid] then f.rem_pending[defid]={} end
			unit.deleted=true
			local uMoves = unit.uMoves
			while uMoves[1] do table.remove(uMoves,1) end
			table.insert(f.rem_pending[defid],id)
		end

		function DELAY_REMOVE:CheckTime(delta)
			for f in pairs(self.formations) do
				local delay = f.rem_delay-delta
				if delay < 0 then 
					f:RemoveUnits(f.rem_pending,'fromDelayed')
					self.formations[f]=nil
					delay = 3
				end
				f.rem_delay = delay

			end
		end

	----------------------------------------------------------------------------
	------------------------ Points Manipulation -------------------------------
	----------------------------------------------------------------------------


		function FORMATION:Intervert(result,ids,ref_points,receiver_points,byID,point_key,l)
			-- reindex points of chosen type to put them in front of ids and relink them to units
			local trans = {}
			local layer = self.layers[l]
			for _,res in ipairs(result) do
				local id,newp = res[1],res[2]
				local unit = byID[id]
				local I = unit.i
				local point
				-- find out the index of the point matching the id, and update what we can
				for i,p in ipairs(ref_points) do
					if receiver_points[i] and p[1]==newp[1] and p[3]==newp[3] then
						point,receiver_points[i] = receiver_points[i],nil
						trans[I]=point
						point.i=I
						unit[point_key]=point
						-- re-place unit into sublayer of its point
						local s,n = point.s,point.sn
						layer.sublayers[s][n] = unit
						unit.s,unit.sn = s,n
						point.unit = unit
						--
						break
					end
				end
			end
			-- finish the switching using external table
			for i,p in ipairs(trans) do
				receiver_points[i]=p
			end

		end

		function FORMATION:AttachUnits(m,angle) -- reorder index and relink point of chosen type for units to get optimal distance, using ghost point as reference
			local points_key = m and 'mPoints' or 'points'
			local point_key = points_key:sub(1,points_key:len()-1)

			if next(self.rem_pending,nil) then self:RemoveUnits(self.rem_pending,'fromDelayed') end
			local angle = m and self.move_angle or self.angle
			local expand = self.expand
			local _,maxHungarianUnits = debug.getupvalue(CF2_MatchUnitsToNodes,MHU_num)
			for _,uType in pairs(self.uTypes) do
			    local n,ids,byID,points,ref_points,l = uType.n,uType.ids,uType.byID, uType[points_key], uType.gPoints,uType.l
				local result
				--Debug("maxHungarianUnits is ", maxHungarianUnits)
			    if (n <= maxHungarianUnits) or true then -- finally using only hungarian, OrdersNoX is not working as expected
			        result = GetOrdersHungarian(ref_points, ids, n, false)
			    else
			        result = GetOrdersNoX(ref_points, ids, n, false)
			    end
			    self:Intervert(result,ids,ref_points,points,byID,point_key,l)
			end
		end

		function FORMATION:UpdatePoints() -- apply turn and rotation without changing original distance nor original angle of them
			local expand = self.expand
			local rotation = self.angle
			local cx,cz = self.center[1], self.center[3]
			for _,uType in pairs(self.uTypes) do
				for _,point in ipairs(uType.points) do
					local newangle, dist  = point.angle+rotation, point.dist*expand
					local fx,fz = cx+sin(newangle)*dist, cz+cos(newangle)*dist
					point[1],point[2],point[3] = fx,spGetGroundHeight(fx,fz),fz
				end
			end
		end

		function FORMATION:Turn(turn)
			self.angle = self.angle+turn
			self:UpdatePoints()
		end

		function FORMATION:Expand(value)
			if not temp then self.expand=self.expand*(1+value*0.05) end
			self:UpdatePoints()
		end

		function FORMATION:Translate(center,to,free)
			local x,y,z = unpack(to)
			local offx,offz = x-center[1],z-center[3]
			local hyp = (offx^2 + offz^2) ^ 0.5
			if not free then self.last_center={unpack(center)} end-- useful to keep having a direction when mouse is at 0 offset from formation center, keep the previous last_center if we are grabbing
			local big = abs(offx)>abs(offz) and abs(offx) or abs(offz)
			self.dirx,self.dirz = offx/big,offz/big
			if restricted then 
				local hyp = (offx^2 + offz^2) ^ 0.5
				if hyp<self.rad then return false end
			end
			center[1],center[2],center[3]=x,y,z
			outPoint[1],outPoint[3]= outPoint[1]+offx,outPoint[3]+offz
			outPoint[2] = spGetGroundHeight(outPoint[1],outPoint[3])
			for id,unit in pairs(self.allIDs) do
				local point = unit.point
				local mx,mz = point[1]+offx, point[3]+offz
				point[1],point[2],point[3] = mx,spGetGroundHeight(mx,mz),mz
			end	
			return true
		end

		function FORMATION:SetAngle(from,to)
			local x,y,z = unpack(to)
			local rad = self.rad
			--local center = CONTROLS.grabbing and self.mouse_center or shift and self.shift_center or self.center
			local cx,cy,cz = unpack(from)
			-- if we are trailing positions and/or the center is on mouse position, we use the last center to determine direction
			local dirx,dirz = (x-cx), (z-cz)

			local hyp = (dirx^2+dirz^2)^0.5
			if CONTROLS.aim_on_mouse then
				if hyp>CONTROLS.aim_on_mouse then
					CONTROLS.aim_on_mouse=false
				else
					cx,cy,cz = unpack(self.last_center)
					dirx,dirz = (x-cx), (z-cz)
					hyp = (dirx^2+dirz^2)^0.5
				end
			end
			if hyp==0 then return end
			-- also when trailing with alt, we want to have a straightened direction, when cursor is too close of the center, we ignore the new angle

			self.update_angle=false
			dirx,dirz = dirx/hyp,dirz/hyp

			local ox,oz = cx+(dirx*rad), cz+(dirz*rad)
			outPoint[1],outPoint[2],outPoint[3] = ox, spGetGroundHeight(ox,oz), oz
			-- what is needed to fill up the last angle to reach the current orientation
			local turn = atan2(ox-cx,oz-cz)-self.angle
			-- offset the angle of formation with ctrl + shift
			if CONTROLS.angle_offset then self.turn_offset=turn C:UpdatePoints() return end
			--
			self.angle=self.angle-self.turn_offset
			self:Turn(turn)
		end


		function FORMATION:SetGhostFormation(manual)
			local order = self.orders[1]
			self:UpdatePoses(self.ghost_center)
			if not order or order.name=='SimpleMove' then 
				for id,unit in pairs(self.allIDs) do
					local gPoint=unit.gPoint
					gPoint[1],gPoint[2],gPoint[3] = unpack(unit.pos)
					if manual then
						if not self.temoins then self.temoins={} end
						self.temoins[id] = {unpack(gPoint)}
					end		
				end
			else
				local expand = order.expand
				local cx,cy,cz = unpack(self.ghost_center)

				if order.name=='Rotate' then
					-- shapeshift is processing, rotation has not occured yet
					if manual then
						order.angle = self.gAngle
					-- meanwhile rotation, updating angle step by step
					elseif self.update_move_angle and order.angles then
						-- now using completed angles
						local tot,cnt=0,0
						local angles=order.angles
						for id,unit in pairs(self.allIDs) do
							tot,cnt=tot+unit.compAngle,cnt+1
						end
						--order.angle=tot/cnt
						--[[--old method get an average angle from the rotations steps
							for at,n in pairs(order.unitsAt) do cnt,tot = cnt+n, tot+angles[at]*n end
							--complete average angle with the remaining units that haven't yet completed the first angle
							tot = tot + (self.size-cnt)*self.gAngle
							if cnt>0 then order.angle= tot/cnt else order.angle=self.gAngle end
							order.angle=tot/self.size
						--]]
						self.gAngle=tot/cnt
					end
				else
					self.gAngle=order.angle
				end
				local gAngle=self.gAngle
				for id,unit in pairs(self.allIDs) do
					local ref=unit.mPoint
					--if unit.mPoint[1] then point=unit.mPoint end
					local gPoint=unit.gPoint
					gPoint.manual = manual
					local dist,angle = ref.dist*expand, ref.angle+gAngle
					local x,z = cx+sin(angle)*dist, cz+cos(angle)*dist
					local y = spGetGroundHeight(x,z)
					gPoint[1],gPoint[2],gPoint[3] = x,y,z
					--[[ --temoins mPoints when SetGhostFormation called on shepshift
						if manual then
							if not self.temoins then self.temoins={} end
							self.temoins[id] = {unpack(gPoint)}
						end
					--]]		
				end

			end
			self.update_angle=true
		end

------------------------------------------------------------------------------------
------------------------------------------------------------------------------------
-------------------------------- USER CONTROL --------------------------------------
------------------------------------------------------------------------------------
------------------------------------------------------------------------------------

	----------------------------------------------------------------------------
	--------------------------- Control Module ---------------------------------
	----------------------------------------------------------------------------

		------------------- Detection -------------------

			function CONTROLS:mouse()
				self.prevmx,self.prevmy=self.mx,self.my
				local mx,my,lClick,mClick,rClick = spGetMouseState()
				self.mx,self.my = mx,my
				local px,py,pz,offmap = UniTraceScreenRay(mx,my)
				local newmove =  px~=self.px or py~=self.py or pz~=self.pz
				self.newmove = newmove
				self.offmap = offmap
				self.px,self.py,self.pz = px,py,pz
				local newclick = self.lClick~=lClick or self.mClick~=mClick or self.rClick~=rClick
				self.lClick,self.mClick,self.rClick = lClick,mClick,rClick

				return newmove,newclick
			end


			do
				local function Pass(self,conditions)
					local pass,ORopen,NOT,OR
					for _,condition in ipairs(conditions) do
						local oricond = condition
						NOT,OR,condition = condition:match('!'), condition:match('%?'), condition:gsub('[!%?]','') -- '?' are used as OR statement  {name='status', ?cond a,?cond b,cond c} = (a or b) and c

						if ORopen and not (OR or pass) then break end

						pass =  ORopen and pass
							 or not NOT==(not not self[condition])

						ORopen=OR
						if not pass or OR then break end
					end
					--Debug.Ctrls(status,oricond,pass)
					return pass
				end
				function CONTROLS:GetStatus()
					local olds={}
					Debug.Ctrls('-----------------------')
					for _,conditions in ipairs(self.statuses) do
						local status = conditions.name:gsub('!','')
						--Echo('-------'..status..'-------')
						local pass = Pass(self,conditions)
							-- if not (pass or OR) then  break end

						-- when status is negated with conditions: {name='!status', cond a,cond b,cond c} not used anymore for now
						--if status=='inspect' then Echo('inspect =>',pass) end
						if status:match('!') then 
							if pass then
								status=status:gsub('!')
								if olds[status]==nil then olds[status]=self[status] end
								self[status]=false
							end
						elseif self[status]~=pass then
							if olds[status]==nil then olds[status]=self[status] end
							self[status]=pass
						end
					end
					local news={}
					for status,v in pairs(olds) do if self[status]~=v then news[status]=not v end end

					return news
				end
			end


			function CONTROLS:Update(arg,arg2,press,isRepeat)
				if isRepeat then return end
				self.Mouse=arg=='Mouse'
				self.Key=arg=='Key'
				self.Wheel=arg=='Wheel'
				if arg=='Key' then 
					local key = arg2
					key = KEYCODES[key]
					self[ key ]=press
					if not self.uniques_cond[ key ] then Debug('unused '..key )return else Debug('used '..key) end
				elseif arg=='Mouse' then
					local delta =arg2
					self.delta=delta
					newmove,newclick = self:mouse()
					if not (newmove or newclick) then return end
				end
				
				self.C = C and true
				local _
				_,self.cmd = spGetActiveCommand()
				self.order = C and C.orders[1]
				self.sel = currentSel.n>0
				local news = self:GetStatus()
				------ set statuses/condition for drawing debugging ------
				if Debug.Ctrls.On then
					local str  = '' for k,status in ipairs(self.statuses) do if self[status.name]  then str =str ..'|'..status.name end 			end self.debugstr =str
					local str2 = '' for cond in pairs(self.uniques_cond)  do if self[cond] 	       then str2=str2..'|'..cond        end				end	self.debugstr2=str2
					local str3 = '' for new   in pairs(news) 			  do if self.instants[new] then	str3=str3..'|'..new	end						end self.debugstr3=str3
					local str4 = '' for new,v in pairs(news) 			  do 							str4=str4..'|'..(not v and 'un' or '')..new	end self.debugstr4=str4
				end
				----------------------------------------------------------
				return self:Act(news)
			end

			-- unused CheckKeys -- retrieve the option key from key + keyset taken from KeyPress
				--[[
					function CONTROLS:CheckKeys(key,keyset)
					local mod,hex = keyset:match('(%+?)(0x.*)')
					local key = (hex:match('0x400000E') or hex:match('0x020$')) and '' or mod..KEYCODES[key]
					local hotkey = ( keyset:gsub('(%+?)(0x.*)','')..key )
					return self.keys[hotkey]
					end
				--]]

		------------------- Response --------------------
			do
				local self = CONTROLS
				CONTROLS.acts={
					stop = function()
						C:Stop()
					end
					,browse = function(up)
						--local shift = up or self.shift
						local down = not up
						C.shape_num=C.shape_num + (down and -1 or 1)
						if not SHAPES[C.shape_num] then C.shape_num = (down and SHAPES.n or 1) end
						C.shape=SHAPES[C.shape_num]
						C:SetPoints()
						C.new_shape=true
						return true
					end
					,grabbing = function()
						C:Translate(C.center,C.mouse_center,true)
						C.center = C.mouse_center
					end
					,ungrabbing = function()
						--Echo('ungrabbing')
					end
					,untrailing = function()
						if not CONTROLS.shifted then 
							C.aim_center = C.ghost_center
							local order = C.orders[1]
							if not order then return end -- can happen when untrailing if army has finished moving
							local shape_num = order.shape_num
							if C.shape_num~=shape_num then
								C.shape_num=shape_num
								C:SetPoints()
							end

						end
					end
					,unlock_angle = function()
						C.update_angle=true
					end
					---------- prepare a new formation or recover one or disband it
					,fmode = function()
						if C then
							Echo('disband C')
							C:Disband()
							return true,true
						elseif currentSel.formation then 
							Echo('reselect C')
							currentSel.formation:Select()

							return true,true
						end
						Echo('create a new formation')
						local sorted_sel = spGetSelectedUnitsSorted()
						sorted_sel.n=nil
						-- remove irrelevant units
						for defid,ids in pairs(sorted_sel) do if not UDS[defid].isGroundUnit then sorted_sel[defid]=nil end end
						-- no need to go any further if no relevant unit remains
						if not next(sorted_sel,nil) then 
							CONTROLS.sel=false
						else
							local f = FORMATION:new(sorted_sel)
							Echo('select the new created selection from fmode')
							f:Select()
						end
						return C,true
					end
					,unselect = function()
						C:Stop()
						C:Unselect()
						return true,true
					end
					--------- clean preferences
					,cleanmem = function()
						local stats = MEMORY.formations
						for srt_form in pairs(stats) do stats[srt_form]=nil end
						for i=1,SHAPES.n do
							MEMORY.most_used_shapes[SHAPES[i]]	=	1-i/1000
						end 
					end
					----
					,reset_offset = function()
						if C.turn_offset~=0 then
							C:Turn(C.turn_offset)
							C.turn_offset=0
							return true
						end
					end
					
					,shifted = function()
				 		C.aim_center = C.shift_center
				 		if C.orders.n>1 then
							local shape_num = C.orders[C.orders.n].shape_num
							if C.shape_num~=shape_num then
								Echo('CHANGED SHAPE IN SHIFTED ACT')
								C.shape_num=shape_num
								C:SetPoints()
							end
						end
					end
					,unshifted = function()
				 		C.aim_center = C.ghost_center

				 		if C.orders[1] then
							local shape_num = C.orders[1].shape_num
							if C.shape_num~=shape_num then
								C.shape_num=shape_num
								C:SetPoints()
							end
						end
					end
					,move_rotate = function()
						if not self.shifted then
							from = C.ghost_center
						 	C:Stop()
						else
							from = C.shift_center
						end
						if self.aim_on_mouse then
							-- don't give an additional rotate if the mouse didnt really moved
							C:AddMove(from,C.pose_center,C.orders.n+1,C.angle,C.expand,'strict')
						else
							C:AddMoveRotate(from,C.pose_center,C.orders.n+1,C.pose_angle,C.angle,C.expand,'strict')
						end
				 		C:GiveNextOrder('manual')
						C.update_angle=true
						self.posed=false
					end
					,rmove_rotate = function()
						self.rposed=false
						return CONTROLS.acts.move_rotate()
					end
					,posed = function()
						--Echo('posed')
						-- remember the angle when we pose
						C.pose_angle=C.angle
						-- set a candidate 
						C.pose_center={unpack(C.mouse_center)}
						-- move the aiming base and rmb the last pos
						C.last_center = C.aim_center
						C.aim_center = C.pose_center
						-- root the project so it pivot on itself for the user to define direction
						C.center = {unpack(C.pose_center)}
						-- indicate we got aim on mouse so we have to rely on another center to determine direction
						CONTROLS.aim_on_mouse=6*6
						return true
					end
					,rposed = function()
						return CONTROLS.acts.posed()
					end
				 	,unposed = function()
				 		--self.aim_on_mouse=false
					 	if not self.move_rotate then
				 			-- put the aiming back at the ghost and rmb the last_center
				 			C.last_center = {unpack(C.aim_center)}
				 			C.aim_center = self.shifted and C.shift_center or C.ghost_center
				 			-- unroot the project
				 			C.center = C.mouse_center
				 		end
					end
				 	,unrposed = function()
				 		return CONTROLS.acts.unposed()
				 	end
				 	,rotate = function()
				 		CONTROLS.rot = 0.2 -- timing or rotate refresh
				 		C:Stop()
						C:AddRotate(C.ghost_center,C.orders.n+1,C.angle,C.expand,'strict',false,'isUser')
				 		C:GiveNextOrder('manual')
				 		return true
				 	end
				 	,unrotate = function()
				 		CONTROLS.rot = false
						C:AddRotate(C.ghost_center,C.orders.n+1,C.angle,C.expand,'strict',false,'isUser')
				 		C:GiveNextOrder('manual')
				 		return true
				 	end

				 	,inspect = function() return true end
				 	,uninspect = function()
				 		if self.spottedOrder then
							C.center = C.mouse_center
				 			self.spottedOrder=false
				 		end
 						self.distSpotted=false
 						self.movingSpotted=false
 						self.rotateSpotted=false
 						self.clickedOrder=false

				 		if not C then return end
				 		if C.orders.n>0 then
							local shape_num = C.orders[ CONTROLS.shifted and C.orders.n or 1 ].shape_num
							if C.shape_num~=shape_num then
								C.shape_num=shape_num
								C:SetPoints()
							end
						end
						if C.backup_expand then
							C.expand = C.backup_expand
							C.backup_expand = nil
							C:Expand(0)
						end
				 	end
				 	,reload_widget = function()
				 		local w_name = widget:GetInfo().name
		        		spSendCommands('luaui disablewidget '..w_name)
		        		spSendCommands('luaui enablewidget '..w_name)
		        		return true
				 	end
				 	,instant_regroup = function()
				 		C:Stop()
						C:AddRegroup(C.ghost_center,C.ghost_center,1,C.angle,C.expand)
						C:GiveNextOrder()
						return true
				 	end
				 	,debug_layer = function()
				 		self.debug_layerON = not self.debug_layerON
				 		return true
				 	end
				 	,debug_uradius = function()
				 		self.debug_uradiusON = not self.debug_uradiusON
				 		return true
				 	end
				 	,debug_echo = function()
				 		Debug.On = not Debug.On
				 	end
				}
			end


			function CONTROLS:Act(news)
				local instants=self.instants
				local acts=self.acts
				local lock,abort=false,false
				for act,ON in pairs(news) do
					-- Echo('act',act,ON,self[act])
					if not ON then
						-- act=(self[act] or instants[act]) and 'un'..act
						-- act=self.statuses[act] and 'un'..act
						act='un'..act
					end
					if act then
						local thislock
						if acts[act] then thislock,abort = acts[act]() end
						lock = thislock or lock
						if instants[act] then self[act]=false end
						if abort then return lock end
					end
				end
				return lock-- lock keyboard or mouse
			end

		-------------------- Reset ----------------------
			function CONTROLS:Reset()
				for prop in pairs(self or CONTROLS) do 
					if type(prop)=='boolean' then self[prop]=false end
				end
			end

	----------------------------------------------------------------------------
	---------------------------- Zone Module -----------------------------------
	----------------------------------------------------------------------------

		function MyZones(zone,mx,my,button)
			zone.checked = not zone.checked
			if zone.checked then
				zone.draw[1] = CHECKED..zone.name
				zone.color = zone.color_checked
			else
				zone.draw[1] = UNCHECKED..zone.name
				zone.color = zone.color_unchecked
			end
			zone.action()
			return true
		end

	----------------------------------------------------------------------------
	---------------------------- User Moves ------------------------------------
	----------------------------------------------------------------------------

		-- Unit Command Debugging
			--[[
				function widget:UnitCommand(id, defID, teamID, cmd, params, options, cmdTag, fromSynced, fromLua)
					DebugUnitCommand(id, defID, teamID, cmd, params, options, cmdTag, fromSynced, fromLua)
				end
			--]]
		function FORMATION:Select()
			ACTIVES.toSelect=false
			C=self
			C.selected=true
			CONTROLS:Reset()
			if self.active then currentSel.formation=self end
		end

		function FORMATION:Unselect()
			C=false
			CONTROLS:Reset()
			self.selected=false
			if self.active then
				self:MemorizeScore()
			else
				self=nil
				collectgarbage('count')
			end
		end
		function FORMATION:Activate()
			if self.active then return end
			for id,unit in pairs(self.allIDs) do ACTIVEIDS[id]=unit end
			self.active=true
			local n = ACTIVES.n+1
			ACTIVES[n]=self
			self.n=n
			ACTIVES.n=n
			currentSel.formation=self
		end
		function FORMATION:Disband()
			if C==self then
				C:Unselect()
			end
			if self.active then
				self:MemorizeScore()
				for id,unit in pairs(self.allIDs) do ACTIVEIDS[id]=nil end
				local n = self.n
				table.remove(ACTIVES,n)
				ACTIVES.n=ACTIVES.n-1
				while ACTIVES[n] do
					ACTIVES[n].n=n
					n=n+1
				end
			end
			currentSel.formation=nil
			self=nil
			collectgarbage('count')
		end


		function widget:CommandNotify(cmd,params,opts)
			if not C then return end
			if next(C.rem_pending,nil) then C:RemoveUnits(C.rem_pending,'fromDelayed') end
			if cmd==0 then C:Stop() return true end
			if cmd==31109 or cmd==16 then
				if CONTROLS.shifted or CONTROLS.trailing then
					C.last_center=C.aim_center
					CONTROLS.aim_on_mouse=200
					C.aim_center=params
					if not (CONTROLS.lock_angle) then
						C:SetAngle(C.last_center,C.aim_center)
					end
				end
				C:AddMove(C.last_center,params,C.orders.n+1,C.angle,C.expand,false,nil,cmd)
				C:GiveNextOrder('manual')
				return true
			end
		end

		function widget:KeyPress(key,mods,isRepeat,keyset)

			if isRepeat then return end
			-- if KEYCODES[key]=='f' then Echo('pressed F') end

			if C and  next(C.rem_pending,nil) then C:RemoveUnits(C.rem_pending,'fromDelayed') end
			if mods.alt and KEYCODES[key]=='c' then
				Echo(collectgarbage('count'))
			end

			return CONTROLS:Update('Key',key,true)
		end

		function widget:KeyRelease(key,mods,keyset)
			CONTROLS:Update('Key',key,false)
		end

		function widget:MousePress(mx,my,button)
			local lock = CONTROLS:Update('Mouse')

			if CONTROLS.spottedOrder then
 				if CONTROLS.spottedOrder and button==1 then
 					CONTROLS.clickedOrder=true
 					if CONTROLS.distSpotted>MOVE_SPOT then
 						CONTROLS.rotateSpotted=true
 					else
 						CONTROLS.movingSpotted=true
 					end
 					return true
 				end
			end
			if ACTIVES.spotted and button==1 then 
				local f = ACTIVES.spotted
				f.spotted=false
				if f==currentSel.formation then f:Select() return true end
				Spring.SelectUnitMap(f.allIDs)
				ACTIVES.toSelect,ACTIVES.spotted=ACTIVES.spotted,nil
				return true
			end

			-- lock/unlock CF2 from starting a trail when we don't want to
			if button==3 then
				local _,formationCmds = debug.getupvalue(CF2_MousePress,FCMDS_num)
				formationCmds[CMD_MOVE]=CONTROLS.trailing or not C
				--formationCmds[CMD_RAW_MOVE]=trailing or not C
			end
			return lock
		end
		function widget:MouseWheel(up,value)
			if not C then return end
			-- while inspecting an order, modify its shape and the forwarding until another tweaked shape is found
			if CONTROLS.spottedOrder then
				local order = CONTROLS.spottedOrder
				local f=order.f
				local n = order.n
				local orders = f.orders
				local previous_order = orders[n-1]
				

				if CONTROLS.shift then
					local shape_num = order.shape_num
					shape_num=shape_num + (up and 1 or -1)
					if not SHAPES[shape_num] then shape_num = (up and 1 or SHAPES.n) end

					for i=n+1,orders.n do
						if orders[i].shapeshift then break end
						orders[i].shape_num=shape_num
					end

					order.shapeshift= previous_order and previous_order.shape_num~=shape_num or not previous_order
					order.shape_num = shape_num

					if C.shape_num~=shape_num then
						C.shape_num=shape_num
						C:SetPoints()
					end
				else
					C:Expand(value)
					local expand = C.expand
					order.expand = expand
					order.expand_mark=true
					for i=n+1,orders.n do
						local order = orders[i]
						if order.shapeshift then break end
						if order.expand_mark then break end
						orders[i].expand=expand
					end
				end
				return true
			end
			if CONTROLS.alt then 
				CONTROLS.acts.browse(up)
				return true
			end
			-- CTRL + wheel or CTRL+alt expand/shrink formation
			if CONTROLS.shift then 
				C:Expand(value)
				return true
			end
		end

		--My Clicks
			--[[ 
				function MyClicks(x,y,L,M,R,gf)
				end
			--]]
		function widget:MouseRelease(mx,my,button)
			if CONTROLS.clickedOrder then
				CONTROLS.clickedOrder=false
				CONTROLS.movingSpotted=false
				CONTROLS.rotateSpotted=false
			end
		end
	----------------------------------------------------------------------------
	---------------------------- Inspection ------------------------------------
	----------------------------------------------------------------------------

		function FORMATION:SpotOrder(x,z)
			local orders = self.orders
			local bestdist = SPOT_THRESHOLD
			local spotted
			for i,order in ipairs(orders) do
				local pos = order.from
				local ox,oy,oz = unpack(pos)
				local dist = ( (x-ox)^2 + (z-oz)^2 )^0.5
				if dist < bestdist then spotted,bestdist = i,dist end
			end

			if spotted then 
				local order = orders[spotted]
				self.angle=order.angle
				CONTROLS.lock_angle=true
				--if order==CONTROLS.spottedOrder then return end
				CONTROLS.spottedOrder = order
				local shape_num = order.shape_num
				if C.shape_num~=shape_num then
					C.shape_num=shape_num
					C:SetPoints()
				end
				if not C.backup_expand then C.backup_expand=C.expand end
				if order.expand~=C.expand then 
					C.expand=order.expand
					C:Expand(0)
				end

				--C:Translate(C.center,order.from,true)
				--if CONTROLS.shifted then CONTROLS.act.unshifted() end
				C.center=order.from
			elseif CONTROLS.spottedOrder then
				local order = CONTROLS.spottedOrder

				C.center= C.mouse_center

				CONTROLS.spottedOrder=false
				CONTROLS.lock_angle=false
			end
		end

	----------------------------------------------------------------------------
	-------------------------- Units Changing ----------------------------------
	----------------------------------------------------------------------------

		function MyNewTeamID(id) -- own callin
			myTeamID=id
		end

		do
		-- Commands Changed
			-- local GetMapSel = function(t,comp) -- no need anymore with SelectionChanged
			-- 	local ret,n={},0
			-- 	local identical=true
			-- 	local compN
			-- 	compN,comp.n = comp.n,nil
			-- 	for i,id in ipairs(t) do
			-- 		ret[id],n=true,n+1
			-- 		if identical then identical = comp[id] end
			-- 	end	
			-- 	ret.n=n
			-- 	comp.n=n
			-- 	if identical then identical = n==compN end
			-- 	return ret, identical
			-- end
			local GetMapSel = function(t)
				local ret,n={},0
				for i,id in ipairs(t) do
					ret[id],n=true,n+1
				end	
				ret.n=n
				return ret
			end
			local function CleanGot(fs)
				for _,f in ipairs(fs) do f.got=nil end
			end
			local DetectFormation = function(newsel,forceAdd)
				local samecnt = 0
				local fs,total = {n=0},0
				for id,_ in pairs(newsel) do
					local unit = ACTIVEIDS[id] or C and  C.allIDs[id]
					if unit then
						local thisf = unit.f
						if not thisf.got then thisf.got=0 table.insert(fs,thisf) end
						thisf.got = thisf.got+1
						total=total+1
					end
				end
				-- we don't bother more if there is not 85% of owned units in the selection
				if not forceAdd and total<newsel.n*0.85 then CleanGot(fs) Echo('not enough owned unit selected '..total..' vs '..newsel.n) return end

				-- we selected a single formation entirely (or almost)
				if not fs[2] and total>0.9*newsel.n and total>0.8*fs[1].size then
					CleanGot(fs) 
					-- we got it exactly
					if total==fs[1].size then return fs[1] end
					-- or we need to correct the selection
					local newsel = {}
					for id in pairs(fs[1].allIDs) do table.insert(newsel,id) end
					return fs[1],_,newsel
				end
				-- else we retain any formation that has at least 50% of their unit in the selection and has the most number of units
				local gotMore 
				for _,f in ipairs(fs) do
					if not gotMore and f.got>f.size*0.5 then gotMore=f
					elseif f.got>f.size*0.5 and f.got>gotMore.got then gotMore=f
					end
				end
				if gotMore then Echo('a formation got '..gotMore.got,'its size is ',gotMore.size) end
				CleanGot(fs)

				---- end of detection, now find out what unit to add and if we own some

				local remainToAdd
				if gotMore then
					fs[gotMore]=nil
					remainToAdd = {undefined={},owned={}}
					local sorted_sel = spGetSelectedUnitsSorted()
					local correctedSel
					sorted_sel.n=nil
					for defID,ids in pairs(sorted_sel) do if not UDS[defID].isGroundUnit then sorted_sel[defid]=nil correctedSel=true end end
					if correctedSel then correctedSel={} end

					local alreadyGot=gotMore.allIDs
					for defID,ids in pairs(sorted_sel) do
						for i,id in pairs(ids) do
							if not alreadyGot[id] then
								local unit = ACTIVEIDS[id] or C and C.allIDs[id]
								if unit then
									 remainToAdd.owned[unit]=true
								else
									remainToAdd.undefined[id]=true
								end
							end
						end
						if correctedSel then table.insert(correctedSel,id) end
					end
				end
				return gotMore, remainToAdd,correctedSel
			end
			-- function widget:SelectionChanged(sel)
			-- 	Echo('sel changed')
			-- 	for k,v in pairs(sel) do
			-- 		Echo(k,v)
			-- 	end
			-- 	-- return {}
			-- end
			function widget:SelectionChanged(sel,less)
				CONTROLS.Reset()
				local byid = GetMapSel(sel)
				-- detect if user selected one or more formations
				if byid.n>0 and not ACTIVES.toSelect and not less and  (C or ACTIVES[1]) then
					Echo('detecting...')
					local f,remainToAdd,correctedSel = DetectFormation(byid,CONTROLS.shift)
					if f then 
						if not remainToAdd then
							if correctedSel then Echo('correcting sel') return correctedSel end -- ask widgetHandler to redo selection with our correction
							-- a whole existing formation has been selected
							currentSel=byid
							Echo('select an existing formation')
							f:Select()
							CONTROLS:Update()
							return
						end
						-- a partial formation has been selected
						for id in pairs(remainToAdd.undefined) do Echo(id..' need to be defined') end
						for unit in pairs(remainToAdd.owned) do Echo(unit.id..' already belong to a formation') end
						if correctedSel then Echo('correcting selection') end
						CONTROLS:Update()
						return correctedSel
					end
				end
				currentSel=byid
				if ACTIVES.toSelect then
					-- a formation has been spotted by the mouse and clicked, selecting...
					ACTIVES.toSelect:Select()
				elseif C then
					-- else leaving current formation
					Echo('unselect from selection changed')
					C:Unselect()
				end
				

				CONTROLS.sel=currentSel.n>0
				CONTROLS:Update()
			end
		end


-------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------
------------------------------- INITIALIZATION --------------------------------------
-------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------

	--------------------------------------------------
	------------------ Set Colors --------------------
	--------------------------------------------------

		function ConfigSetColors()
			for _,t in pairs(CONFIG) do
				t.color = {unpack(colors[t.color])}
			end
			for i,col_name in ipairs(layerColors) do
				layerColors[i]={unpack(colors[col_name])}
			end
		end


	--------------------------------------------------
	------------------ Set Debugs --------------------
	--------------------------------------------------

		function Debug:Define()
			local mt = { __call=function(self,...) return self.On and Echo(...) end }
			for k,t in pairs(self) do
				self[k]=setmetatable({On=false},mt)
			end
			self.On=false
			setmetatable(self, mt)

		end

	--------------------------------------------------
	-------------- Get View Resolution ---------------
	--------------------------------------------------

		function widget:GetViewSizes(vsx,vsy)
			txtx,txty = vsx, vsy
			ZONES:SetZones()
		end

	--------------------------------------------------
	---------------- Zones definition ----------------
	--------------------------------------------------

		function ZONES:DefineActions()
			self.actions = {
				 ['Debug At']	= function() Debug.At.On		= not Debug.At.On end
				,['Debug Ctrls']= function() Debug.Ctrls.On		= not Debug.Ctrls.On end
				,['Debug Layers']= function() Debug.Layers.On	= not Debug.Layers.On end
			}
		end

		function ZONES:SetZones()
			local offx,offy=0,0
			for i,zone in ipairs(Zones) do

				local x,y = zone.offx and offx or 0, zone.offy and offy or 0
				x,y = x + zone.x*txtx, zone.y*txty
				local s,name = zone.size, zone.name
				local len = (name:len()/2+1)
				local x2, y2 = x + len*s, y + s
				local color_checked = {unpack(colors[zone.color_checked])}
				local color_unchecked = {unpack(colors[zone.color_unchecked])}
				color_checked[4]=zone.alpha_checked
				color_unchecked[4]=zone.alpha_unchecked
				self[i]={ 
						    name=name
						   ,checked=false
						   ,x=x, x2=x2 ,y=y, y2=y2
						   ,action=self.actions[name]
						   ,color = color_unchecked
						   ,color_checked=color_checked
						   ,color_unchecked=color_unchecked
						   ,draw = {UNCHECKED..name, x, y, s,'h', color=color_unchecked}
						}
				offx=offx+len*s+15
				offy=offy+s+5
			end
		end
	
	--------------------------------------------------
	--------------- Shape Definition -----------------
	--------------------------------------------------

		SHAPES = { -- initial order that will be changed with user habits
			'CIRCLE'
			,'BULLET'
			,'DAWN'
			,'BARRAGE'
			,'SQUARED'
			,'OVALE'
			,'ELLIPSE'
			,'EYE'
			,'ROUND LEAF'
			,'ROUND LEAF 2'
			,'SPEAR HEAD'
			,'SPEAR HEAD 2'
			,'MORNING STAR'
			,'ARC'
			,'TRIANGLE'
			,'LOSANGE'
			,'SHARD'
			,'SHELL'
			,'FOUR ARROWS'
			,'DONKEY'
			,'TRIFORCE'
			,'FLOWER'
			,'FLOWER 2'

			,'TWO RECTS'
			,'TWO SQUARED'
			,'CROACH 2'

			,'SEAGULL'
			,'CANNON'
			,'CROACH'
			,'DOUBLE ARROW'
			,'BEE'
			,'BEE 2'
			,'DOUBLE SHELL'
			,'EOL'
			,'FISH'
			,'RADIO'
			,'NOISE'

			,'DOG'
			,'CAT'
			,'BAT'
			,'DUM HAT'
			,'BUNNY'
			,'CARROT'

			,'DOUBLE BARREL'
			,'TRIPLE BARREL'
			,'TRIPLE BARREL 2'
			,'BUTTERFLY'
		}
		for i,name in ipairs(SHAPES) do 
			SHAPES.n=i
			SHAPES[name] = i
		end
		for i=1,SHAPES.n do
			MEMORY.most_used_shapes[SHAPES[i]]	=	1-i/1000-- give it a little more to keep the order of the non used one in func FORMATION:UpdateShapesOrder
			MEMORY.oriSHAPES[SHAPES[i]]			=	1-i/1000
		end 

		OFF_PORTION = { -- initial order that will be changed with user habits
			['CIRCLE']=0
			,['BULLET']=0.45
			,['DAWN']=0
			,['BARRAGE']=-0.90
			,['SQUARED']=0
			,['OVALE']=-0.45
			,['ELLIPSE']=-0.45
			,['EYE']=-0.45
			,['ROUND LEAF']=0
			,['ROUND LEAF 2']=0
			,['SPEAR HEAD']=0
			,['SPEAR HEAD 2']=0
			,['MORNING STAR']=0
			,['ARC']=0
			,['TRIANGLE']=0.45
			,['LOSANGE']=-0.90
			,['SHARD']=-0.9
			,['SHELL']=0.3
			,['FOUR ARROWS']=-0.45
			,['DONKEY']=0
			,['TRIFORCE']=0
			,['FLOWER']=0
			,['FLOWER 2']=0

			,['TWO RECTS']=0
			,['TWO SQUARED']=0
			,['CROACH 2']=0.45

			,['SEAGULL']=0
			,['CANNON']=0
			,['CROACH']=0
			,['DOUBLE ARROW']=0.95
			,['BEE']=0.95
			,['BEE 2']=-0.45
			,['DOUBLE SHELL']=0
			,['EOL']=0
			,['FISH']=0
			,['RADIO']=0
			,['NOISE']=0

			,['DOG']=0
			,['CAT']=0
			,['BAT']=0
			,['DUM HAT']=0
			,['BUNNY']=0
			,['CARROT']=0

			,['DOUBLE BARREL']=0
			,['TRIPLE BARREL']=0
			,['TRIPLE BARREL 2']=0
			,['BUTTERFLY']=0
		}


		SET_BEFORE={ -- return a new offset,rotangle,rotate variable before usual CIRCLE transformation
			['BEE']				= function(s,a,angle,offset,rotangle) return 	abs(a+0.33*s)%1>0.5 and offset*2 or offset,		a*pi+pi,      		angle		end
			,['FISH']				= function(s,a,angle,offset,rotangle) return 	abs(a)>0.75 		and offset*2 or offset,		a*pi,         		angle		end
			,['SHELL']				= function(s,a,angle,offset,rotangle) return 	offset   + offset * min(a^2,0.7) * s,			a*pi, 		   		angle-pi/4	end
			,['OVALE']				= function(s,a,angle,offset,rotangle) return 	offset   + offset * (abs(a-0.5*s)%1), 		 	a*pi, 		   		angle+pi/2	end
			,['DOUBLE SHELL']		= function(s,a,angle,offset,rotangle) return   (offset/2 + offset * (a%1))       *1.5,		 	rotangle	   					end
			,['EOL']				= function(s,a,angle,offset,rotangle) return    offset   + offset * 2.5*(a%0.5),				rotangle	   					end
			,['ROUND LEAF']			= function(s,a,angle,offset,rotangle) return 	offset   + offset * a^2,					 	a*pi,     			angle		end
			,['RADIO']				= function(s,a,angle,offset,rotangle) return 			offset*5, 							    (a%0.25*s)*pi, 		angle		end
			,['ROUND LEAF 2']		= function(s,a,angle,offset,rotangle) return 			offset,									a*pi		   					end
			,['ARC']				= function(s,a,angle,offset,rotangle) return 			offset,									 0--[[pi/20--]] 				end
			,['TRIPLE BARREL']		= function(s,a,angle,offset,rotangle) return 			offset,  								  pi/20 + a*pi 					end
			,['TRIPLE BARREL 2']	= function(s,a,angle,offset,rotangle) return 			offset,  								  pi/20 + a*pi 					end
			,['SEAGULL']			= function(s,a,angle,offset,rotangle) return 			offset,  								  pi/20 + a*pi 					end
			,['SPEAR']				= function(s,a,angle,offset,rotangle) return 			offset,  								 -pi/20 + a*pi 					end
			,['CROACH 2']			= function(s,a,angle,offset,rotangle) return 			offset,  								 -pi/20 + a*pi 					end
			,['DOUBLE ARROW']		= function(s,a,angle,offset,rotangle) return 			offset,  								 -pi/20 + a*pi 					end
			,['SPEAR HEAD']			= function(s,a,angle,offset,rotangle) return 			offset,  								  pi/4  + a*pi 					end
			,['EYE']				= function(s,a,angle,offset,rotangle) return 			offset,  								  pi/4  + a*pi 					end
			,['SHARD']				= function(s,a,angle,offset,rotangle) return 			offset,  								  pi/4  + a*pi 					end
			,['LOSANGE']			= function(s,a,angle,offset,rotangle) return 			offset,  								  pi/4  + a*pi 					end
			,['TRIANGLE']			= function(s,a,angle,offset,rotangle) return 			offset,  								  pi/4  + a*pi 					end
			,['DOUBLE BARREL']		= function(s,a,angle,offset,rotangle) return 			offset,  								  pi/2  + a*pi 					end
			,['DAWN']				= function(s,a,angle,offset,rotangle) return 			offset,  								  pi    +   pi/5 				end
			,['DONKEY']				= function(s,a,angle,offset,rotangle) return 			offset,  								a*pi    +   pi/2				end
			,['FOUR ARROWS']		= function(s,a,angle,offset,rotangle) return 			offset,									a*pi    +   pi/2 				end
			,['BULLET']				= function(s,a,angle,offset,rotangle) return 			offset,									a*pi 							end
			,['BEE 2']				= function(s,a,angle,offset,rotangle) return 			offset,									a*pi 							end
			,['CANNON']				= function(s,a,angle,offset,rotangle) return 			offset,									a*pi 							end
			,['CROACH']				= function(s,a,angle,offset,rotangle) return 			offset,									a*pi 							end
			,['MORNING STAR']		= function(s,a,angle,offset,rotangle) return 			offset,									a*pi 							end
			,['BARRAGE']			= function(s,a,angle,offset,rotangle) return 			offset,									a*pi 							end
			,['TWO SQUARED']		= function(s,a,angle,offset,rotangle) return 			offset,									a*pi 							end
			,['TWO RECTS']			= function(s,a,angle,offset,rotangle) return 			offset,									a*pi 							end
			,['SQUARED']			= function(s,a,angle,offset,rotangle) return 			offset,									a*pi 							end
			,['DONKEY']				= function(s,a,angle,offset,rotangle) return 			offset,									a*pi 							end
			,['DOG']				= function(s,a,angle,offset,rotangle) return 			offset,									a*pi 							end
			,['CARROT']				= function(s,a,angle,offset,rotangle) return 			offset,									a*pi 							end
			,['CAT']				= function(s,a,angle,offset,rotangle) return 			offset,									a*pi 							end
			,['BAT']				= function(s,a,angle,offset,rotangle) return 			offset,									a*pi 							end
			,['BUNNY']				= function(s,a,angle,offset,rotangle) return 			offset,									a*pi 							end
			,['DUM HAT']			= function(s,a,angle,offset,rotangle) return 			offset,									a*pi 							end
			,['TRIFORCE']			= function(s,a,angle,offset,rotangle) return 			offset,									a*pi 							end
		}
		-----
		SET_AFTER ={ -- modify usual translated points after CIRCLE transformation
			['BUNNY']=function(x,z,s,shiftx,shiftz,a,angle,fx,fz,dirx,dirz,sdx,sdz,ratio,offset,minoffset,maxoffset,nlayers,centerRad,off,offx,offz)
				if dirz<0 then
					fx,fz = fx+(sdx*ratio^2*offset*8)/10, fz+(sdz*ratio^2*offset*8)/10+minoffset*(nlayers)*1.5
					fx = x+(fx-x)*0.8
				else
					fz = fz+(offset)
					fx = fx-dirx*offset/4*ratio^2
				end
				return fx,z+(fz-z)*0.8
			end
			,['TRIFORCE']=function(x,z,s,shiftx,shiftz,a,angle,fx,fz,dirx,dirz,sdx,sdz,ratio,offset,minoffset,maxoffset,nlayers,centerRad,off,offx,offz)
				if dirz<0 then
					fx,fz = fx+(sdx*ratio^2*offset*8)/10, fz+(sdz*ratio^2*offset*8)/10+minoffset*(nlayers)*1.5
					fx = x+(fx-x)*0.8
				else
					fz = fz+(offset)*dirz*2
					fx = fx-dirx*offset/1.5*dirz
				end
				return fx,z+(fz-z)*0.8,angle
			end
			,['DUM HAT']=function(x,z,s,shiftx,shiftz,a,angle,fx,fz,dirx,dirz,sdx,sdz,ratio,offset,minoffset,maxoffset,nlayers,centerRad,off,offx,offz)
				if dirz<0 then
					fx,fz = fx+(sdx*ratio*offset*8)/10, fz+(sdz*ratio*offset*8)/10+minoffset*(nlayers)*1.5
					fx = x+(fx-x)*0.8
				else
					fz = fz+(sdz*ratio^2.5*offset*8)/10
					fx = fx-dirx*offset*-dirz
				end
				return fx,z+(fz-z)*0.8,angle
			end
			,['BAT']=function(x,z,s,shiftx,shiftz,a,angle,fx,fz,dirx,dirz,sdx,sdz,ratio,offset,minoffset,maxoffset,nlayers,centerRad,off,offx,offz)
				if dirz<0 then
					fx,fz = fx+(sdx*ratio*offset*8)/10, fz+(sdz*ratio*offset*8)/10+minoffset*(nlayers)*1.5
					fx = x+(fx-x)*0.8
				else
					fz = fz+(sdz*ratio^2.5*offset*8)/10
				end
				return fx,z+(fz-z)*0.8,angle
			end
			,['DONKEY']=function(x,z,s,shiftx,shiftz,a,angle,fx,fz,dirx,dirz,sdx,sdz,ratio,offset,minoffset,maxoffset,nlayers,centerRad,off,offx,offz)
				if dirz<0 then
					fx,fz = fx+(sdx*ratio^2*offset*8)/10, fz+(sdz*ratio^2*offset*8)/10+minoffset*(nlayers-1)
					fx = x+(fx-x)*0.8
				else
					fz = fz+dirz^2*offset*2
					fx = fx-dirx*offset*0.33
				end
				return fx,z+(fz-z)*0.8,angle
			end
			,['DOG']=function(x,z,s,shiftx,shiftz,a,angle,fx,fz,dirx,dirz,sdx,sdz,ratio,offset,minoffset,maxoffset,nlayers,centerRad,off,offx,offz)
				if dirz<0 then
					fx,fz = fx+(sign(dirx)*ratio^1.7*offset*8)/10, fz+(sign(dirz)*ratio^1.7*offset*8)/10+minoffset*(nlayers-1)
				else
					fz = fz+dirz^2*offset
				end
				return x+(fx-x)*0.8, z+(fz-z)*0.8,angle
			end
			,['CARROT']=function(x,z,s,shiftx,shiftz,a,angle,fx,fz,dirx,dirz,sdx,sdz,ratio,offset,minoffset,maxoffset,nlayers,centerRad,off,offx,offz)
				if dirz<0 then
					fx,fz = fx+(sdx*ratio^2*offset*8)/10, fz+(sdz*ratio^2*offset*8)/10+minoffset*(nlayers-1)
					fx = x+(fx-x)*0.8
				else
					fz = fz+dirz^2*offset*2
					fx = fx-dirx/2*offset
				end
				return fx,z+(fz-z)*0.8,angle
			end
			,['CAT']=function(x,z,s,shiftx,shiftz,a,angle,fx,fz,dirx,dirz,sdx,sdz,ratio,offset,minoffset,maxoffset,nlayers,centerRad,off,offx,offz)
				if dirz<0 then
					fx,fz = fx+(sdx*ratio*offset*8)/10, fz+(sdz*ratio*offset*8)/10+minoffset*(nlayers-1)
				else
					fz = fz+dirz^2*offset
					fx = fx+dirx*offset
				end
				return x+(fx-x)*0.8, z+(fz-z)*0.8,angle
			end
			,['FOUR ARROWS']=function(x,z,s,shiftx,shiftz,a,angle,fx,fz,dirx,dirz,sdx,sdz,ratio,offset,minoffset,maxoffset,nlayers,centerRad,off,offx,offz)
				return fx+(sign(dirx)*ratio^2*offset*8)/10, fz+(sign(dirz)*ratio^2*offset*8)/10,angle
			end
			,['TRIANGLE']=function(x,z,s,shiftx,shiftz,a,angle,fx,fz,dirx,dirz,sdx,sdz,ratio,offset,minoffset,maxoffset,nlayers,centerRad,off,offx,offz)
				if a<0 then a,off = -a, off + ((dirx*minoffset)^2 + (dirz*minoffset)^2)^0.5  end
				off = off + off%max(minoffset,0.0001)
				
				return x + sin(a*pi)*((off)*3/4)*1.5, z + cos(a*pi)*(off)*1.5,angle-pi/2
			end
			,['LOSANGE']=function(x,z,s,shiftx,shiftz,a,angle,fx,fz,dirx,dirz,sdx,sdz,ratio,offset,minoffset,maxoffset,nlayers,centerRad,off,offx,offz)
				return x + sin(a*pi)*off*3/4, z + cos(a*pi)*off,angle+pi
			end
			,['BULLET']=function(x,z,s,shiftx,shiftz,a,angle,fx,fz,dirx,dirz,sdx,sdz,ratio,offset,minoffset,maxoffset,nlayers,centerRad,off,offx,offz)
				if a<0 then 
					fx,fz = x+dirx*offset*2, z+dirz*offset*3/4
				else
					fx,fz = x + sin(a*pi)*offset*2, z + cos(a*pi)*offset*3/4
				end
				return fx,fz,angle-pi/2
			end
			,['ELLIPSE']=function(x,z,s,shiftx,shiftz,a,angle,fx,fz,dirx,dirz,sdx,sdz,ratio,offset,minoffset,maxoffset,nlayers,centerRad,off,offx,offz)
				return x + sin(a*pi)*offset*1.5, z + cos(a*pi)*offset*3/4,angle+pi/2
			end
			,['SHARD']=function(x,z,s,shiftx,shiftz,a,angle,fx,fz,dirx,dirz,sdx,sdz,ratio,offset,minoffset,maxoffset,nlayers,centerRad,off,offx,offz)
				return x + sin(a*pi)*offset/1.5, z + cos(a*pi)*off*1.5,angle+pi
			end
			,['EYE']=function(x,z,s,shiftx,shiftz,a,angle,fx,fz,dirx,dirz,sdx,sdz,ratio,offset,minoffset,maxoffset,nlayers,centerRad,off,offx,offz)
				return x + sin(a*pi)*offset, z + cos(a*pi)*off,angle+pi/2
			end
			,['SPEAR HEAD']=function(x,z,s,shiftx,shiftz,a,angle,fx,fz,dirx,dirz,sdx,sdz,ratio,offset,minoffset,maxoffset,nlayers,centerRad,off,offx,offz)
				return x + sin(a/1.5*pi)*offset, z + cos(a*pi)*off,angle
			end
			,['SPEAR HEAD 2']=function(x,z,s,shiftx,shiftz,a,angle,fx,fz,dirx,dirz,sdx,sdz,ratio,offset,minoffset,maxoffset,nlayers,centerRad,off,offx,offz)
				return x + sin(a/1.5*pi)*offset, z + cos(a*pi)*offset*1.5,angle
			end
			,['MORNING STAR']=function(x,z,s,shiftx,shiftz,a,angle,fx,fz,dirx,dirz,sdx,sdz,ratio,offset,minoffset,maxoffset,nlayers,centerRad,off,offx,offz)
				return x + sin(a/1.5*pi)*off*1.5, z + cos(a/1.5*pi)*off*1.5,angle
			end
			,['DOUBLE ARROW']=function(x,z,s,shiftx,shiftz,a,angle,fx,fz,dirx,dirz,sdx,sdz,ratio,offset,minoffset,maxoffset,nlayers,centerRad,off,offx,offz)
				if a>=0 then offset=offset+minoffset end
				return fx-dirx*offset, fz+dirz*offset*2,angle+pi
			end
			,['CROACH 2']=function(x,z,s,shiftx,shiftz,a,angle,fx,fz,dirx,dirz,sdx,sdz,ratio,offset,minoffset,maxoffset,nlayers,centerRad,off,offx,offz)
				return x + sin(dirz)*offset*3, z + cos(dirx)*offset*3,angle
			end
			,['SPEAR']=function(x,z,s,shiftx,shiftz,a,angle,fx,fz,dirx,dirz,sdx,sdz,ratio,offset,minoffset,maxoffset,nlayers,centerRad,off,offx,offz)
				local off = 2.3*((dirx*offset*2)^2+(dirz*offset)^2)^0.5
				return x + sin(a/pi)*off, z + cos(a/2.5*pi)*off,angle+pi
			end
			,['NOISE']=function(x,z,s,shiftx,shiftz,a,angle,fx,fz,dirx,dirz,sdx,sdz,ratio,offset,minoffset,maxoffset,nlayers,centerRad,off,offx,offz)
				--[[
					fx,fz = x+dirx*offset*-sdz*2, z+dirz*offset*-sdx*2
					local offx,offz = fx-ox,fz-oz
					local offhyp = (offx^2+offz^2)^0.5
					local angle = acos(cos(offx,offz))+a*pi
					fx,fz = ox + sin(angle)*offhyp/2, oz + cos(angle)*offhyp/2
				--]]
				return x+(centerRad*dirx)*rand(), z+(centerRad*dirz)*rand()
			end
			,['CANNON']=function(x,z,s,shiftx,shiftz,a,angle,fx,fz,dirx,dirz,sdx,sdz,ratio,offset,minoffset,maxoffset,nlayers,centerRad,off,offx,offz)
				local off = (((dirx*offset)^2+(dirz*offset+centerRad)^2)^0.5)*1.4
				return x + sin(a/2.5*pi)*off, z + cos(a/2.5*pi)*off,angle
			end
			,['SEAGULL']=function(x,z,s,shiftx,shiftz,a,angle,fx,fz,dirx,dirz,sdx,sdz,ratio,offset,minoffset,maxoffset,nlayers,centerRad,off,offx,offz)
				local off = 2*((offx)^2+(offz-centerRad)^2)^0.5
				return x + sin(a/2.5*pi)*off, z + cos(a/2.5*pi)*off,angle+pi/25
			end
			,['CROACH']=function(x,z,s,shiftx,shiftz,a,angle,fx,fz,dirx,dirz,sdx,sdz,ratio,offset,minoffset,maxoffset,nlayers,centerRad,off,offx,offz)
				local off = 1.5*((dirx*offset*2)^2+(dirz*offset)^2)^0.5
				return x + sin(a*pi)*off, z + cos(a/2.5*pi)*off,angle
			end
			,['ARC']=function(x,z,s,shiftx,shiftz,a,angle,fx,fz,dirx,dirz,sdx,sdz,ratio,offset,minoffset,maxoffset,nlayers,centerRad,off,offx,offz)
				local off = fx-x+centerRad+fz-z+centerRad
				return x + sin(a/1.5*pi)*off, z + cos(a/1.5*pi)*off,angle
			end
			,['DAWN']=function(x,z,s,shiftx,shiftz,a,angle,fx,fz,dirx,dirz,sdx,sdz,ratio,offset,minoffset,maxoffset,nlayers,centerRad,off,offx,offz)
				local off = fx-x+centerRad+fz-z+centerRad
				if abs(a)>0.9 then off=-off end
				return x + sin(a/1.5*pi)*off, z + cos(a/1.5*pi)*off,angle
			end
			,['ROUND LEAF 2']=function(x,z,s,shiftx,shiftz,a,angle,fx,fz,dirx,dirz,sdx,sdz,ratio,offset,minoffset,maxoffset,nlayers,centerRad,off,offx,offz)
				return x + (shiftx*a*s)*2.5, z + (shiftz*a*s)*2.5,angle
			end
			,['TWO SQUARED']=function(x,z,s,shiftx,shiftz,a,angle,fx,fz,dirx,dirz,sdx,sdz,ratio,offset,minoffset,maxoffset,nlayers,centerRad,off,offx,offz)
				if a>=0 then offset=offset+minoffset end
				return x+dirx*offset*(sdz*1.5), z+dirz*offset*(sdx*1.5),angle+pi/4
			end
			,['TWO RECTS']=function(x,z,s,shiftx,shiftz,a,angle,fx,fz,dirx,dirz,sdx,sdz,ratio,offset,minoffset,maxoffset,nlayers,centerRad,off,offx,offz)
				if a>=0 then offset=offset+minoffset end
				return x+dirx*offset*sdz*-2, z+dirz*offset*sdx,angle-pi/4
			end
			,['SQUARED']=function(x,z,s,shiftx,shiftz,a,angle,fx,fz,dirx,dirz,sdx,sdz,ratio,offset,minoffset,maxoffset,nlayers,centerRad,off,offx,offz)
				fx,fz = x+dirx*offset, z+dirz*offset
				return fx,fz,angle
			end
			,['BARRAGE']=function(x,z,s,shiftx,shiftz,a,angle,fx,fz,dirx,dirz,sdx,sdz,ratio,offset,minoffset,maxoffset,nlayers,centerRad,off,offx,offz)
				return x-dirx*offset*2, z-dirz*offset,angle
			end
			,['DOUBLE BARREL']=function(x,z,s,shiftx,shiftz,a,angle,fx,fz,dirx,dirz,sdx,sdz,ratio,offset,minoffset,maxoffset,nlayers,centerRad,off,offx,offz)
				local off = ((dirx*offset)^2+(dirz*offset*2)^2)^0.5
				return x + sin(angle-a/2*pi)*off, z + cos(angle-a/2*pi)*off
			end
			,['TRIPLE BARREL']=function(x,z,s,shiftx,shiftz,a,angle,fx,fz,dirx,dirz,sdx,sdz,ratio,offset,minoffset,maxoffset,nlayers,centerRad,off,offx,offz)
				local off = ((dirx*offset)^2+(dirz*offset*2)^2)^0.5
				return x + sin(angle-a/2*pi)*off, z + cos(angle-a/2*pi)*off
			end
			,['TRIPLE BARREL 2']=function(x,z,s,shiftx,shiftz,a,angle,fx,fz,dirx,dirz,sdx,sdz,ratio,offset,minoffset,maxoffset,nlayers,centerRad,off,offx,offz)
				local off = ((dirx*offset)^2+(dirz*offset*2)^2)^0.5
				return x + sin(angle-a/1.5*pi)*off, z + cos(angle-a/1.5*pi)*off
			end
			,['BUTTERFLY']=function(x,z,s,shiftx,shiftz,a,angle,fx,fz,dirx,dirz,sdx,sdz,ratio,offset,minoffset,maxoffset,nlayers,centerRad,off,offx,offz)
				local off = ((dirx*offset*2)^2+(dirz*offset*0.5)^2)^0.5
				return x + sin(angle-a*pi)*off, z + cos(angle-a*pi)*off
			end
			,['BEE 2']=function(x,z,s,shiftx,shiftz,a,angle,fx,fz,dirx,dirz,sdx,sdz,ratio,offset,minoffset,maxoffset,nlayers,centerRad,off,offx,offz)
				local off = max(((dirx*offset*1)^2+(dirz*offset*0.50)^2)^0.5, 0.00001)
				return x+shiftx*(offset/off), z+shiftz*(offset/off),angle+pi/2
			end
			,['FLOWER']=function(x,z,s,shiftx,shiftz,a,angle,fx,fz,dirx,dirz,sdx,sdz,ratio,offset,minoffset,maxoffset,nlayers,centerRad,off,offx,offz)
				return x+dirx*(1.5-ratio)*offset*3, z+dirz*(1.5-ratio)*offset*3,angle
			end
			,['FLOWER 2']=function(x,z,s,shiftx,shiftz,a,angle,fx,fz,dirx,dirz,sdx,sdz,ratio,offset,minoffset,maxoffset,nlayers,centerRad,off,offx,offz)
				ratio=max(ratio,0.0001)
				return x+(dirx/ratio)*offset*2/ratio, z+(dirz/ratio)*offset*2/ratio,angle
			end
		}

	--------------------------------------------------
	---------- CONTROLS module initialization --------
	--------------------------------------------------

		function CONTROLS:Initialize()

			CONTROLS.statuses=actHotkeys

			CONTROLS.instants = {
				 fmode=true
				,unshifted=true
				,browse=true
				,grab=true
				,move_rotate=true
				,cleanmem=true
				,reset_offset=true
				,unposed=true
				,unrposed=true
				,debug_layer=true
				,debug_uradius=true
				,reload_widget=true
				,debug_echo=true
				,instant_regroup=true
			}


			----- gathering unique conditions for debugging and saving useless checks -----
			CONTROLS.uniques_cond= {}
			for _,status in ipairs(CONTROLS.statuses) do 
				for _,cond in ipairs(status) do
			 		cond = cond:gsub('[!%?]','')
			 		CONTROLS.uniques_cond[cond]=true
			 	end
			 end

			------- simplify and lower KEYCODES for our use --------
			for num,key in pairs(KEYCODES) do
				if key:match('CTRL') or key:match('ALT') or key:match('SHIFT') then key=key:gsub('^[LR]','') end	
				KEYCODES[num]=key:lower()
			end
		end
		----------------------------------------------------

	--------------------------------------------------
	-------- Set Custom Formation 2 variables --------
	--------------------------------------------------

		local function DefineCF2()
			local CF2 = widgetHandler:FindWidget('CustomFormations2')
			if not CF2 then spSendCommands("luaui enablewidget CustomFormations2")
				CF2 = widgetHandler:FindWidget('CustomFormations2')
				if not CF2 then Debug('Army Formation require widget CustomFormation2, shutting down.') widgetHandler:RemoveWidget(widget) return end
			end
			-- change and/or signal we want to keep the modified version of 'GiveNonNotifyingOrder' function
		    if not CF2._GiveNonNotifyingOrder then
		        local GiveNotifyingOrder = f.GetUpvaluesOf(CF2.MouseMove,'GiveNotifyingOrder')
		        local GiveNonNotifyingOrder,num  = f.GetUpvaluesOf(CF2.MouseMove,'GiveNonNotifyingOrder')
		        CF2._GiveNonNotifyingOrder = GiveNonNotifyingOrder
		        debug.setupvalue(CF2.MouseMove, num, GiveNotifyingOrder)
		    end
		    CF2.modifiedBy = CF2.modifiedBy or {}
		    CF2.modifiedBy[widget:GetInfo().name]=true
		    ---------------------------------
			findHungarian = CF2.findHungarian
		    GetOrdersHungarian = CF2.GetOrdersHungarian
			GetOrdersNoX = CF2.GetOrdersNoX
			-- getting upvalue of MouseRelease of CF2 to get updated for choosing either Hungarian or NoX method, 
			f.Page(f.GetUpvaluesOf(CF2.MouseRelease),2)
			CF2_MatchUnitsToNodes = CF2.MatchUnitsToNodes
			local _
			_,MHU_num = f.GetUpvaluesOf(CF2_MatchUnitsToNodes,'maxHungarianUnits')
			
			-- slightly different for MousePress, the real function is not CF2.MousePress but an upvalue of it called 'func'
			CF2_MousePress = f.GetUpvaluesOf(CF2.MousePress,'func')
			_,FCMDS_num = f.GetUpvaluesOf(CF2_MousePress,'formationCmds')
			
			return true
		end

		local function DefineSAC()
			local SAC = widgetHandler:FindWidget('Show All Commands v2')
			if SAC then
				Spring.LoadCmdColorsConfig("alwaysDrawQueue 0")
				local RemoveUnit = f.GetUpvaluesOf(SAC.PoolUnit,'RemoveUnit')
				local AddUnit = f.GetUpvaluesOf(SAC.PoolUnit,'AddUnit')
				local Update = f.GetUpvaluesOf(SAC.Update,'func')
				local updateDrawing,num = f.GetUpvaluesOf(Update,'updateDrawing')
				local _,numsel = f.GetUpvaluesOf(updateDrawing,'selectedUnitCount')
				AllowDrawCmds = function(ids,n)
					debug.setupvalue(updateDrawing, numsel, n)
					for id in pairs(ids) do AddUnit(id) end
				end
				PreventDrawCmds = function(ids)
					debug.setupvalue(updateDrawing, numsel, 0)
					for id in pairs(ids) do RemoveUnit(id) end
				end
		-- 	
			end
		end
	--------------------------------------------------
	--------------- WIDGET STARTING ------------------
	--------------------------------------------------

		f.DebugWidget(widget)
		function widget:Initialize()
			    if Spring.GetSpectatingState() or Spring.IsReplay() then
			        Spring.Echo(widget:GetInfo().name..' disabled for spectators')
			        widgetHandler:RemoveWidget()
			        return
			    end
			------------UnitsIDCard------------
			    if not WG.UnitsIDCard then
					Echo('UnitsIDCard is required for ArmyFormation to work') widgetHandler:RemoveWidget(self)
					return
			    end
			    Units=WG.UnitsIDCard
			    Units.subscribed[widget:GetInfo().name]=true
		    	UDS = UnitDefs
				myTeamID = Spring.GetMyTeamID()
		    ----------------- Set Class Colors ----------------------
		    	ConfigSetColors()
		    -------------------- update keys ------------------------
		    	-- unused for key_name,opt in pairs(options) do if opt.hotkey then opt.OnHotkeyChange() end end
		    ----------- define Debug functions object ---------------
		    	Debug:Define()
		    --------get CF2 components and modify a function---------
		    	if not DefineCF2() then return end
			--------get Show All Commands component
				-- Set Access to some upvalues of Show All Commands to modify its units to draw
				-- so I can suppress the drawing of formation commands even when show selecion commands is enabled
				DefineSAC()

			--go before CF2
			    widgetHandler:LowerWidget(self)
			------------ CONTROLS module initialization -------------
				CONTROLS:Initialize()
		    ------- unused own callin for click detection ------
		    	--if WG.MyClicks then WG.MyClicks[self]=MyClicks end
		    ------- own callin for zone click detection ------
		    	if WG.MyZones then
					ZONES:DefineActions()
					ZONES.ci = MyZones
					WG.MyZones[self]=ZONES
				end
			-------- Set txt position ---------
				widget:GetViewSizes(widgetHandler:GetViewSizes())

			----automatic callin disabler-----
		    	DisableOnSpec(widgetHandler,widget)
		    --- unused --- TODO: need to find a way to activate/deactivate or change unit icon
				--[[
					local IZT = widgetHandler:FindWidget('Icon Zoom Transition')
			    	if IZT then IZT_LeftLos,IZT_EnteredLos = IZT.UnitLeftLos,IZT.UnitEnteredLos end
			    --]]
		    -------------------------
				Debug('<<<Army Formation Loaded>>>')
			-------------------------
				widget:SelectionChanged(Spring.GetSelectedUnits(),false)

		end

		function widget:SetConfigData(data)
			MEMORY=data.MEMORY or MEMORY
			FORMATION:UpdateShapesOrder()
		end

		function widget:GetConfigData()
			return {MEMORY=MEMORY}
		end

------------------------------------------------------------------------------------
------------------------------------------------------------------------------------
---------------------------------- DRAWING -----------------------------------------
------------------------------------------------------------------------------------
------------------------------------------------------------------------------------

	do 
	----------------------------------------------------------------------------
	--------------------------- Initialization ---------------------------------
	----------------------------------------------------------------------------
		--------color constants----------
			local default = {1,1,1,1}
			local ghost = {1,1,1,0.45}
			local ghost_spotted = {1,1,1,0.75}
			local ghost_selected = {0,1,0,0.35}
			local path_ghost = {1,1,1,0.15}
			local ghost_shapeshift = {1,0.5,1,0.40}
			local ghost_angle = {1,0.5,0,0.40}
			local white = {1,1,1,1}  
		--------- speed ups -------------
			local glPushMatrix 			= gl.PushMatrix
			local glLineWidth 			= gl.LineWidth
			local glColor 				= gl.Color
			local glDrawGroundCircle 	= gl.DrawGroundCircle
			local glPopMatrix 			= gl.PopMatrix
			local glPointSize 			= gl.PointSize
			local glBeginEnd 			= gl.BeginEnd
			local glDepthTest 			= gl.DepthTest
			local glVertex 				= gl.Vertex
			local glBillboard 			= gl.Billboard
			local glText 				= gl.Text
			local glTranslate 			= gl.Translate
			local glScale				= gl.Scale
			local glRotate				= gl.Rotate
			local GL_LINES 				= GL.LINES
			local GL_POINTS 			= GL.POINTS
			local GL_ALWAYS 			= GL.ALWAYS
			local GL_LINE_STRIP			= GL.LINE_STRIP
			local GL_TRIANGLES			= GL.TRIANGLES
			local spGetUnitMoveTypeData = Spring.GetUnitMoveTypeData
			local deg 					= math.deg
		----- exclusives function -------
			local function drawPoint(point) if point.color then glColor(point.color) else glColor(1, 1, 1, 1) end glVertex(unpack(point)) end
			local Set_ColorAndSize = (function()
				local white,defaultsize,color,size=colors.white,5
				return function(point)
					local new_color,new_size = point.color or white, point.size or defaultsize
					if new_color~=color then color=new_color glColor(color) end
					if new_size~=size then size=new_size glPointSize(size) end
				end
			end)()
			local function circle(pos,r,color)
				local x,y,z = unpack(pos)
				if color then glColor(color) end
				glPushMatrix() glDrawGroundCircle(x,y,z,r, 40) glPopMatrix()
			end
			local function vertex (x,y,z) glVertex(x,y,z) end
			local function line(x,y,z,ox,oy,oz)	glVertex(x,y,z)	glVertex(ox,oy,oz) end
			local function PointVertice(points) for _,point in ipairs(points) do glVertex(unpack(point)) end end
			local function OrderVertice(orders,toEnd) for i,order in ipairs(orders) do glVertex(unpack(toEnd and order.to or order.from)) end end
			local function OrderShapeShift(orders) for i,order in ipairs(orders) do if order.shapeshift then glVertex(unpack(order.from)) end end end
			local function OrderExpands(orders) for i,order in ipairs(orders) do if order.expand_mark then glVertex(unpack(order.from)) end end end
			local function OrderAngles(orders) for i,order in ipairs(orders) do if order.mark_mod_angle then glVertex(unpack(order.from)) end end end
			local function drawRect(x,y,z,s)
			 	glVertex(x + s, y, z + s)
				glVertex(x + s, y, z - s)
				glVertex(x - s, y, z - s)
				glVertex(x - s, y, z + s)
				glVertex(x + s, y, z + s)
			end
			local function ArrowFuncVert()
				-- stick bottom/left
				glVertex( 0, 0, -8) -- base left (0,0,-8)
				glVertex( 0, 0, 8) --
				glVertex( 57, 0, -3)
				-- stick top/right
				glVertex( 0, 0,  8)  -- base right (0,0,8)
				glVertex( 57, 0, 3)
				glVertex( 57, 0, -3 )
				-- stick_to_tip junction
				glVertex( 60, 0,  0) -- end (50)
				glVertex( 57, 0, 3)
				glVertex( 57, 0, -3 )
				-- left wing
				glVertex( 60, 0, 0) --base(80)
				glVertex( 45, 0, 15 ) --start (30,0,30)
				glVertex( 80, 0, 0 ) -- wing tip
				-- right wing
				glVertex( 60, 0, 0) --base (80)
				glVertex( 45, 0, -15 ) --base (30,0,-30)
				glVertex( 80, 0, 0 ) -- wing tip
			end
			-- DrawArrow params can be either with both ends or a starting point with given angle, length can be given, or defined by ends or 80 by default
			local function DrawArrow(from,to,angle,length)
				local fx,fy,fz = unpack(from)
				local tx,ty,tz
				if not angle then
					tx,ty,tz = unpack(to)
					angle = atan2(tx-fx,tz-fz)
				end
				length = length and length/80 or to and ((tx-fx)^2 + (tz-fz)^2)^0.5 / 80 or 1
				glPushMatrix()
				glTranslate(fx,fy,fz)
				glRotate( deg(angle)-90, 0, 1, 0 )
				glScale( length, 0, length )
				glBeginEnd( GL_TRIANGLES, ArrowFuncVert )
				glScale( 1.0, 1.0, 1.0)
				glPopMatrix()
			end
			local function glDoText(texts,trans)
		        glPushMatrix()
		        if trans then 
		        	glTranslate(unpack(trans))
		        	glBillboard()
		        end
		        for _,text in ipairs(texts) do
		        	glText(unpack(text))
		        end
		        glPopMatrix()
			end

	----------------------------------------------------------------------------
	------------------------------- Main ---------------------------------------
	----------------------------------------------------------------------------
		
		function widget:DrawScreen()
		---- draw interactive zones
		    glColor(1, 1, 0.5, 0.6)
		    for i,zone in ipairs(ZONES) do
		    	glColor(zone.color)
   	    		glDoText({zone.draw})
   	    	end
		---- debug CONTROLS
			if Debug.Ctrls.On then
			    glColor(1, 1, 1, 1)
			    glDoText({{'current:'..CONTROLS.debugstr,  txtx*1/4,txty*3/5, 20}})
			    glColor(1, 1, 0.5, 0.6)
		   	    glDoText({{'cond:'..CONTROLS.debugstr2, txtx*1/4,txty*2.9/5, 12}})
			    glColor(1, 1, 1, 1)
		   	    glDoText({{'instant:'..CONTROLS.debugstr3, txtx*1/4,txty*2.8/5, 12}})
			    glColor(1, 1, 0.5, 0.6)
		   	    glDoText({{'last:'..CONTROLS.debugstr4, txtx*1/4,txty*2.7/5, 12}})
		   	end
		--- Draw Formation Shape Name
			if not (drawFormationName and C) then return end
		    glColor(1, 1, 0, 0.6)
		    glDoText({{SHAPES[C.shape_num], txtx*1/4,txty*1/2, 20}})
		    glColor(1, 1, 1, 1)
		   ----------------------
		end
		function widget:DrawWorld()
			glDepthTest(GL_ALWAYS)
			if C then
			----------------Draw Spotted Order ------------------
				if CONTROLS.spottedOrder then
					local order = CONTROLS.spottedOrder
					local f = order.f
					local pos = order.from or order.to

					circle(pos,50,colors.orange)
	            	glColor(ghost_spotted)

					local texts= {
						 {	'name:'	..order.name..'\n'
						  ..'shape:'..SHAPES[order.shape_num]..'\n'
						  ..'angle:'..order.angle..'\n'
						  ..'expand:'..order.expand
						  , 0,0,12,'h' }
	            	}
	            	glDoText(texts, pos)
	            	-- Drawing one Arrow showing formation orientation
	            	if CONTROLS.distSpotted>MOVE_SPOT then
		            	local x = pos[1] - sin(order.angle)*40
						local z = pos[3] - cos(order.angle)*40
						local y = spGetGroundHeight(x,z)
						DrawArrow({x,y,z},false,order.angle,80)
					else
					-- Drawing four arrows moving symbol
						DrawArrow(pos,false,order.angle,40)
						glColor(ghost)
						DrawArrow(pos,false,order.angle+pi/2,40)
						DrawArrow(pos,false,order.angle-pi/2,40)
						DrawArrow(pos,false,order.angle+pi,40)
					end
				end
			-------- Draw Current Formation ghost points --------
				if C.update_ghost then
					glPointSize(5)
					glColor(ghost)
					for _,uType in pairs(C.uTypes) do
			 			glBeginEnd(GL_POINTS, PointVertice,uType.gPoints)
					end
				else
					glPointSize(25)
					glColor(ghost)
					C:UpdatePoses(C.ghost_center)
					glBeginEnd(GL_POINTS, function()  glVertex(unpack(C.ghost_center))  end)
				end
			------------ Show PROJECT points and frame ----------
				--if not CONTROLS.spottedOrder then
					local x,y,z = unpack(C.aim_center)
					local ox,oy,oz = unpack(outPoint)
					local rad = C.rad
					-- Draw formation Project Points
					glPointSize(5)
					for _,uType in pairs(C.uTypes) do
						if CONTROLS.grabbing then uType.color[4]=0.5 end
						glColor(uType.color)
			 			glBeginEnd(GL_POINTS, PointVertice,uType.points)
						if CONTROLS.grabbing then uType.color[4]=1 end
					end
					-- Draw Center Point
					glPointSize(10)
					glColor(1,1,0,1)
					glBeginEnd(GL_POINTS, vertex, x,y,z)
					-- Draw Frame of formation
					glColor(1,0.3,0,1)
					glBeginEnd(GL_LINE_STRIP, drawRect, x,y,z,rad)
					-- Draw Circle Containing Formation
					glColor(1,0,0,1)
					glPushMatrix()
					glDrawGroundCircle(x, y, z, rad, 40)
					glPopMatrix()
					-- Draw Formation Direction with mouse
					if not CONTROLS.lock_angle then
						glBeginEnd(GL_LINES, line, x,y,z,ox,oy,oz)
					end
				--end
			------------- Debug centers positions ---------------
				--[[			
				local centers = {'center','last_center','aim_center','pose_center'--[==[,'project_center'--]==]--[==[,'ghost_center'--]==]}
				for i,cen in ipairs(centers) do
	           		glColor(colors.white)
	           		glDoText({{cen, 0,30-i*15,30,'h'}},C[cen] )
	    		end
		    	--]]	
			----------- Debug Sublayers main infos --------------
				if CONTROLS.debug_layerON then
					local cen = C.ghost_center
					for l,layer in ipairs(C.layers) do
						glColor(layerColors[l])
						for s,sub in ipairs(layer.sublayers) do
							glDoText(
								{	
									{l..'.'..s,sub.rad,8,12,'h'}
									,{'u:'..sub.n,sub.rad,0,10,'h'}
									,{'c:'..round(sub.contains,1),sub.rad,-6,7,'h'}
									,{'r:'..round(sub.rad,1),sub.rad,-17,10,'h'}
								}
								,cen
							)
							circle(cen,sub.rad,layerColors[l])
						end
					end
					glLineWidth(3)
					circle(cen,C.rad,colors.white)
					glLineWidth(1)
				end
			----------- Debug Sublayer points/units -------------
				if Debug.Layers.On then
					for l, layer in ipairs(C.layers) do
						glColor(layerColors[l])
						for s,sub in ipairs(layer.sublayers) do
							for i,unit in ipairs(sub) do
								glDoText({{unit.point.l..'.'..unit.point.s,0,0,12,'h'}},unit.point)
								glDoText({{unit.l..'.'..unit.s,0,0,12,'h'}},unit.pos)
								glDoText({{unit.point.sn,0,-7,10,'h'}},unit.point)
							end
						end
					end
				end
			--------------- Debug Unit Radiuses ----------------
				if CONTROLS.debug_uradiusON then
					for id,unit in pairs(C.allIDs) do
						circle(unit.pos,unit.r,colors.orange)
					end
				end
			----------------------------------------------------
			end
			---- Treat Actives formations 
				if ACTIVES.n>0 then
					for i,f in ipairs(ACTIVES) do
					-- draw moving points
						glPointSize(5)
						glColor(1,0,0,1)
						--[[--draw unit.mPoint
							for id,unit in pairs(f.allIDs) do
								glBeginEnd(GL_POINTS, function() glVertex(unpack(unit.mPoint)) end) 
							end
						--]]
												
						if f.temoins and next(f.temoins,nil) then
							for _,tem in pairs(f.temoins) do glBeginEnd(GL_POINTS, function() glVertex(unpack(tem)) end) end
						end
						
					-- draw ghost center used as spotting
						glColor(f.spotted and ghost_spotted or ghost)
						--[[-- as big point
							glPointSize(15)
							glBeginEnd(GL_POINTS, vertex, unpack(f.ghost_center))
						--]]
						--as arrow indicating orientation
						
						local x = f.ghost_center[1] - sin(f.gAngle)*40
						local z = f.ghost_center[3] - cos(f.gAngle)*40
						local y = spGetGroundHeight(x,z)
						DrawArrow({x,y,z},false,f.gAngle,80)
					-- draw other than current formation's ghost points
						if f~=C then
							glPointSize(5)
							for _,uType in pairs(f.uTypes) do
					 			glBeginEnd(GL_POINTS, PointVertice,uType.gPoints)
							end
						end
					-- draw orders
						if f.orders[1] then
							glColor(path_ghost)
							glBeginEnd(GL_LINE_STRIP, OrderVertice, f.orders, 'end')
							glPointSize(5)
							glBeginEnd(GL_POINTS, OrderVertice, f.orders, 'end')
							-- show shapeshifts
							glPointSize(10)
							glColor(ghost_shapeshift)
							glBeginEnd(GL_POINTS, OrderShapeShift,f.orders)
							-- show expands changements
							glPointSize(7)
							glColor(ghost)
							glBeginEnd(GL_POINTS, OrderExpands,f.orders)
							-- show angle changements
							glPointSize(7)
							glColor(ghost_angle)
							glBeginEnd(GL_POINTS, OrderAngles,f.orders)
							--
							glColor(white)
							for i,order in pairs(f.orders) do
								if tonumber(i) then
									-- show name of orders
									local prevO=f.orders[i-1]
									local nextO=f.orders[i+1]
									local off = prevO and prevO.name=='Rotate' and order.name=='Move' and -8 or 0
		           					glDoText({{order.name..'#'..order['#'], 0,off,10,'h'}},order.from )
		           					-- show Rotate as Arrow from move_rotate order
	           						if order.name=="Rotate" and order.strict then
	           							DrawArrow(order.from,false,order.angle,80)
	           						end
	           						--
		           				end
		           			end
		           			--glDoText({{'angle:'..f.gAngle, 0,0,10,'h'}},f.ghost_center )
						---------------- Debug Unit At Infos -------------------
							if f.moving and Debug.At.On then
						        for id,unit in pairs(f.allIDs) do
						            local uMoves = unit.uMoves
						            local md = spGetUnitMoveTypeData(id)
						            local maxWantedSpeed = round(md.maxWantedSpeed)
						            local wantedSpeed = round(md.wantedSpeed)
						            -- if wantedSpeed==0 or wantedSpeed==2000 then wantedSpeed=unit.speed end
						            local curSpeed = round(md.currentSpeed)
			            			local ownWantedSpeed = round(unit.wantedSpeed[1])
			            			if ownWantedSpeed==0 then ownWantedSpeed=unit.speed end
			            			-- if uMoves.status~='arrived' and curSpeed/ownWantedSpeed<0.3 then
			            			-- 	Echo("Bad speed",'current: '..curSpeed,'mdMaxWanted: '..maxWantedSpeed,'mdWanted: '..wantedSpeed,'ownWanted: '..ownWantedSpeed)
			            			-- 	for k,v in pairs(md) do Echo(k,v) end
			            			-- end
			            			local pathing = (md.currwaypointx~=md.goalx or md.currwaypointz~=md.goalz) and 'contourning' or 'straight'
			            			local stuck = pathing=='contourning' and (curSpeed==0 or curSpeed/ownWantedSpeed<0.3)

			            			local color = (uMoves.status=='arrived' or uMoves.status=='undefined') and 'yellow'
			            				 or pathing=='contourning' and (stuck and 'red' or 'green')
			            				 or 'white' 
			            			local order = unit.f.orders[1]
			            			local order_num = order and order['#'] or 0
			            			local title = uMoves.status..' at #'..order_num..' ('..uMoves.completed..'/'..uMoves.total..')'
			            			-- local title = order.name..' #'..order_num
					            	glColor(colors[ color ])
					            	local texts= {
					            		 {title, 0,0,12,'h'}
					            		-- ,{'speed:'..curSpeed..'/'..ownWantedSpeed..'/'..wantedSpeed..'/'..maxWantedSpeed, 0,-15,8,'h'}
					            		-- {'speed:'..curSpeed..'/'..ownWantedSpeed, 0,-15,8,'h'}
					            		-- ,{'id:'..id, 0,-30,8,'h'}
					            	}
					            	glDoText(texts, unit.pos)
						        end
					            glColor(1, 1, 1, 1)
					    	end
						end
					end
				end
			------ Debug manual Points and Circles ------
				if next(Circles,nil) then
					for _,circle in pairs(Circles) do
						local x,y,z,r,col = unpack(circle)
						glColor(col)
						--glBeginEnd(GL_LINE_STRIP, drawRect, x,y,z,r)
						glPushMatrix()
						glDrawGroundCircle(x,y,z,r, 40)
						glPopMatrix()
					end
				end
				if next(Points,nil) then
					local color,size = colors.white,5
					glColor(1, 1, 1, 1)
					glPointSize(5)
					for _,point in pairs(Points) do
						Set_ColorAndSize(point)
						glBeginEnd(GL_POINTS, drawPoint,point)
					end
					glPointSize(1.0)
				end
				if next(Texts,nil) then
					local color,size = colors.white,5
					glColor(1, 1, 1, 1)
					glPointSize(5)
					for _,text in pairs(Texts) do
						glDoText(text,text.pos)
					end
					glPointSize(1.0)
				end
			------------------- reset -------------------
				glPointSize(1)
				glColor(1,1,1,1)
				glDepthTest(false)
		end
	end

-------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------
--------------------------- PREFERENCES MANAGEMENT ----------------------------------
-------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------

	function FORMATION:CreateScoring() -- set a score name by ratio of unit's class and memorize  it
		local total = self.size
		local scores = {}
		for class in pairs(CONFIG) do
			scores[class]=0
		end
		for _,uType in pairs(self.uTypes) do
			local class = Units[uType.ids[1]].class
			local n = uType.n
			scores[class] = scores[class]+n
		end
		local srt_form = ''
		for class,score in pairs(scores) do
			score = round(round(score/total*5)/5*100)
			srt_form=srt_form..score..','
		end
		srt_form:sub(1,srt_form:len()-2)
		self.score = {srt_form=srt_form,shapes={},expands={},actions=0}
	end

	function FORMATION:SetScore() -- on each action of the player, add to stats the expand and shape used
		local score = self.score
		score.actions=score.actions+1
		local shape_num = self.moving_shape_num
		local shape = SHAPES[shape_num]
		score.shapes[shape_num] = (score.shapes[shape_num] or 0) + 1
		local exp = round(round(self.expand*3)/3,2)
		score.expands[exp] = (score.expands[exp] or 0) + 1
		-- also count the total shapes used to refine order of browsing
		MEMORY.most_used_shapes[shape] = MEMORY.most_used_shapes[shape]+1
	end

	function FORMATION:MemorizeScore() -- before changing formation make some stats and put in memory with the srt_form as reference reference
		local score = self.score
		if score.actions==0 then return end
		-- get the most used shape
		local best_shape,shape_sc = 1,0
		for num,sc in pairs(score.shapes) do if sc>shape_sc then best_shape,shape_sc = num,sc end end
		-- get an average of the expands used 
		local expands = score.expands
		local n_exp,total_exp=0,0
		for exp,n in pairs(expands) do n_exp,total_exp=n_exp+n,total_exp+exp*n end
		local avg_expand = round(total_exp/n_exp,2)

		--
		local memory = MEMORY.formations[self.srt_form]
		local actions = score.actions
		if memory then
			memory.expands[avg_expand]= (memory.expands[avg_expand] or 0) + actions
			memory.shapes[best_shape] = (memory.shapes[best_shape] or 0)  + actions
		else
			MEMORY.formations[score.srt_form]={expands={[avg_expand]=actions},shapes={[best_shape]=actions}}
		end

		self.score = {srt_form=score.srt_form,shapes={},expands={},actions=0}
	end

	function FORMATION:RecallPreferences()
		local memory = MEMORY[self.score.srt_form]
		if memory then
			-- get the most used shape
			local best_shape,shape_sc = 1,0
			for num,sc in pairs(memory.shapes) do if sc>shape_sc then best_shape,shape_sc = num,sc end end
			-- get an average of the expands used 
			local expands = memory.expands
			local n_exp,total_exp=0,0
			for exp,n in pairs(expands) do n_exp,total_exp=n_exp+n,total_exp+exp*n end
			local avg_expand = total_exp/n_exp
			return best_shape,avg_expand
		end
		return 1,1
	end

	function FORMATION:UpdateShapesOrder()
		local most_used_shapes = MEMORY.most_used_shapes
		local new_order = {} for i,name in ipairs(SHAPES) do new_order[i]=name end
		local sortfunc = function(a,b) return most_used_shapes[a]>most_used_shapes[b] end
		table.sort(new_order,sortfunc)
		for i,name in ipairs(new_order) do new_order[name]=i end
		new_order.n=SHAPES.n

		-- correct the scores shape_nums
		for _,mem_f in pairs(MEMORY.formations) do
			local mem_shapes=mem_f.shapes
			for num,score in pairs(mem_shapes) do 
				local name = SHAPES[num]
				local new_num=new_order[name]
				mem_shapes[num], mem_shapes[new_num] = nil, score
			end
			--Page()
		end
		-- correct the orders shape_num
		for i,f in ipairs(ACTIVES) do
			for i,order in ipairs(f.orders) do
				local num = order.shape_num
				local name = SHAPES[num]
				local new_num=new_order[name]
				order.shape_num = new_num
			end
			-- correct the current moving shape num
			if f.moving_shape_num then
				local num = f.moving_shape_num
				local name = SHAPES[num]
				local new_num=new_order[name]
				f.moving_shape_num = new_num
			end
		end
		SHAPES=new_order
		Echo('now first shapes are:',SHAPES[1],SHAPES[2],SHAPES[3])
	end

-------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------
-------------------------------- WIDGET ENDING --------------------------------------
-------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------

	function widget:GameOver()
	    widgetHandler:RemoveWidget(self)
	end

	function widget:Shutdown()
	    if Units then Units.subscribed[widget:GetInfo().name]=nil end
	    local CF2 = widgetHandler:FindWidget('CustomFormations2')
	    if CF2 then
	        if CF2.modifiedBy then
	            CF2.modifiedBy[self:GetInfo().name]=nil
	            if not next(CF2.modifiedBy,nil) then
	                if CF2._GiveNonNotifyingOrder then
	                    local _,num  = f.GetUpvaluesOf(CF2.MouseMove,'GiveNonNotifyingOrder')
	                    debug.setupvalue(CF2.MouseMove, num, CF2._GiveNonNotifyingOrder)
	                    CF2._GiveNonNotifyingOrder=nil
	                end
	            end
	        end
	    end
	    if WG.MyClicks then WG.MyClicks[self]=nil end
	    if WG.MyZones then WG.MyZones[self]=nil end
	    CONTROLS.Reset()
	    C=false
	end


