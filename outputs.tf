##
# (c) 2021-2026
#     Cloud Ops Works LLC - https://cloudops.works/
#     Find us on:
#       GitHub: https://github.com/cloudopsworks
#       WebSite: https://cloudops.works
#     Distributed Under Apache v2.0 License
#

output "default_host_management_role_arn" {
  description = "ARN of the module-created Default Host Management Configuration IAM role, or null when an existing role is used"
  value       = try(aws_iam_role.default_host_management[0].arn, null)
}

output "automation_log_group_name" {
  description = "CloudWatch Logs group configured for Systems Manager Automation customer-script logging"
  value       = local.automation_logging_enabled ? local.automation_log_group_name : null
}

output "inventory_association_id" {
  description = "ID of the AWS-GatherSoftwareInventory State Manager association"
  value       = try(aws_ssm_association.inventory[0].association_id, null)
}

output "inventory_resource_data_sync_name" {
  description = "Name of the optional Systems Manager Inventory resource data sync"
  value       = try(aws_ssm_resource_data_sync.inventory[0].name, null)
}

output "document_arns" {
  description = "ARNs of customer-owned, tagged Systems Manager documents keyed by settings.documents key"
  value       = { for key, document in aws_ssm_document.this : key => document.arn }
}

output "association_ids" {
  description = "IDs of custom State Manager associations keyed by settings.associations key"
  value       = { for key, association in aws_ssm_association.this : key => association.association_id }
}

output "patch_scan_association_id" {
  description = "ID of the non-rebooting AWS-RunPatchBaseline Scan association"
  value       = try(aws_ssm_association.patch_scan[0].association_id, null)
}

output "patch_baseline_ids" {
  description = "IDs of custom patch baselines keyed by settings.patch_baselines key"
  value       = { for key, baseline in aws_ssm_patch_baseline.this : key => baseline.id }
}

output "maintenance_window_ids" {
  description = "IDs of maintenance windows keyed by settings.maintenance_windows key"
  value       = { for key, window in aws_ssm_maintenance_window.this : key => window.id }
}

output "maintenance_window_target_ids" {
  description = "IDs of maintenance window targets keyed as window.target"
  value       = { for key, target in aws_ssm_maintenance_window_target.this : key => target.id }
}

output "maintenance_window_task_ids" {
  description = "IDs of maintenance window tasks keyed as window.task"
  value       = { for key, task in aws_ssm_maintenance_window_task.this : key => task.id }
}

output "security_hub_ssm_controls" {
  description = "Module configuration status and Terraform resources supporting Security Hub CSPM controls SSM.1 through SSM.7"
  value = {
    "SSM.1" = {
      configured = local.default_host_management_enabled
      resources  = compact([try(aws_ssm_service_setting.default_host_management[0].id, null)])
    }
    "SSM.2" = {
      configured = local.patch_scan_enabled
      resources  = compact([try(aws_ssm_association.patch_scan[0].association_id, null)])
    }
    "SSM.3" = {
      configured = local.inventory_enabled || local.patch_scan_enabled || length(local.ssm_associations) > 0
      resources = concat(
        compact([try(aws_ssm_association.inventory[0].association_id, null)]),
        compact([try(aws_ssm_association.patch_scan[0].association_id, null)]),
        [for association in aws_ssm_association.this : association.association_id]
      )
    }
    "SSM.4" = {
      configured = local.block_public_document_sharing
      resources  = compact([try(aws_ssm_service_setting.block_public_document_sharing[0].id, null)])
    }
    "SSM.5" = {
      configured = length(local.ssm_documents) > 0
      resources  = [for document in aws_ssm_document.this : document.arn]
    }
    "SSM.6" = {
      configured = local.automation_logging_enabled
      resources = compact([
        try(aws_ssm_service_setting.automation_log_destination[0].id, null),
        try(aws_ssm_service_setting.automation_log_group[0].id, null),
      ])
    }
    "SSM.7" = {
      configured = local.block_public_document_sharing
      resources  = compact([try(aws_ssm_service_setting.block_public_document_sharing[0].id, null)])
    }
  }
}
