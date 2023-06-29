# FILE_TF_PLAN_RELATIVE is the plan's file path+name that terraform uses, *after* its `-chdir` param has been obeyed.
FILE_TF_PLAN_RELATIVE:=tmp/tfplan.zip
# FILE_TF_PLAN is the plan's file path+name that everything *other* than terraform uses.
FILE_TF_PLAN=$(DIR_TF)/$(FILE_TF_PLAN_RELATIVE)

FILE_TF_INIT=$(DIR_TF)/.terraform/terraform.tfstate

# The 4 following FILE_TF_PLAN_* variables are used in the process that generates PR comments from terraform ouput.
FILE_TF_PLAN_ERR=$(FILE_TF_PLAN).err
FILE_TF_PLAN_TXT=$(FILE_TF_PLAN).txt
FILE_TF_PLAN_DIFF=$(FILE_TF_PLAN).diff
FILE_TF_PLAN_DIFF_MD=$(FILE_TF_PLAN).diff.md

# A make-ism to SPOT the check for makevars (`make foo VAR=1`) not being set, and a noisy error.
check_var_defined=$(if $(strip $($1)),,$(error "$1" is not defined))

################################################################
## Internal targets ############################################
################################################################

lockfile_INTERNAL_init_upgrade: ORG=.terraform_lockfile
lockfile_INTERNAL_init_upgrade: # This target is present for internal sequencing only. Don't run it manually
	$(CMD_TF) init -upgrade

CMD_TF_PLAN=$(CMD_TF) plan -input=false -no-color -out="$(FILE_TF_PLAN_RELATIVE)" 2> >(tee "$(FILE_TF_PLAN_ERR)" >&2)
$(FILE_TF_PLAN): $(FILE_TF_INIT)
$(FILE_TF_PLAN):
	$(call check_var_defined,ORG)
ifdef DRIFT_DETECTION # in CI, indicating that a scheduled drift-detection job is running
	$(CMD_TF_PLAN) -detailed-exitcode
else # all other cases: fall back to checking the most recent commit's message body for the magic no-op string
	@set -x; if git log --format=%b -1 | grep -q ^TERRAFORM-PLAN-NO-OP-REQUIRED; \
	  then $(CMD_TF_PLAN) -detailed-exitcode ;\
	  else $(CMD_TF_PLAN) ;\
	fi
endif

$(FILE_TF_INIT):
	$(call check_var_defined,ORG)
	$(CMD_TF) init -no-color

# Make needs to ".IGNORE" errors whilst creating the following targets, because
# any such errors need to be surfaced in the resulting text files that the
# recipes generate and not the Make invocation's error messages, which will be
# hidden away in CI job logs.
# NB don't expand this list without thinking it through *very* carefully.
.IGNORE: $(FILE_TF_PLAN_TXT) $(FILE_TF_PLAN_DIFF) $(FILE_TF_PLAN_DIFF_MD)
$(FILE_TF_PLAN_TXT): $(FILE_TF_PLAN)
$(FILE_TF_PLAN_TXT): # Create a plaintext version of the current plan
	$(call check_var_defined,ORG)
	$(CMD_TF) show -no-color $(FILE_TF_PLAN_RELATIVE) >"$@" 2> >(tee $@.err >&2)
$(FILE_TF_PLAN_DIFF): $(FILE_TF_PLAN_TXT)
$(FILE_TF_PLAN_DIFF): # Turn the plaintext plan into a diff-alike version, suitable for GitHub PR comments
	# Create the aggregate of:
	#  - the plan (FILE_TF_PLAN_TXT)
	#  - problems encountered generating the plan (FILE_TF_PLAN_ERR)
	#  - problems /parsing/ the plan (FILE_TF_PLAN_TXT.err)
	# ... and make sure there's a newline between each file's contents.
	# Then format the aggregate as per https://github.com/github/markup/issues/1440#issuecomment-803889380. (sed)
	# Remove any trailing blank lines. (`tac|awk|tac` hack)
	for file in $(FILE_TF_PLAN_TXT) $(FILE_TF_PLAN_ERR) $(FILE_TF_PLAN_TXT).err ; do cat $$file 2>&1; echo; done \
	| sed -E --file=ci/misc/tf-plan-to-diff.sed \
	| tac | awk 'NF{x=1};NF+x' | tac \
	>"$@"
$(FILE_TF_PLAN_DIFF_MD): $(FILE_TF_PLAN_DIFF)
$(FILE_TF_PLAN_DIFF_MD): # Make a markdown-ish file from the plan diff contents
	cat ci/misc/tf-plan-to-diff.envsubst | envsubst  >"$@"
	{ cat "$^"; echo '```'; }                       >>"$@"

################################################################
## CI convenience shims ########################################
################################################################

ci_tf_init: $(FILE_TF_INIT)

ci_tf_validate: $(FILE_TF_INIT)
ci_tf_validate:
	$(call check_var_defined,ORG)
	$(CMD_TF) validate -no-color

ci_tf_plan: $(FILE_TF_PLAN)

DANGER_ci_tf_apply: $(FILE_TF_INIT)
	$(call check_var_defined,ORG)
ifndef REALLY_DO_RUN_TERRAFORM_APPLY
	$(error This command is dangerous, and should only be run inside CI)
endif
	$(CMD_TF) apply -no-color -auto-approve > >(tee $(FILE_TF_APPLY_STDOUT)) 2> >(tee $(FILE_TF_APPLY_STDERR >&2))

MAKEFLAGS += --warn-undefined-variables \
             --no-builtin-rules \
             --no-builtin-variables \
             --no-print-directory
