package github

import "github.com/cue-examples/cue-terraform-github-config-experiment/internal/schemata/terraform"

#resources: {
	github_team_repository: {
		terraform.#resource
		team_id!:    string
		repository!: string
		permission?: string
	}
}
