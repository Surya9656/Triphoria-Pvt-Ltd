# DevOps Assessment – Terraform + Database Reliability
## Overview
This repository contains the solution for the **DevOps Assessment: Terraform + Database Reliability**.
The project demonstrates:
- Infrastructure as Code using Terraform
- Multi-environment Terraform structure (dev/prod)
- AWS infrastructure design (VPC, ALB, ECS/Fargate, RDS)
- Local PostgreSQL database using Docker Compose
- Database migration and seed data
- Query optimization using indexes
- Database backup and restore using Shell scripts
- GitHub Actions workflow for Terraform validation
---
## Technology Stack
- Terraform
- AWS
- Amazon VPC
- Application Load Balancer (ALB)
- Amazon ECS (Fargate)
- Amazon RDS (PostgreSQL)
- Docker Compose
- PostgreSQL
- Bash Shell Scripts
- GitHub Actions
---------------------
## Project Structure
```text
hotel-booking-devops/
├── infra/
│   ├── modules/
│   │   ├── network/
│   │   ├── ecs/
│   │   └── rds/
│   └── envs/
│       ├── dev/
│       └── prod/
├── database/
│   ├── migrations/
│   ├── seed/
│   └── indexes.sql
├── scripts/
│   ├── backup.sh
│   └── restore.sh
├── backups/
├── docker-compose.yml
├── .github/
│   └── workflows/
│       └── terraform.yml
└── README.md
```
-------------------------------------------------
## Part 1 – Terraform Infrastructure
Terraform provisions the following AWS infrastructure:
- VPC
- Public Subnets
- Private Subnets
- Internet Gateway
- Route Tables
- Security Groups
- Application Load Balancer
- ECS Cluster
- ECS Task Definition
- ECS Service (Fargate)
- Amazon RDS PostgreSQL
- CloudWatch Log Group
- IAM Roles
### Infrastructure Flow
```text
Internet
    │
    ▼
Application Load Balancer
    │
    ▼
ECS Fargate Service
    │
    ▼
Amazon RDS PostgreSQL
```

---

## Part 2 – Environment Handling

Separate environments are maintained.

### Development

- Small instance sizes
- Short backup retention
- Deletion protection disabled

### Production

- Larger instance sizes
- Long backup retention
- Deletion protection enabled

Environment folders:
```text
infra/envs/dev
infra/envs/prod
```
Each environment contains:
- backend.tf
- terraform.tfvars
- variables
- provider configuration
---------------------------------------------
## Part 3 – Terraform Commands
### Initialize Terraform
```bash
terraform init
```
### Format Configuration
```bash
terraform fmt -recursive
```
### Validate Configuration
```bash
terraform validate
```
### Review Execution Plan
```bash
terraform plan
```
### Deploy Infrastructure
```bash
terraform apply
```
### Destroy Infrastructure
```bash
terraform destroy
```
----------------------------------------
## ECS Verification Commands
### List Tasks
```bash
aws ecs list-tasks --cluster hotel-booking-devops-dev-cluster
```
### Describe Service
```bash
aws ecs describe-services \
--cluster hotel-booking-devops-dev-cluster \
--services hotel-booking-devops-dev-service
```
### Describe Task
```bash
aws ecs describe-tasks \
--cluster hotel-booking-devops-dev-cluster \
--tasks <TASK_ID>
```
### Check Target Health
```bash
aws elbv2 describe-target-health \
--target-group-arn <TARGET_GROUP_ARN>
```
---
## Part 4 – Local Database
### Start PostgreSQL
```bash
docker compose up -d
```
### Verify Container
```bash
docker ps
```
### Connect to PostgreSQL
```bash
docker exec -it hotel_bookings_db psql -U postgres -d hotel_bookings
```
----------------------------------------
## Database Schema
### hotel_bookings
- id
- org_id
- hotel_id
- city
- checkin_date
- checkout_date
- amount
- status
- created_at
### booking_events
- id
- booking_id
- event_type
- payload
- created_at
---
## Part 5 – Seed Data
The database contains:
- 100 hotel bookings
- Multiple organizations
- Multiple cities
- Multiple booking statuses
- Booking events
Run the seed script:
```bash
psql -U postgres -d hotel_bookings -f database/seed/seed.sql
```
---
## Query Optimization
Optimized query:
```sql
SELECT
    org_id,
    status,
    COUNT(*),
    SUM(amount)
FROM hotel_bookings
WHERE city = 'delhi'
AND created_at >= NOW() - INTERVAL '30 days'
GROUP BY org_id, status;
```
Composite index:
```sql
CREATE INDEX idx_hotel_bookings_city_created_org_status
ON hotel_bookings
(city, created_at, org_id, status);
```
### Why this index?
The query filters by:
- city
- created_at
and groups by:
- org_id
- status
The composite index improves query performance by reducing the number of rows scanned.
-------------------------------------------------------
## Part 6 – Backup
Run the backup script:
```bash
./scripts/backup.sh
```
The backup is stored in:
```text
backups/
```
Example:
```text
hotel_bookings_20260706_142530.sql
```
---------------------------------------------------
## Restore
Run:
```bash
./scripts/restore.sh
```
The script:
- Creates a fresh database
- Restores the latest backup
- Verifies the restore
---
## Verify Restore
Connect to PostgreSQL:
```bash
docker exec -it hotel_bookings_db psql -U postgres -d hotel_bookings
```
Verify hotel bookings:
```sql
SELECT COUNT(*) FROM hotel_bookings;
```
Verify booking events:
```sql
SELECT COUNT(*) FROM booking_events;
```
---------------------------------------------
## GitHub Actions
The workflow automatically runs:
- terraform fmt
- terraform init
- terraform validate
- terraform plan
Workflow location:
```text
.github/workflows/terraform.yml
```
------------------------------------------------
## Submission Checklist
- Terraform Infrastructure
- Dev and Prod environments
- AWS Modules
- Docker Compose
- PostgreSQL
- SQL Migrations
- Seed Data
- Query Optimization
- Backup Script
- Restore Script
- GitHub Actions
- README Documentation
---
## Repository Setup
Clone the repository:
```bash
git clone <repository-url>
```
Move into the project:
```bash
cd hotel-booking-devops
```
Start PostgreSQL:
```bash
docker compose up -d
```
Initialize Terraform:
```bash
cd infra/envs/dev
terraform init
```
Validate:
```bash
terraform validate
```
Plan:
```bash
terraform plan
```
Deploy:
```bash
terraform apply
```
---
## Author
**Surya Kandipalli**
**DevOps Engineer**
<img width="1920" height="1080" alt="Screenshot 2026-07-06 160954" src="https://github.com/user-attachments/assets/49622d94-9b93-4c1d-ae0c-289f7a99b7f4" />
