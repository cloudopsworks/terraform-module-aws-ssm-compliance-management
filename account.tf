##
# (c) 2021-2026
#     Cloud Ops Works LLC - https://cloudops.works/
#     Find us on:
#       GitHub: https://github.com/cloudopsworks
#       WebSite: https://cloudops.works
#     Distributed Under Apache v2.0 License
#

locals {
  default_host_management_enabled = try(var.settings.default_host_management.enabled, true)
  default_host_management_create_role = (
    local.default_host_management_enabled &&
    try(var.settings.default_host_management.create_role, true)
  )
  default_host_management_role_name = try(
    var.settings.default_host_management.role_name,
    "AWSSystemsManagerDefaultEC2InstanceManagementRole"
  )
  default_host_management_role_path = try(var.settings.default_host_management.role_path, "/service-role/")
  default_host_management_role_value = trimprefix(
    "${local.default_host_management_role_path}${local.default_host_management_role_name}",
    "/"
  )
  default_host_management_additional_policy_arns = distinct(try(
    var.settings.default_host_management.additional_policy_arns,
    []
  ))

  automation_logging_enabled          = try(var.settings.automation_logging.enabled, true)
  automation_logging_create_log_group = local.automation_logging_enabled && try(var.settings.automation_logging.create_log_group, true)
  automation_log_group_name = try(
    var.settings.automation_logging.log_group_name,
    "/aws/ssm/compliance-management/automation/${local.system_name}"
  )

  automation_log_group_kms_key_in = try(var.settings.automation_logging.kms_key_id, null)
  automation_logging_create_kms_key = (
    local.automation_logging_create_log_group &&
    local.automation_log_group_kms_key_in == null &&
    try(var.settings.automation_logging.create_kms_key, false)
  )
  automation_log_group_kms_key_arn = local.automation_logging_create_kms_key ? aws_kms_key.automation[0].arn : local.automation_log_group_kms_key_in
  kms_deletion_window_days_default = 30
  kms_rotation_period_days_default = 90 # Default cryptoperiod; adjustable through kms_key_rotation_period_in_days

  block_public_document_sharing = try(var.settings.document_security.block_public_sharing, true)
}

data "aws_caller_identity" "current" {}

resource "aws_iam_role" "default_host_management" {
  count = local.default_host_management_create_role ? 1 : 0

  name        = local.default_host_management_role_name
  path        = local.default_host_management_role_path
  description = "Default Host Management Configuration role for Systems Manager managed nodes"
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

resource "aws_iam_role_policy_attachment" "default_host_management" {
  count = local.default_host_management_create_role ? 1 : 0

  role       = aws_iam_role.default_host_management[0].name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/AmazonSSMManagedEC2InstanceDefaultPolicy"
}

resource "aws_iam_role_policy_attachment" "default_host_management_additional" {
  for_each = local.default_host_management_create_role ? toset(local.default_host_management_additional_policy_arns) : toset([])

  role       = aws_iam_role.default_host_management[0].name
  policy_arn = each.value
}

resource "aws_ssm_service_setting" "default_host_management" {
  count = local.default_host_management_enabled ? 1 : 0

  setting_id    = "/ssm/managed-instance/default-ec2-instance-management-role"
  setting_value = local.default_host_management_role_value

  depends_on = [
    aws_iam_role_policy_attachment.default_host_management,
    aws_iam_role_policy_attachment.default_host_management_additional,
  ]
}

# Optional customer managed key for the module-created Automation log group (NIST AU-9 / SC-28).
# The key policy only lets CloudWatch Logs use it for this one log group in this account.
data "aws_iam_policy_document" "automation_kms" {
  count = local.automation_logging_create_kms_key ? 1 : 0

  statement {
    sid       = "EnableAccountIamPolicies"
    effect    = "Allow"
    actions   = ["kms:*"]
    resources = ["*"]
    principals {
      type        = "AWS"
      identifiers = ["arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:root"]
    }
  }

  statement {
    sid       = "AllowCloudWatchLogsForAutomationLogGroup"
    effect    = "Allow"
    actions   = ["kms:Encrypt*", "kms:Decrypt*", "kms:ReEncrypt*", "kms:GenerateDataKey*", "kms:Describe*"]
    resources = ["*"]
    principals {
      type        = "Service"
      identifiers = ["logs.${data.aws_region.current.region}.${data.aws_partition.current.dns_suffix}"]
    }
    condition {
      test     = "ArnEquals"
      variable = "kms:EncryptionContext:aws:logs:arn"
      values   = ["arn:${data.aws_partition.current.partition}:logs:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:log-group:${local.automation_log_group_name}"]
    }
  }
}

resource "aws_kms_key" "automation" {
  count = local.automation_logging_create_kms_key ? 1 : 0

  description             = "SSM Automation CloudWatch Logs encryption key"
  deletion_window_in_days = try(var.settings.automation_logging.kms_key_deletion_window_in_days, local.kms_deletion_window_days_default)
  enable_key_rotation     = true # Security Hub KMS.4
  rotation_period_in_days = try(var.settings.automation_logging.kms_key_rotation_period_in_days, local.kms_rotation_period_days_default)
  policy                  = data.aws_iam_policy_document.automation_kms[0].json
  tags                    = local.all_tags

  # Encrypted Automation logs become unreadable once the key is deleted.
  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_kms_alias" "automation" {
  count = local.automation_logging_create_kms_key ? 1 : 0

  name          = "alias/ssm-automation-logs-${local.system_name}"
  target_key_id = aws_kms_key.automation[0].id
}

resource "aws_cloudwatch_log_group" "automation" {
  count = local.automation_logging_create_log_group ? 1 : 0

  name              = local.automation_log_group_name
  retention_in_days = try(var.settings.automation_logging.retention_in_days, 365)
  kms_key_id        = local.automation_log_group_kms_key_arn
  skip_destroy      = try(var.settings.automation_logging.skip_destroy, false)
  tags              = local.all_tags
}

resource "aws_ssm_service_setting" "automation_log_destination" {
  count = local.automation_logging_enabled ? 1 : 0

  lifecycle {
    precondition {
      condition     = !try(var.settings.automation_logging.create_kms_key, false) || (local.automation_logging_create_log_group && local.automation_log_group_kms_key_in == null)
      error_message = "settings.automation_logging.create_kms_key requires create_log_group = true and no kms_key_id (the key policy is scoped to the module-created log group)."
    }
  }

  setting_id    = "/ssm/automation/customer-script-log-destination"
  setting_value = "CloudWatch"
}

resource "aws_ssm_service_setting" "automation_log_group" {
  count = local.automation_logging_enabled ? 1 : 0

  setting_id    = "/ssm/automation/customer-script-log-group-name"
  setting_value = local.automation_log_group_name

  depends_on = [aws_cloudwatch_log_group.automation]
}

resource "aws_ssm_service_setting" "block_public_document_sharing" {
  count = local.block_public_document_sharing ? 1 : 0

  setting_id    = "/ssm/documents/console/public-sharing-permission"
  setting_value = "Disable"
}
