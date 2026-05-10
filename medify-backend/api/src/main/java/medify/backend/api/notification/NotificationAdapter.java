package medify.backend.api.notification;

import medify.backend.domain.port.NotificationPort;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Component;

@Component
public class NotificationAdapter implements NotificationPort {
    private static final Logger logger = LoggerFactory.getLogger(NotificationAdapter.class);
    private static String pendingNotification = null;

    @Override
    public void send(String message) {
        pendingNotification = message;
        logger.info("Notification queued: {}", message);
    }

    public static String getPendingNotification() {
        if (pendingNotification != null) {
            String message = pendingNotification;
            pendingNotification = null;
            return message;
        }
        return null;
    }
}