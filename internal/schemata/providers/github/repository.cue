package github

import "github.com/cue-examples/cue-terraform-github-config-experiment/internal/schemata/terraform"

#resources: {
	github_repository: {
		terraform.#resource
		name!:                        string
		description?:                 string
		homepage_url?:                string
		private?:                     bool
		visibility?:                  string
		has_issues?:                  bool
		has_discussions?:             bool
		has_projects?:                bool
		has_wiki?:                    bool
		is_template?:                 bool
		allow_merge_commit?:          bool
		allow_squash_merge?:          bool
		allow_rebase_merge?:          bool
		allow_auto_merge?:            bool
		squash_merge_commit_title?:   string
		squash_merge_commit_message?: string
		merge_commit_title?:          string
		merge_commit_message?:        string
		delete_branch_on_merge?:      bool
		has_downloads?:               bool
		auto_init?:                   bool
		gitignore_template?:          string
		license_template?:            string
		archived?:                    bool
		archive_on_destroy?:          bool
		topics?: [ ...string]
		vulnerability_alerts?:                    bool
		ignore_vulnerability_alerts_during_read?: bool
		allow_update_branch?:                     bool

		pages?: {
			source!: {
				branch!: string
				path?:   string
			}
			cname?: string
		}

		security_and_analysis?: {
			advanced_security?: {
				status!: "enabled" | "disabled"
			}
			secret_scanning?: {
				status!: "enabled" | "disabled"
			}
			secret_scanning_push_protection?: {
				status!: "enabled" | "disabled"
			}
		}

		template?: {
			owner!:                string
			repository!:           string
			include_all_branches?: bool
		}
	}
}
