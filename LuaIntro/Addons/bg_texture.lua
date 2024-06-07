
if addon.InGetInfo then
	return {
		name    = "LoadTexture",
		desc    = "",
		author  = "jK",
		date    = "2012",
		license = "GPL2",
		layer   = 2,
		depend  = {"LoadProgress"},
		enabled = true,
	}
end

------------------------------------------
local ROTATE = false -- can be 'LOAD PROGRESS' or just true and it will rotate by load progress or time elapsed, can be false or nil and it will never rotate
local ROTATION_TIME = 10 
local LOAD_PROGRESS_ROTATE = {0.25, 0.50, 0.75} -- each step to trigger a new rotation if ROTATE is 'LOAD PROGRESS'
local progressZone = 0


local Echo = Spring.Echo


local loadscreens = VFS.DirList("bitmaps/loadpictures/")

local backgroundTexture

local len = #loadscreens
local current = math.random(len)
if len ~= 0 then
	backgroundTexture = loadscreens[ current ]
end
local aspectRatio
local time = os.clock()

local function Rotate()
	local tries = 0
	while tries < 100 do
		tries = tries + 1
		local newCurrent = math.random(len)
		if newCurrent ~= current then
			current = newCurrent
			if backgroundTexture then
				gl.DeleteTexture(backgroundTexture)
			end
			backgroundTexture = loadscreens[ current ]
			aspectRatio = nil
		end
	end
end

local function UpdateTexture(loadProgress)
	if len <= 1 or not ROTATE then
		return
	end
	if ROTATE == 'LOAD PROGRESS' then
		for i = #LOAD_PROGRESS_ROTATE, 1, -1 do
			if loadProgress > LOAD_PROGRESS_ROTATE[i] then
				if i ~= progressZone then
					progressZone = i
					Rotate()
				end
			end
		end
	else
		local now = os.clock()
		if now - time > ROTATION_TIME then
			time = now
			Rotate()
		end
	end
end

function addon.DrawLoadScreen()
	if backgroundTexture == nil then
		return
	end

	local loadProgress = SG.GetLoadProgress()
	UpdateTexture(loadProgress)

	if not aspectRatio then
		local texInfo = gl.TextureInfo(backgroundTexture)
		if not texInfo then return end
		aspectRatio = texInfo.xsize / texInfo.ysize
	end

	local vsx, vsy = gl.GetViewSizes()
	local screenAspectRatio = vsx / vsy

	local xDiv = 0
	local yDiv = 0
	local ratioComp = screenAspectRatio / aspectRatio

	if (ratioComp > 1) then
		xDiv = (1 - (1 / ratioComp)) * 0.5;
	elseif (math.abs(ratioComp - 1) < 0) then
	else
		yDiv = (1 - ratioComp) * 0.5;
	end

	-- background
	--fade in: gl.Color(1,1,1,1 - (1 - loadProgress)^5)
	gl.Color(1,1,1,1)
	gl.Texture(backgroundTexture)
	gl.TexRect(0+xDiv,0+yDiv,1-xDiv,1-yDiv)
	gl.Texture(false)


end

function addon.Shutdown()
	if backgroundTexture == nil then
		return
	end
	gl.DeleteTexture(backgroundTexture)
end
