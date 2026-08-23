-- Tracks the last "your reminder is being held because of an earlier unresolved dose"
-- notification sent for an intake, so the 30s reconcile tick doesn't resend an identical one every
-- cycle while the same blocker is still unresolved. Deliberately separate from
-- reminder_evaluated_at, which is a *permanent* decision — this pair goes stale (and a fresh
-- notification, or the normal reminder, can fire) the moment the blocking intake's status changes.
ALTER TABLE intakes ADD COLUMN blocked_notified_intake_id BIGINT;
ALTER TABLE intakes ADD COLUMN blocked_notified_status VARCHAR(20);
