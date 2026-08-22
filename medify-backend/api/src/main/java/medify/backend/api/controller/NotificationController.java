package medify.backend.api.controller;

import medify.backend.api.notification.NotificationAdapter;
import medify.backend.api.service.IntakeService;
import medify.backend.domain.model.Timing;
import medify.backend.domain.scheduler.ReminderScheduler;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.web.bind.annotation.*;
import java.util.HashMap;
import java.util.Map;

@RestController
@RequestMapping("/api/notification")
@CrossOrigin(origins = "*")
public class NotificationController {
    private static final Logger logger = LoggerFactory.getLogger(NotificationController.class);
    private final ReminderScheduler reminderScheduler;
    private final IntakeService intakeService;

    public NotificationController(ReminderScheduler reminderScheduler, IntakeService intakeService) {
        this.reminderScheduler = reminderScheduler;
        this.intakeService = intakeService;
    }

    @GetMapping
    public Map<String, Object> getNotification() {
        NotificationAdapter.PendingNotification pending = NotificationAdapter.drain();
        if (pending != null) {
            logger.info("Delivering notification to frontend: {} (intakeId={}, timing={})", pending.message(), pending.intakeId(), pending.timing());
            Map<String, Object> result = new HashMap<>();
            result.put("status", "OK");
            result.put("message", pending.message());
            result.put("intakeId", pending.intakeId());
            result.put("timing", pending.timing());
            result.put("type", pending.type().name());
            return result;
        }
        return Map.of("status", "EMPTY");
    }

    @PostMapping("/test")
    public Map<String, String> triggerTest() {
        reminderScheduler.sendReminder(Timing.MORNING);
        return Map.of("status", "OK");
    }

    @PostMapping
    public Map<String, String> receiveResponse(@RequestBody Map<String, Object> body) {
        String response = (String) body.get("message");
        Long intakeId = body.get("intakeId") != null
                ? ((Number) body.get("intakeId")).longValue()
                : null;

        logger.info("Received user response: {} (intakeId={})", response, intakeId);

        if (intakeId == null) {
            return Map.of("status", "OK");
        }

        if (response.equals("snooze_15")) {
            intakeService.postpone(intakeId);
            reminderScheduler.snoozeByIntakeId(intakeId, 15);
        } else if (response.startsWith("snooze_custom:")) {
            String[] parts = response.split(":");
            int hour = Integer.parseInt(parts[1]);
            int minute = Integer.parseInt(parts[2]);
            intakeService.postpone(intakeId);
            reminderScheduler.snoozeUntilByIntakeId(intakeId, hour, minute);
        } else if (response.equals("skip")) {
            intakeService.skip(intakeId);
        } else {
            logger.info("Intake {} confirmed by user", intakeId);
        }

        return Map.of("status", "OK");
    }
}
