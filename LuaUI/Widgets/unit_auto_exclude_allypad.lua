function widget:GetInfo()
	return {
		name      = "Auto Exclude Ally Pads",
		desc      = "From hmp idea",
		author    = "Helwor",
		date      = "August 2024",
		license   = "GNU GPL, v2 or later",
		-- layer     = 2, -- after Unit Start State
		layer     = 0,
		enabled   = true,  --  loaded by default?
		-- api       = true,
		handler   = true,
	}
end
local Echo = Spring.Echo

local isSpec  = false

local function Sleep(bool)
    if widgetHandler.Sleep then
        return widgetHandler[bool and 'Sleep' or 'Wake'](widgetHandler,widget, {PlayerChanged = true})
    else
        for k,v in pairs(widget) do
            if type(k)=='string' and type(v)=='function' then
                if k ~= 'PlayerChanged' and widgetHandler[k .. 'List'] then
                    widgetHandler[(bool and 'Remove' or 'Update')..'WidgetCallIn'](widgetHandler,k,widget)
                end
            end
        end
    end
end


options_path = 'Hel-K/' .. widget.GetInfo().name
options = {}


local initialized = false
options.active = {
	name = 'active',
	type = 'bool',
	desc = 'guess...',
	value = EXCLUDE,
	OnChange = function(self)
		if initialized then
			Sleep(not self.value or isSpec)
			if self.value then
				Echo('send player changed from OnChange()')
				widget:PlayerChanged(myPlayerID)
			end
		end
	end,
}

local CMD_EXCLUDE_PAD
do
	local customCmds = VFS.Include("LuaRules/Configs/customcmds.lua")
	CMD_EXCLUDE_PAD = customCmds.EXCLUDE_PAD
end


local EXCLUDE = false -- default
local myPlayerID
local myTeam
local myAllyeamID

local tobool = Spring.Utilities.tobool
local spGetUnitRulesParam = Spring.GetUnitRulesParam
local GiveOrderTo = Spring.GiveOrderToUnit
local spGetTeamUnitsByDefs = Spring.GetTeamUnitsByDefs
local excludeString

local pad = {
	[UnitDefNames["factoryplane"].id] = true,
	[UnitDefNames["staticrearm"].id] = true,
	[UnitDefNames["shipcarrier"].id] = true,
}
local padIndex = {}
for defID in pairs(pad) do
	table.insert(padIndex, defID)
end
local landable = {}
local landableIndex = {}
for i = 1, #UnitDefs do
	local unitDef = UnitDefs[i]
	local movetype = Spring.Utilities.getMovetype(unitDef)
	if (movetype == 1 or movetype == 0) and (not tobool(unitDef.customParams.cantuseairpads)) then
		landable[i] = true
		table.insert(landableIndex, i)
	end
end
local alliance = setmetatable({}, {__index = function(self,k) local t = {} rawset(self, k, t) return t end})
local allyTeam = {}
for i,teamID in pairs(Spring.GetTeamList()) do
	local allyTeamID = Spring.GetTeamAllyTeamID(teamID)
	table.insert(alliance[allyTeamID], teamID)
	allyTeam[teamID] = allyTeamID

end
-- for allyTeam, teams in pairs(alliance) do
-- 	for _, teamID in ipairs(teams) do
-- 		Echo('in ally team', allyTeam, 'there is teamID', teamID)
-- 	end
-- end

local function IsExcluded(padID)
	return tobool(spGetUnitRulesParam(padID, excludeString))
end
local GetMyAircraft
do
	local lastOne
	local lastTime = os.clock()
	local spValidUnitID = Spring.ValidUnitID
	local spGetUnitTeam = Spring.GetUnitTeam
	function GetMyAircraft()
		local now = os.clock()
		if lastOne and now - lastTime < 0.5 and myTeam == spGetUnitTeam(lastOne) then
			return lastOne
		else
			lastOne = spGetTeamUnitsByDefs(myTeam, landableIndex)[1]
			if lastOne then
				lastTime = now
			end
			return lastOne
		end
	end
end



local toSwitch = {}
local gotToSwitch = false

local function Init() -- need to wait the first update round to have the saved option value
	initialized = true
	widgetHandler:RemoveWidgetCallIn('Update', widget)
	widget.Update = nil
	if not options.active.value then
		Sleep(true)
	else
		-- Echo('send player changed from Init()')
		widget:PlayerChanged(myPlayerID)
	end
end
widget.Update = Init

function widget:PlayerChanged(playerID) -- updating
	if playerID ~= myPlayerID then
		return
	end
	local isNewSpec = Spring.GetSpectatingState()
	if isSpec ~= isNewSpec then
		isSpec = isNewSpec
		if initialized and options.active.value then
			Sleep(isSpec)
		end
		if isSpec then
			myTeam = false
			return
		end
	end

	local newTeamID = Spring.GetMyTeamID()
	if newTeamID ~= myTeam then
		myTeam = newTeamID
		excludeString = "padExcluded" .. myTeam
		myAllyTeam = Spring.GetMyAllyTeamID()
		gotToSwitch = false
		toSwitch = {}
		local myAircraftID = GetMyAircraft()
		for _, teamID in ipairs(alliance[myAllyTeam]) do
			local shouldBeExcluded = teamID ~= myTeam
			for _, padID in ipairs(spGetTeamUnitsByDefs(teamID, padIndex)) do
				-- Echo('team',teamID,"padID, IsExcluded(padID) is ", padID, IsExcluded(padID),'should be', shouldBeExcluded)
				if IsExcluded(padID) ~= shouldBeExcluded  then
					if myAircraftID then
						GiveOrderTo(myAircraftID, CMD_EXCLUDE_PAD, padID, 0)
						-- Echo('Excluding Pad '..padID..' of team '..teamID..' for my team '..myTeam..':'..tostring(shouldBeExcluded)..'.')
					else
						toSwitch[padID] = true
						gotToSwitch = true
						-- Echo('Wanting to excluding Pad '..padID..' of team '..teamID..' for my team '..myTeam..':'..tostring(shouldBeExcluded)..'.')
					end
				end
			end
		end
	end
end

-- function widget:UnitDestroyed(unitID) -- table access every dead unit just for a few pad is not really worth it
--     toSwitch[unitID] = nil
-- end


function widget:UnitGiven(unitID, defID, toTeam, fromTeam)
	if fromTeam == myTeam then
		-- it has already been dealt in UnitTaken
		return
	end
	-- Echo(unitID, 'Given fromTeam', fromTeam, 'toTeam', toTeam, pad[defID] and ('current exclude :'..tostring(IsExcluded(unitID)) or 'not a pad'))
	if pad[defID] then
		toSwitch[unitID] = nil
		if IsExcluded(unitID) then
			local myAircraftID = spGetTeamUnitsByDefs(myTeam, landableIndex)[1]
			if myAircraftID then
				GiveOrderTo(myAircraftID, CMD_EXCLUDE_PAD, unitID, 0)
			else
				toSwitch[unitID] = true
				gotToSwitch = true
			end
			-- Echo('Unexcluding my new Pad '..unitID..' from team '..fromTeam..' for my team '..myTeam..'.')
		end
	elseif landable[defID] then
		if gotToSwitch then
			widget:UnitCreated(unitID, defID, toTeam)
		end
	end
end

function widget:UnitTaken(unitID, defID, fromTeam, toTeam)
	-- Echo(unitID, 'Taken fromTeam', fromTeam, 'toTeam', toTeam, 'isAllied', myAllyTeam == allyTeam[toTeam], pad[defID] and ('current exclude: '..tostring(IsExcluded(unitID)) or 'not a pad'))
	if pad[defID] then
		if myAllyTeam == allyTeam[toTeam] then
			widget:UnitCreated(unitID, defID, toTeam)
		end
	end
end

function widget:UnitCreated(unitID, defID, teamID)
	-- Echo('Created', unitID, pad[defID] and 'pad' or 'not a pad', teamID == myTeam and 'mine' or 'not mine')
	if teamID == myTeam then
		if gotToSwitch and landable[defID] then
			for padID in pairs(toSwitch) do
				toSwitch[padID] = nil
				-- Echo('Got a new Aircraft, switching exclusion of Pad '..padID..' for my team '..myTeam..'.(current: '..tostring(IsExcluded(unitID))..')')
				GiveOrderTo(unitID, CMD_EXCLUDE_PAD, padID, 0)
			end
			gotToSwitch = false
		end
	else
		if pad[defID] then
			local myAircraftID =  GetMyAircraft()
			if myAircraftID then
				-- Echo('Excluding a new ally Pad '..unitID..' of team '..teamID..' for my team '..myTeam..'.(current: '..tostring(IsExcluded(unitID))..')')
				GiveOrderTo(myAircraftID, CMD_EXCLUDE_PAD, unitID, 0)
			else
				-- Echo('Wanting to exclude a new ally Pad '..unitID..' of team '..teamID..' for my team '..myTeam..'.(current: '..tostring(IsExcluded(unitID))..')')
				toSwitch[unitID] = true
				gotToSwitch = true
			end
		end
	end
end


function widget:Initialize()
	myPlayerID = Spring.GetMyPlayerID()
	myAllyTeam = Spring.GetMyAllyTeamID()
	-- don't give the teamID to make a refresh in PlayerChanged
end