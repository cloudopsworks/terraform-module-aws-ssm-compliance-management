##
# (c) 2021-2026
#     Cloud Ops Works LLC - https://cloudops.works/
#     Find us on:
#       GitHub: https://github.com/cloudopsworks
#       WebSite: https://cloudops.works
#     Distributed Under Apache v2.0 License
#

locals {
  ssm_associations = try(var.settings.associations, {})
}

resource "aws_ssm_association" "this" {
  for_each = local.ssm_associations

  name                             = each.value.name
  association_name                 = try(each.value.association_name, "${local.system_name}-${each.key}")
  document_version                 = try(each.value.document_version, null)
  parameters                       = try(each.value.parameters, {})
  schedule_expression              = try(each.value.schedule_expression, null)
  apply_only_at_cron_interval      = try(each.value.apply_only_at_cron_interval, null)
  calendar_names                   = try(each.value.calendar_names, null)
  compliance_severity              = try(each.value.compliance_severity, "MEDIUM")
  sync_compliance                  = try(each.value.sync_compliance, "AUTO")
  max_concurrency                  = try(each.value.max_concurrency, null)
  max_errors                       = try(each.value.max_errors, null)
  automation_target_parameter_name = try(each.value.automation_target_parameter_name, null)
  wait_for_success_timeout_seconds = try(each.value.wait_for_success_timeout_seconds, null)

  dynamic "targets" {
    for_each = try(each.value.targets, [])
    content {
      key    = targets.value.key
      values = targets.value.values
    }
  }

  dynamic "output_location" {
    for_each = try(each.value.output_location, null) == null ? [] : [each.value.output_location]
    content {
      s3_bucket_name = output_location.value.s3_bucket_name
      s3_key_prefix  = try(output_location.value.s3_key_prefix, null)
      s3_region      = try(output_location.value.s3_region, null)
    }
  }

  depends_on = [aws_ssm_document.this]
}
