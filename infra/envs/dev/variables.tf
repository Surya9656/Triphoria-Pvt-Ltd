variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "project" {
  type    = string
  default = "hotel-booking"
}

variable "environment" {
  type    = string
  default = "dev"
}

variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  type    = list(string)
  default = ["10.0.0.0/24", "10.0.1.0/24"]
}

variable "private_subnet_cidrs" {
  type    = list(string)
  default = ["10.0.10.0/24", "10.0.11.0/24"]
}

variable "availability_zones" {
  type    = list(string)
  default = ["us-east-1a", "us-east-1b"]
}

variable "container_image" {
  type    = string
  default = "public.ecr.aws/nginx/nginx:latest"
}

variable "container_port" {
  type    = number
  default = 80
}

variable "task_cpu" {
  type    = number
  default = 256
}

variable "task_memory" {
  type    = number
  default = 512
}

variable "desired_count" {
  type    = number
  default = 1
}

variable "db_engine" {
  type    = string
  default = "postgres"
}

variable "db_instance_class" {
  description = "Small instance class for dev"
  type        = string
  default     = "db.t4g.micro"
}

variable "db_allocated_storage" {
  type    = number
  default = 20
}

variable "db_name" {
  type    = string
  default = "hotel_bookings"
}

variable "db_username" {
  type    = string
  default = "app_user"
}

variable "db_password" {
  description = "Set via TF_VAR_db_password env var or a tfvars file excluded from git. Never commit real values."
  type        = string
  sensitive   = true
  default     = "changeme-in-dev"
}

variable "db_backup_retention_period" {
  description = "Short retention for dev"
  type        = number
  default     = 1
}

variable "db_deletion_protection" {
  description = "Disabled in dev so the DB can be torn down freely"
  type        = bool
  default     = false
}

variable "tags" {
  type = map(string)
  default = {
    Owner = "platform-team"
  }
}
