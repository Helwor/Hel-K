--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
function widget:GetInfo()
  return {
    name      = "Cluster Detection",
    desc      = "Unit cluster detection API",
    author    = "msafwan",
    date      = "2011.10.22",
    license   = "GNU GPL, v2 or later",
    layer     = 0,
    enabled   = true,
	api = true,
	-- alwaysStart = true,
  }
end
local Echo = Spring.Echo
local echoOutCalculationTime = false
local spGetTimer = Spring.GetTimer
local spDiffTimers = Spring.DiffTimers

---------------------------------------------------------------------------------
-----------C L U S T E R   D E T E C T I O N   T O O L --------------------------
---------------------------------------------------------------------------------
--Note: maintained by msafwan (xponen)
--Positional Functions------------------------------------------------------------
-- 3 function.
local searchCount = 0
local modf = math.modf
local testcnt = 0
local function BinarySearchNaturalOrder(position, orderedList)
	local timer --= spGetTimer()
	local startPos = 1
	local endPos = orderedList.n or #orderedList
	local span = endPos - startPos
	local midPos = modf((span/2) + startPos + 0.5) --round to nearest integer
	local found = false
	while (span > 1) do
		local difference = position - orderedList[midPos][2]
 
		if difference < 0 then
			endPos = midPos
		elseif difference > 0 then
			startPos = midPos
		else
			found=true
			break;
		end
		
		span = endPos - startPos
		midPos = modf((span/2) + startPos + 0.5) --round to nearest integer
	end
	if not found then
		if(math.abs(position - orderedList[startPos][2]) < math.abs(position - orderedList[endPos][2])) then
			midPos = startPos
		else
			midPos = endPos
		end
	end
	searchCount = searchCount  --+ spDiffTimers(spGetTimer(), timer)
	return midPos
end

local distCount = 0
local function GetDistanceSQ(unit1, unit2)
	local timer --= spGetTimer()
	local distanceSQ = ((unit1[1]-unit2[1])^2 + (unit1[3]-unit2[3])^2)
	distCount = distCount  --+ spDiffTimers(spGetTimer(), timer)
	return distanceSQ
end

local intersectionCount = 0
local abs = math.abs
local function GetUnitsInSquare(x,z,distance,posListX)
	local unitIndX = BinarySearchNaturalOrder(x, posListX)
	testcnt = testcnt + 1
	-- Echo('unitIndX #' .. testcnt, unitIndX)
	local unitsX, ux_n = {}, 0
	for i = unitIndX, 1, -1 do --go left
		local pos = posListX[i]
		if x - pos[2] > distance then
			break
		end
		ux_n = ux_n + 1
		unitsX[ux_n]=pos
	end
	for i = unitIndX+1, posListX.n, 1 do --go right
		local pos = posListX[i]
		if pos[2]-x > distance then
			break
		end
		ux_n = ux_n + 1
		unitsX[ux_n]=pos
	end
	unitsX.n = ux_n
	if ux_n == 0 then
		return unitsX
	end
	local timer --= spGetTimer()
	local unitsInBox, n = {}, 0
	for i=1, ux_n, 1 do
		local unitX = unitsX[i] 
		if (abs(unitX[3]-z) <= distance) then
			n = n + 1
			unitsInBox[n] = unitX
		end
	end
	unitsInBox.n = n
	intersectionCount = intersectionCount --+ spDiffTimers(spGetTimer(), timer)
	return unitsInBox
end
local function GetUnitsInSquareByID(x,z,distance,posListX)
	local unitIndX = BinarySearchNaturalOrder(x, posListX)
	local unitsX, ux_n = {n=0}, 0
	for i = unitIndX, 1, -1 do --go left
		if x - posListX[i][2] > distance then
			break
		end
		ux_n = ux_n + 1
		unitsX[ux_n]=posListX[i]
	end
	for i = unitIndX+1, posListX.n, 1 do --go right
		if posListX[i][2]-x > distance then
			break
		end
		ux_n = ux_n + 1
		unitsX[ux_n]=posListX[i]
	end
	if ux_n == 0 then
		return unitsX
	end
	local timer --= spGetTimer()
	local unitsInBox, n = {n=0}, 0
	for i=1, ux_n, 1 do
		if (math.abs(unitsX[i][3]-z) <= distance) then
			n = n + 1
			unitsInBox[ unitsX[i][1] ] = true
		end
	end
	unitsInBox.n = n

	intersectionCount = intersectionCount --+ spDiffTimers(spGetTimer(), timer)
	return unitsInBox
end

--GetNeigbors--------------------------------------------------------------------
-- 1 function.
local getunitCount = 0
local function GetNeighbor (unit, neighborhoodRadius, posListX) --//return the unitIDs of specific units around a center unit
	local timer --= spGetTimer()
	local tempList = GetUnitsInSquare(unit[1],unit[3],neighborhoodRadius,posListX) --Get neighbor. Ouput: unitID + my units
	getunitCount = getunitCount  --+ spDiffTimers(spGetTimer(), timer)
	return tempList
end
local function GetNeighborByID (unit, neighborhoodRadius, posListX) --//return the unitIDs of specific units around a center unit
	local timer --= spGetTimer()
	local tempList = GetUnitsInSquareByID(unit[1],unit[3],neighborhoodRadius,posListX) --Get neighbor. Ouput: unitID + my units
	getunitCount = getunitCount  --+ spDiffTimers(spGetTimer(), timer)
	return tempList
end

--Pre-SORTING function----------------------------------------------------------------
--3 function
local function InsertAtOrder(posList, newObject,compareFunction) --//stack big values at end of table, and tiny values at start of table.
	posList.n = posList.n or #posList
	local insertionIndex = posList.n + 1 --//insert data just below that big value
	for i = posList.n, 1, -1 do
		if compareFunction(posList[i],newObject) then-- posList[i] < newObject will sort in ascending order, while  posList[i] > newObject will sort in descending order
			break
		end
		insertionIndex=i
	end
	
	--//shift table content
	-- local buffer1 = posList[insertionIndex] --backup content of current index
	-- posList[insertionIndex] = newObject --replace current index with new value. eg: {unitID = objects.unitID , x = objects.x, z = objects.z }
	-- for j = insertionIndex, posList.n, 1 do --shift content for content less-or-equal-to table length
	-- 	local buffer2 = posList[j+1] --save content of next index
	-- 	posList[j+1] = buffer1 --put backup value into next index
	-- 	buffer1 = buffer2 --use saved content as next backup, then repeat process
	-- end
	-- simpler and faster
	for j = posList.n, insertionIndex, -1 do
		posList[j+1] = posList[j]
	end
	posList[insertionIndex] = newObject
	posList.n = posList.n + 1
	return posList
end

local insertCount = 0
local function InsertOrderSeed (orderSeed, unitID_to_orderSeedMeta, object) --//stack tiny values at end of table, and big values at start of table.
	local timer --= spGetTimer()
	local orderSeedLength = orderSeed.n --//code below can handle both: table of length 0 and >1
	local insertionIndex = orderSeedLength + 1 --//insert data just above that big value
	for i = orderSeedLength, 1, -1 do
		if orderSeed[i].content.reachability_distance >= object.reachability_distance then --//if existing value is abit bigger than to-be-inserted value: break
			break
		end
		insertionIndex=i
	end

	-- --//shift table content
	-- local buffer1 = orderSeed[insertionIndex] --backup content of current index
	-- orderSeed[insertionIndex] = {unitID = unitID , content = object} --replace current index with new value
	-- unitID_to_orderSeedMeta[unitID]=insertionIndex --update meta table
	-- for j = insertionIndex, orderSeedLength, 1 do --shift content for content less-or-equal-to table length
	-- 	local buffer2 = orderSeed[j+1] --save content of next index
	-- 	orderSeed[j+1] = buffer1 --put backup value into next index
	-- 	unitID_to_orderSeedMeta[buffer1.unitID]=j+1 -- update meta table
	-- 	buffer1 = buffer2 --use saved content as next backup, then repeat process
	-- end

	for j = orderSeedLength, insertionIndex, -1 do
		local seed = orderSeed[j]
		orderSeed[j+1] = seed
		unitID_to_orderSeedMeta[seed.unitID]=j+1
	end
	orderSeed[insertionIndex] = {unitID = object.unitID , content = object}
	unitID_to_orderSeedMeta[unitID] = insertionIndex


	insertCount = insertCount +  spDiffTimers(spGetTimer(), timer)

end

local shiftCount = 0
local function ShiftOrderSeed (orderSeed, unitID_to_orderSeedMeta, object) --//move values to end of table, and shift big values to beginning of of table.
	local timer --= spGetTimer()
	local newseed = {unitID = object.unitID , content = object}
	local oldPosition = unitID_to_orderSeedMeta[unitID]
	local newPosition = oldPosition
	for i = oldPosition+1, orderSeed.n, 1 do
		if orderSeed[i].content.reachability_distance < object.reachability_distance then --//if existing value is abit lower than to-be-inserted value: add behind it and break
			break
		end
		newPosition = i
	end

	if newPosition == oldPosition then
		orderSeed[oldPosition]= newseed
	else
		-- local buffer1 = orderSeed[newPosition] --//backup content of current index
		-- orderSeed[newPosition] = {unitID = unitID , content = object} --//replace current index with new value
		-- unitID_to_orderSeedMeta[unitID]=newPosition --//update meta table
		-- orderSeed[oldPosition] = nil --//delete old position
		-- for j = newPosition-1, oldPosition, -1 do --//shift values toward beginning of table
		-- 	local buffer2 = orderSeed[j] --//save content of current index
		-- 	orderSeed[j] = buffer1 --//put backup value into previous index
		-- 	unitID_to_orderSeedMeta[buffer1.unitID]=j --// update meta table
		-- 	buffer1 = buffer2 --//use saved content as the following backup, then repeat process
		-- end
		for j = newPosition, oldPosition+1, -1 do --//shift values toward beginning of table
			local seed = orderSeed[j]
			orderSeed[j-1] = seed
			unitID_to_orderSeedMeta[seed.unitID]=j-1
		end
		orderSeed[newPosition] = newseed
		unitID_to_orderSeedMeta[unitID]=newPosition

	end
	shiftCount = shiftCount --+ spDiffTimers(spGetTimer(), timer)
end

--Merge-SORTING function----------------------------------------------------------------
--2 function. Reference: http://www.algorithmist.com/index.php/Merge_sort.c
local function merge(left, right, CompareFunction)
    local result, res_n ={},0 --var list result
	local leftProgress, rightProgress = 1,1
	local leftLen, rightLen = #left, #right
	local leftNotFinish = leftProgress <= leftLen
	local rightNotFinish = rightProgress <= rightLen

    while leftNotFinish or rightNotFinish do --while length(left) > 0 or length(right) > 0
    	res_n = res_n + 1
        if leftNotFinish and rightNotFinish then --if length(left) > 0 and length(right) > 0
            if CompareFunction(left[leftProgress],right[rightProgress]) then --if first(left) < first(right), sort ascending. if first(left) > first(right), sort descending.
                result[res_n] =left[leftProgress]--append first(left) to result
				leftProgress = leftProgress + 1 --left = rest(left)
            else
                result[res_n] =right[rightProgress]--append first(right) to result
				rightProgress = rightProgress + 1 --right = rest(right)
			end
        elseif leftNotFinish then --else if length(left) > 0
            result[res_n] =left[leftProgress] --append first(left) to result
			leftProgress = leftProgress + 1  --left = rest(left)
        elseif rightNotFinish then --else if length(right) > 0
            result[res_n] =right[rightProgress] --append first(right) to result
			rightProgress = rightProgress + 1  --right = rest(right)
		end
		leftNotFinish = leftProgress <= leftLen
		rightNotFinish = rightProgress <= rightLen

    end --end while
    return result
end

local function merge_sort(m,CompareFunction)
    --// if list size is 1, consider it sorted and return it
    local m_len = #m
    if m_len <=1 then--if length(m) <= 1
        return m
	end
    --// else list size is > 1, so split the list into two sublists
    local left,l_n, right, r_n = {}, 0, {}, 0 --var list left, right
    local middle = math.modf((m_len/2)+0.5) --var integer middle = length(m) / 2
    for i= 1, middle, 1 do --for each x in m up to middle
    	l_n = l_n + 1
         left[l_n] = m[i] --add x to left
	end
    for j= m_len, middle+1, -1 do--for each x in m after or equal middle
         right[(j-middle)] = m[j]--add x to right
	end
    --// recursively call merge_sort() to further split each sublist
    --// until sublist size is 1
    left = merge_sort(left,CompareFunction)
    right = merge_sort(right,CompareFunction)
    --// merge the sublists returned from prior calls to merge_sort()
    --// and return the resulting merged sublist
	return merge(left, right,CompareFunction)
end

--OPTICS function----------------------------------------------------------------
--5 function
local useMergeSorter_gbl = true --//constant: experiment with merge sorter (slower)
local orderseedCount = 0
local function OrderSeedsUpdate(neighborsID, currentUnitID,objects, orderSeed,unitID_to_orderSeedMeta,receivedUnitList)
	local timer --= spGetTimer()
	local c_dist = objects[currentUnitID].core_distance
	local os_n = orderSeed.n
	for i=1, #neighborsID do
		local neighborUnitID = neighborsID[i]
		objects[neighborUnitID]=objects[neighborUnitID] or {unitID=neighborUnitID,}
		local object = objects[neighborUnitID]
		if not object.processed then
			local new_r_dist = math.max(c_dist, GetDistanceSQ(receivedUnitList[currentUnitID], receivedUnitList[neighborUnitID]))
			if not object.reachability_distance then
				object.reachability_distance = new_r_dist
				os_n = os_n + 1
				if useMergeSorter_gbl then
					orderSeed[os_n] = {unitID = neighborUnitID, content = object}
					unitID_to_orderSeedMeta[neighborUnitID] = os_n
				else
					InsertOrderSeed(orderSeed, unitID_to_orderSeedMeta, object)
				end
			else --// object already in OrderSeeds
				if new_r_dist< object.reachability_distance then
					object.reachability_distance = new_r_dist
					if useMergeSorter_gbl then
						local oldPosition = unitID_to_orderSeedMeta[neighborUnitID]
						orderSeed[oldPosition] = {unitID = neighborUnitID, content = object} -- update values
					else
						ShiftOrderSeed(orderSeed, unitID_to_orderSeedMeta, object)
					end
				end
			end
		end
	end
	if useMergeSorter_gbl then
		-- orderSeed = merge_sort(orderSeed, function(a,b) return a.content.reachability_distance > b.content.reachability_distance end ) --really slow
		table.sort(orderSeed, function(a,b) return a.content.reachability_distance > b.content.reachability_distance end) --abit slow
		for i= 1, os_n do
			unitID_to_orderSeedMeta[orderSeed[i].unitID] = i
		end
	end
	orderSeed.n = os_n
	orderseedCount = orderseedCount --+ spDiffTimers(spGetTimer(), timer)
	return os_n
end

local setcoreCount =0
local function SetCoreDistance(neighborsID, minimumNeighbor, unitID,receivedUnitList)
	local nid_n = #neighborsID
	if (nid_n >= minimumNeighbor) then
		local neighborsDist= {} --//table to list down neighbor's distance.
		for i=1, nid_n do
			-- local distance = spGetUnitSeparation (unitID, neighborsID[i])
			local distanceSQ = GetDistanceSQ(receivedUnitList[unitID],receivedUnitList[neighborsID[i]])
			neighborsDist[i]= distanceSQ --//add distance value
		end
		local timer --= spGetTimer()
		table.sort(neighborsDist, function(a,b) return a < b end)
		-- neighborsDist = merge_sort(neighborsDist, true)
		setcoreCount = setcoreCount  --+ spDiffTimers(spGetTimer(), timer)
		return neighborsDist[minimumNeighbor] --//return the distance of the minimumNeigbor'th unit with respect to the center unit.
	else
		return nil
	end
end

local function ExtractDBSCAN_Clustering (unitID, currentClusterID, cluster, noiseIDList, object, neighborhoodRadius_alt)
	local reachabilityDist = (object.reachability_distance and math.sqrt(object.reachability_distance)) or 9999
	--// Precondition: neighborhoodRadius_alt <= generating dist neighborhoodRadius for Ordered Objects
	if reachabilityDist > neighborhoodRadius_alt then --// UNDEFINED > neighborhoodRadius. ie: Not reachable from outside
		local coreDistance = (object.core_distance and math.sqrt(object.core_distance)) or 9999
		if coreDistance <= neighborhoodRadius_alt then --//has neighbor
			currentClusterID = currentClusterID + 1 --//create new cluster
			cluster[currentClusterID] = cluster[currentClusterID] or {} --//initialize array
			local arrayIndex = #cluster[currentClusterID] + 1
			cluster[currentClusterID][arrayIndex] = unitID --//add to new cluster
			-- Spring.Echo("CREATE CLUSTER")
		else --//if has no neighbor
			local arrayIndex = #noiseIDList +1
			noiseIDList[arrayIndex]= unitID --//add to noise list
		end
	else --// object.reachability_distance <= neighborhoodRadius_alt. ie:reachable
		local arrayIndex = #cluster[currentClusterID] + 1
		cluster[currentClusterID][arrayIndex] = unitID--//add to current cluster
	end

	return cluster, noiseIDList, currentClusterID
end

local function ExpandClusterOrder(orderedObjects,receivedUnitList, unitID, neighborhoodRadius, minimumNeighbor, objects,posListX)
	local neighborsID = GetNeighbor (receivedUnitList[unitID], neighborhoodRadius, posListX)
	objects[unitID].processed = true
	objects[unitID].reachability_distance = nil
	objects[unitID].core_distance = SetCoreDistance(neighborsID, minimumNeighbor, unitID,receivedUnitList)
	local oo_n = #orderedObjects
	oo_n = oo_n + 1
	orderedObjects[oo_n]=objects[unitID]
	if objects[unitID].core_distance then --//it have neighbor
		local orderSeed ={n=0}
		local unitID_to_orderSeedMeta = {}
		local os_n = OrderSeedsUpdate(neighborsID, unitID, objects, orderSeed,unitID_to_orderSeedMeta,receivedUnitList)
		while os_n > 0 do
			local currentUnitID = orderSeed[os_n].unitID
			objects[currentUnitID] = orderSeed[os_n].content
			orderSeed[os_n]=nil
			os_n = os_n - 1
			local neighborsID_ne = GetNeighbor (receivedUnitList[currentUnitID], neighborhoodRadius, posListX)
			objects[currentUnitID].processed = true
			objects[currentUnitID].core_distance = SetCoreDistance(neighborsID_ne, minimumNeighbor, currentUnitID,receivedUnitList)
			oo_n = oo_n + 1
			orderedObjects[oo_n]=objects[currentUnitID]
			if objects[currentUnitID].core_distance~=nil then
				orderSeed.n = os_n
				os_n = OrderSeedsUpdate(neighborsID_ne, currentUnitID, objects, orderSeed, unitID_to_orderSeedMeta,receivedUnitList)
			end
		end
	end
	return orderedObjects,objects
end

function WG.OPTICS_cluster (receivedUnitList, neighborhoodRadius, minimumNeighbor, _, neighborhoodRadius_alt,giveEcho) --//OPTIC_cluster function are accessible globally
	local objects={}
	local orderedObjects = {}
	local cluster = {}
	local noiseIDList = {}
	local currentClusterID = 0
	local posListX= {}
	local timer --= spGetTimer()
	neighborhoodRadius_alt = neighborhoodRadius_alt or neighborhoodRadius
	neighborhoodRadius_alt = 20
	giveEcho = giveEcho or echoOutCalculationTime
	--//SORTING unit list by X axis for easier searching, for getting unit in a box thru GetUnitInSquare()
	neighborhoodRadius = math.max(neighborhoodRadius_alt,neighborhoodRadius)
	local p_n = 0
	for unitID,pos in pairs(receivedUnitList) do
		p_n = p_n + 1
		posListX[p_n] = {unitID,pos[1],pos[3]}
		-- posListX = InsertAtOrder(posListX, {unitID,pos[1],pos[3]},function(a,b) return a[2]<b[2] end) --abit slow
	end
	posListX.n = p_n
	table.sort(posListX, function(a,b) return a[2]<b[2] end) --//stack ascending
	-- if giveEcho then
	-- 	distCount,shiftCount,insertCount = 0,0,0
	-- 	setcoreCount,getunitCount,searchCount = 0,0,0
	-- 	orderseedCount,intersectionCount = 0,0
	-- 	Spring.Echo("SPEED")
	-- 	--Spring.Echo("Initial sorting: ".. spDiffTimers(spGetTimer(), timer))
	-- 	--timer = spGetTimer()
	-- end
	--//SORTING unit list by connections, for extracting cluster information later using ExtractDBSCAN_Clustering()
	for unitID,_ in pairs(receivedUnitList) do --//go thru the un-ordered list
		objects[unitID] = objects[unitID] or {unitID=unitID,}
		if (objects[unitID].processed ~= true) then
			orderedObjects, objects = ExpandClusterOrder(orderedObjects,receivedUnitList,unitID, neighborhoodRadius,minimumNeighbor,objects,posListX)
		end
	end
	-- if giveEcho then
	-- 	--Spring.Echo("OPTICs: ".. spDiffTimers(spGetTimer(), timer))
	-- 	Spring.Echo("  Distance calculation: ".. distCount)
	-- 	Spring.Echo("  OrderSeed calc: " .. orderseedCount)
	-- 	Spring.Echo("    Insert calculation: " .. insertCount)
	-- 	Spring.Echo("    Shift calculation: " .. shiftCount)
	-- 	Spring.Echo("  SetCore sort calc: " .. setcoreCount)
	-- 	Spring.Echo("  GetUnitBox calc: " .. getunitCount)
	-- 	Spring.Echo("    BinarySearch: " .. searchCount)
	-- 	Spring.Echo("    Intersection: " .. intersectionCount)
	-- 	--timer = spGetTimer()
	-- end
	--//CREATE cluster based on desired density (density == neighborhoodRadius_alt).
	--//Note: changing cluster view to different density is really cheap when using this function as long as the initial neighborhoodRadius is greater than the new density.
	--//if new density (neighborhoodRadius_alt) is greater than initial neighborhoodRadius, then you must recalculate the connections using bigger neighborhoodRadius which incur greater cost.
	-- local clusters, noises, c_n, n_n = {}, {}, 0, 0
	for i=1, #orderedObjects do
		local unitID = orderedObjects[i].unitID
		cluster, noiseIDList, currentClusterID = ExtractDBSCAN_Clustering (unitID, currentClusterID, cluster, noiseIDList, orderedObjects[i], neighborhoodRadius_alt)
	end
	if giveEcho then
		--Spring.Echo("Extract Cluster: ".. spDiffTimers(spGetTimer(), timer))
	end
	return cluster, noiseIDList
end

function WG.Run_OPTIC(receivedUnitList, neighborhoodRadius, minimumNeighbor) --//OPTIC_cluster function are accessible globally
	local objects={}
	local orderedObjects = {}
	local posListX= {}
	local p_n = 0
	--//SORTING unit list by X axis for easier searching, for getting unit in a box thru GetUnitInSquare()
	for unitID,pos in pairs(receivedUnitList) do
		p_n = p_n + 1
		posListX[p_n] = {unitID,pos[1],pos[3]}
		-- posListX = InsertAtOrder(posListX, {unitID,pos[1],pos[3]},function(a,b) return a[2]<b[2] end) --abit slow
	end
	posListX.n = p_n
	table.sort(posListX, function(a,b) return a[2]<b[2] end) --//stack ascending
	--//SORTING unit list by connections, for extracting cluster information later using ExtractDBSCAN_Clustering()
	for unitID,_ in pairs(receivedUnitList) do --//go thru the un-ordered list
		objects[unitID] = objects[unitID] or {unitID=unitID,}
		if (objects[unitID].processed ~= true) then
			orderedObjects, objects = ExpandClusterOrder(orderedObjects,receivedUnitList,unitID, neighborhoodRadius,minimumNeighbor,objects,posListX)
		end
	end
	return orderedObjects
end

function WG.Extract_Cluster (orderedObjects,neighborhoodRadius_alt )
	local cluster = {}
	local noiseIDList = {}
	local currentClusterID = 0
	--//CREATE cluster based on desired density (density == neighborhoodRadius_alt).
	--//Note: changing cluster view to different density is really cheap when using this function as long as the initial neighborhoodRadius is greater than the new density.
	--//if new density (neighborhoodRadius_alt) is greater than initial neighborhoodRadius, then you must recalculate the connections using bigger neighborhoodRadius which incur greater cost.
	for i=1, #orderedObjects do
		local unitID = orderedObjects[i].unitID
		cluster, noiseIDList, currentClusterID = ExtractDBSCAN_Clustering (unitID, currentClusterID, cluster, noiseIDList, orderedObjects[i], neighborhoodRadius_alt)
	end
	return cluster, noiseIDList
end

function WG.Convert_To_Circle (cluster, noiseIDList,receivedUnitList)
	--// extract cluster information and add mapMarker.
	local circlePosition = {}
	for index=1 , #cluster do
		local sumX, sumY,sumZ, unitCount,meanX, meanY, meanZ = 0,0 ,0 ,0 ,0,0,0
		local maxX, minX, maxZ, minZ, radiiX, radiiZ, avgRadii = 0,99999,0,99999, 0,0,0
		local obj = cluster[index]
		for unitIndex=1, #obj do
			local unitID = obj[unitIndex]
			local x,y,z= receivedUnitList[unitID][1],receivedUnitList[unitID][2],receivedUnitList[unitID][3] --// get stored unit position
			sumX= sumX+x
			sumY = sumY+y
			sumZ = sumZ+z
			if x> maxX then
				maxX= x
			end
			if x<minX then
				minX=x
			end
			if z> maxZ then
				maxZ= z
			end
			if z<minZ then
				minZ=z
			end
			unitCount=unitCount+1
		end
		meanX = sumX/unitCount --//calculate center of cluster
		meanY = sumY/unitCount
		meanZ = sumZ/unitCount
		
		radiiX = ((maxX - meanX)+ (meanX - minX))/2
		radiiZ = ((maxZ - meanZ)+ (meanZ - minZ))/2
		avgRadii = (radiiX + radiiZ) /2
		circlePosition[#circlePosition+1] = {meanX,0,meanZ,avgRadii+100,#cluster[index]}
	end
	
	if noiseIDList[1] then --//IF outlier list is not empty
		for j= 1 ,#noiseIDList do
			local unitID = noiseIDList[j]
			local x,y,z= receivedUnitList[unitID][1],receivedUnitList[unitID][2],receivedUnitList[unitID][3] --// get stored unit position
			circlePosition[#circlePosition+1] = {x,0,z,100,1}
		end
	end
	return circlePosition
end

--DBSCAN function----------------------------------------------------------
--1 function. BUGGY (Not yet debugged)
function WG.DBSCAN_cluster(receivedUnitList,neighborhoodRadius,minimumNeighbor,giveEcho)
	local timer
	if giveEcho then
		timer = spGetTimer()
	end
	local clusterByUnitID = {}
	local visitedUnitID = {}
	local currentCluster=1
	local clusters = {}
	local unitIDNoise, noise_n = {}, 0
	

	local posListX, p_n = {}, 0
	for unitID,pos in pairs(receivedUnitList) do
		p_n = p_n + 1
		posListX[p_n] = {unitID,pos[1],pos[3]}
	end
	posListX.n = p_n
	table.sort(posListX, function(a,b) return a[2]<b[2] end) --//stack ascending
	for unitID, obj in pairs(receivedUnitList) do --//go thru the un-ordered list
	
		if not visitedUnitID[unitID] then --//skip if already visited
			visitedUnitID[unitID] = true
			local neighborUnits = GetNeighbor (obj, neighborhoodRadius, posListX)
			local neigh_len = neighborUnits.n
			-- if #neighborUnits ~= nil then
			if neigh_len < minimumNeighbor then --//if surrounding units is less-or-just-equal to minimum neighbor then mark current unit as noise or 'outliers'
				noise_n = noise_n + 1
				unitIDNoise[noise_n] = unitID
			else
				local newcluster = {n=1,unitID}  --//initialize new clusters with an empty table for unitID
				clusters[currentCluster]=newcluster
				clusterByUnitID[unitID] = currentCluster

				for l=1, neigh_len do
					local unitID_ne = neighborUnits[l]
					if not visitedUnitID[unitID_ne] then --//skip if already visited
						visitedUnitID[unitID_ne] = true
						---- this code don't do anything except a lot of loops
						-- local neighborUnits_ne = GetNeighbor (receivedUnitList[unitID_ne], neighborhoodRadius, posListX)
						-- if neighborUnits_ne[minimumNeighbor+1] then
						-- 	for m=1, neighborUnits_ne.n do
						-- 		local duplicate = false
						-- 		for n=1, neigh_len do
						-- 			if neighborUnits[n] == neighborUnits_ne[m] then
						-- 				duplicate = true
						-- 				break
						-- 			end
						-- 		end
						-- 		if not duplicate then
						-- 			neigh_len = neigh_len + 1
						-- 			neighborUnits[neigh_len]=neighborUnits_ne[m]
						-- 		end
						-- 	end --//for m=1, m<= #neighborUnits_ne, 1
						-- end --// if #neighborUnits_ne > minimumNeighbor


						if clusterByUnitID[unitID_ne] ~= currentCluster then
							if clusterByUnitID[unitID_ne] then
								Echo(unitID_ne .. ':' .. clusterByUnitID[unitID_ne] .. '=>' .. currentCluster)
							end
							-- local unitIndex_ne = #clusters[currentCluster] +1 --//length of the table-in-table containing unit list plus 1 new unit
							-- clusters[currentCluster][unitIndex_ne] = unitID_ne
							newcluster.n = newcluster.n + 1
							newcluster[newcluster.n] = unitID_ne
							clusterByUnitID[unitID_ne] = currentCluster
						end
					end --//if visitedUnitID[unitID_ne] ~= true
				end --//for l=1, l <= #neighborUnits, 1
				currentCluster= currentCluster + 1
			end --//if #neighborUnits <= minimumNeighbor, else
			-- end --//if #neighborUnits ~= nil
		end --//if visitedUnitID[unitID] ~= true
	end --//for i=1, i <= #receivedUnitList,1
	if giveEcho then
		Spring.Echo("DBSCAN_cluster processed: " .. posListX.n .. ' in ' .. spDiffTimers(spGetTimer(), timer))
	end
	return clusters, unitIDNoise
end
--brief:   a clustering algorithm
--algorithm source: Ordering Points To Identify the Clustering Structure (OPTICS) by Mihael Ankerst, Markus M. Breunig, Hans-Peter Kriegel and Jörg Sander
--algorithm source: density-based spatial clustering of applications with noise (DBSCAN) by Martin Ester, Hans-Peter Kriegel, Jörg Sander and Xiaowei Xu
--Reference:
--http://en.wikipedia.org/wiki/OPTICS_algorithm ;pseudocode
--http://en.wikipedia.org/wiki/DBSCAN ;pseudocode
--http://codingplayground.blogspot.com/2009/11/dbscan-clustering-algorithm.html ;C++ sourcecode
--http://www.google.com.my/search?q=optics%3A+Ordering+Points+To+Identify+the+Clustering+Structure ;article & pseudocode on OPTICS
---------------------------------------------------------------------------------
---------------------------------E N D ------------------------------------------
---------------------------------------------------------------------------------
function WG.DBSCAN_cluster2(receivedUnitList,neighborhoodRadius,minimumNeighbor,giveEcho)
	-- this version was made to help optimize a code that is actually totally useless
	local timer 
	if giveEcho then
		timer = spGetTimer()
	end
	local clusterByUnitID = {}
	local visitedUnitID = {}
	local currentCluster=1
	local clusters = {}
	local unitIDNoise, noise_n = {}, 0
	

	local posListX, p_n = {}, 0
	for unitID,pos in pairs(receivedUnitList) do
		p_n = p_n + 1
		posListX[p_n] = {unitID,pos[1],pos[3]}
		-- posListX = InsertAtOrder(posListX, {unitID,pos[1],pos[3]},function(a,b) return a[2]<b[2] end) --abit slow

	end
	posListX.n = p_n

	table.sort(posListX, function(a,b) return a[2]<b[2] end) --//stack ascending

	for unitID, obj in pairs(receivedUnitList) do --//go thru the un-ordered list
	
		if not visitedUnitID[unitID] then --//skip if already visited
			visitedUnitID[unitID] = true
	
			local neighborUnits = GetNeighborByID (obj, neighborhoodRadius, posListX)
			if neighborUnits.n < minimumNeighbor then --//if surrounding units is less-or-just-equal to minimum neighbor then mark current unit as noise or 'outliers'
				noise_n = noise_n + 1
				unitIDNoise[noise_n] = unitID
			else
				local newcluster = {n=1,unitID}  --//initialize new clusters with an empty table for unitID
				clusters[currentCluster]=newcluster
				clusterByUnitID[unitID] = currentCluster
				local neigh_len = neighborUnits.n
				neighborUnits.n = nil
				--local add = {}
				for unitID_ne in pairs(neighborUnits) do
					if not visitedUnitID[unitID_ne] then --//skip if already visited
						visitedUnitID[unitID_ne] = true
						---- this code don't do anything except a lot of loops
						-- local neighborUnits_ne = GetNeighbor (receivedUnitList[unitID_ne], neighborhoodRadius, posListX)
						-- if neighborUnits_ne[minimumNeighbor+1] then
						-- 	for m=1, neighborUnits_ne.n do
						-- 		local id_ne = neighborUnits_ne[m]
						-- 		if not neighborUnits[id_ne] and not add[id_ne] then
						-- 			add[id_ne]=true
						-- 		end
						-- 	end --//for m=1, m<= #neighborUnits_ne, 1
						-- end --// if #neighborUnits_ne > minimumNeighbor

						if clusterByUnitID[unitID_ne] ~= currentCluster then
							newcluster.n = newcluster.n + 1
							newcluster[newcluster.n] = unitID_ne
							clusterByUnitID[unitID_ne] = currentCluster
						end
					else
						-- Echo('visited',unitID_ne)

					end --//if visitedUnitID[unitID_ne] ~= true
				end --//for l=1, l <= #neighborUnits, 1
				currentCluster= currentCluster + 1
			end --//if #neighborUnits <= minimumNeighbor, else
			-- end --//if #neighborUnits ~= nil
		end --//if visitedUnitID[unitID] ~= true
	end --//for i=1, i <= #receivedUnitList,1
	if giveEcho then
		Spring.Echo("DBSCAN_cluster processed: ".. spDiffTimers(spGetTimer(), timer))
	end

	return clusters, unitIDNoise
end

local function GetUnitsInSquare3(x,z,distance,posListX)
	local unitIndX = BinarySearchNaturalOrder(x, posListX)
	testcnt = testcnt + 1
	-- Echo('unitIndX #' .. testcnt, unitIndX)
	local unitsX, ux_n = {}, 0
	for i = unitIndX, 1, -1 do --go left
		local pos = posListX[i]
		if x - pos[2] > distance then
			break
		end
		ux_n = ux_n + 1
		unitsX[ux_n]=pos
	end
	for i = unitIndX+1, posListX.n, 1 do --go right
		local pos = posListX[i]
		if pos[2]-x > distance then
			break
		end
		ux_n = ux_n + 1
		unitsX[ux_n]=pos
	end
	unitsX.n = ux_n
	if ux_n == 0 then
		return unitsX
	end
	local timer --= spGetTimer()
	local unitsInBox, n = {}, 0
	for i=1, ux_n, 1 do
		local unitX = unitsX[i] 
		if (abs(unitX[3]-z) <= distance) then
			n = n + 1
			unitsInBox[n] = unitX
		end
	end
	unitsInBox.n = n
	intersectionCount = intersectionCount --+ spDiffTimers(spGetTimer(), timer)
	return unitsInBox
end
local function GetNeighbor3 (x,z, neighborhoodRadius, posListX) --//return the unitIDs of specific units around a center unit
	local timer --= spGetTimer()
	local tempList = GetUnitsInSquare3(x,z,neighborhoodRadius,posListX) --Get neighbor. Ouput: unitID + my units
	getunitCount = getunitCount  --+ spDiffTimers(spGetTimer(), timer)
	return tempList
end

function WG.DBSCAN_cluster3(posListX,neighborhoodRadius,minimumNeighbor,wantNoise,noSorting,gatherFactor,giveEcho)
	-- As it is, it doesn't really give cluster, it arrange units by X, catch everything around orthogonally (not by radius), 
	-- then ignore those that have been caught as 'cluster' and continue to proceed onto the next unit
	-- but it is fast and have its use -- the old function was not considering noise properly and also was extremely bad optimized (hundreds times slower)
	-- this receive a table as {[1] = {unitID1,x1,z1}, [2] = {unitID2,x2,z2} ... } but we could just rewrite and ignore the unitID
	-- it add some property into each obj
	local timer = giveEcho and spGetTimer()



	local clusters, currentClID = {n=0}, 0
	local noiseObjs = {}
	local commons
	local mergeMethod = 1

	gatherFactor = false --  not working as wanted  = 0.5 -- if mergeMethod == 1 => if 50% of the new cluster got in common with another we merge the smallest to the biggest
	-- gatherFactor = 0.5 

	if not noSorting then
		local index = {}
		for i,v in ipairs(posListX) do
			index[v] = i
		end
		table.sort(posListX, function(a,b) return a[2]<b[2] end) --//stack ascending
		local needed = false
		for i,v in ipairs(posListX) do
			if index[v]~=i then
				needed = true
				break
			end
		end
		-- Echo('Sorting was ' .. (needed and '' or 'NOT ') .. ' NEEDED.')
	end

	for i, obj in ipairs(posListX) do --//go thru the un-ordered list
		local x, z = obj[2], obj[3] 
		local id = obj[1] -- id only necessary for debugging
		-- Echo('id',id)
		if not (noiseObjs[obj] or obj.cluster) then --//skip if already visited
			-- Echo('processing unit',id)
			local neighborUnits = GetNeighbor3 (x, z, neighborhoodRadius, posListX)
			local neigh_len = neighborUnits.n
			if neigh_len < minimumNeighbor then --//if surrounding units is less-or-just-equal to minimum neighbor then mark current unit as noise or 'outliers'

					-- Echo('not enough units found ('.. neigh_len ..') around unit # '.. i,'id ' .. id)
					-- possible noise
				noiseObjs[obj] = true
			else
				currentClID = currentClID + 1
				-- Echo('found ' .. neigh_len ..' around unit id ' .. id)
				-- Echo('new cluster : ' .. currentClID)
				local newcluster = {clID = currentClID, expanded = 1} 
				local new_n = 0
				if gatherFactor then
					commons = {}
				end
				-- clusterByObj[obj] = currentClID

				for l=1, neigh_len do
					local obj_ne = neighborUnits[l]
					local owner = obj_ne.cluster
					if owner then
						-- local fromCluster = clusterByObj[obj_ne]
						if gatherFactor and not owner.merged then
							commons[owner] = (commons[owner] or 0) + 1
						end
					else
						new_n = new_n + 1
						-- Echo('add #' .. new_n, 'id ' .. obj_ne[1])
						newcluster[new_n] = obj_ne
						if wantNoise then
							noiseObjs[obj_ne] = nil
						end
						obj_ne.cluster = newcluster
					end 
				end 

				newcluster.n = new_n
				newcluster.orisize = new_n
				clusters[currentClID] = newcluster

				if  gatherFactor and currentClID>1 then
					if mergeMethod == 2 then
						-- share half of the common with neighbour ?
					end
					if mergeMethod == 1 then -- method 1 merge totally a cluster -- work but doesnt do exactly what was expected
						for commonCluster, n in pairs(commons) do
							local smaller, bigger
							smaller = newcluster.n < commonCluster.n and newcluster or commonCluster
							if smaller.n > 0 then -- might be 0 if smaller is newcluster and it has been absorbed by a bigger one in that loop
								bigger = smaller == newcluster and commonCluster or newcluster
								-- Echo('new cluster #' .. currentClID .. ' got ' .. n .. ' commons from Cluster #' .. commonCluster.clID)
								if n >= bigger.n --[[/ bigger.expanded--]] * gatherFactor then
									-- local beforeStr,afterStr = '', ''
									-- for i = 1, currentClID do
									-- 	beforeStr = beforeStr .. '#'..i .. ': ' .. clusters[i].n .. ', '
									-- end	
									local index = bigger.n
									-- merge to a unique cluster if the commons are big enough
									for i = 1, smaller.n  do
										local obj = smaller[i]
										obj.cluster =  bigger
										bigger[index + i] = obj
										smaller[i] = nil
									end
									local smID, bgID = smaller.clID, bigger.clID
									local newsize = bigger.n + smaller.n
									bigger.expanded = newsize / bigger.orisize
									-- Echo('merging',smaller.clID,'(n:'..smaller.n..')','to',bigger.clID,'(n:'..bigger.n..'), expanded: '..bigger.expanded)
									bigger.n = newsize
									smaller.n = 0
									bigger.merged = true
									table.remove(clusters, smID)
									currentClID = currentClID - 1
									for i = smID, currentClID do
										clusters[i].clID = i
									end
									-- for i = 1, currentClID do
									-- 	afterStr = afterStr .. '#'..i .. ': ' .. clusters[i].n .. ', '
									-- end	
									-- Echo('before => ' .. beforeStr)
									-- Echo('after => ' .. afterStr)
								end
							end
						end
					end
				end
			end 
		end 
	end 
	clusters.n = currentClID
	local noise
	if wantNoise then
		local n = 0
		noise = {}
		for obj in pairs(noiseObjs) do
			n = n + 1
			noise[n] = obj
		end
		noise.n = n
	end

	if timer then
		Spring.Echo("DBSCAN_cluster processed: " .. posListX.n .. ' positions in ' .. spDiffTimers(spGetTimer(), timer))
	end
	return clusters, noise
end

local intersectionCount = 0
local function GetUnitsInSquareOLD(x,z,distance,posListX)
	local unitIndX = BinarySearchNaturalOrder(x, posListX)
	local unitsX = {}
	for i = unitIndX, 1, -1 do --go left
		if x - posListX[i][2] > distance then
			break
		end
		unitsX[#unitsX+1]=posListX[i]
	end
	for i = unitIndX+1, #posListX, 1 do --go right
		if posListX[i][2]-x > distance then
			break
		end
		unitsX[#unitsX+1]=posListX[i]
	end
	if #unitsX == 0 then
		return unitsX
	end
	local prevClock = os.clock()
	local unitsInBox = {}
	for i=1, #unitsX, 1 do
		if (math.abs(unitsX[i][3]-z) <= distance) then
			unitsInBox[#unitsInBox+1] = unitsX[i][1]
		end
	end
	intersectionCount = intersectionCount + (os.clock()-prevClock)
	return unitsInBox
end

--GetNeigbors--------------------------------------------------------------------
-- 1 function.
local getunitCount = 0
local function GetNeighborOLD (unitID, myTeamID, neighborhoodRadius, receivedUnitList,posListX) --//return the unitIDs of specific units around a center unit
	local prevCount = os.clock()
	local x,z = receivedUnitList[unitID][1],receivedUnitList[unitID][3]
	local tempList = GetUnitsInSquareOLD(x,z,neighborhoodRadius,posListX) --Get neighbor. Ouput: unitID + my units
	getunitCount = getunitCount + (os.clock() - prevCount)
	return tempList
end


function WG.DBSCAN_clusterOLD(receivedUnitList,neighborhoodRadius,minimumNeighbor)
	-- EXTREMELY unoptimized and useless code process 500 units in one second while the other version process the same in 4 ms
	local unitID_to_clusterMeta = {}
	local visitedUnitID = {}
	local currentCluster_global=1
	local cluster = {}
	local unitIDNoise = {}

	local posListX = {}
	for unitID,pos in pairs(receivedUnitList) do
		posListX[#posListX+1] = {unitID,pos[1],pos[3]}
		-- posListX = InsertAtOrder(posListX, {unitID,pos[1],pos[3]},function(a,b) return a[2]<b[2] end) --abit slow

	end
	table.sort(posListX, function(a,b) return a[2]<b[2] end) --//stack ascending
	-- local i = 0
	for unitID,_ in pairs(receivedUnitList) do --//go thru the un-ordered list
		-- i = i + 1 -- (for debugging only)
		-- Echo(i,'unitID',unitID)
		if visitedUnitID[unitID] ~= true then --//skip if already visited
			visitedUnitID[unitID] = true
	
			local neighborUnits = GetNeighborOLD (unitID, myTeamID, neighborhoodRadius, receivedUnitList,posListX)
			if #neighborUnits ~= nil then
				-- this is bugged, it should not count as noise, we aren't sure it is noise until we look at its neighbour's neighbours
				if #neighborUnits < minimumNeighbor then --//if surrounding units is less-or-just-equal to minimum neighbor then mark current unit as noise or 'outliers'
					local noiseIDLenght = #unitIDNoise or 0 --// if table is empty then make sure return table-lenght as 0 (zero) instead of 'nil'
					unitIDNoise[noiseIDLenght +1] = unitID
					-- Echo('not enough units found ('.. #neighborUnits ..') around unit #' .. i .. ', id ' .. unitID)
				else
					--local clusterIndex = #cluster+1 --//lenght of previous cluster table plus 1 new cluster
					cluster[currentCluster_global]={} --//initialize new cluster with an empty table for unitID
					local unitClusterLenght = #cluster[currentCluster_global] or 0 --// if table is empty then make sure return table-lenght as 0 (zero) instead of 'nil'
					cluster[currentCluster_global][unitClusterLenght +1] = unitID --//lenght of the table-in-table containing unit list plus 1 new unit
					unitID_to_clusterMeta[unitID] = currentCluster_global
					
					for l=1, #neighborUnits do
						-- Echo('found ' .. #neighborUnits ..' around unit id ' .. unitID)
						local unitID_ne = neighborUnits[l]
						if visitedUnitID[unitID_ne] ~= true then --//skip if already visited
							visitedUnitID[unitID_ne] = true
							
							local neighborUnits_ne = GetNeighborOLD (unitID_ne, myTeamID, neighborhoodRadius, receivedUnitList,posListX)
							if #neighborUnits_ne ~= nil then
								if #neighborUnits_ne > minimumNeighbor then
									for m=1, #neighborUnits_ne do
										local duplicate = false
										for n=1, #neighborUnits do
											if neighborUnits[n] == neighborUnits_ne[m] then
												duplicate = true
												break
											end
										end
										if duplicate== false then
											neighborUnits[#neighborUnits +1]=neighborUnits_ne[m]
										end
									end --//for m=1, m<= #neighborUnits_ne, 1
								end --// if #neighborUnits_ne > minimumNeighbor
							end --//if #neighborUnits_ne ~= nil
							
							if unitID_to_clusterMeta[unitID_ne] ~= currentCluster_global then
								local unitIndex_ne = #cluster[currentCluster_global] +1 --//lenght of the table-in-table containing unit list plus 1 new unit
								cluster[currentCluster_global][unitIndex_ne] = unitID_ne
								
								unitID_to_clusterMeta[unitID_ne] = currentCluster_global
							end
							
						end --//if visitedUnitID[unitID_ne] ~= true
					end --//for l=1, l <= #neighborUnits, 1
					currentCluster_global= currentCluster_global + 1
				end --//if #neighborUnits <= minimumNeighbor, else
			end --//if #neighborUnits ~= nil
		end --//if visitedUnitID[unitID] ~= true
	end --//for i=1, i <= #receivedUnitList,1
	return cluster, unitIDNoise
end
