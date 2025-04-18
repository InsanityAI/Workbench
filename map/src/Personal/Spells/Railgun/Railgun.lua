if Debug then Debug "Railgun" end
--==================================================================================================
-----------------------------------Railgun-----by-Insanity_AI---------------------------------------
--==================================================================================================
--  Setup:  Create a Railgun ability and modify trigger spell condition.
--          Create a dummy unit for trajectory visualizaton.
--          Make sure to match those objectIDs with configuration settings in here:
--          Primarily in SpellCondition() and in the Visuals category; VISUALIZATION_ID
--  A bit of configuration info:
--          You can edit in the Configuration Section just down below.
--          Each configurable function or variable has a little comment describing what it does.
--          There are also functions that are responsible for damaging units, killing destructables,
--          And blacklisting them, those are all at your disposal.
--          I added a lot of visual configuration, I'm pretty sure you can use things like GetTriggerUnit()
--          in there, so I'm pretty sure that alone opens a lot of doors and posibilities.
--
--  About the damage:
--          At the moment it deals percentage of target's max health.
--          The damage is stacked on the target depending on how close they're to the beam,
--          which is determined by the RADIUS.
--          It goes up from 0% to 90%(in configuration) depending on how close the target is
--          to the beam.
--
--  Limitation:
--          It will shoot through terrain hills, so I'd suggest using some sort of pathingblockers
--          ... that is, unless you don't want this intended interaction (or lack of.)
--
--  Modifications:
--          Cast time, cooldown and mana cost is edited in the object editor,
--          as for the other things, they're editable right here.
--
--==================================================================================================
OnInit.module("Railgun", function(require)
    require "SetUtils"
    require "TimerQueue"
    require "ApplyOverTime"
    require "typeof"

    local aot = ApplyOverTime.create(TimerQueue)
    local rect = Rect(0, 0, 0, 0)

    local defaultDestructFilter = Filter(function()
        --Any additions you'd like to add here?
        local destructType = GetDestructableTypeId(GetFilterDestructable())

        --if the destructable is alive and is not a pathblocker of any kind.
        if GetDestructableLife(GetFilterDestructable()) <= 0 then
            return false
        end
        return not ((destructType == 'YTlb') or (destructType == 'YTab') or (destructType == 'YTpb') or (destructType == 'YTfb'))
    end)

    ---@param caster unit
    ---@param widget widget
    ---@param squaredDistance number
    ---@param beamWidthSquared number
    local function defaultTargetHandler(caster, widget, squaredDistance, beamWidthSquared)
        --Function responsible for damaging units, you can edit this however you'd like.
        --squaredDistance is the distance of the unit from the beam... squared.
        if (widget ~= caster) then
            local widgetType = typeof(widget)
            if widgetType == 'unit' then
                local damage = (beamWidthSquared - squaredDistance) / beamWidthSquared
                if damage > 0.90 then
                    damage = 0.90
                end
                damage = damage * GetUnitState(widget --[[@as unit]], UNIT_STATE_MAX_LIFE)
                UnitDamageTarget(caster, widget, damage, true, false, ATTACK_TYPE_CHAOS, DAMAGE_TYPE_UNKNOWN, WEAPON_TYPE_WHOKNOWS)
            elseif widgetType == 'destructable' then
                SetDestructableLife(widget --[[@as destructable]], 0)
            else
                return -- ignore items
            end
            DestroyEffect(AddSpecialEffectTarget("Objects\\Spawnmodels\\NightElf\\NECancelDeath\\NECancelDeath.mdl", widget, "chest"))
        end
    end

    ---@alias Beam unknown
    ---@alias BeamVisualConstructor fun(startX: number, startY: number, startZ: number, endX: number, endY: number, endZ: number): Beam

    ---@type BeamVisualConstructor
    local function defaultBeamConstructor(startX, startY, startZ, endX, endY, endZ)
        local beams = {}
        local lightning ---@type lightning
        for i = 1, 5 do
            lightning = AddLightningEx('LEAS', true, endX, endY, endZ + 60.0, startX, startY, startZ + 60.0)
            SetLightningColor(lightning, 1.00, 1.00, 0.75, 1.00)
            beams[i] = lightning
        end
        return beams
    end

    ---@param beam Beam
    local function defaultBeamDestructor(beam)
        aot:Builder()
            :addStaticParam(beam)
            :addVariable(1.0, 0.0, false)
        ---@type fun(thisBeam: lightning[], alpha: number)
            :execute(0.2, 0.04, function(thisBeam, alpha)
                for _, lightning in ipairs(thisBeam) do
                    SetLightningColor(lightning, GetLightningColorR(lightning), GetLightningColorG(lightning), GetLightningColorB(lightning), alpha)
                end
            end)
        TimerQueue:callDelayed(0.21, function(thisBeam)
            for index, lightning in ipairs(thisBeam) do
                thisBeam[index] = nil
                DestroyLightning(lightning)
            end
        end, beam)
    end

    ---@alias AimVisual unknown
    ---@alias AimVisualConstructor fun(x: number, y: number, z: number): AimVisual

    ---@type AimVisualConstructor
    local function defaultVisualConstructor(x, y, z)
        local visualizer = AddSpecialEffect("Objects\\Spawnmodels\\NightElf\\NECancelDeath\\NECancelDeath.mdl", x, y)
        BlzSetSpecialEffectZ(visualizer, z)
        return visualizer
    end

    ---@class Railgun
    ---@field package range number
    ---@field package aimVisualRadius number
    ---@field package aimVisualStepDelta number
    ---@field package beamStepDelta number
    ---@field package beamWidth number
    ---@field package unitFilter filterfunc?
    ---@field package destructableFilter filterfunc
    ---@field package aimVisuals AimVisual[]
    ---@field package beamConstructor BeamVisualConstructor
    ---@field package beamDestructor fun(beams: Beam)
    ---@field package targetHandler fun(caster: unit, target: widget, squaredDistance: number, beamWidthSquared: number)
    ---@field package aimVisualConstructor AimVisualConstructor
    ---@field package aimVisualDestructor fun(aimVisual: AimVisual)
    Railgun = {}
    Railgun.__index = Railgun

    ---@param range number
    ---@param aimVisualRadius number
    ---@param aimVisualStepDelta number
    ---@param beamStepDelta number
    ---@param beamWidth number
    ---@param unitFilter filterfunc?
    ---@param destructableFilter filterfunc?
    ---@param beamConstructor BeamVisualConstructor?
    ---@param beamDestructor fun(beams: Beam)?
    ---@param targetHandler fun(caster: unit, target: widget, squaredDistance: number, beamWidthSquared: number)?
    ---@param aimVisualConstructor AimVisualConstructor?
    ---@param aimVisualDestructor fun(aimVisual: AimVisual)?
    function Railgun.create(range, aimVisualRadius, aimVisualStepDelta, beamStepDelta, beamWidth, unitFilter, destructableFilter,
                            beamConstructor, beamDestructor, targetHandler, aimVisualConstructor, aimVisualDestructor)
        return setmetatable({
            range = range,
            aimVisualRadius = aimVisualRadius,
            aimVisualStepDelta = aimVisualStepDelta,
            beamStepDelta = beamStepDelta,
            beamWidth = beamWidth,
            unitFilter = unitFilter,
            destructableFilter = destructableFilter or defaultDestructFilter,
            beamConstructor = beamConstructor or defaultBeamConstructor,
            beamDestructor = beamDestructor or defaultBeamDestructor,
            targetHandler = targetHandler or defaultTargetHandler,
            aimVisualConstructor = aimVisualConstructor or defaultVisualConstructor,
            aimVisualDestructor = aimVisualDestructor or DestroyEffect
        }, Railgun)
    end

    function Railgun:RemoveAimVisuals()
        for index, aimVisual in ipairs(self.aimVisuals) do
            self.aimVisualDestructor(aimVisual)
            self.aimVisuals[index] = nil
        end
    end

    ---@param casterX number
    ---@param casterY number
    ---@param casterZ number
    ---@param targetX number
    ---@param targetY number
    ---@param targetZ number
    function Railgun:Aim(casterX, casterY, casterZ, targetX, targetY, targetZ)
        local angle = math.atan(targetY - casterY, targetX - casterX)
        local offsetX = self.aimVisualStepDelta * math.cos(angle)
        local offsetY = self.aimVisualStepDelta * math.sin(angle)
        local iterations = math.modf(self.range / self.aimVisualStepDelta)
        local offsetZ = (targetZ - casterZ) / self.range

        local tempX, tempY, tempZ = casterX, casterY, casterZ
        for _ = 1, iterations do
            tempX = tempX + offsetX
            tempY = tempY + offsetY
            tempZ = tempZ + offsetZ
            table.insert(self.aimVisuals, self.aimVisualConstructor(tempX, tempY, tempZ))

            SetRect(rect,
                tempX - self.aimVisualRadius,
                tempY - self.aimVisualRadius,
                tempX + self.aimVisualRadius,
                tempY + self.aimVisualRadius)
            if SetUtils.getDestructablesInRectMatching(rect, self.destructableFilter):size() > 0 then
                break;
            end
        end
    end

    ---@param tarX number
    ---@param tarY number
    ---@param startX number
    ---@param startY number
    ---@param angle number
    ---@return number
    local function distanceFromBeam(tarX, tarY, startX, startY, angle)
        --A slightly modified Distance between a line and a point formula
        --Ax + By + C = 0 => -ax + y + b = 0 from y = ax - b, where a = tan(angle) and b = a(x1) - y1
        --Formula: |Ax + By + C|/Sqrt(A^2 + B^2) => ((-ax + y + b)^2)/(a^2 + 1)
        local angleT = math.tan(angle)
        return ((-angleT * tarX + tarY + angleT * startX - startY) ^ 2) / ((angleT ^ 2) + 1)
    end

    ---@param caster unit
    ---@param startX number
    ---@param startY number
    ---@param startZ number
    ---@param targetX number
    ---@param targetY number
    ---@param targetZ number
    function Railgun:Fire(caster, startX, startY, startZ, targetX, targetY, targetZ)
        local angle = math.atan(targetY - startY, targetX - startX)
        local offsetX, offsetY = self.beamStepDelta * math.cos(angle), self.beamStepDelta * math.sin(angle)
        local steps = math.modf(self.range / self.beamStepDelta)
        local offsetZ = (targetZ - startZ) / steps
        local maxRangeSquared = self.beamWidth ^ 2

        local i = 1
        targetX, targetY = startX, startY
        while i <= steps do
            targetX = targetX + offsetX
            targetY = targetY + offsetY
            SetRect(rect, targetX - self.beamWidth, targetY - self.beamWidth, targetX + self.beamWidth, targetY + self.beamWidth)
            local destructable = SetUtils.getDestructablesInRectMatching(rect, self.destructableFilter):random()
            if destructable ~= nil then
                local tarX   = GetDestructableX(destructable)
                local tarY   = GetDestructableY(destructable)
                local angleT = math.atan(tarY - startY, tarX - startX) - angle

                --Ignore units that are behind the caster.
                if angleT < bj_PI / 2 and angleT > -bj_PI / 2 then
                    local targetDistance = distanceFromBeam(tarX, tarY, startX, startY, angle)
                    if targetDistance <= maxRangeSquared then
                        self.targetHandler(caster, destructable, targetDistance, maxRangeSquared)
                        break
                    end
                end
            end

            i = i + 1
        end
        targetZ = startZ + offsetZ * i * self.beamStepDelta

        SetRect(rect,
            math.min(startX, targetX) - self.beamWidth,
            math.min(startY, targetY) - self.beamWidth,
            math.max(startX, targetX) + self.beamWidth,
            math.max(startY, targetY) + self.beamWidth)
        for target in SetUtils.getUnitsInRectMatching(rect, self.unitFilter):elements() do
            local tarX   = GetUnitX(target)
            local tarY   = GetUnitY(target)
            local angleT = math.atan(tarY - startY, tarX - startX) - angle

            --Ignore units that are behind the caster.
            if angleT < bj_PI / 2 and angleT > -bj_PI / 2 then
                local targetDistance = distanceFromBeam(tarX, tarY, startX, startY, angle)
                if targetDistance <= maxRangeSquared then
                    self.targetHandler(caster, target, targetDistance, maxRangeSquared)
                end
            end
        end

        self.beamDestructor(self.beamConstructor(startX, startY, startZ, targetX, targetY, targetZ))
    end
end)
if Debug then Debug.endFile() end
