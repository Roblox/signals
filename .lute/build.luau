const runStep = require("@scripts/processExecution").runStep

runStep("Install packages", { "wally", "install" })
runStep("Generate sourcemap", { "rojo", "sourcemap", "test.project.json", "-o", "sourcemap.json" })
runStep(
	"Fetch types",
	{ "curl", "-s", "-O", "https://raw.githubusercontent.com/JohnnyMorganz/luau-lsp/master/scripts/globalTypes.d.luau" }
)
