package medify.backend.data.repository;

import medify.backend.domain.model.Intake;
import medify.backend.domain.model.IntakeStatus;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import java.time.LocalDateTime;
import java.util.List;

public interface IntakeJpaRepository extends JpaRepository<Intake, Long> {

    @Query("SELECT i FROM Intake i WHERE i.userId = :userId AND i.windowStartTime >= :from AND i.windowStartTime < :to")
    List<Intake> findByUserIdBetween(
            @Param("userId") Long userId,
            @Param("from") LocalDateTime from,
            @Param("to") LocalDateTime to);

    @Query("SELECT i FROM Intake i WHERE i.status IN :statuses AND i.windowEndTime < :now")
    List<Intake> findExpiredPendingIntakes(
            @Param("now") LocalDateTime now,
            @Param("statuses") List<IntakeStatus> statuses);

    @Query("SELECT COUNT(i) FROM Intake i WHERE i.userId = :userId AND i.status = :status AND i.windowStartTime >= :since")
    long countTakenSince(
            @Param("userId") Long userId,
            @Param("status") IntakeStatus status,
            @Param("since") LocalDateTime since);
}
