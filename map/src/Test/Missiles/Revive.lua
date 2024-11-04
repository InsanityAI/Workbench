OnInit.final(function(require)
    require "TimerQueue"

    local trigger = CreateTrigger()
    TriggerRegisterDestDeathInRegionEvent(trigger, GetPlayableMapRect())
    TriggerAddCondition(trigger, Condition(function()
        local destructable = GetDyingDestructable()
        TimerQueue:callDelayed(10, function()
            DestructableRestoreLife(destructable, GetDestructableMaxLife(destructable), true)
        end)
    end))

    local trigger2 = CreateTrigger()
    TriggerRegisterAnyUnitEventBJ(trigger2, EVENT_PLAYER_UNIT_DEATH)
    TriggerAddAction(trigger2, function()
        local unit = GetTriggerUnit()
        local x    = GetUnitX(unit)
        local y    = GetUnitY(unit)
        local f    = GetUnitFacing(unit)

        if IsUnitType(unit, UNIT_TYPE_HERO) then
            ReviveHero(unit, x, y, true)
        else
            TimerQueue:callDelayed(5.00, function()
                CreateUnit(Player(0), GetUnitTypeId(unit), x, y, f)
            end)
        end
    end)
end)
