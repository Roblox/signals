local process = require("@std/process")
local tableext = require("@std/tableext")

local function runStep(name: string, command: { string }, options: process.ProcessRunOptions?)
	print(`{name}: {table.concat(command, " ")}`)
	local result = process.run(command, tableext.combine({
		stdio = "inherit",
	}, options))
	if not result.ok then
		error(`{name} failed to run`)
	end
end

return {
	runStep = runStep,
}
