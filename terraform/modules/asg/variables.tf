variable "name" {
  type = string
}
variable "vpc_id" {
  type = string
}
variable "private_subnets" {
  type = list(string)
}
variable "instance_type" {
  type = string
}
variable "ami_id" {
  type = string
}
variable "app_port" {
  type = number
}
variable "iam_instance_profile" {
  type = string
}
variable "target_group_arn" {
  type = string
}
variable "alb_sg_id" {
  type = string
}
variable "alb_arn_suffix_for_metric" {
  type = string
}
variable "target_group_arn_suffix_for_metric" {
  type = string
}
variable "min_size" {
  type = number
}
variable "max_size" {
  type = number
}
variable "desired_capacity" {
  type = number
}
variable "db_secret_arn" {
  type = string
}
variable "db_endpoint" {
  type = string
}
variable "db_name" {
  type = string
}
variable "log_bucket" {
  type = string
}
variable "ssh_key_name" {
  type = string
}
variable "enable_bastion" {
  type = bool
}
variable "public_subnets" {
  type = list(string)
}
variable "allowed_bastion_cidr" {
  type = list(string)
}
variable "tags" {
  type    = map(string)
  default = {}
}

output "asg_name" {
  value = aws_autoscaling_group.app.name
}
output "asg_arn" {
  value = aws_autoscaling_group.app.arn
}
output "launch_template_id" {
  value = aws_launch_template.app.id
}
output "app_security_group_id" {
  value = aws_security_group.app.id
}
output "bastion_public_ip" {
  value = var.enable_bastion ? aws_instance.bastion[0].public_ip : ""
}
