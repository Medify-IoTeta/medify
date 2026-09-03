package medify.backend.api.dto;

import medify.backend.domain.model.Intake;
import medify.backend.domain.model.IntakeStatus;
import medify.backend.domain.model.Timing;

import java.time.Duration;
import java.time.LocalDate;
import java.time.LocalDateTime;

/**
 * One row of the patient/caregiver-facing intake history — a computed projection over an
 * existing {@link Intake}, not a persisted concept of its own. The mapping in {@link #from} is
 * the single place "what actually happened to this dose" is decided, so the patient app and the
 * caregiver view (both hitting the same /api/intakes/history endpoint) always agree.
 */
public record IntakeHistoryEntry(
        Long intakeId,
        Timing timing,
        LocalDate scheduledDate,
        LocalDateTime scheduledTime,
        IntakeStatus status,
        Outcome outcome,
        /** When the IR sensor actually confirmed pickup — null if never taken. */
        LocalDateTime takenAt,
        /** takenAt - scheduledTime, in minutes. Negative means taken early (during the early
         *  window, before the scheduled instant). Null if never taken. */
        Long latenessMinutes,
        /** Whether this occurrence was postponed at least once, regardless of the final outcome —
         *  e.g. still worth surfacing even when the outcome ended up TAKEN_AFTER_MISSED. */
        boolean wasPostponed
) {
    public enum Outcome {
        TAKEN_ON_TIME,
        TAKEN_AFTER_POSTPONED,
        TAKEN_AFTER_MISSED,
        MISSED,
        SKIPPED,
        INCOMPLETE,
        PENDING,
        APPROVED,
        POSTPONED,
        DISPENSING,
        DISPENSED
    }

    public static IntakeHistoryEntry from(Intake intake) {
        boolean wasPostponed = intake.getPostponedAt() != null;
        boolean wasMissed = intake.getMissedAt() != null;

        Outcome outcome = switch (intake.getStatus()) {
            case TAKEN -> wasMissed ? Outcome.TAKEN_AFTER_MISSED
                    : wasPostponed ? Outcome.TAKEN_AFTER_POSTPONED
                    : Outcome.TAKEN_ON_TIME;
            case MISSED -> Outcome.MISSED;
            case SKIPPED -> Outcome.SKIPPED;
            case INCOMPLETE -> Outcome.INCOMPLETE;
            case PENDING -> Outcome.PENDING;
            case APPROVED -> Outcome.APPROVED;
            case POSTPONED -> Outcome.POSTPONED;
            case DISPENSING -> Outcome.DISPENSING;
            case DISPENSED -> Outcome.DISPENSED;
        };

        LocalDateTime takenAt = intake.getReleasedTime();
        Long latenessMinutes = takenAt != null
                ? Duration.between(intake.getScheduledTime(), takenAt).toMinutes()
                : null;

        return new IntakeHistoryEntry(
                intake.getId(),
                intake.getTiming(),
                intake.getScheduledDate(),
                intake.getScheduledTime(),
                intake.getStatus(),
                outcome,
                takenAt,
                latenessMinutes,
                wasPostponed
        );
    }
}
