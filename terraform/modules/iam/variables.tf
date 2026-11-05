variable "name" {
  type = string
}
variable "log_bucket" {
  type = string
}
variable "data_bucket" {
  type = string
}
variable "secret_arn" {
  type = string
}
variable "tags" {
  type    = map(string)
  default = {}
}

output "role_name" {
  value = aws_iam_role.app.name
}
output "role_arn" {
  value = aws_iam_role.app.arn
}
output "instance_profile_name" {
  value = aws_iam_instance_profile.app.name
}
output "instance_profile_arn" {
  value = aws_iam_instance_profile.app.arn
}
