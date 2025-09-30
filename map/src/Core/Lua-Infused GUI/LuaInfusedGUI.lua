if Debug then Debug.beginFile "LuaInfusedGUI" end
--[[
    Lua-Infused GUI with automatic memory leak resolution: Modernizing the experience for a better future for users of the Trigger Editor.

    Credits:
        Bribe, Tasyen, Dr Super Good, HerlySQR

    Transforming rects, locations, groups, forces and BJ hashtable wrappers into Lua tables, which are automatically garbage collected.

    Provides RegisterAnyPlayerUnitEvent to cut down on handle count and simplify syntax for Lua users while benefitting GUI.

    Provides GUI.enumUnitsInRect/InRange/Selected/etc. which replaces the first parameter with a function (which takes a unit), for immediate action without needing a separate group variable.

    Provides GUI.loopArray for safe iteration over a __jarray

    Updated: 28 Sep 2025 by Insanity_AI

    Changes: Added asserts everywhere, EmmyLua annotations and fixed some overrides to actually return booleans and Hashtable to behave like a normal hashtable with primitive types

    Uses optionally:
        https://github.com/BribeFromTheHive/Lua-Core/blob/main/Total_Initialization.lua
        https://github.com/BribeFromTheHive/Lua-Core/blob/main/Hook.lua
        https://github.com/BribeFromTheHive/Lua-Core/blob/main/Global_Variable_Remapper.lua
        https://github.com/BribeFromTheHive/Lua-Core/blob/main/UnitEvent.lua
--]]
GUI = {}
do
    --Configurables
    local _USE_GLOBAL_REMAP = false --set to true if you want GUI to have extended functionality such as "udg_HashTableArray" (which gives GUI an infinite supply of shared hashtables)
    local _USE_UNIT_EVENT   = false --set to true if you have UnitEvent in your map and want to automatically remove units from their unit groups if they are removed from the game.

    --Define common variables to be utilized throughout the script.
    local _G                = _G
    local unpack            = table.unpack
    local assert            = assert

    ---@class FakedType
    ---@field __faketype {__name: string}

    local fakeTypes         = {
        FakeLocation  = { __name = 'userdata' },
        FakeHashtable = { __name = 'userdata' },
        FakeGroup     = { __name = 'userdata' },
        FakeForce     = { __name = 'userdata' },
        FakeRect      = { __name = 'userdata' }
    }
    do
        local oldType = type
        --[[ Type extender - if object being checked is a table, check if it's one of the replacements for userdata --]]
        ---@param obj unknown
        ---@return string typeName
        function type(obj)
            local thisType = oldType(obj)
            if thisType == 'table' and obj.__faketype and oldType(obj.__faketype) == 'table' then
                return obj --[[@as FakedType]].__faketype.__name
            end
            return thisType
        end
    end

    --[[-----------------------------------------------------------------------------------------
        __jarray expander by Bribe

        This snippet will ensure that objects used as indices in udg_ arrays will be automatically
        cleaned up when the garbage collector runs, and tries to re-use metatables whenever possible.
        -------------------------------------------------------------------------------------------]]
    do
        local mts = {}
        local weakKeys = { __mode = "k" } --ensures tables with non-nilled objects as keys will be garbage collected.

        ---Re-define __jarray.
        ---@param default? any
        ---@param tab? table
        ---@return table
        function __jarray(default, tab)
            local mt
            if default then
                mts[default] = mts[default] or {
                    __index = function()
                        return default
                    end,
                    __mode = "k"
                }
                mt = mts[default]
            else
                mt = weakKeys
            end
            return setmetatable(tab or {}, mt)
        end

        --have to do a wide search for all arrays in the variable editor. The WarCraft 3 _G table is HUGE,
        --and without editing the war3map.lua file manually, it is not possible to rewrite it in advance.
        for k, v in pairs(_G) do
            if type(v) == "table" and string.sub(k, 1, 4) == "udg_" then
                __jarray(v[0], v)
            end
        end
        ---Add this safe iterator function for jarrays.
        ---@param whichTable table
        ---@param func fun(index:integer, value:any)
        function GUI.loopArray(whichTable, func)
            for i = rawget(whichTable, 0) ~= nil and 0 or 1, #whichTable do
                func(i, rawget(whichTable, i))
            end
        end
    end
    --[=============[
      • HASHTABLES •
    --]=============]
    do
        --[[ GUI hashtable converter by Tasyen and Bribe

        Converts GUI hashtables API into Lua Tables, overwrites StringHashBJ and GetHandleIdBJ to permit
        typecasting, bypasses the 256 hashtable limit by avoiding hashtables, provides the variable
        "HashTableArray", which automatically creates hashtables for you as needed (so you don't have to
        initialize them each time). ]]
        ---@param s string
        ---@return string s
        function StringHashBJ(s)
            return s or 0
        end

        ---@generic T
        ---@param id T
        ---@return T id
        function GetHandleIdBJ(id)
            return id or 0
        end

        ---@alias FakeHashtableBucket<T> {[unknown]: {[unknown]: T}}
        ---@class FakeHashtable: FakedType
        ---@field boolean FakeHashtableBucket<boolean>
        ---@field integer FakeHashtableBucket<integer>
        ---@field real FakeHashtableBucket<real>
        ---@field string FakeHashtableBucket<string>
        ---@field handle FakeHashtableBucket<handle>

        ---@param whichHashTable FakeHashtable
        ---@param type 'boolean'|'integer'|'real'|'string'|'handle'
        ---@param parentKey unknown
        ---@return unknown
        local function load(whichHashTable, type, parentKey)
            local typedTable = whichHashTable[type]
            if not typedTable then
                typedTable = {}
                whichHashTable[type] = typedTable
            end
            local index = typedTable[parentKey]
            if not index then
                index = __jarray()
                typedTable[parentKey] = index
            end
            return index
        end
        if _USE_GLOBAL_REMAP then
            OnInit(function(import)
                local remap = import "GlobalRemapArray"
                local hashes = __jarray()
                remap("udg_HashTableArray", function(index)
                    return load(hashes, 'handle', index)
                end)
            end)
        end

        local last

        ---@return FakeHashtable
        function GetLastCreatedHashtableBJ()
            return last
        end

        ---@return FakeHashtable
        function InitHashtableBJ()
            last = __jarray();
            last.__faketype = fakeTypes.FakeHashtable
            return last
        end

        ---@param value unknown?
        ---@param childKey unknown
        ---@param parentKey unknown
        ---@param whichHashTable FakeHashtable
        ---@param type string
        local function saveInto(value, childKey, parentKey, whichHashTable, type)
            assert(childKey ~= nil, 'childKey cannot be nil')
            assert(parentKey ~= nil, 'parentKey cannot be nil')
            assert(whichHashTable ~= nil, 'whichHashTable cannot be nil')
            assert(type ~= nil, 'type cannot be nil')
            load(whichHashTable, type, parentKey)[childKey] = value
        end

        ---@param childKey unknown
        ---@param parentKey unknown
        ---@param whichHashTable FakeHashtable
        ---@param type string|nil
        ---@param default unknown|nil
        ---@return unknown|nil
        local function loadFrom(childKey, parentKey, whichHashTable, type, default)
            assert(childKey ~= nil, 'childKey cannot be nil')
            assert(parentKey ~= nil, 'parentKey cannot be nil')
            assert(whichHashTable ~= nil, 'whichHashTable cannot be nil')
            local val = load(whichHashTable, type or 'handle', parentKey)[childKey]
            return val ~= nil and val or default
        end

        ---@generic T
        ---@param type string
        ---@return fun(value: T, childKey: unknown, parentKey: unknown, whichHashTable: FakeHashtable)
        local function createSaveIntoTyped(type)
            ---@generic T
            ---@param value T
            ---@param childKey unknown
            ---@param parentKey unknown
            ---@param whichHashTable FakeHashtable
            return function(value, childKey, parentKey, whichHashTable)
                return saveInto(value, childKey, parentKey, whichHashTable, type)
            end
        end

        SaveIntegerBJ = createSaveIntoTyped('integer')
        SaveRealBJ = createSaveIntoTyped('real')
        SaveBooleanBJ = createSaveIntoTyped('boolean')
        SaveStringBJ = createSaveIntoTyped('string')

        ---@param value unknown|nil
        ---@param childKey unknown
        ---@param parentKey unknown
        ---@param whichHashTable FakeHashtable
        local function saveHandle(value, childKey, parentKey, whichHashTable)
            saveInto(value, childKey, parentKey, whichHashTable, 'handle')
        end

        ---@param type string
        ---@param default unknown
        ---@return fun(childKey: unknown, parentKey: unknown, whichHashTable: table): unknown|nil
        local function createDefault(type, default)
            return function(childKey, parentKey, whichHashTable)
                return loadFrom(childKey, parentKey, whichHashTable, type, default)
            end
        end
        LoadIntegerBJ = createDefault('integer', 0) ---@type fun(childKey: unknown, parentKey: unknown, whichHashTable: FakeHashtable): integer
        LoadRealBJ = createDefault('real', 0) ---@type fun(childKey: unknown, parentKey: unknown, whichHashTable: FakeHashtable): number
        LoadBooleanBJ = createDefault('boolean', false) ---@type fun(childKey: unknown, parentKey: unknown, whichHashTable: FakeHashtable): boolean
        LoadStringBJ = createDefault('string', '') ---@type fun(childKey: unknown, parentKey: unknown, whichHashTable: FakeHashtable): string

        ---@param childKey unknown
        ---@param parentKey unknown
        ---@param whichHashTable FakeHashtable
        local function loadHandle(childKey, parentKey, whichHashTable)
            return loadFrom(childKey, parentKey, whichHashTable, 'handle')
        end

        do
            local sub = string.sub
            for key in pairs(_G) do
                if sub(key, -8) == "HandleBJ" then
                    local str = sub(key, 1, 4)
                    if str == "Save" then
                        _G[key] = saveHandle
                    elseif str == "Load" then
                        _G[key] = loadHandle
                    end
                end
            end
        end

        ---@param childKey unknown
        ---@param valueType integer
        ---@param parentKey unknown
        ---@param whichHashTable FakeHashtable
        ---@return boolean
        function HaveSavedValue(childKey, valueType, parentKey, whichHashTable)
            assert(childKey ~= nil, 'childKey cannot be nil')
            assert(parentKey ~= nil, 'parentKey cannot be nil')
            assert(whichHashTable ~= nil, 'whichHashTable cannot be nil')
            if (valueType == bj_HASHTABLE_BOOLEAN) then
                return load(whichHashTable, 'boolean', parentKey)[childKey] ~= nil
            elseif (valueType == bj_HASHTABLE_INTEGER) then
                return load(whichHashTable, 'integer', parentKey)[childKey] ~= nil
            elseif (valueType == bj_HASHTABLE_REAL) then
                return load(whichHashTable, 'real', parentKey)[childKey] ~= nil
            elseif (valueType == bj_HASHTABLE_STRING) then
                return load(whichHashTable, 'string', parentKey)[childKey] ~= nil
            elseif (valueType == bj_HASHTABLE_HANDLE) then
                return load(whichHashTable, 'handle', parentKey)[childKey] ~= nil
            else
                --  Unrecognized value type - ignore the request.
                return false
            end
        end

        ---@param whichHashTable FakeHashtable
        function FlushParentHashtableBJ(whichHashTable)
            assert(whichHashTable ~= nil, 'whichHashTable cannot be nil')
            whichHashTable.boolean = nil
            whichHashTable.integer = nil
            whichHashTable.real = nil
            whichHashTable.string = nil
            whichHashTable.handle = nil
        end

        ---@param parentKey unknown
        ---@param whichHashTable FakeHashtable
        function FlushChildHashtableBJ(parentKey, whichHashTable)
            assert(whichHashTable ~= nil, 'whichHashTable cannot be nil')
            assert(parentKey ~= nil, 'parentKey cannot be nil')
            whichHashTable.boolean[parentKey] = nil
            whichHashTable.integer[parentKey] = nil
            whichHashTable.real[parentKey] = nil
            whichHashTable.string[parentKey] = nil
            whichHashTable.handle[parentKey] = nil
        end
    end
    --[===========================[
      • LOCATIONS (POINTS IN GUI) •
    --]===========================]
    do
        ---@class FakeLocation: FakedType
        ---@field [1] number x
        ---@field [2] number y

        local oldLocation = Location
        local location

        ---@param x number
        ---@param y number
        ---@return FakeLocation
        function Location(x, y)
            assert(x ~= nil, 'x cannot be nil')
            assert(y ~= nil, 'y cannot be nil')
            return { x, y, __faketype = fakeTypes.FakeLocation }
        end

        do
            local oldRemove = RemoveLocation
            local oldGetX   = GetLocationX
            local oldGetY   = GetLocationY
            local oldRally  = GetUnitRallyPoint

            ---@param unit unit
            ---@return FakeLocation
            function GetUnitRallyPoint(unit)
                assert(unit ~= nil, 'unit cannot be nil')
                local removeThis = oldRally(unit) --Actually needs to create a location for a brief moment, as there is no GetUnitRallyX/Y
                local loc = Location(oldGetX(removeThis), oldGetY(removeThis))
                oldRemove(removeThis)
                return loc
            end
        end

        RemoveLocation = DoNothing ---@type fun(location: FakeLocation)

        do
            local oldMoveLoc = MoveLocation
            local oldGetZ = GetLocationZ

            ---@param x number
            ---@param y number
            ---@return number z
            function GUI.getCoordZ(x, y)
                function GUI.getCoordZ(x, y)
                    assert(x ~= nil, 'x cannot be nil')
                    assert(y ~= nil, 'y cannot be nil')
                    oldMoveLoc(location, x, y)
                    return oldGetZ(location)
                end

                location = oldLocation(x, y)
                return GUI.getCoordZ(x, y)
            end
        end

        ---@param loc FakeLocation
        ---@return number x
        function GetLocationX(loc)
            assert(loc ~= nil, 'loc cannot be nil')
            return loc[1]
        end

        ---@param loc FakeLocation
        ---@return number y
        function GetLocationY(loc)
            assert(loc ~= nil, 'loc cannot be nil')
            return loc[2]
        end

        ---@param loc FakeLocation
        ---@return number z
        function GetLocationZ(loc)
            assert(loc ~= nil, 'loc cannot be nil')
            return GUI.getCoordZ(loc[1], loc[2])
        end

        ---@param loc FakeLocation
        ---@param x number
        ---@param y number
        function MoveLocation(loc, x, y)
            assert(loc ~= nil, 'loc cannot be nil')
            loc[1] = x
            loc[2] = y
        end

        ---@param varName string
        ---@param suffix string|nil
        local function fakeCreate(varName, suffix)
            local getX = _G[varName .. "X"]
            local getY = _G[varName .. "Y"]
            _G[varName .. (suffix or "Loc")] = function(obj) return Location(getX(obj), getY(obj)) end
        end
        fakeCreate("GetUnit")
        fakeCreate("GetOrderPoint")
        fakeCreate("GetSpellTarget")
        fakeCreate("CameraSetupGetDestPosition")
        fakeCreate("GetCameraTargetPosition")
        fakeCreate("GetCameraEyePosition")
        fakeCreate("BlzGetTriggerPlayerMouse", "Position")
        fakeCreate("GetStartLocation")

        ---@param effect effect
        ---@param loc FakeLocation
        function BlzSetSpecialEffectPositionLoc(effect, loc)
            assert(effect ~= nil, 'effect cannot be nil')
            assert(loc ~= nil, 'loc cannot be nil')
            local x, y = loc[1], loc[2]
            BlzSetSpecialEffectPosition(effect, x, y, GUI.getCoordZ(x, y))
        end

        ---@param oldVarName string
        ---@param newVarName string
        ---@param index integer needed to determine which of the parameters calls for a location.
        local function hook(oldVarName, newVarName, index)
            local new = _G[newVarName]
            local func
            if index == 1 then
                func = function(loc, ...)
                    return new(loc[1], loc[2], ...)
                end
            elseif index == 2 then
                func = function(a, loc, ...)
                    return new(a, loc[1], loc[2], ...)
                end
            else --index==3
                func = function(a, b, loc, ...)
                    return new(a, b, loc[1], loc[2], ...)
                end
            end
            _G[oldVarName] = func
        end
        hook("IsLocationInRegion", "IsPointInRegion", 2)
        hook("IsUnitInRangeLoc", "IsUnitInRangeXY", 2)
        hook("IssuePointOrderLoc", "IssuePointOrder", 3)
        IssuePointOrderLocBJ = IssuePointOrderLoc
        hook("IssuePointOrderByIdLoc", "IssuePointOrderById", 3)
        hook("IsLocationVisibleToPlayer", "IsVisibleToPlayer", 1)
        hook("IsLocationFoggedToPlayer", "IsFoggedToPlayer", 1)
        hook("IsLocationMaskedToPlayer", "IsMaskedToPlayer", 1)
        hook("CreateFogModifierRadiusLoc", "CreateFogModifierRadius", 3)
        hook("AddSpecialEffectLoc", "AddSpecialEffect", 2)
        hook("AddSpellEffectLoc", "AddSpellEffect", 3)
        hook("AddSpellEffectByIdLoc", "AddSpellEffectById", 3)
        hook("SetBlightLoc", "SetBlight", 2)
        hook("DefineStartLocationLoc", "DefineStartLocation", 2)
        hook("GroupEnumUnitsInRangeOfLoc", "GroupEnumUnitsInRange", 2)
        hook("GroupEnumUnitsInRangeOfLocCounted", "GroupEnumUnitsInRangeCounted", 2)
        hook("GroupPointOrderLoc", "GroupPointOrder", 3)
        GroupPointOrderLocBJ = GroupPointOrderLoc
        hook("GroupPointOrderByIdLoc", "GroupPointOrderById", 3)
        hook("MoveRectToLoc", "MoveRectTo", 2)
        hook("RegionAddCellAtLoc", "RegionAddCell", 2)
        hook("RegionClearCellAtLoc", "RegionClearCell", 2)
        hook("CreateUnitAtLoc", "CreateUnit", 3)
        hook("CreateUnitAtLocByName", "CreateUnitByName", 3)
        hook("SetUnitPositionLoc", "SetUnitPosition", 2)
        hook("ReviveHeroLoc", "ReviveHero", 2)
        hook("SetFogStateRadiusLoc", "SetFogStateRadius", 3)

        ---@param min FakeLocation
        ---@param max FakeLocation
        ---@return FakeRect newRect
        function RectFromLoc(min, max)
            assert(min ~= nil, 'min cannot be nil')
            assert(max ~= nil, 'max cannot be nil')
            return Rect(min[1], min[2], max[1], max[2]) --[[@as FakeRect]]
        end

        ---@param whichRect FakeRect
        ---@param min FakeLocation
        ---@param max FakeLocation
        function SetRectFromLoc(whichRect, min, max)
            assert(min ~= nil, 'min cannot be nil')
            assert(max ~= nil, 'max cannot be nil')
            SetRect(whichRect, min[1], min[2], max[1], max[2])
        end
    end
    --[=============================[
      • GROUPS (UNIT GROUPS IN GUI) •
    --]=============================]
    do
        local mainGroup = bj_lastCreatedGroup
        DestroyGroup(bj_suspendDecayFleshGroup --[[@as group]])
        DestroyGroup(bj_suspendDecayBoneGroup --[[@as group]])
        DestroyGroup = DoNothing

        ---@class FakeGroup: FakedType
        ---@field [integer] unit
        ---@field indexOf {[unit]: integer}

        ---@return FakeGroup
        function CreateGroup()
            return { indexOf = {}, __faketype = fakeTypes.FakeGroup }
        end

        bj_lastCreatedGroup = CreateGroup()
        bj_suspendDecayFleshGroup = CreateGroup()
        bj_suspendDecayBoneGroup = CreateGroup()

        local groups ---@type table<unit, FakeGroup>
        if _USE_UNIT_EVENT then
            groups = {}

            ---@param group FakeGroup
            function GroupClear(group)
                assert(group ~= nil, 'group cannot be nil')
                local u
                for i = 1, #group do
                    u = group[i]
                    groups[u] = nil
                    group.indexOf[u] = nil
                    group[i] = nil
                end
            end
        else
            ---@param group FakeGroup
            function GroupClear(group)
                assert(group ~= nil, 'group cannot be nil')
                for i = 1, #group do
                    group.indexOf[group[i]] = nil
                    group[i] = nil
                end
            end
        end

        ---@param group FakeGroup
        ---@param unit unit
        function GroupAddUnit(group, unit)
            assert(group ~= nil, 'group cannot be nil')
            assert(unit ~= nil, 'unit cannot be nil')
            if group.indexOf[unit] then return end

            local pos = #group + 1
            group.indexOf[unit] = pos
            group[pos] = unit
            if groups then
                groups[unit] = groups[unit] or __jarray()
                groups[unit][group] = true
            end
        end

        ---@param group FakeGroup
        ---@param unit unit
        function GroupRemoveUnit(group, unit)
            assert(group ~= nil, 'group cannot be nil')
            assert(unit ~= nil, 'unit cannot be nil')
            local indexOf = group.indexOf
            if indexOf == nil then return end
            local pos = indexOf[unit]
            if pos == nil then return end

            local size = #group
            if pos ~= size then
                indexOf[group[size]] = pos
            end
            group[size] = nil
            indexOf[unit] = nil
            if groups then
                groups[unit][group] = nil
            end
        end

        ---@param unit unit
        ---@param group FakeGroup
        ---@return boolean
        function IsUnitInGroup(unit, group)
            assert(unit ~= nil, 'unti cannot be nil')
            assert(group ~= nil, 'group cannot be nil')
            return group.indexOf[unit] and true or false
        end

        ---@param group FakeGroup
        ---@return unit|nil
        function FirstOfGroup(group)
            assert(group ~= nil, 'group cannot be nil')
            return group[1]
        end

        local enumUnit
        ---@return unit enumUnit
        function GetEnumUnit()
            return enumUnit
        end

        ---@param group FakeGroup
        ---@param code fun(u: unit)
        function GUI.forGroup(group, code)
            assert(group ~= nil, 'group cannot be nil')
            assert(code ~= nil, 'code cannot be nil')
            for i = 1, #group do
                code(group[i])
            end
        end

        ---@param group FakeGroup
        ---@param code fun(u)
        function ForGroup(group, code)
            assert(group ~= nil, 'group cannot be nil')
            assert(code ~= nil, 'code cannot be nil')
            local old = enumUnit
            GUI.forGroup(group, function(unit)
                enumUnit = unit
                code()
            end)
            enumUnit = old
        end

        do
            local oldUnitAt = BlzGroupUnitAt

            ---@param group FakeGroup
            ---@param index integer
            ---@return unit|nil
            function BlzGroupUnitAt(group, index)
                assert(group ~= nil, 'group cannot be nil')
                assert(index ~= nil, 'index cannot be nil')
                return group[index + 1]
            end

            local oldGetSize = BlzGroupGetSize

            ---@param code fun(u: unit)
            local function groupAction(code)
                for i = 0, oldGetSize(mainGroup) - 1 do
                    code(oldUnitAt(mainGroup, i) --[[@as unit should be fine]])
                end
            end
            for _, name in ipairs({
                "OfType",
                "OfPlayer",
                "OfTypeCounted",
                "InRect",
                "InRectCounted",
                "InRange",
                "InRangeOfLoc",
                "InRangeCounted",
                "InRangeOfLocCounted",
                "Selected"
            }) do
                local varStr = "GroupEnumUnits" .. name
                local old = _G[varStr]

                ---@param group FakeGroup
                ---@param ... unknown
                _G[varStr] = function(group, ...)
                    if group then
                        old(mainGroup, ...)
                        GroupClear(group)
                        groupAction(function(unit)
                            GroupAddUnit(group, unit)
                        end)
                    end
                end
                --Provide API for Lua users who just want to efficiently run code, without caring about the group itself.
                ---@param code fun(group: FakeGroup, ...: unknown)
                ---@param ... unknown
                GUI["enumUnits" .. name] = function(code, ...)
                    assert(code ~= nil, 'code cannot be nil')
                    old(mainGroup, ...)
                    groupAction(code)
                end
            end
        end

        for _, name in ipairs {
            "ImmediateOrder",
            "ImmediateOrderById",
            "PointOrder",
            "PointOrderById",
            "TargetOrder",
            "TargetOrderById"
        } do
            local new = _G["Issue" .. name]

            ---@param group FakeGroup
            ---@param ... unknown
            _G["Group" .. name] = function(group, ...)
                for i = 1, #group do
                    new(group[i], ...)
                end
            end
        end
        GroupTrainOrderByIdBJ = GroupImmediateOrderById

        ---@param group FakeGroup
        ---@return integer
        function BlzGroupGetSize(group)
            assert(group ~= nil, 'group cannot be nil')
            return #group
        end

        ---@param group FakeGroup
        ---@param add FakeGroup
        function GroupAddGroup(group, add)
            assert(group ~= nil, 'group cannot be nil')
            assert(add ~= nil, 'add cannot be nil')
            GUI.forGroup(add, function(unit)
                GroupAddUnit(group, unit)
            end)
        end

        ---@param group FakeGroup
        ---@param remove FakeGroup
        function GroupRemoveGroup(group, remove)
            assert(group ~= nil, 'group cannot be nil')
            assert(remove ~= nil, 'remove cannot be nil')
            GUI.forGroup(remove, function(unit)
                GroupRemoveUnit(group, unit)
            end)
        end

        ---@param group FakeGroup
        ---@return unit|nil
        function GroupPickRandomUnit(group)
            assert(group ~= nil, 'group cannot be nil')
            return group[1] and group[GetRandomInt(1, #group)]
        end

        ---@param group FakeGroup
        ---@return boolean
        function IsUnitGroupEmptyBJ(group)
            assert(group ~= nil, 'group cannot be nil')
            return not group[1]
        end

        ForGroupBJ = ForGroup
        CountUnitsInGroup = BlzGroupGetSize
        BlzGroupAddGroupFast = GroupAddGroup
        BlzGroupRemoveGroupFast = GroupRemoveGroup
        GroupPickRandomUnitEnum = nil
        CountUnitsInGroupEnum = nil
        GroupAddGroupEnum = nil
        GroupRemoveGroupEnum = nil

        if groups then
            OnInit(function(import)
                import "UnitEvent"
                ---@param data {unit: unit}
                UnitEvent.onRemoval(function(data)
                    local u = data.unit
                    local g = groups[u]
                    if g then
                        for _, group in pairs(g) do
                            GroupRemoveUnit(group, u)
                        end
                    end
                end)
            end)
        end
    end
    --[========================[
      • RECTS (REGIONS IN GUI) •
    --]========================]
    do
        ---@class FakeRect: FakedType
        ---@field [1] number minX
        ---@field [2] number minY
        ---@field [3] number maxX
        ---@field [4] number maxY

        local oldRect, rect = Rect, nil
        ---@param minX number
        ---@param minY number
        ---@param maxX number
        ---@param maxY number
        ---@return FakeRect
        function Rect(minX, minY, maxX, maxY)
            assert(minX ~= nil, 'minX cannot be nil')
            assert(minY ~= nil, 'minY cannot be nil')
            assert(maxX ~= nil, 'maxX cannot be nil')
            assert(maxY ~= nil, 'maxY cannot be nil')
            return { minX, minY, maxX, maxY, __faketype = fakeTypes.FakeRect }
        end

        local oldSetRect = SetRect
        ---@param rect FakeRect
        ---@param minX number
        ---@param minY number
        ---@param maxX number
        ---@param maxY number
        function SetRect(rect, minX, minY, maxX, maxY)
            assert(rect ~= nil, 'rect cannot be nil')
            assert(minX ~= nil, 'minX cannot be nil')
            assert(minY ~= nil, 'minY cannot be nil')
            assert(maxX ~= nil, 'maxX cannot be nil')
            assert(maxY ~= nil, 'maxY cannot be nil')
            rect[1] = minX
            rect[2] = minY
            rect[3] = maxX
            rect[4] = maxY
        end

        do
            local oldWorld = GetWorldBounds
            local getMinX = GetRectMinX
            local getMinY = GetRectMinY
            local getMaxX = GetRectMaxX
            local getMaxY = GetRectMaxY
            local remover = RemoveRect
            RemoveRect = DoNothing
            local newWorld

            ---@return FakeRect
            function GetWorldBounds()
                if not newWorld then
                    local w = oldWorld() --[[@as rect]]
                    newWorld = Rect(getMinX(w), getMinY(w), getMaxX(w), getMaxY(w))
                    remover(w)
                end
                return Rect(unpack(newWorld))
            end

            GetEntireMapRect = GetWorldBounds
        end

        ---@param rect FakeRect
        ---@return number
        function GetRectMinX(rect)
            assert(rect ~= nil, 'rect cannot be nil')
            return rect[1]
        end

        ---@param rect FakeRect
        ---@return number
        function GetRectMinY(rect)
            assert(rect ~= nil, 'rect cannot be nil')
            return rect[2]
        end

        ---@param rect FakeRect
        ---@return number
        function GetRectMaxX(rect)
            assert(rect ~= nil, 'rect cannot be nil')
            return rect[3]
        end

        ---@param rect FakeRect
        ---@return number
        function GetRectMaxY(rect)
            assert(rect ~= nil, 'rect cannot be nil')
            return rect[4]
        end

        ---@param rect FakeRect
        ---@return number
        function GetRectCenterX(rect)
            assert(rect ~= nil, 'rect cannot be nil')
            return (rect[1] + rect[3]) / 2
        end

        ---@param rect FakeRect
        ---@return number
        function GetRectCenterY(rect)
            assert(rect ~= nil, 'rect cannot be nil')
            return (rect[2] + rect[4]) / 2
        end

        ---@param rect FakeRect
        ---@param x number
        ---@param y number
        function MoveRectTo(rect, x, y)
            assert(rect ~= nil, 'rect cannot be nil')
            assert(x ~= nil, 'x cannot be nil')
            assert(y ~= nil, 'y cannot be nil')
            x = x - GetRectCenterX(rect)
            y = y - GetRectCenterY(rect)
            SetRect(rect, rect[1] + x, rect[2] + y, rect[3] + x, rect[4] + y)
        end

        ---@param varName string
        ---@param index integer needed to determine which of the parameters calls for a rect.
        local function hook(varName, index)
            local old = _G[varName]
            local func
            if index == 1 then
                func = function(rct, ...)
                    oldSetRect(rect --[[@as rect]], unpack(rct))
                    return old(rect, ...)
                end
            elseif index == 2 then
                func = function(a, rct, ...)
                    oldSetRect(rect --[[@as rect]], unpack(rct))
                    return old(a, rect, ...)
                end
            else --index==3
                func = function(a, b, rct, ...)
                    oldSetRect(rect --[[@as rect]], unpack(rct))
                    return old(a, b, rect, ...)
                end
            end

            ---@param ... unknown
            _G[varName] = function(...)
                if not rect then rect = oldRect(0, 0, 32, 32) end
                _G[varName] = func
                return func(...)
            end
        end
        hook("EnumDestructablesInRect", 1)
        hook("EnumItemsInRect", 1)
        hook("AddWeatherEffect", 1)
        hook("SetDoodadAnimationRect", 1)
        hook("GroupEnumUnitsInRect", 2)
        hook("GroupEnumUnitsInRectCounted", 2)
        hook("RegionAddRect", 2)
        hook("RegionClearRect", 2)
        hook("SetBlightRect", 2)
        hook("SetFogStateRect", 3)
        hook("CreateFogModifierRect", 3)
    end
    --[===============================[
      • FORCES (PLAYER GROUPS IN GUI) •
    --]===============================]
    do
        ---@class FakeForce: FakedType
        ---@field [integer] player
        ---@field indexOf {[player]: integer}

        local oldForce, mainForce = CreateForce, nil
        local function initForce()
            initForce = DoNothing
            mainForce = oldForce()
        end

        ---@return FakeForce
        function CreateForce()
            return { indexOf = {}, __faketype = fakeTypes.FakeForce }
        end

        DestroyForce = DoNothing ---@type fun(force: FakeForce)
        local oldClear = ForceClear

        ---@param force FakeForce
        function ForceClear(force)
            assert(force ~= nil, 'force cannot be nil')
            for i, val in ipairs(force) do
                force.indexOf[val] = nil
                force[i] = nil
            end
        end

        do
            local oldCripple = CripplePlayer
            local oldAdd = ForceAddPlayer

            ---@param player player
            ---@param force FakeForce
            ---@param flag boolean
            function GUI.cripplePlayer(player, force, flag)
                function GUI.cripplePlayer(player, force, flag)
                    for _, val in ipairs(force) do
                        oldAdd(mainForce --[[@ as force]], val)
                    end
                    oldCripple(player, mainForce --[[@ as force]], flag)
                    oldClear(mainForce --[[@ as force]])
                end

                initForce()
                GUI.cripplePlayer(player, force, flag)
            end

            ---@param player player
            ---@param force FakeForce
            ---@param flag boolean
            function CripplePlayer(player, force, flag)
                assert(player ~= nil, 'player cannot be nil')
                assert(force ~= nil, 'force cannot be nil')
                GUI.cripplePlayer(player, force, flag)
            end
        end

        ---@param force FakeForce
        ---@param player player
        function ForceAddPlayer(force, player)
            assert(force ~= nil, 'force cannot be nil')
            assert(player ~= nil, 'player cannot be nil')
            if force.indexOf[player] then return end

            local pos = #force + 1
            force.indexOf[player] = pos
            force[pos] = player
        end

        ---@param force FakeForce
        ---@param player player
        function ForceRemovePlayer(force, player)
            assert(force ~= nil, 'force cannot be nil')
            assert(player ~= nil, 'player cannot be nil')
            local pos = force.indexOf[player]
            if pos == nil then return end

            force.indexOf[player] = nil
            local top = #force
            if pos ~= top then
                force[pos] = force[top]
                force.indexOf[force[top]] = pos
            end
            force[top] = nil
        end

        ---@param force FakeForce
        ---@param player player
        ---@return boolean
        function BlzForceHasPlayer(force, player)
            assert(force ~= nil, 'force cannot be nil')
            assert(player ~= nil, 'player cannot be nil')
            return force.indexOf[player] and true or false
        end

        ---@param player player
        ---@param force FakeForce
        ---@return boolean
        function IsPlayerInForce(player, force)
            assert(player ~= nil, 'player cannot be nil')
            assert(force ~= nil, 'force cannot be nil')
            return force.indexOf[player] and true or false
        end

        ---@param unit unit
        ---@param force FakeForce
        ---@return boolean
        function IsUnitInForce(unit, force)
            assert(unit ~= nil, 'unit cannot be nil')
            assert(force ~= nil, 'force cannot be nil')
            return force.indexOf[GetOwningPlayer(unit)] and true or false
        end

        local enumPlayer
        local oldForForce = ForForce
        local oldEnumPlayer = GetEnumPlayer

        ---@return player
        function GetEnumPlayer()
            return enumPlayer
        end

        ---@param force FakeForce
        ---@param code function
        function ForForce(force, code)
            assert(force ~= nil, 'force cannot be nil')
            assert(code ~= nil, 'code cannot be nil')
            local old = enumPlayer
            for _, player in ipairs(force) do
                enumPlayer = player
                code()
            end
            enumPlayer = old
        end

        ---@param force FakeForce
        local function funnelEnum(force)
            assert(force ~= nil, 'force cannot be nil')
            ForceClear(force)
            oldForForce(mainForce, function()
                ForceAddPlayer(force, oldEnumPlayer())
            end)
            oldClear(mainForce --[[@as force]])
        end
        ---@param varStr string
        local function hookEnum(varStr)
            local old = _G[varStr]
            local deferred
            function deferred(force, ...)
                function deferred(force, ...)
                    old(mainForce, ...)
                    funnelEnum(force)
                end

                initForce()
                _G[varStr](force, ...)
            end

            _G[varStr] = function(force, ...)
                assert(force ~= nil, 'force cannot be nil')
                deferred(force, ...)
            end
        end
        hookEnum("ForceEnumPlayers")
        hookEnum("ForceEnumPlayersCounted")
        hookEnum("ForceEnumAllies")
        hookEnum("ForceEnumEnemies")
        ---@param force FakeForce
        ---@return integer
        function CountPlayersInForceBJ(force)
            assert(force ~= nil, 'force cannot be nil')
            return #force
        end

        CountPlayersInForceEnum = nil

        ---@param player player
        ---@return FakeForce
        function GetForceOfPlayer(player)
            assert(player ~= nil, 'player cannot be nil')
            --No longer leaks. There was no reason to dynamically create forces to begin with.
            return bj_FORCE_PLAYER[GetPlayerId(player)]
        end
    end

    -- section on Blizzard.j desyncable objects
    do
        local desyncCausingTimer1 = bj_queuedExecTimeoutTimer
        local desyncCausingTimer2 = bj_delayedSuspendDecayTimer
        local desyncCausingTimer3 = bj_volumeGroupsTimer
        local desyncCausingTimer4 = bj_lastStartedTimer
        function GUI.__constantly_loaded()
            -- some nonsense lines to make sure this function "always" needs the relevant upvalues
            if desyncCausingTimer1 then return true end
            if desyncCausingTimer2 then return true end
            if desyncCausingTimer3 then return true end
            if desyncCausingTimer4 then return true end
        end
    end

    --Blizzard forgot to add this, but still enabled it for GUI. Therefore, I've extracted and simplified the code from DebugIdInteger2IdString
    ---@param value integer
    ---@return string
    function BlzFourCC2S(value)
        if value == nil then return "" end
        local result = ""
        for _ = 1, 4 do
            result = string.char(value % 256) .. result
            value = value // 256
        end
        return result
    end

    ---@param trig trigger
    ---@param r FakeRect
    function TriggerRegisterDestDeathInRegionEvent(trig, r)
        assert(trig ~= nil, 'trigger cannot be nil')
        assert(r ~= nil, 'rect cannot be nil')
        --Removes the limit on the number of destructables that can be registered.
        EnumDestructablesInRect(r, nil, function() TriggerRegisterDeathEvent(trig, GetEnumDestructable()) end)
    end

    IsUnitAliveBJ = UnitAlive --use the reliable native instead of the life checks

    ---@param u unit
    ---@return boolean
    function IsUnitDeadBJ(u)
        return not UnitAlive(u)
    end

    ---@param whichUnit unit
    ---@param propWindow number
    function SetUnitPropWindowBJ(whichUnit, propWindow)
        --Allows the Prop Window to be set to zero to allow unit movement to be suspended.
        SetUnitPropWindow(whichUnit, math.rad(propWindow))
    end

    if _USE_GLOBAL_REMAP then
        OnInit(function(import)
            import "GlobalRemap"
            GlobalRemap("udg_INFINITE_LOOP", function() return -1 end) --a readonly variable for infinite looping in GUI.
        end)
    end

    do
        local cache = __jarray()

        ---@param whichTrig trigger
        function GUI.wrapTrigger(whichTrig)
            assert(whichTrig ~= nil, 'whichTrig cannot be nil')
            local func = cache[whichTrig]
            if not func then
                func = function()
                    if IsTriggerEnabled(whichTrig) and TriggerEvaluate(whichTrig) then
                        TriggerExecute(whichTrig)
                    end
                end
                cache[whichTrig] = func
            end
            return func
        end
    end
    do
        --[[---------------------------------------------------------------------------------------------
            RegisterAnyPlayerUnitEvent by Bribe

            RegisterAnyPlayerUnitEvent cuts down on handle count for alread-registered events, plus has
            the benefit for Lua users to just use function calls.

            Adds a third parameter to the RegisterAnyPlayerUnitEvent function: "skip". If true, disables
            the specified event, while allowing a single function to run discretely. It also allows (if
            Global Variable Remapper is included) GUI to un-register a playerunitevent by setting
            udg_RemoveAnyUnitEvent to the trigger they wish to remove.

            The "return" value of RegisterAnyPlayerUnitEvent calls the "remove" method. The API, therefore,
            has been reduced to just this one function (in addition to the bj override).
        -----------------------------------------------------------------------------------------------]]
        local fStack, tStack, oldBJ = {}, {},
            TriggerRegisterAnyUnitEventBJ ---@type {[eventid]: function[]}, {[eventid]: trigger[]}

        ---@param event eventid
        ---@param userFunc function
        ---@param skip boolean?
        function RegisterAnyPlayerUnitEvent(event, userFunc, skip)
            assert(event ~= nil, 'event cannot be nil')
            assert(userFunc ~= nil, 'userFunc cannot be nil')
            if skip then
                local t = tStack[event]
                if t and IsTriggerEnabled(t) then
                    DisableTrigger(t)
                    userFunc()
                    EnableTrigger(t)
                else
                    userFunc()
                end
            else
                local funcs, insertAt = fStack[event], 1
                if funcs then
                    insertAt = #funcs + 1
                    if insertAt == 1 then EnableTrigger(tStack[event]) end
                else
                    local t = CreateTrigger()
                    oldBJ(t, event)
                    tStack[event], funcs = t, {}
                    fStack[event] = funcs
                    TriggerAddCondition(t, Filter(function()
                        for _, func in ipairs(funcs) do func() end
                    end))
                end
                funcs[insertAt] = userFunc
                return function()
                    local total = #funcs
                    for i = 1, total do
                        if funcs[i] == userFunc then
                            if total == 1 then
                                DisableTrigger(tStack[event]) --no more events are registered, disable the event (for now).
                            elseif total > i then
                                funcs[i] = funcs[total]
                            end                --pop just the top index down to this vacant slot so we don't have to down-shift the entire stack.
                            funcs[total] = nil --remove the top entry.
                            return true
                        end
                    end
                end
            end
        end

        local trigFuncs
        ---@param trig trigger
        ---@param event eventid
        ---@return function|nil
        function TriggerRegisterAnyUnitEventBJ(trig, event)
            assert(trig ~= nil, 'trig cannot be nil')
            assert(event ~= nil, 'event cannot be nil')
            local removeFunc = RegisterAnyPlayerUnitEvent(event, GUI.wrapTrigger(trig))
            if _USE_GLOBAL_REMAP then
                if not trigFuncs then
                    trigFuncs = __jarray()
                    GlobalRemap("udg_RemoveAnyUnitEvent", nil, function(t)
                        if trigFuncs[t] then
                            trigFuncs[t]()
                            trigFuncs[t] = nil
                        end
                    end)
                end
                trigFuncs[trig] = removeFunc
            end
            return removeFunc
        end
    end

    ---Modify to allow requests for negative hero stats, as per request from Tasyen.
    ---@param whichHero unit
    ---@param whichStat integer
    ---@param value integer
    function SetHeroStat(whichHero, whichStat, value)
        assert(whichStat ~= nil, 'whichStat cannot be nil')
        (whichStat == bj_HEROSTAT_STR and SetHeroStr or whichStat == bj_HEROSTAT_AGI and SetHeroAgi or SetHeroInt)(
                whichHero, value, true)
    end

    --The next part of the code is purely optional, as it is intended to optimize rather than add new functionality
    CommentString                        = nil
    RegisterDestDeathInRegionEnum        = nil

    --This next list comes from HerlySQR, and its purpose is to eliminate useless wrapper functions (only where the parameters aligned):
    StringIdentity                       = GetLocalizedString
    TriggerRegisterTimerExpireEventBJ    = TriggerRegisterTimerExpireEvent
    TriggerRegisterDialogEventBJ         = TriggerRegisterDialogEvent
    TriggerRegisterUpgradeCommandEventBJ = TriggerRegisterUpgradeCommandEvent
    RemoveWeatherEffectBJ                = RemoveWeatherEffect
    DestroyLightningBJ                   = DestroyLightning
    GetLightningColorABJ                 = GetLightningColorA
    GetLightningColorRBJ                 = GetLightningColorR
    GetLightningColorGBJ                 = GetLightningColorG
    GetLightningColorBBJ                 = GetLightningColorB
    SetLightningColorBJ                  = SetLightningColor
    GetAbilityEffectBJ                   = GetAbilityEffectById
    GetAbilitySoundBJ                    = GetAbilitySoundById
    ResetTerrainFogBJ                    = ResetTerrainFog
    SetSoundDistanceCutoffBJ             = SetSoundDistanceCutoff
    SetSoundPitchBJ                      = SetSoundPitch
    AttachSoundToUnitBJ                  = AttachSoundToUnit
    KillSoundWhenDoneBJ                  = KillSoundWhenDone
    PlayThematicMusicBJ                  = PlayThematicMusic
    EndThematicMusicBJ                   = EndThematicMusic
    StopMusicBJ                          = StopMusic
    ResumeMusicBJ                        = ResumeMusic
    VolumeGroupResetImmediateBJ          = VolumeGroupReset
    WaitForSoundBJ                       = TriggerWaitForSound
    ClearMapMusicBJ                      = ClearMapMusic
    DestroyEffectBJ                      = DestroyEffect
    GetItemLifeBJ                        = GetWidgetLife     -- This was just to type casting
    SetItemLifeBJ                        = SetWidgetLife     -- This was just to type casting
    UnitRemoveBuffBJ                     = UnitRemoveAbility -- The buffs are abilities
    GetLearnedSkillBJ                    = GetLearnedSkill
    UnitDropItemPointBJ                  = UnitDropItemPoint
    UnitDropItemTargetBJ                 = UnitDropItemTarget
    UnitUseItemDestructable              = UnitUseItemTarget -- This was just to type casting
    UnitInventorySizeBJ                  = UnitInventorySize
    SetItemInvulnerableBJ                = SetItemInvulnerable
    SetItemDropOnDeathBJ                 = SetItemDropOnDeath
    SetItemDroppableBJ                   = SetItemDroppable
    SetItemPlayerBJ                      = SetItemPlayer
    ChooseRandomItemBJ                   = ChooseRandomItem
    ChooseRandomNPBuildingBJ             = ChooseRandomNPBuilding
    ChooseRandomCreepBJ                  = ChooseRandomCreep
    String2UnitIdBJ                      = UnitId -- I think they just wanted a better name
    GetIssuedOrderIdBJ                   = GetIssuedOrderId
    GetKillingUnitBJ                     = GetKillingUnit
    IsUnitHiddenBJ                       = IsUnitHidden
    IssueTrainOrderByIdBJ                = IssueImmediateOrderById -- I think they just wanted a better name
    IssueUpgradeOrderByIdBJ              = IssueImmediateOrderById -- I think they just wanted a better name
    GetAttackedUnitBJ                    = GetTriggerUnit          -- I think they just wanted a better name
    SetUnitFlyHeightBJ                   = SetUnitFlyHeight
    SetUnitTurnSpeedBJ                   = SetUnitTurnSpeed
    GetUnitDefaultPropWindowBJ           = GetUnitDefaultPropWindow
    SetUnitBlendTimeBJ                   = SetUnitBlendTime
    SetUnitAcquireRangeBJ                = SetUnitAcquireRange
    UnitSetCanSleepBJ                    = UnitAddSleep
    UnitCanSleepBJ                       = UnitCanSleep
    UnitWakeUpBJ                         = UnitWakeUp
    UnitIsSleepingBJ                     = UnitIsSleeping
    IsUnitPausedBJ                       = IsUnitPaused
    SetUnitExplodedBJ                    = SetUnitExploded
    GetTransportUnitBJ                   = GetTransportUnit
    GetLoadedUnitBJ                      = GetLoadedUnit
    IsUnitInTransportBJ                  = IsUnitInTransport
    IsUnitLoadedBJ                       = IsUnitLoaded
    IsUnitIllusionBJ                     = IsUnitIllusion
    SetDestructableInvulnerableBJ        = SetDestructableInvulnerable
    IsDestructableInvulnerableBJ         = IsDestructableInvulnerable
    SetDestructableMaxLifeBJ             = SetDestructableMaxLife
    WaygateIsActiveBJ                    = WaygateIsActive
    QueueUnitAnimationBJ                 = QueueUnitAnimation
    SetDestructableAnimationBJ           = SetDestructableAnimation
    QueueDestructableAnimationBJ         = QueueDestructableAnimation
    DialogSetMessageBJ                   = DialogSetMessage
    DialogClearBJ                        = DialogClear
    GetClickedButtonBJ                   = GetClickedButton
    GetClickedDialogBJ                   = GetClickedDialog
    DestroyQuestBJ                       = DestroyQuest
    QuestSetTitleBJ                      = QuestSetTitle
    QuestSetDescriptionBJ                = QuestSetDescription
    QuestSetCompletedBJ                  = QuestSetCompleted
    QuestSetFailedBJ                     = QuestSetFailed
    QuestSetDiscoveredBJ                 = QuestSetDiscovered
    QuestItemSetDescriptionBJ            = QuestItemSetDescription
    QuestItemSetCompletedBJ              = QuestItemSetCompleted
    DestroyDefeatConditionBJ             = DestroyDefeatCondition
    DefeatConditionSetDescriptionBJ      = DefeatConditionSetDescription
    FlashQuestDialogButtonBJ             = FlashQuestDialogButton
    DestroyTimerBJ                       = DestroyTimer
    DestroyTimerDialogBJ                 = DestroyTimerDialog
    TimerDialogSetTitleBJ                = TimerDialogSetTitle
    TimerDialogSetSpeedBJ                = TimerDialogSetSpeed
    TimerDialogDisplayBJ                 = TimerDialogDisplay
    LeaderboardSetStyleBJ                = LeaderboardSetStyle
    LeaderboardGetItemCountBJ            = LeaderboardGetItemCount
    LeaderboardHasPlayerItemBJ           = LeaderboardHasPlayerItem
    DestroyLeaderboardBJ                 = DestroyLeaderboard
    LeaderboardDisplayBJ                 = LeaderboardDisplay
    LeaderboardSortItemsByPlayerBJ       = LeaderboardSortItemsByPlayer
    LeaderboardSortItemsByLabelBJ        = LeaderboardSortItemsByLabel
    PlayerGetLeaderboardBJ               = PlayerGetLeaderboard
    DestroyMultiboardBJ                  = DestroyMultiboard
    SetTextTagPosUnitBJ                  = SetTextTagPosUnit
    SetTextTagSuspendedBJ                = SetTextTagSuspended
    SetTextTagPermanentBJ                = SetTextTagPermanent
    SetTextTagAgeBJ                      = SetTextTagAge
    SetTextTagLifespanBJ                 = SetTextTagLifespan
    SetTextTagFadepointBJ                = SetTextTagFadepoint
    DestroyTextTagBJ                     = DestroyTextTag
    ForceCinematicSubtitlesBJ            = ForceCinematicSubtitles
    DisplayCineFilterBJ                  = DisplayCineFilter
    SaveGameCacheBJ                      = SaveGameCache
    FlushGameCacheBJ                     = FlushGameCache
    SaveGameCheckPointBJ                 = SaveGameCheckpoint
    LoadGameBJ                           = LoadGame
    RenameSaveDirectoryBJ                = RenameSaveDirectory
    RemoveSaveDirectoryBJ                = RemoveSaveDirectory
    CopySaveGameBJ                       = CopySaveGame
    IssueTargetOrderBJ                   = IssueTargetOrder
    IssueTargetDestructableOrder         = IssueTargetOrder -- This was just to type casting
    IssueTargetItemOrder                 = IssueTargetOrder -- This was just to type casting
    IssueImmediateOrderBJ                = IssueImmediateOrder
    GroupTargetOrderBJ                   = GroupTargetOrder
    GroupImmediateOrderBJ                = GroupImmediateOrder
    GroupTargetDestructableOrder         = GroupTargetOrder       -- This was just to type casting
    GroupTargetItemOrder                 = GroupTargetOrder       -- This was just to type casting
    GetDyingDestructable                 = GetTriggerDestructable -- I think they just wanted a better name
    GetAbilityName                       = GetObjectName          -- I think they just wanted a better name
end
if Debug then Debug.endFile() end
