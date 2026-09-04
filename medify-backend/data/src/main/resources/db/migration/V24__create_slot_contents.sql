-- Persisted actual contents of every physical slot, independent of any refill session -- this is
-- what makes "which cells still have this medicine" survive starting a new refill pass. Replaces
-- box_slot_fills as the live-state table; box_slot_fills/box_refill_sessions remain as-is for now,
-- available to be repurposed as pure history/audit later, but nothing reads them for current state.
CREATE TABLE slot_contents (
    id          BIGSERIAL PRIMARY KEY,
    device_id   BIGINT    NOT NULL REFERENCES devices(id),
    slot_number INTEGER   NOT NULL,
    medicine_id BIGINT    NOT NULL REFERENCES medications(id),
    added_at    TIMESTAMP NOT NULL,
    UNIQUE (device_id, slot_number, medicine_id)
);
