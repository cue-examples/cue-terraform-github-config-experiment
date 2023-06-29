package config

import (
	provider_github "github.com/cue-examples/cue-terraform-github-config-experiment/internal/schemata/providers/github"
)

// Schemata imposed internally (by this system) and externally (by Terraform
// and its components)

////////////////////////////////////////////////////////////////
// Constraints implicitly imposed by this project's CUE use ////
////////////////////////////////////////////////////////////////

company?: #company
#company: employees?: [string]: login: github!: string

versions?: #versions
#versions: {
	terraform?: {
		core?: #version
		providers?: [string]: #version
	}
	github?: actions?: [string]: #version
	cue?: #version
}
#version: string

github?: actions?: workflow?: [FilenameWithoutDotYmlSuffix=string]: _

// github.org.[_] contains information for a single GitHub Organization
github?: org?: [OrgName=string]: config?: #terraform_input & {
	_all_company_employees_are_org_members!: bool
	resource?: {
		github_repository?: [Name=_]: name!:                          Name
		github_repository_collaborators?: [Name=string]: repository!: Name
		github_organization_settings?: self?: _
		// Collaborator and bot access (currently) have distinct Terraform identifiers,
		// which requires them to be distinguished.
		_non_org_member_access?: {
			collaborator?: #access_list
			bot?:          #access_list
			#access_list: {
				[Username=string]: [Repo=string]: "pull" | "push" | "triage"
				#ID: string
			}
		}
	}
}

// target.terraform.github.org.[_] is the Terraform-acceptable input for a
// single GitHub Organization
target?: terraform?: github?: org?: [string]: config?: #terraform_input & {
	resource?: [string]: #terraform_resource
	// https://developer.hashicorp.com/terraform/language/syntax/configuration#identifiers
	#terraform_resource: [=~"^[-a-zA-Z_][-a-zA-Z_0-9]*$"]: _
}

////////////////////////////////////////////////////////////////
// Terraform-defined input schema, collated from several docs //
////////////////////////////////////////////////////////////////
#terraform_input: {// https://developer.hashicorp.com/terraform/language/syntax/json
	resource?: {// https://developer.hashicorp.com/terraform/language/resources/syntax
		[ResourceType=string]: [ResourceIdentifier=string]: {
			#resource_meta_arguments
			...
		}
		github_membership?: [_]:               provider_github.#resources.github_membership
		github_organization_settings?: [_]:    provider_github.#resources.github_organization_settings
		github_repository_collaborators?: [_]: provider_github.#resources.github_repository_collaborators
		github_team?: [_]:                     provider_github.#resources.github_team
		github_team_membership?: [_]:          provider_github.#resources.github_team_membership
		github_team_repository?: [_]:          provider_github.#resources.github_team_repository
		github_repository?: [_]:               provider_github.#resources.github_repository
	}

	terraform?: {// https://developer.hashicorp.com/terraform/language/settings
		cloud?: {// https://developer.hashicorp.com/terraform/cli/cloud/settings#the-cloud-block
			organization!: string
			workspaces?:   {
				tags!: [string, ...string]
			} | {
				name!: string
			}
			hostname?: string
			token?:    string
		}
		required_providers?: [ProviderName=string]: {// https://developer.hashicorp.com/terraform/language/providers/requirements#requiring-providers
			source?:  string
			version?: string
		}
		required_version?: string
	}

	provider?: [ProviderName=string]: {// https://developer.hashicorp.com/terraform/language/providers/configuration
		alias?: string
		...
	}

	variable?: [Name=string]: {// https://developer.hashicorp.com/terraform/language/values/variables
		default?:     _
		type?:        string
		description?: string
		validation?:  _
		sensitive?:   bool
		nullable?:    bool
	}

	moved?: [ ...{from: string, to: string}]

	#resource_meta_arguments: {
		for_each?: _      // https://developer.hashicorp.com/terraform/language/meta-arguments/for_each
		count?:    int    // https://developer.hashicorp.com/terraform/language/meta-arguments/count
		provider?: string // https://developer.hashicorp.com/terraform/language/meta-arguments/resource-provider
		lifecycle?: {// https://developer.hashicorp.com/terraform/language/meta-arguments/lifecycle
			create_before_destroy?: bool
			prevent_destroy?:       bool
			ignore_changes?: [...string]
			replace_triggered_by?: [...string]
			#condition?: {// https://developer.hashicorp.com/terraform/language/expressions/custom-conditions
				condition!:     string
				error_message!: string
			}
			precondition?:  #condition
			postcondition?: #condition
		}
		depends_on?: [...string] // https://developer.hashicorp.com/terraform/language/meta-arguments/depends_on
		provisioner?: [string]: {...} // https://developer.hashicorp.com/terraform/language/resources/provisioners/syntax
	}
}
