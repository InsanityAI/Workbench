if Debug then Debug.beginFile "LuaInfusedGUI" end
--[[
    Lua-Infused GUI with automatic memory leak resolution: Modernizing the experience for a better future for users of the Trigger Editor.

    Credits:
        Bribe, Tasyen, Dr Super Good, HerlySQR, Antares, Marcielos, InsanityAI

    Installation:
        1. Get the following scripts at the top of your trigger editor in following order:
        - DebugUtils (Optional)
        - IngameConsole (Optional)
        - Total Initialization
        - LuaInfusedGUI
        - everything else
        2. Copy the "Unit Remove Event (LIGUI)" (Aurm) Ability from object editor into your map
        - or create your own by basing it off of footman's Defend ability, just modify the _REMOVE_ABIL constant below

    Transforming rects, locations, groups, forces and BJ hashtable wrappers into Lua tables, which are automatically garbage collected.

    Provides RegisterAnyPlayerUnitEvent to cut down on handle count and simplify syntax for Lua users while benefitting GUI.

    Provides GUI.enumUnitsInRect/InRange/Selected/etc. which replaces the first parameter with a function (which takes a unit), for immediate action without needing a separate group variable.

    Provides GUI.loopArray for safe iteration over a __jarray

    Update: XX xxx 2026 by InsanityAI
    Changes:
        - Refactored entire script
        - Overriden Events and Trigger API to use native triggers as events and fake triggers in place of actual triggers
        - TriggerExecute/TriggerEvaluate will now be able to read event responses from the parent trigger
        - Overriden Timer API to use TimerQueue instead
        - DestroyTimer now no longer does anything
        - TriggerRegisterTimerEvent and TriggerRegisterTimerExpireEvent now use FakeTimers (based on TimerQueue) -- pending change
        - CreateTimerDialog and DestroyTimerDialog now accept FakeTimers instead
        - TimerDialogSetRealTimeRemaining and TimerDialogSetSpeed modified to reflect actual Game behavior with FakeTimers
        - Removed GetForceOfPlayer override as those forces were never immutable to begin with

    Update: 24 May 2026 by InsanityAI & Marcielos
    Changes:
        - Groups now auto-remove units that were removed from the game
        - Added GUI.RegisterUnitRemovedEventListener and GUI.DeregisterUnitRemovedEventListener
        - Added GUI.forForce and fixed Force and Group being able to remove units/players within their respective loops

    Update: 30 Mar 2026 by Macielos
    Changes:
        - Removed overrides for UnitRemoveBuffBJ, TimerDialogDisplayBJ, LeaderboardDisplayBJ as they do not have identical argument order with their corresponding native

    Update: 16 Mar 2026 by InsanityAI
    Changes:
        - Fixed asserts early exiting functions in case _THROW_ERROR_ON_INVALID_ARG is set to true and the arg condition is valid

    Update: 15 Mar 2026 by InsanityAI
    Changes:
        - Added _THROW_ERROR_ON_INVALID_ARG & _PRINT_WARNING_ON_INVALID_ARG flags that modify how assert works within this system
        - Location and Rect overrides now return non-nil values even if error is disabled but no valid argument was provided

    Update: 01 Mar 2026 by Marcielos & InsanityAI
    Changes:
        - Fixed GroupClear, GroupAddUnit, GroupAddGroup and GroupRemoveGroup overrides
        - Fixed Hashtable API where argument order was wrong
        - Overridden CreateMinimapIconAtLoc and ExecuteFunc

    Update: 02 Feb 2026 by Insanity_AI
    Changes:
        - FakedType property is now a string
        - replaced _G with _ENV for a (negligible) speed boost
        - additional asserts for hashtable API
        - Hashtable API now replaces the natives instead of BJs
        - GroupRemoveUnit now no longer breaks the FakeGroup (thanks Antares & Macielos)
        - fixed SetHeroStat
        - added some String & Math API overrides (check the bottom of the script for the list)
        - modified GroupXOrder overrides to use group natives in order to retain speed and formation of units when ordered as a group (thanks Macielos)
        - swapped order of overrides: group <-> location, so that group overrides happen first

    Update: 30 Sep 2025 by Insanity_AI
    Changes:
        - asserts on arguments so DebugUtils can more effectively tell you what's wrong
        - StringHashBJ and GetHandleIdBJ returns 0 if the argument is falsy, otherwise returns the argument itself
        - fixed Hashtable API overrides to support niche Hashtable mechanic of being able to store integer, real, string, boolean and a handle simultaneously on same key pair
        - explicit boolean return for following natives: IsUnitInGroup, IsUnitGroupEmptyBJ, BlzForceHasPlayer, IsPlayerInForce, IsUnitInForce
        - GroupPickRandomUnit will no longer return 0 if group is empty
        - swapped FlushChildHashtableBJ arguments to match the Blizzard.j signature
        - type override to return 'userdata' for FakeLocation, FakeRect, FakeGroup, FakeForce and FakeHashtable
        - added Debug.beginFile/endFile
        - added EmmyLua annotations
        - stored the 4 timers defined in Lua root by Blizzard.j so that their references never get lost and the objects never get collected by GC which ultimately causes desyncs
        - WC3 Native Math API replaced with Lua's math API
        - SubStringBJ replaced with string.sub

    Requires:
        https://www.hiveworkshop.com/threads/total-initialization.317099/page-2#post-3641920

    Uses optionally:
        https://github.com/BribeFromTheHive/Lua-Core/blob/main/Global_Variable_Remapper.lua
        https://www.hiveworkshop.com/threads/syncedtable.353715/
        https://www.hiveworkshop.com/threads/timerqueue-stopwatch.353718/
--]]
OnInit.root("LIGUI", function(require)
    --Configurables
    local _THROW_ERROR_ON_INVALID_ARG    = true           -- set to true if you want LIGUI to throw errors when incorrect arguments are sent to overriden functions
    local _PRINT_WARNING_ON_INVALID_ARG  = true           -- set to true if you want warnings by LIGUI when incorrect arguments are sent to overriden functions
    local _USE_GLOBAL_REMAP              = false          -- set to true if you want GUI to have extended functionality such as "udg_HashTableArray" (which gives GUI an infinite supply of shared hashtables)
    local _REMOVE_ABIL                   = FourCC('Aurm') -- a copy of Defend ability that is used to detect when exactly does a unit get removed.

    -- Experimental features
    local _RESUME_TIMER_RESTORE_PERIODIC = true -- set to true if _USE_TIMERQUEUE is true and you wish to fix resumed repeating timers staying repeating instead of becoming one-shot

    --Define common variables to be utilized throughout the script.
    GUI                                  = {
        DEBUG_MODE = true,
        log = nil ---@type 'debug'|'warning'|nil
    }
    local assert                         = assert
    -- Used to check if function should exit early due to invalid arguments, instead of executing its internal logic
    local check                          = (function() ---@type fun(condition:boolean, msg: string): shouldEarlyExit: boolean
        if _THROW_ERROR_ON_INVALID_ARG then
            return function(condition, msg)
                return not assert(condition, msg)
            end
        elseif _PRINT_WARNING_ON_INVALID_ARG then
            return function(condition, msg)
                if not condition then
                    if Debug then
                        Debug.errorHandler("LIGUI: " .. msg, 3)
                    else
                        print("|cFFFF0000LIGUI: " .. msg)
                    end
                end
                return not condition
            end
        else
            return function(condition)
                return not condition
            end
        end
    end)()

    ---@param ... unknown
    local function debug(...)
        if GUI.log == 'debug' then print("|cFF00FFFFDebug:|r", ...) end
    end

    local function debugWithStackTrace(...)
        if GUI.log == 'debug' then
            print("|cFF00FFFFDebug:|r", ...)
            print("|cFF00FFFFTrace:|r", Debug.traceback(1))
        end
    end

    OnInit.root("LIGUI_FakeType", function(require)
        ---@class FakedType
        ---@field __faketype string

        local oldType = type -- old native `type` API
        --[[ Type extender - if object being checked is a table, check if it's one of the replacements for userdata --]]
        ---@param obj unknown
        ---@return string typeName
        function type(obj)
            local thisType = oldType(obj)
            if thisType == 'table' and obj.__faketype and oldType(obj.__faketype) == 'string' then
                return obj --[[@as FakedType]].__faketype
            end
            return thisType
        end

        GUI.type = type
        GUI.oldType = oldType

        ---@class LIGUI_FakeTypeAPI
        local fakeTypeAPI = {
            type = type
        }
        return fakeTypeAPI
    end)
    OnInit.root("LIGUI_ThreadData", function(require)
        -- Required in order to access cached event responses
        -- Note: This relies on __index and __newindex chain instead of threads as keys to lookup data
        local threadData = setmetatable({}, { __mode = 'k' }) ---@type table<thread, table<string, unknown>> -- map of threads to tbl keys for threadData
        local threadDataMt = { __mode = 'k' }
        ---@param currentThread thread
        ---@param parentThread thread?
        ---@return table<string, unknown>
        local function setupThreadData(currentThread, parentThread)
            local tbl = {}
            if parentThread then
                local parentKey = threadData[parentThread]
                setmetatable(tbl, {
                    __index = parentKey,
                    __newindex = parentKey,
                    __mode = 'k'
                }) -- create new one as this is the first descendant thread
            else
                setmetatable(tbl, threadDataMt)
            end
            threadData[currentThread] = tbl
            return tbl
        end

        ---@param thread thread
        ---@return table<string,unknown>
        local function getThreadData(thread)
            return threadData[thread]
        end

        ---@param thread thread
        local function clearThreadData(thread)
            threadData[thread] = nil
        end

        if GUI.DEBUG_MODE then
            local nonDebugSetupThreadData = setupThreadData
            local nonDebugClearThreadData = clearThreadData

            ---@param currentThread thread
            ---@param parentThread thread
            ---@return table<string, unknown>
            setupThreadData = function(currentThread, parentThread)
                local threadData = nonDebugSetupThreadData(currentThread, parentThread)
                local mt = getmetatable(threadData)
                -- note, might report wrong threads considering they can get recycled, but only in case of waits
                ---@param tbl table<string, unknown>
                mt.__tostring = function(tbl)
                    if mt.__index ~= nil then
                        return "ThreadData for " ..
                            tostring(currentThread) ..
                            " with " .. tostring(#tbl) .. " entires and parent:|n" .. tostring(mt.__index)
                    else
                        return "ThreadData for " .. tostring(currentThread) .. " with " .. tostring(#tbl) .. " entries."
                    end
                end
                debug("Created" .. tostring(threadData))
                return threadData
            end

            clearThreadData = function(thread)
                debug("Unbinding data for", thread)
                nonDebugClearThreadData(thread)
            end
        end

        ---@class LIGUI_ThreadDataAPI
        local threadDataAPI = {
            setupThreadData = setupThreadData,
            getThreadData = getThreadData,
            clearThreadData = clearThreadData
        }
        return threadDataAPI
    end)
    OnInit.root("LIGUI_Coroutines", function(require)
        local threadDataAPI = require "LIGUI_ThreadData" --[[@as LIGUI_ThreadDataAPI]]
        ---@param threads thread[]
        ---@return boolean
        local function threadsAllDone(threads)
            for _, thread in ipairs(threads) do
                if coroutine.status(thread) ~= 'dead' then
                    return false
                end
            end
            return true
        end
        if GUI.DEBUG_MODE then
            threadsAllDone = function(threads)
                local total = 0
                local pending = 0
                for _, thread in ipairs(threads) do
                    total = total + 1
                    if coroutine.status(thread) ~= 'dead' then
                        pending = pending + 1
                    end
                end
                debug(total - pending, "out of", total, "threads done.")
                return pending == 0
            end
        end

        -- Coroutine recycler + Override coroutine.create to automatically setup threadData entry to carry over event responses

        --- some optimizations probably could be done about this
        local function pack(args, ...)
            local argN = select('#', ...)
            if argN < args.n then
                for i = argN + 1, args.n do
                    args[i] = nil
                end
            end

            args.n = argN
            for i = 1, argN do
                args[i] = select(i, ...)
            end
        end

        local unpack = table.unpack

        local coroutine = coroutine
        local threadPool = { n = 0 } ---@type thread[]|{n: integer}
        local threadJobMap = setmetatable({}, { __mode = 'k' }) ---@type table<thread, fun(...):...>
        local threadDead = setmetatable({}, { __mode = 'k' }) ---@type table<thread, true>
        local args = { n = 0 } -- One table to pass all the data, ALL OF IT

        local function coroutineCallback(...)
            local thread = coroutine.running()
            pack(args, ...) -- only for first time coroutine.resume call since native thread is created
            while true do
                -- run job function
                pack(args, pcall(threadJobMap[thread], unpack(args)))

                -- mark coroutine as available
                threadPool.n = threadPool.n + 1
                threadPool[threadPool.n] = thread
                threadJobMap[thread] = nil
                threadDead[thread] = true

                -- final value return and next coroutine resume call (new job function)
                pack(args, coroutine.yield(unpack(args)))
            end
        end

        ---@param whichFunc fun(...):...
        ---@return thread
        local function getCoroutine(whichFunc)
            local thread
            if threadPool.n > 0 then
                thread = threadPool[threadPool.n]
                threadPool[threadPool.n] = nil
                threadPool.n = threadPool.n - 1
            else
                thread = coroutine.create(coroutineCallback)
            end
            threadJobMap[thread] = whichFunc
            threadDead[thread] = nil
            return thread
        end

        ---@param status boolean
        ---@param ... unknown
        ---@return ...
        local function processWrapResult(status, ...)
            if status then
                return ...
            else
                error(..., nil)
            end
        end

        local setupThreadData = threadDataAPI.setupThreadData
        local clearThreadData = threadDataAPI.clearThreadData

        _ENV.coroutine = {
            ---@param whichFunc fun(...):...
            ---@return fun(...):...
            wrap = function(whichFunc)
                local thread = getCoroutine(whichFunc)
                return function(...)
                    return processWrapResult(_ENV.coroutine.resume(thread, ...))
                end
            end,

            ---@param co thread
            ---@return 'running'|'suspended'|'normal'|'dead'
            status = function(co)
                return (threadDead[co] and 'dead') or coroutine.status(co)
            end,

            ---@param co thread
            ---@param ... any
            ---@return boolean success
            ---@return ...
            resume = function(co, ...)
                if threadDead[co] then return false, 'cannot resume dead coroutine' end
                coroutine.resume(co, ...)
                if coroutine.status(co) == 'dead' then
                    clearThreadData(co)
                end
                return unpack(args) -- all data from resume should be in args anyways
            end,

            yield = coroutine.yield,
            running = coroutine.running,
            isyieldable = coroutine.isyieldable,
            ---@param whichFunc fun(...):...
            ---@return thread
            create = function(whichFunc)
                local thread = getCoroutine(whichFunc)
                setupThreadData(thread, coroutine.running())
                return thread
            end
        }
        if GUI.DEBUG_MODE then
            local nonDebugCoroutineResume = _ENV.coroutine.resume
            _ENV.coroutine.resume = function(co, ...)
                debug("Thread", co, "resuming with args:", ...)
                nonDebugCoroutineResume(co, ...)
                debug("Thread", co, "yielding " .. table.tostring(args))
                return unpack(args)
            end
        end

        ---@class LIGUI_CoroutineAPI
        local LIGUI_CoroutineAPI = {
            threadsAllDone = threadsAllDone
        }
        return LIGUI_CoroutineAPI
    end)
    OnInit.root("LIGUI_MiscellaneousFixes", function(require)
        -- Blizzard forgot to add this, but still enabled it for GUI. Therefore, I've extracted and simplified the code from DebugIdInteger2IdString
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

        -- local oldExecuteFunc = ExecuteFunc
        -- ExecuteFunc native can be useful to create a blizzard thread, but why'd you want that?
        ---@param funcName string
        function ExecuteFunc(funcName)
            local func = _ENV[funcName]
            if func == nil then
                check(false, 'Function by the name ' .. funcName .. ' is not found!')
            else
                -- oldExecuteFunc(funcName)
                func()
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

            --have to do a wide search for all arrays in the variable editor. The WarCraft 3 _ENV table is HUGE,
            --and without editing the war3map.lua file manually, it is not possible to rewrite it in advance.
            for k, v in pairs(_ENV) do
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
    end)
    OnInit.root("LIGUI_Hashtables", function(require)
        --[[ GUI hashtable converter by Tasyen and Bribe

        Converts GUI hashtables API into Lua Tables, overwrites StringHashBJ and GetHandleIdBJ to permit
        typecasting, bypasses the 256 hashtable limit by avoiding hashtables, provides the variable
        "HashTableArray", which automatically creates hashtables for you as needed (so you don't have to
        initialize them each time). ]]
        require "LIGUI_FakeType"
        require "LIGUI_MiscellaneousFixes" -- _jarray fix

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

        ---@param whichHashTable FakeHashtable
        ---@param parentKey unknown
        ---@param childKey unknown
        ---@return boolean shouldEarlyExit
        local function checkHashtableArgs(whichHashTable, parentKey, childKey)
            return check(whichHashTable ~= nil, 'whichHashTable cannot be nil') or
                check(parentKey ~= nil, 'parentKey cannot be nil') or
                check(childKey ~= nil, 'childKey cannot be nil')
        end

        ---@param value unknown?
        ---@param childKey unknown
        ---@param parentKey unknown
        ---@param whichHashTable FakeHashtable
        ---@param type 'boolean'|'integer'|'real'|'string'|'handle'
        local function saveInto(whichHashTable, type, parentKey, childKey, value)
            if checkHashtableArgs(whichHashTable, parentKey, childKey) then return end
            load(whichHashTable, type, parentKey)[childKey] = value
        end

        ---@generic T
        ---@param type 'boolean'|'integer'|'real'|'string'|'handle'
        ---@return fun(whichHashTable: FakeHashtable, parentKey: unknown, childKey: unknown, value: T)
        local function createSaveIntoTyped(type)
            check(type ~= nil, 'type cannot be nil')
            ---@generic T
            ---@param whichHashTable FakeHashtable
            ---@param parentKey unknown
            ---@param childKey unknown
            ---@param value T
            return function(whichHashTable, parentKey, childKey, value)
                return saveInto(whichHashTable, type, parentKey, childKey, value)
            end
        end

        ---@param whichHashTable FakeHashtable
        ---@param type 'boolean'|'integer'|'real'|'string'|'handle'
        ---@param parentKey unknown
        ---@param childKey unknown
        ---@param default unknown|nil
        ---@return unknown|nil
        local function loadFrom(whichHashTable, type, parentKey, childKey, default)
            if checkHashtableArgs(whichHashTable, parentKey, childKey) then return default end
            local val = load(whichHashTable, type, parentKey)[childKey]
            return val ~= nil and val or default
        end

        ---@param type 'boolean'|'integer'|'real'|'string'|'handle'|nil
        ---@param default unknown
        ---@return fun(whichHashTable: FakeHashtable, parentKey: unknown, childKey: unknown): unknown|nil
        local function createDefault(type, default)
            return function(whichHashTable, parentKey, childKey)
                return loadFrom(whichHashTable, type or 'handle', parentKey, childKey, default)
            end
        end

        if _USE_GLOBAL_REMAP then
            OnInit.global(function(require)
                local remap = require "GlobalRemapArray"
                local hashes = __jarray()
                remap("udg_HashTableArray", function(index)
                    return load(hashes, 'handle', index)
                end)
            end)
        end

        ---@class LIGUI_HashtableAPI
        local hashtableAPI = {
            createDefault = createDefault,
            checkHashtableArgs = checkHashtableArgs,
            load = load,
            loadFrom = loadFrom,
            createSaveIntoTyped = createSaveIntoTyped,
            saveInto = saveInto
        }
        return hashtableAPI
    end)
    OnInit.root("LIGUI_Boolexprs", function(require)
        local threadDataAPI = require "LIGUI_ThreadData" --[[@as LIGUI_ThreadDataAPI]]
        local setupThreadData = threadDataAPI.setupThreadData
        local clearThreadData = threadDataAPI.clearThreadData

        -- ForGroup/ForForce will use regular loops
        local filterUpvalue = nil ---@type fun(): boolean
        local nativeFilter ---@type filterfunc

        local nativeFilterConstructor = Filter
        OnInit.main("LIGUI_NativeFilter", function(require)
            nativeFilter = nativeFilterConstructor(function()
                -- note: this runs in a "blizzard" thread and cannot be paused/yielded, so we're safe
                return filterUpvalue()
            end) --[[@as filterfunc]]
        end)

        ---@param filter fun(): boolean
        ---@param enumNative fun(): unknown
        ---@param enumName string
        ---@return filterfunc
        local function toNativeFilter(filter, enumNative, enumName)
            local parentThread = coroutine.running()
            filterUpvalue = function()
                local thisThread = coroutine.running()
                local data = setupThreadData(thisThread, parentThread)
                rawset(data, enumName, enumNative())
                local result = filter()
                clearThreadData(thisThread)
                return result
            end
            return nativeFilter
        end

        local oldGetFilterUnit = GetFilterUnit
        local function wrapUnitFilter(filter)
            if not filter then return nil end
            return toNativeFilter(filter --[[@as fun(): boolean]], oldGetFilterUnit, "GetFilterUnit")
        end

        local oldGetFilterPlayer = GetFilterPlayer
        local function wrapPlayerFilter(filter)
            if not filter then return nil end
            return toNativeFilter(filter --[[@as fun(): boolean]], oldGetFilterPlayer, "GetFilterPlayer")
        end

        ---@class LIGUI_BoolexprAPI
        local boolexprAPI = {
            wrapUnitFilter = wrapUnitFilter,
            wrapPlayerFilter = wrapPlayerFilter,
            toNativeFilter = toNativeFilter
        }
        return boolexprAPI
    end)
    OnInit.root("LIGUI_Groups", function(require)
        local weakKeyMt = { __mode = 'k' }
        local groupDB = {
            unitsInGroups = {} --[[@as table<unit, table<FakeGroup, true>>]],
            groups = setmetatable({}, weakKeyMt) --[[@as table<FakeGroup, true> ]],
        }

        ---@param group FakeGroup
        ---@param unit unit
        local function groupDBRegisterUnitInGroup(group, unit)
            local relevantGroups = groupDB.unitsInGroups[unit]
            if not relevantGroups then
                relevantGroups = setmetatable({}, weakKeyMt) --[[@as table<FakeGroup, true>]]
                groupDB.unitsInGroups[unit] = relevantGroups
            end
            relevantGroups[group] = true
            groupDB.groups[group] = true

            local pos = #group + 1
            group.indexOf[unit] = pos
            group[pos] = unit
        end

        ---@param group FakeGroup
        ---@param unit unit
        local function groupDBDeregisterUnitFromGroup(group, unit)
            local pos = group.indexOf[unit]
            if pos == nil then return end
            groupDB.unitsInGroups[unit][group] = nil

            -- remove unit from group
            local size = #group
            if pos ~= size then
                local replUnit = group[size]
                group[pos] = replUnit
                group.indexOf[replUnit] = pos
            end
            group[size] = nil
            group.indexOf[unit] = nil
        end

        ---@param unit unit
        local function groupDBDeregisterUnit(unit)
            local relevantGroups = groupDB.unitsInGroups[unit]
            if not relevantGroups then return end
            for group, _ in pairs(relevantGroups) do
                groupDBDeregisterUnitFromGroup(group, unit)
                if #group == 0 then
                    groupDB.groups[group] = nil
                end
            end
            groupDB.unitsInGroups[unit] = nil
        end

        ---@param group FakeGroup
        local function groupDBDeregisterGroup(group)
            if not groupDB.groups[group] then return end
            for i = #group, 1, -1 do
                groupDBDeregisterUnitFromGroup(group, group[i])
            end

            groupDB.groups[group] = nil
        end

        local function groupDBDeregisterGroupSimple(group)
            groupDB.groups[group] = nil
        end

        ---@class LIGUI_GroupsAPI
        local groupsAPI = {
            groupDBRegisterUnitInGroup = groupDBRegisterUnitInGroup,
            groupDBDeregisterUnitFromGroup = groupDBDeregisterUnitFromGroup,
            groupDBDeregisterUnit = groupDBDeregisterUnit,
            groupDBDeregisterGroup = groupDBDeregisterGroup,
            groupDBDeregisterGroupSimple = groupDBDeregisterGroupSimple
        }
        return groupsAPI
    end)
    OnInit.root("LIGUI_RandomPool", function(require)
        require "LIGUI_FakeType"

        local nilRef = {}

        -- A simplified version of WeightedTable
        ---@generic T
        ---@class LIGUI_RandomPool<T>
        ---@field private allowNil boolean
        ---@field private compiled boolean
        ---@field private internalWeights number[]
        ---@field public weights number[]
        ---@field public [integer] T -- array of objects
        ---@field public [T] integer -- object index lookup
        ---@field public size integer
        local RandomPool = {}
        RandomPool.__index = RandomPool

        ---@param allowNil true?
        ---@return LIGUI_RandomPool
        function RandomPool.create(allowNil)
            return setmetatable({
                allowNil = allowNil,
                weights = {},
                size = 0,
                compiled = true
            }, RandomPool)
        end

        ---@param obj T
        ---@param weight number
        function RandomPool:addObject(obj, weight)
            if check(weight ~= nil, "Weight must not be nil") then return end
            if check(type(weight) == 'number', "Weight must be a number!") then return end 
            if obj == nil then
                if check(self.allowNil, "RandomPool does not accept nil object") then return end
                obj = nilRef
            end
            if self.allowNil and obj == nil then obj = nilRef end
            local index = self.objectIndices[obj]
            if not index then
                table.insert(self, obj)
                table.insert(self.weights, weight)
                self[obj] = self.size
                self.size = self.size + 1
            else
                self.weights[index] = weight
            end
            self.compiled = false
        end

        ---@param obj T
        function RandomPool:removeObject(obj)
            if obj == nil then
                if check(self.allowNil, "RandomPool does not accept nil object") then return end
                obj = nilRef
            end
            if self.allowNil and obj == nil then obj = nilRef end
            local index = self.objectIndices[obj]
            if not index then return end
            table.remove(self.weights, index)
            table.remove(self, index)

            self.compiled = false
            self.size = self.size - 1
        end

        ---@generic T
        ---@return T?
        function RandomPool:getRandomObj()
            if not self.compiled then
                self.internalWeights = {}
                local weightSum = 0
                for _, weight in ipairs(self.weights) do
                    weightSum = weightSum + weight
                end
                local currentCumulativeNormalizedWeight = 0
                for index, weight in ipairs(self.weights) do
                    currentCumulativeNormalizedWeight = currentCumulativeNormalizedWeight + weight / weightSum
                    self.internalWeights[index] = currentCumulativeNormalizedWeight
                end
            end

            local rng = math.random()
            for index, weightedValue in ipairs(self.internalWeights) do
                if rng <= weightedValue then
                    local obj = self[index]
                    if obj == nilRef then obj = nil end
                    return obj --[[@as unknown]]
                end
            end
        end

        GUI.RandomPool = RandomPool

        return RandomPool
    end)
    OnInit.root("LIGUI_EventRegistry", function(require)
        require "LIGUI_FakeType"
        local threadDataAPI = require "LIGUI_ThreadData" --[[@as LIGUI_ThreadDataAPI]]
        local setupThreadData = threadDataAPI.setupThreadData
        local getThreadData = threadDataAPI.getThreadData

        ---@class EventRegistry
        EventRegistry = {}
        GUI.EventRegistry = EventRegistry
        local NULL = {}

        -- No point writing generics since this could in theory be variadic param and variadic result, which doesn't work with generic
        ---@class Cache
        ---@field getterFunc function
        ---@field argN integer
        ---@field keyArgs integer[]?
        ---@field cachedData table
        local Cache = {}
        Cache.__index = Cache

        local weakTable = { __mode = "kv" }

        -- Create a cache with specified getter, but also indices of which arguments of the getterFunc are supposed to be used as keys (order of arguments also matters)
        ---@param getterFunc function
        ---@param getterFuncArgN integer amount of arguments getter func accepts
        ---@param ... integer keyArgs
        ---@return Cache
        function Cache.create(getterFunc, getterFuncArgN, ...)
            local keyArgs = { ... } ---@type integer[]?
            if #keyArgs == 0 then
                keyArgs = nil
            end
            return setmetatable({
                getterFunc = getterFunc,
                argN = getterFuncArgN,
                keyArgs = keyArgs,
                cachedData = setmetatable({}, weakTable)
            }, Cache)
        end

        ---@param self Cache
        ---@param ... unknown key(s)
        ---@return table finalTable, unknown finalKey
        local function fetchFromCache(self, ...)
            local argv = { ... }

            local currentTable = self.cachedData
            local finalKey
            if self.keyArgs == nil then
                for i = 1, self.argN - 1 do
                    local arg = argv[i] or NULL
                    local nextTable = currentTable[arg]
                    if nextTable == nil then
                        nextTable = setmetatable({}, weakTable)
                        currentTable[arg] = nextTable
                    end
                    currentTable = nextTable
                end
                finalKey = argv[self.argN] or NULL
            else
                local argvSize = #self.keyArgs
                for i = 1, argvSize - 1 do
                    local arg = argv[self.keyArgs[i]] or NULL
                    local nextTable = currentTable[arg]
                    if nextTable == nil then
                        nextTable = setmetatable({}, weakTable)
                        currentTable[arg] = nextTable
                    end
                    currentTable = nextTable
                end
                finalKey = argv[self.keyArgs[argvSize]] or NULL
            end

            return currentTable, finalKey
        end

        -- Fetch cached value or get and cache from getterFunc
        ---@param ... unknown key(s)
        ---@return unknown value(s)
        function Cache:get(...)
            local finalTable, finalKey = fetchFromCache(self, ...)
            local val = finalTable[finalKey]
            if val == nil then
                val = self.getterFunc(...)
                finalTable[finalKey] = val
            end
            return val
        end

        local oldCreateTrigger = CreateTrigger
        local oldEnableTrigger = EnableTrigger
        local oldDisableTrigger = DisableTrigger
        local oldTriggerAddAction = TriggerAddAction
        local oldGetTriggeringTrigger = GetTriggeringTrigger

        -- Events
        do
            ---@class AbstractTriggerEvent: FakedType, event
            ---@field package listeners table<FakeTrigger, true>
            ---@field package listenerAmount integer
            ---@field notifyListeners fun(self: AbstractTriggerEvent)
            ---@field addListener fun(self: AbstractTriggerEvent, listener: FakeTrigger)
            ---@field removeListener fun(self: AbstractTriggerEvent, listener: FakeTrigger)

            ---@class FakeTriggerEvent: AbstractTriggerEvent
            ---@field package actualTrigger trigger
            FakeTriggerEvent = {}
            FakeTriggerEvent.__index = FakeTriggerEvent

            function FakeTriggerEvent:notifyListeners()
                debug("FakeTriggerEvent:notifyListeners", self)
                if self.listenerAmount == 0 then
                    debug("No listeners in", self)
                    debug("Listeners", table.tostring(self.listeners))
                    oldDisableTrigger(self.actualTrigger)
                    return
                end
                local thread = coroutine.running()
                for listener in pairs(self.listeners) do
                    if listener:evaluate() then
                        local newThread = coroutine.create(listener.execute)
                        local data = setupThreadData(newThread, thread)
                        -- run in a coroutine to avoid TSA/PolledWait congesting every listener/trigger
                        debug("Executing trigger", listener)
                        coroutine.resume(newThread, listener)
                    end
                end
            end

            local function createFakeTriggerEvent()
                local o = setmetatable({
                    __faketype = "userdata",
                    actualTrigger = oldCreateTrigger(),
                    listeners = SyncedTable.create(),
                    listenerAmount = 0
                }, FakeTriggerEvent)
                return o
            end

            ---@param self FakeTriggerEvent
            ---@param listener FakeTrigger
            function FakeTriggerEvent:addListener(listener)
                if not self.listeners[listener] then
                    self.listenerAmount = self.listenerAmount + 1
                end
                self.listeners[listener] = true
                if self.listenerAmount > 0 then
                    oldEnableTrigger(self.actualTrigger)
                end
            end

            ---@param self FakeTriggerEvent
            ---@param listener FakeTrigger
            function FakeTriggerEvent:removeListener(listener)
                if self.listeners[listener] then
                    self.listenerAmount = self.listenerAmount - 1
                end
                self.listeners[listener] = nil
                if self.listenerAmount == 0 then
                    oldDisableTrigger(self.actualTrigger)
                end
            end

            local eventResponseMap = {} ---@type table<string, fun():unknown>

            local useNativeInstead = {
                GetFilterUnit = "GetTriggerUnit",
                GetEnteringUnit = "GetTriggerUnit",
                GetLeavingUnit = "GetTriggerUnit",
                GetDyingUnit = "GetTriggerUnit",
                GetDecayingUnit = "GetTriggerUnit",
                GetDetectedUnit = "GetTriggerUnit",
                GetEventDetectingPlayer = "GetTriggerPlayer",
                GetOrderedUnit = "GetTriggerUnit",
                GetLevelingUnit = "GetTriggerUnit",
                GetLearningUnit = "GetTriggerUnit",
                GetRevivableUnit = "GetTriggerUnit",
                GetRevivingUnit = "GetTriggerUnit",
                GetManipulatingUnit = "GetTriggerUnit",
                GetSpellAbilityUnit = "GetTriggerUnit",
            }

            ---@param event AbstractTriggerEvent
            ---@param eventResponseNames string[]
            local function processEventCallback(event, eventResponseNames)
                debug("Process event callback")
                local thread = coroutine.running()
                local data = setupThreadData(thread)
                data.GetTriggerEventId = event

                for _, name in ipairs(eventResponseNames) do
                    print("Event response", name)
                    if useNativeInstead[name] then
                        getThreadData(thread)[name] = getThreadData(thread)[useNativeInstead[name]]
                    else
                        getThreadData(thread)[name] = eventResponseMap[name]()
                    end
                    print("Event response", name, getThreadData(thread)[name])
                end
                event:notifyListeners()
            end

            ---@param eventRegistrationNative fun(trigger: trigger, ...: unknown)
            ---@param nativeArgCount integer
            ---@param eventResponseNames string[]
            ---@return fun(...): AbstractTriggerEvent
            local function defineEventType(eventRegistrationNative, nativeArgCount, eventResponseNames)
                local abstractTriggerEventCache = Cache.create(createFakeTriggerEvent, nativeArgCount)
                local eventCache = Cache.create(function(...)
                    local trigger = oldCreateTrigger() --[[@as trigger]]
                    eventRegistrationNative(trigger, ...)
                    local event = abstractTriggerEventCache:get(trigger, ...)
                    oldTriggerAddAction(trigger, function()
                        processEventCallback(event, eventResponseNames)
                    end)
                    return event
                end, nativeArgCount - 1)
                return function(...)
                    return eventCache:get(...)
                end
            end

            ---@param eventRegistrationNative fun(trigger: trigger, ...: unknown)
            ---@param nativeArgCount integer
            ---@param eventResponseNames string[]
            ---@param filterEnumGetter string
            ---@return fun(...): AbstractTriggerEvent
            local function defineEventTypeWithFilter(eventRegistrationNative, nativeArgCount, eventResponseNames,
                                                     filterEnumGetter)
                local eventConstructor = defineEventType(eventRegistrationNative, nativeArgCount - 1,
                    table.pack(filterEnumGetter, table.unpack(eventResponseNames)))

                ---@param trigger FakeTrigger
                ---@param ... unknown
                return function(trigger, ...)
                    -- remove filter from args
                    local args = table.pack(...)
                    local filter = args[nativeArgCount] --[[@as nil|fun():boolean]]
                    args[nativeArgCount] = nil

                    if filter then
                        trigger:addCondition(filter)
                    end
                    return eventConstructor(trigger, table.unpack(args))
                end
            end

            ---@param eventRegistrationNative fun(trigger: trigger, ...:unknown)
            ---@param nativeArgCount integer
            ---@param eventTypeResponseMap table<eventid, string[]>
            ---@param commonResponse string?
            ---@---@return fun(...): AbstractTriggerEvent
            local function defineDynamicEventType(eventRegistrationNative, nativeArgCount, eventTypeResponseMap,
                                                  commonResponse)
                local abstractTriggerEventCache = Cache.create(createFakeTriggerEvent, nativeArgCount)
                local eventCache = Cache.create(function(...)
                    local eventResponseNames = table.pack(commonResponse,
                        table.unpack(eventTypeResponseMap[select(nativeArgCount - 1, ...)]))
                    local trigger = oldCreateTrigger() --[[@as trigger]]
                    eventRegistrationNative(trigger, ...)
                    local event = abstractTriggerEventCache:get(trigger, ...)
                    oldTriggerAddAction(trigger, function()
                        processEventCallback(event, eventResponseNames)
                    end)
                    return event
                end, nativeArgCount - 1)
                return function(...)
                    return eventCache:get(...)
                end
            end

            ---@param eventRegistrationNative fun(trigger: trigger, ...: unknown)
            ---@param nativeArgCount integer
            ---@param eventTypeResponseMap table<eventid, string[]>
            ---@param filterEnumGetter string
            ---@return fun(...): AbstractTriggerEvent
            local function defineDynamicEventTypeWithFilter(eventRegistrationNative, nativeArgCount,
                                                            eventTypeResponseMap, filterEnumGetter)
                local eventConstructor = defineDynamicEventType(eventRegistrationNative, nativeArgCount - 1,
                    eventTypeResponseMap, filterEnumGetter)

                ---@param trigger FakeTrigger
                ---@param ... unknown
                return function(trigger, ...)
                    -- remove filter from args
                    local args = table.pack(...)
                    local filter = args[nativeArgCount] --[[@as nil|fun():boolean]]
                    args[nativeArgCount] = nil

                    if filter then
                        trigger:addCondition(filter)
                    end
                    return eventConstructor(trigger, table.unpack(args))
                end
            end

            -- note: commented out position event responses will call the X/Y natives anyways, because they've been overriden earlier

            local gameEventResponseMap = {
                [EVENT_GAME_VICTORY] = { "GetWinningPlayer" },
                [EVENT_GAME_END_LEVEL] = {},
                [EVENT_GAME_VARIABLE_LIMIT] = { "GetTriggeringVariableName" },
                [EVENT_GAME_STATE_LIMIT] = { "GetEventGameState" },
                [EVENT_GAME_TIMER_EXPIRED] = { "GetExpiredTimer" },
                [EVENT_GAME_ENTER_REGION] = { "GetTriggeringRegion", "GetTriggerUnit", "GetEnteringUnit" },
                [EVENT_GAME_LEAVE_REGION] = { "GetTriggeringRegion", "GetTriggerUnit", "GetLeavingUnit" },
                [EVENT_GAME_TRACKABLE_HIT] = { "GetTriggeringTrackable" },
                [EVENT_GAME_TRACKABLE_TRACK] = { "GetTriggeringTrackable" },
                [EVENT_GAME_SHOW_SKILL] = {},
                [EVENT_GAME_BUILD_SUBMENU] = {},
                [EVENT_GAME_LOADED] = {},
                [EVENT_GAME_TOURNAMENT_FINISH_SOON] = { "GetTournamentFinishSoonTimeRemaining" },
                [EVENT_GAME_TOURNAMENT_FINISH_NOW] = { "GetTournamentFinishNowRule", "GetTournamentFinishNowPlayer" },
                [EVENT_GAME_SAVE] = { "GetSaveBasicFilename" },
                [EVENT_GAME_CUSTOM_UI_FRAME] = { "GetTriggerPlayer", "BlzGetTriggerFrame", "BlzGetTriggerFrameEvent", "BlzGetTriggerFrameValue" }
            }

            local dialogEventResponses = { "GetClickedDialog", "GetClickedButton" }

            local playerEventResponseMap = {
                [EVENT_PLAYER_STATE_LIMIT] = { "GetTriggerPlayer", "GetEventPlayerState" },
                [EVENT_PLAYER_ALLIANCE_CHANGED] = { "GetTriggerPlayer" },
                [EVENT_PLAYER_DEFEAT] = { "GetTriggerPlayer" },
                [EVENT_PLAYER_VICTORY] = { "GetTriggerPlayer" },
                [EVENT_PLAYER_LEAVE] = { "GetTriggerPlayer" },
                [EVENT_PLAYER_CHAT] = { "GetTriggerPlayer", "GetEventPlayerChatString", "GetEventPlayerChatStringMatched" }, --todo: does matched work?
                [EVENT_PLAYER_END_CINEMATIC] = { "GetTriggerPlayer" },
                [EVENT_PLAYER_ARROW_LEFT_DOWN] = { "GetTriggerPlayer" },
                [EVENT_PLAYER_ARROW_LEFT_UP] = { "GetTriggerPlayer" },
                [EVENT_PLAYER_ARROW_RIGHT_DOWN] = { "GetTriggerPlayer" },
                [EVENT_PLAYER_ARROW_RIGHT_UP] = { "GetTriggerPlayer" },
                [EVENT_PLAYER_ARROW_DOWN_DOWN] = { "GetTriggerPlayer" },
                [EVENT_PLAYER_ARROW_DOWN_UP] = { "GetTriggerPlayer" },
                [EVENT_PLAYER_ARROW_UP_DOWN] = { "GetTriggerPlayer" },
                [EVENT_PLAYER_ARROW_UP_UP] = { "GetTriggerPlayer" },
                [EVENT_PLAYER_MOUSE_DOWN] = { "GetTriggerPlayer", "BlzGetTriggerPlayerMouseButton", --[["BlzGetTriggerPlayerMousePosition",]] "BlzGetTriggerPlayerMouseX", "BlzGetTriggerPlayerMouseY" },
                [EVENT_PLAYER_MOUSE_UP] = { "GetTriggerPlayer", "BlzGetTriggerPlayerMouseButton", --[["BlzGetTriggerPlayerMousePosition",]] "BlzGetTriggerPlayerMouseX", "BlzGetTriggerPlayerMouseY" },
                [EVENT_PLAYER_MOUSE_MOVE] = { "GetTriggerPlayer", --[["BlzGetTriggerPlayerMousePosition",]] "BlzGetTriggerPlayerMouseX", "BlzGetTriggerPlayerMouseY" },
                [EVENT_PLAYER_SYNC_DATA] = { "GetTriggerPlayer", "BlzGetTriggerSyncData", "BlzGetTriggerSyncPrefix" },
                [EVENT_PLAYER_KEY] = { "GetTriggerPlayer", "BlzGetTriggerPlayerKey", "BlzGetTriggerPlayerMetaKey", "BlzGetTriggerPlayerIsKeyDown" },
                [EVENT_PLAYER_KEY_DOWN] = { "GetTriggerPlayer", "BlzGetTriggerPlayerKey", "BlzGetTriggerPlayerMetaKey", "BlzGetTriggerPlayerIsKeyDown" },
                [EVENT_PLAYER_KEY_UP] = { "GetTriggerPlayer", "BlzGetTriggerPlayerKey", "BlzGetTriggerPlayerMetaKey", "BlzGetTriggerPlayerIsKeyDown" },
            }

            local playerUnitEventResponseMap = {
                [EVENT_PLAYER_UNIT_ATTACKED] = { "GetTriggerPlayer", "GetTriggerUnit" },
                [EVENT_PLAYER_UNIT_RESCUED] = { "GetTriggerPlayer", "GetTriggerUnit", "GetRescuer" },
                [EVENT_PLAYER_UNIT_DEATH] = { "GetTriggerPlayer", "GetTriggerUnit", "GetDyingUnit", "GetKillingUnit" },
                [EVENT_PLAYER_UNIT_DECAY] = { "GetTriggerPlayer", "GetTriggerUnit", "GetDecayingUnit" },
                [EVENT_PLAYER_UNIT_DETECTED] = { "GetTriggerPlayer", "GetTriggerUnit", "GetDetectedUnit", "GetEventDetectingPlayer" },
                [EVENT_PLAYER_UNIT_HIDDEN] = { "GetTriggerPlayer", "GetTriggerUnit" }, -- what is this event even?
                [EVENT_PLAYER_UNIT_SELECTED] = { "GetTriggerPlayer", "GetTriggerUnit" },
                [EVENT_PLAYER_UNIT_DESELECTED] = { "GetTriggerPlayer", "GetTriggerUnit" },
                [EVENT_PLAYER_UNIT_CONSTRUCT_START] = { "GetTriggerPlayer", "GetTriggerUnit", "GetConstructingStructure" },
                [EVENT_PLAYER_UNIT_CONSTRUCT_CANCEL] = { "GetTriggerPlayer", "GetTriggerUnit", "GetConstructingStructure", "GetCancelledStructure" },
                [EVENT_PLAYER_UNIT_CONSTRUCT_FINISH] = { "GetTriggerPlayer", "GetTriggerUnit", "GetConstructedStructure" },
                [EVENT_PLAYER_UNIT_UPGRADE_START] = { "GetTriggerPlayer", "GetTriggerUnit", "GetConstructingStructure" },  -- todo: is this how these events work?
                [EVENT_PLAYER_UNIT_UPGRADE_CANCEL] = { "GetTriggerPlayer", "GetTriggerUnit", "GetConstructingStructure" }, -- todo: is this how these events work?
                [EVENT_PLAYER_UNIT_UPGRADE_FINISH] = { "GetTriggerPlayer", "GetTriggerUnit", "GetConstructedStructure" },  -- todo: is this how these events work?
                [EVENT_PLAYER_UNIT_TRAIN_START] = { "GetTriggerPlayer", "GetTriggerUnit", "GetTrainedUnitType" },
                [EVENT_PLAYER_UNIT_TRAIN_CANCEL] = { "GetTriggerPlayer", "GetTriggerUnit", "GetTrainedUnitType" },
                [EVENT_PLAYER_UNIT_TRAIN_FINISH] = { "GetTriggerPlayer", "GetTriggerUnit", "GetTrainedUnitType", "GetTrainedUnit" },
                [EVENT_PLAYER_UNIT_RESEARCH_START] = { "GetTriggerPlayer", "GetTriggerUnit", "GetResearched", "GetResearchingUnit" },
                [EVENT_PLAYER_UNIT_RESEARCH_CANCEL] = { "GetTriggerPlayer", "GetTriggerUnit", "GetResearched", "GetResearchingUnit" },
                [EVENT_PLAYER_UNIT_RESEARCH_FINISH] = { "GetTriggerPlayer", "GetTriggerUnit", "GetResearched", "GetResearchingUnit" },
                [EVENT_PLAYER_UNIT_ISSUED_ORDER] = { "GetTriggerPlayer", "GetTriggerUnit", "GetOrderedUnit", "GetIssuedOrderId" },
                [EVENT_PLAYER_UNIT_ISSUED_POINT_ORDER] = { "GetTriggerPlayer", "GetTriggerUnit", "GetOrderedUnit", "GetIssuedOrderId", "GetOrderPointX", "GetOrderPointY", --[["GetOrderPointLoc"]] },
                [EVENT_PLAYER_UNIT_ISSUED_TARGET_ORDER] = { "GetTriggerPlayer", "GetTriggerUnit", "GetOrderedUnit", "GetIssuedOrderId", "GetOrderPointX", "GetOrderPointY", --[["GetOrderPointLoc",]] "GetOrderTarget", "GetOrderTargetDestructable", "GetOrderTargetUnit", "GetOrderTargetItem" }, -- todo: triggerUnit = orderedUnit, orderTarget =  multiple things?
                [EVENT_PLAYER_UNIT_ISSUED_UNIT_ORDER] = { "GetTriggerPlayer", "GetTriggerUnit", "GetOrderedUnit", "GetIssuedOrderId", "GetOrderPointX", "GetOrderPointY", --[["GetOrderPointLoc",]] "GetOrderTarget", "GetOrderTargetDestructable", "GetOrderTargetUnit", "GetOrderTargetItem" },   -- todo: triggerUnit = orderedUnit, orderTarget =  multiple things?
                [EVENT_PLAYER_HERO_LEVEL] = { "GetTriggerPlayer", "GetTriggerUnit", "GetLevelingUnit" },
                [EVENT_PLAYER_HERO_SKILL] = { "GetTriggerPlayer", "GetTriggerUnit", "GetLearnedSkillLevel", "GetLearnedSkill", "GetLearningUnit" },
                [EVENT_PLAYER_HERO_REVIVABLE] = { "GetTriggerPlayer", "GetTriggerUnit", "GetRevivableUnit" },
                [EVENT_PLAYER_HERO_REVIVE_START] = { "GetTriggerPlayer", "GetTriggerUnit", "GetRevivingUnit" },
                [EVENT_PLAYER_HERO_REVIVE_CANCEL] = { "GetTriggerPlayer", "GetTriggerUnit", "GetRevivingUnit" },
                [EVENT_PLAYER_HERO_REVIVE_FINISH] = { "GetTriggerPlayer", "GetTriggerUnit", "GetRevivingUnit" },
                [EVENT_PLAYER_UNIT_SUMMON] = { "GetTriggerPlayer", "GetTriggerUnit", "GetSummonedUnit", "GetSummoningUnit" }, -- todo: triggerUnit == ?
                [EVENT_PLAYER_UNIT_DROP_ITEM] = { "GetTriggerPlayer", "GetTriggerUnit", "GetManipulatingUnit", "GetManipulatedItem" },
                [EVENT_PLAYER_UNIT_PICKUP_ITEM] = { "GetTriggerPlayer", "GetTriggerUnit", "GetManipulatingUnit", "GetManipulatedItem", "BlzGetAbsorbingItem", "BlzGetManipulatedItemWasAbsorbed" },
                [EVENT_PLAYER_UNIT_USE_ITEM] = { "GetTriggerPlayer", "GetTriggerUnit", "GetManipulatingUnit", "GetManipulatedItem" },
                [EVENT_PLAYER_UNIT_LOADED] = { "GetTriggerPlayer", "GetTriggerUnit", "GetLoadedUnit", "GetTransportUnit" },                                                                                                                                     -- todo: triggerUnit == ??
                [EVENT_PLAYER_UNIT_DAMAGED] = { "GetTriggerPlayer", "GetTriggerUnit", "GetEventDamage", "GetEventDamageSource", "BlzGetEventDamageTarget", "BlzGetEventDamageType", "BlzGetEventAttackType", "BlzGetEventWeaponType", "BlzGetEventIsAttack" },  -- todo: triggerUnit == ??
                [EVENT_PLAYER_UNIT_DAMAGING] = { "GetTriggerPlayer", "GetTriggerUnit", "GetEventDamage", "GetEventDamageSource", "BlzGetEventDamageTarget", "BlzGetEventDamageType", "BlzGetEventAttackType", "BlzGetEventWeaponType", "BlzGetEventIsAttack" }, -- todo: triggerUnit == ??
                [EVENT_PLAYER_UNIT_SELL] = { "GetTriggerPlayer", "GetTriggerUnit", "GetBuyingUnit", "GetSoldUnit", "GetSellingUnit" },                                                                                                                          -- todo: triggerUnit == ??
                [EVENT_PLAYER_UNIT_CHANGE_OWNER] = { "GetTriggerPlayer", "GetTriggerUnit", "GetChangingUnit", "GetChangingUnitPrevOwner" },
                [EVENT_PLAYER_UNIT_SELL_ITEM] = { "GetTriggerPlayer", "GetTriggerUnit", "GetBuyingUnit", "GetSoldItem", "GetSellingUnit", "GetManipulatedItem", "GetManipulatingUnit" },                                                                        -- todo: manipulatingUnit? == triggerUnit, which shop?
                [EVENT_PLAYER_UNIT_SPELL_CHANNEL] = { "GetTriggerPlayer", "GetTriggerUnit", "GetSpellAbility", "GetSpellAbilityId", "GetSpellAbilityUnit", "GetSpellTargetX", "GetSpellTargetY", --[[GetSpellTargetLoc,]] "GetSpellTargetUnit", "GetSpellTargetDestructable", "GetSpellTargetItem" },
                [EVENT_PLAYER_UNIT_SPELL_CAST] = { "GetTriggerPlayer", "GetTriggerUnit", "GetSpellAbility", "GetSpellAbilityId", "GetSpellAbilityUnit", "GetSpellTargetX", "GetSpellTargetY", --[[GetSpellTargetLoc,]] "GetSpellTargetUnit", "GetSpellTargetDestructable", "GetSpellTargetItem" },
                [EVENT_PLAYER_UNIT_SPELL_EFFECT] = { "GetTriggerPlayer", "GetTriggerUnit", "GetSpellAbility", "GetSpellAbilityId", "GetSpellAbilityUnit", "GetSpellTargetX", "GetSpellTargetY", --[[GetSpellTargetLoc,]] "GetSpellTargetUnit", "GetSpellTargetDestructable", "GetSpellTargetItem" },
                [EVENT_PLAYER_UNIT_SPELL_FINISH] = { "GetTriggerPlayer", "GetTriggerUnit", "GetSpellAbility", "GetSpellAbilityId", "GetSpellAbilityUnit" },
                [EVENT_PLAYER_UNIT_SPELL_ENDCAST] = { "GetTriggerPlayer", "GetTriggerUnit", "GetSpellAbility", "GetSpellAbilityId", "GetSpellAbilityUnit" },
                [EVENT_PLAYER_UNIT_PAWN_ITEM] = { "GetTriggerPlayer", "GetTriggerUnit", "GetBuyingUnit", "GetSoldItem", "GetSellingUnit", "GetManipulatedItem", "GetManipulatingUnit" },                                                   -- todo: test this combination
                [EVENT_PLAYER_UNIT_STACK_ITEM] = { "GetTriggerPlayer", "GetTriggerUnit", "BlzGetStackingItemSource", "BlzGetStackingItemTarget", "BlzGetStackingItemTargetPreviousCharges", "GetManipulatedItem", "GetManipulatingUnit" }, -- todo: figure out duplicates
            }

            local unitEventResponseMap = {
                [EVENT_UNIT_DAMAGED] = { "GetTriggerUnit", "GetEventDamage", "GetEventDamageSource", "BlzGetEventDamageTarget", "BlzGetEventDamageType", "BlzGetEventAttackType", "BlzGetEventWeaponType", "BlzGetEventIsAttack" },  -- todo: triggerUnit == ??
                [EVENT_UNIT_DAMAGING] = { "GetTriggerUnit", "GetEventDamage", "GetEventDamageSource", "BlzGetEventDamageTarget", "BlzGetEventDamageType", "BlzGetEventAttackType", "BlzGetEventWeaponType", "BlzGetEventIsAttack" }, -- todo: triggerUnit == ??
                [EVENT_UNIT_DEATH] = { "GetTriggerUnit", "GetDyingUnit", "GetKillingUnit" },
                [EVENT_UNIT_DECAY] = { "GetTriggerUnit", "GetDecayingUnit" },
                [EVENT_UNIT_DETECTED] = { "GetTriggerPlayer", "GetTriggerUnit", "GetDetectedUnit", "GetEventDetectingPlayer" },
                [EVENT_UNIT_HIDDEN] = { "GetTriggerUnit" }, -- what is this event even?
                [EVENT_UNIT_SELECTED] = playerUnitEventResponseMap[EVENT_PLAYER_UNIT_SELECTED],
                [EVENT_UNIT_DESELECTED] = playerUnitEventResponseMap[EVENT_PLAYER_UNIT_DESELECTED],
                [EVENT_UNIT_STATE_LIMIT] = { "GetTriggerUnit", "GetEventUnitState" },
                [EVENT_UNIT_ACQUIRED_TARGET] = { "GetTriggerUnit", "GetEventTargetUnit" },
                [EVENT_UNIT_TARGET_IN_RANGE] = { "GetTriggerUnit", "GetEventTargetUnit" },
                [EVENT_UNIT_ATTACKED] = { "GetTriggerUnit", "GetAttacker" },
                [EVENT_UNIT_RESCUED] = { "GetTriggerUnit", "GetRescuer" },
                [EVENT_UNIT_CONSTRUCT_CANCEL] = { "GetTriggerUnit", "GetConstructingStructure", "GetCancelledStructure" },
                [EVENT_UNIT_CONSTRUCT_FINISH] = { "GetTriggerUnit", "GetConstructedStructure" },
                [EVENT_UNIT_UPGRADE_START] = { "GetTriggerUnit", "GetConstructingStructure" },  -- todo: is this how these events work?
                [EVENT_UNIT_UPGRADE_CANCEL] = { "GetTriggerUnit", "GetConstructingStructure" }, -- todo: is this how these events work?
                [EVENT_UNIT_UPGRADE_FINISH] = { "GetTriggerUnit", "GetConstructedStructure" },  -- todo: is this how these events work?
                [EVENT_UNIT_TRAIN_START] = { "GetTriggerUnit", "GetTrainedUnitType" },
                [EVENT_UNIT_TRAIN_CANCEL] = { "GetTriggerUnit", "GetTrainedUnitType" },
                [EVENT_UNIT_TRAIN_FINISH] = { "GetTriggerUnit", "GetTrainedUnitType", "GetTrainedUnit" },
                [EVENT_UNIT_RESEARCH_START] = { "GetTriggerUnit", "GetResearched", "GetResearchingUnit" },
                [EVENT_UNIT_RESEARCH_CANCEL] = { "GetTriggerUnit", "GetResearched", "GetResearchingUnit" },
                [EVENT_UNIT_RESEARCH_FINISH] = { "GetTriggerUnit", "GetResearched", "GetResearchingUnit" },
                [EVENT_UNIT_ISSUED_ORDER] = { "GetTriggerUnit", "GetOrderedUnit", "GetIssuedOrderId" },
                [EVENT_UNIT_ISSUED_POINT_ORDER] = { "GetTriggerUnit", "GetOrderedUnit", "GetIssuedOrderId", "GetOrderPointX", "GetOrderPointY", --[["GetOrderPointLoc"]] },                                                                                              -- todo: orderTarget =  multiple things?
                [EVENT_UNIT_ISSUED_TARGET_ORDER] = { "GetTriggerUnit", "GetOrderedUnit", "GetIssuedOrderId", "GetOrderPointX", "GetOrderPointY", --[["GetOrderPointLoc",]] "GetOrderTarget", "GetOrderTargetDestructable", "GetOrderTargetUnit", "GetOrderTargetItem" }, -- todo: orderTarget =  multiple things?
                [EVENT_UNIT_HERO_LEVEL] = { "GetTriggerUnit", "GetLevelingUnit" },
                [EVENT_UNIT_HERO_SKILL] = { "GetTriggerUnit", "GetLearnedSkillLevel", "GetLearnedSkill", "GetLearningUnit" },
                [EVENT_UNIT_HERO_REVIVABLE] = { "GetTriggerUnit", "GetRevivableUnit" },
                [EVENT_UNIT_HERO_REVIVE_START] = { "GetTriggerUnit", "GetRevivingUnit" },
                [EVENT_UNIT_HERO_REVIVE_CANCEL] = { "GetTriggerUnit", "GetRevivingUnit" },
                [EVENT_UNIT_HERO_REVIVE_FINISH] = { "GetTriggerUnit", "GetRevivingUnit" },
                [EVENT_UNIT_SUMMON] = { "GetTriggerUnit", "GetSummoningUnit", "GetSummonedUnit" },
                [EVENT_UNIT_DROP_ITEM] = { "GetTriggerUnit", "GetManipulatingUnit", "GetManipulatedItem" },
                [EVENT_UNIT_PICKUP_ITEM] = { "GetTriggerUnit", "GetManipulatingUnit", "GetManipulatedItem", "BlzGetAbsorbingItem", "BlzGetManipulatedItemWasAbsorbed" },
                [EVENT_UNIT_USE_ITEM] = { "GetTriggerUnit", "GetManipulatingUnit", "GetManipulatedItem" },
                [EVENT_UNIT_LOADED] = { "GetTriggerUnit", "GetTransportUnit", "GetLoadedUnit" },
                [EVENT_UNIT_SELL] = { "GetTriggerUnit", "GetBuyingUnit", "GetSoldUnit", "GetSellingUnit" },
                [EVENT_UNIT_CHANGE_OWNER] = { "GetTriggerUnit", "GetChangingUnit", "GetChangingUnitPrevOwner" },
                [EVENT_UNIT_SELL_ITEM] = { "GetTriggerUnit", "GetBuyingUnit", "GetSoldItem", "GetSellingUnit" },
                [EVENT_UNIT_SPELL_CHANNEL] = { "GetTriggerUnit", "GetSpellAbility", "GetSpellAbilityId", "GetSpellAbilityUnit", "GetSpellTargetX", "GetSpellTargetY", --[[GetSpellTargetLoc,]] "GetSpellTargetUnit", "GetSpellTargetDestructable", "GetSpellTargetItem" },
                [EVENT_UNIT_SPELL_CAST] = { "GetTriggerUnit", "GetSpellAbility", "GetSpellAbilityId", "GetSpellAbilityUnit", "GetSpellTargetX", "GetSpellTargetY", --[[GetSpellTargetLoc,]] "GetSpellTargetUnit", "GetSpellTargetDestructable", "GetSpellTargetItem" },
                [EVENT_UNIT_SPELL_EFFECT] = { "GetTriggerUnit", "GetSpellAbility", "GetSpellAbilityId", "GetSpellAbilityUnit", "GetSpellTargetX", "GetSpellTargetY", --[[GetSpellTargetLoc,]] "GetSpellTargetUnit", "GetSpellTargetDestructable", "GetSpellTargetItem" },
                [EVENT_UNIT_SPELL_FINISH] = { "GetTriggerUnit", "GetSpellAbility", "GetSpellAbilityId", "GetSpellAbilityUnit" },
                [EVENT_UNIT_SPELL_ENDCAST] = { "GetTriggerUnit", "GetSpellAbility", "GetSpellAbilityId", "GetSpellAbilityUnit" },
                [EVENT_UNIT_PAWN_ITEM] = { "GetTriggerUnit", "GetBuyingUnit", "GetSoldItem", "GetSellingUnit", "GetManipulatedItem", "GetManipulatingUnit" },                                                   -- todo: test this combination
                [EVENT_UNIT_STACK_ITEM] = { "GetTriggerUnit", "BlzGetStackingItemSource", "BlzGetStackingItemTarget", "BlzGetStackingItemTargetPreviousCharges", "GetManipulatedItem", "GetManipulatingUnit" }, -- todo: figure out duplicates
            }

            local frameEventResponseMap = {
                [FRAMEEVENT_CONTROL_CLICK] = { "BlzGetTriggerFrameEvent", "BlzGetTriggerFrame", "GetTriggerPlayer" },
                [FRAMEEVENT_MOUSE_ENTER] = { "BlzGetTriggerFrameEvent", "BlzGetTriggerFrame", "GetTriggerPlayer" },
                [FRAMEEVENT_MOUSE_LEAVE] = { "BlzGetTriggerFrameEvent", "BlzGetTriggerFrame", "GetTriggerPlayer" },
                [FRAMEEVENT_MOUSE_UP] = { "BlzGetTriggerFrameEvent", "BlzGetTriggerFrame", "GetTriggerPlayer" },
                [FRAMEEVENT_MOUSE_DOWN] = { "BlzGetTriggerFrameEvent", "BlzGetTriggerFrame", "GetTriggerPlayer" },
                [FRAMEEVENT_MOUSE_WHEEL] = { "BlzGetTriggerFrameEvent", "BlzGetTriggerFrame", "GetTriggerPlayer" },
                [FRAMEEVENT_CHECKBOX_CHECKED] = { "BlzGetTriggerFrameEvent", "BlzGetTriggerFrame", "GetTriggerPlayer" },
                [FRAMEEVENT_CHECKBOX_UNCHECKED] = { "BlzGetTriggerFrameEvent", "BlzGetTriggerFrame", "GetTriggerPlayer" },
                [FRAMEEVENT_EDITBOX_TEXT_CHANGED] = { "BlzGetTriggerFrameEvent", "BlzGetTriggerFrame", "GetTriggerPlayer", "BlzGetTriggerFrameValue", },
                [FRAMEEVENT_POPUPMENU_ITEM_CHANGED] = { "BlzGetTriggerFrameEvent", "BlzGetTriggerFrame", "GetTriggerPlayer", "BlzGetTriggerFrameValue", },
                [FRAMEEVENT_MOUSE_DOUBLECLICK] = { "BlzGetTriggerFrameEvent", "BlzGetTriggerFrame", "GetTriggerPlayer" },
                [FRAMEEVENT_SPRITE_ANIM_UPDATE] = { "BlzGetTriggerFrameEvent", "BlzGetTriggerFrame", "GetTriggerPlayer" },
                [FRAMEEVENT_SLIDER_VALUE_CHANGED] = { "BlzGetTriggerFrameEvent", "BlzGetTriggerFrame", "GetTriggerPlayer", "BlzGetTriggerFrameValue", },
                [FRAMEEVENT_DIALOG_CANCEL] = { "BlzGetTriggerFrameEvent", "BlzGetTriggerFrame", "GetTriggerPlayer" },
                [FRAMEEVENT_DIALOG_ACCEPT] = { "BlzGetTriggerFrameEvent", "BlzGetTriggerFrame", "GetTriggerPlayer" },
                [FRAMEEVENT_EDITBOX_ENTER] = { "BlzGetTriggerFrameEvent", "BlzGetTriggerFrame", "GetTriggerPlayer" }
            }

            -- unused events - cannot be passed to any native
            -- EVENT_WIDGET_DEATH
            -- EVENT_DIALOG_BUTTON_CLICK
            -- EVENT_DIALOG_CLICK

            EventRegistry.Variable = defineEventType(TriggerRegisterVariableEvent, 4,
                gameEventResponseMap[EVENT_GAME_VARIABLE_LIMIT])
            EventRegistry.GameState = defineEventType(TriggerRegisterGameStateEvent, 4,
                gameEventResponseMap[EVENT_GAME_STATE_LIMIT])
            EventRegistry.Dialog = defineEventType(TriggerRegisterDialogEvent, 2, dialogEventResponses)
            EventRegistry.DialogButton = defineEventType(TriggerRegisterDialogButtonEvent, 2, dialogEventResponses)
            EventRegistry.Game = defineDynamicEventType(TriggerRegisterGameEvent, 2, gameEventResponseMap)
            EventRegistry.EnterRegion = defineEventTypeWithFilter(TriggerRegisterEnterRegion, 3,
                gameEventResponseMap[EVENT_GAME_ENTER_REGION], "GetFilterUnit")
            EventRegistry.LeaveRegion = defineEventTypeWithFilter(TriggerRegisterLeaveRegion, 3,
                gameEventResponseMap[EVENT_GAME_LEAVE_REGION], "GetFilterUnit")
            EventRegistry.TrackableHit = defineEventType(TriggerRegisterTrackableHitEvent, 2,
                gameEventResponseMap[EVENT_GAME_TRACKABLE_HIT])
            EventRegistry.TrackableTrack = defineEventType(TriggerRegisterTrackableTrackEvent, 2,
                gameEventResponseMap[EVENT_GAME_TRACKABLE_TRACK])
            EventRegistry.Command = defineEventType(TriggerRegisterCommandEvent, 3, {})
            EventRegistry.UpgradeCommand = defineEventType(TriggerRegisterUpgradeCommandEvent, 2, {})
            EventRegistry.Player = defineDynamicEventType(TriggerRegisterPlayerEvent, 3, playerEventResponseMap)
            EventRegistry.PlayerUnit = defineDynamicEventTypeWithFilter(TriggerRegisterPlayerUnitEvent, 4,
                playerUnitEventResponseMap, "GetFilterUnit")
            EventRegistry.PlayerAlliance = defineEventType(TriggerRegisterPlayerAllianceChange, 3,
                playerEventResponseMap[EVENT_PLAYER_ALLIANCE_CHANGED])
            EventRegistry.PlayerState = defineEventType(TriggerRegisterPlayerStateEvent, 5,
                playerEventResponseMap[EVENT_PLAYER_STATE_LIMIT])
            EventRegistry.Chat = defineEventType(TriggerRegisterPlayerChatEvent, 4,
                { "GetTriggerPlayer", "GetEventPlayerChatString", "GetEventPlayerChatStringMatched" } -- todo: test EVENT_PLAYER_CHAT
            )
            EventRegistry.Death = defineEventType(TriggerRegisterDeathEvent, 2,
                { "GetTriggerWidget", "GetTriggerDestructable", "GetTriggerUnit" } -- todo: needs a special thing?
            )
            EventRegistry.UnitState = defineEventType(TriggerRegisterUnitStateEvent, 5,
                unitEventResponseMap[EVENT_UNIT_STATE_LIMIT]) --todo: does GetTriggerUnit work for this?
            EventRegistry.Unit = defineDynamicEventType(TriggerRegisterUnitEvent, 3, unitEventResponseMap)
            EventRegistry.FilterUnit = defineDynamicEventTypeWithFilter(TriggerRegisterUnitEvent, 4,
                unitEventResponseMap, "GetFilterUnit") -- actually overrides TriggerRegisterFilterUnitEvent but uses the no-filter one
            EventRegistry.UnitInRange = defineEventTypeWithFilter(TriggerRegisterUnitInRange, 4,
                unitEventResponseMap[EVENT_UNIT_TARGET_IN_RANGE], "GetFilterUnit")
            EventRegistry.Frame = defineDynamicEventType(BlzTriggerRegisterFrameEvent, 3, frameEventResponseMap)
            EventRegistry.PlayerSync = defineEventType(BlzTriggerRegisterPlayerSyncEvent, 4,
                gameEventResponseMap[EVENT_PLAYER_SYNC_DATA])
            EventRegistry.PlayerKey = defineEventType(BlzTriggerRegisterPlayerKeyEvent, 5,
                gameEventResponseMap[EVENT_PLAYER_KEY])

            -- Timer and TimerExpire events registered in Timer section

            ---@class LIGUI_EventRegistryAPI
            local eventRegistryAPI = {
                eventResponseMap = eventResponseMap
            }
            return eventRegistryAPI
        end
    end)
    OnInit.root("LIGUI_CommonOverrides", function(require)
        -- todo: test this
        -- SyncSelections apparently doesn't work properly, and only does weird things where it deselects player units if done too quickly (not to mention, breaks unit selections if spammed)
        SyncSelections                = DoNothing

        --The next part of the code is purely optional, as it is intended to optimize rather than add new functionality
        CommentString                 = nil
        RegisterDestDeathInRegionEnum = nil

        -- Native Atans are faster than math.atan, surprisingly
        -- AtanBJ                               = function(ratio) return math.atan(ratio) * bj_RADTODEG end ---@type fun(ratio: number): number
        -- Atan2BJ                              = function(y, x) return math.atan(y, x) * bj_RADTODEG end ---@type fun(x: number, y: number): number
        Cos                           = math.cos
        Sin                           = math.sin
        Tan                           = math.tan
        Acos                          = math.acos
        Asin                          = math.asin
        Pow                           = function(base, exponent) return base ^ exponent end ---@type fun(base: number, exponent: number): number
        SquareRoot                    = math.sqrt
        Deg2Rad                       = function(degrees) return degrees * bj_DEGTORAD end ---@type fun(degrees: number): number
        Rad2Deg                       = function(radians) return radians * bj_RADTODEG end ---@type fun(radians: number): number

        SubString                     = function(source, start, _end) return string.sub(source, start + 1, _end) end ---@type fun(source: string, start: integer, _end: integer): string
        StringLength                  = string.len

        ---@param source string
        ---@param upper boolean
        ---@return string
        function StringCase(source, upper)
            if upper then
                return string.upper(source)
            else
                return string.lower(source)
            end
        end
    end)
    OnInit.root("LIGUI_HashtableOverride", function(require)
        local hashtableAPI = require "LIGUI_Hashtables" --[[@as LIGUI_HashtableAPI]]

        local createDefault = hashtableAPI.createDefault
        local checkHashtableArgs = hashtableAPI.checkHashtableArgs
        local load = hashtableAPI.load
        local createSaveIntoTyped = hashtableAPI.createSaveIntoTyped

        ---@return FakeHashtable
        function InitHashtable()
            return { __faketype = "userdata" }
        end

        SaveInteger = createSaveIntoTyped('integer') ---@type fun(whichHashtable: FakeHashtable, parentKey: unknown, childKey: unknown, value: integer)
        SaveReal = createSaveIntoTyped('real') ---@type fun(whichHashtable: FakeHashtable, parentKey: unknown, childKey: unknown, value: number)
        SaveBoolean = createSaveIntoTyped('boolean') ---@type fun(whichHashtable: FakeHashtable, parentKey: unknown, childKey: unknown, value: boolean)
        SaveStr = createSaveIntoTyped('string') ---@type fun(whichHashtable: FakeHashtable, parentKey: unknown, childKey: unknown, value: string)
        local saveHandle = createSaveIntoTyped('handle')

        LoadInteger = createDefault('integer', 0) ---@type fun(whichHashTable: FakeHashtable, parentKey: unknown, childKey: unknown): integer
        LoadReal = createDefault('real', 0) ---@type fun(whichHashTable: FakeHashtable, parentKey: unknown, childKey: unknown): number
        LoadBoolean = createDefault('boolean', false) ---@type fun(whichHashTable: FakeHashtable, parentKey: unknown, childKey: unknown): boolean
        LoadStr = createDefault('string', '') ---@type fun(whichHashTable: FakeHashtable, parentKey: unknown, childKey: unknown): string
        local loadHandle = createDefault('handle', nil)

        do
            local sub = string.sub
            for key in pairs(_ENV) do
                if sub(key, -6) == "Handle" then
                    local str = sub(key, 1, 4)
                    if str == "Save" then
                        _ENV[key] = saveHandle
                    elseif str == "Load" then
                        _ENV[key] = loadHandle
                    end
                end
            end
        end

        ---@param whichHashTable FakeHashtable
        ---@param parentKey unknown
        ---@param childKey unknown
        ---@return boolean
        function HaveSavedBoolean(whichHashTable, parentKey, childKey)
            if checkHashtableArgs(whichHashTable, parentKey, childKey) then return false end
            return load(whichHashTable, parentKey, 'boolean')[childKey] ~= nil
        end

        ---@param whichHashTable FakeHashtable
        ---@param parentKey unknown
        ---@param childKey unknown
        ---@return boolean
        function HaveSavedInteger(whichHashTable, parentKey, childKey)
            if checkHashtableArgs(whichHashTable, parentKey, childKey) then return false end
            return load(whichHashTable, parentKey, 'integer')[childKey] ~= nil
        end

        ---@param whichHashTable FakeHashtable
        ---@param parentKey unknown
        ---@param childKey unknown
        ---@return boolean
        function HaveSavedReal(whichHashTable, parentKey, childKey)
            if checkHashtableArgs(whichHashTable, parentKey, childKey) then return false end
            return load(whichHashTable, parentKey, 'real')[childKey] ~= nil
        end

        ---@param whichHashTable FakeHashtable
        ---@param parentKey unknown
        ---@param childKey unknown
        ---@return boolean
        function HaveSavedString(whichHashTable, parentKey, childKey)
            if checkHashtableArgs(whichHashTable, parentKey, childKey) then return false end
            return load(whichHashTable, parentKey, 'string')[childKey] ~= nil
        end

        ---@param whichHashTable FakeHashtable
        ---@param parentKey unknown
        ---@param childKey unknown
        ---@return boolean
        function HaveSavedHandle(whichHashTable, parentKey, childKey)
            if checkHashtableArgs(whichHashTable, parentKey, childKey) then return false end
            return load(whichHashTable, parentKey, 'handle')[childKey] ~= nil
        end

        ---@param whichHashTable FakeHashtable
        function FlushParentHashtable(whichHashTable)
            if check(whichHashTable ~= nil, 'whichHashTable cannot be nil') then return end
            whichHashTable.boolean = nil
            whichHashTable.integer = nil
            whichHashTable.real = nil
            whichHashTable.string = nil
            whichHashTable.handle = nil
        end

        ---@param whichHashTable FakeHashtable
        ---@param parentKey unknown
        function FlushChildHashtable(whichHashTable, parentKey)
            if check(whichHashTable ~= nil, 'whichHashTable cannot be nil') then return end
            if check(parentKey ~= nil, 'parentKey cannot be nil') then return end
            if whichHashTable.boolean then whichHashTable.boolean[parentKey] = nil end
            if whichHashTable.integer then whichHashTable.integer[parentKey] = nil end
            if whichHashTable.real then whichHashTable.real[parentKey] = nil end
            if whichHashTable.string then whichHashTable.string[parentKey] = nil end
            if whichHashTable.handle then whichHashTable.handle[parentKey] = nil end
        end
    end)
    OnInit.root("LIGUI_TriggerOverride", function(require)
        require "LIGUI_FakeType"
        local coroutineAPI = require "LIGUI_Coroutines" --[[@as LIGUI_CoroutineAPI]]
        local threadsAllDone = coroutineAPI.threadsAllDone

        local threadDataAPI = require "LIGUI_ThreadData" --[[@as LIGUI_ThreadDataAPI]]
        local getThreadData = threadDataAPI.getThreadData
        local setupThreadData = threadDataAPI.setupThreadData

        require "LIGUI_Boolexprs"
        ---@class FakeTrigger: FakedType, trigger
        ---@field private enabled boolean
        ---@field private waitOnSleep boolean
        ---@field private execCount integer
        ---@field private evalCount integer
        ---@field private events table<AbstractTriggerEvent, boolean>
        ---@field private conditions table<fun():boolean, boolean>
        ---@field private actions table<fun(), boolean>
        FakeTrigger = {}
        FakeTrigger.__index = FakeTrigger

        ---@return FakeTrigger
        function FakeTrigger.create()
            return setmetatable({
                __faketype = "userdata",
                enabled = true,
                pauseOnWait = false,
                execCount = 0,
                evalCount = 0,
                events = SyncedTable.create(),
                conditions = SyncedTable.create(),
                actions = SyncedTable.create()
            }, FakeTrigger)
        end

        ---@param state boolean? if undefined, switches trigger from enabled to disabled or from disabled to enabled, otherwise uses the state value
        function FakeTrigger:toggle(state)
            if state == nil then
                self.enabled = not self.enabled
            else
                self.enabled = state
            end

            if self.enabled then
                for event, enabled in pairs(self.events) do
                    if enabled then
                        event:addListener(self)
                    end
                end
            else
                for event, enabled in pairs(self.events) do
                    if enabled then
                        event:removeListener(self)
                    end
                end
            end
        end

        ---@return boolean
        function FakeTrigger:isEnabled()
            return self.enabled
        end

        ---@param waitOnSleep boolean
        function FakeTrigger:setWaitOnSleep(waitOnSleep)
            self.waitOnSleep = waitOnSleep
        end

        ---@return boolean
        function FakeTrigger:isWaitOnSleep()
            return self.waitOnSleep
        end

        ---@param event AbstractTriggerEvent
        function FakeTrigger:addEvent(event)
            debug("Add event", event, "to trigger", self)
            self.events[event] = true
            event:addListener(self)
        end

        ---@param event AbstractTriggerEvent
        function FakeTrigger:removeEvent(event)
            self.events[event] = nil
            event:removeListener(self)
        end

        function FakeTrigger:clearEvents()
            for event, _ in pairs(self.events) do
                event:removeListener(self)
            end
            self.events = SyncedTable.create()
        end

        ---@param event AbstractTriggerEvent
        ---@param state boolean?
        function FakeTrigger:toggleEvent(event, state)
            if self.events[event] == nil then return end
            if state == nil then
                self.events[event] = not self.events[event]
            else
                self.events[event] = state
            end

            if self.events[event] then
                event:addListener(self)
            else
                event:removeListener(self)
            end
        end

        ---@param condition fun():boolean
        function FakeTrigger:addCondition(condition)
            self.conditions[condition] = true
        end

        ---@param condition fun():boolean
        function FakeTrigger:removeCondition(condition)
            self.conditions[condition] = nil
        end

        function FakeTrigger:clearConditions()
            self.conditions = SyncedTable.create()
        end

        ---@param condition fun():boolean
        ---@param state boolean?
        function FakeTrigger:toggleCondition(condition, state)
            if self.conditions[condition] == nil then return end
            if state == nil then
                self.conditions[condition] = not self.conditions[condition]
            else
                self.conditions[condition] = state
            end
        end

        ---@return boolean
        function FakeTrigger:evaluate()
            self.evalCount = self.evalCount + 1
            for condition, enabled in pairs(self.conditions) do
                if enabled and not condition() then
                    return false
                end
            end
            return true
        end

        ---@return integer
        function FakeTrigger:getEvalCount()
            return self.evalCount
        end

        ---@param action fun()
        function FakeTrigger:addAction(action)
            self.actions[action] = true
        end

        ---@param action fun()
        function FakeTrigger:removeAction(action)
            self.actions[action] = nil
        end

        function FakeTrigger:clearActions()
            self.actions = SyncedTable.create()
        end

        ---@param action fun()
        ---@param state boolean?
        function FakeTrigger:toggleAction(action, state)
            if self.actions[action] == nil then return end
            if state == nil then
                self.actions[action] = not self.actions[action]
            else
                self.actions[action] = state
            end
        end

        ---@param withSleep boolean?
        function FakeTrigger:execute(withSleep)
            local parentThread = coroutine.running()
            self.execCount = self.execCount + 1
            -- if execute with sleep and caller is marked with waitOnSleep
            if withSleep and getThreadData(parentThread).waitOnSleep then
                local threads = {} ---@type thread[]
                local threadData = {} ---@type table<thread, table>
                for action, enabled in pairs(self.actions) do
                    if enabled then
                        local actionThread = coroutine.create(action)
                        table.insert(threads, actionThread)
                        local data = setupThreadData(actionThread, parentThread)
                        threadData[actionThread] = data
                        --todo: triggering trigger reports the trigger that executed it, right?
                        rawset(data, "GetTriggeringTrigger", self) -- don't overwrite master threadData entry
                        rawset(data, "waitOnSleep", self.waitOnSleep)
                        coroutine.resume(actionThread)
                    end
                end
                if not threadsAllDone(threads) then
                    local function polledWaitCallback()
                        if threadsAllDone(threads) then
                            coroutine.resume(parentThread)
                        end
                    end
                    for _, thread in ipairs(threads) do
                        rawset(threadData[thread], "forkJoinCallback", polledWaitCallback)
                    end
                    coroutine.yield(parentThread)
                end
            else
                for action, enabled in pairs(self.actions) do
                    if enabled then
                        local thisThread = coroutine.create(action)
                        local data = setupThreadData(thisThread, parentThread)
                        rawset(data, "GetTriggeringTrigger", self) -- don't overwrite master threadData entry
                        rawset(data, "waitOnSleep", self.waitOnSleep)
                        coroutine.resume(thisThread)
                    end
                end
            end
        end

        ---@return integer
        function FakeTrigger:getExecCount()
            return self.execCount
        end

        function FakeTrigger:reset()
            self.execCount = 0
            self.evalCount = 0
        end

        -- Override Natives
        do
            ---@param thread thread
            local function finishedWait(thread)
                local callback = getThreadData(thread)["forkJoinCallback"]
                if callback then
                    callback(coroutine.resume(thread))
                else
                    coroutine.resume(thread)
                end
            end

            ---@param duration number
            function PolledWait(duration)
                local thread = coroutine.running()
                TimerQueue:callDelayed(duration, finishedWait, thread)
                coroutine.yield()
            end

            CreateTrigger = FakeTrigger.create
            DestroyTrigger = DoNothing
            ResetTrigger = FakeTrigger.reset
            EnableTrigger = function(trigger) trigger:toggle(true) end ---@type fun(trigger: FakeTrigger)
            DisableTrigger = function(trigger) trigger:toggle(false) end ---@type fun(trigger: FakeTrigger)
            IsTriggerEnabled = FakeTrigger.isEnabled
            TriggerWaitOnSleeps = FakeTrigger.setWaitOnSleep
            IsTriggerWaitOnSleeps = FakeTrigger.isWaitOnSleep
            GetTriggerEvalCount = FakeTrigger.getEvalCount
            GetTriggerExecCount = FakeTrigger.getExecCount
            ---@param trigger FakeTrigger
            ---@param condition fun(): boolean
            ---@return fun(): boolean
            TriggerAddCondition = function(trigger, condition)
                FakeTrigger.addCondition(trigger, condition)
                return condition
            end
            TriggerRemoveCondition = FakeTrigger.removeCondition
            TriggerClearConditions = FakeTrigger.clearConditions
            ---@param trigger FakeTrigger
            ---@param action function
            ---@return function
            TriggerAddAction = function(trigger, action)
                FakeTrigger.addAction(trigger, action)
                return action
            end
            TriggerRemoveAction = FakeTrigger.removeAction
            TriggerClearActions = FakeTrigger.clearActions
            TriggerSleepAction = PolledWait
            -- TriggerWaitForSound -- I'll probably leave this as is
            TriggerEvaluate = FakeTrigger.evaluate
            TriggerExecute = FakeTrigger.execute
            ---@param whichTrigger FakeTrigger|trigger
            TriggerExecuteWait = function(whichTrigger) whichTrigger --[[@as FakeTrigger]]:execute(true) end
            -- TriggerSyncStart -- I'll probably leave this as is
            -- TriggerSyncReady -- I'll probably leave this as is

            ---@param EventRegistryMethod function
            local function makeTriggerEventOverrideWrapper(EventRegistryMethod)
                ---@param trigger FakeTrigger
                ---@param ... unknown
                ---@return AbstractTriggerEvent
                return function(trigger, ...)
                    local event = EventRegistryMethod(...)
                    trigger:addEvent(event)
                    return event
                end
            end

            TriggerRegisterVariableEvent = makeTriggerEventOverrideWrapper(EventRegistry.Variable) ---@overload fun(trigger: FakeTrigger, varname: string, opcode: limitop, limitval: number): AbstractTriggerEvent
            TriggerRegisterGameStateEvent = makeTriggerEventOverrideWrapper(EventRegistry.GameState) ---@overload fun(trigger: FakeTrigger, gamestate: gamestate, opcode: limitop, limitval: number): AbstractTriggerEvent
            TriggerRegisterDialogEvent = makeTriggerEventOverrideWrapper(EventRegistry.Dialog) ---@overload fun(trigger: FakeTrigger, dialog: dialog): AbstractTriggerEvent
            TriggerRegisterDialogButtonEvent = makeTriggerEventOverrideWrapper(EventRegistry.DialogButton) ---@overload fun(trigger: FakeTrigger, button: button): AbstractTriggerEvent
            TriggerRegisterGameEvent = makeTriggerEventOverrideWrapper(EventRegistry.Game) ---@overload fun(trigger: FakeTrigger, gameEvent: gameevent): AbstractTriggerEvent
            TriggerRegisterEnterRegion = makeTriggerEventOverrideWrapper(EventRegistry.EnterRegion) ---@overload fun(trigger: FakeTrigger,region: region, filter: boolexpr?): AbstractTriggerEvent
            TriggerRegisterLeaveRegion = makeTriggerEventOverrideWrapper(EventRegistry.LeaveRegion) ---@overload fun(trigger: FakeTrigger,region: region, filter: boolexpr?): AbstractTriggerEvent
            TriggerRegisterTrackableHitEvent = makeTriggerEventOverrideWrapper(EventRegistry.TrackableHit) ---@overload fun(trigger: FakeTrigger,trackable: trackable): AbstractTriggerEvent
            TriggerRegisterTrackableTrackEvent = makeTriggerEventOverrideWrapper(EventRegistry.TrackableTrack) ---@overload fun(trigger: FakeTrigger,trackable: trackable): AbstractTriggerEvent
            TriggerRegisterCommandEvent = makeTriggerEventOverrideWrapper(EventRegistry.Command) ---@overload fun(trigger: FakeTrigger,ability: integer, order: string): AbstractTriggerEvent
            TriggerRegisterUpgradeCommandEvent = makeTriggerEventOverrideWrapper(EventRegistry.UpgradeCommand) ---@overload fun(trigger: FakeTrigger,upgrade: integer): AbstractTriggerEvent
            TriggerRegisterPlayerEvent = makeTriggerEventOverrideWrapper(EventRegistry.Player) ---@overload fun(trigger: FakeTrigger,player: player, playerEvent: playerevent): AbstractTriggerEvent
            TriggerRegisterPlayerUnitEvent = makeTriggerEventOverrideWrapper(EventRegistry.PlayerUnit) ---@overload fun(trigger: FakeTrigger,player: player, playerUnitEvent: playerunitevent, filter: boolexpr?): AbstractTriggerEvent
            TriggerRegisterPlayerAllianceChange = makeTriggerEventOverrideWrapper(EventRegistry.PlayerAlliance) ---@overload fun(trigger: FakeTrigger,player: player, allianceType: alliancetype): AbstractTriggerEvent
            TriggerRegisterPlayerStateEvent = makeTriggerEventOverrideWrapper(EventRegistry.PlayerState) ---@overload fun(trigger: FakeTrigger,player: player, state: playerstate, operation: limitop, limitValue: number): AbstractTriggerEvent
            TriggerRegisterPlayerChatEvent = makeTriggerEventOverrideWrapper(EventRegistry.Chat) ---@overload fun(trigger: FakeTrigger,player: player, matchText: string, exactMatch: boolean): AbstractTriggerEvent
            TriggerRegisterDeathEvent = makeTriggerEventOverrideWrapper(EventRegistry.Death) ---@overload fun(trigger: FakeTrigger,widget: widget): AbstractTriggerEvent
            TriggerRegisterUnitStateEvent = makeTriggerEventOverrideWrapper(EventRegistry.UnitState) ---@overload fun(trigger: FakeTrigger,unit: unit, state: unitstate, operation: limitop, limitValue: number): AbstractTriggerEvent
            TriggerRegisterUnitEvent = makeTriggerEventOverrideWrapper(EventRegistry.Unit) ---@overload fun(trigger: FakeTrigger,unit: unit, event: unitevent): AbstractTriggerEvent
            TriggerRegisterFilterUnitEvent = makeTriggerEventOverrideWrapper(EventRegistry.FilterUnit) ---@overload fun(trigger: FakeTrigger,unit: unit, event: unitevent, filter: boolexpr?): AbstractTriggerEvent
            TriggerRegisterUnitInRange = makeTriggerEventOverrideWrapper(EventRegistry.UnitInRange) ---@overload fun(trigger: FakeTrigger,unit: unit, range: number, filter: boolexpr?): AbstractTriggerEvent
            BlzTriggerRegisterFrameEvent = makeTriggerEventOverrideWrapper(EventRegistry.Frame) ---@overload fun(trigger: FakeTrigger,frame: framehandle, eventType: frameeventtype): AbstractTriggerEvent
            BlzTriggerRegisterPlayerSyncEvent = makeTriggerEventOverrideWrapper(EventRegistry.PlayerSync) ---@overload fun(trigger: FakeTrigger,player: player, prefix: string, fromServer: boolean): AbstractTriggerEvent
            BlzTriggerRegisterPlayerKeyEvent = makeTriggerEventOverrideWrapper(EventRegistry.PlayerKey) ---@overload fun(trigger: FakeTrigger,player: player, key: oskeytype, metaKey: integer, keyDown: boolean): AbstractTriggerEvent
        end
    end)
    OnInit.main("LIGUI_TimerOverride", function(require)
        local threadDataAPI = require "LIGUI_ThreadData" --[[@as LIGUI_ThreadDataAPI]]
        local setupThreadData = threadDataAPI.setupThreadData

        require "LIGUI_TriggerOverride"
        require "TimerQueue"
        require "SyncedTable"
        if not TimerQueue or not SyncedTable then return end
        local stopwatch = Stopwatch.create(false)
        OnInit.final(function() stopwatch:start() end)

        -- ============================
        --       Trigger Events
        -- ============================

        ---@class FakeTimerEvent: AbstractTriggerEvent
        ---@field timer FakeTimer
        FakeTimerEvent = {}
        FakeTimerEvent.__index = FakeTimerEvent

        ---@param timer FakeTimer?
        ---@return FakeTimerEvent
        local function createFakeTimerEvent(timer)
            return setmetatable({
                __faketype = "userdata",
                listeners = SyncedTable.create(),
                listenerAmount = 0,
                timer = timer
            }, FakeTimerEvent)
        end

        function FakeTimerEvent:notifyListeners()
            local thread = coroutine.running()
            for listener in pairs(self.listeners) do
                if listener:isEnabled() and listener:evaluate() then
                    local newThread = coroutine.create(listener.execute)
                    local data = setupThreadData(newThread, thread)
                    -- run in a coroutine to avoid TSA/PolledWait congesting every listener/trigger
                    coroutine.resume(newThread, listener)
                end
            end
        end

        ---@param self FakeTimerEvent
        ---@param listener FakeTrigger
        function FakeTimerEvent:addListener(listener)
            if self.listeners[listener] then
                self.listenerAmount = self.listenerAmount + 1
            end
            self.listeners[listener] = true
        end

        ---@param self FakeTimerEvent
        ---@param listener FakeTrigger
        function FakeTimerEvent:removeListener(listener)
            if self.listeners[listener] then
                self.listenerAmount = self.listenerAmount - 1
            end
            self.listeners[listener] = nil
        end

        ---@param trigger trigger
        local function triggerCallback(trigger)
            local success, result = pcall(TriggerEvaluate, trigger)
            if success and result then
                pcall(TriggerExecute, trigger)
            end
        end

        local function triggerTimeCallback(trigger, timeout, periodic)
            coroutine.wrap(triggerCallback)(trigger)
            if periodic then
                TimerQueue:callDelayed(timeout, triggerTimeCallback, trigger, timeout, periodic)
            end
        end

        local triggersWithTimers = {} ---@type table<trigger, table<FakeTimer, true>>
        local timersWithEvents = {} ---@type table<FakeTimer, table<trigger, boolean>> -- boolean is enabled/disabled

        ---@param whichTrigger FakeTrigger
        ---@param timeout number
        ---@param periodic boolean
        ---@return FakeTimerEvent
        EventRegistry.Timer = function(whichTrigger, timeout, periodic)
            if check(whichTrigger ~= nil, 'trigger cannot be nil') then return nil end
            if check(timeout ~= nil, 'timeout cannot be nil') then return nil end
            local event = createFakeTimerEvent(CreateTimer() --[[@as FakeTimer]])
            whichTrigger:addEvent(event)
            -- TimerStart(event.timer, timeout, periodic, nil)
            TimerQueue:callDelayed(timeout, triggerTimeCallback, whichTrigger, timeout, periodic)
            return event
        end

        ---@param whichTrigger FakeTrigger
        ---@param whichTimer FakeTimer,
        ---@return FakeTimerEvent
        EventRegistry.TimerExpire = function(whichTrigger, whichTimer)
            if check(whichTrigger ~= nil, 'trigger cannot be nil') then return nil end
            if check(whichTimer ~= nil, 'timer cannot be nil') then return nil end
            local event = createFakeTimerEvent(whichTimer)
            whichTrigger:addEvent(event)

            local triggerEvents = triggersWithTimers[whichTrigger] ---@type table<FakeTimer, true>
            if not triggerEvents then
                triggerEvents = SyncedTable.create()
                triggersWithTimers[whichTrigger] = triggerEvents
            end

            local timerEvents = timersWithEvents[whichTimer] ---@type table<trigger, boolean>
            if not timerEvents then
                timerEvents = SyncedTable.create()
                timersWithEvents[whichTimer] = timerEvents
            end

            timerEvents[whichTrigger] = true
            triggerEvents[whichTimer] = true

            return event
        end

        TriggerRegisterTimerEvent = EventRegistry
            .Timer ---@overload fun(trigger: FakeTrigger, timeout: number, periodic: boolean): AbstractTriggerEvent
        TriggerRegisterTimerExpireEvent = EventRegistry
            .TimerExpire ---@overload fun(trigger: FakeTrigger, timer: timer): AbstractTriggerEvent

        local oldDisableTrigger = DisableTrigger
        ---@param whichTrigger trigger
        function DisableTrigger(whichTrigger)
            oldDisableTrigger(whichTrigger)
            local timerEvents = triggersWithTimers[whichTrigger]
            if timerEvents then
                for timer, _ in pairs(timerEvents) do
                    timersWithEvents[timer][whichTrigger] = false
                end
            end
        end

        local oldEnableTrigger = EnableTrigger
        ---@param whichTrigger trigger
        function EnableTrigger(whichTrigger)
            oldEnableTrigger(whichTrigger)
            local timerEvents = triggersWithTimers[whichTrigger]
            if timerEvents then
                for timer, _ in pairs(timerEvents) do
                    timersWithEvents[timer][whichTrigger] = true
                end
            end
        end

        local oldDestroyTrigger = DestroyTrigger
        ---@param whichTrigger trigger
        function DestroyTrigger(whichTrigger)
            oldDestroyTrigger(whichTrigger)
            local timerEvents = triggersWithTimers[whichTrigger]
            if timerEvents then
                for timer, _ in pairs(timerEvents) do
                    timersWithEvents[timer][whichTrigger] = nil
                end
            end
            triggersWithTimers[whichTrigger] = nil
        end

        -- ============================
        --        TimerDialogs
        -- ============================

        ---@class TimerDialogData
        ---@field remainingTime number?
        ---@field speed number
        ---@field timer FakeTimer
        ---@field task integer?

        local oldCreateTimerDialog = CreateTimerDialog
        local oldTimerDialogSetRealTimeRemaining = TimerDialogSetRealTimeRemaining
        local oldTimerDialogSetSpeed = TimerDialogSetSpeed
        local oldDestroyTimerDialog = DestroyTimerDialog
        local timerDialogs = {} ---@type table<timerdialog, TimerDialogData>
        local timersWithDialogs = {} ---@type table<FakeTimer, table<timerdialog, boolean>>

        ---@param timerDialog timerdialog
        local function timerDialogCallback(timerDialog)
            local tdd = timerDialogs[timerDialog]
            local time ---@type number
            if tdd.remainingTime ~= nil then
                -- todo: does combining remaining time and speed cause remaining time to also be multiplied?
                if tdd.remainingTime > 0 then
                    tdd.remainingTime = tdd.remainingTime - 1
                    time = tdd.remainingTime --[[@as number]]
                else
                    time = 0
                end
            else
                time = TimerGetRemaining(tdd.timer) * tdd.speed
            end
            oldTimerDialogSetRealTimeRemaining(timerDialog, time)
        end

        ---@param t FakeTimer
        ---@return timerdialog
        function CreateTimerDialog(t)
            local td = oldCreateTimerDialog(nil)
            if t then
                local tdd = {
                    timer = t,
                    speed = 1.00,
                    task = TimerQueue:callDelayed(1.00, timerDialogCallback, td)
                }
                timerDialogs[td] = tdd
                local twd = timersWithDialogs[t]
                if not twd then
                    twd = SyncedTable.create()
                    timersWithDialogs[t] = twd
                end
                twd[td] = true
                oldTimerDialogSetRealTimeRemaining(td, TimerGetRemaining(t))
            end
            return td
        end

        ---@param timerDialog timerdialog
        function DestroyTimerDialog(timerDialog)
            if check(timerDialog ~= nil, 'timerDialog cannot be nil') then return end
            local tdd = timerDialogs[timerDialog]
            if tdd then
                timerDialogs[timerDialog] = nil
                TimerQueue:disableCallback(tdd.task)
            end
            oldDestroyTimerDialog(timerDialog)
        end

        ---@param whichDialog timerdialog
        ---@param timeRemaining number
        function TimerDialogSetRealTimeRemaining(whichDialog, timeRemaining)
            if check(whichDialog ~= nil, 'timerDialog cannot be nil') then return end
            if check(timeRemaining ~= nil, 'timeRemaining cannot be nil') then return end
            local tdd = timerDialogs[whichDialog]
            if tdd then
                tdd.remainingTime = timeRemaining
            end
            oldTimerDialogSetRealTimeRemaining(whichDialog, timeRemaining)
        end

        ---@param whichDialog timerdialog
        ---@param speedMultFactor number
        function TimerDialogSetSpeed(whichDialog, speedMultFactor)
            if check(whichDialog ~= nil, 'timerDialog cannot be nil') then return end
            if check(speedMultFactor ~= nil, 'speedMultFactor cannot be nil') then return end
            local tdd = timerDialogs[whichDialog]
            if tdd then
                tdd.speed = speedMultFactor
                TimerQueue:disableCallback(tdd.task)
                tdd.task = TimerQueue:callDelayed(1 / speedMultFactor, timerDialogCallback, whichDialog)
            end
            oldTimerDialogSetSpeed(whichDialog, speedMultFactor)
        end

        -- ============================
        --           Timers
        -- ============================

        ---@class FakeTimer: FakedType, timer
        ---@field startTime number?
        ---@field handler function?
        ---@field periodic boolean?
        ---@field timeout number?
        ---@field pausedTimeout number?
        ---@field task integer?

        local expiredTimers = setmetatable({}, { __mode = 'k' }) ---@type table<thread, FakeTimer>

        ---@return FakeTimer
        function CreateTimer()
            return { __faketype = "userdata" }
        end

        DestroyTimer = DoNothing

        ---@param whichTimer FakeTimer
        local function processCallbacks(whichTimer)
            if whichTimer.handler then whichTimer.handler() end
            local timerEvents = timersWithEvents[whichTimer]
            if timerEvents then
                for trigger, enabled in pairs(timerEvents) do
                    if enabled then
                        coroutine.wrap(triggerCallback)(trigger)
                    end
                end
            end
        end

        ---@param whichTimer FakeTimer
        local function callback(whichTimer)
            local thread = coroutine.create(processCallbacks)
            expiredTimers[thread] = whichTimer
            coroutine.resume(thread, whichTimer)

            if whichTimer.periodic then
                whichTimer.startTime = stopwatch:getElapsed()
                whichTimer.task = TimerQueue:callDelayed(whichTimer.timeout, callback)
            end
        end

        ---@param whichTimer FakeTimer
        ---@param timeout number
        ---@param periodic boolean
        ---@param handlerFunc function
        function TimerStart(whichTimer, timeout, periodic, handlerFunc)
            if check(whichTimer ~= nil, 'timer cannot be nil') then return end
            if check(timeout ~= nil, 'timeout cannot be nil') then return end

            whichTimer.handler = handlerFunc
            whichTimer.periodic = not not periodic
            whichTimer.timeout = timeout
            whichTimer.startTime = stopwatch:getElapsed()
            whichTimer.task = TimerQueue:callDelayed(timeout, callback, whichTimer)
        end

        ---@param whichTimer FakeTimer
        ---@return number
        function TimerGetElapsed(whichTimer)
            return stopwatch:getElapsed() - whichTimer.startTime
        end

        -- todo: implement bug
        ---@param whichTimer FakeTimer
        ---@return number
        function TimerGetRemaining(whichTimer)
            return whichTimer.timeout - stopwatch:getElapsed() - whichTimer.startTime
        end

        ---@param whichTimer FakeTimer
        ---@return number
        function TimerGetTimeout(whichTimer)
            return whichTimer.timeout
        end

        ---@param whichTimer FakeTimer
        function PauseTimer(whichTimer)
            if whichTimer.task then
                TimerQueue:disableCallback(whichTimer.task)
                whichTimer.pausedTimeout = TimerGetRemaining(whichTimer)
                whichTimer.task = nil
                local tds = timersWithDialogs[whichTimer]
                if tds then
                    for timerDialog, _ in pairs(tds) do
                        local tdd = timerDialogs[timerDialog]
                        TimerQueue:disableCallback(tdd.task)
                        tdd.task = nil
                    end
                end
            end
        end

        ---@param whichTimer FakeTimer
        function ResumeTimer(whichTimer)
            if whichTimer.pausedTimeout ~= nil then
                if not _RESUME_TIMER_RESTORE_PERIODIC then whichTimer.periodic = false end

                whichTimer.startTime = stopwatch:getElapsed() - whichTimer.timeout + whichTimer.pausedTimeout
                TimerQueue:callDelayed(whichTimer.timeout, callback, whichTimer)
                whichTimer.pausedTimeout = nil
                local tds = timersWithDialogs[whichTimer]
                if tds then
                    for timerDialog, _ in pairs(tds) do
                        local tdd = timerDialogs[timerDialog]
                        if tdd.task then TimerQueue:disableCallback(tdd.task) end
                        tdd.task = TimerQueue:callDelayed(1 / tdd.speed, timerDialogCallback, timerDialog)
                    end
                end
            end
        end

        ---@return FakeTimer
        function GetExpiredTimer()
            return expiredTimers[coroutine.running()]
        end

        -- these are now FAKE mauhahahhaha
        bj_queuedExecTimeoutTimer = CreateTimer()
        bj_delayedSuspendDecayTimer = CreateTimer()
        bj_volumeGroupsTimer = CreateTimer()
        bj_lastStartedTimer = CreateTimer()
    end)
    OnInit.root("LIGUI_LocationOverride", function(require)
        ---@class FakeLocation: FakedType
        ---@field [1] number x
        ---@field [2] number y

        local oldLocation = Location
        local oldRemove   = RemoveLocation
        local oldGetX     = GetLocationX
        local oldGetY     = GetLocationY
        local oldRally    = GetUnitRallyPoint
        local oldMoveLoc  = MoveLocation
        local oldGetZ     = GetLocationZ

        ---@param x number
        ---@param y number
        ---@return FakeLocation
        function Location(x, y)
            if check(x ~= nil, 'x cannot be nil') then return { 0.00, 0.00, __faketype = 'userdata' } end
            if check(y ~= nil, 'y cannot be nil') then return { 0.00, 0.00, __faketype = 'userdata' } end
            return { x, y, __faketype = "userdata" }
        end

        RemoveLocation = DoNothing ---@type fun(location: FakeLocation)

        ---@param loc FakeLocation
        ---@return number x
        function GetLocationX(loc)
            if check(loc ~= nil, 'loc cannot be nil') then return 0 end
            return loc[1]
        end

        ---@param loc FakeLocation
        ---@return number y
        function GetLocationY(loc)
            if check(loc ~= nil, 'loc cannot be nil') then return 0 end
            return loc[2]
        end

        ---@param loc FakeLocation
        ---@return number z
        function GetLocationZ(loc)
            if check(loc ~= nil, 'loc cannot be nil') then return 0 end
            return GUI.getCoordZ(loc[1], loc[2])
        end

        ---@param loc FakeLocation
        ---@param x number
        ---@param y number
        function MoveLocation(loc, x, y)
            if check(loc ~= nil, 'loc cannot be nil') then return end
            loc[1] = x
            loc[2] = y
        end

        local nativePoint
        OnInit.main("LIGUI_NativeLoc", function(require)
            nativePoint = oldLocation(0, 0)
        end)

        ---@param x number
        ---@param y number
        ---@return number z
        function GUI.getCoordZ(x, y)
            if check(x ~= nil, 'x cannot be nil') then return 0 end
            if check(y ~= nil, 'y cannot be nil') then return 0 end
            oldMoveLoc(nativePoint, x, y)
            return oldGetZ(nativePoint)
        end

        ---@param unit unit
        ---@return FakeLocation?
        function GetUnitRallyPoint(unit)
            if check(unit ~= nil, 'unit cannot be nil') then return nil end -- no unit, no rally
            local removeThis = oldRally(unit)                               --Actually needs to create a location for a brief moment, as there is no GetUnitRallyX/Y
            if removeThis == nil then return nil end                        -- in case there's no rally
            local loc = Location(oldGetX(removeThis), oldGetY(removeThis))
            oldRemove(removeThis)
            return loc
        end

        ---@param whichUnit unit
        ---@return FakeLocation
        function GetUnitLoc(whichUnit)
            if check(whichUnit ~= nil, "Unit cannot be nil") then return Location(0, 0) end
            return Location(GetUnitX(whichUnit), GetUnitY(whichUnit))
        end

        ---@return FakeLocation
        function GetOrderPointLoc()
            return Location(GetOrderPointX(), GetOrderPointY())
        end

        ---@return FakeLocation
        function GetSpellTargetLoc()
            local result = Location(GetSpellTargetX(), GetSpellTargetY())
            debug("Getting spell target location", result)
            return result
        end

        ---@param whichSetup camerasetup
        ---@return FakeLocation
        function CameraSetupGetDestPositionLoc(whichSetup)
            if check(whichSetup ~= nil, "Camera setup cannot be nil") then return Location(0, 0) end
            return Location(CameraSetupGetDestPositionX(whichSetup), CameraSetupGetDestPositionY(whichSetup))
        end

        ---@return FakeLocation
        function GetCameraTargetPositionLoc()
            return Location(GetCameraTargetPositionX(), GetCameraTargetPositionY())
        end

        ---@return FakeLocation
        function GetCameraEyePositionLoc()
            return Location(GetCameraEyePositionX(), GetCameraEyePositionY())
        end

        ---@return FakeLocation
        function BlzGetTriggerPlayerMousePosition()
            return Location(BlzGetTriggerPlayerMouseX(), BlzGetTriggerPlayerMouseY())
        end

        ---@param whichStartLocation integer
        ---@return FakeLocation
        function GetStartLocationLoc(whichStartLocation)
            if check(whichStartLocation ~= nil, "Start location id cannot be nil") then return Location(0, 0) end
            return Location(GetStartLocationX(whichStartLocation), GetStartLocationY(whichStartLocation))
        end

        ---@param whichRegion region
        ---@param whichLocation FakeLocation
        function RegionAddCellAtLoc(whichRegion, whichLocation)
            if check(whichRegion ~= nil, "region cannot be nil") then return end
            if check(whichLocation ~= nil, "location cannot be nil") then return end
            RegionAddCell(whichRegion, whichLocation[1], whichLocation[2])
        end

        ---@param whichRegion region
        ---@param whichLocation FakeLocation
        function RegionClearCellAtLoc(whichRegion, whichLocation)
            if check(whichRegion ~= nil, "region cannot be nil") then return end
            if check(whichLocation ~= nil, "location cannot be nil") then return end
            RegionClearCell(whichRegion, whichLocation[1], whichLocation[2])
        end

        ---@param whichRegion region
        ---@param whichLocation FakeLocation
        ---@return boolean
        function IsLocationInRegion(whichRegion, whichLocation)
            if check(whichRegion ~= nil, "region cannot be nil") then return false end
            if check(whichLocation ~= nil, "location cannot be nil") then return false end
            return IsPointInRegion(whichRegion, whichLocation[1], whichLocation[2])
        end

        ---@param whichUnit unit
        ---@param whichLocation FakeLocation
        ---@param distance number
        ---@return boolean
        function IsUnitInRangeLoc(whichUnit, whichLocation, distance)
            if check(whichUnit ~= nil, "unit cannot be nil") then return false end
            if check(whichLocation ~= nil, "location cannot be nil") then return false end
            if check(distance ~= nil, "distance cannot be nil") then return false end
            return IsUnitInRangeXY(whichUnit, whichLocation[1], whichLocation[2], distance)
        end

        ---@param whichUnit unit
        ---@param order string
        ---@param whichLocation FakeLocation
        ---@return boolean
        function IssuePointOrderLoc(whichUnit, order, whichLocation)
            if check(whichUnit ~= nil, "unit cannot be nil") then return false end
            if check(order ~= nil, "order cannot be nil") then return false end
            if check(whichLocation ~= nil, "location cannot be nil") then return false end
            return IssuePointOrder(whichUnit, order, whichLocation[1], whichLocation[2])
        end

        ---@param whichUnit unit
        ---@param order integer
        ---@param whichLocation FakeLocation
        ---@return boolean
        function IssuePointOrderByIdLoc(whichUnit, order, whichLocation)
            if check(whichUnit ~= nil, "unit cannot be nil") then return false end
            if check(order ~= nil, "order cannot be nil") then return false end
            if check(whichLocation ~= nil, "location cannot be nil") then return false end
            return IssuePointOrderById(whichUnit, order, whichLocation[1], whichLocation[2])
        end

        ---@param whichLocation FakeLocation
        ---@param whichPlayer player
        ---@return boolean
        function IsLocationVisibleToPlayer(whichLocation, whichPlayer)
            if check(whichLocation ~= nil, "location cannot be nil") then return false end
            if check(whichPlayer ~= nil, "player cannot be nil") then return false end
            return IsVisibleToPlayer(whichLocation[1], whichLocation[2], whichPlayer)
        end

        ---@param whichLocation FakeLocation
        ---@param whichPlayer player
        ---@return boolean
        function IsLocationFoggedToPlayer(whichLocation, whichPlayer)
            if check(whichLocation ~= nil, "location cannot be nil") then return false end
            if check(whichPlayer ~= nil, "player cannot be nil") then return false end
            return IsFoggedToPlayer(whichLocation[1], whichLocation[2], whichPlayer)
        end

        ---@param whichLocation FakeLocation
        ---@param whichPlayer player
        ---@return boolean
        function IsLocationMaskedToPlayer(whichLocation, whichPlayer)
            if check(whichLocation ~= nil, "location cannot be nil") then return false end
            if check(whichPlayer ~= nil, "player cannot be nil") then return false end
            return IsMaskedToPlayer(whichLocation[1], whichLocation[2], whichPlayer)
        end

        ---@param forWhichPlayer player
        ---@param whichState fogstate
        ---@param center FakeLocation
        ---@param radius number
        ---@param useSharedVision boolean
        ---@param afterUnits boolean
        ---@return fogmodifier
        function CreateFogModifierRadiusLoc(forWhichPlayer, whichState, center, radius, useSharedVision, afterUnits)
            if check(forWhichPlayer ~= nil, "player cannot be nil") then return nil end
            if check(whichState ~= nil, "fog state cannot be nil") then return nil end
            if check(center ~= nil, "center cannot be nil") then return nil end
            if check(radius ~= nil, "radius cannot be nil") then return nil end
            if check(useSharedVision ~= nil, "useSharedVision cannot be nil") then return nil end
            if check(afterUnits ~= nil, "afterUnits cannot be nil") then return nil end
            return CreateFogModifierRadius(forWhichPlayer, whichState, center[1], center[2], radius, useSharedVision,
                afterUnits)
        end

        ---@param modelName string
        ---@param where FakeLocation
        ---@return effect
        function AddSpecialEffectLoc(modelName, where)
            if check(modelName ~= nil, "modelName cannot be nil") then return nil end
            if check(where ~= nil, "location cannot be nil") then return nil end
            return AddSpecialEffect(modelName, where[1], where[2])
        end

        ---@param abilityString string
        ---@param t effecttype
        ---@param where FakeLocation
        ---@return effect
        function AddSpellEffectLoc(abilityString, t, where)
            if check(abilityString ~= nil, "abilityString cannot be nil") then return nil end
            if check(t ~= nil, "effect type cannot be nil") then return nil end
            if check(where ~= nil, "location cannot be nil") then return nil end
            return AddSpellEffect(abilityString, t, where[1], where[2])
        end

        ---@param abilityId integer
        ---@param t effecttype
        ---@param where FakeLocation
        ---@return effect
        function AddSpellEffectByIdLoc(abilityId, t, where)
            if check(abilityId ~= nil, "abilityId cannot be nil") then return nil end
            if check(t ~= nil, "effect type cannot be nil") then return nil end
            if check(where ~= nil, "location cannot be nil") then return nil end
            return AddSpellEffectById(abilityId, t, where[1], where[2])
        end

        ---@param effect effect
        ---@param loc FakeLocation
        function BlzSetSpecialEffectPositionLoc(effect, loc)
            if check(effect ~= nil, 'effect cannot be nil') then return end
            if check(loc ~= nil, 'loc cannot be nil') then return end
            local x, y = loc[1], loc[2]
            BlzSetSpecialEffectPosition(effect, x, y, GUI.getCoordZ(x, y))
        end

        ---@param whichPlayer player
        ---@param whichLocation FakeLocation
        ---@param radius number
        ---@param addBlight boolean
        function SetBlightLoc(whichPlayer, whichLocation, radius, addBlight)
            if check(whichPlayer ~= nil, "player cannot be nil") then return end
            if check(whichLocation ~= nil, "location cannot be nil") then return end
            if check(radius ~= nil, "radius cannot be nil") then return end
            if check(addBlight ~= nil, "addBlight cannot be nil") then return end
            SetBlight(whichPlayer, whichLocation[1], whichLocation[2], radius, addBlight)
        end

        ---@param whichStartLoc integer
        ---@param whichLocation FakeLocation
        function DefineStartLocationLoc(whichStartLoc, whichLocation)
            if check(whichStartLoc ~= nil, "start location cannot be nil") then return end
            if check(whichLocation ~= nil, "location cannot be nil") then return end
            DefineStartLocation(whichStartLoc, whichLocation[1], whichLocation[2])
        end

        ---@param id player
        ---@param unitid integer
        ---@param whichLocation FakeLocation
        ---@param face number
        ---@return unit
        function CreateUnitAtLoc(id, unitid, whichLocation, face)
            if check(id ~= nil, "player cannot be nil") then return nil end
            if check(unitid ~= nil, "unitId cannot be nil") then return nil end
            if check(whichLocation ~= nil, "location cannot be nil") then return nil end
            if check(face ~= nil, "facing angle be nil") then return nil end
            return CreateUnit(id, unitid, whichLocation[1], whichLocation[2], face)
        end

        ---@param id player
        ---@param unitname string
        ---@param whichLocation FakeLocation
        ---@param face number
        ---@return unit
        function CreateUnitAtLocByName(id, unitname, whichLocation, face)
            if check(id ~= nil, "player cannot be nil") then return nil end
            if check(unitname ~= nil, "unitname cannot be nil") then return nil end
            if check(whichLocation ~= nil, "location cannot be nil") then return nil end
            if check(face ~= nil, "facing angle be nil") then return nil end
            return CreateUnitByName(id, unitname, whichLocation[1], whichLocation[2], face)
        end

        ---@param whichUnit unit
        ---@param whichLocation FakeLocation
        function SetUnitPositionLoc(whichUnit, whichLocation)
            if check(whichUnit ~= nil, "unit cannot be nil") then return end
            if check(whichLocation ~= nil, "location cannot be nil") then return end
            SetUnitPosition(whichUnit, whichLocation[1], whichLocation[2])
        end

        ---@param whichHero unit
        ---@param loc FakeLocation
        ---@param doEyecandy boolean
        ---@return boolean
        function ReviveHeroLoc(whichHero, loc, doEyecandy)
            if check(whichHero ~= nil, "hero cannot be nil") then return false end
            if check(loc ~= nil, "location cannot be nil") then return false end
            if check(doEyecandy ~= nil, "doEyecandy be nil") then return false end
            return ReviveHero(whichHero, loc[1], loc[2], doEyecandy)
        end

        ---@param forWhichPlayer player
        ---@param whichState fogstate
        ---@param center FakeLocation
        ---@param radius number
        ---@param useSharedVision boolean
        function SetFogStateRadiusLoc(forWhichPlayer, whichState, center, radius, useSharedVision)
            if check(forWhichPlayer ~= nil, "player cannot be nil") then return end
            if check(whichState ~= nil, "fogstate cannot be nil") then return end
            if check(center ~= nil, "location be nil") then return end
            if check(radius ~= nil, "radius cannot be nil") then return end
            if check(useSharedVision ~= nil, "useSharedVision cannot be nil") then return end
            SetFogStateRadius(forWhichPlayer, whichState, center[1], center[2], radius, useSharedVision)
        end

        ---@param where FakeLocation
        ---@param red integer
        ---@param green integer
        ---@param blue integer
        ---@param pingPath string
        ---@param fogVisibility fogstate
        ---@return minimapicon
        function CreateMinimapIconAtLoc(where, red, green, blue, pingPath, fogVisibility)
            if check(where ~= nil, "location cannot be nil") then return nil end
            if check(red ~= nil, "red cannot be nil") then return nil end
            if check(green ~= nil, "green be nil") then return nil end
            if check(blue ~= nil, "blue cannot be nil") then return nil end
            if check(pingPath ~= nil, "pingPath cannot be nil") then return nil end
            if check(fogVisibility ~= nil, "fogstate cannot be nil") then return nil end
            return CreateMinimapIcon(where[1], where[2], red, green, blue, pingPath, fogVisibility)
        end
    end)
    OnInit.root("LIGUI_BoolexprOverride", function(require)
        ---@param func fun(): boolean
        ---@return conditionfunc|fun(): boolean
        function Condition(func)
            return func
        end

        ---@param func fun():boolean
        ---@return filterfunc|fun(): boolean
        function Filter(func)
            return func
        end

        ---@param boolexpr1 boolexpr|fun(): boolean
        ---@param boolexpr2 boolexpr|fun(): boolean
        ---@return boolexpr|fun(): boolean
        function And(boolexpr1, boolexpr2)
            return function()
                return boolexpr1() and boolexpr2()
            end
        end

        ---@param boolexpr1 boolexpr|fun(): boolean
        ---@param boolexpr2 boolexpr|fun(): boolean
        ---@return boolexpr|fun(): boolean
        function Or(boolexpr1, boolexpr2)
            return function()
                return boolexpr1() or boolexpr2()
            end
        end

        DestroyFilter = DoNothing
        DestroyCondition = DoNothing
        DestroyBoolExpr = DoNothing
    end)
    OnInit.root("LIGUI_RectOverride", function(require)
        ---@class FakeRect: FakedType
        ---@field [1] number minX
        ---@field [2] number minY
        ---@field [3] number maxX
        ---@field [4] number maxY

        local oldRect = Rect
        local oldWorld = GetWorldBounds
        local getMinX = GetRectMinX
        local getMinY = GetRectMinY
        local getMaxX = GetRectMaxX
        local getMaxY = GetRectMaxY
        local remover = RemoveRect

        ---@param minX number
        ---@param minY number
        ---@param maxX number
        ---@param maxY number
        ---@return FakeRect
        function Rect(minX, minY, maxX, maxY)
            if check(minX ~= nil, 'minX cannot be nil') then return { 0, 0, 0, 0, __faketype = "userdata" } end
            if check(minY ~= nil, 'minY cannot be nil') then return { 0, 0, 0, 0, __faketype = "userdata" } end
            if check(maxX ~= nil, 'maxX cannot be nil') then return { 0, 0, 0, 0, __faketype = "userdata" } end
            if check(maxY ~= nil, 'maxY cannot be nil') then return { 0, 0, 0, 0, __faketype = "userdata" } end
            return { minX, minY, maxX, maxY, __faketype = "userdata" }
        end

        RemoveRect = DoNothing

        local oldSetRect = SetRect
        ---@param rect FakeRect
        ---@param minX number
        ---@param minY number
        ---@param maxX number
        ---@param maxY number
        function SetRect(rect, minX, minY, maxX, maxY)
            if check(rect ~= nil, 'rect cannot be nil') then return end
            if check(minX ~= nil, 'minX cannot be nil') then return end
            if check(minY ~= nil, 'minY cannot be nil') then return end
            if check(maxX ~= nil, 'maxX cannot be nil') then return end
            if check(maxY ~= nil, 'maxY cannot be nil') then return end
            rect[1] = minX
            rect[2] = minY
            rect[3] = maxX
            rect[4] = maxY
        end

        local world ---@type FakeRect
        OnInit.main("LIGUI_WorldBounds", function(require)
            local w = oldWorld() --[[@as rect]]
            world = Rect(getMinX(w), getMinY(w), getMaxX(w), getMaxY(w))
            remover(w)
        end)
        ---@return FakeRect
        function GetWorldBounds()
            return Rect(world[1], world[2], world[3], world[4])
        end

        ---@param rect FakeRect
        ---@return number
        function GetRectMinX(rect)
            if check(rect ~= nil, 'rect cannot be nil') then return 0 end
            return rect[1]
        end

        ---@param rect FakeRect
        ---@return number
        function GetRectMinY(rect)
            if check(rect ~= nil, 'rect cannot be nil') then return 0 end
            return rect[2]
        end

        ---@param rect FakeRect
        ---@return number
        function GetRectMaxX(rect)
            if check(rect ~= nil, 'rect cannot be nil') then return 0 end
            return rect[3]
        end

        ---@param rect FakeRect
        ---@return number
        function GetRectMaxY(rect)
            if check(rect ~= nil, 'rect cannot be nil') then return 0 end
            return rect[4]
        end

        ---@param rect FakeRect
        ---@return number
        function GetRectCenterX(rect)
            if check(rect ~= nil, 'rect cannot be nil') then return 0 end
            return (rect[1] + rect[3]) / 2
        end

        ---@param rect FakeRect
        ---@return number
        function GetRectCenterY(rect)
            if check(rect ~= nil, 'rect cannot be nil') then return 0 end
            return (rect[2] + rect[4]) / 2
        end

        ---@param rect FakeRect
        ---@param x number
        ---@param y number
        function MoveRectTo(rect, x, y)
            if check(rect ~= nil, 'rect cannot be nil') then return end
            if check(x ~= nil, 'x cannot be nil') then return end
            if check(y ~= nil, 'y cannot be nil') then return end
            x = x - GetRectCenterX(rect)
            y = y - GetRectCenterY(rect)
            SetRect(rect, rect[1] + x, rect[2] + y, rect[3] + x, rect[4] + y)
        end

        local nativeRect ---@type rect
        OnInit.main("LIGUI_NativeRect", function(require)
            nativeRect = oldRect(0, 0, 0, 0) --[[@as rect]]
        end)
        ---@param rect FakeRect
        ---@return rect
        local function toNativeRect(rect)
            oldSetRect(nativeRect, rect[1], rect[2], rect[3], rect[4])
            return nativeRect
        end

        local nativeAddWeatherEffect = AddWeatherEffect
        ---@param where FakeRect
        ---@param effectID integer
        ---@return weathereffect
        function AddWeatherEffect(where, effectID)
            if check(where ~= nil, 'rect cannot be nil') then return nil end
            if check(effectID ~= nil, 'effectID cannot be nil') then return nil end
            return nativeAddWeatherEffect(toNativeRect(where), effectID)
        end

        local nativeSetDoodadAnimationRect = SetDoodadAnimationRect
        ---@param r FakeRect
        ---@param doodadID integer
        ---@param animName string
        ---@param animRandom boolean
        function SetDoodadAnimationRect(r, doodadID, animName, animRandom)
            if check(r ~= nil, 'rect cannot be nil') then return nil end
            if check(doodadID ~= nil, 'doodadID cannot be nil') then return end
            if check(animName ~= nil, 'animationName cannot be nil') then return end
            if check(animRandom ~= nil, 'animRandom cannot be nil') then return end
            nativeSetDoodadAnimationRect(toNativeRect(r), doodadID, animName, animRandom)
        end

        local nativeRegionAddRect = RegionAddRect
        ---@param whichRegion region
        ---@param r FakeRect
        function RegionAddRect(whichRegion, r)
            if check(whichRegion ~= nil, 'region cannot be nil') then return end
            if check(r ~= nil, 'rect cannot be nil') then return end
            nativeRegionAddRect(whichRegion, toNativeRect(r))
        end

        local nativeRegionClearRect = RegionClearRect
        ---@param whichRegion region
        ---@param r FakeRect
        function RegionClearRect(whichRegion, r)
            if check(whichRegion ~= nil, 'region cannot be nil') then return end
            if check(r ~= nil, 'rect cannot be nil') then return end
            nativeRegionClearRect(whichRegion, toNativeRect(r))
        end

        local nativeSetBlightRect = SetBlightRect
        ---@param whichPlayer player
        ---@param r FakeRect
        ---@param addBlight boolean
        function SetBlightRect(whichPlayer, r, addBlight)
            if check(whichPlayer ~= nil, 'player cannot be nil') then return end
            if check(r ~= nil, 'rect cannot be nil') then return end
            if check(addBlight ~= nil, 'addBlight cannot be nil') then return end
            nativeSetBlightRect(whichPlayer, toNativeRect(r), addBlight)
        end

        local nativeSetFogStateRect = SetFogStateRect
        ---@param forWhichPlayer player
        ---@param whichState fogstate
        ---@param where FakeRect
        ---@param useSharedVision boolean
        function SetFogStateRect(forWhichPlayer, whichState, where, useSharedVision)
            if check(forWhichPlayer ~= nil, 'player cannot be nil') then return end
            if check(whichState ~= nil, 'fogstate cannot be nil') then return end
            if check(where ~= nil, 'rect cannot be nil') then return end
            if check(useSharedVision ~= nil, 'useSharedVision cannot be nil') then return end
            nativeSetFogStateRect(forWhichPlayer, whichState, toNativeRect(where), useSharedVision)
        end

        local nativeCreateFogModifierRect = CreateFogModifierRect
        ---@param forWhichPlayer player
        ---@param whichState fogstate
        ---@param where FakeRect
        ---@param useSharedVision boolean
        ---@param afterUnits boolean
        ---@return fogmodifier
        function CreateFogModifierRect(forWhichPlayer, whichState, where, useSharedVision, afterUnits)
            if check(forWhichPlayer ~= nil, 'player cannot be nil') then return nil end
            if check(whichState ~= nil, 'fogstate cannot be nil') then return nil end
            if check(where ~= nil, 'rect cannot be nil') then return nil end
            if check(useSharedVision ~= nil, 'useSharedVision cannot be nil') then return nil end
            if check(afterUnits ~= nil, 'afterUnits cannot be nil') then return nil end
            return nativeCreateFogModifierRect(forWhichPlayer, whichState, toNativeRect(where), useSharedVision,
                afterUnits)
        end

        ---@class LIGUI_RectOverrideAPI
        local rectOverrideAPI = {
            toNativeRect = toNativeRect
        }
        return rectOverrideAPI
    end)
    OnInit.root("LIGUI_ForceOverride", function(require)
        local threadDataAPI = require "LIGUI_ThreadData" --[[@as LIGUI_ThreadDataAPI]]
        local coroutineAPI = require "LIGUI_Coroutines" --[[@as LIGUI_CoroutineAPI]]
        local setupThreadData = threadDataAPI.setupThreadData
        local getThreadData = threadDataAPI.getThreadData
        local threadsAllDone = coroutineAPI.threadsAllDone

        ---@class FakeForce: FakedType
        ---@field [integer] player
        ---@field indexOf {[player]: integer}

        local oldForce = CreateForce
        local oldClear = ForceClear
        local oldCripple = CripplePlayer
        local oldAdd = ForceAddPlayer

        ---@return FakeForce
        function CreateForce()
            return { indexOf = {}, __faketype = "userdata" }
        end

        DestroyForce = DoNothing

        ---@param force FakeForce
        function ForceClear(force)
            if check(force ~= nil, 'force cannot be nil') then return end
            for i, val in ipairs(force) do
                force.indexOf[val] = nil
                force[i] = nil
            end
        end

        ---@param force FakeForce
        ---@param player player
        function ForceAddPlayer(force, player)
            if check(force ~= nil, 'force cannot be nil') then return end
            if check(player ~= nil, 'player cannot be nil') then return end
            if force.indexOf[player] then return end

            local pos = #force + 1
            force.indexOf[player] = pos
            force[pos] = player
        end

        ---@param force FakeForce
        ---@param player player
        function ForceRemovePlayer(force, player)
            if check(force ~= nil, 'force cannot be nil') then return end
            if check(player ~= nil, 'player cannot be nil') then return end
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
            if check(force ~= nil, 'force cannot be nil') then return false end
            if check(player ~= nil, 'player cannot be nil') then return false end
            return force.indexOf[player] and true or false
        end

        ---@param player player
        ---@param force FakeForce
        ---@return boolean
        function IsPlayerInForce(player, force)
            if check(player ~= nil, 'player cannot be nil') then return false end
            if check(force ~= nil, 'force cannot be nil') then return false end
            return force.indexOf[player] and true or false
        end

        ---@param unit unit
        ---@param force FakeForce
        ---@return boolean
        function IsUnitInForce(unit, force)
            if check(unit ~= nil, 'unit cannot be nil') then return false end
            if check(force ~= nil, 'force cannot be nil') then return false end
            return force.indexOf[GetOwningPlayer(unit)] and true or false
        end

        local mainForce ---@type force
        OnInit.main("LIGUI_NativeForce", function(require)
            mainForce = oldForce() --[[@as force]]
        end)
        ---@param player player
        ---@param force FakeForce
        ---@param flag boolean
        function GUI.cripplePlayer(player, force, flag)
            oldClear(mainForce --[[@as force]])
            for _, val in ipairs(force) do
                oldAdd(mainForce --[[@as force]], val)
            end
            oldCripple(player, mainForce --[[@ as force]], flag)
        end

        ---@param player player
        ---@param force FakeForce
        ---@param flag boolean
        function CripplePlayer(player, force, flag)
            if check(player ~= nil, 'player cannot be nil') then return end
            if check(force ~= nil, 'force cannot be nil') then return end
            GUI.cripplePlayer(player, force, flag)
        end

        local oldForForce = ForForce
        local oldEnumPlayer = GetEnumPlayer

        ---@param force FakeForce
        ---@param code fun(p: player)
        ---@param waitOnSleep boolean?
        function GUI.forForce(force, code, waitOnSleep)
            if check(force ~= nil, 'force cannot be nil') then return end
            if check(code ~= nil, 'code cannot be nil') then return end
            local i = 1
            local player
            local parentThread = coroutine.running()
            if waitOnSleep then
                local threads = {} ---@type thread[]
                local threadData = {} ---@type table<thread, table>
                while i <= #force do
                    player = force[i]
                    local codeThread = coroutine.create(code)
                    table.insert(threads, codeThread)
                    local data = setupThreadData(codeThread, parentThread)
                    threadData[codeThread] = data
                    coroutine.resume(codeThread, player)
                    if force.indexOf[player] then
                        i = i + 1
                    end
                end
                if not threadsAllDone(threads) then
                    local function polledWaitCallback()
                        if threadsAllDone(threads) then
                            coroutine.resume(parentThread)
                        end
                    end
                    for _, thread in ipairs(threads) do
                        rawset(threadData[thread], "forkJoinCallback", polledWaitCallback)
                    end
                    coroutine.yield()
                end
            else
                while i <= #force do
                    player = force[i]
                    local codeThread = coroutine.create(code)
                    setupThreadData(codeThread, parentThread)
                    coroutine.resume(codeThread, player)
                    if force.indexOf[player] then
                        i = i + 1
                    end
                end
            end
        end

        function ForForce(force, code)
            if check(force ~= nil, 'force cannot be nil') then return end
            if check(code ~= nil, 'code cannot be nil') then return end
            local waitOnSleep = GUI.waitOnSleep
            GUI.waitOnSleep = false
            GUI.forForce(force, function(player)
                rawset(getThreadData(coroutine.running()), "GetEnumPlayer", player)
                code()
            end, waitOnSleep)
        end

        ---@class LIGUI_ForceOverrideAPI
        local forceOverrideAPI = {
            getMainForce = function() -- getter due to different init timings
                return mainForce
            end,
            oldForForce = oldForForce,
            oldEnumPlayer = oldEnumPlayer
        }
        return forceOverrideAPI
    end)
    OnInit.root("LIGUI_GroupOverride", function(require)
        local threadDataAPI = require "LIGUI_ThreadData" --[[@as LIGUI_ThreadDataAPI]]
        local coroutineAPI = require "LIGUI_Coroutines" --[[@as LIGUI_CoroutineAPI]]
        local groupsAPI = require "LIGUI_Groups" --[[@as LIGUI_GroupsAPI]]
        local setupThreadData = threadDataAPI.setupThreadData
        local getThreadData = threadDataAPI.getThreadData
        local threadsAllDone = coroutineAPI.threadsAllDone
        local groupDBRegisterUnitInGroup = groupsAPI.groupDBRegisterUnitInGroup
        local groupDBDeregisterUnitFromGroup = groupsAPI.groupDBDeregisterUnitFromGroup
        local groupDBDeregisterGroupSimple = groupsAPI.groupDBDeregisterGroupSimple
        local groupDBDeregisterGroup = groupsAPI.groupDBDeregisterGroup

        local nativeCreateGroup = CreateGroup
        local nativeDestroyGroup = DestroyGroup
        local oldGroupClear = GroupClear --[[@as fun(group: group)]]
        local oldGroupAddUnit = GroupAddUnit --[[@as fun(group: group, unit: unit)]]
        local oldUnitAt = BlzGroupUnitAt
        local oldGetSize = BlzGroupGetSize

        local mainGroup = bj_lastCreatedGroup --[[@as group]]
        local issueGroup ---@type group
        do
            local oldGroup1 = bj_suspendDecayFleshGroup
            local oldGroup2 = bj_suspendDecayBoneGroup
            OnInit.main("LIGUI_NativeGroups", function(require)
                nativeDestroyGroup(oldGroup1 --[[@as group]])
                nativeDestroyGroup(oldGroup2 --[[@as group]])
                issueGroup = nativeCreateGroup() --[[@as group]]
            end)
        end

        ---@class FakeGroup: FakedType, group
        ---@field [integer] unit
        ---@field indexOf {[unit]: integer}

        ---@return FakeGroup
        function CreateGroup()
            return { indexOf = {}, __faketype = "userdata" }
        end

        DestroyGroup = DoNothing

        ---@param group FakeGroup
        ---@param unit unit
        function GroupAddUnit(group, unit)
            if check(group ~= nil, 'group cannot be nil') then return end
            if check(unit ~= nil, 'unit cannot be nil') then return end

            if group.indexOf[unit] then return end
            groupDBRegisterUnitInGroup(group, unit)
        end

        ---@param group FakeGroup
        ---@param unit unit
        function GroupRemoveUnit(group, unit)
            if check(group ~= nil, 'group cannot be nil') then return end
            if check(unit ~= nil, 'unit cannot be nil') then return end
            groupDBDeregisterUnitFromGroup(group, unit)
            if #group == 0 then groupDBDeregisterGroupSimple(group) end
        end

        ---@param group FakeGroup
        function GroupClear(group)
            if check(group ~= nil, 'group cannot be nil') then return end
            groupDBDeregisterGroup(group)
        end

        ---@param unit unit
        ---@param group FakeGroup
        ---@return boolean
        function IsUnitInGroup(unit, group)
            if check(unit ~= nil, 'unit cannot be nil') then return false end
            if check(group ~= nil, 'group cannot be nil') then return false end
            return group.indexOf[unit] and true or false
        end

        ---@param group FakeGroup
        ---@return unit|nil
        function FirstOfGroup(group)
            if check(group ~= nil, 'group cannot be nil') then return end
            return group[1]
        end

        ---@param group FakeGroup
        ---@param index integer
        ---@return unit|nil
        function BlzGroupUnitAt(group, index)
            if check(group ~= nil, 'group cannot be nil') then return nil end
            if check(index ~= nil, 'index cannot be nil') then return nil end
            return group[index + 1]
        end

        ---@param group FakeGroup
        ---@return integer
        function BlzGroupGetSize(group)
            if check(group ~= nil, 'group cannot be nil') then return 0 end
            return #group
        end

        ---@param group FakeGroup
        ---@return group
        local function toNativeGroup(group)
            oldGroupClear(issueGroup)
            for _, unit in ipairs(group) do
                oldGroupAddUnit(issueGroup, unit)
            end
            return issueGroup
        end

        local nativeGroupImmediateOrder = GroupImmediateOrder
        ---@param whichGroup FakeGroup
        ---@param order string
        ---@return boolean
        function GroupImmediateOrder(whichGroup, order)
            if check(whichGroup ~= nil, 'group cannot be nil') then return false end
            if check(order ~= nil, 'order cannot be nil') then return false end
            return nativeGroupImmediateOrder(toNativeGroup(whichGroup), order)
        end

        local nativeGroupImmediateOrderById = GroupImmediateOrderById
        ---@param whichGroup FakeGroup
        ---@param order integer
        ---@return boolean
        function GroupImmediateOrderById(whichGroup, order)
            if check(whichGroup ~= nil, 'group cannot be nil') then return false end
            if check(order ~= nil, 'order cannot be nil') then return false end
            return nativeGroupImmediateOrderById(toNativeGroup(whichGroup), order)
        end

        local nativeGroupPointOrder = GroupPointOrder
        ---@param whichGroup FakeGroup
        ---@param order string
        ---@param x number
        ---@param y number
        ---@return boolean
        function GroupPointOrder(whichGroup, order, x, y)
            if check(whichGroup ~= nil, 'group cannot be nil') then return false end
            if check(order ~= nil, 'order cannot be nil') then return false end
            if check(x ~= nil, 'x cannot be nil') then return false end
            if check(y ~= nil, 'y cannot be nil') then return false end
            return nativeGroupPointOrder(toNativeGroup(whichGroup), order, x, y)
        end

        local nativeGroupPointOrderById = GroupPointOrderById
        ---@param whichGroup FakeGroup
        ---@param order integer
        ---@param x number
        ---@param y number
        ---@return boolean
        function GroupPointOrderById(whichGroup, order, x, y)
            if check(whichGroup ~= nil, 'group cannot be nil') then return false end
            if check(order ~= nil, 'order cannot be nil') then return false end
            if check(x ~= nil, 'x cannot be nil') then return false end
            if check(y ~= nil, 'y cannot be nil') then return false end
            return nativeGroupPointOrderById(toNativeGroup(whichGroup), order, x, y)
        end

        local nativeGroupTargetOrder = GroupTargetOrder
        ---@param whichGroup FakeGroup
        ---@param order string
        ---@param targetWidget widget
        ---@return boolean
        function GroupTargetOrder(whichGroup, order, targetWidget)
            if check(whichGroup ~= nil, 'group cannot be nil') then return false end
            if check(order ~= nil, 'order cannot be nil') then return false end
            if check(targetWidget ~= nil, 'targetWidget cannot be nil') then return false end
            return nativeGroupTargetOrder(toNativeGroup(whichGroup), order, targetWidget)
        end

        local nativeGroupTargetOrderById = GroupTargetOrderById
        ---@param whichGroup FakeGroup
        ---@param order integer
        ---@param targetWidget widget
        ---@return boolean
        function GroupTargetOrderById(whichGroup, order, targetWidget)
            if check(whichGroup ~= nil, 'group cannot be nil') then return false end
            if check(order ~= nil, 'order cannot be nil') then return false end
            if check(targetWidget ~= nil, 'targetWidget cannot be nil') then return false end
            return nativeGroupTargetOrderById(toNativeGroup(whichGroup), order, targetWidget)
        end

        ---@param group FakeGroup
        ---@param code fun(u: unit)
        ---@param waitOnSleep boolean?
        function GUI.forGroup(group, code, waitOnSleep)
            if check(group ~= nil, 'group cannot be nil') then return end
            if check(code ~= nil, 'code cannot be nil') then return end
            local i = 1
            local unit
            local parentThread = coroutine.running()
            if waitOnSleep then
                local threads = {} ---@type thread[]
                local threadData = {} ---@type table<thread, table>
                while i <= #group do
                    unit = group[i]
                    local codeThread = coroutine.create(code)
                    table.insert(threads, codeThread)
                    local data = setupThreadData(codeThread, parentThread)
                    threadData[codeThread] = data
                    coroutine.resume(codeThread, unit)
                    if group.indexOf[unit] then
                        i = i + 1
                    end
                end
                if not threadsAllDone(threads) then
                    local function polledWaitCallback()
                        if threadsAllDone(threads) then
                            coroutine.resume(parentThread)
                        end
                    end
                    for _, thread in ipairs(threads) do
                        rawset(threadData[thread], "forkJoinCallback", polledWaitCallback)
                    end
                    coroutine.yield()
                end
            else
                while i <= #group do
                    unit = group[i]
                    local codeThread = coroutine.create(code)
                    setupThreadData(codeThread, parentThread)
                    coroutine.resume(codeThread, unit)
                    if group.indexOf[unit] then
                        i = i + 1
                    end
                end
            end
        end

        ---@param group FakeGroup
        ---@param code function
        function ForGroup(group, code)
            if check(group ~= nil, 'group cannot be nil') then return end
            if check(code ~= nil, 'code cannot be nil') then return end
            local waitOnSleep = GUI.waitOnSleep
            GUI.waitOnSleep = false
            GUI.forGroup(group, function(unit)
                rawset(getThreadData(coroutine.running()), "GetEnumUnit", unit)
                code()
            end, waitOnSleep)
        end

        ---@class LIGUI_GroupOverrideAPI
        local groupOverrideAPI = {
            mainGroup = mainGroup,
            oldGetSize = oldGetSize,
            oldUnitAt = oldUnitAt,
            toNativeGroup = toNativeGroup,
            nativeGroupPointOrder = nativeGroupPointOrder,
            nativeGroupPointOrderById = nativeGroupPointOrderById
        }
        return groupOverrideAPI
    end)
    OnInit.root("LIGUI_UnitPoolOverride", function(require)
        require "LIGUI_FakeType"
        local randomPool = require "LIGUI_RandomPool" --[[@as LIGUI_RandomPool]]

        ---@class FakeUnitPool: LIGUI_RandomPool<integer>, FakedType

        ---@return FakeUnitPool
        function CreateUnitPool()
            return setmetatable({ __faketype = "userdata" }, randomPool) --[[@as FakeUnitPool]]
        end

        DestroyUnitPool = nil

        UnitPoolAddUnitType = randomPool
            .addObject ---@type fun(whichPool: FakeUnitPool, unitId: integer, weight: number)
        UnitPoolRemoveUnitType = randomPool.removeObject ---@type fun(whichPool: FakeUnitPool, unitId: integer)

        ---@param whichPool FakeUnitPool
        ---@param forWhichPlayer player
        ---@param x number
        ---@param y number
        ---@param facing number
        ---@return unit
        function PlaceRandomUnit(whichPool, forWhichPlayer, x, y, facing)
            local unitId = whichPool:getRandomObj()
            if not unitId then return nil end
            return CreateUnit(forWhichPlayer, unitId, x, y, facing)
        end
    end)
    OnInit.root("LIGUI_ItemPoolOverride", function(require)
        require "LIGUI_FakeType"
        local randomPool = require "LIGUI_RandomPool" --[[@as LIGUI_RandomPool]]

        ---@class FakeItemPool: LIGUI_RandomPool<integer>, FakedType

        ---@return FakeItemPool
        function CreateItemPool()
            return setmetatable({ __faketype = "userdata" }, randomPool) --[[@as FakeItemPool]]
        end

        DestroyItemPool = nil

        ItemPoolAddItemType = randomPool
            .addObject ---@type fun(whichPool: FakeItemPool, unitId: integer, weight: number)
        ItemPoolRemoveItemType = randomPool.removeObject ---@type fun(whichPool: FakeItemPool, unitId: integer)

        ---@param whichPool FakeItemPool
        ---@param x number
        ---@param y number
        ---@return item
        function PlaceRandomItem(whichPool, x, y)
            local itemId = whichPool:getRandomObj()
            if not itemId then return nil end
            return CreateItem(itemId, x, y)
        end
    end)
    OnInit.root("LIGUI_ComboOverrides", function(require)
        local threadDataAPI = require "LIGUI_ThreadData" --[[@as LIGUI_ThreadDataAPI]]
        local setupThreadData = threadDataAPI.setupThreadData

        require "LIGUI_LocationOverride"

        local boolexprAPI = require "LIGUI_Boolexprs" --[[@as LIGUI_BoolexprAPI]]

        local rectAPI = require "LIGUI_RectOverride" --[[@as LIGUI_RectOverrideAPI]]
        local toNativeRect = rectAPI.toNativeRect

        local groupOverrideAPI = require "LIGUI_GroupOverride" --[[@as LIGUI_GroupOverrideAPI]]
        local forceOverrideAPI = require "LIGUI_ForceOverride" --[[@as LIGUI_ForceOverrideAPI]]

        do -- Group + (Rect or Location) + Boolexpr
            local mainGroup = groupOverrideAPI.mainGroup
            local oldGetSize = groupOverrideAPI.oldGetSize
            local oldUnitAt = groupOverrideAPI.oldUnitAt
            local toNativeGroup = groupOverrideAPI.toNativeGroup
            local wrapUnitFilter = boolexprAPI.wrapUnitFilter

            ---@param sourceGroup group
            ---@param outputGroup FakeGroup
            local function toFakeGroup(sourceGroup, outputGroup)
                local size = oldGetSize(sourceGroup) - 1
                GroupClear(outputGroup)
                for i = 0, size do
                    GroupAddUnit(outputGroup, oldUnitAt(sourceGroup, i) --[[@as unit should be fine]])
                end
            end

            local oldGroupEnumUnitsOfType = GroupEnumUnitsOfType
            ---@param whichGroup FakeGroup
            ---@param unitName string
            ---@param filter? boolexpr|fun():boolean
            function GroupEnumUnitsOfType(whichGroup, unitName, filter)
                if check(whichGroup ~= nil, "group cannot be nil") then return end
                if check(unitName ~= nil, "unitName cannot be nil") then return end
                oldGroupEnumUnitsOfType(mainGroup, unitName, wrapUnitFilter(filter))
                toFakeGroup(mainGroup, whichGroup)
            end

            local oldGroupEnumUnitsOfPlayer = GroupEnumUnitsOfPlayer
            ---@param whichGroup FakeGroup
            ---@param whichPlayer player
            ---@param filter? boolexpr|fun(): boolean
            function GroupEnumUnitsOfPlayer(whichGroup, whichPlayer, filter)
                if check(whichGroup ~= nil, "group cannot be nil") then return end
                if check(whichPlayer ~= nil, "player cannot be nil") then return end
                oldGroupEnumUnitsOfPlayer(mainGroup, whichPlayer, wrapUnitFilter(filter))
                toFakeGroup(mainGroup, whichGroup)
            end

            local oldGroupEnumUnitsOfTypeCounted = GroupEnumUnitsOfTypeCounted
            ---@param whichGroup FakeGroup
            ---@param unitName string
            ---@param filter? boolexpr|fun(): boolean
            ---@param countLimit integer
            function GroupEnumUnitsOfTypeCounted(whichGroup, unitName, filter, countLimit)
                if check(whichGroup ~= nil, "group cannot be nil") then return end
                if check(unitName ~= nil, "unitName cannot be nil") then return end
                if check(countLimit ~= nil, "countLimit cannot be nil") then return end
                oldGroupEnumUnitsOfTypeCounted(mainGroup, unitName, wrapUnitFilter(filter), countLimit)
                toFakeGroup(mainGroup, whichGroup)
            end

            local oldGroupEnumUnitsInRect = GroupEnumUnitsInRect
            ---@param whichGroup FakeGroup
            ---@param r FakeRect
            ---@param filter? boolexpr|fun(): boolean
            function GroupEnumUnitsInRect(whichGroup, r, filter)
                if check(whichGroup ~= nil, "group cannot be nil") then return end
                if check(r ~= nil, "rect cannot be nil") then return end
                oldGroupEnumUnitsInRect(mainGroup, toNativeRect(r), wrapUnitFilter(filter))
                toFakeGroup(mainGroup, whichGroup)
            end

            local oldGroupEnumUnitsInRectCounted = GroupEnumUnitsInRectCounted
            ---@param whichGroup FakeGroup
            ---@param r FakeRect
            ---@param filter? boolexpr|fun(): boolean
            ---@param countLimit integer
            function GroupEnumUnitsInRectCounted(whichGroup, r, filter, countLimit)
                if check(whichGroup ~= nil, "group cannot be nil") then return end
                if check(r ~= nil, "rect cannot be nil") then return end
                if check(countLimit ~= nil, "countLimit cannot be nil") then return end
                oldGroupEnumUnitsInRectCounted(mainGroup, toNativeRect(r), wrapUnitFilter(filter), countLimit)
                toFakeGroup(mainGroup, whichGroup)
            end

            local oldGroupEnumUnitsInRange = GroupEnumUnitsInRange
            ---@param whichGroup FakeGroup
            ---@param x number
            ---@param y number
            ---@param radius number
            ---@param filter? boolexpr|fun():boolean
            function GroupEnumUnitsInRange(whichGroup, x, y, radius, filter)
                if check(whichGroup ~= nil, "group cannot be nil") then return end
                if check(x ~= nil, "x cannot be nil") then return end
                if check(y ~= nil, "y cannot be nil") then return end
                if check(radius ~= nil, "radius cannot be nil") then return end
                oldGroupEnumUnitsInRange(mainGroup, x, y, radius, wrapUnitFilter(filter))
                toFakeGroup(mainGroup, whichGroup)
            end

            ---@param whichGroup FakeGroup
            ---@param whichLocation FakeLocation
            ---@param radius number
            ---@param filter? boolexpr|fun(): boolean
            function GroupEnumUnitsInRangeOfLoc(whichGroup, whichLocation, radius, filter)
                if check(whichGroup ~= nil, "group cannot be nil") then return end
                if check(whichLocation ~= nil, "location cannot be nil") then return end
                if check(radius ~= nil, "radius cannot be nil") then return end
                oldGroupEnumUnitsInRange(mainGroup, whichLocation[1], whichLocation[2], radius, wrapUnitFilter(filter))
                toFakeGroup(mainGroup, whichGroup)
            end

            local oldGroupEnumUnitsInRangeCounted = GroupEnumUnitsInRangeCounted
            ---@param whichGroup FakeGroup
            ---@param x number
            ---@param y number
            ---@param radius number
            ---@param filter? boolexpr|fun(): boolean
            ---@param countLimit integer
            function GroupEnumUnitsInRangeCounted(whichGroup, x, y, radius, filter, countLimit)
                if check(whichGroup ~= nil, "group cannot be nil") then return end
                if check(x ~= nil, "x cannot be nil") then return end
                if check(y ~= nil, "y cannot be nil") then return end
                if check(radius ~= nil, "radius cannot be nil") then return end
                if check(countLimit ~= nil, "countLimit cannot be nil") then return end
                oldGroupEnumUnitsInRangeCounted(mainGroup, x, y, radius, wrapUnitFilter(filter), countLimit)
                toFakeGroup(mainGroup, whichGroup)
            end

            ---@param whichGroup FakeGroup
            ---@param whichLocation FakeLocation
            ---@param radius number
            ---@param filter? boolexpr|fun(): boolean
            ---@param countLimit integer
            function GroupEnumUnitsInRangeOfLocCounted(whichGroup, whichLocation, radius, filter, countLimit)
                if check(whichGroup ~= nil, "group cannot be nil") then return end
                if check(whichLocation ~= nil, "location cannot be nil") then return end
                if check(radius ~= nil, "radius cannot be nil") then return end
                if check(countLimit ~= nil, "countLimit cannot be nil") then return end
                oldGroupEnumUnitsInRangeCounted(mainGroup, whichLocation[1], whichLocation[2], radius,
                    wrapUnitFilter(filter), countLimit)
                toFakeGroup(mainGroup, whichGroup)
            end

            local oldGroupEnumUnitsSelected = GroupEnumUnitsSelected
            ---@param whichGroup FakeGroup
            ---@param whichPlayer player
            ---@param filter? boolexpr|fun(): boolean
            function GroupEnumUnitsSelected(whichGroup, whichPlayer, filter)
                if check(whichGroup ~= nil, "group cannot be nil") then return end
                if check(whichPlayer ~= nil, "player cannot be nil") then return end
                oldGroupEnumUnitsSelected(mainGroup, whichPlayer, wrapUnitFilter(filter))
                toFakeGroup(mainGroup, whichGroup)
            end

            local oldGroupPointOrder = groupOverrideAPI.nativeGroupPointOrder
            ---@param whichGroup FakeGroup
            ---@param order string
            ---@param whichLocation FakeLocation
            ---@return boolean
            function GroupPointOrderLoc(whichGroup, order, whichLocation)
                if check(whichGroup ~= nil, "group cannot be nil") then return false end
                if check(order ~= nil, "order cannot be nil") then return false end
                if check(whichLocation ~= nil, 'location cannot be nil') then return false end
                return oldGroupPointOrder(toNativeGroup(whichGroup), order, whichLocation[1], whichLocation[2])
            end

            local oldGroupPointOrderById = groupOverrideAPI.nativeGroupPointOrderById
            ---@param whichGroup FakeGroup
            ---@param order integer
            ---@param whichLocation FakeLocation
            ---@return boolean
            function GroupPointOrderByIdLoc(whichGroup, order, whichLocation)
                if check(whichGroup ~= nil, "group cannot be nil") then return false end
                if check(order ~= nil, "order cannot be nil") then return false end
                if check(whichLocation ~= nil, 'location cannot be nil') then return false end
                return oldGroupPointOrderById(toNativeGroup(whichGroup), order, whichLocation[1], whichLocation[2])
            end
        end

        do -- Rect + Location
            ---@param whichRect FakeRect
            ---@param newCenterLoc FakeLocation
            function MoveRectToLoc(whichRect, newCenterLoc)
                if check(whichRect ~= nil, 'rect cannot be nil') then return end
                if check(newCenterLoc ~= nil, 'centerLoc cannot be nil') then return end
                local x = newCenterLoc[1] - GetRectCenterX(whichRect)
                local y = newCenterLoc[2] - GetRectCenterY(whichRect)
                SetRect(whichRect, whichRect[1] + x, whichRect[2] + y, whichRect[3] + x, whichRect[4] + y)
            end

            ---@param min FakeLocation
            ---@param max FakeLocation
            ---@return FakeRect newRect
            function RectFromLoc(min, max)
                if check(min ~= nil, 'min cannot be nil') then return nil end
                if check(max ~= nil, 'max cannot be nil') then return nil end
                return Rect(min[1], min[2], max[1], max[2]) --[[@as FakeRect]]
            end

            ---@param whichRect FakeRect
            ---@param min FakeLocation
            ---@param max FakeLocation
            function SetRectFromLoc(whichRect, min, max)
                if check(min ~= nil, 'min cannot be nil') then return end
                if check(max ~= nil, 'max cannot be nil') then return end
                SetRect(whichRect, min[1], min[2], max[1], max[2])
            end
        end

        do -- Rect + Boolexpr
            local toNativeFilter = boolexprAPI.toNativeFilter

            local oldGetFilterDestructable = GetFilterDestructable
            local oldGetEnumDestructable = GetEnumDestructable
            local oldEnumDestructablesInRect = EnumDestructablesInRect
            ---@param r FakeRect
            ---@param filter? boolexpr|fun():boolean
            ---@param actionFunc fun()
            function EnumDestructablesInRect(r, filter, actionFunc)
                if not filter and not actionFunc then return end
                local filterFunc ---@type filterfunc?
                if filter then
                    filterFunc = toNativeFilter(filter --[[@as fun(): boolean]], oldGetFilterDestructable,
                        "GetFilterDestructable")
                else
                    filterFunc = nil
                end

                local callback
                if actionFunc then
                    callback = function()
                        local parentThread = coroutine.running()
                        return function()
                            local thisThread = coroutine.running()
                            local data = setupThreadData(thisThread, parentThread)
                            rawset(data, "GetEnumDestructable", oldGetEnumDestructable())
                            return actionFunc()
                        end
                    end
                else
                    callback = nil
                end

                oldEnumDestructablesInRect(toNativeRect(r), filterFunc, callback)
            end

            local oldEnumItemsInRect = EnumItemsInRect
            local oldGetFilterItem = GetFilterItem
            local oldGetEnumItem = GetEnumItem
            ---@param r FakeRect
            ---@param filter? boolexpr|fun():boolean
            ---@param actionFunc fun()
            function EnumItemsInRect(r, filter, actionFunc)
                if not filter and not actionFunc then return end
                local filterFunc ---@type filterfunc?
                if filter then
                    filterFunc = toNativeFilter(filter --[[@as fun(): boolean]], oldGetFilterItem, "GetFilterItem")
                else
                    filterFunc = nil
                end

                local callback
                if actionFunc then
                    callback = function()
                        local parentThread = coroutine.running()
                        return function()
                            local thisThread = coroutine.running()
                            local data = setupThreadData(thisThread, parentThread)
                            rawset(data, "GetEnumItem", oldGetEnumItem())
                            return actionFunc()
                        end
                    end
                else
                    callback = nil
                end

                oldEnumItemsInRect(toNativeRect(r), filterFunc, callback)
            end
        end

        do -- Player + Boolexpr
            local getMainForce = forceOverrideAPI.getMainForce
            local wrapPlayerFilter = boolexprAPI.wrapPlayerFilter
            local oldForForce = forceOverrideAPI.oldForForce
            local oldEnumPlayer = forceOverrideAPI.oldEnumPlayer

            ---@param force FakeForce
            local function funnelEnum(force)
                if check(force ~= nil, 'force cannot be nil') then return end
                local mainForce = getMainForce()
                ForceClear(force)
                oldForForce(mainForce, function()
                    ForceAddPlayer(force, oldEnumPlayer())
                end)
            end

            local oldForceEnumPlayers = ForceEnumPlayers
            ---@param whichForce FakeForce
            ---@param filter? boolexpr|fun():boolean
            function ForceEnumPlayers(whichForce, filter)
                oldForceEnumPlayers(getMainForce(), wrapPlayerFilter(filter))
                funnelEnum(whichForce)
            end

            local oldForceEnumPlayersCounted = ForceEnumPlayersCounted
            ---@param whichForce FakeForce
            ---@param filter? boolexpr|fun():boolean
            ---@param countLimit integer
            function ForceEnumPlayersCounted(whichForce, filter, countLimit)
                oldForceEnumPlayersCounted(getMainForce(), wrapPlayerFilter(filter), countLimit)
                funnelEnum(whichForce)
            end

            local oldForceEnumAllies = ForceEnumAllies
            ---@param whichForce FakeForce
            ---@param filter? boolexpr|fun():boolean
            function ForceEnumAllies(whichForce, filter)
                oldForceEnumAllies(getMainForce(), wrapPlayerFilter(filter))
                funnelEnum(whichForce)
            end

            local oldForceEnumEnemies = ForceEnumEnemies
            ---@param whichForce FakeForce
            ---@param filter? boolexpr|fun():boolean
            function ForceEnumEnemies(whichForce, filter)
                oldForceEnumEnemies(getMainForce(), wrapPlayerFilter(filter))
                funnelEnum(whichForce)
            end
        end
    end)
    OnInit.root("LIGUI_EventResponseOverrides", function(require)
        local threadDataAPI = require "LIGUI_ThreadData" --[[@as LIGUI_ThreadDataAPI]]
        local getThreadData = threadDataAPI.getThreadData

        local eventRegistryAPI = require "LIGUI_EventRegistry" --[[@as LIGUI_EventRegistryAPI]]
        local eventResponseMap = eventRegistryAPI.eventResponseMap

        ---@param name string
        ---@return unknown
        local function getEventResponse(name)
            debug("Get", name, "for", coroutine.running(), "as", getThreadData(coroutine.running())[name])
            return getThreadData(coroutine.running())[name]
        end

        ---@param name string
        ---@param value unknown
        local function setEventResponse(name, value)
            debug("Set", name, "for", coroutine.running(), "to", value)
            getThreadData(coroutine.running())[name] = value
        end

        ---@param eventResponseGetterFunctionName string
        local function hijackNativeEventResponse(eventResponseGetterFunctionName)
            eventResponseMap[eventResponseGetterFunctionName] = _ENV[eventResponseGetterFunctionName]
            _ENV[eventResponseGetterFunctionName] = function()
                return getEventResponse(eventResponseGetterFunctionName)
            end
        end

        ---@param eventResponseGetterFunctionName string
        ---@param invalidatorFunctionName string
        local function hijackEditableNativeEventResponse(eventResponseGetterFunctionName, invalidatorFunctionName)
            hijackNativeEventResponse(eventResponseGetterFunctionName)

            local old = _ENV[invalidatorFunctionName]
            ---@param value unknown
            _ENV[invalidatorFunctionName] = function(value)
                old(value)
                setEventResponse(invalidatorFunctionName, value)
            end
        end

        hijackNativeEventResponse("GetTriggeringTrigger") -- setup by FakeTriggerEvent
        hijackNativeEventResponse("GetTriggerEventId")    -- setup by FakeTriggerEvent
        hijackNativeEventResponse("GetTriggeringRegion")
        hijackNativeEventResponse("GetEnteringUnit")
        hijackNativeEventResponse("GetLeavingUnit")
        hijackNativeEventResponse("GetTriggeringTrackable")
        hijackNativeEventResponse("GetClickedButton")
        hijackNativeEventResponse("GetClickedDialog")
        hijackNativeEventResponse("GetSaveBasicFilename")
        hijackNativeEventResponse("GetTriggerPlayer")
        hijackNativeEventResponse("GetLevelingUnit")
        hijackNativeEventResponse("GetLearningUnit")
        hijackNativeEventResponse("GetLearnedSkill")
        hijackNativeEventResponse("GetLearnedSkillLevel")
        hijackNativeEventResponse("GetRevivableUnit")
        hijackNativeEventResponse("GetRevivingUnit")
        hijackNativeEventResponse("GetAttacker")
        hijackNativeEventResponse("GetRescuer")
        hijackNativeEventResponse("GetDyingUnit")
        hijackNativeEventResponse("GetKillingUnit")
        hijackNativeEventResponse("GetDecayingUnit")
        hijackNativeEventResponse("GetConstructingStructure")
        hijackNativeEventResponse("GetCancelledStructure")
        hijackNativeEventResponse("GetConstructedStructure")
        hijackNativeEventResponse("GetResearchingUnit")
        hijackNativeEventResponse("GetResearched")
        hijackNativeEventResponse("GetTrainedUnitType")
        hijackNativeEventResponse("GetTrainedUnit")
        hijackNativeEventResponse("GetDetectedUnit")
        hijackNativeEventResponse("GetSummoningUnit")
        hijackNativeEventResponse("GetSummonedUnit")
        hijackNativeEventResponse("GetTransportUnit")
        hijackNativeEventResponse("GetLoadedUnit")
        hijackNativeEventResponse("GetSellingUnit")
        hijackNativeEventResponse("GetSoldUnit")
        hijackNativeEventResponse("GetBuyingUnit")
        hijackNativeEventResponse("GetSoldItem")
        hijackNativeEventResponse("GetChangingUnit")
        hijackNativeEventResponse("GetChangingUnitPrevOwner")
        hijackNativeEventResponse("GetManipulatingUnit")
        hijackNativeEventResponse("GetManipulatedItem")
        hijackNativeEventResponse("BlzGetAbsorbingItem")
        hijackNativeEventResponse("BlzGetManipulatedItemWasAbsorbed")
        hijackNativeEventResponse("BlzGetStackingItemSource")
        hijackNativeEventResponse("BlzGetStackingItemTarget")
        hijackNativeEventResponse("BlzGetStackingItemTargetPreviousCharges")
        hijackNativeEventResponse("GetOrderedUnit")
        hijackNativeEventResponse("GetIssuedOrderId")
        hijackNativeEventResponse("GetOrderPointX")
        hijackNativeEventResponse("GetOrderPointY")
        -- hijackNativeEventResponse("GetOrderPointLoc")
        hijackNativeEventResponse("GetOrderTarget")
        hijackNativeEventResponse("GetOrderTargetDestructable")
        hijackNativeEventResponse("GetOrderTargetItem")
        hijackNativeEventResponse("GetOrderTargetUnit")
        hijackNativeEventResponse("GetSpellAbilityUnit")
        hijackNativeEventResponse("GetSpellAbilityId")
        hijackNativeEventResponse("GetSpellAbility")
        hijackNativeEventResponse("GetSpellTargetX")
        hijackNativeEventResponse("GetSpellTargetY")
        -- hijackNativeEventResponse("GetSpellTargetLoc")
        hijackNativeEventResponse("GetSpellTargetDestructable")
        hijackNativeEventResponse("GetSpellTargetItem")
        hijackNativeEventResponse("GetSpellTargetUnit")
        hijackNativeEventResponse("GetEventPlayerState")
        hijackNativeEventResponse("GetEventPlayerChatString")
        hijackNativeEventResponse("GetEventPlayerChatStringMatched")
        hijackNativeEventResponse("GetTriggerUnit")
        hijackNativeEventResponse("GetEventUnitState")
        hijackNativeEventResponse("GetEventDamageSource")
        hijackNativeEventResponse("GetEventDetectingPlayer")
        hijackNativeEventResponse("GetEventTargetUnit")
        hijackNativeEventResponse("GetTriggerWidget")
        hijackNativeEventResponse("BlzGetEventDamageTarget")
        hijackEditableNativeEventResponse("GetEventDamage", "BlzSetEventDamage")
        hijackEditableNativeEventResponse("BlzGetEventAttackType", "BlzSetEventAttackType")
        hijackEditableNativeEventResponse("BlzGetEventDamageType", "BlzSetEventDamageType")
        hijackEditableNativeEventResponse("BlzGetEventWeaponType", "BlzSetEventWeaponType")
        hijackNativeEventResponse("BlzGetEventIsAttack")
        hijackNativeEventResponse("BlzGetTriggerFrame")
        hijackNativeEventResponse("BlzGetTriggerFrameEvent")
        hijackNativeEventResponse("BlzGetTriggerFrameValue")
        hijackNativeEventResponse("BlzGetTriggerPlayerKey")
        hijackNativeEventResponse("BlzGetTriggerPlayerMetaKey")
        hijackNativeEventResponse("BlzGetTriggerPlayerIsKeyDown")
        hijackNativeEventResponse("BlzGetTriggerPlayerMouseX")
        hijackNativeEventResponse("BlzGetTriggerPlayerMouseY")
        hijackNativeEventResponse("BlzGetTriggerPlayerMousePosition")
        -- let's pretend these are also event responses
        hijackNativeEventResponse("GetEnumUnit")
        hijackNativeEventResponse("GetEnumDestructable")
        hijackNativeEventResponse("GetEnumItem")
        hijackNativeEventResponse("GetEnumPlayer")
    end)
    OnInit.root("LIGUI_BjOverrides", function(require)
        require "LIGUI_CommonOverrides"
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

        IssuePointOrderLocBJ                 = IssuePointOrderLoc
        GroupPointOrderLocBJ                 = GroupPointOrderLoc
        GetEntireMapRect                     = GetWorldBounds
        CountPlayersInForceEnum              = nil
        bj_lastCreatedGroup                  = CreateGroup()
        bj_suspendDecayFleshGroup            = CreateGroup()
        bj_suspendDecayBoneGroup             = CreateGroup()
        ForGroupBJ                           = ForGroup
        CountUnitsInGroup                    = BlzGroupGetSize
        BlzGroupAddGroupFast                 = GroupAddGroup
        BlzGroupRemoveGroupFast              = GroupRemoveGroup
        GroupPickRandomUnitEnum              = nil
        CountUnitsInGroupEnum                = nil
        GroupAddGroupEnum                    = nil
        GroupRemoveGroupEnum                 = nil

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
        GetItemLifeBJ                        = GetWidgetLife -- This was just to type casting
        SetItemLifeBJ                        = SetWidgetLife -- This was just to type casting
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
        LeaderboardSetStyleBJ                = LeaderboardSetStyle
        LeaderboardGetItemCountBJ            = LeaderboardGetItemCount
        LeaderboardHasPlayerItemBJ           = LeaderboardHasPlayerItem
        DestroyLeaderboardBJ                 = DestroyLeaderboard
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
        GroupTrainOrderByIdBJ                = GroupImmediateOrderById
        GroupTargetDestructableOrder         = GroupTargetOrder       -- This was just to type casting
        GroupTargetItemOrder                 = GroupTargetOrder       -- This was just to type casting
        GetDyingDestructable                 = GetTriggerDestructable -- I think they just wanted a better name
        GetAbilityName                       = GetObjectName          -- I think they just wanted a better name

        -- List of math overrides, provided by Antares & Insanity_AI
        CosBJ                                = function(degrees) return math.cos(degrees * bj_DEGTORAD) end ---@type fun(degrees: number): number
        SinBJ                                = function(degrees) return math.sin(degrees * bj_DEGTORAD) end ---@type fun(degrees: number): number
        TanBJ                                = function(degrees) return math.tan(degrees * bj_DEGTORAD) end ---@type fun(degrees: number): number
        AsinBJ                               = function(ratio) return math.asin(ratio) * bj_RADTODEG end ---@type fun(ratio: number): number
        AcosBJ                               = function(ratio) return math.acos(ratio) * bj_RADTODEG end ---@type fun(ratio: number): number

        SubStringBJ                          = string.sub

        ---@param group FakeGroup
        ---@param add FakeGroup
        function GroupAddGroup(add, group)
            if check(group ~= nil, 'group cannot be nil') then return end
            if check(add ~= nil, 'add cannot be nil') then return end
            GUI.forGroup(add, function(unit)
                GroupAddUnit(group, unit)
            end)
        end

        ---@param group FakeGroup
        ---@param remove FakeGroup
        function GroupRemoveGroup(remove, group)
            if check(group ~= nil, 'group cannot be nil') then return end
            if check(remove ~= nil, 'remove cannot be nil') then return end
            GUI.forGroup(remove, function(unit)
                GroupRemoveUnit(group, unit)
            end)
        end

        ---@param group FakeGroup
        ---@return unit|nil
        function GroupPickRandomUnit(group)
            if check(group ~= nil, 'group cannot be nil') then return nil end
            return group[1] and group[GetRandomInt(1, #group)]
        end

        ---@param group FakeGroup
        ---@return boolean
        function IsUnitGroupEmptyBJ(group)
            if check(group ~= nil, 'group cannot be nil') then return true end -- if it's a nil group, I'm sure the appropriate logic is to say it's empty?
            return not group[1]
        end

        ---@param force FakeForce
        ---@return integer
        function CountPlayersInForceBJ(force)
            if check(force ~= nil, 'force cannot be nil') then return 0 end
            return #force
        end
    end)
    OnInit.root("LIGUI_BjFixes", function(require)
        ---@param trig FakeTrigger
        ---@param r FakeRect
        function TriggerRegisterDestDeathInRegionEvent(trig, r)
            if check(trig ~= nil, 'trigger cannot be nil') then return end
            if check(r ~= nil, 'rect cannot be nil') then return end
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

        -- Modify to allow requests for negative hero stats, as per request from Tasyen.
        ---@param whichHero unit
        ---@param whichStat integer
        ---@param value integer
        function SetHeroStat(whichHero, whichStat, value)
            if check(whichStat ~= nil, 'whichStat cannot be nil') then return end
            if (whichStat == bj_HEROSTAT_STR) then
                SetHeroStr(whichHero, value, true)
            elseif (whichStat == bj_HEROSTAT_AGI) then
                SetHeroAgi(whichHero, value, true)
            elseif (whichStat == bj_HEROSTAT_INT) then
                SetHeroInt(whichHero, value, true)
            end
        end

        -- removed SyncSelections from the following BJs
        ---@param whichPlayer player
        ---@return FakeGroup
        function GetUnitsSelectedAll(whichPlayer)
            local g = CreateGroup()
            -- SyncSelections()
            GroupEnumUnitsSelected(g, whichPlayer, nil)
            return g --[[@as FakeGroup]]
        end

        ---@param whichPlayer player
        ---@param enumFilter? fun():boolean
        ---@param enumAction function
        function EnumUnitsSelected(whichPlayer, enumFilter, enumAction)
            local g = CreateGroup()
            -- SyncSelections()
            GroupEnumUnitsSelected(g --[[@as group]], whichPlayer, enumFilter)
            ForGroup(g, enumAction)
        end

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
        local fStack, tStack = {}, {} ---@type {[eventid]: function[]}, {[eventid]: trigger[]}
        local oldBJ = TriggerRegisterAnyUnitEventBJ

        ---@param event playerunitevent
        ---@param userFunc function
        ---@param skip boolean?
        function RegisterAnyPlayerUnitEvent(event, userFunc, skip)
            if check(event ~= nil, 'event cannot be nil') then return end
            if check(userFunc ~= nil, 'userFunc cannot be nil') then return end
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
        ---@param trig FakeTrigger
        ---@param event playerunitevent
        ---@return function|nil
        function TriggerRegisterAnyUnitEventBJ(trig, event)
            if check(trig ~= nil, 'trig cannot be nil') then return nil end
            if check(event ~= nil, 'event cannot be nil') then return nil end
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

        if _USE_GLOBAL_REMAP then
            OnInit.global(function(require)
                require "GlobalRemap"
                GlobalRemap("udg_INFINITE_LOOP", function() return -1 end) --a readonly variable for infinite looping in GUI.
            end)
        end
    end)
    OnInit.root("LIGUI_UnitRemoveDetection", function(require)
        local groupsAPI = require "LIGUI_Groups" --[[@as LIGUI_GroupsAPI]]
        local groupDBDeregisterUnit = groupsAPI.groupDBDeregisterUnit

        local UNDEFEND_ORDER_ID = 852056
        local allUnits = {} ---@type table<unit, boolean>

        ---@alias UnitRemovalEventListener fun(removedUnit: unit)

        ---@class EventListenerMap
        ---@field [integer] UnitRemovalEventListener
        ---@field [UnitRemovalEventListener] integer
        ---@field n integer
        local eventListeners = { n = 0 }

        local function indexUnitAction()
            local unit = GetTriggerUnit()
            if not allUnits[unit] then
                allUnits[unit] = true
                UnitAddAbility(unit, _REMOVE_ABIL)
                UnitMakeAbilityPermanent(unit, true, _REMOVE_ABIL)
            end -- else - the unit was dead, but has re-entered the map (e.g. unloaded from meat wagon)
        end

        local function deindexUnitAction()
            local unit = GetTriggerUnit()
            if GetIssuedOrderId() == UNDEFEND_ORDER_ID and not UnitAlive(unit) and allUnits[unit] and GetUnitAbilityLevel(unit, _REMOVE_ABIL) == 0 then
                allUnits[unit] = nil
                for _, listener in ipairs(eventListeners) do
                    coroutine.wrap(listener)(unit) -- we don't care about result
                end
                groupDBDeregisterUnit(unit)        -- this shouldn't throw errors
            end
        end

        ---@param listener fun(removedUnit: unit)
        function GUI.RegisterUnitRemovedEventListener(listener)
            if check(listener ~= nil, 'listener cannot be nil') then return end
            if eventListeners[listener] then return end

            eventListeners.n = eventListeners.n + 1
            eventListeners[listener] = eventListeners.n
            eventListeners[eventListeners.n] = listener
        end

        ---@param listener fun(removedUnit: unit)
        function GUI.DeregisterUnitRemovedEventListener(listener)
            if check(listener ~= nil, 'listener cannot be nil') then return end
            if eventListeners[listener] then return end

            eventListeners[eventListeners[listener]] = eventListeners[eventListeners.n]
            eventListeners[eventListeners.n] = nil
            eventListeners.n = eventListeners.n - 1
            eventListeners[listener] = nil
        end

        OnInit.main("LIGUI_UnitRemoveDetectInit", function(require)
            require "LIGUI_WorldBounds"

            local indexTrigger = CreateTrigger()
            TriggerRegisterEnterRectSimple(indexTrigger, GetWorldBounds() --[[@as rect]]) -- returns FakeRect but due to all overrides, the BJ will be able to process it
            TriggerAddAction(indexTrigger, indexUnitAction)

            local deindexTrigger = CreateTrigger()
            TriggerRegisterAnyUnitEventBJ(deindexTrigger, EVENT_PLAYER_UNIT_ISSUED_ORDER)
            TriggerAddAction(deindexTrigger, deindexUnitAction)

            local playerCountMax = GetBJMaxPlayerSlots() - 1 -- 24 + 4 neutrals
            for j = 0, playerCountMax do
                SetPlayerAbilityAvailable(Player(j), _REMOVE_ABIL, false)
            end
        end)
    end)
    OnInit.root("LIGUI_QuantumTempVariables", function(require)
        local threadDataAPI = require "LIGUI_ThreadData" --[[@as LIGUI_ThreadDataAPI]]
        local getThreadData = threadDataAPI.getThreadData

        local gmt = getmetatable(_ENV) or getmetatable(setmetatable(_ENV, {}))
        local rawset = gmt.__newindex or rawset
        local rawget = gmt.__index or rawget
        local variableThreadLocals = {} ---@type table<string, true>
        gmt.__newindex = function(t, k, v)
            if string.match(string.lower(k), 'udg_temp') then
                variableThreadLocals[k] = true
                debug("Setting", k, "for", coroutine.running(), "to", v)
                rawset(getThreadData(coroutine.running()), k, v)
            else
                rawset(t, k, v)
            end
        end
        gmt.__index = function(t, k)
            if variableThreadLocals[k] then
                local result = getThreadData(coroutine.running())[k]
                debug("Getting", k, "for", coroutine.running(), "as", result)
                return result
            else
                return rawget(t, k)
            end
        end
    end)

    -- root
    require "LIGUI_FakeType"
    require "LIGUI_ThreadData"
    require "LIGUI_Coroutines"
    require "LIGUI_MiscellaneousFixes"
    require "LIGUI_Hashtables"
    require "LIGUI_Boolexprs"
    require "LIGUI_Groups"
    require "LIGUI_EventRegistry"

    -- root - overrides
    require "LIGUI_CommonOverrides"
    require "LIGUI_HashtableOverride"
    require "LIGUI_TriggerOverride"
    require "LIGUI_TimerOverride"
    require "LIGUI_LocationOverride"
    require "LIGUI_BoolexprOverride"
    require "LIGUI_RectOverride"
    require "LIGUI_ForceOverride"
    require "LIGUI_GroupOverride"
    require "LIGUI_ComboOverrides"
    require "LIGUI_EventResponseOverrides"
    require "LIGUI_BjOverrides"
    require "LIGUI_BjFixes"
    require "LIGUI_UnitRemoveDetection"
    require "LIGUI_QuantumTempVariables"

    -- main
    require "LIGUI_NativeFilter"
    require "LIGUI_NativeLoc"
    require "LIGUI_WorldBounds"
    require "LIGUI_NativeForce"
    require "LIGUI_NativeGroups"
    require "LIGUI_UnitRemoveDetectInit"
end)
if Debug then Debug.endFile() end
