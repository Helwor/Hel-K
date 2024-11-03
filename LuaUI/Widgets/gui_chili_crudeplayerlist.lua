
function widget:GetInfo()
	return {
		name      = "Chili Crude Player List",
		desc      = "An inexpensive playerlist.",
		author    = "GoogleFrog",
		date      = "8 November 2019",
		license   = "GNU GPL, v2 or later",
		layer     = 50,
		enabled   = true,
	}
end
local Echo = Spring.Echo
if Spring.GetModOptions().singleplayercampaignbattleid then
	function widget:Initialize()
		Spring.SendCommands("info 0")
	end

	return
end

-- A test game: http://zero-k.info/Battles/Detail/797379
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local myAllyTeamID          = Spring.GetMyAllyTeamID()
local myTeamID              = Spring.GetMyTeamID()
local myPlayerID            = Spring.GetMyPlayerID()
local mySpectating          = Spring.GetSpectatingState()
local spGetPlayerRulesParam = Spring.GetPlayerRulesParam
local spGetPlayerList 		= Spring.GetPlayerList
local spGetPlayerInfo		= Spring.GetPlayerInfo
local spGetTeamInfo			= Spring.GetTeamInfo
if mySpectating then
	myTeamID = false
	myAllyTeamID = false
end
local fallbackAllyTeamID    = Spring.GetMyAllyTeamID()

local Chili

local function GetColorChar(colorTable)
	if colorTable == nil then return string.char(255,255,255,255) end
	local col = {}
	for i = 1, 4 do
		col[i] = math.ceil(colorTable[i]*255)
	end
	return string.char(col[4],col[1],col[2],col[3])
end

local pingCpuColors = {
	{0, 1, 0, 1},
	{0.7, 1, 0, 1},
	{1, 1, 0, 1},
	{1, 0.6, 0, 1},
	{1, 0, 0, 1},
	{1, 1, 1, 1},
}

local playerInfo

local ALLY_COLOR  = {0, 1, 1, 1}
local ENEMY_COLOR = {1, 0, 0, 1}

local PING_TIMEOUT = 2 -- seconds

local MAX_NAME_LENGTH = 100

local UPDATE_PERIOD = 1
local DEFAULT_TEXT_HEIGHT = 13
local IMAGE_SHARE  = ":n:" .. LUAUI_DIRNAME .. "Images/playerlist/share.png"
local IMAGE_CPU    = ":n:" .. LUAUI_DIRNAME .. "Images/playerlist/cpu.png"
local IMAGE_PING   = ":n:" .. LUAUI_DIRNAME .. "Images/playerlist/ping.png"
local IMAGE_METAL  = 'LuaUI/Images/ibeam.png'
local IMAGE_ENERGY = 'LuaUI/Images/energy.png'
local defaultamount = 100 -- default amount to give to ally player
local CONTINUE = {energy = {time = 0, target = false, next_time = 0}, metal = {time = 0, target = false, next_time = 0}}
local CONTINUE_TIME = 10 -- how long last the continued sharing
local CONTINUE_FREQUENCY = 1 
local HIDDEN_STORAGE = 10000
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local function PingTimeOut(pingTime)
	if pingTime < 1 then
		return "Ping " .. (math.floor(pingTime*1000) ..'ms')
	elseif pingTime > 999 then
		return "Ping " .. ('' .. (math.floor(pingTime*100/60)/100)):sub(1,4) .. 'min'
	end
	--return (math.floor(pingTime*100))/100
	return "Ping " .. ('' .. (math.floor(pingTime*100)/100)):sub(1,4) .. 's' --needed due to rounding errors.
end

local function CpuUsageOut(cpuUsage)
	return "CPU usage " .. math.ceil(cpuUsage*100) .. "%"
end

local function ToGrey(v)
	if v < 0.6 then
		return 0.6 - 0.1*(0.6 - v)
	end
	return 0.6 + 0.1*(v - 0.6)
end

local function GetName(name, font, state)
	if state.isDead then
		name = "[D] " .. name
	elseif state.isLagging then
		name = "[L] " .. name
	elseif state.isWaiting then
		if state.isSpec and (state.isGone or state.isConnecting) then
			if state.isGone then
				name = "[G] " .. name
			else
				name = "[C] " .. name
			end
		else
			name = "[W] " .. name
		end

		
	elseif state.isAfk then
		name = "[afk] " .. name
	end
	
	if not font then
		return name
	end
	return Spring.Utilities.TruncateStringIfRequiredAndDotDot(name, font, MAX_NAME_LENGTH) or name
end

local function GetPlayerTeamColor(teamID, isDead, specGone)
	local r, g, b, a = Spring.GetTeamColor(teamID)
	if specGone then
		r,g,b,a = 0.3,0.3,0.3,1
	elseif isDead then
		r, g, b = ToGrey(r), ToGrey(g), ToGrey(b)
	end
	return {r, g, b, a}
end

local function ShareUnits(playername, teamID)
	if not teamID then
		Spring.Echo('Player List: Invalid team to share.')
		return
	end
	local selcnt = Spring.GetSelectedUnitsCount()
	if selcnt == 0 then
		Spring.Echo('Player List: No units selected to share.')
		return
	end
	local sel = Spring.GetSelectedUnitsSorted()
	local names = ''
	local count = 0
	local maxcount = 3
	for defID, t in pairs(sel) do
		local name = UnitDefs[defID].humanName
		if name then
			count = count + 1
			if count > maxcount then
				names = names .. '..., '
				break
			else
				names = names .. name .. ', '
			end
		end
	end
	names = names:sub(1,-3)
	
	if names == '' then
		Spring.SendCommands("say a: I gave "..selcnt.." units to "..playername..".")
	else
		Spring.SendCommands("say a: I gave "..names.." (" .. selcnt .. ") to "..playername..".")
	end
	Spring.ShareResources(teamID, "units")
end
local function GetResource(target, kind)
	local tgtCurr, tgtStor = Spring.GetTeamResources(target, kind)
	tgtStor = tgtStor - HIDDEN_STORAGE
	local maxfill =  tgtStor - tgtCurr
	return tgtCurr, tgtStor, maxfill
end
local function GiveResource(target, kind, mod, quiet) -- directly copied from gui_chili_share.lua, the TAB playlist
	--mod = 20,500,all
	if not mod then
		local alt,ctrl,_,shift = Spring.GetModKeyState()
		if alt and shift then
			mod = "continue"
		elseif alt then
			mod = "all"
		elseif ctrl then
			mod = defaultamount/5
		elseif shift then
			mod = defaultamount*5
		else
			mod = defaultamount
		end
	end
	local _, leader, _, isAI = Spring.GetTeamInfo(target, false)
	local name = select(1,Spring.GetPlayerInfo(leader, false))
	if isAI then
		name = select(2,Spring.GetAIInfo(target))
	end
	local playerslist = Spring.GetPlayerList(target, true)
	if #playerslist > 1 then
		name = name .. "'s squad"
	end
	local num = 0
	local currentResourceValue = Spring.GetTeamResources(select(1, Spring.GetMyTeamID(), kind))
	if mod == "continue" then
		CONTINUE[kind] = {time = os.clock() + CONTINUE_TIME, target = target, next_time = os.clock() + CONTINUE_FREQUENCY}
		if not quiet then
			Spring.SendCommands("say a: Giving continued " .. kind .. " to " .. name .. " for " .. CONTINUE_TIME .. " seconds.")
			quiet = true
		end
	elseif mod == "all" then
		num = currentResourceValue
	elseif mod ~= nil then
		num = math.min(mod, currentResourceValue)
	else
		return
	end


	local tgtCurr, tgtStor, maxfill = GetResource(target, kind)

	if tgtStor <= 0 then
		if not quiet then
			Echo(name .. " don't have " .. kind .. ' storage')
		end
		return
	end

	if maxfill <= 0 then
		if not quiet then
			Echo(name .. "'s " .. kind .. ' storage is full')
		end
		return
	end

	if num > maxfill then
		num = maxfill
	end
	if not quiet then
		Spring.SendCommands("say a: I gave " .. math.floor(num) .. " " .. kind .. " to " .. name .. ".")
	end
	Spring.ShareResources(target, kind, num)
end
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local function UpdateEntryData(entryData, controls, pingCpuOnly, forceUpdateControls,info, connecting)
	local newTeamID, newAllyTeamID = entryData.teamID, entryData.allyTeamID
	local newIsLagging = entryData.isLagging
	local newIsWaiting = entryData.isWaiting
	local newIsConnecting = connecting
	local isSpectator = false
	local resortRequired, updateColors = false, false
	if entryData.playerID then
		local playerName, active, spectator, teamID, allyTeamID, pingTime, cpuUsage, country, rank, customKeys = spGetPlayerInfo(entryData.playerID, true)
		if info then
			if info.name and entryData.name ~= info.name then
				entryData.name = info.name
				controls.textName:SetCaption(GetName(entryData.name, controls.textName.font, entryData))
			end
			country = country~='' and country or info.country~='' and info.country
			if country then
				entryData.country = ("LuaUI/Images/flags/" .. country ..".png")
				controls.imCountry.file = entryData.country
				controls.imCountry.color = {1,1,1,1} -- remove the transparency, since we made a placeholder for the image (that would have been blank without transparency)
				controls.imCountry:Invalidate()
			end
			if info.icon and entryData.rank == "LuaUI/Images/LobbyRanks/0_0.png" then
				entryData.rank = "LuaUI/Images/LobbyRanks/" .. info.icon .. ".png"
				controls.imRank.file = entryData.rank
				controls.imRank:Invalidate()
			end
			if not entryData.clan then
				local clan
				if info.clan and VFS.FileExists("LuaUI/Configs/Clans/" .. info.clan ..".png") then
					clan = "LuaUI/Configs/Clans/" .. info.clan ..".png"
				elseif info.faction and  VFS.FileExists("LuaUI/Configs/Factions/" .. info.faction .. ".png") then
					clan = "LuaUI/Configs/Factions/" .. info.faction .. ".png"
				end
				if clan then
					entryData.clan = clan
					controls.imClan.file = entryData.clan
					controls.imClan.color = {1,1,1,1} -- remove the transparency, since we made a placeholder for the image (that would have been blank without transparency)
					controls.imClan:Invalidate()
				end
			end
			return
		end

		newTeamID, newAllyTeamID = teamID, allyTeamID
		entryData.isMe = (entryData.playerID == myPlayerID)

		if spectator then
			isSpectator = true
			newTeamID, newAllyTeamID = entryData.initTeamID,  entryData.initAllyTeamID
		end
		
		local pingBucket = (active and math.max(1, math.min(5, math.ceil(math.min(pingTime, 1) * 5)))) or 6
		if forceUpdateControls or pingBucket ~= entryData.pingBucket then
			entryData.pingBucket = pingBucket
			if controls then
				controls.imPing.color = pingCpuColors[entryData.pingBucket]
				controls.imPing:Invalidate()
			end
		end
		
		local cpuBucket = (active and math.max(1, math.min(5, math.ceil(cpuUsage * 5)))) or 6
		if forceUpdateControls or cpuBucket ~= entryData.cpuBucket then
			entryData.cpuBucket = cpuBucket
			if controls then
				controls.imCpu.color = pingCpuColors[entryData.cpuBucket]
				controls.imCpu:Invalidate()
			end
		end
		
		if controls then
			controls.imCpu.tooltip = CpuUsageOut(cpuUsage)
			controls.imPing.tooltip = PingTimeOut(pingTime)
		end
		
		newIsLagging = ((pingTime > PING_TIMEOUT) and true) or false
		if forceUpdateControls or newIsLagging ~= entryData.isLagging then
			entryData.isLagging = newIsLagging
			if controls and not entryData.isDead then
				controls.textName:SetCaption(GetName(entryData.name, controls.textName.font, entryData))
			end
		end
		
		newIsWaiting = (not active)
		if forceUpdateControls or newIsConnecting or newIsWaiting ~= entryData.isWaiting then
			-- Echo('update for ',entryData.name)
			-- Echo(entryData.name,'active update, now ' .. tostring(active),'before '.. tostring(entryData.isWaiting),'connecting: '..tostring(entryData.connecting))
			resortRequired = true
			entryData.isConnecting = newIsWaiting and newIsConnecting
			entryData.isGone = not entryData.isWaiting and newIsWaiting -- and (newIsWaiting ~= entryData.isWaiting or entryData.isGone)
			-- entryData.isWaiting = not entryData.isGone and not entryData.isConnecting
			entryData.isWaiting = newIsWaiting
			-- if not newIsWaiting and playerInfo[entryData.name] then
			-- 	entryData.connecting = false
			-- end
			if controls and not (entryData.isDead or entryData.isLagging) then
				controls.textName:SetCaption(GetName(entryData.name, controls.textName.font, entryData))
			end
			if entryData.isSpec then
				if controls then
					-- dark grey when specs are not connected
					controls.textName.font.color = GetPlayerTeamColor(entryData.teamID, true,newIsWaiting)
					-- controls.textAllyTeam.font.color = GetPlayerTeamColor(entryData.teamID, true,newIsWaiting)
					controls.textTeamID.font.color = GetPlayerTeamColor(entryData.teamID, true,newIsWaiting)
					controls.textName:SetCaption(GetName(entryData.name, controls.textName.font, entryData))
					-- controls.textAllyTeam:SetCaption('0')
					controls.textTeamID:SetCaption('0')


					-- controls.textAllyTeam:Invalidate()
					controls.textTeamID:Invalidate()
					controls.textName:Invalidate()
				end
			end
			-- Echo(entryData.name,'is now',newIsWaiting and 'waiting' or 'not waiting','connecting?',newIsConnecting )
		end
		
		newIsAfk = (spGetPlayerRulesParam(entryData.playerID, "lagmonitor_lagging") and true) or false
		if forceUpdateControls or newIsAfk ~= entryData.isAfk then
			entryData.isAfk = newIsAfk
			-- entryData.isConnecting = newIsConnecting
			if controls and not (entryData.isDead or entryData.isLagging or entryData.isWaiting) then
				controls.textName:SetCaption(GetName(entryData.name, controls.textName.font, entryData))
			end
		end
		
		if pingCpuOnly then
			return false
		end
	elseif pingCpuOnly then
		return false
	end
	
	-- Ping and CPU cannot resort
	if forceUpdateControls or newTeamID ~= entryData.teamID then
		entryData.teamID = newTeamID
		entryData.isMyTeam = (newTeamID == myTeamID)
		resortRequired = true
		if controls then
			controls.textName.font.color = GetPlayerTeamColor(entryData.teamID, entryData.isDead)
 			controls.textName:Invalidate()
 			if not isSpectator then
				controls.textTeamID.font.color = GetPlayerTeamColor(entryData.teamID, false, entryData.isWaiting)
				controls.textTeamID:SetCaption(entryData.teamID)
				controls.textTeamID:Invalidate()
				updateColors = true
			end
		end
	end
	if forceUpdateControls or newAllyTeamID ~= entryData.allyTeamID then
		entryData.allyTeamID = newAllyTeamID
		resortRequired = true
		if entryData.isMe then
			updateColors = true
		end
		if controls then
			-- controls.textAllyTeam:SetCaption(entryData.allyTeamID + 1)
			controls.textTeamID:SetCaption(entryData.teamID)
		end
	end
	
	local isMyAlly = (entryData.allyTeamID == (myAllyTeamID or fallbackAllyTeamID))
	if forceUpdateControls or isMyAlly ~= entryData.isMyAlly then
		entryData.isMyAlly = isMyAlly
		entryData.allyTeamColor = (isMyAlly and ALLY_COLOR) or ENEMY_COLOR
		resortRequired = true
		if controls then
			-- controls.textAllyTeam.font.color = entryData.allyTeamColor
			-- controls.textAllyTeam:Invalidate()
			controls.textTeamID.font.color = entryData.allyTeamColor -- not used anymore to set the header team colors
			controls.textTeamID:Invalidate()
			local shareVisible = myAllyTeamID and entryData.isMyAlly and not entryData.isDead and (entryData.teamID ~= myTeamID) and true or false
			controls.btnShare:SetVisibility(shareVisible)
			controls.btnMetal:SetVisibility(shareVisible)
			controls.btnEnergy:SetVisibility(shareVisible)
		end
	end

	local newIsDead = ((isSpectator and not entryData.isSpec or Spring.GetTeamRulesParam(entryData.teamID, "isDead")) and true) or false
	if newIsDead then
		if forceUpdateControls or newIsDead ~= entryData.isDead then
			entryData.isDead = newIsDead
			if controls then
				controls.textName:SetCaption(GetName(entryData.name, controls.textName.font, entryData))
				controls.textName.font.color = GetPlayerTeamColor(entryData.teamID, entryData.isDead)
				controls.textName:Invalidate()
			end
		end
	elseif entryData.isDead and not newIsDead or entryData.isSpec and not isSpectator then -- case cheat when user go from spec to team
		entryData.isDead = newIsDead
		entryData.isSpec = isSpectator
		resortRequired = true
		if controls then

			controls.textTeamID.font.color = GetPlayerTeamColor(entryData.teamID, false, entryData.isWaiting)
			controls.textTeamID:SetCaption(entryData.teamID)
			controls.textTeamID:Invalidate()
			controls.textName.font.color = GetPlayerTeamColor(entryData.teamID, false)
			controls.textName:SetCaption(GetName(entryData.name, controls.textName.font, entryData))
			controls.textName:Invalidate()
		end

	elseif isSpectator and entryData.isSpec then
		if forceUpdateControls then

			resortRequired = true
			if controls then
				controls.textName.font.color = GetPlayerTeamColor(entryData.teamID, true, entryData.isWaiting)
				-- controls.textAllyTeam.font.color = GetPlayerTeamColor(entryData.teamID, true, entryData.isWaiting)
				controls.textTeamID.font.color = GetPlayerTeamColor(entryData.teamID, true, entryData.isWaiting)
				controls.textName:SetCaption(GetName(entryData.name, controls.textName.font, entryData))
				-- controls.textAllyTeam:SetCaption('0')
				controls.textTeamID:SetCaption('0')

				controls.textName:Invalidate()
				-- controls.textAllyTeam:Invalidate()
				controls.textTeamID:Invalidate()
			end
		end

	end

	return resortRequired, updateColors
end

local function GetEntryData(playerID, teamID, allyTeamID, isAiTeam, isDead, isSpec)
	local entryData = {
		playerID = playerID,
		teamID = teamID,
		allyTeamID = allyTeamID,
		initTeamID = teamID,
		initAllyTeamID = allyTeamID,
		isAiTeam = isAiTeam,
		isDead = isDead,
		isSpec = isSpec,
	}
	
	if playerID then
		local playerName, active, spectator, teamID, allyTeamID, pingTime, cpuUsage, country, rank, customKeys = spGetPlayerInfo(playerID, true)
		local info = playerInfo[playerName]
		-- if isSpec and not active and Spring.GetGameFrame()<1 then
		-- 	entryData.connecting = true
		-- end
		if info then
			country = country or info.country
			customKeys.icon = customKeys.icon or info.icon
			customKeys.clan = customKeys.clan or info.clan
			customKeys.faction = customKeys.faction or info.faction
			customKeys.elo = customKeys.elo or info.elo
		end
		-- if not spectator then
		-- 	Echo("playerName,customKeys.elo is ", playerName,customKeys.elo)
		-- end
		customKeys = customKeys or {}
		entryData.isMe = (entryData.playerID == myPlayerID)
		entryData.name = playerName
		entryData.country = (country and country ~= '' and ("LuaUI/Images/flags/" .. country ..".png"))
		entryData.rank = ("LuaUI/Images/LobbyRanks/" .. (customKeys.icon or "0_0") .. ".png")
		entryData.elo = customKeys.elo
		if customKeys.clan and customKeys.clan ~= "" then
			entryData.clan = VFS.FileExists("LuaUI/Configs/Clans/" .. customKeys.clan ..".png") and "LuaUI/Configs/Clans/" .. customKeys.clan ..".png" or nil
		elseif customKeys.faction and customKeys.faction ~= "" then
			entryData.clan = VFS.FileExists("LuaUI/Configs/Factions/" .. customKeys.faction .. ".png") and "LuaUI/Configs/Factions/" .. customKeys.faction .. ".png"
		end
	end
	
	if isAiTeam then
		local _, name = Spring.GetAIInfo(teamID)
		entryData.name = name
	end
	
	if not entryData.name then
		entryData.name = "noname"
	end
	
	UpdateEntryData(entryData)
	
	return entryData
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local function GetUserControls(playerID, teamID, allyTeamID, isAiTeam, isDead, isSpec, parent)
	local offset             = 0
	local offsetY            = 0
	local height             = options.text_height.value + 4
	local userControls = {}
	userControls.entryData = GetEntryData(playerID, teamID, allyTeamID, isAiTeam, isDead, isSpec)

	userControls.mainControl = Chili.Control:New {
		-- name = playerID,
		x = 0,
		top = 0,
		bottom = 0,
		right = 0,
		height = height,
		padding = {0, 0, 0, 0},
		-- itemPadding = {0, -5, 0, 0},
		-- borderColor = {1,0,0,1},
		-- backgroundColor = {0,0,1,1},
		parent = parent
	}

	offset = offset + 1
	-- if userControls.entryData.country then
		userControls.imCountry = Chili.Image:New {
			name = "imCountry",
			color = not userControls.entryData.country and {0,0,0,0} or nil,
			x = offset,
			y = offsetY,
			width = options.text_height.value + 3,
			height = options.text_height.value + 3,
			parent = userControls.mainControl,
			keepAspect = true,
			file = userControls.entryData.country,
		}
	-- end
	offset = offset + options.text_height.value + 3

	offset = offset + 1
	if userControls.entryData.rank then
		userControls.imRank = Chili.Image:New {
			name = "imRank",
			x = offset,
			y = offsetY,
			width = options.text_height.value + 3,
			height = options.text_height.value + 3,
			parent = userControls.mainControl,
			keepAspect = true,
			file = userControls.entryData.rank,
		}
	end
	offset = offset + options.text_height.value + 3
	
	offset = offset + 1
	-- if userControls.entryData.clan then
		userControls.imClan = Chili.Image:New {
			backGroundColor = {0,0,0,0},
			color = not userControls.entryData.clan and {0,0,0,0} or nil,
			name = "imClan",
			x = offset,
			y = offsetY,
			width = options.text_height.value + 3,
			height = options.text_height.value + 3,
			parent = userControls.mainControl,
			keepAspect = true,
			file = userControls.entryData.clan or '',
		}
	-- end
	offset = offset + options.text_height.value + 3

	offset = offset + 1
	-- if userControls.entryData.clan then
	userControls.txtElo = Chili.Label:New {
		name = "elo",
		x = offset,
		y = offsetY + 1,
		right = 0,
		bottom = 3,
		parent = userControls.mainControl,
		caption = userControls.entryData.elo and ('%.1f'):format(userControls.entryData.elo/1000) or '',
		fontsize = options.text_height.value,
		fontShadow = true,
		autosize = false,
	}
	-- end
	offset = offset + options.text_height.value + 3


	offset = offset + 15
	-- userControls.textAllyTeam = Chili.Label:New {
	-- 	name = "textAllyTeam",
	-- 	x = offset,
	-- 	y = offsetY + 1,
	-- 	right = 0,
	-- 	bottom = 3,
	-- 	-- parent = userControls.mainControl,
	-- 	caption = userControls.entryData.allyTeamID + (isSpec and not isDead and 0 or 1),
	-- 	textColor = userControls.entryData.allyTeamColor,
	-- 	fontsize = options.text_height.value,
	-- 	fontShadow = true,
	-- 	autosize = false,
	-- }
	userControls.textTeamID = Chili.Label:New {
		name = "textTeamID",
		x = offset,
		y = offsetY + 1,
		right = 0,
		bottom = 3,
		parent = userControls.mainControl,
		caption = isSpec and not isDead and 0 or userControls.entryData.teamID,
		textColor = userControls.entryData.allyTeamColor,
		fontsize = options.text_height.value,
		fontShadow = true,
		autosize = false,
	}
	offset = offset + options.text_height.value --+ 3
	
	offset = offset + 2
	userControls.textName = Chili.Label:New {
		name = "textName",
		x = offset,
		y = offsetY + 1,
		right = 0,
		bottom = 3,
		align = "left",
		parent = userControls.mainControl,
		caption = GetName(userControls.entryData.name, nil, userControls.entryData),
		textColor = GetPlayerTeamColor(userControls.entryData.teamID, userControls.entryData.isDead or userControls.entryData.isSpec),
		fontsize = options.text_height.value,
		fontShadow = true,
		autosize = false,
	}
	userControls.textName:SetCaption(GetName(userControls.entryData.name, userControls.textName.font, userControls.entryData))
	offset = offset + MAX_NAME_LENGTH - 15

	offset = offset + 1
	userControls.btnShare = Chili.Button:New {
		name = "btnShare",
		x = offset + 2,
		y = offsetY + 2,
		width = options.text_height.value - 1,
		height = options.text_height.value - 1,
		parent = userControls.mainControl,
		caption = "",
		tooltip = "Click to share the units you have selected to this player.",
		padding ={0,0,0,0},
		OnClick = {function(self)
			ShareUnits(userControls.entryData.name, userControls.entryData.teamID)
		end, },
	}
	Chili.Image:New {
		name = "imShare",
		x = 0,
		y = 0,
		right = 0,
		bottom = 0,
		parent = userControls.btnShare,
		keepAspect = true,
		file = IMAGE_SHARE,
	}
	userControls.btnShare:SetVisibility((userControls.entryData.isMyAlly and (userControls.entryData.teamID ~= myTeamID) and true) or false)
	offset = offset + options.text_height.value + 1



	offset = offset + 1
	userControls.btnMetal = Chili.Button:New {
		name = "btnMetal",
		x = offset + 2,
		y = offsetY + 2,
		width = options.text_height.value - 1,
		height = options.text_height.value - 1,
		parent = userControls.mainControl,
		caption = "",
		tooltip = "Click to give Metal to this player.",
		padding ={0,0,0,0},
		OnMouseOver = {
			function(self)
				local cur, stor = GetResource(userControls.entryData.teamID, 'metal')
				self.tooltip = ('M:' .. '%d' .. '/' .. '%d'):format(cur,stor)
			end
		},
		OnClick = {function(self)
			GiveResource(userControls.entryData.teamID,"metal")
			local cur, stor = GetResource(userControls.entryData.teamID, 'metal')
			self.tooltip = ('M:' .. '%d' .. '/' .. '%d'):format(cur,stor)

		end, },
	}
	Chili.Image:New {
		name = "imMetal",
		x = 0,
		y = 0,
		right = 0,
		bottom = 0,
		parent = userControls.btnMetal,
		keepAspect = true,
		file = IMAGE_METAL,
	}
	userControls.btnMetal:SetVisibility((userControls.entryData.isMyAlly and (userControls.entryData.teamID ~= myTeamID) and true) or false)
	offset = offset + options.text_height.value + 1



	offset = offset + 1
	userControls.btnEnergy = Chili.Button:New {
		name = "btnEnergy",
		x = offset + 2,
		y = offsetY + 2,
		width = options.text_height.value - 1,
		height = options.text_height.value - 1,
		parent = userControls.mainControl,
		caption = "",
		tooltip = "Click to give Energy to this player.",
		padding ={0,0,0,0},
		OnMouseOver = {
			function(self)
				local cur, stor = GetResource(userControls.entryData.teamID, 'energy')
				self.tooltip = ('E:' .. '%d' .. '/' .. '%d'):format(cur,stor)
			end
		},
		OnClick = {function(self)
			GiveResource(userControls.entryData.teamID,"energy")
			local cur, stor = GetResource(userControls.entryData.teamID, 'energy')
			self.tooltip = ('E:' .. '%d' .. '/' .. '%d'):format(cur,stor)

		end, },
	}
	Chili.Image:New {
		name = "imEnergy",
		x = 0,
		y = 0,
		right = 0,
		bottom = 0,
		parent = userControls.btnEnergy,
		keepAspect = true,
		file = IMAGE_ENERGY,
	}
	userControls.btnEnergy:SetVisibility((userControls.entryData.isMyAlly and (userControls.entryData.teamID ~= myTeamID) and true) or false)
	offset = offset + options.text_height.value + 1



	offset = offset + 1
	if userControls.entryData.cpuBucket then
		userControls.imCpu = Chili.Image:New {
			name = "imCpu",
			x = offset,
			y = offsetY,
			width = options.text_height.value + 3,
			height = options.text_height.value + 3,
			parent = userControls.mainControl,
			keepAspect = true,
			file = IMAGE_CPU,
			color = pingCpuColors[userControls.entryData.cpuBucket],
		}
		function userControls.imCpu:HitTest(x,y) return self end
	end
	offset = offset + options.text_height.value
	
	offset = offset + 1
	if userControls.entryData.pingBucket then
		userControls.imPing = Chili.Image:New {
			name = "imPing",
			x = offset,
			y = offsetY,
			width = options.text_height.value + 3,
			height = options.text_height.value + 3,
			parent = userControls.mainControl,
			keepAspect = true,
			file = IMAGE_PING,
			color = pingCpuColors[userControls.entryData.pingBucket],
		}
		function userControls.imPing:HitTest(x,y) return self end
	end
	offset = offset + options.text_height.value

	UpdateEntryData(userControls.entryData, userControls, false, true)

	return userControls
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local playerlistWindow
local scrollPanel
local stackPanel
local header
local listControls = {}
local playersByPlayerID = {}
local teamByTeamID = {}

local function Compare(ac, bc)
	local a, b = ac.entryData, bc.entryData

	if a.isSpec ~= b.isSpec then
		return not a.isSpec
	elseif a.isSpec and b.isSpec and not b.isMe then
		if a.isWaiting~=b.isWaiting then
			return b.isWaiting 
		end
	end

	if a.allyTeamID ~= b.allyTeamID then
		return a.allyTeamID < b.allyTeamID
	end


	if a.isAiTeam ~= b.isAiTeam then
		return not a.isAiTeam
	elseif a.isAiTeam then
		return a.teamID < b.teamID
	end
	--

	
	if not a.isMyTeam ~= not b.isMyTeam then
		return b.isMyTeam
	end
	
	if not a.isMyAlly ~= not b.isMyAlly then
		return b.isMyAlly
	end
	

	if not a.isMe ~= not b.isMe then
		return a.isMe
	end
	
	if not a.isAiTeam ~= not b.isAiTeam then
		return a.isAiTeam
	end
	
	if --[[not a.isSpec and--]] a.elo and b.elo then
		return tonumber(a.elo) > tonumber(b.elo)
	end
	if a.rank and b.rank then
		return tonumber(a.rank:match('%d')) > tonumber(b.rank:match('%d'))
	end	

	if a.teamID ~= b.teamID then
		return a.teamID > b.teamID
	end
	if a.playerID then
		return (not b.playerID) or a.playerID > b.playerID
	end
	return (not b.playerID)
end
local function Unlink(obj)
	while type(obj)=='userdata' do
		obj = obj()
	end
	return obj
end
local function SortEntries()
	if not playerlistWindow then
		return
	end
	
	table.sort(listControls, Compare)
	
	local toTop = options.alignToTop.value
	local offset = options.text_height.value -5

	local teams = {}
	for i = 1, #listControls do
		local control = listControls[i]
		local userControl = control.mainControl
		local userData = control.entryData
		local isPlayer = not userData.isSpec
		-- local teamTxt = tonumber(listControls[i].textAllyTeam.caption)
		local allyTeam = tonumber(userData.allyTeamID) + (isPlayer and 1 or 0)
		local thisTeam = teams[allyTeam]

		if not userData.isSpec then
			if not thisTeam then
				thisTeam = {}
				teams[allyTeam] = thisTeam
				thisTeam.count = 1
				thisTeam.aiCount = 0
				if isPlayer then
					thisTeam.elo = userData.elo or 0
				end
				-- local color = userData.allyTeamColor
				local color = listControls[i].textName.font.color
				thisTeam.color = not isPlayer and {ToGrey(color[1]), ToGrey(color[2]), ToGrey(color[3])} or color
			else
				thisTeam.count = thisTeam.count + 1
				if isPlayer then
					thisTeam.elo = thisTeam.elo + (userData.elo or 0)
				end
			end
		end
		if userData.isAiTeam then
			thisTeam.aiCount = thisTeam.aiCount + 1
		end
		if toTop then
			userControl._relativeBounds.top = offset
			userControl._relativeBounds.bottom = nil
		else
			userControl._relativeBounds.top = nil
			userControl._relativeBounds.bottom = offset
		end
		userControl:UpdateClientArea(false)
		
		offset = offset + options.text_height.value + 2
	end

	if toTop then
		header._relativeBounds.bottom = false
		header._relativeBounds.top = 1
	else
		header._relativeBounds.top = false
		header._relativeBounds.bottom = options.text_height.value - header.parent.padding[3] + 1
	end

	local headerCaption = ''
	local function coloredString(str,color)
		return '\255' .. string.char(color[1]*255) .. string.char(color[2]*255) ..  string.char(color[3]*255) .. str .. '\008'
	end

	for _, t in ipairs(teams) do
		local countTxt =  coloredString(t.count,t.color)
		local humanPlayers = t.count - t.aiCount
		headerCaption = headerCaption .. countTxt .. (tonumber(t.elo)>0 and ' (' .. ('%.1f'):format(t.elo/(humanPlayers)/1000) .. ') ' or '') .. 'v '
	end
	headerCaption = headerCaption:sub(1,-3)
	if not teams[3] and teams[1] and teams[2] and tonumber(teams[1].elo)>0 and tonumber(teams[2].elo)>0 then
		local avgElo1 = teams[1].elo/teams[1].count
		local avgElo2 = teams[2].elo/teams[2].count
		local avgEloDiff = avgElo1 - avgElo2
		-- local eloDiff = teams[1].elo - teams[2].elo -- not relevant since teams can be uneven
		headerCaption = headerCaption .. ' | elo ~'..(avgEloDiff>0 and '+' or '') ..  ('%d'):format(avgEloDiff)
	end
	local specCount = teams[0] and coloredString(teams[0].count,teams[0].color)
	if specCount then
		headerCaption = headerCaption .. ' | ' .. specCount
	end
	header:SetCaption(headerCaption)
	header.font.autoOutlineColor = false -- keep the outline black no matter which color in the string (much less ugly)

end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local function UpdateTeam(teamID)
	local controls = teamByTeamID[teamID]
	if not controls then
		return
	end
	
	local toSort = UpdateEntryData(controls.entryData, controls)
	if toSort then
		SortEntries()
	end
end

local function UpdatePlayer(playerID, info, connecting)
	local controls = playersByPlayerID[playerID]
	local toSort
	local name, active, spectator, teamID, allyTeamID, pingTime, cpuUsage, country = spGetPlayerInfo(playerID, false)
	if not controls then
		local name, active, spectator, teamID, allyTeamID, pingTime, cpuUsage, country = spGetPlayerInfo(playerID, false)
		local isSpec = (--[[teamID == 0 and --]]spectator and spGetPlayerRulesParam(playerID, "initiallyPlayingPlayer") ~= 1)

		-- if isSpec then
		if not controls then
			toSort = true
			controls = GetUserControls(playerID, teamID, allyTeamID, isAiTeam, isDead, isSpec, scrollPanel)
			listControls[#listControls + 1] = controls
			teamByTeamID[teamID] = controls
			playersByPlayerID[playerID] = controls
		end
		if not controls then
			return
		end
	end

	local _toSort, updateColors = UpdateEntryData(controls.entryData, controls, false, false, info, connecting)
	-- Echo('received ', info and info.name,'sort?',toSort)
	if updateColors then
		for _, controls in pairs (listControls) do
			local entryData = controls.entryData
			controls.textName.font.color = GetPlayerTeamColor(entryData.teamID, entryData.isSpec, entryData.isWaiting)
			-- controls.textName:SetCaption(controls.textName.caption .. 'A')
			controls.textName:Invalidate()
			controls.textTeamID.font.color = GetPlayerTeamColor(entryData.teamID, entryData.isSpec, entryData.isWaiting)
			-- controls.textTeamID:SetCaption(controls.textTeamID.caption .. 'B')
			controls.textTeamID:Invalidate()
		end
	end
	if toSort or _toSort then
		SortEntries()
	end
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local function InitializePlayerlist()
	if playerlistWindow then
		playerlistWindow:Dispose()
		playerlistWindow = nil
	end
	
	if listControls then
		for i = 1, #listControls do
			if listControls[i].mainControl then
				listControls[i].mainControl:Dispose()
			end
		end
		listControls = {}
		playersByPlayerID = {}
		teamByTeamID = {}
	end
	local screenWidth, screenHeight = Spring.GetViewGeometry()
	local windowWidth = MAX_NAME_LENGTH + 10*(options.text_height.value or 13) + 40

	--// WINDOW
	scrollPanel = Chili.ScrollPanel:New{
		backgroundColor = {0, 0, 0, 0},
		color = {0, 0, 0, 0},
		borderColor = {0, 0, 0, 0},
		-- border = {0,0,0,0},
		width = '100%',
		height = '100%',
		y = 13, 
		bottom = 13,
		-- top = 13,

		-- minHeight = 100,
		-- autosize = true,
		-- scrollbarSize = 6,
		horizontalScrollbar = false,
        padding = {0,-7,0,0},
        -- itemPadding = {0,-7,0,0},
        -- itemMargin = {0,-7,0,0},
        -- margin =  {0,-7,0,0},
        -- itemPadding = {0,-25,0,0},
	}
	-- local stackPanel = Chili.StackPanel:New{height = 800, width = 800--[[, autoResize = true--]]}
	header = Chili.Label:New{
		caption = 'recap',
		bottom = 20,
		fontsize = options.text_height.value,
	}
	playerlistWindow = Chili.Window:New{
		backgroundColor = {0, 0, 0, 0},
		color = {0, 0, 0, 0},
		parent = Chili.Screen0,
		-- margin = {0,13,0,0},
		dockable = true,
		name = "Player List", -- NB: this exact string is needed for HUD preset playerlist handling
		padding = {0, 0, 11, 0},
		x = screenWidth - windowWidth,
		y = math.floor(screenHeight/10),
		width = windowWidth,
		minWidth = windowWidth,
		clientHeight = math.floor(screenHeight/2),
		minHeight = 100,
		draggable = false,
		resizable = true,
		tweakDraggable = true,
		tweakResizable = true,
		minimizable = false,

		children = {
			header,
			scrollPanel
		},
	}

	local gaiaTeamID = Spring.GetGaiaTeamID
	local teamList = Spring.GetTeamList()
	for i = 1, #teamList do
		local teamID = teamList[i]
		if teamID ~= gaiaTeamID then
			local _, leaderID, isDead, isAiTeam, side, allyTeamID = spGetTeamInfo(teamID, false)
			Echo(teamID,_,"isAiTeam, leaderID is ", isAiTeam, leaderID)
			if leaderID < 0 then
				leaderID = Spring.GetTeamRulesParam(teamID, "initLeaderID") or leaderID
			end
			
			if leaderID >= 0 then
				if isAiTeam then
					leaderID = nil
				end
				
				local controls = GetUserControls(leaderID, teamID, allyTeamID, isAiTeam, isDead, false, scrollPanel)
				listControls[#listControls + 1] = controls
				teamByTeamID[teamID] = controls
				if leaderID then
					playersByPlayerID[leaderID] = controls
				end
			end
		end
	end
	-- go through all players, register as entities, assign to teams
	for i,playerID in ipairs(spGetPlayerList()) do
		local name, active, spectator, teamID, allyTeamID, pingTime, cpuUsage, country = spGetPlayerInfo(playerID, false)
		local isSpec = (--[[teamID == 0 and--]] spectator and spGetPlayerRulesParam(playerID, "initiallyPlayingPlayer") ~= 1)
		if isSpec then
			local controls = GetUserControls(playerID, teamID, allyTeamID, isAiTeam, isDead, isSpec, scrollPanel)
			listControls[#listControls + 1] = controls
			teamByTeamID[teamID] = controls
			playersByPlayerID[playerID] = controls
		end
	end
	SortEntries()
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

options_path = 'Settings/HUD Panels/Player List'
options_order = {'text_height', 'backgroundOpacity', 'alignToTop'}
options = {
	text_height = {
		name = 'Font Size (10-18)',
		type = 'number',
		value = DEFAULT_TEXT_HEIGHT,
		min = 10, max = 18, step = 1,
		OnChange = InitializePlayerlist,
		advanced = true
	},
	backgroundOpacity = {
		name = "Background opacity",
		type = "number",
		value = 0, min = 0, max = 1, step = 0.01,
		OnChange = function(self)
			playerlistWindow.backgroundColor = {1,1,1,self.value}
			playerlistWindow.borderColor = {1,1,1,self.value}
			playerlistWindow:Invalidate()
		end,
	},
	alignToTop = {
		name = "Align to top",
		type = 'bool',
		value = false,
		desc = "Align list entries to top (i.e. don't push to bottom)",
		OnChange = SortEntries,
	},
}

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local lastUpdate = 0
function widget:Update(dt)
	for kind, cont in pairs(CONTINUE) do
		if cont.target then
			local now = os.clock()
			if cont.next_time < now then
				cont.next_time = now + 1
				GiveResource(cont.target, kind, 'all', true)
				if cont.time < now then
					cont.target = false
				end
			end
		end
	end
	lastUpdate = lastUpdate + dt
	if lastUpdate < UPDATE_PERIOD then
		return
	end
	lastUpdate = 0
	
	for i = 1, #listControls do
		UpdateEntryData(listControls[i].entryData, listControls[i], true)
	end
end

function widget:PlayerChanged(playerID)
	-- local name, active, spectator, teamID, allyTeamID, pingTime, cpuUsage, country, rank, customKeys = spGetPlayerInfo(playerID, true)
	-- Echo('player',playerID,'CHANGED','name?',name,'playerInfo?',playerInfo[name])
	if playerID == myPlayerID then
		local isSpectating = Spring.GetSpectatingState()
		local ownAllyTeamID = Spring.GetMyAllyTeamID()
		local ownTeamID = Spring.GetMyTeamID()
		local updateAll = false
		-- local changedTeam = ownTeamID ~= myTeamID
		
		if mySpectating ~= isSpectating then
			updateAll = true
			mySpectating = isSpectating
		end
		if myAllyTeamID ~= (not mySpectating and ownAllyTeamID) then
			updateAll = true
			myAllyTeamID = (not mySpectating and ownAllyTeamID)
		end
		if myTeamID ~= (not mySpectating and ownTeamID) then
			updateAll = true
			myTeamID = (not mySpectating and ownTeamID)
		end
		
		if changedTeam then
			local toSort = false
			for i = 1, #listControls do
				toSort = UpdateEntryData(listControls[i].entryData, listControls[i], false, true) or toSort
			end
			
			if toSort then
				SortEntries()
			end
			return
		end
	end
	
	UpdatePlayer(playerID,nil, not playerInfo[name])
end

function widget:PlayerAdded(playerID)
	UpdatePlayer(playerID,nil, true)
	-- local name, active, spectator, teamID, allyTeamID, pingTime, cpuUsage, country, rank, customKeys = spGetPlayerInfo(playerID, true)
	-- Echo('player',playerID,'ADDED','name?',name,'playerInfo?',playerInfo[name],'elo?',customKeys.elo)

end

function widget:PlayerRemoved(playerID)
	-- local name, active, spectator, teamID, allyTeamID, pingTime, cpuUsage, country, rank, customKeys = spGetPlayerInfo(playerID, true)
	-- Echo('player',playerID,'REMOVED','name?',name,'playerInfo?',playerInfo[name])
	UpdatePlayer(playerID)
end

function widget:TeamDied(teamID)
	UpdateTeam(teamID)
end

function widget:TeamChanged(teamID)
	UpdateTeam(teamID)
end
local function CorrectUserInfo(info)
	if info.clan and not VFS.FileExists("LuaUI/Configs/Clans/" .. info.clan ..".png") then
		if VFS.FileExists("LuaUI/Configs/Factions/" .. info.clan .. ".png") then
			info.faction, info.clan = info.clan, nil
		elseif VFS.FileExists("LuaUI/Images/flags/" .. info.clan ..".png") then
			info.country, info.clan = info.clan, nil
		end
	end
	if info.faction and not VFS.FileExists("LuaUI/Configs/Factions/" .. info.faction .. ".png") then
		if VFS.FileExists("LuaUI/Images/flags/" .. info.faction ..".png") then
			info.country, info.faction = info.faction, nil
		end
	end
	return info
end
function widget:ReceiveUserInfo(info, simulated)
	local newPlayer = not simulated and not playerInfo[info.name]
	playerInfo[info.name] = CorrectUserInfo(info)

	for i,playerID in ipairs(spGetPlayerList()) do
		local name, active, spectator, teamID, allyTeamID, pingTime, cpuUsage, country, rank, customKeys = spGetPlayerInfo(playerID, true)
		if name == info.name then
			info.elo = customKeys.elo or info.elo
		-- for k,v in pairs(info) do
		-- 	if k~='name' then
		-- 		Echo('=> ' .. k .. ' = ' .. tostring(v))
		-- 	end
		-- end

			-- Echo('got playerID: ' .. playerID,'country?',country,info.country)
			UpdatePlayer(playerID, info,newPlayer)
			break
		end
	end
	-- for playerID, controls in pairs(playersByPlayerID) do
	-- 	if controls.entryData and controls.entryData.name == info.name then
	-- 		UpdateEntryData(controls.entryData, controls, false, false, info)
	-- 		break
	-- 	end
	-- end

end

function widget:Initialize()
	Chili = WG.Chili

	if (not Chili) then
		widgetHandler:RemoveWidget()
		return
	end
	WG.playerInfo = WG.playerInfo or {}
	playerInfo = WG.playerInfo
	InitializePlayerlist()
	for name, info in pairs(playerInfo) do
		widget:ReceiveUserInfo(info, true)
	end
	if not next(playerInfo) then -- in case of cheat and impersonating a team
		widget:PlayerChanged(Spring.GetMyPlayerID())
	end
	Spring.SendCommands("info 0")
end

--function widget:Shutdown()
--	Spring.SendCommands("info 1")
--end
