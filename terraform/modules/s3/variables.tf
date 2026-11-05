variable "bucket_name" {
  type = string
}
variable "log_bucket_name" {
  type = string
}
variable "force_destroy" {
  type    = bool
  default = false
}
variable "retention_days" {
  type    = number
  default = 14
}
variable "tags" {
  type    = map(string)
  default = {}
}

output "data_bucket_id" {
  value = aws_s3_bucket.data.id
}
output "data_bucket_arn" {
  value = aws_s3_bucket.data.arn
}
output "logs_bucket_id" {
  value = aws_s3_bucket.logs.id
}
output "logs_bucket_arn" {
  value = aws_s3_bucket.logs.arn
}
output "kms_key_arn" {
  value = aws_kms_key.this.arn
}
