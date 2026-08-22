package medify.backend.domain.port;

import medify.backend.domain.model.Intake;
import medify.backend.domain.model.IntakeStatus;
import java.time.LocalDateTime;
import java.util.List;
import java.util.Optional;

public interface IntakeRepositoryPort {
    Intake save(Intake intake);
    Optional<Intake> findById(Long id);
    List<Intake> findByUserIdBetween(Long userId, LocalDateTime from, LocalDateTime to);
    List<Intake> findExpiredPendingIntakes(LocalDateTime now);
    List<Intake> findByStatusAndDispensedTimeBefore(IntakeStatus status, LocalDateTime cutoff);
    long countTakenSince(Long userId, IntakeStatus status, LocalDateTime since);
}
