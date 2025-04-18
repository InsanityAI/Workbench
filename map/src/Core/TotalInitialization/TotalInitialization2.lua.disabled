if Debug then Debug.beginFile "TotalInitialization" end
do
    local function initErrorHandler(errorMsg)
        print("|cFFFF0000OnInit error: " .. errorMsg .. "|r")
    end

    ---@class Require: { [string]: Requirement }
    ---@overload async fun(requirement: string, source?: table): string
    Require = {}

    ---@class Module
    ---@field name string
    ---@field requested boolean
    ---@field generated boolean
    ---@field initialized boolean
    ---@field initializer Initializer.Callback?
    ---@field values unknown[]
    ---@field children table<string, Module>
    ---@field dependants thread[]
    local Module = {}
    Module.__index = Module
    do -- module shenanigans
        local moduleRegistry = {} ---@type table<string, Module>

        ---@param name string
        ---@return string[]|{n:integer}
        local function splitModuleName(name)
            local result = {}
            local count = 0
            for str in string.gmatch(name, '([^.]+)') do
                table.insert(result, str)
                count = count + 1
            end
            result.n = count
            return result
        end

        ---@param name string
        ---@param initializer Initializer.Callback?
        ---@param ... unknown? initialized values
        ---@return Module
        local function defineModule(name, initializer, ...)
            local count = select("#", ...)
            local values = nil
            if count > 0 then
                values = table.pack(...)
            end
            return setmetatable({
                name = name,
                requested = false,
                generated = not initializer and count == 0,
                initialized = count > 0,
                initializer = initializer,
                values = values,
                children = {},
                dependants = {}
            }, Module)
        end

        ---@param src table<string, Module>
        ---@param name string
        ---@param currentName string
        ---@param initializer Initializer.Callback?
        ---@param ... unknown?
        local function getOrDefineModule(src, name, currentName, initializer, ...)
            local thisModule = src[currentName]
            if thisModule then
                local valueCount = select("#", ...)
                if initializer or valueCount > 0 then
                    if not thisModule.generated and (thisModule.initializer or thisModule.values) then
                        initErrorHandler("Duplicate module [" .. name .. "] declaration!")
                    end
                    thisModule.generated = false
                    thisModule.initialized = valueCount > 0
                    thisModule.initializer = initializer
                    thisModule.values = table.pack(...)
                end
                return thisModule
            else
                local thisModule = defineModule(name, initializer, ...)
                src[currentName] = thisModule
                return thisModule
            end
        end

        ---@param name string
        ---@return table<string, Module>, string lastName
        local function getLastParentModuleChildren(name)
            local nameParts = splitModuleName(name)
            local currentModuleChildren = moduleRegistry
            local cumulativeName = nameParts[1]
            if nameParts.n > 1 then
                local thisModule = getOrDefineModule(currentModuleChildren, cumulativeName, nameParts[1])
                currentModuleChildren = thisModule.children
                for i = 2, nameParts.n - 1 do
                    cumulativeName = cumulativeName .. '.' .. nameParts[i]
                    local thisModule = getOrDefineModule(currentModuleChildren, cumulativeName, nameParts[i])
                    currentModuleChildren = thisModule.children
                end
                cumulativeName = cumulativeName .. '.' .. nameParts[nameParts.n]
            end
            return currentModuleChildren, nameParts[nameParts.n]
        end

        ---@param name string
        ---@param initializer Initializer.Callback?
        ---@param ... unknown? initialized values
        ---@return Module
        function Module.create(name, initializer, ...)
            assert(type(name) == 'string', 'Module name must be string! Provided: ' .. tostring(name))
            local parentModuleChildren, lastKey = getLastParentModuleChildren(name)
            return getOrDefineModule(parentModuleChildren, name, lastKey, initializer, ...)
        end

        ---@param name string
        ---@return Module
        function Module.fetch(name)
            assert(type(name) == 'string', 'Module name must be string! Provided: ' .. tostring(name))
            local parentModuleChildren, lastKey = getLastParentModuleChildren(name)
            local thisModule = getOrDefineModule(parentModuleChildren, name, lastKey)
            thisModule.requested = true
            return thisModule
        end

        ---@return ...
        function Module:getValues()
            if not self.initialized then
                self.values = table.pack(self.initializer(Require))
                self.initialized = true
            end
            return table.unpack(self.values)
        end

        ---@param optional boolean?
        ---@param requirement string
        ---@param explicitSource any
        ---@return ...
        local function processRequirement(optional, requirement, explicitSource)
            local requiredModule = Module.fetch(requirement)
            return requiredModule:getValues()
        end

        function Require.strict(name, explicitSource)
            return processRequirement(false, name, explicitSource)
        end

        setmetatable(Require --[[@as table]], {
            __call = processRequirement,
            __index = function ()
                return processRequirement
            end
        })
    end

    ---@alias Initializer.Callback fun(require?: Requirement | {[string]: Requirement}):...?
    ---@alias Requirement async fun(reqName: string, source?: table): unknown

    -- formerly known as initFuncQueue
    local moduleLoadingQueue = { ---@type table<string, {name: string, init: Initializer.Callback}[]?>
        -- immediately run root and module upon arrival, therefore their queues are nil
        root = nil,
        config = {},
        main = {},
        global = {},
        trig = {},
        map = {},
        final = {},
        module = nil
    }

    local initializationPhases = {}

    -- formerly known as callUserFunc/addUserFunc
    ---@overload fun(initPhaseName: string, moduleInitializer: Initializer.Callback, _, debugLineNum: integer?, incDebugLevel: boolean?)
    ---@overload fun(initPhaseName: string, moduleName: string, moduleInitializer: Initializer.Callback, debugLineNum: integer?, incDebugLevel: boolean?)
    local function queueModuleInitFunc(initPhaseName, moduleName, moduleInitializer, debugLineNum, incDebugLevel)
        if not moduleInitializer then
            moduleInitializer = moduleName
            moduleName = nil
        else
            assert(type(moduleName) == 'string', 'Module name must be string! Provided: ' .. tostring(moduleName))
            if debugLineNum and Debug then
                Debug.beginFile(moduleName, incDebugLevel and 3 or 2)
                Debug.data.sourceMap[#Debug.data.sourceMap].lastLine = debugLineNum
            end
        end
        assert(type(moduleInitializer) == 'function', 'Expected module function. Provided: ' .. tostring(moduleInitializer))
        if moduleLoadingQueue[initPhaseName] then -- if a queue exists put the module in it
            table.insert(moduleLoadingQueue[initPhaseName], { name = moduleName, init = moduleInitializer })
        else                                      -- otherwise call it immediately, since nil means that init phase has ended and there's no reason to queue
            initializationPhases[initPhaseName](moduleName, moduleInitializer)
        end
    end

    do -- initializer API
        ---@param initPhaseName string
        local function createInit(initPhaseName)
            ---@async
            ---@param moduleName string                --Assign your callback a unique name, allowing other OnInit callbacks can use it as a requirement.
            ---@param moduleInitializer Initializer.Callback --Define a function to be called at the chosen point in the initialization process. It can optionally take the `Require` object as a parameter. Its optional return value(s) are passed to a requiring library via the `Require` object (defaults to `true`).
            ---@param debugLineNum? integer             --If the Debug library is present, you can call Debug.getLine() for this parameter (which should coincide with the last line of your script file). This will neatly tie-in with OnInit's built-in Debug library functionality to define a starting line and an ending line for your module.
            ---@overload async fun(userInitFunc: Initializer.Callback)
            return function(moduleName, moduleInitializer, debugLineNum)
                xpcall(queueModuleInitFunc, initErrorHandler, initPhaseName, moduleName, moduleInitializer, debugLineNum)
            end
        end

        ---@class TotalInit
        TotalInit = setmetatable({
            root = createInit 'root',     -- Runs immediately during the Lua root, but is yieldable (allowing requirements) and pcalled.
            config = createInit 'config', -- Runs when `config` is called. Credit to @Luashine: https://www.hiveworkshop.com/threads/inject-main-config-from-we-trigger-code-like-jasshelper.338201/
            main = createInit 'main',     -- Runs when `main` is called. Idea from @Tasyen: https://www.hiveworkshop.com/threads/global-initialization.317099/post-3374063
            global = createInit 'global', -- Called after InitGlobals, and is the standard point to initialize.
            trig = createInit 'trig',     -- Called after InitCustomTriggers, and is useful for removing hooks that should only apply to GUI events.
            map = createInit 'map',       -- Called last in the script's loading screen sequence. Runs after the GUI "Map Initialization" events have run.
            final = createInit 'final',   -- Called immediately after the loading screen has disappeared, and the game has started.
            module = createInit 'module'  -- Will only call the OnInit function if the module is required by another resource, rather than being called at a pre-specified point in the loading process. It works similarly to Go, in that including modules in your map that are not actually being required will throw an error message.
        }, {
            ---@overload fun(self: table, moduleName: string, moduleInitializer: Initializer.Callback, debugLineNum: integer)
            ---@overload fun(self: table, moduleInitializer: Initializer.Callback, debugLineNum: integer)
            __call = function(self, moduleName, moduleInitializer, debugLineNum)
                if moduleInitializer or type(moduleName) == "function" then
                    xpcall(queueModuleInitFunc, initErrorHandler, 'global', moduleName, moduleInitializer, debugLineNum, true)
                else
                    xpcall(Module.create, initErrorHandler, moduleName, nil, true) --API handler for OnInit "Custom initializer"
                end
            end
        })
    end

    ---@param moduleName string?
    ---@param moduleInitializer Initializer.Callback
    local function moduleInit(moduleName, moduleInitializer)
        coroutine.wrap(moduleInitializer)(Require) -- ??
        if moduleName then
            local source = moduleDefinitions
            local nameParts = splitModuleName(moduleName)
            pendingModuleInits
        end
    end

    --- initializes all queued up modules for that particular init phase
    local function baseInit(phaseName)
        for _, module in ipairs(moduleLoadingQueue[phaseName]) do
            moduleInit(module.name, module.init)
        end
        moduleLoadingQueue[phaseName] = nil
        initializationPhases[phaseName] = moduleInit
    end

    initializationPhases.root   = moduleInit
    initializationPhases.config = function() baseInit('config') end
    initializationPhases.main   = function() baseInit('main') end
    initializationPhases.global = function() baseInit('global') end
    initializationPhases.trig   = function() baseInit('trig') end
    initializationPhases.map    = function() baseInit('map') end
    initializationPhases.final  = function() baseInit('final') end
    initializationPhases.module = moduleInit

    do -- Initializer phases setup
        -- Hooks to a global function where it first executes the original and then calls the hookAction. But expects the original function to be provided
        ---@param hookName string
        ---@param originalAction fun()?
        ---@param hookAction fun()
        local function rawPostHook(hookName, originalAction, hookAction)
            if not originalAction then
                print("Unknown function under name [" .. hookName .. "]")
                return
            end
            rawset(_G, hookName, function()
                originalAction()
                hookAction()
            end)
        end

        ---@param hookName string
        ---@param hookAction fun()
        local function postHook(hookName, hookAction) -- formerly known as 'hook'
            rawPostHook(hookName, rawget(_G, hookName), hookAction)
        end

        local gmt = getmetatable(_G) or getmetatable(setmetatable(_G, {}))
        local rawIndex = gmt.__newindex or rawset
        ---@param self table will be _G
        ---@param key string technically doesn't have to be a string, but for these purposes it always will be
        ---@param value unknown can be a function, a primitive or a table
        gmt.__newindex = function(self, key, value)
            if key ~= 'main' and key ~= 'config' then
                rawIndex(self, key, value) -- these are not the keys we're looking for
            elseif key == 'config' then
                rawPostHook('config', value --[[@as fun()]], initializationPhases.initConfig)
            else                                -- main
                initializationPhases.initRoot() -- root runs only when main is defined
                rawPostHook('main', value --[[@as fun()]], initializationPhases.initMain)
                postHook('main', function()
                    -- clean up _G metatable after main initialization phase
                    -- do note that any _G metatable modifications happening during root (after TI declaration), config and main will be reverted
                    -- TODO: perhaps find a way to remedy this.
                    gmt.__newindex = rawIndex
                end)
            end
        end

        postHook('InitGlobals', function()
            initializationPhases.initGlobal()
            postHook('InitCustomTriggers', function() -- InitCustomTriggers and RunInitializationTriggers are declared after the users' code,
                initializationPhases.initTrigger()    -- hence users need to wait until they have been declared.
                postHook('RunInitializationTriggers', initializationPhases.initMap)
            end)
        end)
        postHook('MarkGameStarted', initializationPhases.initFinal)
    end
end
if Debug then Debug.endFile() end
