if Debug then Debug.beginFile "StringInterpolation" end
-- Solution: Named Parameters with Formatting Codes
-- from http://lua-users.org/wiki/StringInterpolation
-- credits to http://lua-users.org/wiki/RiciLake
-- modified by InsanityAI to not create anonymous functions like cray-cray

--[[
    print( interp("\x25(key)s is \x25(val)7.2f\x25"), {key = "concentration", val = 56.2795} )
    outputs "concentration is   56.28\x25"
]]
OnInit.module("StringInterpolation", function(require)
    local currentParams = nil ---@type table<string, unknown>
    local function substitutePlaceholders(k, fmt)
        return currentParams[k] and ("\x25" .. fmt):format(currentParams[k]) or '\x25(' .. k .. ')' .. fmt
    end

    ---@param stringPattern string
    ---@param params table<string, unknown>
    ---@return string finalString
    ---@return integer replacementsOccured
    function interp(stringPattern, params)
        currentParams = params
        return stringPattern:gsub('\x25\x25\x25((\x25a\x25w*)\x25)([-0-9\x25.]*[cdeEfgGiouxXsq])', substitutePlaceholders)
    end
end)
if Debug then Debug.endFile() end