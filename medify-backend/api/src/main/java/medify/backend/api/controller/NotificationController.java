package medify.backend.api.controller;

import medify.backend.api.notification.NotificationAdapter;
import medify.backend.domain.model.Timing;
import medify.backend.domain.scheduler.ReminderScheduler;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.web.bind.annotation.*;
import java.util.Map;

@RestController
@RequestMapping("/api/notification")
@CrossOrigin(origins = "*")
public class NotificationController {
    private static final Logger logger = LoggerFactory.getLogger(NotificationController.class);
    private final ReminderScheduler reminderScheduler;

    public NotificationController(ReminderScheduler reminderScheduler) {
        this.reminderScheduler = reminderScheduler;
    }

    @GetMapping
    public Map<String, String> getNotification() {
        String message = NotificationAdapter.getPendingNotification();
        if (message != null) {
            logger.info("Delivering notification to frontend: {}", message);
            return Map.of("status", "OK", "message", message);
        }
        return Map.of("status", "EMPTY");
    }

    @PostMapping
    public Map<String, String> receiveResponse(@RequestBody Map<String, Object> body) {
        String response = (String) body.get("message");
        logger.info("Received user response: {}", response);

        if (response.equals("snooze_15")) {
            reminderScheduler.snooze(Timing.MORNING, 15); // temporary, timing should come from context
        } else if (response.startsWith("snooze_custom:")) {
            String[] parts = response.split(":");
            int hour = Integer.parseInt(parts[1]);
            int minute = Integer.parseInt(parts[2]);
            reminderScheduler.snoozeUntil(Timing.MORNING, hour, minute); // temporary
        } else {
            logger.info("Intake confirmed by user");
        }

        return Map.of("status", "OK");
    }
}