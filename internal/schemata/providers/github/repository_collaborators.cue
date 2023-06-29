package github

import (
	"list"
	"github.com/cue-examples/cue-terraform-github-config-experiment/internal/schemata/terraform"
)

#resources: {
	github_repository_collaborators: {
		terraform.#resource
		repository!: string

		user?: list.MinItems(1)
		user?: [ ...{
			username!:   string
			permission?: "pull" | "push" | "maintain" | "triage" | "admin"
		}]

		team?: list.MinItems(1)
		team?: [ ...{
			team_id!:    string
			permission?: "pull" | "push" | "maintain" | "triage" | "admin"
		}]
	}
}
