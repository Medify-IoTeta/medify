package medify.backend.api.notification;

import medify.backend.domain.port.NotificationPort;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Component;

@Component
public class NotificationAdapter implements NotificationPort {
    private static final Logger logger = LoggerFactory.getLogger(NotificationAdapter.class);

    public record PendingNotification(String message, Long intakeId, String timing) {}

    private static volatile PendingNotification pending = null;

    @Override
    public void send(String message, Long intakeId, String timing) {
        pending = new PendingNotification(message, intakeId, timing);
        logger.info("Notification queued: {} (intakeId={}, timing={})", message, intakeId, timing);
    }

    public static PendingNotification drain() {
        PendingNotification p = pending;
        pending = null;
        return p;
    }
}
