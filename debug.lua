getfile = require -- require is later replaced by TotalInit
package.path = "?.lua" -- '/var/mnt/ssd/projects/warcraft 3/Workbench/?.lua;/var/mnt/ssd/projects/warcraft 3/Workbench/?.lua'
table.insert(package.searchers, function(module_name)
    local path, err = package.searchpath(module_name, package.path, "/")
    if path then
        return assert(loadfile(path))
    end
    return err
end)

--getfile "/var/mnt/ssd/projects/warcraft 3/Declarations/hiddennatives.1.33.0"
--getfile "/var/mnt/ssd/projects/warcraft 3/Declarations/common.1.33.0"
getfile "wc3-stubs"
getfile "/var/mnt/ssd/projects/warcraft 3/Declarations/blizzard.1.33.0"
getfile "map/src/Core/DebugUtils/DebugUtils"
getfile "map/src/Core/DebugUtils/IngameConsole"
getfile "map/src/Core/Lua-Infused GUI/LuaInfusedGUI2"
getfile "map/src/Test/LIGUI/GroupTest"