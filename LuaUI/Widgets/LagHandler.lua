function widget:GetInfo()
    return {
        name        = "Player Lag Handler",
        desc        = "WIP",
        author      = "Helwor",
        date        = "oct 2023",
        license     = "GPLv2",
        layer       = 1000,
        enabled     = true,  --  loaded by default?
        handler     = true,
        api         = true,
    }
end


local Echo = Spring.Echo


local userIsBehind = false
local behind = 0
local joinedInMidGame = false
local progFrame, frameChecked
local spGetGameFrame = Spring.GetGameFrame




function widget:GameProgress(f)
    progFrame = f
    frameChecked = spGetGameFrame()
    if frameChecked < 1 then
        joinedInMidGame = true
        return
    end
    behind = (progFrame-frameChecked)/30
    local behindStr = ('%.1f'):format(behind)
    if behind > 1 then
        userIsBehind = true
    end
    -- Echo('progFrame: ',progFrame, behindStr,'joinedInMidGame:', joinedInMidGame)
end

local checkTime = 5
local time = 0
local spGetGameSpeed = Spring.GetGameSpeed
local spGetMyTeamID = Spring.GetMyTeamID
local spGetPlayerInfo = Spring.GetPlayerInfo
function widget:Update(dt)
    time = time + dt
    if time >= checkTime then
        time = 0
        userIsBehind = false
        if dt > 0.5 then
            userIsBehind = true
        else
            if behind > 1 then
                local frame = spGetGameFrame()
                if frame - frameChecked > 150 then
                    -- in some situation GameProgress hasnt been called for a while, we can't rely on it
                    behind = 0
                end
            end
            if behind > 1 then
                userIsBehind = true
            else
                local userSpeedFactor, speedFactor, paused = spGetGameSpeed()
                local ping = select(6,spGetPlayerInfo(spGetMyTeamID(), true))
                if ping > 0.5 or userSpeedFactor < 2 and userSpeedFactor > speedFactor*1.2 then
                    userIsBehind = true
                    -- Echo('user is Behind')
                end
            end
        end
        WG.userIsBehind = userIsBehind
        -- Echo("userIsBehind is ", userIsBehind)
    end
end
