if Debug then Debug.beginFile "LuaInfusedGUI" end
OnInit.root(function()
    --Configurables
    local _THROW_ERROR_ON_INVALID_ARG    = false -- set to true if you want LIGUI to throw errors when incorrect arguments are sent to overriden functions
    local _PRINT_WARNING_ON_INVALID_ARG  = true  -- set to true if you want warnings by LIGUI when incorrect arguments are sent to overriden functions
    local _USE_GLOBAL_REMAP              = false -- set to true if you want GUI to have extended functionality such as "udg_HashTableArray" (which gives GUI an infinite supply of shared hashtables)
    local _USE_UNIT_EVENT                = false -- set to true if you have UnitEvent in your map and want to automatically remove units from their unit groups if they are removed from the game.

    -- Experimental features
    local _EXPERIMENTAL                  = true -- experimental features; overriding coroutines, triggers, timers and boolexprs
    local _COROUTINE_RECYCLER            = true -- use a coroutine recycler
    local _RESUME_TIMER_RESTORE_PERIODIC = true -- set to true if _USE_TIMERQUEUE is true and you wish to fix resumed repeating timers staying repeating instead of becoming one-shot

    -- Used to check if function should exit early due to invalid arguments, instead of executing its internal logic
    local check ---@type fun(condition:boolean, msg: string): shouldEarlyExit: boolean
    do
        if _THROW_ERROR_ON_INVALID_ARG then
            check = function(condition, msg)
                return not assert(condition, msg)
            end
        elseif _PRINT_WARNING_ON_INVALID_ARG then
            check = function(condition, msg)
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
            check = function(condition)
                return not condition
            end
        end
    end

    --- some optimizations probably could be done about this
    ---@param outArgs table
    ---@param ... any
    local function pack(outArgs, ...)
        local argN = select(..., '#')
        if argN < outArgs.n then
            for i = argN + 1, outArgs.n do
                outArgs[i] = nil
            end
        end

        outArgs.n = argN
        for i = 1, argN do
            outArgs[i] = select(..., i)
        end
    end
    local unpack = table.unpack

    if _COROUTINE_RECYCLER then
        local coroutine = coroutine
        local threadPool = { n = 0 } ---@type thread[]|{n: integer}
        local threadJobMap = setmetatable({}, { __mode = 'k' }) ---@type table<thread, fun(...):...>
        local threadDead = setmetatable({}, { __mode = 'k' }) ---@type table<thread, true>
        local args = {} -- One table to pass all the data, ALL OF IT

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

        ---@param f async fun(...):...
        ---@return thread
        local function getCoroutine(f)
            local thread
            if threadPool.n > 0 then
                thread = threadPool[threadPool.n]
                threadPool[threadPool.n] = nil
                threadPool.n = threadPool - 1
            else
                thread = coroutine.create(coroutineCallback)
            end
            threadJobMap[thread] = f
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
            ---@return ...
            resume = function(co, ...)
                if threadDead[co] then return false, 'cannot resume dead coroutine' end
                return coroutine.resume(co, ...)
            end,

            yield = coroutine.yield,
            running = coroutine.running,
            isyieldable = coroutine.isyieldable,
            create = getCoroutine
        }
    end

    local oldCoroutineCreate = coroutine.create
    local oldCoroutineResume = coroutine.resume

    -- types

    ---@class FakedType
    ---@field __faketype string

    GUI = {}

    -- thread local
    do
        -- Required in order to access cached event responses
        local threadData = setmetatable({}, { __mode = 'kv' }) ---@type table<thread, table<string, unknown>>
        local threadDataMt = { __mode = 'k' }

        ---@param currentThread thread
        ---@param parentThread thread?
        ---@param toRoot true?
        ---@return table<string, unknown>
        function GUI.setupThreadData(currentThread, parentThread, toRoot)
            local tbl = {}
            if parentThread then
                if toRoot then
                    local parentMt = getmetatable(threadData[parentThread])
                    if parentMt.__index then
                        setmetatable(tbl, parentMt) -- copy to directly refer to master thread table
                    else
                        setmetatable(tbl, {
                            __index = threadData[parentThread],
                            __newindex = threadData[parentThread],
                            __mode = 'k'
                        }) -- create new one as this is the first descendant thread
                    end
                else
                    setmetatable(tbl, threadData[parentThread])
                end
            else
                setmetatable(tbl, threadDataMt)
            end
            threadData[currentThread] = tbl
            return tbl
        end

        function GUI.clearThreadData(currentThread)
            threadData[currentThread] = nil
        end
    end

    -- global variables
    do
        local mts = {}
        local weakKeys = { __mode = "k" } --ensures tables with non-nilled objects as keys will be garbage collected.

        ---@param default? any
        ---@param tab? table
        ---@return table
        function GUI.jarray(default, tab)
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

        ---Add this safe iterator function for jarrays.
        ---@param whichTable table
        ---@param func fun(index:integer, value:any)
        function GUI.loopArray(whichTable, func)
            for i = rawget(whichTable, 0) ~= nil and 0 or 1, #whichTable do
                func(i, rawget(whichTable, i))
            end
        end
    end

    -- Overrides
    do
        local oldType = type
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

        ---@param f async fun(...):...
        ---@return thread
        function coroutine.create(f)
            local thread = oldCoroutineCreate(f)
            GUI.setupThreadData(thread, coroutine.running())
            return thread
        end

        local args = {}

        ---@param co thread
        ---@param val1 any?
        ---@param ... any
        ---@return boolean success
        ---@return any ...
        coroutine.resume = function(co, val1, ...)
            pack(args, oldCoroutineResume(co, val1, ...))
            if coroutine.status(co) == 'dead' then
                GUI.clearThreadData(co)
            end
            return unpack(args)
        end

        --have to do a wide search for all arrays in the variable editor. The WarCraft 3 _ENV table is HUGE,
        --and without editing the war3map.lua file manually, it is not possible to rewrite it in advance.
        for k, v in pairs(_ENV) do
            if type(v) == "table" and string.sub(k, 1, 4) == "udg_" then
                __jarray(v[0], v)
            end
        end
    end
end)
if Debug then Debug.endFile() end
