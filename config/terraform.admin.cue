package config

// Constraints on Terraform's runtime config, admin-reviewable if changed

github: org: [orgName=_]: config: {
	provider: github: {
		// This is the scope/namespace under which GitHub API access operates.
		// Failure to set this to the name of the org being managed would be
		// **disastrous**!
		owner!: orgName
	}
	terraform: cloud: {
		organization!: "cue-terraform-github-config-experiment"
		workspaces: tags!: ["service:github", "org:\(orgName)"]
	}
}
