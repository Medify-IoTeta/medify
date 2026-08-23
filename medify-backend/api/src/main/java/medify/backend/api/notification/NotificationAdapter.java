package medify.backend.api.notification;

import com.google.firebase.FirebaseApp;
import com.google.firebase.messaging.FirebaseMessaging;
import com.google.firebase.messaging.FirebaseMessagingException;
import com.google.firebase.messaging.Message;
import com.google.firebase.messaging.Notification;
import medify.backend.domain.model.IntakeActionResult;
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
import java.util.Queue;
import java.util.concurrent.ConcurrentLinkedQueue;

@Component
public class NotificationAdapter implements NotificationPort {
    private static final Logger logger = LoggerFactory.getLogger(NotificationAdapter.class);

    /**
     * outcome/blockingIntakeId are only populated for BUTTON_PRESSED notifications — they carry
     * the already-decided result of the physical button press (see
     * DeviceWebSocketHandler.handleButtonPressed) purely as information for the app to display.
     * The dispense decision has already happened by the time this reaches the app.
     */
    public record PendingNotification(String message, Long intakeId, String timing, NotificationType type,
                                       String outcome, Long blockingIntakeId) {}

    private static final Queue<PendingNotification> pending = new ConcurrentLinkedQueue<>();

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
        pending.add(new PendingNotification(message, intakeId, timing, NotificationType.WINDOW_REMINDER, null, null));
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
    public void sendButtonPressed(Long userId, IntakeActionResult result) {
        String message = messageFor(result);
        Long relevantIntakeId = result.intake() != null ? result.intake().getId()
                : result.blockingIntake() != null ? result.blockingIntake().getId() : null;
        Long blockingId = result.blockingIntake() != null ? result.blockingIntake().getId() : null;

        pending.add(new PendingNotification(message, relevantIntakeId, null, NotificationType.BUTTON_PRESSED,
                result.outcome().name(), blockingId));
        logger.info("Button-pressed notification queued for user {}: {} ({})", userId, result.outcome(), message);

        NotificationLog log = new NotificationLog(null, userId, relevantIntakeId, NotificationType.BUTTON_PRESSED, message, LocalDateTime.now(), "SENT");
        notificationLogRepository.save(log);

        userRepository.findById(userId).ifPresent(user -> {
            if (user.getFcmToken() != null) {
                sendPushNotification(user.getFcmToken(), message, relevantIntakeId, null);
            }
        });
    }

    @Override
    public void sendBlockedReminder(String message, Long intakeId, String timing) {
        pending.add(new PendingNotification(message, intakeId, timing, NotificationType.BLOCKED_REMINDER, null, null));
        logger.info("Blocked-reminder notification queued: {} (intakeId={}, timing={})", message, intakeId, timing);

        userRepository.findFirstByType(UserType.PATIENT).ifPresent(patient -> {
            NotificationLog log = new NotificationLog(null, patient.getId(), intakeId, NotificationType.BLOCKED_REMINDER, message, LocalDateTime.now(), "SENT");
            notificationLogRepository.save(log);

            if (patient.getFcmToken() != null) {
                sendPushNotification(patient.getFcmToken(), message, intakeId, timing);
            }
        });
    }

    private String messageFor(IntakeActionResult result) {
        return switch (result.outcome()) {
            case STARTED -> "Physical button pressed — dispensing now.";
            case NOTHING_AVAILABLE -> "Physical button pressed, but nothing is currently available to take.";
            default -> "Physical button pressed — " + result.message();
        };
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
        return pending.poll();
    }
}
