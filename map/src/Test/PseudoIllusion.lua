if Debug then Debug.beginFile "PseudoIllusion" end
OnInit.trig("PseudoIllusion", function()
    local TriggerPseudoIllusion = CreateTrigger()
    TriggerRegisterAnyUnitEventBJ(TriggerPseudoIllusion, EVENT_PLAYER_UNIT_SPELL_EFFECT)
    TriggerAddCondition(TriggerPseudoIllusion, Condition(function() return GetSpellAbilityId() == FourCC('API1') end))
    TriggerAddAction(TriggerPseudoIllusion, function()
        local UnitTrigger = GetSpellAbilityUnit()
        local PlayerTrigger = GetOwningPlayer(UnitTrigger)
        local UnitTarget = GetSpellTargetUnit()
        local LevelTarget = GetHeroLevel(UnitTarget)
        local UnitTargetType = GetUnitTypeId(UnitTarget)

        local UnitTargetTypeId = string.char((UnitTargetType >> 24) & 0xFF, (UnitTargetType >> 16) & 0xFF, (UnitTargetType >> 8) & 0xFF, UnitTargetType & 0xFF)
        local UnitIllusionTypeId = "I" .. UnitTargetTypeId:sub(2)
        local UnitIllusionType = (string.byte(UnitIllusionTypeId, 1) << 24) | (string.byte(UnitIllusionTypeId, 2) << 16) | (string.byte(UnitIllusionTypeId, 3) << 8) | string.byte(UnitIllusionTypeId, 4)

        local UnitIllusion = CreateUnit(PlayerTrigger, UnitIllusionType, GetUnitX(UnitTarget) + 200 * Cos(GetRandomReal(0, 6.283)), GetUnitY(UnitTarget) + 200 * Sin(GetRandomReal(0, 6.283)),
            GetUnitFacing(UnitTarget))
        UnitApplyTimedLife(UnitIllusion, FourCC('BTLF'), 60.0)

        if GetLocalPlayer() == PlayerTrigger then
            SetUnitVertexColor(UnitIllusion, 15, 63, 183, 223)
        end

        local Effect = AddSpecialEffectTarget("Abilities\\Spells\\Items\\AIil\\AIilTarget.mdl", UnitIllusion, "origin")
        DestroyEffect(Effect)

        if IsUnitType(UnitTarget, UNIT_TYPE_HERO) then
            if GetHeroLevel(UnitIllusion) ~= LevelTarget then
                SetHeroLevel(UnitIllusion, LevelTarget, false)
            end
            SuspendHeroXP(UnitIllusion, true)
        end

        SetUnitState(UnitIllusion, UNIT_STATE_LIFE, GetUnitState(UnitTarget, UNIT_STATE_LIFE))
        SetUnitState(UnitIllusion, UNIT_STATE_MANA, GetUnitState(UnitTarget, UNIT_STATE_MANA))

        for AbilityIndex = 0, 15 do
            local Ability = BlzGetUnitAbilityByIndex(UnitTarget, AbilityIndex)
            if not Ability then break end

            if not BlzGetAbilityBooleanField(Ability, ABILITY_BF_ITEM_ABILITY) then
                local AbilityId = BlzGetAbilityId(Ability)
                UnitAddAbility(UnitIllusion, AbilityId)
                SetUnitAbilityLevel(UnitIllusion, AbilityId, GetUnitAbilityLevel(UnitTarget, AbilityId))
            end
        end

        for ItemIndex = 0, 5 do
            local Item = UnitItemInSlot(UnitTarget, ItemIndex)
            if Item then
                local ItemIllusion = CreateItem(GetItemTypeId(Item), GetUnitX(UnitIllusion), GetUnitY(UnitIllusion))
                SetItemCharges(ItemIllusion, GetItemCharges(Item))
                UnitAddItem(UnitIllusion, ItemIllusion)
            end
        end
    end)
end)
if Debug then Debug.endFile() end
