package medify.backend.data.repository;

import medify.backend.domain.model.SlotContent;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.transaction.annotation.Transactional;
import java.util.List;

public interface SlotContentJpaRepository extends JpaRepository<SlotContent, Long> {

    List<SlotContent> findByDeviceId(Long deviceId);

    boolean existsByDeviceIdAndSlotNumberAndMedicineId(Long deviceId, int slotNumber, Long medicineId);

    @Modifying
    @Transactional
    @Query("DELETE FROM SlotContent c WHERE c.deviceId = :deviceId AND c.slotNumber = :slotNumber AND c.medicineId = :medicineId")
    void deleteByDeviceIdAndSlotNumberAndMedicineId(@Param("deviceId") Long deviceId,
                                                     @Param("slotNumber") int slotNumber,
                                                     @Param("medicineId") Long medicineId);

    @Modifying
    @Transactional
    @Query("DELETE FROM SlotContent c WHERE c.deviceId = :deviceId AND c.slotNumber = :slotNumber")
    void deleteByDeviceIdAndSlotNumber(@Param("deviceId") Long deviceId, @Param("slotNumber") int slotNumber);
}
