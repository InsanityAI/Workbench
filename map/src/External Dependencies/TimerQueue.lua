if Debug and Debug.beginFile then Debug.beginFile("TimerQueue") end
--[[------------------------------------------------------------------------------------------------------------------------------------------------------------
*
*    --------------------------------
*    | TimerQueue and Stopwatch 1.2 |
*    --------------------------------
*
*    - by Eikonium and AGD
*
*    -> https://www.hiveworkshop.com/threads/timerqueue-stopwatch.353718/
*    - This is basically the enhanced and instancifiable version of ExecuteDelayed 1.0.4 by AGD https://www.hiveworkshop.com/threads/lua-delayedaction.321072/
*
* --------------------
* | TimerQueue class |
* --------------------
*        - A TimerQueue is an object used to execute delayed function calls. It can queue any number of function calls at the same time, while being based on a single timer. This offers much better performance than starting many separate timers.
*        - The class also provides methods to pause, resume, reset and destroy a TimerQueue - and even includes error handling.
*        - As such, you can create as many independent TimerQueues as you like, which you can individually use, pause, reset, etc.
*        - All methods can also be called on the class directly, which frees you from needing to create a TimerQueue object in the first place. You still need colon-notation!
*    TimerQueue.create() --> TimerQueue
*        - Creates a new TimerQueue with its own independent timer and function queue.
*    <TimerQueue>:callDelayed(number delay, function callback, ...) --> TimerQueueElement
*        - Calls the specified function (or callable table) after the specified delay (in seconds) with the specified arguments (...). Does not delay the following lines of codes.
*        - The returned TimerQueueElement can usually be discarded. Saving it to a local var allows you to :disable() or re-:enable() it later.
*    <TimerQueue>:callPeriodically(number delay, function|nil stopCondition, function callback, ...)
*        - Periodically calls the specified function (or callable table) after the specified delay (in seconds) with the specified arguments (...). Stops, when the specified condition resolves to true.
*        - The stop-condition must be a function returning a boolean. It is checked after each callback execution and is passed the same arguments as the callback (...) (which you can still ignore).
*        - You can pass nil instead of a function to let the periodic execution repeat forever.
*        - Resetting the TimerQueue will stop all periodic executions, even if the reset happened within the periodic callback.
*        - Doesn't return a TimerQueueElement, so disabling a periodic callback is only possible via either meeting the stop-condition or resetting the queue.
*    <TimerQueue>:reset()
*        - Discards all queued function calls from the Timer Queue. Discarded function calls are not executed.
*        - You can continue to use <TimerQueue>:callDelayed after resetting it.
*    <TimerQueue>:pause()
*        - Pauses the TimerQueue at its current point in time, effectively freezing all delayed function calls that it currently holds, until the queue is resumed.
*        - Using <TimerQueue>:callDelayed on a paused queue will correctly add the new callback to the queue, but time will start ticking only after resuming the queue.
*    <TimerQueue>:isPaused() --> boolean
*        - Returns true, if the TimerQueue is paused, and false otherwise.
*    <TimerQueue>:resume()
*        - Resumes a TimerQueue that was previously paused. Has no effect on TimerQueues that are not paused.
*    <TimerQueue>:destroy()
*        - Destroys the Timer Queue. Remaining function calls are discarded and not being executed.
*    <TimerQueue>:tostring() --> string
*        - Represents a TimerQueue as a list of its tasks. For debugging purposes.
*    <TimerQueue>.debugMode : boolean
*        - TimerQueues come with their own error handling in case you are not using DebugUtils (https://www.hiveworkshop.com/threads/debug-utils-ingame-console-etc.330758/).
*        - Set to true to let erroneous function calls through <TimerQueue>:callDelayed print error messages on screen (only takes effect, if Debug Utils is not present. Otherwise you get Debug Utils error handling, which is even better).
*        - Set to false to not trigger error messages after erroneous callbacks. Do this before map release.
*        - Default: true.
*    <TimerQueueElement>:disable()
*        - Disables this TimerQueueElement (as returned by TimerQueue:callDelayed), making the callback not execute upon timeout.
*        - Use this to cancel a future callback, when resetting the whole queue is not a suitable solution.
*        - The disabled TimerQueue-Element will continue to tick, but will forward to the next callback upon timeout instead of executing itself.
*    <TimerQueueElement>:enable()
*        - Enables this TimerQueueElement after you have previously disabled it, making the callback again execute normally upon timer expiration.
*        - Enabling a TimerQueueElement after its timeout has already passed (which happens even while disabled) will not have any effect.
* -------------------
* | Stopwatch class |
* -------------------
*        - Stopwatches count upwards, i.e. they measure the time passed since you've started them. Thus, they can't trigger any callbacks (use normal timers or TimerQueues for that).
*    Stopwatch.create(boolean startImmediately_yn) --> Stopwatch
*        - Creates a Stopwatch. Set boolean param to true to start it immediately.
*    <Stopwatch>:start()
*        - Starts or restarts a Stopwatch, i.e. resets the elapsed time of the Stopwatch to zero and starts counting upwards.
*    <Stopwatch>:getElapsed() --> number
*        - Returns the time in seconds that a Stopwatch is currently running, i.e. the elapsed time since start.
*    <Stopwatch>:pause()
*        - Pauses a Stopwatch, so it will retain its current elapsed time, until resumed.
*    <Stopwatch>:resume()
*        - Resumes a Stopwatch after having been paused.
*    <Stopwatch>:destroy()
*        - Destroys a Stopwatch. Maybe necessary to prevent memory leaks. Not sure, if lua garbage collection also collects warcraft objects...
---------------------------------------------------------------------------------------------------------------------------------------------------------]]

do

    ---@class TimerQueueElement
    ---@field [integer] any arguments to be passed to callback
    TimerQueueElement = {
        next = nil                      ---@type TimerQueueElement next TimerQueueElement to expire after this one
        ,   timeout = 0.                ---@type number time between previous callback and this one
        ,   callback = function() end   ---@type function callback to be executed
        ,   n = 0                       ---@type integer number of arguments passed
        ,   enabled = true              ---@type boolean defines whether the callback shall be executed on timeout or not.
    }
    TimerQueueElement.__index = TimerQueueElement
    TimerQueueElement.__name = 'TimerQueueElement'

    ---Creates a new TimerQueueElement, which points to itself.
    ---@param timeout? number
    ---@param callback? function|table
    ---@param ... any arguments for callback
    ---@return TimerQueueElement
    function TimerQueueElement.create(timeout, callback, ...)
        local new = setmetatable({timeout = timeout, callback = callback, n = select('#', ...), ...}, TimerQueueElement)
        new.next = new
        return new
    end

    ---Disables this TimerQueueElement, making the callback not execute upon timer expiration.
    ---Use this to cancel a future callback, when resetting the whole queue is not suitable.
    ---The disabled TimerQueue-Element will technically still be part of the queue, but will just forward to the next callback instead of executing itself.
    function TimerQueueElement:disable()
        self.enabled = false
    end

    ---Enables this TimerQueueElement after you have previously disabled it, making the callback again execute normally upon timer expiration.
    function TimerQueueElement:enable()
        self.enabled = true
    end

    ---@class TimerQueue
    TimerQueue = {
        timer = nil                     ---@type timer the single timer this system is based on (one per instance of course)
        ,   queue = TimerQueueElement.create() -- queue of waiting callbacks to be executed in the future
        ,   n = 0                       ---@type integer number of elements in the queue
        ,   on_expire = function() end  ---@type function callback to be executed upon timer expiration (defined further below).
        ,   debugMode = true           ---@type boolean setting this to true will print error messages, when the input function couldn't be executed properly. Set this to false before releasing your map.
        ,   paused = false              ---@type boolean whether the queue is paused or not
    }

    TimerQueue.__index = TimerQueue
    TimerQueue.__name = 'TimerQueue'

    --Creates a timer on first access of the static TimerQueue:callDelayed method. Avoids timer creation inside the Lua root.
    setmetatable(TimerQueue, {__index = function(t,k) if k == 'timer' then t[k] = CreateTimer() end; return rawget(t,k) end})

    local unpack, max, timerStart, timerGetElapsed, pauseTimer = table.unpack, math.max, TimerStart, TimerGetElapsed, PauseTimer

    ---@param timerQueue TimerQueue
    local function on_expire(timerQueue)
        local queue, timer = timerQueue.queue, timerQueue.timer
        local topOfQueue = queue.next
        queue.next = topOfQueue.next
        timerQueue.n = timerQueue.n - 1
        if timerQueue.n > 0 then
            timerStart(timer, queue.next.timeout, false, timerQueue.on_expire)
        else
            -- These two functions below may not be necessary
            timerStart(timer, 0, false, nil) --don't put in on_expire as handlerFunc, because it can still expire and reduce n to a value < 0.
            pauseTimer(timer)
        end
        if topOfQueue.enabled then
            if Debug and Debug.try then
                Debug.try(topOfQueue.callback, unpack(topOfQueue, 1, topOfQueue.n))
            else
                local errorStatus, errorMessage = pcall(topOfQueue.callback, unpack(topOfQueue, 1, topOfQueue.n))
                if timerQueue.debugMode and not errorStatus then
                    print("|cffff5555ERROR during TimerQueue callback: " .. errorMessage .. "|r")
                end
            end
        end
    end

    TimerQueue.on_expire = function() on_expire(TimerQueue) end

    ---@return TimerQueue
    function TimerQueue.create()
        local new = {}
        setmetatable(new, TimerQueue)
        new.timer = CreateTimer()
        new.queue = TimerQueueElement.create()
        new.on_expire = function() on_expire(new) end
        return new
    end

    ---Calls a function (or callable table) after the specified timeout (in seconds) with all specified arguments (...). Does not delay the following lines of codes.
    ---@param timeout number
    ---@param callback function|table if table, must be callable
    ---@param ... any arguments of the callback function
    ---@return TimerQueueElement queuedTask usually discarded. Can be saved to local var to :disable() or re-:enable() later.
    function TimerQueue:callDelayed(timeout, callback, ...)
        timeout = math.max(timeout, 0.)
        local queue = self.queue
        self.n = self.n + 1
        -- Sort timeouts in descending order
        local current = queue
        local current_timeout = current.next.timeout - max(timerGetElapsed(self.timer), 0.) -- don't use TimerGetRemaining to prevent bugs for expired and previously paused timers.
        while current.next ~= queue and timeout >= current_timeout do --there is another element in the queue and the new element shall be executed later than the current
            timeout = timeout - current_timeout
            current = current.next
            current_timeout = current.next.timeout
        end
        -- after loop, current is the element that executes right before the new callback. If the new is the front of the queue, current is the root element (queue).
        local new = TimerQueueElement.create(timeout, callback, ...)
        new.next = current.next
        current.next = new
        -- if the new callback is the next to expire, restart timer with new timeout
        if current == queue then --New callback is the next to expire
            new.next.timeout = max(current_timeout - timeout, 0.) --adapt element that was previously on top. Subtract new timeout and subtract timer elapsed time to get new timeout.
            timerStart(self.timer, timeout, false, self.on_expire)
            if self.paused then
                self:pause()
            end
        else
            new.next.timeout = max(new.next.timeout - timeout, 0.) --current.next might be the root element (queue), so prevent that from dropping below 0. (although it doesn't really matter)
        end
        return new
    end

    ---Calls the specified callback with the specified argumets (...) every <timeout> seconds, until the specified stop-condition holds.
    ---The stop-condition must be a function returning a boolean. It is checked after every callback execution. All arguments (...) are also passed to the stop-conditon (you can still ignore them).
    ---Resetting the TimerQueue will stop all periodic executions, even if the reset happened within the periodic callback.
    ---Doesn't return a TimerQueue-Element, so disabling is only possible by either meeting the stop-condition or resetting the queue.
    ---@param timeout number time between calls
    ---@param stopCondition? fun(...):boolean callback will stop to repeat, when this condition holds. You can pass nil to skip the condition (i.e. the periodic execution will run forever).
    ---@param callback fun(...) the callback to be executed
    ---@param ... any arguments for the callback
    function TimerQueue:callPeriodically(timeout, stopCondition, callback, ...)
        local func
        func = function(...)
            local queue = self.queue --memorize queue element to check later, whether TimerQueue:reset has been called in the meantime.
            callback(...) --execute callback first
            --re-queue, if stopCondition doesn't hold and the TimerQueue has not been reset during the callback (checked via queue == self.queue)
            if queue == self.queue and not (stopCondition and stopCondition(...)) then
                self:callDelayed(timeout, func, ...)
            end
        end
        self:callDelayed(timeout, func, ...)
    end

    ---Removes all queued calls from the Timer Queue, so any remaining actions will not be executed.
    ---Using <TimerQueue>:callDelayed afterwards will still work.
    function TimerQueue:reset()
        timerStart(self.timer, 0., false, nil) --dont't put in on_expire as handlerFunc. callback can still expire after pausing and resuming the empty queue, which would set n to a value < 0.
        pauseTimer(self.timer)
        self.n = 0
        self.queue = TimerQueueElement.create()
    end

    ---Pauses the TimerQueue at its current point in time, preventing all queued callbacks from being executed, until the queue is resumed.
    ---Using <TimerQueue>:callDelayed on a paused queue will correctly add the new callback to the queue, but time will start ticking only after the queue is being resumed.
    function TimerQueue:pause()
        self.paused = true
        pauseTimer(self.timer)
    end

    ---Returns true, if the timer queue is paused, and false otherwise.
    ---@return boolean
    function TimerQueue:isPaused()
        return self.paused
    end

    ---Resumes a TimerQueue that was paused previously. Has no effect on running TimerQueues.
    function TimerQueue:resume()
        if self.paused then
            self.paused = false
            self.queue.next.timeout = self.queue.next.timeout - timerGetElapsed(self.timer) --need to restart from 0, because TimerGetElapsed(resumedTimer) is doing so as well after a timer is resumed.
            ResumeTimer(self.timer)
        end
    end

    ---Destroys the timer object behind the TimerQueue. The Lua object will be automatically garbage collected once you ensure that there is no more reference to it.
    function TimerQueue:destroy()
        pauseTimer(self.timer) --https://www.hiveworkshop.com/threads/issues-with-timer-functions.309433/ suggests that non-paused destroyed timers can still execute their callback
        DestroyTimer(self.timer)
    end

    ---Prints the queued callbacks within the TimerQueue. For debugging purposes.
    ---@return string
    function TimerQueue:tostring()
        local current, result, i = self.queue.next, {}, 0
        local args = {}
        while current ~= self.queue do
            i = i + 1
            for j = 1, current.n do
                args[j] = tostring(current[j])
            end
            result[i] = '(i=' .. i .. ',timeout=' .. current.timeout .. ',enabled = ' .. tostring(current.enabled) .. ',f=' .. tostring(current.callback) .. ',args={' .. table.concat(args, ',',1,current.n) .. '})'
            current = current.next
        end
        return '{n = ' .. self.n .. ',queue=(' .. table.concat(result, ',', 1, i) .. ')}'
    end

    ---@class Stopwatch
    Stopwatch = {
        timer = {}                                  ---@type timer the countdown-timer permanently cycling
        ,   elapsed = 0.                            ---@type number the number of times the timer reached 0 and restarted
        ,   increaseElapsed = function() end        ---@type function timer callback function to increase numCycles by 1 for a specific Stopwatch.
    }
    Stopwatch.__index = Stopwatch

    local CYCLE_LENGTH = 3600. --time in seconds that a timer needs for one cycle. doesn't really matter.

    ---Creates a Stopwatch.
    ---@param startImmediately_yn boolean Set to true to start immediately. If not specified or set to false, the Stopwatch will not start to count upwards.
    function Stopwatch.create(startImmediately_yn)
        local new = {}
        setmetatable(new, Stopwatch)
        new.timer = CreateTimer()
        new.elapsed = 0.
        new.increaseElapsed = function() new.elapsed = new.elapsed + CYCLE_LENGTH end
        if startImmediately_yn then
            new:start()
        end
        return new
    end

    ---Starts or restarts a Stopwatch, i.e. resets the elapsed time of the Stopwatch to zero and starts counting upwards.
    function Stopwatch:start()
        self.elapsed = 0.
        TimerStart(self.timer, CYCLE_LENGTH, true, self.increaseElapsed)
    end

    ---Returns the time in seconds that a Stopwatch is currently running, i.e. the elapsed time since start.
    ---@return number
    function Stopwatch:getElapsed()
        return self.elapsed + TimerGetElapsed(self.timer)
    end

    ---Pauses a Stopwatch, so it will retain its current elapsed time, until resumed.
    function Stopwatch:pause()
        PauseTimer(self.timer)
    end

    ---Resumes a Stopwatch after having been paused.
    function Stopwatch:resume()
        self.elapsed = self.elapsed + TimerGetElapsed(self.timer)
        TimerStart(self.timer, CYCLE_LENGTH, true, self.increaseElapsed) --not using ResumeTimer here, as it actually starts timer from new with the remaining time and thus screws up TimerGetElapsed().
    end

    ---Destroys the timer object behind the Stopwatch. The Lua object will be automatically garbage collected once you ensure that there is no more reference to it.
    function Stopwatch:destroy()
        DestroyTimer(self.timer)
    end
end
if Debug and Debug.endFile then Debug.endFile() end