if Debug then Debug.beginFile "Missile R" end
OnInit.trig(function(require)
    require "MissileSystem"
    require "TimerQueue"
    require "SetUtils"

    local RSPELLID = FourCC('A003')
    local trigger = CreateTrigger()
    TriggerRegisterAnyUnitEventBJ(trigger, EVENT_PLAYER_UNIT_SPELL_EFFECT)
    TriggerAddAction(trigger, function()
        if GetSpellAbilityId() ~= RSPELLID then
            return
        end

        local player = GetTriggerPlayer()
        local caster = GetTriggerUnit()
        local casterX, casterY = GetUnitX(caster), GetUnitY(caster)

        local movement = BasicMovement.create(500, 0)

        for unit in SetUtils.getUnitsInRange(GetSpellTargetX(), GetSpellTargetY(), 500):elements() do
            if UnitAlive(unit) and unit ~= caster then
                local hammer = Missile.create(player, casterX, casterY, 50)
                movement:applyToMissile(hammer)
                local targetting = UnitTargetting.create(unit)
                targetting:applyToMissile(hammer)

                local effect = MissileEffect.create()
                effect:setModel("Abilities\\Spells\\Human\\StormBolt\\StormBoltMissile.mdl")
                effect:attachToMissile(hammer)

                hammer.onUnit = function(missile, hitUnit, delay)
                    if unit == hitUnit then
                        if UnitAlive(hitUnit) then
                            KillUnit(unit)
                        end
                        missile:destroy()
                    end
                end

                hammer:launch()
            end
        end

    end)
end)
if Debug then Debug.endFile() end