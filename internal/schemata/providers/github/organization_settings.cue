package github

import "github.com/cue-examples/cue-terraform-github-config-experiment/internal/schemata/terraform"

#resources: {
	github_organization_settings: {
		terraform.#resource
		billing_email!:                                                string
		company?:                                                      string
		blog?:                                                         string
		email?:                                                        string
		twitter_username?:                                             string
		location?:                                                     string
		name?:                                                         string
		description?:                                                  string
		has_organization_projects?:                                    bool
		has_repository_projects?:                                      bool
		default_repository_permission?:                                string
		members_can_create_repositories?:                              bool
		members_can_create_public_repositories?:                       bool
		members_can_create_private_repositories?:                      bool
		members_can_create_internal_repositories?:                     bool
		members_can_create_pages?:                                     bool
		members_can_create_public_pages?:                              bool
		members_can_create_private_pages?:                             bool
		members_can_fork_private_repositories?:                        bool
		web_commit_signoff_required?:                                  bool
		advanced_security_enabled_for_new_repositories?:               bool
		dependabot_alerts_enabled_for_new_repositories?:               bool
		dependabot_security_updates_enabled_for_new_repositories?:     bool
		dependency_graph_enabled_for_new_repositories?:                bool
		secret_scanning_enabled_for_new_repositories?:                 bool
		secret_scanning_push_protection_enabled_for_new_repositories?: bool
	}
}
