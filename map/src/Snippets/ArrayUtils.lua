if Debug then Debug.beginFile "ArrayUtils" end
OnInit.module("ArrayUtils", function (require)
    ArrayUtils = {}

    ---@generic T
    ---@param arr T[]
    ---@return T random
    function ArrayUtils.Random(arr)
        local n = arr --[[@as unknown]].n or #arr
        return arr[GetRandomInt(1, n)]
    end
end)
if Debug then Debug.endFile() end