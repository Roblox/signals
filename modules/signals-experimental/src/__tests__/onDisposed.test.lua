local Root = script:FindFirstAncestor("SignalsExperimental")
local Packages = Root.Parent

local JestGlobals = require(Packages.Dev.JestGlobals)
local expect = JestGlobals.expect
local it = JestGlobals.it

local Signals = require(Packages.Signals)
local createSignal = Signals.createSignal
local createComputed = Signals.createComputed
local createEffect = Signals.createEffect

local onDisposed = require(script.Parent.Parent.onDisposed)

it("should call disposed when signal changes", function()
	local counter = 0

	local getValue, setValue = createSignal(1)

	local dispose = createEffect(function(scope)
		getValue(scope)
		onDisposed(scope, function()
			counter += 1
		end)
	end)

	task.wait()
	expect(counter).toEqual(0)

	setValue(2)
	task.wait()
	expect(counter).toEqual(1)

	setValue(2) -- value did not change!
	task.wait()
	expect(counter).toEqual(1)

	dispose()
	task.wait()
	expect(counter).toEqual(2)
end)

it("should call disposed irrespective of call order", function()
	local counter = 0

	local getValue, setValue = createSignal(1)

	local dispose = createEffect(function(scope)
		onDisposed(scope, function()
			counter += 1
		end)
		-- here, getValue is called after onDisposed
		getValue(scope)
	end)

	task.wait()
	expect(counter).toEqual(0)

	setValue(2)
	task.wait()
	expect(counter).toEqual(1)

	setValue(2) -- value did not change!
	task.wait()
	expect(counter).toEqual(1)

	dispose()
	task.wait()
	expect(counter).toEqual(2)
end)

it("should call disposed when a computed changes", function()
	local counter = 0

	local getValue, setValue = createSignal(1)

	local getDerived = createComputed(function(scope)
		onDisposed(scope, function()
			counter += 1
		end)
		return getValue(scope)
	end)

	task.wait()
	expect(counter).toEqual(0)

	getDerived(false)
	task.wait()
	expect(counter).toEqual(0)

	setValue(2)
	getDerived(false)
	task.wait()
	expect(counter).toEqual(1)

	setValue(2) -- value did not change!
	getDerived(false)
	task.wait()
	expect(counter).toEqual(1)

	setValue(3)
	getDerived(false)
	task.wait()
	expect(counter).toEqual(2)
end)

it("should call disposed when a transitive computed changes", function()
	local counter1 = 0
	local counter2 = 0

	local getValue1, setValue1 = createSignal(1)
	local getValue2, setValue2 = createSignal(1)
	local getValue3, setValue3 = createSignal(1)

	local getDerived1 = createComputed(function(scope)
		getValue1(scope)
		onDisposed(scope, function()
			counter1 += 1
		end)
		return getValue3(scope)
	end)

	local getDerived2 = createComputed(function(scope)
		getValue2(scope)
		onDisposed(scope, function()
			counter2 += 1
		end)
		return getDerived1(scope)
	end)

	task.wait()
	expect(counter1).toEqual(0)
	expect(counter2).toEqual(0)

	getDerived2(false)
	task.wait()
	expect(counter1).toEqual(0)
	expect(counter2).toEqual(0)

	setValue1(2)
	getDerived2(false)
	task.wait()
	expect(counter1).toEqual(1)
	expect(counter2).toEqual(0)

	setValue1(2) -- value did not change!
	getDerived2(false)
	task.wait()
	expect(counter1).toEqual(1)
	expect(counter2).toEqual(0)

	setValue1(3)
	getDerived2(false)
	task.wait()
	expect(counter1).toEqual(2)
	expect(counter2).toEqual(0)

	setValue2(2)
	getDerived2(false)
	task.wait()
	expect(counter1).toEqual(2)
	expect(counter2).toEqual(1)

	setValue3(2)
	getDerived2(false)
	task.wait()
	expect(counter1).toEqual(3)
	expect(counter2).toEqual(2)
end)
