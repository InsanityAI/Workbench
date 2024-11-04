if Debug then Debug.beginFile "Missile Q" end
OnInit.trig(function(require)
    require "MissileSystem"

    local QSPELLID = FourCC('A000')

    local trigger = CreateTrigger()
    TriggerRegisterAnyUnitEventBJ(trigger, EVENT_PLAYER_UNIT_SPELL_EFFECT)
    TriggerAddAction(trigger, function()
        if GetSpellAbilityId() ~= QSPELLID then
            return
        end
        local caster = GetTriggerUnit()
        local player = GetTriggerPlayer()
        local sourceX, sourceY = GetUnitX(caster), GetUnitY(caster)
        local target = GetSpellTargetUnit()
        local targetX, targetY = GetSpellTargetX(), GetSpellTargetY()

        local missile = SimpleMissile.create(player, "Abilities\\Weapons\\FireBallMissile\\FireBallMissile.mdl", sourceX,
            sourceY, 50, targetX, targetY, 50)
        missile:setMovementType(BasicMovement, 500, 0)
        if target then
            missile:setTarget(target) -- homing
        else
            -- to point target
            -- missile:setTarget(targetX, targetY, nil, true)

            -- or at direction target with range limit
            missile.range = 1500
        end
        missile:setVision(500)
        missile.collisionSize = 75

        missile.onPause = function(missile)
            print("Freezing")
        end

        missile.onResume = function(missile)
            print("Unfreezing")
        end

        missile.onUnit = function(missile, unit, delay)
            if unit ~= caster and UnitAlive(unit) then
                print("onHit - " .. GetUnitName(unit))
                KillUnit(unit)
            end
            if unit == target then
                missile.targetting = nil -- disable homing
            end
        end

        missile.onItem = function(missile, item, delay)
            print("OnItem: Removing")
            RemoveItem(item)
        end

        missile.onDestructable = function(missile, destructable, delay)
            print("onDestructable: Killing")
            KillDestructable(destructable)
        end

        missile.onDestroy = function(missile)
            DestroyEffect(AddSpecialEffect("Abilities\\Weapons\\Mortar\\MortarMissile.mdl", missile.missileX,
                missile.missileY))
            print("onDestroy: Cleaning")
        end

        missile:launch()
    end)
end)
if Debug then Debug.endFile() end
