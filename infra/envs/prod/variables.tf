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
  default = "prod"
}

variable "vpc_cidr" {
  type    = string
  default = "10.1.0.0/16"
}

variable "public_subnet_cidrs" {
  type    = list(string)
  default = ["10.1.0.0/24", "10.1.1.0/24"]
}

variable "private_subnet_cidrs" {
  type    = list(string)
  default = ["10.1.10.0/24", "10.1.11.0/24"]
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
  description = "Larger task size for prod"
  type        = number
  default     = 1024
}

variable "task_memory" {
  type    = number
  default = 2048
}

variable "desired_count" {
  description = "Run 2 tasks in prod for availability"
  type        = number
  default     = 2
}

variable "db_engine" {
  type    = string
  default = "postgres"
}

variable "db_instance_class" {
  description = "Larger instance class for prod"
  type        = string
  default     = "db.r6g.large"
}

variable "db_allocated_storage" {
  type    = number
  default = 100
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
  description = "Set via TF_VAR_db_password env var or a secrets manager. Never commit real values."
  type        = string
  sensitive   = true
}

variable "db_backup_retention_period" {
  description = "Longer retention for prod"
  type        = number
  default     = 30
}

variable "db_deletion_protection" {
  description = "Enabled in prod to prevent accidental deletion"
  type        = bool
  default     = true
}

variable "tags" {
  type = map(string)
  default = {
    Owner = "platform-team"
  }
}
