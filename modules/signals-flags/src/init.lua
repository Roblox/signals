local _, SignalsSchedulerResetStateAfterErrors = xpcall(function()
	return game:DefineFastFlag("SignalsSchedulerResetStateAfterErrors", false)
end, function()
	return true
end)

return {
	SignalsSchedulerResetStateAfterErrors = SignalsSchedulerResetStateAfterErrors,
}
