if Debug then Debug.beginFile "Main" end
OnInit.root(function(require)
end)
OnInit.config(function(require)
end)
OnInit.main(function(require)
end)
OnInit.global(function(require)
end)
OnInit.trig(function(require)
end)
OnInit.map(function(require)
    require "MissileSystem"
    require "Tilesets"
    require "TableBuilder"
    require "DummyRecycler"
end)
OnInit.final(function(require)
    require "ChatSystem"
end)
if Debug then Debug.endFile() end
