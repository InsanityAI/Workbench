if Debug and Debug.beginFile then Debug.beginFile('MagiCam') end
--[[

MagiCam v1.2

A free-form camera system for WC3! Includes a mathematically perfect World2Screen implementation!

(C) ModdieMads

This software is provided 'as-is', without any express or implied
warranty.  In no event will the authors be held liable for any damages
arising from the use of this software.

Permission is granted to anyone to use this software for any purpose,
excluding commercial applications, and to alter it and redistribute it
freely, subject to the following restrictions:

1. The origin of this software must not be misrepresented; you must not
   claim that you wrote the original software. If you use this software
   in a product, an acknowledgment in the product documentation and public
   profiles is required.
2. Altered source versions must be plainly marked as such, and must not be
   misrepresented as being the original software.
3. This notice may not be removed or altered from any source distribution.

]]

--[[
---+------------------------------------+---
-- | MagiCam v1.2 | --
---+------------------------------------+---

--> by ModdieMads https://www.hiveworkshop.com/members/moddiemads.310879/

+---------------------------------------------------------------------------------------------------------------------+
|                                                                                                                     |
| Provides free-form controls for the Warcraft3 camera!                                                               |
|                                                                                                                     |
| FEATURES:                                                                                                           |
| :: Agile camera controls! Hold down CTRL to enable the MagiCam controls!                                            |
| :: Click and Drag to control a multitude of camera fields in an intuitive fashion!                                  |
| :: Lock the camera to a unit to follow it while still being able to rotate and pan the camera around!               |
| :: A mathematically PERFECT implementation of World2Screen! No magic numbers here!                                  |
|                                                                                                                     |
+---------------------------------------------------------------------------------------------------------------------+

Special thanks to:
    - #modding channel on the HiveWorkshop Discord. The best part of modding WC3!
	- @Situ, for the template map used as the perfect showcase!
    - @Antares, for the help in pushing this to the above and beyond.
    - @Tasyen, for the herculean job of writing The Big UI-Frame Tutorial.
    - @Water, for the support while we're trying to push WC3 to its limits.
    - @Eikonium, for providing the DebugUtils and the IngameConsole.
    - @Vinz, for the crosshair texture!
	
+-------------------------------------------------------------------------------------------------------------------------------------------------+
| USAGE:                                                                                                                                          |
|                                                                                                                                                 |
|   1. Hold down CTRL to enable the MagiCam controls!                                                                                             |
|   2. Copy the MagiCam script into the Trigger Editor. Order it under the MagiMouse script.                                                      |
|   3. [OPTIONAL] Configure the system in the MagiCam global table.                                                                               |
|   4. Call MagiCam.Init() in a trigger with the "Elapsed game time is 0.01 seconds" event.                                                       |
|                                                                                                                                                 |
+-------------------------------------------------------------------------------------------------------------------------------------------------+

+-------------------------------------------------------------------------------------------------------------------------------------------------+
| INSTALLATION:                                                                                                                                   |
|                                                                                                                                                 |
|   1. Install the MagiMouse system into your map.                                                                                                |
|   2. Copy the MagiCam script into the Trigger Editor. Order it under the MagiMouse script.                                                      |
|   3. [OPTIONAL] Configure the system in the MagiCam global table.                                                                               |
|   4. Call MagiCam.Init() in a trigger with the "Elapsed game time is 0.01 seconds" event.                                                       |
|                                                                                                                                                 |
+-------------------------------------------------------------------------------------------------------------------------------------------------+

* ------------------
* |      API       |
* ------------------
*
*    MagiCam.Init(debugEnabled) <returns nil>
*        - Initialization function. Required to make the system operational.
*        - Args ->
*             - debugEnabled: Enables the system to initialize with the Debug mode enabled.
*
*    MagiCam.RefreshCamFields() <returns nil>
*        - Reads the camera fields and stores them for speed and ease of access.
*
*    MagiCam.FoVToViewPlaneDist(fov) <returns real>
*        - Calculates the distance of the camera's view plane to the camera's eye using the Field of View field.
*
*    MagiCam.FrameXY2SaneXY(frameX, frameY) <returns real, real>
*        - Converts coordinates in frame-space to sane-space.
*        - Frame-Space: Center of the screen = {0.4,0.3}
*        - Sane-Space: Top-Left of the screen = {0.0,0.0}, Bottom-Right of the screen = {1.0,1.0}
*
*    MagiCam.WorldXYZToFrameXY(worldX, worldY, worldZ) <returns real, real> | <returns nil>
*        - Calculates the frame-space screen coordinates of a 3D point in world-space.
*        - If the screen-space coordinates are outside the screen boundaries, returns nil.
*        - SCREEN_XY_TOLERANCE is a configurable tolerance parameter for the screen boundaries check.
*        - Zero magic numbers involved!
*
*    MagiCam.WorldXYZToSaneXY(worldX, worldY, worldZ) <returns real, real>
*        - Calculates the frame-space screen coordinates of a 3D point in world-space.
*        - If the screen-space coordinates are outside the screen boundaries, returns nil.
*        - SCREEN_XY_TOLERANCE is a configurable tolerance parameter for the screen boundaries check.
*        - Frame-Space: Center of the screen = {0.4,0.3}
*        - Sane-Space: Top-Left of the screen = {0.0,0.0}, Bottom-Right of the screen = {1.0,1.0}
*
*    MagiCam.IsWorldXYZInsideScreen(worldX, worldY, worldZ) <returns boolean>
*        - Checks if the screen-space coordinates of a 3D point is within the screen boundaries.
*        - SCREEN_XY_TOLERANCE is a configurable tolerance parameter for the screen boundaries check.
*
*    MagiCam.IsWorldXYZInsideScreen(worldX, worldY, worldZ) <returns boolean>
*        - Checks if the screen-space coordinates of a 3D point is within the screen boundaries.
*
*    MagiCam.IsWorldXYZInsideViewCone(worldX, worldY, worldZ) <returns boolean>
*        - Checks if a 3D point in world-space is inside the view cone of the camera.
*        - VIEW_CONE_TOLERANCE is a configurable tolerance parameter for the view cone check.
*
*    MagiCam.SetCamHolder(u) <returns nil>
*        - Locks the camera to a unit. If the argument u is nil, unlocks the camera instead.
*        - VIEW_CONE_TOLERANCE is a configurable tolerance parameter for the view cone check.
*
*    MagiCam.SetEnable(enabled, willResetCam) <returns nil>
*        - Sets the status of the system.
*        - [OPTIONAL]willResetCam: Resets the camera to game's default camera.
*
*    MagiCam.SetFieldsDefaultValuesToCurrent() <returns nil>
*        - Sets the default values of the camera's fields to their current values.
*        - Automatically called upon initialization.
*
*    MagiCam.ResetFieldsValues() <returns nil>
*        - Resets the camera's fields (not including the Camera Target) to their default values, as set by MagiCam.SetFieldsDefaultValuesToCurrent.
*
]]
do
    local DEG2RAD = 0.017453292519943295;
    local RAD2DEG = 57.29577951308232;
    local HALF_PI = 0.5 * bj_PI;
    local TWO_PI = 2.0 * bj_PI;

    MagiCam = {
        -- Easy to Configure Parameters
        PAN_DRAG_STRENGTH = 1400,
        SIDE_SCROLL_STRENGTH = 140,
        HOLD_SPACEBAR_STRENGTH = 140,

        -- These 2 can NEVER be the exact same value.
        MIN_AOA = 270 * DEG2RAD,
        MAX_AOA = 360 * DEG2RAD,

        -- These 2 can NEVER be the exact same value.
        MIN_FIRST_PERSON_AOA = 271 * DEG2RAD,
        MAX_FIRST_PERSON_AOA = 449 * DEG2RAD,

        -- These 2 can NEVER be the exact same value.
        MAX_FIRST_PERSON_ZOFF = 200.0,
        MIN_FIRST_PERSON_ZOFF = 0.0,

        -- These 2 can NEVER be the exact same value.
        MIN_EYE_TARGET_DIST = 50.0,
        MAX_EYE_TARGET_DIST = 4800.0,

        -- When the Wheel Factor gets lower than this value, first person mode is activated.
        WHEEL_FIRST_PERSON_ZONE = 0.2,

        isInit = false,
        isLocked = false,
        isEnabled = false,
        debugMode = false,

        isLMBDown = false,
        isRMBDown = false,
        isShiftDown = false,
        isSpaceBarDown = false,
        isDragging = false,
        isToggleKeyDown = false,

        defaults = {}
    };

    local EPSILON = .00001;
    local VEC2_1_0 = { 1, 0 };
    local VEC2_0_1 = { 0, 1 };

    local CAM_VIEW_ASPECT_RATIO = 16.0 / 9.0;
    local CAM_VIEWPORT_HEIGHT = 300.0;
    local CAM_CONSOLE_HEIGHT = 130.0;

    local CAM_DEF_TARG_DIST = 1650.0;
    local SCREEN_XY_TOLERANCE = .02;
    local VIEW_CONE_TOLERANCE = .03;

    local CAM_UPDATES_PER_MOUSE_MOVE = 8;

    local mouseWheelCatcher;
    local mouseWheelFactor = (CAM_DEF_TARG_DIST - MagiCam.MIN_EYE_TARGET_DIST) /
    (MagiCam.MAX_EYE_TARGET_DIST - MagiCam.MIN_EYE_TARGET_DIST);
    local mouseWheelFactorStep = .1;

    local willUpdateMouseWheel = false;

    local MAIN_TICK_DUR = .02;

    local mouseMoveTick = 0;
    local lastCamUpdateTick = 0;
    local lastRefreshCamFieldsTick = -1;
    local lastUpdateViewAxesTick = -1;
    local mainTick = 0;

    local mouseX = 0.5;
    local mouseY = 0.5;

    local startDragMouseX = 0.0;
    local startDragMouseY = 0.0;

    local startDragCamTargetX = 0.0;
    local startDragCamTargetY = 0.0;

    local startDragOffsetX = 0.0;
    local startDragOffsetY = 0.0;

    local curDragCamRot = bj_PI / 2.0;
    local startDragCamRot = curDragCamRot;

    local curDragCamAoA = DEG2RAD * 304.0;
    local startDragCamAoA = curDragCamAoA;

    local curDragCamLocalYaw = 0;
    local startDragCamLocalYaw = curDragCamLocalYaw;

    local curDragCamLocalPitch = 0;
    local startDragCamLocalPitch = curDragCamLocalPitch;

    local curDragCamLocalRoll = 0;
    local startDragCamLocalRoll = curDragCamLocalRoll;

    local vecCamTarg = {};
    local vecCamEye = {};
    local vecCamDir = {};

    local camDirX;
    local camDirY;
    local camDirZ;

    local vecViewPlaneN, vecViewPlaneOri, vecViewPlaneDist, viewPlaneConst, vecCamSide, vecCamUp;

    local vecViewAxisX = { 1, 0, 0 };
    local vecViewAxisY = { 0, 1, 0 };

    local mainTimer;

    local tempLoc;

    ---@param ... unknown
    local function PrintDebug(...)
        if MagiCam.debugMode then print(...) end;
    end

    ---@param x number
    ---@param y number
    ---@return number z
    function GetLocZ(x, y)
        MoveLocation(tempLoc, x, y);
        return GetLocationZ(tempLoc);
    end

    ---@param val number
    ---@return number
    local function Round(val)
        return math.floor(val + .5);
    end

    ---@param v0 number
    ---@param v1 number
    ---@param t number
    ---@return number
    local function Lerp(v0, v1, t)
        return v0 + (v1 - v0) * t;
    end

    ---@param v number
    ---@param v0 number
    ---@param v1 number
    ---@return number
    local function Clamp(v, v0, v1)
        return v < v0 and v0 or (v > v1 and v1 or v);
    end

    ---@param val number
    ---@return number
    local function Sign(val)
        return val < 0 and -1 or 1;
    end

    ---@param vec0 [number, number]
    ---@param vec1 [number, number]
    ---@return number
    local function Vec2Dot(vec0, vec1)
        return vec0[1] * vec1[1] + vec0[2] * vec1[2];
    end

    ---@param vec [number, number]
    ---@return number
    local function Vec2Mag(vec)
        return math.sqrt(Vec2Dot(vec, vec));
    end

    ---@param vec [number, number]
    ---@param scalar number
    ---@return [number, number]
    local function Vec2Scale(vec, scalar)
        return { vec[1] * scalar, vec[2] * scalar };
    end

    ---@param vec [number, number]
    ---@return [number, number]
    local function Vec2Normalize(vec)
        return Vec2Scale(vec, 1.0 / Vec2Mag(vec));
    end

    ---@param vecTo [number, number]
    ---@param vecFrom [number, number]
    ---@return number
    local function Vec2RadGap(vecTo, vecFrom)
        return math.atan(vecFrom[1] * vecTo[2] - vecFrom[2] * vecTo[1], vecTo[1] * vecFrom[1] + vecTo[2] * vecFrom[2]);
    end

    ---@param vec0 [number, number, number]
    ---@param vec1 [number, number, number]
    ---@param t number
    ---@return [number, number]
    local function Vec3Lerp(vec0, vec1, t)
        return { Lerp(vec0[1], vec1[1], t), Lerp(vec0[2], vec1[2], t), Lerp(vec0[3], vec1[3], t) };
    end

    ---@param vec0 [number, number, number]
    ---@param vec1 [number, number, number]
    ---@return number
    local function Vec3Dot(vec0, vec1)
        return vec0[1] * vec1[1] + vec0[2] * vec1[2] + vec0[3] * vec1[3];
    end

    ---@param vec [number, number, number]
    ---@return number
    local function Vec3SqrMag(vec)
        return vec[1] * vec[1] + vec[2] * vec[2] + vec[3] * vec[3];
    end

    ---@param vec [number, number, number]
    ---@return number
    local function Vec3Mag(vec)
        return math.sqrt(Vec3SqrMag(vec));
    end

    ---@param vec [number, number, number]
    ---@param scalar number
    ---@return [number, number, number]
    local function Vec3Scale(vec, scalar)
        return { vec[1] * scalar, vec[2] * scalar, vec[3] * scalar };
    end

    ---@param vec [number, number, number]
    ---@param vecBase [number, number, number]
    ---@return [number, number, number]
    local function Vec3Proj(vec, vecBase)
        return Vec3Scale(vecBase, Vec3Dot(vec, vecBase) / Vec3SqrMag(vecBase));
    end

    ---@param vec0 [number, number, number]
    ---@param vec1 [number, number, number]
    ---@return number
    local function Vec3RadGap(vec0, vec1)
        return math.acos(Clamp((Vec3Dot(vec0, vec1) / math.sqrt(Vec3SqrMag(vec0) * Vec3SqrMag(vec1))), -1.0, 1.0))
    end

    ---@param vecTo [number, number, number]
    ---@param vecFrom [number, number, number]
    ---@return [number, number, number]
    local function Vec3Cross(vecTo, vecFrom)
        return { vecFrom[2] * vecTo[3] - vecFrom[3] * vecTo[2], vecFrom[3] * vecTo[1] - vecFrom[1] * vecTo[3], vecFrom
        [1] * vecTo[2] - vecFrom[2] * vecTo[1] };
    end

    ---@param vec [number, number, number]
    ---@return [number, number, number]
    local function Vec3Neg(vec)
        return { -vec[1], -vec[2], -vec[3] };
    end

    ---@param vec [number, number, number]
    ---@return [number, number, number]
    local function Vec3Sqr(vec)
        return { vec[1] * vec[1], vec[2] * vec[2], vec[3] * vec[3] };
    end

    ---@param vec [number, number, number]
    ---@return [number, number, number]
    local function Vec3Normalize(vec)
        return Vec3Scale(vec, 1.0 / Vec3Mag(vec));
    end

    ---@param vecTo [number, number, number]
    ---@param vecFrom [number, number, number]
    ---@return [number, number, number]
    local function Vec3Subtract(vecTo, vecFrom)
        return { vecTo[1] - vecFrom[1], vecTo[2] - vecFrom[2], vecTo[3] - vecFrom[3] };
    end

    ---@param vec0 [number, number, number]
    ---@param vec1 [number, number, number]
    ---@return [number, number, number]
    local function Vec3Add(vec0, vec1)
        return { vec0[1] + vec1[1], vec0[2] + vec1[2], vec0[3] + vec1[3] };
    end

    ---@param vec0 [number, number, number]
    ---@param vec1 [number, number, number]
    ---@param vec2 [number, number, number]
    ---@return [number, number, number]
    local function Vec3Add_3(vec0, vec1, vec2)
        return { vec0[1] + vec1[1] + vec2[1], vec0[2] + vec1[2] + vec2[2], vec0[3] + vec1[3] + vec2[3] };
    end

    ---@param v [number, number, number]
    ---@param n [number, number, number]
    ---@param radVal number
    ---@return [number, number, number]
    local function Vec3RotateByVec(v, n, radVal)
        local cosrad = math.cos(radVal);

        return Vec3Add_3(Vec3Scale(v, cosrad), Vec3Scale(Vec3Cross(v, n), math.sin(radVal)),
            Vec3Scale(n, Vec3Dot(n, v) * (1.0 - cosrad)));
    end

    ---@param vecLine0 [number, number, number]
    ---@param vecLine1 [number, number, number]
    ---@param vecPlaneNorm [number, number, number]
    ---@param viewPlaneConst number
    ---@return [number, number, number]?, number?
    local function LinePlaneIntersectionVecScalar(vecLine0, vecLine1, vecPlaneNorm, viewPlaneConst)
        local dLine = Vec3Subtract(vecLine1, vecLine0);

        local dot = Vec3Dot(dLine, vecPlaneNorm);

        if dot == 0 then return nil end;

        local t = -(Vec3Dot(vecLine0, vecPlaneNorm) - viewPlaneConst) / dot;

        return Vec3Add(vecLine0, Vec3Scale(dLine, t)), t;
    end

    local function ResizeWheelCatcher()
        BlzFrameSetSize(mouseWheelCatcher, MagiCam.screenAspectRatio * .6 - .015, .6 - .01);
    end

    local function HideMouseWheelCatcher()
        BlzFrameSetVisible(mouseWheelCatcher, false);
        BlzFrameCageMouse(mouseWheelCatcher, false);
    end

    local function TrigToggleKeyDown()
        EnableDragSelect(false, false);

        if lastRefreshCamFieldsTick < mainTick then MagiCam.RefreshCamFields() end;

        BlzFrameSetVisible(mouseWheelCatcher, true);
        ResizeWheelCatcher();
        BlzFrameCageMouse(mouseWheelCatcher, true);

        MagiCam.isToggleKeyDown = true;
    end

    local function TrigToggleKeyUp()
        EnableDragSelect(true, true);

        HideMouseWheelCatcher();

        MagiCam.isDragging = false;
        MagiCam.isToggleKeyDown = false;
    end

    function MagiCam.RefreshCamFields()
        local math_sqrt = math.sqrt;

        local oldWid, oldHei = MagiCam.screenWid, MagiCam.screenHei;

        MagiCam.screenWid = BlzGetLocalClientWidth();
        MagiCam.screenWid = MagiCam.screenWid > 0 and MagiCam.screenWid or 1;

        MagiCam.screenHei = BlzGetLocalClientHeight();
        MagiCam.screenHei = MagiCam.screenHei > 0 and MagiCam.screenHei or 1;

        MagiCam.screenAspectRatio = MagiCam.screenWid / MagiCam.screenHei;

        MagiCam.screenDiag = math_sqrt(MagiCam.screenWid * MagiCam.screenWid + MagiCam.screenHei * MagiCam.screenHei);

        if oldWid ~= MagiCam.screenWid or oldHei ~= MagiCam.screenHei or not BlzIsLocalClientActive() then
            ResizeWheelCatcher();
            TrigToggleKeyUp();
            MagiCam.isShiftDown = false;
        end

        MagiCam.fov = GetCameraField(CAMERA_FIELD_FIELD_OF_VIEW);
        MagiCam.rotation = GetCameraField(CAMERA_FIELD_ROTATION);
        MagiCam.roll = GetCameraField(CAMERA_FIELD_ROLL);
        MagiCam.aoa = GetCameraField(CAMERA_FIELD_ANGLE_OF_ATTACK);
        MagiCam.targetDist = GetCameraField(CAMERA_FIELD_TARGET_DISTANCE);
        MagiCam.zOffset = GetCameraField(CAMERA_FIELD_ZOFFSET);

        MagiCam.targetX = GetCameraTargetPositionX();
        MagiCam.targetY = GetCameraTargetPositionY();
        MagiCam.targetZ = GetCameraTargetPositionZ();

        MagiCam.holderX = MagiCam.targetX;
        MagiCam.holderY = MagiCam.targetY;
        MagiCam.holderZ = MagiCam.targetZ;

        vecCamTarg[1] = MagiCam.targetX;
        vecCamTarg[2] = MagiCam.targetY;
        vecCamTarg[3] = MagiCam.targetZ;

        if MagiCam.camHolder then
            if GetUnitTypeId(MagiCam.camHolder) == 0 then
                MagiCam.camHolder = nil;
            else
                MagiCam.holderX = GetUnitX(MagiCam.camHolder);
                MagiCam.holderY = GetUnitY(MagiCam.camHolder);
                MagiCam.holderZ = GetLocZ(MagiCam.holderX, MagiCam.holderY);
            end
        end

        MagiCam.eyeX = GetCameraEyePositionX();
        MagiCam.eyeY = GetCameraEyePositionY();
        MagiCam.eyeZ = GetCameraEyePositionZ();

        vecCamEye[1] = MagiCam.eyeX;
        vecCamEye[2] = MagiCam.eyeY;
        vecCamEye[3] = MagiCam.eyeZ;

        camDirX = MagiCam.targetX - MagiCam.eyeX;
        camDirY = MagiCam.targetY - MagiCam.eyeY;
        camDirZ = MagiCam.targetZ - MagiCam.eyeZ;

        local invmag = 1.0 / math_sqrt(camDirX * camDirX + camDirY * camDirY + camDirZ * camDirZ);

        camDirX = camDirX * invmag;
        camDirY = camDirY * invmag;
        camDirZ = camDirZ * invmag;

        vecCamDir[1] = camDirX;
        vecCamDir[2] = camDirY;
        vecCamDir[3] = camDirZ;

        MagiCam.localYaw = GetCameraField(CAMERA_FIELD_LOCAL_YAW);
        MagiCam.localPitch = GetCameraField(CAMERA_FIELD_LOCAL_PITCH);
        MagiCam.localRoll = GetCameraField(CAMERA_FIELD_LOCAL_ROLL);

        lastRefreshCamFieldsTick = mainTick;
    end

    local MCGVPD_memoArg = 70.0 * DEG2RAD;
    local MCGVPD_memoVal = 740.66448;
    local CAM_ASPECT_RATIO_FOV_FIX = 1.05 / (2 * math.sqrt(CAM_VIEW_ASPECT_RATIO + 1.0));
    ---@param fov number
    ---@return number memoVal
    function MagiCam.FoVToViewPlaneDist(fov)
        MCGVPD_memoVal = MCGVPD_memoArg == fov and MCGVPD_memoVal or
        CAM_VIEWPORT_HEIGHT / math.tan(fov * CAM_ASPECT_RATIO_FOV_FIX);
        MCGVPD_memoArg = fov;
        return MCGVPD_memoVal;
    end

    local function UpdateViewAxes()
        if lastRefreshCamFieldsTick < mainTick then MagiCam.RefreshCamFields() end;

        local vecCamSight = Vec3Subtract(vecCamTarg, vecCamEye);

        vecViewPlaneN = Vec3Normalize(vecCamSight);

        local screenUpSideSign = Sign(-math.sin(2.0 * MagiCam.aoa));

        local vecCamFront = { vecCamSight[1] * screenUpSideSign, vecCamSight[2] * screenUpSideSign, 0.0 };

        vecCamFront = Vec3SqrMag(vecCamFront) > EPSILON and Vec3Normalize(vecCamFront) or
        { math.cos(MagiCam.rotation), math.sin(MagiCam.rotation), 0 };

        vecCamFront = Vec3RotateByVec(vecCamFront, vecViewPlaneN, MagiCam.roll);

        vecCamSide = Vec3Normalize(Vec3Cross(vecCamFront, vecViewPlaneN));

        if MagiCam.localPitch ~= 0 then
            vecViewPlaneN = Vec3RotateByVec(vecViewPlaneN, vecCamSide, MagiCam.localPitch);
            vecCamFront = Vec3RotateByVec(vecCamFront, vecCamSide, MagiCam.localPitch);
        end

        vecCamUp = Vec3RotateByVec(vecViewPlaneN, vecCamSide, HALF_PI);

        if MagiCam.localYaw ~= 0 then
            vecViewPlaneN = Vec3RotateByVec(vecViewPlaneN, vecCamUp, MagiCam.localYaw);
            vecCamSide = Vec3RotateByVec(vecCamSide, vecCamUp, MagiCam.localYaw);
            vecCamFront = Vec3RotateByVec(vecCamFront, vecCamUp, MagiCam.localYaw);
        end

        if MagiCam.localRoll ~= 0 then
            vecCamUp = Vec3RotateByVec(vecCamUp, vecViewPlaneN, MagiCam.localRoll);
            vecCamSide = Vec3RotateByVec(vecCamSide, vecViewPlaneN, MagiCam.localRoll);
            vecCamFront = Vec3RotateByVec(vecCamFront, vecViewPlaneN, MagiCam.localRoll);
        end

        vecViewPlaneDist = MagiCam.FoVToViewPlaneDist(MagiCam.fov);

        vecViewPlaneOri = Vec3Add(vecCamEye, Vec3Scale(vecViewPlaneN, vecViewPlaneDist));

        viewPlaneConst = Vec3Dot(vecViewPlaneN, vecViewPlaneOri);

        vecCamFront = Vec3Add(vecCamEye, vecCamFront);

        vecViewAxisY = LinePlaneIntersectionVecScalar(
            vecCamFront,
            Vec3Add(
                vecCamFront,
                Vec3Scale(vecViewPlaneN, 100000.0)
            ),
            vecViewPlaneN,
            viewPlaneConst
        ) --[[@as [number, number, number] ]];

        vecViewAxisY = Vec3Subtract(vecViewAxisY, vecViewPlaneOri);
        vecViewAxisY = Vec3Normalize(vecViewAxisY);

        vecViewAxisX = Vec3Cross(vecViewAxisY, vecViewPlaneN);

        lastUpdateViewAxesTick = mainTick;
    end

    ---@param frameX number
    ---@param frameY number
    ---@return number x, number y
    function MagiCam.FrameXY2SaneXY(frameX, frameY)
        return 1.666667 * ((frameX - .4) + .3 * MagiCam.screenAspectRatio) / MagiCam.screenAspectRatio,
            (1.0 - 1.666667 * frameY);
    end

    ---@param worldX number
    ---@param worldY number
    ---@param worldZ number
    ---@return number? projX, number? projY
    function MagiCam.WorldXYZToFrameXY(worldX, worldY, worldZ)
        if lastUpdateViewAxesTick < mainTick then UpdateViewAxes() end;

        local vecIntersect, tIntersect = LinePlaneIntersectionVecScalar(
            { worldX, worldY, worldZ == nil and GetLocZ(worldX, worldY) or worldZ },
            vecCamEye,
            vecViewPlaneN,
            viewPlaneConst
        );

        if tIntersect > 1.0 then
            return nil;
        end

        local vecIntersectDif = Vec3Subtract(vecIntersect --[[@as [number,number,number] ]], vecViewPlaneOri);

        local projX = Vec3Dot(vecIntersectDif, vecViewAxisX);
        local projY = Vec3Dot(vecIntersectDif, vecViewAxisY) + CAM_CONSOLE_HEIGHT * (1.0 - math.cos(MagiCam.aoa));

        projX = .001 * (projX + 400.);
        projY = .001 * (projY + 300.);

        local saneX, saneY = MagiCam.FrameXY2SaneXY(projX, projY);

        if saneX < -SCREEN_XY_TOLERANCE and saneX > 1.0 + SCREEN_XY_TOLERANCE and
            saneY < -SCREEN_XY_TOLERANCE and saneY > 1.0 + SCREEN_XY_TOLERANCE then
            return nil;
        end

        return projX, projY;
    end

    ---@param x number
    ---@param y number
    ---@param z number
    ---@return number? x, number? y
    function MagiCam.WorldXYZToSaneXY(x, y, z)
        local frameX, frameY = MagiCam.WorldXYZToFrameXY(x, y, z);

        if not frameX then return nil end;

        return MagiCam.FrameXY2SaneXY(frameX, frameY --[[@as number]]);
    end

    ---@param x number
    ---@param y number
    ---@param z number
    ---@return boolean
    function MagiCam.IsWorldXYZInsideScreen(x, y, z)
        return MagiCam.WorldXYZToSaneXY(x, y, z) ~= nil;
    end

    ---@param x number
    ---@param y number
    ---@param z number
    ---@return boolean
    function MagiCam.IsWorldXYZInsideViewCone(x, y, z)
        if lastRefreshCamFieldsTick < mainTick then MagiCam.RefreshCamFields() end;

        local vecXYZFromCam = Vec3Subtract({ x, y, z }, vecCamEye);
        local dot = Vec3Dot(vecXYZFromCam, vecCamDir);

        local coneRadius = .5 * (1.0 + VIEW_CONE_TOLERANCE) * dot * MagiCam.screenDiag /
        MagiCam.FoVToViewPlaneDist(MagiCam.fov);

        return Vec3SqrMag(Vec3Subtract(vecXYZFromCam, Vec3Scale(vecCamDir, dot))) < coneRadius * coneRadius;
    end

    local function TrigMouseDown()
        MagiCam.mouseWorldX = BlzGetTriggerPlayerMouseX();
        MagiCam.mouseWorldY = BlzGetTriggerPlayerMouseY();

        local mouseBtn = BlzGetTriggerPlayerMouseButton();
        if mouseBtn == MOUSE_BUTTON_TYPE_LEFT then
            MagiCam.isLMBDown = true;
        elseif mouseBtn == MOUSE_BUTTON_TYPE_RIGHT then
            MagiCam.isRMBDown = true;
        end

        if BlzFrameIsVisible(mouseWheelCatcher) then
            if MagiCam.isLMBDown then
                ShowInterface(false, 0);
                ShowInterface(true, 0);

                MagiCam.isDragging = true;

                if lastRefreshCamFieldsTick < mainTick then MagiCam.RefreshCamFields() end;

                startDragMouseX = mouseX;
                startDragMouseY = mouseY;

                startDragCamRot = MagiCam.rotation;
                curDragCamRot = startDragCamRot;

                startDragCamAoA = MagiCam.aoa;
                startDragCamAoA = (startDragCamAoA > HALF_PI) and startDragCamAoA or startDragCamAoA + TWO_PI;
                curDragCamAoA = startDragCamAoA;

                startDragCamLocalYaw = MagiCam.localYaw;
                curDragCamLocalYaw = startDragCamLocalYaw;

                startDragCamLocalPitch = MagiCam.localPitch;
                curDragCamLocalPitch = startDragCamLocalPitch;

                startDragCamLocalRoll = MagiCam.localRoll;
                curDragCamLocalRoll = startDragCamLocalRoll;
            elseif MagiCam.isRMBDown then
                --MagiCam.isRMBDown = true;

                ShowInterface(false, 0);
                ShowInterface(true, 0);

                MagiCam.isDragging = true;

                if lastRefreshCamFieldsTick < mainTick then MagiCam.RefreshCamFields() end;

                startDragMouseX = mouseX;
                startDragMouseY = mouseY;

                startDragCamTargetX = MagiCam.holderX;
                startDragCamTargetY = MagiCam.holderY;

                startDragOffsetX = MagiCam.holderOffsetX;
                startDragOffsetY = MagiCam.holderOffsetY;
            end
        end
    end

    local function TrigMouseUp()
        MagiCam.mouseWorldX = BlzGetTriggerPlayerMouseX();
        MagiCam.mouseWorldY = BlzGetTriggerPlayerMouseY();

        local mouseBtn = BlzGetTriggerPlayerMouseButton();
        if mouseBtn == MOUSE_BUTTON_TYPE_LEFT then
            MagiCam.isLMBDown = false;
        elseif mouseBtn == MOUSE_BUTTON_TYPE_RIGHT then
            MagiCam.isRMBDown = false;
        end

        if BlzFrameIsVisible(mouseWheelCatcher) then
            MagiCam.isDragging = false;
            if not MagiCam.isToggleKeyDown then
                HideMouseWheelCatcher();
            end
        end
    end

    local function TrigMouseMove()
        MagiCam.mouseWorldX = BlzGetTriggerPlayerMouseX();
        MagiCam.mouseWorldY = BlzGetTriggerPlayerMouseY();

        mouseMoveTick = mouseMoveTick + 1;
        lastCamUpdateTick = mouseMoveTick;
    end


    local function MainTimerTick()
        mainTick = mainTick + 1;

        if not MagiCam.isEnabled then return end;

        local camHasPanned = false;

        if lastUpdateViewAxesTick < mainTick then UpdateViewAxes() end;

        if willUpdateMouseWheel then
            willUpdateMouseWheel = false;

            local newDist = Lerp(MagiCam.MIN_EYE_TARGET_DIST, MagiCam.MAX_EYE_TARGET_DIST, mouseWheelFactor);
            SetCameraField(CAMERA_FIELD_TARGET_DISTANCE, newDist, .5);

            if mouseWheelFactor <= MagiCam.WHEEL_FIRST_PERSON_ZONE and MagiCam.zOffset < MagiCam.MAX_FIRST_PERSON_ZOFF then
                MagiCam.zOffset = Lerp(
                    MagiCam.MAX_FIRST_PERSON_ZOFF,
                    MagiCam.MIN_FIRST_PERSON_ZOFF,
                    Clamp(mouseWheelFactor, 0, MagiCam.WHEEL_FIRST_PERSON_ZONE) / MagiCam.WHEEL_FIRST_PERSON_ZONE
                );

                SetCameraField(CAMERA_FIELD_ZOFFSET, MagiCam.zOffset, .5);
            end

            if mouseWheelFactor > MagiCam.WHEEL_FIRST_PERSON_ZONE and not MagiCam.isDragging then
                if curDragCamAoA > MagiCam.MAX_AOA then
                    curDragCamAoA = MagiCam.MAX_AOA;
                    SetCameraField(CAMERA_FIELD_ANGLE_OF_ATTACK, RAD2DEG * curDragCamAoA, 0.5);
                elseif curDragCamAoA < MagiCam.MIN_AOA then
                    curDragCamAoA = MagiCam.MIN_AOA;
                    SetCameraField(CAMERA_FIELD_ANGLE_OF_ATTACK, RAD2DEG * curDragCamAoA, 0.5);
                end
            end
        else
            mouseWheelFactor = (MagiCam.targetDist - MagiCam.MIN_EYE_TARGET_DIST) /
            (MagiCam.MAX_EYE_TARGET_DIST - MagiCam.MIN_EYE_TARGET_DIST);
        end

        if MagiCam.eyeZ < 0.0 then
            MagiCam.zOffset = MagiCam.zOffset + (MagiCam.eyeZ < -100.0 and 100.0 or 8.0);
            SetCameraField(CAMERA_FIELD_ZOFFSET, MagiCam.zOffset, 0);
        elseif MagiCam.isSpaceBarDown then
            MagiCam.zOffset = MagiCam.zOffset +
            (MagiCam.isShiftDown and -MagiCam.HOLD_SPACEBAR_STRENGTH or MagiCam.HOLD_SPACEBAR_STRENGTH);
            SetCameraField(CAMERA_FIELD_ZOFFSET, MagiCam.zOffset, .1);
        end

        if lastCamUpdateTick < mouseMoveTick + CAM_UPDATES_PER_MOUSE_MOVE then
            lastCamUpdateTick = lastCamUpdateTick + 1;

            if MagiCam.isDragging then
                local dx = mouseX - startDragMouseX;
                local dy = mouseY - startDragMouseY;
                if MagiCam.isLMBDown then
                    if MagiCam.isShiftDown then
                        local vecNewFront = Vec3Subtract(
                            Vec3Add_3(
                                Vec3Scale(vecViewAxisX, vecViewPlaneDist * dx),
                                Vec3Scale(vecViewAxisY, vecViewPlaneDist * dy),
                                vecViewPlaneOri
                            ),
                            vecCamEye
                        );

                        local frontProjMag = Vec3Dot(vecNewFront, vecViewPlaneN);
                        local sideProjMag = Vec3Dot(vecNewFront, vecCamSide);
                        local upProjMag = Vec3Dot(vecNewFront, vecCamUp);

                        local dYaw = 1.5 * Vec2RadGap(VEC2_0_1, { -sideProjMag, frontProjMag });
                        local dPitch = 1.5 * Vec2RadGap(VEC2_1_0, { frontProjMag, upProjMag });

                        SetCameraField(CAMERA_FIELD_LOCAL_YAW, (RAD2DEG * (startDragCamLocalYaw + dYaw) + .5) // 1, .1);
                        SetCameraField(CAMERA_FIELD_LOCAL_PITCH, (RAD2DEG * (startDragCamLocalPitch + dPitch) + .5) // 1,
                            .1);
                    else
                        local newRot = Lerp(curDragCamRot, startDragCamRot + 1.2 * bj_PI * dx, .25);
                        local newAoA = Lerp(curDragCamAoA, startDragCamAoA - bj_PI * dy, .25);


                        newAoA = mouseWheelFactor > .05 and
                            Clamp(newAoA, MagiCam.MIN_AOA, MagiCam.MAX_AOA) or
                            Clamp(newAoA, MagiCam.MIN_FIRST_PERSON_AOA, MagiCam.MAX_FIRST_PERSON_AOA);

                        curDragCamAoA = newAoA;
                        curDragCamRot = newRot;

                        SetCameraField(CAMERA_FIELD_ROTATION, (RAD2DEG * curDragCamRot + .5) // 1, .1);
                        SetCameraField(CAMERA_FIELD_ANGLE_OF_ATTACK, (RAD2DEG * curDragCamAoA + .5) // 1, .1);
                    end
                elseif MagiCam.isRMBDown then
                    if lastUpdateViewAxesTick < mainTick then UpdateViewAxes() end;

                    local magX = MagiCam.PAN_DRAG_STRENGTH * dx;
                    local magY = 1.333 * MagiCam.PAN_DRAG_STRENGTH * dy;

                    local vecPanAxes = Vec2Normalize({ vecViewAxisX[1], vecViewAxisX[2] });

                    if MagiCam.camHolder then
                        startDragCamTargetX = MagiCam.holderX;
                        startDragCamTargetY = MagiCam.holderY;

                        MagiCam.holderOffsetX = startDragOffsetX - (magX * vecPanAxes[1] + magY * vecPanAxes[2]);
                        MagiCam.holderOffsetY = startDragOffsetY - (magX * vecPanAxes[2] - magY * vecPanAxes[1]);
                    end

                    PanCameraToTimed(
                        startDragCamTargetX + startDragOffsetX - (magX * vecPanAxes[1] + magY * vecPanAxes[2]),
                        startDragCamTargetY + startDragOffsetY - (magX * vecPanAxes[2] - magY * vecPanAxes[1]),
                        .1
                    );
                    camHasPanned = true;
                end
            end
        end

        mouseX = MagiMouse.mouseSaneX;
        mouseY = MagiMouse.mouseSaneY;

        if not camHasPanned and not (MagiCam.isDragging and MagiCam.isRMBDown) then
            if not MagiCam.camHolder and not BlzFrameIsVisible(mouseWheelCatcher) then
                local newSlideX = mouseX <= .005 and MagiCam.SIDE_SCROLL_STRENGTH or
                (mouseX >= .995 and -MagiCam.SIDE_SCROLL_STRENGTH or 0);
                local newSlideY = mouseY <= .005 and MagiCam.SIDE_SCROLL_STRENGTH or
                (mouseY >= .995 and -MagiCam.SIDE_SCROLL_STRENGTH or 0);

                if newSlideX ~= 0 or newSlideY ~= 0 then
                    local vecPanAxes = Vec2Normalize({ vecViewAxisX[1], vecViewAxisX[2] });


                    PanCameraToTimed(
                        MagiCam.holderX + MagiCam.holderOffsetX - (newSlideX * vecPanAxes[1] + newSlideY * vecPanAxes[2]),
                        MagiCam.holderY + MagiCam.holderOffsetY - (newSlideX * vecPanAxes[2] - newSlideY * vecPanAxes[1]),
                        0
                    );
                    camHasPanned = true;
                end
            end

            if not camHasPanned then
                PanCameraToTimed(
                    MagiCam.holderX + MagiCam.holderOffsetX + ((mainTick & 1) - .5) * .005,
                    MagiCam.holderY + MagiCam.holderOffsetY + ((mainTick & 1) - .5) * .005,
                    .5
                );
            end

            camHasPanned = true;
        end
    end

    ---@param u unit?
    function MagiCam.SetCamHolder(u)
        if u and GetUnitTypeId(u) == 0 then u = nil end;

        MagiCam.camHolder = u;

        MagiCam.holderOffsetX = 0;
        MagiCam.holderOffsetY = 0;
        MagiCam.zOffset = MagiCam.defaults.zOffset;

        MagiCam.RefreshCamFields();

        if u then
            SetCameraField(CAMERA_FIELD_ZOFFSET, MagiCam.defaults.zOffset, .5);
            SetCameraField(CAMERA_FIELD_LOCAL_YAW, MagiCam.defaults.localYaw, .5);
            SetCameraField(CAMERA_FIELD_LOCAL_PITCH, MagiCam.defaults.localPitch, .5);
            PanCameraToTimed(MagiCam.holderX, MagiCam.holderY, .5);
        end
    end

    ---@param enabled boolean
    ---@param willResetCam boolean
    function MagiCam.SetEnable(enabled, willResetCam)
        MagiCam.isRMBDown = false;
        MagiCam.isLMBDown = false;
        MagiCam.isDragging = false;
        MagiCam.isToggleKeyDown = false;

        HideMouseWheelCatcher();


        if willResetCam then
            ResetToGameCamera(0);
        end

        MagiCam.isEnabled = enabled;
    end

    local function TrigWheelCatcher()
        if BlzGetTriggerFrameValue() > 0 then
            mouseWheelFactor = mouseWheelFactor - mouseWheelFactorStep;
        else
            mouseWheelFactor = mouseWheelFactor + mouseWheelFactorStep;
        end

        mouseWheelFactor = Clamp(mouseWheelFactor, 0.0, 1.0);

        willUpdateMouseWheel = true;
    end

    local function TrigWheelCatcherClick()
        EnableDragSelect(true, true);

        HideMouseWheelCatcher();

        MagiCam.isDragging = false;
    end

    local function InitFrameStuff()
        mouseWheelCatcher = BlzCreateFrameByType('BUTTON', '', BlzGetFrameByName('ConsoleUIBackdrop', 0), '', 0);
        BlzFrameSetAbsPoint(mouseWheelCatcher, FRAMEPOINT_CENTER, .4, .3);
        BlzFrameSetVisible(mouseWheelCatcher, false);
        BlzFrameSetLevel(mouseWheelCatcher, 8);

        ResizeWheelCatcher();

        local trig;

        trig = CreateTrigger();
        BlzTriggerRegisterFrameEvent(trig, mouseWheelCatcher, FRAMEEVENT_MOUSE_WHEEL);
        TriggerAddAction(trig, TrigWheelCatcher);
    end

    local function InitLocationStuff()
        tempLoc = Location(0.0, 0.0);
    end

    local function TriggerRegisterPlayerKeyEventForAllMetaKeys(trig, player, oskey, onDown, metaKeys)
        if metaKeys then
            for _, v in ipairs(metaKeys) do
                BlzTriggerRegisterPlayerKeyEvent(trig, player, oskey, v, onDown);
            end
        else
            for i = 0, 15 do
                BlzTriggerRegisterPlayerKeyEvent(trig, player, oskey, i, onDown);
            end
        end
    end

    function MagiCam.SetFieldsDefaultValuesToCurrent()
        MagiCam.defaults.fov = GetCameraField(CAMERA_FIELD_FIELD_OF_VIEW);
        MagiCam.defaults.rotation = GetCameraField(CAMERA_FIELD_ROTATION);
        MagiCam.defaults.roll = GetCameraField(CAMERA_FIELD_ROLL);
        MagiCam.defaults.aoa = GetCameraField(CAMERA_FIELD_ANGLE_OF_ATTACK);
        MagiCam.defaults.targetDist = GetCameraField(CAMERA_FIELD_TARGET_DISTANCE);
        MagiCam.defaults.zOffset = GetCameraField(CAMERA_FIELD_ZOFFSET);

        MagiCam.defaults.targetX = GetCameraTargetPositionX();
        MagiCam.defaults.targetY = GetCameraTargetPositionY();
        MagiCam.defaults.targetZ = GetCameraTargetPositionZ();

        MagiCam.defaults.holderX = MagiCam.defaults.targetX;
        MagiCam.defaults.holderY = MagiCam.defaults.targetY;
        MagiCam.defaults.holderZ = MagiCam.defaults.targetZ;

        MagiCam.defaults.eyeX = GetCameraEyePositionX();
        MagiCam.defaults.eyeY = GetCameraEyePositionY();
        MagiCam.defaults.eyeZ = GetCameraEyePositionZ();

        MagiCam.defaults.localYaw = GetCameraField(CAMERA_FIELD_LOCAL_YAW);
        MagiCam.defaults.localPitch = GetCameraField(CAMERA_FIELD_LOCAL_PITCH);
        MagiCam.defaults.localRoll = GetCameraField(CAMERA_FIELD_LOCAL_ROLL);
    end

    function MagiCam.ResetFieldsValues()
        SetCameraField(CAMERA_FIELD_FIELD_OF_VIEW, RAD2DEG * MagiCam.defaults.fov, .5);
        SetCameraField(CAMERA_FIELD_ROTATION, RAD2DEG * MagiCam.defaults.rotation, .5);
        SetCameraField(CAMERA_FIELD_ROLL, RAD2DEG * MagiCam.defaults.roll, .5);
        SetCameraField(CAMERA_FIELD_ANGLE_OF_ATTACK, RAD2DEG * MagiCam.defaults.aoa, .5);
        SetCameraField(CAMERA_FIELD_TARGET_DISTANCE, MagiCam.defaults.targetDist, .5);
        SetCameraField(CAMERA_FIELD_ZOFFSET, MagiCam.defaults.zOffset, .5);

        MagiCam.holderOffsetX = 0;
        MagiCam.holderOffsetY = 0;

        PanCameraToTimed(GetCameraTargetPositionX(), GetCameraTargetPositionY(), .5);

        SetCameraField(CAMERA_FIELD_LOCAL_YAW, RAD2DEG * MagiCam.defaults.localYaw, .5);
        SetCameraField(CAMERA_FIELD_LOCAL_PITCH, RAD2DEG * MagiCam.defaults.localPitch, .5);
        SetCameraField(CAMERA_FIELD_LOCAL_ROLL, RAD2DEG * MagiCam.defaults.localRoll, .5);
    end

    local function InitLocalTriggers()
        local p = GetLocalPlayer();

        local trig = CreateTrigger();
        TriggerRegisterPlayerEvent(trig, p, EVENT_PLAYER_MOUSE_DOWN);
        TriggerAddAction(trig, TrigMouseDown);

        trig = CreateTrigger();
        TriggerRegisterPlayerEvent(trig, p, EVENT_PLAYER_MOUSE_UP);
        TriggerAddAction(trig, TrigMouseUp);

        trig = CreateTrigger();
        TriggerRegisterPlayerEvent(trig, p, EVENT_PLAYER_MOUSE_MOVE);
        TriggerAddAction(trig, TrigMouseMove);

        trig = CreateTrigger();
        TriggerRegisterPlayerKeyEventForAllMetaKeys(trig, p, OSKEY_LCONTROL, true);
        TriggerRegisterPlayerKeyEventForAllMetaKeys(trig, p, OSKEY_RCONTROL, true);
        TriggerAddAction(trig, TrigToggleKeyDown);

        trig = CreateTrigger();
        TriggerRegisterPlayerKeyEventForAllMetaKeys(trig, p, OSKEY_LCONTROL, false);
        TriggerRegisterPlayerKeyEventForAllMetaKeys(trig, p, OSKEY_RCONTROL, false);
        TriggerAddAction(trig, TrigToggleKeyUp);

        trig = CreateTrigger();
        TriggerRegisterPlayerKeyEventForAllMetaKeys(trig, p, OSKEY_LSHIFT, true);
        TriggerRegisterPlayerKeyEventForAllMetaKeys(trig, p, OSKEY_RSHIFT, true);
        TriggerAddAction(trig, function()
            if not MagiCam.isShiftDown then
                startDragMouseX = mouseX;
                startDragMouseY = mouseY;
            end

            MagiCam.isShiftDown = true;
        end);

        trig = CreateTrigger();
        TriggerRegisterPlayerKeyEventForAllMetaKeys(trig, p, OSKEY_LSHIFT, false);
        TriggerRegisterPlayerKeyEventForAllMetaKeys(trig, p, OSKEY_RSHIFT, false);
        TriggerAddAction(trig, function()
            if MagiCam.isShiftDown then
                startDragMouseX = mouseX;
                startDragMouseY = mouseY;
            end

            MagiCam.isShiftDown = false;
        end);

        trig = CreateTrigger();
        TriggerRegisterPlayerKeyEventForAllMetaKeys(trig, p, OSKEY_SPACE, true, { 2, 2|1, 2|4, 2|8 });
        TriggerAddAction(trig, function()
            MagiCam.isSpaceBarDown = true;
        end);

        trig = CreateTrigger();
        TriggerRegisterPlayerKeyEventForAllMetaKeys(trig, p, OSKEY_SPACE, false);
        TriggerAddAction(trig, function()
            MagiCam.isSpaceBarDown = false;
        end);
    end

    function MagiCam.Init(debugEnabled)
        MagiCam.debugMode = debugEnabled == nil and false or debugEnabled;

        if not MagiMouse then
            print('|cffff5500ERROR:MagiCam.Init!', 'MagiMouse system is missing! Aborting MagiCam.Init...|r');
            return false;
        end

        MagiMouse.Init(debugEnabled);
        if not MagiMouse.isInit then
            print('|cffff5500ERROR:MagiCam.Init!', 'MagiMouse system failed to initialize! Aborting MagiCam.Init...|r');
            return false;
        end

        InitLocationStuff();

        MagiCam.holderOffsetX = 0;
        MagiCam.holderOffsetY = 0;

        UpdateViewAxes();

        MagiCam.SetFieldsDefaultValuesToCurrent();

        InitFrameStuff();
        InitLocalTriggers();

        mainTimer = CreateTimer();
        TimerStart(mainTimer, MAIN_TICK_DUR, true, MainTimerTick);

        --SetCameraField(CAMERA_FIELD_FARZ, 65000.0, 0);

        MagiCam.isEnabled = true;
        MagiCam.isInit = true;
        return true;
    end
end

if Debug and Debug.endFile then Debug.endFile() end
