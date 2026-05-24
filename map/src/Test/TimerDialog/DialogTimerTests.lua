if Debug then Debug.beginFile "DialogTimerTests" end
OnInit.final("DialogTimerTests", function(require)
    ---@param td timerdialog
    ---@param speed number?
    ---@param time number?
    function TestTimerDialog(td, speed, time)
        if speed ~= nil then TimerDialogSetSpeed(td, speed) end
        if time ~= nil then TimerDialogSetRealTimeRemaining(td, time) end
    end

    local paused = false
    function ToggleTimers()
        if paused then
            BJDebugMsg("Resumed timers")
            ResumeTimer(udg_TestTimer1)
            ResumeTimer(udg_TestTimer2)
            paused = false
        else
            BJDebugMsg("Paused timers")
            PauseTimer(udg_TestTimer1)
            PauseTimer(udg_TestTimer2)
            paused = true
        end
    end
end)
if Debug then Debug.endFile() end

TestTimerDialog(udg_TimerDialog1, 2.00, nil)