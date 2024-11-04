if Debug then Debug.beginFile "Missile D" end
OnInit.trig(function(require)
    require "MissileSystem"

    local DSPELLID = FourCC('A004')

    local trigger = CreateTrigger()
    TriggerRegisterAnyUnitEventBJ(trigger, EVENT_PLAYER_UNIT_SPELL_EFFECT)
    TriggerAddAction(trigger, function ()
        if GetSpellAbilityId() ~= DSPELLID then
            return
        end

        local caster = GetTriggerUnit()
        local player = GetTriggerPlayer()
        local casterX, casterY = GetUnitX(caster), GetUnitY(caster)

        local this = Missile.create(player, casterX, casterY, 50)
        local effect = MissileEffect.create()
        effect:setModel("units\\human\\phoenix\\phoenix")
        effect:attachToMissile(this)
        effect:setAnimation(5)
        effect:setTimeScale(3)
        effect:setPlayerColor(3)
        effect:setAlpha(128)
        effect:setColor(123, 67, 32)
        this:setVision(500)
        local movement = ArcMovement.create(1000, 40)
        movement:applyToMissile(this)
        local targetting = PointTargetting.create(GetSpellTargetX(), GetSpellTargetY(), 50)
        targetting:applyToMissile(this)

        -- this:arc(GetRandomReal(0, 35))
        -- this:curve(GetRandomReal(15, 30) * GetRandomInt(-1, 1))

        this.onFinish = function(missile, delay)
            targetting:setPosition(GetUnitX(caster), GetUnitY(caster), 50)
            targetting:applyToMissile(missile)
            missile.nextMissileX = missile.missileX
            missile.nextMissileY = missile.missileY
            missile.nextMissileZ = missile.missileZ
            missile.nextGroundAngle = missile.groundAngle - math.pi
            missile.nextHeightAngle = missile.heightAngle - math.pi
        end

        this:launch()
    end)
end)
if Debug then Debug.endFile() end
