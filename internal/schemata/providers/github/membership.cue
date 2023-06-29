package github

import "github.com/cue-examples/cue-terraform-github-config-experiment/internal/schemata/terraform"

#resources: {
	github_membership: {
		terraform.#resource
		username!: string
		role?:     string
	}
}
