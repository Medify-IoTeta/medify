package medify.backend.data.repository;

import medify.backend.domain.model.Intake;
import medify.backend.domain.model.IntakeStatus;
import medify.backend.domain.model.Timing;
import medify.backend.domain.port.IntakeRepositoryPort;
import org.springframework.stereotype.Repository;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.Collection;
import java.util.List;
import java.util.Optional;

@Repository
public class IntakeRepository implements IntakeRepositoryPort {

    private final IntakeJpaRepository jpaRepository;

    public IntakeRepository(IntakeJpaRepository jpaRepository) {
        this.jpaRepository = jpaRepository;
    }

    @Override
    public Intake save(Intake intake) {
        return jpaRepository.save(intake);
    }

    @Override
    public Optional<Intake> findById(Long id) {
        return jpaRepository.findById(id);
    }

    @Override
    public List<Intake> findByUserIdBetween(Long userId, LocalDateTime from, LocalDateTime to) {
        return jpaRepository.findByUserIdBetween(userId, from, to);
    }

    @Override
    public List<Intake> findExpiredPendingIntakes(LocalDateTime now) {
        // PENDING/APPROVED/POSTPONED are all "unresolved and still in the original flow" — any of
        // them still sitting unresolved once the window ends counts as missed.
        return jpaRepository.findExpiredPendingIntakes(now,
                List.of(IntakeStatus.PENDING, IntakeStatus.APPROVED, IntakeStatus.POSTPONED));
    }

    @Override
    public List<Intake> findByStatusAndDispensedTimeBefore(IntakeStatus status, LocalDateTime cutoff) {
        return jpaRepository.findByStatusAndDispensedTimeBefore(status, cutoff);
    }

    @Override
    public long countTakenSince(Long userId, IntakeStatus status, LocalDateTime since) {
        return jpaRepository.countTakenSince(userId, status, since);
    }

    @Override
    public Optional<Intake> findByUserIdAndTimingAndScheduledDate(Long userId, Timing timing, LocalDate scheduledDate) {
        return jpaRepository.findByUserIdAndTimingAndScheduledDate(userId, timing, scheduledDate);
    }

    @Override
    public List<Intake> findUnresolvedOrderByScheduledTimeAsc(Long userId, Collection<IntakeStatus> unresolvedStatuses) {
        return jpaRepository.findByUserIdAndStatusInOrderByScheduledTimeAsc(userId, unresolvedStatuses);
    }

    @Override
    public boolean tryTransition(Long id, Collection<IntakeStatus> allowedFrom, IntakeStatus newStatus) {
        return jpaRepository.atomicUpdateStatus(id, allowedFrom, newStatus) == 1;
    }
}
