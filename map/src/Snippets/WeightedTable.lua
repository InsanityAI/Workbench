if Debug then Debug.beginFile "WeightedTable" end
OnInit.module("WeightedTable", function(require)
    ---@class WeightedTable
    ---@field private compiled boolean
    ---@field private internalWeights number[]
    ---@field public weights number[]
    ---@field public values unknown[]
    ---@field public size integer
    WeightedTable = {}
    WeightedTable.__index = WeightedTable

    ---@overload fun(weight1: number, value1: unknown, weight2: number, value2: unknown, weight3: number, value3: unknown, weight4: number, value4: unknown): WeightedTable
    ---@overload fun(weight1: number, value1: unknown, weight2: number, value2: unknown, weight3: number, value3: unknown): WeightedTable
    ---@overload fun(weight1: number, value1: unknown, weight2: number, value2: unknown): WeightedTable
    ---@overload fun(weight1: number, value1: unknown): WeightedTable
    ---@return WeightedTable
    function WeightedTable.create(...)
        local size = select("#", ...)
        local weights = {}
        local values = {}
        local counter = 1
        for i = 1, size, 2 do
            weights[counter], values[counter] = select(i, ...)
            assert(type(weights[counter]) == "number", "Argument " .. i .. " is expected to be a weight number")
            counter = counter + 1
        end

        return setmetatable({
            compiled = false,
            size = counter,
            weights = weights,
            values = values
        }, WeightedTable)
    end

    ---@param ... WeightedTable
    ---@return WeightedTable
    function WeightedTable.merge(...)
        local weights = {}
        local values = {}
        local size = 0
        for _, tbl in ipairs(table.pack(...)) do
            for index, weight in ipairs(tbl.weights) do
                size = size + 1
                weights[size] = weight
                values[size] = tbl.values[index]
            end
        end

        return setmetatable({
            compiled = false,
            size = size,
            weights = weights,
            values = values
        }, WeightedTable)
    end

    ---@return WeightedTable
    function WeightedTable:copy()
        return setmetatable({
            compiled = self.compiled,
            size = self.size,
            internalWeights = self.internalWeights,
            weights = table.pack(table.unpack(self.weights)),
            values = table.pack(table.unpack(self.values))
        }, WeightedTable)
    end

    ---@param weight number
    ---@param value unknown
    ---@param index integer?
    ---@return WeightedTable self
    function WeightedTable:add(weight, value, index)
        assert(type(weight) == "number", "Weight must be a number")
        if index ~= nil then
            assert(index > 0, "Index must be greated than 0")
            assert(index <= self.size, "Index must be less or equal to current size")
            table.insert(self.weights, index, weight)
            table.insert(self.values, index, value)
        else
            table.insert(self.weights, weight)
            table.insert(self.values, value)
        end

        self.compiled = false
        self.size = self.size + 1
        return self
    end

    ---@param index integer?
    ---@return WeightedTable
    function WeightedTable:remove(index)
        index = index or self.size
        table.remove(self.weights, index)
        table.remove(self.values, index)

        self.compiled = false
        self.size = self.size - 1
        return self
    end

    ---@param index integer
    ---@param weight number
    function WeightedTable:modifyWeight(index, weight)
        assert(index > 0, "Index must be greated than 0")
        assert(index <= self.size, "Index must be less or equal to current size")
        assert(type(weight) == "number", "Weight must be a number")
        self.weights[index] = weight
    end

    ---@return unknown? value
    function WeightedTable:random()
        if not self.compiled then
            self.internalWeights = {}
            local weightSum = 0
            for _, weight in ipairs(self.weights) do
                weightSum = weightSum + weight
            end
            local currentCumulativeNormalizedWeight = 0
            for index, weight in ipairs(self.weights) do
                currentCumulativeNormalizedWeight = currentCumulativeNormalizedWeight + weight / weightSum
                self.internalWeights[index] = currentCumulativeNormalizedWeight
            end
        end

        local rng = math.random()
        for index, weightedValue in ipairs(self.internalWeights) do
            if rng <= weightedValue then
                return self.values[index] -- this should always return a value, unless there's nothing in the table.
            end
        end
    end
end)
if Debug then Debug.endFile() end
