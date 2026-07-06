-- 001_create_tables.sql
-- Creates the core schema for the hotel booking assessment.

CREATE EXTENSION IF NOT EXISTS "pgcrypto"; -- for gen_random_uuid()

CREATE TABLE IF NOT EXISTS hotel_bookings (
    id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id        UUID NOT NULL,
    hotel_id      VARCHAR(100) NOT NULL,
    city          VARCHAR(100) NOT NULL,
    checkin_date  DATE NOT NULL,
    checkout_date DATE NOT NULL,
    amount        NUMERIC(12, 2) NOT NULL,
    status        VARCHAR(50) NOT NULL,
    created_at    TIMESTAMP NOT NULL DEFAULT now(),

    CONSTRAINT chk_checkout_after_checkin CHECK (checkout_date > checkin_date)
);

CREATE TABLE IF NOT EXISTS booking_events (
    id          BIGSERIAL PRIMARY KEY,
    booking_id  UUID NOT NULL REFERENCES hotel_bookings (id) ON DELETE CASCADE,
    event_type  VARCHAR(100) NOT NULL,
    payload     JSONB,
    created_at  TIMESTAMP NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_booking_events_booking_id ON booking_events (booking_id);

-- ---------------------------------------------------------------------------
-- Query optimization index (see README.md "Part 5" for the full explanation)
--
-- Target query:
--   SELECT org_id, status, COUNT(*), SUM(amount)
--   FROM hotel_bookings
--   WHERE city = 'delhi'
--     AND created_at >= NOW() - INTERVAL '30 days'
--   GROUP BY org_id, status;
--
-- The filter is an equality match on city plus a range predicate on
-- created_at, and the grouping columns are org_id/status. A composite
-- B-tree index with city first (equality column), created_at second
-- (range column), and org_id/status included lets Postgres do a single
-- index range scan and pull org_id/status straight from the index without
-- touching the heap for those columns (an index-only-ish scan once
-- combined with amount via INCLUDE).
-- ---------------------------------------------------------------------------
CREATE INDEX IF NOT EXISTS idx_hotel_bookings_city_created_at
    ON hotel_bookings (city, created_at)
    INCLUDE (org_id, status, amount);
