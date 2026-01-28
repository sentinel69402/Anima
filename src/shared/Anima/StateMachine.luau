local StateMachine = {}
StateMachine.__index = StateMachine

local Types = require(script.Parent.Types)

function StateMachine.new(config: Types.StateMachineConfig): Types.StateMachine
    assert(config.initial, "StateMachine requires an initial state")

    local self = setmetatable({}, StateMachine)

    self._current = config.initial
    self._states = config.states or {}
    self.Context = config.context or {}
    self._lockedUntil = 0

    local initial = self._states[self._current]
    if initial and initial.onEnter then
        initial.onEnter()
    end

    return self
end

function StateMachine:AddState(name: string, state: Types.State)
    self._states[name] = state

    if name == self._current and state.onEnter then
        state.onEnter()
    end
end

function StateMachine:GetState(): string
    return self._current
end

function StateMachine:SetState(name: string)
    if self._current == name then
        return
    end

    local now = os.clock()
    if now < self._lockedUntil then
        return
    end

    local currentState = self._states[self._current]
    if currentState and currentState.onExit then
        currentState.onExit()
    end

    self._current = name

    local newState = self._states[name]
    if newState and newState.onEnter then
        newState.onEnter()
    end
end

function StateMachine:Lock(duration: number)
    self._lockedUntil = os.clock() + duration
end

function StateMachine:Update()
    local now = os.clock()
    if now < self._lockedUntil then
        return
    end

    local state = self._states[self._current]
    if not state or not state.transitions then
        return
    end

    for target, condition in (state.transitions) do
        if condition(self.Context) then
            self:SetState(target)
            break
        end
    end
end

return StateMachine