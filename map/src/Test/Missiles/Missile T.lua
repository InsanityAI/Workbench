if Debug then Debug.beginFile "Missile T" end
OnInit.trig(function(require)
    require "MissileSystem"
    require "SetUtils"

    local TSPELLID = FourCC('A006')
    local trigger = CreateTrigger()
    TriggerRegisterAnyUnitEventBJ(trigger, EVENT_PLAYER_UNIT_SPELL_EFFECT)
    TriggerAddAction(trigger, function()
        if GetSpellAbilityId() ~= TSPELLID then
            return
        end
        local caster = GetTriggerUnit()
        local casterX, casterY = GetUnitX(caster), GetUnitY(caster)
        for missile in MissileSystem.missiles:elements() do
            if (missile.missileX - casterX) ^ 2 + (missile.missileY - casterY) ^ 2 <= 350 ^ 2 then
                if missile.paused then
                    missile:pause(false)
                else
                    missile:pause(true)
                end
            end
        end
    end)
end)
if Debug then Debug.endFile() end
