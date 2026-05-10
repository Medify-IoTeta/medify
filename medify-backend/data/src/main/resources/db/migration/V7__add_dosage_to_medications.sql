ALTER TABLE medications
    ADD COLUMN dosage_amount DECIMAL(10, 2),
    ADD COLUMN dosage_unit   VARCHAR(20);
