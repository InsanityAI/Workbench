if Debug then Debug.beginFile "TriggerAbstraction/EventRegistry" end
OnInit.module("TriggerAbstraction/EventRegistry", function(require)
    require "Cache"
    require "TriggerAbstraction/AbstractTrigger"

    local oldCreateTrigger = CreateTrigger
    local oldTriggerDisable = DisableTrigger
    local oldTriggerAddAction = TriggerAddAction
    local oldGetTriggeringTrigger = GetTriggeringTrigger

    ---@param trigger trigger
    local function triggerEventConstructor(trigger)
        return setmetatable({ actualTrigger = trigger }, AbstractTriggerEvent)
    end

    local function triggerCallback()
        local trigger = oldGetTriggeringTrigger()
        -- get abstract event somehow
    end

    --- need to setup dynamic and static event params!!!!
    --- hook it so it can all be fetched from trigger callback!
    --- triggers with dynamic event params shouldn't create new triggers

    ---@param eventRegisterNative fun(trigger: trigger, ...: unknown)
    ---@param argCount integer
    ---@param fetchIdentifier fun()
    ---@param ... integer static argument indices 0-indexed
    local function newEventCache(eventRegisterNative, argCount, fetchIdentifier, ...)
        ---@param trigger trigger 
        local abstractTriggerEventCache = Cache.create(function(trigger, ...)
            local abstractTriggerEvent = triggerEventConstructor(trigger)
        end, argCount)

        return Cache.create(function(...)
            local trigger = oldCreateTrigger() --[[@as trigger]]
            eventRegisterNative(trigger, ...)
            oldTriggerAddAction(trigger, triggerCallback)
            return abstractTriggerEventCache:get(trigger, ...)
        end, argCount - 1, ...)
    end

    ---@class EventRegistry
    EventRegistry = {
        keepEnabled = false
    }

    ---@param eventRegistrationNative fun(trigger: trigger, ...: unknown)
    ---@param nativeArgCount integer
    ---@param fetchIdentifier function
    ---@return function
    local function defineEventType(eventRegistrationNative, nativeArgCount, fetchIdentifier)
        local eventCache = newEventCache(eventRegistrationNative, nativeArgCount, fetchIdentifier)
        return function(...)
            local event = eventCache:get(...) --[[@as AbstractTriggerEvent]]
            if not EventRegistry.keepEnabled then
                ---@diagnostic disable-next-line: invisible
                oldTriggerDisable(event.actualTrigger)
                EventRegistry.keepEnabled = false
            end
            return event
        end
    end

    ---@overload fun(variableName: string, operation: limitop, limitValue: number): AbstractTriggerEvent
    EventRegistry.Variable = defineEventType(TriggerRegisterVariableEvent, 4)
    ---@overload fun(timeout: number, periodic: boolean): AbstractTriggerEvent
    EventRegistry.Timer = defineEventType(TriggerRegisterTimerEvent, 3)
    ---@overload fun(trigger: trigger, timer: timer): AbstractTriggerEvent
    EventRegistry.TimerExpire = defineEventType(TriggerRegisterTimerExpireEvent, 2)
    ---@overload fun(gamestate: gamestate, operation: limitop, limitValue: number): AbstractTriggerEvent
    EventRegistry.GameState = defineEventType(TriggerRegisterGameStateEvent, 4)
    ---@overload fun(dialog: dialog): AbstractTriggerEvent
    EventRegistry.Dialog = defineEventType(TriggerRegisterDialogEvent, 2)
    ---@overload fun(button: button): AbstractTriggerEvent
    EventRegistry.DialogButton = defineEventType(TriggerRegisterDialogButtonEvent, 2)
    ---@overload fun(gameEvent): AbstractTriggerEvent
    EventRegistry.Game = defineEventType(TriggerRegisterGameEvent, 2)
    ---@overload fun(region: region, filter: boolexpr?): AbstractTriggerEvent
    EventRegistry.EnterRegion = defineEventType(TriggerRegisterEnterRegion, 3)
    ---@overload fun(region: region, filter: boolexpr?): AbstractTriggerEvent
    EventRegistry.LeaveRegion = defineEventType(TriggerRegisterLeaveRegion, 3)
    ---@overload fun(trackable: trackable): AbstractTriggerEvent
    EventRegistry.TrackableHit = defineEventType(TriggerRegisterTrackableHitEvent, 2)
    ---@overload fun(trackable: trackable): AbstractTriggerEvent
    EventRegistry.TrackableTrack = defineEventType(TriggerRegisterTrackableTrackEvent, 2)
    ---@overload fun(ability: integer, order: string): AbstractTriggerEvent
    EventRegistry.Command = defineEventType(TriggerRegisterCommandEvent, 3)
    ---@overload fun(upgrade: integer): AbstractTriggerEvent
    EventRegistry.UpgradeCommand = defineEventType(TriggerRegisterUpgradeCommandEvent, 2)
    ---@overload fun(player: player, playerEvent: playerevent): AbstractTriggerEvent
    EventRegistry.Player = defineEventType(TriggerRegisterPlayerEvent, 3)
    ---@overload fun(player: player, playerUnitEvent: playerunitevent, filter: boolexpr?): AbstractTriggerEvent
    EventRegistry.PlayerUnit = defineEventType(TriggerRegisterPlayerUnitEvent, 4)
    ---@overload fun(player: player, allianceType: alliancetype): AbstractTriggerEvent
    EventRegistry.PlayerAlliance = defineEventType(TriggerRegisterPlayerAllianceChange, 3)
    ---@overload fun(player: player, state: playerstate, operation: limitop, limitValue: number): AbstractTriggerEvent
    EventRegistry.PlayerState = defineEventType(TriggerRegisterPlayerStateEvent, 5)
    ---@overload fun(player: player, matchText: string, exactMatch: boolean): AbstractTriggerEvent
    EventRegistry.Chat = defineEventType(TriggerRegisterPlayerChatEvent, 4)
    ---@overload fun(widget: widget): AbstractTriggerEvent
    EventRegistry.Death = defineEventType(TriggerRegisterDeathEvent, 2)
    ---@overload fun(unit: unit, state: unitstate, operation: limitop, limitValue: number): AbstractTriggerEvent
    EventRegistry.UnitState = defineEventType(TriggerRegisterUnitStateEvent, 5)
    ---@overload fun(unit: unit, event: unitevent): AbstractTriggerEvent
    EventRegistry.Unit = defineEventType(TriggerRegisterUnitEvent, 3)
    ---@overload fun(unit: unit, event: unitevent, filter: boolexpr?): AbstractTriggerEvent
    EventRegistry.FilterUnit = defineEventType(TriggerRegisterFilterUnitEvent, 4)
    ---@overload fun(unit: unit, range: number, filter: boolexpr?): AbstractTriggerEvent
    EventRegistry.UnitInRange = defineEventType(TriggerRegisterUnitInRange, 4)
    ---@overload fun(frame: framehandle, eventType: frameeventtype): AbstractTriggerEvent
    EventRegistry.Frame = defineEventType(BlzTriggerRegisterFrameEvent, 3,
        function() return oldGetTriggeringTrigger(), BlzGetTriggerFrame(), BlzGetTriggerFrameEvent() end)
    ---@overload fun(player: player, prefix: string, fromServer: boolean): AbstractTriggerEvent
    EventRegistry.PlayerSync = defineEventType(BlzTriggerRegisterPlayerSyncEvent, 4)
    ---@overload fun(player: player, key: oskeytype, metaKey: integer, keyDown: boolean): AbstractTriggerEvent
    EventRegistry.PlayerKey = defineEventType(BlzTriggerRegisterPlayerKeyEvent, 5)
end)
if Debug then Debug.endFile() end
