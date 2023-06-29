package terraform

#resource: {
	for_each?: string
	lifecycle?: {
		create_before_destroy?: bool
		prevent_destroy?:       bool
		ignore_changes?: [...string]
		replace_triggered_by?: [...string]
	}
	depends_on?: [...string]
}
