if Debug then Debug.beginFile "RoomRandomizer" end
OnInit.module("RoomRandomizer", function(require)
    require "SetUtils"

    ---@alias RoomType "start"|"offense"|"defense"|"merchant"|"boss"

    ---@class RoomTypeSet: Set
    ---@field random fun(self: RoomTypeSet): RoomType

    local stages = {
        Set.create("start") --[[@as RoomTypeSet]],
        Set.create("offense") --[[@as RoomTypeSet]],
        Set.create("offense, defense") --[[@as RoomTypeSet]],
        Set.create("merchant") --[[@as RoomTypeSet]],
        Set.create("offense") --[[@as RoomTypeSet]],
        Set.create("offense, defense") --[[@as RoomTypeSet]],
        Set.create("merchant") --[[@as RoomTypeSet]],
        Set.create("boss") --[[@as RoomTypeSet]]
    }

    ---@class RoomProperties
    ---@field small_enemies boolean
    ---@field medium_enemies boolean
    ---@field large_enemies boolean
    ---@field exits destructable[]

    local rooms = { ---@type table<RoomType, RoomProperties>
        offense = {
            small_enemies = false,
            medium_enemies = false,
            large_enemies = false,
            exits = {}
        },
        defense = {
            small_enemies = false,
            medium_enemies = false,
            large_enemies = false,
            exits = {}
        },
        merchant = {
            small_enemies = false,
            medium_enemies = false,
            large_enemies = false,
            exits = {}
        },
        boss = {
            small_enemies = false,
            medium_enemies = false,
            large_enemies = false,
            exits = {}
        },
        start = {
            small_enemies = false,
            medium_enemies = false,
            large_enemies = false,
            exits = { gg_dest_B005_0376 }
        }
    }

    ---@class EnemySetup
    ---@field [1] string name
    ---@field [2] integer food cost per unit
    ---@field [3] IntegerWeightedTable count

    ---@class IntegerWeightedTable
    ---@field add fun(self: IntegerWeightedTable, weight: number, value: integer): IntegerWeightedTable
    ---@field random fun(self: IntegerWeightedTable): integer?

    ---@class WeightedEnemyTable: WeightedTable
    ---@field add fun(self: WeightedEnemyTable, weight: number, value: EnemySetup): WeightedEnemyTable
    ---@field random fun(self: WeightedEnemyTable): EnemySetup?

    local enemyTable = {
        small = WeightedTable.create() --[[@as WeightedEnemyTable]]
            :add(0.3, { "ghoul", 2, WeightedTable.create(1, 1) --[[@as IntegerWeightedTable]] })
            :add(0.03, { "banshee", 6, WeightedTable.create(1, 1) --[[@as IntegerWeightedTable]] })
            :add(0.12, { "troll_berserker", 4, WeightedTable.create(1, 1) --[[@as IntegerWeightedTable]] })
            :add(0.06, { "troll_shaman", 4, WeightedTable.create(1, 2) --[[@as IntegerWeightedTable]] })
            :add(0.06, { "elemental_plague", 10, WeightedTable.create(1, 1) --[[@as IntegerWeightedTable]] }),
        medium = WeightedTable.create() --[[@as WeightedEnemyTable]]
            :add(0.05, { "demon_immo", 15, WeightedTable.create(1, 1) --[[@as IntegerWeightedTable]] }),
        large = WeightedTable.create() --[[@as WeightedEnemyTable]]
            :add(0.05, { "demon_pitlord", 35, WeightedTable.create(1, 1) --[[@as IntegerWeightedTable]] })
    }

    local stagecount = 1

    ---@param wghtTable WeightedEnemyTable
    ---@param list EnemySetup[]
    local function AddAllToWeightedTable(wghtTable, list)
        for _, val in ipairs(list) do
            wghtTable:add(val[0], val)
        end
    end

    function Room_Selection()
        local roomType1 = rooms[stages[stagecount]:random()]
        local roomType2 = rooms[stages[stagecount]:random()]
        local selected_enemies = WeightedTable.create() --[[@as WeightedEnemyTable]]

        if roomType1.large_enemies or roomType2.large_enemies then
            AddAllToWeightedTable(selected_enemies, enemyTable.large)
        end

        if roomType1.medium_enemies or roomType2.medium_enemies then
            AddAllToWeightedTable(selected_enemies, enemyTable.medium)
        end

        if roomType1.small_enemies or roomType2.small_enemies then
            AddAllToWeightedTable(selected_enemies, enemyTable.small)
        end

        if selected_enemies.size > 0 then
            local availableSupply = 10 * stagecount -- some special logic probably goes here:
            while availableSupply > 0 do
                local enemy_unit = selected_enemies:random()
                if enemy_unit ~= nil then
                    local enemy_unit_count = enemy_unit[3]:random()
                    local 
                    local totalSupplyUsed = enemy_unit_count * enemy_unit[2]
                    if 
                end

                --- spawn unit [1] - is unit name?,
                --- 
            end


        end
    end
end)
if Debug then Debug.endFile() end
