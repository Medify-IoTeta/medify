CREATE TABLE notifications_log (
    id                BIGSERIAL PRIMARY KEY,
    recipient_user_id BIGINT       NOT NULL REFERENCES users(id),
    intake_id         BIGINT       REFERENCES intakes(id),
    type              VARCHAR(50)  NOT NULL,
    message           VARCHAR(500) NOT NULL,
    sent_time         TIMESTAMP    NOT NULL,
    delivery_status   VARCHAR(20)
);
