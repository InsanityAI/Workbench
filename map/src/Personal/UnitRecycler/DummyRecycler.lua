if Debug then Debug.beginFile "DummyRecycler" end
OnInit.module("DummyRecycler", function(require)
    require "UnitRecycler"
    DummyRecycler = {}

    local DUMMY_ID = FourCC('dumy')

    local dummyAbilities = {} ---@type table<unit, integer>

    ---@param abilityId integer|string
    ---@param player player
    ---@param x number
    ---@param y number
    ---@param degrees number
    ---@param ignoreCollision? boolean
    ---@return unit
    function DummyRecycler.getForAbility(abilityId, player, x, y, degrees, ignoreCollision)
        if type(abilityId) == 'string' then abilityId = FourCC(abilityId) end
        if ignoreCollision == nil then ignoreCollision = true end
        local dummy = UnitRecycler.getUnit(DUMMY_ID, player, x, y, degrees, ignoreCollision)
        UnitAddAbility(dummy, abilityId)
        dummyAbilities[dummy] = abilityId
        return dummy
    end

    ---@param dummy unit
    function DummyRecycler.releaseDummy(dummy)
        UnitRemoveAbility(dummy, dummyAbilities[dummy])
        dummyAbilities[dummy] = nil
        UnitRecycler.recycleUnit(dummy)
    end
end)
if Debug then Debug.endFile() end
