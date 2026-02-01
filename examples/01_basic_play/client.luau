--[[
    Example: Basic Animation Playback
    This script demonstrates the fundamental workflow for using Anima:
    instantiation, configuration, and playback control.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Anima = require(ReplicatedStorage.Shared.Anima)

--[[
    Get local dependencies
]]
local player = Players.LocalPlayer
local anims = ReplicatedStorage:WaitForChild("Anims")

--[[
    Initialize Anima
    The .new() constructor automatically loads and caches animations from the provided folder.
]]
local anima = Anima.new(anims, player)

--[[
    Listen for animation starts
    The signal now provides (name, player, character)
]]
anima:getPlaySignal():Connect(function(name, player, character)
    local identity = player and player.Name or character.Name
    print(`{identity} started playing: {name}`)
end)

--[[
    Configure playback parameters
    Setting 'loop' to true will make the animation repeat until stopped.
]]
local config: Anima.config = {
    loop = true
}

--[[
    Start playing the animation
    'Idle' must exist as an Animation object within the 'anims' folder.
]]
anima:PlayAnimation("Idle", config)

--[[
    Stop the animation after 3 seconds with a 0.2s fade-out
]]
task.wait(3)

anima:StopAnimation("Idle", 0.2)
