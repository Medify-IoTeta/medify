package medify.backend.api.service;

import medify.backend.domain.model.NotificationLog;
import medify.backend.domain.port.NotificationLogRepositoryPort;
import org.springframework.stereotype.Service;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.LocalTime;
import java.util.List;

@Service
public class NotificationLogService {

    private final NotificationLogRepositoryPort repository;

    public NotificationLogService(NotificationLogRepositoryPort repository) {
        this.repository = repository;
    }

    public List<NotificationLog> getByUserIdAndRange(Long userId, LocalDateTime from, LocalDateTime to) {
        if (from == null) from = LocalDate.now().minusDays(30).atStartOfDay();
        if (to == null)   to   = LocalDate.now().atTime(LocalTime.MAX);
        return repository.findByRecipientUserIdBetween(userId, from, to);
    }
}
