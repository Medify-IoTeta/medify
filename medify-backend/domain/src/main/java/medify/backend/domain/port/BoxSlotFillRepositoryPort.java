package medify.backend.domain.port;

import medify.backend.domain.model.BoxSlotFill;
import java.util.List;

public interface BoxSlotFillRepositoryPort {
    BoxSlotFill save(BoxSlotFill fill);
    List<BoxSlotFill> findBySessionId(Long sessionId);
    boolean existsBySessionIdAndSlotNumberAndMedicineId(Long sessionId, int slotNumber, Long medicineId);
    void deleteBySessionIdAndSlotNumberAndMedicineId(Long sessionId, int slotNumber, Long medicineId);
}
