if Debug then Debug.beginFile "UnitRecycler" end
OnInit.module("UnitRecycler", function()
    local Recycled = {}
    local onRecycle ---@type function

    UnitRecycler = {}

    --internal
    local CAMP_X = 3720
    local CAMP_Y = 3270
    local prepareUnit
    local hideUnit

    ---Retrieves a unit from the recycled list if there is one.
    ---Creates a unit normally otherwise.
    ---@param id integer
    ---@param player player
    ---@param x number
    ---@param y number
    ---@param degrees number
    ---@param ignoreCollision boolean
    ---@return unit
    function UnitRecycler.getUnit(id, player, x, y, degrees, ignoreCollision)
        Recycled[id] = Recycled[id] or {}

        local u
        if #Recycled[id] == 0 then --all in use, then create
            u = CreateUnit(player, id, x, y, degrees)
            --Recycled[id][#Recycled[id] + 1] = u
        else
            u = Recycled[id][#Recycled[id]]
            Recycled[id][#Recycled[id]] = nil
            prepareUnit(u, player, x, y, degrees, ignoreCollision)
        end
        return u
    end

    ---Recycles the unit. Returns true if successful.
    ---@param unit unit
    ---@return boolean
    function UnitRecycler.recycleUnit(unit)
        if unit then
            local id = GetUnitTypeId(unit)
            if not Recycled[id] then Recycled[id] = {} end
            Recycled[id][#Recycled[id] + 1] = unit
            hideUnit(unit)
            return true
        end
        return false
    end

    ---Registers a function that executes when the unit is recycled.
    ---Must take a unit as the argument.
    ---@param func fun (u: unit)
    function UnitRecycler.onRecycle(func)
        onRecycle = func
    end

    ---@param unit unit
    ---@param player player
    ---@param x number
    ---@param y number
    ---@param degrees number
    ---@param ignoreCollision boolean
    prepareUnit = function(unit, player, x, y, degrees, ignoreCollision)
        SetUnitOwner(unit, player, true)
        if ignoreCollision then
            SetUnitX(unit, x)
            SetUnitY(unit, y)
        else
            SetUnitPosition(unit, x, y)
        end
        SetUnitState(unit, UNIT_STATE_LIFE, GetUnitState(unit, UNIT_STATE_MAX_LIFE))
        SetUnitState(unit, UNIT_STATE_MANA, GetUnitState(unit, UNIT_STATE_MAX_MANA))
        BlzSetUnitFacingEx(unit, degrees)
        SetUnitInvulnerable(unit, false)
    end

    ---@param unit unit
    hideUnit = function(unit)
        if onRecycle then
            onRecycle(unit)
        end
        SetUnitOwner(unit, Player(27), true)
        SetUnitX(unit, CAMP_X)
        SetUnitY(unit, CAMP_Y)
        SetUnitInvulnerable(unit, true)
    end
end)
if Debug then Debug.endFile() end
