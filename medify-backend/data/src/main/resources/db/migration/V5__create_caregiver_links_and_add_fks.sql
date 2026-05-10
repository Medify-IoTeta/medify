ALTER TABLE medications ADD CONSTRAINT fk_medications_user FOREIGN KEY (user_id) REFERENCES users(id);
ALTER TABLE intakes     ADD CONSTRAINT fk_intakes_user     FOREIGN KEY (user_id) REFERENCES users(id);

CREATE TABLE caregiver_links (
    patient_id     BIGINT  NOT NULL REFERENCES users(id),
    caregiver_id   BIGINT  NOT NULL REFERENCES users(id),
    receive_alerts BOOLEAN NOT NULL DEFAULT TRUE,
    PRIMARY KEY (patient_id, caregiver_id)
);

-- Seed demo link
INSERT INTO caregiver_links (patient_id, caregiver_id, receive_alerts) VALUES (1, 2, true);
