package medify.backend.domain.port;

import medify.backend.domain.model.NotificationLog;
import java.time.LocalDateTime;
import java.util.List;

public interface NotificationLogRepositoryPort {
    NotificationLog save(NotificationLog log);
    List<NotificationLog> findByRecipientUserIdBetween(Long userId, LocalDateTime from, LocalDateTime to);
}
