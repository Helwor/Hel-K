if not Spring.Utilities.GetUnitsInScreenCircle then
    local spGetUnitPosition = Spring.GetUnitPosition
    local spGetUnitsInScreenRectangle = Spring.GetUnitsInScreenRectangle
    local spGetMouseState = Spring.GetMouseState
    local spWorldToScreenCoords = Spring.WorldToScreenCoords
    function Spring.Utilities.GetUnitsInScreenCircle(r,mx,my, allyTeamID, midpos)
        if not mx then
            mx, my = spGetMouseState()
        end
        local sqr = r^2
        local ret, n = {}, 0
        for i, id in ipairs(spGetUnitsInScreenRectangle(mx - r, my - r, mx + r, my + r), allyTeamID) do
            local ux,uy,uz, _
            if midPos then
                _,_,_, ux,uy,uz = spGetUnitPosition(id, true)
            else
                ux,uy,uz = spGetUnitPosition(id)
            end
            local x,y = spWorldToScreenCoords(ux,uy,uz)
            if (x-mx)^2 + (y-my)^2 <= sqr then
                n = n + 1
                ret[n] = id
                -- Points[#Points+1] = {ux,uy,uz,size = 15, txt = math.ceil(i/10)}
            end
        end
        return ret, n
    end
end