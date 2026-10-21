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

it("reports one outer batch and all continuations drained in that batch", function()
	local batches = 0
	local counts = {}
	SignalsScheduler.setHooks({
		onBatch = function()
			batches += 1
		end,
		onContinuations = function(count)
			table.insert(counts, count)
		end,
	})

	batch(function()
		batch(function()
			schedule(function()
				schedule(function() end)
			end)
		end)
	end)
	expect(batches).toEqual(1)
	expect(counts).toEqual({ 2 })

	-- An empty flush has no work to profile.
	flush()
	expect(batches).toEqual(1)
	expect(counts).toEqual({ 2 })
	SignalsScheduler.setHooks(nil)
end)

it("resets scheduler state when a continuation hook errors", function()
	SignalsScheduler.setHooks({
		onContinuations = function()
			error("hook failed")
		end,
	})
	expect(function()
		batch(function()
			schedule(function() end)
		end)
	end).toThrow("hook failed")
	SignalsScheduler.setHooks(nil)

	local ran = false
	batch(function()
		schedule(function()
			ran = true
		end)
	end)
	expect(ran).toEqual(true)
end)

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

it("keeps draining work that is scheduled by another continuation", function()
	local order = {}

	batch(function()
		schedule(function()
			table.insert(order, "first")
			-- Appends to the queue that is being drained right now. An effect
			-- scheduling another effect is the ordinary case, so this has to be
			-- picked up by the drain already in progress. This checks the indexed
			-- traversal contract; generalised iteration also passes this case today.
			schedule(function()
				table.insert(order, "second")
				schedule(function()
					table.insert(order, "third")
				end)
			end)
		end)
	end)

	expect(order).toEqual({ "first", "second", "third" })
end)

if SignalsSchedulerResetStateAfterErrors then
	it("should drain scheduled work after batched work errors", function()
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

	it("should drain pending work after batched work errors", function()
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

		expect(function()
			batch(function()
				error("batch failed")
			end)
		end).toThrow("batch failed")

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

	it("should preserve batch errors when scheduled work also errors", function()
		local ran = false
		local recovered = false

		expect(function()
			batch(function()
				schedule(function()
					ran = true
					error("scheduled work failed")
				end)
				error("batch failed")
			end)
		end).toThrow("batch failed")

		expect(ran).toEqual(true)

		schedule(function()
			recovered = true
		end)
		flush()

		expect(recovered).toEqual(true)
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
