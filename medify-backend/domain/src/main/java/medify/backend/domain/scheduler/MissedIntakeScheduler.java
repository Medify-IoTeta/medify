package medify.backend.domain.scheduler;

import medify.backend.domain.model.*;
import medify.backend.domain.port.CaregiverLinkRepositoryPort;
import medify.backend.domain.port.IntakeRepositoryPort;
import medify.backend.domain.port.NotificationLogRepositoryPort;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;
import java.time.LocalDateTime;
import java.util.List;

@Component
public class MissedIntakeScheduler {
    private static final Logger logger = LoggerFactory.getLogger(MissedIntakeScheduler.class);

    private final IntakeRepositoryPort intakeRepository;
    private final CaregiverLinkRepositoryPort caregiverLinkRepository;
    private final NotificationLogRepositoryPort notificationLogRepository;

    public MissedIntakeScheduler(IntakeRepositoryPort intakeRepository,
                                 CaregiverLinkRepositoryPort caregiverLinkRepository,
                                 NotificationLogRepositoryPort notificationLogRepository) {
        this.intakeRepository = intakeRepository;
        this.caregiverLinkRepository = caregiverLinkRepository;
        this.notificationLogRepository = notificationLogRepository;
    }

    @Scheduled(cron = "0 */5 * * * *")
    public void detectMissedIntakes() {
        List<Intake> expired = intakeRepository.findExpiredPendingIntakes(LocalDateTime.now());

        for (Intake intake : expired) {
            intake.setStatus(IntakeStatus.MISSED);
            intakeRepository.save(intake);
            logger.info("Intake {} marked as MISSED", intake.getId());

            notifyCaregivers(intake);
        }
    }

    private void notifyCaregivers(Intake intake) {
        List<CaregiverLink> links = caregiverLinkRepository.findByPatientId(intake.getUserId())
                .stream()
                .filter(CaregiverLink::isReceiveAlerts)
                .toList();

        for (CaregiverLink link : links) {
            String timingLabel = intake.getTiming().name().charAt(0)
                    + intake.getTiming().name().substring(1).toLowerCase();

            NotificationLog log = new NotificationLog();
            log.setRecipientUserId(link.getId().getCaregiverId());
            log.setIntakeId(intake.getId());
            log.setType(NotificationType.MISSED_INTAKE);
            log.setMessage("Patient missed their " + timingLabel + " medication");
            log.setSentTime(LocalDateTime.now());
            log.setDeliveryStatus("SENT");
            notificationLogRepository.save(log);

            logger.info("MISSED_INTAKE notification logged for caregiver {}", link.getId().getCaregiverId());
        }
    }
}
