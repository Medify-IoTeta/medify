CREATE TABLE devices (
    id               BIGSERIAL PRIMARY KEY,
    device_key       VARCHAR(100) NOT NULL UNIQUE,
    user_id          BIGINT NOT NULL REFERENCES users(id),
    secret_hash      VARCHAR(255) NOT NULL,
    status           VARCHAR(20) NOT NULL DEFAULT 'OFFLINE',
    last_seen_at     TIMESTAMP,
    firmware_version VARCHAR(50),
    created_at       TIMESTAMP NOT NULL DEFAULT now()
);

ALTER TABLE intakes ADD CONSTRAINT fk_intakes_device FOREIGN KEY (device_id) REFERENCES devices(id);

-- Seed the demo pill box, bound to the seeded patient (users.id = 1).
-- device_key/secret pair to flash into the Arduino's config.h during firmware setup:
--   deviceId = pillbox-01
--   token    = medify-dev-secret-001
-- secret_hash below is sha256("medify-dev-secret-001") — dev-only, rotate before any real deployment.
INSERT INTO devices (device_key, user_id, secret_hash, status)
VALUES ('pillbox-01', 1, 'e8b819e7514a14fd905d489648c4ef03ab8fbcd9808f73e343ddaf6759b6d94b', 'OFFLINE');
