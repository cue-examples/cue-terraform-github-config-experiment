package config

// company employees and their GitHub logins

company: {
	#Employee: login: github: string
	employees: {
		[_]: #Employee
	}
}
