package medify.backend.domain.port;

import medify.backend.domain.model.SlotContent;
import java.util.List;

public interface SlotContentRepositoryPort {
    SlotContent save(SlotContent content);

    /** Every slot's current contents for one device, in one query — BoxRefillService groups this by slot itself. */
    List<SlotContent> findByDeviceId(Long deviceId);

    boolean existsByDeviceIdAndSlotNumberAndMedicineId(Long deviceId, int slotNumber, Long medicineId);

    void deleteByDeviceIdAndSlotNumberAndMedicineId(Long deviceId, int slotNumber, Long medicineId);

    /** Clears an entire slot's contents — called when the device reports that slot was just dispensed. */
    void deleteByDeviceIdAndSlotNumber(Long deviceId, int slotNumber);
}
