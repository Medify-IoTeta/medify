package medify.backend.domain.model;

import org.junit.jupiter.api.Test;

import java.time.LocalDateTime;
import java.util.List;
import java.util.Optional;

import static org.junit.jupiter.api.Assertions.assertEquals;

class IntakeChronologyTest {

    private Intake intake(Long id, IntakeStatus status, Timing timing, LocalDateTime scheduledTime) {
        Intake i = new Intake();
        i.setId(id);
        i.setStatus(status);
        i.setTiming(timing);
        i.setScheduledTime(scheduledTime);
        return i;
    }

    @Test
    void twoPendingIntakesEarlierScheduledTimeSelected() {
        Intake earlier = intake(1L, IntakeStatus.PENDING, Timing.MORNING, LocalDateTime.of(2026, 1, 1, 8, 0));
        Intake later = intake(2L, IntakeStatus.PENDING, Timing.NOON, LocalDateTime.of(2026, 1, 1, 12, 0));

        List<Intake> sorted = IntakeChronology.sortByPriority(List.of(later, earlier)); // deliberately reversed input

        assertEquals(1L, sorted.get(0).getId());
    }

    @Test
    void twoMissedIntakesEarlierScheduledTimeSelected() {
        Intake earlier = intake(1L, IntakeStatus.MISSED, Timing.MORNING, LocalDateTime.of(2026, 1, 1, 10, 0));
        Intake later = intake(2L, IntakeStatus.MISSED, Timing.NOON, LocalDateTime.of(2026, 1, 1, 12, 0));

        List<Intake> sorted = IntakeChronology.sortByPriority(List.of(later, earlier));

        assertEquals(1L, sorted.get(0).getId());
    }

    @Test
    void missedAlwaysBeatsPendingEvenWhenPendingIsChronologicallyCloserToNow() {
        // MISSED occurred hours ago; PENDING is only minutes away. Under a naive "closest to now"
        // (absolute distance) comparison PENDING could look "closer," but MISSED must still win —
        // it needs attention regardless of how close some other upcoming dose is.
        LocalDateTime now = LocalDateTime.of(2026, 1, 1, 12, 0);
        Intake missed = intake(1L, IntakeStatus.MISSED, Timing.MORNING, now.minusHours(6));
        Intake pending = intake(2L, IntakeStatus.PENDING, Timing.NOON, now.plusMinutes(5));

        List<Intake> sorted = IntakeChronology.sortByPriority(List.of(pending, missed));

        assertEquals(1L, sorted.get(0).getId());
    }

    @Test
    void selectionIsIndependentOfTimingEnumOrder() {
        // EVENING is declared after MORNING in the Timing enum, but scheduled earlier here — the
        // sort must go strictly by scheduledTime, never by Timing's declaration/ordinal order.
        Intake evening = intake(1L, IntakeStatus.PENDING, Timing.EVENING, LocalDateTime.of(2026, 1, 1, 6, 0));
        Intake morning = intake(2L, IntakeStatus.PENDING, Timing.MORNING, LocalDateTime.of(2026, 1, 1, 9, 0));

        List<Intake> sorted = IntakeChronology.sortByPriority(List.of(morning, evening));

        assertEquals(1L, sorted.get(0).getId(),
                "EVENING (id=1) is scheduled earlier and must win despite its later enum position");
    }

    @Test
    void physicalSafetyBlockingStatusesOutrankMissedRegardlessOfTime() {
        // Regression guard for the existing blocking invariant: a chronologically-earlier DISPENSED
        // intake (pills physically in the shared compartment) must still block everything, even a
        // chronologically-LATER MISSED intake. MISSED priority must never override physical safety.
        Intake dispensed = intake(1L, IntakeStatus.DISPENSED, Timing.MORNING, LocalDateTime.of(2026, 1, 1, 8, 0));
        Intake missed = intake(2L, IntakeStatus.MISSED, Timing.NOON, LocalDateTime.of(2026, 1, 1, 12, 0));

        List<Intake> sorted = IntakeChronology.sortByPriority(List.of(missed, dispensed));

        assertEquals(1L, sorted.get(0).getId(), "DISPENSED must always outrank MISSED, regardless of relative scheduled time");
    }

    @Test
    void dispensingAndIncompleteAlsoOutrankMissedRegardlessOfTime() {
        Intake dispensing = intake(1L, IntakeStatus.DISPENSING, Timing.MORNING, LocalDateTime.of(2026, 1, 1, 9, 0));
        Intake incomplete = intake(2L, IntakeStatus.INCOMPLETE, Timing.NOON, LocalDateTime.of(2026, 1, 1, 10, 0));
        Intake missed = intake(3L, IntakeStatus.MISSED, Timing.EVENING, LocalDateTime.of(2026, 1, 1, 6, 0));

        List<Intake> sorted = IntakeChronology.sortByPriority(List.of(missed, incomplete, dispensing));

        assertEquals(List.of(1L, 2L, 3L), sorted.stream().map(Intake::getId).toList());
    }

    @Test
    void findEarlierUnresolvedUsesThePriorityOrderNotRawListOrder() {
        Intake missed = intake(1L, IntakeStatus.MISSED, Timing.MORNING, LocalDateTime.of(2026, 1, 1, 8, 0));
        Intake pending = intake(2L, IntakeStatus.PENDING, Timing.NOON, LocalDateTime.of(2026, 1, 1, 12, 0));
        List<Intake> sorted = IntakeChronology.sortByPriority(List.of(pending, missed));

        Optional<Intake> blocker = IntakeChronology.findEarlierUnresolved(sorted, 2L);

        assertEquals(1L, blocker.orElseThrow().getId());
    }

    @Test
    void sortByPriorityDoesNotMutateTheInputList() {
        Intake later = intake(2L, IntakeStatus.PENDING, Timing.NOON, LocalDateTime.of(2026, 1, 1, 12, 0));
        Intake earlier = intake(1L, IntakeStatus.PENDING, Timing.MORNING, LocalDateTime.of(2026, 1, 1, 8, 0));
        List<Intake> original = List.of(later, earlier); // List.of is immutable — mutation would throw

        IntakeChronology.sortByPriority(original);

        assertEquals(List.of(2L, 1L), original.stream().map(Intake::getId).toList());
    }
}
