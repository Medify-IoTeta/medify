package medify.backend.data.repository;

import medify.backend.domain.model.Intake;
import medify.backend.domain.model.IntakeStatus;
import medify.backend.domain.model.Timing;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.transaction.annotation.Transactional;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.Collection;
import java.util.List;
import java.util.Optional;

public interface IntakeJpaRepository extends JpaRepository<Intake, Long> {

    @Query("SELECT i FROM Intake i WHERE i.userId = :userId AND i.scheduledTime >= :from AND i.scheduledTime < :to")
    List<Intake> findByUserIdBetween(
            @Param("userId") Long userId,
            @Param("from") LocalDateTime from,
            @Param("to") LocalDateTime to);

    @Query("SELECT i FROM Intake i WHERE i.status IN :statuses AND i.windowEndTime < :now")
    List<Intake> findExpiredPendingIntakes(
            @Param("now") LocalDateTime now,
            @Param("statuses") List<IntakeStatus> statuses);

    List<Intake> findByStatusAndDispensedTimeBefore(IntakeStatus status, LocalDateTime dispensedTimeBefore);

    @Query("SELECT COUNT(i) FROM Intake i WHERE i.userId = :userId AND i.status = :status AND i.scheduledTime >= :since")
    long countTakenSince(
            @Param("userId") Long userId,
            @Param("status") IntakeStatus status,
            @Param("since") LocalDateTime since);

    Optional<Intake> findByUserIdAndTimingAndScheduledDate(Long userId, Timing timing, LocalDate scheduledDate);

    List<Intake> findByUserIdAndStatusInOrderByScheduledTimeAsc(Long userId, Collection<IntakeStatus> statuses);

    /**
     * @Modifying (bulk UPDATE/DELETE) queries require an active read-write transaction to execute
     * at all — unlike save()/findById()/etc., which SimpleJpaRepository already wraps in its own
     * transaction, a custom @Query method on the repository interface gets none by default. Without
     * this @Transactional, calling this method throws TransactionRequiredException immediately
     * (never executes the UPDATE) — which is exactly what was silently breaking the physical-button
     * and take-now claim step. Deliberately scoped to just this one call, not the calling service
     * method, so it stays a short-lived transaction and never spans the WebSocket ACK wait in
     * IntakeOrchestrationService.
     */
    @Transactional
    @Modifying
    @Query("UPDATE Intake i SET i.status = :newStatus WHERE i.id = :id AND i.status IN :allowedFrom")
    int atomicUpdateStatus(
            @Param("id") Long id,
            @Param("allowedFrom") Collection<IntakeStatus> allowedFrom,
            @Param("newStatus") IntakeStatus newStatus);
}
