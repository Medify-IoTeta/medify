package medify.backend.domain.scheduler;

import medify.backend.domain.model.Intake;
import medify.backend.domain.model.IntakeChronology;
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
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.scheduling.TaskScheduler;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;
import java.time.Instant;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.ZoneId;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.ScheduledFuture;

/**
 * Owns two related but distinct jobs, both driven by IntakeSettings (reminder times +
 * earlyWindowMinutes) rather than any hard-coded schedule:
 *
 * 1. Creating the PENDING Intake for a scheduled occurrence once its early window begins
 *    (see reconcileTiming/createIntakeForOccurrence) — not at the scheduled instant itself.
 * 2. Deciding, once the scheduled instant is actually reached, whether the normal "time to
 *    take your medicines" reminder should still fire (see maybeSendScheduledReminder) — it must
 *    NOT fire if the intake already progressed via early intake, is postponed (its own timer
 *    owns that), or was skipped.
 *
 * A single lightweight periodic sweep (tick) replaces the previous per-timing dynamic single-shot
 * TaskScheduler rescheduling — settings changes are picked up on the next tick, and
 * IntakeSettingsService also calls reconcileNow() synchronously so a change takes effect
 * immediately rather than waiting up to one tick interval.
 */
@Component
public class ReminderScheduler {
    private static final Logger logger = LoggerFactory.getLogger(ReminderScheduler.class);
    private static final long TICK_INTERVAL_MS = 30_000;

    private final MedicineRepositoryPort medicineRepository;
    private final IntakeRepositoryPort intakeRepository;
    private final NotificationPort notificationPort;
    private final UserRepositoryPort userRepository;
    private final IntakeSettingsRepositoryPort intakeSettingsRepository;
    private final TaskScheduler taskScheduler;

    /** intakeId -> pending single-shot re-notification for a POSTPONED intake. */
    private final Map<Long, ScheduledFuture<?>> postponeTimers = new ConcurrentHashMap<>();

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
        reconcileNow();
    }

    @Scheduled(fixedRate = TICK_INTERVAL_MS)
    public void tick() {
        reconcileNow();
    }

    /**
     * Runs both jobs for every timing window right now. Called by the periodic tick, on startup,
     * and synchronously by IntakeSettingsService whenever reminder times or earlyWindowMinutes
     * change, so a setting change that makes a dose's early window "already active" takes effect
     * immediately rather than on the next tick.
     */
    public void reconcileNow() {
        for (Timing timing : Timing.values()) {
            try {
                reconcileTiming(timing);
            } catch (Exception e) {
                logger.error("Reminder reconciliation failed for {}: {}", timing, e.getMessage(), e);
            }
        }
    }

    // Package-private (not private) so tests can drive these directly with controlled inputs —
    // there's no injected Clock in this codebase, and maybeSendScheduledReminder's `now` parameter
    // is the one deterministic seam available without adding one.
    void reconcileTiming(Timing timing) {
        List<Medicine> medicines = medicineRepository.findByTiming(timing);
        if (medicines.isEmpty()) {
            return;
        }

        Long patientId = userRepository.findFirstByType(UserType.PATIENT)
                .map(user -> user.getId())
                .orElse(null);
        if (patientId == null) {
            return;
        }

        IntakeSettings settings = intakeSettingsRepository.getSettings();
        if (settings == null) {
            logger.warn("No intake settings row found — skipping reconciliation for {}", timing);
            return;
        }

        LocalDateTime now = LocalDateTime.now();
        LocalDateTime todayOccurrence = LocalDate.now().atTime(settings.timeFor(timing));

        Optional<Intake> existing = intakeRepository.findByUserIdAndTimingAndScheduledDate(
                patientId, timing, todayOccurrence.toLocalDate());

        if (existing.isEmpty()) {
            LocalDateTime earlyWindowStart = todayOccurrence.minusMinutes(settings.getEarlyWindowMinutes());
            if (!now.isBefore(earlyWindowStart)) {
                createIntakeForOccurrence(patientId, timing, todayOccurrence);
            }
            return;
        }

        Intake intake = existing.get();
        reconcileScheduledTimeIfUntouched(intake, todayOccurrence);
        maybeSendScheduledReminder(intake, now);
    }

    /**
     * If the reminder time for this timing is edited while today's occurrence is still an
     * untouched PENDING intake, that row's scheduledTime/windowEndTime must move with it —
     * otherwise it would silently keep referring to the old time forever. Once the intake has
     * progressed (any status other than PENDING) or its scheduled-time reminder has already been
     * evaluated, it is historical and must never be rewritten by a later schedule edit.
     */
    void reconcileScheduledTimeIfUntouched(Intake intake, LocalDateTime currentlyConfiguredTime) {
        if (intake.getStatus() != IntakeStatus.PENDING || intake.getReminderEvaluatedAt() != null) {
            return;
        }
        if (intake.getScheduledTime().equals(currentlyConfiguredTime)) {
            return;
        }
        logger.info("Reconciling intake {} scheduledTime {} -> {} (reminder time changed)",
                intake.getId(), intake.getScheduledTime(), currentlyConfiguredTime);
        intake.setScheduledTime(currentlyConfiguredTime);
        intake.setWindowEndTime(currentlyConfiguredTime.plusHours(1));
        intakeRepository.save(intake);
    }

    void createIntakeForOccurrence(Long patientId, Timing timing, LocalDateTime scheduledTime) {
        try {
            Intake intake = new Intake();
            intake.setUserId(patientId);
            intake.setTiming(timing);
            intake.setScheduledTime(scheduledTime);
            intake.setScheduledDate(scheduledTime.toLocalDate());
            intake.setWindowStartTime(LocalDateTime.now());
            intake.setWindowEndTime(scheduledTime.plusHours(1));
            intake.setStatus(IntakeStatus.PENDING);
            Intake saved = intakeRepository.save(intake);
            logger.info("Created PENDING intake {} for {} occurrence at {}", saved.getId(), timing, scheduledTime);
        } catch (DataIntegrityViolationException e) {
            // Another tick (or a settings-change reconcile racing the periodic one) already
            // created this occurrence's row — the DB unique constraint is the final word here.
            logger.debug("Intake for {} {} already exists, skipping duplicate creation", timing, scheduledTime.toLocalDate());
        }
    }

    void maybeSendScheduledReminder(Intake intake, LocalDateTime now) {
        if (intake.getReminderEvaluatedAt() != null) {
            return; // permanently decided (sent, or suppressed because this intake itself moved on)
        }
        if (now.isBefore(intake.getScheduledTime())) {
            return; // early-window intake exists, but its scheduled instant hasn't arrived yet
        }

        if (intake.getStatus() != IntakeStatus.PENDING) {
            // Already progressed via early intake (APPROVED/DISPENSING/DISPENSED/TAKEN/INCOMPLETE),
            // or resolved (SKIPPED), or POSTPONED (its own timer owns re-notifying). In every one
            // of these cases the normal "time to take your medicines" reminder must not fire —
            // for DISPENSED/INCOMPLETE in particular, a normal reminder could read as "safe to
            // dispense again" which is exactly what must never happen while pills already sit in
            // the compartment. This is a permanent decision: once this intake itself is off PENDING,
            // there's no scenario where it goes back to "awaiting its normal reminder".
            intake.setReminderEvaluatedAt(now);
            intakeRepository.save(intake);
            logger.info("Suppressing scheduled reminder for intake {} — already {}", intake.getId(), intake.getStatus());
            return;
        }

        // Still genuinely untouched PENDING and its scheduled time has arrived — but a
        // chronologically earlier intake may still be unresolved (the same rule
        // IntakeOrchestrationService enforces at dispense time). Unlike the branch above, this is
        // NOT permanent: reminderEvaluatedAt is deliberately left null so that once the blocker
        // clears, this intake becomes normally remindable again on a later tick.
        Optional<Intake> blocking = findEarlierUnresolvedIntake(intake);
        if (blocking.isPresent()) {
            notifyBlockedIfChanged(intake, blocking.get());
            return;
        }

        intake.setReminderEvaluatedAt(now);
        intakeRepository.save(intake);
        notificationPort.send("Time to take your " + label(intake.getTiming()) + " medicines",
                intake.getId(), intake.getTiming().name());
        logger.info("Sent scheduled reminder for intake {} ({})", intake.getId(), intake.getTiming());
    }

    /** Same primitive IntakeOrchestrationService uses at dispense time: is anything chronologically earlier for this user still unresolved? */
    private Optional<Intake> findEarlierUnresolvedIntake(Intake intake) {
        List<Intake> unresolved = intakeRepository.findUnresolvedOrderByScheduledTimeAsc(intake.getUserId(), IntakeStatus.UNRESOLVED);
        return IntakeChronology.findEarlierUnresolved(unresolved, intake.getId());
    }

    /**
     * Sends a BLOCKED_REMINDER notification explaining why intake's normal reminder is being
     * withheld — but only if the blocking intake (or its status) differs from the last time we
     * notified about this, so a 30s reconcile tick doesn't resend an identical notification while
     * the same blocker remains unresolved in the same state.
     */
    private void notifyBlockedIfChanged(Intake intake, Intake blocking) {
        boolean alreadyNotifiedForThisExactSituation =
                blocking.getId().equals(intake.getBlockedNotifiedIntakeId())
                        && blocking.getStatus() == intake.getBlockedNotifiedStatus();
        if (alreadyNotifiedForThisExactSituation) {
            return;
        }

        intake.setBlockedNotifiedIntakeId(blocking.getId());
        intake.setBlockedNotifiedStatus(blocking.getStatus());
        intakeRepository.save(intake);

        String message = blockedReminderMessage(blocking.getStatus());
        notificationPort.sendBlockedReminder(message, intake.getId(), intake.getTiming().name());
        logger.info("Withheld scheduled reminder for intake {} — blocked by intake {} ({})",
                intake.getId(), blocking.getId(), blocking.getStatus());
    }

    private String blockedReminderMessage(IntakeStatus blockingStatus) {
        return switch (blockingStatus) {
            case MISSED -> "A previous dose was missed. Please complete that dose before this one becomes available.";
            case DISPENSED -> "Medication from a previous dose is still in the compartment. Remove it before this dose can continue.";
            case INCOMPLETE -> "A previous intake wasn't confirmed taken and must be resolved before this dose can continue.";
            case DISPENSING -> "A previous dose is currently being dispensed — this one will wait until that finishes.";
            case PENDING, APPROVED, POSTPONED -> "A previous dose needs your attention before this one becomes available.";
            default -> "A previous dose must be resolved before this one becomes available.";
        };
    }

    /**
     * Manual/dev trigger only (POST /api/notification/test). Bypasses early-window timing and
     * reminder suppression on purpose. Reuses today's occurrence if one already exists instead of
     * creating a second row, so it can't violate the one-intake-per-occurrence rule.
     */
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

        LocalDateTime now = LocalDateTime.now();
        Intake intake = intakeRepository.findByUserIdAndTimingAndScheduledDate(patientId, timing, now.toLocalDate())
                .orElseGet(() -> {
                    Intake fresh = new Intake();
                    fresh.setUserId(patientId);
                    fresh.setTiming(timing);
                    fresh.setScheduledTime(now);
                    fresh.setScheduledDate(now.toLocalDate());
                    fresh.setWindowStartTime(now);
                    fresh.setWindowEndTime(now.plusHours(1));
                    fresh.setStatus(IntakeStatus.PENDING);
                    return intakeRepository.save(fresh);
                });

        logger.info("Manually triggered {} reminder, intake id={}", timing, intake.getId());
        notificationPort.send("Time to take your " + label(timing) + " medicines", intake.getId(), timing.name());
    }

    // ── Postpone re-notification (replaces the old Thread.sleep-based snooze) ──────

    /**
     * Schedules a one-shot re-notification for a POSTPONED intake at `at`. Safe by construction
     * against stale firing: firePostponedReminder re-checks the intake's live status immediately
     * before notifying, so if the user takes it (via Take Now, from either the app or the physical
     * button) before the timer fires, this becomes a no-op instead of a duplicate/incorrect reminder.
     */
    public void schedulePostponeReminder(Long intakeId, LocalDateTime at) {
        cancelPostponeReminder(intakeId);
        Instant instant = at.atZone(ZoneId.systemDefault()).toInstant();
        ScheduledFuture<?> future = taskScheduler.schedule(() -> firePostponedReminder(intakeId), instant);
        postponeTimers.put(intakeId, future);
    }

    /** Cancels a pending postpone timer, if any. Called as soon as the intake starts progressing. */
    public void cancelPostponeReminder(Long intakeId) {
        ScheduledFuture<?> future = postponeTimers.remove(intakeId);
        if (future != null) {
            future.cancel(false);
        }
    }

    private void firePostponedReminder(Long intakeId) {
        postponeTimers.remove(intakeId);
        intakeRepository.findById(intakeId).ifPresent(intake -> {
            if (intake.getStatus() != IntakeStatus.POSTPONED) {
                logger.info("Stale postpone timer for intake {} — status is now {}, no-op", intakeId, intake.getStatus());
                return;
            }
            notificationPort.send("Time to take your " + label(intake.getTiming()) + " medicines",
                    intake.getId(), intake.getTiming().name());
            logger.info("Re-sent postponed reminder for intake {}", intakeId);
        });
    }

    private String label(Timing timing) {
        return timing.name().charAt(0) + timing.name().substring(1).toLowerCase();
    }
}
