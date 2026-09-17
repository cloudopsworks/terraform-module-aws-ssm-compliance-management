##
# (c) 2021-2026
#     Cloud Ops Works LLC - https://cloudops.works/
#     Find us on:
#       GitHub: https://github.com/cloudopsworks
#       WebSite: https://cloudops.works
#     Distributed Under Apache v2.0 License
#

terraform {
  required_version = ">= 1.5"
}

variable "existing_inventory_association_id" {
  description = "Association ID of the existing AWS-GatherSoftwareInventory association"
  type        = string
}

module "ssm_compliance" {
  source = "../../"

  org = {
    organization_name = "example"
    organization_unit = "platform"
    environment_type  = "production"
    environment_name  = "shared"
  }

  settings = {
    inventory = {
      enabled = true

      # Match these values to the existing association before applying.
      schedule = "rate(1 day)"
      targets = [{
        key    = "InstanceIds"
        values = ["*"]
      }]
    }
  }
}

import {
  to = module.ssm_compliance.aws_ssm_association.inventory[0]
  id = var.existing_inventory_association_id
}
