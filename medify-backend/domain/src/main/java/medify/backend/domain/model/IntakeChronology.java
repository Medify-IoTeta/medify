package medify.backend.domain.model;

import java.util.ArrayList;
import java.util.Comparator;
import java.util.List;
import java.util.Optional;

/**
 * The single, shared definition of "which unresolved intake is most urgent for this user" — used
 * both to decide what blocks a later intake (IntakeOrchestrationService's explicit-target check,
 * ReminderScheduler's reminder-suppression check) and, when there's no explicit target (the
 * physical button), which one to act on. Lives here rather than in either caller because domain
 * must not depend on api, and both need it.
 */
public final class IntakeChronology {
    private IntakeChronology() {}

    /**
     * Priority tiers, most urgent first:
     * <ol>
     *   <li>DISPENSING / DISPENSED / INCOMPLETE — a physical-safety invariant, not a preference:
     *       the motor is mid-flight or pills are physically sitting in the shared compartment.
     *       These must outrank everything else unconditionally, regardless of scheduled time —
     *       a chronologically-later MISSED intake must never be selected ahead of an older
     *       DISPENSED one still awaiting removal (e.g. pills dispensed hours ago, never
     *       IR-confirmed, while a newer dose has since gone MISSED in the meantime).</li>
     *   <li>MISSED — the window passed unattended. Ranked ahead of merely-upcoming/deferred
     *       intakes even when one of those is chronologically closer to now.</li>
     *   <li>Everything else unresolved (PENDING, APPROVED, POSTPONED).</li>
     * </ol>
     * Within a tier, the earliest scheduledTime wins — never Timing (MORNING/NOON/EVENING)
     * enum order, which carries no chronological meaning on its own once times are configurable.
     */
    private static final Comparator<Intake> SELECTION_PRIORITY =
            Comparator.<Intake>comparingInt(intake -> tierOf(intake.getStatus()))
                    .thenComparing(Intake::getScheduledTime);

    private static int tierOf(IntakeStatus status) {
        return switch (status) {
            case DISPENSING, DISPENSED, INCOMPLETE -> 0;
            case MISSED -> 1;
            default -> 2; // PENDING, APPROVED, POSTPONED — the only other members of UNRESOLVED
        };
    }

    /** Returns a new list — never mutates the input — ordered by the priority rule above. */
    public static List<Intake> sortByPriority(List<Intake> unresolved) {
        List<Intake> sorted = new ArrayList<>(unresolved);
        sorted.sort(SELECTION_PRIORITY);
        return sorted;
    }

    /**
     * @param unresolvedByPriority every IntakeStatus.UNRESOLVED intake for one user, already
     *                             ordered by {@link #sortByPriority}
     * @param targetIntakeId       the intake being evaluated/attempted — if it is itself the
     *                             highest-priority unresolved one, nothing blocks it
     */
    public static Optional<Intake> findEarlierUnresolved(List<Intake> unresolvedByPriority, Long targetIntakeId) {
        if (unresolvedByPriority.isEmpty()) {
            return Optional.empty();
        }
        Intake earliest = unresolvedByPriority.get(0);
        if (targetIntakeId != null && targetIntakeId.equals(earliest.getId())) {
            return Optional.empty();
        }
        return Optional.of(earliest);
    }
}
