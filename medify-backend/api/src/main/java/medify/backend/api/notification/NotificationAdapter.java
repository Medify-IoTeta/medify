package medify.backend.api.notification;

import com.google.firebase.FirebaseApp;
import com.google.firebase.messaging.FirebaseMessaging;
import com.google.firebase.messaging.FirebaseMessagingException;
import com.google.firebase.messaging.Message;
import com.google.firebase.messaging.Notification;
import medify.backend.domain.model.NotificationLog;
import medify.backend.domain.model.NotificationType;
import medify.backend.domain.model.UserType;
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

    public record PendingNotification(String message, Long intakeId, String timing, NotificationType type) {}

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
        pending = new PendingNotification(message, intakeId, timing, NotificationType.WINDOW_REMINDER);
        logger.info("Notification queued: {} (intakeId={}, timing={})", message, intakeId, timing);

        userRepository.findFirstByType(UserType.PATIENT).ifPresent(patient -> {
            NotificationLog log = new NotificationLog(null, patient.getId(), intakeId, NotificationType.WINDOW_REMINDER, message, LocalDateTime.now(), "SENT");
            notificationLogRepository.save(log);

            if (patient.getFcmToken() != null) {
                sendPushNotification(patient.getFcmToken(), message, intakeId, timing);
            }
        });
    }

    @Override
    public void sendButtonPressed(Long userId) {
        String message = "Physical button pressed on the pill box";
        pending = new PendingNotification(message, null, null, NotificationType.BUTTON_PRESSED);
        logger.info("Button-pressed notification queued for user {}", userId);

        NotificationLog log = new NotificationLog(null, userId, null, NotificationType.BUTTON_PRESSED, message, LocalDateTime.now(), "SENT");
        notificationLogRepository.save(log);

        userRepository.findById(userId).ifPresent(user -> {
            if (user.getFcmToken() != null) {
                sendPushNotification(user.getFcmToken(), message, null, null);
            }
        });
    }

    private void sendPushNotification(String fcmToken, String body, Long intakeId, String timing) {
        Message.Builder builder = Message.builder()
                .setToken(fcmToken)
                .setNotification(Notification.builder()
                        .setTitle("Medify")
                        .setBody(body)
                        .build())
                .putData("intakeId", String.valueOf(intakeId));
        if (timing != null) {
            builder.putData("timing", timing);
        }
        try {
            String response = FirebaseMessaging.getInstance(firebaseApp).send(builder.build());
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
