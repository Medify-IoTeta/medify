package medify.backend.api.notification;

import medify.backend.domain.model.NotificationLog;
import medify.backend.domain.model.NotificationType;
import medify.backend.domain.port.NotificationLogRepositoryPort;
import medify.backend.domain.port.NotificationPort;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Component;

import java.time.LocalDateTime;

@Component
public class NotificationAdapter implements NotificationPort {
    private static final Logger logger = LoggerFactory.getLogger(NotificationAdapter.class);

    public record PendingNotification(String message, Long intakeId, String timing) {}

    private static volatile PendingNotification pending = null;

    private final NotificationLogRepositoryPort notificationLogRepository;

    public NotificationAdapter(NotificationLogRepositoryPort notificationLogRepository) {
        this.notificationLogRepository = notificationLogRepository;
    }

    @Override
    public void send(String message, Long intakeId, String timing) {
        pending = new PendingNotification(message, intakeId, timing);
        logger.info("Notification queued: {} (intakeId={}, timing={})", message, intakeId, timing);

        NotificationLog log = new NotificationLog(null, 1L, intakeId, NotificationType.WINDOW_REMINDER, message, LocalDateTime.now(), "SENT");
        notificationLogRepository.save(log);
    }

    public static PendingNotification drain() {
        PendingNotification p = pending;
        pending = null;
        return p;
    }
}
