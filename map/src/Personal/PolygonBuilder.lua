if Debug then Debug.beginFile "PolygonBuilder" end
OnInit.map("PolygonBuilder", function(require)
    require "Polygon"

    ---@class PolygonBuilder
    ---@field angle number?
    ---@field centerX number?
    ---@field centerY number?
    ---@field radius number?
    ---@field nPoints integer
    ---@field package [integer] number
    PolygonBuilder = {}
    PolygonBuilder.__index = PolygonBuilder

    ---@param centerX number
    ---@param centerY number
    ---@param radius number
    ---@param nPoints integer
    ---@param angle number?
    ---@return PolygonBuilder
    function PolygonBuilder.centeredSymmetricalPoly(centerX, centerY, radius, nPoints, angle)
        return setmetatable({
            centerX = centerX,
            centerY = centerY,
            radius = radius,
            nPoints = nPoints,
            angle = angle or 0
        }, PolygonBuilder)
    end

    -- Takes absolute points
    ---@overload fun(x1: number, y1: number, ...): PolygonBuilder
    ---@overload fun(x1: number, y1: number, x2: number, y2: number, ...): PolygonBuilder
    ---@overload fun(x1: number, y1: number, x2: number, y2: number, x3: number, y3: number, ...): PolygonBuilder
    ---@overload fun(x1: number, y1: number, x2: number, y2: number, x3: number, y3: number, x4: number, y4: number, ...): PolygonBuilder
    -- I'm not gonna overload infinite combinations...
    function PolygonBuilder.simplePoly(...)
        local argc = select("#", ...)
        if math.fmod(argc, 2) ~= 0 then error(
            "Points are not defined correctly, to define a point you must supply both x and y coordinates of each point!") end
        local o = setmetatable({ nPoints = argc / 2 }, PolygonBuilder)
        for i = 1, argc do
            o:overridePoint(i, select(2 * i - 1, ...) --[[@as number]])
        end
        return o
    end

    ---@param pointIndex integer
    ---@param offsetX number?
    ---@param offsetY number?
    ---@param isOriginOffset boolean?
    function PolygonBuilder:overridePointOffset(pointIndex, offsetX, offsetY, isOriginOffset)
        assert(pointIndex > 0, "pointIndex is 1-indexed index, must be greater than 0")
        assert(pointIndex <= self.nPoints,
            "pointIndex cannot exceed the amount of points PolygonBuilder has registered, use addPoint method to add more.")
        if pointIndex == 1 and self.centerX == nil and self.centerY == nil then
            error("Cannot set first point as offset as it is being used as originX/Y")
        end
        self[2 * pointIndex - 1] = offsetX
        self[2 * pointIndex] = offsetY
        self[-2 * pointIndex + 1] = nil
        self[-2 * pointIndex] = nil
        self["originOffset" .. pointIndex] = isOriginOffset or false
    end

    ---@param pointIndex integer
    ---@param pointX number?
    ---@param pointY number?
    function PolygonBuilder:overridePoint(pointIndex, pointX, pointY)
        assert(pointIndex > 0, "pointIndex is 1-indexed index, must be greater than 0")
        assert(pointIndex <= self.nPoints,
            "pointIndex cannot exceed the amount of points PolygonBuilder has registered, use addPoint method to add more.")
        self[-2 * pointIndex + 1] = pointX
        self[-2 * pointIndex] = pointY
        self[2 * pointIndex - 1] = nil
        self[2 * pointIndex] = nil
    end

    ---@param pointX number
    ---@param pointY number
    function PolygonBuilder:addPoint(pointX, pointY)
        local pointIndex = self.nPoints
        self[2 * pointIndex - 1] = pointX
        self[2 * pointIndex] = pointY
        self.nPoints = self.nPoints + 1
    end

    ---@return Polygon
    function PolygonBuilder:build()
        local originX, originY ---@type number, number
        if self.centerX and self.centerY and self.radius and self.angle then -- case: symmetrical centered poly
            originX, originY = self.centerX, self.centerY
            local angle = self.angle --[[@as number]]
            local angleDelta = 2 * math.pi(self.nPoints)
            for i = 1, self.nPoints do
                local x, y = self[-2 * i + 1], self[-2 * i]
                if x ~= nil and y ~= nil then
                    self[2 * i - 1], self[2 * i] = x - originX, y - originY
                else
                    local offsetX, offsetY = self[2 * i - 1], self[2 * i]
                    if offsetX ~= nil and offsetY ~= nil then
                        if not self["originOffset" .. i] then
                            local distance = math.sqrt(offsetX ^ 2 + offsetY ^ 2)
                            local newAngle = math.atan(offsetY, offsetX) + self.angle

                            self[2 * i - 1] = originX + self.radius * math.cos(angle) + distance * math.cos(newAngle)
                            self[2 * i] = originY + self.radius * math.sin(angle) + distance * math.sin(newAngle)
                        end
                    else
                        self[2 * i - 1] = originX + self.radius * math.cos(angle)
                        self[2 * i] = originY + self.radius * math.sin(angle)
                    end
                end

                angle = angle + angleDelta
            end
        else -- case: just absolute points
            originX, originY = self[-1], self[-2]
            for i = 1, self.nPoints do
                local x, y = self[-2 * i + 1], self[-2 * i]
                if x ~= nil and y ~= nil then
                    self[2 * i - 1], self[2 * i] = x - originX, y - originY
                end
            end
        end

        return Polygon.new(originX, originY, select(1, self))
    end
end)
if Debug then Debug.endFile() end
