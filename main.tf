#
#
# Update Window
#
#
resource "aws_ssm_maintenance_window" "default" {
  count    = "${var.weeks}"
  name     = "${var.weeks > 1 ? "${var.type}_linux_week-${count.index+1}_${var.day}_${var.hour}00" : "${var.type}_linux_week-${var.week}_${var.day}_${var.hour}00"}"
  schedule = "${var.weeks > 1 ? "cron(00 ${var.hour} ? 1/3 ${var.day}#${count.index+1} *)" : "cron(00 ${var.hour} ? 1/3 ${var.day}#${var.week} *)"}"
  duration = "${var.mw_duration}"
  cutoff   = "${var.mw_cutoff}"
  schedule_timezone = "Europe/London"
}

resource "aws_ssm_maintenance_window_target" "default" {
  count         = "${var.weeks}"
  window_id     = "${element(aws_ssm_maintenance_window.default.*.id, count.index)}"
  name = "default"
  description = "default"
  resource_type = "INSTANCE"
  
  targets {
    key    = "tag:ssmMaintenanceWindow"
    values = ["${var.weeks > 1 ? "${var.type}_linux_week-${count.index+1}_${var.day}_${var.hour}00" : "${var.type}_linux_week-${var.week}_${var.day}_${var.hour}00"}"]
  }
}

resource "aws_ssm_maintenance_window_task" "default_task_create_image" {
  count            = "${var.weeks}"
  window_id        = "${element(aws_ssm_maintenance_window.default.*.id, count.index)}"
  name             = "create_ami_backup"
  description      = "Take AMI of instance"
  task_type        = "AUTOMATION"
  task_arn         = "AWS-CreateImage"
  priority         = 10
  service_role_arn = "${var.role}"
  max_concurrency  = "${var.mw_concurrency}"
  max_errors       = "${var.mw_error_rate}"

  task_invocation_parameters {
    automation_parameters {
      document_version = "$LATEST"

      parameter {
        name   = "InstanceId"
        values = ["{{TARGET_ID}}"]
      }
      parameter {
        name   = "NoReboot"
        values = ["false"]
      }
      parameter {
        name   = "AutomationAssumeRole"
        values = ["${var.ssm_maintenance_window_create_image_role}"]
      }
    }
  }

  targets {
    key    = "WindowTargetIds"
    values = ["${element(aws_ssm_maintenance_window_target.default.*.id, count.index)}"]
  }
}

resource "aws_ssm_maintenance_window_task" "default_task_ena_update" {
  count            = "${var.weeks}"
  window_id        = "${element(aws_ssm_maintenance_window.default.*.id, count.index)}"
  name             = "update_aws_ena"
  description      = "Installs AwsEnaNetworkDriver for snapshotting"
  task_type        = "RUN_COMMAND"
  task_arn         = "AWS-ConfigureAWSPackage"
  priority         = 20
  service_role_arn = "${var.role}"
  max_concurrency  = "${var.mw_concurrency}"
  max_errors       = "${var.mw_error_rate}"

  targets {
    key    = "WindowTargetIds"
    values = ["${element(aws_ssm_maintenance_window_target.default.*.id, count.index)}"]
  }

  task_invocation_parameters {
    run_command_parameters {
      output_s3_bucket = "${var.s3_bucket}"
      output_s3_key_prefix = "${var.weeks > 1 ? "${var.type}_week-${count.index+1}_${var.day}_${var.hour}00/${var.account}-${var.environment}" : "${var.type}_week-${var.week}_${var.day}_${var.hour}00/${var.account}-${var.environment}" }"
      service_role_arn = "${var.role}"
      timeout_seconds  = 300

      parameter {
        name   = "action"
        values = ["Install"]
      }
      parameter {
        name   = "name"
        values = ["AwsEnaNetworkDriver"]
      }
    }
  }
}

resource "aws_ssm_maintenance_window_task" "default_task_pvdriver_update" {
  count            = "${var.weeks}"
  window_id        = "${element(aws_ssm_maintenance_window.default.*.id, count.index)}"
  name             = "update_aws_pvdriver"
  description      = "Installs AWSPVDriver for snapshotting"
  task_type        = "RUN_COMMAND"
  task_arn         = "AWS-ConfigureAWSPackage"
  priority         = 30
  service_role_arn = "${var.role}"
  max_concurrency  = "${var.mw_concurrency}"
  max_errors       = "${var.mw_error_rate}"

  targets {
    key    = "WindowTargetIds"
    values = ["${element(aws_ssm_maintenance_window_target.default.*.id, count.index)}"]
  }

  task_invocation_parameters {
    run_command_parameters {
      output_s3_bucket = "${var.s3_bucket}"
      output_s3_key_prefix = "${var.weeks > 1 ? "${var.type}_week-${count.index+1}_${var.day}_${var.hour}00/${var.account}-${var.environment}" : "${var.type}_week-${var.week}_${var.day}_${var.hour}00/${var.account}-${var.environment}" }"
      service_role_arn = "${var.role}"
      timeout_seconds  = 300

      parameter {
        name   = "action"
        values = ["Install"]
      }
      parameter {
        name   = "name"
        values = ["AWSPVDriver"]
      }
    }
  }
}

resource "aws_ssm_maintenance_window_task" "default_task_updates" {
  count            = "${var.weeks}"
  window_id        = "${element(aws_ssm_maintenance_window.default.*.id, count.index)}"
  name             = "install_yum_updates"
  description      = "Install YUM Updates"
  task_type        = "RUN_COMMAND"
  task_arn         = "AWS-RunShellScript"
  priority         = 40
  service_role_arn = "${var.role}"
  max_concurrency  = "${var.mw_concurrency}"
  max_errors       = "${var.mw_error_rate}"

  targets {
    key    = "WindowTargetIds"
    values = ["${element(aws_ssm_maintenance_window_target.default.*.id, count.index)}"]
  }

  task_invocation_parameters {
    run_command_parameters {
      output_s3_bucket = "${var.s3_bucket}"
      output_s3_key_prefix = "${var.weeks > 1 ? "${var.type}_week-${count.index+1}_${var.day}_${var.hour}00/${var.account}-${var.environment}" : "${var.type}_week-${var.week}_${var.day}_${var.hour}00/${var.account}-${var.environment}" }"
      service_role_arn = "${var.role}"
      timeout_seconds  = 10800

      parameter {
        name   = "commands"
        values = ["sudo yum update-minimal --security -y --exclude=kernel*,mongo*,elastic*,samba*"]
      }
    }
  }
}


resource "aws_ssm_maintenance_window_task" "default_task_email_notification" {
  count            = "${var.weeks}"
  window_id        = "${element(aws_ssm_maintenance_window.default.*.id, count.index)}"
  name             = "ssm_email_notification"
  description      = "Send email notification"
  task_type        = "RUN_COMMAND"
  task_arn         = "AWL-SSMEmailNotification"
  priority         = 50
  service_role_arn = "${var.role}"
  max_concurrency  = "${var.mw_concurrency}"
  max_errors       = "${var.mw_error_rate}"

  targets {
    key    = "WindowTargetIds"
    values = ["${element(aws_ssm_maintenance_window_target.default.*.id, count.index)}"]
  }

  task_invocation_parameters {
    run_command_parameters {
      output_s3_bucket = "${var.s3_bucket}"
      output_s3_key_prefix = "${var.weeks > 1 ? "${var.type}_week-${count.index+1}_${var.day}_${var.hour}00/${var.account}-${var.environment}" : "${var.type}_week-${var.week}_${var.day}_${var.hour}00/${var.account}-${var.environment}" }"
      service_role_arn = "${var.role}"
      timeout_seconds  = 300
    }
  }
}

resource "aws_ssm_maintenance_window_task" "default_task_ssmagent" {
  count            = "${var.weeks}"
  window_id        = "${element(aws_ssm_maintenance_window.default.*.id, count.index)}"
  name             = "update_ssm_agent"
  description      = "Update SSM Agent"
  task_type        = "RUN_COMMAND"
  task_arn         = "AWS-UpdateSSMAgent"
  priority         = 60
  service_role_arn = "${var.role}"
  max_concurrency  = "${var.mw_concurrency}"
  max_errors       = "${var.mw_error_rate}"

  targets {
    key    = "WindowTargetIds"
    values = ["${element(aws_ssm_maintenance_window_target.default.*.id, count.index)}"]
  }

  task_invocation_parameters {
    run_command_parameters {
      output_s3_bucket = "${var.s3_bucket}"
      output_s3_key_prefix = "${var.weeks > 1 ? "${var.type}_week-${count.index+1}_${var.day}_${var.hour}00/${var.account}-${var.environment}" : "${var.type}_week-${var.week}_${var.day}_${var.hour}00/${var.account}-${var.environment}" }"
      service_role_arn = "${var.role}"
      timeout_seconds  = 300

      parameter {
        name   = "allowDowngrade"
        values = ["false"]
      }
    }
  }
}
