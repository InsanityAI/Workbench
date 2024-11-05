if Debug then Debug.beginFile "ListView" end
OnInit.module("ListView", function(require)
    require "FrameRecycler"
    require "LinkedList"

    local listViewCount = 0

    ---@class ListView
    ---@field package container framehandle
    ---@field package slider framehandle
    ---@field package scrollTrigger trigger
    ---@field package sliderTrigger trigger
    ---@field package listSize integer
    ---@field package dummyContentFrame framehandle
    ---@field package contentList LinkedList
    ---@field package recyclerName string
    --- runtime properties
    ---@field package maxHeight number
    ListView = {}
    ListView.__index = ListView


    -- gets calculated by available height after setting up the dialogMessages frame
    -- assumes that every sent message contains minimal amount of text (single-line)
    local maxFrames = 0
    local maxHeight = 0
    local currentUsedHeight = 0
    local index = 1
    local messagesMinIndex, messagesMaxIndex = 1, 1

    ---@class MessageFrameListNode: LinkedListNode
    ---@field value ChatLogMessageFrame
    ---@field getPrev fun(self: MessageFrameListNode): MessageFrameListNode
    ---@field getNext fun(self: MessageFrameListNode): MessageFrameListNode
    ---@field next MessageFrameListNode
    ---@field prev MessageFrameListNode

    ---@class MessageFrameList: LinkedList
    ---@field next MessageFrameListNode
    ---@field prev MessageFrameListNode
    local usedFramesList = LinkedList.create()
    local framesUnused = {} ---@type table<ChatLogMessageFrame, boolean>

    ---@param self ListView
    ---@param val integer
    ---@param change true? is thia not absolute value but relative change value?
    local function sliderValueUpdate(self, val, change)
        if change then
            val = index + val
        end

        if val > messages.n then
            val = messages.n
        elseif val < 0 then
            val = 1
        end

        if index ~= val then
            index = val
        else
            return
        end

        DisableTrigger(self.sliderTrigger)
        BlzFrameSetValue(self.slider, val)
        EnableTrigger(self.sliderTrigger)
    end

    ---@param container framehandle container for listView
    ---@param slider framehandle slider to be used for scrolling
    ---@param listSize integer
    ---@param contentFrameConstructor fun(): framehandle
    function ListView.Create(container, slider, listSize, contentFrameConstructor)
        local self = setmetatable({
            container = container,
            slider = slider,
            scrollTrigger = CreateTrigger(),
            sliderTrigger = CreateTrigger(),
            listSize = listSize,
            recyclerName = 'ListViewContent' .. tostring(listViewCount)
        }, ListView)
        listViewCount = listViewCount + 1

        FrameRecycler.Define(self.recyclerName, true, contentFrameConstructor)
        self.dummyContentFrame = contentFrameConstructor()
        -- BlzFrameSetVisible(self.dummyContentFrame, false)
        self.maxHeight = BlzFrameGetHeight(container)
        local maxFrames = math.floor(self.maxHeight / BlzFrameGetHeight(self.dummyContentFrame))
        FrameRecycler.Allocate(self.recyclerName, maxFrames)

        BlzFrameSetMinMaxValue(slider, 1, listSize)
        BlzFrameSetStepSize(slider, 1)
        BlzFrameSetValue(slider, listSize)
        BlzTriggerRegisterFrameEvent(self.sliderTrigger, slider, FRAMEEVENT_SLIDER_VALUE_CHANGED)
        TriggerAddAction(self.sliderTrigger, function()
            if GetTriggerPlayer() ~= GetLocalPlayer() then return end
            sliderValueUpdate(self, BlzGetTriggerFrameValue())
        end)

        BlzTriggerRegisterFrameEvent(self.scrollTrigger, container, FRAMEEVENT_MOUSE_WHEEL)
        TriggerAddAction(self.scrollTrigger, function()
            if GetTriggerPlayer() ~= GetLocalPlayer() then return end
            sliderValueUpdate(self, math.modf(BlzGetTriggerFrameValue() / 120), true)
        end)
    end
end)
if Debug then Debug.endFile() end
