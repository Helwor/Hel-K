function widget:GetInfo()
    return {
        name      = "VolumeAddon",
        desc      = "",
        author    = "Helwor",
        version   = "v1",
        date      = "June 2024",
        license   = "GNU GPL, v2 or later",
        layer     = -10001, 
        enabled   = true,
        handler   = true,
    }
end
local Echo = Spring.Echo
local lists, shaders = {}, {}
local glUseShader, glUniform
local CreateCircle = function(divs,plain)
    local list = function()
        gl.BeginEnd(plain and GL.TRIANGLE_FAN or GL.LINE_LOOP, function() 
            for i = 0, divs - 1 do
                local r = 2.0 * math.pi * (i / divs)
                local cosv = math.cos(r)
                local sinv = math.sin(r)
                gl.TexCoord(cosv, sinv)
                gl.Vertex(cosv, 0, sinv)
            end
        end)
    end
    return gl.CreateList(list)
end
local plainCircle = CreateCircle(40,true)
local hollowCircle = CreateCircle(40,true)
lists.plainCircle = plainCircle
lists.hollowCircle = hollowCircle






-- local i, name, value = 0, true
-- local cylinder, averageGroundHeight, shapeHeight
-- while name do
--     i = i + 1
--     name, value = debug.getupvalue(gl.Utilities.DrawGroundCircle,i)
--     if name == 'cylinder' then
--         cylinder = value
--     elseif name == 'averageGroundHeight' then
--         averageGroundHeight = value
--     elseif name == 'shapeHeight' then
--         shapeHeight = value
--     end
-- end
-- Echo("shapeHeight is ", shapeHeight,'averageGroundHeight is',averageGroundHeight)



function gl.Utilities.DrawFlatHollowCircle(x,y,z,r)
    if not hollowCircle then
        hollowCircle = CreateCircle(40,false)
    end
    gl.PushMatrix()
    gl.Translate(x, y, z)
    gl.Scale(r, y, r)
    gl.CallList(hollowCircle)
    gl.PopMatrix()
end
function gl.Utilities.DrawFlatPlainCircle(x,y,z,r)
    if not plainCircle then
        plainCircle = CreateCircle(40,true)
    end
    gl.PushMatrix()
    gl.Translate(x, y, z)
    gl.Scale(r, y, r)
    gl.Utilities.DrawMergedVolume(plainCircle)
    gl.PopMatrix()
end
function gl.Utilities.DrawMergedFlat(dlist)
    gl.DepthMask(false)
    -- gl.Culling(false)
    gl.StencilTest(true)
    gl.DepthTest(GL.NEVER)
    gl.ColorMask(false, false, false, false)
    gl.StencilOp(GL.KEEP, GL.INVERT, GL.KEEP)

    gl.StencilMask(1)
    gl.StencilFunc(GL.ALWAYS, 0, 1)


    gl.CallList(dlist)

    gl.DepthTest(false)
    gl.ColorMask(true, true, true, true)
    gl.StencilOp(GL.KEEP, GL.INCR, GL.INCR)
    gl.StencilMask(3)
    gl.StencilFunc(GL.EQUAL, 1, 3)

    gl.CallList(dlist)
    gl.StencilTest(false)
end


-------------------------------------------------------------
local DrawSphere, sphereMat
local TRY_BUBBLES = false
local ROTATE = true
local PULSE = true
local COLORED = true
local BUBBLE_JUNCTION = 1
local DRAW_ON_BUBBLE = true
local INVERT_DRAWING = true
local sphereCol = {0,0.2,0.3}

options = {}
options_path = 'Hel-K/' .. widget:GetInfo().name
options_order = {'try_bubbles','draw_on_bubble','invert_draw','rotate'} -- the rest of options are inserted after declaration
options.try_bubbles = {
    name ='Try Bubbles',
    type = 'bool',
    desc = 'Select some units and move them around to see the result',
    value = TRY_BUBBLES,
    OnChange = function(self)
        TRY_BUBBLES = self.value
        if not TRY_BUBBLES then
            if options.hide_units.value then
                options.hide_units.value = false
                options.hide_units:OnChange()
            end
        end
    end,
}
options.draw_on_bubble = {
    name = 'Drawings on bubble',
    type = 'bool',
    value = DRAW_ON_BUBBLE,
    OnChange = function(self)
        DRAW_ON_BUBBLE = self.value
    end,
    children = {'invert_draw','rotate'},
}
options.invert_draw = {
    name = 'Invert Drawings',
    type = 'bool',
    value = INVERT_DRAWING,
    OnChange = function(self)
        INVERT_DRAWING = self.value
    end,
    parents = {'draw_on_bubble'},
}
options.rotate = {
    name = 'Rotate',
    type = 'bool',
    value = ROTATE,
    OnChange = function(self)
        ROTATE = self.value
    end,
    parents = {'draw_on_bubble'},
}
options.colored = {
    name = 'Colored',
    type = 'bool',
    value = COLORED,
    OnChange = function(self)
        COLORED = self.value
    end,
}
options.pulse = {
    name = 'Pulse',
    type = 'bool',
    value = PULSE,
    OnChange = function(self)
        PULSE = self.value
    end,
}

options.bubble_junction = {
    name ='Bubble Junction',
    type ='number',
    min = 0.1, max = 10, step = 0.1,
    value = BUBBLE_JUNCTION,
    update_on_the_fly = true,
    OnChange = function(self)
        BUBBLE_JUNCTION = self.value
    end,
}
options.hide_units = {
    name ='Hide Units',
    type ='bool',
    value = false,
    OnChange = function(self)
        for _,id in pairs(Spring.GetAllUnits()) do
            Spring.SetUnitNoDraw(id,self.value)
        end
    end,
}

local main_children = {} 
for k,v in pairs(options) do
    if k~='try_bubbles' then
        if k~='rotate' and k~='invert_draw' then
            if v.parents then
                table.insert(v.parents, 'try_bubbles')
            else
                v.parents = {'try_bubbles'}
            end
            if k ~= 'draw_on_bubble' then
            end

        end
        if k ~= 'draw_on_bubble' then
            table.insert(options_order,k)
        end
        table.insert(main_children, k)
    end
end
options.try_bubbles.children = main_children

-----------------------------

do
    -- copied and customized from unit_cloak_shield
    local sphereDivs = 16
    local sphereArcs = 32
    local trans = {0.1, 0.28, 0.60 } -- step of transparency 
    local color = {0,0.25,0}
    local PI = math.pi
    local twoPI = (2.0 * PI)
    local cos = math.cos
    local sin = math.sin
    local max, min = math.max, math.min
    local gl = gl
    local function SphereVertex(x, y, z, neg)
        if neg then
            gl.Normal(-x, -y, -z)
        else
            gl.Normal(x, y, z)
        end
        gl.Vertex(x, y, z)
    end
    sphereMat = {
        -- ambient  = {0,0,0}, 
        diffuse  = { 0, 0, 0, 0.7},
        emission = { 0.05, 0.10, 0.15 },
        specular = { 0.25, 0.75, 1 },
        shininess = 4

    }



    lists.backMat    = gl.CreateList(function()
        gl.Material({
            ambient  = { 0, 0, 0 },
            diffuse  = { 0, 0, 0, 0.5 },
            emission = { 0.05, 0.10, 0.15 },
            specular = { 0.25, 0.75, 1.0 },
            shininess = 4
        })
    end)
    lists.frontMat    = gl.CreateList(function()
        gl.Material({
            ambient  = { 0, 0, 0 },
            diffuse  = { 0, 0, 0, 0.75 },
            emission = { 0.05, 0.10, 0.15 },
            specular = { 0.25, 0.75, 1.0 },
            shininess = 4
        })
    end)

    local function CloakSphere(divs, arcs, neg)
        local divRads = PI / divs
        local minRad = sin(divRads)
        local oriDiffuse = sphereMat.diffuse[4]
        -- sides
        for d = 4, (divs - 2) do -- 
            if (d < 7) then
                sphereMat.diffuse[4] = trans[d-3]
                gl.Material(sphereMat)
            elseif (d > 10) then
                sphereMat.diffuse[4] = trans[15-d]
                gl.Material(sphereMat)
            elseif d == 7 then
                sphereMat.diffuse[4] = 1
                gl.Material(sphereMat)
            end
        
            gl.BeginEnd(GL.QUAD_STRIP, function()
                local topRads = divRads * (d + 0)
                local botRads = divRads * (d + 1)
                local top = cos(topRads)
                local bot = cos(botRads)
                local topRad = sin(topRads)
                local botRad = sin(botRads)
            
                for i = 0, arcs do
                    local a = i * twoPI / arcs
                    SphereVertex(sin(a) * topRad, top, cos(a) * topRad, neg)
                    SphereVertex(sin(a) * botRad, bot, cos(a) * botRad, neg)
                end
            end)
        end
        
        -- bottom -- is not seen
        -- gl.BeginEnd(GL.TRIANGLE_FAN, function()
        --     SphereVertex(0, -1, 0, neg)
        --     for i = 0, arcs do
        --         local a = -i * twoPI / arcs
        --         SphereVertex(sin(a) * minRad, -cos(divRads), cos(a) * minRad, neg)
        --     end
        -- end)
        sphereMat.diffuse[4] = oriDiffuse
    end


    
    lists.setupSphereDraw = gl.CreateList(function()
        -- gl.Color(0.1, 0.2, 0.3, 0.3)
        gl.Blending(GL.SRC_ALPHA, GL.ONE)
        gl.DepthTest(GL.LESS)
        gl.Lighting(true)
        gl.ShadeModel(GL.FLAT)
        -- gl.Fog(false)
        -- gl.ClipPlane(1, 0, 1, 0, 0) -- invisible in water
        gl.Material({
            -- ambient  = {0.2,0.2,0.2}, 
            diffuse  = { 0, 0, 0, 0.3},
            emission = { 0.15, 0.15, 0.15 },
            specular = { 0, 0, 0 },
            shininess = 20,
        })



    end)

    lists.resetSphereDraw = gl.CreateList(function()
        gl.ShadeModel(GL.SMOOTH)
        gl.Lighting(false)
        gl.DepthTest(false)
        gl.Blending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA)
        gl.Fog(true)
        -- gl.ClipPlane(1, false) -- invisible in water
        gl.Color(1,1,1,1)
        gl.Material({
            ambient  = { 0, 0, 0 },
            diffuse  = { 0, 0, 0, 0 },
            emission = { 0, 0, 0 },
            specular = { 0, 0, 0 },
            shininess = 0
        })
    end
    )


    ---------------------------------------------------




    local function Sphere(divs, arcs, neg)

        local divRads = PI / divs
        local minRad = sin(divRads)
        -- sides
        for d = 0, divs - 2 do -- 
            gl.BeginEnd(GL.QUAD_STRIP, function()
                local topRads = divRads * (d + 0)
                local botRads = divRads * (d + 1)
                local top = cos(topRads)
                local bot = cos(botRads)
                local topRad = sin(topRads)
                local botRad = sin(botRads)
            
                for i = 0, arcs do
                    local a = i * twoPI / arcs
                    SphereVertex(sin(a) * topRad, top, cos(a) * topRad, neg)
                    SphereVertex(sin(a) * botRad, bot, cos(a) * botRad, neg)
                end
            end)
        end
        -- bottom -- is not seen
        gl.BeginEnd(GL.TRIANGLE_FAN, function()
            SphereVertex(0, -1, 0, neg)
            for i = 0, arcs do
                local a = -i * twoPI / arcs
                SphereVertex(sin(a) * minRad, -cos(divRads), cos(a) * minRad, neg)
            end
        end)
    end


    ------------------------------------------
    local unif = {1,1,1}

    if gl.CreateShader then
           shaders.test= gl.CreateShader(
            {
                 fragment = [[
                    uniform vec3 unif;
                    void main()
                    {
                        gl_FragData[0].rgb =  gl_Color.rgb * unif * vec3(0.5,0.5,0.5);
                        gl_FragData[0].a = 1;
                    }
                ]],
                uniformFloat = { -- specify uniform floats here
                    unif = unif,
                    -- myFloat4 = {0, 1, 2, 3},
                },
            }
        )
    end
    if not shaders.test then
        glUseShader = function() end
        glUniform = function() end
        Echo('SHADER CREATION FAILED')
    else
        unifLoc = gl.GetUniformLocation(shaders.test, 'unif')
        glUseShader = gl.UseShader
        glUniform = gl.Uniform
    end
    local myBackMat  = {
        diffuse  = { 0, 0, 0, 0.1},
        emission = { 0.1, 0.1, 0.2 },
        specular = { 1, 0.75, 1 },
        shininess = 5,
    }
    local myFrontMat = {
        diffuse  = { 0, 0, 0, 0.5},
        emission = { 0.15, 0.15, 0.15 },
        specular = { 0, 0, 0 },
        shininess = 20,
    }

    local mySphereDivs = 22
    local mySphereArcs = 32

    local function MySphere(divs, arcs, neg,inv)
        local divRads = PI / divs
        local minRad = sin(divRads)
        local myMat = neg and myBackMat or myFrontMat
        gl.Material(myMat)
        local diffuse = myMat.diffuse
        local matDiffuse = {diffuse = diffuse}
        local maxOpacity = diffuse[4]
        local abs = math.abs
        -- sides
        local mid = (divs ) / 2
        -- local middleLane -- not done
        -- if math.min(mid%3,(mid+1)%3) == mid%3 then
        --     middleLane = mid
        -- else
        --     middleLane = mid+1
        -- end
        local count = 0
        local function DivVerts(topRads,botRads)
            local top = cos(topRads)
            local bot = cos(botRads)
            local topRad = sin(topRads)
            local botRad = sin(botRads)
        
            for i = 0, arcs do
                local a = i * twoPI / arcs
                SphereVertex(sin(a) * topRad, top, cos(a) * topRad, neg)
                SphereVertex(sin(a) * botRad, bot, cos(a) * botRad, neg)
            end
        end

        local bands, b = {}, 0
        local current = 0
        for d = 0, divs do
            local s = d<mid and -1 or 1
            local delta = s*(d - mid) / mid -- from 0 to 1, how far are we from the middle

            -- Echo("d,delta is ", d,delta)
            local incr = (1-delta) -- increment in percent
              -- reduce step at top and bottom, augment it toward the mid
            -- local size = 
            local alpha = maxOpacity * delta-- less opaque when being close of the middle lane
            local size = 1 + incr
            if not DBG then
                Echo("d is ", d,'s',s,'current',current,'delta', delta,'incr',incr,'size',size)
            end
            b=b+1
            bands[b] = {
                alpha = alpha,
                size = size,
                current = current,
                alpha = alpha,
            }
            current = current + size
        end

        for i = inv and 2 or 1, b - 1, 2  do
            local div = bands[i]
            diffuse[4] = div.alpha
            gl.Material(matDiffuse)
            if not DBG then
                Echo('making band from index',i,'start',div.current,'size',div.size,'instead of',i,i+1)
            end
            gl.BeginEnd(GL.QUAD_STRIP, DivVerts, divRads*i, divRads*(i+1))
            -- gl.BeginEnd(GL.QUAD_STRIP, DivVerts, divRads*div.current, divRads*div.current+div.size)
        end
        DBG = true
        -- local rads, r = {}, 0
        -- for d = 0, (divs -1) do -- 
        --     if d%1 == 0 then -- zebra
        --         local s = d<mid and -1 or 1
        --         local delta = s*(d - mid) / mid -- from 0 to 1, how far are we from the middle
        --         -- Echo("d,delta is ", d,delta)
        --         d = d + 2*(1-delta)*s
        --         -- diffuse[4] = maxOpacity *(1-delta)^1.1 -- more transparent while leaving the middle lane
        --         local alpha = maxOpacity * delta^1.1-- more opaque while leaving the middle lane

        --         if alpha > 0.005 then
        --             r=r+1
        --             rads[r] = {
        --                 top = divRads * max(d + 1*delta*s, 0), -- widen when leaving the mid (d+0) -- TODO: this only works well for d%3
        --                 bot = divRads * min(divs, d - 1.900*(delta*s)), -- widen when leaving the mid -- (d+1)
        --                 alpha = alpha,
        --             }
        --         end
        --     end
        -- end
        -- for i=1, r do
        --     local div = rads[i]
        --     local top, bot
        --     if inv then
        --         if rads[i+1] then
        --             top = div.bot
        --             bot = rads[i+1].top
        --         end
        --     else
        --         top,bot = div.top, div.bot
        --     end
        --     if top then
        --         diffuse[4] = div.alpha
        --         gl.Material(matDiffuse)
        --         gl.BeginEnd(GL.QUAD_STRIP, DivVerts, top, bot)
        --     end

        -- end
       
        -- bottom -- is not seen
        -- gl.BeginEnd(GL.TRIANGLE_FAN, function()
        --     SphereVertex(0, -1, 0, neg)
        --     for i = 0, arcs do
        --         local a = -i * twoPI / arcs
        --         SphereVertex(sin(a) * minRad, -cos(divRads), cos(a) * minRad, neg)
        --     end
        -- end)
        -- myMat.diffuse[4] = 0.22
        -- gl.Material(myMat)
        diffuse[4] = maxOpacity
    end

    lists.cloakSphere    = gl.CreateList(CloakSphere, sphereDivs, sphereArcs, false)
    lists.cloakSphereNeg = gl.CreateList(CloakSphere, sphereDivs, sphereArcs, true)
    lists.simpleSphere   = gl.CreateList(Sphere, sphereDivs, sphereArcs, false)
    lists.simpleSphereNeg= gl.CreateList(Sphere, sphereDivs, sphereArcs, true)
    lists.mySphere       = gl.CreateList(MySphere, mySphereDivs, mySphereArcs, false)
    lists.mySphereNeg    = gl.CreateList(MySphere, mySphereDivs, mySphereArcs, true)
    lists.mySphereInv       = gl.CreateList(MySphere, mySphereDivs, mySphereArcs, false, true)
    lists.mySphereInvNeg    = gl.CreateList(MySphere, mySphereDivs, mySphereArcs, true, true)
    lists.myWholeSphere  = gl.CreateList(function()-- doesnt look any different
        gl.Culling(GL.FRONT)
        gl.CallList(lists.mySphereNeg)

        gl.Culling(GL.BACK)
        gl.CallList(lists.mySphere)

        gl.Culling(false)
    end)
    lists.myWholeSphereInv  = gl.CreateList(function()-- doesnt look any different
        gl.Culling(GL.FRONT)
        gl.CallList(lists.mySphereInvNeg)

        gl.Culling(GL.BACK)
        gl.CallList(lists.mySphereInv)

        gl.Culling(false)
    end)
    lists.cloakShield    = gl.CreateList(function()-- doesnt look any different
        gl.Culling(GL.FRONT)
        gl.CallList(lists.backMat)
        gl.CallList(lists.cloakSphereNeg)

        gl.Culling(GL.BACK)
        gl.CallList(lists.frontMat)
        gl.CallList(lists.cloakSphere)

        gl.Culling(false)
    end)

    ---------------------------------------------------
    local spGetUnitViewPosition = Spring.GetUnitViewPosition
    local glScale = gl.Scale
    local glRotate = gl.Rotate

    local function UnitInView(unitID, radius)
        local x, y, z = Spring.GetUnitViewPosition(unitID, true)
        if (x == nil) then
            return
        end
    
        if (not Spring.IsSphereInView(x, y, z, math.abs(radius))) then
            return
        end
        return x,y,z
    end
    function DrawSphere(type,unitID, radius, degrees,incline,mult)
        local list = lists[type]
        if not list then
            return
        end
        local x,y,z = UnitInView(unitID, radius)
        if not x then
            return
        end
        if mult then
            radius = radius * (mult)
        end
        gl.PushMatrix()
            gl.Translate(x, y, z)
            gl.Scale(radius, radius, radius)
            if incline then
                gl.Rotate(degrees, degrees, degrees, 0)
            else
                gl.Rotate(degrees, 0, 1, 0)
            end
            gl.CallList(list)
        gl.PopMatrix()

    end

end

----------------------------------------------------

function StartMergingFlat() -- Draw only where it has not been drawn
    gl.Clear(GL.STENCIL_BUFFER_BIT, 0)
    gl.DepthMask(false)
    gl.StencilTest(true)
    gl.DepthTest(GL.LEQUAL)
    gl.StencilOp(GL.KEEP, GL.KEEP, GL.INCR)
    gl.StencilMask(1)
    gl.StencilFunc(GL.EQUAL, 0, 1)

end

function EndMergingFlat()
    gl.DepthTest(false)
    gl.StencilTest(false)
    gl.Clear(GL.STENCIL_BUFFER_BIT)


end
function TestStencil() -- Draw only where it has not been drawn
    gl.Clear(GL.STENCIL_BUFFER_BIT, 0)
    gl.DepthMask(false)
    gl.StencilTest(true)
    gl.DepthTest(GL.LEQUAL)
    gl.StencilOp(GL.KEEP, GL.KEEP, GL.INCR)
    gl.StencilMask(1)
    gl.StencilFunc(GL.LEQUAL, 6, 1)

end

function EndStencil()
    gl.DepthTest(false)
    gl.StencilTest(false)
    gl.StencilMask(0xff)
    gl.Clear(GL.STENCIL_BUFFER_BIT)
end

function stencilEnter()
    gl.StencilTest(true)
    gl.DepthTest(true)
    -- gl.Culling(false)
    -- gl.DepthTest(GL.LESS)
    gl.DepthTest(GL.LEQUAL)
    gl.StencilMask(0xff)
    gl.Clear(GL.STENCIL_BUFFER_BIT)
    gl.StencilFunc(GL.EQUAL, 0, 1)
    gl.StencilOp(GL.KEEP, GL.DECR_WRAP, GL.KEEP)
    gl.StencilOpSeparate(GL.FRONT, GL.KEEP, GL.KEEP, GL.KEEP)
    gl.StencilOpSeparate(GL.BACK, GL.KEEP, GL.INCR_WRAP, GL.KEEP)
    gl.DepthMask(false) --disable writing to depth buffer
    gl.ColorMask(false,false,false,false) --disable writing to color buffer
end

function stencilApply()
    gl.StencilFunc(GL.EQUAL, 0, 0xFF)
    gl.DepthTest(false)
    -- gl.Blending(true)
    -- gl.BlendEquation(GL.FUNC_ADD)
    -- gl.BlendFunc(GL.ONE, GL.ONE);
    gl.Culling(true)
    gl.Culling(GL.FRONT);
    gl.DepthMask(true);
    gl.ColorMask(true,true,true,true)
end

function stencilExit()
    gl.StencilTest(false)
    gl.Culling(false)
    gl.Clear(GL.STENCIL_BUFFER_BIT)
    gl.StencilFunc(GL.ALWAYS, 0, 0xff)
    gl.StencilOp(GL.KEEP, GL.KEEP, GL.KEEP)
    gl.StencilOpSeparate(GL.BACK, GL.KEEP, GL.KEEP, GL.KEEP)
    gl.StencilOpSeparate(GL.FRONT, GL.KEEP, GL.KEEP, GL.KEEP)
    gl.DepthMask(false)
end



    function widget:DrawWorld()
        if not TRY_BUBBLES then
            return
        end
        local sel = WG.selection or Spring.GetSelectedUnits()
        if sel and sel[1] then
            -- gl.Utilities.TestStencil()
            -- gl.Utilities.StartMergingFlat()
           -----------
            if not unitParams then
                unitParams = {}
            end

            local frame = Spring.GetGameFrame() + Spring.GetFrameTimeOffset()
            local degrees = frame % (360 * 2 * 3 * 5)
            local delta = math.abs((frame)%50) * 2 -- oscillate between 0 and 50 in 100 frame

            -- gl.CallList(lists.setupSphereDraw)
            for i = #sel, 1, -1 do
                local id = sel[i]
                if PULSE or COLORED then
                    local params = unitParams[id]
                    if not params then
                        params = {}
                        -- setup definitive params for each unit
                        math.randomseed(id)
                        params.maxScale = 0.1 + math.random()/2.5 -- personalized scale mult (pulsing) from 10% to 50% up
                        params.speed = math.random(60) + 20 -- minimum 
                        local r,g,b = math.random(), math.random(), math.random()
                        while r<2/3 and g<2/3 and b<2/3 do
                            local rand = math.random(3)
                            if rand == 1 then
                                r = r + 0.1
                            elseif rand == 2 then
                                g = g + 0.1
                            elseif rand == 3 then
                                b = b + 0.1
                            end
                        end
                        -- r,g,b = 1,0,0
                        params.color = {r,g,b}
                        unitParams[id] = params
                    end
                    local speed = params.speed
                    local delta = math.abs(speed - (frame + id*57)%(speed*2))
                    local mult = 1 + (params.maxScale * (delta) / 100)
                    params.mult = mult-- gives final scale mult result for the current draw
                end
            end
            -- gl.DepthMask(false)

            gl.DepthMask(true)
            gl.ColorMask(false,false,false,false)
            gl.DepthTest(true)
            gl.DepthTest(GL.LEQUAL)
            -- StartMergingFlat()
            

            for i = #sel, 1, -1 do
                local id = sel[i]

                -- gl.Culling(GL.FRONT)
                -- if i == 1 then
                --     Echo((Spring.GetUnitPosition(id)))
                -- end
                -- gl.Color(0.1,0.1,0.3,0.2)
                -- gl.Color(0.1,0.1,0.3,0.2)
                -- gl.Culling(GL.FRONT)
                DrawSphere('simpleSphere',id,128,degrees + id * 57,false,PULSE and unitParams[id].mult)
                -- gl.DrawFuncAtUnit(id,false,DrawSphereAtUnit,'simpleSphere',id,128,degrees + id * 57,false,PULSE and unitParams[id].mult)
                -- gl.Culling(false)
                -- DrawSphere('simpleSphereNeg',id,128,degrees + id * 57,false,unitParams[id].mult)

                -- gl.Culling(GL.BACK)
                -- gl.Color(1,1,1,0.1)
                -- DrawSphere('simpleSphereNeg',id,132,degrees + id * 57)
                -- DrawSphere('cloakSphere',id,128,degrees + id * 57)
                -- gl.Culling(false)
            end
            -- EndMergingFlat()
            -- gl.DepthMask(true)
            gl.ColorMask(true,true,true,true)
            gl.DepthMask(false)
            gl.CallList(lists.setupSphereDraw)

            local offset = 0.5--0.05
            for i = #sel, 1, -1 do
                local id = sel[i]
                local mult = unitParams[id].mult
                -- gl.Culling(GL.BACK)
                -- gl.DepthTest(true)
                -- gl.DepthTest(GL.GEQUAL)
                -- gl.Color(0,0.8,1,0.1)
                -- gl.Culling(GL.FRONT)
                -- DrawSphere('mySphereNeg',id,128,degrees + id * 57, true,mult)
                -- gl.Culling(false)


                -- gl.DepthTest(GL.LEQUAL)
                -- if i == 1 then
                --     Echo((Spring.GetUnitPosition(id)))
                -- end
                -- DrawSphere('simpleSphere',id,130,degrees + id * 57)
                -- gl.Culling(GL.BACK)
                -- gl.Color(1,1,1,0.1)
                -- DrawSphere('simpleSphere',id,128.8,degrees + id * 57)
                -- DrawSphere('cloakSphere',id,128 + offset,degrees + id * 57)
                -- DrawSphere('cloakShield',id,128.5,degrees + id * 57)
                -- gl.Culling(GL.BACK)
                -- DrawSphere('cloakShield',id,128 + offset,degrees + id * 57)
                -- gl.Rotate(id * 57,1,1,0)
                -- gl.Color(0,1,0,1)
                -- uni
                -- glUseShader(shaders.test)
                -- gl.Material({
                --     diffuse = {1,1,1,1}
                -- })
                -- gl.Uniform(unifLoc,unpack(unitParams[id].color))
                -- gl.Material({ambient = {0.5,0,0}})
                -- gl.Material({ambient = unitParams[id].color})
                if COLORED then
                    gl.Material({ambient = unitParams[id].color})
                else
                    gl.Material({ambient = sphereCol})
                end
                gl.Material(sphereMat)   
                -- Echo("sphereMat.diffuse[4] is ", sphereMat.diffuse[4])
                DrawSphere('simpleSphere',id,128 + BUBBLE_JUNCTION,degrees + id * 57,false,PULSE and mult)
                -- glUseShader(0)
                if DRAW_ON_BUBBLE then
                    if INVERT_DRAWING then
                        DrawSphere('mySphereInv',id,128 + BUBBLE_JUNCTION,degrees + id * 57,ROTATE, PULSE and mult)
                    else
                        DrawSphere('mySphere',id,128 + BUBBLE_JUNCTION,degrees + id * 57,ROTATE, PULSE and mult)
                    end
                end


            end
            -- gl.Culling(false)
            gl.DepthTest(false)
            gl.Culling(false)
            
            -- gl.StencilTest(false)
            stencilExit()

            gl.CallList(lists.resetSphereDraw)
            gl.Color(1,1,1,1)

            -----------
            -- gl.Utilities.EndStencil()

            ------------ -- merge flat surface
                -- gl.Utilities.StartMergingFlat()
                -- local mx, my = Spring.GetMouseState()
                -- local _, pos = Spring.TraceScreenRay(mx,my,true,true)
                -- if pos then
                --     local x,y,z = pos[1], pos[2], pos[3]
                --     local r = 100






                --     gl.Color(1,0.5,0,0.2)
                --     gl.PushMatrix()
                --     gl.Translate(x, y, z)
                --     gl.Scale(r, y, r)
                --     -- DrawMergedFlat(plainCircle)
                --     gl.CallList(plainCircle)
                --     gl.Translate(50/r, 0, 0)
                --     gl.Color(1,0.75,0,0.2)
                --     gl.CallList(plainCircle)
                --     gl.Color(1,1,0,0.2)
                --     gl.Translate(-50/r, 0, -50/r)
                --     gl.CallList(plainCircle)
                --     gl.PopMatrix()

                --     gl.Color(1,1,1,1)
                --     -- gl.Utilities.DrawWorldCircle(x,y,z,r)


                -- end
            --------------
            -- gl.Utilities.EndMergingFlat()

        end
    end



































----- test merging flat circle success
-- function widget:DrawWorld()
--     local mx, my = Spring.GetMouseState()
--     local _, pos = Spring.TraceScreenRay(mx,my,true,true)
--     if pos then
--         local x,y,z = pos[1], pos[2], pos[3]
--         local r = 100


--         gl.Utilities.StartMergingFlat()



--         gl.Color(1,0.5,0,0.2)
--         gl.PushMatrix()
--         gl.Translate(x, y, z)
--         gl.Scale(r, y, r)
--         -- gl.Utilities.DrawMergedFlat(plainCircle)
--         gl.CallList(plainCircle)
--         gl.Translate(50/r, 0, 0)
--         gl.Color(1,0.75,0,0.2)
--         gl.CallList(plainCircle)
--         -- gl.Utilities.DrawMergedFlat(plainCircle)
--         gl.Color(1,1,0,0.2)
--         gl.Translate(-50/r, 0, -50/r)
--         gl.CallList(plainCircle)
--         -- gl.Utilities.DrawMergedFlat(plainCircle)
--         gl.PopMatrix()

--         gl.Color(1,1,1,1)

--         gl.Utilities.EndMergingFlat()

--     end
-- end
function widget:Initialize()
end

function widget:Shutdown()
    for _,list in pairs(lists) do
        gl.DeleteList(list)
    end
    for _, shader in pairs(shaders) do
        gl.DeleteShader(shader)
    end
    if options.hide_units.value then
        options.hide_units.value = false
        options.hide_units:OnChange()
    end
end
