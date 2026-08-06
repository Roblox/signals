export type work = () -> ()

local Packages = script.Parent.Parent
local SignalsFlags = require(Packages.SignalsFlags)
local SignalsSchedulerResetStateAfterErrors = SignalsFlags.SignalsSchedulerResetStateAfterErrors

local isContinuing = false

local continuations: { work } = {}

--[[
	Both drains below are indexed rather than iterated.

	Work run during a drain can call `schedule`, which appends to the very table being
	walked. Generalised iteration is not guaranteed to reach entries added after it
	started, so an effect scheduled by another effect could be dropped for the rest of
	the batch -- and `table.clear` below would then discard it entirely. Indexing by
	position re-reads the length each time round and picks those up.
]]
local function runWork(fn: work)
	fn()
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
			runWork(fn)

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
}
