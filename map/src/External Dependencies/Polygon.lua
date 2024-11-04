if Debug then Debug.beginFile "Polygon" end
do
    ---@class Polygon
    ---@field minX number
    ---@field minY number
    ---@field maxX number
    ---@field maxY number
    ---@field private is_dirty boolean
    ---@field package origin_x number
    ---@field package origin_y number
    ---@field points number[]
    ---@field private debug_data table
    Polygon = {}
    Polygon.__index = Polygon

    local function get_bouding_box(points, j)
        local minX, minY, maxX, maxY = points[1], points[2], points[1], points[2]
        for i = 1, j, 2 do
            local qx = points[i]
            local qy = points[i + 1]
            minX, maxX, minY, maxY = math.min(qx, minX), math.max(qx, maxX), math.min(qy, minY), math.max(qy, maxY)
        end
        return minX, maxX, minY, maxY
    end

    function Polygon.get_bounding_box(self)
        self.minX, self.maxX, self.minY, self.maxY = get_bouding_box(self.points, #self.points)
        self.is_dirty = false
    end

    function Polygon.new(origin_x, origin_y, ...)
        local self = setmetatable({
            origin_x = origin_x,
            origin_y = origin_y,
            points = { ... },
        }, Polygon)
        self:get_bounding_box()
        return self
    end

    function Polygon.move_to(self, x, y)
        self.origin_x = x
        self.origin_y = y
    end

    function Polygon.rotate(self, angle)
        local cos_a = math.cos(angle)
        local sin_a = math.sin(angle)
        for i = 1, #self.points, 2 do
            local x = self.points[i]
            local y = self.points[i + 1]
            self.points[i] = x * cos_a - y * sin_a
            self.points[i + 1] = x * sin_a + y * cos_a
        end
        self.is_dirty = true
    end

    function Polygon.scale(self, scale_x, scale_y)
        for i = 1, #self.points, 2 do
            self.points[i] = self.points[i] * scale_x
            self.points[i + 1] = self.points[i + 1] * scale_y
        end
    end

    local function inside(x, y, points, j)
        local is_inside = false
        local l = j - 1
        for i = 1, j, 2 do
            local qx = points[i]
            local qy = points[i + 1]
            local ay = points[l + 1]
            if (qy > y) ~= (ay > y) and x < (points[l] - qx) * (y - qy) / (ay - qy) + qx then
                is_inside = not (is_inside)
            end
            l = i
        end
        return is_inside
    end

    function Polygon.inside(self, x, y)
        x = x - self.origin_x
        y = y - self.origin_y
        if self.is_dirty then
            self:get_bounding_box()
        end
        if x < self.minX or x > self.maxX or y < self.minY or y > self.maxY then
            return false
        end
        return inside(x, y, self.points, #self.points)
    end

    local ex_tbl = {}
    function Polygon.insideEx(self, x, y, angle, scale_x, scale_y)
        x = x - self.origin_x
        y = y - self.origin_y
        local cos_a = math.cos(angle)
        local sin_a = math.sin(angle)
        for i = 1, #self.points, 2 do
            local x1 = self.points[i] * scale_x
            local y1 = self.points[i + 1] * scale_y
            ex_tbl[i] = x1 * cos_a - y1 * sin_a
            ex_tbl[i + 1] = x1 * sin_a + y1 * cos_a
        end
        local minX, maxX, minY, maxY = get_bouding_box(ex_tbl, #self.points)
        if x < minX or x > maxX or y < minY or y > maxY then
            return false
        end
        return inside(x, y, ex_tbl, #self.points)
    end

    function Polygon.debug(self, state)
        self.debug_data = self.debug_data or {}
        if state then
            local points = self.points
            local j = #points
            local l = j - 1
            local ox = self.origin_x
            local oy = self.origin_y
            for i = 1, j, 2 do
                local qx = points[i] + ox
                local qy = points[i + 1] + oy
                local ax = points[l] + ox
                local ay = points[l + 1] + oy
                table.insert(self.debug_data,
                    AddLightningEx("FORK", false, qx, qy, 0, ax, ay, 0)
                )
                l = i
            end
        else
            for i = 1, #self.debug_data, 1 do
                DestroyLightning(self.debug_data[i])
                self.debug_data[i] = nil
            end
        end
    end
end
if Debug then Debug.endFile() end