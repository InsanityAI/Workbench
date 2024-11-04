if Debug then Debug.beginFile "TableRecycler" end
OnInit.module("TableRecycler", function()
    local freeTable = {}
    local tblTracker = {}

    TableRecycler = {}

    ---Creates a table if the recycled table list is empty.
    ---Retrieves one from it otherwise.
    ---@return table
    function TableRecycler.create()
        local tbl = freeTable[#freeTable + 1] or {}
        tblTracker[tbl] = nil
        freeTable[#freeTable + 1] = nil
        return tbl
    end

    ---Clears data from the table and adds it to the recycled table list.
    ---@param tbl table
    function TableRecycler.release(tbl)
        if not tbl or tblTracker[tbl] then return end
        tblTracker[tbl] = true
        for k in pairs(tbl) do
            rawset(tbl, k, nil)
        end
        freeTable[#freeTable + 1] = tbl
    end

    ---Clears data from the table but doesn't add it to the recycled table list.
    ---@param tbl table
    function TableRecycler.clear(tbl)
        if not tbl then return end
        for k in pairs(tbl) do
            print("Error: bad table release", k)
            rawset(tbl, k, nil)
        end
    end

    ---Alternative way to add table to the recycled table list.
    ---@param tbl table
    function TableRecycler.releaseFast(tbl)
        freeTable[#freeTable + 1] = tbl
    end

    ---comment
    ---@param tbl table
    function TableRecycler.releaseKey(tbl)
        if not tbl then return end
        local list = tbl._list
        setmetatable(tbl, nil)
        for i = 1, #list, 1 do
            local key = list[i]
            tbl[key] = nil
            list[i] = nil
        end
        tbl._list = nil
        TableRecycler.release(list)
        --freeTable[#freeTable+1] = list
        TableRecycler.release(tbl)
        --freeTable[#freeTable+1] = tbl
    end

    ---pretty sure we dont' need this
    local metaKeyTable = {
        __newindex = function(t, k, v)
            rawset(t, k, v)
            t._list[#t._list + 1] = k
        end
    }

    ---pretty sure we dont' need this
    ---@param o table
    ---@return table
    function TableRecycler.newKey(o)
        o = o or TableRecycler.create()
        o._list = TableRecycler.create()
        return setmetatable(o, metaKeyTable)
    end

    ---pretty sure we dont' need this
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
