## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.3 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | ~> 6.35 |

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_aws"></a> [aws](#provider\_aws) | ~> 6.35 |

## Modules

| Name | Source | Version |
| ---- | ------ | ------- |
| <a name="module_tags"></a> [tags](#module\_tags) | cloudopsworks/tags/local | 1.0.10 |

## Resources

| Name | Type |
| ---- | ---- |
| [aws_cloudwatch_log_group.automation](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_iam_role.default_host_management](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.maintenance](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy_attachment.default_host_management](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.default_host_management_additional](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.maintenance](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.maintenance_additional](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_ssm_association.inventory](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ssm_association) | resource |
| [aws_ssm_association.patch_scan](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ssm_association) | resource |
| [aws_ssm_association.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ssm_association) | resource |
| [aws_ssm_document.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ssm_document) | resource |
| [aws_ssm_maintenance_window.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ssm_maintenance_window) | resource |
| [aws_ssm_maintenance_window_target.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ssm_maintenance_window_target) | resource |
| [aws_ssm_maintenance_window_task.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ssm_maintenance_window_task) | resource |
| [aws_ssm_patch_baseline.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ssm_patch_baseline) | resource |
| [aws_ssm_patch_group.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ssm_patch_group) | resource |
| [aws_ssm_resource_data_sync.inventory](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ssm_resource_data_sync) | resource |
| [aws_ssm_service_setting.automation_log_destination](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ssm_service_setting) | resource |
| [aws_ssm_service_setting.automation_log_group](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ssm_service_setting) | resource |
| [aws_ssm_service_setting.block_public_document_sharing](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ssm_service_setting) | resource |
| [aws_ssm_service_setting.default_host_management](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ssm_service_setting) | resource |
| [aws_partition.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/partition) | data source |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_extra_tags"></a> [extra\_tags](#input\_extra\_tags) | Extra tags to add to the resources | `map(string)` | `{}` | no |
| <a name="input_is_hub"></a> [is\_hub](#input\_is\_hub) | Is this a hub or spoke configuration? | `bool` | `false` | no |
| <a name="input_org"></a> [org](#input\_org) | Organization details | <pre>object({<br/>    organization_name = string<br/>    organization_unit = string<br/>    environment_type  = string<br/>    environment_name  = string<br/>  })</pre> | n/a | yes |
| <a name="input_settings"></a> [settings](#input\_settings) | AWS Systems Manager account and Region configuration for Security Hub CSPM controls SSM.1 through SSM.7; Session Manager resources are intentionally excluded | `any` | `{}` | no |
| <a name="input_spoke_def"></a> [spoke\_def](#input\_spoke\_def) | Spoke ID Number, must be a 3 digit number | `string` | `"001"` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_association_ids"></a> [association\_ids](#output\_association\_ids) | IDs of custom State Manager associations keyed by settings.associations key |
| <a name="output_automation_log_group_name"></a> [automation\_log\_group\_name](#output\_automation\_log\_group\_name) | CloudWatch Logs group configured for Systems Manager Automation customer-script logging |
| <a name="output_default_host_management_role_arn"></a> [default\_host\_management\_role\_arn](#output\_default\_host\_management\_role\_arn) | ARN of the module-created Default Host Management Configuration IAM role, or null when an existing role is used |
| <a name="output_document_arns"></a> [document\_arns](#output\_document\_arns) | ARNs of customer-owned, tagged Systems Manager documents keyed by settings.documents key |
| <a name="output_inventory_association_id"></a> [inventory\_association\_id](#output\_inventory\_association\_id) | ID of the AWS-GatherSoftwareInventory State Manager association |
| <a name="output_inventory_resource_data_sync_name"></a> [inventory\_resource\_data\_sync\_name](#output\_inventory\_resource\_data\_sync\_name) | Name of the optional Systems Manager Inventory resource data sync |
| <a name="output_maintenance_window_ids"></a> [maintenance\_window\_ids](#output\_maintenance\_window\_ids) | IDs of maintenance windows keyed by settings.maintenance\_windows key |
| <a name="output_maintenance_window_target_ids"></a> [maintenance\_window\_target\_ids](#output\_maintenance\_window\_target\_ids) | IDs of maintenance window targets keyed as window.target |
| <a name="output_maintenance_window_task_ids"></a> [maintenance\_window\_task\_ids](#output\_maintenance\_window\_task\_ids) | IDs of maintenance window tasks keyed as window.task |
| <a name="output_patch_baseline_ids"></a> [patch\_baseline\_ids](#output\_patch\_baseline\_ids) | IDs of custom patch baselines keyed by settings.patch\_baselines key |
| <a name="output_patch_scan_association_id"></a> [patch\_scan\_association\_id](#output\_patch\_scan\_association\_id) | ID of the non-rebooting AWS-RunPatchBaseline Scan association |
| <a name="output_security_hub_ssm_controls"></a> [security\_hub\_ssm\_controls](#output\_security\_hub\_ssm\_controls) | Module configuration status and Terraform resources supporting Security Hub CSPM controls SSM.1 through SSM.7 |
