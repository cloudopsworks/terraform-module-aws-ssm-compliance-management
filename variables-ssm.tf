##
# (c) 2021-2026
#     Cloud Ops Works LLC - https://cloudops.works/
#     Find us on:
#       GitHub: https://github.com/cloudopsworks
#       WebSite: https://cloudops.works
#     Distributed Under Apache v2.0 License
#

# settings: # (Optional) AWS Systems Manager compliance settings. Default: {}
#   default_host_management:
#     enabled: true
#     create_role: true
#     role_name: AWSSystemsManagerDefaultEC2InstanceManagementRole
#     role_path: /service-role/
#     additional_policy_arns: []
#   automation_logging:
#     enabled: true
#     create_log_group: true
#     log_group_name: /aws/ssm/automation/example
#     retention_in_days: 365
#     kms_key_id: null
#     skip_destroy: false
#   document_security:
#     block_public_sharing: true
#   inventory:
#     enabled: true
#     association_name: ssm-inventory-example
#     schedule: rate(1 day)
#     targets:
#       - key: InstanceIds
#         values: ["*"]
#     parameters: {}
#     resource_data_sync:
#       enabled: false
#       name: inventory-sync
#       bucket_name: example-inventory
#       prefix: inventory
#       region: us-east-1
#       kms_key_arn: null
#   patch_scan:
#     enabled: true
#     association_name: ssm-patch-scan-example
#     schedule: rate(1 day)
#     targets:
#       - key: InstanceIds
#         values: ["*"]
#     compliance_severity: HIGH
#   documents:
#     example:
#       name: ExampleDocument
#       document_type: Command
#       document_format: YAML
#       content: |-
#         schemaVersion: '2.2'
#         description: Example
#         mainSteps: []
#       shared_account_ids: []
#   associations:
#     example:
#       name: AWS-UpdateSSMAgent
#       schedule_expression: rate(7 days)
#       parameters: {}
#       targets:
#         - key: InstanceIds
#           values: ["*"]
#   patch_baselines:
#     amazon_linux:
#       name: example-amazon-linux
#       operating_system: AMAZON_LINUX_2
#       description: Security patch baseline
#       approval_rules:
#         - approve_after_days: 7
#           compliance_level: HIGH
#           enable_non_security: false
#           patch_filters:
#             - key: CLASSIFICATION
#               values: [Security]
#   patch_groups:
#     amazon_linux:
#       patch_group: amazon-linux
#       baseline_key: amazon_linux
#   maintenance:
#     create_role: true
#     role_name: example-ssm-maintenance-window
#     role_path: /service-role/
#     additional_policy_arns: []
#   maintenance_windows:
#     monthly:
#       name: example-monthly
#       schedule: cron(0 3 ? * SUN#1 *)
#       schedule_timezone: UTC
#       duration: 4
#       cutoff: 1
#       enabled: true
#       targets:
#         linux:
#           name: linux
#           resource_type: INSTANCE
#           targets:
#             - key: tag:Patch Group
#               values: [amazon-linux]
#       tasks:
#         install:
#           name: install-approved-patches
#           task_arn: AWS-RunPatchBaseline
#           target_keys: [linux]
#           priority: 1
#           max_concurrency: 10%
#           max_errors: 1
#           parameters:
#             Operation: [Install]
#             RebootOption: [RebootIfNeeded]
variable "settings" {
  description = "AWS Systems Manager account and Region configuration for Security Hub CSPM controls SSM.1 through SSM.7; Session Manager resources are intentionally excluded"
  type        = any
  default     = {}

  validation {
    condition = alltrue(flatten([
      for _, document in try(var.settings.documents, {}) : [
        for account_id in try(document.shared_account_ids, []) : can(regex("^[0-9]{12}$", account_id))
      ]
    ]))
    error_message = "Every documents[*].shared_account_ids entry must be a 12-digit AWS account ID; public sharing with All is not supported."
  }

  validation {
    condition = alltrue([
      for _, document in try(var.settings.documents, {}) : trimspace(try(document.content, "")) != ""
    ])
    error_message = "Every settings.documents entry must provide non-empty content."
  }

  validation {
    condition = (
      !try(var.settings.inventory.resource_data_sync.enabled, false) ||
      trimspace(try(var.settings.inventory.resource_data_sync.bucket_name, "")) != ""
    )
    error_message = "inventory.resource_data_sync.bucket_name is required when the resource data sync is enabled."
  }

  validation {
    condition = alltrue([
      for _, group in try(var.settings.patch_groups, {}) :
      (try(group.baseline_id, null) != null) != (try(group.baseline_key, null) != null) &&
      (
        try(group.baseline_key, null) == null ||
        contains(keys(try(var.settings.patch_baselines, {})), try(group.baseline_key, ""))
      )
    ])
    error_message = "Every patch group must set exactly one of baseline_id or baseline_key, and baseline_key must reference settings.patch_baselines."
  }

  validation {
    condition = alltrue(flatten([
      for _, window in try(var.settings.maintenance_windows, {}) : [
        for _, task in try(window.tasks, {}) :
        length(try(task.target_keys, [])) > 0 && alltrue([
          for target_key in try(task.target_keys, []) : contains(keys(try(window.targets, {})), target_key)
        ])
      ]
    ]))
    error_message = "Every maintenance window task must set target_keys and reference targets defined in the same window."
  }

  validation {
    condition = try(var.settings.maintenance.create_role, true) || alltrue(flatten([
      for _, window in try(var.settings.maintenance_windows, {}) : [
        for _, task in try(window.tasks, {}) : trimspace(try(coalesce(task.service_role_arn, ""), "")) != ""
      ]
    ]))
    error_message = "When maintenance.create_role is false, every maintenance window task must set service_role_arn."
  }

  validation {
    condition = alltrue(flatten([
      for _, window in try(var.settings.maintenance_windows, {}) : [
        for _, task in try(window.tasks, {}) : upper(try(task.task_type, "RUN_COMMAND")) == "RUN_COMMAND"
      ]
    ]))
    error_message = "This module supports RUN_COMMAND maintenance window tasks only."
  }
}
