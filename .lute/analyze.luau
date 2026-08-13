const runStep = require("@scripts/processExecution").runStep

const function getTargetPaths()
	return "./.lute", "./modules", "./scripts", "./src"
end

runStep("Selene check", { "selene", getTargetPaths() })
runStep("Style check", { "stylua", "-c", getTargetPaths() })
runStep(
	"Type check",
	{ "luau-lsp", "analyze", "--defs", "globalTypes.d.luau", "--sourcemap", "sourcemap.json", "modules" }
)
