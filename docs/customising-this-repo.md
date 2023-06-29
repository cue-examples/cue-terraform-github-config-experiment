# Customising This Repo

This is a basic guide to customising this repo, and setting up the initial
state it expects to find inside GitHub Actions ("GHA").

1. Fork this repo, **and reset its state back to the very first commit**:

   - `git reset --hard $(git rev-list --max-parents=0 HEAD)`

1. Manually create a GitHub machine user account for the system:

   - this will be the account that the system will operate as, when interacting
     with the GitHub API

1. Decide your default GitHub Billing email:

   - Whilst this is overrideable per-org, choose your GitHub orgs' most
     frequently-used billing email to be the default

1. Manually create a Terraform Cloud organisation (or select an existing one)

1. Find the following placeholders across all files in the repo, and replace
   them with values appropriate to your situation. Note that most of them will
   be found as bareword references which deliberately break CUE
   (`FIXME_BILLING_EMAIL`), whereas you'll need to replace them with strings
   (`"billing-email@example.com"`)

   - `FIXME_NOTIFICATIONS_EMAIL`: a string containing the email that will
     receive notifications when GHA jobs fail, or when drift is detected
     between GitHub and your last-applied configuration

   - `FIXME_DISCORD_WEBHOOK_ID`: the webhook ID which will receive
     notifications when GHA jobs fail, or when drift is detected between GitHub
     and your last-applied configuration

   - `FIXME_BILLING_EMAIL`: a string containing the email that will be set as
     each GitHub org's "billing email", unless overridden by the org-level
     settings

   - `FIXME_TERRAFORM_CLOUD_ORG`: a string containing your TFC org identifier

   - `FIXME_MACHINE_USER_ACCOUNT_USERNAME`: the username of the GitHub machine
     user account described above

   - `FIXME_ONE_OR_MORE_INFRA_ADMIN_USERNAMES`: the `CODEOWNERS` entries for
     the folks who will have admin oversight of your GitHub orgs

   Note that until you replace these values, `make test-config` will fail and
   no GHA jobs will be able to run.

1. Provide the following as GHA "Repository Secrets", via the GitHub UI:

   - `TFC_API_TOKEN`: a Terraform Cloud ("TFC") API token, scoped to a team
     with access to all TFC Workspaces you'll be creating for the system to use

   - `GH_API_TOKEN`: a GitHub Personal Access Token ("PAT") belonging to the
     machine user account described above. It should have access to the
     following scopes:

     - `repo`: required to create and modify public and private repositories

     - `admin:org`: required to modify org-level settings, and manage org membership

     - `delete_repo`: **only required if you want to allow Terraform to delete repositories**.
       The system *will work* without access to this scope.

   - `GOOGLE_SMTP_USERNAME`: The static Google SMTP username used to send
     failure and drift notification emails

   - `GOOGLE_SMTP_PASSWORD`: The static Google SMTP password associated with
     `GOOGLE_SMTP_USERNAME`

   - `DISCORD_WEBHOOK_TOKEN`: The static Discord webhook token which grants
     posting access to the webhook *ID* that you inserted in place of
     `FIXME_DISCORD_WEBHOOK_ID`, above

1. Enable GitHub Actions on the repository's Actions tab on the GitHub UI

1. Commit all the above file changes and `git push --force-with-lease` to your
   fork
