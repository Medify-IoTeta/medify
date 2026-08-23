package medify.backend.domain.model;

import java.util.List;
import java.util.Optional;

/**
 * The single, shared definition of "is anything chronologically earlier still unresolved" — used
 * by IntakeOrchestrationService (api module, request-time blocking of dispensing) and
 * ReminderScheduler (domain module, blocking B's normal scheduled reminder while A is unresolved).
 * Lives here rather than in either caller because domain must not depend on api, and both need it.
 */
public final class IntakeChronology {
    private IntakeChronology() {}

    /**
     * @param unresolvedOrderedByScheduledTime every IntakeStatus.UNRESOLVED intake for one user,
     *                                          earliest scheduledTime first (as returned by
     *                                          IntakeRepositoryPort.findUnresolvedOrderByScheduledTimeAsc)
     * @param targetIntakeId                    the intake being evaluated/attempted — if it is
     *                                           itself the earliest unresolved one, nothing blocks it
     */
    public static Optional<Intake> findEarlierUnresolved(List<Intake> unresolvedOrderedByScheduledTime, Long targetIntakeId) {
        if (unresolvedOrderedByScheduledTime.isEmpty()) {
            return Optional.empty();
        }
        Intake earliest = unresolvedOrderedByScheduledTime.get(0);
        if (targetIntakeId != null && targetIntakeId.equals(earliest.getId())) {
            return Optional.empty();
        }
        return Optional.of(earliest);
    }
}
