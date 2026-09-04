package medify.backend.data.repository;

import medify.backend.domain.model.SlotContent;
import medify.backend.domain.port.SlotContentRepositoryPort;
import org.springframework.stereotype.Repository;
import java.util.List;

@Repository
public class SlotContentRepository implements SlotContentRepositoryPort {

    private final SlotContentJpaRepository jpaRepository;

    public SlotContentRepository(SlotContentJpaRepository jpaRepository) {
        this.jpaRepository = jpaRepository;
    }

    @Override
    public SlotContent save(SlotContent content) {
        return jpaRepository.save(content);
    }

    @Override
    public List<SlotContent> findByDeviceId(Long deviceId) {
        return jpaRepository.findByDeviceId(deviceId);
    }

    @Override
    public boolean existsByDeviceIdAndSlotNumberAndMedicineId(Long deviceId, int slotNumber, Long medicineId) {
        return jpaRepository.existsByDeviceIdAndSlotNumberAndMedicineId(deviceId, slotNumber, medicineId);
    }

    @Override
    public void deleteByDeviceIdAndSlotNumberAndMedicineId(Long deviceId, int slotNumber, Long medicineId) {
        jpaRepository.deleteByDeviceIdAndSlotNumberAndMedicineId(deviceId, slotNumber, medicineId);
    }

    @Override
    public void deleteByDeviceIdAndSlotNumber(Long deviceId, int slotNumber) {
        jpaRepository.deleteByDeviceIdAndSlotNumber(deviceId, slotNumber);
    }
}
