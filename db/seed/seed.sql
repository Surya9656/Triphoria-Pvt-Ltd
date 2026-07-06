-- seed.sql
-- Populates hotel_bookings and booking_events with realistic sample data:
--   - 200 bookings (comfortably over the required 100)
--   - 5 cities, 6 organizations, 4 statuses
--   - booking_events for roughly half of the bookings
--
-- Uses set-based generation (generate_series) so it runs fast and
-- deterministically without needing an external scripting language.

BEGIN;

-- Fixed set of organization UUIDs so re-running the seed is reproducible.
WITH orgs AS (
    SELECT unnest(ARRAY[
        '11111111-1111-1111-1111-111111111111',
        '22222222-2222-2222-2222-222222222222',
        '33333333-3333-3333-3333-333333333333',
        '44444444-4444-4444-4444-444444444444',
        '55555555-5555-5555-5555-555555555555',
        '66666666-6666-6666-6666-666666666666'
    ]::uuid[]) AS org_id
),
cities AS (
    SELECT unnest(ARRAY['delhi', 'mumbai', 'bangalore', 'hyderabad', 'chennai']) AS city
),
statuses AS (
    SELECT unnest(ARRAY['confirmed', 'cancelled', 'pending', 'completed']) AS status
),
generated AS (
    SELECT
        gen_random_uuid() AS id,
        (SELECT org_id FROM orgs ORDER BY random() LIMIT 1) AS org_id,
        'HTL-' || lpad((floor(random() * 50) + 1)::text, 4, '0') AS hotel_id,
        (SELECT city FROM cities ORDER BY random() LIMIT 1) AS city,
        (SELECT status FROM statuses ORDER BY random() LIMIT 1) AS status,
        -- spread created_at across the last 90 days so the "last 30 days"
        -- filter in the target query has a realistic mix of matches/misses
        now() - (random() * interval '90 days') AS created_at,
        (round((random() * 400 + 50)::numeric, 2)) AS amount,
        (current_date - (floor(random() * 60))::int) AS checkin_date,
        (floor(random() * 5) + 1)::int AS stay_nights,
        gs AS seq
    FROM generate_series(1, 200) AS gs
)
INSERT INTO hotel_bookings (id, org_id, hotel_id, city, checkin_date, checkout_date, amount, status, created_at)
SELECT
    id,
    org_id,
    hotel_id,
    city,
    checkin_date,
    checkin_date + stay_nights,
    amount,
    status,
    created_at
FROM generated;

-- Booking events for roughly half the bookings: a "created" event for all
-- of them, plus a follow-up "status_changed" event for non-pending ones.
INSERT INTO booking_events (booking_id, event_type, payload, created_at)
SELECT
    id,
    'created',
    jsonb_build_object('source', 'seed_script'),
    created_at
FROM hotel_bookings
WHERE random() < 0.5;

INSERT INTO booking_events (booking_id, event_type, payload, created_at)
SELECT
    id,
    'status_changed',
    jsonb_build_object('new_status', status),
    created_at + interval '1 hour'
FROM hotel_bookings
WHERE status <> 'pending'
  AND random() < 0.5;

COMMIT;

-- Quick sanity counts (visible when running via psql -f)
SELECT 'hotel_bookings' AS table_name, count(*) FROM hotel_bookings
UNION ALL
SELECT 'booking_events', count(*) FROM booking_events;
