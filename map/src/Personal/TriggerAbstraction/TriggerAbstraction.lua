if Debug then Debug.beginFile "TriggerAbstraction" end
OnInit.root("TriggerAbstraction", function(require)
    require "TriggerAbstraction/AbstractTrigger"
    require "TriggerAbstraction/TriggerEventDispatcher"

    local oldDestroyTrigger = DestroyTrigger -- requires override
    -- local oldResetTrigger = ResetTrigger     -- unused

    -- local oldIsTriggerEnabled = IsTriggerEnabled             -- unused
    local oldTriggerWaitOnSleeps = TriggerWaitOnSleeps
    -- local oldIsTriggerWaitOnSleeps = IsTriggerWaitOnSleeps   -- unused
    local oldGetTriggeringTrigger = GetTriggeringTrigger -- requires override
    -- local oldGetTriggerEventId = GetTriggerEventId           -- unused
    -- local oldGetTriggerEvalCount = GetTriggerEvalCount       -- unused
    -- local oldGetTriggerExecCount = GetTriggerExecCount       -- unused

    -- local oldTriggerAddCondition = TriggerAddCondition       -- unused
    -- local oldTriggerRemoveCondition = TriggerRemoveCondition -- unused
    -- local oldTriggerClearConditions = TriggerClearConditions -- unused


    local oldTriggerSleepAction = TriggerSleepAction   -- requires override
    local oldTriggerWaitForSound = TriggerWaitForSound -- requires override
    local oldTriggerEvaluate = TriggerEvaluate
    local oldTriggerExecute = TriggerExecute
    local oldTriggerExecuteWait =
        TriggerExecuteWait                       -- requires override - Does the same as TriggerExecute but if the caller has been marked with TriggerWaitOnSleeps before its execution, it will additionally wait for TriggerSleepActions of the callee, so this really ensures that the callee has finished. If there was a TriggerSleepAction, there will be a short delay before returning.
    local oldTriggerSyncStart = TriggerSyncStart -- requires override
    local oldTriggerSyncReady = TriggerSyncReady -- requires override


    local OVERRIDE_TRIGGER_NATIVES = true

    if OVERRIDE_TRIGGER_NATIVES then
        CreateTrigger = AbstractTrigger.create
        -- DestroyTrigger goes here
        ResetTrigger = AbstractTrigger.reset
        EnableTrigger = function(trigger) trigger:toggle(true) end ---@type fun(trigger: AbstractTrigger)
        DisableTrigger = function(trigger) trigger:toggle(false) end ---@type fun(trigger: AbstractTrigger)
        IsTriggerEnabled = AbstractTrigger.isEnabled
        TriggerWaitOnSleeps = AbstractTrigger.setWaitOnSleep
        IsTriggerWaitOnSleeps = AbstractTrigger.isWaitOnSleep
        -- GetTriggeringTrigger goes here
        -- GetTriggerEventId goes here
        GetTriggerEvalCount = AbstractTrigger.getEvalCount
        GetTriggerExecCount = AbstractTrigger.getExecCount

        TriggerAddCondition = function(trigger, condition)
            AbstractTrigger.addCondition(trigger, condition); return condition
        end ---@type fun(trigger: AbstractTrigger, condition: function): function
        TriggerRemoveCondition = AbstractTrigger.removeCondition
        TriggerClearConditions = AbstractTrigger.clearConditions
        TriggerAddAction = function(trigger, action)
            AbstractTrigger.addAction(trigger, action); return action
        end ---@type fun(trigger: AbstractTrigger, action: function): function
        TriggerRemoveAction = AbstractTrigger.removeAction
        TriggerClearActions = AbstractTrigger.clearActions
        -- TriggerSleepAction goes here
        -- TriggerWaitForSound goes here
        TriggerEvaluate = AbstractTrigger.evaluate
        TriggerExecute = AbstractTrigger.execute
        -- TriggerExecuteWait goes here
        -- TriggerSyncStart goes here
        -- TriggerSyncReady goes here

        ---@param EventRegistryMethod function
        local function makeTriggerEventOverrideWrapper(EventRegistryMethod)
            ---@param trigger AbstractTrigger
            ---@param ... unknown
            ---@return AbstractTriggerEvent
            return function(trigger, ...)
                EventRegistry.keepEnabled = true
                local event = EventRegistryMethod(..., true)
                trigger:addEvent(event)
                return event
            end
        end

        TriggerRegisterVariableEvent = makeTriggerEventOverrideWrapper(EventRegistry.Variable) ---@overload fun(trigger: AbstractTrigger, varname: string, opcode: limitop, limitval: number): AbstractTriggerEvent
        TriggerRegisterTimerEvent = makeTriggerEventOverrideWrapper(EventRegistry.Timer) ---@overload fun(trigger: AbstractTrigger, timeout: number, periodic: boolean): AbstractTriggerEvent
        TriggerRegisterTimerExpireEvent = makeTriggerEventOverrideWrapper(EventRegistry.TimerExpired) ---@overload fun(trigger: AbstractTrigger, timer: timer): AbstractTriggerEvent
        TriggerRegisterGameStateEvent = makeTriggerEventOverrideWrapper(EventRegistry.GameState) ---@overload fun(trigger: AbstractTrigger, gamestate: gamestate, opcode: limitop, limitval: number): AbstractTriggerEvent
        TriggerRegisterDialogEvent = makeTriggerEventOverrideWrapper(EventRegistry.Dialog) ---@overload fun(trigger: AbstractTrigger, dialog: dialog): AbstractTriggerEvent
        TriggerRegisterDialogButtonEvent = makeTriggerEventOverrideWrapper(EventRegistry.DialogButton) ---@overload fun(trigger: AbstractTrigger, button: button): AbstractTriggerEvent
        TriggerRegisterGameEvent = makeTriggerEventOverrideWrapper(EventRegistry.Game) ---@overload fun(trigger: AbstractTrigger, gameEvent: gameevent): AbstractTriggerEvent
        TriggerRegisterEnterRegion = makeTriggerEventOverrideWrapper(EventRegistry.EnterRegion) ---@overload fun(trigger: AbstractTrigger,region: region, filter: boolexpr?): AbstractTriggerEvent
        TriggerRegisterLeaveRegion = makeTriggerEventOverrideWrapper(EventRegistry.LeaveRegion) ---@overload fun(trigger: AbstractTrigger,region: region, filter: boolexpr?): AbstractTriggerEvent
        TriggerRegisterTrackableHitEvent = makeTriggerEventOverrideWrapper(EventRegistry.TrackableHit) ---@overload fun(trigger: AbstractTrigger,trackable: trackable): AbstractTriggerEvent
        TriggerRegisterTrackableTrackEvent = makeTriggerEventOverrideWrapper(EventRegistry.TrackableTrack) ---@overload fun(trigger: AbstractTrigger,trackable: trackable): AbstractTriggerEvent
        TriggerRegisterCommandEvent = makeTriggerEventOverrideWrapper(EventRegistry.Command) ---@overload fun(trigger: AbstractTrigger,ability: integer, order: string): AbstractTriggerEvent
        TriggerRegisterUpgradeCommandEvent = makeTriggerEventOverrideWrapper(EventRegistry.UpgradeCommand) ---@overload fun(trigger: AbstractTrigger,upgrade: integer): AbstractTriggerEvent
        TriggerRegisterPlayerEvent = makeTriggerEventOverrideWrapper(EventRegistry.Player) ---@overload fun(trigger: AbstractTrigger,player: player, playerEvent: playerevent): AbstractTriggerEvent
        TriggerRegisterPlayerUnitEvent = makeTriggerEventOverrideWrapper(EventRegistry.PlayerUnit) ---@overload fun(trigger: AbstractTrigger,player: player, playerUnitEvent: playerunitevent, filter: boolexpr?): AbstractTriggerEvent
        TriggerRegisterPlayerAllianceChange = makeTriggerEventOverrideWrapper(EventRegistry.PlayerAlliance) ---@overload fun(trigger: AbstractTrigger,player: player, allianceType: alliancetype): AbstractTriggerEvent
        TriggerRegisterPlayerStateEvent = makeTriggerEventOverrideWrapper(EventRegistry.PlayerState) ---@overload fun(trigger: AbstractTrigger,player: player, state: playerstate, operation: limitop, limitValue: number): AbstractTriggerEvent
        TriggerRegisterPlayerChatEvent = makeTriggerEventOverrideWrapper(EventRegistry.Chat) ---@overload fun(trigger: AbstractTrigger,player: player, matchText: string, exactMatch: boolean): AbstractTriggerEvent
        TriggerRegisterDeathEvent = makeTriggerEventOverrideWrapper(EventRegistry.Death) ---@overload fun(trigger: AbstractTrigger,widget: widget): AbstractTriggerEvent
        TriggerRegisterUnitStateEvent = makeTriggerEventOverrideWrapper(EventRegistry.UnitState) ---@overload fun(trigger: AbstractTrigger,unit: unit, state: unitstate, operation: limitop, limitValue: number): AbstractTriggerEvent
        TriggerRegisterUnitEvent = makeTriggerEventOverrideWrapper(EventRegistry.Unit) ---@overload fun(trigger: AbstractTrigger,unit: unit, event: unitevent): AbstractTriggerEvent
        TriggerRegisterFilterUnitEvent = makeTriggerEventOverrideWrapper(EventRegistry.FilterUnit) ---@overload fun(trigger: AbstractTrigger,unit: unit, event: unitevent, filter: boolexpr?): AbstractTriggerEvent
        TriggerRegisterUnitInRange = makeTriggerEventOverrideWrapper(EventRegistry.UnitInRange) ---@overload fun(trigger: AbstractTrigger,unit: unit, range: number, filter: boolexpr?): AbstractTriggerEvent
        BlzTriggerRegisterFrameEvent = makeTriggerEventOverrideWrapper(EventRegistry.Frame) ---@overload fun(trigger: AbstractTrigger,frame: framehandle, eventType: frameeventtype): AbstractTriggerEvent
        BlzTriggerRegisterPlayerSyncEvent = makeTriggerEventOverrideWrapper(EventRegistry.PlayerSync) ---@overload fun(trigger: AbstractTrigger,player: player, prefix: string, fromServer: boolean): AbstractTriggerEvent
        BlzTriggerRegisterPlayerKeyEvent = makeTriggerEventOverrideWrapper(EventRegistry.PlayerKey) ---@overload fun(trigger: AbstractTrigger,player: player, key: oskeytype, metaKey: integer, keyDown: boolean): AbstractTriggerEvent


        -- This is for GUI Compatibility
        -- Won't work if complicated boolexpr constructions are happening via And, Or, Not
        -- Or if by some reason people are using Filter to construct conditionfuncs...
        Condition = function(conditionfunc) return conditionfunc end
        -- It will also cause issues if people are using this to make filterfuncs as well...
    end

    OnInit.trig(function(require)

    end)
end)
if Debug then Debug.endFile() end
