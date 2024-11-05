if Debug then Debug.beginFile "FrameDoctor" end
do
    --[[
    =============================================================================================================================================================
                                                                       Frame Doctor
                                                                        by Antares

                           Automatically repair all broken frames and return them to their last known state after loading a saved game.

								Requires:
								TotalInitialization			    https://www.hiveworkshop.com/threads/total-initialization.317099/
                                Hook 						    https://www.hiveworkshop.com/threads/hook.339153/
                                HandleType                      https://www.hiveworkshop.com/threads/get-handle-type.354436/

                                                Thank you to Tasyen for advice and repeated help with testing.

    =============================================================================================================================================================

    IsFrame(var)                        Returns whether the specified variable is a framehandle or FrameData table.
    GetFrame(var)                       Returns the variable if it is a framehandle or the framehandle stored to a FrameData table.

    =============================================================================================================================================================
    ]]

    --Disable for debugging. Use this if you want to keep the IsFrame and GetFrame functions and overwrite BlzDestroyFrame. Otherwise disable in World Editor.
    local DISABLE                       = false

    --===========================================================================================================================================================

    local SETTER_FUNCTIONS
    local GETTER_FUNCTIONS
    local FRAMEPOINTS
    local ORIGIN_FRAME_NAMES

    local copiedData
    local gameWasSaved = false
    local tocFiles = {}
    local hideOriginFrames = false

    local pack = table.pack
    local unpack = table.unpack

    local dataOfFrame = {}              ---@type FrameData[]
    local first = {}                    ---@type FrameData
    local last = first                  ---@type FrameData

    local SetPointNative
    local SetAbsPointNative
    local SetTooltipNative
    local AddTextNative
    local RegisterFrameEventNative
    local GetOriginFrameNative
    local GetChildNative
    local GetParentNative
    local GetFrameByNameNative
    local ClearAllPointsNative
    local SetVisibleNative

    ---@class FrameData
    local FrameData = {
        framehandle = nil,              ---@type framehandle
        constructor = nil,              ---@type function
        constructorArgs = nil,          ---@type table
        setters = nil,                  ---@type table<function,boolean>
        setterArgs = nil,               ---@type table[]
        positioners = nil,              ---@type table<framepointtype,function>
        x = nil,                        ---@type number[]
        y = nil,                        ---@type number[]
        anchor = nil,                   ---@type FrameData[]
        anchorFramePoint = nil,         ---@type framepointtype[]
        clearAllPoints = nil,           ---@type boolean
        path = nil,                     ---@type string
        addText = nil,                  ---@type string[]
        tooltip = nil,                  ---@type FrameData
        triggers = nil,                 ---@type trigger[]
        triggerEventTypes = nil,        ---@type frameeventtype[]
        parent = nil,                   ---@type FrameData
        parentIndex = nil,              ---@type integer
        child = nil,                    ---@type FrameData
        next = nil,                     ---@type FrameData
        previous = nil,                 ---@type FrameData
    }

    ---@param var FrameData | framehandle
    ---@return framehandle, FrameData
    local function GetFrameAndData(var)
        if HandleType[var] == "framehandle" then
            local data = dataOfFrame[var]
            if data then
                return data.framehandle, data
            else
                return var --[[@as framehandle]], dataOfFrame[var]
            end
        else
            return var.framehandle, var --[[@as FrameData]]
        end
    end

    ---Frame was first referenced with BlzGetFrameByName or BlzGetOriginFrame.
    ---@param name string
    ---@return framehandle
    local function GetFrameFromString(name)
        local position = name:find("---")
        local index = name:sub(position + 3, name:len())
        string = name:sub(1, position - 1)

        if _G[string] and ORIGIN_FRAME_NAMES[_G[string]] then
            return GetOriginFrameNative(_G[string], tonumber(index))
        else
            return GetFrameByNameNative(string, tonumber(index))
        end
    end

    local function GetFrameFromParent(data)
        return GetChildNative(data.parent.framehandle, data.parentIndex)
    end

    ---Frame was first referenced with BlzFrameGetParent.
    ---@param data FrameData
    ---@return framehandle
    local function GetFrameFromChild(data)
        return GetParentNative(data.child.framehandle)
    end

    ---@param frame framehandle
    ---@param parent? FrameData
    ---@param index? integer
    ---@param path? string
    ---@param constructor? string
    ---@param constructorArgs? table
    ---@param child? FrameData
    local function RegisterFrame(frame, parent, index, path, constructor, constructorArgs, child)
        local data
        if copiedData then
            data = copiedData
            data.framehandle = frame
        else
            data = {
                framehandle = frame,
                constructor = _G[constructor],
                parent = parent,
                parentIndex = index,
                child = child,
                path = path,
                constructorArgs = constructorArgs,
                setters = {},
                setterArgs = {},
                positioners = {},
                x = {},
                y = {},
                anchor = {},
                anchorFramePoint = {},
            }
            last.next = data
            data.previous = last
            last = data
        end
        dataOfFrame[frame] = data
        return data
    end

    ---@param data FrameData
    local function CopyFrame(data)
        if data.constructor then
            copiedData = data
            data.constructor(unpack(data.constructorArgs))
            copiedData = nil
        elseif data.path then
            data.framehandle = GetFrameFromString(data.path)
        elseif data.parent then
            data.framehandle = GetFrameFromParent(data)
        elseif data.child then
            data.framehandle = GetFrameFromChild(data)
        end

        dataOfFrame[data.framehandle] = data
    end

    ---@param data FrameData
    local function ModifyFrame(data)
        if data.clearAllPoints then
            ClearAllPointsNative(data.framehandle)
        end

        for framePoint, func in pairs(data.positioners) do
            if func == SetPointNative then
                SetPointNative(data.framehandle, framePoint, data.anchor[framePoint].framehandle, data.anchorFramePoint[framePoint], data.x[framePoint], data.y[framePoint])
            else
                SetAbsPointNative(data.framehandle, framePoint, data.x[framePoint], data.y[framePoint])
            end
        end

        for setterFunc, __ in pairs(data.setters) do
            setterFunc(data.framehandle, unpack(data.setterArgs[setterFunc]))
        end

        if data.addText then
            for __, text in ipairs(data.addText) do
                AddTextNative(data.framehandle, text)
            end
        end

        if data.triggers then
            for index, trigger in ipairs(data.triggers) do
                RegisterFrameEventNative(trigger, data.framehandle, data.triggerEventTypes[index])
            end
        end

        if data.tooltip then
            SetTooltipNative(data.framehandle, data.tooltip.framehandle)
        end
    end

    local function RecreateFrames()
        local data = first.next
        while data do
            CopyFrame(data)
            data = data.next
        end

        data = first.next
        while data do
            ModifyFrame(data)
            data = data.next
        end
    end

    local function OnLoad()
        gameWasSaved = true
        if hideOriginFrames then
            BlzHideOriginFrames(true)
        end
        for __, path in ipairs(tocFiles) do
            BlzLoadTOCFile(path)
        end
        RecreateFrames()

        DestroyTimer(GetExpiredTimer())
    end

    OnInit.main("FrameDoctor", function()
        if DISABLE then
            Hook.add("BlzDestroyFrame", function(self, frame)
                BlzFrameSetVisible(frame, false)
            end)
            return
        end

        FrameDoctor = true

        SetPointNative              = BlzFrameSetPoint
        SetAbsPointNative           = BlzFrameSetAbsPoint
        SetTooltipNative            = BlzFrameSetTooltip
        AddTextNative               = BlzFrameAddText
        RegisterFrameEventNative    = BlzTriggerRegisterFrameEvent
        GetOriginFrameNative        = BlzGetOriginFrame
        GetChildNative              = BlzFrameGetChild
        GetParentNative             = BlzFrameGetParent
        GetFrameByNameNative        = BlzGetFrameByName
        ClearAllPointsNative        = BlzFrameClearAllPoints
        SetVisibleNative            = BlzFrameSetVisible

        SETTER_FUNCTIONS = {
            BlzDestroyFrame = true,
            BlzFrameSetVisible = true,
            BlzFrameSetText = true,
            BlzFrameSetTextSizeLimit = true,
            BlzFrameSetTextColor = true,
            BlzFrameSetFocus = true,
            BlzFrameSetModel = true,
            BlzFrameSetEnable = true,
            BlzFrameSetAlpha = true,
            BlzFrameSetSpriteAnimate = true,
            BlzFrameSetTexture = true,
            BlzFrameSetScale = true,
            BlzFrameCageMouse = true,
            BlzFrameSetValue = true,
            BlzFrameSetMinMaxValue = true,
            BlzFrameSetStepSize = true,
            BlzFrameSetSize = true,
            BlzFrameSetVertexColor = true,
            BlzFrameSetLevel = true,
            BlzFrameSetParent = true,
            BlzFrameSetFont = true,
            BlzFrameSetTextAlignment = true,
        }

        GETTER_FUNCTIONS = {
            BlzFrameGetText = true,
            BlzFrameGetName = true,
            BlzFrameGetTextSizeLimit = true,
            BlzFrameGetAlpha = true,
            BlzFrameGetEnable = true,
            BlzFrameGetValue = true,
            BlzFrameGetHeight = true,
            BlzFrameGetWidth = true,
            BlzFrameIsVisible = true,
        }

        --Reforged only.
        if BlzFrameGetChildrenCount then
            GETTER_FUNCTIONS.BlzFrameGetChildrenCount = true
        end

        FRAMEPOINTS = {
            [FRAMEPOINT_BOTTOM] = true,
            [FRAMEPOINT_BOTTOMLEFT] = true,
            [FRAMEPOINT_BOTTOMRIGHT] = true,
            [FRAMEPOINT_CENTER] = true,
            [FRAMEPOINT_LEFT] = true,
            [FRAMEPOINT_RIGHT] = true,
            [FRAMEPOINT_TOP] = true,
            [FRAMEPOINT_TOPLEFT] = true,
            [FRAMEPOINT_TOPRIGHT] = true
        }

        ORIGIN_FRAME_NAMES = {
            [ORIGIN_FRAME_GAME_UI]                    = "ORIGIN_FRAME_GAME_UI",
            [ORIGIN_FRAME_COMMAND_BUTTON]             = "ORIGIN_FRAME_COMMAND_BUTTON",
            [ORIGIN_FRAME_HERO_BAR]                   = "ORIGIN_FRAME_HERO_BAR",
            [ORIGIN_FRAME_HERO_BUTTON]                = "ORIGIN_FRAME_HERO_BUTTON",
            [ORIGIN_FRAME_HERO_HP_BAR]                = "ORIGIN_FRAME_HERO_HP_BAR",
            [ORIGIN_FRAME_HERO_MANA_BAR]              = "ORIGIN_FRAME_HERO_MANA_BAR",
            [ORIGIN_FRAME_HERO_BUTTON_INDICATOR]      = "ORIGIN_FRAME_HERO_BUTTON_INDICATOR",
            [ORIGIN_FRAME_ITEM_BUTTON]                = "ORIGIN_FRAME_ITEM_BUTTON",
            [ORIGIN_FRAME_MINIMAP]                    = "ORIGIN_FRAME_MINIMAP",
            [ORIGIN_FRAME_MINIMAP_BUTTON]             = "ORIGIN_FRAME_MINIMAP_BUTTON",
            [ORIGIN_FRAME_SYSTEM_BUTTON]              = "ORIGIN_FRAME_SYSTEM_BUTTON",
            [ORIGIN_FRAME_TOOLTIP]                    = "ORIGIN_FRAME_TOOLTIP",
            [ORIGIN_FRAME_UBERTOOLTIP]                = "ORIGIN_FRAME_UBERTOOLTIP",
            [ORIGIN_FRAME_CHAT_MSG]                   = "ORIGIN_FRAME_CHAT_MSG",
            [ORIGIN_FRAME_UNIT_MSG]                   = "ORIGIN_FRAME_UNIT_MSG",
            [ORIGIN_FRAME_TOP_MSG]                    = "ORIGIN_FRAME_TOP_MSG",
            [ORIGIN_FRAME_PORTRAIT]                   = "ORIGIN_FRAME_PORTRAIT",
            [ORIGIN_FRAME_WORLD_FRAME]                = "ORIGIN_FRAME_WORLD_FRAME",
        }

        --Reforged only.
        if ORIGIN_FRAME_SIMPLE_UI_PARENT then
            ORIGIN_FRAME_NAMES[ORIGIN_FRAME_SIMPLE_UI_PARENT]           = "ORIGIN_FRAME_SIMPLE_UI_PARENT"
            ORIGIN_FRAME_NAMES[ORIGIN_FRAME_PORTRAIT_HP_TEXT]           = "ORIGIN_FRAME_PORTRAIT_HP_TEXT"
            ORIGIN_FRAME_NAMES[ORIGIN_FRAME_PORTRAIT_MANA_TEXT]         = "ORIGIN_FRAME_PORTRAIT_MANA_TEXT"
            ORIGIN_FRAME_NAMES[ORIGIN_FRAME_UNIT_PANEL_BUFF_BAR]        = "ORIGIN_FRAME_UNIT_PANEL_BUFF_BAR"
            ORIGIN_FRAME_NAMES[ORIGIN_FRAME_UNIT_PANEL_BUFF_BAR_LABEL]  = "ORIGIN_FRAME_UNIT_PANEL_BUFF_BAR_LABEL"
        end

        local trig = CreateTrigger()
        TriggerRegisterGameEvent(trig, EVENT_GAME_LOADED)
        TriggerAddAction(trig, function()
            TimerStart(CreateTimer(), 0.0, false, OnLoad)
        end)

        --Functions that return a framehandle have the lowest possible priority so that other hooks don't break because they return a table.
        --Functions that take a framehandle have the highest possible priority so that other hooks don't receive a table.

        Hook.add("BlzCreateFrame", function(self, name, ownerVar, priority, createContext)
            local ownerFrame, ownerData = GetFrameAndData(ownerVar)
            local newFrame = self.old(name, ownerFrame, priority, createContext)
            return RegisterFrame(newFrame, nil, nil, nil, "BlzCreateFrame", {name, ownerData, priority, createContext})
        end, -2147483648)

        Hook.add("BlzCreateSimpleFrame", function(self, name, ownerVar, createContext)
            local ownerFrame, ownerData = GetFrameAndData(ownerVar)
            local newFrame = self.old(name, ownerFrame, createContext)
            return RegisterFrame(newFrame, nil, nil, nil, "BlzCreateSimpleFrame", {name, ownerData, createContext})
        end, -2147483648)

        Hook.add("BlzCreateFrameByType", function(self, typeName, name, ownerVar, inherits, createContext)
            local ownerFrame, ownerData = GetFrameAndData(ownerVar)
            local newFrame = self.old(typeName, name, ownerFrame, inherits, createContext)
            return RegisterFrame(newFrame, nil, nil, nil, "BlzCreateFrameByType", {typeName, name, ownerData, inherits, createContext})
        end, -2147483648)

        for func, __ in pairs(SETTER_FUNCTIONS) do
            Hook.add(func, function(self, var, ...)
                if var == nil then return end
                local framehandle, data = GetFrameAndData(var)
                self.old(framehandle, ...)
                dataOfFrame[framehandle].setters[self.old] = true
                dataOfFrame[framehandle].setterArgs[self.old] = pack(...)
            end, 2147483647)
        end

        for func, __ in pairs(GETTER_FUNCTIONS) do
            Hook.add(func, function(self, var, ...)
                if var == nil then return end
                local framehandle, data = GetFrameAndData(var)
                return self.old(framehandle, ...)
            end, 2147483647)
        end

        Hook.add("BlzFrameAddText", function(self, var, text)
            local framehandle, data = GetFrameAndData(var)
            if var == nil then return end
            data.addText = data.addText or {}
            table.insert(data.addText, text)
            self.old(framehandle, text)
        end)

        Hook.add("BlzFrameSetParent", function(self, var, parentVar)
            if var == nil then return end
            local framehandle, data = GetFrameAndData(var)
            local parent = GetFrameAndData(parentVar)
            self.old(framehandle, parent)
        end, 2147483647)

        Hook.add("BlzFrameSetTooltip", function(self, var, tooltipVar)
            if var == nil then return end
            local framehandle, data = GetFrameAndData(var)
            local tooltip, tooltipData = GetFrameAndData(tooltipVar)
            self.old(framehandle, tooltip)
            data.tooltip = tooltipData
        end, 2147483647)

        Hook.add("BlzFrameSetAbsPoint", function(self, var, framePoint, x, y)
            if var == nil then return end
            local framehandle, data = GetFrameAndData(var)
            self.old(framehandle, framePoint, x, y)
            data.positioners[framePoint] = self.old
            data.x[framePoint] = x
            data.y[framePoint] = y
        end, 2147483647)

        Hook.add("BlzFrameSetPoint", function(self, var, framePoint, anchorVar, anchorFramePoint, x, y)
            if var == nil or anchorVar == nil then return end
            local framehandle, data = GetFrameAndData(var)
            local anchorFrame, anchorData = GetFrameAndData(anchorVar)
            self.old(framehandle, framePoint, anchorFrame, anchorFramePoint, x, y)
            data.positioners[framePoint] = self.old
            data.x[framePoint] = x
            data.y[framePoint] = y
            data.anchor[framePoint] = anchorData
            data.anchorFramePoint[framePoint] = anchorFramePoint
        end, 2147483647)

        Hook.add("BlzFrameClearAllPoints", function(self, var)
            if var == nil then return end
            local framehandle, data = GetFrameAndData(var)
            self.old(framehandle)
            data.clearAllPoints = true
            for framePoint, __ in pairs(FRAMEPOINTS) do
                data.positioners[framePoint] = nil
            end
        end, 2147483647)

        Hook.add("BlzFrameSetAllPoints", function(self, var, anchorVar)
            if var == nil or anchorVar == nil then return end
            local framehandle, data = GetFrameAndData(var)
            local anchorFrame, anchorData = GetFrameAndData(anchorVar)
            self.old(framehandle, anchorFrame)
            for framePoint, __ in pairs(FRAMEPOINTS) do
                data.positioners[framePoint] = SetPointNative
                data.x[framePoint] = 0
                data.y[framePoint] = 0
                data.anchor[framePoint] = anchorData
                data.anchorFramePoint[framePoint] = framePoint
            end
        end, 2147483647)

        Hook.add("BlzFrameClick", function(self, var)
            if var == nil then return end
            local framehandle, data = GetFrameAndData(var)
            self.old(framehandle)
        end)

        Hook.add("BlzTriggerRegisterFrameEvent", function(self, trigger, var, frameEventType)
            if var == nil then return end
            local framehandle, data = GetFrameAndData(var)
            data.triggers = data.triggers or {}
            data.triggerEventTypes = data.triggerEventTypes or {}
            table.insert(data.triggers, trigger)
            table.insert(data.triggerEventTypes, frameEventType)
            return self.old(trigger, framehandle, frameEventType)
        end, 2147483647)

        Hook.add("BlzGetTriggerFrame", function(self)
            local framehandle = self.old()
            if dataOfFrame[framehandle] == nil then
                RegisterFrame(framehandle)
            end
            return dataOfFrame[framehandle]
        end, -2147483648)

        Hook.add("BlzFrameGetParent", function(self, var)
            if var == nil then return end
            local childFrame, childData = GetFrameAndData(var)
            local parentFrame, parentData = GetFrameAndData(self.old(childFrame))
            if parentData == nil then
                RegisterFrame(parentFrame, nil, nil, nil, nil, nil, childData)
            end
            return parentData or parentFrame
        end, -2147483648)

        --Reforged only.
        if BlzFrameGetChild then
            Hook.add("BlzFrameGetChild", function(self, var, index)
                if var == nil then return end
                local parentFrame, parentData = GetFrameAndData(var)
                local childFrame, childData = GetFrameAndData(self.old(parentFrame, index))
                if childData == nil then
                    childData = RegisterFrame(childFrame, parentData, index)
                end
                return childData
            end, -2147483648)
        end

        Hook.add("BlzGetFrameByName", function(self, name, createContext)
            local frame, frameData = GetFrameAndData(self.old(name, createContext))
            if frameData == nil then
                frameData = RegisterFrame(frame, nil, nil, name .. "---" .. createContext)
            end
            return frameData
        end, -2147483648)

        Hook.add("BlzGetOriginFrame", function(self, originFrame, createContext)
            local frame, frameData = GetFrameAndData(self.old(originFrame, createContext))
            if frameData == nil then
                frameData = RegisterFrame(frame, nil, nil, ORIGIN_FRAME_NAMES[originFrame] .. "---" .. createContext)
            end
            return frameData
        end, -2147483648)

        Hook.add("BlzDestroyFrame", function(self, var)
            if var == nil then return end
            local frame, frameData = GetFrameAndData(var)
            SetVisibleNative(frame, false)
            if frameData.next then
                frameData.next.previous = frameData.previous
            else
                last = frameData.previous
            end
            frameData.previous.next = frameData.next
            frameData[frame] = nil
        end, 2147483647)

        Hook.add("BlzLoadTOCFile", function(self, filePath)
            local success = self.old(filePath)
            if not gameWasSaved then
                table.insert(tocFiles, filePath)
            end
			return success
        end)

        Hook.add("BlzHideOriginFrames", function(self, enable)
            hideOriginFrames = enable
            self.old(enable)
        end)

        Hook.add("GetHandleId", function(self, var)
            if type(var) == "table" and var.framehandle then
                return self.old(var.framehandle)
            else
                return self.old(var)
            end
        end)
    end)

    ---@param var any
    ---@return boolean
    function IsFrame(var)
        if HandleType[var] == "framehandle" then
            return true
        elseif type(var) == "table" then
            return var.framehandle ~= nil
        end
        return false
    end

    ---@param var framehandle | FrameData
    ---@return framehandle | nil
    function GetFrame(var)
        if HandleType[var] == "framehandle" then
            return var --[[@as framehandle]]
        elseif type(var) == "table" then
            return var.framehandle
        end
        return nil
    end
end
if Debug then Debug.endFile() end