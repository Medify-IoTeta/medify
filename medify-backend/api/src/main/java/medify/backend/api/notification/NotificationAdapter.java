package medify.backend.api.notification;

import com.google.firebase.FirebaseApp;
import com.google.firebase.messaging.FirebaseMessaging;
import com.google.firebase.messaging.FirebaseMessagingException;
import com.google.firebase.messaging.Message;
import com.google.firebase.messaging.Notification;
import medify.backend.domain.model.NotificationLog;
import medify.backend.domain.model.NotificationType;
import medify.backend.domain.port.NotificationLogRepositoryPort;
import medify.backend.domain.port.NotificationPort;
import medify.backend.domain.port.UserRepositoryPort;
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
    private final UserRepositoryPort userRepository;
    private final FirebaseApp firebaseApp;

    public NotificationAdapter(NotificationLogRepositoryPort notificationLogRepository,
                               UserRepositoryPort userRepository,
                               FirebaseApp firebaseApp) {
        this.notificationLogRepository = notificationLogRepository;
        this.userRepository = userRepository;
        this.firebaseApp = firebaseApp;
    }

    @Override
    public void send(String message, Long intakeId, String timing) {
        pending = new PendingNotification(message, intakeId, timing);
        logger.info("Notification queued: {} (intakeId={}, timing={})", message, intakeId, timing);

        NotificationLog log = new NotificationLog(null, 1L, intakeId, NotificationType.WINDOW_REMINDER, message, LocalDateTime.now(), "SENT");
        notificationLogRepository.save(log);

        userRepository.findById(1L).ifPresent(user -> {
            if (user.getFcmToken() != null) {
                sendPushNotification(user.getFcmToken(), message, intakeId, timing);
            }
        });
    }

    private void sendPushNotification(String fcmToken, String body, Long intakeId, String timing) {
        Message fcmMessage = Message.builder()
                .setToken(fcmToken)
                .setNotification(Notification.builder()
                        .setTitle("Medify")
                        .setBody(body)
                        .build())
                .putData("intakeId", String.valueOf(intakeId))
                .putData("timing", timing)
                .build();
        try {
            String response = FirebaseMessaging.getInstance(firebaseApp).send(fcmMessage);
            logger.info("FCM push sent: {}", response);
        } catch (FirebaseMessagingException e) {
            logger.error("FCM push failed: {}", e.getMessage());
        }
    }

    public static PendingNotification drain() {
        PendingNotification p = pending;
        pending = null;
        return p;
    }
}
