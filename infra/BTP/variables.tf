variable "globalaccount" {
  description = "Subdomain of the SAP BTP global account"
  type        = string

  validation {
    condition     = length(trimspace(var.globalaccount)) > 0
    error_message = "globalaccount must be set (issue form or GLOBALACCOUNT secret)."
  }
}

variable "project_name" {
  description = "Base name used to build the subaccount names"
  type        = string
  default     = "Project ABC"
}

variable "project_costcenter" {
  description = "Cost center assigned to the subaccounts"
  type        = string
  default     = "12345"

  validation {
    condition     = can(regex("^[0-9]{5}$", var.project_costcenter))
    error_message = "Cost center must be a 5 digit number."
  }
}

variable "subaccount_full_admins" {
  description = "List of users to assign all available role collections on every subaccount"
  type        = list(string)
  default     = []
}

variable "subaccounts" {
  description = "Map of SAP BTP subaccounts to create. By default it creates test and prod."
  type = map(object({
    stage             = string
    region            = string
    subdomain_prefix  = optional(string)
    beta_enabled      = optional(bool)
    emergency_admins  = optional(list(string), [])
    additional_labels = optional(map(list(string)), {})
  }))

  default = {
    test = {
      stage            = "TEST"
      region           = "us10"
      subdomain_prefix = "test"
      emergency_admins = []
      additional_labels = {
        landscape = ["nonprod"]
      }
    }
    prod = {
      stage            = "PROD"
      region           = "us10"
      subdomain_prefix = "prod"
      emergency_admins = []
      additional_labels = {
        landscape = ["prod"]
      }
    }
  }

  validation {
    condition = alltrue([
      for subaccount in values(var.subaccounts) : contains(["us10", "ap21"], subaccount.region)
    ])
    error_message = "Each subaccount region must be one of us10 or ap21."
  }

  validation {
    condition = alltrue([
      for subaccount in values(var.subaccounts) : contains(["DEV", "TEST", "PROD"], subaccount.stage)
    ])
    error_message = "Each subaccount stage must be one of DEV, TEST or PROD."
  }
}

variable "integration_suite_enabled" {
  description = "Enable Integration Suite entitlement, subscription and role assignments"
  type        = bool
  default     = false
}

variable "integration_suite_subaccounts" {
  description = "Subaccount keys where Integration Suite should be enabled"
  type        = list(string)
  default     = ["test", "prod"]
}

variable "integration_suite_admin_users" {
  description = "Users to assign Integration Suite focused role collections in selected subaccounts"
  type        = list(string)
  default     = []
}

variable "integration_suite_assign_roles_to_full_admins" {
  description = "Also assign Integration Suite focused roles to users already listed as subaccount full admins"
  type        = bool
  default     = false
}

variable "integration_suite_role_collection_patterns" {
  description = "Case-insensitive substrings used to match Integration Suite role collection names"
  type        = list(string)
  default = [
    "integration",
    "suite"
  ]
}

variable "integration_suite_service_name" {
  description = "Technical service name used for entitlement and subscription"
  type        = string
  default     = "integrationsuite-trial"
}

variable "integration_suite_plan_name" {
  description = "Optional fixed plan name override for Integration Suite. Leave empty to auto-select"
  type        = string
  default     = ""
}

variable "integration_suite_plan_name_candidates" {
  description = "Ordered candidate plan names used when integration_suite_plan_name is empty"
  type        = list(string)
  default = [
    "trial",
    "standard"
  ]
}

variable "integration_suite_entitlement_amount" {
  description = "Entitlement amount for Integration Suite in each selected subaccount"
  type        = number
  default     = 1
}
