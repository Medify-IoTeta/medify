package medify.backend.data.repository;

import medify.backend.domain.model.NotificationLog;
import medify.backend.domain.port.NotificationLogRepositoryPort;
import org.springframework.stereotype.Repository;
import java.time.LocalDateTime;
import java.util.List;

@Repository
public class NotificationLogRepository implements NotificationLogRepositoryPort {

    private final NotificationLogJpaRepository jpaRepository;

    public NotificationLogRepository(NotificationLogJpaRepository jpaRepository) {
        this.jpaRepository = jpaRepository;
    }

    @Override
    public NotificationLog save(NotificationLog log) {
        return jpaRepository.save(log);
    }

    @Override
    public List<NotificationLog> findByRecipientUserIdBetween(Long userId, LocalDateTime from, LocalDateTime to) {
        return jpaRepository.findByRecipientUserIdBetween(userId, from, to);
    }
}
