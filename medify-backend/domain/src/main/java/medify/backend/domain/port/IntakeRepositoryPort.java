package medify.backend.domain.port;

import medify.backend.domain.model.Intake;
import medify.backend.domain.model.IntakeStatus;
import medify.backend.domain.model.Timing;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.Collection;
import java.util.List;
import java.util.Optional;

public interface IntakeRepositoryPort {
    Intake save(Intake intake);
    Optional<Intake> findById(Long id);
    List<Intake> findByUserIdBetween(Long userId, LocalDateTime from, LocalDateTime to);
    List<Intake> findExpiredPendingIntakes(LocalDateTime now);
    List<Intake> findByStatusAndDispensedTimeBefore(IntakeStatus status, LocalDateTime cutoff);
    long countTakenSince(Long userId, IntakeStatus status, LocalDateTime since);

    /** The single row for one scheduled occurrence, if it has been created yet. Enforces "one occurrence -> at most one Intake" at the read side. */
    Optional<Intake> findByUserIdAndTimingAndScheduledDate(Long userId, Timing timing, LocalDate scheduledDate);

    /** All not-yet-resolved intakes for this user, earliest scheduled dose first — the ordering IntakeOrchestrationService relies on to enforce "earlier unresolved blocks later". */
    List<Intake> findUnresolvedOrderByScheduledTimeAsc(Long userId, Collection<IntakeStatus> unresolvedStatuses);

    /**
     * Atomically transitions the intake to newStatus only if its current status is one of allowedFrom.
     * Returns true iff the transition happened. This is the sole mechanism that may move an intake
     * into DISPENSING, so two near-simultaneous requests (double button press, double app tap) can
     * never both win.
     */
    boolean tryTransition(Long id, Collection<IntakeStatus> allowedFrom, IntakeStatus newStatus);
}
