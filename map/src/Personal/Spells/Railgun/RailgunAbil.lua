if Debug then Debug.beginFile "RailgunAbil" end
OnInit.trig(function(require)
    --==================================================================================================
    --------------------------------Railgun Abil-----by-Insanity_AI-------------------------------------
    --==================================================================================================
    require "Railgun"
    require "GetPointZ" -- found in Dependencies
    require "SoundLib"

    --[[
        This is an example trigger for how you can setup Railgun ability, you can either use this or
        write your own logic that does not rely on unit abilities, if you so choose.
    ]]

    local ABILITY_ID = FourCC('A000')    -- Railgun ability code
    local RAILGUN_RANGE = 4000.00        -- Railgun maximum range
    local AIM_VISUAL_RADIUS = 100.00     -- Aim visualizers' obstacle checker radius
    local AIM_VISUAL_STEP_DELTA = 266.66 -- Distance between 2 aim visualizers
    local BEAM_STEP_DELTA = 40.00        -- Distance between points in the beam for obstacle checking
    local BEAM_WIDTH = 100.00            -- Width of the beam for damaging targets and obstacle checking
    local aimSound = Sound:new({ path = "war3mapImported\\Railgun-charge.wav", is3D = true })
    local fireSound = Sound:new({ path = "war3mapImported\\Railgun-fire.wav", is3D = true })

    local CASTER_ANIMATION_AIM = "stand ready" -- casting spell animation
    local CASTER_ANIMATION_FIRE = "spell"      -- starts effect of spell animation
    local CASTER_ANIMATION_STAND = "stand"     -- default animation after spell completes

    -- Utility class to store target position on
    ---@class RailgunEx: Railgun
    ---@field targetX number
    ---@field targetY number
    ---@field targetZ number

    -- Overriding the default visualizer so that the effects do not get hidden underneath this uneven terrain
    ---@param x number
    ---@param y number
    ---@param z number
    ---@return effect
    local function visualizerConstructor(x, y, z)
        return AddSpecialEffect("Abilities\\Spells\\Undead\\AbsorbMana\\AbsorbManaBirthMissile.mdl", x, y)
    end

    local spellInstances = {} ---@type table<unit, RailgunEx>

    ---@param caster unit
    ---@param targetX number
    ---@param targetY number
    ---@param targetZ number
    ---@return Railgun
    local function getSpellInstance(caster, targetX, targetY, targetZ)
        local instance = spellInstances[caster]

        if instance ~= nil then
            instance:removeAimVisuals()
        else
            instance = Railgun.create(RAILGUN_RANGE, AIM_VISUAL_RADIUS, AIM_VISUAL_STEP_DELTA, BEAM_STEP_DELTA, BEAM_WIDTH, nil, nil, nil, nil, nil, visualizerConstructor, nil) --[[@as RailgunEx]]
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

        local casterX, casterY, casterZ = GetUnitX(caster), GetUnitY(caster), BlzGetUnitZ(caster)
        local targetX, targetY = GetSpellTargetX(), GetSpellTargetY()
        local targetZ = GetPointZ(targetX, targetY)

        getSpellInstance(caster, targetX, targetY, targetZ):aim(casterX, casterY, casterZ, targetX, targetY, targetZ)
        SetUnitAnimation(caster, CASTER_ANIMATION_AIM)
        aimSound(1, false, nil, nil, caster)
        -- PlaySoundOnUnitBJ(gg_snd_Railgun_charge, 100, caster)
    end)

    local stopTrigger = CreateTrigger()
    TriggerRegisterAnyUnitEventBJ(stopTrigger, EVENT_PLAYER_UNIT_SPELL_ENDCAST)
    TriggerAddAction(stopTrigger, function()
        if GetSpellAbilityId() ~= ABILITY_ID then return end
        local caster = GetTriggerUnit()
        spellInstances[caster]:removeAimVisuals()
        spellInstances[caster] = nil
        SetUnitAnimation(caster, CASTER_ANIMATION_STAND)
    end)

    local fireTrigger = CreateTrigger()
    TriggerRegisterAnyUnitEventBJ(fireTrigger, EVENT_PLAYER_UNIT_SPELL_FINISH)
    TriggerAddAction(fireTrigger, function()
        if GetSpellAbilityId() ~= ABILITY_ID then return end
        local caster = GetTriggerUnit()
        local casterX, casterY, casterZ = GetUnitX(caster), GetUnitY(caster), BlzGetUnitZ(caster)
        local spell = spellInstances[caster]
        spell:fire(caster, casterX, casterY, casterZ, spell.targetX, spell.targetY, spell.targetZ)
        SetUnitAnimation(caster, CASTER_ANIMATION_FIRE)
        QueueUnitAnimation(caster, CASTER_ANIMATION_STAND)
        -- PlaySoundOnUnitBJ(gg_snd_Railgun_fire, 100, caster)
        fireSound(1, false, nil, nil, caster)
    end)
end)
if Debug then Debug.endFile() end
