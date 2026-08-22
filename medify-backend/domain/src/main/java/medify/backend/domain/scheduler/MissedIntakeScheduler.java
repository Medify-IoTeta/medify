package medify.backend.domain.scheduler;

import medify.backend.domain.model.*;
import medify.backend.domain.port.CaregiverLinkRepositoryPort;
import medify.backend.domain.port.IntakeRepositoryPort;
import medify.backend.domain.port.NotificationLogRepositoryPort;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;
import java.time.LocalDateTime;
import java.util.List;

/**
 * Sweeps two kinds of intakes that never got resolved before their window ran out:
 * MISSED — never even started (still PENDING/APPROVED when windowEndTime passed).
 * INCOMPLETE — pills were dispensed but the IR sensor never confirmed the
 *   compartment emptied within incompleteGraceMinutes of the DISPENSED timestamp.
 * These are judged on different clocks on purpose: MISSED is relative to the
 * original reminder window, INCOMPLETE is relative to when dispensing actually
 * happened, so a late approval doesn't unfairly shorten the IR confirmation window.
 */
@Component
public class MissedIntakeScheduler {
    private static final Logger logger = LoggerFactory.getLogger(MissedIntakeScheduler.class);

    private final IntakeRepositoryPort intakeRepository;
    private final CaregiverLinkRepositoryPort caregiverLinkRepository;
    private final NotificationLogRepositoryPort notificationLogRepository;
    private final int incompleteGraceMinutes;

    public MissedIntakeScheduler(IntakeRepositoryPort intakeRepository,
                                 CaregiverLinkRepositoryPort caregiverLinkRepository,
                                 NotificationLogRepositoryPort notificationLogRepository,
                                 @Value("${medify.intake.incomplete-grace-minutes:30}") int incompleteGraceMinutes) {
        this.intakeRepository = intakeRepository;
        this.caregiverLinkRepository = caregiverLinkRepository;
        this.notificationLogRepository = notificationLogRepository;
        this.incompleteGraceMinutes = incompleteGraceMinutes;
    }

    @Scheduled(cron = "0 */5 * * * *")
    public void detectMissedIntakes() {
        detectMissed();
        detectIncomplete();
    }

    private void detectMissed() {
        List<Intake> expired = intakeRepository.findExpiredPendingIntakes(LocalDateTime.now());

        for (Intake intake : expired) {
            intake.setStatus(IntakeStatus.MISSED);
            intakeRepository.save(intake);
            logger.info("Intake {} marked as MISSED", intake.getId());

            notifyCaregivers(intake, NotificationType.MISSED_INTAKE,
                    "Patient missed their " + timingLabel(intake) + " medication");
        }
    }

    private void detectIncomplete() {
        LocalDateTime cutoff = LocalDateTime.now().minusMinutes(incompleteGraceMinutes);
        List<Intake> staleDispensed = intakeRepository.findByStatusAndDispensedTimeBefore(IntakeStatus.DISPENSED, cutoff);

        for (Intake intake : staleDispensed) {
            intake.setStatus(IntakeStatus.INCOMPLETE);
            intakeRepository.save(intake);
            logger.info("Intake {} marked as INCOMPLETE (dispensed at {}, {}min grace period elapsed)",
                    intake.getId(), intake.getDispensedTime(), incompleteGraceMinutes);

            notifyCaregivers(intake, NotificationType.INCOMPLETE_INTAKE,
                    "Patient's " + timingLabel(intake) + " medication was dispensed but not confirmed taken");
        }
    }

    private String timingLabel(Intake intake) {
        return intake.getTiming().name().charAt(0) + intake.getTiming().name().substring(1).toLowerCase();
    }

    private void notifyCaregivers(Intake intake, NotificationType type, String message) {
        List<CaregiverLink> links = caregiverLinkRepository.findByPatientId(intake.getUserId())
                .stream()
                .filter(CaregiverLink::isReceiveAlerts)
                .toList();

        for (CaregiverLink link : links) {
            NotificationLog log = new NotificationLog();
            log.setRecipientUserId(link.getId().getCaregiverId());
            log.setIntakeId(intake.getId());
            log.setType(type);
            log.setMessage(message);
            log.setSentTime(LocalDateTime.now());
            log.setDeliveryStatus("SENT");
            notificationLogRepository.save(log);

            logger.info("{} notification logged for caregiver {}", type, link.getId().getCaregiverId());
        }
    }
}
