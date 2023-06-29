# CUE.works infrastructure

This repo contains and orchestrates a system which manages most CUE-owned
GitHub Organisations.

The system uses GitHub Actions ("GHA") to coordinate Terraform invocations that
manage the state of the GitHub orgs' entities such as org members, repo
settings, outside collaborators
[and more](internal/schemata/providers/github/).
It can be easily extended to manage any GitHub entity type supported by
[the `github` Terraform provider](https://registry.terraform.io/providers/integrations/github/5.25.1/docs)
and potentially any entity type supported by
[any Terraform provider](https://registry.terraform.io/browse/providers).

CUE is the system's source of truth, which is primarily stored in the `config`
package.

There are [Quickstart guides](#quickstart-guides) available for some common
tasks:

- [Creating a new repo](#creating-a-new-repo)
- [Deleting a repo](#deleting-a-repo)
- [Onboarding a new employee](#onboarding-a-new-employee)
- [Granting an outside collaborator access to specific repos](#granting-an-outside-collaborator-access-to-specific-repos)
- [Adding an org to the system](#adding-an-org-to-the-system)

There is a basic guide to
[customising this repo and setting up your GitHub Actions environment](docs/customising-this-repo.md).

There are additional Quickstart guides for the following tasks, but **these
processes are untested** and should only be performed by *experienced* users of
this system, and with an eye on validating the process and promoting its entry
to the list above:

- [Moving a repo across orgs](#moving-a-repo-across-orgs)
- [Renaming a repo](#renaming-a-repo)

The GitHub org that *this* repo belongs to is deliberately left unmanaged by
the system, so that we can never accidentally cause the system to lock
ourselves out of this repo, unable to undo the change.

The system manages other orgs via a GitHub machine user account. That account
is an owner of any org it manages. We have chosen not to manage *that* machine
user's membership in any org via this system - again, so that we can never
inadvertently remove the machine user from any org and lock ourselves out of
*that* org.

---

## Operations

### Overview

This repo is a CUE module whose `config` package defines the configuration of
all GitHub orgs managed by the system. All CUE files in the `config/` directory
contribute to the package. The [files' purposes](#this-repo) and [resulting CUE
structure](#the-main-cue-package) are documented in this README.

CUE is the source of truth both for the GitHub orgs being managed by Terraform
and the GHA jobs that automate the management. However neither Terraform nor
GHA accept CUE as input, so we serialise their respective config files before
they execute. We store Terraform's config files in the repo (instead of
exporting them at GHA runtime) so we can have confidence in their content and
presence, and to ensure they are reviewable as part of any change.

We shield each GitHub org from all the others (and shield the operator from
making high-impact errors) by managing each org via its own Terraform config
file and Terraform invocation, and by storing each org's state file in a
dedicated Terraform Cloud ("TFC") Workspace. TFC is used solely to store
Terraform state files and to provide a locking mechanism preventing parallel
Terraform invocations from interfering with each other. It is not used for its
ability to invoke Terraform.

Changes are made to the repo's contents via GitHub Pull Requests ("PR"s) from
feature branches onto the `main` branch. Only commits to the `main` branch
trigger a `terraform apply` invocation, and that branch is protected from
direct pushes. Commits must be added via PRs.

Terraform invocations run inside GHA, with each org having a dedicated
`terraform plan` job during PR testing, and a dedicated `terraform apply` job
after each PR merge.

Terraform's generated config files live inside `_operations/github/` in a
directory named after the org being managed. This per-org directory is
Terraform's working directory, and is where Terraform initialises its provider
plugins before invocations.

Changes to files inside `_operations/` are made by Makefile recipes, CUE
`_tool` scripts, and Terraform's lockfile management - all of which are
triggered by the operator and never by CI itself.

The contents of files inside `_operations/` are controlled via the `config`
package. Changes inside `_operations/`, `config/` and `.github/` must be
committed by the operator.  No *manual* edits of files inside `_operations/`
are needed, and such edits are guarded against by an early CI assertion that
the committed contents of `config/` produces exactly the committed contents of
`_operations/`.

### Making A Content Change In One Or More Orgs

After making a change in `config/` that updates one or more org's resources or
introduces new resources, you must:

- test the changes with `make test-config`
- generate static Terraform configuration with `make generate`
- submit the changes as a PR
- validate the per-org `terraform plan` output posted to your PR as comments
- have the PR reviewed and approved
- merge the PR

#### Test The Changes

With a version of CUE installed that understands required fields, run

```shell
make test-config
```

#### Generate Static Terraform Configuration

Run

```
make generate
```

#### Submit The Changes

On a non-`main` branch, commit all changed files, including but not limited to
all changes under the `config/`, `_operations/`, and `.github/` directories.

Add all changes in a single commit. Use a commit prefix such as:

- changes to a single org: `org/cue-foo: add the X field to Y`
- changes across multiple orgs: `org/cue-{foo,bar}: make Y do X`
- changes across all orgs: `org/*: change all X to Y`
  - e.g. global template changes

If your commit doesn't update, create, or destroy any Terraform resources (e.g.
it's a CUE refactor, a documentation update, or a whitespace change), inform
the CI tests that they should assert that no-op-ness by including this string
on a separate line in your commit message *body*:

```text
TERRAFORM-PLAN-NO-OP-REQUIRED
```

Open a draft PR that would add your changes to the `main` branch in this repo.

#### Validate The Per-Org `terraform plan`

The CI test jobs will finish by running `terraform plan` once for each managed
org. Each `terraform plan`'s output is posted to your PR as a separate comment.

Check that Terraform is proposing to create, update or destroy the resources
that you expect.

If your PR passes the GitHub Actions CI tests for every org, mark the PR as
ready and request a review from someone on the team.

#### Have The PR Reviewed And Approved

This repo has a [`CODEOWNERS`](/CODEOWNERS) file which enforces that certain
files' changes must be reviewed by specific people. In general, PRs may be
reviewed by anyone with access to the repo. @myitcv has the most information
about the system, and in an emergency you can reach out to @jpluscplusm for
support.

The `main` branch's protection rules require an approval on a PR's latest
commit before that PR's commit(s) can be added to the branch.

#### Merge The PR

After the PR has been approved **ensure that any other PR merges have fully
run to completion in the repo's GitHub Actions**.

Merge the PR yourself, using the "Rebase and merge" strategy.

### Make Targets

There is a single Makefile at the top of the repo. This Makefile is used by
developers, operators, and CI to perform specific tasks. The Makefile is
written in the "phony" task runner model, not the traditional `make
a.specific.file.exist` model - all tasks run unconditionally, without checking
any file modification times. The Makefile includes other Makefiles (in
`/ci/make/`) which contain the messy implementation details of how CI jobs turn
`terraform plan` output into nice PR comments.

Running `make [help]` lists the runnable targets alongside a brief description
of what each target does. These targets are listed here with slightly more
detail than at the CLI.

Parameters should be provided as Makevars (`make <target> PARAM=value`).
Providing them as envvars *may* work, but has not been tested.

| Target | Parameters | Purpose |
| :---   | :---:      | :---
| `test-config` | | `cue vet` the `config` package
| `clean` | | Remove all .gitignored files
| `generate` | | Recreate all generated files in the repo
| `trim` | | Run cue-trim on the non-GitHub-Actions portions of the unified config (because something about our workflows confuses `trim`, which has been filed as an upstream bug)
| `lockfile_upgrade` | | Upgrade Terraform providers to the latest versions permitted by `config/manifest.cue`
| `lockfile_hash` | | Place a full set of platform-specific hashes in terraform's lock file, without re-locking versions
| `check_clean_working_tree` | | Assert that all git's tracked files are unchanged from their latest committed state, and no untracked files exist
| `help` | | Show abbreviated help text

### Upgrading Terraform Providers

---

<details>

<summary>Click to open this paragraph <strong>if you have prior
experience</strong> of upgrading Terraform providers in a different
system</summary>

<br>

In vanilla Terraform setups you would run `terraform init` with its `-upgrade`
flag in a directory that contains Terraform's config.

**Do NOT do that here!**

*Don't* run `terraform init -upgrade` in any specific org's `_operations/*`
directory.

Doing so would desync that org from all the other orgs (in terms of provider
versioning) and would require unpicking symlinks (cf.
https://github.com/hashicorp/terraform/issues/32707)

Instead, read on for details of how to use Makefile targets to upgrade
Terraform providers in this system.

</details>

---

The versions of providers we use are constrained by
[Terraform's constraint syntax](https://developer.hashicorp.com/terraform/language/expressions/version-constraints#version-constraint-syntax)
in the version manifest at `config/manifest.cue`, under the CUE path

```CUE
versions: terraform: providers: [_]:
```

`config/manifest.cue` is under your control, but the provider versions that
will be used are *not* decided by this file's contents **on every Terraform
invocation.**

Instead, the versions are locked at the *specific* versions
visible inside `_operations/github/.terraform_lockfile/.terraform.lock.hcl`.

This file is static until an operator chooses to upgrade and lock provider
versions.

`_operations/github/.terraform_lockfile/.terraform.lock.hcl` is managed by
Terraform, and is modified by the following Make targets (which invoke
Terraform, which must be installed):

- `make lockfile_upgrade`: upgrades to the latest versions permitted by the
  constraints in `config/manifest.cue`
- `make lockfile_hash`: records a hash of each currently selected provider's
  installation files, *without* upgrading versions

Runnng `make lockfile_upgrade` also invokes `lockfile_hash`. **Neither** target
requires TFC or GitHub API tokens to be available on the local machine, and can
be run by anyone with an appropriate version of Terraform installed.

Both of these commands might modify
`_operations/github/.terraform_lockfile/.terraform.lock.hcl`.

**Changes to this file must be committed and PR'd.**

**It is STRONGLY recommended to PR & merge provider version upgrades ahead of
configuration changes which require the upgraded versions** so that the version
upgrade can be verified as being a no-op change in isolation.

### Running Terraform Locally

This system is intended to run Terraform solely in CI, and not on an operator's
machine. The initial setup required for CI is documented
[separately](docs/customising-this-repo.md).

If you *do* need to run Terraform locally then the system requires 2
environment variables to be set, containing credentials for its 2 different
backend systems: Terraform Cloud ("TFC") and GitHub.

However, before doing this, *consider if you really **need** to run Terraform
locally*, or if you could instead achieve what you need via CI. The system
currently does not have a concept of "read-only" access to either TFC or
GitHub, so possessing the credentials required for Terraform invocation means
your local machine is a *signficantly* elevated risk for the organisation.

If you make the choice to run Terraform locally, protect the credentials:

- **minimise the duration that the credentials are present** on your local
  machine
- **remove them from your environment** after each session in which you use
  them
- **don't make shadow copies of them in your local secret-management software**
- **don't store them on your filesystem** for any period of time
- ***don't commit them to this repo!***

#### Terraform Cloud

[Terraform Cloud](https://app.terraform.io) ("TFC") is a managed service hosted
by Hashicorp. We use it to store our Terraform state files, and to provide
locking primitives for access to those state files.

Expose a TFC API token via the environment variable
`TF_TOKEN_app_terraform_io`.  

In mid-2023, these tokens look like
`<random-characters>.atlasv1.<random-characters>`.

#### GitHub API

The GitHub resources resources managed by the system are accessed via the
Github API.

Expose an appropriately-permissioned GitHub API token via the environment
variable `TF_VAR_provider_github_token`.  

In mid-2023, these tokens
[look like](https://github.blog/changelog/2021-03-31-authentication-token-format-updates-are-generally-available/)
`ghp_<random-characters>`.

### Managing Existing GitHub Resources

Importing existing GitHub resources so they can be managed by Terraform is a
fiddly and potentially risky operation.

It is
[documented separately](/docs/managing-existing-resources.md).

---

## Layout

### This Repo

- [`ci/`](/ci): CI related files

  - [`github/`](/ci/github): a convenience symlink to `.github/workflows/`

  - [`make/`](/ci/make): a place for Makefiles that contain targets used by CI

  - [`misc/`](/ci/misc): `sed` and `envsubst` "scripts" which are used by CI to format
    `terraform [plan|apply]` output for comments on PRs

- [`CODEOWNERS`](/CODEOWNERS): A file configuring a
  [GitHub feature](https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/customizing-your-repository/about-code-owners)
  that ensures that changes to certain files are reviewed by specific people

- [`config/`](/config): user-modifiable configuration files

  - `org.*.cue`: per-org resources and org-level deviations from global defaults

- [`generate_tool.cue`](/generate_tool.cue): a CUE script which writes the systems' generated files

- [`.github/workflows/`](/.github/workflows): Generated GHA workflow files

- [`internal/`](/internal): CUE files which don't have a place as part of the
  `config` package, but haven't yet been externalised from this repo

  - [`schemata/providers/github/`](/internal/schemata/providers/github):
    manually-generated schemata which validate our configuration of resources
    managed by the `github` Terraform provider

  - [`schemata/terraform/`](/internal/schemata/terraform):
    manually-generated, minimally-viable schemata for various provider-agnostic
    components of Terraform's input, including top-level config and
    [resource meta arguments](https://developer.hashicorp.com/terraform/language/resources)

- [`Makefile`](/Makefile): the dev- and CI-facing task runner. See
  [Make Targets](#make-targets) for a list of its targets and the tasks it
  performs

- [`_operations/`](/_operations): the root directory for all generated files
  (except GitHub Actions workflow files, which must live in `.github/workflows`
  and cannot be symlinks)

  - [`github/cue-*/`](/_operations/github): a per-GitHub-org working directory
    for Terraform invocations, each containing the generated `config.tf.json`
    file for the GitHub org the directory is named after

  - [`github/.terraform_lockfile/`](/_operations/github/.terraform_lockfile):
    the working directory used by [`make lockfile_upgrade`](#make-targets)
    operations, containing only those parts of our Terraform configuration
    which affect provider dependency version selection

    - [`.terraform.lock.hcl`](/_operations/github/.terraform_lockfile/.terraform.lock.hcl):
      The Terraform-controlled lockfile which contains the exact versions of
      providers the system uses. Controlled by a Make target, and documented
      [elsewhere in this README](#upgrading-terraform-providers)

### The Main CUE Package

The high-level shape of the `config` package is described in
[`schema.cue`](/config/schema.cue).

Each `github.org.[OrgName=string]: {}` struct represents a managed GitHub org
named `OrgName`.

Inside this struct the org's config lives in the `config` field, whose shape is
also described in [`schema.cue`](/config/schema.cue), in the `#terraform_input`
definition.

Each `github.actions.workflow.[Filename=string]: {}` struct that exists results
in a separate GHA workflow file being written into
`.github/workflows/<Filename>.yml`

Each `target.terraform.github.org.[OrgName=string]: {}` struct is a dynamic
copy of the same path *without* the `target.terraform` prefix. A copy exists
for each managed org.

This struct contains the content that ultimately gets serialised into
`_operations/github/<OrgName>/config.tf.json`, but with one difference:
resource names are translated in order to meet a specific set of Terraform
requirements, which are different from CUE's struct name constraints. The
translation rules live inside `target.terraform.#Identifier.adapt`, defined in
`config/target.terraform.cue` along with their documentation.

---

## Quickstart Guides

After following any quickstart section, also follow the
[content change](#making-a-content-change-in-one-or-more-orgs)
section to submit and apply your changes.

### Creating A New Repo

#### Prerequisites

- You want to create a repo with name `<REPO-NAME>` in org `<ORG-NAME>`
- You know if it will be a public or private repo

#### Configuration

Configure the new repo in `config/org.<ORG-NAME>.cue`, with the following path
and minimum concrete configuration:

```CUE
github: org: <ORG-NAME>: config: {
  resource: {
    github_repository: {
      <REPO-NAME>: {
        visibility: "public" | "private"
      }
    }
  }
}
```

Other options are available, as per the schema in
`internal/schemata/providers/github/repository.cue`. Global defaults,
if any, are visible in `config/defaults.cue`.

Now read the
[content change](#making-a-content-change-in-one-or-more-orgs)
section.

### Deleting A Repo

#### Prerequisites

- A public or private repo exists that you wish to delete entirely
- The repo is managed by this system
- The repo is named `<REPO-NAME>`, and it exists in the `<ORG-NAME>` org

#### Configuration

In the `config` package, in the file dedicated to `<ORG-NAME>`'s resources,
find the struct

```cue
github: org: <ORG-NAME>: config: resource
```

Inside that struct, find and delete the `github_repository: <REPO-NAME>`
struct.

Alow find and delete any references to the repo in other structs such as:

- `_non_org_member_access: collaborator`
- `_non_org_member_access: bot`
- `github_repository_collaborators`

You  now need to PR and merge these change, **but the CI job after the merge
onto the main branch will fail**. This is expected, and is a safety precaution.

*After* reading and following the
[content change](#making-a-content-change-in-one-or-more-orgs)
section, return to this guide and continue from this point.

---

Your PR passed all its tests, you merged it, and the `terraform apply` job on
the `main` branch failed. This is because this system has not been granted
permission to delete *any* repos, so it can't accidentally destroy content
irreversibly.

Find someone who has control of an org-owner account in the `<ORG-NAME>` org.

Ask them to navigate to the repo's settings page and delete the repo manually.

After they have done this, **re-trigger the CI job on the `main` branch** and
observe your commit's status going green.

### Onboarding A New Employee

#### Prerequisites

- You want to grant a new company employee read and write access to all public
  and private repos across all orgs
- You know their GitHub login

#### Configuration

Add the new employee to `config/employees.cue` as an `#Employee` struct inside
`company.employees`.

Now read the
[content change](#making-a-content-change-in-one-or-more-orgs)
section.

### Granting An Outside Collaborator Access To Specific Repos

#### Prerequisites

- You want to grant a 3rd party read, write, or triage access to a specific
  public or private repo
- You know their GitHub login is `<USER-NAME>`
- You know the repo name is `<REPO-NAME>` and it already exists inside org
  `<ORG-NAME>`

#### Configuration

Configure the access in `config/org.<ORG-NAME>.cue` with the following path and
minimum concrete configuration:

```CUE
github: org: <ORG-NAME>: config: {
  resource: {
    _non_org_member_access: {
      collaborator: {
        <USER-NAME>: {
          <REPO-NAME>: "pull" | "push" | "triage"
        }
      }
    }
  }
}
```

Now read the
[content change](#making-a-content-change-in-one-or-more-orgs)
section.

### Adding An Org To The System

#### Prerequisites

- You want to give the system the ability to create GitHub entities inside a
  GitHub org called `<ORG-NAME>`
- The GitHub org already exists
  - or you can create it via
    [their web UI](https://github.com/account/organizations/new)
- You want the org to adopt our
  [org-level default settings](config/defaults.cue)
  - *or* you know which of the org's settings deviate from our defaults, and
    what their values are
- The machine user account `FIXME_MACHINE_USER_ACCOUNT_USERNAME`
  has been manually invited into the org as an owner
  - ... and the machine user has logged in and accepted the invitation via the
    GitHub web UI
- You have created a dedicated "CLI-driven workflow" workspace in Terraform
  Cloud for the org
  [via their web UI](https://app.terraform.io)
  - The workflow is the "CLI-driven" flavour
  - The workspace is named `org_<ORG-NAME>`
  - You have tagged it, after creation, via the workspace's main page, with
    these tags:
    - `service:github`
    - `org:<ORG-NAME>`
  - You have switched the workspace's "Execution Mode" to "Local" via the
    workspace's Settings page

#### Configuration

Create the file `config/org.<ORG-NAME>.cue` with the following minimum content:

```CUE
package config

github: org: <ORG-NAME>: {}
```

If there are any
[org-level settings](https://registry.terraform.io/providers/integrations/github/5.25.1/docs/resources/organization_settings#argument-reference)
that deviate from our defaults in `config/defaults.cue`, place them at this
path:

```CUE
github: org: <ORG-NAME>: config: {
  resource: {
    github_organization_settings: self: {
      ...
    }
  }
}
```

The controlling schema is at
`internal/schemata/providers/github/organization_settings.cue`

Adopting this config *will* change the existing org-level settings to our
defaults (or your overrides) **without showing you the existing values** in a
PR's `terraform plan` output.

Now read the
[content change](#making-a-content-change-in-one-or-more-orgs)
section.

## UNTESTED Quickstart Guides

These guides have never been tested, and are purely indicative of the process
that might be followed. If you complete any of the following, please validate
its process carefully and consider promoting it to the main
[Quickstart](#quickstart-guides) section if it's robust enough.

### Renaming A Repo

NB **THIS PROCESS HAS NOT BEEN TESTED**. So long as it sits in this section of
the documentation ("UNTESTED Quickstart Guides") please exercise **extreme**
caution when following this process, and add any updates/changes/better-words
that you feel would help the next reader.

#### Prerequisites

- a repo named `<REPO-1>` exists in the org `<ORG-NAME>`
- a repo named `<REPO-2>` **does *not* exist** in that same org
- you want to rename `<REPO-1>` to `<REPO-2>`, inside the same org
- you accept that the outside collaborators with access to `<REPO-1>` will get
  re-invited to collaborate on the repo after the renaming

#### Configuration

In the `config` package, in the file dedicated to `<ORG-NAME>`'s resources,
find the struct

```cue
github: org: <ORG-NAME>: config: resource
```

Inside that struct, find the `github_repository: <REPO-1>` struct.

Change the path element `<REPO-1>` to `<REPO-2>`.

Also find and change any references to the repo's name in other structs such
as:

- `_non_org_member_access: collaborator`
- `_non_org_member_access: bot`

The `github_repository_collaborators` struct cannot be updated in place, so a
destroy/create cycle will be performed on that resource. This will re-invite
any collaborator or bot accounts to collaborate on `<REPO-2>`, and will require
them to accept the invitation before access is re-granted.

Add a new struct:

```cue
github: org: <ORG-NAME>: config: moved
```

`moved` is an ordered list of `{ from: string, to: string }` tuples that
enables Terraform to track identifier renames over time. You may well be
establishing the first such element of the struct, and the struct
itself, as we haven't used this Terraform feature previously.

`from` and `to` must contain the **Terraform-visible** identifiers of the old
and renamed repo, respectively. This means that they must reflect the name changes
that are performed by `target.terraform.#Identifier.adapt{}` - which, among
other things, changes periods into underscores.

Both `from` and `to` must be strings, not CUE-resolved references. Neither
should refer to a resource's CUE `#tfref` convenience field (that normally
contains the Terraform-visible identifier for a resource, as a string) because
at least one of the before- and after-the-renaming CUE structs will be missing
from your config.

Now read the
[content change](#making-a-content-change-in-one-or-more-orgs) section, paying
very close attention to the mid-PR Terraform plan output, telling you what will
be created, updated in place, update with a destroy/recreate, and destroyed
entirely. **Be very, very sure that you understand what Terraform is proposing
to do**.

### Moving A Repo Across Orgs

NB **THIS PROCESS HAS NOT BEEN TESTED** and is only sketched out as an
indicator for an experienced user of this system to use as a starting point. So
long as it sits in this section of the documentation ("UNTESTED Quickstart
Guides") please exercise **extreme** caution when adapting this process, and
add any updates/changes/better-words that you feel would help the next reader.

This process is a lightweight concept for how transferring a repo across orgs
might work. It will require admin-level involvement halfway through, as it
leans on the *UI*-based "transfer a repo" feature that's only available to repo
admins. This is because there doesn't appear to be support for cross-org
transfers in
[the `github` Terraform provider](https://github.com/integrations/terraform-provider-github/issues?q=is%3Aissue+transfer).

1. Move the config defining the repo between the 2 orgs' `config/org.*.cue`
   files and `resource` structs
1. Move (or delete) the config of any resources that are dependent on the repo
   (such as access granted via `_non_org_member_access` between the 2 orgs'
   `resource` structs
1. Raise a PR containing these changes in line with the 
   [content change](#making-a-content-change-in-one-or-more-orgs) section, but
   **do not merge the PR**
1. Observe that the `terraform plan` output posted to the PR as comments shows
   that the repo will be deleted from one org and created in the other. Again,
   **do not merge the PR**
1. Ensure that all your colleagues are aware that **from this point onwards,
   until further notice**, you must have an exclusive lock on the repo, and
   **they must *not* open, sync, or merge any PRs, or otherwise cause a
   `terraform` invocation to ocurr**
1. Use a GitHub account (probably an org-owner, or one that has, at minimum,
   repo-admin permissions on the repo in question and the ability to create
   repos in the receiving org) to perform the transfer via the repo's settings
   UI
1. Re-run the PR's checks. Observe that the donating org's plan no longer tries
   to delete the repo (though it *will* be proposing deletion of various linked
   resources). Observe that the receiving org's plan still shows it is going to
   try and create the repo. As above, **do not merge the PR**
1. Follow the relevant parts of the separate doc on [managing existing github
   resources](/docs/managing-existing-resources.md), making adjustments where
   neccessary when your situation differs from that assumed by the document
   - in particular, you must perform all local `terraform` invocations whilst
     your PR'd branch is checked out, and your litmus test for success is *not*
     "the PR shows a no-op change". You won't raise a second PR, and you
     **won't** mark your PR as a no-op with `TERRAFORM-PLAN-NO-OP-REQUIRED`
     (because the donating org will have some resources deleted)
   - all the warnings in that doc about the risks involved still hold
   - all the warnings in that doc about the "critical region" still hold
1. When you have performed the import, re-run your PR's checks. Observe that:
   - the *donating* org will still have some deletions. Understand and agree
     with each
   - the receving org will have some creations
     - but critically *not* the `github_repository` resource
     - understand and agree with each
1. If the above point is not 100% the case, reach out for support *immediately*.
1. Merge the PR, and verify that the changes performed after the merge match
   those proposed in the PR comments
1. Advise your colleagues that the critical region has finished.
