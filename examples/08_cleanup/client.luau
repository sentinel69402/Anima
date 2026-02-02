--[[
    Example: Clean Up Anima, Blend Controllers & State Machine

    This example demonstrates how to clean up the objects after they
    are no longer being used to prevent memory leaks.
    
    Unlike BlendControllers, State Machines are not stored inside Anima
    objects, so you will need to call their :Destroy() function manually.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Anima = require(ReplicatedStorage.Shared.Anima)

--[[
    Get local dependencies and character references
]]
local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local humanoid = character:WaitForChild("Humanoid") :: Humanoid
local anims = ReplicatedStorage:WaitForChild("Anims")

--[[
    Initialize Anima
    We disable the default 'Animate' script to manage all locomotion ourselves.
]]
local anima = Anima.new(anims, player, false, true)

--[[
    Define the State Machine & create a State and BlendController for basic movement.
    For a proper implementation of this, look at example 05_state_plus_blend.
]]
local SM = anima:CreateStateMachine({
    initial = "Locomotion",
    context = {}
})

SM:AddState("Locomotion", {})

anima:CreateBlendController("Locomotion", {
    nodes = {
        { name = "Idle", min = 0, max = 1 },
        { name = "Run", min = 0, max = 16 }
    }
})

--[[
    Clean up the objects.

    Since BlendControllers are stored inside the Anima object, they are
    cleaned up alongside the main object when you call `anima:Destroy()`.

    Since StateMachines are independent from the Anima object, you will
    have to call `StateMachine:Destroy()` manually when destroying one.
]]
print(anima) --> Anima
print(SM) --> StateMachine

anima:Destroy()
SM:Destroy()

print(anima) --> {}
print(SM) --> {}
