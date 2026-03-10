data "btp_globalaccount" "this" {}

data "btp_globalaccount_entitlements" "this" {}

data "btp_subaccount" "existing_for_is" {
  for_each = var.integration_suite_enabled ? var.integration_suite_existing_subaccount_ids : {}
  id       = each.value
}

data "btp_subaccount_role_collections" "existing_is_role_collections" {
  for_each      = var.integration_suite_enabled ? var.integration_suite_existing_subaccount_ids : {}
  subaccount_id = each.value

  depends_on = [btp_subaccount_subscription.integration_suite]
}

resource "random_uuid" "subaccount_suffix" {
  for_each = var.subaccounts
}

locals {
  normalized_subaccounts = {
    for key, subaccount in var.subaccounts : key => {
      stage             = upper(subaccount.stage)
      region            = subaccount.region
      beta_enabled      = try(subaccount.beta_enabled, upper(subaccount.stage) != "PROD")
      emergency_admins  = try(subaccount.emergency_admins, [])
      additional_labels = try(subaccount.additional_labels, {})
      name              = "${upper(subaccount.stage)} ${var.project_name}"
      subdomain_base    = lower(replace("${coalesce(try(subaccount.subdomain_prefix, null), key)}-${var.project_name}", " ", "-"))
    }
  }

  role_collection_assignments = {
    for assignment in flatten([
      for subaccount_key, subaccount in local.normalized_subaccounts : [
        for admin in subaccount.emergency_admins : {
          key            = "${subaccount_key}:${admin}"
          subaccount_key = subaccount_key
          admin          = admin
        }
      ]
    ]) : assignment.key => assignment
  }

  full_admin_assignments = {
    for assignment in flatten([
      for subaccount_key in keys(local.normalized_subaccounts) : [
        for user in var.subaccount_full_admins : {
          key            = "${subaccount_key}:${user}"
          subaccount_key = subaccount_key
          user           = user
        }
      ]
    ]) : assignment.key => assignment
  }

  integration_suite_targets = var.integration_suite_enabled ? (
    length(var.integration_suite_existing_subaccount_ids) > 0
    ? data.btp_subaccount.existing_for_is
    : {
        for key, subaccount in btp_subaccount.environment : key => subaccount
        if contains(var.integration_suite_subaccounts, key)
      }
  ) : {}

    integration_suite_global_account_plans = toset([
      for entitlement in values(data.btp_globalaccount_entitlements.this.values) : entitlement.plan_name
      if entitlement.service_name == var.integration_suite_service_name
    ])

  integration_suite_plan_by_subaccount = var.integration_suite_enabled ? {
    for key, _ in local.integration_suite_targets : key => (
      length(trimspace(var.integration_suite_plan_name)) > 0
      ? trimspace(var.integration_suite_plan_name)
        : try([
          for candidate in var.integration_suite_plan_name_candidates : candidate
          if contains(local.integration_suite_global_account_plans, candidate)
        ][0], "")
    )
  } : {}

  integration_suite_role_collections = var.integration_suite_enabled ? (
    length(var.integration_suite_existing_subaccount_ids) > 0
    ? data.btp_subaccount_role_collections.existing_is_role_collections
    : { for key, _ in local.integration_suite_targets : key => data.btp_subaccount_role_collections.all[key] }
  ) : {}

  integration_suite_role_assignments = var.integration_suite_enabled ? {
    for assignment in flatten([
      for subaccount_key, subaccount in local.integration_suite_targets : [
        for rc in local.integration_suite_role_collections[subaccount_key].values : [
          for user in var.integration_suite_admin_users : {
            key           = "${subaccount_key}:${rc.name}:${user}"
            subaccount_id = subaccount.id
            rc_name       = rc.name
            user          = user
          }
          if var.integration_suite_assign_roles_to_full_admins || !contains(var.subaccount_full_admins, user)
        ]
        if length([
          for pattern in var.integration_suite_role_collection_patterns : pattern
          if strcontains(lower(rc.name), lower(pattern))
        ]) > 0
      ]
    ]) : assignment.key => assignment
  } : {}
}

resource "btp_subaccount" "environment" {
  for_each = local.normalized_subaccounts

  name         = each.value.name
  subdomain    = "${each.value.subdomain_base}-${random_uuid.subaccount_suffix[each.key].result}"
  region       = each.value.region
  beta_enabled = each.value.beta_enabled
  labels = merge(
    {
      stage      = [each.value.stage]
      costcenter = [var.project_costcenter]
      managed_by = ["terraform"]
    },
    each.value.additional_labels
  )
}

resource "btp_subaccount_role_collection_assignment" "emergency_administrators" {
  for_each = local.role_collection_assignments

  subaccount_id        = btp_subaccount.environment[each.value.subaccount_key].id
  role_collection_name = "Subaccount Administrator"
  user_name            = each.value.admin
}

# -----------------------------------------------------------------------
# Assign ALL available role collections to the configured full admins
# -----------------------------------------------------------------------

data "btp_subaccount_role_collections" "all" {
  for_each = btp_subaccount.environment

  subaccount_id = each.value.id
}

resource "btp_subaccount_role_collection_assignment" "full_admins" {
  for_each = local.full_admin_assignments

  subaccount_id        = btp_subaccount.environment[each.value.subaccount_key].id
  role_collection_name = "Subaccount Administrator"
  user_name            = each.value.user
}

# -----------------------------------------------------------------------
# Integration Suite: entitlement + subscription + focused role grants
# -----------------------------------------------------------------------

resource "btp_subaccount_entitlement" "integration_suite" {
  for_each = local.integration_suite_targets

  subaccount_id = each.value.id
  service_name  = var.integration_suite_service_name
  plan_name     = local.integration_suite_plan_by_subaccount[each.key]
  amount        = var.integration_suite_entitlement_amount

  lifecycle {
    precondition {
      condition     = length(local.integration_suite_plan_by_subaccount[each.key]) > 0
      error_message = "No suitable Integration Suite plan found in global account entitlements. Set integration_suite_plan_name explicitly or adjust integration_suite_plan_name_candidates."
    }
  }
}

resource "btp_subaccount_subscription" "integration_suite" {
  for_each = local.integration_suite_targets

  subaccount_id = each.value.id
  app_name      = var.integration_suite_service_name
  plan_name     = local.integration_suite_plan_by_subaccount[each.key]

  depends_on = [btp_subaccount_entitlement.integration_suite]
}

resource "btp_subaccount_role_collection_assignment" "integration_suite_admins" {
  for_each = local.integration_suite_role_assignments

  subaccount_id        = each.value.subaccount_id
  role_collection_name = each.value.rc_name
  user_name            = each.value.user
  depends_on           = [btp_subaccount_subscription.integration_suite]
}
