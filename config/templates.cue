package config

// Resources and settings that are templated into all orgs

// All github_repository resources have identical CUE identifiers and
// user-visible names on GitHub
github: org: [_]: config: resource: {
	github_repository?: [Name=string]: {
		name: Name
	}
}
// Every CUE-addressable resource gets a pair of fields added:
// - #tfid: the translated identifier (e.g. `_foo_repo_xyz`)
// - #tfref: the path by which it can be addressed via Terraform's
//   runtime expression references (e.g. `github_repository._foo_repo_xyz`)
github: org: [_]: config: resource: {
	[resource_type=_]: [cue_resource_name=string]: {
		#tfid:  "\({target.terraform.#Identifier.adapt & {#in: cue_resource_name}}.#out)"
		#tfref: "\(resource_type).\(#tfid)"
	}
}

// Orgs that set config._all_company_employees_are_org_members template
// resources across several different resource types
github: org: [_]: config: resource: {
	if config._all_company_employees_are_org_members {
		// Add all employees to the org's membership
		github_membership: {
			for name, employee in company.employees
			let id = employee.login.github {
				(id): {
					username: id
					role:     *"member" | "admin"
				}
			}
		}
		// Create the team in which all employees will be *members|maintainers
		github_team: company_employees: {
			name:                      "Company Employees Team"
			description:               "All company employees [terraform-managed]"
			privacy:                   "secret"
			create_default_maintainer: false
		}
		// Add all employees to the employee team
		github_team_membership: {
			for name, employee in company.employees
			let id = employee.login.github {
				"members_company_employees_team_\(id)": {
					team_id:  "${\(github_team.company_employees.#tfref).id}"
					username: id
					role:     *"member" | "maintainer"
				}
			}
		}

		// all repos grant access to the company employees team
		if resource.github_repository != _|_ {
			for repo_name, _ in resource.github_repository {
				github_repository_collaborators: (repo_name): {
					repository: repo_name
					team: [{
						team_id:    "${ \( resource.github_team.company_employees.#tfref ).slug }"
						permission: *"push" | string
					}]
					depends_on: [ resource.github_repository[repo_name].#tfref]
				}
			}
		}
	}
}

// For each type of _non_org_member_access that exists, grant the appropriate
// access to the username specified
github: org: [_]: config: resource: {

	_non_org_member_access: _
	// `_non_org_member_access` gives us a user-centric view of outside
	// collaborators' access permissions, which is better for audit and ops-y
	// purposes.
	// `github_repository_collaborators` needs a repo-centric view to assemble
	// its `user` list of permissions, and that's `inverted_access_struct`.
	// We'll probably be able to instantiate our
	// `github_repository_collaborators` resources inside *this* loop (and delete
	// the loop below this one) as & when & if CUE lists ever become open.
	// But, right now, we need to create this struct to be iterated over below.
	let inverted_access_struct = {
		for access_type, access_list in _non_org_member_access
		for user_name, user_access in access_list
		for repo_name, user_permission in user_access {
			(repo_name): (user_name): user_permission
		}
	}

	for repo_name, access_list in inverted_access_struct {
		github_repository_collaborators: (repo_name): {
			repository: repo_name
			user: [ for user_name, user_permission in access_list {
				{
					username:   user_name
					permission: user_permission
				}
			}]
		}
	}
}
