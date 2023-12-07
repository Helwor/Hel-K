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
local GetOptionsCode
do
    local code={meta=4,internal=8,right=16,shift=32,ctrl=64,alt=128}
    GetOptionsCode = function(options)
        local coded = 0
        for opt, isTrue in pairs(options) do
            if isTrue then 
                coded = coded + code[opt]
            end
        end
        options.coded = coded
        return coded
    end
end

function widget:CommandNotify(cmd,params,opts)
    if cmd == CMD_EXCLUDE_PAD then
        local selTypes = WG.selectionDefID or spGetSelectedUnitsSorted()
        for defID, units in pairs(selTypes) do
            if airUnitDefID[defID] then
                spGiveOrderToUnit(units[1],cmd,params,opts.coded or GetOptionsCode(opts))
                return true
            end
        end
    end
end
