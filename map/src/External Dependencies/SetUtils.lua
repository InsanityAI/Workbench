if Debug and Debug.beginFile then Debug.beginFile("SetUtils") end ---@diagnostic disable-line
--[[

 ------------------------------------
 -- | API Set & Set Utils v1.3.5 | --
 ------------------------------------

 by Eikonium

 --> https://www.hiveworkshop.com/threads/setutils.353716/

-------------------------------------------------------------------------------------------------------------------------------------------------------------------------
| Sets are data containers that can contain every element only once. Much like unitgroups, but not limited to units.                                                    |
| The Set-API offers functions to create, alter and loop through Sets.                                                                                                  |
| The SetUtils library offers equivalents to pick-all-units-matching-condition-natives (players/destructables/items) that return a Set instead of a group or force.     |
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------

-------------------------------------------------------------------------------------------------------------------------------------------------------------------------
| Optional Dependencies:                                                                                                                                                |
|                                                                                                                                                                       |
| Total Initialization by Bribe:                                                                                                                                        |
|       https://www.hiveworkshop.com/threads/lua-global-initialization.317099/                                                                                          |
|       Having Total Init in your map script frees you of creating a GUI trigger that runs SetUtils.createTriggers() on Map Init.                                       |
|       Please make sure that you copy Global Initilization to a script file in your map that is located above(!) the Set library.                                      |
| SyncedTable                                                                                                                                                           |
|       https://www.hiveworkshop.com/threads/syncedtable.353715/                                                                                                        |
|       Many Set-functionalities like union, intersection, except, fromTable and addAllKeys do support arrays and SyncedTables, but not normal tables (because it could |
|       lead to desyncs).                                                                                                                                               |
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------

-------------------------------------------------------------------------------------------------------------------------------------------------------------------------
* API Functions:
*
* The API uses standard Lua object-oriented syntax, i.e. you have to pay attention to whether the function you want to use requires dot- or colon-notation (it's clearly visible in the documentation).
* The library provides a debug-mode that allows you to get notified about when you used dots instead of colons and vice versa.
*
* -------------
* | Set class |
* -------------
*        - The class itself mainly offers ways to create new Sets.
*    Set.create(...) -> Set
*        - Creates a new Set and adds all specified arguments as elements.
*        - Example:
*           local a = Set.create("bla", 50, Player(0)) --creates a Set with 3 elements.
*    Set.union(...) -> Set
*        - Creates a new Set as the union of all specified arguments.
*        - All arguments must be either Sets, SyncedTables, arrays, forces or groups. If specifying an array, it must form a sequence. Otherwise, values beyond the first nil-key are ignored.
*    Set.intersection(...) -> Set
*        - Creates a new Set as the intersection of all specified arguments.
*        - All arguments must be either Sets, SyncedTables, arrays, forces or groups. If specifying an array, it must form a sequence. Otherwise, values beyond the first nil-key are ignored.
*    Set.except(containerA, containerB) -> Set
*        - Creates a new Set having all elements from specified containerA except the elements from specified containerB.
*        - All arguments must be either Sets, SyncedTables, arrays, forces or groups. If specifying an array, it must form a sequence. Otherwise, values beyond the first nil-key are ignored.
*    Set.fromForce(force) -> Set
*        - Creates a new Set containing all players from the specified force.
*    Set.fromGroup(group) -> Set
*        - Creates a new Set containing all units fromn the specified group.
*    Set.fromTable(array|SyncedTable) -> Set
*        - Creates a new Set containing all elements from the specified table (elements refer to the values of the table, not the keys).
*        - Table must be either a SyncedTable or an array. If specifying an array, it must form a sequence. Otherwise, values beyond the first nil-key are ignored.
* ---------------
* | Set objects |
* ---------------
*        - The following methods are available for any existing Set object.
*    --------------------------------
*    | ADDING AND REMOVING ELEMENTS |
*    --------------------------------
*    <Set>:add(...)
*        - adds any number of specified arguments as elements to <Set>
*        - ignores all arguments that are already contained in <Set>
*        - returns <Set> to allow for chaining methods
*        - if you highly care for performance and only want to add one single element, you can use <Set>:addSingle(element) instead.
*    <Set>:remove(...)
*        - removes any number of specified arguments from <Set>
*        - ignores all arguments that are not contained in <Set>
*        - returns <Set> to allow for chaining methods
*        - if you highly care for performance and only want to remove one single element, you can use <Set>:removeSingle(element) instead.
*    <Set>:addAll(container)
*        - adds all elements from the specified container as elements to <Set> (and ignores everything that is already present in <Set>)
*        - the container must be a Set, array, force or group (in case of an array, "elements" refers to its values)
*        - returns <Set> to allow for chaining methods
*    <Set>:addAllKeys(SyncedTable) [or any table with a multiplayer-synched pairs function]
*        - adds all keys from the specified table as elements to <Set>
*        - this method is only multiplayer-compatible, if you input a SyncedTable or if you have overwritten the pairs-function to make it synchronous on the input table. Otherwise, using this method can lead to a desync.
*        - returns <Set> to allow for chaining methods
*    <Set>:removeAll(container)
*        - removes all elements present in the specified container from <Set> (and ignores everything that is not contained in <Set>)
*        - the container must be a Set, array, force or group.
*        - returns <Set> to allow for chaining methods
*    <Set>:retainAll(container)
*        - only keeps elements in <Set> that are also contained in the specified container and removes the rest.
*        - the container must be a Set, array, force or group.
*        - returns <Set> to allow for chaining methods
*    <Set>:clear()
*        - removes all elements from <Set>
*        - returns <Set> (which is empty now) to allow for chaining methods
*    ---------------------
*    | LOOPING MECHANISM |
*    ---------------------
*    <Set>:elements()
*        - iterator function for the generic for-loop over <Set>
*        - Example:
*             local exampleSet = Set.create(Player(0), Player(1), "bla", 5)
*             for dings in exampleSet:elements() do
*                 print(dings)
*             end
*    -----------
*    | UTILITY |
*    -----------
*    <Set>:contains(element) -> boolean
*        - returns true, if the element is contained in <Set> and false otherwise.
*    <Set>:size() -> integer
*        - returns the number of elements of the set.
*    <Set>:isEmpty() -> boolean
*        - returns true, if <Set> contains no elements, and false otherwise.
*    <Set>:toString() -> string
*        - returns a comma separated list of all elements of <Set>, engulfed in {}-brackets.
*    <Set>:print()
*        - prints <Set>:toString() on screen.
*    <Set>:random() -> any
*        - returns a random element from <Set>
*    <Set>:toArray() -> any[]
*        - returns a normal array (table) containing ell elements from <Set>.
*        - not really useful in most cases, as arrays are not better than sets most of the time. There are exceptions however, e.g. when you want to sort the elements (Sets don't have an order, but arrays have).
*    <Set>:intersects(otherSet) -> boolean
*        - Returns true, if <Set> has at least one common element with the specified argument.
*        - Argument currently only supports other Sets - not arrays, forces or groups.
*    <Set>:copy() -> Set
*        - Returns a new Set containing the same elements as <Set>.
* -------------------
* | Set Utils class |
* -------------------
*        - this class offers set equivalents for the Wc3 natives that pick and return a group of units, players, destructables and items.
*    ------------------
*    | SIMPLE GETTERS |
*    ------------------
*        | -> Units |
*        ------------
*        SetUtils.getUnitsInRect(rect)
*            - returns a new Set with all units located in the specified rect
*            - like in the Warcraft native, the rect is considered an half-open rectangle (closed to west and south, open to east and north?). That means that entering units are not guaranteed to be picked.
*            - does not pick units having the locust ability
*        SetUtils.getUnitsInRange(float x, float y, float radius)
*            - returns a new Set with all units within the specified radius of the specified coordinates.
*            - does not pick units having the locust ability
*        SetUtils.getUnitsOfPlayer(player)
*            - returns a new Set with all units owned by the specified player.
*        SetUtils.getUnitsOfTypeId(integer typeId)
*            - returns a new Set with all units on the map having the specified type.
*            - the typeId parameter has to be created out of the FourCC-function, e.g. SetUtils.getUnitsOfTypeId(FourCC('hfoo'))
*        SetUtils.getUnitsOfPlayerAndTypeId(player, integer typeId)
*            - returns a new Set with all units owned by the specified player and having the specified type.
*        SetUtils.getUnitsSelected(player)
*            - returns a new Set with all units currently being selected by the specified player.
*            - returns the empty Set, when the player doesn't have any units selected.
*            - this function needs to synchronize local selections between players, so it might not be as instant as usual (needs investigation).
*        ------------------------------------
*        | -> Players, Destructables, Items |
*        ------------------------------------
*        SetUtils.getPlayersAll()
*            - returns a new Set containing all players that were present during map init, i.e. a copy of InitialPlayersPlaying.
*        SetUtils.getDestructablesInRect(rect)
*            - returns a Set with all Destructables located in the specified rect.
*        SetUtils.getItemsInRect(rect)
*            - returns a Set with all Items located in the specified rect.
*    -----------------------
*    | CONDITIONAL GETTERS |
*    -----------------------
*        - Below functions are variants to the above functions that take a condition function as an additional parameter.
*          Only elements passing the condition will join the set.
*        - The condition must be a either a Wc3 native conditionfunc or a Lua-function that takes nothing and returns a boolean.
*          If you choose to provide a Lua-function, SetUtils will automatically convert it to a conditionfunc by applying the Condition()-native.
*          If you use the same condition function over and over, it is recommended that you apply Condition() yourself, save it in a variable and use the same thing instead of creating a new one every time.
*        - Use GetFilterUnit() inside of the condition function to refer to the unit being checked.
*        ------------
*        | -> Units |
*        ------------
*        SetUtils.getUnitsInRectMatching(rect, condition)
*            - returns a new Set with all units located in the specified rect and matching the specified condition.
*            - like the Warcraft native, the rect is considered an half-open rectangle (closed to west and south, open to east and north?). That means that entering units are not guaranteed to be picked.
*            - Example:
*               local r = <someRect>
*               local condition = Condition(function() return GetOwningPlayer(GetFilterUnit()) == Player(0) end)
*               local exampleSet = SetUtils.getUnitsInRectMatching(r, condition) --will contain all units in the rect owned by Player 1.
*        SetUtils.getUnitsInRangeMatching(float x, float y, float radius, condition)
*            - returns a new Set with all units within the specified radius of the specified coordinates that match the specified condition.
*        SetUtils.getUnitsOfPlayerMatching(player, condition)
*            - returns a new Set with all units owned by the specified player and matching the specified condition.
*        SetUtils.getUnitsOfTypeIdMatching(integer typeId, condition)
*            - returns a new Set with all units on the map having the specified type and matching the specified condition.
*            - the typeId parameter has to be created out of the FourCC-function, e.g. SetUtils.getUnitsOfTypeId(FourCC('hfoo'))
*        SetUtils.getUnitsSelectedMatching(player, condition)
*            - returns a new Set with all units currently being selected by the specified player and matching the specified condition.
*            - returns the empty Set, when the player doesn't have any units selected.
*            - this function needs to synchronize local selections between players, so it might not be as instant as usual (needs investigation).
*        ------------------------------------
*        | -> Players, Destructables, Items |
*        ------------------------------------
*        SetUtils.getPlayersMatching()
*            - returns a new Set containing all players that were present during map init and who match the specified condition.
*        SetUtils.getDestructablesInRectMatching(rect)
*            - returns a Set with all Destructables located in the specified rect and matching the specified condition.
*        SetUtils.getItemsInRectMatching(rect)
*            - returns a Set with all Items located in the specified rect and matching the specified condition.
*    -----------
*    | UTILITY |
*    -----------
*    SetUtils.clearInvalidUnitRefs(Set [, boolean checkIfUnit])
*        - Removes all invalid unit references from the specified Set, i.e. units that have already been removed from the game.
*        - Only useful for Sets that actually contain units.
*        - If your Set contains non-unit elements, you must set the second parameter to true to avoid crashes.
*        - Good to use as safety mechanism before looping over unit Sets, because Sets (in contrast to Wc3 native unitgroups) don't automatically remove units that leave the game after Set creation.
*        - As an alternative, you can use SetUtils.subscribeSetToAutoUnitRemoval(Set) (see below) on the Set to automatically remove invalid unit references for the rest of the game.
*    SetUtils.subscribeSetToAutoUnitRemoval(Set [, boolean subscribe_yn])   [requires you to declare CUSTOM_DEFEND_ABICODE, see options below]
*        - Subscribes the specified set to automatic removal of invalid unit references, i.e. for the rest of the game, units that are removed from the game will also be removed from the specified set.
*        - Only useful for Sets that actually contain units. Avoids bugs, when looping over it. As an alternative, you can just call SetUtils.clearInvalidUnitReferences (see above) on the Set before each loop.
*        - Set the second parameter to false (default true) to unsubscribe the specified Set from the automatic unit cleaning.
*        - As long as a Set is subscribed, it will not be garbage collected.
*    SetUtils.triggerRegisterAnyUnitRemoveEvent(trigger)     [requires you to declare CUSTOM_DEFEND_ABICODE, see options below]
*        - Adds the event "any unit is removed from the game" to the specified trigger. Not compatible with other events on the same trigger!
*        - Use "GetTriggerUnit()" to refer to the unit being removed.
*        - Will trigger twice, if the remove unit also had the original Defend ability (or just another copy), so don't use this, if you also plan to use the Defend ability in your map.
*        - This functionality is not really Set-specific, but the system does use the event internally, so there is no reason to not offer it to you guys.
----------------------------------------------------------------------------------------------------------------------------------------------------------------------------]]

-- disable sumneko extension warnings for imported resource
---@diagnostic disable

do
    -----------------
    -- | OPTIONS | --
    -----------------

    -- Debug-Mode will notify you per ingame error-message, if you confused dot-notation and colon-notation. The check doesn't recognize 100% of confusions, but works for most of the cases (and most important, it has no false positives).
    -- Set this to false before the release of your map.
    local DEBUG_MODE = true             ---@type boolean

    -- To be able to use SetUtils.subscribeSetToAutoUnitRemoval, you must provide the ability code of your custom Defend ability below (make a copy of the Defend ability of the Human footman that you don't use for other purposes).
    local CUSTOM_DEFEND_ABICODE = nil   ---@type integer -- Enter the abi code of your custom defend ability here (as FourCC('xxxx')). If you do, this resource will use the ability to detect units leaving the game.

    ---Start of code. No need to read further.---

    ---------------------
    -- | Set Library | --
    ---------------------

    ---@class Set
    Set = {
        data = {}               ---@type table data structure saving the actual elements
        ,   orderedKeys = {}    ---@type any[] to keep iteration order synchronized in multiplayer
        ,   n = 0               ---@type number number of elements in the Set
    }
    Set.__index = Set
    Set.__name = 'Set'

    ---Prints an error message on screen, applying red color and the ERROR-prefix.
    ---@param message string
    local printError = function(message) print("|cffff5555Error: " .. message .. "|r") end

    ---To be used as a first-line-check in methods that are required to be called with colon-notation.
    ---Prints an error-message on screen, if the method was instead used with dot-notation.
    ---Doesn't catch all false uses, but most of them. Most importantly, it never brings up false positives.
    ---@param methodName string name of the method, will be printed as part of the error message
    ---@param pseudoSelf any using colon-notation does always pass the object itself as first argument, so we can check it for if it is really a Set (ok) or not (error)
    local checkColonNotation = function(methodName, pseudoSelf)
        if getmetatable(pseudoSelf) ~= Set then
            printError("Method " .. methodName .. " used with .-notation instead of :-notation.")
        end
    end

    ---To be used as a first-line-check in functions that are required to be called with dot-notation.
    ---Prints an error-message on screen, if the method was instead used with colon-notation.
    ---Doesn't catch all false uses, but most of them. Most importantly, it never brings up false positives.
    ---@param methodName string name of the method, will be printed as part of the error message
    ---@param firstArgumentOfMethod any using colon-notation does always pass the object itself as first argument, so in case of a wrong Set:method() call, the first passed argument would be the Set class itself (error).
    local checkDotNotation = function(methodName, firstArgumentOfMethod)
        if firstArgumentOfMethod == Set then
            printError("Method " .. methodName .. " used with :-notation instead of .-notation.")
        end
    end

    ---Returns the wc3-type of any object, i.e. 'unit', if the input is a unit. Returns the Lua-type in case the input is not a Warcraft-type.
    ---@param input any the object to be checked
    ---@return string wc3Type
    local wc3Type = function (input)
        local typeString = type(input)
        if typeString == 'userdata' then
            typeString = tostring(input) --toString returns the warcraft type plus a colon and some hashstuff.
            return string.sub(typeString, 1, (string.find(typeString, ":", nil, true) or 0) -1) --string.find returns nil, if the argument is not found, which would break string.sub. So we need or as coalesce.
        else
            return typeString
        end
    end

    --- Set constructor. Creates a Set containing all specified arguments as elements. Not specifying any arguments will create an empty Set.
    ---@param ... any
    ---@return Set
    function Set.create(...)
        if DEBUG_MODE then checkDotNotation("Set.create(...)", ...) end
        local new = {}
        new.data = {} --place to save the actual elements of the set. Elements can't be saved in self, because they might conflict with function names of the class (adding the element "add" would prevent future access to the add-method).
        new.orderedKeys = {}
        setmetatable(new, Set)
        new:add(...)
        return new
    end

    --- Returns true, if the input parameter is a Set and false otherwise.
    ---@param anything any
    ---@return boolean
    function Set.isSet(anything)
        if DEBUG_MODE then checkDotNotation("Set.isSet(anything)", anything) end
        return getmetatable(anything) == Set
    end

    ---Adds a single given element to the set. Already existing Elements are a valid input, but won't be added again.
    ---@param element any
    ---@return Set self
    function Set:addSingle(element)
        if DEBUG_MODE then checkColonNotation("Set:addSingle(element)", self) end
        if element ~=nil and not self.data[element] then
            self.n = self.n + 1
            self.data[element] = self.n
            self.orderedKeys[self.n] = element
        end
        return self
    end

    ---Adds all specified arguments to the Set. Already existing elements are a valid input, but won't be added again.
    ---E.g. add(2, {2}) would add two elements, the number 2 and Set containing the number 2.
    ---@param ... any
    ---@return Set self
    function Set:add(...)
        if DEBUG_MODE then checkColonNotation("Set:add(...)", self) end
        for i = 1, select('#', ...) do
            self:addSingle(select(i, ...))
        end
        return self
    end

    ---Removes the specified element from set, if existent. Non-existent elements are a valid input, but won't change the Set.
    ---@param element any
    ---@return Set self
    function Set:removeSingle(element)
        if DEBUG_MODE then checkColonNotation("Set:removeSingle(element)", self) end
        if self.data[element] then
            local i,n = self.data[element], self.n
            self.data[self.orderedKeys[n]] = i --last element takes iteration slot of removed element
            self.orderedKeys[i] = self.orderedKeys[n]
            self.orderedKeys[n] = nil
            self.data[element] = nil
            self.n = self.n - 1
        end
        return self
    end

    ---Removes all specified arguments from the Set, if existent. Non-existent elements are a valid input, but won't change the Set.
    ---@param ... any
    ---@return Set self
    function Set:remove(...)
        if DEBUG_MODE then checkColonNotation("Set:remove(...)", self) end
        for i = 1, select('#', ...) do
            self:removeSingle(select(i, ...))
        end
        return self
    end

    ---returns true, if set contains given element, false otherwise
    ---@param element any element to check for
    ---@return boolean
    function Set:contains(element)
        if DEBUG_MODE then checkColonNotation("Set:contains(element)", self) end
        return self.data[element] ~= nil
    end

    ---Keeps all Elements in the set that are also present in another Set/SyncedTable/array/Force/Group. Removes all elements that are not.
    ---For SyncedTables and Arrays, elements refer to the values, not the keys. If the specified container is an array, it must form a sequence. Otherwise, values beyond the first nil-key are ignored.
    ---@param container Set | SyncedTable | any[] | force | group
    ---@return Set self
    function Set:retainAll(container)
        if DEBUG_MODE then checkColonNotation("Set:retainAll(container)", self) end
        local typeString = wc3Type(container)
        --first add all elements to a Set, if the input container is not already. This allows to intersect more easily.
        local containerAsSet = Set.create()
        if typeString == 'group' then --Case 1: container is group
            ForGroup(container, function () containerAsSet:addSingle(GetEnumUnit()) end)
        elseif typeString == 'force' then --Case 2: container is force
            ForForce(container, function () containerAsSet:addSingle(GetEnumPlayer()) end)
        elseif (getmetatable(container) == getmetatable(self)) then --Case 3: container is Set
            containerAsSet = container
        elseif SyncedTable and SyncedTable.isSyncedTable(container) then --Case 4: container is SyncedTable
            for _, element in pairs(container) do --pairs-function is multiplayer synced for SyncedTables.
                containerAsSet:addSingle(element)
            end
        elseif(typeString == 'table') then --Case 5: container is a Table. We then assume, it's an array.
            for _, element in ipairs(container) do
                containerAsSet:addSingle(element)
            end
        else --Case 6: invalid input.
            printError("retainAll is only compatible with a Set, SyncedTable, array, force or group")
            ---@diagnostic disable-next-line: missing-return-value
            return
        end

        -- do intersection
        for element in self:elements() do
            if not containerAsSet:contains(element) then self:removeSingle(element) end
        end
        return self
    end

    ---Removes all elements from the set that are present in another Set/SyncedTable/array/Force/Group. For SyncedTables and arrays, elements means values, not keys.
    ---If specifying an array, it must form a sequence. Otherwise, values beyond the first nil-key will be ignored.
    ---@param container Set | SyncedTable | any[] | force | group
    ---@return Set self
    function Set:removeAll(container)
        if DEBUG_MODE then checkColonNotation("Set:removeAll(container)", self) end
        local typeString = wc3Type(container)
        if typeString == 'group' then --Case 1: container is a group
            ForGroup(container, function () self:removeSingle(GetEnumUnit()) end)
        elseif typeString == 'force' then --Case 2: container is a force
            ForForce(container, function () self:removeSingle(GetEnumPlayer()) end)
        elseif (getmetatable(container) == getmetatable(self)) then --Case 3: container is a Set
            for element in container:elements() do
                self:removeSingle(element)
            end
        elseif SyncedTable and SyncedTable.isSyncedTable(container) then --Case 4: container is SyncedTable
            for _, element in pairs(container) do --pairs-function is multiplayer synced for SyncedTables.
                self:removeSingle(element)
            end
        elseif(type(container) == 'table') then --Case 5: container is a table. We then assume, it's a sequence.
            for _, element in ipairs(container) do
                self:removeSingle(element)
            end
        else --Case 6: invalid input.
            printError("removeAll is only compatible with a Set, SyncedTable, array, force or group")
        end
        return self
    end

    ---Adds all Elements of the given Container to the Set.
    ---Specifying an array or SyncedTable will add all values of that table to the set.
    ---If you specify an array, it must be a sequence. Otherwise, all values beyond the first nil key will not be added.
    ---@param container Set | any[] | SyncedTable | force | group
    ---@return Set self
    function Set:addAll(container)
        if DEBUG_MODE then checkColonNotation("Set:addAll(container)", self) end
        local typeString = wc3Type(container)
        if typeString == 'group' then --Case 1: container is Group
            ForGroup(container, function () self:addSingle(GetEnumUnit()) end)
        elseif typeString == 'force' then --Case 2: container is Force
            ForForce(container, function () self:addSingle(GetEnumPlayer()) end)
        elseif (getmetatable(container) == getmetatable(self)) then --Case 3: container is Set
            for element in container:elements() do
                self:addSingle(element)
            end
        elseif SyncedTable and SyncedTable.isSyncedTable(container) then --Case 4: container is SyncedTable
            for _, element in pairs(container) do --pairs-function is multiplayer synced for SyncedTables.
                self:addSingle(element)
            end
        elseif typeString == 'table' then --Case 5: container is table (and we then assume it's an array)
            for _, element in ipairs(container) do
                self:addSingle(element)
            end
        else --Case 6: invalid input.
            printError("addAll is only compatible with a Set, SyncedTable, array, force or group")
        end
        return self
    end

    ---Adds all keys of a given table as elements to the set. This method is only multiplayer-compatible, if you use a SyncedTable as input OR if you are have overwritten the pairs function to make it multiplayer-synchronous. Otherwise it might lead to desyncs.
    ---@param whichTable SyncedTable Adds all keys of given table to the set
    ---@return Set self
    function Set:addAllKeys(whichTable)
        if DEBUG_MODE then checkColonNotation("Set:addAllKeys(container)", self) end
        if(type(whichTable) == 'table') then
            for key, _ in pairs(whichTable) do --pairs-function is multiplayer synced for SyncedTables.
                self:add(key)
            end
        else
            printError("AddAllKeys only compatible with SyncedTables")
        end
        return self
    end

    --Help data structures for Set iteration that memorize all currently running iterations, their current element and counter variables.
    local recycleStack = {} --State-tables are stored here to prevent garbage collection, at least up to MAX_STACK_SIZE
    local stackSize = 0 --Current number of tables stored in recycleStack
    local MAX_STACK_SIZE = 128 --Max number of tables that can be stored in recycleStack

    --- Iterator function that is used the retreive the next loop element within a Set loop.
    --- This iterator is identical for every Set. Different loops are distinguished by different loopIds and all new iterations receive a unique new loopId.
    --- The iteration loops through orderedKeys[] in ascending order, saving the current position and element externally.
    ---@param state {loopCounter:integer, lastElement:any, loopSet:Set} loopId to identify one particular running iteration.
    ---@return any element
    local function iterator(state)
        local loopSet = state.loopSet
        if state.lastElement == loopSet.orderedKeys[state.loopCounter] then --check, if the last iterated key is still in place. If not, it has been removed in the last part of the iteration.
            state.loopCounter = state.loopCounter + 1 --only increase i, when the last iterated key is still part of the table. Otherwise use the same i again. This allows the removal of (key,value)-pairs inside the pairs()-iteration.
        end
        local currentElement = loopSet.orderedKeys[state.loopCounter]
        state.lastElement = currentElement
        --If the loop is finished and the recycleStack is not full, empty and recycle the state-table.
        --If the recycleStack is full, the state-table will not be recycled and instead garbage collected (no further action required)
        if currentElement == nil and stackSize < MAX_STACK_SIZE then
            state.loopCounter = nil  --state.lastElement is already nil at this point
            state.loopSet = nil
            stackSize = stackSize + 1
            recycleStack[stackSize] = state
        end
        return currentElement
    end

    ---returns an iterator for a standard for loop
    ---usage: for element in set:elements() do ... end
    ---You can both remove and add elements during the loop. Added elements will also be contained in the loop.
    ---@return function iterator
    ---@return integer loopId
    function Set:elements()
        if DEBUG_MODE then checkColonNotation("Set:elements()", self) end
        local state --structure to hold loop information
        if stackSize > 0 then --recycled table available -> pop
            state = recycleStack[stackSize]
            recycleStack[stackSize] = nil
            stackSize = stackSize - 1
        else
            state = {}
        end
        state.loopSet = self
        state.loopCounter = 1 --current position within orderedKeys
        return iterator, state
    end

    ---returns the number of elements in this set.
    ---@return integer
    function Set:size()
        if DEBUG_MODE then checkColonNotation("Set:size()", self) end
        return self.n
    end

    ---returns true, when the set is empty and false otherwise
    ---@return boolean
    function Set:isEmpty()
        if DEBUG_MODE then checkColonNotation("Set:isEmpty()", self) end
        return self:size() == 0
    end

    ---Returns a random element from the Set.
    function Set:random()
        if DEBUG_MODE then checkColonNotation("Set:random()", self) end
        return self.orderedKeys[math.random(self.n)]
    end

    ---removes all Elements from the set
    ---@return Set self
    function Set:clear()
        if DEBUG_MODE then checkColonNotation("Set:clear()", self) end
        self.data = {}
        self.orderedKeys = {}
        self.n = 0
        return self
    end

    ---Returns an array with exactly the elements of the Set. Only do this, when another function input needs an array, because why should you use a Set, when you convert it to an array anyway?
    ---@return any[] array
    function Set:toArray()
        if DEBUG_MODE then checkColonNotation("Set:toArray()", self) end
        local i,result = 1,{}
        for element in self:elements() do
            result[i] = element
            i = i+1
        end
        return result
    end

    ---Returns a comma separated list of all elements of <Set>, engulfed in {}-brackets.
    ---@return string
    function Set:toString()
        if DEBUG_MODE then checkColonNotation("Set:toString()", self) end
        local elementsToString = {}
        for i = 1, self.n do
            elementsToString[i] = tostring(self.orderedKeys[i]) --must be translated to strings, else table.concat wouldn't work.
        end
        return '{' .. table.concat(elementsToString, ', ', 1, self.n) .. '}'
    end

    ---prints all elements of the Set on Screen (space separated)
    function Set:print()
        if DEBUG_MODE then checkColonNotation("Set:print()", self) end
        print(self:toString())
    end

    ---Returns true, if this Set has at least one common element with another Set, i.e. the intersection is not empty.
    ---@param otherSet Set
    ---@return boolean haveCommonElement
    function Set:intersects(otherSet)
        if DEBUG_MODE then checkColonNotation("Set:intersects(otherSet)", self) end
        for element in self:elements() do
            if otherSet.data[element] then
                return true
            end
        end
        return false
    end

    ---Returns a copy of an existing Set.
    ---@return Set copy
    function Set:copy()
        if DEBUG_MODE then checkColonNotation("Set:copy()", self) end
        return Set.create():addAll(self)
    end

    ---Returns a new Set, which is the union of all specified parameters.
    ---You can specify any number of arguments of types Set, SyncedTable, array, force and group.
    ---Arrays are required to form a sequence. Otherwise, values beyond the first nil-key are ignored.
    ---@param ... Set | SyncedTable | any[] | force | group
    ---@return Set union
    function Set.union(...)
        if DEBUG_MODE then checkDotNotation("Set.union(...)", ...) end
        local resultSet = Set.create()
        for i = 1, select('#',...) do
            resultSet:addAll(select(i, ...))
        end
        return resultSet
    end

    ---Returns a new Set, which is the intersection of all specified parameters.
    ---You can specify any number of arguments of types Set, SyncedTable, array, force and group.
    ---Arrays are required to form a sequence. Otherwise, values beyond the first nil-key are ignored.
    ---@param ... Set | SyncedTable | any[] | force | group
    ---@return Set intersection
    function Set.intersection(...)
        if DEBUG_MODE then checkDotNotation("Set.intersection(...)", ...) end
        local n = select('#',...)
        local resultSet = Set.create()
        if n > 0 then resultSet:addAll(...) end --actually only adds the first container (addAll only supports one param)
        for i = 2, n do
            resultSet:retainAll(select(i,...))
        end
        return resultSet
    end

    ---Returns a new Set, which equals setA exluding the elements of setB.
    ---Arrays are required to form a sequence. Otherwise, values beyond the first nil-key are ignored.
    ---@param containerA Set | SyncedTable | any[] | force | group
    ---@param containerB Set | SyncedTable | any[] | force | group
    ---@return Set setDifference
    function Set.except(containerA, containerB)
        if DEBUG_MODE then checkDotNotation("Set.except(A,B)", containerA) end
        return Set.create():addAll(containerA):removeAll(containerB)
    end

    ---Returns the Set of all units from the specified unitgroup.
    ---@param unitgroup group
    ---@return Set
    function Set.fromGroup(unitgroup)
        if DEBUG_MODE then checkDotNotation("Set.fromGroup(unitgroup)", unitgroup) end
        local unitSet = Set.create()
        ForGroup(unitgroup, function () unitSet:addSingle(GetEnumUnit()) end)
        return unitSet
    end

    ---Returns the Set of all players from the specified playergroup.
    ---@param playergroup force
    ---@return Set
    function Set.fromForce(playergroup)
        if DEBUG_MODE then checkDotNotation("Set.fromForce(playergroup)", playergroup) end
        local playerSet = Set.create()
        ForForce(playergroup, function () playerSet:addSingle(GetEnumPlayer()) end)
        return playerSet
    end

    ---Returns a new Set with all elements from the specified table (i.e. all values, not keys). The table must be either a SyncedTable or array.
    ---Arrays are required to form a sequence. Otherwise, values beyond the first nil-key are ignored.
    ---@param whichTable SyncedTable | any[]
    ---@return Set
    function Set.fromTable(whichTable)
        if DEBUG_MODE then checkDotNotation("Set.fromTable(whichTable)", whichTable) end
        return Set.create():addAll(whichTable)
    end

    --------------------------
    -- | SetUtils Library | --
    --------------------------

    --Mimick existing pick natives, but create Sets instead of groups, forces, destructable
    SetUtils = {}

    local autoUnitRemoveSubscriptions = Set.create() --Set of all Sets that are subscribed to automatic unit removal. Only in use, when a custom defend ability was provided.

    local getUnitTypeId, unitAddAbility, unitMakeAbilityPermanent = GetUnitTypeId, UnitAddAbility, UnitMakeAbilityPermanent --localize natives for quicker access

    ---Removes the specified unit from all sets subscribed to auto-removal of invalid unit references.
    ---Called upon any unit leaving the game.
    ---@param unitToRemove unit
    local function removeUnitFromSubscribedSets(unitToRemove)
        for set in autoUnitRemoveSubscriptions:elements() do
            set:removeSingle(unitToRemove)
        end
    end

    local checkDotNotation = function(firstArgumentOfMethod)
        if firstArgumentOfMethod == SetUtils then
            printError("SetUtils method used with :-notation instead of .-notation.")
        end
    end

    --------UnitGroups---------

    local dummyGroup ---@type group this unitgroup will be used within the Wc3 natives.

    ---Executes the specified enumFunc to create a unitgroup and converts the output to a set.
    ---@param enumFunc function
    ---@param destroyCondition? boolexpr pass a boolean expr if you want it to be destroyed after the enumeration.
    ---@param ... any the parameters to pass to enumFunc
    ---@return Set
    local function enumGroupToSet(enumFunc, destroyCondition, ...)
        if DEBUG_MODE then checkDotNotation(...) end
        dummyGroup = dummyGroup or CreateGroup()
        GroupClear(dummyGroup) --do this first to ensure an empty group. Errors in the conditions passed to enumFunc below could otherwise interrupt code execution and leave dummyGroup non-empty.
        enumFunc(dummyGroup, ...)
        local unitSet = Set.fromGroup(dummyGroup)
        if destroyCondition then
            DestroyBoolExpr(destroyCondition)
        end
        return unitSet
    end

    ---Returns Condition(func), if the input a is a function. Returns the input otherwise.
    ---@param func? function | boolexpr
    ---@return boolexpr condition, boolean converted_yn
    local function conditionIfNecessary(func)
        local converted_yn = type(func) == 'function' ---@diagnostic disable-next-line: return-type-mismatch
        return (converted_yn and Condition(func)) or func, converted_yn --real boolexpr have type userdata
    end

    ---Returns the Set of all units in a specified rect that match a specified condition.
    ---Use GetFilterUnit() to refer to the unit being checked by the condition.
    ---@param whichRect rect
    ---@param condition? function | boolexpr
    ---@return Set
    function SetUtils.getUnitsInRectMatching(whichRect, condition)
        local convertedCondition, converted_yn = conditionIfNecessary(condition)
        return enumGroupToSet(GroupEnumUnitsInRect, converted_yn and convertedCondition or nil, whichRect, convertedCondition)
    end

    ---Returns the Set of all units in a specified rect.
    ---@param whichRect rect
    ---@return Set
    function SetUtils.getUnitsInRect(whichRect)
        return SetUtils.getUnitsInRectMatching(whichRect)
    end

    ---Returns the Set of all units within a specified radius of the specified coordinates matching the specified condition.
    ---Use GetFilterUnit() to refer to the unit being checked by the condition.
    ---@param x real
    ---@param y real
    ---@param radius real
    ---@param condition? function | boolexpr
    ---@return Set
    function SetUtils.getUnitsInRangeMatching(x, y, radius, condition)
        local convertedCondition, converted_yn = conditionIfNecessary(condition)
        return enumGroupToSet(GroupEnumUnitsInRange, converted_yn and convertedCondition or nil, x, y, radius, convertedCondition)
    end

    ---Returns the Set of all units within a specified radius of the specified coordinates.
    ---@param x real
    ---@param y real
    ---@param radius real
    ---@return Set
    function SetUtils.getUnitsInRange(x, y, radius)
        return SetUtils.getUnitsInRangeMatching(x, y, radius)
    end

    ---Returns the Set of all units owned by the specified player and matching the specified condition.
    ---Use GetFilterUnit() to refer to the unit being checked by the condition.
    ---@param whichPlayer player
    ---@param condition? function | boolexpr
    ---@return Set
    function SetUtils.getUnitsOfPlayerMatching(whichPlayer, condition)
        local convertedCondition, converted_yn = conditionIfNecessary(condition)
        return enumGroupToSet(GroupEnumUnitsOfPlayer, converted_yn and convertedCondition or nil, whichPlayer, convertedCondition)
    end

    ---Returns the Set of all units owned by the specified player.
    ---@param whichPlayer player
    ---@return Set
    function SetUtils.getUnitsOfPlayer(whichPlayer)
        return SetUtils.getUnitsOfPlayerMatching(whichPlayer)
    end

    --Permanently stores conditions for retreiving typeIds and the worldBounds rect. Both are created on demand. Prevents continous re-creation of conditionfuncs from anonymous functions.
    --TypeIds are static and limited in number, so there's not much chance of creating unused objects with this system.
    local storage = setmetatable({}, {})
    getmetatable(storage).__index = function(t,k)
        if k == 'worldBounds' then
            t[k] = GetWorldBounds()
        elseif k == 'returnTrue' then
            t[k] = Condition(function() return true end)
        else
            t[k] = Condition(function() return GetUnitTypeId(GetFilterUnit()) == k end)
        end
        return rawget(t,k)
    end

    ---Returns the Set of all units having the specified unitType and matching the specified condition.
    ---Use GetFilterUnit() to refer to the unit being checked by the condition.
    ---@param typeId integer
    ---@param condition? function | boolexpr
    ---@return Set
    function SetUtils.getUnitsOfTypeIdMatching(typeId, condition)
        condition = condition or storage['returnTrue']
        local convertedCondition, converted_yn = conditionIfNecessary(condition)
        local logicalAnd = And(storage[typeId], convertedCondition)
        local returnSet = enumGroupToSet(GroupEnumUnitsInRect, logicalAnd, storage['worldBounds'], logicalAnd)
        if converted_yn then DestroyBoolExpr(convertedCondition) end
        return returnSet
    end

    ---Returns the Set of all units owned by the specified player and having the specified unitType.
    ---Use GetFilterUnit() to refer to the unit being checked by the condition.
    ---@param whichPlayer player
    ---@param typeId integer
    ---@return Set
    function SetUtils.getUnitsOfPlayerAndTypeId(whichPlayer, typeId)
        return enumGroupToSet(GroupEnumUnitsOfPlayer, nil, whichPlayer, storage[typeId])
    end

    ---Returns the Set of all units having the specified unitType.
    ---@param typeId integer
    ---@return Set
    function SetUtils.getUnitsOfTypeId(typeId)
        return SetUtils.getUnitsOfTypeIdMatching(typeId)
    end

    ---Returns the Set of all units being currently selected by a player and matching the specified condition.
    ---@param whichPlayer player
    ---@param condition? function | boolexpr
    ---@return Set
    function SetUtils.getUnitsSelected(whichPlayer, condition)
        SyncSelections() --important to prevent desyncs, as selections are saved locally.
        local convertedCondition, converted_yn = conditionIfNecessary(condition)
        return enumGroupToSet(GroupEnumUnitsSelected, converted_yn and convertedCondition or nil, whichPlayer, convertedCondition)
    end

    SetUtils.getUnitsSelectedMatching = SetUtils.getUnitsSelected

    --------PlayerGroups---------

    ---Returns the Set of all players.
    ---Contains players that were present during game start, including computer players.
    ---@return Set
    function SetUtils.getPlayersAll()
        return Set.fromForce(GetPlayersAll()) --global wc3 var, doesn't produce memory leaks
    end

    ---Returns the Set of all active players (including computer players) matching the specified condition.
    ---Only contains players that were present during game start, including computer players.
    ---Use GetFilterPlayer() to refer to the player being checked in the condition.
    ---@param condition function | boolexpr
    ---@return Set
    function SetUtils.getPlayersMatching(condition)
        local playergroup = CreateForce()
        local convertedCondition, converted_yn = conditionIfNecessary(condition)
        ForceEnumPlayers(playergroup, convertedCondition)
        local playerSet = Set.fromForce(playergroup)
        DestroyForce(playergroup)
        if converted_yn then
            DestroyBoolExpr(convertedCondition)
        end
        return playerSet
    end

    --------DestructableGroups---------

    ---Returns the Set of all destructables in the specified rect matching the specified condition.
    ---Use GetFilterDestructable() to refer to the destructable being checked in the condition.
    ---@param whichRect rect
    ---@param condition? function | boolexpr
    ---@return Set
    function SetUtils.getDestructablesInRectMatching(whichRect, condition)
        local destructableSet = Set.create()
        local convertedCondition, converted_yn = conditionIfNecessary(condition)
        EnumDestructablesInRect(whichRect, convertedCondition, function() destructableSet:add(GetEnumDestructable()) end)
        if converted_yn then
            DestroyBoolExpr(convertedCondition)
        end
        return destructableSet
    end

    ---Returns the Set of all destructables in the specified rect.
    ---@param whichRect rect
    ---@return Set
    function SetUtils.getDestructablesInRect(whichRect)
        return SetUtils.getDestructablesInRectMatching(whichRect)
    end

    --------ItemGroups---------

    ---Returns the Set of all items in the specified rect matching the specified condition.
    ---Use GetFilterItem() to refer to the item being checked in the condition.
    ---@param whichRect rect
    ---@param condition function | boolexpr
    ---@return Set
    function SetUtils.getItemsInRectMatching(whichRect, condition)
        local itemSet = Set.create()
        local convertedCondition, converted_yn = conditionIfNecessary(condition)
        EnumItemsInRect(whichRect, convertedCondition, function() itemSet:add(GetEnumItem()) end)
        if converted_yn then
            DestroyBoolExpr(convertedCondition)
        end
        return itemSet
    end

    ---Returns the Set of all items in the specified rect.
    ---@param whichRect rect
    ---@return Set
    function SetUtils.getItemsInRect(whichRect)
       return SetUtils.getItemsInRectMatching(whichRect)
    end

    --------Utility---------

    ---Removes all invalid unit references from the specified Set, i.e. units that have already been removed from the game.
    ---If your Set contains non-unit elements, you must set the second parameter to true to avoid crashes.
    ---@param whichSet Set the Set that might contain references to removed units
    ---@param checkIfUnit? boolean default: false. Set to true to avoid crashes, if the Set contains non-unit elements.
    function SetUtils.clearInvalidUnitRefs(whichSet, checkIfUnit)
        for element in whichSet:elements() do
            if not checkIfUnit or wc3Type(element) == 'unit' then
                if getUnitTypeId(element) == 0 then
                    whichSet:removeSingle(element)
                end
            end
        end
    end

    ---Subscribes the specified set to automatic removal of invalid unit references, i.e. for the rest of the game, units that are removed from the game will also be removed from the specified set.
    ---Set the second parameter to false (default true) to unsubscribe the specified Set from the automatic unit cleaning.
    ---As long as a Set is subscribed, it will not be garbage collected.
    ---This function requires CUSTOM_DEFEND_ABICODE to be set.
    ---@param whichSet Set
    ---@param subscribe_yn? boolean default: true. true to subscribe. false to unsubscribe.
    function SetUtils.subscribeSetToAutoUnitRemoval(whichSet, subscribe_yn)
        if CUSTOM_DEFEND_ABICODE then
            if subscribe_yn or subscribe_yn == nil then
                SetUtils.clearInvalidUnitRefs(whichSet, true)
                autoUnitRemoveSubscriptions:addSingle(whichSet)
            else
                autoUnitRemoveSubscriptions:removeSingle(whichSet)
            end
        else
            printError("You can't use SetUtils.subscribeToAutoUnitRemoval, until you have provided a custom defend ability.")
        end
    end

    local hasUnitBeenRemovedCondition ---@type conditionfunc initialized in SetUtils.createTriggers() below.

    ---Adds the event "unit is removed from the game" to the specified trigger.
    ---This event is not compatible with other events, so don't use it on triggers with multiple events (other events will simply be invalidated).
    ---Requires CUSTOM_DEFEND_ABICODE to be set.
    ---@param whichTrigger trigger
    function SetUtils.triggerRegisterAnyUnitRemoveEvent(whichTrigger)
        if CUSTOM_DEFEND_ABICODE then
            TriggerRegisterAnyUnitEventBJ(whichTrigger, EVENT_PLAYER_UNIT_ISSUED_ORDER)
            TriggerAddCondition(whichTrigger, hasUnitBeenRemovedCondition)
        else
            printError("You can't use SetUtils.triggerRegisterAnyUnitRemoveEvent, until you have provided a custom defend ability.")
        end
    end

    --------Triggers for unit auto removal---------

    function SetUtils.createTriggers()
        --Init unit reference cleanup methods
        --Add the custom defend ability to all units entering the map, if it was provided.
        if CUSTOM_DEFEND_ABICODE then
            for i = 0, GetBJMaxPlayers() - 1 do
                SetPlayerAbilityAvailable(Player(i), CUSTOM_DEFEND_ABICODE, false)
            end
            local enterTrigger = CreateTrigger()
            TriggerRegisterEnterRectSimple( enterTrigger, bj_mapInitialPlayableArea )
            local function prepareNewUnit()
                local u = GetTriggerUnit()
                unitAddAbility(u, CUSTOM_DEFEND_ABICODE)
                unitMakeAbilityPermanent(u, true, CUSTOM_DEFEND_ABICODE)
            end
            TriggerAddAction(enterTrigger, prepareNewUnit)

            --Initialize upvalue. We don't set hasUnitBeenRemovedCondition earlier to prevent using Wc3 natives in the Lua root.
            hasUnitBeenRemovedCondition = Condition(function() return (GetIssuedOrderId() == 852056) and GetUnitAbilityLevel(GetTriggerUnit(), CUSTOM_DEFEND_ABICODE) == 0 end) --undefend order. This one is issued upon units leaving the game, but also under other circumstances. Ability-Level == 0 proves the removed from the game event.

            local removeTrigger = CreateTrigger()
            SetUtils.triggerRegisterAnyUnitRemoveEvent(removeTrigger)
            TriggerAddAction(removeTrigger, function() removeUnitFromSubscribedSets(GetTriggerUnit()) end)
        end
    end

    ---@diagnostic disable-next-line: undefined-global
    if OnInit and OnInit.trig then OnInit.trig(SetUtils.createTriggers) end --use TotalInit library, if available.
end
if Debug and Debug.endFile then Debug.endFile() end