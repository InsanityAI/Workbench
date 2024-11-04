if Debug then Debug.beginFile "TerrainTest" end
OnInit.final("TerrainTest", function(require)
    require "TerrainIO"
    require "ChatSystem"

    local SETPOINT1ABIL = FourCC('A007')
    local SETPOINT2ABIL = FourCC('A008')
    local COPYABIL = FourCC('A009')
    local PASTEABIL = FourCC('A00A')

    local terrainTestTrigger = CreateTrigger()
    local point1x, point1y = 0, 0
    local point2x, point2y = 0, 0
    local rect = Rect(0, 0, 0, 0)

    local resolution = TileResolution.get()
    local tileTemplate ---@type TileTemplate
    local heightMap ---@type HeightMap
    local terrainWidgets ---@type TerrainWidgets
    local rotation = TerrainIORotate.NO_ROTATE

    TriggerAddAction(terrainTestTrigger, function()
        local ability = GetSpellAbilityId()
        if ability == SETPOINT1ABIL or ability == SETPOINT2ABIL then
            local targetX, targetY = GetSpellTargetX(), GetSpellTargetY()
            if ability == SETPOINT1ABIL then
                point1x = targetX
                point1y = targetY
            else
                point2x = targetX
                point2y = targetY
            end
        elseif ability == COPYABIL then
            if point1x > point2x then point1x, point2x = point2x, point1x end
            if point1y > point2y then point1y, point2y = point2y, point1y end
            SetRect(rect, point1x, point1y, point2x, point2y)
            tileTemplate = InMemoryTileTemplate.create(TileScanner.ScanBounds(resolution, point1x, point1y, point2x, point2y))
            heightMap = InMemoryHeightMap.create(TerrainHeightScanner.ScanBounds(point1x, point1y, point2x, point2y))
            terrainWidgets = InMemoryTerrainWidgets.create(TerrainWidgetScanner.ScanRect(rect))
            print("Copied!", "x1:", point1x, "y1:", point1y, "x2:", point2x, "y2:", point2y)
            print("sizeX:", tileTemplate.sizeX, "sizeY:", tileTemplate.sizeY)
        elseif ability == PASTEABIL then
            TilePrinter.PrintFrom(resolution, point1x, point1y, tileTemplate, true, rotation)
            TerrainHeightPrinter.PrintFrom(point1x, point1y, heightMap, rotation)
            TimerQueue:callDelayed(0.1, function()
                TerrainWidgetPrinter.PrintFrom(point1x, point1y, terrainWidgets, rotation)
            end)
            print("Pasted!", "x1:", point1x, "y1:", point1y, "sizeX:", tileTemplate.sizeX, "sizeY:", tileTemplate.sizeY)
        end
    end)
    TriggerRegisterAnyUnitEventBJ(terrainTestTrigger, EVENT_PLAYER_UNIT_SPELL_EFFECT)

    ---@param chatEvent ChatEvent
    ---@param rotate string
    ChatCommandBuilder.create("rotate", function(chatEvent, rotate)
        print(rotate)
        local i = math.tointeger(rotate)
        if i then
            rotation = i --[[@as TerrainIORotate]]
        end
    end):showInHelp()
        :argument("rotation"):description("Values 1-4")
        :register()

    ChatCommandBuilder.create("save", function(chatEvent, templateName)
        print(templateName)
        if templateName == "" then return end

        TileIO.Save(templateName, tileTemplate)
        TerrainWidgetsIO.Save(templateName, terrainWidgets)
        HeightMapIO.Save(templateName, heightMap)
        print(templateName .. " saved")
    end):showInHelp()
        :argument("templateName"):description("name to store template as")
        :register()

    ---@param chatEvent ChatEvent
    ---@param templateName string
    local function load(chatEvent, templateName)
        print(templateName)
        if templateName == "" then return end

        terrainWidgets = TerrainWidgetsIO.Load(templateName)
        tileTemplate = TileIO.Load(templateName)
        heightMap = HeightMapIO.Load(templateName)
        print("sizeX:", tileTemplate.sizeX, "sizeY:", tileTemplate.sizeY)
        print(templateName .. " loaded")
    end

    ChatCommandBuilder.create("load", load):showInHelp()
        :argument("templateName"):description("name of template that was stored")
        :register()
end)
if Debug then Debug.endFile() end
