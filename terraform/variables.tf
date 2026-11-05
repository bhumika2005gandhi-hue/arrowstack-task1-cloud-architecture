###############################################################################
# Global Variables — Arrowstack Task 1 (Multi-Tier Cloud Architecture)
###############################################################################
variable "aws_region" {
  description = "AWS region for all resources."
  type        = string
  default     = "ap-south-1"
}

variable "environment" {
  description = "Deployment environment name (dev/stage/prod)."
  type        = string
  default     = "dev"
}

variable "project_name" {
  description = "Short project prefix used for naming resources."
  type        = string
  default     = "arrowstack-t1"
}

variable "owner_email" {
  description = "Owner email for cost allocation tags."
  type        = string
  default     = "bhumika2005gandhi@gmail.com"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC."
  type        = string
  default     = "10.20.0.0/16"
}

variable "availability_zones" {
  description = "AZs to spread multi-tier resources across (min 2 for HA)."
  type        = list(string)
  default     = ["ap-south-1a", "ap-south-1b"]
}

variable "app_port" {
  description = "Port the sample Node.js app listens on inside EC2."
  type        = number
  default     = 3000
}

variable "instance_type" {
  description = "EC2 instance type for the app tier (free-tier friendly)."
  type        = string
  default     = "t3.micro"
}

variable "asg_min_size" {
  description = "Minimum number of instances in the ASG."
  type        = number
  default     = 2
}

variable "asg_max_size" {
  description = "Maximum number of instances in the ASG."
  type        = number
  default     = 4
}

variable "asg_desired_capacity" {
  description = "Desired number of instances in the ASG at steady state."
  type        = number
  default     = 2
}

variable "db_instance_class" {
  description = "RDS instance class (free-tier friendly)."
  type        = string
  default     = "db.t3.micro"
}

variable "db_engine" {
  description = "RDS engine."
  type        = string
  default     = "postgres"
}

variable "db_engine_version" {
  description = "RDS engine version."
  type        = string
  default     = "15.5"
}

variable "db_allocated_storage" {
  description = "Allocated storage in GB for the RDS instance."
  type        = number
  default     = 20
}

variable "db_name" {
  description = "Initial database name on the RDS instance."
  type        = string
  default     = "appdb"
}

variable "enable_bastion" {
  description = "Whether to provision a bastion host for SSH access to private subnets."
  type        = bool
  default     = true
}

variable "allowed_ingress_cidrs" {
  description = "CIDR blocks allowed to reach the ALB on 443/80. Tighten for prod."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "ssh_key_name" {
  description = "Name of an existing EC2 key pair for SSH access (bastion + instances)."
  type        = string
  default     = "arrowstack-task1-key"
}

variable "log_retention_days" {
  description = "CloudWatch log group retention in days."
  type        = number
  default     = 14
}
