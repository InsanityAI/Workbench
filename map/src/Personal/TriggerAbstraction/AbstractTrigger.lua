if Debug then Debug.beginFile "TriggerAbstraction/AbstractTrigger" end
OnInit.module("TriggerAbstraction/AbstractTrigger", function(require)
    require "SetUtils"

    local oldEnableTrigger = EnableTrigger
    local oldDisableTrigger = DisableTrigger

    ---@class AbstractTriggerEvent
    ---@field package triggerEnabled boolean
    ---@field package actualTrigger trigger
    ---@field package listeners Set
    AbstractTriggerEvent = {}
    AbstractTriggerEvent.__index = AbstractTriggerEvent

    function AbstractTriggerEvent:notifyListeners()
        for listener in self.listeners:elements() do
            ---@cast listener AbstractTrigger
            if listener:isEnabled() and listener:evaluate() then
                listener:execute()
            end
        end
    end

    ---@param self AbstractTriggerEvent
    ---@param listener AbstractTrigger
    local function addEventListener(self, listener)
        self.listeners:add(listener)
        if (not self.triggerEnabled) and self.listeners:size() > 0 then
            oldEnableTrigger(self.actualTrigger)
        end
    end

    ---@param self AbstractTriggerEvent
    ---@param listener AbstractTrigger
    local function removeEventListener(self, listener)
        self.listeners:remove(listener)
        if self.triggerEnabled and self.listeners:size() == 0 then
            oldDisableTrigger(self.actualTrigger)
        end
    end

    ---@class AbstractTrigger
    ---@field private enabled boolean
    ---@field private waitOnSleep boolean -- REQUIRES LOGIC
    ---@field private execCount integer
    ---@field private evalCount integer
    ---@field private events Set
    ---@field private conditions Set
    ---@field private actions Set
    AbstractTrigger = {}
    AbstractTrigger.__index = AbstractTrigger

    ---@return AbstractTrigger
    function AbstractTrigger.create()
        return setmetatable({
            enabled = true,
            pauseOnWait = false,
            execCount = 0,
            evalCount = 0,
            conditions = Set.create(),
            actions = Set.create()
        }, AbstractTrigger)
    end

    ---@param state boolean? if undefined, switches trigger from enabled to disabled or from disabled to enabled, otherwise uses the state value
    function AbstractTrigger:toggle(state)
        if state then
            self.enabled = true
        elseif state == false then
            self.enabled = false
        else
            self.enabled = not self.enabled
        end
    end

    ---@return boolean
    function AbstractTrigger:isEnabled()
        return self.enabled
    end

    ---@param waitOnSleep boolean
    function AbstractTrigger:setWaitOnSleep(waitOnSleep)
        self.waitOnSleep = waitOnSleep
    end

    ---@return boolean
    function AbstractTrigger:isWaitOnSleep()
        return self.waitOnSleep
    end

    function AbstractTrigger:addEvent(event)
        self.events:add(event)
        addEventListener(event, self)
    end

    function AbstractTrigger:removeEvent(event)
        self.events:remove(event)
        removeEventListener(event, self)
    end

    function AbstractTrigger:clearEvents()
        for event in self.events:elements() do
            removeEventListener(event, self)
        end
        self.events:clear()
    end

    ---@param condition fun():boolean
    function AbstractTrigger:addCondition(condition)
        self.conditions:add(condition)
    end

    ---@param condition fun():boolean
    function AbstractTrigger:removeCondition(condition)
        self.conditions:remove(condition)
    end

    function AbstractTrigger:clearConditions()
        self.conditions:clear()
    end

    ---@return boolean
    function AbstractTrigger:evaluate()
        self.evalCount = self.evalCount + 1
        for condition in self.conditions:elements() do
            --[[@cast condition fun():boolean]]
            if not condition() then
                return false
            end
        end
        return true
    end

    ---@return integer
    function AbstractTrigger:getEvalCount()
        return self.evalCount
    end

    ---@param action function
    function AbstractTrigger:addAction(action)
        self.actions:add(action)
    end

    ---@param action function
    function AbstractTrigger:removeAction(action)
        self.actions:remove(action)
    end

    function AbstractTrigger:clearActions()
        self.actions:clear()
    end

    function AbstractTrigger:execute()
        self.execCount = self.execCount + 1
        for action in self.actions:elements() do
            action()
        end
    end

    ---@return integer
    function AbstractTrigger:getExecCount()
        return self.execCount
    end

    function AbstractTrigger:reset()
        self.execCount = 0
        self.evalCount = 0
    end
end)
if Debug then Debug.endFile() end
