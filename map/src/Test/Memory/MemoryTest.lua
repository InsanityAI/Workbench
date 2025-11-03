if Debug then Debug.beginFile "MemoryTest" end
OnInit.map("MemoryTest", function(require)
    require "ChatSystem"
    require "TimerQueue"

    ---@param chatEvent ChatEvent
    ---@param count string|number
    ---@param duration string|number
    ---@param rate string|number
    ChatCommandBuilder.create("TestMemory", function(chatEvent, count, duration, rate)
        local numCount = math.tointeger(count)
        local numDuration = tonumber(duration)
        local numRate = tonumber(rate)

        if not numCount or numCount < 0 then
            ChatService.errorMessage("numCount has to be a positive integer!", chatEvent.from)
            return
        end

        if not numDuration or numDuration < 0 then
            ChatService.errorMessage("numDuration has to be a positive number!", chatEvent.from)
            return
        end

        if not numRate or numRate < 0 then
            ChatService.errorMessage("numRate has to be a positive number!", chatEvent.from)
            return
        end

        local countPerRate = numCount / numDuration
        local timePassed = 0
        TimerQueue:callPeriodically(numRate, function()
            timePassed = timePassed + numRate
            return timePassed >= numDuration
        end, function()
            for i = 1, countPerRate do
                local tbl = {}
            end
        end)
    end)
    :description("Test memory by spamming table creation"):showInHelp()
    :argument("count", '10'):description("Amount of tables to be created")
    :argument("duration", '1'):description("Duration at which the test will run")
    :argument("rate", "0.1"):description("Rate at which the timer will do stuff")
    :register()
end)
if Debug then Debug.endFile() end
