--[[
----------------------
--  EventListener   --
--      v.1.0.3.1   --
----------------------
--          MyPad   --
----------------------
 ----------------------------------------------------------------------
|
|    About:
|
|----------------------------------------------------------------------
|
|        EventListener is a class that enables a user to create a list
|        of functions, which can be executed in sequence safely. It is
|        designed to handle recursion depth logics, as well as edge case
|        scenarios where functions are deregistered during the execution
|        of the list of functions.
|
|        By creating a list of functions, EventListener as a class is
|        well suited to creating custom events, and responding to said
|        events. For example, if one wishes to observe a damage event,
|        but prevent the possibility of an infinite depth recursion,
|        one can create an EventListener object that handles the depth
|        recursion logic for the user.
|
|        << Sample Code >>
|        dmgEvent = EventListener:create()
|        dmgEvent:setMaxDepth(8)
|        << Sample Code >>
|
|        The example above will create an EventListener that has a
|        defined maximum recursion depth at 8. However, the code
|        above will do nothing on its' own. Let's append it to the
|        actual event.
|
|        << Sample Code >>
|        function SomeInitFunc()
|            local t = CreateTrigger()
|            TriggerRegisterAnyUnitEventBJ(t, EVENT_PLAYER_UNIT_DAMAGED)
|            TriggerAddCondition(t, Condition(function()
|                ...
|                dmgEvent:run()
|            end))
|        end
|
|        ...
|        SomeInitFunc()
|        << Sample Code >>
|
|        As you can see, the dmgEvent will now execute every time
|        a unit is damaged. This is achieved by calling
|        EventListener:run(), which iterates through and calls
|        the given list of functions.
|
|    ----------------
|    --  Features  --
|    ----------------
|
|        - Recursion depth protection.
|        - Robust function registration and removal.
|
|----------------------------------------------------------------------
|                   |--             API             --|
|----------------------------------------------------------------------
|
|        EventListener.create(o)
|        EventListener.new(o) {LEGACY}
|        EventListener(o) {LEGACY}
|           - Returns a new EventListener object.
|
|        EventListener:destroy()
|           - Destroys a given EventListener object.
|
|        EventListener:register(func) -> bool
|           - Registers a given function to the
|             EventListener object.
|           - Registration may fail due to the following reasons:
|               - The function may be already registered to the instance
|               - The function may be blacklisted
|               - The parameter may not be a function.
|           - As of 1.0.3.0, <repetitions> field has been removed.
|
|        EventListener:unregister(func)
|        EventListener:deregister(func) {LEGACY}
|           - Deregisters a function if found in
|             the list of functions associated with the
|             EventListener object.
|
|        EventListener:destroy()
|           - As of 1.0.3.0, if called while the EventListener
|             object is still running, it will block subsequent
|             executions and terminate the loop.
|           - As of 1.0.3.0, the EventListener object removes
|             all of its references to the tables it used.
|
|        EventListener:cond_run(cond[, ...])
|        EventListener:cfire(cond[, ...]) {LEGACY}
|        EventListener:conditionalRun(cond[, ...]) {LEGACY}
|        EventListener:conditionalExec(cond[, ...]) {LEGACY}
|           - As of 1.0.3.0, the condition is evaluated only once.
|           - Internally calls EventListener:run with
|             the appended arguments (true, true, <...>).
|
|        EventListener:run([, ...])
|        EventListener:execute([, ...]) {LEGACY}
|        EventListener:fire([, ...]) {LEGACY}
|        EventListener:exec([, ...]) {LEGACY}
|           - If an argument <...> is passed, it will be propagated
|             to the body of executing functions. This has no
|             practical limit. (Only restricted by Lua itself)
|           - Destroys the object if it has been "finalized".
|
|        EventListener:getMaxDepth(value)
|        EventListener:getRecursionCount(value) {LEGACY}
|        EventListener:getRecursionDepth(value) {LEGACY}
|           - Returns the maximum amount of times a function can be executed
|             recursively.
|
|        EventListener:setMaxDepth(value)
|        EventListener:setRecursionCount(value) {LEGACY}
|        EventListener:setRecursionDepth(value) {LEGACY}
|           - Sets the recursion depth to the given value.
|           - A value of 0 or less will make the object
|              susceptible to infinite loops.
|
|       EventListener:getCallbackDepth(func)
|           - Returns the integer depth of the requested function.
|           - If the function isn't registered, this returns 0.
|           - Note that very high values may suggest the presence
|             of an infinite loop (typically around 3+).
|
|       EventListener:getCurDepth()
|           - Returns the integer depth of the EventListener instance.
|           - If the current depth is greater than the maximum depth
|             of the EventListener instance, all registered functions
|             will not be executed.
|
|       EventListener:getCurCallback()
|           - Returns the currently executing function of the instance.
|           - Defaults to DoNothing if the instance isn't currently running.
|
|       EventListener:getCurCallbackIndex()
|           - Returns the index of the currently executing function of the instance.
|           - Defaults to 0 if the instance isn't currently running.
|       
|       EventListener:enable(func, flag)
|           - Increments the "enabled" counter value of the registered
|             function "func" by 1 if flag is true. Otherwise, decrements
|             the "enabled" counter value by 1.
|           - Returns a boolean value which reflects the success of the
|             operation (with true corresponding to success and vice versa).
|
|       EventListener:isEnabled(func)
|           - If the function is not registered, this returns false.
|           - If the "enabled" counter value is greater than 0, this
|             returns true. Returns false otherwise.
|
 ----------------------------------------------------------------------
]]
do
    -- Determines the default amount of times a function can recursively be called
    -- before the system treats it as a runaway infinite loop.
    local _LOCAL_MAX_RECURSION  = 8
    -- Appends the current index of the executing function as the first parameter 
    -- among the list of parameters to be used. (Determined at compiletime)
    local _APPEND_INDEX         = false
    -- This is actually author-exclusive and excludes all copies of
    -- certain functions if set to false.
    local _LEGACY_MODE          = false
    ---@param baseFunc function -> The base function / method.
    ---@param baseName string -> The name of the base function / method.
    ---@param targetName string -> The name of the target function / method.
    local function deprecatedFactory(baseFunc, baseName, targetName)
        local print = print
        return function(...)
            print(targetName .. " has been deprecated. Use " .. baseName .. " instead.")
            return baseFunc(...)
        end
    end
    ---@class EventListener
    ---@field package _funcList table -> Stores a list of functions registered to this object.
    ---@field package _funcMap table -> Stores a flag for each registered function.
    ---@field package _funcAbleCounter table -> Stores a counter that determines whether function is to be called when the EventListener runs.
    ---@field package _funcCallCounter table -> Stores a counter that determines the current recursion depth of the called function.
    ---@field package _funcMaxDepth integer -> Holds the maximum amount of times a function can be recursively called. Default is _LOCAL_MAX_RECURSION
    ---@field package _curDepth integer -> The current depth of the EventListener object in a recursive context.
    ---@field package _curFunc function -> The current executing function of the EventListener object.
    ---@field package _curIndex integer -> The current executing function's index of the EventListener object.
    EventListener               = {}
    EventListener.__index       = EventListener
    EventListener.__metatable   = EventListener
    EventListener.__newindex    = 
    function(t, k, v)
        if EventListener[k] then return end
        rawset(t, k, v)
    end
    EventListener.__len         =
    function(t)
        return t._size or 0
    end
    if not IsFunction then
    function IsFunction(func)
        return type(func) == 'function'
    end
    end
    local pcall     = pcall
    local DoNothing = DoNothing
    ---Creates a new instance.
    ---@param o table | nil
    ---@return EventListener
    function EventListener.create(o)
        o                   = o or {}
        o._funcMap          = {}
        o._funcList         = {}
        o._funcAbleCounter  = {}
        o._funcCallCounter  = {}
        o._funcMaxDepth     = _LOCAL_MAX_RECURSION
        o._curDepth         = 0
        o._curIndex         = 0
        o._size             = 0
        o._curFunc          = DoNothing
        o._wantDestroy      = false
        setmetatable(o, EventListener)
        return o
    end
    if _LEGACY_MODE then
    EventListener.new      = deprecatedFactory(EventListener.create, "EventListener.create", "EventListener.new")
    EventListener.__call   = deprecatedFactory(EventListener.create, "EventListener.create", "EventListener:__call")
    end
    ---Destroys the instance.
    function EventListener:destroy()
        if (self._curDepth > 0) then
            self._wantDestroy   = true
            return
        end
        self._funcMap           = nil
        self._funcList          = nil
        self._funcAbleCounter   = nil
        self._funcCallCounter   = nil
        self._funcMaxDepth      = nil
        self._curDepth          = nil
        self._curIndex          = nil
        self._curFunc           = nil
        self._wantDestroy       = nil
        self._size              = 0
        local mt                = EventListener.__metatable
        EventListener.__metatable   = nil
        setmetatable(self, nil)
        EventListener.__metatable   = mt
    end
    ---Returns true if the requested function is
    ---already mapped within the queried instance.
    ---@param o EventListener - The queried instance
    ---@param func function - The requested function.
    ---@return boolean
    local function alreadyRegistered(o, func)
        return o._funcMap[func] ~= nil
    end
    ---A list of blacklisted functions -> Cannot be registered as
    ---callback functions. If the function returns true, the parameter
    ---will not be registered. So far, only DoNothing is blacklisted.
    ---@param func function
    ---@return boolean
    local function blacklistedFunction(func)
        return func == DoNothing
    end
    ---@param func function - The function to be registered.
    ---@return boolean - true if function was successfully registered; false otherwise.
    function EventListener:register(func)
        if (not IsFunction(func)) or
           (alreadyRegistered(self, func) or
           (blacklistedFunction(func))) then
            return false
        end
        local index                     = #self._funcList + 1
        self._size                      = self._size + 1
        self._funcList[index]           = func
        self._funcAbleCounter[index]    = 1
        self._funcCallCounter[index]    = 0
        self._funcMap[func]             = #self._funcList
        return true
    end
    ---@param func function - The function to be unregistered.
    ---@return boolean - true if function was successfully unregistered; false otherwise.
    function EventListener:unregister(func)
        if (not IsFunction(func)) or
           (not alreadyRegistered(self, func) or
           (blacklistedFunction(func))) then
            return false
        end
        local i                         = self._funcMap[func]
        self._funcList[i]               = nil
        self._funcAbleCounter[i]        = nil
        self._funcCallCounter[i]        = nil
        self._funcMap[func]             = nil
        self._size                      = self._size - 1
        if (self._curFunc == func) then
            self._curFunc   = DoNothing
            self._curIndex  = 0
        end
        return true
    end
    if _LEGACY_MODE then
    EventListener.deregister = deprecatedFactory(EventListener.unregister, "EventListener:unregister", "EventListener:deregister")
    end
    ---This gets the smallest index higher than i
    ---that has a meaningful entry and maps the
    ---contents of the bigger index to the specified
    ---index i.
    ---@param i integer - The base index
    ---@param n integer - The size of the list as an explicit parameter.
    ---@param iBuffer integer - The buffer value to use for peeking.
    ---@return integer - Returns the updated value of iBuffer.
    local function forwardSwap(self, i, n, iBuffer)
        while (i + iBuffer <= n) do
            if (self._funcList[i + iBuffer] ~= nil) then
                local func                          = self._funcList[i + iBuffer]
                self._funcList[i]                   = func
                self._funcAbleCounter[i]            = self._funcAbleCounter[i + iBuffer]
                self._funcCallCounter[i]            = self._funcCallCounter[i + iBuffer]
                self._funcMap[func]                 = i
                self._funcList[i + iBuffer]         = nil
                self._funcAbleCounter[i + iBuffer]  = 0
                self._funcCallCounter[i + iBuffer]  = 0
                break
            end
            iBuffer     = iBuffer + 1
        end
        return iBuffer
    end
    ---At compiletime, this function will either append the current
    ---index as part of the parameters or pass the parameters as
    ---they are.
    local invokeFunction
    if _APPEND_INDEX then
        invokeFunction =
        function(func, i, ...)
            pcall(func, i, ...)
        end
    else
        invokeFunction =
        function(func, i, ...)
            pcall(func, ...)
        end
    end
    ---Attempts to call all registered functions in sequential order.
    ---@vararg any optional parameters that can be any type. Passed down to callback functions.
    function EventListener:run(...)
        local i, n          = 1, #self._funcList
        local checkForDepth = (self._funcMaxDepth > 0)
        local prevF, prevI  = self._curFunc, self._curIndex
        local iBuffer       = 1
        self._curDepth      = self._curDepth + 1
        while (i <= n) and (not self._wantDestroy) do
        while (true) do
            -- If the current index holds a recently deregistered function,
            -- peek into future entries and place them at the current index.
            if (self._funcList[i] == nil) then
                iBuffer = forwardSwap(self, i, n, iBuffer)
                -- Since there are no more entries, break the inner loop here.
                if (i + iBuffer > n) then
                    break
                end
            end
            if ((self._funcAbleCounter[i] < 1) or
                (self._wantDestroy)) then
                break
            end
            local func      = self._funcList[i]
            self._curIndex  = i
            self._curFunc   = func
            self._funcCallCounter[i] = self._funcCallCounter[i] + 1
            if (not checkForDepth) or (self._funcCallCounter[i] <= self._funcMaxDepth) then
                invokeFunction(func, i, ...)
            end
            if (self._wantDestroy) then
                break
            end
            -- Since the list is mutable, consider the possibility that it
            -- was the current function that was removed when the EventListener was
            -- at a lower depth. If so, do not decrement.
            if (func == self._curFunc) then
                self._funcCallCounter[i] = self._funcCallCounter[i] - 1
            else
                iBuffer = forwardSwap(self, i, n, iBuffer)
                n = #self._funcList
            end
            break
        end
        i = i + 1
        end
        self._curFunc, self._curIndex = prevF, prevI
        self._curDepth = self._curDepth - 1
        if (self._wantDestroy) and (self._curDepth <= 0) then
            self:destroy()
            return
        end
        if (not alreadyRegistered(self, self._curFunc)) then
            self._curFunc = DoNothing
            self._curIndex = 0
        end
    end
    if _LEGACY_MODE then
    EventListener.exec      = deprecatedFactory(EventListener.run, "EventListener:run", "EventListener:exec")
    EventListener.fire      = deprecatedFactory(EventListener.run, "EventListener:run", "EventListener:fire")
    EventListener.execute   = deprecatedFactory(EventListener.run, "EventListener:run", "EventListener:execute")
    end
    ---Evaluates the condition once before falling back to EventListener:run()
    ---@param cond function | boolean
    ---@vararg any optional parameters that can be any type. Passed down to callback functions.
    function EventListener:cond_run(cond, ...)
        if ((IsFunction(cond) and (not cond())) or 
        ((not IsFunction(cond)) and (not cond))) then
            return
        end
        self:run(...)
    end
    if _LEGACY_MODE then
        EventListener.cfire             = deprecatedFactory(EventListener.cond_run, "EventListener:cond_run", "EventListener:cfire")
        EventListener.conditionalRun    = deprecatedFactory(EventListener.cond_run, "EventListener:cond_run", "EventListener:conditionalRun")
        EventListener.conditionalExec   = deprecatedFactory(EventListener.cond_run, "EventListener:cond_run", "EventListener:conditionalExec")
    end
    ---@param self EventListener - The EventListener object.
    ---@return integer - The max depth for a registered function within this instance.
    function EventListener:getMaxDepth()
        return self._funcMaxDepth
    end
    if _LEGACY_MODE then
    EventListener.getRecursionCount = deprecatedFactory(EventListener.getMaxDepth, "EventListener:getMaxDepth", "EventListener:getRecursionCount")
    EventListener.getRecursionDepth = deprecatedFactory(EventListener.getMaxDepth, "EventListener:getMaxDepth", "EventListener:getRecursionDepth")
    end
    ---@param self EventListener - The EventListener object.
    ---@param i integer - The updated max depth value.
    function EventListener:setMaxDepth(i)
        self._funcMaxDepth = i
    end
    if _LEGACY_MODE then
    EventListener.setRecursionCount = deprecatedFactory(EventListener.setMaxDepth, "EventListener:setMaxDepth", "EventListener:setRecursionCount")
    EventListener.setRecursionDepth = deprecatedFactory(EventListener.setMaxDepth, "EventListener:setMaxDepth", "EventListener:setRecursionDepth")
    end
    ---@param self EventListener - The EventListener object.
    ---@param func function - The function to be peeked.
    ---@return number - If not registered, defaults to 0. Returns the current depth of the function.
    function EventListener:getCallbackDepth(func)
        func = func or self._curFunc or DoNothing
        if (not alreadyRegistered(self, func)) then
            return 0
        end
        local i = self._funcMap[func]
        return self._funcCallCounter[i]
    end
    ---@param self EventListener - The EventListener object.
    ---@return integer - The current depth of the instance.
    function EventListener:getCurDepth()
        return self._curDepth or 0
    end
    ---@param self EventListener - The EventListener object.
    ---@return function - The current callback function of the running instance.
    function EventListener:getCurCallback()
        return self._curFunc or DoNothing
    end
    ---@param self EventListener - The EventListener object.
    ---@return integer - The index of the current callback function of the running instance.
    function EventListener:getCurCallbackIndex()
        return self._curIndex or 0
    end
    ---@param self EventListener - The EventListener object.
    ---@param func function - The affected function
    ---@param flag boolean - The flag value.
    ---@return boolean - Defaults to false if function isn't registered. Returns true otherwise.
    function EventListener:enable(func, flag)
        if (not alreadyRegistered(self, func)) then
            return false
        end
        local i = self._funcMap[func]
        local j = (flag and 1) or -1
        self._funcAbleCounter[i] = self._funcAbleCounter[i] + j
        return true
    end
    ---@param self EventListener - The EventListener object.
    ---@param func function - The affected function
    ---@return boolean - Defaults to false if function isn't registered. Returns true if counter value for function is greater than 0.
    function EventListener:isEnabled(func)
        if (not alreadyRegistered(self, func)) then
            return false
        end
        local i = self._funcMap[func]
        return self._funcAbleCounter[i] > 0
    end
end