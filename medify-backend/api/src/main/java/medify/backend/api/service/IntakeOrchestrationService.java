package medify.backend.api.service;

import medify.backend.domain.model.Device;
import medify.backend.domain.model.Intake;
import medify.backend.domain.model.IntakeActionResult;
import medify.backend.domain.model.IntakeChronology;
import medify.backend.domain.model.IntakeStatus;
import medify.backend.domain.port.DeviceConnectionPort;
import medify.backend.domain.port.DeviceRepositoryPort;
import medify.backend.domain.port.IntakeRepositoryPort;
import medify.backend.domain.scheduler.ReminderScheduler;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;
import java.time.LocalDateTime;
import java.util.List;
import java.util.Optional;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.locks.ReentrantLock;

/**
 * The single business operation behind "start or continue an intake now" — the physical button
 * and the app's Take Now both call {@link #requestIntakeNow}, and neither implements any
 * eligibility rule of its own. This is deliberate: per-client duplicated rules is exactly what
 * let the physical button silently depend on Flutter before this refactor.
 *
 * Core rule: a chronologically later intake may never start/progress while an earlier one is
 * still unresolved (IntakeStatus.UNRESOLVED). Concurrency: the eligibility decision is serialized
 * per user with an in-process lock (this deployment is one-patient-per-instance — see
 * medify-backend/CLAUDE.md — so a single JVM-local lock is sufficient; it would need to become a
 * DB-level lock if this service were ever run with more than one backend instance), and the actual
 * claim into DISPENSING is additionally an atomic conditional UPDATE
 * (IntakeRepositoryPort.tryTransition) so even a second caller that somehow bypassed the lock could
 * not also win the transition.
 */
@Service
public class IntakeOrchestrationService {
    private static final Logger logger = LoggerFactory.getLogger(IntakeOrchestrationService.class);

    private final IntakeRepositoryPort intakeRepository;
    private final DeviceRepositoryPort deviceRepository;
    private final DeviceConnectionPort deviceConnectionPort;
    private final ReminderScheduler reminderScheduler;

    private final ConcurrentHashMap<Long, ReentrantLock> userLocks = new ConcurrentHashMap<>();

    public IntakeOrchestrationService(IntakeRepositoryPort intakeRepository,
                                       DeviceRepositoryPort deviceRepository,
                                       DeviceConnectionPort deviceConnectionPort,
                                       ReminderScheduler reminderScheduler) {
        this.intakeRepository = intakeRepository;
        this.deviceRepository = deviceRepository;
        this.deviceConnectionPort = deviceConnectionPort;
        this.reminderScheduler = reminderScheduler;
    }

    /**
     * @param userId           the patient whose pill box this is
     * @param explicitIntakeId when non-null, the specific intake the caller wants to act on (e.g.
     *                         the app's "Take now" on a particular MISSED/POSTPONED card). When
     *                         null (always the case for the physical button, which has no concept
     *                         of a specific intake), the earliest unresolved intake is used.
     */
    public IntakeActionResult requestIntakeNow(Long userId, Long explicitIntakeId) {
        ReentrantLock lock = userLocks.computeIfAbsent(userId, id -> new ReentrantLock());
        lock.lock();
        try {
            return doRequestIntakeNow(userId, explicitIntakeId);
        } finally {
            lock.unlock();
        }
    }

    /** Read-only: what would happen right now, without acting. Used by callers that only need to know what's blocking, e.g. to render a "resolve this first" prompt. */
    public Optional<Intake> findBlockingEarlierIntake(Long userId, Long targetIntakeId) {
        List<Intake> unresolved = intakeRepository.findUnresolvedOrderByScheduledTimeAsc(userId, IntakeStatus.UNRESOLVED);
        return IntakeChronology.findEarlierUnresolved(unresolved, targetIntakeId);
    }

    /**
     * Not wrapped in a service-level @Transactional on purpose: the concurrency guarantee here
     * comes from {@link IntakeRepositoryPort#tryTransition}, a single atomic conditional UPDATE
     * statement (each Spring Data repository call already runs in its own auto-managed
     * transaction) — not from an enclosing transaction spanning the WebSocket round-trip to the
     * device, which would hold a transaction open for the ~5s device ACK wait. The per-user
     * ReentrantLock in {@link #requestIntakeNow} keeps normal (non-racing) calls serialized end to
     * end; tryTransition is what makes even a lock-bypassing race safe.
     */
    private IntakeActionResult doRequestIntakeNow(Long userId, Long explicitIntakeId) {
        List<Intake> unresolved = intakeRepository.findUnresolvedOrderByScheduledTimeAsc(userId, IntakeStatus.UNRESOLVED);

        if (unresolved.isEmpty()) {
            if (explicitIntakeId != null) {
                Intake target = intakeRepository.findById(explicitIntakeId).orElse(null);
                if (target != null) {
                    return IntakeActionResult.alreadyResolved(target, "This dose has already been resolved.");
                }
            }
            return IntakeActionResult.nothingAvailable("Nothing is currently available to take.");
        }

        Intake earliest = unresolved.get(0);
        Intake target = earliest;

        if (explicitIntakeId != null) {
            Intake requested = intakeRepository.findById(explicitIntakeId).orElse(null);
            if (requested == null) {
                return IntakeActionResult.nothingAvailable("That dose could not be found.");
            }
            if (IntakeStatus.RESOLVED.contains(requested.getStatus())) {
                return IntakeActionResult.alreadyResolved(requested, "This dose has already been resolved.");
            }
            // Same rule ReminderScheduler uses to decide whether B's normal reminder may fire:
            // is anything chronologically earlier still unresolved?
            Optional<Intake> blocker = IntakeChronology.findEarlierUnresolved(unresolved, requested.getId());
            if (blocker.isPresent()) {
                return IntakeActionResult.blockedByEarlier(blocker.get(), blockedMessage(blocker.get()));
            }
            target = requested;
        }

        // target == earliest at this point either way.
        if (!IntakeStatus.STARTABLE.contains(target.getStatus())) {
            return switch (target.getStatus()) {
                case DISPENSING -> IntakeActionResult.alreadyInProgress(target, "The previous dose is currently being dispensed.");
                case DISPENSED -> IntakeActionResult.awaitingRemoval(target,
                        "Medication from the previous dose is still in the compartment. Remove it before continuing.");
                case INCOMPLETE -> IntakeActionResult.awaitingRemoval(target,
                        "The previous intake wasn't completed and may still contain medication. Remove it before continuing.");
                default -> IntakeActionResult.blockedByEarlier(target, blockedMessage(target));
            };
        }

        Optional<Device> deviceOpt = deviceRepository.findByUserId(userId);
        if (deviceOpt.isEmpty()) {
            return IntakeActionResult.noDevice("No pill box registered for this patient.");
        }
        Device device = deviceOpt.get();

        IntakeStatus priorStatus = target.getStatus();
        boolean claimed = intakeRepository.tryTransition(target.getId(), IntakeStatus.STARTABLE, IntakeStatus.DISPENSING);
        if (!claimed) {
            // Lost a race (shouldn't normally happen given the per-user lock, but the atomic
            // conditional update is the real safety net) — re-read and report the current truth
            // rather than attempting a second dispense.
            Intake fresh = intakeRepository.findById(target.getId()).orElse(target);
            logger.info("Intake {} claim lost the race — current status {}", target.getId(), fresh.getStatus());
            return IntakeActionResult.alreadyInProgress(fresh, "This dose is already being handled.");
        }

        reminderScheduler.cancelPostponeReminder(target.getId());

        DeviceConnectionPort.DispatchOutcome outcome = deviceConnectionPort.dispatchDispense(device.getDeviceKey(), target.getId());
        if (outcome != DeviceConnectionPort.DispatchOutcome.ACKED) {
            // Revert the claim — the device never actually took the command, so the intake must not
            // be left looking like it's dispensing.
            intakeRepository.tryTransition(target.getId(), List.of(IntakeStatus.DISPENSING), priorStatus);
            if (outcome == DeviceConnectionPort.DispatchOutcome.ACK_TIMEOUT) {
                return IntakeActionResult.deviceAckTimeout(target, "Pill box didn't respond in time — try again.");
            }
            return IntakeActionResult.deviceOffline(target, "Pill box is offline — try again once it reconnects.");
        }

        target.setStatus(IntakeStatus.DISPENSING);
        target.setDeviceId(device.getId());
        if (target.getApprovedTime() == null) {
            target.setApprovedTime(LocalDateTime.now());
        }
        Intake saved = intakeRepository.save(target);
        logger.info("Intake {} claimed and dispensing (was {})", saved.getId(), priorStatus);
        return IntakeActionResult.started(saved);
    }

    private String blockedMessage(Intake blocking) {
        return switch (blocking.getStatus()) {
            case MISSED -> "A previous dose was missed. Please complete that dose before taking the next one.";
            case POSTPONED -> "A previous dose was postponed. Please complete that dose before taking the next one.";
            case PENDING, APPROVED -> "A previous dose needs your attention before you can take this one.";
            default -> "A previous dose must be resolved before you can take this one.";
        };
    }
}
