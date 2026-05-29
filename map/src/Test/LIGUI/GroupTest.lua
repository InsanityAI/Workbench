if Debug then Debug.beginFile "Test/LIGUI/GroupTest" end
OnInit.final("Test/LIGUI/GroupTest", function(require)
    require "TimerQueue"

    local stopwatch = Stopwatch.create(true)
    local oldPrint = print
    local function print(...)
        oldPrint("[" .. stopwatch:getElapsed() .. "]", ...)
    end

    GUI.RegisterUnitRemovedEventListener(function(removedUnit)
        print("Unit removal has occured!", removedUnit)
    end)

    TestUnit = CreateUnit(Player(0), FourCC('hpea'), 0, 0, 0)
    TestGroup = CreateGroup()
    GroupAddUnit(TestGroup, TestUnit)

    TimerQueue:callPeriodically(3.00, nil, function()
        print("Unit in group", BlzGroupGetSize(TestGroup))
    end)

    TimerQueue:callDelayed(5.00, function()
        RemoveUnit(TestUnit)
        print("Unit has been removed.")
    end)

    local unitA = CreateUnit(Player(0), FourCC('hpea'), 0, 0, 0)
    local unitB = CreateUnit(Player(0), FourCC('hpea'), 0, 0, 0)
    GroupAddUnit(TestGroup, unitA)
    GroupAddUnit(TestGroup, unitB)

    TimerQueue:callDelayed(5.00, function()
        local trig = CreateTrigger()
        TriggerRegisterPlayerChatEvent(trig, Player(0), "", false)
        TriggerAddCondition(trig, Condition(function()
            print("Lmao condition")
            return true
        end))
        TriggerAddAction(trig, function()
            print("Unit action")
        end)
    end)
    
end)
if Debug then Debug.endFile() end
