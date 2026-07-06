terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Separate state per environment. Fill in bucket/table for your account,
  # or run with `-backend=false` for local plan-only review.
  backend "s3" {
    bucket         = "REPLACE_ME-terraform-state-dev"
    key            = "hotel-booking/dev/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "REPLACE_ME-terraform-locks-dev"
    encrypt        = true
  }
}

provider "aws" {
  region = var.aws_region
}

module "network" {
  source = "../../modules/network"

  project              = var.project
  environment          = var.environment
  vpc_cidr             = var.vpc_cidr
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
  availability_zones   = var.availability_zones
  app_port             = var.container_port
  enable_nat_gateway   = true
  tags                 = var.tags
}

module "rds" {
  source = "../../modules/rds"

  project            = var.project
  environment        = var.environment
  engine             = var.db_engine
  instance_class     = var.db_instance_class
  allocated_storage  = var.db_allocated_storage
  db_name            = var.db_name
  db_username        = var.db_username
  db_password        = var.db_password
  private_subnet_ids = module.network.private_subnet_ids
  security_group_ids = [module.network.rds_security_group_id]

  backup_retention_period = var.db_backup_retention_period
  deletion_protection     = var.db_deletion_protection
  multi_az                = false
  skip_final_snapshot     = true

  tags = var.tags
}

module "ecs" {
  source = "../../modules/ecs"

  project               = var.project
  environment           = var.environment
  vpc_id                = module.network.vpc_id
  public_subnet_ids     = module.network.public_subnet_ids
  private_subnet_ids    = module.network.private_subnet_ids
  alb_security_group_id = module.network.alb_security_group_id
  ecs_security_group_id = module.network.ecs_security_group_id

  container_image = var.container_image
  container_port  = var.container_port
  task_cpu        = var.task_cpu
  task_memory     = var.task_memory
  desired_count   = var.desired_count

  container_environment = {
    DB_HOST = module.rds.db_address
    DB_PORT = tostring(module.rds.db_port)
    DB_NAME = module.rds.db_name
    ENV     = var.environment
  }

  tags = var.tags
}
