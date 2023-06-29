package config

// SPOT for external dependencies' versions

versions: {
	terraform: {
		core: "1.4.6"
		providers: github: "5.25.1"
	}
	github: {
		actions: {
			runner:                      "ubuntu-20.04"
			"actions/checkout":          "v3"
			"cue-lang/setup-cue":        "0be332bb74c8a2f07821389447ba3163e2da3bfb"
			"hashicorp/setup-terraform": "v2"
			"mshick/add-pr-comment":     "v2.6.1"
		}
	}
	cue: "v0.6.0-alpha.1"
}
