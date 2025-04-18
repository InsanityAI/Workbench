if Debug then Debug.beginFile "SortUtils" end
OnInit.module("SortUtils", function(require)
    SortUtils = {}

    ---@param val1 unknown
    ---@param val2 unknown
    ---@return boolean
    local function numericalCompare(val1, val2)
        return val1 <= val2
    end
    local comparer = numericalCompare

    ---@param array unknown[]
    ---@param left integer
    ---@param right integer
    ---@param pivotIndex integer
    local function partition(array, left, right, pivotIndex)
        local pivotValue = array[pivotIndex]
        array[pivotIndex], array[right] = array[right], array[pivotIndex]

        local storeIndex = left

        for i = left, right - 1 do
            if comparer(array[i], pivotValue) then
                array[i], array[storeIndex] = array[storeIndex], array[i]
                storeIndex = storeIndex + 1
            end
            array[storeIndex], array[right] = array[right], array[storeIndex]
        end

        return storeIndex
    end

    ---@param array unknown[]
    ---@param left integer
    ---@param right integer
    local function quicksort(array, left, right)
        if right > left then
            local pivotNewIndex = partition(array, left, right, left)
            quicksort(array, left, pivotNewIndex - 1)
            quicksort(array, pivotNewIndex + 1, right)
        end
    end

    ---@param array unknown[]
    ---@param left integer
    ---@param right integer
    ---@param comparerFunc (fun(i: unknown, j: unknown): boolean)?
    function SortUtils.quicksort(array, left, right, comparerFunc)
        comparer = comparerFunc or numericalCompare
        quicksort(array, left, right)
    end
end)
if Debug then Debug.endFile() end
