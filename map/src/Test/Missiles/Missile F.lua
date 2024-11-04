if Debug then Debug.beginFile "Missiles F" end
OnInit.trig(function(require)
    require "MissileSystem"

    local FSPELLID = FourCC('A005')
    local trigger = CreateTrigger()
    TriggerRegisterAnyUnitEventBJ(trigger, EVENT_PLAYER_UNIT_SPELL_EFFECT)
    TriggerAddAction(trigger, function()
        if GetSpellAbilityId ~= FSPELLID then
            return
        end

        local caster = GetTriggerUnit()
        local player = GetTriggerPlayer()
        local casterX, casterY = GetUnitX(caster), GetUnitY(caster)
        local a = 0

        local function onUnitHit(missile, unit, delay)
            if unit ~= caster and UnitAlive(unit) then
                KillUnit(unit)
            end
        end

        local function onDestructableHit(missile, destructable, delay)
            KillDestructable(destructable)
        end

        local movement = BasicMovement.create(1050, 0)
        for i = 0, 9 do
            local this = Missile.create(player, casterX,casterY, 0)
            local targetting = PointTargetting.create(casterX + 400*math.cos(a), casterY + 400*math.sin(a), 0)
            targetting:applyToMissile(this)
            movement:applyToMissile(this)
            this.collisionSize = 125
            local effect = MissileEffect.create()
            effect:setModel("Abilities\\Spells\\Other\\BreathOfFire\\BreathOfFireMissile.mdl")
            effect:attachToMissile(this)

            this.onUnit = onUnitHit
            this.onDestructable = onDestructableHit

            this:launch()
            a = a + 36*bj_DEGTORAD
        end

    end)
end)
if Debug then Debug.endFile() end