local runStep = require("@scripts/processExecution").runStep

runStep("Selene check", { "selene", "modules" })
runStep("Style check", { "stylua", "-c", "modules" })
runStep(
	"Type check",
	{ "luau-lsp", "analyze", "--defs", "globalTypes.d.luau", "--sourcemap", "sourcemap.json", "modules" }
)
