if Debug then Debug.beginFile "MapBounds" end
OnInit.global("MapBounds", function()
    ---@class MapBounds
    ---@field minX number
    ---@field minY number
    ---@field maxX number
    ---@field maxY number
    ---@field sizeX number
    ---@field sizeY number
    ---@field centerX number
    ---@field centerY number
    ---@field rect rect
    ---@field region region
    local bounds = {}
    bounds.__index = bounds

    ---@return number x
    function bounds:getRandomX()
        return GetRandomReal(self.minX, self.maxX)
    end

    ---@return number y
    function bounds:getRandomY()
        return GetRandomReal(self.minY, self.maxY)
    end

    ---@return number x, number y  
    function bounds:getRandomPoint()
        return self:getRandomX(), self:getRandomY()
    end

    ---@param bounds MapBounds
    ---@param v number
    ---@param minV string
    ---@param maxV string
    ---@param margin? number
    ---@return number
    local function GetBoundedValue(bounds, v, minV, maxV, margin)
        margin = margin or 0.00

        if v < (bounds[minV] + margin) then
            return bounds[minV] + margin
        elseif v > (bounds[maxV] - margin) then
            return bounds[maxV] - margin
        end

        return v
    end

    ---@param x number
    ---@param margin? number
    ---@return number boundedX
    function bounds:getBoundedX(x, margin)
        return GetBoundedValue(self, x, "minX", "maxX", margin)
    end

    ---@param y number
    ---@param margin? number
    ---@return number boundedY
    function bounds:getBoundedY(y, margin)
        return GetBoundedValue(self, y, "minY", "maxY", margin)
    end

    ---@param x number
    ---@param y number
    ---@param margin? number
    ---@return number boundedX, number boundedY
    function bounds:getBoundedXY(x, y, margin)
        return self:getBoundedX(x, margin), self:getBoundedY(y, margin)
    end

    ---@param x number
    ---@return boolean
    function bounds:containsX(x)
        return self:getBoundedX(x) == x
    end

    ---@param y number
    ---@return boolean
    function bounds:containsY(y)
        return self:getBoundedY(y) == y
    end

    ---@param x number
    ---@param y number
    ---@return boolean
    function bounds:containsXY(x, y)
        return self:containsX(x) and self:containsY(y)
    end

    ---@param rect rect
    ---@return MapBounds
    local function InitData(rect)
        bounds = setmetatable({
            minX = GetRectMinX(rect),
            minY = GetRectMinY(rect),
            maxX = GetRectMaxX(rect),
            maxY = GetRectMaxY(rect),
            region = CreateRegion()
        }, bounds)
        bounds.sizeX = bounds.minX + bounds.maxX
        bounds.sizeY = bounds.minY + bounds.maxY
        bounds.centerX = bounds.sizeX / 2.00
        bounds.centerY = bounds.sizeY / 2.00
        RegionAddRect(bounds.region, bounds.rect)

        return bounds
    end

    MapBounds = InitData(bj_mapInitialPlayableArea)
    WorldBounds = InitData(GetWorldBounds())
end)
if Debug then Debug.endFile() end
