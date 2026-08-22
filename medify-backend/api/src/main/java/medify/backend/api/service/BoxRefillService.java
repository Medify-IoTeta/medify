package medify.backend.api.service;

import medify.backend.domain.model.BoxRefillSession;
import medify.backend.domain.model.BoxSlotFill;
import medify.backend.domain.model.IntakeStatus;
import medify.backend.domain.port.BoxRefillSessionRepositoryPort;
import medify.backend.domain.port.BoxSlotFillRepositoryPort;
import medify.backend.domain.port.IntakeRepositoryPort;
import org.springframework.stereotype.Service;

import java.time.LocalDateTime;
import java.util.List;
import java.util.Optional;
import java.util.stream.Collectors;

@Service
public class BoxRefillService {

    public record FilledCell(int slotNumber, Long medicineId) {}

    public record BoxRefillState(
            Long sessionId,
            LocalDateTime startedAt,
            long currentSlot,
            List<FilledCell> filledCells,
            boolean active) {}

    private final BoxRefillSessionRepositoryPort sessionRepository;
    private final BoxSlotFillRepositoryPort slotFillRepository;
    private final IntakeRepositoryPort intakeRepository;

    public BoxRefillService(BoxRefillSessionRepositoryPort sessionRepository,
                            BoxSlotFillRepositoryPort slotFillRepository,
                            IntakeRepositoryPort intakeRepository) {
        this.sessionRepository = sessionRepository;
        this.slotFillRepository = slotFillRepository;
        this.intakeRepository = intakeRepository;
    }

    public BoxRefillState startNewRefill(Long userId) {
        sessionRepository.deactivateAllByUserId(userId);
        BoxRefillSession session = new BoxRefillSession();
        session.setUserId(userId);
        session.setStartedAt(LocalDateTime.now());
        session.setActive(true);
        BoxRefillSession saved = sessionRepository.save(session);
        return new BoxRefillState(saved.getId(), saved.getStartedAt(), 0L, List.of(), true);
    }

    public Optional<BoxRefillState> getCurrentState(Long userId) {
        return sessionRepository.findActiveByUserId(userId).map(session -> {
            long currentSlot = intakeRepository.countTakenSince(
                    userId, IntakeStatus.TAKEN, session.getStartedAt());
            List<FilledCell> filledCells = slotFillRepository.findBySessionId(session.getId())
                    .stream()
                    .map(f -> new FilledCell(f.getSlotNumber(), f.getMedicineId()))
                    .collect(Collectors.toList());
            return new BoxRefillState(session.getId(), session.getStartedAt(), currentSlot, filledCells, true);
        });
    }

    public void markSlotFilled(Long userId, int slotNumber, Long medicineId) {
        BoxRefillSession session = sessionRepository.findActiveByUserId(userId)
                .orElseThrow(() -> new RuntimeException("No active refill session"));
        if (slotFillRepository.existsBySessionIdAndSlotNumberAndMedicineId(session.getId(), slotNumber, medicineId)) {
            return;
        }
        BoxSlotFill fill = new BoxSlotFill();
        fill.setSessionId(session.getId());
        fill.setSlotNumber(slotNumber);
        fill.setMedicineId(medicineId);
        fill.setFilledAt(LocalDateTime.now());
        slotFillRepository.save(fill);
    }

    public void unmarkSlotFilled(Long userId, int slotNumber, Long medicineId) {
        BoxRefillSession session = sessionRepository.findActiveByUserId(userId)
                .orElseThrow(() -> new RuntimeException("No active refill session"));
        slotFillRepository.deleteBySessionIdAndSlotNumberAndMedicineId(session.getId(), slotNumber, medicineId);
    }
}
