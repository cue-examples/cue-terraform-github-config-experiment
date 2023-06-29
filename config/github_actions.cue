package config

// All GitHub Actions workflows, jobs and steps.
// This file is somewhat (too) long.

import (
	"strings"
	"path"
)

github: actions: {
	_orgs: {
		for k, _ in github.org {
			(k): {name: k}
		}
	}

	workflow: {
		// This workflow tests changes to the `main` branch, invokes `terraform
		// apply` if the tests pass, and posts the resulting Terraform output to
		// the PR that introduced the change
		"test-and-apply.main-branch": {
			name: "Test & apply changes"
			on: push: branches: ["main"]
			jobs: {
				tests
				let tests = {
					"Test-Shared-Components": job.#TestShared
					for org, config in _orgs {
						"Test-\(config.name)": job.#TestAndPublish & {#Org: config}
					}
				}
				apply
				let apply = {
					for org, config in _orgs {
						"Apply-\(config.name)": job.#Apply & {
							#Org: config
							#WaitForJobs: [ for jobId, _ in tests {jobId}]
						}
					}
				}
				"Notify-On-Failure": job.#NotifyApplyFailure & {
					#JobsToCheck: [ for jobId, _ in {tests & apply} {jobId}]
				}
			}
		}

		// This workflow tests changes across all orgs on PR feature branches and
		// posts the output of `terraform plan` to the associated PR
		"test.PR-branch": {
			name: "Test proposed changes"
			on: pull_request: {
				branches: ["main"] // the *target* of the PR
				types: ["opened", "synchronize", "reopened"]
			}
			jobs: {
				let tests = {for org, config in _orgs {
					"Test-\(config.name)": job.#TestAndPublish & {#Org: config}
				}}
				tests
				"Test-Shared-Components": job.#TestShared & {
					needs: [ for k, _ in tests {k}]
				}
			}
		}

		// This workflow runs week-daily and reports any drift between Terraform
		// configuration and GitHub resources' states
		"detect-drift.main-branch.scheduled": {
			name: "Detect drift"
			//on: push: branches: [ "jcm/drift-detection/**"] // Only used for testing, pre-merge
			on: schedule: [{cron: "30 7 * * 1-5"}] // 0730 UTC, Monday-Friday
			on: workflow_dispatch: {}
			jobs: {
				detect
				let detect = {
					for org, config in _orgs {
						"Drift-\(config.name)": job.#DetectDrift & {#Org: config}
					}
				}
				"Alert": job.#NotifyDrift & {
					#JobsToCheck: [ for k, v in detect {k}]
				}
			}
		}

		_job_id_constraint: [
			// "[Job] IDs may only contain alphanumeric characters, '_', and '-'"
			=~"^[-a-zA-Z0-9_]+$",
			// "IDs must start with a letter or '_'"
			=~"^[a-zA-Z_]",
			// "and must be less than 100 characters"
			strings.MaxRunes(99),
		]
		_#JobID: [and(_job_id_constraint)]: _
		[_]: {
			jobs: _#JobID
			env: {
				TF_IN_AUTOMATION: "yes it is"
				TF_INPUT:         0
			}
			concurrency: {
				// All workflows share a static concurrency group.
				// This is the simplest, safest approach, and shouldn't be changed
				// without signficant thought, and understanding of the specific
				// terraform operations being performed across workflows, jobs, and
				// branches.
				group:                "terraform-state-lock"
				"cancel-in-progress": false
			}
		}
	}

	job: {

		#DetectDrift: {
			_#common_job_params
			#Org: {
				name: string
			}

			name:        "Detect drift: \(#Org.name)"
			"runs-on":   versions.github.actions.runner
			concurrency: "terraform-state-lock-org_\(#Org.name)"
			permissions: {
				contents: "read"
			}
			steps: [
				step.#Checkout,
				step.#SetupTerraform,
				step.#TerraformInit & {#OrgName: #Org.name},
				{
					step.#Step
					name: "Detect drift"
					env: TF_VAR_provider_github_token: "${{ secrets.GH_API_TOKEN }}"
					run: "make ci_tf_plan ORG=\(#Org.name) DRIFT_DETECTION=1"
				},
			]
		}

		#NotifyDrift: {
			_#common_job_params
			#JobsToCheck: [...string]
			name:  "Report drift"
			needs: #JobsToCheck
			if:    "${{ failure() }}"
			let workflow_link = "$GITHUB_SERVER_URL/$GITHUB_REPOSITORY/actions/runs/$GITHUB_RUN_ID"
			"runs-on": versions.github.actions.runner
			steps: [
				step.#NotifyDiscord & {
					if:       "${{ always() }}"
					#Message: ":x: Infrastructure drift detected: " +
						"[Workflow](\(workflow_link))"
				},
				step.#NotifyEmail & {
					if: "${{ always() }}"
					#To: [FIXME_NOTIFICATIONS_EMAIL]
					#Subject: "Infrastructure drift detected"
					#Message: "\(#Subject): \(workflow_link)"
				},
			]
		}

		#NotifyApplyFailure: {
			_#common_job_params
			#JobsToCheck: [string, ...string]
			name:      "Notify on apply failure"
			needs:     #JobsToCheck
			if:        "${{ failure() }}"
			"runs-on": "ubuntu-20.04"
			let workflow_link = "$GITHUB_SERVER_URL/$GITHUB_REPOSITORY/actions/runs/$GITHUB_RUN_ID"
			steps: [
				step.#NotifyDiscord & {
					if:       "${{ always() }}"
					#Message: ":x: main branch CI failure: " +
						"[Workflow](\(workflow_link))"
				},
				step.#NotifyEmail & {
					if: "${{ always() }}"
					#To: [FIXME_NOTIFICATIONS_EMAIL]
					#Subject: "CI failure on infra repo `main` branch"
					#Message: "Failed CI workflow: \(workflow_link)"
				},
			]
		}

		#TestShared: {
			_#common_job_params
			name:      "Test shared components"
			"runs-on": versions.github.actions.runner
			needs?: [...string]
			steps: [
				step.#Checkout,
				step.#SetupCUE,
				{
					name: "Test that all generated files match their CUE sources"
					run:  "make generate check_clean_working_tree"
				},
				{
					name: "Test the unified config"
					run:  "make test-config"
				},
			]
		}

		#TestAndPublish: {
			_#common_job_params
			#Org: {
				name: string
			}
			_file_tf_plan_diff_md: path.Join([ "_operations", "github", #Org.name, "tmp", "tfplan.zip.diff.md"], path.Unix)

			name:        "Test: \(#Org.name)"
			"runs-on":   versions.github.actions.runner
			concurrency: "terraform-state-lock-org_\(#Org.name)"
			permissions: {
				contents:        "read"
				"pull-requests": "write"
			}
			steps: [
				step.#Checkout & {
					#gitref: "${{ github.event.pull_request.head.sha }}"
				},
				step.#SetupCUE,
				step.#SetupTerraform,
				step.#TerraformInit & {#OrgName: #Org.name},

				// end of setup, start of tests
				step.#TerraformValidate & {#OrgName: #Org.name},
				{
					step.#Step
					name: "Serialise Terraform's plan"
					run:  "make ci_tf_plan ORG=\(#Org.name)"
					env: TF_VAR_provider_github_token: "${{ secrets.GH_API_TOKEN }}"
				},
				{
					step.#Step
					if:   step.#If.IgnorePreviousStepsFailures
					name: "Reformat plan output as diff"
					run:  "make \(_file_tf_plan_diff_md) ORG=\(#Org.name) COMMIT_ID=${{ github.sha }}"
				},
				{
					step.#Step
					if:   step.#If.IgnorePreviousStepsFailures
					name: "Post plan diff to GitHub PR"
					uses: "mshick/add-pr-comment@" + versions.github.actions."mshick/add-pr-comment"
					with: {
						status:            "${{ job.status }}"
						"allow-repeats":   true
						"message-path":    _file_tf_plan_diff_md
						"message-failure": """
							# test plan FAILURE: `\(#Org.name)`
							
							Check GitHub Actions job output for more details.
							"""
					}
				},
			]
		}

		#Apply: {
			_#common_job_params

			// a non-empty list of other jobs to wait for
			#WaitForJobs: [string, ...string]
			#Org: {
				name: string
			}

			let _file_tf_tmp = path.Join(["_operations", "github", #Org.name, "tmp"], path.Unix)
			_file_tf_apply_log_md: path.Join([_file_tf_tmp, "tf-apply.log.md"], path.Unix)
			_file_tf_apply_stderr: path.Join([_file_tf_tmp, "tf-apply.stderr.log"], path.Unix)
			_file_tf_apply_stdout: path.Join([_file_tf_tmp, "tf-apply.stdout.log"], path.Unix)

			needs:       #WaitForJobs
			name:        "Apply: \(#Org.name)"
			"runs-on":   versions.github.actions.runner
			concurrency: "terraform-state-lock-org_\(#Org.name)"
			permissions: {
				contents:        "read"
				"pull-requests": "write"
			}
			steps: [
				step.#Checkout,
				step.#SetupCUE,
				step.#SetupTerraform,
				step.#TerraformInit & {#OrgName: #Org.name},
				{
					step.#Step
					name: "terraform apply"
					id:   "terraform_apply"
					env: {
						TF_VAR_provider_github_token: "${{ secrets.GH_API_TOKEN }}"
						GITHUB_TOKEN:                 "${{ secrets.GITHUB_TOKEN }}"
					}
					run: """
						set -euo pipefail
						
						if [ "${CUE_DEBUG_SCRIPTS:-}" = "true" ]
						then
						  set -x
						fi
						
						# Assert that the working tree contains only files which are as
						# they were committed, or are gitignored.  This ensures that the
						# config we're about to `terraform apply` is exactly what the
						# developer comitted, with no additional files that might confuse
						# terraform.
						make check_clean_working_tree || {
						  echo "ERROR: reason: git working tree is not clean"                            | tee -a \(_file_tf_apply_stderr)
						  echo "ERROR: result: exiting and failing before attemping a 'terraform apply'" | tee -a \(_file_tf_apply_stderr)
						  exit 1
						}
						
						make DANGER_ci_tf_apply \\
						  ORG=\(#Org.name) \\
						  FILE_TF_APPLY_STDERR=\(_file_tf_apply_stderr) \\
						  FILE_TF_APPLY_STDOUT=\(_file_tf_apply_stdout) \\
						  REALLY_DO_RUN_TERRAFORM_APPLY=true
						
						"""
				},
				{
					step.#Step
					if:   step.#If.IgnorePreviousStepsFailures
					name: "Reformat terraform-apply output as diff"
					env: {
						COMMIT_ID:    "${{ github.sha }}"
						ORG:          #Org.name
						APPLY_STATUS: "${{ steps.terraform_apply.conclusion }}"
					}
					run: """
						file=\(_file_tf_apply_log_md)
						cat ci/misc/tf-apply-to-diff.envsubst \\
						| envsubst \\
						>$file
						
						# format as diff; strip trailing blank lines
						sed -E --file=ci/misc/tf-plan-to-diff.sed \\
						  \(_file_tf_apply_stdout) \\
						  \(_file_tf_apply_stderr) \\
						| tac | awk 'NF{x=1};NF+x' | tac \\
						>>$file
						
						echo '```' >>$file
						
						"""
				},
				{
					step.#Step
					if:   step.#If.IgnorePreviousStepsFailures
					name: "Post apply diff to GitHub PR"
					uses: "mshick/add-pr-comment@" + versions.github.actions."mshick/add-pr-comment"
					with: {
						status:            "${{ job.status }}"
						"allow-repeats":   true
						"message-path":    _file_tf_apply_log_md
						"message-failure": """
							# terraform apply FAILURE: `\(#Org.name)`
							
							Check GitHub Actions job output for more details.
							"""
					}
				},
			]
		}
		_#common_job_params: {
			defaults: run: "working-directory": "."
			env: CUE_DEBUG_SCRIPTS: "${{ vars.CUE_DEBUG_SCRIPTS }}"
		}
	}

	step: {

		#Step: {
			name: string
			if:   string | *"${{ success() }}"
		}

		#If: {
			IgnorePreviousStepsFailures: "(success() || failure())"
		}

		#Checkout: {
			#Step
			name:     "Check out code"
			uses:     "actions/checkout@" + versions.github.actions."actions/checkout"
			#gitref?: string
			if #gitref != _|_ {
				with: ref: #gitref
			}
		}

		#SetupCUE: {
			#Step
			name: "Setup CUE"
			uses: "cue-lang/setup-cue@" + versions.github.actions."cue-lang/setup-cue"
			with: version: versions.cue
		}

		#SetupTerraform: {
			#Step
			name: "Setup Terraform"
			uses: "hashicorp/setup-terraform@" + versions.github.actions."hashicorp/setup-terraform"
			with: {
				terraform_version:            versions.terraform.core
				cli_config_credentials_token: "${{ secrets.TFC_API_TOKEN }}"
				terraform_wrapper:            bool | *false
			}
		}

		#TerraformInit: {
			#Step
			#OrgName: string
			name:     "Initialize Terraform state/plugins/backend"
			run:      "make ci_tf_init ORG=\(#OrgName)"
		}

		#TerraformValidate: {
			#Step
			#OrgName: string
			name:     "Validate terraform input"
			run:      "make ci_tf_validate ORG=\(#OrgName)"
		}

		#NotifyDiscord: {
			#Step
			#Message: string
			name:     "Notify Discord"
			if:       string | *"${{ always() }}" // this default isn't intended to layer on top of #Step's default - it forces the consumer to make an explicit choice, whilst providing a hint beyond #Step's opinion.
			run:      """
				curl \\
				  --no-progress-meter \\
				  -d content="\(#Message)" \\
				  -d username="Github Actions" \\
				  "https://discord.com/api/webhooks/FIXME_DISCORD_WEBHOOK_ID/${{ secrets.DISCORD_WEBHOOK_TOKEN }}"
				"""
		}

		#NotifyEmail: {
			#Step
			#To: [string, ...string]
			#Subject: string
			#Message: string
			_to:      strings.Join(
					[ for k in #To {"\"\(k)\""}],
					",")
			name:     "Notify Email"
			if:       string | *"${{ always() }}" // this default isn't intended to layer on top of #Step's default - it forces the consumer to make an explicit choice, whilst providing a hint beyond #Step's opinion.
			run:      """
				sudo apt-get install -qq swaks
				swaks \\
				  -tls \\
				  --server smtp.gmail.com:587 \\
				  --auth   LOGIN \\
				  --auth-user     "${{ secrets.GOOGLE_SMTP_USERNAME }}" \\
				  --auth-password "${{ secrets.GOOGLE_SMTP_PASSWORD }}" \\
				  --h-Subject "\(#Subject)" \\
				  --body      "\(#Message)" \\
				  --to \(_to)
				"""
		}
	}
}
