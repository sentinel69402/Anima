local StateMachine = {}
StateMachine.__index = StateMachine

local Types = require(script.Parent.Types)

--[[
Creates a new StateMachine instance
@param config StateMachineConfig The configuration for the state machine
@return StateMachine
```lua
local machine = StateMachine.new({
    initial = "Idle",
    states = {
        Idle = {
            onEnter = function() anima:PlayAnimation("Idle") end,
            transitions = {
                Walking = function(ctx) return ctx.speed > 0 end
            }
        }
    }
})
```
]]
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

--[[
Adds a new state to the machine
@param name string The name of the state
@param state State The state configuration
]]
function StateMachine:AddState(name: string, state: Types.State)
    self._states[name] = state

    if name == self._current and state.onEnter then
        state.onEnter()
    end
end

--[[
Gets the current state name
@return string
]]
function StateMachine:GetState(): string
    return self._current
end

--[[
Transitions to a specific state
@param name string The name of the state to transition to
]]
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

--[[
Locks the state machine for a duration, preventing transitions
@param duration number How long to lock the machine in seconds
]]
function StateMachine:Lock(duration: number)
    self._lockedUntil = os.clock() + duration
end

--[[
Updates the state machine and checks for transitions
]]
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

--[[
Cleans up the StateMachine
]]
function StateMachine:Destroy()
    local currentState = self._states[self._current]
    if currentState and currentState.onExit then
        pcall(function() currentState.onExit() end
    end

    self._states = nil
    self._Context = nil

    setmetatable(self,nil)
end

return StateMachine
