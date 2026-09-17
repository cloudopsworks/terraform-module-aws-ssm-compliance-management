##
# (c) 2021-2026
#     Cloud Ops Works LLC - https://cloudops.works/
#     Find us on:
#       GitHub: https://github.com/cloudopsworks
#       WebSite: https://cloudops.works
#     Distributed Under Apache v2.0 License
#

locals {
  patch_scan_enabled = try(var.settings.patch_scan.enabled, true)
  patch_scan_targets = try(var.settings.patch_scan.targets, [{
    key    = "InstanceIds"
    values = ["*"]
  }])
  patch_baselines = try(var.settings.patch_baselines, {})
  patch_groups    = try(var.settings.patch_groups, {})
}

resource "aws_ssm_association" "patch_scan" {
  count = local.patch_scan_enabled ? 1 : 0

  name                        = "AWS-RunPatchBaseline"
  association_name            = try(var.settings.patch_scan.association_name, "ssm-patch-scan-${local.system_name}")
  schedule_expression         = try(var.settings.patch_scan.schedule, "rate(1 day)")
  apply_only_at_cron_interval = try(var.settings.patch_scan.apply_only_at_cron_interval, false)
  compliance_severity         = try(var.settings.patch_scan.compliance_severity, "HIGH")
  sync_compliance             = "AUTO"
  max_concurrency             = try(var.settings.patch_scan.max_concurrency, "10%")
  max_errors                  = try(var.settings.patch_scan.max_errors, "1")
  wait_for_success_timeout_seconds = try(
    var.settings.patch_scan.wait_for_success_timeout_seconds,
    null
  )
  parameters = {
    Operation    = "Scan"
    RebootOption = "NoReboot"
  }

  dynamic "targets" {
    for_each = local.patch_scan_targets
    content {
      key    = targets.value.key
      values = targets.value.values
    }
  }
}

resource "aws_ssm_patch_baseline" "this" {
  for_each = local.patch_baselines

  name                                 = try(each.value.name, "${local.system_name}-${each.key}")
  description                          = try(each.value.description, "Managed by terraform-module-aws-ssm-compliance-management")
  operating_system                     = try(each.value.operating_system, "AMAZON_LINUX_2")
  approved_patches                     = try(each.value.approved_patches, null)
  approved_patches_compliance_level    = try(each.value.approved_patches_compliance_level, null)
  approved_patches_enable_non_security = try(each.value.approved_patches_enable_non_security, null)
  rejected_patches                     = try(each.value.rejected_patches, null)
  rejected_patches_action              = try(each.value.rejected_patches_action, null)
  available_security_updates_compliance_status = try(
    each.value.available_security_updates_compliance_status,
    null
  )
  tags = merge(local.all_tags, try(each.value.tags, {}))

  dynamic "approval_rule" {
    for_each = try(each.value.approval_rules, [])
    content {
      approve_after_days  = try(approval_rule.value.approve_after_days, null)
      approve_until_date  = try(approval_rule.value.approve_until_date, null)
      compliance_level    = try(approval_rule.value.compliance_level, null)
      enable_non_security = try(approval_rule.value.enable_non_security, false)

      dynamic "patch_filter" {
        for_each = approval_rule.value.patch_filters
        content {
          key    = patch_filter.value.key
          values = patch_filter.value.values
        }
      }
    }
  }

  dynamic "global_filter" {
    for_each = try(each.value.global_filters, [])
    content {
      key    = global_filter.value.key
      values = global_filter.value.values
    }
  }

  dynamic "source" {
    for_each = try(each.value.sources, [])
    content {
      name          = source.value.name
      products      = source.value.products
      configuration = source.value.configuration
    }
  }
}

resource "aws_ssm_patch_group" "this" {
  for_each = local.patch_groups

  patch_group = each.value.patch_group
  baseline_id = try(each.value.baseline_id, null) != null ? each.value.baseline_id : aws_ssm_patch_baseline.this[each.value.baseline_key].id
}
