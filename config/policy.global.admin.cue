package config

import (
	"github.com/cue-examples/cue-terraform-github-config-experiment/internal/schemata/terraform"
)

// Config policies that apply to all orgs, and are admin-reviewable if changed

github: org: [orgName=_]: config: terraform.#Config & {

	resource: {

		github_repository?: [_]: {

			// repo resources all set prevent_destroy, so that no terraform plan
			// believes it's acceptable to destroy *and then recreate* a repo.
			// NB **THIS DOES NOT STOP A REPO BEING DELETED IF REMOVED FROM THE CONFIG!**
			lifecycle: prevent_destroy: true

			// repo resources must explicitly set their visibility, so that we can
			// definitely assert against it rather than accepting the github provider's
			// default setting.
			visibility!: "public" | "private"
		}

		github_repository_collaborators?: [_]: {

			// collaborator privs are capped at a maximum of "triage".
			let max_privs = "pull" | "push" | "triage"
			user?: [ ...{
				permission!: max_privs
			}]
			// the only team we grant access to is the employee team, who needs to
			// have "maintain" access in the cue-lang org.
			// TODO: Refactor this sometime.
			team?: [ ...{
				permission!: max_privs | "maintain"
			}]
		}

		github_organization_settings: self: {
			billing_email: "cue-terraform-github-config-experiment-controller+billing@cue.works"
		}

		github_membership: {
			// Orgs have these owner accounts as admin

			myitcv_owner: {
				username: "myitcv"
				role:     "admin"
			}
		}
	}
}
