
function widget:GetInfo()
	return {
		name      = "Reclaim Field Highlight",
		desc      = "Highlights clusters of reclaimable material",
		author    = "ivand, refactored by esainane",
		date      = "2020",
		license   = "public",
		layer     = 0,
		enabled   = false  --  loaded by default?
	}
end
local Echo = Spring.Echo
VFS.Include("LuaRules/Configs/customcmds.h.lua")

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- Options

local flashStrength = 0.0
local fontScaling = 25 / 40
local fontSizeMin = 70
local fontSizeMax = 250

local textParametersChanged = false

local methodUsed = 1

options_path = "Settings/Interface/Reclaim Highlight"
options_order = { 'testmethod','showhighlight', 'flashStrength', 'fontSizeMin', 'fontSizeMax', 'fontScaling' }

options = {
	testmethod = {
		name = 'Faster method of clustering',
		type = 'bool',
		value = false,
		OnChange = function(self)
			methodUsed = self.value and 2 or 1
		end,
	},
	showhighlight = {
		name = 'Show Field Summary',
		type = 'radioButton',
		value = 'constructors',
		items = {
			{key ='always', name='Always'},
			{key ='withecon', name='With the Economy Overlay'},
			{key ='constructors',  name='With Constructors Selected'},
			{key ='conorecon',  name='With Constructors or Overlay'},
			{key ='conandecon',  name='With Constructors and Overlay'},
			{key ='reclaiming',  name='When Reclaiming'},
		},
		noHotkey = true,
	},
	flashStrength = {
		name = "Field flashing strength",
		type = 'number',
		value = flashStrength,
		min = 0.0, max = 0.5, step = 0.05,
		desc = "How intensely the reclaim fields should pulse over time",
		OnChange = function()
			flashStrength = options.flashStrength.value
		end,
	},
	fontSizeMin = {
		name = "Minimum font size",
		type = 'number',
		value = fontSizeMin,
		min = 20, max = 150, step = 10,
		desc = "The smallest font size to use for the smallest reclaim fields",
		OnChange = function()
			fontSizeMin = options.fontSizeMin.value
			textParametersChanged = true
		end,
	},
	fontSizeMax = {
		name = "Maximum font size",
		type = 'number',
		value = fontSizeMax,
		min = 20, max = 300, step = 10,
		desc = "The largest font size to use for the largest reclaim fields",
		OnChange = function()
			fontSizeMax = options.fontSizeMax.value
			textParametersChanged = true
		end,
	},
	fontScaling = {
		name = "Font scaling factor",
		type = 'number',
		value = fontScaling,
		min = 0.2, max = 0.8, step = 0.025,
		desc = "How quickly the font size of the metal value display should grow with the size of the field",
		OnChange = function()
			fontScaling = options.fontScaling.value
			textParametersChanged = true
		end,
	}
}

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- Speedups

local glBeginEnd = gl.BeginEnd
local glBlending = gl.Blending
local glCallList = gl.CallList
local glColor = gl.Color
local glCreateList = gl.CreateList
local glDeleteList = gl.DeleteList
local glDepthTest = gl.DepthTest
local glLineWidth = gl.LineWidth
local glPolygonMode = gl.PolygonMode
local glPopMatrix = gl.PopMatrix
local glPushMatrix = gl.PushMatrix
local glRotate = gl.Rotate
local glText = gl.Text
local glTranslate = gl.Translate
local glVertex = gl.Vertex
local spGetAllFeatures = Spring.GetAllFeatures
local spGetCameraPosition = Spring.GetCameraPosition
local spGetFeatureHeight = Spring.GetFeatureHeight
local spGetFeaturePosition = Spring.GetFeaturePosition
local spGetFeatureResources = Spring.GetFeatureResources
local spGetFeatureTeam = Spring.GetFeatureTeam
local spGetGaiaTeamID = Spring.GetGaiaTeamID
local spGetGameFrame = Spring.GetGameFrame
local spGetGroundHeight = Spring.GetGroundHeight
local spGetMyAllyTeamID = Spring.GetMyAllyTeamID
local spIsGUIHidden = Spring.IsGUIHidden
local spIsPosInLos = Spring.IsPosInLos
local spTraceScreenRay = Spring.TraceScreenRay
local spValidFeatureID = Spring.ValidFeatureID
local spGetActiveCommand = Spring.GetActiveCommand
local spGetActiveCmdDesc = Spring.GetActiveCmdDesc

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- Data

local screenx, screeny

local Benchmark = false and VFS.Include("LuaRules/Gadgets/Include/Benchmark.lua")
local Optics = VFS.Include("LuaRules/Gadgets/Include/Optics.lua")
local ConvexHull = VFS.Include("LuaRules/Gadgets/Include/ConvexHull.lua")

local gaiaTeamId = spGetGaiaTeamID()

local myAllyTeamID
local benchmark = Benchmark and Benchmark.new()

local scanInterval = 1 * Game.gameSpeed
local scanForRemovalInterval = 10 * Game.gameSpeed --10 sec

local minDistance = 300
local minSqDistance = minDistance^2
local minPoints = 2
local minFeatureMetal = 8 --flea

local drawEnabled = true
local BASE_FONT_SIZE = 192

local knownFeatures = {}

--local reclaimColor = (1.0, 0.2, 1.0, 0.7);
local reclaimColor = {1.0, 0.2, 1.0, 0.3}
local reclaimEdgeColor = {1.0, 0.2, 1.0, 0.5}
local E2M = 0 -- doesn't convert too well, plus would be inconsistent since trees aren't counted

local drawFeatureConvexHullSolidList
local drawFeatureConvexHullEdgeList
local drawFeatureClusterTextList
local checkFrequency = 150
local cumDt = 0
local minDim = 100

local featureNeighborsMatrix = {}
local featureConvexHulls = {}
local featureClusters = {}

local featuresUpdated = false
local clusterMetalUpdated = false

local font = gl.LoadFont("FreeSansBold.otf", BASE_FONT_SIZE, 0, 0)


--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- State update

local function UpdateTeamAndAllyTeamID()
	myAllyTeamID = spGetMyAllyTeamID()
end

local function UpdateDrawEnabled()
	if spIsGUIHidden() then
		return false
	end
	if (options.showhighlight.value == 'always')
			or (options.showhighlight.value == 'withecon' and WG.showeco)
			or (options.showhighlight.value == "constructors" and conSelected)
			or (options.showhighlight.value == 'conorecon' and (conSelected or WG.showeco))
			or (options.showhighlight.value == 'conandecon' and (conSelected and WG.showeco)) then
		return true
	end
	
	local currentCmd = spGetActiveCommand()
	if currentCmd then
		local activeCmdDesc = spGetActiveCmdDesc(currentCmd)
		return (activeCmdDesc and (activeCmdDesc.name == "Reclaim" or activeCmdDesc.name == "Resurrect"))
	end
	return false
end

function widget:SelectionChanged(units)
	if (WG.selectionEntirelyCons) then
		conSelected = true
	else
		conSelected = false
	end
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- Feature Tracking

local function UpdateFeatureNeighborsMatrix(fID, added, posChanged, removed)
	if methodUsed >1 then
		return
	end
	local fInfo = knownFeatures[fID]

	if added then
		featureNeighborsMatrix[fID] = {}
		for fID2, fInfo2 in pairs(knownFeatures) do
			if fID2 ~= fID then --don't include self into featureNeighborsMatrix[][]
				local sqDist = (fInfo.x - fInfo2.x)^2 + (fInfo.z - fInfo2.z)^2
				if sqDist <= minSqDistance then
					featureNeighborsMatrix[fID][fID2] = true
					featureNeighborsMatrix[fID2][fID] = true
				end
			end
		end
	end

	if removed then
		for fID2, _ in pairs(featureNeighborsMatrix[fID]) do
			featureNeighborsMatrix[fID2][fID] = nil
			featureNeighborsMatrix[fID][fID2] = nil
		end
	end

	if posChanged then
		UpdateFeatureNeighborsMatrix(fID, false, false, true) --remove
		UpdateFeatureNeighborsMatrix(fID, true, false, false) --add again
	end
end

local function UpdateFeatures(gf)
	if benchmark then
		benchmark:Enter("UpdateFeatures")
	end
	featuresUpdated = false
	clusterMetalUpdated = false
	if benchmark then
		benchmark:Enter("UpdateFeatures 1loop")
	end

	for _, fID in ipairs(spGetAllFeatures()) do
		local metal, _, energy = spGetFeatureResources(fID)
		metal = metal + energy * E2M
		local fInfo = knownFeatures[fID]
		if (not fInfo) and (metal >= minFeatureMetal) then --first time seen
			local f = {}
			f.lastScanned = gf

			local fx, _, fz = spGetFeaturePosition(fID)
			local fy = spGetGroundHeight(fx, fz)
			f.x = fx
			f.y = fy
			f.z = fz

			f.isGaia = (spGetFeatureTeam(fID) == gaiaTeamId)
			f.height = spGetFeatureHeight(fID)
			f.drawAlt = ((fy > 0 and fy) or 0) + f.height + 10

			f.metal = metal

			fInfo = f
			knownFeatures[fID] = f
			UpdateFeatureNeighborsMatrix(fID, true, false, false)
			featuresUpdated = true
		end

		if fInfo and gf - fInfo.lastScanned >= scanInterval then
			fInfo.lastScanned = gf

			local fx, _, fz = spGetFeaturePosition(fID)
			local fy = spGetGroundHeight(fx, fz)

			if fInfo.x ~= fx or fInfo.y ~= fy or fInfo.z ~= fz then
				fInfo.x = fx
				fInfo.y = fy
				fInfo.z = fz

				fInfo.drawAlt = ((fy > 0 and fy) or 0) + fInfo.height + 10
				UpdateFeatureNeighborsMatrix(fID, false, true, false)
				featuresUpdated = true
			end

			if fInfo.metal ~= metal then
				--Spring.Echo("fInfo.metal ~= metal", metal)
				if fInfo.clID then
					--Spring.Echo("fInfo.clID")
					local thisCluster = featureClusters[ fInfo.clID ]
					thisCluster.metal = thisCluster.metal - fInfo.metal
					if metal >= minFeatureMetal then
						thisCluster.metal = thisCluster.metal + metal
						fInfo.metal = metal
						--Spring.Echo("clusterMetalUpdated = true", thisCluster.metal)
						clusterMetalUpdated = true
					else
						UpdateFeatureNeighborsMatrix(fID, false, false, true)
						fInfo = nil
						knownFeatures[fID] = nil
						featuresUpdated = true
					end
				end
			end
		end
	end

	if benchmark then
		benchmark:Leave("UpdateFeatures 1loop")
		benchmark:Enter("UpdateFeatures 2loop")
	end

	for fID, fInfo in pairs(knownFeatures) do
		if fInfo.isGaia and spValidFeatureID(fID) == false then
			--Spring.Echo("fInfo.isGaia and spValidFeatureID(fID) == false")

			UpdateFeatureNeighborsMatrix(fID, false, false, true)
			fInfo = nil
			knownFeatures[fID] = nil
			featuresUpdated = true
		end

		if fInfo and gf - fInfo.lastScanned >= scanForRemovalInterval then --long time unseen features, maybe they were relcaimed or destroyed?
			local los = spIsPosInLos(fInfo.x, fInfo.y, fInfo.z, myAllyTeamID)
			if los then --this place has no feature, it's been moved or reclaimed or destroyed
				--Spring.Echo("this place has no feature, it's been moved or reclaimed or destroyed")

				UpdateFeatureNeighborsMatrix(fID, false, false, true)
				fInfo = nil
				knownFeatures[fID] = nil
				featuresUpdated = true
			end
		end

		if fInfo and featuresUpdated then
			knownFeatures[fID].clID = nil
		end
	end
	
	if benchmark then
		benchmark:Leave("UpdateFeatures 2loop")
		benchmark:Leave("UpdateFeatures")
	end
end

local spGetTimer,spDiffTimers = Spring.GetTimer, Spring.DiffTimers
local huge = math.huge
local GroupClusters = function(clusters) -- not used/finished yet, complement method 2 to gather clusters
	local mids
	for i = 1, clusters.n do
		local cluster = clusters[i]
		local cnt = cluster.n
		for j = 1, cnt do
			local obj = cluster[j]
			local  x, z = obj[2], obj[3]
			totalx, totalz = totalx + x, totalz + z
		end
		cluster.mid = {totalx/cnt, totalz/cnt}
	end
	for i = 1, clusters.n do
		local cluster = clusters[i]
		if cluster.n > 1 then
			--- . . .
		end
	end
end
local function ClusterizeFeatures()

	local time1, time2
	local debugCluster = true
	if methodUsed == 2 then
		local pointsTable = {}

		--Spring.Echo("#knownFeatures", #knownFeatures)
	    if debugCluster then
	        time1 = spGetTimer()
	    end
		local n = 0
		for fID, fInfo in pairs(knownFeatures) do
			n = n + 1
			local x, z = fInfo.x, fInfo.z
			pointsTable[n] = {
				fID, x, z,
				x = x,
				z = z,
				fID = fID,
			}
		end
		pointsTable.n = n 
		for k in pairs(featureClusters or {}) do
			featureClusters[k] = nil
		end
	    if debugCluster then
	        time1 = spDiffTimers(spGetTimer(),time1)
	        if time1>0.1 then
	        	Echo(widget:GetInfo().name .. ': collecting features took more than 0.1 sec!  ', time1)
	        end
	        time2 = spGetTimer()
	    end

		local clusters = WG.DBSCAN_cluster3(pointsTable,minDistance,1)
		for i=1, clusters.n do
			local cluster = clusters[i]
			local members = {}
			local metal = 0
			local xmin, xmax, zmin, zmax = huge, -huge, huge, -huge
			for j = 1, cluster.n do
				local obj = cluster[j]
				local fID, x, z = obj[1], obj[2], obj[3]
				members[j] = fID
				local fInfo = knownFeatures[fID]
				metal = metal + fInfo.metal
				if x < xmin then xmin = x end
				if x > xmax then xmax = x end
				if z < zmin then zmin = z end
				if z > zmax then zmax = z end
				fInfo.clID = i
			end
			featureClusters[i] = {
				members = members,
				metal = metal,
				xmin = xmin,
				xmax = xmax,
				zmin = zmin,
				zmax = zmax,
			}
		end
	end
	if methodUsed == 1 then
	    if debugCluster then
	        time1 = spGetTimer()
	    end

		if benchmark then
			benchmark:Enter("ClusterizeFeatures")
		end
		local pointsTable = {}
		local unclusteredPoints  = {}

		--Spring.Echo("#knownFeatures", #knownFeatures)
		local n = 0
		for fID, fInfo in pairs(knownFeatures) do
			n = n + 1
			pointsTable[n] = {
				x = fInfo.x,
				z = fInfo.z,
				fID = fID,
			}
			unclusteredPoints[fID] = true
		end

	--TableEcho(featureNeighborsMatrix, "featureNeighborsMatrix")
		local opticsObject = Optics.new(pointsTable, featureNeighborsMatrix, minPoints, benchmark)
		if benchmark then
			benchmark:Enter("opticsObject:Run()")
		end
		opticsObject:Run()
		
		if benchmark then
			benchmark:Leave("opticsObject:Run()")
			benchmark:Enter("opticsObject:Clusterize(minDistance)")
		end
		featureClusters = opticsObject:Clusterize(minDistance)
		if benchmark then
			benchmark:Leave("opticsObject:Clusterize(minDistance)")
		end
	    if debugCluster then
	        time1 = spDiffTimers(spGetTimer(),time1)
	        time2 = spGetTimer()
	    end

		--Spring.Echo("#featureClusters", #featureClusters)

		for i = 1, #featureClusters do
			local thisCluster = featureClusters[i]
			local xmin, xmax, zmin, zmax = huge, -huge, huge, -huge

			local metal = 0
			for j = 1, #thisCluster.members do
				local fID = thisCluster.members[j]
				local fInfo = knownFeatures[fID]
				local x, z = fInfo.x, fInfo.z
				if x < xmin then xmin = x end
				if x > xmax then xmax = x end
				if z < zmin then zmin = z end
				if z > zmax then zmax = z end

				metal = metal + fInfo.metal
				knownFeatures[fID].clID = i
				unclusteredPoints[fID] = nil
			end
			thisCluster.xmin = xmin
			thisCluster.xmax = xmax
			thisCluster.zmin = zmin
			thisCluster.zmax = zmax

			thisCluster.metal = metal
		end

		for fID, _ in pairs(unclusteredPoints) do --add Singlepoint featureClusters
			local fInfo = knownFeatures[fID]
			local thisCluster = {}

			thisCluster.members = {fID}
			thisCluster.metal = fInfo.metal

			thisCluster.xmin = fInfo.x
			thisCluster.xmax = fInfo.x
			thisCluster.zmin = fInfo.z
			thisCluster.zmax = fInfo.z

			featureClusters[#featureClusters + 1] = thisCluster
			knownFeatures[fID].clID = #featureClusters
		end

		if benchmark then
			benchmark:Leave("ClusterizeFeatures")
		end
	end
    if debugCluster then
        time2 = spDiffTimers(spGetTimer(),time2)
        -- Echo('clusters processed in ' .. time1 .. ' + ' .. time2 .. ' = ' .. time1 + time2 )
        if time2>0.1 then
        	Echo(widget:GetInfo().name .. ': clusterizing features took more than 0.1 sec!  ', time1)
        end

    end
end
local sqrt = math.sqrt
local function ClustersToConvexHull()
	if benchmark then
		benchmark:Enter("ClustersToConvexHull")
	end
	featureConvexHulls = {}
	--Spring.Echo("#featureClusters", #featureClusters)
	for fc = 1, #featureClusters do
		local clusterPoints = {}
		if benchmark then
			benchmark:Enter("ClustersToConvexHull 1st Part")
		end
		local n = 0
		local members = featureClusters[fc].members
		for fcm = 1, #members do
			local fID = members[fcm]
			local feature = knownFeatures[fID]
			n = n + 1
			clusterPoints[n] = {
				x = feature.x,
				y = feature.drawAlt,
				z = feature.z
			}
			--spMarkerAddPoint(knownFeatures[fID].x, 0, knownFeatures[fID].z, string.format("%i(%i)", fc, fcm))
		end
		if benchmark then
			benchmark:Leave("ClustersToConvexHull 1st Part")
		end
		
		--- TODO perform pruning as described in the article below, if convex hull algo will start to choke out
		-- http://mindthenerd.blogspot.ru/2012/05/fastest-convex-hull-algorithm-ever.html
		
		if benchmark then
			benchmark:Enter("ClustersToConvexHull 2nd Part")
		end
		local convexHull
		if clusterPoints[3] then
			--Spring.Echo("#clusterPoints >= 3")
			--convexHull = ConvexHull.JarvisMarch(clusterPoints, benchmark)
			convexHull = ConvexHull.MonotoneChain(clusterPoints, benchmark) --twice faster
		else
			--Spring.Echo("not #clusterPoints >= 3")
			local thisCluster = featureClusters[fc]

			local xmin, xmax, zmin, zmax = thisCluster.xmin, thisCluster.xmax, thisCluster.zmin, thisCluster.zmax

			local dx, dz = xmax - xmin, zmax - zmin

			if dx < minDim then
				xmin = xmin - (minDim - dx) / 2
				xmax = xmax + (minDim - dx) / 2
			end

			if dz < minDim then
				zmin = zmin - (minDim - dz) / 2
				zmax = zmax + (minDim - dz) / 2
			end

			local height = clusterPoints[1].y
			if clusterPoints[2] then
				height = math.max(height, clusterPoints[2].y)
			end

			convexHull = {
				{x = xmin, y = height, z = zmin},
				{x = xmax, y = height, z = zmin},
				{x = xmax, y = height, z = zmax},
				{x = xmin, y = height, z = zmax},
			}
		end

		local cx, cz, cy = 0, 0, 0
		local n = #convexHull
		for i = 1, n do
			local convexHullPoint = convexHull[i]
			cx = cx + convexHullPoint.x
			cz = cz + convexHullPoint.z
			cy = math.max(cy, convexHullPoint.y)
		end

		if benchmark then
			benchmark:Leave("ClustersToConvexHull 2nd Part")
			benchmark:Enter("ClustersToConvexHull 3rd Part")
		end
		
		local totalArea = 0
		local pt1, pt2 = convexHull[1], convexHull[2]
		local x1, z1 = pt1.x, pt1.z
		local x2, z2 = pt2.x, pt2.z
		local a = sqrt((x2 - x1)^2 + (z2 - z1)^2)
		for i = 3, n do
			local pt3 = convexHull[i]
			--Heron formula to get triangle area
			local x3, z3  =  pt3.x, pt3.z
			local b = sqrt((x3 - x2)^2 + (z3 - z2)^2)
			local c = sqrt((x3 - x1)^2 + (z3 - z1)^2)
			local p = (a + b + c)/2 --half perimeter

			local triangleArea = sqrt(p * (p - a) * (p - b) * (p - c))
			totalArea = totalArea + triangleArea
			x2, z2 = x3, z3
			a = c
		end
		if benchmark then
			benchmark:Leave("ClustersToConvexHull 3rd Part")
		end
		
		convexHull.area = totalArea
		convexHull.center = {x = cx/n, z = cz/n, y = cy + 1}

		featureConvexHulls[fc] = convexHull


		--for i = 1, #convexHull do
		--	spMarkerAddPoint(convexHull[i].x, convexHull[i].y, convexHull[i].z, string.format("C%i(%i)", fc, i))
		--end

		if benchmark then
			benchmark:Leave("ClustersToConvexHull")
		end
	end
end

local function ColorMul(scalar, actionColor)
	return {scalar * actionColor[1], scalar * actionColor[2], scalar * actionColor[3], actionColor[4]}
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

widget.TeamChanged = UpdateTeamAndAllyTeamID
widget.PlayerChanged = UpdateTeamAndAllyTeamID
widget.Playeradded = UpdateTeamAndAllyTeamID
widget.PlayerRemoved = UpdateTeamAndAllyTeamID
widget.TeamDied = UpdateTeamAndAllyTeamID

function widget:Initialize()
	Spring.Echo(widget.GetInfo().name .. " initialize.")

	UpdateTeamAndAllyTeamID()
	screenx, screeny = widgetHandler:GetViewSizes()
	widget:SelectionChanged()
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- Drawing
local color
local cameraScale

local function DrawHullVertices(hull)
	for j = 1, #hull do
		glVertex(hull[j].x, hull[j].y, hull[j].z)
	end
end

local function DrawFeatureConvexHullSolid()
	glPolygonMode(GL.FRONT_AND_BACK, GL.FILL)
	for i = 1, #featureConvexHulls do
		glBeginEnd(GL.TRIANGLE_FAN, DrawHullVertices, featureConvexHulls[i])
	end
end

local function DrawFeatureConvexHullEdge()
	glPolygonMode(GL.FRONT_AND_BACK, GL.LINE)
	for i = 1, #featureConvexHulls do
		glBeginEnd(GL.LINE_LOOP, DrawHullVertices, featureConvexHulls[i])
	end
	glPolygonMode(GL.FRONT_AND_BACK, GL.FILL)
end

local function DrawFeatureClusterText()
	for i = 1, #featureConvexHulls do
		glPushMatrix()

		local center = featureConvexHulls[i].center

		glTranslate(center.x, center.y, center.z)
		glRotate(-90, 1, 0, 0)

		local fontSize = fontSizeMin * fontScaling
		local area = featureConvexHulls[i].area
		fontSize = math.sqrt(area) * fontSize / minDim
		fontSize = math.max(fontSize, fontSizeMin)
		fontSize = math.min(fontSize, fontSizeMax)

		local metal = featureClusters[i].metal
		--Spring.Echo(metal)
		local metalText
		if metal < 1000 then
			metalText = string.format("%.0f", metal) --exact number
		elseif metal < 10000 then
			metalText = string.format("%.1fK", math.floor(metal / 100) / 10) --4.5K
		else
			metalText = string.format("%.0fK", math.floor(metal / 1000)) --40K
		end
		gl.Scale(fontSize / BASE_FONT_SIZE, fontSize / BASE_FONT_SIZE, fontSize / BASE_FONT_SIZE)

		local x100  = 100  / (100  + metal)
		local x1000 = 1000 / (1000 + metal)
		local r = 1 - x1000
		local g = x1000 - x100
		local b = x100

		--glRect(-200, -200, 200, 200)
		--glColor(r, g, b, 1.0)
		--glText(metalText, 0, 0, fontSize, "cv")
		font:Begin()
			font:SetTextColor(r, g, b, 1.0)
			font:Print(metalText, 0, 0, BASE_FONT_SIZE, "cv")
		font:End()

		glPopMatrix()
	end
end
local wasDisabled = true

function widget:Update(dt)
	cumDt = cumDt + dt
	local cx, cy, cz = spGetCameraPosition()

	local desc, w = spTraceScreenRay(screenx / 2, screeny / 2, true)
	if desc then
		local cameraDist = math.min( 8000, math.sqrt( (cx-w[1])^2 + (cy-w[2])^2 + (cz-w[3])^2 ) )
		cameraScale = math.sqrt((cameraDist / 600)) --number is an "optimal" view distance
	else
		cameraScale = 1.0
	end

	local isEnabled = UpdateDrawEnabled()
	wasDisabled = isEnabled and not drawEnabled
	drawEnabled = isEnabled

	local frame = spGetGameFrame()
	color = 0.5 + flashStrength * (frame % checkFrequency - checkFrequency)/(checkFrequency - 1)
	if color < 0 then
		color = 0
	end
	if color > 1 then
		color = 1
	end
end
function widget:GameFrame(frame)

	if not drawEnabled then
		return
	end
	local frameMod = frame % checkFrequency
	if frameMod ~= 0  and not wasDisabled then
		return
	end
	if benchmark then
		benchmark:Enter("GameFrame UpdateFeatures")
	end
	UpdateFeatures(frame)
	if featuresUpdated or (drawFeatureConvexHullSolidList == nil) then
		ClusterizeFeatures()
		ClustersToConvexHull()
		
		if benchmark then
			benchmark:Enter("featuresUpdated or drawFeatureConvexHullSolidList == nil")
		end
		--Spring.Echo("featuresUpdated")
		if drawFeatureConvexHullSolidList then
			glDeleteList(drawFeatureConvexHullSolidList)
			drawFeatureConvexHullSolidList = nil
		end

		if drawFeatureConvexHullEdgeList then
			glDeleteList(drawFeatureConvexHullEdgeList)
			drawFeatureConvexHullEdgeList = nil
		end

		drawFeatureConvexHullSolidList = glCreateList(DrawFeatureConvexHullSolid)
		drawFeatureConvexHullEdgeList = glCreateList(DrawFeatureConvexHullEdge)
		if benchmark then
			benchmark:Leave("featuresUpdated or drawFeatureConvexHullSolidList == nil")
		end
	end

	if textParametersChanged or featuresUpdated or clusterMetalUpdated or drawFeatureClusterTextList == nil then
		if benchmark then
			benchmark:Enter("featuresUpdated or clusterMetalUpdated or drawFeatureClusterTextList == nil")
		end
		--Spring.Echo("clusterMetalUpdated")
		if drawFeatureClusterTextList then
			glDeleteList(drawFeatureClusterTextList)
			drawFeatureClusterTextList = nil
		end
		drawFeatureClusterTextList = glCreateList(DrawFeatureClusterText)
		textParametersChanged = false
		if benchmark then
			benchmark:Leave("featuresUpdated or clusterMetalUpdated or drawFeatureClusterTextList == nil")
		end
	end
	if benchmark then
		benchmark:Leave("GameFrame UpdateFeatures")
	end
end

function widget:ViewResize(viewSizeX, viewSizeY)
	screenx, screeny = widgetHandler:GetViewSizes()
end

function widget:DrawWorld()
	if --[[spIsGUIHidden() or--]] not drawEnabled then
		return
	end

	glDepthTest(false)
	--glDepthTest(true)

	glBlending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA)
	if drawFeatureConvexHullSolidList then
		glColor(ColorMul(color, reclaimColor))
		glCallList(drawFeatureConvexHullSolidList)
		--DrawFeatureConvexHullSolid()
	end

	if drawFeatureConvexHullEdgeList then
		glLineWidth(6.0 / cameraScale)
		glColor(ColorMul(color, reclaimEdgeColor))
		glCallList(drawFeatureConvexHullEdgeList)
		--DrawFeatureConvexHullEdge()
		glLineWidth(1.0)
	end

	if drawFeatureClusterTextList then
		glCallList(drawFeatureClusterTextList)
		--DrawFeatureClusterText()
	end

	glDepthTest(true)
end

function widget:Shutdown()
	if drawFeatureConvexHullSolidList then
		glDeleteList(drawFeatureConvexHullSolidList)
	end
	if drawFeatureConvexHullEdgeList then
		glDeleteList(drawFeatureConvexHullEdgeList)
	end
	if drawFeatureClusterTextList then
		glDeleteList(drawFeatureClusterTextList)
	end
	if benchmark then
		benchmark:PrintAllStat()
	end
end
