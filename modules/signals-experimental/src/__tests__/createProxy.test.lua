local Root = script:FindFirstAncestor("SignalsExperimental")
local Packages = Root.Parent

local JestGlobals = require(Packages.Dev.JestGlobals)
local expect = JestGlobals.expect
local it = JestGlobals.it

local Signals = require(Packages.Signals)
local createEffect = Signals.createEffect

local SignalsScheduler = require(Packages.SignalsScheduler)
local batch = SignalsScheduler.batch

local createProxy = require(script.Parent.Parent.createProxy)

it("should crash when attempting to write to a read-only instance", function()
	local proxy = createProxy({
		foo = 123,
	})

	local store = proxy()

	expect(function()
		store.foo += 1
	end).toThrow()

	expect(function()
		store.baz = 1
	end).toThrow()
end)

it("should not re-execute if nothing is read", function()
	local count = 0

	local proxy = createProxy({
		foo = 1,
		bar = 100,
		baz = nil :: number?,
	})

	local dispose = createEffect(function(scope)
		count += 1
		proxy(scope)
	end)

	task.wait()
	expect(count).toEqual(1)

	proxy.foo += 5
	task.wait()
	expect(count).toEqual(1)

	proxy.bar += 5
	task.wait()
	expect(count).toEqual(1)

	proxy.foo += 5
	task.wait()
	expect(count).toEqual(1)

	proxy.baz = 5
	task.wait()
	expect(count).toEqual(1)

	proxy.baz = nil
	task.wait()
	expect(count).toEqual(1)

	dispose()
	proxy.bar += 5
	task.wait()
	expect(count).toEqual(1)
end)

it("should only notify as changed when accessed fields are changed", function()
	local proxy = createProxy({
		foo = 1,
		bar = 100,
	})

	local countFoo = 0

	local disposeFoo = createEffect(function(scope)
		countFoo += 1
		local _ = proxy(scope).foo
	end)

	task.wait()
	expect(countFoo).toEqual(1)
	expect(proxy().foo).toEqual(1)

	proxy.foo += 5
	task.wait()
	expect(countFoo).toEqual(2)
	expect(proxy().foo).toEqual(6)

	proxy.bar += 5
	task.wait()
	expect(countFoo).toEqual(2)
	expect(proxy().foo).toEqual(6)

	local countBar = 0
	local disposeBar = createEffect(function(scope)
		countBar += 1
		local _ = proxy(scope).bar
	end)

	task.wait()
	expect(countFoo).toEqual(2)
	expect(proxy().foo).toEqual(6)
	expect(countBar).toEqual(1)
	expect(proxy().bar).toEqual(105)

	proxy.bar += 5
	task.wait()
	expect(countFoo).toEqual(2)
	expect(proxy().foo).toEqual(6)
	expect(countBar).toEqual(2)
	expect(proxy().bar).toEqual(110)

	proxy.foo += 5
	task.wait()
	expect(countFoo).toEqual(3)
	expect(proxy().foo).toEqual(11)
	expect(countBar).toEqual(2)
	expect(proxy().bar).toEqual(110)

	proxy.foo += 5
	proxy.bar += 5
	task.wait()
	expect(countFoo).toEqual(4)
	expect(proxy().foo).toEqual(16)
	expect(countBar).toEqual(3)
	expect(proxy().bar).toEqual(115)

	disposeFoo()
	disposeBar()
end)

it("should support iterating over elements", function()
	local proxy = createProxy({
		foo = 1,
		bar = 100,
	} :: {
		foo: number,
		bar: number,
		baz: number?,
	})

	local count = 0
	local dispose = createEffect(function(scope)
		count += 1
		for key in proxy(scope) do
			local _ = key
		end
	end)

	task.wait()
	expect(count).toEqual(1)

	proxy.baz = 5
	task.wait()
	expect(count).toEqual(2)

	assert(proxy.baz, "non-nil")
	proxy.baz += 5
	task.wait()
	expect(count).toEqual(3)

	proxy.baz = nil
	task.wait()
	expect(count).toEqual(4)

	batch(function()
		proxy.foo += 5
		proxy.bar += 5
	end)
	task.wait()
	expect(count).toEqual(5)

	dispose()
end)

it("should support removing elements", function()
	local proxy = createProxy({} :: { [string]: number? })

	local count = 0
	local dispose = createEffect(function(scope)
		count += 1
		local _ = proxy(scope).foo
	end)

	task.wait()
	expect(count).toEqual(1)

	proxy.foo = nil
	task.wait()
	expect(count).toEqual(1)

	proxy.foo = 123
	task.wait()
	expect(count).toEqual(2)

	proxy.foo = 456
	task.wait()
	expect(count).toEqual(3)

	proxy.foo = nil
	task.wait()
	expect(count).toEqual(4)

	dispose()
end)

it("should tracking length", function()
	local proxy = createProxy({} :: { [number]: boolean?, foo: string? })

	local count = 0
	local dispose = createEffect(function(scope)
		count += 1
		local _ = #proxy(scope)
	end)

	task.wait()
	expect(count).toEqual(1)

	proxy.foo = "true"
	task.wait()
	expect(count).toEqual(1)

	proxy[1] = true
	task.wait()
	expect(count).toEqual(2)

	proxy[1] = false
	task.wait()
	expect(count).toEqual(2)

	proxy[2] = nil
	task.wait()
	expect(count).toEqual(2)

	proxy[2] = true
	task.wait()
	expect(count).toEqual(3)

	proxy[3] = true
	task.wait()
	expect(count).toEqual(4)

	proxy.foo = nil
	task.wait()
	expect(count).toEqual(4)

	proxy[2] = nil
	task.wait()
	expect(count).toEqual(5)

	proxy[1] = nil
	task.wait()
	expect(count).toEqual(6)

	proxy[3] = nil
	task.wait()
	expect(count).toEqual(7)

	dispose()
end)
