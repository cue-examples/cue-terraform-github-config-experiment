package github

import "github.com/cue-examples/cue-terraform-github-config-experiment/internal/schemata/terraform"

#resources: {
	github_team_membership: {
		terraform.#resource
		team_id!:  string
		username!: string
		role?:     string
	}
}
