local _, SignalsReactUseMutableSource = xpcall(function()
	return game:DefineFastFlag("SignalsReactUseMutableSource", false)
end, function()
	return true
end)

return {
	SignalsReactUseMutableSource = SignalsReactUseMutableSource,
}
