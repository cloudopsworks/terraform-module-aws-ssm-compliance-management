##
# (c) 2021-2026
#     Cloud Ops Works LLC - https://cloudops.works/
#     Find us on:
#       GitHub: https://github.com/cloudopsworks
#       WebSite: https://cloudops.works
#     Distributed Under Apache v2.0 License
#

locals {
  maintenance_windows = try(var.settings.maintenance_windows, {})
  maintenance_targets = merge({}, [
    for window_key, window in local.maintenance_windows : {
      for target_key, target in try(window.targets, {}) : "${window_key}.${target_key}" => merge(target, {
        window_key = window_key
        target_key = target_key
      })
    }
  ]...)
  maintenance_tasks = merge({}, [
    for window_key, window in local.maintenance_windows : {
      for task_key, task in try(window.tasks, {}) : "${window_key}.${task_key}" => merge(task, {
        window_key = window_key
        task_key   = task_key
      })
    }
  ]...)
  maintenance_create_role = length(local.maintenance_tasks) > 0 && try(
    var.settings.maintenance.create_role,
    true
  )
  maintenance_role_name = try(
    var.settings.maintenance.role_name,
    "${local.system_name_short}-ssm-maintenance-window"
  )
  maintenance_role_path                = try(var.settings.maintenance.role_path, "/service-role/")
  maintenance_additional_policy_arns   = distinct(try(var.settings.maintenance.additional_policy_arns, []))
  maintenance_default_service_role_arn = local.maintenance_create_role ? aws_iam_role.maintenance[0].arn : null
}

resource "aws_iam_role" "maintenance" {
  count = local.maintenance_create_role ? 1 : 0

  name        = local.maintenance_role_name
  path        = local.maintenance_role_path
  description = "Service role for Systems Manager maintenance window tasks"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "ssm.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
  tags = local.all_tags
}

resource "aws_iam_role_policy_attachment" "maintenance" {
  count = local.maintenance_create_role ? 1 : 0

  role       = aws_iam_role.maintenance[0].name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/service-role/AmazonSSMMaintenanceWindowRole"
}

resource "aws_iam_role_policy_attachment" "maintenance_additional" {
  for_each = local.maintenance_create_role ? toset(local.maintenance_additional_policy_arns) : toset([])

  role       = aws_iam_role.maintenance[0].name
  policy_arn = each.value
}

resource "aws_ssm_maintenance_window" "this" {
  for_each = local.maintenance_windows

  name                       = try(each.value.name, "${local.system_name}-${each.key}")
  description                = try(each.value.description, "Managed by terraform-module-aws-ssm-compliance-management")
  schedule                   = each.value.schedule
  schedule_timezone          = try(each.value.schedule_timezone, "UTC")
  schedule_offset            = try(each.value.schedule_offset, null)
  duration                   = try(each.value.duration, 4)
  cutoff                     = try(each.value.cutoff, 1)
  enabled                    = try(each.value.enabled, true)
  allow_unassociated_targets = try(each.value.allow_unassociated_targets, false)
  start_date                 = try(each.value.start_date, null)
  end_date                   = try(each.value.end_date, null)
  tags                       = merge(local.all_tags, try(each.value.tags, {}))
}

resource "aws_ssm_maintenance_window_target" "this" {
  for_each = local.maintenance_targets

  window_id         = aws_ssm_maintenance_window.this[each.value.window_key].id
  name              = try(each.value.name, each.value.target_key)
  description       = try(each.value.description, null)
  resource_type     = try(each.value.resource_type, "INSTANCE")
  owner_information = try(each.value.owner_information, null)

  dynamic "targets" {
    for_each = each.value.targets
    content {
      key    = targets.value.key
      values = targets.value.values
    }
  }
}

resource "aws_ssm_maintenance_window_task" "this" {
  for_each = local.maintenance_tasks

  window_id        = aws_ssm_maintenance_window.this[each.value.window_key].id
  name             = try(each.value.name, each.value.task_key)
  description      = try(each.value.description, null)
  task_arn         = try(each.value.task_arn, "AWS-RunPatchBaseline")
  task_type        = "RUN_COMMAND"
  priority         = try(each.value.priority, 1)
  max_concurrency  = try(each.value.max_concurrency, "10%")
  max_errors       = try(each.value.max_errors, "1")
  cutoff_behavior  = try(each.value.cutoff_behavior, "CANCEL_TASK")
  service_role_arn = trimspace(try(coalesce(each.value.service_role_arn, ""), "")) != "" ? each.value.service_role_arn : local.maintenance_default_service_role_arn

  dynamic "targets" {
    for_each = length(try(each.value.target_keys, [])) > 0 ? [true] : []
    content {
      key = "WindowTargetIds"
      values = [
        for target_key in each.value.target_keys :
        aws_ssm_maintenance_window_target.this["${each.value.window_key}.${target_key}"].id
      ]
    }
  }

  task_invocation_parameters {
    run_command_parameters {
      comment              = try(each.value.comment, null)
      document_version     = try(each.value.document_version, null)
      output_s3_bucket     = try(each.value.output_s3_bucket, null)
      output_s3_key_prefix = try(each.value.output_s3_key_prefix, null)
      timeout_seconds      = try(each.value.timeout_seconds, null)

      dynamic "parameter" {
        for_each = try(each.value.parameters, {})
        content {
          name   = parameter.key
          values = parameter.value
        }
      }

      dynamic "cloudwatch_config" {
        for_each = try(each.value.cloudwatch_output_enabled, null) == null ? [] : [true]
        content {
          cloudwatch_output_enabled = each.value.cloudwatch_output_enabled
          cloudwatch_log_group_name = try(each.value.cloudwatch_log_group_name, local.automation_log_group_name)
        }
      }

      dynamic "notification_config" {
        for_each = try(each.value.notification_config, null) == null ? [] : [each.value.notification_config]
        content {
          notification_arn    = notification_config.value.notification_arn
          notification_events = try(notification_config.value.notification_events, null)
          notification_type   = try(notification_config.value.notification_type, null)
        }
      }
    }
  }

  depends_on = [
    aws_iam_role_policy_attachment.maintenance,
    aws_iam_role_policy_attachment.maintenance_additional,
  ]
}
