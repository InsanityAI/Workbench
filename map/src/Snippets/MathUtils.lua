do
    --[[
        from https://stackoverflow.com/a/65552089 Credits Jonathan Cohler 
        (Dunno what's CristiFati's problem)
    ]]
    function bits() return 1<<32==0 and 32 or 1<<64==0 and 64 end

    --[[
        From https://stackoverflow.com/a/58411671 credits to Pedro Gimeno
    ]]
    local ofs = 2 ^ (bits() == 64 and 52 or 23)

    ---@param num number
    ---@return integer
    math.round = function(num)
        if math.abs(num) > ofs then
            return num
        end
        return num < 0 and num - ofs + ofs or num + ofs - ofs
    end

    ---@param num number 
    ---@param lowbound number
    ---@param highbound number 
    ---@return number relativeNum
    math.mapToBounds = function(num, lowbound, highbound)
        return (highbound - lowbound) * num + lowbound
    end

    ---@param low number
    ---@param high number
    ---@return number center
    math.center = function(low, high)
        return (high + low) * 0.5
    end
end
