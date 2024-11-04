if Debug then Debug.beginFile "ApplyOverTime" end
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
        VARIABLE_INT = 3
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

    ---@param self ApplyOverTimeBuilder
    ---@param applyFunc fun(...)
    ---@param progress number
    local function apply(self, applyFunc, progress)
        local params = {}

        for index, paramType in ipairs(self.paramType) do
            if paramType == ParamType.STATIC then
                params[index] = self.params[index]
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
