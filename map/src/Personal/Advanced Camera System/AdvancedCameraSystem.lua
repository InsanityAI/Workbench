if Debug then Debug.beginFile "AdvancedCameraSystem" end
OnInit.module("AdvancedCameraSystem", function(require)
    require "TimerQueue"
    require "SyncedTable"

    -- Advanced Camera System by The_Witcher (transpiled to Lua by Insanity_AI)
    --
    -- This is a very advanced advanced camera system which adjusts the camera
    -- distance to the target so the camera isn't looking through houses/trees/...
    -- and the cameras angle of attack so the view isn't blocked because of hills...
    --
    -- useful for RPGs and that stuff
    --
    -- To bind the camera to a unit for a player use
    --   SetCameraUnit(  unit, player )
    --
    -- if you want to have your normal camera again use
    --   ReleaseCameraUnit(  player  )
    --
    -- in case you want to know which unit is bound to the camera for player xy use
    --   GetCameraUnit(  player  )
    --
    -- to change the AngleOfAttack of a player ingame use
    --   SetCamDefaultAngleOfAttack(  Player, NewValue  )
    --
    -- to change the maximal camera target distance of a player ingame use
    --   SetCamMaxDistance(  Player, NewValue  )
    --
    -- to change the maximal distance behind the target, the z-offis checked (for z-angle), of a player ingame use
    --   SetCamMaxZCheckDistance(  Player, NewValue  )
    --
    --   SETUP PART

    -- The max. distance the camera can have to the target
    local DEFAULT_MAX_DISTANCE = 1000

    -- The max. distance the zOffbehind the unit is checked (for zAngle)
    local DEFAULT_MAX_Z_CHECK_DISTANCE = 500

    -- the camera angle of attack correction after the zAngle calculation
    local DEFAULT_ANGLE_OF_ATTACK = -20

    -- the timer interval (0.01 is best but can lagg in huge maps with many of these short intervals)
    local INTERVAL = 0.03

    -- the time the camera will need to adjust
    local DELAY = 0.25

    -- the standart z of the camera
    local NORMAL_HEIGHT = 100

    -- the accuracy increases if the value gets smaller
    local ACCURACY = 50

    -- the secondary accruracy when the camera reaches a barricade (just leave at this amount)
    local EXTREME_ACCURACY = 10

    -- SETUP END

    -- don't modify the code below!

    local TimerQueue = TimerQueue:create() -- we probably want a dedicated queue

    local playerCamData = SyncedTable.create() ---@type table<player, {Aoa: number, Dist: number, CheckDist: number, CamUnit: unit?}>

    local active = 0 ---@type integer

    local function timerCondition()
        return active == 0
    end

    local ite ---@type item
    ---@param x number
    ---@param y number
    ---@return boolean
    local function isCoordPathable(x, y)
        SetItemVisible(ite, true)
        SetItemPosition(ite, x, y)
        x = GetItemX(ite) - x
        y = GetItemY(ite) - y
        SetItemVisible(ite, false)
        if x < 1 and x > -1 and y < 1 and y > -1 then
            return true
        end
        return false
    end

    local loc = Location(0, 0)
    ---@param x number
    ---@param y number
    ---@return number z
    local function getPointZ(x, y)
        MoveLocation(loc, x, y)
        return GetLocationZ(loc)
    end

    local tempItems ---@type item[]|{n: integer}
    local tempItem ---@type item
    local function addItemToTable()
        tempItem = GetEnumItem()
        if not IsItemVisible(tempItem) then return end
        tempItems.n = tempItems.n + 1
        tempItems[tempItems.n] = tempItem
    end

    ---@param rect rect
    ---@param items item[]|{n: integer}
    local function addItemsInRectToTable(rect, items)
        tempItems = items
        EnumItemsInRect(rect, nil, addItemToTable)
    end

    ---@param items item[]|{n: integer}
    ---@param visible boolean
    ---@param fromIndex integer?
    local function toggleItemsVisible(items, visible, fromIndex)
        for i = fromIndex or 1, items.n do
            SetItemVisible(items[i], visible)
        end
    end

    local function Actions()
        local items = { n = 0 } ---@type item[]|{n: integer}

        for player, data in pairs(playerCamData) do
            if data.CamUnit == nil then goto ACS_continue end

            local DistanceDone = 0
            local rz = 0
            local x = GetUnitX(data.CamUnit)
            local y = GetUnitY(data.CamUnit)
            local Check = 1
            local angle = (GetUnitFacing(data.CamUnit) - 180) * bj_DEGTORAD
            local CheckDistance = ACCURACY
            local z = DEFAULT_ANGLE_OF_ATTACK

            if not IsUnitType(data.CamUnit, UNIT_TYPE_FLYING) then
                repeat
                    x = x + CheckDistance * Cos(angle)
                    y = y + CheckDistance * Sin(angle)
                    DistanceDone = DistanceDone + CheckDistance
                    z = getPointZ(x, y)
                    if RAbsBJ(z) > RAbsBJ(rz) and DistanceDone <= data.CheckDist then rz = z end
                    if not isCoordPathable(x, y) then
                        local oldSize = items.n
                        local rec = Rect(x - ACCURACY, y - ACCURACY, x + ACCURACY, y + ACCURACY)
                        addItemsInRectToTable(rec, items)
                        RemoveRect(rec)
                        toggleItemsVisible(items, false, oldSize)
                        if not isCoordPathable(x, y) then Check = 0 end
                    end
                    if Check == 0 and CheckDistance == ACCURACY then
                        DistanceDone = DistanceDone - CheckDistance
                        x = x - CheckDistance * Cos(angle)
                        y = y - CheckDistance * Sin(angle)
                        Check = 1
                        CheckDistance = EXTREME_ACCURACY
                    end
                until (Check == 0 and CheckDistance == EXTREME_ACCURACY) or DistanceDone > data.Dist
            else
                DistanceDone = data.Dist
            end

            x = getPointZ(GetUnitX(data.CamUnit), GetUnitY(data.CamUnit))
            while x - rz < 180 do
                x = x - 180
            end

            z = Atan2(x - rz, 200) * bj_RADTODEG + data.Aoa
            if IsUnitType(data.CamUnit, UNIT_TYPE_FLYING) then
                z = data.Aoa
            end

            if GetLocalPlayer() == player then
                CameraSetSmoothingFactor(1)
                SetCameraField(CAMERA_FIELD_TARGET_DISTANCE, DistanceDone, DELAY)
                SetCameraField(CAMERA_FIELD_ANGLE_OF_ATTACK, z, DELAY)
                SetCameraField(CAMERA_FIELD_ZOFFSET,
                    GetCameraField(CAMERA_FIELD_ZOFFSET) + x + GetUnitFlyHeight(data.CamUnit) + NORMAL_HEIGHT -
                    GetCameraTargetPositionZ(), DELAY)
                SetCameraField(CAMERA_FIELD_ROTATION, angle * bj_RADTODEG + 180, DELAY)
                SetCameraTargetController(data.CamUnit, 0, 0, false)
            end

            ::ACS_continue::
        end
        toggleItemsVisible(items, true)
    end

    ---@param p player
    function ReleaseCameraUnit(p)
        if playerCamData[p].CamUnit ~= nil then
            playerCamData[p].CamUnit = nil
            ResetToGameCameraForPlayer(p, 0)
            if GetLocalPlayer() == p then
                CameraSetSmoothingFactor(0)
            end
            active = active - 1
        end
    end

    ---@param u unit
    ---@param owner player
    function SetCameraUnit(u, owner)
        if playerCamData[owner].CamUnit ~= nil then
            ReleaseCameraUnit(owner)
        end
        playerCamData[owner].CamUnit = u
        active = active + 1
        if active == 1 then
            TimerQueue:callPeriodically(INTERVAL, timerCondition, Actions)
        end
    end

    ---@param p player
    ---@param a number
    function SetCamDefaultAngleOfAttack(p, a)
        playerCamData[p].Aoa = a
    end

    ---@param p player
    ---@param d number
    function SetCamMaxDistance(p, d)
        playerCamData[p].Dist = d
    end

    ---@param p player
    ---@param d number
    function SetCamMaxZCheckDistance(p, d)
        playerCamData[p].CheckDist = d
    end

    ---@param pl player
    ---@return unit?
    function GetCameraUnit(pl)
        return playerCamData[pl].CamUnit
    end

    ForForce(GetPlayersAll(), function()
        playerCamData[GetEnumPlayer()] = {
            Aoa = DEFAULT_ANGLE_OF_ATTACK,
            Dist = DEFAULT_MAX_DISTANCE,
            CheckDist = DEFAULT_MAX_Z_CHECK_DISTANCE,
            CamUnit = nil
        }
    end)

    ite = CreateItem(FourCC('wolg'), 0, 0)
    SetItemVisible(ite, false)
end)
if Debug then Debug.endFile() end
