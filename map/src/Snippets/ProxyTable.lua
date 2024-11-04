if Debug then Debug.beginFile "ProxyTable" end
OnInit.module("ProxyTable", function()
    function ProxyTable(table)
        return setmetatable({}, {
            __index = function(t, k)
                return table[k]
            end,
            __name = table.__name -- mimic class or smth, idk
        })
    end
end)
if Debug then Debug.endFile() end