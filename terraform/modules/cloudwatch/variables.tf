variable "name" {
  type = string
}
variable "asg_name" {
  type = string
}
variable "alb_arn_suffix" {
  type = string
}
variable "target_group_arn" {
  type = string
}
variable "sns_topic_arn" {
  type = string
}
variable "retention_days" {
  type    = number
  default = 14
}
variable "tags" {
  type    = map(string)
  default = {}
}

output "dashboard_url" {
  value = "https://console.aws.amazon.com/cloudwatch/home#dashboards:name=${aws_cloudwatch_dashboard.this.dashboard_name}"
}
output "log_group_app" {
  value = aws_cloudwatch_log_group.app.name
}
output "log_group_userdata" {
  value = aws_cloudwatch_log_group.userdata.name
}
