local Root = script:FindFirstAncestor("SignalsImplicitScope")
local Packages = Root.Parent

local JestGlobals = require(Packages.Dev.JestGlobals)
local expect = JestGlobals.expect
local it = JestGlobals.it

local SignalsImplicitScope = require(script.Parent.Parent.SignalsImplicitScope)
local createSignal = SignalsImplicitScope.createSignal
local createComputed = SignalsImplicitScope.createComputed
local createEffect = SignalsImplicitScope.createEffect

it("should track signals without explicit scope passing", function()
	local count = 0

	local getValue, setValue = createSignal(0)

	local dispose = createEffect(function()
		getValue()
		count += 1
	end)

	task.wait()
	expect(count).toEqual(1)

	setValue(1)
	task.wait()
	expect(count).toEqual(2)

	setValue(1)
	task.wait()
	expect(count).toEqual(2)

	setValue(2)
	task.wait()
	expect(count).toEqual(3)

	dispose()
	task.wait()

	setValue(3)
	task.wait()
	expect(count).toEqual(3)
end)

it("should track computeds without explicit scope passing", function()
	local count = 0

	local getValue, setValue = createSignal(0)

	local getDerived = createComputed(function()
		return getValue() + 1
	end)

	local dispose = createEffect(function()
		getDerived()
		count += 1
	end)

	task.wait()
	expect(count).toEqual(1)

	setValue(1)
	task.wait()
	expect(count).toEqual(2)

	setValue(1)
	task.wait()
	expect(count).toEqual(2)

	setValue(2)
	task.wait()
	expect(count).toEqual(3)

	dispose()
	task.wait()

	setValue(3)
	task.wait()
	expect(count).toEqual(3)
end)

it("should support untracked signals", function()
	local count = 0

	local getValue1, setValue1 = createSignal(0)
	local getValue2, setValue2 = createSignal(0)

	local dispose = createEffect(function()
		getValue1()
		getValue2(false)
		count += 1
	end)

	task.wait()
	expect(count).toEqual(1)

	setValue1(1)
	task.wait()
	expect(count).toEqual(2)

	setValue2(1)
	task.wait()
	expect(count).toEqual(2)

	setValue2(2)
	task.wait()
	expect(count).toEqual(2)

	setValue1(2)
	task.wait()
	expect(count).toEqual(3)

	dispose()
	task.wait()
end)
