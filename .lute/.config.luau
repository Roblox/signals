return {
	luau = {
		languagemode = "strict",
		lint = { ["*"] = true },
		linterrors = true,
		aliases = {
			scripts = "../scripts",
			std = "~/.lute/typedefs/0.1.0/std",
		},
	},
}
