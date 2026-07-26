CREATE TABLE IF NOT EXISTS box_refill_sessions (
    id         BIGSERIAL PRIMARY KEY,
    user_id    BIGINT    NOT NULL,
    started_at TIMESTAMP NOT NULL,
    is_active  BOOLEAN   NOT NULL DEFAULT TRUE
);

CREATE TABLE IF NOT EXISTS box_slot_fills (
    id          BIGSERIAL PRIMARY KEY,
    session_id  BIGINT    NOT NULL REFERENCES box_refill_sessions(id),
    slot_number INTEGER   NOT NULL,
    filled_at   TIMESTAMP NOT NULL
);
