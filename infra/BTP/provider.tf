terraform {
  required_providers {
    btp = {
      source  = "SAP/btp"
      version = "~> 1.20.0"
    }

    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}

provider "btp" {
  globalaccount = var.globalaccount
}
