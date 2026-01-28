--[[
    Example: Upper Body Overlay / Animation Priorities
    
    This script demonstrates how to overlay high-priority animations (like a Punch)
    over lower-priority blended locomotion (Idle/Run).
    
    By setting the 'priority' parameter in the config, we ensure that the 
    Action-level animation overrides the movement animations on relevant joints
    without stopping them.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Anima = require(ReplicatedStorage.Shared.Anima)

--[[
    Get local dependencies and references
]]
local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local humanoid = character:WaitForChild("Humanoid") :: Humanoid
local anims = ReplicatedStorage:WaitForChild("Anims")

--[[
    Initialize Anima
    As with previous examples, we disable the default 'Animate' script.
]]
local anima = Anima.new(anims, player, false, true)

--[[
    Configure Locomotion
    The movement animations should typically be set to 'Movement' priority 
    (handled internally or via the Animation object's properties).
]]
anima:CreateBlendController("Locomotion", {
    nodes = {
        { name = "Idle", min = 0, max = 1 },
        { name = "Run", min = 6, max = 16 }
    }
})

--[[
    Input Handling for Overlay Animations
    Press 'F' to perform a punch. We use 'Action' priority to ensure it 
    plays over the movement animations.
]]
UserInputService.InputBegan:Connect(function(Input, GPE)
    if GPE then return end

    if Input.KeyCode == Enum.KeyCode.F then 
        -- Play the punch with a higher priority and fast cross-fade
        anima:PlayAnimation("Punch", {
            priority = Enum.AnimationPriority.Action,
            fadeTime = 0.05
        })
    end
end)

--[[
    Locomotion Sync Loop
]]
RunService.Heartbeat:Connect(function()
    local speed = humanoid.MoveDirection.Magnitude * humanoid.WalkSpeed
    
    -- Keep updating movement blend even while punching
    anima:UpdateBlend("Locomotion", speed)
end)
