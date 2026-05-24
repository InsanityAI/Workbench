function Guardian_Relentless_Charge()
    -- Set local variables crucual for the spell
    local caster, target = GetTriggerUnit(), GetSpellTargetUnit()
    local radius,slowDuration,slowAmount,damage, speed, MINIMUM_DISTANCE,cooldown = Guardian_Relentless_Charge_Config(caster)
    local delay = 0.03
    local alreadyTargeted = {}
    local casterPropWindow = GetUnitPropWindow(caster)
    local spellDone = false

    -- Prevent all movement from caster
    SetUnitPropWindow(caster,0)

    -- Create a DUMMY unit that casts Slow on affected targets
    UnitAddAbility(DUMMY,ABILITY_ID.slow)
    BlzSetAbilityRealLevelField(BlzGetUnitAbility(DUMMY, ABILITY_ID.slow),ABILITY_RLF_DURATION_HERO, 0, slowDuration)
    BlzSetAbilityRealLevelField(BlzGetUnitAbility(DUMMY, ABILITY_ID.slow),ABILITY_RLF_DURATION_NORMAL, 0, slowDuration)
    BlzSetAbilityRealLevelField(BlzGetUnitAbility(DUMMY, ABILITY_ID.slow),ABILITY_RLF_MOVEMENT_SPEED_FACTOR_SLO1, 0, slowAmount)
    IncDecAbilityLevel(DUMMY,ABILITY_ID.slow)

    -- Start a looping timer that, each time it expires, runs a set of code
    local tim = CreateTimer()
    TimerStart(tim,delay,true,function()
        -- Fetch important information to handle the effects during movement
        local cx, cy, tx, ty = GetUnitX(caster),GetUnitY(caster),GetUnitX(target),GetUnitY(target)
        local angle = AngleBetweenXYs(cx,cy,tx,ty)
        local distance = DistanceBetweenXYs(cx,cy,tx,ty)
        local newX, newY = PolarProjectionXY(cx,cy,speed,angle)

        -- Move the Caster forward and lock it's facing towards the target
        SetUnitXY(caster,newX,newY)
        SetUnitFacingTimed(caster, angle,0)
        if GetRandomInt(1,10) >= 8 then
            DestroyEffect(AddSpecialEffect(VFX, newX,newY))
        end

        GroupEnumUnitsInRange(nilGroup,newX,newY,radius,Filter(function()
            local u = GetFilterUnit()

            if UnitAlive(u) and IsUnitEnemy(u, GetOwningPlayer(caster)) and alreadyTargeted[u] == nil then
                alreadyTargeted[u] = true
                -- Move the DUMMY so that it's in range for the target 
                SetUnitXY(DUMMY,cx,cy)

                -- Have caster damage the affected unit and then have DUMMY apply slow to them as well
                UnitDamageTarget(caster,u, damage, false, false, ATTACK_TYPE, DAMAGE_TYPE, WEAPON_TYPE)
                IssueTargetOrder(DUMMY, "slow", u)
            end

            -- Check if caster has reached their destination
            if distance <= MINIMUM_DISTANCE or not UnitAlive(caster) or spellDone == true then
                
                -- Destination reached, end spell and clean up
                print(spellDone)
                spellDone = true
                print(spellDone)
                PauseTimer(tim)
                DestroyTimer(tim)
                SetUnitPropWindow(caster,casterPropWindow)

                -- "Taunt" nearby affected units
                IssueTargetOrder(u,"attack",caster)
                UnitResetCooldown(caster)
                BlzStartUnitAbilityCooldown(caster,GetSpellAbilityId(),cooldown)
                print(caster," ",GetSpellAbilityId()," ",cooldown)
            else
                -- Spell is still going
                -- Do Nothing
            end
            return false
        end))
    end)
end