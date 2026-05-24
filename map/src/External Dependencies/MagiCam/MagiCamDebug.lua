if Debug and Debug.beginFile then Debug.beginFile('MagiCamDebug') end
--[[

MagiCamDebug v1.2

A collection of debug utilities for the MagiCam system!

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

do
    MagiCamDebug = {};

    local RAD2DEG = 57.29577951308232;

    local camEngagedWarningTextFrames = {};
    local camLockTextFrame, camControlsHintFrame;
    local debugBoard, resetButton, lockButton;
    local curSelUnit;

    local function UpdateDebugBoard()
        local row = 1;
        MultiboardSetItemValueBJ(debugBoard, 2, row, R2S(RAD2DEG * MagiCam.fov));

        row = row + 1;
        MultiboardSetItemValueBJ(debugBoard, 2, row, R2S(RAD2DEG * MagiCam.rotation));

        row = row + 1;
        MultiboardSetItemValueBJ(debugBoard, 2, row, R2S(RAD2DEG * MagiCam.roll));

        row = row + 1;
        MultiboardSetItemValueBJ(debugBoard, 2, row, R2S(RAD2DEG * MagiCam.aoa));

        row = row + 1;
        MultiboardSetItemValueBJ(debugBoard, 2, row, R2S(MagiCam.eyeX));

        row = row + 1;
        MultiboardSetItemValueBJ(debugBoard, 2, row, R2S(MagiCam.eyeY));

        row = row + 1;
        MultiboardSetItemValueBJ(debugBoard, 2, row, R2S(MagiCam.eyeZ));

        row = row + 1;
        MultiboardSetItemValueBJ(debugBoard, 2, row, R2S(MagiCam.targetX));

        row = row + 1;
        MultiboardSetItemValueBJ(debugBoard, 2, row, R2S(MagiCam.targetY));

        row = row + 1;
        MultiboardSetItemValueBJ(debugBoard, 2, row, R2S(MagiCam.targetZ));

        row = row + 1;
        MultiboardSetItemValueBJ(debugBoard, 2, row, R2S(MagiCam.targetDist));

        row = row + 1;
        MultiboardSetItemValueBJ(debugBoard, 2, row, R2S(MagiCam.zOffset));

        row = row + 1;
        MultiboardSetItemValueBJ(debugBoard, 2, row, R2S(RAD2DEG * MagiCam.localYaw));

        row = row + 1;
        MultiboardSetItemValueBJ(debugBoard, 2, row, R2S(RAD2DEG * MagiCam.localPitch));

        row = row + 1;
        MultiboardSetItemValueBJ(debugBoard, 2, row, R2S(RAD2DEG * MagiCam.localRoll));

        MultiboardDisplay(debugBoard, true);
    end

    local lastCamHolder;
    local function DebugTick()
        if MagiCam.isToggleKeyDown and not BlzFrameIsVisible(camEngagedWarningTextFrames[1]) then
            for _, v in ipairs(camEngagedWarningTextFrames) do
                BlzFrameSetVisible(v, true);
            end
            BlzFrameSetVisible(camControlsHintFrame, false);
        elseif not MagiCam.isToggleKeyDown and BlzFrameIsVisible(camEngagedWarningTextFrames[1]) then
            for _, v in ipairs(camEngagedWarningTextFrames) do
                BlzFrameSetVisible(v, false);
            end
            BlzFrameSetVisible(camControlsHintFrame, true);
        end

        if MagiCam.camHolder and GetUnitTypeId(MagiCam.camHolder) ~= 0 then
            if lastCamHolder ~= MagiCam.camHolder then
                BlzFrameSetText(camLockTextFrame, '|cffffaa00<< Cam Locked to ' ..
                GetUnitName(MagiCam.camHolder) .. ' >>|r');
                lastCamHolder = MagiCam.camHolder;
            end
            BlzFrameSetVisible(camLockTextFrame, true);
        elseif BlzFrameIsVisible(camLockTextFrame) then
            BlzFrameSetVisible(camLockTextFrame, false);
            lastCamHolder = nil;
        end

        UpdateDebugBoard();

        if not BlzFrameIsVisible(resetButton) then
            BlzFrameSetVisible(resetButton, true);
        end
    end

    local function CreateTextFrames()
        camControlsHintFrame = BlzCreateFrameByType('TEXT', '', BlzGetFrameByName('ConsoleUIBackdrop', 0), '', 0);
        BlzFrameSetText(camControlsHintFrame, '|cffffff00!! HOLD down CTRL to activate the cam controls !!|r');
        BlzFrameSetAbsPoint(camControlsHintFrame, FRAMEPOINT_CENTER, .4, .22);
        BlzFrameSetEnable(camControlsHintFrame, false);
        BlzFrameSetScale(camControlsHintFrame, 2);

        local frameY = .27;

        camLockTextFrame = BlzCreateFrameByType('TEXT', '', BlzGetFrameByName('ConsoleUIBackdrop', 0), '', 0);
        BlzFrameSetText(camLockTextFrame, '');
        BlzFrameSetAbsPoint(camLockTextFrame, FRAMEPOINT_CENTER, .4, frameY);
        BlzFrameSetScale(camLockTextFrame, 1.5);
        BlzFrameSetEnable(camLockTextFrame, false);

        frameY = frameY - .02;
        local ind = 1;
        camEngagedWarningTextFrames[ind] = BlzCreateFrameByType('TEXT', '', BlzGetFrameByName('ConsoleUIBackdrop', 0), '',
            0);
        BlzFrameSetText(camEngagedWarningTextFrames[ind], '|cffffcc00<< Camera Controls ENGAGED! >>|r');
        BlzFrameSetAbsPoint(camEngagedWarningTextFrames[ind], FRAMEPOINT_CENTER, .4, frameY);
        BlzFrameSetEnable(camEngagedWarningTextFrames[ind], false);
        BlzFrameSetScale(camEngagedWarningTextFrames[ind], 2);
        BlzFrameSetVisible(camEngagedWarningTextFrames[ind], false);

        ind = ind + 1;
        frameY = frameY - .02;
        camEngagedWarningTextFrames[ind] = BlzCreateFrameByType('TEXT', '', BlzGetFrameByName('ConsoleUIBackdrop', 0), '',
            0);
        BlzFrameSetText(camEngagedWarningTextFrames[ind],
            'LEFT-Click + Drag:|r |cffffcc00Orbit Camera Target|r'
        );
        BlzFrameSetAbsPoint(camEngagedWarningTextFrames[ind], FRAMEPOINT_CENTER, .4, frameY);
        BlzFrameSetEnable(camEngagedWarningTextFrames[ind], false);
        BlzFrameSetScale(camEngagedWarningTextFrames[ind], 1.3);
        BlzFrameSetVisible(camEngagedWarningTextFrames[ind], false);

        ind = ind + 1;
        frameY = frameY - .02;
        camEngagedWarningTextFrames[ind] = BlzCreateFrameByType('TEXT', '', BlzGetFrameByName('ConsoleUIBackdrop', 0), '',
            0);
        BlzFrameSetText(camEngagedWarningTextFrames[ind],
            'RIGHT-Click + Drag: |cffffcc00Pan XY|r'
        );
        BlzFrameSetAbsPoint(camEngagedWarningTextFrames[ind], FRAMEPOINT_CENTER, .4, frameY);
        BlzFrameSetEnable(camEngagedWarningTextFrames[ind], false);
        BlzFrameSetScale(camEngagedWarningTextFrames[ind], 1.3);
        BlzFrameSetVisible(camEngagedWarningTextFrames[ind], false);

        ind = ind + 1;
        frameY = frameY - .02;
        camEngagedWarningTextFrames[ind] = BlzCreateFrameByType('TEXT', '', BlzGetFrameByName('ConsoleUIBackdrop', 0), '',
            0);
        BlzFrameSetText(camEngagedWarningTextFrames[ind],
            '|cff00ffffWHEEL|r-Scroll: |cffffcc00Zoom|r'
        );
        BlzFrameSetAbsPoint(camEngagedWarningTextFrames[ind], FRAMEPOINT_CENTER, .4, frameY);
        BlzFrameSetEnable(camEngagedWarningTextFrames[ind], false);
        BlzFrameSetScale(camEngagedWarningTextFrames[ind], 1.3);
        BlzFrameSetVisible(camEngagedWarningTextFrames[ind], false);

        ind = ind + 1;
        frameY = frameY - .02;
        camEngagedWarningTextFrames[ind] = BlzCreateFrameByType('TEXT', '', BlzGetFrameByName('ConsoleUIBackdrop', 0), '',
            0);
        BlzFrameSetText(camEngagedWarningTextFrames[ind],
            '|cff66ff66SHIFT|r + LEFT-Click + Drag: |cffffcc00Rotate Yaw and Pitch|r'
        );
        BlzFrameSetAbsPoint(camEngagedWarningTextFrames[ind], FRAMEPOINT_CENTER, .4, frameY);
        BlzFrameSetEnable(camEngagedWarningTextFrames[ind], false);
        BlzFrameSetScale(camEngagedWarningTextFrames[ind], 1.3);
        BlzFrameSetVisible(camEngagedWarningTextFrames[ind], false);

        ind = ind + 1;
        frameY = frameY - .02;
        camEngagedWarningTextFrames[ind] = BlzCreateFrameByType('TEXT', '', BlzGetFrameByName('ConsoleUIBackdrop', 0), '',
            0);
        BlzFrameSetText(camEngagedWarningTextFrames[ind],
            '|cffffaa00HOLD|r Space-Bar: |cffffcc00Increase / |r|cff66ff66[SHIFT]|r|cffffcc00Decrease Camera Z|r'
        );
        BlzFrameSetAbsPoint(camEngagedWarningTextFrames[ind], FRAMEPOINT_CENTER, .4, frameY);
        BlzFrameSetEnable(camEngagedWarningTextFrames[ind], false);
        BlzFrameSetScale(camEngagedWarningTextFrames[ind], 1.3);
        BlzFrameSetVisible(camEngagedWarningTextFrames[ind], false);
    end

    local function CreateDebugBoard()
        debugBoard = CreateMultiboard();
        MultiboardSetItemsWidth(debugBoard, .1);
        MultiboardSetItemsStyle(debugBoard, true, false);

        MultiboardSetRowCount(debugBoard, 15);
        MultiboardSetColumnCount(debugBoard, 2);
        MultiboardSetTitleText(debugBoard, 'Camera Fields');

        local row = 1;
        MultiboardSetItemValueBJ(debugBoard, 1, row, 'Field of View');

        row = row + 1;
        MultiboardSetItemValueBJ(debugBoard, 1, row, 'Rotation');

        row = row + 1;
        MultiboardSetItemValueBJ(debugBoard, 1, row, 'Roll');

        row = row + 1;
        MultiboardSetItemValueBJ(debugBoard, 1, row, 'Angle of Attack');

        row = row + 1;
        MultiboardSetItemValueBJ(debugBoard, 1, row, 'Cam Eye X');

        row = row + 1;
        MultiboardSetItemValueBJ(debugBoard, 1, row, 'Cam Eye Y');

        row = row + 1;
        MultiboardSetItemValueBJ(debugBoard, 1, row, 'Cam Eye Z');

        row = row + 1;
        MultiboardSetItemValueBJ(debugBoard, 1, row, 'Cam Target X');

        row = row + 1;
        MultiboardSetItemValueBJ(debugBoard, 1, row, 'Cam Target Y');

        row = row + 1;
        MultiboardSetItemValueBJ(debugBoard, 1, row, 'Cam Target Z');

        row = row + 1;
        MultiboardSetItemValueBJ(debugBoard, 1, row, 'Cam Target Dist');

        row = row + 1;
        MultiboardSetItemValueBJ(debugBoard, 1, row, 'Z Offset');

        row = row + 1;
        MultiboardSetItemValueBJ(debugBoard, 1, row, 'Local Yaw');

        row = row + 1;
        MultiboardSetItemValueBJ(debugBoard, 1, row, 'Local Pitch');

        row = row + 1;
        MultiboardSetItemValueBJ(debugBoard, 1, row, 'Local Roll');

        UpdateDebugBoard();

        MultiboardDisplay(debugBoard, true);
    end

    local function CreateButtons()
        resetButton = BlzCreateFrameByType("GLUETEXTBUTTON", '', BlzGetFrameByName('ConsoleUIBackdrop', 0),
            "ScriptDialogButton", 0);
        BlzFrameSetLevel(resetButton, 8);
        BlzFrameSetAbsPoint(resetButton, FRAMEPOINT_CENTER, 0.86, 0.3);

        BlzFrameSetText(resetButton, 'Reset Camera');

        local trig = CreateTrigger();

        BlzTriggerRegisterFrameEvent(trig, resetButton, FRAMEEVENT_CONTROL_CLICK);

        TriggerAddAction(trig, function()
            MagiCam.ResetFieldsValues();
            BlzFrameSetVisible(resetButton, false);
            print('Resetting camera!');
        end);

        lockButton = BlzCreateFrameByType("GLUETEXTBUTTON", '', BlzGetFrameByName('ConsoleUIBackdrop', 0),
            "ScriptDialogButton", 0);
        BlzFrameSetLevel(lockButton, 8);
        BlzFrameSetAbsPoint(lockButton, FRAMEPOINT_CENTER, 0.86, 0.265);
        BlzFrameSetText(lockButton, 'Lock Camera to Selected Unit');

        local unlockButton = BlzCreateFrameByType("GLUETEXTBUTTON", '', BlzGetFrameByName('ConsoleUIBackdrop', 0),
            "ScriptDialogButton", 0);
        BlzFrameSetLevel(unlockButton, 8);
        BlzFrameSetAbsPoint(unlockButton, FRAMEPOINT_CENTER, 0.86, 0.23);
        BlzFrameSetText(unlockButton, 'Unlock Camera');
        BlzFrameSetVisible(unlockButton, false);

        trig = CreateTrigger()

        BlzTriggerRegisterFrameEvent(trig, lockButton, FRAMEEVENT_CONTROL_CLICK);

        TriggerAddAction(trig, function()
            if curSelUnit and GetUnitTypeId(curSelUnit) ~= 0 then
                MagiCam.SetCamHolder(curSelUnit);
                print('Camera will now follow the unit. You can still rotate and pan the camera!')
                BlzFrameSetVisible(unlockButton, true);
                BlzFrameSetVisible(lockButton, false);
            end
        end);

        trig = CreateTrigger()

        BlzTriggerRegisterFrameEvent(trig, unlockButton, FRAMEEVENT_CONTROL_CLICK);

        TriggerAddAction(trig, function()
            MagiCam.SetCamHolder(nil);
            BlzFrameSetVisible(unlockButton, false);
            BlzFrameSetVisible(lockButton, true);
        end)
    end

    function MagiCamDebug.Init()
        if not MagiCam or not MagiCam.isInit then return end;

        local tim = CreateTimer();
        TimerStart(tim, 0.02, true, DebugTick);

        CreateTextFrames();
        CreateDebugBoard();
        CreateButtons();

        local trig = CreateTrigger();

        TriggerRegisterPlayerUnitEvent(trig, Player(0), EVENT_PLAYER_UNIT_SELECTED, nil);
        TriggerAddAction(trig, function()
            curSelUnit = GetTriggerUnit();
        end);

        local tempGroup = CreateGroup();
        GroupEnumUnitsOfPlayer(tempGroup, Player(0), Filter(function()
            local u = GetFilterUnit();
            if IsUnitSelected(u, Player(0)) then curSelUnit = u end;
            return false;
        end));
        DestroyGroup(tempGroup);
    end
end

if Debug and Debug.endFile then Debug.endFile() end
