package medify.backend.domain.scheduler;

import medify.backend.domain.model.Intake;
import medify.backend.domain.model.IntakeSettings;
import medify.backend.domain.model.IntakeStatus;
import medify.backend.domain.model.Medicine;
import medify.backend.domain.model.Timing;
import medify.backend.domain.model.UserType;
import medify.backend.domain.port.IntakeRepositoryPort;
import medify.backend.domain.port.IntakeSettingsRepositoryPort;
import medify.backend.domain.port.MedicineRepositoryPort;
import medify.backend.domain.port.NotificationPort;
import medify.backend.domain.port.UserRepositoryPort;
import jakarta.annotation.PostConstruct;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.scheduling.TaskScheduler;
import org.springframework.stereotype.Component;
import java.time.Duration;
import java.time.Instant;
import java.time.LocalDateTime;
import java.time.LocalTime;
import java.time.ZonedDateTime;
import java.util.List;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.ScheduledFuture;

@Component
public class ReminderScheduler {
    private static final Logger logger = LoggerFactory.getLogger(ReminderScheduler.class);
    private final MedicineRepositoryPort medicineRepository;
    private final IntakeRepositoryPort intakeRepository;
    private final NotificationPort notificationPort;
    private final UserRepositoryPort userRepository;
    private final IntakeSettingsRepositoryPort intakeSettingsRepository;
    private final TaskScheduler taskScheduler;
    private final Map<Timing, ScheduledFuture<?>> scheduledTasks = new ConcurrentHashMap<>();

    public ReminderScheduler(MedicineRepositoryPort medicineRepository,
                             IntakeRepositoryPort intakeRepository,
                             NotificationPort notificationPort,
                             UserRepositoryPort userRepository,
                             IntakeSettingsRepositoryPort intakeSettingsRepository,
                             TaskScheduler taskScheduler) {
        this.medicineRepository = medicineRepository;
        this.intakeRepository = intakeRepository;
        this.notificationPort = notificationPort;
        this.userRepository = userRepository;
        this.intakeSettingsRepository = intakeSettingsRepository;
        this.taskScheduler = taskScheduler;
    }

    @PostConstruct
    public void init() {
        rescheduleAll();
    }

    /** Re-reads intake_settings and re-queues all three reminder triggers — called on startup and whenever settings are saved. */
    public void rescheduleAll() {
        for (Timing timing : Timing.values()) {
            reschedule(timing);
        }
    }

    private void reschedule(Timing timing) {
        ScheduledFuture<?> existing = scheduledTasks.get(timing);
        if (existing != null) {
            existing.cancel(false);
        }
        ScheduledFuture<?> future = taskScheduler.schedule(
                () -> sendReminder(timing),
                triggerContext -> nextExecutionInstant(timing));
        scheduledTasks.put(timing, future);
    }

    private Instant nextExecutionInstant(Timing timing) {
        IntakeSettings settings = intakeSettingsRepository.getSettings();
        if (settings == null) {
            logger.warn("No intake settings row found — retrying reminder scheduling in 1 minute");
            return Instant.now().plusSeconds(60);
        }
        LocalTime configured = settings.timeFor(timing);
        ZonedDateTime now = ZonedDateTime.now();
        ZonedDateTime next = now.with(configured);
        if (!next.isAfter(now)) {
            next = next.plusDays(1);
        }
        return next.toInstant();
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
