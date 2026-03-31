local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:FindFirstChild("Packages") or error("Packages folder not found")

local JestPackages = Packages:QueryDescendants("ModuleScript#Jest")
assert(#JestPackages > 0, "No Jest packages found")
local Jest = require(JestPackages[1])

local roots = Packages:QueryDescendants(`[Name="jest.config"]`)

assert(#roots > 0, "No test roots found")
print(`Running tests for {#roots} packages...`)

local status, result = Jest.runCLI(Packages, {
	ci = true,
	verbose = false,
}, roots):awaitStatus()

if status == "Rejected" then
	print(result)
	error("Tests failed")
elseif result.results.numFailedTestSuites > 0 or result.results.numFailedTests > 0 then
	error(`Tests failed: {result.results.numFailedTests} failed tests, {result.results.numFailedTestSuites} failed suites`)
end
