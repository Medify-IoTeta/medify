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
        logger.info("[BUTTON_FLOW] requestIntakeNow entered: userId={}, explicitIntakeId={}", userId, explicitIntakeId);
        // The repository call itself only guarantees scheduledTime ascending — sortByPriority
        // re-orders it into the actual selection rule (physical-safety-blocking statuses first,
        // then MISSED, then everything else, each sub-ordered by scheduledTime). Without this,
        // two co-eligible PENDING intakes would still come out in scheduledTime order correctly,
        // but a MISSED intake would NOT reliably outrank a chronologically-closer PENDING one, and
        // — the part that actually matters for physical safety — nothing would guarantee a
        // DISPENSED/DISPENSING/INCOMPLETE intake stays absolute-first regardless of what else
        // exists.
        List<Intake> unresolved = IntakeChronology.sortByPriority(
                intakeRepository.findUnresolvedOrderByScheduledTimeAsc(userId, IntakeStatus.UNRESOLVED));
        logger.info("[BUTTON_FLOW] unresolved intakes for user {} (priority order): count={}, ids={}",
                userId, unresolved.size(), unresolved.stream().map(Intake::getId).toList());

        if (unresolved.isEmpty()) {
            if (explicitIntakeId != null) {
                Intake target = intakeRepository.findById(explicitIntakeId).orElse(null);
                if (target != null) {
                    logger.info("[BUTTON_FLOW] no unresolved intakes; explicit target {} already resolved -> ALREADY_RESOLVED", explicitIntakeId);
                    return IntakeActionResult.alreadyResolved(target, "This dose has already been resolved.");
                }
            }
            logger.info("[BUTTON_FLOW] no unresolved intakes exist for user {} -> NOTHING_AVAILABLE (no PENDING/MISSED/POSTPONED/etc. intake to act on)", userId);
            return IntakeActionResult.nothingAvailable("Nothing is currently available to take.");
        }

        Intake earliest = unresolved.get(0);
        Intake target = earliest;
        logger.info("[BUTTON_FLOW] earliest unresolved intake selected: id={}, status={}, scheduledTime={}, windowEndTime={}",
                earliest.getId(), earliest.getStatus(), earliest.getScheduledTime(), earliest.getWindowEndTime());

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
            logger.info("[BUTTON_FLOW] intake {} status {} is not STARTABLE -> blocked (no dispatch attempted)",
                    target.getId(), target.getStatus());
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
            logger.warn("[BUTTON_FLOW] no device registered for user {} -> NO_DEVICE (no dispatch attempted)", userId);
            return IntakeActionResult.noDevice("No pill box registered for this patient.");
        }
        Device device = deviceOpt.get();
        logger.info("[BUTTON_FLOW] device for user {}: deviceKey={}", userId, device.getDeviceKey());

        IntakeStatus priorStatus = target.getStatus();
        logger.info("[BUTTON_FLOW] about to claim intake {} ({} -> DISPENSING) via tryTransition", target.getId(), priorStatus);
        boolean claimed;
        try {
            claimed = intakeRepository.tryTransition(target.getId(), IntakeStatus.STARTABLE, IntakeStatus.DISPENSING);
        } catch (RuntimeException e) {
            // Temporary diagnostic wrapper: tryTransition threw before returning, so the flow would
            // otherwise stop silently here from a [BUTTON_FLOW]-only log view — the underlying
            // exception was still being logged by DeviceWebSocketHandler's catch-all, just without
            // this prefix. Logging and rethrowing here makes it visible under the same filter, then
            // preserves existing error handling upstream.
            logger.error("[BUTTON_FLOW] tryTransition threw for intake {} — claim did not complete: {}",
                    target.getId(), e.toString(), e);
            throw e;
        }
        logger.info("[BUTTON_FLOW] claim intake {} ({} -> DISPENSING): {}",
                target.getId(), priorStatus, claimed ? "SUCCEEDED" : "FAILED (lost race)");
        if (!claimed) {
            // Lost a race (shouldn't normally happen given the per-user lock, but the atomic
            // conditional update is the real safety net) — re-read and report the current truth
            // rather than attempting a second dispense.
            Intake fresh = intakeRepository.findById(target.getId()).orElse(target);
            logger.info("[BUTTON_FLOW] intake {} claim lost the race — current status {}", target.getId(), fresh.getStatus());
            return IntakeActionResult.alreadyInProgress(fresh, "This dose is already being handled.");
        }

        reminderScheduler.cancelPostponeReminder(target.getId());

        logger.info("[BUTTON_FLOW] dispatching command:dispense to device {} for intake {}", device.getDeviceKey(), target.getId());
        DeviceConnectionPort.DispatchOutcome outcome = deviceConnectionPort.dispatchDispense(device.getDeviceKey(), target.getId());
        logger.info("[BUTTON_FLOW] dispatchDispense outcome for intake {}: {}", target.getId(), outcome);

        if (outcome == DeviceConnectionPort.DispatchOutcome.ACKED) {
            target.setStatus(IntakeStatus.DISPENSING);
            target.setDeviceId(device.getId());
            if (target.getApprovedTime() == null) {
                target.setApprovedTime(LocalDateTime.now());
            }
            Intake saved = intakeRepository.save(target);
            logger.info("[BUTTON_FLOW] intake {} claimed and dispensing (was {}) — STARTED", saved.getId(), priorStatus);
            return IntakeActionResult.started(saved);
        }

        if (outcome == DeviceConnectionPort.DispatchOutcome.ACK_TIMEOUT) {
            // Delivery is UNCERTAIN here, not known-failed: the command was sent, and the device may
            // well have received it, acted on it, and even physically dispensed — we simply didn't
            // get the ack back in time (this is exactly what happened with the WebSocket
            // self-blocking bug: the device acked and dispensed, but the backend's own wait timed
            // out first). Deliberately do NOT revert to a STARTABLE status here — reverting would
            // let the very next button press or Take Now select this same intake again and risk a
            // second physical dispense into a compartment that may already hold the first dose.
            // Leaving it at DISPENSING keeps it non-STARTABLE until the device's own "dispensed"
            // event resolves it forward, which still arrives independently of whether the ack
            // round-trip succeeded. Same conservative philosophy already applied to DISPENSED never
            // auto-reverting on its own (see MissedIntakeScheduler / CLAUDE.md) — no reliable
            // jam/delivery-failure detection exists, so an uncertain outcome is left for the
            // device's own follow-up event (or a human) to resolve, never guessed away.
            target.setStatus(IntakeStatus.DISPENSING);
            Intake saved = intakeRepository.save(target);
            logger.warn("[BUTTON_FLOW] ack uncertain for intake {} — leaving at DISPENSING instead of reverting, to avoid a possible duplicate dispense", target.getId());
            return IntakeActionResult.deviceAckTimeout(saved,
                    "Pill box didn't confirm in time — it may still have dispensed. Check the compartment before trying again.");
        }

        // OFFLINE (or any other non-ACKED outcome): the command never reached the device — no open
        // session, or the send itself failed — so nothing was dispatched and reverting is safe.
        intakeRepository.tryTransition(target.getId(), List.of(IntakeStatus.DISPENSING), priorStatus);
        logger.warn("[BUTTON_FLOW] dispatch failed before reaching the device ({}) -> reverted intake {} back to {}", outcome, target.getId(), priorStatus);
        return IntakeActionResult.deviceOffline(target, "Pill box is offline — try again once it reconnects.");
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
