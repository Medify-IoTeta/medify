-- The timing that will be dispensed next from this device, advanced in lockstep with
-- current_slot on every completed dispense (MORNING -> NOON -> EVENING -> MORNING). This is the
-- anchor a given physical slot's timing is computed relative to -- see BoxRefillService for why a
-- fixed per-slot-index timing assignment can't produce an even split across 13 physical positions.
ALTER TABLE devices ADD COLUMN next_due_timing VARCHAR(20) NOT NULL DEFAULT 'MORNING';
