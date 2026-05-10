package medify.backend.api.service;

import medify.backend.domain.model.Intake;
import medify.backend.domain.model.IntakeStatus;
import medify.backend.domain.port.IntakeRepositoryPort;
import org.springframework.stereotype.Service;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.LocalTime;
import java.util.List;

@Service
public class IntakeService {

    private final IntakeRepositoryPort intakeRepository;

    public IntakeService(IntakeRepositoryPort intakeRepository) {
        this.intakeRepository = intakeRepository;
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
        intake.setStatus(IntakeStatus.APPROVED);
        intake.setApprovedTime(LocalDateTime.now());
        return intakeRepository.save(intake);
    }

    public Intake released(Long id) {
        Intake intake = findOrThrow(id);
        // Emptied detection not yet implemented — released means taken
        intake.setStatus(IntakeStatus.TAKEN);
        intake.setReleasedTime(LocalDateTime.now());
        return intakeRepository.save(intake);
    }

    public Intake skip(Long id) {
        Intake intake = findOrThrow(id);
        intake.setStatus(IntakeStatus.SKIPPED);
        return intakeRepository.save(intake);
    }

    public Intake postpone(Long id) {
        Intake intake = findOrThrow(id);
        intake.setStatus(IntakeStatus.POSTPONED);
        return intakeRepository.save(intake);
    }

    public Intake missed(Long id) {
        Intake intake = findOrThrow(id);
        intake.setStatus(IntakeStatus.MISSED);
        return intakeRepository.save(intake);
    }

    private Intake findOrThrow(Long id) {
        return intakeRepository.findById(id)
                .orElseThrow(() -> new RuntimeException("Intake not found: " + id));
    }
}
