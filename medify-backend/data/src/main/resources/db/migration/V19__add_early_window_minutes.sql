-- Configurable Early Window: how many minutes before the scheduled time a dose becomes eligible
-- for early intake. Lives on the existing single-row intake_settings table alongside the reminder
-- times, rather than a parallel config mechanism.
ALTER TABLE intake_settings ADD COLUMN early_window_minutes INTEGER NOT NULL DEFAULT 60;
