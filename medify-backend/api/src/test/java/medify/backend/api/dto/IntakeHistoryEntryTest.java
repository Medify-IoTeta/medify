package medify.backend.api.dto;

import medify.backend.domain.model.Intake;
import medify.backend.domain.model.IntakeStatus;
import medify.backend.domain.model.Timing;
import org.junit.jupiter.api.Test;

import java.time.LocalDate;
import java.time.LocalDateTime;

import static org.junit.jupiter.api.Assertions.*;

class IntakeHistoryEntryTest {

    private Intake baseIntake(IntakeStatus status) {
        Intake i = new Intake();
        i.setId(1L);
        i.setUserId(1L);
        i.setTiming(Timing.MORNING);
        i.setScheduledDate(LocalDate.of(2026, 9, 1));
        i.setScheduledTime(LocalDateTime.of(2026, 9, 1, 8, 0));
        i.setStatus(status);
        return i;
    }

    @Test
    void takenWithNoDeviationIsTakenOnTime() {
        Intake intake = baseIntake(IntakeStatus.TAKEN);
        intake.setReleasedTime(LocalDateTime.of(2026, 9, 1, 8, 5));

        IntakeHistoryEntry entry = IntakeHistoryEntry.from(intake);

        assertEquals(IntakeHistoryEntry.Outcome.TAKEN_ON_TIME, entry.outcome());
        assertEquals(5L, entry.latenessMinutes());
        assertFalse(entry.wasPostponed());
    }

    @Test
    void takenAfterPostponeIsTakenAfterPostponed() {
        Intake intake = baseIntake(IntakeStatus.TAKEN);
        intake.setPostponedAt(LocalDateTime.of(2026, 9, 1, 8, 10));
        intake.setReleasedTime(LocalDateTime.of(2026, 9, 1, 8, 30));

        IntakeHistoryEntry entry = IntakeHistoryEntry.from(intake);

        assertEquals(IntakeHistoryEntry.Outcome.TAKEN_AFTER_POSTPONED, entry.outcome());
        assertEquals(30L, entry.latenessMinutes());
        assertTrue(entry.wasPostponed());
    }

    @Test
    void takenAfterMissedIsTakenAfterMissedEvenIfAlsoPostponed() {
        Intake intake = baseIntake(IntakeStatus.TAKEN);
        intake.setPostponedAt(LocalDateTime.of(2026, 9, 1, 8, 10));
        intake.setMissedAt(LocalDateTime.of(2026, 9, 1, 9, 0));
        intake.setReleasedTime(LocalDateTime.of(2026, 9, 1, 10, 0));

        IntakeHistoryEntry entry = IntakeHistoryEntry.from(intake);

        // MISSED dominates over POSTPONED per product decision, even though both happened.
        assertEquals(IntakeHistoryEntry.Outcome.TAKEN_AFTER_MISSED, entry.outcome());
        assertEquals(120L, entry.latenessMinutes());
        assertTrue(entry.wasPostponed());
    }

    @Test
    void takenEarlyDuringWindowGivesNegativeLateness() {
        Intake intake = baseIntake(IntakeStatus.TAKEN);
        intake.setReleasedTime(LocalDateTime.of(2026, 9, 1, 7, 50));

        IntakeHistoryEntry entry = IntakeHistoryEntry.from(intake);

        assertEquals(IntakeHistoryEntry.Outcome.TAKEN_ON_TIME, entry.outcome());
        assertEquals(-10L, entry.latenessMinutes());
    }

    @Test
    void missedNeverTakenHasNoTakenAtOrLateness() {
        Intake intake = baseIntake(IntakeStatus.MISSED);
        intake.setMissedAt(LocalDateTime.of(2026, 9, 1, 9, 0));

        IntakeHistoryEntry entry = IntakeHistoryEntry.from(intake);

        assertEquals(IntakeHistoryEntry.Outcome.MISSED, entry.outcome());
        assertNull(entry.takenAt());
        assertNull(entry.latenessMinutes());
    }

    @Test
    void skippedIncompleteAndInProgressStatusesKeepDistinctOutcomes() {
        assertEquals(IntakeHistoryEntry.Outcome.SKIPPED, IntakeHistoryEntry.from(baseIntake(IntakeStatus.SKIPPED)).outcome());
        assertEquals(IntakeHistoryEntry.Outcome.INCOMPLETE, IntakeHistoryEntry.from(baseIntake(IntakeStatus.INCOMPLETE)).outcome());
        assertEquals(IntakeHistoryEntry.Outcome.PENDING, IntakeHistoryEntry.from(baseIntake(IntakeStatus.PENDING)).outcome());
        assertEquals(IntakeHistoryEntry.Outcome.APPROVED, IntakeHistoryEntry.from(baseIntake(IntakeStatus.APPROVED)).outcome());
        assertEquals(IntakeHistoryEntry.Outcome.POSTPONED, IntakeHistoryEntry.from(baseIntake(IntakeStatus.POSTPONED)).outcome());
        assertEquals(IntakeHistoryEntry.Outcome.DISPENSING, IntakeHistoryEntry.from(baseIntake(IntakeStatus.DISPENSING)).outcome());
        assertEquals(IntakeHistoryEntry.Outcome.DISPENSED, IntakeHistoryEntry.from(baseIntake(IntakeStatus.DISPENSED)).outcome());
    }
}
