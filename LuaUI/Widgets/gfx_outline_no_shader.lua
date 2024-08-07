-- $Id: gfx_outline.lua 3171 2008-11-06 09:06:29Z det $
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--
--  file:    gfx_outline.lua
--  brief:   Displays a nice cartoon like outline around units
--  author:  jK
--
--  Copyright (C) 2007.
--  Licensed under the terms of the GNU GPL, v2 or later.
--
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function widget:GetInfo()
	return {
		name      = "Outline No Shader",
		desc      = "Displays a nice cartoon like outline around units.",
		author    = "jK",
		date      = "Dec 06, 2007",
		license   = "GNU GPL, v2 or later",
		layer     = -10,
		enabled   = false,  --  loaded by default?
		handler   = true,
	}
end
local Echo = Spring.Echo
local thickness = 1
local thicknessMult = 1
local forceLowQuality = false
local scaleWithHeight = false
local functionScaleWithHeight = true
local spGetVisibleUnits = Spring.GetVisibleUnits
local spGetUnitDefID = Spring.GetUnitDefID
local spGetUnitIsDead = Spring.GetUnitIsDead
local spValidUnitID = Spring.ValidUnitID
local PI = math.pi
local SUBTLE_MIN = 500
local SUBTLE_MAX = 3000
local zoomScaleRange = 0.5

local supercheap = true
local Units
local Cam

local function OnchangeFunc()
	thickness = options.thickness.value
end

local function QualityChangeCheckFunc()
	if forceLowQuality then
		options.lowQualityOutlines.OnChange = nil
		options.lowQualityOutlines.value = true
		options.lowQualityOutlines.OnChange = QualityChangeCheckFunc
	end
end

options_path = 'Settings/Graphics/Unit Visibility/Outline (No Shader)'
options = {
	thickness = {
		name = 'Outline Thickness',
		desc = 'How thick the outline appears around objects',
		type = 'number',
		min = 0.2, max = 1, step = 0.01,
		value = 0.5,
	OnChange = OnchangeFunc,
	},
	scaleWithHeight = {
		name = 'Scale With Distance',
		desc = 'Reduces the screen space width of outlines when zoomed out.',
		type = 'bool',
		value = false,
		noHotkey = true,
		OnChange = function (self)
			scaleWithHeight = self.value
			if not scaleWithHeight then
				thicknessMult = 1
			end
		end,
	},
	scaleRange = {
		name = 'Zoom Scale Minimum',
		desc = 'Minimum outline thickness muliplier when zoomed out.',
		type = 'number',
		min = 0, max = 1, step = 0.01,
		value = zoomScaleRange,
		OnChange = function (self)
			zoomScaleRange = self.value
		end,
	},
	functionScaleWithHeight = {
		name = 'Subtle Scale With Distance',
		desc = 'Reduces the screen space width of outlines when zoomed out, in a subtle way.',
		type = 'bool',
		value = true,
		noHotkey = true,
		OnChange = function (self)
			functionScaleWithHeight = self.value
			if not functionScaleWithHeight then
				thicknessMult = 1
			end
		end,
	},
	lowQualityOutlines = {
		name = 'Low Quality Outlines',
		desc = 'Reduces outline accuracy to improve perfomance, only recommended for low-end machines',
		type = 'bool',
		value = false,
		advanced = true,
		noHotkey = true,
		OnChange = QualityChangeCheckFunc,
	},
}

OnchangeFunc()

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

--//textures
local offscreentex
local depthtex
local blurtex

--//shader
local depthShader
local blurShader_h
local blurShader_v
local uniformUseEqualityTest, uniformScreenXY, uniformScreenX, uniformScreenY

--// geometric
local vsx, vsy = 0,0
local resChanged = false

--// display lists
local enter2d,leave2d
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local GL_DEPTH_BITS = 0x0D56

local GL_DEPTH_COMPONENT   = 0x1902
local GL_DEPTH_COMPONENT16 = 0x81A5
local GL_DEPTH_COMPONENT24 = 0x81A6
local GL_DEPTH_COMPONENT32 = 0x81A7

--// speed ups
local ALL_UNITS       = Spring.ALL_UNITS
local GetUnitHealth   = Spring.GetUnitHealth
local GetVisibleUnits = Spring.GetVisibleUnits
local spIsUnitIcon 	  = Spring.IsUnitIcon
local spIsUnitVisible = Spring.IsUnitVisible

local GL_MODELVIEW  = GL.MODELVIEW
local GL_PROJECTION = GL.PROJECTION
local GL_COLOR_BUFFER_BIT = GL.COLOR_BUFFER_BIT

local glUnit            = gl.Unit
local glCopyToTexture   = gl.CopyToTexture
local glRenderToTexture = gl.RenderToTexture
local glCallList        = gl.CallList

local glUseShader  = gl.UseShader
local glUniform    = gl.Uniform
local glUniformInt = gl.UniformInt

local glClear    = gl.Clear
local glTexRect  = gl.TexRect
local glColor    = gl.Color
local glTexture  = gl.Texture

local glResetMatrices = gl.ResetMatrices
local glMatrixMode    = gl.MatrixMode
local glPushMatrix    = gl.PushMatrix
local glLoadIdentity  = gl.LoadIdentity
local glPopMatrix     = gl.PopMatrix

local GL_ALWAYS				= GL.ALWAYS
local GL_REPLACE 			= GL.REPLACE
local GL_FRONT_AND_BACK 	= GL.FRONT_AND_BACK
local GL_FILL 				= GL.FILL
local GL_STENCIL_BUFFER_BIT = GL.STENCIL_BUFFER_BIT
local GL_NOTEQUAL			= GL.NOTEQUAL
local GL_KEEP				= GL.KEEP




local glStencilOp 	= gl.StencilOp
local glStencilFunc = gl.StencilFunc
local glPolygonMode = gl.PolygonMode
local glDepthMask	= gl.DepthMask
local glDepthTest	= gl.DepthTest

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

--tables
local unbuiltUnits = {}

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
local Units
local visibleUnits

local NewView


local lastView = 0
local glCreateList = gl.CreateList
local glCallList = gl.CallList
local glDeleteList = gl.DeleteList
local globalList
local lists = {}

function widget:Initialize()
	NewView = WG.NewView
	visibleUnits = WG.Visibles and WG.Visibles.not_iconsMap
	if not (visibleUnits) then
		Echo(widget:GetInfo().name .. ' requires HasViewChanged.')
		widgetHandler:RemoveWidget(widget)
		-- Echo(widget:GetInfo().name .. ' need ' .. (not Units and 'UnitsIDCards' or '')  .. (not visibleUnits and  ((not Units and ', ' or '') .. 'HasViewnChanged') or '') .. '.')
		return
	end
	Cam = WG.Cam
	Units = Cam.Units --WG.UnitsIDCard.units
	vsx, vsy = widgetHandler:GetViewSizes()

	self:ViewResize(widgetHandler:GetViewSizes())

	if gl.CreateShader == nil then --For old Intel chips
		Spring.Log(widget:GetInfo().name, LOG.ERROR, "Outline widget: cannot create shaders. forcing shader-less fallback.")
		forceLowQuality = true
		options.lowQualityOutlines.value = true
		return true
	end



	--For cards that can use shaders
	enter2d = gl.CreateList(function()
		glUseShader(0)
		glMatrixMode(GL_PROJECTION); glPushMatrix(); glLoadIdentity()
		glMatrixMode(GL_MODELVIEW);  glPushMatrix(); glLoadIdentity()
	end)
	leave2d = gl.CreateList(function()
		glMatrixMode(GL_PROJECTION); glPopMatrix()
		glMatrixMode(GL_MODELVIEW);  glPopMatrix()
		glTexture(false)
		glUseShader(0)
	end)

	depthShader = gl.CreateShader({
		fragment = [[
			uniform sampler2D tex0;
			uniform int useEqualityTest;
			uniform vec2 screenXY;

			void main(void)
			{
				vec2 texCoord = vec2( gl_FragCoord.x/screenXY.x , gl_FragCoord.y/screenXY.y );
				float depth  = texture2D(tex0, texCoord ).z;

				if (depth < gl_FragCoord.z) {
					discard;
				}
				gl_FragColor = gl_Color;
			}
		]],
		uniformInt = {
			tex0 = 0,
			useEqualityTest = 1,
		},
			uniform = {
			screenXY = {vsx,vsy},
		},
	})

	blurShader_h = gl.CreateShader({
		fragment = [[
			uniform sampler2D tex0;
			uniform int screenX;

			const vec2 kernel = vec2(0.6,0.7);

			void main(void) {
				vec2 texCoord  = vec2(gl_TextureMatrix[0] * gl_TexCoord[0]);
				gl_FragColor = vec4(0.0);

				float pixelsize = 1.0/float(screenX);
				gl_FragColor += kernel[0] * texture2D(tex0, vec2(texCoord.s + 2.0*pixelsize,texCoord.t) );
				gl_FragColor += kernel[1] * texture2D(tex0, vec2(texCoord.s + pixelsize,texCoord.t) );

				gl_FragColor += texture2D(tex0, texCoord );

				gl_FragColor += kernel[1] * texture2D(tex0, vec2(texCoord.s + -1.0*pixelsize,texCoord.t) );
				gl_FragColor += kernel[0] * texture2D(tex0, vec2(texCoord.s + -2.0*pixelsize,texCoord.t) );
			}
		]],
		uniformInt = {
			tex0 = 0,
			screenX = vsx,
		},
	})


	blurShader_v = gl.CreateShader({
		fragment = [[
			uniform sampler2D tex0;
			uniform int screenY;

			const vec2 kernel = vec2(0.6,0.7);

			void main(void) {
				vec2 texCoord  = vec2(gl_TextureMatrix[0] * gl_TexCoord[0]);
				gl_FragColor = vec4(0.0);

				float pixelsize = 1.0/float(screenY);
				gl_FragColor += kernel[0] * texture2D(tex0, vec2(texCoord.s,texCoord.t + 2.0*pixelsize) );
				gl_FragColor += kernel[1] * texture2D(tex0, vec2(texCoord.s,texCoord.t + pixelsize) );

				gl_FragColor += texture2D(tex0, texCoord );

				gl_FragColor += kernel[1] * texture2D(tex0, vec2(texCoord.s,texCoord.t + -1.0*pixelsize) );
				gl_FragColor += kernel[0] * texture2D(tex0, vec2(texCoord.s,texCoord.t + -2.0*pixelsize) );
			}
		]],
		uniformInt = {
			tex0 = 0,
			screenY = vsy,
		},
	})

	if (depthShader == nil) then
		Spring.Log(widget:GetInfo().name, LOG.ERROR, "Outline widget: depthcheck shader error, forcing shader-less fallback: "..gl.GetShaderLog())
		-- widgetHandler:RemoveWidget(widget)
		-- return false
		forceLowQuality = true
		options.lowQualityOutlines.value = true
		return true
	end
	if (blurShader_h == nil) then
		Spring.Log(widget:GetInfo().name, LOG.ERROR, "Outline widget: hblur shader error, forcing shader-less fallback: "..gl.GetShaderLog())
		-- widgetHandler:RemoveWidget(widget)
		-- return false
		forceLowQuality = true
		options.lowQualityOutlines.value = true
		return true
	end
	if (blurShader_v == nil) then
		Spring.Log(widget:GetInfo().name, LOG.ERROR, "Outline widget: vblur shader error, forcing shader-less fallback: "..gl.GetShaderLog())
		-- widgetHandler:RemoveWidget(widget)
		-- return false
		forceLowQuality = true
		options.lowQualityOutlines.value = true
		return true
	end

	uniformScreenXY        = gl.GetUniformLocation(depthShader,  'screenXY')
	uniformScreenX         = gl.GetUniformLocation(blurShader_h, 'screenX')
	uniformScreenY         = gl.GetUniformLocation(blurShader_v, 'screenY')
end

function widget:ViewResize(viewSizeX, viewSizeY)
	vsx = viewSizeX
	vsy = viewSizeY

	gl.DeleteTexture(depthtex or 0)
	gl.DeleteTextureFBO(offscreentex or 0)
	gl.DeleteTextureFBO(blurtex or 0)

	if not forceLowQuality then
		depthtex = gl.CreateTexture(vsx,vsy, {
			border = false,
			format = GL_DEPTH_COMPONENT24,
			min_filter = GL.NEAREST,
			mag_filter = GL.NEAREST,
		})

		offscreentex = gl.CreateTexture(vsx,vsy, {
			border = false,
			min_filter = GL.LINEAR,
			mag_filter = GL.LINEAR,
			wrap_s = GL.CLAMP,
			wrap_t = GL.CLAMP,
			fbo = true,
			fboDepth = true,
		})

		blurtex = gl.CreateTexture(vsx,vsy, {
			border = false,
			min_filter = GL.LINEAR,
			mag_filter = GL.LINEAR,
			wrap_s = GL.CLAMP,
			wrap_t = GL.CLAMP,
			fbo = true,
		})
	end

	resChanged = true
end




--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
local lastView = 0
local spGetTimer = Spring.GetTimer
local spDiffTimers = Spring.DiffTimers
local glUnitRaw = gl.UnitRaw
local function DrawVisibleUnits(overrideEngineDraw, perUnitStencil)
	if Cam.frame % (15) == 0 then
		checknow = true
	end


	-- if Spring.GetGameFrame() % 15 == 0 then
	-- 	if DrawVisibleList then glDeleteList(DrawVisibleList) end
	-- 	Echo('create')
	-- 	DrawVisibleList = glCreateList(DrawVisible,'A','B')
	-- 	Echo('call')
	-- 	glCallList(DrawVisibleList)
	-- end
	-- if lastView==NewView[1] then
	-- 	return
	-- end
	-- lastView = NewView[1]

	-- local visibleUnits = Visibles[1]
	-- local visibleUnits = spGetVisibleUnits(ALL_UNITS,nil,false)
	-- local timer = spGetTimer()
	-- Spring.Echo("#visibleUnits is ", #visibleUnits)
	-- Echo("table.size(visibleUnits) is ", table.size(visibleUnits))
	for id in pairs(visibleUnits) do
		-- if i%10 == 0 and spDiffTimers(spGetTimer(),timer) > 0.05 then
		-- 	break
		-- end
		local unit = Units[id]
		if not unit then
			local defID = spGetUnitDefID(id)
			local name = defID and UnitDefs[defID].name
			local humanName = name and UnitDefs[defID].humanName
			Echo('PROBLEM in Outline no shader, no unit for',id,name, humanName,'is valid?',spValidUnitID(id))
		elseif not unit.isCloaked then
			if checknow  --[[and (supercheap and i<100 or not supercheap)--]] then
				local unitProgress = Units[id].health[5]
				if unitProgress == nil or unitProgress >= 0.67 then -- when the nano frame is filled up
					unbuiltUnits[id] = nil
				else
					unbuiltUnits[id] = true
				end
			end

			if --[[supercheap or--]] not unbuiltUnits[id] then
				if perUnitStencil then
					glClear(GL_STENCIL_BUFFER_BIT)
					glStencilFunc(GL_ALWAYS, 0x01, 0xFF)
					glStencilOp(GL_REPLACE, GL_REPLACE, GL_REPLACE)
					glPolygonMode(GL_FRONT_AND_BACK, GL_FILL)
					glUnit(id,true)
					glStencilFunc(GL_NOTEQUAL, 0x01, 0xFF)
					glStencilOp(GL_KEEP, GL_KEEP, GL_KEEP)
					glPolygonMode(GL_FRONT_AND_BACK, GL.LINE)
					glDepthMask(true)
				end
				----- cannot work
				-- local list = lists[id]
				-- if not list then
				-- 	list = glCreateList(glUnit, id, overrideEngineDraw)
				-- 	-- list = glCreateList(function() glUnit(id, overrideEngineDraw) end)
				-- 	lists[id] = list
				-- end
				-- glCallList(lists[id])
				-- Echo("overrideEngineDraw is ", overrideEngineDraw)
				-- glUnit(id, overrideEngineDraw)
				-- glUnit(id, overrideEngineDraw)
				-- Spring.SetUnitNoDraw(id, false)
				-- gl.PushMatrix()
					-- local _,_,_,x,y,z = Spring.GetUnitPosition(id,true)
					-- gl.Translate(1,1,1)
				-- gl.PolygonOffset(8.0, 4.0)
				
				glUnit(id, true) -- this is quite expensive, but didnt find any workaround yet (good outline shader would be better)
					-- gl.UnitShape(Spring.GetUnitDefID(id), Spring.GetMyTeamID(),false)
				-- gl.PopMatrix()
				if perUnitStencil then

					glDepthMask(false)
					glStencilFunc(GL_ALWAYS, 0, 0xFF);
					glStencilOp(GL_REPLACE, GL_REPLACE, GL_REPLACE)
					glPolygonMode(GL_FRONT_AND_BACK,GL_FILL)
					glUnit(id,true)
				end
			end
		end
	end

end

local MyDrawVisibleUnits = function()
	glClear(GL_COLOR_BUFFER_BIT,0,0,0,0)
	glPushMatrix()
	glResetMatrices()
	glColor(0,0,0,thickness * thicknessMult*4)
	DrawVisibleUnits(true)
	glColor(1,1,1,1)
	glPopMatrix()
end

--This is expected to be a shader-less fallback for low-end machines, though it also works for refraction pass
local function DrawVisibleUnitsLines(underwater, frontLines)
	glDepthTest(GL.LESS)
	if underwater then
		gl.LineWidth(3.0 * thickness * thicknessMult)
		gl.PolygonOffset(8.0, 4.0)
	else
		if frontLines then
			if supercheap then
				local relDist = Cam.relDist
				-- gl.LineWidth(2.3)
				local width = math.clamp(2.2 *  1300 / relDist, 1.2, 2.3)
				-- Echo('relDist',Cam.relDist,'width',width,'uncapped',2.2 *  1300 / relDist,'test',2.2 *  1000 / relDist)
				gl.LineWidth(width)--cheap
				gl.PolygonOffset(1.0, 0.0) -- fix the crab and newton
				
			else
				gl.LineWidth(3.0 * thickness * thicknessMult)
				gl.PolygonOffset(10.0, 5.0) -- it gives thicker lines on closer thing
			end
		elseif options.lowQualityOutlines.value then
			gl.LineWidth(4.0 * thickness * thicknessMult)
		end
	end


	glPolygonMode(GL_FRONT_AND_BACK, GL.LINE)
	gl.Culling(GL.FRONT)
	-- glDepthMask(false)
	glColor(0,0,0,1)

	-- glPushMatrix()
	-- glResetMatrices()
	-- gl.StencilTest(true)

	DrawVisibleUnits(true, not supercheap)
	-- gl.StencilTest(false)
	-- glPopMatrix()

	gl.LineWidth(1.0)
	glColor(1,1,1,1)
	gl.Culling(false)
	glPolygonMode(GL_FRONT_AND_BACK, GL_FILL)
	glDepthTest(false)

	-- if underwater then
		gl.PolygonOffset(0.0, 0.0)
	-- end
end

local blur_h = function()
  glClear(GL_COLOR_BUFFER_BIT,0,0,0,0)
  glUseShader(blurShader_h)
  glTexRect(-1-0.5/vsx,1+0.5/vsy,1+0.5/vsx,-1-0.5/vsy)
end

local blur_v = function()
	glClear(GL_COLOR_BUFFER_BIT,0,0,0,0)
	glUseShader(blurShader_v)
	glTexRect(-1-0.5/vsx,1+0.5/vsy,1+0.5/vsx,-1-0.5/vsy)
end
local function GlobalDraw()
	if supercheap then

		glDepthMask(true)
		DrawVisibleUnitsLines(false, true) 
		glDepthMask(false)
	elseif (options.lowQualityOutlines.value or forceLowQuality) then
		DrawVisibleUnitsLines(false)
		glDepthMask(true)
		DrawVisibleUnitsLines(false, true)
		glDepthMask(false)
	else

		glCopyToTexture(depthtex, 0, 0, 0, 0, vsx, vsy)
		glTexture(depthtex)

		if (resChanged) then
			resChanged = false
			if (vsx==1) or (vsy==1) then
				return
			end
			glUseShader(depthShader)
			glUniform(uniformScreenXY,   vsx,vsy )
			glUseShader(blurShader_h)
			glUniformInt(uniformScreenX, vsx )
			glUseShader(blurShader_v)
			glUniformInt(uniformScreenY, vsy )
		end

		glUseShader(depthShader)
		glRenderToTexture(offscreentex,MyDrawVisibleUnits)

		glTexture(offscreentex)
		glRenderToTexture(blurtex, blur_v)
		glTexture(blurtex)
		glRenderToTexture(offscreentex, blur_h)

		glCallList(enter2d)
		glTexture(offscreentex)
		glTexRect(-1-0.5/vsx,1+0.5/vsy,1+0.5/vsx,-1-0.5/vsy)
		glCallList(leave2d)

		-- draw inner lines
		glDepthMask(true)
		DrawVisibleUnitsLines(false, true) 
		glDepthMask(false)
		glTexture(false)
	end
end
function widget:DrawWorldPreUnit()
	if --[[WG.drawingPlacement or WG.EzSelecting or--]] WG.panning then
		return
	end
	if not next(visibleUnits) then
		return
	end
	-- if globalList and lastView == NewView[1] then -- this is actually much slower
	-- else
	-- 	lastView = NewView[1]
	-- 	globalList = glCreateList(GlobalDraw)
	-- end
	-- glCallList(globalList)

	GlobalDraw()
end
function widget:DrawWorldRefraction()
	-- cheaper
	if cheap or supercheap then
		return
	end
	DrawVisibleUnitsLines(true)
end

function widget:UnitCreated(unitID)
	unbuiltUnits[unitID] = true
end

function widget:UnitDestroyed(unitID)
	unbuiltUnits[unitID] = nil
	-- if lists[unitID] then
	-- 	glDeleteList(lists[unitID])
	-- 	lists[unitID] = nil

	-- end

end

local function GetNewThickness()
	if functionScaleWithHeight then
		local cs = Spring.GetCameraState()
		local gy = Spring.GetGroundHeight(cs.px, cs.pz)
		local cameraHeight
		if cs.name == "ta" then
			cameraHeight = cs.height - gy
		else
			cameraHeight = cs.py - gy
		end
		if cameraHeight < SUBTLE_MIN then
			return 1
		end
		if cameraHeight > SUBTLE_MAX then
			thicknessMult = zoomScaleRange
			return zoomScaleRange
		end
		local zoomScale = (((math.cos(math.pi*(cameraHeight - SUBTLE_MIN)/(SUBTLE_MAX - SUBTLE_MIN)) + 1)/2)^3)
		return zoomScale*(1 - zoomScaleRange) + zoomScaleRange
	end
	
	if not scaleWithHeight then
		return
	end
	local cs = Spring.GetCameraState()
	local gy = Spring.GetGroundHeight(cs.px, cs.pz)
	local cameraHeight
	if cs.name == "ta" then
		cameraHeight = cs.height - gy
	else
		cameraHeight = cs.py - gy
	end
	if cameraHeight < 1 then
		cameraHeight = 1
	end
	return 1000/cameraHeight
end

function WidgetRemoveNotify(w,name,preloading)
	if preloading then
		return
	end
	if name == 'HasViewChanged' then
		widgetHandler:Sleep(widget)
	end
end
function WidgetInitNotify(w,name,preloading)
	if preloading then
		return
	end
	if name == 'HasViewChanged' then
		-- Units = WG.UnitsIDCard.units
		widgetHandler:Wake(widget)
	end
end


function widget:Update(dt)
	if supercheap then
		return
	end
	local newThickness = GetNewThickness()
	if newThickness then
		thicknessMult = newThickness
	end
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
function widget:Shutdown()
	if globalList then
		glDeleteList(globalList)
	end
	for id, list in pairs(lists) do
		glDeleteList(list)
	end
	gl.DeleteTexture(depthtex or 0)
	if (gl.DeleteTextureFBO) then
		gl.DeleteTextureFBO(offscreentex or 0)
		gl.DeleteTextureFBO(blurtex or 0)
	end

	if (gl.DeleteShader) then
		gl.DeleteShader(depthShader or 0)
		gl.DeleteShader(blurShader_h or 0)
		gl.DeleteShader(blurShader_v or 0)
	end

	gl.DeleteList(enter2d or 0)
	gl.DeleteList(leave2d or 0)
end
