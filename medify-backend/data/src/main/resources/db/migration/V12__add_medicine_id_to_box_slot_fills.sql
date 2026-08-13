DELETE FROM box_slot_fills;

ALTER TABLE box_slot_fills
    ADD COLUMN medicine_id BIGINT NOT NULL REFERENCES medications(id);

ALTER TABLE box_slot_fills
    ADD CONSTRAINT uq_box_slot_fills_session_slot_medicine
        UNIQUE (session_id, slot_number, medicine_id);
