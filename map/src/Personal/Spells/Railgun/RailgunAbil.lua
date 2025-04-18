if Debug then Debug.beginFile "RailgunAbil" end
OnInit.trig(function(require)
    require "Railgun"
    require "SyncedTable"

    local ABILITY_ID = FourCC('A000')
    local RAILGUN_RANGE = 4000.00
    local AIM_VISUAL_RADIUS = 100.00
    local AIM_VISUAL_STEP_DELTA = 266.66
    local BEAM_STEP_DELTA = 40.00
    local BEAM_WIDTH = 100.00

    local CASTER_ANIMATION_AIM = "stand ready"
    local CASTER_ANIMATION_FIRE = "spell"
    local CASTER_ANIMATION_STAND = "stand"

    ---@class RailgunEx: Railgun
    ---@field targetX number
    ---@field targetY number
    ---@field targetZ number

    local spellInstances = SyncedTable.create() ---@type table<unit, RailgunEx>

    ---@param caster unit
    ---@param targetX number
    ---@param targetY number
    ---@param targetZ number
    ---@return Railgun
    local function getSpellInstance(caster, targetX, targetY, targetZ)
        local instance = spellInstances[caster]

        if instance ~= nil then
            instance:RemoveAimVisuals()
        else
            instance = Railgun.create(RAILGUN_RANGE, AIM_VISUAL_RADIUS, AIM_VISUAL_STEP_DELTA, BEAM_STEP_DELTA, BEAM_WIDTH) --[[@as RailgunEx]]
            spellInstances[caster] = instance
        end

        instance.targetX = targetX
        instance.targetY = targetY
        instance.targetZ = targetZ
        return instance
    end

    local castTrigger = CreateTrigger()
    TriggerRegisterAnyUnitEventBJ(castTrigger, EVENT_PLAYER_UNIT_SPELL_CHANNEL)
    TriggerAddAction(castTrigger, function()
        if GetSpellAbilityId() ~= ABILITY_ID then return end

        local caster = GetTriggerUnit()

        local targetX, targetY = GetSpellTargetX(), GetSpellTargetY()
        local targetZ = GetPointZ(targetX, targetY)

        getSpellInstance(caster, targetX, targetY, targetZ):Aim(
            GetUnitX(caster), GetUnitY(caster), BlzGetUnitZ(caster),
            targetX, targetY, targetZ
        )

        SetUnitAnimation(caster, CASTER_ANIMATION_AIM)
    end)

    local stopTrigger = CreateTrigger()
    TriggerRegisterAnyUnitEventBJ(stopTrigger, EVENT_PLAYER_UNIT_SPELL_ENDCAST)
    TriggerAddAction(stopTrigger, function()
        if GetSpellAbilityId() ~= ABILITY_ID then return end
        local caster = GetTriggerUnit()
        spellInstances[caster]:RemoveAimVisuals()
        spellInstances[caster] = nil
        SetUnitAnimation(caster, CASTER_ANIMATION_STAND)
    end)

    local fireTrigger = CreateTrigger()
    TriggerRegisterAnyUnitEventBJ(fireTrigger, EVENT_PLAYER_UNIT_SPELL_FINISH)
    TriggerAddAction(fireTrigger, function()
        if GetSpellAbilityId() ~= ABILITY_ID then return end

        local caster = GetTriggerUnit()
        local spell = spellInstances[caster]
        spell:Fire(caster, GetUnitX(caster), GetUnitY(caster), BlzGetUnitZ(caster), spell.targetX, spell.targetY, spell.targetZ)
        spellInstances[caster] = nil
        SetUnitAnimation(caster, CASTER_ANIMATION_FIRE)
        QueueUnitAnimation(caster, CASTER_ANIMATION_STAND)
    end)
end)
if Debug then Debug.endFile() end
