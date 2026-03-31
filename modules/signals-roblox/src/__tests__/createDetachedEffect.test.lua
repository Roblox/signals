local Root = script:FindFirstAncestor("SignalsRoblox")
local Packages = Root.Parent

local JestGlobals = require(Packages.Dev.JestGlobals)
local expect = JestGlobals.expect
local it = JestGlobals.it

local Signals = require(Packages.Signals)
local createSignal = Signals.createSignal

local createDetachedEffect = require(script.Parent.Parent.createDetachedEffect)

local function waitFrames(n: number)
	for _ = 1, n do
		task.wait()
	end
end

it("should support calling dispose from within the effect directly and only", function()
	local counter = 0

	local getValue, setValue = createSignal(1)

	createDetachedEffect(function(scope, dispose)
		if getValue(scope) >= 5 then
			dispose()
		else
			counter += 1
		end
	end)

	waitFrames(10)
	expect(counter).toEqual(1)
	waitFrames(10)
	expect(counter).toEqual(1)

	setValue(2)
	waitFrames(10)
	expect(counter).toEqual(2)

	setValue(2)
	waitFrames(10)
	expect(counter).toEqual(2)

	setValue(3)
	waitFrames(10)
	expect(counter).toEqual(3)

	setValue(4)
	waitFrames(10)
	expect(counter).toEqual(4)

	setValue(5) -- disposed here!
	waitFrames(10)
	expect(counter).toEqual(4)

	setValue(1)
	waitFrames(10)
	expect(counter).toEqual(4)
end)
