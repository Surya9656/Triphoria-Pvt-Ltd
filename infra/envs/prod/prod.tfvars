aws_region  = "us-east-1"
project     = "hotel-booking"
environment = "prod"

vpc_cidr             = "10.1.0.0/16"
public_subnet_cidrs  = ["10.1.0.0/24", "10.1.1.0/24"]
private_subnet_cidrs = ["10.1.10.0/24", "10.1.11.0/24"]
availability_zones   = ["us-east-1a", "us-east-1b"]

container_image = "public.ecr.aws/nginx/nginx:latest"
container_port  = 80
task_cpu        = 1024
task_memory     = 2048
desired_count   = 2

db_engine            = "postgres"
db_instance_class    = "db.r6g.large"
db_allocated_storage = 100
db_name              = "hotel_bookings"
db_username          = "app_user"
# db_password must come from TF_VAR_db_password or a secrets manager, never this file.

db_backup_retention_period = 30
db_deletion_protection     = true

tags = {
  Owner = "platform-team"
}
