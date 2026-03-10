output "subaccount_ids" {
  description = "IDs of the created SAP BTP subaccounts keyed by environment name"
  value = {
    for key, subaccount in btp_subaccount.environment : key => subaccount.id
  }
}

output "subaccount_names" {
  description = "Names of the created SAP BTP subaccounts keyed by environment name"
  value = {
    for key, subaccount in btp_subaccount.environment : key => subaccount.name
  }
}

output "subaccount_subdomains" {
  description = "Subdomains of the created SAP BTP subaccounts keyed by environment name"
  value = {
    for key, subaccount in btp_subaccount.environment : key => subaccount.subdomain
  }
}

output "subaccount_urls" {
  description = "Cockpit URLs of the created SAP BTP subaccounts keyed by environment name"
  value = {
    for key, subaccount in btp_subaccount.environment : key => "https://account.hanatrial.ondemand.com/trial/#/globalaccount/${data.btp_globalaccount.this.id}/subaccount/${subaccount.id}"
  }
}

output "integration_suite_selected_plans" {
  description = "Selected Integration Suite plan names keyed by environment name"
  value       = local.integration_suite_plan_by_subaccount
}

output "integration_suite_subscription_ids" {
  description = "Integration Suite subscription IDs keyed by environment name"
  value = {
    for key, subscription in btp_subaccount_subscription.integration_suite : key => subscription.id
  }
}

output "integration_suite_subscription_urls" {
  description = "Integration Suite subscription URLs keyed by environment name"
  value = {
    for key, subscription in btp_subaccount_subscription.integration_suite : key => subscription.subscription_url
  }
}
