if Debug and Debug.beginFile then Debug.beginFile('MagiMouse') end
--[[

MagiMouse v1.1

A mouse cursor tracking system for WC3!

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
-- | MagiMouse v1.1 | --
---+------------------------------------+---

--> by ModdieMads https://www.hiveworkshop.com/members/moddiemads.310879/

+---------------------------------------------------------------------------------------------------------------------+
|                                                                                                                     |
| Provides mouse screen coordinates with precision, elegance and asynchronicity!                                      |
|                                                                                                                     |
| FEATURES:                                                                                                           |
| :: Asynchronous, zero-latency tracking of the mouse cursor! What more can you want??                                |
|                                                                                                                     |
+---------------------------------------------------------------------------------------------------------------------+

Special thanks to:
    - #modding channel on the HiveWorkshop Discord. The best part of modding WC3!
    - @Antares, for the help in pushing this to the above and beyond
    - @Tasyen, for the herculean job of writing The Big UI-Frame Tutorial.
    - @Water, for the support while we're trying to push WC3 to its limits.
    - @Eikonium, for providing the DebugUtils and the IngameConsole.
    - @Vinz, for the crosshair texture!

+-------------------------------------------------------------------------------------------------------------------------------------------------+
| Installation:                                                                                                                                   |
|                                                                                                                                                 |
|   1. Copy the MagiMouse.toc and MagiMouse.fdf files to the war3MapImported folder of your map.                                                  |
|   2. Copy the MagiMouse script into the Trigger Editor.                                                                                         |
|   3. Call MagiMouse.Init() in a trigger with the "Elapsed game time is 0.01 seconds" event.                                                     |
|                                                                                                                                                 |
+-------------------------------------------------------------------------------------------------------------------------------------------------+

* ------------------
* |      API       |
* ------------------
*
*    MagiMouse.Init(debugEnabled, startFrameX, startFrameY) <returns nil>
*        - Initialization function. Required to make the system operational.
*        - Args ->
*             - debugEnabled: Enables the system to initialize with the Debug mode enabled.
*             - startFrameX, startFrameY: Sets the mouse to these coordinates after initialization.
*
*    MagiMouse.SetEnable(enabled, newFrameX, newFrameY) <returns nil>
*        - Sets the status of the system. Disabling it will stop the tracking.
*        - [OPTIONAL]newFrameX, newFrameY: Sets the mouse position to these coordinates upon enabling the system.
*
*    MagiMouse.FrameXY2SaneXY(frameX, frameY) <returns real, real>
*        - Converts coordinates in frame-space to sane-space.
*        - Frame-Space: Center of the screen = {0.4,0.3}
*        - Sane-Space: Top-Left of the screen = {0.0,0.0}, Bottom-Right of the screen = {1.0,1.0}
*
*    MagiMouse.isInit <read-only, boolean>
*        - Retrieves the Init status of the system.
*
*    MagiMouse.debugMode <read-only, boolean>
*        - Retrieves the Debug Mode status of the system.
*
*    MagiMouse.isEnabled <read-only, boolean>
*        - Retrieves the Enable status of the system.
*
*    MagiMouse.mouseFrameX, MagiMouse.mouseFrameY <read-only, real>
*        - Retrieves the frame-space coordinates of the mouse cursor.
*        - Center of the screen = {0.4,0.3}
*
*    MagiMouse.mouseSaneX, MagiMouse.mouseSaneY <read-only, real>
*        - Retrieves the sane-space coordinates of the mouse cursor.
*        - Top-Left of the screen = {0.0,0.0}, Bottom-Right of the screen = {1.0,1.0}
*
]]

do
    MagiMouse = {
        isInit = false,
        debugMode = false,
        isEnabled = false,

        mouseFrameX = 0.0,
        mouseFrameY = 0.0,

        mouseSaneX = 0.0,
        mouseSaneY = 0.0,
    };

    local mainTick = 0;

    local TRACKER_ERROR_LIMIT = .5;

    local baseTileSize = .001;

    local trackerTilesGaps = { 3, 3, 3, 1, 1, 1, 1 };
    local trackerTilesClms = { 9, 9, 7, 3, 3, 3, 3 };
    local trackerTilesSizes = { baseTileSize,
        3.0 * baseTileSize,
        3.0 * 3.0 * baseTileSize,
        7.0 * 3.0 * 3.0 * baseTileSize,
        3.0 * 7.0 * 3.0 * 3.0 * baseTileSize,
        3.0 * 3.0 * 7.0 * 3.0 * 3.0 * baseTileSize,
        3.0 * 3.0 * 7.0 * 3.0 * 3.0 * 3.0 * baseTileSize
    };

    local TRACKER_LEVELS = #trackerTilesGaps;

    local trackerTilesButtons = {};
    local trackerTilesTooltips = {};
    local trackerTilesN = 0;

    local trackerRawX = 0.0;
    local trackerRawY = 0.0;

    local trackerFailedCount = 0;
    local trackerFlickerTick = 0;

    local demoMouseTargetFrame = nil;

    local demoMouseTextFrame = nil;
    local demoMouseTextFrameX, demoMouseTextFrameY, demoMouseTargetFrameX, demoMouseTargetFrameY;

    local screenWid;
    local screenHei;
    local screenAspectRatio;

    local mainTimer;

    local function Lerp(v0, v1, t)
        return v0 + (v1 - v0) * t;
    end

    local function Clamp(v, v0, v1)
        return v < v0 and v0 or (v > v1 and v1 or v);
    end

    local function Sign(val)
        return val < 0 and -1 or 1;
    end

    local function MoveTracker(x, y)
        local testX = 1.666667 * (x + .3 * screenAspectRatio) / screenAspectRatio;
        local testY = (1.0 - 1.666667 * (y + .3));

        if testX > (1.0 + TRACKER_ERROR_LIMIT) or testY > (1.0 + TRACKER_ERROR_LIMIT) or
            testX < -TRACKER_ERROR_LIMIT or testY < -TRACKER_ERROR_LIMIT then
            return MoveTracker(0.0, 0.0);
        end

        trackerRawX = x;
        trackerRawY = y;


        local curSize, curGap, gapInd0, gapInd1, curClms, clmCenter, ind;

        ind = 0;
        for lvl = 1, TRACKER_LEVELS do
            curSize = trackerTilesSizes[lvl];
            curGap = trackerTilesGaps[lvl];
            curClms = trackerTilesClms[lvl];

            clmCenter = curClms >> 1;
            gapInd0 = (curClms - curGap) >> 1;
            gapInd1 = curClms - gapInd0;

            for i = 0, curClms - 1 do
                for i2 = 0, curClms - 1 do
                    if not (i >= gapInd0 and i < gapInd1 and i2 >= gapInd0 and i2 < gapInd1) then
                        ind = ind + 1;

                        BlzFrameSetAbsPoint(
                            trackerTilesButtons[ind], FRAMEPOINT_CENTER,
                            trackerRawX + .4 + curSize * (i2 - clmCenter),
                            trackerRawY + .3 - curSize * (i - clmCenter)
                        );
                    end
                end
            end
        end
    end

    local function SetTrackerVisible(val)
        for i = 1, trackerTilesN do
            BlzFrameSetVisible(trackerTilesButtons[i], val);
        end
    end

    local function UpdateTracker()
        local curSize, curGap, gapInd0, gapInd1, curClms, clmCenter, ind;

        ind = 0;
        for lvl = 1, TRACKER_LEVELS do
            curSize = trackerTilesSizes[lvl];
            curGap = trackerTilesGaps[lvl];
            curClms = trackerTilesClms[lvl];

            clmCenter = curClms >> 1;
            gapInd0 = (curClms - curGap) >> 1;
            gapInd1 = curClms - gapInd0;

            for i = 0, curClms - 1 do
                for i2 = 0, curClms - 1 do
                    if not (i >= gapInd0 and i < gapInd1 and i2 >= gapInd0 and i2 < gapInd1) then
                        ind = ind + 1;

                        if BlzFrameIsVisible(trackerTilesTooltips[ind]) then
                            SetTrackerVisible(false);

                            trackerFlickerTick = mainTick + 26;

                            MoveTracker(
                                trackerRawX + curSize * (i2 - clmCenter),
                                trackerRawY - curSize * (i - clmCenter)
                            );
                            return true;
                        end
                    end
                end
            end
        end

        return false;
    end

    local function CreateTrackerButton(size)
        local button = BlzCreateSimpleFrame('MagiMouseTile', BlzGetOriginFrame(ORIGIN_FRAME_SIMPLE_UI_PARENT, 0), 0);

        BlzFrameSetLevel(button, 8);
        BlzFrameSetSize(button, size, size);

        return button;
    end

    local function CreateTrackerTooltip(button)
        local tooltip = BlzCreateFrameByType('SIMPLEFRAME', '', button, '', 0);

        BlzFrameSetTooltip(button, tooltip);
        BlzFrameSetEnable(tooltip, false);
        BlzFrameSetVisible(tooltip, false);

        return tooltip;
    end


    local function CreateTracker()
        local button, curSize, curGap, gapInd0, gapInd1, curClms, ind;

        ind = 0;
        for lvl = 1, TRACKER_LEVELS do
            curSize = trackerTilesSizes[lvl];
            curGap = trackerTilesGaps[lvl];
            curClms = trackerTilesClms[lvl];

            gapInd0 = (curClms - curGap) >> 1;
            gapInd1 = curClms - gapInd0;

            for i = 0, curClms - 1 do
                for i2 = 0, curClms - 1 do
                    if not (i >= gapInd0 and i < gapInd1 and i2 >= gapInd0 and i2 < gapInd1) then
                        button = CreateTrackerButton(curSize);

                        ind = ind + 1;
                        trackerTilesButtons[ind] = button;
                        trackerTilesTooltips[ind] = CreateTrackerTooltip(button);
                    end
                end
            end
        end

        trackerTilesN = ind;
        MoveTracker(0.0, 0.0);
    end

    function MagiMouse.InitDemo()
        demoMouseTargetFrameX = .4;
        demoMouseTargetFrameY = .3;
        demoMouseTargetFrame = BlzCreateFrameByType('BACKDROP', '', BlzGetFrameByName('ConsoleUIBackdrop', 0), '', 0);
        BlzFrameSetTexture(demoMouseTargetFrame, 'war3mapImported\\CrossHairSelectionSmall', 0, true);
        BlzFrameSetAbsPoint(demoMouseTargetFrame, FRAMEPOINT_CENTER, demoMouseTargetFrameX, demoMouseTargetFrameY);
        BlzFrameSetEnable(demoMouseTargetFrame, false);
        BlzFrameSetSize(demoMouseTargetFrame, 0.04, 0.04);

        demoMouseTextFrameX = .4;
        demoMouseTextFrameY = .3;
        demoMouseTextFrame = BlzCreateFrameByType('TEXT', '', BlzGetFrameByName('ConsoleUIBackdrop', 0), '', 0);
        BlzFrameSetText(demoMouseTextFrame, '');
        BlzFrameSetAbsPoint(demoMouseTextFrame, FRAMEPOINT_CENTER, demoMouseTextFrameX, demoMouseTextFrameY);
        BlzFrameSetEnable(demoMouseTextFrame, false);
        BlzFrameSetScale(demoMouseTextFrame, 2);


        MagiMouse.InitDemo = DoNothing;
    end

    function MagiMouse.SetDemoVisible(val)
        BlzFrameSetVisible(demoMouseTargetFrame, val);
        BlzFrameSetVisible(demoMouseTextFrame, val);
    end

    local function UpdateDemoGraphics()
        BlzFrameSetText(
            demoMouseTextFrame,
            table.concat({
                R2S(MagiMouse.mouseFrameX), ' , ', R2S(MagiMouse.mouseFrameY),
                '|n|cffdddddd', R2S(MagiMouse.mouseSaneX), ' , ', R2S(MagiMouse.mouseSaneY), '|r'
            })
        );

        demoMouseTextFrameX = Lerp(demoMouseTextFrameX,
            MagiMouse.mouseFrameX + (MagiMouse.mouseSaneX < .9 and .09 or -.09), .5);
        demoMouseTextFrameY = Lerp(demoMouseTextFrameY,
            MagiMouse.mouseFrameY + (MagiMouse.mouseSaneY > .1 and .03 or -.05), .5);

        BlzFrameSetAbsPoint(demoMouseTextFrame, FRAMEPOINT_CENTER, demoMouseTextFrameX, demoMouseTextFrameY);
        BlzFrameSetAbsPoint(demoMouseTargetFrame, FRAMEPOINT_CENTER, MagiMouse.mouseFrameX, MagiMouse.mouseFrameY);
    end

    local function UpdateScreenVars()
        screenWid = BlzGetLocalClientWidth();
        screenWid = screenWid > 0 and screenWid or 1;

        screenHei = BlzGetLocalClientHeight();
        screenHei = screenHei > 0 and screenHei or 1;

        screenAspectRatio = screenWid / screenHei;
    end

    local function MainTimerTick()
        mainTick = mainTick + 1;

        if not MagiMouse.isEnabled then return end;

        if mainTick == trackerFlickerTick then
            SetTrackerVisible(true);
        end

        if (mainTick & 511) == 1 then
            if BlzGetLocalClientWidth() ~= screenWid then
                MoveTracker(0, 0);
                SetTrackerVisible(true);
                trackerFlickerTick = mainTick;
                trackerFailedCount = 0;
            end

            UpdateScreenVars();
        end

        if trackerFlickerTick <= mainTick and (trackerFailedCount < 8 or (mainTick & 15) == 1) then
            if UpdateTracker() then
                trackerFailedCount = 0;
            else
                trackerFailedCount = trackerFailedCount + 1;
            end

            MagiMouse.mouseSaneX = Lerp(MagiMouse.mouseSaneX,
                1.666667 * (trackerRawX + .3 * screenAspectRatio) / screenAspectRatio, .5);
            MagiMouse.mouseSaneY = Lerp(MagiMouse.mouseSaneY, (1.0 - 1.666667 * (trackerRawY + .3)), .5);

            MagiMouse.mouseFrameX = Lerp(MagiMouse.mouseFrameX, trackerRawX + .4, .7);
            MagiMouse.mouseFrameY = Lerp(MagiMouse.mouseFrameY, trackerRawY + .3, .7);
        end

        if demoMouseTargetFrame and (mainTick & 15) == 1 then
            UpdateDemoGraphics()
        end
    end

    function MagiMouse.FrameXY2SaneXY(frameX, frameY)
        return 1.666667 * ((frameX - .4) + .3 * screenAspectRatio) / screenAspectRatio, (1.0 - 1.666667 * frameY);
    end

    function MagiMouse.SetEnable(enabled, newFrameX, newFrameY)
        if enabled then
            UpdateScreenVars();

            if newFrameX or newFrameY then
                newFrameX = newFrameX or .4;
                newFrameY = newFrameY or .3;

                local newX, newY = MagiMouse.FrameXY2SaneXY(newFrameX, newFrameY);

                BlzSetMousePos(math.floor(newX * screenWid), math.floor(newY * screenHei));

                MoveTracker(newFrameX - .4, newFrameY - .3);
            end

            SetTrackerVisible(true);

            if MagiMouse.debugMode and demoMouseTargetFrame then
                MagiMouse.SetDemoVisible(true);
            end
        else
            SetTrackerVisible(false);

            if demoMouseTargetFrame then
                MagiMouse.SetDemoVisible(false);
            end
        end

        MagiMouse.isEnabled = enabled;
    end

    function MagiMouse.Init(debugEnabled, startFrameX, startFrameY)
        MagiMouse.debugMode = debugEnabled == nil and false or debugEnabled;

        if not BlzLoadTOCFile('war3mapImported\\MagiMouse.toc') then
            if MagiMouse.debugMode then
                print('|cffff5500ERROR:MagiMouse.Init!',
                    'Error loading MagiMouse.toc. Please check war3mapImported\\MagiMouse.toc is a valid file.|r');
            end
            return false;
        end

        UpdateScreenVars();

        CreateTracker();

        if MagiMouse.debugMode then
            print("|cff66ddffMagiMouse, the Async Mouse Screen Tracker by|r |cffffdd00@ModdieMads!|r");
            print("|cffffcc22This project is hosted on HiveWorkshop! Find me there!|r");
            print("|cffffcc00If you use, build upon or modify this system,|r |cff9999ffplease give me credit!|r");

            MagiMouse.InitDemo();
        end

        MagiMouse.isEnabled = true;
        MagiMouse.isInit = true;

        local saneX, saneY = MagiMouse.FrameXY2SaneXY(startFrameX or 0.4, startFrameY or 0.3);

        BlzSetMousePos(saneX and math.floor(saneX * screenWid) or screenWid >> 1,
            saneY and math.floor(saneY * screenHei) or screenHei >> 1);
        mainTimer = CreateTimer();
        TimerStart(mainTimer, .001, true, MainTimerTick);

        MagiMouse.Init = DoNothing;

        return true;
    end
end

if Debug and Debug.endFile then Debug.endFile() end
