if Debug then Debug.beginFile "Missile W" end
OnInit.trig(function(require)
    require "TimerQueue"
    require "MissileSystem"

    local WSPELLID = FourCC('A001')

    local function onDestructableHit(missile, destructable, delay)
        KillDestructable(destructable)
    end

    local trigger = CreateTrigger()
    TriggerRegisterAnyUnitEventBJ(trigger, EVENT_PLAYER_UNIT_SPELL_EFFECT)
    TriggerAddAction(trigger, function()
        if GetSpellAbilityId() ~= WSPELLID then
            return
        end

        local player = GetTriggerPlayer()
        local caster = GetTriggerUnit()
        local x      = GetUnitX(caster)
        local y      = GetUnitY(caster)
        local z      = 50
        local tx     = GetSpellTargetX()
        local ty     = GetSpellTargetY()

        local count  = 50

        local theta
        local radius
        local missile

        local toX, toY, toZ

        ---@param missile Missile
        ---@param unit unit
        ---@param delay number
        local function onUnitHit(missile, unit, delay)
            if unit ~= caster and UnitAlive(unit) then
                KillUnit(unit)
            end
        end
        TimerQueue:callPeriodically(0.1, function() return count <= 0 end, function()
            count                  = count - 1
            theta                  = 2 * bj_PI * math.random()
            radius                 = math.random(0, 350)
            toX, toY, toZ          = tx + radius * math.cos(theta), ty + radius * math.sin(theta), 0
            missile                = SimpleMissile.create(player,
                "Abilities\\Weapons\\FireBallMissile\\FireBallMissile.mdl", x, y, z, toX, toY, toZ)
            missile:setTarget(toX, toY, toZ)
            missile:setMovementType(ArcMovement, 800, 50)
            missile.collisionSize  = 75
            missile.onUnit         = onUnitHit
            missile.onDestructable = onDestructableHit
            missile:launch()
        end)
    end)
end)
if Debug then Debug.endFile() end
