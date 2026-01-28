--[[
    Example: 1D Blend Locomotion
    This example demonstrates how to use the Blend Controller for seamless
    interpolation between multiple animations (e.g., Idle to Run) based on speed.
    
    1D Blending is ideal for movement systems where you want a smooth transition
    between states without the jarring "snap" of switching animations instantly.
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
    We disable the default Roblox 'Animate' script to manage movement ourselves.
]]
local anima = Anima.new(anims, player, false, true)

--[[
    Create a 1D Blend Controller
    The controller manages weights between animations based on a scalar value.
    
    Nodes definition:
    - 'name': The animation name in the 'anims' folder.
    - 'min': The value at which this animation starts having weight.
    - 'max': The value at which this animation reaches 1.0 weight (or starts fading out).
]]
anima:CreateBlendController("Locomotion", {
    nodes = {
        { name = "Idle", min = 0, max = 1 },
        { name = "Run", min = 6, max = 16 }
    }
})

--[[
    Synchronization Loop
    We calculate the character's current movement speed and pass it to
    the Blend Controller to update the animation weights accordingly.
]]
RunService.Heartbeat:Connect(function()
    -- Calculate speed based on movement direction and WalkSpeed
    local speed = humanoid.MoveDirection.Magnitude * humanoid.WalkSpeed
    
    -- Update the blend controller weights based on the calculated speed
    anima:UpdateBlend("Locomotion", speed)
end)
