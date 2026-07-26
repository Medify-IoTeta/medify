package medify.backend.domain.port;

import medify.backend.domain.model.BoxRefillSession;
import java.util.Optional;

public interface BoxRefillSessionRepositoryPort {
    BoxRefillSession save(BoxRefillSession session);
    Optional<BoxRefillSession> findActiveByUserId(Long userId);
    void deactivateAllByUserId(Long userId);
}
