local process = require("@std/process")
local runStep = require("@scripts/processExecution").runStep

local placeId = process.env.ROBLOX_PLACE_ID
local universeId = process.env.ROBLOX_UNIVERSE_ID
local apiKey = process.env.ROBLOX_API_KEY

assert(placeId and #placeId > 0, "Missing ROBLOX_PLACE_ID env var")
assert(universeId and #universeId > 0, "Missing ROBLOX_UNIVERSE_ID env var")
assert(apiKey and #apiKey > 0, "Missing ROBLOX_API_KEY env var")

runStep("Run tests", {
	"rocale-cli",
	"run",
	"--placeId",
	placeId,
	"--universeId",
	universeId,
	"--load.project",
	"test.project.json",
	"--script",
	"scripts/test.lua",
	"--lua.globals",
	"__DEV__=true,__ROACT_17_INLINE_ACT__=true,__ROACT_17_MOCK_SCHEDULER__=true",
	"--verbose",
}, { env = { ROBLOX_API_KEY = apiKey } })
