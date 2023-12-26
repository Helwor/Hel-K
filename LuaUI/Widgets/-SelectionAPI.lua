--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--
--  file:    unit_smart_nanos.lua
--  brief:   Enables auto reclaim & repair for idle turrets
--  author:  Owen Martindell
--
--  Copyright (C) 2008.
--  Licensed under the terms of the GNU GPL, v2 or later.
--
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function widget:GetInfo()
  return {
    name      = "Selection API",
    desc      = "set of tools to get info about selection",
    author    = "Helwor",
    date      = "Sept 2023",
    license   = "GNU GPL, v2 or later",
    layer     = -1000000, -- before Draw Placement and Persistent Build Height 2 so they can override this widget orders
    enabled   = true,  --  loaded by default?
    handler   = true,
    api       = true,
    alwaysStart = true,
  }
end
local Echo = Spring.Echo
local f = VFS.Include("LuaUI\\Widgets\\UtilsFunc.lua")
include("LuaRules/Configs/customcmds.h.lua")
-- speedups
local spGetModKeyState          = Spring.GetModKeyState
local spGetKeyState             = Spring.GetKeyState

local spGetCameraState          = Spring.GetCameraState
local spSetCameraState          = Spring.SetCameraState
local spGetCameraPosition       = Spring.GetCameraPosition
local spSetCameraTarget         = Spring.SetCameraTarget
local spTraceScreenRay          = Spring.TraceScreenRay
local spSetActiveCommand        = Spring.SetActiveCommand
local spSendCommands            = Spring.SendCommands
local spGetActiveCommand        = Spring.GetActiveCommand

local spGetMouseState           = Spring.GetMouseState
local spSetMouseCursor          = Spring.SetMouseCursor
local spWarpMouse               = Spring.WarpMouse


local spFindUnitCmdDesc         = Spring.FindUnitCmdDesc
local spGetCmdDescIndex         = Spring.GetCmdDescIndex
local spGetSelectedUnitsSorted  = Spring.GetSelectedUnitsSorted
local spGetUnitIsTransporting   = Spring.GetUnitIsTransporting
local spGetUnitDefID            = Spring.GetUnitDefID
local CMD_UNLOAD_UNITS = CMD.UNLOAD_UNITS
local CMD_LOAD_UNITS = CMD.LOAD_UNITS
-- f.DebugWidget(widget)
local alt
local EMPTY_TABLE = {}
local BASE_SELINFO_KEYS = {

}
local wh
WG.commandMap           = WG.commandMap or {}
WG.selectionMap         = WG.selectionMap or {}
WG.selectionDefID       = WG.selectionDefID or {}
WG.selection            = WG.selection or {}
WG.mySelection          = WG.mySelection or {}
WG.transportedUnit      = WG.transportedUnit or {}

local currentCommands   = {}
local commandMap        = WG.commandMap
local selection         = WG.selection
local selectionMap      = WG.selectionMap
local selectionDefID    = WG.selectionDefID
local mySelection       = WG.mySelection
local transportedUnits  = WG.transportedUnits or {}
-- function widget:DefaultCommand(_,_,defaultCmd)
--     if defaultCmd == CMD_LOAD_UNITS then
--         if not alt then
--             return CMD_RAW_MOVE
--         end
--     end
-- end
local function clear(t)
    for k in pairs(t) do
        t[k] = nil
    end
end

local transportDefID = UnitDefNames['gunshiptrans'].id
local heavyTransportDefID = UnitDefNames['gunshipheavytrans'].id


local function UpdateTransport()

    local hasTransport, isTransporting, canLoadLight, canLoadHeavy = false, false,false
    if commandMap['Unload units'] then
        local light = selectionDefID[transportDefID]

        if light then
            hasTransport = true
            for i, id in ipairs(light) do
                local tid = spGetUnitIsTransporting(id)[1]
                if tid then
                    isTransporting = true
                    -- if canLoadLight then
                    --     break
                    -- end
                else
                    canLoadLight = true
                end
            end
        end
        local heavy = selectionDefID[heavyTransportDefID]
        if heavy then
            hasTransport = true
            for i, id in ipairs(heavy) do
                local tid = spGetUnitIsTransporting(id)[1]
                if tid then
                    isTransporting = true
                    -- if canLoadHeavy then
                    --     break
                    -- end
                else
                    canLoadHeavy = true
                end
            end
        end
    end
    mySelection.hasTransport = hasTransport
    mySelection.isTransporting = isTransporting
    mySelection.canLoadLight = canLoadLight
    mySelection.canLoadHeavy = canLoadHeavy
end


local function RemapCommands()
    currentCommands = wh.commands
    clear(commandMap)
    for i, command in pairs(wh.commands) do
        if i~='n' then

            -- if command.name == 'Unload units' then -- note : some different got same name, but different id, ex: LOAD_ONTO and LOAD_UNITS have the same name 'Load units'
            --     for k,v in pairs(command) do
            --         Echo(k,v)
            --     end
            --     Echo('params?',table.size(command.params))
            --     for k,v in pairs(command.params) do
            --         Echo('params',k,v)
            --     end
            -- end
            command.pos = i
            commandMap[command.name] = command
            commandMap[command.id] = command
        end
    end
    UpdateTransport()
end
-- function widget:Update()
--     Echo("next(transportedUnits) is ", next(transportedUnits))
-- end
function widget:Update()
    if currentCommands ~= wh.commands then
        currentCommands = wh.commands
        RemapCommands()
    end
end


function widget:CommandsChanged()
    -- for k,v in pairs(customCmds) do
    --     Echo(k,v)
    -- end
    clear(selectionMap)
    clear(selectionDefID)
    clear(selection)
    clear(mySelection)
    -- Echo('--')

    local totalCount = 0
    for defID, t in pairs(spGetSelectedUnitsSorted()) do
        local count = #t
        selectionDefID[defID] = t
        t.count = count
        for i, id in ipairs(t) do
            selectionMap[id] = defID
            selection[totalCount + i] = id
        end
        totalCount = totalCount + count
    end
    mySelection.count = totalCount
    RemapCommands()
    -- Get if Transporting
    --     local light = selectionDefID[]


end
function widget:UnitDestroyed(unitID)
    if transportedUnits[unitID] then
        UpdateTransport()
        transportedUnits[unitID] = nil
    end
end

function widget:UnitLoaded(unitID, unitDefID, unitTeam, transportID, transportTeam)
    if selectionMap[transportID] then
        -- RemapCommands()
        UpdateTransport()
        transportedUnits[unitID] = unitDefID
    end
end


function widget:UnitUnloaded(unitID, unitDefID, unitTeam, transportID, transportTeam)
    if selectionMap[transportID] then
        -- RemapCommands()
        UpdateTransport()
        transportedUnits[unitID] = nil
    end
end
function widget:Initialize()
    if Spring.GetSpectatingState() then
        widgetHandler:RemoveWidget(widget)
        return
    end
    wh = widgetHandler
    widget:CommandsChanged()
end