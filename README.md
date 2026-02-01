<img src="assets/anima128.png" width="">

# Anima; Tame your animations

[![License](https://img.shields.io/badge/License-Apache2.0-blue.svg)](LICENSE)
[![Version](https://img.shields.io/badge/Version-2-green.svg)](README.md)
[![Roblox Studio](https://img.shields.io/badge/Compatible-Roblox%20Studio-red.svg)]()

---

Animations that don’t fight back.

Anima is a lightweight animation library for Roblox. It’s built to remove the repetitive boilerplate of loading tracks and to fix the common conflicts that come with Roblox's default character scripts. It gives you clean control over playback, blending, and state transitions without trying to own your actual gameplay logic.

The goal is simple: You decide what should play, and Anima handles the behavior.

---

### Why use this?

Standard Roblox animation code often turns into a mess of:

- Duplicated track loading logic
- Fighting priorities between scripts
- Jarring animation cuts
- Hard-to-read movement checks scattered everywhere

Anima approach is different:

- Tracks are cached once and reused.
- Animations stay alive at weight 0 during blends to avoid "popping".
- It uses actual blending instead of just stopping and starting tracks.
- High-level systems (like state machines) are completely optional.

---

### Core Features

- **Zero-cost Caching**: AnimationTracks are loaded once and stored. No runtime hitches from loading assets on the fly.
- **1D Blend Controllers**: Smoothly interpolate between states like Idle, Walk, and Run based on a single value (usually speed).
- **Optional State Machine**: A simple way to manage high-level intent (e.g., "Is the character jumping?") without mixing it into your physics code.
- **Folder-Based**: No manual configuration. Point it at a folder and it finds everything for you.
- **NPC Support**: Works out of the box for NPCs by passing the Model instead of a Player.
- **Singleton Pattern**: Automatically manages and returns a single instance per Player, preventing duplicated logic.
- **Animate Conflict Handling**: Anima can automatically disable Roblox’s default "Animate" script so it doesn't fight your custom system.

---

### What Anima isn't

To keep it lightweight, this library specifically avoids:

- Movement logic or physics
- Input handling
- Character controllers
- Gameplay decisions

Anima handles how the animations look and transition, but it doesn't decide how your game works.

---

### Quick Start

```lua
local Anima = require(game.ReplicatedStorage.Anima)

-- (folder, subject [Player or NPC Model], debug?, disableAnimate?)
local anima = Anima.new(
    game.ReplicatedStorage.anims,
    game.Players.LocalPlayer, -- Or workspace.NPC
    false,
    true
)

anima:PlayAnimation("Idle", {
    loop = true,
    fadeTime = 0.2
})

-- Optional: Initialize with IDs instead of a folder
local animaWithIds = Anima.new({
    Idle = 12345678,
    Walk = 87654321,
}, game.Players.LocalPlayer)
```

---

### 1D Blend Controllers

These keep animations playing in the background and smoothly shift their weights based on speed.

```lua
anima:CreateBlendController("Locomotion", {
    nodes = {
        { name = "Idle", min = 0,  max = 1 },
        { name = "Run",  min = 6,  max = 16 }
    }
})

-- Update in a loop
local speed = humanoid.MoveDirection.Magnitude * humanoid.WalkSpeed
anima:UpdateBlend("Locomotion", speed)
```

This prevents the "snapping" or "popping" usually seen when switching between walk and run states.

---

### State Machine

Use this to define high-level character intent. A common pattern is to let the State Machine decide _what_ the character is doing, and let a Blend Controller decide _how_ that motion looks.

```lua
local SM = anima:CreateStateMachine({
    initial = "Locomotion",
    context = { IsJumping = false }
})

SM:AddState("Jump", {
    onEnter = function()
        anima:PlayAnimation("Jump")
    end,
    transitions = {
        Locomotion = function(ctx) return not ctx.IsJumping end
    }
})
```

---

### Examples

The `examples/` folder contains focused scripts for specific use cases:

1. **Basic Playback**: The simplest way to play an animation.
2. **Disabling Animate**: How to take full control of a character.
3. **State Machines**: Managing high-level animation states.
4. **Locomotion Blending**: Smoothly handling movement speed transitions.
5. **Composition**: Using states and blending together.
6. **Overlays**: Layering actions (like punching) over movement using priorities.
7. **NPC Support**: Operating Anima on non-player characters.

---

### API Reference

#### Core Types

```lua
type PlaybackConfig = {
    fadeTime: number?,           -- Default: 0.2
    weight: number?,             -- Default: 1.0
    priority: Enum.Priority?,    -- Default: Action
    loop: boolean?,              -- Default: false
    stopOthers: boolean?         -- Default: true
}

type BlendNode = {
    name: string,                -- Animation name
    min: number,                 -- Start influence
    max: number                  -- Peak influence
}

type State = {
    onEnter: (() -> ())?,        -- Called when entering state
    onExit: (() -> ())?,         -- Called when leaving state
    transitions: { [string]: (context: table) -> boolean }?
}
```

#### Anima Methods

**Initialization**

- `Anima.new(source, subject, debug?, disableAnimate?)` -> `Anima`
  - `source` can be a **Folder** or a **Table** (`{[string]: number | string}`).
  - `subject` can be a **Player** or a **Model** (NPC).
  - If a Player is provided, it returns a singleton instance.
- `:LoadAnimations()` - Manually re-scan the animation folder.
- `:Cache()` - Reloads character animator and tracks (call this on respawn).
- `:WatchForChanges()` - Enables live-reloading of animations during development.

**Playback**

- `:PlayAnimation(name, config?)` -> `AnimationTrack?`
- `:StopAnimation(name, fadeTime?)` -> `boolean`
- `:PauseAnimation(name)` / `:ResumeAnimation(name)`
- `:PlayLooped(name, loopCount?)`
- `:SetAnimation(name, id)` - Dynamically set or replace an animation using an ID or Instance.
- `:SetAnimationSpeed(name, speed)` - Persistently sets the playback speed for an animation.
- `:SetWeight(name, weight, fadeTime?)`
- `:FadeAllOut(fadeTime?)`

**Queries**

- `:GetAnimationTrack(name)` -> `AnimationTrack?`
- `:GetPlayingTracks()` -> `{ string }`
- `:GetAnimationProgress(name)` -> `(progress: number, isPlaying: boolean)`
- `:IsAnimationPlaying(name)` / `:IsAnimationLoaded(name)`

**Grouping & Sequencing**

- `:QueueAnimations(names, config?)` - Sequential playback.
- `:playSequence(names, fadeTime)` - Simplified sequential playback.
- `:setAnimationTag(name, tag)` / `:fadeOutTag(tag, fadeTime?)` - Batch control via tags.

**Systems**

- `:CreateBlendController(name, profile)` -> `BlendController`
- `:UpdateBlend(name, value)`
- `:CreateStateMachine(config)` -> `StateMachine`

**Lifecycle**

- `:getPlaySignal()` / `:getStopSignal()` - Returns custom Signal objects.
  - Listeners receive: `(animationName: string, player: Player?, character: Model)`
- `:setAnimationCallbacks(name, callbacks)` - Hook into state changes or markers.
- `:Destroy()` - Clean up all tracks and event connections.

#### BlendController Methods

- `:Update(value)` - Manually update the blend tree weights.
- `:Destroy()` - Clean up the controller.

#### StateMachine Methods

- `:AddState(name, state)` - Register a new state.
- `:GetState()` -> `string` - Returns current state name.
- `:SetState(name)` - Force a state transition.
- `:Update()` - Evaluate transitions based on context.
- `:Lock(duration)` - Prevent transitions for a set amount of time.
- `.Context` - Workspace table for transition data.

---

### Philosophy

Anima is designed to be predictable and composable. It shouldn't have side effects that surprise you. If it does, that's a bug.

---

### License

Apache License 2.0

![Anima Promo](assets/AnimaPromo.gif)
