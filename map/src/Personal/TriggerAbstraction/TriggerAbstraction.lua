if Debug then Debug.beginFile "TriggerAbstraction" end
OnInit.module("TriggerAbstraction", function(require)
    require "SyncedTable"

    -- Required in order to access cached event responses
    local threadData = setmetatable({}, { __mode = 'kv' }) ---@type table<thread, table<string, unknown>>
    local threadDataMt = { __mode = 'k' }
    ---@param currentThread thread
    ---@param parentThread thread?
    ---@return table<string, unknown>
    local function setupThreadData(currentThread, parentThread)
        local tbl = {}
        if parentThread then
            local parentMt = getmetatable(threadData[parentThread])
            if parentMt.__index then
                setmetatable(tbl, parentMt) -- copy to directly refer to master thread table
            else
                setmetatable(tbl, {
                    __index = threadData[parentThread],
                    __newindex = threadData[parentThread],
                    __mode = 'k'
                }) -- create new one as this is the first descendant thread
            end
        else
            setmetatable(tbl, threadDataMt)
        end
        threadData[currentThread] = tbl
        return tbl
    end

    -- Boolexprs
    do
        -- ForGroup/ForForce will use regular loops
        local filterUpvalue = nil ---@type fun(): boolean
        local nativeFilter = Filter(function()
            -- note: this runs in a "blizzard" thread and cannot be paused/yielded, so we're safe
            return filterUpvalue()
        end)

        --todo: override enum natives
        -- TriggerRegisterEnterRegion
        -- TriggerRegisterLeaveRegion
        -- TriggerRegisterPlayerUnitEvent
        -- TriggerRegisterFilterUnitEvent

        -- TriggerAddCondition -- overridden later via FakeTrigger
        --

        ---@param filter fun(): boolean
        ---@param enumNative fun(): unknown
        ---@param enumName string
        ---@return fun(): boolean
        local function wrapFilter(filter, enumNative, enumName)
            local parentThread = coroutine.running()
            return function()
                local thisThread = coroutine.running()
                local data = setupThreadData(thisThread, parentThread)
                rawset(data, enumName, enumNative())
                return filter()
            end
        end

        -- Unit API
        do
            local oldGetFilterUnit = GetFilterUnit
            local function wrapUnitFilter(filter)
                if not filter then return nil end
                filterUpvalue = wrapFilter(filter --[[@as fun(): boolean]], oldGetFilterUnit, "GetFilterUnit")
                return nativeFilter
            end

            local oldGroupEnumUnitsOfType = GroupEnumUnitsOfType
            ---@param whichGroup group
            ---@param unitName string
            ---@param filter? boolexpr|fun():boolean
            function GroupEnumUnitsOfType(whichGroup, unitName, filter)
                oldGroupEnumUnitsOfType(whichGroup, unitName, wrapUnitFilter(filter))
            end

            local oldGroupEnumUnitsOfPlayer = GroupEnumUnitsOfPlayer
            ---@param whichGroup group
            ---@param whichPlayer player
            ---@param filter? boolexpr|fun(): boolean
            function GroupEnumUnitsOfPlayer(whichGroup, whichPlayer, filter)
                oldGroupEnumUnitsOfPlayer(whichGroup, whichPlayer, wrapUnitFilter(filter))
            end

            local oldGroupEnumUnitsInRect = GroupEnumUnitsInRect
            ---@param whichGroup group
            ---@param r rect
            ---@param filter? boolexpr|fun(): boolean
            function GroupEnumUnitsInRect(whichGroup, r, filter)
                oldGroupEnumUnitsInRect(whichGroup, r, wrapUnitFilter(filter))
            end

            local oldGroupEnumUnitsInRange = GroupEnumUnitsInRange
            ---@param whichGroup group
            ---@param x number
            ---@param y number
            ---@param radius number
            ---@param filter? boolexpr|fun():boolean
            function GroupEnumUnitsInRange(whichGroup, x, y, radius, filter)
                oldGroupEnumUnitsInRange(whichGroup, x, y, radius, wrapUnitFilter(filter))
            end

            local oldGroupEnumUnitsInRangeOfLoc = GroupEnumUnitsInRangeOfLoc
            ---@param whichGroup group
            ---@param whichLocation location
            ---@param radius number
            ---@param filter? boolexpr|fun(): boolean
            function GroupEnumUnitsInRangeOfLoc(whichGroup, whichLocation, radius, filter)
                oldGroupEnumUnitsInRangeOfLoc(whichGroup, whichLocation, radius, wrapUnitFilter(filter))
            end

            local oldGroupEnumUnitsSelected = GroupEnumUnitsSelected
            ---@param whichGroup group
            ---@param whichPlayer player
            ---@param filter? boolexpr|fun(): boolean
            function GroupEnumUnitsSelected(whichGroup, whichPlayer, filter)
                oldGroupEnumUnitsSelected(whichGroup, whichPlayer, wrapUnitFilter(filter))
            end

            local oldGroupEnumUnitsInRectCounted = GroupEnumUnitsInRectCounted
            ---@param whichGroup group
            ---@param r rect
            ---@param filter? boolexpr|fun(): boolean
            ---@param countLimit integer
            function GroupEnumUnitsInRectCounted(whichGroup, r, filter, countLimit)
                oldGroupEnumUnitsInRectCounted(whichGroup, r, wrapUnitFilter(filter), countLimit)
            end

            local oldGroupEnumUnitsOfTypeCounted = GroupEnumUnitsOfTypeCounted
            ---@param whichGroup group
            ---@param unitName string
            ---@param filter? boolexpr|fun(): boolean
            ---@param countLimit integer
            function GroupEnumUnitsOfTypeCounted(whichGroup, unitName, filter, countLimit)
                oldGroupEnumUnitsOfTypeCounted(whichGroup, unitName, wrapUnitFilter(filter), countLimit)
            end

            local oldGroupEnumUnitsInRangeCounted = GroupEnumUnitsInRangeCounted
            ---@param whichGroup group
            ---@param x number
            ---@param y number
            ---@param radius number
            ---@param filter? boolexpr|fun(): boolean
            ---@param countLimit integer
            function GroupEnumUnitsInRangeCounted(whichGroup, x, y, radius, filter, countLimit)
                oldGroupEnumUnitsInRangeCounted(whichGroup, x, y, radius, wrapUnitFilter(filter), countLimit)
            end

            local oldGroupEnumUnitsInRangeOfLocCounted = GroupEnumUnitsInRangeOfLocCounted
            ---@param whichGroup group
            ---@param whichLocation location
            ---@param radius number
            ---@param filter? boolexpr|fun(): boolean
            ---@param countLimit integer
            function GroupEnumUnitsInRangeOfLocCounted(whichGroup, whichLocation, radius, filter, countLimit)
                oldGroupEnumUnitsInRangeOfLocCounted(whichGroup, whichLocation, radius, wrapUnitFilter(filter),
                    countLimit)
            end
        end

        -- Player API
        do
            local oldGetFilterPlayer = GetFilterPlayer
            local function wrapPlayerFilter(filter)
                if not filter then return nil end
                filterUpvalue = wrapFilter(filter --[[@as fun(): boolean]], oldGetFilterPlayer, "GetFilterPlayer")
                return nativeFilter
            end

            local oldForceEnumPlayers = ForceEnumPlayers
            ---@param whichForce force
            ---@param filter? boolexpr|fun():boolean
            function ForceEnumPlayers(whichForce, filter)
                oldForceEnumPlayers(whichForce, wrapPlayerFilter(filter))
            end

            local oldForceEnumPlayersCounted = ForceEnumPlayersCounted
            ---@param whichForce force
            ---@param filter? boolexpr|fun():boolean
            ---@param countLimit integer
            function ForceEnumPlayersCounted(whichForce, filter, countLimit)
                oldForceEnumPlayersCounted(whichForce, wrapPlayerFilter(filter), countLimit)
            end

            local oldForceEnumAllies = ForceEnumAllies
            ---@param whichForce force
            ---@param filter? boolexpr|fun():boolean
            function ForceEnumAllies(whichForce, filter)
                oldForceEnumAllies(whichForce, wrapPlayerFilter(filter))
            end

            local oldForceEnumEnemies = ForceEnumEnemies
            ---@param whichForce force
            ---@param filter? boolexpr|fun():boolean
            function ForceEnumEnemies(whichForce, filter)
                oldForceEnumEnemies(whichForce, wrapPlayerFilter(filter))
            end
        end

        -- Items and Destructables
        do
            local oldGetFilterDestructable = GetFilterDestructable
            local oldGetEnumDestructable = GetEnumDestructable
            local oldEnumDestructablesInRect = EnumDestructablesInRect
            ---@param r rect
            ---@param filter? boolexpr|fun():boolean
            ---@param actionFunc fun()
            function EnumDestructablesInRect(r, filter, actionFunc)
                if not filter and not actionFunc then return end
                local filterFunc
                if filter then
                    filterUpvalue = wrapFilter(filter --[[@as fun(): boolean]], oldGetFilterDestructable,
                        "GetFilterDestructable")
                    filterFunc = nativeFilter
                else
                    filterFunc = nil
                end

                local callback
                if actionFunc then
                    callback = function()
                        local parentThread = coroutine.running()
                        return function()
                            local thisThread = coroutine.running()
                            local data = setupThreadData(thisThread, parentThread)
                            rawset(data, "GetEnumDestructable", oldGetEnumDestructable())
                            return actionFunc()
                        end
                    end
                else
                    callback = nil
                end

                oldEnumDestructablesInRect(r, filterFunc, callback)
            end

            local oldEnumItemsInRect = EnumItemsInRect
            local oldGetFilterItem = GetFilterItem
            local oldGetEnumItem = GetEnumItem
            ---@param r rect
            ---@param filter? boolexpr|fun():boolean
            ---@param actionFunc fun()
            function EnumItemsInRect(r, filter, actionFunc)
                if not filter and not actionFunc then return end
                local filterFunc
                if filter then
                    filterUpvalue = wrapFilter(filter --[[@as fun(): boolean]], oldGetFilterItem, "GetFilterItem")
                    filterFunc = nativeFilter
                else
                    filterFunc = nil
                end

                local callback
                if actionFunc then
                    callback = function()
                        local parentThread = coroutine.running()
                        return function()
                            local thisThread = coroutine.running()
                            local data = setupThreadData(thisThread, parentThread)
                            rawset(data, "GetEnumItem", oldGetEnumItem())
                            return actionFunc()
                        end
                    end
                else
                    callback = nil
                end

                oldEnumItemsInRect(r, filterFunc, callback)
            end
        end

        ---@param func fun(): boolean
        ---@return conditionfunc|fun(): boolean
        function Condition(func)
            return func
        end

        ---@param func fun():boolean
        ---@return filterfunc|fun(): boolean
        function Filter(func)
            return func
        end

        ---@param boolexpr1 boolexpr|fun(): boolean
        ---@param boolexpr2 boolexpr|fun(): boolean
        ---@return boolexpr|fun(): boolean
        function And(boolexpr1, boolexpr2)
            return function()
                return boolexpr1() and boolexpr2()
            end
        end

        ---@param boolexpr1 boolexpr|fun(): boolean
        ---@param boolexpr2 boolexpr|fun(): boolean
        ---@return boolexpr|fun(): boolean
        function Or(boolexpr1, boolexpr2)
            return function()
                return boolexpr1() or boolexpr2()
            end
        end

        DestroyFilter = DoNothing
        DestroyCondition = DoNothing
        DestroyBoolExpr = DoNothing
    end

    local oldCreateTrigger = CreateTrigger
    local oldEnableTrigger = EnableTrigger
    local oldDisableTrigger = DisableTrigger
    local oldTriggerAddAction = TriggerAddAction
    local oldGetTriggeringTrigger = GetTriggeringTrigger

    local addEventListener, removeEventListener

    -- Events
    do
        ---@class AbstractTriggerEvent
        ---@field package actualTrigger trigger
        ---@field package listeners table<FakeTrigger, boolean>
        ---@field package listenerAmount integer
        AbstractTriggerEvent = {}
        AbstractTriggerEvent.__index = AbstractTriggerEvent

        function AbstractTriggerEvent:notifyListeners()
            if self.listenerAmount == 0 then
                oldDisableTrigger(self.actualTrigger)
                return
            end
            local thread = coroutine.running()
            for listener in pairs(self.listeners) do
                if listener:isEnabled() and listener:evaluate() then
                    local newThread = coroutine.create(listener.execute)
                    local data = setupThreadData(newThread, thread)
                    -- run in a coroutine to avoid TSA/PolledWait congesting every listener/trigger
                    coroutine.resume(newThread, listener)
                end
            end
        end

        local function createAbstractTriggerEvent()
            return setmetatable({
                actualTrigger = oldCreateTrigger(),
                listeners = SyncedTable.create(),
                listenersAmount = 0
            }, AbstractTriggerEvent)
        end

        ---@param self AbstractTriggerEvent
        ---@param listener FakeTrigger
        addEventListener = function(self, listener)
            if self.listeners[listener] then
                self.listenerAmount = self.listenerAmount + 1
            end
            self.listeners[listener] = true
            if self.listenerAmount > 0 then
                oldEnableTrigger(self.actualTrigger)
            end
        end

        ---@param self AbstractTriggerEvent
        ---@param listener FakeTrigger
        removeEventListener = function(self, listener)
            if self.listeners[listener] then
                self.listenerAmount = self.listenerAmount - 1
            end
            self.listeners[listener] = nil
            if self.listenerAmount == 0 then
                oldDisableTrigger(self.actualTrigger)
            end
        end

        local eventResponseMap = {} ---@type table<string, fun():unknown>

        local useNativeInstead = {
            GetEnteringUnit = "GetTriggerUnit",
            GetLeavingUnit = "GetTriggerUnit",
            GetDyingUnit = "GetTriggerUnit",
            GetDecayingUnit = "GetTriggerUnit",
            GetDetectedUnit = "GetTriggerUnit",
            GetEventDetectingPlayer = "GetTriggerPlayer",
            GetOrderedUnit = "GetTriggerUnit",
            GetLevelingUnit = "GetTriggerUnit",
            GetLearningUnit = "GetTriggerUnit",
            GetRevivableUnit = "GetTriggerUnit",
            GetManipulatingUnit = "GetTriggerUnit",
            GetSpellAbilityUnit = "GetTriggerUnit",
        }

        ---@param abstractTriggerEventCache Cache
        ---@param eventResponseNames string[]
        local function processEventCallback(abstractTriggerEventCache, eventResponseNames)
            local event = abstractTriggerEventCache:get(oldGetTriggeringTrigger()) --[[@as AbstractTriggerEvent]]
            local thread = coroutine.running()
            local data = setupThreadData(thread)
            data.GetTriggerEventId = event

            for _, name in ipairs(eventResponseNames) do
                if useNativeInstead[name] then
                    threadData[thread][name] = threadData[thread][useNativeInstead[name]]
                else
                    threadData[thread][name] = eventResponseMap[name]()
                end
            end
            event:notifyListeners()
        end

        ---@param eventRegistrationNative fun(trigger: trigger, ...: unknown)
        ---@param nativeArgCount integer
        ---@param eventResponseNames string[]
        ---@return fun(...): AbstractTriggerEvent
        local function defineEventType(eventRegistrationNative, nativeArgCount, eventResponseNames)
            local abstractTriggerEventCache = Cache.create(createAbstractTriggerEvent, nativeArgCount)

            local function triggerCallback()
                processEventCallback(abstractTriggerEventCache, eventResponseNames)
            end

            local eventCache = Cache.create(function(...)
                local trigger = oldCreateTrigger() --[[@as trigger]]
                eventRegistrationNative(trigger, ...)
                oldTriggerAddAction(trigger, triggerCallback)
                return abstractTriggerEventCache:get(trigger, ...)
            end, nativeArgCount - 1)
            return function(...)
                return eventCache:get(...)
            end
        end

        ---@param eventRegistrationNative fun(trigger: trigger, ...: unknown)
        ---@param nativeArgCount integer
        ---@param eventResponseNames string[]
        ---@return fun(...): AbstractTriggerEvent
        local function defineEventTypeWithFilter(eventRegistrationNative, nativeArgCount, eventResponseNames)
            local eventConstructor = defineEventType(eventRegistrationNative, nativeArgCount - 1, eventResponseNames)

            ---@param trigger FakeTrigger
            ---@param ... unknown
            return function(trigger, ...)
                -- remove filter from args
                local args = table.pack(...)
                local filter = args[nativeArgCount] --[[@as nil|fun():boolean]]
                args[nativeArgCount] = nil

                if filter then
                    trigger:addCondition(filter)
                end
                return eventConstructor(trigger, table.unpack(args))
            end
        end

        ---@param eventRegistrationNative fun(trigger: trigger, ...:unknown)
        ---@param nativeArgCount integer
        ---@param eventTypeResponseMap table<eventid, string[]>
        ---@---@return fun(...): AbstractTriggerEvent
        local function defineDynamicEventType(eventRegistrationNative, nativeArgCount, eventTypeResponseMap)
            local abstractTriggerEventCache = Cache.create(createAbstractTriggerEvent, nativeArgCount)
            local eventCache = Cache.create(function(...)
                local eventResponseNames = eventTypeResponseMap[select(2, ...)]
                local trigger = oldCreateTrigger() --[[@as trigger]]
                eventRegistrationNative(trigger, ...)
                oldTriggerAddAction(trigger, function()
                    processEventCallback(abstractTriggerEventCache, eventResponseNames)
                end)
                return abstractTriggerEventCache:get(trigger, ...)
            end, nativeArgCount - 1)
            return function(...)
                return eventCache:get(...)
            end
        end

        ---@param eventRegistrationNative fun(trigger: trigger, ...: unknown)
        ---@param nativeArgCount integer
        ---@param eventTypeResponseMap table<eventid, string[]>
        ---@return fun(...): AbstractTriggerEvent
        local function defineDynamicEventTypeWithFilter(eventRegistrationNative, nativeArgCount, eventTypeResponseMap)
            local eventConstructor = defineDynamicEventType(eventRegistrationNative, nativeArgCount - 1, eventTypeResponseMap)

            ---@param trigger FakeTrigger
            ---@param ... unknown
            return function(trigger, ...)
                -- remove filter from args
                local args = table.pack(...)
                local filter = args[nativeArgCount] --[[@as nil|fun():boolean]]
                args[nativeArgCount] = nil

                if filter then
                    trigger:addCondition(filter)
                end
                return eventConstructor(trigger, table.unpack(args))
            end
        end

        -- note: commented out position event responses will call the X/Y natives anyways, because they've been overriden earlier

        local gameEventResponseMap = {
            [EVENT_GAME_VICTORY] = { "GetWinningPlayer" },
            [EVENT_GAME_END_LEVEL] = {},
            [EVENT_GAME_VARIABLE_LIMIT] = { "GetTriggeringVariableName" },
            [EVENT_GAME_STATE_LIMIT] = { "GetEventGameState" },
            [EVENT_GAME_TIMER_EXPIRED] = { "GetExpiredTimer" },
            [EVENT_GAME_ENTER_REGION] = { "GetTriggeringRegion", "GetTriggerUnit", "GetEnteringUnit" },
            [EVENT_GAME_LEAVE_REGION] = { "GetTriggeringRegion", "GetTriggerUnit", "GetLeavingUnit" },
            [EVENT_GAME_TRACKABLE_HIT] = { "GetTriggeringTrackable" },
            [EVENT_GAME_TRACKABLE_TRACK] = { "GetTriggeringTrackable" },
            [EVENT_GAME_SHOW_SKILL] = {},
            [EVENT_GAME_BUILD_SUBMENU] = {},
            [EVENT_GAME_LOADED] = {},
            [EVENT_GAME_TOURNAMENT_FINISH_SOON] = { "GetTournamentFinishSoonTimeRemaining" },
            [EVENT_GAME_TOURNAMENT_FINISH_NOW] = { "GetTournamentFinishNowRule", "GetTournamentFinishNowPlayer" },
            [EVENT_GAME_SAVE] = { "GetSaveBasicFilename" },
            [EVENT_GAME_CUSTOM_UI_FRAME] = { "GetTriggerPlayer", "BlzGetTriggerFrame", "BlzGetTriggerFrameEvent", "BlzGetTriggerFrameValue" }
        }

        local dialogEventResponses = { "GetClickedDialog", "GetClickedButton" }

        local playerEventResponseMap = {
            [EVENT_PLAYER_STATE_LIMIT] = { "GetTriggerPlayer", "GetEventPlayerState" },
            [EVENT_PLAYER_ALLIANCE_CHANGED] = { "GetTriggerPlayer" },
            [EVENT_PLAYER_DEFEAT] = { "GetTriggerPlayer" },
            [EVENT_PLAYER_VICTORY] = { "GetTriggerPlayer" },
            [EVENT_PLAYER_LEAVE] = { "GetTriggerPlayer" },
            [EVENT_PLAYER_CHAT] = { "GetTriggerPlayer", "GetEventPlayerChatString", "GetEventPlayerChatStringMatched" }, --todo: does matched work?
            [EVENT_PLAYER_END_CINEMATIC] = { "GetTriggerPlayer" },
            [EVENT_PLAYER_ARROW_LEFT_DOWN] = { "GetTriggerPlayer" },
            [EVENT_PLAYER_ARROW_LEFT_UP] = { "GetTriggerPlayer" },
            [EVENT_PLAYER_ARROW_RIGHT_DOWN] = { "GetTriggerPlayer" },
            [EVENT_PLAYER_ARROW_RIGHT_UP] = { "GetTriggerPlayer" },
            [EVENT_PLAYER_ARROW_DOWN_DOWN] = { "GetTriggerPlayer" },
            [EVENT_PLAYER_ARROW_DOWN_UP] = { "GetTriggerPlayer" },
            [EVENT_PLAYER_ARROW_UP_DOWN] = { "GetTriggerPlayer" },
            [EVENT_PLAYER_ARROW_UP_UP] = { "GetTriggerPlayer" },
            [EVENT_PLAYER_MOUSE_DOWN] = { "GetTriggerPlayer", "BlzGetTriggerPlayerMouseButton", --[["BlzGetTriggerPlayerMousePosition",]] "BlzGetTriggerPlayerMouseX", "BlzGetTriggerPlayerMouseY" },
            [EVENT_PLAYER_MOUSE_UP] = { "GetTriggerPlayer", "BlzGetTriggerPlayerMouseButton", --[["BlzGetTriggerPlayerMousePosition",]] "BlzGetTriggerPlayerMouseX", "BlzGetTriggerPlayerMouseY" },
            [EVENT_PLAYER_MOUSE_MOVE] = { "GetTriggerPlayer", --[["BlzGetTriggerPlayerMousePosition",]] "BlzGetTriggerPlayerMouseX", "BlzGetTriggerPlayerMouseY" },
            [EVENT_PLAYER_SYNC_DATA] = { "GetTriggerPlayer", "BlzGetTriggerSyncData", "BlzGetTriggerSyncPrefix" },
            [EVENT_PLAYER_KEY] = { "GetTriggerPlayer", "BlzGetTriggerPlayerKey", "BlzGetTriggerPlayerMetaKey", "BlzGetTriggerPlayerIsKeyDown" },
            [EVENT_PLAYER_KEY_DOWN] = { "GetTriggerPlayer", "BlzGetTriggerPlayerKey", "BlzGetTriggerPlayerMetaKey", "BlzGetTriggerPlayerIsKeyDown" },
            [EVENT_PLAYER_KEY_UP] = { "GetTriggerPlayer", "BlzGetTriggerPlayerKey", "BlzGetTriggerPlayerMetaKey", "BlzGetTriggerPlayerIsKeyDown" },
        }

        local playerUnitEventResponseMap = {
            [EVENT_PLAYER_UNIT_ATTACKED] = { "GetTriggerPlayer", "GetTriggerUnit" },
            [EVENT_PLAYER_UNIT_RESCUED] = { "GetTriggerPlayer", "GetTriggerUnit", "GetRescuer" },
            [EVENT_PLAYER_UNIT_DEATH] = { "GetTriggerPlayer", "GetTriggerUnit", "GetDyingUnit", "GetKillingUnit" },
            [EVENT_PLAYER_UNIT_DECAY] = { "GetTriggerPlayer", "GetTriggerUnit", "GetDecayingUnit" },
            [EVENT_PLAYER_UNIT_DETECTED] = { "GetTriggerPlayer", "GetTriggerUnit", "GetDetectedUnit", "GetEventDetectingPlayer" },
            [EVENT_PLAYER_UNIT_HIDDEN] = { "GetTriggerPlayer", "GetTriggerUnit" }, -- what is this event even?
            [EVENT_PLAYER_UNIT_SELECTED] = { "GetTriggerPlayer", "GetTriggerUnit" },
            [EVENT_PLAYER_UNIT_DESELECTED] = { "GetTriggerPlayer", "GetTriggerUnit" },
            [EVENT_PLAYER_UNIT_CONSTRUCT_START] = { "GetTriggerPlayer", "GetTriggerUnit", "GetConstructingStructure" },
            [EVENT_PLAYER_UNIT_CONSTRUCT_CANCEL] = { "GetTriggerPlayer", "GetTriggerUnit", "GetConstructingStructure", "GetCancelledStructure" },
            [EVENT_PLAYER_UNIT_CONSTRUCT_FINISH] = { "GetTriggerPlayer", "GetTriggerUnit", "GetConstructedStructure" },
            [EVENT_PLAYER_UNIT_UPGRADE_START] = { "GetTriggerPlayer", "GetTriggerUnit", "GetConstructingStructure" },  -- todo: is this how these events work?
            [EVENT_PLAYER_UNIT_UPGRADE_CANCEL] = { "GetTriggerPlayer", "GetTriggerUnit", "GetConstructingStructure" }, -- todo: is this how these events work?
            [EVENT_PLAYER_UNIT_UPGRADE_FINISH] = { "GetTriggerPlayer", "GetTriggerUnit", "GetConstructedStructure" },  -- todo: is this how these events work?
            [EVENT_PLAYER_UNIT_TRAIN_START] = { "GetTriggerPlayer", "GetTriggerUnit", "GetTrainedUnitType" },
            [EVENT_PLAYER_UNIT_TRAIN_CANCEL] = { "GetTriggerPlayer", "GetTriggerUnit", "GetTrainedUnitType" },
            [EVENT_PLAYER_UNIT_TRAIN_FINISH] = { "GetTriggerPlayer", "GetTriggerUnit", "GetTrainedUnitType", "GetTrainedUnit" },
            [EVENT_PLAYER_UNIT_RESEARCH_START] = { "GetTriggerPlayer", "GetTriggerUnit", "GetResearched", "GetResearchingUnit" },
            [EVENT_PLAYER_UNIT_RESEARCH_CANCEL] = { "GetTriggerPlayer", "GetTriggerUnit", "GetResearched", "GetResearchingUnit" },
            [EVENT_PLAYER_UNIT_RESEARCH_FINISH] = { "GetTriggerPlayer", "GetTriggerUnit", "GetResearched", "GetResearchingUnit" },
            [EVENT_PLAYER_UNIT_ISSUED_ORDER] = { "GetTriggerPlayer", "GetTriggerUnit", "GetOrderedUnit", "GetIssuedOrderId" },
            [EVENT_PLAYER_UNIT_ISSUED_POINT_ORDER] = { "GetTriggerPlayer", "GetTriggerUnit", "GetOrderedUnit", "GetIssuedOrderId", "GetOrderPointX", "GetOrderPointY", --[["GetOrderPointLoc"]] },                                                                                              -- todo: triggerUnit = orderedUnit, orderTarget =  multiple things?
            [EVENT_PLAYER_UNIT_ISSUED_TARGET_ORDER] = { "GetTriggerPlayer", "GetTriggerUnit", "GetOrderedUnit", "GetIssuedOrderId", "GetOrderPointX", "GetOrderPointY", --[["GetOrderPointLoc",]] "GetOrderTarget", "GetOrderTargetDestructable", "GetOrderTargetUnit", "GetOrderTargetItem" }, -- todo: triggerUnit = orderedUnit, orderTarget =  multiple things?
            [EVENT_PLAYER_UNIT_ISSUED_UNIT_ORDER] = { "GetTriggerPlayer", "GetTriggerUnit", "GetOrderedUnit", "GetIssuedOrderId", "GetOrderPointX", "GetOrderPointY", --[["GetOrderPointLoc",]] "GetOrderTarget", "GetOrderTargetDestructable", "GetOrderTargetUnit", "GetOrderTargetItem" },   -- todo: triggerUnit = orderedUnit, orderTarget =  multiple things?
            [EVENT_PLAYER_HERO_LEVEL] = { "GetTriggerPlayer", "GetTriggerUnit", "GetLevelingUnit" },
            [EVENT_PLAYER_HERO_SKILL] = { "GetTriggerPlayer", "GetTriggerUnit", "GetLearnedSkillLevel", "GetLearnedSkill", "GetLearningUnit" },
            [EVENT_PLAYER_HERO_REVIVABLE] = { "GetTriggerPlayer", "GetTriggerUnit", "GetRevivableUnit" },
            [EVENT_PLAYER_HERO_REVIVE_START] = { "GetTriggerPlayer", "GetTriggerUnit", "GetRevivingUnit" },
            [EVENT_PLAYER_HERO_REVIVE_CANCEL] = { "GetTriggerPlayer", "GetTriggerUnit", "GetRevivingUnit" },
            [EVENT_PLAYER_HERO_REVIVE_FINISH] = { "GetTriggerPlayer", "GetTriggerUnit", "GetRevivingUnit" },
            [EVENT_PLAYER_UNIT_SUMMON] = { "GetTriggerPlayer", "GetTriggerUnit", "GetSummonedUnit", "GetSummoningUnit" }, -- todo: triggerUnit == ?
            [EVENT_PLAYER_UNIT_DROP_ITEM] = { "GetTriggerPlayer", "GetTriggerUnit", "GetManipulatingUnit", "GetManipulatedItem" },
            [EVENT_PLAYER_UNIT_PICKUP_ITEM] = { "GetTriggerPlayer", "GetTriggerUnit", "GetManipulatingUnit", "GetManipulatedItem", "BlzGetAbsorbingItem", "BlzGetManipulatedItemWasAbsorbed" },
            [EVENT_PLAYER_UNIT_USE_ITEM] = { "GetTriggerPlayer", "GetTriggerUnit", "GetManipulatingUnit", "GetManipulatedItem" },
            [EVENT_PLAYER_UNIT_LOADED] = { "GetTriggerPlayer", "GetTriggerUnit", "GetLoadedUnit", "GetTransportUnit" },                                                                                                                                     -- todo: triggerUnit == ??
            [EVENT_PLAYER_UNIT_DAMAGED] = { "GetTriggerPlayer", "GetTriggerUnit", "GetEventDamage", "GetEventDamageSource", "BlzGetEventDamageTarget", "BlzGetEventDamageType", "BlzGetEventAttackType", "BlzGetEventWeaponType", "BlzGetEventIsAttack" },  -- todo: triggerUnit == ??
            [EVENT_PLAYER_UNIT_DAMAGING] = { "GetTriggerPlayer", "GetTriggerUnit", "GetEventDamage", "GetEventDamageSource", "BlzGetEventDamageTarget", "BlzGetEventDamageType", "BlzGetEventAttackType", "BlzGetEventWeaponType", "BlzGetEventIsAttack" }, -- todo: triggerUnit == ??
            [EVENT_PLAYER_UNIT_SELL] = { "GetTriggerPlayer", "GetTriggerUnit", "GetBuyingUnit", "GetSoldUnit", "GetSellingUnit" },                                                                                                                          -- todo: triggerUnit == ??
            [EVENT_PLAYER_UNIT_CHANGE_OWNER] = { "GetTriggerPlayer", "GetTriggerUnit", "GetChangingUnit", "GetChangingUnitPrevOwner" },
            [EVENT_PLAYER_UNIT_SELL_ITEM] = { "GetTriggerPlayer", "GetTriggerUnit", "GetBuyingUnit", "GetSoldItem", "GetSellingUnit", "GetManipulatedItem", "GetManipulatingUnit" },                                                                        -- todo: manipulatingUnit? == triggerUnit, which shop?
            [EVENT_PLAYER_UNIT_SPELL_CHANNEL] = { "GetTriggerPlayer", "GetTriggerUnit", "GetSpellAbility", "GetSpellAbilityId", "GetSpellAbilityUnit", "GetSpellTargetX", "GetSpellTargetY", --[[GetSpellTargetLoc,]] "GetSpellTargetUnit", "GetSpellTargetDestructable", "GetSpellTargetItem" },
            [EVENT_PLAYER_UNIT_SPELL_CAST] = { "GetTriggerPlayer", "GetTriggerUnit", "GetSpellAbility", "GetSpellAbilityId", "GetSpellAbilityUnit", "GetSpellTargetX", "GetSpellTargetY", --[[GetSpellTargetLoc,]] "GetSpellTargetUnit", "GetSpellTargetDestructable", "GetSpellTargetItem" },
            [EVENT_PLAYER_UNIT_SPELL_EFFECT] = { "GetTriggerPlayer", "GetTriggerUnit", "GetSpellAbility", "GetSpellAbilityId", "GetSpellAbilityUnit", "GetSpellTargetX", "GetSpellTargetY", --[[GetSpellTargetLoc,]] "GetSpellTargetUnit", "GetSpellTargetDestructable", "GetSpellTargetItem" },
            [EVENT_PLAYER_UNIT_SPELL_FINISH] = { "GetTriggerPlayer", "GetTriggerUnit", "GetSpellAbility", "GetSpellAbilityId", "GetSpellAbilityUnit" },
            [EVENT_PLAYER_UNIT_SPELL_ENDCAST] = { "GetTriggerPlayer", "GetTriggerUnit", "GetSpellAbility", "GetSpellAbilityId", "GetSpellAbilityUnit" },
            [EVENT_PLAYER_UNIT_PAWN_ITEM] = { "GetTriggerPlayer", "GetTriggerUnit", "GetBuyingUnit", "GetSoldItem", "GetSellingUnit", "GetManipulatedItem", "GetManipulatingUnit" },                                                   -- todo: test this combination
            [EVENT_PLAYER_UNIT_STACK_ITEM] = { "GetTriggerPlayer", "GetTriggerUnit", "BlzGetStackingItemSource", "BlzGetStackingItemTarget", "BlzGetStackingItemTargetPreviousCharges", "GetManipulatedItem", "GetManipulatingUnit" }, -- todo: figure out duplicates
        }

        local unitEventResponseMap = {
            [EVENT_UNIT_DAMAGED] = { "GetTriggerUnit", "GetEventDamage", "GetEventDamageSource", "BlzGetEventDamageTarget", "BlzGetEventDamageType", "BlzGetEventAttackType", "BlzGetEventWeaponType", "BlzGetEventIsAttack" },  -- todo: triggerUnit == ??
            [EVENT_UNIT_DAMAGING] = { "GetTriggerUnit", "GetEventDamage", "GetEventDamageSource", "BlzGetEventDamageTarget", "BlzGetEventDamageType", "BlzGetEventAttackType", "BlzGetEventWeaponType", "BlzGetEventIsAttack" }, -- todo: triggerUnit == ??
            [EVENT_UNIT_DEATH] = { "GetTriggerUnit", "GetDyingUnit", "GetKillingUnit" },
            [EVENT_UNIT_DECAY] = { "GetTriggerUnit", "GetDecayingUnit" },
            [EVENT_UNIT_DETECTED] = { "GetTriggerPlayer", "GetTriggerUnit", "GetDetectedUnit", "GetEventDetectingPlayer" },
            [EVENT_UNIT_HIDDEN] = { "GetTriggerUnit" }, -- what is this event even?
            [EVENT_UNIT_SELECTED] = playerUnitEventResponseMap[EVENT_PLAYER_UNIT_SELECTED],
            [EVENT_UNIT_DESELECTED] = playerUnitEventResponseMap[EVENT_PLAYER_UNIT_DESELECTED],
            [EVENT_UNIT_STATE_LIMIT] = { "GetTriggerUnit", "GetEventUnitState" },
            [EVENT_UNIT_ACQUIRED_TARGET] = { "GetTriggerUnit", "GetEventTargetUnit" },
            [EVENT_UNIT_TARGET_IN_RANGE] = { "GetTriggerUnit", "GetEventTargetUnit" },
            [EVENT_UNIT_ATTACKED] = { "GetTriggerUnit", "GetAttacker" },
            [EVENT_UNIT_RESCUED] = { "GetTriggerUnit", "GetRescuer" },
            [EVENT_UNIT_CONSTRUCT_CANCEL] = { "GetTriggerUnit", "GetConstructingStructure", "GetCancelledStructure" },
            [EVENT_UNIT_CONSTRUCT_FINISH] = { "GetTriggerUnit", "GetConstructedStructure" },
            [EVENT_UNIT_UPGRADE_START] = { "GetTriggerUnit", "GetConstructingStructure" },  -- todo: is this how these events work?
            [EVENT_UNIT_UPGRADE_CANCEL] = { "GetTriggerUnit", "GetConstructingStructure" }, -- todo: is this how these events work?
            [EVENT_UNIT_UPGRADE_FINISH] = { "GetTriggerUnit", "GetConstructedStructure" },  -- todo: is this how these events work?
            [EVENT_UNIT_TRAIN_START] = { "GetTriggerUnit", "GetTrainedUnitType" },
            [EVENT_UNIT_TRAIN_CANCEL] = { "GetTriggerUnit", "GetTrainedUnitType" },
            [EVENT_UNIT_TRAIN_FINISH] = { "GetTriggerUnit", "GetTrainedUnitType", "GetTrainedUnit" },
            [EVENT_UNIT_RESEARCH_START] = { "GetTriggerUnit", "GetResearched", "GetResearchingUnit" },
            [EVENT_UNIT_RESEARCH_CANCEL] = { "GetTriggerUnit", "GetResearched", "GetResearchingUnit" },
            [EVENT_UNIT_RESEARCH_FINISH] = { "GetTriggerUnit", "GetResearched", "GetResearchingUnit" },
            [EVENT_UNIT_ISSUED_ORDER] = { "GetTriggerUnit", "GetOrderedUnit", "GetIssuedOrderId" },
            [EVENT_UNIT_ISSUED_POINT_ORDER] = { "GetTriggerUnit", "GetOrderedUnit", "GetIssuedOrderId", "GetOrderPointX", "GetOrderPointY", --[["GetOrderPointLoc"]] },                                                                                              -- todo: orderTarget =  multiple things?
            [EVENT_UNIT_ISSUED_TARGET_ORDER] = { "GetTriggerUnit", "GetOrderedUnit", "GetIssuedOrderId", "GetOrderPointX", "GetOrderPointY", --[["GetOrderPointLoc",]] "GetOrderTarget", "GetOrderTargetDestructable", "GetOrderTargetUnit", "GetOrderTargetItem" }, -- todo: orderTarget =  multiple things?
            [EVENT_UNIT_HERO_LEVEL] = { "GetTriggerUnit", "GetLevelingUnit" },
            [EVENT_UNIT_HERO_SKILL] = { "GetTriggerUnit", "GetLearnedSkillLevel", "GetLearnedSkill", "GetLearningUnit" },
            [EVENT_UNIT_HERO_REVIVABLE] = { "GetTriggerUnit", "GetRevivableUnit" },
            [EVENT_UNIT_HERO_REVIVE_START] = { "GetTriggerUnit", "GetRevivingUnit" },
            [EVENT_UNIT_HERO_REVIVE_CANCEL] = { "GetTriggerUnit", "GetRevivingUnit" },
            [EVENT_UNIT_HERO_REVIVE_FINISH] = { "GetTriggerUnit", "GetRevivingUnit" },
            [EVENT_UNIT_SUMMON] = { "GetTriggerUnit", "GetSummoningUnit", "GetSummonedUnit" },
            [EVENT_UNIT_DROP_ITEM] = { "GetTriggerUnit", "GetManipulatingUnit", "GetManipulatedItem" },
            [EVENT_UNIT_PICKUP_ITEM] = { "GetTriggerUnit", "GetManipulatingUnit", "GetManipulatedItem", "BlzGetAbsorbingItem", "BlzGetManipulatedItemWasAbsorbed" },
            [EVENT_UNIT_USE_ITEM] = { "GetTriggerUnit", "GetManipulatingUnit", "GetManipulatedItem" },
            [EVENT_UNIT_LOADED] = { "GetTriggerUnit", "GetTransportUnit", "GetLoadedUnit" },
            [EVENT_UNIT_SELL] = { "GetTriggerUnit", "GetBuyingUnit", "GetSoldUnit", "GetSellingUnit" },
            [EVENT_UNIT_CHANGE_OWNER] = { "GetTriggerUnit", "GetChangingUnit", "GetChangingUnitPrevOwner" },
            [EVENT_UNIT_SELL_ITEM] = { "GetTriggerUnit", "GetBuyingUnit", "GetSoldItem", "GetSellingUnit" },
            [EVENT_UNIT_SPELL_CHANNEL] = { "GetTriggerUnit", "GetSpellAbility", "GetSpellAbilityId", "GetSpellAbilityUnit", "GetSpellTargetX", "GetSpellTargetY", --[[GetSpellTargetLoc,]] "GetSpellTargetUnit", "GetSpellTargetDestructable", "GetSpellTargetItem" },
            [EVENT_UNIT_SPELL_CAST] = { "GetTriggerUnit", "GetSpellAbility", "GetSpellAbilityId", "GetSpellAbilityUnit", "GetSpellTargetX", "GetSpellTargetY", --[[GetSpellTargetLoc,]] "GetSpellTargetUnit", "GetSpellTargetDestructable", "GetSpellTargetItem" },
            [EVENT_UNIT_SPELL_EFFECT] = { "GetTriggerUnit", "GetSpellAbility", "GetSpellAbilityId", "GetSpellAbilityUnit", "GetSpellTargetX", "GetSpellTargetY", --[[GetSpellTargetLoc,]] "GetSpellTargetUnit", "GetSpellTargetDestructable", "GetSpellTargetItem" },
            [EVENT_UNIT_SPELL_FINISH] = { "GetTriggerUnit", "GetSpellAbility", "GetSpellAbilityId", "GetSpellAbilityUnit" },
            [EVENT_UNIT_SPELL_ENDCAST] = { "GetTriggerUnit", "GetSpellAbility", "GetSpellAbilityId", "GetSpellAbilityUnit" },
            [EVENT_UNIT_PAWN_ITEM] = { "GetTriggerUnit", "GetBuyingUnit", "GetSoldItem", "GetSellingUnit", "GetManipulatedItem", "GetManipulatingUnit" },                                                   -- todo: test this combination
            [EVENT_UNIT_STACK_ITEM] = { "GetTriggerUnit", "BlzGetStackingItemSource", "BlzGetStackingItemTarget", "BlzGetStackingItemTargetPreviousCharges", "GetManipulatedItem", "GetManipulatingUnit" }, -- todo: figure out duplicates
        }

        -- unused events - cannot be passed to any native
        -- EVENT_WIDGET_DEATH
        -- EVENT_DIALOG_BUTTON_CLICK
        -- EVENT_DIALOG_CLICK

        ---@class EventRegistry
        EventRegistry = {}

        EventRegistry.Variable = defineEventType(TriggerRegisterVariableEvent, 4,
            gameEventResponseMap[EVENT_GAME_VARIABLE_LIMIT])
        EventRegistry.GameState = defineEventType(TriggerRegisterGameStateEvent, 4,
            gameEventResponseMap[EVENT_GAME_STATE_LIMIT])
        EventRegistry.Dialog = defineEventType(TriggerRegisterDialogEvent, 2, dialogEventResponses)
        EventRegistry.DialogButton = defineEventType(TriggerRegisterDialogButtonEvent, 2, dialogEventResponses)
        EventRegistry.Game = defineDynamicEventType(TriggerRegisterGameEvent, 2, gameEventResponseMap)
        EventRegistry.EnterRegion = defineEventTypeWithFilter(TriggerRegisterEnterRegion, 3,
            gameEventResponseMap[EVENT_GAME_ENTER_REGION])
        EventRegistry.LeaveRegion = defineEventTypeWithFilter(TriggerRegisterLeaveRegion, 3,
            gameEventResponseMap[EVENT_GAME_LEAVE_REGION])
        EventRegistry.TrackableHit = defineEventType(TriggerRegisterTrackableHitEvent, 2,
            gameEventResponseMap[EVENT_GAME_TRACKABLE_HIT])
        EventRegistry.TrackableTrack = defineEventType(TriggerRegisterTrackableTrackEvent, 2,
            gameEventResponseMap[EVENT_GAME_TRACKABLE_TRACK])
        EventRegistry.Command = defineEventType(TriggerRegisterCommandEvent, 3, {})
        EventRegistry.UpgradeCommand = defineEventType(TriggerRegisterUpgradeCommandEvent, 2, {})
        EventRegistry.Player = defineDynamicEventType(TriggerRegisterPlayerEvent, 3, playerEventResponseMap)
        EventRegistry.PlayerUnit = defineDynamicEventTypeWithFilter(TriggerRegisterPlayerUnitEvent, 4, playerUnitEventResponseMap)
        EventRegistry.PlayerAlliance = defineEventType(TriggerRegisterPlayerAllianceChange, 3,
            playerEventResponseMap[EVENT_PLAYER_ALLIANCE_CHANGED])
        EventRegistry.PlayerState = defineEventType(TriggerRegisterPlayerStateEvent, 5,
            playerEventResponseMap[EVENT_PLAYER_STATE_LIMIT])
        EventRegistry.Chat = defineEventType(TriggerRegisterPlayerChatEvent, 4,
            { "GetTriggerPlayer", "GetEventPlayerChatString", "GetEventPlayerChatStringMatched" } -- todo: test EVENT_PLAYER_CHAT
        )
        EventRegistry.Death = defineEventType(TriggerRegisterDeathEvent, 2,
            { "GetTriggerWidget", "GetTriggerDestructable", "GetTriggerUnit" } -- todo: needs a special thing?
        )
        EventRegistry.UnitState = defineEventType(TriggerRegisterUnitStateEvent, 5,
            unitEventResponseMap[EVENT_UNIT_STATE_LIMIT]) --todo: does GetTriggerUnit work for this?
        EventRegistry.Unit = defineDynamicEventType(TriggerRegisterUnitEvent, 3, unitEventResponseMap)
        EventRegistry.FilterUnit = defineDynamicEventTypeWithFilter(TriggerRegisterUnitEvent, 4, unitEventResponseMap) -- actually overrides TriggerRegisterFilterUnitEvent but uses the no-filter one
        EventRegistry.UnitInRange = defineEventType(TriggerRegisterUnitInRange, 4,
            unitEventResponseMap[EVENT_UNIT_TARGET_IN_RANGE])
        EventRegistry.Frame = defineEventType(BlzTriggerRegisterFrameEvent, 3,
            gameEventResponseMap[EVENT_GAME_CUSTOM_UI_FRAME]) -- todo: frame event responses
        EventRegistry.PlayerSync = defineEventType(BlzTriggerRegisterPlayerSyncEvent, 4,
            gameEventResponseMap[EVENT_PLAYER_SYNC_DATA])
        EventRegistry.PlayerKey = defineEventType(BlzTriggerRegisterPlayerKeyEvent, 5,
            gameEventResponseMap[EVENT_PLAYER_KEY])

        -- todo: timer override
        -- EventRegistry.TriggerRegisterTimerEvent
        -- EventRegistry.TriggerRegisterTimerExpireEvent

        -- Event response overrides
        do
            ---@param name string
            ---@return unknown
            local function getEventResponse(name)
                return threadData[coroutine.running()][name]
            end

            ---@param name string
            ---@param value unknown
            local function setEventResponse(name, value)
                threadData[coroutine.running()][name] = value
            end

            ---@param eventResponseGetterFunctionName string
            local function hijackNativeEventResponse(eventResponseGetterFunctionName)
                eventResponseMap[eventResponseGetterFunctionName] = _ENV[eventResponseGetterFunctionName]
                _ENV[eventResponseGetterFunctionName] = function()
                    return getEventResponse(eventResponseGetterFunctionName)
                end
            end

            ---@param eventResponseGetterFunctionName string
            ---@param invalidatorFunctionName string
            local function hijackEditableNativeEventResponse(eventResponseGetterFunctionName, invalidatorFunctionName)
                hijackNativeEventResponse(eventResponseGetterFunctionName)

                local old = _ENV[invalidatorFunctionName]
                ---@param value unknown
                _ENV[invalidatorFunctionName] = function(value)
                    old(value)
                    setEventResponse(invalidatorFunctionName, value)
                end
            end

            hijackNativeEventResponse("GetTriggeringTrigger") -- setup by AbstractTriggerEvent
            hijackNativeEventResponse("GetTriggerEventId")    -- setup by AbstractTriggerEvent
            hijackNativeEventResponse("GetTriggeringRegion")
            hijackNativeEventResponse("GetEnteringUnit")
            hijackNativeEventResponse("GetLeavingUnit")
            hijackNativeEventResponse("GetTriggeringTrackable")
            hijackNativeEventResponse("GetClickedButton")
            hijackNativeEventResponse("GetClickedDialog")
            hijackNativeEventResponse("GetSaveBasicFilename")
            hijackNativeEventResponse("GetTriggerPlayer")
            hijackNativeEventResponse("GetLevelingUnit")
            hijackNativeEventResponse("GetLearningUnit")
            hijackNativeEventResponse("GetLearnedSkill")
            hijackNativeEventResponse("GetLearnedSkillLevel")
            hijackNativeEventResponse("GetRevivableUnit")
            hijackNativeEventResponse("GetRevivingUnit")
            hijackNativeEventResponse("GetAttacker")
            hijackNativeEventResponse("GetRescuer")
            hijackNativeEventResponse("GetDyingUnit")
            hijackNativeEventResponse("GetKillingUnit")
            hijackNativeEventResponse("GetDecayingUnit")
            hijackNativeEventResponse("GetConstructingStructure")
            hijackNativeEventResponse("GetCancelledStructure")
            hijackNativeEventResponse("GetConstructedStructure")
            hijackNativeEventResponse("GetResearchingUnit")
            hijackNativeEventResponse("GetResearched")
            hijackNativeEventResponse("GetTrainedUnitType")
            hijackNativeEventResponse("GetTrainedUnit")
            hijackNativeEventResponse("GetDetectedUnit")
            hijackNativeEventResponse("GetSummoningUnit")
            hijackNativeEventResponse("GetSummonedUnit")
            hijackNativeEventResponse("GetTransportUnit")
            hijackNativeEventResponse("GetLoadedUnit")
            hijackNativeEventResponse("GetSellingUnit")
            hijackNativeEventResponse("GetSoldUnit")
            hijackNativeEventResponse("GetBuyingUnit")
            hijackNativeEventResponse("GetSoldItem")
            hijackNativeEventResponse("GetChangingUnit")
            hijackNativeEventResponse("GetChangingUnitPrevOwner")
            hijackNativeEventResponse("GetManipulatingUnit")
            hijackNativeEventResponse("GetManipulatedItem")
            hijackNativeEventResponse("BlzGetAbsorbingItem")
            hijackNativeEventResponse("BlzGetManipulatedItemWasAbsorbed")
            hijackNativeEventResponse("BlzGetStackingItemSource")
            hijackNativeEventResponse("BlzGetStackingItemTarget")
            hijackNativeEventResponse("BlzGetStackingItemTargetPreviousCharges")
            hijackNativeEventResponse("GetOrderedUnit")
            hijackNativeEventResponse("GetIssuedOrderId")
            hijackNativeEventResponse("GetOrderPointX")
            hijackNativeEventResponse("GetOrderPointY")
            hijackNativeEventResponse("GetOrderPointLoc")
            hijackNativeEventResponse("GetOrderTarget")
            hijackNativeEventResponse("GetOrderTargetDestructable")
            hijackNativeEventResponse("GetOrderTargetItem")
            hijackNativeEventResponse("GetOrderTargetUnit")
            hijackNativeEventResponse("GetSpellAbilityUnit")
            hijackNativeEventResponse("GetSpellAbilityId")
            hijackNativeEventResponse("GetSpellAbility")
            hijackNativeEventResponse("GetSpellTargetX")
            hijackNativeEventResponse("GetSpellTargetY")
            hijackNativeEventResponse("GetSpellTargetLoc")
            hijackNativeEventResponse("GetSpellTargetDestructable")
            hijackNativeEventResponse("GetSpellTargetItem")
            hijackNativeEventResponse("GetSpellTargetUnit")
            hijackNativeEventResponse("GetEventPlayerState")
            hijackNativeEventResponse("GetEventPlayerChatString")
            hijackNativeEventResponse("GetEventPlayerChatStringMatched")
            hijackNativeEventResponse("GetTriggerUnit")
            hijackNativeEventResponse("GetEventUnitState")
            hijackNativeEventResponse("GetEventDamageSource")
            hijackNativeEventResponse("GetEventDetectingPlayer")
            hijackNativeEventResponse("GetEventTargetUnit")
            hijackNativeEventResponse("GetTriggerWidget")
            hijackNativeEventResponse("BlzGetEventDamageTarget")
            hijackEditableNativeEventResponse("GetEventDamage", "BlzSetEventDamage")
            hijackEditableNativeEventResponse("BlzGetEventAttackType", "BlzSetEventAttackType")
            hijackEditableNativeEventResponse("BlzGetEventDamageType", "BlzSetEventDamageType")
            hijackEditableNativeEventResponse("BlzGetEventWeaponType", "BlzSetEventWeaponType")
            hijackNativeEventResponse("BlzGetEventIsAttack")
            hijackNativeEventResponse("BlzGetTriggerFrame")
            hijackNativeEventResponse("BlzGetTriggerFrameEvent")
            hijackNativeEventResponse("BlzGetTriggerFrameValue")
            hijackNativeEventResponse("BlzGetTriggerPlayerKey")
            hijackNativeEventResponse("BlzGetTriggerPlayerMetaKey")
            hijackNativeEventResponse("BlzGetTriggerPlayerIsKeyDown")
            hijackNativeEventResponse("BlzGetTriggerPlayerMouseX")
            hijackNativeEventResponse("BlzGetTriggerPlayerMouseY")
            hijackNativeEventResponse("BlzGetTriggerPlayerMousePosition")
        end
    end

    -- Triggers
    do
        ---@class FakeTrigger
        ---@field private enabled boolean
        ---@field private waitOnSleep boolean
        ---@field private execCount integer
        ---@field private evalCount integer
        ---@field private events table<AbstractTriggerEvent, true>
        ---@field private conditions table<fun():boolean, true>
        ---@field private actions table<fun(), true>
        FakeTrigger = {}
        FakeTrigger.__index = FakeTrigger

        ---@return FakeTrigger
        function FakeTrigger.create()
            return setmetatable({
                enabled = true,
                pauseOnWait = false,
                execCount = 0,
                evalCount = 0,
                conditions = SyncedTable.create(),
                actions = SyncedTable.create()
            }, FakeTrigger)
        end

        ---@param state boolean? if undefined, switches trigger from enabled to disabled or from disabled to enabled, otherwise uses the state value
        function FakeTrigger:toggle(state)
            if state then
                self.enabled = true
            elseif state == false then
                self.enabled = false
            else
                self.enabled = not self.enabled
            end
        end

        ---@return boolean
        function FakeTrigger:isEnabled()
            return self.enabled
        end

        ---@param waitOnSleep boolean
        function FakeTrigger:setWaitOnSleep(waitOnSleep)
            self.waitOnSleep = waitOnSleep
        end

        ---@return boolean
        function FakeTrigger:isWaitOnSleep()
            return self.waitOnSleep
        end

        ---@param event AbstractTriggerEvent
        function FakeTrigger:addEvent(event)
            self.events[event] = true
            addEventListener(event, self)
        end

        ---@param event AbstractTriggerEvent
        function FakeTrigger:removeEvent(event)
            self.events[event] = nil
            removeEventListener(event, self)
        end

        function FakeTrigger:clearEvents()
            for event, _ in pairs(self.events) do
                removeEventListener(event, self)
            end
            self.events = SyncedTable.create()
        end

        ---@param condition fun():boolean
        function FakeTrigger:addCondition(condition)
            self.conditions[condition] = true
        end

        ---@param condition fun():boolean
        function FakeTrigger:removeCondition(condition)
            self.conditions[condition] = nil
        end

        function FakeTrigger:clearConditions()
            self.conditions = SyncedTable.create()
        end

        ---@return boolean
        function FakeTrigger:evaluate()
            self.evalCount = self.evalCount + 1
            for condition, _ in pairs(self.conditions) do
                if not condition() then
                    return false
                end
            end
            return true
        end

        ---@return integer
        function FakeTrigger:getEvalCount()
            return self.evalCount
        end

        ---@param action fun()
        function FakeTrigger:addAction(action)
            self.actions[action] = true
        end

        ---@param action fun()
        function FakeTrigger:removeAction(action)
            self.actions[action] = nil
        end

        function FakeTrigger:clearActions()
            self.actions = SyncedTable.create()
        end

        ---@param threads thread[]
        ---@return boolean
        local function allDone(threads)
            for _, thread in threads do
                if coroutine.status(thread) ~= 'dead' then
                    return false
                end
            end
            return true
        end

        ---@param withSleep boolean?
        function FakeTrigger:execute(withSleep)
            local parentThread = coroutine.running()
            self.execCount = self.execCount + 1
            if withSleep and threadData[parentThread].waitOnSleep then
                local threads = {}
                for action, _ in pairs(self.actions) do
                    local thisThread = coroutine.create(function()
                        action()
                        if allDone(threads) then
                            coroutine.resume(parentThread)
                        end
                    end)
                    table.insert(threads, action)

                    local data = setupThreadData(thisThread, parentThread)
                    rawset(data, "GetTriggeringTrigger", self) -- don't overwrite master threadData entry
                    rawset(data, "waitOnSleep", self.waitOnSleep)
                    coroutine.resume(thisThread)
                end
                if not allDone(threads) then
                    coroutine.yield(parentThread)
                end
            else
                for action, _ in pairs(self.actions) do
                    local thisThread = coroutine.create(action)
                    local data = setupThreadData(thisThread, parentThread)
                    rawset(data, "GetTriggeringTrigger", self) -- don't overwrite master threadData entry
                    rawset(data, "waitOnSleep", self.waitOnSleep)
                    coroutine.resume(thisThread)
                end
            end
        end

        ---@return integer
        function FakeTrigger:getExecCount()
            return self.execCount
        end

        function FakeTrigger:reset()
            self.execCount = 0
            self.evalCount = 0
        end

        -- Override Natives
        do
            ---@param duration number
            function PolledWait(duration)
                local thread = coroutine.running()
                TimerQueue:callDelayed(duration, coroutine.resume, thread)
                coroutine.yield(thread)
            end

            CreateTrigger = FakeTrigger.create
            DestroyTrigger = DoNothing
            ResetTrigger = FakeTrigger.reset
            EnableTrigger = function(trigger) trigger:toggle(true) end ---@type fun(trigger: FakeTrigger)
            DisableTrigger = function(trigger) trigger:toggle(false) end ---@type fun(trigger: FakeTrigger)
            IsTriggerEnabled = FakeTrigger.isEnabled
            TriggerWaitOnSleeps = FakeTrigger.setWaitOnSleep
            IsTriggerWaitOnSleeps = FakeTrigger.isWaitOnSleep
            GetTriggerEvalCount = FakeTrigger.getEvalCount
            GetTriggerExecCount = FakeTrigger.getExecCount
            TriggerAddCondition = function(trigger, condition)
                FakeTrigger.addCondition(trigger, condition)
                return condition
            end ---@type fun(trigger: FakeTrigger, condition: function): function
            TriggerRemoveCondition = FakeTrigger.removeCondition
            TriggerClearConditions = FakeTrigger.clearConditions
            TriggerAddAction = function(trigger, action)
                FakeTrigger.addAction(trigger, action)
                return action
            end ---@type fun(trigger: FakeTrigger, action: function): function
            TriggerRemoveAction = FakeTrigger.removeAction
            TriggerClearActions = FakeTrigger.clearActions
            TriggerSleepAction = PolledWait
            -- TriggerWaitForSound -- I'll probably leave this as is
            TriggerEvaluate = FakeTrigger.evaluate
            TriggerExecute = FakeTrigger.execute
            ---@param whichTrigger FakeTrigger|trigger
            TriggerExecuteWait = function(whichTrigger) whichTrigger --[[@as FakeTrigger]]:execute(true) end
            -- TriggerSyncStart -- I'll probably leave this as is
            -- TriggerSyncReady -- I'll probably leave this as is

            ---@param EventRegistryMethod function
            local function makeTriggerEventOverrideWrapper(EventRegistryMethod)
                ---@param trigger FakeTrigger
                ---@param ... unknown
                ---@return AbstractTriggerEvent
                return function(trigger, ...)
                    local event = EventRegistryMethod(..., true)
                    trigger:addEvent(event)
                    return event
                end
            end

            TriggerRegisterVariableEvent = makeTriggerEventOverrideWrapper(EventRegistry.Variable) ---@overload fun(trigger: FakeTrigger, varname: string, opcode: limitop, limitval: number): AbstractTriggerEvent
            -- TriggerRegisterTimerEvent = makeTriggerEventOverrideWrapper(EventRegistry.Timer) ---@overload fun(trigger: FakeTrigger, timeout: number, periodic: boolean): AbstractTriggerEvent
            -- TriggerRegisterTimerExpireEvent = makeTriggerEventOverrideWrapper(EventRegistry.TimerExpired) ---@overload fun(trigger: FakeTrigger, timer: timer): AbstractTriggerEvent
            TriggerRegisterGameStateEvent = makeTriggerEventOverrideWrapper(EventRegistry.GameState) ---@overload fun(trigger: FakeTrigger, gamestate: gamestate, opcode: limitop, limitval: number): AbstractTriggerEvent
            TriggerRegisterDialogEvent = makeTriggerEventOverrideWrapper(EventRegistry.Dialog) ---@overload fun(trigger: FakeTrigger, dialog: dialog): AbstractTriggerEvent
            TriggerRegisterDialogButtonEvent = makeTriggerEventOverrideWrapper(EventRegistry.DialogButton) ---@overload fun(trigger: FakeTrigger, button: button): AbstractTriggerEvent
            TriggerRegisterGameEvent = makeTriggerEventOverrideWrapper(EventRegistry.Game) ---@overload fun(trigger: FakeTrigger, gameEvent: gameevent): AbstractTriggerEvent
            TriggerRegisterEnterRegion = makeTriggerEventOverrideWrapper(EventRegistry.EnterRegion) ---@overload fun(trigger: FakeTrigger,region: region, filter: boolexpr?): AbstractTriggerEvent
            TriggerRegisterLeaveRegion = makeTriggerEventOverrideWrapper(EventRegistry.LeaveRegion) ---@overload fun(trigger: FakeTrigger,region: region, filter: boolexpr?): AbstractTriggerEvent
            TriggerRegisterTrackableHitEvent = makeTriggerEventOverrideWrapper(EventRegistry.TrackableHit) ---@overload fun(trigger: FakeTrigger,trackable: trackable): AbstractTriggerEvent
            TriggerRegisterTrackableTrackEvent = makeTriggerEventOverrideWrapper(EventRegistry.TrackableTrack) ---@overload fun(trigger: FakeTrigger,trackable: trackable): AbstractTriggerEvent
            TriggerRegisterCommandEvent = makeTriggerEventOverrideWrapper(EventRegistry.Command) ---@overload fun(trigger: FakeTrigger,ability: integer, order: string): AbstractTriggerEvent
            TriggerRegisterUpgradeCommandEvent = makeTriggerEventOverrideWrapper(EventRegistry.UpgradeCommand) ---@overload fun(trigger: FakeTrigger,upgrade: integer): AbstractTriggerEvent
            TriggerRegisterPlayerEvent = makeTriggerEventOverrideWrapper(EventRegistry.Player) ---@overload fun(trigger: FakeTrigger,player: player, playerEvent: playerevent): AbstractTriggerEvent
            TriggerRegisterPlayerUnitEvent = makeTriggerEventOverrideWrapper(EventRegistry.PlayerUnit) ---@overload fun(trigger: FakeTrigger,player: player, playerUnitEvent: playerunitevent, filter: boolexpr?): AbstractTriggerEvent
            TriggerRegisterPlayerAllianceChange = makeTriggerEventOverrideWrapper(EventRegistry.PlayerAlliance) ---@overload fun(trigger: FakeTrigger,player: player, allianceType: alliancetype): AbstractTriggerEvent
            TriggerRegisterPlayerStateEvent = makeTriggerEventOverrideWrapper(EventRegistry.PlayerState) ---@overload fun(trigger: FakeTrigger,player: player, state: playerstate, operation: limitop, limitValue: number): AbstractTriggerEvent
            TriggerRegisterPlayerChatEvent = makeTriggerEventOverrideWrapper(EventRegistry.Chat) ---@overload fun(trigger: FakeTrigger,player: player, matchText: string, exactMatch: boolean): AbstractTriggerEvent
            TriggerRegisterDeathEvent = makeTriggerEventOverrideWrapper(EventRegistry.Death) ---@overload fun(trigger: FakeTrigger,widget: widget): AbstractTriggerEvent
            TriggerRegisterUnitStateEvent = makeTriggerEventOverrideWrapper(EventRegistry.UnitState) ---@overload fun(trigger: FakeTrigger,unit: unit, state: unitstate, operation: limitop, limitValue: number): AbstractTriggerEvent
            TriggerRegisterUnitEvent = makeTriggerEventOverrideWrapper(EventRegistry.Unit) ---@overload fun(trigger: FakeTrigger,unit: unit, event: unitevent): AbstractTriggerEvent
            TriggerRegisterFilterUnitEvent = makeTriggerEventOverrideWrapper(EventRegistry.FilterUnit) ---@overload fun(trigger: FakeTrigger,unit: unit, event: unitevent, filter: boolexpr?): AbstractTriggerEvent
            TriggerRegisterUnitInRange = makeTriggerEventOverrideWrapper(EventRegistry.UnitInRange) ---@overload fun(trigger: FakeTrigger,unit: unit, range: number, filter: boolexpr?): AbstractTriggerEvent
            BlzTriggerRegisterFrameEvent = makeTriggerEventOverrideWrapper(EventRegistry.Frame) ---@overload fun(trigger: FakeTrigger,frame: framehandle, eventType: frameeventtype): AbstractTriggerEvent
            BlzTriggerRegisterPlayerSyncEvent = makeTriggerEventOverrideWrapper(EventRegistry.PlayerSync) ---@overload fun(trigger: FakeTrigger,player: player, prefix: string, fromServer: boolean): AbstractTriggerEvent
            BlzTriggerRegisterPlayerKeyEvent = makeTriggerEventOverrideWrapper(EventRegistry.PlayerKey) ---@overload fun(trigger: FakeTrigger,player: player, key: oskeytype, metaKey: integer, keyDown: boolean): AbstractTriggerEvent
        end
    end
end)
if Debug then Debug.endFile() end
