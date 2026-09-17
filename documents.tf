##
# (c) 2021-2026
#     Cloud Ops Works LLC - https://cloudops.works/
#     Find us on:
#       GitHub: https://github.com/cloudopsworks
#       WebSite: https://cloudops.works
#     Distributed Under Apache v2.0 License
#

locals {
  ssm_documents = try(var.settings.documents, {})
}

resource "aws_ssm_document" "this" {
  for_each = local.ssm_documents

  name            = try(each.value.name, "${local.system_name}-${each.key}")
  document_type   = try(each.value.document_type, "Command")
  document_format = try(each.value.document_format, "YAML")
  content         = each.value.content
  target_type     = try(each.value.target_type, null)
  version_name    = try(each.value.version_name, null)
  permissions = length(try(each.value.shared_account_ids, [])) > 0 ? {
    type        = "Share"
    account_ids = join(",", each.value.shared_account_ids)
  } : null
  tags = merge(local.all_tags, try(each.value.tags, {}))

  dynamic "attachments_source" {
    for_each = try(each.value.attachments_source, [])
    content {
      key    = attachments_source.value.key
      name   = try(attachments_source.value.name, null)
      values = attachments_source.value.values
    }
  }
}
