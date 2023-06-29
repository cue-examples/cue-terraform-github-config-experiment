package github

import "github.com/cue-examples/cue-terraform-github-config-experiment/internal/schemata/terraform"

#resources: {
	github_team: {
		terraform.#resource
		name!:                      string
		description?:               string
		privacy?:                   string
		parent_team_id?:            string | null
		ldap_dn?:                   string
		create_default_maintainer?: bool
	}
}
