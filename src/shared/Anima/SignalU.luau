--[[
	SignalU V1.25.0 [by iamnotultra3]
	
	MIT LICENSE
	
	https://github.com/Elentium/SignalU
]]
--!strict
local FreeRunnerThread = nil :: thread? -- the free thread variable we will use to then reuse threads when needed

local function AcquireFreeThreadAndCallEventHandler(fn: (...any) -> (), ...: any)
	-- take the free thread and free it only after the function execution is finished
	local Thread = FreeRunnerThread
	FreeRunnerThread = nil
	fn(...)
	FreeRunnerThread = Thread
	Thread = nil
end

local function RunEventHandlerInFreeThread()
	while true do
		AcquireFreeThreadAndCallEventHandler(coroutine.yield())
		-- wait for the coroutine to be resumed
		-- with function and params data to be sent in the `AcquireFreeThreadAndCallEventHandler`
		-- coroutine.yield() returns whatever the coroutine.resume(co, ...) sends so that is how it works
	end
end

-- there were `Defer` and `Spawn` functions before but i later removed the `Defer` function so that is why there is a helper function
local function HelperThreadSpawner(taskfn, fn: (...any) -> (), ...: any)
	-- if there is no Free Thread = create a new one and resume it
	if not FreeRunnerThread then
		FreeRunnerThread = coroutine.create(RunEventHandlerInFreeThread)
		coroutine.resume(FreeRunnerThread :: any) -- start the coroutine loop
	end

	taskfn(FreeRunnerThread :: any, fn, ...) -- we set the type to any to silenece strict type checker
end

local function Spawn(fn: (...any) -> (), ...: any)
	-- logical, needs no explanation
	HelperThreadSpawner(task.spawn, fn, ...)
end

local function GetInstanceFromPath(path: string): Instance?
	-- logical, needs no explanation
	local current = game
	for segment in string.gmatch(path, "[^%.]+") do
		current = current:FindFirstChild(segment)
		if not current then
			return nil
		end
	end
	return current
end

-- Type annotations

export type Signal<T... = ()> = {
	Connect: (self: Signal<T...>, fn: (T...) -> ()) -> Connection,
	Once: (self: Signal<T...>, fn: (T...) -> ()) -> Connection,
	ConnectParallel: (self: Signal<T...>, fn: (T...) -> ()) -> Connection,
	Fire: (self: Signal<T...>, T...) -> (),
	FireAsync: (self: Signal<T...>, T...) -> (),
	Wait: (self: Signal<T...>) -> T...,
	DisconnectAll: (self: Signal<T...>) -> (),
	Destroy: (self: Signal<T...>) -> (),
}

export type Connection = {
	Disconnect: (self: Connection) -> (),
	Connected: boolean,
	Parent: any, -- here we do `any` instead of `Signal` because the strict type checker warns about Recursive type thing
	Next: Connection?,
	Listener: (...any) -> (),
}

-- Main

local Connection = {}
Connection.__index = Connection

function Connection:Disconnect()
	if not self.Connected then
		return
	end
	self.Connected = false

	local parent = self.Parent
	if not parent then
		return
	end

	-- since the connection is disconnected = connect previous connection with the next one
	-- if the connection is at the head = replace the head with the next connection
	if self.Prev then
		self.Prev.Next = self.Next
	else
		parent.Head = self.Next
	end

	if self.Next then
		(self.Next :: any).Prev = self.Prev
	end

	-- cleanup
	self.Next = nil :: any
	self.Prev = nil :: any
	self.Parent = nil :: any
	self.Listener = nil :: any
	-- the :: any is for silencing the strict type checker
end

local Signal = {}
Signal.__index = Signal

local function CreateSignal<T...>(_, strictcheck: boolean?, ...: T...): Signal<T...>
	-- create a new signal object
	local self = setmetatable({}, Signal)
	-- we do `strictcheck == true` to ensure the value is a boolean
	self.StrictCheck = strictcheck == true
	self.Head = nil :: Connection?
	return (self :: any) :: Signal<T...>
end

function Signal:Connect(fn)
	-- create a connetion object
	local connection = setmetatable({}, Connection)
	connection.Listener = fn
	connection.Connected = true
	connection.Parent = self

	-- since we add connections to the end = the newest added connection should be at the tail
	if self.Tail then
		-- if a tail already existed = set the current tail's `Next` reference to the new connection
		-- set the new connection's `Prev` reference to the current Tail
		-- set the new tail as the new connection
		self.Tail.Next = connection
		connection.Prev = self.Tail
		self.Tail = connection :: any
	else
		-- tail did not exist = instant set
		-- we also set the head as the new connection because if there is no tail = there is no head
		self.Head = connection
		self.Tail = connection :: any
	end

	-- return the connection
	return connection
end

function Signal:Once(fn: (...any) -> ())
	-- store the connection variable and disconnect it as soon as the signal is fired
	local conn: any

	conn = self:Connect(function(...)
		fn(...)
		conn:Disconnect()
	end)

	return conn
end

function Signal:ConnectParallel(fn: (...any) -> ())
	if self.StrictCheck then
		-- if the strict check is on = check if the script that uses the module is running under an actor
		-- 2 is the level of how deep to check, the level 1 is the module itself so we do not want this, level 2 is the script that required the module
		-- "s" of debug.info returns a script path like "ServerScriptService.Script"
		local scriptPath = debug.info(coroutine.running(), 2, "s")
		if scriptPath then
			local scriptInstance = GetInstanceFromPath(scriptPath)
			-- check if the script is running under an Actor
			if scriptInstance and scriptInstance:GetActor() == nil then
				warn(`Cannot use ConnectParallel in non-parallel environment ({scriptPath})`)
				return (nil :: any) :: Connection
			end
		end
	end

	return self:Connect(function(...)
		task.desynchronize()
		fn(...)
	end)
end

function Signal:Fire(...: any)
	-- simple linked list iteration
	local node = self.Head
	while node do
		if node.Connected then
			node.Listener(...)
		end
		node = node.Next
	end
end

function Signal:FireAsync(...: any)
	-- same iteration, but this time we run each listener in a separate thread
	local node = self.Head
	while node do
		if node.Connected then
			Spawn(node.Listener, ...)
		end
		node = node.Next
	end
end

function Signal:Wait(): ...any
	-- yield the current thread until a signal has been fired
	local co = coroutine.running()
	local conn: any
	conn = self:Connect(function(...)
		conn:Disconnect()
		-- resume the coroutine with the received data
		coroutine.resume(co, ...)
	end)
	return coroutine.yield()
end

function Signal:DisconnectAll()
	-- we simply get rid of the head and tail references, and the connections automatically get garbage collected
	self.Head = nil
	self.Tail = nil
end

function Signal:Destroy()
	-- fully clear the signal
	self.Head = nil
	self.Tail = nil
	self.StrictCheck = nil :: any
	-- now you cannot call any of the methods since the signal is not affected by the metatable anymore
	setmetatable(self, nil)
end

local SignalU = setmetatable({
	IsSignal = function(object: any)
		return getmetatable(object) == Signal
	end,
}, {
	__call = CreateSignal, -- __call is being triggered whenever we try to call the table as a function
})

return SignalU
