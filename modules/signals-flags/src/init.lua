local _, SignalsReactUseMutableSource = xpcall(function()
	return game:DefineFastFlag("SignalsReactUseMutableSource", false)
end, function()
	return true
end)

local _, SignalsSchedulerResetStateAfterErrors = xpcall(function()
	return game:DefineFastFlag("SignalsSchedulerResetStateAfterErrors", false)
end, function()
	return true
end)

return {
	SignalsReactUseMutableSource = SignalsReactUseMutableSource,
	SignalsSchedulerResetStateAfterErrors = SignalsSchedulerResetStateAfterErrors,
}
