if Debug then Debug.beginFile "SoundLib" end
-- credits to Maddeem
OnInit.module("SoundLib", function(require)
    require "TimerQueue"
    require "TableRecycler"

    local soundTimerQueue = TimerQueue:create()

    local SoundPitch = {} ---@type table<sound, number>
    local _AllSounds = {} ---@type Sound[]
    local _3DSounds = {} ---@type Sound3DData[]

    ---@class Sound3DData
    ---@field x number
    ---@field y number
    ---@field sound sound

    ---@class Sound
    ---@field path string
    ---@field pitch number
    ---@field duration number
    ---@field looping boolean
    ---@field is3D boolean
    ---@field outOfRangeStop boolean
    ---@field minDist number
    ---@field maxDist number
    ---@field fadeIn number
    ---@field fadeOut number
    ---@field eaxSetting string
    ---@field volume number
    ---@field instances table
    Sound = {
        path = "",
        pitch = 1,
        duration = 0,
        looping = false,
        is3D = false,
        outOfRangeStop = false,
        minDist = 4000,
        maxDist = 10000,
        fadeIn = 1,
        fadeOut = 1,
        eaxSetting = "DefaultEAXON",
        volume = 127
    }
    Sound.__index = Sound

    ---@param offset_x number
    ---@param offset_y number
    function Sound.move_all(offset_x, offset_y)
        for index, _ in ipairs(_3DSounds) do
            local sound_data = _3DSounds[index]
            sound_data.x = sound_data.x + offset_x
            sound_data.y = sound_data.y + offset_y
            SetSoundPosition(sound_data.sound, sound_data.x, sound_data.y, 0)
        end
    end

    ---@param t Sound
    ---@return Sound
    function Sound:new(t)
        t = setmetatable(t or {}, Sound)
        t.instances = {}
        table.insert(_AllSounds, t)
        return t
    end

    ---@param self Sound
    ---@param sound_data Sound3DData
    local function recycle(self, sound_data)
        table.insert(self.instances, sound_data.sound)
        if sound_data.x then
            table.removeobject(_3DSounds, sound_data)
            sound_data.x = nil
            sound_data.y = nil
        end
        sound_data.sound = nil
        TableRecycler.release(sound_data)
    end

    local function loading(snd, pitch, self, isLocal, x, y, target)
        table.insert(self.instances, snd)
        self(pitch, isLocal, x, y, target)
    end

    function Sound:stop(snd, fade)
        StopSound(snd, false, fade)
        table.insert(self.instances, snd)
    end

    ---@param pitch number
    ---@param isLocal boolean
    ---@param x number
    ---@param y number
    ---@param target unit
    function Sound:__call(pitch, isLocal, x, y, target)
        local pos = #self.instances
        local snd
        if pos == 0 then
            snd = CreateSound(
                self.path,
                self.looping,
                self.is3D,
                self.outOfRangeStop,
                self.fadeIn,
                self.fadeOut,
                self.eaxSetting
            )
            SetSoundVolume(snd, self.volume)
            if self.is3D then
                SetSoundDistances(snd, self.minDist, self.maxDist)
            end
            soundTimerQueue:callDelayed(0.0, loading, snd, pitch, self, isLocal, x, y, target)
        else
            snd = self.instances[pos]
            table.remove(self.instances, pos)
            local data = TableRecycler.create()
            data.sound = snd
            if x ~= nil and y ~= nil then
                SetSoundPosition(snd, x, y, 0)
                data.x = x
                data.y = y
                table.insert(_3DSounds, data)
            elseif target then
                AttachSoundToUnit(snd, target)
            end
            if isLocal == nil or isLocal then
                StartSound(snd)
            end
            if not self.looping then
                soundTimerQueue:callDelayed(self.duration * SoundPitch[snd], recycle, self, data)
            end
        end
        SetPitch(snd, pitch or self.pitch)
        return snd
    end

    ---@param snd sound
    ---@param pitch number
    function SetPitch(snd, pitch)
        if GetSoundIsPlaying(snd) or GetSoundIsLoading(snd) then
            local last = SoundPitch[snd] or 1
            SetSoundPitch(snd, 1 / last)
            SetSoundPitch(snd, pitch)
        elseif pitch == 1 then
            SetSoundPitch(snd, 1.0001)
            pitch = 1.0001
        else
            SetSoundPitch(snd, pitch)
        end
        SoundPitch[snd] = pitch
    end
end)
if Debug then Debug.endFile() end