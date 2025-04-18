if Debug then Debug.beginFile "ApplyOverTime" end
--[[
    ApplyOverTime v1.0
    ===================

    ApplyOverTime.create(executor?)
        * Creates a new AOT instance for your purpose
        * Isn't actually required since ApplyOverTime is also an instance of itself, so you can
            just do ApplyOverTime:* calls without using this constructor. (It's using TimerQueue itself)
        - executor: TimerQueue?
        -> ApplyOverTime new AOT instance

    ApplyOverTime:Builder()
        * Get a new AOT (task) Builder, using the following methods you can construct an easy
            timed execution with value easing support.
        -> ApplyOverTimeBuilder

    ApplyOverTimeBuilder:execute(period, rate, applyFunc)
        * Builds the AOT task and starts executing it. This method can only be called once for
            particular AOTBuilder instance.
        - period : number - time over which something needs to be applied (best to keep this as multiple of 'rate')
        - rate : number - periodic timer's period at which something is applied (periodic timer period)
        - applyFunc : function - function that gets called every 'rate' over a 'period'
            - It is expected that the user will supply arguments to the builder for this applyFunc
                before this method is executed!

    ApplyOverTimeBuilder:addStaticParam(param)
        * Adds a parameter to the function that will be executed, this parameter is constant throughout the 'period'.
        - param: unknown - any parameter, depending on which function will be executed
        -> ApplyOverTimeBuilder - same builder, returned just for API purposes

    ApplyOverTimeBuilder:addVariable(startValue, endValue, forceInt, easeFunc?)
        * Adds a variable that changes over 'period' for every 'rate' from 'startValue' to 'endValue'
        * The variable's value change is influenced by easeFunc
        - startValue: number - starting value of the variable
        - endValue: number - final value of the variable
        - forceInt: boolean - after changing/easing, use math.modf to get an integer value (for natives)
        - easeFunc?: fun(t: number): number - by default uses Linear, which returns the value itself.
            - easing functions are expected to receive an argument 't'
                which represents the progress of easing: values [0.00, 1.00]
            - functions are also expected to return the from the following range: [0.00, 1.00]
            - the value returned by the easeFunc is further used to calculate the variable value for the 'applyFunc' call

    AOTBuilders are bound to the AOT that constructed them, they cannot be changed.

    Example 1: - Lower an effect to the Z = 0 slowly over 20 seconds (no easing, linear)
    ApplyOverTime:Builder()
            :addStaticParam(effect)
            :addVariable(100.00, 0.00, false)
            :execute(20, 0.1, BlzSetSpecialEffectZ)

    Example 2: - Overwrite unit health back to full HP over 5 seconds with 1 second rate. (no easing, linear)
    ApplyOverTime:Builder()
            :addStaticParam(whichUnit)
            :addStaticParam(UNIT_STATE_LIFE)
            :addVariable(GetUnitState(whichUnit, UNIT_STATE_LIFE), GetUnitState(whichUnit, UNIT_STATE_MAX_LIFE), false)
            :execute(5, 1, SetUnitState)
        - Note: It's overwrite for a reason, not 'heal'

    Example 3: - Animate frame movement (Y-axis) with easeInOutSine
    ApplyOverTime:Builder()
            :addStaticParam(frame)
            :addStaticParam(FRAMEPOINT_BOTTOMLEFT)
            :addStaticParam(targetFrame)
            :addStaticParam(FRAMEPOINT_TOPLEFT)
            :addStaticParam(0)
            :addVariable(-0.15, 0, false, easeInOutSine)
            :execute(0.5, 0.1, BlzFrameSetPoint)
    ]]
OnInit.module("ApplyOverTime", function(require)
    require "TimerQueue"

    ---@param t number
    ---@return number
    local Linear = function(t)
        return t
    end

    ---@enum ParamType
    local ParamType = {
        STATIC = 1,
        VARIABLE = 2,
        VARIABLE_INT = 3,
        SUPPLIER = 4
    }

    ---@class ApplyOverTime
    ---@field executor TimerQueue
    ApplyOverTime = { executor = TimerQueue }
    ApplyOverTime.__index = ApplyOverTime

    ---@param executor TimerQueue?
    ---@return ApplyOverTime
    function ApplyOverTime.create(executor)
        return setmetatable({ executor = executor or TimerQueue.create() }, ApplyOverTime)
    end

    ---@class ApplyOverTimeBuilder
    ---@field package executor TimerQueue
    ---@field package params unknown[]
    ---@field package endParams number[]
    ---@field package paramType ParamType[]
    ---@field package easeFuncs (fun(t: number):number)[]
    ---@field package variableCount integer
    ---@field package t number
    ---@field package rate number
    ApplyOverTimeBuilder = {}
    ApplyOverTimeBuilder.__index = ApplyOverTimeBuilder

    ---@return ApplyOverTimeBuilder
    function ApplyOverTime:Builder()
        return setmetatable({
            executor = self.executor,
            params = {},
            endParams = {},
            paramType = {},
            easeFuncs = {},
            variableCount = 0,
            t = 0
        }, ApplyOverTimeBuilder)
    end

    ---@param startValue number
    ---@param endValue number
    ---@param forceInt boolean
    ---@param easeFunc (fun(t: number): number)?
    ---@return ApplyOverTimeBuilder
    function ApplyOverTimeBuilder:addVariable(startValue, endValue, forceInt, easeFunc)
        self.variableCount = self.variableCount + 1
        self.params[self.variableCount] = startValue
        self.endParams[self.variableCount] = endValue
        self.easeFuncs[self.variableCount] = easeFunc or Linear
        self.paramType[self.variableCount] = forceInt and ParamType.VARIABLE_INT or ParamType.VARIABLE
        return self
    end

    ---@param param unknown
    ---@return ApplyOverTimeBuilder
    function ApplyOverTimeBuilder:addStaticParam(param)
        self.variableCount = self.variableCount + 1
        self.params[self.variableCount] = param
        self.paramType[self.variableCount] = ParamType.STATIC
        return self
    end

    ---@param supplier fun():unknown
    ---@return ApplyOverTimeBuilder
    function ApplyOverTimeBuilder:addVariableSupplier(supplier)
        self.variableCount = self.variableCount + 1
        self.params[self.variableCount] = supplier
        self.paramType[self.variableCount] = ParamType.SUPPLIER
        return self
    end

    ---@param self ApplyOverTimeBuilder
    ---@param applyFunc fun(...)
    ---@param progress number
    local function apply(self, applyFunc, progress)
        local params = {}

        for index, paramType in ipairs(self.paramType) do
            if paramType == ParamType.STATIC then
                params[index] = self.params[index]
            elseif paramType == ParamType.SUPPLIER then
                params[index] = self.params[index]()
            else
                local var = self.params[index] + (self.endParams[index] - self.params[index]) * self.easeFuncs[index](progress)
                if paramType == ParamType.VARIABLE_INT then
                    params[index] = math.modf(var)
                else
                    params[index] = var
                end
            end
        end

        applyFunc(table.unpack(params))
    end

    ---@param self ApplyOverTimeBuilder
    ---@param applyFunc fun(...)
    ---@param period number
    ---@return boolean
    local function stopCondition(self, applyFunc, period)
        if self.t >= period then
            apply(self, applyFunc, 1)
            return true
        end
        return false
    end

    ---@param self ApplyOverTimeBuilder
    ---@param applyFunc fun(...)
    ---@param period number
    local function runFunc(self, applyFunc, period)
        self.t = self.t + self.rate
        apply(self, applyFunc, self.t / period)
    end

    ---@param period number
    ---@param rate number
    ---@param applyFunc fun(...)
    function ApplyOverTimeBuilder:execute(period, rate, applyFunc)
        self.rate = rate
        self.executor:callPeriodically(rate, stopCondition, runFunc, self, applyFunc, period)
        apply(self, applyFunc, 0)
        setmetatable(self, nil) -- make sure users can't execute multiple times
    end
end)
if Debug then Debug.endFile() end
