package medify.backend.domain.model;

/**
 * Outcome of a "start/continue an intake now" request, regardless of whether it came from the
 * app or the physical button. Both callers go through the same business logic and get back the
 * same structured result — see IntakeOrchestrationService (api module) for where this is built.
 */
public record IntakeActionResult(
        Outcome outcome,
        /** The intake that was acted on (present only when outcome == STARTED, or when the target
         *  itself is why the request couldn't proceed, e.g. ALREADY_IN_PROGRESS/AWAITING_REMOVAL/ALREADY_RESOLVED). */
        Intake intake,
        /** The earlier unresolved intake blocking the request, when outcome == BLOCKED_BY_EARLIER_INTAKE. */
        Intake blockingIntake,
        String message
) {
    public enum Outcome {
        /** Claimed the intake and the device acknowledged the dispense command. */
        STARTED,
        /** No intake is currently eligible to be started (nothing pending/approved/missed/postponed exists). */
        NOTHING_AVAILABLE,
        /** An explicit target was requested but a chronologically earlier unresolved intake must be resolved first. */
        BLOCKED_BY_EARLIER_INTAKE,
        /** The relevant intake is already DISPENSING — do not send a second command. */
        ALREADY_IN_PROGRESS,
        /** The relevant intake is DISPENSED or INCOMPLETE — pills are physically in the compartment and must be removed first. */
        AWAITING_REMOVAL,
        /** An explicit target was requested but it's already TAKEN or SKIPPED. */
        ALREADY_RESOLVED,
        /** No pill box registered for this patient. */
        NO_DEVICE,
        /** The device isn't connected. */
        DEVICE_OFFLINE,
        /** The device is connected but didn't acknowledge the command in time. */
        DEVICE_ACK_TIMEOUT
    }

    public static IntakeActionResult started(Intake intake) {
        return new IntakeActionResult(Outcome.STARTED, intake, null, "Dispensing started.");
    }

    public static IntakeActionResult nothingAvailable(String message) {
        return new IntakeActionResult(Outcome.NOTHING_AVAILABLE, null, null, message);
    }

    public static IntakeActionResult blockedByEarlier(Intake blockingIntake, String message) {
        return new IntakeActionResult(Outcome.BLOCKED_BY_EARLIER_INTAKE, null, blockingIntake, message);
    }

    public static IntakeActionResult alreadyInProgress(Intake intake, String message) {
        return new IntakeActionResult(Outcome.ALREADY_IN_PROGRESS, intake, null, message);
    }

    public static IntakeActionResult awaitingRemoval(Intake intake, String message) {
        return new IntakeActionResult(Outcome.AWAITING_REMOVAL, intake, null, message);
    }

    public static IntakeActionResult alreadyResolved(Intake intake, String message) {
        return new IntakeActionResult(Outcome.ALREADY_RESOLVED, intake, null, message);
    }

    public static IntakeActionResult noDevice(String message) {
        return new IntakeActionResult(Outcome.NO_DEVICE, null, null, message);
    }

    public static IntakeActionResult deviceOffline(Intake intake, String message) {
        return new IntakeActionResult(Outcome.DEVICE_OFFLINE, intake, null, message);
    }

    public static IntakeActionResult deviceAckTimeout(Intake intake, String message) {
        return new IntakeActionResult(Outcome.DEVICE_ACK_TIMEOUT, intake, null, message);
    }

    public boolean isBlocking() {
        return outcome != Outcome.STARTED;
    }
}
