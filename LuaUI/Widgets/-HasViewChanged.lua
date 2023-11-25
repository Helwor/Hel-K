-- $Id: gfx_outline.lua 3171 2008-11-06 09:06:29Z det $
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--
--  file:    gfx_outline.lua
--  brief:   Displays a nice cartoon like outline around units
--  author:  jK
--
--  Copyright (C) 2007.
--  Licensed under the terms of the GNU GPL, v2 or later.
--
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function widget:GetInfo()
	return {
		name      = "HasViewChanged",
		desc      = "Tell if view may have changed to lessen Draw work and gives VisiblesUnits",
		author    = "Helwor",
		date      = "May 2023",
		license   = "GNU GPL, v2 or later",
		layer     = -10e38,
		enabled   = true,  --  loaded by default?
		api		  = true,
	}
end
local Echo = Spring.Echo
local spIsUnitVisible = Spring.IsUnitVisible
local spIsUnitInView = Spring.IsUnitInView
local spIsUnitIcon = Spring.IsUnitIcon
local spGetVisibleUnits = Spring.GetVisibleUnits
local spGetCameraPosition = Spring.GetCameraPosition
local spGetCameraVectors = Spring.GetCameraVectors
local spGetCameraFOV = Spring.GetCameraFOV
local spGetGameFrame = Spring.GetGameFrame
local spGetCameraState = Spring.GetCameraState
local spTraceScreenRay = Spring.TraceScreenRay
local spGetUnitHealth = Spring.GetUnitHealth
local spGetUnitPosition = Spring.GetUnitPosition
local spGetUnitDefID = Spring.GetUnitDefID
local spGetSpectatingState = Spring.GetSpectatingState
local spGetAllUnits = Spring.GetAllUnits
local spGetUnitLosState = Spring.GetUnitLosState
local spGetGlobalLos = Spring.GetGlobalLos
local spGetLocalAllyTeamID = Spring.GetLocalAllyTeamID
local spGetMyTeamID = Spring.GetMyTeamID
local spAreTeamsAllied = Spring.AreTeamsAllied
local spGetUnitAllyTeam = Spring.GetUnitAllyTeam
local spGetUnitTeam = Spring.GetUnitTeam
local ALL_UNITS       = Spring.ALL_UNITS
local spGetMyAllyTeamID = Spring.GetMyAllyTeamID
local spGetUnitViewPosition = Spring.GetUnitViewPosition
local spGetUnitIsDead = Spring.GetUnitIsDead
local spValidUnitID = Spring.ValidUnitID
local spGetUnitPosition = Spring.GetUnitPosition
local Units = {}
local UPDATE_FRAME_HEALTH = 5

local myTeamID = spGetMyTeamID()
local DUMMY_HEALTH = {50,50,0,0,1}
local ignoreHealthUnitDefID = {
  [UnitDefNames['wolverine_mine'].id] = true,
  [UnitDefNames['shieldscout'].id] = true,
  [UnitDefNames['jumpscout'].id] = true,
  -- [UnitDefNames['terraunit'].id] = true,
}
local structureDefID = {}
do
	local spuGetMoveType = Spring.Utilities.getMovetype
	for defID, def in pairs(UnitDefs) do
		if not spuGetMoveType(def) then
			structureDefID[defID] = true
		end
	end
end
local vsx, vsy = Spring.GetViewGeometry()

local currentFrame = spGetGameFrame()
local requestUpdate
local NewView
local Visibles
local inSight
local Cam
local fullview
local center_x, center_y = vsx/2, vsy/2 -1
local UpdateVisibleUnits, OriUpdateVisibleUnits, Ori2UpdateVisibleUnits, AltUpdateVisibleUnits, NewUpdateVisibleUnits
-- local f = VFS.Include("LuaUI\\Widgets\\UtilsFunc.lua")
local function HaveFullView()
	local spec, _fullview = spGetSpectatingState()
	local fullview = _fullview and 1 or spGetGlobalLos(spGetLocalAllyTeamID()) and 2
	return fullview
end
local function GetPos(self,threshold,mid) -- method of unit to get its position, to be used by any widget, threshold is the frame delta acceptance
    local pos = self.pos
	if mid then
		local update
		if not pos.midframe then
			pos.midframe = true
			pos.frame = currentFrame
			update = true
		elseif not self.isStructure and pos.frame < currentFrame + (threshold or 0) then
			update = true
			pos.frame = currentFrame
		end
		if update then
			pos[1], pos[2], pos[3], pos[4], pos[5], pos[6] = spGetUnitPosition(self.id,true)
		end
		return pos[1], pos[2], pos[3], pos[4], pos[5], pos[6]
	end
    if not self.isStructure and pos.frame < currentFrame + (threshold or 0) then
    	pos.midframe = false
    	pos.frame = currentFrame
        pos[1], pos[2], pos[3] = spGetUnitPosition(self.id)
    end
    return  pos[1], pos[2], pos[3]

end
local function SafeTrace()
    local type,pos = spTraceScreenRay(center_x, center_y,true,false,true,true)
    if type=='sky' then
        for i=1,3 do
            pos[i], pos[i+3] = pos[i+3], nil
        end
    end
    return pos
end
-- Echo("#Spring.GetVisibleUnits(-1, nil, false) is ", #Spring.GetVisibleUnits(-1, nil, false), #spGetVisibleUnits(-1, nil, false) )
local GetDist = function()
    local cs = Cam.state
    local dist,relDist
    if cs.mode == 4 then
        local pos =  Cam.trace
        dist = ((cs.px-pos[1])^2 + (cs.py-pos[2])^2 + (cs.pz-pos[3])^2)^0.5
    else
        -- ez
        dist = cs.height
    end
    return dist
end
-- each param is stored in unique table for widget to keep around as local
local lag, lagref = 0, 0.033

WG.lag = WG.lag or {Spring.GetLastUpdateSeconds() or 0.033}
local lag = WG.lag
WG.NewView = WG.NewView or {0,0,0,0,0}
NewView = WG.NewView
WG.Visibles = WG.Visibles or {any = {},icons = {}, not_icons = {}, anyMap = {}, iconsMap = {}, not_iconsMap = {}}
Visibles = WG.Visibles

WG.Cam  = WG.Cam or  {Units={}, pos={}, inSight = {}}
Cam = WG.Cam
Cam.frame 	= spGetGameFrame()
Cam.pos[1], Cam.pos[2], Cam.pos[3] =	spGetCameraPosition()
Cam.vecs 	= spGetCameraVectors()
Cam.fov 	= spGetCameraFOV()
Cam.state 	= spGetCameraState()
Cam.trace 	= SafeTrace()
Cam.dist 	= GetDist()
Cam.fullview = HaveFullView()
Cam.relDist = Cam.dist * (Cam.fov / 45)

inSight = Cam.inSight
local newParams = {frame = spGetGameFrame(), pos = spGetCameraPosition(), vecs = spGetCameraVectors(), fov = spGetCameraFOV()}

local CHECKDEAD
local lastDead

local function UpdateAll(fullview)
	-- Echo("#spGetVisibleUnits(ALL_UNITS,radius,true) is ", #spGetVisibleUnits(ALL_UNITS,radius,true))
	-- if Units == Cam.Units then

		-- if changedSide or oldview~=fullview then
			for id, unit in pairs(Units) do
				if spGetUnitIsDead(id) then
					--Echo('detected just dead unit',id,' while switching side!') -- can happen often
					-- CHECKDEAD = id
					Units[id].isDead = true
					Units[id] = nil
					inSight[id] = nil
				elseif fullview == 1 and not spValidUnitID(id) then
					-- Echo('detected dead unit',id,' while switching in fullview!') -- can happen often
					Units[id] = nil
					inSight[id] = nil
				else					
					-- changing Los and health check for already known units
					local teamID = unit.teamID
					local isMine = teamID == myTeamID
					local isAllied = not isMine and spAreTeamsAllied(teamID, myTeamID)
					local defID = spGetUnitDefID(id)
					local isKnown = not not defID
					if (isAllied or isMine) and fullview~=1 and not spValidUnitID(id) then
						-- Echo('detected allied unit',id,"that wasn't existing anymore.") -- can happen often
						Units[id].isDead = true
						Units[id] = nil
						inSight[id] = nil
					else
						local isInSight, isInRadar
						if fullview==1 then
							isInSight = true
						else
							local losState = spGetUnitLosState(id)
							if losState then
								isInSight = losState.los
								isInRadar = losState.radar
							end
							-- unit.sightCheckedFrame = currentFrame
						end
						inSight[id] = isInSight and unit or nil
						if isInSight or isInRadar then
							local oldDefID = unit.defID
							if defID and defID ~= oldDefID then
								if oldDefID then
									Echo('detected recycled unit?',id) -- never seen
								end
								unit.defID = defID
								unit.isStructure = structureDefID[defID]
								if unit.health == DUMMY_HEALTH then
									if not ignoreHealthUnitDefID[defID] then
										unit.health = {frame = currentFrame, spGetUnitHealth(id)}
									end
								else
									if ignoreHealthUnitDefID[defID] then
										unit.health = DUMMY_HEALTH
									end
								end
							end
							if isInSight then
								unit:GetPos()
							end
						end
						-- Echo('Update unit',id,'of team',spGetUnitTeam(id),'fullview',fullview,'in los?',spGetUnitLosState(id) and spGetUnitLosState(id).los)
						if not ignoreHealthUnitDefID[unit.defID] then
							if fullview==1 then
								-- Echo('checkhealth stay the same for spec fullview',unit.checkHealth,' for unit',id,'of team',unit.teamID)
								-- we ask for a recheck in case discovered units are damaged
								unit.checkHealth = true
								-- local hp = spGetUnitHealth(id)
								-- if not hp then
								-- 	Echo('unit ',id,'dont have hp in fullview !') -- never happened
								-- end
							elseif not isInSight then
								unit.checkHealth = false

							elseif not (isAllied or isMine) then
								-- when not in spec fullview, we cannot avoid checking health continuously for enemy units that are in sight
								unit.checkHealth = true
							else
								-- for allied, we ask for a recheck that might or not be needed
								unit.checkHealth = true

							end
						end
						unit.isAllied = isAllied
						unit.isMine = isMine
						unit.isEnemy = not isAllied and not isMine

						unit.isInSight = isInSight
						unit.isInRadar = isInRadar
						unit.isKnown = isKnown
					end
				end
			end

		-- end
			for i, id in ipairs(spGetAllUnits()) do
				local unit = Units[id]
				if spGetUnitIsDead(id) then
					-- Echo('detected just dead unit',id,'is unit?',Units[id], 'while getting All units') -- happens sometime
					-- CHECKDEAD = id
					if unit then
						unit.isDead = true
						Units[id] = nil
					end
					inSight[id] = nil
	--[[			elseif not spValidUnitID(id) then -- never happened
					Echo('detected just invalid unit',id,'is unit?',Units[id], 'while getting All units')
					Units[id] = nil
					inSight[id] = nil--]]
				else
					local defID = spGetUnitDefID(id)
					local teamID = spGetUnitTeam(id)
					local isMine = teamID == myTeamID
					local isAllied = not isMine and spAreTeamsAllied(teamID, myTeamID)
					local isStructure = defID and structureDefID[defID]

					local isInSight
					local isInRadar
					local isKnown
					local checkHealth
					local health
					

					if fullview == 1 then
						isInSight = true
						isInRadar = true
						isKnown = true
					else
						local losState = spGetUnitLosState(id)
						if losState then
							isInSight = losState.los
							isInRadar = losState.radar -- true anyway?
							-- if not isInRadar then -- never happened
							-- 	Echo('UNIT ' .. id .. ' FROM spGetAllUnits not in radar !')
							-- end
						end
						-- sightCheckedFrame = currentFrame
					end

					if isInSight then
						isKnown = true
						local ignore = ignoreHealthUnitDefID[defID]
						if ignore then
							health = DUMMY_HEALTH
						else
							-- if not hp then
							-- 	Echo('no hp for unit',id,'of team',teamID) 
							-- end

							-- if not maxHP then A = A + 1 end
							local hp, maxHP, paraDamage, capture, build = spGetUnitHealth(id) 
							if unit and unit.health then
								health = unit.health
								health.frame, health[1], health[2], health[3], health[4], health[5] = currentFrame, hp, maxHP, paraDamage, capture, build
							else
								health = {frame = currentFrame, hp, maxHP, paraDamage, capture, build}
							end
							if isAllied or isMine or fullview==1 then
								-- we can avoid checking for health if unit is restored for allied and spec fullview mode
								checkHealth = hp ~= maxHP or build~=1 or paraDamage ~= 0 or capture ~= 0
								-- Echo('checkHealth for unit ', id,'of team',teamID, 'is saving',checkHealth)
							else

								checkHealth = true
								-- if checkHealth then
								-- 	Echo('checking health continuously for',id)
								-- end
							end
						end
					elseif isInRadar then
						isKnown = not not defID
						checkHealth = false
					end

					if unit then -- we shouldnt need that, this is already managed above 
						unit.isInSight = isInSight
						unit.isInRadar = isInRadar
						unit.isKnown = isKnown
						unit.checkHealth = checkHealth
						if defID and unit.defID ~= defID then
							Echo('Detected recycled unit???', unit.defID,defID,'id',id)
							unit.defID = defID
							unit.isStructure = structureDefID[defID]
							if unit.health == DUMMY_HEALTH then
								if not ignoreHealthUnitDefID[defID] then
									unit.health = {frame = currentFrame, spGetUnitHealth(id)}
								end
							else
								if ignoreHealthUnitDefID[defID] then
									unit.health = DUMMY_HEALTH
								end
							end
						end

						unit:GetPos()
					else

						-- local sightCheckedFrame
	
						local pos = {frame = currentFrame, spGetUnitPosition(id)}


						-- Echo('Create unit',id,'of team',spGetUnitTeam(id),'fullview',fullview,'in los?',spGetUnitLosState(id).los)

							-- if not teamID and fullview==1 then -- never happening
							-- 	Echo('no teamID for unit',id,'is really in sight?',spGetUnitLosState(id) and spGetUnitLosState(id).los) -- never happened
							-- end
							-- Echo('creating unit',id, 'of team',teamID)

						unit = {
							id = id,
							frame = currentFrame,
							teamID = teamID,
							isAllied = isAllied,
							isMine = isMine,
							isEnemy = not isAllied and not isMine,
							isInSight = isInSight,
							isInRadar = inRadar,
							defID = defID,
							health = health,
							checkHealth = checkHealth,
							-- sightCheckedFrame = sightCheckedFrame,
							isKnown = isKnown,
							pos = pos,
							GetPos = GetPos,
							isStructure = isStructure,
						}
						Units[id] = unit
					end
					if isInSight then
						inSight[id] = unit
					end
				end

			end
		-- end
	-- end
	-- verify if all is good -- never had problem since
	-- for id,unit in pairs(inSight) do
	-- 	if spGetUnitIsDead(id) then
	-- 		Echo('detected just dead unit ', id, ' in inSight while switching !',unit.defID and UnitDefs[unit.defID].name)
	-- 	elseif not spValidUnitID(id) then
	-- 		Echo('detected invalid unit', id, ' in inSight while switching !',unit.defID and UnitDefs[unit.defID].name)
	-- 	end
	-- end
	-- UpdateVisibleUnits()
end
function widget:PlayerChanged() -- PlayerChanged also get triggered naturally when switching fullview as spectator
	local oldfullview = fullview
	local newfullview = HaveFullView()
	if newfullview ~= oldfullview then
		-- Echo('fullview has changed in PlayerChanged, now',newfullview)
		fullview = newfullview
		requestUpdate = true
		Cam.fullview = fullview
	end

	local myNewTeamID = spGetMyTeamID()
	local changedSide = not spAreTeamsAllied(myNewTeamID, myTeamID)
	myTeamID = myNewTeamID

	-- Echo('my new Ally Team', spGetMyAllyTeamID(),'my new teamID',myNewTeamID,'newfullview?',newfullview, 'old fullview?',oldfullview)
	if not changedSide and (oldfullview == newfullview) then 
		return
	end

	-- Echo('updating all...')
	UpdateAll(newfullview)
	if newfullview~=oldfullview then
		-- NewView[5] = NewView[5] + 1
		-- NOTE: Getting visibles units at this moment will give units that doesn't have position
		-- UpdateVisibleUnits()-- 
	end

	-- NewView[5] = NewView[5] + 1
end
local function DeepCompare(t,t2)
	for k,v in pairs(t) do
		local same = t2[k]==v or type(v)=='table' and DeepCompare(v,t2[k])
		if not same then
			return false
		end
	end
	return true
end
local count 


local HasViewChanged = function()
	local frame, pos, vecs, fov = currentFrame, {spGetCameraPosition()}, spGetCameraVectors(), spGetCameraFOV()
	local changed
	-- if Cam.frame == frame then
		-- Echo('-- no frame changed',frame)
	-- end
	-- if  count then
	-- 	Echo(count,frame,Cam.frame)
	-- end
	Cam.state = spGetCameraState()
	if frame~=Cam.frame then
		NewView[1] = NewView[1] + 1
		Cam.frame = frame
		changed = true
	end
	local needRetrace
	if not DeepCompare(Cam.pos, pos) then
		needRetrace = true
		Cam.pos[1], Cam.pos[2], Cam.pos[3] = pos[1], pos[2], pos[3]
		NewView[2] = NewView[2] + 1
		changed = true
	end
	if not DeepCompare(Cam.vecs, vecs) then
		for k,v in pairs(vecs) do Cam.vecs[k] = v end
		needRetrace = true
		NewView[3] = NewView[3] + 1
		changed = true
	end
	if needRetrace then
		Cam.trace = SafeTrace()
		Cam.dist = GetDist()
		Cam.relDist = Cam.dist * (Cam.fov / 45)
	end
	if Cam.fov ~= fov then
		Cam.fov = fov
		NewView[4] = NewView[4] + 1
		changed = true
	end
	local oldfullview = fullview
	local newfullview = HaveFullView()
	if oldfullview ~= newfullview then
		fullview = newfullview
		-- Echo("full view has changed in 'HasViewChanged', now",fullview)
		changed = true
		Cam.fullview = newfullview
		--if Units == Cam.Units  and fullview~=2 then -- fullview 2 is globallos, we don't need to update here as it will normally get updated by UnitEnteredLos
			-- UpdateAll() -- fullview don't need to get updated here, it is triggered in PlayerChanged and has already been updated since then
			-- if fullview then
			-- 	for i, id in ipairs(spGetAllUnits()) do
			-- 		if not Units[id] then
			-- 			local hp, maxHP, paraDamage, capture, build = spGetUnitHealth(id)
			-- 			local health = {hp, maxHP, paraDamage, capture, build}
			-- 			health.frame = currentFrame
			-- 			local teamID = spGetUnitTeam(id)
			--			local isMine = teamID == myTeamID
			--			local isAllied = not isMine and spAreTeamsAllied(teamID, myTeamID)
			-- 			Units[id] = {
			-- 				teamID = teamID,
			-- 				isAllied = isAllied,
			--				isMine = isMine,
			-- 				isInSight = true,
			-- 				defID = spGetUnitDefID(id),
			-- 				health = health,
			-- 				checkHealth = hp ~= maxHP or build~=1 or paraDamage ~= 0 or capture ~= 0 ,
			-- 			}
			-- 		end
			-- 	end

			-- end
		--end
	end


	if changed then
		NewView[5] = NewView[5] + 1
		return true
	end
end
---
---
local function clear()
	for _, t in pairs(Visibles) do
		for i in pairs(t) do
			t[i] = nil
		end
	end

end
local radius = nil
function OriUpdateVisibleUnits()
	-- if not Visibles.test then
	-- 	Visibles.test = {}
	-- end
	clear()
	local any, not_icons, icons  = Visibles.any, Visibles.not_icons, Visibles.icons
	local n, n2, n3 = 0, 0, 0
	-- local test, n4 = Visibles.test, 0
	-- local undetectedIcons
	-- for _, id in ipairs(spGetVisibleUnits(ALL_UNITS,radius,false)) do  -- this should report non-icons only but it includes units that just became icons in that draw frame,
	-- 																-- spIsUnitIcon report them as icon 
	-- 																-- spIsUnitVisible(id,nil,true) doesn't detect them as it report non-icons only (and never report icons detected by spIsUnitIcon)
	-- 																-- it also fail to report non-icon unit that are just entering view in that draw frame
	-- 																-- spIsUnitInView report any unit in view correctly according to the 2 above
	-- 																-- with true as third argument (reporting any in view), all checks correctly (EXCEPT see below)
	-- 																-- so it looks like this function is at fault when using false as third argument
	-- 																-- BUT ALSO: when unit get out of view, it is first detected by spIsUnitInView then detected the next draw frame by spGetVisibleUnits(ALL_UNITS,nil,true)
	-- 	n4 = n4 + 1
	-- 	test[n4] = id
	-- 	undetectedIcons = undetectedIcons or spIsUnitIcon(id)
	-- end
	local alreadyDead
	for _, id in ipairs(spGetVisibleUnits(ALL_UNITS,radius,true)) do -- 
		n = n + 1
		any[n] = id
		alreadyDead = alreadyDead or spGetUnitIsDead(id)
		if spIsUnitVisible(id,radius,true) then
			n2 = n2 + 1
			not_icons[n2] = id
		else
			n3 = n3 + 1
			icons[n3] = id
		end
		local x = spGetUnitViewPosition(id)
		if not x then
			Echo('Unit ', id, 'visible but no position !')
		end

	end
	if alreadyDead then
		Echo('Fresh Visible units contains just dead units !')
	end
	any.frame, not_icons.frame, icons.frame = currentFrame, currentFrame, currentFrame
	-- Echo('any:',#any,"#icons is ",  #icons,  'not icons',#not_icons,'test',#test,'undetectedIcons',undetectedIcons)
	return any, not_icons, icons
end

function Ori2UpdateVisibleUnits() -- this is faster
	-- if not Visibles.test then
	-- 	Visibles.test = {}
	-- end
	clear()

	local any, not_icons, icons  = Visibles.any, Visibles.not_icons, Visibles.icons
	local anyMap, not_iconsMap, iconsMap = Visibles.anyMap, Visibles.not_iconsMap, Visibles.iconsMap
	local n, n2, n3 = 0, 0, 0
	-- local undetectedIcons = 0
	-- local invalid, justDead, _invalid, _justDead, undetected = 0, 0, 0, 0, 0
	-- local justDeadGood = 0
	-- spGetVisibleUnits is cached and doesnt give 100% of the time the correct units, especially when switching spec view

	-- asking for visible units that are not icons
	for _, id in ipairs(spGetVisibleUnits(ALL_UNITS,radius,false)) do 
		if inSight[id] then
			n2 = n2 + 1
			not_icons[n2] = id
			not_iconsMap[id] = true
			-- if not inSight[id] then
			-- 	if spGetUnitIsDead(id) then
			-- 		justDeadGood = justDeadGood + 1
			-- 	elseif not spValidUnitID(id) then
			-- 		invalid = invalid +1
			-- 	else
			-- 		undetected = undetected + 1
			-- 		local unit = Units[id]
			-- 		local isInSight = unit and unit.isInSight

			-- 		local defID = spGetUnitDefID(id)
			-- 		local name = defID and UnitDefs[defID].name
			-- 		local team = defID and spGetUnitTeam(id)
			-- 		local isAllied = unit and unit.isAllied
			-- 		local isAllied2 = team and spAreTeamsAllied(myTeamID,team)
			-- 		local isMine = unit and unit.isMine or team == myTeamID
			-- 		local losState = defID and spGetUnitLosState(id)
			-- 		local isRealInSight = losState and losState.los
			-- 		Echo('visible unit not present in inSight ! unit?',unit,'isInSight?',isInSight,'isRealInSight?',isRealInSight,'currentFrame?',currentFrame,'sight checked frame?',unit and unit.sightCheckedFrame,'defID?',defID,'name?',name,'is allied?',isAllied,isAllied2)
			-- 	end
			-- elseif spGetUnitIsDead(id) then
			-- 	_justDead = _justDead + 1
			-- elseif not spValidUnitID(id) then
			-- 	_invalid = _invalid +1
			-- end
			-- if spIsUnitIcon(id) then
			-- 	undetectedIcons = undetectedIcons + 1
			-- end
		end
	end

	for _, id in ipairs(spGetVisibleUnits(ALL_UNITS,radius,true)) do -- 
		if inSight[id] then -- purge from  dead unit and invalidate
			n = n + 1
			any[n] = id
			anyMap[id] = true
			-- if not inSight[id] then
			-- 	if spGetUnitIsDead(id) then
			-- 		justDeadGood = justDeadGood + 1
			-- 	elseif not spValidUnitID(id) then
			-- 		invalid = invalid +1
			-- 	else
			-- 		undetected = undetected + 1
			-- 		local unit = Units[id]
			-- 		local isInSight = unit and unit.isInSight

			-- 		local defID = spGetUnitDefID(id)
			-- 		local name = defID and UnitDefs[defID].name
			-- 		local team = defID and spGetUnitTeam(id)
			-- 		local isMine = unit and unit.isMine
			-- 		local isAllied = unit and unit.isAllied
			-- 		local isAllied2 = team and spAreTeamsAllied(myTeamID,team)
					
			-- 		local losState = defID and spGetUnitLosState(id)
			-- 		local isRealInSight = losState and losState.los
			-- 		Echo('visible unit not present in inSight ! unit?',unit,'isInSight?',isInSight,'isRealInSight?',isRealInSight,'currentFrame?',currentFrame,'sight checked frame?',unit and unit.sightCheckedFrame,'defID?',defID,'name?',name,'is allied?',isAllied,isAllied2,'isMine?',isMine)
			-- 	end
			-- elseif spGetUnitIsDead(id) then
			-- 	_justDead = _justDead + 1
			-- elseif not spValidUnitID(id) then
			-- 	_invalid = _invalid +1
			-- end
			if not not_iconsMap[id] then
				n3 = n3 + 1
				icons[n3] = id
				iconsMap[id] = true
			end
			-- local x = spGetUnitViewPosition(id)
			-- if not x then
			-- 	Echo('Unit ', id, 'visible but no position !')
			-- end
		end

	end
	-- Echo('any:',#any,"#icons is ",  #icons,  'not icons',#not_icons,'undetectedIcons',undetectedIcons)
	any.frame, not_icons.frame, icons.frame = currentFrame, currentFrame, currentFrame

	-- if justDead > 0 then
	-- 	Echo('GetVisibleUnits reported ' .. justDead .. ' just dead units')
	-- end
	-- if invalid > 0 then
	-- 	Echo('GetVisibleUnits reported ' .. invalid .. ' invalid units  correctly detected by inSight')
	-- end
	-- if _justDead > 0 then
	-- 	Echo('GetVisibleUnits reported ' .. justDead .. ' just dead units NOT correctly detected by inSight')
	-- end
	-- if _invalid > 0 then
	-- 	Echo('GetVisibleUnits reported ' .. invalid .. ' invalid units  NOT correctly detected by inSight')
	-- end
	-- if undetected > 0 then
	-- 	Echo('inSight didnt detect ' .. undetected .. ' visible units !')
	-- end
	return any, not_icons, icons, anyMap, not_iconsMap, iconsMap
end

function AltUpdateVisibleUnits()
	clear()
	local any, not_icons, icons  = Visibles.any, Visibles.not_icons, Visibles.icons
	local n, n2, n3 = 0, 0, 0
	-- local any,n = {},0

	-- local not_icons,n2 = {}, 0
	local id = 9707

	for id, unit in pairs(Units) do
		if tonumber(id) then
			if spIsUnitVisible(id) then
				n = n + 1
				any[n] = id
				if spIsUnitVisible(id,nil,true) then
					n2 = n2 + 1
					not_icons[n2] = id
				else
					n3 = n3 + 1
					icons[n3] = id
				end
			end
		end
	end

	-- Echo("#any is ", #any)
	-- Echo('any:',#any,"#icons is ",  #icons,  'not icons',#not_icons)
	any.frame, not_icons.frame, icons.frame = currentFrame, currentFrame, currentFrame

	return any, not_icons, icons
end

function NewUpdateVisibleUnits()
	clear()
	local any, not_icons, icons  = Visibles.any, Visibles.not_icons, Visibles.icons
	local n, n2, n3 = 0, 0, 0
	-- local any,n = {},0

	-- local not_icons,n2 = {}, 0
	local id = 9707

	for id, unit in pairs(inSight) do
		-- if unit.isInSight then
			if spIsUnitVisible(id) then
				n = n + 1
				any[n] = id
				if spIsUnitVisible(id,nil,true) then
					n2 = n2 + 1
					not_icons[n2] = id
				else
					n3 = n3 + 1
					icons[n3] = id
				end
			end
		-- end
	end

	any.frame, not_icons.frame, icons.frame = currentFrame, currentFrame, currentFrame
end

-- local stop = false
-- function widget:MouseWheel()
-- 	if not stop then
-- 		count = 0
-- 		Echo('--')
-- 	end
-- end
-- function widget:KeyPress(key)
-- 	if key == 100 then
-- 		count = not count and 0 or false
-- 		stop = true
-- 		Echo('-----')
-- 	end
-- end
-- when game lags, no matter the culprit, more game frame will be executed before Genesis and the rest of drawing callin are called
local count -- = 0


function widget:GameFrame(f)
	-- end
	currentFrame = f
	if count then
		count = count + 1
		Echo('frame',count)
	end
end
function widget:UnitReverseBuilt(id--[[, unitDefID, unitTeam--]])
	local unit = Units[id]
	if unit then
		unit.checkHealth = true
	end
end
function widget:MouseWheel()
	-- count = 0
end
function widget:DrawGenesis()
	if count then
		count = count + 1
		Echo('genesis',count)
	end
end
	-- local IsUnitVisible = function() for id in pairs(inSight) do spIsUnitVisible(id) end end
	-- local GetUnitDefID = function() for id in pairs(inSight) do spGetUnitDefID(id) end end
	-- local GetUnitIsDead = function() for id in pairs(inSight) do spGetUnitIsDead(id) end end
	-- local GetUnitPosition = function() for id in pairs(inSight) do spGetUnitPosition(id) end end
	-- local ValidUnitID = function() for id in pairs(inSight) do spValidUnitID(id) end end
	-- local GetUnitViewPosition = function() for id in pairs(inSight) do spGetUnitViewPosition(id) end end
	-- local IsUnitInView = function() for id in pairs(inSight) do spIsUnitInView(id) end end
	-- local GetUnitLosState = function() for id in pairs(inSight) do spGetUnitLosState(id) end end
	-- local GetUnitHealth = function() for id in pairs(inSight) do spGetUnitHealth(id) end end

	
	
local lastCount = 0
local lagCounts = 10
local cnt, lags, total = 0, {}, 0
for i=1, lagCounts do lags[i] = 0 end

local lastFrame = spGetGameFrame()
function widget:Update(dt)

		-- IsUnitVisible()
		-- GetUnitDefID()
		-- GetUnitIsDead()
		-- GetUnitPosition()
		-- ValidUnitID()
		-- GetUnitViewPosition()
		-- IsUnitInView()
		-- GetUnitLosState()
		-- GetUnitHealth()
	if count then
		count = count + 1
		Echo('update', count)
	end
	cnt = cnt +1
	if cnt > lagCounts then cnt = 1 end
	total = total - lags[cnt] + dt
	lags[cnt] = dt
	local avg = (total / lagCounts)
	lag[1] = math.max(1, avg / lagref )



	-- Echo("=>>>#Spring.GetVisibleUnits(-1, nil, false) is ", #Spring.GetVisibleUnits(-1, nil, false), #spGetVisibleUnits(-1, nil, false) )

	-- for i=1,5000000 do	i = i +1	end

	local lastView = NewView[5]
	local newFrame = currentFrame ~= Cam.frame
	local update = HasViewChanged()
	if not update and requestUpdate then
		NewView[5] = NewView[5] + 1
		update = true
	end

	if update then
		-- Echo('view has changed',spGetGameFrame())
		UpdateVisibleUnits()
		-- OriUpdateVisibleUnits()
		-- Ori2UpdateVisibleUnits()
		-- AltUpdateVisibleUnits()
		-- NewUpdateVisibleUnits()
		-- if not fullview and HaveFullView() then
		-- 	fullview = true

		
		local frame = currentFrame
		local lagUpdate = lag[1] * UPDATE_FRAME_HEALTH
		-- Echo("lagUpdate is ", lagUpdate)
		-- local count = 0
		for id, unit in pairs(inSight) do
			-- if tonumber(id) then
			-- 	local isInSight = unit.isInSight
			-- 	if fullview and not isInSight then
			-- 		Echo('PROBLEM full view but not in sight !') -- never happened
			-- 	end
			--	if (fullview or isInSight) and unit.checkHealth then
				if unit.checkHealth then
					-- count = count + 1
					local health = unit.health
					if frame > health.frame + lagUpdate then
						health.frame = frame
						if not health[2] then
							Echo('Problem with unit',id,unit.defID and UnitDefs[unit.defID].name,'empty health !',unpack(health))
						end
						local hp, maxHP, paraDamage, capture, build = spGetUnitHealth(id)
						if  hp then
							-- only in spec fullview we can get informed when enemy unit got damaged, so we can stop checking for nothing
							if fullview==1 or unit.isAllied or unit.isMine then
								if hp == maxHP and paraDamage == 0 and capture == 0  and build==1 then
									unit.checkHealth = false
								end
							end
							health[1], health[3], health[4], health[5] = hp, paraDamage, capture, build
						else
							local defID = spGetUnitDefID(id)

							local name = defID and UnitDefs[defID].name
							local name2 = unit.defID and UnitDefs[unit.defID].name
							Echo('unit',name,name2,id,'dont have health ! is dead?',spGetUnitIsDead(id),'is valid?',spValidUnitID(id),'registered health?',health and health[1],'is allied?',unit.isAllied)
							unit.checkHealth = false
						end
					end
				end
				-- too expensive
				-- if newFrame and unit.pos and not unit.isStructure then
				-- -- if fullview or unit.isInRadar then
				-- 	local pos = unit.pos
				-- 	pos[1], pos[2], pos[3] = spGetUnitPosition(id)
				-- 	pos.frame = currentFrame
				-- end
			-- end
		end
		-- if math.round(os.clock()*10)%30 == 0 then
			-- Echo('count for checkhealth',count)
		-- end

	end
end





function widget:UnitGiven(id, defID, toTeam, fromTeam)
	if spGetUnitIsDead(id) then
		-- Echo('unit', id, 'got given but is just dead !')
		CHECKDEAD = id
		return
	end
	local unit = Units[id]
	if unit then
		-- Echo('unit',id, 'got given from team', fromTeam, 'to team', toTeam, 'was it already registered ?',unit.teamID == toTeam)
		if unit.teamID ~= toTeam then
			unit.teamID = toTeam
			local isMine = toTeam == myTeamID
			local isAllied = not isMine and spAreTeamsAllied(toTeam, myTeamID)
			-- unless in fullview, this should be our side
			unit.isAllied = isAllied 
			unit.isMine = isMine
			unit.isEnemy = not isAllied and not isMine

			if fullview==1 then
				-- let the checkHealth state and isInSight (true as it should be) as it is
			else
				unit.isInSight = true
				inSight[id] = unit
				unit.checkHealth = not ignoreHealthUnitDefID[defID]
			end
		end
	else
		local ignore = ignoreHealthUnitDefID[defID]
		local health
		if ignore then
			health = DUMMY_HEALTH
		else
			local hp, maxHP, paraDamage, capture, build = spGetUnitHealth(id)
			health = {hp, maxHP, paraDamage, capture, build}
			health.frame = currentFrame
		end
		local isInSight
		if fullview==1 then
			isInSight = true
		else
			local losState = spGetUnitLosState(id)
			isInSight = losState and losState.los
		end
		local isMine = toTeam == myTeamID
		local isAllied = not isMine and spAreTeamsAllied(toTeam, myTeamID)
		local pos = {spGetUnitPosition(id)}
		pos.frame = currentFrame
		Units[id] = {
			id = id,
			frame = currentFrame,
			teamID = teamID,
			isMine = isMine,
			isAllied = isAllied,
			isEnemy = not isAllied and not isMine,
			isInSight = isInSight ,
			teamID = toTeam,
			defID = defID,
			health = health,
			isKnown = true,
			checkHealth = not ignore and hp ~= maxHP or build~=1 or paraDamage ~= 0 or capture ~= 0,
			pos = pos,
			GetPos = GetPos,
			isStructure = structureDefID[defID],
		}
		inSight[id] = isInSight and Units[id] or nil
	end

end

function widget:UnitTaken(id, defID, fromTeam, toTeam)
	if spGetUnitIsDead(id) then
		-- Echo('unit', id, 'got taken but is just dead !')
		CHECKDEAD = id
		return
	end

	local unit = Units[id]
	if unit then
		-- Echo('unit',id, 'got took from team', fromTeam, 'to team', toTeam, 'was it already registered ?',unit.teamID == toTeam)
		if unit.teamID ~= toTeam then
			unit.teamID = toTeam
			local isMine = toTeam == myTeamID
			local isAllied = not isMine and spAreTeamsAllied(toTeam, myTeamID)

			unit.isAllied = isAllied -- unless in fullview, this should be our ally
			unit.isMine = isMine
			unit.isEnemy = not isAllied and not isMine

			if fullview then
				-- let the checkHealth state and isInSight (true as it should be) as it is
				if not unit.isInSight then
					-- Echo('problem in unit taken with unit',id, 'it should be in sight') -- never happened
				end
			else
				local ignore = ignoreHealthUnitDefID[defID]
				local losState = spGetUnitLosState(id)
				local isInSight = losState and losState.los
				unit.isInSight = isInSight
				inSight[id] = isInSight and unit or nil
				unit.checkHealth = not ignore and isInSight
			end
		end
	else
		Echo('unit',id, 'has been taken but wasnt registered !')
		local ignore = ignoreHealthUnitDefID[defID]
		local health
		if ignore then
			health = DUMMY_HEALTH
		else
			local hp, maxHP, paraDamage, capture, build = spGetUnitHealth(id)
			health = {hp, maxHP, paraDamage, capture, build}
			health.frame = currentFrame
		end
		local isInSight
		if fullview then
			isInSight = true
		else
			local losState = spGetUnitLosState(id)
			isInSight = losState and losState.los
		end
		local isMine = toTeam == myTeamID
		local isAllied = not isMine and spAreTeamsAllied(myTeamID, toTeam)
		local checkHealth
		if not ignore then
			if fullview or isMine or isAllied then
				checkHealth = hp ~= maxHP or build~=1 or paraDamage ~= 0 or capture ~= 0
			else
				checkHealth = isInSight
			end
		end


		local pos = {spGetUnitPosition(id)}
		pos.frame = currentFrame
		Units[id] = {
			id = id,
			frame = currentFrame,
			teamID = teamID,
			isAllied = isAllied,
			isMine = isMine,
			isEnemy = not isAllied and not isMine,
			isInSight = isInSight ,
			teamID = toTeam,
			defID = defID,
			health = health,
			checkHealth = checkHealth,
			isKnown = true,
			pos = pos,
			GetPos = GetPos,
			isStructure = structureDefID[defID],
		}
		inSight[id] = isInSight  and Units[id] or nil

	end

end
-- NOTE: plop fac trigger first UnitFinished then UnitCreated
function widget:UnitFinished(id, defID, teamID) -- with cheat globallos UnitCreated when other team is creating unit but instead, UnitEnteredLos is triggered
	-- Echo('unit created',id,defID,teamID)
	if not Units[id] then
		local ignore = ignoreHealthUnitDefID[defID]
		local health
		if ignore then
			health = DUMMY_HEALTH
		else
			health = {spGetUnitHealth(id)}
			health.frame = currentFrame
		end
		local isMine = teamID == myTeamID
		local isAllied = not isMine and spAreTeamsAllied(teamID, myTeamID)
		local isInSight = spGetUnitLosState(id).los
		if not isInSight then
			Echo('unit',id,' created but not in sight !')
		end

		local pos = {spGetUnitPosition(id)}
		pos.frame = currentFrame

		Units[id] = {
			id = id,
			frame = currentFrame,
			isAllied = isAllied,
			isMine = isMine,
			isEnemy = not isAllied and not isMine,
			teamID = teamID,
			isInSight = isInSight,
			health = health,
			defID = defID,
			checkHealth = not ignore and true,
			isKnown = true,
			pos = pos,
			GetPos = GetPos,
			isStructure = structureDefID[defID],
		} 
		inSight[id] = isInSight and Units[id] or nil
	end

end

function widget:UnitCreated(id, defID, teamID) -- with cheat globallos UnitCreated when other team is creating unit but instead, UnitEnteredLos is triggered
	-- Echo('unit created',id,defID,teamID)
	if spGetUnitIsDead(id) then
		-- Echo('unit', id, 'got created but is just dead !')
		-- CHECKDEAD = id
		return
	end

	-- if not fullview and not spAreTeamsAllied(teamID, myTeamID) then
	-- 	Echo('unit ', id, ' enemy created !') -- never happened
	-- end
	if not Units[id] then
		local ignore = ignoreHealthUnitDefID[defID]
		local health
		if ignore then
			health = DUMMY_HEALTH
		else
			health = {spGetUnitHealth(id)}
			health.frame = currentFrame
		end
		local isMine = teamID == myTeamID
		local isAllied = not isMine and spAreTeamsAllied(teamID, myTeamID)

		local isInSight = spGetUnitLosState(id).los
		if not isInSight then
			Echo('unit',id,' created but not in sight !')
		end
		local pos = {spGetUnitPosition(id)}
		pos.frame = currentFrame

		Units[id] = {
			id = id,
			frame = currentFrame,
			isAllied = isAllied,
			isMine = isMine,
			isEnemy = not isAllied and not isMine,
			teamID = teamID,
			isInSight = isInSight,
			health = health,
			defID = defID,
			checkHealth = not ignore and true,
			isKnown = true,
			pos = pos,
			GetPos = GetPos,
			isStructure = structureDefID[defID],
		} 
		inSight[id] = isInSight and Units[id] or nil
	-- else
	-- 	Echo('unit',id, 'was already created !') -- never happened
	end

end
function widget:UnitDamaged(id, defID, teamID) -- NOTE: we cannot get enemy unit damaged from there (even those that are in sight), except in SPEC full view (not cheat globallos)
	-- Echo("id is ", id, 'is getting damaged',math.round(os.clock()),Units[id],Units[id] and Units[id].isAllied)
	if id == lastDead then
		return -- so it happens often that UnitDamaged get triggered AFTER UnitDestroyed
	elseif spGetUnitIsDead(id) then -- in some rarer case it's not the last dead registered
		-- Echo('id',id, 'get damaged after beeing dead but its not the last dead! Was registered ?',Units[id])
		CHECKDEAD = id
		return
	elseif Units[id] then
		local unit = Units[id]
		if not ignoreHealthUnitDefID[defID] then
			unit.checkHealth = true
		end
	else
		-- if not fullview and not spAreTeamsAllied(myTeamID,teamID) then
		-- 	Echo('unit',id, 'is enemy damaged while not in full view !') -- never happened
		-- end
		local health
		local ignore =ignoreHealthUnitDefID[defID]
		if ignore then
			health = DUMMY_HEALTH
		else
			health = {spGetUnitHealth(id)}
		end
		local isInSight = fullview==1 or spGetUnitLosState(id).los
		if not isInSight then
			Echo('unit',id,'get damaged without beeing in sight !')
		end
		health.frame = currentFrame
		local isMine = teamID == myTeamID
		local isAllied = not isMine or fullview and spAreTeamsAllied(teamID, myTeamID) -- without fullview, it will not be an allied in any case
		local pos = {spGetUnitPosition(id)}
		pos.frame = currentFrame
		Echo('created unit ' .. id .. ' from UnitDamaged')
		Units[id] = { 
			id = id,
			frame = currentFrame,
			isInSight = isInSight,
			defID = defID,
			checkHealth  = not ignore and true,
			health = health,
			teamID = teamID,
			isAllied = isAllied, 
			isMine = isMine,
			isEnemy = not isAllied and not isMine,
			pos = pos,
			GetPos = GetPos,
			isStructure = structureDefID[defID],
			isKnown = not not defID,
		} 
		inSight[id] = isInSight and Units[id] or nil
	end
end


function widget:UnitEnteredLos(id, teamID)
	-- in spec fullview, UnitEnteredLos trigger for every side, and in fullspec by globallos cheat, it triggers as usual for our side but we're seeing the whole map, once enabled, every unseen units will popup there, cloaked enemy will still stay cloaked and undetected
	-- so we let it pass in globallos fullview to register new units
	-- Echo('a unit of team', teamID, 'entered the LoS, allyteam: ',spGetUnitAllyTeam(id),'allied with me?',spAreTeamsAllied(myTeamID,teamID), 'arg3?',arg3)
	-- if fullview and spAreTeamsAllied(teamID,myTeamID) then
	-- 	return
	-- 	-- Echo('own allied entered los !',math.round(os.clock()*10)%10)
	-- end
	if spGetUnitIsDead(id) then -- happens often
		if Units[id] then -- more rare but can happen
			-- Echo('unit', id, 'entered LoS but is just dead AND Was registered !')
			Units[id] = nil
			inSight[id] = nil
		end
		CHECKDEAD = id
		-- widget:UnitDestroyed(id)
		return
	elseif not spValidUnitID(id) then -- happens often
		if Units[id] then -- more rare but can happen
			-- Echo('unit', id, 'entered LoS but is invalid AND Was registered !')
			Units[id] = nil
			inSight[id] = nil
		else
			-- Echo('unit', id, 'entered LoS but is invalid!')

		end
		CHECKDEAD = id
		-- widget:UnitDestroyed(id)
		return

	end
	local unit = Units[id]
	if fullview==1 then
		-- if unit and not unit.isInSight then
		-- 	Echo('PROBLEM WITH UNIT', id, unit.defID, ' NOT INSIGHT WHILE IN FULL VIEW')-- never happened
		-- end
		return
		-- Echo('own allied entered los !',math.round(os.clock()*10)%10)
	end


	if unit then
		local defID = spGetUnitDefID(id)
		local teamID = spGetUnitTeam(id)
		if defID ~= unit.defID  then
			-- Echo('unit ', id, 'got recycled !')
			unit.defID = defID
			unit.isStructure = structureDefID[defID]
		end
		if unit.teamID~=teamID then
			unit.teamID = teamID
		end

		unit.isInSight = true
		unit.isKnown = true
		unit.isInRadar = true
		inSight[id] = unit
		-- in not spec fullview, this is an enemy, we need to check continuously for health because UnitDamaged wont get triggered
		unit.checkHealth = not ignoreHealthUnitDefID[defID] and true
		if not unit.health then
			unit.health = {frame = currentFrame,spGetUnitHealth(id)}
		end
	else
		local defID = spGetUnitDefID(id)
		local health
		local ignore = ignoreHealthUnitDefID[defID]
		if ignore then
			health = DUMMY_HEALTH
		else
			health = {spGetUnitHealth(id)}
			health.frame = currentFrame
		end
		local isMine = teamID == myTeamID
		local isAllied = not isMine and spAreTeamsAllied(teamID, myTeamID)
		local pos = {spGetUnitPosition(id)}
		pos.frame = currentFrame

		Units[id] = { 
			id = id,
			frame = currentFrame,
			teamID = teamID,
			isMine = isMine,
			isAllied = isAllied,
			isEnemy = not isAllied and not isMine,
			isInSight = true,
			defID = defID,
			health = health,
			checkHealth = not ignore and true,
			isKnown = true,
			pos = pos,
			GetPos = GetPos,
			isStructure = structureDefID[defID],
		} 
		inSight[id] = Units[id]
	end
end
function widget:UnitLeftLos(id, teamID, fromAllyTeam)
	-- in spec fullview
	-- Echo('a unit of team', teamID, 'left the LoS of ', fromAllyTeam, 'allyteam:',spGetUnitAllyTeam(id),'allied with me?',spAreTeamsAllied(myTeamID,teamID))
	if spGetUnitIsDead(id) then -- happens sometimes
		if Units[id] then
			Echo('unit', id, 'left LoS but is just dead AND Was registered !')
			Units[id] = nil
			inSight[id] = nil
		end
		return
	end

	if fullview==1 then
		return
	end
	-- if fullview and spAreTeamsAllied(teamID,myTeamID) then
	-- 	return
	-- 	-- Echo('own allied entered los !',math.round(os.clock()*10)%10)
	-- end
	local unit = Units[id]
	if unit then
		unit.isInSight = false
		inSight[id] = nil
		unit.checkHealth = false
	else
		Echo('unit ', id, ' left LoS but wasnt registered !')
	end
end
function widget:UnitLeftRadar(id)
	local unit = Units[id]
	if unit then
		unit.inRadar = false
		unit.isKnown = false
	else
		-- Echo('unregistered unit', id, ' left radar !')
	end
end
function widget:UnitEnteredRadar(id)
	local unit = Units[id]
	if unit then
		unit.inRadar = true
		if unit.isStructure then
			unit.isKnown = true
		end
	end
end

function widget:UnitDestroyed(id)
	if CHECKDEAD == id then
		Echo('unit ', id, 'got indeed destroyed')
	end
	if not Units[id] then
		Echo('unit',id, 'got destroyed but wasnt registered !')
	end
	lastDead = id
	Units[id] = nil
	inSight[id] = nil
end
-- function widgetRemoveNotify(w,name,preloading)
-- 	if name == 'UnitIDCard' then
-- 		UpdateVisibleUnits = OriUpdateVisibleUnits
-- 	end
-- end
-- function WidgetInitNotify(w,name,preloading)
-- 	if name == 'UnitIDCard' then
-- 		Units = WG.UnitsIDCard
-- 		UpdateVisibleUnits = AltUpdateVisibleUnits
-- 	end
-- end
local useNew = false
local useOri2 = true
function widget:Initialize()
	if useOri2 then -- Ori2 is faster than Ori but it will count for one frame units that become icons as not icons
		Units = Cam.Units
		UpdateVisibleUnits = Ori2UpdateVisibleUnits -- bit faster now, rely on isInSight prop before checking for visibilty
		Echo(widget:GetInfo().name .. ' use Cam.Units with Ori2 Update Visible function.')

	elseif useNew then
		Units = Cam.Units
		UpdateVisibleUnits = NewUpdateVisibleUnits -- finally not faster than Ori
		Echo(widget:GetInfo().name .. ' use Cam.Units with new Update Visible function.')
	elseif WG.UnitsIDCard then 
		Units = WG.UnitsIDCard
		UpdateVisibleUnits = AltUpdateVisibleUnits -- finally not faster than Ori
		Echo(widget:GetInfo().name .. ' use UnitsIDCard.')
	else
		Units = Cam.Units
		UpdateVisibleUnits = OriUpdateVisibleUnits
		Echo(widget:GetInfo().name .. ' use Cam.Units.')
		-- for id, unit in pairs(Units) do
			-- Check For LOS and Existance and delete/update
		-- end
	end
	if Units == Cam.Units then
		for k,unit in pairs(Units) do
			Units[k] = nil
			inSight[k] = nil
		end

		-- trigger the update from PlayerChanged
		myTeamID = -1
		widget:PlayerChanged()
	end
	widget:ViewResized(Spring.GetViewGeometry())
end
function widget:TextCommand(cmd)

	-- local oldfullview = fullview
	-- if not fullview and cmd == 'epic_spectate_selected_teamradiobutton_viewallselectany' then
	-- 	NewView[5] = NewView[5] + 1
	-- 	fullview = true
	-- elseif fullview and cmd == 'epic_spectate_selected_teamradiobutton_selectanyunit' then
	-- 	NewView[5] = NewView[5] + 1
	-- 	fullview = false
	-- end
	-- if fullview ~= oldfullview then
	-- 	Cam.fullview = fullview
	-- 	if Units == Cam.Units then
	-- 		if fullview then
	-- 			for i, id in ipairs(spGetAllUnits()) do
	-- 				if not Units[id] then
	-- 					local hp, maxHP, paraDamage, capture, build = spGetUnitHealth(id)
	-- 					local health = {hp, maxHP, paraDamage, capture, build}
	-- 					health.frame = currentFrame
	-- 					local teamID = spGetUnitTeam(id)
	--					local isMine = teamID == myTeamID
	--					local isAllied = not isMine and spAreTeamsAllied(teamID, myTeamID)

	-- 					Units[id] = {

	-- 						teamID = teamID,
	--						isAllied = isAllied,
	--						isMine = isMine,
	--						isEnemy = not isAllied and not isMine,

	-- 						isInSight = spGetUnitLosState(id).los,
	-- 						defID = spGetUnitDefID(id),
	-- 						health = health,
	-- 						checkHealth = hp ~= maxHP or build~=1 or paraDamage ~= 0 or capture ~= 0 ,
	-- 					}
	-- 				end
	-- 			end

	-- 		end
	-- 	end
	-- end
	-- Echo('cmd is',cmd, cmd == 'epic_spectate_selected_teamradiobutton_viewallselectany',fullview,oldfullview)
end

function widget:ViewResized(vsx, vsy)
	center_x, center_y = vsx/2, vsy/2 -1
	if HasViewChanged() then
		UpdateVisibleUnits()
	end
end
