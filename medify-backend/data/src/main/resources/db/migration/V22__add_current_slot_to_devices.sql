-- The backend-persisted, authoritative physical wheel position (0-based, 0..TOTAL_SLOTS-1),
-- durable across Arduino reboots/power loss. The device syncs from this value on every WebSocket
-- connect, instead of assuming its own RAM-only counter (reset to 0 on every boot) is correct.
ALTER TABLE devices ADD COLUMN current_slot INTEGER NOT NULL DEFAULT 0;
