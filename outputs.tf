output "instance_id" {
  description = "ID of the monitored EC2 instance"
  value       = aws_instance.monitored.id
}

output "instance_public_ip" {
  description = "Public IP of the monitored EC2 instance"
  value       = aws_instance.monitored.public_ip
}

output "dashboard_url" {
  description = "CloudWatch Dashboard URL"
  value       = "https://console.aws.amazon.com/cloudwatch/home?region=${var.aws_region}#dashboards:name=${aws_cloudwatch_dashboard.main.dashboard_name}"
}

output "sns_topic_arn" {
  description = "SNS Topic ARN for alarms"
  value       = aws_sns_topic.alarms.arn
}

output "lambda_function_name" {
  description = "Lambda function name for remediation"
  value       = aws_lambda_function.remediation.function_name
}

output "cloudwatch_log_group" {
  description = "CloudWatch Log Group name"
  value       = aws_cloudwatch_log_group.ec2_logs.name
}

output "alarm_names" {
  description = "CloudWatch Alarm names"
  value = {
    cpu_high           = aws_cloudwatch_metric_alarm.cpu_high.alarm_name
    memory_high        = aws_cloudwatch_metric_alarm.memory_high.alarm_name
    disk_high          = aws_cloudwatch_metric_alarm.disk_high.alarm_name
    status_check_failed = aws_cloudwatch_metric_alarm.status_check_failed.alarm_name
  }
}
