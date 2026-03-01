if Debug then Debug.beginFile "TableRecycler" end
OnInit.module("TableRecycler", function()
    local freeTable = {}
    local tblTracker = {}

    TableRecycler = {}

    ---Creates a table if the recycled table list is empty.
    ---Retrieves one from it otherwise.
    ---@return table
    function TableRecycler.create()
        local tbl = table.remove(freeTable, nil) or {}
        tblTracker[tbl] = nil
        return tbl
    end

    function table.removeobject(tbl, object)
        for i = 1, math.huge do
            local val = tbl[i]
            if val == nil then break end
            if val == object then
                table.remove(tbl, i)
                break
            end
        end
    end

    ---Clears data from the table and adds it to the recycled table list.
    ---@param tbl table
    function TableRecycler.release(tbl)
        if not tbl or tblTracker[tbl] then return end
        tblTracker[tbl] = true
        for i = 1, math.huge, 1 do
            if tbl[i] == nil then break end
            tbl[i] = nil
        end
        for k in pairs(tbl) do
            print("Error: bad table release", k)
            Debug.throwError()
            rawset(tbl, k, nil)
        end
        table.insert(freeTable, tbl)
    end

    ---@param tbl table
    function TableRecycler.releaseKey(tbl)
        if not tbl then return end
        local list = tbl._list
        setmetatable(tbl, nil)
        for i = 1, math.huge, 1 do
            local key = list[i]
            if key == nil then break end
            tbl[key] = nil
            list[i] = nil
        end
        tbl._list = nil
        TableRecycler.release(list)
        TableRecycler.release(tbl)
    end

    function ClearKeyTable(tbl)
        local list = tbl._list
        for i = 1, math.huge, 1 do
            local key = list[i]
            if key == nil then break end
            tbl[key] = nil
            list[i] = nil
        end
    end

    local metaKeyTable = {
        __newindex = function(t, k, v)
            rawset(t, k, v)
            table.insert(t._list, k)
        end
    }

    ---@param o table
    ---@return table
    function TableRecycler.newKey(o)
        o = o or TableRecycler.create()
        o._list = TableRecycler.create()
        return setmetatable(o, metaKeyTable)
    end

    ---@param base table
    function TableRecycler.copyKey(base)
        local new = TableRecycler.create()
        new._list = TableRecycler.create()
        local newList = new._list
        for i, key in ipairs(base._list) do
            newList[i] = key
            new[key] = base[key]
        end
        setmetatable(new, metaKeyTable)
    end
end)
if Debug then Debug.endFile() end
