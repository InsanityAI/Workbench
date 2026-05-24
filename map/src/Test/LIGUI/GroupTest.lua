if Debug then Debug.beginFile "Test/LIGUI/GroupTest" end
OnInit.final("Test/LIGUI/GroupTest", function(require)
    require "TimerQueue"

    IngameConsole:makeShared()
    IngameConsole.create(Player(0))
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

    TimerQueue:callDelayed(5.00, function ()
        RemoveUnit(TestUnit)
        print("Unit has been removed.")
    end)

    local unitA = CreateUnit(Player(0), FourCC('hpea'), 0, 0, 0)
    local unitB = CreateUnit(Player(0), FourCC('hpea'), 0, 0, 0)
    GroupAddUnit(TestGroup, unitA)
    GroupAddUnit(TestGroup, unitB)
end)
if Debug then Debug.endFile() end
