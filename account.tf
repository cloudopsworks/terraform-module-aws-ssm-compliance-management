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
    "/aws/ssm/automation/${local.system_name}"
  )

  block_public_document_sharing = try(var.settings.document_security.block_public_sharing, true)
}

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

resource "aws_cloudwatch_log_group" "automation" {
  count = local.automation_logging_create_log_group ? 1 : 0

  name              = local.automation_log_group_name
  retention_in_days = try(var.settings.automation_logging.retention_in_days, 365)
  kms_key_id        = try(var.settings.automation_logging.kms_key_id, null)
  skip_destroy      = try(var.settings.automation_logging.skip_destroy, false)
  tags              = local.all_tags
}

resource "aws_ssm_service_setting" "automation_log_destination" {
  count = local.automation_logging_enabled ? 1 : 0

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
