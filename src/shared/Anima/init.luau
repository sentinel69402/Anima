--[[
    Copyright 2025 s3ntin5l
    
    Licensed under the Apache License, Version 2.0 (the "License");
    you may not use this file except in compliance with the License.
    You may obtain a copy of the License at
    
    http://www.apache.org/licenses/LICENSE-2.0

    Unless required by applicable law or agreed to in writing, software
    distributed under the License is distributed on an "AS IS" BASIS,
    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
    See the License for the specific language governing permissions and
    limitations under the License.
    
    
    USAGE INSTRUCTIONS FOR Anima MODULE
    
    This module facilitates comprehensive management of animations for Roblox Player instances.
    The following instructions delineate its core functionality and proper usage:
    
    1. Instantiation
    Create a new Anima instance by supplying a Folder containing Animation objects and a Player:
    
    local Anima = Anima.new(animationsFolder, player)
    
    2. Animation Loading and Caching
    - Load animations from the designated Folder:
    
    Anima:LoadAnimations()
    
    - Cache AnimationTracks based on loaded animations for the player’s Humanoid:
    
    Anima:Cache()
    
    Note: Cache should be invoked after LoadAnimations and whenever the Character respawns.
    
    3. Playback Control
    - Play a specified animation by name with optional configuration parameters:
    
    Anima:PlayAnimation(animationName, config?)
    
    The optional config table may include:
    • fadeTime (number): Duration of crossfade (default 0.2 seconds)
    • weight (number): Blending weight of the animation
    • priority (Enum.AnimationPriority): Priority level for animation blending
    • stopOthers (boolean): Whether to halt other playing animations (default true)
    
    - Stop a currently playing animation, optionally specifying a fade-out duration:
    
    Anima:StopAnimation(animationName, fadeTime?)
    
    - Pause or resume playback of an animation:
    
    Anima:PauseAnimation(animationName)
    Anima:ResumeAnimation(animationName)
    
    - Play animations in loop, optionally specifying loop count:
    
    Anima:PlayLooped(animationName, loopCount?)
    
    4. Advanced Animation Sequencing
    - Queue multiple animations to play sequentially:
    
    Anima:QueueAnimations(animationNames, config?)
    
    - Play a defined sequence of animations with specified fade times between:
    
    Anima:playSequence(animationNames, fadeTime)
    
    5. Animation Tagging and Group Operations
    - Assign tags to animations for grouped control:
    
    Anima:SetAnimationTag(animationName, tag)
    
    - Fade out all animations associated with a specific tag:
    
    Anima:FadeOutTag(tag, fadeTime?)
    
    6. Fallbacks and Error Handling
    - Specify fallback animations for missing animations:
    
    Anima:SetFallback(missingAnimationName, fallbackAnimationName)
    
    - Register a callback to handle missing animation requests:
    
    Anima:setMissingAnimCallback(callbackFunction)
    
    
    
    7. Event Callbacks and Markers
    - Assign callbacks for animation lifecycle events and custom animation markers:
    
    Anima:SetAnimationCallbacks(animationName, {
        onPlay = function() end,
        onStop = function() end,
        onMarker = { [markerName] = function() end } < make sure to re-cache if you set this.
        })
        
        - Dynamically add custom animation event callbacks at specific marker times:
        
        Anima:addAnimationEvent(animationName, markerTime, callback)
        
        8. Querying Animation State
        - Retrieve all currently playing animations:
        
        local playingAnimations = Anima:GetPlayingTracks()
        
        - Obtain AnimationTrack for a given animation name:
        
        local track = Anima:GetAnimationTrack(animationName)
        
        - Access a deep clone of the loaded animations table:
        
        local animationsCopy = Anima:getLoadedAnimations()
        
        9. Automatic Updates and Resource Management
        - Automatically reload and cache animations upon changes to the animations Folder:
        
        Anima:WatchForChanges()
        
        - Subscribe to external reload events:
        
        Anima:HotReload(bindableEvent)
        
        - Fade out all playing animations immediately:
        
        Anima:FadeAllOut(fadeTime)
        
        - Stop and clear all cached animation tracks:
        
        Anima:ClearAllTracks()
        
        - Schedule automatic cleanup and fade out after a delay:
        
        Anima:AutoExpire(delayTime)
        
        - Dispose of all event connections and internal resources:
        
        Anima:Destroy()
        
        GENERAL NOTES:
        - Ensure that Cache() is called after LoadAnimations() and when the player’s character is loaded or respawns.
        - Utilize Destroy() to properly release resources and avoid memory leaks when the handler is no longer needed.
        - Leverage tags, fallbacks, and callbacks to implement complex animation workflows tailored to your application’s requirements.
        - Review internal comments and source code for advanced customization opportunities.
        - Make sure to re-cache the animations after setting up callbacks and other configurations this is a roblox issue that I can't fix
        
        By adhering to these guidelines, developers can effectively manage player animations with flexibility, reliability, and performance.
]]
        
        
        
        
local handler = {}
handler.__index = handler
        
local ContentProvider = game:GetService("ContentProvider")
local StateMachine = require(script.StateMachine)
local Types = require(script.Types)
local BlendController = require(script.BlendController)
        
export type Anima = typeof(setmetatable({} :: any, handler))
export type config = {fadeTime: number?,weight: number?,priority: Enum.AnimationPriority?,stopOthers: boolean?,loop: boolean?}
type animationGroup = {name: string,members: {string},defaultConfig: config?}
type AnimationData = {
    track: AnimationTrack?,
    id: number,
    instance: Animation,
    markerConnections: {RBXScriptConnection}?
}

local weakValuesMeta = {__mode = "v"}
local weakKeysMeta = {__mode = "k"}

local DEBUG = false
local function debugPrint(...)
    if DEBUG then
        print(`[Anima Debug]`,...)
    end
end

--[[
Creates a new AnimationHandler instance
@param animationsFolder Folder The folder containing Animation objects
@param player Player The player whose animations will be managed
@param debugMode boolean? Optional debug mode flag
@param disableAnimate boolean? Disables Roblox's Animate script. Useful when using the state machine
@return Anima
```lua
local anima = Anima.new(workspace.Animations, game.Players.Player1, true, false)
```
]]
function handler.new(animationsFolder: Folder, player: Player, debugMode: boolean?, disableAnimate: boolean?)
    if typeof(animationsFolder) ~= "Instance" or not animationsFolder:IsA("Folder") then
        error("Argument 1 must be a folder",2)
    end
    if typeof(player) ~= "Instance" or not player:IsA("Player") then
        error("Argument 2 must be a player",2)
    end
    DEBUG = debugMode or false
    debugPrint("Init Anima for player ",player.Name)
    
    local self = setmetatable({}, handler)
    self.player = player
    self.character = player.Character or player.CharacterAdded:Wait()
    self.animator = self.character:FindFirstChildOfClass("Humanoid"):FindFirstChildOfClass("Animator")
    self.animationsFolder = animationsFolder
    self.animations = {}
    self.animationTracks = {}
    self._connections = {}
    self._onPlay = Instance.new("BindableEvent")
    self._onStop = Instance.new("BindableEvent")
    self._onMissingAnimation = nil
    
    
    self._watchingForChanges = false
    self._lastAnimationSnapshot = {}
    self._initialLoadComplete = false
    self._pendingUpdate = false
    
    self._tags = setmetatable({},weakKeysMeta) -- [tag] = {animationNames}
    self._fallbacks = setmetatable({},weakKeysMeta) -- [missingAnim] = fallbackNAme
    self._animationCallbacks = setmetatable({},weakKeysMeta) -- [animName] = {onPlay, onStop, onMarker = {[marker]}: callback}
    
    self._trackPool = setmetatable({},weakValuesMeta)
    self._animationGroups = setmetatable({},{__mode = "k"})
    
    self._stats = {
        tracksCreated = 0,
        tracksReused = 0,
        cacheOperations = 0,
    }
    
    self._connections[#self._connections + 1] = self.player.CharacterAdded:Connect(function()
        self.character = self.player.Character
        self.animator = nil
        task.wait(0.1)
        self:LoadAnimations()
        self:Cache()
    end)

    self._blendControllers = {} :: {[string]: Types.BlendController}

    local animate = self.character:FindFirstChild("Animate")

    if animate and disableAnimate then
        animate.Disabled = true
    end

    if #animationsFolder:GetChildren() == 0 then
        warn(`Anima: animationsFolder is empty for player: {player.Name}`)
    else
        self:LoadAnimations()
        self:Cache()
    end
    return self
end

local function deepClone(self): {[string]: Animation}
    local cloneTable = {}

    if not self or not self.animations then
        warn("deepClone: animations table is nil or self is invalid")
        return cloneTable
    end

    if type(self.animations) ~= "table" then
        warn("deepClone: animations is not a table, type is:", type(self.animations))
        return cloneTable
    end

    for name, anim in (self.animations) do
        if anim and typeof(anim) == "Instance" and anim:IsA("Animation") then
            local success, cloned = pcall(function()
                return anim:Clone()
            end)
            if success then
                cloneTable[name] = cloned
            else
                warn(`deepClone: Failed to clone animation "{name}"`)
            end
        else
            warn(`deepClone: Invalid animation object for "{name}"`)
        end
    end

    return cloneTable
end

--[[
Debugging and Stats methods
]]

--[[
Toggles debug mode on/off
@param enabled boolean Whether debug mode should be enabled
]]
function handler:setDebugMode(enabled: boolean)
    DEBUG = enabled
    debugPrint("Debug mode ",enabled and "enabled" or "disabled")
end

--[[
Checks if an animation is loaded
@param name string The animation name
@return boolean True if loaded, false otherwise
]]
function handler:IsAnimationLoaded(name: string): boolean
    local track = self.animationTracks[name]
    if not track then
        return false
    end
    return track.Length > 0
end

--[[
Gets performance statistics
@return table Statistics including tracks created, reused, etc.
```lua
local stats = anima:GetStats()
print("Tracks created:", stats.tracksCreated)
```
]]
function handler:getStats()
    if not self._stats then
        return {
            tracksCreated = 0,
            tracksReused = 0,
            cacheOperations = 0,
            lastCacheTime = 0
        }
    end
    
    local statsCopy = {}
    for k,v in (self._stats) do
        statsCopy[k] = v
    end
    return statsCopy
end

local function createDebounce(minInterval: number)
    local lastCall = 0
    local pending = false
    
    return function(callback: () -> ())
        local now = os.clock()
        
        if now - lastCall < minInterval then
            if not pending then
                pending = true
                task.delay(minInterval - (now - lastCall),function()
                    pending = false
                    callback()
                end)
            end
            return
        end
        
        lastCall = now
        callback()
    end
end

--[[
Type Validation Helpers
]]

local function validateAnimationName(self: Anima,name: string)
    if type(name) ~= "string" then
        error("Animation name must be a string",3)
    end
    if not self.animations[name] and not self._fallbacks[name] then
        warn(`Animation {name} not found and no available callback`)
    end
end

local function validateConfig(config: config?)
    if config and type(config) ~= "table" then
        error("Config must be a table or nil",3)
    end
end

--[[
Animation Groups Management
]]

--[[
Creates a new animation group
@param name string The group name
@param members {string} Array of animation names in the group
@param defaultConfig config? Optional default configuration for the group
```lua
anima:CreateGroup("movement", {"walk", "run"}, {priority = Enum.AnimationPriority.Movement})
```
]]
function handler:createGroup(name: string,members: {string},defaultConfig: config?)
    validateConfig(defaultConfig)
    if type(name) ~= "string" then
        error("Group name must be a string", 2)
    end
    if type(members) ~= "table" then
        error("Members must be a table", 2)
    end
    
    self._animationGroups[name] = {
        name = name,
        members = members,
        defaultConfig = defaultConfig or {}
    }
    debugPrint("Created group ",name," with ",#members," members")
end

--[[
Plays all animations in a group
@param groupName string The group to play
@param config config? Optional override configuration
@return {[string]: AnimationTrack} Dictionary of played tracks
```lua
anima:PlayGroup("movement", {fadeTime = 0.1})
```
]]
function handler:playGroup(groupName: string,config: config?)
    local group = self._animationGroups[groupName]
    
    if not group then
        error(`Group {groupName} not found`,2)
    end
    
    local combinedConfig = table.clone(group.defaultConfig or {})
    
    if config then
        for k,v in (config) do
            combinedConfig[k] = v
        end
    end
    
    local result = {}
    
    for _,animName in (group.members) do
        local track = self:PlayAnimation(animName,combinedConfig)
        result[animName] = track
        
        if track then
            local finished = Instance.new("BindableEvent")
            
            local connection
            connection = track.Stopped:Connect(function()
                finished:Fire()
                connection:Disconnect()
            end)
            finished.Event:Wait()
        else
            warn(`Animation "{animName}" failed to play in group {groupName}`)
        end
    end
    return result
end

--[[
Batch Operations
]]

--[[
Plays multiple animations simultaneously
@param animationNames {string} Array of animation names to play
@param config config? Optional configuration for all animations
@return {[string]: AnimationTrack} Dictionary of played tracks
```lua
anima:PlayAnimations({"idle", "blink"}, {weight = 0.5})
```
]]
function handler:PlayAnimations(animationNames: {string},config: config?)
    validateConfig(config)
    if type(animationNames) ~= "table" then
        error("First argument must be a table of animation names",2)
    end
    
    local results = {}
    for _,name in (animationNames) do
        results[name] = self:PlayAnimation(name,config)
    end
    return results
end

--[[
Stops multiple animations simultaneously
@param animationNames {string} Array of animation names to stop
@param fadeTime number? Optional fade out duration
@return {[string]: boolean} Dictionary of results (true if stopped)
```lua
anima:StopAnimations({"walk", "run"}, 0.2)
```
]]
function handler:StopAnimations(animationNames: {string},fadeTime: number?)
    if type(animationNames) ~= "table" then
        error("First argument must be a table of animation names", 2)
    end
    
    local results = {}
    for _,name in (animationNames) do
        results[name] = self:StopAnimation(name, fadeTime)
    end
    return results
end

--[[
Progress Tracking
]]

--[[
Gets progress information for an animation
@param animationName string The animation to check
@return number progress (0-1), boolean isPlaying, number currentTime, number totalLength
```lua
local progress, playing = anima:GetAnimationProgress("walk")
if playing then print(`Walk is {math.floor(progress * 100)}% complete`) end
```
]]
function handler:GetAnimationProgress(animationName: string): (number, boolean, number?, number?)
    validateAnimationName(self, animationName)
    local data = self.animationTracks[animationName]
    if not data or not data.track then
        return 0, false
    end

    local track = data.track
    return track.TimePosition / track.Length, 
        track.IsPlaying, 
        track.TimePosition, 
        track.Length
end

--[[
Gets progress for multiple animations
@param animationNames {string} Array of animation names
@return {[string]: {progress: number, playing: boolean}} Dictionary of progress info
```lua
local allProgress = anima:GetAnimationsProgress({"walk", "run"})
```
]]
function handler:GetAnimationsProgress(animationNames: {string})
    if type(animationNames) ~= "table" then
        error("First argument must be a table of animation names", 2)
    end

    local results = {}
    for _, name in (animationNames) do
        local progress, playing = self:GetAnimationProgress(name)
        results[name] = {
            progress = progress,
            playing = playing
        }
    end
    return results
end

--[[
    Helper to get or create an AnimationTrack
    @param name string Animation name
    @returns AnimationTrack?
]]
function handler:_getTrack(name: string): AnimationTrack?
    local data: AnimationData = self.animations[name]
    if not data then
        return nil
    end

    if data.track then
        return data.track
    end

    local animator: Animator = self.animator
    if not animator then
        local humanoid = self.character:FindFirstChildOfClass("Humanoid")
        if humanoid then
            animator = humanoid:FindFirstChildOfClass("Animator") or Instance.new("Animator", humanoid)
            self.animator = animator
        end
    end
    return nil
end

--[[
Sets a callback function that triggers when a requested animation is missing
@param fn Function accepting the missing animation's name (string)
]]
function handler:setMissingAnimCallback(fn: (string) -> ())
    self._onMissingAnimation = fn
end

--[[
Returns the RBXScriptSignal fired when an animation starts playing
@return RBXScriptSignal
]]
function handler:getPlaySignal(): RBXScriptSignal
    return self._onPlay.Event
end

--[[
Returns the RBXScriptSignal fired when an animation stops playing
@return RBXScriptSignal
]]
function handler:getStopSignal(): RBXScriptSignal
    return self._onStop.Event
end

--[[
Defines fallback animations to play when requested animations are missing
@param missingName Name of the missing animation
@param fallbackName Name of the fallback animation to use
]]
function handler:setFallback(missingName: string, fallbackName: string)
    self._fallbacks[missingName] = fallbackName
end

--[[
Assigns a tag to an animation for grouped control
@param animationName Name of the animation to tag
@param tag Tag identifier (string)
]]
function handler:setAnimationTag(animationName: string, tag: string)
    self._tags[tag] = self._tags[tag] or {}
    table.insert(self._tags[tag],animationName)
end

--[[
Stops all animations associated with a given tag, with an optional fade out duration
@param tag Tag identifier (string)
@param fadeTime Optional fade out duration in seconds (default 0.2)
]]
function handler:fadeOutTag(tag: string,fadeTime: number?)
    fadeTime = fadeTime or 0.2
    local animations = self._tags[tag]
    if not animations then
        return
    end
    for _, name in (animations) do
        self:StopAnimation(name,fadeTime)
    end
end

--[[
Registers callbacks for animation lifecycle events and marker triggers
@param name Animation name
@param callbacks Table with optional onPlay, onStop functions, and onMarker dictionary
]]
function handler:setAnimationCallbacks(name: string,callbacks: {
    onPlay: (() -> ())?,
    onStop: (() -> ())?,
    onMarker: { [string]: () -> () }?
    })
    self._animationCallbacks[name] = callbacks
end

--[[
Loads animations from the assigned animations folder into the handler's cache
]]
function handler:LoadAnimations()
    if not self.animationsFolder then
        warn("LoadAnimations called with no animationsFolder")
    end

    local start = os.clock()
    if not self.animations then
        self.animations = {}
    else
        table.clear(self.animations)
    end

    for _, animation in (self.animationsFolder:GetChildren()) do
        if animation:IsA("Animation") then
            self.animations[animation.Name] = animation
            if DEBUG then
                print("[LoadAnimations] Found animation:", animation.Name)
            end
        end
    end

	local assetsToPreload = {}
	
	for name, animation: Animation in (self.animations) do
		if animation and animation.AnimationId and animation.AnimationId ~= "" then
			table.insert(assetsToPreload, animation)
		end
	end

	if #assetsToPreload > 0 then
		local success, err = pcall(function()
			ContentProvider:PreloadAsync(assetsToPreload)
		end)

		if not success then 
			warn("Failed to preload animations: ", err)
		else
			debugPrint("Preloaded", #assetsToPreload, "animations")
		end
	end
    
    self:_updateAnimationSnapshot()
    
    local duration = os.clock() - start
    
    print(string.format("LoadAnimations completed in %.4f seconds", duration))
end

--[[
Caches AnimationTracks for all loaded animations on the player's character
]]
function handler:Cache()
    local character = self.character
    if not character or not character.Parent then
        warn("Character is invalid or destroyed")
        return 
    end

    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not humanoid then
        warn("Humanoid not found in character")
        return 
    end

    local animator = self.animator

    if not animator then
        animator = humanoid:FindFirstChildOfClass("Animator")
        if not animator then
            animator = Instance.new("Animator")
            animator.Parent = humanoid
        end
        self.animator = animator
    end

    if not animator.Parent then
        animator.Parent = humanoid
    end

    local oldTracks = self.animationTracks or {}
    self.animationTracks = {}

    local start = os.clock()
    local created = 0
    local failed = 0

    for name, oldData in (oldTracks) do
        if oldData.track then
            pcall(function()
                oldData.track:Stop()
            end)

            if oldData.markerConnections then
                for _, conn in (oldData.markerConnections) do
                    pcall(function()
                        conn:Disconnect()
                    end)
                end
            end

            pcall(function()
                oldData.track:Destroy()
            end)
        end
    end

    for name, animation in (self.animations) do
        if not animation or not animation.AnimationId or animation.AnimationId == "" then
            warn("Animation object is invalid for:", name)
            failed += 1
            continue
        end

        local freshAnimation = Instance.new("Animation")
        freshAnimation.AnimationId = animation.AnimationId
        freshAnimation.Name = animation.Name or name

        local loadSuccess, track = pcall(function()
            return animator:LoadAnimation(freshAnimation)
        end)

        if not loadSuccess or not track then
            warn("Failed to load animation:", name)
            failed += 1
            continue
        end

        created += 1

        local markerConnections = {}
        local markerCallbackMap = self._animationCallbacks
            and self._animationCallbacks[name]
            and self._animationCallbacks[name].onMarker

        if markerCallbackMap then
            local hasGetMarkerSignal = false
            pcall(function()
                hasGetMarkerSignal = typeof(track.GetMarkerReachedSignal) == "function"
            end)

            if hasGetMarkerSignal then
                for markerName, callback in (markerCallbackMap) do
                    if typeof(callback) == "function" then
                        local success, signal = pcall(function()
                            return track:GetMarkerReachedSignal(markerName)
                        end)

                        if success and signal and typeof(signal) == "RBXScriptSignal" then
                            local conn = signal:Connect(function()
                                local callSuccess, err = pcall(callback, markerName)
                                if not callSuccess then
                                    warn("Error in marker callback for", name, markerName, ":", err)
                                end
                            end)
                            table.insert(markerConnections, conn)
                            print("Connected marker:", markerName, "for animation:", name)
                        else
                            warn("Failed to get signal for marker:", markerName, "in animation:", name)
                        end
                    end
                end

                if #markerConnections > 0 then
                    print("Connected to", #markerConnections, "markers for:", name)
                else
                    warn("No valid markers connected for:", name)
                end
            else
                local markerSuccess, conn = pcall(function()
                    return track.KeyframeReached:Connect(function(keyframeName)
                        local callback = markerCallbackMap[keyframeName]
                        if callback and typeof(callback) == "function" then
                            local callSuccess, err = pcall(callback, keyframeName)
                            if not callSuccess then
                                warn("Error in keyframe callback for", name, keyframeName, ":", err)
                            end
                        end
                    end)
                end)

                if markerSuccess and conn then
                    table.insert(markerConnections, conn)
                    print("Using KeyframeReached fallback for:", name)
                else
                    warn("No marker or keyframe API available for:", name)
                end
            end
        end

        pcall(function()
            track.Priority = Enum.AnimationPriority.Action
        end)

        self.animationTracks[name] = {
            track = track,
            priority = Enum.AnimationPriority.Action,
            weight = 1,
            lastUsed = os.clock(),
            markerConnections = markerConnections,
            animation = freshAnimation, 
        }
    end

    if not self._stats then
        self._stats = {}
    end

    self._stats.tracksCreated = (self._stats.tracksCreated or 0) + created
    self._stats.cacheOperations = (self._stats.cacheOperations or 0) + 1
    self._stats.lastCacheTime = os.clock()
    
    if not self._initialLoadComplete then
        self._initialLoadComplete = true
        debugPrint("Initial cache complete - WatchForChanges will now respond to changes")
    end

    local duration = os.clock() - start
    print(string.format("Cache completed in %.4f seconds - Created: %d, Failed: %d", duration, created, failed))
end

function handler:_updateAnimationSnapshot()
    self._lastAnimationSnapshot = {}
    for _, child in (self.animationsFolder:GetChildren()) do
        if child:IsA("Animation") then
            self._lastAnimationSnapshot[child.Name] = {
                name = child.Name,
                id = child.AnimationId,
                instance = child
            }
        end
    end
end

function handler:_hasAnimationChanges(): boolean
    local currentAnimations = {}
    
    for _,child in (self.animationsFolder:GetChildren()) do
        if child:IsA("Animation") then
            currentAnimations[child.Name] = {
                name = child.Name,
                id = child.AnimationId,
                instance = child
            }
        end
    end
    
    local currentCount = 0
    local snapshotCount = 0
    
    for _ in (currentAnimations) do currentCount += 1 end
    for _ in (self._lastAnimationSnapshot) do snapshotCount += 1 end
    
    if currentCount ~= snapshotCount then
        debugPrint(`Animation count changed: {snapshotCount} -> {currentCount}`)
        return true
    end
    
    for name,current in (currentAnimations) do
        local snapshot = self._lastAnimationSnapshot[name]
        if not snapshot then
            debugPrint(`New animation found: {name}`)
            return true
        end
        
        if current.id ~= snapshot.id then
            debugPrint(`Animation ID changed for {name}: {snapshot.id} -> {current.id}`)
            return true
        end
        
        if current.instance ~= snapshot.instance then
            debugPrint(`Animation instance changed for {name}`)
            return true
        end
    end
    
    for name,_ in (self._lastAnimationSnapshot) do
        if not currentAnimations[name] then
            debugPrint(`Animation removed: {name}`)
            return true
        end
    end
    return false
end

--[[
Monitors the animations folder for changes and reloads animations automatically
]]
function handler:WatchForChanges()
    if self._watchingForChanges then
        debugPrint("Already watching for changes")
        return
    end

    self._watchingForChanges = true
    debugPrint("Starting to watch for animation changes")

    local debounce = createDebounce(0.5)

    local function handleChange(changeType: string, child: Instance?)
        if not self._initialLoadComplete then
            debugPrint(`Ignoring {changeType} during initial load`)
            return
        end

        if child and not child:IsA("Animation") then
            return
        end

        debugPrint(`Potential change detected: {changeType}`, child and child.Name or "unknown")

        debounce(function()
            if self._pendingUpdate then
                debugPrint("Update already pending, skipping")
                return
            end

            if not self:_hasAnimationChanges() then
                debugPrint("No actual changes detected, skipping reload")
                return
            end

            self._pendingUpdate = true
            debugPrint("Changes confirmed - reloading animations")

            local success, err = pcall(function()
                self:LoadAnimations()
                self:Cache()
            end)

            if not success then
                warn("Failed to reload animations:", err)
            else
                debugPrint("Animation reload completed successfully")
            end

            self._pendingUpdate = false
        end)
    end

    table.insert(self._connections, self.animationsFolder.ChildAdded:Connect(function(child)
        handleChange("ChildAdded", child)
    end))

    table.insert(self._connections, self.animationsFolder.ChildRemoved:Connect(function(child)
        handleChange("ChildRemoved", child)
    end))

    local function watchAnimationProperties()
        for _, animation in (self.animationsFolder:GetChildren()) do
            if animation:IsA("Animation") then
                local conn = animation:GetPropertyChangedSignal("AnimationId"):Connect(function()
                    handleChange("PropertyChanged", animation)
                end)
                table.insert(self._connections, conn)
            end
        end
    end

    watchAnimationProperties()

    table.insert(self._connections, self.animationsFolder.ChildAdded:Connect(function(child)
        if child:IsA("Animation") then
            task.wait(0.1)
            local conn = child:GetPropertyChangedSignal("AnimationId"):Connect(function()
                handleChange("PropertyChanged", child)
            end)
            table.insert(self._connections, conn)
        end
    end))
end

function handler:GetChangeStats(): {lastCheck: number?,changesDetected: number?, lastChangeTime: number?}
    return {
        initialLoadComplete = self._initialLoadComplete,
        watchingForChanges = self._watchingForChanges,
        pendingUpdate = self._pendingUpdate,
        animationCount = self.animations and #(self.animations) or 0
    }
end

    
--[[
Checks if a named animation is currently playing
@param animationName Animation name
@return Boolean true if playing, else false
]]
function handler:IsAnimationPlaying(animationName: string): boolean
    local data = self.animationTracks[animationName]
    return data and data.track.IsPlaying
end

--[[
Retrieves the AnimationTrack associated with a named animation
@param animationName Animation name
@return AnimationTrack or nil if not found
]]
function handler:GetAnimationTrack(animationName: string): AnimationTrack?
    local data = self.animationTracks[animationName]
    return data and data.track
end

--[[
Queues a list of animations to play sequentially with optional playback configuration
@param animationNames Array of animation names in play order
@param options Optional playback config table
]]
function handler:QueueAnimations(animationNames: { string }, options: config)
    local index = 1

    local function playNext()
        if index > #animationNames then
            return
        end
        local name = animationNames[index]
        local track = self:PlayAnimation(name, options)
        if not track then
            return
        end
        index += 1
        track.Stopped:Once(playNext)
    end
    playNext()
end

--[[
Plays an animation with optional configuration parameters
@param name string The name of the animation to play
@param config table? Optional configuration table with fields:
        fadeTime (number): Duration of fade in/out (default 0.2)
        weight (number): Playback weight (default 1)
        priority (Enum.AnimationPriority): Animation priority (default Action)
        stopOthers (boolean): Whether to stop other animations (default true)
@return AnimationTrack? The AnimationTrack if playback started, or nil on failure
]]
function handler:PlayAnimation(name: string, config: config?)
    assert(typeof(name) == "string", "Animation name must be a string")

    local cachedData = self.animationTracks[name]
    local track

    if cachedData and cachedData.track then
        track = cachedData.track
        print(`[PlayAnimation] Using cached track for "{name}"`)
    else
        local anim = self.animations[name]
        if not anim then
            if self._onMissingAnimation then
                self._onMissingAnimation(name)
            end

            local fallback = self._fallbacks[name]
            if fallback then
                return self:PlayAnimation(fallback, config)
            end

            warn(`[PlayAnimation] Animation "{name}" not found and no fallback available`)
            return nil
        end

        local animator = self.animator
        if not animator then
            warn(`[PlayAnimation] No Animator found on character`)
            return nil
        end

        local freshAnimation = Instance.new("Animation")
        freshAnimation.AnimationId = anim.AnimationId
        freshAnimation.Name = anim.Name or name

        track = animator:LoadAnimation(freshAnimation)
        if not track then
            warn(`[PlayAnimation] Failed to load animation track for "{name}"`)
            return nil
        end

        self.animationTracks[name] = {
            track = track,
            lastUsed = os.clock(),
            priority = Enum.AnimationPriority.Action,
            weight = 1,
            markerConnections = {},
            animation = freshAnimation,
        }

        warn(`[PlayAnimation] Had to load track on-demand for "{name}" - markers may not work`)
    end

    
    if not track.Length or track.Length <= 0 then
        warn(`[PlayAnimation] Track for "{name}" has invalid length after loading`)
        return nil	
    end

    local fadeTime = config and config.fadeTime or 0.2
    local weight = config and config.weight or (cachedData and cachedData.weight or 1)
    local priority = config and config.priority or (cachedData and cachedData.priority or Enum.AnimationPriority.Action)
    local stopOthers = if config ~= nil then config.stopOthers else true
    local loop = config and config.loop or false

    track.Priority = priority
    track.Looped = loop
    track:Play(fadeTime)
    track:AdjustWeight(weight, fadeTime)

    local cb = self._animationCallbacks[name]
    if cb and cb.onPlay then
        pcall(cb.onPlay)
    end

    self._onPlay:Fire(name, self.player)

    if stopOthers then
        local animator = self.animator
        if animator then
            for _, t in (animator:GetPlayingAnimationTracks()) do
                if t ~= track then
                    t:Stop(fadeTime)
                end
            end
        end
    end

    print(`[PlayAnimation] Playing "{name}" successfully`)
    return track
end

--[[
Stops the specified animation if playing, with optional fade out
@param animationName Animation name
@param fadeTime Optional fade duration in seconds
@return Boolean true if stopped, false if animation was not playing
]]
function handler:StopAnimation(animationName: string, fadeTime: number?): boolean
    local track = self:GetAnimationTrack(animationName)
    if not track then
        warn(`no animation track found for {animationName} on player {self.player.Name}`)
        return false
    end

    local fadingTime = fadeTime or 0.2

    if track.IsPlaying then
        local conn: RBXScriptConnection
        conn = track.Stopped:Connect(function()
            local cb = self._animationCallbacks[animationName]
            if cb and cb.onStop then
                cb.onStop()
            end
            conn:Disconnect()
            self._onStop:Fire(animationName, self.player)
        end)
        track:Stop(fadingTime)
        return true
    end
    return false
end

--[[
Pauses playback of the specified animation by setting speed to 0
@param animationName Animation name
]]
function handler:PauseAnimation(animationName: string)
    local data = self.animationTracks[animationName]
    if data and data.track.IsPlaying then
        data.track:AdjustSpeed(0)
    end
end

--[[
Resumes playback of the specified paused animation by restoring speed to 1
@param animationName Animation name
]]
function handler:ResumeAnimation(animationName: string)
    local data = self.animationTracks[animationName]
    if data and data.track.IsPlaying then
        data.track:AdjustSpeed(1)
    end
end

--[[
Plays an animation looped indefinitely or for a specified number of loops
@param animationName Animation name
@param loopCount Optional number of loops (infinite if omitted)
@return AnimationTrack if started, else nil
]]
function handler:PlayLooped(animationName: string, loopCount: number?): AnimationTrack?
    local track = self:PlayAnimation(animationName, { stopOthers = false })
    if not track then
        return
    end
    if loopCount then
        local played = 0
        local conn: RBXScriptConnection
        conn = track.Stopped:Connect(function()
            played += 1
            if played < loopCount then
                track:Play()
            else
                conn:Disconnect()
            end
        end)
    end
    return track
end

--[[
Returns a list of animation names currently playing
@return Array of playing animation names
]]
function handler:GetPlayingTracks(): { string }
    local list = table.create(20)
    for name, data in self.animationTracks do
        if data.track.IsPlaying then
            table.insert(list, name)
        end
    end
    return list
end

--[[
Schedules automatic stopping of all animations and cleanup after delayTime seconds
@param delayTime Time in seconds before expiration and cleanup
]]
function handler:AutoExpire(delayTime: number)
    task.delay(delayTime, function()
        if not self.player then
            return
        end
        for _, data in self.animationTracks do
            data.track:Stop()
        end
        self:Destroy()
    end)
end

--[[
Fades out all currently playing animations over the specified fade time
@param fadeTime Duration of fade out in seconds (default 0.3)
]]
function handler:FadeAllOut(fadeTime: number)
    fadeTime = fadeTime or 0.3
    for _, data in self.animationTracks do
        if data.track.IsPlaying then
            data.track:Stop(fadeTime)
            print(`Fading animation[s]: {data.track.Name}`)
        end
    end
end

--[[
Subscribes to an external BindableEvent to trigger reload of animations and cache
@param bindable BindableEvent instance to listen to
]]
function handler:HotReload(bindable: BindableEvent)
    table.insert(
        self._connections,
        bindable.Event:Connect(function()
            self:LoadAnimations()
            self:Cache()
        end)
    )
end

--[[
Stops and clears all cached animation tracks
]]
function handler:ClearAllTracks()
    for _, data in self.animationTracks do
        if data.track.IsPlaying then
            data.track:Stop()
        end
    end
    self.animationTracks = {}
end

--[[
Updates weight and/or priority for a cached animation track
@param name Animation name
@param config Table with optional weight (number) and priority (Enum.AnimationPriority)
]]
function handler:setAnimationConfig(name: string, config: { weight: number?, priority: Enum.AnimationPriority? })
    local data = self.animationTracks[name]
    if data then
        if config.weight then
            data.weight = config.weight
        end
        if config.priority then
            data.priority = config.priority
        end
    end
end

--[[
Quickly sets the weight of a playing animation track
@param name Animation name
@param weight Target weight
@param fadeTime Optional fade duration
]]
function handler:SetWeight(name: string, weight: number, fadeTime: number?)
    local data = self.animationTracks[name]
    if data and data.track then
        data.track:AdjustWeight(weight, fadeTime or 0)
    end
end

--[[
Returns a deep copy of the loaded animations table
@return Table mapping animation names to cloned Animation instances
]]
function handler:getLoadedAnimations(): { [string]: Animation }
    if not self then
        error("getLoadedAnimations called on destroyed Anima instance",2)
    end
    
    if not self.animations then
        warn("getLoadedAnimations called on Anima instance with no animations loaded")
        return {}
    end
    
    return deepClone(self)
end

--[[
Adds a custom event callback triggered at a specific marker time in the animation
@param animationName Animation name
@param time Marker time as string or number
@param callback Function to execute when marker is reached
]]
function handler:addAnimationEvent(animationName: string, time: number, callback: () -> ())
    local track = self:GetAnimationTrack(animationName)
    if track then
        local event = Instance.new("BindableEvent")
        event.Event:Connect(callback)
        track:GetMarkerReachedSignal(tostring(time)):Connect(function()
            event:Fire()
        end)
    end
end

--[[
Plays a sequence of animations one after another with fade time between them
@param sequence Ordered list of animation names
@param fadeTime Fade duration between animations
]]
function handler:playSequence(sequence: { string }, fadeTime: number): ()
    for i, animName in sequence do
        local track = self:PlayAnimation(animName, { fadeTime = fadeTime })
        if track and i < #sequence then
            track.Stopped:Wait()
        end
    end
end

--[[
Creates a new StateMachine instance for managing complex animation logic
@param config Configuration for the state machine, including states and transitions
@return A new StateMachine instance
]]
function handler:CreateStateMachine(config: Types.StateMachineConfig)
    return StateMachine.new(config)
end

--[[
Creates a new BlendController for smooth animation blending
@param name The name to store this controller under
@param profile The blend profile configuration
@return A new BlendController instance
]]
function handler:CreateBlendController(name: string, profile: Types.BlendProfile): Types.BlendController
    assert(self._blendControllers[name] == nil, `BlendController {name} already exists`)
    
    local controller = BlendController.new(self, profile)
    self._blendControllers[name] = controller
    return controller
end

function handler:UpdateBlend(name: string, value: number)
    local controller = self._blendControllers[name] :: Types.BlendController

    if not controller then
        return
    end

    controller:Update(value)
end

--[[
Cleans up all event connections, internal state, and releases resources
]]
function handler:Destroy()
    for _, conn in (self._connections or {}) do
        if conn and conn.Disconnect  then
            pcall(function() conn:Disconnect() end)
        end
    end

    for _, controller: Types.BlendController in (self._blendControllers) do
        controller:Destroy()
    end
    
    if self._onPlay then
        pcall(function() self._onPlay:Destroy() end)
    end
    if self._onStop then
        pcall(function() self._onStop:Destroy() end)
    end
    
    if self._trackPool then
        for _,track in (self._trackPool) do
            if track then
                pcall(function()
                    track:Stop()
                    track:Destroy()
                end)
            end
        end
    end
    
    if self.animations then table.clear(self.animations) end
    if self.animationTracks then table.clear(self.animationTracks) end
    if self._trackPool then table.clear(self._trackPool) end
    
    self._destroyed = true
    
    self.animations = nil
    self.animationTracks = nil
    self._trackPool = nil
    self.player = nil
    self.animationsFolder = nil
    self._connections = nil
    self._blendControllers = {}
end

return handler