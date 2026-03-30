if Debug then Debug.beginFile "ReplayPOVDetection" end
OnInit.global("ReplayPOVDetection", function(require) --[[

    v1.0.0 by InsanityAI
    -------------------------------------------------------
    This snippet is used to detect which player perspective is the replay spectator currently viewing, by abusing how leaderboards work.
    In short, IsLeaderboardDisplayed will only return true for your current spectator / player

    Credits to sotzaii_shuen for finding this function (among others) with this behaviour
    -------------------------------------------------------
    1. Installation
     - Copy this script to your map
     - Put the following libraries in your map
        TotalInitialization - https://www.hiveworkshop.com/threads/total-initialization.317099/post-3641920 --]]
    require "GameStatus" --[[ https://www.hiveworkshop.com/threads/gamestatus-replay-detection.293176/
     - Save map
    -------------------------------------------------------
    2. API
    // function GetReplayPlayer(): player
        returns the player that the replay spectator is currently observing
        returns local player if it was either
            a. unable to determine which POV was observed
            b. not a replay (but an ongoing game)
    -------------------------------------------------------]]

    local lb = CreateLeaderboard()
    local tempLeaderboard = nil ---@type leaderboard?
    local povPlayer = nil ---@type player
    local i = 0
    local wasDisplayed = false
    local somethingWrong = false

    -- Will return whatever player the replay spectator is currently viewing, otherwise, if GameStatus determines that it is not a replay, or if it is
    -- unable to determine the replay player, will return local player instead. It is advised to store the resulting player in a variable if it were to
    -- be used multiple times in same scope/instance, since it does have quite a few native calls happening during a replay
    ---@return player replayPlayer
    function GetReplayPlayer()
        if GetGameStatus() ~= GameStatus.REPLAY then
            return GetLocalPlayer()
        end

        somethingWrong = true
        i = 0
        repeat
            povPlayer = Player(i)

            --record player's current leaderboard
            tempLeaderboard = PlayerGetLeaderboard(povPlayer)
            if (tempLeaderboard ~= nil) then
                wasDisplayed = IsLeaderboardDisplayed(tempLeaderboard)
            else
                wasDisplayed = false
            end

            --Check if player is being spectated
            PlayerSetLeaderboard(povPlayer, lb)
            if IsLeaderboardDisplayed(lb) then
                somethingWrong = false
                i = bj_MAX_PLAYER_SLOTS --force exit after cleanup is done
            end

            --restore player's leaderboard, if any
            if (tempLeaderboard ~= nil) then
                PlayerSetLeaderboard(povPlayer, tempLeaderboard)
                LeaderboardDisplay(tempLeaderboard, wasDisplayed)
            else
                PlayerSetLeaderboard(povPlayer, nil)
            end

            i = i + 1
        until (i >= bj_MAX_PLAYER_SLOTS)
        LeaderboardDisplay(lb, false)

        -- In case it couldn't determine observed player
        if somethingWrong then
            return GetLocalPlayer()
        end

        return povPlayer
    end
end)
