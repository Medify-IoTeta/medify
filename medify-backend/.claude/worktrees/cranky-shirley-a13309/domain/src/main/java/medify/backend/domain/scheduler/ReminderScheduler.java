package medify.backend.domain.scheduler;

import medify.backend.domain.model.Medicine;
import medify.backend.domain.model.Timing;
import medify.backend.domain.port.MedicineRepositoryPort;
import medify.backend.domain.port.NotificationPort;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;
import java.util.List;

@Component
public class ReminderScheduler {
    private static final Logger logger = LoggerFactory.getLogger(ReminderScheduler.class);
    private final MedicineRepositoryPort medicineRepository;
    private final NotificationPort notificationPort;

    public ReminderScheduler(MedicineRepositoryPort medicineRepository, NotificationPort notificationPort) {
        this.medicineRepository = medicineRepository;
        this.notificationPort = notificationPort;
    }

    @Scheduled(cron = "0 0 8 * * *")
    public void sendMorningReminder() {
        sendReminder(Timing.MORNING);
    }

    @Scheduled(cron = "0 0 13 * * *")
    public void sendNoonReminder() {
        sendReminder(Timing.NOON);
    }

    @Scheduled(cron = "0 0 20 * * *")
    public void sendEveningReminder() {
        sendReminder(Timing.EVENING);
    }

    private void sendReminder(Timing timing) {
        List<Medicine> medicines = medicineRepository.findByTiming(timing);

        if (medicines.isEmpty()) {
            logger.info("No medicines scheduled for {}", timing);
            return;
        }

        String names = medicines.stream()
                .map(Medicine::getName)
                .reduce((a, b) -> a + ", " + b)
                .orElse("");

        logger.info("Sending reminder for {}: {}", timing, names);
        notificationPort.send("Time to take your medicines: " + names);
    }

    public void snooze(Timing timing, int minutes) {
        new Thread(() -> {
            try {
                logger.info("Snoozing {} reminder for {} minutes", timing, minutes);
                Thread.sleep((long) minutes * 60 * 1000);
                sendReminder(timing);
            } catch (InterruptedException e) {
                e.printStackTrace();
            }
        }).start();
    }

    public void snoozeUntil(Timing timing, int hour, int minute) {
        new Thread(() -> {
            try {
                java.time.LocalTime target = java.time.LocalTime.of(hour, minute);
                long secondsUntil = java.time.Duration.between(java.time.LocalTime.now(), target).getSeconds();
                if (secondsUntil > 0) {
                    logger.info("Snoozing {} reminder until {}:{}", timing, hour, minute);
                    Thread.sleep(secondsUntil * 1000);
                    sendReminder(timing);
                }
            } catch (Exception e) {
                e.printStackTrace();
            }
        }).start();
    }
}