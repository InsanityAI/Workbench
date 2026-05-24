if Debug then Debug.beginFile "BJDebugMsgOverride" end
OnInit.main("BJDebugMsgOverride", function (require)
    require "StringInterpolation"
    require "TimerQueue"
    local stopwatch = Stopwatch.create(false)
    local params = {time = 0, msg = ''}

    ---@param msg string
    function BJDebugMsg(msg)
        params.time = stopwatch:getElapsed()
        params.msg = msg
        DisplayTextToPlayer(GetReplayPlayer(), 0, 0, interp("[%(time).2f] %(msg)s", params))
    end

    OnInit.final(function() stopwatch:start() end)
end)
if Debug then Debug.endFile() end