-- DEMO-ONLY control: how many minutes after the scheduled time a dose stays available before
-- becoming MISSED. Default 60 preserves current/production behavior (previously a hardcoded
-- scheduledTime.plusHours(1) in ReminderScheduler). Lives on the existing single-row
-- intake_settings table alongside early_window_minutes, not a parallel config mechanism.
ALTER TABLE intake_settings ADD COLUMN missed_window_minutes INTEGER NOT NULL DEFAULT 60;
