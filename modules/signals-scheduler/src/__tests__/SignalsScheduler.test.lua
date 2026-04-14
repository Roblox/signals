local Root = script:FindFirstAncestor("SignalsScheduler")
local Packages = Root.Parent

local JestGlobals = require(Packages.Dev.JestGlobals)
local expect = JestGlobals.expect
local it = JestGlobals.it

local SignalsFlags = require(Packages.SignalsFlags)
local SignalsSchedulerResetStateAfterErrors = SignalsFlags.SignalsSchedulerResetStateAfterErrors

local SignalsScheduler = require(script.Parent.Parent.SignalsScheduler)
local batch = SignalsScheduler.batch
local flush = SignalsScheduler.flush
local schedule = SignalsScheduler.schedule

it("should schedule work without running until flushed", function()
	local counters = {
		foo = 0,
		bar = 0,
	}

	local function foo()
		counters.foo += 1
	end

	local function bar()
		counters.bar += 1
	end

	schedule(foo)
	schedule(bar)

	task.wait()

	expect(counters).toEqual({
		foo = 0,
		bar = 0,
	})

	flush()

	expect(counters).toEqual({
		foo = 1,
		bar = 1,
	})

	schedule(foo)
	schedule(foo)
	schedule(foo)
	schedule(bar)

	expect(counters).toEqual({
		foo = 1,
		bar = 1,
	})

	flush()

	expect(counters).toEqual({
		foo = 4,
		bar = 2,
	})
end)

it("should support incremental scheduling", function()
	local counters = {
		foo = 0,
		bar = 0,
		baz = 0,
	}

	local function foo()
		counters.foo += 1
	end

	local function bar()
		schedule(foo)
		counters.bar += 1
	end

	local function baz()
		schedule(bar)
		counters.baz += 1
	end

	schedule(baz)

	task.wait()

	expect(counters).toEqual({
		foo = 0,
		bar = 0,
		baz = 0,
	})

	flush()

	expect(counters).toEqual({
		foo = 1,
		bar = 1,
		baz = 1,
	})
end)

it("should support batching scheduled work", function()
	local counters = {
		foo = 0,
		bar = 0,
	}

	local function foo()
		counters.foo += 1
	end

	local function bar()
		counters.bar += 1
	end

	batch(function()
		schedule(foo)
		schedule(bar)
	end)

	task.wait()

	expect(counters).toEqual({
		foo = 1,
		bar = 1,
	})

	flush()

	expect(counters).toEqual({
		foo = 1,
		bar = 1,
	})
end)

if SignalsSchedulerResetStateAfterErrors then
	it("should reset after batched work errors", function()
		local counters = {
			foo = 0,
			bar = 0,
		}

		local function foo()
			counters.foo += 1
		end

		local function bar()
			counters.bar += 1
		end

		expect(function()
			batch(function()
				schedule(foo)
				error("batch failed")
			end)
		end).toThrow("batch failed")

		expect(counters).toEqual({
			foo = 0,
			bar = 0,
		})

		schedule(bar)
		flush()

		expect(counters).toEqual({
			foo = 0,
			bar = 1,
		})
	end)

	it("should reset after scheduled work errors", function()
		local counters = {
			foo = 0,
			bar = 0,
		}

		local function foo()
			counters.foo += 1
		end

		local function bar()
			counters.bar += 1
		end

		expect(function()
			batch(function()
				schedule(function()
					error("first scheduled work failed")
				end)
				schedule(foo)
				schedule(function()
					error("second scheduled work failed")
				end)
			end)
		end).toThrow("first scheduled work failed")

		expect(counters).toEqual({
			foo = 1,
			bar = 0,
		})

		schedule(bar)
		flush()

		expect(counters).toEqual({
			foo = 1,
			bar = 1,
		})
	end)
end
