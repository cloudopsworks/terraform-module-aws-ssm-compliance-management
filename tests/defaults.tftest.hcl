mock_provider "aws" {
  mock_data "aws_region" {
    defaults = {
      region = "us-east-1"
    }
  }

  mock_data "aws_partition" {
    defaults = {
      partition = "aws"
    }
  }

  mock_resource "aws_iam_role" {
    defaults = {
      arn = "arn:aws:iam::123456789012:role/mock-ssm-role"
    }
  }
}

variables {
  org = {
    organization_name = "example"
    organization_unit = "platform"
    environment_type  = "production"
    environment_name  = "shared"
  }
}

run "safe_defaults" {
  command = plan

  assert {
    condition     = length(aws_ssm_service_setting.default_host_management) == 1
    error_message = "Default Host Management must be enabled by default."
  }

  assert {
    condition     = length(aws_ssm_association.inventory) == 1
    error_message = "Inventory collection must be enabled by default."
  }

  assert {
    condition     = length(aws_ssm_association.patch_scan) == 1
    error_message = "Patch compliance scanning must be enabled by default."
  }

  assert {
    condition     = aws_ssm_association.patch_scan[0].parameters["Operation"] == "Scan"
    error_message = "The default patch operation must not install or reboot."
  }

  assert {
    condition     = length(aws_ssm_service_setting.automation_log_destination) == 1
    error_message = "Automation logging must be enabled by default."
  }

  assert {
    condition     = length(aws_ssm_service_setting.block_public_document_sharing) == 1
    error_message = "Public SSM document sharing must be blocked by default."
  }

  assert {
    condition     = length(aws_ssm_maintenance_window.this) == 0
    error_message = "Maintenance Windows must remain opt-in."
  }
}

run "complete_patching" {
  command = plan

  variables {
    settings = {
      patch_baselines = {
        linux = {
          operating_system = "AMAZON_LINUX_2"
          approval_rules = [{
            approve_after_days = 7
            patch_filters = [{
              key    = "CLASSIFICATION"
              values = ["Security"]
            }]
          }]
        }
      }

      patch_groups = {
        linux = {
          patch_group  = "linux"
          baseline_key = "linux"
        }
      }

      maintenance_windows = {
        monthly = {
          schedule = "cron(0 3 ? * SUN#1 *)"
          targets = {
            linux = {
              targets = [{
                key    = "tag:Patch Group"
                values = ["linux"]
              }]
            }
          }
          tasks = {
            install = {
              target_keys = ["linux"]
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

  assert {
    condition     = length(aws_ssm_patch_baseline.this) == 1
    error_message = "A configured patch baseline must be planned."
  }

  assert {
    condition     = length(aws_ssm_patch_group.this) == 1
    error_message = "A configured patch group must be planned."
  }

  assert {
    condition     = length(aws_ssm_maintenance_window.this) == 1
    error_message = "A configured Maintenance Window must be planned."
  }

  assert {
    condition     = length(aws_ssm_maintenance_window_task.this) == 1
    error_message = "A configured Maintenance Window task must be planned."
  }
}

run "reject_public_document_share" {
  command = plan

  variables {
    settings = {
      documents = {
        public = {
          content            = "{}"
          shared_account_ids = ["All"]
        }
      }
    }
  }

  expect_failures = [var.settings]
}

run "reject_unknown_window_target" {
  command = plan

  variables {
    settings = {
      maintenance_windows = {
        invalid = {
          schedule = "rate(1 day)"
          tasks = {
            scan = {
              target_keys = ["missing"]
            }
          }
        }
      }
    }
  }

  expect_failures = [var.settings]
}

run "reject_sync_without_bucket" {
  command = plan

  variables {
    settings = {
      inventory = {
        resource_data_sync = {
          enabled = true
        }
      }
    }
  }

  expect_failures = [var.settings]
}
