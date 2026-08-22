CREATE TABLE intake_settings (
    id           BIGSERIAL PRIMARY KEY,
    morning_time TIME NOT NULL,
    noon_time    TIME NOT NULL,
    evening_time TIME NOT NULL
);

INSERT INTO intake_settings (morning_time, noon_time, evening_time)
VALUES ('08:00:00', '13:00:00', '20:00:00');
