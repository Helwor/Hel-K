

function widget:GetInfo()
    return {
        name      = "Draw Terra2",
        desc      = "Terraformation under build previsualization",
        author    = "Helwor",
        version   = "v1",
        date      = "2019",
        license   = "GNU GPL, v2 or later",
        layer     = 999, -- after PBH
        enabled   = true,
    }
end

--------------------------------------------------------------------------------
-- Speedups
--------------------------------------------------------------------------------
local Echo = Spring.Echo



local f = VFS.Include("LuaUI\\Widgets\\UtilsFunc.lua")



local GetDef                            = f.GetDef
--local CheckReach                      = f.CheckReach
local CheckCanSub                       = f.CheckCanSub
--local GetUnitOrFeaturePosition          = tracefunc(f.GetUnitOrFeaturePosition)
--local GetDirection                    = f.GetDirection
--local plusMin                         = f.plusMin
--local table                           = f.table

local l                                 = f.l
--local QueueChanged                      = tracefunc(f.QueueChanged)
local Page                              = f.Page
--local GetCons                           = tracefunc(f.GetCons)

local hollowRectangle                   = f.hollowRectangle

local CheckTime                         = f.CheckTime

local GetCameraHeight                   = f.GetCameraHeight


local spSetActiveCommand        = Spring.SetActiveCommand
local spGetActiveCommand        = Spring.GetActiveCommand
local spGetMouseState           = Spring.GetMouseState
--local spTraceScreenRay          = Spring.TraceScreenRay
local spGetGroundHeight         = Spring.GetGroundHeight
local spGetGroundOrigHeight     = Spring.GetGroundOrigHeight
local spGetTimer                = Spring.GetTimer
local spDiffTimers              = Spring.DiffTimers
local spGetCameraState          = Spring.GetCameraState
local spPos2BuildPos            = Spring.Pos2BuildPos
local spGetBuildProjects        = Spring.GetBuildProjects
local spGetGameSeconds          = Spring.GetGameSeconds

local GL = GL
local GL_LINE_STRIP     = GL.LINE_STRIP
local GL_LINES          = GL.LINES
--local GL_TRIANGLE_FAN   = GL.TRIANGLE_FAN
local GL_TRIANGLE_STRIP = GL.TRIANGLE_STRIP
local GL_LESS           = GL.LESS
local GL_ALWAYS         = GL.ALWAYS

--local GL_QUAD_STRIP     = GL.QUAD_STRIP
local glVertex          = gl.Vertex
local glLineWidth       = gl.LineWidth
local glColor           = gl.Color
local glBeginEnd        = gl.BeginEnd
local glLineStipple     = gl.LineStipple

local glCreateList      = gl.CreateList
local glDeleteList      = gl.DeleteList
local glCallList        = gl.CallList
local glCreateShader    = gl.CreateShader
local glDeleteShader    = gl.DeleteShader
local glPointSize       = gl.PointSize
--[[local GL_FUNC_ADD = 0x8006
local GL_FUNC_SUBTRACT = 0x800a
local GL_FUNC_REVERSE_SUBTRACT = 0x800b
local GL_MIN = 0x8007
local GL_MAX = 0x8008--]]


--local glTexCoord        = gl.TexCoord
--local glTexture         = gl.Texture
local glDepthMask       = gl.DepthMask
local glTranslate       = gl.Translate
local glRotate          = gl.Rotate
local glUnitShape       = gl.UnitShape
local glUseShader       = gl.UseShader
local glBillboard       = gl.Billboard
local glText            = gl.Text
local glPopMatrix       = gl.PopMatrix
local glPushMatrix      = gl.PushMatrix

--local glPolygonMode = gl.PolygonMode
--local glRect = gl.Rect

--local glShape = gl.Shape
local glDepthTest = gl.DepthTest


--local glScale = gl.Scale

--local GL_POLYGON = GL.POLYGON
--local GL_FILL = GL.FILL
--local GL_FRONT_AND_BACK = GL.FRONT_AND_BACK

local GL_EQUAL = GL.EQUAL

local panels


local floor = math.floor
local ceil = math.ceil
local round = math.round
local fround = function(x,n) return tostring(round(x,n)):gsub("%.0+","") end
local abs = math.abs
local max = math.max
local min = math.min
local sqrt = math.sqrt

--global
WG.DrawTerra = WG.DrawTerra or {new=false,finish=true,ready=false}
WG.ghosts=WG.ghosts or {ln=0}
local DrawTerra
local commandLot
local ghosts
local DrawingList
VFS.Include("LuaRules/Configs/customcmds.h.lua")

local mexDefID = UnitDefNames["staticmex"].id

local debugging = false
--------------------------------------------------------------------------------
-- Local Vars
--------------------------------------------------------------------------------

--local preGame=true
local preGame=Spring.GetGameSeconds()==0
local preGameBuildQueue


local function memoize(func)
    local concat=table.concat
    local args
    local results = setmetatable({},{     
        __mode = "v",
        __index=function(res,k) res[k]={func(unpack(args))} return unpack(res[k]) end
    })
    return function(...)
        args={...}
        return results[concat(args)]
    end
end


local overbump,moreoverbump,evenmoreoverbump, pushalittle,pullalittle
local function GenerateShaders() -- those shaders will help make the grid appear above little bumps of the map
    overlap= glCreateShader(
        {
             fragment = [[
                void main()
                {
                    gl_FragData[0].rgba = gl_Color;
                    if (gl_Color.a>1) discard;
                }
            ]],
        }
    )
    overbump=glCreateShader(
        {   
            fragment = [[
                void main()
                {
                    gl_FragData[0].rgba = gl_Color;

                    //**gl_FragData[0].a   = gl_Color.a;

                    //**if ((gl_FragData[0].r > 0.2) || (gl_Color.a == 1 && gl_FragData[0].b == 1))    // force display of the slope ground in case of digging
                    //**if (gl_Color.g == something)
                    //if ( ((gl_Color.r * 1000) ) == 0.5)
                    //**if ( mod(gl_Color.r*1000,1)   == 0.25)
                        gl_FragDepth = (gl_FragCoord.b)*0.99998 ;
                    //if (gl_FragData[0].r > 0.40)
                    //    gl_FragDepth = 0;
                }


            ]],
        }
    )

    moreoverbump=glCreateShader(
        {   
            fragment = [[
                void main()
                {   
                    gl_FragData[0].rgba = gl_Color;
                    gl_FragDepth = (gl_FragCoord.b)*0.9999 ;

                }
            ]],
        }
    )

    evenmoreoverbump=glCreateShader(
        {   
            fragment = [[
                void main()
                {
                    gl_FragData[0].rgba = gl_Color;
                    gl_FragDepth = (gl_FragCoord.b)*0.999 ;
                }
            ]],
        }
    )
    pushalittle=glCreateShader(
        {   
            fragment = [[
                void main()
                {
                    gl_FragData[0].rgba = gl_Color;
                    gl_FragDepth = (gl_FragCoord.b)*1.00001 ;
                }
            ]],
        }
    )
    pullalittle=glCreateShader(
        {   
            fragment = [[
                void main()
                {
                    gl_FragData[0].rgba = gl_Color;
                    gl_FragDepth = (gl_FragCoord.b)*0.99999 ;
                }
            ]],
        }
    )

end



local function DeleteShaders()
    if not glDeleteShader then
        return
    end

    glDeleteShader(overlap or 0)
    glDeleteShader(overbump or 0)
    glDeleteShader(moreoverbump or 0)
    glDeleteShader(evenmoreoverbump or 0)
    glDeleteShader(pushalittle or 0)
    glDeleteShader(pullalittle or 0)
end
-- options variables setup default value

local requestUpdate=true
local show_basic = false
local groundColor
local show_slopped = true




local drawContour = true
local drawSloppedGroundGrid = true
local drawAboveDig = false
local drawBaseGroundGrid = false
local drawBaseGroundContour = true
local slopeFading = true

local inc=8
local addAlpha,AddAlpha={} -- the default AddAlpha function used

local dwOn = false
local dwPlanned = false



local showCost = true
local numborders=5
local groundGridMaxOpacity=1
local quality='automatic'
local s_ground_color = {0, 0.7,  0.7, 0.6} 
local s_ground_on_dig_color = {0, 0.7,  0.7, 0.3}
local s_elev_color = {0, 1, 0, 1}
local s_dig_color = {0.9, 0.3,  0.3, 0.2}
local s_cont_color = {0, 0.9, 0.9, 0.9}

local scrollY=0
local terraPrev_path = 'Hel-K/Terraform Previsualization'


---------- DYNAMIC OPTION PANEL SYSTEM

-- create a starting string with the desired color, convert decimal color to string color
local function ColStr(color)
    local char=string.char
    local round = function(n) -- that way of declaring function ('local f = function()' instead of 'local function f()' make the function ignore itself so I can call round function inside it which is math.round)
        n=round(n)
        return n==0 and 1 or n
    end
   return table.concat({char(255),char(round(color[1]*255)),char(round(color[2]*255)),char(round(color[3]*255))})
end

-- Find out the option panel if it's visible and retain it's scrolling position for refreshing it dynamically when options are changed
local function GetPanel() -- 
    for _,elem in pairs(WG.Chili.Screen0.children) do
        if  type(elem)     == 'table'
        and elem.classname == "main_window_tall"
        and elem.caption   == terraPrev_path
        then
            local scrollpanel,scrollPosY
            for key,v in pairs(elem.children) do
                if type(key)=='table' and key.name:match('scrollpanel') then
                    scrollpanel=key
                    break
                end
            end
            if scrollpanel then 
                scrollPosY = scrollpanel.scrollPosY
            end
            return elem,scrollpanel,scrollPosY
        end
    end
end
-- Dynamic Color List --
-- instead of having a long list of color options in the panel, we make a buttonRadio list to select the color we want to change
-- items names of the list are colored dynamically so we can have an overview of all the colors already set
-- irrelevant color options are dynamically hidden from the list
-- colors are kept linked to the original variable after loading config data

-- reservoir of color items for the dynamic option color list
local colors={
    s_ground_color        = {key  = 's_ground_color',
                             name = ColStr(s_ground_color)..'Ground', basename = 'Ground',
                             val = s_ground_color, default = {unpack(s_ground_color)},
                             IsActive = function() return options.draw_s_ground_grid.value and options.choice.value=='show_slopped' end,
                             Update = function(val) for i=1,4 do s_ground_color[i]=val[i] end end,

    },
    s_ground_on_dig_color = {key  = 's_ground_on_dig_color',
                             name = ColStr(s_ground_on_dig_color)..'Ground above Dig', basename = 'Ground above Dig',
                             val = s_ground_on_dig_color, default = {unpack(s_ground_on_dig_color)},
                             IsActive=function() return options.draw_s_above_dig.value and options.choice.value=='show_slopped' end,
                             Update = function(val) for i=1,4 do s_ground_on_dig_color[i]=val[i] end end,
    },
    s_elev_color          = {key  = 's_elev_color',
                             name = ColStr(s_elev_color)..'Elevation', basename = 'Elevation',
                             val = s_elev_color, default = {unpack(s_elev_color)},
                             IsActive=function() return options.choice.value=='show_slopped' end,
                             Update = function(val) for i=1,4 do s_elev_color[i]=val[i] end end,
    },
    s_dig_color           = {key  = 's_dig_color',
                             name = ColStr(s_dig_color)..'Dig', basename = 'Dig',
                             val = s_dig_color, default = {unpack(s_dig_color)},
                             IsActive  = function() return options.choice.value=='show_slopped' end,
                             Update = function(val) for i=1,4 do s_dig_color[i]=val[i] end end,
    },
    s_cont_color          = {key  = 's_cont_color',
                             name = ColStr(s_cont_color)..'Contour', basename = 'Contour',
                             val = s_cont_color,default = {unpack(s_cont_color)},
                             Update = function(val) for i=1,4 do s_cont_color[i]=val[i] end end,
                             IsActive=function() return options.draw_s_contour.value and options.choice.value=='show_slopped' end,
    },
}
-- work around: behaviour of radioButton object is broken because the scrollPosY get resetted to 0 before the original refreshing function register it
-- so to keep the scrolling when clicking on radioButton list we hijack the access by Epic Menu of an item to get informed before that scrollPosY get reset, (regular OnChange function comes too late)
-- TODO: fix the original radioButton object/Epic Menu behaviour
setmetatable(colors.s_elev_color,{__index=function(t,k) if scrollY==0 then local sY=select(3,GetPanel()) or 0 if sY~=0 then scrollY=sY end end end})
--
-- Menu refresh, hide irrelevant options
local function UpdateOptionsDisplay()
    local panel,_,sY = GetPanel() -- checking if panel is active and reminding the scrolling
    if sY==0 then sY=scrollY end 
    -- Hide irrelevant options
    local options,order = options,options_order
    local option
    for i=1, #order do
        option = options[ order[i] ]
        if option.IsVisible then
            option.hidden = not option.IsVisible()
        end
    end
    if options.color_list.new then
        options.color_list.new=false
    else
        -- Updating color list -- 
        local items = options.color_list.items
        for i=1,#items do items[i]=nil end
        for key,color in pairs(colors) do
            if color.IsActive() then table.insert(items,color) end
        end
    end
    -- check/uncheck default color button 
    local isDefault=true
    local color = colors[options.color_list.value]
    for i=1,4 do
        if (abs(color.val[i]-color.default[i])>0.02) then
            isDefault=false
            break
        end
    end
    options.default_color.value = isDefault
    -- refreshing menu if it's active, and get back where it was scrolled -- 
    if panel then
        WG.crude.OpenPath(terraPrev_path)
        if scrollY and scrollY~=0 then
            local _,scrollpanel = GetPanel()
            scrollpanel.scrollPosY=scrollY -- scrolling back
        end
    end
    --
    scrollY=0
    --**GenerateShaders() -- regenerate shader -- not useful if I give up the red color trick to discernate zones
    if dwOn then WG.DrawTerra.new=true end -- renewing the drawing with the new options if there was a building project going on
end
-------


options_path = 'Settings/Interface/Building Placement'
local hotkeys_path = 'Hotkeys/Construction'

options_order = {
    'choice',
    'show_basic_label','show_slopped_label',
    'draw_s_contour','draw_s_above_dig','s_fading',
    'draw_s_ground_grid', 's_numborders','s_set_border_shape',--[[ 's_border_alpha_start',--]]
    's_grid_size','show_s_cost',
    'color_list','selected_color','default_color',
    'draw_g_ground_grid', 'draw_g_contour',
}
options = {
    choice = {
        name            = 'Choose Visualization Mode',
        type            = 'radioButton',
        value           = 'show_slopped',
        OnChange        = function(self)
                            show_slopped = self.value=='show_slopped'
                            show_basic= not show_slopped
                            if show_basic then options.s_set_border_shape.value='AddAlpha_square'
                            else options.s_set_border_shape.value='AddAlpha_round' end
                            AddAlpha=addAlpha[options.s_set_border_shape.value]
                            requestUpdate=true
                          end,
        items           = {
                            { key = 'show_slopped', name = "Show Full Terraform Slope",  },
                            { key = 'show_basic', name = "Show Basic Vertical Terraform", },
                        },
        path            = terraPrev_path,
    },
    -- option title
    show_basic_label = {
        name            = 'Ground Options',
        type            = 'label',
        path            = terraPrev_path,
        IsVisible       = function() return (options.choice.value=='show_basic') end,
    },
    show_slopped_label = {
        name            = 'Slope Options',
        type            = 'label',
        path            = terraPrev_path,
        IsVisible       = function() return (options.choice.value=='show_slopped') end,
    },
    --
    -- slope mode options
    draw_s_contour = {
        name            = 'draw Contour',
        type            = 'bool',
        desc            = "Draw Contour around the slope",
        noHotkey        = true,
        value           = true,
        OnChange        = function(self)
                            Echo("self.value is ", self.value)
                            updateColorItems=true
                            drawContour = self.value
                            requestUpdate=true
                          end,
        path            = terraPrev_path,
        IsVisible       = function() return (options.choice.value=='show_slopped') end,
    },
    --- Ground Grid options
    draw_s_above_dig = {
        name            = 'Draw Ground Grid above Dig zone',
        type            = 'bool',
        noHotkey        = true,
        OnChange        = function(self)
                            drawAboveDig=self.value
                            requestUpdate=true
                          end,
        path            = terraPrev_path,
        IsVisible       = function() return (options.choice.value=='show_slopped') end,
    },
    s_fading = {
        name            = 'Draw Faded Slope',
        desc            = 'according to height difference',
        type            = 'bool',
        noHotkey        = true,
        OnChange        = function(self)
                            slopeFading = self.value
                            requestUpdate=true
                          end,
        path            = terraPrev_path,
        IsVisible       = function() return (options.choice.value=='show_slopped') end,
    },
    draw_s_ground_grid = {
        name            = 'Draw Surrounding Ground Grid',
        type            = 'bool',
        noHotkey        = true,
        OnChange        = function(self)
                            drawSloppedGroundGrid = self.value
                            requestUpdate=true
                          end,
        path            = terraPrev_path,
        IsVisible       = function() return (options.choice.value=='show_slopped') end,
    },

    s_numborders = {
        name            = ' ..5 borders.',
        type            = 'number',
        value           = 5,
        min             = 2,
        max             = 20,
        step            = 1,
        tooltipFunction = function(self)
                            return self.value==2 and 'automatic' or self.value
                          end,
        OnChange        = function(self)
                            numborders = self.tooltipFunction(self)
                            self.name = ' ..'..(numborders=='automatic' and 'automatic' or numborders..' border'..(numborders>1 and 's' or ''))..'.'
                            requestUpdate=true
                          end,
        path            = terraPrev_path,
        IsVisible       = function() return (options.draw_s_ground_grid.value) end,
    },

    s_set_border_shape = {
        name            = ' ..set borders shape',
        type            = 'radioButton',
        value           = 'AddAlpha_round',
        noHotkey        = true,
        OnChange        = function(self) -- 
                            if not self.value then self.value='AddAlpha_round' end
                            AddAlpha=addAlpha[self.value]
                            requestUpdate=true
                          end,
        items = { -- changing keys depending on which options are active
            {name = "surrounding slope", key  = 'AddAlpha_round',},
            {name = 'squared',           key  = 'AddAlpha_square'},
        },
        path            = terraPrev_path,
        IsVisible       = function() return options.draw_s_ground_grid.value end,
    },
    s_grid_size = {
        name            = 'Grid Cell Size: automatic',
        type            = 'number',
        min             = 0,
        max             = 32,
        step            = 8,
        value           = 32,
        tooltipFunction = function(self)
                            return self.value==0 and 'basic' or self.value==24 and 32 or self.value==32 and 'automatic' or self.value
                          end,
        OnChange        = function(self)
                            quality = self.tooltipFunction(self)
                            if quality=='basic' then
                                inc = 16
                            elseif quality~='automatic' then
                                inc = quality
                            end
                            self.name = 'Grid Cell Size: '..quality
                            requestUpdate=true
                          end,
        path            = terraPrev_path,
        IsVisible       = function() return (options.choice.value=='show_slopped') end,
    },
    show_s_cost = {
        name            = 'show Terraform cost',
        type            = 'bool',
        noHotkey        = true,
        OnChange        = function(self)
                            showCost = self.value
                            requestUpdate=true
                          end,
        path            = terraPrev_path,
        IsVisible       = function() return (options.choice.value=='show_slopped') end,
    },
    color_list = {
        name            = 'Colors',
        type            = 'radioButton',
        noHotkey        = true,
        value           = 's_elev_color',
        OnChange        = function(self) -- 
                            options.selected_color.colorkey=self.value
                            options.selected_color.value=colors[self.value].val
                            options.color_list.new=true
                            requestUpdate=true
                          end,
        items = {
                        colors['s_elev_color'],
                        colors['s_dig_color'],
                        colors['s_ground_color'],
                        colors['s_ground_on_dig_color'],
                        colors['s_cont_color'],
        },
        path            = terraPrev_path,
        IsVisible       = function() return (options.choice.value=='show_slopped') end,
    },
    selected_color = {
        name            = '',
        type            = 'colors',
        default_value   = {0, 0.7,  0.7, 1},
        colorkey        = 's_elev_color',
        value           = s_elev_color,
        OnChange        = function (self)
                            --****s_ground_color[1] = round(s_ground_color[1],2)+0.0025 -- trick to identify desired zone in shader
                            options.color_list.new=true
                            local key = self.colorkey
                            if key then
                                colors[key].Update(self.value)
                                local color = colors[key]
                                color.name = ColStr(color.val)..color.basename
                            end
                            requestUpdate=true
                        end,
        path            = terraPrev_path,
        IsVisible       = function() return (not options.color_list.hidden) end,
    },


    --
        default_color = { -- dynamic default color button changing on color selected
        name            = 'default',
        type            = 'bool',
        noHotkey        = true,
        init            = true,
        value           = false,
        OnChange        = function(self)
                            local key=options.color_list.value
                            options.color_list.new=true
                            local opt = colors[key]
                            if opt then
                                local val,default = opt.val,opt.default
                                if default and val then
                                    for i=1,4 do 
                                        val[i]=default[i]
                                    end -- replace color
                                    opt.name = ColStr(val)..opt.basename
                                    options.selected_color.value = val
                                end
                            end
                            requestUpdate=true
                          end,
        path            = terraPrev_path,
        IsVisible       = function() return not options.color_list.hidden end
    },
    draw_g_ground_grid = {
        name            = 'draw ground grid',
        type            = 'bool',
        noHotkey        = true,
        OnChange        = function(self)
                            drawBaseGroundGrid = self.value
                            if dwOn then WG.DrawTerra.new=true end
                          end,
        path            = terraPrev_path,
        IsVisible       = function() return (options.choice.value=='show_basic') end,
    },
    
    draw_g_contour = {
        name            = 'draw base contour',
        type            = 'bool',
        noHotkey        = true,
        OnChange        = function(self)
                            drawBaseGroundContour = self.value
                            if dwOn then WG.DrawTerra.new=true end
                          end,
        path            = terraPrev_path,
        IsVisible       = function() return (options.choice.value=='show_basic') end,
    },
    --
}

--------------


--[[local function CreateBasicSlopeLines(bx,bz,bw,bh,canFloat,by,needTerra)
    --creates 8 lines coming from each cardinal
    local maxx,maxz = Game.mapSizeX, Game.mapSizeZ

    local lines = {bx=bx,bz=bz,bw=bw,bh=bh,by=by,needTerra=needTerra,canFloat=canFloat}
    local slope
    local conv = {
        {-1,-1,'NW'},{0,-1,'N'},{1,-1,'NE'},{1,0,'E'},{1,1,'SE'},{0,1,'S'},{-1,1,'SW'},{-1,0,'W'}
    }
    local lstart
    local incmult = 1/(8/inc)
    for ln=1,8 do
        lstart=true
        local fx,fz,cardinal = unpack(conv[ln])
        local incx,incz = inc*fx,inc*fz
        local x,z = bx+bw*fx, bz+bh*fz
        local i=0
        local elev
        local endslope
        local line={{x,by,z},elev=0}
        while true do
            local limit = (x==0 or x==maxx or z==0 or z==maxz)
            i=i+1
            gy = spGetGroundHeight(x,z)
            local isFloating
            
            local newelev=by>gy and -1 or by<gy and 1 or 0
            local mark
            slope=false
            if lstart then 
                if canFloat and gy<=0.1 then gy=0.1 isFloating=true end
                elev=newelev
                y = by
                slope=abs(by-gy)
                if slope>5 then
                    line.elev=elev
                else
                    mark=true
                    slope=false
                end
                lstart=false
            elseif endslope then
                y=gy
                mark=true
            elseif elev==newelev then
                ni=i-1
                local newy = by
                newy = newy + (#cardinal==2 and 40 or 28) * ni * incmult * elev

                if elev==1 then newy=newy-20 end -- digging is a bit different, larger hole
                local diff = (newy-gy) * elev
                 -- check if point is between new height calculated and ground height
                if diff>-4 and diff<=10 then -- finish the slope with a little elevation/digging bordering
                    if elev==1 then
                        newy = gy-6; slope=6; endslope=true
                    else 
                        newy = gy+4; slope=4; endslope=true
                    end
                elseif diff <=-4 then
                    slope = -diff
                else 
                    newy = gy
                end
                y = newy
            end
            line[i]={x,y,z,gy=gy,slope=slope,elev=elev,endslope=endslope,cardinal=cardinal,isFloating=isFloating, mark=mark}
            --if isFloating then line[i].mark=true end
            if not slope or endslope or limit then break end
            x,z = x+incx,z+incz
        end
        lines[ln]=line
    end
    return lines
end--]]


local CreateBasicSlopeLines
do
    local CORNERS = {
        {{-1,0,'W'},{-1,-1,'NW'},{0,-1,'N'}},
        {{0,-1,'N'},{1,-1,'NE'},{1,0,'E'}},
        {{1,0,'E'},{1,1,'SE'},{0,1,'S'}},
        {{0,1,'S'},{-1,1,'SW'},{-1,0,'W'}}
    }
    CreateBasicSlopeLines = function(bx,bz,bw,bh,canFloat,by,needTerra)
        --creates 12 lines coming from each cardinal
        local maxx,maxz = Game.mapSizeX, Game.mapSizeZ

        local lines = {bx=bx,bz=bz,bw=bw,bh=bh,by=by,needTerra=needTerra,canFloat=canFloat}

        local slope

        local lstart
        local incmult = 1/(8/inc)
        local ln=0
        for c=1,4 do
            local corner = CORNERS[c]
            for d=1,3 do
                local x,z = bx+bw*corner[2][1], bz+bh*corner[2][2]
                local fx,fz,cardinal = unpack(corner[d])
                local incx,incz = 8*fx,8*fz
                lstart=true
                local i=0
                local elev,polish,endslope
                local line={elev=0}
                while true do
                    local limit = (x==0 or x==maxx or z==0 or z==maxz)
                    i=i+1
                    gy = spGetGroundHeight(x,z)
                    local isFloating
                    local newelev=by>gy and -1 or by<gy and 1 or 0
                    local mark
                    local inshape=false
                    slope=false
                    if lstart then 
                        lstart=false

                        if canFloat and gy<=0.1 then gy=0.1 isFloating=true end
                        elev=newelev
                        y = by
                        slope=abs(by-gy)
                        if slope>5 then
                            line.elev=elev
                        else
                            slope=false
                            endslope=true
                        end
                    elseif polish then
                        y=gy
                        endslope=true
                        polish=false
                    elseif elev==newelev then
                        ni=i-1
                        local newy = by
                        newy = newy + (#cardinal==2 and 40 or 28) * ni --[[* incmult--]] * elev
                        if elev==1 then newy=newy-20 end -- digging is a bit different, larger hole
                        local diff = (newy-gy) * elev
                         -- check if point is between new height calculated and ground height
                        if diff>-4 and diff<=10 then -- finish the slope with a little elevation/digging bordering
                            if elev==1 then
                                newy = gy-6; slope=6
                            else 
                                newy = gy+4; slope=4
                            end
                            polish=true
                        elseif diff <=-4 then
                            slope = -diff

                        else 
                            newy = gy

                            endslope=true
                        end
                        y = newy
                    else
                        y=gy
                        endslope=true
                    end
                    line[i]={x,y,z,gy=gy,slope=slope,elev=elev,endslope=endslope,cardinal=cardinal,isFloating=isFloating, polish=polish, mark=mark}
                    --if isFloating then line[i].mark=true end
                    if endslope or limit then
                        break
                    end
                    x,z = x+incx,z+incz
                end
                ln=ln+1; lines[ln]=line
            end
        end
        local shapes={}
        local line = lines[1]
        for i=2,13 do
            local nextline = lines[i] or lines[1]
            i=i-1
            local ln,nln = #line, #nextline

            shapes[i]={
                line[1],nextline[1],
                line[ln-2],nextline[nln-2],
                line[ln-1],nextline[nln-1],
                line[ln],nextline[nln]
            }
            for j=1,#shapes[i] do
                if not shapes[i][j] then table.remove(shapes[i],j) end
            end
            line=nextline
        end

        lines.shapes = shapes
        return lines
    end
end
local function CreateBasicContour(lines)
    local step=lines[1][ #lines[1] ]
    local stx,stz = step[1],step[3]
    local canFloat = lines.canFloat
    local contour={}
    local ln=0
    for i=2,13 do
        local cardinal = step.cardinal
        ln=ln+1; contour[ln]=step
        --Echo("cardinal is ", cardinal)
        contour[cardinal]=step
        local line=lines[i] or lines[1]
        local newstep=line[#line]
        local isFloating = step.isFloating or newstep.isFloating
        local ex,ez = newstep[1], newstep[3]
        local dirx,dirz = ex-stx,ez-stz
        local div = max(abs(dirx),abs(dirz))
        dirx,dirz = (dirx/div)*8,(dirz/div)*8
        local mid = div/16
        local m = 0
        while (abs(ex-stx)>=8 or abs(ez-stz)>=8) do
            
            if m==round(mid) then --[[contour[ln].mark=true--]] contour[cardinal..'-'..newstep.cardinal]=contour[ln] end
            --if isFloating and gy<=0.1 then contour[ln].mark=true end
            m=m+1; 
            stx,stz = stx+dirx,stz+dirz
            local gy = spGetGroundHeight(stx,stz)
            ln=ln+1; contour[ln]={stx,(isFloating and gy<=0.1 and 0.1 or gy),stz}
        end

        step=newstep
        stx,stz=ex,ez
    end
    local gy = spGetGroundHeight(stx,stz)
    ln=ln+1; contour[ln]=lines[1][ #lines[1] ]
    lines.contour = contour
end

local function CreateHollowRectangles(bx,bz,bw,bh,inc,num,float,by,corners)--create tables of hollow rectangles with cardinal points, clockwise(NW,NE,SE,SW,last before NW) from center to exterior, begining at  NorthWest corner, point separated by incrementation
    local y=by
    local layers={}
    local alpha=1.2
    local maxx,maxz = Game.mapSizeX, Game.mapSizeZ
    for i=1,num do
        local smallerRect, maxlns
        if i>1 then smallerRect = layers[i-1]; maxlns=#smallerRect end
        local ln,lnc,lns = 0,0,1
        local inCorner
        alpha=alpha-0.2
        layers[i]={corners={}}

        local layer=layers[i]

        for x,z,cardinal in hollowRectangle(bx, bz, bw, bh, inc) do
            local out = x<0 or x>maxx or z<0 or z>maxz
            ln=ln+1
            if not by then -- by is not passed in argument meaning we define points on ground
                y = spGetGroundHeight(x,z)  -- -//(+5 to pass the depth test on little bumps of the map)//- = using shader now, doesnt have to cheat on real height
            if float and y<0 and by==0.1 then y=0.1 end -- ground will be drawn on water line instead of subaquatic if unit can float
            end
            layer[ln]={x, y, z, cardinal=cardinal, out=out, bigger={}, alpha=alpha}
            if #cardinal==2 then
                lnc=lnc+1
                layer.corners[lnc]=layer[ln]
            end
            if #cardinal==2 then
                inCorner=true
                lnc, lns = lnc+1, lns-1
                layer.corners[lnc]=layer[ln]
            elseif inCorner then
                inCorner=false
                lns=lns-1
            end
            if smallerRect then 
                layer[ln].smaller = smallerRect[lns] or smallerRect[1]
                if lns>maxlns then 
                    table.insert(layer[1].smaller.bigger, 1, layer[ln])
                else
                    local bigger = layer[ln].smaller.bigger
                    bigger[#bigger+1]=layer[ln]
                end
            end
        end
        bw, bh = bw+inc, bh+inc
        --layer[ln+1]=layer[1] -- to finish the loop of vertices
    end
    return layers
end

-- the most important function
local CreateSloppedRectangles
do
    local registerX = {
        __index=function(t,x)
            t[x]={}
            if x<t.minx then t.minx=x elseif x>t.maxx then t.maxx=x end
            return t[x]
        end
    }
    local registerZ = {
        __index=function(t,z)
            t[z]={}
            if z<t.minz then t.minz=z elseif z>t.maxz then t.maxz=z end
            return t[z]
        end
    }
    CreateSloppedRectangles = function(bx,bz,bw,bh,num,float,by,needTerra)--create tables of hollow rectangles with cardinal points, clockwise(NW,NE,SE,SW,last before NW) from center to exterior, begining at  NorthWest corner, point separated by incrementation
        local cost=0
        local maxx,maxz = Game.mapSizeX, Game.mapSizeZ
        local gotElev,gotDig,gotTrans = false,false,false

        -- local chk=CheckTime('start')

        -- we have to set a conversion system in case the increment is 32, as grid limit might fall out of the map, we will correct it
         -- adjust the limit of the grid if we are in low quality (cell size 32), we will redirect out of limit to limit
        local offsetX = inc==32 and (bx-bw)%32==16
        local offsetZ = inc==32 and (bz-bh)%32==16 
        local isoff = offsetX or offsetZ
        local offx,offz = {},{}
        local neighbourx,neighbourz = {},{}

        if offsetX then
            offx = { [-16]=0, [maxx+16]=maxx, [0]=-16, [maxx]=maxx+16 }
            neighbourx = {[-16]=16, [maxx+16]=maxx-16}
        end
        if offsetZ then offz = { [-16]=0, [maxz+16]=maxz, [0]=-16, [maxz]=maxz+16 }
            neighbourz = {[-16]=16, [maxz+16]=maxz-16}
        end


        local function copy(t,a,b)
            local c={}
            for k,v in pairs(t[a]) do c[k]=v end
            if b then for k,v in pairs(t[b]) do c[k]=v end end
            return c
        end
        local minmax = {{minx=bx-bh,maxx=bx+bh},{minz=bz-bw,maxz=bz+bw}}
        local grid = copy(minmax,1,2)
        setmetatable(grid,{__index=function(t,x)  --[[if x<t.minx then t.minx=x elseif x>t.maxx then x=t.maxx end--]] t[x]={} return t[x] end})

        num=math.ceil(num) + 1 -- add one more layer on the border of the lastslope
        local inc = inc
        local layers={cost=0, midx=bx+bw,float = float}
        local gy=spGetGroundHeight(bx,bz)
        local maxDig, minElev,maxElev = by,by,by
        local innercost=0
        local innermin = min(bw,bh)
        local reduce = innermin-8
        local xoffset,zoffset = bw-innermin,bh-innermin
        local inbw,inbh = bw-reduce, bh-reduce
        -- origin line/point
        for x=bx-xoffset, bx+inbw-8, 8 do
            --if not grid[x] then grid[x]={} end
            for z=bz-zoffset, bz+inbh-8, 8 do
                gy = spGetGroundHeight(x,z)  
                local mark
                if float and gy<=0.1 and by==0.1 then gy=0.1 end
                local needTerra = needTerra
                if needTerra then needTerra = abs(by-gy)>0 end
                local slope,elev
                if needTerra then 
                    mark=true
                    elev=by>gy and -1 or by<gy and 1 or 0
                    slope=abs(by-gy)
                    if slope>5 then
                        if not gotDig and elev==1 then gotDig=1
                        elseif not gotElev and elev==-1 then gotElev=-1
                        end
                    end
                    innercost=innercost+slope
                end
                grid[x][z]={x, by, z, cardinal='N', gy=gy, inner=true, slope=slope, elev=elev}
                --if elev==1 or elev==-1 then grid[x][z].mark=true end
                --if mark then grid[x][z].mark=true end

                if x==bx and z==bz then grid[x][z].center=true end
            end
        end
        -- inner rectangles
        local innum = reduce/8    
        for i=1, innum do
            local inln=0
            for x,z,cardinal in hollowRectangle(bx, bz, inbw, inbh, 8) do
                gy = spGetGroundHeight(x,z)  -- -//(+5 to pass the depth test on little bumps of the map)//- = using shader now, doesnt have to cheat on real height
                if float and gy<=0.1 and by==0.1 then gy=0.1 end
                local needTerra = needTerra
                if needTerra then needTerra = abs(by-gy)>0 end
                if needTerra then innercost=innercost+abs(by-gy) end
                local slope,elev
                if needTerra then 
                    elev=by>gy and -1 or by<gy and 1 or 0
                    slope=abs(by-gy)
                    if slope>5 then
                        if not gotDig and elev==1 then gotDig=1
                        elseif not gotElev and elev==-1 then gotElev=-1
                        end
                    end
                end
                --if not grid[x] then grid[x]={} end
                grid[x][z]={x, by, z, cardinal=cardinal, gy=gy, inner=true, slope=slope, elev=elev}
                --if elev==-1 or elev==1 then grid[x][z].mark=true end
            end
            inbw,inbh=inbw+8,inbh+8
        end    
        ---------------------
        -- border build and all the rest of the grid...

        -- local chkpass1 = CheckTime('start') 
        -- local chkpass2 = CheckTime('start') 

        -- chkpass2('pause')
        local i=0
        local lastslope=0
        local incmult = 1/(8/inc)
        local point
        local smallerRect, maxlns
        local footPrint={}
        local fracCount=0
        local layer={}
        local maxElevSlope, maxDigSlope = 0,0
        local endSlopeStart -- correct but unused variable
        local outi
        --**--
        local x,z
        local incx,incz
        local width,height = bw*2/inc,bh*2/inc
        local c1,c2,c3,c4,c5,c6,c7= 2, 1+width, 2+width, 1+width+height, 2+width+height, 1+width*2+height, 2+width*2+height
        local cardinals ={[c1]='N',[c2]='NE',[c3]='E',[c4]='SE',[c5]='S',[c6]='SW',[c7]='W'}

        --**--
        while i<num do
            -- firstpass = create base points, calculate future rounded corners of pyramid
            -- chkpass1('resume')
            i=i+1
            local lnc, lns = 0,1 -- length of current rectangle, current corner count, corresponding index of point of smaller rectangle
            local maxln=(bw+bh)/2/incmult
            layer.ln=maxln
            local diags,fracs={},{}
            local corner
            --**--
            incx,incz=inc,0
            local cardinal='NW'
            x,z = bx-bw,bz-bh
            for ln=1, maxln do
                --switch increment for x,z and cardinal prop when needed to continue our rectangle
                if cardinals[ln] then
                    cardinal=cardinals[ln]
                    if #cardinal==2 then incx,incz=-incz,incx end
                end
                --if x==0 and z==-16 then Echo('found point#'..ln,offx[x] or x, offz[z] or z,'register as', x,z) Echo("offsetX,offsetZ is ", offsetX,offsetZ) end

            --**--
                local offset
                if isoff and (offx[x] or offz[z]) then -- move the x/z temporarily to the correct limit of the map and remember it for the purpose of getting correct measure (in case of grid cell size = 32)
                    x,z,offset= offx[x] or x, offz[z] or z, {x,z}
                end

                local out = x<0 or x>maxx or z<0 or z>maxz
                --if not out then
                    if not outi and out then outi=i end
                    local limit =  not out and (x==0 or x==maxx or z==0 or z==maxz)

                    gy = spGetGroundHeight(x,z)
                    if float and gy<=0.1 and by==0.1 then gy=0.1 end
                    local elev,diff,slope
                    local b1 = i==1
                    local needTerra = needTerra and b1 and not (float and gy==0.1)
                    local mark
                    local border
                    if needTerra then
                        elev = by>gy and -1 or by<gy and 1 or 0
                        diff=(by-gy)*elev
                        if diff<-5 then
                            slope=-diff
                        end

                        if slope then
                            if elev==-1 then 
                                if not gotElev then gotElev=-1 end
                                maxElevSlope=max(maxElevSlope,slope)
                                --mark=true
                            elseif elev==1 then
                                if not gotDig then gotDig=1 end
                                maxDigSlope=max(maxDigSlope,slope)
                                --mark=true
                            end
                            cost=cost+slope
                            lastslope=i
                        else
                            border = true
                            -- mark = true
                            elev=nil
                        end
                    end
                    if b1 then 
                        point={x, by, z, n=ln, gy=gy, cardinal=cardinal, out=out, slope=slope, b1=true, elev=elev, diff=diff, border = border, mark = mark }
                        footPrint[ln]=point
                        --if mark then point.mark=true end
                        --if point.elev==1 or point.elev==-1 then point.mark=true end
                    else
                        point={x, gy, z, n=ln, gy=gy, cardinal=cardinal, out=out}
                    end
                    -- point.mark = slope and round(slope,1):gsub('%.0$','')
                    layer[ln]=point
                    if not out then
                        if limit then point.limit=true end
                        if offset then
                            x,z = unpack(offset)
                            grid[x][z]=point
                            point.offset=offset
                        else
                            grid[x][z]=point
                        end
                    end
                    if #cardinal==2 then -- precalculate fractions for rounded corners on the second pass (makes a nice curve of the line)  
                        lnc=lnc+1; --layer.corners[lnc]=point
                        if i<(lastslope+2) then
                            for k = -i+2, i-2 do
                                local ni,diag = i-1,(ln+k)
                                if diag<1 then diag=maxln+1+k end
                                local off= ni-abs(k)
                                if lnc==1 and k<1 then
                                    fracs[off]=round((off/ni)^2,3)
                                end
                                diags[diag]=fracs[off]
                            end
                        end
                    end
                --end
                if offset then x,z=unpack(offset) end
                x,z=x+incx,z+incz
                --
            end
            --prepare next loop
            cardinals[c2]=nil; cardinals[c3]=nil; cardinals[c4]=nil; cardinals[c5]=nil; cardinals[c6]=nil; cardinals[c7]=nil
            c2,c3,c4,c5,c6,c7=c2+2,c3+2,c4+4,c5+4,c6+6,c7+6
            cardinals[c1]='N';cardinals[c2]='NE';cardinals[c3]='E';cardinals[c4]='SE'; cardinals[c5]='S';cardinals[c6]='SW';cardinals[c7]='W'
            bw, bh = bw+inc, bh+inc
            --

            -- second pass:  define slope
            -- chkpass1('pause')
            -- chkpass2('resume')
            local point
            local CONVCARD={NW={inc,inc}, N={0,inc}, NE={-inc,inc}, E={-inc,0}, SE={-inc,-inc}, S={0,-inc}, SW={inc,-inc},W={inc,0}}
            local j = 0
            if i>1 then
                for p=1, maxln do
                    point=layer[p]
                    -- define slope with precalculated fraction defined in the first pass
                    
                    if not point.out and i<lastslope+3 then
                        -- point.mark = true
                        local x,z
                        if point.offset then
                            x,z = unpack(point.offset)
                        else
                            x,z=point[1],point[3]
                        end
                        --Echo("offx[ point[1] ],offz[ point[3] ] is ", offx[ point[1] ],offz[ point[3] ])
                        if not (float and point.gy==0.1 and  point[2]<=point.gy) then
                            
                            -- checking smaller rectangle corresponding point and not continuing slope if that smaller reached ground
                            local smi=CONVCARD[point.cardinal]
                            local smaller = grid[ x+smi[1] ][ z+smi[2] ]
                            if smaller.slope and not smaller.polish then
                                local gy = point.gy
                                local slope,polish
                                local ni=i-1
                                local newy = by
                                local elev = by > gy and -1 or 1
                                
                                if elev==smaller.elev then
                                    local fraction = diags[p] or 0
                                    -- lower even more the point if it's in a rounded corner of the pyramid
                                    local offset = (28 + fraction * 12)  -- shift the height from elevation/digging maximum

                                    
                                    newy = by + (offset * ni * incmult * elev)

                                    if elev==1 then newy=newy-20 end -- digging is a bit different, larger hole
                                    local diff = (newy-gy) * elev
                                    -- Echo("diff is ", diff)
                                     -- check if point is between new height calculated and ground height
                                    -- if diff>-4 and diff<=10 then -- finish the slope with a little elevation/digging bordering
                                    --     if elev==1 then
                                    --         newy = gy-6; slope=6; polish=true
                                    --     else 
                                    --         newy = gy+4; slope=4; polish=true
                                    --     end
                                    -- elseif diff <=-4 then
                                    --     slope = -diff
                                    -- end
                                    
                                    -- if 
                                    -- point.mark = fround(diff,1)
                                    -- point.mark = fround(smaller[2] - newy,1)
                                    if diff>-4 and diff<=10 then
                                        -- finish the slope with a little elevation/digging bordering if it appears to be
                                        if elev==1 then
                                            newy = gy-6; slope=6; polish=true
                                        else 
                                            -- point.mark = fround(-diff,1)
                                            newy = gy+4; slope=4; polish=true
                                        end
                                    elseif diff <=-4 then -- we're not close to the ground yet
                                        slope = -diff
                                    end
                                    if diff <= -(offset/2) then
                                        -- slope = -diff
                                    end
                                    if slope then
                                        point.polish=polish
                                        point[2]=newy
                                        point.diff=-diff
                                        point.elev=elev
                                        point.slope=slope
                                        cost=cost+slope
                                        lastslope=i

                                        if elev==gotElev then
                                            maxElevSlope=max(maxElevSlope,slope)
                                            -- point.mark=true
                                        elseif elev==gotDig then
                                            maxDigSlope=max(maxDigSlope,slope)
                                            --point.mark=true
                                        end
                                    else
                                        if not endSlopeStart then
                                            endSlopeStart=i
                                        end
                                    end
                                end
                                -- point.mark = round(point[2] - gy,1):gsub('%.0$','')
                            end
                            -- if (not point.slope) and smaller.slope then
                            --     point.border = true
                            --     point.smaller = smaller
                            --     point.mark = --[[point.slope and fround(point.slope, 1) or--]] true
                            -- end
                            -- if point.slope then
                            --     -- point.mark = fround(point.slope, 1)
                            -- end
                            -- if smaller.border then
                            --     local gdSmaller = smaller.smaller
                            --     if gdSmaller then
                            --         -- point.mark = true
                            --     end
                            -- end
                            -- if point.border then
                            --     -- point.mark = true
                            -- end
                        end
                    end
                end
            end
            if lastslope==i and num<100 then -- up the max of rectangles to make until the slope has totally ended
                num=num+1
                
            end

            -- chkpass2('pause')

        end--- end of points creation --




        -- local chkpass3 = CheckTime('start')

        -- 3rd pass, deduce endslope, transition, cuts, distribute points in different subgrids for faster and easier treatment/display later
        local gridElev, gridDig, gridGround= copy(minmax,1),copy(minmax,1),copy(minmax,1)
        local gridElevZ, gridDigZ, gridGroundZ = copy(minmax,2),copy(minmax,2),copy(minmax,2)
        local gridCut,cutX,cutZ =  copy(minmax,1,2),{},{}
        gridCut.ln=0
        local gridTrans,gridTransZ = copy(minmax,1),copy(minmax,2)
        local gridEndslope, endSlope =copy(minmax,1,2),{ln=0}

        -- set subgrids behaviour, they will create new tables if non existent, updating minmaxes, faster than checking in UpdateGrid function
        setmetatable(grid,nil)


        setmetatable(gridElev,registerX)
        setmetatable(gridDig,registerX)
        setmetatable(gridGround,registerX)
        setmetatable(gridCut,registerX)
        setmetatable(gridTrans,registerX)
        setmetatable(gridEndslope,registerX)

        setmetatable(gridElevZ,registerZ)
        setmetatable(gridDigZ,registerZ)
        setmetatable(gridGroundZ,registerZ)
        setmetatable(gridTransZ,registerZ)
        --
        local function UpdateGrid(point,add,addEnd,elev,slope) -- generic function for point registering
            local x,z
            if point.offset then -- get back the original x,z in case of offset, for correct registration of subgrid, using the prop instead of offx/offz for less work I guess
                x,z = unpack(point.offset)
            else
                x,z = point[1],point[3]
            end
            if add then
                local grid,gridZ
                if add=='elev' then
                    if elev==-1 then
                        grid,gridZ = gridElev,gridElevZ
                    else
                        grid,gridZ = gridDig,gridDigZ
                    end
                elseif add=='ground' then
                    grid,gridZ = gridGround,gridGroundZ
                elseif add=='trans' then
                    gotTrans=true
                    grid,gridZ=gridTrans,gridTransZ
                end
                --register -- trigger metatable behaviour if needed
                grid[x][z]=point
                gridZ[z][x]=point
                --
            end
            if addEnd then
                if point.endslope then
                    if point.endslope==-elev then point.endslope=0 --[[point.trans=true point.mark=true--]] end
                else
                    point.endslope = elev

                    --register
                    if elev==1 then
                        maxDig=max(maxDig,point[2])
                    elseif elev==-1 then
                        minElev=min(minElev,point[2])
                    end
                    gridEndslope[x][z]=point
                    if z<gridEndslope.minz then gridEndslope.minz=z elseif z>gridEndslope.maxz then gridEndslope.maxz=z end
                    --
                    endSlope.ln=endSlope.ln+1
                    endSlope[endSlope.ln]=point
                    if slope then cost=cost+slope/2 end

                end
                if gotDig and point.limit and  point.endslope and point.gy>=point[2] then 
                    gridCut.ln=gridCut.ln+1
                    gridCut[x][z]=point
                    if z<gridCut.minz then gridCut.minz=z elseif z>gridCut.maxz then gridCut.maxz=z end
                    --
                end
            end
        end
        local maxDigHeight
        local minDigHeight
        -- put endslope on the footprint border if there's no need of terra
        if not gotElev and not gotDig then
             for p,point in ipairs(footPrint) do if not point.slope or point.limit then UpdateGrid(point,nil,'addEnd',2) end end
        elseif gotDig then
            maxDigHeight=spGetGroundHeight(bx,bz)
            minDigHeight=by
        end
        --
        grid.minx, grid.maxx, grid.minz, grid.maxz = max((bx-bw+inc),0), min((bx+bw-inc),maxx), max((bz-bh+inc),0), min((bz+bh-inc),maxz)

        if isoff then -- change the min maxes of the main grid in case of offset (increment==32 and odd placement) for a correct iteration
            grid.minx=offx[grid.minx] or grid.minx
            grid.maxx=offx[grid.maxx] or grid.maxx
            grid.minz=offz[grid.minz] or grid.minz
            grid.maxz=offz[grid.maxz] or grid.maxz
        end

        -- iterate through the whole grid, to create subgrids of endslope, ground, elevation, transition, cuts...
        local leftcol,col={}
        for x=grid.minx, grid.maxx,inc do

            col=grid[x]

            local point,left,upleft
            local up 
            for z=grid.minz, grid.maxz,inc do
                point = col[z]
                left = leftcol[z]
                if point.offset then -- in case of inc=32 fixing height that's been defined wrongly (slope calculated with 32 increment instead of 16 for respecting limit of the map, we average the height with its neighbour )
                    local gx,neighbour
                    gx = grid[ neighbourx[x] ] or grid[x]
                    neighbour= gx[neighbourz[z]] or gx[z]
                    point[2]=(point[2]+neighbour[2])/2
                end
                if needTerra then 
                    if point.slope then
                        if point.limit then
                            UpdateGrid(point,nil,'addEnd',point.elev)
                        end
                        local elev = point.elev
                        if left and not left.slope then -- <- endslope
                            UpdateGrid(left,'elev','addEnd',elev,point.slope)
                        end 
                        if up and not up.slope then -- <- endslope
                            UpdateGrid(up,'elev','addEnd',elev,point.slope)
                        end
                        -- elev/dig
                        UpdateGrid(point,'elev',nil,elev)
                    else
                        local slope = up and up.slope or left and left.slope
                        if slope then -- <- endslope 
                            local elev = up and up.elev or left and left.elev
                            UpdateGrid(point,'elev','addEnd',elev,slope)
                        end
                        -- ground
                        if not point.inner and not point.elev then UpdateGrid(point,'ground') end
                    end

                    -- register the transition zone between elevation and dig
                    if gotDig then
                        local pelev = point.elev or point.endslope
                        if pelev==1 then
                            maxDigHeight=max(maxDigHeight,point.gy)
                            minDigHeight=min(minDigHeight,point[2])
                        end
                        if gotElev then
                            local lelev = left and (left.elev or left.endslope)
                            local upelev = up and (up.elev or up.endslope)
                            local upleftelev = upleft and (upleft.elev or upleft.endslope)

                            if pelev then
                                if upelev and pelev==-upelev then
                                    UpdateGrid(point,'trans') UpdateGrid(up,'trans')
                                    --UpdateGrid(point,'elev',nil,-1) UpdateGrid(up,'elev',nil,-1)
                                    --UpdateGrid(point,'elev',nil,1) UpdateGrid(up,'elev',nil,1)
                                end
                                if lelev and pelev==-lelev then
                                    UpdateGrid(point,'trans') UpdateGrid(left,'trans')
                                    --UpdateGrid(point,'elev',nil,-1) UpdateGrid(left,'elev',nil,-1)
                                    --UpdateGrid(point,'elev',nil,1) UpdateGrid(left,'elev',nil,1)

                                end
                            end
                            if upleftelev and upelev and upleftelev==-upelev then
                                UpdateGrid(upleft,'trans') UpdateGrid(up,'trans')
                                --UpdateGrid(upleft,'elev',nil,-1) UpdateGrid(up,'elev',nil,-1)
                                --UpdateGrid(upleft,'elev',nil,1) UpdateGrid(up,'elev',nil,1)
                            end
                            if upleft then
                                if upleft.endslope==0 then
                                    
                                    UpdateGrid(upleft,'trans') 
                                    --UpdateGrid(upleft,'elev',nil,-1)
                                    --UpdateGrid(upleft,'elev',nil,1)
                                elseif  left and left.endslope and upleft.endslope and left.endslope==-upleft.endslope then
                                    UpdateGrid(upleft,'trans') UpdateGrid(left,'trans')
                                    --UpdateGrid(upleft,'elev',nil,-1) UpdateGrid(left,'elev',nil,-1)
                                    --UpdateGrid(upleft,'elev',nil,1) UpdateGrid(left,'elev',nil,1)
                                end
                            end
                        end
                    end
                else
                    if not point.inner then UpdateGrid(point,'ground') end
                end
                up=point
                upleft=left
            end
            leftcol=col
        end

        -- removing metatables
        setmetatable(gridElev,nil)
        setmetatable(gridDig,nil)
        setmetatable(gridGround,nil)
        setmetatable(gridCut,nil)
        setmetatable(gridTrans,nil)
        setmetatable(gridEndslope,nil)

        setmetatable(gridElevZ,nil)
        setmetatable(gridDigZ,nil)
        setmetatable(gridGroundZ,nil)
        setmetatable(gridTransZ,nil)

        for x=grid.minx, grid.maxx,inc do
            col=grid[x]
            local point
            for z=grid.minz, grid.maxz,inc do
                point = col[z]
                
            end
        end

        gridElev.minz,gridElev.maxz = gridElevZ.minz,gridElevZ.maxz
        gridDig.minz,gridDig.maxz = gridDigZ.minz,gridDigZ.maxz
        gridGround.minz,gridGround.maxz = gridGroundZ.minz,gridGroundZ.maxz
        gridTrans.minz,gridTrans.maxz = gridTransZ.minz,gridTransZ.maxz

        -- rearrange cut edge slope, those cuts are limit points under the ground, we register them separately for drawing them forcefully
        local allcuts,acln={},0
        if gridCut.ln>0 then
            local cutX,cutZ,cxln,czln ={},{},0,0
            local startx,startz
            for x=gridCut.minx,gridCut.maxx,inc do
                if gridCut[x] then
                    for z=gridCut.minz,gridCut.maxz,inc do
                        local point = gridCut[x][z]
                        if point then
                            if not startz then startz = (x==0 or x==maxx or offsetX and (offx[x]==0 or offx[x]==maxx)) and x end
                            if startz==x then cxln=cxln+1; cutX[cxln]=point end
                            if not startx then startx = (z==0 or z==maxz or offsetZ and (offz[z]==0 or offz[z]==maxz)) and z end
                            if startx==z then czln=czln+1; cutZ[czln]=point end
                        end
                    end
                end
            end

            local prev=-100
            local cln,cut=0
            for p,point in ipairs(cutX) do
                local z = point[3]
                if abs(z-prev)>inc then -- new separate line
                    acln=acln+1; allcuts[acln]={}; cln=0; cut=allcuts[acln]
                end
                cln=cln+1; cut[cln]=point
                prev=z
            end
            for p,point in ipairs(cutZ) do
                local x = point[1]
                if abs(x-prev)>inc then -- new separate line
                    acln=acln+1; allcuts[acln]={}; cln=0; cut=allcuts[acln]
                end
                cln=cln+1; cut[cln]=point
                prev=x
            end
        end
        endSlope.allcuts=allcuts


        local allpoints = (bw/inc)*(bh/inc)*4

        --Echo("allpoints is ", allpoints)

        --[[Echo('pass1:', (chkpass1()/allpoints)*100000, '('..chkpass1()..')' )
        Echo('pass2:', (chkpass2()/allpoints)*100000, '('..chkpass2()..')' )
        Echo('pass3:', (chkpass3()/allpoints)*100000, '('..chkpass3()..')' )
        --]]

        -- finalizing: keep only main slope, removing any other, elevate ditch, add cost
            --[[for b,layer in ipairs(layers) do
            if b>lastslope then break end
            for p,point in ipairs(layer) do
                if point.slope then 
                    if not point.main then
                        point.slope=nil; point[2]=point.gy
                        Echo('removed')
                    else 
                        point.main=nil
                        --lastslope=b
                        cost=cost+point.slope
                    end
                end
                -- filling ditch
                if not point.slope and point.elev==-1 then
                    local smaller=point.smaller
                    if smaller and smaller.slope and #smaller.cardinal~=2  then
                        local smsm = smaller.smaller
                        if smsm then
                            local inheight,midheight,endheight=smsm[2], smaller[2],point[2]
                            if endheight>midheight and midheight<inheight then 
                                local diff = midheight-((inheight+endheight)/2)
                                smaller[2]= midheight+diff
                                smaller.slope = smaller.slope+diff
                                cost=cost+diff
                            end
                        end

                    end
                end
            end
        end--]]
        grid.numborders=num
        layers.grid = grid

        if gotDig then layers.gridDig,layers.gridDigZ = gridDig,gridDigZ end
        if gotElev then layers.gridElev,layers.gridElevZ = gridElev,gridElevZ end
        if gotTrans then layers.gridTrans,layers.gridTransZ = gridTrans,gridTransZ end

        layers.gridGround, layers.gridCut=  gridGround, gridCut
        layers.gridGroundZ = gridGroundZ
        
        layers.endSlope, layers.gridEndslope  = endSlope, gridEndslope
        layers.lastslope = lastslope
        layers.endSlopeStart = endSlopeStart
        cost=((innercost + cost*incmult^2)/133.3)
        layers.cost=round(cost)
        layers.footPrint=footPrint
        layers.maxElevSlope = maxElevSlope
        layers.maxDigSlope = maxDigSlope
        layers.maxDigHeight = maxDigHeight
        layers.minDigHeight = minDigHeight
        layers.bw,layers.bh = bw,bh
        layers.needTerra = needTerra
        
        layers.gotElev = gotElev
        layers.gotDig = gotDig
        layers.gotTrans = gotTrans


        --chk('say')
        ----

        return layers
    end
end

local GetSlopeContour
do
    local function Rotate(pat)
        local T,ln={},0
        for i=1,#pat do local dir=pat[i]; ln=ln+1; T[ln]={dir[1],dir[2]} end
        table.insert(T,1,table.remove(T,8))
        return T
    end
    local patnum={ 'NW','N','NE','E','SE','S','SW' }
    -- table converting cardinal for point of footprint or limits
    local b1pat = {['NW']='W', ['N']='W', ['NE']='N',['E']='N',['SE']='E',['S']='E',['SW']='S',['W']='S'}

    GetSlopeContour = function(layers)
        local inc = inc
        local ln=0
        local contour={}

        local wbcount,blcount = 0,0
        local startpoint,ns = {},0
        local endSlope = layers.endSlope

        local point
        local function GetNewStart()
        -- define a starting point
            for p,point in pairs(contour) do --[[point.mark=nil;--]] point.passed=false; point.choice=0; point.contour=nil ; contour[p] = nil end
            ns=ns+1;point=endSlope[ns]
            while point and point.fork do 
                ns=ns+1
                point=endSlope[ns]
            end
            startpoint=point
            ln=1;contour[1]=point

            return point
        end
        local function Walkback() -- rollback points that come to a dead end until we find a fork, or to a certain point when in a bad loop
            wbcount=wbcount+1
            point.passed=false; point.choice=0; point.contour=false;
            contour[ln]=nil; ln=ln-1;
            point=contour[ln];
            return point
        end

        -- connect points to each other
        -- create pattern of research to prefer first choices depending on cardinal prop (this will search the point closest to center first)
        local patterns={}
        local pat = { {inc,0},{inc,-inc},{0,-inc},{-inc,-inc},{-inc,0},{-inc,inc},{0,inc},{inc,inc} }
        patterns.W=pat

        for i=1,7 do
            pat = Rotate(pat)
            patterns[ patnum[i] ] = pat
        end

        local orthopat ={ {0,inc},{inc, 0},{0,-inc},{-inc,0}, {inc,inc},{inc,-inc},{-inc,-inc},{-inc,inc} }

        local grid = layers.gridEndslope
        local minx,maxx,minz,maxz = grid.minx,grid.maxx,grid.minz,grid.maxz

        for e=1,endSlope.ln do
            local point = endSlope[e]
            point.connected={}; point.choice=0; point.maxchoice=0
            local connected=point.connected
            local x,z
            if point.offset then
                x,z = point.offset[1],point.offset[2]
            else 
                x,z = point[1],point[3]
            end
            local p=1
            local pattern = point.b1 and patterns[ b1pat[point.cardinal] ] or point.limit and orthopat or patterns[point.cardinal]
            while p<9 do
                local ix,iz = unpack(pattern[p])
                local endslx=grid[x+ix]
                if endslx then
                    local conpoint=endslx[z+iz]
                    if conpoint then
                        if conpoint.limit and not point.limit and pattern~=orthopat then
                            pattern=orthopat; p=0
                        else
                            point.maxchoice=point.maxchoice+1
                            connected[point.maxchoice]=conpoint
                        end
                    end
                end
                p=p+1
            end
            point.fork = point.maxchoice>2
        end
        if not GetNewStart() then return {} end
        --
        local try=0
        point=startpoint

        local tries=0
        local completed=false
        local count=0
        while not completed do -- link all point in order
            local found
            if ln>6 then startpoint.passed=false end
            while not found do
                if point.choice+1>point.maxchoice then break end
                point.choice = point.choice+1
                found = point.connected[point.choice]
                found = not found.passed and found
            end
            ----------- walkback and choose another path if the trail cannot be continued
            if not found then
                while Walkback() and not point.fork do count=count+1 end
                tries=tries+1
                if (not point or tries>(300*ns)) and not GetNewStart() then break end
            else
                point=found; point.passed=true
                point.contour=true; ln=ln+1; contour[ln]=point
                -- fixing badloop
                if point==startpoint and ln>7 then
                    if ln*2<endSlope.ln then
                        if not GetNewStart() then break end
                    else
                        -- fixing bad loops if any --(obsolete)
                        --[[local step1,step2, step3
                        local ii
                        local c,cln=0,#contour
                        local point
                        local crem=0

                        while c<cln do
                            c=c+1; point=contour[c]
                            if step2  then
                                local x,z=point[1], point[3]
                                if step3 and abs(x-step3[1])<=inc and abs(z-step3[3])<=inc then
                                    for i=1,3 do table.remove(contour, c-3) crem=crem+1 end
                                    c,cln=c-3,cln-3
                                    step1,step2 = contour[c-1],contour[c-2]
                                elseif abs(x-step2[1])<=inc and abs(z-step2[3])<=inc then
                                    for i=1,2 do  table.remove(contour, c-2) crem=crem+1 end
                                    c,cln=c-2,cln-2
                                    step1,step2 = contour[c-1],contour[c-2]
                                end
                            end
                            step3=step2
                            step2=step1
                            step1=point
                        end
                        Echo("crem is ", crem)--]]
                        --[[c=c+1
                        contour[c]=contour[1]--]]
                        --[[for p,point in ipairs(endSlope) do
                            if not point.contour then
                                point.elev=point.endslope; point.endslope=nil; endSlope[p]=nil
                            end
                        end--]]
                        return contour
                    end
                end
            end
            ------------
        end
        Echo('empty returned')
        return {}
    end
end

local function AddAlpha_new_square(layers,numborders,maxalpha)
    local alphainc = maxalpha/numborders
    local ggrid,ggridZ = layers.gridGround,layers.gridGroundZ
    local minx,maxx,minz,maxz = ggrid.minx,ggrid.maxx,ggrid.minz,ggrid.maxz
    local ending
    -- local pass=0
    local midstep = numborders/2
    local function AddAlphaSide(Z,amin,amax,bmin,bmax,incb,secondPass)
        local grid,othergrid
        if Z then grid,othergrid = ggridZ,ggrid
        else grid,othergrid = ggrid,ggridZ
        end
        local point
        local ga
        local step
        local prevstep
        for a=amin,amax,inc do
            local prevalpha
            local step
            local prevstep
            local incstep=1
            local maxstep=numborders
            local newstep
            local incnewstep
            ga=grid[a]
            if ga then
                for b=bmin,bmax,incb do
                    point=ga[b]
                    if point then
                        if point.endslope and not secondPass then
                            step=numborders
                        elseif not step and secondPass then
                            if prevstep then 
                                if not point.step then
                                    incnewstep=0.1+(prevstep/maxstep)
                                    newstep=prevstep
                                elseif prevstep>point.step then 
                                    point.step=prevstep
                                    point.alpha=maxalpha-(1-(prevstep/maxstep))^4
                                end
                            end
                        end
                        if ending and point.alpha and point.alpha<0.1 then grid[a][b]=nil; othergrid[b][a]=nil end
                        prevalpha=point.alpha
                        if step then
                            point.step=step
                            point.alpha=maxalpha-(1-(step/maxstep))^4
                            step=step - incstep
                        end
                        if newstep then
                            newstep=newstep-incnewstep
                            point.alpha=maxalpha-(1-(newstep/maxstep))^4
                            if newstep<0 then newstep=false end
                        end
                        prevstep=point.step
                    end
                end
            end
        end
    end
    -- pass=1
    AddAlphaSide(false,minx,maxx,minz,maxz,inc) -- top to bottom
    -- pass=2
    AddAlphaSide(false,minx,maxx,maxz,minz,-inc)  -- bottom to top 
    AddAlphaSide(true,minz,maxz,minx,maxx,inc,true)  -- left to right
    ending=true-- point with less than 0.1 alpha will get removed from tables
    AddAlphaSide(true,minz,maxz,maxx,minx,-inc,true) -- right to left
end

local function AddAlpha_round(layers,numborders,maxalpha)
    local alphainc = maxalpha/numborders
    local ggrid,ggridZ = layers.gridGround,layers.gridGroundZ
    local bigGrid=layers.grid
    local minx,maxx,minz,maxz = ggrid.minx,ggrid.maxx,ggrid.minz,ggrid.maxz
    local ending
    local pass=0
    local midstep = numborders/2
    local maxstep=numborders
     local function AddAlphaSide(Z,amin,amax,bmin,bmax,incb,secondPass)
        local grid,othergrid
        if Z then grid,othergrid = ggridZ,ggrid
        else grid,othergrid = ggrid,ggridZ
        end
        local point
        local ga
        for a=amin,amax,inc do
            local step
            local prevstep
            local incstep=1
            ga=grid[a]
            if ga then
                for b=bmin,bmax,incb do
                    point=ga[b]
                    if point then
                        if point.endslope and not secondPass then
                            step=numborders
                        elseif not step and secondPass then
                            if prevstep then 
                                if not point.step then
                                    local h = (maxstep-prevstep)
                                    local w = sqrt(maxstep^2 - h^2)
                                    incstep=prevstep/w
                                    step=prevstep-incstep
                                elseif prevstep>point.step then 
                                    point.step=(point.step+prevstep*2)/3
                                    point.alpha=maxalpha-(1-(prevstep/maxstep))^4
                                end
                            end
                        end
                        if step then
                            if step<0.05 then
                                step=false
                            else
                                point.step = step
                                point.alpha=maxalpha-(1-(step/maxstep))^4
                                step = step - incstep
                            end
                        end
                        if ending and (not point.step or point.alpha and point.alpha<0.1) then grid[a][b]=nil; othergrid[b][a]=nil --[[ if Z then bigGrid[b][a]=nil else bigGrid[a][b]=nil end--]] end
                        prevstep=point.step
                    end
                end
            end
        end
    end
    AddAlphaSide(false,minx,maxx,minz,maxz,inc) -- top to bottom
    AddAlphaSide(false,minx,maxx,maxz,minz,-inc)  -- bottom to top 
    AddAlphaSide(true,minz,maxz,minx,maxx,inc,true)  -- left to right
    ending=true-- point with less than 0.1 alpha will get removed from tables
    AddAlphaSide(true,minz,maxz,maxx,minx,-inc,true) -- right to left
end
addAlpha['AddAlpha_round']=AddAlpha_round

local function AddAlpha_square(layers,numborders,maxalpha)
    local alphainc=1/numborders
    --
    -- local chk=CheckTime('start')
    --
    local grid,gridZ = layers.gridGround,layers.gridGroundZ
    local minx,maxx,minz,maxz = grid.minx,grid.maxx,grid.minz,grid.maxz
    local ending
    local gx
    local length=(maxz-minz)/inc
    local mid=(maxz+minz)/2
    local endal=length/10
    local incal=maxalpha/endal
    local val
    local function AddAlphaSide(Z,amin,amax,bmin,bmax,incb,secondPass)
        local grid = Z and gridZ or grid
        local ga,point
        for a=amin,amax,inc do
            ga=grid[a]
            val=-incal
            if ga then
                for b=bmin,bmax,incb do
                    if val<maxalpha then
                        val=val+incal
                        if val>maxalpha then break end
                    else
                        break
                    end
                    point=ga[b]
                    if point then
                        if secondPass and point.alpha then
                            point.alpha=min(point.alpha,min(val,(val*1.5)*point.alpha))
                        else
                            point.alpha=val
                        end
                   end
                end
            end
        end
    end
    AddAlphaSide(false,minx,maxx,minz,maxz,inc) -- top to bottom
    AddAlphaSide(false,minx,maxx,maxz,minz,-inc) -- bottom to top 
    length=(maxx-minx)/inc
    mid=(maxx+minx)/2
    endal=length/10
    incal=maxalpha/endal
    AddAlphaSide(true,minz,maxz,minx,maxx,inc,true)  -- left to right
    ending=true
    AddAlphaSide(true,minz,maxz,maxx,minx,-inc,true) -- right to left
end

addAlpha['AddAlpha_square']=AddAlpha_square
AddAlpha=AddAlpha_round

local CreateSlopeFaces
do
    local cam,flipped,midx
    local function Pass(grid,out,minx,maxx,incx,minz,maxz,incz)
        local oln=out.ln
        local group,gln

        local prevlane=grid[minx]
        for x=minx+incx,maxx,incx do
            local continued,suspended,prevendslope
            local lane=grid[x]
            local point,left,prev,prevleft
            local allends=0
            --local filter=function()return --[[oln==2 and grid==layers.gridTrans and gln<3--]] end
            --[[local filter2=function()return oln==2 and grid==layers.gridTrans and left and point end
            local filter3=function()return true end
            local filter4=function()return oln==1 and grid==layers.gridElev end
            local filter5=function()return  end--]]

            if lane and prevlane then
                for z=minz,maxz,incz do
                    local curends=0
                    left,point=prevlane[z],lane[z]
                    if point and point.endslope then curends=curends+1 end
                    if left and left.endslope then curends=curends+1 end
                    allends=allends+curends
                    --if point and point.limit and allends==3 then point.mark=true end
                    if not continued and point and left then
                        if allends<3 then
                            oln=oln+1; out[oln]={};gln=0; group=out[oln]; continued=true
                            if prev --[[and prev.endslope--]] then gln=gln+1; group[gln]=prev --[[if filter5() then prev.mark=true end--]] end
                            if prevleft --[[and prevleft.endslope--]] then gln=gln+1; group[gln]=prevleft --[[if filter5() then prevleft.mark=true end--]] end
                        end
                    end
                    if continued then
                        if allends<3 or point and point.limit then 
                            if point then gln=gln+1; group[gln]=point --[[if filter5() then point.mark=true end--]] end
                            if left then gln=gln+1; group[gln]=left --[[if filter5() then left.mark=true end--]] end
                        end
                    end
                    if continued and not left or not point then continued=false end
                    prev,prevleft = point,left
                    allends=curends
                end
            end
            prevlane=lane
        end
        out.ln=oln

    end
    local function PassFaces(grid,faces)
        if inc==32 and midx%32~=grid.minx%32 then midx=midx-16 end
        local minx,maxx,minz,maxz = grid.minx,grid.maxx,grid.minz,grid.maxz
        if midx<minx then midx=minx elseif midx>maxx then midx=maxx end
        if flipped then
            Pass(grid,faces,midx,maxx,inc,minz,maxz,inc,midx)
            Pass(grid,faces,midx,minx,-inc,minz,maxz,inc,midx)
        else
            Pass(grid,faces,midx,maxx,inc,maxz,minz,-inc,midx)
            Pass(grid,faces,midx,minx,-inc,maxz,minz,-inc,midx)        
        end
    end
    -- Main function
    CreateSlopeFaces = function (layers,gotElev,gotDig,gotTrans)-- TODO:need to check non-working face in very rare case
        -- create table of multiples subtable that consitute vertical lane to be used as mask with triangle fan method.
        -- they are arranged in order that they won't glitch overlap and lessen the transparency 
        local chk=CheckTime('start')
        local facesElev,facesDig,facesTrans

        -- found a workaround to avoid some triangle fan strips to overlap and increase unwantingly alpha values... CANDO: cleaner method
        cam = spGetCameraState()
        flipped = (cam.flipped or -1)==1
        midx=cam.px-cam.px%16
        if gotElev then
            facesElev={ln=0}
            PassFaces(layers.gridElev, facesElev)
        end


        if gotDig then
           facesDig={ln=0}
           PassFaces(layers.gridDig, facesDig)
        end

        if gotTrans then
           facesTrans={ln=0}
           PassFaces(layers.gridTrans, facesTrans )
        end

        --return {gotElev, gotDig, gotTrans}
        --chk('pause', 'Create SlopeFaces')
        layers.slopeFaces={facesElev,facesDig,facesTrans}
    end
end

local function PairBorders(layers)-- pair layers points from each other to prepare vertices for grid drawing
    for b=1,#layers-1 do 
        local biggerB = layers[b+1]
        biggerB.paired={}
        local bln=0
        local lnc=0
        local maxbln=#biggerB
        local bln=-1
        for i,point in ipairs(layers[b]) do
            local corner = #point.cardinal==2
            local bpoints=point.bigger
            local bpoint
            local numpoints=corner and 3 or 1
            for p=1,numpoints do
                bpoint=bpoints[p]
                bln=bln+1
                if p~=2 then 
                    biggerB.paired[ bln==0 and maxbln or bln ]=point
                end
            end
        end
    end
end

local function ElevAndDiggingPairs(gPs,elevPs) -- discern points that will draw elevation from digging, because I will want to mask only points that are behind the terrain if they are under the construction
    local elev,dig = {gp={},lvl={}},{gp={},lvl={}}
    local lne,lnd=0,0
    for i,point in ipairs(gPs) do
        if point[2]<=elevPs[i][2] then
            lne=lne+1
            elev.gp[lne]=point
            elev.lvl[lne]=elevPs[i]
        else
            lnd=lnd+1
            dig.gp[lnd]=point
            dig.lvl[lnd]=elevPs[i]
        end
    end
    return elev,dig
end

local function FlatRect(bx,by,bz,bw,bh)
    local T = 
    {
        {bx-bw,by,bz-bh,'NW'},
        {bx+bw,by,bz-bh,'NE'},
        {bx+bw,by,bz+bh,'SE'},
        {bx-bw,by,bz+bh,'SW'},
    }
    T.corners=T
    return T
end

local function SetHiddenFaces(layer,by)
    local bytable= type(by)=='table'
    local cam = spGetCameraState()
    local flipped= (cam.flipped or -1)==1
    local camx=cam.px
    local hidden
    local hiddenln=0
    local a,gy,b,cardinal
    local mask
    layer.maskln=0
    local point
    for i=1,#layer do
        hidden,mask=false,false
        point = layer[i]
        a,gy,b=unpack(point)
        cardinal=point.cardinal
        --positive elevation
        if flipped then  
            hidden = cardinal=="S" or 
                    (cardinal=="W" or cardinal=="SW") and a<camx or 
                    (cardinal=="E" or cardinal=="SE") and a>camx
        else
            hidden = cardinal=="N" or
                    (cardinal=="E" or cardinal=="NE") and a>camx or
                    (cardinal=="W" or cardinal=="NW") and a<camx
        end
        point.mask= not hidden -- noting point used for mask
        if #cardinal==2 and not hidden then layer.maskln=layer.maskln+1 end
        if bytable and gy>by[i] or gy>by then -- if negative elevation -- reversing hidden except for a corner
            if #cardinal==1 then
                hidden = not hidden
            elseif #cardinal==2 then
                if flipped then 
                    hidden = cardinal=="NW" and a>camx or 
                             cardinal=="NE" and a<camx
                else
                    hidden = cardinal=="SW" and a>camx or 
                             cardinal=="SE" and a<camx
                end
            end
        end
        if hidden and #cardinal==2 then hiddenln=hiddenln+1 end
        point.hidden=hidden
    end
    layer.hiddenln=hiddenln
end

local function CreateElevationMask(gPs, by) -- gather unhidden point of the ground rectangle along with elevation rectangle corner
    local cam = spGetCameraState()
    local camx = cam.px
    local flipped= (cam.flipped or -1)==1
    local mask,ln,lnh={},0,0
    local a,gy,b
    local lnh = gPs.hiddenln
    local onLeft=gPs[1][1]<camx

    -- gathering elevation top corners points in the right order

    if lnh==1 and onLeft or lnh==2 then -- for beeing at left or middle of the screen (or vice versa in flipped)
        mask[flipped and 3 or 1]={gPs.corners[4][1], by, gPs.corners[4][3]}
        mask[         2        ]={gPs.corners[1][1], by, gPs.corners[1][3]}
        mask[flipped and 1 or 3]={gPs.corners[2][1], by, gPs.corners[2][3]}
        ln=3
    else -- on the right
        for i=1,3 do
            ln=ln+1
            a,_,b=unpack(gPs.corners[i])
            mask[i]={a,by,b}
        end
    end
    if lnh==2 then -- on the middle
        mask[4]={gPs.corners[flipped and 4 or 3][1], by, gPs.corners[flipped and 4 or 3][3]}
        ln=4
    end

    -- adding non hidden base ground point in the right order
    local start=(onLeft or lnh==2) and 1 or 2 -- skipping NW point if volume is at right of the screen
    for i=start,#gPs  do
        local point=gPs[i]
        a,gy,b,cardinal=unpack(point)
        if gy<by and not point.hidden then
            ln=ln+1
            mask[ln]={a,gy,b}
        end
    end
    if start==2 then mask[ln+1]={gPs[1][1],gPs[1][2],gPs[1][3]} end -- putting the missing NW point last, if at right of the screen
    return mask
end

-- create faces points to use as mask for vertical elevation display
local function ElevationFaces(gPs, by,elevPs) -- gather unhidden points of the ground rectangle along with elevation rectangle corner, and creates 2 or 3 faces used for masking
    local faces,lnf,f={},0,false,1
    local cam = spGetCameraState()
    local camx = cam.px
    local flipped= (cam.flipped or -1)==1
    local mask,ln,lnm={},0,0
    local a,gy,b
    local lnm = gPs.maskln
    local onLeft=gPs[1][1]<camx
    local top,lnt={},0
    local start,ending = 1,#gPs
    local discontinued=flipped and lnm==3 and not onLeft
    if  lnm==3 and not onLeft then
        if not flipped then start=2 end -- will start after NW corner
        ending=ending+1 -- will end at NW corner in 2 cases
    end
    for i=start,ending do
        if i==ending and lnm==3 and not onLeft then i=1 end
        local point=gPs[i]
        if point.mask then
            local a,y,b = unpack(point)
            cardinal=point.cardinal
            if y<by then
                lnf=lnf+1
                if #cardinal==2 then --(corner)
                    --Echo(cardinal)
                    local start,finish
                    if not f then start,f=true,1  --starting first face
                    elseif discontinued then
                        if f==1 or discontinued=='started' then finish=true --finish face: first to second corner or fourth to first
                        elseif f==2 then start=true ; discontinued='started' -- found new unhidden corner after finishing the first
                        end
                    else
                        finish,start = true,true --finishing face and starting the next
                    end 
                    if finish then
                        faces[f][lnf]={a,y,b}
                        faces[f][lnf+1]={elevPs[i][1], elevPs[i][2], elevPs[i][3]}-- finishing the face
                        if f==2 or f==1 and lnm==2 then break end -- stopping if 2 faces done or 1 face and volume is centered on screen (only one visible face)                     
                        f=f+1
                    end
                    if start then
                        lnf=1
                        faces[f]={}
                        faces[f][lnf]={elevPs[i][1], elevPs[i][2], elevPs[i][3]}
                        lnf=lnf+1
                        faces[f][lnf]={a,y,b}
                    end
                else 
                    if not f then f=1 end -- in case the face start in the middle of a segment
                    if not faces[f] then faces[f]={} end
                    faces[f][lnf]={a,y,b}
                end
            end
        end
    end
    f=f and f+1 or 1
    faces[f]={}
    for i,point in ipairs(gPs.corners) do
        faces[f][i]={point[1],by,point[3]}
    end
    return faces
end




----- DRAWING FUNCTIONS

local DrawGrid
do
    local color, forcealpha,groundAboveDig,ground
    local function lines(grid, mina,maxa,minb,maxb)
        local c1,c2,c3,c4=unpack(color)
        --[[if AddAlpha == addAlpha['AddAlpha_round'] then
            c4=0 --*** temporary
        end--]]
        for a=mina,maxa,inc do
            local grida=grid[a]
            if grida then
                local b=minb
                local point,alpha
                while b<=maxb do
                    point=grida[b]
                    if point then
                        local function verts()
                            while point do
                                if groundAboveDig then 
                                    glColor(c1,c2,c3,c4)
                                    glVertex(point[1],point.gy,point[3])
                                elseif ground then
                                    glColor(c1,c2,c3,point.alpha or c4)
                                    glVertex(unpack(point))
                                else
                                    glColor(c1,c2,c3,c4)
                                    glVertex(unpack(point))
                                end
                                b=b+inc
                                point=grida[b]
                            end
                        end
                        glBeginEnd(GL_LINE_STRIP, verts)
                    end
                    b=b+inc
                end
            end
        end
    end
    DrawGrid =  function (grid,gridZ,col,falpha,grndAboveDig,grnd)
        color,forcealpha,groundAboveDig,ground = col,falpha,grndAboveDig,grnd
        local minx,maxx,minz,maxz=grid.minx,grid.maxx,grid.minz,grid.maxz
        lines(grid,minx,maxx,minz,maxz)
        lines(gridZ,minz,maxz,minx,maxx)
    end
end


local function DrawBorderPairs(border,alpha,slope)
    local elevC = slope and s_elev_color or {0,    0,    1,    alpha}
    local transElevC = {0,    0.35, 0.85, alpha}
    local gridC = slope and s_ground_color or {0,    0.7,  0.7,  alpha}
    local transDigC  = {0.25, 0.35, 0.6,  alpha}
    --local digC       = {0.5,  0,    0.5,  alpha}
    local digC       = {0.8,  0.5,    0.6,  alpha}

    for i=1,#border do
        local pair=border.paired[i]
        local point = border[i]
        if pair then
        --[[if point.hidden then glColor({0,0,0,0})
        --elseif point.mark then glColor({1,0,1,1})
        else--]]if point.out then glColor({0,0,0,0})
            elseif point.endslope then
                --glColor(point.elev==1 and transDigC or transElevC)
                --glColor(point.elev==1 and digC or elevC)
                --glColor({1,1,1,1})
            elseif point.slope then
                glColor(point.elev==1 and digC or elevC)
            else 
                --glColor(gridC[1],gridC[2],gridC[3],point.alpha or 0)
                glColor(0,0,0,0)
            end
            local a,y,b = unpack(point)
            local px,py,pz = unpack(pair)
            glVertex(a, y, b)
            glVertex(px,py,pz)
        end
    end
end

local function DrawSlopeMask(face,i, ground,color,maxSlope,mark)
    local minalpha,maxalpha
    if color then 
        minalpha,maxalpha = 0.1, color[4]
    end
    if ground then 
        for p,point in ipairs(face) do
            if mark then point.mark=true end
            if slopeFading and color then
                color[4]=((point.slope or 0)/maxSlope*maxalpha)^2
                if color[4]<minalpha then color[4]=minalpha end
                glColor(color)
            end
             glVertex(point[1],point.gy,point[3])
        end
    else    
        for p,point in ipairs(face) do
            if mark then point.mark=true end
            if slopeFading and color then
                color[4]=(point.slope or 0)/maxSlope*maxalpha
                if color[4]<minalpha then color[4]=minalpha end
                glColor(color)
            end
            glVertex(point[1],point[2],point[3])
        end
    end
end

local function AddSlopeShade(faces,color,maxSlope,mark)
    
    local minalpha,maxalpha
    if color then 
        minalpha,maxalpha = 0.2, color[4]*0.6
    end

    for i=1, #faces do
        for p,point in ipairs(faces[i]) do
            if mark then point.mark=true end
            if slopeFading and color then
                point.slopeShade=(((point.slope or 0)/maxSlope)*maxalpha)
                if point.slopeShade<minalpha then point.slopeShade=minalpha end
                --point.slopeShade=0.2
                --Echo("point[2]/maxHeight is ", point[2]/maxHeight)
                --point.slopeShade=((point[2]/point.gy)*maxalpha)

                --point.slopeShade=(((point.gy-50)/maxHeight)*maxalpha)^2
            end
        end
    end
end

local function DrawSlopeShade(face,color)
    for p,point in ipairs(face) do
        color[4]=point.slopeShade or 0
        glColor(color)
        glVertex(point[1],point.gy,point[3])
    end
end

local function SimpleDrawRect(r)
    for i=1,#r+1 do
        local point =  r[i] or r[1]
        local a,y,b= unpack(point)
        glVertex(a, y, b)
    end
end

local function DrawRect(r,alpha,slope)
    local elevC = slope and s_elev_color or {0,    0,    1,    alpha}

    local transElevC = {0,    0.35, 0.85, alpha}
    -- local gridC      = {0,    0.7,  0.7,  alpha}
    local gridC      = slope and s_ground_color
                    or {0,    0.7,  0.7,  alpha}

    local transDigC  = {0.25, 0.35, 0.6,  alpha}
    --local digC       = {0.5,  0,    0.5,  alpha}
    local digC       = {0.8,  0.5,  0.6,  alpha}
    local nocolor    = {  0,    0,    0,      0}
    for i=1,#r+1 do
        local point =  r[i] or r[1]
        local x,y,z= unpack(point)
        --[[
        if point.hidden then glColor(nocolor)
        --elseif point.mark then glColor({1,0,1,1})
        else--]]if point.out then glColor(nocolor)
        elseif point.endslope then
            --glColor({1,1,1,1})
            --glColor(point.elev==1 and transDigC or transElevC)
            --glColor(point.elev==1 and digC or elevC)
        elseif point.slope then
            glColor(point.elev==1 and digC or elevC)
        else 
            --gridC[4]=point.alpha
            --glColor(gridC)
            --glColor(gridC[1],gridC[2],gridC[3],point.alpha or 0)
            glColor(nocolor)
        end
        glVertex(x, y, z)
    end
end

local function DrawBorders(layers,color,slope)
    local a,y,b,cardinal
    local numborders=#layers
    local incalpha=0.5/(numborders-1)
    local alpha=0.9
    for i=1,numborders do
        color[4]=alpha
        glColor(color)
        glBeginEnd(GL_LINES, DrawBorderPairs, layers[i], alpha, slope)-- <- cool stuff with GL_LINESTRIP instead of GL_LINES
        alpha=alpha-incalpha
        color[4]=alpha
        if i<numborders then
            glBeginEnd(GL_LINE_STRIP, DrawRect, layers[i], alpha, slope)
            glColor({1,1,0,alpha})
        end
    end
end

local function DrawFlatGrid(elevPs,bw,bh)
    for i,point in ipairs(elevPs) do
        local a,y,b,cardinal = unpack(point)
        if cardinal=='N' then
            glVertex(a,y,b)
            glVertex(a,y,b+bh)
        elseif cardinal=='E' then
            glVertex(a,y,b)
            glVertex(a-bw,y,b)
        elseif cardinal=='SE' then
            break
        end
    end
    for i=1, #elevPs.corners do
        local a,y,b=unpack(elevPs.corners[i])
        local nx,ny,nz= unpack(elevPs.corners[i+1] or elevPs.corners[1])
        glVertex(a,y,b)
        glVertex(nx,ny,nz)
    end
end

local function DrawVerticals(gPs, elevPs,hide)
    for i=1,#gPs do
        if not hide or not gPs[i].hidden then
            local a, y, b, cardinal  = unpack(gPs[i])
            local x2,y2,z2 = unpack(elevPs[i])
            glVertex(a,y,b)
            glVertex(x2,y2,z2)
        end
    end
end



--[[local function CobbleStone(bx,gy,bz,bw,bh,by)
        local base = 
        {
            {bx-bw,gy,bz-bh},--'NW'
            {bx+bw,gy,bz-bh},--'NE'
            {bx+bw,gy,bz+bh},--'SE'
            {bx-bw,gy,bz+bh},--'SW'
        }
        local top = 
        {
            {bx-bw,by,bz-bh},
            {bx+bw,by,bz-bh},
            {bx+bw,by,bz+bh},
            {bx-bw,by,bz+bh},
        }

        local faces =
        {
            {base[1],base[2],base[3],base[4]},
            {top[1],top[2],top[3],top[4]},
        }
        for i=1,3 do
            faces[i+2]={base[i],base[i+1],top[i+1],top[i]}
        end
        faces[6]={base[4],base[1],top[1],top[4]}
        return faces
    end
--]]
local function DrawStipple(grid)
    local gx,point
    local gy,x,y,z
    for x=grid.minx,grid.maxx,inc do
        gx=grid[x]
        if gx then
            for z=grid.minz,grid.maxz,inc do
                point=grid[x][z]
                if point then
                    gy,x,y,z = point.gy,unpack(point)
                    glVertex(x,gy,z)
                    glVertex(x,y,z)
                end
            end
        end
    end
end
local function DrawPoint(x,y,z)
    glVertex(x,y,z)
end
local function DrawPoints(T)
    for i=1,#T do
        glVertex(unpack(T[i]))
    end
end

local function MaskVertices(mask) 
    for i,m in ipairs(mask) do
        glVertex(unpack(m))
    end
end

--[[
    local function sujet(mask) 
        for i,m in ipairs(mask) do
            glVertex(unpack(m))
        end
    end

    local function arriereplan(mask) 
        for i,m in ipairs(mask) do
            glVertex(m[1]-40,m[2]-15,m[3]-15)
        end
    end
    local function outline(mask) 
        for i,m in ipairs(mask) do
            glVertex(m[1]-5,m[2]-5,m[3]-5)
        end
    end
--]]




local bx,by,gy,bz,bw,bh,float,pid,facing,needTerra

local hrects, layers,buildMask
local slopes

local flatrect
local elevFaces
local buildFaces
local groundGrid,groundGrid2D
local elevation,digging
local elevMask2D
local contour, endSlope
local slopeFaces
local y 
local curcount=0
local newcount
--local rectshape 
local comm
local mask
local drawWater

local timecheck=CheckTime('start')
timecheck('pause')
local heightThreshold=0
local threshold=1000

-- lists

local function reset() -- freeing memory
    layers, slopes,
    flatrect, elevFaces, buildFaces,
    groundGrid,groundGrid2D, elevation,digging, elevMask2D, contour, endSlope, slopeFaces
     =
    nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil
    y = nil
    rectshape = nil
    comm = nil
    mask = nil
    newcount= nil
    drawWater = nil
    curcount = 0
    -- Echo('reset',os.clock(),'garbage: '..collectgarbage('count'))
    -- if collectgarbage('count')>190000 then
    --     Echo('collect',os.clock())
    --     collectgarbage('collect')
    -- end
end

local function Finish()
    -- Echo('DT finishing ',os.clock())
    reset()
    --DeleteShaders()
    -- widgetHandler:RemoveCallIn("DrawWorld")
    WG.DrawTerra.finish=false
    dwOn=false
    WG.DrawTerra.working=false
    if DrawingList then glDeleteList(DrawingList) DrawingList=false end
    -- Echo('Finished',os.clock(),'garbage: '..collectgarbage('count'))
    -- collectgarbage('collect')
end


--[[ ***************   local cx, cy, cz = Spring.GetCameraDirection()
    local dir = ((math.atan2(cx, cz) / math.pi) + 1) * 180
--]]
local function OptimalBorders()-- reduce the number of layers according to starting alpha/num layers set in option
    --if groundGridMaxOpacity>1 then return numborders
    --else
        local optBorders=s_ground_color[4]/(1/(numborders))
        return optBorders>=3 and optBorders or 3
    --end
end

--local --avgdraw = CheckTime('start')
--local avgcreate = CheckTime('start')
local createRes
--avgcreate('pause')
--avgdraw('pause')

local function DrawLine(line)
    for i=1,#line do
        glVertex(unpack(line[i]))
    end
end

local function DrawRectangle(a,y,b,w,h)
    glVertex(a + w, y, b + h)
    glVertex(a + w, y, b - h)
    glVertex(a - w, y, b - h)
    glVertex(a - w, y, b + h)
    glVertex(a + w, y, b + h)
end




local function CreateBasicList(layers)
    -- it is the basic cell quality of SLOPE MODE
    local curPullShader=0
    local heightcam=GetCameraHeight(spGetCameraState())
    if heightcam<30000 then -- using different shader depending on the camera height that will more or less vertices a little to the front in order for them to be drawn instead of beeing eaten by the terrain or to separate them from another set of vertices for masking purpose
        if heightcam>3000 then
            curPullShader=overbump -- Echo('overbump')
        elseif heightcam>700 then
            curPullShader=moreoverbump--Echo("moreoverbump")
        else
            curPullShader=evenmoreoverbump--Echo("evenmoreoverbump")
        end
    end
    glDepthMask(true)
    glUseShader(pushalittle)
    glDepthTest(GL.LEQUAL)
    for i=1,#layers do
    glColor(0,0,0,0)
        local slope=layers[i]
        local shapes = slope.shapes
        for i=1,12 do
            local shape = shapes[i]
            glBeginEnd(GL_TRIANGLE_STRIP, DrawSlopeMask , shapes[i], i)
        end
    end
    glUseShader(0)
    glDepthMask(false)
    --glUseShader(curPullShader)
    glUseShader(pullalittle)
    for i=1,#layers do
        local slope=layers[i]
        if drawContour then -- display the contour at front only, masked by the landscape / static alpha
            glDepthTest(GL.LEQUAL)
            glColor(unpack(s_cont_color))
            glBeginEnd(GL_LINE_STRIP, DrawPoints, slope.contour)
            glDepthTest(false)
        end
    end
    for i=1,#layers do
        local slope=layers[i]
        local shapes = slope.shapes
        glDepthTest(GL.LEQUAL)
        local color_elev = {unpack(s_elev_color)}
        color_elev[4]=color_elev[4]/3
        local color_dig = {unpack(s_dig_color)}
        color_dig[4]=color_dig[4]/3
        
        for i=1,12 do
            local shape = shapes[i]
            if shape[1].elev==1 then glColor(color_dig) glDepthTest(GL.GEQUAL)
            else glColor(color_elev) glDepthTest(GL.LEQUAL) end
            glBeginEnd(GL_TRIANGLE_STRIP, DrawSlopeMask , shapes[i], i)
        end
        for i=1,#slope do
            local line = slope[i]
            if line.elev==-1 then
                glDepthTest(GL.LEQUAL); glColor(s_elev_color)
            else
                glDepthTest(GL_ALWAYS); glColor(s_dig_color)
            end
            glBeginEnd(GL_LINE_STRIP, DrawLine, slope[i])
        end
        glUseShader(0)
        glColor(0, 1, 0, 0.9)
        glBeginEnd(GL_LINES, DrawFlatGrid, slope.elevRect,slope.bw*2,slope.bh*2) -- replace engine grid with proper elevated grid, full green

        --- ghost draw
        glPushMatrix()
        glDepthMask(true)
        glDepthTest(GL_ALWAYS);
        glTranslate(slope.bx,slope.by,slope.bz)
        glRotate(facing*90,0,1,0);
        --glScale(1.01, 1.01, 1.01)
        glUnitShape(pid, 0,false, true, false )
        glDepthTest(GL.ALWAYS)
        glDepthTest(false)
        glDepthMask(false)
        glPopMatrix()
    end
end

local function CreateList(layers)
    --[[if not float then
        Echo("type(elevMask2D) is ", type(elevMask2D))
        gl.PushMatrix()
        gl.Translate(bx,by,bz)
        gl.Shape(GL.POLYGON,elevMask2D)
        gl.PopMatrix()
    end--]]
    local heightcam=GetCameraHeight(spGetCameraState())
    if heightcam<30000 then
        if heightcam>3000 then
            curPullShader=overbump--Echo("overbump")  -- using different shader that will force display of grid lines that are eaten by little bumps of the terrain
        elseif heightcam>700 then
            curPullShader=moreoverbump--Echo("moreoverbump")
        else
            curPullShader=evenmoreoverbump--Echo("evenmoreoverbump")
         end
    end
    glUseShader(curPullShader)

     -- it is the BASIC MODE (verticals only)
    if show_basic then
        glDepthMask(true)
        glDepthTest(GL.LESS);--GL.LESS
       -- gl.Clear(GL.DEPTH_BUFFER_BIT)
        glColor(0, 1, 0, 0.1)

        for i,face in ipairs(elevFaces) do
            glBeginEnd(GL.POLYGON, MaskVertices , face)
        end
        glDepthTest(false)
        glDepthMask(false)
    end
    if show_basic then
        glColor(0,1,0,0.5)
        glLineWidth(1)        
        --glDepthMask(true)

        glLineStipple(true)

        glBeginEnd(GL_LINES, DrawVerticals, digging.gp, digging.lvl,'hide') -- stipples lines symbolizing digging will not be masked by the terrain
        glDepthTest(GL.LEQUAL);
        --glBeginEnd(GL_LINES, DrawVerticals, layers.groundPoints, layers.elevRect,'hide') -- draw visible vertical lines on faces
        glBeginEnd(GL_LINES, DrawVerticals, elevation.gp, elevation.lvl,'hide') -- stipple lines symbolizing elevation will be masked by the terrain (ie: if building in a pit we won't see the base)

        glDepthTest(false);

        glLineStipple(false)
        glLineWidth(1)
        --glDepthMask(false)
    end

    glColor(0, 1, 0, 0.9)
    glBeginEnd(GL_LINES, DrawFlatGrid, layers.elevRect,bw*2,bh*2) -- replace engine grid with proper elevated grid, full green
    --[[if not float then
        glDepthMask(true)
        glDepthTest(GL_ALWAYS);            
       -- gl.Clear(GL.DEPTH_BUFFER_BIT)

        glColor(0, 0, 0, 0)
        glBeginEnd(GL.POLYGON, MaskVertices , layers.elevMask)      
        glDepthTest(false);
        glDepthMask(false)


    end--]]

        --

    --gl.DepthMask(false)
    glColor(0,0,1,1)

    --glDepthTest(GL.LEQUAL)
    glDepthTest(GL.LESS)

    --****
    if show_basic then
        --gl.AlphaTest(GL.GREATER, 0.3)
        if drawBaseGroundGrid then DrawBorders(layers,{0,0.7,0.7}) end
        if drawBaseGroundContour then glColor(0,1,0,1) glBeginEnd(GL_LINE_STRIP, SimpleDrawRect, layers.groundPoints) end
    end

    glUseShader(0)
    glDepthTest(false)

    local curPullShader=0
    if heightcam<30000 then -- using different shader depending on the camera height that will more or less vertices a little to the front in order for them to be drawn instead of beeing eaten by the terrain or to separate them from another set of vertices for masking purpose
        if heightcam>3000 then
            curPullShader=overbump -- Echo('overbump')
        elseif heightcam>700 then
            curPullShader=moreoverbump--Echo("moreoverbump")
        else
            curPullShader=evenmoreoverbump--Echo("evenmoreoverbump")
        end
    end
    --
    
    if show_slopped then
        local slopeFaces = layers.slopeFaces
        local float = layers.float
        local gotElev,gotDig,gotTrans = layers.gotElev,layers.gotDig,layers.gotTrans

        if drawWater then
            glColor(0.5,0.8,1,1)  
            if by==0.1 then
                glLineWidth(3)
                glBeginEnd(GL_LINE_STRIP, DrawRectangle, bx,by,bz,bw,bh)
                glLineWidth(1)
            elseif by<80 and by>-80 then
                glBeginEnd(GL_LINE_STRIP, DrawRectangle, bx,0,bz,bw,bh)
            end
        end
        local ground,origGround = spGetGroundHeight(bx,bz),spGetGroundOrigHeight(bx,bz)
        if ground~=origGround then
            if by == origGround then
                glColor(0.8,0.8,0,1)
                glLineWidth(3)
                glBeginEnd(GL_LINE_STRIP, DrawRectangle, bx,by+0.1,bz,bw,bh)
            end
        end
        glLineWidth(1)
        --*** old method: drawing elevation layers transitionned to ground surface above Dig

        --[[ glDepthMask(true) -- Create a mask made of transition to dig zone (ground version) partially covered by the elevation zone + transition(elevation version)
        -- with this mask we will be able to show only the part of the dig zone shaping the ground that emerges from the build grid aswell as masking elevation grid that goes behind
        -- (test transparent mask main dig)

        if gotTrans then -- mask: transparent transition (ground version)
            glDepthTest(GL_ALWAYS)
            glColor(0,0,0,0)
            -- not drawing anymore the mask for ground transition
            for i,face in ipairs(slopeFaces[3]) do
                glBeginEnd(GL_TRIANGLE_STRIP, DrawSlopeMask , face, i, true,nil,nil,'mark') -- dig zone shade
            end
            glDepthTest(false)
            -- mask and draw: transition (elevation version)
            --glDepthMask(true)
            glDepthTest(GL.LESS)
            glColor(0,1,0,0.3)
            for i,face in ipairs(slopeFaces[3]) do
                glBeginEnd(GL_TRIANGLE_STRIP, DrawSlopeMask , face, i) 
            end
            glDepthTest(false)
            --glDepthMask(false)
        end
        if gotElev then --  mask of main elevation
            local color = {unpack(s_elev_color)}
            --**color[4]=color[4]/3

            --gl.BlendEquation(GL_MIN)
            --gl.Blending(GL.ZERO,GL.ZERO)
            glDepthTest(GL.LESS)

            glColor(0,0,0,0)

            for i,face in ipairs(slopeFaces[1]) do
                glBeginEnd(GL_TRIANGLE_STRIP, DrawSlopeMask , face, i)
            end
            glDepthTest(false)
            --gl.Blending (GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA)
            --gl.BlendEquation(GL_FUNC_ADD)
            --gl.AlphaTest(false)
        end
        glDepthMask(false)
        -- end of masking now we can draw the dig transition to elevation without overlapping
        if gotTrans then
            glDepthTest(GL.LEQUAL) -- equal to the transparent mask defined earlier, cropped by the elevation
            glColor(s_dig_color)
                --*** obsolete
            for i,face in ipairs(slopeFaces[3]) do
                glBeginEnd(GL_TRIANGLE_STRIP, DrawSlopeMask , face, i, true) -- dig zone shade
            end
            glDepthTest(false)
            if drawAboveDig then
                glDepthTest(GL.LESS)-- draw the ground grid above the transition
                DrawGrid(layers.gridTrans, layers.gridTransZ, {unpack(s_ground_color)},0.8,true,layers)
                glDepthTest(false)
            end
        end

        local curPullShader=0
        if heightcam<30000 then -- using different shader depending on the camera height that will more or less vertices a little to the front in order for them to be drawn instead of beeing eaten by the terrain or to separate them from another set of vertices for masking purpose
            if heightcam>3000 then
                curPullShader=overbump -- Echo('overbump')
            elseif heightcam>700 then
                curPullShader=moreoverbump--Echo("moreoverbump")
            else
                curPullShader=evenmoreoverbump--Echo("evenmoreoverbump")
            end
        end
        -- now drawing the rest fully over the mask + terrain a bit pushed in front by the shader
        glUseShader(curPullShader)
        if gotDig then -- 
            glDepthTest(GL.LEQUAL)
            glColor(s_dig_color)
            -- **not drawing anymore the zone above dig**
            for i,face in ipairs(slopeFaces[2]) do
                glBeginEnd(GL_TRIANGLE_STRIP, DrawSlopeMask , face, i, true,{unpack(s_dig_color)},layers.maxDigSlope) -- dig zone shade
            end
            if drawAboveDig then
                DrawGrid(layers.gridDig, layers.gridDigZ, {unpack(s_ground_color)},0.5,true)
            end
            glDepthTest(false)
        end
        if gotElev then --  draw: main elevation masked by back mask of elevation + terrain
            local color = {unpack(s_elev_color)}
            color[4]=color[4]/3
            glDepthTest(GL.LEQUAL)
            glColor(color)
            for i,face in ipairs(slopeFaces[1]) do
                glBeginEnd(GL_TRIANGLE_STRIP, DrawSlopeMask , face, i, false, {unpack(s_elev_color)},layers.maxElevSlope)
            end
            -- grid elevation
            glDepthTest(GL.LEQUAL)
            DrawGrid( layers.gridElev, layers.gridElevZ, s_elev_color,1) -- elevation grid
            glDepthTest(false)
        end
        if drawSloppedGroundGrid then -- display the ground grid at front only, masked by the landscape
            glLineWidth(1)   
            glDepthTest(GL.LEQUAL)
            DrawGrid(layers.gridGround, layers.gridGroundZ, s_ground_color,false,false,true) -- ground grid
            glDepthTest(false)
            glLineWidth(1)   
        end
        if drawContour then -- display the contour at front only, masked by the landscape
            glDepthTest(GL.LEQUAL)
            glColor(unpack(s_cont_color))
            glBeginEnd(GL_LINE_STRIP, DrawPoints, contour)
            glDepthTest(false)
        end
        glUseShader(0)-- end of pushing shader
        if layers.endSlope.allcuts then
            glDepthTest(GL_ALWAYS)
            for _,cut in ipairs(layers.endSlope.allcuts) do -- force display edge of map underground contour
                glBeginEnd(GL_LINE_STRIP, DrawPoints, cut)
            end
            glDepthTest(false)
        end--]]
        


        --*** NEW VERSION: elevation slope transitionned to dig slope with shading surface above dig

        ------ Elevation Part + contour
        glDepthMask(true) -- building mask of elevation
        local color={unpack(s_elev_color)}
        if gotElev then --  mask of main elevation without pushing shader
            glDepthTest(GL.LESS)
            glColor(0,0,0,0)
            for i,face in ipairs(slopeFaces[1]) do
                glBeginEnd(GL_TRIANGLE_STRIP, DrawSlopeMask , face, i)
            end
            glDepthTest(false)
        end
        glDepthMask(false)
        if gotTrans then -- mask and draw: complete elevation mask with transition cropped by terrain
            glDepthTest(GL.LESS)
            for i,face in ipairs(slopeFaces[3]) do
                glBeginEnd(GL_TRIANGLE_STRIP, DrawSlopeMask , face, i, false, {unpack(color)}, layers.maxElevSlope) 
            end
            glDepthTest(false)
        end
        glUseShader(curPullShader) -- pulling to front
        if gotElev then --  draw: pushed main elevation above the terrain or the mask, hiding effectively the back part of elevation and grid
            color[4]=color[4]/2
            glDepthTest(GL.LEQUAL)
            glColor(color)
            for i,face in ipairs(slopeFaces[1]) do
                glBeginEnd(GL_TRIANGLE_STRIP, DrawSlopeMask, face, i, false, {unpack(color)}, layers.maxElevSlope)
            end
            glDepthTest(false)
            -- grid elevation
            glDepthTest(GL.LEQUAL)
            DrawGrid( layers.gridElev, layers.gridElevZ, s_elev_color,1) -- elevation grid
            if gotTrans then DrawGrid(layers.gridTrans, layers.gridTransZ, s_elev_color,1) end
            glDepthTest(false)

        end
        glUseShader(0)

        --------- Digging Transition
        if gotDig then -- for digging we make another mask
            color = {unpack(s_dig_color)}
            --** start of masking **--
            glDepthMask(true)--***
            glDepthTest(GL.GREATER)
            glColor(0,0,0,0)
            for i,face in ipairs(slopeFaces[2]) do
                glBeginEnd(GL_TRIANGLE_STRIP, DrawSlopeMask , face, i) -- transparent mask dig slope 
            end
            glDepthTest(GL.LESS)
            for i,face in ipairs(slopeFaces[2]) do
                glBeginEnd(GL_TRIANGLE_STRIP, DrawSlopeMask , face, i, true) -- transparent mask dig surface terrain
            end
            glDepthTest(false)
            if gotTrans then -- dig slope transition, under terrain / static color
                glDepthTest(GL.GREATER)
                color[4]=s_dig_color[4]/2
                glColor(color)
                for i,face in ipairs(slopeFaces[3]) do
                    glBeginEnd(GL_TRIANGLE_STRIP, DrawSlopeMask , face, i, false)
                end
                glDepthTest(false)
            end
            glDepthTest(GL.GEQUAL) -- dig zone slope / static color
            color[4]=s_dig_color[4]/2
            glColor(color)
            for i,face in ipairs(slopeFaces[2]) do
                glBeginEnd(GL_TRIANGLE_STRIP, DrawSlopeMask , face, i, false) 
            end
            glDepthTest(false)
            glDepthMask(false)
            --** end of masking **--

            --[[if gotTrans and maxDigSlope>50 then -- 
                color[4]=s_dig_color[4]*0.8
                glDepthTest(GL_ALWAYS)
                for i,face in ipairs(slopeFaces[3]) do
                    glBeginEnd(GL_TRIANGLE_STRIP, DrawSlopeShade , face,{unpack(color)})
                end
                glDepthTest(false)
            end--]]
            glUseShader(pushalittle) -- push the grid a little to the back so we see only the back part
            glDepthTest(GL.GEQUAL) -- slope grid of dig and dig transition / static color
            DrawGrid(layers.gridDig, layers.gridDigZ, s_dig_color,1)
            if gotTrans then DrawGrid(layers.gridTrans, layers.gridTransZ, s_dig_color,1) end
            glDepthTest(false)
            glUseShader(0)
        end
        glUseShader(curPullShader)

        if layers.needTerra and drawSloppedGroundGrid then -- display the ground grid at front only, masked by the landscape // transparency defined through point prop from AddAlpha func
            glLineWidth(1)   
            glDepthTest(GL.LEQUAL)
            DrawGrid(layers.gridGround, layers.gridGroundZ, s_ground_color,false,false,true) -- ground grid
            glDepthTest(false)
            glLineWidth(1)   
        end
        if drawContour then -- display the contour at front only, masked by the landscape / static alpha
            glDepthTest(GL.LEQUAL)
            glColor(s_cont_color)
            glBeginEnd(GL_LINE_STRIP, DrawPoints, contour)
            glDepthTest(false)
        end
        glUseShader(0)
        --[[if gotDig and maxDigSlope>50 then
            color[4]=s_dig_color[4]*0.8
            color[1], color[2], color[3] = 1-color[1], 1-color[2], 1-color[3]
            glDepthTest(GL_ALWAYS)
            for i,face in ipairs(slopeFaces[2]) do
                glBeginEnd(GL_TRIANGLE_STRIP, DrawSlopeShade , face, {unpack(color)}) -- dig zone shade
            end
            glDepthTest(false)
        end--]]
        glUseShader(curPullShader)
        glDepthTest(GL.LESS)
        if gotDig and drawAboveDig then
            DrawGrid(layers.gridDig, layers.gridDigZ, {unpack(s_ground_on_dig_color)},false,true)
        end
        glUseShader(0)
        glDepthTest(GL.ALWAYS)
        glDepthTest(false)
        --------------------
        glColor(1,1,1,1)
    end -- end of slope display

    if show_slopped and showCost then
        glPushMatrix()
        glTranslate(bx,by,bz)
        glBillboard()
        glColor(1, 1, 1, 0.4)
        glText(layers.cost, bw,bh,30,'h')
        glPopMatrix()
    end

    --- ghost draw
    glDepthMask(true)
    glPushMatrix()
    glTranslate(bx,by,bz)
    glRotate(facing*90,0,1,0);

    --glScale(1.01, 1.01, 1.01)
    glUnitShape(pid, 0,false, true, false )
    glPopMatrix()

    glColor(1, 1, 1, 1)
    glDepthMask(false)
    glDepthTest(false);
    glUseShader(0)
end


local function convinc(quality,by,gy,curcount) -- Set the increment value (size of grid cells)
    if quality=='basic' or curcount>1 then
        return 16
    elseif quality=='automatic' then 
        local placementheight = abs(by-(gy<0 and 0 or gy))
        if placementheight>715 then
            return (bw*2)%32==0 and (bh*2)%32==0 and 32 or 16
        elseif placementheight>315 then
            return 16
        else
            return 8
        end
    elseif quality==32 then
        return (bw*2)%32==0 and (bh*2)%32==0 and 32 or 16
    else 
        return quality
    end
end
local CleanUp
do
    local known = {}
    local cnt=0
    CleanUp = function(t,isRecur)
        if true then return end
        if not t then return true end
        Echo('start clean up...')
        for k,v in pairs(t) do

            if type(v)=='table' and not known[v] then
                -- Echo(k..' is table, recursion...')
                known[v] = true
                CleanUp(v,true)
            end
            -- Echo('delete '..tostring(k))
            t[k]=nil
            cnt=cnt+1
        end
        if not isRecur then for k,v in pairs(known) do known[k]=nil end Echo('cleaned up '..cnt) cnt=0 end
        return true
    end
end
local function Execute()
    WG.TerraCost = nil
    -- collectgarbage('collect')
    -- Echo('collected',collectgarbage('count'))
    -- Echo("collectgarbage('count') is ", collectgarbage('count'))
    -- if collectgarbage('count')>190000 then Echo('collect') collectgarbage('collect') end

--        glDeleteList(DrawingList)
    if not dwOn then --[[GenerateShaders()--]] end

    --avgcreate('resume')
    bx,by,bz,bw,bh,float,pid,facing,needTerra,drawWater = unpack(WG.DrawTerra)
    local poses
    if spGetBuildProjects then
        poses = spGetBuildProjects('poses')
    else
        poses={{bx,by,bz}}
    end

    WG.DrawTerra.new = false
    _,gy=spPos2BuildPos(pid,bx,by,bz,facing)
--Echo("groundGridMaxOpacity is ", groundGridMaxOpacity/(1/numborders)*(8/inc)+1)
    inc = convinc(quality,by,gy,curcount or 1)
    if show_basic then 
        layers = CreateHollowRectangles(bx,bz,bw,bh,8,5,float) -- create segmented rectangle like footprint of our placement + 4 augmented rectangle of it as layers
        PairBorders(layers)--each border point will get reference of adequat points of the smaller rectangle; the smallest beeing the ground points of our placement which doesnt get pairs
        layers.groundPoints=table.remove(layers,1)

        layers.elevRect = CreateHollowRectangles(bx,bz,bw,bh,8,1,nil,by)[1]
        elevation,digging = ElevAndDiggingPairs(layers.groundPoints, layers.elevRect)
        SetHiddenFaces(layers.groundPoints,by,bw) -- create .hidden property on points of the footprint of rectangle placement and relative orientation according to camera view
        --layers.elevMask = CreateElevationMask(layers.groundPoints,by)
        --elevMask2D=toRelative2D(layers.elevMask,bx,by,bz)
        elevFaces = ElevationFaces(layers.groundPoints, by,layers.elevRect) -- so far drawing mask only for elevated face, not digging

    elseif show_slopped then
        local num = numborders
        if numborders == 'automatic' then 
            num =5+abs(by-(gy<0 and 0 or gy))/(20/(8/inc))
        end
        if needTerra and ((quality=='basic') or curcount>1) then
            -- CleanUp(slopes)
            slopes={}
            for i=1,#poses do 
                local pose=poses[i]
                bx,bz = pose[1],pose[3]
                slopes[i]=CreateBasicSlopeLines(bx,bz,bw,bh,float,by)
                CreateBasicContour(slopes[i])
                slopes[i].elevRect = CreateHollowRectangles(bx,bz,bw,bh,8,1,nil,by)[1]
            end
        else
            --layers,gotDig,gotElev, gotTrans = CreateSloppedRectangles(bx,bz,bw,bh,OptimalBorders(),float,by,needTerra)
            --local gotElev,gotDig,gotTrans
            -- CleanUp(layers)
            layers  = CreateSloppedRectangles(bx,bz,bw,bh,num,float,by,needTerra)
            --if drawSloppedGroundGrid then AddAlpha(layers.gridGround,1/numborders,groundGridMaxOpacity) end
            if needTerra and drawSloppedGroundGrid then
                AddAlpha( layers,num,s_ground_color[4])
            end

            if drawContour then contour = GetSlopeContour(layers) end
            --**PairBorders(layers)
            if layers.gotElev or layers.gotDig then
                CreateSlopeFaces(layers,layers.gotElev,layers.gotDig,layers.gotTrans)
            end
            if layers.gotDig then
                AddSlopeShade(layers.slopeFaces[2],{unpack(s_dig_color)}, layers.maxDigSlope)
            end
            --table.remove(layers,1)
            layers.elevRect = CreateHollowRectangles(bx,bz,bw,bh,8,1,nil,by)[1]
            WG.TerraCost = layers.cost
        end
    end
    --buildFaces = CobbleStone(bx,gy-50,bz,bw+25,bh+25,gy+height+15) -- box containing the original ghost build, will be used as mask

    --***---groundGrid   = FlatRect(bx,gy,bz,bw,bh)
    --***---groundGrid2D = To2D(groundGrid,bx,gy,bz)
    --**To2DMap(groundGrid,bx,gy,bz)
    --**flatRect = FlatRect(bx,gy-25,bz+50,bw,bh)
    --**SetHiddenFaces(flatRect,gy+25)
    --**layers.buildMask=CreateElevationMask(flatRect,gy+25)
    --**layers.buildMask=Poly2D(layers.buildMask,bx,gy,bz)
    --elevation,digging = ElevAndDiggingPairs(sloppedGroundPoints, layers.elevRect) 
   -- for i=1,#layers.elevMask do Echo(unpack(layers.elevMask[i])) end
    --layers.buildMask = CreateBuildMask(bx,gy,bz,bw,bh)
    --timecheck('pause')
    --Echo("   is ", quality=='automatic' and inc==8 and timecheck()>0.25)
    if DrawingList then glDeleteList(DrawingList) DrawingList=false end
    if needTerra and (quality=='basic' or curcount>1) then
        DrawingList = glCreateList(function() CreateBasicList(slopes) end)
    else
        DrawingList = glCreateList(function() CreateList(layers) end)
    end
    if not dwOn then widgetHandler:UpdateCallIn("DrawWorld") end

    --Echo('end creation ',--avgcreate('reset'))
    --avgcreate('pause')

end
function widget:Update(dt)

--Echo(Spring.GetBuildProjects("count"))
--Page(Spring.GetBuildProjects("poses"), {content=true})
--local A,B = Spring.GetBuildProjects("count")
    if requestUpdate then
        UpdateOptionsDisplay(requestUpdate)
        requestUpdate=false
    end
    if spGetBuildProjects and spGetGameSeconds()>0.1 then
        local count = spGetBuildProjects('count')
        if bx and curcount~=count then
            curcount = count
            newcount = count~=0
        end
    end
--Echo("quality is ", quality, inc)
--if dwOn then Echo(timecheck('average',100 ,'hey')) end
--if dwOn then     Echo(timecheck('reset')) end
    if WG.DrawTerra.new or newcount then
        newcount=false
        WG.DrawTerra.working=true
        Execute()
    elseif WG.DrawTerra.finish --[[and not bx--]] then
        Finish()
    end
end



local page = 0

local onoff=false
local oldcnt,curcnt=0
local places




function widget:KeyPress(key,mods)
    -- if mods.ctrl and key==262 then -- Ctrl + KP6 to reload
    --     Spring.Echo('Reloading ' .. widget:GetInfo().name)
    --     Spring.SendCommands('luaui disablewidget ' .. widget:GetInfo().name)
    --     Spring.SendCommands('luaui enablewidget ' .. widget:GetInfo().name)
    -- end
    
--[[    if key==111 then
        Spring.SendCommands('atm')
    end--]]
--Echo("Spring.GetBuildProjectsCount() is ", Spring.GetBuildProjectsCount())
    --page=page+1
    --Page(Spring,'build')
    --Echo(Spring.GetBuildProjects())

--[[    local curcnt=spGetBuildProjects('count')
    if curcnt~=oldcnt or curcnt==1 then
        oldcnt=curcnt
        --Echo("curcnt is ", curcnt)
        --Echo("count is ", Spring.GetBuildProjects('count'))
        --places=Spring.GetBuildProjects('poses')
        --Page(places,{content=true})
        Page(spGetBuildProjects('infos'))

    end
    if key==111 then
        onoff= not onoff
        --Spring.SetDrawBuild(onoff,onoff)
    end--]]
    --Echo(Spring.GetDrawBuild())
end

function widget:DrawWorld()
    dwOn=true
    if not DrawingList then return end
    glCallList(DrawingList)

    if debugging then
            glColor(1, 1, 0, 0.6)
            
            -- glText(id, 0,-20,5,'h')
           
            glColor(1, 1, 1, 1)
        local grid = layers.grid
        local white = {1,1,1,1}
        for x=grid.minx,grid.maxx,inc do
            local gridX = grid[x]
            for z=grid.minz,grid.maxz,inc do
                local point = gridX[z]
                if point.mark then
                    glColor(point.color or white)
                    if point.mark==true then
                        glPointSize(10)
                        glBeginEnd(GL.POINTS, DrawPoint,unpack(point))
                    else
                        glPushMatrix()
                        glTranslate(unpack(point))
                        glBillboard()
                        -- Echo('got marked point')
                        glText(point.mark, -5,0,5,'h')
                        glPopMatrix()
                    end
                end
            end
            -- for p,point in pairs(gx) do
            -- end
        end
        glColor(white)
    end
    -- Bunch of tests
        --**Echo('start of draw: ',newpass)
        --**--avgdraw('resume')
        ---- 
        --if not shader then shader=gl.CreateShader(shaderSingleColor) end -- create shader and assign a number to it, that number is stored as 'shader'
        --if not removeGreenShader then removeGreenShader=gl.CreateShader(removeGreen) end

        --if not maskupShader then maskupShader=gl.CreateShader(maskup) end
        --    glUseShader(maskupShader)
        --[[
        gl.DepthTest(true)
        gl.StencilTest(true)
        gl.Clear(GL.STENCIL_BUFFER_BIT); 
            -- if 'REPLACE' the value returned by the StencilFunc will be used
        --gl.Clear(GL.STENCIL_BUFFER_BIT);
        gl.StencilOp(GL.KEEP, GL.KEEP, GL.REPLACE) -- 
        gl.StencilFunc(GL_ALWAYS,30,0xff); -- comparison must be valid for the ref value AND the value in the buffer
        --gl.StencilFunc(GL.NOTEQUAL,1,2); -- comparison must be valid for the ref value AND the value in the buffer
        -- as the comparison here is 'ALWAYS', it will return '1' no matter what, the 3rd paramter is useless, here
        --gl.Clear(GL.COLOR_BUFFER_BIT); 
        --gl.Clear(GL.DEPTH_BUFFER_BIT); 

        --gl.StencilMask(0); -- make sure we don't update the stencil buffer while drawing the floor

                    glColor(1,0,1, 1)
                    for i=1,6 do
                        glBeginEnd(GL.POLYGON, arriereplan , buildFaces[i])      
                    end
          
        --gl.Clear(GL.STENCIL_BUFFER_BIT); 

        --gl.StencilMask(1); 

        --gl.StencilFunc(GL_EQUAL, 1, 3); -- from now on, any new drawing fragment will be checked with the already existing value in the stencil buffer:
                                        -- any fragments with values of 1 in the stencil buffer to 2 (if scenario corroborating )
        gl.StencilFunc(GL_EQUAL, 30, 30); 


                    glColor(1,0,0, 1)
                    for i=1,6 do
                        glBeginEnd(GL.POLYGON, sujet , buildFaces[i])      
                    end

        --gl.StencilFunc(GL.NOTEQUAL, 1, 1); -- now it write only (to 1) if the value in the buffer is 0)
        --gl.StencilMask(0); 
        --gl.DepthTest(false)
        --gl.StencilMask(1)
        gl.StencilFunc(GL.NOTEQUAL, 30, 30);
                    glUseShader(shader); 
                    --glColor(1,1,0, 1)
                    for i=1,6 do
                        glBeginEnd(GL.POLYGON, outline , buildFaces[i])      
                    end
                    
        --gl.StencilMask(0);
        --gl.StencilFunc(GL_ALWAYS, 1, 1);   
        gl.DepthTest(false); 


        glUseShader(0)
        gl.StencilTest(false)


        --[[gl.Clear(GL.COLOR_BUFFER_BIT, 0, 0, 0, 0)
        gl.Clear(GL.STENCIL_BUFFER_BIT, 0)
        gl.Clear(GL.DEPTH_BUFFER_BIT,0,0,0,0,0)
        gl.SwapBuffers()--]]
        --gl.StencilMask(5)

        --Echo("GL.PROJECTION_MATRIX is ", GL.PROJECTION_MATRIX)
        --]]

        --[[    glPushMatrix()
            glColor(1, 0, 0, 0.7)
            --gl.Translate(bx,by,bz)
            gl.Billboard()
            gl.Shape(GL.POLYGON, {
                {v={bx,-bz,by}},
                {v={bx,-bz+50,by+50}},
                {v={bx+100,-bz+50,by+50}},
            })
            
            glPopMatrix()

        --]]
    --

    -- another bunch of test
        --[[--gl.Blending(true)
        -- masking the original unitShape
        --glPushMatrix()
        glDepthMask(true)
        glDepthTest(true);
        --glTranslate(bx,gy,bz)
        glColor(1, 1, 1, 1)
        --glRotate(facing*90,0,1,0);
        --glScale(1.01, 1.01, 1.01)
        --glUnitShape(pid, 0,true,false )

        glBeginEnd(GL.POLYGON, MaskVertices , layers.buildMask)
        glDepthTest(false);
        glDepthMask(false)
        --glPopMatrix()
        --
        -- ]]

        --glPushMatrix()

        --**gl.Utilities.DrawMyBox(bx-bw,gy-50,bz-bh, bx+bw,gy+50,bz+bh)

        --glPopMatrix()

        --if inc==99 and not done then
            --local a,y=spWorldToScreenCoords(bx,gy,bz)
            --local pixels=  gl.ReadPixels(a,y,2,2)
            --done = true
            --f.Page(pixels[1],{content=true})
            --Echo("#pixels is ", #pixels)
            --[[local gridTex = "LuaUI/Images/vr_grid_large.dds"
            --local gridTex = "bitmaps/PD/shield3hex.png"
            local realTex = '$grass'
            local function fun(wx,gy,wz,size)
                local  fragmentx=Game.mapSizeZ/size
                gl.TexCoord(0.5,0.5)
                gl.Vertex(wx-size,gy+50,wz-size)
                gl.TexCoord(0.5,1)
                gl.Vertex(wx-size,gy+50,wz+size)
                gl.TexCoord(1,1)
                gl.Vertex(wx+size+50,gy+50,wz+size+50)
                gl.TexCoord(1,0.5)
                gl.Vertex(wx+size,gy+50,wz-size)

            end
                gl.DepthTest(true)
                --gl.Blending(GL.SRC_ALPHA,GL.ONE_MINUS_SRC_ALPHA)
                gl.Color(1,1,1,1)
                 gl.Texture(realTex)
                gl.BeginEnd(GL.QUADS,fun, bx,by,bz, 100)
                gl.PushAttrib(GL.ALL_ATTRIB_BITS)
                gl.Texture(false)
                gl.Color(1,1,1,1)
                --gl.Blending(GL.SRC_ALPHA,GL.ONE_MINUS_SRC_ALPHA)
                gl.PopAttrib()
                gl.DepthTest(false)
            --]]
        --end

         --*** CobbleStone

        --[[glDepthMask(true)
        --gl.ColorMask(true, true, true, true)
        --gl.StencilMask(GL.LESS)
        glDepthTest(GL.LEQUAL);
        glColor(0,0,0, 0)
        --gl.AlphaTest(GL.LEQUAL, 1)


        for i=1,6 do
            glBeginEnd(GL.POLYGON, MaskVertices , buildFaces[i])
        end
        glDepthMask(false)
        glDepthTest(false);--]]

        --gl.AlphaTest(false)
        --gl.Clear(GL.STENCIL_BUFFER_BIT, 1000)

        --[[-- masking the original unitShape
        glLineWidth(1.0)  
        --gl.Blending(false)
        glDepthMask(true)
        glDepthTest(true)
        gl.PushMatrix()

        glColor(1, 1, 1, 0)

        gl.Translate(bx,gy+50,bz+inc)
        gl.Billboard()
        --glPolygonMode(GL.FRONT_AND_BACK, GL.FILL);
        gl.Shape(GL.POLYGON, layers.buildMask)
        --gl.Shape(GL.POLYGON, func())

        gl.PopMatrix()
        --gl.Blending(true)--]]


        --[[glPushMatrix()
        glColor(1, 1, 1, 0.5)
        glDepthMask(true)
        glDepthTest(true)

        glTranslate(bx,gy,bz)
        glBillboard()
        glShape(GL.POLYGON, func2(bx,gy,bz))

        glDepthMask(false)
        glDepthTest(false)
        glColor(1, 1, 1, 1)
        glPopMatrix()
        --]]--

        --+++Echo(--avgdraw('average',50,(createRes and 'C: '..createRes or '')..', D: '))
        --+++--avgdraw('pause')
        --****Echo('end of draw: '..newpass, --avgdraw('reset'))
        --**Echo('end of draw: ', --avgdraw('reset'))
        --**--avgdraw('pause')

    glColor(1,1,1,1)
    glDepthMask(false)
    glDepthTest(false)

end

function widget:AfterInit()
    DrawTerra = WG.DrawTerra
    DrawTerra.finish=true
    ghosts = WG.ghosts
    commandLot = WG.commandLot
    widget.Update = widget._Update
    widget._Update = nil
end

function widget:Initialize()
--Echo("PBH2 is ", widgetHandler:FindWidget("Persistent Build Height 2"))
   -- Echo("Spring.SetDrawBuild is ", Spring.SetDrawBuild)
    if not glCreateShader then 
        widgetHandler:RemoveWidget(self)
        Echo('compat mode, DrawTerra 2 removed')
        return
    end
    if Spring.GetSpectatingState() or Spring.IsReplay() then
        -- Spring.Echo(widget:GetInfo().name..' disabled for spectators')
        -- widgetHandler:RemoveWidget(self)
        -- return
    end
    WG.DrawTerra.ready=true
    DrawTerra = WG.DrawTerra
    if Spring.SetDrawBuild then Spring.SetDrawBuild(false,false) end
    panels = WG.Chili.Screen0.children
    GenerateShaders()
    widgetHandler:RemoveCallIn('DrawWorld')
    dwOn = false
    widget._Update = widget.Update
    widget.Update = widget.AfterInit
end

function widget:SetConfigData(data)
    --if not data.colors then data.colors=colors end
    if data.colors then
        for key,item in pairs(data.colors) do
            colors[key].Update(item.val) -- don't replace but update local colors content
            colors[key].name = ColStr(item.val)..colors[key].basename
        end
    end
end
function widget:Shutdown()
    DeleteShaders()
    WG.TerraCost = nil
    Finish()
    for k,v in pairs(WG.DrawTerra) do WG.DrawTerra[k]=nil end
    WG.DrawTerra.ready=false
end
function widget:GetConfigData()
    return {colors=colors}
end
f.DebugWidget(widget)

