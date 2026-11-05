###############################################################################
# Root composition — wires all modules together
###############################################################################
locals {
  full_name = "${var.project_name}-${var.environment}"
  common_tags = {
    Project     = "Arrowstack-Task1-CloudArchitecture"
    Environment = var.environment
    ManagedBy   = "Terraform"
    Owner       = var.owner_email
  }

  # Single AZ-pair derived from var.availability_zones; safe slicing
  azs       = slice(var.availability_zones, 0, min(2, length(var.availability_zones)))
  public_a  = cidrsubnet(var.vpc_cidr, 8, 0)  # 10.20.0.0/24
  public_b  = cidrsubnet(var.vpc_cidr, 8, 1)  # 10.20.1.0/24
  private_a = cidrsubnet(var.vpc_cidr, 8, 10) # 10.20.10.0/24
  private_b = cidrsubnet(var.vpc_cidr, 8, 11) # 10.20.11.0/24
  db_a      = cidrsubnet(var.vpc_cidr, 8, 20) # 10.20.20.0/24
  db_b      = cidrsubnet(var.vpc_cidr, 8, 21) # 10.20.21.0/24
}

# Random suffix to keep S3 bucket / DB password unique
resource "random_id" "suffix" {
  byte_length = 4
}

# ----------------------------------------------------------------------------
# Networking
# ----------------------------------------------------------------------------
module "vpc" {
  source = "./modules/vpc"

  name                  = local.full_name
  vpc_cidr              = var.vpc_cidr
  azs                   = local.azs
  public_subnet_cidrs   = [local.public_a, local.public_b]
  private_subnet_cidrs  = [local.private_a, local.private_b]
  database_subnet_cidrs = [local.db_a, local.db_b]
  enable_nat_gateway    = true
  single_nat_gateway    = true # cost-friendly for dev; set false for prod HA
  tags                  = local.common_tags
}

# ----------------------------------------------------------------------------
# S3 — access logs, app logs, backups
# ----------------------------------------------------------------------------
module "s3" {
  source = "./modules/s3"

  bucket_name     = "${local.full_name}-data-${random_id.suffix.hex}"
  log_bucket_name = "${local.full_name}-accesslogs-${random_id.suffix.hex}"
  force_destroy   = var.environment != "prod"
  retention_days  = var.log_retention_days
  tags            = local.common_tags
}

# ----------------------------------------------------------------------------
# IAM — least-privilege instance profile for the app EC2 fleet
# ----------------------------------------------------------------------------
module "iam" {
  source = "./modules/iam"

  name        = local.full_name
  log_bucket  = module.s3.logs_bucket_id
  data_bucket = module.s3.data_bucket_id
  secret_arn  = module.rds.secret_arn
  tags        = local.common_tags
}

# ----------------------------------------------------------------------------
# Application Load Balancer (public subnets, HTTPS listener optional)
# ----------------------------------------------------------------------------
module "alb" {
  source = "./modules/alb"

  name              = local.full_name
  vpc_id            = module.vpc.vpc_id
  public_subnets    = module.vpc.public_subnet_ids
  app_port          = var.app_port
  allowed_ingress   = var.allowed_ingress_cidrs
  health_check_path = "/health"
  health_check_port = var.app_port
  access_log_bucket = module.s3.logs_bucket_id
  tags              = local.common_tags
}

# ----------------------------------------------------------------------------
# RDS — managed Postgres in DB subnets with secrets from Secrets Manager
# ----------------------------------------------------------------------------
module "rds" {
  source = "./modules/rds"

  name                 = local.full_name
  vpc_id               = module.vpc.vpc_id
  db_subnet_group_name = module.vpc.database_subnet_group_name
  allowed_cidrs        = [local.private_a, local.private_b]
  instance_class       = var.db_instance_class
  engine               = var.db_engine
  engine_version       = var.db_engine_version
  allocated_storage    = var.db_allocated_storage
  db_name              = var.db_name
  multi_az             = var.environment == "prod"
  backup_retention     = var.environment == "prod" ? 7 : 1
  tags                 = local.common_tags
}

# ----------------------------------------------------------------------------
# Auto Scaling Group — app tier in private subnets, behind the ALB
# ----------------------------------------------------------------------------
module "asg" {
  source = "./modules/asg"

  name                               = local.full_name
  vpc_id                             = module.vpc.vpc_id
  private_subnets                    = module.vpc.private_subnet_ids
  instance_type                      = var.instance_type
  ami_id                             = data.aws_ami.amazon_linux_2023.id
  app_port                           = var.app_port
  iam_instance_profile               = module.iam.instance_profile_name
  target_group_arn                   = module.alb.target_group_arn
  alb_sg_id                          = module.alb.security_group_id
  alb_arn_suffix_for_metric          = module.alb.alb_arn_suffix
  target_group_arn_suffix_for_metric = "targetgroup/${split("/", module.alb.target_group_arn)[-2]}/${split("/", module.alb.target_group_arn)[-1]}"
  min_size                           = var.asg_min_size
  max_size                           = var.asg_max_size
  desired_capacity                   = var.asg_desired_capacity
  db_secret_arn                      = module.rds.secret_arn
  db_endpoint                        = module.rds.endpoint
  db_name                            = var.db_name
  log_bucket                         = module.s3.logs_bucket_id
  ssh_key_name                       = var.ssh_key_name
  enable_bastion                     = var.enable_bastion
  public_subnets                     = module.vpc.public_subnet_ids
  allowed_bastion_cidr               = var.allowed_ingress_cidrs
  tags                               = local.common_tags
}

# Latest Amazon Linux 2023 AMI — pinned by owner + name pattern for reproducibility
data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }
}

# ----------------------------------------------------------------------------
# CloudWatch — dashboard + alarms for the app tier
# ----------------------------------------------------------------------------
module "cloudwatch" {
  source = "./modules/cloudwatch"

  name             = local.full_name
  asg_name         = module.asg.asg_name
  alb_arn_suffix   = module.alb.alb_arn_suffix
  target_group_arn = module.alb.target_group_arn
  sns_topic_arn    = aws_sns_topic.alerts.arn
  retention_days   = var.log_retention_days
  tags             = local.common_tags
}

resource "aws_sns_topic" "alerts" {
  name = "${local.full_name}-alerts"
  tags = local.common_tags
}

resource "aws_sns_topic_subscription" "email" {
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.owner_email
}
