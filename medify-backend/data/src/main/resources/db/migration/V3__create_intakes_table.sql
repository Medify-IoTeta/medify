CREATE TABLE intakes (
    id                BIGSERIAL PRIMARY KEY,
    user_id           BIGINT NOT NULL,
    device_id         BIGINT,
    timing            VARCHAR(20) NOT NULL,
    window_start_time TIMESTAMP NOT NULL,
    window_end_time   TIMESTAMP NOT NULL,
    approved_time     TIMESTAMP,
    released_time     TIMESTAMP,
    status            VARCHAR(20) NOT NULL DEFAULT 'PENDING'
);
