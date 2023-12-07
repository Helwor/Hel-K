function widget:GetInfo()
  return {
    name      = "FixExcludePad",
    desc      = "This work around fix the Exclude Pad command negating itself due to the repetition per unit selected",
    author    = "Helwor",
    date      = "Dec 2023",
    license   = "free",
    layer     = 1, 
    enabled   = true,  --  loaded by default?
    handler   = true,
  }
end
local Echo = Spring.Echo
local spGetSelectedUnits = Spring.GetSelectedUnits
local spGiveOrderToUnit = Spring.GiveOrderToUnit
local spGetSelectedUnitsSorted = Spring.GetSelectedUnitsSorted
local airUnitDefID = {}
for defID, def in pairs(UnitDefs) do
    if def.canFly then
        airUnitDefID[defID] = true
    end
end
local CMD_EXCLUDE_PAD
do
    local customCmds = VFS.Include("LuaRules/Configs/customcmds.lua")
    CMD_EXCLUDE_PAD = customCmds.EXCLUDE_PAD
end

function widget:CommandNotify(cmd,params,opts)
    if cmd == CMD_EXCLUDE_PAD then
        local selTypes = WG.selectionMap or spGetSelectedUnitsSorted()
        for defID, t in pairs(selTypes) do
            if airUnitDefID[defID] then
                spGiveOrderToUnit(t[1],cmd,params,opts)
                return true
            end
        end
    end
end
