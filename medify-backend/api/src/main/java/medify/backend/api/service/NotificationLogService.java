package medify.backend.api.service;

import medify.backend.api.dto.NotificationLogEntry;
import medify.backend.domain.model.Intake;
import medify.backend.domain.model.NotificationLog;
import medify.backend.domain.port.IntakeRepositoryPort;
import medify.backend.domain.port.NotificationLogRepositoryPort;
import org.springframework.stereotype.Service;
import java.time.LocalDateTime;
import java.util.List;

@Service
public class NotificationLogService {

    private final NotificationLogRepositoryPort repository;
    private final IntakeRepositoryPort intakeRepository;

    public NotificationLogService(NotificationLogRepositoryPort repository, IntakeRepositoryPort intakeRepository) {
        this.repository = repository;
        this.intakeRepository = intakeRepository;
    }

    /**
     * Defaults to a rolling 24-hour window (anchored on "now", not calendar-day boundaries) when
     * from/to aren't supplied — this is what keeps the caregiver Alerts feed to genuinely recent
     * events rather than an unbounded history (Intake History is the place for anything older).
     * Each log is joined against its intake's *current* status so the caregiver UI can relabel a
     * since-resolved MISSED/INCOMPLETE alert instead of leaving it stuck on a stale label.
     */
    public List<NotificationLogEntry> getByUserIdAndRange(Long userId, LocalDateTime from, LocalDateTime to) {
        if (from == null) from = LocalDateTime.now().minusHours(24);
        if (to == null)   to   = LocalDateTime.now();
        return repository.findByRecipientUserIdBetween(userId, from, to).stream()
                .map(this::toEntry)
                .toList();
    }

    private NotificationLogEntry toEntry(NotificationLog log) {
        Intake intake = log.getIntakeId() != null
                ? intakeRepository.findById(log.getIntakeId()).orElse(null)
                : null;
        return NotificationLogEntry.from(log, intake);
    }
}
