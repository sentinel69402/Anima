--[[
    Example: Disabling Roblox's Default Animate Script
    This example demonstrates how to use Anima as a complete replacement for
    Roblox's default 'Animate' script.
    
    Why disable the default Animate script?
    1. Conflict Prevention: Prevents the default script from fighting with your custom animations.
    2. Full Control: Allows the developer to define every character state transition.
    3. Performance: Reduces overhead by removing unnecessary default logic and event connections.
    4. Deterministic State: Ensures that only Anima is controlling the character's movement animations.
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
    Initialize Anima with 'disableAnimate' set to true
    
    Arguments:
    1. anims (Folder) - The animation source
    2. player (Player) - The player instance
    3. false (boolean?) - Debug mode
    4. true (boolean?) - disableAnimate: Disables the default 'Animate' script in the character
]]
local anima = Anima.new(anims, player, false, true)

--[[
    Define playback configuration
]]
local config: Anima.config = {
    loop = true
}

--[[
    Play the primary idle animation
    Since the default Animate is disabled, this animation will persist without
    being overridden by the character's default movement logic.
]]
anima:PlayAnimation("Idle", config)