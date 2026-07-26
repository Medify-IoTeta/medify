package medify.backend.data.repository;

import medify.backend.domain.model.Intake;
import medify.backend.domain.model.IntakeStatus;
import medify.backend.domain.port.IntakeRepositoryPort;
import org.springframework.stereotype.Repository;
import java.time.LocalDateTime;
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
        return jpaRepository.findExpiredPendingIntakes(now, List.of(IntakeStatus.PENDING, IntakeStatus.APPROVED));
    }

    @Override
    public long countTakenSince(Long userId, IntakeStatus status, LocalDateTime since) {
        return jpaRepository.countTakenSince(userId, status, since);
    }
}
