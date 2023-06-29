package config

import (
	"regexp"
)

// Our config, dynamically mutated.
// We do this so that our CUE config can be authored using all CUE (naming/etc)
// features (e.g. periods in resource names), whilst providing Terraform with
// input that meets its more onerous constraints.

X=github: _

target: terraform: {
	github: org: {
		[_]: config: resource: [_]: #Identifier.valid
		for org_name, org_config in X.org {
			(org_name): config: {
				resource: {
					for resource_type, resource_instance in org_config.config.resource {
						(resource_type): {
							for resource_identifier, resource_config in resource_instance {
								let new_resource_identifier = {#Identifier.adapt & {#in: resource_identifier}}.#out
								(new_resource_identifier): resource_config
							}
						}
					}
				}
				for top_level_field, value in org_config.config
				if top_level_field != "resource" {
					(top_level_field): value
				}
			}
		}
	}

	#Identifier: {
		rules: {
			// https://developer.hashicorp.com/terraform/language/syntax/configuration#identifiers
			// "Identifiers can contain letters, digits, underscores (_), and hyphens (-)"
			// "The first character of an identifier must not be a digit"
			valid_initial_characters: "-a-zA-Z_"
			valid_characters:         valid_initial_characters + "0-9"
		}
		valid: [and(valid_constraints)]: _
		valid_constraints: [
			=~"^[\(rules.valid_characters)]+$",
			=~"^[\(rules.valid_initial_characters)]",
		]
		adapt: {
			#in: string

			// Replace every character that's not valid in a terraform identifier with a "_"
			let _a = regexp.ReplaceAllLiteral("[^\(rules.valid_characters)]", #in, "_")

			// Replace every character that's not valid at the start of an identifier with "_", then the character
			let _b = regexp.ReplaceAll("^([^\(rules.valid_initial_characters)])", _a, "_$1")

			// Replace "-" (despite its Terraform legality), to produce nicer CUE identifiers
			//let _c = regexp.ReplaceAllLiteral("-", _b, "_")

			// We currently emit _b, not _c, because Terraform is *already* managing
			// some resources with identifiers containing "-" characters. We'll have
			// to state-migrate them if we want to use _c, or Terraform will 
			// destroy+recreate the underlying GitHub resources. Some of these
			// resources are repositories, which we mustn't delete.
			#out: _b
		}
	}
}
