local _, SignalsSchedulerResetStateAfterErrors = xpcall(function()
	return game:DefineFastFlag("SignalsSchedulerResetStateAfterErrors", false)
end, function()
	return true
end)

local _, SignalsEffectCleanup = xpcall(function()
	return game:DefineFastFlag("SignalsEffectCleanup", false)
end, function()
	return true
end)

return {
	SignalsSchedulerResetStateAfterErrors = SignalsSchedulerResetStateAfterErrors,
	SignalsEffectCleanup = SignalsEffectCleanup,
}
