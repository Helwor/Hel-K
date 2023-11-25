function widget:GetInfo()
    return {
        name      = "CacheGroundHeight", -- this is not giving best performance, the opposite actually
        desc      = "",
        author    = "Helwor",
        date      = "June 2023",
        license   = "GNU GPL, v2 or later",
        layer     = -10e38,
        enabled   = true,  --  loaded by default?
        api       = true,
    }
end
if true then
    return false
end
local Echo = Spring.Echo
local OriGetGroundHeight = Spring.GetGroundHeight
local currentFrame = Spring.GetGameFrame()

local cached, uncached = 0, 0

local ground = setmetatable(
    {},
    {
        __index = function(self,x)
            self[x] = setmetatable(
                {},
                {
                    __index = function(tx,z)
                        tx[z] = {
                            frame = currentFrame,
                            value = OriGetGroundHeight(x,z),
                            new = true,
                        }
                        return tx[z]
                    end
                }
            )
            return self[x]
        end
    }
)
function widget:GameFrame(f)
    if f%120 == 0 then
        Echo('used ' .. cached .. 'cached ' .. '/' .. uncached .. ' uncached values')
    end
    currentFrame = f
end
local floor = math.floor
function Spring.GetGroundHeight(x,z, threshold)
    local modx, modz = x%4, z%4
    if modx > 1 and modx < 3 or modz > 1 and modz < 3 then
        uncached = uncached + 1
        return OriGetGroundHeight(x,z)
    end

    if threshold then
        -- Echo(x,z,"modx, modz is ", modx, modz, floor(x/8 + 0.5) * 8, floor(z/8 + 0.5) * 8)
    end

    local fx, fz = floor(x/4 + 0.5) * 4, floor(z/4 + 0.5) * 4
    -- Echo(x,"=>",fx,'z',"=>",fz)
    local g = ground[fx][fz] -- we cache groundheight asked if they are close to multiple of 8 (a square size)
    if g.frame < currentFrame - (threshold or 30) then
        g.value = OriGetGroundHeight(x,z)
        g.frame = currentFrame
        uncached = uncached + 1
        g.new = false
    elseif g.new then
        uncached = uncached + 1
        g.new = false
    else
        cached = cached + 1
    end
    return g.value
end

