-- Gives each Intake a stable "scheduled occurrence" identity (userId + timing + scheduledDate),
-- independent of when the row was actually created (early-window intakes are now created up to
-- earlyWindowMinutes before the scheduled instant, not at it). Also adds history timestamps.

ALTER TABLE intakes ADD COLUMN scheduled_time TIMESTAMP;
ALTER TABLE intakes ADD COLUMN scheduled_date DATE;
ALTER TABLE intakes ADD COLUMN reminder_evaluated_at TIMESTAMP;
ALTER TABLE intakes ADD COLUMN missed_at TIMESTAMP;
ALTER TABLE intakes ADD COLUMN postponed_at TIMESTAMP;
ALTER TABLE intakes ADD COLUMN postponed_until TIMESTAMP;

-- Backfill existing rows: under the pre-refactor model, window_start_time was set to "now" at the
-- moment the row was created, and creation only ever happened at the scheduled instant itself — so
-- window_start_time is the correct scheduled_time for all pre-existing data.
UPDATE intakes SET scheduled_time = window_start_time WHERE scheduled_time IS NULL;
UPDATE intakes SET scheduled_date = window_start_time::date WHERE scheduled_date IS NULL;
-- Mark pre-existing rows as already evaluated so the scheduler never re-sends a reminder for a
-- historical intake it didn't create under the new flow (findByUserIdAndTimingAndScheduledDate
-- only ever looks at today's date, so this mainly matters for any row that happens to be "today").
UPDATE intakes SET reminder_evaluated_at = window_start_time WHERE reminder_evaluated_at IS NULL;

-- Dev/local data only (see medify-backend/CLAUDE.md — one-patient-per-deployment, Docker Postgres):
-- the pre-refactor model had no occurrence-uniqueness guarantee, so a handful of duplicate
-- (user_id, timing, scheduled_date) rows may exist (e.g. from repeated manual /api/notification/test
-- triggers). Keep only the most recent row per occurrence before the constraint below is added.
DELETE FROM intakes a USING intakes b
WHERE a.user_id = b.user_id
  AND a.timing = b.timing
  AND a.scheduled_date = b.scheduled_date
  AND a.id < b.id;

ALTER TABLE intakes ALTER COLUMN scheduled_time SET NOT NULL;
ALTER TABLE intakes ALTER COLUMN scheduled_date SET NOT NULL;

-- The core "one scheduled dose occurrence -> at most one Intake" rule, enforced at the DB level
-- (application-level checks in ReminderScheduler are the first line of defense; this is the backstop).
ALTER TABLE intakes ADD CONSTRAINT uq_intakes_user_timing_scheduled_date UNIQUE (user_id, timing, scheduled_date);

CREATE INDEX idx_intakes_user_status ON intakes (user_id, status);
