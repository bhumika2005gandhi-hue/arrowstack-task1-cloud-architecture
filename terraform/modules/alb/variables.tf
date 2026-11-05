variable "name" {
  type = string
}
variable "vpc_id" {
  type = string
}
variable "public_subnets" {
  type = list(string)
}
variable "app_port" {
  type = number
}
variable "allowed_ingress" {
  type = list(string)
}
variable "health_check_path" {
  type    = string
  default = "/health"
}
variable "health_check_port" {
  type = number
}
variable "access_log_bucket" {
  type    = string
  default = ""
}
variable "tags" {
  type    = map(string)
  default = {}
}

output "alb_id" {
  value = aws_lb.this.id
}
output "alb_arn" {
  value = aws_lb.this.arn
}
output "alb_arn_suffix" {
  value = aws_lb.this.arn_suffix
}
output "alb_dns_name" {
  value = aws_lb.this.dns_name
}
output "zone_id" {
  value = aws_lb.this.zone_id
}
output "target_group_arn" {
  value = aws_lb_target_group.app.arn
}
output "security_group_id" {
  value = aws_security_group.alb.id
}
output "http_listener_arn" {
  value = aws_lb_listener.http.arn
}
