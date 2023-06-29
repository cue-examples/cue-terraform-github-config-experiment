package terraform

#Config: {
	resource?: {...}
	provider?: {...}
	variable?: {...}
	moved?: [...{...}]
	terraform!: {
		cloud!: {
			organization!: string
			workspaces!: {...}
		}
		required_providers!: {...}
		required_version!: string
	}
}
