export type work = () -> ()

local Packages = script.Parent.Parent
local SignalsFlags = require(Packages.SignalsFlags)
local SignalsSchedulerResetStateAfterErrors = SignalsFlags.SignalsSchedulerResetStateAfterErrors

local isContinuing = false

local continuations: { work } = {}

--[[
	Counters for a profiler, supplied by the host rather than required, so nothing here
	knows about the runtime using it. Bound as upvalues rather than read out of a table
	per batch, so a hook that is not installed costs what a constant did.
]]
export type Hooks = {
	onBatch: (() -> ())?,
	onContinuations: ((count: number) -> ())?,
}

local function noop() end

local onBatch: () -> () = noop
local onContinuations: (count: number) -> () = noop

local function setHooks(hooks: Hooks?)
	local given: any = if hooks ~= nil then hooks else {}
	onBatch = given.onBatch or noop
	onContinuations = given.onContinuations or noop
end

--[[
	Both drains below are indexed rather than iterated.

	Work run during a drain can call `schedule`, which appends to the very table being
	walked. Generalised iteration is not guaranteed to reach entries added after it
	started, so an effect scheduled by another effect could be dropped for the rest of
	the batch -- and `table.clear` below would then discard it entirely. Indexing by
	position re-reads the length each time round and picks those up.
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
		onBatch()
		isContinuing = true

		if SignalsSchedulerResetStateAfterErrors then
			local ok, err: any = xpcall(fn, debug.traceback)
			onContinuations(#continuations)
			local continuationsOk, continuationsErr: any = runContinuations()

			table.clear(continuations)
			isContinuing = false

			if not ok then
				error(err, 0)
			end
			if not continuationsOk then
				error(continuationsErr, 0)
			end
		else
			fn()
			onContinuations(#continuations)
			runWork()

			table.clear(continuations)
			isContinuing = false
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
