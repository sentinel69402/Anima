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

export type Anima = {
    PlayAnimation: (self: Anima, name: string, config: PlaybackConfig?) -> AnimationTrack?,
    StopAnimation: (self: Anima, name: string, fadeTime: number?) -> boolean,
    SetWeight: (self: Anima, name: string, weight: number, fadeTime: number?) -> (),
    -- Add other methods as needed
    [string]: any
}
-- End Core Anima Interface

return {}