--glAddons
VFS.Include("LuaRules/Utilities/glVolumes.lua")
if (not gl) then
    return
end
if gl.Utilities.DrawDisc then
    return
end
local Echo = Spring.Echo
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- CONSTANTS

GL.COLOR_MATERIAL            = 0x0B57 -- use gl.Enable(GL.COLOR_MATERIAL) so set gl.Material ambient and diffusion through gl.Color
GL.COLOR_MATERIAL_FACE       = 0x0B55
GL.COLOR_MATERIAL_PARAMETER  = 0x0B56

GL.CURRENT_COLOR = 2816 --0xb00 use gl.GetNumber(GL.CURRENT_COLOR, 4)




local samplePassedConsts = {
    SAMPLES_PASSED                  = 35092,    -- 0x8914
    ANY_SAMPLES_PASSED              = 35887,    -- 0x8c2f
    ANY_SAMPLES_PASSED_CONSERVATIVE = 36202,    -- 0x8d6a
}
for k,v in pairs(samplePassedConsts) do
    GL[k] = v
end
local stencilResConsts = {
    STENCIL_PASS_DEPTH_FAIL         = 2965,     -- 0xb95
    STENCIL_PASS_DEPTH_PASS         = 2966,     -- 0xb96
    STENCIL_FAIL                    = 2964,     -- 0xb94
    STENCIL_BACK_FAIL               = 34817,    -- 0x8801
    STENCIL_BACK_PASS_DEPTH_FAIL    = 34818,    -- 0x8802
    STENCIL_BACK_PASS_DEPTH_PASS    = 34819,    -- 0x8803
    STENCIL_BITS                    = 3415,     -- 0xd57
}
for k,v in pairs(stencilResConsts) do
    GL[k] = v
end

local stencilOpConsts = {
    KEEP      = 0x1E00,
    INCR_WRAP = 0x8507,
    DECR_WRAP = 0x8508,
}

for k,v in pairs(stencilOpConsts) do
    GL[k] = v
end

local blendConsts = {
    BLEND_COLOR             = 32773,            -- 0x8005
    BLEND_DST               = 3040,             -- 0xbe0
    BLEND_DST_ALPHA         = 32970,            -- 0x80ca
    BLEND_DST_RGB           = 32968,            -- 0x80c8
    BLEND_EQUATION          = 32777,            -- 0x8009
    BLEND_EQUATION_ALPHA    = 34877,            -- 0x883d
    BLEND_EQUATION_RGB      = 32777,            -- 0x8009
    BLEND_SRC               = 3041,             -- 0xbe1
    BLEND_SRC_ALPHA         = 32971,            -- 0x80cb
    BLEND_SRC_RGB           = 32969,            -- 0x80c9
}
for k,v in pairs(blendConsts) do
    GL[k] = v
end
local texFormats = {
    RGBA                    = 0x1908,
    RGBA16F_ARB             = 0x881A,
    RGBA32F_ARB             = 0x8814,
    RGBA12                  = 0x805A,
    RGBA16                  = 0x805B,
    DEPTH_COMPONENT32       = 0x81A7,
    DEPTH24_STENCIL8        = 0x88F0 -- rbo depth/stencil  format
}
for k,v in pairs(texFormats) do
    GL[k] = v
end

-------------------------------------------------------
-- gl.Enable / gl.Disable

do -- hax using gl.UnsafeState to enable/disable a state, normally gl.UnsafeState is used to enable and disable (or in reverse) while calling a given function in the same go
    local dumfunc = function() end
    local glUnsafeState = gl.UnsafeState
    gl.Enable = function(state)
        glUnsafeState(state, true, dumfunc)
    end
    gl.Disable = function(state)
        glUnsafeState(state, true, dumfunc)
    end
end

-------------------------------------------------------
-- circles and discs
do
    local glDrawGroundCircle        = gl.DrawGroundCircle -- this one is making hollow circle following ground
    local gluDrawGroundCircle       = gl.Utilities.DrawGroundCircle -- this one is making plain circle following ground
    local glPushMatrix              = gl.PushMatrix
    local glTranslate               = gl.Translate
    local glBillboard               = gl.Billboard
    local glColor                   = gl.Color
    local glText                    = gl.Text
    local glPopMatrix               = gl.PopMatrix
    local gluDrawGroundRectangle    = gl.Utilities.DrawGroundRectangle
    local glPointSize               = gl.PointSize
    local glNormal                  = gl.Normal
    local glVertex                  = gl.Vertex
    local GL_POINTS                 = GL.POINTS
    local glBeginEnd                = gl.BeginEnd
    local glLineStipple             = gl.LineStipple
    local glLineWidth               = gl.LineWidth
    local glCallList                = gl.CallList
    local glScale                   = gl.Scale

    local spWorldToScreenCoords = Spring.WorldToScreenCoords


    local CreateCircle = function(divs,plain, screen)
        local draw = function()
            gl.BeginEnd(plain and GL.TRIANGLE_FAN or GL.LINE_LOOP, function() 
                for i = 0, divs - 1 do
                    local r = 2.0 * math.pi * (i / divs)
                    local cosv = math.cos(r)
                    local sinv = math.sin(r)
                    -- gl.TexCoord(cosv, sinv)
                    gl.Vertex(cosv, screen and sinv or 0, screen and 0 or sinv)
                end
            end)
        end
        return gl.CreateList(draw)
    end
    local disc = CreateCircle(40,true)
    local circle = CreateCircle(40,false)
    local screen_disc = CreateCircle(40,true, true)
    local screen_circle = CreateCircle(40,false, true)

    local cheap_disc = CreateCircle(20,true)
    local cheap_circle = CreateCircle(20,false)
    local cheap_screen_disc = CreateCircle(20,true, true)
    local cheap_screen_circle = CreateCircle(20,false, true)



    function gl.Utilities.DrawScreenCircle(x,y,r)
        glPushMatrix()
        glTranslate(x, y, 0)
        -- glBillboard()
        glScale(r, r, y)
        glCallList(r < 30 and cheap_screen_circle or screen_circle)
        glPopMatrix()
    end
    function gl.Utilities.DrawScreenDisc(x,y,r)
        glPushMatrix()
        glTranslate(x, y, 0)
        -- glBillboard()
        glScale(r, r, y)
        glCallList(r < 30 and cheap_screen_disc or screen_disc)
        glPopMatrix()
    end
    function gl.Utilities.DrawGroundDisc(x,z,r)
        return gluDrawGroundCircle(x,z,r)
    end
    function gl.Utilities.DrawDisc(x,y,z,r)
        glPushMatrix()
        glTranslate(x, y, z)
        glScale(r, y, r)
        glCallList(r < 50 and cheap_disc or disc)
        glPopMatrix()
    end
    function gl.Utilities.DrawGroundHollowCircle(x,z,r) 
        return glDrawGroundCircle(x,0,z,r,30)
    end
    function gl.Utilities.DrawFlatCircle(x,y,z,r)
        glPushMatrix()
        glTranslate(x, y, z)
        glScale(r, y, r)
        glCallList(r < 50 and cheap_circle or circle)
        glPopMatrix()
    end
end


--------------------------------------------------
-- some gl gets and debugging

local oriGlGetFixedState = gl.GetFixedState
function gl.GetFixedState(arg,toString)
    local argStr = tostring(arg):lower()
    local targ
    if argStr == 'stencilop' then
        targ = stencilOpConsts
    elseif argStr == 'samplepassed' then
        targ = samplePassedConsts
    end
    if targ then
        local t = {}
        if toString then
            for k,v in pairs(targ) do
                table.insert(t, gl.GetNumber(v))
            end
            return table.concat(t,', ')
        else
            for k,v in pairs(targ) do
                local s = gl.GetNumber(v)
                t['GL_'..k] = s
            end
            return t
        end
    end
    return oriGlGetFixedState(arg,toString)
end

local GLConstByValue = function(value)
    if type(value) == 'table' then
        if table.tostring then
            return table.tostring(value)
        else
            return tostring(value)
        end
    end

    local str = ''
    for k,v in pairs(GL) do
        if v == value then
            str = str .. k .. ' / '
        end
    end
    return str:sub(1,-3)
end

function gl.ReadFixedState(state)
    local a,b,c,d = gl.GetFixedState(state)
    Echo('--------',state,'is',a==nil and '' or a,b==nil and '' or b,c==nil and '' or c,d==nil and '' or d)
    if a or b or c or d then
        local t = type(a) == 'table' and a
            or type(b) == 'table' and b
            or type(c) == 'table' and c
            or type(d) == 'table' and d
        if t then
            for k,v in pairs(t) do
                Echo(k,v,GLConstByValue(v))
            end
        end
    end
end

function gl.GetBlendState(echo)
    local ret = {}
    for k,v in pairs(blendConsts) do
        ret[k] = gl.GetNumber(v)
    end
    if echo then
        for k,v in pairs(ret) do
            Echo(k,GLConstByValue(v))
        end
    end
    return ret
end

--// =============================================================================

