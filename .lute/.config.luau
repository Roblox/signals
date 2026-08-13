return {
	luau = {
		languagemode = "strict",
		lint = { ["*"] = true },
		linterrors = true,
		aliases = {
			scripts = "../scripts",
			std = "~/.lute/typedefs/1.0.1/std",
		},
	},
}
