# Hotel Booking Platform — DevOps Assessment

Terraform infrastructure design (Internet → ALB → ECS/Fargate → RDS) plus a
locally runnable PostgreSQL setup with migrations, seed data, query
optimization, and backup/restore tooling.

Actual AWS deployment is **not** required or performed. Terraform is
validated through `fmt` / `init` / `validate` / `plan`. All database work
runs locally via Docker Compose.

## Repository layout

```
infra/
  modules/
    network/   VPC, public/private subnets, NAT, ALB/ECS/RDS security groups
    ecs/       ALB, target group, ECS cluster, task definition, service
    rds/       RDS instance (Postgres or MySQL), subnet group
  envs/
    dev/       small sizing, 1-day backup retention, deletion_protection=false
    prod/      larger sizing, 30-day backup retention, deletion_protection=true
db/
  migrations/  001_create_tables.sql, 002_seed_data.sql (auto-run by Postgres on first boot)
  seed/        seed.sql (source of truth for seed data, also copied into migrations/)
scripts/
  backup.sh    timestamped pg_dump
  restore.sh   restores a dump into a fresh database and verifies row counts
docker-compose.yml
.github/workflows/terraform.yml   fmt/init/validate/plan on every PR
```

---

## Part 1–3: Terraform Infrastructure

### Design

`Internet → ALB (public subnets) → ECS/Fargate (private subnets) → RDS (private subnets)`

- **Network module**: 1 VPC, 2 public + 2 private subnets across 2 AZs, 1 NAT
  gateway for private-subnet egress (image pulls, CloudWatch, etc.), and
  three security groups:
  - `alb-sg`: allows 80/443 from `0.0.0.0/0`
  - `ecs-sg`: allows the app port **only** from `alb-sg`
  - `rds-sg`: allows the DB port **only** from `ecs-sg` — RDS has
    `publicly_accessible = false` and lives in private subnets, so it is
    unreachable from the internet or from anything except the ECS tasks.
- **ECS module**: internet-facing ALB + target group (`target_type = ip` for
  Fargate), ECS cluster, Fargate task definition/service running in private
  subnets with `assign_public_ip = false`, CloudWatch log group, and IAM
  execution/task roles.
- **RDS module**: single RDS instance (Postgres by default, MySQL supported
  via `var.engine`), private subnet group, encrypted storage, configurable
  backup retention / deletion protection / Multi-AZ.

### Environments

`infra/envs/dev` and `infra/envs/prod` both call the same three modules with
different variable values:

| Setting                  | dev                  | prod                 |
|---------------------------|----------------------|----------------------|
| DB instance class          | `db.t4g.micro`       | `db.r6g.large`       |
| DB backup retention        | 1 day                | 30 days              |
| DB deletion protection     | `false`              | `true`               |
| DB Multi-AZ                | `false`              | `true`               |
| Fargate task size           | 256 CPU / 512 MB     | 1024 CPU / 2048 MB   |
| Desired task count           | 1                    | 2                    |
| Backend state key            | `hotel-booking/dev/terraform.tfstate` | `hotel-booking/prod/terraform.tfstate` |

Each environment has its own `variables.tf`, `<env>.tfvars`, and an `s3`
backend block with a separate state key (bucket/table names are placeholders
— replace `REPLACE_ME-*` with real values, or drop the `backend` block
entirely for local-only review).

### How to validate (no AWS account needed)

```bash
cd infra/envs/dev      # or infra/envs/prod

terraform fmt -check -recursive ../../..
terraform init -backend=false          # skip remote state, just download providers
terraform validate

# Plan-only, using dummy credentials since no real AWS account is used:
AWS_ACCESS_KEY_ID=dummy AWS_SECRET_ACCESS_KEY=dummy AWS_DEFAULT_REGION=us-east-1 \
TF_VAR_db_password=dummy-password \
terraform plan -var-file=dev.tfvars -refresh=false -lock=false
```

Repeat with `prod.tfvars` (and `TF_VAR_db_password` set) inside
`infra/envs/prod`.

### CI (Part 3 — optional, included)

`.github/workflows/terraform.yml` runs on every PR that touches `infra/**`,
for both `dev` and `prod` in a matrix:

1. `terraform fmt -check -recursive`
2. `terraform init -backend=false`
3. `terraform validate`
4. `terraform plan -refresh=false` (dummy credentials, no real AWS account
   required)

The plan output is uploaded as a workflow artifact **and** posted as a PR
comment (via `actions/github-script`), so it's visible without opening the
Actions tab.

---

## Part 4–5: Local Database

### Start the database

```bash
docker compose up -d
```

On first boot, Postgres automatically runs everything in
`db/migrations/` in filename order:

- `001_create_tables.sql` — creates `hotel_bookings`, `booking_events`, and
  the optimization index described below
- `002_seed_data.sql` — inserts 200 bookings across 5 cities, 6
  organizations, and 4 statuses, plus `booking_events` for roughly half of
  the bookings

(`db/seed/seed.sql` is kept as the source of truth for the seed data; the
copy in `db/migrations/` is what actually gets auto-executed.)

Check it worked:

```bash
docker exec -it hotel_bookings_db psql -U app_user -d hotel_bookings \
  -c "SELECT count(*) FROM hotel_bookings;" \
  -c "SELECT count(*) FROM booking_events;"
```

If you ever need to re-seed from scratch:

```bash
docker compose down -v   # drops the data volume
docker compose up -d
```

### Query optimization (Part 5)

Target query:

```sql
SELECT org_id, status, COUNT(*), SUM(amount)
FROM hotel_bookings
WHERE city = 'delhi'
  AND created_at >= NOW() - INTERVAL '30 days'
GROUP BY org_id, status;
```

Index added in `001_create_tables.sql`:

```sql
CREATE INDEX idx_hotel_bookings_city_created_at
    ON hotel_bookings (city, created_at)
    INCLUDE (org_id, status, amount);
```

**Why this shape:**

- `city` is an equality filter, so it goes first in the index — Postgres can
  jump straight to the `delhi` rows.
- `created_at` is a range filter (`>= NOW() - INTERVAL '30 days'`), so it
  goes second — within the `delhi` slice, the index can seek to the start of
  the 30-day window and scan forward instead of checking every row.
- `org_id`, `status`, and `amount` are only ever **read**, never filtered
  on, so they're added via `INCLUDE` rather than as extra key columns. That
  keeps the index's sortable key small while still letting Postgres satisfy
  the whole query from the index (an index-only scan) without a trip back
  to the heap for every matching row.

Verify the plan uses the index:

```bash
docker exec -it hotel_bookings_db psql -U app_user -d hotel_bookings -c "
EXPLAIN ANALYZE
SELECT org_id, status, COUNT(*), SUM(amount)
FROM hotel_bookings
WHERE city = 'delhi'
  AND created_at >= NOW() - INTERVAL '30 days'
GROUP BY org_id, status;
"
```

You should see `Index Only Scan using idx_hotel_bookings_city_created_at`
(or a bitmap variant, depending on planner cost estimates at this table
size) instead of a `Seq Scan`.

---

## Part 6: Backup and Restore

```bash
# Create a timestamped dump in ./backups/
./scripts/backup.sh

# Restore the most recent backup into a FRESH database
# (hotel_bookings_restore_test) on the same Postgres instance,
# leaving the original database untouched.
./scripts/restore.sh
```

`restore.sh` prints row counts for `hotel_bookings` and `booking_events`
from the restored database at the end. **To verify the restore worked**,
compare those counts against the source database:

```bash
docker exec -e PGPASSWORD=app_password hotel_bookings_db \
  psql -U app_user -d hotel_bookings -t -A -c "SELECT count(*) FROM hotel_bookings;"

docker exec -e PGPASSWORD=app_password hotel_bookings_db \
  psql -U app_user -d hotel_bookings_restore_test -t -A -c "SELECT count(*) FROM hotel_bookings;"
```

The two counts should match (200 bookings, plus whatever `booking_events`
count was seeded). You can also spot-check specific rows:

```bash
docker exec -e PGPASSWORD=app_password hotel_bookings_db \
  psql -U app_user -d hotel_bookings_restore_test -c "SELECT * FROM hotel_bookings LIMIT 5;"
```

You can restore a specific (older) dump instead of the latest one:

```bash
./scripts/restore.sh backups/hotel_bookings_20260706_101500.dump
```

---

## Full end-to-end verification checklist

```bash
# --- Terraform ---
cd infra/envs/dev
terraform fmt -check -recursive ../../..
terraform init -backend=false
terraform validate
AWS_ACCESS_KEY_ID=dummy AWS_SECRET_ACCESS_KEY=dummy AWS_DEFAULT_REGION=us-east-1 \
TF_VAR_db_password=dummy terraform plan -var-file=dev.tfvars -refresh=false -lock=false
cd ../prod
terraform init -backend=false
terraform validate
AWS_ACCESS_KEY_ID=dummy AWS_SECRET_ACCESS_KEY=dummy AWS_DEFAULT_REGION=us-east-1 \
TF_VAR_db_password=dummy terraform plan -var-file=prod.tfvars -refresh=false -lock=false
cd ../../..

# --- Database ---
docker compose up -d
./scripts/backup.sh
./scripts/restore.sh
```
