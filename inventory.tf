##
# (c) 2021-2026
#     Cloud Ops Works LLC - https://cloudops.works/
#     Find us on:
#       GitHub: https://github.com/cloudopsworks
#       WebSite: https://cloudops.works
#     Distributed Under Apache v2.0 License
#

locals {
  inventory_enabled = try(var.settings.inventory.enabled, true)
  inventory_targets = try(var.settings.inventory.targets, [{
    key    = "InstanceIds"
    values = ["*"]
  }])
  inventory_parameters = merge({
    applications                = "Enabled"
    awsComponents               = "Enabled"
    customInventory             = "Enabled"
    instanceDetailedInformation = "Enabled"
    networkConfig               = "Enabled"
    services                    = "Enabled"
    windowsRoles                = "Enabled"
    windowsUpdates              = "Enabled"
  }, try(var.settings.inventory.parameters, {}))
  inventory_sync_enabled = local.inventory_enabled && try(
    var.settings.inventory.resource_data_sync.enabled,
    false
  )
}

resource "aws_ssm_association" "inventory" {
  count = local.inventory_enabled ? 1 : 0

  name                        = "AWS-GatherSoftwareInventory"
  association_name            = try(var.settings.inventory.association_name, "ssm-inventory-${local.system_name}")
  schedule_expression         = try(var.settings.inventory.schedule, "rate(1 day)")
  apply_only_at_cron_interval = try(var.settings.inventory.apply_only_at_cron_interval, false)
  max_concurrency             = try(var.settings.inventory.max_concurrency, null)
  max_errors                  = try(var.settings.inventory.max_errors, null)
  compliance_severity         = try(var.settings.inventory.compliance_severity, "MEDIUM")
  sync_compliance             = "AUTO"
  wait_for_success_timeout_seconds = try(
    var.settings.inventory.wait_for_success_timeout_seconds,
    null
  )
  parameters = local.inventory_parameters

  dynamic "targets" {
    for_each = local.inventory_targets
    content {
      key    = targets.value.key
      values = targets.value.values
    }
  }
}

resource "aws_ssm_resource_data_sync" "inventory" {
  count = local.inventory_sync_enabled ? 1 : 0

  name = try(var.settings.inventory.resource_data_sync.name, "ssm-inventory-${local.system_name_short}")

  s3_destination {
    bucket_name = var.settings.inventory.resource_data_sync.bucket_name
    prefix      = try(var.settings.inventory.resource_data_sync.prefix, "inventory")
    region      = try(var.settings.inventory.resource_data_sync.region, data.aws_region.current.region)
    sync_format = try(var.settings.inventory.resource_data_sync.sync_format, "JsonSerDe")
    kms_key_arn = try(var.settings.inventory.resource_data_sync.kms_key_arn, null)
  }
}
