if Debug then Debug.beginFile "TerrainMasterPrint" end
OnInit.final("TerrainMasterPrint", function(require)
    require "SetUtils"
    require "TimerQueue"
    local singleTileResolution = TileResolution.get()

    local terrainMaster = SetUtils.getUnitsOfTypeId(FourCC('h000')):random()
    local trigger = CreateTrigger()
    BlzTriggerRegisterPlayerKeyEvent(trigger, Player(0), OSKEY_1, 0, false)
    TriggerAddAction(trigger, function()
        local x, y = GetUnitX(terrainMaster), GetUnitY(terrainMaster)
        print("x:", x, "y:", y)
        local xIndex, yIndex = singleTileResolution:getTileIndexes(x, y)
        print("xIndex:", xIndex, "yIndex:", yIndex)
    end)
end)
if Debug then Debug.endFile() end
