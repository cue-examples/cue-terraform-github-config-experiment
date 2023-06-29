package infrastructure

import (
	"path"
	"tool/file"
	"tool/exec"
	"encoding/json"
	"encoding/yaml"
	"strings"

	"github.com/cue-examples/cue-terraform-github-config-experiment/config"
)

_goos: string @tag(os,var=os)

command: {
	gen_terraform: {
		let json_indent = "    " & strings.MinRunes(4) & strings.MaxRunes(4)
		let dir_operations = path.FromSlash("_operations/github", path.Unix)
		let file_tf_json = "config.tf.json"
		let file_lockfile = ".terraform.lock.hcl"

		remove: {
			glob: file.Glob & {
				glob: path.Join([dir_operations, "*", "*.tf.json"], _goos)
				files: [...string]
			}
			for _, _filename in glob.files {
				"delete \(_filename)": file.RemoveAll & {
					path: _filename
				}
			}
		}

		orgs: {
			for orgName, orgTerraform in config.target.terraform.github.org
			let dir_org = path.Join([dir_operations, orgName], _goos)
			let dir_org_tmp = path.Join([dir_org, "tmp"], _goos)
			let file_org_config = path.Join([dir_org, file_tf_json], _goos)
			let file_org_tmp_gitkeep = path.Join([dir_org_tmp, ".gitkeep"], _goos)
			let file_org_lockfile = path.Join([dir_org, file_lockfile], _goos)
			let task_mkdir_org_tmp_id = "mkdir \(dir_org_tmp)" {
				(task_mkdir_org_tmp_id): file.Mkdir & {
					$after: [ for v in remove {v}]
					path:          dir_org_tmp
					createParents: true
				}
				"generate config \(file_org_config)": file.Create & {
					$after: [ orgs[task_mkdir_org_tmp_id]]
					filename: file_org_config
					contents: json.Indent(json.Marshal(orgTerraform.config), "", json_indent) + "\n"
				}
				"generate \(file_org_tmp_gitkeep)": file.Create & {
					$after: [ orgs[task_mkdir_org_tmp_id]]
					filename: file_org_tmp_gitkeep
					contents: ""
				}
				"symlink \(file_org_lockfile)": exec.Run & {
					$after: [ orgs[task_mkdir_org_tmp_id]]
					let target = path.Join(["..", ".terraform_lockfile", file_lockfile], _goos)
					dir: dir_org
					// the single param form of `ln -s` creates a file in CWD, named after the target file
					cmd: [ "ln", "-nfs", target]
					success: true
				}
			}
		}

		lockfile: file.Create & {
			$after: [ for v in remove {v}]
			filename: path.Join([dir_operations, ".terraform_lockfile", file_tf_json])
			let tf = {
				terraform: config.github.terraform
			}
			contents: json.Indent(json.Marshal(tf), "", json_indent) + "\n"
		}
	}

	gen_ci: {
		github: {
			let dir_gha = path.FromSlash(".github/workflows", path.Unix)
			mkdir: file.Mkdir & {
				path:          dir_gha
				createParents: true
			}
			remove: {
				glob: file.Glob & {
					$after: mkdir
					glob:   path.Join([dir_gha, "*.yml"], _goos)
					files: [...string]
				}
				for _, _filename in glob.files {
					"delete \(_filename)": file.RemoveAll & {
						path: _filename
					}
				}
			}
			workflows: {
				let warning = "# Code generated by generate_tool.cue - DO NOT EDIT."
				for workflow_file_prefix, workflow_content in config.github.actions.workflow
				let _filename = workflow_file_prefix + ".yml" {
					"generate \(_filename)": file.Create & {
						$after: [ for v in remove {v}]
						filename: path.Join([dir_gha, _filename], _goos)
						contents: "\(warning)\n\(yaml.Marshal(workflow_content))"
					}
				}
			}
		}
	}
}
