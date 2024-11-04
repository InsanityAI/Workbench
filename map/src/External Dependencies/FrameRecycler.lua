if Debug then Debug.beginFile "FrameRecycler" end
do
    --[[
    =============================================================================================================================================================
                                                                      Frame Recycler
                                                                        by Antares

                          Recycle frames to avoid using BlzDestroyFrame (which can desync) and use frames in a dynamic, async context.

								Requires:
								TotalInitialization			    https://www.hiveworkshop.com/threads/total-initialization.317099/

    =============================================================================================================================================================
                                                                          A P I
    =============================================================================================================================================================

    FrameRecycler.Define(name, isAsync, constructor)            Define a frametype under the given name. The constructor function will be called whenever a frame
                                                                is requested. It must return a framehandle. If you set the frametype to async, the Get function
                                                                will throw an error when it has run out of preallocated frames.
    FrameRecycler.Allocate(name, amount)                        Preallocate the specified amount for the given frametype. Use this for async frames.
    FrameRecycler.Get(name)                                     Returns a frame of the specified frametype and makes it visible.
    FrameRecycler.Return(whichFrame)                            Hides the specified framehandle and returns it to the recycling system.

    =============================================================================================================================================================
    ]]

    local unusedFrames = {}                 ---@type framehandle[][]
    local frameTypeIsAsync = {}             ---@type table<string,boolean>
    local frameTypeOf = {}                  ---@type table<framehandle,string>
    local constructorOfFrameType = {}       ---@type table<string,function>

    FrameRecycler = {
        ---Define a frametype under the given name. The constructor function will be called whenever a frame is requested. It must return a framehandle.
        ---@param name string
        ---@param isAsync boolean
        ---@param constructor function
        Define = function(name, isAsync, constructor)
            unusedFrames[name] = {}
            frameTypeIsAsync[name] = isAsync
            constructorOfFrameType[name] = constructor
        end,

        ---Preallocate the specified amount for the given frametype.
        ---@param name string
        ---@param amount integer
        Allocate = function(name, amount)
            local list = unusedFrames[name]
            local constructor = constructorOfFrameType[name]
            for i = 1, amount do
                list[i] = constructor()
                BlzFrameSetVisible(list[i], false)
                frameTypeOf[list[i]] = name
            end
        end,

        ---Returns a frame of the specified frametype and makes it visible.
        ---@param name string
        ---@return framehandle | nil
        Get = function(name)
            local list = unusedFrames[name]
            if #list == 0 then
                if frameTypeIsAsync[name] then
                    print("|cffff0000Warning:|r Not enough frames allocated for type " .. name .. ".")
                    return nil
                end
                local newFrame = constructorOfFrameType[name]()
                frameTypeOf[newFrame] = name
                return newFrame
            end

            local frame = list[#list]
            list[#list] = nil
            BlzFrameSetVisible(frame, true)
            return frame
        end,

        ---Hides the specified framehandle and returns it to the recycling system.
        ---@param whichFrame framehandle
        Return = function(whichFrame)
            local name = frameTypeOf[whichFrame]
            local list = unusedFrames[name]
            list[#list + 1] = whichFrame
            BlzFrameSetVisible(whichFrame, false)
        end
    }
end
if Debug then Debug.endFile() end