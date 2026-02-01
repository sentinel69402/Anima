-- State Machine
export type Context = {
    [string]: any
}

export type TransitionFn = (context: Context) -> boolean

export type State = {
    onEnter: (() -> ())?,
    onExit: (() -> ())?,
    transitions: { [string]: TransitionFn }?
}

export type StateMap = {
    [string]: State
}

export type StateMachineConfig = {
    initial: string,
    context: Context?,
    states: StateMap?
}

export type StateMachine = {
    Context: Context,

    AddState: (self: StateMachine, name: string, state: State) -> (),
    SetState: (self: StateMachine, name: string) -> (),
    GetState: (self: StateMachine) -> string,
    Update: (self: StateMachine) -> (),
    Lock: (self: StateMachine, duration: number) -> ()
}
-- End State Machine

-- Blend
export type BlendNode = {
    name: string,
    min: number,
    max: number
}

export type BlendProfile = {
    nodes: { BlendNode }
}

export type BlendController = {
    Update: (self: BlendController, value: number) -> (),
    Destroy: (self: BlendController) -> ()
}
-- End Blend

-- Core Anima Interface (stupid cyclic dependency)
export type PlaybackConfig = {
    fadeTime: number?,
    weight: number?,
    priority: Enum.AnimationPriority?,
    stopOthers: boolean?,
    loop: boolean?
}

export type Signal<T...> = {
    Connect: (self: Signal<T...>, fn: (T...) -> ()) -> any,
    Once: (self: Signal<T...>, fn: (T...) -> ()) -> any,
    Wait: (self: Signal<T...>) -> T...,
    Fire: (self: Signal<T...>, T...) -> (),
    DisconnectAll: (self: Signal<T...>) -> (),
    Destroy: (self: Signal<T...>) -> (),
}

export type Anima = {
    player: Player?,
    character: Model,

    -- Lifecycle & Debug
    Destroy: (self: Anima) -> (),
    LoadAnimations: (self: Anima) -> (),
    Cache: (self: Anima) -> (),
    WatchForChanges: (self: Anima) -> (),
    HotReload: (self: Anima, bindable: BindableEvent) -> (),
    setDebugMode: (self: Anima, enabled: boolean) -> (),
    GetChangeStats: (self: Anima) -> { [string]: any },

    -- Playback
    PlayAnimation: (self: Anima, name: string, config: PlaybackConfig?) -> AnimationTrack?,
    StopAnimation: (self: Anima, name: string, fadeTime: number?) -> boolean,
    PauseAnimation: (self: Anima, name: string) -> (),
    ResumeAnimation: (self: Anima, name: string) -> (),
    PlayLooped: (self: Anima, name: string, loopCount: number?) -> AnimationTrack?,
    PlayAnimations: (self: Anima, animationNames: { string }, config: PlaybackConfig?) -> { [string]: AnimationTrack },
    playGroup: (self: Anima, groupName: string, config: PlaybackConfig?) -> (),
    playSequence: (self: Anima, sequence: { string }, fadeTime: number) -> (),
    QueueAnimations: (self: Anima, animationNames: { string }, options: PlaybackConfig) -> (),

    -- Configuration
    SetAnimation: (self: Anima, name: string, id: number | string | Animation) -> (),
    SetAnimationSpeed: (self: Anima, name: string, speed: number) -> (),
    SetWeight: (self: Anima, name: string, weight: number, fadeTime: number?) -> (),
    setAnimationConfig: (self: Anima, name: string, config: { weight: number?, priority: Enum.AnimationPriority? }) -> (),
    setFallback: (self: Anima, missingName: string, fallbackName: string) -> (),
    setAnimationTag: (self: Anima, animationName: string, tag: string) -> (),
    setAnimationCallbacks: (self: Anima, name: string, callbacks: {
        onPlay: (() -> ())?,
        onStop: (() -> ())?,
        onMarker: { [string]: () -> () }?
    }) -> (),

    -- Queries
    GetAnimationTrack: (self: Anima, animationName: string) -> AnimationTrack?,
    GetPlayingTracks: (self: Anima) -> { string },
    GetAnimationProgress: (self: Anima, animationName: string) -> (number, boolean, number?, number?),
    IsAnimationPlaying: (self: Anima, animationName: string) -> boolean,
    IsAnimationLoaded: (self: Anima, name: string) -> boolean,
    getLoadedAnimations: (self: Anima) -> { [string]: Animation },

    -- Advanced Control
    UpdateBlend: (self: Anima, name: string, value: number) -> (),
    CreateBlendController: (self: Anima, name: string, profile: BlendProfile) -> BlendController,
    CreateStateMachine: (self: Anima, config: StateMachineConfig) -> StateMachine,
    addAnimationEvent: (self: Anima, animationName: string, time: number, callback: () -> ()) -> (),
    AutoExpire: (self: Anima, delayTime: number) -> (),
    FadeAllOut: (self: Anima, fadeTime: number?) -> (),
    fadeOutTag: (self: Anima, tag: string, fadeTime: number?) -> (),
    ClearAllTracks: (self: Anima) -> (),
    Sync: (self: Anima, data: { [Instance]: { string } }) -> (),
    GetRegistry: (self: Anima) -> { [Instance]: any },

    -- Signals
    getPlaySignal: (self: Anima) -> Signal<string, Player?, Model>,
    getStopSignal: (self: Anima) -> Signal<string, Player?, Model>,
}
-- End Core Anima Interface

return {}