package medify.backend.domain.model;

import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.*;

class IntakeStatusTest {

    @Test
    void skippedAndTakenAreResolvedAndDoNotBlock() {
        assertFalse(IntakeStatus.UNRESOLVED.contains(IntakeStatus.SKIPPED));
        assertFalse(IntakeStatus.UNRESOLVED.contains(IntakeStatus.TAKEN));
        assertTrue(IntakeStatus.RESOLVED.contains(IntakeStatus.SKIPPED));
        assertTrue(IntakeStatus.RESOLVED.contains(IntakeStatus.TAKEN));
    }

    @Test
    void unresolvedCoversEveryBlockingState() {
        assertEquals(
                java.util.Set.of(IntakeStatus.PENDING, IntakeStatus.APPROVED, IntakeStatus.MISSED,
                        IntakeStatus.POSTPONED, IntakeStatus.DISPENSING, IntakeStatus.DISPENSED, IntakeStatus.INCOMPLETE),
                IntakeStatus.UNRESOLVED);
    }

    @Test
    void startableIsExactlyPendingApprovedMissedPostponed() {
        assertEquals(
                java.util.Set.of(IntakeStatus.PENDING, IntakeStatus.APPROVED, IntakeStatus.MISSED, IntakeStatus.POSTPONED),
                IntakeStatus.STARTABLE);
        // DISPENSING/DISPENSED/INCOMPLETE/TAKEN/SKIPPED must never be (re-)dispensed
        assertFalse(IntakeStatus.STARTABLE.contains(IntakeStatus.DISPENSING));
        assertFalse(IntakeStatus.STARTABLE.contains(IntakeStatus.DISPENSED));
        assertFalse(IntakeStatus.STARTABLE.contains(IntakeStatus.INCOMPLETE));
        assertFalse(IntakeStatus.STARTABLE.contains(IntakeStatus.TAKEN));
        assertFalse(IntakeStatus.STARTABLE.contains(IntakeStatus.SKIPPED));
    }
}
