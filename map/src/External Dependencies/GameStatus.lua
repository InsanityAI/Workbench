if Debug then Debug.beginFile "GameStatus" end
OnInit.main("GameStatus", function()
    --[[***************************************************************
    *
    *   v1.0.0 by TriggerHappy (transpiled by InsanityAI)
    *   ¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯
    *   Simple API for detecting if the game is online, offline, or a replay.
    *   _________________________________________________________________________
    *   1. Installation
    *   ¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯
    *   Get TotalInitialization - https://www.hiveworkshop.com/threads/total-initialization.317099/post-3641920
    *   Copy this script to your map and save it
    *   _________________________________________________________________________
    *   2. API
    *   ¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯
    *   This library provides one function
    *
    *       function GetGameStatus(): GameStatus
    *
    *   It returns one of the following enum constants
    *
    *       - GameStatus.OFFLINE
    *       - GameStatus.ONLINE
    *       - GameStatus.REPLAY
    *
    ***************************************************************--]]

    -- Configuration:
    local DUMMY_UNIT_ID = FourCC('hfoo')

    ---@enum GameStatus
    GameStatus = {
        OFFLINE = 0,
        ONLINE = 1,
        REPLAY = 2
    }
    local status = GameStatus.OFFLINE

    ---@return GameStatus
    function GetGameStatus()
        return status
    end

    -- Game Status Initialization
    do
        -- find an actual player
        local firstPlayer = Player(0)
        while (GetPlayerController(firstPlayer) ~= MAP_CONTROL_USER or GetPlayerSlotState(firstPlayer) ~= PLAYER_SLOT_STATE_PLAYING) do
            firstPlayer = Player(GetPlayerId(firstPlayer) + 1)
        end

        -- force the player to select a dummy unit
        local u = CreateUnit(firstPlayer, DUMMY_UNIT_ID, 0, 0, 0)
        SelectUnit(u, true)
        local selected = IsUnitSelected(u, firstPlayer)
        RemoveUnit(u)

        if (selected) then
            -- detect if replay or offline game
            if (ReloadGameCachesFromDisk()) then
                status = GameStatus.OFFLINE
            else
                status = GameStatus.REPLAY
            end
        else
            -- if the unit wasn't selected instantly, the game is online
            status = GameStatus.ONLINE
        end
    end
end)
if Debug then Debug.endFile() end
