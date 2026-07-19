do
    local nativeType = type

    ---@param obj unknown
    ---@return string
    function type(obj)
        if obj == nil then return 'nil' end
        local natType = nativeType(obj)
        if natType ~= 'table' then return natType end
        local mt = getmetatable(obj)
        if mt == nil then return 'table' end
        return mt.type
    end

    ---@param obj userdata
    ---@return string
    local function wc3Type(obj)
        if obj == nil then return 'nil' end
        local mt = getmetatable(obj)
        if mt == nil then return type(obj) end
        return mt.__name
    end

    local stubs = {} ---@type table<string, StubTypeMt>

    ---@param thisType StubTypeMt
    ---@param requiredType string
    local function isInheritedTypeAcceptable(thisType, requiredType)
        if thisType == requiredType then return true end
        if thisType == nil or requiredType == nil then return false end
        local typeMt = stubs[thisType]
        if typeMt == nil then return false end
        return isInheritedTypeAcceptable(typeMt.baseType, requiredType)
    end

    ---@class StubTypeMt
    ---@field type string
    ---@field baseType StubTypeMt?

    ---@class StubType
    ---@field isDeleted boolean

    Stubs = {
        ---@param stubType string
        ---@param baseType StubTypeMt?
        ---@return StubTypeMt
        CreateStubType = function(stubType, baseType)
            local obj = { type = 'userdata', __name = stubType, baseType = baseType }
            stubs[stubType] = obj
            return obj
        end,

        ---@param arg unknown
        ---@param optional boolean
        ---@param requiredType string
        ---@returns boolean isValid
        Check = function(arg, optional, requiredType)
            if arg == nil then return optional end
            if type(arg) ~= requiredType then return false end
            return true
        end,

        ---@param arg boolean
        ---@param optional boolean
        ---@returns boolean isValid
        CheckBoolean = function(arg, optional)
            return Stubs.Check(arg, optional, 'boolean')
        end,

        ---@param arg number
        ---@param optional boolean
        ---@returns boolean isValid
        CheckReal = function(arg, optional)
            return Stubs.Check(arg, optional, 'number')
        end,

        ---@param arg integer
        ---@param optional boolean
        ---@returns boolean isValid
        CheckInteger = function(arg, optional)
            if arg == nil then return optional end
            if type(arg) ~= 'number' then return false end
            if math.tointeger(arg) ~= arg then return false end
            return true
        end,

        ---@param arg string
        ---@param optional boolean
        ---@returns boolean isValid
        CheckString = function(arg, optional)
            return Stubs.Check(arg, optional, 'string')
        end,

        ---@param arg function
        ---@param optional boolean
        ---@returns boolean isValid
        CheckFunction = function(arg, optional)
            return Stubs.Check(arg, optional, 'function')
        end,

        ---@param arg userdata
        ---@param optional boolean
        ---@returns boolean isValid
        CheckUserdata = function(arg, optional)
            return Stubs.Check(arg, optional, 'userdata')
        end,

        CheckW3 = function(arg, optional, requiredType)
            if arg == nil then return optional end
            return isInheritedTypeAcceptable(stubs[wc3Type(arg)], requiredType)
        end
    }
end
