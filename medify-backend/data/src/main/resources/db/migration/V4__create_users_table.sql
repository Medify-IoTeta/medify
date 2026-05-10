CREATE TABLE users (
    id            BIGSERIAL PRIMARY KEY,
    username      VARCHAR(255) NOT NULL,
    email         VARCHAR(255) NOT NULL UNIQUE,
    phone         VARCHAR(50),
    password_hash VARCHAR(255),
    type          VARCHAR(20) NOT NULL
);

-- Seed demo users for development (patient=1, caregiver=2)
INSERT INTO users (username, email, phone, password_hash, type) VALUES
('patient',   'patient@medify.com',   '0501234567', 'placeholder', 'PATIENT'),
('caregiver', 'caregiver@medify.com', '0507654321', 'placeholder', 'CAREGIVER');
