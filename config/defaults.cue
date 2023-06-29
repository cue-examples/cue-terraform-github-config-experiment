package config

// Overridable global defaults

github?: org?: [_]: config?: {
	_all_company_employees_are_org_members: _ | *true
}

github?: org?: [_]: config?: resource?: github_organization_settings?: self?: {
	default_repository_permission:                                _ | *"none"
	advanced_security_enabled_for_new_repositories:               _ | *false
	dependabot_alerts_enabled_for_new_repositories:               _ | *false
	dependabot_security_updates_enabled_for_new_repositories:     _ | *false
	dependency_graph_enabled_for_new_repositories:                _ | *false
	has_organization_projects:                                    _ | *false
	has_repository_projects:                                      _ | *false
	members_can_create_internal_repositories:                     _ | *false
	members_can_create_pages:                                     _ | *false
	members_can_create_private_pages:                             _ | *false
	members_can_create_private_repositories:                      _ | *false
	members_can_create_public_pages:                              _ | *false
	members_can_create_public_repositories:                       _ | *false
	members_can_create_repositories:                              _ | *false
	members_can_fork_private_repositories:                        _ | *false
	secret_scanning_enabled_for_new_repositories:                 _ | *false
	secret_scanning_push_protection_enabled_for_new_repositories: _ | *false
	web_commit_signoff_required:                                  _ | *false
}

github?: org?: [_]: config?: resource?: github_repository?: [_]: {
	visibility?:             _ | *"private"
	has_discussions?:        _ | *false
	has_downloads?:          _ | *false
	has_issues?:             _ | *false
	has_projects?:           _ | *false
	has_wiki?:               _ | *false
	allow_merge_commit?:     _ | *false
	allow_squash_merge?:     _ | *false
	allow_rebase_merge?:     _ | *true
	delete_branch_on_merge?: _ | *true
}
