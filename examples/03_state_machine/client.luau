--[[
    Example: Animation State Machine
    This script demonstrates how to implement a declarative state machine using Anima.
    
    The State Machine (SM) handles transitions between different animation states
    (like Idle and Run) based on a shared context (Speed). This approach decouples
    game logic from animation playback.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
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
    We disable the default Roblox 'Animate' script to allow the State Machine
    to have full control over character movement.
]]
local anima = Anima.new(anims, player, false, true)

--[[
    Create the State Machine
    - 'initial': The state to start in upon creation.
    - 'context': A table of data that transitions can check to decide when to switch states.
]]
local SM = anima:CreateStateMachine({
    initial = "Idle",
    context = {
        Speed = 0
    }
})

--[[
    Define the 'Idle' State
    - onEnter: Plays the idle animation when the state becomes active.
    - transitions: Logic to determine if we should switch to the 'Run' state.
]]
SM:AddState("Idle", {
    onEnter = function()
        anima:PlayAnimation("Idle", {loop = true})
    end,
    transitions = {
        Run = function(ctx)
            return ctx.Speed > 0.1
        end
    }
})

--[[
    Define the 'Run' State
    - onEnter: Plays the run animation with a slight cross-fade.
    - onExit: Cleanly stops the run animation when leaving the state.
    - transitions: Logic to transition back to 'Idle' when speed drops.
]]
SM:AddState("Run", {
    onEnter = function()
        anima:PlayAnimation("Run", {loop = true, fadeTime = 0.15})
    end,
    onExit = function()
        anima:StopAnimation("Run", 0.1)
    end,
    transitions = {
        Idle = function(ctx)
            return ctx.Speed < 0.1
        end
    }
})

--[[
    Global Update Loop
    Updates the context data (Speed) based on the character's movement
    and triggers the State Machine update to evaluate transitions.
]]
RunService.Heartbeat:Connect(function()
    SM.Context.Speed = humanoid.MoveDirection.Magnitude
    SM:Update()
end)
