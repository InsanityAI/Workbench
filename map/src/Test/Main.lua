if Debug then Debug.beginFile "Main" end
OnInit.final("Main", function (require)
    require "ReactiveX"
    require "TimerQueue"
    require "TaskProcessor"
    require "MissileSystem"
    require "json"
    require "Tilesets"
    require "TableBuilder"
    require "DummyRecycler"
end)
if Debug then Debug.endFile() end