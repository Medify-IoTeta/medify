package medify.backend.domain.scheduler;

import medify.backend.domain.model.Intake;
import medify.backend.domain.model.IntakeStatus;
import medify.backend.domain.model.Medicine;
import medify.backend.domain.model.Timing;
import medify.backend.domain.model.UserType;
import medify.backend.domain.port.IntakeRepositoryPort;
import medify.backend.domain.port.MedicineRepositoryPort;
import medify.backend.domain.port.NotificationPort;
import medify.backend.domain.port.UserRepositoryPort;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;
import java.time.LocalDateTime;
import java.time.LocalTime;
import java.time.Duration;
import java.util.List;

@Component
public class ReminderScheduler {
    private static final Logger logger = LoggerFactory.getLogger(ReminderScheduler.class);
    private final MedicineRepositoryPort medicineRepository;
    private final IntakeRepositoryPort intakeRepository;
    private final NotificationPort notificationPort;
    private final UserRepositoryPort userRepository;

    public ReminderScheduler(MedicineRepositoryPort medicineRepository,
                             IntakeRepositoryPort intakeRepository,
                             NotificationPort notificationPort,
                             UserRepositoryPort userRepository) {
        this.medicineRepository = medicineRepository;
        this.intakeRepository = intakeRepository;
        this.notificationPort = notificationPort;
        this.userRepository = userRepository;
    }

    @Scheduled(cron = "0 49 19 * * *")
    public void sendMorningReminder() {
        sendReminder(Timing.MORNING);
    }

    @Scheduled(cron = "0 46 19 * * *")
    public void sendNoonReminder() {
        sendReminder(Timing.NOON);
    }

    @Scheduled(cron = "0 48 19 * * *")
    public void sendEveningReminder() {
        sendReminder(Timing.EVENING);
    }

    public void sendReminder(Timing timing) {
        List<Medicine> medicines = medicineRepository.findByTiming(timing);
        if (medicines.isEmpty()) {
            logger.info("No medicines scheduled for {}", timing);
            return;
        }

        Long patientId = userRepository.findFirstByType(UserType.PATIENT)
                .map(user -> user.getId())
                .orElse(null);
        if (patientId == null) {
            logger.warn("No registered patient — skipping {} reminder", timing);
            return;
        }

        String names = medicines.stream()
                .map(Medicine::getName)
                .reduce((a, b) -> a + ", " + b)
                .orElse("");

        LocalDateTime now = LocalDateTime.now();
        Intake intake = new Intake();
        intake.setUserId(patientId);
        intake.setTiming(timing);
        intake.setWindowStartTime(now);
        intake.setWindowEndTime(now.plusHours(1));
        intake.setStatus(IntakeStatus.PENDING);
        Intake saved = intakeRepository.save(intake);

        String timingLabel = timing.name().charAt(0) + timing.name().substring(1).toLowerCase();
        logger.info("Sending {} reminder for: {}, intake id={}", timing, names, saved.getId());
        notificationPort.send("Time to take your " + timingLabel + " medicines", saved.getId(), timing.name());
    }

    public void snoozeByIntakeId(Long intakeId, int minutes) {
        intakeRepository.findById(intakeId).ifPresent(intake -> {
            new Thread(() -> {
                try {
                    logger.info("Snoozing intake {} for {} minutes", intakeId, minutes);
                    Thread.sleep((long) minutes * 60 * 1000);
                    sendReminder(intake.getTiming());
                } catch (InterruptedException e) {
                    Thread.currentThread().interrupt();
                }
            }).start();
        });
    }

    public void snoozeUntilByIntakeId(Long intakeId, int hour, int minute) {
        intakeRepository.findById(intakeId).ifPresent(intake -> {
            new Thread(() -> {
                try {
                    LocalTime target = LocalTime.of(hour, minute);
                    long seconds = Duration.between(LocalTime.now(), target).getSeconds();
                    if (seconds > 0) {
                        logger.info("Snoozing intake {} until {}:{}", intakeId, hour, minute);
                        Thread.sleep(seconds * 1000);
                        sendReminder(intake.getTiming());
                    }
                } catch (Exception e) {
                    Thread.currentThread().interrupt();
                }
            }).start();
        });
    }
}
