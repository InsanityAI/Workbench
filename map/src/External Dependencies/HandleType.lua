if Debug then Debug.beginFile("HandleType") end
do
    --[[
    ===============================================================================================================================================================
                                                                        Handle Type
                                                                        by Antares
    ===============================================================================================================================================================
    
    Determine the type of a Wacraft 3 object (handle). The result is stored in a table on the first execution to increase performance.

    HandleType[whichHandle]     -> string           Returns an empty string if variable is not a handle.
    IsHandle[whichHandle]       -> boolean
    IsWidget[whichHandle]       -> boolean
    IsUnit[whichHandle]         -> boolean

    These can also be called as a function, which has a nil-check, but is slower than the table-lookup

    ===============================================================================================================================================================
    ]]

    ---@alias TypeCheck<T> (fun(obj: unknown): T)|{[unknown]: T}

    HandleType = setmetatable({}, {
        __mode = "k",
        __index = function(self, key)
            if type(key) == "userdata" then
                local str = tostring(key)
                self[key] = str:sub(1, (str:find(":", nil, true) or 0) - 1)
                return self[key]
            else
                self[key] = ""
                return ""
            end
        end,
        __call = function(self, key)
            if key then
                return self[key]
            else
                return ""
            end
        end
    }) --[[@as TypeCheck<string>]]

    ---@generic T
    ---@param condition fun(key: string): T
    ---@param defaultReturnValue T
    ---@return TypeCheck<T>
    local function createTypeCheck(condition, defaultReturnValue)
        return setmetatable({}, {
            __mode = "k",
            __index = function(self, key)
                self[key] = condition(key)
                return self[key]
            end,
            __call = function(self, key)
                if key then
                    return self[key]
                else
                    return defaultReturnValue
                end
            end
        })
    end

    IsHandle = createTypeCheck(function(key) return HandleType[key] ~= "" end, false)

    local widgetTypes = {
        unit = true,
        destructable = true,
        item = true
    }

    IsWidget = createTypeCheck(function(key) return widgetTypes[HandleType[key]] == true end, false)
    IsUnit = createTypeCheck(function(key) return HandleType[key] == "unit" end, false)
    IsDestructable = createTypeCheck(function(key) return HandleType[key] == "destructable" end, false)
    IsItem = createTypeCheck(function(key) return HandleType[key] == "item" end, false)

    local a = IsItem[{}]
end
if Debug then Debug.endFile() end