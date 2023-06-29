default: help
FORCE:

# Bash is required as we're performing output redirection ("2> >(tee file.err >&2)") that /bin/sh can't do.
SHELL:=/bin/bash
.SHELLFLAGS:=-euo pipefail -c

DIR_OPS_ROOT:=_operations/github
DIR_TF=$(DIR_OPS_ROOT)/$(ORG)
CMD_CUE:=cue
CMD_TF=terraform -chdir=$(DIR_TF)

################################################################
## Developer targets ###########################################
################################################################

test-config: ## Run tests against static input config (no creds required locally)
	$(CMD_CUE) vet -c ./config:config
	# Config: OK ✅

clean: FORCE
clean: ## Remove all .gitignored files
	git clean -dfX $(DIR_OPS_ROOT)/

generate: test-config
generate: ## Regenerate all non-source files in the repository
	cue cmd gen_terraform
	cue cmd gen_ci

trim: ## Run cue-trim on the non-GHA portions of the unified config
# (github_actions.cue confuses cue-trim; bug is filed)
	rm -f config/github_actions.cue
	cue trim ./config:config
	git restore config/github_actions.cue

check_clean_working_tree: FORCE
check_clean_working_tree: ## Check that all git's tracked files are unchanged, and no untracked files exist
	test -z "$$(git status --porcelain)" \
	|| { git status; git diff; false; }

lockfile_upgrade: generate
lockfile_upgrade: lockfile_INTERNAL_init_upgrade
lockfile_upgrade: lockfile_hash
lockfile_upgrade: ## Upgrade providers to the latest versions permitted by `config/manifest.cue`

lockfile_hash: ORG=.terraform_lockfile
lockfile_hash: ## Place a full set of platform-specific hashes in terraform's lock file, without re-locking versions
	$(CMD_TF) providers lock \
	  -platform=linux_amd64 \
	  -platform=darwin_amd64 \
	  -platform=linux_arm64 \
	  -platform=darwin_arm64

help: ## Show this help
	@egrep -h '^[^[:blank:]].*\s##\s' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-25s\033[0m %s\n", $$1, $$2}'

include ci/make/internal-targets.mk
