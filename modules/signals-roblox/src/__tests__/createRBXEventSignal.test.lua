local Root = script:FindFirstAncestor("SignalsRoblox")
local Packages = Root.Parent

local JestGlobals = require(Packages.Dev.JestGlobals)
local expect = JestGlobals.expect
local it = JestGlobals.it

local Signals = require(Packages.Signals)

local createRBXEventSignal = require(script.Parent.Parent.createRBXEventSignal)

it("should create a signal from an RBXScriptSignal", function()
	local bindableEvent = Instance.new("BindableEvent")
	local getter: Signals.getter<any>, connection: RBXScriptConnection = createRBXEventSignal(bindableEvent.Event, 0)

	expect(getter).toBeDefined()
	expect(connection).toBeDefined()

	bindableEvent:Fire(1)
	expect(getter(false)).toEqual(1)

	connection:Disconnect()
end)

it("should create a signal from an RBXScriptSignal with an initial value", function()
	local bindableEvent = Instance.new("BindableEvent")
	local getter: Signals.getter<any>, connection: RBXScriptConnection = createRBXEventSignal(bindableEvent.Event, 1)

	expect(getter).toBeDefined()
	expect(connection).toBeDefined()

	expect(getter(false)).toEqual(1)
	bindableEvent:Fire(2)
	expect(getter(false)).toEqual(2)

	connection:Disconnect()
end)

it("should create a signal from an RBXScriptSignal with a filter", function()
	local bindableEvent = Instance.new("BindableEvent")
	local getter: Signals.getter<any>, connection: RBXScriptConnection = createRBXEventSignal(
		bindableEvent.Event,
		0,
		function(value: number)
			return value + 2
		end
	)

	expect(getter).toBeDefined()
	expect(connection).toBeDefined()

	bindableEvent:Fire(1)
	expect(getter(false)).toEqual(3)

	connection:Disconnect()
end)
