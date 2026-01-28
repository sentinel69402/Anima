--[[
    Example: Combined State Machine & Blend Controller
    
    This advanced example demonstrates the power of Anima by combining 
    a State Machine with a 1D Blend Controller. 
    
    Workflow:
    1. The State Machine manages high-level logic (Locomotion vs Jumping).
    2. While in the 'Locomotion' state, the Blend Controller handles the 
       nuanced transitions between 'Idle' and 'Run'.
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
    Define the State Machine
    - 'Locomotion': The default state where blended movement occurs.
    - 'Jump': Triggered when the character is in the air.
]]
local SM = anima:CreateStateMachine({
    initial = "Locomotion",
    context = { IsJumping = false }
})

SM:AddState("Locomotion", {
    transitions = {
        Jump = function(ctx)
            return ctx.IsJumping
        end
    }
})

SM:AddState("Jump", {
    onEnter = function()
        anima:PlayAnimation("Jump")
    end,
    onExit = function()
        anima:StopAnimation("Jump", 0.1)
    end,
    transitions = {
        Locomotion = function(ctx)
            return not ctx.IsJumping
        end
    }
})

--[[
    Create the Blend Controller for Locomotion
    This will be used while the State Machine is in the 'Locomotion' state.
]]
anima:CreateBlendController("Locomotion", {
    nodes = {
        { name = "Idle", min = 0, max = 1 },
        { name = "Run", min = 0, max = 16 }
    }
})

--[[
    Core Logic Loop
    We update both the State Machine context and the Blend Controller values
    every frame to ensure responsive animation transitions.
]]
RunService.Heartbeat:Connect(function()
    -- Check if the character is jumping or falling
    SM.Context.IsJumping = humanoid:GetState() == Enum.HumanoidStateType.Jumping
            or humanoid:GetState() == Enum.HumanoidStateType.Freefall

    -- Conditional Animation Logic
    if SM:GetState() == "Locomotion" then
        -- Update blend weights based on speed when on the ground
        local speed = humanoid.MoveDirection.Magnitude * humanoid.WalkSpeed
        anima:UpdateBlend("Locomotion", speed)
    else
        -- Force Idle weight (0 speed) when not in locomotion state
        anima:UpdateBlend("Locomotion", 0)
    end

    -- Evaluate State Machine transitions
    SM:Update()
end)
