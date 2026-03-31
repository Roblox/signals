local Root = script:FindFirstAncestor("SignalsExperimental")
local Packages = Root.Parent

local JestGlobals = require(Packages.Dev.JestGlobals)
local expect = JestGlobals.expect
local it = JestGlobals.it

local Signals = require(Packages.Signals)
local createSignal = Signals.createSignal

local createReducer = require(script.Parent.Parent.createReducer)

it("should allow tracking the last seen value", function()
	local getCurrent, setCurrent = createSignal(nil :: number?)

	local getLastSeen = createReducer(function(scope, previous: number?)
		return getCurrent(scope) or previous
	end, nil)

	expect(getLastSeen(false)).toEqual(nil)

	setCurrent(0)
	expect(getLastSeen(false)).toEqual(0)

	setCurrent(1)
	expect(getLastSeen(false)).toEqual(1)

	setCurrent(nil)
	expect(getLastSeen(false)).toEqual(1)

	setCurrent(2)
	expect(getLastSeen(false)).toEqual(2)

	setCurrent(nil)
	expect(getLastSeen(false)).toEqual(2)
end)
