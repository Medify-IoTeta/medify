package medify.backend.api.service;

import medify.backend.domain.model.Intake;
import medify.backend.domain.model.IntakeActionResult;
import medify.backend.domain.model.IntakeStatus;
import medify.backend.domain.port.IntakeRepositoryPort;
import medify.backend.domain.scheduler.ReminderScheduler;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.web.server.ResponseStatusException;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.LocalTime;
import java.util.EnumSet;
import java.util.List;
import java.util.Set;

/**
 * Individual status-mutation endpoints (approve/skip/postpone/missed) kept for compatibility and
 * direct single-step use, each now guarded by an explicit allowed-from-state set so a stray call
 * can no longer regress an intake that has already progressed (e.g. TAKEN -> SKIPPED).
 *
 * dispense() is a thin wrapper around IntakeOrchestrationService.requestIntakeNow — the exact
 * same shared eligibility/claim logic the physical button and the app's Take Now use — so this
 * legacy two-step (approve then dispense) endpoint pair can't bypass the earlier-unresolved-intake
 * rule that take-now enforces.
 */
@Service
public class IntakeService {
    private static final Logger logger = LoggerFactory.getLogger(IntakeService.class);

    private static final Set<IntakeStatus> APPROVE_ALLOWED_FROM = EnumSet.of(IntakeStatus.PENDING, IntakeStatus.MISSED, IntakeStatus.POSTPONED);
    private static final Set<IntakeStatus> SKIP_ALLOWED_FROM = EnumSet.of(IntakeStatus.PENDING, IntakeStatus.APPROVED, IntakeStatus.MISSED, IntakeStatus.POSTPONED);
    private static final Set<IntakeStatus> POSTPONE_ALLOWED_FROM = EnumSet.of(IntakeStatus.PENDING, IntakeStatus.APPROVED, IntakeStatus.MISSED, IntakeStatus.POSTPONED);
    private static final Set<IntakeStatus> MANUAL_MISSED_ALLOWED_FROM = EnumSet.of(IntakeStatus.PENDING, IntakeStatus.APPROVED, IntakeStatus.POSTPONED);

    private final IntakeRepositoryPort intakeRepository;
    private final IntakeOrchestrationService intakeOrchestrationService;
    private final ReminderScheduler reminderScheduler;

    public IntakeService(IntakeRepositoryPort intakeRepository,
                          IntakeOrchestrationService intakeOrchestrationService,
                          ReminderScheduler reminderScheduler) {
        this.intakeRepository = intakeRepository;
        this.intakeOrchestrationService = intakeOrchestrationService;
        this.reminderScheduler = reminderScheduler;
    }

    public Intake getById(Long id) {
        return findOrThrow(id);
    }

    public List<Intake> getByDateRange(Long userId, LocalDateTime from, LocalDateTime to) {
        return intakeRepository.findByUserIdBetween(userId, from, to);
    }

    public List<Intake> getToday(Long userId) {
        LocalDateTime startOfDay = LocalDate.now().atStartOfDay();
        LocalDateTime endOfDay = LocalDate.now().atTime(LocalTime.MAX);
        return intakeRepository.findByUserIdBetween(userId, startOfDay, endOfDay);
    }

    public Intake approve(Long id) {
        Intake intake = findOrThrow(id);
        assertTransitionAllowed(intake, APPROVE_ALLOWED_FROM, "approve");
        intake.setStatus(IntakeStatus.APPROVED);
        intake.setApprovedTime(LocalDateTime.now());
        return intakeRepository.save(intake);
    }

    /**
     * Legacy single-intake dispense path — delegates to the same shared start-intake logic the
     * physical button and the app's /take-now endpoint use, targeted explicitly at this intake, so
     * it's still subject to the earlier-unresolved-intake rule and the atomic dispensing claim.
     */
    public Intake dispense(Long id) {
        Intake intake = findOrThrow(id);
        IntakeActionResult result = intakeOrchestrationService.requestIntakeNow(intake.getUserId(), id);
        if (result.outcome() == IntakeActionResult.Outcome.STARTED) {
            return result.intake();
        }
        throw new ResponseStatusException(HttpStatus.CONFLICT, result.message());
    }

    /** Device reported the motor finished releasing the pills. Not TAKEN yet — that's IR-confirmed only. */
    public Intake markDispensed(Long id) {
        Intake intake = findOrThrow(id);
        if (intake.getStatus() != IntakeStatus.DISPENSING) {
            logger.warn("Ignoring 'dispensed' event for intake {}: status is {}, not DISPENSING", id, intake.getStatus());
            return intake;
        }
        intake.setStatus(IntakeStatus.DISPENSED);
        intake.setDispensedTime(LocalDateTime.now());
        return intakeRepository.save(intake);
    }

    /** Device's IR sensor confirmed the compartment is empty. This is the only path to TAKEN. */
    public Intake markTaken(Long id) {
        Intake intake = findOrThrow(id);
        if (intake.getStatus() != IntakeStatus.DISPENSED) {
            logger.warn("Ignoring 'intake_confirmed' event for intake {}: status is {}, not DISPENSED", id, intake.getStatus());
            return intake;
        }
        intake.setStatus(IntakeStatus.TAKEN);
        intake.setReleasedTime(LocalDateTime.now());
        reminderScheduler.cancelPostponeReminder(id);
        return intakeRepository.save(intake);
    }

    public Intake skip(Long id) {
        Intake intake = findOrThrow(id);
        assertTransitionAllowed(intake, SKIP_ALLOWED_FROM, "skip");
        intake.setStatus(IntakeStatus.SKIPPED);
        reminderScheduler.cancelPostponeReminder(id);
        return intakeRepository.save(intake);
    }

    /** Postpones for a relative number of minutes from now. */
    public Intake postpone(Long id, int minutes) {
        return postponeUntil(id, LocalDateTime.now().plusMinutes(minutes));
    }

    /** Postpones until a specific clock time (today, or tomorrow if that time has already passed). */
    public Intake postpone(Long id, LocalTime until) {
        LocalDateTime now = LocalDateTime.now();
        LocalDateTime target = now.toLocalDate().atTime(until);
        if (!target.isAfter(now)) {
            target = target.plusDays(1);
        }
        return postponeUntil(id, target);
    }

    private Intake postponeUntil(Long id, LocalDateTime until) {
        Intake intake = findOrThrow(id);
        assertTransitionAllowed(intake, POSTPONE_ALLOWED_FROM, "postpone");
        intake.setStatus(IntakeStatus.POSTPONED);
        intake.setPostponedAt(LocalDateTime.now());
        intake.setPostponedUntil(until);
        Intake saved = intakeRepository.save(intake);
        reminderScheduler.schedulePostponeReminder(id, until);
        return saved;
    }

    public Intake missed(Long id) {
        Intake intake = findOrThrow(id);
        assertTransitionAllowed(intake, MANUAL_MISSED_ALLOWED_FROM, "mark missed");
        intake.setStatus(IntakeStatus.MISSED);
        intake.setMissedAt(LocalDateTime.now());
        reminderScheduler.cancelPostponeReminder(id);
        return intakeRepository.save(intake);
    }

    private void assertTransitionAllowed(Intake intake, Set<IntakeStatus> allowedFrom, String action) {
        if (!allowedFrom.contains(intake.getStatus())) {
            throw new ResponseStatusException(HttpStatus.CONFLICT,
                    "Cannot " + action + " an intake that is " + intake.getStatus());
        }
    }

    private Intake findOrThrow(Long id) {
        return intakeRepository.findById(id)
                .orElseThrow(() -> new RuntimeException("Intake not found: " + id));
    }
}
