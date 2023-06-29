package config

// Admin-reviewable constraints over external dependencies' versions

// Terraform, like Go, treats its major versions as sufficiently meaningful
// that *actual* major version transitions are extremely rare.
// A minor version bump is something which we would like admin visibility over.
// A patch version bump is an acceptable non-admin-reviewable upgrade.
versions: terraform: core: =~#"^1\.4\."#
