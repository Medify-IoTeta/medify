package medify.backend.data.repository;

import medify.backend.domain.model.BoxRefillSession;
import medify.backend.domain.port.BoxRefillSessionRepositoryPort;
import org.springframework.stereotype.Repository;
import java.util.Optional;

@Repository
public class BoxRefillSessionRepository implements BoxRefillSessionRepositoryPort {

    private final BoxRefillSessionJpaRepository jpaRepository;

    public BoxRefillSessionRepository(BoxRefillSessionJpaRepository jpaRepository) {
        this.jpaRepository = jpaRepository;
    }

    @Override
    public BoxRefillSession save(BoxRefillSession session) {
        return jpaRepository.save(session);
    }

    @Override
    public Optional<BoxRefillSession> findActiveByUserId(Long userId) {
        return jpaRepository.findByUserIdAndActiveTrue(userId);
    }

    @Override
    public void deactivateAllByUserId(Long userId) {
        jpaRepository.deactivateAllByUserId(userId);
    }
}
