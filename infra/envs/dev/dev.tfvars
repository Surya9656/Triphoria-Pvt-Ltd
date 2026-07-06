aws_region  = "us-east-1"
project     = "hotel-booking"
environment = "dev"

vpc_cidr             = "10.0.0.0/16"
public_subnet_cidrs  = ["10.0.0.0/24", "10.0.1.0/24"]
private_subnet_cidrs = ["10.0.10.0/24", "10.0.11.0/24"]
availability_zones   = ["us-east-1a", "us-east-1b"]

container_image = "public.ecr.aws/nginx/nginx:latest"
container_port  = 80
task_cpu        = 256
task_memory     = 512
desired_count   = 1

db_engine            = "postgres"
db_instance_class    = "db.t4g.micro"
db_allocated_storage = 20
db_name              = "hotel_bookings"
db_username          = "app_user"
# db_password should come from TF_VAR_db_password, not this file.

db_backup_retention_period = 1
db_deletion_protection     = false

tags = {
  Owner = "platform-team"
}
