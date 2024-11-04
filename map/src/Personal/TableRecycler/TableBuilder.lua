if Debug then Debug.beginFile "Table Builder" end
OnInit.module("TableBuilder", function(require)
    require "TableRecycler"

    ---@class TableBuilder
    ---@field properties table
    ---@field n integer
    TableBuilder = {}
    TableBuilder.__index = TableBuilder

    -- Creates a TableBuilder that utilizes TableRecycler for memory optimization
    ---@return TableBuilder
    function TableBuilder.create()
        local o = setmetatable(TableRecycler.create(), TableBuilder)
        o.properties = TableRecycler.create()
        o.n = 0
        return o
    end

    -- Add a key,value pair in table
    ---@param key unknown
    ---@param value unknown
    ---@return TableBuilder
    function TableBuilder:addProperty(key, value)
        self.properties[key] = value
        return self
    end

    -- add value to table as an array element, starting with index 1
    ---@param value unknown
    ---@return TableBuilder
    function TableBuilder:addValue(value)
        self.n = self.n + 1
        self.properties[self.n] = value
        return self
    end

    -- Constructs table (via TableRecycler) from given properties and releases TableBuilder instance
    ---@return table
    function TableBuilder:build()
        local table = self.properties
        TableRecycler.release(self)
        return table
    end

end)
if Debug then Debug.endFile() end