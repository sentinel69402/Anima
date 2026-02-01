--[[
    Example: NPC Support
    This script demonstrates how to utilize Anima for non-player characters (NPCs).
    Unlike players, NPCs pass their Model directly to the constructor.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Anima = require(ReplicatedStorage.Shared.Anima)

-- Assuming there is a model named "Zombie" in the Workspace
local npcModel = workspace:FindFirstChild("Zombie")

if not npcModel then
    warn("NPC Support Example: Could not find 'Zombie' model in Workspace")
    return
end

--[[
    Initialize Anima for an NPC
    - Argument 2 is the Model instead of a Player.
    - Anima will automatically find or create an 'Animator' inside the Humanoid.
]]
local anima = Anima.new(ReplicatedStorage:WaitForChild("Anims"), npcModel)

--[[
    Play a signal listener
    Since this is an NPC, the 'player' argument in signals will be nil.
    The 'character' argument will match npcModel.
]]
anima:getPlaySignal():Connect(function(name, player, character)
    if not player then
        print(`NPC {character.Name} started animation: {name}`)
    end
end)

-- Play an animation
anima:PlayAnimation("Idle", { loop = true })

-- Change speed after a few seconds
task.wait(2)
anima:SetAnimationSpeed("Idle", 1.5)
print("Increased NPC animation speed to 1.5x")
