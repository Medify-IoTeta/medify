CREATE TYPE timing_enum AS ENUM ('MORNING', 'NOON', 'EVENING');

CREATE TABLE medications (
                             id                        BIGSERIAL PRIMARY KEY,
                             user_id                   BIGINT NOT NULL,
                             name                      VARCHAR(255) NOT NULL,
                             description               VARCHAR(255),
                             timing                    timing_enum NOT NULL,
                             pre_intake_notice_minutes INTEGER,
                             pre_intake_notice_text    VARCHAR(255),
                             is_active                 BOOLEAN NOT NULL DEFAULT TRUE
);