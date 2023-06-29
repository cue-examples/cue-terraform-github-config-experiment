# Managing Existing GitHub Resources

## Introduction

Terraform aligns closely with the CRUD cycle of infrastructure management, with
a particular emphasis on "Create" - it *really* wants to manage resources that
it originally created, and making it manage resources that it *didn't* create
is fiddly at best.

In order for Terraform to control GitHub resources that already exist, they
must be "imported" and placed under Terraform's complete control. There is no
concept of a "partially" managed resource.

(This process *might* be simplified significantly if Terraform 1.5's "import
blocks" end up being useable in our system. See the
[1.5.0-rc2 release notes](https://github.com/hashicorp/terraform/releases/tag/v1.5.0-rc2)
for an indication of their intended capabilities, but keep in mind they haven't
been tested in our system in any way.)

## Maybe Don't Do This?

To manage an existing resource with Terraform, **first consider *not* importing
an existing resource**. Importing a resource is a fiddly and risky operation,
which should be avoided if at all possible. Whilst this document looks long and
perhaps slightly intimidating, the actual process is quick enough once
understood. Having said that, the *risks* outlined below don't diminish, even
with practice.

If it might be acceptable to move forward by deleting the resource and
configuring Terraform to create it from scratch, then choose that option. This
strategy will be more suitable for stateless resources such as team memberships
and branch protection rules and less suitable for repos, but it should be your
preferred option when available.

## Setup

To safely import an existing resource, you will need exclusive write access to
this repo for the duration of this process. Arrange this with your colleagues,
with no PRs being opened, updated, **or merged(!!!)** by anyone except
yourself. Avoid clashing with the drift detection job's
[scheduled execution time](/.github/workflows/detect-drift.main-branch.scheduled.yml#L5).

The first time you perform an import, **strongly** prefer pairing with someone
who has done this before. The worst-case scenario for getting something wrong
in this processs is that **the resource you're importing will be deleted**. As
we'll see, this is a function of Terraform's state file behaviour, not of this
system specifically.

Read and follow the
[Running Terraform Locally](/README/md#running-terraform-locally)
section of the main README. You will be invoking Terraform locally several
times during this process. All the security warnings found in that section
apply here.

Read the next section, "Configuration", through to the end. Don't start without
having read it at least once, so you know where the dangerous areas are, why
they exist, and how you'll avoid the problems they describe.

## Configuration

Start off with a pristine checkout of this repo, on the `main` branch. **Make
sure your local `main` branch is up to date with the remote**. Ensure your
colleagues know that they *must not* open, update, **or merge** any PRs from
this moment onwards, until you reach the end of this process and let them know.

Create a feature branch off `main`. This process will complete when you have
merged this branch via PR, with `main` branch CI jobs passing and asserting
that your commit was a no-op ... but *the sequence of operations getting to
that point is **critical**.*

Add a reasonable guess at the current state of the resource to be imported into
the right place in the CUE `config` package - almost certainly inside a
`config/org.*.cue` file. For a repo, this might only include its resource
path/name and visibility level - you don't *need* to get anything correct, yet,
**except the resource's path which is *critical***. Changing the path
mid-import (i.e. after having run `terraform import`) is outside the scope of
this guide, and if you discover you need to do so, reach out for support
*immediately*.

Run

```shell
make generate
```

to reflect your CUE change in the appropriate
`_operations/github/*/config.tf.json` static config file.

Use

```shell
git status
```

to confirm that the only change inside `_operations/` is in the
`config.tf.json` file of the GitHub org that already owns the resource to be
imported. (Importing is *not* a cross-org activity, and cannot be used to
change resource ownwership.)

With the
[required credentials available](/README.md#running-terraform-locally), run

```shell
make test-plan ORG=<importing-org-name>
```

to set up Terraform for your import operation. Don't worry that the plan output
says it would *create* the resource that you're importing: we're only using
this Makefile target for its ability to correctly initialise Terraform for that
org - that plan output won't be enacted.

Change into the importing org's directory inside `_operations/github/`. Check
that you see your changes reflected in `config.tf.json`.

Open the
[Terraform documentation for the `github` provider](https://registry.terraform.io/providers/integrations/github/5.25.1/docs).
Make sure you're reading the docs for the version of the provider we're using,
as set in `config/manifest.cue` at path `versions.terraform.providers.github`.

Find the docs for the resource type that you're importing. e.g.
[`github_repository`](https://registry.terraform.io/providers/integrations/github/5.25.1/docs/resources/repository).
Find the "Import" section (it's usually at the bottom of the page), and find
out how the import needs to be specified **for this specific resource type**.

The documentation should show you 4 components of the requisite `terraform
import` command, and should explain how the 4th component must be constructed.

However, the docs are often poorly constructed, with confusing names chosen for
the example import operations. The docs for the `github_repository` resource
type contain especially poor examples so, next, we'll over-explain the command
components so it's clear what you're doing.

These are the components of the import command you'll see on the resource type
documentation page:

1. `terraform`: the path to the Terraform binary you have available locally.

    Its version must adhere to the constraints set in `config/manifest.cue` at
    path `versions.terraform.core`

1. `import`: the import sub-command

1. `github_<resource-type>.<terraform-resource-name>`: this string is the
   *Terraform* path in your config by which the resource can be reached **inside
   the `resource` struct**. It is *critical*

   Consult the `config.tf.json` file to ensure you use the string matching that
   which CUE has exported *precisely*. `<terraform-resource-name>` might have
   been translated during export into something meeting Terraform's naming
   constraints.

   **Don't assume it's the same name that you used in your *CUE* config**

1. `<resource-primary-or-compound-key>`: this string is the key by which the
   provider will uniquely identify the to-be-imported resource remotely, inside
   GitHub

   Sometimes it's simple (e.g. at time of writing, a `github_repository` is
   imported via its name alone), and sometimes it's multi-faceted (e.g. an
   individual's `github_membership` currently uses org name and member name,
   with a separator)

   Read the resource type docs to identify how this component has to be
   constructed

**There is no Terraform CLI validation mechanism for components #3 and #4**.
Don't get them wrong.

Construct your import command with its 4 components as detailed above.

## Critical Region

From this next step, until your PR is merged and its `main` branch jobs pass,
if `terraform apply` gets invoked anywhere, in CI or by another user, on any
branch not containing your config changes, **then that other Terraform
invocation will destroy the resource you have imported**, if it has API
permissions to do so.

This is what we call a "critical region" for the system, where the normal
functioning of the system **must** be paused whilst you make your changes.

Run your import command, carefully constructed above:

```shell
# DO NOT copy and paste this - it is only indicative
# terraform import github_<resource-type>.<terraform-resource-name> <resource-primary-or-compound-key>
```

Terraform will tell you if the import is successful. If it isn't, reach out for
support.

**You have *not* yet finished - continue reading**.

You have just added the resource into Terraform's *live* state file, stored
centrally in Terraform Cloud. The state file is Terraform's concept of remote
resources that exist and are Terraform's responsibility. The state file for
each org is a singleton, and has no affinity with your branch, or your machine:
it's shared across all invocations of Terraform that manage this org.

So, right now, if `terraform apply` is invoked, anywhere, against a
`config.tf.json` that *doesn't* contain config describing your newly imported
resource, then that Terraform invocation will happily attempt to align reality
(i.e. make changes at GitHub) with the config that *it* sees - and that means
destroying resources that it's responsible for, but which don't need to exist
any more (because *they're not in the config file that it sees*).

The rest of this process involves aligning your config with the remote
resource's actual configuration, and merging the resulting config change into
the `main` branch.

Whilst still inside the `_operations/github/...` directory containing the org's
`config.tf.json`, run 

```shell
terraform plan
```

to see the differences between your current config and GitHub's reality.

Terraform will propose making some changes to your newly-imported resource. **You
*must* adapt your config** until Terraform proposes making *no* changes.

Do this by taking the per-field output from `terraform plan` and codifying the
*inverse* of that result in your resource's CUE config. Here's an example ..

Changes being proposed look like this:

```text
Terraform will perform the following actions:

  # github_repository.playground will be updated in-place
  ~ resource "github_repository" "playground" {
      ~ has_downloads               = true -> false
      ~ has_projects                = true -> false
      ~ has_wiki                    = true -> false
        id                          = "playground"
        name                        = "playground"
        # (31 unchanged attributes hidden)

        # (1 unchanged block hidden)
    }
```

Here, the 3 fields `has_downloads`, `has_projects`, and `has_wiki` are being
proposed to move from `true` to `false`. This tells us that the actual repo on
GitHub has those fields already set to `true` - and so we need to reflect that
in our config by adding this to our existing CUE resource struct:

```CUE
our_resource: {
  has_downloads: true
  has_projects:  true
  has_wiki:      true
}
```

After making the changes to your CUE config (**not directly in
`config.tf.json`**) , regenerate your Terraform config and re-run Terraform
from inside the same org-level directory:

```shell
make -C "$(git rev-parse --show-toplevel)" generate
terraform plan
```

If you have now correctly mirrored the state of the existing remote resource,
Terraform will show you something like this message:

```
No changes. Your infrastructure matches the configuration.

Terraform has compared your real infrastructure against your configuration
and found no differences, so no changes are needed.
```

Seeing something close to the above message allows you to move on.

If you don't see this, and changes are still proposed, codify their inverse and
re-attempt the regeneration/plan step. Do this until you see no changes being
proposed.

Once you have eliminated all proposed changes, commit both your changes to the
CUE config and the generated file on your feature branch. Use a commit message
like the following, **and be sure to include the Terraform no-op flag in the
commit message body, at the start of a line**:

```text
org/<ORG-NAME>: import github_<RESOURCE-TYPE> <RESOURCE-NAME>

TERRAFORM-PLAN-NO-OP-REQUIRED
```

Open a PR to merge your feature branch into `main`. The
`TERRAFORM-PLAN-NO-OP-REQUIRED` marker will make the CI tests fail if your
config differs from the resource's actual GitHub state. Make any required
changes to the resource in a *subsequent* PR - don't take a potentially
dangerous shortcut by attempting to make changes to the resource in this PR!

Have the PR reviewed, and then "Rebase and merge" your branch into `main`.

After the `main` branch CI jobs have finished succesfully, the repo's critical
region is over - announce this to your colleagues.

If the jobs fail, reach out for support *immediately*.
