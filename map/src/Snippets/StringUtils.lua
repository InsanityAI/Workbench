if Debug then Debug.beginFile "StringUtils" end
OnInit.module("StringUtils", function(require)
    StringUtils = {}

    ---@param str string
    ---@return string[]
    function StringUtils.deconstructString(str)
        local length = #str
        local result = {} ---@type string[]
        for index = 1, length do
            result[index] = str:sub(index, index)
        end
        return result
    end
end)
if Debug then Debug.endFile() end
