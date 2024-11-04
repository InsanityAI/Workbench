if Debug then Debug.beginFile "Missile E" end
OnInit.trig(function(require)
    require "MissileSystem"
    require "TimerQueue"

    local function onDestructableHit(missile, destructable, delay)
        KillDestructable(destructable)
    end

    local ESPELLID = FourCC('A002')
    local trigger = CreateTrigger()
    TriggerRegisterAnyUnitEventBJ(trigger, EVENT_PLAYER_UNIT_SPELL_EFFECT)
    TriggerAddAction(trigger, function()
        if GetSpellAbilityId ~= ESPELLID then
            return
        end

        local player = GetTriggerPlayer()
        local unit   = GetTriggerUnit()
        local x      = GetUnitX(unit)
        local y      = GetUnitY(unit)
        local tx     = GetSpellTargetX()
        local ty     = GetSpellTargetY()
        local count  = 50

        local function onUnitHit(missile, hit, delay)
            if hit ~= unit and UnitAlive(hit) then
                KillUnit(hit)
            end
        end

        TimerQueue:callPeriodically(0.2, function() return count <= 0 end, function()
            count                 = count - 1
            local theta           = 2 * bj_PI * math.random()
            local radius          = math.random(0, 600)
            local toX             = tx + radius * Cos(theta)
            local toY             = ty + radius * Sin(theta)
            local theta           = math.atan(ty - y, tx - x)
            local missile         = SimpleMissile.create(player,
                "Abilities\\Weapons\\AncientProtectorMissile\\AncientProtectorMissile.mdl", toX + 3000 * math.cos(theta),
                toY + 3000 * math.sin(theta), 1500, toX, toY)
            missile.collideZ      = CollideZMode.SAFE
            missile:setTarget(toX, toY)
            missile.collisionSize = 100
            missile:timedLife(2)
            missile:setModelSize(1.5)
            missile.onUnit = onUnitHit
            missile.onDestructable = onDestructableHit
            missile:setMovementType(BasicMovement, 700, 0)
            missile:launch()
        end)
    end)
end)
if Debug then Debug.endFile() end
