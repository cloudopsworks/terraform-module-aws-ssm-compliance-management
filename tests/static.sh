#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

tofu fmt -check -recursive
tofu init -backend=false -input=false >/dev/null
tofu validate
tofu test

required_setting_ids=(
  "/ssm/managed-instance/default-ec2-instance-management-role"
  "/ssm/automation/customer-script-log-destination"
  "/ssm/automation/customer-script-log-group-name"
  "/ssm/documents/console/public-sharing-permission"
)

for setting_id in "${required_setting_ids[@]}"; do
  grep -R --fixed-strings --quiet "$setting_id" -- ./*.tf
done

required_resources=(
  'resource "aws_ssm_association"'
  'resource "aws_ssm_document"'
  'resource "aws_ssm_patch_baseline"'
  'resource "aws_ssm_patch_group"'
  'resource "aws_ssm_maintenance_window"'
  'resource "aws_ssm_maintenance_window_target"'
  'resource "aws_ssm_maintenance_window_task"'
)

for resource in "${required_resources[@]}"; do
  grep -R --fixed-strings --quiet "$resource" -- ./*.tf
done

documented_settings=(
  "default_host_management"
  "automation_logging"
  "document_security"
  "inventory"
  "resource_data_sync"
  "patch_scan"
  "documents"
  "attachments_source"
  "associations"
  "output_location"
  "patch_baselines"
  "approval_rules"
  "global_filters"
  "sources"
  "patch_groups"
  "maintenance"
  "maintenance_windows"
  "cloudwatch_output_enabled"
  "notification_config"
)

for setting in "${documented_settings[@]}"; do
  grep --fixed-strings --quiet "$setting" .boilerplate/inputs.yaml
  grep --fixed-strings --quiet "$setting" README.yaml
done

for forbidden in \
  'SSM-SessionManagerRunShell' \
  'AWS-StartSSHSession' \
  'aws_ssmguiconnect' \
  'AWSQuickSetupType-JITNA'; do
  if grep -R --fixed-strings --quiet "$forbidden" -- ./*.tf; then
    echo "Session-management resource marker found in Terraform: $forbidden" >&2
    exit 1
  fi
done

echo "Static SSM compliance module checks passed."
