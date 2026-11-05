###############################################################################
# Providers & Backend
###############################################################################
terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.40"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }

  # Uncomment to use remote state. For local-first runs, state stays in ./terraform.tfstate
  # backend "s3" {
  #   bucket         = "arrowstack-tfstate"
  #   key            = "task-1-cloud-architecture/terraform.tfstate"
  #   region         = "ap-south-1"
  #   dynamodb_table = "arrowstack-tf-locks"
  #   encrypt        = true
  # }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "Arrowstack-Task1-CloudArchitecture"
      ManagedBy   = "Terraform"
      Owner       = var.owner_email
      Environment = var.environment
      RefID       = "AS-2026-24281"
    }
  }
}
