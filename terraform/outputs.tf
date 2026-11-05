###############################################################################
# Outputs
###############################################################################
output "alb_dns_name" {
  description = "Public DNS name of the Application Load Balancer — visit http(s)://<this>/health"
  value       = module.alb.alb_dns_name
}

output "alb_zone_id" {
  description = "Route53 zone id for the ALB (use to alias a custom domain)."
  value       = module.alb.zone_id
}

output "vpc_id" {
  description = "ID of the VPC created for the multi-tier stack."
  value       = module.vpc.vpc_id
}

output "public_subnet_ids" {
  description = "Public subnets hosting the ALB and (optional) bastion."
  value       = module.vpc.public_subnet_ids
}

output "private_subnet_ids" {
  description = "Private subnets hosting the app tier EC2 fleet."
  value       = module.vpc.private_subnet_ids
}

output "database_subnet_ids" {
  description = "Isolated database subnets hosting RDS."
  value       = module.vpc.database_subnet_ids
}

output "rds_endpoint" {
  description = "RDS writer endpoint — pass to the app via SSM user-data."
  value       = module.rds.endpoint
  sensitive   = true
}

output "db_secret_arn" {
  description = "Secrets Manager ARN holding the DB master credentials."
  value       = module.rds.secret_arn
  sensitive   = true
}

output "asg_name" {
  description = "Name of the Auto Scaling Group managing the app fleet."
  value       = module.asg.asg_name
}

output "data_bucket" {
  description = "S3 bucket for app data, backups and exports."
  value       = module.s3.data_bucket_id
}

output "logs_bucket" {
  description = "S3 bucket for ALB & EC2 access logs."
  value       = module.s3.logs_bucket_id
}

output "sns_alerts_topic" {
  description = "SNS topic receiving CloudWatch alarm notifications."
  value       = aws_sns_topic.alerts.arn
}

output "bastion_public_ip" {
  description = "Public IP of the bastion host (empty if disabled)."
  value       = module.asg.bastion_public_ip
}
