##
# (c) 2021-2026
#     Cloud Ops Works LLC - https://cloudops.works/
#     Find us on:
#       GitHub: https://github.com/cloudopsworks
#       WebSite: https://cloudops.works
#     Distributed Under Apache v2.0 License
#

terraform {
  required_version = ">= 1.3"
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
      targets = [{
        key    = "tag:SSMManaged"
        values = ["true"]
      }]
    }

    patch_scan = {
      targets = [{
        key    = "tag:Patch Group"
        values = ["amazon-linux"]
      }]
    }

    patch_baselines = {
      amazon_linux = {
        operating_system = "AMAZON_LINUX_2"
        approval_rules = [{
          approve_after_days = 7
          compliance_level   = "HIGH"
          patch_filters = [{
            key    = "CLASSIFICATION"
            values = ["Security"]
          }]
        }]
      }
    }

    patch_groups = {
      amazon_linux = {
        patch_group  = "amazon-linux"
        baseline_key = "amazon_linux"
      }
    }

    maintenance_windows = {
      monthly = {
        name              = "example-monthly-patching"
        schedule          = "cron(0 3 ? * SUN#1 *)"
        schedule_timezone = "UTC"
        duration          = 4
        cutoff            = 1

        targets = {
          amazon_linux = {
            targets = [{
              key    = "tag:Patch Group"
              values = ["amazon-linux"]
            }]
          }
        }

        tasks = {
          install = {
            task_arn    = "AWS-RunPatchBaseline"
            target_keys = ["amazon_linux"]
            parameters = {
              Operation    = ["Install"]
              RebootOption = ["RebootIfNeeded"]
            }
          }
        }
      }
    }
  }
}
