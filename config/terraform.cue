package config

// Terraform's runtime config, templated into all orgs

github: {
	org: [orgName=_]: config: {
		provider: github: {
			token: "${var.provider_github_token}"
			owner: orgName
		}
		variable: {
			provider_github_token: {
				sensitive: true
				type:      "string" // '"string"', not 'string'. This is a TF type assertion, not CUE.
			}
		}
		terraform: github.terraform & {
			cloud: {
				organization: "cue-terraform-github-config-experiment"
				workspaces: tags: ["service:github", "org:\(orgName)"]
			}
		}
	}
	terraform: {
		required_providers: {
			github: {
				source:  "integrations/github"
				version: versions.terraform.providers.github
			}
		}
		// The version of terraform installed inside CI is precisely pinned in
		// the GHA workflow file, from the same source used here.
		// This version constraint needs to be more relaxed ("~>" prefix),
		// otherwise a dev performing /any/ local terraform operations will need
		// *exactly* this version to be installed, which leads to poor DevX.
		required_version: "~> \(versions.terraform.core)"
	}
}
