function widget:GetInfo()
  return {
    name      = "Phoenix Drop",
    desc      = "Simulates DGUN/Drop behaviour like it would with a Thunderbird \n (EXPERIMENTAL working using D key)",
    author    = "Helwor",
    date      = "May 2024",
    license   = "GNU GPL, v2 or later",
    layer     = -1, -- before Keep Attack
    enabled   = true,  --  loaded by default?
    handler   = true,
  }
end

-- speeds up
local Echo = Spring.Echo

local spGetUnitPosition = Spring.GetUnitPosition
local spGetGroundHeight = Spring.GetGroundHeight
local spGiveOrderToUnit = Spring.GiveOrderToUnit
local spGetUnitRulesParam = Spring.GetUnitRulesParam
local spGetSelectedUnitsSorted = Spring.GetSelectedUnitsSorted
local spGetUnitHeading = Spring.GetUnitHeading
local spGetUnitRulesParam = Spring.GetUnitRulesParam
local spGetUnitVelocity = Spring.GetUnitVelocity
-- local spValidUnitID = Spring.ValidUnitID
-- local spGetUnitIsDead = Spring.GetUnitIsDead
-- local spGetUnitWeaponState = Spring.GetUnitWeaponState
-- local spGetUnitIsStunned = Spring.GetUnitIsStunned

local CMD_INSERT, CMD_OPT_ALT, CMD_OPT_SHIFT, CMD_OPT_INTERNAL = CMD.INSERT, CMD.OPT_ALT, CMD.OPT_SHIFT, CMD.OPT_INTERNAL
local CMD_ATTACK, CMD_REMOVE = CMD.ATTACK, CMD.REMOVE


local EMPTY_TABLE = {}

include('keysym.h.lua')
local DROP_KEY = KEYSYMS.D
KEYSYMS = nil

-------------
local dev = false
local f, Debug
if dev then
    f =  VFS.Include('LuaUI\\Widgets\\UtilsFunc.lua')
    option_path = 'Hel-K/'  .. widget:GetInfo().name
    Debug = { -- default values
    active = false, -- no debug, no hotkey active without this
    global = false, -- global is for no key : 'Debug(str)'

    }
end
-------------


local phoenixDefID = UnitDefNames['bomberriot'].id
local selectedPhoenixes = false

-- CONFIG -- 
-- local PING_LEEWAY = 0.02
local opt = {
    removeAnyAttack = true
}
--


local function IsReloaded(id)
    local noammo = spGetUnitRulesParam(id,'noammo')
    return noammo == 0 or noammo == nil
end

local function GetClosestDropLocation(id)
    local bx ,by ,bz = spGetUnitPosition(id)
    if not bx then
        return
    end
    local vx, vy, vz, v = spGetUnitVelocity(id)
    if not vx then
        return
    end
    -- if vx < 5 and vz < 5 then -- in case the unit is temporarily slowed down and stunned
    --     vx, vz = vx * 2, vz * 2
    -- end 
    local gx, gz = bx + vx * 20, bz + vz * 20
    local gy = spGetGroundHeight(gx, gz)
    return gx, gy, gz
end

local function InsertAttackGround(id, x,y,z)
    spGiveOrderToUnit(id, CMD_INSERT,{0, CMD_ATTACK, 0, x,y,z}, CMD_OPT_ALT)
end

local function RemoveAnyAttack(id)
    spGiveOrderToUnit(id, CMD_REMOVE, CMD_ATTACK, CMD_OPT_ALT)
end

local Process = function()
    if not selectedPhoenixes then
        return
    end
    for i = 1, #selectedPhoenixes do
        local id = selectedPhoenixes[i]
        if IsReloaded(id) 
            -- and not spGetUnitRulesParam(id,'att_abilityDisabled')==1
        then
            if opt.removeAnyAttack then
                RemoveAnyAttack(id)
            end
            local x, y, z = GetClosestDropLocation(id)
            if not x then
                return
            end
            InsertAttackGround(id, x, y, z)
        end
    end
end

function widget:KeyPress(key,m, isRepeat) -- note: mods always appear in the order alt,ctrl,shift,meta when iterated  -- we can simulate the same by traversing the table {alt=true,ctrl=true,meta=true,shift=true}
    if isRepeat then
        return
    end
    if key == DROP_KEY then
        Process()
    end
end

function widget:CommandsChanged() 
    selectedPhoenixes = (WG.selectionDefID or spGetSelectedUnitsSorted() or EMPTY_TABLE)[phoenixDefID]
end




function widget:Initialize()
    if Spring.GetSpectatingState() then
        widgetHandler:RemoveWidget(self)
        return
    end
    Debug = dev and f.CreateDebug(Debug,widget,options_path)
    widget:CommandsChanged()
end


function widget:SetConfigData(data)
    if dev and data.Debug then
        Debug.saved = data.Debug
    end
end

function widget:GetConfigData()
    if dev and Debug.GetSetting then
        return {Debug=Debug.GetSetting()}
    end
end
function widget:Shutdown()
    if dev and Debug.Shutdown then
        Debug.Shutdown()
    end
end

if dev then
    f.DebugWidget(widget)
end
