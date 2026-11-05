variable "name" {
  type = string
}
variable "vpc_id" {
  type = string
}
variable "db_subnet_group_name" {
  type = string
}
variable "allowed_cidrs" {
  type = list(string)
}
variable "instance_class" {
  type = string
}
variable "engine" {
  type = string
}
variable "engine_version" {
  type = string
}
variable "allocated_storage" {
  type = number
}
variable "db_name" {
  type = string
}
variable "multi_az" {
  type    = bool
  default = false
}
variable "backup_retention" {
  type    = number
  default = 1
}
variable "tags" {
  type    = map(string)
  default = {}
}

output "endpoint" {
  value = aws_db_instance.this.address
}
output "db_id" {
  value = aws_db_instance.this.id
}
output "db_arn" {
  value = aws_db_instance.this.arn
}
output "secret_arn" {
  value = aws_secretsmanager_secret.master.arn
}
output "secret_name" {
  value = aws_secretsmanager_secret.master.name
}
output "security_group_id" {
  value = aws_security_group.db.id
}
output "kms_key_arn" {
  value = aws_kms_key.this.arn
}
