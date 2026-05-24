if Debug then Debug.beginFile "ArrowKeyMovement" end
OnInit.module("ArrowKeyMovement", function (require)
    -- requires KeyboardSystem, ArrowKeyMovementPlugins
    require "AdvancedCameraSystem"
    require "TimerQueue"

    -- Arrow key movement by The_Witcher
    --   this system allows each player to control 1 unit 
    --   with his arrow keys even if he doesn't own the unit!
    --   It features turning on the left and right arrow, walking foreward 
    --   by pressing the up arrow and walking backwards by pressing the down arrow...
    --
    -- You can improve this system with plugins but you need vJass knowledge for that!
    --
    --  --> The TurnRate of a unit inside the object editor STILL influences the turn rate from this system <--
    --
    -- Included functions:
    --
    --      SetMovementUnit ( whichunit, forWhichPlayer, walkAnimationIndex )
    --                          unit         player            integer
    --            this gives the player the arrow key movement control over the unit
    --            while the unit moves the animation of the given index is played
    --            (just try around to find the index... start at 0 and increase 
    --             by 1 until you find the walk index of that unit)
    --
    --
    --      ReleaseMovementUnit ( fromWhichPlayer )
    --                                player
    --            this function removes the control from a player
    --
    --
    --      GetMovementUnit ( fromWhichPlayer )    returns unit
    --                            player
    --            I think its self explaining...
    --
    --
    --      SetMovementUnitAnimation ( fromWhichPlayer, animation )
    --                                    player         integer
    --            this function allows ingame changing of the played animation of a unit

-- ------- SETUP PART ---------
    
        -- the timer interval... increase if laggy
        local INTERVAL = 0.01 ---@type  real
    
        -- the facing change in degrees each interval (must be a positive value)
        local DEFAULT_VIEW_CHANGE = 4 ---@type  real
    
        -- when you move backwards you move slower than normal...
        local BACKWARDS_MOVING_FACTOR = 0.7       ---@type  real
    
        -- if the unit turns it will turn faster the longer it does...
        -- some people may need that but then it should be 1.02 (1.0 means disabled)
        local TURN_ACCELERATION = 1 ---@type  real
    
        -- (can only be 1 or -1) if you walk backwards you have 2 ways of turning
        --  1. way: pressing left will make the char turn left
        --  2. way: pressing left will make the char turn so he moves to the left                                                                 
        local REVERSED_BACKWARDS_MOVING = 1 ---@type  integer
    
-- whenever this function returns false for a unit it won't be moved even if the player
    --  presses the keys! change to create your own "No Movement" conditions
    ---@param u unit
    ---@return boolean
    local function MoveConditions(u)
        return not IsUnitType(u,UNIT_TYPE_SLEEPING) 
        and not IsUnitType(u,UNIT_TYPE_STUNNED) 
        and not (IsUnitType(u,UNIT_TYPE_DEAD) or GetUnitTypeId(u) == 0 )
    end

    local TimerQueue = TimerQueue.create() -- we probably want a dedicated TimerQueue

    ---@class ArrowKeyMovement: table<player, ArrowKeyMovement>
    ---@field walking integer
    ---@field animation integer
    ---@field SpeedFactor number
    ---@field ViewChange number
    ---@field SpecialDirection number
    ---@field SpecialDirectionActive boolean
    ---@field u unit
    local ArrowKeyMovement = {}
    ArrowKeyMovement.__index = ArrowKeyMovement

    ---@param p player
    ---@return ArrowKeyMovement
    function ArrowKeyMovement.create(p)
        if ArrowKeyMovement[p] then return ArrowKeyMovement[p] end
        local new = setmetatable({
            SpeedFactor = 1,
            SpecialDirection = 0,
            SpecialDirectionActive = false,
            ViewChange = DEFAULT_VIEW_CHANGE
        }, ArrowKeyMovement)
        ArrowKeyMovement[p] = new
        return new
    end

    private static method Walking takes nothing returns nothing
            local  i = 0 ---@type integer
            local  x ---@type real
            local  y ---@type real
            local  X ---@type real
            local  Y ---@type real
            local  boolX ---@type boolean
            local  boolY ---@type boolean
            local  left ---@type boolean
            local  right ---@type boolean
            local  up ---@type boolean
            local  down ---@type boolean
            local  mov ---@type ArrowKeyMovement
            loop
                exitwhen i >= 12              // = bj_MAX_PLAYERS
                mov = .all[i]
                if mov.u ~= nil and MoveConditions(mov.u) then
                    -- special movement <-- plugins
                    if mov.SpecialDirectionActive then
                        if mov.walking ~= 1 then
                            SetUnitTimeScale(mov.u,mov.SpeedFactor)
                            SetUnitAnimationByIndex(mov.u,mov.animation)
                            mov.walking = 1
                        else
                            SetUnitTimeScale(mov.u,mov.SpeedFactor)
                        end
                        x = GetUnitX(mov.u)
                        y = GetUnitY(mov.u)
                        X = x + GetUnitMoveSpeed(mov.u)*INTERVAL * Cos(mov.SpecialDirection*bj_DEGTORAD) * mov.SpeedFactor
                        Y = y + GetUnitMoveSpeed(mov.u)*INTERVAL * Sin(mov.SpecialDirection*bj_DEGTORAD) * mov.SpeedFactor
                        SetUnitPosition(mov.u,X,Y)
                        if (RAbsBJ(GetUnitX(mov.u)-X)>0.5)or(RAbsBJ(GetUnitY(mov.u)-Y)>0.5)then
                            SetUnitPosition(mov.u,X,y)
                            boolX = RAbsBJ(GetUnitX(mov.u)-X)<=0.5
                            SetUnitPosition(mov.u,x,Y)
                            boolY = RAbsBJ(GetUnitY(mov.u)-Y)<=0.5
                            if boolX then
                                SetUnitPosition(mov.u,X,y)
                            elseif boolY then
                                SetUnitPosition(mov.u,x,Y)
                            else
                                SetUnitPosition(mov.u,x,y)
                            end
                        end
                    else
                        -- Normal movement
                        left = IsKeyDown(KEY_LEFT,Player(i))
                        right = IsKeyDown(KEY_RIGHT,Player(i))
                        up = IsKeyDown(KEY_UP,Player(i))
                        down = IsKeyDown(KEY_DOWN,Player(i))
                        --right down
                        if right then
                            if down then
                                SetUnitFacing(mov.u,GetUnitFacing(mov.u)-mov.ViewChange * -REVERSED_BACKWARDS_MOVING)
                            else
                                SetUnitFacing(mov.u,GetUnitFacing(mov.u)-mov.ViewChange)
                            end
                            mov.ViewChange = mov.ViewChange * TURN_ACCELERATION
                        elseif not left then
                            mov.ViewChange = DEFAULT_VIEW_CHANGE
                        end
                        --left down
                        if left then
                            if down then
                                SetUnitFacing(mov.u,GetUnitFacing(mov.u)+mov.ViewChange * -REVERSED_BACKWARDS_MOVING)
                            else
                                SetUnitFacing(mov.u,GetUnitFacing(mov.u)+mov.ViewChange)
                            end
                            mov.ViewChange = mov.ViewChange * TURN_ACCELERATION
                        elseif not right then
                            mov.ViewChange = DEFAULT_VIEW_CHANGE
                        end
                        if mov.ViewChange > 179 then
                            mov.ViewChange = 179
                        end
                        --up down
                        if up then
                            if mov.walking ~= 1 then
                                SetUnitTimeScale(mov.u,mov.SpeedFactor)
                                SetUnitAnimationByIndex(mov.u,mov.animation)
                                mov.walking = 1
                            else
                                SetUnitTimeScale(mov.u,mov.SpeedFactor)
                            end
                            x = GetUnitX(mov.u)
                            y = GetUnitY(mov.u)
                            X = x + GetUnitMoveSpeed(mov.u)*INTERVAL * Cos(GetUnitFacing(mov.u)*bj_DEGTORAD) * mov.SpeedFactor
                            Y = y + GetUnitMoveSpeed(mov.u)*INTERVAL * Sin(GetUnitFacing(mov.u)*bj_DEGTORAD) * mov.SpeedFactor
                            --down down
                        elseif down then
                            if mov.walking ~= 2 then
                                SetUnitTimeScale(mov.u,-BACKWARDS_MOVING_FACTOR * mov.SpeedFactor)
                                SetUnitAnimationByIndex(mov.u,mov.animation)
                                mov.walking = 2
                            else
                                SetUnitTimeScale(mov.u,-BACKWARDS_MOVING_FACTOR * mov.SpeedFactor)
                            end
                            x = GetUnitX(mov.u)
                            y = GetUnitY(mov.u)
                            X = x - GetUnitMoveSpeed(mov.u) * INTERVAL * Cos(GetUnitFacing(mov.u)*bj_DEGTORAD) * BACKWARDS_MOVING_FACTOR * mov.SpeedFactor
                            Y = y - GetUnitMoveSpeed(mov.u) * INTERVAL * Sin(GetUnitFacing(mov.u)*bj_DEGTORAD) * BACKWARDS_MOVING_FACTOR * mov.SpeedFactor
                        end
                        --move
                        if down or up then
                            SetUnitPosition(mov.u,X,Y)
                            if (RAbsBJ(GetUnitX(mov.u)-X)>0.5)or(RAbsBJ(GetUnitY(mov.u)-Y)>0.5)then
                                SetUnitPosition(mov.u,X,y)
                                boolX = RAbsBJ(GetUnitX(mov.u)-X)<=0.5
                                SetUnitPosition(mov.u,x,Y)
                                boolY = RAbsBJ(GetUnitY(mov.u)-Y)<=0.5
                                if boolX then
                                    SetUnitPosition(mov.u,X,y)
                                elseif boolY then
                                    SetUnitPosition(mov.u,x,Y)
                                else
                                    SetUnitPosition(mov.u,x,y)
                                end
                            end
                        else
                            if mov.walking ~= 0 then
                                SetUnitAnimation(mov.u,"stand")
                                SetUnitTimeScale(mov.u,1)
                                mov.walking = 0
                            end
                        end
                    end
                end
                i = i + 1
            endloop
        endmethod
        
        static method onInit takes nothing returns nothing
            .tim = CreateTimer()
            TimerStart(.tim,INTERVAL,true,function ArrowKeyMovement.Walking)
        endmethod

    ---@param p player
    ---@return unit
    function GetMovementUnit(p)
        return ArrowKeyMovement.u
    end

    ---@param p player
    ---@param animation integer
    function SetMovementUnitAnimation(p, animation)
        ArrowKeyMovement.animation = animation
    end

    ---@param p player
    function ReleaseMovementUnit(p)
        if ArrowKeyMovement.u ~= nil then 
            ArrowKeyMovement.walking = 0
            SetUnitAnimation(ArrowKeyMovement.u,"stand")
            SetUnitTimeScale(ArrowKeyMovement.u,1)
            ArrowKeyMovement.u = nil
        end
    end

    ---@param u unit
    ---@param p player
    ---@param anim integer
    function SetMovementUnit(u, p, anim)
        if u == nil then
            ReleaseMovementUnit(p)
            return
        end
        if ArrowKeyMovement.u ~= nil then
            ReleaseMovementUnit(p)
        end
        SetUnitAnimation(ArrowKeyMovement.u,"stand")
        ArrowKeyMovement.u = u
        ArrowKeyMovement.animation = anim
    end
end)




if Debug then Debug.endFile() end

library ArrowKeyMovement initializer Init requires KeyboardSystem, ArrowKeyMovementPlugins

    


                                

    

    //   --------- don't modify anything below this line ------------
    struct ArrowKeyMovement

        
    
    endstruct

    

    //! runtextmacro ArrowKeyMovement_Plugins_Functions()

    private function Init takes nothing returns nothing
        //! runtextmacro Init_ArrowKeyMovement_Plugins()
    end

endlibrary