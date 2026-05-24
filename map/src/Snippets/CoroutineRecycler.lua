if Debug then Debug.beginFile "CoroutineRecycler" end
OnInit.root(function(require)
    local coroutine = coroutine
    local threadPool = { n = 0 } ---@type thread[]|{n: integer}
    local threadJobMap = setmetatable({}, { __mode = 'k' }) ---@type table<thread, fun(...):...>
    local threadDead = setmetatable({}, { __mode = 'k' }) ---@type table<thread, true>
    local args = {} -- One table to pass all the data, ALL OF IT

    --- some optimizations probably could be done about this
    local function pack(args, ...)
        local argN = select(..., '#')
        if argN < args.n then
            for i = argN + 1, args.n do
                args[i] = nil
            end
        end

        args.n = argN
        for i = 1, argN do
            args[i] = select(..., i)
        end
    end

    local unpack = table.unpack

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
            threadPool.n = threadPool - 1
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
end)
if Debug then Debug.endFile() end
