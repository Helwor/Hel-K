
function widget:GetInfo()
    return {
        name      = "FixAlreadyBuiltInQueue",
        desc      = "Remove from queue build that are already finished",
        author    = "Helwor",
        date      = "Oct 2023",
        license   = "GNU GPL, v2 or v3",
        layer     = -10, -- Before NoDuplicateOrders
        enabled   = true,
        handler   = true,
    }
end

local Echo = Spring.Echo

------- Spring locals auto declared
local spGetUnitCurrentCommand = Spring.GetUnitCurrentCommand
local spGetMyTeamID = Spring.GetMyTeamID
local spGetUnitHealth = Spring.GetUnitHealth
local spGetUnitsInRectangle = Spring.GetUnitsInRectangle
local spGiveOrderToUnit = Spring.GiveOrderToUnit
----------------------------





local CMD_REMOVE = CMD.REMOVE

local myTeamID = spGetMyTeamID()

function widget:PlayerChanged()
    myTeamID = spGetMyTeamID()
end
local mem = setmetatable({}, {__mode = 'v'})

function widget:UnitCmdDone(unitID, _, team, cmdDone,paramsDone,_,tagDone)
    if team ~= myTeamID then
        return
    end
    
    local cmd,_,tag,p1,_,p3  = spGetUnitCurrentCommand(unitID)
    -- if unitID == 12783 then
    --     Echo('done:' .. tostring(cmdDone),tostring(paramsDone[1]),'tagdone',tagDone,'current: '..tostring(cmd), p1,'tag',tag)
    -- end
    if cmd and cmd < 0 then
        local cmdxz = cmd..'-'..p1..'-'..p3
        if mem[cmdxz] then
            spGiveOrderToUnit(unitID, CMD_REMOVE, tag, 0)
        else
            local temp_key = tmpkey
            local build =  spGetUnitsInRectangle(p1, p3, p1, p3)[1]
            if build and (select(5,spGetUnitHealth(build)) or 0) >= 1 then
                -- if cmd and cmdDone == cmd and paramsDone[1] == p1 and paramsDone[3] == p3 then
                --     tag = tagDone
                -- end
                spGiveOrderToUnit(unitID, CMD_REMOVE, tag, 0)
                -- Echo(unitID,'removing',cmdxz)
                mem[cmdxz] = paramsDone
            end
        end
    end
end
function widget:GameFrame()
    -- Echo('#mem',table.size(mem))
end
function widget:Initialize()
    if Spring.IsReplay() or Spring.GetSpectatingState() then
        widgetHandler:RemoveWidget(widget)
        return
    end
    widget:PlayerChanged()
end
