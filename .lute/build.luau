local runStep = require("@scripts/processExecution").runStep

runStep("Install packages", { "wally", "install" })
runStep("Generate sourcemap", { "rojo", "sourcemap", "default.project.json", "-o", "sourcemap.json" })

runStep("Export types", { "wally-package-types", "--sourcemap", "sourcemap.json", "Packages" })
runStep("Export types", { "wally-package-types", "--sourcemap", "sourcemap.json", "DevPackages" })
runStep("Fetch types", { "curl", "-s", "-O", "https://raw.githubusercontent.com/JohnnyMorganz/luau-lsp/master/scripts/globalTypes.d.luau" })

return {}
