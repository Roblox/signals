export type work = () -> ()

local Packages = script.Parent.Parent
local SignalsFlags = require(Packages.SignalsFlags)
local SignalsSchedulerResetStateAfterErrors = SignalsFlags.SignalsSchedulerResetStateAfterErrors

local isContinuing = false

local continuations: { work } = {}

--[[
	Counters for a profiler, supplied by the host rather than required, so nothing
	here knows about the runtime using it. Bound as upvalues rather than read out of
	a table per batch, so a hook that is not installed costs what a constant did.
]]
export type Hooks = {
	onBatch: (() -> ())?,
	onContinuations: ((count: number) -> ())?,
}

local function noop() end

local onBatch: () -> () = noop
local onContinuations: (count: number) -> () = noop
local hooksInstalled = false

local function setHooks(hooks: Hooks?)
	local given: any = if hooks ~= nil then hooks else {}
	onBatch = given.onBatch or noop
	onContinuations = given.onContinuations or noop
	hooksInstalled = next(given) ~= nil
end

--[[
	Both drains below are indexed rather than iterated.

	Work run during a drain can call `schedule`, which appends to the very table being
	walked. Indexed traversal explicitly re-reads its length each time round. This
	keeps the append behavior clear without relying on generalised iteration over
	a table that changes during the loop.
]]
local function runWork()
	local i = 1
	while i <= #continuations do
		continuations[i]()
		i += 1
	end
end

local function runContinuations(): (boolean, any)
	local firstError: any = nil
	local i = 1
	while i <= #continuations do
		local ok, err: any = xpcall(continuations[i], debug.traceback)
		if not ok and firstError == nil then
			firstError = err
		end
		i += 1
	end

	return firstError == nil, firstError
end

local function batch(fn: work)
	if not isContinuing then
		isContinuing = true

		if SignalsSchedulerResetStateAfterErrors then
			local ok, err: any = xpcall(fn, debug.traceback)
			local batchHookOk, batchHookErr: any = true, nil
			if hooksInstalled and #continuations > 0 then
				batchHookOk, batchHookErr = xpcall(onBatch, debug.traceback)
			end
			local continuationsOk, continuationsErr: any = runContinuations()
			local hookOk, hookErr: any = true, nil
			if hooksInstalled and #continuations > 0 then
				hookOk, hookErr = xpcall(onContinuations, debug.traceback, #continuations)
			end

			table.clear(continuations)
			isContinuing = false

			if not ok then
				error(err, 0)
			end
			if not batchHookOk then
				error(batchHookErr, 0)
			end
			if not continuationsOk then
				error(continuationsErr, 0)
			end
			if not hookOk then
				error(hookErr, 0)
			end
		else
			fn()
			if hooksInstalled and #continuations > 0 then
				local hookOk, hookErr: any = xpcall(onBatch, debug.traceback)
				if not hookOk then
					table.clear(continuations)
					isContinuing = false
					error(hookErr, 0)
				end
			end
			runWork()
			local hookOk, hookErr: any = true, nil
			if hooksInstalled and #continuations > 0 then
				hookOk, hookErr = xpcall(onContinuations, debug.traceback, #continuations)
			end

			table.clear(continuations)
			isContinuing = false
			if not hookOk then
				error(hookErr, 0)
			end
		end
	else
		fn()
	end
end

local function flush()
	batch(function() end)
end

local function schedule(work: work)
	table.insert(continuations, work)
end

return {
	batch = batch,
	flush = flush,
	schedule = schedule,
	setHooks = setHooks,
}
