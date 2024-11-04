if Debug then Debug.beginFile "typeof" end
OnInit.module("typeof", function(require)
    local typeString ---@type string

    local typeCache = setmetatable({}, {
        __mode = 'k',
        __index = function(t, k)
            typeString = type(k)
            if typeString == 'userdata' then
                typeString = tostring(k)                                                   --tostring returns the warcraft type plus a colon and some hashstuff.
                typeString = typeString:sub(1, (typeString:find(":", nil, true) or 0) - 1) --string.find returns nil, if the argument is not found, which would break string.sub. So we need to replace by 0.
                rawset(t, k, typeString)
                return typeString
            elseif typeString == 'table' then
                typeString = k.__name or 'table'
                rawset(t, k, typeString) -- if it's a properly defined "class" table, or instance of, it will return the name of said "class"
                return typeString
            else                         -- primitive data types or functions
                return typeString
            end
        end,
        __call = function(t, input)
            return t[input]
        end
    }) ---@type table<unknown, string>

    typeof = typeCache --[[@as fun(input: any): typeName: string]]
end)
if Debug then Debug.endFile() end
