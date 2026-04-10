export type work = () -> ()

local isContinuing = false

local continuations: { work } = {}

local function batch(fn: work)
	if not isContinuing then
		isContinuing = true

		local ok, err = xpcall(function()
			fn()
			for _, work in continuations do
				work()
			end
		end, debug.traceback)

		table.clear(continuations)
		isContinuing = false

		if not ok then
			error(err, 0)
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
