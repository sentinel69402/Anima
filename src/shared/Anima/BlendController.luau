--[[
    BlendController
    Manages 1D animation blending based on a weight value.
    Smoothly transitions between multiple animations defined in a BlendProfile.
]]

local BlendController = {}
BlendController.__index = BlendController

local Types = require(script.Parent.Types)

local clamp = math.clamp

--[[
    Applies a smooth cubic curve to the input value for more natural blending
    @param x number Input value (0-1)
    @return number Output value (0-1)
]]
local function dramaticCurve(x: number): number
    return x * x * x * (x * (x * 6 - 15) + 10)
end

--[[
    Creates a new BlendController instance
    @param handler Anima The Anima handler instance
    @param profile BlendProfile The profile defining animations and their ranges
    @return BlendController
    ```lua
    local blend = BlendController.new(anima, {
        nodes = {
            {name = "Idle", min = 0, max = 0},
            {name = "Walk", min = 5, max = 15},
            {name = "Run", min = 20, max = 50}
        }
    })
    ```
]]
function BlendController.new(handler: Types.Anima, profile: Types.BlendProfile): Types.BlendController
    local self = setmetatable({}, BlendController)

    self._handler = handler
    self._nodes = profile.nodes
    self._alive = true

    self._sortedNodes = table.clone(self._nodes)
    table.sort(self._sortedNodes, function(a, b)
        return (a.min + a.max) / 2 < (b.min + b.max) / 2
    end)

    for _, node in (self._nodes) do
        handler:PlayAnimation(node.name,{
            loop = true,
            weight = 0,
            fadeTime = 0.15,
            priority = Enum.AnimationPriority.Action,
            stopOthers = false
        })
    end

    return self
end

--[[
    Updates the weights of the animations based on the provided value
    @param value number The value to blend by (e.g. current movement speed)
    ```lua
    blend:Update(humanoid.MoveDirection.Magnitude * 16)
    ```
]]
function BlendController:Update(value: number)
    if not self._alive then
        return
    end

    local nodes = self._sortedNodes
    local n = #nodes
    
    local weights = {}
    for _, node in nodes do
        weights[node.name] = 0
    end

    if value <= (nodes[1].min + nodes[1].max) / 2 then
        weights[nodes[1].name] = 1
    elseif value >= (nodes[n].min + nodes[n].max) / 2 then
        weights[nodes[n].name] = 1
    else
        for i = 1, n - 1 do
            local p1 = (nodes[i].min + nodes[i].max) / 2
            local p2 = (nodes[i+1].min + nodes[i+1].max) / 2
            
            if value >= p1 and value <= p2 then
                local alpha = (value - p1) / (p2 - p1)
                local w = dramaticCurve(clamp(alpha, 0, 1))
                weights[nodes[i].name] = 1 - w
                weights[nodes[i+1].name] = w
                break
            end
        end
    end

    for name, w in weights do
        if w > 0.001 then
            local track = self._handler:GetAnimationTrack(name)
            if track and not track.IsPlaying then
                self._handler:PlayAnimation(name, {
                    weight = w,
                    stopOthers = false,
                    loop = true
                })
            end
        end
        
        self._handler:SetWeight(name, w, 0.05)
    end
end

--[[
    Cleans up the BlendController and stops its animations
]]
function BlendController:Destroy()
    self._alive = false

    for _, node in (self._nodes) do
        self._handler:SetWeight(node.name,0)
    end
end

return BlendController
