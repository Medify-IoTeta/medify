package medify.backend.api.dto;

import medify.backend.domain.model.Intake;
import medify.backend.domain.model.IntakeStatus;
import medify.backend.domain.model.NotificationLog;
import medify.backend.domain.model.NotificationType;

import java.time.LocalDateTime;

/**
 * API projection of a NotificationLog, adding {@code resolvedAsTaken} — whether the intake this
 * alert refers to has since reached TAKEN. Lets the caregiver UI relabel a MISSED_INTAKE alert as
 * "Taken after missed" (and INCOMPLETE_INTAKE as "Taken after incomplete") instead of just
 * disappearing or staying stuck on the original, now-stale label, while it's still within its
 * 24-hour display window (see NotificationLogService).
 */
public record NotificationLogEntry(
        Long id,
        Long intakeId,
        NotificationType type,
        String message,
        LocalDateTime sentTime,
        boolean resolvedAsTaken
) {
    public static NotificationLogEntry from(NotificationLog log, Intake intake) {
        boolean resolvedAsTaken = intake != null && intake.getStatus() == IntakeStatus.TAKEN;
        return new NotificationLogEntry(
                log.getId(),
                log.getIntakeId(),
                log.getType(),
                log.getMessage(),
                log.getSentTime(),
                resolvedAsTaken
        );
    }
}
