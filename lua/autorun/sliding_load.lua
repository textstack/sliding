if engine.ActiveGamemode() == "eldelim" then return end

AddCSLuaFile("sliding/cl_sliding.lua")
AddCSLuaFile("sliding/sh_sliding.lua")

EE = EE or {}

include("sliding/sh_sliding.lua")

if CLIENT then
    include("sliding/cl_sliding.lua")
end