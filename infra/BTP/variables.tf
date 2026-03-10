variable "globalaccount" {
  description = "Subdomain of the SAP BTP global account"
  type        = string
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
