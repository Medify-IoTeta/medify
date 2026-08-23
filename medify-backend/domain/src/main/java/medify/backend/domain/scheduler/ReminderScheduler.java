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
import java.time.LocalDate;
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
                () -> fireScheduledReminder(timing),
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

    // Used by snoozeByIntakeId/snoozeUntilByIntakeId — always creates a fresh
    // Intake, leaving the postponed one as a distinct historical record. Not
    // touched by the demo feature below.
    public void sendReminder(Timing timing) {
        dispatchReminder(timing, false, true);
    }

    // The actual daily scheduled firing (reschedule() below). Reuses today's
    // existing Intake for this timing if one is already there — normally a
    // no-op difference (there's nothing to reuse yet) but this is what keeps
    // a demo-reset row from being duplicated if the configured time is then
    // changed to make this fire again the same day.
    private void fireScheduledReminder(Timing timing) {
        dispatchReminder(timing, true, true);
    }

    // DEMO-ONLY: revert after exhibition — resets today's existing Intake for
    // this timing back to PENDING (reusing the row instead of accumulating a
    // new one each time), but does NOT send a notification. This only gives
    // the app a fresh state to replay the flow against; the actual reminder
    // is still fired the normal way (real schedule or adjusted intake_settings
    // times), which is why fireScheduledReminder above reuses this same row
    // instead of creating a competing second one.
    public void resetIntakeForDemo(Timing timing) {
        dispatchReminder(timing, true, false);
    }

    private void dispatchReminder(Timing timing, boolean reuseTodaysIntake, boolean notify) {
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
        Intake intake = null;
        if (reuseTodaysIntake) {
            LocalDateTime startOfDay = LocalDate.now().atStartOfDay();
            LocalDateTime endOfDay = LocalDate.now().atTime(LocalTime.MAX);
            intake = intakeRepository.findByUserIdBetween(patientId, startOfDay, endOfDay).stream()
                    .filter(i -> i.getTiming() == timing)
                    .findFirst()
                    .orElse(null);
        }
        if (intake == null) {
            intake = new Intake();
            intake.setUserId(patientId);
            intake.setTiming(timing);
        } else {
            intake.setApprovedTime(null);
            intake.setDispensedTime(null);
            intake.setReleasedTime(null);
            intake.setDeviceId(null);
        }
        intake.setWindowStartTime(now);
        intake.setWindowEndTime(now.plusHours(1));
        intake.setStatus(IntakeStatus.PENDING);
        Intake saved = intakeRepository.save(intake);

        String timingLabel = timing.name().charAt(0) + timing.name().substring(1).toLowerCase();
        if (notify) {
            logger.info("Sending {} reminder for: {}, intake id={}", timing, names, saved.getId());
            notificationPort.send("Time to take your " + timingLabel + " medicines", saved.getId(), timing.name());
        } else {
            logger.info("Reset {} intake to PENDING for demo, intake id={}", timing, saved.getId());
        }
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
