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
    name      = "Fix Squad Wait",
    desc      = "Transform the Cmd Gather Wait into Squad Wait if factory is selected, \nAdd a shift order to the Squad Wait Command as it doesnt make sense to use it without shift.",
    author    = "Helwor",
    date      = "August 2023",
    license   = "GNU GPL, v2 or later",
    layer     = -1000000, 
    enabled   = true,  
    handler   = true,
  }
end
local Echo = Spring.Echo
local f = VFS.Include("LuaUI\\Widgets\\UtilsFunc.lua")
include("LuaRules/Configs/customcmds.h.lua")
-- speedups
local spGetSelectedUnits = Spring.GetSelectedUnits
local spGiveOrderToUnitArray = Spring.GiveOrderToUnitArray
local spGiveOrderToUnit = Spring.GiveOrderToUnit
local spGiveOrder = Spring.GiveOrder
local spGetSelectedUnitsSorted = Spring.GetSelectedUnitsSorted
local spSetActiveCommand = Spring.SetActiveCommand
-- f.DebugWidget(widget)

local CMD_SQUADWAIT = CMD.SQUADWAIT
local CMD_GATHERWAIT = CMD.GATHERWAIT

local GetOptionsCode
do
    local code={meta=4,internal=8,right=16,shift=32,ctrl=64,alt=128}
    GetOptionsCode = function(opts)
        local coded = 0
        for opt,num in pairs(code) do
            if opts[opt] then coded=coded+num end
        end

        return coded
    end
end

local factoryDefID = {}
for defID,def in pairs(UnitDefs) do
    if def.isFactory then
        factoryDefID[defID] = true
    end
end


-- NOTE:    'Gather wait' wait for the units to arrive at destination before processing the next order
--          'Squad wait (used mostly with factory) that will send unit to the next order until an amount of unit reach the current order'
function widget:CommandNotify(cmd,params, opts)
    -- transform the command gather wait into squad wait if we have factory selected, as gather wait is useless with factories
    if cmd == CMD_GATHERWAIT then  -- as the gather wait is instant, we transform this order into the squad wait active command
        local sel = WG.selectionDefID or spGetSelectedUnitsSorted()
        for defID in pairs(sel) do
            if factoryDefID[defID] then
                spSetActiveCommand('SquadWait')
                return true
            end
        end
    elseif cmd == CMD_SQUADWAIT then -- add a shift to the squad wait command if there's not, bc it is useless without it
        if not opts.shift then
            opts.shift = true
            spGiveOrder(cmd,params, opts )
            return true
        end
    end
end