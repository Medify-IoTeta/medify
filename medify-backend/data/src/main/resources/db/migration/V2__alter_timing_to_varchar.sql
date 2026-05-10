ALTER TABLE medications
    ALTER COLUMN timing TYPE VARCHAR(50) USING timing::text;

DROP TYPE timing_enum;
