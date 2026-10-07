const process = require("@std/process")
const tableext = require("@std/tableext")

const function runStep(name: string, command: { string }, options: process.ProcessRunOptions?)
	print(`{name}: {table.concat(command, " ")}`)
	const result = process.run(
		command,
		tableext.combine({
			stdio = "inherit",
		}, options)
	)
	if not result.ok then
		error(`{name} failed to run`)
	end
end

return {
	runStep = runStep,
}
