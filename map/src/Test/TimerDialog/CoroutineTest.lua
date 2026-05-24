if Debug then Debug.beginFile "CoroutineTest" end
OnInit.final("CoroutineTest", function(require)
    CreateUnit(Player(0), FourCC('hpea'), 0, 0, 0)
    CreateUnit(Player(0), FourCC('hfoo'), 0, 0, 0)
    CreateUnit(Player(0), FourCC('Hpal'), 0, 0, 0)
    CreateUnit(Player(0), FourCC('Hamg'), 0, 0, 0)
    CreateUnit(Player(0), FourCC('Hblm'), 0, 0, 0)

    --[[
    local function threadTest(execCount)
        print(I2S(execCount) .. ' - coroutine - ' .. GetUnitName(GetTriggerUnit()))
        print(I2S(execCount) .. ' - coroutine - ' .. GetPlayerName(GetTriggerPlayer()))
        TriggerSleepAction(3.00)
        print(I2S(execCount) .. ' - coroutine - ' .. GetUnitName(GetTriggerUnit()))
        print(I2S(execCount) .. ' - coroutine - ' .. GetPlayerName(GetTriggerPlayer()))
    end

    local execCount = 0
    local t = CreateTrigger()
    TriggerRegisterAnyUnitEventBJ(t, EVENT_PLAYER_UNIT_SELECTED)
    TriggerAddAction(t, function()
        execCount = execCount + 1
        local execCount = execCount
        print(I2S(execCount) .. ' - ' .. GetUnitName(GetTriggerUnit()))
        print(I2S(execCount) .. ' - ' .. GetPlayerName(GetTriggerPlayer()))
        TriggerSleepAction(3.00)
        print(I2S(execCount) .. ' - ' .. GetUnitName(GetTriggerUnit()))
        print(I2S(execCount) .. ' - ' .. GetPlayerName(GetTriggerPlayer()))
    end)
    --]]


    local t1 = CreateTrigger()
    local t2 = CreateTrigger()

    TriggerRegisterAnyUnitEventBJ(t1, EVENT_PLAYER_UNIT_ISSUED_POINT_ORDER)
    TriggerRegisterAnyUnitEventBJ(t2, EVENT_PLAYER_UNIT_SPELL_EFFECT)

    local orderCount = 0
    TriggerAddAction(t1, function()
        orderCount = orderCount + 1
        local orderCount = orderCount
        local loc = GetOrderPointLoc()
        print('Order ' .. I2S(orderCount), GetLocationX(loc), GetLocationY(loc), GetIssuedOrderId())
        TriggerSleepAction(5.00)
        local loc = GetOrderPointLoc()
        print('Order ' .. I2S(orderCount), GetLocationX(loc), GetLocationY(loc), GetIssuedOrderId())
    end)

    local spellCount = 0
    TriggerAddAction(t2, function()
        spellCount = spellCount + 1
        local spellCount = spellCount
        local loc = GetSpellTargetLoc()
        print('Spell ' .. I2S(spellCount), GetLocationX(loc), GetLocationY(loc), GetSpellAbilityId())
        TriggerSleepAction(5.00)
        local loc = GetSpellTargetLoc()
        print('Spell ' .. I2S(spellCount), GetLocationX(loc), GetLocationY(loc), GetSpellAbilityId())
    end)

end)
if Debug then Debug.endFile() end
