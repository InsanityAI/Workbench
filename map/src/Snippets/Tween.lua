if Debug then Debug.beginFile "Tween" end
OnInit.module("Tween", function(require)
    require "TimerQueue"

    Tween = { executor = TimerQueue }
    Tween.__index = Tween

    function Tween.create(executor)
        return setmetatable({ executor = executor }, Tween)
    end

    -- Used to chain two Tweeners after set_parallel() is called with true.
    ---@return Tween
    function Tween:chain()
    end

    -- Processes the Tween by the given delta value, in seconds. This is mostly useful for manual control when the Tween is paused.
    -- It can also be used to end the Tween animation immediately, by setting delta longer than the whole duration of the Tween animation.
    -- Returns true if the Tween still has Tweeners that haven't finished.
    ---@param delta number
    ---@return boolean
    function Tween:customStep(delta)

    end

    -- Returns the number of remaining loops for this Tween (see set_loops()).
    -- A return value of -1 indicates an infinitely looping Tween, and a return value of 0 indicates that the Tween has already finished.
    ---@return integer
    function Tween:getLoopsLeft()
    end

    -- Returns the total time in seconds the Tween has been animating (i.e. the time since it started, not counting pauses etc.).
    -- The time is affected by set_speed_scale(), and stop() will reset it to 0.
    -- Note: As it results from accumulating frame deltas, the time returned after the Tween has finished animating will be slightly greater than the actual Tween duration.
    ---@return number
    function Tween:getTotalElapsedTime()
    end

    --[[
    This method can be used for manual interpolation of a value, when you don't want Tween to do animating for you. It's similar to @GlobalScope.lerp(), but with support for custom transition and easing.

initial_value is the starting value of the interpolation.

delta_value is the change of the value in the interpolation, i.e. it's equal to final_value - initial_value.

elapsed_time is the time in seconds that passed after the interpolation started and it's used to control the position of the interpolation. E.g. when it's equal to half of the duration, the interpolated value will be halfway between initial and final values. This value can also be greater than duration or lower than 0, which will extrapolate the value.

duration is the total time of the interpolation.

Note: If duration is equal to 0, the method will always return the final value, regardless of elapsed_time provided.
    ]]
    ---@param initialValue any
    ---@param deltaValue any
    ---@param elapsedTime any
    ---@param duration any
    ---@param transType any
    ---@param easeType any
    ---@return unknown
    function Tween:interpolateValue(initialValue, deltaValue, elapsedTime, duration, transType, easeType)
    end

    -- Returns whether the Tween is currently running, i.e. it wasn't paused and it's not finished.
    ---@return boolean
    function Tween:isRunning()
    end

    --[[
    Returns whether the Tween is valid. A valid Tween is a Tween contained by the scene tree (i.e. the array from SceneTree.get_processed_tweens() will contain this Tween).
    A Tween might become invalid when it has finished tweening, is killed, or when created with Tween.new(). Invalid Tweens can't have Tweeners appended.
    ]]
    ---@return boolean
    function Tween:isValid()
    end

    -- Aborts all tweening operations and invalidates the Tween.
    function Tween:kill()
    end

    --[[ Makes the next Tweener run parallelly to the previous one.

Tween tween = Tween.create();
tween:TweenProperty(...);
tween:Parallel():TweenProperty(...);
tween:Parallel():TweenProperty(...);

All Tweeners in the example will run at the same time.

You can make the Tween parallel by default by using set_parallel().
    ]]
    ---@return Tween
    function Tween:parallel()

    end

    --[[
    Pauses the tweening. The animation can be resumed by using play().

    Note: If a Tween is paused and not bound to any node, it will exist indefinitely until manually started or invalidated.
    If you lose a reference to such Tween, you can retrieve it using SceneTree.get_processed_tweens().
    ]]
    function Tween:pause()

    end

    -- Resumes a paused or stopped Tween.
    function Tween:play()
    end

    --[[
    Sets the default ease type for PropertyTweeners and MethodTweeners appended after this method.

    Before this method is called, the default ease type is EASE_IN_OUT.

    var tween = create_tween()
    tween.tween_property(self, "position", Vector2(300, 0), 0.5) # Uses EASE_IN_OUT.
    tween.set_ease(Tween.EASE_IN)
    tween.tween_property(self, "rotation_degrees", 45.0, 0.5) # Uses EASE_IN.
    ]]
    ---@param ease any
    ---@return Tween
    function Tween:setEase(ease)
    end

    --[[
    If ignore is true, the tween will ignore Engine.time_scale and update with the real, elapsed time. This affects all Tweeners and their delays. Default value is false.
    ]]
    ---@param ignore boolean
    ---@return Tween
    function Tween:setIgnoreTimeScale(ignore)
    end

    --[[
    Sets the number of times the tweening sequence will be repeated, i.e. set_loops(2) will run the animation twice.

Calling this method without arguments will make the Tween run infinitely, until either it is killed with kill(), the Tween's bound node is freed, or all the animated objects have been freed (which makes further animation impossible).

Warning: Make sure to always add some duration/delay when using infinite loops. To prevent the game freezing, 0-duration looped animations (e.g. a single CallbackTweener with no delay) are stopped after a small number of loops, which may produce unexpected results. If a Tween's lifetime depends on some node, always use bind_node().
    ]]
    ---@param loops integer
    ---@return Tween
    function Tween:setLoops(loops)
    end

    --[[
    If parallel is true, the Tweeners appended after this method will by default run simultaneously, as opposed to sequentially.

    Note: Just like with parallel(), the tweener added right before this method will also be part of the parallel step.]]
    ---@param parallel boolean
    ---@return Tween
    function Tween:setParallel(parallel)
    end

    --[[
    Determines the behavior of the Tween when the SceneTree is paused. Check TweenPauseMode for options.

Default value is TWEEN_PAUSE_BOUND.
    ]]
    ---@param mode any
    ---@return Tween
    function Tween:setPauseMode(mode)
    end


    --[[
    Determines whether the Tween should run after process frames (see Node._process()) or physics frames (see Node._physics_process()).

    Default value is TWEEN_PROCESS_IDLE.
]]
    ---@param mode any
    ---@return Tween
    function Tween:setProcessMode(mode)
    end

    --Scales the speed of tweening. This affects all Tweeners and their delays.
    ---@param speed number
    ---@return Tween
    function Tween:setSpeedScale(speed)
    end

    --[[
    Sets the default transition type for PropertyTweeners and MethodTweeners appended after this method.

Before this method is called, the default transition type is TRANS_LINEAR.

var tween = create_tween()
tween.tween_property(self, "position", Vector2(300, 0), 0.5) # Uses TRANS_LINEAR.
tween.set_trans(Tween.TRANS_SINE)
tween.tween_property(self, "rotation_degrees", 45.0, 0.5) # Uses TRANS_SINE.
    ]]
    ---@param trans any
    ---@return Tween
    function Tween:setTrans(trans)
    end

    --[[
    Stops the tweening and resets the Tween to its initial state. This will not remove any appended Tweeners.

Note: This does not reset targets of PropertyTweeners to their values when the Tween first started.

var tween = create_tween()

# Will move from 0 to 500 over 1 second.
position.x = 0.0
tween.tween_property(self, "position:x", 500, 1.0)

# Will be at (about) 250 when the timer finishes.
await get_tree().create_timer(0.5).timeout

# Will now move from (about) 250 to 500 over 1 second,
# thus at half the speed as before.
tween.stop()
tween.play()
Note: If a Tween is stopped and not bound to any node, it will exist indefinitely until manually started or invalidated. If you lose a reference to such Tween, you can retrieve it using SceneTree.get_processed_tweens().
    ]]
    function Tween:stop()
    end

    --[[
    Creates and appends a CallbackTweener. This method can be used to call an arbitrary method in any object. Use Callable.bind() to bind additional arguments for the call.

Example: Object that keeps shooting every 1 second:

GDScriptC#
Tween tween = GetTree().CreateTween().SetLoops();
tween.TweenCallback(Callable.From(Shoot)).SetDelay(1.0f);
Example: Turning a sprite red and then blue, with 2 second delay:

GDScriptC#
Tween tween = GetTree().CreateTween();
Sprite2D sprite = GetNode<Sprite2D>("Sprite");
tween.TweenCallback(Callable.From(() => sprite.Modulate = Colors.Red)).SetDelay(2.0f);
tween.TweenCallback(Callable.From(() => sprite.Modulate = Colors.Blue)).SetDelay(2.0f);
]]
    ---@param callback function
    ---@return CallbackTweener
    function Tween:tweenCallback(callback)
    end

    --[[
    Creates and appends an IntervalTweener. This method can be used to create delays in the tween animation, as an alternative to using the delay in other Tweeners, or when there's no animation (in which case the Tween acts as a timer). time is the length of the interval, in seconds.

Example: Creating an interval in code execution:

GDScriptC#
// ... some code
await ToSignal(CreateTween().TweenInterval(2.0f), Tween.SignalName.Finished);
// ... more code
Example: Creating an object that moves back and forth and jumps every few seconds:

GDScriptC#
Tween tween = CreateTween().SetLoops();
tween.TweenProperty(GetNode("Sprite"), "position:x", 200.0f, 1.0f).AsRelative();
tween.TweenCallback(Callable.From(Jump));
tween.TweenInterval(2.0f);
tween.TweenProperty(GetNode("Sprite"), "position:x", -200.0f, 1.0f).AsRelative();
tween.TweenCallback(Callable.From(Jump));
tween.TweenInterval(2.0f);
    ]]
    ---@param time number
    ---@return IntervalTweener
    function Tween:tweenInterval(time)
    end

    --[[
    Creates and appends a MethodTweener. This method is similar to a combination of tween_callback() and tween_property(). It calls a method over time with a tweened value provided as an argument. The value is tweened between from and to over the time specified by duration, in seconds. Use Callable.bind() to bind additional arguments for the call. You can use MethodTweener.set_ease() and MethodTweener.set_trans() to tweak the easing and transition of the value or MethodTweener.set_delay() to delay the tweening.

Example: Making a 3D object look from one point to another point:

GDScriptC#
Tween tween = CreateTween();
tween.TweenMethod(Callable.From((Vector3 target) => LookAt(target, Vector3.Up)), new Vector3(-1.0f, 0.0f, -1.0f), new Vector3(1.0f, 0.0f, -1.0f), 1.0f); // Use lambdas to bind additional arguments for the call.
Example: Setting the text of a Label, using an intermediate method and after a delay:

GDScriptC#
public override void _Ready()
{
    base._Ready();

    Tween tween = CreateTween();
    tween.TweenMethod(Callable.From<int>(SetLabelText), 0.0f, 10.0f, 1.0f).SetDelay(1.0f);
}

private void SetLabelText(int value)
{
    GetNode<Label>("Label").Text = $"Counting {value}";
}
    ]]
    ---@param method function
    ---@param from unknown
    ---@param to unknown
    ---@param duration number
    ---@return MethodTweener
    function Tween:tweenMethod(method, from, to, duration)
    end

    --[[
    Creates and appends a PropertyTweener. This method tweens a property of an object between an initial value and final_val in a span of time equal to duration, in seconds. The initial value by default is the property's value at the time the tweening of the PropertyTweener starts.

GDScriptC#
Tween tween = CreateTween();
tween.TweenProperty(GetNode("Sprite"), "position", new Vector2(100.0f, 200.0f), 1.0f);
tween.TweenProperty(GetNode("Sprite"), "position", new Vector2(200.0f, 300.0f), 1.0f);
will move the sprite to position (100, 200) and then to (200, 300). If you use PropertyTweener.from() or PropertyTweener.from_current(), the starting position will be overwritten by the given value instead. See other methods in PropertyTweener to see how the tweening can be tweaked further.

Note: You can find the correct property name by hovering over the property in the Inspector. You can also provide the components of a property directly by using "property:component" (eg. position:x), where it would only apply to that particular component.

Example: Moving an object twice from the same position, with different transition types:
    ]]
    ---@param object table
    ---@param property string
    ---@param finalVal unknown
    ---@param duration number
    ---@return PropertyTweener
    function Tween:tweenProperty(object, property, finalVal, duration)
    end

    --[[
    Creates and appends a SubtweenTweener. This method can be used to nest subtween within this Tween, allowing for the creation of more complex and composable sequences.

# Subtween will rotate the object.
var subtween = create_tween()
subtween.tween_property(self, "rotation_degrees", 45.0, 1.0)
subtween.tween_property(self, "rotation_degrees", 0.0, 1.0)

# Parent tween will execute the subtween as one of its steps.
var tween = create_tween()
tween.tween_property(self, "position:x", 500, 3.0)
tween.tween_subtween(subtween)
tween.tween_property(self, "position:x", 300, 2.0)
Note: The methods pause(), stop(), and set_loops() can cause the parent Tween to get stuck on the subtween step; see the documentation for those methods for more information.

Note: The pause and process modes set by set_pause_mode() and set_process_mode() on subtween will be overridden by the parent Tween's settings.
    ]]
    ---@param subtween Tween
    ---@return SubtweenTweener
    function Tween:tweenSubtween(subtween)
    end
end)
if Debug then Debug.endFile() end
